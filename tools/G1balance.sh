#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1balance.sh
#~ Get the full balance JSON for a G1 wallet (includes pending, blockchain, total)
#~ Unlike G1check.sh which returns just the balance number, this returns full JSON
#~ Useful for monitoring pending transactions
#~ Returns: JSON with balances.pending, balances.blockchain, balances.total (in centimes)
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Constants
MAX_RETRIES=3
BMAS_CACHE_TTL_HOURS=6

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Validate G1 pubkey format
is_valid_g1pub() {
    [[ "$1" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,44}$ ]]
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
    server=$(timeout 120 ${MY_PATH}/duniter_getnode.sh "BMAS" 2>/dev/null | tail -n 1)
    if [[ $? -eq 124 ]]; then
        log "WARNING: duniter_getnode.sh timed out after 120 seconds"
        return 1
    fi
    
    if [[ -n "$server" && "$server" != "ERROR" ]]; then
        echo "$server" > "$cache_file"
        log "Cached new BMAS server: $server"
        echo "$server"
        return 0
    fi
    return 1
}

# Function to get balance JSON with retries using silkaj
get_balance_json() {
    local g1pub="$1"
    local server="$2"
    local retries=0
    local balance_json=""
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        # Use silkaj to get balance with specific BMAS server
        if [[ -n "$server" ]]; then
            log "Trying silkaj balance with server: $server"
            balance_json=$(silkaj --json --endpoint "$server" money balance "$g1pub" 2>/dev/null)
        else
            log "Trying silkaj balance without specific endpoint"
            balance_json=$(silkaj --json money balance "$g1pub" 2>/dev/null)
        fi
        
        # Check if we got valid JSON with balances
        if [[ -n "$balance_json" ]] && echo "$balance_json" | jq -e '.balances' >/dev/null 2>&1; then
            log "Retrieved balance JSON successfully"
            echo "$balance_json"
            return 0
        else
            log "Failed to get balance from server: $server"
        fi
        
        retries=$((retries + 1))
        if [[ $retries -lt $MAX_RETRIES ]]; then
            log "Retry $retries/$MAX_RETRIES - getting new server..."
            server=$(get_bmas_server "true")
        fi
    done
    return 1
}

# Parse arguments
G1PUB=""
CONVERT_TO_G1="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --convert)
            # Convert centimes to G1 in output
            CONVERT_TO_G1="true"
            shift
            ;;
        *)
            G1PUB="$1"
            shift
            ;;
    esac
done

# Validate input
if [[ -z "$G1PUB" ]]; then
    log "ERROR: PLEASE ENTER WALLET G1PUB"
    echo "Usage: $0 [--convert] <g1pub>"
    echo "  --convert: Convert centimes to G1 in output"
    exit 1
fi

if ! is_valid_g1pub "$G1PUB"; then
    log "ERROR: INVALID G1PUB FORMAT: ${G1PUB}"
    exit 1
fi

log "Starting full balance check for $G1PUB"

# Get BMAS server
log "Getting BMAS server..."
BMAS_SERVER=$(get_bmas_server)
if [[ -n "$BMAS_SERVER" ]]; then
    log "Using BMAS server: $BMAS_SERVER"
else
    log "No BMAS server available, will try without specific endpoint"
fi

# Try to get balance JSON with BMAS server
RESULT=$(get_balance_json "$G1PUB" "$BMAS_SERVER")

# If immediate check fails, try with different servers
if [[ -z "$RESULT" ]]; then
    log "Primary BMAS server failed, trying alternative servers..."
    attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        # Try to get a new BMAS server (force refresh)
        NEW_SERVER=$(get_bmas_server "true")
        if [[ -n "$NEW_SERVER" && "$NEW_SERVER" != "$BMAS_SERVER" ]]; then
            log "Trying with new BMAS server: $NEW_SERVER"
            
            # Retry with new server
            result=$(get_balance_json "$G1PUB" "$NEW_SERVER")
            if [[ -n "$result" ]]; then
                RESULT="$result"
                break
            fi
        else
            log "No different server available, trying without specific endpoint"
            result=$(get_balance_json "$G1PUB" "")
            if [[ -n "$result" ]]; then
                RESULT="$result"
                break
            fi
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 2
    done
fi

# If we got a valid result, output it
if [[ -n "$RESULT" ]]; then
    if [[ "$CONVERT_TO_G1" == "true" ]]; then
        # Convert centimes to G1
        echo "$RESULT" | jq '{
            balances: {
                pending: ((.balances.pending // 0) / 100),
                blockchain: ((.balances.blockchain // 0) / 100),
                total: ((.balances.total // 0) / 100)
            }
        }'
    else
        # Return raw JSON (centimes)
        echo "$RESULT"
    fi
    exit 0
fi

# If all else fails, return empty JSON
log "ERROR: Failed to get balance after all attempts"
echo '{"balances": {"pending": 0, "blockchain": 0, "total": 0}}'
exit 1
