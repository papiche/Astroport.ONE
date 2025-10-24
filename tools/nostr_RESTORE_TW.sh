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

# Step 2: Extract backup ZIP (with password prompt if needed)
echo -e "${YELLOW}Step 2/4:${NC} ${CYAN}Extracting backup archive...${NC}"
cd "${RESTORE_DIR}"

# Try to extract without password first
if unzip -q "${BACKUP_ZIP}" 2>/dev/null; then
    echo -e "${GREEN}✅ Backup extracted successfully (no password required)${NC}"
else
    # If that fails, try with password prompt
    echo -e "${YELLOW}⚠️  Backup appears to be password-protected${NC}"
    echo -e "${CYAN}Please enter the ZEN Card password (from the user's .pass file):${NC}"
    echo -e "${YELLOW}💡 The user should provide their ZEN Card password to decrypt the backup${NC}"
    if unzip "${BACKUP_ZIP}" 2>/dev/null; then
        echo -e "${GREEN}✅ Encrypted backup extracted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to extract backup (wrong password or corrupted file)${NC}"
        echo -e "${YELLOW}💡 Make sure the user provides the correct ZEN Card password${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
fi

# Find nostr_export.json
EXPORT_FILE=$(find "${RESTORE_DIR}" -name "nostr_export.json" | head -1)
if [[ ! -f "${EXPORT_FILE}" ]]; then
    echo -e "${RED}❌ nostr_export.json not found in backup${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# Check for uDRIVE manifest
MANIFEST_FILE=$(find "${RESTORE_DIR}" -name "uDRIVE_manifest.json" | head -1)
if [[ -f "${MANIFEST_FILE}" ]]; then
    echo -e "${GREEN}✅ uDRIVE manifest found${NC}"
    TOTAL_SIZE=$(jq -r '.formatted_total_size' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    TOTAL_FILES=$(jq -r '.total_files' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    echo -e "${CYAN}   📊 uDRIVE contains: ${GREEN}${TOTAL_FILES}${CYAN} files (${GREEN}${TOTAL_SIZE}${CYAN})${NC}"
else
    echo -e "${YELLOW}⚠️  No uDRIVE manifest found (no uDRIVE data to restore)${NC}"
fi

# Check for .secret.disco
DISCO_FILE=$(find "${RESTORE_DIR}" -name ".secret.disco" | head -1)
if [[ -f "${DISCO_FILE}" ]]; then
    echo -e "${GREEN}✅ Secret .disco key found${NC}"
    echo -e "${CYAN}   🔑 Full account restoration possible${NC}"
    
    # Extract email, salt, and pepper from .disco file
    DISCO_CONTENT=$(cat "${DISCO_FILE}")
    echo -e "${CYAN}   📋 DISCO content: ${DISCO_CONTENT:0:50}...${NC}"
    
    # Parse DISCO format: /?email=salt&nostr=pepper
    if [[ "$DISCO_CONTENT" =~ ^/\?([^=]+)=([^&]+)&nostr=(.+)$ ]]; then
        RESTORE_EMAIL="${BASH_REMATCH[1]}"
        RESTORE_SALT="${BASH_REMATCH[2]}"
        RESTORE_PEPPER="${BASH_REMATCH[3]}"
        echo -e "${GREEN}   📧 Email: ${RESTORE_EMAIL}${NC}"
        echo -e "${GREEN}   🔐 Salt: ${RESTORE_SALT:0:20}...${NC}"
        echo -e "${GREEN}   🔐 Pepper: ${RESTORE_PEPPER:0:20}...${NC}"
    else
        echo -e "${RED}❌ Invalid DISCO format in .secret.disco${NC}"
        RESTORE_EMAIL=""
        RESTORE_SALT=""
        RESTORE_PEPPER=""
    fi
else
    echo -e "${YELLOW}⚠️  No .secret.disco found (limited restoration)${NC}"
    RESTORE_EMAIL=""
    RESTORE_SALT=""
    RESTORE_PEPPER=""
fi

# Check for ZEN Card files
ZEN_SECRET_JUNE=$(find "${RESTORE_DIR}" -name "secret.june" | head -1)
ZEN_G1PUB=$(find "${RESTORE_DIR}" -name ".g1pub" | head -1)

if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
    echo -e "${GREEN}✅ ZEN Card secret.june found${NC}"
    echo -e "${CYAN}   💰 Capital history preserved${NC}"
else
    echo -e "${YELLOW}⚠️  No ZEN Card secret.june found (no capital history)${NC}"
fi

if [[ -f "${ZEN_G1PUB}" ]]; then
    echo -e "${GREEN}✅ ZEN Card .g1pub found${NC}"
    echo -e "${CYAN}   🏦 G1 wallet access preserved${NC}"
else
    echo -e "${YELLOW}⚠️  No ZEN Card .g1pub found (no G1 wallet)${NC}"
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

# Step 5: Full Account Restoration (if .disco available)
if [[ -n "$RESTORE_EMAIL" && -n "$RESTORE_SALT" && -n "$RESTORE_PEPPER" ]]; then
    echo ""
    echo -e "${YELLOW}Step 5/6:${NC} ${CYAN}Full account restoration...${NC}"
    
    # Check if make_NOSTRCARD.sh exists
    if [[ -f "${MY_PATH}/make_NOSTRCARD.sh" ]]; then
        echo -e "${CYAN}   🔄 Recreating MULTIPASS with original credentials...${NC}"
        
        # Recreate MULTIPASS with original salt/pepper
        if "${MY_PATH}/make_NOSTRCARD.sh" "${RESTORE_EMAIL}" "fr" "0.00" "0.00" "${RESTORE_SALT}" "${RESTORE_PEPPER}" 2>/dev/null; then
            echo -e "${GREEN}✅ MULTIPASS recreated successfully${NC}"
            
            # Now import NOSTR events to the recreated account
            echo -e "${CYAN}   📡 Importing NOSTR events to recreated account...${NC}"
            if [[ -f "${FILTERED_FILE}" ]]; then
                cd "$HOME/.zen/strfry"
                if ./strfry import --no-verify < "${FILTERED_FILE}" 2>/dev/null; then
                    echo -e "${GREEN}✅ NOSTR events imported to recreated account${NC}"
                else
                    echo -e "${YELLOW}⚠️  Failed to import events to recreated account${NC}"
                fi
                cd - > /dev/null 2>&1
            fi
            
                    # Restore uDRIVE files if manifest exists
                    if [[ -f "${MANIFEST_FILE}" ]]; then
                        echo -e "${CYAN}   📁 Restoring uDRIVE files from manifest...${NC}"
                        UDRIVE_DIR="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/APP/uDRIVE"
                        mkdir -p "${UDRIVE_DIR}"
                        
                        # Extract final_cid from manifest
                        if command -v jq >/dev/null 2>&1; then
                            FINAL_CID=$(jq -r '.final_cid' "${MANIFEST_FILE}" 2>/dev/null)
                            if [[ -n "$FINAL_CID" && "$FINAL_CID" != "null" ]]; then
                                echo -e "${CYAN}   📥 Downloading complete uDRIVE structure from IPFS...${NC}"
                                echo -e "${CYAN}   🔗 Final CID: ${FINAL_CID}${NC}"
                                
                                # Download the complete uDRIVE structure
                                if ipfs get "${FINAL_CID}" -o "${UDRIVE_DIR}" 2>/dev/null; then
                                    echo -e "${GREEN}✅ Complete uDRIVE structure restored from IPFS${NC}"
                                    
                                    # Verify generate_ipfs_structure.sh link is valid
                                    if [[ -f "${UDRIVE_DIR}/generate_ipfs_structure.sh" ]]; then
                                        echo -e "${GREEN}✅ generate_ipfs_structure.sh link verified${NC}"
                                    else
                                        echo -e "${YELLOW}⚠️  generate_ipfs_structure.sh not found in restored structure${NC}"
                                    fi
                                    
                                    # Show structure summary
                                    echo -e "${CYAN}   📊 uDRIVE structure:${NC}"
                                    if command -v ipfs >/dev/null 2>&1; then
                                        ipfs ls "${FINAL_CID}" 2>/dev/null | head -10 | while read -r line; do
                                            echo -e "${CYAN}     ${line}${NC}"
                                        done
                                    fi
                                else
                                    echo -e "${RED}❌ Failed to download uDRIVE structure from IPFS${NC}"
                                fi
                            else
                                echo -e "${YELLOW}⚠️  No final_cid found in manifest, skipping uDRIVE restoration${NC}"
                            fi
                        else
                            echo -e "${YELLOW}⚠️  jq not found, skipping uDRIVE file restoration${NC}"
                        fi
                    fi
                    
                    # Restore ZEN Card using VISA.new.sh with SALT/PEPPER from secret.june
                    if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
                        echo -e "${CYAN}   🎮 Recreating ZEN Card with original credentials...${NC}"
                        
                        # Extract SALT and PEPPER from secret.june
                        ZEN_SALT=$(grep '^SALT=' "${ZEN_SECRET_JUNE}" | cut -d'"' -f2)
                        ZEN_PEPPER=$(grep '^PEPPER=' "${ZEN_SECRET_JUNE}" | cut -d'"' -f2)
                        
                        if [[ -n "$ZEN_SALT" && -n "$ZEN_PEPPER" ]]; then
                            echo -e "${CYAN}   🔑 SALT: ${ZEN_SALT:0:20}...${NC}"
                            echo -e "${CYAN}   🔑 PEPPER: ${ZEN_PEPPER:0:20}...${NC}"
                            
                            # Get GPS coordinates from MULTIPASS if available
                            MULTIPASS_GPS="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/GPS"
                            if [[ -f "${MULTIPASS_GPS}" ]]; then
                                source "${MULTIPASS_GPS}"
                                echo -e "${CYAN}   📍 GPS: ${LAT}, ${LON}${NC}"
                            else
                                LAT="0.00"
                                LON="0.00"
                                echo -e "${YELLOW}   📍 GPS: Using default coordinates (0.00, 0.00)${NC}"
                            fi
                            
                            # Get NPUB and HEX from MULTIPASS if available
                            MULTIPASS_NPUB="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/NPUB"
                            MULTIPASS_HEX="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/HEX"
                            
                            RESTORE_NPUB=""
                            RESTORE_HEX=""
                            if [[ -f "${MULTIPASS_NPUB}" ]]; then
                                RESTORE_NPUB=$(cat "${MULTIPASS_NPUB}")
                                echo -e "${CYAN}   🔗 NPUB: ${RESTORE_NPUB:0:20}...${NC}"
                            fi
                            if [[ -f "${MULTIPASS_HEX}" ]]; then
                                RESTORE_HEX=$(cat "${MULTIPASS_HEX}")
                                echo -e "${CYAN}   🔗 HEX: ${RESTORE_HEX:0:20}...${NC}"
                            fi
                            
                            # Recreate ZEN Card using VISA.new.sh
                            echo -e "${CYAN}   🔄 Creating ZEN Card with VISA.new.sh...${NC}"
                            if "${MY_PATH}/../RUNTIME/VISA.new.sh" \
                                "${ZEN_SALT}" \
                                "${ZEN_PEPPER}" \
                                "${RESTORE_EMAIL}" \
                                "UPlanet" \
                                "fr" \
                                "${LAT}" \
                                "${LON}" \
                                "${RESTORE_NPUB}" \
                                "${RESTORE_HEX}" 2>/dev/null; then
                                
                                echo -e "${GREEN}✅ ZEN Card recreated successfully with original credentials${NC}"
                                
                                # Verify the recreated ZEN Card
                                if [[ -f "${HOME}/.zen/game/players/${RESTORE_EMAIL}/.g1pub" ]]; then
                                    NEW_G1PUB=$(cat "${HOME}/.zen/game/players/${RESTORE_EMAIL}/.g1pub")
                                    echo -e "${GREEN}   🏦 New G1PUB: ${NEW_G1PUB:0:20}...${NC}"
                                    
                                    # Compare with original if available
                                    if [[ -f "${ZEN_G1PUB}" ]]; then
                                        ORIGINAL_G1PUB=$(cat "${ZEN_G1PUB}")
                                        if [[ "$NEW_G1PUB" == "$ORIGINAL_G1PUB" ]]; then
                                            echo -e "${GREEN}   ✅ G1PUB matches original (perfect restoration)${NC}"
                                        else
                                            echo -e "${YELLOW}   ⚠️  G1PUB differs from original (new wallet created)${NC}"
                                            echo -e "${CYAN}   📝 Original: ${ORIGINAL_G1PUB:0:20}...${NC}"
                                            echo -e "${CYAN}   📝 New:      ${NEW_G1PUB:0:20}...${NC}"
                                        fi
                                    fi
                                else
                                    echo -e "${RED}   ❌ ZEN Card creation failed - .g1pub not found${NC}"
                                fi
                            else
                                echo -e "${RED}❌ Failed to recreate ZEN Card with VISA.new.sh${NC}"
                            fi
                        else
                            echo -e "${RED}❌ Invalid SALT/PEPPER in secret.june${NC}"
                        fi
                    elif [[ -f "${ZEN_G1PUB}" ]]; then
                        echo -e "${YELLOW}⚠️  Only .g1pub found, copying to players directory${NC}"
                        ZEN_CARD_DIR="${HOME}/.zen/game/players/${RESTORE_EMAIL}"
                        mkdir -p "${ZEN_CARD_DIR}"
                        cp "${ZEN_G1PUB}" "${ZEN_CARD_DIR}/.g1pub"
                        echo -e "${GREEN}✅ ZEN Card .g1pub restored (G1 wallet access)${NC}"
                    fi
            
            echo -e "${GREEN}✅ Complete account restoration finished${NC}"
        else
            echo -e "${RED}❌ Failed to recreate MULTIPASS${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  make_NOSTRCARD.sh not found, skipping full restoration${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping full restoration (missing DISCO information)${NC}"
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

# Show uDRIVE info if manifest exists
if [[ -f "${MANIFEST_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}uDRIVE files:${NC}              ${GREEN}${TOTAL_FILES}${NC} (${GREEN}${TOTAL_SIZE}${NC})                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}uDRIVE status:${NC}            ${YELLOW}Manifest available for recreation${NC}        ${BLUE}║${NC}"
fi

# Show secret key info if exists
if [[ -f "${DISCO_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}Secret key:${NC}               ${GREEN}Available for full restoration${NC}           ${BLUE}║${NC}"
fi

echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
        if [[ -n "$RESTORE_EMAIL" && -n "$RESTORE_SALT" && -n "$RESTORE_PEPPER" ]]; then
            echo -e "${GREEN}💡 Complete Restoration Achieved:${NC}"
            echo -e "   ${CYAN}✅ MULTIPASS recreated with original credentials${NC}"
            echo -e "   ${CYAN}✅ NOSTR events imported successfully${NC}"
            if [[ -f "${MANIFEST_FILE}" ]]; then
                echo -e "   ${CYAN}✅ uDRIVE files restored from IPFS${NC}"
            fi
            if [[ -f "${ZEN_SECRET_JUNE}" || -f "${ZEN_G1PUB}" ]]; then
                echo -e "   ${CYAN}✅ ZEN Card recreated with original credentials (capital owner history)${NC}"
            fi
            echo -e "   ${CYAN}✅ Account location:${NC} ~/.zen/game/nostr/${RESTORE_EMAIL}/"
            echo ""
            echo -e "${YELLOW}📋 For the User:${NC}"
            echo -e "   ${CYAN}• Your complete MULTIPASS has been restored on this Astroport.ONE station${NC}"
            echo -e "   ${CYAN}• All your NOSTR events, profile, and uDRIVE files are now available${NC}"
            if [[ -f "${ZEN_SECRET_JUNE}" || -f "${ZEN_G1PUB}" ]]; then
                echo -e "   ${CYAN}• Your ZEN Card has been recreated with original credentials (capital owner history)${NC}"
            fi
            echo -e "   ${CYAN}• You can access your account at: ${myIPFS}/ipns/<NOSTRNS>/${RESTORE_EMAIL}/APP/uDRIVE/${NC}"
else
    echo -e "${GREEN}💡 Next steps for the Captain:${NC}"
    echo -e "   ${CYAN}1. Verify events:${NC} cd ~/.zen/strfry && ./strfry scan '{\"authors\": [\"<HEX>\"]}'"
    if [[ -f "${MANIFEST_FILE}" ]]; then
        echo -e "   ${CYAN}2. Recreate uDRIVE:${NC} Use uDRIVE_manifest.json to restore user's files"
        echo -e "   ${CYAN}3. uDRIVE location:${NC} ~/.zen/game/nostr/<EMAIL>/APP/uDRIVE/"
    fi
            if [[ -f "${DISCO_FILE}" ]]; then
                echo -e "   ${CYAN}4. Full restoration:${NC} Use .secret.disco for complete account recreation"
                echo -e "   ${CYAN}5. Secret key location:${NC} ${DISCO_FILE}"
            fi
            if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
                echo -e "   ${CYAN}6. ZEN Card recreation:${NC} Use secret.june with VISA.new.sh for ZEN Card restoration"
                echo -e "   ${CYAN}7. ZEN Card secrets:${NC} ${ZEN_SECRET_JUNE}"
            elif [[ -f "${ZEN_G1PUB}" ]]; then
                echo -e "   ${CYAN}6. ZEN Card restoration:${NC} Use .g1pub for G1 wallet access"
                echo -e "   ${CYAN}7. ZEN Card file:${NC} ${ZEN_G1PUB}"
            fi
            echo ""
            echo -e "${YELLOW}📋 For the User:${NC}"
            echo -e "   ${CYAN}• Your NOSTR events have been imported to this Astroport.ONE station${NC}"
            echo -e "   ${CYAN}• Contact the captain for complete account recreation${NC}"
            if [[ -f "${MANIFEST_FILE}" ]]; then
                echo -e "   ${CYAN}• Your uDRIVE files can be recreated using the manifest${NC}"
            fi
            if [[ -f "${ZEN_SECRET_JUNE}" || -f "${ZEN_G1PUB}" ]]; then
                echo -e "   ${CYAN}• Your ZEN Card transaction history and G1 wallet access are preserved${NC}"
            fi
fi
echo ""

exit 0

