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

    ## SEARCH UMAP
    UMAPS=($(ls -t ~/.zen/tmp/${IPFSNODEID}/UPLANET/ 2>/dev/null))
    echo "FOUND : ${UMAPS[@]}"

    for UMAP in ${UMAPS[@]}; do

        echo ">>> REFRESHING ${UMAP}"
        LAT=$(echo ${UMAP} | cut -d '_' -f 2)
        LON=$(echo ${UMAP} | cut -d '_' -f 3)
        ##############################################################
        WALLET=$(${MY_PATH}/../tools/keygen -t duniter "$LAT" "$LON")
        [[ ! ${WALLET} ]] && echo "ERROR generating WALLET" && exit 1
        echo "ACTUAL UMAP WALLET : ${WALLET}"
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/WALLET.priv "$LAT" "$LON"
        ipfs key rm ${WALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        UMAPNS=$(ipfs key import ${WALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/WALLET.priv)

        ## GET ONLINE UMAPNS
        mkdir ~/.zen/tmp/${MOATS}/${UMAP}
        ipfs get -o ~/.zen/tmp/${MOATS}/${UMAP}/ /ipns/${UMAPNS}/

        [[ ! -d ~/.zen/tmp/${MOATS}/${UMAP}/${UMAP} ]] \
            && echo "UMAP IS BAD FORMAT - PLEASE CORRECT -" \
            && exit 1


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
        SWUMAPNS=$(ipfs key import ${NWWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NWWALLET.priv)
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
        SWUMAPNS=$(ipfs key import ${NEWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NEWALLET.priv)
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
        SWUMAPNS=$(ipfs key import ${SEWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SEWALLET.priv)
        ipfs key rm ${SEWALLET}

    done

