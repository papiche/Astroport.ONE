################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: UPLANET
## Dedicated to OSM2IPFS & UPlanet Client App
# ?uplanet=EMAIL&salt=LAT&pepper=LON
## https://git.p2p.legal/qo-op/OSM2IPFS
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
function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

## CHECK FOR NOT PUBLISHING ALREADY (AVOID IPNS CRUSH)
alreadypublishing=$(ps axf --sort=+utime | grep -w 'ipfs name publish --key=' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
if [[ ${alreadypublishing} ]]; then
     echo "$HTTPCORS ERROR - (╥☁╥ ) - IPFS ALREADY PUBLISHING RETRY LATER"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
     exit 1
fi

## START MANAGING UPLANET LAT/LON & PLAYER
mkdir -p ~/.zen/tmp/${MOATS}/

## GET PARAM, with case uplanet="" decalage !
PLAYER=${THAT}
[[ ${PLAYER} == "salt"  ]] && PLAYER="@"

[[ ${AND} != "salt" ]] \
    &&  (echo "$HTTPCORS ERROR - BAD PARAMS" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0

SALT=${THIS}

[[ ${SALT} == "0" ]] && SALT="0.00"
input_number=${SALT}
if [[ ! $input_number =~ ^-?[0-9]{1,3}(\.[0-9]{1,2})?$ ]]; then
    (echo "$HTTPCORS ERROR - BAD LAT $LAT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0
else
    # If input_number has one decimal digit, add a trailing zero
    if [[ ${input_number} =~ ^-?[0-9]+\.[0-9]$ ]]; then
        input_number="${input_number}0"
    elif [[ ${input_number} =~ ^-?[0-9]+$ ]]; then
        # If input_number is an integer, add ".00"
        input_number="${input_number}.00"
    fi

    # Convert input_number to LAT with two decimal digits
    LAT="${input_number}"
fi

PEPPER=${WHAT}

[[ ${APPNAME} != "pepper" ]] \
    &&  (echo "$HTTPCORS ERROR - BAD PARAMS" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0

[[ ${PEPPER} == "0" ]] && PEPPER="0.00"
input_number=${PEPPER}
if [[ ! $input_number =~ ^-?[0-9]{1,3}(\.[0-9]{1,2})?$ ]]; then
    (echo "$HTTPCORS ERROR - BAD LON $LON" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0
else
    # If input_number has one decimal digit, add a trailing zero
    if [[ ${input_number} =~ ^-?[0-9]+\.[0-9]$ ]]; then
        input_number="${input_number}0"
    elif [[ ${input_number} =~ ^-?[0-9]+$ ]]; then
        # If input_number is an integer, add ".00"
        input_number="${input_number}.00"
    fi

    # Convert input_number to LAT with two decimal digits
    LON="${input_number}"
fi

PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)
## RECEIVED PASS
VAL="$(echo ${VAL} | detox --inline)" ## DETOX VAL
[[ ${OBJ} == "g1pub" && ${VAL} != "" ]] && PASS=${VAL}
echo "PASS for Umap $LAT $LON is $PASS"
### CHECK PLAYER EMAIL
EMAIL="${PLAYER,,}" # lowercase

[[ ! ${EMAIL} ]] && (echo "$HTTPCORS ERROR - MISSING ${EMAIL} FOR UPLANET LANDING" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) &&  echo "(☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. &&  exit 0

### SESSION "$LAT" "$LON" KEY
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/_ipns.priv "$LAT" "$LON"
    UMAPNS=$(ipfs key import ${MOATS} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/_ipns.priv)
    ipfs key rm ${MOATS}
###

    REDIR="${myIPFS}/ipns/${UMAPNS}"

## CHECK WHAT IS EMAIL
if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then

    echo "VALID ${EMAIL} EMAIL OK"
    ###################################################
    ## GET NETWORK CACHE - 42s - UNLEASHED COMON BLOCKCHAIN
    echo "ipfs --timeout 42s get -o ~/.zen/tmp/${MOATS}/ /ipns/${UMAPNS}/"
    ipfs --timeout 42s get -o ~/.zen/tmp/${MOATS}/ /ipns/${UMAPNS}/

    ## CHECK if TW is HERE
    [[ -s ~/.zen/tmp/${MOATS}/TW/${EMAIL}/index.html ]] \
        && (echo  "$HTTPCORS <meta http-equiv=\"refresh\" content=\"0; url='${REDIR}/TW/${EMAIL}/index.html'\" /> '"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) \
        && echo "TW is HERE : $EMAIL" && exit 0

else

    echo "BAD EMAIL _$LAT_$LON : ${REDIR}"
    (echo "$HTTPCORS <meta http-equiv=\"refresh\" content=\"0; url='${REDIR}'\" /> '"   | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 0

fi

###########################################
### CREATE Umap G1VISA & G1Card
echo "${MY_PATH}/../tools/VISA.print.sh" "${EMAIL}"  "'"$LAT"'" "'"$LON"'" "'"$PASS"'" "'"$PASS"'"
${MY_PATH}/../tools/VISA.print.sh "${EMAIL}"  "$LAT" "$LON" "$PASS" "${PASS}"##
[[ ${EMAIL} != "" && ${EMAIL} != $(cat ~/.zen/game/players/.current/.player 2>/dev/null) ]] && rm -Rf ~/.zen/game/players/${EMAIL}/

# UPLANET #############################################
## OCCUPY COMMON CRYPTO KEY CYBERSPACE
## SALT="$LAT" PEPPER="$LON"
######################################################
echo "UMAP = $LAT:$LON"
echo "# CALCULATING MAP G1PUB WALLET"
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/_cesium.key  "$LAT" "$LON"
G1PUB=$(cat ~/.zen/tmp/${MOATS}/_cesium.key | grep 'pub:' | cut -d ' ' -f 2)
[[ ! ${G1PUB} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - KEYGEN  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
echo "MAPG1PUB : ${G1PUB}"

echo "# CALCULATING UMAP IPNS ADDRESS"
mkdir -p ~/.zen/tmp/${MOATS}/${G1PUB}
mkdir -p ~/.zen/tmp/${MOATS}/${LAT}_${LON}

ipfs key rm ${G1PUB} > /dev/null 2>&1
rm ~/.zen/tmp/${MOATS}/_ipns.priv 2>/dev/null
${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/_ipns.priv "$LAT" "$LON"
UMAPNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/_ipns.priv )
[[ ! ${UMAPNS} ]] && (echo "$HTTPCORS ERROR - (╥☁╥ ) - UMAPNS  COMPUTATION DISFUNCTON"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
echo "UMAPNS : ${myIPFS}/ipns/${UMAPNS}"

####################################### Umap.png
## CREATING Umap_${LAT}_${LON}.png
echo "# OSM2IPFS ~/.zen/tmp/${MOATS}/Umap_${LAT}_${LON}.png"
UMAPGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Umap.html?southWestLat=$LAT&southWestLon=$LON&deg=0.01"
USATGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Usat.html?southWestLat=$LAT&southWestLon=$LON&deg=0.01"

echo ${UMAPGEN}
echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/Umap.html
echo "<meta http-equiv=\"refresh\" content=\"0; url='${USATGEN}'\" />" > ~/.zen/tmp/${MOATS}/Usat.html

## GET MAP ## TODO find a better crawling method (pb tiles are not fully loaded before screenshot)
chromium --headless --disable-gpu --screenshot=/tmp/Umap.jpg --window-size=1200x1200 "${myIPFS}${UMAPGEN}"
chromium --headless --disable-gpu --screenshot=/tmp/Umap.png --window-size=1200x1200 "${myIPFS}${UMAPGEN}"
## GET SAT
chromium --headless --disable-gpu --screenshot=/tmp/Usat.jpg --window-size=1200x1200 "${myIPFS}${USATGEN}"
chromium --headless --disable-gpu --screenshot=/tmp/Usat.png --window-size=1200x1200 "${myIPFS}${USATGEN}"

## CREATE HTML for LAST of U Keys
echo "<img src=G1Card.${EMAIL}.jpg \>" > ~/.zen/tmp/${MOATS}/UCard.html
echo "<img src=G1Visa.${EMAIL}.jpg \>" > ~/.zen/tmp/${MOATS}/UVisa.html

## ADD TO VISITOR LIST : UFriends
echo "${EMAIL}" >> ~/.zen/tmp/${MOATS}/UFriends.txt

## COPYING FILES  to PUBLISH from ABROAD
cp /tmp/Umap.jpg ~/.zen/tmp/${MOATS}/
cp /tmp/Umap.png ~/.zen/tmp/${MOATS}/
cp /tmp/Usat.jpg ~/.zen/tmp/${MOATS}/
cp /tmp/Usat.png ~/.zen/tmp/${MOATS}/
rm -f ~/.zen/tmp/${MOATS}/G1*.jpg ## DELETE VISA FROM PREVIOUS VISITOR
cp ~/.zen/tmp/${PASS}##/G1Visa.${PASS}.jpg ~/.zen/tmp/${MOATS}/G1Visa.${EMAIL}.jpg
cp -f ~/.zen/tmp/${PASS}##/${PASS}.jpg ~/.zen/tmp/${MOATS}/G1Card.${EMAIL}.jpg
ls ~/.zen/tmp/${MOATS}/

    ### SECURE UMap private keys key with PGP
    cat ~/.zen/tmp/${MOATS}/_ipns.priv | gpg --symmetric --armor --batch --passphrase "$PASS" -o ~/.zen/tmp/${MOATS}/_ipns.priv.${EMAIL}.asc
    rm ~/.zen/tmp/${MOATS}/_ipns.priv

    cat ~/.zen/tmp/${MOATS}/_cesium.key | gpg --symmetric --armor --batch --passphrase "$PASS" -o ~/.zen/tmp/${MOATS}/_cesium.key.${EMAIL}.asc
    rm ~/.zen/tmp/${MOATS}/_cesium.key

### CREATE A G1VISA FOR PLAYER (NO TW EXISTS YET for EMAIL)
if [[ ! -f ~/.zen/tmp/${MOATS}/TW/${EMAIL}/index.html ]]; then

        ## CHECK IF TW EXISTS FOR THIS EMAIL ALREADY
        $($MY_PATH/../tools/search_for_this_email_in_players.sh ${EMAIL}) ## export ASTROTW and more
        echo "export ASTROTW=${ASTRONAUTENS} ASTROG1=${ASTROG1} ASTROMAIL=${EMAIL} ASTROFEED=${FEEDNS}"
        [[ ${ASTROTW} ]] && (echo "$HTTPCORS <meta http-equiv=\"refresh\" content=\"0; url='/ipns/${ASTROTW}'\" />"  | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

        ## Create a redirection to PLAYER (EMAIL/PASS) TW
        mkdir -p ~/.zen/tmp/${MOATS}/TW/${EMAIL}
        ## CREATE TW LINK /ipns/TWADD
        NPASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-9) ## NOUVEAU PASS 8 CHIFFRES
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}.priv "$EMAIL" "$NPASS"
        TWADD=$(ipfs key import ${MOATS} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}.priv)
        ipfs key rm ${MOATS} && rm ~/.zen/tmp/${MOATS}.priv
        echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${TWADD}'\" />" > ~/.zen/tmp/${MOATS}/TW/${EMAIL}/index.html
        ## CREATE OR TRANSFER TW ON CURRENT ASTROPORT
        (
        ${MY_PATH}/../tools/VISA.new.sh "${EMAIL}" "${NPASS}" "${EMAIL}" "UPlanet" "/ipns/${UMAPNS}" "${LAT}" "${LON}" >> ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt
        ${MY_PATH}/../tools/mailjet.sh "${EMAIL}" ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt ## Send VISA.new log to EMAIL
        ) &
fi

## MAKE A MESSAGE
echo "<html>
    <head>
    <title>[Astroport] $LAT $LON WELCOME ${EMAIL} </title>
        <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            background-color: #f0f0f0;
            padding: 20px;
        }
        h1 {
            color: #0077cc;
        }
        h2 {
            color: #333;
        }
        img {
            cursor: pointer;
        }
    </style>
    </head><body>        <button id='printButton'>Print</button>
    <h1>U U Planet ID registration : $LAT/$LON </h1>
    <h2>${EMAIL}</h2>
    <br>    <img width='300' height='300' src='Umap.jpg'  alt='UPlanet map Image' \><img width='300' height='300' src='Usat.jpg'  alt='UPlanet sat Image' \>
    <br> <a href='Umap.html' >MAP</a> | <a href='Usat.html' >SAT</a>
    <br> UMap Key Drive <br>
    <a target=localhost href=http://ipfs.localhost:8080/ipns/${UMAPNS}>LOCAL</a> | <a target=localhost href=${myIPFS}/ipns/${UMAPNS}>GLOBAL</a>

<h2>Umap Visa</h2>
<br>    <img src=G1Visa.${EMAIL}.jpg alt='Umap G1Visa' \>
<h2>Umap Card</h2>
<br>    <img src=G1Card.${EMAIL}.jpg alt='Umap G1Card' \>
<br>
    <script>
        // Function to print the page
        function printPage() {
            window.print();
        }
        // Add click event listener to the print button
        document.getElementById('printButton').addEventListener('click', printPage);
    </script>

    <h2>See <a href='./TW'>TW's</a> here</h2>

<br> Can you <a href='./_ipns.priv.${EMAIL}.asc'>decode this key</a>? Want to know how to use a private key in a browser? <a href='mailto:support@qo-op.com'>Contact us</a>. Let's enhance UPLANET.sh together
        <br><br>ASTROPORT REGISTERED Crypto Commons : $LAT $LON : ${MOATS} : $(date)
     </body></html>" > ~/.zen/tmp/${MOATS}/MESSAGE.html

## HERE YOU PLUG INDEX
# echo "BOO" > ~/.zen/tmp/${MOATS}/index.html
## WHO WILL BE THE G1 WINNER OF THE AREA
# SHOW G1 STATION WALLETS

## TAKING CARE OF THE CHAIN
########################################
IPFSROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/* | tail -n 1)
########################################
ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}/_chain 2>/dev/null)
ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${G1PUB}/_moats 2>/dev/null)
[[ ${ZCHAIN} && ${ZMOATS} ]] \
    && cp ~/.zen/tmp/${MOATS}/${G1PUB}/_chain ~/.zen/tmp/${MOATS}/${G1PUB}/_chain.${ZMOATS} \
    && echo "UPDATING MOATS"

## UPDATE HPASS last G1Visa PASS
HPASS=$(echo $PASS | sha512sum | cut -d ' ' -f 1)
echo "${HPASS}" > ~/.zen/tmp/${MOATS}/${G1PUB}/_${EMAIL}.HPASS

## DOES CHAIN CHANGED or INIT ?
[[ ${ZCHAIN} != ${IPFSROOT} || ${ZCHAIN} == "" ]] \
    && echo "${IPFSROOT}" > ~/.zen/tmp/${MOATS}/${G1PUB}/_chain \
    && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${G1PUB}/_moats \
    && IPFSROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"

########################################
################################################################################
## WRITE INTO 12345 SWARM CACHE LAYER
mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/_visitors
echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${UMAPNS}'\" />" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/index.html
echo "${EMAIL}:${IPFSROOT}:${MOATS}" >> ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/_visitors/${EMAIL}.log
################################################################################
########################################

########################################
echo "PUBLISHING NEW IPFSROOT : http://ipfs.localhost:8080/ipfs/${IPFSROOT}"

    (
    ipfs name publish --key=${G1PUB} /ipfs/${IPFSROOT}
    end=`date +%s`
    ipfs key rm ${G1PUB} ## REMOVE IPNS KEY
    echo "(IPNS) PUBLISH time was "`expr $end - $start` seconds.
    ) &

## HTTP nc ON PORT RESPONSE
echo "$HTTPCORS
    <html>
    <head>
    <title>[Astroport] $LAT $LON + ${EMAIL} </title>
    <meta http-equiv=\"refresh\" content=\"10; url='${myIPFS}/ipns/${TWADD}'\" />
    <style>
        #countdown { display: flex; justify-content: center; align-items: center; color: #0e2c4c; font-size: 20px; width: 60px; height: 60px; background-color: #e7d9fc; border-radius: 50%;}
    </style>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            background-color: #f0f0f0;
            padding: 20px;
        }
        h1 {
            color: #0077cc;
        }
        h2 {
            color: #333;
        }
        img {
            cursor: pointer;
        }
    </style>
    </head><body>
    <h1>UPlanet Registration</h1>
    <br><h2>${EMAIL}, your TW PASS is <bold>${NPASS}</bold></h2>

    ---<br>
    TELEPORTATION
    <br>in
    <h1><center><div id='countdown'></div></center></h1>
    <script>
    var timeLeft = 10;
    var elem = document.getElementById('countdown');
    var timerId = setInterval(countdown, 1000);

    function countdown() {
        if (timeLeft == -1) {
            clearTimeout(timerId);
            doSomething();
        } else {
            elem.innerHTML = timeLeft + ' s';
            timeLeft--;
        }
    }
    </script>
    ---
    <br>
    ( ⚆_⚆) <br>CONSOLE<br>
    $(cat ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt 2>/dev/null)
    <br>(☉_☉ )<br>
    <br><br>${EMAIL} REGISTERED on UMAP : $LAT/$LON : ${MOATS} : $(date)
     </body>
     </html>" > ~/.zen/tmp/${MOATS}/http.rep
cat ~/.zen/tmp/${MOATS}/http.rep | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &


end=`date +%s`
echo "(UPLANET) Operation time was "`expr $end - $start` seconds.
exit 0
