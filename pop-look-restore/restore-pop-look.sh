#!/usr/bin/env bash
set -euo pipefail

DNF_PACKAGES=(
  pop-gtk2-theme
  pop-gtk3-theme
  pop-gtk4-theme
  pop-icon-theme
  pop-gnome-shell-theme
)

APT_CANDIDATE_PACKAGES=(
  pop-theme
  pop-gtk-theme
  pop-icon-theme
  pop-shell-theme
  pop-gnome-shell-theme
  pop-gtk2-theme
  pop-gtk3-theme
  pop-gtk4-theme
)

APT_BUILD_DEPS=(
  git
  meson
  ninja-build
  sassc
  libglib2.0-dev
  pkg-config
)

INSTALLED_FROM_SOURCE=0

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your desktop user (not root)."
  echo "It uses sudo only for package installation."
  exit 1
fi

install_with_dnf() {
  echo "Installing Pop packages with dnf..."
  sudo dnf -y install "${DNF_PACKAGES[@]}"
}

apt_pkg_exists() {
  apt-cache show "$1" >/dev/null 2>&1
}

install_pop_from_source_apt() {
  local workdir
  local gtk_repo
  local icon_repo
  local gtk_build
  local icon_build

  workdir="$(mktemp -d /tmp/pop-theme-src-XXXXXX)"
  gtk_repo="${workdir}/gtk-theme"
  icon_repo="${workdir}/icon-theme"
  gtk_build="${gtk_repo}/build"
  icon_build="${icon_repo}/build"

  echo "Installing build dependencies for source install..."
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_BUILD_DEPS[@]}"

  echo "Building and installing Pop GTK theme to ${HOME}/.local ..."
  git clone --depth=1 https://github.com/pop-os/gtk-theme.git "${gtk_repo}"
  meson setup "${gtk_build}" "${gtk_repo}" --prefix="${HOME}/.local"
  ninja -C "${gtk_build}" install

  echo "Building and installing Pop icon theme to ${HOME}/.local ..."
  git clone --depth=1 https://github.com/pop-os/icon-theme.git "${icon_repo}"
  meson setup "${icon_build}" "${icon_repo}" --prefix="${HOME}/.local"
  ninja -C "${icon_build}" install

  rm -rf "${workdir}"
  INSTALLED_FROM_SOURCE=1
}

install_with_apt() {
  local pkg
  local install_list=()

  echo "Refreshing apt package index..."
  sudo apt-get update

  for pkg in "${APT_CANDIDATE_PACKAGES[@]}"; do
    if apt_pkg_exists "${pkg}"; then
      install_list+=("${pkg}")
    fi
  done

  if [[ "${#install_list[@]}" -eq 0 ]]; then
    echo "No Pop theme packages found in apt repositories."
    echo "Checked packages: ${APT_CANDIDATE_PACKAGES[*]}"
    echo "Falling back to source install from official Pop OS repositories..."
    install_pop_from_source_apt
    return
  fi

  echo "Installing Pop packages with apt: ${install_list[*]}"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${install_list[@]}"
}

if command -v dnf >/dev/null 2>&1; then
  install_with_dnf
elif command -v apt-get >/dev/null 2>&1; then
  install_with_apt
else
  echo "No supported package manager found. Supported: dnf, apt-get."
  exit 1
fi

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
if command -v rpm >/dev/null 2>&1; then
  rpm -qa | grep '^pop-' | sort || true
elif command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E '^pop-' | sort || true
fi
if [[ "${INSTALLED_FROM_SOURCE}" -eq 1 ]]; then
  echo "Installed from source to ${HOME}/.local:"
  ls -1d "${HOME}"/.local/share/themes/Pop* 2>/dev/null || true
  ls -1d "${HOME}"/.local/share/icons/Pop* 2>/dev/null || true
fi

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
