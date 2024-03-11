#!/bin/bash

# Initialisation du plateau de jeu
declare -a board
for i in {0..8}; do
    board[$i]=$i
done

# Affichage du plateau de jeu
function display_board {
    echo " ${board[0]} | ${board[1]} | ${board[2]} "
    echo "---|---|---"
    echo " ${board[3]} | ${board[4]} | ${board[5]} "
    echo "---|---|---"
    echo " ${board[6]} | ${board[7]} | ${board[8]} "
}

# Vérification de la victoire
function check_win {
    local player=$1
    local symbol=$2
    if [[ "${board[0]}" == "$symbol" && "${board[1]}" == "$symbol" && "${board[2]}" == "$symbol" ]] ||
       [[ "${board[3]}" == "$symbol" && "${board[4]}" == "$symbol" && "${board[5]}" == "$symbol" ]] ||
       [[ "${board[6]}" == "$symbol" && "${board[7]}" == "$symbol" && "${board[8]}" == "$symbol" ]] ||
       [[ "${board[0]}" == "$symbol" && "${board[3]}" == "$symbol" && "${board[6]}" == "$symbol" ]] ||
       [[ "${board[1]}" == "$symbol" && "${board[4]}" == "$symbol" && "${board[7]}" == "$symbol" ]] ||
       [[ "${board[2]}" == "$symbol" && "${board[5]}" == "$symbol" && "${board[8]}" == "$symbol" ]] ||
       [[ "${board[0]}" == "$symbol" && "${board[4]}" == "$symbol" && "${board[8]}" == "$symbol" ]] ||
       [[ "${board[2]}" == "$symbol" && "${board[4]}" == "$symbol" && "${board[6]}" == "$symbol" ]]; then
        echo "Le joueur $player ($symbol) gagne !"
        exit
    fi
    if ! (echo ${board[@]} | grep -q '[0-8]'); then
        echo "Match nul !"
        exit
    fi
}

# Boucle de jeu principale
player=1
symbol="X"
while true; do
    display_board
    echo "Joueur $player: Choisissez une position (0-8) pour le symbole $symbol:"
    read -r pos
    if ! [[ $pos =~ ^[0-8]$ ]] || [[ ! ${board[$pos]} =~ ^[0-8]$ ]]; then
        echo "Entrée invalide, veuillez réessayer."
        continue
    fi
    board[$pos]=$symbol
    check_win $player $symbol
    if [ "$symbol" == "X" ]; then
        symbol="O"
        player=2
    else
        symbol="X"
        player=1
    fi
done
