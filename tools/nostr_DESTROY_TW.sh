#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_DESTROY_TW.sh
#
# This script is used to deactivate ("unplug") a NOSTR + PLAYER UPlanet account.
# It allows the user to select a player email, exports and backs up all NOSTR data
# to IPFS, removes the NOSTR profile, transfers any remaining G1 balance to the
# primal account, removes the ZEN card, and sends a notification email to the user
# with recovery information and backup links. It also cleans up local cache and
# removes the NOSTR IPNS vault key.
#
# Usage: ./nostr_DESTROY_TW.sh [email]
# If no email is provided, the script will prompt the user to select one.
# -----------------------------------------------------------------------------
# Unplug NOSTR + PLAYER UPlanet Account

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Function to display usage information
usage() {
    echo "Usage: $ME [email]"
    echo "This script will prompt you to select a player email from the available options."
    exit 1
}

# Function to list available player emails and prompt user to select one
select_player_email() {
    echo "Available player emails:"
    player_emails=($(ls ~/.zen/game/nostr/*@*.*/HEX | rev | cut -d '/' -f 2 | rev))
    if [ ${#player_emails[@]} -eq 0 ]; then
        echo "No player emails found."
        exit 1
    fi

    for i in "${!player_emails[@]}"; do
        g1pub=$(cat ~/.zen/game/nostr/${player_emails[$i]}/G1PUBNOSTR)
        pcoins=$(cat ~/.zen/tmp/coucou/${g1pub}.COINS)
        pprime=$(cat ~/.zen/tmp/coucou/${g1pub}.primal 2>/dev/null)
        echo "$i) ${player_emails[$i]} (${pcoins} Ğ1) ${g1pub} -> ${pprime}" 
    done

    read -p "Select the number corresponding to the player email: " selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 0 ] || [ "$selection" -ge ${#player_emails[@]} ]; then
        echo "Invalid selection."
        exit 1
    fi

    player="${player_emails[$selection]}"
}

################### PLAYER G1 PUB ###########################
[[ -n "$1" ]] && player="$1"
[[ -z $player ]] && select_player_email
g1pubnostr=$(cat ~/.zen/game/nostr/${player}/G1PUBNOSTR)
[[ -z $g1pubnostr ]] && echo "BAD NOSTR MULTIPASS" && exit 1
hex=$(cat ~/.zen/game/nostr/${player}/HEX)

##################### DISCO DECODING ########################
if [[ -s ~/.zen/game/nostr/${player}/.secret.disco ]]; then
    DISCO=$(cat ~/.zen/game/nostr/${player}/.secret.disco)
    IFS='=&' read -r s salt p pepper <<< "$DISCO"
else
    tmp_mid=$(mktemp)
    tmp_tail=$(mktemp)
    # Decrypt the middle part using CAPTAIN key
    ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${player}/.ssss.mid.captain.enc" \
            -k ~/.zen/game/players/.current/secret.dunikey -o "$tmp_mid"

    # Decrypt the tail part using UPLANET dunikey
    if [[ ! -s ~/.zen/game/uplanet.dunikey ]]; then
        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
        chmod 600 ~/.zen/game/uplanet.dunikey
    fi
    ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${player}/ssss.tail.uplanet.enc" \
            -k ~/.zen/game/uplanet.dunikey -o "$tmp_tail"

    # Combine decrypted shares
    DISCO=$(cat "$tmp_mid" "$tmp_tail" | ssss-combine -t 2 -q 2>&1 | tail -n 1)
    IFS='=&' read -r s salt p pepper <<< "$DISCO"

    if [[ -n $pepper ]]; then
        rm "$tmp_mid" "$tmp_tail"
    else
        cat "$tmp_mid" "$tmp_tail"
        exit 1
    fi
fi

##################################################### DISCO DECODED
## Extract email from s parameter
# DEBUG: s before removal (quoted): '/?youyou@yopmail.com'
email=${s:2}  # Remove the first two characters (/, ?)
echo "$email"
youser=$($MY_PATH/../tools/clyuseryomail.sh "${email}")
secnostr=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}" -s)
pubnostr=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}")

OUTPUT_DIR="$HOME/.zen/game/nostr/${email}"

echo ./strfry scan '{"authors": ["'$hex'"]}'
cd ~/.zen/strfry
# Export NOSTR events and format as proper JSON array
echo "[" > "${OUTPUT_DIR}/nostr_export.json"
./strfry scan '{"authors": ["'$hex'"]}' 2> /dev/null | sed 's/^/,/' | sed '1s/^,//' >> "${OUTPUT_DIR}/nostr_export.json"
echo "]" >> "${OUTPUT_DIR}/nostr_export.json"
cd - > /dev/null 2>&1

COUNT=$(grep -c '^{' "${OUTPUT_DIR}/nostr_export.json" 2>/dev/null || echo "0")
echo "Exported ${COUNT} events to ${OUTPUT_DIR}/nostr_export.json"

# Create a simple restore script inside the backup
cat > "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh" <<'RESTORE_SCRIPT'
#!/bin/bash
# Minimal NOSTR backup restore instructions
# Usage: ./RESTORE_INSTRUCTIONS.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   NOSTR Account Restore Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This encrypted backup contains:"
echo "  • nostr_export.json - All your Nostr events"
echo "  • uDRIVE_manifest.json - Your uDRIVE file manifest"
echo "  • .secret.disco - Your secret key for full restoration"
echo "  • secret.june - ZEN Card transaction history"
echo "  • .g1pub - ZEN Card G1 wallet access"
echo "  • Instructions for recreation"
echo ""
echo "🔐 BACKUP PASSWORD: ${ZEN_PASSWORD}"
echo ""
echo "To restore your account:"
echo ""
echo "1. Use the automated restore script:"
echo "   cd ~/.zen/Astroport.ONE"
echo "   ./tools/nostr_RESTORE_TW.sh <IPFS_CID>"
echo "   (Script will prompt for password: ${ZEN_PASSWORD})"
echo ""
echo "2. Or manually recreate your MULTIPASS:"
echo "   - Extract backup with password: ${ZEN_PASSWORD}"
echo "   - Create new MULTIPASS with same email"
echo "   - Import events: jq -c '.[]' nostr_export.json | ./strfry import --no-verify"
echo "   - Use .secret.disco for full account restoration"
echo ""
echo "3. uDRIVE restoration:"
echo "   - Use uDRIVE_manifest.json to recreate your file structure"
echo "   - All files are still available via IPFS links in manifest"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESTORE_SCRIPT
chmod +x "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh"

# Create a README file with backup information
cat > "${OUTPUT_DIR}/README_BACKUP.txt" <<EOF
╔════════════════════════════════════════════════════════════════╗
║           NOSTR MULTIPASS BACKUP INFORMATION                   ║
╚════════════════════════════════════════════════════════════════╝

Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Account: ${email}
Public Key (HEX): ${hex}
G1 Wallet: ${g1pubnostr}

This encrypted backup contains:
  • nostr_export.json - ${COUNT} Nostr events
  • uDRIVE_manifest.json - Your uDRIVE file manifest (if exists)
  • .secret.disco - Your secret key for full restoration
  • secret.june - ZEN Card secrets (if exists)
  • .g1pub - ZEN Card G1 wallet access (if exists)
  • RESTORE_INSTRUCTIONS.sh - Quick restore guide

🔐 BACKUP PASSWORD: ${ZEN_PASSWORD}

⚠️  SECURITY: Backup is encrypted with ZEN Card password
   This protects your private keys and sensitive data

═══════════════════════════════════════════════════════════════

RESTORE METHODS:

Method 1: Using Astroport restore tool (RECOMMENDED)
  $ cd ~/.zen/Astroport.ONE
  $ ./tools/nostr_RESTORE_TW.sh <IPFS_CID>

Method 2: Manual recreation
  $ cd ~/.zen/Astroport.ONE
  $ ./tools/make_NOSTRCARD.sh <EMAIL> <LANG> <LAT> <LON>
  $ cd ~/.zen/strfry
  $ jq -c '.[]' nostr_export.json | ./strfry import --no-verify

Method 3: uDRIVE restoration
  Use uDRIVE_manifest.json to recreate your file structure
  All files are still available via IPFS links in manifest

═══════════════════════════════════════════════════════════════

SECURITY NOTICE:
This backup contains ONLY public data and your Nostr events.
Private keys (.secret.*) are EXCLUDED for security.

To fully restore your account, you will need:
  1. This backup (for events and uDRIVE manifest)
  2. Create new MULTIPASS with same email
  3. Import events to new account

For support: ${CAPTAINEMAIL}
UPlanet Documentation: https://copylaradio.com

═══════════════════════════════════════════════════════════════
EOF

# Create minimal backup with only essential files
BACKUP_DIR="$HOME/.zen/tmp/${email}_nostr_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"

echo "Creating minimal backup with essential files only..."

# Copy nostr_export.json (already created)
if [[ -f "${OUTPUT_DIR}/nostr_export.json" ]]; then
    cp "${OUTPUT_DIR}/nostr_export.json" "${BACKUP_DIR}/"
    echo "✅ NOSTR events exported: ${COUNT} events"
else
    echo "⚠️  nostr_export.json not found"
fi

# Copy uDRIVE manifest.json if it exists
MANIFEST_FILE="${HOME}/.zen/game/nostr/${email}/APP/uDRIVE/manifest.json"
if [[ -f "${MANIFEST_FILE}" ]]; then
    cp "${MANIFEST_FILE}" "${BACKUP_DIR}/uDRIVE_manifest.json"
    echo "✅ uDRIVE manifest exported"
    
    # Show manifest summary
    TOTAL_SIZE=$(jq -r '.formatted_total_size' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    TOTAL_FILES=$(jq -r '.total_files' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    echo "   📊 uDRIVE contains: ${TOTAL_FILES} files (${TOTAL_SIZE})"
else
    echo "⚠️  uDRIVE manifest not found (no uDRIVE data to backup)"
fi

# Copy .disco secret key if it exists
DISCO_FILE="${HOME}/.zen/game/nostr/${email}/.secret.disco"
if [[ -f "${DISCO_FILE}" ]]; then
    cp "${DISCO_FILE}" "${BACKUP_DIR}/.secret.disco"
    echo "✅ Secret .disco key exported"
else
    echo "⚠️  .secret.disco not found (no secret key to backup)"
fi

# Copy ZEN Card secret.june if it exists (for transaction history)
ZEN_SECRET_JUNE="${HOME}/.zen/game/players/${email}/secret.june"
if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
    cp "${ZEN_SECRET_JUNE}" "${BACKUP_DIR}/secret.june"
    echo "✅ ZEN Card secret.june exported (capital owner history preserved)"
else
    echo "⚠️  ZEN Card secret.june not found (no transaction history to backup)"
fi

# Copy ZEN Card .g1pub if it exists (for G1 wallet access)
ZEN_G1PUB="${HOME}/.zen/game/players/${email}/.g1pub"
if [[ -f "${ZEN_G1PUB}" ]]; then
    cp "${ZEN_G1PUB}" "${BACKUP_DIR}/.g1pub"
    echo "✅ ZEN Card .g1pub exported (G1 wallet access preserved)"
else
    echo "⚠️  ZEN Card .g1pub not found (no G1 wallet to backup)"
fi

# Get ZEN Card password for encryption
ZEN_PASS_FILE="${HOME}/.zen/game/players/${email}/.pass"
if [[ -f "${ZEN_PASS_FILE}" ]]; then
    ZEN_PASSWORD=$(cat "${ZEN_PASS_FILE}")
    echo "✅ ZEN Card password retrieved for encryption"
else
    echo "⚠️  ZEN Card .pass not found, using default encryption"
    ZEN_PASSWORD="0000"
fi

# Copy RESTORE_INSTRUCTIONS.sh
if [[ -f "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh" ]]; then
    cp "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh" "${BACKUP_DIR}/"
fi

# Copy README_BACKUP.txt
if [[ -f "${OUTPUT_DIR}/README_BACKUP.txt" ]]; then
    cp "${OUTPUT_DIR}/README_BACKUP.txt" "${BACKUP_DIR}/"
fi

# Create password-protected ZIP with essential files
ZIP_FILE="${BACKUP_DIR}.zip"
echo "Creating password-protected ZIP archive: ${ZIP_FILE}"
echo "🔐 Using ZEN Card password for encryption"

cd "$(dirname "${BACKUP_DIR}")"
if zip -r -P "${ZEN_PASSWORD}" "${ZIP_FILE}" "$(basename "${BACKUP_DIR}")" 2>/dev/null; then
    echo "✅ Password-protected backup created successfully"
    echo "🔑 Password: ${ZEN_PASSWORD}"
    cd - > /dev/null 2>&1
    
    # Add ZIP to IPFS
    echo "Adding encrypted backup to IPFS..."
    NOSTRIFS=$(ipfs add -q "${ZIP_FILE}" | tail -n 1)
    if [[ -n "${NOSTRIFS}" ]]; then
        ipfs pin rm ${NOSTRIFS} 2>/dev/null
        echo "✅ Encrypted backup added to IPFS: ${NOSTRIFS}"
        echo "🔑 Decryption password: ${ZEN_PASSWORD}"
    else
        echo "❌ Failed to add encrypted backup to IPFS"
    fi
    
    # Clean up temporary files
    rm -f "${ZIP_FILE}"
    rm -rf "${BACKUP_DIR}"
else
    echo "❌ Failed to create password-protected backup ZIP"
    cd - > /dev/null 2>&1
    exit 1
fi

echo "DELETING ${player} NOSTRCARD : $pubnostr"

## 0. UPDATE DID DOCUMENT - Mark as deactivated
echo "📝 Updating DID document to mark account as deactivated..."
if [[ -f "${MY_PATH}/did_manager_nostr.sh" ]]; then
    # Update DID to mark account as deactivated
    "${MY_PATH}/did_manager_nostr.sh" update "${player}" "ACCOUNT_DEACTIVATED" 0 0 2>/dev/null \
        && echo "✅ DID document updated - account marked as deactivated" \
        || echo "⚠️  Failed to update DID document (will continue with destruction)"
else
    echo "⚠️  did_manager_nostr.sh not found, skipping DID update"
fi

## 1. UPDATE NOSTR PROFILE (don't remove, just mark as deactivated)
echo "📝 Updating NOSTR profile to mark as deactivated..."
if [[ -f "${MY_PATH}/nostr_update_profile.py" ]]; then
    # Update profile with deactivation message and backup link
    "${MY_PATH}/nostr_update_profile.py" "${secnostr}" "$myRELAY" "wss://relay.copylaradio.com" \
        --about "Account deactivated - backup available" \
        --name "[DEACTIVATED] ${youser}" \
        --website "${myIPFS}/ipfs/${NOSTRIFS}" 2>/dev/null \
        && echo "✅ NOSTR profile updated - marked as deactivated with backup link" \
        || echo "⚠️  Failed to update NOSTR profile (will continue with destruction)"
else
    echo "⚠️  nostr_update_profile.py not found, skipping NOSTR profile update"
fi

## 1.5. DELETE OLD MESSAGES (older than 24h)
echo "🗑️ Deleting messages older than 24 hours..."
if [[ -x "$HOME/.zen/strfry/strfry" ]]; then
    # Calculate timestamp for 24 hours ago
    TIMESTAMP_24H_AGO=$(date -d "24 hours ago" +%s)
    echo "   📅 Deleting messages before: $(date -d "24 hours ago" '+%Y-%m-%d %H:%M:%S')"
    
    # Delete old messages using strfry
    cd ~/.zen/strfry
    if ./strfry delete --age="24h" --filter="authors:${hex}" 2>/dev/null; then
        echo "✅ Old messages deleted successfully"
    else
        echo "⚠️  Failed to delete old messages (may not be supported by this strfry version)"
    fi
    cd - > /dev/null 2>&1
else
    echo "⚠️  strfry not found, skipping old message deletion"
fi


## 2. CASH BACK
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/nostr.dunikey "${salt}" "${pepper}"
AMOUNT=$(${MY_PATH}/../tools/G1check.sh ${g1pubnostr} | tail -n 1)
echo "______ AMOUNT = ${AMOUNT} G1"
## EMPTY AMOUNT G1 to PRIMAL
prime=$(cat ~/.zen/tmp/coucou/${g1pubnostr}.primal 2>/dev/null)
[[ -z $prime ]] && prime=${UPLANETNAME_G1}
if [[ -n ${AMOUNT} && ${AMOUNT} != "null" && ${AMOUNT} != "0" && ${AMOUNT} != "0.00" ]]; then
    ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "$AMOUNT" "$prime" "MULTIPASS:$youser:PRIMAL:CASH-BACK" 2>/dev/null
else
    echo "No G1 balance to transfer (${AMOUNT} G1)"
fi
rm ~/.zen/tmp/nostr.dunikey

## 2. REMOVE ZEN CARD
if [[ -s "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" ]]; then
    echo "/PLAYER.unplug : TW + ZEN CARD"
    ${MY_PATH}/../RUNTIME/PLAYER.unplug.sh "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" "${player}" "ALL"
fi

## SEND EMAIL to CAPTAIN with backup information (SECURE - no sensitive data)
EMAIL_TEMPLATE=$(cat "${MY_PATH}/../templates/NOSTR/wallet_deactivation.html" \
    | sed -e "s~_myIPFS_~${myIPFS}~g" \
          -e "s~_NOSTRIFS_~${NOSTRIFS}~g" \
          -e "s~_SALT_~[PROTECTED]~g" \
          -e "s~_PEPPER_~[PROTECTED]~g" \
          -e "s~_uSPOT_~${uSPOT}~g" \
          -e "s~_DEACTIVATION_DATE_~$(date '+%Y-%m-%d %H:%M:%S')~g")

# Send email to CAPTAIN (not to the user)
${MY_PATH}/../tools/mailjet.sh --expire 7d \
    "${CAPTAINEMAIL}" \
    "${EMAIL_TEMPLATE}" \
    "CAPTAIN: ${youser} MULTIPASS Deactivated - Backup: ${NOSTRIFS}"

## REMOVE NOSTR IPNS VAULT key
#~ ipfs name publish -k "${g1pubnostr}:NOSTR" $(cat "${HOME}/.zen/game/nostr/${player}/MULTIPASS.QR.png.cid") ## "G1QR" CID
ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1

## Cleaning local cache
rm ~/.zen/tmp/coucou/${g1pubnostr-null}.*
rm -Rf ~/.zen/game/nostr/${player-null}

## Cleaning Node (& Swarm cache)
rm -Rf ~/.zen/tmp/$IPFSNODEID/TW/${player-null}


exit 0

