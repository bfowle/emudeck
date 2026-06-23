#!/usr/bin/env bash
#
# make-rom-skeleton.sh — build an EmuDeck-style staging tree on your PC/WSL2.
#
# Creates  <DEST>/Emulation/roms/<system>/  for your target systems, plus a
# <DEST>/Emulation/bios/ folder. You organize ROMs/BIOS here OFF the deck, then
# push the contents to the deck after EmuDeck has created its own Emulation/.
#
# The folder names below follow the ES-DE / EmuDeck convention. EmuDeck creates
# the AUTHORITATIVE full set when it runs on the deck — if a name here doesn't
# match what EmuDeck made, just move that folder's files into EmuDeck's folder
# after the transfer. The live reference is the EmuDeck Cheat Sheet:
#   https://emudeck.github.io/cheat-sheet/
#
# Usage:
#   ./make-rom-skeleton.sh [LIBRARY_DIR]
# LIBRARY_DIR is the Emulation folder to create. Resolved as:
#   arg 1  >  $EMU_LIB  >  ~/emustaging/Emulation
# Point the whole toolkit at one place:  export EMU_LIB=/mnt/e/Emulation
#
set -euo pipefail

ROOT="${1:-${EMU_LIB:-$HOME/emustaging/Emulation}}"

# Target scope: retro through PS2/GC/Wii era (matches your plan).
SYSTEMS=(
  # --- Nintendo ---
  nes snes n64 gb gbc gba nds virtualboy gc wii
  # --- Sega ---
  mastersystem gamegear megadrive sega32x segacd saturn dreamcast
  # --- Sony ---
  psx ps2 psp
  # --- NEC ---
  pcengine pcenginecd supergrafx
  # --- SNK ---
  neogeo neogeocd ngp ngpc
  # --- Atari ---
  atari2600 atari5200 atari7800 atarilynx
  # --- Other consoles ---
  3do colecovision intellivision vectrex wonderswan wonderswancolor
  # --- Home computers ---
  msx c64 amiga zxspectrum
  # --- Arcade ---
  arcade mame fbneo
)

echo "Creating EmuDeck staging tree at: $ROOT"
mkdir -p "$ROOT/bios/dc"          # Dreamcast BIOS lives in bios/dc on EmuDeck
mkdir -p "$ROOT/saves"
for s in "${SYSTEMS[@]}"; do
  mkdir -p "$ROOT/roms/$s"
done

echo
echo "Done. Created ${#SYSTEMS[@]} system folders under: $ROOT/roms/"
echo "Put BIOS in: $ROOT/bios/   (Dreamcast -> $ROOT/bios/dc/)"
echo
echo "Next: drop legally-obtained ROMs into the matching roms/<system> folders,"
echo "then run compress-chd.sh on disc-based systems and check-bios.sh on bios/."
