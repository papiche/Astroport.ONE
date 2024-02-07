#!/bin/bash

################################################################################
# Author: Tuuake
# Version: 1.0
# Cours de scripting M1 Master Cyberséc
################################################################################

source ./Config.sh
source ./fonctions.sh

initialiser_plateau

echo "######################################################################"
echo "###################### Bienvenue dans Puissance 4 ####################"
echo "######################################################################"

# Demander les noms des joueurs
read -p "Nom du Joueur 1: " NOM_JOUEUR1
read -p "Nom du Joueur 2: " NOM_JOUEUR2

tour=0

while true; do
    clear
    afficher_plateau

    if ((tour % 2 == 0)); then
        joueur="$NOM_JOUEUR1"
        token="$PLAYER1_TOKEN"
    else
        joueur="$NOM_JOUEUR2"
        token="$PLAYER2_TOKEN"
    fi

    read -p "$joueur, entrez le numéro de colonne (1-$COLS): " choix_colonne

    if ! [[ $choix_colonne =~ ^[1-$COLS]$ ]]; then
        echo "Veuillez entrer un numéro de colonne valide."
        continue
    fi

    placer_jeton "$choix_colonne" "$token"

    if verifier_victoire; then
        clear
        afficher_plateau
        echo "$joueur a gagné !"
        break
    fi

    ((tour++))
done

# Afficher le plateau une dernière fois à la fin du jeu
clear
afficher_plateau

