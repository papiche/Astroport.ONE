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
## REGION REFRESH
# SHARE & UPDATE IPNS TOGETHER
############################################
echo "## RUNNING REGION.refresh"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

## CALLED BY UPLANET.refresh.sh
LAT=$1
LON=$2
MOATS=$3
UMAP=$4
REGIONNODE=$5


[[ ! $(ls ~/.zen/tmp/${MOATS-undefined}/${UMAP-undefined}) ]] && echo "MISSING UMAP CONTEXT" && exit 1

CLAT=$(echo ${LAT} | cut -d '.' -f 1)
CLON=$(echo ${LON} | cut -d '.' -f 1)
REGION="_${CLAT}_${CLON}"
echo "REGION ${REGION}"

REGIONMAPGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Umap.html?southWestLat=${CLAT}&southWestLon=${CLON}&deg=1"
REGIONSATGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Usat.html?southWestLat=${CLAT}&southWestLon=${CLON}&deg=1"
echo "<meta http-equiv=\"refresh\" content=\"0; url='${REGIONMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/REGION${REGION}.Map.html
echo "<meta http-equiv=\"refresh\" content=\"0; url='${REGIONSATGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/REGION${REGION}.Sat.html

[[ "${REGIONNODE}" == "${IPFSNODEID}" ]] && echo ">>> MANAGING REGION PUBLICATION" || exit 0

##############################################################
REGIONG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${REGION}" "${REGION}")
[[ ! ${REGIONG1PUB} ]] && echo "ERROR generating REGION WALLET" && exit 1
echo "REGION WALLET : ${REGIONG1PUB}"

${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/REGION.priv "${REGION}" "${REGION}"
ipfs key rm ${REGIONG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
REGIONNS=$(ipfs key import ${REGIONG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/REGION.priv)
##############################################################
echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${REGIONNS}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/REGION${REGION}.IPNS.html

       # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #~ ## IPFS GET ONLINE SECTORNS
        mkdir ~/.zen/tmp/${MOATS}/${REGION}
        ipfs get -o ~/.zen/tmp/${MOATS}/${REGION}/ /ipns/${REGIONNS}/
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${CLAT}*_${CLON}*/RSS/*.rss.json 2>/dev/null))
        NL=${#RSSNODE[@]}
        RSSWARM=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${CLAT}*_${CLON}*/RSS/*.rss.json 2>/dev/null))
        NS=${#RSSWARM[@]}
        TOTL=$((${NL}+${NS}))

echo "Number of RSS : "${TOTL}
        echo ${TOTL} > ~/.zen/tmp/${MOATS}/${REGION}/${TOTL}
        IPFSPOP=$(ipfs add -q ~/.zen/tmp/${MOATS}/${REGION}/${TOTL})

        ipfs name publish -k ${REGIONG1PUB} /ipfs/${IPFSPOP}

ipfs key rm ${REGIONG1PUB} > /dev/null 2>&1

exit 0
