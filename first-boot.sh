#!/usr/bin/env bash
set -euo pipefail

# Looseleaf First Boot (Fedora Custom OS)
# - Safe baseline for a script-managed mutable Fedora
# - No desktop installs yet
# - Preps snapshots tooling, dev essentials, Flatpak, and a bootstrap repo scaffold

if [[ $EUID -eq 0 ]]; then
  echo "Do not run as root. Run as your normal user (it will sudo when needed)."
  exit 1
fi

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

say "Checking sudo access"
sudo -v

say "Detecting Fedora version"
. /etc/os-release
echo "NAME=$NAME VERSION_ID=$VERSION_ID"
if [[ "${ID:-}" != "fedora" ]]; then
  echo "This script expects Fedora. Aborting."
  exit 1
fi

say "Enable faster dnf defaults (safe tweaks)"
sudo install -d -m 0755 /etc/dnf
sudo tee /etc/dnf/dnf.conf >/dev/null <<'CONF'
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
deltarpm=False
CONF

say "System update"
sudo dnf -y upgrade --refresh

say "Install baseline utilities (no GUI desktops)"
# Notes:
# - btrfs-progs: for snapshots if you used Btrfs
# - snapper/timeshift: pick one later; install both for now
# - firewalld + NetworkManager: should already exist, but we ensure.
# - pipewire + wireplumber: modern audio (useful once you add a DE)
# - virtualization agents: helpful in VMs
sudo dnf -y install \
  git \
  curl \
  wget \
  ca-certificates \
  gnupg2 \
  neovim \
  tmux \
  zsh \
  ripgrep \
  fd-find \
  fzf \
  jq \
  unzip \
  tar \
  rsync \
  man-db \
  man-pages \
  bash-completion \
  NetworkManager \
  NetworkManager-wifi \
  firewalld \
  btrfs-progs \
  snapper \
  snapper-plugins \
  timeshift \
  policycoreutils-python-utils \
  pipewire \
  pipewire-pulse \
  wireplumber \
  alsa-utils \
  p7zip \
  qemu-guest-agent \
  spice-vdagent

say "Enable core services"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now firewalld

# VM quality-of-life (harmless on bare metal if packages not used)
sudo systemctl enable --now qemu-guest-agent || true
sudo systemctl enable --now spice-vdagentd || true

say "Enable Flathub (Flatpak-first posture)"
# Flatpak may not be installed on minimal; ensure it exists.
sudo dnf -y install flatpak
if ! flatpak remotes --columns=name 2>/dev/null | grep -q '^flathub$'; then
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

say "Create bootstrap repo scaffold"
BOOTSTRAP_DIR="${HOME}/src/looseleaf-bootstrap"
mkdir -p "${BOOTSTRAP_DIR}"
mkdir -p "${BOOTSTRAP_DIR}/"{packages,services,desktops,files,etc,docs}
mkdir -p "${BOOTSTRAP_DIR}/files/etc/"{xdg,systemd,sddm.conf.d}
mkdir -p "${BOOTSTRAP_DIR}/packages"

cat > "${BOOTSTRAP_DIR}/README.md" <<'MD'
# looseleaf-bootstrap

Mutable Fedora bootstrap for Looseleaf.

Goals:
- script-managed, reproducible-enough
- multi-DE friendly: COSMIC (default), KDE (fallback), Scroll+DMS (experimental)
- no "mystery state": if it's installed/enabled, it's in this repo

Structure:
- packages/*.txt: package lists
- desktops/*.sh: install/config per desktop
- services/*.sh: enable/disable services and session hygiene
- files/: config files copied into / (use install.sh to apply)

Next steps:
1) fill packages/base.txt
2) implement install.sh to apply packages + files
3) add desktops/cosmic.sh, desktops/kde.sh
MD

cat > "${BOOTSTRAP_DIR}/packages/base.txt" <<'TXT'
# Base packages for Looseleaf (edit freely)
git
curl
wget
neovim
tmux
zsh
ripgrep
fd-find
fzf
jq
unzip
rsync
man-db
man-pages
NetworkManager
NetworkManager-wifi
firewalld
pipewire
pipewire-pulse
wireplumber
flatpak
TXT

cat > "${BOOTSTRAP_DIR}/install.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; script uses sudo when needed."
  exit 1
fi

sudo -v

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say "Install base packages"
sudo dnf -y install $(grep -Ev '^\s*#|^\s*$' "${ROOT}/packages/base.txt")

say "Copy system files (files/ -> /)"
if [[ -d "${ROOT}/files" ]]; then
  sudo rsync -aHAX --delete "${ROOT}/files/" /
fi

say "Done."
SH
chmod +x "${BOOTSTRAP_DIR}/install.sh"

say "Initialize git repo (optional)"
if [[ ! -d "${BOOTSTRAP_DIR}/.git" ]]; then
  git -C "${BOOTSTRAP_DIR}" init >/dev/null
  git -C "${BOOTSTRAP_DIR}" add -A
  git -C "${BOOTSTRAP_DIR}" commit -m "Initial bootstrap scaffold" >/dev/null || true
fi

say "Summary"
cat <<EOF
- System updated
- Baseline packages installed
- NetworkManager + firewalld enabled
- Flathub remote configured
- Bootstrap repo created at: ${BOOTSTRAP_DIR}

Next:
  cd ${BOOTSTRAP_DIR}
  ./install.sh

Then we can add COSMIC (desktops/cosmic.sh) and later KDE + Scroll/DMS.
EOF

say "Reboot recommended"
echo "Run: sudo reboot"
