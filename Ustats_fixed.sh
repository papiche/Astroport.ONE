#!/bin/bash
######################## Ustats_fixed.sh
# FIXED VERSION - Quick fix for collection bug
# Based on Ustats_enhanced.sh but with corrected result collection
####################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/tools/my.sh"

# Simple performance flags
TURBO_MODE=false
PARALLEL_JOBS=4
DEBUG_TIMING=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --turbo)
            TURBO_MODE=true
            shift
            ;;
        --debug-timing)
            DEBUG_TIMING=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--turbo] [--debug-timing] [ULAT] [ULON] [DEG]"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

ULAT=$1
ULON=$2
DEG=$3

# Performance timing function
time_start() {
    [[ $DEBUG_TIMING == true ]] && echo "$(date +%s%3N)" || echo "0"
}

time_elapsed() {
    if [[ $DEBUG_TIMING == true ]]; then
        local start="$1"
        local end="$(date +%s%3N)"
        echo "$((end - start))ms" >&2
    fi
}

# Enhanced cache configuration
CACHE_BASE_DIR="${HOME}/.zen/tmp/ustats_fixed"
CACHE_DIR="${CACHE_BASE_DIR}/cache"
mkdir -p "$CACHE_DIR"

# Cache file naming
if [[ -n "$ULAT" && -n "$ULON" ]]; then
    CACHE_KEY="${ULAT}_${ULON}_${DEG}"
    CACHE_FILE="${CACHE_DIR}/Ustats_${CACHE_KEY}.json"
else
    CACHE_KEY="global"
    CACHE_FILE="${CACHE_DIR}/Ustats.json"
fi

# Performance monitoring
GENERATION_START=$(date +%s)
PERF_START=$(time_start)

# Check cache validity
check_cache_validity() {
    local cache_file="$1"
    local max_age="$2"
    
    [[ -s "$cache_file" ]] && 
    [[ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt $max_age ]] &&
    jq -e . "$cache_file" >/dev/null 2>&1
}

# Check main cache (12 hours)
if check_cache_validity "$CACHE_FILE" 43200; then
    echo "Using cached data ($(stat -c %Y "$CACHE_FILE"))" >&2
    echo "$CACHE_FILE"
    exit 0
fi

echo "=== Ustats_fixed.sh =============================== //$ULAT//$ULON" >&2

# Fast coordinate bounds checking
is_coordinate_in_bounds() {
    local lat="$1" lon="$2" ulat="$3" ulon="$4" deg="$5"
    
    awk -v lat="$lat" -v lon="$lon" -v ulat="$ulat" -v ulon="$ulon" -v deg="$deg" '
        BEGIN {
            if (lat >= ulat && lat <= (ulat + deg) && lon >= ulon && lon <= (ulon + deg)) {
                print "1"
            } else {
                print "0"
            }
        }'
}

# FIXED: Collect PLAYERs data
collect_players_data() {
    local ulat="$1" ulon="$2" deg="$3"
    local players_start=$(time_start)
    
    echo "🎮 Processing PLAYERs..." >&2
    
    local results=()
    
    # Get all players
    while IFS= read -r email; do
        [[ -z "$email" ]] && continue
        
        local player_dir="$HOME/.zen/game/players/${email}"
        
        if [[ -f "${player_dir}/.player" ]]; then
            # Extract player data directly using source like original script
            local astroport="" astrotw="" zen="0" lat="0.00" lon="0.00" astrog1="" hex="null" astrofeed=""
            
            # Source .player file to get all variables like original
            source "${player_dir}/.player" 2>/dev/null
            astroport="$ASTROPORT"
            astrotw="$ASTROTW"
            astrofeed="$ASTROFEED"
            astrog1="$ASTROG1"
            
            # GPS coordinates
            if [[ -f "${player_dir}/GPS" ]]; then
                source "${player_dir}/GPS" 2>/dev/null
            fi
            [[ -z $LAT ]] && LAT="0.00"
            [[ -z $LON ]] && LON="0.00"
            
            # ZEN calculation from G1 coins
            if [[ -n "$astrog1" ]]; then
                local coins=$(cat ~/.zen/tmp/coucou/$astrog1.COINS 2>/dev/null)
                [[ -n "$coins" ]] && zen=$(echo "($coins - 1) * 10" | bc 2>/dev/null | cut -d '.' -f 1)
            fi
            
            # HEX from player or NOSTR
            hex=$(cat "${player_dir}/HEX" 2>/dev/null)
            [[ -z "$hex" ]] && hex=$(cat ~/.zen/game/nostr/${email}/HEX 2>/dev/null)
            [[ -z "$hex" ]] && hex="null"
            
            # Geographic filtering if coordinates provided
            if [[ -n "$ulat" && -n "$ulon" && -n "$deg" ]]; then
                if [[ "$(is_coordinate_in_bounds "$LAT" "$LON" "$ulat" "$ulon" "$deg")" == "1" ]]; then
                    # Clean variables and create JSON
                    astroport=$(echo "$astroport" | tr -d '\n\r\t' | tr -cd '[:print:]')
                    astrotw=$(echo "$astrotw" | tr -d '\n\r\t' | tr -cd '[:print:]')
                    astrofeed=$(echo "$astrofeed" | tr -d '\n\r\t' | tr -cd '[:print:]')
                    
                    local player_json=$(printf '{"ASTROPORT":"%s","ASTROTW":"%s","ZEN":"%s","LAT":"%s","LON":"%s","ASTROG1":"%s","ASTROMAIL":"%s","ASTROFEED":"%s","HEX":"%s","SOURCE":"LOCAL"}' \
                           "${myIPFS}${astroport}" "${myIPFS}${astrotw}" "$zen" "$LAT" "$LON" "$astrog1" "$email" "${myIPFS}${astrofeed}" "$hex")
                    
                    results+=("$player_json")
                fi
            else
                # No geographic filtering
                astroport=$(echo "$astroport" | tr -d '\n\r\t' | tr -cd '[:print:]')
                astrotw=$(echo "$astrotw" | tr -d '\n\r\t' | tr -cd '[:print:]')
                astrofeed=$(echo "$astrofeed" | tr -d '\n\r\t' | tr -cd '[:print:]')
                
                local player_json=$(printf '{"ASTROPORT":"%s","ASTROTW":"%s","ZEN":"%s","LAT":"%s","LON":"%s","ASTROG1":"%s","ASTROMAIL":"%s","ASTROFEED":"%s","HEX":"%s","SOURCE":"LOCAL"}' \
                       "${myIPFS}${astroport}" "${myIPFS}${astrotw}" "$zen" "$LAT" "$LON" "$astrog1" "$email" "${myIPFS}${astrofeed}" "$hex")
                
                results+=("$player_json")
            fi
        fi
    done < <(find ~/.zen/game/players -maxdepth 1 -type d -name "*@*.*" -printf "%f\n" 2>/dev/null)
    
    # Output as JSON array
    if [[ ${#results[@]} -gt 0 ]]; then
        printf '[%s]' "$(IFS=','; echo "${results[*]}")"
    else
        echo "[]"
    fi
    
    time_elapsed "$players_start"
}

# FIXED: Collect NOSTR data
collect_nostr_data() {
    local ulat="$1" ulon="$2" deg="$3"
    local nostr_start=$(time_start)
    
    echo "🚀 Processing NOSTR..." >&2
    
    local results=()
    
    # Get all NOSTR users
    while IFS= read -r email; do
        [[ -z "$email" ]] && continue
        
        if [[ -f "$HOME/.zen/game/nostr/${email}/HEX" ]]; then
            local hex=$(cat "$HOME/.zen/game/nostr/${email}/HEX" 2>/dev/null)
            local lat="0.00" lon="0.00"
            
            # GPS coordinates
            if [[ -f "$HOME/.zen/game/nostr/${email}/GPS" ]]; then
                source "$HOME/.zen/game/nostr/${email}/GPS" 2>/dev/null
            fi
            [[ -z $LAT ]] && LAT="0.00"
            [[ -z $LON ]] && LON="0.00"
            lat="$LAT"
            lon="$LON"
            
            local g1pubnostr=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
            
            # Calculate ZEN from COINS
            local zen="0"
            if [[ -n "$g1pubnostr" ]]; then
                local ncoins=$(cat ~/.zen/tmp/coucou/${g1pubnostr}.COINS 2>/dev/null)
                [[ -n "$ncoins" ]] && zen=$(echo "($ncoins - 1) * 10" | bc 2>/dev/null | cut -d '.' -f 1)
            fi
            
            # Geographic filtering if coordinates provided
            if [[ -n "$ulat" && -n "$ulon" && -n "$deg" ]]; then
                if [[ "$(is_coordinate_in_bounds "$lat" "$lon" "$ulat" "$ulon" "$deg")" == "1" ]]; then
                    # Clean variables and create JSON
                    hex=$(echo "$hex" | tr -d '\n\r\t' | tr -cd '[:print:]')
                    g1pubnostr=$(echo "$g1pubnostr" | tr -d '\n\r\t' | tr -cd '[:print:]')
                    
                    local nostr_json=$(printf '{"EMAIL":"%s","HEX":"%s","LAT":"%s","LON":"%s","G1PUBNOSTR":"%s","ZEN":"%s"}' \
                           "$email" "$hex" "$lat" "$lon" "$g1pubnostr" "$zen")
                    
                    results+=("$nostr_json")
                fi
            else
                # No geographic filtering
                hex=$(echo "$hex" | tr -d '\n\r\t' | tr -cd '[:print:]')
                g1pubnostr=$(echo "$g1pubnostr" | tr -d '\n\r\t' | tr -cd '[:print:]')
                
                local nostr_json=$(printf '{"EMAIL":"%s","HEX":"%s","LAT":"%s","LON":"%s","G1PUBNOSTR":"%s","ZEN":"%s"}' \
                       "$email" "$hex" "$lat" "$lon" "$g1pubnostr" "$zen")
                
                results+=("$nostr_json")
            fi
        fi
    done < <(find ~/.zen/game/nostr -maxdepth 1 -type d -name "*@*.*" -printf "%f\n" 2>/dev/null)
    
    # Output as JSON array
    if [[ ${#results[@]} -gt 0 ]]; then
        printf '[%s]' "$(IFS=','; echo "${results[*]}")"
    else
        echo "[]"
    fi
    
    time_elapsed "$nostr_start"
}

# FIXED: Collect SWARM data
collect_swarm_data() {
    local swarm_start=$(time_start)
    
    echo "🌐 Processing SWARM..." >&2
    
    local swarm_files=($(find ~/.zen/tmp/swarm -name "12345.json" 2>/dev/null))
    local results=()
    
    for swarm_file in "${swarm_files[@]}"; do
        if [[ -s "$swarm_file" ]] && jq -e . "$swarm_file" >/dev/null 2>&1; then
            local node_id=$(jq -r '.ipfsnodeid // ""' "$swarm_file")
            if [[ "$node_id" != "$IPFSNODEID" && -n "$node_id" ]]; then
                results+=("$(cat "$swarm_file")")
            fi
        fi
    done
    
    # Output as JSON array
    if [[ ${#results[@]} -gt 0 ]]; then
        printf '[%s]' "$(IFS=','; echo "${results[*]}")"
    else
        echo "[]"
    fi
    
    time_elapsed "$swarm_start"
}

# FIXED: Collect UMAPs data
collect_umaps_data() {
    local ulat="$1" ulon="$2" deg="$3"
    local umaps_start=$(time_start)
    
    echo "🗺️ Processing UMAPs..." >&2
    
    local results=()
    
    # Get UMAPs from UPLANET directory like original script
    while IFS= read -r umap_dir; do
        [[ -z "$umap_dir" ]] && continue
        
        # Extract coordinates from directory name (_lat_lon)
        local coords=$(basename "$umap_dir")
        if [[ "$coords" =~ ^_([0-9.-]+)_([0-9.-]+)$ ]]; then
            local lat="${BASH_REMATCH[1]}"
            local lon="${BASH_REMATCH[2]}"
            
            # Get UMAP data using the original script's getUMAP_ENV.sh
            local umap_env_output=$("$MY_PATH/tools/getUMAP_ENV.sh" "$lat" "$lon" | tail -n 1)
            if [[ -n "$umap_env_output" ]]; then
                # Parse the environment variables from getUMAP_ENV.sh output
                eval "$umap_env_output"
                
                # Create UMAP JSON like original script
                local umap_json=$(printf '{"LAT":"%s","LON":"%s","UMAPROOT":"%s","UMAPHEX":"%s","UMAPG1PUB":"%s","UMAPIPNS":"%s","SECTORROOT":"%s","SECTORHEX":"%s","SECTORG1PUB":"%s","SECTORIPNS":"%s","REGIONROOT":"%s","REGIONHEX":"%s","REGIONG1PUB":"%s","REGIONIPNS":"%s"}' \
                       "$lat" "$lon" "$UMAPROOT" "$UMAPHEX" "$UMAPG1PUB" "${myIPFS}/ipns/$UMAPIPNS" "$SECTORROOT" "$SECTORHEX" "$SECTORG1PUB" "${myIPFS}/ipns/$SECTORIPNS" "$REGIONROOT" "$REGIONHEX" "$REGIONG1PUB" "${myIPFS}/ipns/$REGIONIPNS")
                
                # Geographic filtering if coordinates provided
                if [[ -n "$ulat" && -n "$ulon" && -n "$deg" ]]; then
                    if [[ "$(is_coordinate_in_bounds "$lat" "$lon" "$ulat" "$ulon" "$deg")" == "1" ]]; then
                        results+=("$umap_json")
                    fi
                else
                    # No geographic filtering
                    results+=("$umap_json")
                fi
            fi
        fi
    done < <(find "$HOME/.zen/game/world/__" -maxdepth 1 -type d -name "_*_*" 2>/dev/null)
    
    # Output as JSON array
    if [[ ${#results[@]} -gt 0 ]]; then
        printf '[%s]' "$(IFS=','; echo "${results[*]}")"
    else
        echo "[]"
    fi
    
    time_elapsed "$umaps_start"
}

# Main processing
echo "🚀 Starting data collection..." >&2

# Collect all data
players_json=$(collect_players_data "$ULAT" "$ULON" "$DEG")
nostr_json=$(collect_nostr_data "$ULAT" "$ULON" "$DEG")
umaps_json=$(collect_umaps_data "$ULAT" "$ULON" "$DEG")
swarm_json=$(collect_swarm_data)

# Calculate economy
nostr_count=$(echo "$nostr_json" | jq '. | length' 2>/dev/null || echo "0")
players_count=$(echo "$players_json" | jq '. | length' 2>/dev/null || echo "0")

# Initialize default variables if not set
[[ -z $uSPOT ]] && uSPOT="http://127.0.0.1:54321"
[[ -z $myRELAY ]] && myRELAY="ws://127.0.0.1:7777"  
[[ -z $IPFSNODEID ]] && IPFSNODEID="12D3KooWUnknown"
[[ -z $myIPFS ]] && myIPFS="http://127.0.0.1:8080"
[[ -z $UPLANETG1PUB ]] && UPLANETG1PUB="Unknown"

# Get economy variables
coins=$(cat $HOME/.zen/tmp/coucou/$UPLANETG1PUB.COINS 2>/dev/null || echo "1")
zen=$(echo "($coins - 1) * 10" | bc 2>/dev/null | cut -d '.' -f 1 || echo "0")
[[ -z $PAF ]] && PAF=14
[[ -z $NCARD ]] && NCARD=1
[[ -z $ZCARD ]] && ZCARD=4
income=$((nostr_count * NCARD + players_count * ZCARD))
bilan=$((income - PAF))

# Calculate generation duration
generation_duration=$(($(date +%s) - GENERATION_START))

echo "🔧 Assembling final JSON..." >&2

# Build final JSON
final_json=$(jq -n \
    --arg version "1.2-fixed" \
    --arg date "$(date -u)" \
    --arg uspot "$uSPOT" \
    --arg paf "$PAF" \
    --arg ncard "$NCARD" \
    --arg zcard "$ZCARD" \
    --arg relay "$myRELAY" \
    --arg ipfsnodeid "$IPFSNODEID" \
    --arg myipfs "$myIPFS" \
    --arg uplanetg1pub "$UPLANETG1PUB" \
    --arg g1 "$coins" \
    --arg zen "$zen" \
    --arg bilan "$bilan" \
    --arg generation_time "$generation_duration" \
    --argjson swarm "$swarm_json" \
    --argjson nostr "$nostr_json" \
    --argjson players "$players_json" \
    --argjson umaps "$umaps_json" \
    '{
        version: $version,
        DATE: $date,
        uSPOT: $uspot,
        PAF: $paf,
        NCARD: $ncard,
        ZCARD: $zcard,
        myRELAY: $relay,
        IPFSNODEID: $ipfsnodeid,
        myIPFS: $myipfs,
        UPLANETG1PUB: $uplanetg1pub,
        G1: $g1,
        ZEN: $zen,
        BILAN: $bilan,
        GENERATION_TIME: $generation_time,
        SWARM: $swarm,
        NOSTR: $nostr,
        PLAYERs: $players,
        UMAPs: $umaps
    }')

# Add center coordinates if provided
if [[ -n "$ULAT" && -n "$ULON" ]]; then
    final_json=$(echo "$final_json" | jq \
        --arg ulat "$ULAT" \
        --arg ulon "$ULON" \
        --arg deg "$DEG" \
        '. + {
            CENTER: {LAT: $ulat, LON: $ulon, DEG: $deg}
        }')
fi

# Save to cache
echo "$final_json" > "$CACHE_FILE"

# Validate and output
if jq -e . "$CACHE_FILE" >/dev/null 2>&1; then
    echo "$CACHE_FILE"
    
    # Performance summary
    if [[ $DEBUG_TIMING == true ]]; then
        final_size=$(du -h "$CACHE_FILE" | cut -f1)
        echo "📊 Performance Summary:" >&2
        echo "   Cache file: $CACHE_FILE ($final_size)" >&2
        echo "   Total time: $(time_elapsed "$PERF_START")" >&2
        echo "   NOSTR: $nostr_count" >&2
        echo "   PLAYERs: $players_count" >&2
    fi
else
    echo "[Ustats_fixed.sh] ERROR: Cache file is not valid JSON: $CACHE_FILE" >&2
    echo '{"error": "Fixed cache file is not valid JSON"}'
fi

exit 0 