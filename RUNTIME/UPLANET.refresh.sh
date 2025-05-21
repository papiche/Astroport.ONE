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
    [[ ! -d ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ ]] && exit 1

    ####################################################################################
    ## UMAP DATA
    echo "WRITE DATA ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"
    ####################################################################################
    ####################################################################################
    ## WRITE NOSTR HEX ADDRESS USED FOR strfry whitelisting
    NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    HEX=$(${MY_PATH}/../tools/nostr2hex.py $NPUB)
    #~ mkdir -p ~/.zen/game/nostr/UMAP_${SLAT}_${SLON} # Add to nostr Whitelist # DONE by NODE.refresh.sh
    #~ echo "$HEX" \
        #~ > ~/.zen/game/nostr/UMAP_${SLAT}_${SLON}/HEX
    echo "$HEX" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX
    echo "$NPUB" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/NPUB
    ####################################################################################
    echo "${UMAPG1PUB}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB

    SECTORNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    SECTORHEX=$(${MY_PATH}/../tools/nostr2hex.py $SECTORNPUB)
    echo "${SECTORHEX}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX_SECTOR
    echo "${SECTORHEX}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/HEX
    echo "${SECTORG1PUB}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORG1PUB

    REGIONNPUB=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
    REGIONHEX=$(${MY_PATH}/../tools/nostr2hex.py $REGIONNPUB)
    echo "${REGIONHEX}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/HEX_REGION
    echo "${REGIONHEX}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/HEX
    echo "${REGIONG1PUB}" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONG1PUB

    ####################################################################################
    ## COPY SECTOR & REGION IFPSROOT
    ## SWARM INIT
    cat ~/.zen/tmp/swarm/*/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE}  2>/dev/null | tail -f 1 2>/dev/null \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORROOT

    cat ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} 2>/dev/null | tail -f 1 2>/dev/null \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONROOT

    ## LOCAL UPDATE
    [[ -s ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} ]] \
        && cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}_${RLON}/_${SLAT}_${SLON}/ipfs.${TODATE} \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORROOT

    [[ -s ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} ]] \
        && cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_${RLAT}_${RLON}/ipfs.${TODATE} \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/REGIONROOT
    ####################################################################################

    ##################################
    ### UMAP = 0.01° Planet Slice
    UMAPGEN="/ipns/copylaradio.com/Umap.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipfs=${UMAPROOT}"
    USATGEN="/ipns/copylaradio.com/Usat.html?southWestLat=${LAT}&southWestLon=${LON}&deg=0.01&ipfs=${UMAPROOT}"
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${UMAPGEN}'\" />" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/Umap.html
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${USATGEN}'\" />" \
        > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/Usat.html

    ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/

    UMAPROOT=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/* | tail -n 1)
    ######################## EASY IPFS BLOCKCHAIN
    ## UMAPROOT : ipfs link rolling calendar
    echo "${UMAPROOT}" > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ipfs.${DEMAINDATE}
    rm ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/ipfs.${YESTERDATE} 2>/dev/null

    ######### UMAP GCHANGE & CESIUM PROFILE
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${UMAP}.dunikey "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}"
    ################# PUBLISH UPlanet UMAP to G1PODs
    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${UMAP}.dunikey -n ${myDATA} \
            set -n "UMAP_${UPLANETG1PUB:0:8}${UMAP}" -v " " -a " " -d "UPlanet ${UPLANETG1PUB}" \
            -pos ${LAT} ${LON} -s ${myLIBRA}/ipfs/${UMAPROOT} \
            -A ${MY_PATH}/../images/extension_territoire.jpg

    ${MY_PATH}/../tools/timeout.sh -t 20 \
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${UMAP}.dunikey -n ${myCESIUM} \
            set -n "UMAP_${UPLANETG1PUB:0:8}${UMAP}" -v " " -a " " -d "UPlanet ${UPLANETG1PUB}" \
            -pos ${LAT} ${LON} -s ${myLIBRA}/ipfs/${UMAPROOT} \
            -A ${MY_PATH}/../images/extension_territoire.jpg

    ######### UMAP NOSTR PROFILE
    #### PUBLISH TO NOSTR
    echo "#####################################################################"
    echo "###################### UMAP NOSTR PROFILE ##########################"
    echo "#####################################################################"
    UMAPNSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$UMAPNSEC" \
    "UMAP_${UPLANETG1PUB:0:8}${UMAP}" "${UMAPG1PUB}" \
    "UPlanet ${TODATE}${UMAP} JOURNAL - VISIO : $myIPFS$VDONINJA/?room=${UMAPG1PUB:0:8}&effects&record" \
    "${myIPFS}/ipfs/QmXY2JY7cNTA3JnkpV7vdqcr9JjKbeXercGPne8Ge8Hkbw" \
    "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
    "" "${myIPFS}/ipfs/${UMAPROOT}" "" "$myIPFS$VDONINJA/?room=${UMAPG1PUB:0:8}&effects&record" "" "" \
    "$myRELAY" "wss://relay.copylaradio.com"

    rm ~/.zen/tmp/${MOATS}/${UMAP}.dunikey

done


####################################################################################
####################################################################################
## UPLANET ZEN -- follow -> UPlanet ORIGIN
####################################################################################
ZENNSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}" "${UPLANETNAME}" -s)
originpub=$(${MY_PATH}/../tools/keygen -t nostr "EnfinLibre" "EnfinLibre")
originhex=$(${MY_PATH}/../tools/nostr2hex.py $originpub)
if [[ ${UPLANETNAME} == "EnfinLibre" ]]; then
    echo "UPLANET ORIGIN : Seek for ${originhex} followers"
    ${MY_PATH}/../tools/nostr_followers.sh "${originhex}"
else
    ## UPLANET Ẑen ---- > follow UPlanet ORIGIN
    originhex=$(${MY_PATH}/../tools/nostr2hex.py $originpub)
    echo "UPLANET ZEN - follow -> UPlanet ORIGIN : ${originhex}"
    ${MY_PATH}/../tools/nostr_follow.sh "$ZENNSEC" "${originhex}"
fi
####################################################
## SETUP UPLANET PROFILE + UPLANET/HEX signaling
rm ~/.zen/tmp/${IPFSNODEID}/UPLANET/HEX ## TODO REMOVE : chain format re-updating
if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/UPLANET/HEX ]]; then
    ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$ZENNSEC" \
    "UPLANET_${UPLANETG1PUB:0:8}" "${UPLANETG1PUB}" \
    "VISIO ROOM : $myIPFS$VDONINJA/?room=${UPLANETG1PUB:0:8}&effects&record // UPlanet is a #Web3 key architecture offering Global #IPFS Storage through Geolocalized #Astroport Relays" \
    "${myIPFS}/ipfs/QmSuoBkXoY6Fh7AshD71AdPaJdfjtmQdTavyTFNzbir8KR/UPlanetORIGIN.png" \
    "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
    "" "${myIPFS}/ipns/copylaradio.com" "" "$myIPFS$VDONINJA/?room=${UPLANETG1PUB:0:8}&effects&record" "" "" \
    "$myRELAY" "wss://relay.copylaradio.com" \
                --ipfs_gw "$myIPFS" \
                --ipns_vault "/ipns/${NOSTRNS}" \
    | tail -n 1 | rev | cut -d ' ' -f 1 | rev > ~/.zen/tmp/${IPFSNODEID}/UPLANET/HEX
fi
####################################################################################
## TODO FILTER NOSTR MESSAGES WITH IPFS 127.0.0.1

######################################################
exit 0
######################################################
