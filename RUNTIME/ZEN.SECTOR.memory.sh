################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.SECTOR.memory.sh
#~ Search for last "UPLANET:$1:..." in UPLANETG1PUB wallet history
#~ INTERCOM="UPLANET:${SECTOR}:${TODATE}:/ipfs/${IPFSPOP}" TX COMMENT are made during SECTOR.refresh.sh
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
REGLAT=$(echo ${LAT} | cut -d '.' -f 1)
REGLON=$(echo ${LON} | cut -d '.' -f 1)

REGION="_${REGLAT}_${REGLON}"
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${REGION}.priv "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}"
REGIONG1PUB=$(cat ~/.zen/tmp/${MOATS}/${REGION}.priv | grep "pub:" | cut -d ' ' -f 2)
[[ ! ${REGIONG1PUB} ]] && echo "ERROR generating REGION WALLET" && exit 1
COINS=$($MY_PATH/../tools/COINScheck.sh ${REGIONG1PUB} | tail -n 1)
echo "REGION : ${REGION} (${COINS} G1) WALLET : ${REGIONG1PUB}"

## RETRIEVE FROM REGION UKEY
${MY_PATH}/../tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py history -n 100 -p ${REGIONG1PUB} -j \
    > ~/.zen/tmp/${MOATS}/${REGION}.g1history.json

## SCAN FOR UPLANET:${SECTOR} in TX
if [[ -s ~/.zen/tmp/${MOATS}/${REGION}.g1history.json ]]; then

    intercom=$(jq -r '.[] | select(.comment | test("UPLANET:'"${SECTOR}"'")) | .comment' ~/.zen/tmp/${MOATS}/${REGION}.g1history.json | tail -n 1)
    ipfs_pop=$(echo "$intercom" | rev | cut -d ':' -f 1 | rev)
    todate=$(echo "$intercom" | rev | cut -d ':' -f 2 | rev)
    echo "SYNC ${SECTOR} <= $todate => $ipfs_pop"

    if [[ $ipfs_pop ]]; then
        g1pub=$(jq -r '.[] | select(.comment | test("UPLANET:'"${SECTOR}"'")) | .pubkey' ~/.zen/tmp/${MOATS}/${REGION}.g1history.json | tail -n 1)
        echo "INFO :: $g1pub Memory updater"
        ipfs --timeout 180s get -o ~/.zen/tmp/${MOATS}/${SECTOR} $ipfs_pop \
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
