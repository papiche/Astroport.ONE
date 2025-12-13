#!/bin/bash

# Import Duniter database from Brussels backup server
# Usage: ./import_duniter_brussels.sh [DATE]
# DATE format: YYYY-MM-DD (defaults to today)

# --- CONFIGURATION ---
BACKUP_BASE_URL="https://downloads.g1.brussels.ovh"
CONTAINER_NAME="duniter187-duniter-1"
INTERNAL_PATH="/var/lib/duniter"
TEMP_IMPORT_DIR="./duniter_import_tmp"

# Determine the date to use (today if not specified)
if [ -z "$1" ]; then
    BACKUP_DATE=$(date +%Y-%m-%d)
    echo "No date specified, using today: $BACKUP_DATE"
else
    BACKUP_DATE=$1
fi

# Build the backup filename and URL
# Format: auto-backup-g1-brussels-ovh-1.8.7_2025-12-13_02-00.tgz
ARCHIVE_NAME="auto-backup-g1-brussels-ovh-1.8.7_${BACKUP_DATE}_02-00.tgz"
BACKUP_URL="${BACKUP_BASE_URL}/${ARCHIVE_NAME}"

echo "=== Step 1: Downloading backup from Brussels ($BACKUP_URL) ==="
curl -fSL -o "$ARCHIVE_NAME" "$BACKUP_URL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download backup from $BACKUP_URL"
    echo "Check if the date is correct and the backup exists."
    exit 1
fi

echo "=== Step 2: Stopping target node ==="
docker stop $CONTAINER_NAME

echo "=== Step 3: Backing up existing private key ==="
rm -rf $TEMP_IMPORT_DIR
mkdir -p $TEMP_IMPORT_DIR/conf

# Try to retrieve key.yml from container to preserve identity
docker cp $CONTAINER_NAME:$INTERNAL_PATH/conf/key.yml $TEMP_IMPORT_DIR/conf/key.yml 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Private key saved."
else
    echo "WARNING: No key.yml found or copy error. Node will start without identity."
fi

echo "=== Step 4: Extracting and replacing data ==="
mkdir -p $TEMP_IMPORT_DIR/data
tar -xzf $ARCHIVE_NAME -C $TEMP_IMPORT_DIR/data

# If the archive contains a 'duniter' folder, adjust the path
if [ -d "$TEMP_IMPORT_DIR/data/duniter" ]; then
    mv $TEMP_IMPORT_DIR/data/duniter/* $TEMP_IMPORT_DIR/data/
    rmdir $TEMP_IMPORT_DIR/data/duniter
fi

# If the archive contains a 'var/lib/duniter' structure, adjust
if [ -d "$TEMP_IMPORT_DIR/data/var/lib/duniter" ]; then
    mv $TEMP_IMPORT_DIR/data/var/lib/duniter/* $TEMP_IMPORT_DIR/data/
    rm -rf $TEMP_IMPORT_DIR/data/var
fi

# Restore saved key to new data folder
if [ -f "$TEMP_IMPORT_DIR/conf/key.yml" ]; then
    mkdir -p $TEMP_IMPORT_DIR/data/conf
    cp $TEMP_IMPORT_DIR/conf/key.yml $TEMP_IMPORT_DIR/data/conf/
fi

echo "=== Step 5: Copying new data to container ==="
docker cp $TEMP_IMPORT_DIR/data/. $CONTAINER_NAME:$INTERNAL_PATH/

echo "=== Step 6: Fixing permissions ==="
# Duniter runs with UID 1000. Fix ownership on copied files.
docker run --rm --volumes-from $CONTAINER_NAME debian:bullseye-slim chown -R 1000:1000 $INTERNAL_PATH

echo "=== Step 7: Restarting node ==="
docker start $CONTAINER_NAME

# Cleanup
rm -rf $TEMP_IMPORT_DIR
rm -f $ARCHIVE_NAME

echo "----------------------------------------------------"
echo "Import complete from Brussels backup: $ARCHIVE_NAME"
echo "Check logs: docker logs -f $CONTAINER_NAME"
echo "----------------------------------------------------"

