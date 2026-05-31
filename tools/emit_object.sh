#!/usr/bin/env bash
# emit_object.sh — Publie un Kind 30505 NOSTR (objet/ressource physique ou logique)
#
# Usage: emit_object.sh TITLE TYPE [OPTIONS]
#
# Arguments positionnels :
#   TITLE        Nom de l'objet (ex: "Cabane-33", "RPi Zero 2W")
#   TYPE         object | place | tool | material | document | service | skill_resource
#
# Options (variables d'environnement ou flags) :
#   QUANTITY_TYPE  discrete | capacity | durability | infinite  (défaut: discrete)
#   QUANTITY       Entier ≥ 0  (défaut: 1)
#   UNIT           Unité libre (pièce, litre, m², …)  (défaut: "pièce")
#   MOBILITY       fixed | portable | wearable  (défaut: fixed)
#   REPAIRABILITY  0–10  (défaut: 5)
#   MIN_OPERATORS  Entier ≥ 1 (défaut: 1)
#   PHOTO_CID      CID IPFS d'une photo (optionnel)
#   GEO            "LAT,LON" arrondi REGION 1° (optionnel)
#   DESCRIPTION    Texte libre (optionnel)
#   DURABILITY     0–100 (état initial, défaut: 100)
#   CONDITION      new | good | fair | poor | broken  (défaut: new)
#
# Exemples :
#   emit_object.sh "Cabane-33" place \
#     QUANTITY_TYPE=capacity QUANTITY=8 UNIT="places" \
#     MOBILITY=fixed REPAIRABILITY=9 MIN_OPERATORS=2 \
#     GEO="44,0" DESCRIPTION="Cabane en bois, 8 couchages"
#
#   emit_object.sh "RPi Zero 2W" object \
#     QUANTITY_TYPE=durability QUANTITY=1 UNIT="pièce" \
#     MOBILITY=portable REPAIRABILITY=7 \
#     DESCRIPTION="Raspberry Pi Zero 2W pour sound-spot"
#
#   emit_object.sh "Câble Ethernet 5m" material \
#     QUANTITY_TYPE=discrete QUANTITY=3 UNIT="pièce" \
#     MOBILITY=portable REPAIRABILITY=3
#
# Retourne l'event_id sur la dernière ligne de stdout.
# Author: Fred (support@qo-op.com) — AGPL-3.0

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "${MY_PATH}" && pwd)"

. "${MY_PATH}/my.sh"

########################################################################
## Arguments positionnels
########################################################################
_TITLE="${1:-}"
_TYPE="${2:-object}"

if [[ -z "$_TITLE" ]]; then
    echo "Usage: emit_object.sh TITLE [TYPE] [QUANTITY_TYPE=...] [QUANTITY=...] ..." >&2
    echo "Types: object | place | tool | material | document | service | skill_resource" >&2
    exit 1
fi

########################################################################
## Options (variables d'environnement ou flags KEY=VALUE)
########################################################################
# Lire les paires KEY=VALUE depuis les arguments restants
shift 2
for _arg in "$@"; do
    case "$_arg" in
        QUANTITY_TYPE=*)  QUANTITY_TYPE="${_arg#*=}"  ;;
        QUANTITY=*)       QUANTITY="${_arg#*=}"       ;;
        UNIT=*)           UNIT="${_arg#*=}"           ;;
        MOBILITY=*)       MOBILITY="${_arg#*=}"       ;;
        REPAIRABILITY=*)  REPAIRABILITY="${_arg#*=}"  ;;
        MIN_OPERATORS=*)  MIN_OPERATORS="${_arg#*=}"  ;;
        PHOTO_CID=*)      PHOTO_CID="${_arg#*=}"      ;;
        GEO=*)            GEO="${_arg#*=}"            ;;
        DESCRIPTION=*)    DESCRIPTION="${_arg#*=}"    ;;
        DURABILITY=*)     DURABILITY="${_arg#*=}"     ;;
        CONDITION=*)      CONDITION="${_arg#*=}"      ;;
    esac
done

QUANTITY_TYPE="${QUANTITY_TYPE:-discrete}"
QUANTITY="${QUANTITY:-1}"
UNIT="${UNIT:-pièce}"
MOBILITY="${MOBILITY:-fixed}"
REPAIRABILITY="${REPAIRABILITY:-5}"
MIN_OPERATORS="${MIN_OPERATORS:-1}"
PHOTO_CID="${PHOTO_CID:-}"
GEO="${GEO:-}"
DESCRIPTION="${DESCRIPTION:-}"
DURABILITY="${DURABILITY:-100}"
CONDITION="${CONDITION:-new}"

########################################################################
## Validation des valeurs
########################################################################
case "$_TYPE" in
    object|place|tool|material|document|service|skill_resource) ;;
    *) echo "ERROR: TYPE invalide '$_TYPE'. Types: object|place|tool|material|document|service|skill_resource" >&2; exit 1 ;;
esac

case "$QUANTITY_TYPE" in
    discrete|capacity|durability|infinite) ;;
    *) echo "ERROR: QUANTITY_TYPE invalide '$QUANTITY_TYPE'. Valeurs: discrete|capacity|durability|infinite" >&2; exit 1 ;;
esac

case "$MOBILITY" in
    fixed|portable|wearable) ;;
    *) echo "ERROR: MOBILITY invalide '$MOBILITY'. Valeurs: fixed|portable|wearable" >&2; exit 1 ;;
esac

if ! [[ "$REPAIRABILITY" =~ ^[0-9]+$ ]] || (( REPAIRABILITY < 0 || REPAIRABILITY > 10 )); then
    echo "ERROR: REPAIRABILITY doit être entre 0 et 10" >&2; exit 1
fi

if ! [[ "$DURABILITY" =~ ^[0-9]+$ ]] || (( DURABILITY < 0 || DURABILITY > 100 )); then
    echo "ERROR: DURABILITY doit être entre 0 et 100" >&2; exit 1
fi

########################################################################
## Normalisation du titre → d-tag (slug)
########################################################################
_DTAG=$(echo "$_TITLE" | tr '[:upper:]' '[:lower:]' \
    | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null || echo "$_TITLE" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
_DTAG="${_DTAG:-objet}-$(date +%s)"

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
_TITLE_ESC=$(echo "$_TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
_UNIT_ESC=$(echo "$UNIT" | sed 's/\\/\\\\/g; s/"/\\"/g')

_TAGS='['
_TAGS="${_TAGS}[\"d\",\"${_DTAG}\"]"
_TAGS="${_TAGS},[\"title\",\"${_TITLE_ESC}\"]"
_TAGS="${_TAGS},[\"t\",\"${_TYPE}\"]"
_TAGS="${_TAGS},[\"t\",\"${MOBILITY}\"]"
_TAGS="${_TAGS},[\"t\",\"${QUANTITY_TYPE}\"]"
_TAGS="${_TAGS},[\"quantity\",\"${QUANTITY}\"]"
_TAGS="${_TAGS},[\"quantity_unit\",\"${_UNIT_ESC}\"]"
_TAGS="${_TAGS},[\"durability\",\"${DURABILITY}\"]"
_TAGS="${_TAGS},[\"repairability\",\"${REPAIRABILITY}\"]"

if (( MIN_OPERATORS > 1 )); then
    _TAGS="${_TAGS},[\"min_operators\",\"${MIN_OPERATORS}\"]"
fi

if [[ -n "$GEO" ]]; then
    _TAGS="${_TAGS},[\"geo\",\"${GEO}\"]"
fi

if [[ -n "$PHOTO_CID" ]]; then
    _TAGS="${_TAGS},[\"r\",\"ipfs://${PHOTO_CID}\",\"photo\"]"
fi

_TAGS="${_TAGS}]"

########################################################################
## Content JSON
########################################################################
_CREATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
_DESC_ESC=$(echo "$DESCRIPTION" | sed 's/\\/\\\\/g; s/"/\\"/g')

_CONTENT='{'
_CONTENT="${_CONTENT}\"title\":\"${_TITLE_ESC}\""
_CONTENT="${_CONTENT},\"type\":\"${_TYPE}\""
_CONTENT="${_CONTENT},\"quantity_type\":\"${QUANTITY_TYPE}\""
_CONTENT="${_CONTENT},\"quantity\":${QUANTITY}"
_CONTENT="${_CONTENT},\"quantity_unit\":\"${_UNIT_ESC}\""
_CONTENT="${_CONTENT},\"mobility\":\"${MOBILITY}\""
_CONTENT="${_CONTENT},\"repairability\":${REPAIRABILITY}"
_CONTENT="${_CONTENT},\"min_operators\":${MIN_OPERATORS}"
_CONTENT="${_CONTENT},\"durability\":${DURABILITY}"
_CONTENT="${_CONTENT},\"condition\":\"${CONDITION}\""

if [[ -n "$_DESC_ESC" ]]; then
    _CONTENT="${_CONTENT},\"description\":\"${_DESC_ESC}\""
fi

if [[ -n "$GEO" ]]; then
    _CONTENT="${_CONTENT},\"geo\":\"${GEO}\""
fi

if [[ -n "$PHOTO_CID" ]]; then
    _CONTENT="${_CONTENT},\"photo_cid\":\"${PHOTO_CID}\""
fi

_CONTENT="${_CONTENT},\"created_at\":\"${_CREATED_AT}\""
_CONTENT="${_CONTENT}}"

########################################################################
## Relay cible
########################################################################
_RELAY="${NOSTR_RELAY_WS:-ws://127.0.0.1:7777}"

########################################################################
## Publication via nostr_node_intercom.py
########################################################################
_EVENT_ID=$(python3 "${MY_PATH}/nostr_node_intercom.py" publish \
    --nsec "$_NSEC" \
    --kind 30505 \
    --content "$_CONTENT" \
    --tags "$_TAGS" \
    --relays "$_RELAY" 2>/dev/null)

if [[ -z "$_EVENT_ID" ]]; then
    echo "ERROR: publication Kind 30505 échouée pour ${_DTAG}" >&2
    exit 1
fi

echo "✅ ${_TITLE} [${_TYPE}/${QUANTITY_TYPE}] → d-tag=${_DTAG} event_id=${_EVENT_ID}"
echo "$_EVENT_ID"
