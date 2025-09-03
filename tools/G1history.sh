#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1history.sh
#~ Indiquez une clef publique G1.
#~ Il récupère l'historique des transactions en JSON
#~ Utilise silkaj au lieu de jaklis.py
#~ Utilise les serveurs BMAS sélectionnés par duniter_getnode.sh
#~ Compatible avec le format attendu par upassport.sh
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Constants
MAX_RETRIES=3
CACHE_DIR="$HOME/.zen/tmp/coucou"
CACHE_TTL_HOURS=1  # Cache TTL in hours for transaction history
BMAS_CACHE_TTL_HOURS=6  # BMAS server cache TTL in hours
DEFAULT_TX_LIMIT=25  # Default number of transactions to retrieve

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
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

# Get cached transaction history if fresh
get_cached_history() {
    local cache_file="$1"
    
    if is_file_fresh "$cache_file" "$CACHE_TTL_HOURS"; then
        if [[ -s "$cache_file" ]]; then
            # Validate JSON format
            if jq empty "$cache_file" 2>/dev/null; then
                log "Using fresh cached transaction history"
                cat "$cache_file"
                return 0
            else
                log "Cached history is invalid JSON, removing corrupted cache"
                rm -f "$cache_file"
            fi
        fi
    fi
    return 1
}

# Function to get BMAS server using duniter_getnode.sh with TTL check
get_bmas_server() {
    local server=""
    local cache_file="$HOME/.zen/tmp/current.duniter.bmas"
    local force_refresh="${1:-false}"
    
    # Check if cached BMAS server is still fresh (unless force refresh)
    if [[ "$force_refresh" != "true" ]] && is_file_fresh "$cache_file" "$BMAS_CACHE_TTL_HOURS"; then
        server=$(cat "$cache_file" 2>/dev/null)
        if [[ -n "$server" && "$server" != "ERROR" ]]; then
            echo "$server"
            return 0
        fi
    fi
    
    # Get fresh BMAS server
    log "Getting fresh BMAS server..."
    server=$(${MY_PATH}/../tools/duniter_getnode.sh "BMAS" 2>/dev/null | tail -n 1)
    if [[ -n "$server" && "$server" != "ERROR" ]]; then
        echo "$server" > "$cache_file"
        log "Cached new BMAS server: $server"
        echo "$server"
        return 0
    fi
    return 1
}

# Function to get transaction history with retries using silkaj
get_transaction_history() {
    local g1pub="$1"
    local server="$2"
    local retries=0
    local history=""
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        # Use silkaj to get transaction history with specific BMAS server
        if [[ -n "$server" ]]; then
            log "Trying silkaj history with server: $server"
            history=$(timeout 30 silkaj --json --endpoint "$server" money history "$g1pub" 2>/dev/null)
        else
            log "Trying silkaj history without specific endpoint"
            history=$(timeout 30 silkaj --json money history "$g1pub" 2>/dev/null)
        fi
        
        # Check if we got valid JSON
        if [[ -n "$history" ]] && echo "$history" | jq empty 2>/dev/null; then
            log "Retrieved transaction history successfully"
            echo "$history"
            return 0
        else
            log "Failed to get transaction history from server: $server"
        fi
        
        retries=$((retries + 1))
        if [[ $retries -lt $MAX_RETRIES ]]; then
            log "Retry $retries/$MAX_RETRIES - getting new server..."
            server=$(get_bmas_server "true")
        fi
    done
    return 1
}

# Validate input
G1PUB="${1:-}"
TX_LIMIT="${2:-$DEFAULT_TX_LIMIT}"

if [[ -z "$G1PUB" ]]; then
    log "ERROR: PLEASE ENTER WALLET G1PUB"
    exit 1
fi

log "Starting transaction history retrieval for $G1PUB using silkaj with BMAS servers"

# Get IPFS address for validation
ASTROTOIPFS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${G1PUB} 2>/dev/null)
if [[ -z "${ASTROTOIPFS}" ]]; then
    log "ERROR: INVALID G1PUB: ${G1PUB}"
    exit 1
fi

log "G1HISTORY ${G1PUB} (/ipns/${ASTROTOIPFS})"

#######################################################
## CLEANING OLD CACHE FILES
log "Cleaning old cache files..."
# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Remove old .TX.json files (older than 1 day)
find "$CACHE_DIR" -mtime +1 -type f -name "*.TX.json" -exec rm -f '{}' \;

# Clean old BMAS cache if expired
bmas_cache_file="$HOME/.zen/tmp/current.duniter.bmas"
if [[ -f "$bmas_cache_file" ]] && ! is_file_fresh "$bmas_cache_file" "$BMAS_CACHE_TTL_HOURS"; then
    log "Removing expired BMAS cache"
    rm -f "$bmas_cache_file"
fi
#######################################################

HISTORYFILE="$CACHE_DIR/${G1PUB}.TX.json"

# First, try to get fresh cached history
cached_history=$(get_cached_history "$HISTORYFILE")
if [[ $? -eq 0 ]]; then
    echo "$cached_history"
    exit 0
fi

# Get BMAS server
log "Getting BMAS server from cache..."
BMAS_SERVER=$(get_bmas_server)
if [[ -n "$BMAS_SERVER" ]]; then
    log "Using BMAS server for silkaj: $BMAS_SERVER"
else
    log "No BMAS server available, will try without specific endpoint"
fi

# Try to get transaction history with BMAS server
HISTORY_JSON=$(get_transaction_history "$G1PUB" "$BMAS_SERVER")

# If immediate check fails, try with different servers
if [[ -z "$HISTORY_JSON" ]]; then
    log "Primary BMAS server failed, trying alternative servers..."
    attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        # Try to get a new BMAS server (force refresh)
        NEW_SERVER=$(get_bmas_server "true")
        if [[ -n "$NEW_SERVER" && "$NEW_SERVER" != "$BMAS_SERVER" ]]; then
            log "Trying with new BMAS server: $NEW_SERVER"
            
            # Retry with new server
            history=$(get_transaction_history "$G1PUB" "$NEW_SERVER")
            if [[ -n "$history" ]]; then
                HISTORY_JSON="$history"
                break
            fi
        else
            log "No different server available, trying without specific endpoint"
            history=$(get_transaction_history "$G1PUB" "")
            if [[ -n "$history" ]]; then
                HISTORY_JSON="$history"
                break
            fi
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 2
    done
fi

# If we got valid history, save it to cache
if [[ -n "$HISTORY_JSON" ]] && echo "$HISTORY_JSON" | jq empty 2>/dev/null; then
    log "Successfully retrieved transaction history"
    echo "$HISTORY_JSON" > "$HISTORYFILE"
    echo "$HISTORY_JSON"
    exit 0
fi

# If all else fails, return empty JSON object
log "ERROR: Failed to get transaction history after all attempts"
echo "{}"
exit 1
