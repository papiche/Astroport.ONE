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

## CHECKING AMOUNT
if (( $(echo "${AMOUNT} == 0" | bc -l) )); then
    log "NOTHING TO PAY... OK"
    exit 0
fi

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

## CHECKING BALANCE WITH BMAS SERVER
BMAS_SERVER=$(cat ~/.zen/tmp/current.duniter.bmas 2>/dev/null)
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    log "Attempting to get balance with silkaj (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    # Use silkaj to get balance with BMAS server if available
    if [[ -n "$BMAS_SERVER" ]]; then
        COINS=$(silkaj --json --endpoint "$BMAS_SERVER" --dunikey-file "${KEYFILE}" money balance ${ISSUERPUB} 2>/dev/null | jq -r '.balances.total')
    else
        COINS=$(silkaj --json --dunikey-file "${KEYFILE}" money balance ${ISSUERPUB} 2>/dev/null | jq -r '.balances.total')
    fi
    # silkaj balance return COINS in cents, convert to G1
    COINS=$(echo "scale=2; $COINS / 100" | bc)

    if [[ -n $COINS && "$COINS" != "null" ]]; then
        log "Successfully retrieved balance: for $ISSUERPUB : $COINS Ğ1"
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
        silkaj --endpoint "$server" --dunikey-file "${key_file}" money transfer -r ${dest_pub} -a ${amount} --reference "${comment}" --yes 2>/dev/null > ${result_file}
        ISOK=$?
    else
        silkaj --dunikey-file "${key_file}" money transfer -r ${dest_pub} -a ${amount} --reference "${comment}" --yes 2>/dev/null > ${result_file}
        ISOK=$?
    fi
    return $ISOK
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
        
    # Display silkaj result
    cat "${PENDINGDIR}/${MOATS}.result.html"
    
    # Try with different BMAS servers
    log "Attempting payment with alternative BMAS servers..."
    attempts=0
    while [[ $attempts -lt 3 ]]; do
        # Get a new BMAS server using get_bmas_server function
        NEW_SERVER=$(get_bmas_server)
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
            sleep 2
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
    
    # Generate beautiful HTML report
    cat << EOF > ${PENDINGDIR}/${MOATS}.result.html
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Transaction ZEN - ${COMMENT}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        
        .header .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .content {
            padding: 40px;
        }
        
        .transaction-info {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            border-left: 5px solid #4facfe;
        }
        
        .amount-display {
            text-align: center;
            margin-bottom: 30px;
        }
        
        .amount {
            font-size: 3em;
            font-weight: bold;
            color: #4facfe;
            text-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .currency {
            font-size: 1.2em;
            color: #666;
            margin-top: 10px;
        }
        
        .transaction-flow {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin: 30px 0;
            flex-wrap: wrap;
            gap: 20px;
        }
        
        .wallet-card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            flex: 1;
            min-width: 250px;
            border: 2px solid #e9ecef;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .wallet-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.15);
        }
        
        .wallet-card.source {
            border-color: #ff6b6b;
        }
        
        .wallet-card.destination {
            border-color: #51cf66;
        }
        
        .wallet-label {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .wallet-address {
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            color: #333;
            word-break: break-all;
            margin-bottom: 15px;
            background: #f8f9fa;
            padding: 10px;
            border-radius: 8px;
        }
        
        .wallet-balance {
            font-size: 1.5em;
            font-weight: bold;
            color: #4facfe;
        }
        
        .arrow {
            font-size: 2em;
            color: #4facfe;
            margin: 0 20px;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .links {
            display: flex;
            gap: 15px;
            margin-top: 15px;
            flex-wrap: wrap;
        }
        
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #4facfe;
            color: white;
            text-decoration: none;
            border-radius: 25px;
            font-size: 0.9em;
            transition: all 0.3s ease;
            box-shadow: 0 3px 10px rgba(79, 172, 254, 0.3);
        }
        
        .btn:hover {
            background: #3d8bfe;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(79, 172, 254, 0.4);
        }
        
        .btn.secondary {
            background: #6c757d;
        }
        
        .btn.secondary:hover {
            background: #5a6268;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
        
        .status-badge {
            display: inline-block;
            padding: 8px 16px;
            background: #51cf66;
            color: white;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: bold;
            margin-bottom: 20px;
        }
        
        .comment {
            background: #e3f2fd;
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
            border-left: 4px solid #4facfe;
            font-style: italic;
            color: #1976d2;
        }
        
        @media (max-width: 768px) {
            .transaction-flow {
                flex-direction: column;
            }
            
            .arrow {
                transform: rotate(90deg);
                margin: 20px 0;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .amount {
                font-size: 2.5em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Transaction ZEN</h1>
            <div class="subtitle">Opération blockchain réussie</div>
        </div>
        
        <div class="content">
            <div class="status-badge">✅ Transaction confirmée</div>
            
            <div class="amount-display">
                <div class="amount">${ZENAMOUNT}</div>
                <div class="currency">ZEN</div>
            </div>
            
            <div class="comment">
                <strong>Référence :</strong> ${COMMENT}
            </div>
            
            <div class="transaction-flow">
                <div class="wallet-card source">
                    <div class="wallet-label">💰 Portefeuille source</div>
                    <div class="wallet-address">${ISSUERPUB}</div>
                    <div class="wallet-balance">${ZENCUR} ZEN</div>
                    <div class="links">
                        <a href="${CESIUMIPFS}/#/app/wot/tx/${ISSUERPUB}/" class="btn" target="_blank">📊 Cesium</a>
                        <a href="$myUPLANET/g1gate/?pubkey=${ISSUERPUB}" class="btn secondary" target="_blank">🔍 Scanner</a>
                    </div>
                </div>
                
                <div class="arrow">➡️</div>
                
                <div class="wallet-card destination">
                    <div class="wallet-label">🎯 Portefeuille destination</div>
                    <div class="wallet-address">${G1PUB}</div>
                    <div class="wallet-balance">${ZENDES} ZEN</div>
                    <div class="links">
                        <a href="${CESIUMIPFS}/#/app/wot/tx/${G1PUB}/" class="btn" target="_blank">📊 Cesium</a>
                        <a href="$myUPLANET/g1gate/?pubkey=${G1PUB}" class="btn secondary" target="_blank">🔍 Scanner</a>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Transaction traitée le $(date '+%d/%m/%Y à %H:%M:%S')</p>
            <p>ID de transaction : ${MOATS}</p>
        </div>
    </div>
</body>
</html>
EOF

    ## TODO REMOVE : monitor 
    $MY_PATH/mailjet.sh --expire 48h "$CAPTAINEMAIL" ${PENDINGDIR}/${MOATS}.result.html "${ZENAMOUNT} ZEN : ${COMMENT}"



    exit 0
fi

exit 1