#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## ASTROPORT API SERVER http://${myHOST}:1234
## ATOMIC GET REDIRECT TO ONE SHOT WEB SERVICE THROUGH PORTS
## ASYNCHRONOUS IPFS API
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

PORT=45779

    YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER") ## $USER running ipfs
    echo "YOU=$YOU"
    LIBRA=$(myIpfsGw) ## SWARM#0 ENTRANCE URL
    echo "LIBRA=$LIBRA"
    TUBE=$(myTube)
    echo "TUBE=$TUBE"
    export PATH=$HOME/.astro/bin:$HOME/.local/bin:$PATH
    echo "PATH=$PATH"

mkdir -p ~/.zen/tmp ~/.zen/game/players/localhost # ~/.zen & myos compatibility

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(pgrep -au $USER -f 'nc -l -p 1234 -q 1' | head -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "RESTARTING" && kill -9 $ncrunning
## NOT RUNNING TWICE

# Some client needs to respect that
HTTPCORS='HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8
'
echo "_____________________ $PORT ________________________________ $(date)"
echo "LAUNCHING Astroport  API Server : ASTROPORT : ${myASTROPORT}"
echo
echo "_________________________________________________________"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

#############################
########## MAIN ###############
#############################
while true; do

    ########################################################
    ## /ipfs/QmQ9MdCEY1aMmpxBqZKcHTLafRxRFeK1Ku1DES1LCPaimA
    ## TODO: STOP API ACCESS AFTER 20H12

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}
    [[ ${myIP} == "" ]] && source "${MY_PATH}/tools/my.sh" ## correct 1st run DHCP latency

    PORT=$(cat ~/.zen/tmp/PORT) || PORT=45779

    PORT=$((PORT+1)) && [ ${PORT} -ge 45791 ] && PORT=45780 ## WAN ASTROPORT 45780 45781 ... 45790

    # .env HOST
    if [[ ${HOST} != "" ]]; then
        [ ${PORT} -ge 45783 ] && PORT=45780 ## ♥Box nginx-proxy SSL 1234 /12345 /45780 /45781 /45782
    fi ## Use "nginx proxy manager" for SSL

    echo ${PORT} > ~/.zen/tmp/PORT
    ## CHECK PORT IS FREE & KILL OLD ONE
    echo "$HOST SEARCHING FOR PORT ${PORT}"
    pgrep -au $USER -f "nc -l -p ${PORT} -q 1"
    pidportinuse=$(pgrep -au $USER -f "nc -l -p ${PORT} -q 1" | head -n 1 | xargs | cut -d " " -f 1)
    [[ $pidportinuse ]] && kill -9 $pidportinuse && echo "$(date) KILLING LOST $pidportinuse"

    ### START MAP STATION 12345
    ## CHECK 12345 PORT RUNNING (STATION FoF MAP)
    maprunning=$(pgrep -au $USER -f '_12345.sh' | tail -n 1 | xargs | cut -d " " -f 1)
    [[ ! $maprunning ]] \
    && echo '(ᵔ◡◡ᵔ) MAP LAUNCHING http://'${myIP}':12345 (ᵔ◡◡ᵔ)' \
    && exec $MY_PATH/_12345.sh &

    ###############    ###############    ###############    ###############
    # THIS SCRIPT STORES $i PARAMETER IN
    # THOSE VARIABLES
    CMD="" THAT="" AND="" THIS="" APPNAME="" WHAT="" OBJ="" VAL=""

    ###############    ###############    ###############    ############### templates/index.http
    # REPLACE myHOST in http response template (fixing next API meeting point)
    echo "$HTTPCORS" >  ~/.zen/tmp/${MOATS}/${PORT}.myHOST.http
    myHtml >> ~/.zen/tmp/${MOATS}/${PORT}.myHOST.http

    ## REPLACE RESPONSE PORT
    sed -i -e "s~http://127.0.0.1:12345~http://127.0.0.1:${PORT}~g" \
        ~/.zen/tmp/${MOATS}/${PORT}.myHOST.http

    ## WAN REDIRECT TO HTTPS:// + /${PORT}
    [[ -z "$isLAN" || $HOST != "" ]] \
        && sed -i -e "s~http://127.0.0.1:${PORT}~https://${HOST}/${PORT}~g" ~/.zen/tmp/${MOATS}/${PORT}.myHOST.http \
        && echo "WAN STATION"

#### >>> TODO ADD zDomain to manage SSL FRONT PORTAL
    [ -n "$(zIp)" ]\
        && sed -i -e "s~http://127.0.0.1:${PORT}~http://$(zIp):${PORT}~g" ~/.zen/tmp/${MOATS}/${PORT}.myHOST.http \
        && echo "COEUR BOX LAN 2 WAN STATION"

    ## UPLANET HOME LINK REPLACEMENT
    sed -i -e "s~https://qo-op.com~${myUPLANET}~g" ~/.zen/tmp/${MOATS}/${PORT}.myHOST.http

    ############################################################################
    ## SERVE LANDING REDIRECT PAGE ~/.zen/tmp/${MOATS}/${PORT}.myHOST.http on PORT 1234 (LOOP BLOCKING POINT)
    ############################################################################
    ###############    ###############    ###############    ############### WAIT FOR
    ###############    ###############    ###############    ############### 1234 KNOC
    REQ=$(cat $HOME/.zen/tmp/${MOATS}/${PORT}.myHOST.http | nc -l -p 1234 -q 1 && rm $HOME/.zen/tmp/${MOATS}/${PORT}.myHOST.http) ## # WAIT FOR 1234 PORT CONTACT
    ###############    ###############    ###############    ############### KNOC !!
    ###############    ###############    ###############    ###############
    echo "REQ=$REQ"
    URL=$(echo "$REQ" | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    HOSTP=$(echo "$REQ" | grep '^Host:' | cut -d ' ' -f2  | cut -d '?' -f2)
    AGENT=$(echo "$REQ" | grep '^User-Agent:') ### TODO : BAN LESS THAN 3 SEC REQUEST
    HOST=$(echo "$HOSTP" | cut -d ':' -f 1)

    ## COOKIE RETRIEVAL ##
    COOKIE=$(echo "$REQ" | grep '^Cookie:' | cut -d ' ' -f2)
    echo "COOKIE=$COOKIE"
    ###############    ###############    ###############    ###############
    [[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && espeak "Dong" >/dev/null 1>&2 &
    ############################################################################
    [[ $URL == "/test" ]] && continue ## DROP /test

    echo "******* ${MOATS}  ********************************** $(date)"
    echo "ASTROPORT 1234 UP & RUNNING // API : $myASTROPORT //  IPFS : $myIPFS"
    echo "NEXT COMMAND DELIVERY PAGE http://$myHOST:${PORT}"

    ############################################################################
    start=`date +%s`
    ############################################################################
    ## / CONTACT
    if [[ $URL == "/" || $URL == "" ]]; then
        echo "/ CONTACT :  $HOSTP"

        if [ -z "$isLAN"  || $HOST != "" ]; then
        echo ${HOST}/${PORT}
        mySalt | \
            sed "s~http://127.0.0.1:12345~http://${myIP}:${PORT}~g" | \
            sed "s~http://${myIP}:${PORT}~https://${HOST}/${PORT}~g" | \
            sed  "s~https://qo-op.com~${myUPLANET}~g" | \
            ( nc -l -p ${PORT} -q 1 > /dev/null 2>&1 && echo " (‿/‿) $PORT CONSUMED in "`expr $(date +%s) - $start`" seconds." ) &
        else
        mySalt | \
            sed "s~http://127.0.0.1:12345~http://${myIP}:${PORT}~g" | \
            sed  "s~https://qo-op.com~${myUPLANET}~g" | \
            ( nc -l -p ${PORT} -q 1 > /dev/null 2>&1 && echo " (‿/‿) $PORT CONSUMED in "`expr $(date +%s) - $start`" seconds." ) &
        fi

        continue
    fi


    ############################################################################
    # URL DECODING
    ############################################################################

    echo "=================================================="
    echo "GET RECEPTION : $URL"
    arr=(${URL//[=&]/ })

    #~ #####################################################################
    #~ ### /?poule
    #~ #####################################################################
    #~ if [[ ${arr[0]} == "poule" ]]; then
        #~ echo "UPDATING CODE git pull > ~/.zen/tmp/.lastpull"
        #~ echo "$HTTPCORS" > ~/.zen/tmp/.lastpull
        #~ cd ~/.zen/Astroport.ONE
        #~ git pull >> ~/.zen/tmp/.lastpull
        #~ rm ~/.zen/game/players/localhost/latest
        #~ (cat ~/.zen/tmp/.lastpull | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
    #~ fi

########## CHECK GET PARAM NAMES
###################################################################################################
    [[ ${arr[0]} == "" || ${arr[1]} == "" ]] && (echo "$HTTPCORS ERROR - MISSING DATA" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

    CMD=$(urldecode ${arr[0]} | xargs)
    THAT=$(urldecode ${arr[1]} | xargs)
    # SPLIT URL INTO

    AND=$(urldecode ${arr[2]} | xargs)
    THIS=$(urldecode ${arr[3]} | xargs)

    APPNAME=$(urldecode ${arr[4]} | xargs)
    WHAT=$(urldecode ${arr[5]} | xargs)

    OBJ=$(urldecode ${arr[6]} | xargs)
    VAL=$(urldecode ${arr[7]} | xargs)

    echo "===== COMMAND = $CMD ====="
    echo "CMD=THAT&AND=THIS&APPNAME=WHAT&OBJ=VAL"
    echo "$CMD=$THAT&$AND=$THIS&$APPNAME=$WHAT&$OBJ=$VAL"

    case $CMD in
        "salt")
            exec ${MY_PATH}/API/SALT.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE" &
        ;;

        "player")
            exec ${MY_PATH}/API/PLAYER.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE" &
        ;;

        "qrcode")
            exec ${MY_PATH}/API/QRCODE.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE" &
        ;;

        "uplanet")
            echo ${MY_PATH}/API/UPLANET.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE"
            exec ${MY_PATH}/API/UPLANET.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE" &
        ;;

        "amzqr")
            exec ${MY_PATH}/API/AMZQR.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE" &
        ;;

        "")
            echo "$HTTPCORS
            ERROR UNKNOWN $CMD : ${MOATS} : $(date)"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

        ;;

        ### ADD API SCRIPT INTO /API
        ## FORGE YOUR HTTPCORS FOR CLIENT ONLY SECURITTY
        *)

            [[ ! -s ${MY_PATH}/API/${CMD^^}.sh ]] \
            && ( echo "$HTTPCORS
            ERROR UNKNOWN $CMD : ${MOATS} : $(date)"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 & ) \
            || exec ${MY_PATH}/API/${CMD^^}.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE" &

        ;;

    esac

    end=`date +%s`
    echo " ($CMD) $myHOST:$PORT / Launching time was "`expr $end - $start` seconds.

done
exit 0
