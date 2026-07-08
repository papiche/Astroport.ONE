#!/bin/bash
################################################################################
# atom4love_activate.sh — Stocke le profil de naissance/conception ATOM4LOVE
# d'un MULTIPASS EXISTANT (fichiers chiffrés avec G1PUBNOSTR) puis délègue à
# atom4love_publish.py : dérivation de la clé NOSTR dédiée LOVE (.secret.love,
# déterministe depuis les données de naissance), calcul de la résonance Phi²,
# publication de l'event kind 30078 (d=atom4love).
#
# Réutilisé par :
#   - make_NOSTRCARD.sh   (naissance fournie dès la création du MULTIPASS)
#   - UPassport/routers/identity.py (complétion via l'email +a4l d'un compte
#     déjà existant — ne crée jamais de second MULTIPASS)
#
# Usage: atom4love_activate.sh EMAIL BIRTH_DATETIME BIRTH_PLACE BIRTH_LAT BIRTH_LON \
#                               BIRTH_WEIGHT CONCEPTION_DATETIME CONCEPTION_PLACE [POLARITY]
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/my.sh"

EMAIL="$1"
BIRTH_DATETIME="$2"
BIRTH_PLACE="$3"
BIRTH_LAT="$4"
BIRTH_LON="$5"
BIRTH_WEIGHT="$6"
CONCEPTION_DATETIME="$7"
CONCEPTION_PLACE="$8"
POLARITY="${9:-0}"

if [[ -z "${EMAIL}" ]]; then
    echo "Usage: atom4love_activate.sh EMAIL BIRTH_DATETIME BIRTH_PLACE BIRTH_LAT BIRTH_LON BIRTH_WEIGHT CONCEPTION_DATETIME CONCEPTION_PLACE [POLARITY]" >&2
    echo '{"activated":false,"error":"MISSING_EMAIL"}'
    exit 1
fi

_NOSTR_DIR="${HOME}/.zen/game/nostr/${EMAIL}"
_SECRET="${_NOSTR_DIR}/.secret.nostr"
_G1PUB_FILE="${_NOSTR_DIR}/G1PUBNOSTR"

if [[ ! -s "$_SECRET" || ! -s "$_G1PUB_FILE" ]]; then
    echo "❌ No existing MULTIPASS for ${EMAIL} — cannot activate ATOM4LOVE" >&2
    echo '{"activated":false,"error":"PRIMARY_ACCOUNT_NOT_FOUND"}'
    exit 1
fi
G1PUBNOSTR=$(cat "$_G1PUB_FILE")

## Données de naissance/conception
# .BIRTHDATE (YYYY-MM-DD) : clair — utilisé par kin.sh et did_manager_nostr.sh
# .birth_datetime.enc, .birth_weight.enc, .conception_datetime.enc : chiffrés
# avec la clé publique G1PUBNOSTR du joueur → seul le joueur peut déchiffrer.
if [[ -n "${BIRTH_DATETIME}" ]]; then
    _birth_date="${BIRTH_DATETIME%%T*}"
    [[ "${_birth_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
        && echo "${_birth_date}" > "${_NOSTR_DIR}/.BIRTHDATE"
    echo "${BIRTH_DATETIME}" \
        | ${MY_PATH}/natools.py encrypt -p "$G1PUBNOSTR" \
            -o "${_NOSTR_DIR}/.birth_datetime.enc" >/dev/null \
        && rm -f "${_NOSTR_DIR}/.birth_datetime"
    unset _birth_date
fi
[[ -n "${BIRTH_PLACE}" ]] && echo "${BIRTH_PLACE}" > "${_NOSTR_DIR}/.birth_place"
[[ -n "${BIRTH_LAT}" && -n "${BIRTH_LON}" ]] \
    && echo "LAT=${BIRTH_LAT}; LON=${BIRTH_LON};" > "${_NOSTR_DIR}/.birth_gps"
if [[ -n "${BIRTH_WEIGHT}" ]]; then
    echo "${BIRTH_WEIGHT}" \
        | ${MY_PATH}/natools.py encrypt -p "$G1PUBNOSTR" \
            -o "${_NOSTR_DIR}/.birth_weight.enc" >/dev/null \
        && rm -f "${_NOSTR_DIR}/.birth_weight"
fi
if [[ -n "${CONCEPTION_DATETIME}" ]]; then
    echo "${CONCEPTION_DATETIME}" \
        | ${MY_PATH}/natools.py encrypt -p "$G1PUBNOSTR" \
            -o "${_NOSTR_DIR}/.conception_datetime.enc" >/dev/null \
        && rm -f "${_NOSTR_DIR}/.conception_datetime"
fi
[[ -n "${CONCEPTION_PLACE}" ]] && echo "${CONCEPTION_PLACE}" > "${_NOSTR_DIR}/.conception_place"

## Dérivation clé LOVE + résonance Phi² + publication kind 30078 — seule sortie
## stdout attendue par les appelants (dernière ligne = JSON du résultat).
if [[ -n "${BIRTH_DATETIME}" && -n "${BIRTH_LAT}" && -n "${BIRTH_LON}" ]]; then
    python3 "${MY_PATH}/atom4love_publish.py" "${EMAIL}" "${BIRTH_DATETIME}" \
        "${BIRTH_LAT}" "${BIRTH_LON}" "${BIRTH_WEIGHT:-3.5}" "${POLARITY:-0}" \
        "${CONCEPTION_DATETIME}"
else
    echo "⚠️  Missing birth_lat/birth_lon — skipping ATOM4LOVE key derivation/publish" >&2
    echo "{\"activated\":false,\"email\":\"${EMAIL}\",\"error\":\"MISSING_BIRTH_COORDINATES\"}"
fi
