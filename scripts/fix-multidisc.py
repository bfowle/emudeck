#!/usr/bin/env python3
# fix-multidisc.py — remove the per-disc Steam shortcuts SRM creates for multi-disc
# games, keeping only the single .m3u entry. Runs ON THE DECK, after Steam ROM
# Manager (SRM's glob matches every "(Disc N)" file AND the .m3u, so a 4-disc game
# shows as 5 entries). Safe: it parses shortcuts.vdf, does a byte-exact round-trip
# self-test, and ONLY writes if that passes (so it can't corrupt the file). A backup
# is saved to shortcuts.vdf.bak. Close Steam first (it rewrites the file on exit).
import os, glob, struct, re, shutil, sys

cfg = glob.glob(os.path.expanduser("~/.steam/steam/userdata/*/config"))
if not cfg:
    raise SystemExit("no Steam userdata config dir found")
vdf = cfg[0] + "/shortcuts.vdf"
orig = open(vdf, "rb").read()

def parse(b, i):
    d = {}
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
trailer = orig[len(ser(root)):]           # the root map's end marker(s)
if ser(root) + trailer != orig:
    sys.exit("ROUND-TRIP FAILED — not touching the file (parser not byte-exact).")
print("round-trip OK (%d bytes)" % len(orig))

shortcuts = root["shortcuts"][1]
disc = re.compile(r"\((dis[ck]|cd)\s*\d+\)", re.I)
kept, removed, n = {}, 0, 0
for _, (typ, scut) in shortcuts.items():
    name = scut.get("AppName", scut.get("appname", ("str", "")))[1]
    if disc.search(name):
        removed += 1; continue            # drop the per-disc entry; the .m3u stays
    kept[str(n)] = ("map", scut); n += 1
print("shortcuts: %d -> %d  (removed %d disc-member entries)" % (len(shortcuts), len(kept), removed))

if removed:
    root["shortcuts"] = ("map", kept)
    shutil.copyfile(vdf, vdf + ".bak")
    open(vdf, "wb").write(ser(root) + trailer)
    print("written; backup at shortcuts.vdf.bak. Restart Steam.")
