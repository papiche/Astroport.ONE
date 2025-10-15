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
        pprime=$(cat ~/.zen/tmp/coucou/${g1pub}.primal)
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
# Simple restore script for NOSTR backup
# Usage: ./RESTORE_INSTRUCTIONS.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   NOSTR Account Restore Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This backup contains:"
echo "  • nostr_export.json - All your Nostr events"
echo "  • All account files (keys, configs, data)"
echo ""
echo "To restore your account to a strfry relay:"
echo ""
echo "1. Navigate to your Astroport installation:"
echo "   cd ~/.zen/Astroport.ONE"
echo ""
echo "2. Run the restore script with this backup's IPFS CID:"
echo "   ./tools/nostr_RESTORE_TW.sh <IPFS_CID>"
echo ""
echo "3. Or manually import events:"
echo "   cd ~/.zen/strfry"
echo "   jq -c '.[]' nostr_export.json | ./strfry import --no-verify"
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

This backup contains:
  • nostr_export.json - ${COUNT} Nostr events
  • All account configuration files (public)
  • RESTORE_INSTRUCTIONS.sh - Quick restore guide

⚠️  SECURITY: Hidden files (.secret.*, etc.) are NOT included
   This protects your private keys from accidental exposure

═══════════════════════════════════════════════════════════════

RESTORE METHODS:

Method 1: Using Astroport restore tool (RECOMMENDED)
  $ cd ~/.zen/Astroport.ONE
  $ ./tools/nostr_RESTORE_TW.sh <IPFS_CID>

Method 2: Manual import to strfry
  $ cd ~/.zen/strfry
  $ jq -c '.[]' nostr_export.json | ./strfry import --no-verify

Method 3: Import to any Nostr relay
  Use any Nostr client that supports event import with the
  nostr_export.json file (standard Nostr event format)

═══════════════════════════════════════════════════════════════

SECURITY NOTICE:
This backup contains ONLY public data and your Nostr events.
Private keys (.secret.*) are EXCLUDED for security.

To fully restore your account, you will need:
  1. This backup (for events and public data)
  2. Your original private keys (from secure storage)

For support: ${CAPTAINEMAIL}
UPlanet Documentation: https://copylaradio.com

═══════════════════════════════════════════════════════════════
EOF

# Create ZIP archive of entire player directory (excluding hidden files)
ZIP_FILE="$HOME/.zen/tmp/${email}_nostr_backup_$(date +%Y%m%d_%H%M%S).zip"
echo "Creating ZIP archive: ${ZIP_FILE}"
echo "Excluding hidden files (.*) for security..."
cd "$(dirname "${OUTPUT_DIR}")"
# Exclude all hidden files and directories (starting with .)
zip -r "${ZIP_FILE}" "$(basename "${OUTPUT_DIR}")" -x "*/.*" -x ".*" > /dev/null 2>&1
cd - > /dev/null 2>&1

# Add ZIP to IPFS
echo "Adding ZIP to IPFS..."
NOSTRIFS=$(ipfs add -q "${ZIP_FILE}" | tail -n 1)
ipfs pin rm ${NOSTRIFS} 2>/dev/null
echo "Backup ZIP added to IPFS: ${NOSTRIFS}"

# Clean up temporary ZIP file
rm -f "${ZIP_FILE}"

echo "DELETING ${player} NOSTRCARD : $pubnostr"
## 1. REMOVE NOSTR PROFILE
$MY_PATH/../tools/nostr_remove_profile.py "${secnostr}" "$myRELAY" "wss://relay.copylaradio.com"

## 2. CASH BACK
${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/nostr.dunikey "${salt}" "${pepper}"
AMOUNT=$(${MY_PATH}/../tools/G1check.sh ${g1pubnostr} | tail -n 1)
echo "______ AMOUNT = ${AMOUNT} G1"
## EMPTY AMOUNT G1 to PRIMAL
prime=$(cat ~/.zen/tmp/coucou/${g1pubnostr}.primal 2>/dev/null)
[[ -z $prime ]] && prime=${UPLANETG1PUB}
if [[ -n ${AMOUNT} && ${AMOUNT} != "null" ]]; then
    ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "$AMOUNT" "$prime" "MULTIPASS:$youser:PRIMAL:CASH-BACK" 2>/dev/null
fi
rm ~/.zen/tmp/nostr.dunikey

## 2. REMOVE ZEN CARD
if [[ -s "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" ]]; then
    echo "/PLAYER.unplug : TW + ZEN CARD"
    ${MY_PATH}/../RUNTIME/PLAYER.unplug.sh "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" "${player}" "ALL"
fi

## SEND EMAIL with g1pubnostr.QR
EMAIL_TEMPLATE=$(cat "${MY_PATH}/../templates/NOSTR/wallet_deactivation.html" \
    | sed -e "s~_myIPFS_~${myIPFS}~g" \
          -e "s~_NOSTRIFS_~${NOSTRIFS}~g" \
          -e "s~_SALT_~${salt}~g" \
          -e "s~_PEPPER_~${pepper}~g" \
          -e "s~_uSPOT_~${uSPOT}~g")

${MY_PATH}/../tools/mailjet.sh \
    "${player}" \
    "${EMAIL_TEMPLATE}" \
    "${youser} : MULTIPASS missing ẐEN !"

## REMOVE NOSTR IPNS VAULT key
#~ ipfs name publish -k "${g1pubnostr}:NOSTR" $(cat "${HOME}/.zen/game/nostr/${player}/MULTIPASS.QR.png.cid") ## "G1QR" CID
ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1

## Cleaning local cache
rm ~/.zen/tmp/coucou/${g1pubnostr-null}.*
rm -Rf ~/.zen/game/nostr/${player-null}

## Cleaning Node (& Swarm cache)
rm -Rf ~/.zen/tmp/$IPFSNODEID/TW/${player-null}


exit 0
