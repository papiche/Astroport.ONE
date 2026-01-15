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
# 2. Gère le paiement hebdomadaire des coûts opérationnels depuis CASH :
#    - 1x PAF → NODE (loyer matériel Armateur)
#    - 2x PAF → CAPTAIN MULTIPASS (rétribution travail personnelle)
# 3. Implémente le burn 4-semaines et conversion OpenCollective
#
# FLUX ÉCONOMIQUE :
# - CASH (Réserve de Fonctionnement) paie les coûts opérationnels
# - CAPTAIN MULTIPASS = revenus personnels du capitaine (salaire)
# - CAPTAIN_DEDICATED (uplanet.captain.dunikey) = collecte des loyers usagers
#   → Utilisé par ZEN.COOPERATIVE.3x1-3.sh pour allocation coopérative
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
# Source cooperative config for DID-based configuration (encrypted in NOSTR)
. "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null || true
################################################################################
start=`date +%s`

#######################################################################
# Setup logging directory and file
#######################################################################
LOG_DIR="$HOME/.zen/tmp/coucou"
LOG_FILE="$LOG_DIR/zen_economy.txt"
mkdir -p "$LOG_DIR"

# Function to log both to console and file
log_output() {
    echo "$@" | tee -a "$LOG_FILE"
}

# Start logging session with timestamp and separator
{
    echo ""
    echo "========================================================================"
    echo " ZEN ECONOMY RUN - $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "========================================================================"
} >> "$LOG_FILE"

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
        log_output "ZEN ECONOMY: Weekly payment already completed this week ($WEEK_KEY)"
        log_output "Skipping payment process..."
        log_output "========================================================================"
        exit 0
    fi
fi

log_output "ZEN ECONOMY: Starting weekly payment process for week $WEEK_KEY"

#######################################################################
# Vérification des soldes des différents acteurs du système
# UPlanet : La "banque centrale" coopérative
# Node : Le serveur physique (PC Gamer ou RPi5)
# Captain : Le gestionnaire du Node
#######################################################################
log_output "UPlanet G1PUB : ${UPLANETG1PUB}"
UCOIN=$(${MY_PATH}/../tools/G1check.sh ${UPLANETG1PUB} | tail -n 1)
UZEN=$(echo "scale=1; ($UCOIN - 1) * 10" | bc)
log_output "$UZEN Ẑen"

# Vérification du Node (Astroport)
NODEG1PUB=$($MY_PATH/../tools/ipfs_to_g1.py ${IPFSNODEID})
log_output "NODE G1PUB : ${NODEG1PUB}"
NODECOIN=$(${MY_PATH}/../tools/G1check.sh ${NODEG1PUB} | tail -n 1)
NODEZEN=$(echo "scale=1; ($NODECOIN - 1) * 10" | bc)
log_output "$NODEZEN Ẑen"

# Vérification du Captain (gestionnaire) - MULTIPASS (NOSTR)
log_output "CAPTAIN G1PUB : ${CAPTAING1PUB}"
CAPTAINCOIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAING1PUB} | tail -n 1)
CAPTAINZEN=$(echo "scale=1; ($CAPTAINCOIN - 1) * 10" | bc)
log_output "Captain MULTIPASS balance: $CAPTAINZEN Ẑen"

# Vérification de la ZEN Card du Captain (PLAYERS)
if [[ -n "$CAPTAINEMAIL" ]]; then
    CAPTAIN_ZENCARD_PATH="$HOME/.zen/game/players/$CAPTAINEMAIL"
    if [[ -d "$CAPTAIN_ZENCARD_PATH" && -s "$CAPTAIN_ZENCARD_PATH/secret.dunikey" ]]; then
        CAPTAIN_ZENCARD_PUB=$(cat "$CAPTAIN_ZENCARD_PATH/secret.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
        if [[ -n "$CAPTAIN_ZENCARD_PUB" ]]; then
            CAPTAIN_ZENCARD_COIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAIN_ZENCARD_PUB} | tail -n 1)
            CAPTAIN_ZENCARD_ZEN=$(echo "scale=1; ($CAPTAIN_ZENCARD_COIN - 1) * 10" | bc)
            log_output "Captain ZEN Card balance: $CAPTAIN_ZENCARD_ZEN Ẑen"
        else
            CAPTAIN_ZENCARD_ZEN=0
            log_output "Captain ZEN Card not found or invalid"
        fi
    else
        CAPTAIN_ZENCARD_ZEN=0
        log_output "Captain ZEN Card not found"
    fi
else
    CAPTAIN_ZENCARD_ZEN=0
    log_output "Captain email not configured"
fi

#######################################################################
# Comptage des utilisateurs actifs
# NOSTR : Utilisateurs avec carte NOSTR (1 Ẑen/semaine)
# PLAYERS : Utilisateurs avec carte ZEN (4 Ẑen/semaine)
#######################################################################
NOSTRS=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))
PLAYERS=($(ls -t ~/.zen/game/players/ 2>/dev/null | grep "@" ))
log_output "NODE hosts MULTIPASS : ${#NOSTRS[@]} / ZENCARD : ${#PLAYERS[@]}"

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
log_output "ZEN ECONOMY : PAF=$WEEKLYPAF ZEN/week :: NCARD=$NCARD // ZCARD=$ZCARD"
WEEKLYG1=$(makecoord $(echo "$WEEKLYPAF / 10" | bc -l))

##################################################################################
# Système de paiement hebdomadaire depuis CASH (Réserve de Fonctionnement)
# MODÈLE ÉCONOMIQUE (flux correct) :
# - CASH → NODE (1x PAF) : loyer matériel Armateur
# - CASH → CAPTAIN MULTIPASS (2x PAF) : rétribution travail personnelle
# 
# Note : Le Capitaine REÇOIT sa rétribution sur son MULTIPASS personnel.
#        Les loyers usagers sont collectés sur CAPTAIN_DEDICATED (séparé)
#        et servent de source pour l'allocation coopérative 3x1/3.
#######################################################################

# Ensure CASH wallet exists and get its balance
if [[ ! -s "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
    log_output "⚠️  CASH wallet not found - creating it..."
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.CASH.dunikey "${UPLANETNAME}.TREASURY" "${UPLANETNAME}.TREASURY"
    chmod 600 ~/.zen/game/uplanet.CASH.dunikey
fi

CASH_G1PUB=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
CASH_COIN=$(${MY_PATH}/../tools/G1check.sh ${CASH_G1PUB} | tail -n 1)
CASH_ZEN=$(echo "scale=1; ($CASH_COIN - 1) * 10" | bc)
log_output "CASH (Treasury) balance: $CASH_ZEN Ẑen"

# Calculate total required: 3x PAF (1x NODE + 2x CAPTAIN)
TOTAL_PAF_REQUIRED=$(echo "scale=2; $WEEKLYPAF * 3" | bc -l)
log_output "ZEN ECONOMY: Total weekly PAF required: $TOTAL_PAF_REQUIRED Ẑen (1x NODE + 2x CAPTAIN)"

if [[ $(echo "$WEEKLYG1 > 0" | bc -l) -eq 1 ]]; then
    if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 ]]; then
        
        #######################################################################
        # PROGRESSIVE DEGRADATION SYSTEM (Shareholder Agreement)
        # Instead of transferring funds, pay directly from backup wallets:
        # 
        # PHASE 0: Normal operation - Pay from CASH
        # PHASE 1: Growth slowdown - Pay from ASSETS (forest-gardens depleting)
        # PHASE 2: Innovation slowdown - Pay from RnD (R&D budget depleting)
        # PHASE 3: BANKRUPTCY - No funds available, GAME OVER
        #
        # Each phase sends notifications to all shareholders for transparency.
        # This allows collective corrective action before total bankruptcy.
        #######################################################################
        
        BANKRUPTCY_TRIGGERED=0
        PRE_BANKRUPTCY_PHASE=0
        CAPTAIN_PAID=0
        NODE_PAID=0
        PAYMENT_SOURCE="CASH"
        NODE_PAYMENT_SOURCE=""
        CAPTAIN_PAYMENT_SOURCE=""
        
        # Calculate remuneration amounts
        CAPTAIN_REMUNERATION=$(echo "scale=2; $WEEKLYPAF * 2" | bc -l)
        CAPTAIN_REMUNERATION_G1=$(makecoord $(echo "$CAPTAIN_REMUNERATION / 10" | bc -l))
        
        # Get ASSETS wallet balance
        ASSETS_ZEN=0
        ASSETS_G1PUB=""
        if [[ -s ~/.zen/game/uplanet.ASSETS.dunikey ]]; then
            ASSETS_G1PUB=$(cat ~/.zen/game/uplanet.ASSETS.dunikey | grep "pub:" | cut -d ' ' -f 2)
            ASSETS_COIN=$(${MY_PATH}/../tools/G1check.sh ${ASSETS_G1PUB} | tail -n 1)
            ASSETS_ZEN=$(echo "scale=1; ($ASSETS_COIN - 1) * 10" | bc)
        fi
        log_output "ASSETS (Forest-Gardens) balance: $ASSETS_ZEN Ẑen"
        
        # Get RnD wallet balance
        RND_ZEN=0
        RND_G1PUB=""
        if [[ -s ~/.zen/game/uplanet.RnD.dunikey ]]; then
            RND_G1PUB=$(cat ~/.zen/game/uplanet.RnD.dunikey | grep "pub:" | cut -d ' ' -f 2)
            RND_COIN=$(${MY_PATH}/../tools/G1check.sh ${RND_G1PUB} | tail -n 1)
            RND_ZEN=$(echo "scale=1; ($RND_COIN - 1) * 10" | bc)
        fi
        log_output "RnD (Innovation) balance: $RND_ZEN Ẑen"
        
        #######################################################################
        # PRIORITY 1: Pay NODE (1x PAF) - Infrastructure is critical
        #######################################################################
        log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_output "📦 NODE PAYMENT (1x PAF = $WEEKLYPAF Ẑen)"
        
        if [[ $(echo "$CASH_ZEN >= $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            # PHASE 0: Normal - Pay from CASH
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CASH.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UP:${UPLANETG1PUB:0:8}:PAF:W${CURRENT_WEEK}:${WEEKLYPAF}Z:CASH>NODE" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_output "✅ CASH paid NODE PAF: $WEEKLYPAF Ẑen ($WEEKLYG1 G1)"
                NODE_PAID=1
                NODE_PAYMENT_SOURCE="CASH"
                CASH_ZEN=$(echo "scale=1; $CASH_ZEN - $WEEKLYPAF" | bc)
            else
                log_output "❌ CASH payment to NODE failed - trying ASSETS"
            fi
        fi
        
        # PHASE 1: Growth slowdown - Try ASSETS if CASH insufficient/failed
        if [[ $NODE_PAID -eq 0 && $(echo "$ASSETS_ZEN >= $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            PRE_BANKRUPTCY_PHASE=1
            PAYMENT_SOURCE="ASSETS"
            log_output "⚠️  PHASE 1: CASH insufficient - Paying NODE from ASSETS (growth slowdown)"
            ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.ASSETS.dunikey "$WEEKLYG1" "${NODEG1PUB}" "UP:${UPLANETG1PUB:0:8}:PAF:W${CURRENT_WEEK}:${WEEKLYPAF}Z:ASSETS>NODE:PHASE1" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_output "✅ ASSETS paid NODE PAF: $WEEKLYPAF Ẑen (growth slowing)"
                NODE_PAID=1
                NODE_PAYMENT_SOURCE="ASSETS"
                ASSETS_ZEN=$(echo "scale=1; $ASSETS_ZEN - $WEEKLYPAF" | bc)
            else
                log_output "❌ ASSETS payment to NODE failed - trying RnD"
            fi
        fi
        
        # PHASE 2: Innovation slowdown - Try RnD if ASSETS insufficient/failed
        if [[ $NODE_PAID -eq 0 && $(echo "$RND_ZEN >= $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            PRE_BANKRUPTCY_PHASE=2
            PAYMENT_SOURCE="RnD"
            log_output "⚠️  PHASE 2: ASSETS depleted - Paying NODE from RnD (innovation slowdown)"
            ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.RnD.dunikey "$WEEKLYG1" "${NODEG1PUB}" "UP:${UPLANETG1PUB:0:8}:PAF:W${CURRENT_WEEK}:${WEEKLYPAF}Z:RND>NODE:PHASE2" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_output "✅ RnD paid NODE PAF: $WEEKLYPAF Ẑen (innovation slowing)"
                NODE_PAID=1
                NODE_PAYMENT_SOURCE="RnD"
                RND_ZEN=$(echo "scale=1; $RND_ZEN - $WEEKLYPAF" | bc)
            else
                log_output "❌ RnD payment to NODE failed"
            fi
        fi
        
        # PHASE 3: BANKRUPTCY - No funds available
        if [[ $NODE_PAID -eq 0 ]]; then
            PRE_BANKRUPTCY_PHASE=3
            BANKRUPTCY_TRIGGERED=1
            log_output "💀 PHASE 3: BANKRUPTCY - Cannot pay NODE PAF!"
            log_output "   CASH: $CASH_ZEN Ẑen | ASSETS: $ASSETS_ZEN Ẑen | RnD: $RND_ZEN Ẑen"
            log_output "   Required: $WEEKLYPAF Ẑen - Infrastructure cannot function!"
        fi
        
        #######################################################################
        # PRIORITY 2: Pay Captain (2x PAF) - Only if NODE was paid
        #######################################################################
        log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_output "👨‍✈️ CAPTAIN PAYMENT (2x PAF = $CAPTAIN_REMUNERATION Ẑen)"
        
        if [[ $NODE_PAID -eq 1 ]]; then
            # Try CASH first
            if [[ $(echo "$CASH_ZEN >= $CAPTAIN_REMUNERATION" | bc -l) -eq 1 ]]; then
                ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CASH.dunikey" "$CAPTAIN_REMUNERATION_G1" "${CAPTAING1PUB}" "UP:${UPLANETG1PUB:0:8}:SALARY:W${CURRENT_WEEK}:${CAPTAIN_REMUNERATION}Z:CASH>CPT" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_output "✅ CASH paid Captain: $CAPTAIN_REMUNERATION Ẑen"
                    CAPTAIN_PAID=1
                    CAPTAIN_PAYMENT_SOURCE="CASH"
                    CASH_ZEN=$(echo "scale=1; $CASH_ZEN - $CAPTAIN_REMUNERATION" | bc)
                fi
            fi
            
            # PHASE 1: Try ASSETS if CASH insufficient
            if [[ $CAPTAIN_PAID -eq 0 && $(echo "$ASSETS_ZEN >= $CAPTAIN_REMUNERATION" | bc -l) -eq 1 ]]; then
                [[ $PRE_BANKRUPTCY_PHASE -lt 1 ]] && PRE_BANKRUPTCY_PHASE=1
                log_output "⚠️  PHASE 1: Paying Captain from ASSETS"
                ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.ASSETS.dunikey "$CAPTAIN_REMUNERATION_G1" "${CAPTAING1PUB}" "UP:${UPLANETG1PUB:0:8}:SALARY:W${CURRENT_WEEK}:${CAPTAIN_REMUNERATION}Z:ASSETS>CPT:PHASE1" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_output "✅ ASSETS paid Captain: $CAPTAIN_REMUNERATION Ẑen"
                    CAPTAIN_PAID=1
                    CAPTAIN_PAYMENT_SOURCE="ASSETS"
                    ASSETS_ZEN=$(echo "scale=1; $ASSETS_ZEN - $CAPTAIN_REMUNERATION" | bc)
                fi
            fi
            
            # PHASE 2: Try RnD if ASSETS insufficient
            if [[ $CAPTAIN_PAID -eq 0 && $(echo "$RND_ZEN >= $CAPTAIN_REMUNERATION" | bc -l) -eq 1 ]]; then
                [[ $PRE_BANKRUPTCY_PHASE -lt 2 ]] && PRE_BANKRUPTCY_PHASE=2
                log_output "⚠️  PHASE 2: Paying Captain from RnD"
                ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.RnD.dunikey "$CAPTAIN_REMUNERATION_G1" "${CAPTAING1PUB}" "UP:${UPLANETG1PUB:0:8}:SALARY:W${CURRENT_WEEK}:${CAPTAIN_REMUNERATION}Z:RND>CPT:PHASE2" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_output "✅ RnD paid Captain: $CAPTAIN_REMUNERATION Ẑen"
                    CAPTAIN_PAID=1
                    CAPTAIN_PAYMENT_SOURCE="RnD"
                    RND_ZEN=$(echo "scale=1; $RND_ZEN - $CAPTAIN_REMUNERATION" | bc)
                fi
            fi
            
            # Captain not paid but NODE was - partial degradation
            if [[ $CAPTAIN_PAID -eq 0 ]]; then
                log_output "⚠️  Captain NOT PAID: Insufficient funds in all wallets"
                log_output "   Required: $CAPTAIN_REMUNERATION Ẑen"
                log_output "   CASH: $CASH_ZEN | ASSETS: $ASSETS_ZEN | RnD: $RND_ZEN"
                [[ $PRE_BANKRUPTCY_PHASE -lt 2 ]] && PRE_BANKRUPTCY_PHASE=2
            fi
        else
            log_output "⏭️  Captain payment skipped (NODE not paid - infrastructure priority)"
        fi
        
        log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        #######################################################################
        # SEND PRE-BANKRUPTCY NOTIFICATION (Shareholder Agreement Transparency)
        #######################################################################
        if [[ $PRE_BANKRUPTCY_PHASE -gt 0 && $PRE_BANKRUPTCY_PHASE -lt 3 ]]; then
            log_output "📧 Sending pre-bankruptcy notification (Phase $PRE_BANKRUPTCY_PHASE)..."
            
            PRE_BANKRUPTCY_TEMPLATE="${MY_PATH}/../templates/NOSTR/pre_bankruptcy.html"
            PRE_BANKRUPTCY_REPORT="$HOME/.zen/tmp/pre_bankruptcy_phase${PRE_BANKRUPTCY_PHASE}_$(date +%Y-%m-%d).html"
            
            if [[ -s "$PRE_BANKRUPTCY_TEMPLATE" ]]; then
                REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
                TODATE=$(date +%Y-%m-%d)
                UPLANET_ID="${UPLANETG1PUB:0:8}"
                
                # Set phase-specific variables
                case $PRE_BANKRUPTCY_PHASE in
                    1)
                        PHASE_CLASS="assets"
                        PHASE_ICON="🌱"
                        PHASE_NAME_FR="Ralentissement de Croissance"
                        PHASE_NAME_EN="Growth Slowdown"
                        PHASE_NAME_ES="Desaceleración del Crecimiento"
                        PHASE_DESCRIPTION_FR="Les paiements sont effectués depuis le portefeuille ASSETS. Les investissements en forêts-jardins sont temporairement suspendus."
                        PHASE_DESCRIPTION_EN="Payments are made from the ASSETS wallet. Forest-garden investments are temporarily suspended."
                        PHASE_DESCRIPTION_ES="Los pagos se realizan desde la cartera ASSETS. Las inversiones en bosques-jardines están temporalmente suspendidas."
                        IMPACT_LIST_FR="<li>Investissements forêts-jardins suspendus</li><li>Croissance de l'écosystème ralentie</li><li>Services opérationnels maintenus</li>"
                        IMPACT_LIST_EN="<li>Forest-garden investments suspended</li><li>Ecosystem growth slowed</li><li>Operational services maintained</li>"
                        ASSETS_STATUS_TEXT="Source de paiement active"
                        ASSETS_STATUS_TEXT_EN="Active payment source"
                        ASSETS_STATUS_TEXT_ES="Fuente de pago activa"
                        RND_STATUS_TEXT="En réserve"
                        RND_STATUS_TEXT_EN="In reserve"
                        RND_STATUS_TEXT_ES="En reserva"
                        ;;
                    2)
                        PHASE_CLASS="rnd"
                        PHASE_ICON="🔬"
                        PHASE_NAME_FR="Réduction R&D"
                        PHASE_NAME_EN="R&D Reduction"
                        PHASE_NAME_ES="Reducción de I+D"
                        PHASE_DESCRIPTION_FR="Les paiements sont effectués depuis le portefeuille RnD. L'innovation et le développement sont temporairement suspendus."
                        PHASE_DESCRIPTION_EN="Payments are made from the RnD wallet. Innovation and development are temporarily suspended."
                        PHASE_DESCRIPTION_ES="Los pagos se realizan desde la cartera RnD. La innovación y el desarrollo están temporalmente suspendidos."
                        IMPACT_LIST_FR="<li>Investissements forêts-jardins épuisés</li><li>Budget R&D utilisé pour l'opérationnel</li><li>Innovation temporairement suspendue</li><li>Services opérationnels maintenus</li>"
                        IMPACT_LIST_EN="<li>Forest-garden investments depleted</li><li>R&D budget used for operations</li><li>Innovation temporarily suspended</li><li>Operational services maintained</li>"
                        ASSETS_STATUS_TEXT="Épuisé (≤ 1Ğ1)"
                        ASSETS_STATUS_TEXT_EN="Depleted (≤ 1Ğ1)"
                        ASSETS_STATUS_TEXT_ES="Agotado (≤ 1Ğ1)"
                        RND_STATUS_TEXT="Source de paiement active"
                        RND_STATUS_TEXT_EN="Active payment source"
                        RND_STATUS_TEXT_ES="Fuente de pago activa"
                        ;;
                esac
                
                # Determine wallet statuses
                CASH_STATUS="depleted"
                [[ $(echo "$ASSETS_ZEN > 0" | bc -l) -eq 1 ]] && ASSETS_STATUS="warning" || ASSETS_STATUS="depleted"
                [[ $(echo "$RND_ZEN > 0" | bc -l) -eq 1 ]] && RND_STATUS="healthy" || RND_STATUS="warning"
                [[ $PRE_BANKRUPTCY_PHASE -eq 2 ]] && RND_STATUS="warning"
                
                # Payment status texts
                if [[ $NODE_PAID -eq 1 ]]; then
                    NODE_PAYMENT_STATUS_FR="✅ Payé depuis $NODE_PAYMENT_SOURCE ($WEEKLYPAF Ẑen)"
                    NODE_PAYMENT_STATUS_EN="✅ Paid from $NODE_PAYMENT_SOURCE ($WEEKLYPAF Ẑen)"
                else
                    NODE_PAYMENT_STATUS_FR="❌ Non payé"
                    NODE_PAYMENT_STATUS_EN="❌ Not paid"
                fi
                
                if [[ $CAPTAIN_PAID -eq 1 ]]; then
                    CAPTAIN_PAYMENT_STATUS_FR="✅ Payé depuis $CAPTAIN_PAYMENT_SOURCE ($CAPTAIN_REMUNERATION Ẑen)"
                    CAPTAIN_PAYMENT_STATUS_EN="✅ Paid from $CAPTAIN_PAYMENT_SOURCE ($CAPTAIN_REMUNERATION Ẑen)"
                else
                    CAPTAIN_PAYMENT_STATUS_FR="❌ Non payé - Fonds insuffisants"
                    CAPTAIN_PAYMENT_STATUS_EN="❌ Not paid - Insufficient funds"
                fi
                
                # Calculate impact examples
                [[ -z $NCARD ]] && NCARD=1
                [[ -z $ZCARD ]] && ZCARD=4
                IMPACT_10_MULTIPASS=$(echo "scale=0; 10 * $NCARD" | bc)
                IMPACT_5_ZENCARDS=$(echo "scale=0; 5 * $ZCARD" | bc)
                
                # Escape special sed characters in replacement strings
                # The & character is special in sed (represents matched pattern)
                escape_sed_replacement() {
                    echo "$1" | sed 's/[&/\]/\\&/g'
                }
                
                # Escape variables that may contain special characters (& in R&D)
                PHASE_NAME_FR_SAFE=$(escape_sed_replacement "$PHASE_NAME_FR")
                PHASE_NAME_EN_SAFE=$(escape_sed_replacement "$PHASE_NAME_EN")
                PHASE_NAME_ES_SAFE=$(escape_sed_replacement "$PHASE_NAME_ES")
                IMPACT_LIST_FR_SAFE=$(escape_sed_replacement "$IMPACT_LIST_FR")
                IMPACT_LIST_EN_SAFE=$(escape_sed_replacement "$IMPACT_LIST_EN")
                
                # Generate HTML report
                # IMPORTANT: Process longer variable names FIRST to avoid collision
                # e.g., _ASSETS_STATUS_TEXT_ES_ before _ASSETS_STATUS_TEXT_ before _ASSETS_STATUS_
                cat "$PRE_BANKRUPTCY_TEMPLATE" | sed \
                    -e "s~_DATE_~${REPORT_DATE}~g" \
                    -e "s~_TODATE_~${TODATE}~g" \
                    -e "s~_UPLANET_ID_~${UPLANET_ID}~g" \
                    -e "s~_DEGRADATION_PHASE_~${PRE_BANKRUPTCY_PHASE}~g" \
                    -e "s~_PAYMENT_SOURCE_~${PAYMENT_SOURCE}~g" \
                    -e "s~_PHASE_CLASS_~${PHASE_CLASS}~g" \
                    -e "s~_PHASE_ICON_~${PHASE_ICON}~g" \
                    -e "s~_PHASE_NAME_FR_~${PHASE_NAME_FR_SAFE}~g" \
                    -e "s~_PHASE_NAME_EN_~${PHASE_NAME_EN_SAFE}~g" \
                    -e "s~_PHASE_NAME_ES_~${PHASE_NAME_ES_SAFE}~g" \
                    -e "s~_PHASE_DESCRIPTION_FR_~${PHASE_DESCRIPTION_FR}~g" \
                    -e "s~_PHASE_DESCRIPTION_EN_~${PHASE_DESCRIPTION_EN}~g" \
                    -e "s~_PHASE_DESCRIPTION_ES_~${PHASE_DESCRIPTION_ES}~g" \
                    -e "s~_CASH_BALANCE_~${CASH_ZEN}~g" \
                    -e "s~_ASSETS_BALANCE_~${ASSETS_ZEN}~g" \
                    -e "s~_RND_BALANCE_~${RND_ZEN}~g" \
                    -e "s~_TOTAL_PAF_REQUIRED_~${TOTAL_PAF_REQUIRED}~g" \
                    -e "s~_ASSETS_STATUS_TEXT_ES_~${ASSETS_STATUS_TEXT_ES}~g" \
                    -e "s~_ASSETS_STATUS_TEXT_EN_~${ASSETS_STATUS_TEXT_EN}~g" \
                    -e "s~_ASSETS_STATUS_TEXT_~${ASSETS_STATUS_TEXT}~g" \
                    -e "s~_RND_STATUS_TEXT_ES_~${RND_STATUS_TEXT_ES}~g" \
                    -e "s~_RND_STATUS_TEXT_EN_~${RND_STATUS_TEXT_EN}~g" \
                    -e "s~_RND_STATUS_TEXT_~${RND_STATUS_TEXT}~g" \
                    -e "s~_CASH_STATUS_~${CASH_STATUS}~g" \
                    -e "s~_ASSETS_STATUS_~${ASSETS_STATUS}~g" \
                    -e "s~_RND_STATUS_~${RND_STATUS}~g" \
                    -e "s~_IMPACT_LIST_FR_~${IMPACT_LIST_FR_SAFE}~g" \
                    -e "s~_IMPACT_LIST_EN_~${IMPACT_LIST_EN_SAFE}~g" \
                    -e "s~_NODE_PAYMENT_STATUS_FR_~${NODE_PAYMENT_STATUS_FR}~g" \
                    -e "s~_NODE_PAYMENT_STATUS_EN_~${NODE_PAYMENT_STATUS_EN}~g" \
                    -e "s~_CAPTAIN_PAYMENT_STATUS_FR_~${CAPTAIN_PAYMENT_STATUS_FR}~g" \
                    -e "s~_CAPTAIN_PAYMENT_STATUS_EN_~${CAPTAIN_PAYMENT_STATUS_EN}~g" \
                    -e "s~_NCARD_~${NCARD}~g" \
                    -e "s~_ZCARD_~${ZCARD}~g" \
                    -e "s~_IMPACT_10_MULTIPASS_~${IMPACT_10_MULTIPASS}~g" \
                    -e "s~_IMPACT_5_ZENCARDS_~${IMPACT_5_ZENCARDS}~g" \
                    > "$PRE_BANKRUPTCY_REPORT"
                
                # Send to Captain first
                if [[ -n "$CAPTAINEMAIL" ]]; then
                    ${MY_PATH}/../tools/mailjet.sh "$CAPTAINEMAIL" "$PRE_BANKRUPTCY_REPORT" "⚠️ UPlanet Pré-Faillite Phase $PRE_BANKRUPTCY_PHASE - $TODATE"
                    log_output "📧 Pre-bankruptcy alert sent to Captain: $CAPTAINEMAIL"
                fi
                
                # Send to all MULTIPASS users
                for player_dir in ~/.zen/game/nostr/*/; do
                    player_email=$(basename "$player_dir")
                    if [[ "$player_email" =~ @ && "$player_email" != "$CAPTAINEMAIL" ]]; then
                        ${MY_PATH}/../tools/mailjet.sh "$player_email" "$PRE_BANKRUPTCY_REPORT" "⚠️ UPlanet Pré-Faillite Phase $PRE_BANKRUPTCY_PHASE - $TODATE"
                        log_output "📧 Pre-bankruptcy alert sent to: $player_email"
                    fi
                done
            else
                log_output "⚠️ Pre-bankruptcy template not found: $PRE_BANKRUPTCY_TEMPLATE"
            fi
        fi
        
        #######################################################################
        # PAYMENT SUMMARY - Shareholder Transparency Report
        #######################################################################
        log_output ""
        log_output "╔══════════════════════════════════════════════════════════════════════╗"
        log_output "║              📊 WEEKLY PAYMENT SUMMARY - $WEEK_KEY                    "
        log_output "╠══════════════════════════════════════════════════════════════════════╣"
        log_output "║ DEGRADATION PHASE: $PRE_BANKRUPTCY_PHASE                              "
        case $PRE_BANKRUPTCY_PHASE in
            0) log_output "║ STATUS: ✅ NORMAL OPERATION                                          " ;;
            1) log_output "║ STATUS: ⚠️ GROWTH SLOWDOWN (ASSETS depleting)                        " ;;
            2) log_output "║ STATUS: ⚠️ INNOVATION SLOWDOWN (RnD depleting)                       " ;;
            3) log_output "║ STATUS: 💀 BANKRUPTCY (No funds available)                           " ;;
        esac
        log_output "╠══════════════════════════════════════════════════════════════════════╣"
        log_output "║ PAYMENTS:                                                             "
        if [[ $NODE_PAID -eq 1 ]]; then
            log_output "║   NODE:    ✅ $WEEKLYPAF Ẑen from $NODE_PAYMENT_SOURCE                  "
        else
            log_output "║   NODE:    ❌ NOT PAID - Infrastructure at risk!                        "
        fi
        if [[ $CAPTAIN_PAID -eq 1 ]]; then
            log_output "║   CAPTAIN: ✅ $CAPTAIN_REMUNERATION Ẑen from $CAPTAIN_PAYMENT_SOURCE    "
        else
            log_output "║   CAPTAIN: ❌ NOT PAID                                                  "
        fi
        log_output "╠══════════════════════════════════════════════════════════════════════╣"
        log_output "║ WALLET BALANCES (after payments):                                     "
        log_output "║   💰 CASH:   $CASH_ZEN Ẑen                                            "
        log_output "║   🌱 ASSETS: $ASSETS_ZEN Ẑen                                          "
        log_output "║   🔬 RnD:    $RND_ZEN Ẑen                                             "
        log_output "╚══════════════════════════════════════════════════════════════════════╝"
        log_output ""
        
        #######################################################################
        # DEPRECIATION: UPLANETNAME_CAPITAL → UPLANETNAME_AMORTISSEMENT
        # Linear depreciation over 3 years (156 weeks)
        # Compte 21 (Immobilisations) → Compte 28 (Amortissements)
        # 
        # NOTE: Amortissement n'est PAS du cash convertible en €
        # C'est une écriture comptable représentant la valeur "consommée"
        # Valeur Nette Comptable = CAPITAL - AMORTISSEMENT
        #######################################################################
        
        if [[ -s "$HOME/.zen/game/.env" ]] && [[ -s "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
            # Read machine capital configuration
            MACHINE_VALUE=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            CAPITAL_DATE=$(grep "^CAPITAL_DATE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            DEPRECIATION_WEEKS=$(grep "^DEPRECIATION_WEEKS=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            [[ -z $DEPRECIATION_WEEKS ]] && DEPRECIATION_WEEKS=156  # Default: 3 years
            
            # Initialize AMORTISSEMENT wallet if not exists
            if [[ ! -s "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" ]]; then
                log_output "📦 Creating UPLANETNAME_AMORTISSEMENT wallet (Compte 28)..."
                ${MY_PATH}/../tools/keygen -t duniter -o "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" "${UPLANETNAME}.AMORTISSEMENT" "${UPLANETNAME}.AMORTISSEMENT"
                chmod 600 "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey"
                # Initialize with 1Ğ1 for transaction capability
                AMORT_G1PUB=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.G1.dunikey" "1" "${AMORT_G1PUB}" "UP:${UPLANETG1PUB:0:8}:INIT:AMORT:1G1:GENESIS" 2>/dev/null
                log_output "✅ UPLANETNAME_AMORTISSEMENT initialized: ${AMORT_G1PUB:0:8}..."
            fi
            
            # Get AMORTISSEMENT wallet public key
            AMORT_G1PUB=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep "pub:" | cut -d ' ' -f 2)
            
            if [[ -n "$MACHINE_VALUE" ]] && [[ -n "$CAPITAL_DATE" ]] && [[ "$MACHINE_VALUE" != "0" ]]; then
                # Calculate weeks since capital date
                CAPITAL_TIMESTAMP=$(date -d "${CAPITAL_DATE:0:8}" +%s 2>/dev/null || echo "0")
                CURRENT_TIMESTAMP=$(date +%s)
                SECONDS_ELAPSED=$((CURRENT_TIMESTAMP - CAPITAL_TIMESTAMP))
                WEEKS_ELAPSED=$((SECONDS_ELAPSED / 604800))  # 604800 = 7*24*60*60
                
                log_output "📊 DEPRECIATION CHECK: Machine value=$MACHINE_VALUE Ẑen, Weeks elapsed=$WEEKS_ELAPSED/$DEPRECIATION_WEEKS"
                
                if [[ $WEEKS_ELAPSED -lt $DEPRECIATION_WEEKS ]]; then
                    # Calculate weekly depreciation amount
                    WEEKLY_DEPRECIATION=$(echo "scale=2; $MACHINE_VALUE / $DEPRECIATION_WEEKS" | bc -l)
                    WEEKLY_DEPRECIATION_G1=$(echo "scale=4; $WEEKLY_DEPRECIATION / 10" | bc -l)
                    
                    # Check CAPITAL wallet balance
                    CAPITAL_G1PUB=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                    CAPITAL_COIN=$(${MY_PATH}/../tools/G1check.sh ${CAPITAL_G1PUB} | tail -n 1)
                    CAPITAL_ZEN=$(echo "scale=1; ($CAPITAL_COIN - 1) * 10" | bc)
                    
                    # Calculate values for logging
                    TOTAL_DEPRECIATED=$(echo "scale=2; $WEEKLY_DEPRECIATION * $WEEKS_ELAPSED" | bc -l)
                    RESIDUAL_VALUE=$(echo "scale=2; $MACHINE_VALUE - $TOTAL_DEPRECIATED" | bc -l)
                    
                    # Get current AMORTISSEMENT balance
                    AMORT_COIN=$(${MY_PATH}/../tools/G1check.sh ${AMORT_G1PUB} | tail -n 1)
                    AMORT_ZEN=$(echo "scale=1; ($AMORT_COIN - 1) * 10" | bc)
                    
                    if [[ $(echo "$CAPITAL_ZEN >= $WEEKLY_DEPRECIATION" | bc -l) -eq 1 ]]; then
                        # Transfer depreciation from CAPITAL → AMORTISSEMENT (Compte 21 → Compte 28)
                        ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CAPITAL.dunikey" "$WEEKLY_DEPRECIATION_G1" "${AMORT_G1PUB}" "UP:${UPLANETG1PUB:0:8}:AMORT:W${CURRENT_WEEK}:${WEEKLY_DEPRECIATION}Z:C21>C28" 2>/dev/null
                        
                        if [[ $? -eq 0 ]]; then
                            NEW_AMORT_ZEN=$(echo "scale=2; $AMORT_ZEN + $WEEKLY_DEPRECIATION" | bc -l)
                            log_output "✅ DEPRECIATION: $WEEKLY_DEPRECIATION Ẑen → AMORTISSEMENT (Compte 28)"
                            log_output "   Valeur Brute (Compte 21): $MACHINE_VALUE Ẑen"
                            log_output "   Amortissements Cumulés (Compte 28): ~$NEW_AMORT_ZEN Ẑen"
                            log_output "   Valeur Nette Comptable: ~$RESIDUAL_VALUE Ẑen (après $WEEKS_ELAPSED semaines)"
                        else
                            log_output "⚠️  DEPRECIATION transfer failed - will retry next week"
                        fi
                    else
                        log_output "⚠️  CAPITAL wallet insufficient for depreciation ($CAPITAL_ZEN < $WEEKLY_DEPRECIATION Ẑen)"
                        log_output "   Expected residual value: $RESIDUAL_VALUE Ẑen - Capital fully amortized or underfunded"
                    fi
                else
                    log_output "📊 DEPRECIATION COMPLETE: Machine fully amortized after $DEPRECIATION_WEEKS weeks"
                    log_output "   Valeur Nette Comptable = 0 (machine peut être vendue à valeur résiduelle)"
                    # After full depreciation, CAPITAL wallet should be empty
                    # AMORTISSEMENT wallet contains total depreciated value
                fi
            fi
        fi
        
        #######################################################################
        # BANKRUPTCY ALERT - Send email to all users if triggered
        #######################################################################
        if [[ $BANKRUPTCY_TRIGGERED -eq 1 ]]; then
            log_output "🚨 BANKRUPTCY ALERT TRIGGERED - Sending notifications..."
            
            # Generate bankruptcy report
            BANKRUPTCY_TEMPLATE="${MY_PATH}/../templates/NOSTR/bankrupt.html"
            BANKRUPTCY_REPORT="$HOME/.zen/tmp/bankruptcy_alert_$(date +%Y-%m-%d).html"
            
            if [[ -s "$BANKRUPTCY_TEMPLATE" ]]; then
                REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
                TODATE=$(date +%Y-%m-%d)
                UPLANET_ID="${UPLANETG1PUB:0:8}"
                
                # Get current balances for report
                CASH_BALANCE=$CASH_ZEN
                [[ -z $NCARD ]] && NCARD=1
                [[ -z $ZCARD ]] && ZCARD=4
                [[ -z $TVA_RATE ]] && TVA_RATE=20
                [[ -z $IS_THRESHOLD ]] && IS_THRESHOLD=42500
                [[ -z $IS_RATE_REDUCED ]] && IS_RATE_REDUCED=15
                [[ -z $IS_RATE_NORMAL ]] && IS_RATE_NORMAL=25
                
                MIN_REQUIRED=$(echo "scale=2; $WEEKLYPAF + $CAPTAIN_REMUNERATION" | bc -l)
                TOTAL_ALLOCATIONS=0
                TOTAL_NEEDED=$MIN_REQUIRED
                TAX_RATE_USED=$IS_RATE_REDUCED
                DEFICIT=$(echo "scale=2; $TOTAL_PAF_REQUIRED - $CASH_ZEN" | bc -l)
                [[ $(echo "$DEFICIT < 0" | bc -l) -eq 1 ]] && DEFICIT="0.00"
                
                IMPACT_10_MULTIPASS=$(echo "scale=2; 10 * $NCARD" | bc -l)
                IMPACT_5_ZENCARDS=$(echo "scale=2; 5 * $ZCARD" | bc -l)
                IMPACT_TOTAL_REVENUE=$(echo "scale=2; $IMPACT_10_MULTIPASS + $IMPACT_5_ZENCARDS" | bc -l)
                
                SOCIETAIRE_SHARE_PRICE=50
                SOCIETAIRE_SHARE_PRICE_EUR=50
                SOCIETAIRE_CAPITAL=$(echo "scale=2; 10 * $SOCIETAIRE_SHARE_PRICE" | bc -l)
                
                # Get CAPITAL and AMORTISSEMENT wallet values for report
                CAPITAL_BALANCE="0"
                AMORT_BALANCE="0"
                MACHINE_VALUE_REPORT="0"
                DEPRECIATION_PERCENT="0"
                WEEKS_PASSED_REPORT="0"
                DEPRECIATION_WEEKS_REPORT="156"
                
                if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
                    CAPITAL_G1PUB_RPT=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                    CAPITAL_COIN_RPT=$(${MY_PATH}/../tools/G1check.sh ${CAPITAL_G1PUB_RPT} 2>/dev/null | tail -n 1)
                    CAPITAL_BALANCE=$(echo "scale=1; ($CAPITAL_COIN_RPT - 1) * 10" | bc 2>/dev/null || echo "0")
                    
                    # Get AMORTISSEMENT balance (Compte 28)
                    if [[ -f "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" ]]; then
                        AMORT_G1PUB_RPT=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                        AMORT_COIN_RPT=$(${MY_PATH}/../tools/G1check.sh ${AMORT_G1PUB_RPT} 2>/dev/null | tail -n 1)
                        AMORT_BALANCE=$(echo "scale=1; ($AMORT_COIN_RPT - 1) * 10" | bc 2>/dev/null || echo "0")
                    fi
                    
                    # Read config values from .env (MACHINE_VALUE_ZEN)
                    MACHINE_VALUE_REPORT="${MACHINE_VALUE_ZEN:-0}"
                    DEPRECIATION_WEEKS_REPORT="${DEPRECIATION_WEEKS:-156}"
                    DEPRECIATION_PERCENT="0"
                fi
                
                # Build failed allocations list
                FAILED_ALLOCATIONS=""
                [[ $NODE_PAID -eq 0 ]] && FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>NODE PAF: ${WEEKLYPAF} Ẑen</li>"
                [[ $CAPTAIN_PAID -eq 0 ]] && FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>Captain Remuneration: ${CAPTAIN_REMUNERATION} Ẑen</li>"
                
                # Generate report from template
                cat "$BANKRUPTCY_TEMPLATE" | sed \
                    -e "s~_DATE_~${REPORT_DATE}~g" \
                    -e "s~_TODATE_~${TODATE}~g" \
                    -e "s~_UPLANET_ID_~${UPLANET_ID}~g" \
                    -e "s~_CASH_BALANCE_~${CASH_BALANCE}~g" \
                    -e "s~_PAF_~${WEEKLYPAF}~g" \
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
                    -e "s~_FAILED_ALLOCATIONS_~${FAILED_ALLOCATIONS}~g" \
                    -e "s~_CAPITAL_BALANCE_~${CAPITAL_BALANCE}~g" \
                    -e "s~_AMORT_BALANCE_~${AMORT_BALANCE}~g" \
                    -e "s~_MACHINE_VALUE_~${MACHINE_VALUE_REPORT}~g" \
                    -e "s~_DEPRECIATION_PERCENT_~${DEPRECIATION_PERCENT}~g" \
                    -e "s~_WEEKS_PASSED_~${WEEKS_PASSED_REPORT}~g" \
                    -e "s~_DEPRECIATION_WEEKS_~${DEPRECIATION_WEEKS_REPORT}~g" \
                    > "$BANKRUPTCY_REPORT"
                
                # Send to Captain
                if [[ -n "$CAPTAINEMAIL" ]]; then
                    ${MY_PATH}/../tools/mailjet.sh "$CAPTAINEMAIL" "$BANKRUPTCY_REPORT" "⚠️ UPlanet BANKRUPTCY ALERT - $TODATE"
                    log_output "📧 Bankruptcy alert sent to Captain: $CAPTAINEMAIL"
                fi
                
                # Send to all MULTIPASS users
                for player_dir in ~/.zen/game/nostr/*/; do
                    player_email=$(basename "$player_dir")
                    if [[ "$player_email" =~ @ && "$player_email" != "$CAPTAINEMAIL" ]]; then
                        ${MY_PATH}/../tools/mailjet.sh "$player_email" "$BANKRUPTCY_REPORT" "⚠️ UPlanet BANKRUPTCY ALERT - $TODATE"
                        log_output "📧 Bankruptcy alert sent to: $player_email"
                    fi
                done
            else
                log_output "⚠️  Bankruptcy template not found: $BANKRUPTCY_TEMPLATE"
            fi
        fi
        
    else
        log_output "NODE $NODECOIN G1 is NOT INITIALIZED !! UPlanet send 1 G1 to NODE"
        # TX Comment: UP:NetworkID:INIT:IPFSNodeID:Amount (Node wallet activation)
        # First-time activation of NODE wallet with 1 G1 to enable transactions
        ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.G1.dunikey" "1" "${NODEG1PUB}" "UP:${UPLANETG1PUB:0:8}:INIT:${IPFSNODEID:0:8}:1G1:GENESIS" 2>/dev/null
    fi
fi

#######################################################################
# PAF BURN & CONVERSION - 4-week operational cost management
# Burn 4-week accumulated PAF from NODE back to UPLANETNAME_G1 and request € conversion
# This creates a deflationary mechanism and enables real € payment for costs
#######################################################################
fourweeks_paf_burn_and_convert() {
    # Calculate current 4-week period (based on week number)
    local current_week=$(date +%V)
    local current_year=$(date +%Y)
    local period_number=$(( (current_week - 1) / 4 + 1 ))
    local period_key="${current_year}-P${period_number}"
    local burn_marker="$HOME/.zen/game/.fourweeks_paf_burn.$period_key"
    
    # Detect station level (X or Y) like DRAGON_p2p_ssh.sh
    local station_level="X"
    if [[ -s ~/.ssh/id_ed25519.pub ]]; then
        local YIPNS=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
        if [[ ${IPFSNODEID} == ${YIPNS} ]]; then
            station_level="Y"
            log_output "ZEN ECONOMY: Station Level Y detected (SSH/IPFS transmuted)"
        else
            log_output "ZEN ECONOMY: Station Level X detected (SSH/IPFS not linked)"
            log_output "ZEN ECONOMY: ${YIPNS} != ${IPFSNODEID}"
        fi
    else
        log_output "ZEN ECONOMY: Station Level X detected (no SSH key found)"
    fi
    
    # Check if burn was already done for this 4-week period
    if [[ -f "$burn_marker" ]]; then
        log_output "ZEN ECONOMY: 4-week PAF burn already completed for period $period_key"
        return 0
    fi
    
    # Only burn if NODE has sufficient balance and received PAF
    if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 && $(echo "$NODEZEN > 0" | bc -l) -eq 1 ]]; then
        # Calculate 4-week PAF (weekly PAF * 4)
        FOURWEEKS_PAF=$(echo "scale=2; $WEEKLYPAF * 4" | bc -l)
        FOURWEEKS_PAF_G1=$(makecoord $(echo "$FOURWEEKS_PAF / 10" | bc -l))
        
        # Check if NODE has enough for 4-week burn
        if [[ $(echo "$NODEZEN >= $FOURWEEKS_PAF" | bc -l) -eq 1 ]]; then
            log_output "ZEN ECONOMY: Processing 4-week PAF burn..."
            log_output "  Period: $period_key (4-week cycle)"
            log_output "  4-week PAF: $FOURWEEKS_PAF Ẑen ($FOURWEEKS_PAF_G1 G1)"
            log_output "  From: NODE (operational costs)"
            log_output "  To: UPLANETNAME_G1 (burn & convert)"
            
            # Burn: NODE → UPLANETNAME_G1
            # Check station level and use appropriate method
            if [[ "$station_level" == "Y" && -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
                # Level Y: Use existing NODE wallet
                log_output "ZEN ECONOMY: Using NODE wallet (Level Y): $HOME/.zen/game/secret.NODE.dunikey"
                # TX Comment: UP:NetworkID:BURN:Period:Amount:Source (Deflationary mechanism)
                # 4-week accumulated PAF burned to enable EUR conversion via OpenCollective
                ${MY_PATH}/../tools/PAYforSURE.sh \
                    "$HOME/.zen/game/secret.NODE.dunikey" \
                    "$FOURWEEKS_PAF_G1" \
                    "${UPLANETG1PUB}" \
                    "UP:${UPLANETG1PUB:0:8}:BURN:${period_key}:${FOURWEEKS_PAF}Z:NODE>DEFLATE" \
                    2>/dev/null
            elif [[ "$station_level" == "X" ]]; then
                # Level X: Use CAPTAIN MULTIPASS as burn source (no NODE wallet available)
                log_output "ZEN ECONOMY: Level X - Using CAPTAIN MULTIPASS for PAF burn (no NODE wallet available)"
                # For Level X stations, use CAPTAIN MULTIPASS as burn source
                if [[ -n "$CAPTAINEMAIL" && -f "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" ]]; then
                    # TX Comment: UP:NetworkID:BURN:Period:Amount:Source (Level X fallback)
                    # Level X stations use Captain wallet instead of NODE wallet for burn
                    ${MY_PATH}/../tools/PAYforSURE.sh \
                        "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" \
                        "$FOURWEEKS_PAF_G1" \
                        "${UPLANETG1PUB}" \
                        "UP:${UPLANETG1PUB:0:8}:BURN:${period_key}:${FOURWEEKS_PAF}Z:CPT>DEFLATE_LvX" \
                        2>/dev/null
                else
                    log_output "ZEN ECONOMY: Level X - No CAPTAIN MULTIPASS available for PAF burn"
                    return 1
                fi
            else
                log_output "ZEN ECONOMY: Unknown station level or missing NODE wallet"
                return 1
            fi
            
            if [[ $? -eq 0 ]]; then
                log_output "✅ 4-week PAF burn completed: $FOURWEEKS_PAF Ẑen"
                
                # Request OpenCollective conversion (1Ẑ = 1€)
                request_opencollective_conversion "$FOURWEEKS_PAF" "$period_key"
                
                # Mark burn as completed
                echo "$(date -u +%Y%m%d%H%M%S) FOURWEEKS_PAF_BURN $FOURWEEKS_PAF ZEN NODE $period_key" > "$burn_marker"
                chmod 600 "$burn_marker"
            else
                log_output "❌ 4-week PAF burn failed"
            fi
        else
            log_output "ZEN ECONOMY: Insufficient NODE balance for 4-week PAF burn"
            log_output "  Required: $FOURWEEKS_PAF Ẑen"
            log_output "  Available: $NODEZEN Ẑen"
        fi
    else
        log_output "ZEN ECONOMY: NODE not ready for PAF burn (balance: $NODEZEN Ẑen)"
    fi
}

# Function to request OpenCollective conversion using GraphQL API (recommended)
# Conforms to https://docs.opencollective.com/help/contributing/development/api
request_opencollective_conversion() {
    local zen_amount="$1"
    local period="${2:-$(date +%Y%m%d)}"
    local euro_amount=$(echo "scale=2; $zen_amount * 1" | bc -l)  # 1Ẑ = 1€
    local euro_cents=$(echo "$euro_amount * 100" | bc | cut -d. -f1)
    
    log_output "ZEN ECONOMY: Requesting OpenCollective conversion..."
    log_output "  Amount: $zen_amount Ẑen → $euro_amount €"
    log_output "  Period: $period"
    
    # Try to get token from cooperative DID config first (encrypted in NOSTR)
    local OC_TOKEN=""
    if type coop_config_get &>/dev/null; then
        OC_TOKEN=$(coop_config_get "OPENCOLLECTIVE_PERSONAL_TOKEN" 2>/dev/null || echo "")
    fi
    # Fallback to environment variable (legacy support)
    [[ -z "$OC_TOKEN" ]] && OC_TOKEN="${OPENCOLLECTIVE_PERSONAL_TOKEN:-}"
    
    # Check if OpenCollective Personal Token is configured (GraphQL API)
    if [[ -n "$OC_TOKEN" ]]; then
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
            -H "Personal-Token: $OC_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$graphql_query" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$response" ]]; then
            # Check for GraphQL errors
            local errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
            if [[ -n "$errors" && "$errors" != "null" ]]; then
                log_output "⚠️  OpenCollective GraphQL API errors:"
                echo "$errors" | jq -r '.[] | "  - \(.message)"' 2>/dev/null | tee -a "$LOG_FILE" || log_output "$errors"
            else
                local expense_id=$(echo "$response" | jq -r '.data.createExpense.id // empty' 2>/dev/null)
                if [[ -n "$expense_id" ]]; then
                    log_output "✅ OpenCollective expense created: $euro_amount €"
                    log_output "   Expense ID: $expense_id"
                    log_output "   Reference: BURN:PAF:$period:${zen_amount}ZEN"
                else
                    log_output "⚠️  Unexpected response format:"
                    echo "$response" | head -c 200 | tee -a "$LOG_FILE"
                fi
            fi
        else
            log_output "⚠️  OpenCollective GraphQL API request failed"
        fi
    elif [[ -n "$OPENCOLLECTIVE_API_KEY" ]]; then
        # Fallback to REST API (deprecated but still supported)
        log_output "⚠️  Using deprecated REST API (configure OPENCOLLECTIVE_PERSONAL_TOKEN for GraphQL)"
        
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
            log_output "✅ OpenCollective REST expense created: $euro_amount €"
            echo "   Response: $response" | head -c 100 | tee -a "$LOG_FILE"
        else
            log_output "⚠️  OpenCollective REST API request failed"
        fi
    else
        log_output "⚠️  No OpenCollective credentials configured"
        log_output "   Configure via cooperative DID (recommended - encrypted & shared):"
        log_output "     source ~/.zen/Astroport.ONE/tools/cooperative_config.sh"
        log_output "     coop_config_set OPENCOLLECTIVE_PERSONAL_TOKEN \"your_token\""
        log_output "   Legacy: Set OPENCOLLECTIVE_PERSONAL_TOKEN or OPENCOLLECTIVE_API_KEY"
        log_output "   Manual conversion needed: $zen_amount Ẑen → $euro_amount €"
        
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
log_output "ZEN ECONOMY: Checking primal wallet control for cooperative wallets..."

# Define cooperative wallets to protect
declare -A COOPERATIVE_WALLETS=(
    ["UPLANETNAME"]="$HOME/.zen/game/uplanet.dunikey"
    ["UPLANETNAME_SOCIETY"]="$HOME/.zen/game/uplanet.SOCIETY.dunikey"
    ["UPLANETNAME_CASH"]="$HOME/.zen/game/uplanet.CASH.dunikey"
    ["UPLANETNAME_RND"]="$HOME/.zen/game/uplanet.RnD.dunikey"
    ["UPLANETNAME_ASSETS"]="$HOME/.zen/game/uplanet.ASSETS.dunikey"
    ["UPLANETNAME_IMPOT"]="$HOME/.zen/game/uplanet.IMPOT.dunikey"
    ["UPLANETNAME.CAPTAIN"]="$HOME/.zen/game/uplanet.captain.dunikey"
    ["UPLANETNAME_INTRUSION"]="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
    ["UPLANETNAME_CAPITAL"]="$HOME/.zen/game/uplanet.CAPITAL.dunikey"
    ["UPLANETNAME_AMORTISSEMENT"]="$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey"
    ["NODE"]="$HOME/.zen/game/secret.NODE.dunikey"
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
            log_output "ZEN ECONOMY: Checking primal control for $wallet_name (${wallet_pubkey:0:8}...)"
            
            # Run primal wallet control for this cooperative wallet
            if [[ ${UPLANETNAME} != "EnfinLibre" ]]; then
                log_output "CONTROL UPLANET ZEN - Cooperative wallet primal control"
                ${MY_PATH}/../tools/primal_wallet_control.sh \
                    "$wallet_dunikey" \
                    "$wallet_pubkey" \
                    "$COOPERATIVE_MASTER_PRIMAL" \
                    "$COOPERATIVE_ADMIN_EMAIL"
                    
                if [[ $? -eq 0 ]]; then
                    log_output "ZEN ECONOMY: ✅ Primal control OK for $wallet_name"
                else
                    log_output "ZEN ECONOMY: ⚠️  Primal control issues detected for $wallet_name"
                fi
            else
                log_output "UPlanet ORIGIN - No Control -"
            fi
        else
            log_output "ZEN ECONOMY: ⚠️  Could not extract public key from $wallet_name"
        fi
    else
        log_output "ZEN ECONOMY: ⚠️  Wallet file not found: $wallet_name ($wallet_dunikey)"
    fi
done

log_output "ZEN ECONOMY: Primal wallet control completed for all cooperative wallets"

#######################################################################
# Cooperative allocation check - trigger 3x1/3 allocation if conditions are met
# This will be executed after PAF payment to ensure proper economic flow
#######################################################################
log_output "ZEN ECONOMY: Checking cooperative allocation conditions..."
${MY_PATH}/ZEN.COOPERATIVE.3x1-3.sh

#######################################################################
# Mark weekly payment as completed
# Create marker file with current week to prevent duplicate payments
# Include degradation phase for tracking
#######################################################################
echo "$WEEK_KEY:PHASE${PRE_BANKRUPTCY_PHASE:-0}:NODE${NODE_PAID:-0}:CPT${CAPTAIN_PAID:-0}" > "$PAYMENT_MARKER"
log_output "ZEN ECONOMY: Weekly payment completed and marked for week $WEEK_KEY (Phase ${PRE_BANKRUPTCY_PHASE:-0})"
log_output "========================================================================"

# Exit code reflects system health:
# 0 = Normal operation (Phase 0)
# 1 = Pre-bankruptcy Phase 1 (ASSETS used)
# 2 = Pre-bankruptcy Phase 2 (RnD used)
# 3 = Bankruptcy (GAME OVER)
exit ${PRE_BANKRUPTCY_PHASE:-0}
