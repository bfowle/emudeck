#!/usr/bin/env bash
#
# compress-chd.sh — batch-convert disc images to .chd with chdman (lossless,
# 50-70% smaller, natively supported by RetroArch/DuckStation/PCSX2/Flycast).
#
# Handles: .cue (+.bin), .gdi, .toc, and bare .iso
#   - CD-based systems (PS1, Saturn, Sega CD, TG-CD): default mode (createcd)
#   - DVD-based systems (PS2): pass --dvd  (createdvd)
#
# With --out DIR it READS from the input dir(s) and WRITES the .chd into DIR
# (e.g. compress straight from your old library into the staging tree — no
# giant raw copy first). Source files are left untouched.
#
# NOT handled: Dreamcast .cdi (chdman can't read DiscJuggler images) — Flycast
# plays .cdi directly, so just copy those as-is. GameCube/Wii use RVZ (Dolphin).
#
# Usage:
#   ./compress-chd.sh [--dvd] [--out DIR] [--delete] <dir> [dir...]
#     --dvd       treat .iso as DVD (PS2)
#     --out DIR   write .chd into DIR instead of next to the source
#     --delete    remove SOURCE files after a verified convert (ignored with --out)
#
set -uo pipefail
trap 'echo; echo "Interrupted."; exit 130' INT TERM

command -v chdman >/dev/null 2>&1 || { echo "chdman not found — run ./setup-tools.sh first."; exit 1; }

MODE=createcd; DELETE=0; OUT=""; DIRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dvd)    MODE=createdvd ;;
    --delete) DELETE=1 ;;
    --out)    OUT="${2:?--out needs a directory}"; shift ;;
    *)        DIRS+=("$1") ;;
  esac
  shift
done
[ "${#DIRS[@]}" -gt 0 ] || { echo "usage: $0 [--dvd] [--out DIR] [--delete] <dir>..."; exit 1; }

if [ -n "$OUT" ]; then
  mkdir -p "$OUT"
  [ "$DELETE" -eq 1 ] && { echo "(ignoring --delete: refusing to delete the source library when --out is set)"; DELETE=0; }
fi

convert() {
  local in="$1" out base
  base="$(basename "${in%.*}")"
  if [ -n "$OUT" ]; then out="$OUT/$base.chd"; else out="${in%.*}.chd"; fi
  [ -f "$out" ] && { echo "  exists, skip: $base.chd"; return 0; }
  echo "  -> $base.chd"
  if chdman "$MODE" -i "$in" -o "$out"; then
    if [ "$DELETE" -eq 1 ]; then
      case "$in" in
        *.cue|*.gdi|*.toc)
          local d; d="$(dirname "$in")"
          # remove the track files the sheet references (quoted names -> spaces OK)
          sed -nE 's/.*"([^"]+\.(bin|img|iso|raw))".*/\1/Ip' "$in" 2>/dev/null \
            | while IFS= read -r trk; do [ -n "$trk" ] && rm -f "$d/$trk"; done
          ;;
      esac
      rm -f "$in"   # removes the sheet/iso (a symlink in the staging workflow)
    fi
  else
    echo "  !! FAILED: $in"; rm -f "$out"
  fi
}

for dir in "${DIRS[@]}"; do
  [ -d "$dir" ] || { echo "no such dir: $dir"; continue; }
  echo "== $dir (mode=$MODE${OUT:+, out=$OUT}) =="
  # cue/gdi/toc first (they reference their own tracks)...
  while IFS= read -r -d '' f; do convert "$f"; done \
    < <(find "$dir" -type f \( -iname '*.cue' -o -iname '*.gdi' -o -iname '*.toc' \) -print0)
  # ...then bare .iso that aren't part of a .cue set
  while IFS= read -r -d '' f; do
    [ -f "${f%.*}.cue" ] && continue
    convert "$f"
  done < <(find "$dir" -type f -iname '*.iso' -print0)
done
echo "Done."
