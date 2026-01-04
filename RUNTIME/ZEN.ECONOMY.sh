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
        # BANKRUPTCY RECOVERY CASCADE
        # If CASH is insufficient, try to recover from other wallets:
        # 1. ASSETS → CASH (cooperative can't grow anymore)
        # 2. RnD → CASH (cooperative can't pay its actors)
        # 3. If NODE can't be paid = GAME OVER
        #######################################################################
        
        BANKRUPTCY_TRIGGERED=0
        CAPTAIN_PAID=0
        NODE_PAID=0
        
        # First, check if we need to trigger recovery cascade
        if [[ $(echo "$CASH_ZEN < $TOTAL_PAF_REQUIRED" | bc -l) -eq 1 ]]; then
            log_output "🚨 CASH insufficient ($CASH_ZEN Ẑen < $TOTAL_PAF_REQUIRED Ẑen required)"
            
            DEFICIT=$(echo "scale=2; $TOTAL_PAF_REQUIRED - $CASH_ZEN" | bc -l)
            DEFICIT_G1=$(echo "scale=4; $DEFICIT / 10" | bc -l)
            log_output "   Deficit: $DEFICIT Ẑen"
            
            ## STEP 1: Try to recover from ASSETS (cooperative can't grow anymore)
            if [[ -s ~/.zen/game/uplanet.ASSETS.dunikey ]]; then
                ASSETS_G1PUB=$(cat ~/.zen/game/uplanet.ASSETS.dunikey | grep "pub:" | cut -d ' ' -f 2)
                ASSETS_COIN=$(${MY_PATH}/../tools/G1check.sh ${ASSETS_G1PUB} | tail -n 1)
                ASSETS_ZEN=$(echo "scale=1; ($ASSETS_COIN - 1) * 10" | bc)
                
                if [[ $(echo "$ASSETS_ZEN > 0" | bc -l) -eq 1 ]]; then
                    # Transfer from ASSETS to CASH
                    TRANSFER_AMOUNT=$DEFICIT
                    if [[ $(echo "$ASSETS_ZEN < $DEFICIT" | bc -l) -eq 1 ]]; then
                        TRANSFER_AMOUNT=$ASSETS_ZEN
                    fi
                    TRANSFER_G1=$(echo "scale=4; $TRANSFER_AMOUNT / 10" | bc -l)
                    
                    log_output "🔄 RECOVERY: Transferring $TRANSFER_AMOUNT Ẑen from ASSETS to CASH"
                    ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.ASSETS.dunikey "$TRANSFER_G1" "${CASH_G1PUB}" "UP:${UPLANETG1PUB:0:8}:RECOVERY:ASSETS>CASH:${TRANSFER_AMOUNT}Z" 2>/dev/null
                    
                    # Update CASH balance
                    CASH_ZEN=$(echo "scale=1; $CASH_ZEN + $TRANSFER_AMOUNT" | bc)
                    DEFICIT=$(echo "scale=2; $TOTAL_PAF_REQUIRED - $CASH_ZEN" | bc -l)
                    log_output "   CASH after ASSETS recovery: $CASH_ZEN Ẑen (deficit: $DEFICIT Ẑen)"
                    BANKRUPTCY_TRIGGERED=1
                fi
            fi
            
            ## STEP 2: If still insufficient, try RnD (cooperative can't pay its actors)
            if [[ $(echo "$CASH_ZEN < $TOTAL_PAF_REQUIRED" | bc -l) -eq 1 ]]; then
                if [[ -s ~/.zen/game/uplanet.RnD.dunikey ]]; then
                    RND_G1PUB=$(cat ~/.zen/game/uplanet.RnD.dunikey | grep "pub:" | cut -d ' ' -f 2)
                    RND_COIN=$(${MY_PATH}/../tools/G1check.sh ${RND_G1PUB} | tail -n 1)
                    RND_ZEN=$(echo "scale=1; ($RND_COIN - 1) * 10" | bc)
                    
                    if [[ $(echo "$RND_ZEN > 0" | bc -l) -eq 1 ]]; then
                        DEFICIT=$(echo "scale=2; $TOTAL_PAF_REQUIRED - $CASH_ZEN" | bc -l)
                        TRANSFER_AMOUNT=$DEFICIT
                        if [[ $(echo "$RND_ZEN < $DEFICIT" | bc -l) -eq 1 ]]; then
                            TRANSFER_AMOUNT=$RND_ZEN
                        fi
                        TRANSFER_G1=$(echo "scale=4; $TRANSFER_AMOUNT / 10" | bc -l)
                        
                        log_output "🔄 RECOVERY: Transferring $TRANSFER_AMOUNT Ẑen from RnD to CASH"
                        ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.RnD.dunikey "$TRANSFER_G1" "${CASH_G1PUB}" "UP:${UPLANETG1PUB:0:8}:RECOVERY:RND>CASH:${TRANSFER_AMOUNT}Z" 2>/dev/null
                        
                        # Update CASH balance
                        CASH_ZEN=$(echo "scale=1; $CASH_ZEN + $TRANSFER_AMOUNT" | bc)
                        log_output "   CASH after RnD recovery: $CASH_ZEN Ẑen"
                        BANKRUPTCY_TRIGGERED=1
                    fi
                fi
            fi
        fi
        
        #######################################################################
        # PAYMENT PRIORITY: NODE first (infrastructure), then Captain (salary)
        #######################################################################
        
        ## PRIORITY 1: Pay NODE (1x PAF) - Infrastructure is critical
        if [[ $(echo "$CASH_ZEN >= $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CASH.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UP:${UPLANETG1PUB:0:8}:PAF:W${CURRENT_WEEK}:${WEEKLYPAF}Z:CASH>NODE" 2>/dev/null
            log_output "✅ CASH paid weekly PAF to NODE (Armateur): $WEEKLYPAF ZEN ($WEEKLYG1 G1)"
            NODE_PAID=1
            CASH_ZEN=$(echo "scale=1; $CASH_ZEN - $WEEKLYPAF" | bc)
        else
            ## GAME OVER - NODE cannot be paid, infrastructure cannot function
            log_output "💀 GAME OVER: Cannot pay NODE PAF - Infrastructure cannot function!"
            log_output "   Required: $WEEKLYPAF Ẑen, Available: $CASH_ZEN Ẑen"
            BANKRUPTCY_TRIGGERED=1
        fi
        
        ## PRIORITY 2: Pay Captain (2x PAF) - Only if enough funds remain
        CAPTAIN_REMUNERATION=$(echo "scale=2; $WEEKLYPAF * 2" | bc -l)
        CAPTAIN_REMUNERATION_G1=$(makecoord $(echo "$CAPTAIN_REMUNERATION / 10" | bc -l))
        
        if [[ $NODE_PAID -eq 1 && $(echo "$CASH_ZEN >= $CAPTAIN_REMUNERATION" | bc -l) -eq 1 ]]; then
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CASH.dunikey" "$CAPTAIN_REMUNERATION_G1" "${CAPTAING1PUB}" "UP:${UPLANETG1PUB:0:8}:SALARY:W${CURRENT_WEEK}:${CAPTAIN_REMUNERATION}Z:CASH>CPT_MP" 2>/dev/null
            log_output "✅ CASH paid weekly remuneration to CAPTAIN MULTIPASS: $CAPTAIN_REMUNERATION ZEN ($CAPTAIN_REMUNERATION_G1 G1)"
            CAPTAIN_PAID=1
        else
            log_output "⚠️  CAPTAIN NOT PAID: Insufficient CASH for Captain remuneration"
            log_output "   Required: $CAPTAIN_REMUNERATION Ẑen, Available: $CASH_ZEN Ẑen"
            BANKRUPTCY_TRIGGERED=1
        fi
        
        #######################################################################
        # DEPRECIATION: UPLANETNAME_CAPITAL → CASH (Weekly machine amortization)
        # Linear depreciation over 3 years (156 weeks)
        # Compte 21 (Immobilisations) → Compte 512 (Banque/Trésorerie)
        #######################################################################
        
        if [[ -s "$HOME/.zen/game/.env" ]] && [[ -s "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
            # Read machine capital configuration
            MACHINE_VALUE=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            CAPITAL_DATE=$(grep "^CAPITAL_DATE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            DEPRECIATION_WEEKS=$(grep "^DEPRECIATION_WEEKS=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            [[ -z $DEPRECIATION_WEEKS ]] && DEPRECIATION_WEEKS=156  # Default: 3 years
            
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
                    
                    # Calculate residual value for logging
                    TOTAL_DEPRECIATED=$(echo "scale=2; $WEEKLY_DEPRECIATION * $WEEKS_ELAPSED" | bc -l)
                    RESIDUAL_VALUE=$(echo "scale=2; $MACHINE_VALUE - $TOTAL_DEPRECIATED" | bc -l)
                    
                    if [[ $(echo "$CAPITAL_ZEN >= $WEEKLY_DEPRECIATION" | bc -l) -eq 1 ]]; then
                        # Transfer depreciation from CAPITAL → CASH
                        ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CAPITAL.dunikey" "$WEEKLY_DEPRECIATION_G1" "${CASH_G1PUB}" "UP:${UPLANETG1PUB:0:8}:DEPREC:W${CURRENT_WEEK}:${WEEKLY_DEPRECIATION}Z:CAP>CASH" 2>/dev/null
                        
                        if [[ $? -eq 0 ]]; then
                            log_output "✅ DEPRECIATION: $WEEKLY_DEPRECIATION Ẑen transferred from CAPITAL to CASH"
                            log_output "   Residual machine value: $RESIDUAL_VALUE Ẑen (after $WEEKS_ELAPSED weeks)"
                        else
                            log_output "⚠️  DEPRECIATION transfer failed - will retry next week"
                        fi
                    else
                        log_output "⚠️  CAPITAL wallet insufficient for depreciation ($CAPITAL_ZEN < $WEEKLY_DEPRECIATION Ẑen)"
                        log_output "   Expected residual value: $RESIDUAL_VALUE Ẑen - Capital fully amortized or underfunded"
                    fi
                else
                    log_output "📊 DEPRECIATION COMPLETE: Machine fully amortized after $DEPRECIATION_WEEKS weeks"
                    # After full depreciation, CAPITAL wallet should be empty
                    # Residual value = 0, machine can only be sold for scrap value
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
                
                # Get CAPITAL wallet values for report
                CAPITAL_BALANCE="0"
                MACHINE_VALUE_REPORT="0"
                DEPRECIATION_PERCENT="0"
                WEEKS_PASSED_REPORT="0"
                DEPRECIATION_WEEKS_REPORT="156"
                
                if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
                    CAPITAL_G1PUB_RPT=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                    CAPITAL_COIN_RPT=$(${MY_PATH}/../tools/G1check.sh ${CAPITAL_G1PUB_RPT} 2>/dev/null | tail -n 1)
                    CAPITAL_BALANCE=$(echo "scale=1; ($CAPITAL_COIN_RPT - 1) * 10" | bc 2>/dev/null || echo "0")
                    
                    # Read config values
                    if [[ -f "$HOME/.zen/game/uplanet.conf" ]]; then
                        MACHINE_VALUE_REPORT=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/uplanet.conf" | cut -d'=' -f2 || echo "0")
                        CAPITAL_DATE_RPT=$(grep "^CAPITAL_DATE=" "$HOME/.zen/game/uplanet.conf" | cut -d'=' -f2 || echo "")
                        DEPRECIATION_WEEKS_REPORT=$(grep "^DEPRECIATION_WEEKS=" "$HOME/.zen/game/uplanet.conf" | cut -d'=' -f2 || echo "156")
                        
                        if [[ -n "$CAPITAL_DATE_RPT" && $(echo "$DEPRECIATION_WEEKS_REPORT > 0" | bc -l) -eq 1 ]]; then
                            CAPITAL_TIMESTAMP_RPT=$(date -d "$CAPITAL_DATE_RPT" +%s 2>/dev/null || echo "0")
                            CURRENT_TIMESTAMP_RPT=$(date +%s)
                            SECONDS_IN_WEEK=$((7 * 24 * 60 * 60))
                            WEEKS_PASSED_REPORT=$(( (CURRENT_TIMESTAMP_RPT - CAPITAL_TIMESTAMP_RPT) / SECONDS_IN_WEEK ))
                            [[ $WEEKS_PASSED_REPORT -lt 0 ]] && WEEKS_PASSED_REPORT=0
                            DEPRECIATION_PERCENT=$(echo "scale=1; ($WEEKS_PASSED_REPORT * 100) / $DEPRECIATION_WEEKS_REPORT" | bc -l 2>/dev/null || echo "0")
                            [[ $(echo "$DEPRECIATION_PERCENT > 100" | bc -l) -eq 1 ]] && DEPRECIATION_PERCENT="100"
                        fi
                    fi
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
        log_output "   Configure OPENCOLLECTIVE_PERSONAL_TOKEN (GraphQL) or OPENCOLLECTIVE_API_KEY (REST)"
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
#######################################################################
echo "$WEEK_KEY" > "$PAYMENT_MARKER"
log_output "ZEN ECONOMY: Weekly payment completed and marked for week $WEEK_KEY"
log_output "========================================================================"

exit 0
