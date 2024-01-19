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

COINS=$(cat ~/.zen/tmp/coucou/${G1PUB}.COINS)
ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)

echo "===== ${G1PUB} ===== ${COINS} G1 / ${ZEN} ZEN"

## GET G1 WALLET HISTORY
if [[ ${COINS} != "null" && $(echo "$COINS > 0" | bc -l) -eq 1 ]]; then

    [[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json ]] \
    && ${MY_PATH}/timeout.sh -t 20 $MY_PATH/jaklis/jaklis.py history -n 100 -p ${G1PUB} -j > ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json
    echo "++ HISTORY OK" >> ~/.zen/tmp/${MOATS}/response

fi

## SCAN GCHANGE +
${MY_PATH}/timeout.sh -t 20 curl -s ${myDATA}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json
GFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json | jq -r '.found')

if [[ $GFOUND == "false" ]]; then
    echo "-- NO GCHANGE " >> ~/.zen/tmp/${MOATS}/response
else
    echo "++ FOUND IN GCHANGE+ : $GFOUND" >> ~/.zen/tmp/${MOATS}/response
    [[ $COINS == "null" ]] && PALPE=10 ## 10 ZEN REWARD
fi

## SCAN CESIUM +
${MY_PATH}/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json 2>/dev/null
GCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json | jq -r '.found')

if [[ $GCFOUND == "false" ]]; then
    echo "-- NO CESIUM" >> ~/.zen/tmp/${MOATS}/response
else
    echo "++ FOUND IN CESIUM+ : $GCFOUND" >> ~/.zen/tmp/${MOATS}/response
    [[ $COINS == "null" ]] && PALPE=50 ## REWARD
fi

## CHECK IF GCHANGE IS LINKED TO "A DECLARED CESIUM"
CPLUS=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json | jq -r '._source.pubkey' 2>/dev/null)
echo "CPLUS=$CPLUS" >> ~/.zen/tmp/${MOATS}/response
## SCAN GPUB CESIUM +

##### DO WE HAVE A DIFFERENT KEY LINKED TO GCHANGE ??
if [[ $CPLUS != "" && $CPLUS != 'null' && $CPLUS != $G1PUB ]]; then

    echo "SCAN GPLUS CESIUM + ACCOUNT" >> ~/.zen/tmp/${MOATS}/response
    ${MY_PATH}/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${CPLUS} > ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json 2>/dev/null

    CCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json | jq -r '.found')

    if [[ $CCFOUND == "false" ]]; then
        echo "AUCUN CCPLUS : NO MEMBER LINK" >> ~/.zen/tmp/${MOATS}/response
    else
        CPLUSCOIN=$(${MY_PATH}/COINScheck.sh ${CPLUS} | tail -n 1)
        echo "${G1PUB} IS LINKED TO MEMBER ${CPLUS} POSSESSING  ${CPLUSCOIN} G1" >> ~/.zen/tmp/${MOATS}/response
    fi

fi

cat  ~/.zen/tmp/${MOATS}/response

## REFRESH ~/.zen/tmp/coucou/
[[ ! -s ~/.zen/tmp/coucou/${G1PUB}.g1history.json && -s ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json ]] \
    && cp -f ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json ~/.zen/tmp/coucou/
[[ ! -s ~/.zen/tmp/coucou/${G1PUB}.gchange.json && -s ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json ]] \
    && cp -f ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json ~/.zen/tmp/coucou/
[[ ! -s ~/.zen/tmp/coucou/${G1PUB}.cesium.json && -s ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json ]] \
    && cp -f ~/.zen/tmp/${MOATS}/${G1PUB}.cesium.json ~/.zen/tmp/coucou/
[[ ! -s ~/.zen/tmp/coucou/${G1PUB}.cplus.json && -s ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json ]] \
    && cp -f ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json ~/.zen/tmp/coucou/

rm -Rf ~/.zen/tmp/${MOATS}/

exit 0
