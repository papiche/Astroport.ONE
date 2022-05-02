#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# INTERFACE DE GESTION DE JOURNAUX DES PLAYERS
# Le Journal du CAPTAIN est désormais le journal de bord de cet Astroport

# Sa tâche sera de faire le tour des nouveaux rêves pour les ajouter à son journal désormais publié comme balise de la station astrXbian
# Alerter de manque de placement sur certains ou sur les primes de maintenance.

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
source ~/.zen/ipfs.sync

if [[ $IPFS_SYNC_DIR == "$PLAYER" ]]; then
    echo "Bienvenue capitaine $PLAYER !"; sleep 2
    echo "$PSEUDO ouverture du journal de votre Astroport (rassemblez les Good News des journaux Moa) ?"
    # Récupération de la clef du capitaine PLAYER ( identique à celle du démon IPFS )
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
    [ $? == 0 ] && xdg-open "http://127.0.0.1:8080/ipns/$IPFSNODEID"

    # Ouverture des Moa de tous les PLAYER
    for play in $(ls ~/.zen/game/players); do
        moaplayer=$(ipfs key list -l | grep -w moa_$play | cut -d ' ' -f 1)
        g1pub=$(cat ~/.zen/game/players/$play/_g1.pubkey)

        # Check if different from last record (check .chain)
        nowchain=$(ipfs cat /ipns/$moaplayer/chain 2>/dev/null)
        moachain=$(cat ~/.zen/ipfs/.$IPFSNODEID/FRIENDS/$g1pub/chain.moa 2>/dev/null)

        [[ $nowchain != $moachain ]] && xdg-open "http://127.0.0.1:8080/ipns/$moaplayer"
        # TODO Save actual moachain from a command received through Instscan/nc trick for exemple, or recurrent astrXbian actions...
        # ipfs cat /ipns/$moaplayer/chain > ~/.zen/ipfs/.$IPFSNODEID/FRIENDS/$g1pub/chain.moa
    done

    zenity --question --width 300 --text "$PLAYER souhaitez-vous ouvrir votre journal 'secret' (niveau 5) ?"
    # Récupération de la clef du capitaine PLAYER ( identique à celle du démon IPFS )
    player=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
    [ $? == 0 ] && xdg-open "http://127.0.0.1:8080/ipns/$player"

fi

# NOT CAPTAIN
zenity --question --width 300 --text "$PSEUDO souhaitez-vous ouvrir votre journal 'Moa' (niveau 3) ?"
# Récupération de la clef du capitaine PLAYER ( identique à celle du démon IPFS )
moa=$(ipfs key list -l | grep -w moa_$PLAYER | cut -d ' ' -f 1)
[ $? == 0 ] && xdg-open "http://127.0.0.1:8080/ipns/$moa"

zenity --question --width 300 --text "$PSEUDO souhaitez-vous ouvrir votre journal 'qo-op' (niveau 0) ?"
# Récupération de la clef du capitaine PLAYER ( identique à celle du démon IPFS )
qo-op=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
[ $? == 0 ] && xdg-open "http://127.0.0.1:8080/ipns/$qo-op"

# TODO: fabriquer une interface où passer d'un journal à l'autre, y glisser déposer, etc ...
# Le journal transmit par la balise IPFS est celui de la clef PLAYER du CAPTAIN.
# Ce journal ne se remplit pour un joueur que lorsqu'il devient CAPTAIN (y compris pour le canal secret).
#
# Le journal Moa = NFT où nous repertorions nos exploits et talents
# Le journal qo-op fait partie de la diffusion incensurable des bunkerbox (evolutions Youtube/Facebook/etc... ici on se branche au vieux web)

exit 0
