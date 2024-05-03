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

if [[ "${EMAIL}" =~ ^[a-zA-Z0-9.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then

    INDEX=$(ls $HOME/.zen/game/players/${EMAIL}/ipfs/moa/index.html 2>/dev/null) && source="LOCAL"
    [[ ! $INDEX ]] && INDEX=$(ls $HOME/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/index.html 2>/dev/null) && source="CACHE"
    [[ ! $INDEX ]] && INDEX=$(ls $HOME/.zen/tmp/swarm/*/TW/${EMAIL}/index.html 2>/dev/null) && source="SWARM"
    [[ ! $INDEX ]] && exit 1
    ## TODO ? SEARCH WITH DNSLINK
    echo "export TW=${INDEX} source=${source}"

    mkdir -p ~/.zen/tmp/${MOATS}
    # SWARM CACHE index.html contains
    # <meta http-equiv="refresh" content="0; url='/ipfs/$EXTERNAL'" />
    if [[ ${source} != "LOCAL" ]]; then
        EXTERNAL=$(grep -o "url='/[^']*'" ${INDEX} | sed "s/url='\(.*\)'/\1/" | awk -F"/" '{print $3}')
        [[ ! -s $HOME/.zen/tmp/flashmem/tw/${EXTERNAL}/index.html ]] \
            && mkdir $HOME/.zen/tmp/flashmem/tw/${EXTERNAL} \
            && ipfs cat /ipfs/${EXTERNAL} > $HOME/.zen/tmp/flashmem/tw/${EXTERNAL}/index.html
        INDEX="$HOME/.zen/tmp/flashmem/tw/${EXTERNAL}/index.html"
    fi

    #~ if [[ ! ${EXTERNAL} ]]; then
    ## EXTRACT DATA FROM TW
    rm -f ~/.zen/tmp/${MOATS}/Astroport.json

    tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'

    ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].astroport)
    ASTROG1=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].g1pub)
    TWCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].chain)

    ## GET ASTRONAUTENS - field was missing in TW model Astroport Tiddler -
    ASTRONAUTENS=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].astronautens)
    [[ ${ASTRONAUTENS} == "null" || ${ASTRONAUTENS} == "" ]] && ASTRONAUTENS="/ipns/"$(ipfs key list -l | grep -w ${ASTROG1} | cut -d ' ' -f1)
    [[ ${ASTRONAUTENS} == "/ipns/" ]] && ASTRONAUTENS="/ipfs/${TWCHAIN}"
    #~ else
        #~ ASTRONAUTENS="/ipfs/${EXTERNAL}"
        #~ ASTROG1=$(${MY_PATH}/../tools/ipfs_to_g1.py ${EXTERNAL})
        #~ ASTROPORT="/ipns/$(echo $INDEX | rev | cut -d / -f 4 | rev)"
    #~ fi

    rm -Rf ~/.zen/tmp/${MOATS}
    # cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r

else

    echo "export ASTROTW='' # ${EMAIL} NOT FOUND"
    exit 0

fi

### RUN THIS $(SCRIPT) TO INITIALIZE PLAYER ENV
echo "export ASTROPORT=$ASTROPORT ASTROTW=$ASTRONAUTENS ASTROG1=$ASTROG1 ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS TW=$INDEX source=$source"
exit 0
