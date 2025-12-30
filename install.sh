#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; script uses sudo when needed."
  exit 1
fi

sudo -v

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say "Install base packages (if packages/base.txt exists)"
if [[ -f "${ROOT}/packages/base.txt" ]]; then
  mapfile -t PKGS < <(grep -Ev '^\s*#|^\s*$' "${ROOT}/packages/base.txt" || true)
  if (( ${#PKGS[@]} > 0 )); then
    sudo dnf -y install "${PKGS[@]}"
  else
    echo "packages/base.txt is empty; skipping base package install."
  fi
else
  echo "No packages/base.txt found; skipping base package install."
fi

say "Copy system files (files/ -> /) if present"
if [[ -d "${ROOT}/files" ]]; then
  sudo rsync -aHAX --delete "${ROOT}/files/" /
else
  echo "No files/ directory found; skipping file sync."
fi

say "Run service installers"
if [[ -d "${ROOT}/services" ]]; then
  shopt -s nullglob
  for f in "${ROOT}/services/"*.sh; do
    say "Running $(basename "$f")"
    bash "$f"
  done
  shopt -u nullglob
else
  echo "No services/ directory found; skipping services."
fi

say "Done."
