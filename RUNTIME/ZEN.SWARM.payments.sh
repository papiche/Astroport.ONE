#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# ZEN.SWARM.payments.sh
# Gestion des paiements automatiques des abonnements inter-nodes
# Appelé par ZEN.ECONOMY.sh après le paiement de la PAF locale
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

#######################################################################
# Vérification des abonnements et paiements
#######################################################################

SUBSCRIPTIONS_FILE="$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions.json"

# Vérifier si nous avons des abonnements
if [[ ! -f "$SUBSCRIPTIONS_FILE" ]]; then
    echo "No swarm subscriptions found"
    exit 0
fi

# Vérifier si le fichier contient des abonnements actifs
ACTIVE_SUBS=$(jq '[.subscriptions[] | select(.status == "active")] | length' "$SUBSCRIPTIONS_FILE" 2>/dev/null)
if [[ -z "$ACTIVE_SUBS" || "$ACTIVE_SUBS" == "0" ]]; then
    echo "No active swarm subscriptions"
    exit 0
fi

echo "SWARM SUBSCRIPTIONS PAYMENT CHECK"
echo "================================="
echo "Active subscriptions: $ACTIVE_SUBS"

#######################################################################
# Calcul du paiement quotidien pour chaque abonnement
#######################################################################

# Date actuelle pour vérifier les échéances
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CURRENT_TIMESTAMP=$(date +%s)

# Calculer le paiement quotidien (coût mensuel / 28 jours)
jq -c '.subscriptions[] | select(.status == "active")' "$SUBSCRIPTIONS_FILE" | while read -r subscription; do
    TARGET_NODE=$(echo "$subscription" | jq -r '.target_node')
    SUBSCRIPTION_EMAIL=$(echo "$subscription" | jq -r '.subscription_email')
    TOTAL_COST=$(echo "$subscription" | jq -r '.total_cost')
    PAYMENT_SOURCE=$(echo "$subscription" | jq -r '.payment_source')
    NEXT_PAYMENT=$(echo "$subscription" | jq -r '.next_payment')
    API_URL=$(echo "$subscription" | jq -r '.api_url')
    
    # Calculer le paiement quotidien
    DAILY_COST=$(echo "scale=2; $TOTAL_COST / 28" | bc)
    DAILY_G1=$(echo "scale=4; $DAILY_COST / 10" | bc)
    
    echo "Processing subscription to: $TARGET_NODE"
    echo "Email: $SUBSCRIPTION_EMAIL"
    echo "Daily cost: $DAILY_COST Ẑ ($DAILY_G1 G1)"
    echo "Payment source: $PAYMENT_SOURCE"
    
    #######################################################################
    # Effectuer le paiement quotidien
    #######################################################################
    
    # Obtenir la clé G1 du node cible
    TARGET_JSON="$HOME/.zen/tmp/swarm/$TARGET_NODE/12345.json"
    if [[ -f "$TARGET_JSON" ]]; then
        TARGET_NODEG1PUB=$(jq -r '.NODEG1PUB' "$TARGET_JSON")
        TARGET_CAPTAIN=$(jq -r '.captain' "$TARGET_JSON")
        
        if [[ "$TARGET_NODEG1PUB" != "null" && "$TARGET_NODEG1PUB" != "" ]]; then
            echo "Target Node G1PUB: $TARGET_NODEG1PUB"
            
            # Déterminer la source de paiement
            if [[ "$PAYMENT_SOURCE" == "Node (Y Level)" && -f ~/.zen/game/secret.dunikey ]]; then
                # Paiement depuis le portefeuille du Node
                PAYMENT_KEY="$HOME/.zen/game/secret.dunikey"
                echo "Paying from Node wallet (Y Level)"
            elif [[ -f ~/.zen/game/players/.current/secret.dunikey ]]; then
                # Paiement depuis le portefeuille du Capitaine
                PAYMENT_KEY="$HOME/.zen/game/players/.current/secret.dunikey"
                echo "Paying from Captain wallet"
            else
                echo "ERROR: No valid payment key found"
                continue
            fi
            
            # Effectuer le paiement
            PAYMENT_COMMENT="SWARM:${SUBSCRIPTION_EMAIL}:${TARGET_NODE:0:8}"
            echo "Payment comment: $PAYMENT_COMMENT"
            
            if [[ $(echo "$DAILY_G1 > 0.01" | bc) -eq 1 ]]; then
                echo "Executing payment: $DAILY_G1 G1 to $TARGET_NODEG1PUB"
                
                PAYMENT_RESULT=$(${MY_PATH}/../tools/PAYforSURE.sh "$PAYMENT_KEY" "$DAILY_G1" "$TARGET_NODEG1PUB" "$PAYMENT_COMMENT" 2>&1)
                PAYMENT_EXIT_CODE=$?
                
                if [[ $PAYMENT_EXIT_CODE -eq 0 ]]; then
                    echo "✅ Payment successful: $DAILY_G1 G1 to $TARGET_NODE"
                    
                    # Mettre à jour la date de dernier paiement
                    TEMP_FILE=$(mktemp)
                    jq --arg target "$TARGET_NODE" --arg timestamp "$CURRENT_DATE" '
                        .subscriptions = [
                            .subscriptions[] | 
                            if .target_node == $target then 
                                .last_payment = $timestamp 
                            else . end
                        ]' "$SUBSCRIPTIONS_FILE" > "$TEMP_FILE"
                    mv "$TEMP_FILE" "$SUBSCRIPTIONS_FILE"
                    
                else
                    echo "❌ Payment failed to $TARGET_NODE: $PAYMENT_RESULT"
                fi
            else
                echo "⚠️  Daily payment too small, skipping: $DAILY_G1 G1"
            fi
        else
            echo "❌ Invalid Target Node G1PUB for $TARGET_NODE"
        fi
    else
        echo "❌ Target node JSON not found: $TARGET_JSON"
    fi
    
    echo "---"
done

#######################################################################
# Vérifier et mettre à jour les échéances d'abonnement
#######################################################################

echo "Checking subscription renewals..."

# Mettre à jour les échéances expirées
TEMP_FILE=$(mktemp)
jq --arg current_time "$CURRENT_DATE" '
    .subscriptions = [
        .subscriptions[] |
        if .status == "active" and (.next_payment | . < $current_time) then
            .next_payment = ($current_time | fromdateiso8601 + (28 * 24 * 3600) | todateiso8601) |
            .renewed_at = $current_time
        else . end
    ]' "$SUBSCRIPTIONS_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$SUBSCRIPTIONS_FILE"

echo "SWARM payments check completed"
exit 0 