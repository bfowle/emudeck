#!/usr/bin/env python3
# fix-multidisc.py — collapse duplicate Steam shortcuts to one entry per game.
# Runs ON THE DECK, after Steam ROM Manager. SRM creates a shortcut for EVERY file it
# matches, so you get duplicates from: multi-disc games (Disc 1/2/3/4 + the .m3u, all
# cleaned to the same name), the same ROM appearing in both Redump and No-Intro, and
# region/revision variants. This keeps exactly ONE shortcut per display name, preferring
# the .m3u (so multi-disc plays all discs), then a non-disc file, then USA/base.
#
# Safe: byte-exact shortcuts.vdf round-trip self-test before writing (aborts rather than
# risk corruption); backup saved to shortcuts.vdf.bak. Close Steam first (it rewrites
# the file on exit). Idempotent.
import os, glob, struct, re, shutil, sys
from collections import OrderedDict

cfg = glob.glob(os.path.expanduser("~/.steam/steam/userdata/*/config"))
if not cfg:
    raise SystemExit("no Steam userdata config dir found")
vdf = cfg[0] + "/shortcuts.vdf"
orig = open(vdf, "rb").read()

def parse(b, i):
    d = OrderedDict()
    while i < len(b):
        t = b[i]
        if t == 0x08:
            return d, i + 1
        i += 1
        e = b.index(0, i); key = b[i:e].decode("utf-8", "surrogateescape"); i = e + 1
        if t == 0x00:
            v, i = parse(b, i); d[key] = ("map", v)
        elif t == 0x01:
            e = b.index(0, i); d[key] = ("str", b[i:e].decode("utf-8", "surrogateescape")); i = e + 1
        elif t == 0x02:
            d[key] = ("int", struct.unpack("<I", b[i:i + 4])[0]); i += 4
        else:
            raise ValueError("unknown VDF type %d at %d" % (t, i))
    return d, i

def ser(d):
    out = bytearray()
    for k, (typ, v) in d.items():
        kb = k.encode("utf-8", "surrogateescape")
        if typ == "map":   out += b"\x00" + kb + b"\x00" + ser(v) + b"\x08"
        elif typ == "str": out += b"\x01" + kb + b"\x00" + v.encode("utf-8", "surrogateescape") + b"\x00"
        elif typ == "int": out += b"\x02" + kb + b"\x00" + struct.pack("<I", v)
    return bytes(out)

root, _ = parse(orig, 0)
trailer = orig[len(ser(root)):]
if ser(root) + trailer != orig:
    sys.exit("ROUND-TRIP FAILED — not touching the file (parser not byte-exact).")
print("round-trip OK (%d bytes)" % len(orig))

shortcuts = root["shortcuts"][1]
def field(sc, *names):
    low = {k.lower(): v for k, v in sc.items()}
    for n in names:
        if n.lower() in low:
            return low[n.lower()][1]
    return ""
def romfile(sc):
    lo = field(sc, "LaunchOptions", "Exe")
    m = re.search(r'([^"/\\]+\.(chd|m3u|cue|iso|zip|gdi))', lo, re.I)
    return m.group(1) if m else ""
def score(sc):
    f = romfile(sc).lower()
    s = 0
    if f.endswith(".m3u"): s += 1000
    if not re.search(r"\((dis[ck]|cd)\s*\d+\)", f): s += 100      # non-disc preferred
    if "(usa)" in f: s += 10
    if re.search(r"\((dis[ck]|cd)\s*0*1\)", f): s += 5            # else disc 1
    return (s, -len(f))

# group by display name, keep the best-scoring shortcut per name
groups = OrderedDict()
for key, (typ, sc) in shortcuts.items():
    groups.setdefault(field(sc, "AppName"), []).append(sc)
kept, removed, n = OrderedDict(), 0, 0
for name, scs in groups.items():
    best = max(scs, key=score) if len(scs) > 1 else scs[0]
    removed += len(scs) - 1
    kept[str(n)] = ("map", best); n += 1
print("shortcuts: %d -> %d  (removed %d duplicates: multi-disc + same-rom + region/rev)"
      % (len(shortcuts), len(kept), removed))

if removed:
    root["shortcuts"] = ("map", kept)
    shutil.copyfile(vdf, vdf + ".bak")
    open(vdf, "wb").write(ser(root) + trailer)
    print("written; backup at shortcuts.vdf.bak. Restart Steam.")
