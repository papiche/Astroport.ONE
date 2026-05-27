#!/usr/bin/env bash
# emit_skill.sh — Publie un Kind 30503 NOSTR auto-attesté (folksonomy de compétence)
#
# Usage: emit_skill.sh SKILL [LEVEL] [EVIDENCE_CID]
# Exemples:
#   emit_skill.sh bash 1 QmXxx...
#   emit_skill.sh docker 1
#   emit_skill.sh astroport-install 1 QmYyy...
# Niveaux : x1 = folksonomy auto-proclamé. x2+ = cérémonie ou 3 likes.
#
# Retourne le event ID sur la dernière ligne de stdout.
# Author: Fred (support@qo-op.com) — AGPL-3.0

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "${MY_PATH}" && pwd)"

. "${MY_PATH}/my.sh"

########################################################################
## Arguments
########################################################################
_SKILL_RAW="${1:-}"
_LEVEL="${2:-1}"
_CID="${3:-}"

if [[ -z "$_SKILL_RAW" ]]; then
    echo "Usage: emit_skill.sh SKILL [LEVEL] [EVIDENCE_CID]" >&2
    echo "Exemple: emit_skill.sh bash 1 QmXxx..." >&2
    exit 1
fi

########################################################################
## Normalisation du skill
## "Astroport Install" → astroport-install → PERMIT_ASTROPORT_INSTALL_X1
########################################################################
_SKILL_NORM=$(echo "$_SKILL_RAW" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
_PERMIT_KEY="PERMIT_$(echo "$_SKILL_NORM" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_X${_LEVEL}"

########################################################################
## Récupération du NSEC
########################################################################
if [[ -n "${_NSEC_OVERRIDE:-}" ]]; then
    _NSEC="$_NSEC_OVERRIDE"
else
    _SECRET_FILE="$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    if [[ ! -s "$_SECRET_FILE" ]]; then
        echo "ERROR: fichier secret introuvable : $_SECRET_FILE" >&2
        exit 1
    fi
    _NSEC=$(grep -oP 'NSEC=\K[^;]+' "$_SECRET_FILE" 2>/dev/null | head -1 | tr -d ' ')
    if [[ -z "$_NSEC" ]]; then
        echo "ERROR: NSEC introuvable dans $_SECRET_FILE" >&2
        exit 1
    fi
fi

########################################################################
## Construction des tags JSON
########################################################################
_ATTESTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

_TAGS='[["d","'"$_PERMIT_KEY"'"],["l","'"$_PERMIT_KEY"'","permit_type"],["level","'"$_LEVEL"'"],["t","'"$_SKILL_NORM"'"],["t","auto_proclaimed"]]'

if [[ -n "$_CID" ]]; then
    # Injecter les tags evidence avant le ] final
    _TAGS="${_TAGS%]}"
    _TAGS="${_TAGS}"',["e","'"$_CID"'","","evidence"],["r","ipfs://'"$_CID"'"]]'
fi

########################################################################
## Content JSON
########################################################################
_CONTENT='{"skill":"'"$_SKILL_NORM"'","level":'"$_LEVEL"',"attested_at":"'"$_ATTESTED_AT"'","auto_proclaimed":true}'

########################################################################
## Relay cible
########################################################################
_RELAY="${NOSTR_RELAY_WS:-ws://127.0.0.1:7777}"

########################################################################
## Publication via nostr_node_intercom.py
########################################################################
_EVENT_ID=$(python3 "${MY_PATH}/nostr_node_intercom.py" publish \
    --nsec "$_NSEC" \
    --kind 30503 \
    --content "$_CONTENT" \
    --tags "$_TAGS" \
    --relays "$_RELAY" 2>/dev/null)

if [[ -z "$_EVENT_ID" ]]; then
    echo "ERROR: publication Kind 30503 échouée pour $_PERMIT_KEY" >&2
    exit 1
fi

echo "✅ $_PERMIT_KEY → event_id=${_EVENT_ID}"
echo "$_EVENT_ID"
