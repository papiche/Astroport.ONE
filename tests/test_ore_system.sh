#!/bin/bash
###################################################################
# test_ore_system.sh
# Test suite for ORE System (Environmental Contracts)
#
# Tests:
# - UMAP DID creation (kind 30800)
# - ORE contract activation
# - ORE Meeting Space (kind 30312)
# - ORE Verification Meeting (kind 30313)
# - UMAP 0.00 0.00 as test territory
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source common test functions
source "$MY_PATH/test_common.sh"

# Test UMAP DID for 0.00 0.00
test_umap_did_ore() {
    test_log_info "Testing UMAP DID for ORE (0.00 0.00)..."
    
    local lat="0.00"
    local lon="0.00"
    local umap_hex
    umap_hex=$(get_umap_keys)
    assert_not_empty "$umap_hex" "UMAP HEX should be available"
    
    # Query for UMAP DID (kind 30800)
    local filters_json="{\"kinds\":[30800],\"#d\":[\"did\"],\"authors\":[\"$umap_hex\"]}"
    local result
    result=$(query_nostr_events 30800 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "UMAP DID found on Nostr relay"
        
        # Validate DID structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30800" "$event_kind" "Event should be kind 30800"
        
        # Check DID content
        local did_content=$(echo "$result" | jq -r '.content // empty' 2>/dev/null)
        if [[ -n "$did_content" ]]; then
            local did_json=$(echo "$did_content" | jq . 2>/dev/null)
            if [[ -n "$did_json" ]]; then
                # Check for UMAPGeographicCell type
                local did_type=$(echo "$did_json" | jq -r '.type // empty' 2>/dev/null)
                if [[ "$did_type" == "UMAPGeographicCell" ]]; then
                    test_log_success "UMAP DID has correct type"
                fi
                
                # Check for geographic metadata
                local geo_metadata=$(echo "$did_json" | jq -r '.geographicMetadata // empty' 2>/dev/null)
                if [[ -n "$geo_metadata" ]]; then
                    local geo_coords=$(echo "$did_json" | jq -r '.geographicMetadata.coordinates // empty' 2>/dev/null)
                    if [[ -n "$geo_coords" ]]; then
                        test_log_success "UMAP DID has geographic metadata"
                    fi
                fi
                
                # Check for environmental obligations
                local env_obligations=$(echo "$did_json" | jq -r '.environmentalObligations // empty' 2>/dev/null)
                if [[ -n "$env_obligations" ]]; then
                    test_log_success "UMAP DID has environmental obligations"
                    
                    # Check for ORE contract
                    local ore_contract=$(echo "$did_json" | jq -r '.environmentalObligations.oreContract // empty' 2>/dev/null)
                    if [[ -n "$ore_contract" ]]; then
                        test_log_success "UMAP DID has ORE contract"
                        
                        # Check contract details
                        local contract_id=$(echo "$did_json" | jq -r '.environmentalObligations.oreContract.contractId // empty' 2>/dev/null)
                        local contract_desc=$(echo "$did_json" | jq -r '.environmentalObligations.oreContract.description // empty' 2>/dev/null)
                        
                        if [[ -n "$contract_id" ]]; then
                            test_log_success "ORE contract has contractId: $contract_id"
                        fi
                        if [[ -n "$contract_desc" ]]; then
                            test_log_success "ORE contract has description"
                        fi
                    else
                        test_log_warning "UMAP DID has environmental obligations but no ORE contract (may not be activated)"
                    fi
                else
                    test_log_warning "UMAP DID does not have environmental obligations (ORE may not be activated)"
                fi
            fi
        fi
    else
        test_log_warning "UMAP DID not found on Nostr relay (may not be published yet)"
    fi
}

# Test ORE Meeting Space
test_ore_meeting_space() {
    test_log_info "Testing ORE Meeting Space (kind 30312)..."
    
    local lat="0.00"
    local lon="0.00"
    local space_id="ore-space-${lat}-${lon}"
    
    # Query for ORE Meeting Space
    local filters_json="{\"kinds\":[30312],\"#d\":[\"$space_id\"]}"
    local result
    result=$(query_nostr_events 30312 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "ORE Meeting Space found on Nostr relay"
        
        # Validate event structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30312" "$event_kind" "Event should be kind 30312"
        
        # Check for room tag (VDO.ninja)
        local room_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "room") | .[1] // empty' 2>/dev/null)
        if [[ -n "$room_tag" ]]; then
            test_log_success "ORE Meeting Space has room tag for VDO.ninja"
        fi
        
        # Check for geolocation tag
        local geo_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "g") | .[1] // empty' 2>/dev/null)
        if [[ -n "$geo_tag" ]]; then
            test_log_success "ORE Meeting Space has geolocation tag"
        fi
        
        # Check for ORE tags
        local ore_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "t" and .[1] == "ORE") | .[1] // empty' 2>/dev/null)
        if [[ -n "$ore_tag" ]]; then
            test_log_success "ORE Meeting Space has ORE tag"
        fi
    else
        test_log_warning "ORE Meeting Space not found (may not be activated for this UMAP)"
    fi
}

# Test ORE Verification Meeting
test_ore_verification_meeting() {
    test_log_info "Testing ORE Verification Meeting (kind 30313)..."
    
    local lat="0.00"
    local lon="0.00"
    
    # Query for ORE Verification Meetings
    local filters_json="{\"kinds\":[30313],\"#t\":[\"ORE\",\"Verification\"]}"
    local result
    result=$(query_nostr_events 30313 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "ORE Verification Meeting found on Nostr relay"
        
        # Validate event structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30313" "$event_kind" "Event should be kind 30313"
        
        # Check for reference to meeting space (tag a)
        local space_ref=$(echo "$result" | jq -r '.tags[] | select(.[0] == "a") | .[1] // empty' 2>/dev/null | head -1)
        if [[ -n "$space_ref" ]]; then
            test_log_success "Verification Meeting references ORE Meeting Space"
        fi
        
        # Check for start time
        local start_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "start") | .[1] // empty' 2>/dev/null)
        if [[ -n "$start_tag" ]]; then
            test_log_success "Verification Meeting has start time"
        fi
        
        # Check for status
        local status_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "status") | .[1] // empty' 2>/dev/null)
        if [[ -n "$status_tag" ]]; then
            test_log_success "Verification Meeting has status: $status_tag"
        fi
    else
        test_log_warning "No ORE Verification Meetings found (may not have scheduled any yet)"
    fi
}

# Test ORE system script
test_ore_system_script() {
    test_log_info "Testing ORE system script..."
    
    local ore_system="$HOME/.zen/Astroport.ONE/tools/ore_system.py"
    
    if [[ ! -f "$ore_system" ]]; then
        test_log_warning "ore_system.py not found, skipping script tests"
        return 0
    fi
    
    # Test script availability
    assert_file_exists "$ore_system" "ORE system script should exist"
    
    # Try to run help command
    local help_result
    help_result=$(python3 "$ore_system" --help 2>&1)
    local help_exit=$?
    
    if [[ $help_exit -eq 0 ]]; then
        test_log_success "ORE system script is executable"
    else
        test_log_warning "ORE system script may not be executable or may have errors"
    fi
}

# Test ORE contract activation
test_ore_contract_activation() {
    test_log_info "Testing ORE contract activation..."
    
    local lat="0.00"
    local lon="0.00"
    local umap_hex
    umap_hex=$(get_umap_keys)
    assert_not_empty "$umap_hex" "UMAP HEX should be available"
    
    # Check if UMAP directory exists
    local umap_dir="$HOME/.zen/game/nostr/UMAP_${lat}_${lon}"
    if [[ -d "$umap_dir" ]]; then
        test_log_success "UMAP directory exists"
        
        # Check for HEX file
        if [[ -f "$umap_dir/HEX" ]]; then
            local stored_hex=$(cat "$umap_dir/HEX")
            assert_equal "$umap_hex" "$stored_hex" "UMAP HEX should match stored value"
        fi
        
        # Check for .secret.nostr file
        if [[ -f "$umap_dir/.secret.nostr" ]]; then
            test_log_success "UMAP has secret file for signing"
        else
            test_log_warning "UMAP secret file not found (may not be fully initialized)"
        fi
    else
        test_log_warning "UMAP directory not found (may not be initialized)"
    fi
}

# Test ORE badge emission
test_ore_badge_emission() {
    test_log_info "Testing ORE badge emission..."
    
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Query for ORE-related badges (kind 30009)
    local filters_json="{\"kinds\":[30009],\"#t\":[\"ore\",\"uplanet\"]}"
    local result
    result=$(query_nostr_events 30009 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "ORE badge definition found"
        
        # Validate badge structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30009" "$event_kind" "Event should be kind 30009"
        
        # Check for ORE tag
        local ore_tag=$(echo "$result" | jq -r '.tags[] | select(.[0] == "t" and .[1] == "ore") | .[1] // empty' 2>/dev/null)
        if [[ -n "$ore_tag" ]]; then
            test_log_success "ORE badge has ore tag"
        fi
    else
        test_log_warning "No ORE badges found (may not have emitted any yet)"
    fi
}

# Main test execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  ORE System Tests"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    test_umap_did_ore
    test_ore_meeting_space
    test_ore_verification_meeting
    test_ore_system_script
    test_ore_contract_activation
    test_ore_badge_emission
    
    print_test_summary
    exit $?
}

# Run main function
main "$@"

