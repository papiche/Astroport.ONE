#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#################################################### GetGCAttributesFromG1PUB.sh
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

[[ ${1} == "-h" || ${1} == "--help" ]] && echo "#################################################
# GIVEN A PUBKEY -
# This program scan for presence in GChange & Cesium Elastic Search Databases
# So it detect attributes attached to actual key $G1PUB
# .g1history.json .cesium.json ( .gchange.json .cplus.json )
#################################################"
G1PUB="$1"
MOATS="$2"

QRNS=$(${MY_PATH}/g1_to_ipfs.py ${G1PUB})
[[ ! ${QRNS} ]] && echo "PROVIDED KEY IS NOT CONVERTIBLE." && exit 1

[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

COINS=$(cat ~/.zen/tmp/coucou/${G1PUB}.COINS 2>/dev/null)
ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)

echo "===== ${G1PUB} ===== ${COINS} G1 / ${ZEN} ZEN ($ME)"

## GET G1 WALLET HISTORY
if [[ ${COINS} != "null" && $(echo "$COINS > 0" | bc -l) -eq 1 ]]; then

    [[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json ]] \
    && ${MY_PATH}/timeout.sh -t 5 $MY_PATH/jaklis/jaklis.py history -n 100 -p ${G1PUB} -j > ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json

    if [[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json ]]; then
        GVASERVER=$(${MY_PATH}/../tools/duniter_getnode.sh | tail -n 1)
        ## Changing GVA SERVER in tools/jaklis/.env
        [[ $(echo ${GVASERVER} | grep "/gva" ) ]] \
            && cat ${MY_PATH}/../tools/jaklis/.env.template > ${MY_PATH}/../tools/jaklis/.env \
            && echo "NODE=${GVASERVER}" >> ${MY_PATH}/../tools/jaklis/.env \
            && echo "OK. NEW GVA NODE : ${GVASERVER}" \
            || echo "ERROR. BAD GVA NODE : ${GVASERVER}"
    else
        echo "++ HISTORY OK"
    fi
fi

## SCAN GCHANGE +
if [[ ! -s ~/.zen/tmp/coucou/${G1PUB}.gchange.json ]]; then
    ${MY_PATH}/timeout.sh -t 5 curl -s ${myDATA}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json
    GFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json 2>/dev/null | jq -r '.found' 2>/dev/null)

    if [[ ! $GFOUND || $GFOUND == "false" ]]; then
        echo "-- NO GCHANGE "
    else
        cp -f ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json ~/.zen/tmp/coucou/
        echo "++ FOUND IN GCHANGE+ : $GFOUND"
        [[ $COINS == "null" ]] && PALPE=10 ## 10 ZEN REWARD
    fi
else
    echo "GCHANGE + : OK ~/.zen/tmp/coucou/${G1PUB}.gchange.json"
fi
## EXTRACT GCHANGE AVATAR
if [[ -s ~/.zen/tmp/coucou/${G1PUB}.gchange.json ]]; then
    [[ ! -s "$HOME/.zen/tmp/coucou/${G1PUB}.gchange.avatar.png" ]] \
        && cat ~/.zen/tmp/coucou/${G1PUB}.gchange.json \
            | jq -r '._source.avatar._content' 2>/dev/null \
            | base64 -d > "$HOME/.zen/tmp/coucou/${G1PUB}.gchange.avatar.png" 2>/dev/null
    [[ ! $(file -b "$HOME/.zen/tmp/coucou/${G1PUB}.gchange.avatar.png" | grep PNG) ]] \
        && rm "$HOME/.zen/tmp/coucou/${G1PUB}.gchange.avatar.png"
fi
## SCAN CESIUM +
if [[ ! -s ~/.zen/tmp/coucou/${G1PUB}.cesium.json ]]; then

    ${MY_PATH}/timeout.sh -t 5 curl -s ${myCESIUM}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json 2>/dev/null
    GCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json 2>/dev/null | jq -r '.found' 2>/dev/null)

    if [[ ! $GCFOUND || $GCFOUND == "false" ]]; then
        echo "-- NO CESIUM"
    else
        cp -f ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json ~/.zen/tmp/coucou/
        echo "++ FOUND IN CESIUM+ : $GCFOUND"
        [[ $COINS == "null" ]] && PALPE=50 ## REWARD
    fi
else
    echo "CESIUM + : OK ~/.zen/tmp/coucou/${G1PUB}.cesium.json"
fi

## EXTRACT CESIUM AVATAR
if [[ -s ~/.zen/tmp/coucou/${G1PUB}.cesium.json ]]; then
    [[ ! -s "$HOME/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png" ]] \
        && cat ~/.zen/tmp/coucou/${G1PUB}.cesium.json \
            | jq -r '._source.avatar._content' 2>/dev/null \
            | base64 -d > "$HOME/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png" 2>/dev/null
    [[ ! $(file -b "$HOME/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png" | grep PNG) ]] && rm "$HOME/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png"
fi

## CHECK IF GCHANGE IS LINKED TO "A DECLARED CESIUM"
if [[ ! -s ~/.zen/tmp/coucou/${G1PUB}.cplus.json ]]; then
    CPLUS=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json 2>/dev/null | jq -r '._source.pubkey' 2>/dev/null)
    echo "CPLUS=$CPLUS"
    ## SCAN GPUB CESIUM +

    ##### DO WE HAVE A DIFFERENT KEY LINKED TO GCHANGE ??
    if [[ $CPLUS != "" && $CPLUS != 'null' && $CPLUS != $G1PUB ]]; then

        echo "SCAN GPLUS CESIUM + ACCOUNT"
        ${MY_PATH}/timeout.sh -t 5 curl -s ${myCESIUM}/user/profile/${CPLUS} > ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json 2>/dev/null

        CCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json | jq -r '.found' 2>/dev/null)

        if [[ $CCFOUND == "false" ]]; then
            echo "AUCUN CCPLUS : NO MEMBER LINK"
        else
            cp -f ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json ~/.zen/tmp/coucou/
            CPLUSCOIN=$(${MY_PATH}/COINScheck.sh ${CPLUS} | tail -n 1)
            echo "${G1PUB} IS LINKED TO MEMBER ${CPLUS} POSSESSING  ${CPLUSCOIN} G1"
        fi

    fi
else
    echo "MEMBER + : OK ~/.zen/tmp/coucou/${G1PUB}.cplus.json "
fi
## EXTRACT CPLUS AVATAR
if [[ -s ~/.zen/tmp/coucou/${G1PUB}.cplus.json ]]; then
    [[ ! -s "$HOME/.zen/tmp/coucou/${G1PUB}.cplus.avatar.png" ]] \
        && cat ~/.zen/tmp/coucou/${G1PUB}.cplus.json \
            | jq -r '._source.avatar._content' 2>/dev/null \
            | base64 -d > "$HOME/.zen/tmp/coucou/${G1PUB}.cplus.avatar.png" 2>/dev/null
    [[ ! $(file -b "$HOME/.zen/tmp/coucou/${G1PUB}.cplus.avatar.png" | grep PNG) ]] && rm "$HOME/.zen/tmp/coucou/${G1PUB}.cplus.avatar.png"
fi

rm -Rf ~/.zen/tmp/${MOATS}/

exit 0
