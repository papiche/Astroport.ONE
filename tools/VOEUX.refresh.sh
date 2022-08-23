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
    ipfs --timeout 12s get -o ~/.zen/tmp/work/ /ipns/$voeuns


    if [[ ! -f ~/.zen/tmp/work/index.html ]]; then
        echo "UNAVAILABLE WISH! Removing $W $voeu"
        ipfs key rm $voeu
        rm -Rf ~/.zen/game/world/$voeu
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
        echo "Supprimer votre voeux $W? Tapez sur ENTRER pour passer au voeu suivant..."
        read QUOI
        [[ "$QUOI" != "" ]] &&  ipfs key rm $voeu && rm -Rf ~/.zen/game/world/$voeu && rm -Rf ~/.zen/game/players/$PLAYER/voeux/$voeu && echo "SUPRESSION OK"
    fi

done

