#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1primal.sh
#~ Indiquez une clef publique G1.
#~ Retourne la source primal (première transaction) du portefeuille
#~ Utilise un cache permanent (primal ne change jamais)
#~ Utilise silkaj avec les serveurs BMAS sélectionnés par duniter_getnode.sh
#~ Output JSON compatible: {"primal_source_pubkey": "xxx", "cached": true/false}
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Constants
MAX_RETRIES=3
CACHE_DIR="$HOME/.zen/tmp/coucou"
BMAS_CACHE_TTL_HOURS=6  # BMAS server cache TTL in hours

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Validate G1 public key format
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
    
    # Get fresh BMAS server with timeout
    log "Getting fresh BMAS server..."
    server=$(timeout 120 ${MY_PATH}/../tools/duniter_getnode.sh "BMAS" 2>/dev/null | tail -n 1)
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

# Output result as JSON or plain text
output_result() {
    local primal="$1"
    local cached="$2"
    local json_mode="$3"
    
    if [[ "$json_mode" == "true" ]]; then
        if [[ -n "$primal" ]] && is_valid_g1pub "$primal"; then
            echo "{\"primal_source_pubkey\": \"$primal\", \"cached\": $cached}"
        else
            echo "{\"primal_source_pubkey\": null, \"cached\": false, \"error\": \"not_found\"}"
        fi
    else
        echo "$primal"
    fi
}

# Validate input
G1PUB="${1:-}"
JSON_MODE="${2:-false}"  # Pass "json" as second arg for JSON output

if [[ -z "$G1PUB" ]]; then
    log "ERROR: PLEASE ENTER WALLET G1PUB"
    [[ "$JSON_MODE" == "json" ]] && echo '{"error": "missing_pubkey"}' && exit 1
    exit 1
fi

# Handle JSON mode argument
[[ "$JSON_MODE" == "json" || "$JSON_MODE" == "--json" ]] && JSON_MODE="true"

log "Starting primal check for $G1PUB using silkaj with BMAS servers"

# Validate G1PUB format
if ! is_valid_g1pub "$G1PUB"; then
    log "ERROR: INVALID G1PUB format: ${G1PUB}"
    [[ "$JSON_MODE" == "true" ]] && echo '{"error": "invalid_pubkey"}' && exit 1
    exit 1
fi

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"
PRIMAL_FILE="$CACHE_DIR/${G1PUB}.primal"

# Check if we have a valid cached primal (permanent cache - primal never changes)
if [[ -s "$PRIMAL_FILE" ]]; then
    cached_primal=$(cat "$PRIMAL_FILE" 2>/dev/null)
    if is_valid_g1pub "$cached_primal"; then
        log "Using cached primal: $cached_primal"
        output_result "$cached_primal" "true" "$JSON_MODE"
        exit 0
    else
        log "Cached primal is invalid, removing corrupted cache"
        rm -f "$PRIMAL_FILE"
    fi
fi

# Function to check primal with silkaj
check_primal() {
    local g1pub="$1"
    local server="$2"
    local primal=""
    
    if [[ -n "$server" ]]; then
        log "Trying silkaj primal with server: $server"
        primal_json=$(silkaj --json --endpoint "$server" money primal "$g1pub" 2>/dev/null)
    else
        log "Trying silkaj primal without specific endpoint"
        primal_json=$(silkaj --json money primal "$g1pub" 2>/dev/null)
    fi
    
    # Validate JSON response
    if echo "$primal_json" | jq empty 2>/dev/null; then
        primal=$(echo "$primal_json" | jq -r '.primal_source_pubkey // empty' 2>/dev/null)
        if is_valid_g1pub "$primal"; then
            echo "$primal"
            return 0
        fi
    fi
    
    return 1
}

# Get BMAS server
log "Getting BMAS server from cache..."
BMAS_SERVER=$(get_bmas_server)
if [[ -n "$BMAS_SERVER" ]]; then
    log "Using BMAS server for silkaj: $BMAS_SERVER"
else
    log "No BMAS server available, will try without specific endpoint"
fi

# Try to get primal with BMAS server
PRIMAL=$(check_primal "$G1PUB" "$BMAS_SERVER")

# If immediate check fails, try with different servers
if [[ -z "$PRIMAL" ]]; then
    log "Primary BMAS server failed, trying alternative servers..."
    attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        # Try to get a new BMAS server (force refresh)
        NEW_SERVER=$(get_bmas_server "true")
        if [[ -n "$NEW_SERVER" && "$NEW_SERVER" != "$BMAS_SERVER" ]]; then
            log "Trying with new BMAS server: $NEW_SERVER"
            
            primal=$(check_primal "$G1PUB" "$NEW_SERVER")
            if [[ -n "$primal" ]]; then
                PRIMAL="$primal"
                break
            fi
        else
            log "No different server available, trying without specific endpoint"
            primal=$(check_primal "$G1PUB" "")
            if [[ -n "$primal" ]]; then
                PRIMAL="$primal"
                break
            fi
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 2
    done
fi

# If we got a valid primal, save it to cache (permanent)
if [[ -n "$PRIMAL" ]] && is_valid_g1pub "$PRIMAL"; then
    log "Successfully retrieved primal: $PRIMAL"
    echo "$PRIMAL" > "$PRIMAL_FILE"
    chmod 644 "$PRIMAL_FILE"
    output_result "$PRIMAL" "false" "$JSON_MODE"
    exit 0
fi

# If all else fails, return empty
log "ERROR: Failed to get primal after all attempts"
output_result "" "false" "$JSON_MODE"
exit 1
