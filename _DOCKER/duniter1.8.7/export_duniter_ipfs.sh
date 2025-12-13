#!/bin/bash

# Export Duniter database to IPFS
# Minimizes downtime by copying data quickly then processing offline
# Must be run from the docker-compose directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- CONFIGURATION ---
COMPOSE_PROJECT="duniter187"
INTERNAL_PATH="/var/lib/duniter"
DATA_VOLUME="${COMPOSE_PROJECT}_data"
WORK_DIR="$HOME/.zen/tmp/duniter_export"
ARCHIVE_NAME="duniter_db_snapshot.tar.gz"

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
CID=$(ipfs add -Q "$WORK_DIR/$ARCHIVE_NAME")

# Cleanup
rm -rf "$WORK_DIR"

echo "----------------------------------------------------"
echo "SUCCESS! Database exported to IPFS."
echo "CID: $CID"
echo "Use this CID with import_duniter_ipfs.sh"
echo "----------------------------------------------------"
