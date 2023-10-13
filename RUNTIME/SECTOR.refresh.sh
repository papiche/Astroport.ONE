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

[[ ! $(ls ~/.zen/tmp/${MOATS-undefined}/${UMAP-undefined}) ]] && echo "MISSING UMAP CONTEXT" && exit 1

SLAT=$(echo ${LAT} | xargs printf '%.1f\n' | sed s~,~.~g)
SLON=$(echo ${LON} | xargs printf '%.1f\n' | sed s~,~.~g)
SECTOR="_${SLAT}_${SLON}"
echo "WELCOME IN SECTOR${SECTOR}"

SECTORMAPGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Umap.html?southWestLat=${SLAT}&southWestLon=${SLON}&deg=0.1"
SECTORSATGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Usat.html?southWestLat=${SLAT}&southWestLon=${SLON}&deg=0.1"
echo "<meta http-equiv=\"refresh\" content=\"0; url='${SECTORMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/SECTOR${SECTOR}.Map.html
echo "<meta http-equiv=\"refresh\" content=\"0; url='${SECTORSATGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/SECTOR${SECTOR}.Sat.html
##############################################################
SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${SECTOR}" "${SECTOR}")
[[ ! ${SECTORG1PUB} ]] && echo "ERROR generating SECTOR WALLET" && exit 1
echo "ACTUAL SECTOR WALLET : ${SECTORG1PUB}"
${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SECTOR.priv "${SECTOR}" "${SECTOR}"
ipfs key rm ${SECTORG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
SECTORNS=$(ipfs key import ${SECTORG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SECTOR.priv)
##############################################################
       # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        ## IPFS GET ONLINE SECTORNS
        #~ mkdir ~/.zen/tmp/${MOATS}/${SECTOR}
        #~ ipfs get -o ~/.zen/tmp/${MOATS}/${SECTOR}/ /ipns/${SECTORNS}/
        #~ # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #~ # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #~ UREFRESH="${HOME}/.zen/tmp/${MOATS}/${SECTOR}/SECTOR.refresh"

## KEY SHARING
echo ""


exit 0
