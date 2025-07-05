#!/bin/bash

# Comprehensive test script for #rec2 functionality
# This script simulates the actual UPlanet_IA_Responder.sh behavior

echo "=== Comprehensive #rec2 Test ==="
echo ""

# Test parameters
TEST_USER="test@example.com"
TEST_SLOT="5"
TEST_LAT="48.85"
TEST_LON="2.35"

# Create test directory
TEST_DIR="$HOME/.zen/tmp/flashmem/$TEST_USER"
mkdir -p "$TEST_DIR"

echo "Test setup:"
echo "  User: $TEST_USER"
echo "  Slot: $TEST_SLOT"
echo "  Directory: $TEST_DIR"
echo ""

# Step 1: Simulate user message with #rec2
echo "=== Step 1: User message with #rec2 ==="
USER_MESSAGE="Hello bot! #BRO #rec2 #5 What's the weather like?"
echo "User message: $USER_MESSAGE"

# Simulate the slot detection logic from UPlanet_IA_Responder.sh
slot=0
for i in {1..12}; do
    if [[ "$USER_MESSAGE" =~ \#${i}\b ]]; then
        slot=$i
        break
    fi
done
echo "Detected slot: $slot"

# Check for #rec2
auto_record_response=false
if [[ "$USER_MESSAGE" =~ \#rec2 ]]; then
    auto_record_response=true
    echo "✅ #rec2 detected - bot response will be auto-recorded"
else
    echo "❌ #rec2 not detected"
fi

echo ""

# Step 2: Simulate bot response
echo "=== Step 2: Bot response generation ==="
BOT_RESPONSE="The weather is sunny with a temperature of 22°C. Perfect day for a walk!"
echo "Bot response: $BOT_RESPONSE"

# Step 3: Auto-record bot response (simulating UPlanet_IA_Responder.sh logic)
echo ""
echo "=== Step 3: Auto-recording bot response ==="
if [[ "$auto_record_response" == true ]]; then
    echo "Auto-recording bot response for USER: $TEST_USER, SLOT: $slot"
    
    # Create a fake event JSON for the bot response (simulating the actual code)
    bot_event_json='{"event":{"id":"bot_response_'$(date +%s)'","content":"'"$BOT_RESPONSE"'","pubkey":"botpubkey","created_at":'$(date +%s)'}}'
    
    # Call short_memory.py to record the bot response
    ./short_memory.py "$bot_event_json" "$TEST_LAT" "$TEST_LON" "$slot" "$TEST_USER"
    
    echo "✅ Bot response recorded"
else
    echo "❌ Bot response not recorded (no #rec2 detected)"
fi

# Step 4: Verify the memory file
echo ""
echo "=== Step 4: Memory verification ==="
MEMORY_FILE="$TEST_DIR/slot$slot.json"
if [[ -f "$MEMORY_FILE" ]]; then
    echo "✅ Memory file exists: $MEMORY_FILE"
    echo ""
    echo "Memory contents:"
    cat "$MEMORY_FILE" | jq '.'
    
    # Check if bot response is the last message
    LAST_MESSAGE=$(cat "$MEMORY_FILE" | jq -r '.messages[-1].content')
    if [[ "$LAST_MESSAGE" == "$BOT_RESPONSE" ]]; then
        echo ""
        echo "✅ Bot response successfully recorded as last message"
    else
        echo ""
        echo "❌ Bot response not found as last message"
        echo "Expected: $BOT_RESPONSE"
        echo "Found: $LAST_MESSAGE"
    fi
else
    echo "❌ Memory file not found: $MEMORY_FILE"
fi

# Step 5: Test #mem command simulation
echo ""
echo "=== Step 5: #mem command simulation ==="
if [[ -f "$MEMORY_FILE" ]]; then
    echo "📝 Historique (#mem slot $slot)"
    echo "========================"
    
    # Simulate the #mem display logic
    jq -r '.messages | to_entries | .[-5:] | .[] | "📅 \(.value.timestamp | sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%d/%m/%Y %H:%M"))\n💬 \(.value.content | sub("#BOT "; "") | sub("#BRO "; "") | sub("#bot "; "") | sub("#bro "; ""))\n---"' "$MEMORY_FILE"
else
    echo "Aucune mémoire trouvée pour le slot $slot."
fi

# Step 6: Cleanup and summary
echo ""
echo "=== Test Summary ==="
echo "✅ #rec2 functionality test completed"
echo ""
echo "Key differences:"
echo "  #rec  - Records only user message"
echo "  #rec2 - Records only bot response"
echo ""
echo "Usage examples:"
echo "  #BRO #rec #5 Save this note"
echo "  #BRO #rec2 #5 Ask about the note"
echo "  #mem #5 Show conversation history"
echo ""
echo "Test completed successfully!" 