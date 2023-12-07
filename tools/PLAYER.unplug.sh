#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"
################################################################################
## UNPLUG A PLAYER FROM ASTROPORT STATION
############################################
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

INDEX="$1"
[[ ! -s ${INDEX} ]] && echo "INDEX ${INDEX} NOT FOUND - EXIT -" && exit 1

PLAYER="$2"
[[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] && echo "PLAYER ${PLAYER} NOT FOUND - EXIT -" && exit 1

ONE="$3"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

## PLAYER UMAP ?
    ## GET "GPS" TIDDLER
    tiddlywiki --load ${INDEX} \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
    TWMAPNS=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].umap)
    LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
    LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
    echo "LAT=${LAT}; LON=${LON}; UMAPNS=${TWMAPNS}"
    rm ~/.zen/tmp/${MOATS}/GPS.json

    ## COULD TRANSERT TO my_swarm G1PUB (IPFSNODEID/MACHINE RELATED KEY)
    #~ SWARMG1PUB=$(cat ~/.zen/game/myswarm_secret.dunikey | grep "pub:" | cut -d ' ' -f 2)
    ########## SEND COINS TO SECTORG1PUB - ẐEN VIRTUAL BANK - EVERY 800 METERS - ;)
    LAT=$(makecoord $LAT)
    LON=$(makecoord $LON)
    ##############################################################
    # UMAPG1PUB=$(${MY_PATH}/keygen -t duniter "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    ##############################################################
    SECLAT="${LAT::-1}"
    SECLON="${LON::-1}"
    SECTOR="_${SECLAT}_${SECLON}"
    ##############################################################
    SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    ##############################################################

        [[ ! ${SECTORG1PUB} ]] && echo "ERROR generating UMAP WALLET ${UPLANETNAME}${LAT}/${UPLANETNAME}${LON}" && exit 1
        COINS=$($MY_PATH/../tools/COINScheck.sh ${SECTORG1PUB} | tail -n 1)
        echo "TRANSFERING TO UMAP (${COINS} G1) WALLET : ${SECTORG1PUB}"

    [[ ! -z ${SECTORG1PUB} ]] \
    && ALL="ALL" \
    && [[ $ONE == "ONE" ]] && ALL=1 \
    && echo "> PAY4SURE ZEN:${ALL} WALLET MOVE" \
    && ./PAY4SURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${ALL}" "${SECTORG1PUB}" "ZEN:${ALL}"

## REMOVING PLAYER from ASTROPORT
    ipfs key rm ${PLAYER}; ipfs key rm ${PLAYER}_feed; ipfs key rm ${G1PUB};
    for vk in $(ls -d ~/.zen/game/players/${PLAYER}/voeux/*/* 2>/dev/null | rev | cut -d / -f 1 | rev); do
        echo "removing wish ${vk}"
        ipfs key rm ${vk}
    done

    echo "PLAYER IPNS KEYS UNPLUGED"
    echo "rm -Rf ~/.zen/game/players/${PLAYER}"
    rm -Rf ~/.zen/game/players/${PLAYER}

echo "CLEANING SESSION CACHE"
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
