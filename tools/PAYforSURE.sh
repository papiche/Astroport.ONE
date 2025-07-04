#!/bin/bash
########################################################################
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# MAKE PAYMENTS ON DUNITER BLOCKCHAIN USING SILKAJ
# VERIFY SUCCESS & RENEW IF FAILED
# Utilise les serveurs BMAS sélectionnés par duniter_getnode.sh
########################################################################
# set -euo pipefail  # Stricter error handling

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Check silkaj version and fallback to PAY4SURE.sh if needed
check_silkaj_version() {
    if command -v silkaj >/dev/null 2>&1; then
        local version=$(silkaj -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if [[ -n "$version" ]]; then
            local major=$(echo "$version" | cut -d. -f1)
            local minor=$(echo "$version" | cut -d. -f2)
            
            # Check if version is less than 0.20
            if [[ $major -eq 0 && $minor -lt 20 ]]; then
                echo "silkaj version $version detected, falling back to PAY4SURE.sh"
                return 1
            fi
        fi
    else
        echo "silkaj not found, falling back to PAY4SURE.sh"
        return 1
    fi
    return 0
}

# If silkaj version is too old, call PAY4SURE.sh with same parameters
if ! check_silkaj_version; then
    if [[ -f "${MY_PATH}/PAY4SURE.sh" ]]; then
        exec "${MY_PATH}/PAY4SURE.sh" "$@"
    else
        echo "ERROR: PAY4SURE.sh not found in ${MY_PATH}"
        exit 1
    fi
fi

# Log function for better debugging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Validate required arguments
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <keyfile> <amount> <g1pub> [comment] [moats]"
    exit 1
fi

KEYFILE="$1"
AMOUNT="$2"
G1PUB="$3"
COMMENT="${4:-}"
MOATS="${5:-}"

log "Starting payment process with parameters:"
log "AMOUNT=${AMOUNT}"
log "DESTG1PUB=${G1PUB}"
log "COMMENT=${COMMENT}"

[[ -z $MOATS ]] \
    && MOATS=$(date -u +"%Y%m%d%H%M%S%4N") \
    || log "OLD PAYMENT FAILURE = NEW TRY $MOATS"

## CHECKING ISSUER WALLET (dunikey file)
if [[ ! -s ${KEYFILE} ]]; then
    log "ERROR : MISSING SECRET DUNIKEY FILE - EXIT -"
    exit 1
fi

ISSUERPUB=$(cat ${KEYFILE} | grep "pub:" | cut -d ' ' -f 2)
if [[ -z ${ISSUERPUB} ]]; then
    log "CANNOT EXTRACT ISSUERPUB FROM DUNIKEY - EXIT -"
    exit 1
fi

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

# Get balance with retry mechanism using silkaj with BMAS server
MAX_RETRIES=3
RETRY_COUNT=0
COINS=""

# Get BMAS server
log "Getting BMAS server from cache..."
BMAS_SERVER=$(cat ~/.zen/tmp/current.duniter.bmas 2>/dev/null)
if [[ -n "$BMAS_SERVER" ]]; then
    log "Using BMAS server for silkaj: $BMAS_SERVER"
else
    log "Failed to get BMAS server, using new silkaj endpoint"
    BMAS_SERVER=$(get_bmas_server)
fi

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    log "Attempting to get balance with silkaj (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    
    # Use silkaj to get balance with BMAS server if available
    if [[ -n "$BMAS_SERVER" ]]; then
        COINS=$(silkaj --json --endpoint "$BMAS_SERVER" --dunikey-file "${KEYFILE}" money balance ${ISSUERPUB} 2>/dev/null | jq -r '.balances.total')
    else
        COINS=$(silkaj --json --dunikey-file "${KEYFILE}" money balance ${ISSUERPUB} 2>/dev/null | jq -r '.balances.total')
    fi
    
    if [[ -n $COINS && "$COINS" != "null" ]]; then
        log "Successfully retrieved balance: $COINS"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    BMAS_SERVER=$(get_bmas_server)
    sleep 2
done

if [[ -z $COINS || "$COINS" == "null" ]]; then
    log "ERROR : ${ISSUERPUB}=$COINS EMPTY WALLET - EXIT -"
    exit 1
fi

###### TEST INPUT VALUES
[[ $AMOUNT == "ALL" ]] && AMOUNT=$COINS ## ALL MEAN EMPTY ORIGIN WALLET
[[ -z $AMOUNT ]] && log "ERROR : ${ISSUERPUB}=$COINS MISSING AMOUNT - EXIT -" && exit 1

# Validate amount format
if ! [[ $AMOUNT =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    log "ERROR NOT a valid AMOUNT : ${AMOUNT} - EXIT -"
    exit 1
fi

# Check sufficient balance
if [[ "$COINS" != "null" && $(echo "$COINS < $AMOUNT" | bc -l) -eq 1 ]]; then
    log "ERROR : SOURCE WALLET ${ISSUERPUB} IS MISSING COINS !!! $AMOUNT > $COINS - EXIT -"
    exit 1
fi

[[ -z $G1PUB ]] && log "ERROR : ${ISSUERPUB}=$COINS ($AMOUNT) MISSING DESTINATION - EXIT -" && exit 1

log "Payment processor ID: ${MOATS}"
log "${ISSUERPUB} : (${AMOUNT}) -> ${G1PUB}"

[[ -z $COMMENT ]] && COMMENT="UPLANET${UPLANETG1PUB:0:8}:ZEN:${MOATS}"

PENDINGDIR=$HOME/.zen/tmp/${ISSUERPUB}
mkdir -p $PENDINGDIR

# Copy key file to pending directory
cp "${KEYFILE}" "${PENDINGDIR}/${MOATS}.key"
if [[ ! -s "${PENDINGDIR}/${MOATS}.key" ]]; then
    log "ERROR: Failed to copy key file to pending directory"
    exit 1
fi

################################################
# MAKE PAYMENT
log "Initiating payment process..."

function make_payment() {
    local key_file="$1"
    local amount="$2"
    local dest_pub="$3"
    local comment="$4"
    local result_file="$5"
    local server="$6"
    
    log "Attempting payment with silkaj: amount: $amount to: $dest_pub"
    # Utiliser le fichier dunikey directement
    if [[ -n "$server" ]]; then
        silkaj --json --endpoint "$server" --dunikey-file "${key_file}" money transfer -r ${dest_pub} -a ${amount} --reference "${comment}" 2>/dev/null | jq -r '.txid' > ${result_file}
    else
        silkaj --json --dunikey-file "${key_file}" money transfer -r ${dest_pub} -a ${amount} --reference "${comment}" 2>/dev/null | jq -r '.txid' > ${result_file}
    fi
    return $?
}

# Get fresh BMAS server for payment
log "Getting BMAS server for payment..."
PAYMENT_SERVER=$(cat ~/.zen/tmp/current.duniter.bmas 2>/dev/null)
if [[ -n "$PAYMENT_SERVER" ]]; then
    log "Using BMAS server for payment: $PAYMENT_SERVER"
else 
    log "Failed to get BMAS server for payment, using new silkaj endpoint"
    PAYMENT_SERVER=$(get_bmas_server)
    log "Using new BMAS server for payment: $PAYMENT_SERVER"
fi

# First attempt
make_payment "${PENDINGDIR}/${MOATS}.key" "${AMOUNT}" "${G1PUB}" "${COMMENT}" "${PENDINGDIR}/${MOATS}.result.html" "$PAYMENT_SERVER"
ISOK=$?

if [[ ${ISOK} != 0 ]]; then
    log "(╥☁╥ ) TRANSACTION ERROR (╥☁╥ )"
    
    # Check for insufficient balance
    if grep -q "insufficient balance" "${PENDINGDIR}/${MOATS}.result.html"; then
        log "ERROR: Insufficient balance"
        exit 1
    fi
    
    # Try with different BMAS servers
    log "Attempting payment with alternative BMAS servers..."
    attempts=0
    while [[ $attempts -lt 3 ]]; do
        # Get a new BMAS server
        NEW_SERVER=$(cat ~/.zen/tmp/current.duniter.bmas 2>/dev/null)
        if [[ -n "$NEW_SERVER" ]]; then
            log "Trying payment with BMAS server: $NEW_SERVER"
            make_payment "${PENDINGDIR}/${MOATS}.key" "${AMOUNT}" "${G1PUB}" "${COMMENT}" "${PENDINGDIR}/${MOATS}.result.html" "$NEW_SERVER"
            ISOK=$?
            
            if [[ $ISOK == 0 ]]; then
                log "Payment successful with alternative BMAS server"
                break
            fi
        fi
        
        attempts=$((attempts + 1))
        if [[ $attempts -lt 3 ]]; then
            log "Payment failed, trying next BMAS server (attempt $attempts of 3)"
            NEW_SERVER=$(get_bmas_server)
        fi
    done

    if [[ $ISOK != 0 ]]; then
        log "ERROR: Payment failed with all BMAS servers"
        exit 1
    fi
fi

if [[ ${ISOK} == 0 ]]; then
    log "TRANSACTION SENT SUCCESSFULLY"
    
    ## ACCESS COINS value CACHE
    COINSFILE="$HOME/.zen/tmp/coucou/${ISSUERPUB}.COINS"
    DESTFILE="$HOME/.zen/tmp/coucou/${G1PUB}.COINS"
    
    ## Apply TX : DECREASE SOURCE IN "coucou" CACHE
    ## SOURCE WALLET
    if [[ "$COINS" != "null" ]]; then
        echo "$COINS - $AMOUNT" | bc > ${COINSFILE}
    else
        echo "0" > ${COINSFILE}
    fi
    
    DES=$(cat ${DESTFILE}) ## DESTINATION WALLET
    if [[ ${DES} != "" && ${DES} != "null" ]]; then
        echo "$DES + $AMOUNT" | bc > ${DESTFILE}
    else
        echo "${AMOUNT}" > ${DESTFILE}
        DES=${AMOUNT}
    fi
    
    ## ZEN CONVERSION
    ZENAMOUNT=$(echo "$AMOUNT * 10" | bc | cut -d '.' -f 1)
    ZENCUR=$(echo "$COINS * 10" | bc | cut -d '.' -f 1)
    ZENDES=$(echo "$DES * 10" | bc | cut -d '.' -f 1)
    
    # Generate HTML report
    cat << EOF > ${PENDINGDIR}/${MOATS}.result.html
<html>
<head>
    <meta charset='UTF-8'>
    <title>${COMMENT}</title>
    <style>
        body { font-family: 'Courier New', monospace; }
        pre { white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>${ZENAMOUNT} ZEN OPERATION</h1>
    ${COMMENT}
    <h3>
        <a title='CESIUM' href='${CESIUMIPFS}/#/app/wot/tx/${ISSUERPUB}/'>${ISSUERPUB}</a>
        (<a href='$myUPLANET/g1gate/?pubkey=${ISSUERPUB}'>SCAN</a>) : ${ZENCUR} ZEN
        <br> //--->> 
        <a title='CESIUM' href='${CESIUMIPFS}/#/app/wot/tx/${G1PUB}/'>${G1PUB}</a>
        (<a href='$myUPLANET/g1gate/?pubkey=${G1PUB}'>SCAN</a>) : ${ZENDES} ZEN
    </h3>
</body>
</html>
