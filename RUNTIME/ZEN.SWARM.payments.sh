#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# ZEN.SWARM.payments.sh
# Gestion des paiements automatiques des abonnements inter-nodes
# Appelé par ZEN.ECONOMY.sh après le paiement de la PAF locale
# Paiements hebdomadaires (tous les 7 jours) au lieu de quotidiens
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

echo "SWARM SUBSCRIPTIONS WEEKLY PAYMENT CHECK"
echo "========================================"
echo "Active subscriptions: $ACTIVE_SUBS"

#######################################################################
# Calcul du paiement hebdomadaire pour chaque abonnement
#######################################################################

# Date actuelle pour vérifier les échéances
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CURRENT_TIMESTAMP=$(date +%s)

# Traiter chaque abonnement actif
jq -c '.subscriptions[] | select(.status == "active")' "$SUBSCRIPTIONS_FILE" | while read -r subscription; do
    TARGET_NODE=$(echo "$subscription" | jq -r '.target_node')
    SUBSCRIPTION_EMAIL=$(echo "$subscription" | jq -r '.subscription_email')
    TOTAL_COST=$(echo "$subscription" | jq -r '.total_cost')
    PAYMENT_SOURCE=$(echo "$subscription" | jq -r '.payment_source')
    NEXT_PAYMENT=$(echo "$subscription" | jq -r '.next_payment')
    LAST_PAYMENT=$(echo "$subscription" | jq -r '.last_payment // empty')
    API_URL=$(echo "$subscription" | jq -r '.api_url')
    
    echo "Processing subscription to: $TARGET_NODE"
    echo "Email: $SUBSCRIPTION_EMAIL"
    echo "Weekly cost: $TOTAL_COST Ẑ"
    echo "Payment source: $PAYMENT_SOURCE"
    echo "Next payment: $NEXT_PAYMENT"
    echo "Last payment: $LAST_PAYMENT"
    
    # Vérifier si le paiement hebdomadaire est dû
    if [[ -n "$NEXT_PAYMENT" ]]; then
        NEXT_TIMESTAMP=$(date -d "$NEXT_PAYMENT" +%s 2>/dev/null)
        if [[ $? -eq 0 && $CURRENT_TIMESTAMP -ge $NEXT_TIMESTAMP ]]; then
            echo "✅ Weekly payment due for $TARGET_NODE"
        else
            echo "⏳ Payment not due yet for $TARGET_NODE"
            continue
        fi
    else
        echo "⚠️  No next_payment date set, skipping $TARGET_NODE"
        continue
    fi
    
    # Calculer le paiement hebdomadaire en Ğ1
    WEEKLY_G1=$(echo "scale=2; $TOTAL_COST / 10" | bc)
    
    echo "Weekly payment: $TOTAL_COST Ẑ ($WEEKLY_G1 G1)"
    
    #######################################################################
    # Effectuer le paiement hebdomadaire
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
            PAYMENT_COMMENT="SWARM:${SUBSCRIPTION_EMAIL}:${TARGET_NODE:0:8}:WEEKLY"
            echo "Payment comment: $PAYMENT_COMMENT"
            
            if [[ $(echo "$WEEKLY_G1 > 0.01" | bc) -eq 1 ]]; then
                echo "Executing weekly payment: $WEEKLY_G1 G1 to $TARGET_NODEG1PUB"
                
                PAYMENT_RESULT=$(${MY_PATH}/../tools/PAYforSURE.sh "$PAYMENT_KEY" "$WEEKLY_G1" "$TARGET_NODEG1PUB" "$PAYMENT_COMMENT" 2>&1)
                PAYMENT_EXIT_CODE=$?
                
                if [[ $PAYMENT_EXIT_CODE -eq 0 ]]; then
                    echo "✅ Weekly payment successful: $WEEKLY_G1 G1 to $TARGET_NODE"
                    
                    # Calculer la prochaine échéance (7 jours)
                    NEXT_PAYMENT_DATE=$(date -d "$CURRENT_DATE + 7 days" -u +"%Y-%m-%dT%H:%M:%SZ")
                    
                    # Mettre à jour les dates de paiement
                    TEMP_FILE=$(mktemp)
                    jq --arg target "$TARGET_NODE" \
                       --arg current_date "$CURRENT_DATE" \
                       --arg next_date "$NEXT_PAYMENT_DATE" '
                        .subscriptions = [
                            .subscriptions[] | 
                            if .target_node == $target then 
                                .last_payment = $current_date |
                                .next_payment = $next_date
                            else . end
                        ]' "$SUBSCRIPTIONS_FILE" > "$TEMP_FILE"
                    mv "$TEMP_FILE" "$SUBSCRIPTIONS_FILE"
                    
                    echo "📅 Next payment scheduled: $NEXT_PAYMENT_DATE"
                    
                else
                    echo "❌ Weekly payment failed to $TARGET_NODE: $PAYMENT_RESULT"
                fi
            else
                echo "⚠️  Weekly payment too small, skipping: $WEEKLY_G1 G1"
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

# Mettre à jour les échéances expirées (renouvellement mensuel)
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

echo "SWARM weekly payments check completed"
exit 0 