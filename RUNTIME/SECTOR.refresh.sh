#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
################################################################################
## SECTOR REFRESH
# SHARE & UPDATE IPNS TOGETHER
############################################
echo "## RUNNING SECTOR.refresh"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

## CALLED BY UPLANET.refresh.sh
LAT=$1
LON=$2
MOATS=$3
UMAP=$4
SECTORNODE=$5

[[ ! -d ~/.zen/tmp/${MOATS-undefined}/${UMAP-undefined} ]] && echo "MISSING UMAP CONTEXT" && exit 1

SLAT="${LAT::-1}"
SLON="${LON::-1}"
SECTOR="_${SLAT}_${SLON}"
echo "SECTOR ${SECTOR}"
[[ -s ~/.zen/tmp/${MOATS}/${UMAP}/SECTOR${SECTOR}.IPNS.html ]] && echo "ALREADY DONE" && exit 0

[[ "${SECTORNODE}" == "${IPFSNODEID}" ]] && echo ">> MANAGING SECTOR PUBLICATION" || exit 0

##############################################################
SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${SECTOR}" "${SECTOR}")
[[ ! ${SECTORG1PUB} ]] && echo "ERROR generating SECTOR WALLET" && exit 1
        COINS=$($MY_PATH/../tools/COINScheck.sh ${SECTORG1PUB} | tail -n 1)
        echo "SECTOR : ${SECTOR} (${COINS} G1) WALLET : ${SECTORG1PUB}"

${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SECTOR.priv "${SECTOR}" "${SECTOR}"
ipfs key rm ${SECTORG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
SECTORNS=$(ipfs key import ${SECTORG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SECTOR.priv)

echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${SECTORNS}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/SECTOR${SECTOR}.IPNS.html

SECTORMAPGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Umap.html?southWestLat=${SLAT}&southWestLon=${SLON}&deg=0.1&ipns=${SECTORNS}"
SECTORSATGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Usat.html?southWestLat=${SLAT}&southWestLon=${SLON}&deg=0.1&ipns=${SECTORNS}"
echo "<meta http-equiv=\"refresh\" content=\"0; url='${SECTORMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/SECTOR${SECTOR}.Map.html
echo "<meta http-equiv=\"refresh\" content=\"0; url='${SECTORSATGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/SECTOR${SECTOR}.Sat.html
##############################################################


       # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #~ ## IPFS GET ONLINE SECTORNS
        mkdir ~/.zen/tmp/${MOATS}/${SECTOR}
        ipfs get -o ~/.zen/tmp/${MOATS}/${SECTOR}/ /ipns/${SECTORNS}/
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        ## INIT TW WITH TEMPLATE
        [[ ! -d ~/.zen/tmp/${MOATS}/${SECTOR}/TW ]] \
            && mkdir ~/.zen/tmp/${MOATS}/${SECTOR}/TW \
            && cp ${MY_PATH}/../templates/minimal.html ~/.zen/tmp/${MOATS}/${SECTOR}/TW/index.html


        ## GET ALL RSS json's AND Feed SECTOR TW with it
        ## TODO Make function to CONTROL Tiddlers with same Title from different WT and detect conflict.
        RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${SLAT}*_${SLON}*/RSS/*.rss.json 2>/dev/null))
        NL=${#RSSNODE[@]}

        for RSS in ${RSSNODE[@]}; do

            ${MY_PATH}/../tools/RSS2UPlanetTW.sh "${RSS}" "${SECTOR}" "${MOATS}"

        done


        RSSWARM=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${SLAT}*_${SLON}*/RSS/*.rss.json 2>/dev/null))
        NS=${#RSSWARM[@]}

        for RSS in ${RSSWARM[@]}; do

            ${MY_PATH}/../tools/RSS2UPlanetTW.sh "${RSS}" "${SECTOR}" "${MOATS}"

        done

        TOTL=$((${NL}+${NS}))

echo "Number of RSS : "${TOTL}
        echo ${TOTL} > ~/.zen/tmp/${MOATS}/${SECTOR}/N_RSS
        IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${SECTOR}/* | tail -n 1)

        ipfs name publish -k ${SECTORG1PUB} /ipfs/${IPFSPOP}

ipfs key rm ${SECTORG1PUB} > /dev/null 2>&1


exit 0
