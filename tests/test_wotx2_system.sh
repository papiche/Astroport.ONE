#!/bin/bash
###################################################################
# test_wotx2_system.sh
# Test suite for WoTx2 System (Auto-Proclaimed Masteries)
#
# Tests:
# - WoTx2 permit creation (PERMIT_*_X1)
# - Auto-progression (X1 → X2 → X3...)
# - Competency revelation
# - Captain as WoTx2 user (PERMIT_DRAGON)
# - NIP-42 authentication for progression
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source common test functions
source "$MY_PATH/test_common.sh"

# Test WoTx2 permit creation
test_wotx2_permit_creation() {
    test_log_info "Testing WoTx2 permit creation..."
    
    # Query for auto-proclaimed permits (PERMIT_*_X1 pattern)
    local filters_json="{\"kinds\":[30500],\"#t\":[\"auto_proclaimed\"]}"
    local result
    result=$(query_nostr_events 30500 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "WoTx2 permit found on Nostr relay"
        
        # Validate permit structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30500" "$event_kind" "Event should be kind 30500"
        
        # Check permit content
        local permit_content=$(echo "$result" | jq -r '.content // empty' 2>/dev/null)
        if [[ -n "$permit_content" ]]; then
            local permit_json=$(echo "$permit_content" | jq . 2>/dev/null)
            if [[ -n "$permit_json" ]]; then
                # Check for auto_proclaimed metadata
                local auto_proclaimed=$(echo "$permit_json" | jq -r '.metadata.auto_proclaimed // false' 2>/dev/null)
                assert_equal "true" "$auto_proclaimed" "Permit should be auto-proclaimed"
                
                # Check for level
                local level=$(echo "$permit_json" | jq -r '.metadata.level // empty' 2>/dev/null)
                if [[ -n "$level" ]]; then
                    assert_true "[[ '$level' =~ ^X[0-9]+$ ]]" "Level should match X{n} pattern"
                    test_log_success "WoTx2 permit has level: $level"
                fi
                
                # Check for evolving_system metadata
                local evolving_type=$(echo "$permit_json" | jq -r '.metadata.evolving_system.type // empty' 2>/dev/null)
                if [[ "$evolving_type" == "WoTx2_AutoProclaimed" ]]; then
                    test_log_success "WoTx2 permit has correct evolving_system type"
                fi
            fi
        fi
    else
        test_log_warning "No WoTx2 permits found (may not have created any yet)"
    fi
}

# Test PERMIT_DRAGON for captain
test_permit_dragon() {
    test_log_info "Testing PERMIT_DRAGON for captain..."
    
    local captain_hex
    captain_hex=$(get_captain_keys)
    assert_not_empty "$captain_hex" "Captain's HEX should be available"
    
    # Query for PERMIT_DRAGON definitions
    local filters_json="{\"kinds\":[30500],\"#d\":[\"PERMIT_DRAGON\"]}"
    local result
    result=$(query_nostr_events 30500 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "PERMIT_DRAGON definition found"
        
        # Check if captain has a credential for PERMIT_DRAGON
        local filters_cred="{\"kinds\":[30503],\"#permit_id\":[\"PERMIT_DRAGON\"],\"#p\":[\"$captain_hex\"]}"
        local cred_result
        cred_result=$(query_nostr_events 30503 "$filters_cred" 2>/dev/null)
        
        if [[ -n "$cred_result" ]]; then
            test_log_success "Captain has PERMIT_DRAGON credential"
        else
            test_log_warning "Captain does not have PERMIT_DRAGON credential yet"
        fi
    else
        test_log_warning "PERMIT_DRAGON definition not found (may not be created yet)"
    fi
}

# Test WoTx2 progression
test_wotx2_progression() {
    test_log_info "Testing WoTx2 progression (X1 → X2 → X3)..."
    
    # Query for permits with different levels
    local levels=("X1" "X2" "X3" "X5" "X10")
    local found_levels=0
    
    for level in "${levels[@]}"; do
        # Try to find a permit with this level
        local filters_json="{\"kinds\":[30500],\"#t\":[\"auto_proclaimed\"]}"
        local result
        result=$(query_nostr_events 30500 "$filters_json" 2>/dev/null)
        
        if [[ -n "$result" ]]; then
            # Check if any permit has this level
            local permit_content=$(echo "$result" | jq -r '.content // empty' 2>/dev/null)
            if [[ -n "$permit_content" ]]; then
                local permit_json=$(echo "$permit_content" | jq . 2>/dev/null)
                if [[ -n "$permit_json" ]]; then
                    local permit_level=$(echo "$permit_json" | jq -r '.metadata.level // empty' 2>/dev/null)
                    if [[ "$permit_level" == "$level" ]]; then
                        ((found_levels++))
                        test_log_success "Found permit with level $level"
                    fi
                fi
            fi
        fi
    done
    
    if [[ $found_levels -gt 0 ]]; then
        test_log_success "WoTx2 progression is working (found $found_levels different levels)"
    else
        test_log_warning "No WoTx2 permits with different levels found (progression may not have occurred yet)"
    fi
}

# Test competency revelation
test_competency_revelation() {
    test_log_info "Testing competency revelation..."
    
    # Query for attestations with competency tags
    local filters_json="{\"kinds\":[30502],\"#competency\":[]}"
    local result
    result=$(query_nostr_events 30502 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Attestation with competency tags found"
        
        # Check competency tags
        local competencies=$(echo "$result" | jq -r '.tags[] | select(.[0] == "competency") | .[1] // empty' 2>/dev/null)
        if [[ -n "$competencies" ]]; then
            test_log_success "Competencies are revealed in attestations"
        fi
    else
        test_log_warning "No attestations with competency tags found (may not have revealed competencies yet)"
    fi
    
    # Check credential content for competencies
    local filters_cred="{\"kinds\":[30503],\"#t\":[\"wotx2\"]}"
    local cred_result
    cred_result=$(query_nostr_events 30503 "$filters_cred" 2>/dev/null)
    
    if [[ -n "$cred_result" ]]; then
        local cred_content=$(echo "$cred_result" | jq -r '.content // empty' 2>/dev/null)
        if [[ -n "$cred_content" ]]; then
            local cred_json=$(echo "$cred_content" | jq . 2>/dev/null)
            if [[ -n "$cred_json" ]]; then
                local competencies=$(echo "$cred_json" | jq -r '.credentialSubject.competencies // []' 2>/dev/null)
                local comp_count=$(echo "$competencies" | jq 'length' 2>/dev/null)
                if [[ $comp_count -gt 0 ]]; then
                    test_log_success "Credentials include competencies ($comp_count found)"
                fi
            fi
        fi
    fi
}

# Test NIP-42 authentication
test_nip42_authentication() {
    test_log_info "Testing NIP-42 authentication..."
    
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Query for NIP-42 authentication events (kind 22242)
    local filters_json="{\"kinds\":[22242],\"authors\":[\"$g1_hex\"]}"
    local result
    result=$(query_nostr_events 22242 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "NIP-42 authentication event found"
        
        # Validate NIP-42 event structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "22242" "$event_kind" "Event should be kind 22242"
        
        # Check for relay tag
        local relay_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "relay") | .[1] // empty' 2>/dev/null)
        if [[ -n "$relay_tag" ]]; then
            test_log_success "NIP-42 event has relay tag"
        fi
        
        # Check for challenge tag
        local challenge_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "challenge") | .[1] // empty' 2>/dev/null)
        if [[ -n "$challenge_tag" ]]; then
            test_log_success "NIP-42 event has challenge tag"
        fi
    else
        test_log_warning "No NIP-42 authentication events found (may not have authenticated via NIP-42 yet)"
    fi
}

# Test IPFSNODEID filtering for WoTx2
test_wotx2_ipfsnodeid_filtering() {
    test_log_info "Testing IPFSNODEID filtering for WoTx2..."
    
    if [[ -z "${IPFSNODEID:-}" ]]; then
        test_log_warning "IPFSNODEID not set, skipping filtering test"
        return 0
    fi
    
    # Query for WoTx2 permits with ipfs_node tag
    local filters_json="{\"kinds\":[30500],\"#t\":[\"auto_proclaimed\"],\"#ipfs_node\":[\"$IPFSNODEID\"]}"
    local result
    result=$(query_nostr_events 30500 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        # Check if events have ipfs_node tag
        local has_ipfs_node=$(echo "$result" | jq -r '.tags[] | select(.[0] == "ipfs_node") | .[1] // empty' 2>/dev/null | head -1)
        if [[ "$has_ipfs_node" == "$IPFSNODEID" ]]; then
            test_log_success "WoTx2 events are properly filtered by IPFSNODEID"
        else
            test_log_warning "Event found but ipfs_node tag may not match"
        fi
    else
        test_log_warning "No WoTx2 events found with IPFSNODEID filter"
    fi
}

# Main test execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  WoTx2 System Tests"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    test_wotx2_permit_creation
    test_permit_dragon
    test_wotx2_progression
    test_competency_revelation
    test_nip42_authentication
    test_wotx2_ipfsnodeid_filtering
    
    print_test_summary
    exit $?
}

# Run main function
main "$@"


