#!/usr/bin/env bash
#
# zip-status.sh — READ-ONLY report: which zips are imported (a .chd exists) vs
# still pending, and WHY pending. Touches nothing — no extract, no delete.
#
# "Pending" is your effective to-do list. A complete disc zip always becomes a
# .chd, so the only zips that stay pending are:
#   • downloading (0-byte / truncated)  -> finish the torrent, re-run import-zips
#   • READY (valid, not imported yet)   -> just run import-zips
#   • no disc image inside              -> needs a look
#
# Defaults (from ../.env if present):  input=$TORRENTS  dest=$EMU_LIB/roms
#
# Usage:
#   ./zip-status.sh [input-dir] [dest-roms-dir]
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/systems.sh"
# Prefer repo-root .env; fall back to legacy scripts/sync.env if that's all you have.
if   [ -f "$ROOT/.env" ];     then . "$ROOT/.env"
elif [ -f "$HERE/sync.env" ]; then . "$HERE/sync.env"
fi
# 7z (p7zip) is more robust than Info-ZIP unzip for large/odd archives and its
# exit code cleanly flags a still-downloading zip (missing central directory).
command -v 7z >/dev/null || { echo "7z not found — run ./setup-tools.sh (p7zip)"; exit 1; }

INPUT="${1:-${TORRENTS:-}}"
DEST="${2:-${EMU_LIB:-$HOME/emustaging/Emulation}/roms}"
[ -n "$INPUT" ] || { echo "usage: $0 <input-dir> [dest-roms-dir]   (or set TORRENTS in .env)"; exit 1; }
[ -d "$INPUT" ] || { echo "no such input dir: $INPUT"; exit 1; }

echo "ZIPS : $INPUT"
echo "CHD  : $DEST"
echo

gtot=0; gdone=0; gpend=0; gdl=0
shopt -s nullglob
# system folders at any depth (flat, or nested under Redump/ + No-Intro/ like Myrient)
while IFS= read -r -d '' sysdir; do
  folder="$(basename "$sysdir")"
  sys="$(map_system "$folder")"
  [ -z "$sys" ] && { printf "  ?  UNMAPPED  %s\n" "$folder"; continue; }
  zips=("$sysdir"/*.zip); [ ${#zips[@]} -eq 0 ] && continue
  out="$DEST/$sys"
  tot=${#zips[@]}; done=0; pend=0; lines=()
  for z in "${zips[@]}"; do
    game="$(basename "$z" .zip)"
    if [ -f "$out/$game.chd" ] || [ -f "$out/$(basename "$z")" ]; then done=$((done+1)); continue; fi
    pend=$((pend+1)); sz="$(du -h "$z" 2>/dev/null | cut -f1)"
    if   [ ! -s "$z" ];                       then tag="downloading (0 bytes)";  gdl=$((gdl+1))
    elif ! 7z l "$z" >/dev/null 2>&1;         then tag="downloading (partial)";  gdl=$((gdl+1))
    elif 7z l -slt "$z" 2>/dev/null | grep -qiE '^Path = .*\.(cue|gdi|toc|iso)$'; then tag="READY — run import-zips"
    else                                           tag="no disc image inside — check"
    fi
    lines+=("      - $game  ($sz)  [$tag]")
  done
  printf "  %-12s %d/%d imported%s\n" "$sys" "$done" "$tot" "$( [ "$pend" -gt 0 ] && printf "  (%d pending)" "$pend" )"
  for l in "${lines[@]}"; do echo "$l"; done
  gtot=$((gtot+tot)); gdone=$((gdone+done)); gpend=$((gpend+pend))
done < <(find "$INPUT" -type f -name '*.zip' -printf '%h\0' | sort -zu)

echo
echo "TOTAL: $gdone/$gtot imported, $gpend pending ($gdl still downloading)."
