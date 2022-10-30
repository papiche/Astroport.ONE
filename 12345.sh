#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## ASTROPORT API SERVER http://$myIP:1234
## ATOMIC GET REDIRECT TO ONE SHOT WEB SERVICE THROUGH 12345-12445 PORTS
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
[[ ! $myIP ]] && myIP="127.0.1.1"
PORT=12345

    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)

mkdir -p ~/.zen/tmp/123/

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 1234' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "ERROR - API Server Already Running -  http://$myIP:1234/?salt=toto&pepper=toto " && exit 1
echo "_________________________________________________________"
echo "LAUNCHING Astroport  API Server - TEST - "
echo
echo "CREATE GCHANGE + TW http://$myIP:1234/?salt=toto&pepper=toto&g1pub=on&email=fred@astroport.com"
echo "CREATE TW ONLY http://$myIP:1234/?salt=toto&pepper=toto&g1pub=off&email=fred@astroport.com"
echo "OPEN TW R/W http://$myIP:1234/?salt=toto&pepper=toto&official"
echo
echo "GCHANGE MESSAGING http://$myIP:1234/?salt=toto&pepper=toto&messaging"
echo "GCHANGE PLAYER URL http://$myIP:1234/?salt=toto&pepper=toto&g1pub"
echo
echo "TESTCRAFT http://$myIP:1234/?salt=toto&pepper=toto&testcraft=on&nodeid=12D3KooWK1ACupF7RD3MNvkBFU9Z6fX11pKRAR99WDzEUiYp5t8j&dataid=QmZXo87nn34i54HhuMrbuXM5fKXymhV3Zj9exeZDK6s4WD"
echo "_________________________________________________________"

# [[ $DISPLAY ]] && xdg-open "file://$HOME/.zen/Astroport.ONE/templates/instascan.html" 2>/dev/null
# [[ $DISPLAY ]] && xdg-open "http://$myIP:1234" 2>/dev/null

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

while true; do
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    ## CHANGE NEXT PORT (HERE YOU CREATE A SOCKET QUEUE)
    [ $PORT -lt 12345 ] && PORT=$((PORT+${RANDOM:0:3})) || PORT=$((PORT-${RANDOM:0:3}))
                ## RANDOM PORT SWAPPINESS

    SALT=""; PEPPER=""; TYPE=""
    echo "************************************************************************* "
    echo "ASTROPORT API SERVER UP.......................... http://$myIP:1234 PORT"
    echo "$MOATS LANDING PAGE http://$myIP:$PORT"

    # REPLACE myIP in http response template
    sed "s~127.0.0.1:12345~$myIP:$PORT~g" $HOME/.zen/Astroport.ONE/templates/index.http > ~/.zen/tmp/123/${MOATS}.myIP.http
    sed -i "s~127.0.0.1~$myIP~g" ~/.zen/tmp/123/${MOATS}.myIP.http
    sed -i "s~:12345~:$PORT~g" ~/.zen/tmp/123/${MOATS}.myIP.http
    sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/tmp/123/${MOATS}.myIP.http ## NODE PUBLISH HOSTED WHAT'S JSON
    sed -i "s~_HOSTNAME_~$(hostname)~g" ~/.zen/tmp/123/${MOATS}.myIP.http ## HOSTNAME

    ############################################################################
    ## WAITING TO SERVE 1ST LANDING REDIRECT PAGE
    ############################################################################
    URL=$(cat $HOME/.zen/tmp/123/${MOATS}.myIP.http | nc -l -p 1234 -q 1 | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    ############################################################################
    echo "URL" > ~/.zen/tmp/123/${MOATS}.url ## LOGGING URL
    ############################################################################
    start=`date +%s`

    ############################################################################
    ## BARE URL CONTACT - PUBLISH HTML HOMEPAGE (ADD HTTP HEADER)
    if [[ $URL == "/" ]]; then
        echo "API NULL CALL :  http://$myIP:1234"
        echo "___________________________ Preparing register.html"
        echo "HTTP/1.1 200 OK
Server: Astroport
Content-Type: text/html; charset=UTF-8
" > ~/.zen/tmp/123/${MOATS}.index.redirect
sed "s~127.0.0.1~$myIP~g" $HOME/.zen/Astroport.ONE/templates/register.html >> ~/.zen/tmp/123/${MOATS}.index.redirect
sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/tmp/123/${MOATS}.index.redirect
sed -i "s~_HOSTNAME_~$(hostname)~g" ~/.zen/tmp/123/${MOATS}.index.redirect

        cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
        end=`date +%s`
        echo Execution time was `expr $end - $start` seconds.
        continue
    fi
    ############################################################################
    ############################################################################


    echo "=================================================="
    echo "GET RECEPTION : $URL"
    arr=(${URL//[=&]/ })

    # CHECK TYPE
        TYPE=$(urldecode ${arr[4]})
        WHAT=$(urldecode ${arr[5]})

    [[ ${arr[0]} == "" || ${arr[1]} == "" ]] && (echo "ERROR - MISSING DATA" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

    ########## CHECK GET PARAM NAMES
###################################################################################################
###################################################################################################
# API ZERO ## Made In Zion & La Bureautique
    if [[ ${arr[0]} == "salt" ]]; then
        echo ">>>>>>>>>>>>>> Application LaBureautique >><< TYPE = $TYPE <<<<<<<<<<<<<<<<<<<<"
        SALT=$(urldecode ${arr[1]} | xargs);
        [[ ! $SALT ]] && (echo "ERROR - SALT MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        PEPPER=$(urldecode ${arr[3]} | xargs)
        [[ ! $PEPPER ]] && (echo "ERROR - PEPPER MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        TYPE=$(urldecode ${arr[4]} | xargs)
        WHAT=$(urldecode ${arr[5]} | xargs)

        echo "API CALL CREDENTIALS : \"$SALT\" \"$PEPPER\""
        echo "\"$SALT\" \"$PEPPER\"" > ~/.zen/tmp/123/${MOATS}.secret.june

        # CALCULATING G1PUB
        ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/tmp/123/${MOATS}.secret.key  "$SALT" "$PEPPER"
        G1PUB=$(cat ~/.zen/tmp/123/${MOATS}.secret.key | grep 'pub:' | cut -d ' ' -f 2)
        [[ ! $G1PUB ]] && (echo "ERROR - CORE COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        echo "G1PUB : $G1PUB"
        ## CALCULATING IPNS ADDRESS
        ipfs key rm gchange > /dev/null 2>&1
        rm -f ~/.zen/tmp/123/${MOATS}.${G1PUB}.ipns.key
        ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/123/${MOATS}.${G1PUB}.ipns.key "$SALT" "$PEPPER"
        ASTRONAUTENS=$(ipfs key import gchange -f pem-pkcs8-cleartext ~/.zen/tmp/123/${MOATS}.${G1PUB}.ipns.key )
        echo "ASTRONAUTE TW : http://$myIP:8080/ipns/${ASTRONAUTENS}"
        echo
########################################
        ## ARCHIVE TOCTOC WHATS & KEEPS LOGS CLEAN
        mkdir -p ~/.zen/tmp/toctoc/
        ISTHERE=$(ls -t ~/.zen/tmp/toctoc/*.${G1PUB}.ipns.key 2>/dev/null | tail -n 1)
        TTIME=$(echo $ISTHERE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
        if [[ ! $ISTHERE ]]; then
            echo "WHAT 1ST TOCTOC : $MOATS"
            cp ~/.zen/tmp/123/${MOATS}.* ~/.zen/tmp/toctoc/
        else ## KEEP 1ST CONTACT ONLY
            OLDONE=$(ls -t ~/.zen/tmp/123/*.${G1PUB}.ipns.key | tail -n 1)
            DTIME=$(echo $OLDONE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
            [[ $DTIME != $MOATS ]] && rm ~/.zen/tmp/123/$DTIME.*
        fi

## TYPE SLECTION ########################
        # MESSAGING
        if [[ $TYPE == "messaging" ]]; then

            echo "Extracting $G1PUB messages..."
            ~/.zen/Astroport.ONE/tools/timeout.sh -t 3 \
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/123/${MOATS}.secret.key read -n 10 -j  > ~/.zen/tmp/123/messin.${G1PUB}.json
            [[ ! -s ~/.zen/tmp/123/messin.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/123/messin.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/123/messin.${G1PUB}.json

            ~/.zen/Astroport.ONE/tools/timeout.sh -t 3 \
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/123/${MOATS}.secret.key read -n 10 -j -o > ~/.zen/tmp/123/messout.${G1PUB}.json
            [[ ! -s ~/.zen/tmp/123/messout.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/123/messout.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/123/messout.${G1PUB}.json

            echo "Creating messages In/Out JSON ~/.zen/tmp/123/${MOATS}.messaging.json"
            echo '[' > ~/.zen/tmp/123/${MOATS}.messaging.json
            cat ~/.zen/tmp/123/messin.${G1PUB}.json >> ~/.zen/tmp/123/${MOATS}.messaging.json
            echo "," >> ~/.zen/tmp/123/${MOATS}.messaging.json
            cat ~/.zen/tmp/123/messout.${G1PUB}.json >> ~/.zen/tmp/123/${MOATS}.messaging.json
            echo ']' >> ~/.zen/tmp/123/${MOATS}.messaging.json

            ## ADDING HTTP/1.1 PROTOCOL HEADER
            echo "HTTP/1.1 200 OK
Server: Astroport
Content-Type: text/html; charset=UTF-8
" > ~/.zen/tmp/123/${MOATS}.index.redirect
cat ~/.zen/tmp/123/${MOATS}.messaging.json >> ~/.zen/tmp/123/${MOATS}.index.redirect

            cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo Execution time was `expr $end - $start` seconds.
            continue
        fi
        ######################## MESSAGING END

########################################
# G1PUB -> Open Gchange Profile
########################################
        if [[ "$TYPE" == "g1pub" && ${arr[7]} == "" ]]; then
            ## NO EMAIL = REDIRECT TO GCHANGE PROFILE
            sed "s~_TWLINK_~https://www.gchange.fr/#/app/user/$G1PUB/~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/123/${MOATS}.index.redirect
            cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo Execution time was `expr $end - $start` seconds.
            continue
        fi
########################################
#TESTCRAFT=ON nodeid dataid
########################################
        if [[ "$TYPE" == "testcraft" ]]; then
            ## RECORD DATA MADE IN BROWSER (JSON)
            SALT=$(urldecode ${arr[1]} | xargs)
            PEPPER=$(urldecode ${arr[3]} | xargs)
            NODEID=$(urldecode ${arr[7]} | xargs)
            DATAID=$(urldecode ${arr[9]} | xargs)

            mkdir -p ~/.zen/tmp/${IPFSNODEID}/$NODEID/${MOATS}
            echo "TRYING PING $NODEID"
            ipfs --timeout 12s ping $NODEID &

            ## COULD BE A RAW FILE, AN HTML, A JSON
            echo "$WHAT is being sent : json, html, ipfs ? Default on=json"
            echo "TRYING CURL https://ipfs.io/ipfs/$DATAID ~/.zen/tmp/${IPFSNODEID}/$NODEID/${MOATS}data.json"
            curl -m 12 -so ~/.zen/tmp/${IPFSNODEID}/$NODEID/${MOATS}/data.json "https://gateway.ipfs.io/ipfs/$DATAID"

            [[ -s ~/.zen/tmp/${IPFSNODEID}/$NODEID/${MOATS}/data.json ]] && echo "OK data.json" &&\
            [[ ! $(~/.zen/tmp/${IPFSNODEID}/$NODEID/${MOATS}/data.json | jq) ]] && echo "NOT JSON IMPLEMENT : testcraft=html" || \
            ipfs add ~/.zen/tmp/${IPFSNODEID}/$NODEID/${MOATS}/data.json

            echo "TRYIN CAT /ipfs/$DATAID"
            [[ $YOU ]] && ipfs --timeout 12s cat /ipfs/$DATAID > ~/.zen/tmp/${IPFSNODEID}/$NODEID/${MOATS}/data.json &

            ## TODO ADD data.json to PLAYER TW

            echo "OK - $NODEID GONE GET YOUR /ipfs/$DATAID"
            echo "/ipns/${IPFSNODEID}/$NODEID/${MOATS}/ " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo Execution time was `expr $end - $start` seconds.
            continue
        fi

##############################################
# DEFAULT (NO REDIRECT DONE YET) CHECK OFFICIAL GATEWAY
##############################################
        if [[ ! -f ~/.zen/tmp/123/${MOATS}.index.redirect ]]; then
            TWIP=$myIP
            # OFFICIAL Gateway ( increase waiting time ) - MORE SECURE
            if [[ $TYPE == "official" ]]; then

                echo "OFFICIAL latest online TW... $LIBRA ($YOU)"

                [[ $YOU ]] && echo "http://$myIP:8080/ipns/${ASTRONAUTENS} ($YOU)" && ipfs --timeout 12s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/123/${MOATS}.astroindex.html
                [[ ! -s ~/.zen/tmp/123/${MOATS}.astroindex.html ]] && echo "$LIBRA/ipns/${ASTRONAUTENS}" && curl -m 12 -so ~/.zen/tmp/123/${MOATS}.astroindex.html "$LIBRA/ipns/${ASTRONAUTENS}"

                # DEBUG
                # echo "tiddlywiki --load ~/.zen/tmp/123/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'"
                # echo "cat ~/.zen/tmp/miz.json | jq -r .[].secret"

                if [[ -s ~/.zen/tmp/123/${MOATS}.astroindex.html ]]; then
                    tiddlywiki --load ~/.zen/tmp/123/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
                    OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)
                    [[ ! $OLDIP ]] && (echo "501 ERROR - SORRY - YOUR TW IS OUT OF SWARM#0 - CONTINUE " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
                    # LOCKED TW BECOMING NEW GATEWAY
                    if [[ $OLDIP == "_SECRET_" ]]; then
                        echo "_SECRET_ TW PUSHING TW" ## SEND FULL TW
                        sed -i "s~_SECRET_~${myIP}~g" ~/.zen/tmp/123/${MOATS}.astroindex.html
                        echo "HTTP/1.1 200 OK
Server: Astroport
Content-Type: text/html; charset=UTF-8
" > ~/.zen/tmp/123/${MOATS}.index.redirect
                        cat ~/.zen/tmp/123/${MOATS}.astroindex.html >> ~/.zen/tmp/123/${MOATS}.index.redirect
                        cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
                        continue
                    fi
                    # REDIRECTING TO TODAY GATEWAY
                    [[ $OLDIP != $myIP ]] && TWIP=$OLDIP
                    echo "***********  OFFICIAL LOGIN GOES TO $TWIP"
                else
                     (echo "ERROR - NO TW FOUND - ASK FOR VISA" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
                fi
            else
                echo "***** READER MODE - R/W USE OFFICIAL *****  http://$myIP:1234/?salt=$SALT&pepper=$PEPPER&official=on"
            fi

            sed "s~_TWLINK_~http://$TWIP:8080/ipns/${ASTRONAUTENS}~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/123/${MOATS}.index.redirect

        fi
        ## TODO PATCH _SECRET_ myIP STUFF

        ## RESPONDING
        cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
        echo "HTTP 1.1 PROTOCOL DOCUMENT READY ~/.zen/tmp/123/${MOATS}.index.redirect"
        echo "$MOATS -----> PAGE AVAILABLE -----> http://$myIP:${PORT}"
        #echo "${ASTRONAUTENS}" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

        ## CHECK IF ALREADY EXISTING WHAT
        # IF NOT = BATCH CREATE TW
        end=`date +%s`
        echo Execution time was `expr $end - $start` seconds.

    fi ## END IF SALT


###################################################################################################
###################################################################################################
# API ONE : ?salt=PHRASE%20UNE&pepper=PHRASE%20DEUX&g1pub=on&email/elastic=ELASTICID&pseudo=PROFILENAME
    if [[ (${arr[6]} == "email" || ${arr[6]} == "elastic") && ${arr[7]} != "" ]]; then

        [[ $TYPE != "g1pub" ]] && (echo "ERROR - BAD COMMAND $TYPE" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        start=`date +%s`

        SALT=$(urldecode ${arr[1]} | xargs)
        PEPPER=$(urldecode ${arr[3]} | xargs)
        WHAT=$(urldecode ${arr[7]} | xargs)
        PSEUDO=$(urldecode ${arr[9]} | xargs)

        [[ ! $WHAT ]] && (echo "ERROR - MISSING $WHAT FOR WHAT CONTACT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

                if [[ ! $PSEUDO ]]; then
                    PSEUDO=$(echo $WHAT | cut -d '@' -f 1)
                    PSEUDO=${PSEUDO,,}; PSEUDO=${PSEUDO%%[0-9]*}${RANDOM:0:3}
                fi
                # PASS CRYPTING KEY
                PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

            echo "$SALT"
            echo "$PEPPER"

                if [[ ! -d ~/.zen/game/players/$WHAT ]]; then
                    # ASTRONAUT NEW VISA Create VISA.new.sh in background
                    $MY_PATH/tools/VISA.new.sh "$SALT" "$PEPPER" "$WHAT" "$PSEUDO" &
                    echo "OK - ASTRONAUT $PSEUDO VISA CREATION  [$SALT + $PEPPER] ($WHAT)
                    <br> PREPARING YOUR TW - PLEASE 'CHECK' http://$myIP:1234/ " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
                    continue
               else
                    # ASTRONAUT EXISTING WHAT
                    CHECK=$(cat ~/.zen/game/players/$WHAT/secret.june | grep -w "$SALT")
                    [[ $CHECK ]] && CHECK=$(cat ~/.zen/game/players/$WHAT/secret.june | grep -w "$PEPPER")
                    [[ ! $CHECK ]] && (echo "ERROR - WHAT $WHAT ALREADY EXISTS"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
               fi

                 ###################################################################################################
                end=`date +%s`
                echo Execution time was `expr $end - $start` seconds.

    fi

###################################################################################################
###################################################################################################
# API TWO : ?qrcode=G1PUB
    if [[ ${arr[0]} == "qrcode" ]]; then
        ## Astroport.ONE local use QRCODE Contains WHAT G1PUB
        QRCODE=$(echo $URL | cut -d ' ' -f2 | cut -d '=' -f 2 | cut -d '&' -f 1)   && echo "QRCODE : $QRCODE"
        g1pubpath=$(grep $QRCODE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
        WHAT=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

        ## FORCE LOCAL USE ONLY. Remove to open 1234 API
        [[ ! -d ~/.zen/game/players/$WHAT || $WHAT == "" ]] && (echo "ERROR - QRCODE - NO $WHAT ON BOARD !!"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        ## USE SECOND HTTP SERVER TO RECEIVE PASS

        [[ ${arr[2]} == "" ]] && (echo "ERROR - QRCODE - MISSING ACTION"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        ## Demande de copie d'une URL reçue.
        if [[ ${arr[2]} == "url" ]]; then
            wsource="${arr[3]}"
             [[ ${arr[4]} == "type" ]] && wtype="${arr[5]}" || wtype="Youtube"

            ## CREATION TIDDLER "G1Voeu" G1CopierYoutube
            # /.zen/Astropor.ONE/ajouter_media.sh "$(urldecode $wsource)" "$wtype" "$QRCODE" &
            echo "## Insertion tiddler : G1CopierYoutube"
            echo '[
  {
    "title": "'${MOATS}'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$(urldecode $wsource)'",
    "tags": "'CopierYoutube ${WHAT}'"
  }
]
' > ~/.zen/tmp/${WHAT}.${MOATS}.import.json

            ## TODO ASTROBOT "G1AstroAPI" READS ~/.zen/tmp/${WHAT}.${MOATS}.import.json

            (echo "OK - ~/.zen/tmp/${WHAT}.${MOATS}.import.json WORKS IF YOU MAKE THE WISH voeu 'AstroAPI'"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        fi

    fi


done
exit 0
