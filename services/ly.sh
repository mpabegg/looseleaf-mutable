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

say "Enable COPR for Ly display manager (Fedora 43 compatible)"
sudo dnf -y install dnf-plugins-core
sudo dnf -y copr enable fnux/ly

say "Install Ly display manager"
sudo dnf -y install ly

say "Ensure graphical target is default"
sudo systemctl set-default graphical.target

say "Disable other display managers if present"
for dm in gdm sddm lightdm; do
  sudo systemctl disable --now "${dm}.service" 2>/dev/null || true
done

say "Enable Ly service (try common unit names)"
if systemctl list-unit-files --no-pager | grep -q '^ly\.service'; then
  sudo systemctl enable --now ly.service
elif systemctl list-unit-files --no-pager | grep -q '^ly@\.service'; then
  sudo systemctl enable --now ly@tty2.service
else
  echo "ERROR: Ly installed but no systemd unit found (ly.service or ly@.service)."
  echo "Debug:"
  echo "  rpm -ql ly | grep -Ei 'systemd|ly\\.service|ly@'"
  exit 1
fi

say "Ly installed and enabled"
echo "Reboot required: sudo reboot"
