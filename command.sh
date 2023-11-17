#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

TS=$(date -u +%s%N | cut -b1-13)
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
#~ mkdir -p ~/.zen/tmp/${MOATS}

echo '
    _    ____ _____ ____   ___  ____   ___  ____ _____    ___  _   _ _____
   / \  / ___|_   _|  _ \ / _ \|  _ \ / _ \|  _ \_   _|  / _ \| \ | | ____|
  / _ \ \___ \ | | | |_) | | | | |_) | | | | |_) || |   | | | |  \| |  _|
 / ___ \ ___) || | |  _ <| |_| |  __/| |_| |  _ < | |   | |_| | |\  | |___
/_/   \_\____/ |_| |_| \_\\___/|_|    \___/|_| \_\|_|    \___/|_| \_|_____|

Ambassade numérique pair à pair sur IPFS.

@@@@@@@@@@@@@@@@@@
ASTROPORT
VISA : MadeInZion
@@@@@@@@@@@@@@@@@@'
echo

## VERIFY SOFTWARE DEPENDENCIES
[[ ! $(which ipfs) ]] && echo "EXIT. Vous devez avoir installé ipfs CLI sur votre ordinateur" && echo "https://dist.ipfs.io/#go-ipfs" && exit 1
YOU=$(myIpfsApi);
[[ ! $YOU ]] && echo "Lancez 'ipfs daemon' SVP sudo systemctl start ipfs" && exit 1

echo 'PRESS ENTER... '; read

## CREATE AND OR CONNECT USER
    PS3='Astronaute connectez votre PLAYER  ___ '
    players=( "ZENCARD DEMO" "CREATE PLAYER" "IMPORT PLAYER" $(ls ~/.zen/game/players  | grep "@" 2>/dev/null))
    ## MULTIPLAYER

    select fav in "${players[@]}"; do
        case $fav in
        "ZENCARD DEMO")
            ## DIRECT VISA.print.sh
            echo "'Email ?'"
            read EMAIL
            [[ ${EMAIL} == "" ]] && EMAIL=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
            echo "'Secret 1 ?'"
            read SALT
            [[ ${SALT} == "" ]] && SALT=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
            echo "'Secret 2?'"
            read PEPPER
            [[ ${PEPPER} == "" ]] && PEPPER=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
            echo "'PIN ?'"
            read PASS
            echo "${MY_PATH}/tools/VISA.print.sh" "${EMAIL}"  "'"$SALT"'" "'"$PEPPER"'" "'"$PASS"'"
            ${MY_PATH}/tools/VISA.print.sh "${EMAIL}"  "$SALT" "$PEPPER" "$PASS" ##

             [[ ${EMAIL} != "" && ${EMAIL} != $(cat ~/.zen/game/players/.current/.player 2>/dev/null) ]] && rm -Rf ~/.zen/game/players/${EMAIL}/

            exit
            ;;
        "CREATE PLAYER")
            ${MY_PATH}/RUNTIME/VISA.new.sh
            fav=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null) && rm ~/.zen/tmp/PSEUDO
            echo "Astronaute $fav bienvenue dans le jeu de terraformation forêt jardin MadeInZion"
            exit
            ;;
        "IMPORT PLAYER")
            echo "'Secret 1'"
            read SALT
            echo "'Secret 2'"
            read PEPPER
            echo "'Adresse Email'"
            read EMAIL
            ${MY_PATH}/RUNTIME/VISA.new.sh "$SALT" "$PEPPER" "$EMAIL"
            fav=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null) && rm ~/.zen/tmp/PSEUDO
            echo "Astronaute $fav heureux de vous acceuillir"
            exit
            ;;
        "")
            echo "Choix obligatoire. exit"
            exit
            ;;
        *) echo "Salut $fav"
            break
            ;;
        esac
    done
    PLAYER=$fav


pass=$(cat ~/.zen/game/players/$PLAYER/.pass 2>/dev/null)
########################################## DEVEL
echo "Saisissez votre PASS -- UPGRADE CRYPTO FREELY -- $pass" && read PASS

## DECODE CURRENT PLAYER CRYPTO
# echo "********* DECODAGE SecuredSocketLayer *********"
# rm -f ~/.zen/tmp/${PLAYER}.dunikey 2>/dev/null
# openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/${PLAYER}/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $pass 2>&1>/dev/null
[[ $PASS != $pass ]] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

echo "________LOGIN OK____________";
echo
echo "DECHIFFRAGE CLEFS ASTRONAUTE"
echo "Votre Pass Astroport.ONE  : $(cat ~/.zen/game/players/$PLAYER/.pass 2>/dev/null)"
export G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
[ ! ${G1PUB} ] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

echo "Clef Publique Astronaute : $G1PUB"
echo "ENTREE ACCORDEE"
echo
export ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)

echo "$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null) TW/Moa"
echo "$myIPFS/ipns/$ASTRONAUTENS"
echo "Activation Réseau P2P Astroport !"

[[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open "http://ipfs.localhost:8080/ipns/$ASTRONAUTENS"

echo
PS3="$PLAYER choisissez : __ "
choices=("MAKE UN VOEU" "PRINT QRVOEU" "PRINT VISA" "UNPLUG PLAYER" "QUIT")
select fav in  "${choices[@]}"; do
    case $fav in
    "PRINT VISA")
        echo "IMPRESSION"
        ${MY_PATH}/tools/VISA.print.sh "$PLAYER"
        ;;

    "UNPLUG PLAYER")
        echo "ATTENTION ${PLAYER} DECONNEXION DE VOTRE TW !!"
        echo  "Enter to continue. Ctrl+C to stop"
        read
        espeak "Droping TW in cyber space"
        ${MY_PATH}/tools/PLAYER.unplug.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}"

        break
        ;;

    #~ "AJOUTER VLOG")
        #~ echo "Lancement Webcam..."
        #~ ${MY_PATH}/tools/vlc_webcam.sh "$PLAYER"
        #~ ;;

    "MAKE UN VOEU")
        echo "QRCode à coller sur les lieux ou objets portant une Gvaleur"
        cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html
        ${MY_PATH}/RUNTIME/G1Voeu.sh "" "$PLAYER" "$HOME/.zen/tmp/$PLAYER.html"
        DIFF=$(diff ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html)
        if [[ $DIFF ]]; then
            cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

            TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
            ipfs name publish --key=$PLAYER /ipfs/$TW

            echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
            echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
        fi
    echo "================================================"
    echo "$PLAYER : $myIPFS/ipns/$ASTRONAUTENS"
    echo "================================================"
        ;;

    "PRINT QRVOEU")
        ${MY_PATH}/tools/VOEUX.print.sh $PLAYER
        ;;

    "QUIT")
        echo "CIAO" && exit 0
        ;;

    "")
        echo "Mauvais choix."
        ;;

    esac
done

exit 0
