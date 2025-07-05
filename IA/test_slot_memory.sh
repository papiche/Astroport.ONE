#!/bin/bash
# Test script for slot-based memory system

echo "Testing slot-based memory system..."

# Test data
TEST_USER="test@example.com"
TEST_SLOT=3
TEST_CONTENT="This is a test message for slot $TEST_SLOT"

# Create test event JSON
TEST_EVENT_JSON='{"event":{"id":"test123","content":"'"$TEST_CONTENT"' #rec #'"$TEST_SLOT"'","pubkey":"testpubkey"}}'

echo "1. Testing memory recording..."
echo "Event JSON: $TEST_EVENT_JSON"
echo "User: $TEST_USER"
echo "Slot: $TEST_SLOT"

# Call short_memory.py
$HOME/.zen/Astroport.ONE/IA/short_memory.py "$TEST_EVENT_JSON" "0.00" "0.00" "$TEST_SLOT" "$TEST_USER"

echo ""
echo "2. Checking if memory file was created..."
MEMORY_FILE="$HOME/.zen/tmp/flashmem/$TEST_USER/slot$TEST_SLOT.json"
if [[ -f "$MEMORY_FILE" ]]; then
    echo "✅ Memory file created: $MEMORY_FILE"
    echo "Content:"
    cat "$MEMORY_FILE" | jq '.'
else
    echo "❌ Memory file not found: $MEMORY_FILE"
fi

echo ""
echo "3. Testing question.py with slot memory..."
TEST_QUESTION="What was the last message in slot $TEST_SLOT?"
ANSWER=$($HOME/.zen/Astroport.ONE/IA/question.py "$TEST_QUESTION" --user-id "$TEST_USER" --slot "$TEST_SLOT")
echo "Question: $TEST_QUESTION"
echo "Answer: $ANSWER"

echo ""
echo "4. Testing memory display..."
# Simulate #mem #3
MEMORY_DISPLAY=$(jq -r '.messages | to_entries | .[-5:] | .[] | "📅 \(.value.timestamp | sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%d/%m/%Y %H:%M"))\n💬 \(.value.content)\n---"' "$MEMORY_FILE" 2>/dev/null)
echo "Memory display for slot $TEST_SLOT:"
echo "$MEMORY_DISPLAY"

echo ""
echo "5. Cleaning up test data..."
rm -rf "$HOME/.zen/tmp/flashmem/$TEST_USER"

echo "Test completed!" 