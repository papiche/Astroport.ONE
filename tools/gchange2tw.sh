#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

####################################
#### HERE WE SCAN G1PUB GCHANGE ENV ####
# PART OF TW SYNCHRONIZATION #
####################################
G1PUB="$1"

## CHECK FOR KEY AVAILABLE
g1pubpath=$(grep $G1PUB ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)
[[ !$PLAYER ]] && echo "NO Astronaut Key Found. Please use 12345.sh to activate your ID on this gateway." && exit 1
ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)

## Getting Gchange  liking_me list
~/.zen/Astroport.ONE/tools/timeout.sh -t 20 ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" stars | jq -r '.likes[].issuer' | uniq > ~/.zen/tmp/liking_me


