#!/bin/bash
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
# Controle par Scanner de QRCode
# Scan G1PUB
# Scan QRSec + PASS
# Colecter ou générer les identifiants / mot de passe = "$SALT" "$PEPPER"
# Correspondance profil Gchange+ (CESIUM+) = $PLAYER
#
# Get last connected User
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )

echo "Bienvenue $PLAYER"
echo "Relancez start.sh pour changer votre identité"
echo "Pressez ENTRER"
read

sudo cat /dev/ttyACM0 | while read line; do
    lon=${#line}
    # /ipns/.... /ipfs
    inet=$(echo $line | cut -d "/" -f 2)
    hash=$(echo $line | cut -d "/" -f 3)
    echo "__SUB:tag_READ.sh: SCAN /dev/ttyACM0 ($lon) :: $line"

    if [[ $inet == 'ipns' ]]; then
        xdg-open "http://127.0.0.1:8080/ipns/$hash" &
    fi

    if [[ $lon != 43 && $lon != 44 ]]; then
        ## QRSEC SCAN ???
        echo "Veuillez saisir PASS pour décoder cet identité"
        read PASS
        echo "********* DECODAGE SecuredSocketLayer *********"
        rm -f ~/.zen/tmp/secret.dunikey 2>/dev/null
        openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/.current/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $pass 2>&1>/dev/null
        [ ! -f $HOME/.zen/tmp/${PLAYER}.dunikey ] && echo "ERROR. MAUVAIS PASS. SORTIE" && exit 1

        PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
        echo "ASTRONAUTE $PLAYER : Ŋ1 exploration"
        PLAYERNS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)
        echo "MOA : http://127.0.0.1:8080/ipns/$PLAYERNS"

        ## Lancer vlc_webcam
        ## Ajouter vlog au TW

        continue
    fi

    RESSOURCENS=$(ipfs key list -l | grep -w "$G1PUB" | cut -d ' ' -f 1)

    if [[ $RESSOURCENS ]]; then
        echo "SCAN G1REVE. CONFIRMER."
        echo "'Identifiant' ..."
        read SALT
        echo "'Code secret' ..."
        read PEPPER
        echo "MERCI"; sleep 2
    else
        echo "Scan G1Billet VIERGE"
        echo "Saisissez son TITRE (en majuscules sans accent)"
        read TITLE
    fi

    # REGENERATION CLEFS ET COMPARAISON
    $MY_PATH/tools/keygen -t duniter -o ~/.zen/tmp/secret.dunikey "$SALT" "$PEPPER"
    G1PUB=$(cat ~/.zen/tmp/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)

    # EXISTING RESSOURCE ?
    if [[ $RESSOURCENS ]]; then
        # YES
        echo "EXISTING RESSOURCE CURRENT STATUS $G1PUB"
        ls -al ~/.zen/game/world/$G1PUB

        ipfs ls /ipns/$RESSOURCENS

        continue

    fi


    # CREATE NEW RESSOURCE
    $MY_PATH/tools/keygen -t ipfs -o ~/.zen/tmp/astroscan.secret "$SALT" "$PEPPER"
    ipfs key import $G1PUB -f pem-pkcs8-cleartext ~/.zen/tmp/astroscan.secret

    if [[ ! -f ~/.zen/game/world/$G1PUB/index.html ]]; then
        echo "Nouveau Canal TW Astroport"
        mkdir -p ~/.zen/game/world/$G1PUB

        cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/world/$G1PUB/index.html
        sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/world/$G1PUB/index.html
        sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/world/$G1PUB/index.html
        sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/world/$G1PUB/index.html

        IPNSK=$(ipfs key list -l | grep -w "${G1PUB}" | cut -d ' ' -f 1)
        # La Clef IPNS porte comme nom G1PUB.
        sed -i "s~_MOAKEY_~${G1PUB}~g" ~/.zen/game/world/$G1PUB/index.html
        sed -i "s~k2k4r8opmmyeuee0xufn6txkxlf3qva4le2jlbw6da7zynhw46egxwp2~${IPNSK}~g" ~/.zen/game/world/$G1PUB/index.html
        sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/world/$G1PUB/index.html

        IPUSH=$(ipfs add -Hq ~/.zen/game/world/$G1PUB/index.html | tail -n 1)
        ipfs name publish --key=${G1PUB} /ipfs/$IPUSH 2>/dev/null

    else
        echo "Canal TW existant"
        # REFRESH IPNS
        ipfs get -o ~/.zen/game/world/$G1PUB /ipns/$IPNSK

        CHECK=(ls ~/.zen/game/world/$G1PUB/) && mv ~/.zen/game/world/$G1PUB/$CHECK ~/.zen/game/world/$G1PUB/index.html
    fi

    ## CREATE GCHANGE AD
    if [[ ! -f ~/.zen/game/world/.gchange.$G1PUB ]]
    then
        echo "CREATION ANNONCE CROWDFUNDING"
        echo $MY_PATH/tools/jaklis/jaklis.py -k ~/.zen/tmp/secret.dunikey -n "https://data.gchange.fr" setoffer -t "${TITLE} #ASTROMIZ" -d "http://127.0.0.1:8080/ipns/$RESSOURCENS - Gratitude Astronaute $PLAYER" -p $HOME/.zen/Astroport.ONE/images/moa_net.png
        # echo $GOFFER > ~/.zen/game/world/.gchange.$G1PUB
    fi

    ## OPEN
    echo "OUVERTURE TW"
    xdg-open "http://127.0.0.1:8080/ipns/$IPNSK" &


done

# Charger le TW # sudo npm install -g tiddlywiki
# TODO USE TW COMMANDS
# https://tiddlywiki.com/static/ListenCommand.html

# CLEF PLAYER CONNUE
# tiddlywiki $PLAYER --verbose --load ~/.zen/Astroport.ONE/templates/moawiki.html --listen port=8282
