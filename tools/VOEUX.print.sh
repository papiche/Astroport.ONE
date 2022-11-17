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
ASTRONAUTENS=$(ipfs key list -l | grep -w "${G1PUB}" | cut -d ' ' -f 1)
[[ $ASTRONAUTENS == "" ]] && echo "ASTRONAUTE manquant" && exit 1


for v in $(cat ~/.zen/game/players/*/voeux/*/.title); do
    g1pub=$(grep -r $v ~/.zen/game/players/*/voeux/ 2>/dev/null | rev | cut -d '/' -f 2 | rev )
#    echo "$v : $g1pub"
#    echo '------------------------------------------------------------------'
    vlist=($v:$g1pub ${vlist[@]})
done

# echo "${vlist[@]}"

PS3='Choisissez le voeux ___ '
voeux=($(ls ~/.zen/game/players/$PLAYER/voeux 2>/dev/null) "QUITTER")

select voeu in "${vlist[@]}"; do
    case $voeu in
    "QUITTER")
        exit 0
    ;;

    *) echo "IMPRESSION $voeu"
        voeu=$(echo $voeu | cut -d ':' -f2) ## Get G1PUB part
        TITLE=$(cat ~/.zen/game/world/$voeu/.pepper) ## Get Voeu title (pepper) = simple GUI form + Name collision => Voeu fusion

myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="astroport.localhost"

        VOEUXNS=$(ipfs key list -l | grep $voeu | cut -d ' ' -f1)

        choices=("TW" "G1")
        PS3='Imprimer le QR du TiddlyWiki TW ou celui de son G1 portefeuille ?'
        select typ in "${choices[@]}"; do

            case $typ in
            "TW")
                echo "Changer de Gateway http://$myIP:8080 ?"
                read GW && [[ ! $GW ]] && GW="http://$myIP:8080"
                qrencode -s 12 -o "$HOME/.zen/game/world/$voeu/QR.WISHLINK.png" "http://$myIP:8080/ipns/$VOEUXNS"
                convert $HOME/.zen/game/world/$voeu/QR.WISHLINK.png -resize 600 ~/.zen/tmp/START.png
                echo " QR code $TITLE  : http://$myIP:8080/ipns/$VOEUXNS"
                break
            ;;
            "G1")
                qrencode -s 12 -o "$HOME/.zen/game/world/$voeu/G1PUB.png" "$voeu"
                convert $HOME/.zen/game/world/$voeu/G1PUB.png -resize 600 ~/.zen/tmp/START.png
                break
            ;;
            esac
        done

        convert -gravity northwest -pointsize 40 -fill black -draw "text 50,2 \"$TITLE ($typ)\"" ~/.zen/tmp/START.png ~/.zen/tmp/g1voeu1.png
        convert -gravity southeast -pointsize 40 -fill black -draw "text 50,2 \"($typ) $TITLE\"" ~/.zen/tmp/g1voeu1.png ~/.zen/tmp/g1voeu.png


        LP=$(ls /dev/usb/lp* | head -n1)
        [[ ! $LP ]] && echo "NO PRINTER FOUND - Brother QL700 validated" && continue

        echo "IMPRESSION LIEN TW VOEU"
        brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/g1voeu.png > ~/.zen/tmp/toprint.bin 2>/dev/null
        sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP

        ;;
    esac
done
