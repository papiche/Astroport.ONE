# fonctions.sh
source Config.sh

initialiser_plateau() {
    for ((i = 0; i < ROWS * COLS; i++)); do
        board[i]=" "
    done
}

afficher_plateau() {
    for ((i = 0; i < ROWS; i++)); do
        for ((j = 0; j < COLS; j++)); do
            echo -n "${board[i * COLS + j]} "
        done
        echo
    done
}

placer_jeton() {
    local colonne=$1
    local token=$2

    for ((i = ROWS - 1; i >= 0; i--)); do
        if [ "${board[i * COLS + colonne - 1]}" == " " ]; then
            board[i * COLS + colonne - 1]=$token
            break
        fi
    done
}

verifier_victoire() {
    # Vérification des alignements horizontaux
    for ((i = 0; i < ROWS; i++)); do
        for ((j = 0; j < COLS - 3; j++)); do
            if [ "${board[i * COLS + j]}" != " " ] && \
               [ "${board[i * COLS + j]}" == "${board[i * COLS + j + 1]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[i * COLS + j + 2]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[i * COLS + j + 3]}" ]; then
                return 0  # Victoire
            fi
        done
    done

    # Vérification des alignements verticaux
    for ((j = 0; j < COLS; j++)); do
        for ((i = 0; i < ROWS - 3; i++)); do
            if [ "${board[i * COLS + j]}" != " " ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 1) * COLS + j]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 2) * COLS + j]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 3) * COLS + j]}" ]; then
                return 0  # Victoire
            fi
        enddone
    done

    # Vérification des alignements diagonaux (de gauche à droite)
    for ((i = 0; i < ROWS - 3; i++)); do
        for ((j = 0; j < COLS - 3; j++)); do
            if [ "${board[i * COLS + j]}" != " " ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 1) * COLS + j + 1]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 2) * COLS + j + 2]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 3) * COLS + j + 3]}" ]; then
                return 0  # Victoire
            fi
        done
    done

    # Vérification des alignements diagonaux (de droite à gauche)
    for ((i = 0; i < ROWS - 3; i++)); do
        for ((j = 3; j < COLS; j++)); do
            if [ "${board[i * COLS + j]}" != " " ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 1) * COLS + j - 1]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 2) * COLS + j - 2]}" ] && \
               [ "${board[i * COLS + j]}" == "${board[(i + 3) * COLS + j - 3]}" ]; then
                return 0  # Victoire
            fi
        done
    done

    return 1  # Pas de victoire
}
