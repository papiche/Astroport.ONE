#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1 — Ğ1-Nostr (N²), dual-stack de G1check.sh
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ g1n2_check.sh
#~ Retourne le solde Ğ1-Nostr (N²) d'un compte, lu depuis le cache maintenu par
#~ NIP-101/relay.writePolicy.plugin/filter/30852.sh (writePolicy strfry) — ne
#~ recalcule JAMAIS indépendamment : le filtre est la seule autorité de
#~ validation (anti-double-dépense, chaînage prev), toute réimplémentation
#~ séparée du calcul de solde risquerait de diverger silencieusement de ce que
#~ le relay a réellement validé.
#
# Usage (interface volontairement identique à G1check.sh, dual-stack via
# G1_MODE=NOSTR — voir le dispatch en tête de G1check.sh) :
#   g1n2_check.sh <HEX_ou_G1PUB>[:ZEN] [--fresh]
#   g1n2_check.sh <PUB1> <PUB2> ...    → mode batch séquentiel (lecture cache
#                                        locale, pas de fetch réseau : le
#                                        parallélisme de G1check.sh n'apporte
#                                        rien ici)
#
# --fresh : force un recalcul complet (n2_ledger_rescan_author, un seul scan
# strfry combiné émis+reçus) plutôt que de lire le cache — jamais un scan
# maison redondant avec celui du filtre.
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

log() { echo "[g1n2_check] $*" >&2; }

N2_LEDGER_LIB="$HOME/.zen/workspace/NIP-101/relay.writePolicy.plugin/filter/n2_ledger_lib.sh"
if [[ ! -s "$N2_LEDGER_LIB" ]]; then
    log "ERREUR: n2_ledger_lib.sh introuvable ($N2_LEDGER_LIB) — NIP-101 installé ?"
    exit 1
fi
source "$N2_LEDGER_LIB"

# ── Extraction du flag --fresh AVANT le dispatch batch (même pattern que
# G1check.sh — voir son commentaire pour le bug évité) ───────────────────────
FORCE_FRESH="false"
_ARGS=()
for _a in "$@"; do
    if [[ "$_a" == "--fresh" ]]; then
        FORCE_FRESH="true"
    else
        _ARGS+=("$_a")
    fi
done
set -- "${_ARGS[@]}"
unset _a _ARGS

# ── Mode batch : plusieurs comptes en arguments ───────────────────────────────
if [[ $# -gt 1 ]]; then
    SELF="$0"
    for _arg in "$@"; do
        if [[ "$FORCE_FRESH" == "true" ]]; then
            "$SELF" "$_arg" --fresh
        else
            "$SELF" "$_arg"
        fi
    done
    exit 0
fi

PUBKEY_ORIGINAL="${1:-}"
[[ -z "$PUBKEY_ORIGINAL" ]] && { log "USAGE: g1n2_check.sh <HEX_ou_G1PUB>[:ZEN] [--fresh]"; exit 1; }

IS_ZEN="false"
PUBKEY="$PUBKEY_ORIGINAL"
if [[ "$PUBKEY_ORIGINAL" == *":ZEN" ]]; then
    IS_ZEN="true"
    PUBKEY="${PUBKEY_ORIGINAL%:ZEN}"
fi

# ── Résolution en HEX NOSTR ────────────────────────────────────────────────────
# Déjà un HEX (64 hex chars) : utilisé tel quel. Sinon, c'est un G1PUB (format
# historique des appelants existants) : résolu via le dossier MULTIPASS local
# dont le .secret.dunikey correspond (même source que
# PAYforSURE.sh::find_player_email(), comparaison directe sur le champ "pub:"
# puisqu'on part ici du G1PUB source, pas d'une adresse SS58 destination).
HEX=""
if [[ "$PUBKEY" =~ ^[0-9a-f]{64}$ ]]; then
    HEX="$PUBKEY"
else
    for dir in "$HOME/.zen/game/nostr"/*/; do
        [[ -s "${dir}.secret.dunikey" ]] || continue
        pub_v1=$(grep -E '^pub:' "${dir}.secret.dunikey" 2>/dev/null | head -1 | awk '{print $2}')
        [[ -n "$pub_v1" && "$pub_v1" == "$PUBKEY" ]] || continue
        [[ -s "${dir}HEX" ]] && HEX=$(cat "${dir}HEX" 2>/dev/null)
        break
    done
fi

if [[ -z "$HEX" ]]; then
    log "ERREUR: impossible de résoudre '$PUBKEY' en HEX NOSTR (ni hex64, ni G1PUB MULTIPASS local connu)"
    echo ""
    exit 1
fi

state=$(n2_ledger_get_balance "$HEX" "$FORCE_FRESH")
IFS='|' read -r balance _last_tx <<< "$state"
[[ -z "$balance" ]] && balance="0"

# ── Sortie ─────────────────────────────────────────────────────────────────
# Ẑen = translation d'affichage (solde-1)*10, IDENTIQUE à G1check.sh — le même
# "-1" s'applique au solde Ğ1-N² (pas seulement à Duniter) : la conversion Ẑen
# est une règle d'affichage globale de la coopérative, pas une propriété propre
# à l'existential deposit Duniter. Négatif (compte tout juste bridgé/minté sous
# le seuil) écrêté à 0, même convention que finance.py::get_g1_balances_batch.
if [[ "$IS_ZEN" == "true" ]]; then
    zen=$(echo "scale=1; ($balance - 1) * 10" | bc)
    (( $(echo "$zen < 0" | bc -l) )) && zen="0.0"
    echo "$zen"
else
    echo "$balance"
fi
