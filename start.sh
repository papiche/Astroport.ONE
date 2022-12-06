#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"

ME="${0##*/}"
TS=$(date -u +%s%N | cut -b1-13)
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "(RE)STARTING 12345.sh"
###################################################
killall 12345.sh; killall "_12345.sh"; killall nc
mkdir -p ~/.zen/tmp
~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &

echo "HTTP API :  http://$myIP:1234"
echo "MONITORING : tail -f ~/.zen/tmp/12345.log"
###################################################

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
YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
[[ ! $YOU ]] && echo "Lancez 'ipfs daemon' SVP sudo systemctl start ipfs" && exit 1
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

echo 'PRESS ENTER... '; read

## CREATE AND OR CONNECT USER
    PS3='Créez votre VISA PLAYER ou connectez-vous avec un compte Astronaute ___ '
    players=("NOUVEAU VISA" "IMPORT GCHANGE" $(ls ~/.zen/game/players 2>/dev/null))
    ## MULTIPLAYER

    select fav in "${players[@]}"; do
        case $fav in
        "NOUVEAU VISA")
            ${MY_PATH}/tools/VISA.new.sh
            fav=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null) && rm ~/.zen/tmp/PSEUDO
            echo "Astronaute $fav bienvenue dans le jeu de terraformation forêt jardin MadeInZion"
            exit
            ;;
        "IMPORT GCHANGE")
            echo "'Identifiant Gchange'"
            read SALT
            echo "'Mot de passe Gchange'"
            read PEPPER
            echo "'Adresse Email'"
            read EMAIL
            ${MY_PATH}/tools/VISA.new.sh "$SALT" "$PEPPER" "$EMAIL"
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


rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

pass=$(cat ~/.zen/game/players/.current/.pass 2>/dev/null)

########################################## DEVEL
echo "Saisissez votre PASS -- UPGRADE CRYPTO FREELY -- $pass" && read pass

## DECODE CURRENT PLAYER CRYPTO
echo "********* DECODAGE SecuredSocketLayer *********"
rm -f ~/.zen/tmp/${PLAYER}.dunikey 2>/dev/null
openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/.current/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $pass 2>&1>/dev/null
[[ ! $? == 0 ]] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

echo "________LOGIN OK____________";
echo
echo "DECHIFFRAGE CLEFS ASTRONAUTE"
echo "Votre Pass Astroport.ONE  : $(cat ~/.zen/game/players/.current/.pass 2>/dev/null)"
G1PUB=$(cat ~/.zen/tmp/${PLAYER}.dunikey | grep 'pub:' | cut -d ' ' -f 2)
[ ! ${G1PUB} ] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

echo "Clef Publque Astronaute : $G1PUB"
echo "ENTREE ACCORDEE"
echo
ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)

echo "$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) TW/Moa"
echo "http://$myIP:8080/ipns/$ASTRONAUTENS"
echo "Activation Réseau P2P Astroport !"

echo
PS3="$PLAYER choisissez : __ "
choices=("AJOUTER VLOG" "CREER UN VOEU" "IMPRIMER QRVOEU" "IMPRIMER VISA" "EXPORTER VISA" "SUPPRIMER VISA" "QUITTER")
select fav in  "${choices[@]}"; do
    case $fav in
    "IMPRIMER VISA")
        echo "IMPRESSION"
        ${MY_PATH}/tools/VISA.print.sh
        ;;

    "EXPORTER VISA")
        echo "EXPORT IDENTITE ASTRONAUTE"
        du -h ~/.zen/game/players/.current/
        echo  "MANUAL BACKUP ZIP ~/.zen/game/players/$PLAYER/"
        ## EXPORT TW + VOEUX IPNS KEYS


        break
        ;;

    "SUPPRIMER VISA")
        echo "ATTENTION SUPPRESSION DEFINITIVE !!"
        echo  "Enter to continue. Ctrl+C to stop"
        read
        ipfs key rm $PLAYER; ipfs key rm $G1PUB;
        for voeu in $(ls ~/.zen/game/players/$PLAYER/voeux/); do
            ipfs key rm $voeu
            [[ $voeu != "" ]] && rm -Rf ~/.zen/game/world/$voeu
        done
        echo "rm -Rf ~/.zen/game/players/$PLAYER"
        $MY_PATH/tools/jaklis/jaklis.py -k $HOME/.zen/tmp/${PLAYER}.dunikey -n https://data.gchange.fr erase
#        ~/.zen/astrXbian/zen/jaklis/jaklis.py -k $HOME/.zen/tmp/${PLAYER}.dunikey -n https://g1.data.e-is.pro erase

        rm -Rf ~/.zen/game/players/$PLAYER
        break
        ;;

    "AJOUTER VLOG")
        echo "Lancement Webcam..."
        ${MY_PATH}/tools/vlc_webcam.sh "$PLAYER"
        ;;

    "CREER UN VOEU")
        echo "QRCode à coller sur les lieux ou objets portant une Gvaleur"
        cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html
        ${MY_PATH}/ASTROBOT/G1Voeu.sh "" "$PLAYER" "~/.zen/tmp/$PLAYER.html"
        DIFF=$(diff ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html)
        if [[ $DIFF ]]; then
            MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
            cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

            TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
            ipfs name publish --allow-offline -t 72h --key=$PLAYER /ipfs/$TW

            echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
            echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
        fi
    echo "================================================"
    echo "$PLAYER : http://$myIP:8080/ipns/$ASTRONAUTENS"
    echo "================================================"
        ;;

    "IMPRIMER QRVOEU")
        ${MY_PATH}/tools/VOEUX.print.sh
        ;;

    "QUITTER")
        echo "CIAO" && exit 0
        ;;

    "")
        echo "Mauvais choix."
        ;;

    esac
done

exit 0
