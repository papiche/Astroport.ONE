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

[[ ! -d ~/.zen/tmp/${MOATS-undefined}/${UMAP-undefined} ]] && echo "MISSING UMAP CONTEXT" && exit 1

REGLAT=$(echo ${LAT} | cut -d '.' -f 1)
REGLON=$(echo ${LON} | cut -d '.' -f 1)
REGION="_${REGLAT}_${REGLON}"
echo "REGION ${REGION}"
[[ -s ~/.zen/tmp/${MOATS}/${UMAP}/${REGION}/index.html ]] && echo "ALREADY DONE" && exit 0

[[ "${REGIONNODE}" == "${IPFSNODEID}" ]] && echo ">>> MANAGING REGION PUBLICATION" || exit 0

##############################################################
REGIONG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
[[ ! ${REGIONG1PUB} ]] && echo "ERROR generating REGION WALLET" && exit 1
        COINS=$($MY_PATH/../tools/COINScheck.sh ${REGIONG1PUB} | tail -n 1)
        echo "REGION : ${REGION} (${COINS} G1) WALLET : ${REGIONG1PUB}"

${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/REGION.priv "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}"
ipfs key rm ${REGIONG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
REGIONNS=$(ipfs key import ${REGIONG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/REGION.priv)
##############################################################
mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${REGION}
echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${REGIONNS}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/${REGION}/index.html

REGIONMAPGEN="/ipfs/QmWRfn9wszPzCmo7VHxc5f6tTJmAnLUrBiygsjjnU99HA2/Umap.html?southWestLat=${REGLAT}&southWestLon=${REGLON}&deg=1&ipns=${REGIONNS}"
REGIONSATGEN="/ipfs/QmWRfn9wszPzCmo7VHxc5f6tTJmAnLUrBiygsjjnU99HA2/Usat.html?southWestLat=${REGLAT}&southWestLon=${REGLON}&deg=1&ipns=${REGIONNS}"
echo "<meta http-equiv=\"refresh\" content=\"0; url='${REGIONMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/REGION${REGION}.Map.html
echo "<meta http-equiv=\"refresh\" content=\"0; url='${REGIONSATGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/REGION${REGION}.Sat.html

       # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #~ ## IPFS GET ONLINE SECTORNS
        mkdir ~/.zen/tmp/${MOATS}/${REGION}
        ipfs --timeout 42s get -o ~/.zen/tmp/${MOATS}/${REGION}/ /ipns/${REGIONNS}/
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${REGLAT}*_${REGLON}*/RSS/*.rss.json 2>/dev/null))
            for RSS in ${RSSNODE[@]}; do
                echo ${RSS}
            done
        NL=${#RSSNODE[@]}
        RSSWARM=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${REGLAT}*_${REGLON}*/RSS/*.rss.json 2>/dev/null))
            for RSS in ${RSSWARM[@]}; do
                echo ${RSS}
            done
        NS=${#RSSWARM[@]}
        TOTL=$((${NL}+${NS}))

echo "Number of RSS : "${TOTL}
        echo ${TOTL} > ~/.zen/tmp/${MOATS}/${REGION}/N_RSS
        IPFSPOP=$(ipfs add -q ~/.zen/tmp/${MOATS}/${REGION}/N_RSS)

        ipfs name publish -k ${REGIONG1PUB} /ipfs/${IPFSPOP}

ipfs key rm ${REGIONG1PUB} > /dev/null 2>&1

exit 0
