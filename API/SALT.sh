################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: SALT & PEPPER - PRIVATE KEY AUTH
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

start=`date +%s`

PORT=$1 THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9
SALT=$THAT
PEPPER=$THIS

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"
mkdir -p ~/.zen/tmp/${MOATS}/

[[ ! $APPNAME || $SALT == "pepper" ]] \
    && echo "NO APPNAME - BAD APP - CONTINUE" \
    &&  (echo "$HTTPCORS ERROR - BAD CREDENTIALS" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
    && exit 1

############################################################################
# WRITING API # SALT # PEPPER # MAKING THE KEY EXIST #########
################### KEY GEN ###################################
echo ">>>>>>>>>>>>>> Application LaBureautique >><< APPNAME = $APPNAME <<<<<<<<<<<<<<<<<<<<"

[[ ! $SALT ]] && (echo "$HTTPCORS ERROR - SALT MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
[[ ! $PEPPER || ${PEPPER:0:2} == "G1" ]] && (echo "$HTTPCORS ERROR - BAD OR PEPPER MISSING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

## SAVE "salt" "pepper" DEBUG REMOVE OR PASS ENCRYPT FOR SECURITY REASON
echo "PLAYER : \"$SALT\" \"$PEPPER\" : $APPNAME ($WHAT)"
echo "\"$SALT\" \"$PEPPER\"" > ~/.zen/tmp/${MOATS}/${MOATS}.secret.june

# CALCULATING ${MOATS}.secret.key + G1PUB
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${MOATS}.secret.key  "$SALT" "$PEPPER"
G1PUB=$(cat ~/.zen/tmp/${MOATS}/${MOATS}.secret.key | grep 'pub:' | cut -d ' ' -f 2)
[[ ! ${G1PUB} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - KEYGEN  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
echo "G1PUB : ${G1PUB}"

## CALCULATING ${MOATS}.${G1PUB}.ipns.key ADDRESS
ipfs key rm ${G1PUB} > /dev/null 2>&1
rm -f ~/.zen/tmp/${MOATS}/${MOATS}.${G1PUB}.ipns.key
${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${MOATS}.${G1PUB}.ipns.key "$SALT" "$PEPPER"
ASTRONAUTENS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${MOATS}.${G1PUB}.ipns.key )
[[ ! ${ASTRONAUTENS} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - ASTRONAUTENS  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

echo "TW ADDRESS : $myIPFS/ipns/${ASTRONAUTENS}"
echo

########################################
## APPNAME SELECTION  ########################
########################################

##############################################
# MESSAGING : GET MESSAGE FROM GCHANGE+
##############################################
if [[ $APPNAME == "messaging" ]]; then

    ( ## & SUB PROCESS

    echo "Extracting ${G1PUB} messages..."
    ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${MOATS}.secret.key read -n 10 -j  > ~/.zen/tmp/${MOATS}/messin.${G1PUB}.json
    [[ ! -s ~/.zen/tmp/${MOATS}/messin.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/${MOATS}/messin.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/${MOATS}/messin.${G1PUB}.json

    ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${MOATS}.secret.key read -n 10 -j -o > ~/.zen/tmp/${MOATS}/messout.${G1PUB}.json
    [[ ! -s ~/.zen/tmp/${MOATS}/messout.${G1PUB}.json || $(grep  -v -E 'Aucun message à afficher' ~/.zen/tmp/${MOATS}/messout.${G1PUB}.json) == "True" ]] && echo "[]" > ~/.zen/tmp/${MOATS}/messout.${G1PUB}.json

    echo "Creating messages In/Out JSON ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json"
    echo '[' > ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json
    cat ~/.zen/tmp/${MOATS}/messin.${G1PUB}.json >> ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json
    echo "," >> ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json
    cat ~/.zen/tmp/${MOATS}/messout.${G1PUB}.json >> ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json
    echo ']' >> ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json

    ## ADDING HTTP/1.1 PROTOCOL HEADER
    echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
    sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
    cat ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json >> ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect

    ## SEND REPONSE PROCESS IN BACKGROUD
    ( cat ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 && rm ~/.zen/tmp/${MOATS}/${MOATS}* ) &
        #~ ( ## USING IPNS SESSION KEY
        #~ REPONSE=$(cat ~/.zen/tmp/${MOATS}/${MOATS}.messaging.json | ipfs add -q)
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
    exit 0
fi
######################## MESSAGING END

########################################
# G1PUB : REDIRECT TO GCHANGE OR TW + EMAIL => CREATE PLAYER !
########################################
if [[ "$APPNAME" == "g1pub" ]]; then

    if [[ "$OBJ" != "email" ]]; then
        ## WITH NO EMAIL -> Open Gchange Profile & Update TW cache
        [[ ${WHAT} == "astro" ]] && REPLACE="https://$myTUBE/ipns/${ASTRONAUTENS}" \
        || REPLACE="$myGCHANGE/#/app/user/${G1PUB}"
        echo ${REPLACE}

        ## REDIRECT TO TW OR GCHANGE PROFILE
        sed "s~_TWLINK_~${REPLACE}/~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
        ## USED BY https://git.p2p.legal/La_Bureautique/zeg1jeux/src/branch/main/lib/Fred.class.php#L81
        echo "url='"${REPLACE}"'" >> ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect

        ###  REPONSE=$(echo $myGCHANGE/#/app/user/${G1PUB}/ | ipfs add -q)
        ### ipfs name publish --allow-offline --key=${PORT} /ipfs/$REPONSE
        ### echo "SESSION ${myIPFS}/ipns/$SESSIONNS "
        (
        cat ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
        ${MY_PATH}/../tools/TW.cache.sh ${ASTRONAUTENS} ${MOATS}
        rm ~/.zen/tmp/${MOATS}/${MOATS}*
        ) &
        end=`date +%s`
        echo $APPNAME" (0‿‿0) ${WHAT} Execution time was "`expr $end - $start` seconds.
        exit 0

    else

        # CREATE PLAYER : ?salt=PHRASE%20UNE&pepper=PHRASE%20DEUX&g1pub=on&email=EMAIL&pseudo=PROFILENAME
        # WHAT can contain urlencoded FullURL
        EMAIL="${VAL,,}" # lowercase

        [[ ! ${EMAIL} ]] && (echo "$HTTPCORS ERROR - MISSING ${EMAIL} FOR ${WHAT} CONTACT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0

        ## CHECK WHAT IS EMAIL
        if [[ $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            echo "VALID EMAIL OK"
        else
            echo "BAD EMAIL"
            (echo "$HTTPCORS KO ${EMAIL} : bad '"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 0
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
            #~ echo "VISA.new : \"$SALT\" \"$PEPPER\" \"${EMAIL}\" \"$PSEUDO\" \"${WHAT}\"" > ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt
            ${MY_PATH}/../RUNTIME/VISA.new.sh "$SALT" "$PEPPER" "${EMAIL}" "$PSEUDO" "${WHAT}" >> ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt

            #~ ${MY_PATH}/../tools/mailjet.sh "${EMAIL}" ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt "LOG ZenCard creation" ## Send VISA.new log to EMAIL

            echo "ASTROID PIN=${PASS}, operate on all La♥Box Web3 ẐenStation (WWW : https://astroport.copylaradio.com)"
            ## :: TRICK :: EXECUTE LAST VISA.new.sh output LINE : export above VARs
            $(cat ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt | tail -n 1)
            echo "export ASTROTW=/ipns/$ASTRONAUTENS ASTROG1=$G1PUB ASTROMAIL=$PLAYER ASTROFEED=$FEEDNS PASS=$PASS"

            BILLETNAME=$(echo "$SALT" | sed 's/ /_/g')
            #~ mpack -a -s "La♥Box : ASTROID :+: TW :+: " -d ~/.zen/tmp/${MOATS}/intro.txt \
                #~ ~/.zen/G1BILLET/tmp/g1billet/${PASS}/${BILLETNAME}.BILLET.jpg ${PLAYER}

            end=`date +%s`
            dur=`expr $end - $startvisa`
            echo ${MOATS}:${G1PUB}:${PLAYER}:VISA:$dur >> ~/.zen/tmp/${IPFSNODEID}/_timings
            cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1
            ) &

            echo "$HTTPCORS
            <meta http-equiv='refresh' content='30; url=\""${myIPFS}"/ipns/"${ASTRONAUTENS}"\"'/>
            <h1>ASTRONAUTE $PSEUDO</h1>
            <br>KEY : $SALT:$PEPPER:${EMAIL}
            <br>TW : ${myIPFS}/ipns/${ASTRONAUTENS}
            <br>STATION : ${myIPFS}/ipns/$IPFSNODEID<br><br>please wait....<br>
            export ASTROTW=/ipns/${ASTRONAUTENS} ASTROG1=${G1PUB} ASTROMAIL=${EMAIL} ASTROIPFS=${myIPFS}" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

            exit 0

       else

            # ASTRONAUT EXISTING ${EMAIL}
            CHECK=$(cat ~/.zen/game/players/${EMAIL}/secret.june | grep -w "$SALT")
            [[ $CHECK ]] && CHECK=$(cat ~/.zen/game/players/${EMAIL}/secret.june | grep -w "$PEPPER")
            [[ ! $CHECK ]] && (echo "$HTTPCORS - WARNING - PLAYER ${EMAIL} ALREADY HERE"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0

       fi

         ###################################################################################################
        end=`date +%s`
        echo " (☓‿‿☓) Execution time was "`expr $end - $start` seconds.

    fi

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
    OBJID=$OBJ
    DATAID=$VAL

    ## export PLAYER
    ${MY_PATH}/../tools/TW.cache.sh ${ASTRONAUTENS} ${MOATS}

    ## IS IT INDEX JSON
    echo "${PLAYER} $APPNAME IS ${WHAT}"
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}

    [[ $WHAT == "on" ]] && WHAT="json" # data mimetype (default "on" = json)

    ## TODO : modify timeout if isLAN or NOT
    [[ $isLAN ]] && WAIT=3 || WAIT=12
    echo "1ST TRY : ipfs --timeout ${WAIT}s cat --progress=false /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT}"
    ipfs --timeout ${WAIT}s cat --progress=false /ipfs/$DATAID  > ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT}

echo "" > ~/.zen/tmp/.ipfsgw.bad.twt # TODO move in 20h12.sh

    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} ]]; then

        echo "IPFS TIMEOUT >>> (°▃▃°) $DATAID STILL MISSING GATEWAY BANGING FOR IT (°▃▃°)"
        array=(${myIPFSGW}/ipfs/:hash https://ipns.co/:hash https://dweb.link/ipfs/:hash https://ipfs.io/ipfs/:hash https://ipfs.fleek.co/ipfs/:hash https://ipfs.best-practice.se/ipfs/:hash https://gateway.pinata.cloud/ipfs/:hash https://gateway.ipfs.io/ipfs/:hash https://cf-ipfs.com/ipfs/:hash https://cloudflare-ipfs.com/ipfs/:hash)
        # size=${#array[@]}; index=$(($RANDOM % $size)); echo ${array[$index]} ## TODO CHOOSE RANDOM

        # official ipfs best gateway from https://luke.lol/ipfs.php
        for nicegw in ${array[@]}; do

            [[ $(cat ~/.zen/tmp/.ipfsgw.bad.twt | grep -w $nicegw) ]] && echo "<<< BAD GATEWAY >>>  $nicegw" && exit 0
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
                    exit 0

                else
                    ## GOT IT !! IPFS ADD
                    ipfs pin add /ipfs/${GOAL}
                    ## + TW ADD (new_file_in_astroport.sh)

                    echo "(♥‿‿♥) FILE UPLOAD OK"; echo
                    break

                fi

            else

                echo " (⇀‿‿↼) - NO FILE - (⇀‿‿↼)"
                exit 0

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
        echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
        sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
        cat ~/.zen/tmp/${IPFSNODEID}/${APPNAME}/${PLAYER}/${MOATS}.data.${WHAT} >> ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect

        (cat ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 && rm ~/.zen/tmp/${MOATS}/${MOATS}.* ) &

    ## REPONSE ON IPFSNODEID
        (
            start=`date +%s`
            echo "¯\_༼<O͡〰o>༽_/¯ $IPFSNODEID $PLAYER SIGNALING"
            ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )
            ipfs name publish /ipfs/$ROUTING
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
    exit 0
fi

##############################################
# PAY : /?salt=SALT&pepper=PEPPER&pay=1&dest=G1PUB APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9
##############################################
if [[ $APPNAME == "pay" ]]; then
(
    echo "$HTTPCORS" > ~/.zen/tmp/$PLAYER.pay.$WHAT.http

    if [[ $WHAT =~ ^[0-9]+$ ]]; then

        echo "${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/tmp/${MOATS}/${MOATS}.secret.key pay -a ${WHAT} -p ${VAL} -c 'Bro'"
        ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/tmp/${MOATS}/${MOATS}.secret.key" "${WHAT}" "${VAL}" "Bro"
        echo "PAY4SURE " >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http

    fi

    if [[ "$WHAT" == "history" ]]; then
        sed -i "s~text/html~application/json~g"  ~/.zen/tmp/$PLAYER.pay.$WHAT.http
        ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 \
        ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${MOATS}.secret.key history -j >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http
    fi

    if [[ "$WHAT" == "get" ]]; then
        sed -i "s~text/html~application/json~g"  ~/.zen/tmp/$PLAYER.pay.$WHAT.http
        ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 \
        ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${MOATS}.secret.key get >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http
    fi

    if [[ "$WHAT" == "balance" ]]; then
            ~/.zen/Astroport.ONE/tools/timeout.sh -t 20 \
            ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${MOATS}.secret.key balance >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http
    fi

    cat ~/.zen/tmp/$PLAYER.pay.$WHAT.http
    (cat ~/.zen/tmp/$PLAYER.pay.$WHAT.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 && rm ~/.zen/tmp/$PLAYER.pay.$WHAT.http ) &
    end=`date +%s`
    echo "(G_G ) G1BANK Operation time was "`expr $end - $start` seconds.
    exit 0
) &
fi

##############################################
# FRIEND  ★ &friend=G1PUB&stars=1 // APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9
##############################################
if [[ $APPNAME == "friend" ]]; then

    ## CHECK IF ASKING FRIEND TW EXISTS
    #~ ipfs --timeout 60s ls /ipns/${ASTRONAUTENS}
    #~ [ $? != 0 ] && echo "BAD VISITOR" && exit 0

    g1friend=${WHAT}
    stars=${VAL:-1} // Default 1 ★

    $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${MOATS}.secret.key stars -p $g1friend -n $stars > ~/.zen/tmp/${MOATS}/${MOATS}.log

    (
        echo "$HTTPCORS $(cat ~/.zen/tmp/${MOATS}/${MOATS}.log)"| nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    ) &

    rm ~/.zen/tmp/${MOATS}/${MOATS}.*
    end=`date +%s`
    echo $APPNAME "(☉_☉ ) ${MESTAR} Execution time was "`expr $end - $start` seconds.
    exit 0
fi


##############################################
# GETIPNS
##############################################
if [[ $APPNAME == "getipns" ]]; then
    ( echo "$HTTPCORS
    url='"${ASTRONAUTENS}"'" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 && echo "SLURP getipns : ${ASTRONAUTENS}" ) &
    end=`date +%s`
    echo $APPNAME "(☉_☉ ) /ipns/${ASTRONAUTENS} Execution time was "`expr $end - $start` seconds.
    rm ~/.zen/tmp/${MOATS}/${MOATS}.*
    exit 0
fi

##############################################
# GETG1PUB
##############################################
if [[ $APPNAME == "getg1pub" ]]; then
    (
        echo "$HTTPCORS
        url='"${G1PUB}"'" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 && echo "SLURP getg1pub : ${G1PUB}"
        echo "BLURP ${PORT}"
    ) &
    end=`date +%s`
    echo $APPNAME "(☉_☉ ) /ipns/${ASTRONAUTENS} Execution time was "`expr $end - $start` seconds.
    rm ~/.zen/tmp/${MOATS}/${MOATS}*
    exit 0
fi

##############################################
# LOGIN
##############################################
if [[ $APPNAME == "login" ]]; then

    ## INSTALL PLAYER IPNS KEY ON STATION
    [[ "${SALT}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] \
    && PLAYER=${SALT} \
    || PLAYER=${WHAT}

    ipfs key import ${PLAYER} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${MOATS}.${G1PUB}.ipns.key
    ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)

    #~ WSTATION=$(cat ~/.zen/tmp/WSTATION 2>/dev/null)
    #~ [[ $WSTATION != "" ]] \
    #~ && REPLACE=${myIPFS}${WSTATION} \
    #~ || REPLACE=${myIPFS}/ipns/${ASTRONAUTENS}

    REPLACE=${myIPFS}/ipns/${ASTRONAUTENS}

    USALT=$(echo "$SALT" | jq -Rr @uri)
    UPEPPER=$(echo "$PEPPER" | jq -Rr @uri)
    echo "/?salt=${USALT}&pepper=${UPEPPER} IS LOGIN - OPEN TW -"
    sed "s~_TWLINK_~${REPLACE}~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
    ## SET COOKIE
    #~ sed -i "s~_USALT_~${USALT}~g" ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
    #~ sed -i "s~_UPEPPER_~${UPEPPER}~g" ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
    echo "url='"${REPLACE}"'" >> ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect
    (
        cat ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
        echo "BLURP ${PORT}"
    ) &
    rm ~/.zen/tmp/${MOATS}/${MOATS}*
    end=`date +%s`
    echo $APPNAME "(☉_☉ ) Execution time was "`expr $end - $start` seconds.
    exit 0

fi

##############################################
# LOGOUT
##############################################
if [[ $APPNAME == "logout" ]]; then

    ## REMOVE PLAYER IPNS KEY FROM STATION
    [[ "${SALT}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] \
    && PLAYER=${SALT} \
    || PLAYER=${WHAT}

    echo "<h1>$PLAYER LOGOUT OK</h1>" > ~/.zen/tmp/${MOATS}/${MOATS}.log

    ipfs key rm ${G1PUB} >> ~/.zen/tmp/${MOATS}/${MOATS}.log
    ipfs key rm ${PLAYER} >> ~/.zen/tmp/${MOATS}/${MOATS}.log

    echo "$HTTPCORS $(cat ~/.zen/tmp/${MOATS}/${MOATS}.log)"| nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
    end=`date +%s`
    echo $APPNAME "(☉_☉ ) Execution time was "`expr $end - $start` seconds.
    rm ~/.zen/tmp/${MOATS}/${MOATS}.*
    exit 0

fi


###################################################################################################
###################################################################################################



## END RESPONDING
[[ ! -s ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect ]] \
    && echo "$HTTPCORS  PORT=$1 THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9 url=/user/$G1PUB" \
    > ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect

cat ~/.zen/tmp/${MOATS}/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > ~/.zen/tmp/${MOATS}/${MOATS}.official.swallow &
echo "HTTP 1.1 PROTOCOL DOCUMENT READY"
echo "${MOATS} -----> PAGE AVAILABLE -----> http://${myHOST}:${PORT}"

end=`date +%s`
echo $type" (J‿‿J) Execution time was "`expr $end - $start` seconds.
rm ~/.zen/tmp/${MOATS}/${MOATS}.*

exit 0
