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

echo "RENEWING LOCAL UPLANET REPOSITORY
 ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??"
rm -Rf ~/.zen/tmp/${IPFSNODEID}/UPLANET
mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET
echo "CLEANING IPFSNODEID TW CACHE ~/.zen/tmp/${IPFSNODEID}/TW/"
rm -Rf ~/.zen/tmp/${IPFSNODEID}/TW/

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in ${PLAYERONE[@]}; do
    [[ ! -d ~/.zen/game/players/${PLAYER:-undefined} ]] && echo "BAD ${PLAYERONE}" && continue
    [[ ! $(echo "${PLAYER}" | grep '@') ]] && continue

    start=`date +%s`
    # CLEAN LOST ACCOUNT
    [[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] \
        && rm -Rf ~/.zen/game/players/${PLAYER} \
        && echo "WARNING - ERASE ${PLAYER} - BADLY PLUGGED" \
        && continue

    ### UPGRADE PLAYER for myos IPFS API ### DOUBLON WITH VISA.new (TO REMOVE)
    mkdir -p ~/.zen/game/players/${PLAYER}/.ipfs # Prepare PLAYER datastructure
    echo "/ip4/127.0.0.1/tcp/5001" > ~/.zen/game/players/${PLAYER}/.ipfs/api
    ######## WORK IN PROGRESS #### myos integration

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}
    echo "############################################ ~/.zen/tmp/${MOATS}"
    echo "##################################################################"
    echo ">>>>> PLAYER : ${PLAYER} >>>>>>>>>>>>> REFRESHING TW "
    echo "################################################ $(date)"
    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)
    # Get PLAYER wallet amount
    $MY_PATH/../tools/COINScheck.sh ${G1PUB} > ~/.zen/tmp/${MOATS}/${PLAYER}.COINScheck
    cat ~/.zen/tmp/${MOATS}/${PLAYER}.COINScheck ###DEBUG MODE
    COINS=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.COINScheck | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    echo "+++ WALLET BALANCE _ $COINS (G1) _ / $ZEN ZEN /"

    #~ ## ZENCARD ARE ACTIVATED WITH 1 G1 + 10 ZEN (= 10 €/OC) ?
    echo "## >>>>>>>>>>>>>>>> REFRESH ASTRONAUTE TW"
    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${G1PUB} | cut -d ' ' -f1)

    ############### CANNOT FIND PLAYER KEY ###########
    if [[ ! ${ASTRONAUTENS} ]]; then

        echo "${PLAYER} TW IS DISCONNECTED... RECREATING IPNS KEYS"
        ## TODO : EXTRACT & DECRYPT secret.june FROM TW
        ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/secret.player
        ipfs key import ${PLAYER} -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/secret.player

        source ~/.zen/game/players/${PLAYER}/secret.june
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/feed.ipfskey "$SALT" "$G1PUB"
        FEEDNS=$(ipfs key import "${PLAYER}_feed" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/feed.ipfskey)

        ## IF ASTRONS="" KEY WILL BE DELETED AFTER REFRESH
        ASTRONAUTENS=$ASTRONS && ASTRONS=""

    fi

    [[ ! ${ASTRONAUTENS} ]] && echo "ERROR BAD ${PLAYER} - CONTINUE" && continue

    echo ">>> $myIPFS/ipns/${ASTRONAUTENS}"

    ## ACTIVATE PLAYER TW IN STATION CACHE
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/

    ################### GET LATEST TW
    echo "GETTING TW..."
    ####################################################################################################
    ipfs --timeout 480s get -o ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html /ipns/${ASTRONAUTENS}
    ####################################################################################################
    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ]; then

        NOWCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain)
        LASTCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.* | tail -n 1)
        try=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.try 2>/dev/null) || try=3
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx<br>"
        echo "<a href='$myIPFS/ipns/${ASTRONAUTENS}'>TW REFRESH FAILED</a>"
        echo ">> %%% WARNING TRY LEFT : $try %%%"
        echo "------------------------------------------------"
        echo " * <a href='${myIPFS}/ipfs/${LASTCHAIN}'>LAST</a>"
        echo " * <a href='${myIPFS}/ipfs/${NOWCHAIN}'>NOW</a>"
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

        ## SEND AN EMAIL ALERT TO PLAYER
        echo "<html><body><a href='$myIPFS/ipns/${ASTRONAUTENS}'>TW REFRESH FAILED</a>" > ~/.zen/tmp/result
        echo "<br>------------------------------------------------" >> ~/.zen/tmp/result
        echo "<br>" >> ~/.zen/tmp/result
        echo "<br><a href='${myIPFS}/ipfs/${LASTCHAIN}'>TW[-1]</a>" >> ~/.zen/tmp/result
        echo "<br><a href='${myIPFS}/ipfs/${NOWCHAIN}'>TW[0]</a>" >> ~/.zen/tmp/result
        echo "<br>" >> ~/.zen/tmp/result
        echo "<br> %%% WARNING %%% $try TRY LEFT %%%" >> ~/.zen/tmp/result
        echo "<br>------------------------------------------------" >> ~/.zen/tmp/result
        echo "<br>REPAIR BY SAVING ONLINE<br>" >> ~/.zen/tmp/result
        echo "COMMAND :<br>ipfs name publish --key=${PLAYER} /ipfs/${NOWCHAIN}" >> ~/.zen/tmp/result
        echo "</body></html>" >> ~/.zen/tmp/result


        [[ $try == 0 ]] \
            && echo "PLAYER ${PLAYER} UNPLUG" \
            && ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${PLAYER} "ALL" \
            && continue

        try=$((try-1))
        echo "$try" > ~/.zen/game/players/${PLAYER}/ipfs/moa/.try

        $MY_PATH/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/result "TW[+1] REFRESH WARNING"

        continue

    fi

    #############################################################
    ## FOUND TW
    #############################################################
    ## CHECK IF OFFICIAL MadeInZion TW
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion' ## MadeInZion Tiddler

    [[ ! -s ~/.zen/tmp/${MOATS}/MadeInZion.json ]] && echo "${PLAYER} MadeInZion : BAD TW (☓‿‿☓) " && continue

    player=$(cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r .[].player)
    #############################################################
    ## REAL PLAYER REMOVE AstroID
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'AstroID.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'AstroID' ## AstroID Tiddler

    ###############################################################################
    ## EXTRACT "$:/config/NewTiddler/Tags" ## Astroport :: Lasertag :: TW plugin ##
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'TWsign.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '$:/config/NewTiddler/Tags' ## $:/config/NewTiddler/Tags Tiddler
    signature=$(cat ~/.zen/tmp/${MOATS}/TWsign.json | jq -r .[].text)
    echo "${player} SIGNATURE = $signature"

    ############################################################ BAD TW SIGNATURE
    [[ ${player} != ${PLAYER} || ${PLAYER} != ${signature} ]] \
        && echo "> (☓‿‿☓) BAD PLAYER=$player in TW (☓‿‿☓)" \
        && continue \
        || echo "${PLAYER} OFFICIAL TW - (⌐■_■) -"

    ## GET "Astroport" TIDDLER
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'  ## Astroport Tiddler
    BIRTHDATE=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].birthdate)
    ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport) ## ZenStation IPNS address
    CURCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].chain | rev | cut -f 1 -d '/' | rev) # Remove "/ipfs/" part
    [[ ${CURCHAIN} == "" ||  ${CURCHAIN} == "null" ]] \
        &&  CURCHAIN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" # AVOID EMPTY

    SBIRTH=$(${MY_PATH}/../tools/MOATS2seconds.sh ${BIRTHDATE})
    SNOW=$(${MY_PATH}/../tools/MOATS2seconds.sh ${MOATS})
    DIFF_SECONDS=$(( SNOW - SBIRTH ))
    days=$((DIFF_SECONDS / 60 / 60 / 24))

    echo "ASTROPORT ZenStation : ${ASTROPORT}"
    echo "TW was created $days days ago"
    ## REMOVE TW OLDER THAN 7 DAYS WITH AstroID
    [[ -s ~/.zen/tmp/${MOATS}/AstroID.json && $days -gt 7 && ( $COINS == "null" || $ZEN -le 10 ) ]] \
        && ${MY_PATH}/PLAYER.unplug.sh  "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}" "ALL" \
        && echo "(#__#) AstroID SECURITY ERROR (#__#)" && continue

    echo "CURCHAIN=${CURCHAIN}"
    IPNSTAIL=$(echo ${ASTROPORT} | rev | cut -f 1 -d '/' | rev) # Remove "/ipns/" part
    ########### ASTROPORT is not IPFSNODEID => EJECT TW
    if [[ ${IPNSTAIL} != ${IPFSNODEID} || ${IPNSTAIL} == "_ASTROPORT_" ]]; then
        echo "> PLAYER MOVED TO ${IPNSTAIL} : UNPLUG "
        ${MY_PATH}/PLAYER.unplug.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}" "ONE"
        echo ">>>> CIAO ${PLAYER}"
        continue
    fi


    ######################################
    #### UPLANET GEO COORD EXTRACTION
    ## GET "GPS" TIDDLER - 0.00 0.00 (if empty: null)
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
    LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
                [[ $LAT == "null" || $LAT == "" ]] && LAT="0.00"
    LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
                [[ $LON == "null" || $LON == "" ]] && LON="0.00"

    SECTOR="_${LAT::-1}_${LON::-1}"
    ## CALCULATE UMAP TODATENS ################
    ######################################
    ipfs key rm "temp" >/dev/null 2>&1
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/todate.ipfskey "${TODATE}${UPLANETNAME}${LAT}" "${TODATE}${UPLANETNAME}${LON}"
    UMAPNS=$(ipfs key import "temp" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/todate.ipfskey)

    cat ~/.zen/tmp/${MOATS}/GPS.json | jq '.[0] + {"umap": "/ipns/_UMAPNS_"}' \
        > ~/.zen/tmp/${MOATS}/GPStw.json \
        && mv ~/.zen/tmp/${MOATS}/GPStw.json ~/.zen/tmp/${MOATS}/GPS.json
    sed -i "s~_UMAPNS_~${UMAPNS}~g" ~/.zen/tmp/${MOATS}/GPS.json
        ###################################### INJECT JSON

    #~ cat ~/.zen/tmp/${MOATS}/GPS.json
    echo "UMAP _${LAT}_${LON} UMAPNS=/ipns/${UMAPNS}"

    ## CALCULATE SECTOR TODATENS ################
    ipfs key rm "temp" >/dev/null 2>&1
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/sectodate.ipfskey "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}"
    TODATESECTORNS=$(ipfs key import "temp" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/sectodate.ipfskey)

    cat ~/.zen/tmp/${MOATS}/GPS.json | jq '. + {"sectortw": "_SECTORTW_"}' \
        > ~/.zen/tmp/${MOATS}/GPSsec.json \
        && mv ~/.zen/tmp/${MOATS}/GPSsec.json ~/.zen/tmp/${MOATS}/GPS.json
    sed -i "s~_SECTORTW_~/ipns/${TODATESECTORNS}/TW~g" ~/.zen/tmp/${MOATS}/GPS.json
        ###################################### INJECT JSON

    ######################################
    # (RE)MAKE "SECTORTW_NEWS" TIDDLER
    cat ${MY_PATH}/../templates/data/SECTORTW_NEWS.json \
        | sed -e "s~_SECTOR_~${SECTOR}~g" \
        -e "s~_MOATS_~${MOATS}~g" \
        -e "s~_SECTORTW_~/ipns/${TODATESECTORNS}/TW~g" \
            > ~/.zen/tmp/${MOATS}/SECTORTW_NEWS.json

    echo "SECTOR $SECTOR SECTORTW=/ipns/${TODATESECTORNS}/TW"


    ################# PERSONAL VDO.NINJA ADDRESS)
    PHONEBOOTH=${PLAYER/@/_}
    PHONEBOOTH=${PHONEBOOTH/\./_}

    # MAKE "ALLO" TIDDLER
    cat ${MY_PATH}/../templates/data/ALLO.json \
        | sed -e "s~_IPFSNINJA_~${VDONINJA}~g" \
        -e "s~_MOATS_~${MOATS}~g" \
        -e "s~_PHONEBOOTH_~${PHONEBOOTH}~g" \
            > ~/.zen/tmp/${MOATS}/ALLO.json

    ipfs key rm "temp" >/dev/null 2>&1

    ## UPDATE PLAYER CACHE
    echo "_${LAT}_${LON}" > ~/.zen/game/players/${PLAYER}/.umap
    cp ~/.zen/tmp/${MOATS}/GPS.json ~/.zen/game/players/${PLAYER}/

    #####################################################################
    # (RE)MAKE "CESIUM" TIDDLER
    echo "Create CESIUM Tiddler"
    cat ${MY_PATH}/../templates/data/CESIUM.json \
        | sed -e "s~_G1PUB_~${G1PUB}~g" \
        -e "s~_MOATS_~${MOATS}~g" \
        -e "s~_CESIUMIPFS_~${CESIUMIPFS}~g" \
        -e "s~_PLAYER_~${PLAYER}~g" \
            > ~/.zen/tmp/${MOATS}/CESIUM.json

    #####################################################################
    ########## $:/moa picture ## lightbeams replacement ###############
    ## GET $:/moa Tiddlers ####################################### START
    echo "GET $:/moa Tiddlers"
    ###################################################### [tag[$:/moa]]
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'FRIENDS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[$:/moa]]'  ## $:/moa EMAIL Tiddlers
    #####################################################################
    fplayers=($(cat ~/.zen/tmp/${MOATS}/FRIENDS.json | jq -rc .[].title))
    echo "${fplayers[@]}"
    INPUTPLAYERS=()
    for fp in ${fplayers[@]}; do

        [[ ! "${fp}" =~ ^[a-zA-Z0-9.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]] && echo "BAD ${fp} FORMAT" && continue
        [[ "${fp}" == "${PLAYER}" ]] && echo "IT'S ME - CONTINUE" && continue

        FPLAYER=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .player')
        [[ $FPLAYER == 'null' || $FPLAYER == '' ]] && echo "FPLAYER null - CONTINUE" && continue

        FTW=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .tw')
        [[ ${FTW} == "/ipns/" && ${FTW} == "null" && ${FTW} == "" ]] && echo "WEIRD FTW ${FTW} - CONTINUE" && continue

        FG1PUB=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .g1pub')
        [[ $FG1PUB == 'null' || $FG1PUB == '' ]] && echo "FG1PUB null - CONTINUE" && continue

        IHASH=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .text' | sha256sum | cut -d ' ' -f 1)

        echo ":: coucou :: $FPLAYER :: (ᵔ◡◡ᵔ) ::"
        echo "TW: $FTW"
        echo "G1: $FG1PUB"
        echo "IHASH: $IHASH"

        ## GET ORIGINH FROM LAST KNOWN TW STATE
        mkdir -p ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}
        if [[ -s ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}/index.html ]]; then
            rm -f ~/.zen/tmp/${MOATS}/forigin.json
            tiddlywiki --load ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}/index.html \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' "${FPLAYER}.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '${FPLAYER}' ## GET ORIGIN

            ORIGINH=$(cat ~/.zen/tmp/${MOATS}/${FPLAYER}.json  | jq -r '.[].text' | sha256sum | cut -d ' ' -f 1)
            echo "ORIGINH: $ORIGINH"
        fi

        ( ## REFRESH LOCAL PLAYER CACHE with FRIEND ACTUAL TW (&)
            ipfs --timeout 180s cat ${FTW} > ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}/index.html
        ) &

        ## CHECK ALREADY IN ${FPLAYER^^} IHASH
        rm -f ~/.zen/tmp/${MOATS}/finside.json
        tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'finside.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '${FPLAYER^^}'  ## ${FPLAYER^^} autoload Tiddlers

        INSIDEH=$(cat ~/.zen/tmp/${MOATS}/finside.json  | jq -rc '.[].ihash')
        echo "INSIDEH: $INSIDEH"

        ## UPDATE IF IHASH CHANGED -> New drawing => Friend get informed
        if [[ -z $INSIDEH || $INSIDEH != $IHASH || $ORIGINH != $INSIDEH ]]; then
            cat ${MY_PATH}/../templates/data/_UPPERFPLAYER_.json \
                | sed -e "s~_UPPERFPLAYER_~${FPLAYER^^}~g" \
                -e "s~_FPLAYER_~${FPLAYER}~g" \
                -e "s~_MOATS_~${MOATS}~g" \
                -e "s~_IHASH_~${IHASH}~g" \
                -e "s~_FRIENDTW_~${FTW}~g" \
                -e "s~_PLAYER_~${PLAYER}~g" \
                    > ~/.zen/tmp/${MOATS}/${FPLAYER^^}.json

            echo "Insert New ${FPLAYER^^}.json"
            #~ cat ~/.zen/tmp/${MOATS}/${FPLAYER^^}.json | jq

            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --import ${HOME}/.zen/tmp/${MOATS}/${FPLAYER^^}.json 'application/json' \
                --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} \
                --render "$:/core/save/all" "newindex.html" "text/plain"
            [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]] \
                && cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                && rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html \
                || echo "ERROR - CANNOT CREATE TW NEWINDEX - ERROR"

            if [[ $ORIGINH != $INSIDEH ]]; then
                echo "ORIGINH Update"
                rm -f ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html
                tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                    --import ${HOME}/.zen/tmp/${MOATS}/${FPLAYER}.json 'application/json' \
                    --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} \
                    --render "$:/core/save/all" "newindex.html" "text/plain"
                [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]] \
                    && cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                    && rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html \
                    || echo "ERROR - CANNOT CREATE TW NEWINDEX - ERROR"
            fi
        fi

    done

    ## FRIENDS TW FLUX TO IMPORT
    #####################################################################
    ## GET $:/moa Tiddlers ####################################### END
    #####################################################################

    #############################################################
    # Connect_PLAYER_To_Gchange.sh : Sync FRIENDS TW - TODO : REWRITE
    ##############################################################
    #~ echo "##################################################################"

    #~ [[ $(echo "$COINS >= 500" | bc -l) -eq 1 ]]  \
        #~ && echo "## Connect_PLAYER_To_Gchange.sh" \
        #~ && ${MY_PATH}/../tools/Connect_PLAYER_To_Gchange.sh "${PLAYER}" \
        #~ || echo "$COINS <= 1 G1 + 10 ẑen : bypass Gchange stars exchange (★★★★★)"

    ##############################################################
    # G1PalPay - 2 G1 mini -> Check for G1 TX incoming comments #
    ##############################################################
    if [[ $(echo "$COINS >= 2" | bc -l) -eq 1 ]]; then
        ##############################################################
        # G1PalPay.sh #
        ##############################################################
        echo "## RUNNING G1PalPay Wallet Monitoring "
        ${MY_PATH}/G1PalPay.sh ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "${PLAYER}"

        ##############################################################
        # VOEUX.create.sh #
        ##############################################################
        ${MY_PATH}/VOEUX.create.sh ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "${PLAYER}" "${G1PUB}"

        ##############################################################
        # VOEUX.refresh.sh #
        ##############################################################
        ${MY_PATH}/VOEUX.refresh.sh "${PLAYER}" "${MOATS}" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

    else
        echo "> ZenCard not activated ($ZEN ZEN)"
    fi

    ###################
    # REFRESH PLAYER_feed KEY
    ##################################
    #~ echo "# TW : GW API + LightBeam Feed + Friends"
    #~ TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)

    # WRITE lightbeam params
    #~ echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-name","text":"'${PLAYER}_feed'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-name.json
    #~ echo '[{"title":"$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key","text":"'${FEEDNS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/lightbeam-key.json

                #~ --import ~/.zen/tmp/${MOATS}/lightbeam-name.json "application/json" \
                #~ --import ~/.zen/tmp/${MOATS}/lightbeam-key.json "application/json" \
    ###########################
    # UPDATE GW & API
    #~ echo '[{"title":"$:/ipfs/saver/api/http/localhost/5001","tags":"$:/ipfs/core $:/ipfs/saver/api","text":"'$(myPlayerApiGw)'"}]' > ~/.zen/tmp/${MOATS}/5001.json
    #~ echo '[{"title":"$:/ipfs/saver/gateway/http/localhost","tags":"$:/ipfs/core $:/ipfs/saver/gateway","text":"'$myIPFS'"}]' > ~/.zen/tmp/${MOATS}/8080.json

    ## COPY DATA PRODUCED BY GCHANGE STAR EXTRACTION
    #~ FRIENDSFEEDS=$(cat ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/FRIENDSFEEDS 2>/dev/null)
    #~ echo "★★★★★ FRIENDS  FEEDS : "${FRIENDSFEEDS}
    #~ ASTRONAUTES=$(cat ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/ASTRONAUTES 2>/dev/null)
    #~ echo "★★★★★ FRIENDS TW : "${ASTRONAUTES}

    ## Change TW FRIENDFEED ie PLAYER RSS IPNS (must fix TW plugin to work)
    #~ echo '[{"title":"$:/plugins/astroport/lightbeams/state/subscriptions","text":"'${FRIENDSFEEDS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/friends.json
    #~ ## ADD              --import "$HOME/.zen/tmp/${MOATS}/friends.json" "application/json" \ ## MANUAL TW RSS REGISTRATION

    ## PATCH : RESTORE PLAYER GPS.json (protect cache erased by WISH treatment)
    cp -f ~/.zen/game/players/${PLAYER}/GPS.json ~/.zen/tmp/${MOATS}/
    ## WRITE TIDDLERS IN TW SECTORTW_NEWS.json
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --import ~/.zen/tmp/${MOATS}/GPS.json "application/json" \
                --import ~/.zen/tmp/${MOATS}/ALLO.json "application/json" \
                --import ~/.zen/tmp/${MOATS}/CESIUM.json "application/json" \
                --import ~/.zen/tmp/${MOATS}/SECTORTW_NEWS.json "application/json" \
                --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} --render "$:/core/save/all" "newindex.html" "text/plain"

    ## CHECK IT IS OK
    [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]] \
        && cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        && rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html \
        || echo "ERROR - CANNOT CREATE TW NEWINDEX - ERROR"
    ###########################

    ####################
    ## TW NEWINDEX .... #####
    ##############################################################
    echo "LOCAL BACKUP + MICROLEDGER TW"
    cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    [[ -s ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain ]] \
    && ZCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain) \
    && echo "# CHAIN : ${CURCHAIN} -> ${ZCHAIN}" \
    && [[ ${CURCHAIN} != "" && ${ZCHAIN} != "" ]]  \
    && sed -i "s~${CURCHAIN}~${ZCHAIN}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    ##################################################
    ######## UPDATING ${PLAYER}/ipfs/moa/.chain
    cp ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain \
       ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats)

    ##########################################
    ## IPFS ADD & PUBLISH
    ##########################################
    TW=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    ipfs --timeout 720s name publish --key=${PLAYER} /ipfs/${TW}

    ## LOCAL PLAYER CACHING
    echo ${TW} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain
    echo ${MOATS} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats

    echo "================================================"
    echo " NEW TW ${PLAYER} : =  ${myIPFS}/ipfs/${TW}"
    echo "  $myIPFSGW/ipns/${ASTRONAUTENS}"
    echo "================================================"

    echo "(☉_☉ ) (☉_☉ ) (☉_☉ ) RSS"
    ## CREATING 30 DAYS JSON RSS STREAM
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/game/players/${PLAYER}/ipfs \
        --render '.' "${PLAYER}.rss.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-30]!is[system]!tag[G1Voeu]!externalTiddler[yes]!tag[load-external]]'

    [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json ]] \
        && echo "NO ${PLAYER} RSS - BAD "

    echo "~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json"

    ## TODO CREATING 30 DAYS XML RSS STREAM
    ## https://talk.tiddlywiki.org/t/has-anyone-generated-an-rss-feed-from-tiddlywiki/966/26
    # tiddlywiki.js --load my-wiki.html --render "[[$:/plugins/sq/feeds/templates/rss]]" "feed.xml" "text/plain" "$:/core/templates/wikified-tiddler"
    ### $:/plugins/sycom/atom-feed/atom.xml
    #~ tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        #~ --output ~/.zen/game/players/${PLAYER}/ipfs --render '.' "${PLAYER}.rss.xml" 'text/plain' "$:/core/templates/wikified-tiddler" 'exportFilter' '[days:created[-30]!is[system]!tag[G1Voeu]]'

    ########################################
    #### PLAYER ACCOUNT IS ACTIVE ? #########
    if [[ $(cat ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json) == "[]" ]]; then
        echo "RSS IS EMPTY -- COINS=$COINS / ZEN=$ZEN --"
        ## DEAD PLAYER ??
        if [[ $(echo "$COINS < 2.1" | bc -l) -eq 1 ]]; then
            if [[ ${DIFF_SECONDS} -eq $(( 27 * 24 * 60 * 60 )) ]]; then
                echo "<html><body><h1>WARNING.</h1> Your TW will be UNPLUGGED and stop being published..." > ~/.zen/tmp/alert
                echo "<br><h3>TW : <a href=$(myIpfsGw)/ipfs/${CURCHAIN}> ${PLAYER}</a></h3> ADD MORE ZEN ($ZEN) </body></html>" >> ~/.zen/tmp/alert

                ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/alert "TW ALERT"
                echo "<<<< PLAYER TW WARNING <<<< ${DIFF_SECONDS} > ${days} days"
            fi
            if [[ ${DIFF_SECONDS} -gt $(( 29 * 24 * 60 * 60 )) ]]; then
                echo ">>>> PLAYER TW UNPLUG >>>>> ${days} days => BYE BYE ${PLAYER} ZEN=$ZEN"
                ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${PLAYER} "ALL"
                continue
            fi
        fi
    else
    ### PUBLISH RSS &
        FEEDNS=$(ipfs key list -l | grep -w "${PLAYER}_feed" | cut -d ' ' -f 1)
        [[ ! ${FEEDNS} ]] \
            && IRSS=$(ipfs add -q ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json | tail -n 1) \
            && ipfs --timeout 180s name publish --key="${PLAYER}_feed" /ipfs/${IRSS} & \
            || echo ">>>>> ERROR ${PLAYER}_feed IPNS KEY NOT FOUND - ERROR"

    fi

    #################################### UNPLUG ACCOUNT




    ######################### REPLACE TW with REDIRECT to latest IPFS or IPNS (reduce 12345 cache size)
    [[ ! -z ${TW} ]] && TWLNK="/ipfs/${TW}" || TWLNK="/ipns/${ASTRONAUTENS}"
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${TWLNK}'\" />${PLAYER}" \
                > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${IRSS}'\" />${PLAYER}" \
                > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}.feed.html

    #################################################
    ################### COPY DATA TO UP LEVEL GRIDS
    #################################################
    if [[ ${LAT} && ${LON} ]]; then
        ## SECTOR BANK COORD
        SECLAT="${LAT::-1}"
        SECLON="${LON::-1}"
        ## REGION
        REGLAT=$(echo ${LAT} | cut -d '.' -f 1)
        REGLON=$(echo ${LON} | cut -d '.' -f 1)

        echo "/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}"
        ## IPFSNODEID 12345 CACHE UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/RSS/

        cp ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json \
                ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/RSS/

        ${MY_PATH}/../tools/json_dir.all.sh \
            ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/RSS/

        mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/TW/${PLAYER}
        ## IPFS PLAYER TW #
        # /ipfs/${TW}
        echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${TW}'\" />${TODATE}:${PLAYER}" \
                > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/TW/${PLAYER}/index.html
        # /ipns/${ASTRONAUTENS}
        echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${ASTRONAUTENS}'\" />${PLAYER}" \
                > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/TW/${PLAYER}/_index.html
        ## IPNS UMAP _index.html ##
        echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${UMAPNS}'\" />${TODATE}:_${LAT}_${LON}" \
                > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/_index.html

        ## IF PLAYER INACTIVE PAY 1 ZEN TO UMAPG1PUB
        [[ $(cat ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json) == "[]" ]] \
            && UMAPG1PUB=$(${MY_PATH}/../tools/keygen "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}") \
            && YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${PLAYER}") \
            && ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "0.1" "${UMAPG1PUB}" "UPLANET:TW:${YOUSER}:/ipfs/${TW}"

    fi

    ls -al ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON} 2>/dev/null
    echo "(☉_☉ ) (☉_☉ ) (☉_☉ )"

    ## MAINTAIN R/RW TW STATE
    [[ ${ASTRONS} == "" ]] \
    && echo "${PLAYER} DISCONNECT" \
    && ipfs key rm ${PLAYER} \
    && ipfs key rm ${PLAYER}_feed \
    && ipfs key rm ${G1PUB}

    ## CLEANING CACHE
    rm -Rf ~/.zen/tmp/${MOATS}
    echo

    end=`date +%s`
    dur=`expr $end - $start`
    echo "${PLAYER} refreshing took $dur seconds (${MOATS})"

done
echo "============================================ PLAYER.refresh DONE."

exit 0
