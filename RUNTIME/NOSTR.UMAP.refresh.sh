#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# NIP-101 related : strfry processing "UPlanet message"
# This script aggregates and manages geolocated content from Nostr.
#
# - Identifies UMAPs (Geo Keys) from ~/.zen/game/nostr/UMAP*/HEX.
# - Each UMAP acts as a Nostr identity, making friends with users whose messages
#   are associated with its location.
# - Daily, it retrieves messages from these friends and relays them in a journal.
# - If the UMAP journal exceeds 10 messages or 3000 characters, it is summarized
#   and grouped by author using AI (question.py), keeping references to each profile.
# - For SECTOR and REGION, only messages with at least 3 (SECTOR) or 12 (REGION) likes
#   are included, and the journal is also summarized by AI if it exceeds the threshold.
# - Special content like '#market' tags triggers image downloads and ad JSON creation.
# - Publishes journals and summaries to Nostr and IPFS.
# - Manages friend activity, sending reminders or removing inactive friends.
# - Maintains and cleans up a "friend of friend" list from active contacts.
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

################################################################################
# Utility Functions
################################################################################

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

    process_umap_friends "$hex" "$UMAPPATH"

    # Appel IA si journal UMAP trop long
    MAX_MSGS=10
    MAX_SIZE=3000
    if [[ -f "${UMAPPATH}/NOSTR_messages" ]]; then
        msg_count=$(grep -c '^On ' "${UMAPPATH}/NOSTR_messages")
        file_size=$(wc -c < "${UMAPPATH}/NOSTR_messages")
        if [[ $msg_count -gt $MAX_MSGS || $file_size -gt $MAX_SIZE ]]; then
            IA_PROMPT="[TEXT] $(cat ${UMAPPATH}/NOSTR_messages) [/TEXT] --- \
# 1. Summarize and group messages by profile (author), clearly cite each profile. \
# 2. For each profile, list the main messages of the day. \
# 3. Add hashtags and emojis for readability. \
# 4. IMPORTANT: Never omit an author, even if you summarize. \
# 5. Use the same language as the messages."
            ANSWER=$($MY_PATH/../IA/question.py "$IA_PROMPT")
            echo "$ANSWER" > "${UMAPPATH}/NOSTR_messages"
        fi
    fi

    setup_umap_identity "$UMAPPATH"
}

process_umap_friends() {
    local hex=$1
    local UMAPPATH=$2

    # Initialize NPRIV_HEX early for this UMAP using global coordinates
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")

    local friends=($($MY_PATH/../tools/nostr_get_N1.sh $hex 2>/dev/null))
    local SINCE=$(date -d "48 hours ago" +%s)
    local WEEK_AGO=$(date -d "7 days ago" +%s)
    local MONTH_AGO=$(date -d "28 days ago" +%s)

    cd ~/.zen/strfry

    # Reset global arrays for this UMAP
    TAGS=()
    ACTIVE_FRIENDS=()

    # First, get all market messages from friends in the last 48h
    process_market_messages_from_friends "${friends[@]}" "$UMAPPATH" "$SINCE"

    for ami in ${friends[@]}; do
        process_friend_messages "$ami" "$UMAPPATH" "$SINCE" "$WEEK_AGO" "$MONTH_AGO" "$NPRIV_HEX"
    done

    update_friends_list "${ACTIVE_FRIENDS[@]}"
    
    # Check if UMAP has no active friends and clean up cache if needed
    if [[ ${#ACTIVE_FRIENDS[@]} -eq 0 ]]; then
        rm -Rf "$UMAPPATH" ## Remove UMAP cache if no active friends
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
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$GOODBYE_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY" 2>/dev/null
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
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$REMINDER_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY"
    echo "📬 Sent reminder to $profile" 2>/dev/null >> ${UMAPPATH}/NOSTR_messages
}

process_market_messages_from_friends() {
    local friends=("$@")
    local UMAPPATH=${friends[-2]}
    local SINCE=${friends[-1]}
    unset "friends[-1]" "friends[-2]"

    # Create authors JSON array for strfry query
    local authors_json=$(printf '"%s",' "${friends[@]}"); authors_json="[${authors_json%,}]"

    # Get all market messages from friends in the last 48h
    ./strfry scan "{
      \"kinds\": [1],
      \"authors\": ${authors_json},
      \"since\": ${SINCE},
      \"limit\": 500
    }" 2>/dev/null | jq -c 'select(.kind == 1 and (.content | contains("#market"))) | {id: .id, content: .content, created_at: .created_at, author: .pubkey}' | while read -r message; do
        local content=$(echo "$message" | jq -r .content)
        local message_id=$(echo "$message" | jq -r .id)
        local author_hex=$(echo "$message" | jq -r .author)
        local created_at=$(echo "$message" | jq -r .created_at)

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

    # Get all messages from the last 48 hours
    ./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '$SINCE'
    }' 2>/dev/null | jq -c 'select(.kind == 1) | {id: .id, content: .content, created_at: .created_at}' | while read -r message; do
        local content=$(echo "$message" | jq -r .content)
        ## Avoid treating Captain Warning Messages sent to unregistered message publishers
        if [[ "$content" =~ "Hello NOSTR visitor." ]]; then continue; fi  
        local message_id=$(echo "$message" | jq -r .id)
        local created_at=$(echo "$message" | jq -r .created_at)
        local date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M')

        # Format journaliste
        echo "On $date_str, nostr:$author_nprofile published:" >> ${UMAPPATH}/NOSTR_messages
        echo "> $content" >> ${UMAPPATH}/NOSTR_messages
        echo "" >> ${UMAPPATH}/NOSTR_messages

        # Process #market messages, ensuring they are not processed multiple times
        if [[ "$content" == *"#market"* ]]; then
            # Check if the ad file already exists to avoid reprocessing
            if [[ ! -f "${UMAPPATH}/APP/uMARKET/ads/${message_id}.json" ]]; then
                process_market_images "$content" "$UMAPPATH"
                create_market_ad "$content" "${message_id}" "$UMAPPATH" "$ami" "$created_at"
            fi
        fi
    done | head -n 100 # limit to 100 messages from 48h from each friend
}

process_market_images() {
    local content=$1
    local UMAPPATH=$2

    # Ensure Images directory exists
    mkdir -p "${UMAPPATH}/APP/uMARKET/Images"

    local image_urls=$(echo "$content" | grep -o 'https\?://[^[:space:]]*\.\(jpg\|jpeg\|png\|gif\)')
    if [[ -n "$image_urls" ]]; then
        for img_url in $image_urls; do
            # Validate URL format
            if [[ ! "$img_url" =~ ^https?://[^[:space:]]+\.(jpg|jpeg|png|gif)$ ]]; then
                echo "⚠️  Invalid image URL format: $img_url" >&2
                continue
            fi
            
            local filename=$(basename "$img_url")
            # Sanitize filename to prevent path traversal
            filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]//g')
            
            local umap_filename="UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}_${filename}"
            local target_path="${UMAPPATH}/APP/uMARKET/Images/$umap_filename"
            
            # Check if file already exists
            if [[ ! -f "$target_path" ]]; then
                # Download with timeout and size limit
                if wget -q --timeout=30 --tries=3 --max-redirect=3 --limit-rate=1m "$img_url" -O "$target_path" 2>/dev/null; then
                    # Validate downloaded file
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

create_market_ad() {
    local content=$1
    local message_id=$2
    local UMAPPATH=$3
    local ami=$4
    local created_at=$5

    # Ensure ads directory exists
    mkdir -p "${UMAPPATH}/APP/uMARKET/ads"

    # Get author profile information
    local author_nprofile=$($MY_PATH/../tools/nostr_hex2nprofile.sh "$ami" 2>/dev/null)
    
    # Extract local image filenames
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

cleanup_old_files() {
    local SIX_MONTHS_AGO=$(date -d "6 months ago" +%s)

    cleanup_old_documents "$SIX_MONTHS_AGO" "$NPRIV_HEX"
    cleanup_old_images "$SIX_MONTHS_AGO"
    cleanup_orphaned_ads
}

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
            if [[ -n "$author" && "$author" != "null" ]]; then
                local notification="🛒 nostr:$author_profile votre annonce a été retirée après 6 mois. Vous pouvez la republier si elle est toujours d'actualité. #UPlanet #uMARKET #Community"

                nostpy-cli send_event \
                    -privkey "$NPRIV_HEX" \
                    -kind 1 \
                    -content "$notification" \
                    -tags "[['p', '$author']]" \
                    --relay "$myRELAY" 2>/dev/null
            fi

            rm "$file"
        fi
    done < <(find "ads" -type f -name "*.json" -print0)
}

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

cleanup_orphaned_ads() {
    if [[ ! -d "ads" ]]; then
        return
    fi

    echo "🔍 Checking for orphaned and malformed market advertisements..."

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
            echo "🗑️  Removing malformed JSON ad: ${message_id}"
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
                echo "🗑️  Removing orphaned ad: ${message_id} ($author)"
                # Remove the orphaned ad file
                rm "$file"
                ((orphaned_count++))
            fi
        fi
    done < <(find "$current_dir/ads" -type f -name "*.json" -print0)

    # Return to original directory
    cd "$current_dir"

    if [[ $orphaned_count -gt 0 || $malformed_count -gt 0 ]]; then
        echo "✅ Cleaned up $orphaned_count orphaned and $malformed_count malformed advertisements"
    else
        echo "✅ No orphaned or malformed advertisements found"
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

    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY" 2>/dev/null

    if [[ $(cat ${UMAPPATH}/NOSTR_messages) != "" ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat ${UMAPPATH}/NOSTR_messages) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY" 2>/dev/null
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

    echo "Creating ${type} ${geo_id} Journal from recently liked messages (threshold: ${like_threshold} likes)"

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

    if [[ ${#all_friends[@]} -eq 0 ]]; then echo "No friends found for ${type} ${geo_id}."; rm -Rf "$geo_path"; return; fi
    local unique_friends=($(echo "${all_friends[@]}" | tr ' ' '\n' | sort -u))

    # 2. Get recently liked message IDs from friends
    local authors_json=$(printf '"%s",' "${unique_friends[@]}"); authors_json="[${authors_json%,}]"
    local SINCE=$(date -d "48 hours ago" +%s)
    cd ~/.zen/strfry
    local liked_event_ids=($(./strfry scan "{\"kinds\": [7], \"authors\": ${authors_json}, \"since\": ${SINCE}}" 2>/dev/null | jq -r '.tags[] | select(.[0] == "e") | .[1]' | sort -u))
    cd - >/dev/null

    if [[ ${#liked_event_ids[@]} -eq 0 ]]; then echo "No recently liked messages for ${type} ${geo_id}."; rm -Rf "$geo_path"; return; fi
    echo "Found ${#liked_event_ids[@]} unique recently liked messages to process for ${type} ${geo_id}."

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
                
                echo "[$date_str] $author_nprofile ($likes likes) :" >> "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"
                echo "> $content" >> "$geo_path/${IPFSNODEID: -12}.NOSTR_journal"
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

    local SECROOT=$(ipfs add -rwHq $sectorpath/* | tail -n 1)
    update_sector_calendar "$sectorpath" "$SECROOT"
    echo "$SECROOT"
}

update_sector_calendar() {
    local sectorpath=$1
    local SECROOT=$2

    echo "${SECROOT}" > ${sectorpath}/ipfs.${DEMAINDATE} 2>/dev/null
    echo "${SECROOT}" > ${sectorpath}/ipfs.${TODATE} 2>/dev/null
    rm ${sectorpath}/ipfs.${YESTERDATE} 2>/dev/null

    local JOUR_SEMAINE=$(LANG=fr_FR.UTF-8 date +%A)
    local HIER=$(LANG=fr_FR.UTF-8 date --date="yesterday" +%A)
    echo '<meta http-equiv="refresh" content="0;url='${myIPFS}'/ipfs/'${SECROOT}'">' \
            > ${sectorpath}/_${JOUR_SEMAINE}.html 2>/dev/null
    rm ${sectorpath}/_${HIER}.html 2>/dev/null
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

    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$SECTORNSEC" \
        "SECTOR_${UPLANETG1PUB:0:8}${sector} ${TODATE}" "${SECTORG1PUB}" \
        "VISIO ROOM : $myIPFS$VDONINJA/?room=${SECTORG1PUB:0:8}&effects&record" \
        "${myIPFS}/ipfs/Qmeezy8CtoXzz9LqA8mWqzYDweEYMqAvjZ1JyZFDW7pLQC/LivingTV.gif" \
        "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
        "" "${myIPFS}/ipfs/${SECROOT}" "" "$myIPFS$VDONINJA/?room=${SECTORG1PUB:0:8}&effects&record" "" "" \
        "$myRELAY" "wss://relay.copylaradio.com" \
        --zencard "$UPLANETNAME_G1"

    local TAGS_JSON=$(printf '%s\n' "${STAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY" 2>/dev/null

    if [[ -s $sectorpath/${IPFSNODEID: -12}.NOSTR_journal ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat $sectorpath/${IPFSNODEID: -12}.NOSTR_journal) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY" 2>/dev/null
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

save_region_journal() {
    local region=$1
    local content=$2
    local rlat=$(echo ${region} | cut -d '_' -f 2)
    local rlon=$(echo ${region} | cut -d '_' -f 3)
    local regionpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/${region}"
    mkdir -p "$regionpath"
    echo "$content" > "$regionpath/${IPFSNODEID: -12}.NOSTR_journal"

    # Minimal IPFS publishing, can be expanded
    local REGROOT=$(ipfs add -rwHq "$regionpath"/* | tail -n 1)
    echo "Published Region ${region} to IPFS: ${REGROOT}"

    # Publish to Nostr
    update_region_nostr_profile "$region" "$content" "$REGROOT"
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

    ## Update profile with new REGROOT
    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$REGSEC" \
        "REGION_${UPLANETG1PUB:0:8}${region}" "${REGIONG1PUB}" \
        "UPlanet ${TODATE} -- VISIO ROOM : $myIPFS$VDONINJA/?room=${REGIONG1PUB:0:8}&effects&record" \
        "${myIPFS}/ipfs/QmRsRTZuVwL6UsjLGooVMFFTbNfeswfCaRmJHTBmk2XiqU/internet.png" \
        "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
        "" "${myIPFS}/ipfs/${REGROOT}" "" "$myIPFS$VDONINJA/?room=${REGIONG1PUB:0:8}&effects&record" "" "" \
        "$myRELAY" "wss://relay.copylaradio.com" \
        --zencard "$UPLANETNAME_G1"

    local TAGS_JSON=$(printf '%s\n' "${RTAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    ## Confirm UMAP friendship
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY" 2>/dev/null
    
    ## Publish Report to NOSTR
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
    -content "$content $myIPFS/ipns/copylaradio.com" \
        --relay "$myRELAY" 2>/dev/null
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
        $MY_PATH/../tools/nostr_follow.sh "$UMAPNSEC" "${friends[@]}" "$myRELAY"
        echo "(${LAT} ${LON}) Updated friends list with ${#friends[@]} active friends "
    else
        echo "(${LAT} ${LON}) No active friends to update"
    fi
}

generate_ai_summary() {
    local text=$1
    local QUESTION="[TEXT] $text [/TEXT] --- # 1. Write a summary of [TEXT] # 2. Highlight key points with their authors # 3. Add hastags and emoticons # IMPORTANT : Use the same language as mostly used in [TEXT]."
    $MY_PATH/../IA/question.py "${QUESTION}"
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
