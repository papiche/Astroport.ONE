#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1 — Ğ1-Nostr (N²), dual-stack de PAYforSURE.sh
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ g1n2_pay.sh
#~ Émet une transaction Ğ1-Nostr (N²) — kind 30852, cf. NIP-101/KIND_REGISTRY.md.
#~ Contrairement à PAYforSURE.sh (gcli/blockchain), la confirmation est
#~ quasi-immédiate (retour NIP-20 "OK"/"reject" du relay strfry) : pas de
#~ polling multi-blocs. Le relay (filter/30852.sh) reste l'arbitre final —
#~ un rejet dû à une course avec une autre transaction concurrente (prev
#~ devenu obsolète) est une situation NORMALE, pas une erreur fatale : ce
#~ script relit son propre cache et retente automatiquement (borné).
#
# Usage : g1n2_pay.sh <.secret.nostr> <amount> <dest_hex_ou_g1pub> [comment] [moats] [--mint]
#   <.secret.nostr>  : keyfile de l'émetteur (format NSEC=...;NPUB=...;HEX=...;)
#   <amount>         : montant Ğ1-N² (nombre positif, 2 décimales max)
#   <dest>           : HEX NOSTR (64 chars) ou G1PUB MULTIPASS local
#   [comment]        : libre, informatif — jamais utilisé par le filtre
#   [moats]          : identifiant de reprise (repris tel quel dans les logs,
#                       cohérence avec PAYforSURE.sh — sans effet sur le kind 30852)
#   --mint           : émission (pont Ğ1→N², cf. N2_Bridge.sh) — l'émetteur doit
#                       figurer dans n2_mint_authorities.txt (vérifié côté relay,
#                       jamais fait confiance ici) ; ne débite jamais l'émetteur
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
loge() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}" >&2; }
logw() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}" >&2; }
logok(){ echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}" >&2; }

N2_LEDGER_LIB="$HOME/.zen/workspace/NIP-101/relay.writePolicy.plugin/filter/n2_ledger_lib.sh"
if [[ ! -s "$N2_LEDGER_LIB" ]]; then
    loge "n2_ledger_lib.sh introuvable ($N2_LEDGER_LIB) — NIP-101 installé ?"
    exit 1
fi
source "$N2_LEDGER_LIB"

NOSTR_SEND="${MY_PATH}/nostr_send_note.py"
RELAY_URL="${myRELAY:-ws://127.0.0.1:7777}"
MAX_RETRIES=3
RETRY_BACKOFF_SEC=1

# ── Arguments ──────────────────────────────────────────────────────────────
# --mint : émission (pont Ğ1→N², cf. N2_Bridge.sh) — l'émetteur doit figurer
# dans n2_mint_authorities.txt (vérifié côté relay par filter/30852.sh, jamais
# fait confiance ici) ; ne débite jamais l'émetteur, saute la pré-vérification
# locale de solde. Extrait AVANT le parsing positionnel (même précaution que
# --fresh dans g1n2_check.sh/G1check.sh).
IS_MINT="false"
_ARGS=()
for _a in "$@"; do
    if [[ "$_a" == "--mint" ]]; then
        IS_MINT="true"
    else
        _ARGS+=("$_a")
    fi
done
set -- "${_ARGS[@]}"
unset _a _ARGS

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <.secret.nostr> <amount> <dest_hex_ou_g1pub> [comment] [moats] [--mint]"
    exit 1
fi

KEYFILE="$1"
AMOUNT="$2"
DEST_ORIGINAL="$3"
COMMENT="${4:-}"
MOATS="${5:-$(date -u +"%Y%m%d%H%M%S%4N")}"

[[ -s "$KEYFILE" ]] || { loge "Keyfile introuvable : $KEYFILE"; exit 1; }

# ── Montant ────────────────────────────────────────────────────────────────
if ! [[ "$AMOUNT" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || ! awk "BEGIN{exit !($AMOUNT > 0)}"; then
    loge "Montant invalide : $AMOUNT"
    exit 1
fi

# ── Émetteur : HEX depuis le keyfile ───────────────────────────────────────
SENDER_HEX=$(grep -oP 'HEX=\K[0-9a-f]{64}' "$KEYFILE" | head -1)
if [[ -z "$SENDER_HEX" ]]; then
    loge "Impossible d'extraire HEX depuis $KEYFILE (format attendu: NSEC=...;NPUB=...;HEX=...;)"
    exit 1
fi

# ── Destinataire : HEX direct ou résolution G1PUB → MULTIPASS local ────────
# (même algorithme que g1n2_check.sh — voir son commentaire pour le détail)
DEST_HEX=""
if [[ "$DEST_ORIGINAL" =~ ^[0-9a-f]{64}$ ]]; then
    DEST_HEX="$DEST_ORIGINAL"
else
    for dir in "$HOME/.zen/game/nostr"/*/; do
        [[ -s "${dir}.secret.dunikey" ]] || continue
        pub_v1=$(grep -E '^pub:' "${dir}.secret.dunikey" 2>/dev/null | head -1 | awk '{print $2}')
        [[ -n "$pub_v1" && "$pub_v1" == "$DEST_ORIGINAL" ]] || continue
        [[ -s "${dir}HEX" ]] && DEST_HEX=$(cat "${dir}HEX" 2>/dev/null)
        break
    done
fi
if [[ -z "$DEST_HEX" ]]; then
    loge "Impossible de résoudre le destinataire '$DEST_ORIGINAL' en HEX NOSTR"
    exit 1
fi
if [[ "$DEST_HEX" == "$SENDER_HEX" ]]; then
    loge "Auto-paiement refusé (émetteur == destinataire)"
    exit 1
fi

log "=== g1n2_pay démarrage (Ğ1-Nostr N²) ==="
log "ÉMETTEUR : ${SENDER_HEX:0:12}... $([[ "$IS_MINT" == "true" ]] && echo '(mint)')"
log "DEST     : ${DEST_HEX:0:12}..."
log "MONTANT  : ${AMOUNT}"
log "MOATS    : $MOATS"

# ── Pré-vérification LOCALE (non-authoritative — échec rapide sans round-trip
# réseau si manifestement insuffisant ; le relay reste l'arbitre final). Sautée
# en mode mint : un mint ne débite jamais l'émetteur (cf. filter/30852.sh).
if [[ "$IS_MINT" != "true" ]]; then
    sender_state=$(n2_ledger_get_balance "$SENDER_HEX")
    IFS='|' read -r local_balance _ <<< "$sender_state"
    [[ -z "$local_balance" ]] && local_balance="0"
    if ! awk "BEGIN{exit !($local_balance >= $AMOUNT)}"; then
        loge "Solde Ğ1-N² insuffisant (cache local) : ${local_balance} < ${AMOUNT} — abandon sans tenter le relay"
        exit 1
    fi
fi

EVENT_ID=""
LAST_ERROR=""

for ((attempt = 1; attempt <= MAX_RETRIES; attempt++)); do
    # prev relu à CHAQUE tentative — après un rejet, le cache a pu être mis à
    # jour (par notre propre échec précédent si le relay avait quand même
    # avancé la chaîne, ou par une transaction concurrente d'un autre process).
    sender_state=$(n2_ledger_get_balance "$SENDER_HEX")
    IFS='|' read -r cur_balance cur_last_tx <<< "$sender_state"
    prev="${cur_last_tx:-genesis}"
    [[ -z "$prev" ]] && prev="genesis"

    nonce=$(head -c4 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')
    d_tag="n2-$(date +%s)-${nonce}"

    if [[ "$IS_MINT" == "true" ]]; then
        tags_json=$(jq -cn --arg d "$d_tag" --arg p "$DEST_HEX" --arg amount "$AMOUNT" --arg prev "$prev" \
            '[["d",$d],["p",$p],["amount",$amount],["prev",$prev],["t","g1-n2"],["t","mint"]]')
    else
        tags_json=$(jq -cn --arg d "$d_tag" --arg p "$DEST_HEX" --arg amount "$AMOUNT" --arg prev "$prev" \
            '[["d",$d],["p",$p],["amount",$amount],["prev",$prev],["t","g1-n2"]]')
    fi

    log "Tentative ${attempt}/${MAX_RETRIES} — prev=${prev:0:12}... d=${d_tag}"

    result_json=$(python3 "$NOSTR_SEND" --json \
        --keyfile "$KEYFILE" --kind 30852 --content "" \
        --tags "$tags_json" --relays "$RELAY_URL" 2>/tmp/g1n2_pay_err.$$)
    rc=$?
    stderr_content=$(cat /tmp/g1n2_pay_err.$$ 2>/dev/null); rm -f /tmp/g1n2_pay_err.$$

    success=$(echo "$result_json" | jq -r '.success // false' 2>/dev/null)
    if [[ "$rc" -eq 0 && "$success" == "true" ]]; then
        EVENT_ID=$(echo "$result_json" | jq -r '.event_id // empty' 2>/dev/null)
        logok "=== TRANSACTION Ğ1-N² ACCEPTÉE === id=${EVENT_ID:0:16}..."
        break
    fi

    LAST_ERROR="$stderr_content"
    if echo "$stderr_content" | grep -qi "solde insuffisant"; then
        loge "Rejet définitif : solde insuffisant côté relay — abandon (retry inutile)"
        break
    elif echo "$stderr_content" | grep -qi "prev\|fork\|rejeu\|déjà utilisé"; then
        logw "Rejet probable dû à une course (prev obsolète/d rejoué) — retry ${attempt}/${MAX_RETRIES}"
    else
        logw "Rejet (raison non catégorisée) — retry ${attempt}/${MAX_RETRIES} : ${stderr_content:-<vide>}"
    fi
    [[ $attempt -lt $MAX_RETRIES ]] && sleep "$RETRY_BACKOFF_SEC"
done

if [[ -z "$EVENT_ID" ]]; then
    loge "Échec après ${MAX_RETRIES} tentative(s) : ${LAST_ERROR:-raison inconnue}"
    exit 1
fi

echo "$EVENT_ID"
exit 0
