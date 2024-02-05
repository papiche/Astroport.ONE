#!/bin/bash

GAMES_DIR="./games"

if [ ! -d "$GAMES_DIR" ]; then
    echo "Le dossier des jeux $GAMES_DIR n'existe pas."
    exit 1
fi

GAMES=$(find "$GAMES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

if [ -z "$GAMES" ]; then
    echo "Aucun jeu trouvé dans le dossier $GAMES_DIR."
    exit 1
fi

echo "Sélectionnez un jeu :"
select GAME in $GAMES; do
    if [ -n "$GAME" ]; then
        cd "$GAMES_DIR/$GAME/rooms"
        START_SCRIPT="./start.sh"
        
        if [ ! -x "$START_SCRIPT" ]; then
            echo "Le fichier start.sh pour $GAME n'existe pas ou n'est pas exécutable."
            exit 1
        fi
        
        echo "Lancement de $GAME..."
        "$START_SCRIPT"
        break
    else
        echo "Choix invalide. Veuillez réessayer."
    fi
done