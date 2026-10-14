#!/bin/bash
########################################################################
# channels_watchdog.sh — (Re)démarre les ponts Web2 multi-tenant (Telegram,
# Mastodon). Chaque pont scanne lui-même les comptes MULTIPASS locaux ayant
# configuré un canal (vault API Access, cookie.html onglet "API officielle")
# — ce script ne fait que s'assurer que les deux daemons tournent, sans
# connaître leur contenu. Démarrage sans effet réseau si aucun compte n'a
# rien configuré (boucle de scan interne, aucune requête externe tant
# qu'aucun provider n'est trouvé).
#
# Usage : channels_watchdog.sh
########################################################################
MY_PATH="$(dirname "$(realpath "$0")")"
PYBIN="python3"
[[ -x "$HOME/.astro/bin/python3" ]] && PYBIN="$HOME/.astro/bin/python3"

if ! pgrep -f "IA/channels/telegram_bridge.py" >/dev/null 2>&1; then
    nohup "$PYBIN" "${MY_PATH}/telegram_bridge.py" >> "$HOME/.zen/tmp/telegram_bridge.log" 2>&1 &
    disown
fi

if ! pgrep -f "IA/channels/mastodon_bridge.py" >/dev/null 2>&1; then
    nohup "$PYBIN" "${MY_PATH}/mastodon_bridge.py" >> "$HOME/.zen/tmp/mastodon_bridge.log" 2>&1 &
    disown
fi

exit 0
