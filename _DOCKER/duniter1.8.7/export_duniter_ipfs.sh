#!/bin/bash

# Export Duniter database to IPFS
# Minimizes downtime by copying data quickly then processing offline
# Only exports if local node is synchronized with network
# If desync > 6h, auto-imports from a synchronized swarm peer
# Must be run from the docker-compose directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- CONFIGURATION ---
COMPOSE_PROJECT="duniter187"
INTERNAL_PATH="/var/lib/duniter"
DATA_VOLUME="${COMPOSE_PROJECT}_data"
WORK_DIR="$HOME/.zen/tmp/duniter_export"
ARCHIVE_NAME="duniter_db_snapshot.tar.gz"
LOCAL_NODE="localhost:10901"
REFERENCE_NODES=(g1.brussels.ovh g1.cgeek.fr g1.duniter.fr duniter-v1.comunes.net)

# 6 hours = ~72 blocks (1 block every 5 minutes)
MAX_DESYNC_BLOCKS=72
# Max age for 12345.json in seconds (30 minutes)
MAX_NODE_AGE=1800

# Get IPFS Node ID
IPFSNODEID=$(ipfs id -f='<id>\n' 2>/dev/null)
if [[ -z "$IPFSNODEID" ]]; then
    echo "ERROR: Cannot get IPFS node ID. Is IPFS running?"
    exit 1
fi

CID_FILE="$HOME/.zen/tmp/$IPFSNODEID/_blockchain.v1.cid"
SWARM_DIR="$HOME/.zen/tmp/swarm"
mkdir -p "$(dirname "$CID_FILE")"

echo "=== Step 0: Checking node synchronization ==="

# Get local node current block
LOCAL_BLOCK=$(curl -s -m 5 http://$LOCAL_NODE/blockchain/current | jq -r '.number // empty' 2>/dev/null)
if [[ -z "$LOCAL_BLOCK" ]]; then
    echo "ERROR: Cannot reach local Duniter node at $LOCAL_NODE"
    rm -f "$CID_FILE"
    exit 1
fi
echo "Local node block: $LOCAL_BLOCK"

# Get reference node current block (try multiple nodes)
REF_BLOCK=""
REF_NODE=""
for ref_node in "${REFERENCE_NODES[@]}"; do
    REF_BLOCK=$(curl -s -m 5 https://$ref_node/blockchain/current | jq -r '.number // empty' 2>/dev/null)
    if [[ -n "$REF_BLOCK" ]]; then
        REF_NODE="$ref_node"
        echo "Reference node ($ref_node) block: $REF_BLOCK"
        break
    fi
done

if [[ -z "$REF_BLOCK" ]]; then
    echo "ERROR: Cannot reach any reference node"
    rm -f "$CID_FILE"
    exit 1
fi

# Check synchronization
BLOCK_DIFF=$((REF_BLOCK - LOCAL_BLOCK))
if [[ $BLOCK_DIFF -lt 0 ]]; then
    BLOCK_DIFF=$((-BLOCK_DIFF))
fi

echo "Block difference: $BLOCK_DIFF blocks"

# If severely desynchronized (>6 hours), try to auto-repair from swarm
if [[ $BLOCK_DIFF -gt $MAX_DESYNC_BLOCKS ]]; then
    echo "WARNING: Local node is $BLOCK_DIFF blocks behind (>$MAX_DESYNC_BLOCKS = 6 hours)"
    echo "Searching for synchronized peer in swarm..."
    rm -f "$CID_FILE"

    FOUND_CID=""
    FOUND_PEER=""
    NOW=$(date +%s)

    # Scan swarm for a peer with valid CID and fresh 12345.json
    if [[ -d "$SWARM_DIR" ]]; then
        for peer_dir in "$SWARM_DIR"/*/; do
            [[ ! -d "$peer_dir" ]] && continue
            PEER_ID=$(basename "$peer_dir")
            [[ "$PEER_ID" == "$IPFSNODEID" ]] && continue  # Skip self

            PEER_CID_FILE="${peer_dir}_blockchain.v1.cid"
            PEER_JSON="${peer_dir}12345.json"

            # Check if CID file exists
            if [[ ! -f "$PEER_CID_FILE" ]]; then
                echo "  $PEER_ID: No CID file, skipping"
                continue
            fi

            # Check if 12345.json exists and is fresh
            if [[ ! -f "$PEER_JSON" ]]; then
                echo "  $PEER_ID: No 12345.json, skipping"
                continue
            fi

            # Check 12345.json age
            JSON_MTIME=$(stat -c %Y "$PEER_JSON" 2>/dev/null)
            if [[ -z "$JSON_MTIME" ]]; then
                echo "  $PEER_ID: Cannot stat 12345.json, skipping"
                continue
            fi

            JSON_AGE=$((NOW - JSON_MTIME))
            if [[ $JSON_AGE -gt $MAX_NODE_AGE ]]; then
                echo "  $PEER_ID: 12345.json too old (${JSON_AGE}s > ${MAX_NODE_AGE}s), skipping"
                continue
            fi

            # Read the CID
            PEER_CID=$(cat "$PEER_CID_FILE" | tr -d '[:space:]')
            if [[ -z "$PEER_CID" ]]; then
                echo "  $PEER_ID: Empty CID file, skipping"
                continue
            fi

            # Verify CID is valid IPFS hash format
            if [[ ! "$PEER_CID" =~ ^Qm[a-zA-Z0-9]{44}$ ]] && [[ ! "$PEER_CID" =~ ^bafy[a-zA-Z0-9]{50,}$ ]]; then
                echo "  $PEER_ID: Invalid CID format, skipping"
                continue
            fi

            echo "  $PEER_ID: Found valid CID $PEER_CID (12345.json age: ${JSON_AGE}s)"
            FOUND_CID="$PEER_CID"
            FOUND_PEER="$PEER_ID"
            break
        done
    fi

    if [[ -n "$FOUND_CID" ]]; then
        echo ""
        echo "=== AUTO-REPAIR: Importing from peer $FOUND_PEER ==="
        echo "CID: $FOUND_CID"
        echo ""

        # Call the import script
        if [[ -x "$SCRIPT_DIR/import_duniter_ipfs.sh" ]]; then
            "$SCRIPT_DIR/import_duniter_ipfs.sh" "$FOUND_CID"
            exit $?
        else
            echo "ERROR: import_duniter_ipfs.sh not found or not executable"
            exit 1
        fi
    else
        echo "ERROR: No synchronized peer found in swarm"
        echo "Manual intervention required."
        exit 1
    fi
fi

# Node is synchronized (or close enough), proceed with export
if [[ $BLOCK_DIFF -gt 2 ]]; then
    echo "WARNING: Local node is $BLOCK_DIFF blocks behind, but within acceptable range."
fi

echo "Node is synchronized (diff: $BLOCK_DIFF blocks)"

# Prepare work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/data"

echo "=== Step 1: Quick snapshot from volume (minimal downtime) ==="
# Stop container briefly for consistent snapshot
docker compose stop duniter

# Copy data from volume using alpine container (fast)
docker run --rm -v ${DATA_VOLUME}:${INTERNAL_PATH}:ro -v ${WORK_DIR}/data:/backup alpine \
    cp -a ${INTERNAL_PATH}/. /backup/

# Restart immediately - compression and upload happen with node running
echo "=== Step 2: Restarting node ==="
docker compose start duniter
echo "Node restarted. Processing backup in background..."

echo "=== Step 3: Securing data (removing private keys) ==="
# NEVER publish key.yml or keyring.yml to IPFS
find "$WORK_DIR/data" -name "key.yml" -delete
find "$WORK_DIR/data" -name "key.priv" -delete
find "$WORK_DIR/data" -name "keyring.yml" -delete

echo "=== Step 4: Compressing database ==="
cd "$WORK_DIR/data"
tar -czf "$WORK_DIR/$ARCHIVE_NAME" .
cd "$SCRIPT_DIR"

echo "=== Step 5: Uploading to IPFS ==="
# Get old CID before adding new one (for cleanup)
OLD_CID=""
if [[ -f "$CID_FILE" ]]; then
    OLD_CID=$(cat "$CID_FILE" | tr -d '[:space:]')
fi

CID=$(ipfs add -Q "$WORK_DIR/$ARCHIVE_NAME")

if [[ -z "$CID" ]]; then
    echo "ERROR: Failed to add to IPFS"
    rm -f "$CID_FILE"
    rm -rf "$WORK_DIR"
    exit 1
fi

# Unpin old CID to free space (if different from new)
if [[ -n "$OLD_CID" && "$OLD_CID" != "$CID" ]]; then
    echo "Unpinning old CID: $OLD_CID"
    ipfs pin rm "$OLD_CID" 2>/dev/null || true
fi

# Save CID to cache file
echo "$CID" > "$CID_FILE"

# Cleanup
rm -rf "$WORK_DIR"

echo "----------------------------------------------------"
echo "SUCCESS! Database exported to IPFS."
echo "CID: $CID"
echo "Saved to: $CID_FILE"
echo "Block: $LOCAL_BLOCK"
echo "----------------------------------------------------"
