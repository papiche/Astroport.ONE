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
# 1. 1/3 Trésorerie (Réserves) - Liquidité et stabilité
# 2. 1/3 R&D (G1FabLab) - Recherche et développement
# 3. 1/3 Forêts Jardins (Actifs Réels) - Investissement régénératif
# 
# Déclenchement : Allocation uniquement si le compte MULTIPASS du Capitaine 
# dépasse 4 fois la PAF hebdomadaire
#
# Conformité fiscale : Provision automatique TVA (20%) et IS (25%)
# via le portefeuille UPLANETNAME.IMPOT
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################
start=`date +%s`

 ## DESACTIVATE ZEN ECONOMY 
if [[ $PAF == 0 ]]; then
    echo "ZEN COOPERATIVE: PAF = 0"
    echo "Skipping allocation process..."
    exit 0
fi
#######################################################################
# Cooperative allocation check - ensure allocation is made only once per month
# Check if allocation was already done this month using marker file
#######################################################################
ALLOCATION_MARKER="$HOME/.zen/game/.cooperative_allocation.done"

# Get current month and year
CURRENT_MONTH=$(date +%m)
CURRENT_YEAR=$(date +%Y)
MONTH_KEY="${CURRENT_YEAR}-M${CURRENT_MONTH}"

# Check if allocation was already done this month
if [[ -f "$ALLOCATION_MARKER" ]]; then
    LAST_ALLOCATION_MONTH=$(cat "$ALLOCATION_MARKER")
    if [[ "$LAST_ALLOCATION_MONTH" == "$MONTH_KEY" ]]; then
        echo "ZEN COOPERATIVE: Monthly allocation already completed this month ($MONTH_KEY)"
        echo "Skipping allocation process..."
        exit 0
    fi
fi

echo "ZEN COOPERATIVE: Starting monthly allocation process for $MONTH_KEY"

#######################################################################
# Vérification du solde du compte MULTIPASS du Capitaine
#######################################################################
echo "CAPTAIN G1PUB : ${CAPTAING1PUB}"
CAPTAINCOIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAING1PUB} | tail -n 1)
CAPTAINZEN=$(echo "($CAPTAINCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "Captain MULTIPASS balance: $CAPTAINZEN Ẑen"

# Configuration de la PAF hebdomadaire
[[ -z $PAF ]] && PAF=14  # PAF hebdomadaire par défaut
CAPTAIN_THRESHOLD=$(echo "$PAF * 4" | bc -l)

echo "Captain threshold (4x PAF): $CAPTAIN_THRESHOLD Ẑen"

# Vérification du seuil du Capitaine
if [[ $(echo "$CAPTAINZEN < $CAPTAIN_THRESHOLD" | bc -l) -eq 1 ]]; then
    echo "ZEN COOPERATIVE: Captain's balance insufficient for allocation ($CAPTAINZEN Ẑen < $CAPTAIN_THRESHOLD Ẑen)"
    echo "Skipping allocation process..."
    exit 0
fi

#######################################################################
# Vérification du surplus disponible sur le portefeuille coopératif
#######################################################################
echo "UPlanet Cooperative G1PUB : ${UPLANETG1PUB}"
UPLANETCOIN=$(${MY_PATH}/../tools/G1check.sh ${UPLANETG1PUB} | tail -n 1)
UPLANETZEN=$(echo "($UPLANETCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "Cooperative balance: $UPLANETZEN Ẑen"

#######################################################################
# Configuration des paramètres fiscaux
#######################################################################
[[ -z $TVA_RATE ]] && TVA_RATE=20  # Taux de TVA (20%)

# Taux d'Impôt sur les Sociétés selon la réglementation française
# Source: https://www.impots.gouv.fr/international-professionnel/impot-sur-les-societes
[[ -z $IS_THRESHOLD ]] && IS_THRESHOLD=42500  # Plafond en euros (42 500 €)
[[ -z $IS_RATE_REDUCED ]] && IS_RATE_REDUCED=15  # Taux réduit (15% jusqu'à 42 500 €)
[[ -z $IS_RATE_NORMAL ]] && IS_RATE_NORMAL=25   # Taux normal (25% au-delà de 42 500 €)

echo "ZEN COOPERATIVE: Tax rates - VAT: $TVA_RATE%"
echo "ZEN COOPERATIVE: Corporate Tax - Reduced: $IS_RATE_REDUCED% (up to $IS_THRESHOLD €) | Normal: $IS_RATE_NORMAL% (above $IS_THRESHOLD €)"

#######################################################################
# Provision fiscale automatique (IS sur le surplus avec plafond)
#######################################################################
echo "🔄 Processing automatic tax provision..."

# Créer le portefeuille IMPOTS s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.impots.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.impots.dunikey "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
    chmod 600 ~/.zen/game/uplanet.impots.dunikey
fi

IMPOTSG1PUB=$(cat $HOME/.zen/game/uplanet.impots.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)

# Conversion du surplus en euros (1 Ẑen ≈ 1 €)
SURPLUS_EUR=$(echo "scale=2; $CAPTAINZEN * 1" | bc -l)

# Calcul de l'IS selon les tranches fiscales françaises
if [[ $(echo "$SURPLUS_EUR <= $IS_THRESHOLD" | bc -l) -eq 1 ]]; then
    # Taux réduit 15% pour les bénéfices jusqu'à 42 500 €
    TAX_PROVISION=$(echo "scale=2; $CAPTAINZEN * $IS_RATE_REDUCED / 100" | bc -l)
    TAX_RATE_USED=$IS_RATE_REDUCED
    echo "Using reduced tax rate: $IS_RATE_REDUCED% (surplus: $SURPLUS_EUR € <= $IS_THRESHOLD €)"
else
    # Taux normal 25% pour les bénéfices au-delà de 42 500 €
    TAX_PROVISION=$(echo "scale=2; $CAPTAINZEN * $IS_RATE_NORMAL / 100" | bc -l)
    TAX_RATE_USED=$IS_RATE_NORMAL
    echo "Using normal tax rate: $IS_RATE_NORMAL% (surplus: $SURPLUS_EUR € > $IS_THRESHOLD €)"
fi

TAX_PROVISION_G1=$(echo "scale=2; $TAX_PROVISION / 10" | bc -l)

echo "Tax provision (${TAX_RATE_USED}% of surplus): $TAX_PROVISION Ẑen ($TAX_PROVISION_G1 G1)"

# Transfert de la provision fiscale
tax_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" "$TAX_PROVISION_G1" "${IMPOTSG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:COOPERATIVE:TAX_PROVISION" 2>/dev/null)

if [[ $? -eq 0 ]]; then
    echo "✅ Tax provision completed: $TAX_PROVISION Ẑen ($TAX_PROVISION_G1 G1)"
else
    echo "❌ Tax provision failed: $TAX_PROVISION Ẑen"
fi

# Calcul du surplus net après provision fiscale
NET_SURPLUS=$(echo "scale=2; $CAPTAINZEN - $TAX_PROVISION" | bc -l)
echo "Net surplus after tax provision: $NET_SURPLUS Ẑen"

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
if [[ ! -s ~/.zen/game/uplanet.treasury.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.treasury.dunikey "${UPLANETNAME}.TREASURY" "${UPLANETNAME}.TREASURY"
    chmod 600 ~/.zen/game/uplanet.treasury.dunikey
fi

TREASURYG1PUB=$(cat $HOME/.zen/game/uplanet.treasury.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
# Calcul en G1
TREASURY_G1=$(echo "scale=2; $TREASURY_AMOUNT / 10" | bc -l)

# Transfert vers le portefeuille trésorerie
treasury_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" "$TREASURY_G1" "${TREASURYG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:COOPERATIVE:TREASURY" 2>/dev/null)

if [[ $? -eq 0 ]]; then
    echo "✅ Treasury allocation completed: $TREASURY_AMOUNT Ẑen ($TREASURY_G1 G1)"
else
    echo "❌ Treasury allocation failed: $TREASURY_AMOUNT Ẑen"
fi

#######################################################################
# 1/3 R&D (G1FabLab) - Recherche et développement
#######################################################################
echo "🔄 Processing R&D allocation (1/3): $RND_AMOUNT Ẑen"

# Créer le portefeuille R&D s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.rnd.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.rnd.dunikey "${UPLANETNAME}.RND" "${UPLANETNAME}.RND"
    chmod 600 ~/.zen/game/uplanet.rnd.dunikey
fi

RNDG1PUB=$(cat $HOME/.zen/game/uplanet.rnd.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
# Calcul en G1
RND_G1=$(echo "scale=2; $RND_AMOUNT / 10" | bc -l)

# Transfert vers le portefeuille R&D
rnd_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" "$RND_G1" "${RNDG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:COOPERATIVE:RND" 2>/dev/null)

if [[ $? -eq 0 ]]; then
    echo "✅ R&D allocation completed: $RND_AMOUNT Ẑen ($RND_G1 G1)"
else
    echo "❌ R&D allocation failed: $RND_AMOUNT Ẑen"
fi

#######################################################################
# 1/3 Forêts Jardins (Actifs Réels) - Investissement régénératif
#######################################################################
echo "🔄 Processing Assets allocation (1/3): $ASSETS_AMOUNT Ẑen"

# Créer le portefeuille actifs s'il n'existe pas
if [[ ! -s ~/.zen/game/uplanet.assets.dunikey ]]; then
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.assets.dunikey "${UPLANETNAME}.ASSETS" "${UPLANETNAME}.ASSETS"
    chmod 600 ~/.zen/game/uplanet.assets.dunikey
fi

ASSETSG1PUB=$(cat $HOME/.zen/game/uplanet.assets.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
# Calcul en G1
ASSETS_G1=$(echo "scale=2; $ASSETS_AMOUNT / 10" | bc -l)

# Transfert vers le portefeuille actifs
assets_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" "$ASSETS_G1" "${ASSETSG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:COOPERATIVE:ASSETS" 2>/dev/null)

if [[ $? -eq 0 ]]; then
    echo "✅ Assets allocation completed: $ASSETS_AMOUNT Ẑen ($ASSETS_G1 G1)"
else
    echo "❌ Assets allocation failed: $ASSETS_AMOUNT Ẑen"
fi

#######################################################################
# Rapport d'allocation avec conformité fiscale
#######################################################################
echo "============================================ COOPERATIVE ALLOCATION SUMMARY"
echo "📊 Total surplus: $CAPTAINZEN Ẑen"
echo "💰 Tax provision (${TAX_RATE_USED}%): $TAX_PROVISION Ẑen"
echo "📈 Net surplus allocated: $NET_SURPLUS Ẑen"
echo "🏦 Treasury (1/3): $TREASURY_AMOUNT Ẑen"
echo "🔬 R&D (1/3): $RND_AMOUNT Ẑen"
echo "🌱 Assets (1/3): $ASSETS_AMOUNT Ẑen"
echo "============================================ COOPERATIVE ALLOCATION DONE."

#######################################################################
# Envoi du rapport par email via mailjet.sh
#######################################################################
echo "🔄 Sending allocation report via email..."

# Créer le fichier de rapport
REPORT_FILE="$HOME/.zen/tmp/cooperative_allocation_report_${MONTH_KEY}.txt"

cat > "$REPORT_FILE" << EOF
============================================
COOPERATIVE ALLOCATION REPORT
============================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Period: $MONTH_KEY
UPlanet: ${UPLANETG1PUB:0:8}

ECONOMIC DATA:
- Captain MULTIPASS balance: $CAPTAINZEN Ẑen
- Captain threshold (4x PAF): $CAPTAIN_THRESHOLD Ẑen

TAX PROVISION:
- Tax rate applied: ${TAX_RATE_USED}%
- Tax provision: $TAX_PROVISION Ẑen ($TAX_PROVISION_G1 G1)
- Net surplus after tax: $NET_SURPLUS Ẑen

ALLOCATION 3x1/3 (on net surplus):
- Treasury (1/3): $TREASURY_AMOUNT Ẑen
- R&D (1/3): $RND_AMOUNT Ẑen
- Assets (1/3): $ASSETS_AMOUNT Ẑen

WALLET ADDRESSES:
- Treasury: ${TREASURYG1PUB:0:8}...
- R&D: ${RNDG1PUB:0:8}...
- Assets: ${ASSETSG1PUB:0:8}...
- Tax provision: ${IMPOTSG1PUB:0:8}...

STATUS: ✅ Allocation completed successfully
============================================
EOF

# Envoyer le rapport par email au Capitaine
if [[ -n "$CAPTAINEMAIL" && -s "$REPORT_FILE" ]]; then
    echo "📧 Sending report to Captain: $CAPTAINEMAIL"
    ${MY_PATH}/../tools/mailjet.sh "$CAPTAINEMAIL" "$REPORT_FILE" "Cooperative Allocation Report - $MONTH_KEY"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Report sent successfully to Captain"
    else
        echo "❌ Failed to send report to Captain"
    fi
else
    echo "⚠️  Captain email not configured or report file empty"
fi

#######################################################################
# Mark monthly allocation as completed
# Create marker file with current month to prevent duplicate allocations
#######################################################################
echo "$MONTH_KEY" > "$ALLOCATION_MARKER"
echo "ZEN COOPERATIVE: Monthly allocation completed and marked for $MONTH_KEY"

exit 0
