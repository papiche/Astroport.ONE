#!/bin/bash

# Function to handle enigma scenes
function enigma_scene {
    local question="$1"
    local options=("${@:2}")
    local correct_answer="$2"

    echo "$question"
    
    for (( i=0; i<${#options[@]}; i++ )); do
        echo "$((i+1)). ${options[i]}"
    done

    read -p "Votre réponse : " user_choice

    if ! [[ "$user_choice" =~ ^[1-9][0-9]*$ ]]; then
        echo "Choix invalide. Veuillez entrer un nombre valide."
        return 1
    elif [ "$user_choice" -le 0 ] || [ "$user_choice" -gt "${#options[@]}" ]; then
        echo "Choix invalide. Veuillez entrer un nombre entre 1 et ${#options[@]}."
        return 1
    elif [ "${options[$((user_choice-1))]}" == "$correct_answer" ]; then
        echo "Bonne réponse !"
        return 0  # Succès
    else
        echo "Mauvaise réponse. La réponse correcte était : $correct_answer"
        return 1  # Échec
    fi
}

# Main game loop
score=0
for _ in {1..3}; do
    echo "Bienvenue dans le monde des énigmes."

    if enigma_scene "Énigme 1: Quel est le capitale de la France ?" "Paris" "Berlin" "Londres" "Madrid" "Paris"; then
        echo "Appuyez sur Entrée pour continuer..."
        ((score++))
    else
        echo "Vous reposez l'écran portatif interactif."
        read -p "Appuyez sur Entrée pour quitter..."
        exit
    fi

    if enigma_scene "Énigme 2: Quelle est la couleur du ciel par temps clair ?" "Bleu" "Rouge" "Vert" "Jaune" "Bleu"; then
        echo "Appuyez sur Entrée pour continuer..."
        ((score++))
    else
        echo "Vous reposez l'écran portatif interactif."
        read -p "Appuyez sur Entrée pour quitter..."
        exit
    fi

    if enigma_scene "Énigme 3: Combien de planètes dans notre système solaire?" "7" "8" "9" "10" "8"; then
        break
    else
        echo "Vous reposez l'écran portatif interactif."
        read -p "Appuyez sur Entrée pour quitter..."
        exit
    fi
done

# Vérifier le score avant de donner la possibilité de revenir dans mainroom.sh
if [ "$score" -ge 2 ]; then
    echo "Félicitations, voici un indice dans ta quête vers l'astroport : indice 1"
    read -p "Appuyez sur Entrée pour revenir à la pièce principale..."
else
    echo "Vous reposez l'écran portatif interactif."
    read -p "Appuyez sur Entrée pour quitter..."
fi

# Lancer mainroom.sh
./mainroom.sh
