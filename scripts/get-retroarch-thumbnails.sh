#!/usr/bin/env bash
# get-retroarch-thumbnails.sh — bulk-download cover art for your games from the
# libretro thumbnail server into RetroArch's thumbnails/ folder. Runs ON THE DECK.
# Matches by game label exactly the way RetroArch does, so what it downloads is what
# the playlists show.
#
# FAST on repeat runs:
#   • art already on disk      -> skipped (a local stat, no network)
#   • game with NO art in DB   -> recorded in a miss-cache (.thumb-misses) so it
#                                 isn't re-requested (404'd) every run
#   So a re-run with nothing new does ZERO downloads. Only genuinely-new games hit
#   the network. Pass --recheck to retry the cached misses (e.g. after libretro
#   adds new art).
#
# Usage:  ./get-retroarch-thumbnails.sh [--recheck] [roms-dir] [thumbnails-out-dir]
#   roms-dir default: auto-detected /run/media/*/Emulation/roms
#   out-dir  default: ~/.var/app/org.libretro.RetroArch/config/retroarch/thumbnails
#   THUMB_TYPES env (default "Named_Boxarts") — add Named_Titles / Named_Snaps for more
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/retroarch-systems.sh"
command -v curl >/dev/null || { echo "curl not found"; exit 1; }

RECHECK=0; POS=()
for a in "$@"; do case "$a" in
  --recheck) RECHECK=1 ;;
  -*) echo "unknown option: $a"; exit 2 ;;
  *) POS+=("$a") ;;
esac; done

ROMS="${POS[0]:-}"
[ -z "$ROMS" ] && ROMS="$(ls -d /run/media/*/Emulation/roms 2>/dev/null | head -1)"
[ -n "$ROMS" ] && [ -d "$ROMS" ] || { echo "no roms dir found — pass it as arg 1"; exit 1; }
OUT="${POS[1]:-$HOME/.var/app/org.libretro.RetroArch/config/retroarch/thumbnails}"
TYPES="${THUMB_TYPES:-Named_Boxarts}"
BASE="https://thumbnails.libretro.com"
mkdir -p "$OUT"
MISSCACHE="$OUT/.thumb-misses"

# known-missing keys: games the DB had no art for, so we don't re-request them
declare -A MISS
[ "$RECHECK" -eq 1 ] && : > "$MISSCACHE"
[ -f "$MISSCACHE" ] && while IFS= read -r k; do [ -n "$k" ] && MISS["$k"]=1; done < "$MISSCACHE"

DISC_RE='\((dis[ck]|cd) *[0-9]+\)'
EXTS="chd m3u iso cue gdi pbp cso nes sfc smc fig swc gb gbc gba nds n64 z64 v64 md gen smd sms gg pce sg col int vec a78 lnx ws wsc ngp ngc 32x d64 adf dsk tap st zip"

# percent-encode for the URL (byte-wise so UTF-8 names encode correctly)
urlenc(){ local LC_ALL=C s=$1 o='' i ch hex; for ((i=0;i<${#s};i++)); do ch=${s:i:1}; case "$ch" in [a-zA-Z0-9._~-]) o+=$ch ;; *) printf -v hex '%%%02X' "'$ch"; o+=$hex ;; esac; done; printf '%s' "$o"; }
# RetroArch replaces these filename-illegal chars with _ in thumbnail names
sanitize(){ LC_ALL=C sed 's#[&*/:`<>?\\|"]#_#g' <<<"$1"; }

echo "ROMS: $ROMS"
echo "OUT : $OUT  (types: $TYPES)$( [ "$RECHECK" -eq 1 ] && echo '  [--recheck: ignoring miss-cache]' )"
echo
got=0; have=0; cached=0; newmiss=0
shopt -s nullglob
for sysdir in "$ROMS"/*/; do
  sysdir="${sysdir%/}"; sys="$(basename "$sysdir")"
  db="$(ra_db_name "$sys")"; [ -z "$db" ] && continue
  m3us=("$sysdir"/*.m3u); has_m3u=0; [ ${#m3us[@]} -gt 0 ] && has_m3u=1
  printf "== %-14s %s\n" "$sys" "$db"
  encdb="$(urlenc "$db")"
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"; ext="${base##*.}"; ext="${ext,,}"
    case " $EXTS " in *" $ext "*) ;; *) continue ;; esac
    if [ "$has_m3u" -eq 1 ] && [ "$ext" != "m3u" ] && printf '%s' "$base" | grep -qiE "$DISC_RE"; then continue; fi
    safe="$(sanitize "${base%.*}")"
    for t in $TYPES; do
      dest="$OUT/$db/$t/$safe.png"
      [ -f "$dest" ] && { have=$((have+1)); continue; }       # already downloaded
      key="$db|$t|$safe"
      [ -n "${MISS[$key]:-}" ] && { cached=$((cached+1)); continue; }   # known no-art
      if curl -fsSL --create-dirs -o "$dest" "$BASE/$encdb/$t/$(urlenc "$safe").png" 2>/dev/null; then
        got=$((got+1))
      else
        rm -f "$dest" 2>/dev/null
        MISS["$key"]=1; printf '%s\n' "$key" >> "$MISSCACHE"; newmiss=$((newmiss+1))
      fi
    done
  done < <(find "$sysdir" -maxdepth 1 -type f -print0)
done
echo
echo "Done. downloaded=$got  already-had=$have  known-missing(skipped)=$cached  newly-missing=$newmiss"
echo "Thumbnails: $OUT  (miss-cache: $MISSCACHE — re-run with --recheck to retry those)"
