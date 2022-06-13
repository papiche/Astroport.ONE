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

xdg-open "file://$HOME/.zen/Astroport.ONE/templates/instascan.html" 2>/dev/null

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

while true; do

    URL=$(echo -e 'HTTP/1.1 200 OK\r\n' | nc -l -p 1234 -q 1 | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    echo "=================================================="
    echo "GET RECEPTION : $URL"
    arr=(${URL//[=&]/ })
    echo "PARAM : ${arr[0]} = ${arr[1]} & ${arr[2]} = ${arr[3]} & ${arr[4]} = ${arr[5]}"

    if [[ ${arr[0]} == "qrcode" ]]; then
        ## Astroport.ONE local use QRCODE Contains PLAYER G1PUB
        QRCODE=$(echo $URL | cut -d ' ' -f2 | cut -d '=' -f 2 | cut -d '&' -f 1)   && echo "Instascan.html QR : $QRCODE"
        g1pubpath=$(grep $QRCODE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
        PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

             # Get IPFS ID
            ASTROID=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py $QRCODE)
            echo "ASTROID = $ASTROID"
            # Rechercher dans mon essaim Gchange

        ## Open "qo-op_PLAYER" TW
        if [[ $PLAYER ]]; then
           echo "$PLAYER"
           qoop=$(ipfs key list -l | grep -w qo-op_$PLAYER | cut -d ' ' -f 1)
           moa=$(ipfs key list -l | grep -w moa_$PLAYER | cut -d ' ' -f 1)
           perso=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
           xdg-open "http://127.0.0.1:8080/ipns/$qoop"

        else
           echo "Astronaute INCONNU ? $QRCODE" # && continue
        fi

        [[ ${arr[2]} == "" ]] && continue
    fi

    ## Demande de copie d'une URL reçue.
    if [[ ${arr[0]} == "qrcode" &&  ${arr[2]} == "url" ]]; then
        wsource="${arr[3]}"
         [[ ${arr[4]} == "type" ]] && wtype="${arr[5]}" || wtype="Youtube"

        ## LANCEMENT COPIE
        ~/.zen/astrXbian/ajouter_video.sh "$(urldecode $wsource)" "$wtype" "$QRCODE" &

        if [[ $PLAYER == $CAPTAIN  ]]; then
            echo "running as captain"
        else
            # running for another player than captain.
            # Captain copy for all PLAYER (Gchange key conversion TODO)
            echo "$QRCODE $wsource"

        fi
    fi

    ## ENVOYER MESSAGE GCHANGE POUR QRCODE


done



