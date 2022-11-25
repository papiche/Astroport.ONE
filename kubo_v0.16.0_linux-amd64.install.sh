#!/bin/bash
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

# Download & decompress
mkdir ~/.zen/tmp
cd  ~/.zen/tmp
wget https://dist.ipfs.tech/kubo/v0.16.0/kubo_v0.16.0_linux-amd64.tar.gz
tar -xvzf kubo_v0.16.0_linux-amd64.tar.gz
cd kubo

# Install
sudo bash install.sh

# Test & clean
[[ $(ipfs --version) ]] \
&& rm -Rf ~/.zen/tmp/kubo*
