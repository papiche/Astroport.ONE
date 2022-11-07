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
IPFSNODEID=$(ipfs id -f='<id>\n')

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
    G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/$PLAYER/.playerns 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS || $COINS -lt 0 ]] && echo "WARNING No $PLAYER in keystore or Missing $COINS G1 --" && ASTRONAUTENS=$ASTRONS

    [[ ! -f ~/.zen/game/players/$PLAYER/enc.secret.dunikey ]] && echo "$PLAYER IPNS KEY NOT MINE CONTINUE -- " \
                                                                                                            && mv ~/.zen/game/players/$PLAYER ~/.zen/game/players/.$PLAYER  &&  continue

    rm -Rf ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/

myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="127.0.1.1"

    echo "Getting latest online TW..."
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "$LIBRA/ipns/$ASTRONAUTENS"
    echo "http://$myIP:8080/ipns/$ASTRONAUTENS ($YOU)"
    [[ $YOU ]] && ipfs --timeout 12s cat /ipns/$ASTRONAUTENS > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html \
                        || curl -m 12 -so ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html "$LIBRA/ipns/$ASTRONAUTENS"

    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html ]; then

        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "ERROR_PLAYERTW_OFFLINE : /ipns/$ASTRONAUTENS"
        echo "------------------------------------------------"
        echo "MANUAL PROCEDURE NEEDED"
        echo "------------------------------------------------"
        echo "http://$myIP:8080/ipfs/"
        cat ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.*
        echo "ipfs name publish  -t 72h --key=$PLAYER /ipfs/"
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

        continue

    else
     ## FOUND TW
        #############################################################
        ## CHECK IF myIP IS ACTUAL OFFICIAL GATEWAY
        tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)
        [[ ! $OLDIP ]] && echo "(╥☁╥ ) ERROR - SORRY - TW IS BROKEN - (╥☁╥ ) " && continue
        # WHO IS OFFICIAL TW GATEWAY.
        [[ $OLDIP != $myIP && $OLDIP != "_SECRET_" ]] && ipfs key rm ${PLAYER} && echo "*** OFFICIAL GATEWAY : http://$OLDIP:8080/ipns/$ASTRONAUTENS - (⌐■_■) - ***" && continue
        #############################################################

        # VOEUX.create.sh
        ##############################################################
        ## SPECIAL TAG "voeu" => Creation G1Voeu (G1Titre) makes AstroBot TW G1Processing
        ##############################################################
        $MY_PATH/VOEUX.create.sh ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html $PLAYER

        # VOEUX.refresh.sh
        ##############################################################
        ## RUN ASTROBOT G1Voeux SUBPROCESS (SPECIFIC AND STANDARD Ŋ1 SYNC)
        ##############################################################
        $MY_PATH/VOEUX.refresh.sh ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html $PLAYER
        ##############################################################

        ####################
        # REMOVE OFFCIAL : myIP becomes _SECRET_
        sed -i "s~${myIP}~_SECRET_~g" ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html
        TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)
        sed -i "s~_SECRET_~$TUBE~g" ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html

        ####################

        ## ANY CHANGES ?
        ##############################################################
        DIFF=$(diff ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html)
        if [[ $DIFF ]]; then
            echo "DIFFERENCE DETECTED !! "
            echo "Backup & Upgrade TW local copy..."
            cp ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        fi
        ##############################################################

    fi

    ##################################################
    IKEY=$G1PUB
    ##################################################
    ################## UPDATING PLAYER MOA
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ $DIFF ]] && cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --allow-offline -t 72h --key=$IKEY /ipfs/$TW

    [[ $DIFF ]] && echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats

    echo "================================================"
    echo "$PLAYER : http://$myIP:8080/ipns/$ASTRONAUTENS"
    echo "================================================"

done

#################################################################
## IPFSNODEID ASTRONAUTES SIGNALING ## 12345 port
############################
ls ~/.zen/tmp/${IPFSNODEID}/

ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )

echo "PUBLISHING SELF"
ipfs name publish --allow-offline -t 72h /ipfs/$ROUTING

echo "THANK YOU."

exit 0
