#!/bin/bash
########################################################################
# NOSTR Captain Broadcast Script (Secure DMs Enhanced)
# Sends a secure encrypted message from captain's NOSTR account to all MULTIPASS network users
# Features: NIP-44 encryption, metadata protection, gift wrapping
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Default message if none provided
DEFAULT_MESSAGE="🔔 Captain's Secure Broadcast - UPlanet Network

This is a secure encrypted broadcast message from the UPlanet Captain to all MULTIPASS users.

🌍 UPlanet Network Communication
🔐 Enhanced Security: NIP-44 encryption, metadata protection
📅 $(date -u +"%Y-%m-%d %H:%M:%S UTC")
👨‍✈️ Captain: ${CAPTAINEMAIL:-unknown}

This message was sent via secure NOSTR DMs with enhanced privacy features."

# Parse parameters
MESSAGE="$1"
DRY_RUN=false
VERBOSE=false
SECURE_MODE=false
GIFT_WRAP=false
METADATA_PROTECTION=false

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
        --secure-mode)
            SECURE_MODE=true
            GIFT_WRAP=true
            METADATA_PROTECTION=true
            shift
            ;;
        --gift-wrap)
            GIFT_WRAP=true
            shift
            ;;
        --metadata-protection)
            METADATA_PROTECTION=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [message] [options]"
            echo ""
            echo "Send a secure NOSTR message from captain to all network users"
            echo ""
            echo "Arguments:"
            echo "  message     Message to send (default: test message)"
            echo ""
            echo "Options:"
            echo "  --dry-run              Show what would be sent without actually sending"
            echo "  --verbose              Show detailed output"
            echo "  --secure-mode          Enable all security features (gift-wrap + metadata-protection)"
            echo "  --gift-wrap            Enable NIP-17 gift wrapping for additional privacy"
            echo "  --metadata-protection  Enable metadata protection and obfuscation"
            echo "  --help                 Show this help"
            echo ""
            echo "Security Features:"
            echo "  • NIP-44 encryption (ChaCha20-Poly1305) - enhanced security"
            echo "  • Metadata protection - obfuscates timing and length analysis"
            echo "  • Gift wrapping (NIP-17) - hides sender identity"
            echo "  • Rate limiting - prevents surveillance and relay overload"
            echo ""
            echo "Examples:"
            echo "  $0 \"Hello network!\""
            echo "  $0 --dry-run --verbose"
            echo "  $0 \"Important announcement\" --secure-mode --verbose"
            echo "  $0 \"Sensitive info\" --gift-wrap --metadata-protection"
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

echo "🚀 UPlanet Secure NOSTR Broadcast"
echo "=================================="
echo "📧 Captain: ${CAPTAINEMAIL:-unknown}"
echo "📝 Message: ${MESSAGE:0:50}..."
echo "🔍 Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE")"
echo "🔐 Security Features:"
echo "   • NIP-44 encryption (ChaCha20-Poly1305)"
if [[ "$GIFT_WRAP" = true ]]; then
    echo "   • Gift wrapping (NIP-17) - hides sender identity"
fi
if [[ "$METADATA_PROTECTION" = true ]]; then
    echo "   • Metadata protection - obfuscates timing/length"
fi
if [[ "$SECURE_MODE" = true ]]; then
    echo "   • Secure mode - all privacy features enabled"
fi
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

# Create temporary files for counters
TEMP_DIR=$(mktemp -d)
SUCCESS_FILE="$TEMP_DIR/success"
FAILED_FILE="$TEMP_DIR/failed"
TOTAL_FILE="$TEMP_DIR/total"

# Initialize counters
echo "0" > "$SUCCESS_FILE"
echo "0" > "$FAILED_FILE"
echo "0" > "$TOTAL_FILE"

# Process each user
echo "$USERS_JSON" | jq -r '.[] | .hex' 2>/dev/null | while read -r user_hex; do
    if [[ -n "$user_hex" ]]; then
        # Increment total count
        current_total=$(cat "$TOTAL_FILE")
        echo $((current_total + 1)) > "$TOTAL_FILE"
        
        echo -n "📤 Sending to ${user_hex:0:16}... "
        
        if [[ "$DRY_RUN" = true ]]; then
            echo "✅ (DRY RUN)"
            current_success=$(cat "$SUCCESS_FILE")
            echo $((current_success + 1)) > "$SUCCESS_FILE"
        else
            # Build secure DM command with options
            SECURE_DM_CMD="python3 \"$MY_PATH/nostr_send_secure_dm.py\" \"$NSEC\" \"$user_hex\" \"$MESSAGE\" \"$myRELAY\""
            
            # Add security options
            if [[ "$GIFT_WRAP" = true ]]; then
                SECURE_DM_CMD="$SECURE_DM_CMD --gift-wrap"
            fi
            if [[ "$METADATA_PROTECTION" = true ]]; then
                SECURE_DM_CMD="$SECURE_DM_CMD --metadata-protection"
            fi
            if [[ "$SECURE_MODE" = true ]]; then
                SECURE_DM_CMD="$SECURE_DM_CMD --secure-mode"
            fi
            
            # Send secure NOSTR DM
            if eval "$SECURE_DM_CMD" >/dev/null 2>&1; then
                echo "✅"
                current_success=$(cat "$SUCCESS_FILE")
                echo $((current_success + 1)) > "$SUCCESS_FILE"
            else
                echo "❌"
                current_failed=$(cat "$FAILED_FILE")
                echo $((current_failed + 1)) > "$FAILED_FILE"
            fi
        fi
        
        # Small delay to avoid overwhelming the relay
        sleep 0.5
    fi
done

# Read final counts
TOTAL_COUNT=$(cat "$TOTAL_FILE")
SUCCESS_COUNT=$(cat "$SUCCESS_FILE")
FAILED_COUNT=$(cat "$FAILED_FILE")

# Clean up temporary files
rm -rf "$TEMP_DIR"

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
        echo "🎉 Secure broadcast completed!"
        echo "💡 Users should receive the encrypted message in their NOSTR clients"
        echo "🔐 Security features applied:"
        echo "   • NIP-44 encryption (ChaCha20-Poly1305)"
        if [[ "$GIFT_WRAP" = true ]]; then
            echo "   • Gift wrapping (NIP-17) - sender identity hidden"
        fi
        if [[ "$METADATA_PROTECTION" = true ]]; then
            echo "   • Metadata protection - timing/length obfuscated"
        fi
        echo "   • Rate limiting - anti-surveillance measures"
    else
        echo ""
        echo "⚠️  No messages were sent successfully"
        echo "💡 Check relay connectivity and captain's NOSTR keys"
        echo "🔧 Try running with --verbose for detailed error information"
    fi
else
    echo ""
    echo "🔍 This was a dry run - no actual messages were sent"
    echo "🔐 Security features that would be applied:"
    echo "   • NIP-44 encryption (ChaCha20-Poly1305)"
    if [[ "$GIFT_WRAP" = true ]]; then
        echo "   • Gift wrapping (NIP-17) - sender identity hidden"
    fi
    if [[ "$METADATA_PROTECTION" = true ]]; then
        echo "   • Metadata protection - timing/length obfuscated"
    fi
fi

exit 0
