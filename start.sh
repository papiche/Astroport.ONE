#!/bin/bash -x
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


ASTROPORT is a peer to peer friends of friends real life game based on IPFS.
Join the OASIS so we fix the world together.

@@@@@@@@@@@@@@
ACTUAL PLAYERS
@@@@@@@@@@@@@@
'

## VERIFY SOFTWARE DEPENDENCIES
[[ ! $(which ipfs) ]] && echo "EXIT. Vous devez avoir installé ipfs CLI sur votre ordinateur" && echo "https://dist.ipfs.io/#go-ipfs" && exit 1

mkdir -p ~/.zen/tmp
mkdir -p ~/.zen/game/players


## VERIFY MadeInZion VISA OWNERSHIP
# AONE=$(zenity --entry --width 300 --title="Astroport ONE" --text="Connectez vous Astroport One?" --entry-text="OUI" NON)
PS3='Choisissez ou créez votre identité : '
players=($(ls ~/.zen/game/players) "NOUVEAU VISA")
select fav in "${players[@]}"; do
    case $fav in
    "NOUVEAU VISA")
        fav=$(${MY_PATH}/tools/VISA.new.sh quiet | tail -n 1)
        break
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
echo "SVP entrez votre PASS $fav"
rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current
cat ~/.zen/game/players/.current/.pass
read PASS

## DECODE CURRENT PLAYER CRYPTO
openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/.current/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $PASS 2>/dev/null
[ $? != 0 ] && echo "ERROR. MAUVAIS PASS. EXIT" && rm $HOME/.zen/tmp/${PLAYER}.dunikey && exit 1

PS3="$PLAYER choisissez une action à mener : "
choices=("AJOUTER VIDEOBLOG" "IMPRIMER VISA" "EXPORTER VISA" "SUPPRIMER VISA" "QUITTER")
select fav in  "${choices[@]}"; do
    case $fav in
    "IMPRIMER VISA")
        echo "IMPRESSION"
        ${MY_PATH}/tools/VISA.print.sh
        ;;
    "EXPORTER VISA")
        echo "EXPORT"
        break
        ;;
    "SUPPRIMER VISA")
        echo "SUPPRESSION"
        echo  "Enter to continue. Ctrl+C to stop"
        read
        ipfs key rm $PLAYER
        rm -Rf ~/.zen/game/players/$PLAYER
        break
        ;;
    "AJOUTER VIDEOBLOG")
        echo "VIDEOBLOG"
        ${MY_PATH}/tools/vlc_webcam.sh
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
