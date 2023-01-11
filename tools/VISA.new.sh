#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

! ipfs swarm peers >/dev/null 2>&1 && echo "Lancez 'ipfs daemon' SVP" && exit 1
################################################################################
mkdir -p ~/.zen/tmp/${MOATS}

SALT="$1"
PEPPER="$2"
PLAYER="$3"
PSEUDO="$4"

## Fill UP TW with VIDEO URL
URL="$5"
################################################################################
YOU=$(myIpfsApi);
LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
################################################################################

################################################################################

## CHECK if PLAYER resolve any ASTRONAUTENS
[[ ${PLAYER} ]] && ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
[[ ${ASTRONAUTENS} ]] && echo "WARNING IPNS ${PLAYER} EXISTANT ${myIPFS}/ipns/${ASTRONAUTENS} - EXIT -" && exit 0

## Chargement TW !!!
if [[ $SALT != "" && PEPPER != "" ]]; then
    ASTRO=""

    ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/player.key "$SALT" "$PEPPER" 2>/dev/null
    ASTRONAUTENS=$(ipfs key import ${MOATS} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/player.key 2>/dev/null)
    # echo "/ipns/${ASTRONAUTENS}"

    ipfs key rm ${MOATS} 2>/dev/null ## CLEANING

    mkdir -p ~/.zen/tmp/${MOATS}/TW

    echo "SCANNING /ipns/${ASTRONAUTENS}"
    ## GETTING LAST TW via IPFS or HTTP GW
    [[ $YOU ]] \
    && ipfs --timeout 30s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/${MOATS}/TW/index.html

    [[ ! -s ~/.zen/tmp/${MOATS}/TW/index.html ]] \
    && curl -m 12 -so ~/.zen/tmp/${MOATS}/TW/index.html "$LIBRA/ipns/${ASTRONAUTENS}"

    #############################################
    ## AUCUN RESULTAT
    if [ ! -s ~/.zen/tmp/${MOATS}/TW/index.html ]; then

        rm -f ~/.zen/tmp/${MOATS}/TW/index.html
        echo "CREATION TW Astronaute" ## Nouveau Compte Astronaute
        echo
        echo "***** Activation du Canal TW Astronaute ${PLAYER} *****"
        mkdir -p ~/.zen/game/players/${PLAYER}/ipfs/moa/
        cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    else
    #############################################
    # TW : DATA TESTING & CACHE
        rm -f ~/.zen/tmp/${MOATS}/Astroport.json
        tiddlywiki --load ~/.zen/tmp/${MOATS}/TW/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
        ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)

        if [[ $ASTROPORT ]]; then

            IPNSTAIL=$(echo $ASTROPORT | rev | cut -f 1 -d '/' | rev)
            echo "TW ASTROPORT GATEWAY : ${ASTROPORT}"

            [[ $IPNSTAIL == "_ASTROPORT_" ]] \
            && echo "_ASTROPORT_ TW : CONNECT TO DOCK" \
            && mkdir -p ~/.zen/game/players/${PLAYER}/ipfs/moa/ \
            && cp ~/.zen/tmp/${MOATS}/TW/index.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
            && echo "- WARNING - WARNING - WARNING - WARNING - PLEASE VERIFY TW -"

            [[ $IPNSTAIL == $IPFSNODEID ]] \
            && echo "UPDATING ${PLAYER} LOCAL CACHE ~/.zen/game/players/${PLAYER}/ipfs/moa" \
            && mkdir -p ~/.zen/game/players/${PLAYER}/ipfs/moa \
            && cp ~/.zen/tmp/${MOATS}/TW/index.html ~/.zen/game/players/${PLAYER}/ipfs/moa/ \
            || ( echo "PLAYER ALREADY CONNECTED TO $ASTROPORT STATION" && exit 1)

        else

            echo "ERROR BAD TW - Missing Astroport Tiddler ?"
            exit 1

        fi

        rm -Rf ~/.zen/tmp/${MOATS}

    fi

fi
################################################################################
TWMODEL="/ipfs/bafybeifdifxlikk4bwjdkvh4inm4bzck4do5hzw5gctylzubwmjejmqt3a"
# ipfs cat $TWMODEL > templates/twdefault.html
##################################################### # NEW PLAYER ###############
################################################################################
echo "=============================================
ASTROPORT DIPLOMATIC PASSPORT - MadeInZion VISA -
=============================================
A Cryptographic Key to control your INTERNET
Adventure & Exploration P2P Terraforming Game.
=============================================
Bienvenue 'Astronaute'"; sleep 1

echo "Création de votre PLAYER, votre PSEUDO et PASS (6 chiffres)"

[[ $SALT == "" ]] && SALT=$(${MY_PATH}/diceware.sh 4 | xargs)
echo "-> SALT : $SALT"

[[ $PEPPER == "" ]] && PEPPER=$(${MY_PATH}/diceware.sh 2 | xargs)
echo "-> PEPPER : $PEPPER"

PSEUDO=${PLAYER%%[0-9]*}

[[ ! $PSEUDO ]] && echo "Choisissez un pseudo : " && read PSEUDO
PSEUDO=${PSEUDO,,}
PSEUDO=${PSEUDO%%[0-9]*}
[[ $(ls ~/.zen/game/players/$PSEUDO 2>/dev/null) ]] && echo "CE PSEUDO EST DEJA UN PLAYER. EXIT" && exit 1

# PSEUDO=${PSEUDO,,} #lowercase
[[ ! ${PLAYER} ]] && PLAYER=${PSEUDO}${RANDOM:0:3}@$(${MY_PATH}/diceware.sh 1 | xargs).${RANDOM:0:3} \
                            && echo "ADRESSE EMAIL ?" && read OPLAYER && [[ $OPLAYER ]] && PLAYER=$OPLAYER

[[ ! $PSEUDO ]] && PSEUDO="Anonymous"
echo; echo "Génération de votre crypto identité PLAYER :"; sleep 1; echo "${PLAYER}"; sleep 2

# 6 DIGIT PASS CODE TO PROTECT QRSEC
PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

############################################################
######### TODO Ajouter d'autres clefs IPNS, GPG ?
# MOANS=$(ipfs key gen moa_${PLAYER})
# MOAKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "moa_${PLAYER}")
# echo "Coffre personnel multimedia journalisé dans votre 'Astroport' (amis de niveau 3)"
# echo "Votre clef moa_${PLAYER} <=> $MOANS ($MOAKEYFILE)"; sleep 2
############################################################
echo
echo; echo "Création de votre clef multi-accès..."; sleep 2
echo;

${MY_PATH}/keygen -t duniter -o ~/.zen/tmp/${MOATS}/secret.dunikey "$SALT" "$PEPPER"

G1PUB=$(cat ~/.zen/tmp/${MOATS}/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)

[[ ! $G1PUB ]] && echo "Désolé. clef Cesium absente." && exit 1


    ## CREATE Player personnal files storage and IPFS publish directory
    mkdir -p ~/.zen/game/players/${PLAYER} # Prepare PLAYER datastructure

        # PLAYER=geg-la_debrouille@super.chez-moi.com
YUSER=$(echo ${PLAYER} | cut -d '@' -f1)    # YUSER=geg-la_debrouille
LYUSER=($(echo "$YUSER" | sed 's/[^a-zA-Z0-9]/\ /g')) # LYUSER=(geg la debrouille)
CLYUSER=$(printf '%s\n' "${LYUSER[@]}" | tac | tr '\n' '.' ) # CLYUSER=debrouille.la.geg.
YOMAIN=$(echo ${PLAYER} | cut -d '@' -f 2)    # YOMAIN=super.chez-moi.com
# echo "NEXT STYLE GW : https://ipfs.$CLYUSER$YOMAIN.$(myHostName)"
# echo "MY PLAYER API GW : $(myPlayerApiGw)"

NID="${myIPFS}"
WID="https://ipfs.$CLYUSER$YOMAIN.$(myHostName)/api" ## Next Generation API # TODO PLAYER IPFS Docker entrance
WID="https://ipfs.$(myHostName)/api"
WID="http://ipfs.$(myHostName):5001"


[[ $isLAN ]] && NID="http://astroport.localhost:8080" \
                        && WID="http://astroport.localhost:5001"

####

    mv ~/.zen/tmp/${MOATS}/secret.dunikey ~/.zen/game/players/${PLAYER}/

    # Create Player "IPNS Key" (key import)
    ${MY_PATH}/keygen -t ipfs -o ~/.zen/game/players/${PLAYER}/secret.player "$SALT" "$PEPPER"
    ipfs key import ${PLAYER} -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/secret.player
    ASTRONAUTENS=$(ipfs key import $G1PUB -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/secret.player)

    mkdir -p ~/.zen/game/players/${PLAYER}/ipfs/G1SSB # Prepare astrXbian sub-datastructure

    qrencode -s 12 -o ~/.zen/game/players/${PLAYER}/QR.png "$G1PUB"
    cp ~/.zen/game/players/${PLAYER}/QR.png ~/.zen/game/players/${PLAYER}/ipfs/QR.png
    echo "$G1PUB" > ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.pubkey # G1SSB NOTATION (astrXbian compatible)

    qrencode -s 12 -o ~/.zen/game/players/${PLAYER}/QR.ASTRONAUTENS.png "$LIBRA/ipns/${ASTRONAUTENS}"


    ## SEC PASS PROTECTED QRCODE
    secFromDunikey=$(cat ~/.zen/game/players/${PLAYER}/secret.dunikey | grep "sec" | cut -d ' ' -f2)
    echo "$secFromDunikey" > ~/.zen/tmp/${MOATS}/${PSEUDO}.sec
    openssl enc -aes-256-cbc -salt -in ~/.zen/tmp/${MOATS}/${PSEUDO}.sec -out "$HOME/.zen/tmp/${MOATS}/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
    PASsec=$(cat ~/.zen/tmp/${MOATS}/enc.${PSEUDO}.sec | base58) && rm -f ~/.zen/tmp/${MOATS}/${PSEUDO}.sec
    qrencode -s 12 -o $HOME/.zen/game/players/${PLAYER}/QRsec.png $PASsec



    ### INITALISATION WIKI dans leurs répertoires de publication IPFS
    ############ TODO améliorer templates, sed, ajouter index.html, etc...

        sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        # INSERT ASTROPORT ADRESS
        tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
        ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)
        sed -i "s~$ASTROPORT~/ipns/${IPFSNODEID}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

         # TW CHAIN INIT WITH TWMODEL
         sed -i "s~_MOATS_~${MOATS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
         sed -i "s~_CHAIN_~${TWMODEL}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

         sed -i "s~_SALT_~${SALT}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
         sed -i "s~_PEPPER_~${PEPPER}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
         sed -i "s~_PASS_~${PASS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

         sed -i "s~_URL_~${URL}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        # INSERT PLAYER DATA
        sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~_WISHKEY_~${G1PUB}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~_QRSEC_~${PASsec}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        sed -i "s~G1Voeu~G1Visa~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
        # La Clef IPNS porte comme nom G1PUB
        sed -i "s~_MEDIAKEY_~${PLAYER}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~k2k4r8kxfnknsdf7tpyc46ks2jb3s9uvd3lqtcv9xlq9rsoem7jajd75~${ASTRONAUTENS}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        sed -i "s~tube.copylaradio.com~$myTUBE~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        sed -i "s~ipfs.copylaradio.com~$myTUBE~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

#
        sed -i "s~127.0.0.1~$myIP~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html # 8080 & 5001 BEING THE RECORDING GATEWAY (WAN or ipfs.localhost)

###########
        echo "# CRYPTO ENCODING  _SECRET_ "
        $MY_PATH/natools.py encrypt -p $G1PUB -i $HOME/.zen/game/players/${PLAYER}/secret.dunikey -o $HOME/.zen/tmp/${MOATS}/secret.dunikey.$G1PUB.enc
        ENCODING=$(cat ~/.zen/tmp/${MOATS}/secret.dunikey.$G1PUB.enc | base16)
        sed -i "s~_SECRET_~$ENCODING~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        echo "$ENCODING"
###########
        echo "# CRYPTO DECODING TESTING..."
        tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r .[].secret | base16 -d > ~/.zen/tmp/${MOATS}/crypto.$G1PUB.enc.2
        $MY_PATH/natools.py decrypt -f pubsec -k $HOME/.zen/game/players/${PLAYER}/secret.dunikey -i $HOME/.zen/tmp/${MOATS}/crypto.$G1PUB.enc.2 -o $HOME/.zen/tmp/${MOATS}/crypto.2
###########
        ## CRYPTO PROCESS VALIDATED
        [[ -s ~/.zen/tmp/${MOATS}/crypto.2 ]] && echo "NATOOLS LOADED" \
                                                        || sed -i "s~$ENCODING~$myIP~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html # Revert to plaintext _SECRET_ myIP
        rm -f ~/.zen/tmp/${MOATS}/crypto.2
###########

    ### CREATE $NID ADDRESS FOR API & ROUND ROBIN FOR GW
    cat ~/.zen/Astroport.ONE/templates/data/local.api.json | sed "s~_NID_~${WID}~g" > ~/.zen/tmp/${MOATS}/local.api.json
    cat ~/.zen/Astroport.ONE/templates/data/local.gw.json | sed "s~_NID_~${NID}~g" > ~/.zen/tmp/${MOATS}/local.gw.json

    # Create"${PLAYER}_feed" Key
    FEEDNS=$(ipfs key gen "${PLAYER}_feed")

    ## MAKE LightBeam Plugin Tiddler ${PLAYER}_feed
    # $:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key
    echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-name","text":"'${PLAYER}_feed'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-name.json
    echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key","text":"'${FEEDNS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-key.json

    echo "TW IPFS GATEWAY : $NID"
    # cat ~/.zen/tmp/${MOATS}/local.gw.json | jq -r
    echo "TW IPFS API : $WID"
    # cat ~/.zen/tmp/${MOATS}/local.api.json | jq -r

    ## CHANGE SELECTED GW & API

        ## ADD SYSTEM TW
        tiddlywiki  --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-name.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-key.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/local.api.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/local.gw.json "application/json" \
    --import "$HOME/.zen/Astroport.ONE/templates/tw/$_ipfs_saver_api.json" "application/json" \
    --import "$HOME/.zen/Astroport.ONE/templates/tw/$_ipfs_saver_gateway.json" "application/json" \
                            --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "newindex.html" "text/plain"

        [[ -s ~/.zen/tmp/${MOATS}/newindex.html ]] && cp -f ~/.zen/tmp/${MOATS}/newindex.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html && echo "NEWINDEX OK"

        ## ID CARD & QRCODE
        convert ~/.zen/game/players/${PLAYER}/QR.png -resize 300 ~/.zen/tmp/${MOATS}/QR.png
        convert ~/.zen/game/players/${PLAYER}/QR.ASTRONAUTENS.png -resize 240 ~/.zen/tmp/${MOATS}/TW.png
        convert ${MY_PATH}/../images/astroport.jpg  -resize 240 ~/.zen/tmp/${MOATS}/ASTROPORT.png


        composite -compose Over -gravity SouthWest -geometry +280+20 ~/.zen/tmp/${MOATS}/ASTROPORT.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/${MOATS}/astroport.png
        composite -compose Over -gravity East -geometry +0+0 ~/.zen/tmp/${MOATS}/TW.png ~/.zen/tmp/${MOATS}/astroport.png ~/.zen/tmp/${MOATS}/astroport2.png
        composite -compose Over -gravity NorthWest -geometry +0+0 ~/.zen/tmp/${MOATS}/QR.png ~/.zen/tmp/${MOATS}/astroport2.png ~/.zen/tmp/${MOATS}/one.png
        # composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/.current/QRsec.png ~/.zen/tmp/${MOATS}/one.png ~/.zen/tmp/${MOATS}/image.png

        convert -gravity northwest -pointsize 35 -fill black -draw "text 50,300 \"$PSEUDO\"" ~/.zen/tmp/${MOATS}/one.png ~/.zen/tmp/${MOATS}/image.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,40 \"${PLAYER}\"" ~/.zen/tmp/${MOATS}/image.png ~/.zen/tmp/${MOATS}/pseudo.png



        convert -gravity northeast -pointsize 25 -fill black -draw "text 20,180 \"$PASS\"" ~/.zen/tmp/${MOATS}/pseudo.png ~/.zen/tmp/${MOATS}/pass.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,100 \"$SALT\"" ~/.zen/tmp/${MOATS}/pass.png ~/.zen/tmp/${MOATS}/salt.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,140 \"$PEPPER\"" ~/.zen/tmp/${MOATS}/salt.png ~/.zen/game/players/${PLAYER}/ID.png

        # INSERTED IMAGE IPFS
        # IASTRO=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ID.png | tail -n 1) ## G1VISA PUBLIC / PRIVATE
        IASTRO=$(ipfs add -Hq ~/.zen/tmp/${MOATS}/pseudo.png | tail -n 1) ## G1VISA PUBLIC ONLY
        sed -i "s~bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a~${IASTRO}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    echo
    echo "## PUBLISHING ${PLAYER}"
    echo "/ipns/${ASTRONAUTENS}/"
    IPUSH=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    echo $IPUSH > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain # Contains last IPFS backup PLAYER KEY
    echo "/ipfs/$IPUSH"
    echo $MOATS > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats

    (
    ipfs name publish --key=${PLAYER} /ipfs/$IPUSH >/dev/null 2>&1
    ) &

    ## MEMORISE PLAYER Ŋ1 ZONE
    echo "${PLAYER}" > ~/.zen/game/players/${PLAYER}/.player
    echo "$PSEUDO" > ~/.zen/game/players/${PLAYER}/.pseudo
    echo "$G1PUB" > ~/.zen/game/players/${PLAYER}/.g1pub

    echo "${ASTRONAUTENS}" > ~/.zen/game/players/${PLAYER}/.playerns

    echo "SALT=$SALT" > ~/.zen/game/players/${PLAYER}/secret.june
    echo "PEPPER=$PEPPER" >> ~/.zen/game/players/${PLAYER}/secret.june

echo; echo "Création Clefs et QR codes pour accès au niveau Astroport Ŋ1"; sleep 1

echo "--- PLAYER : ${PLAYER}";

[[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open "${myIPFS}/ipns/${ASTRONAUTENS}"

################# PREPARE DOCKERIZATION
rm ~/.zen/game/players/.current
ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current
. "$MY_PATH/my.sh"

#################################################################
#### make player ipfs docker ## TODO
# [[ $USER == 'zen' ]] && make player MAIL=$(myPlayer) USER_HOST=$(myPlayerHost) > /dev/null 2>&1
## 1ST RELEASE BASED ON DIRECT NODE IPFSNODEID KEY "ADD / DEL" API
#################################################################
#################################################################
#################################################################
#################################################################


# PASS CRYPTING KEY
#~ echo; echo "Sécurisation de vos clefs... "; sleep 1
#~ openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/${PLAYER}/secret.june" -out "$HOME/.zen/game/players/${PLAYER}/enc.secret.june" -k $PASS 2>/dev/null
#~ openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/${PLAYER}/secret.dunikey" -out "$HOME/.zen/game/players/${PLAYER}/enc.secret.dunikey" -k $PASS 2>/dev/null
#~ openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/${PLAYER}/$KEYFILE -out" "$HOME/.zen/game/players/${PLAYER}/enc.$KEYFILE" -k $PASS 2>/dev/null
## TODO MORE SECURE ?! USE opengpg, natools, etc ...
# ${MY_PATH}/natools.py encrypt -p $G1PUB -i ~/.zen/game/players/${PLAYER}/secret.dunikey -o "$HOME/.zen/game/players/${PLAYER}/enc.secret.dunikey"
echo

#################################################
# !! TODO !! # DEMO MODE. REMOVE FOR PRODUCTION - RECALCULATE AND RENEW AFTER EACH NEW KEY DELEGATION
echo "$PASS" > ~/.zen/game/players/${PLAYER}/.pass
# ~/.zen/game/players/${PLAYER}/secret.june SECURITY TODO
# Astronaut QRCode + PASS = LOGIN (=> DECRYPTING CRYPTO IPFS INDEX)
# TODO : Allow Astronaut PASS change ;)
#####################################################

## DISCONNECT AND CONNECT CURRENT PLAYER
#~ rm -f ~/.zen/game/players/.current
#~ ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

## MANAGE GCHANGE+ & Ŋ1 EXPLORATION
${MY_PATH}/Connect_PLAYER_To_Gchange.sh "${PLAYER}"

### IF PRINTER -> PRINT VISA
LP=$(ls /dev/usb/lp* 2>/dev/null)
[[ $LP ]] && ${MY_PATH}/VISA.print.sh "${PLAYER}" &

## INIT FRIENDSHIP CAPTAIN/ASTRONAUTS (LATER THROUGH GCHANGE)
## ${MY_PATH}/FRIENDS.init.sh
## NO. GCHANGE+ IS THE MAIN INTERFACE, astrXbian manage
echo "$(${MY_PATH}/face.sh cool)"
echo "Bienvenue 'Astronaute'  $PSEUDO"
echo
echo "${PLAYER}"
echo "Clef Publique : $G1PUB"; sleep 1
echo "
Phrases de connexion :
    $SALT
    $PEPPER

PASS : $PASS

:start: system https://gchange.fr"; sleep 1
echo "$(${MY_PATH}/face.sh friendly)"

echo; echo "VISA : ${myIPFS}/ipfs/${IASTRO}"
echo; echo "TW : ${myIPFS}/ipns/${ASTRONAUTENS}"
echo; echo "RSS : ${myIPFS}/ipns/${FEEDNS}"; sleep 1

echo $PSEUDO > ~/.zen/tmp/PSEUDO ## Return data to start.sh

echo "export ASTROTW=/ipns/$ASTRONAUTENS ASTROG1=$G1PUB ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS"

## CLEANING CACHE
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
