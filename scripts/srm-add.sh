#!/usr/bin/env bash
# srm-add.sh — update the Steam library via the Steam ROM Manager CLI `add`
# (no GUI clicking). Runs ON THE DECK.
#
# SRM is an Electron app, so `add` needs an X display to initialize. Run over SSH
# there's none, so this borrows the running Desktop (Plasma/X11) session's display.
# Order tried:
#   1) a display already in the environment (i.e. run from the deck's own Konsole)
#   2) the running KDE/Plasma session's DISPLAY + XAUTHORITY  (SSH + DESKTOP MODE)
#   3) xvfb-run, if installed
#   4) clear fallback: run it on the deck / use the SRM GUI
#
# => For the SSH path to work, the deck must be in DESKTOP MODE (so there's a
#    desktop X session to attach to). Steam must be fully exited before `add`
#    (SRM's own requirement), so this closes it first.
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

# 1) a display already in the environment (run from the deck's own terminal)
if [ -n "${DISPLAY:-}" ]; then
  echo "using DISPLAY=$DISPLAY ..."
  "$SRM" --no-sandbox add && { echo "Done — apps added to Steam. Return to Gaming Mode to see them."; exit 0; }
fi

# 2) borrow the running Desktop session's DISPLAY + XAUTHORITY (SSH + Desktop Mode)
for proc in plasmashell kwin_x11 ksmserver kded5 Xorg; do
  pid="$(pgrep -u "$(id -u)" -x "$proc" 2>/dev/null | head -1)"
  [ -n "$pid" ] || continue
  d="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^DISPLAY=//p'    | head -1)"
  xa="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^XAUTHORITY=//p' | head -1)"
  [ -n "$d" ] || continue
  echo "borrowing display '$d' from $proc (pid $pid)${xa:+ with XAUTHORITY=$xa} ..."
  if DISPLAY="$d" ${xa:+XAUTHORITY="$xa"} "$SRM" --no-sandbox add; then
    echo "Done — apps added to Steam. Return to Gaming Mode to see them."
    exit 0
  fi
done

# 3) virtual framebuffer, if available
if command -v xvfb-run >/dev/null 2>&1; then
  echo "no usable desktop display; trying xvfb-run ..."
  xvfb-run -a "$SRM" --no-sandbox add && { echo "Done (via xvfb)."; exit 0; }
fi

# 4) fallback
echo
echo "!! SRM 'add' couldn't get an X display headless."
echo "   The deck is probably in Gaming Mode (no desktop X session to borrow)."
echo "   Fix: switch the deck to DESKTOP MODE and re-run, or on the deck run:"
echo "      ~/emudeck-toolkit/srm-add.sh         (from Konsole)"
echo "   or open EmuDeck -> Steam ROM Manager -> Generate app list -> Save to Steam."
exit 2
