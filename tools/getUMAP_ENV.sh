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
UMAPROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ipfs.${TODATE} 2>/dev/null)
[[ -z $UMAPROOT ]] && UMAPROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ipfs.${TODATE} 2>/dev/null | tail -n 1)
echo "UMAPROOT=$UMAPROOT"

UMAPHEX=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX 2>/dev/null | tail -n 1)
[[ -z $UMAPHEX ]] && UMAPHEX=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX 2>/dev/null | tail -n 1)
if [[ -z $UMAPHEX ]]; then
    UMAPNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    UMAPHEX=$(${MY_PATH}/../tools/nostr2hex.py $UMAPNPUB)
fi
echo "UMAPHEX=$UMAPHEX"

UMAPG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)
[[ -z $UMAPG1PUB ]] && UMAPG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)
if [[ -z $UMAPG1PUB ]]; then
    UMAPG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
fi
echo "UMAPG1PUB=$UMAPG1PUB"

UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)
[[ $UMAPIPNS == "/ipns/" ]] && UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)
if [[ $UMAPIPNS == "/ipns/" ]]; then
    UMAPIPNS="/ipns/"$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${LAT}" "${TODATE}${UPLANETNAME}${LON}")
fi
echo "UMAPIPNS=$UMAPIPNS"

######################################################################
echo "SECTOR : _${SLAT}_${SLON}"
SECTORROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} 2>/dev/null)
[[ -z $SECTORROOT ]] && SECTORROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} 2>/dev/null | tail -n 1)
echo "SECTORROOT=$SECTORROOT"

SECTORHEX=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX_SECTOR 2>/dev/null | tail -n 1)
[[ -z $SECTORHEX ]] && SECTORHEX=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX_SECTOR 2>/dev/null | tail -n 1)
if [[ -z $SECTORHEX ]]; then
    SECTORNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    SECTORHEX=$(${MY_PATH}/../tools/nostr2hex.py $SECTORNPUB)
fi
echo "SECTORHEX=$SECTORHEX"

SECTORG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
[[ ! $SECTORG1PUB ]] && SECTORG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
if [[ ! $SECTORG1PUB ]]; then
    SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
fi
echo "SECTORG1PUB=$SECTORG1PUB"

SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)
[[ $SECTORIPNS == "/ipns/" ]] && SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)
if [[ $SECTORIPNS == "/ipns/" ]]; then
    SECTORIPNS="/ipns/"$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}")
fi
echo "SECTORIPNS=$SECTORIPNS"

######################################################################
echo "REGION : _${RLAT}_${RLON}"
REGIONROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} 2>/dev/null)
[[ -z $REGIONROOT ]] && REGIONROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} 2>/dev/null | tail -n 1)
echo "REGIONROOT=$REGIONROOT"

REGIONHEX=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX_REGION 2>/dev/null | tail -n 1)
[[ -z $REGIONHEX ]] && REGIONHEX=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX_REGION 2>/dev/null | tail -n 1)
if [[ -z $REGIONHEX ]]; then
    REGIONNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
    REGIONHEX=$(${MY_PATH}/../tools/nostr2hex.py $REGIONNPUB)
fi
echo "REGIONHEX=$REGIONHEX"

REGIONG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
[[ ! $REGIONG1PUB ]] && REGIONG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
if [[ ! $REGIONG1PUB ]]; then
    REGIONG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
fi
echo "REGIONG1PUB=$REGIONG1PUB"

REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)
[[ $REGIONIPNS == "/ipns/" ]] && REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)
if [[ $REGIONIPNS == "/ipns/" ]]; then
    REGIONIPNS="/ipns/"$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${REGION}" "${TODATE}${UPLANETNAME}${REGION}")
fi
echo "REGIONIPNS=$REGIONIPNS"

echo "## LAST LINE EXPORT ############"
echo "export UMAPROOT=$UMAPROOT SECTORROOT=$SECTORROOT REGIONROOT=$REGIONROOT UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORHEX=$SECTORHEX SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONHEX=$REGIONHEX REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"
exit 0
