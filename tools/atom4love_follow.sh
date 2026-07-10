#!/bin/bash
################################################################################
# atom4love_follow.sh — Ajoute/retire un pubkey de la liste de contacts
# (kind 3, NIP-02) de la clé LOVE (.secret.love) déjà activée.
#
# Réutilisé par : UPassport/routers/identity.py (POST /atom4love/follow)
#
# Usage: atom4love_follow.sh EMAIL ACTION TARGET_HEX
#   ACTION : add | remove
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/my.sh"

EMAIL="$1"
ACTION="$2"
TARGET_HEX="$3"

if [[ -z "${EMAIL}" || -z "${ACTION}" || -z "${TARGET_HEX}" ]]; then
    echo "Usage: atom4love_follow.sh EMAIL ACTION TARGET_HEX" >&2
    echo '{"published":false,"error":"MISSING_PARAMETERS"}'
    exit 1
fi

_LOVE_SECRET="${HOME}/.zen/game/nostr/${EMAIL}/.secret.love"
if [[ ! -s "$_LOVE_SECRET" ]]; then
    echo "❌ No .secret.love for ${EMAIL} — activate ATOM4LOVE first" >&2
    echo '{"published":false,"error":"LOVE_KEY_NOT_FOUND"}'
    exit 1
fi

python3 "${MY_PATH}/atom4love_follow.py" "${EMAIL}" "${ACTION}" "${TARGET_HEX}"
