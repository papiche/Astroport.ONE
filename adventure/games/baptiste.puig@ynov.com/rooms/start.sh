#!/bin/bash

# Mots possibles pour le jeu
words=("ordinateur" "programmation" "bash" "terminal" "script")

# Sélection aléatoire d'un mot
target="${words[RANDOM % ${#words[@]}]}"
length=${#target}
guessed=($(for ((i=0;i<$length;i++)); do echo "_"; done))

# Initialisation des variables
attempts=0
max_attempts=6
guessed_letters=""
wrong_letters=""

# Dessins ASCII du pendu
HANGMAN=(
"  +---+\n  |   |\n      |\n      |\n      |\n      |\n========="
"  +---+\n  |   |\n  O   |\n      |\n      |\n      |\n========="
"  +---+\n  |   |\n  O   |\n  |   |\n      |\n      |\n========="
"  +---+\n  |   |\n  O   |\n /|   |\n      |\n      |\n========="
"  +---+\n  |   |\n  O   |\n /|\\  |\n      |\n      |\n========="
"  +---+\n  |   |\n  O   |\n /|\\  |\n /    |\n      |\n========="
"  +---+\n  |   |\n  O   |\n /|\\  |\n / \\  |\n      |\n========="
)

# Fonction pour afficher l'état actuel du jeu
display() {
    clear
    echo "Jeu du Pendu"
    echo -e "${HANGMAN[attempts]}" # Utilisez echo -e pour interpréter les séquences d'échappement
    echo "Mot à deviner: ${guessed[*]}"
    echo "Lettres essayées: $wrong_letters"
}

# Fonction de vérification des lettres
guess() {
    read -p "Devinez une lettre: " -n 1 letter
    echo

    if [[ "$target" == *"$letter"* ]]; then
        for (( i=0; i<${#target}; i++ )); do
            if [[ "${target:$i:1}" == "$letter" ]]; then
                guessed[$i]=$letter
            fi
        done
    else
        ((attempts++))
        wrong_letters+="$letter "
    fi
}

# Boucle principale du jeu
while [ $attempts -lt $max_attempts ]; do
    display
    guess

    if [ "$target" == "$(echo ${guessed[*]} | tr -d ' ')" ]; then
        echo "Félicitations, vous avez trouvé le mot : $target !"
        exit
    fi
done

display
echo "Désolé, vous avez perdu. Le mot était : $target."