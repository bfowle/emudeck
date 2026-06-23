#!/usr/bin/env bash
# full-sync.sh — ONE command, end to end:
#
#   PC:    import new ROMs -> .chd, rsync to the deck            (sync.sh)
#   deck:  regenerate RetroArch playlists + cover art           (over SSH)
#   deck:  update the Steam library via Steam ROM Manager's CLI (over SSH)
#
# Drop new "System Name/*.zip" sets into your TORRENTS folder, then run this.
# Everything is idempotent, so re-run it any time you add games.
#
# REQUIRES passwordless SSH to the deck — run `ssh-copy-id deck@$DECK_IP` once, or
# it will prompt for the deck password at every SSH step. Config comes from .env
# (DECK_IP, CARD, EMU_LIB, TORRENTS). Run it from Desktop mode / not mid-game: the
# SRM step closes Steam.
#
# Usage:  ./full-sync.sh [--no-srm] [--no-deck] [--no-import]
#   --no-import  skip import+transfer (just refresh playlists/art/Steam on the deck)
#   --no-deck    do only the PC import+transfer, stop before the deck-side steps
#   --no-srm     do playlists+art on the deck but skip the Steam ROM Manager step
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
if   [ -f "$ROOT/.env" ];     then . "$ROOT/.env"
elif [ -f "$HERE/sync.env" ]; then . "$HERE/sync.env"
fi
DECK_IP="${DECK_IP:-}"

NO_SRM=0; NO_DECK=0; NO_IMPORT=0
for a in "$@"; do case "$a" in
  --no-srm)    NO_SRM=1 ;;
  --no-deck)   NO_DECK=1 ;;
  --no-import) NO_IMPORT=1 ;;
  *) echo "unknown option: $a"; exit 2 ;;
esac; done

# 1) PC: import + transfer
if [ "$NO_IMPORT" -eq 0 ]; then
  echo "==> [1/2] PC: import + transfer"
  "$HERE/sync.sh"
else
  echo "==> [1/2] skipped (--no-import)"
fi

[ "$NO_DECK" -eq 1 ] && { echo; echo "(--no-deck) stopping after the PC half."; exit 0; }
[ -n "$DECK_IP" ] || { echo; echo "No DECK_IP in .env — can't run the deck-side steps."; exit 1; }

# 2) deck: push the helper scripts, then run them over SSH
echo
echo "==> [2/2] deck@$DECK_IP: playlists + thumbnails$( [ "$NO_SRM" -eq 0 ] && echo ' + Steam ROM Manager' )"
DST="emudeck-toolkit"
rsync -a \
  "$HERE/retroarch-systems.sh" \
  "$HERE/make-retroarch-playlists.sh" \
  "$HERE/get-retroarch-thumbnails.sh" \
  "$HERE/srm-add.sh" \
  "deck@$DECK_IP:$DST/"

REMOTE="set -e; chmod +x $DST/*.sh; $DST/make-retroarch-playlists.sh; $DST/get-retroarch-thumbnails.sh"
[ "$NO_SRM" -eq 0 ] && REMOTE="$REMOTE; $DST/srm-add.sh || echo '(SRM step needs attention — see message above)'"
ssh "deck@$DECK_IP" "$REMOTE"

echo
echo "Done. New games: imported -> transferred -> RetroArch playlists + art -> Steam library."
echo "Open Gaming Mode to play. (ES-DE users: nothing else needed — it auto-discovers.)"
