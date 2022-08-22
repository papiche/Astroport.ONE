#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
TS=$(date -u +%s%N | cut -b1-13)
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

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
YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
[[ ! $YOU ]] && echo "Lancez 'ipfs daemon' SVP" && exit 1

## CREATE AND OR CONNECT USER
   PS3='Créez VISA ou connectez-vous à votre compte Astronaute ___ '
    players=("NOUVEAU VISA" $(ls ~/.zen/game/players 2>/dev/null))
    select fav in "${players[@]}"; do
        case $fav in
        "NOUVEAU VISA")
            ${MY_PATH}/tools/VISA.new.sh
            fav=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null) && rm ~/.zen/tmp/PSEUDO
            echo "Astronaute $fav bienvenue dans le jeu de terraformation forêt jardin MadeInZion"
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

# DEVEL
echo "Saisissez votre PASS -- DEBUG $(cat ~/.zen/game/players/.current/.pass 2>/dev/null) --"
read pass

## DECODE CURRENT PLAYER CRYPTO
echo "********* DECODAGE SecuredSocketLayer *********"
rm -f ~/.zen/tmp/${PLAYER}.dunikey 2>/dev/null
openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/.current/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $pass 2>&1>/dev/null
[[ ! $? == 0 ]] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

G1PUB=$(cat ~/.zen/tmp/${PLAYER}.dunikey | grep 'pub:' | cut -d ' ' -f 2)
[ ! ${G1PUB} ] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

echo "________LOGIN OK____________";
echo $G1PUB
echo
ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)

echo "Votre MOA : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"

PS3="$PLAYER choisissez : __ "
choices=("CREER UN VOEU" "IMPRIMER VOEU" "IMPRIMER VISA" "EXPORTER VISA" "SUPPRIMER VISA" "QUITTER")
select fav in  "${choices[@]}"; do
    case $fav in
    "IMPRIMER VISA")
        echo "IMPRESSION"
        ${MY_PATH}/tools/VISA.print.sh
        ;;

    "EXPORTER VISA")
        echo "EXPORT IDENTITE ASTRONAUTE"
        du -h ~/.zen/game/players/.current/
        echo  "MANUAL BACKUP ZIP ~/.zen/game/players/.$PLAYER/"

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
        ~/.zen/astrXbian/zen/jaklis/jaklis.py -k $HOME/.zen/tmp/${PLAYER}.dunikey -n https://data.gchange.fr erase
#        ~/.zen/astrXbian/zen/jaklis/jaklis.py -k $HOME/.zen/tmp/${PLAYER}.dunikey -n https://g1.data.e-is.pro erase

        rm -Rf ~/.zen/game/players/$PLAYER
        break
        ;;

    "CREER UN VOEU")
        echo "QRCode à coller sur votre REVE"
        ${MY_PATH}/G1VOEUX.sh
        # ${MY_PATH}/tools/vlc_webcam.sh
        #~/.zen/astrXbian/ajouter_video.sh
        ;;

    "IMPRIMER VOEU")
        PS3='Choisissez un de vos voeux ___ '
        voeux=($(ls ~/.zen/game/players/$PLAYER/voeux 2>/dev/null))
        select voeu in "${voeux[@]}"; do
            case $voeu in
            *) echo "IMPRESSION $voeu"
                myIP=$(hostname -I | awk '{print $1}' | head -n 1)
                VOEUXNS=$($MY_PATH/tools/g1_to_ipfs.py $voeu)
                qrencode -s 12 -o "$HOME/.zen/game/world/$voeu/QR.WISHLINK.png" "http://$myIP:8080/ipns/$VOEUXNS"
                convert $HOME/.zen/game/world/$voeu/QR.WISHLINK.png -resize 600 /tmp/QRWISHLINK.png
                TITLE=$(cat ~/.zen/game/world/$voeu/.pepper)
                convert -gravity northwest -pointsize 35 -fill black -draw "text 250,5 \"$TITLE\"" /tmp/QRWISHLINK.png /tmp/g1voeu.png
                echo " QR code $TITLE  : http://$myIP:8080/ipns/$VOEUXNS"

                LP=$(ls /dev/usb/lp* | head -n1)
                [[ ! $LP ]] && echo "NO PRINTER FOUND - Brother QL700 validated" && continue

                echo "IMPRESSION LIEN TW VOEU"
                brother_ql_create --model QL-700 --label-size 62 /tmp/g1voeu.png > /tmp/toprint.bin 2>/dev/null
                sudo brother_ql_print /tmp/toprint.bin $LP

                ;;
            esac
        done
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
