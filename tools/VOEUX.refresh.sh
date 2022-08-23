#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
################################################################################
# Inspect game wishes, refresh latest IPNS version
# Backup and chain

[[ $PLAYER == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)


############################################
## WORLD VOEUX

for voeu in $(ls ~/.zen/game/world/);
do
    echo "VOEU : $voeu"
    voeuns=$($MY_PATH/g1_to_ipfs.py $voeu)
    echo "http://127.0.0.1:8080/ipns/$voeuns"
    echo
    W=$(cat ~/.zen/game/world/$voeu/.pepper 2>/dev/null)
    echo $W

    mkdir -p ~/.zen/tmp/work

    echo "Getting latest online TW..."
    ipfs --timeout 12s get -o ~/.zen/tmp/work /ipns/$voeuns


    if [[ ! -f ~/.zen/tmp/work/index.html ]]; then
        echo "UNAVAILABLE WISH! If you want to remove $W $voeu"
        echo "ipfs key rm $voeu && rm -Rf ~/.zen/game/world/$voeu"
        continue
    fi

    # RECORDING BLOCKCHAIN TIC
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    cp ~/.zen/game/world/$voeu/.chain ~/.zen/game/world/$voeu/.chain.old
    IPUSH=$(ipfs add -rHq ~/.zen/game/world/$voeu/ | tail -n 1)
    echo $IPUSH > ~/.zen/game/world/$voeu/.chain
    echo $MOATS > ~/.zen/game/world/$voeu/.moats
    ipfs name publish --key=${voeu} /ipfs/$IPUSH 2>/dev/null

    rm -Rf ~/.zen/tmp/work

    if [[ -d ~/.zen/game/players/$PLAYER/voeux/$voeu ]]; then
        echo "Commande de suppression du Voeu$W (A effacer manuellement de votre TW"
        echo "ipfs key rm $voeu && rm -Rf ~/.zen/game/world/$voeu && rm -Rf ~/.zen/game/players/$PLAYER/voeux/$voeu"
        # read QUOI
        # [[ "$QUOI" != "" ]] &&  ipfs key rm $voeu && rm -Rf ~/.zen/game/world/$voeu && rm -Rf ~/.zen/game/players/$PLAYER/voeux/$voeu && echo "SUPRESSION OK"
    fi

done

############################################
## PLAYER TW

for PLAYER in $(ls ~/.zen/game/players/); do
    echo "$PLAYER"
    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(cat ~/.zen/game/players/$PLAYER/.playerns)
    rm -Rf ~/.zen/tmp/astro
    ipfs --timeout 12s get -o ~/.zen/tmp/astro /ipns/$ASTRONAUTENS

    if [ ! -f ~/.zen/tmp/astro/index.html ]; then
        echo "ERROR IPNS TIMEOUT. Using local backup..."
    else
        echo "Upgrade TW local copy..."
        cp ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
    fi

    TW=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/moa/ | tail -n 1)
    ipfs name publish --key=$PLAYER /ipfs/$TW

done

exit 0
