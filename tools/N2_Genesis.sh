#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1 — Ğ1-Nostr (N²), genèse du DU hyper-relativiste
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ N2_Genesis.sh
#~ Mint initial Ğ1-N² pour un humain venant d'inscrire sa naissance/conception
#~ (clé .secret.love/HEX_LOVE créée par atom4love_publish.py) : DU hyper-
#~ relativiste initialisé à 100.00 Ẑen = 11.00 Ğ1-N² (formule commune
#~ Ẑen=(solde-1)*10, cf. g1n2_check.sh — (11-1)*10 = 100).
#
# IMPORTANT — créditée sur HEX_LOVE, PAS sur le HEX du MULTIPASS : le
# MULTIPASS (G1PUBNOSTR + .secret.nostr) reste dédié à l'économie réelle
# (Ğ1/Duniter, raccordement OpenCollective, comptage des € versés au
# collectif) — jamais mêlé au ledger Ğ1-N², local et sans consensus. Toute
# l'économie Ğ1-N² (genesis ET DU quotidien, cf. N2_Economics.py) vit
# exclusivement sur l'identité NOSTR LOVE, distincte.
#
# Déclencheur : appelé par atom4love_activate.sh juste après succès de
# write_secret_love() — jamais indépendamment d'une inscription ATOM4LOVE
# réussie. Les portefeuilles coopératifs (UPLANETNAME_G1, uplanet.G1.nostr,
# CAPTAIN_DEDICATED) n'ont structurellement jamais de .secret.love (aucune
# naissance humaine associée) : ils ne peuvent donc jamais déclencher ce
# genesis — exclusion par construction, pas un test explicite à maintenir.
#
# Anti-Sybil : la clé LOVE est déterministe depuis les données de naissance/
# conception (PBKDF2, 600000 itérations, cf. atom4love_publish.py) — resaisir
# EXACTEMENT la même naissance sur un AUTRE MULTIPASS dérive le MÊME HEX_LOVE.
# Un registre local (n2_genesis_love_claimed.txt) garantit qu'un seul genesis
# est jamais accordé par HEX_LOVE, quel que soit le nombre de MULTIPASS créés
# avec cette naissance. Protection à l'échelle de CETTE STATION uniquement
# (comme tout le ledger Ğ1-N², jamais synchronisé entre stations).
#
# Usage: N2_Genesis.sh <EMAIL>
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

log() { echo "[N2_Genesis] $*" >&2; }

GENESIS_AMOUNT="11.00"   # → 100.00 Ẑen, cf. g1n2_check.sh: Ẑen=(solde-1)*10
MINT_KEYFILE="$HOME/.zen/game/uplanet.G1.nostr"
LOVE_REGISTRY="$HOME/.zen/strfry/n2_genesis_love_claimed.txt"

EMAIL="${1:-}"
[[ -z "$EMAIL" ]] && { log "Usage: N2_Genesis.sh <EMAIL>"; exit 1; }

_NOSTR_DIR="$HOME/.zen/game/nostr/${EMAIL}"
_HEX_LOVE_FILE="${_NOSTR_DIR}/HEX_LOVE"
_MARKER="${_NOSTR_DIR}/.n2_genesis_minted"

if [[ ! -s "$_HEX_LOVE_FILE" ]]; then
    log "${EMAIL} : pas de HEX_LOVE (ATOM4LOVE non activé) — genesis non applicable"
    exit 0
fi
if [[ ! -s "$MINT_KEYFILE" ]]; then
    log "ERREUR: clé mint introuvable ($MINT_KEYFILE) — station non initialisée ?"
    exit 1
fi

# Idempotence n°1 : ce MULTIPASS a-t-il déjà reçu SON genesis ?
if [[ -s "$_MARKER" ]]; then
    log "${EMAIL} : genesis déjà minté ($(cat "$_MARKER" 2>/dev/null)) — skip"
    exit 0
fi

HEX_LOVE=$(cat "$_HEX_LOVE_FILE")
if [[ ! "$HEX_LOVE" =~ ^[0-9a-f]{64}$ ]]; then
    log "ERREUR: HEX_LOVE invalide pour ${EMAIL} (${HEX_LOVE:0:20}...)"
    exit 1
fi

# Idempotence n°2 (anti-Sybil, cf. en-tête) : réservation atomique de HEX_LOVE
# dans le registre AVANT tout mint — le mint réseau lui-même reste hors verrou
# (jamais bloquer le writer strfry sur un round-trip, même philosophie que
# filter/30852.sh).
mkdir -p "$(dirname "$LOVE_REGISTRY")"
touch "$LOVE_REGISTRY"
(
    flock -w 5 9 || { log "ERREUR: verrou registre LOVE indisponible (timeout)"; exit 1; }
    if grep -q "^${HEX_LOVE}:" "$LOVE_REGISTRY" 2>/dev/null; then
        exit 3
    fi
    echo "${HEX_LOVE}:${EMAIL}:$(date -u +%s)" >> "$LOVE_REGISTRY"
) 9>"${LOVE_REGISTRY}.lock"
rc=$?
if [[ $rc -eq 3 ]]; then
    log "${EMAIL} : HEX_LOVE ${HEX_LOVE:0:12}... déjà crédité via un autre MULTIPASS (même naissance) — aucun second genesis"
    exit 0
elif [[ $rc -ne 0 ]]; then
    log "ERREUR verrouillage registre LOVE (rc=$rc)"
    exit 1
fi

log "${EMAIL} : mint genesis ${GENESIS_AMOUNT} Ğ1-N² (→ 100.00 Ẑen) vers HEX_LOVE ${HEX_LOVE:0:12}..."
EVENT_ID=$("${MY_PATH}/g1n2_pay.sh" "$MINT_KEYFILE" "$GENESIS_AMOUNT" "$HEX_LOVE" "N2_GENESIS:${EMAIL}" "" --mint)
rc=$?

if [[ $rc -ne 0 || -z "$EVENT_ID" ]]; then
    log "ÉCHEC mint genesis pour ${EMAIL} — retrait de l'entrée du registre LOVE pour permettre un nouvel essai"
    ( flock -w 5 9 && sed -i "\|^${HEX_LOVE}:|d" "$LOVE_REGISTRY" ) 9>"${LOVE_REGISTRY}.lock"
    exit 1
fi

date -u +"%Y-%m-%dT%H:%M:%SZ event=${EVENT_ID}" > "$_MARKER"
log "✅ Genesis Ğ1-N² minté pour ${EMAIL} : event=${EVENT_ID}"
echo "$EVENT_ID"
exit 0
