#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
################################################################################
## Publish All PLAYER TW,
# Run TAG subprocess: tube, voeu
############################################
echo "## RUNNING PLAYER.refresh"

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in $(ls -t ~/.zen/game/players/); do
    [[ $PLAYER == '.toctoc' ]] && echo ".toctoc users " && continue
    echo "##################################################################"
    echo ">>>>> PLAYER : $PLAYER >>>>>>>>>>>>> REFRESHING TW STATION"
    echo "##################################################################"
    # Get PLAYER wallet amount
    COINS=$($MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey balance)
    echo "+++ WALLET BALANCE _ $COINS (G1) _"
    ## DROP IF WALLET IS EMPTY : TODO
    echo "##################################################################"
    echo "## GCHANGE+ & Ŋ1 EXPLORATION:  Connect_PLAYER_To_Gchange.sh"
    ${MY_PATH}/../tools/Connect_PLAYER_To_Gchange.sh "$PLAYER"
    echo "##################################################################"
    echo "##################################################################"
    echo "################### REFRESH ASTRONAUTE TW ###########################"
    echo "##################################################################"

    PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "Missing $PLAYER IPNS KEY -- CONTINUE --" && continue

    rm -Rf ~/.zen/tmp/${PLAYER}
    mkdir -p ~/.zen/tmp/${PLAYER}

    myIP=$(hostname -I | awk '{print $1}' | head -n 1)

    echo "Getting latest online TW..."
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "$LIBRA/ipns/$ASTRONAUTENS"
    echo "http://$myIP:8080/ipns/$ASTRONAUTENS ($YOU)"
    [[ $YOU ]] && ipfs --timeout 12s cat /ipns/$ASTRONAUTENS > ~/.zen/tmp/${PLAYER}/index.html \
                        || curl -m 12 -so ~/.zen/tmp/${PLAYER}/index.html "$LIBRA/ipns/$ASTRONAUTENS"

    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/${PLAYER}/index.html ]; then

        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "ERROR_PLAYERTW_TIMEOUT : /ipns/$ASTRONAUTENS"
        echo "------------------------------------------------"
        echo "MANUAL PROCEDURE NEEDED"
        echo "------------------------------------------------"
        echo "TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)"
        echo "ipfs name publish  -t 72h --key=$PLAYER /ipfs/\$TW"
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        continue

    else
     ## FOUND TW
        #############################################################
        ## CHECK IF myIP IS ACTUAL OFFICIAL GATEWAY
        tiddlywiki --load ~/.zen/tmp/${PLAYER}/index.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)
        [[ ! $OLDIP ]] && echo "(╥☁╥ ) ERROR - SORRY - TW IS BROKEN - (╥☁╥ ) " && continue
        # WHO IS OFFICIAL TW GATEWAY
        [[ $OLDIP != $myIP ]] && ipfs key rm ${PLAYER} && echo "*** OFFICIAL GATEWAY : http://$OLDIP:8080/ipns/$ASTRONAUTENS - (⌐■_■) - ***" && continue
        #############################################################

        # VOEUX.create.sh
        ##############################################################
        ## SPECIAL TAG "voeu" => Creation G1Voeu (G1Titre) makes AstroBot TW G1Processing
        ##############################################################
        $MY_PATH/VOEUX.create.sh ~/.zen/tmp/${PLAYER}/index.html $PLAYER

        # VOEUX.refresh.sh
        ##############################################################
        ## RUN ASTROBOT G1Voeux SUBPROCESS (SPECIFIC AND STANDARD Ŋ1 SYNC)
        ##############################################################
        $MY_PATH/VOEUX.refresh.sh ~/.zen/tmp/${PLAYER}/index.html $PLAYER
        ##############################################################

        ####################
        # LOCKING TW : myIP becomes _SECRET_
        sed -i "s~${myIP}~_SECRET_~g" ~/.zen/tmp/${PLAYER}/index.html
        ####################

        ## ANY CHANGES ?
        ##############################################################
        DIFF=$(diff ~/.zen/tmp/${PLAYER}/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html)
        if [[ $DIFF ]]; then
            echo "DIFFERENCE DETECTED !! "
            echo "Backup & Upgrade TW local copy..."
            cp ~/.zen/tmp/${PLAYER}/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        fi
        ##############################################################

    fi

    ##################################################
    ##################################################
    ################## UPDATING PLAYER MOA
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ $DIFF ]] && cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --allow-offline -t 72h --key=$PLAYER /ipfs/$TW

    [[ $DIFF ]] && echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats

    echo "================================================"
    echo "$PLAYER : http://$myIP:8080/ipns/$ASTRONAUTENS"
    echo "================================================"

    ## TODO ! NOT .current SO ipfs key rm

## PUBLISHING ASTRONAUTS LIST
[[ ! $(grep -w "$ASTRONAUTENS" ~/.zen/game/astronautes.txt ) ]] && echo "$PSEUDO:$PLAYER:$ASTRONAUTENS" >> ~/.zen/game/astronautes.txt

done

#################################################################
## IPFSNODEIDE ASTRONAUTES SIGNALING ##
############################
############################
## TODO EVOLVE TO P2P QOS MAPPING
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
ls ~/.zen/tmp/${IPFSNODEID}/
ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )
echo "PUBLISHING ASTRONAUTES SIGNALING"
ipfs name publish --allow-offline -t 72h /ipfs/$ROUTING
echo "THANK YOU."

exit 0
