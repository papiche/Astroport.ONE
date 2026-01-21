#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1primal.sh
#~ Get the primal (first) transaction source for a G1 wallet
#~ Uses cache permanently (primal never changes once set)
#~ Returns: primal source pubkey (or empty if not found)
#~ With --json flag: returns full silkaj JSON response
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Constants
MAX_RETRIES=3
CACHE_DIR="$HOME/.zen/tmp/coucou"
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

# Get cached primal if valid
get_cached_primal() {
    local cache_file="$1"
    
    if [[ -s "$cache_file" ]]; then
        local cached_value=$(cat "$cache_file" 2>/dev/null | head -n 1)
        if is_valid_g1pub "$cached_value"; then
            log "Using cached primal: $cached_value"
            echo "$cached_value"
            return 0
        else
            log "Cached primal is invalid, removing corrupted cache"
            rm -f "$cache_file"
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

# Function to get primal with retries using silkaj
get_primal_from_blockchain() {
    local g1pub="$1"
    local server="$2"
    local json_mode="$3"
    local retries=0
    local primal=""
    local silkaj_output=""
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        # Use silkaj to get primal with specific BMAS server
        if [[ -n "$server" ]]; then
            log "Trying silkaj primal with server: $server"
            silkaj_output=$(silkaj --endpoint "$server" --json money primal "$g1pub" 2>/dev/null)
        else
            log "Trying silkaj primal without specific endpoint"
            silkaj_output=$(silkaj --json money primal "$g1pub" 2>/dev/null)
        fi
        
        # Check if we got valid JSON
        if [[ -n "$silkaj_output" ]] && echo "$silkaj_output" | jq empty 2>/dev/null; then
            primal=$(echo "$silkaj_output" | jq -r '.primal_source_pubkey // empty' 2>/dev/null)
            
            if is_valid_g1pub "$primal"; then
                log "Retrieved primal: $primal"
                if [[ "$json_mode" == "true" ]]; then
                    echo "$silkaj_output"
                else
                    echo "$primal"
                fi
                return 0
            else
                log "Invalid primal from server: $server (got: $primal)"
            fi
        else
            log "Failed to get primal from server: $server"
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
JSON_MODE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE="true"
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
    echo "Usage: $0 [--json] <g1pub>"
    exit 1
fi

if ! is_valid_g1pub "$G1PUB"; then
    log "ERROR: INVALID G1PUB FORMAT: ${G1PUB}"
    exit 1
fi

log "Starting primal check for $G1PUB"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"
PRIMALFILE="$CACHE_DIR/${G1PUB}.primal"

# Primal is permanent (never changes), so check cache first
cached_primal=$(get_cached_primal "$PRIMALFILE")
if [[ $? -eq 0 ]]; then
    if [[ "$JSON_MODE" == "true" ]]; then
        # Return JSON format for compatibility
        echo "{\"primal_source_pubkey\": \"$cached_primal\"}"
    else
        echo "$cached_primal"
    fi
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

# Try to get primal with BMAS server
RESULT=$(get_primal_from_blockchain "$G1PUB" "$BMAS_SERVER" "$JSON_MODE")

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
            result=$(get_primal_from_blockchain "$G1PUB" "$NEW_SERVER" "$JSON_MODE")
            if [[ -n "$result" ]]; then
                RESULT="$result"
                break
            fi
        else
            log "No different server available, trying without specific endpoint"
            result=$(get_primal_from_blockchain "$G1PUB" "" "$JSON_MODE")
            if [[ -n "$result" ]]; then
                RESULT="$result"
                break
            fi
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 2
    done
fi

# If we got a valid result, save to cache and output
if [[ -n "$RESULT" ]]; then
    # Extract primal for caching (even if JSON mode)
    if [[ "$JSON_MODE" == "true" ]]; then
        primal_to_cache=$(echo "$RESULT" | jq -r '.primal_source_pubkey // empty' 2>/dev/null)
    else
        primal_to_cache="$RESULT"
    fi
    
    if is_valid_g1pub "$primal_to_cache"; then
        log "Caching primal: $primal_to_cache"
        echo "$primal_to_cache" > "$PRIMALFILE"
        chmod 644 "$PRIMALFILE"
    fi
    
    echo "$RESULT"
    exit 0
fi

# If all else fails, return empty
log "ERROR: Failed to get primal after all attempts"
echo ""
exit 1
