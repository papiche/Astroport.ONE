#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Gestion de l'identité IPFS de la Station parmis celle des PLAYER
# La première clef n'a aucun chalenge pour le faire.
# Les suivantes peuvent être soumises au niveau de confiance (LOVE) des meilleurs Astronautes.
#
# ~/.zen/game/players/$PLAYER/ipfs/
# ~/.zen/ipfs/.$IPFSNODEID
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

# Check who is currently current connected PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null)

# Check if Astroport Station already has a "captain"
source ~/.zen/ipfs.sync

### AN ASTROPORT NEEDS A CAPTAIN
##############################
if [[ $IPFS_SYNC_DIR == "" || $IPFS_SYNC_DIR == "$HOME/astroport" ]]; then

    echo "Aucun Capitaine à bord."; sleep 1
    echo "$PLAYER vous devenez la clef maitre de la Station et de sa balise astrXbian..."; sleep 1

    # 1st Captain. Changing IPFS station key.
    sudo service ipfs stop
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ $YOU ]] && sudo killall -5 ipfs
    #-----------------------------------

echo "Replace ~/.ipfs/config"
read
    [[ -f ~/.ipfs/config.astrXbian ]] && mv ~/.ipfs/config.astrXbian ~/.ipfs/config.astrXbian.${MOATS} && echo "BACKUP config.astrXbian.${MOATS}"
    mv ~/.ipfs/config ~/.ipfs/config.astrXbian && echo "BACKUP current ipfs config"
    cp ~/.zen/game/players/$PLAYER/ipfs.config ~/.ipfs/config && echo "Install $PLAYER G1 ipfs config"
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

echo "Link keystore to captain"
read
    mv ~/.ipfs/keystore ~/.ipfs/keystore.astrXbian
    ln -s ~/.zen/game/players/$PLAYER/keystore ~/.ipfs/keystore

echo "Keep 'qo-op' existing key, or create first one"
read
    cp ~/.ipfs/keystore.astrXbian/key_ofxs233q ~/.ipfs/keystore/ 2>/dev/null
    publishkey=$(ipfs key gen qo-op 2>/dev/null)
    publishkey=$(ipfs key list -l | grep -w qo-op | cut -d ' ' -f 1)

    echo "Station 'qo-op' channel : /ipns/$publishkey"; sleep 1

echo "Connect captain ipfs data ?!"
read
    [[ -d ~/.zen/ipfs.astrXbian ]] && mv ~/.zen/ipfs.astrXbian ~/.zen/ipfs.astrXbian.${MOATS} && echo "BACKUP ~/.zen/ipfs.astrXbian.${MOATS}"
    mv ~/.zen/ipfs ~/.zen/ipfs.astrXbian && echo "BACKUP current ~/.zen/ipfs"
    ln -s ~/.zen/game/players/$PLAYER/ipfs ~/.zen/ipfs && echo "$PLAYER control 'self' and 'qo-op' channels"

echo "## Start IPFS DAEMON"
    sudo service ipfs start
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ ! $YOU ]] && ipfs daemon --writable &
    #-----------------------------------

    echo "Nouvelle Identité balise IPFS"; sleep 1
    ipfs id
    echo "##################################################### OK"
    echo "IPFS_SYNC_DIR=$PLAYER" > ~/.zen/ipfs.sync ## PLAYER IS ASTROPORT CAPTAIN NOW

else
    if [[ $IPFS_SYNC_DIR == "$PLAYER" ]]; then
        ## THE CAPTAIN IS LOGGED IN
        echo "Bienvenue capitaine !"; sleep 2
        echo "Ouverture des journaux...";

    else
        # A PLAYER IS LOGGED IN
        echo "Joueur $PLAYER, $IPFS_SYNC_DIR est le capitaine de cet Astroport"; sleep 1
        echo "$PSEUDO, documentez vos 'rêves' et 'plans' dans votre journal 'moa' et donnez 3 étoiles au capitaine."; sleep 1

    fi
fi

${MY_PATH}/JOURNAL.visit.sh # OPEN TIDDLYWIKIS


[[ $1 != "quiet" ]] && echo "=============================================
Appuyez sur ENTRER pour vous déconnecter.
Saisissez 'S' avant pour copier vos données sur clef USB ?
=======================================================
"
read EJECT
[[ $EJECT == "" ]] && echo "Merci. Au revoir"; rm -f ~/.zen/game/players/.current && exit 0

echo "## TODO BACKUP SUR CLEF USB"
# ${MY_PATH}/tools/SAVE.astronaut.sh # tar.gzip PLAYER DATA TO USB KEY TODO

exit 0
