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

mkdir -p ~/.zen/tmp/123/

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 1234' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "ERROR - API Server Already Running -  http://$myIP:1234/?salt=toto&pepper=toto " && exit 1

echo "LAUNCHING Astroport  API Server - http://$myIP:1234/?salt=toto&pepper=toto&messaging"

# [[ $DISPLAY ]] && xdg-open "file://$HOME/.zen/Astroport.ONE/templates/instascan.html" 2>/dev/null
# [[ $DISPLAY ]] && xdg-open "http://$myIP:1234" 2>/dev/null

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

while true; do
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    ## CHANGE NEXT PORT (HERE YOU CREATE A SOCKET QUEUE)
    [ $PORT -lt 12345 ] && PORT=$((PORT+${RANDOM:0:2})) || PORT=$((PORT-${RANDOM:0:2}))
                ## RANDOM PORT SWAPPINESS

    echo "************************************************************************* "
    echo "ASTROPORT API SERVER UP.......................... http://$myIP:1234 PORT"
    echo "$MOATS LANDING PAGE http://$myIP:$PORT"

    # REPLACE myIP in http response template
    sed "s~127.0.0.1:12345~$myIP:$PORT~g" $HOME/.zen/Astroport.ONE/templates/index.http > ~/.zen/tmp/123/${MOATS}.myIP.http
    sed -i "s~127.0.0.1~$myIP~g" ~/.zen/tmp/123/${MOATS}.myIP.http
    sed -i "s~_IPFSNODEID_~$IPFSNODEID~g" ~/.zen/tmp/123/${MOATS}.myIP.http ## NODE PUBLISH HOSTED PLAYER'S JSON

    ############################################################################
    ## WAITING TO SERVE 1ST LANDING REDIRECT PAGE
    ############################################################################
    URL=$(cat $HOME/.zen/tmp/123/${MOATS}.myIP.http | nc -l -p 1234 -q 1 | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    ############################################################################
    ############################################################################
    start=`date +%s`

    ## NO API CONTACT - PUBLISH HOMEPAGE
    if [[ $URL == "/" ]]; then
        echo "API NULL CALL :  http://$myIP:1234"
        echo "___________________________ Launching homepage.html"
        echo "HTTP/1.1 200 OK
Server: Astroport
Content-Type: text/html; charset=UTF-8
" > ~/.zen/tmp/123/${MOATS}.index.redirect
sed "s~127.0.0.1~$myIP~g" $HOME/.zen/Astroport.ONE/templates/homepage.html >> ~/.zen/tmp/123/${MOATS}.index.redirect

        cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 &

        end=`date +%s`
        echo Execution time was `expr $end - $start` seconds.
        continue
    fi

    echo "=================================================="
    echo "GET RECEPTION : $URL"
    arr=(${URL//[=&]/ })
    echo "PARAM : ${arr[0]} = ${arr[1]} & ${arr[2]} = ${arr[3]} & ${arr[4]} = ${arr[5]} & ${arr[6]} = ${arr[7]}"

    [[ ${arr[0]} == "" && ${arr[1]} == "" ]] && echo "GET NO DATA" && continue

    ########## CHECK GET PARAM NAMES
###################################################################################################
###################################################################################################
# API ZERO ## Made In Zion & La Bureautique
    if [[ ${arr[0]} == "salt" ]]; then
        echo "Application LaBureautique !!"
        SALT=$(urldecode ${arr[1]})
        [[ ! $SALT ]] && echo "BAD SALT API CALL" && continue
        PEPPER=$(urldecode ${arr[3]})
        [[ ! $PEPPER ]] && echo "BAD PEPPER API CALL" && continue

        TYPE=$(urldecode ${arr[4]})
        PLAYER=$(urldecode ${arr[5]})

        echo "API ZERO CALL :  http://$myIP:1234/?salt=$SALT&pepper=$PEPPER&$TYPE=$PLAYER"

        echo "\"$SALT\" \"$PEPPER\"" > ~/.zen/tmp/123/${MOATS}.secret.june

        # CALCULATING G1PUB
        ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/tmp/123/${MOATS}.secret.key  "$SALT" "$PEPPER"
        G1PUB=$(cat ~/.zen/tmp/123/${MOATS}.secret.key | grep 'pub:' | cut -d ' ' -f 2)
        [[ ! $G1PUB ]] && echo "ERROR - G1PUB COMPUTATION EMPTY" && continue

        ## CALCULATING IPNS ADDRESS
        ipfs key rm gchange 2>/dev/null
        rm -f ~/.zen/tmp/123/${MOATS}.${G1PUB}.ipns.key
        ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/123/${MOATS}.${G1PUB}.ipns.key "$SALT" "$PEPPER"
        GNS=$(ipfs key import gchange -f pem-pkcs8-cleartext ~/.zen/tmp/123/${MOATS}.${G1PUB}.ipns.key )
        echo "Astronaute TW ? http://$myIP:8080/ipns/$GNS"

        ## ARCHIVE TOCTOC PLAYERS
        mkdir -p ~/.zen/tmp/toctoc/
        ISTHERE=$(ls -t ~/.zen/tmp/toctoc/*.${G1PUB}.ipns.key 2>/dev/null | tail -n 1)
        TTIME=$(echo $ISTHERE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
        if [[ ! $ISTHERE ]]; then
            echo "PLAYER 1ST TOCTOC : $MOATS"
            cp ~/.zen/tmp/123/${MOATS}.* ~/.zen/tmp/toctoc/
        else
            OLDONE=$(ls -t ~/.zen/tmp/123/*.${G1PUB}.ipns.key | tail -n 1)
            DTIME=$(echo $OLDONE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
            [[ $DTIME != $MOATS ]] && rm ~/.zen/tmp/123/$DTIME.*
        fi
## TYPE SLECTION
        # MESSAGING
        if [[ $TYPE == "messaging" ]]; then

            echo "Extracting $G1PUB messages..."
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/123/${MOATS}.secret.key read -n 10 -j  > ~/.zen/tmp/123/messin.${G1PUB}.json
            [[ $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/123/messin.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/123/messin.${G1PUB}.json
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/123/${MOATS}.secret.key read -n 10 -j -o > ~/.zen/tmp/123/messout.${G1PUB}.json
            [[ $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/123/messout.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/123/messout.${G1PUB}.json

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

        fi
        ######################## MESSAGING

        # G1PUB -> Open Gchange Profile
        [[ "$TYPE" == "g1pub" ]] && sed "s~_TWLINK_~https://www.gchange.fr/#/app/user/$G1PUB/~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/123/${MOATS}.index.redirect

        ## ELSE IPNS TW REDIRECT
        if [[ ! -f ~/.zen/tmp/123/${MOATS}.index.redirect ]]; then
            TWIP=$myIP
            # OFFICIAL Gateway ( increase waiting time ) - MORE SECURE
            if [[ $TYPE="official" ]]; then
                ipfs --timeout 3s cat /ipns/$GNS > ~/.zen/tmp/123/${MOATS}.astroindex.html && echo "LATEST TW: ~/.zen/tmp/123/${MOATS}.astroindex.html"
                [[ -s ~/.zen/tmp/123/${MOATS}.astroindex.html ]] && tiddlywiki --load ~/.zen/tmp/123/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
                OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret) && [[ ! $OLDIP ]] && echo "+x+x+x+x+x+ SECRET IP ERROR - BAD TW - CONTINUE " && continue
                # FIRST TIME PLAYER TW USING GATEWAY
                [[ $OLDIP == "_SECRET_" ]] && echo "_SECRET_ TW" && sed -i "s~_SECRET_~${myIP}~g" ~/.zen/tmp/123/${MOATS}.astroindex.html && OLDIP=$myIP
                # AM I MANAGING TW
                [[ $OLDIP != $myIP ]] && TWIP=$OLDIP
            else
                echo "***** TRY OFFICIAL *****  http://$myIP:1234/?salt=$SALT&pepper=$PEPPER&official=on"
            fi
            sed "s~_TWLINK_~http://$TWIP:8080/ipns/$GNS~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/123/${MOATS}.index.redirect
        fi
        ## TODO PATCH _SECRET_ myIP STUFF

        ## RESPONDING
        cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 &
        echo "HTTP 1.1 PROTOCOL DOCUMENT READY ~/.zen/tmp/123/${MOATS}.index.redirect"
        echo "$MOATS -----> PAGE AVAILABLE -----> http://$myIP:${PORT}"
        #echo "$GNS" | nc -l -p ${PORT} -q 1 &

        ## CHECK IF ALREADY EXISTING PLAYER
        # IF NOT = BATCH CREATE TW
        end=`date +%s`
        echo Execution time was `expr $end - $start` seconds.

    fi

###################################################################################################
###################################################################################################
# API ONE : ?salt=PHRASE%20UNE&pepper=PHRASE%20DEUX&messaging/g1pub=on&email/elastic=ELASTICID&pseudo=PROFILENAME
    if [[ ${arr[6]} == "email" || ${arr[6]} == "elastic" ]]; then
        TYPE=$(urldecode ${arr[4]})
        [[ $TYPE != "g1pub" ]] && echo "ONLY WORKS WITH TYPE=g1pub CALL" && continue
        start=`date +%s`

        SALT=$(urldecode ${arr[1]})
        PEPPER=$(urldecode ${arr[3]})
        PLAYER=$(urldecode ${arr[7]})
        PSEUDO=$(urldecode ${arr[9]})

        [[ ! $PLAYER ]] && echo "ERROR - NO EMAIL. BAD ELASTIC PLAYER" && continue

                if [[ ! $PSEUDO ]]; then
                    PSEUDO=$(echo $PLAYER | cut -d '@' -f 1)
                    PSEUDO=${PSEUDO,,}; PSEUDO=${PSEUDO%%[0-9]*}${RANDOM:0:3}
                fi
                # PASS CRYPTING KEY
                PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

            echo "$SALT"
            echo "$PEPPER"

                if [[ ! -d ~/.zen/game/players/$PLAYER ]]; then
                    # ASTRONAUT NEW VISA
                    $MY_PATH/tools/VISA.new.sh "$SALT" "$PEPPER" "$PLAYER" "$PSEUDO"

               else
                    # ASTRONAUT EXISTING PLAYER
                    CHECK=$(cat ~/.zen/game/players/$PLAYER/secret.june | grep -w "$SALT")
                    [[ $CHECK ]] && CHECK=$(cat ~/.zen/game/players/$PLAYER/secret.june | grep -w "$PEPPER")
                    [[ ! $CHECK ]] && echo "ERROR - CREDENTIALS NOT CORRESPONDING WITH PLAYER" && continue
               fi

                    mkdir -p ~/.zen/tmp/123/TW/
                    cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/123/TW/index.html

               ###################################################################################################
                # VERIFICATION PAR EXTRACTION MOA
                rm -f ~/.zen/tmp/123/tiddlers.json
                tiddlywiki --load ~/.zen/tmp/123/TW/index.html --output ~/.zen/tmp --render '.' 'tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[moa]]'
                TITLE=$(cat ~/.zen/tmp/123/tiddlers.json | jq -r '.[].title') # Dessin de PLAYER
                PLAYER=$(echo $TITLE | rev | cut -f 1 -d ' ' | rev)
                [[ ! $PLAYER ]] && echo "ERROR WRONG TW" && continue

                echo "Bienvenue Astronaute $PLAYER. Nous avons capté votre TW"
                echo "Redirection"
                [[ $YOU ]] && TWLINK="http://$myIP:8080/ipns/$GNS" \
                                    || TWLINK="$LIBRA/ipns/$GNS"
                echo "$TWLINK"

                # Injection TWLINK dans template de redirection.
                sed "s~_TWLINK_~$TWLINK~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/123/${MOATS}.index.redirect

                ## NOW ~/.zen/tmp/123/${MOATS}.index.redirect APPEARS. WAITING $PORT AVAILABLE THEN INJECT $TWLINK REDIRECT
                echo "ASTRONAUT $TWLINK AVAILABLE on http://$myIP:${PORT}"
                [[ ! $(ps auxf --sort=+utime | grep -w 'nc -l -p '${PORT} | grep -v -E 'color=auto|grep') ]] && cat ~/.zen/tmp/123/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 &

                ###################################################################################################
                end=`date +%s`
                echo Execution time was `expr $end - $start` seconds.

    fi

###################################################################################################
###################################################################################################
# API TWO : ?qrcode=G1PUB
    if [[ ${arr[0]} == "qrcode" ]]; then
        ## Astroport.ONE local use QRCODE Contains PLAYER G1PUB
        QRCODE=$(echo $URL | cut -d ' ' -f2 | cut -d '=' -f 2 | cut -d '&' -f 1)   && echo "Instascan.html QR : $QRCODE"
        g1pubpath=$(grep $QRCODE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
        PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

        ## FORCE LOCAL USE ONLY. Remove to open 1234 API
        [[ ! -d ~/.zen/game/players/$PLAYER || $PLAYER == "" ]] && echo "AUCUN PLAYER !!" && continue

        ## UNE SECOND HTTP SERVER TO RECEIVE PASS

        [[ ${arr[2]} == "" ]] && continue


    fi

###################################################################################################
###################################################################################################
# API THREE : ?qrcode=G1PUB&url=HTTPLINK
    ## Demande de copie d'une URL reçue.
    if [[ ${arr[0]} == "qrcode" &&  ${arr[2]} == "url" ]]; then
        wsource="${arr[3]}"
         [[ ${arr[4]} == "type" ]] && wtype="${arr[5]}" || wtype="Youtube"

        ## LANCEMENT COPIE
        ~/.zen/Astropor.ONE/ajouter_video.sh "$(urldecode $wsource)" "$wtype" "$QRCODE" &

        echo "$QRCODE $wsource"

    fi

    ## ENVOYER MESSAGE GCHANGE POUR QRCODE


    rm ~/.zen/tmp/123/${MOATS}.myIP.http
    HOMEPAGE=""

done
exit 0
