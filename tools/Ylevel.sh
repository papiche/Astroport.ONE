#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

mkdir -p ~/.zen/game

## Convert SSH key into IPFS key (Node ID)

if [[ -s ~/.ssh/id_ed25519 ]]; then
    SSHASH=$(cat ~/.ssh/id_ed25519 | sha512sum | cut -d ' ' -f 1)
    SECRET1=$(echo "$SSHASH" | cut -c 1-64) && echo "SECRET1=$SECRET1"
    SECRET2=$(echo "$SSHASH" | cut -c 65-128) && echo "SECRET2=$SECRET2"
    SSHYNODEID=$(~/.zen/Astroport.ONE/tools/keygen -t ipfs "$SECRET1" "$SECRET2") && echo "SSHYNODEID=${SSHYNODEID}"

    if [[ ${SSHYNODEID} != ${IPFSNODEID} ]]; then
        echo "ACTIVATING Y LEVEL"
        ## Creating IPNSNODEID from SECRETS
        ~/.zen/Astroport.ONE/tools/keygen -t ipfs -o ~/.zen/game/secret.ipns "$SECRET1" "$SECRET2"
        ## Convert IPFS key to Duniter key (G1 Wallet)
        ~/.zen/Astroport.ONE/tools/keygen -i ~/.zen/game/secret.ipns -t duniter  -o ~/.zen/game/secret.dunikey

        ## EXTRACT PUB/PRIV KEY
        PeerID=$(~/.zen/Astroport.ONE/tools/keygen -i ~/.zen/game/secret.ipns -t ipfs)
        echo $PeerID
        PrivKey=$(~/.zen/Astroport.ONE/tools/keygen -i ~/.zen/game/secret.ipns -t ipfs -s)
        echo $PrivKey

        ~/.zen/Astroport.ONE/stop.sh

        # Backup actual Node ID
        cat ~/.ipfs/config | jq -r '.Identity.PeerID' \
            > ~/.zen/game/ipfsnodeid.bkp
        cat ~/.ipfs/config | jq -r '.Identity.PrivKey' \
            >> ~/.zen/game/ipfsnodeid.bkp

        # Insert new Node ID
        cp ~/.ipfs/config ~/.ipfs/config.bkp
        jq '.Identity.PeerID="'$PeerID'"' ~/.ipfs/config > ~/.ipfs/config.tmp
        jq '.Identity.PrivKey="'$PrivKey'"' ~/.ipfs/config.tmp > ~/.ipfs/config && rm ~/.ipfs/config.tmp

        # Verify & restart IPFS daemon
        [[ "$(cat ~/.ipfs/config | jq -r '.Identity.PrivKey' )" != "$PrivKey" ]] \
            && blurp="ERROR" \
            || blurp="SUCCESS"

        echo ${blurp}

        ## SUCCESS
        ## supprimer les anciennes clef de SWARM
        rm ~/.zen/game/myswarm_secret.*

        ## Réactivation Astroport.ONE
        ~/.zen/Astroport.ONE/start.sh
    else
        echo "Y LEVEL ALREADY ACTIVATED : $IPFSNODEID "
    fi

    NODEG1PUB=$(cat ~/.zen/game/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    echo "NODEG1PUB=${NODEG1PUB}"

fi

