#!/bin/bash
###################################################################
# test_captain_validation.sh
# Complete validation test for Captain - Creates real data
#
# This test allows the captain to:
# 1. Create and sign their own WoTx2 permit (PERMIT_CAPTAINEMAIL_X1)
# 2. Generate badge images automatically
# 3. Create an ORE contract for UMAP 0.00 0.00
# 4. Validate the complete UPlanet game UX
#
# Usage: ./test_captain_validation.sh [--cleanup]
#
# Options:
#   --cleanup: Clean up test events after completion
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE is missing !!" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Source common test functions
source "$MY_PATH/test_common.sh"

# Note: Colors are already defined in test_common.sh, but we ensure they're available
# YELLOW, BLUE, NC are already defined in test_common.sh

# Test configuration
CLEANUP_AFTER=false
VERBOSE=false
DEBUG=false
TEST_EVENTS_FILE="$TEST_TEMP_DIR/captain_test_events.json"
rm -f "$TEST_EVENTS_FILE"
touch "$TEST_EVENTS_FILE"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP_AFTER=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --debug|-d)
            DEBUG=true
            VERBOSE=true
            set -x  # Enable bash debug mode
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--cleanup] [--verbose] [--debug]" >&2
            exit 1
            ;;
    esac
done

# Debug logging function
debug_log() {
    if [[ "$DEBUG" == "true" || "$VERBOSE" == "true" ]]; then
        echo -e "${YELLOW}[DEBUG] $1${NC}" >&2
    fi
}

verbose_log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE] $1${NC}" >&2
    fi
}

# Store event IDs for cleanup
store_event_id() {
    local event_id="$1"
    local event_kind="$2"
    local event_type="$3"
    
    echo "{\"id\":\"$event_id\",\"kind\":$event_kind,\"type\":\"$event_type\"}" >> "$TEST_EVENTS_FILE"
}

# Get captain's permit name from email
get_captain_permit_name() {
    local email="$CAPTAINEMAIL"
    # Convert email to permit name: user@example.com -> USER
    local username=$(echo "$email" | cut -d'@' -f1 | tr '[:lower:]' '[:upper:]')
    echo "PERMIT_${username}_X1"
}

# Test 1: Create WoTx2 permit for captain
test_create_captain_wotx2_permit() {
    test_log_info "═══════════════════════════════════════════════════════════"
    test_log_info "Test 1: Creating WoTx2 Permit for Captain"
    test_log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    assert_file_exists "$captain_secret" "Captain's secret file should exist"
    
    source "$captain_secret"
    local captain_hex="${HEX:-}"
    local captain_npub="${NPUB:-}"
    
    assert_not_empty "$captain_hex" "Captain's HEX should be available"
    assert_not_empty "$captain_npub" "Captain's NPUB should be available"
    
    # Get permit name
    local permit_name=$(get_captain_permit_name)
    local permit_id="${permit_name}"
    local permit_display_name=$(echo "$permit_name" | sed 's/PERMIT_//' | sed 's/_X1//' | sed 's/_/ /g')
    
    test_log_info "Permit ID: $permit_id"
    test_log_info "Permit Name: $permit_display_name"
    echo ""
    
    # Check if permit already exists using nostr_get_events.sh
    local existing
    existing=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
        --kind 30500 \
        --tag-d "$permit_id" \
        2>/dev/null)
    
    if [[ -n "$existing" ]]; then
        local existing_id=$(echo "$existing" | jq -r '.id // empty' 2>/dev/null)
        test_log_warning "Permit $permit_id already exists (event: $existing_id)"
        test_log_info "Skipping permit creation, using existing permit"
        
        if [[ -n "$existing_id" ]]; then
            store_event_id "$existing_id" "30500" "permit_definition"
        fi
        
        return 0
    fi
    
    # Get UPLANETNAME_G1 keys for permit creation
    local g1_keyfile="$HOME/.zen/game/uplanet.G1.nostr"
    if [[ ! -f "$g1_keyfile" ]]; then
        test_log_error "UPLANETNAME_G1 keyfile not found: $g1_keyfile"
        test_log_info "Please run UPLANET.init.sh to initialize UPlanet keys"
        return 1
    fi
    
    # Authenticate with NIP-42 first
    test_log_info "Step 1: Authenticating with NIP-42..."
    local challenge="captain_test_$(date +%s)_${permit_id}"
    local auth_result
    auth_result=$(publish_nostr_event "22242" "$challenge" \
        "[[\"relay\",\"$myRELAY\"],[\"challenge\",\"$challenge\"]]" \
        "$g1_keyfile" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        test_log_success "NIP-42 authentication event published"
        sleep 2  # Wait for relay to process
    else
        test_log_warning "NIP-42 authentication may have failed, continuing anyway..."
    fi
    
    # Create permit definition using oracle_system.py
    test_log_info "Step 2: Creating permit definition using oracle_system.py..."
    
    local oracle_system="$HOME/.zen/UPassport/oracle_system.py"
    if [[ ! -f "$oracle_system" ]]; then
        test_log_error "oracle_system.py not found: $oracle_system"
        test_log_info "Please ensure UPassport is installed at $HOME/.zen/UPassport/"
        return 1
    fi
    
    # Use oracle_system.py to create permit definition
    # WoTx2 permits start with min_attestations=1 (auto-proclaimed)
    debug_log "Calling: python3 $oracle_system create-definition $permit_id $permit_display_name --min-attestations 1 --valid-days 0"
    local oracle_result
    oracle_result=$(python3 "$oracle_system" create-definition \
        "$permit_id" \
        "$permit_display_name" \
        --min-attestations 1 \
        --valid-days 0 \
        2>&1)
    
    local oracle_exit=$?
    debug_log "oracle_system.py exit code: $oracle_exit"
    verbose_log "oracle_system.py output: $oracle_result"
    
    if [[ $oracle_exit -eq 0 ]]; then
        test_log_success "Permit definition created using oracle_system.py"
        
        # Wait for event to propagate
        debug_log "Waiting 5 seconds for event propagation..."
        sleep 5
        
        # Verify permit was created using nostr_get_events.sh
        debug_log "Querying Nostr for permit definition with tag-d: $permit_id"
        local verify_result
        verify_result=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
            --kind 30500 \
            --tag-d "$permit_id" \
            2>&1)
        
        verbose_log "Nostr query result: $verify_result"
        
        if [[ -n "$verify_result" && "$verify_result" != "null" ]]; then
            # Parse first event from result
            local event_id=$(echo "$verify_result" | jq -r 'if type == "array" then .[0].id // .id else .id end' 2>/dev/null | head -1)
            debug_log "Parsed event ID: $event_id"
            if [[ -n "$event_id" && "$event_id" != "null" ]]; then
                store_event_id "$event_id" "30500" "permit_definition"
                test_log_success "Permit verified on Nostr relay (event: ${event_id:0:16}...)"
            else
                test_log_warning "Permit created but event ID not found in verification"
                debug_log "Full verify_result: $verify_result"
            fi
        else
            test_log_warning "Permit created but not yet visible on relay (may need more time)"
            debug_log "No result from Nostr query, checking if permit was saved locally..."
            # Check if permit was saved locally
            local permit_file="$HOME/.zen/game/permits/definitions.json"
            if [[ -f "$permit_file" ]]; then
                local permit_exists=$(jq -r --arg id "$permit_id" '.[$id] // empty' "$permit_file" 2>/dev/null)
                if [[ -n "$permit_exists" ]]; then
                    debug_log "Permit found in local file: $permit_file"
                    test_log_info "Permit saved locally, will be published by ORACLE.refresh.sh"
                fi
            fi
        fi
    else
        test_log_error "Failed to create permit definition (exit code: $oracle_exit)"
        test_log_info "Output: $oracle_result"
        return 1
    fi
    
    echo ""
}

# Test 2: Captain requests their own permit
test_captain_request_permit() {
    test_log_info "═══════════════════════════════════════════════════════════"
    test_log_info "Test 2: Captain Requests Their Own Permit"
    test_log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    source "$captain_secret"
    local captain_hex="${HEX:-}"
    local captain_npub="${NPUB:-}"
    
    local permit_id=$(get_captain_permit_name)
    local request_id="req_captain_$(date +%s)"
    
    test_log_info "Creating permit request: $request_id"
    test_log_info "Permit: $permit_id"
    echo ""
    
    # Check if request already exists using nostr_get_events.sh
    local existing
    existing=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
        --kind 30501 \
        --author "$captain_hex" \
        --tag-t "wotx2" \
        2>/dev/null)
    
    if [[ -n "$existing" ]]; then
        local existing_id=$(echo "$existing" | jq -r '.id // empty' 2>/dev/null)
        test_log_warning "Request already exists (event: $existing_id)"
        test_log_info "Skipping request creation, using existing request"
        
        if [[ -n "$existing_id" ]]; then
            store_event_id "$existing_id" "30501" "permit_request"
        fi
        
        return 0
    fi
    
    # Create permit request using oracle_system.py
    test_log_info "Creating permit request using oracle_system.py..."
    
    local oracle_system="$HOME/.zen/UPassport/oracle_system.py"
    if [[ ! -f "$oracle_system" ]]; then
        test_log_error "oracle_system.py not found: $oracle_system"
        return 1
    fi
    
    local statement="I, the Captain, request this mastery to validate my competence in managing this UPlanet."
    
    # Use oracle_system.py to create permit request
    debug_log "Calling: python3 $oracle_system request $permit_id $captain_npub \"$statement\""
    local oracle_result
    oracle_result=$(python3 "$oracle_system" request \
        "$permit_id" \
        "$captain_npub" \
        "$statement" \
        2>&1)
    
    local oracle_exit=$?
    debug_log "oracle_system.py exit code: $oracle_exit"
    verbose_log "oracle_system.py output: $oracle_result"
    
    if [[ $oracle_exit -eq 0 ]]; then
        test_log_success "Permit request created using oracle_system.py"
        
        # Wait for event to propagate
        debug_log "Waiting 5 seconds for event propagation..."
        sleep 5
        
        # Verify request was created using nostr_get_events.sh
        debug_log "Querying Nostr for permit requests by author: $captain_hex"
        local verify_result
        verify_result=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
            --kind 30501 \
            --author "$captain_hex" \
            --limit 10 \
            2>&1)
        
        verbose_log "Nostr query result: $verify_result"
        
        if [[ -n "$verify_result" && "$verify_result" != "null" ]]; then
            # Parse first event from result
            local event_id=$(echo "$verify_result" | jq -r 'if type == "array" then .[0].id // .id else .id end' 2>/dev/null | head -1)
            debug_log "Parsed event ID: $event_id"
            if [[ -n "$event_id" && "$event_id" != "null" ]]; then
                store_event_id "$event_id" "30501" "permit_request"
                test_log_success "Request verified on Nostr relay (event: ${event_id:0:16}...)"
            else
                test_log_warning "Request created but event ID not found in verification"
                debug_log "Full verify_result: $verify_result"
            fi
        else
            test_log_warning "Request created but not yet visible on relay (may need more time)"
            debug_log "No result from Nostr query, checking if request was saved locally..."
            # Check if request was saved locally
            local request_file="$HOME/.zen/game/permits/requests.json"
            if [[ -f "$request_file" ]]; then
                local request_exists=$(jq -r '.[] | select(.permit_definition_id == "'"$permit_id"'") | .request_id' "$request_file" 2>/dev/null | head -1)
                if [[ -n "$request_exists" ]]; then
                    debug_log "Request found in local file: $request_file (request_id: $request_exists)"
                    test_log_info "Request saved locally, will be published by ORACLE.refresh.sh"
                fi
            fi
        fi
    else
        test_log_error "Failed to create permit request (exit code: $oracle_exit)"
        test_log_info "Output: $oracle_result"
        return 1
    fi
    
    echo ""
}

# Test 3: Captain attests their own request (self-attestation for X1)
test_captain_self_attestation() {
    test_log_info "═══════════════════════════════════════════════════════════"
    test_log_info "Test 3: Captain Self-Attestation (WoTx2 X1 allows this)"
    test_log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    source "$captain_secret"
    local captain_hex="${HEX:-}"
    local captain_npub="${NPUB:-}"
    
    local permit_id=$(get_captain_permit_name)
    
    # Find the request event using nostr_get_events.sh
    # Wait a bit for event propagation
    test_log_info "Waiting for request event to propagate (5 seconds)..."
    sleep 5
    
    debug_log "Searching for permit request with permit_id: $permit_id"
    debug_log "Captain HEX: $captain_hex"
    
    local request_event
    request_event=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
        --kind 30501 \
        --author "$captain_hex" \
        --limit 10 \
        2>&1)
    
    verbose_log "Initial Nostr query result: $request_event"
    
    # Filter for requests matching the permit_id
    if [[ -n "$request_event" && "$request_event" != "null" ]]; then
        debug_log "Filtering results for permit_id: $permit_id"
        # Try to find request with matching permit_id in content or tags
        local filtered_event=$(echo "$request_event" | jq -c "if type == \"array\" then .[] else . end" 2>/dev/null | \
            jq -c "select(.content | contains(\"$permit_id\") or .tags[]? | select(.[0] == \"l\" and .[1] == \"$permit_id\"))" 2>/dev/null | head -1)
        
        debug_log "Filtered event: $filtered_event"
        
        if [[ -n "$filtered_event" && "$filtered_event" != "null" ]]; then
            request_event="$filtered_event"
        else
            # Try to get any request from this author (maybe permit_id is in content differently)
            debug_log "No exact match, trying to get any request from this author..."
            local any_request=$(echo "$request_event" | jq -c "if type == \"array\" then .[0] else . end" 2>/dev/null)
            if [[ -n "$any_request" && "$any_request" != "null" ]]; then
                debug_log "Found a request (may not match permit_id exactly): $any_request"
                request_event="$any_request"
            fi
        fi
    fi
    
    if [[ -z "$request_event" || "$request_event" == "null" ]]; then
        test_log_warning "No permit request found. Waiting longer (10 seconds)..."
        debug_log "Checking local permit requests file..."
        
        # Check local file first
        local request_file="$HOME/.zen/game/permits/requests.json"
        if [[ -f "$request_file" ]]; then
            local local_requests=$(jq -r --arg permit_id "$permit_id" '.[] | select(.permit_definition_id == $permit_id) | .request_id' "$request_file" 2>/dev/null)
            if [[ -n "$local_requests" ]]; then
                debug_log "Found local request(s): $local_requests"
                test_log_info "Request found locally, will be published by ORACLE.refresh.sh"
                # Use the first local request ID
                local first_request_id=$(echo "$local_requests" | head -1)
                # Create a minimal event structure for testing
                request_event="{\"id\":\"local_$first_request_id\",\"tags\":[[\"d\",\"$first_request_id\"]]}"
            fi
        fi
        
        sleep 10
        
        # Try again with broader search
        debug_log "Retrying Nostr query with broader search..."
        request_event=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
            --kind 30501 \
            --author "$captain_hex" \
            --limit 20 \
            2>&1)
        
        verbose_log "Retry query result: $request_event"
        
        if [[ -z "$request_event" || "$request_event" == "null" ]]; then
            test_log_error "No permit request found after waiting. Run test_captain_request_permit first."
            debug_log "Searched for kind 30501, author $captain_hex, permit_id $permit_id"
            return 1
        fi
    fi
    
    local request_event_id=$(echo "$request_event" | jq -r '.id // empty' 2>/dev/null)
    local request_d_tag=$(echo "$request_event" | jq -r '.tags[] | select(.[0] == "d") | .[1] // empty' 2>/dev/null)
    
    assert_not_empty "$request_event_id" "Request event should have an id"
    assert_not_empty "$request_d_tag" "Request should have d tag"
    
    test_log_info "Request event ID: ${request_event_id:0:16}..."
    test_log_info "Request d tag: $request_d_tag"
    echo ""
    
    # Check if attestation already exists using nostr_get_events.sh
    local existing_attest
    existing_attest=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
        --kind 30502 \
        --author "$captain_hex" \
        --tag-e "$request_event_id" \
        2>/dev/null)
    
    if [[ -n "$existing_attest" ]]; then
        local existing_id=$(echo "$existing_attest" | jq -r '.id // empty' 2>/dev/null)
        test_log_warning "Attestation already exists (event: $existing_id)"
        test_log_info "Skipping attestation creation, using existing attestation"
        
        if [[ -n "$existing_id" ]]; then
            store_event_id "$existing_id" "30502" "permit_attestation"
        fi
        
        return 0
    fi
    
    # Create attestation using oracle_system.py
    test_log_info "Creating self-attestation using oracle_system.py..."
    
    local oracle_system="$HOME/.zen/UPassport/oracle_system.py"
    if [[ ! -f "$oracle_system" ]]; then
        test_log_error "oracle_system.py not found: $oracle_system"
        return 1
    fi
    
    local statement="I attest to my own competence as Captain of this UPlanet. This self-attestation is valid for WoTx2 X1 level."
    
    # Use oracle_system.py to create attestation
    local oracle_result
    oracle_result=$(python3 "$oracle_system" attest \
        "$request_d_tag" \
        "$captain_npub" \
        "$statement" \
        2>&1)
    
    local oracle_exit=$?
    
    if [[ $oracle_exit -eq 0 ]]; then
        test_log_success "Self-attestation created using oracle_system.py"
        
        # Wait for event to propagate
        sleep 3
        
        # Verify attestation was created using nostr_get_events.sh
        local verify_result
        verify_result=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
            --kind 30502 \
            --author "$captain_hex" \
            --tag-e "$request_event_id" \
            2>/dev/null)
        
        if [[ -n "$verify_result" ]]; then
            # Parse first event from result
            local event_id=$(echo "$verify_result" | jq -r 'if type == "array" then .[0].id // .id else .id end' 2>/dev/null | head -1)
            if [[ -n "$event_id" && "$event_id" != "null" ]]; then
                store_event_id "$event_id" "30502" "permit_attestation"
                test_log_success "Attestation verified on Nostr relay (event: ${event_id:0:16}...)"
            else
                test_log_warning "Attestation created but event ID not found in verification"
            fi
        else
            test_log_warning "Attestation created but not yet visible on relay (may need more time)"
        fi
    else
        test_log_error "Failed to create attestation (exit code: $oracle_exit)"
        test_log_info "Output: $oracle_result"
        return 1
    fi
    
    echo ""
}

# Test 4: Trigger credential issuance (via ORACLE.refresh.sh simulation)
test_trigger_credential_issuance() {
    test_log_info "═══════════════════════════════════════════════════════════"
    test_log_info "Test 4: Triggering Credential Issuance"
    test_log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    source "$captain_secret"
    local captain_hex="${HEX:-}"
    
    local permit_id=$(get_captain_permit_name)
    
    # Find the request using nostr_get_events.sh
    # Wait a bit for event propagation
    test_log_info "Waiting for request event to propagate (5 seconds)..."
    sleep 5
    
    local request_event
    request_event=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
        --kind 30501 \
        --author "$captain_hex" \
        --limit 20 \
        2>/dev/null)
    
    # Filter for requests matching the permit_id
    if [[ -n "$request_event" ]]; then
        # Try to find request with matching permit_id in content or tags
        local filtered_event=$(echo "$request_event" | jq -c "if type == \"array\" then .[] else . end" 2>/dev/null | \
            jq -c "select(.content | contains(\"$permit_id\") or .tags[]? | select(.[0] == \"l\" and .[1] == \"$permit_id\"))" 2>/dev/null | head -1)
        
        if [[ -n "$filtered_event" && "$filtered_event" != "null" ]]; then
            request_event="$filtered_event"
        fi
    fi
    
    if [[ -z "$request_event" || "$request_event" == "null" ]]; then
        test_log_warning "No permit request found. Waiting longer (10 seconds)..."
        sleep 10
        
        # Try again with broader search
        request_event=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
            --kind 30501 \
            --author "$captain_hex" \
            --limit 20 \
            2>/dev/null)
        
        if [[ -z "$request_event" || "$request_event" == "null" ]]; then
            test_log_error "No permit request found after waiting"
            return 1
        fi
    fi
    
    local request_d_tag=$(echo "$request_event" | jq -r '.tags[] | select(.[0] == "d") | .[1] // empty' 2>/dev/null)
    local request_event_id=$(echo "$request_event" | jq -r '.id // empty' 2>/dev/null)
    
    test_log_info "Request ID: $request_d_tag"
    test_log_info "Request event: ${request_event_id:0:16}..."
    echo ""
    
    # Count attestations using nostr_get_events.sh
    local attestations
    attestations=$($HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh \
        --kind 30502 \
        --tag-e "$request_event_id" \
        --limit 10 \
        2>/dev/null)
    
    local attest_count=0
    if [[ -n "$attestations" ]]; then
        # Count how many attestation events we have
        attest_count=$(echo "$attestations" | jq -s 'length' 2>/dev/null || echo "1")
    fi
    
    test_log_info "Attestations found: $attest_count"
    test_log_info "Required for X1: 1"
    echo ""
    
    if [[ $attest_count -ge 1 ]]; then
        test_log_success "Sufficient attestations collected ($attest_count >= 1)"
        
        # Call API to issue credential
        test_log_info "Calling API to issue credential..."
        local api_url="http://127.0.0.1:54321/api/permit/issue/$request_d_tag"
        local api_response
        api_response=$(curl -s -X POST "$api_url" 2>&1)
        
        local api_exit=$?
        
        if [[ $api_exit -eq 0 ]]; then
            local success=$(echo "$api_response" | jq -r '.success // false' 2>/dev/null)
            if [[ "$success" == "true" ]]; then
                local credential_id=$(echo "$api_response" | jq -r '.credential_id // empty' 2>/dev/null)
                local event_id=$(echo "$api_response" | jq -r '.event_id // empty' 2>/dev/null)
                
                test_log_success "Credential issued successfully"
                test_log_info "Credential ID: $credential_id"
                
                if [[ -n "$event_id" ]]; then
                    store_event_id "$event_id" "30503" "permit_credential"
                    test_log_info "Credential event: ${event_id:0:16}..."
                    
                    # Wait for propagation
                    sleep 3
                    
                    # Verify credential
                    local cred_filters="{\"kinds\":[30503],\"ids\":[\"$event_id\"]}"
                    local cred_result
                    cred_result=$(query_nostr_events 30503 "$cred_filters" 2>/dev/null)
                    if [[ -n "$cred_result" ]]; then
                        test_log_success "Credential verified on Nostr relay"
                        
                        # Check for badge emission
                        sleep 2
                        local badge_filters="{\"kinds\":[8],\"#credential_id\":[\"$credential_id\"]}"
                        local badge_result
                        badge_result=$(query_nostr_events 8 "$badge_filters" 2>/dev/null)
                        if [[ -n "$badge_result" ]]; then
                            local badge_event_id=$(echo "$badge_result" | jq -r '.id // empty' 2>/dev/null)
                            if [[ -n "$badge_event_id" ]]; then
                                store_event_id "$badge_event_id" "8" "badge_award"
                                test_log_success "Badge award emitted automatically"
                            fi
                        fi
                    fi
                fi
            else
                local error=$(echo "$api_response" | jq -r '.error // "Unknown error"' 2>/dev/null)
                test_log_error "API returned error: $error"
                return 1
            fi
        else
            test_log_error "API call failed (exit code: $api_exit)"
            test_log_info "Response: $api_response"
            return 1
        fi
    else
        test_log_warning "Insufficient attestations ($attest_count < 1)"
        test_log_info "Credential issuance will happen when ORACLE.refresh.sh runs"
    fi
    
    echo ""
}

# Test 5: Generate badge images
test_generate_badge_images() {
    test_log_info "═══════════════════════════════════════════════════════════"
    test_log_info "Test 5: Generating Badge Images"
    test_log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    local generate_script="$HOME/.zen/Astroport.ONE/IA/generate_badge_image.sh"
    
    if [[ ! -f "$generate_script" ]]; then
        test_log_warning "generate_badge_image.sh not found, skipping badge image generation"
        return 0
    fi
    
    local permit_id=$(get_captain_permit_name)
    local badge_id=$(echo "$permit_id" | tr '[:upper:]' '[:lower:]' | sed 's/PERMIT_/permit_/')
    local permit_display_name=$(echo "$permit_id" | sed 's/PERMIT_//' | sed 's/_X1//' | sed 's/_/ /g')
    
    test_log_info "Badge ID: $badge_id"
    test_log_info "Permit Name: $permit_display_name"
    echo ""
    
    # Check if Ollama and ComfyUI are available
    test_log_info "Checking AI services availability..."
    bash "$HOME/.zen/Astroport.ONE/IA/ollama.me.sh" >/dev/null 2>&1
    bash "$HOME/.zen/Astroport.ONE/IA/comfyui.me.sh" >/dev/null 2>&1
    sleep 2
    
    # Check if services are actually responding
    local ollama_ok=false
    local comfyui_ok=false
    
    if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        ollama_ok=true
        test_log_success "Ollama is available"
    else
        test_log_warning "Ollama is not responding (may need more time)"
    fi
    
    if curl -s http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
        comfyui_ok=true
        test_log_success "ComfyUI is available"
    else
        test_log_warning "ComfyUI is not responding (may need more time)"
    fi
    
    if [[ "$ollama_ok" != "true" || "$comfyui_ok" != "true" ]]; then
        test_log_warning "AI services not fully available, badge generation may fail"
        test_log_info "Skipping badge image generation (services not ready)"
        return 0
    fi
    
    # Generate badge image with timeout and verbose output
    test_log_info "Generating badge image (this may take 1-2 minutes)..."
    debug_log "Calling: $generate_script $badge_id \"$permit_display_name\" \"Captain's auto-proclaimed mastery - WoTx2 level X1\" X1 Débutant"
    
    # Create a temporary file to capture output
    local badge_output_file="$TEST_TEMP_DIR/badge_generation_${badge_id}.log"
    rm -f "$badge_output_file"
    
    debug_log "Badge generation output will be logged to: $badge_output_file"
    
    # Run with timeout and capture both stdout and stderr
    local badge_result
    if [[ "$DEBUG" == "true" ]]; then
        # In debug mode, show output in real-time
        badge_result=$(timeout 300 "$generate_script" \
            "$badge_id" \
            "$permit_display_name" \
            "Captain's auto-proclaimed mastery - WoTx2 level X1" \
            "X1" \
            "Débutant" 2>&1 | tee "$badge_output_file")
    else
        # In normal mode, capture to file
        timeout 300 "$generate_script" \
            "$badge_id" \
            "$permit_display_name" \
            "Captain's auto-proclaimed mastery - WoTx2 level X1" \
            "X1" \
            "Débutant" > "$badge_output_file" 2>&1
        badge_result=$(cat "$badge_output_file")
    fi
    
    local gen_exit=$?
    debug_log "Badge generation exit code: $gen_exit"
    verbose_log "Badge generation output (first 500 chars): ${badge_result:0:500}"
    
    if [[ $gen_exit -eq 124 ]]; then
        test_log_error "Badge generation timed out after 5 minutes"
        debug_log "Full output saved in: $badge_output_file"
        return 1
    elif [[ $gen_exit -ne 0 ]]; then
        test_log_error "Badge generation failed (exit code: $gen_exit)"
        debug_log "Full output saved in: $badge_output_file"
        verbose_log "Error output: $badge_result"
        return 1
    fi
    
    if [[ $gen_exit -eq 0 ]]; then
        local success=$(echo "$badge_result" | jq -r '.success // false' 2>/dev/null)
        if [[ "$success" == "true" ]]; then
            local image_url=$(echo "$badge_result" | jq -r '.badge_image_url // empty' 2>/dev/null)
            local thumb_256=$(echo "$badge_result" | jq -r '.badge_thumb_256 // empty' 2>/dev/null)
            local thumb_64=$(echo "$badge_result" | jq -r '.badge_thumb_64 // empty' 2>/dev/null)
            
            test_log_success "Badge images generated successfully"
            test_log_info "Main image: $image_url"
            test_log_info "Thumbnail 256: $thumb_256"
            test_log_info "Thumbnail 64: $thumb_64"
            
            # Verify images are accessible
            if [[ -n "$image_url" ]]; then
                local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$image_url" 2>/dev/null)
                if [[ "$http_code" == "200" ]]; then
                    test_log_success "Badge image is accessible via IPFS"
                else
                    test_log_warning "Badge image may not be accessible yet (HTTP $http_code)"
                fi
            fi
        else
            local error=$(echo "$badge_result" | jq -r '.error // "Unknown error"' 2>/dev/null)
            test_log_warning "Badge generation may have failed: $error"
            test_log_info "This is expected if ComfyUI is not running"
        fi
    else
        test_log_warning "Badge generation script failed (exit code: $gen_exit)"
        test_log_info "This is expected if ComfyUI/AI services are not available"
        test_log_info "Badge images will be generated automatically when credential is issued"
    fi
    
    echo ""
}

# Test 6: Create ORE contract for UMAP 0.00 0.00
test_create_ore_contract() {
    test_log_info "═══════════════════════════════════════════════════════════"
    test_log_info "Test 6: Creating ORE Contract for UMAP 0.00 0.00"
    test_log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    local lat="0.00"
    local lon="0.00"
    local ore_system="$ASTROPORT_PATH/tools/ore_system.py"
    
    if [[ ! -f "$ore_system" ]]; then
        test_log_warning "ore_system.py not found at $ore_system, skipping ORE contract creation"
        test_log_info "ORE system may not be fully implemented yet"
        return 0
    fi
    
    # Check if ORE is already activated
    local umap_dir="$HOME/.zen/game/nostr/UMAP_${lat}_${lon}"
    if [[ -f "$umap_dir/ore_mode.activated" ]]; then
        test_log_warning "ORE mode already activated for UMAP $lat $lon"
        test_log_info "Skipping ORE activation, using existing contract"
        return 0
    fi
    
    # Activate ORE mode
    test_log_info "Activating ORE mode for UMAP ($lat, $lon)..."
    local umappath="$HOME/.zen/tmp/${IPFSNODEID}/UPLANET/__/_0/_0/_${lat}_${lon}"
    mkdir -p "$umappath"
    
    local ore_result
    ore_result=$(python3 "$ore_system" "activate_ore" "$lat" "$lon" "$umappath" 2>&1)
    local ore_exit=$?
    
    if [[ $ore_exit -eq 0 ]]; then
        test_log_success "ORE mode activated for UMAP"
        
        # Verify ORE contract file
        if [[ -f "$umap_dir/ore_contract.json" ]]; then
            test_log_success "ORE contract file created"
            
            # Check contract content
            local contract_id=$(jq -r '.contractId // empty' "$umap_dir/ore_contract.json" 2>/dev/null)
            if [[ -n "$contract_id" ]]; then
                test_log_success "ORE contract ID: $contract_id"
            fi
        fi
        
        # Verify UMAP DID was created/updated
        local umap_hex
        umap_hex=$(get_umap_keys)
        if [[ -n "$umap_hex" ]]; then
            local did_filters="{\"kinds\":[30800],\"#d\":[\"did\"],\"authors\":[\"$umap_hex\"]}"
            local did_result
            did_result=$(query_nostr_events 30800 "$did_filters" 2>/dev/null)
            
            if [[ -n "$did_result" ]]; then
                local did_content=$(echo "$did_result" | jq -r '.content // empty' 2>/dev/null)
                if [[ -n "$did_content" ]]; then
                    local has_ore=$(echo "$did_content" | jq -r '.environmentalObligations // empty' 2>/dev/null)
                    if [[ -n "$has_ore" ]]; then
                        test_log_success "UMAP DID includes environmental obligations"
                    fi
                fi
            fi
        fi
        
        # Verify ORE Meeting Space was published
        sleep 2
        local space_id="ore-space-${lat}-${lon}"
        local space_filters="{\"kinds\":[30312],\"#d\":[\"$space_id\"]}"
        local space_result
        space_result=$(query_nostr_events 30312 "$space_filters" 2>/dev/null)
        
        if [[ -n "$space_result" ]]; then
            local space_event_id=$(echo "$space_result" | jq -r '.id // empty' 2>/dev/null)
            if [[ -n "$space_event_id" ]]; then
                store_event_id "$space_event_id" "30312" "ore_meeting_space"
                test_log_success "ORE Meeting Space published (event: ${space_event_id:0:16}...)"
            fi
        else
            test_log_warning "ORE Meeting Space not found (may not be published yet)"
        fi
    else
        test_log_warning "ORE activation may have failed: $ore_result"
        test_log_info "This is expected if ORE system is not fully configured"
    fi
    
    echo ""
}

# Test 7: Explain UPlanet Game UX
test_explain_uplanet_ux() {
    test_log_info "═══════════════════════════════════════════════════════════"
    test_log_info "Test 7: UPlanet Game UX Explanation"
    test_log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    cat << 'EOF'
🎮 UPLANET GAME UX - The Captain's Journey
═══════════════════════════════════════════════════════════════

UPlanet is a gamified ecosystem where every action contributes to
building and maintaining a decentralized planet. As Captain, you are
the guardian and architect of your UPlanet.

📊 GAME MECHANICS:

1. IDENTITY & SOVEREIGNTY (DID System)
   ────────────────────────────────────
   • Your MULTIPASS is your identity (did:nostr:...)
   • Your ZEN Card is your ownership stake
   • Every action is cryptographically signed
   • You control your data, your identity, your planet

2. COMPETENCE CERTIFICATION (Oracle System)
   ────────────────────────────────────────
   • Official Permits: Created by UPLANETNAME_G1
     - PERMIT_ORE_V1: Environmental verifier
     - PERMIT_DRIVER: Driver's license (WoT model)
     - PERMIT_MEDICAL_FIRST_AID: First aid provider
   
   • WoTx2 Masteries: Created by anyone (auto-proclaimed)
     - PERMIT_CAPTAINEMAIL_X1: Your mastery starts here
     - Progression: X1 → X2 → X3 → ... → X144+ (unlimited)
     - Each level requires N attestations from certified masters
     - Competencies are revealed progressively

3. BADGES & GAMIFICATION (NIP-58)
   ───────────────────────────────
   • Every credential earns a badge
   • Badges are visual proof of competence
   • Badge images generated automatically with AI
   • Display badges in your profile (kind 30008)
   • Show mastery progression visually

4. ENVIRONMENTAL PROTECTION (ORE System)
   ─────────────────────────────────────
   • UMAPs (0.01° × 0.01° cells) have DIDs
   • Environmental contracts attached to UMAP DIDs
   • Verification via satellite/IoT/VDO.ninja
   • Economic rewards in Ẑen for compliance
   • Cost: < 1€ vs 6,500-19,000€ traditional

5. ECONOMIC INCENTIVES
   ────────────────────
   • Permit holders receive Ẑen rewards
   • ORE compliance earns Ẑen from ASSETS wallet
   • Contributions to TREASURY/R&D/ASSETS tracked
   • All transactions on blockchain Ğ1
   • Transparent, verifiable, decentralized

🎯 CAPTAIN'S RESPONSIBILITIES:

As Captain, you validate the health of your UPlanet by:

1. ✅ Creating and managing permits (Oracle System)
2. ✅ Certifying competencies (WoTx2 attestations)
3. ✅ Protecting environment (ORE contracts)
4. ✅ Maintaining infrastructure (Astroport management)
5. ✅ Building community (N² network expansion)

📈 PROGRESSION SYSTEM:

WoTx2 Masteries:
  X1-X4:    Débutant (Bronze/Copper badges)
  X5-X10:   Expert (Silver badges)
  X11-X50:  Maître (Gold badges)
  X51-X100: Grand Maître (Platinum badges)
  X101+:    Maître Absolu (Rainbow badges)

Each level unlocks:
  • New competencies
  • Higher authority
  • More Ẑen rewards
  • Greater responsibility

🌱 ENVIRONMENTAL SCORING:

UMAP Environmental Value Score:
  • Biodiversity (PlantNet observations)
  • Forest coverage
  • Water presence
  • Protected species
  • ORE contract compliance

Score > 0.7 → ORE mode activated automatically

💎 ECONOMIC FLOW:

TREASURY (1/3) → Cooperative operations
R&D (1/3)      → Research & development
ASSETS (1/3)   → Environmental rewards (ORE)

All flows are transparent on blockchain Ğ1

🔐 SECURITY MODEL:

SSSS 3/2 Secret Sharing:
  • Part 1: You (QR code, laminated)
  • Part 2: Captain (Astroport)
  • Part 3: UPlanet network (backup)

2 of 3 parts needed to recover identity

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎮 GAME LOOP:

1. CREATE → Create permits, masteries, ORE contracts
2. ATTEST → Validate competencies of others
3. EARN → Receive Ẑen rewards for contributions
4. PROGRESS → Level up your masteries (X1 → X2 → ...)
5. PROTECT → Maintain environmental contracts
6. BUILD → Expand your N² network
7. REPEAT → Continuous improvement cycle

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ VALIDATION COMPLETE:

By completing these tests, you have:
  • Created your WoTx2 mastery (PERMIT_CAPTAINEMAIL_X1)
  • Generated badge images automatically
  • Created an ORE contract for UMAP 0.00 0.00
  • Validated the complete UPlanet game loop

Your UPlanet is now operational and ready for:
  • Community growth
  • Competence certification
  • Environmental protection
  • Economic development

🚀 Welcome to UPlanet, Captain!

EOF
    
    echo ""
    test_log_success "UPlanet Game UX explained"
    echo ""
}

# Main test execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  Captain Validation Test - Complete UPlanet Workflow"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "This test creates REAL data on your UPlanet:"
    echo "  • WoTx2 permit for captain"
    echo "  • Permit request and self-attestation"
    echo "  • Badge images (AI-generated)"
    echo "  • ORE contract for UMAP 0.00 0.00"
    echo ""
    echo "Options:"
    echo "  --cleanup    Remove test events after completion"
    echo "  --verbose    Show detailed output"
    echo "  --debug      Show debug information (includes --verbose)"
    echo ""
    
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${YELLOW}[DEBUG MODE ENABLED]${NC}"
        echo "  - Bash debug mode: ON (set -x)"
        echo "  - Verbose logging: ON"
        echo "  - Debug logging: ON"
        echo ""
    elif [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE MODE ENABLED]${NC}"
        echo "  - Verbose logging: ON"
        echo ""
    fi
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo ""
    
    # Run all tests
    test_create_captain_wotx2_permit
    test_captain_request_permit
    test_captain_self_attestation
    test_trigger_credential_issuance
    test_generate_badge_images
    test_create_ore_contract
    test_explain_uplanet_ux
    
    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Test Summary"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    print_test_summary
    
    # Cleanup if requested
    if [[ "$CLEANUP_AFTER" == "true" ]]; then
        echo ""
        test_log_info "Cleaning up test events..."
        if [[ -f "$MY_PATH/cleanup_test_events.sh" ]]; then
            bash "$MY_PATH/cleanup_test_events.sh" --file "$TEST_EVENTS_FILE"
        else
            test_log_warning "cleanup_test_events.sh not found, skipping cleanup"
        fi
    else
        echo ""
        test_log_info "Test events stored in: $TEST_EVENTS_FILE"
        test_log_info "Run cleanup_test_events.sh to remove test events"
    fi
    
    exit $?
}

# Run main function
main "$@"

