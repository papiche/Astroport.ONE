#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
################################################################################
## Publish All PLAYER TW,
# Run TAG subprocess: tube, voeu
############################################
echo "## RUNNING PLAYER.refresh"

PLAYERONE="$1"
[[ $isLAN ]] && PLAYERONE=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ! $PLAYERONE ]] && PLAYERONE=($(ls -t ~/.zen/game/players/  | grep -Ev "localhost" 2>/dev/null))

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in ${PLAYERONE[@]}; do
    [[ ! -d ~/.zen/game/players/$PLAYER ]] && echo "BAD $PLAYERONE" && continue

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ ! $(echo "$PLAYER" | grep '@') ]] && continue
    mkdir -p ~/.zen/tmp/${MOATS}
    echo "##################################################################"
    echo ">>>>> PLAYER : $PLAYER >>>>>>>>>>>>> REFRESHING TW STATION"
    echo "##################################################################"
    # Get PLAYER wallet amount
    COINS=$($MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey balance)
    echo "+++ WALLET BALANCE _ $COINS (G1) _"
    #~ ## IF WALLET IS EMPTY : WHAT TODO ?
    echo "##################################################################"
    echo "##################################################################"
    echo "################### REFRESH ASTRONAUTE TW ###########################"
    echo "##################################################################"

    PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/$PLAYER/.playerns 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "WARNING No $PLAYER in keystore --" && ASTRONAUTENS=$ASTRONS

    ## VISA EMITER STATION MUST ACT ONLY
    [[ ! -f ~/.zen/game/players/$PLAYER/secret.dunikey ]] && echo "$PLAYER secret.dunikey NOT HERE CONTINUE -- " \
                                                                                                            && mv ~/.zen/game/players/$PLAYER ~/.zen/game/players/.$PLAYER  &&  continue

    ## MY PLAYER
    ipfs key export $G1PUB -o ~/.zen/tmp/${MOATS}/$PLAYER.key
    [[ ! $(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1) ]] && ipfs key import $PLAYER ~/.zen/tmp/${MOATS}/$PLAYER.key
    rm -f ~/.zen/tmp/${MOATS}/$PLAYER.key

    ## REFRESH CACHE
    rm -Rf ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/

    echo "Getting latest online TW..."
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "/ipns/$ASTRONAUTENS ON $LIBRA"

    ipfs --timeout 60s get -o ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html /ipns/$ASTRONAUTENS \
    || curl -m 60 -so ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html "$LIBRA/ipns/$ASTRONAUTENS" \
    || cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html

    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html ]; then

        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "ERROR_PLAYERTW_OFFLINE : /ipns/$ASTRONAUTENS"
        echo "------------------------------------------------"
        echo "MANUAL PROCEDURE NEEDED"
        echo "------------------------------------------------"
        echo "$myIPFS/ipfs/"
        echo "/ipfs/"$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.* | tail -n 1)
        echo "ipfs name publish  -t 24h --key=$PLAYER ..."
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

        continue

    else
     ## FOUND TW
        #############################################################
        ## CHECK WHO IS ACTUAL OFFICIAL GATEWAY
            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html --output ~/.zen/tmp/${MOATS} --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
            [[ ! -s ~/.zen/tmp/${MOATS}/MadeInZion.json ]] && echo "${PLAYER} MadeInZion : BAD TW (☓‿‿☓) " && continue

            player=$(cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r .[].player)

            [[ $player == $PLAYER ]] \
            && echo "$PLAYER OFFICIAL TW - (⌐■_■) -" \
            || ( echo "BAD PLAYER=$player in TW" && continue)
    fi
        #############################################################
        ## GWIP == myIP or TUBE !!
        #############################################################

        # Connect_PLAYER_To_Gchange.sh : Sync FRIENDS TW
        ##############################################################
        echo "##################################################################"
        echo "## GCHANGE+ & Ŋ1 EXPLORATION:  Connect_PLAYER_To_Gchange.sh"
        ${MY_PATH}/../tools/Connect_PLAYER_To_Gchange.sh "$PLAYER"

        # VOEUX.create.sh
        ##############################################################
        ## SPECIAL TAG "voeu" => Creation G1Voeu (G1Titre) makes AstroBot TW G1Processing
        ##############################################################
        ${MY_PATH}/VOEUX.create.sh ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html "$PLAYER"
        # VOEUX.refresh.sh
        ##############################################################
        ## RUN ASTROBOT G1Voeux SUBPROCESS (SPECIFIC Ŋ1 COPY)
        ##############################################################
        ${MY_PATH}/VOEUX.refresh.sh "$PLAYER" "$MOATS" ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html
        ##############################################################

        ## CHECK G1PALPAY TO MAKE
        ${MY_PATH}/G1PalPay.sh ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html "$PLAYER"

        ##################################
        echo "# TW : GW API + LightBeam Feed + Friends"
        TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)

        FEEDNS=$(ipfs key list -l  | grep -w "${PLAYER}_feed" | cut -d ' ' -f 1)
        [[ ! $FEEDNS ]] && FEEDNS=$(ipfs key gen "${PLAYER}_feed")
        echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-name","text":"'${PLAYER}_feed'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-name.json
        echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key","text":"'${FEEDNS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-key.json

                ###########################
                # Modification Tiddlers de contrôle de GW & API
            #~ echo '[{"title":"$:/ipfs/saver/api/http/localhost/5001","tags":"$:/ipfs/core $:/ipfs/saver/api","text":"'$(myPlayerApiGw)'"}]' > ~/.zen/tmp/${MOATS}/5001.json
            #~ echo '[{"title":"$:/ipfs/saver/gateway/http/localhost","tags":"$:/ipfs/core $:/ipfs/saver/gateway","text":"'$myIPFS'"}]' > ~/.zen/tmp/${MOATS}/8080.json

            FRIENDSFEEDS=$(cat ~/.zen/tmp/${IPFSNODEID}/rss/${PLAYER}/FRIENDSFEEDS 2>/dev/null)
            echo "FRIENDS qo-op FEEDS : "${FRIENDSFEEDS}

            ## export FRIENDSFEEDS from Gchange stars
            echo '[{"title":"$:/plugins/astroport/lightbeams/state/subscriptions","text":"'${FRIENDSFEEDS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/friends.json

            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-name.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-key.json "application/json" \
                            --import "$HOME/.zen/tmp/${MOATS}/friends.json" "application/json" \
                            --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER} --render "$:/core/save/all" "newindex.html" "text/plain"

            [[ -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/newindex.html ]] \
                    && cp ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html \
                    && rm ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/newindex.html
                ###########################

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

    ##################################################
    ##################################################
    ################## UPDATING PLAYER MOA
    [[ $DIFF ]] && cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --allow-offline -t 24h --key=$PLAYER /ipfs/$TW

    [[ $DIFF ]] && echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats

    echo "================================================"
    echo "$PLAYER : $myIPFS/ipns/$ASTRONAUTENS"
    echo " = /ipfs/$TW"
    echo "================================================"

######################### PLAYER_feed
    IFRIENDHEAD="$(cat ~/.zen/tmp/${IPFSNODEID}/rss/${PLAYER}/IFRIENDHEAD 2>/dev/null)"
    echo "(☉_☉ ) (☉_☉ ) (☉_☉ )"
    echo "IFRIENDHEAD :" ${IFRIENDHEAD}
    echo "(☉_☉ ) (☉_☉ ) (☉_☉ )"

    # cp -f ~/.zen/game/players/${PLAYER}/ipfs/${FPLAYER}.rss.json ~/.zen/game/players/$PLAYER/FRIENDS/${FPLAYER}.rss.json

    [[ -d ~/.zen/game/players/$PLAYER/FRIENDS ]] \
    && cat ${MY_PATH}/../www/iframe.html | sed "s~_ME_~/ipns/${ASTRONAUTENS}~g" | sed "s~_IFRIENDHEAD_~${IFRIENDHEAD}~g" > ~/.zen/game/players/$PLAYER/FRIENDS/index.html

    [[ -s ~/.zen/game/players/$PLAYER/FRIENDS/index.html ]] \
    && FRAME=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/FRIENDS/index.html | tail -n 1) \
    && ipfs name publish --allow-offline -t 24h --key="${PLAYER}_feed" /ipfs/$FRAME

done

#################################################################
## IPFSNODEID ASTRONAUTES SIGNALING ## 12345 port
############################
# Scan local cache
if [[ -d ~/.zen/tmp/${IPFSNODEID} ]]; then
    BSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | cut -f 1)

    ## Merge actual online version
    ipfs get -o ~/.zen/tmp/${IPFSNODEID} /ipns/${IPFSNODEID}/
    ## MAP CACHE CLEANING
    rm -f ~/.zen/tmp/${IPFSNODEID}/*TW.json
    ############################################
    NSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | cut -f 1)

    [[ $BSIZE != $NSIZE ]] \
    && ROUTING=$(ipfs add -rwHq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 ) \
    && echo "PUBLISH BALISE STATION /ipns/${IPFSNODEID} = $NSIZE octets" \
    && ipfs name publish --allow-offline -t 24h /ipfs/$ROUTING
fi

echo "PLAYER.refresh DONE."

exit 0
