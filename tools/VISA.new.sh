#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

! ipfs swarm peers >/dev/null 2>&1 && echo "Lancez 'ipfs daemon' SVP" && exit 1
################################################################################
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

SALT="$1"
PEPPER="$2"
PLAYER="$3"
PSEUDO="$4"

## Fill UP TW with VIDEO URL
URL="$5"
################################################################################
YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
################################################################################
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
################################################################################
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"
################################################################################

## CHECK if PLAYER resolve any ASTRONAUTENS
[[ ${PLAYER} ]] && ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
[[ ${ASTRONAUTENS} ]] && echo "IPNS $PLAYER EXISTANT http://$myIP:8080/${ASTRONAUTENS} !! DO NOTHING - EXIT -" && exit 0

## Chargement TW !!!
if [[ $SALT != "" && PEPPER != "" ]]; then
    ASTRO=""

    ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/player.key "$SALT" "$PEPPER" 2>/dev/null
    ASTRONAUTENS=$(ipfs key import ${MOATS} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/player.key 2>/dev/null)
    echo "/ipns/${ASTRONAUTENS}"

    ipfs key rm ${MOATS} 2>/dev/null ## CLEANING

    mkdir -p ~/.zen/tmp/${MOATS}/TW

    ## GETTING LAST TW via IPFS or HTTP GW
    [[ $YOU ]] \
    && echo "ipfs --timeout 30s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/${MOATS}/TW/index.html ($YOU)" \
    && ipfs --timeout 30s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/${MOATS}/TW/index.html

    [[ ! -s ~/.zen/tmp/${MOATS}/TW/index.html ]] \
    && echo "TRYING $LIBRA/ipns/${ASTRONAUTENS}" \
    && curl -m 30 -so ~/.zen/tmp/${MOATS}/TW/index.html "$LIBRA/ipns/${ASTRONAUTENS}"

    #############################################
    ## AUCUN RESULTAT
    if [ ! -s ~/.zen/tmp/${MOATS}/TW/index.html ]; then

        rm -f ~/.zen/tmp/${MOATS}/TW/index.html
        echo "CREATION TW Astronaute" ## Nouveau Compte Astronaute

    else
    #############################################
    # TW : DATA TESTING & CACHE
        rm -f ~/.zen/tmp/${MOATS}/Astroport.json
        tiddlywiki --load ~/.zen/tmp/${MOATS}/TW/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
        ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)

        IPNSTAIL=$(echo $ASTROPORT | rev | cut -f 1 -d '/' | rev)
        echo "TW ASTROPORT GATEWAY : ${ASTROPORT}"

        [[ $IPNSTAIL == $IPFSNODEID ]] \
        && echo "UPDATING $PLAYER LOCAL CACHE ~/.zen/game/players/$PLAYER/ipfs/moa" \
        && mkdir -p ~/.zen/game/players/$PLAYER/ipfs/moa \
        && cp ~/.zen/tmp/${MOATS}/TW/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/ \
        || echo "PLAYER on $ASTROPORT Station"

        # DO NOT CONTINUE
        echo "VISA ALREADY EXISTING"

        rm -Rf ~/.zen/tmp/${MOATS}

        exit 1

    fi

fi
################################################################################
TWMODEL="/ipfs/bafybeifnanmthip6iv3jhgm7cmtd3qld3ppqbizhypft32j7p7lrmflpuq"
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
[[ $(ls ~/.zen/game/players/$PSEUDO* 2>/dev/null) ]] && echo "CE PSEUDO EST DEJA UN PLAYER. EXIT" && exit 1

# PSEUDO=${PSEUDO,,} #lowercase
[[ ! $PLAYER ]] && PLAYER=${PSEUDO}${RANDOM:0:2}$(${MY_PATH}/diceware.sh 1 | xargs)${RANDOM:0:2} \
                            && echo "$PLAYER ! VOTRE EMAIL SVP ?" && read OPLAYER && [[ $OPLAYER ]] && PLAYER=$OPLAYER
[[ -d ~/.zen/game/players/$PLAYER ]] && echo "FATAL ERROR $PLAYER NAME COLLISION. TRY AGAIN." && exit 1

[[ ! $PSEUDO ]] && PSEUDO=$PLAYER
echo; echo "Génération de vos identités Astronaute (PLAYER):"; sleep 1; echo "$PLAYER"; sleep 2

# 6 DIGIT PASS CODE TO PROTECT QRSEC
PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

############################################################
######### TODO Ajouter d'autres clefs IPNS, GPG ?
# MOANS=$(ipfs key gen moa_$PLAYER)
# MOAKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "moa_$PLAYER")
# echo "Coffre personnel multimedia journalisé dans votre 'Astroport' (amis de niveau 3)"
# echo "Votre clef moa_$PLAYER <=> $MOANS ($MOAKEYFILE)"; sleep 2
############################################################
echo
echo "Compte Gchange et portefeuille G1.
Utilisez ces identifiants pour rejoindre le réseau JUNE

    $SALT
    $PEPPER

Rendez-vous sur https://gchange.fr"; sleep 3

echo; echo "Création de votre clef multi-accès..."; sleep 2
echo;

${MY_PATH}/keygen -t duniter -o /tmp/secret.dunikey "$SALT" "$PEPPER"

G1PUB=$(cat /tmp/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)

[[ ! $G1PUB ]] && echo "Désolé. clef Cesium absente." && exit 1


    ## CREATE Player personnal files storage and IPFS publish directory
    mkdir -p ~/.zen/game/players/$PLAYER # Prepare PLAYER datastructure
    mkdir -p ~/.zen/tmp/

    mv /tmp/secret.dunikey ~/.zen/game/players/$PLAYER/

    # Create Player "IPNS Key" (key import)
    ${MY_PATH}/keygen -t ipfs -o ~/.zen/game/players/$PLAYER/secret.player "$SALT" "$PEPPER"
    ipfs key import $PLAYER -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/secret.player
    ASTRONAUTENS=$(ipfs key import $G1PUB -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/secret.player)

    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/G1SSB # Prepare astrXbian sub-datastructure

    qrencode -s 12 -o ~/.zen/game/players/$PLAYER/QR.png "$G1PUB"
    cp ~/.zen/game/players/$PLAYER/QR.png ~/.zen/game/players/$PLAYER/ipfs/QR.png
    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/ipfs/G1SSB/_g1.pubkey # G1SSB NOTATION (astrXbian compatible)

    secFromDunikey=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep "sec" | cut -d ' ' -f2)
    echo "$secFromDunikey" > /tmp/${PSEUDO}.sec
    openssl enc -aes-256-cbc -salt -in /tmp/${PSEUDO}.sec -out "/tmp/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
    PASsec=$(cat /tmp/enc.${PSEUDO}.sec | base58) && rm -f /tmp/${PSEUDO}.sec
    qrencode -s 12 -o $HOME/.zen/game/players/$PLAYER/QRsec.png $PASsec

    echo "Votre Clef publique G1 est : $G1PUB"; sleep 1

    ### INITALISATION WIKI dans leurs répertoires de publication IPFS
    ############ TODO améliorer templates, sed, ajouter index.html, etc...
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
        echo
        echo "***** Activation du Canal TW Astronaute $PLAYER *****"
        mkdir -p ~/.zen/game/players/$PLAYER/ipfs/moa/
        cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        # INSERT ASTROPORT ADRESS
        tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
        ASTROPORT=$(cat ~/.zen/tmp/Astroport.json | jq -r .[].astroport)
        sed -i "s~$ASTROPORT~/ipns/${IPFSNODEID}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

         # TW CHAIN INIT WITH TWMODEL
         sed -i "s~_MOATS_~${MOATS}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
         sed -i "s~_CHAIN_~${TWMODEL}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

         sed -i "s~_URL_~${URL}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        # INSERT PLAYER DATA
        sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        sed -i "s~_WISHKEY_~${G1PUB}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        sed -i "s~_QRSEC_~${PASsec}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        sed -i "s~G1Voeu~G1Visa~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
        # La Clef IPNS porte comme nom G1PUB
        sed -i "s~_MEDIAKEY_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        sed -i "s~k2k4r8kxfnknsdf7tpyc46ks2jb3s9uvd3lqtcv9xlq9rsoem7jajd75~${ASTRONAUTENS}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        sed -i "s~ipfs.infura.io~ipfs.copylaradio.com~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html # USELESS ?!

#
        sed -i "s~127.0.0.1~$myIP~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html # 8080 & 5001 BEING THE RECORDING GATEWAY (WAN or ipfs.localhost)

#
        echo "# CRYPTO ENCODING secret.dunikey -> TW _SECRET_ "
        echo $myIP > ~/.zen/tmp/myIP
        $MY_PATH/natools.py encrypt -p $G1PUB -i $HOME/.zen/game/players/$PLAYER/secret.dunikey -o $HOME/.zen/tmp/secret.dunikey.$G1PUB.enc
        ENCODING=$(cat ~/.zen/tmp/secret.dunikey.$G1PUB.enc | base16)
        sed -i "s~_SECRET_~$ENCODING~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
#
        echo "# CRYPTO DECODING TEST"
        tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        cat ~/.zen/tmp/MadeInZion.json | jq -r .[].secret | base16 -d > ~/.zen/tmp/myIP.$G1PUB.enc.2
        $MY_PATH/natools.py decrypt -f pubsec -k $HOME/.zen/game/players/$PLAYER/secret.dunikey -i $HOME/.zen/tmp/myIP.$G1PUB.enc.2 -o $HOME/.zen/tmp/myIP.2
#
        ## CRYPTO PROCESS VALIDATED
        [[ -s ~/.zen/tmp/myIP.2 ]] && echo "NATOOLS ENCODED secret LAODED" \
                                                        || sed -i "s~$ENCODING~$myIP~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html # Revert to plaintext _SECRET_ myIP

        rm -f ~/.zen/tmp/myIP.2

        ## ADD SYSTEM TW
        tiddlywiki  --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html \
                            --import ~/.zen/Astroport.ONE/templates/data/local.api.json "application/json" \
                            --import ~/.zen/Astroport.ONE/templates/data/local.gw.json "application/json" \
                            --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"
        [[ -f ~/.zen/tmp/newindex.html ]] && cp ~/.zen/tmp/newindex.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

        ## ID CARD
        convert ~/.zen/game/players/$PLAYER/QR.png -resize 300 /tmp/QR.png
        convert ${MY_PATH}/../images/astroport.jpg  -resize 300 /tmp/ASTROPORT.png

        composite -compose Over -gravity SouthWest -geometry +280+20 /tmp/ASTROPORT.png ${MY_PATH}/../images/Brother_600x400.png /tmp/astroport.png
        composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QR.png /tmp/astroport.png /tmp/one.png
        # composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/.current/QRsec.png /tmp/one.png /tmp/image.png

        convert -gravity northwest -pointsize 35 -fill black -draw "text 50,300 \"$PSEUDO\"" /tmp/one.png /tmp/image.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,40 \"$PLAYER\"" /tmp/image.png /tmp/pseudo.png
        convert -gravity northeast -pointsize 25 -fill black -draw "text 20,180 \"$PASS\"" /tmp/pseudo.png /tmp/pass.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,100 \"$SALT\"" /tmp/pass.png /tmp/salt.png
        convert -gravity northwest -pointsize 25     -fill black -draw "text 300,140 \"$PEPPER\"" /tmp/salt.png ~/.zen/game/players/$PLAYER/ID.png

        # INSERTED IMAGE IPFS
        IASTRO=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ID.png | tail -n 1)
        sed -i "s~bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a~${IASTRO}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

    echo
    echo "## PUBLISHING ${PLAYER}"
    echo "/ipns/${ASTRONAUTENS}/"
    IPUSH=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    echo $IPUSH > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain # Contains last IPFS backup PLAYER KEY
    echo "/ipfs/$IPUSH"
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats

    (
    ipfs name publish --key=${PLAYER} /ipfs/$IPUSH >/dev/null 2>&1
    ) &

    ## MEMORISE PLAYER Ŋ1 ZONE
    echo "$PLAYER" > ~/.zen/game/players/$PLAYER/.player
    echo "$PSEUDO" > ~/.zen/game/players/$PLAYER/.pseudo
    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/.g1pub

    # astrXbian compatible IPFS sub structure =>$XZUID
    cp ~/.zen/game/players/$PLAYER/.player ~/.zen/game/players/$PLAYER/ipfs/_xbian.zuid
    cp ~/.zen/game/players/$PLAYER/.player ~/.zen/game/players/$PLAYER/ipfs/
    # PUBLIC Ŋ7 ZONE

    echo "${ASTRONAUTENS}" > ~/.zen/game/players/$PLAYER/.playerns

    echo "$SALT" > ~/.zen/game/players/$PLAYER/secret.june
    echo "$PEPPER" >> ~/.zen/game/players/$PLAYER/secret.june

    rm -f ~/.zen/game/players/.current
    ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current # LOCAL LOGIN

qrencode -s 12 -o "$HOME/.zen/game/players/$PLAYER/QR.ASTRONAUTENS.png" "https://ipfs.copylaradio.com/ipns/${ASTRONAUTENS}"

echo; echo "Création de votre Clef et QR codes d'accès au niveau Astroport Ŋ1"; sleep 1

echo; echo "*** HOME : ~/.zen/game/players/$PLAYER/"; sleep 1
echo "*** IPNS Ŋ0 KEY : $PLAYER";
echo; echo "GW : https://ipfs.copylaradio.com/ipns/${ASTRONAUTENS}"; sleep 1

# PASS CRYPTING KEY
#~ echo; echo "Sécurisation de vos clefs... "; sleep 1
#~ openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.june" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.june" -k $PASS 2>/dev/null
#~ openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.dunikey" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.dunikey" -k $PASS 2>/dev/null
#~ openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/$KEYFILE -out" "$HOME/.zen/game/players/$PLAYER/enc.$KEYFILE" -k $PASS 2>/dev/null
## TODO MORE SECURE ?! USE opengpg, natools, etc ...
# ${MY_PATH}/natools.py encrypt -p $G1PUB -i ~/.zen/game/players/$PLAYER/secret.dunikey -o "$HOME/.zen/game/players/$PLAYER/enc.secret.dunikey"
echo

#################################################
# !! TODO !! # DEMO MODE. REMOVE FOR PRODUCTION - RECALCULATE AND RENEW AFTER EACH NEW KEY DELEGATION
echo "$PASS" > ~/.zen/game/players/$PLAYER/.pass
# ~/.zen/game/players/$PLAYER/secret.june SECURITY TODO
# Astronaut QRCode + PASS = LOGIN (=> DECRYPTING CRYPTO IPFS INDEX)
# TODO : Allow Astronaut PASS change ;)
#####################################################

## DISCONNECT AND CONNECT CURRENT PLAYER
rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

## MANAGE GCHANGE+ & Ŋ1 EXPLORATION
${MY_PATH}/Connect_PLAYER_To_Gchange.sh "$PLAYER"

### IF PRINTER -> PRINT VISA
LP=$(ls /dev/usb/lp*)
[[ $LP ]] && ${MY_PATH}/VISA.print.sh &

## INIT FRIENDSHIP CAPTAIN/ASTRONAUTS (LATER THROUGH GCHANGE)
## ${MY_PATH}/FRIENDS.init.sh
## NO. GCHANGE+ IS THE MAIN INTERFACE, astrXbian manage
echo "$(${MY_PATH}/face.sh cool)"
echo "Bienvenue 'Astronaute' $PSEUDO ($PLAYER)"
echo "Votre PASS"; sleep 1

echo $PSEUDO > ~/.zen/tmp/PSEUDO ## Return data to start.sh

echo "$PASS"



exit 0
