#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# MAKE PAYMENTS ON DUNITER BLOCKCHAIN
# VERIFY SUCCESS & RENEW IF FAILED
########################################################################
# set -euo pipefail  # Stricter error handling

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

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

# Get balance with retry mechanism
MAX_RETRIES=3
RETRY_COUNT=0
COINS=""

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    log "Attempting to get balance (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    COINS=$($MY_PATH/COINScheck.sh ${ISSUERPUB} | tail -n 1)
    if [[ -n $COINS ]]; then
        log "Successfully retrieved balance: $COINS"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 2
done

if [[ -z $COINS ]]; then
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
    
    log "Attempting payment with amount: $amount to: $dest_pub"
    ${MY_PATH}/jaklis/jaklis.py -k ${key_file} pay -a ${amount} -p ${dest_pub} -c "${comment}" -m 2>/dev/null > ${result_file}
    return $?
}

# First attempt
make_payment "${PENDINGDIR}/${MOATS}.key" "${AMOUNT}" "${G1PUB}" "${COMMENT}" "${PENDINGDIR}/${MOATS}.result.html"
ISOK=$?

if [[ ${ISOK} != 0 ]]; then
    log "(╥☁╥ ) TRANSACTION ERROR (╥☁╥ )"
    
    # Check for insufficient balance
    if grep -q "insufficient balance" "${PENDINGDIR}/${MOATS}.result.html"; then
        log "ERROR: Insufficient balance"
        exit 1
    fi
    
    # Try with different GVA server
    log "Attempting to get alternative GVA server..."
    attempts=0
    while [[ $attempts -lt 3 ]]; do
        GVA=$(${MY_PATH}/../tools/duniter_getnode.sh | tail -n 1)
        if [[ ! -z $GVA ]]; then
            sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env
            echo "NODE=$GVA" >> ${MY_PATH}/../tools/jaklis/.env
            log "Switching to new GVA NODE: $GVA"
            break
        fi
        attempts=$((attempts + 1))
        log "Failed to get GVA server, attempt $attempts of 3"
        sleep 1
    done
    
    if [[ -z $GVA ]]; then
        log "ERROR: Failed to get GVA server after 3 attempts"
    fi
        # Second attempt with new server
        make_payment "${PENDINGDIR}/${MOATS}.key" "${AMOUNT}" "${G1PUB}" "${COMMENT}" "${PENDINGDIR}/${MOATS}.result.html"
        ISOK=$?
    else
        log "ERROR: Could not get alternative GVA server"
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
EOF

    log "Sending email notification..."
    $MY_PATH/mailjet.sh "support@qo-op.com" ${PENDINGDIR}/${MOATS}.result.html "${ZENAMOUNT} ZEN : ${COMMENT}"
    
    # Cleanup
    log "Cleaning up temporary files..."
    rm -Rf ${PENDINGDIR}
    log "Payment process completed successfully"
    exit 0
else
    log "TRANSACTION FAILED AFTER ALL ATTEMPTS"
    exit 1
fi
