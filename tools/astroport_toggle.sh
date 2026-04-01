#!/bin/bash
########################################################################
# astroport_toggle.sh - Bouton ON/OFF utilisant cron_VRFY.sh
########################################################################
ASTRO_PATH="$HOME/.zen/Astroport.ONE"
DESKTOPS=("$HOME/Bureau" "$HOME/Desktop")

# 1. Exécuter la bascule via le contrôleur officiel
bash "$ASTRO_PATH/tools/cron_VRFY.sh" TOGGLE

# 2. Détecter le nouvel état (on se base sur le service astroport)
if systemctl is-active --quiet astroport; then
    NEW_NAME="Astroport [ON]"
    NEW_ICON="$ASTRO_PATH/astroport_on.png"
    # Notification enrichie
    if command -v notify-send >/dev/null; then
        notify-send "Astroport.ONE" "Station ACTIVE. Synchronisation constellation en cours..." --icon="$NEW_ICON"
    fi
else
    NEW_NAME="Astroport [OFF]"
    NEW_ICON="$ASTRO_PATH/astroport_off.png"
    MSG="Station à l'arrêt"
fi

# 3. Notification système
if command -v notify-send >/dev/null; then
    notify-send "Astroport.ONE" "$MSG" --icon="$NEW_ICON"
fi

# 4. Mise à jour visuelle des fichiers .desktop sur le bureau
for DESK in "${DESKTOPS[@]}"; do
    FILE="$DESK/astroport_toggle.desktop"
    if [ -f "$FILE" ]; then
        sed -i "s|^Name=.*|Name=$NEW_NAME|" "$FILE"
        sed -i "s|^Icon=.*|Icon=$NEW_ICON|" "$FILE"
    fi
done