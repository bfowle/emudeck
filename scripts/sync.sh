#!/usr/bin/env bash
#
# sync.sh — one-command, idempotent library sync.
#
#   1) import any NEW ROM zips into the library  (import-zips.sh)
#   2) push the library to the deck              (transfer-to-deck.sh, rsync)
#
# Re-run it anytime — a year from now, after dropping one new game in. Both steps
# only touch what's new/changed, so it's safe and fast to run repeatedly.
#
# Config comes from ../.env (gitignored) if present; env vars / arg 1 override.
# See .env.example. Required: TORRENTS. For the push: DECK_IP + CARD.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# Prefer repo-root .env; fall back to legacy scripts/sync.env if that's all you have.
if   [ -f "$ROOT/.env" ];     then . "$ROOT/.env"
elif [ -f "$HERE/sync.env" ]; then . "$HERE/sync.env"
fi

TORRENTS="${1:-${TORRENTS:-}}"
EMU_LIB="${EMU_LIB:-$HOME/emustaging/Emulation}"
DECK_IP="${DECK_IP:-}"
CARD="${CARD:-}"
export EMU_LIB

[ -n "$TORRENTS" ] || { echo "Set TORRENTS (the dir of \"System Name/*.zip\" sets) in .env or as arg 1."; exit 1; }

echo "==> import-zips:  $TORRENTS  ->  $EMU_LIB/roms"
"$HERE/import-zips.sh" "$TORRENTS"

echo
if [ -n "$DECK_IP" ] && [ -n "$CARD" ]; then
  echo "==> transfer:  $EMU_LIB  ->  $DECK_IP:$CARD"
  "$HERE/transfer-to-deck.sh" "$DECK_IP" "$CARD"
else
  echo "(skipping push — set DECK_IP and CARD in .env to send to the deck)"
fi

echo
echo "Done. On the deck: open ES-DE (auto-finds new games), or re-run Steam ROM Manager"
echo "if you want the new titles in the Steam library proper."
