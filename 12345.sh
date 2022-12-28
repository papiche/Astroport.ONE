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

    YOU=$(myIpfsApi); ## API of $USER running ipfs
    echo "YOU=$YOU"
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2) ## SWARM#0 ENTRANCE URL
    TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)

mkdir -p ~/.zen/tmp/coucou/ ~/.zen/game/players/localhost

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 1234' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "ERROR - API Server Already Running -  ${myASTROPORT}/?salt=totodu56&pepper=totodu56&getipns " && exit 1
## NOT RUNNING TWICE

# Some client needs to respect that
HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8
"
echo "_________________________________________________________ $(date)"
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
echo "TESTCRAFT ${myASTROPORT}/?salt=totodu56&pepper=totodu56&testcraft=on&nodeid=12D3KooWK1ACupF7RD3MNvkBFU9Z6fX11pKRAR99WDzEUiYp5t8j&dataid=QmPXhrqQrS1bePKJUPH9cJ2qe4RrNjaJdRXaJzSjxWuvDi"
echo "_________________________________________________________"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

#############################
########## MAIN ###############
#############################
while true; do

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    # EACH VISITOR RECEIVE COMMAND RESPONSE ON
    ## RANDOM PORT = RESPONSE SOCKET & IPNS SESSION TOKEN

    [ ${PORT} -le 12345 ] && PORT=$((PORT+${RANDOM:0:2})) || PORT=$((PORT-${RANDOM:0:2}))
                    ## RANDOM PORT SWAPPINESS AVOIDING COLLISION

    ## CHECK PORT IS FREE & KILL OLD ONE
    pidportinuse=$(ps axf --sort=+utime | grep -w "nc -l -p ${PORT}" | grep -v -E 'color=auto|grep' | awk '{gsub(/^ +| +$/,"")} {print $0}' | tail -n 1 | cut -d " " -f 1)
    [[ $pidportinuse ]] && kill -9 $pidportinuse && echo "KILLING $pidportinuse" && continue

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
    SALT=""; PEPPER=""; APPNAME=""

    ###############    ###############    ###############    ############### templates/index.http
    # REPLACE myHOST in http response template (fixing next API meeting point)
    echo "$HTTPCORS" >  ~/.zen/tmp/coucou/${MOATS}.myHOST.http
    myTmpl >> ~/.zen/tmp/coucou/${MOATS}.myHOST.http
    sed -i -e "s~\"${myIPFS}/\"~\"$(myIpfs)\"~g" \
        -e "s~http://${myHOST}:12345~http://${myHOST}:${PORT}~g" \
        ~/.zen/tmp/coucou/${MOATS}.myHOST.http

    ############################################################################
    ## SERVE LANDING REDIRECT PAGE ~/.zen/tmp/coucou/${MOATS}.myHOST.http on PORT 1234 (LOOP BLOCKING POINT)
    ############################################################################
    REQ=$(cat $HOME/.zen/tmp/coucou/${MOATS}.myHOST.http | nc -l -p 1234 -q 1) ## # WAIT FOR 1234 PORT CONTACT

    URL=$(echo "$REQ" | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    HOSTP=$(echo "$REQ" | grep '^Host:' | cut -d ' ' -f2  | cut -d '?' -f2)
    HOST=$(echo "$HOSTP" | cut -d ':' -f 1)

    ###############    ###############    ###############    ###############

    ############################################################################
    [[ $URL == "/test"  || $URL == "" ]] && continue

    echo "************************************************************************* "
    echo "ASTROPORT 1234 UP & RUNNING.......................... http://$HOST:1234 PORT"
    echo "${MOATS} NEXT COMMAND DELIVERY PAGE http://$HOST:${PORT}"

    [[ $XDG_SESSION_TYPE == 'x11' ]] && espeak "Ding" >/dev/null 1>&2

    echo "URL" > ~/.zen/tmp/coucou/${MOATS}.url ## LOGGING URL

    ############################################################################
    start=`date +%s`

    ############################################################################
    ## / CONTACT
    if [[ $URL == "/" ]]; then
        echo "/ CONTACT :  $HOSTP"

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

    # CHECK APPNAME
        APPNAME=$(urldecode ${arr[4]} | xargs)
        WHAT=$(urldecode ${arr[5]} | xargs)

        OBJ=$(urldecode ${arr[6]} | xargs)
        VAL=$(urldecode ${arr[7]} | xargs)

########## CHECK GET PARAM NAMES
###################################################################################################
    [[ ${arr[0]} == "" || ${arr[1]} == "" ]] && (echo "$HTTPCORS ERROR - MISSING DATA" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

###################################################################################################
# API ZERO ## Made In Zion & La Bureautique
    if [[ ${arr[0]} == "salt" ]]; then
        [[ ! $APPNAME || $SALT == "pepper" ]] && echo "NO APPNAME - BAD APP - CONTINUE" && continue
        ############################################################################
        # WRITING API # SALT # PEPPER # MAKING THE KEY EXIST #########
        ################### KEY GEN ###################################
        echo ">>>>>>>>>>>>>> Application LaBureautique >><< APPNAME = $APPNAME <<<<<<<<<<<<<<<<<<<<"

        SALT=$(urldecode ${arr[1]} | xargs);
        [[ ! $SALT ]] && (echo "$HTTPCORS ERROR - SALT MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        PEPPER=$(urldecode ${arr[3]} | xargs)
        [[ ! $PEPPER ]] && (echo "$HTTPCORS ERROR - PEPPER MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        ## SAVE "salt" "pepper" DEBUG REMOVE OR PASS ENCRYPT FOR SECURITY REASON
        echo "PLAYER : \"$SALT\" \"$PEPPER\" : $APPNAME ($WHAT)"
        echo "\"$SALT\" \"$PEPPER\"" > ~/.zen/tmp/coucou/${MOATS}.secret.june

        # CALCULATING ${MOATS}.secret.key + G1PUB
        ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/tmp/coucou/${MOATS}.secret.key  "$SALT" "$PEPPER"
        G1PUB=$(cat ~/.zen/tmp/coucou/${MOATS}.secret.key | grep 'pub:' | cut -d ' ' -f 2)
        [[ ! ${G1PUB} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - KEYGEN  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        echo "G1PUB : ${G1PUB}"

        ## CALCULATING ${MOATS}.${G1PUB}.ipns.key ADDRESS
        ipfs key rm ${G1PUB} > /dev/null 2>&1
        rm -f ~/.zen/tmp/coucou/${MOATS}.${G1PUB}.ipns.key
        ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/coucou/${MOATS}.${G1PUB}.ipns.key "$SALT" "$PEPPER"
        ASTRONAUTENS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/coucou/${MOATS}.${G1PUB}.ipns.key )
        [[ ! ${ASTRONAUTENS} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - ASTRONAUTENS  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        echo "TW ADDRESS : $myIPFS/ipns/${ASTRONAUTENS}"
        echo

        ################### KEY GEN ###################################

    # Get PLAYER wallet amount
    ( ## SUB PROCESS
        COINS=$($MY_PATH/tools/jaklis/jaklis.py -k ~/.zen/tmp/coucou/${MOATS}.secret.key balance)
        echo "+++ WALLET BALANCE _ $COINS (G1) _"
        [[ $COINS == "" || $COINS == "null" ]] && $MY_PATH/tools/jaklis/jaklis.py -k ~/.zen/tmp/coucou/${MOATS}.secret.key -n "https://data.gchange.fr" send -d "${G1PUB}" -t "BRO." -m "TAPA DE JUNE ? VA AVEC >>> https://cesium.app >>> (ᵔ◡◡ᵔ) FLASHER TON G1VISA "
        end=`date +%s`
        echo "G1WALLET  (☓‿‿☓) Execution time was "`expr $end - $start` seconds.
    ) &
########################################

########################################
        ## ARCHIVE TOCTOC ${WHAT}S KEEP LOG (TODO : ERASE)
########################################
        mkdir -p ~/.zen/game/players/.toctoc/
        ISTHERE=$(ls -t ~/.zen/game/players/.toctoc/*.${G1PUB}.ipns.key 2>/dev/null | tail -n 1 | cut -d '.' -f 1)
        TTIME=$(echo $ISTHERE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
        if [[ ! $ISTHERE ]]; then
            echo "${APPNAME} 1ST TOCTOC : ${MOATS}"
            cp ~/.zen/tmp/coucou/${MOATS}.* ~/.zen/game/players/.toctoc/
        else ## KEEP 1ST CONTACT ONLY
            OLDONE=$(ls -t ~/.zen/tmp/coucou/*.${G1PUB}.ipns.key | tail -n 1)
            DTIME=$(echo $OLDONE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
            [[ $DTIME != ${MOATS} ]] && rm ~/.zen/tmp/coucou/$DTIME.*
        fi

########################################
## APPNAME SELECTION  ########################
########################################

##############################################
# MESSAGING
##############################################
        if [[ $APPNAME == "messaging" ]]; then

            ( ## & SUB PROCESS

            echo "Extracting ${G1PUB} messages..."
            ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/coucou/${MOATS}.secret.key read -n 10 -j  > ~/.zen/tmp/coucou/messin.${G1PUB}.json
            [[ ! -s ~/.zen/tmp/coucou/messin.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/coucou/messin.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/coucou/messin.${G1PUB}.json

            ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/tmp/coucou/${MOATS}.secret.key read -n 10 -j -o > ~/.zen/tmp/coucou/messout.${G1PUB}.json
            [[ ! -s ~/.zen/tmp/coucou/messout.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/coucou/messout.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/coucou/messout.${G1PUB}.json

            echo "Creating messages In/Out JSON ~/.zen/tmp/coucou/${MOATS}.messaging.json"
            echo '[' > ~/.zen/tmp/coucou/${MOATS}.messaging.json
            cat ~/.zen/tmp/coucou/messin.${G1PUB}.json >> ~/.zen/tmp/coucou/${MOATS}.messaging.json
            echo "," >> ~/.zen/tmp/coucou/${MOATS}.messaging.json
            cat ~/.zen/tmp/coucou/messout.${G1PUB}.json >> ~/.zen/tmp/coucou/${MOATS}.messaging.json
            echo ']' >> ~/.zen/tmp/coucou/${MOATS}.messaging.json

            ## ADDING HTTP/1.1 PROTOCOL HEADER
            echo "$HTTPCORS" > ~/.zen/tmp/coucou/${MOATS}.index.redirect
            sed -i "s~text/html~application/json~g"  ~/.zen/tmp/coucou/${MOATS}.index.redirect
            cat ~/.zen/tmp/coucou/${MOATS}.messaging.json >> ~/.zen/tmp/coucou/${MOATS}.index.redirect

            ## SEND REPONSE PROCESS IN BACKGROUD
            cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
                #~ ( ## USING IPNS SESSION KEY
                #~ REPONSE=$(cat ~/.zen/tmp/coucou/${MOATS}.messaging.json | ipfs add -q)
                #~ ipfs name publish --allow-offline --key=${PORT} /ipfs/$REPONSE
                #~ echo "SESSION ${myIPFS}/ipns/$SESSIONNS "
                #~ ) &

            end=`date +%s`
            dur=`expr $end - $start`
            echo ${MOATS}:${G1PUB}:${PLAYER}:${APPNAME}:$dur >> ~/.zen/tmp/${IPFSNODEID}/_timings
            cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1

            ) & ## & SUB PROCESS

            end=`date +%s`
            echo " Messaging launch (☓‿‿☓) Execution time was "`expr $end - $start` seconds.
            continue
        fi
        ######################## MESSAGING END

########################################
# G1PUB WITH NO EMAIL -> Open Gchange Profile & Update TW cache
########################################
        if [[ "$APPNAME" == "g1pub" && "$OBJ" != "email" ]]; then

            [[ ${WHAT} == "astro" ]] && REPLACE="$LIBRA/ipns/$ASTRONAUTENS" \
            || REPLACE="https://www.gchange.fr/#/app/user/${G1PUB}"
            echo ${REPLACE}

            ## REDIRECT TO TW OR GCHANGE PROFILE
            sed "s~_TWLINK_~${REPLACE}/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/coucou/${MOATS}.index.redirect
            ## USED BY https://git.p2p.legal/La_Bureautique/zeg1jeux/src/branch/main/lib/Fred.class.php#L81
            echo "url='"${REPLACE}"'" >> ~/.zen/tmp/coucou/${MOATS}.index.redirect

            ###  REPONSE=$(echo https://www.gchange.fr/#/app/user/${G1PUB}/ | ipfs add -q)
            ### ipfs name publish --allow-offline --key=${PORT} /ipfs/$REPONSE
            ### echo "SESSION ${myIPFS}/ipns/$SESSIONNS "
            (
            cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
            ${MY_PATH}/tools/TW.cache.sh ${ASTRONAUTENS} ${MOATS}
            ) &
            end=`date +%s`
            echo $APPNAME" (0‿‿0) ${WHAT} Execution time was "`expr $end - $start` seconds.
            continue
        fi
########################################

########################################
########################################
#TESTCRAFT=ON nodeid dataid
########################################
########################################
        if [[ "$APPNAME" == "testcraft" ]]; then

        ( # testcraft & SUB PROCESS

            start=`date +%s`
            ## RECORD DATA MADE IN BROWSER (JSON)
            NODEID=$(urldecode ${arr[7]} | xargs)
            DATAID=$(urldecode ${arr[9]} | xargs)

            ## export PLAYER
            ${MY_PATH}/tools/TW.cache.sh ${ASTRONAUTENS} ${MOATS}

            ## IS IT INDEX JSON
            echo "${PLAYER} $APPNAME IS ${WHAT}"
            mkdir -p ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}

            [[ $WHAT == "on" ]] && WHAT="json" # data mimetype (default "on" = json)

            ## TODO : modify timeout if isLAN or NOT
            [[ $isLAN ]] && WAIT=3 || WAIT=12
            echo "1ST TRY : ipfs --timeout ${WAIT}s cat /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT}"
            ipfs --timeout ${WAIT}s cat /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT}

echo "" > ~/.zen/tmp/.ipfsgw.bad.twt # TODO move in 20h12.sh

            if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} ]]; then

                echo "IPFS TIMEOUT >>> (°▃▃°) $DATAID STILL MISSING GATEWAY BANGING FOR IT (°▃▃°)"
                array=(https://ipfs.copylaradio.com/ipfs/:hash https://ipns.co/:hash https://dweb.link/ipfs/:hash https://ipfs.io/ipfs/:hash https://ipfs.fleek.co/ipfs/:hash https://ipfs.best-practice.se/ipfs/:hash https://gateway.pinata.cloud/ipfs/:hash https://gateway.ipfs.io/ipfs/:hash https://cf-ipfs.com/ipfs/:hash https://cloudflare-ipfs.com/ipfs/:hash)
                # size=${#array[@]}; index=$(($RANDOM % $size)); echo ${array[$index]} ## TODO CHOOSE RANDOM

                # official ipfs best gateway from https://luke.lol/ipfs.php
                for nicegw in ${array[@]}; do

                    [[ $(cat ~/.zen/tmp/.ipfsgw.bad.twt | grep -w $nicegw) ]] && echo "<<< BAD GATEWAY >>>  $nicegw" && continue
                    gum=$(echo  "$nicegw" | sed "s~:hash~$DATAID~g")
                    echo "LOADING $gum"
                    curl -m 5 -so ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} "$gum"
                    [[ $? != 0 ]] && echo "(✜‿‿✜) BYPASSING"

                    if [[ -s ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} ]]; then

                        MIME=$(mimetype -b ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT})
                        GOAL=$(ipfs add -q ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT})

                        if [[ ${GOAL} != ${DATAID} ]]; then
                            echo " (╥☁╥ ) - BAD ${WHAT} FORMAT ERROR ${MIME} - (╥☁╥ )"
                            ipfs pin rm /ipfs/${GOAL}
                            rm ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT}
                            # NOT A JSON AVOID BANISHMENT
                            echo $nicegw >> ~/.zen/tmp/.ipfsgw.bad.twt
                            continue

                        else
                            ## GOT IT !! IPFS ADD
                            ipfs pin add /ipfs/${GOAL}
                            ## + TW ADD (new_file_in_astroport.sh)

                            echo "(♥‿‿♥) FILE UPLOAD OK"; echo
                            break

                        fi

                    else

                        echo " (⇀‿‿↼) - NO FILE - (⇀‿‿↼)"
                        continue

                    fi

                done

            fi ## NO DIRECT IPFS - GATEWAY TRY

           ## REALLY NO FILE FOUND !!!
           [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} ]] && \
           echo "$HTTPCORS ERROR (╥☁╥ ) - $DATAID TIMEOUT - (╥☁╥ )" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

            ## SPECIAL  index.[json/html/...] MODE.
            [[ ${WHAT} == "index" ]] && cp ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/index.json
## TODO MAKE MULTIFORMAT DATA & INDEX
#            RWHAT=$(echo "$WHAT" | cut -d '.' -f 1)
#            TWHAT=$(echo "$WHAT" | cut -d '.' -f 2)
#            cp ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${RWHAT}.${TWHAT}

            ## REPONSE ON PORT
                echo "$HTTPCORS" > ~/.zen/tmp/coucou/${MOATS}.index.redirect
                sed -i "s~text/html~application/json~g"  ~/.zen/tmp/coucou/${MOATS}.index.redirect
                cat ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} >> ~/.zen/tmp/coucou/${MOATS}.index.redirect

                cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

            ## REPONSE ON IPFSNODEID
                (
                    start=`date +%s`
                    echo "¯\_༼<O͡〰o>༽_/¯ $IPFSNODEID $PLAYER SIGNALING"
                    ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )
                    ipfs name publish --allow-offline /ipfs/$ROUTING
                    echo "DONE"
                    end=`date +%s`
                    dur=`expr $end - $start`
                    echo ${MOATS}:${G1PUB}:${PLAYER}:SELF:$dur >> ~/.zen/tmp/${IPFSNODEID}/_timings
                    cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1
                ) &

            end=`date +%s`
            dur=`expr $end - $start`
            echo ${MOATS}:${G1PUB}:${PLAYER}:${APPNAME}:$dur >> ~/.zen/tmp/${IPFSNODEID}/_timings
            cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1

        ) & # testcraft & SUB PROCESS

            end=`date +%s`
            echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds.
            continue
        fi


##############################################
# GETIPNS
##############################################
        if [[ $APPNAME == "getipns" ]]; then
            echo "$HTTPCORS /ipns/${ASTRONAUTENS}"| nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo $APPNAME "(☉_☉ ) /ipns/${ASTRONAUTENS} Execution time was "`expr $end - $start` seconds.
            continue
        fi


        ###################################################################################################
        ###################################################################################################
        # API ONE : ?salt=PHRASE%20UNE&pepper=PHRASE%20DEUX&g1pub=on&email=EMAIL&pseudo=PROFILENAME
    if [[ ${OBJ} == "email" && "${VAL}" != "" ]]; then

                [[ $APPNAME != "g1pub" ]] && (echo "$HTTPCORS ERROR - BAD COMMAND $APPNAME" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. && continue

                start=`date +%s`

                # WHAT can contain urlencoded FullURL
                EMAIL="${VAL}"
                PSEUDO=$(urldecode ${arr[9]} | xargs)

                [[ ! ${EMAIL} ]] && (echo "$HTTPCORS ERROR - MISSING ${EMAIL} FOR ${WHAT} CONTACT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  continue

                ## CHECK WHAT IS EMAIL
                if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
                    echo "VALID EMAIL OK"
                else
                    echo "BAD EMAIL"
                    (echo "$HTTPCORS KO ${EMAIL} : bad '"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
                fi

                ## CREATE PSEUDO FROM
                if [[ ! $PSEUDO ]]; then
                    PSEUDO=$(echo ${EMAIL} | cut -d '@' -f 1)
                    PSEUDO=${PSEUDO,,}; PSEUDO=${PSEUDO%%[0-9]*}${RANDOM:0:4}
                fi

                if [[ ! -d ~/.zen/game/players/${EMAIL} ]]; then
                    echo "# ASTRONAUT NEW VISA Create VISA.new.sh in background (~/.zen/tmp/email.${EMAIL}.${MOATS}.txt)"
                    (
                    startvisa=`date +%s`
                    [[ "$SALT" == "0" && "$PEPPER" == "0" ]] && SALT="" && PEPPER="" # "0" "0" means random salt pepper
                    echo "VISA.new : \"$SALT\" \"$PEPPER\" \"${EMAIL}\" \"$PSEUDO\" \"${WHAT}\"" > ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt
                    $MY_PATH/tools/VISA.new.sh "$SALT" "$PEPPER" "${EMAIL}" "$PSEUDO" "${WHAT}" >> ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt
                    $MY_PATH/tools/mailjet.sh "${EMAIL}" ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt ## Send VISA.new log to EMAIL

                    end=`date +%s`
                    dur=`expr $end - $startvisa`
                    echo ${MOATS}:${G1PUB}:${PLAYER}:VISA:$dur >> ~/.zen/tmp/${IPFSNODEID}/_timings
                    cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1
                    ) &

                    echo "$HTTPCORS -    <meta http-equiv='refresh' content='3; url=\""${myIPFS}"/ipns/"$ASTRONAUTENS"\"'/>
                    <h1>BOOTING - ASTRONAUT $PSEUDO </h1> IPFS FORMATING - [$SALT + $PEPPER] (${EMAIL})
                    <br>- TW - ${myIPFS}/ipns/$ASTRONAUTENS <br> - GW - /ipns/$IPFSNODEID" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

                    continue
               else
                    # ASTRONAUT EXISTING ${EMAIL}
                    CHECK=$(cat ~/.zen/game/players/${EMAIL}/secret.june | grep -w "$SALT")
                    [[ $CHECK ]] && CHECK=$(cat ~/.zen/game/players/${EMAIL}/secret.june | grep -w "$PEPPER")
                    [[ ! $CHECK ]] && (echo "$HTTPCORS - WARNING - PLAYER ${EMAIL} ALREADY HERE"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  continue
               fi

                 ###################################################################################################
                end=`date +%s`
                echo " (☓‿‿☓) Execution time was "`expr $end - $start` seconds.

    fi


        ## RESPONDING
        cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > ~/.zen/tmp/coucou/${MOATS}.official.swallow &
        echo "HTTP 1.1 PROTOCOL DOCUMENT READY"
        echo "${MOATS} -----> PAGE AVAILABLE -----> http://${myHOST}:${PORT}"

        end=`date +%s`
        echo $type" (J‿‿J) Execution time was "`expr $end - $start` seconds.



    fi ## END IF SALT

##############################################
# /?player=PLAYER&APPNAME=WHAT&OBJ=VAL
##############################################
 if [[ ${arr[0]} == "player" ]]; then

        PLAYER=$(urldecode ${arr[1]} | xargs)
        APPNAME=$(urldecode ${arr[2]} | xargs)
        WHAT=$(urldecode ${arr[3]} | xargs)

        OBJ=$(urldecode ${arr[4]} | xargs)
        VAL=$(urldecode ${arr[5]} | xargs)

        echo "- $PLAYER - $APPNAME : $WHAT $OBJ $VAL"

        ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)
        [[ ! $ASTRONAUTENS ]] && (echo "$HTTPCORS UNKNOWN PLAYER $PLAYER - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

##############################################
# PAY : /?player=PLAYER&pay=1&dest=G1PUB
##############################################
        if [[ $APPNAME == "pay" ]]; then
            echo "${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${WHAT} -p ${VAL} -c 'Bro' -m"
            echo "$HTTPCORS" > ~/.zen/tmp/pay.log
            ${MY_PATH}/tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${WHAT} -p ${VAL} -c 'Bro' -m 2>&1 >> ~/.zen/tmp/pay.log
            cat ~/.zen/tmp/pay.log | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo "(G_G ) PAYING Execution time was "`expr $end - $start` seconds.
            continue
        fi

##############################################
# MOATUBE : /?player=PLAYER&moa=json&tag=FILTER
##############################################
        if [[ $APPNAME == "moa" ]]; then

                [[ ! $VAL ]] && VAL="G1CopierYoutube"
                echo "EXPORT MOATUBE $PLAYER $VAL"

                echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}.$PLAYER.http
                sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}.$PLAYER.http

                tiddlywiki --load ~/.zen/game/players/support@qo-op.com/ipfs/moa/index.html --output ~/.zen/tmp/ --render '.' "$PLAYER.moatube.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "[tag[$VAL]]"

                cat ~/.zen/tmp/$PLAYER.moatube.json >> ~/.zen/tmp/${MOATS}.$PLAYER.http
                cat ~/.zen/tmp/${MOATS}.$PLAYER.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

                continue
        fi
fi
##############################################
# /?player=PLAYER&APPNAME=WHAT&OBJ=VAL
##############################################

###################################################################################################
###################################################################################################
# API TWO : ?qrcode=G1PUB
    if [[ ${arr[0]} == "qrcode" ]]; then
        ## Astroport.ONE local use QRCODE Contains ${WHAT} G1PUB
        QRCODE=$(echo $URL | cut -d ' ' -f2 | cut -d '=' -f 2 | cut -d '&' -f 1)   && echo "QRCODE : $QRCODE"
        g1pubpath=$(grep $QRCODE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
        PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

        ## FORCE LOCAL USE ONLY. Remove to open 1234 API
        [[ ! -d ~/.zen/game/players/${PLAYER} || ${PLAYER} == "" ]] && (echo "$HTTPCORS ERROR - QRCODE - NO ${PLAYER} ON BOARD !!"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        ## USE SECOND HTTP SERVER TO RECEIVE PASS

        ## Demande de copie d'une URL reçue.
        if [[ ${arr[2]} == "url" ]]; then
            wsource="${arr[3]}"
             [[ ${arr[4]} == "type" ]] && CHOICE="${arr[5]}" || CHOICE="Youtube"

            ## CREATION TIDDLER "G1Voeu" G1CopierYoutube
            # CHOICE = "Video" Page MP3 Web
            ~/.zen/Astropor.ONE/ajouter_media.sh "$(urldecode $wsource)" "$PLAYER" "$CHOICE" &

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

            (echo "$HTTPCORS OK - ~/.zen/tmp/${WHAT}.${MOATS}.import.json WORKS IF YOU MAKE THE WISH voeu 'AstroAPI'"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        else

            (echo "$HTTPCORS ERROR - ${arr[2]} - ${arr[3]} UNKNOWN"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        fi

    fi


done
exit 0
