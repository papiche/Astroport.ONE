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

    echo "$player 'moa' UPDATE : $MOATS $IPUSH" && \
    DATA="$DATA { name: '"${pseudo}"', link: '"/ipns/${moans}"', weight: "$(cat ~/.zen/game/players/$player/moa/$player.moa.n)", tooltip: '"${player}"' },"
done

echo 'data: [ '$DATA' ]'
