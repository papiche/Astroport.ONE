#!/bin/bash
################################################################################
# atom4love_profile.sh — Calcule et publie le profil de rencontre (kind 30078,
# d=love-profile) de la clé LOVE (.secret.love) déjà activée : bio, âge,
# intérêts, photo, visibilité publique pour le matching.
#
# Réutilisé par :
#   - UPassport/routers/identity.py (POST /atom4love/profile)
#   - IA/bro/love_handler.sh (_handle_love_profile, édition via chat BRO)
#
# Usage: atom4love_profile.sh EMAIL [AGE] [BIO] [INTERESTS] [PUBLIC] [PHOTO]
#   INTERESTS : tags séparés par des virgules (ex: "nature,musique,voyage")
#   PHOTO : URL IPFS (déjà uploadée via /api/upload/image)
#   Un paramètre vide n'est pas envoyé dans le payload (pas d'écrasement).
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/my.sh"

EMAIL="$1"
AGE="$2"
BIO="$3"
INTERESTS="$4"
PUBLIC="$5"
PHOTO="$6"

if [[ -z "${EMAIL}" ]]; then
    echo "Usage: atom4love_profile.sh EMAIL [AGE] [BIO] [INTERESTS] [PUBLIC] [PHOTO]" >&2
    echo '{"published":false,"error":"MISSING_EMAIL"}'
    exit 1
fi

_LOVE_SECRET="${HOME}/.zen/game/nostr/${EMAIL}/.secret.love"
if [[ ! -s "$_LOVE_SECRET" ]]; then
    echo "❌ No .secret.love for ${EMAIL} — activate ATOM4LOVE first" >&2
    echo '{"published":false,"error":"LOVE_KEY_NOT_FOUND"}'
    exit 1
fi

## Payload JSON via variables d'environnement — évite les pièges de
## quoting shell avec un texte bio libre (guillemets, retours à la ligne).
_PAYLOAD=$(AGE="$AGE" BIO="$BIO" INTERESTS="$INTERESTS" PUBLIC="$PUBLIC" PHOTO="$PHOTO" python3 -c "
import json, os
payload = {}
age = os.environ.get('AGE', '').strip()
if age:
    payload['age'] = int(age) if age.isdigit() else 0
bio = os.environ.get('BIO', '')
if bio.strip():
    payload['bio'] = bio
interests = [t.strip() for t in os.environ.get('INTERESTS', '').split(',') if t.strip()]
if interests:
    payload['interests'] = interests
public_raw = os.environ.get('PUBLIC', '').strip().lower()
if public_raw:
    payload['public'] = public_raw in ('1', 'true', 'yes', 'on')
photo = os.environ.get('PHOTO', '').strip()
if photo:
    payload['photo'] = photo
print(json.dumps(payload))
")

echo "${_PAYLOAD}" | python3 "${MY_PATH}/atom4love_profile_publish.py" "${EMAIL}"
