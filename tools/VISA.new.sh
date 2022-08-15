#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
#
[[ $1 != "quiet" ]] && echo "=============================================
MadeInZion DIPLOMATIC PASSPORT
=============================================
A cryptographic key pair to control your P2P Digital Life.
Solar Punk garden forest terraforming game.
=============================================
Bienvenue 'Astronaute'"; sleep 1

echo ""

################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

! ipfs swarm peers >/dev/null 2>&1 && echo "Lancez 'ipfs daemon' SVP" && exit 1

SALT=$(${MY_PATH}/diceware.sh 4 | xargs)
# [[ $1 != "quiet" ]] && echo "-> SALT : $SALT"

PEPPER=$(${MY_PATH}/diceware.sh 2 | xargs)
# [[ $1 != "quiet" ]] && echo "-> PEPPER : $PEPPER"

echo "Création de votre PSEUDO, votre PLAYER, avec PASS (6 chiffres)"

[[ $1 != "quiet" ]] && echo "CHOISISSEZ UN PSEUDO" && read PSEUDO; PSEUDO=${PSEUDO,,} && [[ $(ls ~/.zen/game/players/$PSEUDO* 2>/dev/null) ]] && echo "CE PSEUDO EST DEJA UN PLAYER. EXIT" && exit 1
# PSEUDO=${PSEUDO,,} #lowercase
PLAYER=${PSEUDO}${RANDOM:0:2}$(${MY_PATH}/diceware.sh 1 | xargs)${RANDOM:0:2}
[[ -d ~/.zen/game/players/$PLAYER ]] && echo "FATAL ERROR $PLAYER NAME COLLISION. TRY AGAIN." && exit 1

[[ ! $PSEUDO ]] && PSEUDO=$PLAYER
[[ $1 != "quiet" ]] && echo; echo "Génération de vos identités Astronaute (PLAYER):"; sleep 1; echo "$PLAYER"; sleep 2

# 6 DIGIT PASS CODE TO PROTECT QRSEC
PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

############################################################
######### TODO Ajouter d'autres clefs IPNS, GPG ?
# MOANS=$(ipfs key gen moa_$PLAYER)
# MOAKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "moa_$PLAYER")
# echo "Coffre personnel multimedia journalisé dans votre 'Astroport' (amis de niveau 3)"
# [[ $1 != "quiet" ]] && echo "Votre clef moa_$PLAYER <=> $MOANS ($MOAKEYFILE)"; sleep 2
############################################################

[[ $1 != "quiet" ]] && echo "Compte Gchange et portefeuille G1.
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
    ipfs key import $G1PUB -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/secret.player

    ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)

    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/G1SSB # Prepare astrXbian sub-datastructure
    mkdir -p ~/.zen/game/players/$PLAYER/ipfs_swarm

    qrencode -s 6 -o ~/.zen/game/players/$PLAYER/QR.png "$G1PUB"
    cp ~/.zen/game/players/$PLAYER/QR.png ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/QR.png
    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/G1SSB/_g1.pubkey # G1SSB NOTATION (astrXbian compatible)

    secFromDunikey=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep "sec" | cut -d ' ' -f2)
    echo "$secFromDunikey" > /tmp/${PSEUDO}.sec
    openssl enc -aes-256-cbc -salt -in /tmp/${PSEUDO}.sec -out "/tmp/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
    PASsec=$(cat /tmp/enc.${PSEUDO}.sec | base58) && rm -f /tmp/${PSEUDO}.sec
    qrencode -s 6 -o $HOME/.zen/game/players/$PLAYER/QRsec.png $PASsec

    [[ $1 != "quiet" ]] && echo "Votre Clef publique G1 est : $G1PUB"; sleep 1

    ### INITALISATION WIKI dans leurs répertoires de publication IPFS
    ############ TODO améliorer templates, sed, ajouter index.html, etc...
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
        echo "Nouveau Canal TW Astronaute"
        mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/

        cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        # base58 ssl PASS encoded sec from dunikey (contains public/private key TX tuxmain)
        sed -i "s~_QRSEC_~${$PASsec}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html


        IPNSK=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
        # La Clef IPNS porte comme nom G1PUB.
        sed -i "s~_MOAKEY_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~k2k4r8opmmyeuee0xufn6txkxlf3qva4le2jlbw6da7zynhw46egxwp2~${IPNSK}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html
        sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html


    #echo "## PUBLISHING ${PLAYER} /ipns/$PeerID/"
    IPUSH=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/moa/index.html | tail -n 1)
    echo $IPUSH > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/.moachain # Contains last IPFS backup PLAYER KEY
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/.moats
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
    echo "$IPFSNODEID" > ~/.zen/game/players/$PLAYER/.ipfsnodeid

    # astrXbian compatible IPFS sub structure =>$XZUID
    cp ~/.zen/game/players/$PLAYER/.player ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/_xbian.zuid
    cp ~/.zen/game/players/$PLAYER/.player ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/
    # PUBLIC Ŋ7 ZONE

    echo "$ASTRONAUTENS" > ~/.zen/game/players/$PLAYER/.playerns

    echo "$SALT" > ~/.zen/game/players/$PLAYER/secret.june
    echo "$PEPPER" >> ~/.zen/game/players/$PLAYER/secret.june

    rm -f ~/.zen/game/players/.current
    ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

    ## CREATE GCHANGE+ PROFILE
    ${MY_PATH}/Connect_PLAYER_To_Gchange.sh

qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.ASTRONAUTENS.png" "http://127.0.0.1:8080/ipns/$ASTRONAUTENS"

echo; echo "Création de vos QR codes IPNS, clefs de votre réseau IPFS."; sleep 1

[[ $1 != "quiet" ]] && echo; echo "*** Espace Astronaute Activé : ~/.zen/game/players/$PLAYER/"; sleep 1
[[ $1 != "quiet" ]] && echo; echo "*** Votre Journal : $PLAYER"; echo "http://127.0.0.1:8080/ipns/$ASTRONAUTENS"; sleep 2

# PASS CRYPTING KEY
[[ $1 != "quiet" ]] && echo; echo "Sécurisation de vos clefs par chiffrage SSL... "; sleep 1
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

## INIT FRIENDSHIP CAPTAIN/ASTRONAUTS (LATER THROUGH GCHANGE)
## ${MY_PATH}/FRIENDS.init.sh
## NO. GCHANGE+ IS THE MAIN INTERFACE, astrXbian manage
[[ $1 != "quiet" ]] && echo "Bienvenue 'Astronaute' $PSEUDO ($PLAYER)"
[[ $1 != "quiet" ]] && echo "SRetenez votre PASS : $PASS"; sleep 2

echo $PSEUDO > ~/.zen/tmp/PSEUDO ## Return data to start.sh
echo "cool $(${MY_PATH}/face.sh cool)"

${MY_PATH}/VISA.print.sh

exit 0
