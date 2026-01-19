#!/bin/bash
################################################################################
# Script: nostr_tube_manager.sh
# Description: Monitor and manage NostrTube video chain for MULTIPASS users
# Usage: nostr_tube_manager.sh [COMMAND] [OPTIONS]
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# Source common tools
[[ -s "${HOME}/.zen/Astroport.ONE/tools/my.sh" ]] \
    && source "${HOME}/.zen/Astroport.ONE/tools/my.sh"

################################################################################
# Colors for output
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Configuration
################################################################################
IPFS_GATEWAY="${myLIBRA:-http://127.0.0.1:8080}"
UPASSPORT_API="${myHOST:-http://127.0.0.1:54321}"
NOSTR_GET_EVENTS="${MY_PATH}/nostr_get_events.sh"
NOSTR_GET_EVENT_BY_ID="${MY_PATH}/nostr_get_event_by_id.sh"
UPLOAD2IPFS="${HOME}/.zen/UPassport/upload2ipfs.sh"
PUBLISH_NOSTR_VIDEO="${MY_PATH}/publish_nostr_video.sh"
TEMP_DIR="${HOME}/.zen/tmp/nostr_tube_$$"

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
${CYAN}NostrTube Manager - Monitor and upgrade MULTIPASS video chains${NC}

${YELLOW}USAGE:${NC}
    nostr_tube_manager.sh COMMAND [OPTIONS]

${YELLOW}COMMANDS:${NC}
    list              List all NostrTube videos for a user
    list-all          List ALL NostrTube videos from all users
    browse            Interactive browser to explore channels and videos
    channel           Interactive channel administration (connect & manage)
    upgrade           Upgrade specific video(s) with fresh metadata
    upgrade-all       Upgrade all videos for a user
    check             Check video metadata completeness
    stats             Show statistics for user's video chain
    cleanup           Clean up non-compliant events (no metadata or no channel)
    
${YELLOW}INTERACTIVE FEATURES (in browse/details menu):${NC}
    Export tree       Export all events related to a video (kind 21/22, 1985, 1986, 30001, 1111, 5)
    Delete tree       Delete complete video tree (LOCAL accounts only - MULTIPASS on this station)

${YELLOW}OPTIONS:${NC}
    -u, --npub NPUB           User's npub key
    -x, --hex HEX             User's hex pubkey
    -e, --email EMAIL         User's email address
    -i, --event-id ID         Specific event ID to upgrade
    -k, --kind KIND           Video kind (21 or 22, default: both)
    -l, --limit N             Limit number of results (default: 100)
    -f, --force               Skip confirmation prompts
    -v, --verbose             Verbose output
    -h, --help                Show this help message

${YELLOW}EXAMPLES:${NC}
    # List ALL videos from all users
    nostr_tube_manager.sh list-all

    # Browse channels and videos interactively
    nostr_tube_manager.sh browse

    # Interactive channel administration
    nostr_tube_manager.sh channel --email user@example.com

    # List all videos for a user
    nostr_tube_manager.sh list --npub npub1abc...

    # Check metadata completeness
    nostr_tube_manager.sh check --email user@example.com

    # Upgrade all videos (add missing gifanim_ipfs, etc.)
    nostr_tube_manager.sh upgrade-all --hex abc123...

    # Upgrade specific video
    nostr_tube_manager.sh upgrade --event-id evt123... --force

    # Show statistics
    nostr_tube_manager.sh stats --npub npub1abc...

    # Clean up non-compliant events (no metadata or no channel tag)
    nostr_tube_manager.sh cleanup --force

${YELLOW}UPGRADE PROCESS:${NC}
    1. Download original video from IPFS
    2. Re-upload via upload2ipfs.sh (generates fresh metadata)
    3. Delete old NOSTR event
    4. Publish new event with complete metadata (including gifanim_ipfs)

${YELLOW}EXPORT TREE PROCESS:${NC}
    Exports all events related to a video:
    - Main video event (kind 21/22)
    - User tags (kind 1985 - NIP-32)
    - TMDB enrichments (kind 1986 - community contributions)
    - Author updates (kind 30001 - replaceable enrichments)
    - Comments (kind 1111 - NIP-22)
    - Deletion events (kind 5 - if already deleted)
    Export saved to: ~/.zen/tmp/video_export_*/video_tree_*.json

${YELLOW}DELETE TREE PROCESS (LOCAL accounts only):${NC}
    1. Create backup export (all related events)
    2. Publish kind 5 deletion events for all related events
    3. Physical deletion using nostr_get_events.sh --del --force
    ⚠️  Only available for LOCAL accounts (MULTIPASS on this station)
    ⚠️  This permanently removes ALL events from database

${YELLOW}NOTES:${NC}
    - Requires jq, ipfs, and curl
    - Videos are temporarily downloaded to ~/.zen/tmp/
    - Old events are permanently deleted (cannot be undone)
    - Use --force to skip confirmation prompts
    - Export/Delete tree features require LOCAL account (MULTIPASS on station)

EOF
    exit 0
}

################################################################################
# Helper functions
################################################################################
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    command -v jq &> /dev/null || missing+=("jq")
    command -v curl &> /dev/null || missing+=("curl")
    command -v ipfs &> /dev/null || missing+=("ipfs")
    
    [[ ! -f "$NOSTR_GET_EVENTS" ]] && missing+=("nostr_get_events.sh")
    [[ ! -f "$UPLOAD2IPFS" ]] && missing+=("upload2ipfs.sh")
    [[ ! -f "$PUBLISH_NOSTR_VIDEO" ]] && missing+=("publish_nostr_video.sh")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Convert npub to hex
npub_to_hex() {
    local npub="$1"
    
    # Simple conversion using Python (if available)
    if command -v python3 &> /dev/null; then
        python3 -c "
import sys
try:
    from nostr.key import PublicKey
    pk = PublicKey.from_npub('$npub')
    print(pk.hex())
except:
    sys.exit(1)
" 2>/dev/null && return 0
    fi
    
    # Fallback: assume it's already hex if conversion fails
    echo "$npub"
}

# Find user's hex pubkey from email
find_hex_from_email() {
    local email="$1"
    
    # Search in ~/.zen/game/players/
    local player_dir="${HOME}/.zen/game/players"
    
    if [[ ! -d "$player_dir" ]]; then
        log_error "Players directory not found: $player_dir"
        return 1
    fi
    
    # Find directory matching email
    for dir in "$player_dir"/*/"$email"; do
        if [[ -d "$dir" ]] && [[ -f "$dir/.secret.nostr" ]]; then
            # Extract HEX from .secret.nostr (format: NSEC=...; NPUB=...; HEX=...;)
            local hex=$(grep -oP 'HEX=\K[a-f0-9]{64}' "$dir/.secret.nostr" 2>/dev/null)
            if [[ -n "$hex" ]]; then
                echo "$hex"
                return 0
            fi
        fi
    done
    
    log_error "Could not find hex pubkey for email: $email"
    return 1
}

# Check if a pubkey (hex) exists locally in ~/.zen/game/nostr/*/HEX
check_local_pubkey() {
    local pubkey_hex="$1"
    
    # Search for this pubkey in all HEX files
    grep -qr "^${pubkey_hex}$" "${HOME}/.zen/game/nostr"/*@*/HEX 2>/dev/null
}

# Delete specific NOSTR event by ID using kind 5 (NIP-09) or physical deletion
delete_event_by_id() {
    local event_id="$1"
    local user_hex="$2"
    local force="${3:-false}"
    local deletion_mode="${4:-kind5}"  # "kind5", "physical", or "both"
    
    log_debug "Deleting event: $event_id (mode: $deletion_mode)"
    
    if [[ "$deletion_mode" == "both" ]]; then
        # Do both: kind 5 first, then physical deletion
        log_info "Combined deletion mode: kind 5 + physical"
        
        # Step 1: Publish kind 5 deletion event
        log_info "Step 1/2: Publishing kind 5 deletion event..."
        if delete_event_by_id "$event_id" "$user_hex" "$force" "kind5"; then
            log_success "✅ Kind 5 deletion event published"
        else
            log_error "❌ Failed to publish kind 5 event"
            return 1
        fi
        
        # Step 2: Physical deletion
        log_info "Step 2/2: Physical deletion from database..."
        if delete_event_by_id "$event_id" "$user_hex" "$force" "physical"; then
            log_success "✅ Event physically deleted from database"
        else
            log_error "❌ Failed to physically delete event"
            return 1
        fi
        
        log_success "🎉 Complete deletion finished (kind 5 + physical)"
        return 0
        
    elif [[ "$deletion_mode" == "physical" ]]; then
        # Physical deletion using nostr_get_events.sh --del
        log_info "Physical deletion mode (using --del)"
        
        if [[ "$force" != "true" ]]; then
            log_warning "Confirmation required for physical deletion"
            echo "Event ID to delete: $event_id"
            read -p "Continue with physical deletion? (yes/NO): " confirm
            
            if [[ "$confirm" != "yes" ]]; then
                log_warning "Deletion cancelled"
                return 1
            fi
        fi
        
        # Use nostr_get_events.sh with --del option
        local force_flag=""
        [[ "$force" == "true" ]] && force_flag="--force"
        
        # Delete by filtering on this specific event ID
        # We need to query first, then delete based on author + created_at or use strfry delete directly
        log_info "Executing physical deletion..."
        
        # Using strfry delete directly with filter
        local STRFRY_DIR="$HOME/.zen/strfry"
        local STRFRY_BIN="${STRFRY_DIR}/strfry"
        
        if [[ ! -f "${STRFRY_BIN}" ]]; then
            log_error "strfry not found at ${STRFRY_BIN}"
            return 1
        fi
        
        cd "$STRFRY_DIR" || return 1
        
        # Build filter JSON with specific event ID
        local IDS_JSON=$(echo "$event_id" | jq -R . | jq -s -c '{ids: .}')
        
        log_debug "Delete filter: $IDS_JSON"
        
        if ./strfry delete --filter="$IDS_JSON" 2>&1 >/dev/null; then
            log_success "Event physically deleted from database"
            cd - > /dev/null 2>&1
            return 0
        else
            log_error "Failed to physically delete event: $event_id"
            cd - > /dev/null 2>&1
            return 1
        fi
        
    else
        # Kind 5 deletion (NIP-09) - publish deletion event
        log_info "Publishing kind 5 deletion event (NIP-09)..."
        
        # Find user's .secret.nostr file
        local secret_file=""
        
        # Query DID document for this pubkey (kind 30800)
        log_debug "Querying DID document for pubkey: ${user_hex:0:16}..."
        local did_event=$(bash "$NOSTR_GET_EVENTS" --kind 30800 --author "$user_hex" --limit 1 2>/dev/null)
        
        if [[ -n "$did_event" ]] && [[ "$did_event" != "[]" ]]; then
            # Try to extract email from event tags first
            local email=$(echo "$did_event" | jq -r 'if type == "array" then .[0].tags[]? else .tags[]? end | select(.[0] == "email") | .[1]' 2>/dev/null | head -n1)
            
            # If not found in tags, try from content.metadata.email
            if [[ -z "$email" ]]; then
                email=$(echo "$did_event" | jq -r 'if type == "array" then .[0].content else .content end | fromjson | .metadata.email // empty' 2>/dev/null)
            fi
            
            # If still not found, try from content.alsoKnownAs
            if [[ -z "$email" ]]; then
                email=$(echo "$did_event" | jq -r 'if type == "array" then .[0].content else .content end | fromjson | .alsoKnownAs[]? | select(startswith("mailto:")) | sub("^mailto:"; "")' 2>/dev/null | head -n1)
            fi
            
            if [[ -n "$email" ]]; then
                log_debug "Found email from DID: $email"
                secret_file="${HOME}/.zen/game/nostr/${email}/.secret.nostr"
                
                if [[ ! -f "$secret_file" ]]; then
                    log_error "Secret file not found at: $secret_file"
                    return 1
                fi
            else
                log_error "Could not extract email from DID document"
                return 1
            fi
        else
            log_error "No DID document found for user: ${user_hex:0:16}..."
            return 1
        fi
        
        # Confirmation prompt if not forced
        if [[ "$force" != "true" ]]; then
            log_warning "Confirmation required for deletion"
            echo "Event ID to delete: $event_id"
            read -p "Continue with kind 5 deletion? (yes/NO): " confirm
            
            if [[ "$confirm" != "yes" ]]; then
                log_warning "Deletion cancelled"
                return 1
            fi
        fi
        
        local NOSTR_SEND_NOTE="${MY_PATH}/nostr_send_note.py"
        
        if [[ ! -f "$NOSTR_SEND_NOTE" ]]; then
            log_error "nostr_send_note.py not found at: $NOSTR_SEND_NOTE"
            return 1
        fi
        
        # Build tags JSON: [["e", "event_id"]]
        local tags_json="[[\"e\",\"$event_id\"]]"
        
        # Send deletion event
        local result=$(python3 "$NOSTR_SEND_NOTE" \
            --keyfile "$secret_file" \
            --content "Video deleted by owner" \
            --kind 5 \
            --tags "$tags_json" \
            --json 2>&1)
        
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            local success=$(echo "$result" | jq -r '.success // false' 2>/dev/null)
            
            if [[ "$success" == "true" ]]; then
                log_success "Deletion event published successfully (kind 5)"
                return 0
            else
                log_error "Failed to publish deletion event"
                log_debug "Result: $result"
                return 1
            fi
        else
            log_error "Failed to execute nostr_send_note.py"
            log_debug "Output: $result"
            return 1
        fi
    fi
}

################################################################################
# Command: list-all
################################################################################
cmd_list_all() {
    local kind="${KIND:-}"
    local limit="${LIMIT:-100}"
    
    log_info "Fetching ALL NostrTube videos from relay..."
    
    # Build query (no author filter)
    local kind_filter=""
    if [[ "$kind" == "21" ]] || [[ "$kind" == "22" ]]; then
        kind_filter="--kind $kind"
    else
        # Get both kind 21 and 22
        kind_filter="21,22"
    fi
    
    local events=""
    if [[ "$kind_filter" == "21,22" ]]; then
        # Query both kinds
        events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --limit "$limit" 2>/dev/null)
        events+=$'\n'
        events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --limit "$limit" 2>/dev/null)
    else
        events=$(bash "$NOSTR_GET_EVENTS" $kind_filter --limit "$limit" 2>/dev/null)
    fi
    
    if [[ -z "$events" ]]; then
        log_warning "No videos found on relay"
        return 0
    fi
    
    # Parse and display events with channel grouping
    local -A channel_count
    local count=0
    local missing_gifanim=0
    local missing_thumbnail=0
    local missing_info=0
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                     ${YELLOW}All NostrTube Videos (Relay)${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        count=$((count + 1))
        
        local author=$(echo "$event" | jq -r '.pubkey // "unknown"')
        local kind=$(echo "$event" | jq -r '.kind // 0')
        local created_at=$(echo "$event" | jq -r '.created_at // 0')
        local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
        
        # Extract channel from tags
        local channel=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "t" and (.[1] | startswith("Channel-"))) | .[1]' 2>/dev/null | head -n1)
        if [[ -n "$channel" ]]; then
            channel=${channel#Channel-}
            channel_count["$channel"]=$((${channel_count["$channel"]:-0} + 1))
        else
            channel="unknown"
            channel_count["unknown"]=$((${channel_count["unknown"]:-0} + 1))
        fi
        
        # Extract metadata from tags
        local title=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "title") | .[1] // empty' 2>/dev/null | head -n1)
        local url=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "url") | .[1] // empty' 2>/dev/null | head -n1)
        local duration=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "duration") | .[1] // "0"' 2>/dev/null | head -n1)
        local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local thumbnail=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local info=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "info") | .[1] // empty' 2>/dev/null | head -n1)
        
        # Extract source type from tag "i" with prefix "source:"
        local source_tag=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "i" and (.[1] | startswith("source:"))) | .[1]' 2>/dev/null | head -n1)
        local source_type=""
        local source_icon=""
        if [[ -n "$source_tag" ]]; then
            source_type=${source_tag#source:}
            case "$source_type" in
                webcam) source_icon="🎥" ;;
                film) source_icon="🎬" ;;
                serie) source_icon="📺" ;;
                video) source_icon="📹" ;;
                youtube) source_icon="▶️" ;;
                *) source_icon="📄" ;;
            esac
        fi
        
        # Extract CID from URL
        local cid=$(echo "$url" | grep -oP '(?<=ipfs/)[^/]+' | head -n1)
        
        [[ -z "$title" ]] && title="(no title)"
        [[ -z "$cid" ]] && cid="N/A"
        
        # Check completeness
        local status_icons=""
        [[ -z "$gifanim" ]] && { status_icons+="❌GIF "; missing_gifanim=$((missing_gifanim + 1)); } || status_icons+="✅GIF "
        [[ -z "$thumbnail" ]] && { status_icons+="❌THUMB "; missing_thumbnail=$((missing_thumbnail + 1)); } || status_icons+="✅THUMB "
        [[ -z "$info" ]] && { status_icons+="❌INFO"; missing_info=$((missing_info + 1)); } || status_icons+="✅INFO"
        
        echo -e "${YELLOW}Video #$count${NC} (kind $kind) - Channel: ${CYAN}$channel${NC}"
        echo -e "  👤 Author: ${author:0:16}..."
        echo -e "  📅 Date: $date"
        echo -e "  🆔 Event: ${event_id:0:16}..."
        echo -e "  📹 Title: $title"
        [[ -n "$source_type" ]] && echo -e "  ${source_icon} Source: ${source_type}"
        echo -e "  💿 CID: ${cid:0:16}..."
        echo -e "  ⏱️  Duration: ${duration}s"
        echo -e "  📊 Status: $status_icons"
        echo ""
        
    done <<< "$events"
    
    # Summary with channel breakdown
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Total videos: $count${NC}"
    echo ""
    echo -e "${YELLOW}Channels:${NC}"
    for channel in "${!channel_count[@]}"; do
        echo -e "  📺 $channel: ${channel_count[$channel]} video(s)"
    done
    echo ""
    
    if [[ $missing_gifanim -gt 0 ]] || [[ $missing_thumbnail -gt 0 ]] || [[ $missing_info -gt 0 ]]; then
        echo -e "${YELLOW}Incomplete metadata (global):${NC}"
        [[ $missing_gifanim -gt 0 ]] && echo -e "  ❌ Missing animated GIF: $missing_gifanim videos"
        [[ $missing_thumbnail -gt 0 ]] && echo -e "  ❌ Missing thumbnail: $missing_thumbnail videos"
        [[ $missing_info -gt 0 ]] && echo -e "  ❌ Missing info.json: $missing_info videos"
    else
        echo -e "${GREEN}✅ All videos have complete metadata${NC}"
    fi
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: list
################################################################################
cmd_list() {
    local user_hex="$1"
    local kind="${KIND:-}"
    local limit="${LIMIT:-100}"
    
    log_info "Fetching NostrTube videos for user: ${user_hex:0:16}..."
    
    # Build query
    local kind_filter=""
    if [[ "$kind" == "21" ]] || [[ "$kind" == "22" ]]; then
        kind_filter="--kind $kind"
    else
        # Get both kind 21 and 22 (will run two queries)
        kind_filter="21,22"
    fi
    
    local events=""
    if [[ "$kind_filter" == "21,22" ]]; then
        # Query both kinds
        events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit "$limit" 2>/dev/null)
        events+=$'\n'
        events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit "$limit" 2>/dev/null)
    else
        events=$(bash "$NOSTR_GET_EVENTS" $kind_filter --author "$user_hex" --limit "$limit" 2>/dev/null)
    fi
    
    if [[ -z "$events" ]]; then
        log_warning "No videos found for this user"
        return 0
    fi
    
    # Parse and display events
    local count=0
    local missing_gifanim=0
    local missing_thumbnail=0
    local missing_info=0
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                          ${YELLOW}NostrTube Videos${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        count=$((count + 1))
        
        local kind=$(echo "$event" | jq -r '.kind // 0')
        local created_at=$(echo "$event" | jq -r '.created_at // 0')
        local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
        
        # Extract metadata from tags
        local title=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "title") | .[1] // empty' 2>/dev/null | head -n1)
        local url=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "url") | .[1] // empty' 2>/dev/null | head -n1)
        local duration=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "duration") | .[1] // "0"' 2>/dev/null | head -n1)
        local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local thumbnail=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local info=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "info") | .[1] // empty' 2>/dev/null | head -n1)
        
        # Extract source type from tag "i" with prefix "source:"
        local source_tag=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "i" and (.[1] | startswith("source:"))) | .[1]' 2>/dev/null | head -n1)
        local source_type=""
        local source_icon=""
        if [[ -n "$source_tag" ]]; then
            source_type=${source_tag#source:}
            case "$source_type" in
                webcam) source_icon="🎥" ;;
                film) source_icon="🎬" ;;
                serie) source_icon="📺" ;;
                video) source_icon="📹" ;;
                youtube) source_icon="▶️" ;;
                *) source_icon="📄" ;;
            esac
        fi
        
        # Extract CID from URL
        local cid=$(echo "$url" | grep -oP '(?<=ipfs/)[^/]+' | head -n1)
        
        [[ -z "$title" ]] && title="(no title)"
        [[ -z "$cid" ]] && cid="N/A"
        
        # Check completeness
        local status_icons=""
        [[ -z "$gifanim" ]] && { status_icons+="❌GIF "; missing_gifanim=$((missing_gifanim + 1)); } || status_icons+="✅GIF "
        [[ -z "$thumbnail" ]] && { status_icons+="❌THUMB "; missing_thumbnail=$((missing_thumbnail + 1)); } || status_icons+="✅THUMB "
        [[ -z "$info" ]] && { status_icons+="❌INFO"; missing_info=$((missing_info + 1)); } || status_icons+="✅INFO"
        
        echo -e "${YELLOW}Video #$count${NC} (kind $kind)"
        echo -e "  📅 Date: $date"
        echo -e "  🆔 Event: ${event_id:0:16}..."
        echo -e "  📹 Title: $title"
        [[ -n "$source_type" ]] && echo -e "  ${source_icon} Source: ${source_type}"
        echo -e "  💿 CID: ${cid:0:16}..."
        echo -e "  ⏱️  Duration: ${duration}s"
        echo -e "  📊 Status: $status_icons"
        
        if [[ "$VERBOSE" == "true" ]]; then
            [[ -n "$gifanim" ]] && echo -e "  🎬 GIF: ${gifanim:0:16}..."
            [[ -n "$thumbnail" ]] && echo -e "  🖼️  Thumbnail: ${thumbnail:0:16}..."
            [[ -n "$info" ]] && echo -e "  📋 Info: ${info:0:16}..."
        fi
        
        echo ""
        
    done <<< "$events"
    
    # Summary
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Total videos: $count${NC}"
    
    if [[ $missing_gifanim -gt 0 ]] || [[ $missing_thumbnail -gt 0 ]] || [[ $missing_info -gt 0 ]]; then
        echo -e "${YELLOW}Incomplete metadata:${NC}"
        [[ $missing_gifanim -gt 0 ]] && echo -e "  ❌ Missing animated GIF: $missing_gifanim videos"
        [[ $missing_thumbnail -gt 0 ]] && echo -e "  ❌ Missing thumbnail: $missing_thumbnail videos"
        [[ $missing_info -gt 0 ]] && echo -e "  ❌ Missing info.json: $missing_info videos"
        echo ""
        echo -e "${CYAN}💡 Tip:${NC} Run 'upgrade-all' to fix missing metadata"
    else
        echo -e "${GREEN}✅ All videos have complete metadata${NC}"
    fi
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: check
################################################################################
cmd_check() {
    local user_hex="$1"
    
    log_info "Checking metadata completeness for user: ${user_hex:0:16}..."
    
    # Reuse list command with parsing
    cmd_list "$user_hex"
}

################################################################################
# Command: stats
################################################################################
cmd_stats() {
    local user_hex="$1"
    local limit="${LIMIT:-1000}"
    
    log_info "Generating statistics for user: ${user_hex:0:16}..."
    
    # Get all videos
    local events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit "$limit" 2>/dev/null)
    events+=$'\n'
    events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit "$limit" 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No videos found"
        return 0
    fi
    
    # Statistics
    local total=0
    local kind21=0
    local kind22=0
    local with_gif=0
    local with_thumb=0
    local with_info=0
    local total_duration=0
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        total=$((total + 1))
        
        local kind=$(echo "$event" | jq -r '.kind // 0')
        [[ "$kind" == "21" ]] && kind21=$((kind21 + 1))
        [[ "$kind" == "22" ]] && kind22=$((kind22 + 1))
        
        local duration=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "duration") | .[1] // "0"' 2>/dev/null | head -n1)
        total_duration=$((total_duration + duration))
        
        local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local thumbnail=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local info=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "info") | .[1] // empty' 2>/dev/null | head -n1)
        
        [[ -n "$gifanim" ]] && with_gif=$((with_gif + 1))
        [[ -n "$thumbnail" ]] && with_thumb=$((with_thumb + 1))
        [[ -n "$info" ]] && with_info=$((with_info + 1))
        
    done <<< "$events"
    
    # Convert duration to human readable
    local hours=$((total_duration / 3600))
    local minutes=$(((total_duration % 3600) / 60))
    local seconds=$((total_duration % 60))
    
    # Display stats
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                          ${YELLOW}NostrTube Statistics${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📊 Video Count${NC}"
    echo -e "  Total videos: $total"
    echo -e "  Regular videos (kind 21): $kind21"
    echo -e "  Short videos (kind 22): $kind22"
    echo ""
    echo -e "${YELLOW}⏱️  Total Duration${NC}"
    echo -e "  ${hours}h ${minutes}m ${seconds}s ($total_duration seconds)"
    echo ""
    echo -e "${YELLOW}📋 Metadata Completeness${NC}"
    echo -e "  Animated GIF: $with_gif/$total ($(( (with_gif * 100) / total ))%)"
    echo -e "  Thumbnail: $with_thumb/$total ($(( (with_thumb * 100) / total ))%)"
    echo -e "  Info.json: $with_info/$total ($(( (with_info * 100) / total ))%)"
    echo ""
    
    # Recommendations
    local missing_any=$((total - with_gif))
    if [[ $missing_any -gt 0 ]]; then
        echo -e "${YELLOW}💡 Recommendations${NC}"
        echo -e "  $missing_any videos are missing metadata"
        echo -e "  Run: ${CYAN}nostr_tube_manager.sh upgrade-all --hex $user_hex${NC}"
    else
        echo -e "${GREEN}✅ All videos have complete metadata!${NC}"
    fi
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: upgrade (single video)
################################################################################
cmd_upgrade() {
    local event_id="$1"
    local user_hex="$2"
    
    log_info "Upgrading video: ${event_id:0:16}..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Get event
    local event=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit 1000 2>/dev/null | jq -r "select(.id == \"$event_id\")")
    
    if [[ -z "$event" ]] && [[ -z "$event" ]]; then
        event=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit 1000 2>/dev/null | jq -r "select(.id == \"$event_id\")")
    fi
    
    if [[ -z "$event" ]]; then
        log_error "Event not found: $event_id"
        return 1
    fi
    
    # Extract metadata from original event using jq
    local title=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "title") | .[1] // "Untitled"' 2>/dev/null | head -n1)
    local description=$(echo "$event" | jq -r '.content // ""' 2>/dev/null)
    local url=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "url") | .[1] // empty' 2>/dev/null | head -n1)
    local old_duration=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "duration") | .[1] // "0"' 2>/dev/null | head -n1)
    local latitude=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "latitude") | .[1] // "0.00"' 2>/dev/null | head -n1)
    local longitude=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "longitude") | .[1] // "0.00"' 2>/dev/null | head -n1)
    
    # Extract CID and filename from URL using sed (no lookbehind issues)
    # URL format: /ipfs/CID/filename or http://domain/ipfs/CID/filename
    local cid=$(echo "$url" | sed -n 's|.*/ipfs/\([^/]*\).*|\1|p')
    local filename=$(echo "$url" | sed -n 's|.*/ipfs/[^/]*/\(.*\)|\1|p' | sed 's/%20/ /g; s/%28/(/g; s/%29/)/g; s/%2C/,/g')
    
    if [[ -z "$cid" ]]; then
        log_error "Could not extract CID from URL: $url"
        return 1
    fi
    
    # If filename extraction failed, try to get it from the last part of URL
    if [[ -z "$filename" ]]; then
        filename=$(basename "$url" | sed 's/%20/ /g; s/%28/(/g; s/%29/)/g; s/%2C/,/g')
    fi
    
    # Final fallback
    [[ -z "$filename" ]] && filename="video_${event_id:0:8}.mp4"
    
    log_info "Title: $title"
    log_info "CID: $cid"
    log_info "Filename: $filename"
    
    # Download video from IPFS
    log_info "Downloading video from IPFS..."
    local video_path="$TEMP_DIR/$filename"
    
    if ! ipfs get "$cid/$filename" -o "$video_path" 2>/dev/null; then
        log_error "Failed to download video from IPFS"
        return 1
    fi
    
    log_success "Video downloaded: $video_path"
    
    # Re-upload via upload2ipfs.sh
    log_info "Re-uploading via upload2ipfs.sh to generate fresh metadata..."
    local upload_output="$TEMP_DIR/upload_output.json"
    
    if ! bash "$UPLOAD2IPFS" "$video_path" "$upload_output" "$user_hex" 2>&1 | grep -q "Upload successful"; then
        log_error "Failed to re-upload video"
        return 1
    fi
    
    # Read upload result
    if [[ ! -f "$upload_output" ]]; then
        log_error "Upload output file not found"
        return 1
    fi
    
    local new_cid=$(jq -r '.cid // empty' "$upload_output")
    local gifanim_cid=$(jq -r '.gifanim_ipfs // empty' "$upload_output")
    local thumbnail_cid=$(jq -r '.thumbnail_ipfs // empty' "$upload_output")
    local info_cid=$(jq -r '.info // empty' "$upload_output")
    local file_hash=$(jq -r '.fileHash // empty' "$upload_output")
    local mime_type=$(jq -r '.mimeType // "video/webm"' "$upload_output")
    local upload_chain=$(jq -r '.upload_chain // empty' "$upload_output")
    local duration=$(jq -r '.duration // "0"' "$upload_output")
    local dimensions=$(jq -r '.dimensions // "640x480"' "$upload_output")
    
    log_success "Re-upload complete!"
    log_info "New CID: $new_cid"
    [[ -n "$gifanim_cid" ]] && log_success "✅ Animated GIF: $gifanim_cid"
    [[ -n "$thumbnail_cid" ]] && log_success "✅ Thumbnail: $thumbnail_cid"
    [[ -n "$info_cid" ]] && log_success "✅ Info.json: $info_cid"
    
    # Confirmation
    if [[ "$FORCE" != "true" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  This will:${NC}"
        echo "  1. Delete old NOSTR event: ${event_id:0:16}..."
        echo "  2. Publish new event with fresh metadata"
        echo ""
        read -p "Continue? (yes/NO): " confirm
        
        if [[ "$confirm" != "yes" ]]; then
            log_warning "Upgrade cancelled by user"
            rm -rf "$TEMP_DIR"
            return 0
        fi
    fi
    
    # Delete old event by publishing kind 5 deletion event
    log_info "Deleting old NOSTR event: ${event_id:0:16}..."
    if delete_event_by_id "$event_id" "$user_hex" "true"; then
        log_success "Old event deleted successfully (kind 5 published)"
    else
        log_error "Failed to delete old event, aborting upgrade"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Find user's .secret.nostr file by querying DID document
    log_info "Looking for user's NOSTR keys..."
    local secret_file=""
    
    # Query DID document for this pubkey (kind 30800)
    log_info "Querying DID document for pubkey: ${user_hex:0:16}..."
    local did_event=$(bash "$NOSTR_GET_EVENTS" --kind 30800 --author "$user_hex" --limit 1 2>/dev/null)
    
    if [[ -n "$did_event" ]] && [[ "$did_event" != "[]" ]]; then
        # Try to extract email from event tags first (simpler and more reliable)
        local email=$(echo "$did_event" | jq -r 'if type == "array" then .[0].tags[]? else .tags[]? end | select(.[0] == "email") | .[1]' 2>/dev/null | head -n1)
        
        # If not found in tags, try from content.metadata.email
        if [[ -z "$email" ]]; then
            email=$(echo "$did_event" | jq -r 'if type == "array" then .[0].content else .content end | fromjson | .metadata.email // empty' 2>/dev/null)
        fi
        
        # If still not found, try from content.alsoKnownAs
        if [[ -z "$email" ]]; then
            email=$(echo "$did_event" | jq -r 'if type == "array" then .[0].content else .content end | fromjson | .alsoKnownAs[]? | select(startswith("mailto:")) | sub("^mailto:"; "")' 2>/dev/null | head -n1)
        fi
        
        if [[ -n "$email" ]]; then
            log_info "Found email from DID: $email"
            # Construct path to .secret.nostr file
            secret_file="${HOME}/.zen/game/nostr/${email}/.secret.nostr"
            
            if [[ ! -f "$secret_file" ]]; then
                log_error "Secret file not found at expected path: $secret_file"
                log_warning "⚠️  New event NOT published - manual intervention required"
                log_info "To complete the upgrade, please re-publish this video via /webcam"
                log_info "Use the following metadata:"
                echo "  - CID: $new_cid"
                echo "  - Filename: $filename"
                echo "  - Title: $title"
                [[ -n "$gifanim_cid" ]] && echo "  - Animated GIF: $gifanim_cid"
                [[ -n "$thumbnail_cid" ]] && echo "  - Thumbnail: $thumbnail_cid"
                [[ -n "$info_cid" ]] && echo "  - Info: $info_cid"
                rm -rf "$TEMP_DIR"
                return 1
            fi
        else
            log_error "Could not extract email from DID document"
            log_warning "⚠️  New event NOT published - manual intervention required"
            log_info "To complete the upgrade, please re-publish this video via /webcam"
            log_info "Use the following metadata:"
            echo "  - CID: $new_cid"
            echo "  - Filename: $filename"
            echo "  - Title: $title"
            [[ -n "$gifanim_cid" ]] && echo "  - Animated GIF: $gifanim_cid"
            [[ -n "$thumbnail_cid" ]] && echo "  - Thumbnail: $thumbnail_cid"
            [[ -n "$info_cid" ]] && echo "  - Info: $info_cid"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    else
        log_error "No DID document found for user: ${user_hex:0:16}..."
        log_warning "⚠️  New event NOT published - manual intervention required"
        log_info "To complete the upgrade, please re-publish this video via /webcam"
        log_info "Use the following metadata:"
        echo "  - CID: $new_cid"
        echo "  - Filename: $filename"
        echo "  - Title: $title"
        [[ -n "$gifanim_cid" ]] && echo "  - Animated GIF: $gifanim_cid"
        [[ -n "$thumbnail_cid" ]] && echo "  - Thumbnail: $thumbnail_cid"
        [[ -n "$info_cid" ]] && echo "  - Info: $info_cid"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    log_success "Found secret file: $secret_file"
    
    # Extract channel name from secret file directory (should be email)
    local channel_name=$(basename "$(dirname "$secret_file")")
    log_info "Channel: $channel_name"
    
    # Publish new event using unified script
    log_info "Publishing new NOSTR event with fresh metadata..."
    
    local publish_result=""
    publish_result=$(bash "$PUBLISH_NOSTR_VIDEO" \
        --nsec "$secret_file" \
        --ipfs-cid "$new_cid" \
        --filename "$filename" \
        --title "$title" \
        --description "$description" \
        --thumbnail-cid "$thumbnail_cid" \
        --gifanim-cid "$gifanim_cid" \
        --info-cid "$info_cid" \
        --file-hash "$file_hash" \
        --mime-type "$mime_type" \
        --upload-chain "$upload_chain" \
        --duration "$duration" \
        --dimensions "$dimensions" \
        --latitude "$latitude" \
        --longitude "$longitude" \
        --channel "$channel_name" \
        --json 2>&1)
    
    local publish_exit_code=$?
    
    if [[ $publish_exit_code -eq 0 ]]; then
        # Parse JSON output
        local new_event_id=$(echo "$publish_result" | jq -r '.event_id // empty' 2>/dev/null)
        local relays_success=$(echo "$publish_result" | jq -r '.relays_success // 0' 2>/dev/null)
        
        if [[ -n "$new_event_id" ]]; then
            log_success "✅ New NOSTR event published successfully!"
            log_success "   Event ID: ${new_event_id:0:16}..."
            log_success "   Published to $relays_success relay(s)"
            log_success "   Upload chain: ${upload_chain:0:50}..."
            echo ""
            log_success "🎉 Upgrade complete! Video successfully upgraded with fresh metadata."
        else
            log_error "Event published but could not extract event ID"
            log_warning "Output: $publish_result"
        fi
    else
        log_error "Failed to publish new NOSTR event"
        log_error "Exit code: $publish_exit_code"
        log_error "Output: $publish_result"
        log_warning "Old event was deleted but new event publication failed"
        log_info "Manual intervention required - please re-publish via /webcam"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

################################################################################
# Command: browse (interactive video browser)
################################################################################
cmd_browse() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                       ${YELLOW}NostrTube Channel Browser${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get all videos and build channel list
    log_info "Loading channels from relay..."
    
    local events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --limit 1000 2>/dev/null)
    events+=$'\n'
    events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --limit 1000 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No videos found on relay"
        read -p "Press ENTER to exit..."
        return 0
    fi
    
    # Build channel map: channel_name -> array of event IDs
    declare -A channel_videos
    declare -A channel_authors
    local channels=()
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        local author=$(echo "$event" | jq -r '.pubkey // "unknown"')
        
        # Extract channel from tags
        local channel=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "t" and (.[1] | startswith("Channel-"))) | .[1]' 2>/dev/null | head -n1)
        if [[ -n "$channel" ]]; then
            channel=${channel#Channel-}
        else
            channel="unknown"
        fi
        
        # Add to channel map
        if [[ -z "${channel_videos[$channel]}" ]]; then
            channels+=("$channel")
            channel_videos["$channel"]="$event_id"
            channel_authors["$channel"]="$author"
        else
            channel_videos["$channel"]+=" $event_id"
        fi
    done <<< "$events"
    
    # Sort channels
    IFS=$'\n' channels=($(sort <<<"${channels[*]}"))
    unset IFS
    
    # Channel selection menu
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                       ${YELLOW}Select a Channel${NC}                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        local idx=1
        for channel in "${channels[@]}"; do
            local video_count=$(echo "${channel_videos[$channel]}" | wc -w)
            local author_hex="${channel_authors[$channel]}"
            
            # Check if this channel's pubkey exists locally (has HEX file with matching pubkey)
            local status_indicator=""
            if check_local_pubkey "$author_hex"; then
                status_indicator="${GREEN}[LOCAL]${NC}"
            else
                status_indicator="${YELLOW}[REMOTE]${NC}"
            fi
            
            echo -e "  ${YELLOW}$idx.${NC} 📺 $channel (${GREEN}$video_count${NC} videos) $status_indicator"
            idx=$((idx + 1))
        done
        
        echo ""
        echo -e "  ${YELLOW}0.${NC} 🚪 Exit"
        echo ""
        
        read -p "$(echo -e ${CYAN}Select channel [0-${#channels[@]}]:${NC} )" choice
        
        if [[ "$choice" == "0" ]]; then
            clear
            return 0
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -gt 0 ]] && [[ $choice -le ${#channels[@]} ]]; then
            local selected_channel="${channels[$((choice - 1))]}"
            local selected_author="${channel_authors[$selected_channel]}"
            browse_channel_videos "$selected_channel" "$selected_author"
        else
            log_error "Invalid choice"
            sleep 1
        fi
    done
}

# Browse videos in a specific channel
browse_channel_videos() {
    local channel_name="$1"
    local author_hex="$2"
    
    local current_page=0
    local videos_per_page=5
    local needs_reload=true
    
    # Declare arrays at function scope
    local -a video_ids=()
    local -A video_data=()
    
    # Function to load/reload video list
    load_video_list() {
        # Get all videos for this author
        local events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$author_hex" --limit 1000 2>/dev/null)
        events+=$'\n'
        events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$author_hex" --limit 1000 2>/dev/null)
        
        if [[ -z "$events" ]]; then
            return 1
        fi
        
        # Clear and rebuild arrays
        video_ids=()
        video_data=()
        
        while IFS= read -r event; do
            [[ -z "$event" ]] && continue
            
            local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
            [[ -z "$event_id" ]] && continue
            
            video_ids+=("$event_id")
            video_data["$event_id"]="$event"
        done <<< "$events"
        
        return 0
    }
    
    # Video navigation menu
    while true; do
        # Reload video list if needed (first time or after deletion)
        if [[ "$needs_reload" == "true" ]]; then
            if ! load_video_list; then
                log_warning "No videos found for this channel"
                read -p "Press ENTER to continue..."
                return 0
            fi
            needs_reload=false
            # Reset to first page if we're beyond available pages
            local total_videos=${#video_ids[@]}
            local total_pages=$(( (total_videos + videos_per_page - 1) / videos_per_page ))
            if [[ $current_page -ge $total_pages ]] && [[ $total_pages -gt 0 ]]; then
                current_page=$((total_pages - 1))
            fi
        fi
        
        local total_videos=${#video_ids[@]}
        local total_pages=$(( (total_videos + videos_per_page - 1) / videos_per_page ))
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                 ${YELLOW}Channel: $channel_name${NC}                                      ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Page $((current_page + 1))/$total_pages${NC} - ${GREEN}$total_videos videos${NC} total"
        echo ""
        
        # Display videos for current page
        local start_idx=$((current_page * videos_per_page))
        local end_idx=$((start_idx + videos_per_page))
        [[ $end_idx -gt $total_videos ]] && end_idx=$total_videos
        
        local display_idx=1
        for ((i=start_idx; i<end_idx; i++)); do
            local event_id="${video_ids[$i]}"
            local event="${video_data[$event_id]}"
            
            local title=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "title") | .[1] // "Untitled"' 2>/dev/null | head -n1)
            local duration=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "duration") | .[1] // "0"' 2>/dev/null | head -n1)
            local kind=$(echo "$event" | jq -r '.kind // 0')
            local created_at=$(echo "$event" | jq -r '.created_at // 0')
            local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
            
            # Extract source type from tag "i" with prefix "source:"
            local source_tag=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "i" and (.[1] | startswith("source:"))) | .[1]' 2>/dev/null | head -n1)
            local source_type=""
            local source_icon=""
            if [[ -n "$source_tag" ]]; then
                source_type=${source_tag#source:}
                case "$source_type" in
                    webcam) source_icon="🎥" ;;
                    film) source_icon="🎬" ;;
                    serie) source_icon="📺" ;;
                    video) source_icon="📹" ;;
                    youtube) source_icon="▶️" ;;
                    *) source_icon="📄" ;;
                esac
            fi
            
            # Check metadata completeness
            local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
            local thumbnail=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
            local info=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "info") | .[1] // empty' 2>/dev/null | head -n1)
            
            local status=""
            [[ -n "$gifanim" ]] && status+="✅" || status+="❌"
            [[ -n "$thumbnail" ]] && status+="✅" || status+="❌"
            [[ -n "$info" ]] && status+="✅" || status+="❌"
            
            echo -e "  ${YELLOW}$display_idx.${NC} 📹 $title"
            local source_display=""
            [[ -n "$source_type" ]] && source_display=" | ${source_icon} $source_type"
            echo -e "      ⏱️  ${duration}s | 📅 $date | Kind $kind$source_display | Status: $status"
            echo ""
            
            display_idx=$((display_idx + 1))
        done
        
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${YELLOW}1-$videos_per_page.${NC} 🔍 View video details"
        [[ $current_page -gt 0 ]] && echo -e "  ${YELLOW}p.${NC} ⬅️  Previous page"
        [[ $current_page -lt $((total_pages - 1)) ]] && echo -e "  ${YELLOW}n.${NC} ➡️  Next page"
        echo -e "  ${YELLOW}b.${NC} 🔙 Back to channels"
        echo -e "  ${YELLOW}0.${NC} 🚪 Exit"
        echo ""
        
        read -p "$(echo -e ${CYAN}Choose action:${NC} )" action
        
        case "$action" in
            p)
                if [[ $current_page -gt 0 ]]; then
                    current_page=$((current_page - 1))
                fi
                ;;
            n)
                if [[ $current_page -lt $((total_pages - 1)) ]]; then
                    current_page=$((current_page + 1))
                fi
                ;;
            b)
                return 0
                ;;
            0)
                clear
                exit 0
                ;;
            [1-5])
                local video_idx=$((start_idx + action - 1))
                if [[ $video_idx -ge $start_idx ]] && [[ $video_idx -lt $end_idx ]]; then
                    local selected_event_id="${video_ids[$video_idx]}"
                    local selected_event="${video_data[$selected_event_id]}"
                    # Show video details - if it returns 0, video was deleted, reload list
                    if show_video_details "$selected_event_id" "$selected_event" "$author_hex"; then
                        # Video was deleted, reload the list
                        needs_reload=true
                        log_info "Reloading video list after deletion..."
                    fi
                else
                    log_error "Invalid video number"
                    sleep 1
                fi
                ;;
            *)
                log_error "Invalid action"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# Export all events related to a video (complete tree)
################################################################################
export_video_tree() {
    local video_event_id="$1"
    local author_hex="$2"
    
    log_info "Exporting all events related to video: ${video_event_id:0:16}..."
    
    # Create export directory
    local export_dir="${HOME}/.zen/tmp/video_export_${video_event_id:0:8}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    
    local export_file="${export_dir}/video_tree_${video_event_id:0:16}.json"
    local export_summary="${export_dir}/summary.txt"
    
    # Initialize export JSON array
    local all_events="[]"
    
    local total_events=0
    local event_kinds=()
    
    # 1. Main video event (kind 21 or 22) - use nostr_get_event_by_id.sh
    log_info "Fetching main video event (kind 21/22)..."
    local video_event=""
    if [[ -f "$NOSTR_GET_EVENT_BY_ID" ]]; then
        video_event=$(bash "$NOSTR_GET_EVENT_BY_ID" "$video_event_id" 2>/dev/null)
    else
        # Fallback: try to get by author and filter
        log_debug "nostr_get_event_by_id.sh not found, trying alternative method..."
        local author_events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$author_hex" --limit 1000 2>/dev/null)
        video_event=$(echo "$author_events" | jq -r "if type == \"array\" then .[] | select(.id == \"$video_event_id\") else if .id == \"$video_event_id\" then . else empty end end" 2>/dev/null)
        if [[ -z "$video_event" ]] || [[ "$video_event" == "null" ]]; then
            author_events=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$author_hex" --limit 1000 2>/dev/null)
            video_event=$(echo "$author_events" | jq -r "if type == \"array\" then .[] | select(.id == \"$video_event_id\") else if .id == \"$video_event_id\" then . else empty end end" 2>/dev/null)
        fi
    fi
    
    # Parse output from nostr_get_event_by_id.sh (strfry scan returns JSON on single line)
    if [[ -n "$video_event" ]] && [[ "$video_event" != "" ]]; then
        # strfry scan returns one JSON object per line, get first non-empty line
        local event_line=$(echo "$video_event" | grep -v '^$' | head -1)
        if [[ -n "$event_line" ]]; then
            # Verify it's valid JSON and extract event
            if echo "$event_line" | jq -e '.' >/dev/null 2>&1; then
                local event_id_check=$(echo "$event_line" | jq -r '.id // empty' 2>/dev/null)
                if [[ "$event_id_check" == "$video_event_id" ]]; then
                    local video_kind=$(echo "$event_line" | jq -r '.kind // empty' 2>/dev/null)
                    # Add to export using proper jq merge
                    all_events=$(echo "$all_events" | jq --argjson evt "$event_line" '. + [$evt]' 2>/dev/null || echo "$all_events")
                    total_events=$((total_events + 1))
                    event_kinds+=("kind $video_kind (main video)")
                    log_success "✅ Found main video event (kind $video_kind)"
                else
                    log_warning "⚠️  Event ID mismatch: expected $video_event_id, got ${event_id_check:0:16}..."
                fi
            else
                log_warning "⚠️  Main video event not found (invalid JSON)"
                log_debug "Raw output: ${video_event:0:200}..."
            fi
        else
            log_warning "⚠️  Main video event not found (empty output)"
        fi
    else
        log_warning "⚠️  Main video event not found (no output from query)"
    fi
    
    # 2. User tags (kind 1985) - NIP-32
    log_info "Fetching user tags (kind 1985)..."
    local tag_events=$(bash "$NOSTR_GET_EVENTS" --kind 1985 --tag e "$video_event_id" --limit 1000 2>/dev/null)
    local tag_count=0
    if [[ -n "$tag_events" ]] && [[ "$tag_events" != "[]" ]]; then
        tag_count=$(echo "$tag_events" | jq 'if type == "array" then length else 1 end' 2>/dev/null || echo "0")
        all_events=$(echo "$all_events" | jq --argjson evts "$(echo "$tag_events" | jq 'if type == "array" then . else [.] end' 2>/dev/null)" '. + $evts' 2>/dev/null || echo "$all_events")
        total_events=$((total_events + tag_count))
    fi
    event_kinds+=("kind 1985 (user tags): $tag_count event(s)")
    if [[ $tag_count -gt 0 ]]; then
        log_success "✅ Found $tag_count user tag event(s)"
    else
        log_info "ℹ️  No user tags found (0 events)"
    fi
    
    # 3. TMDB enrichments (kind 1986) - Community enrichments
    log_info "Fetching TMDB enrichments (kind 1986)..."
    local enrichment_events=$(bash "$NOSTR_GET_EVENTS" --kind 1986 --tag e "$video_event_id" --tag L "tmdb.metadata" --limit 1000 2>/dev/null)
    local enrichment_count=0
    if [[ -n "$enrichment_events" ]] && [[ "$enrichment_events" != "[]" ]]; then
        enrichment_count=$(echo "$enrichment_events" | jq 'if type == "array" then length else 1 end' 2>/dev/null || echo "0")
        all_events=$(echo "$all_events" | jq --argjson evts "$(echo "$enrichment_events" | jq 'if type == "array" then . else [.] end' 2>/dev/null)" '. + $evts' 2>/dev/null || echo "$all_events")
        total_events=$((total_events + enrichment_count))
    fi
    event_kinds+=("kind 1986 (TMDB enrichments): $enrichment_count event(s)")
    if [[ $enrichment_count -gt 0 ]]; then
        log_success "✅ Found $enrichment_count TMDB enrichment event(s)"
    else
        log_info "ℹ️  No TMDB enrichments found (0 events)"
    fi
    
    # 4. Author updates (kind 30001) - Replaceable enrichments
    log_info "Fetching author updates (kind 30001)..."
    local author_update_events=$(bash "$NOSTR_GET_EVENTS" --kind 30001 --author "$author_hex" --tag e "$video_event_id" --tag d "tmdb-metadata" --limit 10 2>/dev/null)
    local update_count=0
    if [[ -n "$author_update_events" ]] && [[ "$author_update_events" != "[]" ]]; then
        update_count=$(echo "$author_update_events" | jq 'if type == "array" then length else 1 end' 2>/dev/null || echo "0")
        all_events=$(echo "$all_events" | jq --argjson evts "$(echo "$author_update_events" | jq 'if type == "array" then . else [.] end' 2>/dev/null)" '. + $evts' 2>/dev/null || echo "$all_events")
        total_events=$((total_events + update_count))
    fi
    event_kinds+=("kind 30001 (author updates): $update_count event(s)")
    if [[ $update_count -gt 0 ]]; then
        log_success "✅ Found $update_count author update event(s)"
    else
        log_info "ℹ️  No author updates found (0 events)"
    fi
    
    # 5. Comments (kind 1111) - NIP-22
    log_info "Fetching comments (kind 1111)..."
    local comment_events=$(bash "$NOSTR_GET_EVENTS" --kind 1111 --tag e "$video_event_id" --limit 1000 2>/dev/null)
    local comment_count=0
    if [[ -n "$comment_events" ]] && [[ "$comment_events" != "[]" ]]; then
        comment_count=$(echo "$comment_events" | jq 'if type == "array" then length else 1 end' 2>/dev/null || echo "0")
        all_events=$(echo "$all_events" | jq --argjson evts "$(echo "$comment_events" | jq 'if type == "array" then . else [.] end' 2>/dev/null)" '. + $evts' 2>/dev/null || echo "$all_events")
        total_events=$((total_events + comment_count))
    fi
    event_kinds+=("kind 1111 (comments): $comment_count event(s)")
    if [[ $comment_count -gt 0 ]]; then
        log_success "✅ Found $comment_count comment event(s)"
    else
        log_info "ℹ️  No comments found (0 events)"
    fi
    
    # 6. Deletion events (kind 5) - If video was already deleted
    log_info "Fetching deletion events (kind 5)..."
    local deletion_events=$(bash "$NOSTR_GET_EVENTS" --kind 5 --tag e "$video_event_id" --limit 100 2>/dev/null)
    local deletion_count=0
    if [[ -n "$deletion_events" ]] && [[ "$deletion_events" != "[]" ]]; then
        deletion_count=$(echo "$deletion_events" | jq 'if type == "array" then length else 1 end' 2>/dev/null || echo "0")
        all_events=$(echo "$all_events" | jq --argjson evts "$(echo "$deletion_events" | jq 'if type == "array" then . else [.] end' 2>/dev/null)" '. + $evts' 2>/dev/null || echo "$all_events")
        total_events=$((total_events + deletion_count))
    fi
    event_kinds+=("kind 5 (deletions): $deletion_count event(s)")
    if [[ $deletion_count -gt 0 ]]; then
        log_success "✅ Found $deletion_count deletion event(s)"
    else
        log_info "ℹ️  No deletion events found (0 events)"
    fi
    
    # Write all events to file
    echo "$all_events" | jq '.' > "$export_file" 2>/dev/null || echo "[]" > "$export_file"
    
    # Create summary file
    {
        echo "Video Event Tree Export"
        echo "========================"
        echo ""
        echo "Video Event ID: $video_event_id"
        echo "Author: ${author_hex:0:16}..."
        echo "Export Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Total Events: $total_events"
        echo ""
        echo "Event Types:"
        for kind_info in "${event_kinds[@]}"; do
            echo "  - $kind_info"
        done
        echo ""
        echo "Export File: $export_file"
        echo ""
        echo "This export contains all NOSTR events related to this video:"
        echo "  - Main video event (kind 21/22)"
        echo "  - User tags (kind 1985)"
        echo "  - TMDB enrichments (kind 1986)"
        echo "  - Author updates (kind 30001)"
        echo "  - Comments (kind 1111)"
        echo "  - Deletion events (kind 5)"
    } > "$export_summary"
    
    # Display summary
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}Video Tree Export Complete${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✅ Export directory:${NC} $export_dir"
    echo -e "${GREEN}✅ Total events exported:${NC} $total_events"
    echo ""
    echo -e "${YELLOW}Event breakdown:${NC}"
    for kind_info in "${event_kinds[@]}"; do
        echo -e "  • $kind_info"
    done
    echo ""
    echo -e "${CYAN}Files created:${NC}"
    echo -e "  📄 $export_file (JSON array of all events)"
    echo -e "  📋 $export_summary (Summary text)"
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    
    # Return export directory path (to stdout, not stderr)
    echo "$export_dir" >&1
    
    return 0
}

################################################################################
# Delete complete video tree (all related events)
################################################################################
delete_video_tree() {
    local video_event_id="$1"
    local author_hex="$2"
    local force="${3:-false}"
    
    log_warning "⚠️  COMPLETE VIDEO TREE DELETION"
    echo ""
    echo -e "${RED}This will permanently delete:${NC}"
    echo "  • Main video event (kind 21/22)"
    echo "  • All user tags (kind 1985)"
    echo "  • All TMDB enrichments (kind 1986)"
    echo "  • All author updates (kind 30001)"
    echo "  • All comments (kind 1111)"
    echo ""
    echo -e "${RED}⚠️  This operation CANNOT be undone!${NC}"
    echo ""
    
    if [[ "$force" != "true" ]]; then
        read -p "$(echo -e ${RED}Type 'DELETE TREE' to confirm:${NC} )" confirm
        if [[ "$confirm" != "DELETE TREE" ]]; then
            log_warning "Deletion cancelled"
            return 1
        fi
    fi
    
    # First, export the tree (backup before deletion)
    log_info "Creating backup export before deletion..."
    local export_dir=""
    # Capture export_dir from stdout (last line), redirect all log messages to stderr
    # export_video_tree outputs the export_dir path as the last line on stdout
    export_dir=$(export_video_tree "$video_event_id" "$author_hex" 2>&1 | grep -E "^/.*video_export" | tail -1)
    if [[ -z "$export_dir" ]] || [[ ! -d "$export_dir" ]]; then
        # Try alternative: get from function output directly
        export_dir=$(export_video_tree "$video_event_id" "$author_hex" 2>&1 | tail -1)
        if [[ -z "$export_dir" ]] || [[ ! -d "$export_dir" ]]; then
            log_warning "Export failed, but continuing with deletion..."
            export_dir=""
        else
            log_info "Export directory: $export_dir"
        fi
    else
        log_info "Export directory: $export_dir"
    fi
    
    # Collect all event IDs to delete (use process substitution to avoid subshell issues)
    local -a event_ids_to_delete=()
    
    # 1. Main video event - use nostr_get_event_by_id.sh
    log_debug "Fetching main video event for deletion..."
    local video_event=""
    if [[ -f "$NOSTR_GET_EVENT_BY_ID" ]]; then
        video_event=$(bash "$NOSTR_GET_EVENT_BY_ID" "$video_event_id" 2>/dev/null)
    else
        # Fallback: try to get by author and filter
        log_debug "nostr_get_event_by_id.sh not found, trying alternative method..."
        local author_events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$author_hex" --limit 1000 2>/dev/null)
        video_event=$(echo "$author_events" | jq -r "if type == \"array\" then .[] | select(.id == \"$video_event_id\") else if .id == \"$video_event_id\" then . else empty end end" 2>/dev/null)
        if [[ -z "$video_event" ]] || [[ "$video_event" == "null" ]]; then
            author_events=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$author_hex" --limit 1000 2>/dev/null)
            video_event=$(echo "$author_events" | jq -r "if type == \"array\" then .[] | select(.id == \"$video_event_id\") else if .id == \"$video_event_id\" then . else empty end end" 2>/dev/null)
        fi
    fi
    
    # Parse output from nostr_get_event_by_id.sh (strfry scan returns JSON on single line)
    if [[ -n "$video_event" ]] && [[ "$video_event" != "" ]]; then
        # strfry scan returns one JSON object per line, get first non-empty line
        local event_line=$(echo "$video_event" | grep -v '^$' | head -1)
        if [[ -n "$event_line" ]]; then
            # Verify it's valid JSON and extract event ID
            if echo "$event_line" | jq -e '.' >/dev/null 2>&1; then
                local main_id=$(echo "$event_line" | jq -r '.id // empty' 2>/dev/null)
                if [[ -n "$main_id" ]] && [[ "$main_id" != "null" ]] && [[ "$main_id" == "$video_event_id" ]]; then
                    event_ids_to_delete+=("$main_id")
                    log_debug "Added main video event to deletion list: ${main_id:0:16}..."
                else
                    log_warning "⚠️  Event ID mismatch or invalid: expected $video_event_id, got ${main_id:0:16}..."
                fi
            else
                log_warning "⚠️  Could not parse event JSON for deletion"
                log_debug "Raw output: ${video_event:0:200}..."
            fi
        else
            log_warning "⚠️  Main video event not found for deletion (empty output)"
        fi
    else
        log_warning "⚠️  Main video event not found for deletion (may already be deleted)"
    fi
    
    # 2. User tags (kind 1985)
    local tag_events=$(bash "$NOSTR_GET_EVENTS" --kind 1985 --tag e "$video_event_id" --limit 1000 2>/dev/null)
    if [[ -n "$tag_events" ]] && [[ "$tag_events" != "[]" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && event_ids_to_delete+=("$id")
        done < <(echo "$tag_events" | jq -r 'if type == "array" then .[].id else .id end' 2>/dev/null)
    fi
    
    # 3. TMDB enrichments (kind 1986)
    local enrichment_events=$(bash "$NOSTR_GET_EVENTS" --kind 1986 --tag e "$video_event_id" --tag L "tmdb.metadata" --limit 1000 2>/dev/null)
    if [[ -n "$enrichment_events" ]] && [[ "$enrichment_events" != "[]" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && event_ids_to_delete+=("$id")
        done < <(echo "$enrichment_events" | jq -r 'if type == "array" then .[].id else .id end' 2>/dev/null)
    fi
    
    # 4. Author updates (kind 30001)
    local author_update_events=$(bash "$NOSTR_GET_EVENTS" --kind 30001 --author "$author_hex" --tag e "$video_event_id" --tag d "tmdb-metadata" --limit 10 2>/dev/null)
    if [[ -n "$author_update_events" ]] && [[ "$author_update_events" != "[]" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && event_ids_to_delete+=("$id")
        done < <(echo "$author_update_events" | jq -r 'if type == "array" then .[].id else .id end' 2>/dev/null)
    fi
    
    # 5. Comments (kind 1111)
    local comment_events=$(bash "$NOSTR_GET_EVENTS" --kind 1111 --tag e "$video_event_id" --limit 1000 2>/dev/null)
    if [[ -n "$comment_events" ]] && [[ "$comment_events" != "[]" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && event_ids_to_delete+=("$id")
        done < <(echo "$comment_events" | jq -r 'if type == "array" then .[].id else .id end' 2>/dev/null)
    fi
    
    local total_to_delete=${#event_ids_to_delete[@]}
    
    if [[ $total_to_delete -eq 0 ]]; then
        log_warning "No events found to delete"
        log_info "Debug: Checking if event still exists using nostr_get_event_by_id.sh..."
        if [[ -f "$NOSTR_GET_EVENT_BY_ID" ]]; then
            local check_event=$(bash "$NOSTR_GET_EVENT_BY_ID" "$video_event_id" 2>/dev/null | grep -v '^$' | head -1)
            if [[ -n "$check_event" ]]; then
                local check_id=$(echo "$check_event" | jq -r '.id // empty' 2>/dev/null)
                if [[ "$check_id" == "$video_event_id" ]]; then
                    log_error "❌ Event still exists but was not added to deletion list!"
                    log_info "Event found: ${check_id:0:16}..."
                    log_info "This is a bug - the event should have been added to deletion list"
                    # Force add it
                    event_ids_to_delete+=("$video_event_id")
                    total_to_delete=1
                    log_warning "⚠️  Forcing deletion of event (workaround)"
                else
                    log_info "Event not found in database (may already be deleted)"
                fi
            else
                log_info "Event not found in database (may already be deleted)"
            fi
        fi
        
        if [[ ${#event_ids_to_delete[@]} -eq 0 ]]; then
            log_warning "No events found to delete - operation cancelled"
            return 0
        fi
    fi
    
    total_to_delete=${#event_ids_to_delete[@]}
    log_info "Found $total_to_delete event(s) to delete"
    echo ""
    
    # Step 1: Publish kind 5 deletion events for all
    log_info "Step 1/2: Publishing kind 5 deletion events..."
    local kind5_success=0
    local kind5_failed=0
    
    for event_id in "${event_ids_to_delete[@]}"; do
        if delete_event_by_id "$event_id" "$author_hex" "true" "kind5"; then
            kind5_success=$((kind5_success + 1))
        else
            kind5_failed=$((kind5_failed + 1))
            log_warning "Failed to publish kind 5 for: ${event_id:0:16}..."
        fi
    done
    
    log_info "Kind 5 deletion: $kind5_success success, $kind5_failed failed"
    
    # Step 2: Physical deletion using nostr_get_events.sh --del --force
    log_info "Step 2/2: Physical deletion from database (nostr_get_events.sh --del --force)..."
    
    local physical_success=0
    local physical_failed=0
    
    # Delete each event using strfry delete directly (more reliable)
    for event_id in "${event_ids_to_delete[@]}"; do
        log_debug "Deleting event: ${event_id:0:16}..."
        
        # Use strfry delete directly with filter (more reliable than nostr_get_events.sh --del)
        local STRFRY_DIR="$HOME/.zen/strfry"
        local STRFRY_BIN="${STRFRY_DIR}/strfry"
        
        if [[ -f "${STRFRY_BIN}" ]]; then
            cd "$STRFRY_DIR" || continue
            # Create filter JSON with proper format for strfry delete
            # strfry expects: {"ids":["event_id1","event_id2"]}
            local IDS_JSON=$(echo "$event_id" | jq -R . | jq -s -c '{ids: .}')
            
            # Verify JSON is valid before passing to strfry
            if echo "$IDS_JSON" | jq -e '.' >/dev/null 2>&1; then
                log_debug "Deleting event ${event_id:0:16}... with filter: $IDS_JSON"
                # Capture strfry output to check if deletion was successful
                local strfry_output=$(./strfry delete --filter="$IDS_JSON" 2>&1)
                local strfry_exit=$?
                
                # Check if strfry reported deleting events (look for "Deleting N events" where N > 0)
                local deleted_count=$(echo "$strfry_output" | grep -oP 'Deleting \K\d+' || echo "0")
                
                if [[ $strfry_exit -eq 0 ]] && [[ "$deleted_count" -gt 0 ]]; then
                    physical_success=$((physical_success + 1))
                    log_debug "✅ Physically deleted: ${event_id:0:16}... (strfry reported: $deleted_count event(s))"
                elif [[ $strfry_exit -eq 0 ]] && [[ "$deleted_count" == "0" ]]; then
                    # Event may have already been deleted by kind 5, or doesn't exist
                    log_debug "⚠️  strfry reported 0 events deleted for ${event_id:0:16}... (may already be deleted)"
                    # Still count as success if exit code is 0 (event doesn't exist = success)
                    physical_success=$((physical_success + 1))
                else
                    physical_failed=$((physical_failed + 1))
                    log_warning "Failed to physically delete: ${event_id:0:16}... (exit code: $strfry_exit)"
                    log_debug "strfry output: ${strfry_output:0:200}..."
                fi
            else
                physical_failed=$((physical_failed + 1))
                log_warning "Invalid JSON filter for deletion: $IDS_JSON"
            fi
            cd - > /dev/null 2>&1
        else
            # Fallback: use nostr_get_events.sh --del --force (requires filtering by kind + author)
            log_warning "strfry not found, using fallback deletion method..."
            physical_failed=$((physical_failed + 1))
        fi
    done
    
    # Summary
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}Complete Video Tree Deletion Summary${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Total events processed:${NC} $total_to_delete"
    echo ""
    echo -e "${YELLOW}Kind 5 deletion (NIP-09):${NC}"
    echo -e "  ✅ Success: $kind5_success"
    [[ $kind5_failed -gt 0 ]] && echo -e "  ❌ Failed: $kind5_failed"
    echo ""
    echo -e "${YELLOW}Physical deletion (database):${NC}"
    echo -e "  ✅ Success: $physical_success"
    [[ $physical_failed -gt 0 ]] && echo -e "  ❌ Failed: $physical_failed"
    echo ""
    
    if [[ $physical_success -eq $total_to_delete ]]; then
        log_success "🎉 Complete video tree deleted successfully!"
        
        # Verify deletion by checking if main event still exists
        log_info "Verifying deletion..."
        sleep 1  # Give strfry time to process deletion
        if [[ -f "$NOSTR_GET_EVENT_BY_ID" ]]; then
            local verify_event=$(bash "$NOSTR_GET_EVENT_BY_ID" "$video_event_id" 2>/dev/null | grep -v '^$' | head -1)
            if [[ -n "$verify_event" ]]; then
                local verify_id=$(echo "$verify_event" | jq -r '.id // empty' 2>/dev/null)
                if [[ "$verify_id" == "$video_event_id" ]]; then
                    log_error "❌ WARNING: Event still exists after deletion!"
                    log_warning "The event may still be visible in create_video_channel.py"
                    log_info "This could be due to:"
                    log_info "  - Database replication delay"
                    log_info "  - Cache in create_video_channel.py"
                    log_info "  - Deletion not fully processed by strfry"
                else
                    log_success "✅ Deletion verified: event no longer exists in database"
                fi
            else
                log_success "✅ Deletion verified: event no longer exists in database"
            fi
        fi
        
        # Send notification message (kind 1, ephemeral 28 days) with IPFS link to export
        if [[ -n "$export_dir" ]] && [[ -d "$export_dir" ]]; then
            local export_file="${export_dir}/video_tree_${video_event_id:0:16}.json"
            if [[ -f "$export_file" ]]; then
                log_info "Uploading export to IPFS and sending notification..."
                
                # Upload JSON file to IPFS
                local ipfs_output=$(ipfs add -q "$export_file" 2>/dev/null)
                if [[ -n "$ipfs_output" ]] && [[ $? -eq 0 ]]; then
                    local ipfs_cid=$(echo "$ipfs_output" | tail -1)
                    local ipfs_url="${IPFS_GATEWAY}/ipfs/${ipfs_cid}"
                    
                    log_info "✅ Export uploaded to IPFS: ${ipfs_cid}"
                    
                    # Find author's .secret.nostr file
                    local author_secret_file=""
                    local nostr_base="${HOME}/.zen/game/nostr"
                    
                    if [[ -d "$nostr_base" ]]; then
                        for email_dir in "$nostr_base"/*; do
                            if [[ -d "$email_dir" ]]; then
                                local hex_file="${email_dir}/HEX"
                                if [[ -f "$hex_file" ]]; then
                                    local stored_hex=$(cat "$hex_file" 2>/dev/null | tr -d '\n\r ')
                                    if [[ "$stored_hex" == "$author_hex" ]]; then
                                        author_secret_file="${email_dir}/.secret.nostr"
                                        break
                                    fi
                                fi
                            fi
                        done
                    fi
                    
                    if [[ -n "$author_secret_file" ]] && [[ -f "$author_secret_file" ]]; then
                        # Prepare notification message
                        local notification_msg="🗑️ Video deletion completed

Event ID: ${video_event_id:0:16}...
Total events deleted: $total_to_delete

📋 Export backup (all events before deletion):
${ipfs_url}

This message will expire in 28 days (ephemeral)."
                        
                        # Send kind 1 message with ephemeral duration (28 days = 2419200 seconds)
                        local nostr_send_script="${MY_PATH}/nostr_send_note.py"
                        if [[ -f "$nostr_send_script" ]]; then
                            log_info "Sending notification message (kind 1, ephemeral 28d)..."
                            if python3 "$nostr_send_script" \
                                --keyfile "$author_secret_file" \
                                --content "$notification_msg" \
                                --kind 1 \
                                --ephemeral 2419200 \
                                --relays "ws://127.0.0.1:7777" \
                                2>/dev/null; then
                                log_success "✅ Notification message sent successfully!"
                            else
                                log_warning "⚠️  Failed to send notification message"
                            fi
                        else
                            log_warning "⚠️  nostr_send_note.py not found, skipping notification"
                        fi
                    else
                        log_warning "⚠️  Could not find .secret.nostr file for author ${author_hex:0:16}..., skipping notification"
                    fi
                else
                    log_warning "⚠️  Failed to upload export to IPFS, skipping notification"
                fi
            fi
        fi
    else
        log_warning "⚠️  Some events may not have been deleted completely"
    fi
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    
    return 0
}

# Show detailed video information with metadata links
show_video_details() {
    local event_id="$1"
    local event="$2"
    local author_hex="$3"
    
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                         ${YELLOW}Video Details${NC}                                      ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Extract all metadata
        local title=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "title") | .[1] // "Untitled"' 2>/dev/null | head -n1)
        local url=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "url") | .[1] // empty' 2>/dev/null | head -n1)
        local duration=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "duration") | .[1] // "0"' 2>/dev/null | head -n1)
        local dimensions=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "dim") | .[1] // empty' 2>/dev/null | head -n1)
        local kind=$(echo "$event" | jq -r '.kind // 0')
        local created_at=$(echo "$event" | jq -r '.created_at // 0')
        local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        
        # Extract source type from tag "i" with prefix "source:"
        local source_tag=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "i" and (.[1] | startswith("source:"))) | .[1]' 2>/dev/null | head -n1)
        local source_type=""
        local source_icon=""
        if [[ -n "$source_tag" ]]; then
            source_type=${source_tag#source:}
            case "$source_type" in
                webcam) source_icon="🎥" ;;
                film) source_icon="🎬" ;;
                serie) source_icon="📺" ;;
                video) source_icon="📹" ;;
                youtube) source_icon="▶️" ;;
                *) source_icon="📄" ;;
            esac
        fi
        
        local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local thumbnail=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local info=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "info") | .[1] // empty' 2>/dev/null | head -n1)
        local file_hash=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "x") | .[1] // empty' 2>/dev/null | head -n1)
        local upload_chain=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "upload_chain") | .[1] // empty' 2>/dev/null | head -n1)
        
        # Extract CID and filename from URL using sed (no lookbehind issues)
        # URL format: /ipfs/CID/filename or http://domain/ipfs/CID/filename
        local cid=$(echo "$url" | sed -n 's|.*/ipfs/\([^/]*\).*|\1|p')
        local filename=$(echo "$url" | sed -n 's|.*/ipfs/[^/]*/\(.*\)|\1|p' | sed 's/%20/ /g; s/%28/(/g; s/%29/)/g; s/%2C/,/g')
        
        # If filename extraction failed, try to get it from the last part of URL
        if [[ -z "$filename" ]]; then
            filename=$(basename "$url" | sed 's/%20/ /g; s/%28/(/g; s/%29/)/g; s/%2C/,/g')
        fi
        
        # Final fallback
        [[ -z "$filename" ]] && filename="video.mp4"
        
        # Extract content/description
        local content=$(echo "$event" | jq -r '.content // ""')
        
        # Display metadata
        echo -e "${YELLOW}📹 Title:${NC} $title"
        echo -e "${YELLOW}🆔 Event ID:${NC} $event_id"
        echo -e "${YELLOW}👤 Author:${NC} ${author_hex:0:16}..."
        echo -e "${YELLOW}📅 Date:${NC} $date"
        echo -e "${YELLOW}⏱️  Duration:${NC} ${duration}s"
        [[ -n "$dimensions" ]] && echo -e "${YELLOW}📐 Dimensions:${NC} $dimensions"
        echo -e "${YELLOW}🎬 Kind:${NC} $kind"
        [[ -n "$source_type" ]] && echo -e "${YELLOW}${source_icon} Source:${NC} $source_type"
        echo ""
        
        if [[ -n "$content" ]]; then
            echo -e "${YELLOW}📝 Description:${NC}"
            echo "$content" | fold -w 76 -s | sed 's/^/  /'
            echo ""
        fi
        
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                           ${YELLOW}IPFS Links${NC}                                        ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        if [[ -n "$cid" ]]; then
            echo -e "${GREEN}📹 Video File:${NC}"
            echo -e "   CID: $cid"
            echo -e "   URL: ${IPFS_GATEWAY}/ipfs/$cid/$filename"
            echo ""
        else
            echo -e "${RED}❌ No video CID found${NC}"
            echo ""
        fi
        
        if [[ -n "$thumbnail" ]]; then
            echo -e "${GREEN}🖼️  Thumbnail:${NC}"
            echo -e "   CID: $thumbnail"
            echo -e "   URL: ${IPFS_GATEWAY}/ipfs/$thumbnail"
            echo ""
        else
            echo -e "${RED}❌ No thumbnail${NC}"
            echo ""
        fi
        
        if [[ -n "$gifanim" ]]; then
            echo -e "${GREEN}🎬 Animated GIF:${NC}"
            echo -e "   CID: $gifanim"
            echo -e "   URL: ${IPFS_GATEWAY}/ipfs/$gifanim"
            echo ""
        else
            echo -e "${RED}❌ No animated GIF${NC}"
            echo ""
        fi
        
        if [[ -n "$info" ]]; then
            echo -e "${GREEN}📋 Info.json:${NC}"
            echo -e "   CID: $info"
            echo -e "   URL: ${IPFS_GATEWAY}/ipfs/$info"
            echo ""
        else
            echo -e "${RED}❌ No info.json${NC}"
            echo ""
        fi
        
        if [[ -n "$file_hash" ]]; then
            echo -e "${YELLOW}🔐 File Hash (SHA256):${NC}"
            echo -e "   $file_hash"
            echo ""
        fi
        
        if [[ -n "$upload_chain" ]]; then
            echo -e "${YELLOW}🔗 Upload Chain (Provenance):${NC}"
            echo -e "   $upload_chain"
            echo ""
        fi
        
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${YELLOW}1.${NC} 🔄 Upgrade video (re-generate metadata)"
        echo -e "  ${YELLOW}2.${NC} 📋 Copy video URL to clipboard"
        echo -e "  ${YELLOW}3.${NC} 🖼️  Open thumbnail in browser"
        echo -e "  ${YELLOW}4.${NC} 🎬 Open animated GIF in browser"
        echo -e "  ${YELLOW}5.${NC} 📊 View info.json"
        echo -e "  ${YELLOW}6.${NC} 💾 Export complete video tree (all related events)"
        echo -e "  ${YELLOW}7.${NC} 🗑️  Delete this video (kind 5 - NIP-09)"
        echo -e "  ${YELLOW}8.${NC} ⚠️  Delete physically from database"
        echo -e "  ${YELLOW}9.${NC} 💥 Delete both (kind 5 + physical)"
        echo -e "  ${YELLOW}10.${NC} ${RED}🗑️💥 Delete COMPLETE TREE (all events + physical)${NC}"
        echo -e "  ${YELLOW}b.${NC} 🔙 Back to video list"
        echo -e "  ${YELLOW}0.${NC} 🚪 Exit"
        echo ""
        
        read -p "$(echo -e ${CYAN}Choose action:${NC} )" action
        
        case "$action" in
            1)
                # Upgrade video
                echo ""
                read -p "Upgrade this video? This will re-generate metadata. (yes/NO): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    cmd_upgrade "$event_id" "$author_hex"
                    read -p "Press ENTER to continue..."
                fi
                ;;
            2)
                # Copy video URL
                if [[ -n "$cid" ]]; then
                    local video_url="${IPFS_GATEWAY}/ipfs/$cid/$filename"
                    echo "$video_url" | xclip -selection clipboard 2>/dev/null || echo "$video_url"
                    log_success "Video URL copied: $video_url"
                else
                    log_error "No video URL available"
                fi
                sleep 2
                ;;
            3)
                # Open thumbnail
                if [[ -n "$thumbnail" ]]; then
                    local thumb_url="${IPFS_GATEWAY}/ipfs/$thumbnail"
                    xdg-open "$thumb_url" 2>/dev/null || echo "Open in browser: $thumb_url"
                    log_success "Opening thumbnail in browser..."
                else
                    log_error "No thumbnail available"
                fi
                sleep 2
                ;;
            4)
                # Open GIF
                if [[ -n "$gifanim" ]]; then
                    local gif_url="${IPFS_GATEWAY}/ipfs/$gifanim"
                    xdg-open "$gif_url" 2>/dev/null || echo "Open in browser: $gif_url"
                    log_success "Opening animated GIF in browser..."
                else
                    log_error "No animated GIF available"
                fi
                sleep 2
                ;;
            5)
                # View info.json
                if [[ -n "$info" ]]; then
                    echo ""
                    log_info "Fetching info.json..."
                    local info_url="${IPFS_GATEWAY}/ipfs/$info/info.json"
                    curl -s "$info_url" | jq '.' 2>/dev/null || echo "Failed to fetch info.json"
                    echo ""
                    read -p "Press ENTER to continue..."
                else
                    log_error "No info.json available"
                    sleep 2
                fi
                ;;
            6)
                # Export complete video tree
                echo ""
                log_info "Exporting complete video tree..."
                if export_video_tree "$event_id" "$author_hex"; then
                    log_success "Export complete!"
                else
                    log_error "Export failed"
                fi
                echo ""
                read -p "Press ENTER to continue..."
                ;;
            7)
                # Delete video with kind 5 (NIP-09)
                echo ""
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}Delete with kind 5 (NIP-09)${NC}"
                echo ""
                echo -e "This will publish a deletion event (kind 5) according to NIP-09."
                echo -e "Compliant clients will hide this video from their interface."
                echo -e "The original video event remains in the database."
                echo ""
                read -p "Delete this video with kind 5? (yes/NO): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    if delete_event_by_id "$event_id" "$author_hex" "true" "kind5"; then
                        log_success "Video deleted (kind 5 published)!"
                        sleep 2
                        return 0
                    else
                        log_error "Failed to delete video"
                        sleep 2
                    fi
                fi
                ;;
            7)
                # Delete video with kind 5 (NIP-09)
                echo ""
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}Delete with kind 5 (NIP-09)${NC}"
                echo ""
                echo -e "This will publish a deletion event (kind 5) according to NIP-09."
                echo -e "Compliant clients will hide this video from their interface."
                echo -e "The original video event remains in the database."
                echo ""
                read -p "Delete this video with kind 5? (yes/NO): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    if delete_event_by_id "$event_id" "$author_hex" "true" "kind5"; then
                        log_success "Video deleted (kind 5 published)!"
                        echo ""
                        read -p "$(echo -e ${CYAN}Press ENTER to return to video list...${NC} )"
                        return 0
                    else
                        log_error "Failed to delete video"
                        sleep 2
                    fi
                fi
                ;;
            8)
                # Physical deletion from database
                echo ""
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${RED}⚠️  Physical Deletion from Database${NC}"
                echo ""
                echo -e "${YELLOW}WARNING:${NC} This will permanently remove the event from the relay database."
                echo -e "This operation cannot be undone!"
                echo -e "Use this only if you are the relay operator."
                echo ""
                read -p "Physically delete this video from database? (yes/NO): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    if delete_event_by_id "$event_id" "$author_hex" "true" "physical"; then
                        log_success "Video physically deleted from database!"
                        echo ""
                        read -p "$(echo -e ${CYAN}Press ENTER to return to video list...${NC} )"
                        return 0
                    else
                        log_error "Failed to delete video"
                        sleep 2
                    fi
                fi
                ;;
            9)
                # Combined deletion: kind 5 + physical
                echo ""
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${MAGENTA}💥 Complete Deletion (kind 5 + physical)${NC}"
                echo ""
                echo -e "This will:"
                echo -e "  ${YELLOW}1.${NC} Publish a kind 5 deletion event (NIP-09)"
                echo -e "  ${YELLOW}2.${NC} Physically remove the event from the local database"
                echo ""
                echo -e "${YELLOW}Note:${NC} This deletes only the main video event."
                echo -e "Use option 10 to delete the complete tree (all related events)."
                echo ""
                read -p "Perform complete deletion (kind 5 + physical)? (yes/NO): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    if delete_event_by_id "$event_id" "$author_hex" "true" "both"; then
                        log_success "Complete deletion finished!"
                        echo ""
                        read -p "$(echo -e ${CYAN}Press ENTER to return to video list...${NC} )"
                        return 0
                    else
                        log_error "Failed to complete deletion"
                        sleep 2
                    fi
                fi
                ;;
            10)
                # Delete complete video tree (all related events)
                echo ""
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${RED}🗑️💥 DELETE COMPLETE VIDEO TREE${NC}"
                echo ""
                echo -e "${RED}⚠️  WARNING: This will delete EVERYTHING related to this video!${NC}"
                echo ""
                echo -e "This will permanently delete:"
                echo -e "  • Main video event (kind 21/22)"
                echo -e "  • All user tags (kind 1985)"
                echo -e "  • All TMDB enrichments (kind 1986)"
                echo -e "  • All author updates (kind 30001)"
                echo -e "  • All comments (kind 1111)"
                echo ""
                echo -e "Deletion method:"
                echo -e "  ${YELLOW}1.${NC} Publish kind 5 deletion events for all"
                echo -e "  ${YELLOW}2.${NC} Physical deletion using nostr_get_events.sh --del --force"
                echo ""
                echo -e "${RED}⚠️  This operation CANNOT be undone!${NC}"
                echo -e "${YELLOW}Note:${NC} A backup export will be created before deletion."
                echo ""
                
                # Check if user is LOCAL (has MULTIPASS on this station)
                if ! check_local_pubkey "$author_hex"; then
                    log_error "❌ This feature is only available for LOCAL accounts (MULTIPASS on this station)"
                    log_warning "Author ${author_hex:0:16}... is not found locally"
                    echo ""
                    read -p "Press ENTER to continue..."
                    continue
                fi
                
                read -p "$(echo -e ${RED}Type 'DELETE TREE' to confirm:${NC} )" confirm
                if [[ "$confirm" == "DELETE TREE" ]]; then
                    if delete_video_tree "$event_id" "$author_hex" "false"; then
                        log_success "Complete video tree deleted!"
                        echo ""
                        read -p "$(echo -e ${CYAN}Press ENTER to return to video list...${NC} )"
                        return 0
                    else
                        log_error "Failed to delete video tree"
                        sleep 2
                    fi
                else
                    log_warning "Deletion cancelled"
                    sleep 1
                fi
                ;;
            b)
                return 0
                ;;
            0)
                clear
                exit 0
                ;;
            *)
                log_error "Invalid action"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# Command: channel (interactive administration)
################################################################################
cmd_channel() {
    local user_hex="$1"
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                   ${YELLOW}NostrTube Channel Administration${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show user info
    log_info "Channel owner: ${user_hex:0:16}..."
    echo ""
    
    # Get channel name from first video
    local events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit 1 2>/dev/null)
    [[ -z "$events" ]] && events=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit 1 2>/dev/null)
    
    local channel_name="unknown"
    if [[ -n "$events" ]]; then
        channel_name=$(echo "$events" | jq -r '.tags[]? | select(.[0] == "t" and (.[1] | startswith("Channel-"))) | .[1]' 2>/dev/null | head -n1)
        channel_name=${channel_name#Channel-}
        channel_name=${channel_name//_/@}
        channel_name=${channel_name//_/.}
    fi
    
    echo -e "${CYAN}📺 Channel:${NC} $channel_name"
    echo ""
    
    # Quick stats
    local total=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit 1000 --output count 2>/dev/null)
    total=$((total + $(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit 1000 --output count 2>/dev/null)))
    
    echo -e "${GREEN}Total videos: $total${NC}"
    echo ""
    
    # Interactive menu
    while true; do
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                           ${YELLOW}Channel Actions${NC}                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  1. 📋 List all videos"
        echo -e "  2. 📊 Show statistics"
        echo -e "  3. 🔍 Check metadata completeness"
        echo -e "  4. 🔄 Upgrade all videos (fix missing metadata)"
        echo -e "  5. 🗑️  Delete specific video"
        echo -e "  6. 🧹 Clean duplicate videos"
        echo -e "  7. 📤 Export channel data (JSON)"
        echo -e "  8. 🔙 Back to main menu"
        echo -e "  0. 🚪 Exit"
        echo ""
        read -p "$(echo -e ${YELLOW}Choose action [0-8]:${NC} )" action
        echo ""
        
        case "$action" in
            1)
                cmd_list "$user_hex"
                echo ""
                read -p "Press ENTER to continue..."
                clear
                ;;
            2)
                cmd_stats "$user_hex"
                echo ""
                read -p "Press ENTER to continue..."
                clear
                ;;
            3)
                cmd_check "$user_hex"
                echo ""
                read -p "Press ENTER to continue..."
                clear
                ;;
            4)
                cmd_upgrade_all "$user_hex"
                echo ""
                read -p "Press ENTER to continue..."
                clear
                ;;
            5)
                echo "🗑️  Delete specific video"
                echo ""
                echo -e "${CYAN}Choose deletion method:${NC}"
                echo -e "  1. Kind 5 deletion (NIP-09) - Publish deletion event"
                echo -e "  2. Physical deletion from database"
                echo -e "  3. Both (kind 5 + physical)"
                echo -e "  0. Cancel"
                echo ""
                read -p "Method: " del_method
                
                case "$del_method" in
                    1|2|3)
                        echo ""
                        read -p "Enter event ID: " event_id
                        if [[ -n "$event_id" ]]; then
                            echo ""
                            
                            if [[ "$del_method" == "1" ]]; then
                                log_info "Kind 5 deletion method selected"
                                read -p "Publish kind 5 deletion event for $event_id? (yes/NO): " confirm
                                if [[ "$confirm" == "yes" ]]; then
                                    log_info "Deleting event: ${event_id:0:16}..."
                                    if delete_event_by_id "$event_id" "$user_hex" "true" "kind5"; then
                                        log_success "Event deleted successfully (kind 5 published)!"
                                    else
                                        log_error "Failed to delete event"
                                    fi
                                else
                                    log_warning "Deletion cancelled"
                                fi
                            elif [[ "$del_method" == "2" ]]; then
                                log_warning "Physical deletion method selected"
                                echo -e "${RED}⚠️  WARNING: This will permanently remove the event from the database!${NC}"
                                read -p "Physically delete $event_id from database? (yes/NO): " confirm
                                if [[ "$confirm" == "yes" ]]; then
                                    log_info "Deleting event: ${event_id:0:16}..."
                                    if delete_event_by_id "$event_id" "$user_hex" "true" "physical"; then
                                        log_success "Event physically deleted from database!"
                                    else
                                        log_error "Failed to delete event"
                                    fi
                                else
                                    log_warning "Deletion cancelled"
                                fi
                            else
                                log_warning "Combined deletion method selected (kind 5 + physical)"
                                echo -e "${RED}⚠️  WARNING: This will publish kind 5 AND physically delete from database!${NC}"
                                read -p "Perform complete deletion for $event_id? (yes/NO): " confirm
                                if [[ "$confirm" == "yes" ]]; then
                                    log_info "Deleting event: ${event_id:0:16}..."
                                    if delete_event_by_id "$event_id" "$user_hex" "true" "both"; then
                                        log_success "Complete deletion finished (kind 5 + physical)!"
                                    else
                                        log_error "Failed to complete deletion"
                                    fi
                                else
                                    log_warning "Deletion cancelled"
                                fi
                            fi
                        fi
                        ;;
                    0)
                        log_info "Deletion cancelled"
                        ;;
                    *)
                        log_error "Invalid method"
                        ;;
                esac
                echo ""
                read -p "Press ENTER to continue..."
                clear
                ;;
            6)
                echo "🧹 Clean duplicate videos"
                echo ""
                log_info "Scanning for duplicates (same file hash)..."
                
                # Get all events
                local all_events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit 1000 2>/dev/null)
                all_events+=$'\n'
                all_events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit 1000 2>/dev/null)
                
                # Find duplicates by hash
                local -A hash_map
                local duplicates=0
                
                while IFS= read -r event; do
                    [[ -z "$event" ]] && continue
                    
                    local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
                    [[ -z "$event_id" ]] && continue
                    
                    local hash=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "x") | .[1] // empty' 2>/dev/null | head -n1)
                    
                    if [[ -n "$hash" ]]; then
                        if [[ -n "${hash_map[$hash]}" ]]; then
                            echo -e "  ${YELLOW}Duplicate found:${NC}"
                            echo -e "    - Original: ${hash_map[$hash]:0:16}..."
                            echo -e "    - Duplicate: ${event_id:0:16}..."
                            duplicates=$((duplicates + 1))
                        else
                            hash_map["$hash"]="$event_id"
                        fi
                    fi
                done <<< "$all_events"
                
                if [[ $duplicates -eq 0 ]]; then
                    log_success "No duplicates found!"
                else
                    log_warning "Found $duplicates duplicate(s)"
                    echo ""
                    echo "Note: Automatic deletion not implemented yet"
                    echo "Please use 'Delete specific video' action to remove duplicates manually"
                fi
                
                echo ""
                read -p "Press ENTER to continue..."
                clear
                ;;
            7)
                echo "📤 Export channel data"
                echo ""
                local export_file="${HOME}/.zen/tmp/channel_${user_hex:0:8}_$(date +%Y%m%d_%H%M%S).json"
                
                log_info "Exporting to: $export_file"
                
                # Get all events and export
                bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit 1000 2>/dev/null > "$export_file"
                bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit 1000 2>/dev/null >> "$export_file"
                
                log_success "Export complete!"
                echo "  File: $export_file"
                
                echo ""
                read -p "Press ENTER to continue..."
                clear
                ;;
            8)
                clear
                return 0
                ;;
            0)
                echo ""
                log_info "Goodbye! 👋"
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                sleep 1
                clear
                ;;
        esac
    done
}

################################################################################
# Command: upgrade-all
################################################################################
cmd_upgrade_all() {
    local user_hex="$1"
    
    log_info "Upgrading all videos for user: ${user_hex:0:16}..."
    
    # Get all videos with missing metadata
    local events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" --limit 1000 2>/dev/null)
    events+=$'\n'
    events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$user_hex" --limit 1000 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No videos found"
        return 0
    fi
    
    # Count videos needing upgrade
    local count=0
    local event_ids=()
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        # Check if missing gifanim_ipfs
        local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        
        if [[ -z "$gifanim" ]]; then
            event_ids+=("$event_id")
            count=$((count + 1))
        fi
        
    done <<< "$events"
    
    if [[ $count -eq 0 ]]; then
        log_success "All videos already have complete metadata!"
        return 0
    fi
    
    log_info "Found $count videos needing upgrade"
    
    # Confirmation
    if [[ "$FORCE" != "true" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  This will upgrade $count videos${NC}"
        echo "  This may take a while and will:"
        echo "  - Download each video from IPFS"
        echo "  - Re-upload via upload2ipfs.sh"
        echo "  - Delete old NOSTR events"
        echo "  - Publish new events with complete metadata"
        echo ""
        read -p "Continue? (yes/NO): " confirm
        
        if [[ "$confirm" != "yes" ]]; then
            log_warning "Upgrade cancelled by user"
            return 0
        fi
    fi
    
    # Upgrade each video
    local success=0
    local failed=0
    
    for event_id in "${event_ids[@]}"; do
        log_info "Upgrading video $((success + failed + 1))/$count..."
        
        if cmd_upgrade "$event_id" "$user_hex"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            log_error "Failed to upgrade: $event_id"
        fi
        
        # Pause between upgrades to avoid overloading
        sleep 2
    done
    
    # Summary
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Upgrade complete!${NC}"
    echo -e "  ✅ Success: $success"
    [[ $failed -gt 0 ]] && echo -e "  ❌ Failed: $failed"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: cleanup (clean non-compliant events)
################################################################################
cmd_cleanup() {
    log_info "Scanning for non-compliant events..."
    echo ""
    
    # Get all video events
    local events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --limit 10000 2>/dev/null)
    events+=$'\n'
    events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --limit 10000 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No video events found"
        return 0
    fi
    
    # Collect non-compliant events categorized by author type
    local -a invalid_author_ids=()
    local -a invalid_author_events=()
    local -a invalid_author_reasons=()
    
    local -a local_author_ids=()
    local -a local_author_events=()
    local -a local_author_reasons=()
    
    local -a remote_author_ids=()
    local -a remote_author_events=()
    local -a remote_author_reasons=()
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        local author=$(echo "$event" | jq -r '.pubkey // empty' 2>/dev/null)
        
        # Check if author is valid (64 hex characters)
        local is_valid_author=false
        if [[ -n "$author" ]] && [[ ${#author} -eq 64 ]] && [[ "$author" =~ ^[0-9a-f]{64}$ ]]; then
            is_valid_author=true
        fi
        
        local is_non_compliant=false
        local reason=""
        
        # Check 1: Channel tag (must have Channel-*)
        local channel=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "t" and (.[1] | startswith("Channel-"))) | .[1]' 2>/dev/null | head -n1)
        if [[ -z "$channel" ]]; then
            is_non_compliant=true
            reason="❌ No channel tag"
        fi
        
        # Check 2: Complete metadata (gifanim_ipfs, thumbnail_ipfs, info)
        local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local thumbnail=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
        local info=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "info") | .[1] // empty' 2>/dev/null | head -n1)
        
        local metadata_status=""
        [[ -z "$gifanim" ]] && metadata_status+="❌ No GIF "
        [[ -z "$thumbnail" ]] && metadata_status+="❌ No thumbnail "
        [[ -z "$info" ]] && metadata_status+="❌ No info"
        
        if [[ -n "$metadata_status" ]]; then
            is_non_compliant=true
            [[ -n "$reason" ]] && reason="$reason | "
            reason="${reason}${metadata_status}"
        fi
        
        # Categorize non-compliant events
        if [[ "$is_non_compliant" == "true" ]]; then
            if [[ "$is_valid_author" != "true" ]]; then
                # Invalid or missing author -> DELETE
                invalid_author_ids+=("$event_id")
                invalid_author_events+=("$event")
                invalid_author_reasons+=("${reason} | 🚫 Invalid/missing author")
            elif check_local_pubkey "$author"; then
                # Local account -> UPGRADE
                local_author_ids+=("$event_id")
                local_author_events+=("$event")
                local_author_reasons+=("$reason")
            else
                # Remote account -> IGNORE (can't upgrade)
                remote_author_ids+=("$event_id")
                remote_author_events+=("$event")
                remote_author_reasons+=("$reason")
            fi
        fi
        
    done <<< "$events"
    
    local total_invalid=${#invalid_author_ids[@]}
    local total_local=${#local_author_ids[@]}
    local total_remote=${#remote_author_ids[@]}
    local total_non_compliant=$((total_invalid + total_local + total_remote))
    
    if [[ $total_non_compliant -eq 0 ]]; then
        log_success "✅ All events are compliant with UPlanet File Contract!"
        return 0
    fi
    
    # Display summary
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${YELLOW}Non-Compliant Events - Actionable Items${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show only actionable items
    local has_actionable=false
    if [[ $total_invalid -gt 0 ]]; then
        echo -e "  ${RED}Invalid/Missing Author:${NC} $total_invalid event(s) → ${RED}WILL BE DELETED${NC}"
        has_actionable=true
    fi
    if [[ $total_local -gt 0 ]]; then
        echo -e "  ${GREEN}Local Account:${NC} $total_local event(s) → ${GREEN}CAN BE UPGRADED${NC}"
        has_actionable=true
    fi
    
    if [[ "$has_actionable" != "true" ]]; then
        log_warning "No actionable events found (all are from remote accounts)"
        [[ $total_remote -gt 0 ]] && echo -e "  ${YELLOW}Note:${NC} $total_remote remote account events cannot be fixed (missing keys)"
        return 0
    fi
    
    [[ $total_remote -gt 0 ]] && echo -e "  ${YELLOW}Note:${NC} $total_remote remote account events ignored (cannot be fixed)"
    echo ""
    
    # Display events by category
    
    # Category 1: Invalid Author (TO DELETE)
    if [[ $total_invalid -gt 0 ]]; then
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}         ${RED}🚫 Events with Invalid/Missing Author (TO DELETE)${NC}             ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        for i in "${!invalid_author_ids[@]}"; do
            local idx=$((i + 1))
            local event_id="${invalid_author_ids[$i]}"
            local event="${invalid_author_events[$i]}"
            
            local title=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "title") | .[1] // "Untitled"' 2>/dev/null | head -n1)
            local author=$(echo "$event" | jq -r '.pubkey // "N/A"' 2>/dev/null)
            local kind=$(echo "$event" | jq -r '.kind // 0' 2>/dev/null)
            local created_at=$(echo "$event" | jq -r '.created_at // 0' 2>/dev/null)
            local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
            
            echo -e "${RED}[DELETE-$idx]${NC}"
            echo -e "    ${CYAN}Event ID:${NC} ${event_id:0:32}..."
            echo -e "    ${CYAN}Title:${NC} $title"
            echo -e "    ${CYAN}Author:${NC} $author"
            echo -e "    ${CYAN}Kind:${NC} $kind | ${CYAN}Date:${NC} $date"
            echo -e "    ${RED}Issue:${NC} ${invalid_author_reasons[$i]}"
            echo ""
        done
    fi
    
    # Category 2: Local Account (CAN UPGRADE)
    if [[ $total_local -gt 0 ]]; then
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}            ${GREEN}🔧 Local Account Events (CAN BE UPGRADED)${NC}                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        for i in "${!local_author_ids[@]}"; do
            local idx=$((i + 1))
            local event_id="${local_author_ids[$i]}"
            local event="${local_author_events[$i]}"
            
            local title=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "title") | .[1] // "Untitled"' 2>/dev/null | head -n1)
            local author=$(echo "$event" | jq -r '.pubkey // "unknown"' 2>/dev/null)
            local kind=$(echo "$event" | jq -r '.kind // 0' 2>/dev/null)
            local created_at=$(echo "$event" | jq -r '.created_at // 0' 2>/dev/null)
            local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
            
            echo -e "${GREEN}[UPGRADE-$idx]${NC}"
            echo -e "    ${CYAN}Event ID:${NC} ${event_id:0:32}..."
            echo -e "    ${CYAN}Title:${NC} $title"
            echo -e "    ${CYAN}Author:${NC} ${author:0:16}... ${GREEN}[LOCAL]${NC}"
            echo -e "    ${CYAN}Kind:${NC} $kind | ${CYAN}Date:${NC} $date"
            echo -e "    ${YELLOW}Issue:${NC} ${local_author_reasons[$i]}"
            echo ""
        done
    fi
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Action menu
    if [[ "$FORCE" != "true" ]]; then
        echo -e "${YELLOW}⚠️  Actions:${NC}"
        echo ""
        
        local menu_idx=1
        local delete_option=""
        local upgrade_option=""
        
        # Build menu dynamically
        if [[ $total_invalid -gt 0 ]]; then
            delete_option="$menu_idx"
            echo -e "  ${RED}$menu_idx. Delete invalid author events${NC} ($total_invalid events)"
            menu_idx=$((menu_idx + 1))
        fi
        
        if [[ $total_local -gt 0 ]]; then
            upgrade_option="$menu_idx"
            echo -e "  ${GREEN}$menu_idx. Upgrade local account events${NC} ($total_local events)"
            menu_idx=$((menu_idx + 1))
        fi
        
        echo -e "  ${YELLOW}0. Cancel${NC}"
        echo ""
        read -p "$(echo -e ${CYAN}Enter your choice:${NC} )" choice
        
        if [[ "$choice" == "0" ]] || [[ -z "$choice" ]]; then
            log_warning "Cleanup cancelled by user"
            return 0
        elif [[ -n "$delete_option" ]] && [[ "$choice" == "$delete_option" ]]; then
            # Delete invalid author events
            if [[ $total_invalid -eq 0 ]]; then
                log_warning "No invalid author events to delete"
                return 0
            fi
            
            echo ""
            echo -e "${RED}⚠️  You are about to DELETE $total_invalid event(s) with invalid/missing authors!${NC}"
            echo -e "${RED}This operation CANNOT be undone!${NC}"
            echo ""
            read -p "Confirm deletion? (type 'DELETE' to confirm): " confirm
            
            if [[ "$confirm" != "DELETE" ]]; then
                log_warning "Deletion cancelled by user"
                return 0
            fi
            
            # Delete events
            log_info "Deleting events with invalid authors..."
            echo ""
            
            local STRFRY_DIR="$HOME/.zen/strfry"
            local STRFRY_BIN="${STRFRY_DIR}/strfry"
            
            if [[ ! -f "${STRFRY_BIN}" ]]; then
                log_error "strfry not found at ${STRFRY_BIN}"
                return 1
            fi
            
            cd "$STRFRY_DIR" || return 1
            
            local success_count=0
            local failed_count=0
            
            for event_id in "${invalid_author_ids[@]}"; do
                local IDS_JSON=$(echo "$event_id" | jq -R . | jq -s -c '{ids: .}')
                
                if ./strfry delete --filter="$IDS_JSON" 2>&1 >/dev/null; then
                    success_count=$((success_count + 1))
                    log_success "  ✅ Deleted: ${event_id:0:16}..."
                else
                    failed_count=$((failed_count + 1))
                    log_error "  ❌ Failed: ${event_id:0:16}..."
                fi
            done
            
            cd - > /dev/null 2>&1
            
            echo ""
            echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║${NC}                        ${YELLOW}Deletion Summary${NC}                                   ${CYAN}║${NC}"
            echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${GREEN}✅ Successfully deleted: $success_count${NC}"
            [[ $failed_count -gt 0 ]] && echo -e "${RED}❌ Failed: $failed_count${NC}"
            echo ""
            log_success "🎉 Invalid author events deleted!"
            echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
            
        elif [[ -n "$upgrade_option" ]] && [[ "$choice" == "$upgrade_option" ]]; then
            # Upgrade local account events
            if [[ $total_local -eq 0 ]]; then
                log_warning "No local account events to upgrade"
                return 0
            fi
            
            echo ""
            echo -e "${GREEN}🔧 Upgrading local account events...${NC}"
            echo ""
            echo -e "${YELLOW}This will:${NC}"
            echo -e "  1. Download each video from IPFS"
            echo -e "  2. Regenerate metadata (GIF, thumbnail, info.json)"
            echo -e "  3. Delete old event"
            echo -e "  4. Publish new event with complete metadata"
            echo ""
            echo -e "${YELLOW}⚠️  This may take a while ($total_local videos to upgrade)${NC}"
            echo ""
            read -p "Continue with upgrade? (yes/NO): " confirm
            
            if [[ "$confirm" != "yes" ]]; then
                log_warning "Upgrade cancelled by user"
                return 0
            fi
            
            local success_count=0
            local failed_count=0
            
            for i in "${!local_author_ids[@]}"; do
                local event_id="${local_author_ids[$i]}"
                local event="${local_author_events[$i]}"
                local author=$(echo "$event" | jq -r '.pubkey')
                
                log_info "Upgrading video $((i + 1))/$total_local: ${event_id:0:16}..."
                echo ""
                
                # Call upgrade directly without capturing output
                if cmd_upgrade "$event_id" "$author"; then
                    success_count=$((success_count + 1))
                    log_success "✅ Video upgraded successfully"
                else
                    failed_count=$((failed_count + 1))
                    log_error "❌ Failed to upgrade video"
                fi
                
                echo ""
                # Pause between upgrades
                sleep 2
            done
            
            echo ""
            echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║${NC}                        ${YELLOW}Upgrade Summary${NC}                                    ${CYAN}║${NC}"
            echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${GREEN}✅ Successfully upgraded: $success_count${NC}"
            [[ $failed_count -gt 0 ]] && echo -e "${RED}❌ Failed: $failed_count${NC}"
            echo ""
            log_success "🎉 Local account events upgraded!"
            echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        else
            log_error "Invalid choice: $choice"
            return 1
        fi
    else
        # Force mode: delete invalid authors only
        if [[ $total_invalid -eq 0 ]]; then
            log_success "No invalid author events to delete"
            return 0
        fi
        
        log_info "Force mode: Deleting $total_invalid invalid author events..."
        echo ""
        
        local STRFRY_DIR="$HOME/.zen/strfry"
        local STRFRY_BIN="${STRFRY_DIR}/strfry"
        
        if [[ ! -f "${STRFRY_BIN}" ]]; then
            log_error "strfry not found at ${STRFRY_BIN}"
            return 1
        fi
        
        cd "$STRFRY_DIR" || return 1
        
        local success_count=0
        local failed_count=0
        
        for event_id in "${invalid_author_ids[@]}"; do
            local IDS_JSON=$(echo "$event_id" | jq -R . | jq -s -c '{ids: .}')
            
            if ./strfry delete --filter="$IDS_JSON" 2>&1 >/dev/null; then
                success_count=$((success_count + 1))
                log_success "  ✅ Deleted: ${event_id:0:16}..."
            else
                failed_count=$((failed_count + 1))
                log_error "  ❌ Failed: ${event_id:0:16}..."
            fi
        done
        
        cd - > /dev/null 2>&1
        
        echo ""
        log_success "✅ Deleted: $success_count events"
        [[ $failed_count -gt 0 ]] && log_error "❌ Failed: $failed_count events"
    fi
}

################################################################################
# Main
################################################################################
main() {
    # Parse command
    COMMAND="${1:-}"
    shift || true
    
    # Default options
    NPUB=""
    HEX=""
    EMAIL=""
    EVENT_ID=""
    KIND=""
    LIMIT=100
    FORCE=false
    VERBOSE=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--npub)
                NPUB="$2"
                shift 2
                ;;
            -x|--hex)
                HEX="$2"
                shift 2
                ;;
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -i|--event-id)
                EVENT_ID="$2"
                shift 2
                ;;
            -k|--kind)
                KIND="$2"
                shift 2
                ;;
            -l|--limit)
                LIMIT="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Show help if no command
    [[ -z "$COMMAND" ]] && usage
    
    # Check dependencies
    check_dependencies || exit 1
    
    # Determine user hex (not required for list-all, browse, and cleanup)
    USER_HEX=""
    if [[ "$COMMAND" != "list-all" ]] && [[ "$COMMAND" != "browse" ]] && [[ "$COMMAND" != "cleanup" ]]; then
        if [[ -n "$HEX" ]]; then
            USER_HEX="$HEX"
        elif [[ -n "$NPUB" ]]; then
            USER_HEX=$(npub_to_hex "$NPUB")
        elif [[ -n "$EMAIL" ]]; then
            USER_HEX=$(find_hex_from_email "$EMAIL")
            [[ -z "$USER_HEX" ]] && exit 1
        else
            log_error "Must provide --npub, --hex, or --email"
            exit 1
        fi
        
        log_debug "User hex: $USER_HEX"
    fi
    
    # Execute command
    case "$COMMAND" in
        list-all)
            # list-all doesn't require user identification
            cmd_list_all
            ;;
        browse)
            # browse doesn't require user identification
            cmd_browse
            ;;
        list)
            cmd_list "$USER_HEX"
            ;;
        channel)
            cmd_channel "$USER_HEX"
            ;;
        check)
            cmd_check "$USER_HEX"
            ;;
        stats)
            cmd_stats "$USER_HEX"
            ;;
        upgrade)
            if [[ -z "$EVENT_ID" ]]; then
                log_error "Must provide --event-id for upgrade command"
                exit 1
            fi
            cmd_upgrade "$EVENT_ID" "$USER_HEX"
            ;;
        upgrade-all)
            cmd_upgrade_all "$USER_HEX"
            ;;
        cleanup)
            # cleanup doesn't require user identification
            cmd_cleanup
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            ;;
    esac
}

# Trap cleanup
trap "rm -rf $TEMP_DIR" EXIT

# Run main
main "$@"

