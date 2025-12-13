#!/bin/bash

# Import Duniter database from IPFS
# Usage: ./import_duniter_ipfs.sh <CID>
# Must be run from the docker-compose directory

if [ -z "$1" ]; then
    echo "Error: Please provide the IPFS CID as argument."
    echo "Usage: ./import_duniter_ipfs.sh QmHash..."
    exit 1
fi

CID=$1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- CONFIGURATION ---
COMPOSE_PROJECT="duniter187"
INTERNAL_PATH="/var/lib/duniter"
DATA_VOLUME="${COMPOSE_PROJECT}_data"
WORK_DIR="$HOME/.zen/tmp/duniter_import"
mkdir -p "$WORK_DIR"
TEMP_IMPORT_DIR="$WORK_DIR/data"
ARCHIVE_NAME="$WORK_DIR/duniter_import.tar.gz"

echo "=== Step 1: Downloading from IPFS ($CID) ==="
ipfs get "$CID" -o "$ARCHIVE_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download from IPFS."
    exit 1
fi

echo "=== Step 2: Stopping duniter via docker compose ==="
docker compose stop duniter

echo "=== Step 3: Backing up existing private key ==="
rm -rf $TEMP_IMPORT_DIR
mkdir -p $TEMP_IMPORT_DIR/conf

# Use a temp container to extract key.yml from the volume
docker run --rm -v ${DATA_VOLUME}:${INTERNAL_PATH}:ro -v ${TEMP_IMPORT_DIR}:/backup alpine \
    sh -c "cp ${INTERNAL_PATH}/conf/key.yml /backup/conf/key.yml 2>/dev/null || \
           cp ${INTERNAL_PATH}/duniter_default/keyring.yml /backup/conf/keyring.yml 2>/dev/null || true"

if [ -f "$TEMP_IMPORT_DIR/conf/key.yml" ] || [ -f "$TEMP_IMPORT_DIR/conf/keyring.yml" ]; then
    echo "Private key(s) saved."
else
    echo "WARNING: No key.yml/keyring.yml found. Node will start without identity."
fi

echo "=== Step 4: Extracting backup ==="
mkdir -p $TEMP_IMPORT_DIR/data
tar -xzf $ARCHIVE_NAME -C $TEMP_IMPORT_DIR/data

# Handle various archive structures
if [ -d "$TEMP_IMPORT_DIR/data/duniter" ]; then
    mv $TEMP_IMPORT_DIR/data/duniter/* $TEMP_IMPORT_DIR/data/
    rmdir $TEMP_IMPORT_DIR/data/duniter
fi
if [ -d "$TEMP_IMPORT_DIR/data/var/lib/duniter" ]; then
    mv $TEMP_IMPORT_DIR/data/var/lib/duniter/* $TEMP_IMPORT_DIR/data/
    rm -rf $TEMP_IMPORT_DIR/data/var
fi

echo "=== Step 5: Clearing volume and importing new data ==="
# Use a temp container to clear and copy data to the volume
docker run --rm -v ${DATA_VOLUME}:${INTERNAL_PATH} -v ${TEMP_IMPORT_DIR}:/import alpine \
    sh -c "rm -rf ${INTERNAL_PATH}/* && cp -a /import/data/. ${INTERNAL_PATH}/"

echo "=== Step 6: Restoring private key(s) ==="
# Restore saved keys
if [ -f "$TEMP_IMPORT_DIR/conf/key.yml" ]; then
    docker run --rm -v ${DATA_VOLUME}:${INTERNAL_PATH} -v ${TEMP_IMPORT_DIR}:/import alpine \
        sh -c "mkdir -p ${INTERNAL_PATH}/conf && cp /import/conf/key.yml ${INTERNAL_PATH}/conf/"
    echo "key.yml restored."
fi
if [ -f "$TEMP_IMPORT_DIR/conf/keyring.yml" ]; then
    docker run --rm -v ${DATA_VOLUME}:${INTERNAL_PATH} -v ${TEMP_IMPORT_DIR}:/import alpine \
        sh -c "mkdir -p ${INTERNAL_PATH}/duniter_default && cp /import/conf/keyring.yml ${INTERNAL_PATH}/duniter_default/"
    echo "keyring.yml restored."
fi

echo "=== Step 7: Fixing permissions ==="
# Duniter container runs with UID 1111. Fix ownership on all files.
docker run --rm -v ${DATA_VOLUME}:${INTERNAL_PATH} -v ${COMPOSE_PROJECT}_etc:/etc/duniter alpine \
    chown -R 1111:1111 ${INTERNAL_PATH} /etc/duniter

echo "=== Step 8: Restarting duniter ==="
docker compose start duniter

# Cleanup
rm -rf "$WORK_DIR"

# Unpin the imported CID to free space (we have it in our DB now)
echo "Unpinning imported CID to free IPFS space..."
ipfs pin rm "$CID" 2>/dev/null || true

echo "----------------------------------------------------"
echo "Import complete from IPFS: $CID"
echo "Check logs: docker compose logs -f duniter"
echo "----------------------------------------------------"
