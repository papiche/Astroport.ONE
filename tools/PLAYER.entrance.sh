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

# Check who is currently current connected PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null)

# Check if Astroport Station already has a "captain"
source ~/.zen/ipfs.sync

### AN ASTROPORT NEEDS A CAPTAIN
##############################
if [[ $IPFS_SYNC_DIR == "" || $IPFS_SYNC_DIR == "$HOME/astroport" ]]; then

    echo "Aucun pilote dans le cockpit."; sleep 1
    echo "$PLAYER séquence déplacement clef balise station..."; sleep 1

    # astrXbian tranformation only once!
    [[ -f ~/.ipfs/config.astrXbian ]] && echo "FATAL ERROR"; echo "File corruption detected. EXIT"; exit 1

    # 1st Captain. Changing IPFS station key.
    sudo service ipfs stop

    # Replace ~/.ipfs
    mv ~/.ipfs/config ~/.ipfs/config.astrXbian
    cp ~/.zen/game/players/$PLAYER/ipfs.config ~/.ipfs/config
    ## TODO CONTROL keystore to enhance security level
    ## ajouter_video KEYS will be moved when captain is changing?

    # Moving captain data into Balise Station
    mv ~/.zen/game/players/$PLAYER/ipfs/.* ~/.zen/ipfs/

    ## Start IPFS DAEMON
    sudo service ipfs start

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
        echo "Joueur $PLAYER, $IPFS_SYNC_DIR est votre capitaine"; sleep 1
        echo "$PSEUDO, inscrivez dans votre 'Moa Journal' vos rêves et remarques à adresser au monde ou capitaine de cet Astroport"; sleep 1

    fi
fi

${MY_PATH}/tools/JOURNAL.visit.sh # OPEN TIDDLYWIKIS


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
