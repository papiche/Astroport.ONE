#!/bin/bash

# Test script for uMARKET system
# This script creates sample market advertisements to test the uMARKET interface

set -e

echo "🧪 Testing uMARKET system..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create test directory structure
TEST_DIR="/tmp/test_umarket"
mkdir -p "$TEST_DIR/ads"
mkdir -p "$TEST_DIR/Images"

# Copy the generate_uMARKET.sh script to test directory
cp "$SCRIPT_DIR/generate_uMARKET.sh" "$TEST_DIR/"
chmod +x "$TEST_DIR/generate_uMARKET.sh"

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
    "umap_id": "UMAP_sample_48.8566_2.3522"
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
    "umap_id": "UMAP_sample_48.8566_2.3522"
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
    "umap_id": "UMAP_sample_48.8566_2.3522"
}
EOF

# Create sample images (empty files for testing)
touch "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_apples.jpg"
touch "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_bicycle.jpg"
touch "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_bicycle_detail.jpg"
touch "$TEST_DIR/Images/UMAP_sample_48.8566_2.3522_books.jpg"

echo "📁 Test data created in $TEST_DIR"

# Run the uMARKET generator
cd "$TEST_DIR"
echo "🛒 Generating uMARKET interface..."
UDRIVE_CID=$(./generate_uMARKET.sh .)

echo "✅ uMARKET interface generated successfully!"
echo "🌐 Market interface available at: /ipfs/$UDRIVE_CID"
echo "📊 Market data compiled to: public/market.json"

# Show the generated market.json
echo ""
echo "📋 Generated market.json content:"
cat public/market.json | jq .

echo ""
echo "🎉 Test completed successfully!"
echo "💡 To view the interface, visit: /ipfs/$UDRIVE_CID" 