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
if [[ ! -d ~/.zen/game/players/$CAPTAIN || $CAPTAIN == "" || $CAPTAIN == "$HOME/astroport" ]]; then
    echo "#-----------------------------------"
    echo $CAPTAIN
    echo "Aucun Capitaine à bord."; sleep 1
    echo "$PLAYER vous devenez la clef maitre de la Station et de sa balise astrXbian..."; sleep 2
    echo "Et de ses canaux, public 'qo-op' et administratif 'moa'"; sleep 2

echo
echo "** Stop or Kill ipfs daemon **"
    # 1st Captain. Changing IPFS station key.
    sudo service ipfs stop
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ $YOU ]] && sudo killall -5 ipfs
    #-----------------------------------

echo
echo "=== Replacing ~/.ipfs/config ==="; sleep 2

    [[ ! -f ~/.ipfs/config.astrXbian ]] && mv ~/.ipfs/config ~/.ipfs/config.astrXbian && echo "BACKUP OLD ipfs config" || rm ~/.ipfs/config
    ln -s ~/.zen/game/players/$PLAYER/ipfs.config ~/.ipfs/config && echo "Installing $PLAYER 'G1' ipfs config";    sleep 2
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID); echo $IPFSNODEID

echo
echo "==== qo-op & moa Captain/Station keystore ===="; sleep 2

    mv ~/.ipfs/keystore ~/.ipfs/keystore.astrXbian.${PLAYER}.${MOATS}
    ln -s ~/.zen/game/players/$PLAYER/keystore ~/.ipfs/keystore

    # Keep already created keys !!?
    cp ~/.ipfs/keystore.astrXbian.${PLAYER}.${MOATS}/* ~/.ipfs/keystore/ 2>/dev/null

    # 'qo-op' Key there? Or Captain already join a flag
    # Astroport public channel 'state of mind' propagation...
    [[ ! -f ~/.ipfs/keystore/key_ofxs233q ]] &&\
        qoopns=$(ipfs key gen qo-op) && \
        IPUSH=$(ipfs add -Hq ${MY_PATH}/../templates/qoopwiki.html | tail -n 1) && \
        ipfs name publish --key=qo-op /ipfs/$IPUSH 2>/dev/null
        # qo-op channel is created from template
    ipfs key list -l | grep -w qo-op
    qoopns=$(ipfs key list -l | grep -w qo-op | cut -d ' ' -f 1)

    echo "----> Station 'qo-op' channel : http://127.0.0.1:8080/ipns/$qoopns"; sleep 1


    # 'moa' Key there? It is the 'Administrative' 3 star.level confidence information layer.
    [[ ! -f ~/.ipfs/keystore/key_nvxwc ]] &&\
        moans=$(ipfs key gen moa) && \
        IPUSH=$(ipfs add -Hq ${MY_PATH}/../templates/moawiki.html | tail -n 1) && \
        ipfs name publish --key=moa /ipfs/$IPUSH 2>/dev/null
        # moa channel is created from template
    ipfs key list -l | grep -w moa
    moans=$(ipfs key list -l | grep -w moa | cut -d ' ' -f 1)

    echo "----> Station 'moa' channel : http://127.0.0.1:8080/ipns/$moans"; sleep 1

echo
echo "===== Connect captain IPFS datadir to Station (balise junction) ====="; sleep 2

    [[ -d ~/.zen/ipfs.astrXbian ]] && mv ~/.zen/ipfs.astrXbian ~/.zen/ipfs.astrXbian.${MOATS} && echo "BACKUP ~/.zen/ipfs.astrXbian.${MOATS}"; sleep 2
    mv ~/.zen/ipfs ~/.zen/ipfs.astrXbian && echo "BACKUP current ~/.zen/ipfs"; sleep 2

    # Linking ~/.zen/ipfs & ~/.zen/secret.dunikey
    echo "CAPITAINE VOUS ETES EN POSSESSION DES CANAUX PRINCIPAUX DE LA STATION 'qo-op', 'moa', etc ..."
    ln -s ~/.zen/game/players/$PLAYER/ipfs ~/.zen/ipfs && echo "$PLAYER become 'self' and can manage 'moa' & 'qo-op' channels" && sleep 1
    ln -s ~/.zen/game/players/$PLAYER/secret.dunikey ~/.zen/secret.dunikey && echo "Linking your ~/.zen/secret.dunikey with Station" && sleep 1

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
    echo "CAPTAIN=$PLAYER" > ~/.zen/ipfs.sync ## PLAYER IS ASTROPORT CAPTAIN NOW
    ## CAPTAIN is define  in ~/.zen/ipfs.sync

else
##############################

echo
echo "=== Replacing ~/.ipfs/config ==="; sleep 2

    [[ ! -f ~/.ipfs/config.astrXbian ]] && mv ~/.ipfs/config ~/.ipfs/config.astrXbian && echo "BACKUP OLD ipfs config" || rm ~/.ipfs/config
    ln -s ~/.zen/game/players/$PLAYER/ipfs.config ~/.ipfs/config && echo "Installing $PLAYER 'G1' ipfs config";    sleep 2
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID); echo $IPFSNODEID

echo
echo "==== Astronaute keystore activated ===="; sleep 2

    [[ ! -d ~/.ipfs/keystore.astrXbian ]] && mv ~/.ipfs/keystore ~/.ipfs/keystore.astrXbian || rm ~/.ipfs/keystore
    ln -s ~/.zen/game/players/$PLAYER/keystore ~/.ipfs/keystore

    if [[ $CAPTAIN == "$PLAYER" ]]; then
        ## THE CAPTAIN IS LOGGED IN
        echo "Bienvenue CAPITAINE !"; sleep 2
        echo "Ouverture des journaux 'moa' et 'qo-op' de votre Station Astroport";
     else
        # ASTRONAUT PLAYER IS LOGGED IN
        echo "Joueur $PLAYER, $CAPTAIN est Capitaine de cet Astroport"; sleep 1
        echo "$PSEUDO, Décrivez vos 'Talents', soumettez vos 'Rêves' pour améliorer cet Astroport dans votre journal 'moa'."; sleep 2
        echo "Publiez dans votre journal public 'qo-op'"; sleep 2

    fi
        # OPEN 'moa' channel
        moans=$(ipfs key list -l | grep -w moa | cut -d ' ' -f 1)
        xdg-open "http://127.0.0.1:8080/ipns/$moans"

        # OPEN 'qo-op' channel
        qoopns=$(ipfs key list -l | grep -w qo-op | cut -d ' ' -f 1)
        xdg-open "http://127.0.0.1:8080/ipns/$qoopns"


fi

# OPEN PLAYER HOME (contains 'moa_player' + 'qo-op_player' vertical iframes
player=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
xdg-open "http://127.0.0.1:8080/ipns/$player"


[[ $1 != "quiet" ]] && echo "=============================================
Appuyez sur ENTRER pour vous déconnecter.
Saisissez 'S' avant pour copier vos données sur clef USB ?
=======================================================
"
read EJECT
[[ $EJECT == "" ]] && echo "Merci. Au revoir"; rm -f ~/.zen/game/players/.current && exit 0

echo "## TODO ZIP DANS UN FICHIER CHIFFRE AVEC PASS = BACKUP SUR CLEF USB"
# ${MY_PATH}/tools/SAVE.astronaut.sh # tar.gzip PLAYER DATA TO USB KEY TODO

exit 0
