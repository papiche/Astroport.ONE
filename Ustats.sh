#!/bin/bash
######################## Ustats.sh
# analyse LOCAL & SWARM data structure
# and cache the result for 1 hour
####################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/tools/my.sh"

MLAT=$1
MLON=$2
MDEG=$3

## Check format
ULAT=$(makecoord $MLAT)
ULON=$(makecoord $MLON)
DEG=$(makecoord $MDEG)

# Create cache filename based on parameters
if [[ -n "$ULAT" && -n "$ULON" ]]; then
    CACHE_FILE="Ustats_${ULAT}_${ULON}_${DEG}.json"
else
    CACHE_FILE="Ustats.json"
fi

ISrunning=$(pgrep -au $USER -f "$ME" | wc -l)
[[ $ISrunning -gt 2 ]] && echo "ISrunning = $ISrunning" >&2 && echo "$HOME/.zen/tmp/${CACHE_FILE}" && exit 0

echo "=== $ME =============================== //$ULAT//$ULON" >&2
########################################
# Get start time for generation duration
GENERATION_START=$(date +%s)

# Check if cache exists and is less than 12 hours old
if [[ -s ~/.zen/tmp/${CACHE_FILE} ]]; then
    CACHE_AGE=$(($(date +%s) - $(stat -c %Y ~/.zen/tmp/${CACHE_FILE})))
    if [[ $CACHE_AGE -lt 43200 ]]; then  # 43200 seconds = 12 hours
        echo "Using cached data (age: ${CACHE_AGE}s)" >&2
        if jq -e . ~/.zen/tmp/${CACHE_FILE} >/dev/null 2>&1; then
            echo ~/.zen/tmp/${CACHE_FILE}
            exit 0
        else
            echo "[Ustats.sh] ERROR: Cache file is not valid JSON, regenerating: ~/.zen/tmp/${CACHE_FILE}" >&2
        fi
    else
        echo "Cache expired (age: ${CACHE_AGE}s), regenerating..." >&2
    fi
fi

# Function to calculate distance between two points (Haversine formula)
calculate_distance() {
    local lat1=$1
    local lon1=$2
    local lat2=$3
    local lon2=$4
    
    # Convert to radians
    local lat1_rad=$(echo "$lat1 * 0.0174533" | bc -l)
    local lon1_rad=$(echo "$lon1 * 0.0174533" | bc -l)
    local lat2_rad=$(echo "$lat2 * 0.0174533" | bc -l)
    local lon2_rad=$(echo "$lon2 * 0.0174533" | bc -l)
    
    # Haversine formula
    local dlat=$(echo "$lat2_rad - $lat1_rad" | bc -l)
    local dlon=$(echo "$lon2_rad - $lon1_rad" | bc -l)
    local a=$(echo "s($dlat/2)^2 + c($lat1_rad) * c($lat2_rad) * s($dlon/2)^2" | bc -l)
    local c=$(echo "2 * a(sqrt($a))" | bc -l)
    local distance=$(echo "6371 * $c" | bc -l)  # Earth radius in km
    
    echo "$distance"
}

# Function to find the 4 closest UMAPs to center coordinates
find_closest_umaps() {
    local center_lat=$1
    local center_lon=$2
    local umap_list=("${@:3}")
    
    echo "🔍 Finding 4 closest UMAPs to center ($center_lat, $center_lon)..." >&2
    
    # Array to store distances and UMAP data
    declare -a distances_umaps=()
    
    for umap in "${umap_list[@]}"; do
        # Extract lat/lon from UMAP name (format: _lat_lon)
        local umap_lat=$(echo "$umap" | cut -d '_' -f 2)
        local umap_lon=$(echo "$umap" | cut -d '_' -f 3)
        
        # Calculate distance to center
        local distance=$(calculate_distance "$center_lat" "$center_lon" "$umap_lat" "$umap_lon")
        
        # Store distance and UMAP name
        distances_umaps+=("$distance:$umap")
    done
    
    # Sort by distance and take the 4 closest
    IFS=$'\n' sorted_umaps=($(sort -t: -k1,1n <<<"${distances_umaps[*]}"))
    unset IFS
    
    # Extract the 4 closest UMAPs
    local closest_umaps=()
    for i in {0..3}; do
        if [[ $i -lt ${#sorted_umaps[@]} ]]; then
            local umap_data="${sorted_umaps[$i]}"
            local distance=$(echo "$umap_data" | cut -d ':' -f 1)
            local umap_name=$(echo "$umap_data" | cut -d ':' -f 2)
            closest_umaps+=("$umap_name")
            echo "   📍 UMAP $((i+1)): $umap_name (distance: ${distance}km)" >&2
        fi
    done
    
    echo "${closest_umaps[@]}"
}

if [[ ! -s ~/.zen/tmp/${CACHE_FILE} ]]; then
    ####################################
    # search for active Zen Cards
    ####################################
    echo " ## SEARCH PLAYER in ~/.zen/game/players/*@*.*/.player" >&2
    METW=($(ls -d ~/.zen/game/players/*@*.*/.player 2>/dev/null | rev | cut -d '/' -f 2 | rev | sort | uniq))

    echo "${#METW[@]} TW(S) : ${METW[@]}" >&2
    echo "===========================================================" >&2
    tw_array=()
    twcount=0
    for player in ${METW[@]}; do
        $(${MY_PATH}/tools/search_for_this_email_in_players.sh "$player" | tail -n 1)
        # Filter by geographic area if coordinates are provided
        if [[ -n "$ULAT" && -n "$ULON" && -n "$DEG" ]]; then
            # Convert coordinates to float for comparison
            LAT_FLOAT=$(echo "$LAT" | bc -l)
            LON_FLOAT=$(echo "$LON" | bc -l)
            ULAT_FLOAT=$(echo "$ULAT" | bc -l)
            ULON_FLOAT=$(echo "$ULON" | bc -l)
            DEG_FLOAT=$(echo "$DEG" | bc -l)

            # Check if coordinates are within the area
            LAT_IN_RANGE=$(echo "$LAT_FLOAT >= $ULAT_FLOAT && $LAT_FLOAT <= ($ULAT_FLOAT + $DEG_FLOAT)" | bc -l)
            LON_IN_RANGE=$(echo "$LON_FLOAT >= $ULON_FLOAT && $LON_FLOAT <= ($ULON_FLOAT + $DEG_FLOAT)" | bc -l)

            if [[ $LAT_IN_RANGE -eq 0 || $LON_IN_RANGE -eq 0 ]]; then
                continue
            fi
        fi

        echo "ASTROPORT=$ASTROPORT ASTROTW=$ASTROTW ZEN=$ZEN LAT=$LAT LON=$LON ASTROG1=$ASTROG1 ASTROMAIL=$ASTROMAIL ASTROFEED=$ASTROFEED HEX=$HEX TW=$TW source=$source" >&2
        # Construct JSON object using printf and associative array
        tw_obj=$(printf '{"ASTROPORT": "%s", "ASTROTW": "%s", "ZEN": "%s", "LAT": "%s", "LON": "%s", "ASTROG1": "%s", "ASTROMAIL": "%s", "ASTROFEED": "%s", "HEX": "%s", "SOURCE": "%s"}' \
                        "${myIPFS}$ASTROPORT" "${myIPFS}$ASTROTW" "$ZEN" "$LAT" "$LON" "$ASTROG1" "$ASTROMAIL" "${myIPFS}$ASTROFEED" "$HEX" "$source")
        tw_array+=("$tw_obj")
        [[ $ZEN -gt 0 ]] && twcount=$((twcount + 1))
    done
    echo "===========================================================" >&2
    ####################################
    # search for active NOSTR MULTIPASS
    ####################################
    echo " ## SEARCH HEX in ~/.zen/tmp/{12*,swarm/*}/TW/*/HEX" >&2
    MENOSTR=($(ls ~/.zen/tmp/$IPFSNODEID/TW/*/HEX ~/.zen/tmp/swarm/*/TW/*/HEX 2>/dev/null | rev | cut -d '/' -f 2 | rev | sort -u))

    echo "${#MENOSTR[@]} NOSTR MULTIPASS(S) : ${MENOSTR[@]}" >&2
    echo "===========================================================" >&2
    nostr_array=()
    nostrcount=0
    for player in ${MENOSTR[@]}; do
        $(${MY_PATH}/tools/search_for_this_email_in_nostr.sh "$player" | tail -n 1)
        [[ -z $LAT ]] && LAT="0.00"
        [[ -z $LON ]] && LON="0.00"

        # Filter by geographic area if coordinates are provided
        if [[ -n "$ULAT" && -n "$ULON" && -n "$DEG" ]]; then
            # Convert coordinates to float for comparison
            LAT_FLOAT=$(echo "$LAT" | bc -l)
            LON_FLOAT=$(echo "$LON" | bc -l)
            ULAT_FLOAT=$(echo "$ULAT" | bc -l)
            ULON_FLOAT=$(echo "$ULON" | bc -l)
            DEG_FLOAT=$(echo "$DEG" | bc -l)

            # Check if coordinates are within the area
            LAT_IN_RANGE=$(echo "$LAT_FLOAT >= $ULAT_FLOAT && $LAT_FLOAT <= ($ULAT_FLOAT + $DEG_FLOAT)" | bc -l)
            LON_IN_RANGE=$(echo "$LON_FLOAT >= $ULON_FLOAT && $LON_FLOAT <= ($ULON_FLOAT + $DEG_FLOAT)" | bc -l)

            if [[ $LAT_IN_RANGE -eq 0 || $LON_IN_RANGE -eq 0 ]]; then
                continue
            fi
        fi

        NCOINS=$(cat $HOME/.zen/tmp/coucou/${G1PUBNOSTR}.COINS 2>/dev/null)
        [[ -z "$NCOINS" ]] && NCOINS=$($MY_PATH/tools/G1check.sh ${G1PUBNOSTR} | tail -n 1)
        ZEN=$(echo "($NCOINS - 1) * 10" | bc | cut -d '.' -f 1  2>/dev/null)
        echo "export source=${source} HEX=${HEX} LAT=${LAT} LON=${LON} EMAIL=${EMAIL} G1PUBNOSTR=${G1PUBNOSTR} ZEN=${ZEN}" >&2
        # Construct JSON object using printf and associative array
        nostr_obj=$(printf '{"EMAIL": "%s", "HEX": "%s", "LAT": "%s", "LON": "%s", "G1PUBNOSTR": "%s", "ZEN": "%s"}' \
                        "${EMAIL}" "${HEX}" "$LAT" "$LON" "$G1PUBNOSTR" "$ZEN")
        nostr_array+=("$nostr_obj")
        [[ $ZEN -gt 0 ]] && nostrcount=$((nostrcount + 1))
    done
    ####################################
    # search for active UMAPS
    ####################################
    echo " ## SEARCH UMAPS in UPLANET/__/_*_*/_*.?_*.?/*" >&2
    MEMAPS=($(ls -td ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    SWARMMAPS=($(ls -Gd ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/* 2>/dev/null | rev | cut -d '/' -f 1 | rev | sort | uniq))
    combinedUMAPS=("${MEMAPS[@]}" "${SWARMMAPS[@]}")
    unique_combinedUMAPS=($(echo "${combinedUMAPS[@]}" | tr ' ' '\n' | sort -u))

    echo "${#unique_combinedUMAPS[@]} UMAP(S) : ${unique_combinedUMAPS[@]}" >&2
    echo "===========================================================" >&2

    # Find the 4 closest UMAPs if center coordinates are provided
    closest_umaps_array=()
    if [[ -n "$ULAT" && -n "$ULON" ]]; then
        echo "🎯 Calculating 4 closest UMAPs to center ($ULAT, $ULON)..." >&2
        closest_umaps=($(find_closest_umaps "$ULAT" "$ULON" "${unique_combinedUMAPS[@]}"))
        
        # Process only the closest UMAPs
        for umap in "${closest_umaps[@]}"; do
            if [[ -n "$umap" ]]; then
                lat=$(echo "$umap" | cut -d '_' -f 2)
                lon=$(echo "$umap" | cut -d '_' -f 3)

                echo "📍 Processing closest UMAP: $umap ($lat, $lon)" >&2
                $(${MY_PATH}/tools/getUMAP_ENV.sh "$lat" "$lon" | tail -n 1)
                echo "UMAPROOT=$UMAPROOT SECTORROOT=$SECTORROOT REGIONROOT=$REGIONROOT UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORHEX=$SECTORHEX SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONHEX=$REGIONHEX REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON" >&2
                
                # Construct JSON object for closest UMAP
                closest_umap_obj=$(printf '{"LAT": "%s", "LON": "%s", "UMAPROOT": "%s", "UMAPHEX": "%s", "UMAPG1PUB": "%s", "UMAPIPNS": "%s", "SECTORROOT": "%s", "SECTORHEX": "%s", "SECTORG1PUB": "%s", "SECTORIPNS": "%s", "REGIONROOT": "%s", "REGIONHEX": "%s", "REGIONG1PUB": "%s", "REGIONIPNS": "%s", "DISTANCE_KM": "%s"}' \
                                "$lat" "$lon" "${UMAPROOT}" "${UMAPHEX}" "${UMAPG1PUB}" "${myIPFS}${UMAPIPNS}" "${SECTORROOT}" "${SECTORHEX}" "${SECTORG1PUB}" "${myIPFS}${SECTORIPNS}" "${REGIONROOT}" "${REGIONHEX}" "${REGIONG1PUB}" "${myIPFS}${REGIONIPNS}" "$(calculate_distance "$ULAT" "$ULON" "$lat" "$lon")")
                closest_umaps_array+=("$closest_umap_obj")
            fi
        done
    fi

    # Array to store UMAP data (all UMAPs for backward compatibility)
    umap_array=()
    for umap in "${unique_combinedUMAPS[@]}"; do
        lat=$(echo "$umap" | cut -d '_' -f 2)
        lon=$(echo "$umap" | cut -d '_' -f 3)

        ## Adjust to layer grid
        # Filter by geographic area if coordinates are provided
        if [[ -n "$ULAT" && -n "$ULON" && -n "$DEG" ]]; then
            # Convert coordinates to float for comparison
            LAT_FLOAT=$(echo "$lat" | bc -l)
            LON_FLOAT=$(echo "$lon" | bc -l)
            ULAT_FLOAT=$(echo "$ULAT" | bc -l)
            ULON_FLOAT=$(echo "$ULON" | bc -l)
            DEG_FLOAT=$(echo "$DEG" | bc -l)

            # Check if coordinates are within the area
            LAT_IN_RANGE=$(echo "$LAT_FLOAT >= $ULAT_FLOAT && $LAT_FLOAT <= ($ULAT_FLOAT + $DEG_FLOAT)" | bc -l)
            LON_IN_RANGE=$(echo "$LON_FLOAT >= $ULON_FLOAT && $LON_FLOAT <= ($ULON_FLOAT + $DEG_FLOAT)" | bc -l)

            if [[ $LAT_IN_RANGE -eq 0 || $LON_IN_RANGE -eq 0 ]]; then
                continue
            fi
        fi

        echo "$lat $lon" >&2
        $(${MY_PATH}/tools/getUMAP_ENV.sh "$lat" "$lon" | tail -n 1)
        echo "UMAPROOT=$UMAPROOT SECTORROOT=$SECTORROOT REGIONROOT=$REGIONROOT UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORHEX=$SECTORHEX SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONHEX=$REGIONHEX REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON" >&2
        # Construct JSON object using printf and associative array, filter out UMAPs with no root
        umap_obj=$(printf '{"LAT": "%s", "LON": "%s", "UMAPROOT": "%s", "UMAPHEX": "%s", "UMAPG1PUB": "%s", "UMAPIPNS": "%s", "SECTORROOT": "%s", "SECTORHEX": "%s", "SECTORG1PUB": "%s", "SECTORIPNS": "%s", "REGIONROOT": "%s", "REGIONHEX": "%s", "REGIONG1PUB": "%s", "REGIONIPNS": "%s"}' \
                            "$lat" "$lon" "${UMAPROOT}" "${UMAPHEX}" "${UMAPG1PUB}" "${myIPFS}${UMAPIPNS}" "${SECTORROOT}" "${SECTORHEX}" "${SECTORG1PUB}" "${myIPFS}${SECTORIPNS}" "${REGIONROOT}" "${REGIONHEX}" "${REGIONG1PUB}" "${myIPFS}${REGIONIPNS}")
            umap_array+=("$umap_obj")
            echo
    done

    #########################################################
    # search for other active ASTROPORTs in UPlanet swarm
    #########################################################
    echo " ## SEARCH ASTROPORTs in ~/.zen/tmp/swarm/*/12345.json" >&2
    MASTROPORT=($(ls ~/.zen/tmp/swarm/*/12345.json 2>/dev/null | rev | cut -d '/' -f 2 | rev | sort | uniq))

    echo "${#MASTROPORT[@]} ASTROPORT(S) : ${MASTROPORT[@]}" >&2
    echo "===========================================================" >&2

    # Array to store SWARM data
    swarm_array=()
    for astroport in "${MASTROPORT[@]}"; do
        # Get the directory containing the 12345.json file
        astroport_dir=$(ls -d ~/.zen/tmp/swarm/*/12345.json | grep "$astroport" | xargs dirname)
        # echo "astroport_dir=$astroport_dir"
        # Read and validate the 12345.json file
        if [[ -s "$astroport_dir/12345.json" ]]; then
            if swarm_data=$(cat "$astroport_dir/12345.json" | jq -c '.'); then
                # Only include if it's not our own node
                if [[ $(echo "$swarm_data" | jq -r '.ipfsnodeid') != "$IPFSNODEID" ]]; then
                    echo "adding $astroport_dir/12345.json" >&2
                    swarm_array+=("$swarm_data")
                else
                    echo "skipping $astroport_dir/12345.json" >&2
                fi
            else
                echo "Skipping malformed or empty JSON file: $astroport_dir/12345.json" >&2
            fi
        fi
    done

    # Constructing JSON string using a more robust method:
    tw_json_array=$(printf '%s,' "${tw_array[@]}"); tw_json_array="${tw_json_array%,}" #remove trailing comma
    nostr_json_array=$(printf '%s,' "${nostr_array[@]}"); nostr_json_array="${nostr_json_array%,}" #remove trailing comma
    umap_array_str=$(printf '%s,' "${umap_array[@]}"); umap_array_str="${umap_array_str%,}" #remove trailing comma
    closest_umaps_json_array=$(printf '%s,' "${closest_umaps_array[@]}"); closest_umaps_json_array="${closest_umaps_json_array%,}" #remove trailing comma
    swarm_json_array=$(printf '%s,' "${swarm_array[@]}"); swarm_json_array="${swarm_json_array%,}" #remove trailing comma

    #######################################
    ## BILAN ZEN ECONOMY
    COINS=$(cat $HOME/.zen/tmp/coucou/$UPLANETG1PUB.COINS 2>/dev/null)
    [[ -z $COINS ]] && COINS=$($MY_PATH/tools/G1check.sh $UPLANETG1PUB | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1 2>/dev/null)

    [[ -z $PAF ]] && PAF=14
    [[ -z $NCARD ]] && NCARD=1
    [[ -z $ZCARD ]] && ZCARD=4
    INCOME=$((nostrcount * NCARD + twcount * ZCARD))
    BILAN=$((INCOME - PAF))

    # Add center coordinates and closest UMAPs to JSON if provided
    if [[ -n "$ULAT" && -n "$ULON" ]]; then
        final_json="{\"version\" : \"1.1\", \"DATE\": \"$(date -u)\", \"uSPOT\": \"$uSPOT\", \"PAF\": \"$PAF\", \"NCARD\": \"$NCARD\", \"ZCARD\": \"$ZCARD\", \"myRELAY\": \"$myRELAY\", \"IPFSNODEID\": \"$IPFSNODEID\", \"myIPFS\": \"${myIPFS}\", \"UPLANETG1PUB\": \"$UPLANETG1PUB\", \"G1\": \"$COINS\", \"ZEN\": \"$ZEN\", \"BILAN\": \"$BILAN\", \"CENTER\": {\"LAT\": \"$ULAT\", \"LON\": \"$ULON\", \"DEG\": \"$DEG\"}, \"CLOSEST_UMAPs\": [$closest_umaps_json_array], \"SWARM\": [$swarm_json_array], \"NOSTR\": [$nostr_json_array], \"PLAYERs\": [$tw_json_array], \"UMAPs\": [$umap_array_str]}"
    else
        final_json="{\"version\" : \"1.1\", \"DATE\": \"$(date -u)\", \"uSPOT\": \"$uSPOT\", \"PAF\": \"$PAF\", \"NCARD\": \"$NCARD\", \"ZCARD\": \"$ZCARD\", \"myRELAY\": \"$myRELAY\", \"IPFSNODEID\": \"$IPFSNODEID\", \"myIPFS\": \"${myIPFS}\", \"UPLANETG1PUB\": \"$UPLANETG1PUB\", \"G1\": \"$COINS\", \"ZEN\": \"$ZEN\", \"BILAN\": \"$BILAN\", \"SWARM\": [$swarm_json_array], \"NOSTR\": [$nostr_json_array], \"PLAYERs\": [$tw_json_array], \"UMAPs\": [$umap_array_str]}"
    fi

    # Calculate generation duration
    GENERATION_DURATION=$(($(date +%s) - GENERATION_START))

    # Add cache info to JSON
    final_json=$(echo "$final_json" | jq -c --arg date "$(date -u)" --arg duration "$GENERATION_DURATION" '. + {
        "GENERATION_TIME": $duration
    }')

    # Print and format the JSON string with pretty printing
    echo "$final_json" | jq '.' > ~/.zen/tmp/${CACHE_FILE}
fi
if jq -e . ~/.zen/tmp/${CACHE_FILE} >/dev/null 2>&1; then
    echo ~/.zen/tmp/${CACHE_FILE}
else
    echo "[Ustats.sh] ERROR: Cache file is not valid JSON after regeneration: ~/.zen/tmp/${CACHE_FILE}" >&2
    echo '{"error": "Cache file is not valid JSON after regeneration"}'
fi
exit 0
