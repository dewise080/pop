#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(
  pop-gtk2-theme
  pop-gtk3-theme
  pop-gtk4-theme
  pop-icon-theme
  pop-gnome-shell-theme
)

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your desktop user (not root)."
  echo "It uses sudo only for package installation."
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "dnf is required but was not found."
  exit 1
fi

echo "Installing Pop packages..."
sudo dnf -y install "${PACKAGES[@]}"

RUNTIME_DIR="/run/user/$(id -u)"
BUS_PATH="${RUNTIME_DIR}/bus"

if [[ -S "${BUS_PATH}" ]]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${BUS_PATH}"
fi
export XDG_RUNTIME_DIR="${RUNTIME_DIR}"

echo "Applying GNOME settings..."
gsettings set org.gnome.desktop.interface gtk-theme "'Pop-dark'"
gsettings set org.gnome.desktop.interface icon-theme "'Pop'"
gsettings set org.gnome.desktop.interface cursor-theme "'Pop'"
gsettings set org.gnome.desktop.interface font-name "'Cantarell 11'"
gsettings set org.gnome.desktop.interface document-font-name "'Cantarell 11'"
gsettings set org.gnome.desktop.interface monospace-font-name "'Monospace 11'"
gsettings set org.gnome.desktop.interface color-scheme "'prefer-dark'"
gsettings set org.gnome.desktop.wm.preferences theme "'Pop-dark'"

echo
echo "Installed Pop packages:"
rpm -qa | grep '^pop-.*theme' | sort

echo
echo "Current GNOME values:"
for k in gtk-theme icon-theme cursor-theme font-name document-font-name monospace-font-name color-scheme; do
  printf "%s=" "${k}"
  gsettings get org.gnome.desktop.interface "${k}"
done
printf "wm-theme="
gsettings get org.gnome.desktop.wm.preferences theme

echo
echo "Done."
