#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; uses sudo when needed."
  exit 1
fi

sudo -v

say "Install build dependencies for Ly (Fedora)"
# From Ly README (Fedora deps). zig 0.15.x is required. :contentReference[oaicite:5]{index=5}
sudo dnf -y install \
  git \
  kernel-devel \
  pam-devel \
  libxcb-devel \
  zig \
  xorg-x11-xauth \
  xorg-x11-server-Xorg \
  brightnessctl

say "Build + install Ly from source (systemd)"
WORKDIR="${HOME}/.cache/looseleaf-build/ly"
rm -rf "${WORKDIR}"
mkdir -p "$(dirname "${WORKDIR}")"

# README notes development happens on Codeberg (GitHub is a mirror). :contentReference[oaicite:6]{index=6}
git clone https://codeberg.org/fairyglade/ly.git "${WORKDIR}"
cd "${WORKDIR}"

# Install executable + systemd units (init_system defaults to systemd, but we pass explicitly). :contentReference[oaicite:7]{index=7}
sudo zig build installexe -Dinit_system=systemd

say "Disable other display managers if present"
for dm in gdm sddm lightdm; do
  sudo systemctl disable --now "${dm}.service" 2>/dev/null || true
done

say "Configure systemd TTY for Ly (tty2)"
# README: enable ly@tty2.service and disable getty@tty2.service. :contentReference[oaicite:8]{index=8}
sudo systemctl disable --now getty@tty2.service 2>/dev/null || true
sudo systemctl enable ly@tty2.service

say "Ensure graphical target is default"
sudo systemctl set-default graphical.target

say "Ly installed and enabled on tty2"
echo "Reboot required: sudo reboot"
