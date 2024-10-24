#!/bin/bash
##################################################
## Get TODATE G1PUB & IPNS values for LAT / LON
##################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

## INIT
LAT="$1"
LON="$2"
ZLAT=$(makecoord ${LAT})
ZLON=$(makecoord ${LON})
## CHECK
[[ "$ZLAT" != "$LAT" || "$LAT" == "" ]] && echo "# ERROR - $LAT bad format -" && exit 1
[[ "$ZLON" != "$LON" || "$LON" == "" ]] && echo "# ERROR - $LON bad format -" && exit 1

## COMPUTE UMAP, USECTOR, UREGION
SLAT="${LAT::-1}"
SLON="${LON::-1}"
SECTOR="_${SLAT}_${SLON}"
RLAT="$(echo ${LAT} | cut -d '.' -f 1)"
RLON="$(echo ${LON} | cut -d '.' -f 1)"
REGION="_${RLAT}_${RLON}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir ~/.zen/tmp/${MOATS}

## GET ENV
######################################################################
echo "UMAP : _${LAT}_${LON}"
UMAPG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)
[[ -z $UMAPG1PUB ]] && UMAPG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)

if [[ -z $UMAPG1PUB ]]; then
    UMAPG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/
    echo "$UMAPG1PUB" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB
fi
echo "UMAPG1PUB=$UMAPG1PUB"

UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)
[[ $UMAPIPNS == "/ipns/" ]] && UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)

if [[ $UMAPIPNS == "/ipns/" ]]; then
    UMAPIPNS=$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${LAT}" "${TODATE}${UPLANETNAME}${LON}")
    echo "$UMAPIPNS" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS
    UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS)
fi
echo "UMAPIPNS=$UMAPIPNS"

######################################################################
echo "SECTOR : _${SLAT}_${SLON}"
SECTORG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
[[ ! $SECTORG1PUB ]] && SECTORG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
if [[ ! $SECTORG1PUB ]]; then
    SECTORG1PUB=$(${MY_PATH}/../tools/keygen "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    echo "$SECTORG1PUB" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORG1PUB
fi
echo "SECTORG1PUB=$SECTORG1PUB"

SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)
[[ $SECTORIPNS == "/ipns/" ]] && SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)

if [[ $SECTORIPNS == "/ipns/" ]]; then
    SECTORIPNS=$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}")
    echo "$SECTORIPNS" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORNS
    SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORNS)
fi
echo "SECTORIPNS=$SECTORIPNS"

######################################################################
echo "REGION : _${RLAT}_${RLON}"
REGIONG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
[[ ! $REGIONG1PUB ]] && REGIONG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
if [[ ! $REGIONG1PUB ]]; then
    REGIONG1PUB=$(${MY_PATH}/../tools/keygen "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
    echo "$REGIONG1PUB" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONG1PUB
fi
echo "REGIONG1PUB=$REGIONG1PUB"

REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)
[[ $REGIONIPNS == "/ipns/" ]] && REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)

if [[ $REGIONIPNS == "/ipns/" ]]; then
    REGIONIPNS=$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${REGION}" "${TODATE}${UPLANETNAME}${REGION}")
    echo "$REGIONIPNS" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONNS
    REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONNS)
fi
echo "REGIONIPNS=$REGIONIPNS"

rm -Rf ~/.zen/tmp/${MOATS}

echo "## LAST LINE EXPORT ############"
echo "export UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"

exit 0
