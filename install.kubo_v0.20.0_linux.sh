#!/bin/bash
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

mkdir -p ~/.zen/tmp
cd  ~/.zen/tmp

# Check processor architecture
architecture=$(uname -m)

# Download appropriate version of kubo
if [ "$architecture" == "x86_64" ]; then
    wget --no-check-certificate -O kubo.tar.gz https://dist.ipfs.tech/kubo/v0.20.0/kubo_v0.20.0_linux-amd64.tar.gz
    # /ipfs/QmPA3PLy3pCFssr9vFn9SY2amegWT3GyFYS1g4T5hJwW4d
elif [ "$architecture" == "aarch64" ]; then
    wget --no-check-certificate -O kubo.tar.gz https://dist.ipfs.tech/kubo/v0.20.0/kubo_v0.20.0_linux-arm64.tar.gz
    # /ipfs/QmaLDWNLLUpTSZUE9YaZq3id6bNDcZsEmaW7xQFrzhD7Yy
elif [ "$architecture" == "armv7l" || "$architecture" == "armv6l" ]; then
    wget --no-check-certificate -O kubo.tar.gz https://dist.ipfs.tech/kubo/v0.20.0/kubo_v0.20.0_linux-arm.tar.gz
    # /ipfs/QmWA5L51H7ALodxWv3nT1XhWbRLdFVjC1SPENCFMH9nQAc
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
