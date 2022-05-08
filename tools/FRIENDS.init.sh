#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2020.03.24
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
countMErunning=$(ps auxf --sort=+utime | grep -w $ME | grep -v -E 'color=auto|grep' | wc -l)
[[ $countMErunning -gt 2 ]] && echo "$ME already running $countMErunning time" && exit 0
start=`date +%s`

YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1) && [[ ! $YOU ]] && echo "ipfs NOT RUNNING. EXIT" && exit 1
G1PUB=$(cat ~/.zen/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2) && [[ ! $G1PUB ]] && echo "ERREUR G1PUB. EXIT" && exit 1
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID) || ( echo "noipfsid" && exit 1 )
########################################################################
########################################################################
# This script used to initialize 'FRIENDS' data and star.level with beetween crew and new Astronaut
# Astronaut is sendind level3 to Captain / # Captain send level1 to Astronaut
# astrXbian keychains are written to disk... So IPFS obey to this organisation.
########################################################################
########################################################################
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Check who is currently current connected PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )

# Astroport Station "Captain" connected?
source ~/.zen/ipfs.sync; echo "CAPTAIN is $CAPTAIN $(${MY_PATH}/face.sh cool)"


# New Astronaut is entering Astroport
# UPDATING players friend relations
# Inform Captain.
for player in $(ls ~/.zen/game/players/); do
    # $player g1pub
    g1pub=$(cat ~/.zen/game/players/$player/.g1pub) || continue
    ipfsnodeid=$(cat ~/.zen/game/players/$player/.ipfsnodeid) || continue

    [[ $PLAYER == $player ]] && continue
    ## Adding ME as Astronauts Friend. Sharing Stars.
    # Inform Network / Application levels. Friend of Friends appears here.

    echo "Adding $player to my astrXbian ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/FRIENDS/$g1pub"
    read
    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/FRIENDS/$g1pub # Opening FRIEND RELATION
    echo "$player" > ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/FRIENDS/$g1pub/player  # This Astronaut become my level 1 friend
    echo "1" > ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/FRIENDS/$g1pub/stars.level  # This Astronaut become my level 1 friend
    echo "$ipfsnodeid" > ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/FRIENDS/$g1pub/ipfsnodeid # This Astronaut become my level 1 friend

    if [[ $player == "$CAPTAIN" ]]; then
        echo "Cet Astronaute est le CAPITAINE. Confiance 3 !!!"
        echo "3" > ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/FRIENDS/$g1pub/stars.level  # Ugrade to Level 3 Friend
        # Need to receive confidence back before acting as Astronaut. 3 days to compare dreams & reality.
    fi

    echo "Adding myself to $player ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/$G1PUB"
    read
    mkdir -p ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/$G1PUB # AUTO SYMETRIC RELATION TODO : Not overpassing anymore ?
    echo "$PLAYER" > ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/$G1PUB/player  # This Astronaut become my level 1 friend
    echo "1" > ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/$G1PUB/stars.level
    echo "$IPFSNODEID" > ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/$G1PUB/ipfsnodeid # TODO : Not overpassing anymore ?
    echo "Compromis de Confiance 1 ajouté à $player"


done

