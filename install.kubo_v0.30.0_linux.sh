#!/bin/bash
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

## Check if ipfs is running ?
ipfsrunning=$(ps auxf | grep -w 'ipfs' | grep -v -E 'color=auto|grep' | tail -n 1 | xargs | cut -d " " -f 1)
[ ! -z $ipfsrunning ] && echo " $ipfsrunning is running IPFS daemon... please shutdown !" && exit 1

mkdir -p ~/.zen/tmp
cd  ~/.zen/tmp

# Check processor architecture
architecture=$(uname -m)

# Download appropriate version of kubo
if [ "$architecture" == "x86_64" ]; then
    wget --no-check-certificate -O kubo.tar.gz https://dist.ipfs.tech/kubo/v0.36.0/kubo_v0.36.0_linux-amd64.tar.gz
elif [ "$architecture" == "aarch64" ]; then
    wget --no-check-certificate -O kubo.tar.gz https://dist.ipfs.tech/kubo/v0.36.0/kubo_v0.36.0_linux-arm64.tar.gz
elif [ "$architecture" == "armv7l" || "$architecture" == "armv6l" ]; then
    wget --no-check-certificate -O kubo.tar.gz https://dist.ipfs.tech/kubo/v0.36.0/kubo_v0.36.0_linux-arm.tar.gz
else
    echo "Error: Unknown architecture"
    exit 1
fi

tar -xvzf kubo.tar.gz

cd kubo

# Install
sudo bash install.sh

# Test & clean
[[ $(ipfs --version) ]] \
&& rm -Rf ~/.zen/tmp/kubo* \
|| echo "problem occured"

exit 0
