#!/bin/bash
## INSTALL UPassport
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

echo "INSTALLING UPassport API : http://localhost:54321"

if [[ ! -d ~/.zen/UPassport ]]; then
    ## PATH CONTROL
    mkdir -p ~/.zen
    cd ~/.zen

    # Clone REPO
    git clone --depth 1 https://github.com/papiche/UPassport.git
    cd UPassport

    # INstall python packages
    pip install -U -r requirements.txt

    # Setup systemd startup script
    ./setup_systemd.sh

    ## CREATE .env
    # Ǧinspecte : https://ginspecte.mithril.re/
cat > .env <<EOL
myDUNITER="https://g1.cgeek.fr"
myCESIUM="https://g1.data.e-is.pro"
ipfsNODE="$myIPFS"
CESIUMAPPIPFS="$CESIUMIPFS"
OBSkey="null"
EOL

    echo "############################################################"
    echo "# Adapt .env using Ǧinspecte : https://ginspecte.mithril.re/"
    echo "############################################################"
    cat .env
    ## BACK TO
    cd -

else

    echo "ALREADY INSTALLED"
    ls ~/.zen/UPassport

fi

exit 0
