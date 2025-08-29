################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.UMAP.memory.sh
#~ Search for last "UPLANET${UPLANETG1PUB:0:8}:$1:..." in UPLANETG1PUB wallet history
#~ INTERCOM="UPLANET${UPLANETG1PUB:0:8}:${UMAP}:${TODATE}:/ipfs/${IPFSPOP}" TX COMMENT are made during UPLANET.refresh.sh
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
COINS=$($MY_PATH/../tools/G1check.sh ${SECTORG1PUB} | tail -n 1)
echo "SECTOR : ${SECTOR} (${COINS} G1) WALLET : ${SECTORG1PUB}"

## RETRIEVE FROM SECTOR UKEY
${MY_PATH}/../tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py history -n 40 -p ${SECTORG1PUB} -j \
    > ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json

## SCAN FOR UPLANET${UPLANETG1PUB:0:8}:${UMAP} in TX
if [[ -s ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json ]]; then

    intercom=$(jq -r '.[] | select(.comment | test("UPLANET${UPLANETG1PUB:0:8}:'"${UMAP}"'")) | .comment' ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json | tail -n 1)
    ipfs_pop=$(echo "$intercom" | rev | cut -d ':' -f 1 | rev)
    todate=$(echo "$intercom" | rev | cut -d ':' -f 2 | rev)
    echo "SYNC ${UMAP} <= $todate (=${YESTERDATE})=> $ipfs_pop"

    [[ ${todate} != ${YESTERDATE} ]] && echo "NO GOOD MEMORY - EXIT" && exit 1

    if [[ $ipfs_pop ]]; then
        echo "FOUND $todate MEMORY SLOT"
        g1pub=$(jq -r '.[] | select(.comment | test("UPLANET${UPLANETG1PUB:0:8}:'"${UMAP}"'")) | .pubkey' ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json | tail -n 1)
        echo "INFO :: $g1pub Memory updater"

        ## ADD SECURITY : check payment emitter is a "BOOSTRAP" (TODO)
        nodeid=$(${MY_PATH}/../tools/g1_to_ipfs.py $g1pub)

        ipfs --timeout 360s get --progress="false" -o ~/.zen/tmp/${MOATS}/${UMAP} $ipfs_pop \
            && ipfs pin rm $ipfs_pop \
            || echo "$ipfs_pop ERROR ... "
    else
        echo "WARNING cannot revover any memory !!"
    fi

    ## REMOVE PREVIOUS PIN (in case last one was not mine)
    antecom=$(jq -r '.[] | select(.comment | test("UPLANET${UPLANETG1PUB:0:8}:'"${UMAP}"'")) | .comment' ~/.zen/tmp/${MOATS}/${SECTOR}.g1history.json | tail -n 2 | head -n 1)
    ipfs_b=$(echo "$antecom" | rev | cut -d ':' -f 1 | rev)
    [[ ! -z ${ipfs_b} ]] && ipfs pin rm ${ipfs_b}


else
    echo "FATAL ERROR cannot access to SECTORG1PUB history"
    exit 1
fi

end=`date +%s`
echo "(${UMAP}.memory) ${todate} get time : "`expr $end - $start` seconds.

exit 0
