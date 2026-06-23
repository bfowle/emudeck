# Steam Deck OLED Emulation — Setup & Scripts

A personal, **CLI-forward** toolkit and guide for setting up emulation on a **Steam Deck OLED** with [EmuDeck](https://www.emudeck.com), doing the heavy lifting (organizing, compressing, and validating your ROM library) **off the device** on a Linux or Windows + WSL2 (Ubuntu) PC.

I wrote this for my own setup and I'm sharing it in case it helps you — or future me — do it again elsewhere. It's opinionated but every choice is explained, with the alternatives called out so you can deviate.

> ### ⚠️ No game content here
> **This repository contains only scripts and documentation.** It ships **no ROMs, no BIOS/firmware, and no game executables**, and never will (see [`.gitignore`](.gitignore)). Bring your own legally-obtained files — see [Where to get things (legally)](#where-to-get-things-legally). The links below point to tools and to homebrew/public-domain/verification resources only; they are not sources of copyrighted games.

---

## What's in here

| Path | What it is |
|---|---|
| `README.md` | This general guide (start here). |
| `SETUP-GUIDE.md` | My own worked run-through as a concrete example (specific paths, decisions, library). |
| `.env.example` | Template for your personal paths/IP — `cp .env.example .env`, then edit (`.env` is gitignored). |
| `scripts/` | Bash scripts that automate the off-device prep (see [Scripts](#scripts)). |

## Who it's for / prerequisites

- A **Steam Deck OLED** (the LCD model works identically — same APU, same steps).
- A **Linux or Windows + WSL2 (Ubuntu)** PC to prep on, with a terminal you're comfortable in.
- **Legally-obtained** ROMs/BIOS — dumps of cartridges/discs you own, or homebrew/public-domain titles.
- A microSD card (**512 GB–1 TB** recommended for a PS2/GC/Wii-era library; 256 GB is plenty for retro-only).

---

## Decisions to make first

These three choices shape the rest. My picks are marked, but pick what fits you.

| Decision | Options | Notes |
|---|---|---|
| **SD card filesystem** | **(A) Format on the deck (ext4), transfer over network** ← *my pick* · (B) exFAT, prep entirely on PC · (C) ext4 via `wsl --mount` | The deck uses **ext4**, which Windows can't read natively. (A) is most robust; (B) lets you pre-load the card on Windows but loses Linux case-folding; (C) is best-of-both but fiddly. |
| **How far up the ladder** | Retro only (≤ PS1/N64) · **Through PS2/GC/Wii/PSP/Dreamcast/Saturn** ← *my pick, the Deck's sweet spot* · Everything incl. Switch/3DS/Wii U/PS3 | Higher tiers need more BIOS/firmware and have more legal nuance + variable performance. |
| **RetroAchievements mode** | **Softcore (keep save states)** ← *my pick* · Hardcore (double points, no save states) · Decide per game | Hardcore disables save states, rewind, cheats, and slowdown. You can flip a single game to hardcore anytime. |

---

## The workflow

The bulk of the work happens **on your PC**; the deck only formats the card, installs EmuDeck, and receives the finished library.

### 1. Install the PC toolkit

```bash
cd scripts
./setup-tools.sh      # chdman, 7z, unzip, rsync, ssh, igir  (apt + npm on Ubuntu/WSL2)
```

### 2. Build the staging tree

```bash
./make-rom-skeleton.sh           # creates ~/emustaging/Emulation/{roms/<system>,bios}
```

> All scripts target `~/emustaging/Emulation` by default. Point the whole toolkit somewhere else (e.g. an external drive) by setting `export EMU_LIB=/mnt/e/Emulation`, or pass a path positionally.

Then put your legally-obtained ROMs into the matching `roms/<system>` folders. Folder names follow the ES-DE/EmuDeck convention — the authoritative list is the [EmuDeck Cheat Sheet](https://emudeck.github.io/cheat-sheet/).

**Importing an existing collection?** `import-roms.sh <input-dir>` is generic: it maps each subfolder of your source (an old RetroArch `__GAMES__`, a No-Intro/Redump set, plain `snes`/`psx` folders, …) to an EmuDeck system via a built-in alias table, then places the real ROM/disc files into the library, skipping junk by extension. It auto-picks how:

- **link mode** (local ext4 staging) — symlinks; instant, ~0 bytes. `transfer-to-deck.sh` later follows them with `rsync -L`.
- **copy mode** (destination under `/mnt/*`, e.g. an external/Windows drive) — real files, since symlinks wouldn't survive the move; disc images are compressed straight to `.chd`.

Force either with `--link`/`--copy`. Unmapped folders are reported so you can extend `map_system()`.

```bash
export EMU_LIB=/mnt/e/Emulation     # optional: build a durable library on an external drive
./import-roms.sh /path/to/old/library
```

> 🚩 **A warning worth its own line:** if a "free ROM" site ever hands you a small (~400 KB) `.exe` "downloader" instead of an actual game file, **that is not a game — it's adware/malware.** Delete it; don't run it. Legitimate ROMs are the disc/cart files themselves (`.chd`, `.iso`, `.nes`, …), never an installer. This is exactly the kind of junk the import script filters out.

### 3. Compress disc images

CHD is lossless and shrinks CD/DVD images 50–70%, natively supported by RetroArch/DuckStation/PCSX2/Flycast:

```bash
S=~/emustaging/Emulation/roms
# --delete here removes the raw disc *symlinks* after a successful convert
# (it never touches your source library — only the links in staging).
./compress-chd.sh --delete "$S/psx" "$S/saturn"   # CD-based -> createcd
./compress-chd.sh --dvd --delete "$S/ps2"         # DVD-based -> createdvd
./make-m3u.sh "$S/psx"                            # multi-disc -> one .m3u each
```

- **Dreamcast `.cdi`**: leave as-is — `chdman` can't read DiscJuggler images; Flycast plays `.cdi` directly.
- **GameCube/Wii**: convert to **RVZ** in Dolphin (*right-click → Convert*), not CHD.

### 4. Check BIOS

```bash
./check-bios.sh        # lists which BIOS each system needs; downloads nothing
```

Most BIOS go flat in `Emulation/bios/`; **Dreamcast** (`dc_boot.bin`, `dc_flash.bin`) goes in `Emulation/bios/dc/`. You must supply your own (dumped from hardware you own). The deck's built-in EmuDeck **BIOS Checker** does the final checksum verification.

### 5. Set up the deck

1. Update SteamOS (Settings → System → Updates).
2. Desktop Mode → Konsole:
   ```bash
   passwd                                  # set a password
   sudo systemctl enable --now sshd        # enable SSH for the transfer
   ip route get 1 | awk '{print $7; exit}' # note the deck's IP
   ```
3. Format the SD card as **ext4** (Gaming Mode → Settings → Storage).
4. Run the [EmuDeck](https://www.emudeck.com) installer (AppImage) → **Custom Mode** → install location = **SD card** → select emulators for your scope → set RetroAchievements (Hardcore OFF for softcore) → finish. EmuDeck creates `Emulation/` on the card.
5. Find the card path: `ls -d /run/media/*/Emulation` (newer SteamOS mounts at `/run/media/<LABEL>/Emulation`; older put it under `/run/media/deck/<LABEL>/`).

### 6. Transfer the library (from the PC)

```bash
./transfer-to-deck.sh <deck-ip> /run/media/<CARD>/Emulation
```

`rsync` over SSH — resumable, only copies changes. Use the **Dock's Ethernet** for speed.

### 7. Add to Steam + browse

- **Steam ROM Manager** (in the EmuDeck app): enable parsers → Add Games → scrapes artwork → Save to Steam.
- **ES-DE** ([es-de.org](https://es-de.org), added as a non-Steam app): auto-discovers ROMs; optional artwork scraper. Use both — SRM puts games in the Steam library, ES-DE is a dedicated retro front-end.

### 8. RetroAchievements

Create an account at [retroachievements.org](https://retroachievements.org). EmuDeck's installer login usually propagates to RetroArch + standalone emulators (DuckStation/PCSX2/PPSSPP/Dolphin); if one drops, re-enter the credentials in that emulator's *Settings → Achievements*. For RetroArch specifically, if login keeps expiring, set `cheevos_username`/`cheevos_password` and clear `cheevos_token` in `retroarch.cfg` (password auth survives token expiry). The **Emuchievements** Decky plugin shows progress in the Quick Access menu.

### 9. Controllers + dock

- **Xbox One pad over Bluetooth** (One S/Series have it; the 2013 launch pad doesn't) — cleanest.
- **Wired USB** into the dock — always works.
- **Xbox Wireless Adapter dongle** — on SteamOS it needs the community `xone` driver, isn't officially supported, and breaks on updates; prefer Bluetooth/wired.

EmuDeck hotkeys default to **Select + button** and assume the Deck's back paddles, which external pads lack — remap via **Steam Input** or check [emudeck.github.io/controls-and-hotkeys](https://emudeck.github.io/controls-and-hotkeys/). The dock provides HDMI/DP, Ethernet, USB, and charge passthrough.

### 10. Maintain

- Update emulators from the EmuDeck app or the **EmuDecky** Decky plugin; RetroArch cores via its Online Updater.
- Keep your PC staging tree as the master backup; re-run `transfer-to-deck.sh` to push additions (only changes copy). Back up `Emulation/saves`.

---

## Where to get things (legally)

This repo links out instead of hosting anything. **Within copyright allowances**, that means: tools, homebrew/public-domain games, and databases used to *verify your own dumps* — never copyrighted games or BIOS.

**Tools & emulators**
- EmuDeck — <https://www.emudeck.com> · docs <https://manual.emudeck.com> · system reference <https://emudeck.github.io/cheat-sheet/>
- ES-DE front-end — <https://es-de.org>
- RetroArch — <https://www.retroarch.com>
- Steam ROM Manager — <https://github.com/SteamGridDB/steam-rom-manager>
- igir (ROM organizer/validator) — <https://igir.io>
- chdman — part of MAME tools, <https://www.mamedev.org>
- redumper (accurate disc dumping) — <https://github.com/superg/redumper>
- Decky Loader (plugins) — <https://github.com/SteamDeckHomebrew/decky-loader>
- RetroAchievements — <https://retroachievements.org>

**Legal game content (homebrew / public domain)**
- EmuDeck Store — built into the EmuDeck app; curated free/homebrew titles.
- Internet Archive — <https://archive.org> (legal homebrew & public-domain collections).
- itch.io — <https://itch.io> (lots of console homebrew).
- PDRoms — <https://pdroms.de> (homebrew & public domain).

**Verification databases (checksums/metadata, *not* ROMs)**
- No-Intro (cartridges) — <https://datomatic.no-intro.org>
- Redump (discs) — <http://redump.org>

**Commercial games & BIOS:** there's no legal download link to give — the lawful path is to **dump your own** cartridges/discs/BIOS from hardware you own, then verify them against the No-Intro/Redump DATs above with `igir`.

---

## Scripts

All in `scripts/`, all run on the **PC** except where noted.

| Script | Does |
|---|---|
| `setup-tools.sh` | Installs chdman, 7z, unzip, rsync, ssh, igir (Ubuntu/WSL2). |
| `make-rom-skeleton.sh` | Builds the `Emulation/roms/<system>` + `bios/` staging tree. |
| `import-roms.sh` | Generic importer: maps any source layout → EmuDeck systems; **symlinks** into local staging or **copies real files** to an external/`/mnt` drive (auto), compressing discs to `.chd`. Honors `EMU_LIB`. |
| `import-zips.sh` | **Parallel, idempotent** importer for Redump/No-Intro `"System Name/*.zip"` sets: extract → `.chd` (carts copied as-is). `-j N` jobs (auto ≈ cores/5). Skips still-downloading/partial zips and retries them — safe to re-run mid-download or to add more systems. |
| `sync.sh` | One-command **idempotent sync**: `import-zips` + `transfer-to-deck`. Re-run anytime to add new games (config in `.env`, see [`.env.example`](.env.example)). |
| `zip-status.sh` | **Read-only** report: which zips are imported (`.chd` exists) vs pending, and why (still-downloading / ready / needs-attention). Touches nothing. |
| `systems.sh` | Shared folder-name → EmuDeck-system mapping (sourced by both importers). |
| `compress-chd.sh` | Batch `.cue/.iso/.gdi` → `.chd` (`--dvd` for PS2, `--out DIR` to redirect, `--delete` to drop sources/links). |
| `make-m3u.sh` | Generates multi-disc `.m3u` playlists. |
| `check-bios.sh` | Pre-checks expected BIOS filenames (downloads nothing). |
| `transfer-to-deck.sh` | `rsync`-over-SSH push to the deck's SD card. |

---

## Out of scope

Switch (Ryujinx), 3DS (Azahar), Wii U (Cemu), and PS3 (RPCS3) emulation — heavier, with firmware/key requirements and more legal nuance — aren't covered here. Add them later if you want.

## Disclaimer

Not affiliated with EmuDeck, Valve, or any emulator project. Provided as-is. You are responsible for ensuring you have the legal right to any ROMs, BIOS, or firmware you use.
