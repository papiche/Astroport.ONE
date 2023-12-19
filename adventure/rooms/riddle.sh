#!/bin/bash

score=0

function ask_question {
    local question="$1"
    local options=("${@:2}")

    echo "$question"
    
    for (( i=0; i<${#options[@]}; i++ )); do
        echo "$((i+1)). ${options[i]}"
    done

    read -p "Votre réponse : " user_choice

    if [ "$user_choice" -le 0 ] || [ "$user_choice" -gt "${#options[@]}" ]; then
        echo "Choix invalide. Veuillez entrer un nombre entre 1 et ${#options[@]}."
    elif [ "${options[$((user_choice-1))]}" == "correct" ]; then
        echo "Bonne réponse !"
        ((score++))
    else
        echo "Mauvaise réponse."
    fi
}

# Énigme 1
ask_question "Quel est le capitale de la France ?" "Paris" "Berlin" "Londres" "Madrid"

# Énigme 2
ask_question "Quelle est la couleur du ciel par temps clair ?" "Bleu" "Rouge" "Vert" "Jaune"

# Énigme 3
ask_question "Combien de planètes dans notre système solaire?" "7" "8" "9" "10"

echo "Votre score final est de $score sur 3."
