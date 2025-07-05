#!/bin/bash

# Example script demonstrating #rec vs #rec2
# This shows the practical difference between the two memory recording methods

echo "=== #rec vs #rec2 Example ==="
echo ""

# Test parameters
TEST_USER="demo@example.com"
TEST_SLOT="7"
TEST_LAT="48.8566"
TEST_LON="2.3522"

# Clean up any existing test data
rm -rf "$HOME/.zen/tmp/flashmem/$TEST_USER"

echo "Scenario: Planning a weekend trip"
echo "User: $TEST_USER"
echo "Slot: $TEST_SLOT"
echo ""

# Step 1: User saves trip details with #rec
echo "=== Step 1: User saves trip details with #rec ==="
USER_NOTE="Weekend trip to Paris - Hotel booked for Saturday, visiting Louvre on Sunday"
USER_MESSAGE="#BRO #rec #7 $USER_NOTE"

echo "User message: $USER_MESSAGE"
echo "→ This will record ONLY the user's note in memory"
echo ""

# Simulate #rec behavior (user message only)
slot=0
for i in {1..12}; do
    if [[ "$USER_MESSAGE" =~ \#${i}\b ]]; then
        slot=$i
        break
    fi
done

# Create event JSON for user message
user_event_json='{"event":{"id":"user_note_123","content":"'"$USER_NOTE"'","pubkey":"userpubkey","created_at":'$(date +%s)'}}'
./short_memory.py "$user_event_json" "$TEST_LAT" "$TEST_LON" "$slot" "$TEST_USER"

echo "✅ User note recorded in slot $slot"
echo ""

# Step 2: User asks bot with #rec2
echo "=== Step 2: User asks bot with #rec2 ==="
USER_QUESTION="What should I pack for the trip?"
USER_MESSAGE_2="#BRO #rec2 #7 $USER_QUESTION"

echo "User message: $USER_MESSAGE_2"
echo "→ This will record ONLY the bot's response in memory"
echo ""

# Simulate bot response
BOT_RESPONSE="Based on your Paris trip plans, I recommend packing: comfortable walking shoes for the Louvre, a light jacket for evening walks, and a camera for photos. Don't forget your hotel confirmation and museum tickets!"

echo "Bot response: $BOT_RESPONSE"
echo ""

# Simulate #rec2 behavior (bot response only)
if [[ "$USER_MESSAGE_2" =~ \#rec2 ]]; then
    bot_event_json='{"event":{"id":"bot_response_456","content":"'"$BOT_RESPONSE"'","pubkey":"botpubkey","created_at":'$(date +%s)'}}'
    ./short_memory.py "$bot_event_json" "$TEST_LAT" "$TEST_LON" "$slot" "$TEST_USER"
    echo "✅ Bot response recorded in slot $slot"
else
    echo "❌ Bot response not recorded"
fi

echo ""

# Step 3: Show final memory state
echo "=== Step 3: Final Memory State ==="
MEMORY_FILE="$HOME/.zen/tmp/flashmem/$TEST_USER/slot$slot.json"

if [[ -f "$MEMORY_FILE" ]]; then
    echo "📝 Memory contents for slot $slot:"
    echo "================================"
    
    # Display memory in a readable format
    jq -r '.messages | to_entries | .[] | "📅 \(.value.timestamp | sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%d/%m/%Y %H:%M"))\n💬 \(.value.content)\n---"' "$MEMORY_FILE"
    
    echo ""
    echo "📊 Memory Analysis:"
    echo "=================="
    
    # Count messages
    MESSAGE_COUNT=$(jq '.messages | length' "$MEMORY_FILE")
    echo "Total messages in slot $slot: $MESSAGE_COUNT"
    
    # Show what each message contains
    echo ""
    echo "Message breakdown:"
    jq -r '.messages | to_entries | .[] | "Message \(.key + 1): \(.value.content | if length > 50 then .[:50] + "..." else . end)"' "$MEMORY_FILE"
    
else
    echo "❌ Memory file not found"
fi

echo ""
echo "=== Key Differences Demonstrated ==="
echo ""
echo "🔹 #rec behavior:"
echo "   - Records ONLY the user's message"
echo "   - Example: 'Weekend trip to Paris - Hotel booked...'"
echo ""
echo "🔹 #rec2 behavior:"
echo "   - Records ONLY the bot's response"
echo "   - Example: 'Based on your Paris trip plans, I recommend...'"
echo ""
echo "🔹 Combined result:"
echo "   - User has both their note AND the bot's advice"
echo "   - Complete conversation context preserved"
echo ""
echo "=== Usage Recommendations ==="
echo ""
echo "✅ Use #rec when:"
echo "   - Saving important information you want to remember"
echo "   - Recording meeting notes, ideas, or reminders"
echo "   - You want to keep your own thoughts/notes"
echo ""
echo "✅ Use #rec2 when:"
echo "   - Asking for advice you want to save"
echo "   - Getting explanations you want to reference later"
echo "   - You want to keep the bot's helpful responses"
echo ""
echo "✅ Use both together for:"
echo "   - Complete conversation history"
echo "   - Project planning with both notes and advice"
echo "   - Learning sessions with questions and answers"
echo ""
echo "Example workflow:"
echo "  #rec #7 Meeting notes: Discussed Q4 goals
echo "  #BRO #rec2 #7 What were our action items?
echo "  #mem #7 Show complete meeting record"
echo ""
echo "Test completed! 🎉" 