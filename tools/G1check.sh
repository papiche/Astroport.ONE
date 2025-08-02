#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1check.sh
#~ Indiquez une clef publique G1.
#~ Il verifie le montant présent dans le cache
#~ ou le raffraichi quand il est plus ancien que 24H
#~ Utilise silkaj au lieu de jaklis.py
#~ Utilise les serveurs BMAS sélectionnés par duniter_getnode.sh
################################################################################
# set -euo pipefail  # Stricter error handling

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Constants
MAX_RETRIES=3
CACHE_DIR="$HOME/.zen/tmp/coucou"
BACKUP_DIR="$HOME/.zen/tmp"
CACHE_COINS_LIMIT=7
BACKUP_AGE_DAYS=1
CACHE_TTL_HOURS=24  # Cache TTL in hours
BMAS_CACHE_TTL_HOURS=6  # BMAS server cache TTL in hours

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to output final result, converting to ZEN if requested
output_result() {
    local balance="$1"
    local is_zen_request="$2"

    if [[ "$is_zen_request" == "true" ]]; then
        if validate_balance "$balance"; then
            # Formula: (COINS - 1) * 10, integer part
            local zen_value=$(echo "($balance - 1) * 10" | bc | cut -d '.' -f 1)
            log "Calculated ZEN value: $zen_value from G1 balance: $balance"
            echo "$zen_value"
        else
            log "Invalid balance '$balance' for ZEN calculation. Returning empty."
            echo "" # Return empty for invalid balance
        fi
    else
        echo "$balance"
    fi
}

# Validate if a value is a valid balance (numeric)
validate_balance() {
    local value="$1"
    if [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]] && [[ $(echo "$value >= 0" | bc -l) -eq 1 ]]; then
        return 0
    fi
    return 1
}

# Check if file is within TTL
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

# Get cached balance if fresh and valid
get_cached_balance() {
    local cache_file="$1"
    
    if is_file_fresh "$cache_file" "$CACHE_TTL_HOURS"; then
        local cached_value=$(cat "$cache_file" 2>/dev/null)
        if validate_balance "$cached_value"; then
            log "Using fresh cached balance: $cached_value"
            echo "$cached_value"
            return 0
        else
            log "Cached value is invalid, removing corrupted cache"
            rm -f "$cache_file"
        fi
    fi
    return 1
}

# Create timestamped backup
create_backup() {
    local g1pub="$1"
    local value="$2"
    local timestamp=$(date +%s)
    local backup_file="$BACKUP_DIR/backup.${g1pub}.${timestamp}"
    
    echo "$value" > "$backup_file"
    # Keep only the most recent backup, remove older ones
    find "$BACKUP_DIR" -name "backup.${g1pub}.*" -type f | sort -r | tail -n +2 | xargs rm -f
    log "Created backup: $backup_file"
}

# Get most recent backup
get_backup_balance() {
    local g1pub="$1"
    local latest_backup=$(find "$BACKUP_DIR" -name "backup.${g1pub}.*" -type f 2>/dev/null | sort -r | head -n 1)
    
    if [[ -n "$latest_backup" && -s "$latest_backup" ]]; then
        local backup_value=$(cat "$latest_backup" 2>/dev/null)
        if validate_balance "$backup_value"; then
            log "Using backup balance: $backup_value"
            echo "$backup_value"
            return 0
        else
            log "Backup value is invalid, removing corrupted backup"
            rm -f "$latest_backup"
        fi
    fi
    return 1
}

# Validate input
G1PUB_ORIGINAL="${1:-}"
if [[ -z "$G1PUB_ORIGINAL" ]]; then
    log "ERROR: PLEASE ENTER WALLET G1PUB"
    exit 1
fi

IS_ZEN="false"
if [[ "$G1PUB_ORIGINAL" == *":ZEN" ]]; then
    IS_ZEN="true"
    G1PUB=$(echo "$G1PUB_ORIGINAL" | sed 's/:ZEN$//')
    log "ZEN calculation requested for $G1PUB"
else
    G1PUB="$G1PUB_ORIGINAL"
fi

log "Starting balance check for $G1PUB using silkaj with BMAS servers"

# Get IPFS address
ASTROTOIPFS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${G1PUB} 2>/dev/null)
if [[ -z "${ASTROTOIPFS}" ]]; then
    log "ERROR: INVALID G1PUB: ${G1PUB}"
    exit 1
fi

log "G1CHECK ${G1PUB} (/ipns/${ASTROTOIPFS})"

#######################################################
## CLEANING OLD CACHE FILES
log "Cleaning old cache files..."
# Remove old .COINS files
find "$CACHE_DIR" -mtime +$CACHE_COINS_LIMIT -type f -name "*.COINS" -exec rm -f '{}' \;

# Clean old backup files (keep only recent ones per G1PUB)
for g1pub_pattern in $(find "$BACKUP_DIR" -name "backup.*.*" -type f | sed 's/.*backup\.\([^.]*\)\..*/\1/' | sort -u); do
    find "$BACKUP_DIR" -name "backup.${g1pub_pattern}.*" -type f | sort -r | tail -n +6 | xargs rm -f
done

# Clean old BMAS cache if expired
bmas_cache_file="$HOME/.zen/tmp/current.duniter.bmas"
if [[ -f "$bmas_cache_file" ]] && ! is_file_fresh "$bmas_cache_file" "$BMAS_CACHE_TTL_HOURS"; then
    log "Removing expired BMAS cache"
    rm -f "$bmas_cache_file"
fi
#######################################################

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"
COINSFILE="$CACHE_DIR/${G1PUB}.COINS"

# First, try to get fresh cached balance
cached_balance=$(get_cached_balance "$COINSFILE")
if [[ $? -eq 0 ]]; then
    output_result "$cached_balance" "$IS_ZEN"
    exit 0
fi

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

# Function to check balance with retries using silkaj
check_balance() {
    local g1pub="$1"
    local server="$2"
    local retries=0
    local balance=""
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        # Use silkaj to get balance with specific BMAS server
        if [[ -n "$server" ]]; then
            log "Trying silkaj with server: $server"
            balance=$(silkaj --json --endpoint "$server" money balance "$g1pub" 2>/dev/null | jq -r '.balances.total')
        else
            log "Trying silkaj without specific endpoint"
            balance=$(silkaj --json money balance "$g1pub" 2>/dev/null | jq -r '.balances.total')
        fi
        
        # Convert centimes to full Ğ1 units (divide by 100)
        if [[ "$balance" != "" && "$balance" != "null" ]]; then
            balance=$(echo "scale=2; $balance / 100" | bc -l)
            log "Retrieved balance: $balance"
            echo "$balance"
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

# Get BMAS server
log "Getting BMAS server from cache..."
BMAS_SERVER=$(get_bmas_server)
if [[ -n "$BMAS_SERVER" ]]; then
    log "Using BMAS server for silkaj: $BMAS_SERVER"
else
    log "No BMAS server available, will try without specific endpoint"
fi

# Try to get balance with BMAS server
CURCOINS=$(check_balance "$G1PUB" "$BMAS_SERVER")

# If immediate check fails, try with different servers
if [[ -z "$CURCOINS" ]]; then
    log "Primary BMAS server failed, trying alternative servers..."
    attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        # Try to get a new BMAS server (force refresh)
        NEW_SERVER=$(get_bmas_server "true")
        if [[ -n "$NEW_SERVER" && "$NEW_SERVER" != "$BMAS_SERVER" ]]; then
            log "Trying with new BMAS server: $NEW_SERVER"
            
            # Retry with new server
            balance=$(check_balance "$G1PUB" "$NEW_SERVER")
            if [[ "$balance" != "" ]]; then
                CURCOINS="$balance"
                break
            fi
        else
            log "No different server available, trying without specific endpoint"
            balance=$(check_balance "$G1PUB" "")
            if [[ "$balance" != "" ]]; then
                CURCOINS="$balance"
                break
            fi
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 2
    done
fi

# If we got a valid balance, save it to cache and create backup
if [[ "$CURCOINS" != "" ]] && validate_balance "$CURCOINS"; then
    log "Successfully retrieved balance: $CURCOINS"
    echo "$CURCOINS" > "$COINSFILE"
    create_backup "$G1PUB" "$CURCOINS"
    output_result "$CURCOINS" "$IS_ZEN"
    exit 0
fi

# If we still don't have a balance, try to use backup value
log "Failed to get fresh balance, trying backup..."
backup_balance=$(get_backup_balance "$G1PUB")
if [[ $? -eq 0 ]]; then
    output_result "$backup_balance" "$IS_ZEN"
    exit 0
fi

# If all else fails, return empty
log "ERROR: Failed to get balance after all attempts"
echo ""
exit 1
