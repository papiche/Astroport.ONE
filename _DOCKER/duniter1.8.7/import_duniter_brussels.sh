#!/bin/bash

# Import Duniter database from Brussels backup server
# Usage: ./import_duniter_brussels.sh [DATE]
# DATE format: YYYY-MM-DD (defaults to today)
# Must be run from the docker-compose directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- CONFIGURATION ---
BACKUP_BASE_URL="https://downloads.g1.brussels.ovh"
COMPOSE_PROJECT="duniter187"
INTERNAL_PATH="/var/lib/duniter"
DATA_VOLUME="${COMPOSE_PROJECT}_data"
WORK_DIR="$HOME/.zen/tmp/duniter_import"
mkdir -p "$WORK_DIR"
TEMP_IMPORT_DIR="$WORK_DIR/data"

# Determine the date to use (today if not specified)
if [ -z "$1" ]; then
    BACKUP_DATE=$(date +%Y-%m-%d)
    echo "No date specified, using today: $BACKUP_DATE"
else
    BACKUP_DATE=$1
fi

# Build the backup filename and URL
# Format: auto-backup-g1-brussels-ovh-1.8.7_2025-12-13_02-00.tgz
ARCHIVE_FILE="auto-backup-g1-brussels-ovh-1.8.7_${BACKUP_DATE}_02-00.tgz"
ARCHIVE_NAME="$WORK_DIR/$ARCHIVE_FILE"
BACKUP_URL="${BACKUP_BASE_URL}/${ARCHIVE_FILE}"

echo "=== Step 1: Downloading backup from Brussels ($BACKUP_URL) ==="
if [ ! -f "$ARCHIVE_NAME" ]; then
    curl -fSL -o "$ARCHIVE_NAME" "$BACKUP_URL"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download backup from $BACKUP_URL"
        echo "Check if the date is correct and the backup exists."
        exit 1
    fi
else
    echo "Archive already exists, skipping download."
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

echo "----------------------------------------------------"
echo "Import complete from Brussels backup: $ARCHIVE_FILE"
echo "Check logs: docker compose logs -f duniter"
echo "----------------------------------------------------"

