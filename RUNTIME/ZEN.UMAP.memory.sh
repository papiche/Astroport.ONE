################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.UMAP.memory.sh
#~ Search for last "UPLANET:$1:..." in UPLANETG1PUB wallet history
#~ INTERCOM="UPLANET:${UMAP}:${TODATE}:/ipfs/${IPFSPOP}" TX COMMENT are made during UPLANET.refresh.sh
#~ ~/.zen/tmp/${MOATS}/${UMAP} <=> "/ipfs/$ipfs_pop"
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################

UMAP="$1"
[[ $UMAP == "" ]] && echo "MISSING UMAP ADRESS" && exit 1
MOATS="$2"
G1PUB="$3"

## CHECK FOR BAD PARAM
[[ ! -d ~/.zen/tmp/${MOATS-empty}/${UMAP-empty}/ ]] \
    && echo "BAD ~/.zen/tmp/${MOATS}/${UMAP}" \
    && exit 1

## STARTING
start=`date +%s`

## CORRESPONDING SECTOR UKEY
LAT=$(echo ${UMAP} | cut -d '_' -f 2)
LON=$(echo ${UMAP} | cut -d '_' -f 3)

## SECTOR COORD
SLAT="${LAT::-1}"
SLON="${LON::-1}"

SECTOR="_${SLAT}_${SLON}"

${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${SECTOR}.priv "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}"
SECTORG1PUB=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}.priv | grep "pub:" | cut -d ' ' -f 2)
[[ ! ${SECTORG1PUB} ]] && echo "ERROR generating SECTOR WALLET" && exit 1
COINS=$($MY_PATH/../tools/COINScheck.sh ${SECTORG1PUB} | tail -n 1)
echo "SECTOR : ${SECTOR} (${COINS} G1) WALLET : ${SECTORG1PUB}"

## RETRIEVE FROM SECTOR UKEY
${MY_PATH}/../tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py history -n 100 -p ${SECTORG1PUB} -j \
    > ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json

## SCAN FOR UPLANET:${UMAP} in TX
if [[ -s ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json ]]; then

    intercom=$(jq -r '.[] | select(.comment | test("UPLANET:'"${UMAP}"'")) | .comment' ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json | tail -n 1)
    ipfs_pop=$(echo "$intercom" | rev | cut -d ':' -f 1 | rev)
    todate=$(echo "$intercom" | rev | cut -d ':' -f 2 | rev)
    echo "SYNC ~/.zen/tmp/${MOATS}/${UMAP} <=> $ipfs_pop"

    ## TODO: SECURITY PATCH : check payment emitter is from BOOSTRAP
    if [[ $ipfs_pop ]]; then
        echo "FOUND $todate MEMORY SLOT"
        g1pub=$(jq -r '.[] | select(.comment | test("UPLANET:'"${UMAP}"'")) | .pubkey' ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json | tail -n 1)
        echo "INFO :: $g1pub Memory updater"
        ipfs --timeout 180s get -o ~/.zen/tmp/${MOATS}/${UMAP} $ipfs_pop \
            || echo "$ipfs_pop ERROR ... "
    else
        echo "WARNING cannot revover any memory !!"
    fi

else
    echo "FATAL ERROR cannot access to SECTORG1PUB history"
    exit 1
fi

end=`date +%s`
echo "(${UMAP}.memory) ${todate} get time : "`expr $end - $start` seconds.

exit 0
