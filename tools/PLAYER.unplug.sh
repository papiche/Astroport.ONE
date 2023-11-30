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


    ## TRANSERT PLAYER WALLET TO my_swarm G1PUB (IPFSNODEID/MACHINE RELATED KEY)
    SWARMG1PUB=$(cat ~/.zen/game/myswarm_secret.dunikey | grep "pub:" | cut -d ' ' -f 2)
    [[ ! -z ${SWARMG1PUB} ]] \
    && ALL="ALL" \
    && [[ $ONE == "ONE" ]] && ALL=1 \
    && ./PAY4SURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${ALL}" "${SWARMG1PUB}" "ZEN:${ALL}"

## REMOVING PLAYER from ASTROPORT
    ipfs key rm ${PLAYER}; ipfs key rm ${PLAYER}_feed; ipfs key rm ${G1PUB};
    for vk in $(ls -d ~/.zen/game/players/${PLAYER}/voeux/*/* | rev | cut -d / -f 1 | rev); do
        ipfs key rm ${vk}
    done

    echo "PLAYER IPNS KEYS UNPLUGED"
    echo "rm -Rf ~/.zen/game/players/${PLAYER}"
    rm -Rf ~/.zen/game/players/${PLAYER}

echo "CLEANING SESSION CACHE"
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
