#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1society.sh
#~ Récupère l'historique des parts sociales distribuées
#~ Filtre les transactions entrantes depuis UPLANETNAME_G1 vers SOCIETY
#~ Calcul automatique des montants en Ğ1 et ẐEN
#~ Retourne un JSON formaté pour l'API
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Get SOCIETY wallet public key from environment
SOCIETY_G1PUB="${UPLANETNAME_SOCIETY:-}"
if [[ -z "$SOCIETY_G1PUB" ]]; then
    log "ERROR: UPLANETNAME_SOCIETY not set in environment"
    echo '{"error": "SOCIETY wallet not configured", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Get UPLANET G1 wallet public key
UPLANET_G1PUB="${UPLANETNAME_G1:-}"
if [[ -z "$UPLANET_G1PUB" ]]; then
    log "ERROR: UPLANETNAME_G1 not set in environment"
    echo '{"error": "UPLANET G1 wallet not configured", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

log "Starting SOCIETY transaction analysis"
log "SOCIETY wallet: $SOCIETY_G1PUB"
log "UPLANET G1 wallet: $UPLANET_G1PUB"

# Call G1history.sh to get transaction history
HISTORY_JSON=$(${MY_PATH}/G1history.sh "$SOCIETY_G1PUB" 2>/dev/null)

if [[ -z "$HISTORY_JSON" ]]; then
    log "ERROR: Failed to retrieve transaction history"
    echo '{"error": "Failed to retrieve history", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Validate JSON
if ! echo "$HISTORY_JSON" | jq empty 2>/dev/null; then
    log "ERROR: Invalid JSON from G1history.sh"
    echo '{"error": "Invalid history JSON", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Process history JSON with jq to filter and calculate
# Filter transactions where:
# 1. Amount is positive (incoming to SOCIETY)
# 2. Issuer matches UPLANET_G1PUB (first 8 chars of Issuers/Recipients before ':')
# 3. Reference contains "SOCIETY"
# Format attendu: "UPLANET:xxxxxxxx:SOCIETY:email@example.com:type:IPFSNODEID"
# Legacy format: "UPLANET:xxxxxxxx:SOCIETY:email@example.com:type"
RESULT=$(echo "$HISTORY_JSON" | jq -r --arg uplanet_g1 "$UPLANET_G1PUB" '
{
    g1pub: .pubkey,
    total_outgoing_g1: 0,
    total_outgoing_zen: 0,
    total_transfers: 0,
    transfers: [],
    timestamp: (now | strftime("%Y-%m-%dT%H:%M:%S"))
} as $init |

if .history then
    .history | map(
        # Parse amount
        (."Amounts Ğ1" | tonumber) as $amount_g1 |
        # Extract issuer pubkey (before ":")
        (."Issuers/Recipients" | split(":")[0]) as $issuer |
        # Get reference
        (."Reference" // "") as $reference |
        
        # Check if this is an incoming transfer from UPLANET_G1 with SOCIETY reference
        if ($amount_g1 > 0 and $issuer == $uplanet_g1 and ($reference | contains("SOCIETY"))) then
            {
                is_society_transfer: true,
                amount_g1: $amount_g1,
                amount_zen: (if $amount_g1 > 1 then (($amount_g1 - 1) * 10) else 0 end),
                date: ."Date",
                recipient: (
                    if ($reference | contains("SOCIETY:")) then
                        ($reference | split("SOCIETY:")[1] | split(":")[0])
                    else
                        "N/A"
                    end
                ),
                part_type: (
                    if ($reference | contains("constellation")) then
                        "constellation"
                    elif ($reference | contains("satellite")) then
                        "satellite"
                    elif ($reference | contains("Parts sociales")) then
                        "parts"
                    else
                        "other"
                    end
                ),
                ipfs_node: (
                    if ($reference | contains("SOCIETY:")) then
                        # Format: UPLANET:xxx:SOCIETY:email:type:IPFSNODEID
                        # Extract last field if exists (IPFSNODEID)
                        ($reference | split(":") | if length >= 6 then .[-1] else "N/A" end)
                    else
                        "N/A"
                    end
                ),
                comment: $reference
            }
        else
            {is_society_transfer: false}
        end
    ) |
    
    # Filter only society transfers
    map(select(.is_society_transfer == true)) |
    
    # Calculate totals and format result
    {
        g1pub: $init.g1pub,
        total_outgoing_g1: (map(.amount_g1) | add // 0 | . * 100 | round / 100),
        total_outgoing_zen: (map(.amount_zen) | add // 0 | . * 100 | round / 100),
        total_transfers: length,
        transfers: (
            map({
                date: .date,
                recipient: .recipient,
                amount_g1: (.amount_g1 | . * 100 | round / 100),
                amount_zen: (.amount_zen | . * 100 | round / 100),
                part_type: .part_type,
                ipfs_node: .ipfs_node,
                comment: (
                    if .part_type == "constellation" then
                        "Constellation - \(.comment)"
                    elif .part_type == "satellite" then
                        "Satellite - \(.comment)"
                    elif .part_type == "parts" then
                        "Parts sociales - \(.comment)"
                    else
                        .comment
                    end
                )
            }) | .[:50]
        ),
        timestamp: $init.timestamp
    }
else
    $init
end
')

# Output the result
echo "$RESULT"

log "SOCIETY analysis completed: $(echo "$RESULT" | jq -r '.total_transfers // 0') transfers found"
exit 0

