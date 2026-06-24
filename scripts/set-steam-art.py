#!/usr/bin/env python3
# set-steam-art.py — fill in Steam artwork for SRM-added games that SRM leaves blank.
# Runs ON THE DECK, after Steam ROM Manager. Idempotent. Restart Steam afterwards.
#
#   Portrait library tiles  <- your RetroArch box art (keyless, instant)
#   Hero + Logo + any gaps   <- SteamGridDB   ($SGDB_KEY, free key)
#
# Files use Steam's 32-bit shortcut AppID (what Steam actually reads):
#   <appid>p.png (portrait/tile)   <appid>_hero.*   <appid>_logo.*
#
# SteamGridDB art lookups are BATCHED (comma-separated game IDs, 50/request), so the
# whole library costs only a few hundred API calls instead of thousands.
#
# Usage:  SGDB_KEY=xxxx python3 set-steam-art.py   |   python3 set-steam-art.py (tiles only)
# Free key: steamgriddb.com -> sign in with Steam -> Preferences -> API -> generate.
import os, glob, struct, re, shutil, json, urllib.parse, urllib.request

KEY = os.environ.get("SGDB_KEY", "").strip()
cfg = glob.glob(os.path.expanduser("~/.steam/steam/userdata/*/config"))
if not cfg:
    raise SystemExit("no Steam userdata config dir found")
cfg = cfg[0]
vdf, grid = cfg + "/shortcuts.vdf", cfg + "/grid"
if not os.path.exists(vdf):
    raise SystemExit("no shortcuts.vdf — run Steam ROM Manager first")
os.makedirs(grid, exist_ok=True)

# shortcuts.vdf -> {appid(32-bit): AppName}
data = open(vdf, "rb").read()
AK = b"\x01appname\x00"
sc, i = {}, 0
while True:
    j = data.find(b"\x02appid\x00", i)
    if j < 0:
        break
    a = struct.unpack("<I", data[j + 7:j + 11])[0]
    k = data.lower().find(AK, j)
    nm = ""
    if 0 <= k < j + 600:
        s = k + len(AK); e = data.find(b"\x00", s)
        nm = data[s:e].decode("utf-8", "ignore")
    sc[a] = nm
    i = j + 11

def norm(s):
    return re.sub(r"[^a-z0-9]+", "", re.sub(r"\(.*?\)|\[.*?\]", "", s).lower())
def clean(s):
    return re.sub(r"\s+", " ", re.sub(r"\(.*?\)|\[.*?\]", "", s)).strip()

thumbs = os.path.expanduser("~/.var/app/org.libretro.RetroArch/config/retroarch/thumbnails")
box = {}
for p in glob.glob(thumbs + "/*/Named_Boxarts/*.png"):
    box.setdefault(norm(os.path.splitext(os.path.basename(p))[0]), p)

def api(path):
    req = urllib.request.Request("https://www.steamgriddb.com/api/v2" + path,
        headers={"Authorization": "Bearer " + KEY, "User-Agent": "emudeck-toolkit"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except Exception:
        return None
def have(a, suf):
    return bool(glob.glob(os.path.join(grid, "%d%s.*" % (a, suf))))
def fetch(a, suf, url):
    ext = os.path.splitext(urllib.parse.urlparse(url).path)[1] or ".png"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "emudeck-toolkit"})
        with urllib.request.urlopen(req, timeout=30) as r, open(os.path.join(grid, "%d%s%s" % (a, suf, ext)), "wb") as f:
            shutil.copyfileobj(r, f)
        return True
    except Exception:
        return False

games = [(a, n) for a, n in sc.items() if n and "Emulator" not in n and n != "EmulationStationDE"]
st = dict(tile_box=0, tile_sgdb=0, hero=0, logo=0, nogame=0)

# --- phase 1: portrait tiles from box art (keyless) ---
for a, nm in games:
    if not have(a, "p"):
        src = box.get(norm(nm))
        if src:
            shutil.copyfile(src, os.path.join(grid, "%dp.png" % a)); st["tile_box"] += 1
print("box-art tiles placed: %d" % st["tile_box"], flush=True)
if not KEY:
    print("no SGDB_KEY -> tiles only. DONE:", st)
    raise SystemExit

# --- phase 2a: resolve each game to a SteamGridDB id (cached by cleaned name) ---
print("resolving %d games on SteamGridDB..." % len(games), flush=True)
CACHE = os.path.expanduser("~/.cache/emudeck-sgdb-ids.json")
os.makedirs(os.path.dirname(CACHE), exist_ok=True)
try:
    idcache = json.load(open(CACHE))           # resume: skip names already searched
except Exception:
    idcache = {}
appid_to_sid = {}
for n, (a, nm) in enumerate(games):
    if have(a, "p") and have(a, "_hero") and have(a, "_logo"):
        continue
    q = clean(nm)
    if q not in idcache:
        d = api("/search/autocomplete/" + urllib.parse.quote(q))
        idcache[q] = d["data"][0]["id"] if (d and d.get("data")) else None
        if len(idcache) % 50 == 0:
            try: json.dump(idcache, open(CACHE, "w"))
            except Exception: pass
    sid = idcache[q]
    if sid:
        appid_to_sid[a] = sid
    else:
        st["nogame"] += 1
    if n % 150 == 0:
        print("  searched %d/%d, matched %d" % (n, len(games), len(appid_to_sid)), flush=True)
try: json.dump(idcache, open(CACHE, "w"))
except Exception: pass
print("matched %d games" % len(appid_to_sid), flush=True)

# --- phase 2b: BATCH the art lookups (comma-separated ids, 50/request) ---
def batch(endpoint, params, sids):
    out = {}
    uniq = sorted(set(sids))
    for i in range(0, len(uniq), 50):
        chunk = uniq[i:i + 50]
        d = api("/%s/game/%s%s" % (endpoint, ",".join(map(str, chunk)), params))
        rows = d.get("data") if isinstance(d, dict) else None
        if isinstance(rows, list):
            for sid, entry in zip(chunk, rows):
                imgs = entry.get("data") if isinstance(entry, dict) else None
                out[sid] = imgs[0]["url"] if (isinstance(imgs, list) and imgs) else None
    return out

sids = list(appid_to_sid.values())
print("batch-fetching grids/heroes/logos for %d ids..." % len(set(sids)), flush=True)
grids  = batch("grids",  "?dimensions=600x900&types=static", sids)
heroes = batch("heroes", "?types=static", sids)
logos  = batch("logos",  "?types=static", sids)

# --- phase 2c: download the chosen image per game ---
for a, sid in appid_to_sid.items():
    if not have(a, "p") and grids.get(sid) and fetch(a, "p", grids[sid]):
        st["tile_sgdb"] += 1
    if not have(a, "_hero") and heroes.get(sid) and fetch(a, "_hero", heroes[sid]):
        st["hero"] += 1
    if not have(a, "_logo") and logos.get(sid) and fetch(a, "_logo", logos[sid]):
        st["logo"] += 1
print("DONE:", st)
print("Restart Steam to see the artwork.")
