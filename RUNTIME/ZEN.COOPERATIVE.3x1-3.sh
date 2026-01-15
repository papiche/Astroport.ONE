#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.COOPERATIVE.3x1-3.sh
#~ Cooperative allocation system for UPlanet surplus (3x1/3 rule)
################################################################################
# Ce script gère la répartition coopérative du surplus selon le modèle légal :
# 1. 1/3 Trésorerie (Réserves) - Liquidité et stabilité (CASH)
# 2. 1/3 R&D (G1FabLab) - Recherche et développement (RND)
# 3. 1/3 Ressources Durables (Actifs Réels) - Biens communs (ASSETS)
#
# MODÈLE ÉCONOMIQUE (flux correct) :
# - Redevances collectées (loyers MULTIPASS) → CAPTAIN_DEDICATED (portefeuille d'exploitation)
# - CAPTAIN_DEDICATED → Allocation 3x1/3 (après provision fiscale IS)
# - CASH paie les coûts opérationnels via ZEN.ECONOMY.sh :
#   * 1x PAF → NODE (loyer matériel Armateur)
#   * 2x PAF → CAPTAIN MULTIPASS (rétribution travail personnelle)
#
# Séparation claire :
# - CAPTAIN MULTIPASS = revenus personnels du capitaine (salaire)
# - CAPTAIN_DEDICATED = recettes d'exploitation (loyers collectés)
#
# Déclenchement : Allocation hebdomadaire basée sur le birthday du capitaine
#
# Conformité fiscale : Provision automatique IS (15%/25%)
# via le portefeuille UPLANETNAME_IMPOT
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
# Load cooperative config from DID NOSTR (shared across swarm)
. "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null && coop_load_env_vars 2>/dev/null || true
################################################################################
start=`date +%s`

 ## DESACTIVATE ZEN ECONOMY
if [[ $PAF == 0 ]]; then
    echo "ZEN COOPERATIVE: PAF = 0"
    echo "Skipping allocation process..."
    exit 0
fi
#######################################################################
# Cooperative allocation check - ensure allocation is made only once per week
# Check if allocation was already done this week using captain's birthday
#######################################################################
ALLOCATION_MARKER="$HOME/.zen/game/.cooperative_allocation.done"

# Get current date and captain's birthday
TODATE=$(date +%Y-%m-%d)
CAPTAIN_BIRTHDAY_FILE="$HOME/.zen/game/nostr/$CAPTAINEMAIL/TODATE"

# Check if captain's birthday file exists
if [[ ! -f "$CAPTAIN_BIRTHDAY_FILE" ]]; then
    echo "ZEN COOPERATIVE: Captain's birthday file not found: $CAPTAIN_BIRTHDAY_FILE"
    echo "Skipping allocation process..."
    exit 0
fi

CAPTAIN_BIRTHDAY=$(cat "$CAPTAIN_BIRTHDAY_FILE")
echo "Captain's birthday: $CAPTAIN_BIRTHDAY"
echo "Current date: $TODATE"

# Check if allocation was already done this week (since captain's birthday)
if [[ -f "$ALLOCATION_MARKER" ]]; then
    LAST_ALLOCATION_DATE=$(cat "$ALLOCATION_MARKER")
    # Calculate days since last allocation
    DAYS_SINCE_LAST=$(echo "($(date -d "$TODATE" +%s) - $(date -d "$LAST_ALLOCATION_DATE" +%s)) / 86400" | bc)

    if [[ $DAYS_SINCE_LAST -lt 7 ]]; then
        echo "ZEN COOPERATIVE: Weekly allocation already completed this week (last: $LAST_ALLOCATION_DATE, days ago: $DAYS_SINCE_LAST)"
        echo "Skipping allocation process..."
        exit 0
    fi
fi

echo "ZEN COOPERATIVE: Starting weekly allocation process (captain's birthday: $CAPTAIN_BIRTHDAY)"


#######################################################################
# Vérification du solde du compte CAPTAIN_DEDICATED (collecte des loyers)
# C'est le portefeuille d'exploitation qui collecte les redevances d'usage
# et sert de source pour la répartition coopérative 3x1/3
#######################################################################

# Créer le portefeuille CAPTAIN_DEDICATED s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.captain.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.captain.dunikey "${UPLANETNAME}.${CAPTAINEMAIL}" "${UPLANETNAME}.${CAPTAINEMAIL}"
    chmod 600 ~/.zen/game/uplanet.captain.dunikey
fi

CAPTAIN_DEDICATED_G1PUB=$(cat $HOME/.zen/game/uplanet.captain.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
echo "CAPTAIN_DEDICATED G1PUB : ${CAPTAIN_DEDICATED_G1PUB}"
CAPTAIN_DEDICATED_COIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAIN_DEDICATED_G1PUB} | tail -n 1)
CAPTAIN_DEDICATED_ZEN=$(echo "scale=1; ($CAPTAIN_DEDICATED_COIN - 1) * 10" | bc)
echo "Captain DEDICATED balance: $CAPTAIN_DEDICATED_ZEN Ẑen (recettes d'exploitation pour répartition)"

# Configuration de la PAF hebdomadaire
[[ -z $PAF ]] && PAF=14  # PAF hebdomadaire par défaut

# Vérification du solde minimum pour allocation
if [[ $(echo "$CAPTAIN_DEDICATED_ZEN <= 0" | bc -l) -eq 1 ]]; then
    echo "ZEN COOPERATIVE: Captain DEDICATED balance is zero or negative ($CAPTAIN_DEDICATED_ZEN Ẑen)"
    echo "Skipping allocation process..."
    exit 0
fi

# Note: La rémunération du capitaine (2x PAF) est payée par CASH vers son MULTIPASS personnel
# Ce script gère la répartition coopérative du surplus depuis CAPTAIN_DEDICATED
# CAPTAIN_DEDICATED collecte les loyers (redevances) depuis NOSTRCARD.refresh.sh

#######################################################################
# Vérification du solde pour allocation coopérative
#######################################################################
REMAINING_BALANCE=$CAPTAIN_DEDICATED_ZEN
echo "Balance available for cooperative allocation: $REMAINING_BALANCE Ẑen (from CAPTAIN_DEDICATED)"

# Si le solde est insuffisant pour l'allocation coopérative, on arrête
if [[ $(echo "$REMAINING_BALANCE <= 0" | bc -l) -eq 1 ]]; then
    echo "ZEN COOPERATIVE: No balance available for cooperative allocation"
    echo "Captain keeps all available balance on MULTIPASS"
    exit 0
fi

#######################################################################
# Vérification du solde disponible sur le portefeuille coopératif
#######################################################################
echo "UPlanet Cooperative G1PUB : ${UPLANETG1PUB}"
UPLANETCOIN=$(${MY_PATH}/../tools/G1check.sh ${UPLANETG1PUB} | tail -n 1)
UPLANETZEN=$(echo "scale=1; ($UPLANETCOIN - 1) * 10" | bc)
echo "Cooperative balance: $UPLANETZEN Ẑen"

#######################################################################
# Configuration des paramètres fiscaux
#
# NOTE FISCALE IMPORTANTE :
# =========================
# TVA (20%) : Collectée sur le CHIFFRE D'AFFAIRES BRUT
#             Provisionnée ailleurs (non gérée par ce script)
#             Fait générateur : Encaissement des locations ZENCOIN
#             Portefeuille : UPLANETNAME_IMPOT
#
# IS (15%/25%) : Calculé sur le BÉNÉFICE NET (après charges)
#                Provisionné ICI sur le surplus après Node + Capitaine
#                Base taxable : Surplus coopératif (revenus - PAF - rémunérations)
#                Portefeuille : UPLANETNAME_IMPOT
#######################################################################
[[ -z $TVA_RATE ]] && TVA_RATE=20  # Taux de TVA (20%) - RÉFÉRENCE UNIQUEMENT (provisionnée ailleurs)

# Taux d'Impôt sur les Sociétés selon la réglementation française
# Source: https://www.impots.gouv.fr/international-professionnel/impot-sur-les-societes
[[ -z $IS_THRESHOLD ]] && IS_THRESHOLD=42500  # Plafond en euros (42 500 €)
[[ -z $IS_RATE_REDUCED ]] && IS_RATE_REDUCED=15  # Taux réduit (15% jusqu'à 42 500 €)
[[ -z $IS_RATE_NORMAL ]] && IS_RATE_NORMAL=25   # Taux normal (25% au-delà de 42 500 €)

echo "ZEN COOPERATIVE: Tax rates - VAT: $TVA_RATE% (reference only, provisioned elsewhere)"
echo "ZEN COOPERATIVE: Corporate Tax (IS) - Reduced: $IS_RATE_REDUCED% (up to $IS_THRESHOLD €) | Normal: $IS_RATE_NORMAL% (above $IS_THRESHOLD €)"

#######################################################################
# Provision fiscale automatique (IS sur le surplus avec plafond)
#######################################################################
echo "🔄 Processing automatic tax provision..."

# Créer le portefeuille IMPOTS s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.IMPOT.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.IMPOT.dunikey "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
    chmod 600 ~/.zen/game/uplanet.IMPOT.dunikey
fi

IMPOTSG1PUB=$(cat $HOME/.zen/game/uplanet.IMPOT.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)

# Conversion du surplus restant en euros (1 Ẑen ≈ 1 €)
SURPLUS_EUR=$(echo "scale=2; $REMAINING_BALANCE * 1" | bc -l)

echo "Processing tax provision on remaining surplus: $REMAINING_BALANCE Ẑen ($SURPLUS_EUR €)"

# Calcul de l'IS selon les tranches fiscales françaises
if [[ $(echo "$SURPLUS_EUR <= $IS_THRESHOLD" | bc -l) -eq 1 ]]; then
    # Taux réduit 15% pour les bénéfices jusqu'à 42 500 €
    TAX_PROVISION=$(echo "scale=2; $REMAINING_BALANCE * $IS_RATE_REDUCED / 100" | bc -l)
    TAX_RATE_USED=$IS_RATE_REDUCED
    echo "Using reduced tax rate: $IS_RATE_REDUCED% (surplus: $SURPLUS_EUR € <= $IS_THRESHOLD €)"
else
    # Taux normal 25% pour les bénéfices au-delà de 42 500 €
    TAX_PROVISION=$(echo "scale=2; $REMAINING_BALANCE * $IS_RATE_NORMAL / 100" | bc -l)
    TAX_RATE_USED=$IS_RATE_NORMAL
    echo "Using normal tax rate: $IS_RATE_NORMAL% (surplus: $SURPLUS_EUR € > $IS_THRESHOLD €)"
fi

TAX_PROVISION_G1=$(echo "scale=2; $TAX_PROVISION / 10" | bc -l)

echo "Tax provision (${TAX_RATE_USED}% of surplus): $TAX_PROVISION Ẑen ($TAX_PROVISION_G1 G1)"

# TX Comment: UP:NetworkID:TAX:Week:Amount:Rate (Corporate tax provision)
# Automatic IS provision (15% up to €42,500 / 25% above) on cooperative surplus
# Source: CAPTAIN_DEDICATED (business wallet collecting rentals)
tax_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$TAX_PROVISION_G1" "${IMPOTSG1PUB}" "UP:${UPLANETG1PUB:0:8}:TAX:${TODATE}:${TAX_PROVISION}Z:IS_${TAX_RATE_USED}pct" 2>/dev/null)
TAX_SUCCESS=$?

if [[ $TAX_SUCCESS -eq 0 ]]; then
    echo "✅ Tax provision completed: $TAX_PROVISION Ẑen ($TAX_PROVISION_G1 G1)"
else
    echo "❌ Tax provision failed: $TAX_PROVISION Ẑen"
fi

# Calcul du surplus net après provision fiscale
NET_SURPLUS=$(echo "scale=2; $REMAINING_BALANCE - $TAX_PROVISION" | bc -l)
echo "Net surplus after tax provision: $NET_SURPLUS Ẑen"

# Si le surplus net est insuffisant, on arrête
if [[ $(echo "$NET_SURPLUS <= 0" | bc -l) -eq 1 ]]; then
    echo "ZEN COOPERATIVE: No net surplus for cooperative allocation after tax provision"
    exit 0
fi

#######################################################################
# Configuration des paramètres d'allocation (sur le surplus net)
#######################################################################
[[ -z $TREASURY_RATIO ]] && TREASURY_RATIO=33.33  # 1/3 pour la trésorerie
[[ -z $RND_RATIO ]] && RND_RATIO=33.33  # 1/3 pour la R&D
[[ -z $ASSETS_RATIO ]] && ASSETS_RATIO=33.34  # 1/3 pour les actifs réels

echo "ZEN COOPERATIVE: Allocation ratios - Treasury: $TREASURY_RATIO% | R&D: $RND_RATIO% | Assets: $ASSETS_RATIO%"

#######################################################################
# Calcul des montants d'allocation (sur le surplus net)
#######################################################################
TREASURY_AMOUNT=$(echo "scale=2; $NET_SURPLUS * $TREASURY_RATIO / 100" | bc -l)
RND_AMOUNT=$(echo "scale=2; $NET_SURPLUS * $RND_RATIO / 100" | bc -l)
ASSETS_AMOUNT=$(echo "scale=2; $NET_SURPLUS * $ASSETS_RATIO / 100" | bc -l)

echo "ZEN COOPERATIVE: Allocation amounts - Treasury: $TREASURY_AMOUNT Ẑen | R&D: $RND_AMOUNT Ẑen | Assets: $ASSETS_AMOUNT Ẑen"

#######################################################################
# 1/3 Trésorerie (Réserves) - Liquidité et stabilité
#######################################################################
echo "🔄 Processing Treasury allocation (1/3): $TREASURY_AMOUNT Ẑen"

# Créer le portefeuille trésorerie s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.CASH.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.CASH.dunikey "${UPLANETNAME}.TREASURY" "${UPLANETNAME}.TREASURY"
    chmod 600 ~/.zen/game/uplanet.CASH.dunikey
fi

TREASURYG1PUB=$(cat $HOME/.zen/game/uplanet.CASH.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
# Calcul en G1
TREASURY_G1=$(echo "scale=2; $TREASURY_AMOUNT / 10" | bc -l)

# TX Comment: UP:NetworkID:COOP:Date:Amount:Allocation (1/3 Treasury reserves)
# Cooperative liquidity and financial stability fund
# Source: CAPTAIN_DEDICATED (business wallet collecting rentals)
treasury_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$TREASURY_G1" "${TREASURYG1PUB}" "UP:${UPLANETG1PUB:0:8}:COOP:${TODATE}:${TREASURY_AMOUNT}Z:1/3_CASH" 2>/dev/null)
TREASURY_SUCCESS=$?

if [[ $TREASURY_SUCCESS -eq 0 ]]; then
    echo "✅ Treasury allocation completed: $TREASURY_AMOUNT Ẑen ($TREASURY_G1 G1)"
else
    echo "❌ Treasury allocation failed: $TREASURY_AMOUNT Ẑen"
fi

#######################################################################
# 1/3 R&D (G1FabLab) - Recherche et développement
#######################################################################
echo "🔄 Processing R&D allocation (1/3): $RND_AMOUNT Ẑen"

# Créer le portefeuille R&D s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.RnD.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.RnD.dunikey "${UPLANETNAME}.RND" "${UPLANETNAME}.RND"
    chmod 600 ~/.zen/game/uplanet.RnD.dunikey
fi

RNDG1PUB=$(cat $HOME/.zen/game/uplanet.RnD.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
# Calcul en G1
RND_G1=$(echo "scale=2; $RND_AMOUNT / 10" | bc -l)

# TX Comment: UP:NetworkID:COOP:Date:Amount:Allocation (1/3 R&D G1FabLab)
# Research & Development fund for technological innovation
# Source: CAPTAIN_DEDICATED (business wallet collecting rentals)
rnd_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$RND_G1" "${RNDG1PUB}" "UP:${UPLANETG1PUB:0:8}:COOP:${TODATE}:${RND_AMOUNT}Z:1/3_RnD" 2>/dev/null)
RND_SUCCESS=$?

if [[ $RND_SUCCESS -eq 0 ]]; then
    echo "✅ R&D allocation completed: $RND_AMOUNT Ẑen ($RND_G1 G1)"
else
    echo "❌ R&D allocation failed: $RND_AMOUNT Ẑen"
fi

#######################################################################
# 1/3 Forêts Jardins (Actifs Réels) - Investissement régénératif
#######################################################################
echo "🔄 Processing Assets allocation (1/3): $ASSETS_AMOUNT Ẑen"

# Créer le portefeuille actifs s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.ASSETS.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.ASSETS.dunikey "${UPLANETNAME}.ASSETS" "${UPLANETNAME}.ASSETS"
    chmod 600 ~/.zen/game/uplanet.ASSETS.dunikey
fi

ASSETSG1PUB=$(cat $HOME/.zen/game/uplanet.ASSETS.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
# Calcul en G1
ASSETS_G1=$(echo "scale=2; $ASSETS_AMOUNT / 10" | bc -l)

# TX Comment: UP:NetworkID:COOP:Date:Amount:Allocation (1/3 Real Assets)
# Regenerative investment fund (Forest Gardens, tangible assets)
# Source: CAPTAIN_DEDICATED (business wallet collecting rentals)
assets_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$ASSETS_G1" "${ASSETSG1PUB}" "UP:${UPLANETG1PUB:0:8}:COOP:${TODATE}:${ASSETS_AMOUNT}Z:1/3_ASSETS" 2>/dev/null)
ASSETS_SUCCESS=$?

if [[ $ASSETS_SUCCESS -eq 0 ]]; then
    echo "✅ Assets allocation completed: $ASSETS_AMOUNT Ẑen ($ASSETS_G1 G1)"
else
    echo "❌ Assets allocation failed: $ASSETS_AMOUNT Ẑen"
fi

#######################################################################
# Rapport d'allocation avec conformité fiscale
#######################################################################
echo "============================================ COOPERATIVE ALLOCATION SUMMARY"
echo "📊 CAPTAIN_DEDICATED balance (recettes loyers): $CAPTAIN_DEDICATED_ZEN Ẑen"
echo "💡 Note: CASH pays operational costs (1x PAF NODE + 2x PAF CAPTAIN MULTIPASS) via ZEN.ECONOMY.sh"
echo "📊 Balance for cooperative allocation: $REMAINING_BALANCE Ẑen (from CAPTAIN_DEDICATED)"
echo "💰 Tax provision (${TAX_RATE_USED}%): $TAX_PROVISION Ẑen"
echo "📈 Net surplus allocated: $NET_SURPLUS Ẑen"
echo "🏦 Treasury (1/3): $TREASURY_AMOUNT Ẑen"
echo "🔬 R&D (1/3): $RND_AMOUNT Ẑen"
echo "🌱 Assets (1/3): $ASSETS_AMOUNT Ẑen"
echo "============================================ COOPERATIVE ALLOCATION DONE."

#######################################################################
# Envoi du rapport par email via mailjet.sh (HTML format)
#######################################################################
echo "🔄 Sending allocation report via email..."

# Template path
TEMPLATE_FILE="${MY_PATH}/../templates/NOSTR/cooperative_allocation_report.html"
REPORT_FILE="$HOME/.zen/tmp/cooperative_allocation_report_${TODATE}.html"

# Check if template exists
if [[ ! -s "$TEMPLATE_FILE" ]]; then
    echo "⚠️  Template file not found: $TEMPLATE_FILE"
    echo "Skipping HTML report generation..."
else
    # Calculate values for template substitution
    INITIAL_BALANCE=$CAPTAIN_DEDICATED_ZEN
    REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    UPLANET_ID="${UPLANETG1PUB:0:8}"

    # Query wallet balances and convert to ẐEN: Ẑ = (Ğ1 - 1) * 10
    # Precision: 0.1Ẑ (since Ğ1 has 2 decimal places)
    echo "🔄 Querying wallet balances for report..."

    # Captain Dedicated wallet balance (already queried at start)
    CAPTAIN_DEDICATED_BALANCE_ZEN=$CAPTAIN_DEDICATED_ZEN

    # Treasury wallet balance
    TREASURY_COIN=$(${MY_PATH}/../tools/G1check.sh ${TREASURYG1PUB} | tail -n 1)
    TREASURY_BALANCE_ZEN=$(echo "scale=1; ($TREASURY_COIN - 1) * 10" | bc)

    # R&D wallet balance
    RND_COIN=$(${MY_PATH}/../tools/G1check.sh ${RNDG1PUB} | tail -n 1)
    RND_BALANCE_ZEN=$(echo "scale=1; ($RND_COIN - 1) * 10" | bc)

    # Assets wallet balance
    ASSETS_COIN=$(${MY_PATH}/../tools/G1check.sh ${ASSETSG1PUB} | tail -n 1)
    ASSETS_BALANCE_ZEN=$(echo "scale=1; ($ASSETS_COIN - 1) * 10" | bc)

    # Tax Provision wallet balance
    IMPOTS_COIN=$(${MY_PATH}/../tools/G1check.sh ${IMPOTSG1PUB} | tail -n 1)
    IMPOTS_BALANCE_ZEN=$(echo "scale=1; ($IMPOTS_COIN - 1) * 10" | bc)

    echo "Wallet balances retrieved: Treasury=${TREASURY_BALANCE_ZEN}Ẑ, R&D=${RND_BALANCE_ZEN}Ẑ, Assets=${ASSETS_BALANCE_ZEN}Ẑ, Impots=${IMPOTS_BALANCE_ZEN}Ẑ"

    # Generate HTML report from template using sed substitutions
    # Full public keys are passed for easy copy
    cat "$TEMPLATE_FILE" | sed \
        -e "s~_DATE_~${REPORT_DATE}~g" \
        -e "s~_TODATE_~${TODATE}~g" \
        -e "s~_CAPTAIN_BIRTHDAY_~${CAPTAIN_BIRTHDAY}~g" \
        -e "s~_UPLANET_ID_~${UPLANET_ID}~g" \
        -e "s~_INITIAL_BALANCE_~${INITIAL_BALANCE}~g" \
        -e "s~_REMAINING_BALANCE_~${REMAINING_BALANCE}~g" \
        -e "s~_TAX_RATE_USED_~${TAX_RATE_USED}~g" \
        -e "s~_TAX_PROVISION_~${TAX_PROVISION}~g" \
        -e "s~_TAX_PROVISION_G1_~${TAX_PROVISION_G1}~g" \
        -e "s~_NET_SURPLUS_~${NET_SURPLUS}~g" \
        -e "s~_TREASURY_AMOUNT_~${TREASURY_AMOUNT}~g" \
        -e "s~_TREASURY_G1_~${TREASURY_G1}~g" \
        -e "s~_RND_AMOUNT_~${RND_AMOUNT}~g" \
        -e "s~_RND_G1_~${RND_G1}~g" \
        -e "s~_ASSETS_AMOUNT_~${ASSETS_AMOUNT}~g" \
        -e "s~_ASSETS_G1_~${ASSETS_G1}~g" \
        -e "s~_CAPTAIN_DEDICATED_PUB_~${CAPTAIN_DEDICATED_G1PUB}~g" \
        -e "s~_CAPTAIN_DEDICATED_BALANCE_~${CAPTAIN_DEDICATED_BALANCE_ZEN}~g" \
        -e "s~_TREASURY_PUB_~${TREASURYG1PUB}~g" \
        -e "s~_TREASURY_BALANCE_~${TREASURY_BALANCE_ZEN}~g" \
        -e "s~_RND_PUB_~${RNDG1PUB}~g" \
        -e "s~_RND_BALANCE_~${RND_BALANCE_ZEN}~g" \
        -e "s~_ASSETS_PUB_~${ASSETSG1PUB}~g" \
        -e "s~_ASSETS_BALANCE_~${ASSETS_BALANCE_ZEN}~g" \
        -e "s~_IMPOTS_PUB_~${IMPOTSG1PUB}~g" \
        -e "s~_IMPOTS_BALANCE_~${IMPOTS_BALANCE_ZEN}~g" \
        > "$REPORT_FILE"

    # Envoyer le rapport par email au Capitaine
    if [[ -n "$CAPTAINEMAIL" && -s "$REPORT_FILE" ]]; then
        echo "📧 Sending HTML report to Captain: $CAPTAINEMAIL"
        ${MY_PATH}/../tools/mailjet.sh "$CAPTAINEMAIL" "$REPORT_FILE" "Cooperative Allocation Report - $TODATE"

        if [[ $? -eq 0 ]]; then
            echo "✅ HTML report sent successfully to Captain"
        else
            echo "❌ Failed to send HTML report to Captain"
        fi
    else
        echo "⚠️  Captain email not configured or report file empty"
    fi
fi

#######################################################################
# Bankruptcy Detection and Alert System
# Check if any allocations failed and send alerts to all users
#######################################################################
BANKRUPTCY_DETECTED=0
FAILED_ALLOCATIONS=""

# Check for failed allocations
if [[ $TAX_SUCCESS -ne 0 ]]; then
    BANKRUPTCY_DETECTED=1
    FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>Tax Provision: ${TAX_PROVISION} Ẑen (${TAX_PROVISION_G1} G1)</li>"
fi

if [[ $TREASURY_SUCCESS -ne 0 ]]; then
    BANKRUPTCY_DETECTED=1
    FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>Treasury: ${TREASURY_AMOUNT} Ẑen (${TREASURY_G1} G1)</li>"
fi

if [[ $RND_SUCCESS -ne 0 ]]; then
    BANKRUPTCY_DETECTED=1
    FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>R&D: ${RND_AMOUNT} Ẑen (${RND_G1} G1)</li>"
fi

if [[ $ASSETS_SUCCESS -ne 0 ]]; then
    BANKRUPTCY_DETECTED=1
    FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>Assets: ${ASSETS_AMOUNT} Ẑen (${ASSETS_G1} G1)</li>"
fi

if [[ $BANKRUPTCY_DETECTED -eq 1 ]]; then
    echo "🚨 BANKRUPTCY ALERT: One or more allocations failed!"
    echo "🔄 Sending bankruptcy alerts to all users..."
    
    # Template path
    BANKRUPTCY_TEMPLATE="${MY_PATH}/../templates/NOSTR/bankrupt.html"
    BANKRUPTCY_REPORT="$HOME/.zen/tmp/bankruptcy_alert_${TODATE}.html"
    
    # Check if template exists
    if [[ -s "$BANKRUPTCY_TEMPLATE" ]]; then
        # Calculate values for template substitution
        REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
        UPLANET_ID="${UPLANETG1PUB:0:8}"
        
        # Calculate dynamic values for template
        # Load economic variables from .env or use defaults
        # PAF is already defined (default 14 if not set)
        [[ -z $PAF ]] && PAF=14
        [[ -z $NCARD ]] && NCARD=1
        [[ -z $ZCARD ]] && ZCARD=4
        [[ -z $TVA_RATE ]] && TVA_RATE=20
        [[ -z $IS_THRESHOLD ]] && IS_THRESHOLD=42500
        [[ -z $IS_RATE_REDUCED ]] && IS_RATE_REDUCED=15
        [[ -z $IS_RATE_NORMAL ]] && IS_RATE_NORMAL=25
        [[ -z $TREASURY_RATIO ]] && TREASURY_RATIO=33.33
        [[ -z $RND_RATIO ]] && RND_RATIO=33.33
        [[ -z $ASSETS_RATIO ]] && ASSETS_RATIO=33.34
        
        # Sociétaire share price (default 50 Ẑ/year = 50€)
        [[ -z $SOCIETAIRE_SHARE_PRICE ]] && SOCIETAIRE_SHARE_PRICE=50
        SOCIETAIRE_SHARE_PRICE_EUR=$SOCIETAIRE_SHARE_PRICE  # 1 Ẑ = 1€
        
        # Captain remuneration (2x PAF)
        CAPTAIN_REMUNERATION=$(echo "scale=2; $PAF * 2" | bc -l)
        
        # Minimum required for operational costs (PAF + Captain remuneration)
        MIN_REQUIRED=$(echo "scale=2; $PAF + $CAPTAIN_REMUNERATION" | bc -l)
        
        # Total allocations (Treasury + R&D + Assets)
        TOTAL_ALLOCATIONS=$(echo "scale=2; $TREASURY_AMOUNT + $RND_AMOUNT + $ASSETS_AMOUNT" | bc -l)
        
        # Total required for all allocations (operational + tax + cooperative)
        TOTAL_REQUIRED=$(echo "scale=2; $TAX_PROVISION + $TREASURY_AMOUNT + $RND_AMOUNT + $ASSETS_AMOUNT" | bc -l)
        TOTAL_NEEDED=$(echo "scale=2; $MIN_REQUIRED + $TAX_PROVISION + $TOTAL_ALLOCATIONS" | bc -l)
        
        # Calculate deficit
        DEFICIT=$(echo "scale=2; $TOTAL_REQUIRED - $REMAINING_BALANCE" | bc -l)
        
        # If deficit is negative, set to 0 (we have excess)
        if [[ $(echo "$DEFICIT < 0" | bc -l) -eq 1 ]]; then
            DEFICIT="0.00"
        else
            # Format deficit to 2 decimal places (remove trailing zeros if needed)
            DEFICIT=$(echo "scale=2; $DEFICIT" | bc -l)
        fi
        
        # Calculate impact examples for recovery plan
        IMPACT_10_MULTIPASS=$(echo "scale=2; 10 * $NCARD" | bc -l)
        IMPACT_5_ZENCARDS=$(echo "scale=2; 5 * $ZCARD" | bc -l)
        IMPACT_TOTAL_REVENUE=$(echo "scale=2; $IMPACT_10_MULTIPASS + $IMPACT_5_ZENCARDS" | bc -l)
        
        # Calculate sociétaire capital (10 sociétaires)
        SOCIETAIRE_CAPITAL=$(echo "scale=2; 10 * $SOCIETAIRE_SHARE_PRICE" | bc -l)
        
        # Escape special sed characters in replacement strings
        # The & character is special in sed (represents matched pattern)
        escape_sed_replacement() {
            echo "$1" | sed 's/[&/\]/\\&/g'
        }
        
        # Escape FAILED_ALLOCATIONS which may contain "R&D"
        FAILED_ALLOCATIONS_SAFE=$(escape_sed_replacement "$FAILED_ALLOCATIONS")
        
        # Generate HTML report from template using sed substitutions
        cat "$BANKRUPTCY_TEMPLATE" | sed \
            -e "s~_DATE_~${REPORT_DATE}~g" \
            -e "s~_TODATE_~${TODATE}~g" \
            -e "s~_UPLANET_ID_~${UPLANET_ID}~g" \
            -e "s~_CAPTAIN_BALANCE_~${CAPTAINZEN}~g" \
            -e "s~_PAF_~${PAF}~g" \
            -e "s~_CAPTAIN_REMUNERATION_~${CAPTAIN_REMUNERATION}~g" \
            -e "s~_MIN_REQUIRED_~${MIN_REQUIRED}~g" \
            -e "s~_NCARD_~${NCARD}~g" \
            -e "s~_ZCARD_~${ZCARD}~g" \
            -e "s~_TVA_RATE_~${TVA_RATE}~g" \
            -e "s~_IS_THRESHOLD_~${IS_THRESHOLD}~g" \
            -e "s~_IS_RATE_REDUCED_~${IS_RATE_REDUCED}~g" \
            -e "s~_IS_RATE_NORMAL_~${IS_RATE_NORMAL}~g" \
            -e "s~_TAX_RATE_USED_~${TAX_RATE_USED}~g" \
            -e "s~_TOTAL_ALLOCATIONS_~${TOTAL_ALLOCATIONS}~g" \
            -e "s~_TOTAL_NEEDED_~${TOTAL_NEEDED}~g" \
            -e "s~_DEFICIT_~${DEFICIT}~g" \
            -e "s~_IMPACT_10_MULTIPASS_~${IMPACT_10_MULTIPASS}~g" \
            -e "s~_IMPACT_5_ZENCARDS_~${IMPACT_5_ZENCARDS}~g" \
            -e "s~_IMPACT_TOTAL_REVENUE_~${IMPACT_TOTAL_REVENUE}~g" \
            -e "s~_SOCIETAIRE_SHARE_PRICE_~${SOCIETAIRE_SHARE_PRICE}~g" \
            -e "s~_SOCIETAIRE_SHARE_PRICE_EUR_~${SOCIETAIRE_SHARE_PRICE_EUR}~g" \
            -e "s~_SOCIETAIRE_CAPITAL_~${SOCIETAIRE_CAPITAL}~g" \
            -e "s~_FAILED_ALLOCATIONS_~${FAILED_ALLOCATIONS_SAFE}~g" \
            > "$BANKRUPTCY_REPORT"
        
        # Collect all user emails from ~/.zen/game/nostr/*/
        USER_EMAILS=()
        NOSTR_DIR="$HOME/.zen/game/nostr"
        
        if [[ -d "$NOSTR_DIR" ]]; then
            # Find all directories that contain email addresses (contain @)
            while IFS= read -r -d '' user_dir; do
                user_email=$(basename "$user_dir")
                # Check if it's a valid email format (contains @)
                if [[ "$user_email" =~ @ ]]; then
                    USER_EMAILS+=("$user_email")
                fi
            done < <(find "$NOSTR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        fi
        
        echo "📧 Found ${#USER_EMAILS[@]} user(s) to notify"
        
        # Send bankruptcy alert to all users
        ALERT_SENT_COUNT=0
        ALERT_FAILED_COUNT=0
        
        for user_email in "${USER_EMAILS[@]}"; do
            echo "📧 Sending bankruptcy alert to: $user_email"
            ${MY_PATH}/../tools/mailjet.sh "$user_email" "$BANKRUPTCY_REPORT" "⚠️ UPlanet Bankruptcy Alert - $TODATE"
            
            if [[ $? -eq 0 ]]; then
                echo "✅ Bankruptcy alert sent successfully to $user_email"
                ALERT_SENT_COUNT=$((ALERT_SENT_COUNT + 1))
            else
                echo "❌ Failed to send bankruptcy alert to $user_email"
                ALERT_FAILED_COUNT=$((ALERT_FAILED_COUNT + 1))
            fi
        done
        
        echo "============================================ BANKRUPTCY ALERT SUMMARY"
        echo "📊 Total users notified: ${#USER_EMAILS[@]}"
        echo "✅ Successfully sent: $ALERT_SENT_COUNT"
        echo "❌ Failed: $ALERT_FAILED_COUNT"
        echo "============================================ BANKRUPTCY ALERT DONE."
    else
        echo "⚠️  Bankruptcy template file not found: $BANKRUPTCY_TEMPLATE"
        echo "Skipping bankruptcy alert generation..."
    fi
else
    echo "✅ All allocations completed successfully - no bankruptcy detected"
fi

#######################################################################
# Mark weekly allocation as completed
# Create marker file with current date to prevent duplicate allocations
#######################################################################
echo "$TODATE" > "$ALLOCATION_MARKER"
echo "ZEN COOPERATIVE: Weekly allocation completed and marked for $TODATE"

#######################################################################
# BROADCAST ECONOMIC HEALTH TO NOSTR (kind 30850)
# Enables swarm-level economic visibility and legal compliance reporting
# See: nostr-nips/101-economic-health-extension.md
#######################################################################
if [[ -x "${MY_PATH}/ECONOMY.broadcast.sh" ]]; then
    echo ""
    echo "📡 Broadcasting economic health to NOSTR constellation..."
    ${MY_PATH}/ECONOMY.broadcast.sh 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "✅ Economic health report broadcasted successfully"
    else
        echo "⚠️  Economic health broadcast failed (non-critical)"
    fi
fi

exit 0
