#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; uses sudo."
  exit 1
fi

sudo -v

say "Disable Ly (if previously enabled)"
sudo systemctl disable --now ly@tty2.service 2>/dev/null || true
sudo systemctl disable --now ly.service 2>/dev/null || true

say "Re-enable getty on tty2 (Ly usually steals it)"
sudo systemctl enable --now getty@tty2.service 2>/dev/null || true

say "Install greetd + tuigreet"
sudo dnf -y install greetd tuigreet

say "Configure greetd"
sudo install -d -m 0755 /etc/greetd

# Default: drop you into a TUI login and start Niri after auth.
# Change --cmd later to: cosmic-session, startplasma-wayland, etc.
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-user-session --cmd niri"
user = "greeter"
EOF

say "Ensure graphical target is default"
sudo systemctl set-default graphical.target

say "Disable other display managers if present"
for dm in gdm sddm lightdm; do
  sudo systemctl disable --now "${dm}.service" 2>/dev/null || true
done

say "Enable greetd"
sudo systemctl enable --now greetd.service

say "Done"
echo "Reboot recommended: sudo reboot"
