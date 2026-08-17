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

## Dérivation clé LOVE + résonance Phi² + publication kind 30078 — exécutée
## EN PREMIER. Les données de naissance/conception ne sont persistées que si
## .secret.love a bien été créé (cf. write_secret_love dans atom4love_publish.py) :
## on évite ainsi tout .BIRTHDATE orphelin sans clé LOVE associée.
if [[ -n "${BIRTH_DATETIME}" && -n "${BIRTH_LAT}" && -n "${BIRTH_LON}" ]]; then
    # UPLANETNAME est une variable locale (jamais exportée par my.sh) — transmise
    # explicitement, même convention que atom4love_profile.sh (sinon uplanet_crypto
    # retombe sur son fallback ~/.ipfs/swarm.key, identique en pratique mais moins
    # explicite).
    _PY_RESULT=$(UPLANETNAME="${UPLANETNAME}" python3 "${MY_PATH}/atom4love_publish.py" "${EMAIL}" "${BIRTH_DATETIME}" \
        "${BIRTH_LAT}" "${BIRTH_LON}" "${BIRTH_WEIGHT:-3.5}" "${POLARITY:-0}" \
        "${CONCEPTION_DATETIME}")
    # NB: [[ -s .secret.love ]] ne suffit PAS comme signal de succès — le fichier
    # peut déjà exister d'une activation PRÉCÉDENTE alors que CET appel vient
    # d'être refusé (anti-écrasement, cf. atom4love_publish.py::LOVE_KEY_EXISTS_MISMATCH).
    # Seul le champ "activated" du JSON retourné fait foi.
    _PY_ACTIVATED=$(echo "${_PY_RESULT}" | tail -n1 | jq -r '.activated // false' 2>/dev/null)

    if [[ "${_PY_ACTIVATED}" == "true" ]]; then
        ## Clé LOVE créée/republiée avec succès — on peut persister les données de naissance/conception.
        # .BIRTHDATE (YYYY-MM-DD) : clair — utilisé par kin.sh et did_manager_nostr.sh
        # .birth_datetime.enc, .birth_weight.enc, .conception_datetime.enc : chiffrés
        # avec la clé publique G1PUBNOSTR du joueur → seul le joueur peut déchiffrer.
        _birth_date="${BIRTH_DATETIME%%T*}"
        [[ "${_birth_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
            && echo "${_birth_date}" > "${_NOSTR_DIR}/.BIRTHDATE"
        echo "${BIRTH_DATETIME}" \
            | ${MY_PATH}/natools.py encrypt -p "$G1PUBNOSTR" \
                -o "${_NOSTR_DIR}/.birth_datetime.enc" >/dev/null \
            && rm -f "${_NOSTR_DIR}/.birth_datetime"
        unset _birth_date

        [[ -n "${BIRTH_PLACE}" ]] && echo "${BIRTH_PLACE}" > "${_NOSTR_DIR}/.birth_place"
        echo "LAT=${BIRTH_LAT}; LON=${BIRTH_LON};" > "${_NOSTR_DIR}/.birth_gps"
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

        # Inscrire la Singularité ATOM4LOVE dans le Kind 30800 (DID) de l'utilisateur
        # La mise à jour recalcule aussi le badge MayaKin depuis .BIRTHDATE
        "${MY_PATH}/did_manager_nostr.sh" update "${EMAIL}" ATOM4LOVE >&2 || \
            echo "[atom4love_activate] did_manager_nostr.sh update KO (non-bloquant)" >&2

        # Genesis Ğ1-N² (DU hyper-relativiste initial, 100 Ẑen / 11 Ğ1-N²) —
        # réservé aux humains ayant inscrit naissance/conception ; idempotent
        # par MULTIPASS et par identité LOVE (anti-Sybil, cf. N2_Genesis.sh).
        "${MY_PATH}/N2_Genesis.sh" "${EMAIL}" >&2 || \
            echo "[atom4love_activate] N2_Genesis.sh KO (non-bloquant)" >&2

        # Email dédié "Bienvenue dans LOVE" — une seule fois par compte, quel que
        # soit le nombre de republications idempotentes (mêmes données de naissance).
        # Aucune donnée identifiante dans ce message : confirme juste l'activation
        # et pointe vers atomic_dream.html. La suite (newsletter KIN) est un flux
        # opt-in séparé, réglé via .mailjet (kin.*), pas déclenché ici.
        _LOVE_WELCOME_TPL="${MY_PATH}/../templates/NOSTR/love_welcome.html"
        _LOVE_WELCOME_SENT="${_NOSTR_DIR}/.love_welcome_sent"
        if [[ -s "${_LOVE_WELCOME_TPL}" && ! -s "${_LOVE_WELCOME_SENT}" ]]; then
            _tmp_love=$(mktemp)
            sed -e "s~http://127.0.0.1:8080~${myLIBRA}~g" \
                -e "s~_uSPOT_~${uSPOT}~g" \
                "${_LOVE_WELCOME_TPL}" > "${_tmp_love}"
            "${MY_PATH}/mailjet.sh" --channel milestones --template "${_LOVE_WELCOME_TPL}" --expire 7d \
                "${EMAIL}" "${_tmp_love}" "💭 Votre clé LOVE est active" >&2
            date -u > "${_LOVE_WELCOME_SENT}"
            rm -f "${_tmp_love}"
        fi
    else
        echo "❌ atom4love_publish.py n'a pas activé la clé LOVE — données de naissance non persistées (${_PY_RESULT})" >&2
    fi
    echo "${_PY_RESULT}"
else
    echo "⚠️  Missing birth_lat/birth_lon — skipping ATOM4LOVE key derivation/publish" >&2
    echo "{\"activated\":false,\"email\":\"${EMAIL}\",\"error\":\"MISSING_BIRTH_COORDINATES\"}"
fi
