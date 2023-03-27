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

start=`date +%s`

PORT=$1 THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9 COOKIE=$10
### transfer variables according to script
QRCODE=$THAT
TYPE=$WHAT

echo "COOKIE : $COOKIE"

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
################################################################################
## REFRESH STATION & OPEN G1PalPay INTERFACE
###############################################################################
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
        sed -i "s~http://astroport.localhost:1234~${myASTROPORT}~g" ~/.zen/tmp/${MOATS}/index.htm

        WSTATION="/ipfs/$(ipfs add -q ~/.zen/tmp/${MOATS}/index.htm)"
        echo $WSTATION > ~/.zen/tmp/WSTATION
        end=`date +%s`
        echo "NEW WSTATION ${myIPFS}${WSTATION} Execution time was "`expr $end - $start` seconds.
    ## SEND TO WSTATION PAGE
    sed "s~_TWLINK_~${myIPFS}${WSTATION}/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myIPFS}${WSTATION}"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0
fi

################################################################################
## MODE PGP ENCRYPTED QRCODE
# http://127.0.0.1:1234/?qrcode=-----BEGIN%20PGP%20MESSAGE-----~~jA0ECQMCWZ%2BOT%2FstJiz%2B0koBBzdybjOYmFHlYSdta6YsO4VMPC%2BEL1tinYpWdIh1~q%2FIZGCu3ZXUK%2FfDmYED%2BKh0vzAJ%2ByBOjSAGaAFfigZYrAhNAPDP8jzZ14w%3D%3D~%3DN1Dz~-----END%20PGP%20MESSAGE-----~&pass=coucou
################################################################################
if [[ ${QRCODE:0:5} == "-----" ]]; then
   echo ${QRCODE}
   PASS=$(urldecode $THIS)
   echo "## THIS IS A PGP ENCRYPTED QRCODE LOOK - PASS $PASS -"

    if [[ $PASS != "" ]]; then
        urldecode ${QRCODE} | tr '~' '\n' | tr '_' '+' > ~/.zen/tmp/${MOATS}/disco.aes
        sed -i '$ d' ~/.zen/tmp/${MOATS}/disco.aes
        echo ~/.zen/tmp/${MOATS}/disco.aes
        cat ~/.zen/tmp/${MOATS}/disco.aes | gpg -d --passphrase "$PASS" --batch > ~/.zen/tmp/${MOATS}/disco
        echo "DISCO"
        cat ~/.zen/tmp/${MOATS}/disco
    else
        echo "PASS MISSING" > ~/.zen/tmp/${MOATS}/disco
    fi

    echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}/index.redirect
    cat ~/.zen/tmp/${MOATS}/disco  >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0
fi

################################################################################
## MODE G1VOEU : RETURN WISHNS - image carousel links -
################################################################################
if [[ ${QRCODE:0:2} == "G1" && ${AND} == "tw" ]]; then
    APPNAME="G1Voeu"
    VOEU=${QRCODE}
    ASTROPATH=$(grep -r ${THIS} ~/.zen/game/players/*/ipfs/moa | grep ${QRCODE} | cut -d ':' -f 1 | rev | cut -d '/' -f 2- | rev  2>/dev/null)
    echo $ASTROPATH

    INDEX=$ASTROPATH/index.html
    echo $INDEX
    if [[ -s  ${INDEX} ]]; then
        tiddlywiki --load ${INDEX} --output ~/.zen/tmp --render '.' "${MOATS}.g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'
        cat ~/.zen/tmp/${MOATS}.g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/${MOATS}.g1wishes.txt
        while read WISH
        do
            [[ ${WISH} == "" || ${WISH} == "null" ]] && echo "BLURP. EMPTY WISH" && continue
            WISHNAME=$(cat ~/.zen/tmp/${MOATS}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .title')
            WISHNS=$(cat ~/.zen/tmp/${MOATS}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .wishns')
            echo "${WISHNAME} : ${WISHNS} "
            [[ "G1${WISHNAME}" == "$VOEU" ]] \
            && echo "FOUND" \
            && LINK=${myIPFS}${WISHNS} \
            && break

        done < ~/.zen/tmp/${MOATS}.g1wishes.txt
    fi

    ## REDIRECT TO G1VOEU IPNS ADDRESS
    [[ $LINK == "" ]] && LINK="$myIPFS/ipfs/QmWUZr62SpriLPuqauMbMxvw971qnu741hV8EhrHmKF2Y4" ## 404 LOST IN CYBERSPACE
    echo "#>>> DISPLAY WISHNS >>>> # $VOEU : $LINK"
    sed "s~_TWLINK_~${LINK}~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${LINK}"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0
fi

################################################################################
## QRCODE can be ASTRONAUTENS or G1PUB format
################################################################################
## QRCODE IS IPNS FORMAT : CHANGE .current AND MAKE G1BILLETS
ASTROPATH=$(grep -r $QRCODE  ~/.zen/game/players/*/ipfs/moa | tail -n 1 | cut -d ':' -f 1 | rev | cut -d '/' -f 2- | rev  2>/dev/null)
if [[ $ASTROPATH != "" && $APPNAME == "" ]]; then

    PLAYER=$(echo $ASTROPATH | rev | cut -d '/' -f 3 | rev)

    rm ~/.zen/game/players/.current
    ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current
    echo "LINKING $PLAYER to .current"
    #### SELECT PARRAIN "G1PalPay"

    echo "#>>>>>>>>>>>> # REDIRECT TO CREATE G1BILLETS"
    sed "s~_TWLINK_~${myG1BILLET}?montant=0\&style=$PLAYER~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myG1BILLET}"?montant=0\&style=$PLAYER'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
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
[[ $MYPLAYERKEY == "" ]] && MYPLAYERKEY="$HOME/.zen/game/players/.current/secret.dunikey"
echo "SELECTED KEY : $(cat $MYPLAYERKEY)"
echo

## PARRAIN ID EXTRACTION
###########################################
CURPLAYER=$(cat ~/.zen/game/players/.current/.player)
CURG1=$(cat ~/.zen/game/players/.current/.g1pub)
echo "${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${CURG1}"
~/.zen/Astroport.ONE/tools/COINScheck.sh ${CURG1} > ~/.zen/tmp/curcoin
cat ~/.zen/tmp/curcoin
CURCOINS=$(cat ~/.zen/tmp/curcoin | tail -n 1)
echo "CURRENT PLAYER : $CURCOINS G1"

## WALLET JAMAIS SERVI
###########################################
if [[ $CURCOINS == "null" ]]; then
echo "NULL. PLEASE CHARGE. REDIRECT TO WSTATION HOME"
    sed "s~_TWLINK_~$(cat ~/.zen/WSTATION)~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myIPFSGW}$(cat ~/.zen/WSTATION)"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0
fi

# DETECT WALLET EVOLUTION
###########################################
if [[ ${CURG1} == ${QRCODE} ]]; then

    echo "SAME PLAYER AS CURRENT"

else
# PAS MOA
###########################################
    ## GET VISITOR G1 WANNET AMOUNT : VISITORCOINS
    echo "COINScheck : ${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${QRCODE}"
    VISITORCOINS=$(~/.zen/Astroport.ONE/tools/COINScheck.sh ${QRCODE} | tail -n 1)

    ## PALPE COMBIEN ?
    if [[ $VISITORCOINS == "" || $VISITORCOINS == "null" ]]; then
        # REGLER "DUREE DE VIE" : PALPE / WISH_NB / DAY
        PALPE=10
    else
        PALPE=0
    fi

        echo "VISITEUR POSSEDE ${VISITORCOINS} G1"

        ## GET G1 WALLET HISTORY
        [[ ! -s ~/.zen/tmp/coucou/${QRCODE}.g1history.json ]] \
        && ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 $MY_PATH/../tools/jaklis/jaklis.py history -p ${QRCODE} -j > ~/.zen/tmp/coucou/${QRCODE}.g1history.json &

        ## SCAN GCHANGE +
        [[ ! -s ~/.zen/tmp/coucou/${QRCODE}.gchange.json ]] \
        && ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 curl -s ${myDATA}/user/profile/${QRCODE} > ~/.zen/tmp/coucou/${QRCODE}.gchange.json &

        GFOUND=$(cat ~/.zen/tmp/coucou/${QRCODE}.gchange.json | jq -r '.found')
        echo "GFOUND=$GFOUND"
        [[ $GFOUND == "false" ]] \
        && echo "NO GCHANGE YET. REDIRECT" \
        && sed "s~_TWLINK_~${myGCHANGE}~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect \
        && echo "url='"${myGCHANGE}"'" >> ~/.zen/tmp/${MOATS}/index.redirect \
        && ( cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1) &

        ## SCAN CESIUM +
        [[ ! -s ~/.zen/tmp/coucou/${QRCODE}.gplus.json ]] \
        && ~/.zen/Astroport.ONE/tools/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${QRCODE} > ~/.zen/tmp/coucou/${QRCODE}.gplus.json 2>/dev/null &

        GCFOUND=$(cat ~/.zen/tmp/coucou/${QRCODE}.gplus.json | jq -r '.found')
        echo "GCFOUND=$GCFOUND"
        [[ $GCFOUND == "false" ]] \
        && echo "AUCUN GCPLUS : PAS DE CESIUM POUR CLEF GCHANGE" \
        && sed "s~_TWLINK_~https://demo.cesium.app/#/app/wot/$QRCODE/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect \
        && echo "url='"${myASTRONEF}"'" >> ~/.zen/tmp/${MOATS}/index.redirect \
        && ( cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1) &

        ## CHECK IF GCHANGE IS LINKED TO "A DECLARED CESIUM"
        CPUB=$(cat ~/.zen/tmp/coucou/${QRCODE}.gchange.json | jq -r '._source.pubkey' 2>/dev/null)
        echo "CPUB=$CPUB"
        ## SCAN GPUB CESIUM +

        ##### DO WE HAVE A MEMBER LINKED ??
        if [[ $CPUB && $CPUB != 'null' && $CPUB != $QRCODE ]]; then

            ## SCAN CPUB CESIUM +
            [[ ! -s ~/.zen/tmp/coucou/${QRCODE}.cplus.json ]] \
            && ~/.zen/Astroport.ONE/tools/timeout.sh -t 10 curl -s ${myCESIUM}/user/profile/${CPUB} > ~/.zen/tmp/coucou/${QRCODE}.cplus.json 2>/dev/null &

            CCFOUND=$(cat ~/.zen/tmp/coucou/${QRCODE}.cplus.json | jq -r '.found')

            [[ $CCFOUND == "false" ]] \
            && echo "AUCUN CCPLUS : MEMBRE LIE" \
            && sed "s~_TWLINK_~https://monnaie-libre.fr~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect \
            && ( cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1) &

            ## MESSAGE LINKED CESIUM WALLET
            $MY_PATH/../tools/jaklis/jaklis.py -n $myCESIUM -k $MYPLAYERKEY send -d "${CPUB}" -t "COUCOU" \
            -m "VOUS AVEZ ${VISITORCOINS} G1 SUR VOTRE COMPTE ${QRCODE}"

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
            $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/.current/secret.dunikey pay -a ${PALPE} -p ${QRCODE} -c "ASTRO:${RANDOM}:ZEN_00${PALPE}00" -m

            ## MESSAGE CESIUM +
            $MY_PATH/../tools/jaklis/jaklis.py -n $myCESIUM -k $MYPLAYERKEY send -d "${QRCODE}" -t "CADEAU" \
            -m "ASTRO:${CURPLAYER} A ENVOYE ${PALPE} JUNE.
            GAGNEZ PLUS DE JUNE... INSCRIVEZ VOUS SUR GCHANGE  https://gchange.fr \
            PUIS SCANNEZ VOTRE QRCODE SUR UNE STATION ASTROPORT"

            ## SEND ONE ★ (NEXT STEP GCHANGE)
            my_star_level=1
            echo "★ SENDING $my_star_level STAR(s) ★"
            $MY_PATH/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey stars -p ${QRCODE} -n $my_star_level

    fi

     ls ~/.zen/tmp/${MOATS}/

            echo "************************************************************"
            echo "$VISITORCOINS (+ ${PALPE}) JUNE"
            echo "************************************************************"
    ##


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
            ## INSERT IN TW

            (echo "$HTTPCORS OK - ~/.zen/tmp/${WHAT}.${MOATS}.import.json WORKS IF YOU MAKE THE WISH voeu 'AstroAPI'"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 0

        else

            (echo "$HTTPCORS ERROR - ${AND} - ${THIS} UNKNOWN"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

        fi
fi


exit 0
