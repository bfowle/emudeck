#!/usr/bin/env bash
# retroarch-systems.sh — map a roms/<folder> system id to RetroArch's database
# name. That exact name is used for BOTH the .lpl playlist filename AND the
# thumbnails/<name>/ folder, and must match libretro's naming or art won't resolve.
# Sourced by make-retroarch-playlists.sh and get-retroarch-thumbnails.sh.
#
#   ra_db_name <system-id>   -> echoes "Vendor - System", or "" if unmapped
#
# Add systems as needed; an unmapped folder is simply skipped (non-fatal).
ra_db_name() {
  case "$1" in
    nes)               echo "Nintendo - Nintendo Entertainment System" ;;
    snes)              echo "Nintendo - Super Nintendo Entertainment System" ;;
    n64)               echo "Nintendo - Nintendo 64" ;;
    gb)                echo "Nintendo - Game Boy" ;;
    gbc)               echo "Nintendo - Game Boy Color" ;;
    gba)               echo "Nintendo - Game Boy Advance" ;;
    nds)               echo "Nintendo - Nintendo DS" ;;
    gc)                echo "Nintendo - GameCube" ;;
    wii)               echo "Nintendo - Wii" ;;
    virtualboy)        echo "Nintendo - Virtual Boy" ;;
    segacd)            echo "Sega - Mega-CD - Sega CD" ;;
    megadrive|genesis) echo "Sega - Mega Drive - Genesis" ;;
    sega32x)           echo "Sega - 32X" ;;
    mastersystem)      echo "Sega - Master System - Mark III" ;;
    gamegear)          echo "Sega - Game Gear" ;;
    saturn)            echo "Sega - Saturn" ;;
    dreamcast)         echo "Sega - Dreamcast" ;;
    sg1000)            echo "Sega - SG-1000" ;;
    psx)               echo "Sony - PlayStation" ;;
    ps2)               echo "Sony - PlayStation 2" ;;
    psp)               echo "Sony - PlayStation Portable" ;;
    pcengine)          echo "NEC - PC Engine - TurboGrafx 16" ;;
    pcenginecd)        echo "NEC - PC Engine CD - TurboGrafx-CD" ;;
    supergrafx)        echo "NEC - PC Engine SuperGrafx" ;;
    neogeo)            echo "SNK - Neo Geo" ;;
    neogeocd)          echo "SNK - Neo Geo CD" ;;
    ngp)               echo "SNK - Neo Geo Pocket" ;;
    ngpc)              echo "SNK - Neo Geo Pocket Color" ;;
    atari2600)         echo "Atari - 2600" ;;
    atari5200)         echo "Atari - 5200" ;;
    atari7800)         echo "Atari - 7800" ;;
    atarilynx)         echo "Atari - Lynx" ;;
    wonderswan)        echo "Bandai - WonderSwan" ;;
    wonderswancolor)   echo "Bandai - WonderSwan Color" ;;
    colecovision)      echo "Coleco - ColecoVision" ;;
    intellivision)     echo "Mattel - Intellivision" ;;
    vectrex)           echo "GCE - Vectrex" ;;
    3do)               echo "The 3DO Company - 3DO" ;;
    msx)               echo "Microsoft - MSX" ;;
    c64)               echo "Commodore - 64" ;;
    amiga)             echo "Commodore - Amiga" ;;
    *)                 echo "" ;;
  esac
}
