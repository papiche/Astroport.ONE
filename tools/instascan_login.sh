#!/bin/bash
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

# Check who is .current PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )
PLAYERNS=$(cat ~/.zen/game/players/.current/.playerns 2>/dev/null) || ( echo "noplayerns" && exit 1 )
MOANS=$(cat ~/.zen/game/players/.current/.moans 2>/dev/null) || ( echo "noplayermoans" && exit 1 )
QOOPNS=$(cat ~/.zen/game/players/.current/.qoopns 2>/dev/null) || ( echo "noplayerqoopns" && exit 1 )

# Check if Astroport Station already has a "captain"
source ~/.zen/ipfs.sync; echo "Le capitaine de cet Astroport est actuellement $CAPTAIN"
echo "Astronaute $PLAYER ($PSEUDO) "

xdg-open "file:///home/fred/workspace/Astroport.ONE/templates/instascan.html"

while true; do

    REPONSE=$(echo -e 'HTTP/1.1 200 OK\r\n' | nc -l -p 1234 -q 1 | grep '^GET' | cut -d' ' -f2 | cut -d'=' -f 2)

    ## PLAYER G1PUB
    g1pubpath=$(grep $REPONSE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
    PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

    ##
    [[ $(echo $REPONSE | grep '/ipns/') ]] &&

    [[ $PLAYER ]] &&\
       echo "$PLAYER" && \
       ns=$(ipfs key list -l | grep -w qo-op_$PLAYER | cut -d ' ' -f 1) &&\

       xdg-open "http://127.0.0.1:8080/ipns/$ns" || \
       echo "? "$REPONSE

done


moa=$(ipfs key list -l | grep -w moa_$PLAYER | cut -d ' ' -f 1)

qoop=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)

