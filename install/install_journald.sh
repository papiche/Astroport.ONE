#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
#~ install_journald.sh — borne l'espace disque du journal systemd.
#~ Sans limite, journald peut atteindre plusieurs Go (3,3 Go constatés sur une
#~ station, dont l'essentiel venait de services bavards : snapclient, powerjoular).
#~ Drop-in dédié : /etc/systemd/journald.conf.d/astroport.conf (idempotent).
set -u
CONF_DIR="/etc/systemd/journald.conf.d"
CONF="$CONF_DIR/astroport.conf"
WANTED='[Journal]
SystemMaxUse=500M
SystemKeepFree=2G
MaxRetentionSec=14day
MaxFileSec=1week
'
[[ "$(cat "$CONF" 2>/dev/null)" == "${WANTED%$'\n'}" ]] && { echo "✅ journald déjà limité ($CONF)"; exit 0; }
sudo mkdir -p "$CONF_DIR" \
    && printf '%s' "$WANTED" | sudo tee "$CONF" >/dev/null \
    && sudo systemctl restart systemd-journald \
    && sudo journalctl --vacuum-size=500M >/dev/null 2>&1 \
    && echo "✅ journald limité à 500M / 14 jours ($CONF)" \
    || echo "⚠️  journald : limite non appliquée (sudo/systemd indisponible ?)"
exit 0
