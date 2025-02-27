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

EMAIL="$1"
MOATS="$2"
[[ -z $MOATS ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

if [[ "${EMAIL}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then

    INDEX=$(ls ${HOME}/.zen/game/players/${EMAIL}/ipfs/moa/index.html 2>/dev/null) && source="LOCAL"
    [[ ! $INDEX ]] && INDEX=$(ls ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/index.html 2>/dev/null) && source="CACHE"
    [[ ! $INDEX ]] && INDEX=$(ls ${HOME}/.zen/tmp/swarm/*/TW/${EMAIL}/index.html 2>/dev/null) && source="SWARM"
    [[ ! $INDEX ]] && exit 1
    ## TODO ? SEARCH WITH DNSLINK
    echo "export source=${source} TW=${INDEX}"

    mkdir -p ~/.zen/tmp/${MOATS}
    # SWARM CACHE index.html contains
    # <meta http-equiv="refresh" content="0; url='/ipfs/$ICID'" />
    if [[ ${source} != "LOCAL" ]]; then
        echo "INDEX IS LINK"
        cat ${INDEX}
        ETWLINK=$(grep -o "url='/[^']*'" "${INDEX}" | sed "s|url='||;s|'||")
        ITYPE=$(echo "${ETWLINK}" | cut -d '/' -f 2)
        ICID=$(echo "${ETWLINK}" | rev | cut -d '/' -f 1 | rev)
        echo "ITYPE=$ITYPE ICID=$ICID"
        if [[ ! -s ${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html ]]; then
            [[ ${ICID} != "" ]] \
                && echo "refreshing flashmem ${ETWLINK}" \
                && mkdir -p ${HOME}/.zen/tmp/flashmem/tw/${ICID} \
                && ipfs --timeout=30s cat --progress=false ${ETWLINK} \
                        > ${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html

            [[ -s ${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html ]] \
                && INDEX="${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html" \
                || { echo "export ASTROTW=''"; exit 0; }
        else
            INDEX="${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html"
        fi

    else
        echo "INDEX IS LOCAL PLAYER TW"
    fi

    rm -f ~/.zen/tmp/${MOATS}/Astroport.json

    ## EXTRACT DATA FROM TW
    tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'

    ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].astroport)
    ASTROG1=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].g1pub)
    TWCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].chain)

    tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} --render '.' 'lightbeams.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key'
    FEEDNS="/ipns/"$(cat ~/.zen/tmp/${MOATS}/lightbeams.json 2>/dev/null | jq -r .[].text)

    tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'
    LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json 2>/dev/null | jq -r .[].lat)
    LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json 2>/dev/null | jq -r .[].lon)

    tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} --render '.' 'email.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${EMAIL}"
    HEX=$(cat ~/.zen/tmp/${MOATS}/email.json 2>/dev/null | jq -r .[].hex)

    ## GET ASTRONAUTENS - field was missing in TW model Astroport Tiddler -
    ASTRONAUTENS=$(cat ~/.zen/tmp/${MOATS}/Astroport.json 2>/dev/null | jq -r .[].astronautens)

    [[ ${source} == "LOCAL" && ( ${ASTRONAUTENS} == "null" || ${ASTRONAUTENS} == "" ) ]] \
        && ASTRONAUTENS="/ipns/"$(ipfs key list -l | grep -w ${ASTROG1} | cut -d ' ' -f1)

    [[ ${ASTRONAUTENS} == "/ipns/" ]] && ASTRONAUTENS="/ipfs/${TWCHAIN}"

    # cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r
    rm -Rf ~/.zen/tmp/${MOATS}

else

    echo "export ASTROTW='' # BAD ${EMAIL} FORMAT"
    exit 0

fi

#~ [[ $XDG_SESSION_TYPE == 'x11' && ${ASTRONAUTENS} != "" && ${ASTRONAUTENS} != "/ipfs/" && ${ASTRONAUTENS} != "/ipns/" ]] \
    #~ && xdg-open http://127.0.0.1:8080${ASTRONAUTENS}

### RUN THIS $(SCRIPT) TO INITIALIZE PLAYER ENV
echo "export ASTROPORT=$ASTROPORT ASTROTW=$ASTRONAUTENS LAT=$LAT LON=$LON ASTROG1=$ASTROG1 ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS TW=$INDEX HEX=$HEX source=$source"
exit 0
