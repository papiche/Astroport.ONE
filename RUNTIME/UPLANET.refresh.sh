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
echo "############################################"
echo "
 _________________________
< RUNNING UPLANET.refresh >
 -------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\\/\\
                ||----w |
                ||     ||

"
echo "############################################"
echo "############################################"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir ~/.zen/tmp/${MOATS}

#################################################################
## IPFSNODEID ASTRONAUTES SIGNALING ## 12345 port
############################
## RUNING FOR ALL UMAP FOUND IN STATION MAP CACHE : "_LAT_LON"

## SEARCH UMAP (created by PLAYER.refresh.sh) /UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??
MEMAPS=($(ls -td ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
SWARMMAPS=($(ls -Gd ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
combined=("${MEMAPS[@]}" "${SWARMMAPS[@]}")
unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))
echo "ACTIVATED UMAPS : ${unique_combined[@]}" # "_LAT_LON" directories

######################################################
### LEVEL 1 ###########################################
######################################################
for UMAP in ${unique_combined[@]}; do

    start=`date +%s`
    echo
    echo "-------------------------------------------------------------------"
    echo "____________REFRESHING ${UMAP}__________ $(date)"
    LAT=$(echo ${UMAP} | cut -d '_' -f 2)
    LON=$(echo ${UMAP} | cut -d '_' -f 3)

    [[ ${LAT} == "" || ${LON} == "" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
    [[ ${LAT} == "null" || ${LON} == "null" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue

    ## SECTOR BANK COORD
    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    ## REGION
    RLAT=$(echo ${LAT} | cut -d '.' -f 1)
    RLON=$(echo ${LON} | cut -d '.' -f 1)

    ##############################################################
    ## UMAP WALLET CHECK
    ##############################################################
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${UMAP}.dunikey "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}"
    G1PUB=$(cat ~/.zen/tmp/${MOATS}/${UMAP}.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    [[ ! ${G1PUB} ]] && echo "ERROR generating UMAP WALLET" && exit 1

    COINS=$($MY_PATH/../tools/COINScheck.sh ${G1PUB} | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)

    echo "UMAP (${COINS} G1) ${ZEN} ZEN : ${G1PUB}"

    ## ORIGIN ##########################################################
    ## CALCULATE INITIAL UMAP GEOSPACIAL IPNS KEY
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${UMAP}.priv "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}"
    ipfs key rm ${G1PUB} > /dev/null 2>&1
    UMAPNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${UMAP}.priv)
    echo "ORIGIN : ${myIPFS}/ipns/${UMAPNS}"

    ###################### SPATIO TEMPORAL KEYS
    ## TODATE #########################################
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${TODATE}.priv "${TODATE}${UPLANETNAME}${LAT}" "${TODATE}${UPLANETNAME}${LON}"
    ipfs key rm ${TODATE}${G1PUB} > /dev/null 2>&1
    TODATENS=$(ipfs key import ${TODATE}${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${TODATE}.priv)
    echo "TODAY : ${myIPFS}/ipns/${TODATENS}"

    ## YESTERDATE ###############
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${YESTERDATE}.priv "${YESTERDATE}${UPLANETNAME}${LAT}" "${YESTERDATE}${UPLANETNAME}${LON}"
    ipfs key rm ${YESTERDATE}${G1PUB} > /dev/null 2>&1
    YESTERDATENS=$(ipfs key import ${YESTERDATE}${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${YESTERDATE}.priv)
    echo "YESTERDAY : ${myIPFS}/ipns/${YESTERDATENS}"

    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    start=`date +%s`
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    mkdir ~/.zen/tmp/${MOATS}/${UMAP}
    echo "## IPFS GET YESTERDATENS"
    ipfs --timeout 300s get --progress=false -o ~/.zen/tmp/${MOATS}/${UMAP}/ /ipns/${YESTERDATENS}/
    if [[ $? != 0 ]]; then
        echo "(╥☁╥ ) swarm online memory empty (╥☁╥ )"
        # Try retieve memory from UPlanet Zen Memory
        [[ ${ZEN} -gt 0 ]] \
            && echo "INTERCOM Refreshing from ZEN MEMORY" \
            && ${MY_PATH}/../RUNTIME/ZEN.UMAP.memory.sh "${UMAP}" "${MOATS}" "${G1PUB}"
    fi
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    end=`date +%s`
    echo "_____UMAP${UMAP} GET time was "`expr $end - $start` seconds.
    # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    ## FORMAT CONTROL WARNING
    [[ ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN || ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} ]] \
        && echo ">>> INFO - INTIALIZE UMAP FORMAT - NEW UMAP KEY -" \
        && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON} \
        && mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN \
        && echo ${MOATS} > ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_moats

    mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/RSS
    mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/TW

    echo "~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/"

     ## zday of the week for IPFSNODEID
    rm -f ~/.zen/tmp/${MOATS}/${UMAP}/z*.html 2>/dev/null
    ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_chain 2>/dev/null | rev | cut -d ':' -f 1 | rev 2>/dev/null)
    [[ "${ZCHAIN}" != "" ]] \
        && echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${ZCHAIN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/z$(date +%A-%d_%m_%Y).html

    ########################################################
    ## NODE  SELECTION in UMAP.refresher
    UREFRESH="${HOME}/.zen/tmp/${MOATS}/${UMAP}/${LAT}_${LON}/UMAP.refresher"
    ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}
    STRAPS=($(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#" | rev | cut -d '/' -f 1 | rev | grep -v '^[[:space:]]*$')) ## ${STRAPS[@]}

    if [[ ${ALLNODES[@]} == "" ]]; then
        for STRAP in ${STRAPS[@]}; do
                echo ${STRAP} >> ${UREFRESH} ## FILL UMAP.refresher file with all STRAPS
        done
        ALLNODES=($(cat ${UREFRESH} 2>/dev/null)) # ${ALLNODES[@]}
    fi

    ACTINGNODE=${ALLNODES[0]} ## FIST NODE IN UMAP.refresher

    ## IN CASE OLD BOOSTRAP IS STILL IN CHARGE - CHOOSE 1ST STRAP -
    [[ ! $(echo ${STRAPS[@]} | grep  ${ACTINGNODE}) ]] && ACTINGNODE=${STRAPS[0]}

    #  ++++++++++++++++++++ - - - - FIND LAST TREATMENT TIME
    ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_moats 2>/dev/null) || ZMOATS=${MOATS}
    # ZMOATS SHOULD BE MORE THAT 5 HOURS.
    MOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${MOATS})
    ZMOATS_SECONDS=$(${MY_PATH}/../tools/MOATS2seconds.sh ${ZMOATS})
    DIFF_SECONDS=$((MOATS_SECONDS - ZMOATS_SECONDS))
    hours=$((DIFF_SECONDS / 3600))
    minutes=$(( (DIFF_SECONDS % 3600) / 60 ))
    seconds=$((DIFF_SECONDS % 60))
    echo "UMAP DATA is ${hours} hours ${minutes} minutes ${seconds} seconds "
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ## IF NOT UPDATED FOR TOO LONG
    [[ ${DIFF_SECONDS} -gt $(( 26 * 60 * 60 )) || ${DIFF_SECONDS} -eq 0 ]] \
        && echo "More than 26H update - BOOSTRAP 0 ACTION -" \
        && ACTINGNODE=${STRAPS[0]}

    echo "* ACTINGNODE=${ACTINGNODE}"

    if [[ "${ACTINGNODE}" != "${IPFSNODEID}" ]]; then
        echo ">> ACTINGNODE NOT ME - CONTINUE -"
        ipfs key rm "${TODATE}${G1PUB}"  "${YESTERDATE}${G1PUB}" "${G1PUB}"
        echo "------8<-------------8<------------------8<-----------------8<-----------------8<"
        continue
    fi
    ################################################################################
    # ~~~~~~~~~~~~~ GOING FURTHER ~~~ MEANS IPFSNODEID IS UMAP REFRESHER ~~~~~~~~~~~
    ################################################################################
    ## NEXT REFRESHER
    # TODO: INTRODUCE NODE BALANCE AND CHOOSE THE MOST CONFIDENT ONE
    rm ${UREFRESH}
    for STRAP in ${STRAPS[@]}; do
            echo ${STRAP} >> ${UREFRESH} ## FILL UMAP.refresher file with all STRAPS
    done
    # SHUFFLE UMAP.refresher
    cat ${UREFRESH} | sort | uniq | shuf  > ${UREFRESH}.shuf
    mv ${UREFRESH}.shuf ${UREFRESH}
    ## NEXT REFRESHER
    echo ">> NEXT REFRESHER WILL BE $(cat ${UREFRESH} | head -n 1)"
    ######################################################## # NODE  SELECTION in UMAP.refresher

    ############ 101 ZEN REFILL ?!
    CURRENT=$(readlink ~/.zen/game/players/.current | rev | cut -d '/' -f 1 | rev)
    [[ ${COINS} == "" || ${COINS} == "null" ]] \
        && [[ ${ZEN} -lt 100 && ${CURRENT} != "" ]] \
        && MIUSER=$(${MY_PATH}/../tools/clyuseryomail.sh "${CURRENT}") \
        && ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/players/.current/secret.dunikey" "11.1" "${G1PUB}" "UPLANET:101ZEN:${UMAP}:${MIUSER}" \
        && echo "UPLANET:101:${UMAP}:${MIUSER}" && echo " ~~~ (♥‿‿♥) ~~ _${LAT}_${LON} ~~ (♥‿‿♥) ~~~ "

    # %%%%%%%%%% ##################################################
    ## SECTOR LINKING >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>${SLAT}_${SLON}
    # %%%%%%%%%% ##################################################
    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    SECTOR="_${SLAT}_${SLON}"
    echo "SECTOR ${SECTOR}"
    ############################################################## "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}"
    SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    [[ ! ${SECTORG1PUB} ]] && echo "ERROR generating SECTOR WALLET" && exit 1
    COINS=$($MY_PATH/../tools/COINScheck.sh ${SECTORG1PUB} | tail -n 1)
    echo "SECTOR : ${SECTOR} (${COINS} G1) WALLET : ${SECTORG1PUB}"

    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${SECTOR}.priv "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}"
    ipfs key rm ${SECTORG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
    SECTORNS=$(ipfs key import ${SECTORG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${SECTOR}.priv)
    ipfs key rm ${SECTORG1PUB}
    ##############################################################
    mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${SLAT}_${SLON}
    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${SECTORNS}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/${SLAT}_${SLON}/index.html

    # %%%%%%%%%% ##################################################
    ## REGION LINKING >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${RLAT}_${RLON}
    # %%%%%%%%%% ##################################################
    RLAT=$(echo ${LAT} | cut -d '.' -f 1)
    RLON=$(echo ${LON} | cut -d '.' -f 1)
    REGION="_${RLAT}_${RLON}"
    echo "REGION ${REGION}"
    ##############################################################
    REGIONG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
    [[ ! ${REGIONG1PUB} ]] && echo "ERROR generating REGION WALLET" && exit 1
    COINS=$($MY_PATH/../tools/COINScheck.sh ${REGIONG1PUB} | tail -n 1)
    echo "REGION : ${REGION} (${COINS} G1) WALLET : ${REGIONG1PUB}"

    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/REGION.priv "${TODATE}${UPLANETNAME}${REGION}" "${TODATE}${UPLANETNAME}${REGION}"
    ipfs key rm ${REGIONG1PUB} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
    TODATEREGIONNS=$(ipfs key import ${REGIONG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/REGION.priv)
    ipfs key rm ${REGIONG1PUB}
    ##############################################################
    mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/${RLAT}_${RLON}
    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${TODATEREGIONNS}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/${RLAT}_${RLON}/index.html

    ####################################################################################
    ######################## NEXTNS : UMAP, SECTOR, REGION  ## BOOSTRAP TO SWARM ##
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/
    ####################################################################################
    #################################################################################
    ## DEMAIN DATA
    ####################################################################################
    ## UMAP NEXTNS ############### INFORM "PLAYER.refresh.sh" WITH _next.umap
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/next.priv "${DEMAINDATE}${UPLANETNAME}${LAT}" "${DEMAINDATE}${UPLANETNAME}${LON}"
    ipfs key rm "next" > /dev/null 2>&1
    NEXTNS=$(ipfs key import "next" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/next.priv)
    echo "UMAP NEXTNS : ${myIPFS}/ipns/${NEXTNS}"
    ipfs key rm "next" > /dev/null 2>&1
    rm ~/.zen/tmp/${MOATS}/next.priv
    ## BOOSTRAP SWARM PUBLICATION _next.umapns
    echo "${G1PUB}:${DEMAINDATE}:${NEXTNS}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/_next.umapns
    ## IN UMAP KEY PUBLICATION
    cp ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/_next.umapns \
        ~/.zen/tmp/${MOATS}/${UMAP}/
    ## SECTOR NEXTNS ############### INFORM "PLAYER.refresh.sh" WITH _next.sector
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/next.priv "${DEMAINDATE}${UPLANETNAME}${SECTOR}" "${DEMAINDATE}${UPLANETNAME}${SECTOR}"
    ipfs key rm "next" > /dev/null 2>&1
    NEXTNS=$(ipfs key import "next" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/next.priv)
    echo "SECTOR NEXTNS : ${myIPFS}/ipns/${NEXTNS}"
    ipfs key rm "next" > /dev/null 2>&1
    rm ~/.zen/tmp/${MOATS}/next.priv
    ## BOOSTRAP SWARM PUBLICATION _next.sectorns
    echo "${SECTORG1PUB}:${DEMAINDATE}:${NEXTNS}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/_next.sectorns
    ## IN UMAP KEY PUBLICATION
    cp ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/_next.sectorns \
        ~/.zen/tmp/${MOATS}/${UMAP}/
    ## REGION NEXTNS ############### INFORM "PLAYER.refresh.sh" WITH _next.region
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/next.priv "${DEMAINDATE}${UPLANETNAME}${REGION}" "${DEMAINDATE}${UPLANETNAME}${REGION}"
    ipfs key rm "next" > /dev/null 2>&1
    NEXTNS=$(ipfs key import "next" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/next.priv)
    echo "REGION NEXTNS : ${myIPFS}/ipns/${NEXTNS}"
    ipfs key rm "next" > /dev/null 2>&1
    rm ~/.zen/tmp/${MOATS}/next.priv
    ## BOOSTRAP SWARM PUBLICATION _next.regionns
    echo "${REGIONG1PUB}:${DEMAINDATE}:${NEXTNS}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/_next.regionns
    ## IN UMAP KEY PUBLICATION
    cp ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/_next.regionns \
        ~/.zen/tmp/${MOATS}/${UMAP}/
    ####################################################################################
    ## TODATE DATA
    ####################################################################################
    echo "${TODATENS}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TODATENS
    echo "${SECTORNS}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORNS
    echo "${TODATEREGIONNS}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONNS
    echo "${G1PUB}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB
    echo "${SECTORG1PUB}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORG1PUB
    echo "${REGIONG1PUB}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONG1PUB

    ####################################################################################

    # %%%%%%%%%% ##################################################
    ## COLLECT RSS FROM ALL PLAYERS WITH SAME UMAP IN SWARM MEMORY /UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??
    # %%%%%%%%%% ##################################################
    cp ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/RSS/*.rss.json \
        ~/.zen/tmp/${MOATS}/${UMAP}/RSS/ 2>/dev/null
    RSSFILES=($(ls ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/RSS/*.rss.json 2>/dev/null))
    for RSSFILE in ${RSSFILES[@]}; do
        cp ${RSSFILE} ~/.zen/tmp/${MOATS}/${UMAP}/RSS/
    done

    # %%%%%%%%%% ##################################################
    ## COLLECT TW LINKS FROM NODE & SWARM
    # %%%%%%%%%% ##################################################
    cp -r ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TW/* \
        ~/.zen/tmp/${MOATS}/${UMAP}/TW/ 2>/dev/null
    TWFILES=($(ls ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TW/*/index.html 2>/dev/null))
    for TWRED in ${TWFILES[@]}; do
        ZMAIL=$(echo ${TWRED} | rev | cut -d '/' -f 2 | rev)
        mkdir -p ~/.zen/tmp/${MOATS}/${UMAP}/TW/${ZMAIL}
        cp ${TWRED} ~/.zen/tmp/${MOATS}/${UMAP}/TW/${ZMAIL}/
    done

    ##################################
        ## OSM2IPFS
    ### UMAP = 0.01° Planet Slice
    UMAPGEN="${EARTHCID}/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipns=${TODATENS}/_index.html"
    USATGEN="${EARTHCID}/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipns=${TODATENS}/_index.html"
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/Umap.html
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${USATGEN}'\" />" > ~/.zen/tmp/${MOATS}/${UMAP}/Usat.html

    ## ¤$£€ removed copy OSM map to IPFS. TODO. scrap tiles instead of screen copy
        ## TODO # GET SCREENSHOT UMAP SECTOR & REGION JPG
        ## PROBLEM ON LIBRA ... MORE TEST NEEDED ...
        #~ [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg ]] \
            #~ && python ${MY_PATH}/../tools/page_screenshot.py "${myIPFS}${UMAPGEN}" ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg 900 900 2>/dev/null \
            #~ && [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Umap.jpg ]] && killall chrome

        #~ [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg ]] \
            #~ && python ${MY_PATH}/../tools/page_screenshot.py "${myIPFS}${USATGEN}" ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg 900 900 2>/dev/null \
            #~ && [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/Usat.jpg ]] && killall chrome
    #### NOT WORKING !!!

    ## GEOLINKING CALCULATE SURROUNDING UMAPS  ###############################
    #~ if [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/geolinks.json ]]; then

        #~ ${MY_PATH}/../tools/Umap_geolinks.sh "${LAT}" "${LON}" "${UMAP}" "${MOATS}" "${UMAPNS}"

    #~ fi
    #~ ### SET navigator.html ## MAKE EVOLVE template/umap.html
    #~ cp ${MY_PATH}/../templates/umap.html ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Umap.html
    #~ cat ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Umap.html | sed "s~Umap~Usat~g" > ~/.zen/tmp/${MOATS}/${UMAP}/navigator_Usat.html
    #### IS IT USEFUL ?..??

    ####################################
    # %%%%%%%%%% ##################################################
        ## GET FROM WEB2.0 POI's AROUND  >>>>>>>>>>>>>>>>>>>>>>>>>
    # %%%%%%%%%% ##################################################
    ####################################
    echo "################### WEB2.0 SCRAPING TIME >>>>>>>>>>>>>>>>"
    ## RECORD P4N SPOT DATA
    echo "* park4night : https://www.park4night.com/api/places/around?lat=${LAT}&lng=${LON}&radius=200&filter=%7B%7D&lang=fr"
    [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/p4n.json ]] && touch ~/.zen/tmp/${MOATS}/${UMAP}/p4n.json
    [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ]] \
        && curl -s -L "https://www.park4night.com/api/places/around?lat=${LAT}&lng=${LON}&radius=200&filter=%7B%7D&lang=fr" -o ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json \
        && [[ $(stat -c %s ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json) -gt $(stat -c %s ~/.zen/tmp/${MOATS}/${UMAP}/p4n.json) ]] \
        && mv ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ~/.zen/tmp/${MOATS}/${UMAP}/p4n.json \
        && echo "UPDATED PARK4NIGHT" \
        || rm ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json

    ####################################
    echo "* gchange : ./tools/gchange_get_50km_around_LAT_LON_ads.sh ${LAT} ${LON}"
    ## GET 100KM GCHANGE ADS ( https://data.gchange.fr )
    ${MY_PATH}/../tools/gchange_get_50km_around_LAT_LON_ads.sh ${LAT} ${LON} > ~/.zen/tmp/${MOATS}/${UMAP}/gchange50.json

    ## GET ALL WALLETS
    echo "* GET WALLETS https://g1-stats.axiom-team.fr/data/geoloc-members.json"
    [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/wallall.json ]] && touch ~/.zen/tmp/${MOATS}/${UMAP}/wallall.json
    [[ ! -s ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ]] \
        && curl -s "https://g1-stats.axiom-team.fr/data/geoloc-members.json" -o ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json \
        && [[ $(stat -c %s ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json) -gt $(stat -c %s ~/.zen/tmp/${MOATS}/${UMAP}/wallall.json) ]] \
        && mv ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json ~/.zen/tmp/${MOATS}/${UMAP}/wallall.json \
        && echo "UPDATED WALLALL" \
        || rm ~/.zen/tmp/${MOATS}/${UMAP}/fetch.json

    ## FILTER LOCAL WALLETS
    target_lat=${LAT}
    target_lon=${LON}
    precision=0.1
    jq --argjson target_lat "$target_lat" \
        --argjson target_lon "$target_lon" \
        --argjson precision "$precision" \
        '.wallets | map(select((.geoPoint.lat | tonumber) >= ($target_lat - $precision) and (.geoPoint.lat | tonumber) <= ($target_lat + $precision) and (.geoPoint.lon | tonumber) >= ($target_lon - $precision) and (.geoPoint.lon | tonumber) <= ($target_lon + $precision)))' ~/.zen/tmp/${MOATS}/${UMAP}/wallall.json \
        > ~/.zen/tmp/${MOATS}/${UMAP}/wallets.json

    echo "MAKING _index.p4n.html with ./templates/P4N/index.html"
    ## CREATE INDEX LOADING JSONs ON OPENSTREETMAP
    cat ${MY_PATH}/../templates/P4N/index.html \
    | sed -e "s~43.61000~${LAT}~g" \
              -e "s~1.43000~${LON}~g" \
              -e "s~_SERVICE_~Commons~g" \
              -e "s~_UMAP_~${UMAP}~g" \
              -e "s~http://127.0.0.1:8080~~g" \
    > ~/.zen/tmp/${MOATS}/${UMAP}/_index.p4n.html

    # %%%%%%%%%% ##################################################
    ########################################################
    echo "CREATING SPHERICAL LOCATIONS"
    # %%%%%%%%%% ##################################################
   ## PREPARE SPHERE MAP ##################################################################
    echo "var examples = {};
    examples['locations'] = function() {
    var locations = {
    " > ~/.zen/tmp/world.js
    floop=1

    SWARMTW=($(ls ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TW/*/index.html 2>/dev/null))
    NODETW=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_${LAT}_${LON}/TW/*/index.html 2>/dev/null))
    TWFILES=("${SWARMTW[@]}" "${NODETW[@]}")

    for TWRED in ${TWFILES[@]}; do
        ZMAIL=$(echo ${TWRED} | rev | cut -d '/' -f 2 | rev)
        TWADD=$(cat ${TWRED}  | grep -o "/ipns/[^\"]*" | sed "s/'$//")
        [[ -z ${TWADD} ]] && TWADD=$(cat ${TWRED}  | grep -o "/ipfs/[^\"]*" | sed "s/'$//")

        ## ADD ASTRONAUTNS ON SECTOR WORLD MAP
        echo "${floop}: {
          alpha: Math.random() * 2 * Math.PI,
          delta: Math.random() * 2 * Math.PI,
          name: '"${ZMAIL}"',
          link: '"${TWADD}"'
        }
        ," >> ~/.zen/tmp/world.js

        ((floop++))
    done

    # REMOVE la dernière virgule
    sed -i '$ d' ~/.zen/tmp/world.js
    ##################################
    ## FINISH LOCATIONS
    echo "
    };
       \$('#sphere').earth3d({
        locationsElement: \$('#locations'),
        dragElement: \$('#locations'),
        locations: locations
      });
    };
    " >> ~/.zen/tmp/world.js

    IAMAP=$(ipfs add -qw ~/.zen/tmp/world.js | tail -n 1)
    echo "JSON UMAP WORLD READY /ipfs/${IAMAP}/world.js"
###########################################################################################
    ### APPLY ON APP MODEL
    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    SECTOR="_${SLAT}_${SLON}"
    TODATESECTORNS=$(${MY_PATH}/../tools/keygen -t ipfs "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}")

    PHONEBOOTH="${G1PUB::30}"
    cat ${MY_PATH}/../templates/UPlanetUmap/index.html \
    | sed -e "s~_ZONE_~CASE ${UMAP}~g" \
              -e "s~QmYdWBx32dP14XcbXF7hhtDq7Uu6jFmDaRnuL5t7ARPYkW/index_fichiers/world.js~${IAMAP}/world.js~g" \
              -e "s~_ZONENS_~${TODATENS}~g" \
              -e "s~_IPFSNINJA_~${VDONINJA}~g" \
              -e "s~_HACKGIPFS_~${HACKGIPFS}~g" \
              -e "s~_UPZONE_~SECTOR ${SECTOR}~g" \
              -e "s~_UPZONENS_~${TODATESECTORNS}~g" \
              -e "s~_UPUPZONE_~REGION ${REGION}~g" \
              -e "s~_UPUPZONENS_~${TODATEREGIONNS}~g" \
              -e "s~_PHONEBOOTH_~${PHONEBOOTH}~g" \
              -e "s~_CESIUMIPFS_~${CESIUMIPFS}~g" \
              -e "s~_G1PUB_~${G1PUB}~g" \
              -e "s~_DATE_~$(date +%A-%d_%m_%Y)~g" \
              -e "s~_UPLANETLINK_~${EARTHCID}/map_render.html\?southWestLat=${LAT}\&southWestLon=${LON}\&deg=0.01~g" \
              -e "s~http://127.0.0.1:8080~~g" \
    > ~/.zen/tmp/${MOATS}/${UMAP}/_index.html

    ## Make it root App
    #~ mv ~/.zen/tmp/${MOATS}/${UMAP}/_index.html \
            #~ ~/.zen/tmp/${MOATS}/${UMAP}/index.html
    ##################################

###########################################################################################
########################################################
## CREATE .all.json for RSS in this UMAP
    ${MY_PATH}/../tools/json_dir.all.sh ~/.zen/tmp/${MOATS}/${UMAP}/RSS

    ##############################################################
    ############################ PUBLISHING UMAP
    ##############################################################
    UMAPROOT=$(ipfs add -rwHq ~/.zen/tmp/${MOATS}/${UMAP}/* | tail -n 1)

    ZCHAIN=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_chain | rev | cut -d ':' -f 1 | rev 2>/dev/null)
    ZMOATS=$(cat ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_moats 2>/dev/null)
    [[ ${ZCHAIN} && ${ZMOATS} ]] \
        && cp ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_chain ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_chain.${ZMOATS} \
        && echo "UPDATING MOATS"

######################################################
    ## ZEN CHAINING
    # Send 1 Zen to UPlanet SECTORG1PUB Wallet containing REGION TW HASH
    INTERCOM="UPLANET:${UMAP}:${TODATE}:/ipfs/${UMAPROOT}"
    echo "> INTERCOM ${INTERCOM} (${ZEN} ZEN > 11 ?)"
    if [[ ${ZEN} -gt 11 ]]; then
        echo "---ZZZ-- UMAP 2 SECTOR ZEN CHAINING ---ZZZ------ZZZ----"
        ${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/tmp/${MOATS}/${UMAP}.dunikey "0.1" "${SECTORG1PUB}" "${INTERCOM}"
    fi

    ## MICRO LEDGER CHAIN CHANGED or INIT ?
    [[ ${ZCHAIN} != ${UMAPROOT} || ${ZCHAIN} == "" ]] \
        && echo "${MOATS}:${IPFSNODEID}:${UMAPROOT}" > ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_chain \
        && echo "${MOATS}" > ~/.zen/tmp/${MOATS}/${UMAP}/${G1PUB}:ZEN/_moats \
        && UMAPROOT=$(ipfs add -rwHq  ~/.zen/tmp/${MOATS}/${UMAP}/* | tail -n 1) && echo "ROOT was ${ZCHAIN}"

    echo "PUBLISHING ${TODATE} UMAPROOT : ${myIPFS}/ipfs/${UMAPROOT}"

    ipfs --timeout 300s name publish --key=${TODATE}${G1PUB} /ipfs/${UMAPROOT}
    end=`date +%s`
    echo "(UMAP) ${UMAP} ${TODATE} PUBLISH time was "`expr $end - $start` seconds.

    ipfs key rm "${TODATE}${G1PUB}"  "${YESTERDATE}${G1PUB}" "${G1PUB}" ## REMOVE IPNS KEY
    rm ~/.zen/tmp/${MOATS}/*.priv
    rm ~/.zen/tmp/${MOATS}/${UMAP}.dunikey

done

######################################################
### LEVEL 2 ###########################################
######################################################
### SECTOR = 0.1° Planet Slice
${MY_PATH}/SECTOR.refresh.sh "${unique_combined[@]}"

######################################################
### LEVEL 3 ###########################################
######################################################
 ### REGION = 1° Planet Slice
${MY_PATH}/REGION.refresh.sh  "${unique_combined[@]}"
######################################################

######################################################
exit 0
######################################################
