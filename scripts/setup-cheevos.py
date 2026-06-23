#!/usr/bin/env python3
# setup-cheevos.py — log RetroAchievements into the deck's emulators without the
# on-screen keyboard. Reads your RA login from $RA_USER/$RA_PASS, or from RetroArch's
# config if you've set it there, fetches a session token from the RetroAchievements
# API, and writes it (SOFTCORE) into RetroArch, DuckStation, and Flycast — both the
# live configs and EmuDeck's backend copies. Runs ON THE DECK. Re-runnable.
#
#   RA_USER=name RA_PASS=pw python3 setup-cheevos.py
#   (or just `python3 setup-cheevos.py` if cheevos_username/password are in retroarch.cfg)
#
# Add other RA-capable emulators (PCSX2, PPSSPP, Dolphin) to the writers at the bottom
# as you bring those systems online.
import re, json, os, sys, urllib.parse, urllib.request

HOME = os.path.expanduser("~")
RA_CFGS = [
    f"{HOME}/.var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg",
    f"{HOME}/.config/EmuDeck/backend/configs/org.libretro.RetroArch/config/retroarch/retroarch.cfg",
]

def ra_get(key):
    for p in RA_CFGS:
        try:
            for line in open(p):
                m = re.match(r'^%s\s*=\s*"(.*)"' % re.escape(key), line)
                if m and m.group(1):
                    return m.group(1)
        except FileNotFoundError:
            pass
    return None

user = os.environ.get("RA_USER") or ra_get("cheevos_username")
pw   = os.environ.get("RA_PASS") or ra_get("cheevos_password")
if not user or not pw:
    sys.exit("ERROR: set RA_USER/RA_PASS, or cheevos_username/password in retroarch.cfg")

def get_token():
    base = "https://retroachievements.org/dorequest.php"
    for r in ("login2", "login"):
        try:
            data = urllib.parse.urlencode({"r": r, "u": user, "p": pw}).encode()
            # NB: RetroAchievements rejects the default python-urllib User-Agent.
            req = urllib.request.Request(base, data=data, headers={"User-Agent": "RetroArch/1.0"})
            with urllib.request.urlopen(req, timeout=25) as resp:
                j = json.load(resp)
            if j.get("Success") and j.get("Token"):
                return j["Token"]
        except Exception:
            pass
    return None

token = get_token()
if not token:
    sys.exit("ERROR: RetroAchievements login failed (check username/password).")
print("RA login OK for '%s' — token acquired." % user)

def write_retroarch(path):
    if not os.path.exists(path):
        return "missing"
    want = {"cheevos_enable": '"true"', "cheevos_username": '"%s"' % user,
            "cheevos_token": '"%s"' % token, "cheevos_password": '""',
            "cheevos_hardcore_mode_enable": '"false"'}
    seen, out = set(), []
    for ln in open(path).read().splitlines():
        m = re.match(r'^(\w+)\s*=', ln)
        if m and m.group(1) in want:
            out.append("%s = %s" % (m.group(1), want[m.group(1)])); seen.add(m.group(1))
        else:
            out.append(ln)
    for k, v in want.items():
        if k not in seen:
            out.append("%s = %s" % (k, v))
    open(path, "w").write("\n".join(out) + "\n")
    return "ok"

def write_ini(path, section, kv):
    if not os.path.exists(path):
        return "missing"
    out, in_sec, done, found = [], False, set(), False
    for ln in open(path).read().splitlines():
        if re.match(r'^\[.*\]\s*$', ln):
            if in_sec:
                for k, v in kv.items():
                    if k not in done:
                        out.append("%s = %s" % (k, v))
            in_sec = (ln.strip() == "[%s]" % section)
            if in_sec:
                found = True
            out.append(ln); continue
        if in_sec:
            m = re.match(r'^\s*([\w.]+)\s*=', ln)
            if m and m.group(1) in kv:
                out.append("%s = %s" % (m.group(1), kv[m.group(1)])); done.add(m.group(1)); continue
        out.append(ln)
    if in_sec:
        for k, v in kv.items():
            if k not in done:
                out.append("%s = %s" % (k, v))
    if not found:
        out.append("[%s]" % section)
        for k, v in kv.items():
            out.append("%s = %s" % (k, v))
    open(path, "w").write("\n".join(out) + "\n")
    return "ok"

jobs = []
for p in RA_CFGS:
    jobs.append(("RetroArch", p, write_retroarch(p)))
ds = {"Enabled": "true", "Username": user, "Token": token, "ChallengeMode": "false"}
for p in [f"{HOME}/.local/share/duckstation/settings.ini",
          f"{HOME}/.config/EmuDeck/backend/configs/duckstation/settings.ini"]:
    jobs.append(("DuckStation", p, write_ini(p, "Cheevos", ds)))
fc = {"Achievements.Enabled": "yes", "Achievements.HardcoreMode": "no",
      "Achievements.Token": token, "Achievements.UserName": user}
for p in [f"{HOME}/.var/app/org.flycast.Flycast/config/flycast/emu.cfg",
          f"{HOME}/.config/EmuDeck/backend/configs/org.flycast.Flycast/config/flycast/emu.cfg"]:
    jobs.append(("Flycast", p, write_ini(p, "config", fc)))

for emu, p, st in jobs:
    print("  %-11s %-4s %s" % (emu, st, p))
print("DONE — RetroAchievements (softcore) configured. Relaunch a game to see the login popup.")
