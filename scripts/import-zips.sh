#!/usr/bin/env bash
#
# import-zips.sh — idempotently add Redump/No-Intro per-game .zip sets to the library.
#
# Input layout (e.g. a torrent download):
#   <input>/<System Name>/<Game (Region).zip>
#   e.g.  "Sony - PlayStation/Alundra (USA) (Rev 1).zip"
#
# For each zip:
#   • disc set (.cue/.gdi/.toc/.iso inside)  -> extract -> chdman -> <game>.chd
#   • cart rom (no disc image inside)        -> copy the .zip as-is (RetroArch
#                                               loads zipped carts directly)
#
# IDEMPOTENT: a game whose output already exists is skipped, so re-run anytime —
# mid-download, or to add a new "<System Name>/" folder. Nothing is redone.
#
# PARALLEL: chdman already uses several cores per file, but not a whole big box.
# This runs several games at once (-j N). Default N = cores/5 (so the per-file
# threads of N games roughly fill the machine). Raise -j to push harder.
#
# Destination:  arg >  $EMU_LIB/roms  >  ~/emustaging/Emulation/roms
#
# Usage:
#   ./import-zips.sh [-j N] <input-dir> [dest-roms-dir]
#   ./import-zips.sh -j 6 "/mnt/e/][TORRENTS][" /mnt/e/Emulation/roms
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/systems.sh"

command -v unzip  >/dev/null || { echo "unzip not found  — sudo apt install unzip"; exit 1; }
command -v chdman >/dev/null || { echo "chdman not found — run ./setup-tools.sh"; exit 1; }

JOBS=""; POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -j|--jobs) JOBS="${2:?-j needs a number}"; shift ;;
    -j*)       JOBS="${1#-j}" ;;
    -*)        echo "unknown option: $1"; exit 2 ;;
    *)         POS+=("$1") ;;
  esac
  shift
done
INPUT="${POS[0]:?usage: $0 [-j N] <input-dir-of-\"System Name/*.zip\"> [dest-roms-dir]}"
DEST="${POS[1]:-${EMU_LIB:-$HOME/emustaging/Emulation}/roms}"
[ -d "$INPUT" ] || { echo "no such input dir: $INPUT"; exit 1; }
INPUT="$(realpath "$INPUT")"
mkdir -p "$DEST"
[ -z "$JOBS" ] && JOBS=$(( $(nproc)/5 )); [ "$JOBS" -lt 1 ] && JOBS=1

TMPROOT="$(mktemp -d)"; RESULTS="$TMPROOT/results"; : > "$RESULTS"
cleanup_all(){ pkill -P $$ 2>/dev/null; rm -rf "$TMPROOT" 2>/dev/null; }
trap 'echo; echo "Interrupted — finishing/cancelling in-flight jobs."; cleanup_all; exit 130' INT TERM
trap cleanup_all EXIT

# Compress/copy ONE zip. Runs in the background; logs outcome to $RESULTS.
CART_RE='^(nes|sfc|smc|fig|swc|gb|gbc|gba|nds|n64|z64|v64|md|gen|smd|sms|gg|pce|sg|col|int|vec|a78|lnx|ws|wsc|ngp|ngc|32x|d64|adf|dsk|tap|st|pbp|cso)$'

process_zip(){
  local z="$1" sys="$2" out="$3" mode="$4"
  local game chd zipcopy inner sheet iso cart td in part
  game="$(basename "$z" .zip)"; chd="$out/$game.chd"; zipcopy="$out/$(basename "$z")"
  if [ -f "$chd" ] || [ -f "$zipcopy" ]; then echo skip >>"$RESULTS"; return; fi

  # Read the zip's central directory ONCE. Empty/error => 0-byte or truncated
  # (still-downloading torrent): skip WITHOUT copying so it's retried next run.
  inner="$(unzip -Z1 "$z" 2>/dev/null)"
  if [ -z "$inner" ]; then echo "  [$sys] .. incomplete/unreadable (retry later): $game"; echo incomplete >>"$RESULTS"; return; fi

  sheet="$(printf '%s\n' "$inner" | grep -iE '\.(cue|gdi|toc)$' | head -1)"
  iso="$(printf '%s\n' "$inner" | grep -iE '\.iso$' | head -1)"
  if [ -n "$sheet" ] || [ -n "$iso" ]; then
    td="$(mktemp -d -p "$TMPROOT")"
    # extract failure => partial data (still downloading): retry, don't mark done
    if ! unzip -qq "$z" -d "$td" 2>/dev/null; then echo "  [$sys] .. partial data (retry later): $game"; echo incomplete >>"$RESULTS"; rm -rf "$td"; return; fi
    in="$td/${sheet:-$iso}"; part="$out/.$game.chd.part"; rm -f "$part"
    echo "  [$sys] chd  $game"
    if chdman "$mode" -i "$in" -o "$part" >/dev/null 2>&1; then mv -f "$part" "$chd"; echo add >>"$RESULTS"
    else echo "  [$sys] !! chdman failed: $game"; rm -f "$part"; echo fail >>"$RESULTS"; fi
    rm -rf "$td"; return
  fi

  # No disc image. Only copy if it's a genuine cart rom; never blind-copy.
  cart="$(printf '%s\n' "$inner" | sed -n 's/.*\.//p' | tr 'A-Z' 'a-z' | grep -iE "$CART_RE" | head -1)"
  if [ -n "$cart" ]; then
    cp "$z" "$out/" && { echo cart >>"$RESULTS"; echo "  [$sys] cart $(basename "$z")"; } || echo fail >>"$RESULTS"
  else
    echo "  [$sys] ?? no disc/cart inside, skipping: $game"; echo unknown >>"$RESULTS"
  fi
}

echo "INPUT: $INPUT"
echo "DEST : $DEST"
echo "JOBS : $JOBS parallel ($(nproc) cores)"
echo

touched=()
shopt -s nullglob
for sysdir in "$INPUT"/*/; do
  sysdir="${sysdir%/}"; folder="$(basename "$sysdir")"
  sys="$(map_system "$folder")"
  [ -z "$sys" ] && { printf "  ?  UNMAPPED  %s\n" "$folder"; continue; }
  zips=("$sysdir"/*.zip)
  [ ${#zips[@]} -eq 0 ] && continue
  out="$DEST/$sys"; mkdir -p "$out"; touched+=("$out")
  mode=createcd; is_dvd_system "$sys" && mode=createdvd
  echo "== $folder -> $sys (${#zips[@]} zips, mode=$mode) =="
  for z in "${zips[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
    process_zip "$z" "$sys" "$out" "$mode" &
  done
done
wait

for out in "${touched[@]}"; do "$HERE/make-m3u.sh" "$out" >/dev/null 2>&1 || true; done

echo
printf "Done.  added=%s  skipped(already had)=%s  carts=%s  incomplete(retry later)=%s  unknown=%s  failed=%s\n" \
  "$(grep -c '^add$' "$RESULTS")" "$(grep -c '^skip$' "$RESULTS")" \
  "$(grep -c '^cart$' "$RESULTS")" "$(grep -c '^incomplete$' "$RESULTS")" \
  "$(grep -c '^unknown$' "$RESULTS")" "$(grep -c '^fail$' "$RESULTS")"
echo "Library: $DEST"
