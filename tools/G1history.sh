#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0 — Duniter v2 (squid GraphQL)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1history.sh
#~ Retourne l'historique des transactions d'un wallet G1 en JSON.
#~ Source : indexeur Squid Duniter v2 (GraphQL)
#~ Cache ~/.zen/tmp/coucou/<G1PUB>.TX.json (TTL 1h)
#
# Usage:
#   G1history.sh <G1PUB> [limit]    → JSON tableau de transactions
#
# Format de sortie (compatible avec G1impots.sh) :
# {
#   "history": [
#     {
#       "Date": "2024-01-15T10:30:00",
#       "Amounts Ğ1": 2.48,          ← positif = reçu, négatif = envoyé
#       "Issuers/Recipients": "<pubkey>",
#       "Reference": "<commentaire>",
#       "blockNumber": 12345,
#       "direction": "received|sent"
#     }, ...
#   ]
# }
#
# Note: Les montants bruts squid sont en centimes (DECIMALS=2).
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
DECIMALS=2
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"
CACHE_DIR="${HOME}/.zen/tmp/coucou"
CACHE_TTL_SEC=3600     # 1h
DEFAULT_LIMIT=50       # transactions max par défaut

# Mise à jour squid dynamique
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    _sq=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_sq" ]] && SQUID_URL="$_sq"
fi

log() { echo "[G1history] $*" >&2; }

# ── Validation ────────────────────────────────────────────────────────────────
G1PUB="${1:-}"
TX_LIMIT="${2:-$DEFAULT_LIMIT}"

[[ -z "$G1PUB" ]] && { log "USAGE: G1history.sh <G1PUB> [limit]"; exit 1; }
[[ ! "$G1PUB" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,50}$ ]] && {
    log "ERREUR: G1PUB invalide : $G1PUB"; exit 1; }

# Conversion v1 pubkey → SS58 pour requête squid
G1PUB_QUERY="$G1PUB"
if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]] && ! [[ "$G1PUB" =~ ^g1 ]]; then
    SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$G1PUB" 2>/dev/null)
    [[ -n "$SS58" ]] && G1PUB_QUERY="$SS58" && log "Conversion v1→SS58 : $G1PUB → $SS58"
fi

mkdir -p "$CACHE_DIR"
HISTFILE="$CACHE_DIR/${G1PUB}.TX.json"

# ── Cache (1h) ────────────────────────────────────────────────────────────────
if [[ -s "$HISTFILE" ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "$HISTFILE") ))
    if [[ $age -lt $CACHE_TTL_SEC ]]; then
        jq empty "$HISTFILE" 2>/dev/null && { cat "$HISTFILE"; exit 0; }
    fi
    find "$CACHE_DIR" -mtime +1 -name "*.TX.json" -delete 2>/dev/null
fi

# ── Requête squid : toutes les TX (reçues + envoyées) ────────────────────────
# On récupère les 2 sens en une seule requête (transfers filter)
squid_query() {
    local addr="$1"
    local limit="$2"
    jq -cn --arg a "$addr" --argjson n "$limit" '{
        query: "query($a:String!,$n:Int!){
            received: transfers(condition:{toId:$a}, orderBy:BLOCK_NUMBER_DESC, first:$n){
                nodes{ fromId toId amount timestamp blockNumber comment{remark} }
            }
            sent: transfers(condition:{fromId:$a}, orderBy:BLOCK_NUMBER_DESC, first:$n){
                nodes{ fromId toId amount timestamp blockNumber comment{remark} }
            }
        }",
        variables: {a: $a, n: $n}
    }'
}

log "Fetch squid pour ${G1PUB_QUERY:0:16}... (limit=$TX_LIMIT)"

SQUIDS=("$SQUID_URL"
    "https://squid.g1.gyroi.de/v1/graphql"
    "https://squid.g1.coinduf.eu/v1/graphql"
    "https://g1-squid.axiom-team.fr/v1/graphql"
)
mapfile -t SQUIDS < <(printf '%s\n' "${SQUIDS[@]}" | awk '!seen[$0]++')

RAW_RESP=""
for sq in "${SQUIDS[@]}"; do
    RAW_RESP=$(curl -sf --max-time 15 \
        -X POST -H "Content-Type: application/json" \
        --data "$(squid_query "$G1PUB_QUERY" "$TX_LIMIT")" \
        "$sq" 2>/dev/null)
    jq -e '.data.received' <<<"$RAW_RESP" >/dev/null 2>&1 && {
        SQUID_URL="$sq"; break; }
    RAW_RESP=""
    log "Échec sur $sq"
done

if [[ -z "$RAW_RESP" ]]; then
    log "ERREUR: Aucun squid disponible"
    # Retourner un historique vide plutôt qu'une erreur fatale
    echo '{"history":[]}'
    exit 0
fi

# ── Transformation → format G1history compatible ─────────────────────────────
# Format cible :
#   { "history": [ { "Date", "Amounts Ğ1", "Issuers/Recipients", "Reference",
#                    "blockNumber", "direction" } ] }
#
# Montant : positif si reçu, négatif si envoyé (en Ğ1 float)

HISTORY_JSON=$(echo "$RAW_RESP" | jq --arg wallet "$G1PUB" '
    def to_g1(raw): (raw | tonumber) / 100;

    [
      # TX reçues (positives)
      (.data.received.nodes // [])[] |
      {
        "Date":               (.timestamp // ""),
        "Amounts Ğ1":         (.amount | to_g1(.)),
        "Issuers/Recipients": (.fromId // ""),
        "Reference":          (.comment.remark // ""),
        "blockNumber":        (.blockNumber // 0),
        "direction":          "received"
      }
    ] +
    [
      # TX envoyées (négatives)
      (.data.sent.nodes // [])[] |
      {
        "Date":               (.timestamp // ""),
        "Amounts Ğ1":         ((.amount | tonumber) / 100 * -1),
        "Issuers/Recipients": (.toId // ""),
        "Reference":          (.comment.remark // ""),
        "blockNumber":        (.blockNumber // 0),
        "direction":          "sent"
      }
    ] |
    sort_by(.blockNumber) | reverse
')

# Wrapper final
RESULT=$(jq -n --argjson h "$HISTORY_JSON" '{"history": $h}')

# Validation JSON
if ! jq -e '.history | length >= 0' <<<"$RESULT" >/dev/null 2>&1; then
    log "ERREUR: JSON invalide produit"
    echo "{}"
    exit 1
fi

# Écriture cache
echo "$RESULT" > "$HISTFILE"
echo "$RESULT"
exit 0
