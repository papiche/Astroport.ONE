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
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

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

#################################################################
echo "
 __________ _   _   _____ ____ ___  _   _  ___  _   ___   __
|__  / ____| \ | | | ____/ ___/ _ \| \ | |/ _ \| \ | \ \ / /
  / /|  _| |  \| | |  _|| |  | | | |  \| | | | |  \| |\ V /
 / /_| |___| |\  | | |__| |__| |_| | |\  | |_| | |\  | | |
/____|_____|_| \_| |_____\____\___/|_| \_|\___/|_| \_| |_|

-------------------------------------------------------------"
${MY_PATH}/ZEN.ECONOMY.sh
#################################################################

#################################################################
### COLLECTING NOSTR UMAPS
echo "############################################"
${MY_PATH}/NOSTR.UMAP.refresh.sh
echo "############################################"
#################################################################
#################################################################

#################################################################
## RUNING FOR ALL UMAP FOUND IN STATION MAP CACHE : "_LAT_LON"
#################################################################
MEMAPS=($(ls -td ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
SWARMMAPS=($(ls -Gd ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
combined=("${MEMAPS[@]}" "${SWARMMAPS[@]}")
unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))
echo "ACTIVATED ${#unique_combined[@]} UMAPS : ${unique_combined[@]}" # "_LAT_LON" directories

######################################################
### LEVEL 1 ###########################################
######################################################
for UMAP in ${unique_combined[@]}; do

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir ~/.zen/tmp/${MOATS}

    start=`date +%s`
    echo
    echo "-------------------------------------------------------------------"
    echo "____________REFRESHING ${UMAP}__________ $(date)"
    LAT=$(echo ${UMAP} | cut -d '_' -f 2)
    LON=$(echo ${UMAP} | cut -d '_' -f 3)
    UMAP="_${LAT}_${LON}"
    [[ ${LAT} == "" || ${LON} == "" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
    [[ ${LAT} == "null" || ${LON} == "null" ]] && echo ">> ERROR BAD ${LAT} ${LON}" && continue
    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    SECTOR="_${SLAT}_${SLON}"
    RLAT=$(echo ${LAT} | cut -d '.' -f 1)
    RLON=$(echo ${LON} | cut -d '.' -f 1)
    REGION="_${RLAT}_${RLON}"
    echo "SECTOR ${SECTOR} REGION ${REGION}"
    ##############################################################
    ## setUMAP_ENV.sh 
    ##############################################################
    $(${MY_PATH}/../tools/setUMAP_ENV.sh "${LAT}" "${LON}" | tail -n 1)
    #######################################################################################
    [[ ! -d ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ ]] && echo "UMAPPATH not found" && exit 1

    ####################################################################################
    ## UMAP DATA
    UMAPPATH=$HOME/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}
    echo "UMAPPATH : ${UMAPPATH}"
    ######################################################################################
    ## Fonction pour trouver dans le swarm ou générer une image
    find_or_generate_image() {
        local filename="$1"       # Nom du fichier (ex: Umap.jpg, Usat.jpg)
        local gen_url="$2"        # URL de génération (ex: "${myIPFS}${UMAPGEN}")
        local search_pattern="$3" # Pattern de recherche (ex: "*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/Umap.jpg")

        # Si le fichier n'existe pas ou est vide
        if [[ ! -s "${UMAPPATH}/${filename}" ]]; then
            echo "Recherche de ${filename} dans le swarm..."
            
            # Chercher dans le swarm
            local swarm_file=$(find "$HOME/.zen/tmp/swarm/" -path "$search_pattern" -print -quit 2>/dev/null)
            
            if [[ -f "$swarm_file" ]]; then
                echo "Fichier trouvé dans le swarm : ${UMAPPATH}/${filename}"
                if [[ ! "${UMAPPATH}" =~ "${IPFSNODEID}" ]]; then
                    rm "${UMAPPATH}/${filename}" 2>/dev/null
                fi
                cp "$swarm_file" "${UMAPPATH}/${filename}" # 
            else
                echo "Génération de ${filename} via page_screenshot.py..."
                python "${MY_PATH}/../tools/page_screenshot.py" "$gen_url" "${UMAPPATH}/${filename}" 900 900
            fi
        else
            echo "${filename} existe déjà."
        fi
    }
    ## ==== PARTIE 1 : Umap.jpg et Usat.jpg (vue large) ====
    if [[ ! -s "${UMAPPATH}/Umap.jpg" ]] || [[ ! -s "${UMAPPATH}/Usat.jpg" ]]; then
        UMAPGEN="/ipns/copylaradio.com/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01"
        USATGEN="/ipns/copylaradio.com/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01"

        find_or_generate_image "Umap.jpg" "${myIPFS}${UMAPGEN}" "*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/Umap.jpg"
        find_or_generate_image "Usat.jpg" "${myIPFS}${USATGEN}" "*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/Usat.jpg"
    fi

    ## ==== PARTIE 2 : zUmap.jpg et zUsat.jpg (vue zoomée) ====
    if [[ ! -s "${UMAPPATH}/zUmap.jpg" ]] || [[ ! -s "${UMAPPATH}/zUsat.jpg" ]]; then
        UMAPGEN_ZOOM="/ipns/copylaradio.com/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.001"
        USATGEN_ZOOM="/ipns/copylaradio.com/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.001"

        find_or_generate_image "zUmap.jpg" "${myIPFS}${UMAPGEN_ZOOM}" "*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/Umap.jpg"
        find_or_generate_image "zUsat.jpg" "${myIPFS}${USATGEN_ZOOM}" "*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/Usat.jpg"
    fi
    ########################################################## COPY OPENSTREET MAPS

    ####################################################################################
    ## WRITE NOSTR HEX ADDRESS USED FOR strfry whitelisting
    NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    HEX=$(${MY_PATH}/../tools/nostr2hex.py $NPUB)
    #~ mkdir -p ~/.zen/game/nostr/UMAP_${SLAT}_${SLON} # Add to nostr Whitelist # DONE by NODE.refresh.sh
    #~ echo "$HEX" \
        #~ > ~/.zen/game/nostr/UMAP_${SLAT}_${SLON}/HEX
    echo "$HEX" > ${UMAPPATH}/HEX
    echo "$NPUB" > ${UMAPPATH}/NPUB
    ####################################################################################
    echo "${UMAPG1PUB}" > ${UMAPPATH}/G1PUB
    echo "${SECTORG1PUB}" > ${UMAPPATH}/SECTORG1PUB
    echo "${REGIONG1PUB}" > ${UMAPPATH}/REGIONG1PUB
    ####################################################################################
    SECTORNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    SECTORHEX=$(${MY_PATH}/../tools/nostr2hex.py $SECTORNPUB)
    echo "${SECTORHEX}" > ${UMAPPATH}/HEX_SECTOR
    ####################################################################################
    SECTORPATH=$HOME/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}
    mkdir -p ${SECTORPATH}
    echo "${SECTORHEX}" > ${SECTORPATH}/SECTORHEX
    echo "${SECTORG1PUB}" > ${SECTORPATH}/SECTORG1PUB
    ####################################################################################
    REGIONNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
    REGIONHEX=$(${MY_PATH}/../tools/nostr2hex.py $REGIONNPUB)
    echo "${REGIONHEX}" > ${UMAPPATH}/HEX_REGION
    ####################################################################################
    REGIONPATH=$HOME/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}
    mkdir -p ${REGIONPATH}
    echo "${REGIONHEX}" > ${REGIONPATH}/REGIONHEX
    echo "${REGIONG1PUB}" > ${REGIONPATH}/REGIONG1PUB

    ####################################################################################
    ## COPY SECTOR & REGION IFPSROOT
    ## SWARM INIT
    cat ~/.zen/tmp/swarm/*/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE}  2>/dev/null | tail -f 1 2>/dev/null \
        > ${UMAPPATH}/SECTORROOT

    cat ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} 2>/dev/null | tail -f 1 2>/dev/null \
        > ${UMAPPATH}/REGIONROOT

    ## LOCAL UPDATE PRIORITY --- could be ipfs added ...
    [[ -s ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} ]] \
        && cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} \
        > ${UMAPPATH}/SECTORROOT

    [[ -s ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} ]] \
        && cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} \
        > ${UMAPPATH}/REGIONROOT
    ####################################################################################

    ##########################################################
    ### UMAP = 0.01° UPlanet UMAP ACCESS
    UMAPGEN="/ipns/copylaradio.com/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipfs=$(cat ${UMAPPATH}/ipfs.${TODATE} 2>/dev/null)"
    USATGEN="/ipns/copylaradio.com/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipfs=$(cat ${UMAPPATH}/ipfs.${TODATE} 2>/dev/null)"
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPGEN}'\" />" \
        > ${UMAPPATH}/Umap.html
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${USATGEN}'\" />" \
        > ${UMAPPATH}/Usat.html

    ##########################################################
    UMAPROOT=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/* | tail -n 1)
    echo "UMAPROOT : ${UMAPROOT}"
    ## chain ipfs link in rolling calendar
    echo "${UMAPROOT}" > ${UMAPPATH}/ipfs.${DEMAINDATE}
    rm ${UMAPPATH}/ipfs.${YESTERDATE} 2>/dev/null
    
    ##########################################################
    # profile picture
    PIC_PROFILE="${myIPFS}/ipfs/${UMAPROOT}/zUmap.jpg" # road map
    ##########################################################
    # profile banner
    PIC_BANNER="${myIPFS}/ipfs/${UMAPROOT}/Usat.jpg" # sat map
    echo "PIC_PROFILE : ${PIC_PROFILE}"
    echo "PIC_BANNER : ${PIC_BANNER}"

    ##########################################################
    ######### UMAP GCHANGE & CESIUM PROFILE
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${UMAP}.dunikey "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}"
    ################# PUBLISH UPlanet UMAP to G1PODs
    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${UMAP}.dunikey -n ${myDATA} \
            set -n "UMAP_${UPLANETG1PUB:0:8}${UMAP}" -v " " -a " " -d "UPlanet ${UPLANETG1PUB}" \
            -pos ${LAT} ${LON} -s ${myLIBRA}/ipfs/${UMAPROOT} \
            -A ${UMAPPATH}/zUmap.jpg

    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${UMAP}.dunikey -n ${myCESIUM} \
            set -n "UMAP_${UPLANETG1PUB:0:8}${UMAP}" -v " " -a " " -d "UPlanet ${UPLANETG1PUB}" \
            -pos ${LAT} ${LON} -s ${myLIBRA}/ipfs/${UMAPROOT} \
            -A ${UMAPPATH}/zUmap.jpg

    ##########################################################
    ######### UMAP NOSTR PROFILE
    #### PUBLISH TO NOSTR
    echo "###################### PUBLISH UMAP PROFILE ##########################"
    ##########################################################
    UMAPNSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$UMAPNSEC" \
    "UMAP_${UPLANETG1PUB:0:8}${UMAP}" "${UMAPG1PUB}" \
    "${TODATE} JOURNAL - VISIO : ${myLIBRA}${VDONINJA}/?room=${UMAPG1PUB:0:8}&effects&record" \
    "${PIC_PROFILE}" \
    "${PIC_BANNER}" \
    "" "${myLIBRA}/ipfs/${UMAPROOT}/APP" "" "${myLIBRA}${VDONINJA}/?room=${UMAPG1PUB:0:8}&effects&record" "" "" \
    "$myRELAY"

    rm ~/.zen/tmp/${MOATS}/${UMAP}.dunikey

done


####################################################################################
####################################################################################
## UPLANET ZEN -- auto follow -> UPlanet ORIGIN
####################################################################################
UPLANETNSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}" "${UPLANETNAME}" -s)
originpub=$(${MY_PATH}/../tools/keygen -t nostr "EnfinLibre" "EnfinLibre")
originhex=$(${MY_PATH}/../tools/nostr2hex.py $originpub)
if [[ ${UPLANETNAME} == "EnfinLibre" ]]; then
    echo "UPLANET ORIGIN : Seek for ${originhex} followers"
    ${MY_PATH}/../tools/nostr_followers.sh "${originhex}"
else
    ## UPLANET Ẑen ---- > follow UPlanet ORIGIN
    originhex=$(${MY_PATH}/../tools/nostr2hex.py $originpub)
    echo "UPLANET ZEN - follow -> UPlanet ORIGIN : ${originhex}"
    ${MY_PATH}/../tools/nostr_follow.sh "$UPLANETNSEC" "${originhex}"
fi

####################################################
## SETUP UPLANET PROFILE + UPLANET/HEX signaling
if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/UPLANET/HEX ]]; then
    ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$UPLANETNSEC" \
    "UPLANET_${UPLANETG1PUB:0:8}" "${UPLANETG1PUB}" \
    "VISIO ROOM : ${myLIBRA}${VDONINJA}/?room=${UPLANETG1PUB:0:8}&effects&record // UPlanet is a #Web3 key architecture offering Global #IPFS Storage through Geolocalized #Astroport Relays" \
    "${myLIBRA}/ipfs/QmSuoBkXoY6Fh7AshD71AdPaJdfjtmQdTavyTFNzbir8KR/UPlanetORIGIN.png" \
    "${myLIBRA}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
    "" "${myLIBRA}/ipns/copylaradio.com" "" "$myIPFS$VDONINJA/?room=${UPLANETG1PUB:0:8}&effects&record" "" "" \
    "$myRELAY" \
    --zencard "$UPLANETNAME_G1" \
    | tail -n 1 | rev | cut -d ' ' -f 1 | rev > ~/.zen/tmp/${IPFSNODEID}/UPLANET/HEX
fi
####################################################################################

######################################################
exit 0
######################################################
