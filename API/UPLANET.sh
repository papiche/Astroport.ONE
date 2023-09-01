################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: UPLANET
## Dedicated to OSM2IPFS & UPlanet Client App
# ?uplanet=EMAIL&LAT=LON
## https://git.p2p.legal/qo-op/OSM2IPFS
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
QRCODE=$(echo "$THAT" | cut -d ':' -f 1) # G1nkgo compatible

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"
function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

## GET TW
mkdir -p ~/.zen/tmp/${MOATS}/

## DIRECT VISA.print.sh
PLAYER=${THAT}
[[ ${PLAYER} == "lat"  ]] && PLAYER="@"

[[ ${AND} == "lat" ]] && SALT=${THIS} || SALT=${AND}

input_number=${SALT}
if [[ ! $input_number =~ ^[0-9]{1,3}\.[0-9]*$ ]]; then
    (echo "$HTTPCORS ERROR - BAD LAT $LAT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0
else
    LAT=${input_number}
fi

[[ ${APPNAME} == "lon" ]] && PEPPER=${WHAT} || PEPPER=${APPNAME}

input_number=${PEPPER}
if [[ ! $input_number =~ ^[0-9]{1,3}\.[0-9]*$ ]]; then
    (echo "$HTTPCORS ERROR - BAD LON $LON" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0
else
   LON=${input_number}
fi

PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

### CHECK PLAYER EMAIL
EMAIL="${PLAYER,,}" # lowercase

[[ ! ${EMAIL} ]] && (echo "$HTTPCORS ERROR - MISSING ${EMAIL} FOR UPLANET LANDING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0

## CHECK WHAT IS EMAIL
if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
    echo "VALID ${EMAIL} EMAIL OK"
else
    echo "BAD EMAIL"
    (echo "$HTTPCORS PLEASE PROVIDE A VALID EMAIL ${EMAIL} '"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 0
fi

### CREATE G1VISA & G1Card
echo "${MY_PATH}/../tools/VISA.print.sh" "${EMAIL}"  "'"$SALT"'" "'"$PEPPER"'" "'"$PASS"'" "'"$PASS"'"
${MY_PATH}/../tools/VISA.print.sh "${EMAIL}"  "$SALT" "$PEPPER" "$PASS" "${PASS}"##
[[ ${EMAIL} != "" && ${EMAIL} != $(cat ~/.zen/game/players/.current/.player 2>/dev/null) ]] && rm -Rf ~/.zen/game/players/${EMAIL}/

# UPLANET #############################################
## OCCUPY COMMON CRYPTO KEY CYBERSPACE
## SALT="UPLANET LAT $LAT" PEPPER="UPLANET LON $LON"
######################################################
echo "UMAP = $LAT:$LON"
echo "# CALCULATING MAP G1PUB WALLET"
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/cesium.key  "$LAT" "$LON"
G1PUB=$(cat ~/.zen/tmp/${MOATS}/cesium.key | grep 'pub:' | cut -d ' ' -f 2)
[[ ! ${G1PUB} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - KEYGEN  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
echo "MAPG1PUB : ${G1PUB}"

echo "# CALCULATING UMAP IPNS ADDRESS"
ipfs key rm ${G1PUB} > /dev/null 2>&1
rm -f ~/.zen/tmp/${MOATS}/${G1PUB}.priv
${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${G1PUB}.priv "$LAT" "$LON"
UMAPNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${G1PUB}.priv )
[[ ! ${UMAPNS} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - UMAPNS  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
echo "UMAPNS : http://ipfs.localhost:8080/ipns/${UMAPNS}"

####################################### Umap.png
## CREATING Umap_${SALT}_${PEPPER}.png
echo "# OSM2IPFS ~/.zen/tmp/${MOATS}/Umap_${SALT}_${PEPPER}.png"
chromium --headless --disable-gpu --screenshot=/tmp/Umap_${SALT}_${PEPPER}.png --window-size=600x600 "https://ipfs.copylaradio.com/ipfs/QmegythUHq8bhcLKDAtLh5TRfBt8w1aES3gHykuywyMg9a/Umap.html?southWestLat=$SALT&southWestLon=$PEPPER&deg=0.01"

## COPYING FILES FROM ABROAD
cp /tmp/Umap_${SALT}_${PEPPER}.png ~/.zen/tmp/${MOATS}/Umap_${SALT}_${PEPPER}.png
cp ~/.zen/tmp/${PASS}##/G1*.jpg ~/.zen/tmp/${MOATS}/
ls ~/.zen/tmp/${MOATS}/

## ADD TO FRIENDS
echo "${EMAIL}" >> ~/.zen/tmp/${MOATS}/UFriends.txt

## ADD HPASS to verify PASS is right
HPASS=$(echo $PASS | sha512sum | cut -d ' ' -f 1)
echo "${HPASS}" > ~/.zen/tmp/${MOATS}/.hpass

## TAKING CARE OF THE CHAIN
########################################
IPFSROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/* | tail -n 1)
########################################
ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/.chain 2>/dev/null)
ZMOATS=$(cat ~/.zen/tmp/${MOATS}/.moats 2>/dev/null)
[[ ${ZCHAIN} && ${ZMOATS} ]] && cp ~/.zen/tmp/${MOATS}/.chain ~/.zen/tmp/${MOATS}/.chain.${ZMOATS}
## DOES CHAIN CHANGED ?
[[ ${ZCHAIN} != ${IPFSROOT} || ${ZCHAIN} == "" ]] \
    && echo "${IPFSROOT}" > ~/.zen/tmp/${MOATS}/.chain \
    && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/.moats
[[ ! ${ZCHAIN} ]] && IPFSROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/* | tail -n 1) && echo "INIT THE CHAIN"
########################################
echo "IPFSROOT : http://ipfs.localhost:8080/ipfs/${IPFSROOT}"

## CHECK FOR NOT PUBLISHING ALREADY (AVOID IPNS CRUSH)
alreadypublishing=$(ps axf --sort=+utime | grep -w 'ipfs name publish --key=' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
if [[ ${alreadypublishing} ]]; then
     echo "$HTTPCORS ERROR - (╥☁╥ ) - IPFS ALREADY PUBLISHING RETRY LATER"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
     exit 1
else
    (
    ipfs name publish --key=${G1PUB} /ipfs/${IPFSROOT}
    end=`date +%s`
    echo "(IPNS) publish time was "`expr $end - $start` seconds.
    ) &
fi

echo "$HTTPCORS
    <html>
    <head>
    <title>[Astroport] :powered: Station</title>
    <meta http-equiv=\"refresh\" content=\"300; url='https://ipfs.copylaradio.com/ipns/${UMAPNS}'\" />
    </head><body>
    UMAPNS : http://ipfs.localhost:8080/ipns/${UMAPNS}
    CHAIN : https://ipfs.copylaradio.com/ipfs/${IPFSROOT}
    <br>
        $LAT/$LON BLOCKCHAIN REGISTRED by ${EMAIL} : ${MOATS} : $(date)
     </body></html>" > ~/.zen/tmp/${MOATS}/http.rep
cat ~/.zen/tmp/${MOATS}/http.rep | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &


end=`date +%s`
echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
exit 0
