################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: SALT & PEPPER
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"

start=`date +%s`

PORT=$1 THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9
### transfer variables according to script
QRCODE=$THAT
TYPE=$WHAT

## GET TW
mkdir -p ~/.zen/tmp/${MOATS}/

if [[ ${QRCODE} == "station" ]]; then
    ## GENERATE PLAYER G1 TO ZEN ACCOUNTING
    ISTATION=$($MY_PATH/../tools/make_image_ipfs_index_carousel.sh | tail -n 1)
    sed "s~_TWLINK_~${myIPFSGW}${ISTATION}/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myIPFSGW}${ISTATION}"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    ) &

    exit 0
fi

## FILTRAGE NON G1 TO IPFS READY QRCODE
ASTRONAUTENS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${QRCODE})
        [[ ! ${ASTRONAUTENS} ]] \
        && (echo "$HTTPCORS ERROR - ASTRONAUTENS !!"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
        && exit 1

echo ">>> ${QRCODE} g1_to_ipfs $ASTRONAUTENS"

## SEND MESSAGE TO CESIUM+ ACCOUNT (ME or .current)
MYPLAYERKEY=$(grep ${QRCODE} ~/.zen/game/players/*/secret.dunikey | cut -d ':' -f 1)
[[ ! $MYPLAYERKEY ]] && MYPLAYERKEY="$HOME/.zen/game/players/.current/secret.dunikey"

## COUCOU MSG
## CCHANGE +
$MY_PATH/../tools/jaklis/jaklis.py -n $myGCHANGE -k $MYPLAYERKEY send -d "${QRCODE}" -t "COUCOU" -m "ASTROPORT CONTACT"
## CESIUM +
$MY_PATH/../tools/jaklis/jaklis.py -n $myCESIUM -k $MYPLAYERKEY send -d "${QRCODE}" -t "COUCOU" -m "ASTROPORT CONTACT"

###################################################################################################
#                                                                       THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8
###     amzqr  "$myASTROPORT/?qrcode=$G1PUB&junesec=$PASsec&askpass=$HPass&tw=$ASTRONAUTENS" \
###     amzqr "$myASTROPORT/?qrcode=$WISHKEY&junesec=$PASsec&asksalt=$HPass&flux=$VOEUNS&tw=$ASTRONAUTENS" \
###
if [[ $AND == "junesec" ]]; then
echo "♥BOX♥BOX♥BOX♥BOX♥BOX"
echo "MAGIC WORLD ASTRONAUT & WISHES"

        COINS=$(~/.zen/Astroport.ONE/tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${QRCODE})
        [[ $COINS == "" || $COINS == "null" ]] \
        && $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/.current/secret.dunikey pay -a 50 -p ${QRCODE} -c "ASTRO:PASSPORT_ACTIVATION" -m
        echo "************************************************************"
        echo "$COINS (+ 50 JUNE IF EMPTY) "
        echo "************************************************************"

    if [[ $APPNAME == "askpass" ]]; then
        echo ">> ASTRONAUT QRCODE $APPNAME"
        ENDCODED="$THIS"
        HPASS="$WHAT"
        TW="/ipns/$VAL"


    fi

    if [[ $APPNAME == "asksalt" ]]; then
        echo ">> WISH QRCODE $APPNAME"
        ENDCODED="$THIS"
        HSALT="$WHAT"
        FLUX="/ipns/$VAL"

    fi

fi

## TODO MAGIC QRCODE RX / TX
###################################################################################################
# API TWO : ?qrcode=G1PUB&url=____&type=____

if [[ $AND == "url" ]]; then
        URL=$THIS

        if [[ $URL ]]; then

        ## Astroport.ONE local use QRCODE Contains ${WHAT} G1PUB
        g1pubpath=$(grep $QRCODE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
        PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

        ## FORCE LOCAL USE ONLY. Remove to open 1234 API
        [[ ! -d ~/.zen/game/players/${PLAYER} || ${PLAYER} == "" ]] \
        && espeak "nope" \
        && (echo "$HTTPCORS ERROR - QRCODE - NO ${PLAYER} ON BOARD !!"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
        && exit 1

        ## Demande de copie d'une URL reçue.
             [[ ${TYPE} ]] && CHOICE="${TYPE}" || CHOICE="Youtube"

            ## CREATION TIDDLER "G1Voeu" G1CopierYoutube
            # CHOICE = "Video" Page MP3 Web
            ~/.zen/Astropor.ONE/ajouter_media.sh "${URL}" "$PLAYER" "$CHOICE" &

            echo "## Insertion tiddler : G1CopierYoutube"
            echo '[
  {
    "title": "'${MOATS}'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'${URL}'",
    "tags": "'CopierYoutube ${WHAT}'"
  }
]
' > ~/.zen/tmp/${WHAT}.${MOATS}.import.json

            ## TODO ASTROBOT "G1AstroAPI" READS ~/.zen/tmp/${WHAT}.${MOATS}.import.json

            (echo "$HTTPCORS OK - ~/.zen/tmp/${WHAT}.${MOATS}.import.json WORKS IF YOU MAKE THE WISH voeu 'AstroAPI'"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 0

        else

            (echo "$HTTPCORS ERROR - ${AND} - ${THIS} UNKNOWN"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

        fi
fi
