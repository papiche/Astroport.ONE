#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 3.0 — Duniter v2 (gcli RPC — source de vérité on-chain)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1balance.sh
#~ Retourne le solde JSON complet d'un wallet G1.
#~ Source de vérité : gcli account balance (Duniter RPC, on-chain)
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
GCLI="${GCLI:-gcli}"

# Noeud RPC Duniter (source de vérité on-chain)
RPC_URL=""
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    RPC_URL=$("${MY_PATH}/duniter_getnode.sh" rpc 2>/dev/null)
fi
[[ -z "$RPC_URL" ]] && RPC_URL="${G1_WS_NODE:-wss://g1.1000i100.fr/ws}"

log() { echo "[G1balance] $*" >&2; }

is_valid_g1pub() {
    [[ "$1" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,50}$ ]]
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

# Conversion v1 pubkey → SS58 (gcli utilise le format SS58)
G1PUB_QUERY="$G1PUB"
if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]] && ! [[ "$G1PUB" =~ ^g1 ]]; then
    SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$G1PUB" 2>/dev/null)
    [[ -n "$SS58" ]] && G1PUB_QUERY="$SS58" && log "Conversion v1→SS58 : $G1PUB → $SS58"
fi

# ── Requête gcli : solde total via Duniter RPC (on-chain) ─────────────────────
# Retourne total_balance (inclut le 1 Ğ1 bloqué) pour compatibilité silkaj/ẐEN
gcli_balance_raw() {
    local addr="$1" rpc="$2"
    $GCLI --no-password -a "$addr" -u "$rpc" -o json account balance 2>/dev/null \
        | jq -r '.total_balance // empty'
}

log "Fetch balance Duniter RPC pour ${G1PUB:0:12}..."

# Liste de noeuds RPC à essayer
RPC_NODES=("$RPC_URL")
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    while IFS= read -r node; do
        [[ -n "$node" ]] && RPC_NODES+=("$node")
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null | jq -r '.rpc[].url' 2>/dev/null)
fi
RPC_NODES+=("wss://g1.1000i100.fr/ws" "wss://g1.libra.music:443")
mapfile -t RPC_NODES < <(printf '%s\n' "${RPC_NODES[@]}" | awk '!seen[$0]++')

RAW=""
for rpc in "${RPC_NODES[@]}"; do
    candidate=$(gcli_balance_raw "$G1PUB_QUERY" "$rpc")
    if [[ -n "$candidate" && "$candidate" != "null" ]]; then
        RAW="$candidate"
        log "Balance brute : $RAW centimes (via $rpc)"
        break
    fi
    log "Échec sur $rpc"
done

if [[ -z "$RAW" ]]; then
    log "ERREUR: Aucun noeud Duniter n'a répondu"
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
