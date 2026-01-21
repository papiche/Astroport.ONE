#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1balance.sh
#~ Indiquez une clef publique G1.
#~ Retourne le solde complet en JSON (blockchain, pending, total)
#~ Avec option de cache court (5 minutes) pour les appels fréquents
#~ Utilise silkaj avec les serveurs BMAS sélectionnés par duniter_getnode.sh
#~ Output JSON: {"blockchain": X, "pending": Y, "total": Z, "zen": W}
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Constants
MAX_RETRIES=3
CACHE_DIR="$HOME/.zen/tmp/coucou"
CACHE_TTL_MINUTES=5  # Short cache for balance (real-time needs)
BMAS_CACHE_TTL_HOURS=6  # BMAS server cache TTL in hours

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Validate G1 public key format
is_valid_g1pub() {
    [[ "$1" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,44}$ ]]
}

# Check if file is within TTL (in minutes)
is_file_fresh_minutes() {
    local file_path="$1"
    local ttl_minutes="$2"
    
    if [[ ! -s "$file_path" ]]; then
        return 1
    fi
    
    local file_age=$(stat -c %Y "$file_path" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age_minutes=$(( (current_time - file_age) / 60 ))
    
    if [[ $age_minutes -lt $ttl_minutes ]]; then
        return 0
    fi
    return 1
}

# Check if file is within TTL (in hours)
is_file_fresh() {
    local file_path="$1"
    local ttl_hours="$2"
    
    if [[ ! -s "$file_path" ]]; then
        return 1
    fi
    
    local file_age=$(stat -c %Y "$file_path" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age_hours=$(( (current_time - file_age) / 3600 ))
    
    if [[ $age_hours -lt $ttl_hours ]]; then
        return 0
    fi
    return 1
}

# Function to get BMAS server
get_bmas_server() {
    local server=""
    local cache_file="$HOME/.zen/tmp/current.duniter.bmas"
    local force_refresh="${1:-false}"
    
    if [[ "$force_refresh" != "true" ]] && is_file_fresh "$cache_file" "$BMAS_CACHE_TTL_HOURS"; then
        server=$(cat "$cache_file" 2>/dev/null)
        if [[ -n "$server" && "$server" != "ERROR" ]]; then
            echo "$server"
            return 0
        fi
    fi
    
    log "Getting fresh BMAS server..."
    server=$(timeout 120 ${MY_PATH}/../tools/duniter_getnode.sh "BMAS" 2>/dev/null | tail -n 1)
    
    if [[ -n "$server" && "$server" != "ERROR" ]]; then
        echo "$server" > "$cache_file"
        echo "$server"
        return 0
    fi
    return 1
}

# Validate input
G1PUB="${1:-}"
NO_CACHE="${2:-}"  # Pass "nocache" to bypass cache

if [[ -z "$G1PUB" ]]; then
    log "ERROR: PLEASE ENTER WALLET G1PUB"
    echo '{"error": "missing_pubkey"}'
    exit 1
fi

# Validate G1PUB format
if ! is_valid_g1pub "$G1PUB"; then
    log "ERROR: INVALID G1PUB format: ${G1PUB}"
    echo '{"error": "invalid_pubkey"}'
    exit 1
fi

log "Starting full balance check for $G1PUB"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"
BALANCE_FILE="$CACHE_DIR/${G1PUB}.balance.json"

# Check cache unless nocache is specified
if [[ "$NO_CACHE" != "nocache" ]] && is_file_fresh_minutes "$BALANCE_FILE" "$CACHE_TTL_MINUTES"; then
    cached_balance=$(cat "$BALANCE_FILE" 2>/dev/null)
    if echo "$cached_balance" | jq empty 2>/dev/null; then
        log "Using cached balance"
        echo "$cached_balance"
        exit 0
    else
        rm -f "$BALANCE_FILE"
    fi
fi

# Function to get balance with silkaj
get_balance() {
    local g1pub="$1"
    local server="$2"
    local balance_json=""
    
    if [[ -n "$server" ]]; then
        log "Trying silkaj balance with server: $server"
        balance_json=$(silkaj --json --endpoint "$server" money balance "$g1pub" 2>/dev/null)
    else
        log "Trying silkaj balance without specific endpoint"
        balance_json=$(silkaj --json money balance "$g1pub" 2>/dev/null)
    fi
    
    # Validate JSON response
    if echo "$balance_json" | jq empty 2>/dev/null; then
        echo "$balance_json"
        return 0
    fi
    
    return 1
}

# Get BMAS server
BMAS_SERVER=$(get_bmas_server)

# Try to get balance
RAW_BALANCE=$(get_balance "$G1PUB" "$BMAS_SERVER")

# If immediate check fails, retry with different servers
if [[ -z "$RAW_BALANCE" ]]; then
    log "Primary BMAS server failed, trying alternatives..."
    attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        NEW_SERVER=$(get_bmas_server "true")
        if [[ -n "$NEW_SERVER" && "$NEW_SERVER" != "$BMAS_SERVER" ]]; then
            RAW_BALANCE=$(get_balance "$G1PUB" "$NEW_SERVER")
            [[ -n "$RAW_BALANCE" ]] && break
        else
            RAW_BALANCE=$(get_balance "$G1PUB" "")
            [[ -n "$RAW_BALANCE" ]] && break
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 2
    done
fi

# Process the balance
if [[ -n "$RAW_BALANCE" ]] && echo "$RAW_BALANCE" | jq empty 2>/dev/null; then
    # silkaj returns amounts in centimes, convert to G1
    blockchain_centimes=$(echo "$RAW_BALANCE" | jq -r '.balances.blockchain // 0')
    pending_centimes=$(echo "$RAW_BALANCE" | jq -r '.balances.pending // 0')
    total_centimes=$(echo "$RAW_BALANCE" | jq -r '.balances.total // 0')
    
    # Validate values
    [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
    [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
    [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
    
    # Convert centimes to G1
    blockchain_g1=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
    pending_g1=$(echo "scale=2; $pending_centimes / 100" | bc -l)
    total_g1=$(echo "scale=2; $total_centimes / 100" | bc -l)
    
    # Calculate ZEN: (G1 - 1) * 10
    zen=$(echo "scale=1; ($total_g1 - 1) * 10" | bc -l)
    [[ $(echo "$zen < 0" | bc -l) -eq 1 ]] && zen="0"
    
    # Build output JSON
    OUTPUT_JSON=$(jq -n \
        --arg blockchain "$blockchain_g1" \
        --arg pending "$pending_g1" \
        --arg total "$total_g1" \
        --arg zen "$zen" \
        --arg blockchain_centimes "$blockchain_centimes" \
        --arg pending_centimes "$pending_centimes" \
        --arg total_centimes "$total_centimes" \
        '{
            blockchain: ($blockchain | tonumber),
            pending: ($pending | tonumber),
            total: ($total | tonumber),
            zen: ($zen | tonumber),
            raw: {
                blockchain_centimes: ($blockchain_centimes | tonumber),
                pending_centimes: ($pending_centimes | tonumber),
                total_centimes: ($total_centimes | tonumber)
            }
        }')
    
    # Cache result
    echo "$OUTPUT_JSON" > "$BALANCE_FILE"
    
    # Also update the simple COINS cache for compatibility with G1check.sh
    echo "$total_g1" > "$CACHE_DIR/${G1PUB}.COINS"
    
    log "Successfully retrieved balance: blockchain=$blockchain_g1 pending=$pending_g1 total=$total_g1"
    echo "$OUTPUT_JSON"
    exit 0
fi

# If all else fails
log "ERROR: Failed to get balance after all attempts"
echo '{"error": "fetch_failed", "blockchain": 0, "pending": 0, "total": 0, "zen": 0}'
exit 1
