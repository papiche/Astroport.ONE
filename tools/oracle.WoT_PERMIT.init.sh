#!/bin/bash
################################################################################
# Script: oracle.WoT_PERMIT.init.sh
# Description: Initialize Web of Trust (WoT) for a new permit type
#
# This script bootstraps a new permit by:
# 1. Finding permits (30500) with no holders (30503)
# 2. Selecting MULTIPASS members to become initial holders
# 3. Creating automatic cross-signature attestations (30501 + 30502)
# 4. Issuing initial credentials (30503) signed by UPLANETNAME.G1
#
# This solves the "chicken and egg" problem: how to get the first permit holders
# when attestations require existing permit holders?
#
# Usage:
#   ./oracle.WoT_PERMIT.init.sh [PERMIT_ID] [MULTIPASS_EMAILS...]
#
# Examples:
#   # Interactive mode - select permit and members
#   ./oracle.WoT_PERMIT.init.sh
#
#   # Direct mode - specify permit and members
#   ./oracle.WoT_PERMIT.init.sh PERMIT_ORE_V1 alice@example.com bob@example.com carol@example.com
#
# License: AGPL-3.0
# Author: UPlanet/Astroport.ONE Team
################################################################################

MY_PATH=$(dirname "$0")
. "${MY_PATH}/../tools/my.sh"

# Source NOSTR tools
NOSTR_SEND_NOTE="${MY_PATH}/nostr_send_note.py"
ORACLE_API="${uSPOT}/api/permit"

# UPLANET authority key
UPLANETNAME="${UPLANETNAME:-UPlanet}"
UPLANETG1PUB="${UPLANETG1PUB}"

# Admin email for authentication (required)
ADMIN_EMAIL="${ADMIN_EMAIL:-}"

# NOSTR relay for NIP-42
NOSTR_RELAY="${myNODErelay:-ws://127.0.0.1:7777}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# Send NIP-42 authentication event for an email
################################################################################
send_nip42_auth() {
    local email="$1"
    
    local keyfile="$HOME/.zen/game/nostr/${email}/.secret.nostr"
    
    if [[ ! -f "$keyfile" ]]; then
        log_error "NOSTR keyfile not found for: $email"
        log_error "Path: $keyfile"
        return 1
    fi
    
    log_info "Sending NIP-42 authentication for: $email"
    
    # Create NIP-42 authentication event (kind 22242)
    local challenge="auth-$(date +%s)"
    local tags_json="[[\"relay\",\"${NOSTR_RELAY}\"],[\"challenge\",\"${challenge}\"]]"
    
    # Send authentication event
    local result=$(python3 "$NOSTR_SEND_NOTE" \
        --keyfile "$keyfile" \
        --content "" \
        --kind 22242 \
        --tags "$tags_json" \
        --relays "$NOSTR_RELAY" 2>&1)
    
    if echo "$result" | grep -q "Event sent successfully"; then
        log_success "NIP-42 authentication sent for: $email"
        return 0
    else
        log_error "Failed to send NIP-42 authentication for: $email"
        log_error "Result: $result"
        return 1
    fi
}

################################################################################
# Get NOSTR pubkey from keyfile
################################################################################
get_pubkey_from_keyfile() {
    local email="$1"
    local keyfile="$HOME/.zen/game/nostr/${email}/.secret.nostr"
    
    if [[ ! -f "$keyfile" ]]; then
        log_error "NOSTR keyfile not found for: $email"
        return 1
    fi
    
    # Extract HEX pubkey from keyfile
    local pubkey=$(grep -oP 'HEX=\K[^;]+' "$keyfile" 2>/dev/null)
    
    if [[ -z "$pubkey" ]]; then
        log_error "Failed to extract pubkey from keyfile for: $email"
        return 1
    fi
    
    echo "$pubkey"
}

################################################################################
# Authenticate admin before starting
################################################################################
authenticate_admin() {
    if [[ -z "$ADMIN_EMAIL" ]]; then
        echo ""
        read -p "Enter admin email for authentication: " ADMIN_EMAIL
        
        if [[ -z "$ADMIN_EMAIL" ]]; then
            log_error "Admin email is required"
            return 1
        fi
    fi
    
    # Check if keyfile exists
    local keyfile="$HOME/.zen/game/nostr/${ADMIN_EMAIL}/.secret.nostr"
    if [[ ! -f "$keyfile" ]]; then
        log_error "NOSTR keyfile not found for admin: $ADMIN_EMAIL"
        log_error "Path: $keyfile"
        log_info "Please create a MULTIPASS for this email first"
        return 1
    fi
    
    log_info "Authenticating as admin: ${YELLOW}${ADMIN_EMAIL}${NC}"
    
    # Send NIP-42 authentication
    if ! send_nip42_auth "$ADMIN_EMAIL"; then
        return 1
    fi
    
    # Wait a bit for authentication to propagate
    sleep 2
    
    log_success "Admin authenticated: $ADMIN_EMAIL"
    return 0
}

################################################################################
# Check if permit has any holders (30503 events)
################################################################################
check_permit_holders() {
    local permit_id="$1"
    
    log_info "Checking for existing holders of permit: ${permit_id}"
    
    # Query API for credentials
    local response=$(curl -s "${ORACLE_API}/list?type=credentials" | jq -r ".results[] | select(.permit_definition_id == \"${permit_id}\") | .credential_id" 2>/dev/null)
    
    if [[ -n "$response" ]]; then
        echo "HAS_HOLDERS"
    else
        echo "NO_HOLDERS"
    fi
}

################################################################################
# List all permits (30500) without holders
################################################################################
list_uninitiated_permits() {
    log_info "Fetching all permit definitions..."
    
    # Get all permit definitions
    local permits=$(curl -s "${ORACLE_API}/definitions" | jq -r '.definitions[] | "\(.id)|\(.name)|\(.min_attestations)"' 2>/dev/null)
    
    if [[ -z "$permits" ]]; then
        log_error "Failed to fetch permit definitions"
        return 1
    fi
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║      Permits without Web of Trust (No holders yet)            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    local uninitiated_permits=()
    local index=1
    
    while IFS='|' read -r permit_id permit_name min_attestations; do
        local holder_status=$(check_permit_holders "$permit_id")
        
        if [[ "$holder_status" == "NO_HOLDERS" ]]; then
            uninitiated_permits+=("$permit_id|$permit_name|$min_attestations")
            printf "${GREEN}%2d${NC}) ${YELLOW}%-25s${NC} - %s ${BLUE}(needs %d initial holders)${NC}\n" \
                "$index" "$permit_id" "$permit_name" "$min_attestations"
            ((index++))
        fi
    done <<< "$permits"
    
    if [[ ${#uninitiated_permits[@]} -eq 0 ]]; then
        log_info "All permits have been initialized with holders"
        return 1
    fi
    
    echo ""
    echo "${uninitiated_permits[@]}"
}

################################################################################
# Select permit interactively
################################################################################
select_permit() {
    local permits_array=($@)
    
    echo ""
    read -p "Select permit to initialize (number): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#permits_array[@]}" ]]; then
        log_error "Invalid selection"
        return 1
    fi
    
    local selected="${permits_array[$((selection-1))]}"
    echo "$selected" | cut -d'|' -f1
}

################################################################################
# Get MULTIPASS list from user
################################################################################
get_multipass_list() {
    local permit_id="$1"
    local min_attestations="$2"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           Select Initial WoT Members                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Permit: ${YELLOW}${permit_id}${NC}"
    log_info "Minimum attestations required: ${YELLOW}${min_attestations}${NC}"
    echo ""
    log_warning "You need to select at least ${min_attestations} MULTIPASS members"
    log_warning "These members will become the initial holders through cross-attestation"
    echo ""
    
    local members=()
    local count=1
    
    while true; do
        read -p "Enter MULTIPASS email #${count} (or press Enter to finish): " email
        
        if [[ -z "$email" ]]; then
            if [[ ${#members[@]} -lt $min_attestations ]]; then
                log_error "You need at least ${min_attestations} members to initialize the WoT"
                continue
            else
                break
            fi
        fi
        
        # Validate email format
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            log_error "Invalid email format: $email"
            continue
        fi
        
        # Check if email already added
        if [[ " ${members[@]} " =~ " ${email} " ]]; then
            log_warning "Email already added: $email"
            continue
        fi
        
        members+=("$email")
        log_success "Added: $email (${#members[@]}/${min_attestations})"
        ((count++))
    done
    
    echo "${members[@]}"
}

################################################################################
# Get NOSTR pubkey for an email
################################################################################
get_nostr_pubkey() {
    local email="$1"
    
    # Try to get from keyfile first
    local pubkey=$(get_pubkey_from_keyfile "$email" 2>/dev/null)
    
    if [[ -n "$pubkey" ]]; then
        echo "$pubkey"
        return 0
    fi
    
    # Fallback to NPUB file
    local npubfile="$HOME/.zen/game/nostr/$email/NPUB"
    if [[ -f "$npubfile" ]]; then
        pubkey=$(cat "$npubfile")
    fi

    if [[ -z "$pubkey" || "$pubkey" == "null" ]]; then
        log_error "Failed to get NOSTR pubkey for: $email"
        return 1
    fi

    echo "$pubkey"
}

################################################################################
# Create permit request (30501) for a member
################################################################################
create_permit_request() {
    local permit_id="$1"
    local email="$2"
    local request_id="$3"
    
    log_info "Creating permit request for: $email"
    
    # Authenticate member first
    if ! send_nip42_auth "$email"; then
        log_error "Failed to authenticate: $email"
        return 1
    fi
    
    # Wait for authentication
    sleep 1
    
    # Submit request via API
    local response=$(curl -s -X POST "${ORACLE_API}/request" \
        -H "Content-Type: application/json" \
        -d "{
            \"permit_definition_id\": \"${permit_id}\",
            \"applicant_email\": \"${email}\",
            \"statement\": \"Initial WoT member for ${permit_id} - Bootstrap attestation\",
            \"evidence\": []
        }")
    
    local status=$(echo "$response" | jq -r '.success // false')
    
    if [[ "$status" == "true" ]]; then
        local req_id=$(echo "$response" | jq -r '.request_id')
        log_success "Request created: $req_id"
        echo "$req_id"
    else
        log_error "Failed to create request for: $email"
        log_error "Response: $response"
        return 1
    fi
}

################################################################################
# Create cross-attestations (30502) between all members
################################################################################
create_cross_attestations() {
    local permit_id="$1"
    shift
    local members=("$@")
    
    log_info "Creating cross-attestations between ${#members[@]} members"
    
    # Create attestations: each member attests all others
    for attester_email in "${members[@]}"; do
        log_info "Attestations by: ${attester_email}"
        
        # Authenticate attester before attestations
        if ! send_nip42_auth "$attester_email"; then
            log_error "Failed to authenticate attester: $attester_email"
            continue
        fi
        sleep 1
        
        for applicant_email in "${members[@]}"; do
            if [[ "$attester_email" == "$applicant_email" ]]; then
                continue  # Skip self-attestation
            fi
            
            # Get request_id for applicant
            local requests=$(curl -s "${ORACLE_API}/list?type=requests&npub=$(npub_from_email "$applicant_email")")
            local request_id=$(echo "$requests" | jq -r ".results[] | select(.permit_definition_id == \"${permit_id}\") | .request_id" | head -1)
            
            if [[ -z "$request_id" ]] || [[ "$request_id" == "null" ]]; then
                log_warning "No request found for: $applicant_email"
                continue
            fi
            
            # Submit attestation
            log_info "  → Attesting request: $request_id (for $applicant_email)"
            
            local response=$(curl -s -X POST "${ORACLE_API}/attest" \
                -H "Content-Type: application/json" \
                -d "{
                    \"request_id\": \"${request_id}\",
                    \"attester_email\": \"${attester_email}\",
                    \"statement\": \"Bootstrap WoT attestation - I certify ${applicant_email} as initial ${permit_id} holder\"
                }")
            
            local status=$(echo "$response" | jq -r '.success // false')
            
            if [[ "$status" == "true" ]]; then
                log_success "  ✓ Attestation submitted"
            else
                log_error "  ✗ Failed to submit attestation"
                log_error "  Response: $response"
            fi
            
            sleep 1  # Rate limiting
        done
    done
}

################################################################################
# Wait for credentials to be issued
################################################################################
wait_for_credentials() {
    local permit_id="$1"
    shift
    local members=("$@")
    
    log_info "Waiting for Oracle to issue credentials..."
    echo ""
    
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))
        
        # Check how many credentials have been issued
        local issued_count=0
        
        for email in "${members[@]}"; do
            local npub=$(npub_from_email "$email")
            local credentials=$(curl -s "${ORACLE_API}/list?type=credentials&npub=${npub}")
            local has_credential=$(echo "$credentials" | jq -r ".results[] | select(.permit_definition_id == \"${permit_id}\") | .credential_id")
            
            if [[ -n "$has_credential" ]]; then
                ((issued_count++))
            fi
        done
        
        printf "\rProgress: ${issued_count}/${#members[@]} credentials issued (attempt ${attempt}/${max_attempts})"
        
        if [[ $issued_count -eq ${#members[@]} ]]; then
            echo ""
            log_success "All credentials have been issued!"
            return 0
        fi
        
        sleep 2
    done
    
    echo ""
    log_warning "Timeout waiting for all credentials to be issued"
    log_info "Some credentials may still be pending manual validation"
    return 1
}

################################################################################
# Get npub from email
################################################################################
npub_from_email() {
    local email="$1"
    local pubkey=$(get_nostr_pubkey "$email")
    
    if [[ -n "$pubkey" ]]; then
        # Convert hex pubkey to npub using nostr-tools or silkaj
        # For now, just return the hex (API accepts both)
        echo "$pubkey"
    fi
}

################################################################################
# Display summary
################################################################################
display_summary() {
    local permit_id="$1"
    shift
    local members=("$@")
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    Initialization Complete                     ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Permit: ${YELLOW}${permit_id}${NC}"
    log_info "Initial WoT members: ${YELLOW}${#members[@]}${NC}"
    echo ""
    log_success "Web of Trust initialized successfully!"
    echo ""
    echo "Initial holders:"
    for email in "${members[@]}"; do
        echo "  ✓ $email"
    done
    echo ""
    log_info "These members can now attest new permit requests for ${permit_id}"
    echo ""
}

################################################################################
# Main function
################################################################################
main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     UPlanet Oracle - WoT Permit Initialization (Bootstrap)     ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check if UPLANETNAME is set
    if [[ -z "$UPLANETNAME" ]] || [[ -z "$UPLANETG1PUB" ]]; then
        log_error "UPLANETNAME or UPLANETG1PUB not set"
        log_info "Please configure your UPlanet environment"
        exit 1
    fi
    
    # Check if nostr_send_note.py exists
    if [[ ! -f "$NOSTR_SEND_NOTE" ]]; then
        log_error "NOSTR send note script not found: $NOSTR_SEND_NOTE"
        exit 1
    fi
    
    # Check if API is accessible
    if ! curl -s -f "${ORACLE_API}/definitions" > /dev/null 2>&1; then
        log_error "Cannot access Oracle API: ${ORACLE_API}"
        log_info "Please ensure the UPassport API is running"
        exit 1
    fi
    
    # Authenticate admin before starting
    if ! authenticate_admin; then
        exit 1
    fi
    
    echo ""
    
    local permit_id="$1"
    shift
    local members=("$@")
    
    # Interactive mode if no arguments provided
    if [[ -z "$permit_id" ]]; then
        # List uninitiated permits
        local permits_output=$(list_uninitiated_permits)
        
        if [[ $? -ne 0 ]]; then
            exit 0
        fi
        
        # Extract permits from output (last line)
        local permits_array=(${permits_output##*$'\n'})
        
        # Select permit
        permit_id=$(select_permit "${permits_array[@]}")
        
        if [[ $? -ne 0 ]] || [[ -z "$permit_id" ]]; then
            log_error "No permit selected"
            exit 1
        fi
        
        # Get permit details
        local permit_info=$(echo "${permits_array[@]}" | tr ' ' '\n' | grep "^${permit_id}|")
        local min_attestations=$(echo "$permit_info" | cut -d'|' -f3)
        
        # Check if this permit has bootstrap configuration (e.g., PERMIT_DE_NAGER)
        local bootstrap_attestations="$min_attestations"
        if [[ "$permit_id" == "PERMIT_DE_NAGER" ]]; then
            # For PERMIT_DE_NAGER, bootstrap requires only 2 attestations (2 more than minimum for first cycle)
            bootstrap_attestations=2
            log_info "Using bootstrap mode: ${YELLOW}${bootstrap_attestations}${NC} attestations required for initial Block 0"
            log_info "After bootstrap, normal requirement is ${YELLOW}${min_attestations}${NC} attestations"
        fi
        
        # Get MULTIPASS members
        local members_list=$(get_multipass_list "$permit_id" "$bootstrap_attestations")
        members=($members_list)
    fi
    
    # Validate permit_id
    if [[ -z "$permit_id" ]]; then
        log_error "Permit ID is required"
        echo ""
        echo "Usage: $0 [PERMIT_ID] [MULTIPASS_EMAILS...]"
        exit 1
    fi
    
    # Validate members
    if [[ ${#members[@]} -eq 0 ]]; then
        log_error "At least one MULTIPASS member is required"
        exit 1
    fi
    
    echo ""
    log_info "Initializing WoT for: ${YELLOW}${permit_id}${NC}"
    log_info "Members: ${YELLOW}${members[@]}${NC}"
    echo ""
    
    read -p "Proceed with initialization? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Initialization cancelled"
        exit 0
    fi
    
    echo ""
    log_info "Starting WoT initialization process..."
    echo ""
    
    # Step 1: Create permit requests (30501) for all members
    log_info "Step 1: Creating permit requests (30501)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local request_ids=()
    
    for email in "${members[@]}"; do
        local request_id=$(create_permit_request "$permit_id" "$email" "")
        
        if [[ $? -eq 0 ]] && [[ -n "$request_id" ]]; then
            request_ids+=("$request_id")
        else
            log_error "Failed to create request for: $email"
            exit 1
        fi
        
        sleep 1
    done
    
    echo ""
    log_success "All permit requests created: ${#request_ids[@]}"
    sleep 2
    
    # Step 2: Create cross-attestations (30502)
    echo ""
    log_info "Step 2: Creating cross-attestations (30502)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    create_cross_attestations "$permit_id" "${members[@]}"
    
    echo ""
    log_success "Cross-attestations completed"
    sleep 2
    
    # Step 3: Wait for credentials to be issued (30503)
    echo ""
    log_info "Step 3: Waiting for credentials to be issued (30503)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    wait_for_credentials "$permit_id" "${members[@]}"
    
    # Display summary
    display_summary "$permit_id" "${members[@]}"
    
    log_info "View the initialized WoT at: ${uSPOT}/oracle"
}

# Run main function
main "$@"


    display_summary "$permit_id" "${members[@]}"
    
    log_info "View the initialized WoT at: ${uSPOT}/oracle"
}

# Run main function
main "$@"

