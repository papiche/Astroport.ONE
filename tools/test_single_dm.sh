#!/bin/bash
# Simple test script for nostr_send_dm.py - tests one message at a time

echo "🧪 Simple NOSTR Direct Message Test"
echo "=================================="
echo ""

# Find the first .secret.nostr file
FIRST_SECRET=$(find ~/.zen/game/nostr -name "*@*" -type d -exec find {} -name ".secret.nostr" \; 2>/dev/null | head -1)

if [[ -z "$FIRST_SECRET" ]]; then
    echo "❌ No .secret.nostr files found"
    exit 1
fi

KNAME=$(basename $(dirname "$FIRST_SECRET"))
echo "📁 Using key: $KNAME"
echo "   File: $FIRST_SECRET"
echo ""

# Load the NSEC key
source "$FIRST_SECRET"
if [[ -z "$NSEC" ]]; then
    echo "❌ No NSEC found in $FIRST_SECRET"
    exit 1
fi

echo "🔑 NSEC: ${NSEC:0:20}..."

# Convert to hex
HEX_KEY=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC" 2>/dev/null)
if [[ -z "$HEX_KEY" || ${#HEX_KEY} -ne 64 ]]; then
    echo "❌ Failed to convert NSEC to hex"
    exit 1
fi

echo "🔑 HEX: ${HEX_KEY:0:8}..."
echo ""

# Test sending a message to self (for testing purposes)
echo "📨 Testing self-message (sending to own key)"
echo "-------------------------------------------"

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
test_message="Self-test message from $KNAME at $timestamp"

echo "Message: $test_message"
echo ""

echo "Sending message..."
result=$($HOME/.zen/Astroport.ONE/tools/nostr_send_dm.py "$NSEC" "$HEX_KEY" "$test_message" 2>&1)
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo "✅ Message sent successfully!"
else
    echo "❌ Failed to send message"
    echo "Error: $result"
fi

echo ""
echo "🎯 Test completed!"
echo "Check the relay for the message with event kind 4." 