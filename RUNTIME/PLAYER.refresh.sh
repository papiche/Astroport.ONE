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
# [[ $isLAN ]] && PLAYERONE=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ! ${PLAYERONE} ]] && PLAYERONE=($(ls -t ~/.zen/game/players/  | grep "@" 2>/dev/null))

echo "FOUND : ${PLAYERONE[@]}"

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in ${PLAYERONE[@]}; do
    [[ ! -d ~/.zen/game/players/${PLAYER:-undefined} ]] && echo "BAD ${PLAYERONE}" && continue
    [[ ! $(echo "${PLAYER}" | grep '@') ]] && continue

    # CLEAN LOST ACCOUNT
    [[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] \
        && rm -Rf ~/.zen/game/players/${PLAYER} \
        && mv ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.${PLAYER} 2>/dev/null \
        && echo "LOST ${PLAYER} IS OUT" \
        && continue

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}

    echo "##################################################################"
    echo ">>>>> PLAYER : ${PLAYER} >>>>>>>>>>>>> REFRESHING TW STATION"
    echo "##################################################################"
    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)
    # Get PLAYER wallet amount
    COINS=$($MY_PATH/../tools/COINScheck.sh $G1PUB | tail -n 1)
    echo "+++ WALLET BALANCE _ $COINS (G1) _"
    #~ ## IF WALLET IS EMPTY : WHAT TODO ?
    echo "##################################################################"

    echo "##################################################################"
    echo "################### REFRESH ASTRONAUTE TW ###########################"
    echo "##################################################################"


    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
    [[ ! ${ASTRONAUTENS} ]] \
        && echo "WARNING No ${PLAYER} in keystore WARNING WARNING" \
        && ASTRONAUTENS=$ASTRONS

    [[ ! ${ASTRONAUTENS} ]] && echo "ERROR BAD ${PLAYER} - CONTINUE" && continue

    echo ">>> $myIPFS/ipns/${ASTRONAUTENS}"

    ## MY PLAYER : RESTORE PLAYER KEY FROM G1PUB (IN CASE IS MISSING : PLAYER LOGOUT)
    [[ ! $(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1) ]] \
        &&  ipfs key export ${G1PUB} -o ~/.zen/tmp/${MOATS}/${PLAYER}.key \
        && ipfs key import ${PLAYER} ~/.zen/tmp/${MOATS}/${PLAYER}.key \
        && rm ~/.zen/tmp/${MOATS}/${PLAYER}.key

    ## REFRESH PLAYER IN STATION CACHE
    rm -Rf ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/ 2>/dev/null ## CORRECT OLD PUBLISH FORMAT REMOVE

    rm -Rf ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/

    echo "Getting latest online TW..."
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "/ipns/${ASTRONAUTENS} ON $LIBRA"

    ## IPFS / HTTP / LOCAL
    ipfs --timeout 360s get -o ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html /ipns/${ASTRONAUTENS} \
    || curl -m 60 -so ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "$LIBRA/ipns/${ASTRONAUTENS}" \
    || cp ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ]; then

        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "ERROR_PLAYERTW_OFFLINE : /ipns/${ASTRONAUTENS}"
        echo "------------------------------------------------"
        echo "MANUAL PROCEDURE NEEDED"
        echo "------------------------------------------------"
        echo "$myIPFS/ipfs/"
        echo "/ipfs/"$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.* | tail -n 1)
        echo "ipfs name publish  -t 24h --key=${PLAYER} ..."
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

        continue

    else
     ## FOUND TW
        #############################################################
        ## CHECK WHO IS ACTUAL OFFICIAL GATEWAY
            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion' ## MadeInZion Tiddler

            [[ ! -s ~/.zen/tmp/${MOATS}/MadeInZion.json ]] && echo "${PLAYER} MadeInZion : BAD TW (☓‿‿☓) " && continue

            player=$(cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r .[].player)

            [[ $player == ${PLAYER} ]] \
            && echo "${PLAYER} OFFICIAL TW - (⌐■_■) -" \
            || ( echo "> BAD PLAYER=$player in TW" && continue)

            ## GET "Astroport" TIDDLER
            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'  ## Astroport Tiddler
            ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport) ## Raccorded G1Station IPNS address
            CURCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].chain | rev | cut -f 1 -d '/' | rev) # Remove "/ipfs/" part
            [[ ${CURCHAIN} == "" ||  ${CURCHAIN} == "null" ]] &&  CURCHAIN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" # AVOID EMPTY
            echo "CURCHAIN=${CURCHAIN}"
            IPNSTAIL=$(echo ${ASTROPORT} | rev | cut -f 1 -d '/' | rev) # Remove "/ipns/" part
            echo "TW ASTROPORT GATEWAY : ${ASTROPORT}"

            ## GET "GPS" TIDDLER
            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
            UMAPNS=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].umap)
            LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
            LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
            echo "> GPS_${LAT}_${LON} : ${UMAPNS}"

            ########### ASTROPORT is not IPFSNODEID => EJECT TW
            ## MOVED PLAYER (KEY IS KEPT ON LAST CONNECTED ASTROPORT)
            if [[ ${IPNSTAIL} != ${IPFSNODEID} && ${IPNSTAIL} != "_ASTROPORT_" ]]; then
                echo "> I AM ${IPFSNODEID}  :  PLAYER MOVED TO ${IPNSTAIL} : EJECTION "
                echo "REMOVE PLAYER & G1VOEU IPNS KEYS"
                ipfs key rm "${PLAYER}" "${PLAYER}_feed" "$G1PUB"
                for vk in $(ls -d ~/.zen/game/players/${PLAYER}/voeux/*/* | rev | cut -d / -f 1 | rev); do
                    ipfs key rm $vk
                done
                rm -Rf ~/.zen/game/players/${PLAYER}/
                echo ">>>> ASTRONAUT ${PLAYER} TW CAPSULE EJECTION TERMINATED"
                continue
            fi
    fi
        #############################################################
        ## GWIP == myIP or TUBE !!
        #############################################################
        # Connect_PLAYER_To_Gchange.sh : Sync FRIENDS TW
        ##############################################################
        echo "##################################################################"
        echo "## GCHANGE+ & Ŋ1 EXPLORATION:  Connect_PLAYER_To_Gchange.sh"
        ${MY_PATH}/../tools/Connect_PLAYER_To_Gchange.sh "${PLAYER}"

        ###############
        # VOEUX.create.sh #
        ##############################################################
        ## SPECIAL TAG "voeu" => Creation G1Voeu (G1Titre) makes AstroBot TW G1Processing
        ##############################################################
        ${MY_PATH}/VOEUX.create.sh ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "${PLAYER}" "${G1PUB}"

        ###############
        # VOEUX.refresh.sh #
        ##############################################################
        ## RUN ASTROBOT G1Voeux SUBPROCESS (SPECIFIC Ŋ1 COPY)
        ##############################################################
        ${MY_PATH}/VOEUX.refresh.sh "${PLAYER}" "${MOATS}" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

        ###################
        # REFRESH PLAYER_feed #
        ##################################
        echo "# TW : GW API + LightBeam Feed + Friends"
        TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)

        FEEDNS=$(ipfs key list -l  | grep -w "${PLAYER}_feed" | cut -d ' ' -f 1)
        [[ ! ${FEEDNS} ]] && echo ">>>>> ERROR ${PLAYER}_feed IPNS KEY NOT FOUND - ERROR" && continue

        # WRITE lightbeam params
        echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-name","text":"'${PLAYER}_feed'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-name.json
        echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key","text":"'${FEEDNS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-key.json

                ###########################
                # Tiddlers controling GW & API
            #~ echo '[{"title":"$:/ipfs/saver/api/http/localhost/5001","tags":"$:/ipfs/core $:/ipfs/saver/api","text":"'$(myPlayerApiGw)'"}]' > ~/.zen/tmp/${MOATS}/5001.json
            #~ echo '[{"title":"$:/ipfs/saver/gateway/http/localhost","tags":"$:/ipfs/core $:/ipfs/saver/gateway","text":"'$myIPFS'"}]' > ~/.zen/tmp/${MOATS}/8080.json

            ## COPY DATA PRODUCED BY GCHANGE STAR EXTRACTION
            FRIENDSFEEDS=$(cat ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/FRIENDSFEEDS 2>/dev/null)
            echo "FRIENDS qo-op FEEDS : "${FRIENDSFEEDS}
            echo '[{"title":"$:/plugins/astroport/lightbeams/state/subscriptions","text":"'${FRIENDSFEEDS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/friends.json

            ## WRITE TIDDLERS IN TW
            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-name.json "application/json" \
                            --import ~/.zen/tmp/${MOATS}/lightbeam-key.json "application/json" \
                            --import "$HOME/.zen/tmp/${MOATS}/friends.json" "application/json" \
                            --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} --render "$:/core/save/all" "newindex.html" "text/plain"

            ## CHECK IT IS OK
            [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]] \
                    && cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                    && rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html
                ###########################

        ####################

        ## ANY CHANGES ?
        ##############################################################
        DIFF=$(diff ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html)
        if [[ $DIFF ]]; then
            echo "DIFFERENCE DETECTED !! "
            echo "Backup & Upgrade TW local copy..."
            cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

            [[ -s ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain ]] \
            && ZCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain) \
            && echo "# CHAIN : ${CURCHAIN} -> ${ZCHAIN}" \
            && [[ ${CURCHAIN} != "" && ${ZCHAIN} != "" ]]  \
            && sed -i "s~${CURCHAIN}~${ZCHAIN}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html
        fi
        ##############################################################

    ##################################################
    ##################################################
    ################## UPDATING PLAYER MOA
    [[ $DIFF ]] && cp   ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain \
                                    ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --allow-offline -t 24h --key=${PLAYER} /ipfs/${TW}

    [[ $DIFF ]] && echo ${TW} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain
    echo ${MOATS} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats

    echo "================================================"
    echo " NEW TW ${PLAYER} : =  ${myIPFS}/ipfs/${TW}"
    echo "  $myIPFSGW/ipns/${ASTRONAUTENS}"
    echo "================================================"

    echo "(☉_☉ ) (☉_☉ ) (☉_☉ ) RSS"
    ## CREATING 30 DAYS RSS STREAM
    tiddlywiki --load --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                        --output ~/.zen/game/players/${PLAYER}/ipfs --render '.' "${PLAYER}.rss.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-30]]'
    [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json ]] && echo "NO ${PLAYER} RSS - BAD ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json -"

    IRSS=$(ipfs add -q ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json | tail -n 1) \
    && ipfs name publish --key="${PLAYER}_feed" /ipfs/${IRSS}

    ## Publish on LAT/ON key on 12345 CACHE
    [[ ${LAT} && ${LON} ]] \
    && [[ -d ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON} ]] \
        && mkdir ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/RSS/ \
        && cp ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/RSS/

    ls -al ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON} 2>/dev/null
    echo "(☉_☉ ) (☉_☉ ) (☉_☉ )"

######################### PLAYER_feed
    #~ IFRIENDHEAD="$(cat ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/IFRIENDHEAD 2>/dev/null)"
    #~ echo "(☉_☉ ) (☉_☉ ) (☉_☉ )"
    #~ echo "IFRIENDHEAD :" ${IFRIENDHEAD}
    #~ [[ -d ~/.zen/game/players/${PLAYER}/FRIENDS ]] \
    #~ && cat ${MY_PATH}/../www/iframe.html | sed "s~_ME_~/ipns/${ASTRONAUTENS}~g" | sed "s~_IFRIENDHEAD_~${IFRIENDHEAD}~g" > ~/.zen/game/players/${PLAYER}/FRIENDS/index.html
    #~ [[ -s ~/.zen/game/players/${PLAYER}/FRIENDS/index.html ]] \
    #~ && FRAME=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/FRIENDS/index.html | tail -n 1) \
    #~ && ipfs name publish --key="${PLAYER}_feed" /ipfs/$FRAME

done
echo "PLAYER.refresh DONE."

${MY_PATH}/../tools/MAP.refresh.sh

exit 0
