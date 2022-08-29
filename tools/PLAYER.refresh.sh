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
echo "## PLAYER TW"

for PLAYER in $(ls ~/.zen/game/players/); do
    echo "PLAYER : $PLAYER"
    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "Missing $PLAYER IPNS KEY -- EXIT --" && exit 1

    rm -Rf ~/.zen/tmp/astro
    mkdir -p ~/.zen/tmp/astro

    ipfs --timeout 12s cat  /ipns/$ASTRONAUTENS > ~/.zen/tmp/astro/index.html


    if [ ! -s ~/.zen/tmp/astro/index.html ]; then
        echo "ERROR IPNS TIMEOUT. Unchanged local backup..."
        continue
    else
        ## Replace tube links with downloaded video
        $MY_PATH/TUBE.copy.sh ~/.zen/tmp/astro/index.html $PLAYER
        echo "DIFFERENCE ?"
        DIFF=$(diff ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html)
        if [[ $DIFF ]]; then
            echo "Backup & Upgrade TW local copy..."
            cp -f ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.backup.html
            cp ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        else
            echo "No change since last Refresh"
        fi
    fi

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ $DIFF ]] && cp ~/.zen/game/players/$PLAYER/ipfs/moa/.chain ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$MOATS

    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --key=$PLAYER /ipfs/$TW

    [[ $DIFF ]] && echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats

    echo "================================================"
    echo "$PLAYER : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
    echo "================================================"

done

exit 0
