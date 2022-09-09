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
    vlist=($v:$g1pub ${vlist[@]})
done

echo "${vlist[@]}"


PS3='Choisissez le TW à exporter ___ '
voeux=($(ls ~/.zen/game/players/$PLAYER/voeux 2>/dev/null) "QUITTER")

select voeu in "${vlist[@]}"; do
    case $voeu in
    "QUITTER")
        exit 0
    ;;

    *) echo "OK pour $voeu"
        voeu=$(echo $voeu | cut -d ':' -f2) ## Get G1PUB part
        myIP=$(hostname -I | awk '{print $1}' | head -n 1)
        VOEUNS=$(ipfs key list -l | grep -w $voeu | cut -d ' ' -f1)
        echo "/ipns/$VOEUNS"

        ipfs --timeout 12s cat /ipns/$VOEUNS > ~/.zen/tmp/index.html
        [[ ! -s ~/.zen/tmp/index.html ]] && echo "TIMEOUT ERROR" && break

        tiddlywiki --load ~/.zen/tmp/index.html --output ~/.zen/tmp --render '.' 'tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[ipfs]]' ## TUBE.copy.sh Tiddlers

        cat ~/.zen/tmp/tiddlers.json | jq -r

        ;;
    esac
done
