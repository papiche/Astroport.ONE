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
IPFS_GATEWAY="${myIPFS:-http://127.0.0.1:8080}"
UPASSPORT_API="${myHOST:-http://127.0.0.1:54321}"
NOSTR_GET_EVENTS="${MY_PATH}/nostr_get_events.sh"
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

${YELLOW}UPGRADE PROCESS:${NC}
    1. Download original video from IPFS
    2. Re-upload via upload2ipfs.sh (generates fresh metadata)
    3. Delete old NOSTR event
    4. Publish new event with complete metadata (including gifanim_ipfs)

${YELLOW}NOTES:${NC}
    - Requires jq, ipfs, and curl
    - Videos are temporarily downloaded to ~/.zen/tmp/
    - Old events are permanently deleted (cannot be undone)
    - Use --force to skip confirmation prompts

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
            # Extract hex from .secret.nostr
            local hex=$(grep -oP 'NPUB=[a-f0-9]{64}' "$dir/.secret.nostr" 2>/dev/null | cut -d= -f2)
            if [[ -n "$hex" ]]; then
                echo "$hex"
                return 0
            fi
        fi
    done
    
    log_error "Could not find hex pubkey for email: $email"
    return 1
}

# Delete specific NOSTR event by ID using strfry
delete_event_by_id() {
    local event_id="$1"
    local force="${2:-false}"
    
    log_debug "Deleting event: $event_id"
    
    # Check strfry exists
    local STRFRY_DIR="$HOME/.zen/strfry"
    local STRFRY_BIN="${STRFRY_DIR}/strfry"
    
    if [[ ! -f "${STRFRY_BIN}" ]]; then
        log_error "strfry not found at ${STRFRY_BIN}"
        return 1
    fi
    
    # Change to strfry directory
    cd "$STRFRY_DIR" || return 1
    
    # Build filter JSON with specific event ID
    # Format: {"ids": ["event_id"]}
    local IDS_JSON=$(echo "$event_id" | jq -R . | jq -s -c '{ids: .}')
    
    log_debug "Delete filter: $IDS_JSON"
    
    # Execute deletion with filter (no confirmation if force=true)
    if [[ "$force" == "true" ]]; then
        log_debug "Executing deletion with --force..."
        if ./strfry delete --filter="$IDS_JSON" 2>&1 >/dev/null; then
            cd - > /dev/null 2>&1
            return 0
        else
            log_error "Failed to delete event: $event_id"
            cd - > /dev/null 2>&1
            return 1
        fi
    else
        log_warning "Confirmation required for deletion"
        echo "Event ID to delete: $event_id"
        read -p "Continue? (yes/NO): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            if ./strfry delete --filter="$IDS_JSON" 2>&1 >/dev/null; then
                cd - > /dev/null 2>&1
                return 0
            else
                log_error "Failed to delete event: $event_id"
                cd - > /dev/null 2>&1
                return 1
            fi
        else
            log_warning "Deletion cancelled"
            cd - > /dev/null 2>&1
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
    
    # Delete old event using strfry directly
    log_info "Deleting old NOSTR event: ${event_id:0:16}..."
    if delete_event_by_id "$event_id" "true"; then
        log_success "Old event deleted successfully"
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
            secret_file="${HOME}/.zen/game/nostr/${email}_DID/.secret.nostr"
            
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
            echo -e "  ${YELLOW}$idx.${NC} 📺 $channel (${GREEN}$video_count${NC} videos)"
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
    
    # Get all videos for this author
    local events=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$author_hex" --limit 1000 2>/dev/null)
    events+=$'\n'
    events+=$(bash "$NOSTR_GET_EVENTS" --kind 22 --author "$author_hex" --limit 1000 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No videos found for this channel"
        read -p "Press ENTER to continue..."
        return 0
    fi
    
    # Parse videos into array
    local video_ids=()
    local -A video_data
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        video_ids+=("$event_id")
        video_data["$event_id"]="$event"
    done <<< "$events"
    
    local current_page=0
    local videos_per_page=5
    local total_videos=${#video_ids[@]}
    local total_pages=$(( (total_videos + videos_per_page - 1) / videos_per_page ))
    
    # Video navigation menu
    while true; do
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
            
            # Check metadata completeness
            local gifanim=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "gifanim_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
            local thumbnail=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail_ipfs") | .[1] // empty' 2>/dev/null | head -n1)
            local info=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "info") | .[1] // empty' 2>/dev/null | head -n1)
            
            local status=""
            [[ -n "$gifanim" ]] && status+="✅" || status+="❌"
            [[ -n "$thumbnail" ]] && status+="✅" || status+="❌"
            [[ -n "$info" ]] && status+="✅" || status+="❌"
            
            echo -e "  ${YELLOW}$display_idx.${NC} 📹 $title"
            echo -e "      ⏱️  ${duration}s | 📅 $date | Kind $kind | Status: $status"
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
                    show_video_details "$selected_event_id" "$selected_event" "$author_hex"
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
        echo -e "  ${YELLOW}6.${NC} 🗑️  Delete this video"
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
                    local info_url="${IPFS_GATEWAY}/ipfs/$info"
                    curl -s "$info_url" | jq '.' 2>/dev/null || echo "Failed to fetch info.json"
                    echo ""
                    read -p "Press ENTER to continue..."
                else
                    log_error "No info.json available"
                    sleep 2
                fi
                ;;
            6)
                # Delete video
                echo ""
                read -p "Delete this video permanently? (yes/NO): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    if delete_event_by_id "$event_id" "true"; then
                        log_success "Video deleted!"
                        sleep 2
                        return 0
                    else
                        log_error "Failed to delete video"
                        sleep 2
                    fi
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
                read -p "Enter event ID: " event_id
                if [[ -n "$event_id" ]]; then
                    echo ""
                    read -p "Are you sure you want to delete $event_id? (yes/NO): " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        log_info "Deleting event: ${event_id:0:16}..."
                        # Delete using our helper function
                        if delete_event_by_id "$event_id" "true"; then
                            log_success "Event deleted successfully!"
                        else
                            log_error "Failed to delete event"
                        fi
                    else
                        log_warning "Deletion cancelled"
                    fi
                fi
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
    
    # Determine user hex (not required for list-all and browse)
    USER_HEX=""
    if [[ "$COMMAND" != "list-all" ]] && [[ "$COMMAND" != "browse" ]]; then
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

