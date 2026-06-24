#!/usr/bin/env python3
# set-steam-art.py — give SRM-added games their PORTRAIT library tiles, using the
# RetroArch box art you already downloaded (get-retroarch-thumbnails.sh). Runs ON
# THE DECK, AFTER Steam ROM Manager has added the games.
#
# Why: SRM's CLI (and even its GUI "All Artwork" save, in practice) often writes only
# the landscape capsule, leaving the vertical library tiles blank. Steam shows the
# library grid from <appid64>p.png in userdata/<id>/config/grid/. This fills those in
# from the libretro box art (which is portrait) so the Game Mode library shows covers.
# Idempotent (skips tiles already present). Restart Steam afterwards.
#
# Match is by game name with region/brackets stripped, so "Crazy Taxi (USA)" lines up
# with the box art regardless of SRM's title cleanup.
import os, glob, struct, re, shutil, sys

cfg = glob.glob(os.path.expanduser("~/.steam/steam/userdata/*/config"))
if not cfg:
    sys.exit("no Steam userdata config dir found")
cfg = cfg[0]
vdf, grid = cfg + "/shortcuts.vdf", cfg + "/grid"
if not os.path.exists(vdf):
    sys.exit("no shortcuts.vdf — run Steam ROM Manager first")
os.makedirs(grid, exist_ok=True)

# shortcuts.vdf (binary VDF) -> {appid: AppName}
data = open(vdf, "rb").read()
KEY = b"\x01appname\x00"
shortcuts, i = {}, 0
while True:
    j = data.find(b"\x02appid\x00", i)
    if j < 0:
        break
    appid = struct.unpack("<I", data[j + 7:j + 11])[0]
    k = data.lower().find(KEY, j)
    name = ""
    if 0 <= k < j + 600:
        s = k + len(KEY); e = data.find(b"\x00", s)
        name = data[s:e].decode("utf-8", "ignore")
    shortcuts[appid] = name
    i = j + 11

def norm(s):
    s = re.sub(r"\(.*?\)|\[.*?\]", "", s)        # drop (USA)/(Rev A)/[!] etc.
    return re.sub(r"[^a-z0-9]+", "", s.lower())

# box-art index from RetroArch thumbnails (Named_Boxarts are portrait covers)
thumbs = os.path.expanduser("~/.var/app/org.libretro.RetroArch/config/retroarch/thumbnails")
index = {}
for p in glob.glob(thumbs + "/*/Named_Boxarts/*.png"):
    index.setdefault(norm(os.path.splitext(os.path.basename(p))[0]), p)

print("shortcuts: %d   box-art covers: %d" % (len(shortcuts), len(index)))
placed = skip = nomatch = 0
for f in os.listdir(grid):
    m = re.match(r"^(\d{15,})\.(png|jpg)$", f)   # the landscape <gid>.png SRM wrote
    if not m:
        continue
    gid = int(m.group(1))
    name = shortcuts.get(gid >> 32, "")
    if not name:
        continue
    dest = os.path.join(grid, "%dp.png" % gid)   # the portrait tile slot
    if os.path.exists(dest):
        skip += 1; continue
    src = index.get(norm(name))
    if not src:
        nomatch += 1; continue
    shutil.copyfile(src, dest); placed += 1

print("portrait tiles: placed=%d  already-had=%d  no-boxart-match=%d" % (placed, skip, nomatch))
print("Restart Steam to see the library covers.")
