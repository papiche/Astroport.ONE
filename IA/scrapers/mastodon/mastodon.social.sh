#!/bin/bash
################################################################################
# mastodon.social.sh — Surveillance des mentions sur mastodon.social
#
# Déclenché automatiquement par NOSTRCARD.refresh.sh quand
# ~/.zen/game/nostr/EMAIL/.mastodon.social.cookie est détecté.
# Ne publie rien — signale au PROPRIÉTAIRE du cookie (DM NOSTR, multi-tenant)
# les éléments pertinents via bro_watch_core.py (voir scraper_mastodon.py).
################################################################################

PLAYER="$1"
COOKIE_FILE="$2"

[[ -z "$PLAYER" || -z "$COOKIE_FILE" ]] && echo "Usage: $0 <player_email> <cookie_file_path>" && exit 1

MY_PATH="$(dirname "$(realpath "$0")")"
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"
SEEN_FILE="${PLAYER_DIR}/.mastodon.social.seen.json"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🐘 Surveillance Mastodon pour ${PLAYER}"

python3 "${MY_PATH}/scraper_mastodon.py" \
    --player "$PLAYER" \
    --cookie-file "$COOKIE_FILE" \
    --instance "mastodon.social" \
    --seen-file "$SEEN_FILE"

exit_code=$?
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Mastodon scraper terminé (exit code: $exit_code)"
exit $exit_code
