#!/bin/bash
################################################################################
# duniter_getnode.sh
# Découverte et sélection de nœuds Duniter v2 (RPC + Squid)
# avec health check, latence, et load balancing
#
# Usage:
#   duniter_getnode.sh              → retourne le meilleur nœud RPC WSS
#   duniter_getnode.sh rpc          → meilleur nœud RPC WSS
#   duniter_getnode.sh squid        → meilleur indexer squid
#   duniter_getnode.sh all          → tous les nœuds valides (JSON)
#   duniter_getnode.sh refresh      → force le rafraîchissement du cache
#
# Cache : ~/.zen/tmp/duniter_nodes.json (TTL: 1h)
#
# Sources de découverte (par ordre de priorité) :
#   1. Cache local valide
#   2. duniter_peerings RPC (découverte P2P)
#   3. Fichier réseau GitLab git.duniter.org/nodes/networks
#   4. Annonces on-chain via squid (remark "duniter endpoint g1 add ...")
#   5. Liste hardcodée de bootstrap
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
CACHE_FILE="${HOME}/.zen/tmp/duniter_nodes.json"
CACHE_TTL=3600          # secondes avant re-découverte (1h)
CHECK_TIMEOUT=5         # timeout health check en secondes
MAX_NODES=10            # nb max de nœuds valides à conserver
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"

# ── Nœuds de bootstrap hardcodés (toujours valides en dernier recours) ────────
BOOTSTRAP_RPC=(
    "wss://g1.p2p.legal/ws"
    "wss://duniter.g1.coinduf.eu/ws"
    "wss://g1.duniter.fr/ws"
    "wss://g1.1000i100.fr/ws"
)
BOOTSTRAP_SQUID=(
    "https://squid.g1.gyroi.de/v1/graphql"
    "https://squid.g1.coinduf.eu/v1/graphql"
    "https://g1-squid.axiom-team.fr/v1/graphql"
)

# ── URL du fichier réseau officiel GitLab ────────────────────────────────────
NETWORK_JSON_URL="https://git.duniter.org/nodes/networks/-/raw/main/g1.json"

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

log()  { echo "[duniter_getnode] $*" >&2; }
logw() { echo -e "${YELLOW}[duniter_getnode] ⚠ $*${RESET}" >&2; }
logok(){ echo -e "${GREEN}[duniter_getnode] ✓ $*${RESET}" >&2; }

mkdir -p "$(dirname "$CACHE_FILE")"

# ════════════════════════════════════════════════════════════════════════════════
# HEALTH CHECKS
# ════════════════════════════════════════════════════════════════════════════════

# Vérifie un endpoint HTTP/HTTPS (squid) : répond + retourne du JSON valide
check_squid() {
    local url="$1"
    local start end latency
    start=$(date +%s%3N)

    local resp
    resp=$(curl -sf --max-time "$CHECK_TIMEOUT" \
        -X POST "$url" \
        -H "Content-Type: application/json" \
        --data-binary '{"query":"{ squidStatus { height } }"}' 2>/dev/null)

    [[ $? -ne 0 ]] && return 1

    end=$(date +%s%3N)
    latency=$(( end - start ))

    # Vérifie que la réponse contient une hauteur de bloc
    local height
    height=$(echo "$resp" | jq -r '.data.squidStatus.height // empty' 2>/dev/null)
    [[ -z "$height" || "$height" == "null" ]] && return 1

    echo "$latency $height"
    return 0
}

# Vérifie un endpoint RPC WebSocket (duniter) via HTTP/HTTPS JSON-RPC
# (les WSS ne sont pas testables directement en curl, on essaie HTTPS)
check_rpc() {
    local url="$1"
    # Convertit wss:// → https:// et ws:// → http://
    local http_url
    http_url=$(echo "$url" | sed 's|^wss://|https://|; s|^ws://|http://|')
    # Retire /ws en fin si présent pour l'URL HTTP
    http_url="${http_url%/ws}"

    local start end latency
    start=$(date +%s%3N)

    local resp
    resp=$(curl -sf --max-time "$CHECK_TIMEOUT" \
        -X POST "$http_url" \
        -H "Content-Type: application/json" \
        --data-binary '{"jsonrpc":"2.0","method":"system_chain","params":[],"id":1}' \
        2>/dev/null)

    [[ $? -ne 0 ]] && return 1

    end=$(date +%s%3N)
    latency=$(( end - start ))

    # Vérifie que c'est bien le réseau G1
    local chain
    chain=$(echo "$resp" | jq -r '.result // empty' 2>/dev/null)
    [[ -z "$chain" ]] && return 1

    # Vérifie la synchro via system_syncState
    local sync_resp
    sync_resp=$(curl -sf --max-time "$CHECK_TIMEOUT" \
        -X POST "$http_url" \
        -H "Content-Type: application/json" \
        --data-binary '{"jsonrpc":"2.0","method":"system_syncState","params":[],"id":2}' \
        2>/dev/null)

    local current highest
    current=$(echo "$sync_resp" | jq -r '.result.currentBlock // 0' 2>/dev/null)
    highest=$(echo "$sync_resp" | jq -r '.result.highestBlock // 0' 2>/dev/null)

    # Accepte si le nœud est à moins de 10 blocs du tip
    local lag=$(( highest - current ))
    [[ "$lag" -gt 10 ]] && return 1

    echo "$latency $current"
    return 0
}

# ════════════════════════════════════════════════════════════════════════════════
# DÉCOUVERTE DES ENDPOINTS
# ════════════════════════════════════════════════════════════════════════════════

# Source 1 : duniter_peerings depuis un nœud RPC connu
discover_via_peerings() {
    local rpc_url="$1"
    local http_url
    http_url=$(echo "$rpc_url" | sed 's|^wss://|https://|; s|^ws://|http://|')
    http_url="${http_url%/ws}"

    local resp
    resp=$(curl -sf --max-time "$CHECK_TIMEOUT" \
        -X POST "$http_url" \
        -H "Content-Type: application/json" \
        --data-binary '{"jsonrpc":"2.0","method":"duniter_peerings","params":[],"id":1}' \
        2>/dev/null) || return 1

    # Extraire RPC endpoints
    echo "$resp" | jq -r \
        '.result.peerings[]?.endpoints[]? | select(.protocol=="rpc") | .address' \
        2>/dev/null

    # Extraire Squid endpoints (dans DISCOVERED_SQUIDS)
    echo "$resp" | jq -r \
        '.result.peerings[]?.endpoints[]? | select(.protocol=="squid") | .address' \
        2>/dev/null >> "$TMPFILE"
}

# Source 2 : fichier réseau officiel GitLab
discover_via_network_json() {
    local resp
    resp=$(curl -sf --max-time 10 "$NETWORK_JSON_URL" 2>/dev/null) || return 1

    # Format attendu : {"endpoints":{"rpc":["wss://..."],"squid":["https://..."]}}
    # ou format simple liste
    echo "$resp" | jq -r '.endpoints.rpc[]? // .rpc[]? // .[]?' 2>/dev/null
    echo "$resp" | jq -r '.endpoints.squid[]? // .squid[]?' 2>/dev/null \
        >> "$TMPFILE"
}

# Source 3 : annonces on-chain via squid (remark "duniter endpoint g1 add ...")
discover_via_onchain_remarks() {
    local squid="$1"
    local query
    query='{"query":"{ txComments(filter:{message:{startsWith:\"duniter endpoint g1 add \"}}) { nodes { message } } }"}'

    local resp
    resp=$(curl -sf --max-time 10 \
        -X POST "$squid" \
        -H "Content-Type: application/json" \
        --data-binary "$query" 2>/dev/null) || return 1

    # Extraire les URLs des remarques
    echo "$resp" | jq -r \
        '.data.txComments.nodes[]?.message // empty' 2>/dev/null \
    | while read -r remark; do
        # Format: "duniter endpoint g1 add rpc wss://..."
        #      ou "duniter endpoint g1 add squid https://..."
        local type url
        type=$(echo "$remark" | awk '{print $5}')
        url=$(echo "$remark" | awk '{print $6}')
        [[ -z "$url" ]] && continue
        case "$type" in
            rpc)   echo "$url" ;;
            squid) echo "$url" >> "$TMPFILE" ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════════════════════════
# FONCTION PRINCIPALE : découverte + scoring + cache
# ════════════════════════════════════════════════════════════════════════════════
refresh_nodes() {
    log "Rafraîchissement de la liste des nœuds..."
    local TMPFILE
    TMPFILE=$(mktemp /tmp/duniter_squids_XXXXXX)
    trap 'rm -f "$TMPFILE"' RETURN

    # Collecte de tous les candidats RPC
    local rpc_candidates=("${BOOTSTRAP_RPC[@]}")
    local squid_candidates=("${BOOTSTRAP_SQUID[@]}")

    # Découverte P2P depuis le premier bootstrap
    log "Découverte P2P via peerings..."
    while IFS= read -r node; do
        [[ -n "$node" ]] && rpc_candidates+=("$node")
    done < <(discover_via_peerings "${BOOTSTRAP_RPC[0]}" 2>/dev/null)

    # Fichier réseau GitLab
    log "Lecture du fichier réseau GitLab..."
    while IFS= read -r node; do
        [[ -n "$node" ]] && rpc_candidates+=("$node")
    done < <(discover_via_network_json 2>/dev/null)

    # Annonces on-chain
    log "Lecture des annonces on-chain..."
    while IFS= read -r node; do
        [[ -n "$node" ]] && rpc_candidates+=("$node")
    done < <(discover_via_onchain_remarks "$SQUID_URL" 2>/dev/null)

    # Ajouter les squids découverts
    if [[ -f "$TMPFILE" ]]; then
        while IFS= read -r sq; do
            [[ -n "$sq" ]] && squid_candidates+=("$sq")
        done < "$TMPFILE"
        rm -f "$TMPFILE"
    fi

    # Dédupliquer
    local uniq_rpc uniq_squid
    mapfile -t uniq_rpc   < <(printf '%s\n' "${rpc_candidates[@]}"   | sort -u)
    mapfile -t uniq_squid < <(printf '%s\n' "${squid_candidates[@]}" | sort -u)

    log "Candidats RPC   : ${#uniq_rpc[@]}"
    log "Candidats Squid : ${#uniq_squid[@]}"

    # Health check et scoring des nœuds RPC
    local valid_rpc=()
    for url in "${uniq_rpc[@]}"; do
        local result
        result=$(check_rpc "$url" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            local latency block
            latency=$(echo "$result" | awk '{print $1}')
            block=$(echo "$result"   | awk '{print $2}')
            valid_rpc+=("{\"url\":\"$url\",\"latency\":$latency,\"block\":$block,\"type\":\"rpc\"}")
            logok "RPC OK : $url (${latency}ms, bloc $block)"
        else
            log "RPC KO : $url"
        fi
        [[ "${#valid_rpc[@]}" -ge "$MAX_NODES" ]] && break
    done

    # Health check et scoring des nœuds Squid
    local valid_squid=()
    for url in "${uniq_squid[@]}"; do
        local result
        result=$(check_squid "$url" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            local latency height
            latency=$(echo "$result" | awk '{print $1}')
            height=$(echo "$result"  | awk '{print $2}')
            valid_squid+=("{\"url\":\"$url\",\"latency\":$latency,\"height\":$height,\"type\":\"squid\"}")
            logok "Squid OK : $url (${latency}ms, hauteur $height)"
        else
            log "Squid KO : $url"
        fi
        [[ "${#valid_squid[@]}" -ge "$MAX_NODES" ]] && break
    done

    # Fallback : si tout échoue, garder les bootstraps
    if [[ "${#valid_rpc[@]}" -eq 0 ]]; then
        logw "Aucun RPC valide — utilisation des bootstraps"
        for url in "${BOOTSTRAP_RPC[@]}"; do
            valid_rpc+=("{\"url\":\"$url\",\"latency\":9999,\"block\":0,\"type\":\"rpc\"}")
        done
    fi
    if [[ "${#valid_squid[@]}" -eq 0 ]]; then
        logw "Aucun Squid valide — utilisation des bootstraps"
        for url in "${BOOTSTRAP_SQUID[@]}"; do
            valid_squid+=("{\"url\":\"$url\",\"latency\":9999,\"height\":0,\"type\":\"squid\"}")
        done
    fi

    # Trier par latence (les plus rapides en premier)
    local rpc_json squid_json
    rpc_json=$(printf '%s\n' "${valid_rpc[@]}" \
        | jq -s 'sort_by(.latency)')
    squid_json=$(printf '%s\n' "${valid_squid[@]}" \
        | jq -s 'sort_by(.latency)')

    # Écriture du cache
    jq -n \
        --argjson rpc   "$rpc_json" \
        --argjson squid "$squid_json" \
        --arg ts "$(date -u +%s)" \
        '{timestamp: ($ts|tonumber), rpc: $rpc, squid: $squid}' \
    > "$CACHE_FILE"

    logok "Cache mis à jour : ${#valid_rpc[@]} RPC, ${#valid_squid[@]} Squid"

    # Publish to IPNS node directory (available at /ipns/$IPFSNODEID/duniter_nodes.json)
    if [[ -n "${IPFSNODEID}" && -d "${HOME}/.zen/tmp/${IPFSNODEID}" ]]; then
        cp -f "$CACHE_FILE" "${HOME}/.zen/tmp/${IPFSNODEID}/duniter_nodes.json"
        logok "Copié vers IPNS : ~/.zen/tmp/${IPFSNODEID}/duniter_nodes.json"
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# LECTURE DU CACHE avec TTL
# ════════════════════════════════════════════════════════════════════════════════
load_cache() {
    [[ ! -f "$CACHE_FILE" ]] && return 1

    local ts now age
    ts=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
    now=$(date -u +%s)
    age=$(( now - ts ))

    [[ "$age" -gt "$CACHE_TTL" ]] && return 1
    return 0
}

# ════════════════════════════════════════════════════════════════════════════════
# LOAD BALANCING : sélection pondérée par latence
# Retourne un nœud au hasard parmi les N meilleurs (évite le hot-spot)
# ════════════════════════════════════════════════════════════════════════════════
pick_node() {
    local type="$1"   # "rpc" ou "squid"
    local top="${2:-3}"  # parmi les N meilleurs

    jq -r --arg t "$type" --argjson n "$top" \
        '.[$t][0:$n][].url' "$CACHE_FILE" 2>/dev/null \
    | shuf | head -1
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT D'ENTRÉE
# ════════════════════════════════════════════════════════════════════════════════
MODE="${1:-rpc}"

# Rafraîchir si cache expiré ou demandé
if [[ "$MODE" == "refresh" ]] || ! load_cache; then
    refresh_nodes
fi

case "$MODE" in
    rpc)
        pick_node "rpc"
        ;;
    squid)
        pick_node "squid"
        ;;
    all)
        cat "$CACHE_FILE" | jq .
        ;;
    refresh)
        cat "$CACHE_FILE" | jq '{rpc: [.rpc[].url], squid: [.squid[].url]}'
        ;;
    best)
        # Retourne le meilleur de chaque type sans randomisation
        echo "RPC:   $(jq -r '.rpc[0].url'   "$CACHE_FILE")"
        echo "SQUID: $(jq -r '.squid[0].url' "$CACHE_FILE")"
        ;;
    status)
        # Résumé lisible
        echo -e "${CYAN}=== Nœuds Duniter v2 disponibles ===${RESET}"
        echo ""
        echo -e "${GREEN}RPC (WebSocket) :${RESET}"
        jq -r '.rpc[] | "  \(.latency)ms  \(.url)  (bloc \(.block))"' "$CACHE_FILE" 2>/dev/null
        echo ""
        echo -e "${GREEN}Squid (GraphQL) :${RESET}"
        jq -r '.squid[] | "  \(.latency)ms  \(.url)  (hauteur \(.height))"' "$CACHE_FILE" 2>/dev/null
        echo ""
        _age=$(( $(date -u +%s) - $(jq -r '.timestamp' "$CACHE_FILE") ))
        echo "Cache : ${_age}s / ${CACHE_TTL}s"
        ;;
    *)
        echo "Usage: $0 [rpc|squid|all|best|status|refresh]"
        exit 1
        ;;
esac
