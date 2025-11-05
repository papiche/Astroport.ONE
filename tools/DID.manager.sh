#!/bin/bash
################################################################################
# Script: DID.manager.sh
# Description: Interactive DID Document Manager for UPlanet MULTIPASS & UMAP
# 
# Manages DID documents (kind 30800 events) created by:
# - MULTIPASS (make_NOSTRCARD.sh) - game/nostr/${email}/
# - UMAP (NOSTR.UMAP.refresh.sh) - geographic cells
#
# Uses Nostr as source of truth, local files as cache
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
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

################################################################################
# Configuration
################################################################################
NOSTR_GET_EVENTS="${MY_PATH}/nostr_get_events.sh"
NOSTR_GET_N1="${MY_PATH}/nostr_get_N1.sh"
DID_MANAGER="${MY_PATH}/did_manager_nostr.sh"
DID_EVENT_KIND=30800  # NIP-101 DID events
TEMP_DIR="${HOME}/.zen/tmp/did_official_$$"

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
${CYAN}DID.manager.sh - Interactive DID Document Manager${NC}

${YELLOW}DESCRIPTION:${NC}
    Manage DID documents (kind 30800 events) for MULTIPASS identities and UMAP cells.
    Uses Nostr relays as source of truth, local files as performance cache.

${YELLOW}USAGE:${NC}
    DID.manager.sh COMMAND [OPTIONS]

${YELLOW}COMMANDS:${NC}
    list              List all DID documents for a user
    list-all          List ALL DID documents from all users
    browse            Interactive browser to explore DIDs
    sync              Sync DID from Nostr to local cache
    sync-all          Sync all DIDs for a user
    check             Check DID metadata completeness
    validate          Validate DID document structure
    stats             Show statistics for DID documents
    export            Export DID data to JSON
    show-wallets      Show wallet addresses from DID
    show-follows      Show user's follows (N1 network)

${YELLOW}OPTIONS:${NC}
    -u, --npub NPUB           User's npub key
    -x, --hex HEX             User's hex pubkey
    -e, --email EMAIL         User's email address
    -d, --did DID             Specific DID to display/sync
    -l, --limit N             Limit number of results (default: 100)
    -f, --force               Skip confirmation prompts
    -v, --verbose             Verbose output
    -h, --help                Show this help message

${YELLOW}EXAMPLES:${NC}
    # List ALL DIDs from relay
    DID.manager.sh list-all

    # Browse DIDs interactively
    DID.manager.sh browse

    # List DIDs for specific user
    DID.manager.sh list --email user@example.com

    # Sync DID from Nostr to cache
    DID.manager.sh sync --email user@example.com

    # Check metadata completeness
    DID.manager.sh check --npub npub1abc...

    # Show wallet addresses
    DID.manager.sh show-wallets --hex abc123...

    # Show follows (N1 network)
    DID.manager.sh show-follows --email user@example.com

    # Export all DIDs
    DID.manager.sh export --email user@example.com

${YELLOW}DID DOCUMENT METADATA:${NC}
    - Contract Status (MULTIPASS, SOCIETAIRE, INFRASTRUCTURE, etc.)
    - Storage Quotas
    - Wallet Addresses (MULTIPASS, ZenCard, G1, Bitcoin, Monero)
    - Services (uDRIVE, NextCloud, AI, etc.)
    - France Connect Compliance
    - PlantNet Biodiversity Data
    - ORE (Environmental Obligations)
    - WoT (Web of Trust) Verification

${YELLOW}NOTES:${NC}
    - Requires jq, curl
    - DIDs are cached in ~/.zen/game/nostr/\${email}/did.json.cache
    - Source of truth is Nostr relay (kind 30800 events)
    - Use did_manager_nostr.sh to update DIDs

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
    
    [[ ! -f "$NOSTR_GET_EVENTS" ]] && missing+=("nostr_get_events.sh")
    [[ ! -f "$NOSTR_GET_N1" ]] && missing+=("nostr_get_N1.sh")
    [[ ! -f "$DID_MANAGER" ]] && missing+=("did_manager_nostr.sh")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Convert npub to hex
npub_to_hex() {
    local npub="$1"
    
    # Use nostr2hex.py if available
    if command -v python3 &> /dev/null && [[ -f "${MY_PATH}/nostr2hex.py" ]]; then
        python3 "${MY_PATH}/nostr2hex.py" "$npub" 2>/dev/null && return 0
    fi
    
    # Fallback: assume it's already hex
    echo "$npub"
}

# Find user's hex pubkey from email
find_hex_from_email() {
    local email="$1"
    
    # Check game/nostr directory
    local nostr_dir="${HOME}/.zen/game/nostr/${email}"
    
    if [[ -f "$nostr_dir/HEX" ]]; then
        cat "$nostr_dir/HEX"
        return 0
    fi
    
    # Check .secret.nostr
    if [[ -f "$nostr_dir/.secret.nostr" ]]; then
        grep -oP 'HEX=\K[a-f0-9]{64}' "$nostr_dir/.secret.nostr" 2>/dev/null && return 0
    fi
    
    log_error "Could not find hex pubkey for email: $email"
    return 1
}

# Find email from hex pubkey
find_email_from_hex() {
    local hex="$1"
    
    # Search in game/nostr directories
    for dir in "${HOME}/.zen/game/nostr"/*; do
        [[ ! -d "$dir" ]] && continue
        
        if [[ -f "$dir/HEX" ]]; then
            local stored_hex=$(cat "$dir/HEX")
            if [[ "$stored_hex" == "$hex" ]]; then
                basename "$dir"
                return 0
            fi
        fi
    done
    
    return 1
}

# Extract DID subject from event
extract_did_subject() {
    local event="$1"
    
    # Extract 'd' tag (identifier)
    local did_id=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "d") | .[1] // empty' 2>/dev/null | head -n1)
    
    if [[ -n "$did_id" ]]; then
        echo "$did_id"
    else
        # Fallback: use author pubkey
        echo "$event" | jq -r '.pubkey // empty'
    fi
}

################################################################################
# Command: list-all
################################################################################
cmd_list_all() {
    local limit="${LIMIT:-100}"
    
    log_info "Fetching ALL DID documents from relay..."
    
    local events=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit "$limit" 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No DID documents found on relay"
        return 0
    fi
    
    # Parse and display events
    local count=0
    local -A contract_types
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                     ${YELLOW}All DID Documents (Relay)${NC}                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        count=$((count + 1))
        
        local author=$(echo "$event" | jq -r '.pubkey // "unknown"')
        local created_at=$(echo "$event" | jq -r '.created_at // 0')
        local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
        
        # Extract DID metadata from content (JSON)
        local content=$(echo "$event" | jq -r '.content // "{}"' 2>/dev/null)
        
        # Parse DID document
        local did_id=$(echo "$content" | jq -r '.id // empty' 2>/dev/null)
        local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // "unknown"' 2>/dev/null)
        local storage_quota=$(echo "$content" | jq -r '.metadata.storageQuota // "N/A"' 2>/dev/null)
        local services=$(echo "$content" | jq -r '.metadata.services // "N/A"' 2>/dev/null)
        
        # Track contract types
        contract_types["$contract_status"]=$((${contract_types["$contract_status"]:-0} + 1))
        
        # Find associated email
        local email=$(find_email_from_hex "$author")
        [[ -z "$email" ]] && email="(unknown)"
        
        echo -e "${YELLOW}DID #$count${NC}"
        echo -e "  🆔 DID: ${did_id:0:50}..."
        echo -e "  👤 Author: ${author:0:16}... (${email})"
        echo -e "  📅 Date: $date"
        echo -e "  📋 Event: ${event_id:0:16}..."
        echo -e "  📊 Status: ${CYAN}$contract_status${NC}"
        echo -e "  💾 Quota: $storage_quota"
        echo -e "  🛠️  Services: $services"
        echo ""
        
    done <<< "$events"
    
    # Summary
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Total DIDs: $count${NC}"
    echo ""
    echo -e "${YELLOW}Contract Types:${NC}"
    for type in "${!contract_types[@]}"; do
        echo -e "  📋 $type: ${contract_types[$type]} DID(s)"
    done
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: list
################################################################################
cmd_list() {
    local user_hex="$1"
    local limit="${LIMIT:-100}"
    
    log_info "Fetching DID documents for user: ${user_hex:0:16}..."
    
    local events=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --author "$user_hex" --limit "$limit" 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No DID documents found for this user"
        
        # Check local cache
        local email=$(find_email_from_hex "$user_hex")
        if [[ -n "$email" ]] && [[ -f "${HOME}/.zen/game/nostr/${email}/did.json.cache" ]]; then
            log_info "Found local cache at ~/.zen/game/nostr/${email}/did.json.cache"
            echo ""
            read -p "Display local cache? (y/N): " show_cache
            if [[ "$show_cache" =~ ^[Yy]$ ]]; then
                cat "${HOME}/.zen/game/nostr/${email}/did.json.cache" | jq '.'
            fi
        fi
        
        return 0
    fi
    
    # Parse and display events
    local count=0
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                          ${YELLOW}DID Documents${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        count=$((count + 1))
        
        local created_at=$(echo "$event" | jq -r '.created_at // 0')
        local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        
        # Extract DID metadata
        local content=$(echo "$event" | jq -r '.content // "{}"' 2>/dev/null)
        local did_id=$(echo "$content" | jq -r '.id // empty' 2>/dev/null)
        local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // "unknown"' 2>/dev/null)
        local storage_quota=$(echo "$content" | jq -r '.metadata.storageQuota // "N/A"' 2>/dev/null)
        local services=$(echo "$content" | jq -r '.metadata.services // "N/A"' 2>/dev/null)
        local updated=$(echo "$content" | jq -r '.metadata.updated // empty' 2>/dev/null)
        
        # Wallet addresses
        local g1_multipass=$(echo "$content" | jq -r '.metadata.multipassWallet.g1pub // empty' 2>/dev/null)
        local g1_zencard=$(echo "$content" | jq -r '.metadata.zencardWallet.g1pub // empty' 2>/dev/null)
        
        echo -e "${YELLOW}DID #$count${NC}"
        echo -e "  🆔 ID: ${did_id:0:60}..."
        echo -e "  📅 Created: $date"
        [[ -n "$updated" ]] && echo -e "  🔄 Updated: $updated"
        echo -e "  📋 Event: ${event_id:0:16}..."
        echo -e "  📊 Status: ${CYAN}$contract_status${NC}"
        echo -e "  💾 Quota: $storage_quota"
        echo -e "  🛠️  Services: $services"
        
        if [[ "$VERBOSE" == "true" ]]; then
            [[ -n "$g1_multipass" ]] && echo -e "  💳 MULTIPASS: ${g1_multipass:0:8}..."
            [[ -n "$g1_zencard" ]] && echo -e "  🏦 ZenCard: ${g1_zencard:0:8}..."
        fi
        
        echo ""
        
    done <<< "$events"
    
    # Summary
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Total DIDs: $count${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: show detailed DID
################################################################################
show_did_details() {
    local event="$1"
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                         ${YELLOW}DID Document Details${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local event_id=$(echo "$event" | jq -r '.id // empty')
    local author=$(echo "$event" | jq -r '.pubkey // "unknown"')
    local created_at=$(echo "$event" | jq -r '.created_at // 0')
    local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
    
    # Parse DID content
    local content=$(echo "$event" | jq -r '.content // "{}"' 2>/dev/null)
    
    if ! echo "$content" | jq empty 2>/dev/null; then
        log_error "Invalid JSON content in DID event"
        return 1
    fi
    
    # Extract all fields
    local did_id=$(echo "$content" | jq -r '.id // empty')
    local email=$(find_email_from_hex "$author")
    [[ -z "$email" ]] && email="(unknown)"
    
    # Metadata
    local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // "unknown"')
    local storage_quota=$(echo "$content" | jq -r '.metadata.storageQuota // "N/A"')
    local services=$(echo "$content" | jq -r '.metadata.services // "N/A"')
    local created=$(echo "$content" | jq -r '.metadata.created // empty')
    local updated=$(echo "$content" | jq -r '.metadata.updated // empty')
    
    # Display basic info
    echo -e "${YELLOW}📋 Basic Information${NC}"
    echo -e "  🆔 DID: $did_id"
    echo -e "  👤 Author: ${author:0:16}... ($email)"
    echo -e "  📅 Created: ${created:-$date}"
    [[ -n "$updated" ]] && echo -e "  🔄 Updated: $updated"
    echo -e "  📋 Event ID: $event_id"
    echo ""
    
    # Contract info
    echo -e "${YELLOW}📊 Contract Information${NC}"
    echo -e "  Status: ${CYAN}$contract_status${NC}"
    echo -e "  Quota: $storage_quota"
    echo -e "  Services: $services"
    echo ""
    
    # Wallets
    echo -e "${YELLOW}💰 Wallet Addresses${NC}"
    local g1_multipass=$(echo "$content" | jq -r '.metadata.multipassWallet.g1pub // empty')
    local g1_zencard=$(echo "$content" | jq -r '.metadata.zencardWallet.g1pub // empty')
    local bitcoin=$(echo "$content" | jq -r '.verificationMethod[]? | select(.type == "EcdsaSecp256k1VerificationKey2019" and .controller == "bitcoin") | .publicKeyMultibase // empty' | head -n1)
    local monero=$(echo "$content" | jq -r '.verificationMethod[]? | select(.type == "Curve25519VerificationKey2019" and .controller == "monero") | .publicKeyMultibase // empty' | head -n1)
    
    [[ -n "$g1_multipass" ]] && echo -e "  💳 MULTIPASS (Ẑ revenue): $g1_multipass" || echo -e "  💳 MULTIPASS: ${RED}Not set${NC}"
    [[ -n "$g1_zencard" ]] && echo -e "  🏦 ZenCard (Ẑ society): $g1_zencard" || echo -e "  🏦 ZenCard: ${RED}Not set${NC}"
    [[ -n "$bitcoin" ]] && echo -e "  ₿  Bitcoin: ${bitcoin:0:40}..."
    [[ -n "$monero" ]] && echo -e "  🅼  Monero: ${monero:0:40}..."
    echo ""
    
    # France Connect
    local fc_compliance=$(echo "$content" | jq -r '.metadata.franceConnect.compliance // empty')
    if [[ -n "$fc_compliance" ]]; then
        echo -e "${YELLOW}🇫🇷 France Connect${NC}"
        local fc_status=$(echo "$content" | jq -r '.metadata.franceConnect.kycStatus // "unknown"')
        local fc_level=$(echo "$content" | jq -r '.metadata.franceConnect.verificationLevel // "unknown"')
        
        if [[ "$fc_compliance" == "enabled" ]]; then
            echo -e "  Status: ${GREEN}Enabled${NC} (KYC: $fc_status, Level: $fc_level)"
        else
            echo -e "  Status: ${RED}Disabled${NC} (KYC: $fc_status)"
        fi
        echo ""
    fi
    
    # PlantNet
    local plantnet_count=$(echo "$content" | jq -r '.metadata.plantnetBiodiversity.detections_count // empty')
    if [[ -n "$plantnet_count" ]] && [[ "$plantnet_count" != "0" ]]; then
        echo -e "${YELLOW}🌿 PlantNet Biodiversity${NC}"
        local unique_species=$(echo "$content" | jq -r '.metadata.plantnetBiodiversity.unique_species // 0')
        local avg_confidence=$(echo "$content" | jq -r '.metadata.plantnetBiodiversity.average_confidence // 0')
        echo -e "  Detections: $plantnet_count"
        echo -e "  Unique species: $unique_species"
        echo -e "  Avg confidence: $(echo "$avg_confidence * 100" | bc -l | xargs printf "%.1f")%"
        echo ""
    fi
    
    # ORE System
    local ore_lat=$(echo "$content" | jq -r '.metadata.oreSystem.geographicCell.latitude // empty')
    if [[ -n "$ore_lat" ]]; then
        echo -e "${YELLOW}🌍 ORE System (Environmental Obligations)${NC}"
        local ore_lon=$(echo "$content" | jq -r '.metadata.oreSystem.geographicCell.longitude // empty')
        local ore_status=$(echo "$content" | jq -r '.metadata.oreSystem.environmentalObligations.verification_status // "unknown"')
        echo -e "  Location: ${ore_lat}, ${ore_lon}"
        echo -e "  Verification: $ore_status"
        echo ""
    fi
    
    # Astroport station
    local ipns=$(echo "$content" | jq -r '.metadata.astroportStation.ipns // empty')
    if [[ -n "$ipns" ]]; then
        echo -e "${YELLOW}🏭 Astroport Station${NC}"
        echo -e "  IPNS: $ipns"
        echo ""
    fi
    
    # Show full JSON in verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "${YELLOW}📄 Full DID Document (JSON)${NC}"
        echo ""
        echo "$content" | jq '.'
        echo ""
    fi
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "  ${YELLOW}1.${NC} 🔄 Sync DID from Nostr to cache"
    echo "  ${YELLOW}2.${NC} ✅ Validate DID structure"
    echo "  ${YELLOW}3.${NC} 💾 Export DID to file"
    echo "  ${YELLOW}4.${NC} 📋 Copy DID identifier"
    echo "  ${YELLOW}b.${NC} 🔙 Back"
    echo "  ${YELLOW}0.${NC} 🚪 Exit"
    echo ""
    
    read -p "$(echo -e ${CYAN}Choose action:${NC} )" action
    
    case "$action" in
        1)
            # Sync from Nostr
            local email=$(find_email_from_hex "$author")
            if [[ -n "$email" ]]; then
                log_info "Syncing DID for $email..."
                bash "$DID_MANAGER" sync "$email"
                read -p "Press ENTER to continue..."
            else
                log_error "Cannot find email for this DID"
                sleep 2
            fi
            ;;
        2)
            # Validate
            local temp_file=$(mktemp)
            echo "$content" > "$temp_file"
            log_info "Validating DID structure..."
            bash "$DID_MANAGER" validate "$temp_file"
            rm -f "$temp_file"
            read -p "Press ENTER to continue..."
            ;;
        3)
            # Export
            local export_file="${HOME}/.zen/tmp/did_${author:0:8}_$(date +%Y%m%d_%H%M%S).json"
            echo "$content" | jq '.' > "$export_file"
            log_success "DID exported to: $export_file"
            sleep 2
            ;;
        4)
            # Copy DID
            echo "$did_id" | xclip -selection clipboard 2>/dev/null || echo "$did_id"
            log_success "DID identifier copied"
            sleep 2
            ;;
        b|0)
            return 0
            ;;
        *)
            log_error "Invalid action"
            sleep 1
            ;;
    esac
}

################################################################################
# Command: browse
################################################################################
cmd_browse() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                       ${YELLOW}DID Document Browser${NC}                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "Loading DIDs from relay..."
    
    local events=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit 1000 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No DIDs found on relay"
        read -p "Press ENTER to exit..."
        return 0
    fi
    
    # Build DID list with metadata
    local did_ids=()
    local -A did_data
    local -A did_authors
    local -A did_emails
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        local author=$(echo "$event" | jq -r '.pubkey // "unknown"')
        local email=$(find_email_from_hex "$author")
        [[ -z "$email" ]] && email="(unknown)"
        
        did_ids+=("$event_id")
        did_data["$event_id"]="$event"
        did_authors["$event_id"]="$author"
        did_emails["$event_id"]="$email"
    done <<< "$events"
    
    local current_page=0
    local dids_per_page=5
    local total_dids=${#did_ids[@]}
    local total_pages=$(( (total_dids + dids_per_page - 1) / dids_per_page ))
    
    # DID navigation menu
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                       ${YELLOW}DID Document Browser${NC}                                ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Page $((current_page + 1))/$total_pages${NC} - ${GREEN}$total_dids DIDs${NC} total"
        echo ""
        
        # Display DIDs for current page
        local start_idx=$((current_page * dids_per_page))
        local end_idx=$((start_idx + dids_per_page))
        [[ $end_idx -gt $total_dids ]] && end_idx=$total_dids
        
        local display_idx=1
        for ((i=start_idx; i<end_idx; i++)); do
            local event_id="${did_ids[$i]}"
            local event="${did_data[$event_id]}"
            local author="${did_authors[$event_id]}"
            local email="${did_emails[$event_id]}"
            
            local content=$(echo "$event" | jq -r '.content // "{}"' 2>/dev/null)
            local did_id=$(echo "$content" | jq -r '.id // empty' | sed 's/did:nostr://')
            local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // "unknown"')
            local created_at=$(echo "$event" | jq -r '.created_at // 0')
            local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
            
            echo -e "  ${YELLOW}$display_idx.${NC} 🆔 ${did_id:0:16}..."
            echo -e "      👤 $email | 📊 $contract_status | 📅 $date"
            echo ""
            
            display_idx=$((display_idx + 1))
        done
        
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${YELLOW}1-$dids_per_page.${NC} 🔍 View DID details"
        [[ $current_page -gt 0 ]] && echo -e "  ${YELLOW}p.${NC} ⬅️  Previous page"
        [[ $current_page -lt $((total_pages - 1)) ]] && echo -e "  ${YELLOW}n.${NC} ➡️  Next page"
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
            0)
                clear
                return 0
                ;;
            [1-5])
                local did_idx=$((start_idx + action - 1))
                if [[ $did_idx -ge $start_idx ]] && [[ $did_idx -lt $end_idx ]]; then
                    local selected_event_id="${did_ids[$did_idx]}"
                    local selected_event="${did_data[$selected_event_id]}"
                    show_did_details "$selected_event"
                else
                    log_error "Invalid DID number"
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
# Command: sync
################################################################################
cmd_sync() {
    local user_hex="$1"
    
    local email=$(find_email_from_hex "$user_hex")
    
    if [[ -z "$email" ]]; then
        log_error "Cannot find email for hex: ${user_hex:0:16}..."
        return 1
    fi
    
    log_info "Syncing DID for $email from Nostr to cache..."
    
    bash "$DID_MANAGER" sync "$email"
}

################################################################################
# Command: check
################################################################################
cmd_check() {
    local user_hex="$1"
    
    local email=$(find_email_from_hex "$user_hex")
    
    if [[ -z "$email" ]]; then
        log_error "Cannot find email for hex: ${user_hex:0:16}..."
        return 1
    fi
    
    log_info "Checking DID metadata for $email..."
    
    local did_cache="${HOME}/.zen/game/nostr/${email}/did.json.cache"
    
    if [[ ! -f "$did_cache" ]]; then
        log_warning "No local cache found, syncing from Nostr..."
        bash "$DID_MANAGER" sync "$email"
    fi
    
    if [[ -f "$did_cache" ]]; then
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                      ${YELLOW}DID Metadata Check${NC}                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Check required fields
        local required_fields=("id" "verificationMethod" "metadata")
        local missing_fields=()
        
        for field in "${required_fields[@]}"; do
            if ! jq -e ".$field" "$did_cache" >/dev/null 2>&1; then
                missing_fields+=("$field")
            fi
        done
        
        if [[ ${#missing_fields[@]} -gt 0 ]]; then
            log_error "Missing required fields: ${missing_fields[*]}"
        else
            log_success "All required fields present"
        fi
        
        # Check metadata completeness
        echo ""
        echo -e "${YELLOW}Metadata Completeness:${NC}"
        
        local contract_status=$(jq -r '.metadata.contractStatus // empty' "$did_cache")
        [[ -n "$contract_status" ]] && echo -e "  ✅ Contract Status: $contract_status" || echo -e "  ❌ Contract Status: ${RED}Missing${NC}"
        
        local multipass_wallet=$(jq -r '.metadata.multipassWallet.g1pub // empty' "$did_cache")
        [[ -n "$multipass_wallet" ]] && echo -e "  ✅ MULTIPASS Wallet: ${multipass_wallet:0:8}..." || echo -e "  ❌ MULTIPASS Wallet: ${RED}Missing${NC}"
        
        local zencard_wallet=$(jq -r '.metadata.zencardWallet.g1pub // empty' "$did_cache")
        [[ -n "$zencard_wallet" ]] && echo -e "  ✅ ZenCard Wallet: ${zencard_wallet:0:8}..." || echo -e "  ⚠️  ZenCard Wallet: ${YELLOW}Optional${NC}"
        
        local astroport=$(jq -r '.metadata.astroportStation.ipns // empty' "$did_cache")
        [[ -n "$astroport" ]] && echo -e "  ✅ Astroport Station: ${astroport:0:16}..." || echo -e "  ❌ Astroport Station: ${RED}Missing${NC}"
        
        local fc_compliance=$(jq -r '.metadata.franceConnect.compliance // empty' "$did_cache")
        if [[ "$fc_compliance" == "enabled" ]]; then
            echo -e "  ✅ France Connect: ${GREEN}Enabled${NC}"
        else
            echo -e "  ⚠️  France Connect: ${YELLOW}Disabled${NC}"
        fi
        
        echo ""
        bash "$DID_MANAGER" validate "$did_cache"
    else
        log_error "Failed to get DID cache for $email"
        return 1
    fi
}

################################################################################
# Command: stats
################################################################################
cmd_stats() {
    local limit="${LIMIT:-1000}"
    
    log_info "Generating DID statistics..."
    
    local events=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit "$limit" 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No DIDs found"
        return 0
    fi
    
    # Statistics
    local total=0
    local -A contract_types
    local with_multipass=0
    local with_zencard=0
    local with_astroport=0
    local fc_enabled=0
    local plantnet_users=0
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        total=$((total + 1))
        
        local content=$(echo "$event" | jq -r '.content // "{}"' 2>/dev/null)
        
        local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // "unknown"')
        contract_types["$contract_status"]=$((${contract_types["$contract_status"]:-0} + 1))
        
        local multipass=$(echo "$content" | jq -r '.metadata.multipassWallet.g1pub // empty')
        [[ -n "$multipass" ]] && with_multipass=$((with_multipass + 1))
        
        local zencard=$(echo "$content" | jq -r '.metadata.zencardWallet.g1pub // empty')
        [[ -n "$zencard" ]] && with_zencard=$((with_zencard + 1))
        
        local astroport=$(echo "$content" | jq -r '.metadata.astroportStation.ipns // empty')
        [[ -n "$astroport" ]] && with_astroport=$((with_astroport + 1))
        
        local fc=$(echo "$content" | jq -r '.metadata.franceConnect.compliance // empty')
        [[ "$fc" == "enabled" ]] && fc_enabled=$((fc_enabled + 1))
        
        local plantnet=$(echo "$content" | jq -r '.metadata.plantnetBiodiversity.detections_count // "0"')
        [[ "$plantnet" != "0" ]] && plantnet_users=$((plantnet_users + 1))
        
    done <<< "$events"
    
    # Display stats
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                          ${YELLOW}DID Statistics${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📊 Total DIDs${NC}"
    echo -e "  $total DID documents"
    echo ""
    echo -e "${YELLOW}📋 Contract Types${NC}"
    for type in "${!contract_types[@]}"; do
        local count=${contract_types[$type]}
        local percent=$(( (count * 100) / total ))
        echo -e "  $type: $count ($percent%)"
    done
    echo ""
    echo -e "${YELLOW}💰 Wallet Distribution${NC}"
    echo -e "  MULTIPASS wallets: $with_multipass/$total ($(( (with_multipass * 100) / total ))%)"
    echo -e "  ZenCard wallets: $with_zencard/$total ($(( (with_zencard * 100) / total ))%)"
    echo ""
    echo -e "${YELLOW}🏭 Infrastructure${NC}"
    echo -e "  Astroport Stations: $with_astroport/$total ($(( (with_astroport * 100) / total ))%)"
    echo ""
    echo -e "${YELLOW}🇫🇷 France Connect${NC}"
    echo -e "  Enabled: $fc_enabled/$total ($(( (fc_enabled * 100) / total ))%)"
    echo ""
    echo -e "${YELLOW}🌿 PlantNet${NC}"
    echo -e "  Active users: $plantnet_users/$total ($(( (plantnet_users * 100) / total ))%)"
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: show-wallets
################################################################################
cmd_show_wallets() {
    local user_hex="$1"
    
    local email=$(find_email_from_hex "$user_hex")
    
    if [[ -z "$email" ]]; then
        log_error "Cannot find email for hex: ${user_hex:0:16}..."
        return 1
    fi
    
    bash "$DID_MANAGER" show-wallets "$email"
}

################################################################################
# Command: show-follows
################################################################################
cmd_show_follows() {
    local user_hex="$1"
    
    log_info "Fetching follows (N1 network) for ${user_hex:0:16}..."
    
    local follows=$(bash "$NOSTR_GET_N1" "$user_hex" 2>/dev/null)
    
    if [[ -z "$follows" ]]; then
        log_warning "No follows found (or strfry not available)"
        return 0
    fi
    
    local count=0
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                       ${YELLOW}N1 Network (Follows)${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while IFS= read -r follow_hex; do
        [[ -z "$follow_hex" ]] && continue
        
        count=$((count + 1))
        
        local follow_email=$(find_email_from_hex "$follow_hex")
        [[ -z "$follow_email" ]] && follow_email="(unknown)"
        
        echo -e "${YELLOW}Follow #$count${NC}"
        echo -e "  👤 Hex: ${follow_hex:0:16}..."
        echo -e "  📧 Email: $follow_email"
        echo ""
        
    done <<< "$follows"
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Total follows: $count${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Command: export
################################################################################
cmd_export() {
    local user_hex="$1"
    
    local email=$(find_email_from_hex "$user_hex")
    
    if [[ -z "$email" ]]; then
        log_error "Cannot find email for hex: ${user_hex:0:16}..."
        return 1
    fi
    
    local export_file="${HOME}/.zen/tmp/did_${email//@/_}_$(date +%Y%m%d_%H%M%S).json"
    
    log_info "Exporting DID data to: $export_file"
    
    # Get from relay
    bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --author "$user_hex" --limit 1000 2>/dev/null > "$export_file"
    
    if [[ -s "$export_file" ]]; then
        log_success "Export complete!"
        echo "  File: $export_file"
        
        # Also save local cache if exists
        local did_cache="${HOME}/.zen/game/nostr/${email}/did.json.cache"
        if [[ -f "$did_cache" ]]; then
            local cache_file="${export_file%.json}.cache.json"
            cp "$did_cache" "$cache_file"
            log_success "Cache also exported: $cache_file"
        fi
    else
        log_error "Export failed"
        return 1
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
    DID=""
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
            -d|--did)
                DID="$2"
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
    
    # Determine user hex (not required for list-all, browse, stats)
    USER_HEX=""
    if [[ "$COMMAND" != "list-all" ]] && [[ "$COMMAND" != "browse" ]] && [[ "$COMMAND" != "stats" ]]; then
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
            cmd_list_all
            ;;
        browse)
            cmd_browse
            ;;
        list)
            cmd_list "$USER_HEX"
            ;;
        sync)
            cmd_sync "$USER_HEX"
            ;;
        check)
            cmd_check "$USER_HEX"
            ;;
        stats)
            cmd_stats
            ;;
        show-wallets)
            cmd_show_wallets "$USER_HEX"
            ;;
        show-follows)
            cmd_show_follows "$USER_HEX"
            ;;
        export)
            cmd_export "$USER_HEX"
            ;;
        validate)
            if [[ -z "$DID" ]]; then
                log_error "Must provide --did FILE for validate command"
                exit 1
            fi
            bash "$DID_MANAGER" validate "$DID"
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            ;;
    esac
}

# Trap cleanup
trap "rm -rf $TEMP_DIR" EXIT

# Create temp dir
mkdir -p "$TEMP_DIR"

# Run main
main "$@"

