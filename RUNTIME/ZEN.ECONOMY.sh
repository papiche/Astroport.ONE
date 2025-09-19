################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.ECONOMY.sh
#~ Make payments between UPlanet / NODE / Captain & NOSTR / PLAYERS Cards
################################################################################
# Ce script gère l'économie de l'écosystème UPlanet :
# 1. Vérifie les soldes des différents acteurs (UPlanet, Node, Captain)
# 2. Gère le paiement hebdomadaire de la PAF (Participation Aux Frais)
# 3. Implémente le système de solidarité entre les nœuds
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################
start=`date +%s`

#######################################################################
# Weekly payment check - ensure payment is made only once per week
# Check if payment was already done this week using marker file
#######################################################################
PAYMENT_MARKER="$HOME/.zen/game/.weekly_payment.done"

# Get current week number (ISO week)
CURRENT_WEEK=$(date +%V)
CURRENT_YEAR=$(date +%Y)
WEEK_KEY="${CURRENT_YEAR}-W${CURRENT_WEEK}"

# Check if payment was already done this week
if [[ -f "$PAYMENT_MARKER" ]]; then
    LAST_PAYMENT_WEEK=$(cat "$PAYMENT_MARKER")
    if [[ "$LAST_PAYMENT_WEEK" == "$WEEK_KEY" ]]; then
        echo "ZEN ECONOMY: Weekly payment already completed this week ($WEEK_KEY)"
        echo "Skipping payment process..."
        exit 0
    fi
fi

echo "ZEN ECONOMY: Starting weekly payment process for week $WEEK_KEY"

#######################################################################
# Vérification des soldes des différents acteurs du système
# UPlanet : La "banque centrale" coopérative
# Node : Le serveur physique (PC Gamer ou RPi5)
# Captain : Le gestionnaire du Node
#######################################################################
echo "UPlanet G1PUB : ${UPLANETG1PUB}"
UCOIN=$(${MY_PATH}/../tools/G1check.sh ${UPLANETG1PUB} | tail -n 1)
UZEN=$(echo "($UCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$UZEN Ẑen"

# Vérification du Node (Astroport)
NODEG1PUB=$($MY_PATH/../tools/ipfs_to_g1.py ${IPFSNODEID})
echo "NODE G1PUB : ${NODEG1PUB}"
NODECOIN=$(${MY_PATH}/../tools/G1check.sh ${NODEG1PUB} | tail -n 1)
NODEZEN=$(echo "($NODECOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$NODEZEN Ẑen"

# Vérification du Captain (gestionnaire) - MULTIPASS (NOSTR)
echo "CAPTAIN G1PUB : ${CAPTAING1PUB}"
CAPTAINCOIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAING1PUB} | tail -n 1)
CAPTAINZEN=$(echo "($CAPTAINCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "Captain MULTIPASS balance: $CAPTAINZEN Ẑen"

# Vérification de la ZEN Card du Captain (PLAYERS)
if [[ -n "$CAPTAINEMAIL" ]]; then
    CAPTAIN_ZENCARD_PATH="$HOME/.zen/game/players/$CAPTAINEMAIL"
    if [[ -d "$CAPTAIN_ZENCARD_PATH" && -s "$CAPTAIN_ZENCARD_PATH/secret.dunikey" ]]; then
        CAPTAIN_ZENCARD_PUB=$(cat "$CAPTAIN_ZENCARD_PATH/secret.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
        if [[ -n "$CAPTAIN_ZENCARD_PUB" ]]; then
            CAPTAIN_ZENCARD_COIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAIN_ZENCARD_PUB} | tail -n 1)
            CAPTAIN_ZENCARD_ZEN=$(echo "($CAPTAIN_ZENCARD_COIN - 1) * 10" | bc | cut -d '.' -f 1)
            echo "Captain ZEN Card balance: $CAPTAIN_ZENCARD_ZEN Ẑen"
        else
            CAPTAIN_ZENCARD_ZEN=0
            echo "Captain ZEN Card not found or invalid"
        fi
    else
        CAPTAIN_ZENCARD_ZEN=0
        echo "Captain ZEN Card not found"
    fi
else
    CAPTAIN_ZENCARD_ZEN=0
    echo "Captain email not configured"
fi

#######################################################################
# Comptage des utilisateurs actifs
# NOSTR : Utilisateurs avec carte NOSTR (1 Ẑen/semaine)
# PLAYERS : Utilisateurs avec carte ZEN (4 Ẑen/semaine)
#######################################################################
NOSTRS=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))
PLAYERS=($(ls -t ~/.zen/game/players/ 2>/dev/null | grep "@" ))
echo "NODE hosts MULTIPASS : ${#NOSTRS[@]} / ZENCARD : ${#PLAYERS[@]}"

#######################################################################
# Configuration des paramètres économiques
# PAF : Participation Aux Frais (coûts de fonctionnement)
# NCARD : Coût hebdomadaire de la carte NOSTR
# ZCARD : Coût hebdomadaire de la carte ZEN
#######################################################################
[[ -z $PAF ]] && PAF=14  # PAF hebdomadaire par défaut
[[ -z $NCARD ]] && NCARD=1  # Coût hebdomadaire carte NOSTR
[[ -z $ZCARD ]] && ZCARD=4  # Coût hebdomadaire carte ZEN

# PAF hebdomadaire
WEEKLYPAF=$PAF
echo "ZEN ECONOMY : PAF=$WEEKLYPAF ZEN/week :: NCARD=$NCARD // ZCARD=$ZCARD"
WEEKLYG1=$(makecoord $(echo "$WEEKLYPAF / 10" | bc -l))

##################################################################################
# Système de solidarité : Paiement hebdomadaire de la PAF = House + Electricity + IP Connexion
# PRIORITÉ COMPTABLE CORRECTE :
# 1. CAPTAIN MULTIPASS (frais de fonctionnement)
# 2. UPLANET.CASH (trésorerie coopérative) - PAS ZEN Card (parts sociales)
# 
# NOTE: ZEN Card = Parts sociales (capital), ne doit PAS payer les frais d'exploitation
#######################################################################
if [[ $(echo "$WEEKLYG1 > 0" | bc -l) -eq 1 ]]; then
    if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 ]]; then
        if [[ $(echo "$CAPTAINZEN > $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            ## CAPTAIN MULTIPASS CAN PAY NODE : ECONOMY + (Correct: frais de fonctionnement)
            CAPTYOUSER=$($MY_PATH/../tools/clyuseryomail.sh ${CAPTAINEMAIL})
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:$CAPTYOUSER:WEEKLYPAF" 2>/dev/null
            echo "✅ CAPTAIN MULTIPASS paid weekly PAF: $WEEKLYPAF ZEN ($WEEKLYG1 G1) to NODE"
        else
            ## UPLANET.CASH PAYS NODE: ECONOMY - (Correct: trésorerie coopérative)
            # Use CASH wallet (treasury) instead of ZEN Card (shares) for operational expenses
            if [[ -f "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
                CASH_G1PUB=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
                CASH_COIN=$(${MY_PATH}/../tools/G1check.sh ${CASH_G1PUB} | tail -n 1)
                CASH_ZEN=$(echo "($CASH_COIN - 1) * 10" | bc | cut -d '.' -f 1)
                
                if [[ $(echo "$CASH_ZEN > $WEEKLYPAF" | bc -l) -eq 1 ]]; then
                    ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CASH.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:TREASURY:WEEKLYPAF" 2>/dev/null
                    echo "✅ UPLANET.CASH (Treasury) paid weekly PAF: $WEEKLYPAF ZEN ($WEEKLYG1 G1) to NODE"
                else
                    ## ECONOMIC FAILURE ?!
                    echo "⚠️  UPLANET MISSING CASH to pay weekly PAF: $WEEKLYPAF ZEN ($WEEKLYG1 G1) to NODE (Treasury insufficient)"
                fi
            fi
        fi
    else
        echo "NODE $NODECOIN G1 is NOT INITIALIZED !! UPlanet send 1 G1 to NODE"
        if [[ ! -s ~/.zen/game/uplanet.dunikey ]]; then
            ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
            chmod 600 ~/.zen/game/uplanet.dunikey
        fi
        ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.G1.dunikey" "1" "${NODEG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:$IPFSNODEID:NODEINIT" 2>/dev/null
    fi
fi

#######################################################################

#######################################################################
# APPORT AU CAPITAL - Machine contribution (one-time setup)
# Check if NODE needs capital contribution from CAPTAIN ZEN Card
# This should only happen once when the node is first set up
#######################################################################
check_machine_capital_contribution() {
    local contribution_marker="$HOME/.zen/game/.machine_capital_contributed"
    
    # Check if capital contribution was already made
    if [[ -f "$contribution_marker" ]]; then
        echo "ZEN ECONOMY: Machine capital contribution already recorded"
        return 0
    fi
    
    # Check if we have a captain with ZEN Card and sufficient balance
    if [[ -n "$CAPTAINEMAIL" && "$CAPTAIN_ZENCARD_ZEN" -gt 0 ]]; then
        echo "ZEN ECONOMY: Checking machine capital contribution..."
        
        # Get machine value from environment or default (example: 500€ = 500 Ẑen)
        MACHINE_VALUE_ZEN="${MACHINE_VALUE_ZEN:-500}"  # Default 500 Ẑen for a basic setup
        MACHINE_VALUE_G1=$(makecoord $(echo "$MACHINE_VALUE_ZEN / 10" | bc -l))
        
        if [[ $(echo "$CAPTAIN_ZENCARD_ZEN >= $MACHINE_VALUE_ZEN" | bc -l) -eq 1 ]]; then
            echo "ZEN ECONOMY: Processing machine capital contribution..."
            echo "  Machine value: $MACHINE_VALUE_ZEN Ẑen ($MACHINE_VALUE_G1 G1)"
            echo "  From: CAPTAIN ZEN Card (parts sociales)"
            echo "  To: NODE (apport au capital)"
            
            # Transfer from CAPTAIN ZEN Card to NODE as capital contribution
            CAPTYOUSER=$($MY_PATH/../tools/clyuseryomail.sh ${CAPTAINEMAIL})
            ${MY_PATH}/../tools/PAYforSURE.sh \
                "$HOME/.zen/game/players/$CAPTAINEMAIL/secret.dunikey" \
                "$MACHINE_VALUE_G1" \
                "${NODEG1PUB}" \
                "UPLANET:${UPLANETG1PUB:0:8}:$CAPTYOUSER:APPORT_CAPITAL_MACHINE:${MACHINE_VALUE_ZEN}ZEN" \
                2>/dev/null
            
            if [[ $? -eq 0 ]]; then
                echo "✅ Machine capital contribution completed: $MACHINE_VALUE_ZEN Ẑen"
                echo "$(date -u +%Y%m%d%H%M%S) MACHINE_CAPITAL_CONTRIBUTION $MACHINE_VALUE_ZEN ZEN $CAPTYOUSER" > "$contribution_marker"
                chmod 600 "$contribution_marker"
            else
                echo "❌ Machine capital contribution failed"
            fi
        else
            echo "ZEN ECONOMY: Insufficient ZEN Card balance for machine capital contribution."
            echo "  Required: $MACHINE_VALUE_ZEN Ẑen"
            echo "  Available: $CAPTAIN_ZENCARD_ZEN Ẑen"
        fi
    else
        echo "ZEN ECONOMY: No captain ZEN Card available for machine capital contribution"
    fi
}

# Execute capital contribution check (only runs once)
check_machine_capital_contribution

#######################################################################
# CAPTAIN REMUNERATION - 2x PAF weekly payment
# Transfer captain's remuneration (2x PAF) to dedicated captain wallet
# This is the captain's earning for managing the node
#######################################################################
process_captain_remuneration() {
    echo "ZEN ECONOMY: Processing captain remuneration (2x PAF)..."
    
    # Check if captain is configured
    if [[ -z "$CAPTAINEMAIL" ]]; then
        echo "ZEN ECONOMY: No captain configured, skipping remuneration"
        return 0
    fi
    
    # Create captain wallet if it doesn't exist
    if [[ ! -s ~/.zen/game/uplanet.captain.dunikey ]]; then
        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.captain.dunikey "${UPLANETNAME}.${CAPTAINEMAIL}" "${UPLANETNAME}.${CAPTAINEMAIL}"
        chmod 600 ~/.zen/game/uplanet.captain.dunikey
    fi
    
    # Get captain wallet public key
    CAPTAIN_DEDICATED_PUB=$(cat $HOME/.zen/game/uplanet.captain.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
    
    # Calculate captain's remuneration (2x PAF)
    CAPTAIN_SHARE_TARGET=$(echo "$PAF * 2" | bc -l)
    echo "ZEN ECONOMY: Captain remuneration target: $CAPTAIN_SHARE_TARGET Ẑen (2x PAF)"
    
    # Check if captain MULTIPASS has sufficient balance
    if [[ $(echo "$CAPTAINZEN > $CAPTAIN_SHARE_TARGET" | bc -l) -eq 1 ]]; then
        # Transfer from CAPTAIN MULTIPASS to dedicated captain wallet
        CAPTAIN_SHARE_G1=$(echo "scale=2; $CAPTAIN_SHARE_TARGET / 10" | bc -l)
        
        ${MY_PATH}/../tools/PAYforSURE.sh \
            "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" \
            "$CAPTAIN_SHARE_G1" \
            "${CAPTAIN_DEDICATED_PUB}" \
            "UPLANET:${UPLANETG1PUB:0:8}:CAPTAIN:2xPAF" \
            2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Captain remuneration completed: $CAPTAIN_SHARE_TARGET Ẑen ($CAPTAIN_SHARE_G1 G1)"
            echo "   From: CAPTAIN MULTIPASS (operational funds)"
            echo "   To: CAPTAIN dedicated wallet (personal earnings)"
        else
            echo "❌ Captain remuneration failed"
        fi
    else
        echo "ZEN ECONOMY: Insufficient CAPTAIN MULTIPASS balance for remuneration"
        echo "  Required: $CAPTAIN_SHARE_TARGET Ẑen"
        echo "  Available: $CAPTAINZEN Ẑen"
    fi
}

# Execute captain remuneration
process_captain_remuneration

#######################################################################
# PAF BURN & CONVERSION - 4-week operational cost management
# Burn 4-week accumulated PAF from NODE back to UPLANETNAME.G1 and request € conversion
# This creates a deflationary mechanism and enables real € payment for costs
#######################################################################
fourweeks_paf_burn_and_convert() {
    # Calculate current 4-week period (based on week number)
    local current_week=$(date +%V)
    local current_year=$(date +%Y)
    local period_number=$(( (current_week - 1) / 4 + 1 ))
    local period_key="${current_year}-P${period_number}"
    local burn_marker="$HOME/.zen/game/.fourweeks_paf_burn.$period_key"
    
    # Check if burn was already done for this 4-week period
    if [[ -f "$burn_marker" ]]; then
        echo "ZEN ECONOMY: 4-week PAF burn already completed for period $period_key"
        return 0
    fi
    
    # Only burn if NODE has sufficient balance and received PAF
    if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 && $(echo "$NODEZEN > 0" | bc -l) -eq 1 ]]; then
        # Calculate 4-week PAF (weekly PAF * 4)
        FOURWEEKS_PAF=$(echo "scale=2; $WEEKLYPAF * 4" | bc -l)
        FOURWEEKS_PAF_G1=$(makecoord $(echo "$FOURWEEKS_PAF / 10" | bc -l))
        
        # Check if NODE has enough for 4-week burn
        if [[ $(echo "$NODEZEN >= $FOURWEEKS_PAF" | bc -l) -eq 1 ]]; then
            echo "ZEN ECONOMY: Processing 4-week PAF burn..."
            echo "  Period: $period_key (4-week cycle)"
            echo "  4-week PAF: $FOURWEEKS_PAF Ẑen ($FOURWEEKS_PAF_G1 G1)"
            echo "  From: NODE (operational costs)"
            echo "  To: UPLANETNAME.G1 (burn & convert)"
            
            # Burn: NODE → UPLANETNAME.G1
            if [[ -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
                ${MY_PATH}/../tools/PAYforSURE.sh \
                    "$HOME/.zen/game/secret.NODE.dunikey" \
                    "$FOURWEEKS_PAF_G1" \
                    "${UPLANETG1PUB}" \
                    "UPLANET:${UPLANETG1PUB:0:8}:NODE:BURN_PAF_4WEEKS:$period_key:${FOURWEEKS_PAF}ZEN" \
                    2>/dev/null
                
                if [[ $? -eq 0 ]]; then
                    echo "✅ 4-week PAF burn completed: $FOURWEEKS_PAF Ẑen"
                    
                    # Request OpenCollective conversion (1Ẑ = 1€)
                    request_opencollective_conversion "$FOURWEEKS_PAF" "$period_key"
                    
                    # Mark burn as completed
                    echo "$(date -u +%Y%m%d%H%M%S) FOURWEEKS_PAF_BURN $FOURWEEKS_PAF ZEN NODE $period_key" > "$burn_marker"
                    chmod 600 "$burn_marker"
                else
                    echo "❌ 4-week PAF burn failed"
                fi
            else
                echo "ZEN ECONOMY: NODE dunikey not found for burn operation"
            fi
        else
            echo "ZEN ECONOMY: Insufficient NODE balance for 4-week PAF burn"
            echo "  Required: $FOURWEEKS_PAF Ẑen"
            echo "  Available: $NODEZEN Ẑen"
        fi
    else
        echo "ZEN ECONOMY: NODE not ready for PAF burn (balance: $NODEZEN Ẑen)"
    fi
}

# Function to request OpenCollective conversion using GraphQL API (recommended)
# Conforms to https://docs.opencollective.com/help/contributing/development/api
request_opencollective_conversion() {
    local zen_amount="$1"
    local period="${2:-$(date +%Y%m%d)}"
    local euro_amount=$(echo "scale=2; $zen_amount * 1" | bc -l)  # 1Ẑ = 1€
    local euro_cents=$(echo "$euro_amount * 100" | bc | cut -d. -f1)
    
    echo "ZEN ECONOMY: Requesting OpenCollective conversion..."
    echo "  Amount: $zen_amount Ẑen → $euro_amount €"
    echo "  Period: $period"
    
    # Check if OpenCollective Personal Token is configured (GraphQL API)
    if [[ -n "$OPENCOLLECTIVE_PERSONAL_TOKEN" ]]; then
        # Use GraphQL API (recommended by OpenCollective docs)
        # https://graphql-docs-v2.opencollective.com
        local graphql_query='{
            "query": "mutation CreateExpense($expense: ExpenseCreateInput!) { createExpense(expense: $expense) { id legacyId status amount { valueInCents currency } description reference tags } }",
            "variables": {
                "expense": {
                    "account": { "slug": "uplanet-zero" },
                    "type": "INVOICE",
                    "amount": { "valueInCents": '$euro_cents', "currency": "EUR" },
                    "description": "PAF Burn Conversion - '$IPFSNODEID' Node Operational Costs (4-week cycle)",
                    "reference": "BURN:PAF:'$period':'$zen_amount'ZEN",
                    "tags": ["paf-burn", "operational-costs", "zen-conversion", "4weeks"]
                }
            }
        }'
        
        local response=$(curl -s -X POST "https://api.opencollective.com/graphql/v2" \
            -H "Personal-Token: $OPENCOLLECTIVE_PERSONAL_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$graphql_query" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$response" ]]; then
            # Check for GraphQL errors
            local errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
            if [[ -n "$errors" && "$errors" != "null" ]]; then
                echo "⚠️  OpenCollective GraphQL API errors:"
                echo "$errors" | jq -r '.[] | "  - \(.message)"' 2>/dev/null || echo "$errors"
            else
                local expense_id=$(echo "$response" | jq -r '.data.createExpense.id // empty' 2>/dev/null)
                if [[ -n "$expense_id" ]]; then
                    echo "✅ OpenCollective expense created: $euro_amount €"
                    echo "   Expense ID: $expense_id"
                    echo "   Reference: BURN:PAF:$period:${zen_amount}ZEN"
                else
                    echo "⚠️  Unexpected response format:"
                    echo "$response" | head -c 200
                fi
            fi
        else
            echo "⚠️  OpenCollective GraphQL API request failed"
        fi
    elif [[ -n "$OPENCOLLECTIVE_API_KEY" ]]; then
        # Fallback to REST API (deprecated but still supported)
        echo "⚠️  Using deprecated REST API (configure OPENCOLLECTIVE_PERSONAL_TOKEN for GraphQL)"
        
        local response=$(curl -s -X POST "https://api.opencollective.com/v2/expenses" \
            -H "Authorization: Bearer $OPENCOLLECTIVE_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"collective\": \"uplanet-zero\",
                \"type\": \"INVOICE\",
                \"amount\": $euro_cents,
                \"currency\": \"EUR\",
                \"description\": \"PAF Burn Conversion - '$IPFSNODEID' Node Operational Costs (4-week cycle)\",
                \"reference\": \"BURN:PAF:$period:${zen_amount}ZEN\",
                \"tags\": [\"paf-burn\", \"operational-costs\", \"zen-conversion\", \"4weeks\"]
            }" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$response" ]]; then
            echo "✅ OpenCollective REST expense created: $euro_amount €"
            echo "   Response: $response" | head -c 100
        else
            echo "⚠️  OpenCollective REST API request failed"
        fi
    else
        echo "⚠️  No OpenCollective credentials configured"
        echo "   Configure OPENCOLLECTIVE_PERSONAL_TOKEN (GraphQL) or OPENCOLLECTIVE_API_KEY (REST)"
        echo "   Manual conversion needed: $zen_amount Ẑen → $euro_amount €"
        
        # Log for manual processing
        echo "$(date -u +%Y%m%d%H%M%S) MANUAL_CONVERSION_NEEDED $zen_amount ZEN $euro_amount EUR $period" >> "$HOME/.zen/game/opencollective_conversion.log"
    fi
}

# Execute 4-week PAF burn (runs once per 4-week period)
fourweeks_paf_burn_and_convert

#######################################################################

## AFTER PAF PAYMENT: CHECK SWARM SUBSCRIPTIONS
# ${MY_PATH}/ZEN.SWARM.payments.sh
## Ouverture d'un compte sur un autre noeud de l'essaim pour activer des services...
## Il suffit d'alimenter le MULTIPASS pour payer sur place.


#######################################################################
# PRIMAL WALLET CONTROL - Protect cooperative wallets from intrusions
# Ensure all cooperative wallets only receive funds from authorized sources
#######################################################################
echo "ZEN ECONOMY: Checking primal wallet control for cooperative wallets..."

# Define cooperative wallets to protect
declare -A COOPERATIVE_WALLETS=(
    ["UPLANETNAME"]="$HOME/.zen/game/uplanet.dunikey"
    ["UPLANETNAME.SOCIETY"]="$HOME/.zen/game/uplanet.SOCIETY.dunikey"
    ["UPLANETNAME.CASH"]="$HOME/.zen/game/uplanet.CASH.dunikey"
    ["UPLANETNAME.RND"]="$HOME/.zen/game/uplanet.RnD.dunikey"
    ["UPLANETNAME.ASSETS"]="$HOME/.zen/game/uplanet.ASSETS.dunikey"
    ["UPLANETNAME.IMPOT"]="$HOME/.zen/game/uplanet.IMPOT.dunikey"
    ["UPLANETNAME.CAPTAIN"]="$HOME/.zen/game/uplanet.captain.dunikey"
    ["UPLANETNAME.INTRUSION"]="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
)

# Master primal source for cooperative wallets (UPLANETNAME_G1 is the unique primal source)
COOPERATIVE_MASTER_PRIMAL="$UPLANETNAME_G1"
COOPERATIVE_ADMIN_EMAIL="${CAPTAINEMAIL:-support@qo-op.com}"

# Check each cooperative wallet for primal compliance
for wallet_name in "${!COOPERATIVE_WALLETS[@]}"; do
    wallet_dunikey="${COOPERATIVE_WALLETS[$wallet_name]}"
    
    if [[ -f "$wallet_dunikey" ]]; then
        # Extract public key from dunikey file
        wallet_pubkey=$(cat "$wallet_dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
        
        if [[ -n "$wallet_pubkey" ]]; then
            echo "ZEN ECONOMY: Checking primal control for $wallet_name (${wallet_pubkey:0:8}...)"
            
            # Run primal wallet control for this cooperative wallet
            ${MY_PATH}/../tools/primal_wallet_control.sh \
                "$wallet_dunikey" \
                "$wallet_pubkey" \
                "$COOPERATIVE_MASTER_PRIMAL" \
                "$COOPERATIVE_ADMIN_EMAIL"
                
            if [[ $? -eq 0 ]]; then
                echo "ZEN ECONOMY: ✅ Primal control OK for $wallet_name"
            else
                echo "ZEN ECONOMY: ⚠️  Primal control issues detected for $wallet_name"
            fi
        else
            echo "ZEN ECONOMY: ⚠️  Could not extract public key from $wallet_name"
        fi
    else
        echo "ZEN ECONOMY: ⚠️  Wallet file not found: $wallet_name ($wallet_dunikey)"
    fi
done

echo "ZEN ECONOMY: Primal wallet control completed for all cooperative wallets"

#######################################################################
# Cooperative allocation check - trigger 3x1/3 allocation if conditions are met
# This will be executed after PAF payment to ensure proper economic flow
#######################################################################
echo "ZEN ECONOMY: Checking cooperative allocation conditions..."
${MY_PATH}/ZEN.COOPERATIVE.3x1-3.sh

#######################################################################
# Mark weekly payment as completed
# Create marker file with current week to prevent duplicate payments
#######################################################################
echo "$WEEK_KEY" > "$PAYMENT_MARKER"
echo "ZEN ECONOMY: Weekly payment completed and marked for week $WEEK_KEY"

exit 0
