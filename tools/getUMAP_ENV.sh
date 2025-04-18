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
######################################################################
echo "UMAP : _${LAT}_${LON}"
UMAPNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
UMAPHEX=$(${MY_PATH}/../tools/nostr2hex.py $UMAPNPUB)
echo "UMAPHEX=$UMAPHEX"
UMAPG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
echo "UMAPG1PUB=$UMAPG1PUB"
UMAPIPNS="/ipns/"$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${LAT}" "${TODATE}${UPLANETNAME}${LON}")
echo "UMAPIPNS=$UMAPIPNS"

######################################################################
echo "SECTOR : _${SLAT}_${SLON}"
SECTORNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
SECTORHEX=$(${MY_PATH}/../tools/nostr2hex.py $SECTORNPUB)
echo "SECTORHEX=$SECTORHEX"
SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
echo "SECTORG1PUB=$SECTORG1PUB"
SECTORIPNS="/ipns/"$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}")
echo "SECTORIPNS=$SECTORIPNS"

######################################################################
echo "REGION : _${RLAT}_${RLON}"
REGIONNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
REGIONHEX=$(${MY_PATH}/../tools/nostr2hex.py $REGIONNPUB)
echo "REGIONHEX=$REGIONHEX"
REGIONG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
echo "REGIONG1PUB=$REGIONG1PUB"
REGIONIPNS="/ipns/"$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${REGION}" "${TODATE}${UPLANETNAME}${REGION}")
echo "REGIONIPNS=$REGIONIPNS"

echo "## LAST LINE EXPORT ############"
echo "export UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORHEX=$SECTORHEX SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONHEX=$REGIONHEX REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"
exit 0
