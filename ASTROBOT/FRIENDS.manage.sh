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

YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1) && [[ ! $YOU ]] && echo "ipfs NOT RUNNING. EXIT" && exit 1
G1PUB=$(cat ~/.zen/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2) && [[ ! $G1PUB ]] && echo "ERREUR G1PUB. EXIT" && exit 1
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID) || ( echo "noipfsid" && exit 1 )
########################################################################
########################################################################
# This script could be used to manage .current Astronaut Friendships
# But thinking about it. Is is better to keep Gchange as confidence level collector.
########################################################################
echo "# Script needs enhancement or better a dedicated 'AApp' acting on IPFS directly."
########################################################################
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Check who is currently current connected PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )

# Astroport Station "Captain" connected?
source ~/.zen/ipfs.sync; echo "CAPTAIN is $CAPTAIN $(${MY_PATH}/face.sh cool)"
echo
echo "$PLAYER bon parcours amical (N+2)"
echo
echo
for player in $(ls ~/.zen/game/players/); do
    # $player g1pub
    g1pub=$(cat ~/.zen/game/players/$player/.g1pub) || continue
    ipfsnodeid=$(cat ~/.zen/game/players/$player/.ipfsnodeid) || continue

    echo "Listing FRIENDS from $player"
    ls ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/
    echo
    sleep 1
    for g1 in $(ls ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/); do
        echo "$g1 est le player..."
        cat ~/.zen/game/players/$player/ipfs/.$ipfsnodeid/FRIENDS/$g1/player 2>/dev/null || echo "???"
    done

done

# TODO USE WEB INTERFACE
