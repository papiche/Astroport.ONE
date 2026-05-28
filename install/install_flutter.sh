#!/bin/bash
########################################################################
# install_flutter.sh
# Install Flutter SDK for web builds (ginkgo app).
# Installs to $HOME/.flutter via git clone (stable channel).
# Only web target is needed — no Android SDK or desktop deps required.
########################################################################

set -euo pipefail

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

FLUTTER_DIR="${FLUTTER_HOME:-$HOME/.flutter}"

echo "[install_flutter][$(timestamp)] Installing Flutter SDK to $FLUTTER_DIR" >&2

## Prerequisites: git, curl, unzip, xz-utils (cmake/clang already in install.sh)
_flutter_PKG_MGR="apt"; command -v pacman >/dev/null 2>&1 && _flutter_PKG_MGR="pacman"
_flutter_install_dep() {
    local deb_pkg="$1" arch_pkg="${2:-$1}"
    if [[ "$_flutter_PKG_MGR" == "pacman" ]]; then
        pacman -Qs "^${arch_pkg}$" >/dev/null 2>&1 \
            || sudo pacman -S --noconfirm --needed "$arch_pkg" 2>/dev/null || true
    else
        dpkg -s "$deb_pkg" &>/dev/null \
            || sudo apt-get install -y "$deb_pkg" 2>/dev/null || true
    fi
}
_flutter_install_dep unzip      unzip
_flutter_install_dep xz-utils   xz
_flutter_install_dep clang      clang
_flutter_install_dep cmake      cmake
_flutter_install_dep ninja-build ninja
_flutter_install_dep pkg-config  pkgconf
_flutter_install_dep libgtk-3-dev gtk3

## Already installed?
if [[ -x "$FLUTTER_DIR/bin/flutter" ]]; then
    echo "[install_flutter][$(timestamp)] Flutter already installed at $FLUTTER_DIR" >&2
    "$FLUTTER_DIR/bin/flutter" --version
    echo "[install_flutter][$(timestamp)] Upgrading Flutter..." >&2
    cd "$FLUTTER_DIR"
    git pull
    "$FLUTTER_DIR/bin/flutter" precache --web
    exit 0
fi

## Clone Flutter stable
echo "[install_flutter][$(timestamp)] Cloning Flutter stable channel..." >&2
git clone -b stable --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_DIR"

## Precache web artifacts only (skip Android/iOS/desktop)
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter precache --web

## Disable analytics
flutter config --no-analytics 2>/dev/null || true
dart --disable-analytics 2>/dev/null || true

## Verify
flutter --version
echo "[install_flutter][$(timestamp)] Flutter SDK installed successfully" >&2

## Add to PATH in .bashrc if not already there
if ! grep -q '.flutter/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# Flutter SDK" >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.flutter/bin:$PATH"' >> "$HOME/.bashrc"
    echo "[install_flutter][$(timestamp)] Added Flutter to ~/.bashrc PATH" >&2
fi

echo "[install_flutter][$(timestamp)] Done. Flutter web ready." >&2
