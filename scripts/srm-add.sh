#!/usr/bin/env bash
# srm-add.sh — update the Steam library via the Steam ROM Manager CLI `add`
# (no GUI). Runs ON THE DECK. Two things first:
#   1) set a per-console Steam category on every parser, so games group into
#      collections (Sony Playstation, Sega Dreamcast, …) instead of one flat list.
#   2) borrow the running Desktop session's FULL env — DISPLAY + XAUTHORITY +
#      DBUS_SESSION_BUS_ADDRESS + XDG_RUNTIME_DIR — because SRM is Electron and
#      `add` needs a display AND a session bus (missing dbus = it stalls silently).
#
# => For the SSH path the deck must be in DESKTOP MODE (so there's a Plasma session
#    to borrow). Steam is fully exited first (SRM's own requirement for categories).
# Fallbacks: an existing env (run from the deck's Konsole), xvfb-run, then a clear
# "do it in the GUI" message.
set -uo pipefail

SRM=""
for p in /run/media/*/Emulation/tools/Steam-ROM-Manager.AppImage \
         "$HOME/.config/EmuDeck/backend/tools/Steam-ROM-Manager.AppImage"; do
  [ -e "$p" ] && { SRM="$p"; break; }
done
[ -n "$SRM" ] || SRM="$(find /run/media "$HOME" -name 'Steam-ROM-Manager.AppImage' 2>/dev/null | head -1)"
[ -n "$SRM" ] && [ -e "$SRM" ] || { echo "Steam-ROM-Manager.AppImage not found — install it via EmuDeck first."; exit 1; }
chmod +x "$SRM" 2>/dev/null || true
echo "SRM: $SRM"

# 1) group games into per-console collections: steamCategory = each parser's
#    platform (the configTitle minus its trailing " - <emulator>"). Idempotent.
SRM_CFG="$HOME/.config/steam-rom-manager/userData/userConfigurations.json"
if [ -f "$SRM_CFG" ] && command -v python3 >/dev/null 2>&1; then
  python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
n = 0
for x in d:
    t = x.get("configTitle") or ""
    cat = t.rsplit(" - ", 1)[0] if " - " in t else t
    if cat and x.get("steamCategory") != cat:
        x["steamCategory"] = cat; n += 1
json.dump(d, open(p, "w"), indent=4)
print("  steamCategory set on %d parser(s) (group-by-console)" % n)
' "$SRM_CFG"
fi

# fully exit Steam (required for SRM to write categories)
if pidof steam >/dev/null 2>&1; then
  echo "closing Steam (required before SRM add)..."
  kill -15 $(pidof steam) 2>/dev/null || true
  for _ in $(seq 1 20); do pidof steam >/dev/null 2>&1 || break; sleep 1; done
  pidof steam >/dev/null 2>&1 && { echo "!! Steam still running — close it and re-run."; exit 2; }
fi

# borrow the running Desktop (Plasma/X11) session's full env
borrow_env(){
  local proc pid v val
  for proc in plasmashell kwin_x11 ksmserver kded5; do
    pid="$(pgrep -u "$(id -u)" -x "$proc" 2>/dev/null | head -1)"
    [ -n "$pid" ] || continue
    for v in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR; do
      val="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n "s/^$v=//p" | head -1)"
      [ -n "$val" ] && export "$v=$val"
    done
    [ -n "${DISPLAY:-}" ] && { echo "borrowed session env from $proc (pid $pid): DISPLAY=$DISPLAY"; return 0; }
  done
  return 1
}

run_add(){ "$SRM" --no-sandbox add; }

# 1) env already present (run from the deck's own Konsole)
if [ -n "${DISPLAY:-}" ] && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  echo "using existing session env (DISPLAY=$DISPLAY)"
  run_add && { echo "Done — added to Steam. Restart Steam to see them grouped + arted."; exit 0; }
fi
# 2) borrow the Desktop session (SSH + Desktop Mode)
if borrow_env; then
  run_add && { echo "Done — added to Steam. Restart Steam to see them grouped + arted."; exit 0; }
fi
# 3) virtual framebuffer
if command -v xvfb-run >/dev/null 2>&1; then
  echo "no desktop session; trying xvfb-run..."
  xvfb-run -a "$SRM" --no-sandbox add && { echo "Done (xvfb)."; exit 0; }
fi
echo
echo "!! SRM 'add' couldn't get a display (deck likely in Gaming Mode)."
echo "   Switch the deck to DESKTOP MODE and re-run, or on the deck run:"
echo "      ~/emudeck-toolkit/srm-add.sh"
echo "   or open EmuDeck -> Steam ROM Manager -> Generate app list -> Save to Steam."
exit 2
