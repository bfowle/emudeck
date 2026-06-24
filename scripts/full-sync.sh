#!/usr/bin/env bash
# full-sync.sh — one command to bring new ROMs all the way to the deck:
#
#   PC:    import new ROMs -> .chd, rsync to the deck        (sync.sh)
#   deck:  regenerate RetroArch playlists + cover art        (over SSH)
#   deck:  Steam ROM Manager -> a GUI step (printed at the end, see why below)
#
# Why the Steam step is GUI: SRM's CLI `add` only fetches the LANDSCAPE "recent"
# art (not the vertical library tiles, hero, or logo) and can't write the
# per-console collections. Only the GUI "Save to Steam" produces the complete
# result. So full-sync automates everything headless and then prints the exact
# GUI steps. (--srm-cli opts into the incomplete CLI add if you want it anyway.)
#
# REQUIRES passwordless SSH (`ssh-copy-id deck@$DECK_IP`) and the deck in DESKTOP
# MODE. Config from .env (DECK_IP, CARD, EMU_LIB, TORRENTS).
#
# Usage:  ./full-sync.sh [--srm-cli] [--no-deck] [--no-import]
#   --no-import  skip import+transfer (just refresh the deck side)
#   --no-deck    do only the PC import+transfer
#   --srm-cli    also run SRM's CLI add (incomplete art, no collections)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
if   [ -f "$ROOT/.env" ];     then . "$ROOT/.env"
elif [ -f "$HERE/sync.env" ]; then . "$HERE/sync.env"
fi
DECK_IP="${DECK_IP:-}"

SRM_CLI=0; NO_DECK=0; NO_IMPORT=0
for a in "$@"; do case "$a" in
  --srm-cli)   SRM_CLI=1 ;;
  --no-deck)   NO_DECK=1 ;;
  --no-import) NO_IMPORT=1 ;;
  *) echo "unknown option: $a"; exit 2 ;;
esac; done

# 1) PC: import + transfer
if [ "$NO_IMPORT" -eq 0 ]; then
  echo "==> [1/3] PC: import + transfer"
  "$HERE/sync.sh"
else
  echo "==> [1/3] skipped (--no-import)"
fi

[ "$NO_DECK" -eq 1 ] && { echo; echo "(--no-deck) stopping after the PC half."; exit 0; }
[ -n "$DECK_IP" ] || { echo; echo "No DECK_IP in .env — can't run the deck-side steps."; exit 1; }

# 2) deck: playlists + cover art (and optionally the incomplete SRM CLI add)
echo
echo "==> [2/3] deck@$DECK_IP: RetroArch playlists + cover art"
DST="emudeck-toolkit"
rsync -a \
  "$HERE/retroarch-systems.sh" "$HERE/make-retroarch-playlists.sh" \
  "$HERE/get-retroarch-thumbnails.sh" "$HERE/srm-add.sh" \
  "deck@$DECK_IP:$DST/"
REMOTE="set -e; chmod +x $DST/*.sh; $DST/make-retroarch-playlists.sh; $DST/get-retroarch-thumbnails.sh"
[ "$SRM_CLI" -eq 1 ] && REMOTE="$REMOTE; echo; echo '(--srm-cli) SRM CLI add — landscape art only, no collections:'; $DST/srm-add.sh || true"
ssh "deck@$DECK_IP" "$REMOTE"

# 3) Steam library: GUI step
echo
echo "==> [3/3] Steam library — finish in Steam ROM Manager (GUI, on the deck):"
echo
echo "    SRM's GUI is the only reliable way to add games with FULL artwork"
echo "    (library tiles + hero) and per-console collections. In Desktop Mode:"
echo
echo "      1. EmuDeck app  ->  Steam ROM Manager        (it closes Steam)"
echo "      2. top tab: Preview  ->  Generate app list   (uses cached art; a few min)"
echo "      3. Save to Steam"
echo "      4. Return to Gaming Mode (restart Steam if art/folders lag)"
echo
echo "Done. Import + transfer + playlists + art are automated; the SRM GUI save above"
echo "lights up the games, full artwork, and collections in Gaming Mode."
echo "(ES-DE users: nothing else needed — ES-DE auto-discovers new games.)"
