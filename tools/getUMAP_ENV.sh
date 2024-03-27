#!/bin/bah
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
[[ "$ZLAT" != "$LAT" ]] && echo "ERROR - LAT bad format -" && exit 1
[[ "$ZLON" != "$LON" ]] && echo "ERROR - LON bad format -" && exit 1

## CONTINUE
echo "UMAP : _${LAT}_${LON}"
SLAT="${LAT::-1}"
SLON="${LON::-1}"
echo "SECTOR : _${SLAT}_${SLON}"
RLAT="$(echo ${LAT} | cut -d '.' -f 1)"
RLON="$(echo ${LAT} | cut -d '.' -f 1)"
echo "REGION : _${RLAT}_${RLON}"

## COMPUTE
UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS | tail -n 1)
[[ ! $UMAPIPNS ]] && UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS | tail -n 1)
UMAPG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB | tail -n 1)
[[ ! $UMAPG1PUB ]] && UMAPG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB | tail -n 1)

SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORNS | tail -n 1)
[[ ! $SECTORIPNS ]] && SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORNS | tail -n 1)
SECTORG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORG1PUB | tail -n 1)
[[ ! $SECTORG1PUB ]] && SECTORG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORG1PUB | tail -n 1)

REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}REGIONNS | tail -n 1)
[[ ! $REGIONIPNS ]] && REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONNS | tail -n 1)
REGIONG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONG1PUB | tail -n 1)
[[ ! $REGIONG1PUB ]] && REGIONG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}REGIONG1PUB | tail -n 1)
