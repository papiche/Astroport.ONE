#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# G1zencard_history.sh
# Récupère l'historique des parts sociales reçues par une ZEN Card
# Filtre les transactions entrantes depuis UPLANETNAME_SOCIETY
# Format des références : "UPLANET:xxxxxxxx:SOCIETY:email@example.com:type:IPFSNODEID"
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Get parameters
ZENCARD_EMAIL="$1"
FILTER_YEARS=3  # Always retrieve 3 years of history

if [[ -z "$ZENCARD_EMAIL" ]]; then
    log "ERROR: ZEN Card email required"
    echo '{"error": "ZEN Card email required", "usage": "G1zencard_history.sh <email>"}'
    exit 1
fi

# Get ZEN Card G1 public key
ZENCARD_G1PUB=""
if [[ -f "$HOME/.zen/game/players/${ZENCARD_EMAIL}/secret.dunikey" ]]; then
    ZENCARD_G1PUB=$(cat "$HOME/.zen/game/players/${ZENCARD_EMAIL}/secret.dunikey" | grep "pub:" | cut -d ' ' -f 2)
elif [[ -f "$HOME/.zen/game/players/${ZENCARD_EMAIL}/.g1pub" ]]; then
    ZENCARD_G1PUB=$(cat "$HOME/.zen/game/players/${ZENCARD_EMAIL}/.g1pub")
else
    log "ERROR: ZEN Card not found for email: $ZENCARD_EMAIL"
    echo "{\"error\": \"ZEN Card not found\", \"email\": \"$ZENCARD_EMAIL\", \"total_received_g1\": 0, \"total_received_zen\": 0, \"total_transfers\": 0, \"transfers\": []}"
    exit 1
fi

# Get SOCIETY wallet public key from environment
SOCIETY_G1PUB="${UPLANETNAME_SOCIETY:-}"
if [[ -z "$SOCIETY_G1PUB" ]]; then
    log "ERROR: UPLANETNAME_SOCIETY not set in environment"
    echo '{"error": "SOCIETY wallet not configured", "total_received_g1": 0, "total_received_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

log "Starting ZEN Card history analysis"
log "ZEN Card: $ZENCARD_EMAIL ($ZENCARD_G1PUB)"
log "SOCIETY wallet: $SOCIETY_G1PUB"
log "Filter: Last $FILTER_YEARS year(s)"

# Call G1history.sh to get ZEN Card transaction history
HISTORY_JSON=$(${MY_PATH}/G1history.sh "$ZENCARD_G1PUB" 2>/dev/null)

if [[ -z "$HISTORY_JSON" ]]; then
    log "ERROR: Failed to retrieve transaction history for ZEN Card"
    echo '{"error": "Failed to retrieve history", "total_received_g1": 0, "total_received_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Validate JSON
if ! echo "$HISTORY_JSON" | jq empty 2>/dev/null; then
    log "ERROR: Invalid JSON from G1history.sh"
    echo '{"error": "Invalid history JSON", "total_received_g1": 0, "total_received_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Calculate cutoff date for filtering (current year - FILTER_YEARS)
CURRENT_YEAR=$(date +%Y)
CUTOFF_YEAR=$((CURRENT_YEAR - FILTER_YEARS + 1))

# Process history JSON with jq to filter and calculate
# Always analyze 3 years of history
# Satellite transfers older than 1 year are invalidated from valid balance
RESULT=$(echo "$HISTORY_JSON" | jq -r --arg society_g1 "$SOCIETY_G1PUB" --arg cutoff_year "$CUTOFF_YEAR" --arg zencard_email "$ZENCARD_EMAIL" --arg current_year "$CURRENT_YEAR" '
{
    zencard_email: $zencard_email,
    zencard_g1pub: .pubkey,
    filter_years: 3,
    cutoff_year: ($cutoff_year | tonumber),
    current_year: ($current_year | tonumber),
    total_received_g1: 0,
    total_received_zen: 0,
    valid_balance_g1: 0,
    valid_balance_zen: 0,
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
        # Parse date and year
        (."Date" // "") as $date |
        ($date | split("-")[0] | tonumber) as $year |
        
        # Check if this is an incoming transfer from SOCIETY with SOCIETY reference
        # and within the 3 year period
        if ($amount_g1 > 0 and $issuer == $society_g1 and ($reference | contains("SOCIETY")) and $year >= ($cutoff_year | tonumber)) then
            {
                is_society_transfer: true,
                amount_g1: $amount_g1,
                # Standard rate: 1Ẑ = 0.1Ğ1 (or 10Ẑ = 1Ğ1)
                amount_zen: (if $amount_g1 > 1 then (($amount_g1) * 10) else 0 end),
                date: $date,
                year: $year,
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
                # Determine if this transfer is still valid (counts toward balance)
                # Constellation: valid for 3 years
                # Satellite: valid only for current year
                is_valid: (
                    if ($reference | contains("constellation")) then
                        true
                    elif ($reference | contains("satellite")) then
                        ($year == ($current_year | tonumber))
                    else
                        true
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
    
    # Filter only society transfers within the period
    map(select(.is_society_transfer == true)) |
    
    # Calculate totals and format result
    {
        zencard_email: $init.zencard_email,
        zencard_g1pub: $init.zencard_g1pub,
        filter_years: $init.filter_years,
        filter_period: "Dernières 3 années (\($init.cutoff_year)-\($init.current_year))",
        total_received_g1: (map(.amount_g1) | add // 0 | . * 100 | round / 100),
        total_received_zen: (map(.amount_zen) | add // 0 | . * 100 | round / 100),
        valid_balance_g1: (map(select(.is_valid == true) | .amount_g1) | add // 0 | . * 100 | round / 100),
        valid_balance_zen: (map(select(.is_valid == true) | .amount_zen) | add // 0 | . * 100 | round / 100),
        total_transfers: length,
        valid_transfers: (map(select(.is_valid == true)) | length),
        transfers: (
            map({
                date: .date,
                year: .year,
                amount_g1: (.amount_g1 | . * 100 | round / 100),
                amount_zen: (.amount_zen | . * 100 | round / 100),
                part_type: .part_type,
                is_valid: .is_valid,
                ipfs_node: .ipfs_node,
                comment: (
                    if .part_type == "constellation" then
                        "Parts Constellation - \(.comment)"
                    elif .part_type == "satellite" then
                        if .is_valid then
                            "Parts Satellite (valide) - \(.comment)"
                        else
                            "Parts Satellite (⚠️ expirée) - \(.comment)"
                        end
                    elif .part_type == "parts" then
                        "Parts sociales - \(.comment)"
                    else
                        .comment
                    end
                )
            }) | sort_by(.date) | reverse | .[:50]
        ),
        timestamp: $init.timestamp
    }
else
    $init
end
')

# Output the result
echo "$RESULT"

log "ZEN Card history completed: $(echo "$RESULT" | jq -r '.total_transfers // 0') transfers found"
exit 0

