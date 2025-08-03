#!/bin/bash

# Test script for Global uMARKET Aggregation
# Tests the aggregation of local and swarm market data

set -e

echo "🧪 Testing Global uMARKET Aggregation System..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create test directory structure
TEST_DIR="/tmp/test_global_umarket_$(date +%s)"
mkdir -p "$TEST_DIR"

echo "📁 Test directory: $TEST_DIR"

# Copy the _uMARKET.aggregate.sh script
cp "$SCRIPT_DIR/_uMARKET.aggregate.sh" "$TEST_DIR/"
chmod +x "$TEST_DIR/_uMARKET.aggregate.sh"

# Create mock local data structure
LOCAL_STRUCTURE="$TEST_DIR/mock_local"
mkdir -p "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/ads"
mkdir -p "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/Images"

# Create mock swarm data structure
SWARM_STRUCTURE="$TEST_DIR/mock_swarm"
mkdir -p "$SWARM_STRUCTURE/node1/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/ads"
mkdir -p "$SWARM_STRUCTURE/node1/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/Images"
mkdir -p "$SWARM_STRUCTURE/node2/UPLANET/__/_46_3/_46.5_3.2/_46.52_3.21/APP/uMARKET/ads"
mkdir -p "$SWARM_STRUCTURE/node2/UPLANET/__/_46_3/_46.5_3.2/_46.52_3.21/APP/uMARKET/Images"

# Create sample local advertisements
cat > "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/ads/local_ad_1.json" << 'EOF'
{
    "id": "local_message_1",
    "content": "🍎 Fresh organic apples from local garden! #market #organic #local",
    "author_pubkey": "local_author_1",
    "author_nprofile": "nostr:npub1local1",
    "created_at": 1703000000,
    "location": {
        "lat": 45.42,
        "lon": 2.31
    },
    "local_images": ["UMAP_local_45.42_2.31_apples.jpg"],
    "umap_id": "UMAP_local_45.42_2.31",
    "generated_at": 1703000000
}
EOF

cat > "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/ads/local_ad_2.json" << 'EOF'
{
    "id": "local_message_2",
    "content": "🚲 Vintage bicycle for sale, local pickup! #market #bicycle #vintage",
    "author_pubkey": "local_author_2",
    "author_nprofile": "nostr:npub1local2",
    "created_at": 1703001000,
    "location": {
        "lat": 45.42,
        "lon": 2.31
    },
    "local_images": ["UMAP_local_45.42_2.31_bicycle.jpg"],
    "umap_id": "UMAP_local_45.42_2.31",
    "generated_at": 1703001000
}
EOF

# Create sample swarm advertisements
cat > "$SWARM_STRUCTURE/node1/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/ads/swarm_ad_1.json" << 'EOF'
{
    "id": "swarm_message_1",
    "content": "📚 French literature books from swarm node! #market #books #literature",
    "author_pubkey": "swarm_author_1",
    "author_nprofile": "nostr:npub1swarm1",
    "created_at": 1703002000,
    "location": {
        "lat": 45.42,
        "lon": 2.31
    },
    "local_images": ["UMAP_swarm_45.42_2.31_books.jpg"],
    "umap_id": "UMAP_swarm_45.42_2.31",
    "generated_at": 1703002000
}
EOF

cat > "$SWARM_STRUCTURE/node2/UPLANET/__/_46_3/_46.5_3.2/_46.52_3.21/APP/uMARKET/ads/swarm_ad_2.json" << 'EOF'
{
    "id": "swarm_message_2",
    "content": "🎨 Handmade pottery from distant node! #market #art #handmade",
    "author_pubkey": "swarm_author_2",
    "author_nprofile": "nostr:npub1swarm2",
    "created_at": 1703003000,
    "location": {
        "lat": 46.52,
        "lon": 3.21
    },
    "local_images": ["UMAP_swarm_46.52_3.21_pottery.jpg"],
    "umap_id": "UMAP_swarm_46.52_3.21",
    "generated_at": 1703003000
}
EOF

# Create an old advertisement (should be filtered out)
cat > "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/ads/old_ad.json" << 'EOF'
{
    "id": "old_message",
    "content": "This is an old advertisement that should be filtered out",
    "author_pubkey": "old_author",
    "author_nprofile": "nostr:npub1old",
    "created_at": 1600000000,
    "location": {
        "lat": 45.42,
        "lon": 2.31
    },
    "local_images": [],
    "umap_id": "UMAP_old_45.42_2.31",
    "generated_at": 1600000000
}
EOF

# Create a malformed JSON file (should be filtered out)
cat > "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/ads/malformed.json" << 'EOF'
{
    "id": "malformed_message",
    "content": "This is a malformed JSON file
    "author_pubkey": "malformed_author",
    "created_at": 1703004000
}
EOF

# Create sample images
touch "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/Images/UMAP_local_45.42_2.31_apples.jpg"
touch "$LOCAL_STRUCTURE/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/Images/UMAP_local_45.42_2.31_bicycle.jpg"
touch "$SWARM_STRUCTURE/node1/UPLANET/__/_45_2/_45.4_2.3/_45.42_2.31/APP/uMARKET/Images/UMAP_swarm_45.42_2.31_books.jpg"
touch "$SWARM_STRUCTURE/node2/UPLANET/__/_46_3/_46.5_3.2/_46.52_3.21/APP/uMARKET/Images/UMAP_swarm_46.52_3.21_pottery.jpg"

echo "📁 Mock data created"

# Test 1: Local only aggregation
echo ""
echo "🧪 Test 1: Local only aggregation..."
cd "$TEST_DIR"

# Mock the local path
export IPFSNODEID="testnode"
mkdir -p ~/.zen/tmp/testnode
cp -r "$LOCAL_STRUCTURE/UPLANET" ~/.zen/tmp/testnode/

LOCAL_CID=$(./_uMARKET.aggregate.sh --local-only --output ./output_local --verbose)
echo "✅ Local aggregation test passed - CID: $LOCAL_CID"

# Verify local results
if [[ -f "./output_local/public/market.json" ]]; then
    local_ads=$(jq '.ads | length' "./output_local/public/market.json")
    echo "📊 Local advertisements found: $local_ads"
    
    if [[ $local_ads -eq 2 ]]; then
        echo "✅ Correct number of local ads (excluding old and malformed)"
    else
        echo "❌ Incorrect number of local ads: expected 2, got $local_ads"
        exit 1
    fi
else
    echo "❌ Local market.json not found"
    exit 1
fi

# Test 2: Swarm only aggregation
echo ""
echo "🧪 Test 2: Swarm only aggregation..."

# Mock the swarm path
mkdir -p ~/.zen/tmp/swarm
cp -r "$SWARM_STRUCTURE"/* ~/.zen/tmp/swarm/

SWARM_CID=$(./_uMARKET.aggregate.sh --swarm-only --output ./output_swarm --verbose)
echo "✅ Swarm aggregation test passed - CID: $SWARM_CID"

# Verify swarm results
if [[ -f "./output_swarm/public/market.json" ]]; then
    swarm_ads=$(jq '.ads | length' "./output_swarm/public/market.json")
    echo "📊 Swarm advertisements found: $swarm_ads"
    
    if [[ $swarm_ads -eq 2 ]]; then
        echo "✅ Correct number of swarm ads"
    else
        echo "❌ Incorrect number of swarm ads: expected 2, got $swarm_ads"
        exit 1
    fi
else
    echo "❌ Swarm market.json not found"
    exit 1
fi

# Test 3: Full aggregation
echo ""
echo "🧪 Test 3: Full aggregation (local + swarm)..."
FULL_CID=$(./_uMARKET.aggregate.sh --output ./output_full --verbose)
echo "✅ Full aggregation test passed - CID: $FULL_CID"

# Verify full results
if [[ -f "./output_full/public/market.json" ]]; then
    total_ads=$(jq '.ads | length' "./output_full/public/market.json")
    echo "📊 Total advertisements found: $total_ads"
    
    if [[ $total_ads -eq 4 ]]; then
        echo "✅ Correct total number of ads (2 local + 2 swarm)"
    else
        echo "❌ Incorrect total number of ads: expected 4, got $total_ads"
        exit 1
    fi
    
    # Check source distribution
    local_count=$(jq '.ads[] | select(._source == "local") | .id' "./output_full/public/market.json" | wc -l)
    swarm_count=$(jq '.ads[] | select(._source == "swarm") | .id' "./output_full/public/market.json" | wc -l)
    
    echo "📊 Source distribution: $local_count local, $swarm_count swarm"
    
    if [[ $local_count -eq 2 && $swarm_count -eq 2 ]]; then
        echo "✅ Correct source distribution"
    else
        echo "❌ Incorrect source distribution"
        exit 1
    fi
else
    echo "❌ Full market.json not found"
    exit 1
fi

# Test 4: Age filtering
echo ""
echo "🧪 Test 4: Age filtering..."
AGE_FILTERED_CID=$(./_uMARKET.aggregate.sh --max-age 1 --output ./output_age_filtered --verbose)
echo "✅ Age filtering test passed - CID: $AGE_FILTERED_CID"

# Verify age filtering (should exclude old ad)
if [[ -f "./output_age_filtered/public/market.json" ]]; then
    filtered_ads=$(jq '.ads | length' "./output_age_filtered/public/market.json")
    echo "📊 Age-filtered advertisements: $filtered_ads"
    
    if [[ $filtered_ads -eq 4 ]]; then
        echo "✅ Age filtering working correctly (excluded old ad)"
    else
        echo "❌ Age filtering not working correctly"
        exit 1
    fi
else
    echo "❌ Age-filtered market.json not found"
    exit 1
fi

# Test 5: Verify enhanced web interface
echo ""
echo "🧪 Test 5: Verifying enhanced web interface..."
if [[ -f "./output_full/_index.html" && -f "./output_full/index.html" ]]; then
    if grep -q "Global uMARKET" "./output_full/_index.html" && \
       grep -q "Local and Swarm data" "./output_full/_index.html" && \
       grep -q "source-badge" "./output_full/_index.html"; then
        echo "✅ Enhanced web interface generated correctly"
    else
        echo "❌ Enhanced web interface missing expected content"
        exit 1
    fi
else
    echo "❌ Web interface files not found"
    exit 1
fi

# Test 6: Verify image copying
echo ""
echo "🧪 Test 6: Verifying image copying..."
if [[ -d "./output_full/Images" ]]; then
    image_count=$(find "./output_full/Images" -type f | wc -l)
    echo "📊 Images copied: $image_count"
    
    if [[ $image_count -eq 4 ]]; then
        echo "✅ All images copied correctly"
    else
        echo "❌ Incorrect number of images: expected 4, got $image_count"
        exit 1
    fi
else
    echo "❌ Images directory not found"
    exit 1
fi

# Show final results
echo ""
echo "📋 Final Results:"
echo "   - Local aggregation: $LOCAL_CID"
echo "   - Swarm aggregation: $SWARM_CID"
echo "   - Full aggregation: $FULL_CID"
echo "   - Age filtered: $AGE_FILTERED_CID"

echo ""
echo "🎉 All Global uMARKET tests completed successfully!"
echo "💡 To view the full marketplace: http://127.0.0.1:8080/ipfs/$FULL_CID/"

# Cleanup
echo ""
echo "🧹 Cleaning up test data..."
rm -rf ~/.zen/tmp/testnode
rm -rf ~/.zen/tmp/swarm
rm -rf "$TEST_DIR"
echo "✅ Cleanup completed" 