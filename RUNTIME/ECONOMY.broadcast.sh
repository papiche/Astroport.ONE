#!/bin/bash
################################################################################
# ECONOMY.broadcast.sh - Broadcast Economic Health to NOSTR Constellation
# 
# Publishes a kind:30850 event containing the station's economic health data.
# This enables swarm-level economic visibility and legal compliance reporting.
#
# Part of NIP-101 Economic Health Extension 
# https://github.com/papiche/nostr-nips/blob/main/101-economic-health-extension.md
#
# Usage: ./ECONOMY.broadcast.sh [--dryrun] [--verbose]
#
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Source environment
. "${MY_PATH}/../tools/my.sh"
# Load cooperative config from DID NOSTR (shared across swarm)
. "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null && coop_load_env_vars 2>/dev/null || true

# Parse arguments
DRYRUN=false
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dryrun) DRYRUN=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--dryrun] [--verbose]"
            echo "Broadcasts economic health data as NOSTR event (kind 30850)"
            exit 0
            ;;
        *) shift ;;
    esac
done

# Logging
log_output() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

log_output "📊 Starting ECONOMY.broadcast.sh..."

###############################################################################
# PREREQUISITES CHECK
###############################################################################

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo "❌ jq is required but not installed"
    exit 1
fi

# strfry relay is used for publishing

# Check Captain credentials
# Captain's NOSTR secret is in ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
if [[ -z "$CAPTAINEMAIL" ]]; then
    CAPTAINEMAIL=$(cat "$HOME/.zen/game/players/.current/.player" 2>/dev/null)
fi

CAPTAIN_NOSTR_SECRET="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
if [[ ! -s "$CAPTAIN_NOSTR_SECRET" ]]; then
    echo "❌ Captain NOSTR credentials not found: $CAPTAIN_NOSTR_SECRET"
    exit 1
fi

# Get NOSTR HEX from Captain
CAPTAIN_HEX=$(cat "$HOME/.zen/game/nostr/$CAPTAINEMAIL/HEX" 2>/dev/null)
if [[ -z "$CAPTAIN_HEX" ]]; then
    echo "❌ Cannot determine Captain HEX pubkey"
    exit 1
fi

log_output "✅ Captain HEX: ${CAPTAIN_HEX:0:8}..."

###############################################################################
# COLLECT ECONOMIC DATA
###############################################################################

# Event identifier (replaceable event per station)
EVENT_D="economic-health"
# Tag week courant (ISO 8601 : YYYY-WXX) — lu par economy.Swarm.html
CURRENT_WEEK="$(date -u +%Y-W%V)"
log_output "📅 Publishing economic health report (week $CURRENT_WEEK)"

# Normalize bc output: ensure leading zero for decimals (e.g., .25 -> 0.25)
# This is required for valid JSON output
normalize_number() {
    local num="$1"
    # Handle empty or null
    [[ -z "$num" ]] && echo "0" && return
    # Add leading zero if starts with .
    if [[ "$num" == .* ]]; then
        echo "0$num"
    # Add leading zero if starts with -.
    elif [[ "$num" == -.* ]]; then
        echo "-0${num:1}"
    else
        echo "$num"
    fi
}

# Get wallet balance (G1check.sh handles caching internally)
get_wallet_balance() {
    local pubkey="$1"
    ${MY_PATH}/../tools/G1check.sh "$pubkey" 2>/dev/null | tail -n 1 || echo "0"
}

convert_to_zen() {
    local g1_balance="$1"
    if [[ $(echo "$g1_balance > 1" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        normalize_number "$(echo "scale=2; ($g1_balance - 1) * 10" | bc -l 2>/dev/null)"
    else
        echo "0"
    fi
}

# Get all wallet balances
log_output "💰 Collecting wallet balances..."

# G1 Reserve
G1_RESERVE_G1=$(get_wallet_balance "$UPLANETNAME_G1")
G1_RESERVE_ZEN=$(convert_to_zen "$G1_RESERVE_G1")

# CASH (Treasury)
CASH_PUBKEY=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
CASH_G1=$(get_wallet_balance "$CASH_PUBKEY")
CASH_ZEN=$(convert_to_zen "$CASH_G1")

# RnD
RND_PUBKEY=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
RND_G1=$(get_wallet_balance "$RND_PUBKEY")
RND_ZEN=$(convert_to_zen "$RND_G1")

# ASSETS
ASSETS_PUBKEY=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
ASSETS_G1=$(get_wallet_balance "$ASSETS_PUBKEY")
ASSETS_ZEN=$(convert_to_zen "$ASSETS_G1")

# IMPOT
IMPOT_PUBKEY=$(cat "$HOME/.zen/game/uplanet.IMPOT.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
IMPOT_G1=$(get_wallet_balance "$IMPOT_PUBKEY")
IMPOT_ZEN=$(convert_to_zen "$IMPOT_G1")

# CAPITAL
CAPITAL_PUBKEY=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
CAPITAL_G1=$(get_wallet_balance "$CAPITAL_PUBKEY")
CAPITAL_ZEN=$(convert_to_zen "$CAPITAL_G1")

# AMORTISSEMENT
AMORT_PUBKEY=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
AMORT_G1=$(get_wallet_balance "$AMORT_PUBKEY")
AMORT_ZEN=$(convert_to_zen "$AMORT_G1")

# NODE
NODE_PUBKEY=$(cat "$HOME/.zen/game/secret.NODE.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
NODE_G1=$(get_wallet_balance "$NODE_PUBKEY")
NODE_ZEN=$(convert_to_zen "$NODE_G1")

# CAPTAIN DEDICATED
CAPTAIN_DED_PUBKEY=$(cat "$HOME/.zen/game/uplanet.captain.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
CAPTAIN_DED_G1=$(get_wallet_balance "$CAPTAIN_DED_PUBKEY")
CAPTAIN_DED_ZEN=$(convert_to_zen "$CAPTAIN_DED_G1")

log_output "  CASH: $CASH_ZEN Ẑ | RND: $RND_ZEN Ẑ | ASSETS: $ASSETS_ZEN Ẑ"

###############################################################################
# COLLECT CAPACITY DATA
###############################################################################

log_output "📈 Collecting capacity data..."

# Count MULTIPASS users (only directories with "@" in the name)
MULTIPASS_COUNT=0
if [[ -d "$HOME/.zen/game/nostr" ]]; then
    MULTIPASS_COUNT=$(find "$HOME/.zen/game/nostr" -maxdepth 1 -type d -name '*@*' | wc -l)
fi

# Count ZEN Card users - distinguish between RENTERS and OWNERS (sociétaires)
# - RENTERS (locataires): No U.SOCIETY file OR expired membership → pay weekly ZCARD rent
# - OWNERS (sociétaires): Valid U.SOCIETY file → made capital contribution, no weekly rent
ZENCARD_COUNT=0
ZENCARD_RENTERS=0
ZENCARD_OWNERS=0

if [[ -d "$HOME/.zen/game/players" ]]; then
    CURRENT_DATE=$(date -u +%Y%m%d%H%M%S%4N)
    
    for player_dir in "$HOME/.zen/game/players"/*@*/; do
        [[ ! -d "$player_dir" ]] && continue
        ZENCARD_COUNT=$((ZENCARD_COUNT + 1))
        
        # Check U.SOCIETY status
        if [[ -s "${player_dir}U.SOCIETY" ]]; then
            # Has U.SOCIETY - check if it has an end date
            if [[ -s "${player_dir}U.SOCIETY.end" ]]; then
                USOCIETY_END=$(cat "${player_dir}U.SOCIETY.end" 2>/dev/null)
                if [[ "$CURRENT_DATE" < "$USOCIETY_END" ]]; then
                    # Active sociétaire membership - OWNER (no rent)
                    ZENCARD_OWNERS=$((ZENCARD_OWNERS + 1))
                else
                    # Expired membership - now a RENTER
                    ZENCARD_RENTERS=$((ZENCARD_RENTERS + 1))
                fi
            else
                # No end date = permanent membership - OWNER (no rent)
                ZENCARD_OWNERS=$((ZENCARD_OWNERS + 1))
            fi
        else
            # No U.SOCIETY file - RENTER (pays rent)
            ZENCARD_RENTERS=$((ZENCARD_RENTERS + 1))
        fi
    done
fi

# Get capacities from config
MULTIPASS_CAPACITY=${NOSTRCARD_SLOTS:-250}
ZENCARD_CAPACITY=${ZENCARD_SLOTS:-24}

log_output "  MULTIPASS: $MULTIPASS_COUNT/$MULTIPASS_CAPACITY"
log_output "  ZENCARD: $ZENCARD_COUNT total ($ZENCARD_RENTERS renters, $ZENCARD_OWNERS owners)"

###############################################################################
# COLLECT REVENUE DATA
###############################################################################

log_output "💵 Collecting revenue data..."

# Get rental rates from config
NCARD=${NCARD:-1}  # MULTIPASS weekly rate (HT)
ZCARD=${ZCARD:-4}  # ZENCARD weekly rate (HT)
PAF=${PAF:-14}     # Weekly PAF

# Calculate weekly revenue
# - MULTIPASS: All users pay rent
# - ZENCARD: Only RENTERS pay rent, OWNERS (sociétaires) don't pay weekly rent
MULTIPASS_REVENUE=$(normalize_number "$(echo "$MULTIPASS_COUNT * $NCARD" | bc -l)")
ZENCARD_REVENUE=$(normalize_number "$(echo "$ZENCARD_RENTERS * $ZCARD" | bc -l)")  # Only renters, not owners!
TOTAL_REVENUE=$(normalize_number "$(echo "$MULTIPASS_REVENUE + $ZENCARD_REVENUE" | bc -l)")

# TVA calculation (from cooperative config, default 20%)
_TVA_RATE_PCT=${TVA_RATE:-20}
TOTAL_TVA=$(normalize_number "$(echo "scale=2; $TOTAL_REVENUE * $_TVA_RATE_PCT / 100" | bc -l)")

log_output "  Revenue: $TOTAL_REVENUE Ẑ HT (MP: $MULTIPASS_COUNT × $NCARD + ZC renters: $ZENCARD_RENTERS × $ZCARD)"
log_output "  TVA: $TOTAL_TVA Ẑ | ZenCard owners (no rent): $ZENCARD_OWNERS"

###############################################################################
# CALCULATE COSTS AND BILAN
###############################################################################

log_output "📊 Calculating bilan..."

CAPTAIN_REMUNERATION=$(normalize_number "$(echo "$PAF * 2" | bc -l)")
TOTAL_COSTS=$(normalize_number "$(echo "$PAF + $CAPTAIN_REMUNERATION" | bc -l)")
BILAN=$(normalize_number "$(echo "scale=2; $TOTAL_REVENUE - $TOTAL_COSTS" | bc -l)")

# Calculate allocation (if positive bilan)
# Uses IS rates from cooperative_config (progressive: reduced/normal with threshold)
_IS_RATE_REDUCED=${IS_RATE_REDUCED:-15}
_IS_RATE_NORMAL=${IS_RATE_NORMAL:-25}
_IS_THRESHOLD=${IS_THRESHOLD:-42500}
_TREASURY_PCT=${TREASURY_PERCENT:-33}
_RND_PCT=${RND_PERCENT:-33}
_ASSETS_PCT=${ASSETS_PERCENT:-33}
_CAPTAIN_BONUS_PCT=${CAPTAIN_BONUS_PERCENT:-1}

if [[ $(echo "$BILAN > 0" | bc -l) -eq 1 ]]; then
    # IS provision (progressive: 15% up to threshold, 25% above)
    if [[ $(echo "$BILAN <= $_IS_THRESHOLD" | bc -l) -eq 1 ]]; then
        IS_PROVISION=$(normalize_number "$(echo "scale=2; $BILAN * $_IS_RATE_REDUCED / 100" | bc -l)")
    else
        IS_PROVISION=$(normalize_number "$(echo "scale=2; $BILAN * $_IS_RATE_NORMAL / 100" | bc -l)")
    fi
    NET_SURPLUS=$(normalize_number "$(echo "scale=2; $BILAN - $IS_PROVISION" | bc -l)")

    # Allocation using cooperative ratios (must match ZEN.COOPERATIVE.3x1-3.sh)
    ALLOC_TREASURY=$(normalize_number "$(echo "scale=2; $NET_SURPLUS * $_TREASURY_PCT / 100" | bc -l)")
    ALLOC_RND=$(normalize_number "$(echo "scale=2; $NET_SURPLUS * $_RND_PCT / 100" | bc -l)")
    ALLOC_ASSETS=$(normalize_number "$(echo "scale=2; $NET_SURPLUS * $_ASSETS_PCT / 100" | bc -l)")
    ALLOC_CAPTAIN_BONUS=$(normalize_number "$(echo "scale=2; $NET_SURPLUS * $_CAPTAIN_BONUS_PCT / 100" | bc -l)")
    ALLOCATION_THIRD="$ALLOC_TREASURY"  # Legacy compat (used in tags)
else
    IS_PROVISION="0"
    NET_SURPLUS="0"
    ALLOCATION_THIRD="0"
    ALLOC_TREASURY="0"
    ALLOC_RND="0"
    ALLOC_ASSETS="0"
    ALLOC_CAPTAIN_BONUS="0"
fi

log_output "  Bilan: $BILAN Ẑ | IS: ${IS_PROVISION} Ẑ | Net: ${NET_SURPLUS} Ẑ"
log_output "  Allocation: Treasury=${ALLOC_TREASURY} R&D=${ALLOC_RND} Assets=${ALLOC_ASSETS} Captain=${ALLOC_CAPTAIN_BONUS}"

###############################################################################
# CALCUL DU NIVEAU DE RÉSILIENCE (Love Ledger Model)
# Niveau 0: Abondance   — CASH couvre tous les frais
# Niveau 1: Solidarité  — CASH insuffisant, ASSETS disponibles
# Niveau 2: Résilience  — ASSETS épuisés, R&D disponible
# Niveau 3: Bénévolat   — Tous fonds insuffisants → Captain offre son infra/temps
#                         (comptabilisé dans le Love Ledger, jamais une "faillite")
###############################################################################

log_output "🏥 Calcul du niveau de résilience..."

# Calculer l'autonomie en semaines depuis CASH seul
if [[ $(echo "$TOTAL_COSTS > 0" | bc -l) -eq 1 ]]; then
    WEEKS_RUNWAY=$(normalize_number "$(echo "scale=0; $CASH_ZEN / $TOTAL_COSTS" | bc -l 2>/dev/null || echo "0")")
else
    WEEKS_RUNWAY=999
fi

# Lire le dernier statut depuis le fichier marqueur
PAYMENT_MARKER="$HOME/.zen/game/.weekly_payment.done"
LAST_RESILIENCE_LEVEL=0
if [[ -f "$PAYMENT_MARKER" ]]; then
    MARKER_CONTENT=$(cat "$PAYMENT_MARKER")
    # Format : YEAR-Wxx:RESILIENCEn:NODEn:CPTn
    LAST_RESILIENCE_LEVEL=$(echo "$MARKER_CONTENT" | grep -oP 'RESILIENCE\K[0-9]+' || echo "0")
fi

# Déterminer le niveau de résilience selon les portefeuilles disponibles
RESILIENCE_LEVEL=0

# Vérifier si CASH couvre les frais opérationnels (3x PAF)
[[ -z $PAF ]] && PAF=14
TOTAL_PAF_REQUIRED=$(normalize_number "$(echo "scale=2; $PAF * 3" | bc -l)")

if [[ $(echo "$CASH_ZEN >= $TOTAL_PAF_REQUIRED" | bc -l 2>/dev/null) -eq 1 ]]; then
    # Niveau 0: Abondance
    RESILIENCE_LEVEL=0
    HEALTH_STATUS="healthy"
    RISK_LEVEL="low"
elif [[ $(echo "$ASSETS_ZEN > 0" | bc -l 2>/dev/null) -eq 1 ]]; then
    # Niveau 1: Solidarité ASSETS
    RESILIENCE_LEVEL=1
    HEALTH_STATUS="assets_solidarity"
    RISK_LEVEL="medium"
elif [[ $(echo "$RND_ZEN > 0" | bc -l 2>/dev/null) -eq 1 ]]; then
    # Niveau 2: Solidarité R&D
    RESILIENCE_LEVEL=2
    HEALTH_STATUS="rnd_solidarity"
    RISK_LEVEL="medium"
else
    # Niveau 3: Bénévolat Actif — pas de faillite, le Capitaine offre son infra/temps
    RESILIENCE_LEVEL=3
    HEALTH_STATUS="volunteer"
    RISK_LEVEL="supported_by_captain"
fi

# Charger les données du Love Ledger
LOVE_LEDGER="$HOME/.zen/game/love_ledger.json"
LOVE_TOTAL_ZEN=0
LOVE_WEEKS_COUNT=0
if [[ -f "$LOVE_LEDGER" ]]; then
    LOVE_TOTAL_ZEN=$(jq -r '.total_donated_zen // 0' "$LOVE_LEDGER" 2>/dev/null || echo "0")
    LOVE_WEEKS_COUNT=$(jq -r '.weeks_on_volunteer // 0' "$LOVE_LEDGER" 2>/dev/null || echo "0")
    LOVE_TOTAL_ZEN=$(normalize_number "$LOVE_TOTAL_ZEN")
fi

# Calculer l'autonomie totale (avec tous les portefeuilles de solidarité)
TOTAL_AVAILABLE=$(normalize_number "$(echo "scale=2; $CASH_ZEN + $ASSETS_ZEN + $RND_ZEN" | bc -l 2>/dev/null || echo "0")")
if [[ $(echo "$TOTAL_COSTS > 0" | bc -l) -eq 1 ]]; then
    TOTAL_WEEKS_RUNWAY=$(normalize_number "$(echo "scale=0; $TOTAL_AVAILABLE / $TOTAL_COSTS" | bc -l 2>/dev/null || echo "0")")
else
    TOTAL_WEEKS_RUNWAY=999
fi

log_output "  Résilience: $HEALTH_STATUS (Niveau $RESILIENCE_LEVEL) | CASH: $WEEKS_RUNWAY sem | Total: $TOTAL_WEEKS_RUNWAY sem"
log_output "  Love Ledger: ${LOVE_TOTAL_ZEN} Ẑen offerts sur ${LOVE_WEEKS_COUNT} semaine(s)"

###############################################################################
# GET DEPRECIATION DATA
###############################################################################

log_output "📉 Collecting depreciation data..."

MACHINE_VALUE=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
CAPITAL_DATE=$(grep "^CAPITAL_DATE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
DEPRECIATION_WEEKS=$(grep "^DEPRECIATION_WEEKS=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)

# Apply defaults for empty values
[[ -z "$MACHINE_VALUE" ]] && MACHINE_VALUE="0"
[[ -z "$DEPRECIATION_WEEKS" ]] && DEPRECIATION_WEEKS="156"

if [[ -n "$MACHINE_VALUE" && "$MACHINE_VALUE" != "0" && -n "$CAPITAL_DATE" ]]; then
    CAPITAL_TIMESTAMP=$(date -d "${CAPITAL_DATE:0:8}" +%s 2>/dev/null || echo "0")
    CURRENT_TIMESTAMP=$(date +%s)
    SECONDS_ELAPSED=$((CURRENT_TIMESTAMP - CAPITAL_TIMESTAMP))
    WEEKS_ELAPSED=$((SECONDS_ELAPSED / 604800))
    
    WEEKLY_DEPRECIATION=$(normalize_number "$(echo "scale=2; $MACHINE_VALUE / $DEPRECIATION_WEEKS" | bc -l)")
    TOTAL_DEPRECIATED=$(normalize_number "$(echo "scale=2; $WEEKLY_DEPRECIATION * $WEEKS_ELAPSED" | bc -l)")
    RESIDUAL_VALUE=$(normalize_number "$(echo "scale=2; $MACHINE_VALUE - $TOTAL_DEPRECIATED" | bc -l)")
    DEPRECIATION_PERCENT=$(normalize_number "$(echo "scale=2; ($WEEKS_ELAPSED * 100) / $DEPRECIATION_WEEKS" | bc -l)")
else
    MACHINE_VALUE="0"
    WEEKS_ELAPSED=0
    WEEKLY_DEPRECIATION="0"
    TOTAL_DEPRECIATED="0"
    RESIDUAL_VALUE="0"
    DEPRECIATION_PERCENT="0"
fi

log_output "  Machine: $MACHINE_VALUE Ẑ | Residual: $RESIDUAL_VALUE Ẑ | Deprec: $DEPRECIATION_PERCENT%"

###############################################################################
# STATION GPS & SOLAR TIME SYNC
# Solar time synchronization spreads payment execution across swarm by longitude
# Each station runs at 20h12 LOCAL SOLAR TIME - preventing concurrent payments
###############################################################################

# Get GPS coordinates for solar time sync visibility
if [[ -f ~/.zen/GPS ]]; then
    source ~/.zen/GPS
    STATION_LAT="${LAT:-0}"
    STATION_LON="${LON:-0}"
else
    STATION_LAT="0"
    STATION_LON="0"
fi

# Calculate solar time offset (when this station runs its 20h12 cycle)
# This shows when this station processes payments relative to others in the swarm
SOLAR_OFFSET="--:--"
if [[ -f "${MY_PATH}/../tools/solar_time.sh" && "$STATION_LAT" != "0" && "$STATION_LON" != "0" ]]; then
    SOLAR_RESULT=$(${MY_PATH}/../tools/solar_time.sh "$STATION_LAT" "$STATION_LON" 2>/dev/null | tail -1)
    if [[ -n "$SOLAR_RESULT" ]]; then
        SOLAR_MINUTE=$(echo "$SOLAR_RESULT" | awk '{print $1}')
        SOLAR_HOUR=$(echo "$SOLAR_RESULT" | awk '{print $2}')
        SOLAR_OFFSET=$(printf "%02d:%02d" "${SOLAR_HOUR:-0}" "${SOLAR_MINUTE:-0}")
    fi
fi

log_output "📍 Station GPS: $STATION_LAT, $STATION_LON | Solar sync: $SOLAR_OFFSET"

###############################################################################
# BUILD NOSTR EVENT
###############################################################################

log_output "📝 Building NOSTR event..."

GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CREATED_AT=$(date +%s)

# Build content JSON
CONTENT_JSON=$(cat <<EOF
{
  "report_version": "1.1",
  "report_type": "economic_health",
  "generated_at": "$GENERATED_AT",
  "station": {
    "ipfsnodeid": "$IPFSNODEID",
    "name": "${myDAMAIN:-...${IPFSNODEID: -8}}",
    "swarm_id": "$UPLANETG1PUB",
    "relay_url": "wss://${myDAMAIN}/relay",
    "captain_hex": "$CAPTAIN_HEX",
    "geo": {
      "lat": $STATION_LAT,
      "lon": $STATION_LON
    },
    "sync": {
      "solar_offset": "$SOLAR_OFFSET",
      "solar_comment": "Station runs 20h12 cycle at this local time (spread across swarm by longitude)"
    }
  },
  "wallets": {
    "g1_reserve": { "g1pub": "$UPLANETNAME_G1", "balance_g1": $G1_RESERVE_G1, "balance_zen": $G1_RESERVE_ZEN },
    "cash": { "g1pub": "$CASH_PUBKEY", "balance_g1": $CASH_G1, "balance_zen": $CASH_ZEN },
    "rnd": { "g1pub": "$RND_PUBKEY", "balance_g1": $RND_G1, "balance_zen": $RND_ZEN },
    "assets": { "g1pub": "$ASSETS_PUBKEY", "balance_g1": $ASSETS_G1, "balance_zen": $ASSETS_ZEN },
    "impot": { "g1pub": "$IMPOT_PUBKEY", "balance_g1": $IMPOT_G1, "balance_zen": $IMPOT_ZEN },
    "capital": { "g1pub": "$CAPITAL_PUBKEY", "balance_g1": $CAPITAL_G1, "balance_zen": $CAPITAL_ZEN },
    "amortissement": { "g1pub": "$AMORT_PUBKEY", "balance_g1": $AMORT_G1, "balance_zen": $AMORT_ZEN },
    "node": { "g1pub": "$NODE_PUBKEY", "balance_g1": $NODE_G1, "balance_zen": $NODE_ZEN },
    "captain_dedicated": { "g1pub": "$CAPTAIN_DED_PUBKEY", "balance_g1": $CAPTAIN_DED_G1, "balance_zen": $CAPTAIN_DED_ZEN }
  },
  "revenue": {
    "multipass": { "count": $MULTIPASS_COUNT, "rate": $NCARD, "total": $MULTIPASS_REVENUE },
    "zencard": { "renters": $ZENCARD_RENTERS, "rate": $ZCARD, "total": $ZENCARD_REVENUE },
    "total_ht": $TOTAL_REVENUE,
    "total_tva": $TOTAL_TVA
  },
  "costs": {
    "paf_node": $PAF,
    "captain_salary": $CAPTAIN_REMUNERATION,
    "total": $TOTAL_COSTS
  },
  "allocation": {
    "surplus": $BILAN,
    "is_provision": $IS_PROVISION,
    "net_surplus": $NET_SURPLUS,
    "treasury": $ALLOC_TREASURY,
    "rnd": $ALLOC_RND,
    "assets": $ALLOC_ASSETS,
    "captain_bonus": $ALLOC_CAPTAIN_BONUS,
    "treasury_pct": ${TREASURY_PERCENT:-33},
    "rnd_pct": ${RND_PERCENT:-33},
    "assets_pct": ${ASSETS_PERCENT:-33},
    "captain_bonus_pct": ${CAPTAIN_BONUS_PERCENT:-1}
  },
  "capacity": {
    "multipass": { "used": $MULTIPASS_COUNT, "total": $MULTIPASS_CAPACITY },
    "zencard": { "total": $ZENCARD_COUNT, "renters": $ZENCARD_RENTERS, "owners": $ZENCARD_OWNERS, "capacity": $ZENCARD_CAPACITY }
  },
  "health": {
    "status": "$HEALTH_STATUS",
    "resilience_level": $RESILIENCE_LEVEL,
    "bilan": $BILAN,
    "weeks_runway": $WEEKS_RUNWAY,
    "total_weeks_runway": $TOTAL_WEEKS_RUNWAY,
    "risk_level": "$RISK_LEVEL"
  },
  "love_ledger": {
    "total_donated_zen": $LOVE_TOTAL_ZEN,
    "weeks_on_volunteer": $LOVE_WEEKS_COUNT,
    "comment": "Bénévolat Actif = Don aux Communs. Pas de faillite, seulement de la résilience."
  },
  "depreciation": {
    "machine_value": $MACHINE_VALUE,
    "weeks_elapsed": $WEEKS_ELAPSED,
    "depreciation_weeks": $DEPRECIATION_WEEKS,
    "weekly_depreciation": $WEEKLY_DEPRECIATION,
    "total_depreciated": $TOTAL_DEPRECIATED,
    "residual_value": $RESIDUAL_VALUE,
    "percent": $DEPRECIATION_PERCENT
  },
  "compliance": {
    "tva_provisioned": $IMPOT_ZEN,
    "audit_ready": true
  }
}
EOF
)

# Validate JSON
if ! echo "$CONTENT_JSON" | jq empty 2>/dev/null; then
    echo "❌ Invalid JSON content"
    echo "$CONTENT_JSON" | jq . 2>&1 | head -5
    exit 1
fi

# Escape content for NOSTR event
CONTENT_ESCAPED=$(echo "$CONTENT_JSON" | jq -c .)

# Station SSH public key (for same-uplanet captain P2P SSH linking via DRAGON_p2p_ssh.sh)
STATION_SSH_PUB=$(head -1 "$HOME/.zen/tmp/${IPFSNODEID}/z_ssh.pub" 2>/dev/null || head -1 "$HOME/.zen/tmp/${IPFSNODEID}/y_ssh.pub" 2>/dev/null || head -1 "$HOME/.zen/tmp/${IPFSNODEID}/x_ssh.pub" 2>/dev/null)

# Build tags array
TAGS_JSON=$(cat <<EOF
[
  ["d", "$EVENT_D"],
  ["t", "uplanet"],
  ["t", "economic-health"],
  ["t", "$UPLANETG1PUB"],
  ["t", "$IPFSNODEID"],
  ["constellation", "$UPLANETG1PUB"],
  ["station", "$IPFSNODEID"],
  ["station:name", "${myDAMAIN:-...${IPFSNODEID: -8}}"],
  ["swarm_id", "$UPLANETG1PUB"],
  ["week", "$CURRENT_WEEK"],
  ["g1pub", "$UPLANETNAME_G1"],
  ["geo:lat", "$STATION_LAT"],
  ["geo:lon", "$STATION_LON"],
  ["sync:solar_offset", "$SOLAR_OFFSET"],
  ["balance:cash", "$CASH_ZEN"],
  ["balance:rnd", "$RND_ZEN"],
  ["balance:assets", "$ASSETS_ZEN"],
  ["balance:impot", "$IMPOT_ZEN"],
  ["balance:capital", "$CAPITAL_ZEN"],
  ["balance:amortissement", "$AMORT_ZEN"],
  ["balance:node", "$NODE_ZEN"],
  ["revenue:multipass", "$MULTIPASS_REVENUE"],
  ["revenue:zencard", "$ZENCARD_REVENUE"],
  ["revenue:total", "$TOTAL_REVENUE"],
  ["cost:paf", "$PAF"],
  ["cost:captain", "$CAPTAIN_REMUNERATION"],
  ["cost:total", "$TOTAL_COSTS"],
  ["price:multipass", "$NCARD"],
  ["price:zencard", "$ZCARD"],
  ["allocation:treasury", "$ALLOC_TREASURY"],
  ["allocation:rnd", "$ALLOC_RND"],
  ["allocation:assets", "$ALLOC_ASSETS"],
  ["allocation:captain_bonus", "$ALLOC_CAPTAIN_BONUS"],
  ["allocation:treasury_pct", "${TREASURY_PERCENT:-33}"],
  ["allocation:rnd_pct", "${RND_PERCENT:-33}"],
  ["allocation:assets_pct", "${ASSETS_PERCENT:-33}"],
  ["allocation:captain_bonus_pct", "${CAPTAIN_BONUS_PERCENT:-1}"],
  ["capacity:multipass_used", "$MULTIPASS_COUNT"],
  ["capacity:multipass_total", "$MULTIPASS_CAPACITY"],
  ["capacity:zencard_total", "$ZENCARD_COUNT"],
  ["capacity:zencard_renters", "$ZENCARD_RENTERS"],
  ["capacity:zencard_owners", "$ZENCARD_OWNERS"],
  ["capacity:zencard_capacity", "$ZENCARD_CAPACITY"],
  ["health:status", "$HEALTH_STATUS"],
  ["health:resilience_level", "$RESILIENCE_LEVEL"],
  ["health:weeks_runway", "$WEEKS_RUNWAY"],
  ["health:total_weeks_runway", "$TOTAL_WEEKS_RUNWAY"],
  ["health:bilan", "$BILAN"],
  ["love_ledger:total_zen", "$LOVE_TOTAL_ZEN"],
  ["love_ledger:weeks", "$LOVE_WEEKS_COUNT"],
  ["provision:tva", "$TOTAL_TVA"],
  ["provision:is", "$IS_PROVISION"],
  ["depreciation:machine_value", "$MACHINE_VALUE"],
  ["depreciation:residual", "$RESIDUAL_VALUE"],
  ["depreciation:percent", "$DEPRECIATION_PERCENT"]
]
EOF
)
# Append ssh_pub tag so other captains of same uplanet can add this station to their authorized_keys (DRAGON_p2p_ssh.sh)
if [[ -n "$STATION_SSH_PUB" ]]; then
    TAGS_JSON=$(echo "$TAGS_JSON" | jq --arg pub "$STATION_SSH_PUB" '. + [["ssh_pub", $pub]]' 2>/dev/null) || TAGS_JSON="$TAGS_JSON"
fi

###############################################################################
# PUBLISH EVENT TO LOCAL STRFRY RELAY
###############################################################################

if [[ "$DRYRUN" == "true" ]]; then
    echo "🔍 DRYRUN MODE - Événement qui serait publié :"
    echo ""
    echo "Kind: 30850 (Economic Health Report)"
    echo "Auteur: ${CAPTAIN_HEX:0:16}..."
    echo ""
    echo "═══ NIVEAU DE RÉSILIENCE : $RESILIENCE_LEVEL ($HEALTH_STATUS) ═══"
    case $RESILIENCE_LEVEL in
        0) echo "✅ Abondance — CASH couvre tous les frais" ;;
        1) echo "🌿 Solidarité ASSETS — forêts-jardins soutiennent l'infra" ;;
        2) echo "🔬 Solidarité R&D — innovation soutient l'infra" ;;
        3) echo "❤️  Bénévolat Actif — le Capitaine soutient le réseau" ;;
    esac
    echo ""
    echo "Portefeuilles :"
    echo "  CASH:   $CASH_ZEN Ẑ"
    echo "  RND:    $RND_ZEN Ẑ"
    echo "  ASSETS: $ASSETS_ZEN Ẑ"
    echo "  IMPOT:  $IMPOT_ZEN Ẑ"
    if [[ $(echo "$LOVE_TOTAL_ZEN > 0" | bc -l 2>/dev/null) -eq 1 ]]; then
    echo ""
    echo "❤️  Love Ledger :"
    echo "  Total offert aux Communs : ${LOVE_TOTAL_ZEN} Ẑen"
    echo "  Semaines de bénévolat    : ${LOVE_WEEKS_COUNT}"
    fi
    echo ""
    echo "Capacité :"
    echo "  MULTIPASS : $MULTIPASS_COUNT/$MULTIPASS_CAPACITY"
    echo "  ZENCARD   : $ZENCARD_COUNT total ($ZENCARD_RENTERS locataires, $ZENCARD_OWNERS sociétaires)"
    echo ""
    echo "Revenus : $TOTAL_REVENUE Ẑ HT (MP: $MULTIPASS_COUNT × $NCARD + ZC: $ZENCARD_RENTERS × $ZCARD)"
    echo "  Note: $ZENCARD_OWNERS ZenCard sociétaires exonérés de redevance hebdo"
    echo "Frais   : $TOTAL_COSTS Ẑ (PAF: $PAF + Capitaine: $CAPTAIN_REMUNERATION)"
    echo "Bilan   : $BILAN Ẑ | Autonomie: $WEEKS_RUNWAY semaine(s)"
    echo ""
    echo "JSON complet :"
    echo "$CONTENT_JSON" | jq .
    exit 0
fi

log_output "📡 Publishing event to local strfry relay..."

# Get Captain NSEC and convert to HEX for nostr_send_note.py
# The .secret.nostr file format: "NSEC=nsec1...; NPUB=npub1..."
CAPTAIN_NSEC_RAW=$(cat "$CAPTAIN_NOSTR_SECRET" 2>/dev/null)
if [[ -z "$CAPTAIN_NSEC_RAW" ]]; then
    echo "❌ Cannot read Captain NOSTR secret"
    exit 1
fi

# Extract just the NSEC value (between "NSEC=" and ";")
CAPTAIN_NSEC=$(echo "$CAPTAIN_NSEC_RAW" | grep -oP 'NSEC=\K[^;]+' || echo "$CAPTAIN_NSEC_RAW")
# Fallback: if file just contains "nsec1...", use as-is
[[ "$CAPTAIN_NSEC" != nsec1* ]] && CAPTAIN_NSEC=$(echo "$CAPTAIN_NSEC_RAW" | grep -oP 'nsec1[a-z0-9]+')

# Convert NSEC to HEX using nostr2hex.py
CAPTAIN_PRIVKEY_HEX=$(${MY_PATH}/../tools/nostr2hex.py "$CAPTAIN_NSEC" 2>/dev/null)
if [[ -z "$CAPTAIN_PRIVKEY_HEX" ]]; then
    echo "❌ Cannot convert Captain NSEC to HEX"
    exit 1
fi

# Get local relay URL
myRELAY="wss://${myDAMAIN}/relay"
[[ -z "$myDAMAIN" ]] && myRELAY="ws://127.0.0.1:7777"

# Publish using nostr_send_note.py
if [[ -f "${MY_PATH}/../tools/nostr_send_note.py" ]]; then
    log_output "Using nostr_send_note.py to publish event..."
    
    # Create temp keyfile for nostr_send_note.py
    TMP_KEYFILE=$(mktemp)
    echo "NSEC=$CAPTAIN_NSEC;" > "$TMP_KEYFILE"

    python3 "${MY_PATH}/../tools/nostr_send_note.py" \
        --keyfile "$TMP_KEYFILE" \
        --kind 30850 \
        --content "$CONTENT_ESCAPED" \
        --tags "$TAGS_JSON" \
        --relay "$myRELAY" 2>/dev/null
    
    PUBLISH_STATUS=$?
    rm "$TMP_KEYFILE"
    
    if [[ $PUBLISH_STATUS -eq 0 ]]; then
        log_output "✅ Événement publié sur le relay"
        echo "✅ Rapport de santé économique publié"
        echo "   Statut: $HEALTH_STATUS (Niveau de Résilience: $RESILIENCE_LEVEL)"
        echo "   Bilan: $BILAN Ẑ | Autonomie: $WEEKS_RUNWAY semaine(s)"
        [[ $(echo "$LOVE_TOTAL_ZEN > 0" | bc -l 2>/dev/null) -eq 1 ]] && \
            echo "   ❤️  Love Ledger: ${LOVE_TOTAL_ZEN} Ẑen offerts aux Communs (${LOVE_WEEKS_COUNT} sem.)"
        echo "   Relay: $myRELAY"
    else
        echo "⚠️ nostr_send_note.py failed, trying strfry import..."
        
        # Fallback: create event JSON and import directly to strfry
        MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
        TEMP_EVENT="$HOME/.zen/tmp/${MOATS}_economic_health.json"
        mkdir -p "$HOME/.zen/tmp"
        
        # Build event for strfry import (strfry will sign with --no-verify)
        cat > "$TEMP_EVENT" <<EOF
{
  "kind": 30850,
  "pubkey": "$CAPTAIN_HEX",
  "created_at": $CREATED_AT,
  "tags": $TAGS_JSON,
  "content": $CONTENT_ESCAPED
}
EOF
        
        cd ~/.zen/strfry
        ./strfry import --no-verify < "$TEMP_EVENT" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Economic health report stored locally"
            echo "   (Will be synced via constellation backfill)"
        else
            echo "❌ Failed to store event"
            exit 1
        fi
        
        rm -f "$TEMP_EVENT"
    fi
else
    echo "❌ nostr_send_note.py not found - required for NOSTR publishing"
    exit 1
fi

# Save last broadcast info
echo "$GENERATED_AT" > "$HOME/.zen/tmp/last_economy_broadcast.txt"

log_output "📊 ECONOMY.broadcast.sh completed"
exit 0
