#!/bin/bash
# echo create data set to include into tagcloud
# HERE YOU CAN MODIFY HOMEPAGE TAGCLOUD PROPERTIES
DATA=""

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Check who is currently current connected PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )

# Astroport Station "Captain" connected?
source ~/.zen/ipfs.sync; echo "CAPTAIN is $CAPTAIN"

for player in $(ls ~/.zen/game/players/); do

    moans=$(cat ~/.zen/game/players/$player/.moans)
    pseudo=$(cat ~/.zen/game/players/$player/.pseudo)

    # CHECK DIFFERENCES FROM LATEST TIME CHECK
    ## GETTING LAST 'player_moa' ONLINE VERSION
    ipfs cat /ipns/$moans > ~/.zen/game/players/$player/moa/index.html
    IPUSH=$(ipfs add -Hq ~/.zen/game/players/$player/moa/index.html | tail -n 1)

    # Avance la blockchain CAPTAIN pour archiver les '$player.moa.chain' des Etats modifiés
    [[ $(cat ~/.zen/game/players/$CAPTAIN/moa/$player.moa.chain 2>/dev/null) != "$IPUSH" ]] &&\
        echo $IPUSH > ~/.zen/game/players/$CAPTAIN/moa/$player.moa.chain && \
        echo $MOATS > ~/.zen/game/players/$CAPTAIN/moa/$player.moa.ts && \
        MODIF=$(cat ~/.zen/game/players/$CAPTAIN/moa/$player.moa.n) && MODIF=$((MODIF+1)) || MODIF=1 && \
        echo $MODIF > ~/.zen/game/players/$CAPTAIN/moa/$player.moa.n

    echo "$player 'moa' UPDATE : $MOATS $IPUSH" && \
    DATA="$DATA { name: '"${pseudo}"', link: '"/ipns/${moans}"', weight: "$(cat ~/.zen/game/players/$CAPTAIN/moa/$player.moa.n)", tooltip: '"${player}"' },"
done

echo 'data: [ '$DATA' ]'
