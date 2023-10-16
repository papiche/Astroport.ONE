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

        [[ ${LAT} == "" || ${LON} == "" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
        [[ ${LAT} == "null" || ${LON} == "null" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue

        ##############################################################
        G1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${LAT}" "${LON}")
        [[ ! ${G1PUB} ]] && echo "ERROR generating WALLET" && exit 1
        echo "ACTUAL UMAP WALLET : ${G1PUB}"
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/WALLET.priv "${LAT}" "${LON}"
        ipfs key rm ${G1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        UMAPNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/WALLET.priv)
        ##############################################################

        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        ## IPFS GET ONLINE UMAPNS
        mkdir ~/.zen/tmp/${MOATS}/${UMAP}
        ipfs get -o ~/.zen/tmp/${MOATS}/${UMAP}/ /ipns/${UMAPNS}/
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        ## FORMAT CONTROL WARNING
        [[ ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB} || ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} ]] \
            && echo ">>> WARNING - UMAP IS BAD FORMAT - PLEASE MONITOR KEY -" \
            && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} \
            && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}

        mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/RSS
        mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/TW


    ## PROTOCOL MIGRATION (TODO REMOVE)
    rm ${HOME}/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresh

 # ++++++++++++++++++++ - - - - ADAPT TO NODE TREATMENT TIME
                ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_moats 2>/dev/null)
                # ZMOATS SHOULD BE MORE THAT 20 HOURS.
                MOATS_SECONDS=$(date -d "$MOATS" +%s)
                ZMOATS_SECONDS=$(date -d "$ZMOATS" +%s)
                DIFF_SECONDS=$((MOATS_SECONDS - ZMOATS_SECONDS))
                    echo "UMAP DATA is ${DIFF_SECONDS} seconds "
                # IF LESS.
                if [ ${DIFF_SECONDS} -lt 72000 ]; then
                    echo "GETTING YESTERDAY UMAP.refresher"
                    ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
                    ## GET UMAP.refresher from PREVIOUS _chain ...
                    ipfs cat /ipfs/${ZCHAIN}/${LAT}_${LON}/UMAP.refresher > ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresher
                fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        ########################################################
        ## NODE  SELECTION in UMAP.refresher
        UREFRESH="${HOME}/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresher"
        ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}

        if [[ ${ALLNODES[@]} == "" ]]; then
            STRAPS=($(ipfs bootstrap | rev | cut -f 1 -d'/' | rev)) ## ${STRAPS[@]}
            for STRAP in ${STRAPS[@]}; do
                    echo ${STRAP} >> ${UREFRESH} ## FILL UMAP.refresher file with all STRAPS
            done
            ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}
        fi

        ACTINGNODE=${ALLNODES[-1]} ## LAST NODE IN UMAP.refresher
        SECTORNODE=${ALLNODES[-2]}
        REGIONNODE=${ALLNODES[-3]}

        echo "* ACTINGNODE=${ACTINGNODE}"
        echo "* SECTORNODE=${SECTORNODE}"
        echo "* REGIONNODE=${REGIONNODE}"

### SECTOR = 0.1° Planet Slice
        ${MY_PATH}/SECTOR.refresh.sh "${LAT}" "${LON}" "${MOATS}" "${UMAP}" "${SECTORNODE}"

 ### REGION = 1° Planet Slice
       ${MY_PATH}/REGION.refresh.sh "${LAT}" "${LON}" "${MOATS}" "${UMAP}" "${REGIONNODE}"

        [[ "${ACTINGNODE}" != "${IPFSNODEID}" ]] \
            && echo ">> ACTINGNODE=${ACTINGNODE} is not ME - CONTINUE -" \
            && rm -Rf ~/.zen/tmp/${MOATS} \
            && continue
            ########################################
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ PASSING THERE MAKE IPFSNODEID UMAP REFRESHER

        ## NEXT REFRESHER
        # TODO: INTRODUCE NODE BALANCE AND CHOOSE THE MOST CONFIDENT ONE
        # SHUFFLE UMAP.refresher
        cat ${UREFRESH} | sort | uniq | shuf  > ${UREFRESH}.shuf
        mv ${UREFRESH}.shuf ${UREFRESH}
        ## NEXT REFRESHER
        echo ">> NEXT REFRESHER WILL BE $(cat ${UREFRESH} | tail -n 1)"
        ######################################################## # NODE  SELECTION in UMAP.refresher


 ## COLLECT RSS FROM ALL PLAYERS WITH SAME UMAP IN SWARM MEMORY
        cp ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/RSS/*.rss.json ~/.zen/tmp/${MOATS}/${UMAP}/RSS/
        RSSFILES=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${LAT}_${LON}/RSS/*.rss.json 2>/dev/null))
        for RSSFILE in ${RSSFILES[@]}; do
            cp -v ${RSSFILE} ~/.zen/tmp/${MOATS}/${UMAP}/RSS/
        done

## COLLECT TW LINKS FOR SWARM
        cp R ~/.zen/tmp/${IPFSNODEID}/UPLANET/_${LAT}_${LON}/TW/* ~/.zen/tmp/${MOATS}/${UMAP}/TW/
        TWFILES=($(ls ~/.zen/tmp/swarm/*/UPLANET/_${LAT}_${LON}/TW/*/index.html 2>/dev/null))
        for TWRED in ${TWFILES[@]}; do
            ZMAIL=$(echo ${TWRED} | rev | cut -d '/' -f 2 | rev)
            mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/TW/${ZMAIL}
            cp -v ${TWRED} ~/.zen/tmp/${MOATS}/${UMAP}/TW/${ZMAIL}/
        done


        ## OSM2IPFS
### UMAP = 0.01° Planet Slice
        UMAPGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01"
        USATGEN="/ipfs/QmRG3ZAiXWvKBccPFbv4eUTZFPMsfXG25PiZQD6N8M8MMM/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01"
        echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/Umap.html
        echo "<meta http-equiv=\"refresh\" content=\"0; url='${USATGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/Usat.html

## ¤$£€
        ## # GET SCREENSHOT UMAP SECTOR & REGION JPG
        ## PROBLEM ON LIBRA ... MORE TEST NEEDED ... TODO
        [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg ]] \
            && python ${MY_PATH}/../tools/page_screenshot.py "${myIPFS}${UMAPGEN}" ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg 900 900 \
            && [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg ]] && killall chrome

        [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg ]] \
            && python ${MY_PATH}/../tools/page_screenshot.py "${myIPFS}${USATGEN}" ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg 900 900 \
            && [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg ]] && killall chrome

        ##############################################################
        ## ERASE FOR ALL NODE PROTOCOL UGRADE
        rm ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json
        ##############################################################
    if [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json ]]; then
        ##############################################################
        ## CALCULATE SURROUNDING UMAPS
        ##############################################################
        # North Umap
        NLAT=$(echo "${LAT} + 0.01" | bc)
        NLON="${LON}"
        NWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$NLAT" "$NLON")
        [[ ! ${NWALLET} ]] && echo "ERROR generating NWALLET" && exit 1
        echo "NORTH UMAP NWALLET : ${NWALLET}"
        ipfs key rm ${NWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NWALLET.priv "$NLAT" "$NLON"
        NUMAPNS=$(ipfs key import ${NWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NWALLET.priv)
        ipfs key rm ${NWALLET}

        ##############################################################
        # South Umap
        SLAT=$(echo "${LAT} - 0.01" | bc)
        SLON="${LON}"
        SWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$SLAT" "$SLON")
        [[ ! ${SWALLET} ]] && echo "ERROR generating SWALLET" && exit 1
        echo "SOUTH UMAP SWALLET : ${SWALLET}"
        ipfs key rm ${SWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SWALLET.priv "$SLAT" "$SLON"
        SUMAPNS=$(ipfs key import ${SWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SWALLET.priv)
        ipfs key rm ${SWALLET}

        ##############################################################
        # West Umap
        WLAT="${LAT}"
        WLON=$(echo "${LON} - 0.01" | bc)
        WWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$WLAT" "$WLON")
        [[ ! ${WWALLET} ]] && echo "ERROR generating WWALLET" && exit 1
        echo "WEST UMAP WWALLET : ${WWALLET}"
        ipfs key rm ${WWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/WWALLET.priv "$WLAT" "$WLON"
        WUMAPNS=$(ipfs key import ${WWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/WWALLET.priv)
        ipfs key rm ${WWALLET}

        ##############################################################
        # East Umap
        ELAT="${LAT}"
        ELON=$(echo "${LON} + 0.01" | bc)
        EWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$ELAT" "$ELON")
        [[ ! ${EWALLET} ]] && echo "ERROR generating EWALLET" && exit 1
        echo "EAST UMAP EWALLET : ${EWALLET}"
        ipfs key rm ${EWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/EWALLET.priv "$ELAT" "$ELON"
        EUMAPNS=$(ipfs key import ${EWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/EWALLET.priv)
        ipfs key rm ${EWALLET}

        ##############################################################
        # South West Umap
        SWLAT=$(echo "${LAT} - 0.01" | bc)
        SWLON=$(echo "${LON} - 0.01" | bc)
        SWWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$SWLAT" "$SWLON")
        [[ ! ${SWWALLET} ]] && echo "ERROR generating SWWALLET" && exit 1
        echo "SOUTH WEST UMAP SWWALLET : ${SWWALLET}"
        ipfs key rm ${SWWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SWWALLET.priv "$SWLAT" "$SWLON"
        SWUMAPNS=$(ipfs key import ${SWWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SWWALLET.priv)
        ipfs key rm ${SWWALLET}

        ##############################################################
        # North West Umap
        NWLAT=$(echo "${LAT} + 0.01" | bc)
        NWLON=$(echo "${LON} - 0.01" | bc)
        NWWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$NWLAT" "$NWLON")
        [[ ! ${NWWALLET} ]] && echo "ERROR generating NWWALLET" && exit 1
        echo "NORTH WEST UMAP NWWALLET : ${NWWALLET}"
        ipfs key rm ${NWWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NWWALLET.priv "$NWLAT" "$NWLON"
        NWUMAPNS=$(ipfs key import ${NWWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NWWALLET.priv)
        ipfs key rm ${NWWALLET}

        ##############################################################
        # North East Umap
        NELAT=$(echo "${LAT} + 0.01" | bc)
        NELON=$(echo "${LON} + 0.01" | bc)
        NEWALLET=$(${MY_PATH}/../tools/keygen -t duniter "$NELAT" "$NELON")
        [[ ! ${NEWALLET} ]] && echo "ERROR generating NEWALLET" && exit 1
        echo "NORTH EAST UMAP NEWALLET : ${NEWALLET}"
        ipfs key rm ${NEWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NEWALLET.priv "$NELAT" "$NELON"
        NEUMAPNS=$(ipfs key import ${NEWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NEWALLET.priv)
        ipfs key rm ${NEWALLET}

        ##############################################################
        # South East Umap
        SELAT=$(echo "${LAT} - 0.01" | bc)
        SELON=$(echo "${LON} + 0.01" | bc)
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
          --arg here "${myIPFS}/ipns/${UMAPNS}" \
          '{north: $north, south: $south, east: $east, west: $west, northeast: $northeast, northwest: $northwest, southeast: $southeast, southwest: $southwest, here: $here}' \
          > ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json

    fi

####################################
        ## MAKE GET POI's

### JSON UMAP SCRAPPING
####################################
        ## RECORD P4N SPOT DATA
        curl -s "https://www.park4night.com/api/places/around?lat=${LAT}&lng=${LON}&radius=200&filter=%7B%7D&lang=fr" -o ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json
        [[ -s ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ]] \
        && mv ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ~/.zen/tmp/${MOATS}/${UMAP}/p4n.json

        ## GET 100KM GCHANGE ADS ( https://data.gchange.fr )
        ${MY_PATH}/../tools/gchange_get_50km_around_LAT_LON_ads.sh ${LAT} ${LON} > ~/.zen/tmp/${MOATS}/${UMAP}/gchange50.json

        ## CREATE GCHANGE ACCOUNT ??!!


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

########################################################
## ACTIVATE IN CASE OF PROTOCOL BRAKE
## TODO : BACKUP STATE IN // PRIVATE KEY
## TODO : SNIFF IPFS DHT MODIFICATIONS ## FAIL2BAN ## DEFCON
########################################################

        ##############################################################
        ############################ PUBLISHING UMAP
        ##############################################################
        UMAPROOT=$(ipfs add -rwHq ~/.zen/tmp/${MOATS}/${UMAP}/* | tail -n 1)

        ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
        ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_moats 2>/dev/null)
        [[ ${ZCHAIN} && ${ZMOATS} ]] \
            && cp ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain.${ZMOATS} \
            && echo "UPDATING MOATS"

        ## DOES CHAIN CHANGED or INIT ?
        [[ ${ZCHAIN} != ${UMAPROOT} || ${ZCHAIN} == "" ]] \
            && echo "${MOATS}:${IPFSNODEID}:${UMAPROOT}" > ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_chain \
            && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}/_moats \
            && UMAPROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/${UMAP}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"

        echo "PUBLISHING NEW UMAPROOT : http://ipfs.localhost:8080/ipfs/${UMAPROOT}"

            ipfs name publish --key=${G1PUB} /ipfs/${UMAPROOT}
            end=`date +%s`
            ipfs key rm ${G1PUB} ## REMOVE IPNS KEY

            echo "(UMAP) PUBLISH time was "`expr $end - $start` seconds.

    done

