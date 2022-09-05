#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

[[ $PLAYER == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ $PLAYER == "" ]] && echo "PLAYER manquant" && exit 1
PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "G1PUB manquant" && exit 1
ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
[[ $ASTRONAUTENS == "" ]] && echo "ASTRONAUTE manquant" && exit 1


for v in $(cat ~/.zen/game/players/*/voeux/*/.title); do
    g1pub=$(grep -r $v ~/.zen/game/players/*/voeux/ $v 2>/dev/null | rev | cut -d '/' -f 2 | rev )
    echo "$v : $g1pub"
    echo '------------------------------------------------------------------'
done

PS3='Choisissez le voeux ___ '
voeux=($(ls ~/.zen/game/players/$PLAYER/voeux 2>/dev/null) "QUITTER")

select voeu in "${voeux[@]}"; do
    case $voeu in
    "QUITTER")
        exit 0
    ;;

    *) echo "IMPRESSION $voeu"
        myIP=$(hostname -I | awk '{print $1}' | head -n 1)
        VOEUXNS=$(ipfs key list -l | grep $voeu | cut -d ' ' -f1)
        qrencode -s 12 -o "$HOME/.zen/game/world/$voeu/QR.WISHLINK.png" "http://$myIP:8080/ipns/$VOEUXNS"
        convert $HOME/.zen/game/world/$voeu/QR.WISHLINK.png -resize 600 /tmp/QRWISHLINK.png
        TITLE=$(cat ~/.zen/game/world/$voeu/.pepper)
        convert -gravity northwest -pointsize 40 -fill black -draw "text 250,2 \"$TITLE\"" /tmp/QRWISHLINK.png /tmp/g1voeu.png
        echo " QR code $TITLE  : http://$myIP:8080/ipns/$VOEUXNS"

        LP=$(ls /dev/usb/lp* | head -n1)
        [[ ! $LP ]] && echo "NO PRINTER FOUND - Brother QL700 validated" && continue

        echo "IMPRESSION LIEN TW VOEU"
        brother_ql_create --model QL-700 --label-size 62 /tmp/g1voeu.png > /tmp/toprint.bin 2>/dev/null
        sudo brother_ql_print /tmp/toprint.bin $LP

        ;;
    esac
done
