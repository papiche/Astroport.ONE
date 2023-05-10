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

PORT=12345
[[ $(zIp) ]] && PORT=45780

    YOU=$(myIpfsApi); ## API of $USER running ipfs
    echo "YOU=$YOU"
    LIBRA=$(myIpfsGw) ## SWARM#0 ENTRANCE URL
    echo "LIBRA=$LIBRA"
    TUBE=$(myTube)
    echo "TUBE=$TUBE"

mkdir -p ~/.zen/tmp/coucou/ ~/.zen/game/players/localhost

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(ps axf --sort=+utime | grep -w 'nc -l -p 1234' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
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
echo "LAUNCHING Astroport  API Server - TUBE : $LIBRA - "
echo
echo "GCHANGE ${myASTROPORT}/?salt=totodu56&pepper=totodu56&g1pub"
echo "OPEN TW ${myASTROPORT}/?salt=totodu56&pepper=totodu56&g1pub=astro"
echo "GCHANGE MESSAGING ${myASTROPORT}/?salt=totodu56&pepper=totodu56&messaging"
echo "CREATE SAME PLAYER : ${myASTROPORT}/?salt=totodu56&pepper=totodu56&g1pub=on&email=totodu56@yopmail.com"
echo
echo "NEW PLAYER : ${myASTROPORT}/?salt=${RANDOM}&pepper=${RANDOM}&g1pub=on&email=astro${RANDOM}@yopmail.com"
echo
echo "BunkerBOX : ${myASTROPORT}/?salt=totodu56&pepper=totodu56&g1pub=_URL_&email=totodu56@yopmail.com"
echo
echo "TESTCRAFT ${myASTROPORT}/?salt=totodu56&pepper=totodu56&testcraft=on&dataid=QmPXhrqQrS1bePKJUPH9cJ2qe4RrNjaJdRXaJzSjxWuvDi"
echo "_________________________________________________________"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

#############################
########## MAIN ###############
#############################
while true; do

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ $(zIp) ]] && PORT=45779
    # ZIP
    if [[ $(zIp) ]]; then
        PORT=$((PORT+1)) && [ ${PORT} -ge 45782 ] && PORT=45780 ## yunohost : OPEN FIREWALL 1234 12345 45780 45781
    else
    # EACH VISITOR RECEIVE COMMAND RESPONSE ON
    ## RANDOM PORT = RESPONSE SOCKET & IPNS SESSION TOKEN
    [ ${PORT} -le 12345 ] && PORT=$((PORT+${RANDOM:0:2})) || PORT=$((PORT-${RANDOM:0:2}))
                ## RANDOM PORT SWAPPINESS AVOIDING COLLISION
    fi

    ## CHECK PORT IS FREE & KILL OLD ONE
    pidportinuse=$(ps axf --sort=+utime | grep -w "nc -l -p ${PORT}" | grep -v -E 'color=auto|grep' | awk '{gsub(/^ +| +$/,"")} {print $0}' | tail -n 1 | cut -d " " -f 1)
    [[ $pidportinuse ]] && kill -9 $pidportinuse && echo "$(date) KILLING LOST $pidportinuse"

    ## CHECK 12345 PORT RUNNING (STATION FoF MAP)
    maprunning=$(ps auxf --sort=+utime | grep -w '_12345.sh' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
    [[ ! $maprunning ]] \
    && echo '(ᵔ◡◡ᵔ) LAUNCHING '${myASTROPORT}:'12345 (ᵔ◡◡ᵔ)' \
    && exec $MY_PATH/_12345.sh &

    ############### ACTIVATE USE ON QUICK IPFS DRIVE
    ### CREATE IPNS KEY - ACTIVATE WHITH ENOUGH BOOTSTRAP
    #~ echo
    #~ ipfs key rm ${PORT} > /dev/null 2>&1
    #~ SESSIONNS=$(ipfs key gen ${PORT})
    #~ echo "IPNS SESSION ${myIPFS}/ipns/$SESSIONNS CREATED"

        ### # USE IT #
        ### MIAM=$(echo ${PORT} | ipfs add -q)
        ### ipfs name publish --allow-offline -t 180s --key=${PORT} /ipfs/$MIAM &

    ###############
    ###############

    # RESET VARIABLES
    CMD="" THAT="" AND="" THIS=""  APPNAME="" WHAT="" OBJ="" VAL=""

    ###############    ###############    ###############    ############### templates/index.http
    # REPLACE myHOST in http response template (fixing next API meeting point)
    echo "$HTTPCORS" >  ~/.zen/tmp/coucou/${MOATS}.myHOST.http
    myHtml >> ~/.zen/tmp/coucou/${MOATS}.myHOST.http
    sed -i -e "s~\"http://127.0.0.1:1234/\"~\"$(myIpfs)\"~g" \
        -e "s~http://${myHOST}:12345~http://${myIP}:${PORT}~g" \
        ~/.zen/tmp/coucou/${MOATS}.myHOST.http

    ############################################################################
    ## SERVE LANDING REDIRECT PAGE ~/.zen/tmp/coucou/${MOATS}.myHOST.http on PORT 1234 (LOOP BLOCKING POINT)
    ############################################################################
    REQ=$(cat $HOME/.zen/tmp/coucou/${MOATS}.myHOST.http | nc -l -p 1234 -q 1 && rm $HOME/.zen/tmp/coucou/${MOATS}.myHOST.http) ## # WAIT FOR 1234 PORT CONTACT

    URL=$(echo "$REQ" | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    HOSTP=$(echo "$REQ" | grep '^Host:' | cut -d ' ' -f2  | cut -d '?' -f2)
    HOST=$(echo "$HOSTP" | cut -d ':' -f 1)

    ## COOKIE RETRIEVAL ##
    COOKIE=$(echo "$REQ" | grep '^Cookie:' | cut -d ' ' -f2)
    echo "COOKIE=$COOKIE"
    ###############    ###############    ###############    ###############
    [[ $XDG_SESSION_TYPE == 'x11' ]] && espeak "Ding" >/dev/null 1>&2 &
    ############################################################################
    [[ $URL == "/test"  || $URL == "" ]] && continue

    echo "************************************************************************* $(date)"
    echo "ASTROPORT 1234 UP & RUNNING.......................... $myASTROPORT"
    echo "${MOATS} NEXT COMMAND DELIVERY PAGE http://$myHOST:${PORT}"

    # echo "URL" > ~/.zen/tmp/coucou/${MOATS}.url ## LOGGING URL

    ############################################################################
    start=`date +%s`

    ############################################################################
    ## / CONTACT
    if [[ $URL == "/" ]]; then
        echo "/ CONTACT :  $HOSTP"
        echo "$HTTPCORS
        DING : ${MOATS} : $(date)"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
        end=`date +%s`
        echo " (‿/‿) $myHOST:$PORT / Execution time was "`expr $end - $start` seconds.
        continue
    fi


    ############################################################################
    # URL DECODING
    ############################################################################

    echo "=================================================="
    echo "GET RECEPTION : $URL"
    arr=(${URL//[=&]/ })

    #####################################################################
    ### /?poule
    #####################################################################
    if [[ ${arr[0]} == "poule" ]]; then
        echo "UPDATING CODE git pull > ~/.zen/tmp/.lastpull"
        echo "$HTTPCORS" > ~/.zen/tmp/.lastpull
        git pull >> ~/.zen/tmp/.lastpull
        rm ~/.zen/game/players/localhost/latest
        (cat ~/.zen/tmp/.lastpull | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
    fi

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
            exec ${MY_PATH}/API/SALT.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" &
        ;;

        "player")
            exec ${MY_PATH}/API/PLAYER.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" &
        ;;

        "qrcode")
            exec ${MY_PATH}/API/QRCODE.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" "${MOATS}" "$COOKIE" &
        ;;

        "")
            echo "$HTTPCORS
            ERROR UNKNOWN $CMD : ${MOATS} : $(date)"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

        ;;

        ### ADD API SCRIPT INTO /API
        *)

            [[ ! -s ${MY_PATH}/API/${CMD^^}.sh ]] \
            && ( echo "$HTTPCORS
            ERROR UNKNOWN $CMD : ${MOATS} : $(date)"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 & ) \
            || exec ${MY_PATH}/API/${CMD^^}.sh "$PORT" "$THAT" "$AND" "$THIS" "$APPNAME" "$WHAT" "$OBJ" "$VAL" &

        ;;

    esac

    end=`date +%s`
    echo " ($CMD) $myHOST:$PORT / Launching time was "`expr $end - $start` seconds.

done
exit 0
