#!/bin/bash
###################################################################
# test_badge_system.sh
# Test suite for Badge System (NIP-58)
#
# Tests:
# - Badge definition (kind 30009)
# - Badge award (kind 8)
# - Profile badges (kind 30008)
# - Badge image generation
# - Badge display in interfaces
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source common test functions
source "$MY_PATH/test_common.sh"

# Test badge definition
test_badge_definition() {
    test_log_info "Testing badge definition (kind 30009)..."
    
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Query for badge definitions
    local filters_json="{\"kinds\":[30009],\"authors\":[\"$g1_hex\"]}"
    local result
    result=$(query_nostr_events 30009 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Badge definition found on Nostr relay"
        
        # Validate badge definition structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30009" "$event_kind" "Event should be kind 30009"
        
        # Check for required tags
        local badge_id=$(echo "$result" | jq -r '.tags[] | select(.[0] == "d") | .[1] // empty' 2>/dev/null)
        assert_not_empty "$badge_id" "Badge should have d tag (badge ID)"
        
        local badge_name=$(echo "$result" | jq -r '.tags[] | select(.[0] == "name") | .[1] // empty' 2>/dev/null)
        assert_not_empty "$badge_name" "Badge should have name tag"
        
        local badge_desc=$(echo "$result" | jq -r '.tags[] | select(.[0] == "description") | .[1] // empty' 2>/dev/null)
        assert_not_empty "$badge_desc" "Badge should have description tag"
        
        # Check for image tags
        local badge_image=$(echo "$result" | jq -r '.tags[] | select(.[0] == "image") | .[1] // empty' 2>/dev/null | head -1)
        if [[ -n "$badge_image" ]]; then
            test_log_success "Badge has image tag"
            
            # Check if image URL is valid
            assert_true "[[ '$badge_image' =~ ^https?://.* ]] || [[ '$badge_image' =~ ^ipfs://.* ]]" "Badge image should be a valid URL"
        else
            test_log_warning "Badge does not have image tag (may not have image generated yet)"
        fi
        
        # Check for thumbnails
        local badge_thumb=$(echo "$result" | jq -r '.tags[] | select(.[0] == "thumb") | .[1] // empty' 2>/dev/null | head -1)
        if [[ -n "$badge_thumb" ]]; then
            test_log_success "Badge has thumbnail tag"
        fi
        
        # Check for permit_id tag (Oracle badges)
        local permit_id=$(echo "$result" | jq -r '.tags[] | select(.[0] == "permit_id") | .[1] // empty' 2>/dev/null)
        if [[ -n "$permit_id" ]]; then
            test_log_success "Badge is linked to permit: $permit_id"
        fi
        
        # Check for level tag (WoTx2 badges)
        local level=$(echo "$result" | jq -r '.tags[] | select(.[0] == "level") | .[1] // empty' 2>/dev/null)
        if [[ -n "$level" ]]; then
            test_log_success "Badge has level: $level"
        fi
    else
        test_log_warning "No badge definitions found (may not have emitted any badges yet)"
    fi
}

# Test badge award
test_badge_award() {
    test_log_info "Testing badge award (kind 8)..."
    
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Query for badge awards
    local filters_json="{\"kinds\":[8],\"authors\":[\"$g1_hex\"]}"
    local result
    result=$(query_nostr_events 8 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Badge award found on Nostr relay"
        
        # Validate badge award structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "8" "$event_kind" "Event should be kind 8"
        
        # Check for badge reference (tag a)
        local badge_ref=$(echo "$result" | jq -r '.tags[] | select(.[0] == "a") | .[1] // empty' 2>/dev/null | head -1)
        assert_not_empty "$badge_ref" "Badge award should reference a badge definition"
        
        # Validate badge reference format (30009:pubkey:badge_id)
        assert_true "[[ '$badge_ref' =~ ^30009:[a-f0-9]{64}:.* ]]" "Badge reference should match format 30009:pubkey:badge_id"
        
        # Check for recipient (tag p)
        local recipient=$(echo "$result" | jq -r '.tags[] | select(.[0] == "p") | .[1] // empty' 2>/dev/null | head -1)
        if [[ -n "$recipient" ]]; then
            test_log_success "Badge award has recipient"
        fi
        
        # Check for credential_id tag
        local credential_id=$(echo "$result" | jq -r '.tags[] | select(.[0] == "credential_id") | .[1] // empty' 2>/dev/null)
        if [[ -n "$credential_id" ]]; then
            test_log_success "Badge award is linked to credential: $credential_id"
        fi
    else
        test_log_warning "No badge awards found (may not have awarded any badges yet)"
    fi
}

# Test profile badges
test_profile_badges() {
    test_log_info "Testing profile badges (kind 30008)..."
    
    local captain_hex
    captain_hex=$(get_captain_keys)
    assert_not_empty "$captain_hex" "Captain's HEX should be available"
    
    # Query for profile badges
    local filters_json="{\"kinds\":[30008],\"authors\":[\"$captain_hex\"]}"
    local result
    result=$(query_nostr_events 30008 "$filters_json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        test_log_success "Profile badges found on Nostr relay"
        
        # Validate profile badges structure
        local event_kind=$(echo "$result" | jq -r '.kind // empty' 2>/dev/null)
        assert_equal "30008" "$event_kind" "Event should be kind 30008"
        
        # Check for badge references (tag a)
        local badge_refs=$(echo "$result" | jq -r '.tags[] | select(.[0] == "a") | .[1] // empty' 2>/dev/null)
        if [[ -n "$badge_refs" ]]; then
            test_log_success "Profile badges reference badge definitions"
        fi
    else
        test_log_warning "No profile badges found (user may not have selected badges for profile)"
    fi
}

# Test badge image generation script
test_badge_image_generation() {
    test_log_info "Testing badge image generation script..."
    
    local generate_script="$HOME/.zen/Astroport.ONE/IA/generate_badge_image.sh"
    
    if [[ ! -f "$generate_script" ]]; then
        test_log_warning "generate_badge_image.sh not found, skipping image generation tests"
        return 0
    fi
    
    assert_file_exists "$generate_script" "Badge image generation script should exist"
    
    # Check if script is executable
    if [[ -x "$generate_script" ]]; then
        test_log_success "Badge image generation script is executable"
    else
        test_log_warning "Badge image generation script is not executable"
    fi
    
    # Test script help
    local help_result
    help_result=$("$generate_script" 2>&1)
    local help_exit=$?
    
    if [[ $help_exit -ne 0 ]]; then
        # Script should show usage when called without arguments
        if echo "$help_result" | grep -q "Usage:"; then
            test_log_success "Badge image generation script shows usage"
        fi
    fi
}

# Test badge integration with permits
test_badge_permit_integration() {
    test_log_info "Testing badge integration with permits..."
    
    local g1_hex
    g1_hex=$(get_uplanet_g1_keys)
    assert_not_empty "$g1_hex" "UPLANETNAME_G1 HEX should be available"
    
    # Query for credentials with badges
    local filters_cred="{\"kinds\":[30503],\"authors\":[\"$g1_hex\"]}"
    local cred_result
    cred_result=$(query_nostr_events 30503 "$filters_cred" 2>/dev/null)
    
    if [[ -n "$cred_result" ]]; then
        # Get permit_id from credential
        local permit_id=$(echo "$cred_result" | jq -r '.tags[] | select(.[0] == "permit_id") | .[1] // empty' 2>/dev/null | head -1)
        
        if [[ -n "$permit_id" ]]; then
            test_log_success "Credential has permit_id: $permit_id"
            
            # Check if badge exists for this permit
            local badge_id=$(echo "$permit_id" | tr '[:upper:]' '[:lower:]' | sed 's/PERMIT_/permit_/')
            local filters_badge="{\"kinds\":[30009],\"authors\":[\"$g1_hex\"],\"#d\":[\"$badge_id\"]}"
            local badge_result
            badge_result=$(query_nostr_events 30009 "$filters_badge" 2>/dev/null)
            
            if [[ -n "$badge_result" ]]; then
                test_log_success "Badge exists for permit: $permit_id"
            else
                test_log_warning "No badge found for permit: $permit_id (may not have been generated yet)"
            fi
        fi
    else
        test_log_warning "No credentials found to test badge integration"
    fi
}

# Test badge display functions
test_badge_display_functions() {
    test_log_info "Testing badge display functions..."
    
    local common_js="$HOME/.zen/UPlanet/earth/common.js"
    
    if [[ ! -f "$common_js" ]]; then
        test_log_warning "common.js not found, skipping display function tests"
        return 0
    fi
    
    assert_file_exists "$common_js" "common.js should exist"
    
    # Check for badge-related functions
    local functions=(
        "fetchBadgeAwards"
        "fetchBadgeDefinition"
        "fetchBadgeDefinitions"
        "fetchProfileBadges"
        "fetchUserBadges"
        "renderBadge"
        "displayUserBadges"
    )
    
    local found_functions=0
    for func in "${functions[@]}"; do
        if grep -q "function $func\|$func.*function\|$func.*=" "$common_js"; then
            ((found_functions++))
            test_log_success "Function $func found in common.js"
        else
            test_log_warning "Function $func not found in common.js"
        fi
    done
    
    if [[ $found_functions -gt 0 ]]; then
        test_log_success "Badge display functions are implemented ($found_functions/${#functions[@]})"
    fi
}

# Test badge synchronization
test_badge_synchronization() {
    test_log_info "Testing badge synchronization (NIP-101)..."
    
    # Check if badge kinds are in sync scripts
    local sync_script="$HOME/.zen/workspace/NIP-101/backfill_constellation.sh"
    
    if [[ ! -f "$sync_script" ]]; then
        test_log_warning "backfill_constellation.sh not found, skipping synchronization tests"
        return 0
    fi
    
    # Check for badge kinds in sync script
    local badge_kinds=("8" "30008" "30009")
    local found_kinds=0
    
    for kind in "${badge_kinds[@]}"; do
        if grep -q "\"$kind\"" "$sync_script" || grep -q "'$kind'" "$sync_script"; then
            ((found_kinds++))
            test_log_success "Badge kind $kind found in sync script"
        else
            test_log_warning "Badge kind $kind not found in sync script"
        fi
    done
    
    if [[ $found_kinds -eq ${#badge_kinds[@]} ]]; then
        test_log_success "All badge kinds are included in synchronization"
    fi
}

# Main test execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  Badge System Tests (NIP-58)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    test_badge_definition
    test_badge_award
    test_profile_badges
    test_badge_image_generation
    test_badge_permit_integration
    test_badge_display_functions
    test_badge_synchronization
    
    print_test_summary
    exit $?
}

# Run main function
main "$@"

