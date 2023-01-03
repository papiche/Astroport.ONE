#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

EMAIL="$1"

if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then


    INDEX=$(ls $HOME/.zen/tmp/game/players/${EMAIL}/ipfs/moa/index.html 2>/dev/null)
    [[ ! $INDEX ]] && INDEX=$(ls $HOME/.zen/tmp/$IPFSNODEID/${EMAIL}/index.html 2>/dev/null)
    [[ ! $INDEX ]] && INDEX=$(ls $HOME/.zen/tmp/swarm/*/${EMAIL}/index.html 2>/dev/null)
    [[ ! $INDEX ]] && exit 1
    ## TODO ? SEARCH WITH DNSLINK

    ## EXTRACT DATA FROM TW
    mkdir -p ~/.zen/tmp/${MOATS}
    rm -f ~/.zen/tmp/${MOATS}/Astroport.json
    tiddlywiki --load ~/.zen/tmp/${MOATS}/TW/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
    ASTRONAUTENS=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)
    ASTROG1=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].g1pub)
    rm -Rf ~/.zen/tmp/${MOATS}

else

    echo "NO PLAYER WITH ${EMAIL} FOUND"

fi


echo "export ASTROTW=$ASTRONAUTENS ASTROG1=$G1PUB ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS"

exit 0
