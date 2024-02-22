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

echo "RENEWING UPLANET NODE CACHE
 ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??"
rm -Rf ~/.zen/tmp/${IPFSNODEID}/UPLANET
mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET
echo "CLEANING TW NODE CACHE ~/.zen/tmp/${IPFSNODEID}/TW/"
rm -Rf ~/.zen/tmp/${IPFSNODEID}/TW/

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in ${PLAYERONE[@]}; do
    [[ ! -d ~/.zen/game/players/${PLAYER:-undefined} ]] && echo "BAD ${PLAYERONE}" && continue
    [[ ! $(echo "${PLAYER}" | grep '@') ]] && continue

    # CLEAN LOST ACCOUNT
    [[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] \
        && rm -Rf ~/.zen/game/players/${PLAYER} \
        && echo "${PLAYER} WAS BADLY PLUGGED" \
        && continue

    ### UPGRADE PLAYER for myos IPFS API ### DOUBLON WITH VISA.new (TO REMOVE)
    mkdir -p ~/.zen/game/players/${PLAYER}/.ipfs # Prepare PLAYER datastructure
    echo "/ip4/127.0.0.1/tcp/5001" > ~/.zen/game/players/${PLAYER}/.ipfs/api
    ######## WORK IN PROGRESS #### myos integration

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}
    echo "##################################################################"
    echo "##################################################################"
    echo ">>>>> PLAYER : ${PLAYER} >>>>>>>>>>>>> REFRESHING TW STATION"
    echo "##################################################################"
    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)
    # Get PLAYER wallet amount
    $MY_PATH/../tools/COINScheck.sh $G1PUB > ~/.zen/tmp/g1reveal
    cat ~/.zen/tmp/g1reveal ###DEBUG MODE
    COINS=$(cat ~/.zen/tmp/g1reveal | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    echo "+++ WALLET BALANCE _ $COINS (G1) _ / $ZEN ZEN /"

    #~ ## ZENCARD ARE ACTIVATED WITH 1 G1 + 10 ZEN (= 1 €OC) ?
    echo "##################################################################"
    echo "################### REFRESH ASTRONAUTE TW ###########################"
    echo "##################################################################"

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${G1PUB} | cut -d ' ' -f1)

    if [[ ! ${ASTRONAUTENS} ]]; then

        echo "${PLAYER} TW IS DISCONNECTED... RECREATING IPNS KEYS"

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

    ipfs --timeout 480s get -o ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html /ipns/${ASTRONAUTENS}

    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ]; then

        NOWCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain)
        LASTCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.* | tail -n 1)
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx<br>"
        echo "<a href='$myIPFS/ipns/${ASTRONAUTENS}'>TW REFRESH FAILED</a>"
        echo ">> %%% WARNING %%%"
        echo "------------------------------------------------"
        echo " * <a href='${myIPFS}/ipfs/${LASTCHAIN}'>LAST</a>"
        echo " *<a href='${myIPFS}/ipfs/${NOWCHAIN}'>NOW</a>"
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        ## SEND AN EMAIL ALERT TO PLAYER
        echo "<html><body><a href='$myIPFS/ipns/${ASTRONAUTENS}'>TW REFRESH FAILED</a>" > ~/.zen/tmp/result
        echo "<br>------------------------------------------------" >> ~/.zen/tmp/result
        echo "" >> ~/.zen/tmp/result
        echo "<br><a href='${myIPFS}/ipfs/${LASTCHAIN}'>ANCIENT</a>" >> ~/.zen/tmp/result
        echo "<br><a href='${myIPFS}/ipfs/${NOWCHAIN}'>NEW</a>" >> ~/.zen/tmp/result
        echo "" >> ~/.zen/tmp/result
        echo "<br> %%% WARNING %%%" >> ~/.zen/tmp/result
        echo "<br>------------------------------------------------" >> ~/.zen/tmp/result
        echo "<br>PLEASE REPAIR BY SAVING ONLINE</body></html>" >> ~/.zen/tmp/result
        echo "OR RUNNING CLI COMMAND : ipfs name publish --key=${PLAYER} /ipfs/${NOWCHAIN}" >> ~/.zen/tmp/result

        try=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.try 2>/dev/null) || try=3

        [[ $try == 0 ]] \
            && echo "PLAYER ${PLAYER} UNPLUG" \
            && ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${PLAYER} \
            && continue

        try=$((try-1))
        echo "$try" > ~/.zen/game/players/${PLAYER}/ipfs/moa/.try
        echo " %%% WARNING %%%  ${PLAYER} STATION UNPLUG IN $try DAY(S)." >> ~/.zen/tmp/result
        $MY_PATH/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/result "UNPLUG WARNING"

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

            [[ ${player} != ${PLAYER} ]] \
                && echo "> BAD PLAYER=$player in TW" \
                && continue \
                || echo "${PLAYER} OFFICIAL TW - (⌐■_■) -"

            ## GET "Astroport" TIDDLER
            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'  ## Astroport Tiddler
            BIRTHDATE=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].birthdate)
            ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport) ## Raccorded G1Station IPNS address
            CURCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].chain | rev | cut -f 1 -d '/' | rev) # Remove "/ipfs/" part
            [[ ${CURCHAIN} == "" ||  ${CURCHAIN} == "null" ]] \
                &&  CURCHAIN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" # AVOID EMPTY

            echo "CURCHAIN=${CURCHAIN}"
            IPNSTAIL=$(echo ${ASTROPORT} | rev | cut -f 1 -d '/' | rev) # Remove "/ipns/" part
            echo "TW ASTROPORT GATEWAY : ${ASTROPORT}"

            ######################################
            #### UPLANET GEO COORD EXTRACTION
            ## GET "GPS" TIDDLER - 0.00 0.00 (if empty: null)
            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
            UMAPNS=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].umap)
                        [[ $UMAPNS == "null" || $UMAPNS == "" ]] && UMAPNS="/ipns/k51qzi5uqu5djg1gqzujq5p60w25mi235gdg0lgkk5qztkfrpi5c22oolrriyu"
            LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
                        [[ $LAT == "null" || $LAT == "" ]] && LAT="0.00"
            LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
                        [[ $LON == "null" || $LON == "" ]] && LON="0.00"

            echo "LAT=${LAT}; LON=${LON}; UMAPNS=${UMAPNS}"

            ## TODATENS ################
            TODATENS=$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${LAT}" "${TODATE}${UPLANETNAME}${LON}")
            echo "GPS UMAP LINK UPDATE
            ${YESTERDATE} : ${myIPFS}${UMAPNS}
            ${TODATE} : ${myIPFS}/ipns/${TODATENS}"
            ## UPDATE TW GPS Tiddler #############
            sed -i "s~${UMAPNS}~/ipns/${TODATENS}~g" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

            ## STORE IN PLAYER CACHE
            echo "_${LAT}_${LON}" > ~/.zen/game/players/${PLAYER}/.umap
            cp ~/.zen/tmp/${MOATS}/GPS.json ~/.zen/game/players/${PLAYER}/

            ########### ASTROPORT is not IPFSNODEID => EJECT TW
            ## MOVED PLAYER (KEY IS KEPT ON LAST CONNECTED ASTROPORT)
            ## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            ## TODO UNPLUG PLAYER
            ## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            if [[ ${IPNSTAIL} != ${IPFSNODEID} || ${IPNSTAIL} == "_ASTROPORT_" ]]; then
                echo "> I AM ${IPFSNODEID}  :  PLAYER MOVED TO ${IPNSTAIL} : EJECTION "
                echo "UNPLUG PLAYER"
                ${MY_PATH}/PLAYER.unplug.sh  "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}" "ONE"
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

    [[ $(echo "$COINS >= 2" | bc -l) -eq 1 ]]  \
        && echo "## Connect_PLAYER_To_Gchange.sh" \
        && ${MY_PATH}/../tools/Connect_PLAYER_To_Gchange.sh "${PLAYER}" \
        || echo "1 G1 + 10 ẑen needed to activate ★★★★★ system"

    # G1PalPay - 1 G1 mini -> Check for G1 TX incoming comments #
    if [[ $(echo "$COINS >= 1" | bc -l) -eq 1 ]]; then
        ###########
        # G1PalPay.sh #
        ##############################################################
        echo "## RUNNING G1PalPay Wallet Monitoring "
        ${MY_PATH}/G1PalPay.sh ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "${PLAYER}"

        ###############
        # VOEUX.create.sh #
        ##############################################################
        ${MY_PATH}/VOEUX.create.sh ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "${PLAYER}" "${G1PUB}"

        ###############
        # VOEUX.refresh.sh #
        ##############################################################
        ${MY_PATH}/VOEUX.refresh.sh "${PLAYER}" "${MOATS}" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

    else
        echo "> ZenCard is not activated ($ZEN)"
    fi
    ### CHECK FOR pending (TODO! In case PAY4SURE have abandonned pendings)



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
    echo "★★★★★ FRIENDS  FEEDS : "${FRIENDSFEEDS}
    ASTRONAUTES=$(cat ~/.zen/tmp/${IPFSNODEID}/RSS/${PLAYER}/ASTRONAUTES 2>/dev/null)
    echo "★★★★★ FRIENDS TW : "${ASTRONAUTES}

    ## Change TW FRIENDFEED ie PLAYER RSS IPNS (must fix TW plugin to work)
    #~ echo '[{"title":"$:/plugins/astroport/lightbeams/state/subscriptions","text":"'${FRIENDSFEEDS}'","tags":""}]' > ~/.zen/tmp/${MOATS}/friends.json
    #~ ## ADD              --import "$HOME/.zen/tmp/${MOATS}/friends.json" "application/json" \ ## MANUAL TW RSS REGISTRATION

    ## WRITE TIDDLERS IN TW
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --import ~/.zen/tmp/${MOATS}/lightbeam-name.json "application/json" \
                --import ~/.zen/tmp/${MOATS}/lightbeam-key.json "application/json" \
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
    else
        ## COUNT NO CHANGE
        try=$(cat ~/.zen/game/players/${PLAYER}/ipfs/_nochange 2>/dev/null) || try=0
        ((try++)) && echo $try > ~/.zen/game/players/${PLAYER}/ipfs/_nochange
        echo "NO CHANGE $try TIMES"
    fi
    ##############################################################

    ##################################################
    ############################### LOCAL "MICRO LEDGER"
    ################## UPDATING ${PLAYER}/ipfs/moa
    [[ $DIFF ]] && cp   ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain \
                                    ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --key=${PLAYER} /ipfs/${TW}

    [[ $DIFF ]] && echo ${TW} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain

    echo ${MOATS} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats

    echo "================================================"
    echo " NEW TW ${PLAYER} : =  ${myIPFS}/ipfs/${TW}"
    echo "  $myIPFSGW/ipns/${ASTRONAUTENS}"
    echo "================================================"

    echo "(☉_☉ ) (☉_☉ ) (☉_☉ ) RSS"
    ## CREATING 30 DAYS JSON RSS STREAM
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                        --output ~/.zen/game/players/${PLAYER}/ipfs --render '.' "${PLAYER}.rss.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-30]!is[system]!tag[G1Voeu]]'

    [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json ]] \
        && echo "NO ${PLAYER} RSS - BAD "

    echo "~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json"

    ## TODO CREATING 30 DAYS XML RSS STREAM
    ## https://talk.tiddlywiki.org/t/has-anyone-generated-an-rss-feed-from-tiddlywiki/966/26
    # tiddlywiki.js --load my-wiki.html --render "[[$:/plugins/sq/feeds/templates/rss]]" "feed.xml" "text/plain" "$:/core/templates/wikified-tiddler"
    ### $:/plugins/sycom/atom-feed/atom.xml
    #~ tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                        #~ --output ~/.zen/game/players/${PLAYER}/ipfs --render '.' "${PLAYER}.rss.xml" 'text/plain' "$:/core/templates/wikified-tiddler" 'exportFilter' '[days:created[-30]!is[system]!tag[G1Voeu]]'

    SBIRTH=$(${MY_PATH}/../tools/MOATS2seconds.sh ${BIRTHDATE})
    SNOW=$(${MY_PATH}/../tools/MOATS2seconds.sh ${MOATS})
    DIFF_SECONDS=$(( SNOW - SBIRTH ))
    days=$((DIFF_SECONDS / 60 / 60 / 24))
    echo "PLAYER TW was created $days days ago"

    ##################################
    #### PLAYER ACCOUNT CLEANING #########
    ## IF ZEN < 11
    ## && EMPTY RSS + 30 DAYS BIRTHDATE
    ## only for less 90 days TW ? && ${DIFF_SECONDS} -lt $(( 90 * 24 * 60 * 60 )) ????
    ## ==> UNPLUG
    [[ $(cat ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json) == "[]" ]] \
        && echo "RSS IS EMPTY -- COINS=$COINS / ZEN=$ZEN --" \
        && [[ $(echo "$COINS < 2.1" | bc -l) -eq 1 ]] \
        && [[ ${DIFF_SECONDS} -gt $(( 27 * 24 * 60 * 60 )) ]] \
        && echo "<html><body><h1>WARNING.</h1>  Your TW will be UNPLUGGED and stop being published..." > ~/.zen/tmp/alert \
        && echo "<br><h3>TW : <a href=$(myIpfsGw)/ipfs/${CURCHAIN}> ${PLAYER}</a></h3>ZEN=$ZEN </body></html>" >> ~/.zen/tmp/alert \
        && ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/alert "TW ALERT" \
        && echo "<<<< PLAYER TW WARNING <<<< ${DIFF_SECONDS} > ${days} days" \
        && [[ ${DIFF_SECONDS} -gt $(( 30 * 24 * 60 * 60 ))  ]] \
        && echo ">>>> PLAYER TW UNPLUG >>>>> ${days} days => BYE BYE ${PLAYER} ZEN=$ZEN" \
        && ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${PLAYER} \
        && continue
    #################################### UNPLUG ACCOUNT

    IRSS=$(ipfs add -q ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json | tail -n 1) \
    && ipfs name publish --key="${PLAYER}_feed" /ipfs/${IRSS}

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

        ${MY_PATH}/../tools/json_dir.all.sh ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/RSS/
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/TW/${PLAYER}
        cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/TW/${PLAYER}/

        echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${TODATENS}'\" />" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${REGLAT}_${REGLON}/_${SECLAT}_${SECLON}/_${LAT}_${LON}/_index.html

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

done
echo "============================================ PLAYER.refresh DONE."

exit 0
