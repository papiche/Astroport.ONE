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
CACHE_AGE_DAYS=30
BACKUP_AGE_DAYS=1

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Validate input
G1PUB="${1:-}"
if [[ -z "$G1PUB" ]]; then
    log "ERROR: PLEASE ENTER WALLET G1PUB"
    exit 1
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
find "$CACHE_DIR" -mtime +$CACHE_AGE_DAYS -type f -name "*.COINS" -exec rm -f '{}' \;
find "$BACKUP_DIR" -mtime +$BACKUP_AGE_DAYS -type f -name "${G1PUB}.COINS" -exec mv '{}' "$BACKUP_DIR/backup.${G1PUB}" \;
#######################################################

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"
COINSFILE="$CACHE_DIR/${G1PUB}.COINS"

#######################################################
## GET EXTERNAL G1 DATA
${MY_PATH}/../tools/GetGCAttributesFromG1PUB.sh ${G1PUB}
#######################################################

# Function to get BMAS server using duniter_getnode.sh
get_bmas_server() {
    local server=""
    server=$(${MY_PATH}/../tools/duniter_getnode.sh "BMAS" 2>/dev/null | tail -n 1)
    if [[ -n "$server" && "$server" != "ERROR" ]]; then
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
            balance=$(silkaj --endpoint "$server" money balance "$g1pub" 2>/dev/null | grep "Total balance" | sed 's/.*│ //' | sed 's/ Ğ1.*//')
        else
            balance=$(silkaj money balance "$g1pub" 2>/dev/null | grep "Total balance" | sed 's/.*│ //' | sed 's/ Ğ1.*//')
        fi
        
        if [[ "$balance" != "" ]]; then
            echo "$balance"
            return 0
        fi
        retries=$((retries + 1))
        [[ $retries -lt $MAX_RETRIES ]] && sleep 1
    done
    return 1
}

# Get BMAS server
log "Getting BMAS server from duniter_getnode.sh..."
BMAS_SERVER=$(get_bmas_server)
if [[ -n "$BMAS_SERVER" ]]; then
    log "Using BMAS server: $BMAS_SERVER"
else
    log "Failed to get BMAS server, using default silkaj endpoint"
fi

# Try to get balance with BMAS server
CURCOINS=$(check_balance "$G1PUB" "$BMAS_SERVER")

# If immediate check fails, try with different servers
if [[ -z "$CURCOINS" ]]; then
    log "Primary BMAS server failed, trying alternative servers..."
    attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        # Try to get a new BMAS server
        NEW_SERVER=$(get_bmas_server)
        if [[ -n "$NEW_SERVER" && "$NEW_SERVER" != "$BMAS_SERVER" ]]; then
            log "Trying with new BMAS server: $NEW_SERVER"
            
            # Retry with new server
            balance=$(check_balance "$G1PUB" "$NEW_SERVER")
            if [[ "$balance" != "" ]]; then
                CURCOINS="$balance"
                break
            fi
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 1
    done
fi

# If we got a valid balance, save it to cache
if [[ "$CURCOINS" != "" ]]; then
    echo "$CURCOINS" > "$COINSFILE"
    rm -f "$BACKUP_DIR/backup.${G1PUB}" 2>/dev/null
    echo "$CURCOINS"
    exit 0
fi

# If we still don't have a balance, try to use cached value
if [[ -s "$BACKUP_DIR/backup.${G1PUB}" ]]; then
    log "Using cached backup value"
    cat "$BACKUP_DIR/backup.${G1PUB}"
    exit 0
fi

# If all else fails, return empty
log "ERROR: Failed to get balance after all attempts"
echo ""
exit 1
