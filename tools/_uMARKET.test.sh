#!/bin/bash

# Test script for uMARKET system
# This script creates sample market advertisements to test the uMARKET interface

set -e

echo "🧪 Testing uMARKET system..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create test directory structure
TEST_DIR="/tmp/test_umarket_$(date +%s)"
mkdir -p "$TEST_DIR/ads"
mkdir -p "$TEST_DIR/Images"

echo "📁 Test directory: $TEST_DIR"

# Copy the _uMARKET.generate.sh script to test directory
cp "$SCRIPT_DIR/_uMARKET.generate.sh" "$TEST_DIR/"
chmod +x "$TEST_DIR/_uMARKET.generate.sh"

# Create sample JSON advertisements
cat > "$TEST_DIR/ads/sample_ad_1.json" << 'EOF'
{
    "id": "sample_message_1",
    "content": "🍎 Fresh organic apples from my garden! #market #organic #local",
    "author_pubkey": "sample_author_1",
    "author_nprofile": "nostr:npub1sample1",
    "created_at": 1703000000,
    "location": {
        "lat": 48.8566,
        "lon": 2.3522
    },
    "local_images": ["UMAP_sample_48.8566_2.3522_apples.jpg"],
    "umap_id": "UMAP_sample_48.8566_2.3522",
    "generated_at": 1703000000
}
EOF

cat > "$TEST_DIR/ads/sample_ad_2.json" << 'EOF'
{
    "id": "sample_message_2",
    "content": "🚲 Vintage bicycle for sale, good condition! #market #bicycle #vintage",
    "author_pubkey": "sample_author_2",
    "author_nprofile": "nostr:npub1sample2",
    "created_at": 1703001000,
    "location": {
        "lat": 48.8566,
        "lon": 2.3522
    },
    "local_images": ["UMAP_sample_48.8566_2.3522_bicycle.jpg", "UMAP_sample_48.8566_2.3522_bicycle_detail.jpg"],
    "umap_id": "UMAP_sample_48.8566_2.3522",
    "generated_at": 1703001000
}
EOF

cat > "$TEST_DIR/ads/sample_ad_3.json" << 'EOF'
{
    "id": "sample_message_3",
    "content": "📚 French literature books collection #market #books #literature",
    "author_pubkey": "sample_author_3",
    "author_nprofile": "nostr:npub1sample3",
    "created_at": 1703002000,
    "location": {
        "lat": 48.8566,
        "lon": 2.3522
    },
    "local_images": ["UMAP_sample_48.8566_2.3522_books.jpg"],
    "umap_id": "UMAP_sample_48.8566_2.3522",
    "generated_at": 1703002000
}
EOF

# Create a malformed JSON file to test validation
cat > "$TEST_DIR/ads/malformed_ad.json" << 'EOF'
{
    "id": "malformed_message",
    "content": "This is a malformed JSON file
    "author_pubkey": "sample_author_4",
    "created_at": 1703003000
}
EOF

# Create sample images (valid image files for testing)
# Create a simple 1x1 pixel PNG image using base64
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_apples.jpg"
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_bicycle.jpg"
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_bicycle_detail.jpg"
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_books.jpg"

echo "📁 Test data created in $TEST_DIR"

# Test 1: Basic generation without validation
echo ""
echo "🧪 Test 1: Basic uMARKET generation..."
cd "$TEST_DIR"
UDRIVE_CID=$(./_uMARKET.generate.sh . 2>&1) || {
    echo "❌ Basic test failed"
    echo "Output: $UDRIVE_CID"
    exit 1
}
echo "✅ Basic test passed - CID: $UDRIVE_CID"

# Test 2: Generation with validation
echo ""
echo "🧪 Test 2: uMARKET generation with JSON validation..."
cd "$TEST_DIR"
if ./_uMARKET.generate.sh --validate . 2>&1 | grep -q "fichiers JSON invalides"; then
    echo "✅ Validation test passed - malformed JSON detected"
else
    echo "❌ Validation test failed - malformed JSON not detected"
    exit 1
fi

# Test 3: Generation with logging
echo ""
echo "🧪 Test 3: uMARKET generation with logging..."
cd "$TEST_DIR"
UDRIVE_CID_LOG=$(./_uMARKET.generate.sh --log .)
echo "✅ Logging test passed - CID: $UDRIVE_CID_LOG"

# Test 4: Generation with size limit
echo ""
echo "🧪 Test 4: uMARKET generation with size limit..."
cd "$TEST_DIR"
UDRIVE_CID_SIZE=$(./_uMARKET.generate.sh --max-size 1 .)
echo "✅ Size limit test passed - CID: $UDRIVE_CID_SIZE"

# Show the generated market.json
echo ""
echo "📋 Generated market.json content:"
if [[ -f "public/market.json" ]]; then
    cat public/market.json | jq .
else
    echo "❌ market.json not found"
    exit 1
fi

# Test 5: Verify file structure
echo ""
echo "🧪 Test 5: Verifying file structure..."
if [[ -f "_index.html" && -f "index.html" && -d "public" ]]; then
    echo "✅ File structure test passed"
else
    echo "❌ File structure test failed"
    exit 1
fi

# Test 6: Verify HTML content
echo ""
echo "🧪 Test 6: Verifying HTML content..."
if grep -q "uMARKET" "_index.html" && grep -q "marketplace" "_index.html"; then
    echo "✅ HTML content test passed"
else
    echo "❌ HTML content test failed"
    exit 1
fi

echo ""
echo "🎉 All tests completed successfully!"
echo "💡 To view the interface, visit: /ipfs/$UDRIVE_CID"
echo "🧹 Cleaning up test directory..."
rm -rf "$TEST_DIR"
echo "✅ Cleanup completed" 