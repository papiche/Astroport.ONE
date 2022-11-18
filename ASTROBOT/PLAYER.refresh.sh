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
    echo "##################################################################"
    echo "################### REFRESH ASTRONAUTE TW ###########################"
    echo "##################################################################"

    PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/$PLAYER/.playerns 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "WARNING No $PLAYER in keystore --" && ASTRONAUTENS=$ASTRONS

    ## VISA EMITER STATION MUST ACT ONLY
    [[ ! -f ~/.zen/game/players/$PLAYER/enc.secret.dunikey ]] && echo "$PLAYER IPNS KEY NOT MINE CONTINUE -- " \
                                                                                                            && mv ~/.zen/game/players/$PLAYER ~/.zen/game/players/.$PLAYER  &&  continue

    ## MY PLAYER.
    ipfs key export $G1PUB -o ~/.zen/tmp/$PLAYER.key
    ipfs key import $PLAYER ~/.zen/tmp/$PLAYER.key
    rm -f ~/.zen/tmp/$PLAYER.key

    ## REFRESH CACHE
    rm -Rf ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/

myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="astroport.localhost"

    echo "Getting latest online TW..."
    YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
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
                tiddlywiki --load ~/.zen/tmp/coucou/${MOATS}.astroindex.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
                SECRET=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)
                [[ ! $SECRET ]] && (echo "$HTTPCORS SECRET ERROR - SORRY - CANNOT CONTINUE " | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && echo "BAD SECRET (☓‿‿☓) Execution time was "`expr $(date +%s) - $start` seconds. && continue
#
        # CRYPTO DECODING CRYPTIP -> myIP
                cat ~/.zen/tmp/miz.json | jq -r .[].secret | base16 -d > ~/.zen/tmp/myIP.$G1PUB.enc.2
                $MY_PATH/../tools/natools.py decrypt -f pubsec -k ~/.zen/game/players/$PLAYER/secret.dunikey -i ~/.zen/tmp/myIP.$G1PUB.enc.2 -o ~/.zen/tmp/myIP.$G1PUB > /dev/null 2>&1
                GWIP=$(cat  ~/.zen/tmp/myIP.$G1PUB > /dev/null 2>&1)

                [[ ! $GWIP ]] && GWIP=$SECRET ## CLEAR

                echo "TW is on $GWIP"

        # WHO IS OFFICIAL TW GATEWAY.
    if [[ ! -s ~/.zen/game/players/$PLAYER/ipfs/G1SSB/_g1.pubkey ]]; then
            if [[ $GWIP != $myIP ]]; then
                # NOT MY PLAYER
                echo "REMOVING PLAYER $PLAYER"
                rm -Rf ~/.zen/game/players/$PLAYER/
                ipfs key rm ${PLAYER}
                ipfs key rm ${G1PUB}
                echo "*** OFFICIAL GATEWAY : http://$GWIP:8080/ipns/$ASTRONAUTENS  ***" && continue
            fi
    else
        echo "OFFICIAL VISA - (⌐■_■) -"
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
        $MY_PATH/VOEUX.create.sh ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html $PLAYER

        # VOEUX.refresh.sh
        ##############################################################
        ## RUN ASTROBOT G1Voeux SUBPROCESS (SPECIFIC AND STANDARD Ŋ1 SYNC)
        ##############################################################
        $MY_PATH/VOEUX.refresh.sh ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html $PLAYER
        ##############################################################

        ####################
        echo "# TUBE as 8080 & 5001"
        TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)

                ###########################
                # Modification Tiddlers de contrôle de GW & API
            echo '[{"title":"$:/ipfs/saver/api/http/localhost/5001","tags":"$:/ipfs/core $:/ipfs/saver/api","text":"http://'$TUBE':5001"}]' > ~/.zen/tmp/5001.json
            echo '[{"title":"$:/ipfs/saver/gateway/http/localhost","tags":"$:/ipfs/core $:/ipfs/saver/gateway","text":"http://'$TUBE':8080"}]' > ~/.zen/tmp/8080.json

            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html \
                            --import "$HOME/.zen/tmp/5001.json" "application/json" \
                            --import "$HOME/.zen/tmp/8080.json" "application/json" \
                            --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER} --render "$:/core/save/all" "newindex.html" "text/plain"

            [[ -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/newindex.html ]] \
                    && cp ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html \
                    && rm ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/newindex.html
                ###########################

# [[ $GWIP == $SECRET ]]
        echo "# CRYPTO ENCODING $GWIP -> CRYPTIP"
        echo $GWIP > ~/.zen/tmp/GWIP
        $MY_PATH/../tools/natools.py encrypt -p $G1PUB -i $HOME/.zen/tmp/GWIP -o $HOME/.zen/tmp/myIP.$G1PUB.enc
        CRYPTIP=$(cat ~/.zen/tmp/myIP.$G1PUB.enc | base16)
        sed -i "s~$GWIP~$CRYPTIP~g" ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/index.html

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
    echo " = /ipfs/$TW"
    echo "================================================"

done

#################################################################
## IPFSNODEID ASTRONAUTES SIGNALING ## 12345 port
############################
# Scan local cache
ls ~/.zen/tmp/${IPFSNODEID}/
BSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | cut -f 1)

## Merge actual online version
ipfs get -o ~/.zen/tmp/${IPFSNODEID} /ipns/${IPFSNODEID}/
NSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | cut -f 1)

[[ $BSIZE != $NSIZE ]] \
&& ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 ) \
&& echo "BALISE STATION /ipns/${IPFSNODEID} INDEXES = $NSIZE octets" \
&& ipfs name publish --allow-offline -t 72h /ipfs/$ROUTING

echo "PLAYER.refresh DONE."

exit 0
