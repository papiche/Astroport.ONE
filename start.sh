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
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

## CREATE AND OR CONNECT USER
   PS3='Créez VISA ou connectez-vous à votre compte Astronaute ___ '
    players=("NOUVEAU VISA" "IMPORT GVISA" $(ls ~/.zen/game/players 2>/dev/null))
    [[ ${#players[@]} -lt 3 && ! "$1" ]] && PLAYERONE="${players[1]}" && echo $PLAYERONE

    ## MULTIPLAYER
    if [[ ! $PLAYERONE ]]; then
    select fav in "${players[@]}"; do
        case $fav in
        "NOUVEAU VISA")
            ${MY_PATH}/tools/VISA.new.sh
            fav=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null) && rm ~/.zen/tmp/PSEUDO
            echo "Astronaute $fav bienvenue dans le jeu de terraformation forêt jardin MadeInZion"
            exit
            ;;
        "IMPORT GVISA")
            echo "Saisissez votre 'identifiant Gchange'"
            read SALT
            echo "Saisissez votre 'mot de passe Gchange'"
            read PEPPER
            ${MY_PATH}/tools/VISA.new.sh "$SALT" "$PEPPER"
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

    else
    PLAYER=$PLAYERONE

    fi

rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

 [[ $PLAYERONE ]] && pass=$(cat ~/.zen/game/players/.current/.pass 2>/dev/null)

########################################## DEVEL
 [[ ! $pass ]] && echo "Saisissez votre PASS -- UPGRADE CRYPTO FREELY --" && read pass

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

## IPFSNODEID SIGNALING ##
[[ ! $(grep -w "$ASTRONAUTENS" ~/.zen/game/astronautes.txt ) ]] && echo "$PSEUDO:$PLAYER:$ASTRONAUTENS" >> ~/.zen/game/astronautes.txt
ROUTING=$(ipfs add -q ~/.zen/game/astronautes.txt)
echo "PUBLISHING IPFSNODEID / Astronaute List"
ipfs name publish /ipfs/$ROUTING
######################


echo "$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) TW/Moa"
echo "http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
echo "Echangez vos 'Dessin de Moa' et reliez vous au réseau des Astroport !"

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
        ${MY_PATH}/tools/vlc_webcam.sh
        ;;

    "CREER UN VOEU")
        echo "QRCode à coller sur les lieux ou objets portant une Gvaleur"
        ${MY_PATH}/G1VOEUX.sh
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
