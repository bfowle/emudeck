#!/usr/bin/env bash
# make-retroarch-playlists.sh — generate RetroArch .lpl playlists from a roms tree.
# Runs ON THE DECK (the paths written into the playlists are deck paths). One .lpl
# per roms/<system> folder, named with RetroArch's exact database name so the
# thumbnails (get-retroarch-thumbnails.sh) line up. core = DETECT (RetroArch picks
# or asks on first launch). Multi-disc: the .m3u is listed and its loose "(Disc N)"
# members are skipped, so the game shows once.
#
# Idempotent: rebuilds the playlists from the current roms tree on every run.
#
# Usage:  ./make-retroarch-playlists.sh [roms-dir] [playlists-out-dir]
#   roms-dir default: auto-detected /run/media/*/Emulation/roms
#   out-dir  default: ~/.var/app/org.libretro.RetroArch/config/retroarch/playlists
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/retroarch-systems.sh"

ROMS="${1:-}"
[ -z "$ROMS" ] && ROMS="$(ls -d /run/media/*/Emulation/roms 2>/dev/null | head -1)"
[ -n "$ROMS" ] && [ -d "$ROMS" ] || { echo "no roms dir found — pass it as arg 1"; exit 1; }
OUT="${2:-$HOME/.var/app/org.libretro.RetroArch/config/retroarch/playlists}"
mkdir -p "$OUT"

json_esc(){ local s=$1; s=${s//\\/\\\\}; s=${s//\"/\\\"}; printf '%s' "$s"; }

DISC_RE='\((dis[ck]|cd) *[0-9]+\)'
# file extensions RetroArch can load (lowercase, no dot)
EXTS="chd m3u iso cue gdi pbp cso nes sfc smc fig swc gb gbc gba nds n64 z64 v64 md gen smd sms gg pce sg col int vec a78 lnx ws wsc ngp ngc 32x d64 adf dsk tap st zip"

echo "ROMS: $ROMS"
echo "OUT : $OUT"
echo
shopt -s nullglob
total_pl=0; total_games=0
for sysdir in "$ROMS"/*/; do
  sysdir="${sysdir%/}"; sys="$(basename "$sysdir")"
  db="$(ra_db_name "$sys")"
  [ -z "$db" ] && { printf "  ?  unmapped, skipping: %s\n" "$sys"; continue; }

  m3us=("$sysdir"/*.m3u); has_m3u=0; [ ${#m3us[@]} -gt 0 ] && has_m3u=1

  items=();
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"; ext="${base##*.}"; ext="${ext,,}"
    case " $EXTS " in *" $ext "*) ;; *) continue ;; esac
    # when an .m3u exists, skip its loose (Disc N) members so the set shows once
    if [ "$has_m3u" -eq 1 ] && [ "$ext" != "m3u" ] && printf '%s' "$base" | grep -qiE "$DISC_RE"; then
      continue
    fi
    label="${base%.*}"
    items+=("$(printf '    {\n      "path": "%s",\n      "label": "%s",\n      "core_path": "DETECT",\n      "core_name": "DETECT",\n      "crc32": "DETECT",\n      "db_name": "%s.lpl"\n    }' \
      "$(json_esc "$f")" "$(json_esc "$label")" "$(json_esc "$db")")")
  done < <(find "$sysdir" -maxdepth 1 -type f -print0 | sort -z)

  [ ${#items[@]} -eq 0 ] && { printf "  -- %-30s (no games)\n" "$sys"; continue; }

  {
    printf '{\n'
    printf '  "version": "1.5",\n'
    printf '  "default_core_path": "",\n'
    printf '  "default_core_name": "",\n'
    printf '  "label_display_mode": 0,\n'
    printf '  "right_thumbnail_mode": 0,\n'
    printf '  "left_thumbnail_mode": 0,\n'
    printf '  "sort_mode": 0,\n'
    printf '  "items": [\n'
    for ((k=0; k<${#items[@]}; k++)); do
      [ "$k" -gt 0 ] && printf ',\n'
      printf '%s' "${items[k]}"
    done
    printf '\n  ]\n}\n'
  } > "$OUT/$db.lpl"

  printf "  ✓  %-34s %4d games\n" "$db.lpl" "${#items[@]}"
  total_pl=$((total_pl+1)); total_games=$((total_games+${#items[@]}))
done
echo
echo "Wrote $total_pl playlist(s), $total_games games -> $OUT"
echo "In RetroArch they appear as system playlists on the main menu."
