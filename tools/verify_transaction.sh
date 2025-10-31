#!/bin/bash
################################################################################
# verify_transaction.sh
# Background script to verify transactions after 1 hour and send Nostr notifications
#
# Usage: verify_transaction.sh <source_pubkey> <amount_g1> <reference> <transaction_type> <email> <zen_amount>
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

SOURCE_PUBKEY="$1"
AMOUNT_G1="$2"
REFERENCE="$3"
TRANSACTION_TYPE="$4"
USER_EMAIL="$5"
ZEN_AMOUNT="$6"
VERIFY_DELAY="${7:-3600}"  # Default: 1 hour in seconds

# Wait for the specified delay (default 1 hour)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verification scheduled for transaction in ${VERIFY_DELAY} seconds"
sleep "$VERIFY_DELAY"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting verification for transaction: ${REFERENCE:0:50}..."

# Check if transaction is in history
HISTORY_JSON=$(silkaj --json money history "$SOURCE_PUBKEY" 2>/dev/null)

if [[ $? -eq 0 ]]; then
    # Search for the transaction in history by reference
    # silkaj history uses "Reference" field (with capital R)
    # Try to match the reference (may be truncated in history)
    REFERENCE_SHORT=$(echo "$REFERENCE" | cut -c1-50)
    
    # Check if transaction exists in history
    # History format: { "Date": "...", "Reference": "...", ... }
    FOUND=$(echo "$HISTORY_JSON" | jq -r --arg ref "$REFERENCE_SHORT" '.history[] | select(.["Reference"] != null and (.["Reference"] | contains($ref)))' 2>/dev/null)
    
    if [[ -n "$FOUND" ]]; then
        # Transaction found - send success notification
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Transaction confirmed in blockchain history"
        
        # Prepare Nostr message
        NOSTR_MESSAGE="✅ UPLANET Transaction Confirmed

Type: ${TRANSACTION_TYPE}
Amount: ${ZEN_AMOUNT} Ẑen (${AMOUNT_G1} Ğ1)
Reference: ${REFERENCE:0:80}...
User: ${USER_EMAIL}
Status: Confirmed on blockchain

Verified: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        
        # Send Nostr notification to captain
        if [[ -n "$CAPTAINEMAIL" && -f "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr" ]]; then
            python3 "${MY_PATH}/nostr_send_note.py" \
                --keyfile "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr" \
                --content "$NOSTR_MESSAGE" \
                --kind 1 \
                2>/dev/null
            
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📡 Success notification sent via Nostr"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  Cannot send Nostr notification (CAPTAINEMAIL not configured)"
        fi
        exit 0
    else
        # Transaction not found - send alert
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Transaction NOT found in blockchain history"
        
        # Prepare Nostr alert message
        NOSTR_ALERT="🚨 UPLANET Transaction Verification Failed

Type: ${TRANSACTION_TYPE}
Amount: ${ZEN_AMOUNT} Ẑen (${AMOUNT_G1} Ğ1)
Reference: ${REFERENCE:0:80}...
User: ${USER_EMAIL}
Status: NOT FOUND in blockchain history

⚠️ Action required: Please verify transaction manually
Verified: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        
        # Send Nostr alert to captain
        if [[ -n "$CAPTAINEMAIL" && -f "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr" ]]; then
            python3 "${MY_PATH}/nostr_send_note.py" \
                --keyfile "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr" \
                --content "$NOSTR_ALERT" \
                --kind 1 \
                2>/dev/null
            
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📡 Alert notification sent via Nostr"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  Cannot send Nostr alert (CAPTAINEMAIL not configured)"
        fi
        exit 1
    fi
else
    # Error getting history
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Error retrieving transaction history"
    
    # Send error alert
    if [[ -n "$CAPTAINEMAIL" && -f "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr" ]]; then
        NOSTR_ERROR="⚠️ UPLANET Transaction Verification Error

Cannot retrieve blockchain history for verification.
Reference: ${REFERENCE:0:80}...
User: ${USER_EMAIL}

Please verify manually.
Error time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        
        python3 "${MY_PATH}/nostr_send_note.py" \
            --keyfile "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr" \
            --content "$NOSTR_ERROR" \
            --kind 1 \
            2>/dev/null
    fi
    exit 1
fi

