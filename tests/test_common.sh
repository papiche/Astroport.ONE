#!/bin/bash
###################################################################
# test_common.sh
# Common functions and utilities for test scripts
#
# This file is sourced by all test scripts to provide:
# - Environment setup
# - Common test functions
# - Logging utilities
# - NOSTR event helpers
###################################################################

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE is missing !!" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Test configuration
TEST_TEMP_DIR="$HOME/.zen/tmp/tests"
mkdir -p "$TEST_TEMP_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test state
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Logging functions
test_log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

test_log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
    ((TEST_COUNT++))
    ((PASS_COUNT++))
}

test_log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
    ((TEST_COUNT++))
    ((FAIL_COUNT++))
}

test_log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

# Assert functions
assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if eval "$condition"; then
        test_log_success "$message"
        return 0
    else
        test_log_error "$message"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if ! eval "$condition"; then
        test_log_success "$message"
        return 0
    else
        test_log_error "$message"
        return 1
    fi
}

assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" == "$actual" ]]; then
        test_log_success "$message"
        return 0
    else
        test_log_error "$message (expected: $expected, actual: $actual)"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    
    if [[ -n "$value" ]]; then
        test_log_success "$message"
        return 0
    else
        test_log_error "$message"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    if [[ -f "$file" ]]; then
        test_log_success "$message"
        return 0
    else
        test_log_error "$message"
        return 1
    fi
}

# Get captain's keys
get_captain_keys() {
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    
    if [[ ! -f "$captain_secret" ]]; then
        test_log_error "Captain's secret file not found: $captain_secret"
        return 1
    fi
    
    source "$captain_secret"
    
    if [[ -z "${HEX:-}" ]]; then
        test_log_error "HEX not found in captain's secret file"
        return 1
    fi
    
    if [[ -z "${NPUB:-}" ]]; then
        test_log_error "NPUB not found in captain's secret file"
        return 1
    fi
    
    echo "$HEX"
    return 0
}

get_captain_npub() {
    local captain_secret="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    
    if [[ ! -f "$captain_secret" ]]; then
        test_log_error "Captain's secret file not found: $captain_secret"
        return 1
    fi
    
    source "$captain_secret"
    echo "${NPUB:-}"
}

# Get UMAP keys for 0.00 0.00
get_umap_keys() {
    local lat="0.00"
    local lon="0.00"
    
    # Generate UMAP keys
    local umap_npub=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${lat}" "${UPLANETNAME}${lon}")
    local umap_hex=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$umap_npub")
    
    echo "$umap_hex"
    return 0
}

# Get UMAP NPUB for 0.00 0.00
get_umap_npub() {
    local lat="0.00"
    local lon="0.00"
    
    local umap_npub=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${lat}" "${UPLANETNAME}${lon}")
    echo "$umap_npub"
}

# Get UPLANETNAME_G1 keys
get_uplanet_g1_keys() {
    local g1_keyfile="$HOME/.zen/game/uplanet.G1.nostr"
    
    if [[ ! -f "$g1_keyfile" ]]; then
        test_log_warning "UPLANETNAME_G1 keyfile not found: $g1_keyfile"
        # Try to generate it
        if [[ -x "$HOME/.zen/Astroport.ONE/tools/keygen" ]]; then
            test_log_info "Generating UPLANETNAME_G1 keys..."
            $HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" >/dev/null 2>&1
        fi
    fi
    
    if [[ -f "$g1_keyfile" ]]; then
        source "$g1_keyfile"
        echo "${HEX:-}"
        return 0
    else
        test_log_error "UPLANETNAME_G1 keyfile not found and could not be generated"
        return 1
    fi
}

# Publish NOSTR event
publish_nostr_event() {
    local kind="$1"
    local content="$2"
    local tags_json="$3"
    local keyfile="$4"
    
    if [[ -z "$keyfile" ]]; then
        test_log_error "Keyfile required for NOSTR event"
        return 1
    fi
    
    local result
    result=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
        --keyfile "$keyfile" \
        --content "$content" \
        --relays "$myRELAY" \
        --tags "$tags_json" \
        --kind "$kind" \
        --json 2>&1)
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        return 0
    else
        test_log_error "Failed to publish NOSTR event: $result"
        return 1
    fi
}

# Query NOSTR events using nostr_get_events.sh
query_nostr_events() {
    local kind="$1"
    local filters_json="$2"
    
    # Parse filters_json to extract parameters for nostr_get_events.sh
    local nostr_get_events="$HOME/.zen/Astroport.ONE/tools/nostr_get_events.sh"
    
    if [[ ! -x "$nostr_get_events" ]]; then
        test_log_warning "nostr_get_events.sh not found, using strfry directly"
        # Fallback to strfry scan if available
        if [[ -x "$HOME/.zen/strfry/strfry" ]]; then
            cd "$HOME/.zen/strfry"
            local result
            result=$(./strfry scan "$filters_json" 2>/dev/null)
            cd - >/dev/null
            echo "$result"
            return 0
        else
            test_log_warning "strfry not available"
            return 1
        fi
    fi
    
    # Extract parameters from filters_json
    local authors=$(echo "$filters_json" | jq -r '.["authors"] // [] | join(",")' 2>/dev/null)
    local tag_d=$(echo "$filters_json" | jq -r '.["#d"] // [] | .[0] // empty' 2>/dev/null)
    local tag_p=$(echo "$filters_json" | jq -r '.["#p"] // [] | .[0] // empty' 2>/dev/null)
    local tag_e=$(echo "$filters_json" | jq -r '.["#e"] // [] | .[0] // empty' 2>/dev/null)
    local tag_t=$(echo "$filters_json" | jq -r '.["#t"] // [] | join(",")' 2>/dev/null)
    local tag_g=$(echo "$filters_json" | jq -r '.["#g"] // [] | .[0] // empty' 2>/dev/null)
    local tag_ipfs_node=$(echo "$filters_json" | jq -r '.["#ipfs_node"] // [] | .[0] // empty' 2>/dev/null)
    local since=$(echo "$filters_json" | jq -r '.since // empty' 2>/dev/null)
    local until=$(echo "$filters_json" | jq -r '.until // empty' 2>/dev/null)
    local limit=$(echo "$filters_json" | jq -r '.limit // 100' 2>/dev/null)
    
    # Build command
    local cmd="$nostr_get_events --kind $kind --limit $limit"
    
    [[ -n "$authors" && "$authors" != "null" ]] && cmd="$cmd --author \"$authors\""
    [[ -n "$tag_d" && "$tag_d" != "null" ]] && cmd="$cmd --tag-d \"$tag_d\""
    [[ -n "$tag_p" && "$tag_p" != "null" ]] && cmd="$cmd --tag-p \"$tag_p\""
    [[ -n "$tag_e" && "$tag_e" != "null" ]] && cmd="$cmd --tag-e \"$tag_e\""
    [[ -n "$tag_t" && "$tag_t" != "null" ]] && cmd="$cmd --tag-t \"$tag_t\""
    [[ -n "$tag_g" && "$tag_g" != "null" ]] && cmd="$cmd --tag-g \"$tag_g\""
    [[ -n "$since" && "$since" != "null" ]] && cmd="$cmd --since $since"
    [[ -n "$until" && "$until" != "null" ]] && cmd="$cmd --until $until"
    
    # Execute command
    local result
    result=$(eval "$cmd" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && -n "$result" ]]; then
        echo "$result"
        return 0
    else
        # Fallback to strfry scan
        if [[ -x "$HOME/.zen/strfry/strfry" ]]; then
            cd "$HOME/.zen/strfry"
            result=$(./strfry scan "$filters_json" 2>/dev/null)
            cd - >/dev/null
            echo "$result"
            return 0
        fi
        return 1
    fi
}

# Wait for NOSTR event propagation
wait_for_nostr_event() {
    local event_id="$1"
    local max_wait="${2:-10}"
    
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        local result
        result=$(query_nostr_events 1 "{\"ids\":[\"$event_id\"]}" 2>/dev/null)
        
        if [[ -n "$result" ]] && echo "$result" | jq -e '.id' >/dev/null 2>&1; then
            return 0
        fi
        
        sleep 1
        ((waited++))
    done
    
    return 1
}

# Cleanup function
cleanup_test() {
    test_log_info "Cleaning up test artifacts..."
    # Remove temporary files older than 1 hour
    find "$TEST_TEMP_DIR" -type f -mmin +60 -delete 2>/dev/null || true
}

# Print test summary
print_test_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Test Summary"
    echo "═══════════════════════════════════════════════════════════"
    echo "Total tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo ""
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        test_log_success "All tests passed!"
        return 0
    else
        test_log_error "Some tests failed"
        return 1
    fi
}

# Setup trap for cleanup
trap cleanup_test EXIT

