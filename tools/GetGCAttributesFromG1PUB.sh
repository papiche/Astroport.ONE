#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

[[ ${1} == "-h" || ${1} == "--help" ]] && echo "#################################################
# GIVEN A PUBKEY -
# This program scan for presence in GChange & Cesium Elastic Search Databases
# So it detect attributes attached to actual key $G1PUB
#################################################"
G1PUB="$1"
MOATS="$2"

QRNS=$(${MY_PATH}/g1_to_ipfs.py ${G1PUB})
[[ ! ${QRNS} ]] && echo "PROVIDED KEY IS NOT CONVERTIBLE." && exit 1

[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

COINS=$(cat ~/.zen/tmp/coucou/${G1PUB}.COINS 2>/dev/null)
ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)

echo "===== ${G1PUB} ===== ${COINS} G1 / ${ZEN} ZEN"

## GET G1 WALLET HISTORY
if [[ ${COINS} != "null" && $(echo "$COINS > 0" | bc -l) -eq 1 ]]; then

    [[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json ]] \
    && ${MY_PATH}/timeout.sh -t 20 $MY_PATH/jaklis/jaklis.py history -n 100 -p ${G1PUB} -j > ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json
    echo "++ HISTORY OK"

fi

## SCAN GCHANGE +
if [[ ! -s ~/.zen/tmp/coucou/${G1PUB}.gchange.json ]]; then
    ${MY_PATH}/timeout.sh -t 20 curl -s ${myDATA}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json
    GFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json 2>/dev/null | jq -r '.found')

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

## SCAN CESIUM +
if [[ ! -s ~/.zen/tmp/coucou/${G1PUB}.cesium.json ]]; then

    ${MY_PATH}/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json 2>/dev/null
    GCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json 2>/dev/null | jq -r '.found')

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

## CHECK IF GCHANGE IS LINKED TO "A DECLARED CESIUM"
if [[ ! -s ~/.zen/tmp/coucou/${G1PUB}.cplus.json ]]; then
    CPLUS=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json | jq -r '._source.pubkey' 2>/dev/null)
    echo "CPLUS=$CPLUS"
    ## SCAN GPUB CESIUM +

    ##### DO WE HAVE A DIFFERENT KEY LINKED TO GCHANGE ??
    if [[ $CPLUS != "" && $CPLUS != 'null' && $CPLUS != $G1PUB ]]; then

        echo "SCAN GPLUS CESIUM + ACCOUNT"
        ${MY_PATH}/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${CPLUS} > ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json 2>/dev/null

        CCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json | jq -r '.found')

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

rm -Rf ~/.zen/tmp/${MOATS}/

exit 0
