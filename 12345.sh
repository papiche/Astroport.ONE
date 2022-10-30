#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## ASTROPORT API SERVER http://$myIP:1234
## ATOMIC GET REDIRECT TO ONE SHOT WEB SERVICE THROUGH PORTS
## ASYNCHRONOUS IPFS API
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
[[ ! $myIP ]] && myIP="127.0.1.1"
PORT=12345

    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1); ## $USER running ipfs
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2) ## SWARM#0 ENTRANCE URL

mkdir -p ~/.zen/tmp/${IPFSNODEID}/

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 1234' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "ERROR - API Server Already Running -  http://$myIP:1234/?salt=totodu56&pepper=totodu56 " && exit 1
## NOT RUNNING TWICE

echo "_________________________________________________________"
echo "LAUNCHING Astroport  API Server - TEST - "
echo
echo "CREATE GCHANGE + TW http://$myIP:1234/?salt=totodu56&pepper=totodu56&g1pub=on&email=fred@astroport.com"
echo
echo "OPEN TW R/W http://$myIP:1234/?salt=totodu56&pepper=totodu56&official"
echo
echo "GCHANGE MESSAGING http://$myIP:1234/?salt=totodu56&pepper=totodu56&messaging"
echo "GCHANGE PLAYER URL http://$myIP:1234/?salt=totodu56&pepper=totodu56&g1pub"
echo
echo "TESTCRAFT http://$myIP:1234/?salt=totodu56&pepper=totodu56&testcraft=on&nodeid=12D3KooWK1ACupF7RD3MNvkBFU9Z6fX11pKRAR99WDzEUiYp5t8j&dataid=QmZgfoCtJ1KwoBNUQepM1xhdmdU4x34ZxpLMtLqY43jvXV/g1wishtiddlers.json"
echo "_________________________________________________________"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

while true; do
    start=`date +%s`

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    ## CHANGE NEXT PORT (HERE YOU CREATE A SOCKET QUEUE)
    [ ${PORT} -lt 12345 ] && PORT=$((PORT+${RANDOM:0:3})) || PORT=$((PORT-${RANDOM:0:3}))
                ## RANDOM PORT SWAPPINESS

    ###############
    ### CREATE IPNS KEY - ACTIVATE WHITH ENOUGH BOOTSTRAP
        ### echo
        ### ipfs key rm ${PORT} > /dev/null 2>&1
        ### SESSIONNS=$(ipfs key gen ${PORT})
        ### echo "IPNS SESSION http://$myIP:8080/ipns/$SESSIONNS CREATED"
        ### MIAM=$(echo ${PORT} | ipfs add -q)
        ### ipfs name publish --allow-offline --key=${PORT} /ipfs/$MIAM
        ### end=`date +%s`
        ### echo ${PORT} initialisation time was `expr $end - $start` seconds.
        ### echo
    ###############
    ###############

    # RESET VARIABLES
    SALT=""; PEPPER=""; TYPE=""
    echo "************************************************************************* "
    echo "ASTROPORT API SERVER UP.......................... http://$myIP:1234 PORT"
    echo "$MOATS LANDING PAGE http://$myIP:${PORT}"

    ###############    ###############    ###############    ############### templates/index.http
    # REPLACE myIP in http response template (fixing next API meeting point)
    sed "s~127.0.0.1:12345~$myIP:${PORT}~g" $HOME/.zen/Astroport.ONE/templates/index.http > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.myIP.http
    sed -i "s~127.0.0.1~$myIP~g" ~/.zen/tmp/${IPFSNODEID}/${MOATS}.myIP.http
    sed -i "s~:12345~:${PORT}~g" ~/.zen/tmp/${IPFSNODEID}/${MOATS}.myIP.http
    sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/tmp/${IPFSNODEID}/${MOATS}.myIP.http ## NODE PUBLISH HOSTED WHAT'S JSON
    sed -i "s~_HOSTNAME_~$(hostname)~g" ~/.zen/tmp/${IPFSNODEID}/${MOATS}.myIP.http ## HOSTNAME
    ###############    ###############    ###############    ###############
    ############################################################################
    ## SERVE LANDING REDIRECT PAGE ~/.zen/tmp/${IPFSNODEID}/${MOATS}.myIP.http on PORT 1234 (LOOP BLOCKING POINT)
    ############################################################################
    URL=$(cat $HOME/.zen/tmp/${IPFSNODEID}/${MOATS}.myIP.http | nc -l -p 1234 -q 1 | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    ############################################################################
    echo "URL" > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.url ## LOGGING URL
    ############################################################################
    start=`date +%s`

    ############################################################################
    ## / CONTACT - PUBLISH HTML HOMEPAGE (ADD HTTP HEADER)
    if [[ $URL == "/" ]]; then
        echo "/ CONTACT :  http://$myIP:1234"
        echo "___________________________ Preparing register.html"
        echo "HTTP/1.1 200 OK
Server: Astroport
Content-Type: text/html; charset=UTF-8
" > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect ## HTTP 1.1 HEADER + HTML BODY
sed "s~127.0.0.1~$myIP~g" $HOME/.zen/Astroport.ONE/templates/register.html >> ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect
sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect
sed -i "s~_HOSTNAME_~$(hostname)~g" ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect

        cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
        end=`date +%s`
        echo Execution time was `expr $end - $start` seconds.
        continue
    fi
    ############################################################################
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
        ################### KEY GEN ###################################
        echo ">>>>>>>>>>>>>> Application LaBureautique >><< TYPE = $TYPE <<<<<<<<<<<<<<<<<<<<"

        SALT=$(urldecode ${arr[1]} | xargs);
        [[ ! $SALT ]] && (echo "ERROR - SALT MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        PEPPER=$(urldecode ${arr[3]} | xargs)
        [[ ! $PEPPER ]] && (echo "ERROR - PEPPER MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        TYPE=$(urldecode ${arr[4]} | xargs)
        WHAT=$(urldecode ${arr[5]} | xargs)

        ## SAVE "salt" "pepper" DEBUG REMOVE OR PASS ENCRYPT FOR SECURITY REASON
        echo "PLAYER CREDENTIALS : \"$SALT\" \"$PEPPER\""
        echo "\"$SALT\" \"$PEPPER\"" > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.secret.june

        # CALCULATING ${MOATS}.secret.key + G1PUB
        ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/tmp/${IPFSNODEID}/${MOATS}.secret.key  "$SALT" "$PEPPER"
        G1PUB=$(cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.secret.key | grep 'pub:' | cut -d ' ' -f 2)
        [[ ! ${G1PUB} ]] && (echo "ERROR - KEYGEN  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        echo "G1PUB : ${G1PUB}"

        ## CALCULATING IPNS ADDRESS
        ipfs key rm ${G1PUB} > /dev/null 2>&1
        rm -f ~/.zen/tmp/${IPFSNODEID}/${MOATS}.${G1PUB}.ipns.key
        ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/${IPFSNODEID}/${MOATS}.${G1PUB}.ipns.key "$SALT" "$PEPPER"
        ASTRONAUTENS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${IPFSNODEID}/${MOATS}.${G1PUB}.ipns.key )
        echo "ASTRONAUTE TW : http://$myIP:8080/ipns/${ASTRONAUTENS}"
        echo
        ################### KEY GEN ###################################

########################################
        ## ARCHIVE TOCTOC WHATS & KEEPS LOGS CLEAN
        mkdir -p ~/.zen/tmp/toctoc/
        ISTHERE=$(ls -t ~/.zen/tmp/toctoc/*.${G1PUB}.ipns.key 2>/dev/null | tail -n 1)
        TTIME=$(echo $ISTHERE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
        if [[ ! $ISTHERE ]]; then
            echo "WHAT 1ST TOCTOC : $MOATS"
            cp ~/.zen/tmp/${IPFSNODEID}/${MOATS}.* ~/.zen/tmp/toctoc/
        else ## KEEP 1ST CONTACT ONLY
            OLDONE=$(ls -t ~/.zen/tmp/${IPFSNODEID}/*.${G1PUB}.ipns.key | tail -n 1)
            DTIME=$(echo $OLDONE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
            [[ $DTIME != $MOATS ]] && rm ~/.zen/tmp/${IPFSNODEID}/$DTIME.*
        fi

## TYPE SLECTION ########################
        # MESSAGING
        if [[ $TYPE == "messaging" ]]; then

            echo "Extracting ${G1PUB} messages..."
            ~/.zen/Astroport.ONE/tools/timeout.sh -t 3 \
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/${IPFSNODEID}/${MOATS}.secret.key read -n 10 -j  > ~/.zen/tmp/${IPFSNODEID}/messin.${G1PUB}.json
            [[ ! -s ~/.zen/tmp/${IPFSNODEID}/messin.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/${IPFSNODEID}/messin.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/${IPFSNODEID}/messin.${G1PUB}.json

            ~/.zen/Astroport.ONE/tools/timeout.sh -t 3 \
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/${IPFSNODEID}/${MOATS}.secret.key read -n 10 -j -o > ~/.zen/tmp/${IPFSNODEID}/messout.${G1PUB}.json
            [[ ! -s ~/.zen/tmp/${IPFSNODEID}/messout.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/${IPFSNODEID}/messout.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/${IPFSNODEID}/messout.${G1PUB}.json

            echo "Creating messages In/Out JSON ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json"
            echo '[' > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json
            cat ~/.zen/tmp/${IPFSNODEID}/messin.${G1PUB}.json >> ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json
            echo "," >> ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json
            cat ~/.zen/tmp/${IPFSNODEID}/messout.${G1PUB}.json >> ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json
            echo ']' >> ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json

            ## ADDING HTTP/1.1 PROTOCOL HEADER
            echo "HTTP/1.1 200 OK
Server: Astroport
Content-Type: text/html; charset=UTF-8
" > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect
cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json >> ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect

            ### REPONSE=$(cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.messaging.json | ipfs add -q)
            ###   ipfs name publish --allow-offline --key=${PORT} /ipfs/$REPONSE
            ###   echo "SESSION http://$myIP:8080/ipns/$SESSIONNS "

            cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
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
            sed "s~_TWLINK_~https://www.gchange.fr/#/app/user/${G1PUB}/~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect

            ###  REPONSE=$(echo https://www.gchange.fr/#/app/user/${G1PUB}/ | ipfs add -q)
            ### ipfs name publish --allow-offline --key=${PORT} /ipfs/$REPONSE
            ### echo "SESSION http://$myIP:8080/ipns/$SESSIONNS "

            cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo Execution time was `expr $end - $start` seconds.
            continue
        fi
########################################
########################################
########################################
#TESTCRAFT=ON nodeid dataid
########################################
########################################
        if [[ "$TYPE" == "testcraft" ]]; then
            ## RECORD DATA MADE IN BROWSER (JSON)
            SALT=$(urldecode ${arr[1]} | xargs)
            PEPPER=$(urldecode ${arr[3]} | xargs)
            NODEID=$(urldecode ${arr[7]} | xargs)
            DATAID=$(urldecode ${arr[9]} | xargs)

            ## COULD BE A RAW FILE, AN HTML, A JSON
            echo "$TYPE IS $WHAT"

            mkdir -p ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}

            echo "TRYING  ipfs --timeout 2s cat /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json"
            ipfs --timeout 2s cat /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json
            if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json ]]; then
                echo ">>>  curl -m 12 -so ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json https://gateway.ipfs.io/ipfs/$DATAID"
                curl -m 12 -so ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json "https://gateway.ipfs.io/ipfs/$DATAID"
            fi
            if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json ]]; then
                echo "ERROR - $DATAID TIMEOUT - TRY AGAIN" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            else
                [[ $(~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json | jq) ]] && \
                ipfs add ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json
            fi

            ## REPONSE ON PORT
                cat ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

            end=`date +%s`
            echo Execution time was `expr $end - $start` seconds.
            continue
        fi

##############################################
# DEFAULT (NO REDIRECT DONE YET) CHECK OFFICIAL GATEWAY
##############################################
       TWIP=$myIP
        # OFFICIAL Gateway ( increase waiting time ) - MORE SECURE
        if [[ $TYPE == "official" ]]; then

            echo "OFFICIAL latest online TW... $LIBRA ($YOU)"

            [[ $YOU ]] && echo "http://$myIP:8080/ipns/${ASTRONAUTENS} ($YOU)" && ipfs --timeout 12s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html
            [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html ]] && echo "$LIBRA/ipns/${ASTRONAUTENS}" && curl -m 12 -so ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html "$LIBRA/ipns/${ASTRONAUTENS}"

            # DEBUG
            # echo "tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'"
            # echo "cat ~/.zen/tmp/miz.json | jq -r .[].secret"

            if [[ -s ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html ]]; then
                tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
                OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)
                [[ ! $OLDIP ]] && (echo "501 ERROR - SORRY - YOUR TW IS OUT OF SWARM#0 - CONTINUE " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
                # LOCKED TW BECOMING ACTIVE GATEWAY
                if [[ $OLDIP == "_SECRET_" ]]; then
                    echo "_SECRET_ TW PUSHING TW" ## BECOMING OFFICIAL BECOME R/W TW
                    sed -i "s~_SECRET_~${myIP}~g" ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html
                    echo "HTTP/1.1 200 OK
Server: Astroport
Content-Type: text/html; charset=UTF-8
" > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect
                    cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.astroindex.html >> ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect
                    cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
                    continue
                fi
                # ACTIVE GATEWAY
                [[ $OLDIP != $myIP ]] && TWIP=$OLDIP
                echo "***********  OFFICIAL LOGIN GOES TO $TWIP"
            else
                (echo "ERROR - NO TW FOUND - ASK FOR VISA" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
            fi
        else
            echo "***** READER MODE - R/W USE OFFICIAL *****  http://$myIP:1234/?salt=$SALT&pepper=$PEPPER&official=on"
        fi

        sed "s~_TWLINK_~http://$TWIP:8080/ipns/${ASTRONAUTENS}~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect

        ## TODO PATCH _SECRET_ myIP STUFF

        ## RESPONDING
        cat ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
        echo "HTTP 1.1 PROTOCOL DOCUMENT READY ~/.zen/tmp/${IPFSNODEID}/${MOATS}.index.redirect"
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
