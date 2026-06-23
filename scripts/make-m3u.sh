#!/usr/bin/env bash
#
# make-m3u.sh — generate .m3u playlists for multi-disc games so they show as a
# single entry and support in-game disc swapping.
#
# Detects files like:
#   Final Fantasy VIII (Disc 1).chd
#   Final Fantasy VIII (Disc 2).chd
# and writes "Final Fantasy VIII.m3u" listing the discs in order.
# Recognizes (Disc N) / (Disk N) / (CD N), case-insensitive.
#
# Usage:
#   ./make-m3u.sh <dir> [dir...]
#
set -uo pipefail
[ "$#" -ge 1 ] || { echo "usage: $0 <roms/system dir>..."; exit 1; }

for dir in "$@"; do
  [ -d "$dir" ] || { echo "no such dir: $dir"; continue; }
  echo "== $dir =="
  # Collect unique base names (title without the disc tag) for multi-disc sets.
  mapfile -t bases < <(
    find "$dir" -maxdepth 1 -type f \( -iname '*.chd' -o -iname '*.cue' -o -iname '*.iso' \) -printf '%f\n' \
      | grep -iE '\((dis[ck]|cd) *[0-9]+\)' \
      | sed -E 's/ *\((dis[ck]|cd) *[0-9]+\)[^.]*//I; s/\.[^.]+$//' \
      | sort -u
  )
  [ "${#bases[@]}" -gt 0 ] || { echo "  (no multi-disc sets found)"; continue; }

  for base in "${bases[@]}"; do
    m3u="$dir/$base.m3u"
    : > "$m3u"
    find "$dir" -maxdepth 1 -type f \( -iname "$base*disc*" -o -iname "$base*disk*" -o -iname "$base*cd*" \) \
        \( -iname '*.chd' -o -iname '*.cue' -o -iname '*.iso' \) -printf '%f\n' \
      | sort -V >> "$m3u"
    cnt=$(wc -l < "$m3u")
    echo "  wrote $(basename "$m3u")  ($cnt discs)"
  done
done
echo "Done. Launch the .m3u (not the individual discs)."
