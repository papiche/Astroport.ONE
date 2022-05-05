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
@@@@@@@@@@@@@@@@@@

'

## VERIFY SOFTWARE DEPENDENCIES
[[ ! $(which ipfs) ]] && echo "EXIT. Vous devez avoir installé ipfs CLI sur votre ordinateur" && echo "https://dist.ipfs.io/#go-ipfs" && exit 1
YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
[[ ! $YOU ]] && echo "Lancez 'ipfs daemon' SVP" && exit 1

## CONNECT USER
   PS3='Choisissez votre combinaison Astronaute ou ajoutez la votre. Identité ? '
    players=("NOUVEAU VISA" $(ls ~/.zen/game/players))
    select fav in "${players[@]}"; do
        case $fav in
        "NOUVEAU VISA")
            ${MY_PATH}/tools/VISA.new.sh
            fav=$(cat ~/.zen/tmp/PSEUDO) && rm ~/.zen/tmp/PSEUDO
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

cat ~/.zen/game/players/.current/.pass 2>/dev/null # DEVEL
echo "Saisissez votre PASS "
read PASS

## DECODE CURRENT PLAYER CRYPTO
echo "_ssl_ DECODAGE _ssl_"
openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/.current/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $PASS 2>/dev/null
[ $? != 0 ] && echo "ERROR. MAUVAIS PASS. EXIT" && rm $HOME/.zen/tmp/${PLAYER}.dunikey && exit 1
echo "____________________";
echo
PS3="$PLAYER choisissez une action à mener : "
choices=("WEBCAM" "JOURNAUX" "IMPRIMER VISA" "EXPORTER VISA" "SUPPRIMER VISA" "QUITTER")
select fav in  "${choices[@]}"; do
    case $fav in
    "IMPRIMER VISA")
        echo "IMPRESSION"
        ${MY_PATH}/tools/VISA.print.sh
        ;;

    "EXPORTER VISA")
        echo "EXPORT. INSERT USB KEY"
        ls ~/.zen/game/players/.current
        echo  "Enter to continue. Ctrl+C to stop"
        read
        echo "TODO... ${MY_PATH}/tools/SAVE.astronaut.sh"
        break
        ;;

    "SUPPRIMER VISA")
        echo "SUPPRESSION"
        echo  "Enter to continue. Ctrl+C to stop"
        read
        ipfs key rm $PLAYER; ipfs key rm qo-op_$PLAYER; ipfs key rm moa_$PLAYER;
        rm -Rf ~/.zen/game/players/$PLAYER
        break
        ;;

    "WEBCAM")
        echo "VIDEOBLOG"
        ${MY_PATH}/tools/vlc_webcam.sh
        ;;

    "JOURNAUX")
        ${MY_PATH}/tools/PLAYER.entrance.sh
        break
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
