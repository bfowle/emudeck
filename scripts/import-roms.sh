#!/usr/bin/env bash
#
# import-roms.sh — GENERIC ROM importer into a library you choose.
#
# Maps each subfolder of INPUT to an EmuDeck system (map_system below) and places
# the real ROM/disc files into <library>/roms/<system>/, skipping junk by ext.
#
# Two placement modes (pick the right one for the destination filesystem):
#   • link  — symlink (instant, ~0 bytes). For a LOCAL ext4 staging dir that you
#             later push with `transfer-to-deck.sh` (rsync -L follows the links).
#   • copy  — real files. For a durable/portable library on an external or
#             Windows drive (/mnt/*), where symlinks wouldn't survive the move.
#             Disc images are compressed straight to .chd (no raw copy).
# Default is AUTO: copy when the destination is under /mnt/*, else link.
#
# Destination:  arg 2  >  $EMU_LIB/roms  >  ~/emustaging/Emulation/roms
# Set it once for the whole toolkit:  export EMU_LIB=/mnt/e/Emulation
#
# Usage:
#   ./import-roms.sh [--copy|--link] <input-dir> [dest-roms-dir]
#
set -uo pipefail
trap 'echo; echo "Interrupted."; exit 130' INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=auto; POS=()
for a in "$@"; do
  case "$a" in
    --copy) MODE=copy ;;
    --link|--symlink) MODE=link ;;
    -*) echo "unknown option: $a"; exit 2 ;;
    *) POS+=("$a") ;;
  esac
done
INPUT="${POS[0]:?usage: $0 [--copy|--link] <input-dir> [dest-roms-dir]}"
DEST="${POS[1]:-${EMU_LIB:-$HOME/emustaging/Emulation}/roms}"
[ -d "$INPUT" ] || { echo "no such input dir: $INPUT"; exit 1; }
INPUT="$(realpath "$INPUT")"
mkdir -p "$DEST"

# AUTO: anything under /mnt (external/Windows drive) gets real files, not links.
if [ "$MODE" = auto ]; then
  case "$DEST" in /mnt/*) MODE=copy ;; *) MODE=link ;; esac
fi

# ROM/disc extensions to import (lowercase). Junk like exe/html is simply absent.
EXTS="nes sfc smc fig swc gb gbc gba nds n64 z64 v64 md gen smd sms gg pce sg \
col int vec a78 lnx ws wsc ngp ngc cdi gdi iso bin cue chd img mdf mds ccd sub \
toc pbp cso 32x d64 adf dsk tap st zip 7z"
# Disc images handled by chdman (compressed in copy mode) + their raw tracks
# (consumed by the sheet, so never copied loose):
COMPRESSABLE="cue gdi toc iso"
TRACKS="bin img raw mdf mds ccd sub"

source "$HERE/systems.sh"   # provides map_system()
is_rom()  { local e="${1##*.}"; e="${e,,}"; [[ " $EXTS "         == *" $e "* ]]; }
has_ext() { find "$1" -type f \( -iname '*.cue' -o -iname '*.gdi' -o -iname '*.toc' -o -iname '*.iso' \) -print -quit 2>/dev/null; }

# rsync include-filter for copy mode: everything in EXTS except disc sheets/tracks
COPY_INC=(--include='*/')
for e in $EXTS; do
  case " $COMPRESSABLE $TRACKS " in *" $e "*) continue ;; esac
  COPY_INC+=(--include="*.$e" --include="*.${e^^}")
done
COPY_INC+=(--exclude='*')

echo "INPUT: $INPUT"
echo "DEST : $DEST"
echo "MODE : $MODE"
[ "$MODE" = copy ] && { command -v chdman >/dev/null 2>&1 && echo "chdman: yes (discs -> .chd)" || echo "chdman: MISSING (run ./setup-tools.sh; discs will be listed to compress)"; }
echo

shopt -s nullglob
for srcdir in "$INPUT"/*/; do
  srcdir="${srcdir%/}"; folder="$(basename "$srcdir")"
  sys="$(map_system "$folder")"
  if [ -z "$sys" ]; then printf "  ?    UNMAPPED   %s\n" "$folder"; continue; fi
  dest="$DEST/$sys"; mkdir -p "$dest"

  if [ "$MODE" = link ]; then
    n=0
    while IFS= read -r -d '' f; do
      is_rom "$f" || continue
      rel="${f#"$srcdir"/}"; t="$dest/$rel"; mkdir -p "$(dirname "$t")"
      ln -sfn "$f" "$t" && n=$((n+1))
    done < <(find "$srcdir" -type f -print0)
    [ "$n" -eq 0 ] && { rmdir "$dest" 2>/dev/null; printf "  --   %-12s <- %-32s (no real ROMs)\n" "$sys" "$folder"; } \
                   || printf "  link %-12s <- %-32s (%d files)\n" "$sys" "$folder" "$n"
    continue
  fi

  # --- copy mode ---
  # 1) copy non-disc real files (carts, .cdi, .cso, ...) with progress
  rsync -a --info=progress2 -h --partial --prune-empty-dirs "${COPY_INC[@]}" "$srcdir/" "$dest/" >/dev/null 2>/tmp/.imp.$$ || cat /tmp/.imp.$$; rm -f /tmp/.imp.$$
  # 2) compress disc images straight from the source -> dest (no raw copy)
  if [ -n "$(has_ext "$srcdir")" ]; then
    dvd=""; [ "$sys" = ps2 ] && dvd="--dvd"
    if command -v chdman >/dev/null 2>&1; then
      "$HERE/compress-chd.sh" $dvd --out "$dest" "$srcdir"
      "$HERE/make-m3u.sh" "$dest" >/dev/null 2>&1 || true
    else
      echo "  (need chdman)  ./compress-chd.sh $dvd --out \"$dest\" \"$srcdir\""
    fi
  fi
  if [ -z "$(find "$dest" -type f -print -quit 2>/dev/null)" ]; then
    rmdir "$dest" 2>/dev/null; printf "  --   %-12s <- %-32s (no real ROMs)\n" "$sys" "$folder"
  else
    printf "  copy %-12s <- %-32s (%s, %d files)\n" "$sys" "$folder" \
      "$(du -sh "$dest" 2>/dev/null | cut -f1)" "$(find "$dest" -type f | wc -l)"
  fi
done

echo
if [ "$MODE" = link ]; then
  echo "Symlinks placed. Next: compress discs (drops the raw links), then transfer:"
  echo "  ./compress-chd.sh --delete \"$DEST/psx\" \"$DEST/saturn\"   #  ./compress-chd.sh --dvd --delete \"$DEST/ps2\""
  echo "  ./make-m3u.sh \"$DEST/psx\"   then   ./transfer-to-deck.sh <deck-ip> <deck-Emulation-path>"
else
  echo "Real library built at $DEST (discs stored as .chd)."
  echo "When the SD card is set up, copy it over with transfer-to-deck.sh (or plug the"
  echo "drive into the dock and copy on the deck)."
fi
