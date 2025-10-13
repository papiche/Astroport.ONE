#!/bin/bash
########################################################################
# NOSTR Captain Broadcast Script
# Sends a message from captain's NOSTR account to all MULTIPASS network users
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Default message if none provided
DEFAULT_MESSAGE="🔔 Captain's Broadcast - UPlanet Network

This is a broadcast message from the UPlanet Captain to all MULTIPASS users.

🌍 UPlanet Network Communication
📅 $(date -u +"%Y-%m-%d %H:%M:%S UTC")
👨‍✈️ Captain: ${CAPTAINEMAIL:-unknown}

This message was sent via NOSTR to all network users."

# Parse parameters
MESSAGE="$1"
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [message] [options]"
            echo ""
            echo "Send a NOSTR message from captain to all network users"
            echo ""
            echo "Arguments:"
            echo "  message     Message to send (default: test message)"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be sent without actually sending"
            echo "  --verbose    Show detailed output"
            echo "  --help       Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 \"Hello network!\""
            echo "  $0 --dry-run --verbose"
            echo "  $0 \"Important announcement\" --verbose"
            exit 0
            ;;
        *)
            if [[ -z "$MESSAGE" ]]; then
                MESSAGE="$1"
            fi
            shift
            ;;
    esac
done

# Use default message if none provided
if [[ -z "$MESSAGE" ]]; then
    MESSAGE="$DEFAULT_MESSAGE"
fi

echo "🚀 UPlanet NOSTR Broadcast Test"
echo "================================"
echo "📧 Captain: ${CAPTAINEMAIL:-unknown}"
echo "📝 Message: ${MESSAGE:0:50}..."
echo "🔍 Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE")"
echo ""

# Check if captain's NOSTR keys exist
if [[ -z "$CAPTAINEMAIL" ]]; then
    echo "❌ Error: CAPTAINEMAIL not set"
    exit 1
fi

CAPTAIN_NOSTR_FILE="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
if [[ ! -s "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr" ]]; then
    echo "❌ Error: Captain's NOSTR keys not found at $HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    exit 1
fi

# Load captain's NOSTR keys
source "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
if [[ -z "$NSEC" ]]; then
    echo "❌ Error: NSEC not found in captain's NOSTR file"
    exit 1
fi

echo "✅ Captain's NOSTR keys loaded: ${NSEC:0:20}..."
echo ""

# Get all network users
echo "🔍 Discovering network users..."
USERS_JSON=$($MY_PATH/search_for_this_hex_in_uplanet.sh --json --multipass 2>/dev/null)

if [[ -z "$USERS_JSON" ]]; then
    echo "❌ Error: No users found in network"
    exit 1
fi

# Parse users and count
USER_COUNT=$(echo "$USERS_JSON" | jq length 2>/dev/null || echo "0")
echo "👥 Found $USER_COUNT users in network"

if [[ "$USER_COUNT" -eq 0 ]]; then
    echo "❌ No users found"
    exit 1
fi

# Show users if verbose
if [[ "$VERBOSE" = true ]]; then
    echo ""
    echo "📋 Network users:"
    echo "$USERS_JSON" | jq -r '.[] | "  • \(.hex) (\(.source))"' 2>/dev/null
    echo ""
fi

# Confirm before sending
if [[ "$DRY_RUN" = false ]]; then
    echo ""
    echo "⚠️  This will send a NOSTR message to $USER_COUNT users"
    echo "📝 Message: ${MESSAGE:0:100}..."
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled by user"
        exit 0
    fi
fi

# Send messages
echo ""
echo "📨 Sending messages..."
echo "===================="

SUCCESS_COUNT=0
FAILED_COUNT=0
TOTAL_COUNT=0

# Process each user
echo "$USERS_JSON" | jq -r '.[] | .hex' 2>/dev/null | while read -r user_hex; do
    if [[ -n "$user_hex" ]]; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        
        echo -n "📤 Sending to ${user_hex:0:16}... "
        
        if [[ "$DRY_RUN" = true ]]; then
            echo "✅ (DRY RUN)"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            # Send NOSTR DM
            if python3 "$MY_PATH/nostr_send_dm.py" "$NSEC" "$user_hex" "$MESSAGE" "$myRELAY" >/dev/null 2>&1; then
                echo "✅"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "❌"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        fi
        
        # Small delay to avoid overwhelming the relay
        sleep 0.5
    fi
done

# Final statistics
echo ""
echo "📊 Broadcast Results"
echo "==================="
echo "📤 Total sent: $TOTAL_COUNT"
echo "✅ Successful: $SUCCESS_COUNT"
echo "❌ Failed: $FAILED_COUNT"

if [[ "$DRY_RUN" = false ]]; then
    if [[ $SUCCESS_COUNT -gt 0 ]]; then
        echo ""
        echo "🎉 Broadcast completed!"
        echo "💡 Users should receive the message in their NOSTR clients"
    else
        echo ""
        echo "⚠️  No messages were sent successfully"
        echo "💡 Check relay connectivity and captain's NOSTR keys"
    fi
else
    echo ""
    echo "🔍 This was a dry run - no actual messages were sent"
fi

exit 0
