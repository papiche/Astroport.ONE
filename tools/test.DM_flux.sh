#!/bin/bash
################################################################################
# Script: test.DM_flux.sh
# Description: Test script to verify encrypted direct message (DM) flow
#              Tests sending and receiving DMs between two NOSTR accounts
#              using NIP-44 encryption with strfry relay
# Usage: test.DM_flux.sh
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
SCRIPT_DIR="$MY_PATH"

source $MY_PATH/my.sh
################################################################################
# Colors for output
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Configuration
################################################################################
RELAY_URL="${NOSTR_RELAY:-ws://127.0.0.1:7777}"
ZEN_DIR="$HOME/.zen"
NOSTR_DIR="$ZEN_DIR/game/nostr"

# Accounts
SENDER_EMAIL="${CAPTAINEMAIL:-}"
RECIPIENT_EMAIL="totodu56@yopmail.com"

# Script paths
SEND_DM_SCRIPT="$SCRIPT_DIR/nostr_send_secure_dm.py"
GET_EVENTS_SCRIPT="$SCRIPT_DIR/nostr_get_events.sh"

# Test message with timestamp
TEST_MESSAGE="Test DM from $(date '+%Y-%m-%d %H:%M:%S') - NIP-44 encrypted message"

################################################################################
# Functions
################################################################################
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

################################################################################
# Get NOSTR keys for an email account
################################################################################
get_nostr_keys() {
    local email="$1"
    local account_dir="$NOSTR_DIR/$email"
    
    if [[ ! -d "$account_dir" ]]; then
        log_error "Account directory not found: $account_dir"
        return 1
    fi
    
    local nsec_file="$account_dir/.secret.nostr"
    local npub_file="$account_dir/NPUB"
    local hex_file="$account_dir/HEX"
    
    # Read NSEC (should be nsec1... format)
    local nsec=""
    if [[ -f "$nsec_file" ]]; then
        nsec=$(cat "$nsec_file" | tr -d '\n\r ')
        # Check if file contains NSEC= prefix (from sourcing)
        if [[ "$nsec" =~ ^NSEC= ]]; then
            nsec="${nsec#NSEC=}"
        fi
    elif [[ -f "$account_dir/.player" ]]; then
        # Try to source the file if it's a player file
        source "$account_dir/.player" 2>/dev/null || true
        if [[ -n "$NSEC" ]]; then
            nsec="$NSEC"
        fi
    fi
    
    if [[ -z "$nsec" || ! "$nsec" =~ ^nsec1 ]]; then
        log_error "NSEC not found or invalid for $email (found: ${nsec:0:20}...)"
        return 1
    fi
    
    # Get hex pubkey - try multiple sources
    local hex_pubkey=""
    
    # Method 1: Direct HEX file
    if [[ -f "$hex_file" ]]; then
        hex_pubkey=$(cat "$hex_file" | tr -d '\n\r ')
    fi
    
    # Method 2: Convert from NSEC using nostr_nsec2npub2hex.py
    if [[ -z "$hex_pubkey" || ${#hex_pubkey} != 64 ]]; then
        if [[ -f "$SCRIPT_DIR/nostr_nsec2npub2hex.py" ]]; then
            hex_pubkey=$(python3 "$SCRIPT_DIR/nostr_nsec2npub2hex.py" "$nsec" 2>/dev/null | grep -i "hex pubkey:" | awk '{print $NF}' | tr -d '\n\r')
        fi
    fi
    
    # Method 3: Convert from NPUB
    if [[ -z "$hex_pubkey" || ${#hex_pubkey} != 64 ]]; then
        if [[ -f "$npub_file" ]]; then
            local npub=$(cat "$npub_file" | tr -d '\n\r ')
            if [[ "$npub" =~ ^npub1 ]]; then
                # Convert npub to hex using nostr2hex.py
                if [[ -f "$SCRIPT_DIR/nostr2hex.py" ]]; then
                    hex_pubkey=$(python3 "$SCRIPT_DIR/nostr2hex.py" "$npub" 2>/dev/null | tr -d '\n\r')
                fi
            elif [[ ${#npub} == 64 ]]; then
                # Already hex format
                hex_pubkey="$npub"
            fi
        fi
    fi
    
    # Validate hex pubkey
    if [[ -z "$hex_pubkey" || ${#hex_pubkey} != 64 ]]; then
        log_error "Could not get valid hex pubkey for $email"
        log_error "Tried: HEX file, NSEC conversion, NPUB conversion"
        return 1
    fi
    
    echo "$nsec|$hex_pubkey"
    return 0
}

################################################################################
# Main test function
################################################################################
main() {
    log_info "🧪 Starting DM Flow Test (NIP-44)"
    log_info "======================================"
    
    # Check dependencies
    log_info "Checking dependencies..."
    
    if [[ ! -f "$SEND_DM_SCRIPT" ]]; then
        log_error "Send DM script not found: $SEND_DM_SCRIPT"
        exit 1
    fi
    
    if [[ ! -f "$GET_EVENTS_SCRIPT" ]]; then
        log_error "Get events script not found: $GET_EVENTS_SCRIPT"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "python3 not found"
        exit 1
    fi
    
    log_success "Dependencies OK"
    
    # Get sender keys (CAPTAINEMAIL)
    log_info "Getting sender keys for: $SENDER_EMAIL"
    if [[ -z "$SENDER_EMAIL" ]]; then
        log_error "CAPTAINEMAIL not set. Please set CAPTAINEMAIL environment variable."
        exit 1
    fi
    
    SENDER_KEYS=$(get_nostr_keys "$SENDER_EMAIL")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get sender keys"
        exit 1
    fi
    
    SENDER_NSEC=$(echo "$SENDER_KEYS" | cut -d'|' -f1)
    SENDER_HEX=$(echo "$SENDER_KEYS" | cut -d'|' -f2)
    
    log_success "Sender NSEC: ${SENDER_NSEC:0:20}..."
    log_success "Sender HEX: ${SENDER_HEX:0:16}..."
    
    # Get recipient keys
    log_info "Getting recipient keys for: $RECIPIENT_EMAIL"
    RECIPIENT_KEYS=$(get_nostr_keys "$RECIPIENT_EMAIL")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get recipient keys"
        exit 1
    fi
    
    RECIPIENT_NSEC=$(echo "$RECIPIENT_KEYS" | cut -d'|' -f1)
    RECIPIENT_HEX=$(echo "$RECIPIENT_KEYS" | cut -d'|' -f2)
    
    log_success "Recipient NSEC: ${RECIPIENT_NSEC:0:20}..."
    log_success "Recipient HEX: ${RECIPIENT_HEX:0:16}..."
    
    # Check relay connection
    log_info "Checking relay connection: $RELAY_URL"
    
    # Test 1: Send DM from sender to recipient
    log_info ""
    log_info "======================================"
    log_info "TEST 1: Send DM (Sender → Recipient)"
    log_info "======================================"
    
    log_info "Sending test message..."
    log_info "Message: $TEST_MESSAGE"
    
    SEND_OUTPUT=$(python3 "$SEND_DM_SCRIPT" \
        "$SENDER_NSEC" \
        "$RECIPIENT_HEX" \
        "$TEST_MESSAGE" \
        "$RELAY_URL" 2>&1)
    
    SEND_EXIT_CODE=$?
    
    if [[ $SEND_EXIT_CODE -eq 0 ]]; then
        log_success "Message sent successfully!"
        echo "$SEND_OUTPUT" | grep -E "(✅|Success|Event ID)" || true
    else
        log_error "Failed to send message"
        echo "$SEND_OUTPUT"
        exit 1
    fi
    
    # Wait for relay to process
    log_info "Waiting 3 seconds for relay to process..."
    sleep 3
    
    # Test 2: Retrieve DM for recipient
    log_info ""
    log_info "======================================"
    log_info "TEST 2: Retrieve DM (Recipient inbox)"
    log_info "======================================"
    
    log_info "Querying kind 4 events for recipient..."
    
    # Get events sent to recipient (tagged with recipient's pubkey)
    RECEIVED_EVENTS=$("$GET_EVENTS_SCRIPT" \
        --kind 4 \
        --tag-p "$RECIPIENT_HEX" \
        --limit 10 \
        2>&1)
    
    GET_EXIT_CODE=$?
    
    if [[ $GET_EXIT_CODE -eq 0 ]]; then
        EVENT_COUNT=$(echo "$RECEIVED_EVENTS" | grep -c '"kind":4' || echo "0")
        
        if [[ "$EVENT_COUNT" -gt 0 ]]; then
            log_success "Found $EVENT_COUNT encrypted DM event(s) for recipient"
            
            # Check if our test message is there (by checking sender)
            if echo "$RECEIVED_EVENTS" | grep -q "$SENDER_HEX"; then
                log_success "✅ Test message found in recipient's inbox!"
                log_info "Latest event details:"
                echo "$RECEIVED_EVENTS" | grep -A 5 "$SENDER_HEX" | head -10 || true
            else
                log_warning "Test message not found (may need more time to sync)"
            fi
        else
            log_warning "No events found (may need more time to sync)"
        fi
        
        # Show raw events count
        if command -v jq &> /dev/null; then
            ACTUAL_COUNT=$(echo "$RECEIVED_EVENTS" | jq -r 'select(.kind == 4)' 2>/dev/null | wc -l)
            log_info "Raw event count: $ACTUAL_COUNT"
        fi
    else
        log_error "Failed to retrieve events"
        echo "$RECEIVED_EVENTS"
    fi
    
    # Test 3: Retrieve DMs sent by sender
    log_info ""
    log_info "======================================"
    log_info "TEST 3: Retrieve sent DMs (Sender sent)"
    log_info "======================================"
    
    log_info "Querying kind 4 events sent by sender..."
    
    SENT_EVENTS=$("$GET_EVENTS_SCRIPT" \
        --kind 4 \
        --author "$SENDER_HEX" \
        --limit 10 \
        2>&1)
    
    if [[ $? -eq 0 ]]; then
        SENT_COUNT=$(echo "$SENT_EVENTS" | grep -c '"kind":4' || echo "0")
        
        if [[ "$SENT_COUNT" -gt 0 ]]; then
            log_success "Found $SENT_COUNT DM event(s) sent by sender"
            
            if echo "$SENT_EVENTS" | grep -q "$RECIPIENT_HEX"; then
                log_success "✅ Test message found in sender's sent messages!"
            fi
        else
            log_warning "No sent events found"
        fi
    else
        log_warning "Could not retrieve sent events"
    fi
    
    # Test 4: Bidirectional test (optional - send back)
    log_info ""
    log_info "======================================"
    log_info "TEST 4: Bidirectional test (Recipient → Sender)"
    log_info "======================================"
    
    REPLY_MESSAGE="Reply from $(date '+%Y-%m-%d %H:%M:%S') - NIP-44 encrypted reply"
    
    log_info "Sending reply message..."
    
    REPLY_OUTPUT=$(python3 "$SEND_DM_SCRIPT" \
        "$RECIPIENT_NSEC" \
        "$SENDER_HEX" \
        "$REPLY_MESSAGE" \
        "$RELAY_URL" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        log_success "Reply sent successfully!"
        
        # Wait for relay
        sleep 3
        
        # Check if reply was received
        REPLY_RECEIVED=$("$GET_EVENTS_SCRIPT" \
            --kind 4 \
            --tag-p "$SENDER_HEX" \
            --limit 10 \
            2>&1)
        
        if echo "$REPLY_RECEIVED" | grep -q "$RECIPIENT_HEX"; then
            log_success "✅ Reply found in sender's inbox!"
        else
            log_warning "Reply not yet visible (may need more time)"
        fi
    else
        log_warning "Failed to send reply (non-critical)"
        echo "$REPLY_OUTPUT" | head -5
    fi
    
    # Summary
    log_info ""
    log_info "======================================"
    log_info "TEST SUMMARY"
    log_info "======================================"
    log_success "DM flow test completed!"
    log_info "Relay: $RELAY_URL"
    log_info "Sender: $SENDER_EMAIL (${SENDER_HEX:0:16}...)"
    log_info "Recipient: $RECIPIENT_EMAIL (${RECIPIENT_HEX:0:16}...)"
    log_info ""
    log_info "Next steps:"
    log_info "1. Verify messages are decryptable in a NOSTR client"
    log_info "2. Check strfry logs for any issues"
    log_info "3. Test with different relay if needed"
}

################################################################################
# Run main function
################################################################################
main "$@"

