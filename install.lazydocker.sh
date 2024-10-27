#!/bin/bash
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

## INSTALL LAZYDOCKER
## CLI docker control board
## TODO GET IT FROM IPFS !!

mkdir -p ~/.zen/tmp
cd  ~/.zen/tmp

# Prepare right file
ARCH=$(uname -m)
case $ARCH in
    i386|i686) ARCH=x86 ;;
    armv6*) ARCH=armv6 ;;
    armv7*) ARCH=armv7 ;;
    aarch64*) ARCH=arm64 ;;
esac

VERSION="v0.23.3"
GITHUB_FILE="lazydocker_${VERSION//v/}_$(uname -s)_${ARCH}.tar.gz"
GITHUB_URL="https://github.com/jesseduffield/lazydocker/releases/download/${VERSION}/${GITHUB_FILE}"
######################################################
DIR="$HOME/.local/bin"
mkdir -p "$DIR"

echo "curl -L -o lazydocker.tar.gz $GITHUB_URL"
curl -L -o lazydocker.tar.gz $GITHUB_URL

tar xzvf lazydocker.tar.gz lazydocker
install -Dm 755 lazydocker -t "$DIR"
rm lazydocker lazydocker.tar.gz

# Test
[[ ! $(ls ~/.local/bin/lazydocker) ]] \
&& echo "ERROR. lazydocker NOT installed" && exit 1 \
|| echo "lazydocker installed"

exit 0
