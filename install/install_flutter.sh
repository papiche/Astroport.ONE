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
for pkg in unzip xz-utils clang cmake ninja-build pkg-config libgtk-3-dev; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo "[install_flutter][$(timestamp)] Installing dependency: $pkg" >&2
        sudo apt-get install -y "$pkg" 2>/dev/null || true
    fi
done

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
