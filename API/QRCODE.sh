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

echo "PORT=$1
THAT=$2
AND=$3
THIS=$4
APPNAME=$5
WHAT=$6
OBJ=$7
VAL=$8
MOATS=$9
COOKIE=$10"
PORT="$1" THAT="$2" AND="$3" THIS="$4"  APPNAME="$5" WHAT="$6" OBJ="$7" VAL="$8" MOATS="$9" COOKIE="$10"
### transfer variables according to script
QRCODE=$(echo "$THAT" | cut -d ':' -f 1) # G1nkgo compatible

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"

# function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

function urldecode() {
    local string="${1//+/ }"
    printf '%b' "${string//%/\\x}"
}

urlencode() {
    local string="$1"
    local length="${#string}"
    local url_encoded=""

    for ((i = 0; i < length; i++)); do
        local c="${string:i:1}"
        case "$c" in
            [a-zA-Z0-9.~_-])
                url_encoded+="$c"
                ;;
            *)
                printf -v hex_val "%02X" "'$c"  # Uppercase hex values
                url_encoded+="%$hex_val"
                ;;
        esac
    done

    echo "$url_encoded"
}

## GET TW
mkdir -p ~/.zen/tmp/${MOATS}/

################################################################################
## QRCODE IS HTTP LINK REDIRECT TO
###############################################################################
if [[ ${QRCODE:0:4} == "http" ]]; then
    ## THIS IS A WEB LINK
    sed "s~_TWLINK_~${QRCODE}/~g" ${MY_PATH}/../templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    sed -i "s~Set-Cookie*~Set-Cookie: $COOKIE~" ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${QRCODE}"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0

fi

################################################################################
## QRCODE="station" : REFRESH STATION & OPEN G1PalPay INTERFACE
###############################################################################
if [[ ${QRCODE} == "station" ]]; then

    #~ # Keep 2nd try of the day
    #~ [[ ! -s ~/.zen/tmp/_ISTATION ]] \
        #~ && mv ~/.zen/tmp/ISTATION ~/.zen/tmp/_ISTATION \
        #~ || cp ~/.zen/tmp/_ISTATION ~/.zen/tmp/ISTATION

    if [[ ! -s ~/.zen/tmp/ISTATION ]]; then
        ## GENERATE PLAYER G1 TO ZEN ACCOUNTING
        ISTATION=$($MY_PATH/../tools/make_image_ipfs_index_carousel.sh | tail -n 1)
        echo $ISTATION > ~/.zen/tmp/ISTATION ## STATION G1WALLET CAROUSEL
    else
        ISTATION=$(cat ~/.zen/tmp/ISTATION)
    fi
        ## SHOW G1PALPAY FRONT (IFRAME)
        sed "s~_STATION_~${myIPFS}${ISTATION}/~g" $MY_PATH/../templates/ZenStation/index.html > ~/.zen/tmp/${MOATS}/index.htm
        [[ ! $isLAN ]] && sed -i "s~MENU~HOSTING~g" ~/.zen/tmp/${MOATS}/index.htm
        sed -i "s~http://127.0.0.1:8080~${myIPFS}~g" ~/.zen/tmp/${MOATS}/index.htm
        sed -i "s~http://127.0.0.1:33101~${myG1BILLET}~g" ~/.zen/tmp/${MOATS}/index.htm
        sed -i "s~http://astroport.localhost:1234~${myASTROPORT}~g" ~/.zen/tmp/${MOATS}/index.htm

        WSTATION="/ipfs/$(ipfs add -q ~/.zen/tmp/${MOATS}/index.htm)"
        echo $WSTATION > ~/.zen/tmp/WSTATION
        end=`date +%s`
        echo "NEW WSTATION ${myIPFS}${WSTATION} Execution time was "`expr $end - $start` seconds.
    ## SEND TO WSTATION PAGE
    sed "s~_TWLINK_~${myIPFS}${WSTATION}/~g" ${MY_PATH}/../templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    sed -i "s~Set-Cookie*~Set-Cookie: $COOKIE~" ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${myIPFS}${WSTATION}"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0
fi

################################################################################
## QRCODE = PGP ENCRYPTED STRING
# /?qrcode=-----BEGIN%20PGP%20MESSAGE-----~~jA0ECQMC5iq8 [ ......... ] _Q%3D%3D~%3D9UIj~-----END%20PGP%20MESSAGE-----~
# &pass=coucou&history/read/pay/login=(1|email)&g1pub=_DESTINATAIRE_
################################################################################
if [[ ${QRCODE:0:5} == "~~~~~" ]]; then
   PASS=$(urldecode ${THIS})
   echo "## THIS IS A PGP ENCRYPTED QRCODE ZENCARD - PASS ${PASS} - $APPNAME"

    if [[ ${PASS} != "" ]]; then
        echo "WHAT=${WHAT} VAL=${VAL}"

        ## Recreate GPG aes file
        urldecode "${QRCODE}" | tr '_' '+' | tr '-' '\n' | tr '~' '-'  > ~/.zen/tmp/${MOATS}/disco.aes
        sed -i '$ d' ~/.zen/tmp/${MOATS}/disco.aes
        # Decoding
        echo "cat ~/.zen/tmp/${MOATS}/disco.aes | gpg -d --passphrase "${PASS}" --batch"
        cat ~/.zen/tmp/${MOATS}/disco.aes | gpg -d --passphrase "${PASS}" --batch > ~/.zen/tmp/${MOATS}/decoded

        # cat ~/.zen/tmp/${MOATS}/disco
        ## FORMAT IS "/?salt=${USALT}&pepper=${UPEPPER}"
        DISCO=$(cat ~/.zen/tmp/${MOATS}/decoded  | cut -d '?' -f2)
        arr=(${DISCO//[=&]/ })
        s=$(urldecode ${arr[0]} | xargs)
        salt=$(urldecode ${arr[1]} | xargs)
        p=$(urldecode ${arr[2]} | xargs)
        pepper=$(urldecode ${arr[3]} | xargs)

       echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}/disco

        if [[ ${salt} != "" && ${pepper} != "" ]]; then
            ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/secret.key  "$salt" "$pepper"
            G1PUB=$(cat ~/.zen/tmp/${MOATS}/secret.key | grep 'pub:' | cut -d ' ' -f 2)

            echo "${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${G1PUB}"
            ${MY_PATH}/../tools/COINScheck.sh ${G1PUB} > ~/.zen/tmp/${G1PUB}.curcoin
            cat ~/.zen/tmp/${G1PUB}.curcoin
            CURCOINS=$(cat ~/.zen/tmp/${G1PUB}.curcoin | tail -n 1 | cut -d '.' -f 1) ## ROUNDED G1 COIN
            CURZEN=$(echo "($CURCOINS - 1) * 10" | bc | cut -d '.' -f 1)
            echo "SOURCE WALLET : $CURCOINS G1 / $CURZEN ZEN"

            [[ ${WHAT} == "" ]] &&  echo "<br> Missing amount <br>" >> ~/.zen/tmp/${MOATS}/disco
            [[ ${VAL} == "" || ${VAL} == "undefined" ]] &&  echo "<br> Missing Destination PublicKey <br>" >> ~/.zen/tmp/${MOATS}/disco

            G1DEST=$(echo "$VAL" | cut -d ':' -f 1) ## G1PUB:CHK format
            CHK=$(echo "$VAL" | cut -d ':' -f 2) ## G1 CHECKSUM or ZEN
            [[ ${CHK::3} == "ZEN" ]] && echo "ZENCARD $VAL"

            ## GET DESTINATION ACCOUNT AMOUNT
            DESTM=$(${MY_PATH}/../tools/COINScheck.sh ${G1DEST} | tail -n 1)
            DESTMZEN=$(echo "($DESTM - 1) * 10" | bc | cut -d '.' -f 1)
            echo "DEST WALLET : $DESTM G1 / $DESTMZEN ZEN"

            if [[ ${APPNAME} == "pay" ]]; then

                 if [[ ${WHAT} != "" && ${G1DEST} != "" && ${CURCOINS} != "null" && ${CURCOINS} != "" &&  ${CURCOINS} > ${WHAT} ]]; then
                    ## COMMAND PAYMENT MAX : 999.99
                        if [[ ${WHAT} =~ ^-?[0-9]{1,3}(\.[0-9]{1,2})?$ ]]; then

                            ${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/tmp/${MOATS}/secret.key "${WHAT}" "${G1DEST}" "ZEN:${MOATS}"
                            echo "<h1>OK</h1><h2>PAYMENT PROCESSING</h2>ZEN:${MOATS}" >> ~/.zen/tmp/${MOATS}/disco

                        else

                            echo "<h2>${WHAT} FORMAT ERROR</h2>" >> ~/.zen/tmp/${MOATS}/disco

                        fi

                else

                     echo "<h2> ERROR - ${G1DEST} ? ${CURCOINS} < ${WHAT} ? - ERROR </h2>" >> ~/.zen/tmp/${MOATS}/disco

                fi

            else

                echo "<h2>ERROR - INVALID PIN - ERROR</h2>" >> ~/.zen/tmp/${MOATS}/disco
                cat ~/.zen/tmp/${MOATS}/disco.aes >> ~/.zen/tmp/${MOATS}/disco

            fi

            if [[ ${APPNAME} == "flipper" ]]; then
                ## Open OSM2IPF "getreceiver" App

                BASE="qrcode=${QRCODE}&pass=${PASS}"
                LINK="${myIPFS}${FLIPPERCID}/?${BASE}&coins=${CURCOINS}"
                echo "LINK:$LINK"
                echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}/disco
                echo "<script>window.location.href = '${LINK}';</script>" >> ~/.zen/tmp/${MOATS}/disco

            fi

            if [[ ${APPNAME} == "history" || ${APPNAME} == "read" ]]; then

                ## history & read ## CANNOT USE jaklis CLI formated output (JSON output)
                echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}/disco
                sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}/disco
                # cp ~/.zen/tmp/${MOATS}/secret.key ~/.zen/tmp/
                echo "${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/secret.key $APPNAME -j"
                ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/secret.key $APPNAME -j >> ~/.zen/tmp/${MOATS}/disco

            fi

            if [[ ${APPNAME} == "balance" ]]; then

                ## history & read
                # cp ~/.zen/tmp/${MOATS}/secret.key ~/.zen/tmp/
                qrencode -s 6 -o "${HOME}/.zen/tmp/${MOATS}/disco.qr.png" "${G1PUB}:ZEN"
                QRURL=${myIPFS}/ipfs/$(ipfs add -q ~/.zen/tmp/${MOATS}/disco.qr.png)
                ONVADIRE="<h1> ${CURZEN} ẐEN </h1>${G1PUB}<br><br><img src=${QRURL} />"
                echo "${ONVADIRE}" >> ~/.zen/tmp/${MOATS}/disco

            fi

            if [[ ${APPNAME} == "friend" ]]; then

                # CHECK IF ${G1DEST} HAS A PROFILE
                ${MY_PATH}/../tools/timeout.sh -t 5 \
                    curl -s ${myDATA}/user/profile/${G1DEST} > ~/.zen/tmp/${MOATS}/gchange.json

                ## Send ॐ★ॐ
                [[ -s ~/.zen/tmp/${MOATS}/gchange.json ]] \
                    && ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/secret.key stars -p ${G1DEST} -n ${WHAT} >> ~/.zen/tmp/${MOATS}/disco \
                    && rm ~/.zen/tmp/${MOATS}/gchange.json \
                    || echo "/${G1DEST} profile is not existing yet..." >> ~/.zen/tmp/${MOATS}/disco

            fi

##############################################
# LOGIN / LOGOUT
##############################################
            if [[ ${APPNAME} == "logout" ]]; then

                ## REMOVE PLAYER IPNS KEY FROM STATION
                [[ "${salt}" =~ ^[a-zA-Z0-9.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]] \
                && PLAYER=${salt} \
                || PLAYER=${WHAT}

                echo "TW : $myIPFS/ipns/$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)" > ~/.zen/tmp/${MOATS}/${MOATS}.log
                echo "<h1>$PLAYER LOGOUT ...</h1>" >> ~/.zen/tmp/${MOATS}/${MOATS}.log
                ipfs key rm ${G1PUB} >> ~/.zen/tmp/${MOATS}/${MOATS}.log
                ipfs key rm ${PLAYER} >> ~/.zen/tmp/${MOATS}/${MOATS}.log
                ipfs key rm "${PLAYER}_feed" >> ~/.zen/tmp/${MOATS}/${MOATS}.log

                echo "$HTTPCORS $(cat ~/.zen/tmp/${MOATS}/${MOATS}.log)"| nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
                end=`date +%s`
                echo $APPNAME "(☉_☉ ) Execution time was "`expr $end - $start` seconds.
                rm ~/.zen/tmp/${MOATS}/${MOATS}.*
                exit 0

            fi

            if [[ ${APPNAME} == "login" ]]; then

                [[ "${salt}" =~ ^[a-zA-Z0-9.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]] \
                && PLAYER=${salt} \
                || PLAYER=${WHAT}

                ISTHERE=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
                echo "IS THERE ? $ISTHERE"

                [[ ${ISTHERE} == "" ]] \
                && ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/secret.ipns  "$salt" "$pepper" \
                && ipfs key import ${PLAYER} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/secret.ipns \
                && ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/secret.ipns \
                && ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1) \
                || ASTRONAUTENS=${ISTHERE}

                ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/feed.ipfskey "$salt" "$G1PUB"
                FEEDNS=$(ipfs key import "${PLAYER}_feed" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/feed.ipfskey)

                ( ## 1 HOUR SESSION
                    [[ ${ISTHERE} == "" ]] \
                        && echo "${PLAYER} SESSION STARTED" \
                        && sleep 3600 \
                        && echo "${PLAYER} SESSION ENDED" \
                        && ipfs key rm ${PLAYER} \
                        && ipfs key rm ${PLAYER}_feed \
                        && ipfs key rm ${G1PUB}
                ) &

                REPLACE=${myIPFS}/ipns/${ASTRONAUTENS}
                echo "${PLAYER} LOGIN - TW : ${REPLACE}"

                sed "s~_TWLINK_~${REPLACE}~g" ~/.zen/Astroport.ONE/templates/index.302  > ~/.zen/tmp/${MOATS}.index.redirect
                echo "url='"${REPLACE}"'" >> ~/.zen/tmp/${MOATS}.index.redirect
                (
                    cat ~/.zen/tmp/${MOATS}.index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
                    echo "BLURP " && rm -Rf ~/.zen/tmp/${MOATS} && rm ~/.zen/tmp/${MOATS}/${MOATS}*
                ) &
                exit 0

            fi

        else

            echo "<br><h1>${PASS} : MAUVAIS PASS</h1>" >> ~/.zen/tmp/${MOATS}/disco
            echo "<br><img src='http://127.0.0.1:8080/ipfs/QmVnQ3GkQjNeXw9qM7Fb1TFzwwxqRMqD9AQyHfgx47rNdQ/your-own-data-cloud.svg' />" >> ~/.zen/tmp/${MOATS}/disco
        fi

    else

        echo "<br>DATA MISSING" >> ~/.zen/tmp/${MOATS}/disco
    fi

    (
    cat ~/.zen/tmp/${MOATS}/disco | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0

fi

### THIS QRCODE IS EMAIL/PASS/PIN STYLE
#~ if [[ ${QRCODE:0:5} == "&&&&&" ]]; then
    #~ PASS=$(urldecode ${THIS})
    #~ echo "ZENCARD UPlanet QRCODE : PIN=${PASS}"

#~ fi

################################################################################
## QRCODE = G1Milgram G1Missive PGP ENCRYPTED STRING
# /?qrcode=@@@@@BEGIN%20PGP%20MESSAGE@@@@@~~jA0ECQM...............
# &pass=YYYYMM&milgram=NEWLINE&email=DESTMAIL
################################################################################
if [[ ${QRCODE:0:5} == "@@@@@" ]]; then
   PASS=$(urldecode ${THIS})
   NEWLINE=$(urldecode ${WHAT})
   DESTMAIL=$(urldecode ${VAL,,}) # lowercase

   echo "## G1BILLET+ - @PASS ${PASS} - $APPNAME"

    if [[ ${PASS} != "" ]]; then

        ## Recreate GPG aes file
        urldecode ${QRCODE} | tr '_' '+' | tr '-' '\n' | tr '@' '-'  > ~/.zen/tmp/${MOATS}/disco.aes
        sed -i '$ d' ~/.zen/tmp/${MOATS}/disco.aes
        # Decoding
        echo "cat ~/.zen/tmp/${MOATS}/disco.aes | gpg -d --passphrase "${PASS}" --batch"
        cat ~/.zen/tmp/${MOATS}/disco.aes | gpg -d --passphrase "${PASS}" --batch > ~/.zen/tmp/${MOATS}/decoded

        ## ASTROID COULD BE UP TO 12 MONTH OLD
        if [[ ! -s ~/.zen/tmp/${MOATS}/decoded ]]; then
            for ((i = 1; i < 13; i++)); do
                UPASS=$(date -d "$i months ago" +"%Y%m")
                cat ~/.zen/tmp/${MOATS}/disco.aes | gpg -d --passphrase "${UPASS}" --batch > ~/.zen/tmp/${MOATS}/decoded
                [[ -s ~/.zen/tmp/${MOATS}/decoded ]] && WARNING="=== CARD IS ${i} MONTH OLD ===" && CAGE=${i} && break
            done
        fi

        # cat ~/.zen/tmp/${MOATS}/disco
        ## FORMAT IS "/?salt=${USALT}&pepper=${UPEPPER}"
        ## MADE by tools/VOEUX.print.sh WITH USALT="EMAIL(_SEC1_SEC2)" UPEPPER="G1VoeuName OriG1PUB"
        DISCO=$(cat ~/.zen/tmp/${MOATS}/decoded  | cut -d '?' -f2)
        arr=(${DISCO//[=&]/ })
        s=$(urldecode ${arr[0]} | xargs)
        salt=$(urldecode ${arr[1]} | xargs)
        p=$(urldecode ${arr[2]} | xargs)
        pepper=$(urldecode ${arr[3]} | xargs)

       echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}/disco

        if [[ ${salt} != "" && ${pepper} != "" ]]; then

            echo "secret1=$salt" ## CONTAINS "EMAIL(_SEC1_SEC2)"
            player=$(echo $salt | cut -d '_' -f 1 | cut -d ' ' -f 1 | grep '@')
            echo "player=$player"

            # # G1BILLET+ interlinked ? ## POSSIBLE BUG WITH EMAIL CONTAINING "_" # TODO
            [[ $(echo "$salt" | grep '_') ]] \
                && echo "G1BILLET+ interlinked : salt pepper refining" \
                && murge=($(echo $salt | cut -d '_' -f 2- | sed 's/_/ /g' | xargs)) \
                && echo "${#murge[@]} dice words" && i=$(( ${#murge[@]} / 2 )) && i=$(( i + 1 )) \
                && extra1=$(echo "${murge[@]}" | rev | cut -d ' ' -f $i- | rev) \
                && extra2=$(echo "${murge[@]}" | cut -d ' ' -f $i-) \
                && VoeuName="G1BILLET+" \
                && billkeyname=$(echo "${extra1} ${extra2}" | sha512sum  | awk '{print $1}')

            echo "salt=$salt" ## CONTAINS "EMAIL"
            echo "pepper=$pepper" ## CONTAINS "G1VoeuName ORIGING1PUB" or G1BILLET+ secret2

            [[ ${pepper:0:2} == "G1" ]] \
                && VoeuName=$(echo $pepper | cut -d ' ' -f 1 | cut -c 3-) \
                && PLAYERORIG1=$(echo $pepper | rev | cut -d ' ' -f 1 | rev) \
                && echo "$VoeuName $PLAYERORIG1 @PASS"

            ## CHECK PLAYERORIG1 WALLETS
            echo "${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${PLAYERORIG1}"
            PLAYERCOINS=$(${MY_PATH}/../tools/COINScheck.sh ${PLAYERORIG1} | tail -n 1)
            echo "<br><b>${player} $PLAYERCOINS G1</b>" >> ~/.zen/tmp/${MOATS}/disco
            ###  IF EMPTY ??? WHAT  TODO

            orikeyname="${player}_${VoeuName}"
            destkeyname="${DESTMAIL}_${VoeuName}"
            echo "@PASS KEYS :
            ORIGIN=$orikeyname
            DEST=$destkeyname
            BILL=$billkeyname"
            ## REVEAL THE KEYS
                # G1VOEU & IPNS KEY
                [[ ${player} != "" ]] \
                && ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/playersecret.ipfs  "${player}" "G1${VoeuName} ${PLAYERORIG1}" \
                && ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/player.secret.key  "${player}" "G1${VoeuName} ${PLAYERORIG1}" \
                && G1VOEUPUB=$(cat ~/.zen/tmp/${MOATS}/player.secret.key | grep 'pub:' | cut -d ' ' -f 2)
               # INSTALL orikeyname IPNS KEY ON NODE
                IK=$(ipfs key list -l | grep -w "${orikeyname}" | cut -d ' ' -f 1 )
                [[ ! $IK ]] && ipfs key import ${orikeyname} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/playersecret.ipfs

                ## IS IT A TRANSFER ? MILGRAM G1MISSIVE
                [[ ${DESTMAIL} != "" ]] \
                    && echo "MILGRAM :: ${player} :: ${DESTMAIL}" \
                    #~ && DESTG1=$(${MY_PATH}/../tools/keygen "${DESTMAIL}" "G1${VoeuName} ${PLAYERORIG1}") \
                    #~ && ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/destsecret.ipfs  "${DESTMAIL}" "G1${VoeuName} ${PLAYERORIG1}"

               # INSTALL orikeyname IPNS KEY ON NODE
                IK=$(ipfs key list -l | grep -w "${orikeyname}" | cut -d ' ' -f 1 )
                [[ ! $IK ]] && ipfs key import ${orikeyname} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/playersecret.ipfs

                ## IS IT LINKED WITH extra G1BILLET+
                [[ ${extra1} != "" && ${extra2} != "" ]] \
                && echo "@PASS LINK TO G1BILLET+ :: ${extra1} :: ${extra2}" \
                && EXTRAG1=$(${MY_PATH}/../tools/keygen "${extra1}" "${extra2}") \
                && ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/extrasecret.ipfs  "${extra1}" "${extra2}" \
                && EXTRAG1COINS=$(${MY_PATH}/../tools/COINScheck.sh ${EXTRAG1} | tail -n 1) \
                && echo "<br><b>EXTRA ${VoeuName} $EXTRAG1COINS G1</b>" >> ~/.zen/tmp/${MOATS}/disco

            # Don't care if ORIGIN PLAYER is THERE
            #~ ISTHERE=$(ipfs key list -l | grep -w ${player} | cut -d ' ' -f1)
            #~ echo "<h1>$player G1MISSIVE<h1> $ISTHERE" >> ~/.zen/tmp/${MOATS}/disco

            echo "${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${G1VOEUPUB}"
            G1VOEUCOINS=$(${MY_PATH}/../tools/COINScheck.sh ${G1VOEUPUB} | tail -n 1)
            echo "<br><b>${VoeuName} $G1VOEUCOINS G1</b>" >> ~/.zen/tmp/${MOATS}/disco

            echo ${WARNING} >> ~/.zen/tmp/${MOATS}/disco

            #CONVERT TO IPNS KEY
            G1VOEUNS=$(${MY_PATH}/../tools/g1_to_ipfs.py ${G1VOEUPUB})
            ## RETRIEVE IPNS CONTENT
            echo "${myIPFS}/ipns/$G1VOEUNS"
            if [[ ! -s ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt ]]; then
                HELLO="@PASS :: G1BILLET+ :: ${G1VOEUPUB} :: $(date) :: ${player} :: ${PLAYERORIG1}"
                echo "${HELLO}"
                avanla=$(ps axf --sort=+utime | grep -w 'ipfs cat /ipns/$G1VOEUNS' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
                [[ ! $avanla ]] \
                    && ( ipfs cat /ipns/$G1VOEUNS > ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt \
                                && [[ ! -s ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt ]] \
                                && echo "@PASS G1BILLET+ INIT" \
                                && echo "${HELLO}" > ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt \
                                && MILGRAM=$(ipfs add -q ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt) \
                                && ipfs name publish -k ${player}_${VoeuName} /ipfs/${MILGRAM} &
                            ) &

                echo "<br>PLEASE RETRY IN 30 SECONDS GETTING MESSAGE FROM IPFS<br>" >> ~/.zen/tmp/${MOATS}/disco
                (
                    cat ~/.zen/tmp/${MOATS}/disco | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
                    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
                ) &
               exit 0

            fi
            echo "<br><br>" >> ~/.zen/tmp/${MOATS}/disco
            cat ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt >> ~/.zen/tmp/${MOATS}/disco

            [[ ${NEWLINE} == "" || ${NEWLINE} == "undefined"  ]] && echo "<br> NO NEW LINE <br>" >> ~/.zen/tmp/${MOATS}/disco
            [[ ${DESTMAIL} == "" || ${DESTMAIL} == "undefined" ]] && echo "<br> Missing Destination EMAIL <br>" >> ~/.zen/tmp/${MOATS}/disco

            ## CHECK VALID EMAIL FORMAT
            [[ "${DESTMAIL}" =~ ^[a-zA-Z0-9.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]] \
                &&  echo "<br> GOOD $DESTMAIL <br>" >> ~/.zen/tmp/${MOATS}/disco \
                && GOMAIL=1

            if [[ $APPNAME == "milgram"  && ${GOMAIL} == 1 ]]; then

                # SEARCH FOR DESTMAIL IN SWARM
                $($MY_PATH/../tools/search_for_this_email_in_players.sh ${DESTMAIL}) ## export ASTROTW and more
                echo "export ASTROTW=${ASTROTW} ASTROG1=${ASTROG1} ASTROMAIL=${DESTMAIL} ASTROFEED=${FEEDNS}"

                 # Create Next G1 & IPNS KEY
                DESTG1PUB=$(${MY_PATH}/../tools/keygen"${DESTMAIL}" "G1${VoeuName} ${PLAYERORIG1}")
                ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/newsecret.ipfs  "${DESTMAIL}" "G1${VoeuName} ${PLAYERORIG1}"

                orikeyname="${DESTMAIL}_${VoeuName}"
                # INSTALL NEXT IPNS KEY ON NODE
                IK=$(ipfs key list -l | grep -w "${orikeyname}" | cut -d ' ' -f 1 )
                [[ ! $IK ]] && ipfs key import ${orikeyname} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/newsecret.ipfs

                ## CREATE NEXT G1Missive !
                NEWIMAGIC=$(${MY_PATH}/../tools/VOEUX.print.sh "${DESTMAIL}" "${VoeuName}" "${MOATS}" "${PLAYERORIG1}" | tail -n 1)

                ## ADD NEWLINE TO MESSAGE
                if [[ ${NEWLINE} != "" ]]; then
                    CLINE=$(echo "${NEWLINE}" | detox --inline)
                    echo "$CLINE" >> ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt ## NB: File could still being into "ipfs cat" process... TODO MAKE BETTER
                fi

                echo "UPDATED" >> ~/.zen/tmp/${MOATS}/disco
                cat ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt >> ~/.zen/tmp/${MOATS}/disco
                echo "<br><img src=/ipfs/$NEWIMAGIC />" >> ~/.zen/tmp/${MOATS}/disco

                MILGRAM=$(ipfs add -q ~/.zen/tmp/${MOATS}/${PLAYERORIG1}.${VoeuName}.missive.txt)

                (
                    ipfs name publish -k ${DESTMAIL}_${VoeuName} /ipfs/${MILGRAM}
                    echo "${VoeuName} ${PASS} G1Milgram emitted ${DESTMAIL}"
                ) &

            fi

        else
            ## TODO : EMPTY WALLET BACK TO ORIGIN
            echo "<br><h1>${PASS} ${UPASS} ARE BAD</h1>" >> ~/.zen/tmp/${MOATS}/disco
            echo "<br><img src='/ipfs/QmVnQ3GkQjNeXw9qM7Fb1TFzwwxqRMqD9AQyHfgx47rNdQ/your-own-data-cloud.svg' />" >> ~/.zen/tmp/${MOATS}/disco

        fi

    else

        echo "<br>DATA MISSING" >> ~/.zen/tmp/${MOATS}/disco

    fi

    (
    cat ~/.zen/tmp/${MOATS}/disco | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &

    exit 0

fi



################################################################################
## QRCODE = G1* : MODE G1VOEU : RETURN WISHNS - IPNS App link - or direct tw tag selected json
# ~/?qrcode=G1Tag&tw=_IPNS_PLAYER_(&json)
################################################################################
if [[ ${QRCODE:0:2} == "G1" && ${AND} == "tw" ]]; then

    VOEU=${QRCODE:2} ## "G1G1Voeu" => "G1Voeu"
    # THIS is TW IPNS
    ASTROPATH=$(grep -r ${THIS} ~/.zen/game/players/*/ipfs/moa | tail -n 1 | cut -d ':' -f 1 | rev | cut -d '/' -f 2- | rev  2>/dev/null)
    echo "ASTROPATH=${ASTROPATH}"

    INDEX=${ASTROPATH}/index.html
    echo $INDEX

    if [[ -s  ${INDEX} ]]; then

        echo "OK FOUND TW: ${INDEX}"

        if [[ ${APPNAME} == "json" ]]; then
        ##############################################
            echo "DIRECT Tag = ${VOEU} OUTPUT"
            ## DIRECT JSON OUTPUT
            tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} \
            --render '.' "g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag['${VOEU}']]'

            echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}/index.redirect
            sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}/index.redirect
            cat ~/.zen/tmp/${MOATS}/g1voeu.json >> ~/.zen/tmp/${MOATS}/index.redirect
            (
            cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
            echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
            ) &
            exit 0

        fi
        ##############################################
        echo "## IPNS G1Voeu APP REDIRECT"
        tiddlywiki --load ${INDEX} --output ~/.zen/tmp --render '.' "${MOATS}.g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'
        cat ~/.zen/tmp/${MOATS}.g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/${MOATS}.g1wishes.txt
        cat ~/.zen/tmp/${MOATS}.g1wishes.txt
        while read WISH
        do
            [[ ${WISH} == "" || ${WISH} == "null" ]] && echo "BLURP. EMPTY WISH" && continue
            WISHNAME=$(cat ~/.zen/tmp/${MOATS}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .title')
            WISHNS=$(cat ~/.zen/tmp/${MOATS}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .wishns')

            [[ ${WISHNS} == null ]] && WISHNS="/ipns/"$(cat ~/.zen/tmp/${MOATS}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .ipns') ## KEEP OLD PROTOCOL COMPATIBLE

            echo "${WISHNAME} : ${WISHNS} "
            [[ "G1${WISHNAME}" == "$VOEU" ]] \
            && echo "FOUND" \
            && LINK=${myIPFS}${WISHNS} \
            && break

        done < ~/.zen/tmp/${MOATS}.g1wishes.txt

    fi

    [[ $LINK == "" ]] && LINK="$myIPFS/ipfs/QmWUZr62SpriLPuqauMbMxvw971qnu741hV8EhrHmKF2Y4" ## 404 LOST IN CYBERSPACE

    ## REDIRECT TO G1VOEU IPNS ADDRESS
    echo "#>>> DISPLAY WISHNS >>>> # $VOEU : $LINK"
    sed "s~_TWLINK_~${LINK}~g" ${MY_PATH}/../templates/index.302  > ~/.zen/tmp/${MOATS}/index.redirect
    sed -i "s~Set-Cookie*~Set-Cookie: $COOKIE~" ~/.zen/tmp/${MOATS}/index.redirect
    echo "url='"${LINK}"'" >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0
fi

################################################################################
## QRCODE = IPNS or G1PUB ? Can be ASTRONAUTENS or G1PUB format
ZCHK="${QRCODE#*:}" # ChK or ZEN
QRCODE="${QRCODE%%:*}" ## TRIM :ZEN :ChK
################################################################################
################################################################################
## QRCODE IS IPNS FORMAT "12D3Koo"  ( try ipfs_to_g1 )
IPNS2G1=$(${MY_PATH}/../tools/ipfs_to_g1.py ${QRCODE} 2>/dev/null)
[[ ${IPNS2G1} != "" ]] \
        && echo "${PORT} QRCODE IS IPNS ADDRESS : ${myIPFS}/ipns/${QRCODE}" \
        && (echo "$HTTPCORS <meta http-equiv=\"refresh\" content=\"0; url='${myIPFS}/ipns/${QRCODE}'\" />Loading from IPFS"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
        && exit 0

## TEST G1 TYPE  ( try g1_to_ipfs )
ASTROTOIPNS=$(${MY_PATH}/../tools/g1_to_ipfs.py ${QRCODE} 2>/dev/null)
        [[ ! ${ASTROTOIPNS} ]] \
        && echo "${PORT} INVALID QRCODE : ${QRCODE}" \
        && (echo "$HTTPCORS ERROR - INVALID QRCODE : ${QRCODE}"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
        && exit 1
################################################################################
echo "############################################################################"
echo ">>> ${QRCODE} g1_to_ipfs $ASTROTOIPNS"

    ## GET VISITOR G1 WALLET AMOUNT : VISITORCOINS
    echo "COINScheck : ${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${QRCODE}"
    VISITORCOINS=$(${MY_PATH}/../tools/COINScheck.sh ${QRCODE} | tail -n 1)
    COINSFILE=$HOME/.zen/tmp/${MOATS}/${QRCODE}.COINS

    ZEN=$(echo "($VISITORCOINS - 1) * 10" | bc | cut -d '.' -f 1)

    DISPLAY="$VISITORCOINS G1"
    [[ $ZCHK == "ZEN" ]] && DISPLAY="$ZEN ẐEN"

## WALLET VIERGE
###########################################
if [[ $VISITORCOINS == "null" ]]; then

    echo ""

    echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}/index.redirect
    echo "<h1>EMPTY. PLEASE CHARGE. </h1>
    ... Send dotation to made-in-zen ? Contact <a href='mailto:support@qo-op.com'>support</a>
    ($myHOST)"  >> ~/.zen/tmp/${MOATS}/index.redirect
    (
    cat ~/.zen/tmp/${MOATS}/index.redirect | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &
    exit 0

fi

    (
    echo "$HTTPCORS  <h2>${ZCHK} : ${QRCODE}</h2><h1>${DISPLAY}</h1>"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    echo "BLURP $PORT" && rm -Rf ~/.zen/tmp/${MOATS}
    ) &

exit 0
