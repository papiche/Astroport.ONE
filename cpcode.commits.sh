#!/bin/bash
# Script pour extraire les fichiers texte avec plusieurs extensions spécifiques
# d'un dossier source et copier le contenu dans le presse-papier.
# Possibilité de ne prendre que les fichiers modifiés dans les N derniers commits
# (nécessite d'être dans un dépôt Git).

show_help() {
    echo "Usage : $0 [--commits N] [--help] <extension1> [<extension2> ...] <dossier_source>"
    echo "Options :"
    echo "  --help        Affiche cette aide."
    echo "  --commits N   Ne traite que les fichiers modifiés dans les N derniers commits (doit être exécuté dans un dépôt Git)."
    exit 0
}

# Variables
COMMITS=""
POSITIONAL=()

# Parsing des options
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --commits)
            if [[ -z "$2" || "$2" =~ ^-- ]]; then
                echo "Erreur : L'option --commits nécessite un argument numérique."
                exit 1
            fi
            COMMITS="$2"
            shift 2
            ;;
        --*)
            echo "Erreur : Option inconnue : $1"
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Restauration des arguments positionnels (extensions et dossier source)
set -- "${POSITIONAL[@]}"
if [ "$#" -lt 2 ]; then
    echo "Erreur : Arguments manquants."
    show_help
    exit 1
fi

EXTENSIONS=("${@:1:$#-1}")
SOURCE_DIR="${@: -1}"

# Vérification de l'option --commits
if [ -n "$COMMITS" ]; then
    if ! [[ "$COMMITS" =~ ^[0-9]+$ ]] || [ "$COMMITS" -le 0 ]; then
        echo "Erreur : L'option --commits doit être suivie d'un entier positif."
        exit 1
    fi
    # Vérification que nous sommes dans un dépôt Git
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Erreur : L'option --commits nécessite d'être dans un dépôt Git."
        exit 1
    fi
    GIT_MODE=true
else
    GIT_MODE=false
fi

# Détection de la commande de presse-papiers
if command -v xclip &>/dev/null; then
    CLIP_CMD="xclip -selection clipboard"
elif command -v pbcopy &>/dev/null; then
    CLIP_CMD="pbcopy"
else
    CLIP_CMD=""
fi

RESULT=""
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
TEMP_FILE="/tmp/$MOATS"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Erreur : Le dossier source '$SOURCE_DIR' n'existe pas."
    exit 1
fi

# Fonction de traitement d'un fichier (ajout à RESULT)
process_file() {
    local file="$1"
    local ext="$2"
    if file "$file" | grep -q "text"; then
        RELATIVE_PATH=$(realpath --relative-to="$SOURCE_DIR" "$file")
        FILENAME=$(basename "$file" | sed "s/\.$ext$//")
        echo "Ajout de : $file"
        RESULT+="Chemin : $RELATIVE_PATH\n"
        RESULT+="Titre : $FILENAME\n\n"
        RESULT+="$(cat "$file")\n\n"
    fi
}

if [ "$GIT_MODE" = true ]; then
    # Mode Git : récupération des fichiers modifiés dans les N derniers commits
    REPO_ROOT=$(git rev-parse --show-toplevel)
    SOURCE_DIR_ABS=$(realpath "$SOURCE_DIR")
    
    # Récupère la liste des fichiers modifiés (existants) dans les N derniers commits
    while IFS= read -r FILE; do
        # Exclure les fichiers dans des dossiers cachés (comportement d'origine : présence de "/.")
        if [[ "$FILE" == *"/."* ]]; then
            continue
        fi
        FULL_PATH="$REPO_ROOT/$FILE"
        # Vérifier que le fichier existe et se trouve sous le dossier source
        if [ -f "$FULL_PATH" ] && [[ "$FULL_PATH" == "$SOURCE_DIR_ABS"* ]]; then
            # Vérifier l'extension
            for EXT in "${EXTENSIONS[@]}"; do
                if [[ "$FILE" == *.$EXT ]]; then
                    process_file "$FULL_PATH" "$EXT"
                    break
                fi
            done
        fi
    done < <(git diff --name-only --diff-filter=ACMRT HEAD~$COMMITS HEAD 2>/dev/null)
    
    if [ -z "$RESULT" ]; then
        echo "Erreur : Aucun fichier texte trouvé avec les extensions spécifiées dans les $COMMITS derniers commits, dans '$SOURCE_DIR'."
        rm -f "$TEMP_FILE"
        exit 1
    fi
else
    # Mode normal : parcours récursif du dossier source
    for EXT in "${EXTENSIONS[@]}"; do
        while IFS= read -r FILE; do
            process_file "$FILE" "$EXT"
        done < <(find "$SOURCE_DIR" -type f -name "*.$EXT" | grep -v '/\.')
    done

    if [ -z "$RESULT" ]; then
        echo "Erreur : Aucun fichier trouvé avec les extensions spécifiées dans '$SOURCE_DIR'."
        rm -f "$TEMP_FILE"
        exit 1
    fi
fi

# Écriture du résultat dans un fichier temporaire
echo -e "$RESULT" > "$TEMP_FILE"

# Copie dans le presse-papiers ou sauvegarde dans un fichier
if [ -n "$CLIP_CMD" ] && [ -n "$DISPLAY" ] && cat "$TEMP_FILE" | $CLIP_CMD 2>/dev/null; then
    CLIPBOARD_CONTENT=$(xclip -o -selection clipboard 2>/dev/null || pbpaste 2>/dev/null)
    if [ -n "$CLIPBOARD_CONTENT" ]; then
        echo "Le contenu texte a été copié dans le presse-papiers."
    else
        echo "Avertissement : la copie dans le presse-papiers a peut-être échoué."
    fi
else
    OUTPUT_FILE="$(realpath "$SOURCE_DIR")/cpcode_output.txt"
    cp "$TEMP_FILE" "$OUTPUT_FILE"
    echo "Résultat écrit dans : $OUTPUT_FILE"
fi

rm -f "$TEMP_FILE"