#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Gestion de l'entrée du PLAYER dans la Station
# Le premier devient Capitaine...
# Les suivants selon le niveau de confiance (LOVE) des meilleurs Astronautes?!
#
# 'player' 'moa'
# ~/.zen/ipfs/ -> ~/.zen/game/players/$PLAYER/ipfs/
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
if [[  ! -d $IPFS_SYNC_DIR || $IPFS_SYNC_DIR == "" || $IPFS_SYNC_DIR == "$HOME/astroport" ]]; then
    echo "#-----------------------------------"
    echo $IPFS_SYNC_DIR
    echo "Aucun Capitaine à bord."; sleep 1
    echo "$PLAYER vous devenez la clef maitre de la Station et de sa balise astrXbian..."; sleep 1

echo
echo "** Stop or Kill ipfs daemon **"
    # 1st Captain. Changing IPFS station key.
    sudo service ipfs stop
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ $YOU ]] && sudo killall -5 ipfs
    #-----------------------------------

echo
echo "=== Replacing ~/.ipfs/config ==="; sleep 2

    [[ -f ~/.ipfs/config.astrXbian ]] && mv ~/.ipfs/config.astrXbian ~/.ipfs/config.astrXbian.${MOATS} && echo "BACKUP config.astrXbian.${MOATS}"; sleep 2
    mv ~/.ipfs/config ~/.ipfs/config.astrXbian && echo "BACKUP current ipfs config"; sleep 2
    cp ~/.zen/game/players/$PLAYER/ipfs.config ~/.ipfs/config && echo "Installing $PLAYER 'G1' ipfs config"
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID); echo $IPFSNODEID

echo
echo "==== qo-op & moa Captain/Station keystore ===="; sleep 2

    mv ~/.ipfs/keystore ~/.ipfs/keystore.astrXbian.${LAYER}.${MOATS}
    ln -s ~/.zen/game/players/$PLAYER/keystore ~/.ipfs/keystore

    # Get already created keys
    cp ~/.ipfs/keystore.astrXbian.${LAYER}.${MOATS}/* ~/.ipfs/keystore/ 2>/dev/null

    # 'qo-op' Key there?
    [[ ! -f ~/.ipfs/keystore/key_ofxs233q ]] && qoopns=$(ipfs key gen qo-op)
    ipfs key list -l | grep -w qo-op
    qoopns=$(ipfs key list -l | grep -w qo-op | cut -d ' ' - f 1)

    echo "----> Station 'qo-op' channel : /ipns/$qoopns"; sleep 1

    # 'moa' Key there?
    [[ ! -f ~/.ipfs/keystore/key_nvxwc ]] && moans=$(ipfs key gen moa)
    ipfs key list -l | grep -w moa
    moans=$(ipfs key list -l | grep -w moa | cut -d ' ' - f 1)

    echo "----> Station 'moa' channel : /ipns/$moans"; sleep 1

echo
echo "===== Connect captain IPFS datadir to Station (balise junction) ====="; sleep 2

    [[ -d ~/.zen/ipfs.astrXbian ]] && mv ~/.zen/ipfs.astrXbian ~/.zen/ipfs.astrXbian.${MOATS} && echo "BACKUP ~/.zen/ipfs.astrXbian.${MOATS}"; sleep 2
    mv ~/.zen/ipfs ~/.zen/ipfs.astrXbian && echo "BACKUP current ~/.zen/ipfs"; sleep 2
    ln -s ~/.zen/game/players/$PLAYER/ipfs ~/.zen/ipfs && echo "$PLAYER become 'self' and now control 'moa' & 'qo-op' channels"
echo
echo "** Restart IPFS DAEMON **"
    sudo service ipfs start
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ ! $YOU ]] && ipfs daemon --writable &
    #-----------------------------------
    echo "#-----------------------------------"

    echo "##################################################### OK"
    echo "Nouvelle Identité 'self' Balise IPFS"; sleep 1
    ipfs id -f='<id>\n'
    echo "##################################################### OK"
    echo "IPFS_SYNC_DIR=$PLAYER" > ~/.zen/ipfs.sync ## PLAYER IS ASTROPORT CAPTAIN NOW

else
##############################

    # Adapting ipfs daemon keystore with player keys
    mv ~/.ipfs/keystore ~/.ipfs/keystore.astrXbian.${LAYER}.${MOATS}
    ln -s ~/.zen/game/players/$PLAYER/keystore ~/.ipfs/keystore

    if [[ $IPFS_SYNC_DIR == "$PLAYER" ]]; then
        ## THE CAPTAIN IS LOGGED IN
        echo "Bienvenue CAPITAINE !"; sleep 2
        echo "Ouverture des journaux 'moa' et 'qo-op' de votre Station Astroport";

        # OPEN 'moa' channel
        moans=$(ipfs key list -l | grep -w moa | cut -d ' ' -f 1)
        xdg-open "http://127.0.0.1:8080/ipns/$moans"

        # OPEN 'qo-op' channel
        qoopns=$(ipfs key list -l | grep -w qo-op | cut -d ' ' -f 1)
        xdg-open "http://127.0.0.1:8080/ipns/$qoopns"

    else
        # ASTRONAUT PLAYER IS LOGGED IN
        echo "Joueur $PLAYER, $IPFS_SYNC_DIR est Capitaine de cet Astroport"; sleep 1
        echo "$PSEUDO, Décrivez vos 'Talents', soumettez vos 'Rêves' pour améliorer cet Astroport dans votre journal 'moa'."; sleep 2
        echo "Publiez dans votre journal public 'qo-op'"; sleep 2

    fi
fi

# OPEN PLAYER HOME
player=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
xdg-open "http://127.0.0.1:8080/ipns/$player"


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
