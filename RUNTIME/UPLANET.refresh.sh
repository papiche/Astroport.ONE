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
### ORACLE SYSTEM - Daily Permit Maintenance
echo "############################################"
${MY_PATH}/ORACLE.refresh.sh
echo "############################################"
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
# combined=("${MEMAPS[@]}" "${SWARMMAPS[@]}") ## TODO CONFIRM IT WORKS BETTER
combined=("${MEMAPS[@]}") ### REDUCE UMAP REFRESH TO LOCAL ONLY
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
    
    ####################################################################################
    ## GENERATE NOSTR HEX EARLY (needed for image CID lookup)
    NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    HEX=$(${MY_PATH}/../tools/nostr2hex.py $NPUB)
    
    ######################################################################################
    ## NOSTR-NATIVE IMAGE MANAGEMENT (no local storage, CIDs in profile)
    ## 4 images: zUmap.jpg (profile), Umap.jpg, Usat.jpg (banner), zUsat.jpg
    ## Refresh intervals: road maps = 30 days, satellite = 60 days
    ######################################################################################
    UMAP_REFRESH_DAYS=30   # Road map refresh interval
    USAT_REFRESH_DAYS=60   # Satellite refresh interval
    
    ## Validate that a CID points to a valid image (JPEG or PNG)
    ## Returns 0 if valid image, 1 if invalid/corrupted
    validate_image_cid() {
        local cid="$1"
        local name="$2"
        
        [[ -z "$cid" ]] && return 1
        
        # Fetch first 16 bytes to check magic numbers
        local magic=$(ipfs cat --timeout=10s "$cid" 2>/dev/null | head -c 16 | xxd -p 2>/dev/null)
        
        # Check JPEG magic: FF D8 FF
        if [[ "${magic:0:6}" == "ffd8ff" ]]; then
            echo "✓ $name ($cid) is valid JPEG"
            return 0
        fi
        
        # Check PNG magic: 89 50 4E 47 (0x89 P N G)
        if [[ "${magic:0:8}" == "89504e47" ]]; then
            echo "✓ $name ($cid) is valid PNG"
            return 0
        fi
        
        echo "✗ $name ($cid) INVALID - not a valid image (magic: ${magic:0:16})"
        return 1
    }
    
    ## Check if images need refresh based on NOSTR profile date AND validity
    check_images_need_refresh() {
        local nostr_data=$(${MY_PATH}/../tools/nostr_get_umap_images.sh "$HEX" "" --check-only 2>/dev/null)
        EXISTING_ZUMAP_CID=$(echo "$nostr_data" | grep "^UMAP_CID=" | cut -d'=' -f2)        # zUmap.jpg
        EXISTING_USAT_CID=$(echo "$nostr_data" | grep "^USAT_CID=" | cut -d'=' -f2)         # Usat.jpg
        EXISTING_UMAP_CID=$(echo "$nostr_data" | grep "^UMAP_FULL_CID=" | cut -d'=' -f2)    # Umap.jpg (full)
        EXISTING_ZUSAT_CID=$(echo "$nostr_data" | grep "^USAT_FULL_CID=" | cut -d'=' -f2)   # zUsat.jpg
        EXISTING_UMAP_UPDATED=$(echo "$nostr_data" | grep "^UMAP_UPDATED=" | cut -d'=' -f2)
        
        # If no update date, images need refresh
        if [[ -z "$EXISTING_UMAP_UPDATED" || "$EXISTING_UMAP_UPDATED" == "null" ]]; then
            echo "No existing update date found, images need generation"
            return 0
        fi
        
        # Calculate age in days
        local update_timestamp=$(date -d "${EXISTING_UMAP_UPDATED:0:4}-${EXISTING_UMAP_UPDATED:4:2}-${EXISTING_UMAP_UPDATED:6:2}" +%s 2>/dev/null || echo 0)
        local current_timestamp=$(date +%s)
        local age_days=$(( (current_timestamp - update_timestamp) / 86400 ))
        
        echo "Images last updated: $EXISTING_UMAP_UPDATED ($age_days days ago)"
        
        # Validate existing CIDs - check all 4 images
        local map_images_valid=true
        local sat_images_valid=true
        
        echo "Validating existing image CIDs..."
        if [[ -n "$EXISTING_ZUMAP_CID" ]] && ! validate_image_cid "$EXISTING_ZUMAP_CID" "zUmap.jpg"; then
            map_images_valid=false
        fi
        if [[ -n "$EXISTING_UMAP_CID" ]] && ! validate_image_cid "$EXISTING_UMAP_CID" "Umap.jpg"; then
            map_images_valid=false
        fi
        if [[ -n "$EXISTING_USAT_CID" ]] && ! validate_image_cid "$EXISTING_USAT_CID" "Usat.jpg"; then
            sat_images_valid=false
        fi
        if [[ -n "$EXISTING_ZUSAT_CID" ]] && ! validate_image_cid "$EXISTING_ZUSAT_CID" "zUsat.jpg"; then
            sat_images_valid=false
        fi
        
        # Check if road maps need refresh (30 days OR invalid)
        if [[ $age_days -ge $UMAP_REFRESH_DAYS || -z "$EXISTING_ZUMAP_CID" || "$map_images_valid" == false ]]; then
            NEED_UMAP_REFRESH=true
            if [[ "$map_images_valid" == false ]]; then
                echo "✗ Road maps need refresh (corrupted/invalid CIDs)"
            else
                echo "✗ Road maps need refresh (> $UMAP_REFRESH_DAYS days or missing)"
            fi
        else
            NEED_UMAP_REFRESH=false
            echo "✓ Road maps fresh and valid (< $UMAP_REFRESH_DAYS days)"
        fi
        
        # Check if satellite images need refresh (60 days OR invalid)
        if [[ $age_days -ge $USAT_REFRESH_DAYS || -z "$EXISTING_USAT_CID" || "$sat_images_valid" == false ]]; then
            NEED_USAT_REFRESH=true
            if [[ "$sat_images_valid" == false ]]; then
                echo "✗ Satellite images need refresh (corrupted/invalid CIDs)"
            else
                echo "✗ Satellite images need refresh (> $USAT_REFRESH_DAYS days or missing)"
            fi
        else
            NEED_USAT_REFRESH=false
            echo "✓ Satellite images fresh and valid (< $USAT_REFRESH_DAYS days)"
        fi
        
        [[ "$NEED_UMAP_REFRESH" == true || "$NEED_USAT_REFRESH" == true ]] && return 0
        return 1
    }
    
    ## Generate image directly to IPFS (no local storage)
    generate_image_to_ipfs() {
        local gen_url="$1"
        local tmp_file="$2"
        local img_name=$(basename "$tmp_file")
        
        echo "  → Generating $img_name from: $gen_url" >&2
        
        # Run screenshot with error capture
        local screenshot_output
        screenshot_output=$(python "${MY_PATH}/../tools/page_screenshot.py" "$gen_url" "$tmp_file" 900 900 2>&1)
        local screenshot_exit=$?
        
        if [[ $screenshot_exit -ne 0 ]]; then
            echo "  ✗ Screenshot FAILED for $img_name (exit code: $screenshot_exit)" >&2
            [[ -n "$screenshot_output" ]] && echo "    Error: $screenshot_output" >&2
            echo ""
            return 1
        fi
        
        if [[ ! -s "$tmp_file" ]]; then
            echo "  ✗ Screenshot produced empty file for $img_name" >&2
            [[ -n "$screenshot_output" ]] && echo "    Output: $screenshot_output" >&2
            rm -f "$tmp_file" 2>/dev/null
            echo ""
            return 1
        fi
        
        # Add to IPFS
        local cid
        cid=$(ipfs add -q "$tmp_file" 2>&1)
        local ipfs_exit=$?
        
        if [[ $ipfs_exit -ne 0 || -z "$cid" ]]; then
            echo "  ✗ IPFS add FAILED for $img_name" >&2
            [[ -n "$cid" ]] && echo "    Error: $cid" >&2
            rm -f "$tmp_file" 2>/dev/null
            echo ""
            return 1
        fi
        
        local file_size=$(stat -c%s "$tmp_file" 2>/dev/null || echo "?")
        echo "  ✓ $img_name OK (${file_size} bytes) → $cid" >&2
        rm -f "$tmp_file"
        echo "$cid"
    }
    
    echo "Checking NOSTR profile for image CIDs and update date..."
    
    ## Initialize CID variables (4 images total)
    ZUMAP_CID=""   # zUmap.jpg (zoomed road map - PROFILE PICTURE)
    UMAP_CID=""    # Umap.jpg (full road map)
    USAT_CID=""    # Usat.jpg (full satellite - BANNER)
    ZUSAT_CID=""   # zUsat.jpg (zoomed satellite)
    IMAGES_UPDATED=false
    IMG_SUCCESS=0
    IMG_FAILED=0
    
    if check_images_need_refresh; then
        echo "Generating/updating map images..."
        echo "IPFS Gateway: ${myIPFS}"
        
        # Generate road maps if needed
        if [[ "$NEED_UMAP_REFRESH" == true ]]; then
            # zUmap.jpg (zoomed road map 0.001° - PROFILE PICTURE)
            ZUMAP_GEN="/ipns/copylaradio.com/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.001"
            ZUMAP_CID=$(generate_image_to_ipfs "${myIPFS}${ZUMAP_GEN}" "${HOME}/.zen/tmp/${MOATS}/zUmap.jpg")
            if [[ -n "$ZUMAP_CID" ]]; then
                ((IMG_SUCCESS++))
                IMAGES_UPDATED=true
            else
                ((IMG_FAILED++))
                echo "  ⚠ zUmap.jpg generation failed - check logs above"
            fi
            
            # Umap.jpg (full road map 0.01°)
            UMAP_GEN="/ipns/copylaradio.com/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01"
            UMAP_CID=$(generate_image_to_ipfs "${myIPFS}${UMAP_GEN}" "${HOME}/.zen/tmp/${MOATS}/Umap.jpg")
            if [[ -n "$UMAP_CID" ]]; then
                ((IMG_SUCCESS++))
            else
                ((IMG_FAILED++))
                echo "  ⚠ Umap.jpg generation failed - check logs above"
            fi
        else
            ZUMAP_CID="$EXISTING_ZUMAP_CID"
            UMAP_CID="$EXISTING_UMAP_CID"
            echo "  Using existing road map CIDs (still fresh)"
        fi
        
        # Generate satellite images if needed
        if [[ "$NEED_USAT_REFRESH" == true ]]; then
            # Usat.jpg (full satellite 0.1° - BANNER)
            USAT_GEN="/ipns/copylaradio.com/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.1"
            USAT_CID=$(generate_image_to_ipfs "${myIPFS}${USAT_GEN}" "${HOME}/.zen/tmp/${MOATS}/Usat.jpg")
            if [[ -n "$USAT_CID" ]]; then
                ((IMG_SUCCESS++))
                IMAGES_UPDATED=true
            else
                ((IMG_FAILED++))
                echo "  ⚠ Usat.jpg generation failed - check logs above"
            fi
            
            # zUsat.jpg (zoomed satellite 0.01°)
            ZUSAT_GEN="/ipns/copylaradio.com/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01"
            ZUSAT_CID=$(generate_image_to_ipfs "${myIPFS}${ZUSAT_GEN}" "${HOME}/.zen/tmp/${MOATS}/zUsat.jpg")
            if [[ -n "$ZUSAT_CID" ]]; then
                ((IMG_SUCCESS++))
            else
                ((IMG_FAILED++))
                echo "  ⚠ zUsat.jpg generation failed - check logs above"
            fi
        else
            USAT_CID="$EXISTING_USAT_CID"
            ZUSAT_CID="$EXISTING_ZUSAT_CID"
            echo "  Using existing satellite CIDs (still fresh)"
        fi
        
        # Summary
        if [[ $IMG_FAILED -gt 0 ]]; then
            echo "⚠ Image generation: $IMG_SUCCESS succeeded, $IMG_FAILED failed"
        elif [[ $IMG_SUCCESS -gt 0 ]]; then
            echo "✓ Image generation: $IMG_SUCCESS images generated successfully"
        fi
    else
        # Use existing CIDs from NOSTR profile
        ZUMAP_CID="$EXISTING_ZUMAP_CID"
        UMAP_CID="$EXISTING_UMAP_CID"
        USAT_CID="$EXISTING_USAT_CID"
        ZUSAT_CID="$EXISTING_ZUSAT_CID"
        echo "✓ Using existing image CIDs from NOSTR profile (all fresh)"
    fi
    
    # Set update date (today if images were refreshed, or keep existing)
    if [[ "$IMAGES_UPDATED" == true ]]; then
        UMAP_UPDATE_DATE=$(date +%Y%m%d)
    else
        UMAP_UPDATE_DATE="$EXISTING_UMAP_UPDATED"
    fi
    
    echo "NOSTR images: zUmap=${ZUMAP_CID:-NONE} | Umap=${UMAP_CID:-NONE} | Usat=${USAT_CID:-NONE} | zUsat=${ZUSAT_CID:-NONE}"
    
    ########################################################## TODO REMOVE
    ## CLEANUP: Remove local image files (migration to NOSTR-native storage)
    ## Images are now stored only in IPFS via CIDs in NOSTR profile
    rm -f "${UMAPPATH}/zUmap.jpg" "${UMAPPATH}/Usat.jpg" "${UMAPPATH}/Umap.jpg" 2>/dev/null
    rm -f "${UMAPPATH}/*.jpg" "${UMAPPATH}/*.png" 2>/dev/null
    echo "✓ Local images removed (CIDs in NOSTR profile)"
    ##########################################################

    ####################################################################################
    ## WRITE NOSTR HEX ADDRESS (already generated above for image lookup)
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
    UMAPRENDER="/ipns/copylaradio.com/map_render.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.1&ipfs=$(cat ${UMAPPATH}/ipfs.${TODATE} 2>/dev/null)"
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPRENDER}'\" />" \
        > ${UMAPPATH}/Umap.html
    rm ${UMAPPATH}/Usat.html 2>/dev/null ## TODO Remove

    ##########################################################
    ## Add UMAP metadata to IPFS (no images - they are stored separately via CIDs)
    UMAPROOT=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/* | tail -n 1)
    echo "UMAPROOT : ${UMAPROOT}"
    ## chain ipfs link in rolling calendar
    echo "${UMAPROOT}" > ${UMAPPATH}/ipfs.${DEMAINDATE}
    rm ${UMAPPATH}/ipfs.${YESTERDATE} 2>/dev/null
    
    ##########################################################
    # profile picture - direct CID only (no fallback - images not in UMAPROOT)
    if [[ -n "$ZUMAP_CID" ]]; then
        PIC_PROFILE="${myLIBRA}/ipfs/${ZUMAP_CID}"
        echo "PIC_PROFILE : ${PIC_PROFILE}"
    else
        PIC_PROFILE=""
        echo "PIC_PROFILE : (none - will use default)"
    fi
    ##########################################################
    # profile banner - direct CID only (no fallback - images not in UMAPROOT)
    if [[ -n "$USAT_CID" ]]; then
        PIC_BANNER="${myLIBRA}/ipfs/${USAT_CID}"
        echo "PIC_BANNER : ${PIC_BANNER}"
    else
        PIC_BANNER=""
        echo "PIC_BANNER : (none - will use default)"
    fi

    ##########################################################
    ######### UMAP GCHANGE & CESIUM PROFILE
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${UMAP}.dunikey "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}"
    ################# PUBLISH UPlanet UMAP to G1PODs (no avatar - images in NOSTR/IPFS)
    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${UMAP}.dunikey -n ${myDATA} \
            set -n "UMAP_${UPLANETG1PUB:0:8}${UMAP}" -v " " -a " " -d "UPlanet ${UPLANETG1PUB}" \
            -pos ${LAT} ${LON} -s ${myLIBRA}/ipfs/${UMAPROOT}

    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${UMAP}.dunikey -n ${myCESIUM} \
            set -n "UMAP_${UPLANETG1PUB:0:8}${UMAP}" -v " " -a " " -d "UPlanet ${UPLANETG1PUB}" \
            -pos ${LAT} ${LON} -s ${myLIBRA}/ipfs/${UMAPROOT}

    ##########################################################
    ######### UMAP NOSTR PROFILE
    #### PUBLISH TO NOSTR
    echo "###################### PUBLISH UMAP PROFILE ##########################"
    ##########################################################
    UMAPNSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    
    # Check if ORE mode is activated for this UMAP
    ore_status=""
    if [[ -f "${UMAPPATH}/ore_mode.activated" ]]; then
        ore_status=" | 🌱 ORE MODE ACTIVE - Environmental obligations tracked"
    fi
    
    # Build optional arguments for ALL 4 image CIDs and update date
    UMAP_CID_ARGS=""
    [[ -n "$ZUMAP_CID" ]] && UMAP_CID_ARGS="$UMAP_CID_ARGS --umap_cid $ZUMAP_CID"       # zUmap.jpg (profile)
    [[ -n "$USAT_CID" ]] && UMAP_CID_ARGS="$UMAP_CID_ARGS --usat_cid $USAT_CID"         # Usat.jpg (banner)
    [[ -n "$UMAP_CID" ]] && UMAP_CID_ARGS="$UMAP_CID_ARGS --umap_full_cid $UMAP_CID"    # Umap.jpg (full road)
    [[ -n "$ZUSAT_CID" ]] && UMAP_CID_ARGS="$UMAP_CID_ARGS --usat_full_cid $ZUSAT_CID"  # zUsat.jpg (zoomed sat)
    [[ -n "$UMAPROOT" ]] && UMAP_CID_ARGS="$UMAP_CID_ARGS --umaproot $UMAPROOT"
    [[ -n "$UMAP_UPDATE_DATE" ]] && UMAP_CID_ARGS="$UMAP_CID_ARGS --umap_updated $UMAP_UPDATE_DATE"
    
    ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$UMAPNSEC" \
    "UMAP_${UPLANETG1PUB:0:8}${UMAP}${ore_status}" "${UMAPG1PUB}" \
    "${TODATE} JOURNAL : VISIO : ${VDONINJA}/?room=${UMAPG1PUB:0:8}&effects&record${ore_status}" \
    "${PIC_PROFILE}" \
    "${PIC_BANNER}" \
    "" "${myLIBRA}/ipfs/${UMAPROOT}" "" "${VDONINJA}/?room=${UMAPG1PUB:0:8}&effects&record" "" "" \
    "$myRELAY" \
    --zencard "$UPLANETNAME_G1" $UMAP_CID_ARGS

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
${MY_PATH}/../tools/nostr_setup_profile.py \
"$UPLANETNSEC" \
"UPLANET_${UPLANETG1PUB:0:8}" "${UPLANETG1PUB}" \
"VISIO ROOM : ${VDONINJA}/?room=${UPLANETG1PUB:0:8}&effects&record // UPlanet is a #Web3 key architecture offering Global #IPFS Storage through Geolocalized #Astroport Relays" \
"${myLIBRA}/ipfs/QmSuoBkXoY6Fh7AshD71AdPaJdfjtmQdTavyTFNzbir8KR/UPlanetORIGIN.png" \
"${myLIBRA}/ipfs/QmQMB9GkBXYdufZ7XicKsNsTFvN78G72co8vKrJrepXhs3/auto_heberger.jpg" \
"" "${myLIBRA}/ipns/copylaradio.com" "" "${VDONINJA}/?room=${UPLANETG1PUB:0:8}&effects&record" "" "" \
"$myRELAY" \
--zencard "$UPLANETNAME_G1" \
| tail -n 1 | rev | cut -d ' ' -f 1 | rev > ~/.zen/tmp/${IPFSNODEID}/UPLANET/HEX
####################################################################################

######################################################
exit 0
######################################################
