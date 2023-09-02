################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: UPLANET
## Dedicated to OSM2IPFS & UPlanet Client App
# ?uplanet=EMAIL&salt=LAT&pepper=LON
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
[[ ${PLAYER} == "salt"  ]] && PLAYER="@"

[[ ${AND} == "salt" ]] && SALT=${THIS} || SALT=${AND}

[[ ${SALT} == "0" ]] && SALT="0.00"
input_number=${SALT}
if [[ ! $input_number =~ ^-?[0-9]{1,3}(\.[0-9]{1,2})?$ ]]; then
    (echo "$HTTPCORS ERROR - BAD LAT $LAT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0
else
    LAT=${input_number}
fi

[[ ${APPNAME} == "pepper" ]] && PEPPER=${WHAT} || PEPPER=${APPNAME}

[[ ${PEPPER} == "0" ]] && PEPPER="0.00"
input_number=${PEPPER}
if [[ ! $input_number =~ ^-?[0-9]{1,3}(\.[0-9]{1,2})?$ ]]; then
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
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${G1PUB}/_cesium.key  "$LAT" "$LON"
G1PUB=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}/_cesium.key | grep 'pub:' | cut -d ' ' -f 2)
[[ ! ${G1PUB} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - KEYGEN  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
echo "MAPG1PUB : ${G1PUB}"

echo "# CALCULATING UMAP IPNS ADDRESS"
mkdir -p ~/.zen/tmp/${MOATS}/${G1PUB}
ipfs key rm ${G1PUB} > /dev/null 2>&1
rm ~/.zen/tmp/${MOATS}/_ipns.priv 2>/dev/null
${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/_ipns.priv "$LAT" "$LON"
UMAPNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/_ipns.priv )
[[ ! ${UMAPNS} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - UMAPNS  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
echo "UMAPNS : http://ipfs.localhost:8080/ipns/${UMAPNS}"

###################################################
## GET NETWORK CACHE
echo "ipfs --timeout 22s get -o ~/.zen/tmp/${MOATS}/ /ipns/${UMAPNS}/"
ipfs --timeout 22s get -o ~/.zen/tmp/${MOATS}/ /ipns/${UMAPNS}/

####################################### Umap.png
## CREATING Umap_${SALT}_${PEPPER}.png
echo "# OSM2IPFS ~/.zen/tmp/${MOATS}/Umap_${SALT}_${PEPPER}.png"
UMAPGEN="https://ipfs.copylaradio.com/ipfs/QmSaFpSM6ps2pBqYxxLjKJfuigpEo98GNCPdK4PkMXnDaY/Umap.html?southWestLat=$SALT&southWestLon=$PEPPER&deg=0.01"
echo ${UMAPGEN}
echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/Umap.html

## TODO find a better crawling method (pb tiles are not fully loaded before screenshot)
echo "chromium --headless --disable-gpu --screenshot=/tmp/Umap_${SALT}_${PEPPER}.jpg --window-size=1200x1200 \"${UMAPGEN}\""
chromium --headless --disable-gpu --screenshot=/tmp/Umap.jpg --window-size=1200x1200 ${UMAPGEN}
chromium --headless --disable-gpu --screenshot=/tmp/Umap.png --window-size=1200x1200 ${UMAPGEN}

## COPYING FILES FROM ABROAD
cp /tmp/Umap.jpg ~/.zen/tmp/${MOATS}/
cp /tmp/Umap.png ~/.zen/tmp/${MOATS}/
cp ~/.zen/tmp/${PASS}##/G1*.jpg ~/.zen/tmp/${MOATS}/
cp -f ~/.zen/tmp/${PASS}##/${PASS}.jpg ~/.zen/tmp/${MOATS}/G1Card.${PASS}.jpg
ls ~/.zen/tmp/${MOATS}/

echo "<img src=G1Card.${PASS}.jpg \>" > ~/.zen/tmp/${MOATS}/G1Card.html
echo "<img src=G1Visa.${PASS}.jpg \>" > ~/.zen/tmp/${MOATS}/G1Visa.html

## ADD TO FRIENDS
echo "${EMAIL}" >> ~/.zen/tmp/${MOATS}/UFriends.txt


## TAKING CARE OF THE CHAIN
########################################
IPFSROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/* | tail -n 1)
########################################
ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}/_chain 2>/dev/null)
ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}/_moats 2>/dev/null)
[[ ${ZCHAIN} && ${ZMOATS} ]] \
    && cp ~/.zen/tmp/${MOATS}/${G1PUB}/_chain ~/.zen/tmp/${MOATS}/${G1PUB}/_chain.${ZMOATS} \
    && cp ~/.zen/tmp/${MOATS}/${G1PUB}/_HPASS ~/.zen/tmp/${MOATS}/${G1PUB}/_HPASS.${ZMOATS} \
    && echo "UPDATING MOATS"

## UPDATE HPASS last G1Visa PASS
HPASS=$(echo $PASS | sha512sum | cut -d ' ' -f 1)
echo "${HPASS}" > ~/.zen/tmp/${MOATS}/${G1PUB}/_HPASS

## DOES CHAIN CHANGED or INIT ?
[[ ${ZCHAIN} != ${IPFSROOT} || ${ZCHAIN} == "" ]] \
    && echo "${IPFSROOT}" > ~/.zen/tmp/${MOATS}/${G1PUB}/_chain \
    && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${G1PUB}/_moats \
    && IPFSROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"

########################################
echo "Now IPFSROOT is http://ipfs.localhost:8080/ipfs/${IPFSROOT}"

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

## HTTP nc ON PORT RESPONSE
echo "$HTTPCORS
    <html>
    <head>
    <title>[Astroport] :powered: Station</title>
    <meta http-equiv=\"refresh\" content=\"300; url='https://ipfs.copylaradio.com/ipns/${UMAPNS}'\" />
    </head><body>
    <h1>$LAT/$LON UPlanet common blockchain</h1>
    <br>UMAP : <a target=localhost href=http://ipfs.localhost:8080/ipns/${UMAPNS}>http://ipfs.localhost:8080/ipns/${UMAPNS}</a>
    <br>CHAIN : <a target=wan href=https://ipfs.copylaradio.com/ipfs/${IPFSROOT}>https://ipfs.copylaradio.com/ipfs/${IPFSROOT}</a>
    <br> <h2><bold>Your PASS is $PASS</bold></h2>
    <br> Download files containing in their name
    <br> Use G1Station and compatible G1Card QRCode scanner to operate...
    <br>
        <br><br>${EMAIL} REGISTERED : ${MOATS} : $(date)
     </body></html>" > ~/.zen/tmp/${MOATS}/http.rep
cat ~/.zen/tmp/${MOATS}/http.rep | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &


end=`date +%s`
echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
exit 0
