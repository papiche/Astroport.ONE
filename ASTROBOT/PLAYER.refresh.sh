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
rm ~/.zen/game/astronautes.txt

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in $(ls ~/.zen/game/players/); do

    echo "##################################################################"
    echo ">>>>> PLAYER : $PLAYER"
    echo "##################################################################"
    echo "    ## MANAGE GCHANGE+ & Ŋ1 EXPLORATION"
    ${MY_PATH}/../tools/Connect_PLAYER_To_Gchange.sh "$PLAYER"
    echo "##################################################################"
    echo "##################################################################"
    echo "##################################################################"

    PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "Missing $PLAYER IPNS KEY -- CONTINUE --" && continue

    rm -Rf ~/.zen/tmp/astro
    mkdir -p ~/.zen/tmp/astro

    # Get PLAYER wallet amount
    COINS=$($MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey balance)
    echo "+++ WALLET BALANCE _ $COINS (G1) _"
    echo

    myIP=$(hostname -I | awk '{print $1}' | head -n 1)

    echo "Getting latest online TW..."
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "$LIBRA/ipns/$ASTRONAUTENS"
    echo "http://$myIP:8080/ipns/$ASTRONAUTENS ($YOU)"
    [[ $YOU ]] && ipfs --timeout 12s cat  /ipns/$ASTRONAUTENS > ~/.zen/tmp/astro/index.html \
                        || curl -m 12 -so ~/.zen/tmp/astro/index.html "$LIBRA/ipns/$ASTRONAUTENS"

    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/astro/index.html ]; then

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

        #############################################################
        ## CHECK IF myIP IS ACTUAL OFFICIAL GATEWAY
        tiddlywiki --load ~/.zen/tmp/astro/index.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)
        # FIRST TIME PLAYER TW USING GATEWAY
        [[ $OLDIP == "_SECRET_" ]] && echo "_SECRET_ TW" && sed -i "s~_SECRET_~${myIP}~g" ~/.zen/tmp/astro/index.html && OLDIP=$myIP
        # AM I MANAGING TW
        [[ $OLDIP != $myIP ]] && echo "ASTRONAUTE GATEWAY IS http://$OLDIP:8080/ipns/$ASTRONAUTENS - BYPASSING -" && continue
        #############################################################

        # VOEUX.create.sh
        ##############################################################
        ## SPECIAL TAG "voeu" => Creation G1Voeu (G1Titre) makes AstroBot TW G1Processing
        ##############################################################
        $MY_PATH/VOEUX.create.sh ~/.zen/tmp/astro/index.html $PLAYER

        # VOEUX.refresh.sh
        ##############################################################
        ## RUN ASTROBOT G1Voeux SUBPROCESS (SPECIFIC AND STANDARD Ŋ1 SYNC)
        ##############################################################
        $MY_PATH/VOEUX.refresh.sh ~/.zen/tmp/astro/index.html $PLAYER
        ##############################################################

        ## ANY CHANGES ?
        ##############################################################
        DIFF=$(diff ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html)
        if [[ $DIFF ]]; then
            echo "DIFFERENCE DETECTED !! "
            echo "Backup & Upgrade TW local copy..."
            cp ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        else
            echo "No change since last Refresh..."
        fi
        ##############################################################

    fi

    #
        ##############################################################
        ## TODO : Make it G1Voeu with program contained in a tiddler using G1AstroBot ;)
        ## REFRESH G1BARRE for ALL G1VOEUX in PLAYER TW
        ##############################################################
#        ~/.zen/Astroport.ONE/tools/G1Barre4Player.sh $PLAYER
        ##############################################################

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

## PUBLISHING ASTRONAUTS LIST
[[ ! $(grep -w "$ASTRONAUTENS" ~/.zen/game/astronautes.txt ) ]] && echo "$PSEUDO:$PLAYER:$ASTRONAUTENS" >> ~/.zen/game/astronautes.txt

done

#################################################################
## IPFSNODEIDE ASTRONAUTES SIGNALING ##
############################
############################
## TODO EVOLVE TO P2P QOS MAPPING
cat ~/.zen/game/astronautes.txt
ROUTING=$(ipfs add -q ~/.zen/game/astronautes.txt)
echo "PUBLISHING Astronaute List SELF"
ipfs name publish /ipfs/$ROUTING

exit 0
