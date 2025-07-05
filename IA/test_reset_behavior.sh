#!/bin/bash
# Test script for reset behavior

echo "Testing reset behavior for slot-based memory system..."

# Test data
TEST_USER="test@example.com"

# Create test directories and files
mkdir -p "$HOME/.zen/tmp/flashmem/$TEST_USER"

# Create test slot files
for i in {0..12}; do
    echo '{"user_id":"'$TEST_USER'","slot":'$i',"messages":[{"timestamp":"2024-01-01T12:00:00Z","content":"Test message for slot '$i'"}]}' > "$HOME/.zen/tmp/flashmem/$TEST_USER/slot$i.json"
done

echo "1. Created test slot files (0-12)"
ls -la "$HOME/.zen/tmp/flashmem/$TEST_USER/"

echo ""
echo "2. Testing reset specific slot (slot 3)..."
# Simulate #reset #3
rm -f "$HOME/.zen/tmp/flashmem/$TEST_USER/slot3.json"
echo "Slot 3 reset - remaining files:"
ls -la "$HOME/.zen/tmp/flashmem/$TEST_USER/"

echo ""
echo "3. Testing reset all slots with #all..."
# Simulate #reset #all
rm -f "$HOME/.zen/tmp/flashmem/$TEST_USER"/slot*.json
echo "All slots reset - remaining files:"
ls -la "$HOME/.zen/tmp/flashmem/$TEST_USER/"

echo ""
echo "4. Testing reset default (slot 0)..."
# Recreate slot 0 for testing
echo '{"user_id":"'$TEST_USER'","slot":0,"messages":[{"timestamp":"2024-01-01T12:00:00Z","content":"Test message for slot 0"}]}' > "$HOME/.zen/tmp/flashmem/$TEST_USER/slot0.json"
echo "Created slot 0 again"
ls -la "$HOME/.zen/tmp/flashmem/$TEST_USER/"

# Simulate #reset (should reset only slot 0)
rm -f "$HOME/.zen/tmp/flashmem/$TEST_USER/slot0.json"
echo "Default reset (slot 0) - remaining files:"
ls -la "$HOME/.zen/tmp/flashmem/$TEST_USER/"

echo ""
echo "5. Cleaning up test data..."
rm -rf "$HOME/.zen/tmp/flashmem/$TEST_USER"

echo "Reset behavior test completed!" 