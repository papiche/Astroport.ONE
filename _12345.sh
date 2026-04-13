#!/bin/bash
################################################################################
# Script: Astroport Swarm Node Manager
# Version: 0.3.1
# License: AGPL-3.0
#
# Description:
# Ce script gère la publication et la synchronisation des cartes de stations
# Astroport dans un réseau décentralisé basé sur IPFS (InterPlanetary File System).
#
# Fonctionnalités principales :
# 1. Initialisation de l'identité du nœud (clés IPFS, Nostr et Duniter).
# 2. Synchronisation avec les nœuds bootstrap pour maintenir une vue à jour du réseau.
# 3. Publication périodique des métadonnées du nœud via IPNS (système de nommage IPFS).
# 4. Service HTTP sur le port 12345 pour répondre aux requêtes des autres stations.
#
# Usage :
# - Exécutez ce script en tant que démon pour maintenir la présence de votre nœud
#   dans le réseau Astroport.
# - Les données sont stockées dans ~/.zen/tmp/ et ~/.zen/game/.
#
# Dépendances :
# - IPFS (nœud local configuré et en cours d'exécution).
# - Outils supplémentaires dans ./tools/ (keygen, ipfs_to_g1.py, etc.).
# - Packages : jq, socat, curl.
#################################
# Auteur: Fred (support@qo-op.com)
# Notes :
# Ce script maintien la couche SWARM de l'essaim IPFS reliant les Astroport,
# This script scan Swarm API layer from official bootstraps
#################################################################################
MY_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "${MY_PATH}/tools/my.sh"
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi
export PATH=$HOME/.local/bin:$PATH

PORT=12345
## Seuil de péremption (12 heures) : évite de supprimer trop vite les stations si IPNS est lent
BALISE_STALE_SECONDS=$(( 12 * 60 * 60 ))
COUCHOU_CACHE="$HOME/.zen/tmp/coucou"
RESPONSE_FILE="/dev/shm/astroport_12345.http"
HANDLER_SCRIPT="$HOME/.zen/tmp/12345_handler.sh"
UPSYNC_QUEUE="$HOME/.zen/tmp/upsync_queue.txt"
HTTP_ENV_FILE="$HOME/.zen/tmp/12345_env.sh"
LAST_NODE_PUBLISH_FILE="$HOME/.zen/tmp/12345.last_publish"
LAST_SWARM_PUBLISH_FILE="$HOME/.zen/tmp/swarm/.last_publish"
LAST_NODE_STATE_FILE="$HOME/.zen/tmp/12345.state"
LAST_NODE_JSON_FILE="$HOME/.zen/tmp/12345.last.json"
SCAN_LOCK_DIR="/dev/shm/astroport_swarm_scan.lock.d"

mkdir -p "$COUCHOU_CACHE" ~/.zen/tmp/swarm ~/.zen/tmp/${IPFSNODEID}
touch "$UPSYNC_QUEUE"

read_cached_coin() {
    local pubkey="$1"
    local value
    value=$(cat "$COUCHOU_CACHE/${pubkey}.COINS" 2>/dev/null)
    [[ -z "$value" || ! "$value" =~ ^[0-9]+$ ]] && value=0
    echo "$value"
}

collect_g1check_jobs() {
    local pubs=("$@")
    if [[ ${#pubs[@]} -gt 0 ]]; then
        ("$MY_PATH/tools/G1check.sh" "${pubs[@]}" >/dev/null 2>&1 &)
    fi
}

queue_g1check_batch() {
    local pubs=()
    local seen=""
    local pub
    for pub in "$@"; do
        [[ -z "$pub" ]] && continue
        [[ " $seen " == *" $pub "* ]] && continue
        seen+=" $pub"
        pubs+=("$pub")
    done
    if [[ ${#pubs[@]} -gt 0 ]]; then
        ("$MY_PATH/tools/G1check.sh" "${pubs[@]}" >/dev/null 2>&1 &)
    fi
}

start_http_server() {
    cat > "$HTTP_ENV_FILE" << ENVEOF
export MY_PATH="$MY_PATH"
export IPFSNODEID="$IPFSNODEID"
export UPSYNC_QUEUE="$UPSYNC_QUEUE"
ENVEOF
    chmod 644 "$HTTP_ENV_FILE"

    if [[ ! -s "$HANDLER_SCRIPT" ]]; then
        cat > "$HANDLER_SCRIPT" << 'EOF'
#!/bin/bash
trap '' PIPE
source "$HOME/.zen/tmp/12345_env.sh"
ACCESS_LOG="$HOME/.zen/tmp/12345_access.log"

CLIENT_IP="${SOCAT_PEERADDR:-unknown}"
CLIENT_PORT="${SOCAT_PEERPORT:-?}"

read -r request_line
request_line="${request_line%$'\r'}"
USER_AGENT=""
HOST_HEADER=""
while IFS= read -r header; do
    header="${header%$'\r'}"
    [[ -z "$header" ]] && break
    case "$header" in
        User-Agent:*) USER_AGENT="${header#User-Agent: }" ;;
        Host:*) HOST_HEADER="${header#Host: }" ;;
    esac
done

cat /dev/shm/astroport_12345.http 2>/dev/null
SEND_RC=$?

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
if [[ $SEND_RC -ne 0 ]]; then
    echo "[$TIMESTAMP] ABORTED ${CLIENT_IP}:${CLIENT_PORT} | ${request_line} | UA: ${USER_AGENT}" >> "$ACCESS_LOG"
else
    echo "[$TIMESTAMP] ${CLIENT_IP}:${CLIENT_PORT} | ${request_line} | UA: ${USER_AGENT}" >> "$ACCESS_LOG"
fi

log_lines=$(wc -l < "$ACCESS_LOG" 2>/dev/null || echo 0)
if [[ $log_lines -gt 2000 ]]; then
    tail -n 1600 "$ACCESS_LOG" > "${ACCESS_LOG}.tmp" && mv "${ACCESS_LOG}.tmp" "$ACCESS_LOG"
fi

query=$(echo "$request_line" | sed -n 's/^GET \/\?[?]\(.*\) HTTP.*/\1/p')
if [[ -n "$query" ]]; then
    arr=(${query//[=&]/ })
    GPUB=${arr[0]}
    IPNS=${arr[1]}
    if [[ -n "$GPUB" && -n "$IPNS" ]]; then
        ASTROTOIPFS=$(${MY_PATH}/tools/g1_to_ipfs.py ${GPUB} 2>/dev/null)
        if [[ "${ASTROTOIPFS}" == "${IPNS}" ]]; then
            echo "[$TIMESTAMP] UPSYNC QUEUED: ${CLIENT_IP} G1=${GPUB:0:8}... IPNS=${IPNS: -8}" >> "$ACCESS_LOG"
            grep -qxF "$IPNS" "$UPSYNC_QUEUE" || echo "$IPNS" >> "$UPSYNC_QUEUE"
        else
            echo "[$TIMESTAMP] UPSYNC REJECTED: ${CLIENT_IP} G1/IPNS mismatch" >> "$ACCESS_LOG"
        fi
    fi
fi
EOF
        chmod +x "$HANDLER_SCRIPT"
    fi

    if [[ ! -s "$RESPONSE_FILE" ]]; then
        cat > "$RESPONSE_FILE" << EOF
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: application/json; charset=UTF-8
Connection: close

{"version":"12345.0.2","hostname":"$(myHostName)","ipfsnodeid":"${IPFSNODEID}","status":"booting","created":"$(date +%s)"}
EOF
    fi

    if ! pgrep -f "socat.*TCP4-LISTEN:${PORT}" >/dev/null 2>&1; then
        pkill -f "socat.*TCP4-LISTEN:${PORT}" 2>/dev/null
        socat TCP4-LISTEN:${PORT},reuseaddr,fork EXEC:"$HANDLER_SCRIPT" 2>/dev/null &
    fi
}

[[ -z "${IPFSNODEID}" || "${IPFSNODEID}" == "null" ]] && echo "IPFSNODEID is empty" && exit 1

start_http_server

## IDENTITÉ DU NŒUD
NODEG1PUB=$($MY_PATH/tools/ipfs_to_g1.py ${IPFSNODEID})
queue_g1check_batch "$NODEG1PUB"
NODECOINS=$(read_cached_coin "$NODEG1PUB")
NODEZEN=$(echo "scale=1; ($NODECOINS - 1) * 10" | bc)

rm -Rf ~/.zen/tmp/${IPFSNODEID}/swarm # Anti-boucle

lastrun_file=~/.zen/tmp/12345.lastrun

# Fonction pour vérifier si un peer est Astroport-Compatible
is_astroport_node() {
    local peer_id=$1
    # On tente de lire uniquement les 100 premiers octets du fichier moats via IPNS
    # Si IPNS ne répond pas ou si le fichier est absent, ce n'est pas un Astroport actif
    local check=$(ipfs --timeout 15s cat /ipns/${peer_id}/_MySwarm.moats 2>/dev/null | head -c 20)
    
    if [[ -n "$check" && "$check" =~ ^[0-9]+$ ]]; then
        return 0 # Compatible
    else
        return 1 # Incompatible
    fi
}

############################################################
##  MySwarm KEY INIT
############################################################
CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1)

if [[ ! -s ~/.zen/game/myswarm_secret.june ]]; then
    echo "## INITIALIZING MySwarm KEYS ##"
    FULL_HASH=$(cat /proc/cpuinfo | grep -Ev MHz | sha512sum | cut -d ' ' -f 1)
    SECRET1=${FULL_HASH:0:32}   # Première moitié (32 caractères)
    SECRET2=${FULL_HASH:32:64} # Deuxième moitié (32 caractères)
    ipfs key rm "MySwarm_${IPFSNODEID}" 2>/dev/null
    echo "SALT=$SECRET1 && PEPPER=$SECRET2" > ~/.zen/game/myswarm_secret.june
    chmod 600 ~/.zen/game/myswarm_secret.june
    ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/game/myswarm_secret.ipns "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}"
    chmod 600 ~/.zen/game/myswarm_secret.ipns
    ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/game/myswarm_secret.dunikey "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}"
    chmod 600 ~/.zen/game/myswarm_secret.dunikey
    ipfs key import "MySwarm_${IPFSNODEID}" -f pem-pkcs8-cleartext ~/.zen/game/myswarm_secret.ipns
    CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1 )
fi
#### Clef NODE myswarm_secret.nostr (ORACLE_SYSTEM)
if [[ ! -s ~/.zen/game/myswarm_secret.nostr ]]; then
    FULL_HASH=$(cat /proc/cpuinfo | grep -Ev MHz | sha512sum | cut -d ' ' -f 1)
    SECRET1=${FULL_HASH:0:32}   # Première moitié (32 caractères)
    SECRET2=${FULL_HASH:32:64} # Deuxième moitié (32 caractères)
    npub=$(${MY_PATH}/tools/keygen -t nostr "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}")
    hex=$(${MY_PATH}/tools/nostr2hex.py "$npub")
    nsec=$(${MY_PATH}/tools/keygen -t nostr "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}" -s)
    echo "NSEC=$nsec; NPUB=$npub; HEX=$hex" > ~/.zen/game/myswarm_secret.nostr
    chmod 600 ~/.zen/game/myswarm_secret.nostr
fi 

## NOSTR ##############################################
## CREATE ~/.zen/game/secret.nostr - YLEVEL NODE
if [[ -s ~/.zen/game/secret.june ]]; then
    source ~/.zen/game/secret.june
    # Sécurité : masquer SALT/PEPPER de ps aux via fichier credentials temporaire en RAM
    _CRED_NODE=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
    chmod 600 "$_CRED_NODE"
    trap "rm -f '$_CRED_NODE'" EXIT INT TERM
    printf '%s\n%s\n' "$SALT" "$PEPPER" > "$_CRED_NODE"
    npub=$(${MY_PATH}/tools/keygen -t nostr -i "$_CRED_NODE")
    hex=$(${MY_PATH}/tools/nostr2hex.py "$npub")
    nsec=$(${MY_PATH}/tools/keygen -t nostr -s -i "$_CRED_NODE")
    echo "NSEC=$nsec; NPUB=$npub; HEX=$hex" > ~/.zen/game/secret.nostr
    chmod 600 ~/.zen/game/secret.nostr
    echo $hex > ~/.zen/tmp/${IPFSNODEID}/HEX
fi

######################################### CAPTAIN RELATED
## RE-CREATE ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
if [[ ! -s ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr ]]; then
    DISCO=$(cat ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.disco)
    IFS='=&' read -r s salt p pepper <<< "$DISCO"
    if [[ -n $salt && -n $pepper ]]; then
        CAPTAING1PUB=$(${MY_PATH}/tools/keygen -t duniter "$salt" "$pepper")
        CAPTAINCOINS=$(read_cached_coin "$CAPTAING1PUB")
        CAPTAINZEN=$(echo "scale=1; ($CAPTAINCOINS - 1) * 10" | bc)
        captainNPUB=$(${MY_PATH}/tools/keygen -t nostr "$salt" "$pepper")
        captainHEX=$(${MY_PATH}/tools/nostr2hex.py "$captainNPUB")
        captainNSEC=$(${MY_PATH}/tools/keygen -t nostr "$salt" "$pepper" -s)
        echo "NSEC=$captainNSEC; NPUB=$captainNPUB; HEX=$captainHEX" \
            > ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
        chmod 600 ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
        mkdir -p ~/.zen/game/nostr/CAPTAIN
        echo $captainHEX > ~/.zen/game/nostr/CAPTAIN/HEX
        echo $captainHEX > ~/.zen/tmp/${IPFSNODEID}/HEX_CAPTAIN
    else
        echo "ERROR : CAPTAIN BAD DISCO DECODING" >> ~/.zen/game/nostr/$CAPTAINEMAIL/ERROR
    fi
else
    ## Get data from cache
    if [[ -n "$CAPTAING1PUB" ]]; then
        CAPTAING1=$(read_cached_coin "$CAPTAING1PUB")
        CAPTAINZEN=$(echo "scale=1; ($CAPTAING1 - 1) * 10" | bc)
    fi
    captainHEX=$(cat ~/.zen/game/nostr/$CAPTAINEMAIL/HEX)
    ## Add CAPTAIN HEX to nostr WhiteList
    mkdir -p ~/.zen/game/nostr/CAPTAIN
    echo $captainHEX > ~/.zen/game/nostr/CAPTAIN/HEX
    echo $captainHEX > ~/.zen/tmp/${IPFSNODEID}/HEX_CAPTAIN
fi
##################################################

#############################################################
## G1CHECK BATCH WARMUP
#############################################################
G1CHECK_PUBS=()
[[ -n "$NODEG1PUB" ]] && G1CHECK_PUBS+=("$NODEG1PUB")
[[ -n "$UPLANETG1PUB" ]] && G1CHECK_PUBS+=("$UPLANETG1PUB")
[[ -n "$UPLANETNAME_G1" ]] && G1CHECK_PUBS+=("$UPLANETNAME_G1")
[[ -n "$UPLANETNAME_TREASURY" ]] && G1CHECK_PUBS+=("$UPLANETNAME_TREASURY")
[[ -n "$CAPTAING1PUB" ]] && G1CHECK_PUBS+=("$CAPTAING1PUB")
[[ -n "$CAPTAIN_DEDICATED_PUB" ]] && G1CHECK_PUBS+=("$CAPTAIN_DEDICATED_PUB")
collect_g1check_jobs "${G1CHECK_PUBS[@]}"

#############################################################
## PUBLISH CHANNEL IPNS LINK
echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${CHAN}'\" />" \
    > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.$(myHostName).html
############################################################
## MAIN LOOP
############################################################
echo 0 > ~/.zen/tmp/random.sleep
###################################################################
############################################### ẑen/ẐEN TOKEN SOURCE
queue_g1check_batch "$UPLANETNAME_G1" "$UPLANETG1PUB" "$UPLANETNAME_TREASURY" "$CAPTAING1PUB"
SOURCE_G1COIN=$(read_cached_coin "$UPLANETNAME_G1")
SOURCE_ZEN=$(echo "scale=1; ($SOURCE_G1COIN - 1) * 10" | bc)

##################################### USAGE TOKEN ẑen = 0 relay wallet
UPLANETCOINS=$(read_cached_coin "$UPLANETG1PUB")
UPLANETZEN=$(echo "scale=1; ($UPLANETCOINS - 1) * 10" | bc)

####################################################################################
## Ces wallet COOP sont gérés par UPLANET.init.sh et UPLANET.official.sh 
## Quotidiennement réinitialisées par NODE et DRAGON_p2p puis raffraichis par my.sh
## REFILL TO CHECK CACHE CONFORMITY 
# UPLANETNAME_AMORTISSEMENT wallet (Amortissements - Compte 28 - Valeur Consommée)
UPLANETNAME_AMORTISSEMENT=$(cat $HOME/.zen/tmp/UPLANETNAME_AMORTISSEMENT)
# UPLANETNAME_ASSETS wallet
UPLANETNAME_ASSETS=$(cat $HOME/.zen/tmp/UPLANETNAME_ASSETS)
# UPLANETNAME_CAPITAL wallet (Immobilisations - Compte 21 - Valeur Brute)
UPLANETNAME_CAPITAL=$(cat $HOME/.zen/tmp/UPLANETNAME_CAPITAL)
# UPLANETNAME_CAPTAIN wallet (CAPTAIN_DEDICATED -- 3x1/3 collect MULTIPASS ẑen payments)
UPLANETNAME_CAPTAIN=$(cat $HOME/.zen/tmp/UPLANETNAME_CAPTAIN)
# UPLANETNAME_IMPOT wallet
UPLANETNAME_IMPOT=$(cat $HOME/.zen/tmp/UPLANETNAME_IMPOT)
# UPLANETNAME_INTRUSION wallet (external Ğ1 should always go to UPLANETNAME_G1)
UPLANETNAME_INTRUSION=$(cat $HOME/.zen/tmp/UPLANETNAME_INTRUSION)
# UPLANETNAME_RND wallet
UPLANETNAME_RND=$(cat $HOME/.zen/tmp/UPLANETNAME_RND)
# UPLANETNAME_SOCIETY wallet
UPLANETNAME_SOCIETY=$(cat $HOME/.zen/tmp/UPLANETNAME_SOCIETY)
# UPLANETNAME_TREASURY wallet
UPLANETNAME_TREASURY=$(cat $HOME/.zen/tmp/UPLANETNAME_TREASURY)

### If 12345.json is missing those values ---> meaning cache refresh is altered

####################################################################################
#### UPLANET GEOKEYS_refresh - desactivated - need more investigations (TW coding period)
# if [[ $UPLANETNAME != "0000000000000000000000000000000000000000000000000000000000000000" ]]; then
#     ${MY_PATH}/RUNTIME/GEOKEYS_refresh.sh &
# fi

###################################################################
## WILL SCAN ALL BOOSTRAP - REFRESH "SELF IPNS BALISE" - RECEIVE UPLINK ORDERS
###################################################################
## Variables globales persistantes de la boucle (définies avant le while)
UPSYNC_QUEUE="$HOME/.zen/tmp/upsync_queue.txt"
HANDLER_SCRIPT="$HOME/.zen/tmp/12345_handler.sh"
RESPONSE_FILE="/dev/shm/astroport_12345.http"
touch "$UPSYNC_QUEUE"

while true; do
    start=$(date +%s)
    MOATS=$(date +%s)

    ## Refresh Duniter node list (respects 1h TTL, copies to ~/.zen/tmp/$IPFSNODEID/duniter_nodes.json)
    ("${MY_PATH}/tools/duniter_getnode.sh" >/dev/null 2>&1 &)

    [[ -z ${myIP} ]] && source "${MY_PATH}/tools/my.sh"
    if [ -f "$lastrun_file" ]; then lastrun=$(cat "$lastrun_file"); else lastrun=0; fi
    [[ ${CHAN} == "" ]] && CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1)

    echo "/ip4/${myIP}/udp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    ## Get IP from ~/.zen/♥Box
    [[ ! -z ${zipit} ]] \
        && myIP=${zipit} \
        && echo "/ip4/${zipit}/udp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    ## Derive myDNSADDR from myIPFS (https://ipfs.DOMAIN -> ipfs.DOMAIN)
    myDNSADDR=$(echo "${myIPFS}" | sed -n 's|https://\(.*\)|\1|p')
    [[ ! -z ${myDNSADDR} ]] \
        && echo "/dnsaddr/${myDNSADDR}/udp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    if [ -f "$lastrun_file" ]; then
        lastrun=$(cat "$lastrun_file")
    else
        lastrun=0
    fi

    duree=$(( MOATS - lastrun ))
        ## TRAITEMENT DE LA QUEUE UPSYNC (Requêtes accumulées)
        if [[ -s "$UPSYNC_QUEUE" ]]; then
            echo "--- PROCESSING UPSYNC QUEUE ---"
            # On crée une copie de travail et on vide l'originale pour accepter de nouveaux spams
            mv "$UPSYNC_QUEUE" "${UPSYNC_QUEUE}.work"
            touch "$UPSYNC_QUEUE"
            
            # Sous-processus asynchrone pour ne pas bloquer la boucle principale des 5 minutes
            (
                # On mélange les nœuds et on en extrait jusqu'à 20
                TO_PROCESS=$(shuf -n 20 "${UPSYNC_QUEUE}.work" 2>/dev/null)
                
                for q_znod in $TO_PROCESS; do
                    [[ -z "$q_znod" ]] && continue
                    echo "Queued Syncing: $q_znod"
                    mkdir -p ~/.zen/tmp/swarm/${q_znod}
                    # Le timeout de 60s laisse le temps à IPFS de résoudre le nom IPNS
                    ipfs --timeout 60s get --progress="false" -o ~/.zen/tmp/swarm/${q_znod} /ipns/${q_znod} >/dev/null 2>&1
                done
                
                # On réinjecte les nœuds NON TRAITÉS dans la file d'attente principale
                # Commande grep magique : affiche les lignes de .work qui NE SONT PAS dans la variable TO_PROCESS
                if [[ -n "$TO_PROCESS" ]]; then
                    grep -vxF -f <(echo "$TO_PROCESS") "${UPSYNC_QUEUE}.work" >> "$UPSYNC_QUEUE" 2>/dev/null
                fi
                
                rm -f "${UPSYNC_QUEUE}.work"
            ) &
        fi

        SWARM_COUNT=$(find ~/.zen/tmp/swarm -mindepth 1 -maxdepth 1 -type d | wc -l)

            # Condition de rafraîchissement : 1h écoulée OU premier run OU cache vide
        if [[ ${duree} -gt 3600 || ${lastrun} -eq 0 || ${SWARM_COUNT} -eq 0 ]]; then

            if [[ ${SWARM_COUNT} -eq 0 && ${lastrun} -ne 0 ]]; then
                echo "⚠️  Cache Swarm vide détecté ! Tentative de réactivation immédiate..."
            fi

        ### PING & CONNECT 
        (${MY_PATH}/ping_bootstrap.sh >/dev/null 2>&1 &) 

        ### NOSTR RELAY SYNCHRO for LAST 24 H (direct call with lock protection)
        if [[ -s ~/.zen/workspace/NIP-101/backfill_constellation.sh ]]; then
            # Check if backfill is already running (prevent double execution)
            BACKFILL_LOCK="$HOME/.zen/strfry/constellation-backfill.lock"
            BACKFILL_RUNNING=false
            
            if [[ -f "$BACKFILL_LOCK" ]]; then
                BACKFILL_PID=$(cat "$BACKFILL_LOCK" 2>/dev/null)
                if [[ -n "$BACKFILL_PID" && -d "/proc/$BACKFILL_PID" ]]; then
                    BACKFILL_RUNNING=true
                    echo "⚠️  Backfill already running (PID: $BACKFILL_PID), skipping..."
                else
                    # Remove stale lock file
                    rm -f "$BACKFILL_LOCK"
                fi
            fi
            
            # Check last execution time to prevent double execution in same hour
            BACKFILL_LAST_RUN="$HOME/.zen/tmp/backfill_constellation.lastrun"
            if [[ -f "$BACKFILL_LAST_RUN" ]]; then
                LAST_RUN_TIME=$(cat "$BACKFILL_LAST_RUN" 2>/dev/null)
                CURRENT_TIME=$(date +%s)
                TIME_SINCE_LAST_RUN=$((CURRENT_TIME - LAST_RUN_TIME))
                
                # Prevent execution if last run was less than 50 minutes ago (avoid double execution in same hour)
                if [[ $TIME_SINCE_LAST_RUN -lt 3000 ]]; then
                    echo "⚠️  Backfill executed ${TIME_SINCE_LAST_RUN}s ago (< 50min), skipping to avoid double execution..."
                    BACKFILL_RUNNING=true
                fi
            fi
            
            # Launch backfill only if not running and enough time has passed
            if [[ "$BACKFILL_RUNNING" == "false" ]]; then
                echo "🚀 Launching constellation backfill..."
                ~/.zen/workspace/NIP-101/backfill_constellation.sh --days 1 --verbose &
                # Record execution time
                date +%s > "$BACKFILL_LAST_RUN"
            fi
        fi
        ##################################################################################
        # Check for IPFS P2P tunnels
        ( [[ -z $(ipfs p2p ls) ]] && ${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh ON ) &

        echo "$(date -u) - Starting Swarm Refresh Cycle"
        
        # Sous-processus pour ne pas bloquer le serveur HTTP
        (
            ## 0. Lock anti-scan concurrent
            if ! mkdir "$SCAN_LOCK_DIR" 2>/dev/null; then
                echo "Swarm scan already running, skipping this cycle"
                exit 0
            fi
            trap 'rmdir "$SCAN_LOCK_DIR" 2>/dev/null' EXIT INT TERM

            ## 1. SCAN DES SWARM PEERS (auto-découverte)
            # Récupérer tous les pairs connectés
            SWARM_PEERS=$(ipfs swarm peers | grep -v "${IPFSNODEID}")

            # Si pas de pairs, fallback sur les bootstraps
            if [[ -z "$SWARM_PEERS" ]]; then
                echo "No peers found, falling back to bootstraps"
                SWARM_PEERS=$(cat ${STRAPFILE} | grep -Ev "#" | grep -v '^[[:space:]]*$')
            fi

            for peer in ${SWARM_PEERS}; do
                # Extraire l'ID du peer (format: /ip4/x.x.x.x/tcp/4001/p2p/Qm...)
                peer_id=$(echo "$peer" | grep -oP 'p2p/\K[^/]+' | head -1)
                peer_ip=$(echo "$peer" | awk -F'/' '{print $3}')

                [[ -z "$peer_id" ]] && continue
                [[ "$peer_id" == "${IPFSNODEID}" ]] && continue
                
                echo "Scanning peer: $peer_id"
                if ! is_astroport_node "$peer_id"; then
                    echo "[$(date)] REJECTED: $peer_id (IP: $peer_ip) - Reason: No Astroport Metadata" >> ~/.zen/tmp/swarm_intruders.log
                    
                    # Action immédiate : Déconnexion forcée du swarm IPFS
                    ipfs swarm disconnect "/p2p/$peer_id" 2>/dev/null
                    
                    # Ajout à la liste des candidats au bannissement Firewall
                    echo "$peer_ip" >> ~/.zen/game/firewall_candidates.txt
                    continue
                fi

                TMP_PEER="/tmp/get_peer_${peer_id}"
                rm -Rf "$TMP_PEER"
                
                # Récupérer les données du peer via IPNS
                if ipfs --timeout 60s get --progress="false" -o "$TMP_PEER" /ipns/${peer_id}/ 2>/dev/null; then
                    if [[ -s "$TMP_PEER/_MySwarm.moats" ]]; then
                        # Mettre à jour le cache local
                        rm -Rf ~/.zen/tmp/swarm/${peer_id}
                        mv "$TMP_PEER" ~/.zen/tmp/swarm/${peer_id}
                        
                        # Récupérer la liste des autres stations via ce peer
                        it_map=$(cat ~/.zen/tmp/swarm/${peer_id}/12345.json 2>/dev/null | jq -r '.g1swarm' 2>/dev/null | rev | cut -d '/' -f 1 | rev)
                        if [[ -n "$it_map" && "$it_map" != "null" ]]; then
                            echo "---> Swarm extension with /ipns/${it_map}"
                            ipfs --timeout 20s ls /ipns/${it_map} 2>/dev/null | awk '{print $NF}' | sed 's/\///g' > ~/.zen/tmp/_swarm_list.${peer_id}
                            
                            for znod in $(cat ~/.zen/tmp/_swarm_list.${peer_id}); do
                                [[ "${znod}" == "${IPFSNODEID}" ]] && continue
                                # Téléchargement des balises des stations découvertes
                                TMP_ZNOD="/tmp/get_znod_${znod}"
                                if ipfs --timeout 60s get --progress="false" -o "$TMP_ZNOD" /ipns/${znod} 2>/dev/null; then
                                    ZMOATS=$(cat "$TMP_ZNOD/_MySwarm.moats" 2>/dev/null)
                                    if [[ -n "$ZMOATS" ]]; then
                                        CUR_SEC=$(date +%s)
                                        if [[ $(( CUR_SEC - ZMOATS )) -le ${BALISE_STALE_SECONDS} ]]; then
                                            rm -Rf ~/.zen/tmp/swarm/${znod}
                                            mv "$TMP_ZNOD" ~/.zen/tmp/swarm/${znod}
                                        fi
                                    fi
                                fi
                                rm -Rf "$TMP_ZNOD"
                            done
                        fi
                    fi
                fi
                rm -Rf "$TMP_PEER"
            done

            ls ~/.zen/tmp/swarm/*
            ## 2. NETTOYAGE DES STATIONS MORTES (STALE)
            echo "Cleaning stale stations..."
            for station_dir in ~/.zen/tmp/swarm/*/; do
                [ -d "$station_dir" ] || continue
                s_moats=$(cat "${station_dir}_MySwarm.moats" 2>/dev/null)
                
                if [[ -n "$s_moats" ]]; then
                    # Si la balise a plus de 12h (BALISE_STALE_SECONDS), on nettoie
                    if [[ $(( $(date +%s) - s_moats )) -gt ${BALISE_STALE_SECONDS} ]]; then
                        rm -Rf "$station_dir"
                    fi
                else
                    # Si pas de fichier moats, on vérifie l'âge du DOSSIER lui-même
                    # pour éviter de supprimer un dossier qui vient d'être créé/en cours de téléchargement
                    d_age=$(stat -c %Y "$station_dir")
                    if [[ $(( $(date +%s) - d_age )) -gt ${BALISE_STALE_SECONDS} ]]; then
                        rm -Rf "$station_dir"
                    fi
                fi
            done

            # Supprimer les dossiers restés vides
            find ~/.zen/tmp/swarm -mindepth 1 -maxdepth 1 -type d -empty -delete

            ## 3. PUBLICATION DE NOTRE PROPRE SWARM (CHAN)
            SWARMSIZE=$(du -sb ~/.zen/tmp/swarm | awk '{print $1}')
            local_swarm_size=$(cat ~/.zen/tmp/swarm/.bsize 2>/dev/null)

            if [[ "$SWARMSIZE" != "$local_swarm_size" ]]; then
                echo ${SWARMSIZE} > ~/.zen/tmp/swarm/.bsize
                # CORRECTED: On ajoute le dossier swarm lui-même (/* - pour avoir le bon CID !!
                SWARMH=$(ipfs --timeout 30s add -rwq ~/.zen/tmp/swarm/* | tail -n 1)
                if [[ -n "$SWARMH" ]]; then
                    echo "=== PUBLISHING UPDATED SWARM MAP: /ipfs/${SWARMH} ==="
                    if [[ "$SWARMH" != "$(cat "$LAST_SWARM_PUBLISH_FILE" 2>/dev/null)" ]]; then
                        echo "$SWARMH" > "$LAST_SWARM_PUBLISH_FILE"
                        (ipfs name publish --lifetime=24h --ttl=30m --key "MySwarm_${IPFSNODEID}" /ipfs/${SWARMH} >/dev/null 2>&1 &)
                    fi
                fi
            fi

            ## 4. RE-PUBLICATION DE NOTRE BALISE PERSONNELLE
            # On s'assure que notre 12345.json est à jour
            echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats

            ## ── COPIE DU TEMPLATE status.html ────────────────────────────────────
            ## Template dynamique : fetch 12345.json au chargement + wallets via uSPOT
            [[ -s "${MY_PATH}/templates/status.html" ]] && \
                cp "${MY_PATH}/templates/status.html" ~/.zen/tmp/${IPFSNODEID}/status.html
            ## ─────────────────────────────────────────────────────────────────────

            MYCACHE=$(ipfs --timeout 180s add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1)
            if [[ -n "$MYCACHE" ]]; then
                echo "=== PUBLISHING NODE BALISE: /ipfs/${MYCACHE} ==="
                if [[ "$MYCACHE" != "$(cat "$LAST_NODE_PUBLISH_FILE" 2>/dev/null)" ]]; then
                    echo "$MYCACHE" > "$LAST_NODE_PUBLISH_FILE"
                    (ipfs name publish --lifetime=24h --ttl=30m /ipfs/${MYCACHE} >/dev/null 2>&1 &)
                fi
            else
                echo "⚠️  MYCACHE is empty, skipping ipfs name publish"
            fi

        ) & 

        echo "${MOATS}" > "$lastrun_file"

    else

        echo "#######################"
        echo "NOT SO QUICK"
        echo "$duree only cache life"
        echo "#######################"

    fi

    #######################################
    ## ZEN ECONOMY
    [[ -z $PAF ]] && PAF=14
    [[ -z $NCARD ]] && NCARD=1
    [[ -z $ZCARD ]] && ZCARD=4
    BILAN=$(cat ~/.zen/tmp/Ustats.json 2>/dev/null | jq -r '.BILAN')
    
    ## ECONOMIC HEALTH DATA - For swarm aggregation
    MULTIPASS_COUNT=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
    ZENCARD_COUNT=$(ls ~/.zen/game/players 2>/dev/null | grep "@" | wc -l)
    
    # Captain dedicated wallet (2xPAF remuneration from ZEN.ECONOMY.sh)
    CAPTAIN_DEDICATED_ZEN=0
    if [[ -f "$HOME/.zen/game/uplanet.captain.dunikey" ]]; then
        CAPTAIN_DEDICATED_PUB=$(cat "$HOME/.zen/game/uplanet.captain.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
        if [[ -n "$CAPTAIN_DEDICATED_PUB" ]]; then
            CAPTAIN_DEDICATED_COINS=$(read_cached_coin "$CAPTAIN_DEDICATED_PUB")
            CAPTAIN_DEDICATED_ZEN=$(echo "scale=1; ($CAPTAIN_DEDICATED_COINS - 1) * 10" | bc)
        fi
    fi
    
    # Treasury (CASH) balance for solidarity mechanism
    TREASURY_ZEN=0
    if [[ -n "$UPLANETNAME_TREASURY" ]]; then
        TREASURY_COINS=$(read_cached_coin "$UPLANETNAME_TREASURY")
        TREASURY_ZEN=$(echo "scale=1; ($TREASURY_COINS - 1) * 10" | bc)
    fi
    
    # Calculate weekly revenue and costs
    WEEKLY_REVENUE=$(echo "$MULTIPASS_COUNT * $NCARD + $ZENCARD_COUNT * $ZCARD" | bc -l)
    CAPTAIN_REMUNERATION=$(echo "$PAF * 2" | bc -l)
    MIN_WEEKLY_COSTS=$(echo "$PAF + $CAPTAIN_REMUNERATION" | bc -l)
    WEEKLY_BALANCE=$(echo "$WEEKLY_REVENUE - $MIN_WEEKLY_COSTS" | bc -l)
    
    # Determine economic risk level
    ECONOMIC_RISK="GREEN"
    [[ -z "$CAPTAINZEN" || ! "$CAPTAINZEN" =~ ^[0-9] ]] && CAPTAINZEN=0
    [[ -z "$TREASURY_ZEN" || ! "$TREASURY_ZEN" =~ ^[0-9] ]] && TREASURY_ZEN=0
    [[ -z "$WEEKLY_BALANCE" || ! "$WEEKLY_BALANCE" =~ ^[-0-9] ]] && WEEKLY_BALANCE=0
    if [[ $(echo "$CAPTAINZEN < $MIN_WEEKLY_COSTS" | bc -l) -eq 1 ]]; then
        if [[ $(echo "$TREASURY_ZEN < $MIN_WEEKLY_COSTS" | bc -l) -eq 1 ]]; then
            ECONOMIC_RISK="RED"
        else
            ECONOMIC_RISK="ORANGE"
        fi
    elif [[ $(echo "$WEEKLY_BALANCE < 0" | bc -l) -eq 1 ]]; then
        ECONOMIC_RISK="YELLOW"
    fi

    ## STATION GPS COORDINATES - For UMAP proximity determination in swarm
    STATION_LAT="0"
    STATION_LON="0"
    if [[ -f ~/.zen/GPS ]]; then
        source ~/.zen/GPS
        STATION_LAT="${LAT:-0}"
        STATION_LON="${LON:-0}"
    fi

    ## READ HEARTBOX ANALYSIS - Fast cache-based approach
    ANALYSIS_FILE=~/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json
    NODE_STATE="${myIP}|${myIPFS}|${SOURCE_G1COIN}|${UPLANETCOINS}|${CAPTAINZEN}|${TREASURY_ZEN}|${NODEZEN}|${CAPTAINHEX}|${HEX}|${STATION_LAT}|${STATION_LON}|${ECONOMIC_RISK}|${MULTIPASS_COUNT}|${ZENCARD_COUNT}|${SWARM_COUNT}"
    LAST_NODE_STATE=$(cat "$LAST_NODE_STATE_FILE" 2>/dev/null)
    if [[ "$NODE_STATE" == "$LAST_NODE_STATE" && -s "$LAST_NODE_JSON_FILE" ]]; then
        NODE12345=$(cat "$LAST_NODE_JSON_FILE")
    fi
    
    # Check if cache is fresh (< 12h)
    if [[ -s ${ANALYSIS_FILE} ]]; then
        cache_age=$(( $(date +%s) - $(stat -c %Y "${ANALYSIS_FILE}" 2>/dev/null || echo 0) ))
        if [[ $cache_age -lt 43200 ]]; then  # 12h = 43200 seconds
            TEMP_CAPACITIES=$(cat ${ANALYSIS_FILE} | jq -r '.capacities' 2>/dev/null)
            TEMP_SERVICES=$(cat ${ANALYSIS_FILE} | jq -r '.services' 2>/dev/null)
            CAPACITIES=${TEMP_CAPACITIES:-"{\"reserved_captain_slots\":8}"}
            SERVICES=${TEMP_SERVICES:-"{\"ipfs\":{\"active\":true,\"peers_connected\":$(ipfs swarm peers | wc -l)},\"astroport\":{\"active\":true},\"g1billet\":{\"active\":true}}"}
        else
            # Cache expired, update it in background
            (${MY_PATH}/tools/heartbox_analysis.sh update >/dev/null 2>&1) &
            # Use fallback data for immediate response
            CAPACITIES="{\"reserved_captain_slots\":8}"
            SERVICES="{\"ipfs\":{\"active\":true,\"peers_connected\":$(ipfs swarm peers | wc -l)},\"astroport\":{\"active\":true},\"g1billet\":{\"active\":true}}"
        fi
    else
        # No cache file, create it in background
        (${MY_PATH}/tools/heartbox_analysis.sh update >/dev/null 2>&1) &
        # Use fallback data for immediate response
        CAPACITIES="{\"reserved_captain_slots\":8}"
        SERVICES="{\"ipfs\":{\"active\":true,\"peers_connected\":$(ipfs swarm peers | wc -l)},\"astroport\":{\"active\":true},\"g1billet\":{\"active\":true}}"
    fi

NODE12345="{
    \"version\" : \"12345.0.2\",
    \"created\" : \"${MOATS}\",
    \"date\" : \"$(cat $HOME/.zen/tmp/${IPFSNODEID}/_MySwarm.staom)\",
    \"hostname\" : \"$(myHostName)\",
    \"myIP\" : \"${myIP}\",
    \"IPCity\" : \"$(cat ~/.zen/IPCity 2>/dev/null)\",
    \"myIPv6\" : \"$(${MY_PATH}/tools/ipv6.sh | head -n 1)\",
    \"myASTROPORT\" : \"${myASTROPORT}\",
    \"myIPFS\" : \"${myIPFS}\",
    \"myAPI\" : \"${myAPI}\",
    \"myRELAY\" : \"${myRELAY}\",
    \"uSPOT\" : \"${uSPOT}\",
    \"ipfsnodeid\" : \"${IPFSNODEID}\",
    \"astroport\" : \"http://${myIP}:12345\",
    \"g1station\" : \"${myIPFS}/ipns/${IPFSNODEID}\",
    \"g1swarm\" : \"${myIPFS}/ipns/${CHAN}\",
    \"captain\" : \"${CAPTAINEMAIL}\",
    \"captainZEN\" : \"${CAPTAINZEN}\",
    \"captainHEX\" : \"${captainHEX}\",
    \"CAPTAING1PUB\" : \"${CAPTAING1PUB}\",
    \"CAPTAINZENCARDG1PUB\" : \"${CAPTAINZENCARDG1PUB}\",
    \"SSHPUB\" : \"$(cat $HOME/.ssh/id_ed25519.pub)\",
    \"NODEZEN\" : \"${NODEZEN}\",
    \"NODEHEX\" : \"${hex}\",
    \"NODEG1PUB\" : \"${NODEG1PUB}\",
    \"STATION_LAT\" : \"${STATION_LAT}\",
    \"STATION_LON\" : \"${STATION_LON}\",
    \"SOURCE_ZEN\" : \"${SOURCE_ZEN}\",
    \"UPLANETNAME_G1\" : \"${UPLANETNAME_G1}\",
    \"UPLANETNAME_SOCIETY\" : \"${UPLANETNAME_SOCIETY}\",
    \"UPLANETNAME_TREASURY\" : \"${UPLANETNAME_TREASURY}\",
    \"UPLANETNAME_RND\" : \"${UPLANETNAME_RND}\",
    \"UPLANETNAME_ASSETS\" : \"${UPLANETNAME_ASSETS}\",
    \"UPLANETNAME_IMPOT\" : \"${UPLANETNAME_IMPOT}\",
    \"UPLANETNAME_CAPITAL\" : \"${UPLANETNAME_CAPITAL}\",
    \"UPLANETNAME_AMORTISSEMENT\" : \"${UPLANETNAME_AMORTISSEMENT}\",
    \"UPLANETNAME_INTRUSION\" : \"${UPLANETNAME_INTRUSION}\",
    \"UPLANETG1PUB\" : \"${UPLANETG1PUB}\",
    \"UPLANETG1\" : \"${UPLANETCOINS}\",
    \"UPLANETZEN\" : \"${UPLANETZEN}\",
    \"PAF\" : \"${PAF}\",
    \"NCARD\" : \"${NCARD}\",
    \"ZCARD\" : \"${ZCARD}\",
    \"MACHINE_VALUE_ZEN\" : \"${MACHINE_VALUE_ZEN:-500}\",
    \"BILAN\" : \"${BILAN}\",
    \"dragon_services\" : \"$(ls ~/.zen/tmp/${IPFSNODEID}/x_*.sh 2>/dev/null | xargs -I{} basename {} 2>/dev/null | sed 's/^x_//;s/\\.sh$//' | paste -sd',' - 2>/dev/null || echo '')\",
    \"capacities\" : ${CAPACITIES},
    \"services\" : ${SERVICES},
    \"economy\" : {
        \"multipass_count\" : ${MULTIPASS_COUNT:-0},
        \"zencard_count\" : ${ZENCARD_COUNT:-0},
        \"captain_dedicated_zen\" : ${CAPTAIN_DEDICATED_ZEN:-0},
        \"treasury_zen\" : ${TREASURY_ZEN:-0},
        \"weekly_revenue\" : ${WEEKLY_REVENUE:-0},
        \"weekly_costs\" : ${MIN_WEEKLY_COSTS:-0},
        \"weekly_balance\" : ${WEEKLY_BALANCE:-0},
        \"captain_remuneration\" : ${CAPTAIN_REMUNERATION:-0},
        \"risk_level\" : \"${ECONOMIC_RISK}\"
    }
}
"

    ## PUBLISH ${IPFSNODEID}/12345.json
    if [[ "$NODE_STATE" != "$LAST_NODE_STATE" || ! -s "$LAST_NODE_JSON_FILE" ]]; then
        echo "${NODE12345}" > ~/.zen/tmp/${IPFSNODEID}/12345.json
        echo "${NODE12345}" > "$LAST_NODE_JSON_FILE"
        echo "$NODE_STATE" > "$LAST_NODE_STATE_FILE"
        ## Mise à jour des timestamps de la balise IPNS locale
        echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats
        echo "$(date -u)" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.staom
    fi

    ############ MISE À JOUR HTTP 12345 (RAM - /dev/shm)
    echo -e "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Credentials: true\r\nAccess-Control-Allow-Methods: GET\r\nServer: Astroport.ONE\r\nContent-Type: application/json; charset=UTF-8\r\nConnection: close\r\n\r\n${NODE12345}" > "$RESPONSE_FILE"

    echo '(◕‿‿◕) http://'$myIP:'12345 SERVED VIA SOCAT (CGI) (◕‿‿◕)'
    
    # Sleep to prevent busy loop (replacing nc -l wait)
    # Wait 300 seconds before checking if update is needed
    sleep 300

    #### 12345 NETWORK MAP TOKEN
    end=`date +%s`
    echo '(#__#) LOOP TIME was '`expr $end - $start`' seconds.'

done

exit 0
