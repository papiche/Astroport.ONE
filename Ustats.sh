#!/bin/bash
######################## Ustats.sh
# analyse LOCAL & SWARM data structure 
# and cache the result for 1 hour
####################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
ISrunning=$(pgrep -au $USER -f "$ME" | wc -l)
[[ $ISrunning -gt 2 ]] && echo "ISrunning = $ISrunning" && exit 0
. "${MY_PATH}/tools/my.sh"

ULAT=$1
ULON=$2
DEG=$3

# Create cache filename based on parameters
if [[ -n "$ULAT" && -n "$ULON" ]]; then
    CACHE_FILE="Ustats_${ULAT}_${ULON}_${DEG}.json"
else
    CACHE_FILE="Ustats.json"
fi

echo "=== $ME =============================== //$ULAT//$ULON"

# Check if cache exists and is less than 3 hours old
if [[ -s ~/.zen/tmp/${CACHE_FILE} ]]; then
    CACHE_AGE=$(($(date +%s) - $(stat -c %Y ~/.zen/tmp/${CACHE_FILE})))
    if [[ $CACHE_AGE -lt 43200 ]]; then  # 43200 seconds = 12 hours
        echo "Using cached data (age: ${CACHE_AGE}s)"
        echo ~/.zen/tmp/${CACHE_FILE}
        exit 0
    else
        echo "Cache expired (age: ${CACHE_AGE}s), regenerating..."
    fi
fi

if [[ ! -s ~/.zen/tmp/${CACHE_FILE} ]]; then
    ####################################
    # search for active TWS
    ####################################
    echo " ## SEARCH PLAYER in ~/.zen/game/players/*@*.*/.player"
    METW=($(ls -d ~/.zen/game/players/*@*.*/.player 2>/dev/null | rev | cut -d '/' -f 2 | rev | sort | uniq))

    echo "${#METW[@]} TW(S) : ${METW[@]}"
    echo "==========================================================="
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
        
        echo "ASTROPORT=$ASTROPORT ASTROTW=$ASTROTW ZEN=$ZEN LAT=$LAT LON=$LON ASTROG1=$ASTROG1 ASTROMAIL=$ASTROMAIL ASTROFEED=$ASTROFEED HEX=$HEX TW=$TW source=$source"
        # Construct JSON object using printf and associative array
        tw_obj=$(printf '{"ASTROPORT": "%s", "ASTROTW": "%s", "ZEN": "%s", "LAT": "%s", "LON": "%s", "ASTROG1": "%s", "ASTROMAIL": "%s", "ASTROFEED": "%s", "HEX": "%s", "SOURCE": "%s"}' \
                        "${myIPFS}$ASTROPORT" "${myIPFS}$ASTROTW" "$ZEN" "$LAT" "$LON" "$ASTROG1" "$ASTROMAIL" "${myIPFS}$ASTROFEED" "$HEX" "$source")
        tw_array+=("$tw_obj")
        [[ $ZEN -gt 0 ]] && twcount=$((twcount + 1))
    done
    echo "==========================================================="
    ####################################
    # search for active NOSTR MULTIPASS
    ####################################
    echo " ## SEARCH HEX in ~/.zen/game/nostr/*@*.*/HEX"
    MENOSTR=($(ls -d ~/.zen/game/nostr/*@*.*/HEX 2>/dev/null | rev | cut -d '/' -f 2 | rev | sort | uniq))

    echo "${#MENOSTR[@]} NOSTR MULTIPASS(S) : ${MENOSTR[@]}"
    echo "==========================================================="
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
        ZEN=$(echo "($NCOINS - 1) * 10" | bc | cut -d '.' -f 1  2>/dev/null)
        echo "export source=${source} HEX=${HEX} LAT=${LAT} LON=${LON} EMAIL=${EMAIL} G1PUBNOSTR=${G1PUBNOSTR} ZEN=${ZEN}"
        # Construct JSON object using printf and associative array
        nostr_obj=$(printf '{"EMAIL": "%s", "HEX": "%s", "LAT": "%s", "LON": "%s", "G1PUBNOSTR": "%s", "ZEN": "%s"}' \
                        "${EMAIL}" "${HEX}" "$LAT" "$LON" "$G1PUBNOSTR" "$ZEN")
        nostr_array+=("$nostr_obj")
        [[ $ZEN -gt 0 ]] && nostrcount=$((nostrcount + 1))
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
        
        echo "$lat $lon"
        $(${MY_PATH}/tools/getUMAP_ENV.sh "$lat" "$lon" | tail -n 1)
        echo "UMAPROOT=$UMAPROOT SECTORROOT=$SECTORROOT REGIONROOT=$REGIONROOT UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTOR=$SECTOR SECTORHEX=$SECTORHEX SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGION=$REGION REGIONHEX=$REGIONHEX REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"
        # Construct JSON object using printf and associative array
        umap_obj=$(printf '{"LAT": "%s", "LON": "%s", "UMAPROOT": "%s", "UMAPHEX": "%s", "UMAPG1PUB": "%s", "UMAPIPNS": "%s", "SECTORROOT": "%s", "SECTORHEX": "%s", "SECTORG1PUB": "%s", "SECTORIPNS": "%s", "REGIONROOT": "%s", "REGIONHEX": "%s", "REGIONG1PUB": "%s", "REGIONIPNS": "%s"}' \
                            "$lat" "$lon" "${UMAPROOT}" "${UMAPHEX}" "${UMAPG1PUB}" "${myIPFS}${UMAPIPNS}" "${SECTORROOT}" "${SECTORHEX}" "${SECTORG1PUB}" "${myIPFS}${SECTORIPNS}" "${REGIONROOT}" "${REGIONHEX}" "${REGIONG1PUB}" "${myIPFS}${REGIONIPNS}")
        umap_array+=("$umap_obj")
        echo
    done

    #Constructing JSON string using a more robust method:
    tw_json_array=$(printf '%s,' "${tw_array[@]}"); tw_json_array="${tw_json_array%,}" #remove trailing comma
    nostr_json_array=$(printf '%s,' "${nostr_array[@]}"); nostr_json_array="${nostr_json_array%,}" #remove trailing comma
    umap_array_str=$(printf '%s,' "${umap_array[@]}"); umap_array_str="${umap_array_str%,}" #remove trailing comma

    #######################################
    ## BILAN ZEN ECONOMY
    COINS=$(cat $HOME/.zen/tmp/coucou/$UPLANETG1PUB.COINS 2>/dev/null)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1 2>/dev/null)

    [[ -z $PAF ]] && PAF=56
    [[ -z $NCARD ]] && NCARD=4
    [[ -z $ZCARD ]] && ZCARD=15
    INCOME=$((nostrcount * NCARD + twcount * ZCARD))
    BILAN=$((INCOME - PAF))

    ########################################
    # Get start time for generation duration
    GENERATION_START=$(date +%s)
    
    final_json="{\"DATE\": \"$(date -u)\", \"♥BOX\": \"$myASTROPORT/12345\", \"PAF\": \"$PAF\", \"NCARD\": \"$NCARD\", \"ZCARD\": \"$ZCARD\", \"myRELAY\": \"$myRELAY\", \"IPFSNODEID\": \"$IPFSNODEID\", \"myIPFS\": \"${myIPFS}\", \"UPLANETG1PUB\": \"$UPLANETG1PUB\", \"ZEN\": \"$ZEN\", \"BILAN\": \"$BILAN\", \"NOSTR\": [$nostr_json_array], \"PLAYERs\": [$tw_json_array], \"UMAPs\": [$umap_array_str]}"
    
    # Calculate generation duration
    GENERATION_DURATION=$(($(date +%s) - GENERATION_START))
    
    # Add cache info to JSON
    final_json=$(echo "$final_json" | jq -c --arg date "$(date -u)" --arg duration "$GENERATION_DURATION" '. + {
        "GENERATION_TIME": $duration
    }')
    
    #Print and format INLINE the JSON string.
    echo "$final_json" | jq -rc '.' > ~/.zen/tmp/${CACHE_FILE}
fi
echo "$HOME/.zen/tmp/${CACHE_FILE}"
exit 0
