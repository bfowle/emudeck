#!/usr/bin/env bash
#
# check-bios.sh — checklist for the BIOS/firmware files your in-scope systems
# need, and whether they're present in your staging bios/ folder.
#
# This ONLY checks for expected filenames — it never downloads anything. You
# must supply your own legally-dumped BIOS. The deck's built-in EmuDeck "BIOS
# Checker" is the final authority (it also verifies checksums); this is the
# off-deck pre-check so you don't transfer an incomplete set.
#
# Usage:
#   ./check-bios.sh [BIOS_DIR]
# BIOS_DIR resolved as:  arg 1  >  $EMU_LIB/bios  >  ~/emustaging/Emulation/bios
#
set -uo pipefail
BIOS="${1:-${EMU_LIB:-$HOME/emustaging/Emulation}/bios}"

# system | relative/path/filename | required(yes/no) | note
ENTRIES=(
  "PS1   | scph5501.bin           | one-of | US BIOS (or scph5500 JP / scph5502 EU)"
  "PS1   | scph5500.bin           | one-of | JP BIOS"
  "PS1   | scph5502.bin           | one-of | EU BIOS"
  "PS2   | ps2-0230a-20080220.bin | maybe  | filename varies; any official PS2 BIOS .bin"
  "Saturn| sega_101.bin           | one-of | JP BIOS (or mpr-17933 US/EU)"
  "Saturn| mpr-17933.bin          | one-of | US/EU BIOS"
  "SegaCD| bios_CD_U.bin          | one-of | US (or bios_CD_E EU / bios_CD_J JP)"
  "SegaCD| bios_CD_E.bin          | one-of | EU"
  "SegaCD| bios_CD_J.bin          | one-of | JP"
  "DC    | dc/dc_boot.bin         | yes    | Dreamcast boot ROM (in bios/dc/)"
  "DC    | dc/dc_flash.bin        | yes    | Dreamcast flash (in bios/dc/)"
  "PSP   | ppsspp                 | no     | PPSSPP needs NO BIOS"
  "NES   | disksys.rom            | fds    | only for Famicom Disk System games"
  "GBA   | gba_bios.bin           | no     | optional; improves accuracy"
)

echo "Checking BIOS in: $BIOS"
echo
printf "%-7s %-26s %-7s %s\n" "SYS" "FILE" "STATUS" "NOTE"
printf '%s\n' "----------------------------------------------------------------------------"
miss_required=0
for e in "${ENTRIES[@]}"; do
  IFS='|' read -r sys file req note <<<"$e"
  sys="${sys// /}"; file="${file// /}"; req="${req// /}"
  note="${note#"${note%%[![:space:]]*}"}"
  if [ -f "$BIOS/$file" ]; then status="FOUND"
  else
    status="missing"
    [ "$req" = "yes" ] && { status="MISSING*"; miss_required=1; }
  fi
  printf "%-7s %-26s %-7s %s\n" "$sys" "$file" "$status" "$note"
done
echo
echo "Legend: one-of = at least one regional variant needed; maybe/fds/no = situational."
echo "        * = a strictly required file is missing."
[ "$miss_required" -eq 1 ] && echo "NOTE: required Dreamcast files missing — Flycast won't boot without them."
echo "Place most BIOS flat in $BIOS/ ; Dreamcast goes in $BIOS/dc/."
