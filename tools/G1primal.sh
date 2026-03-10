#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0 — Duniter v2 (squid GraphQL)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1primal.sh
#~ Retourne la source primale d'un wallet G1 :
#~ = fromId de la toute première transaction reçue (blockNumber le plus bas)
#~ Cache permanent (~/.zen/tmp/coucou/<G1PUB>.primal) — jamais périmé.
#
# Usage:
#   G1primal.sh <G1PUB>        → pubkey source primale
#   G1primal.sh --json <G1PUB> → JSON {"primal_source_pubkey": "..."}
#
# Compatibilité : même interface que l'ancienne version silkaj.
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"
CACHE_DIR="${HOME}/.zen/tmp/coucou"

# Mise à jour squid dynamique
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    _sq=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_sq" ]] && SQUID_URL="$_sq"
fi

log() { echo "[G1primal] $*" >&2; }

is_valid_g1pub() {
    [[ "$1" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,44}$ ]]
}

# ── Parse args ────────────────────────────────────────────────────────────────
JSON_MODE="false"
G1PUB=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE="true"; shift ;;
        *) G1PUB="$1"; shift ;;
    esac
done

[[ -z "$G1PUB" ]] && { log "USAGE: G1primal.sh [--json] <G1PUB>"; exit 1; }
is_valid_g1pub "$G1PUB" || { log "ERREUR: G1PUB invalide : $G1PUB"; exit 1; }

mkdir -p "$CACHE_DIR"
PRIMALFILE="$CACHE_DIR/${G1PUB}.primal"

# ── Cache permanent (primal ne change jamais) ─────────────────────────────────
if [[ -s "$PRIMALFILE" ]]; then
    primal=$(head -1 "$PRIMALFILE")
    if is_valid_g1pub "$primal"; then
        log "Primal en cache : ${primal:0:12}..."
        if [[ "$JSON_MODE" == "true" ]]; then
            jq -n --arg p "$primal" '{"primal_source_pubkey": $p}'
        else
            echo "$primal"
        fi
        exit 0
    fi
    rm -f "$PRIMALFILE"
fi

# ── Requête squid : 1ère TX reçue (blockNumber le plus bas) ──────────────────
squid_primal() {
    local addr="$1"
    local sq="$2"
    local query
    query=$(jq -cn --arg a "$addr" '{
        query: "query($a:String!){transfers(filter:{toId:{equalTo:$a}},orderBy:BLOCK_NUMBER_ASC,first:1){nodes{fromId blockNumber}}}",
        variables: {a: $a}
    }')
    curl -sf --max-time 10 \
        -X POST -H "Content-Type: application/json" \
        --data "$query" "$sq" 2>/dev/null \
    | jq -r '.data.transfers.nodes[0].fromId // empty'
}

log "Fetch primal pour ${G1PUB:0:12}..."

SQUIDS=("$SQUID_URL"
    "https://squid.g1.gyroi.de/v1/graphql"
    "https://squid.g1.coinduf.eu/v1/graphql"
    "https://g1-squid.axiom-team.fr/v1/graphql"
)
mapfile -t SQUIDS < <(printf '%s\n' "${SQUIDS[@]}" | awk '!seen[$0]++')

PRIMAL=""
for sq in "${SQUIDS[@]}"; do
    candidate=$(squid_primal "$G1PUB" "$sq")
    if is_valid_g1pub "$candidate"; then
        PRIMAL="$candidate"
        log "Primal trouvé via $sq : ${PRIMAL:0:12}..."
        break
    fi
    log "Échec sur $sq"
done

if is_valid_g1pub "$PRIMAL"; then
    # Cache permanent
    echo "$PRIMAL" > "$PRIMALFILE"
    chmod 644 "$PRIMALFILE"

    if [[ "$JSON_MODE" == "true" ]]; then
        jq -n --arg p "$PRIMAL" '{"primal_source_pubkey": $p}'
    else
        echo "$PRIMAL"
    fi
    exit 0
fi

log "ERREUR: Impossible de trouver le primal de $G1PUB"
echo ""
exit 1
