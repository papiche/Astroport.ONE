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
## SEEK FOR UPLANET KEYS
# GET & UPDATE IPNS
############################################
echo "## RUNNING UPLANET.refresh"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir ~/.zen/tmp/${MOATS}

#################################################################
## IPFSNODEID ASTRONAUTES SIGNALING ## 12345 port
############################
    ## RUNING FOR ALL UMAP FOUND IN STATION MAP CACHE : "_LAT_LON"

    ## SEARCH UMAP (created by PLAYER.refresh.sh)
    UMAPS=($(ls -t ~/.zen/tmp/${IPFSNODEID}/UPLANET/ 2>/dev/null))
    echo "FOUND : ${UMAPS[@]}" # "_LAT_LON" directories

    for UMAP in ${UMAPS[@]}; do

        start=`date +%s`
        echo ">>> REFRESHING ${UMAP}"
        LAT=$(echo ${UMAP} | cut -d '_' -f 2)
        LON=$(echo ${UMAP} | cut -d '_' -f 3)

        [[ $LAT == "" || $LON == "" ]] && echo ">> ERROR BAD $LAT $LON" && continue

        ##############################################################
        WALLET=$(${MY_PATH}/../tools/keygen -t duniter "$LAT" "$LON")
        [[ ! ${WALLET} ]] && echo "ERROR generating WALLET" && exit 1
        echo "ACTUAL UMAP WALLET : ${WALLET}"
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/WALLET.priv "$LAT" "$LON"
        ipfs key rm ${WALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        UMAPNS=$(ipfs key import ${WALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/WALLET.priv)
        ##############################################################

        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        ## IPFS GET ONLINE UMAPNS
        mkdir ~/.zen/tmp/${MOATS}/${UMAP}
        ipfs get -o ~/.zen/tmp/${MOATS}/${UMAP}/ /ipns/${UMAPNS}/
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        ## FORMAT CONTROL WARNING
        [[ ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET} || ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} ]] \
            && echo ">>> WARNING - UMAP IS BAD FORMAT - PLEASE MONITOR KEY -" \
            && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} \
            && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}

        ## UMAP.refresh CORRECTION
        [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresh ]] \
            && echo "${IPFSNODEID}" > ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresh

        ########################################################
        ## NODE  SELECTION in UMAP.refresh
        UREFRESH="${HOME}/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresh"
        ALLNODES=($(cat ${UREFRESH})) # ${ALLNODES[@]}
        STRAPS=($(ipfs bootstrap | rev | cut -f 1 -d'/' | rev)) ## ${STRAPS[@]}
        # STRAPS=($(cat ${MY_PATH}/../A_boostrap_nodes.txt | grep -Ev "#"))

        IAMINBOOTSTRAP=$(echo ${STRAPS[@]} | grep ${IPFSNODEID})
        [[ ! ${IAMINBOOTSTRAP} ]] && ACTINGNODE=$(cat ${UREFRESH} | tail -n 1) ## LAST NODE

        # PRIORITY TO BOOSTRAP
        for NODE in ${ALLNODES[@]}; do
            for STRAP in ${STRAPS[@]}; do
                [[ "$NODE" == "$STRAP" ]] && ACTINGNODE=$(NODE) ## PREFERED 1ST NODE BEING BOOSTRAP
            done
        done

        [[ "${ACTINGNODE}" != "${IPFSNODEID}" ]] \
            && echo ">> ACTINGNODE=${ACTINGNODE} is not ME - NEXT -" \
            && continue

        # SHUFFLE UMAP.refresh
        cat ${UREFRESH} | shuf > ${UREFRESH}.shuf
        mv ${UREFRESH}.shuf ${UREFRESH}
        ######################################################## # NODE  SELECTION in UMAP.refresh

        ##############################################################
        rm ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json
        ##############################################################
    if [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json ]]; then
        ##############################################################
        ## CALCULATE SURROUNDING UMAPS
        ##############################################################
        # North Umap
        NLAT=$(echo "$LAT + 0.01" | bc)
        NLON="$LON"
        NWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$NLAT" "$NLON")
        [[ ! ${NWALLET} ]] && echo "ERROR generating NWALLET" && exit 1
        echo "NORTH UMAP NWALLET : ${NWALLET}"
        ipfs key rm ${NWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NWALLET.priv "$NLAT" "$NLON"
        NUMAPNS=$(ipfs key import ${NWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NWALLET.priv)
        ipfs key rm ${NWALLET}

        ##############################################################
        # South Umap
        SLAT=$(echo "$LAT - 0.01" | bc)
        SLON="$LON"
        SWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$SLAT" "$SLON")
        [[ ! ${SWALLET} ]] && echo "ERROR generating SWALLET" && exit 1
        echo "SOUTH UMAP SWALLET : ${SWALLET}"
        ipfs key rm ${SWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SWALLET.priv "$SLAT" "$SLON"
        SUMAPNS=$(ipfs key import ${SWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SWALLET.priv)
        ipfs key rm ${SWALLET}

        ##############################################################
        # West Umap
        WLAT="$LAT"
        WLON=$(echo "$LON - 0.01" | bc)
        WWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$WLAT" "$WLON")
        [[ ! ${WWALLET} ]] && echo "ERROR generating WWALLET" && exit 1
        echo "WEST UMAP WWALLET : ${WWALLET}"
        ipfs key rm ${WWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/WWALLET.priv "$WLAT" "$WLON"
        WUMAPNS=$(ipfs key import ${WWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/WWALLET.priv)
        ipfs key rm ${WWALLET}

        ##############################################################
        # East Umap
        ELAT="$LAT"
        ELON=$(echo "$LON + 0.01" | bc)
        EWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$ELAT" "$ELON")
        [[ ! ${EWALLET} ]] && echo "ERROR generating EWALLET" && exit 1
        echo "EAST UMAP EWALLET : ${EWALLET}"
        ipfs key rm ${EWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/EWALLET.priv "$ELAT" "$ELON"
        EUMAPNS=$(ipfs key import ${EWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/EWALLET.priv)
        ipfs key rm ${EWALLET}

        ##############################################################
        # South West Umap
        SWLAT=$(echo "$LAT - 0.01" | bc)
        SWLON=$(echo "$LON - 0.01" | bc)
        SWWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$SWLAT" "$SWLON")
        [[ ! ${SWWALLET} ]] && echo "ERROR generating SWWALLET" && exit 1
        echo "SOUTH WEST UMAP SWWALLET : ${SWWALLET}"
        ipfs key rm ${SWWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SWWALLET.priv "$SWLAT" "$SWLON"
        SWUMAPNS=$(ipfs key import ${SWWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SWWALLET.priv)
        ipfs key rm ${SWWALLET}

        ##############################################################
        # North West Umap
        NWLAT=$(echo "$LAT + 0.01" | bc)
        NWLON=$(echo "$LON - 0.01" | bc)
        NWWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$NWLAT" "$NWLON")
        [[ ! ${NWWALLET} ]] && echo "ERROR generating NWWALLET" && exit 1
        echo "NORTH WEST UMAP NWWALLET : ${NWWALLET}"
        ipfs key rm ${NWWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NWWALLET.priv "$NWLAT" "$NWLON"
        NWUMAPNS=$(ipfs key import ${NWWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NWWALLET.priv)
        ipfs key rm ${NWWALLET}

        ##############################################################
        # North East Umap
        NELAT=$(echo "$LAT + 0.01" | bc)
        NELON=$(echo "$LON + 0.01" | bc)
        NEWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$NELAT" "$NELON")
        [[ ! ${NEWALLET} ]] && echo "ERROR generating NEWALLET" && exit 1
        echo "NORTH EAST UMAP NEWALLET : ${NEWALLET}"
        ipfs key rm ${NEWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NEWALLET.priv "$NELAT" "$NELON"
        NEUMAPNS=$(ipfs key import ${NEWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NEWALLET.priv)
        ipfs key rm ${NEWALLET}

        ##############################################################
        # South East Umap
        SELAT=$(echo "$LAT - 0.01" | bc)
        SELON=$(echo "$LON + 0.01" | bc)
        SEWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$SELAT" "$SELON")
        [[ ! ${SEWALLET} ]] && echo "ERROR generating SEWALLET" && exit 1
        echo "SOUTH EAST UMAP SEWALLET : ${SEWALLET}"
        ipfs key rm ${SEWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SEWALLET.priv "$SELAT" "$SELON"
        SEUMAPNS=$(ipfs key import ${SEWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SEWALLET.priv)
        ipfs key rm ${SEWALLET}

        jq -n \
          --arg north "${myIPFS}/ipns/${NUMAPNS}" \
          --arg south "${myIPFS}/ipns/${SUMAPNS}" \
          --arg east "${myIPFS}/ipns/${EUMAPNS}" \
          --arg west "${myIPFS}/ipns/${WUMAPNS}" \
          --arg northeast "${myIPFS}/ipns/${NEUMAPNS}" \
          --arg northwest "${myIPFS}/ipns/${NWUMAPNS}" \
          --arg southeast "${myIPFS}/ipns/${SEUMAPNS}" \
          --arg southwest "${myIPFS}/ipns/${SWUMAPNS}" \
          '{north: $north, south: $south, east: $east, west: $west, northeast: $northeast, northwest: $northwest, southeast: $southeast, southwest: $southwest}' \
          > ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json

    fi

    ### SET navigator.html ## MAKE EVOLVE template/umap.html
        cp ${MY_PATH}/../templates/umap.html ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Umap.html
        cat ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Umap.html | sed "s~Umap~Usat~g" > ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Usat.html

    ### REFRESH PLAYERS DATA (SHOULD BE THERE, but Station rebuilds it )
    # FIND WHICH PLAYERS MATCH SAME "_LAT_LON" IN ~/.zen/game/players/*/.umap
        find ~/.zen/game/players -type f -name ".umap" -exec grep -l "${UMAP}" {} \; | while read umap_file; do
            player_dir=$(dirname "$umap_file")
            player_name=$(basename "$player_dir")
            echo "MATCHING $player_name"
            playertw=$(cat ${player_dir}/.playerns)
            mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/TW/${player_name}
            echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${playertw}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/TW/${player_name}/index.html
        done
        ## COMPLETE WITH SEARCH IN ~/.zen/tmp/swarm/*/UPLANET/${UMAP} ????

        ##############################################################
        ############################ PUBLISHING UMAP
        ##############################################################
        UMAPROOT=$(ipfs add -rwHq ~/.zen/tmp/${MOATS}/${UMAP}/* | tail -n 1)

        ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}/_chain 2>/dev/null)
        ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}/_moats 2>/dev/null)
        [[ ${ZCHAIN} && ${ZMOATS} ]] \
            && cp ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}/_chain ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}/_chain.${ZMOATS} \
            && echo "UPDATING MOATS"

        ## DOES CHAIN CHANGED or INIT ?
        [[ ${ZCHAIN} != ${UMAPROOT} || ${ZCHAIN} == "" ]] \
            && echo "${UMAPROOT}" > ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}/_chain \
            && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}/_moats \
            && UMAPROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/${UMAP}/${WALLET}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"

        echo "PUBLISHING NEW UMAPROOT : http://ipfs.localhost:8080/ipfs/${UMAPROOT}"

            ipfs name publish --key=${WALLET} /ipfs/${UMAPROOT}
            end=`date +%s`
            ipfs key rm ${WALLET} ## REMOVE IPNS KEY

            echo "(UMAP) PUBLISH time was "`expr $end - $start` seconds.

    done

