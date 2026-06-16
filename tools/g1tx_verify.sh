#!/bin/bash
################################################################################
# g1tx_verify.sh — Vérifie la présence d'une TX on-chain via squid GraphQL
#
# Usage: g1tx_verify.sh <dest_g1pub> <reference>
#
# Exit codes & stdout :
#   0  "found"     — TX confirmée on-chain (référence trouvée dans les reçues)
#   1  "not_found" — TX absente dans les 50 dernières transactions reçues
#   2  "error"     — Squid inaccessible ou argument invalide
#
# Utilisé par ZEN.ECONOMY.sh pour la reprise WAL après crash post-broadcast.
################################################################################
MY_PATH="$(dirname "$(realpath "$0")")"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

DEST="${1:-}"
REF="${2:-}"

[[ -z "$DEST" || -z "$REF" ]] && { echo "error"; exit 2; }

# ── Découverte dynamique du squid ─────────────────────────────────────────────
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    _sq=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_sq" ]] && SQUID_URL="$_sq"
fi

# Fallback squids (dédupliqués)
mapfile -t _SQUIDS < <(printf '%s\n' \
    "$SQUID_URL" \
    "https://squid.g1.gyroi.de/v1/graphql" \
    "https://squid.g1.coinduf.eu/v1/graphql" \
    "https://g1-squid.axiom-team.fr/v1/graphql" \
    | awk '!seen[$0]++')

# ── Conversion v1 pubkey → SS58 pour la requête squid ────────────────────────
DEST_QUERY="$DEST"
if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]] && ! [[ "$DEST" =~ ^g1 ]]; then
    _ss58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$DEST" 2>/dev/null)
    [[ -n "$_ss58" ]] && DEST_QUERY="$_ss58"
fi

# ── Requête GraphQL : TX reçues par DEST avec référence contenant REF ─────────
QUERY=$(jq -cn --arg addr "$DEST_QUERY" --arg ref "$REF" '{
    query: "query($addr:String!,$ref:String!){
        transfers(
            condition:{toId:$addr},
            filter:{comment:{remark:{includesInsensitive:$ref}}},
            orderBy:BLOCK_NUMBER_DESC,
            first:5
        ){
            nodes{ fromId blockNumber comment{remark} }
        }
    }",
    variables: {addr: $addr, ref: $ref}
}')

for _sq in "${_SQUIDS[@]}"; do
    _raw=$(curl -sf --max-time 10 \
        -X POST -H "Content-Type: application/json" \
        --data "$QUERY" "$_sq" 2>/dev/null)
    if jq -e '.data.transfers' <<<"$_raw" >/dev/null 2>&1; then
        _count=$(jq -r '.data.transfers.nodes | length' <<<"$_raw" 2>/dev/null)
        if [[ "${_count:-0}" -gt 0 ]]; then
            echo "found"
            exit 0
        else
            echo "not_found"
            exit 1
        fi
    fi
done

echo "error"
exit 2
