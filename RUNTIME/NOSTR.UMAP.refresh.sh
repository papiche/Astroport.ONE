#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.6
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# NOSTR.UMAP.refresh.sh - UPlanet Geolocalized Content Aggregation & Management
#
# This script manages the complete lifecycle of geolocalized Nostr content across
# three geographic levels: UMAP (0.01°), SECTOR (0.1°), and REGION (1°).
#
# === MAIN FEATURES ===
#
# 1. UMAP MANAGEMENT (0.01° zones)
#    - Identifies UMAPs from ~/.zen/game/nostr/UMAP*/HEX
#    - Each UMAP acts as a Nostr identity with its own friends list
#    - Collects messages from friends in the last 48 hours
#    - AI summarization if journal > 10 messages or 3000 characters
#    - Publishes to NOSTR (kind 3 + kind 30023 article) and IPFS
#
# 2. SECTOR MANAGEMENT (0.1° zones)
#    - Aggregates liked messages (≥3 likes) from all UMAPs in sector
#    - Generates 4 cartographic images (Map, zMap, Sat, zSat)
#    - Creates manifest.json with metadata and CID history
#    - GPS-based ownership: only closest captain can create manifest
#    - Swarm cache optimization: reuses images from other nodes
#
# 3. REGION MANAGEMENT (1° zones)
#    - Aggregates highly liked messages (≥12 likes) from all UMAPs in region
#    - Generates 4 cartographic images (Map, zMap, Sat, zSat)
#    - Creates manifest.json with metadata and CID history
#    - GPS-based ownership: only closest captain can create manifest
#
# 4. SPECIAL CONTENT PROCESSING
#    - '#market' tags: downloads images, creates uMARKET JSON ads
#    - Orphaned ads cleanup: removes ads for deleted Nostr events
#    - Old content cleanup: 6-month retention with author notifications
#
# 5. FRIEND MANAGEMENT
#    - Tracks active/inactive friends
#    - Sends reminders after 7 days of inactivity
#    - Removes friends after 28 days of inactivity
#    - Maintains "friends of friends" whitelist
#
# 6. GPS-BASED MANIFEST OWNERSHIP
#    - Only nodes with configured GPS can create manifests
#    - Haversine distance calculation to determine closest node
#    - Manifest includes captain GPS coordinates for verification
#    - Prevents conflicts: one authoritative manifest per zone
#
# 7. SWARM CACHE OPTIMIZATION
#    - Images: searches swarm before generating (99% faster)
#    - Journals: collects from all swarm nodes
#    - Manifests: compares distances from all swarm captains
#
# === REQUIRED FILES ===
# - Captain GPS: ~/.zen/game/nostr/${CAPTAINEMAIL}/GPS
#   Format: LAT=43.60; LON=1.44;
#
# === DEPENDENCIES ===
# - jq, nostpy-cli, ipfs, strfry, bc (for GPS calculations)
# - question.py (AI summarization)
# - page_screenshot.py (map image generation)
################################################################################

# Global variables
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
SECTORS=()
STAGS=()
REGIONS=()
RTAGS=()
ACTIVE_FRIENDS=()  # Global array for active friends
TAGS=()            # Global array for tags
LAT=""             # Global current latitude
LON=""             # Global current longitude
VERBOSE=false      # Verbosity flag

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-v|--verbose] [-h|--help]"
            echo "  -v, --verbose  Enable verbose output"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# Utility Functions
################################################################################

# Check if a message is within the UMAP zone (0.01° precision)
# Extracts GPS coordinates from Nostr message tags and validates against UMAP bounds
# Returns: 0 (true) if message is in zone, 1 (false) otherwise
is_message_in_umap_zone() {
    local message_json="$1"
    
    # Extract GPS coordinates from message tags
    # Priority: latitude/longitude tags > g tag
    local message_lat=$(echo "$message_json" | jq -r '.tags[] | select(.[0] == "latitude") | .[1]' | head -n 1)
    local message_lon=$(echo "$message_json" | jq -r '.tags[] | select(.[0] == "longitude") | .[1]' | head -n 1)
    
    # Fallback to "g" tag if latitude/longitude not found
    if [[ -z "$message_lat" || -z "$message_lon" || "$message_lat" == "null" || "$message_lon" == "null" ]]; then
        message_lat=$(echo "$message_json" | jq -r '.tags[] | select(.[0] == "g") | .[1]' | head -n 1 | cut -d',' -f1)
        message_lon=$(echo "$message_json" | jq -r '.tags[] | select(.[0] == "g") | .[1]' | head -n 1 | cut -d',' -f2)
    fi
    
    # If no GPS coordinates found, only include if this is the global UMAP (0.00, 0.00)
    if [[ -z "$message_lat" || -z "$message_lon" || "$message_lat" == "null" || "$message_lon" == "null" ]]; then
        # Only the global UMAP (0.00, 0.00) should collect messages without GPS coordinates
        if [[ "$LAT" == "0.00" && "$LON" == "0.00" ]]; then
            log "📍 No GPS coordinates in message, including in global UMAP (0.00, 0.00)"
            return 0
        else
            log "📍 No GPS coordinates in message, excluding from UMAP ($LAT, $LON) - only global UMAP (0.00, 0.00) collects non-geolocated messages"
            return 1
        fi
    fi
    
    # Validate coordinate format (must be numeric)
    if ! [[ "$message_lat" =~ ^-?[0-9]+\.?[0-9]*$ ]] || ! [[ "$message_lon" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
        log "⚠️  Invalid GPS coordinates format: lat=$message_lat, lon=$message_lon"
        return 1
    fi
    
    # Calculate UMAP zone boundaries (0.01° precision)
    # UMAP coordinates are the bottom-left (southwest) corner of a 0.01° x 0.01° zone
    local umap_lat_bottom="$LAT"
    local umap_lon_left="$LON"
    
    # Special case: Global UMAP (0.00, 0.00) collects all non-geolocated messages
    if [[ "$LAT" == "0.00" && "$LON" == "0.00" ]]; then
        # Global UMAP accepts all messages (already handled above for non-GPS messages)
        # For GPS messages, it should not accept any (they belong to specific UMAPs)
        log "🌍 Global UMAP (0.00, 0.00) - rejecting geolocated message (belongs to specific UMAP)"
        return 1
    fi
    
    # Calculate zone boundaries (UMAP coord is bottom-left, so add 0.01° for top-right)
    local zone_lat_min="$umap_lat_bottom"
    local zone_lat_max=$(echo "scale=3; $umap_lat_bottom + 0.01" | bc -l)
    local zone_lon_min="$umap_lon_left"
    local zone_lon_max=$(echo "scale=3; $umap_lon_left + 0.01" | bc -l)
    
    # Check if message coordinates are within UMAP zone
    local lat_in_zone=$(echo "scale=3; $message_lat >= $zone_lat_min && $message_lat <= $zone_lat_max" | bc -l)
    local lon_in_zone=$(echo "scale=3; $message_lon >= $zone_lon_min && $message_lon <= $zone_lon_max" | bc -l)
    
    if [[ "$lat_in_zone" == "1" && "$lon_in_zone" == "1" ]]; then
        log "✅ Message in UMAP zone: lat=$message_lat, lon=$message_lon (UMAP bottom-left: $umap_lat_bottom, $umap_lon_left)"
        return 0
    else
        log "❌ Message outside UMAP zone: lat=$message_lat, lon=$message_lon (UMAP bottom-left: $umap_lat_bottom, $umap_lon_left)"
        return 1
    fi
}

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "$1"
    fi
}

log_always() {
    echo "$1"
}

# Wrapper function for nostpy-cli to reduce verbosity
send_nostr_event() {
    local output
    if [[ "$VERBOSE" == "true" ]]; then
        nostpy-cli "$@"
    else
        # Suppress all output except errors
        output=$(nostpy-cli "$@" 2>&1)
        local exit_code=$?
        # Only show actual errors (not success messages or "Already following")
        if [[ $exit_code -ne 0 ]] && [[ ! "$output" =~ "Already following" ]]; then
            # Filter out success messages and color codes
            echo "$output" | grep -i "error\|failed\|warning" | sed 's/\x1b\[[0-9;]*m//g' >&2
        fi
        return $exit_code
    fi
}

check_dependencies() {
    [[ ! -s $MY_PATH/../tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
    source $MY_PATH/../tools/my.sh
    
    # Check for required external tools
    local missing_tools=()
    
    [[ ! -x $(command -v jq) ]] && missing_tools+=("jq")
    [[ ! -x $(command -v nostpy-cli) ]] && missing_tools+=("nostpy-cli")
    [[ ! -x $(command -v ipfs) ]] && missing_tools+=("ipfs")
    [[ ! -d ~/.zen/strfry ]] && missing_tools+=("strfry directory")
    [[ ! -s $MY_PATH/../IA/question.py ]] && missing_tools+=("question.py")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "ERROR. Missing required dependencies: ${missing_tools[*]}"
        exit 1
    fi
}

display_banner() {
    echo '
o               ²        ___---___                    ²
       ²              ²--\        --²     ²     ²         ²
                    ²/²;_²\     __/~ \²
                   /;  / `-²  __\    ² \
 ²        ²       / ,--²     / ²   ²;   \        |
                 | ²|       /       __   |      -O-       ²
                |__/    __ |  ² ;   \ | ² |      |
                |      /  \\_    ² ;| \___|
   ²    o       |      \  ²~\\___,--²     |           ²
                 |     | ² ; ~~~~\_    __|
    |             \    \   ²  ²  ; \  /_/   ²
   -O-        ²    \   /         ² |  ~/                  ²
    |    ²          ~\ \   ²      /  /~          o
  ²                   ~--___ ; ___--~
                 ²          ---         ²
NOTR.UMAP.refresh.sh'
}

################################################################################
# UMAP Management Functions
################################################################################

process_umap_messages() {
    local hexline=$1
    local hex=$(cat $hexline)
    local UMAPDIR=$(dirname "$hexline")  # Store UMAP source directory
    
    # Set global coordinates for this UMAP
    LAT=$(makecoord $(echo $hexline | cut -d '_' -f 2))
    LON=$(makecoord $(echo $hexline | cut -d '_' -f 3 | cut -d '/' -f 1))
    
    # Validate coordinates
    if [[ -z "$LAT" || -z "$LON" ]]; then
        echo "ERROR: Invalid coordinates from $hexline"
        return 1
    fi
    
    local SLAT="${LAT::-1}"
    local SLON="${LON::-1}"
    local RLAT=$(echo ${LAT} | cut -d '.' -f 1)
    local RLON=$(echo ${LON} | cut -d '.' -f 1)

    local UMAPPATH="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"
    mkdir -p ${UMAPPATH}
    echo "" > ${UMAPPATH}/NOSTR_messages

    SECTORS+=("_${SLAT}_${SLON}")

    process_umap_friends "$hex" "$UMAPPATH" "$UMAPDIR"

    # Appel IA si journal UMAP trop long
    MAX_MSGS=10
    MAX_SIZE=3000
    if [[ -f "${UMAPPATH}/NOSTR_messages" ]]; then
        msg_count=$(grep -c '^### 📝' "${UMAPPATH}/NOSTR_messages")
        file_size=$(wc -c < "${UMAPPATH}/NOSTR_messages")
        if [[ $msg_count -gt $MAX_MSGS || $file_size -gt $MAX_SIZE ]]; then
            IA_PROMPT="[TEXT] $(cat ${UMAPPATH}/NOSTR_messages) [/TEXT] --- \
# 1. Summarize and group messages by profile (author) in Markdown format, clearly cite each profile. \
# 2. For each profile, list the main messages of the day using Markdown headers and lists. \
# 3. Add hashtags and emojis for readability. \
# 4. Use Markdown formatting (headers, bold, lists, etc.) for better structure. \
# 5. IMPORTANT: Never omit an author, even if you summarize. \
# 6. Use the same language as the messages."
            ANSWER=$($MY_PATH/../IA/question.py "$IA_PROMPT")
            echo "$ANSWER" > "${UMAPPATH}/NOSTR_messages"
        fi
    fi

    # Only setup UMAP identity if NOSTR_messages exists and has content
    if [[ -f "${UMAPPATH}/NOSTR_messages" && -s "${UMAPPATH}/NOSTR_messages" ]]; then
        setup_umap_identity "$UMAPPATH"
    else
        log "⏭️  No messages to publish for UMAP (${LAT}, ${LON})"
    fi
}

process_umap_friends() {
    local hex=$1
    local UMAPPATH=$2
    local UMAPDIR=$3  # Source directory of UMAP

    # Initialize NPRIV_HEX early for this UMAP using global coordinates
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")

    local friends=($($MY_PATH/../tools/nostr_get_N1.sh $hex 2>/dev/null))
    local SINCE=$(date -d "24 hours ago" +%s)
    local WEEK_AGO=$(date -d "7 days ago" +%s)
    local MONTH_AGO=$(date -d "28 days ago" +%s)

    cd ~/.zen/strfry

    # Reset global arrays for this UMAP
    TAGS=()
    ACTIVE_FRIENDS=()

    # First, get all market messages from friends in the last 24h
    process_market_messages_from_friends "${friends[@]}" "$UMAPPATH" "$SINCE"

    # Process MULTIPASS summaries from this UMAP zone
    process_multipass_summaries "$UMAPPATH" "$SINCE" "$NPRIV_HEX"

    for ami in ${friends[@]}; do
        process_friend_messages "$ami" "$UMAPPATH" "$SINCE" "$WEEK_AGO" "$MONTH_AGO" "$NPRIV_HEX"
    done

    update_friends_list "${ACTIVE_FRIENDS[@]}"
    
    # Check if UMAP has no active friends and clean up cache if needed
    if [[ ${#ACTIVE_FRIENDS[@]} -eq 0 ]]; then
        log_always "⚠️  UMAP (${LAT}, ${LON}) has no active friends, removing all cache"
        rm -Rf "$UMAPPATH" ## Remove temporary UMAP cache
        rm -Rf "$UMAPDIR"  ## Remove source UMAP directory
    else
        setup_ipfs_structure "$UMAPPATH" "$NPRIV_HEX"
    fi
}

process_friend_messages() {
    local ami=$1
    local UMAPPATH=$2
    local SINCE=$3
    local WEEK_AGO=$4
    local MONTH_AGO=$5
    local NPRIV_HEX=$6

    local PROFILE=$(./strfry scan '{
      "kinds": [0],
      "authors": ["'"$ami"'"],
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 0) | .content' | jq -r '[.name, .display_name, .about] | join(" | ")')

    if [[ -n "$PROFILE" ]]; then
        handle_active_friend "$ami" "$UMAPPATH" "$WEEK_AGO" "$MONTH_AGO" "$NPRIV_HEX"
        # Get friends of this friend and add to amisOfAmis.txt if not already present
        local fof_list=$($MY_PATH/../tools/nostr_get_N1.sh "$ami" 2>/dev/null)
        if [[ -n "$fof_list" ]]; then
            for fof in $fof_list; do
                # Only append if fof not already in file (case-insensitive check)
                if ! grep -qi "^${fof}$" ~/.zen/strfry/amisOfAmis.txt 2>/dev/null; then
                    echo "$fof" >> ~/.zen/strfry/amisOfAmis.txt
                fi
            done
        fi

    else
        echo "👤 UNKNOWN VISITOR" >> ${UMAPPATH}/NOSTR_messages
    fi

    process_recent_messages "$ami" "$UMAPPATH" "$SINCE"
}

handle_active_friend() {
    local ami=$1
    local UMAPPATH=$2
    local WEEK_AGO=$3
    local MONTH_AGO=$4
    local NPRIV_HEX=$5

    local profile=$($MY_PATH/../tools/nostr_hex2nprofile.sh $ami 2>/dev/null)

    local RECENT_ACTIVITY=$(./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '"$MONTH_AGO"',
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 1) | .created_at')

    if [[ -z "$RECENT_ACTIVITY" ]]; then
        handle_inactive_friend "$ami" "$profile" "$NPRIV_HEX"
    else
        echo "-----------------------------" >> ${UMAPPATH}/NOSTR_messages
        echo "👤 nostr:$profile" >> ${UMAPPATH}/NOSTR_messages
        handle_active_friend_activity "$ami" "$profile" "$WEEK_AGO" "$NPRIV_HEX"
    fi
}

handle_inactive_friend() {
    local ami=$1
    local profile=$2
    local NPRIV_HEX=$3

    # echo "🚫 Removing inactive friend: nostr:$profile (no activity in 4 weeks)" >> ${UMAPPATH}/NOSTR_messages
    local GOODBYE_MSG="👋 nostr:$profile ! It seems you've been inactive for a while. I remove you from my GeoKey list, but you're welcome to reconnect anytime! #UPlanet #Community"
    send_nostr_event send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$GOODBYE_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY"
}

handle_active_friend_activity() {
    local ami=$1
    local profile=$2
    local WEEK_AGO=$3
    local NPRIV_HEX=$4

    # Add to global arrays
    ACTIVE_FRIENDS+=("$ami")
    TAGS+=("[\"p\", \"$ami\", \"$myRELAY\", \"Ufriend\"]")

    local WEEK_ACTIVITY=$(./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '"$WEEK_AGO"',
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 1) | .created_at')

    if [[ -z "$WEEK_ACTIVITY" ]]; then
        send_reminder_message "$ami" "$profile" "$NPRIV_HEX"
    fi
}

send_reminder_message() {
    local ami=$1
    local profile=$2
    local NPRIV_HEX=$3

    local REMINDER_MSG="👋 nostr:$profile ! Haven't seen you around lately. How are you doing? Feel free to share your thoughts or updates! #UPlanet #Community"
    send_nostr_event send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$REMINDER_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY"
    echo "📬 Sent reminder to $profile" 2>/dev/null >> ${UMAPPATH}/NOSTR_messages
}

################################################################################
# MULTIPASS SUMMARY INTEGRATION
################################################################################
# Process MULTIPASS friends summaries that are geolocated to this UMAP zone
# This allows UMAPs to include relevant MULTIPASS activity summaries as content

# Process MULTIPASS summaries from this UMAP zone
# Searches for MULTIPASS accounts with GPS coordinates matching this UMAP zone
# and includes their friends summaries as UMAP content
process_multipass_summaries() {
    local UMAPPATH=$1
    local SINCE=$2
    local NPRIV_HEX=$3
    
    log "🔍 Searching for MULTIPASS summaries in UMAP zone (${LAT}, ${LON})"
    
    # Find all MULTIPASS accounts with GPS coordinates matching this UMAP zone
    local multipass_accounts=()
    
    # Search for MULTIPASS accounts in ~/.zen/game/nostr/
    for player_dir in ~/.zen/game/nostr/*@*/; do
        if [[ -d "$player_dir" ]]; then
            local player_name=$(basename "$player_dir")
            local gps_file="${player_dir}/GPS"
            
            # Check if this MULTIPASS has GPS coordinates
            if [[ -f "$gps_file" ]]; then
                local player_lat=$(grep "^LAT=" "$gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
                local player_lon=$(grep "^LON=" "$gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
                
                # Check if this MULTIPASS is in the current UMAP zone
                if [[ -n "$player_lat" && -n "$player_lon" && "$player_lat" != "" && "$player_lon" != "" ]]; then
                    # Create a temporary message JSON to test zone membership
                    local temp_message="{\"tags\": [[\"latitude\", \"$player_lat\"], [\"longitude\", \"$player_lon\"]]}"
                    
                    if is_message_in_umap_zone "$temp_message"; then
                        multipass_accounts+=("$player_name")
                        log "📍 Found MULTIPASS in UMAP zone: $player_name ($player_lat, $player_lon)"
                    fi
                fi
            fi
        fi
    done
    
    # Process each MULTIPASS account found in this UMAP zone
    for multipass in "${multipass_accounts[@]}"; do
        process_multipass_summary "$multipass" "$UMAPPATH" "$SINCE" "$NPRIV_HEX"
    done
}

# Process a specific MULTIPASS summary for this UMAP
# Searches for published friends summaries from this MULTIPASS
process_multipass_summary() {
    local multipass=$1
    local UMAPPATH=$2
    local SINCE=$3
    local NPRIV_HEX=$3
    
    log "📱 Processing MULTIPASS summary: $multipass"
    
    # Get MULTIPASS HEX key
    local multipass_hex_file="${HOME}/.zen/game/nostr/${multipass}/HEX"
    if [[ ! -f "$multipass_hex_file" ]]; then
        log "⚠️  No HEX file found for MULTIPASS: $multipass"
        return 1
    fi
    
    local multipass_hex=$(cat "$multipass_hex_file")
    
    # Search for published friends summaries from this MULTIPASS (last 24h)
    cd ~/.zen/strfry
    local summaries=$(./strfry scan "{
        \"kinds\": [30023],
        \"authors\": [\"$multipass_hex\"],
        \"since\": $SINCE,
        \"limit\": 10
    }" 2>/dev/null | jq -c 'select(.kind == 30023 and (.tags[] | select(.[0] == "t" and .[1] == "FriendsSummary"))) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')
    cd - >/dev/null
    
    if [[ -n "$summaries" ]]; then
        echo "-----------------------------" >> ${UMAPPATH}/NOSTR_messages
        echo "📱 MULTIPASS Summary: $multipass" >> ${UMAPPATH}/NOSTR_messages
        
        echo "$summaries" | while read -r summary; do
            local content=$(echo "$summary" | jq -r .content)
            local created_at=$(echo "$summary" | jq -r .created_at)
            local date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M')
            
            # Extract summary type from tags
            local summary_type=$(echo "$summary" | jq -r '.tags[] | select(.[0] == "t" and .[1] == "Daily" or .[1] == "Weekly" or .[1] == "Monthly" or .[1] == "Yearly") | .[1]' | head -n 1)
            if [[ -z "$summary_type" ]]; then
                summary_type="Summary"
            fi
            
            echo "### 📱 $date_str ($summary_type)" >> ${UMAPPATH}/NOSTR_messages
            echo "**Source**: MULTIPASS $multipass" >> ${UMAPPATH}/NOSTR_messages
            echo "" >> ${UMAPPATH}/NOSTR_messages
            echo "$content" >> ${UMAPPATH}/NOSTR_messages
            echo "" >> ${UMAPPATH}/NOSTR_messages
            echo "---" >> ${UMAPPATH}/NOSTR_messages
            echo "" >> ${UMAPPATH}/NOSTR_messages
        done
        
        log "✅ Added MULTIPASS summary from $multipass to UMAP journal"
    else
        log "ℹ️  No friends summaries found for MULTIPASS: $multipass"
    fi
}

################################################################################
# uMARKET - DECENTRALIZED MARKETPLACE SYSTEM
################################################################################
# The #market tag system enables users to post classified ads/offers on Nostr
# that are automatically processed, geolocalized, and made available via IPFS.
#
# WORKFLOW:
# 1. User posts Nostr message (kind 1) containing #market tag
# 2. UMAP detects #market in friend messages (last 48h)
# 3. Downloads images from URLs in message content
# 4. Creates structured JSON ad file with geolocation
# 5. Publishes to IPFS via _uMARKET.generate.sh
# 6. Cleans up old ads (6 months) with author notification
# 7. Removes orphaned ads (deleted Nostr events)
#
# EXAMPLE MESSAGE:
# "Selling vintage bicycle 🚲 150€
#  Great condition, perfect for city rides
#  https://example.com/images/bike.jpg
#  #market #bicycle #toulouse"
#
# STORAGE STRUCTURE:
# ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_R_R/_S_S/_LAT_LON/
#   └── APP/uMARKET/
#       ├── ads/
#       │   └── ${message_id}.json  (structured ad data)
#       └── Images/
#           └── UMAP_${ID}_${LAT}_${LON}_${filename}  (downloaded images)

# Process all #market messages from UMAP friends in batch
# This is called ONCE per UMAP to collect all market messages efficiently
process_market_messages_from_friends() {
    local all_args=("$@")
    local args_count=${#all_args[@]}
    
    # Extract the last two parameters (UMAPPATH and SINCE)
    if [[ $args_count -ge 2 ]]; then
        local SINCE=${all_args[$((args_count-1))]}
        local UMAPPATH=${all_args[$((args_count-2))]}
        # Get all friends (all arguments except the last two)
        local friends=("${all_args[@]:0:$((args_count-2))}")
    else
        echo "Warning: Not enough parameters for process_market_messages_from_friends" >&2
        return 1
    fi

    # Create authors JSON array for strfry query
    local authors_json=$(printf '"%s",' "${friends[@]}"); authors_json="[${authors_json%,}]"

    # Get all market messages from friends in the last 24h
    # Filter: kind=1 (text note) AND content contains "#market"
    ./strfry scan "{
      \"kinds\": [1],
      \"authors\": ${authors_json},
      \"since\": ${SINCE},
      \"limit\": 500
    }" 2>/dev/null | jq -c 'select(.kind == 1 and (.content | contains("#market"))) | {id: .id, content: .content, created_at: .created_at, author: .pubkey, tags: .tags}' | while read -r message; do
        local content=$(echo "$message" | jq -r .content)
        local message_id=$(echo "$message" | jq -r .id)
        local author_hex=$(echo "$message" | jq -r .author)
        local created_at=$(echo "$message" | jq -r .created_at)

        # Filter market messages by UMAP zone
        if ! is_message_in_umap_zone "$message"; then
            continue  # Skip market message if not in UMAP zone
        fi

        # Check if the ad file already exists to avoid reprocessing
        if [[ ! -f "${UMAPPATH}/APP/uMARKET/ads/${message_id}.json" ]]; then
            process_market_images "$content" "$UMAPPATH"
            create_market_ad "$content" "${message_id}" "$UMAPPATH" "$author_hex" "$created_at"
        fi
    done
}

process_recent_messages() {
    local ami=$1
    local UMAPPATH=$2
    local SINCE=$3

    # Récupère le profil source
    local author_nprofile=$($MY_PATH/../tools/nostr_hex2nprofile.sh "$ami" 2>/dev/null)

    # Get all messages from the last 24 hours with tags for geolocation filtering and metadata
    ./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '$SINCE'
    }' 2>/dev/null | jq -c 'select(.kind == 1) | {id: .id, content: .content, created_at: .created_at, tags: .tags}' | while read -r message; do
        local content=$(echo "$message" | jq -r .content)
        ## Avoid treating Captain Warning Messages sent to unregistered message publishers
        if [[ "$content" =~ "Hello NOSTR visitor." ]]; then continue; fi  
        local message_id=$(echo "$message" | jq -r .id)
        local created_at=$(echo "$message" | jq -r .created_at)
        local date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M')
        
        # Extract metadata from message tags
        local message_application=$(echo "$message" | jq -r '.tags[] | select(.[0] == "application") | .[1]' | head -n 1)
        local message_latitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "latitude") | .[1]' | head -n 1)
        local message_longitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "longitude") | .[1]' | head -n 1)
        local message_url=$(echo "$message" | jq -r '.tags[] | select(.[0] == "url") | .[1]' | head -n 1)
        
        # Extract GPS coordinates from message tags and filter by UMAP zone
        if ! is_message_in_umap_zone "$message"; then
            continue  # Skip message if not in UMAP zone
        fi

        # Format Markdown with better structure and metadata
        echo "### 📝 $date_str" >> ${UMAPPATH}/NOSTR_messages
        echo "**Author**: nostr:$author_nprofile" >> ${UMAPPATH}/NOSTR_messages
        
        # Add metadata if available
        if [[ -n "$message_application" && "$message_application" != "null" ]]; then
            echo "**App**: $message_application" >> ${UMAPPATH}/NOSTR_messages
        fi
        
        if [[ -n "$message_latitude" && -n "$message_longitude" && "$message_latitude" != "null" && "$message_longitude" != "null" ]]; then
            echo "**Location**: $message_latitude, $message_longitude" >> ${UMAPPATH}/NOSTR_messages
        fi
        
        if [[ -n "$message_url" && "$message_url" != "null" ]]; then
            echo "**URL**: $message_url" >> ${UMAPPATH}/NOSTR_messages
        fi
        
        echo "" >> ${UMAPPATH}/NOSTR_messages
        echo "$content" >> ${UMAPPATH}/NOSTR_messages
        echo "" >> ${UMAPPATH}/NOSTR_messages

        # Process #market messages, ensuring they are not processed multiple times
        if [[ "$content" == *"#market"* ]]; then
            # Check if the ad file already exists to avoid reprocessing
            if [[ ! -f "${UMAPPATH}/APP/uMARKET/ads/${message_id}.json" ]]; then
                process_market_images "$content" "$UMAPPATH"
                create_market_ad "$content" "${message_id}" "$UMAPPATH" "$ami" "$created_at"
            fi
        fi
    done | head -n 100 # limit to 100 messages from 24h from each friend
}

# Extract and download images from market message content
# Searches for image URLs (jpg, jpeg, png, gif) in the message text
# Downloads them locally with security checks and validation
#
# SECURITY FEATURES:
# - URL format validation (regex check)
# - Filename sanitization (no path traversal)
# - Download timeout (30s), retry (3x), rate limit (1MB/s)
# - File type verification (magic number check)
# - Size check (must be non-empty)
#
# NAMING: UMAP_${ID}_${LAT}_${LON}_${original_filename}
# Example: UMAP_QmABC123_43.60_1.44_bicycle.jpg
process_market_images() {
    local content=$1
    local UMAPPATH=$2

    # Ensure Images directory exists
    mkdir -p "${UMAPPATH}/APP/uMARKET/Images"

    # Extract image URLs from message content (supports http/https)
    local image_urls=$(echo "$content" | grep -o 'https\?://[^[:space:]]*\.\(jpg\|jpeg\|png\|gif\)')
    if [[ -n "$image_urls" ]]; then
        for img_url in $image_urls; do
            # Validate URL format
            if [[ ! "$img_url" =~ ^https?://[^[:space:]]+\.(jpg|jpeg|png|gif)$ ]]; then
                echo "⚠️  Invalid image URL format: $img_url" >&2
                continue
            fi
            
            local filename=$(basename "$img_url")
            # Sanitize filename to prevent path traversal attacks
            filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]//g')
            
            # Create unique filename with UMAP coordinates
            local umap_filename="UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}_${filename}"
            local target_path="${UMAPPATH}/APP/uMARKET/Images/$umap_filename"
            
            # Check if file already exists (avoid re-downloading)
            if [[ ! -f "$target_path" ]]; then
                # Download with security parameters:
                # --timeout=30: max 30s per download
                # --tries=3: retry up to 3 times
                # --max-redirect=3: follow max 3 redirects
                # --limit-rate=1m: limit to 1MB/s (prevent abuse)
                if wget -q --timeout=30 --tries=3 --max-redirect=3 --limit-rate=1m "$img_url" -O "$target_path" 2>/dev/null; then
                    # Validate downloaded file (magic number check)
                    if [[ -s "$target_path" ]] && file "$target_path" | grep -q "image"; then
                        echo "✅ Downloaded: $filename"
                    else
                        echo "⚠️  Invalid image file: $filename" >&2
                        rm -f "$target_path"
                    fi
                else
                    echo "❌ Failed to download: $img_url" >&2
                fi
            else
                echo "ℹ️  Image already exists: $filename"
            fi
        done
    fi
}

# Create structured JSON file for a market advertisement
# Transforms raw Nostr message into geolocalized, searchable ad format
#
# JSON STRUCTURE:
# {
#   "id": "nostr_event_id",              // Original Nostr event ID
#   "content": "message text",           // Full message content
#   "author_pubkey": "hex_pubkey",       // Author's Nostr pubkey
#   "author_nprofile": "nprofile1...",   // NIP-19 profile identifier
#   "created_at": 1704067200,            // Unix timestamp
#   "location": {"lat": 43.60, "lon": 1.44},  // UMAP geolocation
#   "local_images": ["UMAP_..._bike.jpg"], // Downloaded images
#   "umap_id": "UMAP_QmABC_43.60_1.44",  // UMAP identifier
#   "generated_at": 1704067200           // Processing timestamp
# }
#
# USAGE: Ads are consumed by frontend applications to display marketplace
create_market_ad() {
    local content=$1
    local message_id=$2
    local UMAPPATH=$3
    local ami=$4
    local created_at=$5

    # Ensure ads directory exists
    mkdir -p "${UMAPPATH}/APP/uMARKET/ads"

    # Get author profile information (NIP-19 nprofile format)
    local author_nprofile=$($MY_PATH/../tools/nostr_hex2nprofile.sh "$ami" 2>/dev/null)
    
    # Extract local image filenames (only images for this UMAP)
    local local_images=()
    if [[ -d "${UMAPPATH}/APP/uMARKET/Images" ]]; then
        while IFS= read -r -d '' image; do
            local_images+=("$(basename "$image")")
        done < <(find "${UMAPPATH}/APP/uMARKET/Images" -name "UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}_*" -print0)
    fi

    # Validate required fields
    if [[ -z "$message_id" || -z "$content" || -z "$ami" ]]; then
        echo "❌ Missing required fields for market ad" >&2
        return 1
    fi

    # Create JSON advertisement with proper escaping
    # Handle empty local_images array properly
    local local_images_json
    if [[ ${#local_images[@]} -eq 0 ]]; then
        local_images_json="[]"
    else
        local_images_json=$(printf '%s\n' "${local_images[@]}" | jq -R . | jq -s .)
    fi

    local ad_json=$(cat << EOF
{
    "id": "${message_id}",
    "content": "$(echo "$content" | jq -R -s . | sed 's/^"//;s/"$//')",
    "author_pubkey": "${ami}",
    "author_nprofile": "${author_nprofile:-}",
    "created_at": ${created_at},
    "location": {
        "lat": ${LAT},
        "lon": ${LON}
    },
    "local_images": ${local_images_json},
    "umap_id": "UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}",
    "generated_at": $(date +%s)
}
EOF
)

    # Validate JSON before saving
    if echo "$ad_json" | jq . >/dev/null 2>&1; then
        echo "$ad_json" > "${UMAPPATH}/APP/uMARKET/ads/${message_id}.json"
        echo "✅ Created market ad: ${message_id}"
    else
        echo "❌ Invalid JSON generated for ad: ${message_id}" >&2
        # Try to fix common JSON issues
        local fixed_json=$(echo "$ad_json" | sed 's/,$//' | sed 's/,$//' | sed 's/,$//')
        if echo "$fixed_json" | jq . >/dev/null 2>&1; then
            echo "$fixed_json" > "${UMAPPATH}/APP/uMARKET/ads/${message_id}.json"
            echo "✅ Fixed and created market ad: ${message_id}"
        else
            echo "❌ Could not fix JSON for ad: ${message_id}" >&2
            return 1
        fi
    fi
}

setup_ipfs_structure() {
    local UMAPPATH=$1
    local NPRIV_HEX=$2

    # Create complete uMARKET directory structure
    mkdir -p "${UMAPPATH}/APP/uMARKET/ads"
    mkdir -p "${UMAPPATH}/APP/uMARKET/Images"
    cd "${UMAPPATH}/APP/uMARKET"
    
    # Check if there are market advertisements
    if [[ -d "ads" && $(find "ads" -name "*.json" | wc -l) -gt 0 ]]; then
        # Use uMARKET for market advertisements
        ln -sf "${MY_PATH}/../tools/_uMARKET.generate.sh" ./_uMARKET.generate.sh
        cleanup_old_files "$NPRIV_HEX"
        uCID=$(./_uMARKET.generate.sh .)
    fi
    
    ## Redirect to uCID actual ipfs CID
    #echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$uCID\"></head></html>" > index.html
    # rm index.html ## DEBUG MODE (todo remove)
    cd - 2>&1>/dev/null
}

################################################################################
# uMARKET CLEANUP FUNCTIONS
################################################################################
# Maintain marketplace health by removing old and invalid ads
# THREE cleanup strategies:
# 1. Age-based: Remove ads older than 6 months (with author notification)
# 2. Image cleanup: Remove images from deleted ads
# 3. Orphaned ads: Remove ads whose Nostr event was deleted

# Master cleanup function - orchestrates all cleanup tasks
cleanup_old_files() {
    local SIX_MONTHS_AGO=$(date -d "6 months ago" +%s)

    cleanup_old_documents "$SIX_MONTHS_AGO" "$NPRIV_HEX"
    cleanup_old_images "$SIX_MONTHS_AGO"
    cleanup_orphaned_ads
}

# Remove market ads older than 6 months
# POLITE DELETION: Sends Nostr notification to author before removing
# Message: "Your ad was removed after 6 months. You can repost if still relevant."
cleanup_old_documents() {
    local SIX_MONTHS_AGO=$1
    local NPRIV_HEX=$2

    if [[ ! -d "ads" ]]; then
        return
    fi

    while IFS= read -r -d '' file; do
        local file_date=$(stat -c %Y "$file")

        if [[ $file_date -lt $SIX_MONTHS_AGO ]]; then
            # Extract author from JSON file
            local author=$(jq -r '.author_pubkey' "$file" 2>/dev/null)
            local author_profile=$($MY_PATH/../tools/nostr_hex2nprofile.sh $author 2>/dev/null)
            
            # Send courtesy notification to author via UMAP identity
            if [[ -n "$author" && "$author" != "null" ]]; then
                local notification="🛒 nostr:$author_profile your ad was removed after 6 months. You can republish if still relevant. #UPlanet #uMARKET #Community"

                send_nostr_event send_event \
                    -privkey "$NPRIV_HEX" \
                    -kind 1 \
                    -content "$notification" \
                    -tags "[['p', '$author']]" \
                    --relay "$myRELAY"
            fi

            rm "$file"
        fi
    done < <(find "ads" -type f -name "*.json" -print0)
}

# Remove images older than 6 months
# Cleanup happens AFTER ad cleanup to remove images from deleted ads
cleanup_old_images() {
    local SIX_MONTHS_AGO=$1

    if [[ ! -d "Images" ]]; then
        return
    fi

    while IFS= read -r -d '' image; do
        local file_date=$(stat -c %Y "$image")

        if [[ $file_date -lt $SIX_MONTHS_AGO ]]; then
            rm "$image"
        fi
    done < <(find "Images" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -print0)
}

# Remove "orphaned" ads - ads whose original Nostr event no longer exists
# This happens when user deletes their Nostr message (kind 5 deletion)
# Also removes malformed JSON files (corrupted data)
#
# PROCESS:
# 1. Scan all ad JSON files
# 2. Validate JSON structure
# 3. Query strfry relay for original Nostr event
# 4. Remove ad if event doesn't exist anymore
cleanup_orphaned_ads() {
    if [[ ! -d "ads" ]]; then
        return
    fi

    log "🔍 Checking for orphaned and malformed market advertisements..."

    # Store current directory
    local current_dir=$(pwd)
    
    # Change to strfry directory for queries
    cd ~/.zen/strfry

    local orphaned_count=0
    local malformed_count=0
    
    while IFS= read -r -d '' file; do
        local message_id=$(basename "$file" .json)
        
        # First check if the JSON file is valid
        if ! jq . "$file" >/dev/null 2>&1; then
            log "🗑️  Removing malformed JSON ad: ${message_id}"
            rm "$file"
            ((malformed_count++))
            continue
        fi
        
        # Extract author from JSON file
        local author=$(jq -r '.author_pubkey' "$file" 2>/dev/null)
        
        if [[ -n "$message_id" && -n "$author" && "$author" != "null" ]]; then
            # Check if the Nostr event still exists on the relay
            local event_exists=$(./strfry scan "{\"ids\": [\"${message_id}\"], \"kinds\": [1], \"limit\": 1}" 2>/dev/null | jq -r 'select(.kind == 1) | .id' | head -n 1)
            
            if [[ -z "$event_exists" ]]; then
                log "🗑️  Removing orphaned ad: ${message_id} ($author)"
                # Remove the orphaned ad file
                rm "$file"
                ((orphaned_count++))
            fi
        fi
    done < <(find "$current_dir/ads" -type f -name "*.json" -print0)

    # Return to original directory
    cd "$current_dir"

    if [[ $orphaned_count -gt 0 || $malformed_count -gt 0 ]]; then
        log_always "✅ Cleaned up $orphaned_count orphaned and $malformed_count malformed advertisements"
    else
        log "✅ No orphaned or malformed advertisements found"
    fi
}

setup_umap_identity() {
    local UMAPPATH=$1

    $(${MY_PATH}/../tools/setUMAP_ENV.sh "${LAT}" "${LON}" | tail -n 1)
    STAGS+=("[\"p\", \"$SECTORHEX\", \"$myRELAY\", \"$SECTOR\"]")

    local TAGS_JSON=$(printf '%s\n' "${TAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    # Get NPRIV_HEX from the calling context
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")
    
    send_nostr_events "$NPRIV_HEX" "$TAGS_JSON" "$UMAPPATH"
}

send_nostr_events() {
    local NPRIV_HEX=$1
    local TAGS_JSON=$2
    local UMAPPATH=$3

    send_nostr_event send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"

    # Only publish UMAP journal if NOSTR_messages file exists and has content
    if [[ ! -f "${UMAPPATH}/NOSTR_messages" || ! -s "${UMAPPATH}/NOSTR_messages" ]]; then
        log "⏭️  Skipping UMAP journal for ${LAT},${LON} (no messages file)"
        return 0
    fi
    
    # Only publish UMAP journal if there's actual content (not just headers)
    local journal_content=$(cat ${UMAPPATH}/NOSTR_messages)
    if [[ -n "$journal_content" && "$journal_content" != "" ]]; then
        # Check if there's actual message content (not just empty headers)
        local has_real_content=false
        
        # Look for actual message content patterns
        if echo "$journal_content" | grep -q "### 📝" && echo "$journal_content" | grep -q "Author:"; then
            has_real_content=true
        fi
        
        # Also check for MULTIPASS summaries
        if echo "$journal_content" | grep -q "📱 MULTIPASS Summary"; then
            has_real_content=true
        fi
        
        # Only publish if there's real content
        if [[ "$has_real_content" == "true" ]]; then
            local umap_title="UMAP Journal - ${LAT},${LON}"
            
            # Generate image for UMAP journal if ComfyUI is available
            local journal_image_url=""
            if [[ -x "$MY_PATH/../IA/generate_image.sh" ]]; then
                log "🎨 Generating image for UMAP journal ${LAT},${LON}..."
                
                # Generate descriptive prompt from journal content using question.py
                local image_prompt=$($MY_PATH/../IA/question.py "[TEXT] $journal_content [/TEXT] --- Create a descriptive prompt for Stable Diffusion image generation based on this UMAP journal content. The image should represent the activities, mood, and atmosphere of this geographic location. Focus on visual elements that capture the essence of the messages. Keep the prompt concise but descriptive, suitable for AI image generation. Use English for the prompt." --lat "$LAT" --lon "$LON" 2>/dev/null)
                
                if [[ -n "$image_prompt" && "$image_prompt" != "Failed to get answer from Ollama." ]]; then
                    log "📝 Generated image prompt: $image_prompt"
                    
                    # Generate image using ComfyUI
                    journal_image_url=$($MY_PATH/../IA/generate_image.sh "$image_prompt" 2>/dev/null)
                    
                    if [[ -n "$journal_image_url" && "$journal_image_url" != "" ]]; then
                        log "✅ Generated UMAP journal image: $journal_image_url"
                    else
                        log "⚠️  Failed to generate UMAP journal image"
                    fi
                else
                    log "⚠️  Failed to generate image prompt for UMAP journal"
                fi
            else
                log "ℹ️  ComfyUI not available, skipping image generation"
            fi
            
            # Format content with optional image
            local umap_content=$(format_content_as_markdown "$journal_content" "$umap_title" "UMAP" "${LAT}_${LON}" "$journal_image_url")
            local d_tag="umap-${LAT}-${LON}-${TODATE}"
            local published_at=$(date +%s)
            
            # Add kind 30023 specific tags to TAGS_JSON
            local article_tags=$(echo "$TAGS_JSON" | jq '. + [["d", "'"$d_tag"'"], ["title", "'"$umap_title"'"], ["published_at", "'"$published_at"'"], ["t", "UPlanet"], ["t", "'"${LAT}_${LON}"'"], ["t", "UMAP"]]')
            
            send_nostr_event send_event \
                -privkey "$NPRIV_HEX" \
                -kind 30023 \
                -content "$umap_content" \
                -tags "$article_tags" \
                --relay "$myRELAY"
            
            log "✅ Published UMAP journal for ${LAT},${LON} with content"
        else
            log "⏭️  Skipping empty UMAP journal for ${LAT},${LON} (no real content)"
        fi
    else
        log "⏭️  Skipping empty UMAP journal for ${LAT},${LON} (no content)"
    fi
}

################################################################################
# Sector Management Functions
################################################################################

process_sectors() {
    local UNIQUE_SECTORS=($(echo "${SECTORS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for sector in ${UNIQUE_SECTORS[@]}; do
        create_sector_journal "$sector"
    done
}

# Fonction utilitaire pour compter les likes d'un message Nostr (doit être dans ~/.zen/strfry)
count_likes() {
    local event_id="$1"
    cd ~/.zen/strfry
    strfry scan '{
      "kinds": [7],
      "tags": [["e", "'"$event_id"'"]]
    }' 2>/dev/null | jq -r 'select(.content == "+" or .content == "👍" or .content == "❤️" or .content == "♥️") | .id' | wc -l
    cd - >/dev/null
}

create_aggregate_journal() {
    local type=$1 # "Sector" or "Region"
    local geo_id=$2 # sector or region id like _45.4_1.2 or _45_1
    local like_threshold=$3

    log "Creating ${type} ${geo_id} Journal from recently liked messages (threshold: ${like_threshold} likes)"

    local geo_path find_pattern
    if [[ "$type" == "Sector" ]]; then
        local slat=$(echo ${geo_id} | cut -d '_' -f 2)
        local slon=$(echo ${geo_id} | cut -d '_' -f 3)
    local rlat=$(echo ${slat} | cut -d '.' -f 1)
    local rlon=$(echo ${slon} | cut -d '.' -f 1)
        geo_path="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${rlat}_${rlon}/${geo_id}"
        find_pattern="*/UMAP_${slat}*_${slon}*/HEX"
    else # Region
        local rlat=$(echo ${geo_id} | cut -d '_' -f 2)
        local rlon=$(echo ${geo_id} | cut -d '_' -f 3)
        geo_path="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/${geo_id}"
        find_pattern="*/UMAP_${rlat}.*_${rlon}.*/HEX"
    fi

    mkdir -p "$geo_path"
    rm -f "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"

    # 1. Collect unique friends
    local all_friends=()
    for umap_hex_file in $(find ~/.zen/game/nostr -path "$find_pattern" 2>/dev/null); do
        local umap_hex=$(cat "$umap_hex_file")
        local umap_friends=($($MY_PATH/../tools/nostr_get_N1.sh "$umap_hex" 2>/dev/null))
        all_friends+=(${umap_friends[@]})
    done

    if [[ ${#all_friends[@]} -eq 0 ]]; then log "No friends found for ${type} ${geo_id}."; rm -Rf "$geo_path"; return; fi
    local unique_friends=($(echo "${all_friends[@]}" | tr ' ' '\n' | sort -u))

    # 2. Get recently liked message IDs from friends
    local authors_json=$(printf '"%s",' "${unique_friends[@]}"); authors_json="[${authors_json%,}]"
    local SINCE=$(date -d "24 hours ago" +%s)
    cd ~/.zen/strfry
    local liked_event_ids=($(./strfry scan "{\"kinds\": [7], \"authors\": ${authors_json}, \"since\": ${SINCE}}" 2>/dev/null | jq -r '.tags[] | select(.[0] == "e") | .[1]' | sort -u))
    cd - >/dev/null

    if [[ ${#liked_event_ids[@]} -eq 0 ]]; then log "No recently liked messages for ${type} ${geo_id}."; rm -Rf "$geo_path"; return; fi
    log "Found ${#liked_event_ids[@]} unique recently liked messages to process for ${type} ${geo_id}."

    # 3. Process each liked message
    for msgid in "${liked_event_ids[@]}"; do
                local likes=$(count_likes "$msgid")
        if [[ $likes -ge $like_threshold ]]; then
            cd ~/.zen/strfry
            local message_json=$(./strfry scan "{\"ids\": [\"${msgid}\"], \"kinds\": [1], \"limit\": 1}" 2>/dev/null | jq -c 'select(.kind == 1) | {id: .id, author: .pubkey, content: .content, created_at: .created_at}' | head -n 1)
            cd - >/dev/null

            if [[ -n "$message_json" ]]; then
                local content=$(echo "$message_json" | jq -r .content)
                local author_hex=$(echo "$message_json" | jq -r .author)
                local created_at=$(echo "$message_json" | jq -r .created_at)
                local author_nprofile=$($MY_PATH/../tools/nostr_hex2nprofile.sh "$author_hex" 2>/dev/null)
                local date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M')
                
                echo "### 📝 $date_str" >> "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"
                echo "**Author**: nostr:$author_nprofile | **Likes**: ❤️ $likes" >> "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"
                echo "" >> "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"
                echo "$content" >> "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"
                echo "" >> "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"
                fi
        fi
    done

    # 4. Finalize
    if [[ ! -s "$geo_path/${IPFSNODEID: -12}.NOSTR_journal" ]]; then echo "No messages with enough likes for ${type} ${geo_id} journal."; rm -Rf "$geo_path"; return; fi

    local journal_content
    local MAX_MSGS=10
    local MAX_SIZE=3000
    if [[ $(grep -c 'likes) :$' "$geo_path/${IPFSNODEID: -12}.NOSTR_journal") -gt $MAX_MSGS || $(wc -c < "$geo_path/${IPFSNODEID: -12}.NOSTR_journal") -gt $MAX_SIZE ]]; then
        echo "Journal for ${type} ${geo_id} is too large. Summarizing with AI..."
        journal_content=$(generate_ai_summary "$(cat "$geo_path/${IPFSNODEID: -12}.NOSTR_journal")")
    else
        journal_content=$(cat "$geo_path/${IPFSNODEID: -12}.NOSTR_journal")
    fi

    # 5. Save and publish
    if [[ "$type" == "Sector" ]]; then
        local SECROOT=$(save_sector_journal "$geo_id" "$journal_content")
        update_sector_nostr_profile "$geo_id" "$journal_content" "$SECROOT"
    else # Region
        save_region_journal "$geo_id" "$journal_content"
    fi
}

create_sector_journal() {
    local sector=$1
    create_aggregate_journal "Sector" "$sector" 3
}

################################################################################
# GPS PROXIMITY FUNCTIONS
################################################################################
# These functions implement GPS-based manifest ownership to ensure only the
# geographically closest node manages each SECTOR/REGION manifest.json

# Calculate distance between two GPS coordinates (Haversine formula)
# Returns distance in kilometers
# Usage: calculate_distance "lat1" "lon1" "lat2" "lon2"
# Example: calculate_distance "43.60" "1.44" "45.40" "1.20" → 201.45
calculate_distance() {
    local lat1=$1
    local lon1=$2
    local lat2=$3
    local lon2=$4
    
    # Earth radius in kilometers
    local R=6371
    
    # Convert to radians
    local lat1_rad=$(echo "scale=10; $lat1 * 3.14159265359 / 180" | bc -l)
    local lon1_rad=$(echo "scale=10; $lon1 * 3.14159265359 / 180" | bc -l)
    local lat2_rad=$(echo "scale=10; $lat2 * 3.14159265359 / 180" | bc -l)
    local lon2_rad=$(echo "scale=10; $lon2 * 3.14159265359 / 180" | bc -l)
    
    # Haversine formula
    local dlat=$(echo "scale=10; $lat2_rad - $lat1_rad" | bc -l)
    local dlon=$(echo "scale=10; $lon2_rad - $lon1_rad" | bc -l)
    
    local a=$(echo "scale=10; s($dlat/2) * s($dlat/2) + c($lat1_rad) * c($lat2_rad) * s($dlon/2) * s($dlon/2)" | bc -l)
    local c=$(echo "scale=10; 2 * a(sqrt($a) / sqrt(1-$a))" | bc -l 2>/dev/null)
    
    local distance=$(echo "scale=2; $R * $c" | bc -l)
    
    # If calculation fails, return large number
    if [[ -z "$distance" || "$distance" == "" ]]; then
        echo "999999"
    else
        echo "$distance"
    fi
}

# Get local captain GPS coordinates from configuration file
# Returns: "lat,lon" or empty string if not configured
# File: ~/.zen/game/nostr/${CAPTAINEMAIL}/GPS
# Format: LAT=43.60; LON=1.44;
get_local_gps() {
    local gps_file="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/GPS"
    
    if [[ ! -f "$gps_file" ]]; then
        echo ""
        return 1
    fi
    
    local lat=$(grep "^LAT=" "$gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
    local lon=$(grep "^LON=" "$gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
    
    if [[ -z "$lat" || -z "$lon" || "$lat" == "" || "$lon" == "" ]]; then
        echo ""
        return 1
    fi
    
    echo "${lat},${lon}"
    return 0
}

# Check if this node is the closest to a geographic zone
# This is the KEY FUNCTION for manifest ownership determination
#
# Process:
# 1. Reads local captain GPS (REQUIRED - returns false if missing)
# 2. Calculates distance from local captain to zone center
# 3. Scans all swarm manifests for this zone
# 4. Compares distances from swarm captains (from manifest captain_gps)
# 5. Returns true ONLY if this node is the closest
#
# Returns: 0 (true) if closest, 1 (false) otherwise
# Usage: is_closest_node "zone_lat" "zone_lon" "SECTOR|REGION" "zone_id"
is_closest_node() {
    local zone_lat=$1
    local zone_lon=$2
    local zone_type=$3  # "SECTOR" or "REGION"
    local zone_id=$4    # e.g., "_45.4_1.2" or "_45_1"
    
    # Get local captain GPS
    local local_gps=$(get_local_gps)
    if [[ -z "$local_gps" ]]; then
        log "❌ No GPS coordinates for local captain, cannot create manifest (untrusted node)"
        return 1  # If no GPS, deny creation
    fi
    
    local local_lat=$(echo "$local_gps" | cut -d',' -f1)
    local local_lon=$(echo "$local_gps" | cut -d',' -f2)
    
    # Calculate local distance
    local local_distance=$(calculate_distance "$local_lat" "$local_lon" "$zone_lat" "$zone_lon")
    log "📍 Local captain distance to zone: ${local_distance} km"
    
    # Check swarm nodes
    local search_path
    if [[ "$zone_type" == "SECTOR" ]]; then
        local rlat=$(echo ${zone_id} | cut -d'_' -f2 | cut -d'.' -f1)
        local rlon=$(echo ${zone_id} | cut -d'_' -f3 | cut -d'.' -f1)
        search_path="*/UPLANET/SECTORS/_${rlat}_${rlon}/${zone_id}/manifest.json"
    else
        search_path="*/UPLANET/REGIONS/${zone_id}/manifest.json"
    fi
    
    # Check all swarm manifests
    for swarm_manifest in $(find "$HOME/.zen/tmp/swarm/" -path "$search_path" 2>/dev/null); do
        # Extract swarm node captain GPS directly from manifest
        local swarm_node_id=$(jq -r '.node_id // ""' "$swarm_manifest" 2>/dev/null)
        local swarm_lat=$(jq -r '.captain_gps.lat // ""' "$swarm_manifest" 2>/dev/null)
        local swarm_lon=$(jq -r '.captain_gps.lon // ""' "$swarm_manifest" 2>/dev/null)
        local swarm_email=$(jq -r '.captain_gps.email // ""' "$swarm_manifest" 2>/dev/null)
        
        # Skip if no GPS data in manifest
        if [[ -z "$swarm_lat" || -z "$swarm_lon" || "$swarm_lat" == "null" || "$swarm_lon" == "null" ]]; then
            log "⚠️  Swarm node ${swarm_node_id:0:8}... has no GPS data, skipping"
            continue
        fi
        
        # Calculate swarm node distance
        local swarm_distance=$(calculate_distance "$swarm_lat" "$swarm_lon" "$zone_lat" "$zone_lon")
        
        log "🌐 Swarm node ${swarm_node_id:0:8}... ($swarm_email) distance: ${swarm_distance} km"
        
        # If swarm node is closer, we're not the closest
        if (( $(echo "$swarm_distance < $local_distance" | bc -l) )); then
            log "❌ Swarm node is closer, skipping manifest creation"
            return 1
        fi
    done
    
    log "✅ This node is the closest, can create manifest"
    return 0
}

################################################################################
# SWARM CACHE OPTIMIZATION
################################################################################

# Search for a file in the swarm cache before generating it
# This dramatically speeds up image generation by reusing existing files
#
# Process:
# 1. Check if file exists locally → skip (return 0)
# 2. Search in ~/.zen/tmp/swarm/ for same file → copy if found (return 0)
# 3. Not found → return 1 (caller must generate)
#
# Performance: 99% faster (10ms copy vs 5000ms generation)
# Returns: 0 if found/exists, 1 if needs generation
find_or_copy_from_swarm() {
    local filename=$1
    local targetpath=$2
    local search_pattern=$3
    
    # If file already exists locally, skip
    if [[ -s "${targetpath}/${filename}" ]]; then
        log "✓ ${filename} already exists locally"
        return 0
    fi
    
    # Search in swarm
    log "Searching ${filename} in swarm..."
    local swarm_file=$(find "$HOME/.zen/tmp/swarm/" -path "$search_pattern" -print -quit 2>/dev/null)
    
    if [[ -f "$swarm_file" && -s "$swarm_file" ]]; then
        log "✓ ${filename} found in swarm, copying..."
        cp "$swarm_file" "${targetpath}/${filename}"
        return 0
    fi
    
    # Not found in swarm, need to generate
    return 1
}

################################################################################
# SECTOR & REGION IMAGE GENERATION
################################################################################

# Generate 4 cartographic images for a SECTOR zone (0.1° = ~11km)
#
# Images generated:
# - SectorMap.jpg  : OpenStreetMap large view (0.1°) → archive/web
# - zSectorMap.jpg : OpenStreetMap zoomed (0.01°) → NOSTR profile picture
# - SectorSat.jpg  : Satellite large view (0.1°) → NOSTR banner
# - zSectorSat.jpg : Satellite zoomed (0.01°) → archive/detail
#
# Optimization: Checks swarm cache before generating (99% faster if found)
# Each image: ~900x900px, generated via page_screenshot.py
generate_sector_images() {
    local slat=$1
    local slon=$2
    local sectorpath=$3
    local rlat=$(echo ${slat} | cut -d '.' -f 1)
    local rlon=$(echo ${slon} | cut -d '.' -f 1)
    
    log "Generating SECTOR images for _${slat}_${slon}..."
    
    # Calculate coordinates for the sector (center of 0.1° square)
    local lat="${slat}0"
    local lon="${slon}0"
    
    # Generate SectorMap.jpg (large view 0.1°)
    if ! find_or_copy_from_swarm "SectorMap.jpg" "$sectorpath" "*/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}/SectorMap.jpg"; then
        local SECTORMAP_URL="/ipns/copylaradio.com/Umap.html?southWestLat=${lat}&southWestLon=${lon}&deg=0.1"
        log "Generating SectorMap.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${SECTORMAP_URL}" "${sectorpath}/SectorMap.jpg" 900 900
    fi
    
    # Generate zSectorMap.jpg (profile picture - zoomed view 0.01°)
    if ! find_or_copy_from_swarm "zSectorMap.jpg" "$sectorpath" "*/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}/zSectorMap.jpg"; then
        local ZSECTORMAP_URL="/ipns/copylaradio.com/Umap.html?southWestLat=${lat}&southWestLon=${lon}&deg=0.01"
        log "Generating zSectorMap.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${ZSECTORMAP_URL}" "${sectorpath}/zSectorMap.jpg" 900 900
    fi
    
    # Generate SectorSat.jpg (banner - wide view 0.1°)
    if ! find_or_copy_from_swarm "SectorSat.jpg" "$sectorpath" "*/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}/SectorSat.jpg"; then
        local SECTORSAT_URL="/ipns/copylaradio.com/Usat.html?southWestLat=${lat}&southWestLon=${lon}&deg=0.1"
        log "Generating SectorSat.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${SECTORSAT_URL}" "${sectorpath}/SectorSat.jpg" 900 900
    fi
    
    # Generate zSectorSat.jpg (zoomed satellite view 0.01°)
    if ! find_or_copy_from_swarm "zSectorSat.jpg" "$sectorpath" "*/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}/zSectorSat.jpg"; then
        local ZSECTORSAT_URL="/ipns/copylaradio.com/Usat.html?southWestLat=${lat}&southWestLon=${lon}&deg=0.01"
        log "Generating zSectorSat.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${ZSECTORSAT_URL}" "${sectorpath}/zSectorSat.jpg" 900 900
    fi
    
    log "SECTOR images complete: 4/4 images ready"
}

save_sector_journal() {
    local sector=$1
    local ANSWER=$2

    local slat=$(echo ${sector} | cut -d '_' -f 2)
    local slon=$(echo ${sector} | cut -d '_' -f 3)
    local rlat=$(echo ${slat} | cut -d '.' -f 1)
    local rlon=$(echo ${slon} | cut -d '.' -f 1)
    REGIONS+=("_${rlat}_${rlon}")

    local sectorpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}"
    mkdir -p $sectorpath
    echo "$ANSWER" > $sectorpath/${IPFSNODEID: -12}.NOSTR_journal

    # Generate sector images before IPFS add
    generate_sector_images "$slat" "$slon" "$sectorpath"

    # Update manifest before IPFS add to include it in the CID
    local temp_manifest="${sectorpath}/manifest.tmp"
    local previous_cid=""
    if [[ -f "${sectorpath}/manifest.json" ]]; then
        previous_cid=$(jq -r '.current_cid // ""' "${sectorpath}/manifest.json" 2>/dev/null)
    fi
    
    # Add to IPFS (excluding manifest temporarily)
    local SECROOT=$(ipfs add -rwHq $sectorpath/* | tail -n 1)
    
    # Now update manifest with the new CID
    update_sector_manifest "$sectorpath" "$sector" "$SECROOT"
    
    echo "$SECROOT"
}

################################################################################
# MANIFEST.JSON MANAGEMENT
################################################################################

# Update or create manifest.json for a SECTOR
# This replaces the old ipfs.${DATE} files with a unified JSON structure
#
# Manifest contains:
# - date, type, geo_key, coordinates
# - current_cid + ipfs_link (current IPFS CID)
# - previous_cid (for history/diff)
# - captain_gps (lat, lon, email of responsible captain)
# - journals[] (list of all journals from swarm nodes)
# - updated_at, node_id
#
# GPS-BASED OWNERSHIP: Only creates manifest if this node is closest to zone
update_sector_manifest() {
    local sectorpath=$1
    local sector=$2
    local SECROOT=$3
    
    local manifest_file="${sectorpath}/manifest.json"
    local previous_cid=""
    
    # Collect all journals from swarm
    local slat=$(echo ${sector} | cut -d '_' -f 2)
    local slon=$(echo ${sector} | cut -d '_' -f 3)
    local rlat=$(echo ${slat} | cut -d '.' -f 1)
    local rlon=$(echo ${slon} | cut -d '.' -f 1)
    
    # Calculate zone center coordinates
    local zone_lat="${slat}0"
    local zone_lon="${slon}0"
    
    # Check if this node is the closest to the zone
    if ! is_closest_node "$zone_lat" "$zone_lon" "SECTOR" "$sector"; then
        log "⏭️  Skipping manifest creation for SECTOR ${sector} (not closest node)"
        return 0
    fi
    
    # Read previous CID if manifest exists
    if [[ -f "$manifest_file" ]]; then
        previous_cid=$(jq -r '.current_cid // ""' "$manifest_file" 2>/dev/null)
    fi
    
    local journals=()
    # Find local journal
    if [[ -f "${sectorpath}/${IPFSNODEID: -12}.NOSTR_journal" ]]; then
        journals+=("${IPFSNODEID: -12}.NOSTR_journal")
    fi
    
    # Find journals from swarm
    for swarm_journal in $(find "$HOME/.zen/tmp/swarm/" -path "*/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}/*.NOSTR_journal" 2>/dev/null); do
        local journal_name=$(basename "$swarm_journal")
        if [[ ! " ${journals[@]} " =~ " ${journal_name} " ]]; then
            journals+=("$journal_name")
        fi
    done
    
    # Create journals JSON array
    local journals_json=$(printf '%s\n' "${journals[@]}" | jq -R . | jq -s .)
    
    # Get captain GPS coordinates
    local captain_gps=$(get_local_gps)
    local captain_lat=""
    local captain_lon=""
    if [[ -n "$captain_gps" ]]; then
        captain_lat=$(echo "$captain_gps" | cut -d',' -f1)
        captain_lon=$(echo "$captain_gps" | cut -d',' -f2)
    fi
    
    # Create manifest.json
    local manifest=$(cat << EOF
{
    "date": "${TODATE}",
    "type": "SECTOR",
    "geo_key": "${sector}",
    "coordinates": {
        "lat": "${slat}",
        "lon": "${slon}"
    },
    "captain_gps": {
        "lat": "${captain_lat}",
        "lon": "${captain_lon}",
        "email": "${CAPTAINEMAIL}"
    },
    "current_cid": "${SECROOT}",
    "ipfs_link": "${myIPFS}/ipfs/${SECROOT}",
    "previous_cid": "${previous_cid}",
    "journals": ${journals_json},
    "updated_at": $(date +%s),
    "node_id": "${IPFSNODEID}"
}
EOF
)
    
    echo "$manifest" | jq . > "$manifest_file"
    log "✓ Updated manifest.json for SECTOR ${sector}"
    
    # Create day-of-week HTML redirect (keep for backward compatibility)
    local JOUR_SEMAINE=$(LANG=fr_FR.UTF-8 date +%A)
    local HIER=$(LANG=fr_FR.UTF-8 date --date="yesterday" +%A)
    echo '<meta http-equiv="refresh" content="0;url='${myIPFS}'/ipfs/'${SECROOT}'">' \
            > ${sectorpath}/_${JOUR_SEMAINE}.html 2>/dev/null
    rm ${sectorpath}/_${HIER}.html 2>/dev/null
    
    # Clean up old ipfs.* files
    rm ${sectorpath}/ipfs.* 2>/dev/null
}

update_sector_nostr_profile() {
    local sector=$1
    local ANSWER=$2
    local SECROOT=$3

    local slat=$(echo ${sector} | cut -d '_' -f 2)
    local slon=$(echo ${sector} | cut -d '_' -f 3)
    local rlat=$(echo ${slat} | cut -d '.' -f 1)
    local rlon=$(echo ${slon} | cut -d '.' -f 1)

    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${slat}0" "${slon}0" | tail -n 1)
    RTAGS+=("[\"p\", \"$REGIONHEX\", \"$myRELAY\", \"$REGION\"]")

    local SECTORNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$SECTORNSEC")

    # Use generated SECTOR images for profile
    local SECTOR_PROFILE="${myIPFS}/ipfs/${SECROOT}/zSectorMap.jpg"
    local SECTOR_BANNER="${myIPFS}/ipfs/${SECROOT}/SectorSat.jpg"

    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$SECTORNSEC" \
        "SECTOR_${UPLANETG1PUB:0:8}${sector} ${TODATE}" "${SECTORG1PUB}" \
        "VISIO ROOM : ${VDONINJA}/?room=${SECTORG1PUB:0:8}&effects&record" \
        "${SECTOR_PROFILE}" \
        "${SECTOR_BANNER}" \
        "" "${myIPFS}/ipfs/${SECROOT}" "" "${VDONINJA}/?room=${SECTORG1PUB:0:8}&effects&record" "" "" \
        "$myRELAY" "wss://relay.copylaradio.com" \
        --zencard "$UPLANETG1PUB"

    local TAGS_JSON=$(printf '%s\n' "${STAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    send_nostr_event send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"

    if [[ -s $sectorpath/${IPFSNODEID: -12}.NOSTR_journal ]]; then
        local sector_title="SECTOR Report - ${sector}"
        local sector_content=$(format_content_as_markdown "$(cat $sectorpath/${IPFSNODEID: -12}.NOSTR_journal)" "$sector_title" "SECTOR" "$sector")
        local d_tag="sector-${sector}-${TODATE}"
        local published_at=$(date +%s)
        
        # Build article tags with sector-specific tags
        local article_tags=$(echo "$TAGS_JSON" | jq '. + [["d", "'"$d_tag"'"], ["title", "'"$sector_title"'"], ["published_at", "'"$published_at"'"], ["t", "UPlanet"], ["t", "SECTOR"], ["g", "'"${slat},${slon}"'"]]')
        
        send_nostr_event send_event \
            -privkey "$NPRIV_HEX" \
            -kind 30023 \
            -content "$sector_content" \
            -tags "$article_tags" \
            --relay "$myRELAY"
    fi
}

################################################################################
# Region Management Functions
################################################################################

process_regions() {
    local UNIQUE_REGIONS=($(echo "${REGIONS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for region in ${UNIQUE_REGIONS[@]}; do
        create_region_journal "$region"
    done
}

create_region_journal() {
    local region=$1
    create_aggregate_journal "Region" "$region" 12
}

# Generate 4 cartographic images for a REGION zone (1° = ~111km)
#
# Images generated:
# - RegionMap.jpg  : OpenStreetMap large view (1°) → archive/web
# - zRegionMap.jpg : OpenStreetMap zoomed (0.1°) → NOSTR profile picture
# - RegionSat.jpg  : Satellite large view (1°) → NOSTR banner
# - zRegionSat.jpg : Satellite zoomed (0.1°) → archive/detail
#
# Optimization: Checks swarm cache before generating (99% faster if found)
# Each image: ~900x900px, generated via page_screenshot.py
generate_region_images() {
    local rlat=$1
    local rlon=$2
    local regionpath=$3
    
    log "Generating REGION images for _${rlat}_${rlon}..."
    
    # Calculate coordinates for the region (1° square)
    local lat="${rlat}.00"
    local lon="${rlon}.00"
    
    # Generate RegionMap.jpg (large view 1°)
    if ! find_or_copy_from_swarm "RegionMap.jpg" "$regionpath" "*/UPLANET/REGIONS/_${rlat}_${rlon}/RegionMap.jpg"; then
        local REGIONMAP_URL="/ipns/copylaradio.com/Umap.html?southWestLat=${lat}&southWestLon=${lon}&deg=1"
        log "Generating RegionMap.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${REGIONMAP_URL}" "${regionpath}/RegionMap.jpg" 900 900
    fi
    
    # Generate zRegionMap.jpg (profile picture - zoomed view 0.1°)
    if ! find_or_copy_from_swarm "zRegionMap.jpg" "$regionpath" "*/UPLANET/REGIONS/_${rlat}_${rlon}/zRegionMap.jpg"; then
        local ZREGIONMAP_URL="/ipns/copylaradio.com/Umap.html?southWestLat=${lat}&southWestLon=${lon}&deg=0.1"
        log "Generating zRegionMap.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${ZREGIONMAP_URL}" "${regionpath}/zRegionMap.jpg" 900 900
    fi
    
    # Generate RegionSat.jpg (banner - wide view 1°)
    if ! find_or_copy_from_swarm "RegionSat.jpg" "$regionpath" "*/UPLANET/REGIONS/_${rlat}_${rlon}/RegionSat.jpg"; then
        local REGIONSAT_URL="/ipns/copylaradio.com/Usat.html?southWestLat=${lat}&southWestLon=${lon}&deg=1"
        log "Generating RegionSat.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${REGIONSAT_URL}" "${regionpath}/RegionSat.jpg" 900 900
    fi
    
    # Generate zRegionSat.jpg (zoomed satellite view 0.1°)
    if ! find_or_copy_from_swarm "zRegionSat.jpg" "$regionpath" "*/UPLANET/REGIONS/_${rlat}_${rlon}/zRegionSat.jpg"; then
        local ZREGIONSAT_URL="/ipns/copylaradio.com/Usat.html?southWestLat=${lat}&southWestLon=${lon}&deg=0.1"
        log "Generating zRegionSat.jpg via page_screenshot.py..."
        python "${MY_PATH}/../tools/page_screenshot.py" "${myIPFS}${ZREGIONSAT_URL}" "${regionpath}/zRegionSat.jpg" 900 900
    fi
    
    log "REGION images complete: 4/4 images ready"
}

save_region_journal() {
    local region=$1
    local content=$2
    local rlat=$(echo ${region} | cut -d '_' -f 2)
    local rlon=$(echo ${region} | cut -d '_' -f 3)
    local regionpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/${region}"
    mkdir -p "$regionpath"
    echo "$content" > "$regionpath/${IPFSNODEID: -12}.NOSTR_journal"

    # Generate region images before IPFS add
    generate_region_images "$rlat" "$rlon" "$regionpath"

    # Add to IPFS
    local REGROOT=$(ipfs add -rwHq "$regionpath"/* | tail -n 1)
    log "Published Region ${region} to IPFS: ${REGROOT}"
    
    # Update manifest with the new CID
    update_region_manifest "$regionpath" "$region" "$REGROOT"

    # Publish to Nostr
    update_region_nostr_profile "$region" "$content" "$REGROOT"
}

# Update or create manifest.json for a REGION
# Same structure as SECTOR manifest but for larger geographic zones (1°)
#
# GPS-BASED OWNERSHIP: Only creates manifest if this node is closest to zone
update_region_manifest() {
    local regionpath=$1
    local region=$2
    local REGROOT=$3
    
    local manifest_file="${regionpath}/manifest.json"
    local previous_cid=""
    
    # Extract coordinates
    local rlat=$(echo ${region} | cut -d '_' -f 2)
    local rlon=$(echo ${region} | cut -d '_' -f 3)
    
    # Calculate zone center coordinates
    local zone_lat="${rlat}.50"
    local zone_lon="${rlon}.50"
    
    # Check if this node is the closest to the zone
    if ! is_closest_node "$zone_lat" "$zone_lon" "REGION" "$region"; then
        log "⏭️  Skipping manifest creation for REGION ${region} (not closest node)"
        return 0
    fi
    
    # Read previous CID if manifest exists
    if [[ -f "$manifest_file" ]]; then
        previous_cid=$(jq -r '.current_cid // ""' "$manifest_file" 2>/dev/null)
    fi
    
    local journals=()
    # Find local journal
    if [[ -f "${regionpath}/${IPFSNODEID: -12}.NOSTR_journal" ]]; then
        journals+=("${IPFSNODEID: -12}.NOSTR_journal")
    fi
    
    # Find journals from swarm
    for swarm_journal in $(find "$HOME/.zen/tmp/swarm/" -path "*/UPLANET/REGIONS/${region}/*.NOSTR_journal" 2>/dev/null); do
        local journal_name=$(basename "$swarm_journal")
        if [[ ! " ${journals[@]} " =~ " ${journal_name} " ]]; then
            journals+=("$journal_name")
        fi
    done
    
    # Create journals JSON array
    local journals_json=$(printf '%s\n' "${journals[@]}" | jq -R . | jq -s .)
    
    # Get captain GPS coordinates
    local captain_gps=$(get_local_gps)
    local captain_lat=""
    local captain_lon=""
    if [[ -n "$captain_gps" ]]; then
        captain_lat=$(echo "$captain_gps" | cut -d',' -f1)
        captain_lon=$(echo "$captain_gps" | cut -d',' -f2)
    fi
    
    # Create manifest.json
    local manifest=$(cat << EOF
{
    "date": "${TODATE}",
    "type": "REGION",
    "geo_key": "${region}",
    "coordinates": {
        "lat": "${rlat}",
        "lon": "${rlon}"
    },
    "captain_gps": {
        "lat": "${captain_lat}",
        "lon": "${captain_lon}",
        "email": "${CAPTAINEMAIL}"
    },
    "current_cid": "${REGROOT}",
    "ipfs_link": "${myIPFS}/ipfs/${REGROOT}",
    "previous_cid": "${previous_cid}",
    "journals": ${journals_json},
    "updated_at": $(date +%s),
    "node_id": "${IPFSNODEID}"
}
EOF
)
    
    echo "$manifest" | jq . > "$manifest_file"
    log "✓ Updated manifest.json for REGION ${region}"
    
    # Clean up old ipfs.* files if they exist
    rm ${regionpath}/ipfs.* 2>/dev/null
}

update_region_nostr_profile() {
    local region=$1
    local content=$2
    local REGROOT=$3

    local rlat=$(echo ${region} | cut -d '_' -f 2)
    local rlon=$(echo ${region} | cut -d '_' -f 3)

    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${rlat}.00" "${rlon}.00" | tail -n 1) ## Get UMAP ENV for REGION = export REGIONHEX...
    local REGSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${region}" "${UPLANETNAME}${region}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$REGSEC")

    # Use generated REGION images for profile
    local REGION_PROFILE="${myIPFS}/ipfs/${REGROOT}/zRegionMap.jpg"
    local REGION_BANNER="${myIPFS}/ipfs/${REGROOT}/RegionSat.jpg"

    ## Update profile with new REGROOT
    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$REGSEC" \
        "REGION_${UPLANETG1PUB:0:8}${region}" "${REGIONG1PUB}" \
        "UPlanet ${TODATE} -- VISIO ROOM : ${VDONINJA}/?room=${REGIONG1PUB:0:8}&effects&record" \
        "${REGION_PROFILE}" \
        "${REGION_BANNER}" \
        "" "${myIPFS}/ipfs/${REGROOT}" "" "${VDONINJA}/?room=${REGIONG1PUB:0:8}&effects&record" "" "" \
        "$myRELAY" "wss://relay.copylaradio.com" \
        --zencard "$UPLANETG1PUB"

    local TAGS_JSON=$(printf '%s\n' "${RTAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    ## Confirm UMAP friendship
    send_nostr_event send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"
    
    ## Publish Report to NOSTR with kind 30023
    local region_title="REGION Report - ${region}"
    local region_content=$(format_content_as_markdown "$content" "$region_title" "REGION" "$region")
    local d_tag="region-${region}-${TODATE}"
    local published_at=$(date +%s)
    
    # Build article tags with region-specific tags
    local article_tags=$(echo "$TAGS_JSON" | jq '. + [["d", "'"$d_tag"'"], ["title", "'"$region_title"'"], ["published_at", "'"$published_at"'"], ["t", "UPlanet"], ["t", "REGION"], ["g", "'"${rlat},${rlon}"'"]]')
    
    send_nostr_event send_event \
        -privkey "$NPRIV_HEX" \
        -kind 30023 \
        -content "$region_content" \
        -tags "$article_tags" \
        --relay "$myRELAY"
}

################################################################################
# NOSTR Management Functions
################################################################################

update_friends_list() {
    local friends=("$@")

    # Get UPlanet UMAP NSEC with LAT and LON
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)

    # Update friends list using nostr_follow.sh
    if [[ ${#friends[@]} -gt 0 ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            $MY_PATH/../tools/nostr_follow.sh "$UMAPNSEC" "${friends[@]}" "$myRELAY"
        else
            $MY_PATH/../tools/nostr_follow.sh "$UMAPNSEC" "${friends[@]}" "$myRELAY" 2>&1 | grep -v "Already following" | grep -v "Verification successful" | grep -v "Sending event" | grep -v "Response from" | grep -v "EVENT" | grep -v "Follow list updated" | sed 's/\x1b\[[0-9;]*m//g'
        fi
        log_always "(${LAT} ${LON}) Updated friends list with ${#friends[@]} active friends"
    else
        log_always "(${LAT} ${LON}) No active friends to update"
    fi
}

generate_ai_summary() {
    local text=$1
    local QUESTION="[TEXT] $text [/TEXT] --- # 1. Write a summary of [TEXT] in Markdown format # 2. Highlight key points with their authors # 3. Add hastags and emoticons # 4. Structure with Markdown headers, lists, and emphasis # IMPORTANT : Use the same language as mostly used in [TEXT]."
    $MY_PATH/../IA/question.py "${QUESTION}"
}

format_content_as_markdown() {
    local content=$1
    local title=$2
    local geo_type=$3
    local geo_id=$4
    local image_url=$5  # Optional image URL
    
    cat << EOF
# ${title}

**Location**: ${geo_type} ${geo_id}  
**Date**: ${TODATE}  
**Generated by**: UPlanet Geo Key System

EOF

    # Add image if provided
    if [[ -n "$image_url" && "$image_url" != "" ]]; then
        cat << EOF
![UMAP Journal Image](${image_url})

EOF
    fi
    
    cat << EOF
---

${content}

---

*This report was automatically generated from geolocated Nostr messages.*  
*More info: ${myIPFS}/ipns/copylaradio.com*
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    check_dependencies
    display_banner

    BLACKLIST_FILE="${HOME}/.zen/strfry/blacklist.txt"
    AMISOFAMIS_FILE="${HOME}/.zen/strfry/amisOfAmis.txt"

    # Process UMAPs
    for hexline in $(ls ~/.zen/game/nostr/UMAP_*_*/HEX); do
        # Reset global variables for each UMAP to ensure clean state
        LAT=""
        LON=""
        TAGS=()
        ACTIVE_FRIENDS=()
        
        process_umap_messages "$hexline"
    done

    # Process Sectors
    process_sectors

    # Process Regions
    process_regions

    # Clean up duplicate entries in amisOfAmis.txt
    if [[ -f "$AMISOFAMIS_FILE" ]]; then
        # Create a temporary file with unique entries
        sort -u "$AMISOFAMIS_FILE" > "${AMISOFAMIS_FILE}.tmp"
        # Overwrite the original file with deduplicated content
        mv "${AMISOFAMIS_FILE}.tmp" "$AMISOFAMIS_FILE"
        echo "Cleaned $AMISOFAMIS_FILE: removed duplicate entries."
    fi

    # Remove entries from blacklist.txt that are found in amisOfAmis.txt
    if [[ -f "$BLACKLIST_FILE" && -f "$AMISOFAMIS_FILE" ]]; then
        # Create a temporary file for the filtered blacklist
        grep -v -f "$AMISOFAMIS_FILE" "$BLACKLIST_FILE" > "${BLACKLIST_FILE}.tmp"
        # Overwrite the original blacklist with the filtered content
        mv "${BLACKLIST_FILE}.tmp" "$BLACKLIST_FILE"
        echo "Cleaned $BLACKLIST_FILE: removed entries found in $AMISOFAMIS_FILE."
    elif [[ ! -f "$BLACKLIST_FILE" ]]; then
        echo "Info: $BLACKLIST_FILE not found, no blacklist to clean."
    elif [[ ! -f "$AMISOFAMIS_FILE" ]]; then
        echo "Info: $AMISOFAMIS_FILE not found, no friends of friends list for cleaning blacklist."
    fi

    exit 0
}

main
