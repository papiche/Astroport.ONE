################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: QRCODE - ANY/MULTI KEY OPERATIONS
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
################################################################################
## REFRESH STATION & OPEN G1PalPay INTERFACE
################################################################################
if [[ ${QRCODE} == "station" ]]; then

    # rm ~/.zen/tmp/ISTATION ## REMOVE IN PROD

    if [[ ! -s ~/.zen/tmp/ISTATION ]]; then
        ## GENERATE PLAYER G1 TO ZEN ACCOUNTING
        ISTATION=$($MY_PATH/../tools/make_image_ipfs_index_carousel.sh | tail -n 1)
        echo $ISTATION > ~/.zen/ISTATION ## STATION G1WALLET CAROUSEL
    else
        ISTATION=$(cat ~/.zen/ISTATION)
    fi
        ## SHOW G1PALPAY FRONT (IFRAME)
        sed "s~_STATION_~${myIPFS}${ISTATION}/~g" $MY_PATH/../www/G1PalPay/index.html > ~/.zen/tmp/${MOATS}/index.htm
        sed -i "s~http://127.0.0.1:8080~${myIPFS}~g" ~/.zen/tmp/${MOATS}/index.htm

        WSTATION="/ipfs/$(ipfs add -q ~/.zen/tmp/${MOATS}/index.htm)"
        echo "NEW WSTATION ${myIPFS}${WSTATION}"
        echo $WSTATION > ~/.zen/tmp/WSTATION

    ## SEND TO WSTATION PAGE
    sed "s~_TWLINK_~${myIPFS}${WSTATION}/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myIPFS}${WSTATION}"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    ) &
    exit 0
fi
################################################################################
## QRCODE can be ASTRONAUTENS or G1PUB format
################################################################################
## ACCOUNT IPNS FORMAT : CHANGE .current
ASTROPATH=$(grep $QRCODE ~/.zen/game/players/*/.playerns | cut -d ':' -f 1 | rev | cut -d '/' -f 2- | rev  2>/dev/null)
if [[ $ASTROPATH != "" ]]; then
    rm ~/.zen/game/players/.current
    ln -s $ASTROPATH ~/.zen/game/players/.current
    echo "LINKING $ASTROPATH to .current"
    #### SELECT PARRAIN "G1PalPé"

    echo "#>>>>>>>>>>>> # SEND TO G1BILLETS"
    sed "s~_TWLINK_~${myG1BILLET}?montant=0\&style=jeu~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myG1BILLET}"?montant=0\&style=jeu'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0
else

    echo "NOT ON BOARD"
    echo "What is this $QRCODE ?"
    echo "AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9"

fi

################################################################################
## FILTRAGE NON G1 TO IPFS READY QRCODE
ASTROTOIPFS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${QRCODE} 2>/dev/null)
        [[ ! ${ASTROTOIPFS} ]] \
        && echo "INVALID QRCODE : ${QRCODE}" \
        && (echo "$HTTPCORS ERROR - INVALID QRCODE : ${QRCODE}"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
        && exit 1
################################################################################

echo ">>> ${QRCODE} g1_to_ipfs $ASTROTOIPFS"
###########################################""
###########################################
## GET G1PUB OR CURRENT SECRET
###########################################""
MYPLAYERKEY=$(grep ${QRCODE} ~/.zen/game/players/*/secret.dunikey | cut -d ':' -f 1)
[[ ! $MYPLAYERKEY ]] && MYPLAYERKEY="$HOME/.zen/game/players/.current/secret.dunikey"
echo "SELECTES KEY : $(cat MYPLAYERKEY)"
echo

## PARRAIN ID EXTRACTION
###########################################
CURPLAYER=$(cat ~/.zen/game/players/.current/.player)
CURG1=$(cat ~/.zen/game/players/.current/.g1pub)
echo "${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${CURG1}"
CURCOINS=$(~/.zen/Astroport.ONE/tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${CURG1} | cut -d '.' -f 1)
echo "CURRENT PLAYER : $CURCOINS G1"

## FAUCHE
###########################################
if [[ $CURCOINS == "null" ]]; then
echo "NULL"
    sed "s~_TWLINK_~$(cat ~/.zen/ISTATION)~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myIPFSGW}$(cat ~/.zen/ISTATION)"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    ) &
    exit 0
fi

# MOA
###########################################
if [[ ${CURG1} == ${QRCODE} ]]; then

    echo "SAME PLAYER AS CURRENT"

else
# PAS MOA
###########################################
    ## GET VISITOR G1 WANNET AMOUNT : VISITORCOINS
    echo "${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${QRCODE}"
    VISITORCOINS=$(~/.zen/Astroport.ONE/tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${QRCODE} | cut -d '.' -f 1)

    ## PALPE COMBIEN ?
    if [[ $VISITORCOINS == "" || $VISITORCOINS == "null" ]]; then
        # NOUVEAU 1 G1
        PALPE=1
    else
        PALPE=0
    fi

        echo "VISITEUR POSSEDE ${VISITORCOINS} G1"

        ## GET G1 WALLET HISTORY
        $MY_PATH/../tools/jaklis/jaklis.py history -p ${QRCODE} -j > ~/.zen/tmp/${MOATS}/g1history.json

        ## SCAN CCHANGE +
        ~/.zen/Astroport.ONE/tools/timeout.sh -t 10 curl -s ${myDATA}/user/profile/${QRCODE} > ~/.zen/tmp/${MOATS}/gchange.json
        GFOUND=$(cat ~/.zen/tmp/${MOATS}/gchange.json | jq -r '.found')
        [[ $GFOUND == "false" ]] \
        && echo "AUCUN GCHANGE" \
        && sed "s~_TWLINK_~${myGCHANGE}~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect \
        && echo "url='"${myGCHANGE}"'" >> ~/.zen/tmp/${MOATS}/index.redirect \
        && ( cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1) &

        ## CHECK IF RELATED TO CESIUM
        CPUB=$(cat ~/.zen/tmp/${MOATS}/gchange.json | jq -r '._source.pubkey' 2>/dev/null)
        ## SCAN GPUB CESIUM +
        ~/.zen/Astroport.ONE/tools/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${QRCODE} > ~/.zen/tmp/${MOATS}/gplus.json 2>/dev/null
        GCFOUND=$(cat ~/.zen/tmp/${MOATS}/gplus.json | jq -r '.found')
        [[ $GCFOUND == "false" ]] \
        && echo "AUCUN GCPLUS" \
        && sed "s~_TWLINK_~https://demo.cesium.app/#/app/wot/$QRCODE/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect \
        && echo "url='"${myASTRONEF}"'" >> ~/.zen/tmp/${MOATS}/index.redirect \
        && ( cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1) &

        ##### MEMBER ??
        if [[ $CPUB && $CPUB != 'null'  ]]; then

            ## SCAN CPUB CESIUM +
            ~/.zen/Astroport.ONE/tools/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${CPUB} > ~/.zen/tmp/${MOATS}/cplus.json 2>/dev/null
            CCFOUND=$(cat ~/.zen/tmp/${MOATS}/cplus.json | jq -r '.found')

            [[ $CCFOUND == "false" ]] \
            && echo "AUCUN CCPLUS" \
            && sed "s~_TWLINK_~https://monnaie-libre.fr~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect \
            && ( cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1) &

            ## MESSAGE LINKED CESIUM WALLET
            $MY_PATH/../tools/jaklis/jaklis.py -n $myCESIUM -k $MYPLAYERKEY send -d "${QRCODE}" -t "FORGERON" \
            -m "ASTROPORT. G1. FORGERON."

        else

            [[ $GCFOUND != "false" ]] \
            && echo "GPLUS"
            ## EXTRACT GPS ... CONTINUE THE GAME

        fi

    ## DOES CURRENT IS RICHER THAN 100 G1
    if [[ $CURCOINS -gt 1 && $PALPE != 0 ]]; then

            ## LE COMPTE VISITOR EST VIDE
            echo "## PARRAIN $CURPLAYER SEND $PALPE TO ${QRCODE}"
            ## G1 PAYEMENT
            $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/.current/secret.dunikey pay -a ${PALPE} -p ${QRCODE} -c "ASTRO:ZEN_00${PALPE}00" -m

            ## MESSAGE CESIUM +
            $MY_PATH/../tools/jaklis/jaklis.py -n $myCESIUM -k $MYPLAYERKEY send -d "${QRCODE}" -t "CADEAU" \
            -m "ASTRO:${CURPLAYER} VOUS ENVOI ${PALPE} JUNE.
            GAGNEZ PLUS DE JUNE... RELIEZ CE PORTEFEUILLE Cesium SUR https://gchange.fr \
            PUIS REVENEZ SCANNER VOTRE QRCODE"

    fi

     ls ~/.zen/tmp/${MOATS}/

            echo "************************************************************"
            echo "$VISITORCOINS (+ ${PALPE}) JUNE"
            echo "************************************************************"
    ##


fi
###################################################################################################
#                                                                       THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8
###     amzqr  "$myASTROPORT/?qrcode=$G1PUB&junesec=$PASsec&askpass=$HPass&tw=$ASTRONAUTENS" \
###     amzqr "$myASTROPORT/?qrcode=$WISHKEY&junesec=$PASsec&asksalt=$HPass&flux=$VOEUNS&tw=$ASTRONAUTENS" \
###
if [[ $AND == "junesec" ]]; then
echo "♥BOX♥BOX♥BOX♥BOX♥BOX"
echo "MAGIC WORLD ASTRONAUT & WISHES"


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

###     amzqr "$myASTROPORT/?qrcode=$G1FRIEND&star=1" \
###
if [[ $AND == "star" ]]; then

    STAR=$THIS
    echo "WebClient ask to send $STAR star to $QRCODE"
    ## RETURN PAGE with "salt / pepper" API to activate


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


exit 0
