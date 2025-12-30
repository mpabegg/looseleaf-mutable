#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; script uses sudo when needed."
  exit 1
fi

sudo -v

say "Remove python3-ly if installed (NOT the display manager)"
if rpm -q python3-ly >/dev/null 2>&1; then
  sudo dnf -y remove python3-ly
fi

say "Enable COPR for Ly display manager"
# Community-packaged Ly DM for Fedora
sudo dnf -y install dnf-plugins-core
sudo dnf -y copr enable adev/ly

say "Install Ly display manager"
sudo dnf -y install ly

say "Disable other display managers if present"
for dm in gdm sddm lightdm; do
  sudo systemctl disable --now "${dm}.service" 2>/dev/null || true
done

say "Enable Ly service"
if systemctl list-unit-files | grep -q '^ly\.service'; then
  sudo systemctl enable ly.service
elif systemctl list-unit-files | grep -q '^ly@\.service'; then
  # Some builds use a template unit
  sudo systemctl enable ly@tty2.service
else
  echo "ERROR: Ly installed but no systemd unit (ly.service or ly@.service) was found."
  echo "Check: rpm -ql ly | grep -E \"systemd|ly\\.service|ly@\""
  exit 1
fi

say "Ly installed and enabled"
echo "Reboot required to start using Ly: sudo reboot"
