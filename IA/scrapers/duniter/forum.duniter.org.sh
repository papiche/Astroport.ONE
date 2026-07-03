#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# forum.duniter.org.sh — Surveillance des nouveaux sujets sur le forum
# Discourse forum.duniter.org
#
# Déclenché automatiquement par NOSTRCARD.refresh.sh quand
# ~/.zen/game/nostr/EMAIL/.forum.duniter.org.cookie est détecté.
# Signale au PROPRIÉTAIRE du cookie (DM NOSTR, multi-tenant) les nouveaux
# sujets pertinents via bro_watch_core.py (voir IA/forum_watch.py).
################################################################################

PLAYER="$1"
COOKIE_FILE="$2"

[[ -z "$PLAYER" || -z "$COOKIE_FILE" ]] && echo "Usage: $0 <player_email> <cookie_file_path>" && exit 1

MY_PATH="$(dirname "$(realpath "$0")")"
IA_DIR="$(cd "${MY_PATH}/../.." && pwd)"
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"
SEEN_FILE="${PLAYER_DIR}/.forum.duniter.org.seen.json"

FORUM_URL="${FORUM_DUNITER_URL:-https://forum.duniter.org}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📰 Surveillance forum Discourse (${FORUM_URL}) pour ${PLAYER}"

python3 "${IA_DIR}/forum_watch.py" \
    --player "$PLAYER" \
    --cookie-file "$COOKIE_FILE" \
    --forum-url "$FORUM_URL" \
    --seen-file "$SEEN_FILE"

exit_code=$?
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Forum scraper terminé (exit code: $exit_code)"
exit $exit_code
