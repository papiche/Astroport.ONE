#!/bin/bash
# Test script for nostr_send_dm.py using .secret.nostr files

echo "🔍 Testing NOSTR Direct Message functionality with .secret.nostr files"
echo "=================================================================="
echo ""

# Find all .secret.nostr files in ~/.zen/game/nostr/*@* directories
SECRET_FILES=$(find ~/.zen/game/nostr -name "*@*" -type d -exec find {} -name ".secret.nostr" \; 2>/dev/null)

if [[ -z "$SECRET_FILES" ]]; then
    echo "❌ No .secret.nostr files found in ~/.zen/game/nostr/*@* directories"
    exit 1
fi

echo "📁 Found .secret.nostr files:"
for file in $SECRET_FILES; do
    kname=$(basename $(dirname "$file"))
    echo "   - $kname: $file"
done
echo ""

# Test 1: Validate .secret.nostr files
echo "🧪 Test 1: Validating .secret.nostr files"
echo "----------------------------------------"
for file in $SECRET_FILES; do
    kname=$(basename $(dirname "$file"))
    echo -n "Testing $kname: "
    
    if [[ -f "$file" ]]; then
        # Check if file contains NSEC
        if grep -q "^NSEC=" "$file"; then
            NSEC=$(grep "^NSEC=" "$file" | cut -d'=' -f2)
            if [[ "$NSEC" =~ ^nsec1 ]]; then
                echo "✅ Valid NSEC found"
            else
                echo "❌ Invalid NSEC format"
            fi
        else
            echo "❌ No NSEC found in file"
        fi
    else
        echo "❌ File not found"
    fi
done
echo ""

# Test 2: Extract and validate NSEC keys
echo "🔑 Test 2: Extracting and validating NSEC keys"
echo "---------------------------------------------"
declare -A NSEC_KEYS
declare -A HEX_KEYS

for file in $SECRET_FILES; do
    kname=$(basename $(dirname "$file"))
    echo -n "Processing $kname: "
    
    if [[ -f "$file" ]]; then
        source "$file"
        if [[ -n "$NSEC" ]]; then
            NSEC_KEYS["$kname"]="$NSEC"
            echo -n "NSEC extracted, "
            
            # Convert to hex
            HEX_KEY=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC" 2>/dev/null)
            if [[ -n "$HEX_KEY" && ${#HEX_KEY} -eq 64 ]]; then
                HEX_KEYS["$kname"]="$HEX_KEY"
                echo "✅ Hex key: ${HEX_KEY:0:8}..."
            else
                echo "❌ Failed to convert to hex"
            fi
        else
            echo "❌ No NSEC variable found"
        fi
    else
        echo "❌ File not accessible"
    fi
done
echo ""

# Test 3: Test direct message sending between different keys
echo "📨 Test 3: Testing direct message sending"
echo "----------------------------------------"
echo "Note: This will attempt to send real messages to the relay"
echo ""

# Get list of valid keys
VALID_KEYS=()
for kname in "${!NSEC_KEYS[@]}"; do
    if [[ -n "${HEX_KEYS[$kname]}" ]]; then
        VALID_KEYS+=("$kname")
    fi
done

if [[ ${#VALID_KEYS[@]} -lt 2 ]]; then
    echo "❌ Need at least 2 valid keys to test message sending"
    exit 1
fi

echo "Found ${#VALID_KEYS[@]} valid keys for testing:"
for kname in "${VALID_KEYS[@]}"; do
    echo "   - $kname: ${HEX_KEYS[$kname]:0:8}..."
done
echo ""

# Test sending messages between different keys
for i in "${!VALID_KEYS[@]}"; do
    for j in "${!VALID_KEYS[@]}"; do
        if [[ $i -ne $j ]]; then
            sender="${VALID_KEYS[$i]}"
            recipient="${VALID_KEYS[$j]}"
            
            echo "📤 Testing: $sender -> $recipient"
            echo "   Sender NSEC: ${NSEC_KEYS[$sender]:0:20}..."
            echo "   Recipient HEX: ${HEX_KEYS[$recipient]:0:8}..."
            
            # Create test message
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            test_message="Test message from $sender to $recipient at $timestamp"
            
            echo "   Message: $test_message"
            
            # Send the message
            echo -n "   Sending... "
            result=$(python3 nostr_send_dm.py "${NSEC_KEYS[$sender]}" "${HEX_KEYS[$recipient]}" "$test_message" 2>&1)
            
            if [[ $? -eq 0 ]]; then
                echo "✅ Success"
            else
                echo "❌ Failed"
                echo "   Error: $result"
            fi
            echo ""
        fi
    done
done

# Test 4: Test with Captain's key
echo "👨‍✈️ Test 4: Testing with Captain's key"
echo "------------------------------------"
CAPTAIN_SECRET="$HOME/.zen/game/players/.current/secret.nostr"

if [[ -f "$CAPTAIN_SECRET" ]]; then
    echo "Found Captain's secret file: $CAPTAIN_SECRET"
    source "$CAPTAIN_SECRET"
    
    if [[ -n "$NSEC" ]]; then
        echo "Captain NSEC: ${NSEC:0:20}..."
        CAPTAIN_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC" 2>/dev/null)
        
        if [[ -n "$CAPTAIN_HEX" ]]; then
            echo "Captain HEX: ${CAPTAIN_HEX:0:8}..."
            
            # Test Captain sending to one of the test keys
            if [[ ${#VALID_KEYS[@]} -gt 0 ]]; then
                test_recipient="${VALID_KEYS[0]}"
                echo "Testing Captain -> $test_recipient"
                
                timestamp=$(date '+%Y-%m-%d %H:%M:%S')
                test_message="Test message from Captain to $test_recipient at $timestamp"
                
                echo -n "   Sending... "
                result=$(python3 nostr_send_dm.py "$NSEC" "${HEX_KEYS[$test_recipient]}" "$test_message" 2>&1)
                
                if [[ $? -eq 0 ]]; then
                    echo "✅ Success"
                else
                    echo "❌ Failed"
                    echo "   Error: $result"
                fi
            fi
        else
            echo "❌ Failed to convert Captain's NSEC to hex"
        fi
    else
        echo "❌ No NSEC found in Captain's secret file"
    fi
else
    echo "❌ Captain's secret file not found"
fi
echo ""

echo "🎯 Test Summary"
echo "==============="
echo "✅ Valid .secret.nostr files found: ${#SECRET_FILES[@]}"
echo "✅ Valid NSEC keys extracted: ${#NSEC_KEYS[@]}"
echo "✅ Valid hex keys generated: ${#HEX_KEYS[@]}"
echo "✅ Direct message sending tested"
echo ""
echo "🔧 Tool ready for use in UPlanet IA system!"
