#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

. "$MY_PATH/my.sh"


LAT=$1
LON=$2
UMAP=$3
MOATS=$4
UMAPNS=$5

[[ ! -d ~/.zen/tmp/${MOATS-undefined}/${UMAP-undefined}/${LAT}_${LON} ]] && echo "MUST BE CALLED FROM UPLANET.refresh.sh - EXIT -" && exit 1

       ##############################################################
        ## CALCULATE SURROUNDING UMAPS
        ##############################################################
        # North Umap
        NLAT=$(echo "${LAT} + 0.01" | bc)
        NLON="${LON}"
        NWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$NLAT" "${YESTERDATE}${UPLANETNAME}$NLON")
        [[ ! ${NWALLET} ]] && echo "ERROR generating NWALLET" && exit 1
        echo "NORTH UMAP NWALLET : ${NWALLET}"
        ipfs key rm ${NWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NWALLET.priv "${YESTERDATE}${UPLANETNAME}$NLAT" "${YESTERDATE}${UPLANETNAME}$NLON"
        NUMAPNS=$(ipfs key import ${NWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NWALLET.priv)
        ipfs key rm ${NWALLET}

        ##############################################################
        # South Umap
        SLAT=$(echo "${LAT} - 0.01" | bc)
        SLON="${LON}"
        SWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$SLAT" "${YESTERDATE}${UPLANETNAME}$SLON")
        [[ ! ${SWALLET} ]] && echo "ERROR generating SWALLET" && exit 1
        echo "SOUTH UMAP SWALLET : ${SWALLET}"
        ipfs key rm ${SWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SWALLET.priv "${YESTERDATE}${UPLANETNAME}$SLAT" "${YESTERDATE}${UPLANETNAME}$SLON"
        SUMAPNS=$(ipfs key import ${SWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SWALLET.priv)
        ipfs key rm ${SWALLET}

        ##############################################################
        # West Umap
        WLAT="${LAT}"
        WLON=$(echo "${LON} - 0.01" | bc)
        WWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$WLAT" "${YESTERDATE}${UPLANETNAME}$WLON")
        [[ ! ${WWALLET} ]] && echo "ERROR generating WWALLET" && exit 1
        echo "WEST UMAP WWALLET : ${WWALLET}"
        ipfs key rm ${WWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/WWALLET.priv "${YESTERDATE}${UPLANETNAME}$WLAT" "${YESTERDATE}${UPLANETNAME}$WLON"
        WUMAPNS=$(ipfs key import ${WWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/WWALLET.priv)
        ipfs key rm ${WWALLET}

        ##############################################################
        # East Umap
        ELAT="${LAT}"
        ELON=$(echo "${LON} + 0.01" | bc)
        EWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$ELAT" "${YESTERDATE}${UPLANETNAME}$ELON")
        [[ ! ${EWALLET} ]] && echo "ERROR generating EWALLET" && exit 1
        echo "EAST UMAP EWALLET : ${EWALLET}"
        ipfs key rm ${EWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/EWALLET.priv "${YESTERDATE}${UPLANETNAME}$ELAT" "${YESTERDATE}${UPLANETNAME}$ELON"
        EUMAPNS=$(ipfs key import ${EWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/EWALLET.priv)
        ipfs key rm ${EWALLET}

        ##############################################################
        # South West Umap
        SWLAT=$(echo "${LAT} - 0.01" | bc)
        SWLON=$(echo "${LON} - 0.01" | bc)
        SWWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$SWLAT" "${YESTERDATE}${UPLANETNAME}$SWLON")
        [[ ! ${SWWALLET} ]] && echo "ERROR generating SWWALLET" && exit 1
        echo "SOUTH WEST UMAP SWWALLET : ${SWWALLET}"
        ipfs key rm ${SWWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SWWALLET.priv "${YESTERDATE}${UPLANETNAME}$SWLAT" "${YESTERDATE}${UPLANETNAME}$SWLON"
        SWUMAPNS=$(ipfs key import ${SWWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/SWWALLET.priv)
        ipfs key rm ${SWWALLET}

        ##############################################################
        # North West Umap
        NWLAT=$(echo "${LAT} + 0.01" | bc)
        NWLON=$(echo "${LON} - 0.01" | bc)
        NWWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$NWLAT" "${YESTERDATE}${UPLANETNAME}$NWLON")
        [[ ! ${NWWALLET} ]] && echo "ERROR generating NWWALLET" && exit 1
        echo "NORTH WEST UMAP NWWALLET : ${NWWALLET}"
        ipfs key rm ${NWWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NWWALLET.priv "${YESTERDATE}${UPLANETNAME}$NWLAT" "${YESTERDATE}${UPLANETNAME}$NWLON"
        NWUMAPNS=$(ipfs key import ${NWWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NWWALLET.priv)
        ipfs key rm ${NWWALLET}

        ##############################################################
        # North East Umap
        NELAT=$(echo "${LAT} + 0.01" | bc)
        NELON=$(echo "${LON} + 0.01" | bc)
        NEWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$NELAT" "${YESTERDATE}${UPLANETNAME}$NELON")
        [[ ! ${NEWALLET} ]] && echo "ERROR generating NEWALLET" && exit 1
        echo "NORTH EAST UMAP NEWALLET : ${NEWALLET}"
        ipfs key rm ${NEWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/NEWALLET.priv "${YESTERDATE}${UPLANETNAME}$NELAT" "${YESTERDATE}${UPLANETNAME}$NELON"
        NEUMAPNS=$(ipfs key import ${NEWALLET} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/NEWALLET.priv)
        ipfs key rm ${NEWALLET}

        ##############################################################
        # South East Umap
        SELAT=$(echo "${LAT} - 0.01" | bc)
        SELON=$(echo "${LON} + 0.01" | bc)
        SEWALLET=$(${MY_PATH}/keygen -t duniter "${YESTERDATE}${UPLANETNAME}$SELAT" "${YESTERDATE}${UPLANETNAME}$SELON")
        [[ ! ${SEWALLET} ]] && echo "ERROR generating SEWALLET" && exit 1
        echo "SOUTH EAST UMAP SEWALLET : ${SEWALLET}"
        ipfs key rm ${SEWALLET} > /dev/null 2>&1 ## AVOID ERROR ON IMPORT
        ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/SEWALLET.priv "${YESTERDATE}${UPLANETNAME}$SELAT" "${YESTERDATE}${UPLANETNAME}$SELON"
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

exit 0
