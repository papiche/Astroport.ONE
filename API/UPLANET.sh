#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: UPLANET
## Dedicated to OSM2IPFS & UPlanet Client App
# ?uplanet=EMAIL&zlat=LAT&zlon=LON&g1pub=PASS
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

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"
function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

## CHECK FOR NOT PUBLISHING ALREADY (AVOID IPNS CRUSH)
alreadypublishing=$(pgrep -au $USER -f 'ipfs name publish' | tail -n 1 | xargs | cut -d " " -f 1)
if [[ ${alreadypublishing} ]]; then
     echo "$HTTPCORS ERROR - (╥☁╥ ) - IPFS ALREADY PUBLISHING RETRY LATER"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
     exit 1
fi

## START MANAGING UPLANET LAT/LON & PLAYER
mkdir -p ~/.zen/tmp/${MOATS}/

## GET & VERIFY PARAM
PLAYER=${THAT}
[[ ${PLAYER} == "zlat"  ]] && PLAYER="@"

[[ ${AND} != "zlat" ]] \
    &&  (echo "$HTTPCORS ERROR - BAD PARAMS" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0
[[ ${APPNAME} != "zlon" ]] \
    &&  (echo "$HTTPCORS ERROR - BAD PARAMS" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0

ZLAT=${THIS}
ZLON=${WHAT}
LAT=$(makecoord ${ZLAT})
LON=$(makecoord ${ZLON})

#~ ## RECEIVED VAL ## CAN BE USED TO SELECT TW TEMPLATE
VAL="$(echo ${VAL} | detox --inline)" ## DETOX VAL
############################################
#### TODO USE THIS PARAMETER TO SELECT TW TEMPLATE

### CHECK PLAYER EMAIL
EMAIL="${PLAYER,,}" # lowercase

[[ ! ${EMAIL} ]] \
    && (echo "$HTTPCORS ERROR - MISSING ${EMAIL} FOR UPLANET LANDING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
    &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. \
    &&  exit 0

## CHECK WHAT IS EMAIL
if [[ "${EMAIL}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then

    echo "VALID ${EMAIL} EMAIL OK"

    ## CHECK if PLAYER exists in SWARM
    $($MY_PATH/../tools/search_for_this_email_in_players.sh ${EMAIL}) ## export ASTROTW and more
    echo "export ASTROPORT=${ASTROPORT} ASTROTW=${ASTROTW} ASTROG1=${ASTROG1} ASTROMAIL=${EMAIL} ASTROFEED=${FEEDNS}"

    ## YES = OPEN TW
    [[ ${ASTROTW} ]] \
        && (echo "$HTTPCORS <meta http-equiv=\"refresh\" content=\"0; url='${myIPFS}${ASTROTW}'\" />"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
        && exit 0

else

    echo "BAD EMAIL $EMAIL $LAT $LON"

    ### GET ENV FOR "$LAT" "$LON"
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${LAT}" "${LON}" | tail -n 1)
    REDIR="${myIPFS}${UMAPIPNS}"
    echo "Umap : $REDIR"

    if [[ ${UMAPIPNS} != "/ipns/" ]]; then
        echo "$HTTPCORS <html>BAD EMAIL $EMAIL $LAT $LON <a href=${REDIR}> - OPEN UMAP LINK - </a></html>" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
    else
        echo "$HTTPCORS <html>BAD EMAIL $EMAIL ($LAT $LON)</html>" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
    fi

    exit 0

fi

# UPLANET #############################################
## OCCUPY COMMON CRYPTO KEY CYBERSPACE
## LAT="$LAT" LON="$LON"
######################################################
echo "UMAP = $LAT:$LON"
echo "# GET UMAP ENV"
${MY_PATH}/../tools/getUMAP_ENV.sh "${LAT}" "${LON}"

## ALL TEST PASSED -> CREATE ZENCARD + ASTROID
#~ choose salt pepper with variable words count
PPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)
NPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)

## CREATE ASTRONAUTE TW ON CURRENT ASTROPORT
(
echo VISA.new.sh "${PPASS}" "${NPASS}" "${EMAIL}" "UPlanet" "${VAL}" "${LAT}" "${LON}"
    ##### (☉_☉ ) #######
${MY_PATH}/../RUNTIME/VISA.new.sh "${PPASS}" "${NPASS}" "${EMAIL}" "UPlanet" "${VAL}" "${LAT}" "${LON}" >> ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt

end=`date +%s`
echo "(TW REGISTRATION) Operation time was "`expr $end - $start` seconds.
) &

########################################
## Calculating TW IPNS ADDRESS
TWADD=$(${MY_PATH}/../tools/keygen -t ipfs "${PPASS}" "${NPASS}")

IMGTW=$(${MY_PATH}/../API/AMZQR.sh '0' "${myIPFS}/ipns/${TWADD}" 'et' 'TV' | tail -n 1)


## HTTP nc ON PORT RESPONSE
echo "$HTTPCORS
<html>
<head>
<title>[Astroport] $LAT $LON + ${EMAIL} </title>
<meta http-equiv=\"refresh\" content=\"100; url='${myIPFS}/ipns/${TWADD}#AstroID'\" />
<style>
    #countdown { display: flex; justify-content: center; align-items: center; color: #0e2c4c; font-size: 20px; width: 60px; height: 60px; background-color: #e7d9fc; border-radius: 50%;}
</style>
<style>
    body {
        font-family: Arial, sans-serif;
        text-align: center;
        background-color: #f0f0f0;
        padding: 20px;
    }
    h1 {
        color: #0077cc;
    }
    h2 {
        color: #333;
    }
    img {
        cursor: pointer;
    }
</style>
</head><body>
<h1>UPlanet Registration</h1>
${EMAIL} (⌐■_■)<br>
<br>Check your mailbox ! Relevez votre boite mail !
<hr>
<h2><a target=\"_new\" href=\"${myIPFS}/ipns/${TWADD}\">TW5</a></h2>
<h1><center><div id='countdown'></div></center></h1>
<script>
var timeLeft = 90;
var elem = document.getElementById('countdown');
var timerId = setInterval(countdown, 1000);

function countdown() {
    if (timeLeft == -1) {
        clearTimeout(timerId);
        doSomething();
    } else {
        elem.innerHTML = timeLeft + ' s';
        timeLeft--;
    }
}
</script>
---
<br>( ⚆_⚆) TW5 MOBILE APP<br>
<img src='${myIPFSGW}${IMGTW}'\>
<br>CONSOLE<br>
$(cat ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt 2>/dev/null)
<br>(☉_☉ ) use above credentials... utilisez les identiants ci-dessus<br>
<br><br>${EMAIL} REGISTERED on UPlanet UMAP($LAT/$LON) : ${MOATS} : $(date)
</body>
</html>" > ~/.zen/tmp/${MOATS}/http.rep

(
cat ~/.zen/tmp/${MOATS}/http.rep | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
end=`date +%s`
echo "(UPLANET) Operation time was "`expr $end - $start` seconds.
) &

exit 0
