#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 3.1 — Duniter v2 (gcli RPC + Squid GraphQL parallèle)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1check.sh
#~ Retourne le solde d'un wallet G1 (en Ğ1, 2 décimales).
#~ Source de vérité : gcli account balance (Duniter RPC, on-chain)
#~ Cache ~/.zen/tmp/coucou/<G1PUB>.COINS (TTL 12s frais, 60s périmé)
#~ Rafraîchissement en arrière-plan si cache périmé.
#
# Usage:
#   G1check.sh <G1PUB>              → solde en Ğ1 (ex: 2.48)
#   G1check.sh <G1PUB>:ZEN          → solde converti en Ẑen (= (Ğ1-1)*10)
#   G1check.sh <PUB1> <PUB2> ...    → mode batch parallèle (une ligne par pub)
#
# Parallélisation :
#   - mode batch   : plusieurs G1PUBs traités simultanément (GNU parallel ou jobs)
#   - fetch RPC    : tous les nœuds RPC interrogés en parallèle (1er valide gagne)
#   - fetch Squid  : toutes les URLs Squid GraphQL interrogées en parallèle
#
# Compatibilité : retourne le même format que l'ancienne version silkaj.
# Décimales : 1 Ğ1 = 100 centimes bruts (DECIMALS=2)
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ══════════════════════════════════════════════════════════════════════════════
# MODE BATCH : plusieurs G1PUBs en arguments → parallèle
# (Ex: API dashboard 10 users → G1check.sh pub1 pub2 ... pub10)
# ══════════════════════════════════════════════════════════════════════════════
if [[ $# -gt 1 ]]; then
    SELF="$0"
    if command -v parallel &>/dev/null; then
        # GNU parallel : tous les jobs simultanément, résultats dans l'ordre
        parallel --will-cite -j0 "$SELF" ::: "$@"
    else
        # Fallback bash jobs
        declare -a _BATCH_PIDS=()
        for _arg in "$@"; do
            "$SELF" "$_arg" &
            _BATCH_PIDS+=($!)
        done
        for _pid in "${_BATCH_PIDS[@]}"; do
            wait "$_pid"
        done
    fi
    exit 0
fi

# ── Configuration ─────────────────────────────────────────────────────────────
DECIMALS=2                   # 1 Ğ1 = 100 centimes bruts (confirmé sur réseau réel)
GCLI="${GCLI:-gcli}"
CACHE_DIR="${HOME}/.zen/tmp/coucou"
CACHE_FRESH_SEC=12           # 12s : 2 blocs Duniter v2 (1 bloc = 6s)
CACHE_STALE_SEC=60           # 1 min : après ça on force le refresh
CACHE_COINS_LIMIT=1          # jours avant suppression du fichier cache

# Noeud RPC Duniter (source de vérité on-chain)
RPC_URL=""
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    RPC_URL=$("${MY_PATH}/duniter_getnode.sh" rpc 2>/dev/null)
fi
[[ -z "$RPC_URL" ]] && RPC_URL="${G1_WS_NODE:-wss://g1.1000i100.fr/ws}"

# ── Logging ───────────────────────────────────────────────────────────────────
log() { echo "[G1check] $*" >&2; }

# ── Validation solde ──────────────────────────────────────────────────────────
is_valid_balance() {
    [[ "$1" =~ ^[0-9]+\.?[0-9]*$ ]] && \
        [[ $(echo "${1:-0} >= 0" | bc -l 2>/dev/null) -eq 1 ]]
}

# ── Âge d'un fichier en secondes ─────────────────────────────────────────────
file_age_sec() {
    local f="$1"
    [[ -s "$f" ]] || return 1
    echo $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) ))
}

# ── Requête gcli : retourne solde total brut en centimes via Duniter RPC ──────
# Note : retourne total_balance (pas transferable_balance) car la formule
# ẐEN = (Ğ1 - 1) * 10 soustrait déjà le 1 Ğ1 bloqué (primo tx / existential deposit)
gcli_balance_raw() {
    local addr="$1"
    local rpc="${2:-$RPC_URL}"
    $GCLI --no-password -a "$addr" -u "$rpc" -o json account balance 2>/dev/null \
        | jq -r '.total_balance // empty'
}

# ── Conversion BigInt → Ğ1 ───────────────────────────────────────────────────
raw_to_g1() {
    local raw="$1"
    [[ -z "$raw" || "$raw" == "null" ]] && echo "0" && return
    echo "scale=2; ${raw} / 100" | bc
}

# ── Lecture cache ─────────────────────────────────────────────────────────────
read_cache() {
    local f="$1"
    [[ -s "$f" ]] || return 1
    local v
    v=$(cat "$f" 2>/dev/null)
    is_valid_balance "$v" && echo "$v" && return 0
    rm -f "$f"
    return 1
}

# ── Écriture cache + backup ───────────────────────────────────────────────────
write_cache() {
    local f="$1" val="$2"
    echo "$val" > "$f"
    # Backup horodaté (garde 1 seul)
    local bak="${HOME}/.zen/tmp/backup.${G1PUB}.$(date +%s)"
    echo "$val" > "$bak"
    find "${HOME}/.zen/tmp" -maxdepth 1 -name "backup.${G1PUB}.*" \
        | sort -r | tail -n +2 | xargs rm -f 2>/dev/null
}

# ── Sortie finale ─────────────────────────────────────────────────────────────
output() {
    local val="$1"
    if [[ "$IS_ZEN" == "true" ]]; then
        echo "scale=1; ($val - 1) * 10" | bc
    else
        echo "$val"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# FETCH PARALLÈLE RPC : tous les nœuds interrogés simultanément
# Premier résultat valide gagne (mv -n = rename atomique sans écrasement)
# Retourne "<solde>|<rpc_url>" sur stdout, exit 0 si succès
# ══════════════════════════════════════════════════════════════════════════════
parallel_rpc_fetch() {
    local addr="$1"; shift
    local urls=("$@")
    [[ ${#urls[@]} -eq 0 ]] && return 1

    local tmpdir; tmpdir=$(mktemp -d)
    local result_file="$tmpdir/result"
    local PIDS=()

    for rpc in "${urls[@]}"; do
        (
            exec 2>/dev/null  # Silence les erreurs "broken pipe" quand le worker est tué
            raw=$($GCLI --no-password -a "$addr" -u "$rpc" -o json account balance 2>/dev/null \
                | jq -r '.total_balance // empty' 2>/dev/null)
            [[ -z "$raw" || "$raw" == "null" ]] && exit 1
            val=$(echo "scale=2; ${raw} / 100" | bc)
            is_valid_balance "$val" || exit 1
            local tmp_r="$tmpdir/r.$BASHPID"
            echo "${val}|${rpc}" > "$tmp_r"
            # mv -n : atomique, ne remplace pas si déjà présent → 1er valide gagne
            mv -n "$tmp_r" "$result_file" 2>/dev/null || rm -f "$tmp_r"
        ) &
        PIDS+=($!)
    done

    # Polling léger : max 15s, intervalle 100ms
    local i=0
    while [[ $i -lt 150 && ! -s "$result_file" ]]; do
        sleep 0.1
        (( i++ ))
    done

    # Arrêter les workers encore actifs
    for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null; done
    wait "${PIDS[@]}" 2>/dev/null

    if [[ -s "$result_file" ]]; then
        cat "$result_file"
        rm -rf "$tmpdir"
        return 0
    fi
    rm -rf "$tmpdir"
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# FETCH PARALLÈLE SQUID GraphQL : toutes les URLs interrogées simultanément
# Premier résultat valide gagne (mv -n atomique)
# Retourne "<solde>|<squid_url>" sur stdout, exit 0 si succès
# ══════════════════════════════════════════════════════════════════════════════
parallel_squid_fetch() {
    local addr="$1"; shift
    local urls=("$@")
    [[ ${#urls[@]} -eq 0 ]] && return 1

    local tmpdir; tmpdir=$(mktemp -d)
    local result_file="$tmpdir/result"
    local PIDS=()

    for squid_url in "${urls[@]}"; do
        (
            exec 2>/dev/null  # Silence les erreurs "broken pipe" quand le worker est tué
            resp=$(curl -sf --max-time 8 -X POST "$squid_url" \
                -H "Content-Type: application/json" \
                --data-binary \
                "{\"query\":\"query(\$w:String!){accounts(condition:{id:\$w}){nodes{totalBalance}}}\",\"variables\":{\"w\":\"$addr\"}}" \
                2>/dev/null)
            raw=$(echo "$resp" | jq -r '.data.accounts.nodes[0].totalBalance // empty' 2>/dev/null)
            [[ -z "$raw" || "$raw" == "null" ]] && exit 1
            val=$(echo "scale=2; ${raw} / 100" | bc)
            is_valid_balance "$val" || exit 1
            local tmp_r="$tmpdir/r.$BASHPID"
            echo "${val}|${squid_url}" > "$tmp_r"
            mv -n "$tmp_r" "$result_file" 2>/dev/null || rm -f "$tmp_r"
        ) &
        PIDS+=($!)
    done

    # Polling léger : max 10s (curl max-time=8), intervalle 100ms
    local i=0
    while [[ $i -lt 100 && ! -s "$result_file" ]]; do
        sleep 0.1
        (( i++ ))
    done

    # Arrêter les workers encore actifs (curl bloqués)
    for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null; done
    wait "${PIDS[@]}" 2>/dev/null

    if [[ -s "$result_file" ]]; then
        cat "$result_file"
        rm -rf "$tmpdir"
        return 0
    fi
    rm -rf "$tmpdir"
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# PARSE ARGS
# ══════════════════════════════════════════════════════════════════════════════
G1PUB_ORIGINAL="${1:-}"
[[ -z "$G1PUB_ORIGINAL" ]] && { log "USAGE: G1check.sh <G1PUB>[:ZEN]"; exit 1; }

IS_ZEN="false"
if [[ "$G1PUB_ORIGINAL" == *":ZEN" ]]; then
    IS_ZEN="true"
    G1PUB="${G1PUB_ORIGINAL%:ZEN}"
else
    G1PUB="$G1PUB_ORIGINAL"
fi

# Validation basique de format (base58, 43-44 chars ou SS58 g1...)
if ! [[ "$G1PUB" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,50}$ ]]; then
    log "ERREUR: G1PUB invalide : $G1PUB"
    exit 1
fi

# Conversion v1 pubkey → SS58 (gcli utilise le format SS58)
G1PUB_QUERY="$G1PUB"
if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]] && ! [[ "$G1PUB" =~ ^g1 ]]; then
    SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$G1PUB" 2>/dev/null)
    [[ -n "$SS58" ]] && G1PUB_QUERY="$SS58" && log "Conversion v1→SS58 : $G1PUB → $SS58"
fi

# ── Nettoyage cache anciens ───────────────────────────────────────────────────
mkdir -p "$CACHE_DIR"
find "$CACHE_DIR" -mtime +"$CACHE_COINS_LIMIT" -name "*.COINS" -delete 2>/dev/null

COINSFILE="$CACHE_DIR/${G1PUB}.COINS"

# ══════════════════════════════════════════════════════════════════════════════
# 1. Cache frais (< 12s) → retour immédiat
# ══════════════════════════════════════════════════════════════════════════════
age=$(file_age_sec "$COINSFILE") 2>/dev/null || age=99999
if [[ $age -lt $CACHE_FRESH_SEC ]]; then
    val=$(read_cache "$COINSFILE") && { output "$val"; exit 0; }
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. Cache périmé mais valide (< 60s) → retour immédiat + refresh BG
# ══════════════════════════════════════════════════════════════════════════════
if [[ $age -lt $CACHE_STALE_SEC ]]; then
    val=$(read_cache "$COINSFILE")
    if [[ -n "$val" ]]; then
        log "Solde en cache (${age}s) — refresh en arrière-plan"
        # Refresh arrière-plan : RPC parallèle puis Squid parallèle
        (
            exec >/dev/null 2>&1
            sleep 1

            # Construire liste noeuds RPC
            _rpc_nodes=()
            [[ -x "${MY_PATH}/duniter_getnode.sh" ]] && \
                _rpc_bg=$("${MY_PATH}/duniter_getnode.sh" rpc 2>/dev/null)
            [[ -n "$_rpc_bg" ]] && _rpc_nodes+=("$_rpc_bg") || _rpc_nodes+=("$RPC_URL")
            if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
                while IFS= read -r node; do
                    [[ -n "$node" ]] && _rpc_nodes+=("$node")
                done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null \
                    | jq -r '.rpc[].url' 2>/dev/null)
            fi
            mapfile -t _rpc_nodes < <(printf '%s\n' "${_rpc_nodes[@]}" | awk '!seen[$0]++')

            # Tentative RPC parallèle
            _rpc_result=$(parallel_rpc_fetch "$G1PUB_QUERY" "${_rpc_nodes[@]}" 2>/dev/null)
            if [[ -n "$_rpc_result" ]]; then
                _fresh="${_rpc_result%%|*}"
                is_valid_balance "$_fresh" && write_cache "$COINSFILE" "$_fresh"
                exit 0
            fi

            # Fallback Squid parallèle
            if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
                mapfile -t _sq_urls < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null \
                    | jq -r '.squid[].url' 2>/dev/null)
                _sq_result=$(parallel_squid_fetch "$G1PUB_QUERY" "${_sq_urls[@]}" 2>/dev/null)
                if [[ -n "$_sq_result" ]]; then
                    _fresh="${_sq_result%%|*}"
                    is_valid_balance "$_fresh" && write_cache "$COINSFILE" "$_fresh"
                fi
            fi
        ) &>/dev/null &
        disown
        output "$val"
        exit 0
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. Pas de cache valide → fetch synchrone PARALLÈLE via gcli (Duniter RPC)
# ══════════════════════════════════════════════════════════════════════════════
log "Fetch parallèle Duniter RPC pour $G1PUB avec $G1PUB_QUERY"

# Construire liste dédupliquée de noeuds RPC
RPC_NODES=()
[[ -n "$RPC_URL" ]] && RPC_NODES+=("$RPC_URL")

if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    while IFS= read -r node; do
        [[ -n "$node" ]] && RPC_NODES+=("$node")
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null | jq -r '.rpc[].url' 2>/dev/null)
fi

mapfile -t RPC_NODES < <(printf '%s\n' "${RPC_NODES[@]}" | awk '!seen[$0]++')

# ── Fetch RPC parallèle : 1er nœud valide gagne ──────────────────────────────
BALANCE=""
if [[ ${#RPC_NODES[@]} -gt 0 ]]; then
    rpc_result=$(parallel_rpc_fetch "$G1PUB_QUERY" "${RPC_NODES[@]}")
    if [[ -n "$rpc_result" ]]; then
        BALANCE="${rpc_result%%|*}"
        _winning_rpc="${rpc_result##*|}"
        log "Solde obtenu depuis $_winning_rpc : $BALANCE Ğ1 (parallèle)"
    fi
fi

if is_valid_balance "$BALANCE"; then
    write_cache "$COINSFILE" "$BALANCE"
    output "$BALANCE"
    exit 0
fi

# ── Retry : redécouverte forcée des noeuds puis RPC parallèle ─────────────────
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    log "Tous les noeuds RPC ont échoué — redécouverte forcée..."
    "${MY_PATH}/duniter_getnode.sh" refresh >/dev/null 2>&1

    mapfile -t RPC_RETRY < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null \
        | jq -r '.rpc[].url' 2>/dev/null)

    if [[ ${#RPC_RETRY[@]} -gt 0 ]]; then
        rpc_result=$(parallel_rpc_fetch "$G1PUB_QUERY" "${RPC_RETRY[@]}")
        if [[ -n "$rpc_result" ]]; then
            BALANCE="${rpc_result%%|*}"
            _winning_rpc="${rpc_result##*|}"
            log "Solde obtenu après refresh depuis $_winning_rpc : $BALANCE Ğ1"
            write_cache "$COINSFILE" "$BALANCE"
            output "$BALANCE"
            exit 0
        fi
    fi
fi

# ── Fallback Squid GraphQL PARALLÈLE (HTTPS, contourne les firewalls) ─────────
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    log "Tentative fallback via Squid GraphQL parallèle (HTTPS)..."

    mapfile -t SQUID_URLS < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null \
        | jq -r '.squid[].url' 2>/dev/null)

    if [[ ${#SQUID_URLS[@]} -gt 0 ]]; then
        sq_result=$(parallel_squid_fetch "$G1PUB_QUERY" "${SQUID_URLS[@]}")
        if [[ -n "$sq_result" ]]; then
            BALANCE="${sq_result%%|*}"
            _winning_sq="${sq_result##*|}"
            if is_valid_balance "$BALANCE"; then
                log "Solde obtenu via Squid $_winning_sq : $BALANCE Ğ1 (parallèle)"
                write_cache "$COINSFILE" "$BALANCE"
                output "$BALANCE"
                exit 0
            fi
        fi
    fi
fi

# ── Fallback : dernier backup disponible ─────────────────────────────────────
bak=$(find "${HOME}/.zen/tmp" -maxdepth 1 -name "backup.${G1PUB}.*" \
    | sort -r | head -1)
if [[ -s "$bak" ]]; then
    bval=$(cat "$bak")
    is_valid_balance "$bval" && { log "Fallback backup : $bval"; output "$bval"; exit 0; }
fi

log "ERREUR: Impossible de récupérer le solde de $G1PUB"
echo ""
exit 1
