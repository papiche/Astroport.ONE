#!/bin/bash
######################## Ustats.sh
# analyse LOCAL & SWARM data structure
####################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/tools/my.sh"
if [[ ! -s ~/.zen/tmp/Ustats.json ]]; then
    echo "==========================================================="
    ####################################
    # search for active TWS
    ####################################
    echo " ## SEARCH TW in UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/TW/*"
    METW=($(ls -d ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/TW/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    SWARMTW=($(ls -d ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??/TW/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    combined=("${METW[@]}" "${SWARMTW[@]}")
    unique_combined=($(echo "${combined[@]}" | tr ' ' '\n' | sort -u))

    echo "${#unique_combined[@]} TW(S) : ${unique_combined[@]}"
    echo "==========================================================="
    tw_array=()
    for player in ${unique_combined[@]}; do
        $(${MY_PATH}/tools/search_for_this_email_in_players.sh "$player" | tail -n 1)
        echo "ASTROPORT=$ASTROPORT ASTROTW=$ASTROTW LAT=$LAT LON=$LON ASTROG1=$ASTROG1 ASTROMAIL=$ASTROMAIL ASTROFEED=$ASTROFEED TW=$TW source=$source"
        # Construct JSON object using printf and associative array
        tw_obj=$(printf '{"ASTROPORT": "%s", "ASTROTW": "%s", "LAT": "%s", "LON": "%s", "ASTROG1": "%s", "ASTROMAIL": "%s", "ASTROFEED": "%s", "TW": "%s", "SOURCE": "%s"}' \
                        "$ASTROPORT" "$ASTROTW" "$LAT" "$LON" "$ASTROG1" "$ASTROMAIL" "$ASTROFEED" "$TW" "$source")
        tw_array+=("$tw_obj")
    done
    ####################################
    # search for active UMAPS
    ####################################
    echo " ## SEARCH UMAPS in UPLANET/__/_*_*/_*.?_*.?/*"
    MEMAPS=($(ls -td ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    SWARMMAPS=($(ls -Gd ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    combinedUMAPS=("${MEMAPS[@]}" "${SWARMMAPS[@]}")
    unique_combinedUMAPS=($(echo "${combinedUMAPS[@]}" | tr ' ' '\n' | sort -u))

    echo "${#unique_combinedUMAPS[@]} UMAP(S) : ${unique_combinedUMAPS[@]}"
    echo "==========================================================="

    # Array to store UMAP data
    umap_array=()
    for umap in "${unique_combinedUMAPS[@]}"; do
        lat=$(echo "$umap" | cut -d '_' -f 2)
        lon=$(echo "$umap" | cut -d '_' -f 3)
        echo "$lat $lon"
        $(${MY_PATH}/tools/getUMAP_ENV.sh "$lat" "$lon" | tail -n 1)
        echo "UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"
        # Construct JSON object using printf and associative array
        umap_obj=$(printf '{"LAT": "%s", "LON": "%s", "UMAPG1PUB": "%s", "UMAPIPNS": "%s", "SECTORG1PUB": "%s", "SECTORIPNS": "%s", "REGIONG1PUB": "%s", "REGIONIPNS": "%s"}' \
                            "$lat" "$lon" "${UMAPG1PUB}" "${UMAPIPNS}" "${SECTORG1PUB}" "${SECTORIPNS}" "${REGIONG1PUB}" "${REGIONIPNS}")
        umap_array+=("$umap_obj")
        echo
    done

    #Constructing JSON string using a more robust method:
    tw_json_array=$(printf '%s,' "${tw_array[@]}"); tw_json_array="${tw_json_array%,}" #remove trailing comma
    umap_array_str=$(printf '%s,' "${umap_array[@]}"); umap_array_str="${umap_array_str%,}" #remove trailing comma

    final_json="{\"DATE\": \"$(date -u)\", \"MOATS\": \"$MOATS\", \"IPFSNODEID\": \"$IPFSNODEID\", \"myIPFS\": \"${myIPFS}\", \"UPLANETG1PUB\": \"$(${MY_PATH}/tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}")\", \"PLAYERs\": [$tw_json_array], \"UMAPs\": [$umap_array_str]}"

    #Print and format INLINE the JSON string.
    echo "$final_json" | jq -rc '.' > ~/.zen/tmp/Ustats.json
fi
echo "$HOME/.zen/tmp/Ustats.json"
exit 0
