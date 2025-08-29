################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.SECTOR.memory.sh
#~ Search for last "UPLANET${UPLANETG1PUB:0:8}:$1:..." in UPLANETG1PUB wallet history
#~ INTERCOM="UPLANET${UPLANETG1PUB:0:8}:${SECTOR}:${TODATE}:/ipfs/${IPFSPOP}" TX COMMENT are made during SECTOR.refresh.sh
#~ ~/.zen/tmp/${MOATS}/${SECTOR} <=> "/ipfs/$ipfs_pop"
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################

SECTOR="$1"
[[ $SECTOR == "" ]] && echo "MISSING SECTOR ADRESS" && exit 1
MOATS="$2"
G1PUB="$3"

## CHECK FOR BAD PARAM
[[ ! -d ~/.zen/tmp/${MOATS-empty}/${SECTOR-empty}/ ]] \
    && echo "BAD ~/.zen/tmp/${MOATS}/${SECTOR}" \
    && exit 1

## STARTING
start=`date +%s`

## CORRESPONDING REGION UKEY
LAT=$(echo ${SECTOR} | cut -d '_' -f 2)
LON=$(echo ${SECTOR} | cut -d '_' -f 3)
RLAT=$(echo ${LAT} | cut -d '.' -f 1)
RLON=$(echo ${LON} | cut -d '.' -f 1)

REGION="_${RLAT}_${RLON}"
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${REGION}.priv "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}"
REGIONG1PUB=$(cat ~/.zen/tmp/${MOATS}/${REGION}.priv | grep "pub:" | cut -d ' ' -f 2)
[[ ! ${REGIONG1PUB} ]] && echo "ERROR generating REGION WALLET" && exit 1
COINS=$($MY_PATH/../tools/G1check.sh ${REGIONG1PUB} | tail -n 1)
echo "REGION : ${REGION} (${COINS} G1) WALLET : ${REGIONG1PUB}"

## RETRIEVE FROM REGION UKEY
${MY_PATH}/../tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py history -n 40 -p ${REGIONG1PUB} -j \
    > ~/.zen/tmp/${MOATS}/${REGION}.g1history.json

## SCAN FOR UPLANET${UPLANETG1PUB:0:8}:${SECTOR} in TX
if [[ -s ~/.zen/tmp/${MOATS}/${REGION}.g1history.json ]]; then

    intercom=$(jq -r '.[] | select(.comment | test("UPLANET${UPLANETG1PUB:0:8}:'"${SECTOR}"'")) | .comment' ~/.zen/tmp/${MOATS}/${REGION}.g1history.json | tail -n 1)
    ipfs_pop=$(echo "$intercom" | rev | cut -d ':' -f 1 | rev)
    todate=$(echo "$intercom" | rev | cut -d ':' -f 2 | rev)
    echo "SYNC ${SECTOR} <= $todate (=${YESTERDATE})=> $ipfs_pop"

    [[ ${todate} != ${YESTERDATE} ]] && echo "NO GOOD MEMORY - EXIT" && exit 1

    ## TODO: SECURITY PATCH : check payment emitter is from BOOSTRAP
    if [[ $ipfs_pop ]]; then
        g1pub=$(jq -r '.[] | select(.comment | test("UPLANET${UPLANETG1PUB:0:8}:'"${SECTOR}"'")) | .pubkey' ~/.zen/tmp/${MOATS}/${REGION}.g1history.json | tail -n 1)
        echo "INFO :: $g1pub Memory updater"
        ipfs --timeout 180s get --progress="false" -o ~/.zen/tmp/${MOATS}/${SECTOR} $ipfs_pop \
            && ipfs pin rm $ipfs_pop \
            || echo "$ipfs_pop ERROR ... "
    else
        echo "WARNING cannot revover any memory !!"
    fi

else
    echo "FATAL ERROR cannot access to REGIONG1PUB history"
    exit 1
fi

end=`date +%s`
echo "(${SECTOR}.memory) ${todate} get time : "`expr $end - $start` seconds.

exit 0
