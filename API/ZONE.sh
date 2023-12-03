################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: ZONE
## Used by OSM2IPFS map_render.html & other UPlanet Client App
# ?zone=DEG&ulat=LAT&ulon=LON
## Search for TW numbers in received zone
# = json
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

## CHECK FOR NOT PUBLISHING ALREADY (AVOID IPNS CRUSH)
alreadypublishing=$(ps axf --sort=+utime | grep -w 'ipfs name publish --key=' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
if [[ ${alreadypublishing} ]]; then
     echo "$HTTPCORS {[error: ALREADY IPNS ERROR]}"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
     exit 1
fi

## START MANAGING UPLANET LAT/LON & PLAYER
mkdir -p ~/.zen/tmp/${MOATS}/
# GET RECEPTION : zone=0.001&ulat=0.02&ulon=0.01
DEG=${THAT}
[[ -z $DEG ]] && DEG=1
# DEG=$(echo "$DEG * 10" | bc -l )
LAT=${THIS}
[[ -z $LAT ]] && LAT=0.00
LON=${WHAT}
[[ -z $LON ]] && LON=0.00

echo '{ "gridNumbers": [ {"lat": '${LAT}', "lon": '${LON}', "number": SCAN}] }'

echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}.http
sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}.http
echo '{ "gridNumbers": [' >> ~/.zen/tmp/${MOATS}.http
for i in $(seq 0 9);
do
    ZLAT=$(echo "$LAT + $DEG * $i" | bc -l)
   # [[ ! $(echo $ZLAT | grep "\." ) ]] && ZLAT="${ZLAT}."
        for j in $(seq 0 9); do
            ZLON=$(echo "$LON + $DEG * $j" | bc -l)
      #      [[ ! $(echo $ZLON | grep "\." ) ]] && ZLON="${ZLON}."
            ## SEARCH HOW MUCH TW
            twnum=$(ls -d ~/.zen/tmp/swarm/*/UPLANET/_${ZLAT}*_${ZLON}*/TW/* 2>/dev/null | wc -l )
            [[ $twnum -gt 0 ]] && echo '{"lat": '${ZLAT}', "lon": '${ZLON}', "number": '${twnum}'}
            ,' >> ~/.zen/tmp/${MOATS}.http && echo "$DEG ~/.zen/tmp/swarm/*/UPLANET/_${ZLAT}*_${ZLON}*/TW/* = $twnum"

        done
done

sed -i '$ d' ~/.zen/tmp/${MOATS}.http ## REMOVE LAST ','

echo ']}'  >> ~/.zen/tmp/${MOATS}.http

cat ~/.zen/tmp/${MOATS}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &


# PRODUCE A JSON COUNTING PLAYERS TW IN EACH UMAP
# UPLANET OCCUPANCY LIST
#~ {
  #~ "gridNumbers": [
    #~ {"lat": 0.05, "lon": 0.05, "number": 1},
    #~ {"lat": 0.05, "lon": 0.15, "number": 2},
    #~ {"lat": 0.15, "lon": 0.05, "number": 3},
    #~ {"lat": 0.15, "lon": 0.15, "number": 4},
    #~ // Add more grid cells with their corresponding latitude, longitude, and number
  #~ ]
#~ }

rm -Rf ~/.zen/tmp/${MOATS}/
end=`date +%s`
echo "(ZONE) Operation time was "`expr $end - $start` seconds.
exit 0
