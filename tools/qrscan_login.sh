#!/bin/bash
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

qrscan=$(ps auxf --sort=+utime | grep -w qrscan_login.sh | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $qrscan ]] && echo "qrscan already running" && exit 1

# Check if Astroport Station already has a "captain"
source ~/.zen/ipfs.sync; echo "Le capitaine de cet Astroport est actuellement $CAPTAIN"
echo "Astronaute $PLAYER ($PSEUDO) "

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

cat /dev/ttyACM0 | while read line; do
        echo $line;
        QRCODE=$line
        g1pubpath=$(grep $QRCODE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
        PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

        ## FORCE LOCAL USE ONLY. Remove to open 1234 API
        [[ ! -d ~/.zen/game/players/$PLAYER || $PLAYER == "" ]] && echo "AUCUN PLAYER !!" && exit 1
        espeak "Astronaute $PSEUDO. Welcome!"

        ## LOGIN
        rm -f ~/.zen/game/players/.current
        ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

        # Check who is .current PLAYER
        PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
        PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
        G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
        IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )
        PLAYERNS=$(cat ~/.zen/game/players/.current/.playerns 2>/dev/null) || ( echo "noplayerns" && exit 1 )
        MOANS=$(cat ~/.zen/game/players/.current/.moans 2>/dev/null) || ( echo "noplayermoans" && exit 1 )
        QOOPNS=$(cat ~/.zen/game/players/.current/.qoopns 2>/dev/null) || ( echo "noplayerqoopns" && exit 1 )

        espeak "Report your best dreams and plans to the astroport captain. Love."

        break
done

