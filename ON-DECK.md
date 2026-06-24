# On-Deck Guide — running games, achievements, hotkeys & troubleshooting

Everything *after* the library is transferred (see [`README.md`](README.md) for the
PC-side prep). This is the on-deck runbook: BIOS, getting games into Gaming Mode,
RetroAchievements, hotkeys, RetroArch playlists/thumbnails, and editing configs
over SSH — i.e. the GUI/operational parts the scripts deliberately don't automate.

Paths here use placeholders: `<deck-ip>` (find with `ip route get 1 | awk '{print $7; exit}'`),
`<LABEL>` (your SD card label), and `$EMU_LIB` (your PC library, e.g. `/mnt/e/Emulation`).
On the deck the library lives at `/run/media/<LABEL>/Emulation`.

---

## 1. Launching EmuDeck & the Gaming-Mode reality

The **EmuDeck app is a Desktop-Mode application** — there is no first-class "launch
EmuDeck" button in Gaming Mode. That's by design; you rarely need it after setup.

- **Get to it:** STEAM button → **Power → Switch to Desktop** → double-click the
  **EmuDeck** desktop icon, or open the **Application Launcher** (bottom-left) and
  search `EmuDeck`. (Desktop icons are *not* your full app list — installed apps
  like ES-DE live in the Application Launcher, not on the desktop.)
- **Desktop controls without a mouse:** right trackpad = pointer, **R2** = left-click,
  **L2** = right-click, or just tap the touchscreen.
- **You don't play games inside the EmuDeck app** — it only configures things
  (install emulators, BIOS Checker, and the button that opens Steam ROM Manager).
- **The "never touch Desktop again" path:** once **Steam ROM Manager → Save to
  Steam** runs (one Desktop trip), your games are entries in your **Gaming Mode**
  library and launch directly. The **[EmuDecky](https://github.com/EmuDeck/EmuDecky)**
  Decky plugin (Quick Access `…` menu) covers most ongoing tweaks from Gaming Mode.

Full screenshot walkthroughs: **Wagner's TechTalk** —
[EmuDeck Setup Guide](https://wagnerstechtalk.com/sd-emudeck/),
[Steam Deck & Emulation hub](https://wagnerstechtalk.com/steamdeck/#Emulation).

---

## 2. Getting games into Gaming Mode (Steam ROM Manager) + artwork

In Desktop Mode:

1. Open **EmuDeck** → click **Steam ROM Manager** (it must **close Steam** → Yes).
2. Sidebar → **Parsers** → confirm your systems are enabled (on by default).
3. **Preview → Generate app list** (a.k.a. **Add Games**). This scans your ROMs **and
   downloads box art** from SteamGridDB — with hundreds of games it takes a few
   minutes; let it finish. (Cycle art per game with the **◀ ▶** arrows if you want.)
4. **Save to Steam** (Save App List).
5. Desktop → double-click **Return to Gaming Mode** → **STEAM → Library** → your
   games are there, with art, grouped by system → **Play**.

**Missing/blank art?** Re-run *Generate app list* (it's usually SteamGridDB
rate-limiting on a big batch); **restart Steam** so it reloads the library cache;
or add a free SteamGridDB **API key** in SRM → Settings.

---

## 3. BIOS

EmuDeck creates the `bios/` folder scaffolding on the card, but **you supply the
files**. Required for this scope:

| System | File(s) | Location |
|---|---|---|
| PS1 (DuckStation) | `scph5500/5501/5502.bin` | `bios/` |
| PS2 (PCSX2) | any official PS2 BIOS (e.g. `SCPH-70004…`) | `bios/` |
| Saturn (Beetle/Kronos) | `sega_101.bin`, `mpr-17933.bin`, `saturn_bios.bin` | `bios/` (+ `bios/kronos/` for standalone Kronos) |
| Sega CD | `bios_CD_U/E/J.bin` | `bios/` |
| Dreamcast (Flycast) | `dc_boot.bin`, `dc_flash.bin` | `bios/dc/` |
| NES (FDS only) | `disksys.rom` | `bios/` |

> BIOS/firmware are **copyrighted** — only use files for hardware/systems you own;
> the lawful path is dumping your own. This repo hosts none.

Sources, in order of preference:
1. **Your own old RetroArch `system/` folder** — BIOS are platform-independent data,
   so e.g. `scph550x.bin` copy straight over. (Unlike *cores* — see §7.)
2. **[retrobios](https://github.com/Abdess/retrobios)** verified pack. The
   **EmuDeck Platform** asset is BIOS-only (~44 MB) and lays out as `bios/` + `bios/dc/`,
   so it drops straight into the library. The *full* pack (~1.7 GB) adds out-of-scope
   Switch/3DS/PS3 firmware — skip it. Example:
   ```bash
   gh release download <tag> --repo Abdess/retrobios --pattern '*EmuDeck*Platform*' --dir /tmp/rb
   unzip -o /tmp/rb/EmuDeck_*_Platform_BIOS_Pack.zip 'bios/*' -d "$EMU_LIB"   # extracts bios/ into $EMU_LIB
   ```

Then **re-run `transfer-to-deck.sh`** (rsync sends only the new BIOS), and verify:
- **PC pre-check:** `./scripts/check-bios.sh` (reads `$EMU_LIB` from `.env`).
- **On the deck (authoritative, checksum-verified):** EmuDeck app → **BIOS Checker**.

> The BIOS Checker lists firmware for **every** emulator EmuDeck knows, including
> Switch emulators (yuzu / eden / ryujinx / citron). Those "missing firmware" lines
> are **out of scope — ignore them.** Only your in-scope systems need to be green.

---

## 4. SSH into the deck from another machine (edit files remotely)

The deck's on-screen keyboard is painful (and has a bug that appends a `?` after each
character). Far better: drive the deck from your PC/Mac/Linux box over SSH and edit
files with real tools. SSH works whether the deck is in **Desktop or Gaming Mode**, as
long as it's awake and `sshd` is running.

### Step 1 — One-time setup, on the deck (Desktop Mode)
1. **STEAM → Power → Switch to Desktop.**
2. Open **Konsole** (taskbar, or Application Launcher → search `Konsole`).
3. Set a login password — the deck ships with **none**, and SSH needs one:
   ```bash
   passwd
   ```
4. Enable the SSH server (the `--now` starts it immediately; `enable` makes it
   survive reboots):
   ```bash
   sudo systemctl enable --now sshd
   ```
   (`sudo` will ask for the password you just set.)
5. Get the deck's IP on your LAN — note it (e.g. `192.168.1.42`):
   ```bash
   ip route get 1 | awk '{print $7; exit}'
   ```
   > Tip: reserve a **static/DHCP-reserved IP** for the deck in your router so it
   > doesn't change between sessions.

### Step 2 — Connect, from your other machine
```bash
ssh deck@<deck-ip>
```
- First connection: it asks to trust the host key → type **yes**.
- Enter the **deck's** password (the one from `passwd` — *not* your PC password; it
  won't echo as you type).
- You're now in a shell **on the deck** (`deck@steamdeck ~$`). Run anything; `exit` to leave.

### Step 3 — Go passwordless (optional, strongly recommended)
So `ssh`/`scp`/`rsync` and editors stop prompting every single time:
```bash
ssh-keygen -t ed25519          # skip if you already have a key (~/.ssh/id_*.pub)
ssh-copy-id deck@<deck-ip>     # type the deck password ONE last time
ssh deck@<deck-ip>             # now connects with no prompt
```

### Step 4 — Edit files remotely (pick your style)
- **In the SSH terminal (simplest):** `nano <file>` — `Ctrl+W` search, `Ctrl+O` save,
  `Ctrl+X` exit. (`nano` ships with SteamOS — see gotchas re: don't `pacman` vim.)
- **Edit on your machine, copy back** (`scp`):
  ```bash
  scp deck@<deck-ip>:'.var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg' ./ra.cfg
  $EDITOR ./ra.cfg                       # your normal editor
  scp ./ra.cfg deck@<deck-ip>:'.var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg'
  ```
- **VS Code Remote-SSH (nicest GUI):** install the *Remote - SSH* extension → Command
  Palette → *Remote-SSH: Connect to Host…* → `deck@<deck-ip>` → open any folder/file on
  the deck and edit it like a local project. (Use key auth from Step 3 to avoid
  re-typing the password; VS Code drops a small server in the deck's writable `$HOME`.)
- **Mount the deck's home locally (`sshfs`):**
  ```bash
  # on your PC once: sudo apt install sshfs   (or your distro's package)
  mkdir -p ~/deck && sshfs deck@<deck-ip>:/home/deck ~/deck
  #   ...edit anything under ~/deck with any local tool...
  fusermount -u ~/deck                    # unmount when done
  ```

### SteamOS gotchas
- Root FS is **read-only/immutable** and **wiped on every OS update** — don't
  `pacman -S …` into it. **`nano` is already there** (`which nano`); for a persistent
  toolchain use **Homebrew** (installs into `$HOME`, survives updates):
  `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.
  After it installs, **add `brew` to your PATH** (it isn't automatic) — run it now and
  append to `~/.bashrc` so it persists:
  `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"`. Then `brew install vim` works.
- **Close the app before editing its config.** E.g. RetroArch **rewrites
  `retroarch.cfg` on exit**, so edits made while it's running get clobbered.
- A major **SteamOS update can disable `sshd` and reset your password** — just re-run
  Step 1 (3–4) if SSH stops working after one.
- The deck **suspends on idle**, dropping your SSH session — for long remote sessions
  keep it awake (plugged in, and/or raise the sleep timeout in Desktop power settings).

### Concrete example — the RetroArch configs you'll most likely edit
- **Live:** `~/.var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg`
- **EmuDeck-managed copy:** `~/.config/EmuDeck/backend/configs/org.libretro.RetroArch/config/retroarch/retroarch.cfg`
  — EmuDeck pushes this onto the live one when you re-apply its config, so edit **both**
  to make changes survive an EmuDeck reset. Ignore the Android variant and the
  read-only `~/.local/share/flatpak/.../files/etc/retroarch.cfg` default.

---

## 5. RetroAchievements (softcore)

Configured **per emulator**, so one can be logged in and another not.

- **RetroArch:** *Settings → Achievements* (enable; **Hardcore = OFF**) and
  *Settings → User → Accounts → RetroAchievements* (username/password).
  If "Achievements" isn't in the Settings list, it's hidden: *Settings → User
  Interface → Menu Item Visibility* (and/or *Show Advanced Settings → ON*). Note
  there are two menus — the in-game **Quick Menu** is not where login lives; back
  out to the **main menu → Settings**.
- **DuckStation / Flycast standalone:** *Settings → Achievements* → enable + log in.
- **Easiest of all:** the **EmuDeck app** has a RetroAchievements login step that
  pushes credentials to RetroArch *and* the standalones at once.

**If your typed login "didn't save":** RetroArch only persists on a clean exit —
killing it via *STEAM → Exit Game* discards it. Either *Main Menu → Configuration
File → Save Current Configuration* after entering it, or (better) set it in the file
directly **with RetroArch closed**:

```bash
LIVE=~/.var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg
EMUDECK=~/.config/EmuDeck/backend/configs/org.libretro.RetroArch/config/retroarch/retroarch.cfg
set_cfg(){ local f=$1 k=$2 v=$3; sed -i "/^$k = /d" "$f"; printf '%s = "%s"\n' "$k" "$v" >> "$f"; }
for F in "$LIVE" "$EMUDECK"; do
  set_cfg "$F" cheevos_enable                true
  set_cfg "$F" cheevos_username              'YOURNAME'
  set_cfg "$F" cheevos_password              'YOURPASS'      # single-quote; use nano if it contains a '
  set_cfg "$F" cheevos_hardcore_mode_enable  false
  set_cfg "$F" cheevos_token                 ''              # blank → forces re-auth
done
```

**Verify it's working:** launch a game that *has* an achievement set (check at
[retroachievements.org](https://retroachievements.org)) — you'll see a
**"Logged in as …"** popup at boot. Your profile on the site shows "recently played"
once a session connects. The **Emuchievements** Decky plugin shows progress in
Gaming Mode. (Not every game has a set; RA matches by file hash — your Redump CHDs
generally match.)

---

## 6. Hotkeys — exiting and navigating

The deck labels buttons differently than emulators expect:
**Select** = the **View** button (`⧉`, top-left), **Start** = the **Menu** button
(`☰`, top-right), **STEAM** = bottom-left, **`…` (QAM)** = bottom-right.

- **Universal exit (always works):** **STEAM button → Exit Game.**
- **Dreamcast / Flycast** (more restrictive than other cores):
  - Open Flycast's menu: **Select** alone.
  - Quit: **STEAM + D-Pad Left** (Stop Emulation). Fast-forward: **STEAM + D-Pad Right**.
- **General EmuDeck combos** (hold **Select** + button):

  | Action | Combo |
  |---|---|
  | Quit | Select + Start |
  | Menu | Select + R3 |
  | Save state | Select + R1 |
  | Load state | Select + L1 |
  | Fast-forward | Select + R2 |
  | Pause | Select + A |

**"Just pressing A pauses / shows FPS" (face buttons trigger hotkeys bare):** the
hotkey **enabler** modifier got lost, so hotkeys fire without holding Select. Quick
fix: toggle **Game Focus mode** on while in-game (disables all hotkeys). Proper fix:
ensure the **Hotkey Enable** button is bound (to Select) in *Settings → Input → Hotkeys*.
Reference: [Hotkeys – EmuDeck Wiki](https://emudeck.github.io/controls-and-hotkeys/steamos/hotkeys/).

---

## 7. RetroArch cores & choosing an emulator per system

- **Do not copy Windows RetroArch cores or config to the deck.** Windows cores are
  `*_libretro.dll`; SteamOS (Linux) needs `*_libretro.so`. A `.dll` simply won't load.
  Get cores via **RetroArch → Online Updater → Core Downloader / Update Installed
  Cores** (downloads the right Linux builds). EmuDeck already installs the cores for
  the systems you selected. (Only **BIOS** and **ROMs** were worth salvaging from an
  old Windows install — not cores or `retroarch.cfg`.)
- **Per-system emulator (RetroArch vs standalone):** EmuDeck picks a default
  (DuckStation for PS1, Flycast for Dreamcast, RetroArch for Saturn). Change it via
  **ES-DE → Alternative Emulators** (per system or per game), or by enabling the
  RetroArch **parser** for that system in **Steam ROM Manager**. EmuDeck's standalone
  defaults usually perform best; RetroArch wins on uniformity (one UI, achievements,
  shaders, run-ahead).

---

## 8. RetroArch playlists & thumbnails

If you browse from RetroArch's own UI rather than ES-DE/Steam:

- **Build all playlists at once:** *Import Content → **Scan Directory*** is
  **recursive** — point it at the **parent** `/run/media/<LABEL>/Emulation/roms/` and
  pick **`<Scan This Directory>`**; it builds a playlist per detected system in one
  pass (CHDs match the database fine). Use **Manual Scan** for anything that doesn't
  auto-match (set System Name + Default Core, add by extension).
- **Stop scrolling to the SD card:** *Settings → Directory → **File Browser*** →
  set it to `/run/media/<LABEL>/Emulation/roms`.
- **Bulk thumbnails (not scroll-by):** *Online Updater → **Update Thumbnails*** →
  pick each system → downloads that whole playlist's art in one go. The scroll-by
  behavior is *Settings → User Interface → On-Demand Thumbnail Downloads* (leave ON
  to backfill, or OFF to rely only on bulk passes).

**Skip the clicking entirely** — the toolkit does the RetroArch side over SSH:
`make-retroarch-playlists.sh` generates the `.lpl` files (one per system, multi-disc
`.m3u` shown once) and `get-retroarch-thumbnails.sh` pulls the matching cover art.
`full-sync.sh` on the PC chains import → transfer → playlists → art automatically,
then **prints the Steam ROM Manager GUI steps** — because SRM's CLI only fetches
landscape art and can't write the per-console collections, so the final Steam
library (tiles + hero art + folders) is a one-time GUI "Save to Steam".

---

## 9. Known gaps / gotchas

- **Multi-disc games:** launch the **`.m3u`**, not "Disc 1" (`make-m3u.sh` generates
  these during import).
- **Broken source archives:** a disc whose `.zip` is missing track `.bin` files (e.g.
  Azel / Panzer Dragoon Saga Disc 4 in one set) can't be converted — `chdman` fails
  with "couldn't find bin file." That's a bad dump at the source, not fixable by
  re-running; re-source a complete copy. `zip-status.sh` lists what's pending.
