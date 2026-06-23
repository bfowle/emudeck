#!/usr/bin/env bash
# srm-add.sh — update the Steam library from Steam ROM Manager's CLI (headless),
# running the already-enabled parsers. Runs ON THE DECK. No GUI clicking.
#
# SRM's own help says Steam must be FULLY EXITED before `add` (else categories
# aren't written), so this closes Steam and waits for it to die first. It does NOT
# touch which parsers are enabled — it just runs whatever EmuDeck already set up.
#
# Falls back to a clear "do it in the GUI" message if the CLI can't run here.
set -uo pipefail

# locate the AppImage EmuDeck installed (tools live on the SD card)
SRM=""
for p in /run/media/*/Emulation/tools/Steam-ROM-Manager.AppImage \
         "$HOME/.config/EmuDeck/backend/tools/Steam-ROM-Manager.AppImage"; do
  [ -e "$p" ] && { SRM="$p"; break; }
done
[ -n "$SRM" ] || SRM="$(find /run/media "$HOME" -name 'Steam-ROM-Manager.AppImage' 2>/dev/null | head -1)"
[ -n "$SRM" ] && [ -e "$SRM" ] || { echo "Steam-ROM-Manager.AppImage not found — open EmuDeck → Steam ROM Manager once to install it."; exit 1; }
chmod +x "$SRM" 2>/dev/null || true
echo "SRM: $SRM"

# fully exit Steam (required for SRM to write categories)
if pidof steam >/dev/null 2>&1; then
  echo "closing Steam (required before SRM add)..."
  kill -15 $(pidof steam) 2>/dev/null || true
  for _ in $(seq 1 20); do pidof steam >/dev/null 2>&1 || break; sleep 1; done
  pidof steam >/dev/null 2>&1 && { echo "!! Steam still running — close it and re-run."; exit 2; }
fi

echo "Running SRM 'add' (enabled parsers -> Steam)..."
if "$SRM" --no-sandbox add; then
  echo "Done — apps added to Steam. Return to Gaming Mode (or restart Steam) to see them."
  exit 0
fi

echo "!! SRM 'add' failed running headless."
if command -v xvfb-run >/dev/null 2>&1; then
  echo "   retrying under a virtual display (xvfb-run)..."
  xvfb-run -a "$SRM" --no-sandbox add && { echo "Done (via xvfb)."; exit 0; }
fi
echo "   Fallback: open EmuDeck -> Steam ROM Manager -> Generate app list -> Save to Steam."
exit 2
