#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# G1impots.sh
# Calcule les provisions fiscales (TVA + IS) depuis l'historique des transactions
# Filtre : Transactions INCOMING vers UPLANETNAME.IMPOT
#          avec référence contenant "TAX_PROVISION" (provisions fiscales)
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

################################################################################
# Configuration
################################################################################

# Get IMPOT wallet public key from environment
IMPOT_G1PUB="${UPLANETNAME_IMPOT}"

if [[ -z "$IMPOT_G1PUB" ]]; then
    echo '{"error": "UPLANETNAME_IMPOT not configured in environment"}' >&2
    exit 1
fi

################################################################################
# Retrieve transaction history for IMPOT wallet
################################################################################

# Redirect G1history.sh stderr to /dev/null to avoid log pollution in JSON
HISTORY_JSON=$(${MY_PATH}/G1history.sh "$IMPOT_G1PUB" 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "{\"error\": \"Failed to retrieve history for $IMPOT_G1PUB\", \"details\": \"$HISTORY_JSON\"}" >&2
    exit 1
fi

# Validate JSON
if ! echo "$HISTORY_JSON" | jq empty 2>/dev/null; then
    echo '{"error": "Invalid JSON from G1history.sh"}' >&2
    exit 1
fi

################################################################################
# Filter transactions: INCOMING with "TAX_PROVISION" in comment
################################################################################

FILTERED_JSON=$(echo "$HISTORY_JSON" | jq '[
    .history.received[] |
    select(.comment | contains("TAX_PROVISION")) |
    {
        date: .time,
        amount_g1: .amount,
        comment: .comment,
        issuer: .issuer,
        is_tva: (.comment | contains("TVA") or contains("RENTAL")),
        is_is: (.comment | contains("COOPERATIVE") or contains("IS"))
    }
]')

################################################################################
# Calculate totals and categorize by tax type
################################################################################

# TVA provisions (from RENTAL transactions or explicit TVA comment)
TVA_TOTAL_G1=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_tva == true) | .amount_g1] | add // 0')

# IS provisions (from COOPERATIVE allocations)
IS_TOTAL_G1=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_is == true) | .amount_g1] | add // 0')

# Overall total
TOTAL_G1=$(echo "$FILTERED_JSON" | jq '[.[] | .amount_g1] | add // 0')

# Convert to ẐEN (1 Ğ1 - primo_tx) * 10 = ẐEN
# Note: Primo-transaction (1 Ğ1) is deducted from the wallet balance, not from individual transactions
# For transaction sums, we just multiply by 10
TVA_TOTAL_ZEN=$(echo "scale=2; $TVA_TOTAL_G1 * 10" | bc)
IS_TOTAL_ZEN=$(echo "scale=2; $IS_TOTAL_G1 * 10" | bc)
TOTAL_ZEN=$(echo "scale=2; $TOTAL_G1 * 10" | bc)

# Count transactions
TOTAL_TRANSACTIONS=$(echo "$FILTERED_JSON" | jq 'length')
TVA_TRANSACTIONS=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_tva == true)] | length')
IS_TRANSACTIONS=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_is == true)] | length')

################################################################################
# Prepare enhanced transaction list with ZEN conversion
################################################################################

TRANSACTIONS_WITH_ZEN=$(echo "$FILTERED_JSON" | jq --argjson tva_total "$TVA_TOTAL_ZEN" --argjson is_total "$IS_TOTAL_ZEN" '
    map({
        date: .date,
        amount_g1: .amount_g1,
        amount_zen: (.amount_g1 * 10 | tonumber | . * 100 | floor | . / 100),
        comment: .comment,
        issuer: .issuer,
        type: (if .is_tva then "TVA" elif .is_is then "IS" else "OTHER" end)
    })
')

################################################################################
# Output JSON
################################################################################

# Final JSON output with detailed breakdown
jq -n \
    --argjson total_g1 "$TOTAL_G1" \
    --argjson total_zen "$TOTAL_ZEN" \
    --argjson tva_g1 "$TVA_TOTAL_G1" \
    --argjson tva_zen "$TVA_TOTAL_ZEN" \
    --argjson is_g1 "$IS_TOTAL_G1" \
    --argjson is_zen "$IS_TOTAL_ZEN" \
    --argjson total_transactions "$TOTAL_TRANSACTIONS" \
    --argjson tva_transactions "$TVA_TRANSACTIONS" \
    --argjson is_transactions "$IS_TRANSACTIONS" \
    --arg g1pub "$IMPOT_G1PUB" \
    --argjson provisions "$TRANSACTIONS_WITH_ZEN" \
    '{
        wallet: $g1pub,
        total_provisions_g1: $total_g1,
        total_provisions_zen: $total_zen,
        total_transactions: $total_transactions,
        breakdown: {
            tva: {
                total_g1: $tva_g1,
                total_zen: $tva_zen,
                transactions: $tva_transactions,
                description: "TVA collectée sur locations RENTAL (20%)"
            },
            is: {
                total_g1: $is_g1,
                total_zen: $is_zen,
                transactions: $is_transactions,
                description: "Impôt sur les Sociétés provisionné (15% ou 25%)"
            }
        },
        provisions: $provisions
    }'

exit 0

