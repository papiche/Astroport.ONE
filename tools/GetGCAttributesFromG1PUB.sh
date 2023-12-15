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

G1PUB="$1"
MOATS="$2"
echo "#################################################"
echo "WARNING NOT TESTED. PASS A G1PUBKEY AS PARAMETER."
echo "#################################################
# GIVEN A PUBKEY -
# This program scan for presence in GChange & Cesium Elastic Search Databases
# So it detect attributes attached to actual key $G1PUB
#################################################"

QRNS=$(${MY_PATH}/g1_to_ipfs.py ${G1PUB})
[[ ! ${QRNS} ]] && echo "PROVIDED KEY IS NOT CONVERTIBLE." && exit 1

[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

VISITORCOINS=$(${MY_PATH}/COINScheck.sh ${G1PUB} | tail -n 1)
ZEN=$(echo "($VISITORCOINS - 1) * 10" | bc | cut -d '.' -f 1)

## EMPTY WALLET ? PREPARE PALPE WELCOME
if [[ $VISITORCOINS == "null" ]]; then
    PALPE=1
    echo "PALPE=1"
else
    PALPE=0
fi

echo "VISITOR POSSESS ${VISITORCOINS} G1 / ${ZEN} ZEN"

## GET G1 WALLET HISTORY
if [[ ${VISITORCOINS} != "null" && ${VISITORCOINS} -gt 0 ]]; then

    [[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json ]] \
    && ${MY_PATH}/timeout.sh -t 20 $MY_PATH/jaklis/jaklis.py history -p ${G1PUB} -j > ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json

    HISTOLNK=$myIPFS/ipfs/$(ipfs add -q ~/.zen/tmp/${MOATS}/${G1PUB}.g1history.json)

    echo "<a href=${HISTOLNK}>HISTORY</a>" > ~/.zen/tmp/${MOATS}/response
    echo "<h1>Solde $VISITORCOINS Ǧ1</h1>" >> ~/.zen/tmp/${MOATS}/response

fi

## SCAN GCHANGE +
[[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json ]] \
&& ${MY_PATH}/timeout.sh -t 20 curl -s ${myDATA}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json &

GFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json | jq -r '.found')
echo "FOUND IN GCHANGE+ ? $GFOUND"

if [[ $GFOUND == "false" ]]; then
    echo "NO GCHANGE YET. REDIRECT" >> ~/.zen/tmp/${MOATS}/response
else
    [[ $VISITORCOINS == "null" ]] && PALPE=10 \
    && echo "~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json CHECK : PALPE=10"
fi

## SCAN CESIUM +
[[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.gplus.json ]] \
&& ${MY_PATH}/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${G1PUB} > ~/.zen/tmp/${MOATS}/${G1PUB}.gplus.json 2>/dev/null &

GCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gplus.json | jq -r '.found')
echo "FOUND IN CESIUM+ ? $GCFOUND"

if [[ $GCFOUND == "false" ]]; then
    echo "PAS DE COMPTE CESIUM POUR CETTE CLEF" >> ~/.zen/tmp/${MOATS}/response
else
    echo "~/.zen/tmp/${MOATS}/${G1PUB}.gplus.json CHECK : PALPE=50" >> ~/.zen/tmp/${MOATS}/response
fi

## CHECK IF GCHANGE IS LINKED TO "A DECLARED CESIUM"
CPLUS=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.gchange.json | jq -r '._source.pubkey' 2>/dev/null)
echo "CPLUS=$CPLUS" >> ~/.zen/tmp/${MOATS}/response
## SCAN GPUB CESIUM +

##### DO WE HAVE A DIFFERENT KEY LINKED TO GCHANGE ??
if [[ $CPLUS != "" && $CPLUS != 'null' && $CPLUS != $G1PUB ]]; then

    ## SCAN FOR CPLUS CESIUM + ACCOUNT
    [[ ! -s ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json ]] \
    && ${MY_PATH}/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${CPLUS} > ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json 2>/dev/null &

    CCFOUND=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}.cplus.json | jq -r '.found')

    if [[ $CCFOUND == "false" ]]; then
        echo "AUCUN CCPLUS : NO MEMBER LINK" >> ~/.zen/tmp/${MOATS}/response
    else
        CPLUSCOIN=$(${MY_PATH}/COINScheck.sh ${CPLUS} | tail -n 1)
        echo "${G1PUB} IS LINKED TO MEMBER ${CPLUS} POSSESSING  ${CPLUSCOIN} G1" >> ~/.zen/tmp/${MOATS}/response

    fi

fi

cat  ~/.zen/tmp/${MOATS}/response
