#!/usr/bin/env bash
# systems.sh — shared mapping from a source folder name to an EmuDeck system id.
# Source this file:  source "$HERE/systems.sh"
#
#   map_system "<folder name>"   -> echoes the system id (e.g. psx), or "" if unknown
#   is_dvd_system "<system id>"  -> 0 (true) for DVD-based systems (chdman createdvd)
#
# Order matters: more-specific patterns first. Add your own as needed.
map_system() {
  local n; n="$(printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9')"
  case "$n" in
    *wiiu*)                                    echo wiiu ;;
    # SNES MUST come before NES: "Super Nintendo Entertainment System" contains
    # the substring "Nintendo Entertainment System", so the NES glob would steal it.
    *supernintendo*|*superfamicom*|snes|sfc)   echo snes ;;
    *nintendoentertainmentsystem*|nes|famicom) echo nes ;;
    *nintendo64*|n64)                          echo n64 ;;
    *gameboyadvance*|gba)                      echo gba ;;
    *gameboycolor*|gbc)                        echo gbc ;;
    *gameboy*|gb)                              echo gb ;;
    *3ds*)                                     echo 3ds ;;
    *nintendods*|nds)                          echo nds ;;
    *gamecube*|gc|ngc)                         echo gc ;;
    *wii*)                                     echo wii ;;
    *switch*)                                  echo switch ;;
    *virtualboy*)                              echo virtualboy ;;
    *playstation2*|ps2)                        echo ps2 ;;
    *playstationportable*|psp)                 echo psp ;;
    *playstation3*|ps3)                        echo ps3 ;;
    *playstationvita*|psvita|vita)             echo psvita ;;
    *playstation*|psx|ps1|psone)               echo psx ;;
    *megacd*|*segacd*)                         echo segacd ;;
    *sega32x*|*32x*)                           echo sega32x ;;
    *saturn*)                                  echo saturn ;;
    *dreamcast*)                               echo dreamcast ;;
    *megadrive*|*genesis*)                     echo megadrive ;;
    *mastersystem*|sms)                        echo mastersystem ;;
    *gamegear*|gg)                             echo gamegear ;;
    *turbografx*|*pcengine*|tg16|pce)          echo pcengine ;;
    *neogeocd*)                                echo neogeocd ;;
    *neogeo*)                                  echo neogeo ;;
    *atari2600*)                               echo atari2600 ;;
    *atari5200*)                               echo atari5200 ;;
    *atari7800*)                               echo atari7800 ;;
    *atarilynx*|lynx)                          echo atarilynx ;;
    *wonderswancolor*)                         echo wonderswancolor ;;
    *wonderswan*)                              echo wonderswan ;;
    *)                                         echo "" ;;
  esac
}

is_dvd_system() { case "$1" in ps2) return 0 ;; *) return 1 ;; esac; }
