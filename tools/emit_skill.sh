#!/usr/bin/env bash
# emit_skill.sh — Publie un Kind 30503 NOSTR auto-attesté (folksonomy de compétence)
#
# Usage: emit_skill.sh SKILL [LEVEL] [EVIDENCE_CID] [ICON] [DESC]
# Exemples:
#   emit_skill.sh bash 1 QmXxx... 🔧 'Scripting bash et administration système'
#   emit_skill.sh docker 1 '' 🐳 'Orchestration de conteneurs'
#   emit_skill.sh astroport-install 1 QmYyy... ⚓ 'Station décentralisée installée'
# Niveaux : x1 = folksonomy auto-proclamé. x2+ = cérémonie ou 3 likes.
# ICON et DESC sont injectés dans le content JSON et le tag 'summary' (NIP-23).
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
_ICON="${4:-}"
_DESC="${5:-}"

if [[ -z "$_SKILL_RAW" ]]; then
    echo "Usage: emit_skill.sh SKILL [LEVEL] [EVIDENCE_CID] [ICON] [DESC]" >&2
    echo "Exemples:" >&2
    echo "  emit_skill.sh bash 1 QmXxx... 🔧 'Scripting bash et administration'" >&2
    echo "  emit_skill.sh docker 1 '' 🐳 'Orchestration de conteneurs'" >&2
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

# Expiration Tzolkin : x1=260j, x2=780j, x3=2600j (cycles mayas)
case "$_LEVEL" in
    1) _EXPIRE_DAYS=260 ;;
    2) _EXPIRE_DAYS=780 ;;
    3) _EXPIRE_DAYS=2600 ;;
    *) _EXPIRE_DAYS=$((260 * _LEVEL)) ;;
esac
_EXPIRE_TS=$(( $(date +%s) + _EXPIRE_DAYS * 86400 ))

_TAGS='[["d","'"$_PERMIT_KEY"'"],["l","'"$_PERMIT_KEY"'","permit_type"],["level","'"$_LEVEL"'"],["t","'"$_SKILL_NORM"'"],["t","auto_proclaimed"],["expiration","'"$_EXPIRE_TS"'"]]'

# Enrichissement optionnel : description (tag 'summary') et titre (tag 'title')
if [[ -n "$_DESC" ]]; then
    _DESC_ESC=$(echo "$_DESC" | sed 's/\\/\\\\/g; s/"/\\"/g')
    _TAGS="${_TAGS%]}"
    _TAGS="${_TAGS}"',["summary","'"$_DESC_ESC"'"]]'
fi

if [[ -n "$_CID" ]]; then
    _TAGS="${_TAGS%]}"
    _TAGS="${_TAGS}"',["e","'"$_CID"'","","evidence"],["r","ipfs://'"$_CID"'"]]'
fi

########################################################################
## Content JSON (enrichi avec icon + description si fournis)
########################################################################
_CONTENT='{"skill":"'"$_SKILL_NORM"'","level":'"$_LEVEL"

if [[ -n "$_ICON" ]]; then
    _ICON_ESC=$(echo "$_ICON" | sed 's/\\/\\\\/g; s/"/\\"/g')
    _CONTENT="${_CONTENT}"',"icon":"'"$_ICON_ESC"'"'
fi
if [[ -n "$_DESC" ]]; then
    _DESC_ESC=$(echo "$_DESC" | sed 's/\\/\\\\/g; s/"/\\"/g')
    _CONTENT="${_CONTENT}"',"description":"'"$_DESC_ESC"'"'
fi
_CONTENT="${_CONTENT}"',"attested_at":"'"$_ATTESTED_AT"'","auto_proclaimed":true}'

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
