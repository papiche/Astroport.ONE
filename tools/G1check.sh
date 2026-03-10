#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0 — Duniter v2 (squid GraphQL)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1check.sh
#~ Retourne le solde d'un wallet G1 (en Ğ1, 2 décimales).
#~ Cache ~/.zen/tmp/coucou/<G1PUB>.COINS (TTL 15 min actif, 24h stale)
#~ Rafraîchissement en arrière-plan si cache périmé.
#
# Usage:
#   G1check.sh <G1PUB>         → solde en Ğ1 (ex: 2.48)
#   G1check.sh <G1PUB>:ZEN    → solde converti en Ẑen (= (Ğ1-1)*10)
#
# Compatibilité : retourne le même format que l'ancienne version silkaj.
# Décimales : 1 Ğ1 = 100 centimes bruts dans squid (DECIMALS=2)
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
DECIMALS=2                   # 1 Ğ1 = 100 centimes bruts (confirmé sur réseau réel)
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"
CACHE_DIR="${HOME}/.zen/tmp/coucou"
CACHE_FRESH_SEC=900          # 15 min : retour immédiat
CACHE_STALE_SEC=86400        # 24h  : après ça on force le refresh
CACHE_COINS_LIMIT=7          # jours avant suppression du fichier cache

# Mise à jour squid dynamique via duniter_getnode.sh
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    _sq=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_sq" ]] && SQUID_URL="$_sq"
fi

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

# ── Requête squid : retourne solde brut (BigInt) ─────────────────────────────
squid_balance_raw() {
    local addr="$1"
    local query
    query=$(jq -cn --arg a "$addr" '{
        query: "query($a:String!){accounts(condition:{id:$a}){nodes{balance}}}",
        variables: {a: $a}
    }')
    curl -sf --max-time 10 \
        -X POST -H "Content-Type: application/json" \
        --data "$query" "$SQUID_URL" 2>/dev/null \
    | jq -r '.data.accounts.nodes[0].balance // empty'
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

# Validation basique de format (base58, 43-44 chars)
if ! [[ "$G1PUB" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,44}$ ]]; then
    log "ERREUR: G1PUB invalide : $G1PUB"
    exit 1
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
            # Essayer d'abord duniter_getnode squid, puis fallback
            _sq_bg=""
            [[ -x "${MY_PATH}/duniter_getnode.sh" ]] && \
                _sq_bg=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
            [[ -n "$_sq_bg" ]] && SQUID_URL="$_sq_bg"
            raw=$(squid_balance_raw "$G1PUB")
            fresh=$(raw_to_g1 "$raw")
            is_valid_balance "$fresh" && write_cache "$COINSFILE" "$fresh"
        ) &>/dev/null &
        disown
        output "$val"
        exit 0
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. Pas de cache valide → fetch synchrone avec retry multi-squid
# ══════════════════════════════════════════════════════════════════════════════
log "Fetch synchrone squid pour $G1PUB"

# Liste de squids à essayer
SQUIDS=()
[[ -n "$SQUID_URL" ]] && SQUIDS+=("$SQUID_URL")
SQUIDS+=(
    "https://squid.g1.gyroi.de/v1/graphql"
    "https://squid.g1.coinduf.eu/v1/graphql"
    "https://g1-squid.axiom-team.fr/v1/graphql"
)

# Dédupliquer
mapfile -t SQUIDS < <(printf '%s\n' "${SQUIDS[@]}" | awk '!seen[$0]++')

BALANCE=""
for sq in "${SQUIDS[@]}"; do
    SQUID_URL="$sq"
    raw=$(squid_balance_raw "$G1PUB")
    g1=$(raw_to_g1 "$raw")
    if is_valid_balance "$g1" && [[ "$g1" != "0" || -n "$raw" ]]; then
        BALANCE="$g1"
        log "Solde obtenu depuis $sq : $BALANCE Ğ1"
        break
    fi
    log "Échec sur $sq"
done

if is_valid_balance "$BALANCE"; then
    write_cache "$COINSFILE" "$BALANCE"
    output "$BALANCE"
    exit 0
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
