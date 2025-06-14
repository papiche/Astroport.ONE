#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ COINScheck.sh
#~ Indiquez une clef publique G1.
#~ Il verifie le montant présent dans le cache
#~ ou le raffraichi quand il est plus ancien que 24H
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

log "Starting balance check for $G1PUB"

# Get IPFS address
ASTROTOIPFS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${G1PUB} 2>/dev/null)
if [[ -z "${ASTROTOIPFS}" ]]; then
    log "ERROR: INVALID G1PUB: ${G1PUB}"
    exit 1
fi

log "COINCHECK ${G1PUB} (/ipns/${ASTROTOIPFS})"

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

# Function to check balance with retries
check_balance() {
    local g1pub="$1"
    local retries=0
    local balance=""
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        balance=$(${MY_PATH}/timeout.sh -t 5 ${MY_PATH}/jaklis/jaklis.py balance -p "$g1pub")
        if [[ "$balance" != "" && "$balance" != "null" ]]; then
            echo "$balance"
            return 0
        fi
        retries=$((retries + 1))
        [[ $retries -lt $MAX_RETRIES ]] && sleep 1
    done
    return 1
}

# Try to get balance with current server
CURCOINS=$(check_balance "$G1PUB")

# If immediate check fails, try with a different GVA server
if [[ -z "$CURCOINS" ]]; then
    log "Primary server failed, attempting GVA server switch..."
    attempts=0
    while [[ $attempts -lt $MAX_RETRIES ]]; do
        GVA=$(${MY_PATH}/../tools/duniter_getnode.sh | tail -n 1)
        if [[ ! -z $GVA ]]; then
            sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env
            echo "NODE=$GVA" >> ${MY_PATH}/../tools/jaklis/.env
            log "Switched to GVA NODE: $GVA"
            
            # Retry with new server
            CURCOINS=$(check_balance "$G1PUB")
            [[ ! -z "$CURCOINS" ]] && break
        fi
        attempts=$((attempts + 1))
        [[ $attempts -lt $MAX_RETRIES ]] && sleep 1
    done
fi

# If we got a valid balance, save it to cache
if [[ "$CURCOINS" != "" && "$CURCOINS" != "null" ]]; then
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
