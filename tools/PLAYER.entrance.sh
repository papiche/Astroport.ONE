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

# Check who is .current PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )

# Check if Astroport Station already has a "captain"
source ~/.zen/ipfs.sync; echo "CAPTAIN is $CAPTAIN"

echo
echo "** Stop or Kill ipfs daemon **"
    # 1st Captain. Changing IPFS station key.
    sudo service ipfs stop
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ $YOU ]] && sudo killall -5 ipfs
    #-----------------------------------

### AN ASTROPORT NEEDS A CAPTAIN
##############################
if [[ ! -d ~/.zen/game/players/$CAPTAIN || $CAPTAIN == "" || $CAPTAIN == "$HOME/astroport" ]]; then
    echo "#-----------------------------------"
    echo $CAPTAIN
    echo "Aucun Capitaine à bord."; sleep 1
    echo "$PLAYER vous devenez la clef maitre de la Station et de sa balise astrXbian..."; sleep 2
    echo "Vous validez et activez les canaux, public 'qo-op' et administratif 'moa'"; sleep 2
    echo "Contactez support@qo-op.com afin le Canal original MadeInZion"; sleep 2

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
###################################################################################
    # 'tokenring' Key there? TOKENRING IS A SHARED KEY TO KNOW WHO IS NEXT IN MY FRIEND TO WRITE COMMON CHANNEL
    # In case of corruption... Swarm goes into DEFCON 3 procedure and eject "bad friend"
    # Shared between Astroport to choose Station next write time.
    [[ ! -f ~/.ipfs/keystore/key_orxwwzloojuw4zy ]] && qoopns=$(ipfs key gen tokenring)
        # tokenring show which PLAYER is the actual 'official' qo-op and moa channels publisher/
        # tokenringnns is used to choose who is next...
    ipfs key list -l | grep -w tokenring
    tokenringns=$(ipfs key list -l | grep -w tokenring | cut -d ' ' -f 1)
    ipfs name publish --key=tokenring /ipfs/$(echo $PLAYER | ipfs add -q) 2>/dev/null

    echo "----> 'tokenringnns' WHO IS NEXT : http://127.0.0.1:8080/ipns/$tokenringns"; sleep 1
    echo "$tokenringnns" > ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/.tokenringnns ## 'tokenring'  is "who is next player to play"

###################################################################################
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
    echo "$qoopns" > ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/.qoopns ## 'qo-op'  public channel declared in ipfs balise

###################################################################################
    # 'moa' Key there? It is the 'Administrative' 3 star.level confidence information layer.
    [[ ! -f ~/.ipfs/keystore/key_nvxwc ]] &&\
        moans=$(ipfs key gen moa) && \
        IPUSH=$(ipfs add -Hq ${MY_PATH}/../templates/moawiki.html | tail -n 1) && \
        ipfs name publish --key=moa /ipfs/$IPUSH 2>/dev/null
        # moa channel is created from template
    ipfs key list -l | grep -w moa
    moans=$(ipfs key list -l | grep -w moa | cut -d ' ' -f 1)

    echo "----> Station 'moa' channel : http://127.0.0.1:8080/ipns/$moans"; sleep 1
    echo "$moans" > ~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/.moans ## 'moa' captain controled channel

###################################################################################
    echo
    echo "===== Connect captain IPFS datadir to Station (balise junction) ====="; sleep 2

    [[ ! -d ~/.zen/ipfs.astrXbian ]] && mv ~/.zen/ipfs ~/.zen/ipfs.astrXbian && echo "BACKUP ~/.zen/ipfs.astrXbian" || rm ~/.zen/ipfs; sleep 2
    mv ~/.zen/ipfs ~/.zen/ipfs.astrXbian && echo "BACKUP current ~/.zen/ipfs"; sleep 2

    # Linking ~/.zen/ipfs
    # ~/.zen/secret.dunikey
    [[ ! -f ~/.zen/secret.dunikey.astrXbian ]] && mv ~/.zen/secret.dunikey ~/.zen/secret.dunikey.astrXbian && echo "BACKUP ~/.zen/secret.dunikey.astrXbian" || rm ~/.zen/secret.dunikey; sleep 2

    echo "CAPITAINE VOUS PRENEZ POSSESSION DE LA STATION ET SES CANAUX 'qo-op', 'moa', etc ..."
    ln -s ~/.zen/game/players/$PLAYER/ipfs ~/.zen/ipfs && echo "$PLAYER become IPFS 'self'" && sleep 1
    ln -s ~/.zen/game/players/$PLAYER/secret.dunikey ~/.zen/secret.dunikey && echo "Linking your ~/.zen/secret.dunikey to Station" && sleep 1

    echo "##################################################### OK"
    echo "Identité 'self' Balise IPFS"; sleep 1
    ipfs id -f='<id>\n'
    echo "##################################################### OK"
    echo "CAPTAIN=$PLAYER" > ~/.zen/ipfs.sync ## PLAYER IS ASTROPORT CAPTAIN NOW
    ## CAPTAIN is define  in ~/.zen/ipfs.sync

else
##############################

echo
echo "=== Switching ~/.ipfs/config ==="; sleep 2

    [[ ! -f ~/.ipfs/config.astrXbian ]] && mv ~/.ipfs/config ~/.ipfs/config.astrXbian && echo "BACKUP OLD ipfs config" || rm ~/.ipfs/config
    ln -s ~/.zen/game/players/$PLAYER/ipfs.config ~/.ipfs/config && echo "Installing $PLAYER 'G1' ipfs config";    sleep 2
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID); echo $IPFSNODEID

echo
echo "==== Astronaute keystore switch ===="; sleep 2

    [[ ! -d ~/.ipfs/keystore.astrXbian ]] && mv ~/.ipfs/keystore ~/.ipfs/keystore.astrXbian || rm ~/.ipfs/keystore
    ln -s ~/.zen/game/players/$PLAYER/keystore ~/.ipfs/keystore


echo "==== linking G1 Libre ID and Station ~/.zen/ipfs ===="; sleep 2

    [[ ! -f ~/.zen/secret.dunikey.astrXbian ]] && mv ~/.zen/secret.dunikey ~/.zen/secret.dunikey.astrXbian  || rm ~/.zen/secret.dunikey
    ln -s ~/.zen/game/players/$PLAYER/secret.dunikey ~/.zen/secret.dunikey

    [[ ! -d ~/.zen/ipfs.astrXbian ]] && mv ~/.zen/ipfs ~/.zen/ipfs.astrXbian && echo "BACKUP ~/.zen/ipfs.astrXbian" || rm ~/.zen/ipfs
    ln -s ~/.zen/game/players/$PLAYER/ipfs ~/.zen/ipfs && echo "$PLAYER ~/.zen/ipfs "


    echo
    echo "** Restart IPFS DAEMON **"
    sudo service ipfs start
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ ! $YOU ]] && ipfs daemon --writable &
    #-----------------------------------
    echo "#-----------------------------------"

    if [[ $CAPTAIN == "$PLAYER" ]]; then
        ## THE CAPTAIN IS LOGGED IN
        echo "Bienvenue CAPITAINE !"; sleep 2
        echo "Ouverture des journaux 'moa' et 'qo-op' de votre Station Astroport";
        # OPEN 'moa' channel
        moans=$(ipfs key list -l | grep -w moa | cut -d ' ' -f 1) || moans=$(cat ~/.zen/game/players/$CAPTAIN/ipfs/.12D*/.moans | tail -n 1)
        [[ $moans != ""  ]] && xdg-open "http://127.0.0.1:8080/ipns/$moans"

        # OPEN 'qo-op' channel
        qoopns=$(ipfs key list -l | grep -w qo-op | cut -d ' ' -f 1) || moans=$(cat ~/.zen/game/players/$CAPTAIN/ipfs/.12D*/.qoopns | tail -n 1)
        [[ $qoopns != ""  ]] && xdg-open "http://127.0.0.1:8080/ipns/$qoopns"

     else
        # ASTRONAUT PLAYER IS LOGGED IN
        echo "Joueur $PLAYER. Le Capitaine de cet Astroport est - $CAPTAIN -"; sleep 1
        echo
        echo "$PSEUDO, Décrivez vos 'Talents', soumettez vos 'Rêves' pour améliorer cet Astroport dans votre journal 'moa'."; sleep 2
        echo "Publiez dans votre journal public 'qo-op'"; sleep 2
        echo
    fi

fi

echo
echo "** Restart IPFS DAEMON **"
    sudo service ipfs start
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    [[ ! $YOU ]] && ipfs daemon --writable &
    #-----------------------------------
    echo "#-----------------------------------"

# OPEN PLAYER HOME (contains 'moa_player' + 'qo-op_player' vertical iframes
echo "OUVERTURE DE VOTRE INTERFACE JOUEUR"; sleep 1
player=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
xdg-open "http://127.0.0.1:8080/ipns/$player"

exit 0
