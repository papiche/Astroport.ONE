#!/bin/bash
########################################################################
# N1Mediation.sh — Publie un Kind 30506 (dossier de médiation WoTx²)
# Déclenché par NIP-101/filter/1984.sh quand report-type=friction
#
# Usage: N1Mediation.sh <pending_case.json>
#
# Le JSON d'entrée est écrit par 1984.sh dans ~/.zen/tmp/justice_pending/
# Une fois traité, le fichier est déplacé vers ~/.zen/tmp/justice_processed/
#
# Author: Fred (support@qo-op.com) — AGPL-3.0
########################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "${MY_PATH}" && pwd)"
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

########################################################################
## Argument
########################################################################
PENDING_JSON="$1"

if [[ -z "$PENDING_JSON" || ! -s "$PENDING_JSON" ]]; then
    echo "Usage: $ME <pending_case.json>" >&2
    exit 1
fi

########################################################################
## Lire le dossier en attente
########################################################################
case_id=$(jq -r '.case_id // empty'        "$PENDING_JSON")
plaignant=$(jq -r '.plaignant // empty'     "$PENDING_JSON")
défendeur=$(jq -r '."défendeur" // empty'   "$PENDING_JSON")
amount_zen=$(jq -r '.amount_zen // 0'       "$PENDING_JSON")
object_dtag=$(jq -r '.object_dtag // empty' "$PENDING_JSON")
reason=$(jq -r '.reason // empty'          "$PENDING_JSON")
origin_eid=$(jq -r '.origin_event_id // empty' "$PENDING_JSON")
case_level=$(jq -r '.level // "N1"'        "$PENDING_JSON")
created_at=$(jq -r '.created_at // empty'  "$PENDING_JSON")

if [[ -z "$case_id" || -z "$plaignant" || -z "$défendeur" ]]; then
    echo "ERROR: JSON malformé ou champs manquants dans $PENDING_JSON" >&2
    exit 1
fi

########################################################################
## Récupérer le NSEC du capitaine (oracle signataire)
########################################################################
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

########################################################################
## Construire le contenu Kind 30506
########################################################################
status_val="${case_level}_ouvert"
title_esc=$(echo "Friction: $reason" | cut -c1-120 | sed 's/\\/\\\\/g; s/"/\\"/g')
reason_esc=$(echo "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
created_at="${created_at:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

_CONTENT=$(cat <<JSON
{"title":"${title_esc}","status":"${status_val}","level":"${case_level}","description":"${reason_esc}","resolution":null,"reparation_zen":${amount_zen},"created_at":"${created_at}"}
JSON
)

########################################################################
## Construire les tags Kind 30506 (NIP-33)
########################################################################
_TAGS='[
  ["d","'"$case_id"'"],
  ["t","friction"],
  ["status","'"$status_val"'"],
  ["p","'"$plaignant"'","role:plaignant"],
  ["p","'"$défendeur"'","role:défendeur"]'

[[ -n "$origin_eid" ]]  && _TAGS="${_TAGS}"$',\n  ["e","'"$origin_eid"'"]'
[[ -n "$object_dtag" ]] && _TAGS="${_TAGS}"$',\n  ["object","'"$object_dtag"'"]'

_TAGS="${_TAGS}"$'\n]'

########################################################################
## Publier Kind 30506 via nostr_node_intercom.py
########################################################################
_RELAY="${NOSTR_RELAY_WS:-ws://127.0.0.1:7777}"
_TOOLS="${MY_PATH}/../tools"

echo "$ME: publication Kind 30506 pour $case_id (level=$case_level, montant=${amount_zen}Ẑ)"

_EVENT_ID=$(python3 "${_TOOLS}/nostr_node_intercom.py" publish \
    --nsec "$_NSEC" \
    --kind 30506 \
    --content "$_CONTENT" \
    --tags "$_TAGS" \
    --relays "$_RELAY" 2>/dev/null)

if [[ -z "$_EVENT_ID" ]]; then
    echo "ERROR: publication Kind 30506 échouée pour $case_id" >&2
    exit 1
fi

echo "$ME: ✅ Kind 30506 publié — event_id=${_EVENT_ID}"

########################################################################
## Déplacer le dossier vers processed
########################################################################
processed_dir="$HOME/.zen/tmp/justice_processed"
mkdir -p "$processed_dir"
mv "$PENDING_JSON" "${processed_dir}/${case_id}.json"
# Annoter l'event_id dans le fichier archivé
jq --arg eid "$_EVENT_ID" '. + {"kind30506_event_id":$eid}' \
    "${processed_dir}/${case_id}.json" > "${processed_dir}/${case_id}.tmp" \
    && mv "${processed_dir}/${case_id}.tmp" "${processed_dir}/${case_id}.json"

echo "$ME: dossier archivé → ${processed_dir}/${case_id}.json"
