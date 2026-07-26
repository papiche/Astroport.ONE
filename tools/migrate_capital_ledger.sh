#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# migrate_capital_ledger.sh
#
# Migration ONE-SHOT (à exécuter manuellement, PAS depuis un cron) de l'ancien
# enregistrement global de capital machine (~/.zen/game/.env :
# MACHINE_VALUE/CAPITAL_DATE/DEPRECIATION_WEEKS) vers le nouveau grand livre
# multi-contributeurs ~/.zen/game/capital_ledger.json (tools/capital_ledger.sh).
#
# Sans cette migration, un capital déjà enregistré avant cette mise à jour ne
# serait plus jamais amorti par ZEN.ECONOMY.sh (qui ne lit plus le .env global).
#
# Idempotent : si capital_ledger.json contient déjà une entrée "machine" pour
# CAPTAINEMAIL, ne fait rien (affiche l'état existant).
#
# Usage: ./migrate_capital_ledger.sh
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"
. "${MY_PATH}/capital_ledger.sh"

echo "🔍 Migration du capital machine vers le grand livre multi-contributeurs..."

capital_ledger_init

if [[ -z "$CAPTAINEMAIL" ]]; then
    echo "❌ CAPTAINEMAIL non défini dans l'environnement (my.sh). Abandon." >&2
    exit 1
fi

# Déjà migré ?
EXISTING_ID=$(jq -r --arg e "$CAPTAINEMAIL" '
    [.assets[] | select(.email==$e and .asset_type=="machine")] | .[0].id // empty
' "$CAPITAL_LEDGER_FILE")

if [[ -n "$EXISTING_ID" ]]; then
    echo "ℹ️  Une entrée machine existe déjà pour ${CAPTAINEMAIL} dans le ledger (id=${EXISTING_ID})."
    jq -r --arg id "$EXISTING_ID" '.assets[] | select(.id==$id)' "$CAPITAL_LEDGER_FILE"
    echo "✅ Rien à migrer."
    exit 0
fi

ENV_FILE="$HOME/.zen/game/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ℹ️  Aucun fichier $ENV_FILE — rien à migrer."
    exit 0
fi

MACHINE_VALUE=$(grep "^MACHINE_VALUE=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2)
CAPITAL_DATE=$(grep "^CAPITAL_DATE=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2)
DEPRECIATION_WEEKS=$(grep "^DEPRECIATION_WEEKS=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2)
[[ -z "$DEPRECIATION_WEEKS" ]] && DEPRECIATION_WEEKS=156

if [[ -z "$MACHINE_VALUE" || "$MACHINE_VALUE" == "0" ]]; then
    echo "ℹ️  Aucun MACHINE_VALUE dans $ENV_FILE — rien à migrer."
    exit 0
fi

if [[ -z "$CAPITAL_DATE" ]]; then
    echo "⚠️  MACHINE_VALUE présent mais CAPITAL_DATE manquant — migration impossible, corrigez $ENV_FILE manuellement." >&2
    exit 1
fi

echo "📊 Trouvé dans $ENV_FILE :"
echo "   • MACHINE_VALUE=${MACHINE_VALUE} Ẑen"
echo "   • CAPITAL_DATE=${CAPITAL_DATE}"
echo "   • DEPRECIATION_WEEKS=${DEPRECIATION_WEEKS}"

CAP_TIMESTAMP=$(date -d "${CAPITAL_DATE:0:8}" +%s 2>/dev/null || echo "0")
NOW_TIMESTAMP=$(date +%s)
WEEKS_ELAPSED=$(( (NOW_TIMESTAMP - CAP_TIMESTAMP) / 604800 ))
[[ $WEEKS_ELAPSED -lt 0 ]] && WEEKS_ELAPSED=0

WEEKLY_DEPRECIATION=$(echo "scale=4; $MACHINE_VALUE / $DEPRECIATION_WEEKS" | bc -l 2>/dev/null || echo 0)
COMPUTED_AMORTIZED=$(echo "scale=2; $WEEKLY_DEPRECIATION * $WEEKS_ELAPSED" | bc -l 2>/dev/null || echo 0)
if (( $(echo "$COMPUTED_AMORTIZED > $MACHINE_VALUE" | bc -l 2>/dev/null || echo 0) )); then
    COMPUTED_AMORTIZED="$MACHINE_VALUE"
fi

# Réconciliation avec le solde on-chain réel de l'AMORTISSEMENT si disponible
RECONCILED_AMORTIZED="$COMPUTED_AMORTIZED"
if [[ -s "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" ]]; then
    AMORT_G1PUB=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep "pub:" | cut -d ' ' -f 2)
    AMORT_COIN=$("${MY_PATH}/G1check.sh" "$AMORT_G1PUB" 2>/dev/null | tail -n 1)
    if [[ "$AMORT_COIN" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        AMORT_ZEN_ONCHAIN=$(echo "scale=2; ($AMORT_COIN - 1) * 10" | bc 2>/dev/null || echo "0")
        if (( $(echo "$AMORT_ZEN_ONCHAIN >= 0" | bc -l 2>/dev/null || echo 0) )); then
            echo "📡 Solde on-chain AMORTISSEMENT : ${AMORT_ZEN_ONCHAIN} Ẑen (vs calcul théorique: ${COMPUTED_AMORTIZED} Ẑen)"
            RECONCILED_AMORTIZED="$AMORT_ZEN_ONCHAIN"
        fi
    fi
else
    echo "ℹ️  Portefeuille UPLANETNAME_AMORTISSEMENT pas encore initialisé (sera créé au prochain ZEN.ECONOMY.sh)."
fi

if (( $(echo "$RECONCILED_AMORTIZED > $MACHINE_VALUE" | bc -l 2>/dev/null || echo 0) )); then
    RECONCILED_AMORTIZED="$MACHINE_VALUE"
fi

STATUS="active"
if (( $(echo "$RECONCILED_AMORTIZED >= $MACHINE_VALUE" | bc -l 2>/dev/null || echo 0) )); then
    STATUS="fully_amortized"
fi

CAPITAL_DATE_ISO=$(date -d "${CAPITAL_DATE:0:8}" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
NEW_ID=$(echo -n "${CAPTAINEMAIL}:machine:Migration:${CAP_TIMESTAMP}" | sha256sum | cut -c1-12)

exec 203>"$CAPITAL_LEDGER_LOCK"
flock -x 203
jq --arg id "$NEW_ID" --arg email "$CAPTAINEMAIL" --arg date "$CAPITAL_DATE_ISO" \
   --argjson value "$MACHINE_VALUE" --argjson weeks "$DEPRECIATION_WEEKS" \
   --argjson amortized "$RECONCILED_AMORTIZED" --arg status "$STATUS" --argjson created "$CAP_TIMESTAMP" '
    .assets += [{
        id: $id, email: $email, asset_type: "machine", label: "Migration (capital pré-existant)",
        value_zen: $value, created_at: $created, date: $date,
        depreciable: true, depreciation_weeks: $weeks,
        amortized_zen: $amortized, last_depreciated_week: "", status: $status
    }]
' "$CAPITAL_LEDGER_FILE" > "${CAPITAL_LEDGER_FILE}.tmp" && mv "${CAPITAL_LEDGER_FILE}.tmp" "$CAPITAL_LEDGER_FILE"
flock -u 203

echo "✅ Entrée migrée dans $CAPITAL_LEDGER_FILE (id=${NEW_ID}):"
echo "   • Valeur brute: ${MACHINE_VALUE} Ẑen"
echo "   • Amorti (réconcilié): ${RECONCILED_AMORTIZED} Ẑen"
echo "   • Statut: ${STATUS}"
echo "ℹ️  Le fichier $ENV_FILE n'est pas modifié (juste plus lu par ZEN.ECONOMY.sh)."
