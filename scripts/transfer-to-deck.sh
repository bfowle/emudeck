#!/usr/bin/env bash
#
# transfer-to-deck.sh — push your staged ROMs/BIOS to the Steam Deck over SSH
# with rsync (resumable, only copies what changed). Far better than GUI tools
# for a big library.
#
# ON THE DECK FIRST (one time):
#   1) Desktop Mode -> Konsole -> `passwd` to set a password.
#   2) `sudo systemctl enable --now sshd`   (enable SSH server)
#   3) Find its IP: `ip route get 1 | awk '{print $7; exit}'`
#   4) Run EmuDeck once so the Emulation/ folder exists on the SD card.
#      Newer SteamOS path: /run/media/<CARD-LABEL>/Emulation  (older: /run/media/deck/<LABEL>)
#      (find it with:  ls -d /run/media/*/Emulation )
#
# Usage:
#   ./transfer-to-deck.sh <deck-ip> <deck-Emulation-path> [SRC Emulation dir]
# Example:
#   ./transfer-to-deck.sh 192.168.1.42 /run/media/<CARD-LABEL>/Emulation
#
# Default SRC = $EMU_LIB  (else ~/emustaging/Emulation)
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Defaults from repo-root .env (DECK_IP, CARD, EMU_LIB); positional args override.
# So after .env is set, this can run with no args:  ./transfer-to-deck.sh
ROOT="$(cd "$HERE/.." && pwd)"
if   [ -f "$ROOT/.env" ];     then . "$ROOT/.env"
elif [ -f "$HERE/sync.env" ]; then . "$HERE/sync.env"
fi
IP="${1:-${DECK_IP:-}}";   [ -n "$IP" ]     || { echo "usage: $0 <deck-ip> <deck-Emulation-path> [src]   (or set DECK_IP in .env)"; exit 1; }
REMOTE="${2:-${CARD:-}}";  [ -n "$REMOTE" ] || { echo "give the deck Emulation path as arg 2, or set CARD in .env"; exit 1; }
SRC="${3:-${EMU_LIB:-$HOME/emustaging/Emulation}}"

[ -d "$SRC/roms" ] || { echo "No $SRC/roms — build/import your staging tree first."; exit 1; }

echo "Pushing roms/ and bios/ from $SRC  ->  deck@$IP:$REMOTE"
echo "(Tip: dock the deck + use the Dock's Ethernet for max speed.)"
echo

# -L (--copy-links) follows symlinks and copies the REAL files. import-roms.sh
# stages cart ROMs as symlinks into your library, so -L is what actually moves
# the bytes to the deck. Trailing slashes copy the CONTENTS of roms/ and bios/.
rsync -avL --progress --partial --human-readable \
  "$SRC/roms/" "deck@$IP:$REMOTE/roms/"

if [ -d "$SRC/bios" ]; then
  rsync -avL --progress --partial --human-readable \
    "$SRC/bios/" "deck@$IP:$REMOTE/bios/"
fi

echo
echo "Done. On the deck: open the EmuDeck app -> BIOS Checker, then Steam ROM"
echo "Manager to add the games to Steam, and ES-DE to browse them."
