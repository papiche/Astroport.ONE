#!/bin/bash

while true; do
    clear
    echo "Menu Principal"
    echo "1. Puissance 4"
    echo "2. Autre Jeu (à ajouter)"
    echo "3. Quitter"

    read -p "Choisissez le numéro du jeu à exécuter: " choix_jeu

    case $choix_jeu in
        1)
            clear
            echo "Vous avez choisi Puissance 4."
            # Ajoutez le code pour exécuter Puissance 4 ici
            ./Puissance4.sh
            ;;
        2)
            clear
            echo "Vous avez choisi Autre Jeu (à ajouter)."
            # Ajoutez le code pour exécuter l'autre jeu ici
            ;;
        3)
            clear
            echo "Au revoir!"
            exit 0
            ;;
        *)
            echo "Choix invalide. Veuillez sélectionner un numéro valide."
            sleep 2
            ;;
    esac
done

