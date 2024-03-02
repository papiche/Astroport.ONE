#!/bin/bash

# Générer une opération mathématique aléatoire
generate_operation() {
    local operators=("+" "-" "*" "/")
    local operator=${operators[$RANDOM % ${#operators[@]} ]}
    local operand1=$((RANDOM % 20 + 1))
    local operand2=$((RANDOM % 20 + 1))

    echo "$operand1 $operator $operand2"
}

# Vérifier la réponse
check_answer() {
    local result=$(echo "$1" | bc -l)
    if [ "$result" == "$2" ]; then
        echo "Correct !"
        return 0
    else
        echo "Incorrect. La réponse était $result."
        return 1
    fi
}

# Boucle principale du jeu
while true; do
    # Générer une opération
    operation=$(generate_operation)

    # Afficher l'opération et demander à l'utilisateur de fournir la réponse
    read -p "Résolvez $operation : " user_answer

    # Vérifier la réponse
    if check_answer "$operation" "$user_answer"; then
        # Si correcte, continuer avec une nouvelle opération
        echo "Bravo !"
    else
        # Si la réponse est incorrecte, demander à l'utilisateur s'il veut quitter ou continuer
        read -p "Voulez-vous continuer ? (O/n) " continue_playing
        if [ "$continue_playing" == "n" ]; then
            echo "Merci d'avoir joué. Au revoir !"
            break
        fi
    fi
done
