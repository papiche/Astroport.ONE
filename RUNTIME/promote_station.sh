#!/bin/bash
########################################################################
# promote_station.sh — Auto-promotion multicanal (Mastodon, Telegram)
#
# Publie un message quotidien sur les canaux Web2 configurés PAR LE CAPITAINE
# (vault API Access par MULTIPASS, cookie.html onglet "API officielle" —
# cf. UPassport/services/api_access_store.py, kind NOSTR 31904) :
#   - jour impair  → STATS   (Power-Score, valeur d'émancipation, MULTIPASS)
#   - jour pair    → MARKETING (texte éditorial, cf. IA/channels/promote_templates.json)
#
# Le Capitaine représente la station publiquement — l'auto-promotion utilise
# donc SES identifiants (résolus via CAPTAINEMAIL), pas un secret de station
# séparé. Safe à lancer si le Capitaine n'a rien configuré (no-op silencieux).
#
# Idempotent : un seul post réel par jour (marqueur flashmem), relançable
# sans effet si déjà fait aujourd'hui (même convention que le backup FaceCloud
# quotidien dans NOSTRCARD.refresh.sh).
#
# Appelé par : 20h12.process.sh (cron quotidien)
# Usage : promote_station.sh [--force]
########################################################################
MY_PATH="$(dirname "$(realpath "$0")")"
. "${HOME}/.zen/Astroport.ONE/tools/my.sh" 2>/dev/null
[[ -s "$HOME/.astro/bin/activate" ]] && . "$HOME/.astro/bin/activate"

CHANNELS_DIR="${MY_PATH}/../IA/channels"
TEMPLATES_FILE="${CHANNELS_DIR}/promote_templates.json"
FLASHMEM_DIR="${HOME}/.zen/flashmem"
mkdir -p "$FLASHMEM_DIR"

TODATE=$(date '+%Y%m%d')
MARKER="${FLASHMEM_DIR}/promote_station_${TODATE}.done"

if [[ -f "$MARKER" && "${1:-}" != "--force" ]]; then
    echo "ℹ️  promote_station.sh : déjà exécuté aujourd'hui (${TODATE}) — utilisez --force pour forcer"
    exit 0
fi

## ── Choix du contenu : stats (jour impair) / marketing (jour pair) ─────────
DAY_OF_YEAR=$(date +%j)
if (( DAY_OF_YEAR % 2 == 1 )); then
    MODE="stats"
else
    MODE="marketing"
fi

HOSTNAME_DISPLAY=$(hostname)
DOMAIN_DISPLAY="${myDOMAIN:-copylaradio.com}"

if [[ "$MODE" == "stats" ]]; then
    ## Power-Score depuis le cache heartbox_analysis.json (5 min TTL, déjà calculé
    ## ailleurs — on ne relance jamais le calcul ici)
    _HB_JSON="${HOME}/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"
    POWER_SCORE="N/A"
    [[ -s "$_HB_JSON" ]] && POWER_SCORE=$(jq -r '.power_score // "N/A"' "$_HB_JSON" 2>/dev/null)

    CLOUD_VAL=$(grep "^CLOUD_EMANCIPATION_VALUE=" "${HOME}/.zen/Astroport.ONE/.env" 2>/dev/null | cut -d'=' -f2)
    [[ -z "$CLOUD_VAL" ]] && CLOUD_VAL="?"

    MULTIPASS_COUNT=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -mindepth 1 -type d -name "*@*" 2>/dev/null | wc -l)

    TEXT="🐉 Station ${HOSTNAME_DISPLAY} (${DOMAIN_DISPLAY}) — Astroport.ONE
⚡ Power-Score : ${POWER_SCORE}
💰 Émancipation cloud estimée : ${CLOUD_VAL} €/an
🪪 ${MULTIPASS_COUNT} MULTIPASS hébergés
Web3 souverain, logiciel libre AGPL : https://astroport.one"
else
    if [[ -s "$TEMPLATES_FILE" ]]; then
        TEXT=$(jq -r '.marketing[]' "$TEMPLATES_FILE" 2>/dev/null | shuf -n1)
    fi
    [[ -z "$TEXT" ]] && TEXT="🐉 ${HOSTNAME_DISPLAY} est une station Astroport.ONE — Web3 souverain, logiciel libre AGPL. https://astroport.one"
    TEXT="${TEXT//\{hostname\}/$HOSTNAME_DISPLAY}"
    TEXT="${TEXT//\{domain\}/$DOMAIN_DISPLAY}"
fi

echo "📢 promote_station.sh (${MODE}) :"
echo "$TEXT"
echo "---"

_POSTED_ANY=false
API_ACCESS_CLI="${HOME}/.zen/UPassport/api_access_cli.py"
PYBIN="python3"
[[ -x "$HOME/.astro/bin/python3" ]] && PYBIN="$HOME/.astro/bin/python3"

if [[ -z "${CAPTAINEMAIL:-}" ]]; then
    echo "ℹ️  CAPTAINEMAIL introuvable — auto-promotion ignorée (station sans capitaine onboardé ?)"
    touch "$MARKER"
    exit 0
fi
if [[ ! -s "$API_ACCESS_CLI" ]]; then
    echo "ℹ️  api_access_cli.py introuvable (UPassport absent ?) — auto-promotion ignorée"
    touch "$MARKER"
    exit 0
fi

## Mastodon — identifiants du Capitaine (vault API Access)
MASTODON_CFG=$("$PYBIN" "$API_ACCESS_CLI" get "$CAPTAINEMAIL" mastodon 2>/dev/null)
MASTODON_INSTANCE=$(echo "$MASTODON_CFG" | jq -r '.instance_url // ""' 2>/dev/null)
MASTODON_TOKEN=$(echo "$MASTODON_CFG" | jq -r '.access_token // ""' 2>/dev/null)
if [[ -n "$MASTODON_INSTANCE" && -n "$MASTODON_TOKEN" ]]; then
    if "$PYBIN" "${CHANNELS_DIR}/mastodon_channel.py" post "$MASTODON_INSTANCE" "$MASTODON_TOKEN" "$TEXT" >/dev/null 2>&1; then
        echo "✅ Posté sur Mastodon (${CAPTAINEMAIL})"
        _POSTED_ANY=true
    else
        echo "⚠️  Échec post Mastodon (voir logs)"
    fi
else
    echo "ℹ️  Mastodon non configuré pour le Capitaine — ignoré"
fi

## Telegram (canal d'annonce, channel_id) — identifiants du Capitaine
TELEGRAM_CFG=$("$PYBIN" "$API_ACCESS_CLI" get "$CAPTAINEMAIL" telegram 2>/dev/null)
TELEGRAM_TOKEN=$(echo "$TELEGRAM_CFG" | jq -r '.bot_token // ""' 2>/dev/null)
TELEGRAM_CHANNEL=$(echo "$TELEGRAM_CFG" | jq -r '.channel_id // ""' 2>/dev/null)
if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHANNEL" ]]; then
    if "$PYBIN" "${CHANNELS_DIR}/telegram_channel.py" send "$TELEGRAM_TOKEN" "$TELEGRAM_CHANNEL" "$TEXT" >/dev/null 2>&1; then
        echo "✅ Posté sur Telegram (${CAPTAINEMAIL})"
        _POSTED_ANY=true
    else
        echo "⚠️  Échec post Telegram (voir logs)"
    fi
else
    echo "ℹ️  Telegram non configuré (ou channel_id absent) pour le Capitaine — ignoré"
fi

touch "$MARKER"
$_POSTED_ANY && echo "✅ promote_station.sh terminé (${MODE})" \
             || echo "ℹ️  Aucun canal configuré par le Capitaine — rien publié"
exit 0
