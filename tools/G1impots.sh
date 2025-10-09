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
    # Return empty data structure instead of error
    echo '{
        "wallet": "N/A",
        "total_provisions_g1": 0,
        "total_provisions_zen": 0,
        "total_transactions": 0,
        "breakdown": {
            "tva": {
                "total_g1": 0,
                "total_zen": 0,
                "transactions": 0,
                "description": "TVA collectée sur locations RENTAL (20%)"
            },
            "is": {
                "total_g1": 0,
                "total_zen": 0,
                "transactions": 0,
                "description": "Impôt sur les Sociétés provisionné (15% ou 25%)"
            }
        },
        "provisions": []
    }'
    exit 0
fi

################################################################################
# Retrieve transaction history for IMPOT wallet
################################################################################

# Redirect G1history.sh stderr to /dev/null to avoid log pollution in JSON
HISTORY_JSON=$(${MY_PATH}/G1history.sh "$IMPOT_G1PUB" 2>/dev/null)

if [[ $? -ne 0 ]] || [[ -z "$HISTORY_JSON" ]]; then
    # Return empty data structure if history retrieval fails
    echo '{
        "wallet": "'"$IMPOT_G1PUB"'",
        "total_provisions_g1": 0,
        "total_provisions_zen": 0,
        "total_transactions": 0,
        "breakdown": {
            "tva": {
                "total_g1": 0,
                "total_zen": 0,
                "transactions": 0,
                "description": "TVA collectée sur locations RENTAL (20%)"
            },
            "is": {
                "total_g1": 0,
                "total_zen": 0,
                "transactions": 0,
                "description": "Impôt sur les Sociétés provisionné (15% ou 25%)"
            }
        },
        "provisions": []
    }'
    exit 0
fi

# Validate JSON
if ! echo "$HISTORY_JSON" | jq empty 2>/dev/null; then
    # Return empty data structure if JSON is invalid
    echo '{
        "wallet": "'"$IMPOT_G1PUB"'",
        "total_provisions_g1": 0,
        "total_provisions_zen": 0,
        "total_transactions": 0,
        "breakdown": {
            "tva": {
                "total_g1": 0,
                "total_zen": 0,
                "transactions": 0,
                "description": "TVA collectée sur locations RENTAL (20%)"
            },
            "is": {
                "total_g1": 0,
                "total_zen": 0,
                "transactions": 0,
                "description": "Impôt sur les Sociétés provisionné (15% ou 25%)"
            }
        },
        "provisions": []
    }'
    exit 0
fi

################################################################################
# Filter transactions: INCOMING tax provisions
# - TVA: UPLANET:ORIGIN:*:TVA (from MULTIPASS initial payments)
# - IS: UPLANET:*:COOPERATIVE:TAX_PROVISION (from surplus redistribution)
################################################################################

FILTERED_JSON=$(echo "$HISTORY_JSON" | jq '[
    .history[] |
    # Extract relevant fields (matching G1history.sh structure)
    (."Amounts Ğ1" | tonumber) as $amount_g1 |
    (."Issuers/Recipients" | split(":")[0]) as $issuer |
    ."Reference" as $reference |
    ."Date" as $date |
    
    # Only process positive amounts (incoming) with TAX markers
    # Accept either ":TVA" suffix OR "TAX_PROVISION" in reference
    if ($amount_g1 > 0 and (($reference | endswith(":TVA")) or ($reference | contains("TAX_PROVISION")))) then
        # Determine tax type (mutually exclusive)
        (if ($reference | endswith(":TVA")) then "TVA" 
         elif ($reference | contains("COOPERATIVE") and contains("TAX_PROVISION")) then "IS"
         else "UNKNOWN" end) as $tax_type |
        {
            date: $date,
            amount_g1: $amount_g1,
            comment: $reference,
            issuer: $issuer,
            is_tva: ($tax_type == "TVA"),
            is_is: ($tax_type == "IS")
        }
    else
        empty
    end
]')

################################################################################
# Calculate totals and categorize by tax type
################################################################################

# TVA provisions (from RENTAL transactions or explicit TVA comment)
TVA_TOTAL_G1=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_tva == true) | .amount_g1] | add // 0 | . * 100 | round | . / 100')

# IS provisions (from COOPERATIVE allocations)
IS_TOTAL_G1=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_is == true) | .amount_g1] | add // 0 | . * 100 | round | . / 100')

# Overall total
TOTAL_G1=$(echo "$FILTERED_JSON" | jq '[.[] | .amount_g1] | add // 0 | . * 100 | round | . / 100')

# Convert to ẐEN: 1 Ğ1 = 10 Ẑ (no primo deduction for individual transactions)
# Note: Primo-transaction (1 Ğ1) is only deducted from wallet balance, not from transaction history sums
# Let jq handle rounding to avoid bc floating-point precision issues
TVA_TOTAL_ZEN=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_tva == true) | .amount_g1 * 10] | add // 0 | . * 100 | round | . / 100')
IS_TOTAL_ZEN=$(echo "$FILTERED_JSON" | jq '[.[] | select(.is_is == true) | .amount_g1 * 10] | add // 0 | . * 100 | round | . / 100')
TOTAL_ZEN=$(echo "$FILTERED_JSON" | jq '[.[] | .amount_g1 * 10] | add // 0 | . * 100 | round | . / 100')

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
        amount_g1: (.amount_g1 * 100 | round | . / 100),
        amount_zen: (.amount_g1 * 10 | . * 100 | round | . / 100),
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

