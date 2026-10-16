#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com) — License: AGPL-3.0
# domain_scraper_run.sh — Lance UN scraper de domaine (youtube.com.sh, …) pour UN MULTIPASS, EN PROCESSUS AUTONOME.
#
# Usage : domain_scraper_run.sh PLAYER DOMAIN DOMAIN_SCRIPT COOKIE_FILE SYNC_LOG [BRO_WATCH_CORE]
#
# Lancé par RUNTIME/NOSTRCARD.refresh.sh avec `setsid nohup … 200>&- &`. POURQUOI un script à part et pas un sous-shell
# `( … ) &` : un sous-shell garde la ligne de commande de NOSTRCARD.refresh.sh pendant toute la durée du scraper (des
# heures pour une synchro YouTube), et `_12345.sh` ne relance JAMAIS NOSTRCARD.refresh.sh tant que
# `pgrep -f NOSTRCARD.refresh.sh` trouve un processus : plus aucun autre MULTIPASS n'était rafraîchi.
# La ligne de commande de ce script ne contient pas « NOSTRCARD.refresh.sh » (les arguments non plus).
#
# Journal : LOGFILE (même format que log() de NOSTRCARD.refresh.sh), sortie du scraper dans SYNC_LOG.
################################################################################
PLAYER="$1"; DOMAIN="$2"; DOMAIN_SCRIPT="$3"; COOKIE_FILE="$4"; SYNC_LOG="$5"; BRO_WATCH_CORE="$6"
LOGFILE="${LOGFILE:-$HOME/.zen/tmp/MULTIPASS.refresh.log}"

_log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$$] [$1] $2" >> "$LOGFILE"; }

if [[ -z "$PLAYER" || -z "$DOMAIN" || -z "$DOMAIN_SCRIPT" || -z "$COOKIE_FILE" || -z "$SYNC_LOG" ]]; then
    echo "usage: $0 PLAYER DOMAIN DOMAIN_SCRIPT COOKIE_FILE SYNC_LOG [BRO_WATCH_CORE]" >&2
    exit 2
fi
if [[ ! -x "$DOMAIN_SCRIPT" ]]; then
    _log "ERROR" "❌ scraper ${DOMAIN} introuvable ou non exécutable pour ${PLAYER} : ${DOMAIN_SCRIPT}"
    exit 1
fi

"$DOMAIN_SCRIPT" "$PLAYER" "$COOKIE_FILE" > "$SYNC_LOG" 2>&1
code=$?
if [[ $code -eq 0 ]]; then
    _log "INFO" "✅ ${DOMAIN} scraper completed successfully for ${PLAYER}"
else
    _log "WARN" "⚠️ ${DOMAIN} scraper completed with exit code ${code} for ${PLAYER} (cf. ${SYNC_LOG})"
fi

# Sauvegarde chiffrée du log dans le manifest cookie (IPFS) — best-effort, mais l'échec est DIT (jamais /dev/null).
if [[ -n "$BRO_WATCH_CORE" && -f "$BRO_WATCH_CORE" ]]; then
    if ! out=$(python3 "$BRO_WATCH_CORE" store-log "$PLAYER" "$DOMAIN" "$SYNC_LOG" 2>&1); then
        _log "WARN" "⚠️ store-log du scraper ${DOMAIN} pour ${PLAYER} en échec : ${out: -300}"
    fi
fi
exit $code
