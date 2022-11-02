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

mkdir -p ~/.zen/tmp/coucou/

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 1234' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "ERROR - API Server Already Running -  http://$myIP:1234/?salt=totodu56&pepper=totodu56 " && exit 1
## NOT RUNNING TWICE

# Some client needs to respect that
HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: \*
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"

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
echo "TESTCRAFT http://$myIP:1234/?salt=totodu56&pepper=totodu56&testcraft=on&nodeid=12D3KooWK1ACupF7RD3MNvkBFU9Z6fX11pKRAR99WDzEUiYp5t8j&dataid=QmPXhrqQrS1bePKJUPH9cJ2qe4RrNjaJdRXaJzSjxWuvDi"
echo "_________________________________________________________"

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

while true; do
    start=`date +%s`

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    ## CHANGE NEXT PORT (HERE YOU CREATE A SOCKET QUEUE)
    [ ${PORT} -le 12345 ] && PORT=$((PORT+${RANDOM:0:3})) || PORT=$((PORT-${RANDOM:0:3}))
    portinuse=$(ps auxf --sort=+utime | grep -w ${PORT} | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
    [[ $portinuse ]] && echo "$portinuse" && continue
                ## RANDOM PORT SWAPPINESS AVOIDING COLLISION

    ## CHECK 12345 PORT RUNNING (PUBLISHING IPNS SWARM MAP)
    maprunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 12345' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
    [[ ! $maprunning ]] && ($MY_PATH/_12345.sh &) && echo '(ᵔ◡◡ᵔ) LAUNCHING http://'$myIP:'12345 (ᵔ◡◡ᵔ)'

    ############### IPNS SESSION KEY TRY LATER
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
    echo "ASTROPORT 1234 UP & RUNNING.......................... http://$myIP:1234 PORT"
    echo "$MOATS NEXT COMMAND DELIVERY PAGE http://$myIP:${PORT}"

    ###############    ###############    ###############    ############### templates/index.http
    # REPLACE myIP in http response template (fixing next API meeting point)
    sed "s~127.0.0.1:12345~$myIP:${PORT}~g" $HOME/.zen/Astroport.ONE/templates/index.http > ~/.zen/tmp/coucou/${MOATS}.myIP.http
    sed -i "s~127.0.0.1~$myIP~g" ~/.zen/tmp/coucou/${MOATS}.myIP.http
    sed -i "s~:12345~:${PORT}~g" ~/.zen/tmp/coucou/${MOATS}.myIP.http
    sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/tmp/coucou/${MOATS}.myIP.http ## NODE PUBLISH HOSTED WHAT'S JSON
    sed -i "s~_HOSTNAME_~$(hostname)~g" ~/.zen/tmp/coucou/${MOATS}.myIP.http ## HOSTNAME
    ###############    ###############    ###############    ###############
    ############################################################################
    ## SERVE LANDING REDIRECT PAGE ~/.zen/tmp/coucou/${MOATS}.myIP.http on PORT 1234 (LOOP BLOCKING POINT)
    ############################################################################
    URL=$(cat $HOME/.zen/tmp/coucou/${MOATS}.myIP.http | nc -l -p 1234 -q 1 | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    ############################################################################
    echo "URL" > ~/.zen/tmp/coucou/${MOATS}.url ## LOGGING URL
    ############################################################################
    start=`date +%s`

    ############################################################################
    ## / CONTACT - PUBLISH HTML HOMEPAGE (ADD HTTP HEADER)
    if [[ $URL == "/" ]]; then
        echo "/ CONTACT :  http://$myIP:1234"
        echo "___________________________ Preparing register.html"
        echo "$HTTPCORS" > ~/.zen/tmp/coucou/${MOATS}.index.redirect ## HTTP 1.1 HEADER + HTML BODY
sed "s~127.0.0.1~$myIP~g" $HOME/.zen/Astroport.ONE/templates/register.html >> ~/.zen/tmp/coucou/${MOATS}.index.redirect
sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/tmp/coucou/${MOATS}.index.redirect
sed -i "s~_HOSTNAME_~$(hostname)~g" ~/.zen/tmp/coucou/${MOATS}.index.redirect

        cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
        end=`date +%s`
        echo " (☓‿‿☓) Execution time was "`expr $end - $start` seconds.
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

    [[ ${arr[0]} == "" || ${arr[1]} == "" ]] && (echo "$HTTPCORS ERROR - MISSING DATA" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

########## CHECK GET PARAM NAMES
###################################################################################################
###################################################################################################
# API ZERO ## Made In Zion & La Bureautique
    if [[ ${arr[0]} == "salt" ]]; then
        ################### KEY GEN ###################################
        echo ">>>>>>>>>>>>>> Application LaBureautique >><< TYPE = $TYPE <<<<<<<<<<<<<<<<<<<<"

        SALT=$(urldecode ${arr[1]} | xargs);
        [[ ! $SALT ]] && (echo "$HTTPCORS ERROR - SALT MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        PEPPER=$(urldecode ${arr[3]} | xargs)
        [[ ! $PEPPER ]] && (echo "$HTTPCORS ERROR - PEPPER MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        TYPE=$(urldecode ${arr[4]} | xargs)
        WHAT=$(urldecode ${arr[5]} | xargs)

        ## SAVE "salt" "pepper" DEBUG REMOVE OR PASS ENCRYPT FOR SECURITY REASON
        echo "PLAYER CREDENTIALS : \"$SALT\" \"$PEPPER\""
        echo "\"$SALT\" \"$PEPPER\"" > ~/.zen/tmp/coucou/${MOATS}.secret.june

        # CALCULATING ${MOATS}.secret.key + G1PUB
        ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/tmp/coucou/${MOATS}.secret.key  "$SALT" "$PEPPER"
        G1PUB=$(cat ~/.zen/tmp/coucou/${MOATS}.secret.key | grep 'pub:' | cut -d ' ' -f 2)
        [[ ! ${G1PUB} ]] && (echo "$HTTPCORS ERROR - KEYGEN  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        echo "G1PUB : ${G1PUB}"

        ## CALCULATING IPNS ADDRESS
        ipfs key rm ${G1PUB} > /dev/null 2>&1
        rm -f ~/.zen/tmp/coucou/${MOATS}.${G1PUB}.ipns.key
        ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/coucou/${MOATS}.${G1PUB}.ipns.key "$SALT" "$PEPPER"
        ASTRONAUTENS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/coucou/${MOATS}.${G1PUB}.ipns.key )
        echo "ASTRONAUTE TW : http://$myIP:8080/ipns/${ASTRONAUTENS}"
        echo
        ################### KEY GEN ###################################
    # Get PLAYER wallet amount
    ( ## SUB PROCESS
        COINS=$($MY_PATH/tools/jaklis/jaklis.py -k ~/.zen/tmp/coucou/${MOATS}.secret.key balance)
        echo "+++ WALLET BALANCE _ $COINS (G1) _"
        end=`date +%s`
        echo "G1WALLET  (☓‿‿☓) Execution time was "`expr $end - $start` seconds.
    ) &
########################################
        ## ARCHIVE TOCTOC WHATS & KEEPS LOGS CLEAN
        mkdir -p ~/.zen/game/players/.toctoc/
        ISTHERE=$(ls -t ~/.zen/game/players/.toctoc/*.${G1PUB}.ipns.key 2>/dev/null | tail -n 1)
        TTIME=$(echo $ISTHERE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
        if [[ ! $ISTHERE ]]; then
            echo "WHAT 1ST TOCTOC : $MOATS"
            cp ~/.zen/tmp/coucou/${MOATS}.* ~/.zen/game/players/.toctoc/
        else ## KEEP 1ST CONTACT ONLY
            OLDONE=$(ls -t ~/.zen/tmp/coucou/*.${G1PUB}.ipns.key | tail -n 1)
            DTIME=$(echo $OLDONE | rev | cut -d '.' -f 4 | cut -d '/' -f 1  | rev)
            [[ $DTIME != $MOATS ]] && rm ~/.zen/tmp/coucou/$DTIME.*
        fi

## TYPE SLECTION  ########################
        # MESSAGING
        if [[ $TYPE == "messaging" ]]; then
            ( ## SUB PROCESS
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

            ### REPONSE=$(cat ~/.zen/tmp/coucou/${MOATS}.messaging.json | ipfs add -q)
            ###   ipfs name publish --allow-offline --key=${PORT} /ipfs/$REPONSE
            ###   echo "SESSION http://$myIP:8080/ipns/$SESSIONNS "

            cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo "$TYPE (☓‿‿☓) Execution time was "`expr $end - $start` seconds.
            ) &

            end=`date +%s`
            echo " (☓‿‿☓) Execution time was "`expr $end - $start` seconds.
            continue
        fi
        ######################## MESSAGING END

########################################
# G1PUB -> Open Gchange Profile
########################################
        if [[ "$TYPE" == "g1pub" && ${arr[7]} == "" ]]; then
            ## NO EMAIL = REDIRECT TO GCHANGE PROFILE
            sed "s~_TWLINK_~https://www.gchange.fr/#/app/user/${G1PUB}/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/coucou/${MOATS}.index.redirect

            ###  REPONSE=$(echo https://www.gchange.fr/#/app/user/${G1PUB}/ | ipfs add -q)
            ### ipfs name publish --allow-offline --key=${PORT} /ipfs/$REPONSE
            ### echo "SESSION http://$myIP:8080/ipns/$SESSIONNS "

            cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo $TYPE" (☓‿‿☓) Execution time was "`expr $end - $start` seconds.
            continue
        fi
########################################
########################################
########################################
#TESTCRAFT=ON nodeid dataid
########################################
########################################
        if [[ "$TYPE" == "testcraft" ]]; then
        ( # SUB PROCESS
            ## RECORD DATA MADE IN BROWSER (JSON)
            SALT=$(urldecode ${arr[1]} | xargs)
            PEPPER=$(urldecode ${arr[3]} | xargs)
            NODEID=$(urldecode ${arr[7]} | xargs)
            DATAID=$(urldecode ${arr[9]} | xargs)

            ## COULD BE A RAW FILE, AN HTML, A JSON
            echo "$TYPE IS $WHAT"

            mkdir -p ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}

            echo "TRYING  ipfs --timeout 3s cat /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json"
            ipfs --timeout 3s cat /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json
echo "" > ~/.zen/tmp/.ipfsgw.bad.twt # TODO move in 20h12.sh
            if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json ]]; then

                echo "IPFS TIMEOUT >>> (°▃▃°) $DATAID MISSING GATEWAY RUSH (°▃▃°)"

                # official ipfs best gateway from https://luke.lol/ipfs.php
                for nicegw in https://ipns.co/:hash https://dweb.link/ipfs/:hash https://ipfs.yt/ipfs/:hash https://ipfs.io/ipfs/:hash https://ipfs.fleek.co/ipfs/:hash https://ipfs.best-practice.se/ipfs/:hash https://gateway.pinata.cloud/ipfs/:hash https://gateway.ipfs.io/ipfs/:hash https://cf-ipfs.com/ipfs/:hash https://cloudflare-ipfs.com/ipfs/:hash; do
                    [[ $(cat ~/.zen/tmp/.ipfsgw.bad.twt | grep -w $nicegw) ]] && echo "<<< BAD GATEWAY >>>  $nicegw" && continue
                    gum=$(echo  "$nicegw" | sed "s~:hash~$DATAID~g")
                    echo "LOADING $gum"
                    curl -m 3 -so ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json "$gum"
                    [[ $? != 0 ]] && echo "(✜‿‿✜) $nicegw BYPASSING"; echo

                    if [[ -s ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json ]]; then
                    if [[ ! $(cat ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json | jq -r) ]]; then
                        echo " (╥☁╥ ) - $nicegw ERROR - (╥☁╥ )"
                        # NOT A JSON AVOID BANISHMENT
                        echo $nicegw >> ~/.zen/tmp/.ipfsgw.bad.twt
                        continue
                    else
                        ## GOT IT !! IPFS ADD
                        ipfs add ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json
                        ## + TW ADD
                        echo "(♥‿‿♥) $nicegw OK"; echo
                        break
                    fi
                    echo " (╥☁╥ ) - $nicegw TIMEOUT - (╥☁╥ )"
                    continue
                    fi
                done
            fi ## NO DIRECT IPFS - GATEWAY TRY

           ## REALLY NO FILE FOUND !!!
           [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json ]] && \
           echo "$HTTPCORS ERROR (╥☁╥ ) - $DATAID TIMEOUT - (╥☁╥ )" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &



            ## REPONSE ON PORT
                echo "$HTTPCORS" > ~/.zen/tmp/coucou/${MOATS}.index.redirect
                sed -i "s~text/html~application/json~g"  ~/.zen/tmp/coucou/${MOATS}.index.redirect
                cat ~/.zen/tmp/${IPFSNODEID}/${TYPE}/${NODEID}/${MOATS}/data.json >> ~/.zen/tmp/coucou/${MOATS}.index.redirect

                cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

            ## REPONSE ON IPFSNODEID
                (
                    echo "¯\_༼<O͡〰o>༽_/¯ $IPFSNODEID $PLAYER SIGNALING"
                    ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )
                    ipfs name publish --allow-offline /ipfs/$ROUTING
                    echo "DONE"
                    end=`date +%s`
                    echo "MAP PUBLISHING (o‿‿o) Execution time was "`expr $end - $start` seconds.
                ) &

            end=`date +%s`
            echo "(|$TYPE|) Execution time was "`expr $end - $start` seconds.
        ) &

            end=`date +%s`
            echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds.
            continue
        fi

##############################################
# DEFAULT (NO REDIRECT DONE YET) CHECK OFFICIAL GATEWAY
##############################################
        TWIP=$(hostname)
        # OFFICIAL Gateway ( increase waiting time ) - MORE SECURE
        if [[ $TYPE == "official" ]]; then

            echo "SEARCHING FOR OFFICIAL TW GW... $LIBRA/ipns/${ASTRONAUTENS} ($YOU)"

            ## GETTING LAST TW via IPFS or HTTP GW
            [[ $YOU ]] && echo "http://$myIP:8080/ipns/${ASTRONAUTENS} ($YOU)" && ipfs --timeout 12s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/coucou/${MOATS}.astroindex.html
            [[ ! -s ~/.zen/tmp/coucou/${MOATS}.astroindex.html ]] && echo "$LIBRA/ipns/${ASTRONAUTENS}" && curl -m 12 -so ~/.zen/tmp/coucou/${MOATS}.astroindex.html "$LIBRA/ipns/${ASTRONAUTENS}"

            # DEBUG
            # echo "tiddlywiki --load ~/.zen/tmp/coucou/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'"
            # echo "cat ~/.zen/tmp/miz.json | jq -r .[].secret"

            if [[ -s ~/.zen/tmp/coucou/${MOATS}.astroindex.html ]]; then
                tiddlywiki --load ~/.zen/tmp/coucou/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
                OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)
                [[ ! $OLDIP ]] && (echo "$HTTPCORS 501 ERROR - SORRY - YOUR TW IS OUT OF SWARM#0 - CONTINUE " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds. && continue
                echo "TW is on $OLDIP"
                # LOCKED TW BECOMING ACTIVE GATEWAY
                if [[ $OLDIP == "_SECRET_" ]]; then
                    echo "_SECRET_ TW PUSHING TW" ## BECOMING OFFICIAL BECOME R/W TW
                    sed -i "s~_SECRET_~${myIP}~g" ~/.zen/tmp/coucou/${MOATS}.astroindex.html

                    # GET PLAYER FORM Dessin de $PLAYER
                    tiddlywiki --load ~/.zen/tmp/coucou/${MOATS}.astroindex.html --output ~/.zen/tmp --render '.' 'MOA.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[moa]]'
                    PLAYER=$(cat ~/.zen/tmp/MOA.json | jq -r .[].title | rev | cut -d ' ' -f 1 | rev)

                    [[ ! $PLAYER ]] && (echo "$HTTPCORS ERROR - CANNOT FIND PLAYER IN TW - CONTINUE " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds. && continue

                    ##  CREATE $PLAYER IPNS KEY (for next 20h12)
                    ipfs key import ${PLAYER} -f pem-pkcs8-cleartext ~/.zen/tmp/coucou/${MOATS}.${G1PUB}.ipns.key
                    [[ ! -d ~/.zen/game/players/$PLAYER/ipfs/moa ]] && mkdir -p ~/.zen/game/players/$PLAYER/ipfs/moa/
                    # cp ~/.zen/tmp/coucou/${MOATS}.astroindex.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

                    echo "## PUBLISHING ${PLAYER} /ipns/$ASTRONAUTENS/"
                    IPUSH=$(ipfs add -Hq ~/.zen/tmp/coucou/${MOATS}.astroindex.html | tail -n 1)
                    [[ $IPUSH ]] && ipfs name publish --key=${PLAYER} /ipfs/$IPUSH 2>/dev/null
                    ## MEMORISE PLAYER Ŋ1 ZONE (TODO compare with VISA.new.sh)
                    echo "$PLAYER" > ~/.zen/game/players/$PLAYER/.player
                    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/.g1pub
                    OLDIP=${myIP}
                fi
                # ACTIVE GATEWAY
                TWIP=$OLDIP
                echo "***********  OFFICIAL LOGIN GOES TO $TWIP"
            else
                (echo "$HTTPCORS ERROR - NO ACTIVE TW FOUND - $(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.*)" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds. && continue
            fi
        else
            echo "***** SEARVING $TWIP IN READER MODE *****"

        fi ## official

                ## 302 REDIRECT
                cat ~/.zen/Astroport.ONE/templates/index.302 >> ~/.zen/tmp/coucou/${MOATS}.index.redirect
                sed -i "s~_TWLINK_~http://$TWIP:8080/ipns/${ASTRONAUTENS}~g" ~/.zen/tmp/coucou/${MOATS}.index.redirect

        ## RESPONDING
        cat ~/.zen/tmp/coucou/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > ~/.zen/tmp/coucou/${MOATS}.official.swallow &
        echo "HTTP 1.1 PROTOCOL DOCUMENT READY"
        cat ~/.zen/tmp/coucou/${MOATS}.index.redirect
        echo "$MOATS -----> PAGE AVAILABLE -----> http://$myIP:${PORT}"

        #echo "${ASTRONAUTENS}" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

        ## CHECK IF ALREADY EXISTING WHAT
        # IF NOT = BATCH CREATE TW
        end=`date +%s`
        echo $type" (☓‿‿☓) Execution time was "`expr $end - $start` seconds.

    fi ## END IF SALT


###################################################################################################
###################################################################################################
# API ONE : ?salt=PHRASE%20UNE&pepper=PHRASE%20DEUX&g1pub=on&email/elastic=ELASTICID&pseudo=PROFILENAME
    if [[ (${arr[6]} == "email" || ${arr[6]} == "elastic") && ${arr[7]} != "" ]]; then

        [[ $TYPE != "g1pub" ]] && (echo "$HTTPCORS ERROR - BAD COMMAND $TYPE" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds. && continue

        start=`date +%s`

        SALT=$(urldecode ${arr[1]} | xargs)
        PEPPER=$(urldecode ${arr[3]} | xargs)
        WHAT=$(urldecode ${arr[7]} | xargs)
        PSEUDO=$(urldecode ${arr[9]} | xargs)

        [[ ! $WHAT ]] && (echo "$HTTPCORS ERROR - MISSING $WHAT FOR WHAT CONTACT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds. &&  continue

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
                    echo "$HTTPCORS OK - ASTRONAUT $PSEUDO IPFS FILESYSTEM CREATION [$SALT + $PEPPER] ($WHAT)
                    <br>- BUILDING TW - PLEASE 'ASK BIOS AGAIN' IN A WHILE http://$myIP:1234/ " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
                     echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds.
                    continue
               else
                    # ASTRONAUT EXISTING WHAT
                    CHECK=$(cat ~/.zen/game/players/$WHAT/secret.june | grep -w "$SALT")
                    [[ $CHECK ]] && CHECK=$(cat ~/.zen/game/players/$WHAT/secret.june | grep -w "$PEPPER")
                    [[ ! $CHECK ]] && (echo "$HTTPCORS ERROR - WHAT $WHAT ALREADY EXISTS"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $end - $start` seconds. &&  continue
               fi

                 ###################################################################################################
                end=`date +%s`
                echo " (☓‿‿☓) Execution time was "`expr $end - $start` seconds.

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
        [[ ! -d ~/.zen/game/players/$WHAT || $WHAT == "" ]] && (echo "$HTTPCORS ERROR - QRCODE - NO $WHAT ON BOARD !!"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue

        ## USE SECOND HTTP SERVER TO RECEIVE PASS

        [[ ${arr[2]} == "" ]] && (echo "$HTTPCORS ERROR - QRCODE - MISSING ACTION"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
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

            (echo "$HTTPCORS OK - ~/.zen/tmp/${WHAT}.${MOATS}.import.json WORKS IF YOU MAKE THE WISH voeu 'AstroAPI'"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && continue
        fi

    fi


done
exit 0
