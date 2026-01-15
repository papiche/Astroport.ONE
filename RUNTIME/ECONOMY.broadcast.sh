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

# Get week identifier
CURRENT_WEEK="W$(date +%V)-$(date +%Y)"
log_output "📅 Report for week: $CURRENT_WEEK"

# Get wallet balance (G1check.sh handles caching internally)
get_wallet_balance() {
    local pubkey="$1"
    ${MY_PATH}/../tools/G1check.sh "$pubkey" 2>/dev/null | tail -n 1 || echo "0"
}

convert_to_zen() {
    local g1_balance="$1"
    if [[ $(echo "$g1_balance > 1" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        echo "scale=2; ($g1_balance - 1) * 10" | bc -l 2>/dev/null
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
MULTIPASS_REVENUE=$(echo "$MULTIPASS_COUNT * $NCARD" | bc -l)
ZENCARD_REVENUE=$(echo "$ZENCARD_RENTERS * $ZCARD" | bc -l)  # Only renters, not owners!
TOTAL_REVENUE=$(echo "$MULTIPASS_REVENUE + $ZENCARD_REVENUE" | bc -l)

# TVA calculation (20%)
TVA_RATE=0.20
TOTAL_TVA=$(echo "scale=2; $TOTAL_REVENUE * $TVA_RATE" | bc -l)

log_output "  Revenue: $TOTAL_REVENUE Ẑ HT (MP: $MULTIPASS_COUNT × $NCARD + ZC renters: $ZENCARD_RENTERS × $ZCARD)"
log_output "  TVA: $TOTAL_TVA Ẑ | ZenCard owners (no rent): $ZENCARD_OWNERS"

###############################################################################
# CALCULATE COSTS AND BILAN
###############################################################################

log_output "📊 Calculating bilan..."

CAPTAIN_REMUNERATION=$(echo "$PAF * 2" | bc -l)
TOTAL_COSTS=$(echo "$PAF + $CAPTAIN_REMUNERATION" | bc -l)
BILAN=$(echo "scale=2; $TOTAL_REVENUE - $TOTAL_COSTS" | bc -l)

# Calculate allocation (if positive bilan)
if [[ $(echo "$BILAN > 0" | bc -l) -eq 1 ]]; then
    # IS provision (25%)
    IS_PROVISION=$(echo "scale=2; $BILAN * 0.25" | bc -l)
    NET_SURPLUS=$(echo "scale=2; $BILAN - $IS_PROVISION" | bc -l)
    
    # 3x1/3 allocation
    ALLOCATION_THIRD=$(echo "scale=2; $NET_SURPLUS / 3" | bc -l)
else
    IS_PROVISION="0"
    NET_SURPLUS="0"
    ALLOCATION_THIRD="0"
fi

log_output "  Bilan: $BILAN Ẑ | Allocation 1/3: $ALLOCATION_THIRD Ẑ"

###############################################################################
# CALCULATE HEALTH STATUS (Progressive Degradation Model)
# Phase 0: Normal (CASH sufficient)
# Phase 1: Growth Slowdown (CASH < costs, ASSETS > 0)
# Phase 2: Innovation Slowdown (ASSETS depleted, RnD > 0)
# Phase 3: Bankruptcy (All wallets depleted)
###############################################################################

log_output "🏥 Determining health status..."

# Calculate weeks runway based on CASH alone
if [[ $(echo "$TOTAL_COSTS > 0" | bc -l) -eq 1 ]]; then
    WEEKS_RUNWAY=$(echo "scale=0; $CASH_ZEN / $TOTAL_COSTS" | bc -l 2>/dev/null || echo "0")
else
    WEEKS_RUNWAY=999
fi

# Read last payment status from marker file
PAYMENT_MARKER="$HOME/.zen/game/.weekly_payment.done"
LAST_PHASE=0
if [[ -f "$PAYMENT_MARKER" ]]; then
    MARKER_CONTENT=$(cat "$PAYMENT_MARKER")
    # Extract phase from format: WEEK_KEY:PHASE#:NODE#:CPT#
    LAST_PHASE=$(echo "$MARKER_CONTENT" | grep -oP 'PHASE\K[0-9]+' || echo "0")
fi

# Determine health status based on progressive degradation model
DEGRADATION_PHASE=0

# Check if CASH can cover operational costs (3x PAF)
[[ -z $PAF ]] && PAF=14
TOTAL_PAF_REQUIRED=$(echo "scale=2; $PAF * 3" | bc -l)

if [[ $(echo "$CASH_ZEN >= $TOTAL_PAF_REQUIRED" | bc -l 2>/dev/null) -eq 1 ]]; then
    # Phase 0: Normal operation
    DEGRADATION_PHASE=0
    HEALTH_STATUS="healthy"
    RISK_LEVEL="low"
elif [[ $(echo "$ASSETS_ZEN > 0" | bc -l 2>/dev/null) -eq 1 ]]; then
    # Phase 1: CASH insufficient but ASSETS available
    DEGRADATION_PHASE=1
    HEALTH_STATUS="growth_slowdown"
    RISK_LEVEL="medium"
elif [[ $(echo "$RND_ZEN > 0" | bc -l 2>/dev/null) -eq 1 ]]; then
    # Phase 2: ASSETS depleted, using RnD
    DEGRADATION_PHASE=2
    HEALTH_STATUS="innovation_slowdown"
    RISK_LEVEL="high"
else
    # Phase 3: All wallets depleted - Bankruptcy
    DEGRADATION_PHASE=3
    HEALTH_STATUS="bankrupt"
    RISK_LEVEL="critical"
fi

# Calculate total runway including backup wallets
TOTAL_AVAILABLE=$(echo "scale=2; $CASH_ZEN + $ASSETS_ZEN + $RND_ZEN" | bc -l 2>/dev/null || echo "0")
if [[ $(echo "$TOTAL_COSTS > 0" | bc -l) -eq 1 ]]; then
    TOTAL_WEEKS_RUNWAY=$(echo "scale=0; $TOTAL_AVAILABLE / $TOTAL_COSTS" | bc -l 2>/dev/null || echo "0")
else
    TOTAL_WEEKS_RUNWAY=999
fi

log_output "  Status: $HEALTH_STATUS (Phase $DEGRADATION_PHASE) | CASH Runway: $WEEKS_RUNWAY weeks | Total Runway: $TOTAL_WEEKS_RUNWAY weeks"

###############################################################################
# GET DEPRECIATION DATA
###############################################################################

log_output "📉 Collecting depreciation data..."

MACHINE_VALUE=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2 || echo "0")
CAPITAL_DATE=$(grep "^CAPITAL_DATE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2 || echo "")
DEPRECIATION_WEEKS=$(grep "^DEPRECIATION_WEEKS=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2 || echo "156")

if [[ -n "$MACHINE_VALUE" && "$MACHINE_VALUE" != "0" && -n "$CAPITAL_DATE" ]]; then
    CAPITAL_TIMESTAMP=$(date -d "${CAPITAL_DATE:0:8}" +%s 2>/dev/null || echo "0")
    CURRENT_TIMESTAMP=$(date +%s)
    SECONDS_ELAPSED=$((CURRENT_TIMESTAMP - CAPITAL_TIMESTAMP))
    WEEKS_ELAPSED=$((SECONDS_ELAPSED / 604800))
    
    WEEKLY_DEPRECIATION=$(echo "scale=2; $MACHINE_VALUE / $DEPRECIATION_WEEKS" | bc -l)
    TOTAL_DEPRECIATED=$(echo "scale=2; $WEEKLY_DEPRECIATION * $WEEKS_ELAPSED" | bc -l)
    RESIDUAL_VALUE=$(echo "scale=2; $MACHINE_VALUE - $TOTAL_DEPRECIATED" | bc -l)
    DEPRECIATION_PERCENT=$(echo "scale=2; ($WEEKS_ELAPSED * 100) / $DEPRECIATION_WEEKS" | bc -l)
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
EVENT_D="economic-health-$CURRENT_WEEK"

# Build content JSON
CONTENT_JSON=$(cat <<EOF
{
  "report_version": "1.1",
  "report_type": "weekly_economic_health",
  "generated_at": "$GENERATED_AT",
  "station": {
    "ipfsnodeid": "$IPFSNODEID",
    "name": "${myDAMAIN:-${IPFSNODEID:0:12}}",
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
    "treasury": $ALLOCATION_THIRD,
    "rnd": $ALLOCATION_THIRD,
    "assets": $ALLOCATION_THIRD
  },
  "capacity": {
    "multipass": { "used": $MULTIPASS_COUNT, "total": $MULTIPASS_CAPACITY },
    "zencard": { "total": $ZENCARD_COUNT, "renters": $ZENCARD_RENTERS, "owners": $ZENCARD_OWNERS, "capacity": $ZENCARD_CAPACITY }
  },
  "health": {
    "status": "$HEALTH_STATUS",
    "bilan": $BILAN,
    "weeks_runway": $WEEKS_RUNWAY,
    "risk_level": "$RISK_LEVEL"
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
    exit 1
fi

# Escape content for NOSTR event
CONTENT_ESCAPED=$(echo "$CONTENT_JSON" | jq -c .)

# Build tags array
TAGS_JSON=$(cat <<EOF
[
  ["d", "$EVENT_D"],
  ["t", "uplanet"],
  ["t", "economic-health"],
  ["t", "weekly-report"],
  ["week", "$CURRENT_WEEK"],
  ["constellation", "UPlanetV1"],
  ["station", "$IPFSNODEID"],
  ["station:name", "${myDAMAIN:-${IPFSNODEID:0:12}}"],
  ["swarm_id", "$UPLANETG1PUB"],
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
  ["allocation:treasury", "$ALLOCATION_THIRD"],
  ["allocation:rnd", "$ALLOCATION_THIRD"],
  ["allocation:assets", "$ALLOCATION_THIRD"],
  ["capacity:multipass_used", "$MULTIPASS_COUNT"],
  ["capacity:multipass_total", "$MULTIPASS_CAPACITY"],
  ["capacity:zencard_total", "$ZENCARD_COUNT"],
  ["capacity:zencard_renters", "$ZENCARD_RENTERS"],
  ["capacity:zencard_owners", "$ZENCARD_OWNERS"],
  ["capacity:zencard_capacity", "$ZENCARD_CAPACITY"],
  ["health:status", "$HEALTH_STATUS"],
  ["health:weeks_runway", "$WEEKS_RUNWAY"],
  ["health:bilan", "$BILAN"],
  ["provision:tva", "$TOTAL_TVA"],
  ["provision:is", "$IS_PROVISION"],
  ["depreciation:machine_value", "$MACHINE_VALUE"],
  ["depreciation:residual", "$RESIDUAL_VALUE"],
  ["depreciation:percent", "$DEPRECIATION_PERCENT"]
]
EOF
)

###############################################################################
# PUBLISH EVENT TO LOCAL STRFRY RELAY
###############################################################################

if [[ "$DRYRUN" == "true" ]]; then
    echo "🔍 DRYRUN MODE - Event would be published:"
    echo ""
    echo "Kind: 30850 (Economic Health Report)"
    echo "Author: ${CAPTAIN_HEX:0:16}..."
    echo "Week: $CURRENT_WEEK"
    echo "Status: $HEALTH_STATUS"
    echo ""
    echo "Wallets:"
    echo "  CASH: $CASH_ZEN Ẑ"
    echo "  RND: $RND_ZEN Ẑ"
    echo "  ASSETS: $ASSETS_ZEN Ẑ"
    echo "  IMPOT: $IMPOT_ZEN Ẑ"
    echo ""
    echo "Capacity:"
    echo "  MULTIPASS: $MULTIPASS_COUNT/$MULTIPASS_CAPACITY"
    echo "  ZENCARD: $ZENCARD_COUNT total ($ZENCARD_RENTERS renters, $ZENCARD_OWNERS owners)"
    echo ""
    echo "Revenue: $TOTAL_REVENUE Ẑ (MP: $MULTIPASS_COUNT × $NCARD + ZC renters: $ZENCARD_RENTERS × $ZCARD)"
    echo "  Note: $ZENCARD_OWNERS ZenCard owners (sociétaires) don't pay weekly rent"
    echo "Costs: $TOTAL_COSTS Ẑ (PAF: $PAF + Captain: $CAPTAIN_REMUNERATION)"
    echo "Bilan: $BILAN Ẑ"
    echo "Runway: $WEEKS_RUNWAY weeks"
    echo ""
    echo "Content JSON:"
    echo "$CONTENT_JSON" | jq .
    exit 0
fi

log_output "📡 Publishing event to local strfry relay..."

# Get Captain NSEC and convert to HEX for nostpy-cli
CAPTAIN_NSEC=$(cat "$CAPTAIN_NOSTR_SECRET" 2>/dev/null)
if [[ -z "$CAPTAIN_NSEC" ]]; then
    echo "❌ Cannot read Captain NOSTR secret"
    exit 1
fi

# Convert NSEC to HEX using nostr2hex.py
CAPTAIN_PRIVKEY_HEX=$(${MY_PATH}/../tools/nostr2hex.py "$CAPTAIN_NSEC" 2>/dev/null)
if [[ -z "$CAPTAIN_PRIVKEY_HEX" ]]; then
    echo "❌ Cannot convert Captain NSEC to HEX"
    exit 1
fi

# Get local relay URL
myRELAY="wss://${myDAMAIN}/relay"
[[ -z "$myDAMAIN" ]] && myRELAY="ws://127.0.0.1:7777"

# Publish using nostpy-cli send_event
if command -v nostpy-cli &> /dev/null; then
    log_output "Using nostpy-cli to publish event..."
    
    nostpy-cli send_event \
        -privkey "$CAPTAIN_PRIVKEY_HEX" \
        -kind 30850 \
        -content "$CONTENT_ESCAPED" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY" 2>/dev/null
    
    PUBLISH_STATUS=$?
    
    if [[ $PUBLISH_STATUS -eq 0 ]]; then
        log_output "✅ Event published to relay"
        echo "✅ Economic health report published for $CURRENT_WEEK"
        echo "   Status: $HEALTH_STATUS | Bilan: $BILAN Ẑ | Runway: $WEEKS_RUNWAY weeks"
        echo "   Relay: $myRELAY"
    else
        echo "⚠️ nostpy-cli failed, trying strfry import..."
        
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
            echo "✅ Economic health report stored locally for $CURRENT_WEEK"
            echo "   (Will be synced via constellation backfill)"
        else
            echo "❌ Failed to store event"
            exit 1
        fi
        
        rm -f "$TEMP_EVENT"
    fi
else
    echo "❌ nostpy-cli not found - required for NOSTR publishing"
    echo "   Install with: pip install nostpy-cli"
    exit 1
fi

# Save last broadcast info
echo "$CURRENT_WEEK" > "$HOME/.zen/tmp/last_economy_broadcast.txt"
echo "$GENERATED_AT" >> "$HOME/.zen/tmp/last_economy_broadcast.txt"

log_output "📊 ECONOMY.broadcast.sh completed"
exit 0
