#!/bin/bash
################################################################################
# atom4love_dream.sh — Calcule et publie le dream_vector (kind 30079,
# d=dream_vector) de la clé LOVE (.secret.love) déjà activée : tags de
# Réalité Choisie (DR), vitesse d'alignement v (âge+poids), time-ratio CR:DR
# et texte libre CR/DR.
#
# Réutilisé par :
#   - UPassport/routers/identity.py (POST /atom4love/dream)
#   - IA/bro/love_handler.sh (_handle_love_dream, brouillon proposé par Ollama)
#
# Usage: atom4love_dream.sh EMAIL BIRTH_UNIX WEIGHT_KG DREAM_TAGS RATIO CR DR NOTES
#   DREAM_TAGS : tags séparés par des virgules
#                (ex: "setting:foret,values:souverainete,method:visualisation")
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/my.sh"

EMAIL="$1"
BIRTH_UNIX="$2"
WEIGHT_KG="$3"
DREAM_TAGS="$4"
RATIO="$5"
CR="$6"
DR="$7"
NOTES="$8"

if [[ -z "${EMAIL}" ]]; then
    echo "Usage: atom4love_dream.sh EMAIL BIRTH_UNIX WEIGHT_KG DREAM_TAGS RATIO CR DR NOTES" >&2
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
## quoting shell avec un texte CR/DR libre (guillemets, retours à la ligne).
_PAYLOAD=$(DREAM_TAGS="$DREAM_TAGS" RATIO="$RATIO" CR="$CR" DR="$DR" NOTES="$NOTES" python3 -c "
import json, os
tags = [t.strip() for t in os.environ.get('DREAM_TAGS', '').split(',') if t.strip()]
print(json.dumps({
    'dream_tags': tags,
    'ratio': os.environ.get('RATIO', ''),
    'cr': os.environ.get('CR', ''),
    'dr': os.environ.get('DR', ''),
    'notes': os.environ.get('NOTES', ''),
}))
")

echo "${_PAYLOAD}" | python3 "${MY_PATH}/atom4love_dream_publish.py" \
    "${EMAIL}" "${BIRTH_UNIX}" "${WEIGHT_KG:-3.5}"
