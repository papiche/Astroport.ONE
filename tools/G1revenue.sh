#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# G1revenue.sh
# Calcule le Chiffre d'Affaires (CA) total depuis l'historique des transactions
# Filtre : Transactions INCOMING depuis UPLANETNAME_G1 vers UPLANETG1PUB
#          avec référence contenant "RENTAL" (ventes de services)
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

################################################################################
# Configuration
################################################################################

# Get UPLANETG1PUB (hub de distribution des services) from environment
UPLANET_G1PUB="${UPLANETG1PUB}"
UPLANET_G1_SOURCE="${UPLANETNAME_G1}"

# Optional year filter (default: all years)
FILTER_YEAR="${1:-all}"

if [[ -z "$UPLANET_G1PUB" ]]; then
    echo '{"error": "UPLANETG1PUB not configured in environment"}' >&2
    exit 1
fi

if [[ -z "$UPLANET_G1_SOURCE" ]]; then
    echo '{"error": "UPLANETNAME_G1 not configured in environment"}' >&2
    exit 1
fi

################################################################################
# Retrieve transaction history for UPLANETG1PUB wallet
################################################################################

# Redirect G1history.sh stderr to /dev/null to avoid log pollution in JSON
HISTORY_JSON=$(${MY_PATH}/G1history.sh "$UPLANET_G1PUB" 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "{\"error\": \"Failed to retrieve history for $UPLANET_G1PUB\", \"details\": \"$HISTORY_JSON\"}" >&2
    exit 1
fi

# Validate JSON
if ! echo "$HISTORY_JSON" | jq empty 2>/dev/null; then
    echo '{"error": "Invalid JSON response from G1history.sh"}' >&2
    exit 1
fi

################################################################################
# Filter and calculate revenue (RENTAL transactions from UPLANETNAME_G1)
# These are incoming transactions representing service sales
################################################################################

RESULT=$(echo "$HISTORY_JSON" | jq -r --arg source_g1 "$UPLANET_G1_SOURCE" --arg filter_year "$FILTER_YEAR" '
.pubkey as $pubkey |
([.history[] |
    # Extract amount and issuer
    (."Amounts Ğ1" | tonumber) as $amount_g1 |
    (."Issuers/Recipients" | split(":")[0]) as $issuer |
    ."Reference" as $reference |
    ."Date" as $date |
    ($date | split("-")[0]) as $year |
    
    # Check if this is an incoming RENTAL transaction from UPLANETNAME_G1
    if ($amount_g1 > 0 and $issuer == $source_g1 and ($reference | contains("RENTAL"))) then
        {
            is_revenue_transaction: true,
            amount_g1: $amount_g1,
            amount_zen: (if $amount_g1 > 1 then (($amount_g1 - 1) * 10) else 0 end),
            date: $date,
            year: $year,
            customer_email: (
                if ($reference | contains("RENTAL:")) then
                    ($reference | split("RENTAL:")[1] | split(":")[0])
                else
                    "N/A"
                end
            ),
            transaction_type: (
                if ($reference | contains("RENTAL")) then
                    "RENTAL"
                else
                    "OTHER"
                end
            ),
            comment: $reference
        }
    else
        {is_revenue_transaction: false}
    end
] | map(select(.is_revenue_transaction == true))) as $init_transactions |

# Filter by year if specified
($init_transactions | 
    if $filter_year == "all" then
        .
    else
        map(select(.year == $filter_year))
    end
) as $filtered_transactions |

# Calculate yearly summary
($init_transactions | group_by(.year) | map({
    year: .[0].year,
    total_revenue_g1: (map(.amount_g1) | add // 0 | . * 100 | round / 100),
    total_revenue_zen: (map(.amount_zen) | add // 0 | . * 100 | round / 100),
    total_transactions: length
}) | sort_by(.year) | reverse) as $yearly_summary |

{
    g1pub: $pubkey,
    filter_year: $filter_year,
    total_revenue_g1: ($filtered_transactions | map(.amount_g1) | add // 0 | . * 100 | round / 100),
    total_revenue_zen: ($filtered_transactions | map(.amount_zen) | add // 0 | . * 100 | round / 100),
    total_transactions: ($filtered_transactions | length),
    yearly_summary: $yearly_summary,
    transactions: (
        $filtered_transactions | map({
            date: .date,
            year: .year,
            customer_email: .customer_email,
            amount_g1: (.amount_g1 | . * 100 | round / 100),
            amount_zen: (.amount_zen | . * 100 | round / 100),
            transaction_type: .transaction_type,
            comment: (
                if .transaction_type == "RENTAL" then
                    "Service RENTAL - \(.comment)"
                else
                    .comment
                end
            )
        }) | .[:100]  # Limit to last 100 transactions for display
    ),
    timestamp: (now | strftime("%Y-%m-%dT%H:%M:%S"))
}
' 2>&1)

# Check if jq command succeeded
if [[ $? -ne 0 ]]; then
    echo "{\"error\": \"jq processing failed\", \"details\": \"$RESULT\"}" >&2
    exit 1
fi

# Validate output JSON
if ! echo "$RESULT" | jq empty 2>/dev/null; then
    echo '{"error": "Invalid JSON output from jq processing"}' >&2
    exit 1
fi

# Output final JSON result
echo "$RESULT"
exit 0

