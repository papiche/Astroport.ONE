#!/bin/bash
################################################################################
# nostr_get_umap_images.sh - Retrieve UMAP images from NOSTR profile CIDs
# Usage: nostr_get_umap_images.sh <UMAP_HEX> <OUTPUT_DIR> [--check-only]
#
# This script queries the NOSTR profile of a UMAP to get image CIDs,
# then fetches those images from IPFS. This avoids needing to sync
# large image files through the swarm.
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "$MY_PATH/../tools/my.sh"

UMAP_HEX="$1"
OUTPUT_DIR="$2"
CHECK_ONLY=false

[[ "$3" == "--check-only" ]] && CHECK_ONLY=true

if [[ -z "$UMAP_HEX" ]]; then
    echo "Usage: $(basename "$0") <UMAP_HEX> <OUTPUT_DIR> [--check-only]"
    echo "  Retrieves UMAP images from NOSTR profile CIDs"
    echo "  --check-only: Only check if images exist, don't download"
    exit 1
fi

# Query NOSTR profile for image CIDs
cd $HOME/.zen/strfry 2>/dev/null || { echo "strfry not found"; exit 1; }
PROFILE_DATA=$(./strfry scan '{"kinds":[0],"authors":["'$UMAP_HEX'"]}' 2>/dev/null | head -n 1)
cd - >/dev/null 2>&1

if [[ -z "$PROFILE_DATA" ]]; then
    echo "NO_PROFILE"
    exit 1
fi

# Extract image CIDs and update date from profile tags
UMAP_CID=$(echo "$PROFILE_DATA" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("umap_cid:"))) | .[1] | split(":")[1]] | first // empty')
USAT_CID=$(echo "$PROFILE_DATA" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("usat_cid:"))) | .[1] | split(":")[1]] | first // empty')
UMAP_FULL_CID=$(echo "$PROFILE_DATA" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("umap_full_cid:"))) | .[1] | split(":")[1]] | first // empty')
USAT_FULL_CID=$(echo "$PROFILE_DATA" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("usat_full_cid:"))) | .[1] | split(":")[1]] | first // empty')
UMAPROOT=$(echo "$PROFILE_DATA" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("umaproot:"))) | .[1] | split(":")[1]] | first // empty')
UMAP_UPDATED=$(echo "$PROFILE_DATA" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("umap_updated:"))) | .[1] | split(":")[1]] | first // empty')

# Check-only mode: just report what's available
if [[ "$CHECK_ONLY" == true ]]; then
    echo "UMAP_CID=${UMAP_CID}"
    echo "USAT_CID=${USAT_CID}"
    echo "UMAP_FULL_CID=${UMAP_FULL_CID}"
    echo "USAT_FULL_CID=${USAT_FULL_CID}"
    echo "UMAPROOT=${UMAPROOT}"
    echo "UMAP_UPDATED=${UMAP_UPDATED}"
    exit 0
fi

# Download mode: fetch images from IPFS
if [[ -z "$OUTPUT_DIR" ]]; then
    echo "ERROR: OUTPUT_DIR required for download mode"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
FETCHED=0

# Fetch zUmap.jpg (zoomed road map - profile picture)
if [[ -n "$UMAP_CID" && ! -s "${OUTPUT_DIR}/zUmap.jpg" ]]; then
    echo "Fetching zUmap.jpg from IPFS CID: $UMAP_CID"
    ipfs --timeout 30s cat "$UMAP_CID" > "${OUTPUT_DIR}/zUmap.jpg" 2>/dev/null
    if [[ -s "${OUTPUT_DIR}/zUmap.jpg" ]]; then
        echo "✓ zUmap.jpg fetched successfully"
        ((FETCHED++))
    else
        rm -f "${OUTPUT_DIR}/zUmap.jpg"
        echo "✗ Failed to fetch zUmap.jpg"
    fi
fi

# Fetch Usat.jpg (satellite - banner)
if [[ -n "$USAT_CID" && ! -s "${OUTPUT_DIR}/Usat.jpg" ]]; then
    echo "Fetching Usat.jpg from IPFS CID: $USAT_CID"
    ipfs --timeout 30s cat "$USAT_CID" > "${OUTPUT_DIR}/Usat.jpg" 2>/dev/null
    if [[ -s "${OUTPUT_DIR}/Usat.jpg" ]]; then
        echo "✓ Usat.jpg fetched successfully"
        ((FETCHED++))
    else
        rm -f "${OUTPUT_DIR}/Usat.jpg"
        echo "✗ Failed to fetch Usat.jpg"
    fi
fi

# Fetch Umap.jpg (full road map) if CID available
if [[ -n "$UMAP_FULL_CID" && ! -s "${OUTPUT_DIR}/Umap.jpg" ]]; then
    echo "Fetching Umap.jpg from IPFS CID: $UMAP_FULL_CID"
    ipfs --timeout 30s cat "$UMAP_FULL_CID" > "${OUTPUT_DIR}/Umap.jpg" 2>/dev/null
    if [[ -s "${OUTPUT_DIR}/Umap.jpg" ]]; then
        echo "✓ Umap.jpg fetched successfully"
        ((FETCHED++))
    else
        rm -f "${OUTPUT_DIR}/Umap.jpg"
    fi
fi

# Fetch zUsat.jpg (zoomed satellite) if CID available
if [[ -n "$USAT_FULL_CID" && ! -s "${OUTPUT_DIR}/zUsat.jpg" ]]; then
    echo "Fetching zUsat.jpg from IPFS CID: $USAT_FULL_CID"
    ipfs --timeout 30s cat "$USAT_FULL_CID" > "${OUTPUT_DIR}/zUsat.jpg" 2>/dev/null
    if [[ -s "${OUTPUT_DIR}/zUsat.jpg" ]]; then
        echo "✓ zUsat.jpg fetched successfully"
        ((FETCHED++))
    else
        rm -f "${OUTPUT_DIR}/zUsat.jpg"
    fi
fi

# NOTE: UMAPROOT no longer contains images (they are stored individually via CIDs)
# Images must be fetched via individual CIDs above

echo "FETCHED=$FETCHED"
exit 0
