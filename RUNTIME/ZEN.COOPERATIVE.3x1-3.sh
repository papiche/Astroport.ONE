#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.4 (Atomic Allocation & Gratitude Update)
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

# Marqueurs atomiques d'allocation — un fichier par étape pour éviter les doubles paiements
# si le script s'interrompt en cours de traitement.
# IMPORTANT : stockés dans ~/.zen/game/ (persistant) — ~/.zen/tmp/ est vidé à 20h12.
COOP_TAX_MARKER="$HOME/.zen/game/.coop_tax_${TODATE}"
COOP_TREASURY_MARKER="$HOME/.zen/game/.coop_treasury_${TODATE}"
COOP_RND_MARKER="$HOME/.zen/game/.coop_rnd_${TODATE}"
COOP_ASSETS_MARKER="$HOME/.zen/game/.coop_assets_${TODATE}"
COOP_CAPTAIN_MARKER="$HOME/.zen/game/.coop_captain_${TODATE}"

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
# Reversement INTRUSION → CAPTAIN_DEDICATED
# Les fonds intrusifs collectés par primal_wallet_control.sh sont
# réinjectés dans le circuit coopératif (en gardant 1 Ğ1 existential deposit)
#######################################################################
INTRUSION_DUNIKEY="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
if [[ -s "$INTRUSION_DUNIKEY" ]]; then
    INTRUSION_G1PUB=$(grep "pub:" "$INTRUSION_DUNIKEY" | awk '{print $2}')
    INTRUSION_COIN=$(${MY_PATH}/../tools/G1check.sh "${INTRUSION_G1PUB}" | tail -n 1)
    INTRUSION_ZEN=$(echo "scale=1; ($INTRUSION_COIN - 1) * 10" | bc)
    echo "INTRUSION wallet: ${INTRUSION_ZEN} Ẑen (${INTRUSION_COIN} Ğ1)"

    if [[ $(echo "$INTRUSION_ZEN > 0" | bc -l) -eq 1 ]]; then
        # Reversement vers UPLANETNAME_G1 (réserve coopérative centrale)
        UPLANETG1_DUNIKEY="$HOME/.zen/game/uplanet.G1.dunikey"
        UPLANETG1_PUB=$(grep "pub:" "$UPLANETG1_DUNIKEY" 2>/dev/null | awk '{print $2}')

        if [[ -n "$UPLANETG1_PUB" ]]; then
            echo "🔄 Reversement INTRUSION → UPLANETNAME_G1 : ALL (garde 1 Ğ1)"
            intrusion_result=$(${MY_PATH}/../tools/PAYforSURE.sh \
                "$INTRUSION_DUNIKEY" \
                "ALL" \
                "${UPLANETG1_PUB}" \
                "UP:${UPLANETG1PUB:0:8}:INTRUSION:REVERSE:${TODATE}")
            if [[ $? -eq 0 ]]; then
                echo "✅ Reversement INTRUSION réussi : ${INTRUSION_ZEN} Ẑen → UPLANETNAME_G1"
            else
                echo "❌ Échec reversement INTRUSION"
            fi
        else
            echo "⚠️  UPLANETNAME_G1 dunikey introuvable — reversement INTRUSION reporté"
        fi
    else
        echo "ℹ️  INTRUSION wallet vide (0 Ẑen) — rien à reverser"
    fi
else
    echo "ℹ️  Wallet INTRUSION inexistant — aucun reversement"
fi

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
if [[ -f "$COOP_TAX_MARKER" ]]; then
    echo "🔒 Provision fiscale déjà effectuée aujourd'hui (marqueur: $COOP_TAX_MARKER) — skip"
    TAX_SUCCESS=0
else
    tax_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$TAX_PROVISION_G1" "${IMPOTSG1PUB}" "UP:${UPLANETG1PUB:0:8}:TAX:${TODATE}:${TAX_PROVISION}Z:IS_${TAX_RATE_USED}pct" 2>/dev/null)
    TAX_SUCCESS=$?
    if [[ $TAX_SUCCESS -eq 0 ]]; then
        echo "✅ Tax provision completed: $TAX_PROVISION Ẑen ($TAX_PROVISION_G1 G1)"
        echo "$(date +%Y%m%d%H%M%S):TAX:${TAX_PROVISION}Z" > "$COOP_TAX_MARKER"
    else
        echo "❌ Tax provision failed: $TAX_PROVISION Ẑen"
    fi
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
# 33% + 33% + 33% + 1% = 100%
# Le 1% va au MULTIPASS du Capitaine (prime de gestion)
#######################################################################
[[ -z $TREASURY_RATIO ]] && TREASURY_RATIO=33  # 1/3 pour la trésorerie
[[ -z $RND_RATIO ]] && RND_RATIO=33            # 1/3 pour la R&D
[[ -z $ASSETS_RATIO ]] && ASSETS_RATIO=33      # 1/3 pour les actifs réels
[[ -z $CAPTAIN_BONUS_RATIO ]] && CAPTAIN_BONUS_RATIO=1  # 1% prime Capitaine

echo "ZEN COOPERATIVE: Allocation ratios - Treasury: $TREASURY_RATIO% | R&D: $RND_RATIO% | Assets: $ASSETS_RATIO% | Captain: $CAPTAIN_BONUS_RATIO%"

#######################################################################
# Calcul des montants d'allocation (sur le surplus net)
#######################################################################
TREASURY_AMOUNT=$(echo "scale=2; $NET_SURPLUS * $TREASURY_RATIO / 100" | bc -l)
RND_AMOUNT=$(echo "scale=2; $NET_SURPLUS * $RND_RATIO / 100" | bc -l)
ASSETS_AMOUNT=$(echo "scale=2; $NET_SURPLUS * $ASSETS_RATIO / 100" | bc -l)
CAPTAIN_BONUS_AMOUNT=$(echo "scale=2; $NET_SURPLUS * $CAPTAIN_BONUS_RATIO / 100" | bc -l)

echo "ZEN COOPERATIVE: Allocation amounts - Treasury: $TREASURY_AMOUNT Ẑen | R&D: $RND_AMOUNT Ẑen | Assets: $ASSETS_AMOUNT Ẑen | Captain: $CAPTAIN_BONUS_AMOUNT Ẑen"

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
if [[ -f "$COOP_TREASURY_MARKER" ]]; then
    echo "🔒 Allocation Trésorerie déjà effectuée aujourd'hui (marqueur) — skip"
    TREASURY_SUCCESS=0
else
    treasury_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$TREASURY_G1" "${TREASURYG1PUB}" "UP:${UPLANETG1PUB:0:8}:COOP:${TODATE}:${TREASURY_AMOUNT}Z:1/3_CASH" 2>/dev/null)
    TREASURY_SUCCESS=$?
    if [[ $TREASURY_SUCCESS -eq 0 ]]; then
        echo "✅ Treasury allocation completed: $TREASURY_AMOUNT Ẑen ($TREASURY_G1 G1)"
        echo "$(date +%Y%m%d%H%M%S):TREASURY:${TREASURY_AMOUNT}Z" > "$COOP_TREASURY_MARKER"
    else
        echo "❌ Treasury allocation failed: $TREASURY_AMOUNT Ẑen"
    fi
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
if [[ -f "$COOP_RND_MARKER" ]]; then
    echo "🔒 Allocation R&D déjà effectuée aujourd'hui (marqueur) — skip"
    RND_SUCCESS=0
else
    rnd_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$RND_G1" "${RNDG1PUB}" "UP:${UPLANETG1PUB:0:8}:COOP:${TODATE}:${RND_AMOUNT}Z:1/3_RnD" 2>/dev/null)
    RND_SUCCESS=$?
    if [[ $RND_SUCCESS -eq 0 ]]; then
        echo "✅ R&D allocation completed: $RND_AMOUNT Ẑen ($RND_G1 G1)"
        echo "$(date +%Y%m%d%H%M%S):RND:${RND_AMOUNT}Z" > "$COOP_RND_MARKER"
    else
        echo "❌ R&D allocation failed: $RND_AMOUNT Ẑen"
    fi
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
if [[ -f "$COOP_ASSETS_MARKER" ]]; then
    echo "🔒 Allocation ASSETS déjà effectuée aujourd'hui (marqueur) — skip"
    ASSETS_SUCCESS=0
else
    assets_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$ASSETS_G1" "${ASSETSG1PUB}" "UP:${UPLANETG1PUB:0:8}:COOP:${TODATE}:${ASSETS_AMOUNT}Z:1/3_ASSETS" 2>/dev/null)
    ASSETS_SUCCESS=$?
    if [[ $ASSETS_SUCCESS -eq 0 ]]; then
        echo "✅ Assets allocation completed: $ASSETS_AMOUNT Ẑen ($ASSETS_G1 G1)"
        echo "$(date +%Y%m%d%H%M%S):ASSETS:${ASSETS_AMOUNT}Z" > "$COOP_ASSETS_MARKER"
    else
        echo "❌ Assets allocation failed: $ASSETS_AMOUNT Ẑen"
    fi
fi

#######################################################################
# 1% Prime Capitaine → MULTIPASS du Capitaine
# Reconnaissance du travail de gestion et d'animation de la station
#######################################################################
CAPTAIN_BONUS_SUCCESS=1
if [[ -n "$CAPTAINEMAIL" && -n "$CAPTAING1PUB" ]]; then
    echo "🔄 Processing Captain bonus (1%): $CAPTAIN_BONUS_AMOUNT Ẑen → MULTIPASS $CAPTAINEMAIL"

    CAPTAIN_BONUS_G1=$(echo "scale=2; $CAPTAIN_BONUS_AMOUNT / 10" | bc -l)

    # TX Comment: UP:NetworkID:COOP:Date:Amount:Allocation (1% Captain management bonus)
    # Management recognition bonus sent to Captain's MULTIPASS
    # Source: CAPTAIN_DEDICATED (business wallet collecting rentals)
    if [[ -f "$COOP_CAPTAIN_MARKER" ]]; then
        echo "🔒 Prime Capitaine déjà effectuée aujourd'hui (marqueur) — skip"
        CAPTAIN_BONUS_SUCCESS=0
    else
        captain_bonus_result=$(${MY_PATH}/../tools/PAYforSURE.sh \
            "$HOME/.zen/game/uplanet.captain.dunikey" \
            "$CAPTAIN_BONUS_G1" \
            "${CAPTAING1PUB}" \
            "UP:${UPLANETG1PUB:0:8}:COOP:${TODATE}:${CAPTAIN_BONUS_AMOUNT}Z:1pct_CPT" \
            2>/dev/null)
        CAPTAIN_BONUS_SUCCESS=$?
        if [[ $CAPTAIN_BONUS_SUCCESS -eq 0 ]]; then
            echo "✅ Captain bonus completed: $CAPTAIN_BONUS_AMOUNT Ẑen ($CAPTAIN_BONUS_G1 G1) → $CAPTAINEMAIL"
            echo "$(date +%Y%m%d%H%M%S):CAPTAIN:${CAPTAIN_BONUS_AMOUNT}Z" > "$COOP_CAPTAIN_MARKER"
        else
            echo "❌ Captain bonus failed: $CAPTAIN_BONUS_AMOUNT Ẑen"
        fi
    fi
else
    echo "⚠️  Captain bonus skipped: CAPTAINEMAIL or CAPTAING1PUB not set"
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
echo "👨‍✈️ Captain (1%): $CAPTAIN_BONUS_AMOUNT Ẑen"
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
        ${MY_PATH}/../tools/mailjet.sh --expire 7d "$CAPTAINEMAIL" "$REPORT_FILE" "Cooperative Allocation Report - $TODATE"

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
# Vérification atomique des allocations
# Si une allocation échoue, le marqueur n'est PAS écrit → réessai au prochain cycle
#######################################################################
ALLOCATION_FAILED=0
FAILED_LIST=""

[[ $TAX_SUCCESS -ne 0 ]]          && { ALLOCATION_FAILED=1; FAILED_LIST="${FAILED_LIST} Impôt(${TAX_PROVISION}Ẑ);"; }
[[ $TREASURY_SUCCESS -ne 0 ]]     && { ALLOCATION_FAILED=1; FAILED_LIST="${FAILED_LIST} Trésorerie(${TREASURY_AMOUNT}Ẑ);"; }
[[ $RND_SUCCESS -ne 0 ]]          && { ALLOCATION_FAILED=1; FAILED_LIST="${FAILED_LIST} R&D(${RND_AMOUNT}Ẑ);"; }
[[ $ASSETS_SUCCESS -ne 0 ]]       && { ALLOCATION_FAILED=1; FAILED_LIST="${FAILED_LIST} ASSETS(${ASSETS_AMOUNT}Ẑ);"; }
[[ $CAPTAIN_BONUS_SUCCESS -ne 0 && -n "$CAPTAINEMAIL" ]] \
    && FAILED_LIST="${FAILED_LIST} PrimeCPT(${CAPTAIN_BONUS_AMOUNT}Ẑ, non-bloquant);"

if [[ $ALLOCATION_FAILED -eq 0 ]]; then
    echo "✅ ZEN COOPERATIVE: Toutes les allocations réussies pour $TODATE"
    #######################################################################
    # Marquer l'allocation comme complétée UNIQUEMENT si tout a réussi
    #######################################################################
    echo "$TODATE" > "$ALLOCATION_MARKER"
    echo "ZEN COOPERATIVE: Allocation hebdomadaire marquée pour $TODATE"
else
    echo "⚠️  ZEN COOPERATIVE: Échec partiel des allocations :${FAILED_LIST}"
    echo "   Le marqueur n'a PAS été défini → le script retentera au prochain cycle."
    echo "   Ce n'est pas une faillite : les fonds alloués le seront dès que possible."
    # Notification au Capitaine (non-bloquante)
    if [[ -n "$CAPTAINEMAIL" ]]; then
        ${MY_PATH}/../tools/mailjet.sh --expire 7d "$CAPTAINEMAIL" "" \
            "🔄 UPlanet Allocation partielle - Retry - $TODATE" 2>/dev/null || true
    fi
fi

exit 0
