#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
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
for PLAYER in $(ls ~/.zen/game/players/); do

    echo "##################################################################"
    echo ">>>>> PLAYER : $PLAYER"
    echo "##################################################################"
    PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "Missing $PLAYER IPNS KEY -- CONTINUE --" && continue

    rm -Rf ~/.zen/tmp/astro
    mkdir -p ~/.zen/tmp/astro

    # Get PLAYER wallet amount
    BAL=$($MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey balance)
    echo "+++ WALLET BALANCE _ $BAL (G1) _"

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

        echo "ERROR_PLAYERTW_TIMEOUT : /ipns/$ASTRONAUTENS"
        echo "------------------------------------------------"
        echo "MANUAL PROCEDURE NEEDED"
        echo "------------------------------------------------"
        echo "TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)"
        echo "ipfs name publish  -t 72h --key=$PLAYER /ipfs/\$TW"
        continue

    else

        ## CHECK IF myIP IS LAST GATEWAY
        tiddlywiki --load ~/.zen/tmp/astro/index.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)

        # FIRST TW MANAGER
        [[ $OLDIP == "_SECRET_" ]] && sed -i "s~_SECRET_~${myIP}~g" ~/.zen/tmp/astro/index.html && OLDIP=$myIP
        # ALREADY MANAGED TW
        [[ $OLDIP != $myIP ]] && echo "ASTRONAUTE GATEWAY IS http://$OLDIP:8080/ipns/$ASTRONAUTENS - BYPASSING -" && continue


        ##############################################################
        ## SPECIAL TAG "voeu" => Creation G1Voeu (G1Titre) makes AstroBot TW G1Processing
        ##############################################################
        $MY_PATH/VOEUX.create.sh ~/.zen/tmp/astro/index.html $PLAYER
        ##############################################################
        ## RUN ASTROBOT SUBPROCESS (SEARCH FOR SPECIFIC OR RUN STANDARD Ŋ1 SYNC)
        ##############################################################
        ## TAG="tube" tiddler => Dowload youtube video links (playlist accepted) ## WISHKEY=PLAYER or G1PUB !
        $MY_PATH/G1CopierYoutube.sh ~/.zen/tmp/astro/index.html $PLAYER
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

        ## REFRESH G1BARRE for ALL G1VOEUX in PLAYER TW
        ##############################################################
#        ~/.zen/Astroport.ONE/tools/G1Barre4Player.sh $PLAYER
        ##############################################################

############################
## ASTRONAUTE SIGNALING ##
[[ ! $(grep -w "$ASTRONAUTENS" ~/.zen/game/astronautes.txt ) ]] && echo "$PSEUDO:$PLAYER:$ASTRONAUTENS" >> ~/.zen/game/astronautes.txt
############################


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

done

#################################################################
## IPFSNODEID ROUTING
## PUBLISHING ASTRONAUTS LIST
## EVOLVE TO P2P QOS MAP JSON
ROUTING=$(ipfs add -q ~/.zen/game/astronautes.txt)
echo "PUBLISHING IPFSNODEID / Astronaute List"
ipfs name publish /ipfs/$ROUTING

exit 0
