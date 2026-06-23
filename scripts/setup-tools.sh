#!/usr/bin/env bash
#
# setup-tools.sh — install the CLI tools used for off-deck ROM prep (Ubuntu/WSL2).
#
# Installs: chdman (mame-tools), p7zip (7z), unzip, rsync, openssh-client, and igir.
# Safe to re-run; skips anything already present.
#
set -euo pipefail

echo "==> Installing apt packages (chdman, 7z, unzip, rsync, ssh) ..."
sudo apt-get update
sudo apt-get install -y mame-tools p7zip-full unzip rsync openssh-client

echo
echo "==> Installing igir (ROM organizer) ..."
if command -v igir >/dev/null 2>&1; then
  echo "    igir already installed: $(command -v igir)"
elif command -v npm >/dev/null 2>&1; then
  npm install -g igir
else
  echo "    npm not found. Install Node, then: npm install -g igir"
  echo "    (or grab a prebuilt binary from https://github.com/emmercm/igir/releases)"
fi

echo
echo "==> Versions:"
for t in chdman 7z unzip rsync ssh igir; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "  %-8s " "$t"; "$t" --version 2>/dev/null | head -1 || echo "(ok)"
  else
    printf "  %-8s MISSING\n" "$t"
  fi
done
echo
echo "Done. chdman = CHD compression, igir = ROM sorting/validation, rsync/ssh = transfer to deck."
