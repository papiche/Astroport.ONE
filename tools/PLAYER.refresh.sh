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

        echo "Upgrade TW local copy..."
        cp ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
    fi

    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --key=$PLAYER /ipfs/$TW

    echo "$PLAYER : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"


done

exit 0
