#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; script uses sudo when needed."
  exit 1
fi

sudo -v

say "Enable Terra repository (for ly)"
# Installs Terra repo definition; safe if already installed
sudo dnf -y install terra-release

say "Install ly display manager"
sudo dnf -y install ly

say "Disable other display managers if present"
for dm in gdm sddm lightdm; do
  sudo systemctl disable --now "${dm}.service" 2>/dev/null || true
done

say "Enable ly"
sudo systemctl enable ly.service

say "Ly installed and enabled"
echo "Reboot required to start using Ly: sudo reboot"
