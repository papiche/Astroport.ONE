#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1 — Pont de migration Ğ1-Duniter → Ğ1-Nostr (N²)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ N2_Bridge.sh
#~ Migre le solde Duniter réel (transférable) d'un membre local vers le
#~ registre Ğ1-Nostr (N²) : transfert réel Duniter vers le wallet-coffre de
#~ station (UPLANETNAME_G1), puis mint 30852 créditant le membre du même
#~ montant sur N². Propage ensuite une "toile de confiance" de courtoisie
#~ (1 Ğ1-N² + follow forcé) aux stations sœurs/contacts déjà connus par CETTE
#~ station — jamais à la Toile de Confiance Duniter (aucune commande de
#~ listing n'existe pour celle-ci, cf. KIND_REGISTRY.md kind 30852).
#
# Usage : N2_Bridge.sh <EMAIL>   (un membre local à la fois)
#
# Idempotence : marqueur permanent <MEMBER_DIR>/.n2_bridged — posé UNIQUEMENT
# après un mint réussi (si le solde transférable était nul, rien n'est marqué :
# le script peut être relancé plus tard une fois le membre approvisionné).
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
loge() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}" >&2; }
logw() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}" >&2; }
logok(){ echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}" >&2; }

MINT_KEYFILE="$HOME/.zen/game/uplanet.G1.nostr"
MAX_COURTESY_PER_RUN="${MAX_COURTESY_PER_RUN:-20}"
COURTESY_RUN_MARKER="$HOME/.zen/tmp/n2_bridge_courtesy_last_run"
COURTESY_MIN_INTERVAL_SEC="${COURTESY_MIN_INTERVAL_SEC:-3600}"   # 1h entre deux vagues de courtoisie
COURTESY_AMOUNT="1.00"

# ── Arguments ──────────────────────────────────────────────────────────────
EMAIL="${1:-}"
[[ -z "$EMAIL" ]] && { echo "Usage: $0 <EMAIL>"; exit 1; }

MEMBER_DIR="$HOME/.zen/game/nostr/$EMAIL"
[[ -d "$MEMBER_DIR" ]] || { loge "Membre local introuvable : $MEMBER_DIR"; exit 1; }

BRIDGE_MARKER="$MEMBER_DIR/.n2_bridged"
if [[ -f "$BRIDGE_MARKER" ]]; then
    log "Déjà bridgé (marqueur présent) : $EMAIL — rien à faire"
    exit 0
fi

DUNIKEY="$MEMBER_DIR/.secret.dunikey"
MEMBER_NOSTR_KEYFILE="$MEMBER_DIR/.secret.nostr"
HEX_FILE="$MEMBER_DIR/HEX"
for f in "$DUNIKEY" "$MEMBER_NOSTR_KEYFILE" "$HEX_FILE"; do
    [[ -s "$f" ]] || { loge "Fichier requis manquant : $f"; exit 1; }
done
[[ -s "$MINT_KEYFILE" ]] || { loge "Clé mint introuvable : $MINT_KEYFILE (station non initialisée ?)"; exit 1; }

G1PUB=$(grep -E '^pub:' "$DUNIKEY" 2>/dev/null | head -1 | awk '{print $2}')
MEMBER_HEX=$(cat "$HEX_FILE" 2>/dev/null)
[[ -z "$G1PUB" || -z "$MEMBER_HEX" ]] && { loge "Impossible d'extraire G1PUB/HEX pour $EMAIL"; exit 1; }

log "=== N2_Bridge démarrage pour $EMAIL ==="
log "G1PUB   : ${G1PUB:0:12}..."
log "HEX     : ${MEMBER_HEX:0:12}..."

################################################################################
# 1. Solde Duniter réel — mode DUNITER EXPLICITE (ne pas hériter d'un
#    G1_MODE=NOSTR ambiant de l'environnement appelant, qui casserait tout).
################################################################################
BALANCE=$(G1_MODE=DUNITER "${MY_PATH}/G1check.sh" "$G1PUB" --fresh 2>/dev/null)
if [[ -z "$BALANCE" ]] || ! [[ "$BALANCE" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    loge "Impossible de récupérer le solde Duniter de $EMAIL — abandon"
    exit 1
fi
log "Solde Duniter : ${BALANCE} Ğ1"

# Garder 1 Ğ1 (existential deposit) — même seuil que PAYforSURE.sh/ZEN.ECONOMY.sh.
TRANSFERABLE=$(awk "BEGIN{v=$BALANCE-1; if (v<0) v=0; printf \"%.2f\", v}")

if awk "BEGIN{exit !($TRANSFERABLE <= 0)}"; then
    log "Rien à transférer (solde transférable nul) — $EMAIL sera bridgé lors d'un prochain run mieux approvisionné"
    exit 0
fi
log "Montant transférable : ${TRANSFERABLE} Ğ1"

################################################################################
# 2. Transfert Duniter réel vers le wallet-coffre (mode DUNITER, PAYforSURE.sh
#    inchangé — aucune modification de son comportement existant).
################################################################################
if [[ -z "${UPLANETNAME_G1:-}" ]]; then
    loge "UPLANETNAME_G1 non défini (my.sh non chargé correctement ?) — abandon"
    exit 1
fi

log "Transfert Duniter réel : ${TRANSFERABLE} Ğ1 → wallet-coffre (UPLANETNAME_G1)"
G1_MODE=DUNITER "${MY_PATH}/PAYforSURE.sh" "$DUNIKEY" "$TRANSFERABLE" "$UPLANETNAME_G1" "N2_BRIDGE:${EMAIL}"
PAY_RC=$?
if [[ $PAY_RC -ne 0 ]]; then
    loge "Échec du transfert Duniter réel — AUCUN mint effectué (pas de Ğ1-N² créé sans contrepartie réelle)"
    exit 1
fi
logok "Transfert Duniter confirmé : ${TRANSFERABLE} Ğ1 → coffre"

################################################################################
# 3. Mint 30852 créditant le membre du même montant sur Ğ1-N².
################################################################################
log "Mint Ğ1-N² : ${TRANSFERABLE} → ${EMAIL} (${MEMBER_HEX:0:12}...)"
MINT_EVENT_ID=$("${MY_PATH}/g1n2_pay.sh" "$MINT_KEYFILE" "$TRANSFERABLE" "$MEMBER_HEX" "N2_BRIDGE:${EMAIL}" "" --mint)
if [[ -z "$MINT_EVENT_ID" ]]; then
    loge "ÉCHEC du mint Ğ1-N² après transfert Duniter réussi — Ğ1 transféré au coffre mais PAS crédité sur N² : intervention manuelle requise pour ${EMAIL} (montant: ${TRANSFERABLE})"
    exit 1
fi
logok "Mint Ğ1-N² confirmé : event ${MINT_EVENT_ID:0:16}..."

# Marqueur permanent — posé UNIQUEMENT après un mint réellement confirmé.
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) bridged=${TRANSFERABLE} event=${MINT_EVENT_ID}" > "$BRIDGE_MARKER"

################################################################################
# 4. Propagation "toile de confiance" — périmètre : membres locaux connus +
#    amisOfAmis.txt (PAS la Toile de Confiance Duniter, aucune commande de
#    listing n'existe pour celle-ci — cf. KIND_REGISTRY.md kind 30852).
################################################################################
now=$(date +%s)
last_run=0
[[ -s "$COURTESY_RUN_MARKER" ]] && last_run=$(cat "$COURTESY_RUN_MARKER" 2>/dev/null || echo 0)
if [[ $((now - last_run)) -lt $COURTESY_MIN_INTERVAL_SEC ]]; then
    log "Vague de courtoisie ignorée — dernière vague il y a $((now - last_run))s (< ${COURTESY_MIN_INTERVAL_SEC}s)"
    exit 0
fi

declare -A CONTACTS=()
for dir in "$HOME/.zen/game/nostr"/*/; do
    [[ -s "${dir}HEX" ]] || continue
    h=$(cat "${dir}HEX" 2>/dev/null)
    [[ -n "$h" && "$h" != "$MEMBER_HEX" ]] && CONTACTS["$h"]=1
done
AMISOFAMIS_FILE="$HOME/.zen/strfry/amisOfAmis.txt"
if [[ -s "$AMISOFAMIS_FILE" ]]; then
    while IFS= read -r h; do
        [[ -n "$h" && "$h" != "$MEMBER_HEX" && ! "$h" =~ ^# ]] && CONTACTS["$h"]=1
    done < "$AMISOFAMIS_FILE"
fi

log "Contacts candidats pour courtoisie : ${#CONTACTS[@]} (plafond : ${MAX_COURTESY_PER_RUN}/run)"

# Follows courants du membre bridgé (pour fusion, jamais écrasement)
current_follows_json=$("${MY_PATH}/nostr_get_events.sh" -k 3 -a "$MEMBER_HEX" -l 1 -o json 2>/dev/null)
declare -A EXISTING_FOLLOWS=()
if [[ -n "$current_follows_json" ]]; then
    while IFS= read -r p; do
        [[ -n "$p" ]] && EXISTING_FOLLOWS["$p"]=1
    done < <(echo "$current_follows_json" | jq -r '.[0].tags[]? | select(.[0]=="p") | .[1]' 2>/dev/null)
fi

sent=0
for contact_hex in "${!CONTACTS[@]}"; do
    [[ $sent -ge $MAX_COURTESY_PER_RUN ]] && { log "Plafond de courtoisie atteint (${MAX_COURTESY_PER_RUN}) — reste pour un prochain run"; break; }

    courtesy_marker="$HOME/.zen/tmp/n2_bridge_courtesy_${contact_hex}.done"
    [[ -f "$courtesy_marker" ]] && continue

    log "Courtoisie → ${contact_hex:0:12}... : ${COURTESY_AMOUNT} Ğ1-N² + follow"
    courtesy_event_id=$("${MY_PATH}/g1n2_pay.sh" "$MINT_KEYFILE" "$COURTESY_AMOUNT" "$contact_hex" "N2_BRIDGE:courtesy:${EMAIL}" "" --mint)
    if [[ -z "$courtesy_event_id" ]]; then
        logw "Échec mint courtoisie pour ${contact_hex:0:12}... — pas de marqueur posé, retentable"
        continue
    fi

    touch "$courtesy_marker"
    sent=$((sent + 1))
    EXISTING_FOLLOWS["$contact_hex"]=1
done

# Republication du kind 3 du membre bridgé, fusionné (jamais écrasé) —
# uniquement si au moins un nouveau contact a été ajouté cette vague.
if [[ $sent -gt 0 ]]; then
    p_tags_json=$(printf '%s\n' "${!EXISTING_FOLLOWS[@]}" | jq -R . | jq -sc '[.[] | ["p", .]]')
    "${MY_PATH}/nostr_send_note.py" --json --keyfile "$MEMBER_NOSTR_KEYFILE" \
        --kind 3 --content "" --tags "$p_tags_json" --relays "${myRELAY:-ws://127.0.0.1:7777}" >/dev/null 2>&1 \
        && logok "Kind 3 (follows) mis à jour pour ${EMAIL} : +${sent} contact(s)" \
        || logw "Échec republication kind 3 pour ${EMAIL} — courtoisies mint déjà envoyées, follow à refaire manuellement"
fi

echo "$now" > "$COURTESY_RUN_MARKER"
logok "=== N2_Bridge terminé pour $EMAIL — ${sent} courtoisie(s) envoyée(s) ==="
exit 0
