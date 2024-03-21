################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: DRAGONS
## Used by OSM2IPFS welcome.html
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

[[ $MOATS == "" ]] && echo "MISSING MOATS" && exit 1

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

# PREPARE HTTP RESPONSE (application/json)
mkdir -p ~/.zen/tmp/${MOATS}/
echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}/http
sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}/http

# ------------------------------------------------------------------- #
# GET/?dragons
# ------------------------------------------------------------------- #
## RUNNING UPLANET STATIONS GPS DETECTION
rm ~/.zen/tmp/DRAGONS.json

if [[ ! -s ~/.zen/tmp/DRAGONS.json ]]; then

    echo " ## cat ***/GPS.json"
    cat ~/.zen/tmp/${IPFSNODEID}/GPS.json 2>/dev/null | jq -c '.[] + {ipfsnodeid: "'$IPFSNODEID'"}'  > ~/.zen/tmp/${MOATS}/gps.grid
    cat ~/.zen/tmp/swarm/12D*/GPS.json 2>/dev/null | jq -c '.[] + {ipfsnodeid: "'$IPFSNODEID'"}' | sort -u >> ~/.zen/tmp/${MOATS}/gps.grid

    cat ~/.zen/tmp/${MOATS}/gps.grid | jq -s '.' | sed -e 's/\[/[/' -e 's/\]/]/' -e 's/},{/},\n{/g' > ~/.zen/tmp/DRAGONS.json
fi

#~ jq 'unique_by(.umap)' ~/.zen/tmp/DRAGONS.json > ~/.zen/tmp/DRAGONS_no_duplicates.json
#~ mv ~/.zen/tmp/DRAGONS_no_duplicates.json ~/.zen/tmp/DRAGONS.json
echo " ***** WELCOME DRAGONS =========== "
cat ~/.zen/tmp/DRAGONS.json

### SEND RESPONSE ON PORT
cat ~/.zen/tmp/DRAGONS.json  >> ~/.zen/tmp/${MOATS}/http
(
    cat ~/.zen/tmp/${MOATS}/http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    rm -Rf ~/.zen/tmp/${MOATS} && echo "BLURP DRAGONS.json"
) &

## TIMING
end=`date +%s`
echo "(DRAGONS) Operation time was "`expr $end - $start` seconds.
exit 0
