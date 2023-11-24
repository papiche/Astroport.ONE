#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# ON LINE echo script! LAST LINE export VARIABLE values
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"
### USE 12345 MAP
## EXPLORE SWARM BOOSTRAP REPLICATED TW CACHE

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

EMAIL="$1"

if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then

    INDEX=$(ls $HOME/.zen/game/players/${EMAIL}/ipfs/moa/index.html 2>/dev/null) ## LOCAL
    [[ ! $INDEX ]] && INDEX=$(ls $HOME/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/index.html 2>/dev/null) ## CACHE
    [[ ! $INDEX ]] && INDEX=$(ls $HOME/.zen/tmp/swarm/*/TW/${EMAIL}/index.html 2>/dev/null) ## SWARM
    [[ ! $INDEX ]] && exit 1
    ## TODO ? SEARCH WITH DNSLINK
    echo "export TW=${INDEX}"

    # SWARM CACHE index.html contains
    # <meta http-equiv="refresh" content="0; url='/ipns/$EXTERNAL'" />
    EXTERNAL=$(grep -o "url='/[^']*'" ${INDEX} | sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}')

    if [[ ! ${EXTERNAL} ]]; then
        ## EXTRACT DATA FROM TW
        mkdir -p ~/.zen/tmp/${MOATS}
        rm -f ~/.zen/tmp/${MOATS}/Astroport.json

        tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'

        ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)
        ASTROG1=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].g1pub)

        ## GET ASTRONAUTENS - field was missing in TW model Astroport Tiddler -
        ASTRONAUTENS=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astronautens)
        [[ ${ASTRONAUTENS} == "null" || ${ASTRONAUTENS} == "" ]] && ASTRONAUTENS="/ipns/"$(ipfs key list -l | grep -w ${ASTROG1} | cut -d ' ' -f1)
        [[ ${ASTRONAUTENS} == "/ipns/" ]] && ASTRONAUTENS=""
    else
        ASTRONAUTENS="/ipns/${EXTERNAL}"
    fi

    rm -Rf ~/.zen/tmp/${MOATS}
    # cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r

else

    echo "export ASTROTW='' # ${EMAIL} NOT FOUND"
    exit 0

fi


echo "export ASTROPORT=$ASTROPORT ASTROTW=$ASTRONAUTENS ASTROG1=$ASTROG1 ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS"
exit 0
