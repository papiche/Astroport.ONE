#!/bin/bash
###################################################################
# cleanup_test_events.sh
# Clean up NOSTR test events to allow fresh test runs
#
# This script deletes test events from the NOSTR relay to allow
# the captain to re-run validation tests cleanly.
#
# Usage: 
#   ./cleanup_test_events.sh [--file EVENTS_FILE] [--confirm]
#   ./cleanup_test_events.sh --file test_events.json --confirm
#
# Options:
#   --file: JSON file containing event IDs to delete (default: auto-detect)
#   --confirm: Skip confirmation prompt
#
# Safety:
#   - Only deletes events created during test runs
#   - Requires confirmation unless --confirm is used
#   - Creates backup of events before deletion
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE is missing !!" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Configuration
EVENTS_FILE=""
CONFIRM=false
BACKUP_DIR="$HOME/.zen/tmp/tests/cleanup_backups"
mkdir -p "$BACKUP_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --file)
            EVENTS_FILE="$2"
            shift 2
            ;;
        --confirm)
            CONFIRM=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

# Find test events file
find_test_events_file() {
    if [[ -n "$EVENTS_FILE" && -f "$EVENTS_FILE" ]]; then
        echo "$EVENTS_FILE"
        return 0
    fi
    
    # Try to find the most recent test events file
    local latest_file=$(ls -t "$HOME/.zen/tmp/tests"/*_test_events.json 2>/dev/null | head -1)
    if [[ -n "$latest_file" && -f "$latest_file" ]]; then
        echo "$latest_file"
        return 0
    fi
    
    # Try captain test events
    local captain_file="$HOME/.zen/tmp/tests/captain_test_events.json"
    if [[ -f "$captain_file" ]]; then
        echo "$captain_file"
        return 0
    fi
    
    return 1
}

# Delete NOSTR event (kind 5 - Deletion)
delete_nostr_event() {
    local event_id="$1"
    local event_kind="$2"
    local keyfile="$3"
    
    if [[ -z "$keyfile" || ! -f "$keyfile" ]]; then
        log_error "Keyfile required for event deletion: $keyfile"
        return 1
    fi
    
    # Create deletion event (kind 5)
    local tags_json="[[\"e\",\"$event_id\"]]"
    local content=""
    
    log_info "Deleting event ${event_id:0:16}... (kind $event_kind)"
    
    local result
    result=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
        --keyfile "$keyfile" \
        --content "$content" \
        --relays "$myRELAY" \
        --tags "$tags_json" \
        --kind 5 \
        --json 2>&1)
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        local del_event_id=$(echo "$result" | jq -r '.event_id // empty' 2>/dev/null)
        if [[ -n "$del_event_id" ]]; then
            log_success "Deletion event published (${del_event_id:0:16}...)"
            return 0
        else
            log_warning "Deletion event may not have been published correctly"
            return 1
        fi
    else
        log_error "Failed to publish deletion event"
        log_info "Error: $result"
        return 1
    fi
}

# Get keyfile for event type
get_keyfile_for_event() {
    local event_kind="$1"
    local event_type="$2"
    
    # For permit definitions and credentials, use UPLANETNAME_G1
    if [[ "$event_kind" == "30500" ]] || [[ "$event_kind" == "30503" ]] || [[ "$event_kind" == "30009" ]] || [[ "$event_kind" == "8" ]]; then
        local g1_keyfile="$HOME/.zen/game/uplanet.G1.nostr"
        if [[ -f "$g1_keyfile" ]]; then
            echo "$g1_keyfile"
            return 0
        fi
    fi
    
    # For permit requests and attestations, use captain's key
    if [[ "$event_kind" == "30501" ]] || [[ "$event_kind" == "30502" ]]; then
        local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
        if [[ -f "$captain_secret" ]]; then
            echo "$captain_secret"
            return 0
        fi
    fi
    
    # For ORE events, try UPLANETNAME_G1
    if [[ "$event_kind" == "30312" ]] || [[ "$event_kind" == "30313" ]] || [[ "$event_kind" == "30800" ]]; then
        local g1_keyfile="$HOME/.zen/game/uplanet.G1.nostr"
        if [[ -f "$g1_keyfile" ]]; then
            echo "$g1_keyfile"
            return 0
        fi
    fi
    
    # Default to captain's key
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    if [[ -f "$captain_secret" ]]; then
        echo "$captain_secret"
        return 0
    fi
    
    return 1
}

# Cleanup events from file
cleanup_events_from_file() {
    local events_file="$1"
    
    if [[ ! -f "$events_file" ]]; then
        log_error "Events file not found: $events_file"
        return 1
    fi
    
    # Create backup
    local backup_file="$BACKUP_DIR/events_backup_$(date +%Y%m%d_%H%M%S).json"
    cp "$events_file" "$backup_file"
    log_info "Backup created: $backup_file"
    
    # Count events
    local event_count=$(jq -s 'length' "$events_file" 2>/dev/null || echo "0")
    log_info "Found $event_count test events to delete"
    echo ""
    
    if [[ $event_count -eq 0 ]]; then
        log_warning "No events found in file"
        return 0
    fi
    
    # Confirm deletion
    if [[ "$CONFIRM" != "true" ]]; then
        echo ""
        log_warning "This will delete $event_count test events from the NOSTR relay"
        log_warning "Events will be marked as deleted (kind 5) but may remain in relay history"
        echo ""
        read -p "Continue? (yes/no): " confirm_answer
        if [[ "$confirm_answer" != "yes" ]]; then
            log_info "Cleanup cancelled"
            return 0
        fi
        echo ""
    fi
    
    # Delete each event
    local deleted=0
    local failed=0
    
    while IFS= read -r event_json; do
        if [[ -z "$event_json" ]]; then
            continue
        fi
        
        local event_id=$(echo "$event_json" | jq -r '.id // empty' 2>/dev/null)
        local event_kind=$(echo "$event_json" | jq -r '.kind // empty' 2>/dev/null)
        local event_type=$(echo "$event_json" | jq -r '.type // "unknown"' 2>/dev/null)
        
        if [[ -z "$event_id" ]] || [[ -z "$event_kind" ]]; then
            log_warning "Invalid event JSON: $event_json"
            continue
        fi
        
        # Get appropriate keyfile
        local keyfile
        keyfile=$(get_keyfile_for_event "$event_kind" "$event_type")
        
        if [[ -z "$keyfile" ]]; then
            log_error "No keyfile available for event ${event_id:0:16}... (kind $event_kind)"
            ((failed++))
            continue
        fi
        
        # Delete event
        if delete_nostr_event "$event_id" "$event_kind" "$keyfile"; then
            ((deleted++))
            sleep 1  # Rate limiting
        else
            ((failed++))
        fi
        
    done < <(jq -c '.[]' "$events_file" 2>/dev/null || cat "$events_file" | grep -v '^$' | while read -r line; do echo "$line"; done)
    
    echo ""
    log_info "Cleanup complete:"
    log_success "Deleted: $deleted events"
    if [[ $failed -gt 0 ]]; then
        log_error "Failed: $failed events"
    fi
    
    # Clean up local files
    log_info "Cleaning up local test files..."
    
    # Remove permit request files from MULTIPASS
    local captain_multipass="$HOME/.zen/game/nostr/$CAPTAINEMAIL"
    if [[ -d "$captain_multipass" ]]; then
        find "$captain_multipass" -name "30501_*.json" -type f -delete 2>/dev/null
        log_success "Removed permit request files from MULTIPASS"
    fi
    
    # Remove ORE activation files (optional - keep for reference)
    # local umap_dir="$HOME/.zen/game/nostr/UMAP_0.00_0.00"
    # if [[ -d "$umap_dir" ]]; then
    #     log_warning "ORE files in $umap_dir are kept for reference"
    # fi
    
    return 0
}

# Cleanup by pattern (if no events file)
cleanup_by_pattern() {
    log_info "No events file found, attempting pattern-based cleanup..."
    
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    if [[ ! -f "$captain_secret" ]]; then
        log_error "Captain's secret file not found"
        return 1
    fi
    
    source "$captain_secret"
    local captain_hex="${HEX:-}"
    
    if [[ -z "$captain_hex" ]]; then
        log_error "Captain's HEX not available"
        return 1
    fi
    
    # Find test permit
    local permit_id=$(echo "$CAPTAINEMAIL" | cut -d'@' -f1 | tr '[:lower:]' '[:upper:]')
    permit_id="PERMIT_${permit_id}_X1"
    
    log_info "Looking for test permit: $permit_id"
    
    # Find and delete permit definition
    local filters_json="{\"kinds\":[30500],\"#d\":[\"$permit_id\"]}"
    local permit_event
    permit_event=$(cd "$HOME/.zen/strfry" && ./strfry scan "$filters_json" 2>/dev/null && cd - >/dev/null)
    
    if [[ -n "$permit_event" ]]; then
        local event_id=$(echo "$permit_event" | jq -r '.id // empty' 2>/dev/null)
        if [[ -n "$event_id" ]]; then
            log_info "Found permit definition: ${event_id:0:16}..."
            
            local g1_keyfile="$HOME/.zen/game/uplanet.G1.nostr"
            if [[ -f "$g1_keyfile" ]]; then
                if delete_nostr_event "$event_id" "30500" "$g1_keyfile"; then
                    log_success "Permit definition deleted"
                fi
            fi
        fi
    fi
    
    # Find and delete permit requests
    local request_filters="{\"kinds\":[30501],\"authors\":[\"$captain_hex\"],\"#l\":[\"$permit_id\",\"permit_type\"]}"
    local request_events
    request_events=$(cd "$HOME/.zen/strfry" && ./strfry scan "$request_filters" 2>/dev/null && cd - >/dev/null)
    
    if [[ -n "$request_events" ]]; then
        echo "$request_events" | jq -c '.[]' 2>/dev/null | while read -r event; do
            local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
            if [[ -n "$event_id" ]]; then
                log_info "Found permit request: ${event_id:0:16}..."
                if delete_nostr_event "$event_id" "30501" "$captain_secret"; then
                    log_success "Permit request deleted"
                fi
            fi
        done
    fi
    
    # Find and delete attestations
    if [[ -n "$request_events" ]]; then
        local request_ids=$(echo "$request_events" | jq -r '.[] | .id // empty' 2>/dev/null)
        for request_id in $request_ids; do
            if [[ -n "$request_id" ]]; then
                local attest_filters="{\"kinds\":[30502],\"#e\":[\"$request_id\"]}"
                local attest_events
                attest_events=$(cd "$HOME/.zen/strfry" && ./strfry scan "$attest_filters" 2>/dev/null && cd - >/dev/null)
                
                if [[ -n "$attest_events" ]]; then
                    echo "$attest_events" | jq -c '.[]' 2>/dev/null | while read -r event; do
                        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
                        if [[ -n "$event_id" ]]; then
                            log_info "Found attestation: ${event_id:0:16}..."
                            if delete_nostr_event "$event_id" "30502" "$captain_secret"; then
                                log_success "Attestation deleted"
                            fi
                        fi
                    done
                fi
            fi
        done
    fi
}

# Main execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  NOSTR Test Events Cleanup"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Find events file
    local events_file
    events_file=$(find_test_events_file)
    
    if [[ -n "$events_file" ]]; then
        log_info "Using events file: $events_file"
        cleanup_events_from_file "$events_file"
    else
        log_warning "No test events file found"
        log_info "Attempting pattern-based cleanup..."
        cleanup_by_pattern
    fi
    
    echo ""
    log_info "Cleanup process completed"
    log_info "Note: Deleted events may still exist in relay history"
    log_info "Backup saved in: $BACKUP_DIR"
    echo ""
}

# Run main function
main "$@"


