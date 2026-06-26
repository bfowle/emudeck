#!/usr/bin/env bash
# finish-steam.sh — the post-SRM finish, run FROM THE PC after you've done the
# Steam ROM Manager "Save to Steam" GUI step on the deck (Desktop Mode).
#
# Encapsulates the whole "B)" sequence so you can't miss the one precondition that
# bites every time: Steam must be CLOSED, or it rewrites shortcuts.vdf on exit and
# silently clobbers the de-dupe. Steam is usually still running right after a SRM
# "Save to Steam", so this shuts it down first.
#
#   close Steam  ->  de-dupe multi-disc  ->  artwork (box art + SteamGridDB)  ->  (you) restart Steam
#
# Both Python steps are idempotent — safe to re-run after adding more games.
# Steam restart is left to you: relaunching over SSH in Desktop Mode is flaky, and
# you're right there at the deck. Config from .env (DECK_IP, SGDB_KEY).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
if   [ -f "$ROOT/.env" ];     then . "$ROOT/.env"
elif [ -f "$HERE/sync.env" ]; then . "$HERE/sync.env"
fi
DECK_IP="${DECK_IP:-}"
SGDB_KEY="${SGDB_KEY:-}"
DST="emudeck-toolkit"
[ -n "$DECK_IP" ] || { echo "No DECK_IP in .env — nothing to talk to."; exit 1; }

# Make the two scripts present on the deck even if full-sync wasn't run this batch.
rsync -a "$HERE/fix-multidisc.py" "$HERE/set-steam-art.py" "deck@$DECK_IP:$DST/"

echo "==> closing Steam on the deck (it rewrites shortcuts.vdf on exit)…"
ssh "deck@$DECK_IP" '
  if pgrep -x steam >/dev/null; then
    steam -shutdown >/dev/null 2>&1 || true
    for i in $(seq 1 20); do pgrep -x steam >/dev/null || break; sleep 1; done
  fi
  if pgrep -x steam >/dev/null; then
    echo "  Steam still running — close it manually and re-run."; exit 1
  fi
  echo "  Steam closed."
'

echo "==> de-dupe multi-disc (keep one entry per game, prefer the .m3u)…"
ssh "deck@$DECK_IP" "python3 $DST/fix-multidisc.py"

echo "==> artwork — portrait tiles (box art) + Hero/Logo (SteamGridDB, batched)…"
if [ -z "$SGDB_KEY" ]; then
  echo "  (no SGDB_KEY in .env — tiles only; add a free key for Hero/Logo)"
fi
ssh "deck@$DECK_IP" "SGDB_KEY='$SGDB_KEY' python3 $DST/set-steam-art.py"

echo
echo "Done. Restart Steam on the deck to see covers, hero art, folders, and the"
echo "single multi-disc entries. (ES-DE users don't need any of this.)"
