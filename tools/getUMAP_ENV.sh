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

## GET ENV
echo "UMAP : _${LAT}_${LON}"
UMAPG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)
[[ ! $UMAPG1PUB ]] && UMAPG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)
# [[ ! $UMAPG1PUB ]] && echo "NO UMAP FOUND" && exit 0
echo "UMAPG1PUB=$UMAPG1PUB"
UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)
[[ $UMAPIPNS == "/ipns/"  ]] && UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)
echo "UMAPIPNS=$UMAPIPNS"

echo "SECTOR : _${SLAT}_${SLON}"
SECTORG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
[[ ! $SECTORG1PUB ]] && SECTORG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
echo "SECTORG1PUB=$SECTORG1PUB"
SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)
[[ $SECTORIPNS == "/ipns/" ]] && SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)
echo "SECTORIPNS=$SECTORIPNS"

echo "REGION : _${RLAT}_${RLON}"
REGIONG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
[[ ! $REGIONG1PUB ]] && REGIONG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
echo "REGIONG1PUB=$REGIONG1PUB"
REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)
[[ $REGIONIPNS == "/ipns/" ]] && REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)
echo "REGIONIPNS=$REGIONIPNS"

echo "## LAST LINE EXPORT"
echo "export UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"

exit 0
