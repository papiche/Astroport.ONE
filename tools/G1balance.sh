#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0 — Duniter v2 (squid GraphQL)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1balance.sh
#~ Retourne le solde JSON complet d'un wallet G1.
#~ Duniter v2 ne distingue pas "pending" vs "blockchain" comme v1 —
#~ le squid ne retourne que le solde confirmé. pending est mis à 0.
#
# Usage:
#   G1balance.sh <G1PUB>           → JSON (valeurs en centimes, comme silkaj)
#   G1balance.sh --convert <G1PUB> → JSON (valeurs converties en Ğ1)
#
# Format de sortie (compatible silkaj) :
# {
#   "balances": {
#     "pending":    0,
#     "blockchain": 248,     ← centimes bruts (ou Ğ1 si --convert)
#     "total":      248
#   }
# }
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"

if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    _sq=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_sq" ]] && SQUID_URL="$_sq"
fi

log() { echo "[G1balance] $*" >&2; }

is_valid_g1pub() {
    [[ "$1" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,44}$ ]]
}

# ── Parse args ────────────────────────────────────────────────────────────────
CONVERT="false"
G1PUB=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --convert) CONVERT="true"; shift ;;
        *) G1PUB="$1"; shift ;;
    esac
done

[[ -z "$G1PUB" ]] && {
    log "USAGE: G1balance.sh [--convert] <G1PUB>"
    echo '{"balances": {"pending": 0, "blockchain": 0, "total": 0}}'
    exit 1
}
is_valid_g1pub "$G1PUB" || {
    log "ERREUR: G1PUB invalide : $G1PUB"
    echo '{"balances": {"pending": 0, "blockchain": 0, "total": 0}}'
    exit 1
}

# ── Requête squid ─────────────────────────────────────────────────────────────
squid_balance() {
    local addr="$1" sq="$2"
    local query
    query=$(jq -cn --arg a "$addr" '{
        query: "query($a:String!){accounts(condition:{id:$a}){nodes{balance}}}",
        variables: {a: $a}
    }')
    curl -sf --max-time 10 \
        -X POST -H "Content-Type: application/json" \
        --data "$query" "$sq" 2>/dev/null \
    | jq -r '.data.accounts.nodes[0].balance // empty'
}

log "Fetch balance pour ${G1PUB:0:12}..."

SQUIDS=("$SQUID_URL"
    "https://squid.g1.gyroi.de/v1/graphql"
    "https://squid.g1.coinduf.eu/v1/graphql"
    "https://g1-squid.axiom-team.fr/v1/graphql"
)
mapfile -t SQUIDS < <(printf '%s\n' "${SQUIDS[@]}" | awk '!seen[$0]++')

RAW=""
for sq in "${SQUIDS[@]}"; do
    candidate=$(squid_balance "$G1PUB" "$sq")
    if [[ -n "$candidate" && "$candidate" != "null" ]]; then
        RAW="$candidate"
        log "Balance brute : $RAW centimes"
        break
    fi
    log "Échec sur $sq"
done

if [[ -z "$RAW" ]]; then
    log "ERREUR: Aucun squid n'a répondu"
    echo '{"balances": {"pending": 0, "blockchain": 0, "total": 0}}'
    exit 1
fi

# ── Formatage JSON ─────────────────────────────────────────────────────────────
if [[ "$CONVERT" == "true" ]]; then
    # Convertir centimes → Ğ1
    jq -n --argjson raw "$RAW" '{
        "balances": {
            "pending":    0,
            "blockchain": ($raw / 100),
            "total":      ($raw / 100)
        }
    }'
else
    # Retourner les centimes bruts (compatibilité silkaj)
    jq -n --argjson raw "$RAW" '{
        "balances": {
            "pending":    0,
            "blockchain": $raw,
            "total":      $raw
        }
    }'
fi
exit 0
