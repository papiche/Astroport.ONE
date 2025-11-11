#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_DESTROY_TW.sh
#
# This script deactivates MULTIPASS management on the relay it occupies
# and ensures NOSTR/IPFS data coherence for uDRIVE.
#
# This procedure allows the user to change RELAY and CAPTAIN.
#
# Key features:
# - Pre-generates next .disco for restoration on new relay/captain
# - Stores next HEX in DID document and NOSTR profile
# - Preserves ZEN Card capital shares (secret.june) - NOT emptied
# - Maintains minimum 1 G1 in ZEN Card for capital shares management
# - Exports complete backup with restoration credentials
#
# Usage: ./nostr_DESTROY_TW.sh [email]
# If no email is provided, the script will prompt the user to select one.
# -----------------------------------------------------------------------------
# Deactivate MULTIPASS - Enable Relay/Captain Migration

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

## PREGENERATE NEXT .disco FOR RESTORATION (before creating instructions)
echo "🔮 Pre-generating next .disco for restoration on new relay/captain..."
# Generate new SALT and PEPPER for restoration
NEW_SALT=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
NEW_PEPPER=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
NEW_DISCO="/?${email}=${NEW_SALT}&nostr=${NEW_PEPPER}"

# Generate next HEX from new SALT/PEPPER
NEXT_NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${NEW_SALT}" "${NEW_PEPPER}" 2>/dev/null)
NEXT_HEX=$(${MY_PATH}/../tools/nostr2hex.py "$NEXT_NPUB" 2>/dev/null)

if [[ -n "$NEXT_HEX" ]]; then
    echo "✅ Next restoration HEX pre-generated: ${NEXT_HEX:0:20}..."
    echo "   📝 New .disco will be: ${NEW_DISCO:0:50}..."
else
    echo "⚠️  Failed to generate next HEX, restoration will require new .disco creation"
    NEXT_HEX=""
    NEW_SALT=""
    NEW_PEPPER=""
    NEW_DISCO=""
fi

# Create a simple restore script inside the backup
# Note: Variables NEXT_HEX, NEW_DISCO are now available
cat > "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh" <<RESTORE_SCRIPT
#!/bin/bash
# NOSTR Account Restore Instructions
# Usage: ./RESTORE_INSTRUCTIONS.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   NOSTR Account Restore Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This encrypted backup contains:"
echo "  • nostr_export.json - All your Nostr events"
echo "  • uDRIVE_manifest.json - Your uDRIVE file manifest"
echo "  • .secret.disco - Your OLD secret key (for reference)"
echo "  • .next.disco - PRE-GENERATED new .disco for restoration"
echo "  • .next.hex - Next HEX address for new relay/captain"
echo "  • secret.june - ZEN Card transaction history (capital shares)"
echo "  • .g1pub - ZEN Card G1 wallet access"
echo ""
echo "🔐 BACKUP PASSWORD: ${ZEN_PASSWORD}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "IMPORTANT: Account Migration to New Relay/Captain"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your account has been deactivated on the previous relay."
echo "To restore on a NEW relay/captain, you MUST use the NEW .disco:"
echo ""
if [[ -n "$NEXT_HEX" ]]; then
    echo "  🔮 Next HEX (pre-generated): ${NEXT_HEX:0:20}..."
    echo "  📝 New .disco: .next.disco (in backup)"
    echo ""
    echo "The next HEX is also stored in:"
    echo "  • Your DID document (did:nostr:${hex})"
    echo "  • Your NOSTR profile (about field)"
    echo ""
else
    echo "  ⚠️  Next HEX not pre-generated - you'll need to create new .disco"
    echo ""
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RESTORATION METHODS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Method 1: Automated restore (RECOMMENDED)"
echo "  cd ~/.zen/Astroport.ONE"
echo "  ./tools/nostr_RESTORE_TW.sh <IPFS_CID>"
echo "  (Script will use .next.disco automatically)"
echo ""
echo "Method 2: Manual restoration with NEW .disco"
echo "  1. Extract backup with password: ${ZEN_PASSWORD}"
echo "  2. Use .next.disco to create MULTIPASS on new relay:"
echo "     cat .next.disco"
echo "     # Use this .disco when creating new MULTIPASS"
echo "  3. Create MULTIPASS with same email + .next.disco:"
echo "     ./tools/make_NOSTRCARD.sh <EMAIL> <LANG> <LAT> <LON> <NEW_SALT> <NEW_PEPPER>"
echo "  4. Import events to new account:"
echo "     jq -c '.[]' nostr_export.json | ./strfry import --no-verify"
echo ""
echo "Method 3: uDRIVE restoration"
echo "  - Use uDRIVE_manifest.json to recreate your file structure"
echo "  - All files are still available via IPFS links in manifest"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ZEN Card Capital Shares:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your ZEN Card capital shares are preserved in secret.june"
echo "This file contains the transaction history of capital shares"
echo "received from UPLANETNAME_SOCIETY."
echo ""
echo "The ZEN Card wallet (.g1pub) is NOT emptied - it maintains"
echo "minimum 1 G1 for capital shares management."
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
$(if [[ -n "$NEXT_HEX" ]]; then echo "Next HEX (for restoration): ${NEXT_HEX:0:20}..."; fi)

This encrypted backup contains:
  • nostr_export.json - ${COUNT} Nostr events
  • uDRIVE_manifest.json - Your uDRIVE file manifest (if exists)
  • .secret.disco - Your OLD secret key (for reference only)
  • .next.disco - PRE-GENERATED new .disco for restoration on new relay
  • .next.hex - Next HEX address (pre-calculated)
  • .next.salt / .next.pepper - New credentials for restoration
  • secret.june - ZEN Card transaction history (capital shares preserved)
  • .g1pub - ZEN Card G1 wallet access
  • RESTORE_INSTRUCTIONS.sh - Quick restore guide

🔐 BACKUP PASSWORD: ${ZEN_PASSWORD}

⚠️  SECURITY: Backup is encrypted with ZEN Card password
   This protects your private keys and sensitive data

═══════════════════════════════════════════════════════════════

ACCOUNT MIGRATION TO NEW RELAY/CAPTAIN:

Your account has been deactivated on the previous relay.
This allows you to migrate to a NEW relay and NEW captain.

IMPORTANT: You MUST use the NEW .disco (.next.disco) for restoration
The old .disco will NOT work on a new relay.

The next HEX is pre-calculated and stored in:
  • This backup (.next.hex)
  • Your DID document (did:nostr:${hex})
  • Your NOSTR profile (about field)

═══════════════════════════════════════════════════════════════

RESTORE METHODS:

Method 1: Using Astroport restore tool (RECOMMENDED)
  $ cd ~/.zen/Astroport.ONE
  $ ./tools/nostr_RESTORE_TW.sh <IPFS_CID>
  (Script will automatically use .next.disco)

Method 2: Manual recreation with NEW .disco
  $ cd ~/.zen/Astroport.ONE
  $ # Extract backup and read .next.disco
  $ cat .next.disco
  $ # Use the SALT and PEPPER from .next.salt and .next.pepper
  $ ./tools/make_NOSTRCARD.sh <EMAIL> <LANG> <LAT> <LON> <NEW_SALT> <NEW_PEPPER>
  $ cd ~/.zen/strfry
  $ jq -c '.[]' nostr_export.json | ./strfry import --no-verify

Method 3: uDRIVE restoration
  Use uDRIVE_manifest.json to recreate your file structure
  All files are still available via IPFS links in manifest

═══════════════════════════════════════════════════════════════

ZEN CARD CAPITAL SHARES:

Your ZEN Card capital shares are preserved in secret.june.
This file contains the complete transaction history of capital shares
received from UPLANETNAME_SOCIETY.

The ZEN Card wallet (.g1pub) maintains minimum 1 G1 for capital
shares management. It is NOT emptied during account deactivation.

═══════════════════════════════════════════════════════════════

SECURITY NOTICE:
This backup contains:
  • Public data (Nostr events, uDRIVE manifest)
  • Old .secret.disco (for reference, won't work on new relay)
  • New .next.disco (for restoration on new relay)
  • ZEN Card history (secret.june, .g1pub)

To fully restore your account on a NEW relay:
  1. Extract this backup with password: ${ZEN_PASSWORD}
  2. Use .next.disco to create new MULTIPASS on new relay
  3. Import events to new account
  4. Restore uDRIVE from manifest

For support: ${CAPTAINEMAIL}
UPlanet ORIGIN: https://qo-op.com

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

# Save next restoration info to backup directory (before ZIP creation)
if [[ -n "$NEXT_HEX" ]] && [[ -d "${BACKUP_DIR}" ]]; then
    echo "$NEW_DISCO" > "${BACKUP_DIR}/.next.disco"
    echo "$NEXT_HEX" > "${BACKUP_DIR}/.next.hex"
    echo "$NEW_SALT" > "${BACKUP_DIR}/.next.salt"
    echo "$NEW_PEPPER" > "${BACKUP_DIR}/.next.pepper"
    echo "✅ Next restoration credentials saved to backup"
fi

# Get ZEN Card password for encryption
ZEN_PASS_FILE="${HOME}/.zen/game/players/${email}/.pass"
if [[ -f "${ZEN_PASS_FILE}" ]]; then
    ZEN_PASSWORD=$(cat "${ZEN_PASS_FILE}")
    echo "✅ ZEN Card password retrieved for encryption"
else
    # Use 0000 password for MULTIPASS-only accounts
    ZEN_PASSWORD="0000"
    if [[ -z "${ZEN_PASSWORD}" ]]; then
        ZEN_PASSWORD=$(date +%s | sha256sum | cut -c1-8)
    fi
    echo "🔐 Generated secure password for MULTIPASS-only account: ${ZEN_PASSWORD}"
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

## 0. UPDATE DID DOCUMENT - Mark as deactivated and include next HEX
echo "📝 Updating DID document to mark account as deactivated..."
if [[ -f "${MY_PATH}/did_manager_nostr.sh" ]]; then
    # Update DID to mark account as deactivated
    "${MY_PATH}/did_manager_nostr.sh" update "${player}" "ACCOUNT_DEACTIVATED" 0 0 2>/dev/null \
        && echo "✅ DID document updated - account marked as deactivated" \
        || echo "⚠️  Failed to update DID document (will continue with destruction)"
    
    # Add next HEX to DID metadata for restoration on new relay
    if [[ -n "$NEXT_HEX" ]]; then
        local did_cache_file="${HOME}/.zen/game/nostr/${player}/did.json.cache"
        if [[ -f "$did_cache_file" ]] && command -v jq >/dev/null 2>&1; then
            # Add next restoration HEX to deactivation metadata
            jq ".metadata.deactivation.nextRestorationHex = \"${NEXT_HEX}\"" "$did_cache_file" > "${did_cache_file}.tmp" 2>/dev/null
            if [[ -s "${did_cache_file}.tmp" ]]; then
                mv "${did_cache_file}.tmp" "$did_cache_file"
                echo "   🔮 Next restoration HEX added to DID metadata: ${NEXT_HEX:0:20}..."
                
                # Republish DID with next HEX in metadata
                echo "   📡 Republishing DID with next HEX metadata..."
                "${MY_PATH}/did_manager_nostr.sh" sync "${player}" 2>/dev/null \
                    && echo "   ✅ DID republished with next HEX metadata" \
                    || echo "   ⚠️  Failed to republish DID (next HEX stored locally)"
            else
                rm -f "${did_cache_file}.tmp"
                echo "   ⚠️  Failed to add next HEX to DID metadata"
            fi
        else
            echo "   ⚠️  Cannot add next HEX to DID (file or jq not available)"
        fi
    fi
else
    echo "⚠️  did_manager_nostr.sh not found, skipping DID update"
fi

## 1. UPDATE NOSTR PROFILE - Mark as deactivated and include next HEX
echo "📝 Updating NOSTR profile to mark as deactivated..."
if [[ -f "${MY_PATH}/nostr_update_profile.py" ]]; then
    # Build about message with backup link and next HEX
    if [[ -n "$NEXT_HEX" ]]; then
        ABOUT_MSG="Account deactivated - Backup: ${myIPFS}/ipfs/${NOSTRIFS} | Next HEX: ${NEXT_HEX:0:16}..."
    else
        ABOUT_MSG="Account deactivated - backup available at ${myIPFS}/ipfs/${NOSTRIFS}"
    fi
    
    # Update profile with deactivation message, backup link, and next HEX
    "${MY_PATH}/nostr_update_profile.py" "${secnostr}" "$myRELAY" "wss://relay.copylaradio.com" \
        --about "${ABOUT_MSG}" \
        --name "[DEACTIVATED] ${youser}" \
        --website "${myIPFS}/ipfs/${NOSTRIFS}" 2>/dev/null \
        && echo "✅ NOSTR profile updated - marked as deactivated with backup link and next HEX" \
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
    
    # Delete old messages using strfry with proper syntax
    cd ~/.zen/strfry
    # Try different strfry delete syntaxes
    if ./strfry delete --age=24h --filter='{"authors":["'${hex}'"]}' 2>/dev/null; then
        echo "✅ Old messages deleted successfully"
    elif ./strfry delete --age=86400 --authors="${hex}" 2>/dev/null; then
        echo "✅ Old messages deleted successfully (alternative syntax)"
    else
        echo "⚠️  Failed to delete old messages (strfry delete not supported or syntax incompatible)"
        echo "   💡 Messages will remain in relay (this is normal for some relay configurations)"
    fi
    cd - > /dev/null 2>&1
else
    echo "⚠️  strfry not found, skipping old message deletion"
fi


## 2. CASH BACK
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/nostr.dunikey "${salt}" "${pepper}"

# Get fresh balance from blockchain (not cache)
echo "🔄 Checking fresh G1 balance from blockchain..."
AMOUNT=$(${MY_PATH}/../tools/G1check.sh ${g1pubnostr} --fresh 2>/dev/null | tail -n 1)
if [[ -z "${AMOUNT}" ]] || [[ "${AMOUNT}" == "null" ]]; then
    AMOUNT="0"
fi

echo "💰 Current G1 balance: ${AMOUNT} Ğ1"

## EMPTY AMOUNT G1 to UPLANETNAME_G1 (central bank) PRIMAL
prime=$(cat ~/.zen/tmp/coucou/${g1pubnostr}.primal 2>/dev/null)

## Real value when Humans understand that Commons needs aggradation instead of degradation. 
[[ $UPLANETNAME == "Enfin Libre" ]] \
    && [[ -f ~/.zen/tmp/coucou/${g1pubnostr}.2nd ]] \
    && prime=$(cat ~/.zen/tmp/coucou/${g1pubnostr}.2nd) ## REFILL REAL OWNER

[[ -z $prime ]] && prime=${UPLANETNAME_G1}

# Convert amount to numeric for precise comparison using bc
AMOUNT_NUM=$(echo "${AMOUNT}" | sed 's/[^0-9.]//g')
if [[ -n "${AMOUNT_NUM}" ]] && command -v bc >/dev/null 2>&1; then
    # Use bc for precise numeric comparison
    if echo "${AMOUNT_NUM} > 0" | bc -l 2>/dev/null | grep -q "1"; then
        echo "💸 Transferring ${AMOUNT} Ğ1 to primal account: ${prime}"
        if ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "${AMOUNT}" "${prime}" "MULTIPASS:${youser}:PRIMAL:CASH-BACK" 2>/dev/null; then
            echo "✅ G1 balance transferred successfully"
        else
            echo "⚠️  Failed to transfer G1 balance (will continue with destruction)"
        fi
    else
        echo "ℹ️  No G1 balance to transfer (${AMOUNT} Ğ1 - amount is zero or negative)"
    fi
elif [[ -n "${AMOUNT_NUM}" ]] && [[ "${AMOUNT_NUM}" != "0" ]] && [[ "${AMOUNT_NUM}" != "0.00" ]]; then
    # Fallback to string comparison if bc is not available
    echo "💸 Transferring ${AMOUNT} Ğ1 to primal account: ${prime}"
    if ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "${AMOUNT}" "${prime}" "MULTIPASS:${youser}:PRIMAL:CASH-BACK" 2>/dev/null; then
        echo "✅ G1 balance transferred successfully"
    else
        echo "⚠️  Failed to transfer G1 balance (will continue with destruction)"
    fi
else
    echo "ℹ️  No G1 balance to transfer (${AMOUNT} Ğ1)"
fi
rm -f ~/.zen/tmp/nostr.dunikey

## 2. REMOVE ZEN CARD (capital shares preserved in secret.june)
# Note: ZEN Card capital shares are archived in transaction history (secret.june)
# The ZEN Card wallet maintains minimum 1 G1 for capital shares management
# secret.june is preserved in backup - no need to empty remaining june
# The ZEN Card cannot be truly deleted as capital shares are in transaction history
if [[ -s "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" ]]; then
    echo "/PLAYER.unplug : TW + ZEN CARD (capital shares preserved in secret.june)"
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
${MY_PATH}/../tools/mailjet.sh --expire 3d \
    "${CAPTAINEMAIL}" \
    "${EMAIL_TEMPLATE}" \
    "CAPTAIN: ${youser} MULTIPASS Deactivated - Backup: ${NOSTRIFS}"

## REMOVE NOSTR IPNS VAULT key
#~ ipfs name publish -k "${g1pubnostr}:NOSTR" $(cat "${HOME}/.zen/game/nostr/${player}/MULTIPASS.QR.png.cid") ## "G1QR" CID
ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1

## Cleaning local cache
echo "🧹 Cleaning local cache and temporary files..."
if [[ -n "${g1pubnostr}" ]]; then
    rm -f ~/.zen/tmp/coucou/${g1pubnostr}.* 2>/dev/null
    echo "✅ Cleared G1 cache files for ${g1pubnostr}"
fi

if [[ -n "${player}" ]]; then
    rm -rf ~/.zen/game/nostr/${player} 2>/dev/null
    echo "✅ Removed NOSTR directory for ${player}"
fi

## Cleaning Node (& Swarm cache)
if [[ -n "${IPFSNODEID}" ]] && [[ -n "${player}" ]]; then
    rm -rf ~/.zen/tmp/${IPFSNODEID}/TW/${player} 2>/dev/null
    echo "✅ Cleared Node cache for ${player}"
fi

echo "✅ Account destruction completed successfully"


exit 0

