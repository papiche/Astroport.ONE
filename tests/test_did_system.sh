#!/bin/bash
###################################################################
# test_did_system.sh
# Test suite for DID (Decentralized Identifier) System
#
# Tests:
# - DID document creation and structure
# - DID resolution (Nostr, IPFS, cache)
# - DID updates and metadata
# - DID for UMAP (geographic cells)
# - DID compliance with W3C standards
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source common test functions
source "$MY_PATH/test_common.sh"

# Test captain's DID
test_captain_did() {
    test_log_info "Testing Captain's DID..."
    
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    assert_file_exists "$captain_secret" "Captain's secret file should exist"
    
    source "$captain_secret"
    assert_not_empty "${HEX:-}" "Captain's HEX should be set"
    assert_not_empty "${NPUB:-}" "Captain's NPUB should be set"
    
    # Check DID document cache
    local did_cache="$HOME/.zen/game/nostr/$CAPTAINEMAIL/did.json.cache"
    if [[ -f "$did_cache" ]]; then
        assert_file_exists "$did_cache" "DID cache should exist"
        
        # Validate DID structure
        local did_id=$(jq -r '.id // empty' "$did_cache" 2>/dev/null)
        assert_not_empty "$did_id" "DID should have an id"
        assert_true "[[ '$did_id' =~ ^did:nostr:.* ]]" "DID should use did:nostr: method"
        
        # Check verification methods
        local verification_methods=$(jq -r '.verificationMethod // [] | length' "$did_cache" 2>/dev/null)
        assert_true "[[ $verification_methods -gt 0 ]]" "DID should have verification methods"
        
        # Check service endpoints
        local services=$(jq -r '.service // [] | length' "$did_cache" 2>/dev/null)
        assert_true "[[ $services -gt 0 ]]" "DID should have service endpoints"
        
        test_log_success "Captain's DID structure is valid"
    else
        test_log_warning "DID cache not found, DID may not be created yet"
    fi
}

# Test DID resolution via Nostr
test_did_resolution_nostr() {
    test_log_info "Testing DID resolution via Nostr..."
    
    local captain_hex
    captain_hex=$(get_captain_keys)
    assert_not_empty "$captain_hex" "Captain's HEX should be available"
    
    # Try to fetch DID from Nostr (kind 30800)
    local filters_json="{\"kinds\":[30800],\"#d\":[\"did\"],\"authors\":[\"$captain_hex\"]}"
    local result
    result=$(query_nostr_events 30800 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "DID found on Nostr relay"
        
        # Validate event structure
        local event_id=$(echo "$result" | jq -r '.id // empty' 2>/dev/null)
        assert_not_empty "$event_id" "Nostr event should have an id"
        
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30800" "$event_kind" "Event should be kind 30800 (DID Document)"
    else
        test_log_warning "DID not found on Nostr relay (may not be published yet)"
    fi
}

# Test DID manager commands
test_did_manager() {
    test_log_info "Testing DID manager commands..."
    
    local did_manager="$HOME/.zen/Astroport.ONE/tools/did_manager_nostr.sh"
    
    if [[ ! -f "$did_manager" ]]; then
        test_log_warning "did_manager_nostr.sh not found, skipping DID manager tests"
        return 0
    fi
    
    # Test fetch command
    local fetch_result
    fetch_result=$("$did_manager" fetch "$CAPTAINEMAIL" 2>&1)
    local fetch_exit=$?
    
    if [[ $fetch_exit -eq 0 ]]; then
        test_log_success "DID fetch command works"
    else
        test_log_warning "DID fetch command failed (may be expected if DID not published)"
    fi
    
    # Test sync command
    local sync_result
    sync_result=$("$did_manager" sync "$CAPTAINEMAIL" 2>&1)
    local sync_exit=$?
    
    if [[ $sync_exit -eq 0 ]]; then
        test_log_success "DID sync command works"
    else
        test_log_warning "DID sync command failed"
    fi
}

# Test UMAP DID
test_umap_did() {
    test_log_info "Testing UMAP DID for 0.00 0.00..."
    
    local lat="0.00"
    local lon="0.00"
    local umap_id="UMAP_${lat}_${lon}"
    local umap_dir="$HOME/.zen/game/nostr/$umap_id"
    
    # Check if UMAP directory exists
    if [[ -d "$umap_dir" ]]; then
        assert_file_exists "$umap_dir" "UMAP directory should exist"
        
        # Check for HEX file
        if [[ -f "$umap_dir/HEX" ]]; then
            local umap_hex=$(cat "$umap_dir/HEX")
            assert_not_empty "$umap_hex" "UMAP HEX should be set"
            
            # Try to fetch UMAP DID from Nostr
            local filters_json="{\"kinds\":[30800],\"#d\":[\"did\"],\"authors\":[\"$umap_hex\"]}"
            local result
            result=$(query_nostr_events 30800 "$filters_json" 2>/dev/null)
            
            if [[ -n "$result" ]]; then
                test_log_success "UMAP DID found on Nostr relay"
            else
                test_log_warning "UMAP DID not found on Nostr relay (may not be published yet)"
            fi
        else
            test_log_warning "UMAP HEX file not found, UMAP may not be initialized"
        fi
    else
        test_log_warning "UMAP directory not found, UMAP may not be initialized"
    fi
}

# Test DID W3C compliance
test_did_compliance() {
    test_log_info "Testing DID W3C compliance..."
    
    local did_cache="$HOME/.zen/game/nostr/$CAPTAINEMAIL/did.json.cache"
    
    if [[ ! -f "$did_cache" ]]; then
        test_log_warning "DID cache not found, skipping compliance tests"
        return 0
    fi
    
    # Check @context
    local context=$(jq -r '.["@context"] // []' "$did_cache" 2>/dev/null)
    assert_not_empty "$context" "DID should have @context"
    
    # Check id format
    local did_id=$(jq -r '.id // empty' "$did_cache" 2>/dev/null)
    assert_true "[[ '$did_id' =~ ^did:nostr:[a-f0-9]{64}$ ]]" "DID id should match did:nostr: format"
    
    # Check verificationMethod structure
    local vm_count=$(jq -r '.verificationMethod // [] | length' "$did_cache" 2>/dev/null)
    if [[ $vm_count -gt 0 ]]; then
        local first_vm=$(jq -r '.verificationMethod[0]' "$did_cache" 2>/dev/null)
        local vm_id=$(echo "$first_vm" | jq -r '.id // empty' 2>/dev/null)
        local vm_type=$(echo "$first_vm" | jq -r '.type // empty' 2>/dev/null)
        local vm_controller=$(echo "$first_vm" | jq -r '.controller // empty' 2>/dev/null)
        
        assert_not_empty "$vm_id" "Verification method should have id"
        assert_not_empty "$vm_type" "Verification method should have type"
        assert_not_empty "$vm_controller" "Verification method should have controller"
        
        test_log_success "DID verification methods are W3C compliant"
    fi
    
    # Check service structure
    local service_count=$(jq -r '.service // [] | length' "$did_cache" 2>/dev/null)
    if [[ $service_count -gt 0 ]]; then
        local first_service=$(jq -r '.service[0]' "$did_cache" 2>/dev/null)
        local service_id=$(echo "$first_service" | jq -r '.id // empty' 2>/dev/null)
        local service_type=$(echo "$first_service" | jq -r '.type // empty' 2>/dev/null)
        local service_endpoint=$(echo "$first_service" | jq -r '.serviceEndpoint // empty' 2>/dev/null)
        
        assert_not_empty "$service_id" "Service should have id"
        assert_not_empty "$service_type" "Service should have type"
        assert_not_empty "$service_endpoint" "Service should have serviceEndpoint"
        
        test_log_success "DID services are W3C compliant"
    fi
}

# Main test execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  DID System Tests"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    test_captain_did
    test_did_resolution_nostr
    test_did_manager
    test_umap_did
    test_did_compliance
    
    print_test_summary
    exit $?
}

# Run main function
main "$@"


