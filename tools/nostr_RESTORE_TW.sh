#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_RESTORE_TW.sh
#
# This script restores a NOSTR account backup from IPFS.
# It downloads the backup ZIP, extracts it, and imports all events into strfry.
#
# Usage: ./nostr_RESTORE_TW.sh <IPFS_CID> [target_relay_url]
# -----------------------------------------------------------------------------

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   NOSTR Account Restore Tool${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $ME <IPFS_CID> [target_relay_url]"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo -e "  ${GREEN}IPFS_CID${NC}           CID of the backup ZIP file on IPFS"
    echo -e "  ${GREEN}target_relay_url${NC}   (Optional) WebSocket URL of target relay"
    echo -e "                      Default: ws://127.0.0.1:7777"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $ME QmXxx...123"
    echo -e "  $ME QmXxx...123 wss://relay.example.com"
    echo ""
    exit 1
}

# Check arguments
if [[ -z "$1" ]]; then
    echo -e "${RED}❌ Error: IPFS CID required${NC}"
    usage
fi

IPFS_CID="$1"
TARGET_RELAY="${2:-ws://127.0.0.1:7777}"
RESTORE_DIR="$HOME/.zen/tmp/nostr_restore_$$"
NO_VERIFY=true  # Use no-verify for faster import (trusted backup)

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                 ${CYAN}NOSTR Account Restore${NC}                           ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Backup CID:${NC}    ${IPFS_CID}"
echo -e "${CYAN}🎯 Target Relay:${NC}  ${TARGET_RELAY}"
echo -e "${CYAN}📂 Restore Dir:${NC}   ${RESTORE_DIR}"
echo ""

# Create restore directory
mkdir -p "${RESTORE_DIR}"

# Step 1: Download backup from IPFS
echo -e "${YELLOW}Step 1/4:${NC} ${CYAN}Downloading backup from IPFS...${NC}"
BACKUP_ZIP="${RESTORE_DIR}/backup.zip"

if ipfs get "${IPFS_CID}" -o "${BACKUP_ZIP}" 2>/dev/null; then
    echo -e "${GREEN}✅ Backup downloaded successfully${NC}"
else
    echo -e "${RED}❌ Failed to download backup from IPFS${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# Step 2: Extract backup ZIP
echo -e "${YELLOW}Step 2/4:${NC} ${CYAN}Extracting backup archive...${NC}"
cd "${RESTORE_DIR}"
if unzip -q "${BACKUP_ZIP}" 2>/dev/null; then
    echo -e "${GREEN}✅ Backup extracted successfully${NC}"
else
    echo -e "${RED}❌ Failed to extract backup${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# Find nostr_export.json
EXPORT_FILE=$(find "${RESTORE_DIR}" -name "nostr_export.json" | head -1)
if [[ ! -f "${EXPORT_FILE}" ]]; then
    echo -e "${RED}❌ nostr_export.json not found in backup${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# Step 3: Process and import events (using same logic as backfill_constellation.sh)
echo -e "${YELLOW}Step 3/4:${NC} ${CYAN}Processing events for import...${NC}"

# Count events
TOTAL_EVENTS=$(jq -r 'length' "${EXPORT_FILE}" 2>/dev/null | head -1 || echo "0")
echo -e "${CYAN}   Found ${GREEN}${TOTAL_EVENTS}${CYAN} events in backup${NC}"

if [[ "${TOTAL_EVENTS}" -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No events to restore${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 0
fi

# Create filtered file (remove "Hello NOSTR visitor." messages)
FILTERED_FILE="${RESTORE_DIR}/filtered.json"
echo -e "${CYAN}   Filtering out unwanted messages...${NC}"

jq -c '.[] | select(.content | test("Hello NOSTR visitor.") | not)' "${EXPORT_FILE}" > "${FILTERED_FILE}" 2>/dev/null

FILTERED_COUNT=$(wc -l < "${FILTERED_FILE}" 2>/dev/null || echo "0")
REMOVED_COUNT=$((TOTAL_EVENTS - FILTERED_COUNT))

if [[ ${REMOVED_COUNT} -gt 0 ]]; then
    echo -e "${CYAN}   Removed ${YELLOW}${REMOVED_COUNT}${CYAN} unwanted messages${NC}"
fi
echo -e "${CYAN}   Ready to import: ${GREEN}${FILTERED_COUNT}${CYAN} events${NC}"

# Step 4: Import to strfry
echo -e "${YELLOW}Step 4/4:${NC} ${CYAN}Importing events to strfry...${NC}"

if [[ ! -x "$HOME/.zen/strfry/strfry" ]]; then
    echo -e "${RED}❌ strfry not found or not executable${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

cd "$HOME/.zen/strfry"

# Import with or without verification
if [[ "$NO_VERIFY" == "true" ]]; then
    echo -e "${CYAN}   Using no-verify mode (trusted backup)...${NC}"
    if ./strfry import --no-verify < "${FILTERED_FILE}" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully imported ${FILTERED_COUNT} events${NC}"
    else
        echo -e "${RED}❌ Failed to import events${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
else
    echo -e "${CYAN}   Using signature verification mode...${NC}"
    if ./strfry import < "${FILTERED_FILE}" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully imported ${FILTERED_COUNT} events (verified)${NC}"
    else
        echo -e "${RED}❌ Failed to import events${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
fi

# Cleanup
echo ""
echo -e "${CYAN}🧹 Cleaning up temporary files...${NC}"
rm -rf "${RESTORE_DIR}"

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                 ${GREEN}✅ Restore Completed Successfully${NC}                  ${BLUE}║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Total events in backup:${NC}     ${GREEN}${TOTAL_EVENTS}${NC}                                  ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Events imported:${NC}            ${GREEN}${FILTERED_COUNT}${NC}                                  ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Filtered out:${NC}               ${YELLOW}${REMOVED_COUNT}${NC}                                  ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}💡 Tip:${NC} You can now verify the events in strfry:"
echo -e "   ${CYAN}cd ~/.zen/strfry && ./strfry scan '{\"authors\": [\"<HEX>\"]}'${NC}"
echo ""

exit 0

