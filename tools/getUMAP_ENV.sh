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
if [[ -z $UMAPROOT ]]; then
    UMAPROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ipfs.${YESTERDATE} 2>/dev/null)
    [[ -z $UMAPROOT ]] && UMAPROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ipfs.${YESTERDATE} 2>/dev/null | tail -n 1)
fi
echo "UMAPROOT=$UMAPROOT"

UMAPHEX=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX 2>/dev/null | tail -n 1)
[[ -z $UMAPHEX ]] && UMAPHEX=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX 2>/dev/null | tail -n 1)
echo "UMAPHEX=$UMAPHEX"

UMAPG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)
[[ -z $UMAPG1PUB ]] && UMAPG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB 2>/dev/null | tail -n 1)
echo "UMAPG1PUB=$UMAPG1PUB"

UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)
[[ $UMAPIPNS == "/ipns/" ]] && UMAPIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS 2>/dev/null | tail -n 1)
echo "UMAPIPNS=$UMAPIPNS"

######################################################################
echo "SECTOR : _${SLAT}_${SLON}"
SECTORROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} 2>/dev/null)
[[ -z $SECTORROOT ]] && SECTORROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} 2>/dev/null | tail -n 1)
if [[ -z $SECTORROOT ]]; then
    SECTORROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${YESTERDATE} 2>/dev/null)
    [[ -z $SECTORROOT ]] && SECTORROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${YESTERDATE} 2>/dev/null | tail -n 1)
fi
echo "SECTORROOT=$SECTORROOT"

SECTORHEX=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/HEX_SECTOR 2>/dev/null | tail -n 1)
[[ -z $SECTORHEX ]] && SECTORHEX=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/HEX_SECTOR 2>/dev/null | tail -n 1)
echo "SECTORHEX=$SECTORHEX"

SECTORG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
[[ -z $SECTORG1PUB ]] && SECTORG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORG1PUB 2>/dev/null | tail -n 1)
echo "SECTORG1PUB=$SECTORG1PUB"

SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)
[[ $SECTORIPNS == "/ipns/" ]] && SECTORIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_*_*/SECTORNS 2>/dev/null | tail -n 1)
echo "SECTORIPNS=$SECTORIPNS"

######################################################################
echo "REGION : _${RLAT}_${RLON}"
REGIONROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} 2>/dev/null)
[[ -z $REGIONROOT ]] && REGIONROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} 2>/dev/null | tail -n 1)
if [[ -z $REGIONROOT ]]; then
    REGIONROOT=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${YESTERDATE} 2>/dev/null)
    [[ -z $REGIONROOT ]] && REGIONROOT=$(cat ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${YESTERDATE} 2>/dev/null | tail -n 1)
fi
echo "REGIONROOT=$REGIONROOT"

REGIONHEX=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/HEX_REGION 2>/dev/null | tail -n 1)
[[ -z $REGIONHEX ]] && REGIONHEX=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/HEX_REGION 2>/dev/null | tail -n 1)
echo "REGIONHEX=$REGIONHEX"

REGIONG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
[[ -z $REGIONG1PUB ]] && REGIONG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONG1PUB 2>/dev/null | tail -n 1)
echo "REGIONG1PUB=$REGIONG1PUB"

REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)
[[ $REGIONIPNS == "/ipns/" ]] && REGIONIPNS="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}_${RLON}/_*_*/_*_*/REGIONNS 2>/dev/null | tail -n 1)
echo "REGIONIPNS=$REGIONIPNS"

echo "## LAST LINE EXPORT ############"
echo "export UMAPROOT=$UMAPROOT SECTORROOT=$SECTORROOT REGIONROOT=$REGIONROOT UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORHEX=$SECTORHEX SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONHEX=$REGIONHEX REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"
exit 0
