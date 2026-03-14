#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 3.0 — Duniter v2 (gcli RPC — source de vérité on-chain)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1check.sh
#~ Retourne le solde d'un wallet G1 (en Ğ1, 2 décimales).
#~ Source de vérité : gcli account balance (Duniter RPC, on-chain)
#~ Cache ~/.zen/tmp/coucou/<G1PUB>.COINS (TTL 12s frais, 60s périmé)
#~ Rafraîchissement en arrière-plan si cache périmé.
#
# Usage:
#   G1check.sh <G1PUB>         → solde en Ğ1 (ex: 2.48)
#   G1check.sh <G1PUB>:ZEN    → solde converti en Ẑen (= (Ğ1-1)*10)
#
# Compatibilité : retourne le même format que l'ancienne version silkaj.
# Décimales : 1 Ğ1 = 100 centimes bruts (DECIMALS=2)
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

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
# 1. Cache frais (< 15 min) → retour immédiat
# ══════════════════════════════════════════════════════════════════════════════
age=$(file_age_sec "$COINSFILE") 2>/dev/null || age=99999
if [[ $age -lt $CACHE_FRESH_SEC ]]; then
    val=$(read_cache "$COINSFILE") && { output "$val"; exit 0; }
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. Cache périmé mais valide (< 24h) → retour immédiat + refresh BG
# ══════════════════════════════════════════════════════════════════════════════
if [[ $age -lt $CACHE_STALE_SEC ]]; then
    val=$(read_cache "$COINSFILE")
    if [[ -n "$val" ]]; then
        log "Solde en cache (${age}s) — refresh en arrière-plan"
        # Refresh arrière-plan (stdout/stderr isolés)
        (
            exec >/dev/null 2>&1
            sleep 1
            _rpc_bg=""
            [[ -x "${MY_PATH}/duniter_getnode.sh" ]] && \
                _rpc_bg=$("${MY_PATH}/duniter_getnode.sh" rpc 2>/dev/null)
            [[ -z "$_rpc_bg" ]] && _rpc_bg="$RPC_URL"
            raw=$(gcli_balance_raw "$G1PUB_QUERY" "$_rpc_bg")
            fresh=$(raw_to_g1 "$raw")
            is_valid_balance "$fresh" && write_cache "$COINSFILE" "$fresh"
        ) &>/dev/null &
        disown
        output "$val"
        exit 0
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. Pas de cache valide → fetch synchrone via gcli (Duniter RPC)
# ══════════════════════════════════════════════════════════════════════════════
log "Fetch synchrone Duniter RPC pour $G1PUB"

# Liste de noeuds RPC à essayer
RPC_NODES=()
[[ -n "$RPC_URL" ]] && RPC_NODES+=("$RPC_URL")

# Récupérer tous les noeuds disponibles via duniter_getnode.sh
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    while IFS= read -r node; do
        [[ -n "$node" ]] && RPC_NODES+=("$node")
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null | jq -r '.rpc[].url' 2>/dev/null)
fi

# Dédupliquer
mapfile -t RPC_NODES < <(printf '%s\n' "${RPC_NODES[@]}" | awk '!seen[$0]++')

BALANCE=""
for rpc in "${RPC_NODES[@]}"; do
    raw=$(gcli_balance_raw "$G1PUB_QUERY" "$rpc")
    if [[ -n "$raw" ]]; then
        g1=$(raw_to_g1 "$raw")
        BALANCE="$g1"
        log "Solde obtenu depuis $rpc : $BALANCE Ğ1"
        break
    fi
    log "Échec sur $rpc"
done

if is_valid_balance "$BALANCE"; then
    write_cache "$COINSFILE" "$BALANCE"
    output "$BALANCE"
    exit 0
fi

# ── Retry : forcer une redécouverte des noeuds et réessayer ──────────────────
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    log "Tous les noeuds ont échoué — redécouverte forcée..."
    "${MY_PATH}/duniter_getnode.sh" refresh >/dev/null 2>&1
    while IFS= read -r rpc; do
        [[ -z "$rpc" ]] && continue
        raw=$(gcli_balance_raw "$G1PUB_QUERY" "$rpc")
        if [[ -n "$raw" ]]; then
            BALANCE=$(raw_to_g1 "$raw")
            log "Solde obtenu après refresh depuis $rpc : $BALANCE Ğ1"
            write_cache "$COINSFILE" "$BALANCE"
            output "$BALANCE"
            exit 0
        fi
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null | jq -r '.rpc[].url' 2>/dev/null)
fi

# ── Fallback squid : requête GraphQL HTTPS (pas de WSS, contourne les firewalls) ──
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    log "Tentative fallback via Squid GraphQL (HTTPS)..."
    while IFS= read -r squid_url; do
        [[ -z "$squid_url" ]] && continue
        squid_resp=$(curl -sf --max-time 8 -X POST "$squid_url" \
            -H "Content-Type: application/json" \
            --data-binary "{\"query\":\"query(\$w:String!){accounts(condition:{id:\$w}){nodes{totalBalance}}}\",\"variables\":{\"w\":\"$G1PUB_QUERY\"}}" \
            2>/dev/null)
        squid_raw=$(echo "$squid_resp" | jq -r '.data.accounts.nodes[0].totalBalance // empty' 2>/dev/null)
        if [[ -n "$squid_raw" && "$squid_raw" != "null" ]]; then
            BALANCE=$(raw_to_g1 "$squid_raw")
            if is_valid_balance "$BALANCE"; then
                log "Solde obtenu via Squid $squid_url : $BALANCE Ğ1"
                write_cache "$COINSFILE" "$BALANCE"
                output "$BALANCE"
                exit 0
            fi
        fi
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null | jq -r '.squid[].url' 2>/dev/null)
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
