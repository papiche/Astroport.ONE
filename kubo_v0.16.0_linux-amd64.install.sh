#!/bin/bash
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1
mkdir ~/.zen/tmp
cd  ~/.zen/tmp
wget https://dist.ipfs.tech/kubo/v0.17.0/kubo_v0.17.0_linux-amd64.tar.gz
tar -xvzf kubo_v0.17.0_linux-amd64.tar.gz
cd kubo
sudo bash install.sh
ipfs --version
