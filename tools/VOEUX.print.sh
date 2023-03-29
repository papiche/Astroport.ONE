#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

PLAYER=$1

[[ $PLAYER == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ $PLAYER == "" ]] && echo "PLAYER manquant" && exit 1
PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "G1PUB manquant" && exit 1
ASTRONAUTENS=$(ipfs key list -l | grep -w "${G1PUB}" | cut -d ' ' -f 1)
[[ $ASTRONAUTENS == "" ]] && echo "ASTRONAUTE manquant" && exit 1

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
###############################
## EXTRACT G1Voeu from PLAYER TW
echo "Exporting $PLAYER TW [tag[G1Voeu]]"
rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json
tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu --render '.' "${PLAYER}.g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'

[[ ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json ]] && echo "AUCUN G1VOEU - EXIT -" && exit 1

cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt
echo "VOEUX : ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt "$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt | wc -l)

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"


for v in $(cat ~/.zen/game/players/$PLAYER/voeux/*/*/.title); do
    g1pub=$(grep -r $v ~/.zen/game/players/$PLAYER/voeux/ 2>/dev/null | rev | cut -d '/' -f 2 | rev )
    echo "$v : $g1pub"
    echo '------------------------------------------------------------------'
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
        TITLE=$(echo $voeu | cut -d ':' -f1) ## Get Voeu title

        VOEUXNS=$(ipfs key list -l | grep $voeu | cut -d ' ' -f1)

        choices=("TW" "G1")
        PS3='Imprimer le QR du TiddlyWiki TW ou celui de son G1 portefeuille ?'
        select typ in "${choices[@]}"; do

            case $typ in
            "TW")
                echo "Changer de Gateway $myIPFS ?"
                read GW && [[ ! $GW ]] && GW="$myIPFS"
                qrencode -s 12 -o "$HOME/.zen/game/world/$TITLE/$voeu/QR.WISHLINK.png" "$GW/ipns/$VOEUXNS"
                convert $HOME/.zen/game/world/$TITLE/$voeu/QR.WISHLINK.png -resize 600 ~/.zen/tmp/START.png
                echo " QR code $TITLE  : $GW/ipns/$VOEUXNS"
                break
            ;;
            "G1")
                qrencode -s 12 -o "$HOME/.zen/game/world/$TITLE/$voeu/G1PUB.png" "$voeu"
                convert $HOME/.zen/game/world/$TITLE/$voeu/G1PUB.png -resize 600 ~/.zen/tmp/START.png
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
