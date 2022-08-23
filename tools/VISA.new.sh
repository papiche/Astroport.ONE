#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
#
SALT="$1"
PEPPER="$2"

## Chargement TW !!!
if [[ $SALT != "" && PEPPER != "" ]]; then
    ASTRO=""
    ipfs key rm gchange
    rm -f ~/.zen/tmp/gchange.key
    ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/gchange.key "$SALT" "$PEPPER"
    GNS=$(ipfs key import gchange -f pem-pkcs8-cleartext ~/.zen/tmp/gchange.key )

    rm -f ~/.zen/tmp/TW.html
    ipfs --timeout 5s get -o ~/.zen/tmp/TW.html /ipns/$GNS

    # Combien de clefs?
    ipfs key list -l | grep -w $GNS
    ipfs key list -l | grep -w $GNS | wc -l


if [ ! -f ~/.zen/tmp/TW.html ]; then
    echo "Première connexion? Appuyez sur ENTRER pour créer un nouveau TW Astronaute"
    read
else
    ASTRO="yes"
    echo "Bienvenue Astronaute. Nous avons capté votre TW"
    echo "http://127.0.0.1:8080/ipns/$GNS"
    echo "Initialisation de votre compte local"
fi

fi

echo "=============================================
MadeInZion DIPLOMATIC PASSPORT
=============================================
A cryptographic key pair to control your P2P Digital Life.
Solar Punk garden forest terraforming game.
=============================================
Bienvenue 'Astronaute'"; sleep 1

echo ""
echo "Création de votre PSEUDO, votre PLAYER, avec PASS (6 chiffres)"

################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

! ipfs swarm peers >/dev/null 2>&1 && echo "Lancez 'ipfs daemon' SVP" && exit 1

[[ $SALT == "" ]] && SALT=$(${MY_PATH}/diceware.sh 4 | xargs)
echo "-> SALT : $SALT"

[[ $PEPPER == "" ]] && PEPPER=$(${MY_PATH}/diceware.sh 2 | xargs)
echo "-> PEPPER : $PEPPER"

echo "CHOISISSEZ UN PSEUDO" && read PSEUDO; PSEUDO=${PSEUDO,,} && [[ $(ls ~/.zen/game/players/$PSEUDO* 2>/dev/null) ]] && echo "CE PSEUDO EST DEJA UN PLAYER. EXIT" && exit 1
# PSEUDO=${PSEUDO,,} #lowercase
PLAYER=${PSEUDO}${RANDOM:0:2}$(${MY_PATH}/diceware.sh 1 | xargs)${RANDOM:0:2}
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


    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/G1SSB # Prepare astrXbian sub-datastructure
    mkdir -p ~/.zen/game/players/$PLAYER/ipfs_swarm

    qrencode -s 12 -o ~/.zen/game/players/$PLAYER/QR.png "$G1PUB"
    cp ~/.zen/game/players/$PLAYER/QR.png ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/QR.png
    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/G1SSB/_g1.pubkey # G1SSB NOTATION (astrXbian compatible)

    secFromDunikey=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep "sec" | cut -d ' ' -f2)
    echo "$secFromDunikey" > /tmp/${PSEUDO}.sec
    openssl enc -aes-256-cbc -salt -in /tmp/${PSEUDO}.sec -out "/tmp/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
    PASsec=$(cat /tmp/enc.${PSEUDO}.sec | base58) && rm -f /tmp/${PSEUDO}.sec
    qrencode -s 12 -o $HOME/.zen/game/players/$PLAYER/QRsec.png $PASsec

    echo "Votre Clef publique G1 est : $G1PUB"; sleep 1

    ### INITALISATION WIKI dans leurs répertoires de publication IPFS
    ############ TODO améliorer templates, sed, ajouter index.html, etc...
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    if [ ! -f ~/.zen/tmp/TW.html ]; then

        echo "Nouveau Canal TW Astronaute"
        mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/

        cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_WISHKEY_~${G1PUB}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html

        sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_QRSEC_~${PASsec}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html


        ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
        # La Clef IPNS porte comme nom G1PUB.
        sed -i "s~_MEDIAKEY_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~k2k4r8naeti1ny2hsk3a0ziwz22urwiu633hauluwopf4vwjk4x68qgk~${ASTRONAUTENS}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html

        myIP=$(hostname -I | awk '{print $1}' | head -n 1)
        sed -i "s~127.0.0.1~$myIP~g" ~/.zen/game/world/$WISHKEY/index.html

        tiddlywiki  --verbose --load ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html \
                            --import ~/.zen/Astroport.ONE/templates/data/local.api.json "application/json" \
                            --import ~/.zen/Astroport.ONE/templates/data/local.gw.json "application/json" \
                            --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"
        [[ -f ~/.zen/tmp/newindex.html ]] && cp ~/.zen/tmp/newindex.html ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html

        ## ID CARD
        convert ~/.zen/game/players/$PLAYER/QR.png -resize 300 /tmp/QR.png
        convert ${MY_PATH}/../images/astroport.jpg  -resize 300 /tmp/ASTROPORT.png

        composite -compose Over -gravity SouthWest -geometry +280+20 /tmp/ASTROPORT.png ${MY_PATH}/../images/Brother_600x400.png /tmp/astroport.png
        composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QR.png /tmp/astroport.png /tmp/one.png
        # composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/.current/QRsec.png /tmp/one.png /tmp/image.png

        convert -gravity northwest -pointsize 35 -fill black -draw "text 50,300 \"$PSEUDO\"" /tmp/one.png /tmp/image.png
        convert -gravity northwest -pointsize 30 -fill black -draw "text 300,40 \"$PLAYER\"" /tmp/image.png /tmp/pseudo.png
        convert -gravity northeast -pointsize 25 -fill black -draw "text 20,180 \"$PASS\"" /tmp/pseudo.png /tmp/pass.png
        convert -gravity northwest -pointsize 25 -fill black -draw "text 300,100 \"$SALT\"" /tmp/pass.png /tmp/salt.png
        convert -gravity northwest -pointsize 25     -fill black -draw "text 300,140 \"$PEPPER\"" /tmp/salt.png ~/.zen/game/players/$PLAYER/ID.png

        # INSERTED IMAGE IPFS
        IASTRO=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ID.png | tail -n 1)
        sed -i "s~bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a~${IASTRO}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html

else

        cp ~/.zen/tmp/TW.html ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html


fi

    ## Copy Astro TW
    [[ $ASTRO == "yes" ]] && cp ~/.zen/tmp/TW.html ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html

    echo "## PUBLISHING ${PLAYER} /ipns/$ASTRONAUTENS/"
    IPUSH=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/ | tail -n 1)
    echo $IPUSH > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/.chain # Contains last IPFS backup PLAYER KEY
    echo "/ipfs/$IPUSH"
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/.moats
    ipfs name publish --key=${PLAYER} /ipfs/$IPUSH 2>/dev/null

    # Lanch newly created TW
#    cd ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/
#    tiddlywiki $PLAYER --verbose --load ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html --listen port=8282
#    sleep 3
#    killall node

    ## MEMORISE PLAYER Ŋ1 ZONE
    echo "$PLAYER" > ~/.zen/game/players/$PLAYER/.player
    echo "$PSEUDO" > ~/.zen/game/players/$PLAYER/.pseudo
    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/.g1pub

    # astrXbian compatible IPFS sub structure =>$XZUID
    cp ~/.zen/game/players/$PLAYER/.player ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/_xbian.zuid
    cp ~/.zen/game/players/$PLAYER/.player ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/
    # PUBLIC Ŋ7 ZONE

    echo "$ASTRONAUTENS" > ~/.zen/game/players/$PLAYER/.playerns

    echo "$SALT" > ~/.zen/game/players/$PLAYER/secret.june
    echo "$PEPPER" >> ~/.zen/game/players/$PLAYER/secret.june

    rm -f ~/.zen/game/players/.current
    ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

qrencode -s 12 -o "$HOME/.zen/game/players/$PLAYER/QR.ASTRONAUTENS.png" "http://127.0.0.1:8080/ipns/$ASTRONAUTENS"

echo; echo "Création de votre clef et QR codes de votre réseau Astroport Ŋ1"; sleep 1

echo; echo "*** Espace Astronaute Activé : ~/.zen/game/players/$PLAYER/"; sleep 1
echo; echo "*** Votre TW Ŋ7 : $PLAYER"; echo "http://127.0.0.1:8080/ipns/$ASTRONAUTENS"; sleep 2

# PASS CRYPTING KEY
echo; echo "Sécurisation de vos clefs par chiffrage SSL... "; sleep 1
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.june" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.june" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.dunikey" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.dunikey" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/$KEYFILE -out" "$HOME/.zen/game/players/$PLAYER/enc.$KEYFILE" -k $PASS 2>/dev/null
## TODO MORE SECURE ?! USE opengpg, natools, etc ...
# ${MY_PATH}/natools.py encrypt -p $G1PUB -i ~/.zen/game/players/$PLAYER/secret.dunikey -o "$HOME/.zen/game/players/$PLAYER/secret.dunikey.oasis"

#################################################
# !! TODO !! # DEMO MODE. REMOVE FOR PRODUCTION
echo "$PASS" > ~/.zen/game/players/$PLAYER/.pass
# ~/.zen/game/players/$PLAYER/secret.june SECURITY TODO
# Astronaut QRCode + PASS = LOGIN (=> DECRYPTING CRYPTO IPFS INDEX)
# TODO : Allow Astronaut PASS change ;)
#####################################################

## DISCONNECT AND CONNECT CURRENT PLAYER
rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

## CREATE GCHANGE+ PROFILE
${MY_PATH}/Connect_PLAYER_To_Gchange.sh

## INIT FRIENDSHIP CAPTAIN/ASTRONAUTS (LATER THROUGH GCHANGE)
## ${MY_PATH}/FRIENDS.init.sh
## NO. GCHANGE+ IS THE MAIN INTERFACE, astrXbian manage
echo "Bienvenue 'Astronaute' $PSEUDO ($PLAYER)"
echo "Retenez votre PASS : $PASS"; sleep 2

echo $PSEUDO > ~/.zen/tmp/PSEUDO ## Return data to start.sh
echo "cool $(${MY_PATH}/face.sh cool)"
echo "Relancez start."
exit 0
