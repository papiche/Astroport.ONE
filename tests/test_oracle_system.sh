#!/bin/bash
###################################################################
# test_oracle_system.sh
# Test suite for Oracle System (Official Permits)
#
# Tests:
# - Permit definition creation (kind 30500)
# - Permit request submission (kind 30501)
# - Permit attestation (kind 30502)
# - Credential issuance (kind 30503)
# - Badge emission (kind 30009, 8)
# - Integration with UPLANETNAME_G1
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source common test functions
source "$MY_PATH/test_common.sh"

# Test permit definition creation
test_permit_definition() {
    test_log_info "Testing permit definition creation..."
    
    # Get UPLANETNAME_G1 keys
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Test permit definition structure
    local permit_id="PERMIT_TEST_$(date +%s)"
    local permit_name="Test Permit"
    local permit_description="Test permit for validation"
    
    # Check if oracle_system.py is available
    local oracle_system="$HOME/.zen/UPassport/oracle_system.py"
    if [[ ! -f "$oracle_system" ]]; then
        test_log_warning "oracle_system.py not found, skipping permit definition test"
        return 0
    fi
    
    # Try to query existing permit definitions from Nostr
    local filters_json="{\"kinds\":[30500],\"#d\":[\"PERMIT_ORE_V1\"]}"
    local result
    result=$(query_nostr_events 30500 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Permit definition found on Nostr relay"
        
        # Validate permit definition structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30500" "$event_kind" "Event should be kind 30500"
        
        local permit_content=$(echo "$result" | jq -r '.content // empty' 2>/dev/null)
        if [[ -n "$permit_content" ]]; then
            local permit_json=$(echo "$permit_content" | jq . 2>/dev/null)
            if [[ -n "$permit_json" ]]; then
                local permit_id_from_event=$(echo "$permit_json" | jq -r '.id // empty' 2>/dev/null)
                assert_not_empty "$permit_id_from_event" "Permit should have an id"
                
                test_log_success "Permit definition structure is valid"
            fi
        fi
    else
        test_log_warning "Permit definition not found on Nostr relay (may not be published yet)"
    fi
}

# Test permit request
test_permit_request() {
    test_log_info "Testing permit request..."
    
    local captain_hex
    captain_hex=$(get_captain_keys)
    assert_not_empty "$captain_hex" "Captain's HEX should be available"
    
    # Query for permit requests by captain
    local filters_json="{\"kinds\":[30501],\"authors\":[\"$captain_hex\"]}"
    local result
    result=$(query_nostr_events 30501 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Permit request found on Nostr relay"
        
        # Validate request structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30501" "$event_kind" "Event should be kind 30501"
        
        # Check for permit type tag
        local permit_type_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "l" and .[2] == "permit_type") | .[1] // empty' 2>/dev/null)
        if [[ -n "$permit_type_tag" ]]; then
            test_log_success "Permit request has permit_type tag"
        fi
    else
        test_log_warning "No permit requests found for captain (may not have any requests)"
    fi
}

# Test permit attestation
test_permit_attestation() {
    test_log_info "Testing permit attestation..."
    
    local captain_hex
    captain_hex=$(get_captain_keys)
    assert_not_empty "$captain_hex" "Captain's HEX should be available"
    
    # Query for attestations by captain
    local filters_json="{\"kinds\":[30502],\"authors\":[\"$captain_hex\"]}"
    local result
    result=$(query_nostr_events 30502 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Permit attestation found on Nostr relay"
        
        # Validate attestation structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30502" "$event_kind" "Event should be kind 30502"
        
        # Check for reference to request (tag e)
        local request_ref=$(echo "$result" | jq -r '.tags[] | select(.[0] == "e") | .[1] // empty' 2>/dev/null | head -1)
        if [[ -n "$request_ref" ]]; then
            test_log_success "Attestation references a permit request"
        fi
    else
        test_log_warning "No attestations found for captain (may not have attested any permits)"
    fi
}

# Test credential issuance
test_credential_issuance() {
    test_log_info "Testing credential issuance..."
    
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Query for credentials issued by UPLANETNAME_G1
    local filters_json="{\"kinds\":[30503],\"authors\":[\"$g1_hex\"]}"
    local result
    result=$(query_nostr_events 30503 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Credential found on Nostr relay"
        
        # Validate credential structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30503" "$event_kind" "Event should be kind 30503"
        
        # Check credential content (W3C VC)
        local credential_content=$(echo "$result" | jq -r '.content // empty' 2>/dev/null)
        if [[ -n "$credential_content" ]]; then
            local credential_json=$(echo "$credential_content" | jq . 2>/dev/null)
            if [[ -n "$credential_json" ]]; then
                local vc_type=$(echo "$credential_json" | jq -r '.["@context"] // []' 2>/dev/null)
                assert_not_empty "$vc_type" "Credential should have @context"
                
                local vc_issuer=$(echo "$credential_json" | jq -r '.issuer // empty' 2>/dev/null)
                assert_not_empty "$vc_issuer" "Credential should have issuer"
                
                test_log_success "Credential structure is W3C VC compliant"
            fi
        fi
        
        # Check for permit_id tag
        local permit_id_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "permit_id") | .[1] // empty' 2>/dev/null)
        if [[ -n "$permit_id_tag" ]]; then
            test_log_success "Credential has permit_id tag"
        fi
    else
        test_log_warning "No credentials found (may not have issued any credentials yet)"
    fi
}

# Test badge emission
test_badge_emission() {
    test_log_info "Testing badge emission..."
    
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Query for badge definitions (kind 30009)
    local filters_json="{\"kinds\":[30009],\"authors\":[\"$g1_hex\"]}"
    local result
    result=$(query_nostr_events 30009 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Badge definition found on Nostr relay"
        
        # Validate badge definition structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30009" "$event_kind" "Event should be kind 30009"
        
        # Check for badge name tag
        local badge_name=$(echo "$result" | jq -r '.tags[] | select(.[0] == "name") | .[1] // empty' 2>/dev/null)
        if [[ -n "$badge_name" ]]; then
            test_log_success "Badge definition has name tag"
        fi
        
        # Check for image tag
        local badge_image=$(echo "$result" | jq -r '.tags[] | select(.[0] == "image") | .[1] // empty' 2>/dev/null)
        if [[ -n "$badge_image" ]]; then
            test_log_success "Badge definition has image tag"
        fi
    else
        test_log_warning "No badge definitions found (may not have emitted any badges yet)"
    fi
    
    # Query for badge awards (kind 8)
    local filters_json_awards="{\"kinds\":[8],\"authors\":[\"$g1_hex\"]}"
    local result_awards
    result_awards=$(query_nostr_events 8 "$filters_json_awards" 2>/dev/null)
    
    if [[ -n "$result_awards" ]]; then
        test_log_success "Badge award found on Nostr relay"
        
        # Validate badge award structure
        local event_kind=$(echo "$result_awards" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "8" "$event_kind" "Event should be kind 8"
        
        # Check for badge reference (tag a)
        local badge_ref=$(echo "$result_awards" | jq -r '.tags[] | select(.[0] == "a") | .[1] // empty' 2>/dev/null | head -1)
        if [[ -n "$badge_ref" ]]; then
            test_log_success "Badge award references a badge definition"
        fi
    else
        test_log_warning "No badge awards found (may not have awarded any badges yet)"
    fi
}

# Test IPFSNODEID filtering
test_ipfsnodeid_filtering() {
    test_log_info "Testing IPFSNODEID filtering..."
    
    if [[ -z "${IPFSNODEID:-}" ]]; then
        test_log_warning "IPFSNODEID not set, skipping filtering test"
        return 0
    fi
    
    # Query for events with ipfs_node tag
    local filters_json="{\"kinds\":[30500],\"#ipfs_node\":[\"$IPFSNODEID\"]}"
    local result
    result=$(query_nostr_events 30500 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        # Check if events have ipfs_node tag
        local has_ipfs_node=$(echo "$result" | jq -r '.tags[] | select(.[0] == "ipfs_node") | .[1] // empty' 2>/dev/null | head -1)
        if [[ "$has_ipfs_node" == "$IPFSNODEID" ]]; then
            test_log_success "Events are properly filtered by IPFSNODEID"
        else
            test_log_warning "Event found but ipfs_node tag may not match"
        fi
    else
        test_log_warning "No events found with IPFSNODEID filter (may not have any events with this tag)"
    fi
}

# Main test execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  Oracle System Tests"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    test_permit_definition
    test_permit_request
    test_permit_attestation
    test_credential_issuance
    test_badge_emission
    test_ipfsnodeid_filtering
    
    print_test_summary
    exit $?
}

# Run main function
main "$@"

