#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: ZONE
## Used by OSM2IPFS map_render.html & other UPlanet Client App
# ?zone=DEG&ulat=LAT&ulon=LON
## Search for TW numbers in received zone # >> return json
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

start=`date +%s`

echo "PORT=$1
THAT=$2
AND=$3
THIS=$4
APPNAME=$5
WHAT=$6
OBJ=$7
VAL=$8
MOATS=$9
COOKIE=$10"
PORT="$1" THAT="$2" AND="$3" THIS="$4"  APPNAME="$5" WHAT="$6" OBJ="$7" VAL="$8" MOATS="$9" COOKIE="$10"
### transfer variables according to script

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

## RUNNING UPLANET LAT/LON TW DETECTION
mkdir -p ~/.zen/tmp/${MOATS}/
# PREPARE HTTP RESPONSE (application/json)
echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}.http
sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}.http

# ------------------------------------------------------------------- #
# GET/?zone=0.001&ulat=0.02&ulon=0.01
# ------------------------------------------------------------------- #

DEG="${THAT}"
[[ -z ${DEG} ]] && DEG=1
# DEG=$(echo "${DEG} * 10" | bc -l )

LAT="${THIS}"
[[ -z $LAT ]] && LAT=0.00

LON="${WHAT}"
[[ -z $LON ]] && LON=0.00

LAT=$(makecoord ${LAT})
LON=$(makecoord ${LON})
JSON="ZONE_${LAT}_${LON}_${DEG}.json"
$(${MY_PATH}/../tools/getUMAP_ENV.sh "${LAT}" "${LON}" | tail -n 1)
echo "UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS
SECTORHEX=$SECTORHEX SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS
REGIONHEX=$REGIONHEX REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS
LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"

## SECTOR LEVEL
if [[ ${DEG} == "0.01" ]]; then

    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    SECTOR="_${SLAT}_${SLON}"
    echo "SECTOR = ${SECTOR}"
    ZONEINDEX=$SECTORIPNS
    [[ ! $ZONEINDEX ]] && ZONEINDEX="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_${SLAT}*_${SLON}*/_*_*/SECTORNS | tail -n 1)
    [[ ! $ZONEINDEX ]] && ZONEINDEX="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_${SLAT}*_${SLON}*/_*_*/SECTORNS | tail -n 1)
    ZONEG1PUB=$SECTORG1PUB
    [[ ! $ZONEG1PUB ]] && ZONEG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_${SLAT}*_${SLON}*/_*_*/SECTORG1PUB | tail -n 1)
    [[ ! $ZONEG1PUB ]] && ZONEG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_${SLAT}*_${SLON}*/_*_*/SECTORG1PUB | tail -n 1)
    ZONEHEX=$SECTORHEX
    LAT=${SLAT}
    LON=${SLON}
    JSON="ZONE${SECTOR}_${DEG}.json"

fi

## REGION & ABOVE LEVEL
if [[ ${DEG} == "0.1" ||  ${DEG} == "1" ]]; then

    RLAT="$(echo ${LAT} | cut -d '.' -f 1)"
    RLON="$(echo ${LON} | cut -d '.' -f 1)"
    REGION="_${RLAT}_${RLON}"
    echo "REGION = ${REGION}"
    ZONEINDEX=$REGIONIPNS
    [[ ! $ZONEINDEX ]] && ZONEINDEX="/ipns/"$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}*_${RLON}*/_*_*/_*_*/REGIONNS | tail -n 1)
    [[ ! $ZONEINDEX ]] && ZONEINDEX="/ipns/"$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}*_${RLON}*/_*_*/_*_*/REGIONNS | tail -n 1)
    ZONEG1PUB=$REGIONG1PUB
    [[ ! $ZONEG1PUB ]] && ZONEG1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_${RLAT}*_${RLON}*/_*_*/_*_*/REGIONG1PUB | tail -n 1)
    [[ ! $ZONEG1PUB ]] && ZONEG1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${RLAT}*_${RLON}*/_*_*/_*_*/REGIONG1PUB | tail -n 1)
    ZONEHEX=$REGIONHEX
    LAT=${RLAT}
    LON=${RLON}
    JSON="ZONE${REGION}_${DEG}.json"

fi

echo " JSON = ${JSON}"

if [[ ! -s ~/.zen/tmp/${JSON} ]]; then

    ## UMAP LEVEL
    if [[ ${DEG} == "0.001" ]]; then

        swarmnum=$(ls -d ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TW/* 2>/dev/null | wc -l )
        #~ nodenum=$(ls -d ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TW/* 2>/dev/null | wc -l )
        nodenum=0 ## correct duplicate players !
        totnum=$(( swarmnum + nodenum ))
        echo " ## UMAP _${LAT}_${LON} = ${totnum} PLAYERs"

        UMAPNS=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TODATENS | tail -n 1)
        [[ ! $UMAPNS ]] && UMAPNS=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TODATENS | tail -n 1)
        G1PUB=$(cat ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/G1PUB | tail -n 1)
        [[ ! $G1PUB ]] && G1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/G1PUB | tail -n 1)

        echo '{ "gridNumbers": [ {"lat": '${LAT}', "lon": '${LON}', "number": "(_'${LAT}'_'${LON}') = '${totnum}'", "ipns": "'${myIPFS}/ipns/${UMAPNS}/_index.html'" , "hex": "'${UMAPHEX}'" } ] }' \
            > ~/.zen/tmp/${MOATS}/http.grid

        cp ~/.zen/tmp/${MOATS}/http.grid ~/.zen/tmp/${JSON}
        cat ~/.zen/tmp/${JSON} >> ~/.zen/tmp/${MOATS}.http

        cat ~/.zen/tmp/${MOATS}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

        rm -Rf ~/.zen/tmp/${MOATS}/
        end=`date +%s`
        echo "(UMAP)_${LAT}_${LON} $UMAPNS Operation time was "`expr $end - $start` seconds.
        exit 0

    fi

    ##############################################
    ## SEARCH FOR UPLANET TW NUMBERS IN THAT ZONE
    echo '{ "gridNumbers": [' >> ~/.zen/tmp/${MOATS}/http.grid

    for i in $(seq 0 9);
    do

        ZLAT=$(echo "$LAT + ${DEG} * $i" | bc -l)
        [[ -z  ${ZLAT} ]] && ZLAT=0

        for j in $(seq 0 9); do

            ZLON=$(echo "$LON + ${DEG} * $j" | bc -l)
            [[ -z  ${ZLON} ]] && ZLON=0

            echo " ## SEARCH UPLANET/__/_*_*/_*.?_*.?/_${ZLAT}*_${ZLON}*"
            swarmnum=$(ls -d ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_${ZLAT}*_${ZLON}*/TW/* 2>/dev/null | wc -l )
            #~ nodenum=$(ls -d ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_${ZLAT}*_${ZLON}*/TW/* 2>/dev/null | wc -l )
            nodenum=0
            totnum=$(( swarmnum + nodenum ))

            [[ $totnum -gt 9 ]] && displaynum="X" || displaynum=$totnum

            [[ $displaynum != "0" ]] && echo '{"lat": '${ZLAT}', "lon": '${ZLON}', "number": "'${displaynum}'", "ipns": "'${ZONEINDEX}'", "hex": "'${ZONEHEX}'" }
            ,' >> ~/.zen/tmp/${MOATS}/http.grid \
                && echo "${DEG} :" '{"lat": '${ZLAT}', "lon": '${ZLON}', "number": "'${totnum}'", "ipns": "'${ZONEINDEX}'", "hex": "'${ZONEHEX}'" }'

        done

    done

    [[ ! $(cat ~/.zen/tmp/${MOATS}/http.grid | tail -n 1 | grep 'gridNumbers' ) ]] \
        && sed -i '$ d' ~/.zen/tmp/${MOATS}/http.grid ## REMOVE LAST ','

    echo ']}'  >> ~/.zen/tmp/${MOATS}/http.grid

    echo "## ADD TO CACHE ~/.zen/tmp/${JSON}"
    cp ~/.zen/tmp/${MOATS}/http.grid ~/.zen/tmp/${JSON}

fi

cat ~/.zen/tmp/${JSON} | jq -c

### SEND RESPONSE ON PORT
cat ~/.zen/tmp/${JSON} >> ~/.zen/tmp/${MOATS}.http
(
    cat ~/.zen/tmp/${MOATS}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    rm ~/.zen/tmp/${MOATS}/http.grid 2>/dev/null
    rm ~/.zen/tmp/${MOATS}.http && echo "BLURP ${JSON}"
) &
## CLEANING
rm -Rf ~/.zen/tmp/${MOATS}/
## TIMING
end=`date +%s`
echo "(ZONE) Operation time was "`expr $end - $start` seconds.
exit 0
