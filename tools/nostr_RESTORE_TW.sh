#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_RESTORE_TW.sh
#
# This script restores a NOSTR account backup from IPFS.
# It supports both NEW format (.next.disco for migration to new relay/captain)
# and OLD format (.secret.disco for backward compatibility).
#
# For NEW relay/captain migration:
#   - Uses .next.disco (pre-generated during account deactivation)
#   - Creates MULTIPASS with new credentials on the new relay
#   - Imports all NOSTR events and restores uDRIVE
#
# For OLD format (backward compatibility):
#   - Uses .secret.disco (may not work on new relay)
#   - Attempts restoration with original credentials
#
# Usage: ./nostr_RESTORE_TW.sh <IPFS_CID> [target_relay_url]
#
# The IPFS_CID can point to either:
#   - A legacy password-protected ZIP (requires user's .pass)
#   - An asymmetrically encrypted backup (.enc) using natools.py
#     (Requires either the player's old .secret.dunikey or Captain's uplanet key)
#
# Numbered secret.june files (secret.june.000.IPFSNODEID, etc.) preserve
# the cumulative cooperative capital shares history across migrations.
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
    echo -e "  ${GREEN}IPFS_CID${NC}           CID of the backup file on IPFS"
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
BACKUP_FILE="${RESTORE_DIR}/backup.data"

if ipfs get "${IPFS_CID}" -o "${BACKUP_FILE}" 2>/dev/null; then
    echo -e "${GREEN}✅ Backup downloaded successfully${NC}"
else
    echo -e "${RED}❌ Failed to download backup from IPFS${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# Step 2: Extract backup (ZIP or Asymmetrically Encrypted)
echo -e "${YELLOW}Step 2/4:${NC} ${CYAN}Decrypting and Extracting backup archive...${NC}"
cd "${RESTORE_DIR}"

# Check if this is a standard ZIP file (Legacy) or an Encrypted Binary
if file "${BACKUP_FILE}" 2>/dev/null | grep -q "Zip archive"; then
    echo -e "${CYAN}   Archive is a standard ZIP (Legacy format)${NC}"
    
    # Try to extract without password first
    if unzip -q "${BACKUP_FILE}" 2>/dev/null; then
        echo -e "${GREEN}✅ Backup extracted successfully${NC}"
    else
        # If that fails, try with password prompt
        echo -e "${YELLOW}⚠️  Backup appears to be password-protected${NC}"
        echo -e "${CYAN}Please enter the ZEN Card password (from the user's .pass file):${NC}"
        if unzip "${BACKUP_FILE}" 2>/dev/null; then
            echo -e "${GREEN}✅ Encrypted backup extracted successfully${NC}"
        else
            echo -e "${RED}❌ Failed to extract backup (wrong password or corrupted file)${NC}"
            rm -rf "${RESTORE_DIR}"
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}⚠️  File is not a ZIP. Attempting asymmetric decryption (natools.py)...${NC}"
    DECRYPTED_ZIP="${RESTORE_DIR}/backup_decrypted.zip"
    DECRYPTED=false

    # 1. Try Player's Key first
    echo -e "${CYAN}Do you have the Player's old .secret.dunikey to decrypt this backup? (y/N)${NC}"
    read -p "> " has_key
    if [[ "$has_key" =~ ^[Yy] ]]; then
        read -p "Absolute path to Player's .secret.dunikey: " player_key
        if [[ -f "$player_key" ]]; then
            echo "Decrypting with Player's key..."
            if ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "${BACKUP_FILE}" -k "${player_key}" -o "${DECRYPTED_ZIP}" 2>/dev/null; then
                echo -e "${GREEN}✅ Decrypted successfully with Player's key${NC}"
                BACKUP_FILE="${DECRYPTED_ZIP}"
                DECRYPTED=true
            else
                echo -e "${RED}❌ Failed to decrypt with Player's key${NC}"
            fi
        else
            echo -e "${RED}❌ File not found: $player_key${NC}"
        fi
    fi

    # 2. Try Captain's Fallback key
    if [[ "$DECRYPTED" == "false" ]]; then
        echo -e "${YELLOW}⚠️  Trying UPlanet fallback key (Captain)...${NC}"
        # Ensure uplanet.dunikey exists
        if [[ ! -s ~/.zen/game/uplanet.dunikey ]]; then
            ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
            chmod 600 ~/.zen/game/uplanet.dunikey
        fi
        
        if ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "${BACKUP_FILE}" -k ~/.zen/game/uplanet.dunikey -o "${DECRYPTED_ZIP}" 2>/dev/null; then
            echo -e "${GREEN}✅ Decrypted with uplanet key (Captain fallback)${NC}"
            BACKUP_FILE="${DECRYPTED_ZIP}"
            DECRYPTED=true
        else
            echo -e "${RED}❌ Failed to decrypt with uplanet key${NC}"
        fi
    fi

    # Check decryption state
    if [[ "$DECRYPTED" == "false" ]]; then
        echo -e "${RED}❌ Could not decrypt the backup. Restoration aborted.${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi

    # Now extract the decrypted ZIP
    echo -e "${CYAN}   Extracting decrypted ZIP...${NC}"
    if unzip -q "${BACKUP_FILE}" 2>/dev/null; then
        echo -e "${GREEN}✅ Backup extracted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to extract decrypted backup. File may be corrupted.${NC}"
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

# Check for .next.disco (NEW format for restoration on new relay/captain)
NEXT_DISCO_FILE=$(find "${RESTORE_DIR}" -name ".next.disco" | head -1)
NEXT_HEX_FILE=$(find "${RESTORE_DIR}" -name ".next.hex" | head -1)
NEXT_SALT_FILE=$(find "${RESTORE_DIR}" -name ".next.salt" | head -1)
NEXT_PEPPER_FILE=$(find "${RESTORE_DIR}" -name ".next.pepper" | head -1)

# Check for .secret.disco (OLD format - for reference only)
OLD_DISCO_FILE=$(find "${RESTORE_DIR}" -name ".secret.disco" | head -1)

RESTORE_EMAIL=""
RESTORE_SALT=""
RESTORE_PEPPER=""
IS_NEW_RELAY_RESTORE=false

# Priority: Use .next.disco for new relay/captain restoration
if [[ -f "${NEXT_DISCO_FILE}" ]]; then
    echo -e "${GREEN}✅ Next .disco key found (for restoration on NEW relay/captain)${NC}"
    echo -e "${CYAN}   🔮 This backup is ready for migration to a new relay/captain${NC}"
    
    # Extract email, salt, and pepper from .next.disco file
    DISCO_CONTENT=$(cat "${NEXT_DISCO_FILE}")
    echo -e "${CYAN}   📋 Next DISCO content: ${DISCO_CONTENT:0:50}...${NC}"
    
    # Parse DISCO format: /?email=salt&nostr=pepper
    if [[ "$DISCO_CONTENT" =~ ^/\?([^=]+)=([^&]+)\&nostr=(.+)$ ]]; then
        RESTORE_EMAIL="${BASH_REMATCH[1]}"
        RESTORE_SALT="${BASH_REMATCH[2]}"
        RESTORE_PEPPER="${BASH_REMATCH[3]}"
        IS_NEW_RELAY_RESTORE=true
        
        echo -e "${GREEN}   📧 Email: ${RESTORE_EMAIL}${NC}"
        echo -e "${GREEN}   🔐 New Salt: ${RESTORE_SALT:0:20}...${NC}"
        echo -e "${GREEN}   🔐 New Pepper: ${RESTORE_PEPPER:0:20}...${NC}"
        
        # Verify with .next.salt and .next.pepper files if available
        if [[ -f "${NEXT_SALT_FILE}" ]] && [[ -f "${NEXT_PEPPER_FILE}" ]]; then
            VERIFY_SALT=$(cat "${NEXT_SALT_FILE}")
            VERIFY_PEPPER=$(cat "${NEXT_PEPPER_FILE}")
            if [[ "$RESTORE_SALT" == "$VERIFY_SALT" ]] && [[ "$RESTORE_PEPPER" == "$VERIFY_PEPPER" ]]; then
                echo -e "${GREEN}   ✅ Salt/Pepper verified against backup files${NC}"
            fi
        fi
        
        # Show next HEX if available
        if [[ -f "${NEXT_HEX_FILE}" ]]; then
            NEXT_HEX=$(cat "${NEXT_HEX_FILE}")
            echo -e "${CYAN}   🔮 Next HEX (pre-generated): ${NEXT_HEX:0:20}...${NC}"
            echo -e "${CYAN}   💡 This HEX will be used for the new MULTIPASS on this relay${NC}"
        fi
        
        echo -e "${YELLOW}   ⚠️  IMPORTANT: This is a NEW .disco for restoration on a NEW relay/captain${NC}"
        echo -e "${YELLOW}   ⚠️  The old .secret.disco will NOT work on a new relay${NC}"
    else
        echo -e "${RED}❌ Invalid DISCO format in .next.disco${NC}"
        RESTORE_EMAIL=""
        RESTORE_SALT=""
        RESTORE_PEPPER=""
    fi
elif [[ -f "${OLD_DISCO_FILE}" ]]; then
    # Fallback to old .secret.disco (for backward compatibility)
    echo -e "${YELLOW}⚠️  Old .secret.disco found (legacy format)${NC}"
    echo -e "${YELLOW}   ⚠️  This is the OLD .disco - it may not work on a new relay${NC}"
    echo -e "${CYAN}   🔑 Attempting restoration with old credentials...${NC}"
    
    # Extract email, salt, and pepper from old .disco file
    DISCO_CONTENT=$(cat "${OLD_DISCO_FILE}")
    echo -e "${CYAN}   📋 Old DISCO content: ${DISCO_CONTENT:0:50}...${NC}"
    
    # Parse DISCO format: /?email=salt&nostr=pepper
    if [[ "$DISCO_CONTENT" =~ ^/\?([^=]+)=([^&]+)\&nostr=(.+)$ ]]; then
        RESTORE_EMAIL="${BASH_REMATCH[1]}"
        RESTORE_SALT="${BASH_REMATCH[2]}"
        RESTORE_PEPPER="${BASH_REMATCH[3]}"
        IS_NEW_RELAY_RESTORE=false
        
        echo -e "${GREEN}   📧 Email: ${RESTORE_EMAIL}${NC}"
        echo -e "${GREEN}   🔐 Old Salt: ${RESTORE_SALT:0:20}...${NC}"
        echo -e "${GREEN}   🔐 Old Pepper: ${RESTORE_PEPPER:0:20}...${NC}"
        echo -e "${YELLOW}   ⚠️  WARNING: Using old .disco - restoration may fail on new relay${NC}"
        echo -e "${YELLOW}   💡 For new relay/captain, use .next.disco from a recent backup${NC}"
    else
        echo -e "${RED}❌ Invalid DISCO format in .secret.disco${NC}"
        RESTORE_EMAIL=""
        RESTORE_SALT=""
        RESTORE_PEPPER=""
    fi
else
    echo -e "${YELLOW}⚠️  No .disco found (limited restoration)${NC}"
    echo -e "${CYAN}   💡 Full account restoration requires .next.disco or .secret.disco${NC}"
    RESTORE_EMAIL=""
    RESTORE_SALT=""
    RESTORE_PEPPER=""
fi

# Check for ZEN Card files (current + numbered historical versions)
ZEN_SECRET_JUNE=$(find "${RESTORE_DIR}" -name "secret.june" -not -name "secret.june.*" | head -1)
ZEN_G1PUB=$(find "${RESTORE_DIR}" -name ".g1pub" | head -1)
# Find all numbered secret.june.NNN.* (cooperative shares history)
ZEN_JUNE_HISTORY=()
while IFS= read -r -d '' f; do
    ZEN_JUNE_HISTORY+=("$f")
done < <(find "${RESTORE_DIR}" -name "secret.june.[0-9]*" -print0 2>/dev/null | sort -z)

if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
    echo -e "${GREEN}✅ ZEN Card secret.june found${NC}"
    echo -e "${CYAN}   💰 Capital history preserved${NC}"
    if [[ ${#ZEN_JUNE_HISTORY[@]} -gt 0 ]]; then
        echo -e "${GREEN}   📜 ${#ZEN_JUNE_HISTORY[@]} historical version(s) found (cooperative shares)${NC}"
        for f in "${ZEN_JUNE_HISTORY[@]}"; do
            echo -e "${CYAN}      $(basename "$f")${NC}"
        done
    fi
else
    echo -e "${YELLOW}⚠️  No ZEN Card secret.june found (no capital history)${NC}"
fi

if [[ -f "${ZEN_G1PUB}" ]]; then
    echo -e "${GREEN}✅ ZEN Card .g1pub found${NC}"
    echo -e "${CYAN}   🏦 G1 wallet access preserved${NC}"
else
    echo -e "${YELLOW}⚠️  No ZEN Card .g1pub found (no G1 wallet)${NC}"
fi

# Detect UPlanet change (different UPLANETNAME = different cooperative)
BACKUP_UPLANETNAME_FILE=$(find "${RESTORE_DIR}" -name ".uplanetname" | head -1)
SAME_UPLANET=true
if [[ -f "${BACKUP_UPLANETNAME_FILE}" ]]; then
    BACKUP_UPLANETNAME=$(cat "${BACKUP_UPLANETNAME_FILE}")
    if [[ "${BACKUP_UPLANETNAME}" != "${UPLANETNAME}" ]]; then
        SAME_UPLANET=false
        echo -e "${YELLOW}⚠️  UPlanet change detected: ${BACKUP_UPLANETNAME} → ${UPLANETNAME}${NC}"
        echo -e "${CYAN}   📜 ZEN Card history will be archived (new cooperative)${NC}"
        echo -e "${CYAN}   💰 No cashback restoration (different UPlanet)${NC}"
    else
        echo -e "${GREEN}✅ Same UPlanet: ${UPLANETNAME} (cashback will be restored)${NC}"
    fi
else
    echo -e "${CYAN}   ℹ️  No UPlanet info in backup (legacy format, assuming same UPlanet)${NC}"
fi

# Step 3: Process and import events
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
        if [[ "$IS_NEW_RELAY_RESTORE" == "true" ]]; then
            echo -e "${CYAN}   🔄 Recreating MULTIPASS with NEW credentials (for new relay/captain)...${NC}"
            echo -e "${GREEN}   ✅ Using pre-generated .next.disco for restoration on this new relay${NC}"
        else
            echo -e "${CYAN}   🔄 Recreating MULTIPASS with original credentials...${NC}"
            echo -e "${YELLOW}   ⚠️  Using old .secret.disco (may not work on new relay)${NC}"
        fi
        
        # Recreate MULTIPASS with salt/pepper
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
                        
                        if ipfs get "${FINAL_CID}" -o "${UDRIVE_DIR}" 2>/dev/null; then
                            echo -e "${GREEN}✅ Complete uDRIVE structure restored from IPFS${NC}"
                            
                            if [[ -f "${UDRIVE_DIR}/generate_ipfs_structure.sh" ]]; then
                                echo -e "${GREEN}✅ generate_ipfs_structure.sh link verified${NC}"
                            else
                                echo -e "${YELLOW}⚠️  generate_ipfs_structure.sh not found in restored structure${NC}"
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
                    else
                        LAT="0.00"
                        LON="0.00"
                    fi
                    
                    # Get NPUB and HEX from MULTIPASS if available
                    MULTIPASS_NPUB="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/NPUB"
                    MULTIPASS_HEX="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/HEX"
                    
                    RESTORE_NPUB=""
                    RESTORE_HEX=""
                    if [[ -f "${MULTIPASS_NPUB}" ]]; then
                        RESTORE_NPUB=$(cat "${MULTIPASS_NPUB}")
                    fi
                    if [[ -f "${MULTIPASS_HEX}" ]]; then
                        RESTORE_HEX=$(cat "${MULTIPASS_HEX}")
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

                        # Restore secret.june history
                        ZEN_CARD_DIR="${HOME}/.zen/game/players/${RESTORE_EMAIL}"
                        if [[ "$SAME_UPLANET" == "false" ]]; then
                            MIGRATION_NUM=0
                            for f in "${ZEN_CARD_DIR}"/secret.june.[0-9]*; do
                                [[ -f "$f" ]] || continue
                                num_part=$(basename "$f" | sed -n 's/^secret\.june\.\([0-9]\{3\}\)\..*/\1/p')
                                [[ -n "$num_part" ]] && (( 10#$num_part >= MIGRATION_NUM )) && MIGRATION_NUM=$((10#$num_part + 1))
                            done
                            MIGRATION_TAG=$(printf "%03d" "${MIGRATION_NUM}")
                            if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
                                cp "${ZEN_SECRET_JUNE}" "${ZEN_CARD_DIR}/secret.june.${MIGRATION_TAG}.${BACKUP_UPLANETNAME:-unknown}"
                                echo -e "${YELLOW}   📜 Previous secret.june archived as secret.june.${MIGRATION_TAG} (UPlanet change)${NC}"
                            fi
                        fi
                        # Copy all existing numbered versions from backup
                        if [[ ${#ZEN_JUNE_HISTORY[@]} -gt 0 ]]; then
                            for f in "${ZEN_JUNE_HISTORY[@]}"; do
                                cp "$f" "${ZEN_CARD_DIR}/$(basename "$f")"
                            done
                            echo -e "${GREEN}   📜 Restored ${#ZEN_JUNE_HISTORY[@]} historical secret.june version(s)${NC}"
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
                # Restore numbered secret.june history if available
                if [[ ${#ZEN_JUNE_HISTORY[@]} -gt 0 ]]; then
                    for f in "${ZEN_JUNE_HISTORY[@]}"; do
                        cp "$f" "${ZEN_CARD_DIR}/$(basename "$f")"
                    done
                    echo -e "${GREEN}   📜 Restored ${#ZEN_JUNE_HISTORY[@]} historical secret.june version(s)${NC}"
                fi
            fi
            
            ## CASHBACK RESTORATION: send back ẐEN from UPLANETNAME_G1
            CASHBACK_FILE=$(find "${RESTORE_DIR}" -name ".cashback_amount" | head -1)
            RESTORE_G1PUB=""
            if [[ -f "${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/G1PUBNOSTR" ]]; then
                RESTORE_G1PUB=$(cat "${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/G1PUBNOSTR")
            fi

            if [[ "$SAME_UPLANET" == "false" ]]; then
                echo -e "${YELLOW}   ℹ️  No cashback restoration (UPlanet changed: ${BACKUP_UPLANETNAME:-?} → ${UPLANETNAME})${NC}"
            elif [[ -f "${CASHBACK_FILE}" ]] && [[ -n "${RESTORE_G1PUB}" ]]; then
                CASHBACK_RAW=$(cat "${CASHBACK_FILE}" | sed 's/[^0-9.]//g')
                if command -v bc >/dev/null 2>&1; then
                    CASHBACK_AMT=$(echo "scale=2; ${CASHBACK_RAW} - 1" | bc -l 2>/dev/null)
                    CASHBACK_HAS_VALUE=false
                    echo "${CASHBACK_AMT} > 0" | bc -l 2>/dev/null | grep -q "1" && CASHBACK_HAS_VALUE=true
                else
                    CASHBACK_AMT="${CASHBACK_RAW}"
                    CASHBACK_HAS_VALUE=false
                    [[ -n "${CASHBACK_AMT}" ]] && [[ "${CASHBACK_AMT}" != "0" ]] && [[ "${CASHBACK_AMT}" != "0.00" ]] && [[ "${CASHBACK_AMT}" != "1" ]] && [[ "${CASHBACK_AMT}" != "1.00" ]] && CASHBACK_HAS_VALUE=true
                fi

                if [[ "$CASHBACK_HAS_VALUE" == "true" ]]; then
                    echo -e "${CYAN}   💸 Restoring cashback: ${CASHBACK_AMT} Ğ1 (original ${CASHBACK_RAW} - 1 primo) → ${RESTORE_G1PUB:0:16}...${NC}"
                    if [[ ! -s ~/.zen/game/uplanet.G1.dunikey ]]; then
                        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.G1.dunikey "${UPLANETNAME}.G1" "${UPLANETNAME}.G1"
                        chmod 600 ~/.zen/game/uplanet.G1.dunikey
                    fi
                    if ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.G1.dunikey \
                            "${CASHBACK_AMT}" "${RESTORE_G1PUB}" \
                            "MULTIPASS:RESTORE:CASHBACK" 2>/dev/null; then
                        echo -e "${GREEN}   ✅ Cashback ${CASHBACK_AMT} Ğ1 sent to restored MULTIPASS${NC}"
                    else
                        echo -e "${YELLOW}   ⚠️  Cashback transfer failed (UPLANETNAME_G1 may lack funds)${NC}"
                    fi
                else
                    echo -e "${CYAN}   ℹ️  No cashback to restore (${CASHBACK_RAW} Ğ1 ≤ 1 Ğ1 primo)${NC}"
                fi
            else
                echo -e "${CYAN}   ℹ️  No cashback info in backup (pre-cashback format)${NC}"
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

if [[ -f "${MANIFEST_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}uDRIVE files:${NC}              ${GREEN}${TOTAL_FILES}${NC} (${GREEN}${TOTAL_SIZE}${NC})                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}uDRIVE status:${NC}            ${YELLOW}Manifest available for recreation${NC}        ${BLUE}║${NC}"
fi

if [[ -f "${NEXT_DISCO_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}Next .disco:${NC}             ${GREEN}Available (NEW relay/captain ready)${NC}      ${BLUE}║${NC}"
elif [[ -f "${OLD_DISCO_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}Old .disco:${NC}              ${YELLOW}Available (legacy format)${NC}              ${BLUE}║${NC}"
fi

echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ -n "$RESTORE_EMAIL" && -n "$RESTORE_SALT" && -n "$RESTORE_PEPPER" ]]; then
    echo -e "${GREEN}💡 Complete Restoration Achieved:${NC}"
    if [[ "$IS_NEW_RELAY_RESTORE" == "true" ]]; then
        echo -e "   ${GREEN}✅ MULTIPASS recreated with NEW credentials (migration to new relay/captain)${NC}"
        echo -e "   ${CYAN}✅ Using pre-generated .next.disco for restoration on this new relay${NC}"
    else
        echo -e "   ${CYAN}✅ MULTIPASS recreated with original credentials${NC}"
        echo -e "   ${YELLOW}⚠️  Using old .secret.disco (may not work on new relay)${NC}"
    fi
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
    if [[ "$IS_NEW_RELAY_RESTORE" == "true" ]]; then
        echo -e "   ${GREEN}• Your MULTIPASS has been successfully migrated to this NEW relay/captain${NC}"
    else
        echo -e "   ${CYAN}• Your complete MULTIPASS has been restored on this Astroport.ONE station${NC}"
    fi
    echo -e "   ${CYAN}• All your NOSTR events, profile, and uDRIVE files are now available${NC}"
else
    echo -e "${GREEN}💡 Next steps for the Captain:${NC}"
    echo -e "   ${CYAN}1. Verify events:${NC} cd ~/.zen/strfry && ./strfry scan '{\"authors\": [\"<HEX>\"]}'"
    if [[ -f "${MANIFEST_FILE}" ]]; then
        echo -e "   ${CYAN}2. Recreate uDRIVE:${NC} Use uDRIVE_manifest.json to restore user's files"
    fi
    if [[ -f "${NEXT_DISCO_FILE}" ]]; then
        echo -e "   ${CYAN}4. Full restoration:${NC} Use .next.disco for complete account recreation on NEW relay"
    elif [[ -f "${OLD_DISCO_FILE}" ]]; then
        echo -e "   ${CYAN}4. Full restoration:${NC} Use .secret.disco for complete account recreation"
    fi
fi
echo ""

exit 0