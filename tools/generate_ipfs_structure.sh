#!/bin/bash

# Script pour générer la structure IPFS avec manifest.json et _index.html
# Usage: ./generate_ipfs_structure.sh [repertoire_source]

set -e

# Fonction d'aide
show_help() {
    cat << 'HELP_EOF'
🌐 UPlanet IPFS Structure Generator

USAGE:
    ./generate_ipfs_structure.sh [OPTIONS] DIRECTORY

ARGUMENTS:
    DIRECTORY    Répertoire source (OBLIGATOIRE)

OPTIONS:
    -h, --help   Afficher cette aide
    --log        Activer le logging détaillé (sinon sortie silencieuse)

DESCRIPTION:
    Génère une structure complète pour IPFS avec:
    - manifest.json : inventaire de tous les fichiers avec liens IPFS individuels
    - _index.html   : interface d'exploration moderne avec éditeur Markdown
    - index.html    : redirection automatique

    MISE À JOUR INCRÉMENTALE:
    Le script compare les timestamps des fichiers avec le manifest existant
    et ne re-ajoute à IPFS que les fichiers nouveaux ou modifiés.

WORKFLOW:
    1. ./generate_ipfs_structure.sh [--log] DIRECTORY
    2. Le script retourne le CID final de l'application
    3. Accéder à http://127.0.0.1:8080/ipfs/[CID]/

SORTIE:
    - Mode normal: Seul le CID final est affiché
    - Mode --log: Affichage détaillé de tous les traitements
    - Erreurs: Toujours affichées sur stderr

EXEMPLES:
    ./generate_ipfs_structure.sh .                          # Répertoire courant
    ./generate_ipfs_structure.sh --log .                    # Avec logs détaillés
    ./generate_ipfs_structure.sh ./mon-projet               # Répertoire spécifique
    ./generate_ipfs_structure.sh --log ./mon-projet         # Logs + répertoire spécifique
    ./generate_ipfs_structure.sh --help                     # Cette aide

HELP_EOF
}

# Configuration par défaut
SOURCE_DIR=""
ENABLE_LOGGING=false

# Gestion des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    -h|--help)
        show_help
        exit 0
        ;;
        --log)
            ENABLE_LOGGING=true
            shift
        ;;
    -*)
            echo "❌ Option inconnue: $1" >&2
            echo "Utilisez --help pour voir l'aide" >&2
        exit 1
        ;;
        *)
            if [ -z "$SOURCE_DIR" ]; then
                SOURCE_DIR="$1"
            else
                echo "❌ Erreur: Plusieurs répertoires spécifiés" >&2
                echo "Utilisez --help pour voir l'aide" >&2
                exit 1
            fi
            shift
        ;;
esac
done

# Vérifier qu'un répertoire a été fourni
if [ -z "$SOURCE_DIR" ]; then
    echo "❌ Erreur: Aucun répertoire spécifié" >&2
    echo ""
    show_help
    exit 1
fi

# Fonction de logging conditionnelle
log_message() {
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "$@"
    fi
}

# Fonction pour les messages d'erreur (toujours affichés sur stderr)
error_message() {
    echo "$@" >&2
}

# Vérifier que le répertoire existe
if [ ! -d "$SOURCE_DIR" ]; then
    error_message "❌ Erreur: Le répertoire '$SOURCE_DIR' n'existe pas"
    exit 1
fi

# Convertir en chemin absolu pour éviter les problèmes
SOURCE_DIR=$(realpath "$SOURCE_DIR")

# vérifier que le répertoire contient le répertoire Documents
if [[ ! -d "$SOURCE_DIR/Music" || ! -d "$SOURCE_DIR/Documents" || ! -d "$SOURCE_DIR/Images" || ! -d "$SOURCE_DIR/Videos" ]]; then
    #ajouter le répertoire Documents
    mkdir -p "$SOURCE_DIR/Documents"
    #ajouter le répertoire Images
    mkdir -p "$SOURCE_DIR/Images"
    #ajouter le répertoire Videos
    mkdir -p "$SOURCE_DIR/Videos"
    #ajouter le répertoire Audio
    mkdir -p "$SOURCE_DIR/Music"
    # ecire un coucou dans le fichier README.md
    if [ ! -f "$SOURCE_DIR/Documents/README.md" ]; then
        touch "$SOURCE_DIR/Documents/README.md"
    fi
fi

log_message "🚀 Génération de la structure IPFS..."
log_message "📁 Répertoire source: $SOURCE_DIR"
log_message ""

# Fonction pour obtenir la taille d'un fichier
get_file_size() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f%z "$file" 2>/dev/null || echo "0"
    else
        # Linux
        stat -c%s "$file" 2>/dev/null || echo "0"
    fi
}

# Fonction pour formater la taille
format_size() {
    local size=$1
    if [ $size -lt 1024 ]; then
        echo "${size} B"
    elif [ $size -lt 1048576 ]; then
        echo "$((size / 1024)) kB"
    else
        echo "$((size / 1048576)) MB"
    fi
}

# Fonction pour détecter le type de fichier
get_file_type() {
    local file="$1"
    local ext="${file##*.}"

    case $ext in
        jpg|jpeg|png|gif|webp|bmp|svg|ico) echo "image" ;;
        html|htm) echo "html" ;;
        js|mjs) echo "javascript" ;;
        css) echo "stylesheet" ;;
        json) echo "json" ;;
        txt|md|rst) echo "text" ;;
        pdf) echo "document" ;;
        mp3|wav|ogg|m4a) echo "audio" ;;
        mp4|avi|mov|webm) echo "video" ;;
        zip|tar|gz|7z|rar) echo "archive" ;;
        py|sh|bash) echo "script" ;;
        *) echo "file" ;;
    esac
}

# Fonction pour extraire les métadonnées des fichiers média
get_media_metadata() {
    local file="$1"
    local file_type="$2"
    local metadata_json=""

    case $file_type in
        image)
            # Essayer d'obtenir les dimensions de l'image
            if command -v identify >/dev/null 2>&1; then
                local dimensions=$(identify -format "%wx%h" "$file" 2>/dev/null)
                if [ -n "$dimensions" ] && [ "$dimensions" != "0x0" ]; then
                    local width=$(echo $dimensions | cut -d'x' -f1)
                    local height=$(echo $dimensions | cut -d'x' -f2)
                    metadata_json="\"width\": \"$width\", \"height\": \"$height\", \"dimensions\": \"$dimensions\""
                fi
            fi
            ;;
        video)
            # Essayer d'obtenir les informations vidéo
            if command -v ffprobe >/dev/null 2>&1; then
                local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
                local dimensions=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$file" 2>/dev/null)

                if [ -n "$duration" ] && [ "$duration" != "N/A" ] && [ "$duration" != "" ]; then
                    local formatted_duration=$(echo "$duration" | awk '{printf "%.0f", $1}')
                    local min_sec=$(echo "$formatted_duration" | awk '{printf "%d:%02d", $1/60, $1%60}')
                    metadata_json="\"duration_seconds\": $formatted_duration, \"formatted_duration\": \"$min_sec\""
                fi

                if [ -n "$dimensions" ] && [ "$dimensions" != "x" ] && [ "$dimensions" != "0x0" ]; then
                    local width=$(echo $dimensions | cut -d'x' -f1)
                    local height=$(echo $dimensions | cut -d'x' -f2)
                    if [ -n "$metadata_json" ]; then
                        metadata_json="$metadata_json, \"width\": \"$width\", \"height\": \"$height\", \"dimensions\": \"$dimensions\""
                    else
                        metadata_json="\"width\": \"$width\", \"height\": \"$height\", \"dimensions\": \"$dimensions\""
                    fi
                fi
            fi
            ;;
        audio)
            # Essayer d'obtenir les informations audio
            if command -v ffprobe >/dev/null 2>&1; then
                local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
                local bitrate=$(ffprobe -v quiet -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)

                if [ -n "$duration" ] && [ "$duration" != "N/A" ] && [ "$duration" != "" ]; then
                    local formatted_duration=$(echo "$duration" | awk '{printf "%.0f", $1}')
                    local min_sec=$(echo "$formatted_duration" | awk '{printf "%d:%02d", $1/60, $1%60}')
                    metadata_json="\"duration_seconds\": $formatted_duration, \"formatted_duration\": \"$min_sec\""
                fi

                if [ -n "$bitrate" ] && [ "$bitrate" != "N/A" ] && [ "$bitrate" != "" ]; then
                    local bitrate_kb=$(echo "$bitrate" | awk '{printf "%.0f", $1/1000}')
                    if [ -n "$metadata_json" ]; then
                        metadata_json="$metadata_json, \"bitrate\": $(echo "$bitrate" | awk '{printf "%.0f", $1}'), \"formatted_bitrate\": \"${bitrate_kb} kbps\""
                    else
                        metadata_json="\"bitrate\": $(echo "$bitrate" | awk '{printf "%.0f", $1}'), \"formatted_bitrate\": \"${bitrate_kb} kbps\""
                    fi
                fi
            fi
            ;;
    esac

    echo "$metadata_json"
}

# Fonction pour nettoyer le nom de fichier pour JSON
clean_filename() {
    local name="$1"
    # Échapper les guillemets et antislashs pour JSON
    echo "$name" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g'
}

# Fonction pour obtenir le timestamp d'un fichier
get_file_timestamp() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f%m "$file" 2>/dev/null || echo "0"
    else
        # Linux
        stat -c%Y "$file" 2>/dev/null || echo "0"
    fi
}

# Fonction pour ajouter un fichier à IPFS et récupérer le hash
add_file_to_ipfs() {
    local file="$1"
    local relative_path="$2"

    # Ajouter le fichier à IPFS avec wrapper pour conserver le nom
    # -r : récursif, -w : wrap avec nom, -q : quiet (hash seulement)
    local ipfs_output=$(ipfs add -rwq "$file" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$ipfs_output" ]; then
        # Prendre le hash du wrapper (dernier) qui contient le fichier avec son nom
        # Le wrapper permet d'accéder au fichier via: /ipfs/wrapper_hash/filename
        local wrapper_hash=$(echo "$ipfs_output" | tail -1 | awk '{print $1}')
        echo "$wrapper_hash"
        return 0
    else
        # Les erreurs vont sur stderr, pas dans le retour
        return 1
    fi
}

# Fonction pour vérifier si un fichier a été modifié
file_needs_update() {
    local file="$1"
    local relative_path="$2"
    local manifest_file="$SOURCE_DIR/manifest.json"

    if [ ! -f "$manifest_file" ]; then
        log_message "      📋 Aucun manifest existant - fichier sera traité"
        return 0  # Pas de manifest, tout doit être traité
    fi

    # Vérifier si jq est disponible
    if ! command -v jq >/dev/null 2>&1; then
        log_message "      ⚠️  jq non disponible - fichier sera traité"
        return 0  # Pas de jq, traiter tous les fichiers
    fi

    # Obtenir le timestamp actuel du fichier
    local current_timestamp=$(get_file_timestamp "$file")

    # Chercher le fichier dans le manifest existant et récupérer son timestamp
    local stored_timestamp=$(jq -r --arg path "$relative_path" '
        .files[]? | select(.path == $path) | .last_modified // 0
    ' "$manifest_file" 2>/dev/null)

    if [ -z "$stored_timestamp" ] || [ "$stored_timestamp" = "null" ] || [ "$stored_timestamp" = "0" ]; then
        log_message "      📄 Nouveau fichier - sera ajouté à IPFS"
        return 0  # Fichier non trouvé dans le manifest, doit être ajouté
    fi

    # Comparer les timestamps
    if [ "$current_timestamp" -gt "$stored_timestamp" ]; then
        log_message "      🔄 Fichier modifié ($(date -d @$current_timestamp '+%Y-%m-%d %H:%M:%S') > $(date -d @$stored_timestamp '+%Y-%m-%d %H:%M:%S')) - sera mis à jour"
        return 0  # Fichier modifié
    else
        log_message "      💾 Fichier inchangé - utilisation du cache IPFS"
        return 1  # Fichier inchangé
    fi
}

# Fonction pour récupérer l'ancien lien IPFS d'un fichier
get_existing_ipfs_link() {
    local relative_path="$1"
    local manifest_file="$SOURCE_DIR/manifest.json"

    if [ -f "$manifest_file" ] && command -v jq >/dev/null 2>&1; then
        local existing_link=$(jq -r --arg path "$relative_path" '
            .files[]? | select(.path == $path) | .ipfs_link // ""
        ' "$manifest_file" 2>/dev/null)

        if [ -n "$existing_link" ] && [ "$existing_link" != "null" ]; then
            echo "$existing_link"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Fonction pour récupérer le CID final existant du manifest
get_existing_final_cid() {
    local manifest_file="$SOURCE_DIR/manifest.json"

    if [ -f "$manifest_file" ] && command -v jq >/dev/null 2>&1; then
        local existing_cid=$(jq -r '.final_cid // ""' "$manifest_file" 2>/dev/null)

        if [ -n "$existing_cid" ] && [ "$existing_cid" != "null" ] && [ "$existing_cid" != "" ]; then
            echo "$existing_cid"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Fonction pour extraire le hash d'un lien IPFS et le dépinner
unpin_ipfs_hash() {
    local ipfs_link="$1"
    local description="$2"

    if [ -z "$ipfs_link" ] || [ "$ipfs_link" = "null" ] || [ "$ipfs_link" = "" ]; then
        return 0
    fi

    # Extraire le hash du lien IPFS (format: hash/filename)
    local hash=$(echo "$ipfs_link" | cut -d'/' -f1)

    if [ -n "$hash" ] && [ "$hash" != "$ipfs_link" ]; then
        log_message "      🗑️  Dépinnage de l'ancien hash: $hash ($description)"

        # Essayer de dépinner avec un timeout
        if ipfs --timeout 10s pin rm "$hash" >/dev/null 2>&1; then
            log_message "      ✅ Hash $hash dépinné avec succès"
        else
            log_message "      ⚠️  Échec du dépinnage de $hash (peut-être déjà dépinné)"
        fi
    fi
}

# Fonction pour dépinner les hashes des fichiers supprimés
unpin_deleted_files() {
    local deleted_count="$1"
    local manifest_file="$SOURCE_DIR/manifest.json"
    local deleted_files_list="~/.zen/tmp/deleted_files_$$"

    if [ "$deleted_count" -eq 0 ] || [ ! -f "$deleted_files_list" ]; then
        return 0
    fi

    log_message "🗑️  Dépinnage des hashes des fichiers supprimés..."

    # Pour chaque fichier supprimé, récupérer son ancien lien IPFS et le dépinner
    while IFS= read -r deleted_path; do
        if [ -n "$deleted_path" ]; then
            # Récupérer l'ancien lien IPFS depuis le manifest
            local old_ipfs_link=""
            if [ -f "$manifest_file" ] && command -v jq >/dev/null 2>&1; then
                old_ipfs_link=$(jq -r --arg path "$deleted_path" '
                    .files[]? | select(.path == $path) | .ipfs_link // ""
                ' "$manifest_file" 2>/dev/null)
            fi

            if [ -n "$old_ipfs_link" ] && [ "$old_ipfs_link" != "null" ]; then
                unpin_ipfs_hash "$old_ipfs_link" "fichier supprimé: $deleted_path"
            fi
        fi
    done < "$deleted_files_list"
}

# Fonction pour créer un fichier temporaire avec la liste des fichiers actuels
create_current_files_list() {
    local temp_file="$1"

    # Créer la liste des fichiers actuels avec leurs chemins relatifs
    find "$SOURCE_DIR" -type f -print0 | while IFS= read -r -d '' file; do
        basename_file=$(basename "$file")
        relative_path="${file#$SOURCE_DIR/}"

        # Ignorer les fichiers générés par ce script et les fichiers cachés
        if [[ "$basename_file" == manifest.json ]] || \
           [[ "$basename_file" == _index.html ]] || \
           [[ "$basename_file" == _redirect.html ]] || \
           [[ "$basename_file" == upload_test.html ]] || \
           [[ "$basename_file" == main.py ]] || \
           [[ "$basename_file" == requirements.txt ]] || \
           [[ "$basename_file" == generate_ipfs_structure.sh ]] || \
           [[ "$basename_file" == start_server.sh ]] || \
           [[ "$basename_file" == .* ]] || \
           [[ "$relative_path" == .* ]] || \
           [[ "$relative_path" == *"__pycache__"* ]]; then
            continue
        fi

        # Cas spécial pour index.html généré par ce script
        if [[ "$basename_file" == index.html ]] && [ -f "$file" ] && grep -q "UPLANET_IPFS_GENERATOR" "$file" 2>/dev/null; then
            continue
        fi

        echo "$relative_path" >> "$temp_file"
    done
}

# Fonction pour détecter les fichiers supprimés
detect_deleted_files() {
    local manifest_file="$SOURCE_DIR/manifest.json"
    local deleted_files=()
    local deleted_count=0

    if [ ! -f "$manifest_file" ] || ! command -v jq >/dev/null 2>&1; then
        # Pas de manifest existant ou pas de jq, rien à supprimer
        echo "0"
        return 0
    fi

    # Créer un fichier temporaire avec la liste des fichiers actuels
    local current_files_temp=$(mktemp)
    create_current_files_list "$current_files_temp"

    log_message "🗑️  Détection des fichiers supprimés..." >&2

    # Récupérer tous les chemins de fichiers depuis l'ancien manifest
    local manifest_files=$(jq -r '.files[]?.path // empty' "$manifest_file" 2>/dev/null)

    while IFS= read -r manifest_path; do
        if [ -n "$manifest_path" ]; then
            # Vérifier si ce fichier existe encore sur le disque
            if ! grep -Fxq "$manifest_path" "$current_files_temp" 2>/dev/null; then
                log_message "   🗑️  Fichier supprimé détecté: $manifest_path" >&2
                deleted_files+=("$manifest_path")
                deleted_count=$((deleted_count + 1))
            fi
        fi
    done <<< "$manifest_files"

    # Nettoyer le fichier temporaire
    rm -f "$current_files_temp"

    if [ $deleted_count -gt 0 ]; then
        log_message "   📊 $deleted_count fichier(s) supprimé(s) détecté(s)" >&2

        # Exporter la liste pour usage ultérieur
        printf '%s\n' "${deleted_files[@]}" > "/tmp/deleted_files_$$"
    else
        log_message "   ✅ Aucun fichier supprimé détecté" >&2
    fi

    echo "$deleted_count"
}

# Fonction pour filtrer les fichiers supprimés du JSON
filter_deleted_files_from_json() {
    local deleted_count="$1"
    local manifest_file="$SOURCE_DIR/manifest.json"
    local deleted_files_list="/tmp/deleted_files_$$"

    if [ "$deleted_count" -eq 0 ] || [ ! -f "$deleted_files_list" ]; then
        return 0
    fi

    log_message "🗑️  Suppression des fichiers supprimés du manifest..."

    # Créer un filtre jq pour exclure les fichiers supprimés
    local jq_filter='def deleted_paths: ['

    while IFS= read -r deleted_path; do
        if [ -n "$deleted_path" ]; then
            jq_filter="$jq_filter\"$deleted_path\","
        fi
    done < "$deleted_files_list"

    # Enlever la dernière virgule et fermer le tableau
    jq_filter="${jq_filter%,}]; .files |= map(select(.path as \$p | deleted_paths | index(\$p) | not))"

    # Appliquer le filtre pour supprimer les fichiers supprimés
    if command -v jq >/dev/null 2>&1; then
        local temp_manifest=$(mktemp)
        jq "$jq_filter" "$manifest_file" > "$temp_manifest" 2>/dev/null
        if [ $? -eq 0 ]; then
            mv "$temp_manifest" "$manifest_file"
            log_message "   ✅ Fichiers supprimés retirés du manifest"
        else
            rm -f "$temp_manifest"
            log_message "   ⚠️  Erreur lors du filtrage - manifest non modifié"
        fi
    fi

    # Nettoyer le fichier temporaire
    rm -f "$deleted_files_list"
}

# Générer le manifest.json
log_message "📋 Génération du manifest.json..."

# Sauvegarder le CID existant avant de régénérer le manifest
EXISTING_FINAL_CID=""
if [ -f "$SOURCE_DIR/manifest.json" ]; then
    EXISTING_FINAL_CID=$(get_existing_final_cid)
    if [ -n "$EXISTING_FINAL_CID" ]; then
        log_message "   💾 CID existant sauvegardé: $EXISTING_FINAL_CID"
    fi
fi

# Détecter les fichiers supprimés avant le traitement
deleted_count=$(detect_deleted_files)

# Dépinner les hashes des fichiers supprimés
unpin_deleted_files "$deleted_count"

# Variables pour collecter les données
directories_json=""
files_json=""
total_size=0
file_count=0
dir_count=0
updated_count=0
cached_count=0
OWNER_HEX_PUBKEY=""
# Récupérer la gateway IPFS depuis le fichier .env ou utiliser la valeur par défaut
if [ -f "$HOME/.zen/Astroport.ONE/.env" ]; then
    ORIGIN_IPFS_GATEWAY=$(grep "^myIPFS=" "$HOME/.zen/Astroport.ONE/.env" | cut -d'=' -f2)
fi
ORIGIN_IPFS_GATEWAY="${ORIGIN_IPFS_GATEWAY:-http://127.0.0.1:8080}"


############################################################## MULTIPLE APP on UPLANET
## USED in ${HOME}/.zen/game/nostr/${OWNER_EMAIL}/APP/uDRIVE
OWNER_PLAYER_DIR=$(dirname "$(dirname "$SOURCE_DIR")")
OWNER_EMAIL=$(basename "$OWNER_PLAYER_DIR")
OWNER_HEX_FILE="${HOME}/.zen/game/nostr/${OWNER_EMAIL}/HEX"

if [ -f "$OWNER_HEX_FILE" ]; then
    OWNER_HEX_PUBKEY=$(cat "$OWNER_HEX_FILE" 2>/dev/null)
    log_message "🔑 Clé publique HEX du propriétaire du Drive détectée: $OWNER_HEX_PUBKEY"
else
    log_message "⚠️  Fichier HEX non trouvé pour le propriétaire du Drive : $OWNER_HEX_FILE"
fi

log_message "🔍 Analyse des répertoires..."

# Parcourir tous les répertoires d'abord
while IFS= read -r -d '' dir; do
    # Obtenir le nom de base et le chemin relatif
    basename_dir=$(basename "$dir")
    relative_path="${dir#$SOURCE_DIR/}"

    # Ignorer le répertoire racine et les répertoires cachés
    if [[ "$dir" == "$SOURCE_DIR" ]] || \
       [[ "$basename_dir" == .* ]] || \
       [[ "$relative_path" == .* ]]; then
        continue
    fi

    # Compter les fichiers dans ce répertoire (non récursif)
    files_in_dir=$(find "$dir" -maxdepth 1 -type f | wc -l)
    subdirs_in_dir=$(find "$dir" -maxdepth 1 -type d | wc -l)
    subdirs_in_dir=$((subdirs_in_dir - 1)) # Enlever le répertoire lui-même

    # Nettoyer les noms pour JSON
    clean_basename=$(clean_filename "$basename_dir")
    clean_path=$(clean_filename "$relative_path")

    # Ajouter à la collection
    if [ -n "$directories_json" ]; then
        directories_json="${directories_json},"
    fi

    directories_json="${directories_json}
        {
            \"name\": \"$clean_basename\",
            \"path\": \"$clean_path\",
            \"type\": \"directory\",
            \"files_count\": $files_in_dir,
            \"subdirs_count\": $subdirs_in_dir
        }"

    dir_count=$((dir_count + 1))

    # Afficher le progrès
    if [ $((dir_count % 5)) -eq 0 ]; then
        log_message "   📁 $dir_count répertoires traités..."
    fi

done < <(find "$SOURCE_DIR" -type d -print0 | sort -z)

log_message "🔍 Analyse des fichiers..."

# Parcourir tous les fichiers du répertoire (récursif)
while IFS= read -r -d '' file; do
    # Obtenir le nom de base et le chemin relatif
    basename_file=$(basename "$file")
    relative_path="${file#$SOURCE_DIR/}"

    log_message "🔍 Examen du fichier: $relative_path"

    # Ignorer les fichiers générés par ce script et les fichiers cachés
    if [[ "$basename_file" == manifest.json ]]; then
        log_message "   ⏭️  Ignoré: fichier manifest.json (généré par ce script)"
        continue
    elif [[ "$basename_file" == _index.html ]]; then
        log_message "   ⏭️  Ignoré: fichier _index.html (généré par ce script)"
        continue
    elif [[ "$basename_file" == index.html ]]; then
        # Vérifier si c'est notre fichier de redirection
        if [ -f "$file" ] && grep -q "UPLANET_IPFS_GENERATOR" "$file" 2>/dev/null; then
            log_message "   ⏭️  Ignoré: fichier index.html (généré par ce script - redirection détectée)"
            continue
        else
            log_message "   ⚠️  index.html détecté mais pas généré par ce script - sera traité"
        fi
    elif [[ "$basename_file" == _redirect.html ]]; then
        log_message "   ⏭️  Ignoré: fichier _redirect.html (généré par ce script)"
        continue
    elif [[ "$basename_file" == update_manifest.sh ]]; then
        log_message "   ⏭️  Ignoré: script update_manifest.sh"
        continue
    elif [[ "$basename_file" == upload_test.html ]]; then
        log_message "   ⏭️  Ignoré: fichier upload_test.html (page de test)"
        continue
    elif [[ "$basename_file" == main.py ]]; then
        log_message "   ⏭️  Ignoré: fichier main.py (serveur FastAPI)"
        continue
    elif [[ "$basename_file" == requirements.txt ]]; then
        log_message "   ⏭️  Ignoré: fichier requirements.txt (dépendances Python)"
        continue
    elif [[ "$basename_file" == generate_ipfs_structure.sh ]]; then
        log_message "   ⏭️  Ignoré: script generate_ipfs_structure.sh"
        continue
    elif [[ "$basename_file" == start_server.sh ]]; then
        log_message "   ⏭️  Ignoré: script start_server.sh"
        continue
    elif [[ "$basename_file" == .* ]]; then
        log_message "   ⏭️  Ignoré: fichier caché $basename_file"
        continue
    elif [[ "$relative_path" == .* ]]; then
        log_message "   ⏭️  Ignoré: chemin caché $relative_path"
        continue
    elif [[ "$relative_path" == *"__pycache__"* ]]; then
        log_message "   ⏭️  Ignoré: cache Python $relative_path"
        continue
    fi

    # Ignorer les répertoires (on ne veut que les fichiers)
    if [ -d "$file" ]; then
        log_message "   ⏭️  Ignoré: répertoire $relative_path"
        continue
    fi

    log_message "   📄 Traitement du fichier: $basename_file"

    # Calculer les informations du fichier
    file_size=$(get_file_size "$file")
    file_type=$(get_file_type "$file")
    formatted_size=$(format_size $file_size)
    current_timestamp=$(get_file_timestamp "$file")

    log_message "      📊 Taille: $formatted_size ($file_size bytes)"
    log_message "      🏷️  Type: $file_type"
    log_message "      🕐 Timestamp: $(date -d @$current_timestamp '+%Y-%m-%d %H:%M:%S')"

    # Nettoyer les noms pour JSON
    clean_basename=$(clean_filename "$basename_file")
    clean_path=$(clean_filename "$relative_path")

    # Vérifier si le fichier a été modifié ou est nouveau
    ipfs_link=""
    if file_needs_update "$file" "$relative_path"; then
        # Récupérer l'ancien lien IPFS avant de le remplacer
        old_ipfs_link=$(get_existing_ipfs_link "$relative_path")

        # Fichier nouveau ou modifié - ajouter à IPFS
        log_message "      🚀 Ajout du fichier à IPFS..."
        log_message "         🔗 Ajout IPFS: $relative_path"

        ipfs_hash=$(add_file_to_ipfs "$file" "$relative_path")
        if [ $? -eq 0 ] && [ -n "$ipfs_hash" ]; then
            ipfs_link="$ipfs_hash/$clean_basename"
            updated_count=$((updated_count + 1))
            log_message "         ✅ Hash IPFS obtenu: $ipfs_hash"
            log_message "      ✅ Fichier ajouté avec succès - Link: $ipfs_link"

            # Dépinner l'ancien hash si il existait et qu'il est différent du nouveau
            if [ -n "$old_ipfs_link" ] && [ "$old_ipfs_link" != "$ipfs_link" ]; then
                unpin_ipfs_hash "$old_ipfs_link" "fichier modifié: $relative_path"
            fi
        else
            log_message "      ❌ Échec de l'ajout IPFS"
        fi
    else
        # Fichier inchangé - récupérer l'ancien lien
        ipfs_link=$(get_existing_ipfs_link "$relative_path")
        cached_count=$((cached_count + 1))
    fi

    # Obtenir les métadonnées média
    log_message "      🔍 Extraction des métadonnées..."
    metadata=$(get_media_metadata "$file" "$file_type")
    metadata_fields=""
    if [ -n "$metadata" ]; then
        metadata_fields=", $metadata"
        log_message "      📝 Métadonnées extraites: $metadata"
    else
        log_message "      📝 Aucune métadonnée spécifique trouvée"
    fi

    # Ajouter le lien IPFS s'il est disponible
    ipfs_link_field=""
    if [ -n "$ipfs_link" ]; then
        ipfs_link_field=", \"ipfs_link\": \"$ipfs_link\""
        log_message "      🔗 Lien IPFS final: $ipfs_link"
    else
        log_message "      ⚠️  Aucun lien IPFS disponible"
    fi

    # Ajouter à la collection
    if [ -n "$files_json" ]; then
        files_json="${files_json},"
    fi

    files_json="${files_json}
        {
            \"name\": \"$clean_basename\",
            \"path\": \"$clean_path\",
            \"size\": $file_size,
            \"formatted_size\": \"$formatted_size\",
            \"type\": \"$file_type\",
            \"last_modified\": $current_timestamp$metadata_fields$ipfs_link_field
        }"

    total_size=$((total_size + file_size))
    file_count=$((file_count + 1))

    log_message "   ✅ Fichier traité avec succès ($file_count/$((file_count + cached_count + updated_count)) total)"
    log_message ""

done < <(find "$SOURCE_DIR" -type f -print0 | sort -z)

# Générer le JSON final
cat > "$SOURCE_DIR/manifest.json" << EOF
{
    "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "version": "1.0.0",
    "final_cid": "",
    "owner_email": "$OWNER_EMAIL",
    "owner_hex_pubkey": "$OWNER_HEX_PUBKEY",
    "my_ipfs_gateway": "$ORIGIN_IPFS_GATEWAY",
    "directories": [$directories_json
    ],
    "files": [$files_json
    ],
    "total_directories": $dir_count,
    "total_files": $file_count,
    "total_size": $total_size,
    "formatted_total_size": "$(format_size $total_size)"
}
EOF

# Filtrer les fichiers supprimés du manifest final
filter_deleted_files_from_json "$deleted_count"

# Fonction pour mettre à jour le CID final dans le manifest
update_final_cid_in_manifest() {
    local final_cid="$1"
    local manifest_file="$SOURCE_DIR/manifest.json"

    if [ -n "$final_cid" ] && [ -f "$manifest_file" ] && command -v jq >/dev/null 2>&1; then
        local temp_manifest=$(mktemp)
        jq --arg cid "$final_cid" '.final_cid = $cid' "$manifest_file" > "$temp_manifest" 2>/dev/null
        if [ $? -eq 0 ]; then
            mv "$temp_manifest" "$manifest_file"
            log_message "   📝 CID final sauvegardé dans le manifest: $final_cid"
        else
            rm -f "$temp_manifest"
            log_message "   ⚠️  Erreur lors de la sauvegarde du CID final"
        fi
    fi
}

log_message "✅ Manifest généré avec $dir_count répertoires et $file_count fichiers ($(format_size $total_size))"
log_message "   📊 Statistiques IPFS: $updated_count nouveaux/modifiés, $cached_count en cache, $deleted_count supprimés"

# Générer _index.html
log_message "🎨 Génération de _index.html..."

cat > "$SOURCE_DIR/_index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <link rel="icon" type="image/x-icon" href="/ipfs/QmPPELF7HhM9BXtAUMnNUSNsrRJgsFzLNCQ5pFhWKr9ogk/favicon.galaxy.ico">
    <title>UPlanet MULTIPASS / IPFS Drive Explorer</title>
    <script src="/ipfs/QmQLQ5WdCEc7mpKw5rhUujUU1URKweei4Bb4esyVNd9Atx/G1PalPay_fichiers/jquery-3.6.3.min.js"></script>
    <script src="/ipfs/Qmab3sg8QLrKYw7wQGmBujEdxG3zTNsMQcsG9zoBdToAhQ/marked.min.js.js"></script>
    <script src="/ipfs/QmXEmaPRUaGcvhuyeG99mHHNyP43nn8GtNeuDok8jdpG4a/nostr.bundle.js"></script>
    <link rel="stylesheet" href="/ipfs/QmVAXbUyzyaZP4yVzN6WnkEhw7LFw3TY1bmMCTSKbHgYpR/css/all.min.css">
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 50%, #16213e 100%);
            color: #e0e0e0;
            min-height: 100vh;
            overflow-x: hidden;
            font-size: 14px;
        }

        * { box-sizing: border-box; }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 10px;
            height: calc(100vh - 120px);
            overflow-y: auto;
        }

        .info-panel {
            background: rgba(42, 42, 42, 0.9);
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 10px;
            border: 1px solid #444;
            backdrop-filter: blur(10px);
        }

        .header {
            background: linear-gradient(90deg, #ff6b6b, #ffa500, #ffff00, #00ff00, #00ffff, #0000ff, #ff00ff);
            padding: 1px;
            position: sticky;
            top: 0;
            z-index: 1000;
        }

        .header-content {
            background: #1a1a2e;
            padding: 10px 15px;
            text-align: center;
        }

        .header h1 {
            background: linear-gradient(90deg, #ff6b6b, #ffa500, #ffff00, #00ff00, #00ffff, #0000ff, #ff00ff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            font-size: 1.5em;
            margin: 0;
            font-weight: bold;
        }

        .nav-bar {
            background: #16213e;
            padding: 5px 15px;
            display: flex;
            justify-content: center;
            gap: 10px;
            flex-wrap: wrap;
        }

        .nav-btn {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 15px;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            font-size: 0.75em;
            display: flex;
            align-items: center;
            gap: 5px;
            white-space: nowrap;
        }

        .nav-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 2px 8px rgba(76, 175, 80, 0.4);
            text-decoration: none;
            color: white;
        }

        .search-bar {
            width: 100%;
            padding: 8px 15px;
            background: rgba(42, 42, 42, 0.9);
            border: 2px solid #444;
            border-radius: 20px;
            color: #e0e0e0;
            font-size: 0.9em;
            margin-bottom: 10px;
            transition: border-color 0.3s ease;
        }

        .search-bar:focus {
            outline: none;
            border-color: #4CAF50;
            box-shadow: 0 0 5px rgba(76, 175, 80, 0.3);
        }

        .tabs-container {
            display: flex;
            flex-wrap: wrap;
            gap: 4px;
            margin-bottom: 10px;
            background: rgba(22, 33, 62, 0.8);
            padding: 8px;
            border-radius: 10px;
            border: 1px solid #444;
        }

        .tab {
            background: transparent;
            color: #aaa;
            border: 1px solid #444;
            padding: 6px 12px;
            border-radius: 15px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.75em;
            display: flex;
            align-items: center;
            gap: 5px;
            white-space: nowrap;
        }

        .tab:hover {
            background: rgba(76, 175, 80, 0.2);
            color: #4CAF50;
            border-color: #4CAF50;
        }

        .tab.active {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            color: white;
            border-color: #4CAF50;
            box-shadow: 0 1px 5px rgba(76, 175, 80, 0.3);
        }

        .files-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 10px;
            margin-top: 10px;
        }

        .file-card {
            background: linear-gradient(145deg, #2a2a2a, #1e1e1e);
            border: 1px solid #444;
            border-radius: 8px;
            padding: 10px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .file-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 2px;
            background: linear-gradient(90deg, #ff6b6b, #4CAF50, #2196F3);
            opacity: 0;
            transition: opacity 0.3s ease;
        }

        .file-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            border-color: #4CAF50;
        }

        .file-card:hover::before {
            opacity: 1;
        }

        .file-card:hover .download-btn {
            opacity: 1;
        }

       .file-card:hover .sync-btn {
            opacity: 1;
        }

        .file-card:hover .delete-btn {
            opacity: 1;
        }

        .file-actions {
            position: absolute;
            top: 8px;
            right: 8px;
            display: flex;
            flex-direction: column;
            gap: 4px;
            z-index: 10;
        }
        .file-action-btn { /* Nouvelle classe de base */
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(76, 175, 80, 0.8); /* Couleur par défaut */
            color: white;
            border: none;
            border-radius: 50%;
            width: 28px;
            height: 28px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            opacity: 0;
            transition: all 0.3s ease;
            font-size: 0.8em;
            z-index: 10;
        }

        .file-action-btn.delete-btn { /* Supprimer la règle spécifique au download-btn et la réappliquer ici */
            left: 8px; /* Override for delete button */
            right: auto;
            background: rgba(244, 67, 54, 0.8);
        }

        .file-action-btn:hover {
            background: rgba(76, 175, 80, 1);
            transform: scale(1.1);
        }

        .file-action-btn.delete-btn:hover { /* Override pour le delete button */
            background: rgba(244, 67, 54, 1);
        }

        .file-icon {
            font-size: 2em;
            text-align: center;
            margin-bottom: 8px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .file-name {
            font-weight: bold;
            color: #4CAF50;
            margin-bottom: 6px;
            word-break: break-word;
            font-size: 0.9em;
            line-height: 1.2;
            overflow-wrap: break-word;
            hyphens: auto;
            word-wrap: break-word !important;
            white-space: normal !important;
            writing-mode: horizontal-tb !important;
        }

        .file-details {
            font-size: 0.75em;
            color: #aaa;
            margin-bottom: 6px;
            line-height: 1.3;
            word-break: break-word;
            overflow-wrap: break-word;
            word-wrap: break-word !important;
            white-space: normal !important;
            writing-mode: horizontal-tb !important;
        }

        .file-type-badge {
            display: inline-block;
            padding: 2px 6px;
            border-radius: 8px;
            font-size: 0.65em;
            color: white;
            margin-bottom: 6px;
        }

        /* Modal Styles */
        .modal {
            display: none;
            position: fixed;
            z-index: 2000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.95);
            backdrop-filter: blur(5px);
        }

        .modal-content {
            position: relative;
            width: 100%;
            height: 100%;
            margin: 0;
            background: #1a1a2e;
            border-radius: 0;
            border: none;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .modal-content.image-modal {
            width: 100%;
            height: 100%;
        }

        .modal-content.text-modal {
            background: #ffffff;
            color: #333333;
        }

        .modal-header {
            background: linear-gradient(90deg, #ff6b6b, #4CAF50, #2196F3);
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: white;
            flex-shrink: 0;
        }

        .modal-header.text-header {
            background: linear-gradient(90deg, #333, #555, #777);
        }

        .modal-title {
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .modal-controls {
            display: flex;
            gap: 10px;
        }

        .modal-btn {
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            padding: 8px 12px;
            border-radius: 5px;
            cursor: pointer;
            transition: background 0.3s ease;
        }

        .modal-btn:hover {
            background: rgba(255,255,255,0.3);
        }

        .modal-body {
            flex: 1;
            overflow: auto;
            padding: 0;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .modal-body.text-body {
            padding: 20px;
            background: #ffffff;
            color: #333333;
            font-family: 'Courier New', monospace;
            overflow: auto;
            align-items: flex-start;
            justify-content: flex-start;
        }

        .modal iframe {
            width: 100%;
            height: 100%;
            border: none;
            border-radius: 0 0 15px 15px;
        }

        .modal img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
            border-radius: 0 0 15px 15px;
        }

        .modal video {
            max-width: 100%;
            max-height: 100%;
            border-radius: 0 0 15px 15px;
        }

        .modal audio {
            width: 80%;
            max-width: 600px;
        }

        .loading {
            text-align: center;
            color: #4CAF50;
            font-size: 1.2em;
            margin: 40px 0;
        }

        .error {
            background: rgba(244, 67, 54, 0.1);
            color: #ff6b6b;
            padding: 15px;
            border-radius: 10px;
            margin: 20px 0;
            text-align: center;
            border: 1px solid #f44336;
        }

        /* Type-specific colors */
        .type-image { background-color: #ff9800; }
        .type-html { background-color: #4CAF50; }
        .type-javascript { background-color: #ffc107; }
        .type-json { background-color: #9c27b0; }
        .type-text { background-color: #607d8b; }
        .type-document { background-color: #e91e63; }
        .type-audio { background-color: #673ab7; }
        .type-video { background-color: #3f51b5; }
        .type-archive { background-color: #795548; }
        .type-script { background-color: #009688; }
        .type-directory { background-color: #ff5722; }
        .type-file { background-color: #666; }

        /* Responsive */
        @media (max-width: 768px) {
            .container {
                padding: 5px;
            }

            .files-grid {
                grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                gap: 8px;
            }

            .file-card {
                padding: 8px;
                min-width: 200px;
            }

            .file-icon {
                font-size: 1.5em;
                height: 30px;
            }

            .file-name {
                font-size: 0.8em;
                word-wrap: break-word;
                overflow-wrap: break-word;
                white-space: normal;
                max-width: 100%;
            }

            .file-details {
                font-size: 0.7em;
                word-wrap: break-word;
                overflow-wrap: break-word;
                white-space: normal;
            }

            .filters-bar {
                justify-content: center;
                flex-wrap: wrap;
            }

            .filter-tab {
                flex: 1;
                justify-content: center;
                min-width: 80px;
                font-size: 0.7em;
                padding: 5px 8px;
                max-width: 120px;
            }

            .controls-bar {
                padding: 5px 8px;
                gap: 5px;
                flex-direction: column;
                align-items: stretch;
            }

            .controls-group.nav-buttons {
                justify-content: center;
                flex-wrap: wrap;
                gap: 6px;
            }

            .nav-btn {
                flex: 1;
                min-width: 100px;
                max-width: 140px;
                font-size: 0.7em;
                padding: 5px 8px;
                justify-content: center;
            }

            /* Hide NOSTR Geo and Coracle buttons on mobile */
            #nostr-link,
            .nav-btn[href="https://coracle.copylaradio.com"] {
                display: none;
            }

            .control-btn {
                padding: 4px 8px;
                font-size: 0.7em;
            }

            .controls-right {
                margin-left: 0;
                margin-top: 5px;
                justify-content: center;
                width: 100%;
            }

            .upload-btn-special {
                font-size: 0.75em;
                padding: 8px 20px;
                order: -1; /* Show upload button first on mobile */
            }
        }

        @media (max-width: 480px) {
            .files-grid {
                grid-template-columns: 1fr 1fr;
                gap: 5px;
            }

            .file-card {
                padding: 6px;
                min-width: 150px;
            }

            .file-name {
                font-size: 0.75em;
                line-height: 1.1;
            }

            .file-details {
                font-size: 0.65em;
                line-height: 1.2;
            }

            .filter-tab {
                font-size: 0.65em;
                padding: 4px 6px;
                min-width: 60px;
            }

            .upload-btn-special {
                font-size: 0.7em;
                padding: 6px 16px;
                border-radius: 15px;
            }
        }

        .hidden { display: none !important; }

        /* Animation keyframes */
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .file-card {
            animation: fadeIn 0.5s ease forwards;
        }

        /* Barre de contrôles */
        .controls-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: rgba(22, 33, 62, 0.8);
            padding: 8px 12px;
            border-radius: 10px;
            border: 1px solid #444;
            margin-bottom: 10px;
            flex-wrap: wrap;
            gap: 8px;
        }

        .controls-group {
            display: flex;
            gap: 4px;
            align-items: center;
        }

        .controls-group.nav-buttons {
            gap: 8px;
            flex-wrap: wrap;
        }

        .control-btn {
            background: transparent;
            color: #aaa;
            border: 1px solid #444;
            padding: 6px 10px;
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.8em;
        }

        .control-btn:hover {
            background: rgba(76, 175, 80, 0.2);
            color: #4CAF50;
            border-color: #4CAF50;
        }

        .control-btn.active {
            background: #4CAF50;
            color: white;
            border-color: #4CAF50;
        }

        .nav-btn {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 15px;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            font-size: 0.75em;
            display: flex;
            align-items: center;
            gap: 5px;
            white-space: nowrap;
        }

        .nav-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 2px 8px rgba(76, 175, 80, 0.4);
            text-decoration: none;
            color: white;
        }

        /* Sections pliables */
        .collapsible-section {
            margin-bottom: 10px;
        }

        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: rgba(42, 42, 42, 0.9);
            padding: 10px 15px;
            border-radius: 10px 10px 0 0;
            border: 1px solid #444;
            cursor: pointer;
            transition: background 0.3s ease;
        }

        .section-header:hover {
            background: rgba(52, 52, 52, 0.9);
        }

        .section-header h3 {
            margin: 0;
            color: #4CAF50;
            font-size: 1em;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .toggle-icon {
            transition: transform 0.3s ease;
            color: #aaa;
        }

        .section-header.collapsed .toggle-icon {
            transform: rotate(-90deg);
        }

        .section-content {
            background: rgba(22, 33, 62, 0.8);
            border: 1px solid #444;
            border-top: none;
            border-radius: 0 0 10px 10px;
            padding: 8px;
            transition: max-height 0.3s ease, opacity 0.3s ease;
            overflow: hidden;
        }

        .section-content.collapsed {
            max-height: 0;
            opacity: 0;
            padding: 0 8px;
        }

        /* Thème clair */
        .light-theme {
            background: linear-gradient(135deg, #f5f5f5 0%, #e8e8e8 50%, #dadada 100%);
            color: #333;
        }

        body.foreign-drive {
            background: repeating-linear-gradient(
                45deg,
                #0a0a0a, /* Couleur de fond sombre principale */
                #0a0a0a 10px, /* Fin de la première bande sombre */
                #331a1a 10px, /* Début de la bande rouge sombre */
                #331a1a 20px  /* Fin de la bande rouge sombre */
            );
        }

        .light-theme body.foreign-drive {
            background: repeating-linear-gradient(
                45deg,
                #f5f5f5, /* Couleur de fond claire principale */
                #f5f5f5 10px, /* Fin de la première bande claire */
                #ffe8e8 10px, /* Début de la bande rouge pâle */
                #ffe8e8 20px  /* Fin de la bande rouge pâle */
            );
        }

        .light-theme .header-content {
            background: #ffffff;
        }

        .light-theme .nav-bar {
            background: #e0e0e0;
        }

        .light-theme .info-panel {
            background: rgba(255, 255, 255, 0.9);
            border-color: #ccc;
            color: #333;
        }

        .light-theme .controls-bar {
            background: rgba(255, 255, 255, 0.8);
            border-color: #ccc;
        }

        .light-theme .tabs-container {
            background: rgba(240, 240, 240, 0.8);
            border-color: #ccc;
        }

        .light-theme .section-header {
            background: rgba(255, 255, 255, 0.9);
            border-color: #ccc;
        }

        .light-theme .section-content {
            background: rgba(248, 248, 248, 0.8);
            border-color: #ccc;
        }

        .light-theme .tab {
            color: #666;
            border-color: #ccc;
        }

        .light-theme .control-btn {
            color: #666;
            border-color: #ccc;
        }

        .light-theme .control-btn:hover {
            background: rgba(76, 175, 80, 0.2);
            color: #4CAF50;
        }

        .light-theme .search-bar {
            background: rgba(255, 255, 255, 0.9);
            border-color: #ccc;
            color: #333;
        }

        .light-theme .file-card {
            background: linear-gradient(145deg, #ffffff, #f5f5f5);
            border-color: #ddd;
            color: #333;
        }

        .light-theme .file-details {
            color: #666;
        }

        .light-theme .modal-content {
            background: #ffffff;
            border-color: #ccc;
            color: #333;
        }

        .light-theme .modal-body.text-body {
            background: #ffffff;
            color: #333;
        }

        .light-theme .upload-btn-special {
            background: linear-gradient(45deg, #e91e63, #c2185b);
            box-shadow: 0 2px 4px rgba(233, 30, 99, 0.3);
        }

        .light-theme .upload-btn-special:hover {
            background: linear-gradient(45deg, #c2185b, #ad1457);
            box-shadow: 0 4px 12px rgba(233, 30, 99, 0.5);
        }

        .light-theme .connect-btn-special {
            background: linear-gradient(45deg, #673ab7, #5e35b1);
            box-shadow: 0 2px 4px rgba(103, 58, 183, 0.3);
        }

        .light-theme .connect-btn-special:hover {
            background: linear-gradient(45deg, #5e35b1, #512da8);
            box-shadow: 0 4px 12px rgba(103, 58, 183, 0.5);
        }

        .light-theme .connect-btn-special.connected {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            box-shadow: 0 2px 4px rgba(76, 175, 80, 0.3);
        }

        /* Barre de filtres directement visible */
        .filters-bar {
            display: flex;
            flex-wrap: wrap;
            gap: 4px;
            margin-bottom: 10px;
            background: rgba(22, 33, 62, 0.8);
            padding: 8px;
            border-radius: 10px;
            border: 1px solid #444;
        }

        .filter-tab {
            background: transparent;
            color: #aaa;
            border: 1px solid #444;
            padding: 6px 12px;
            border-radius: 15px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.75em;
            display: flex;
            align-items: center;
            gap: 5px;
            white-space: nowrap;
        }

        .filter-tab:hover {
            background: rgba(76, 175, 80, 0.2);
            color: #4CAF50;
            border-color: #4CAF50;
        }

        .filter-tab.active {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            color: white;
            border-color: #4CAF50;
            box-shadow: 0 1px 5px rgba(76, 175, 80, 0.3);
        }

        /* Panel du bas */
        .bottom-panel {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            background: rgba(26, 26, 46, 0.95);
            backdrop-filter: blur(10px);
            border-top: 1px solid #444;
            z-index: 100;
        }

        .nav-buttons {
            display: flex;
            justify-content: center;
            gap: 10px;
            flex-wrap: wrap;
            padding: 5px;
        }

        /* Markdown Editor Styles */
        .markdown-editor {
            display: flex;
            flex-direction: column;
            height: 100%;
            background: #1a1a2e;
        }

        .markdown-toolbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px 15px;
            background: rgba(42, 42, 42, 0.9);
            border-bottom: 1px solid #444;
            gap: 10px;
            flex-wrap: wrap;
        }

        .markdown-toolbar-group {
            display: flex;
            gap: 5px;
        }

        .markdown-btn {
            background: rgba(76, 175, 80, 0.8);
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 5px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.8em;
            display: flex;
            align-items: center;
            gap: 5px;
        }

        .markdown-btn:hover {
            background: rgba(76, 175, 80, 1);
            transform: translateY(-1px);
        }

        .markdown-btn.active {
            background: #4CAF50;
            box-shadow: 0 2px 5px rgba(76, 175, 80, 0.4);
        }

        .markdown-content {
            display: flex;
            flex: 1;
            overflow: hidden;
        }

        .markdown-editor-pane {
            flex: 1;
            display: flex;
            flex-direction: column;
            border-right: 1px solid #444;
        }

        .markdown-preview-pane {
            flex: 1;
            display: flex;
            flex-direction: column;
            background: #ffffff;
        }

        .markdown-editor-pane.fullwidth {
            border-right: none;
        }

        .markdown-preview-pane.hidden {
            display: none;
        }

        .markdown-editor-pane.hidden {
            display: none;
        }

        .markdown-preview-pane.fullwidth {
            flex: 2;
        }

        .pane-header {
            padding: 8px 12px;
            background: rgba(22, 33, 62, 0.8);
            color: #4CAF50;
            font-weight: bold;
            font-size: 0.9em;
            border-bottom: 1px solid #444;
        }

        .markdown-preview-pane .pane-header {
            background: #f5f5f5;
            color: #333;
        }

        .markdown-textarea {
            flex: 1;
            width: 100%;
            background: #2a2a2a;
            color: #e0e0e0;
            border: none;
            padding: 15px;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            line-height: 1.6;
            resize: none;
            outline: none;
        }

        .markdown-preview {
            flex: 1;
            padding: 15px;
            overflow: auto;
            background: #ffffff;
            color: #333;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
        }

        .markdown-preview h1,
        .markdown-preview h2,
        .markdown-preview h3,
        .markdown-preview h4,
        .markdown-preview h5,
        .markdown-preview h6 {
            color: #2c3e50;
            margin-top: 24px;
            margin-bottom: 16px;
        }

        .markdown-preview h1 { border-bottom: 2px solid #4CAF50; padding-bottom: 8px; }
        .markdown-preview h2 { border-bottom: 1px solid #e1e4e8; padding-bottom: 8px; }

        .markdown-preview code {
            background: #f6f8fa;
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            color: #e36209;
        }

        .markdown-preview pre {
            background: #f6f8fa;
            padding: 16px;
            border-radius: 6px;
            overflow: auto;
            border-left: 4px solid #4CAF50;
        }

        .markdown-preview pre code {
            background: none;
            padding: 0;
            color: #333;
        }

        .markdown-preview blockquote {
            margin: 0;
            padding: 0 16px;
            color: #6a737d;
            border-left: 4px solid #dfe2e5;
        }

        .markdown-preview table {
            border-collapse: collapse;
            width: 100%;
            margin: 16px 0;
        }

        .markdown-preview th,
        .markdown-preview td {
            border: 1px solid #dfe2e5;
            padding: 8px 12px;
            text-align: left;
        }

        .markdown-preview th {
            background: #f6f8fa;
            font-weight: bold;
        }

        .markdown-status {
            padding: 5px 12px;
            background: rgba(22, 33, 62, 0.8);
            color: #aaa;
            font-size: 0.8em;
            border-top: 1px solid #444;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .save-status {
            color: #4CAF50;
        }

        .save-status.error {
            color: #ff6b6b;
        }

        .save-status.saving {
            color: #ffa500;
        }

        .save-status.success {
            color: #4CAF50;
        }

        /* Upload Modal Styles */
        .upload-container {
            padding: 20px;
            max-width: 600px;
            margin: 0 auto;
        }

        .upload-zone {
            border: 2px dashed #4CAF50;
            border-radius: 10px;
            padding: 40px 20px;
            text-align: center;
            background: rgba(76, 175, 80, 0.1);
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            margin-bottom: 20px;
        }

        .upload-zone:hover {
            border-color: #45a049;
            background: rgba(76, 175, 80, 0.2);
        }

        .upload-zone.dragover {
            border-color: #ff6b6b;
            background: rgba(255, 107, 107, 0.1);
        }

        .upload-icon {
            font-size: 3em;
            color: #4CAF50;
            margin-bottom: 15px;
        }

        .upload-text h3 {
            margin: 0 0 10px 0;
            color: #4CAF50;
        }

        .upload-text p {
            margin: 5px 0;
            color: #aaa;
            font-size: 0.9em;
        }

        #file-input {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            opacity: 0;
            cursor: pointer;
        }

        .progress-bar {
            width: 100%;
            height: 20px;
            background: #2a2a2a;
            border-radius: 10px;
            overflow: hidden;
            margin-bottom: 10px;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4CAF50, #45a049);
            width: 0%;
            transition: width 0.3s ease;
        }

        .progress-text {
            text-align: center;
            color: #4CAF50;
            font-weight: bold;
        }

        .upload-results {
            background: rgba(42, 42, 42, 0.9);
            border-radius: 10px;
            padding: 15px;
            margin-top: 20px;
        }

        .upload-result-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px;
            margin: 5px 0;
            background: rgba(76, 175, 80, 0.1);
            border-radius: 5px;
            border-left: 4px solid #4CAF50;
        }

        .upload-result-item.error {
            background: rgba(255, 107, 107, 0.1);
            border-left-color: #ff6b6b;
        }

        .upload-result-file {
            flex: 1;
        }

        .upload-result-status {
            font-weight: bold;
        }

        .upload-result-status.success {
            color: #4CAF50;
        }

        .upload-result-status.error {
            color: #ff6b6b;
        }

        .redirect-notice {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            color: white;
            padding: 15px;
            border-radius: 10px;
            text-align: center;
            margin-top: 15px;
        }

        .redirect-countdown {
            font-size: 1.2em;
            font-weight: bold;
            margin-top: 10px;
        }

        /* Upload button special styles */
        .controls-right {
            margin-left: auto;
            display: flex;
            gap: 8px;
            align-items: center;
        }

        .upload-btn-special {
            background: linear-gradient(45deg, #ff6b6b, #ff5252);
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 20px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.8em;
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 6px;
            white-space: nowrap;
            box-shadow: 0 2px 4px rgba(255, 107, 107, 0.3);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .upload-btn-special:hover {
            background: linear-gradient(45deg, #ff5252, #f44336);
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(255, 107, 107, 0.5);
        }

        .upload-btn-special:active {
            transform: translateY(0px);
            box-shadow: 0 2px 4px rgba(255, 107, 107, 0.3);
        }

        .upload-btn-special i {
            font-size: 1em;
        }

        /* Connect button special styles */
        .connect-btn-special {
            background: linear-gradient(45deg, #9c27b0, #7b1fa2);
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 20px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.8em;
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 6px;
            white-space: nowrap;
            box-shadow: 0 2px 4px rgba(156, 39, 176, 0.3);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .connect-btn-special:hover {
            background: linear-gradient(45deg, #7b1fa2, #6a1b9a);
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(156, 39, 176, 0.5);
        }

        .connect-btn-special:active {
            transform: translateY(0px);
            box-shadow: 0 2px 4px rgba(156, 39, 176, 0.3);
        }

        .connect-btn-special.connected {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            box-shadow: 0 2px 4px rgba(76, 175, 80, 0.3);
        }

        .connect-btn-special.connected:hover {
            background: linear-gradient(45deg, #45a049, #388e3c);
            box-shadow: 0 4px 12px rgba(76, 175, 80, 0.5);
        }

        .connect-btn-special i {
            font-size: 1em;
        }

        /* Markdown Editor Styles */
        .markdown-editor {
            display: flex;
            flex-direction: column;
            height: 100%;
            background: #1a1a2e;
        }

        .modal-content.markdown-modal {
            width: 100%;
            height: 100%;
            max-width: 100vw;
            max-height: 100vh;
            margin: 0;
            border-radius: 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Barre de contrôles en haut -->
        <div class="controls-bar">
            <div class="controls-group nav-buttons">
                <a href="/ipns/copylaradio.com" class="nav-btn" target="_blank"><i class="fas fa-globe"></i> UPlanet</a>
                <a href="#" id="scanner-link" class="nav-btn" target="_blank"><i class="fas fa-search"></i> Scanner</a>
                <a href="#" id="nostr-link" class="nav-btn" target="_blank"><i class="fas fa-satellite-dish"></i> NOSTR Geo</a>
                <a href="https://coracle.copylaradio.com" class="nav-btn" target="_blank"><i class="fas fa-broadcast-tower"></i> Coracle</a>
            </div>
            <div class="controls-group controls-right">
                <button class="connect-btn-special" id="connect-btn"><i class="fas fa-satellite-dish"></i> Connect</button>
                <button class="upload-btn-special" id="upload-btn"><i class="fas fa-upload"></i> Upload</button>
                <button class="control-btn" id="theme-toggle" title="Toggle Theme">
                    <i class="fas fa-moon"></i>
                </button>
            </div>
        </div>

        <!-- Barre de recherche -->
        <input type="text" class="search-bar" id="search-input" placeholder="🔍 Search files...">

        <!-- Filtres directement visibles -->
        <div class="filters-bar">
            <div class="filter-tab active" data-filter="all">
                <i class="fas fa-th-large"></i> All Files
            </div>
            <div class="filter-tab" data-filter="image">
                <i class="fas fa-image"></i> Images
            </div>
            <div class="filter-tab" data-filter="video">
                <i class="fas fa-video"></i> Videos
            </div>
            <div class="filter-tab" data-filter="audio">
                <i class="fas fa-music"></i> Audio
            </div>
            <div class="filter-tab" data-filter="text">
                <i class="fas fa-file-alt"></i> Text
            </div>
            <div class="filter-tab" data-filter="html">
                <i class="fas fa-code"></i> Web
            </div>
            <div class="filter-tab" data-filter="document">
                <i class="fas fa-file-pdf"></i> Docs
            </div>
        </div>

        <!-- Zone d'affichage des fichiers -->
        <div class="files-grid" id="files-container">
            <div class="loading"><i class="fas fa-spinner fa-spin"></i> Loading files...</div>
        </div>
    </div>

    <!-- Navigation et informations en bas -->
    <div class="bottom-panel">
        <div class="collapsible-section" id="directory-info">
            <div class="section-header" data-target="info-content">
                <h3><i class="fas fa-info-circle"></i> Capsule Information</h3>
                <i class="fas fa-chevron-down toggle-icon"></i>
            </div>
            <div class="section-content" id="info-content">
                <div class="loading"><i class="fas fa-spinner fa-spin"></i> Loading directory information...</div>
            </div>
        </div>
    </div>

    <!-- Modal for file preview -->
    <div id="fileModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <div class="modal-title">
                    <i class="fas fa-file"></i>
                    <span id="modal-filename">File Preview</span>
                </div>
                <div class="modal-controls">
                    <button class="modal-btn" id="prevFile" title="Previous File">
                        <i class="fas fa-chevron-left"></i>
                    </button>
                    <span id="modal-file-counter" style="color: #bbb; font-size: 0.9em; min-width: 50px; text-align: center;"></span>
                    <button class="modal-btn" id="nextFile" title="Next File">
                        <i class="fas fa-chevron-right"></i>
                    </button>
                    <button class="modal-btn" id="copyLinkBtn" title="Copy IPFS Link">
                        <i class="fas fa-copy"></i> Copy Link
                    </button>
                    <span id="modal-temp-status" style="margin-left: 10px; color: #ffeb3b; font-size: 0.8em; white-space: nowrap;"></span>
                    <button class="modal-btn" id="closeModal" title="Close">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
            </div>
            <div class="modal-body">
                <iframe id="modal-iframe" src=""></iframe>
            </div>
        </div>
    </div>

    <!-- Modal for file upload -->
    <div id="uploadModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <div class="modal-title">
                    <i class="fas fa-upload"></i>
                    <span>Upload Files</span>
                </div>
                <div class="modal-controls">
                    <button class="modal-btn" id="closeUploadModal" title="Close">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
            </div>
            <div class="modal-body">
                <div class="upload-container">
                    <div class="upload-zone" id="upload-zone">
                        <div class="upload-icon">
                            <i class="fas fa-cloud-upload-alt"></i>
                        </div>
                        <div class="upload-text">
                            <h3>Drop files here or click to browse</h3>
                            <p>Supported types: Images, Music, Videos, Documents</p>
                            <p>Files will be automatically sorted into appropriate folders</p>
                        </div>
                        <input type="file" id="file-input" multiple accept=".jpg,.jpeg,.png,.gif,.webp,.bmp,.svg,.tiff,.ico,.mp3,.wav,.ogg,.flac,.aac,.m4a,.wma,.mp4,.avi,.mov,.wmv,.flv,.webm,.mkv,.m4v,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.rtf,.zip,.rar,.7z">
                    </div>
                    <div class="upload-progress" id="upload-progress" style="display: none;">
                        <div class="progress-bar">
                            <div class="progress-fill" id="progress-fill"></div>
                        </div>
                        <div class="progress-text" id="progress-text">Uploading...</div>
                    </div>
                    <div class="upload-results" id="upload-results" style="display: none;">
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let currentManifest = null;
        let allItems = [];
        let filteredItems = [];
        let currentFilter = 'all';
        let currentFileIndex = 0;
        let currentGateway = '';
        let upassportUrl = '';
        let NOSTRws = '';
        let nostrRelay = null;
        let isNostrConnected = false;
        let userPublicKey = null;
        let userPrivateKey = null;

        const typeIcons = {
            image: 'fas fa-image',
            video: 'fas fa-video',
            audio: 'fas fa-music',
            html: 'fas fa-code',
            javascript: 'fab fa-js-square',
            json: 'fas fa-brackets-curly',
            text: 'fas fa-file-alt',
            document: 'fas fa-file-pdf',
            archive: 'fas fa-file-archive',
            script: 'fas fa-terminal',
            directory: 'fas fa-folder',
            file: 'fas fa-file'
        };

        $(document).ready(function() {
            console.log('Loading IPFS directory from manifest...');
            detectGatewayAndAPIs();
            detectNOSTRws();
            loadManifest();
            setupEventListeners();
        });

        function detectGatewayAndAPIs() {
            // Détecter la gateway IPFS actuelle
            const currentURL = new URL(window.location.href);
            const hostname = currentURL.hostname;
            const port = currentURL.port;
            const protocol = currentURL.protocol.split(":")[0];

            // Gateway IPFS actuelle
            currentGateway = hostname;
            console.log('Detected IPFS Gateway:', currentGateway);

            // Découverte de l'API UPassport
            let upassportPort = port;
            if (port === "8080") {
                upassportPort = "54321";
            }
            const uHost = hostname.replace("ipfs", "u");
            upassportUrl = protocol + "://" + uHost + (upassportPort ? (":" + upassportPort) : "");
            console.log('UPassport API URL:', upassportUrl);

            // Initialiser les liens dynamiques dans la navigation
            $('#scanner-link').attr('href', upassportUrl + '/scan');
            $('#nostr-link').attr('href', upassportUrl + '/nostr');

            console.log('Scanner URL:', upassportUrl + '/scan');
            console.log('NOSTR URL:', upassportUrl + '/nostr');
        }

        function detectNOSTRws() {
            // Détecter la gateway IPFS actuelle
            const currentURL = new URL(window.location.href);
            const hostname = currentURL.hostname;
            const port = currentURL.port;
            const protocol = currentURL.protocol.split(":")[0];

            // Gateway IPFS actuelle
            currentGateway = hostname;
            console.log('Detected IPFS Gateway:', currentGateway);

            // Découverte de l'API UPassport
            let rPort = port;
            if (port === "8080") {
                rPort = "7777";
            }
            const rHost = hostname.replace("ipfs", "relay");

            // Convert protocol to ws/wss
            const wsProtocol = protocol === 'https' ? 'wss' : 'ws';
            NOSTRws = wsProtocol + "://" + rHost + (rPort ? (":" + rPort) : "");
            console.log('NOSTR relay websocket:', NOSTRws);
        }

        // NOSTR Connection Functions
        async function connectToNostr() {
            console.log('Attempting to connect to NOSTR...');

            try {
                // Try to use browser extension first (NIP-07)
                if (window.nostr) {
                    console.log('NOSTR extension detected, requesting permissions...');
                    userPublicKey = await window.nostr.getPublicKey();
                    console.log('Connected with public key:', userPublicKey);

                    // Connect to relay
                    await connectToRelay();
                    updateConnectionStatus(true);
                    return true;
                } else {
                    // Fallback: ask for nsec key
                    const nsec = prompt('No NOSTR extension found. Please enter your nsec key (optional):');
                    if (nsec && nsec.startsWith('nsec1')) {
                        try {
                            const decoded = NostrTools.nip19.decode(nsec);
                            userPrivateKey = decoded.data;
                            userPublicKey = NostrTools.getPublicKey(userPrivateKey);
                            console.log('Connected with manual key, public key:', userPublicKey);

                            // Connect to relay
                            await connectToRelay();
                            updateConnectionStatus(true);
                            return true;
                        } catch (error) {
                            console.error('Invalid nsec key:', error);
                            alert('Invalid nsec key format');
                            return false;
                        }
                    } else {
                        console.log('No credentials provided, skipping NOSTR connection');
                        return false;
                    }
                }
            } catch (error) {
                console.error('Error connecting to NOSTR:', error);
                alert('Failed to connect to NOSTR: ' + error.message);
                return false;
            }
        }

        async function connectToRelay() {
            if (!NOSTRws) {
                detectNOSTRws();
            }

            console.log('Connecting to relay:', NOSTRws);

            try {
                // Initialize relay without event listeners (compatibility fix)
                nostrRelay = NostrTools.relayInit(NOSTRws);

                console.log('Attempting relay connection...');
                await nostrRelay.connect();

                console.log('✅ Connected to NOSTR relay:', NOSTRws);
                isNostrConnected = true;

                // Simple status check
                if (nostrRelay.status === 1) { // OPEN
                    console.log('✅ Relay status: CONNECTED');

                    // Wait a bit for the connection to be fully established
                    setTimeout(() => {
                        console.log('Sending NIP42 authentication after connection delay...');
                        sendNIP42Auth();
                    }, 500);
                } else {
                    console.log('⚠️ Relay status:', nostrRelay.status);
                }

            } catch (error) {
                console.error('Failed to connect to relay:', error);
                isNostrConnected = false;
                throw error;
            }
        }

        async function sendNIP42Auth() {
            if (!nostrRelay || !userPublicKey) {
                console.log('Cannot send NIP42 auth: missing relay or public key');
                return;
            }

            try {
                console.log('Sending NIP42 authentication...');

                // Create auth event (NIP42)
                const authEvent = {
                    kind: 22242,
                    created_at: Math.floor(Date.now() / 1000),
                    tags: [
                        ['relay', NOSTRws],
                        ['challenge', '']  // Empty challenge for now
                    ],
                    content: '',
                    pubkey: userPublicKey
                };

                // Sign the event
                let signedAuthEvent;
                if (window.nostr) {
                    // Use extension
                    signedAuthEvent = await window.nostr.signEvent(authEvent);
                } else if (userPrivateKey) {
                    // Use manual key
                    signedAuthEvent = NostrTools.finishEvent(authEvent, userPrivateKey);
                } else {
                    console.error('No signing method available');
                    return;
                }

                console.log('Signed NIP42 event:', signedAuthEvent);

                // Try publishing via NostrTools first
                try {
                    console.log('Publishing NIP42 event via NostrTools...');
                    const publishPromise = nostrRelay.publish(signedAuthEvent);

                    // Don't wait too long for the publish response
                    const timeoutPromise = new Promise((_, reject) => {
                        setTimeout(() => reject(new Error('Publish timeout')), 3000);
                    });

                    const publishResult = await Promise.race([publishPromise, timeoutPromise]);
                    console.log('✅ NIP42 authentication event published successfully');
                    console.log('Publish result:', publishResult);

                } catch (publishError) {
                    console.log('⚠️ NostrTools publish failed or timed out, trying direct WebSocket...');
                    console.log('Publish error:', publishError);

                    // Use direct WebSocket as fallback
                    tryDirectWebSocketSend(signedAuthEvent);
                }

            } catch (error) {
                console.error('Failed to send NIP42 auth:', error);

                // Last resort: try direct WebSocket
                if (signedAuthEvent) {
                    console.log('Trying direct WebSocket as last resort...');
                    tryDirectWebSocketSend(signedAuthEvent);
                }
            }
        }

        function tryDirectWebSocketSend(signedAuthEvent) {
            // Fallback method for direct WebSocket access
            console.log('Attempting direct WebSocket send...');

            // First, try to access internal WebSocket from NostrTools
            let foundWebSocket = null;

            if (nostrRelay && nostrRelay.ws) {
                console.log('Found WebSocket in nostrRelay.ws');
                foundWebSocket = nostrRelay.ws;
            } else if (nostrRelay && nostrRelay._ws) {
                console.log('Found WebSocket in nostrRelay._ws');
                foundWebSocket = nostrRelay._ws;
            } else if (nostrRelay && nostrRelay.socket) {
                console.log('Found WebSocket in nostrRelay.socket');
                foundWebSocket = nostrRelay.socket;
            }

            if (foundWebSocket) {
                console.log('Using existing WebSocket, state:', foundWebSocket.readyState);
                sendViaWebSocket(foundWebSocket, signedAuthEvent);
            } else {
                // Create our own WebSocket connection as fallback
                console.log('No existing WebSocket found, creating direct connection...');
                const directWs = new WebSocket(NOSTRws);

                directWs.onopen = () => {
                    console.log('✅ Direct WebSocket connected successfully');
                    sendViaWebSocket(directWs, signedAuthEvent);
                };

                directWs.onerror = (error) => {
                    console.error('❌ Direct WebSocket error:', error);
                };

                directWs.onclose = (event) => {
                    console.log('Direct WebSocket closed:', event.code, event.reason);
                };

                // Timeout for connection
                setTimeout(() => {
                    if (directWs.readyState === WebSocket.CONNECTING) {
                        console.error('❌ Direct WebSocket connection timeout');
                        directWs.close();
                    }
                }, 5000);
            }
        }

        function sendViaWebSocket(ws, signedAuthEvent) {
            if (ws && ws.readyState === WebSocket.OPEN) {
                const eventMessage = JSON.stringify(['EVENT', signedAuthEvent]);
                console.log('Sending EVENT message via WebSocket:', eventMessage);
                ws.send(eventMessage);
                console.log('✅ NIP42 event sent via direct WebSocket');
            } else {
                console.error('❌ WebSocket not ready for direct send, state:', ws ? ws.readyState : 'null');
            }
        }

    function updateConnectionStatus(connected) {
        const connectBtn = $('#connect-btn');
        const icon = connectBtn.find('i');

        isNostrConnected = connected; // S'assurer que la variable globale est mise à jour

        if (connected) {
            connectBtn.addClass('connected');
            connectBtn.html('<i class="fas fa-satellite-dish"></i> Connected');
            console.log('NOSTR connection status: CONNECTED - isNostrConnected:', isNostrConnected);
        } else {
            connectBtn.removeClass('connected');
            connectBtn.html('<i class="fas fa-satellite-dish"></i> Connect');
            console.log('NOSTR connection status: DISCONNECTED - isNostrConnected:', isNostrConnected);
        }
        updateUIBasedOnOwnership();
        filterAndDisplayItems(currentFilter, $('#search-input').val().toLowerCase());

        // NEW: Refresh Capsule Information to show updated connection status
        if (currentManifest) { // Only refresh if manifest is already loaded
            displayDirectoryInfo(currentManifest);
        }
    }

        function disconnectFromNostr() {
            if (nostrRelay) {
                nostrRelay.close();
                nostrRelay = null;
            }

            isNostrConnected = false;
            userPublicKey = null;
            userPrivateKey = null;
            updateConnectionStatus(false);
            console.log('Disconnected from NOSTR');
        }

        function loadManifest() {
            $.ajax({
                url: './manifest.json',
                dataType: 'json',
                success: function(manifest) {
                    console.log('Manifest loaded:', manifest);
                    currentManifest = manifest;

                    prepareItemsData(manifest);
                    displayDirectoryInfo(manifest);
                    filterAndDisplayItems('all');
                    updateUIBasedOnOwnership();
                },
                error: function(xhr, status, error) {
                    console.error('Error loading manifest:', error);
                    $('#directory-info').html('<div class="error"><i class="fas fa-exclamation-triangle"></i> Error loading directory information</div>');
                    $('#files-container').html('<div class="error"><i class="fas fa-exclamation-triangle"></i> Error loading files list</div>');
                    updateUIBasedOnOwnership();
                }
            });
        }

        function getCurrentIPFSHash() {
            const url = window.location.href;
            const ipfsMatch = url.match(/\/ipfs\/([a-zA-Z0-9]+)/);
            return ipfsMatch ? ipfsMatch[1] : null;
        }

        function buildIPFSUrl(item) {
            // Si le fichier a un lien IPFS individuel, l'utiliser en priorité
            if (item.ipfs_link && item.ipfs_link.trim() !== '') {
                const currentURL = new URL(window.location.href);
                const baseUrl = `${currentURL.protocol}//${currentURL.host}`;
                // Le lien IPFS contient déjà le nom du fichier : hash/filename
                return `${baseUrl}/ipfs/${item.ipfs_link}`;
            }

            // Sinon, fallback sur la méthode traditionnelle
            const currentHash = getCurrentIPFSHash();
            if (!currentHash) {
                return null; // Not on IPFS yet
            }

            const currentURL = new URL(window.location.href);
            const baseUrl = `${currentURL.protocol}//${currentURL.host}`;

            if (item.itemType === 'directory') {
                return `${baseUrl}/ipfs/${currentHash}/${item.path}/`;
            } else {
                return `${baseUrl}/ipfs/${currentHash}/${item.path}`;
            }
        }

        function prepareItemsData(manifest) {
            allItems = [];

            // Ajouter seulement les fichiers (pas les répertoires)
            if (manifest.files) {
                manifest.files.forEach(file => {
                    allItems.push({...file, itemType: 'file'});
                });
            }
        }

        function setupEventListeners() {
            // Filtrage par type de fichier seulement
            $('.filter-tab').click(function() {
                const filter = $(this).data('filter');
                $('.filter-tab').removeClass('active');
                $(this).addClass('active');
                currentFilter = filter;
                filterAndDisplayItems(filter);
            });

            // Search
            $('#search-input').on('input', function() {
                const searchTerm = $(this).val().toLowerCase();
                filterAndDisplayItems(currentFilter, searchTerm);
            });

            // Toggle thème
            $('#theme-toggle').click(function() {
                $('body').toggleClass('light-theme');
                const icon = $(this).find('i');
                if ($('body').hasClass('light-theme')) {
                    icon.removeClass('fa-moon').addClass('fa-sun');
                    localStorage.setItem('theme', 'light');
                } else {
                    icon.removeClass('fa-sun').addClass('fa-moon');
                    localStorage.setItem('theme', 'dark');
                }
            });

            // Sections pliables simples
            $('.section-header').click(function() {
                const target = $(this).data('target');
                const content = $('#' + target);

                $(this).toggleClass('collapsed');
                content.toggleClass('collapsed');
            });

            // Restaurer le thème sauvegardé
            const savedTheme = localStorage.getItem('theme');
            if (savedTheme === 'light') {
                $('body').addClass('light-theme');
                $('#theme-toggle i').removeClass('fa-moon').addClass('fa-sun');
            }

            // Modal controls
            $('#closeModal').click(closeModal);
            $('#prevFile').click(() => navigateFile(-1));
            $('#nextFile').click(() => navigateFile(1));
            $('#downloadFile').click(downloadCurrentFile);
            $('#copyLinkBtn').click(copyIpfsLink); // NEW: Add click handler for copy button

            // Close modal on background click
            $('#fileModal').click(function(e) {
                if (e.target === this) {
                    closeModal();
                }
            });

            // Keyboard navigation
            $(document).keydown(function(e) {
                if ($('#fileModal').is(':visible')) {
                    // Vérifier si on est dans l'éditeur Markdown
                    const isMarkdownEditor = $('#fileModal .modal-content').hasClass('markdown-modal');
                    const isInTextarea = $(e.target).is('#markdown-textarea');

                    // Si on est dans l'éditeur Markdown et dans la zone de texte, ignorer la navigation
                    if (isMarkdownEditor && isInTextarea) {
                        // Permettre seulement Escape pour fermer
                        if (e.key === 'Escape') {
                            closeModal();
                        }
                        return; // Ignorer les autres touches
                    }

                    // Navigation normale pour les autres cas
                    switch(e.key) {
                        case 'Escape': closeModal(); break;
                        case 'ArrowLeft':
                            if (!isMarkdownEditor) navigateFile(-1);
                            break;
                        case 'ArrowRight':
                            if (!isMarkdownEditor) navigateFile(1);
                            break;
                    }
                }
                if ($('#uploadModal').is(':visible')) {
                    if (e.key === 'Escape') {
                        closeUploadModal();
                    }
                }
            });

            // Upload modal event handlers
            $('#upload-btn').click(function() {
                openUploadModal();
            });

            // NOSTR Connect button handler
            $('#connect-btn').click(function() {
                if (isNostrConnected) {
                    // If connected, disconnect
                    disconnectFromNostr();
                } else {
                    // If not connected, try to connect
                    connectToNostr();
                }
            });



            $('#closeUploadModal').click(function() {
                closeUploadModal();
            });

            // Close upload modal on background click
            $('#uploadModal').click(function(e) {
                if (e.target === this) {
                    closeUploadModal();
                }
            });

            // Upload zone click handler
            $('#upload-zone').click(function() {
                $('#file-input').click();
            });

            // File input change handler
            $('#file-input').change(function() {
                const files = Array.from(this.files);
                if (files.length > 0) {
                    uploadFiles(files);
                }
            });

            // Drag and drop handlers
            $('#upload-zone').on('dragover', function(e) {
                e.preventDefault();
                $(this).addClass('dragover');
            });

            $('#upload-zone').on('dragleave', function(e) {
                e.preventDefault();
                $(this).removeClass('dragover');
            });

            $('#upload-zone').on('drop', function(e) {
                e.preventDefault();
                $(this).removeClass('dragover');
                const files = Array.from(e.originalEvent.dataTransfer.files);
                if (files.length > 0) {
                    uploadFiles(files);
                }
            });
        }

        // --- NOUVEAU CODE : Fonction pour adapter l'UI en fonction du propriétaire du Drive ---
        function updateUIBasedOnOwnership() {
            const uploadBtn = $('#upload-btn');
            const connectBtn = $('#connect-btn');
            const body = $('body');

            // Determine if the drive is foreign (connected, but owner key doesn't match)
            const isForeignDrive = currentManifest && currentManifest.owner_hex_pubkey && userPublicKey &&
                                   currentManifest.owner_hex_pubkey.toLowerCase() !== userPublicKey.toLowerCase();

            // Determine if upload should be disabled
            // It should be disabled if NOT connected to Nostr, OR if connected but it's a foreign drive.
            const disableUpload = !isNostrConnected || isForeignDrive;

            if (disableUpload) {
                console.log('⚠️ Upload disabled. Connected:', isNostrConnected, 'Foreign Drive:', isForeignDrive);
                body.addClass('foreign-drive');
                uploadBtn.prop('disabled', true).css('opacity', '0.5');
                if (!isNostrConnected) {
                    uploadBtn.attr('title', 'Connect to Nostr to enable uploads.');
                } else if (isForeignDrive) {
                    uploadBtn.attr('title', 'You cannot upload to a drive that you do not own.');
                }
            } else {
                console.log('✅ Upload enabled. Connected:', isNostrConnected, 'Foreign Drive:', isForeignDrive);
                body.removeClass('foreign-drive');
                uploadBtn.prop('disabled', false).css('opacity', '1').attr('title', 'Upload files to your drive');
            }

            // Apply foreign drive styling only if it's actually foreign and connected
            if (isForeignDrive && isNostrConnected) {
                body.addClass('foreign-drive');
            } else {
                body.removeClass('foreign-drive');
            }
        }
        // ---------------------------------------------------------------------------------


        function filterAndDisplayItems(filter, searchTerm = '') {
            filteredItems = allItems.filter(item => {
                // Filter by type
                const typeMatch = filter === 'all' || item.type === filter || item.itemType === filter;

                // Filter by search term
                const searchMatch = searchTerm === '' ||
                    item.name.toLowerCase().includes(searchTerm) ||
                    item.path.toLowerCase().includes(searchTerm);

                return typeMatch && searchMatch;
            });

            displayItems(filteredItems);
        }

        function displayItems(items) {
            if (!items || items.length === 0) {
                $('#files-container').html('<div class="error"><i class="fas fa-search"></i> No items found</div>');
                console.log("No items found or items array is empty. Displaying error message."); // Debug
                return;
            }

            // Déterminer si le drive est "étranger" et si l'utilisateur est connecté
            const isForeignDrive = currentManifest && currentManifest.owner_hex_pubkey && userPublicKey &&
                                   currentManifest.owner_hex_pubkey.toLowerCase() !== userPublicKey.toLowerCase();
            const isConnected = !!userPublicKey; // Convertir userPublicKey en booléen

            const itemsHtml = items.map((item, index) => {
                const icon = typeIcons[item.type] || typeIcons.file;

                let details = '';
                if (item.itemType === 'directory') {
                    details = `Files: ${item.files_count} | Subdirs: ${item.subdirs_count}`;
                } else {
                    details = `Size: ${item.formatted_size}`;

                    // Ajouter les métadonnées spécifiques
                    if (item.dimensions) {
                        details += `<br>📐 ${item.dimensions}`;
                    }
                    if (item.formatted_duration) {
                        details += `<br>⏱️ ${item.formatted_duration}`;
                    }
                    if (item.formatted_bitrate) {
                        details += `<br>🎵 ${item.formatted_bitrate}`;
                    }
                }

                let actionButtonHtml = '';
                let deleteButtonHtml = '';

                if (isConnected && !isForeignDrive) { // Connecté et c'est VOTRE Drive
                    actionButtonHtml = `
                        <button class="file-action-btn download-btn" data-index="${index}" title="Download File">
                            <i class="fas fa-download"></i>
                        </button>
                    `;
                    deleteButtonHtml = `
                        <button class="file-action-btn delete-btn" data-index="${index}" title="Delete File">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                    `;
                } else if (isConnected && isForeignDrive) { // Connecté à un Drive ÉTRANGER
                    actionButtonHtml = `
                        <button class="file-action-btn sync-btn" data-index="${index}" title="Sync File to Your Drive">
                            <i class="fas fa-sync-alt"></i>
                        </button>
                    `;
                    // Pas de bouton de suppression pour les Drives étrangers
                } else { // Non connecté du tout (seulement téléchargement possible)
                    actionButtonHtml = `
                        <button class="file-action-btn download-btn" data-index="${index}" title="Download File">
                            <i class="fas fa-download"></i>
                        </button>
                    `;
                    // Pas de bouton de suppression si non connecté
                }

                // Debugging pour voir le contenu de l'élément généré
                const generatedCardHtml = `
                    <div class="file-card" data-index="${index}" data-type="${item.type}">
                        <div class="file-icon">
                            <i class="${icon}" style="color: ${getTypeColor(item.type)}"></i>
                        </div>
                        <div class="file-type-badge type-${item.type}">
                            ${item.type.toUpperCase()}
                        </div>
                        <div class="file-name">${item.name}</div>
                        <div class="file-details">
                            ${details}<br>
                            Path: ${item.path}
                        </div>
                        ${actionButtonHtml}
                        ${deleteButtonHtml}
                    </div>
                `;
                return generatedCardHtml;
            }).join('');

            console.log("Total generated itemsHtml length:", itemsHtml.length); // Debug
            $('#files-container').html(itemsHtml);
            console.log("Files HTML injected into container."); // Debug

            $('.file-card').off('click').on('click', function(e) {
                // S'assurer qu'on ne clique pas sur un bouton d'action
                if ($(e.target).closest('.file-action-btn').length === 0) {
                    const index = parseInt($(this).data('index'));
                    openFilePreview(index);
                }
            });

            // Add click handlers for download/sync/delete (using .off() to prevent multiple bindings)
            $('.download-btn').off('click').on('click', function(e) {
                e.stopPropagation();
                const index = parseInt($(this).data('index'));
                downloadCurrentFile(index);
            });

            $('.sync-btn').off('click').on('click', function(e) {
                e.stopPropagation();
                const index = parseInt($(this).data('index'));
                syncFile(index);
            });

            $('.delete-btn').off('click').on('click', function(e) {
                e.stopPropagation();
                const index = parseInt($(this).data('index'));
                deleteCurrentFile(index);
            });
        }


        function getTypeColor(type) {
            const colors = {
                image: '#ff9800',
                video: '#3f51b5',
                audio: '#673ab7',
                html: '#4CAF50',
                javascript: '#ffc107',
                json: '#9c27b0',
                text: '#607d8b',
                document: '#e91e63',
                directory: '#ff5722',
                file: '#666'
            };
            return colors[type] || colors.file;
        }

        function openFilePreview(index) {
            currentFileIndex = index;
            const item = filteredItems[index];

            // Update file counter
            $('#modal-file-counter').text(`${index + 1}/${filteredItems.length}`);

            if (!item) return;

            $('#modal-filename').text(item.name);
            const modalContent = $('#fileModal .modal-content');
            const modalHeader = $('#fileModal .modal-header');
            const modalBody = $('#fileModal .modal-body');

            // Reset classes
            modalContent.removeClass('image-modal text-modal');
            modalHeader.removeClass('text-header');
            modalBody.removeClass('text-body');

            const ipfsUrl = buildIPFSUrl(item);
            if (!ipfsUrl) {
                modalBody.html('<div class="error"><i class="fas fa-exclamation-triangle"></i> File not available on IPFS yet</div>');
                $('#fileModal').fadeIn(300);
                $('#copyLinkBtn').hide(); // Hide copy button if no IPFS link
                return;
            } else {
                $('#copyLinkBtn').show(); // Show copy button if IPFS link is available
            }

            // Adapter l'affichage selon le type de fichier
            switch(item.type) {
                case 'image':
                    modalContent.addClass('image-modal');
                    modalBody.html(`<img src="${ipfsUrl}" alt="${item.name}" onload="this.style.opacity=1" style="opacity:0;transition:opacity 0.3s">`);
                    break;

                case 'video':
                    modalBody.html(`
                        <video controls autoplay style="max-width:100%;max-height:100%;">
                            <source src="${ipfsUrl}" type="video/mp4">
                            <source src="${ipfsUrl}" type="video/webm">
                            <source src="${ipfsUrl}" type="video/ogg">
                            Your browser does not support the video tag.
                        </video>
                    `);
                    break;

                case 'audio':
                    modalBody.html(`
                        <div style="text-align:center;padding:40px;">
                            <div style="margin-bottom:20px;">
                                <i class="fas fa-music" style="font-size:4em;color:#673ab7;margin-bottom:20px;"></i>
                                <h3 style="color:#e0e0e0;margin-bottom:10px;">${item.name}</h3>
                                ${item.formatted_duration ? `<p style="color:#aaa;">Duration: ${item.formatted_duration}</p>` : ''}
                                ${item.formatted_bitrate ? `<p style="color:#aaa;">Bitrate: ${item.formatted_bitrate}</p>` : ''}
                            </div>
                            <audio controls autoplay style="width:100%;max-width:600px;">
                                <source src="${ipfsUrl}" type="audio/mpeg">
                                <source src="${ipfsUrl}" type="audio/ogg">
                                <source src="${ipfsUrl}" type="audio/wav">
                                Your browser does not support the audio element.
                            </audio>
                        </div>
                    `);
                    break;

                case 'text':
                case 'html':
                case 'javascript':
                case 'json':
                    // Check if it's a markdown file
                    if (item.name.match(/\.(md|markdown)$/i)) {
                        modalContent.addClass('markdown-modal');
                        loadMarkdownEditor(ipfsUrl, item.name);
                    } else if (item.type === 'text' || item.name.match(/\.(txt|log|conf|ini|cfg|yaml|yml)$/i)) {
                        // Affichage texte optimisé
                        modalContent.addClass('text-modal');
                        modalHeader.addClass('text-header');
                        modalBody.addClass('text-body');

                        // Charger le contenu texte
                        $.ajax({
                            url: ipfsUrl,
                            dataType: 'text',
                            success: function(data) {
                                modalBody.html(`<pre style="margin:0;white-space:pre-wrap;word-wrap:break-word;font-size:14px;line-height:1.4;">${escapeHtml(data)}</pre>`);
                            },
                            error: function() {
                                modalBody.html('<div class="error">Unable to load text content</div>');
                            }
                        });
                    } else {
                        // Affichage iframe pour HTML/JS/JSON
                        modalBody.html(`<iframe src="${ipfsUrl}" style="width:100%;height:100%;border:none;"></iframe>`);
                    }
                    break;

                case 'directory':
                    modalBody.html(`<iframe src="${ipfsUrl}" style="width:100%;height:100%;border:none;"></iframe>`);
                    break;

                default:
                    // Iframe par défaut pour les autres types
                    modalBody.html(`<iframe src="${ipfsUrl}" style="width:100%;height:100%;border:none;"></iframe>`);
                    break;
            }

            $('#fileModal').fadeIn(300);
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function loadMarkdownEditor(url, filename) {
            const modalBody = $('#fileModal .modal-body');

            // Create markdown editor interface
            modalBody.html(`
                <div class="markdown-editor">
                    <div class="markdown-toolbar">
                        <div class="markdown-toolbar-group">
                            <button class="markdown-btn" id="preview-btn" data-mode="preview">
                                <i class="fas fa-eye"></i> Preview
                            </button>
                            <button class="markdown-btn" id="split-btn" data-mode="split">
                                <i class="fas fa-columns"></i> Split
                            </button>
                            <button class="markdown-btn active" id="edit-btn" data-mode="edit">
                                <i class="fas fa-edit"></i> Edit Only
                            </button>
                        </div>
                        <div class="markdown-toolbar-group">
                            <button class="markdown-btn" id="save-btn">
                                <i class="fas fa-save"></i> Save
                            </button>
                        </div>
                    </div>
                    <div class="markdown-content">
                        <div class="markdown-editor-pane">
                            <div class="pane-header">
                                <i class="fas fa-edit"></i> Editor
                            </div>
                            <textarea class="markdown-textarea" id="markdown-textarea" placeholder="Start typing your markdown..."></textarea>
                        </div>
                        <div class="markdown-preview-pane">
                            <div class="pane-header">
                                <i class="fas fa-eye"></i> Preview
                            </div>
                            <div class="markdown-preview" id="markdown-preview"></div>
                        </div>
                    </div>
                    <div class="markdown-status">
                        <span>File: ${filename}</span>
                        <span class="save-status" id="save-status">Ready</span>
                    </div>
                </div>
            `);

            // Load the markdown content
            $.ajax({
                url: url,
                dataType: 'text',
                success: function(data) {
                    $('#markdown-textarea').val(data);
                    updateMarkdownPreview();
                    initMarkdownEditor();
                },
                error: function() {
                    $('#markdown-textarea').val('# Error\n\nUnable to load markdown content.');
                    updateMarkdownPreview();
                    initMarkdownEditor();
                }
            });
        }

        function initMarkdownEditor() {
            // Setup real-time preview update
            $('#markdown-textarea').on('input', function() {
                updateMarkdownPreview();
            });

            // Setup toolbar buttons
            $('.markdown-btn[data-mode]').click(function() {
                const mode = $(this).data('mode');
                setMarkdownViewMode(mode);
                $('.markdown-btn[data-mode]').removeClass('active');
                $(this).addClass('active');
            });

            // Setup save button
            $('#save-btn').click(function() {
                saveMarkdownFile();
            });

            // Add keyboard shortcuts
            $('#markdown-textarea').keydown(function(e) {
                if (e.ctrlKey && e.key === 's') {
                    e.preventDefault();
                    saveMarkdownFile();
                }
            });

            // Démarrer en mode édition plein écran
            setMarkdownViewMode('edit');
        }

        function updateMarkdownPreview() {
            const markdownText = $('#markdown-textarea').val();
            try {
                const htmlContent = marked.parse(markdownText);
                $('#markdown-preview').html(htmlContent);
            } catch (error) {
                $('#markdown-preview').html('<div style="color: red;">Error rendering markdown: ' + error.message + '</div>');
            }
        }

        function setMarkdownViewMode(mode) {
            const editorPane = $('.markdown-editor-pane');
            const previewPane = $('.markdown-preview-pane');

            switch(mode) {
                case 'preview':
                    editorPane.addClass('hidden');
                    previewPane.removeClass('hidden').removeClass('fullwidth');
                    break;
                case 'edit':
                    previewPane.addClass('hidden');
                    editorPane.removeClass('hidden').addClass('fullwidth');
                    break;
                case 'split':
                default:
                    editorPane.removeClass('hidden').removeClass('fullwidth');
                    previewPane.removeClass('hidden').removeClass('fullwidth');
                    break;
            }
        }

        function saveMarkdownFile() {
            const content = $('#markdown-textarea').val();
            const filename = filteredItems[currentFileIndex].name;
            const saveStatus = $('#save-status');

            saveStatus.removeClass('error').addClass('saving').text('Saving...');

            try {
                // Créer un blob avec le contenu markdown
                const blob = new Blob([content], { type: 'text/markdown' });
                const file = new File([blob], filename, { type: 'text/markdown' });

                console.log('Created markdown file for upload:', filename);

                // Utiliser la fonction uploadFiles existante
                uploadMarkdownFile([file], saveStatus);

            } catch (error) {
                console.error('Error preparing markdown file:', error);
                saveStatus.removeClass('saving').addClass('error').text('Failed to prepare file');
                setTimeout(() => {
                    saveStatus.removeClass('error').text('Ready');
                }, 5000);
            }
        }

        function uploadMarkdownFile(files, saveStatus) {
            const apiBaseUrl = getAPIBaseUrl();

            const file = files[0];
            const formData = new FormData();
            formData.append('file', file);

            // Ajouter la npub si connecté à NOSTR
            console.log('DEBUG markdown upload - isNostrConnected:', isNostrConnected, 'userPublicKey:', userPublicKey ? 'présente' : 'absente');

            if ((isNostrConnected && userPublicKey) || userPublicKey) {
                // Utiliser la clé si elle est disponible, même si isNostrConnected peut être faux
                if (userPublicKey.length === 64) {
                    console.log('Ajout de la clé publique au markdown save:', userPublicKey);
                    formData.append('npub', userPublicKey);
                } else if (userPublicKey.startsWith('npub1')) {
                    console.log('Ajout de la npub au markdown save:', userPublicKey);
                    formData.append('npub', userPublicKey);
                }
            } else {
                console.log('Aucune clé publique NOSTR disponible pour cet upload markdown');
            }

            console.log('Uploading markdown file:', file.name);
            $.ajax({
                url: `${apiBaseUrl}/api/upload`,
                type: 'POST',
                data: formData,
                processData: false,
                contentType: false,
                success: function(response) {
                    console.log('Markdown upload success:', response);
                    saveStatus.removeClass('saving').addClass('success').text('Saved successfully');

                    // Afficher le chemin de sauvegarde
                    if (response.file_path) {
                        console.log('Markdown file saved to:', response.file_path);
                    }

                    // Si un nouveau CID est disponible, rediriger directement
                    if (response.new_cid) {
                        saveStatus.text('Saved! Redirecting...');
                        redirectToNewCid(response.new_cid);
                    } else {
                        setTimeout(() => {
                            saveStatus.removeClass('success').text('Ready');
                        }, 3000);
                    }
                },
                error: function(xhr, status, error) {
                    console.error('Markdown upload error:', error, xhr.responseJSON);

                    let errorMessage = 'Save failed';
                    if (xhr.responseJSON && xhr.responseJSON.detail) {
                        errorMessage = xhr.responseJSON.detail;
                    }

                    saveStatus.removeClass('saving').addClass('error').text(errorMessage);
                    setTimeout(() => {
                        saveStatus.removeClass('error').text('Ready');
                    }, 5000);
                }
            });
        }
        function getAPIBaseUrl() {
            // Extract the hostname (e.g., "https://ipfs.domain.tld" or "http://127.0.0.1:8080" or "http://ipfs.localhost:8080")
            const currentURL = new URL(window.location.href);
            const hostname = currentURL.hostname;
            const protocol = currentURL.protocol;

            // Second bloc (uPlanetAPI_URL)
            let uPort = currentURL.port;  // Nouvelle variable pour ce bloc
            if (uPort === "8080") {
                uPort = "54321";
            }
            let uHost = hostname.replace("ipfs", "u");
            let uPlanetStation = protocol + "//" + uHost + (uPort ? ":" + uPort : "");

            console.log('API Base URL detected:', uPlanetStation);
            return uPlanetStation;
        }

        function navigateFile(direction) {
            const newIndex = currentFileIndex + direction;
            if (newIndex >= 0 && newIndex < filteredItems.length) {
                openFilePreview(newIndex);
            }
        }

        function closeModal() {
            $('#fileModal').fadeOut(300);
            const modalBody = $('#fileModal .modal-body');
            const modalContent = $('#fileModal .modal-content');
            const modalHeader = $('#fileModal .modal-header');

            // Reset content and classes
            modalBody.html('');
            modalContent.removeClass('image-modal text-modal markdown-modal');
            modalHeader.removeClass('text-header');
            modalBody.removeClass('text-body');
        }

        // NEW: Function to copy IPFS link to clipboard
        function copyIpfsLink() {
            const item = filteredItems[currentFileIndex];
            if (!item) return;

            const ipfsUrl = buildIPFSUrl(item);
            if (!ipfsUrl) {
                // No alert needed, button is hidden if no link, or user will see no change.
                return;
            }

            navigator.clipboard.writeText(ipfsUrl).then(() => {
                const originalText = $('#copyLinkBtn').html();
                $('#copyLinkBtn').html('<i class="fas fa-check"></i> Copied!');
                setTimeout(() => {
                    $('#copyLinkBtn').html(originalText);
                }, 1500);
                console.log('IPFS link copied:', ipfsUrl);
            }).catch(err => {
                console.error('Failed to copy IPFS link:', err);
                // No alert, just console error for user experience
            });
        }

        function syncFile(index) {
            const item = filteredItems[index];
            if (!item) return;

            const button = $(`.sync-btn[data-index="${index}"]`);
            const originalContent = button.html(); // Save original content here

            if (!userPublicKey) {
                console.log('❌ User not connected to Nostr. Cannot sync file.');
                button.html('<i class="fas fa-exclamation-triangle"></i> No Auth'); // Temporary message
                setTimeout(() => {
                    button.html(originalContent).prop('disabled', false); // Restore button
                }, 2000);
                return;
            }

            const ipfsLink = buildIPFSUrl(item); // Ceci donne l'URL complète comme /http://gateway/ipfs/QmHASH/filename.ext
            if (!ipfsLink) {
                console.log('Fichier non disponible sur IPFS pour la synchronisation.');
                button.html('<i class="fas fa-exclamation-triangle"></i> No IPFS'); // Temporary message
                setTimeout(() => {
                    button.html(originalContent).prop('disabled', false); // Restore button
                }, 2000);
                return;
            }

            // Nous avons besoin de la partie "QmHASH/filename.ext" pour l'API
            const parts = ipfsLink.split('/ipfs/');
            const relativeIpfsLink = parts.length > 1 ? parts[1] : '';

            if (!relativeIpfsLink) {
                console.log('Impossible de déterminer le lien IPFS pour la synchronisation.');
                button.html('<i class="fas fa-exclamation-triangle"></i> Link Error'); // Temporary message
                setTimeout(() => {
                    button.html(originalContent).prop('disabled', false); // Restore button
                }, 2000);
                return;
            }

            console.log('Tentative de synchronisation du fichier:', item.name, 'depuis le lien IPFS:', relativeIpfsLink, 'vers le drive de l\'utilisateur connecté.');

            const apiBaseUrl = getAPIBaseUrl();
            const syncData = {
                ipfs_link: relativeIpfsLink,
                npub: userPublicKey
            };

            // Fournir un feedback visuel
            button.html('<i class="fas fa-spinner fa-spin"></i> Syncing...').prop('disabled', true);

            $.ajax({
                url: `${apiBaseUrl}/api/upload_from_drive`,
                type: 'POST',
                data: JSON.stringify(syncData),
                contentType: 'application/json',
                success: function(response) {
                    console.log('Synchronisation réussie:', response);
                    if (response.new_cid) {
                        button.html('<i class="fas fa-check"></i> Synced! Redirecting...'); // Temporary message before redirect
                        redirectToNewCid(response.new_cid);
                    } else {
                        button.html('<i class="fas fa-check"></i> Synced!'); // Temporary success message
                        setTimeout(() => {
                            button.html(originalContent).prop('disabled', false); // Restore button
                            loadManifest(); // Recharger le manifest si pas de redirection
                        }, 2000);
                    }
                },
                error: function(xhr, status, error) {
                    console.error('Erreur de synchronisation:', error, xhr.responseJSON);
                    let errorMessage = 'Sync failed';
                    if (xhr.responseJSON && xhr.responseJSON.detail) {
                        errorMessage = xhr.responseJSON.detail;
                    }
                    button.html('<i class="fas fa-times"></i> Failed!').prop('disabled', false); // Temporary error message
                    setTimeout(() => {
                        button.html(originalContent); // Restore button
                    }, 3000);
                }
            });
        }
        // ------------------------------------

        function downloadCurrentFile(index) {
            const item = filteredItems[index !== undefined ? index : currentFileIndex];
            if (!item) return;

            const ipfsUrl = buildIPFSUrl(item);
            if (!ipfsUrl) {
                const statusSpan = $('#modal-temp-status');
                const originalContent = statusSpan.html(); // Save original content
                statusSpan.css('color', '#ff6b6b').text('❌ Not published to IPFS yet.');
                setTimeout(() => {
                    statusSpan.text(''); // Clear message
                }, 3000);
                console.log('File not available for download yet - not published to IPFS:', item.name);
                return;
            }

            // Create a temporary link element to trigger download
            const link = document.createElement('a');
            link.href = ipfsUrl;
            link.download = item.name;
            link.style.display = 'none';

            // Add to DOM, click, and remove
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            console.log('Downloading:', item.name, 'from', ipfsUrl);
        }

        function displayDirectoryInfo(manifest) {
            const generatedDate = new Date(manifest.generated_at).toLocaleString();
            const currentHash = getCurrentIPFSHash();
            const hashDisplay = currentHash ?
                `<code style="font-size:0.8em;"><i class="fas fa-fingerprint"></i> ${currentHash}</code>` :
                '<span style="color: #ffa500; font-size:0.8em;"><i class="fas fa-clock"></i> Not published to IPFS</span>';

            // Add Nostr Connected Key display
            let connectedKeyDisplay = '';
            if (userPublicKey) {
                connectedKeyDisplay = `<div><strong><i class="fas fa-key"></i> Connected Key:</strong><br><code>${userPublicKey.substring(0, 10)}...${userPublicKey.substring(userPublicKey.length - 10)}</code></div>`;
            } else {
                connectedKeyDisplay = `<div><strong><i class="fas fa-key"></i> Connected Key:</strong><br><span style="color: #ffa500; font-size:0.8em;">Not Connected</span></div>`;
            }

            // NEW: Add Owner Email and Origin IPFS Gateway display
            const ownerEmailDisplay = manifest.owner_email ?
                `<div><strong><i class="fas fa-user"></i> Owner:</strong><br><code>${manifest.owner_email}</code></div>` : '';
            const originGatewayDisplay = manifest.my_ipfs_gateway ?
                `<div><strong><i class="fas fa-link"></i> Origin Gateway:</strong><br><code>${manifest.my_ipfs_gateway}</code></div>` : '';

            const html = `
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 8px; font-size: 0.85em;">
                    <div><strong><i class="fas fa-fingerprint"></i> Hash:</strong><br>${hashDisplay}</div>
                    <div><strong><i class="fas fa-server"></i> Gateway:</strong><br><code>${currentGateway}</code></div>
                    <div><strong><i class="fas fa-folder"></i> Dirs:</strong> ${manifest.total_directories || 0}</div>
                    <div><strong><i class="fas fa-file"></i> Files:</strong> ${manifest.total_files}</div>
                    <div><strong><i class="fas fa-weight-hanging"></i> Size:</strong> ${manifest.formatted_total_size}</div>
                    <div><strong><i class="fas fa-clock"></i> Generated:</strong><br><span style="font-size:0.8em;">${generatedDate}</span></div>
                    ${ownerEmailDisplay} <!-- NEW: Owner Email -->
                    ${originGatewayDisplay} <!-- NEW: Origin IPFS Gateway -->
                    ${connectedKeyDisplay}
                </div>
            `;
            $('#info-content').html(html);
        }

        // Upload modal functions
        function openUploadModal() {
            $('#uploadModal').fadeIn(300);
            resetUploadForm();
        }

        function closeUploadModal() {
            $('#uploadModal').fadeOut(300);
            resetUploadForm();
        }

        function resetUploadForm() {
            $('#file-input').val('');
            $('#upload-progress').hide();
            $('#upload-results').hide();
            $('#upload-zone').show();
            $('#progress-fill').css('width', '0%');
            $('#progress-text').text('Uploading...');
        }

        function uploadFiles(files) {
            console.log('Starting upload of', files.length, 'files');

            // Hide upload zone and show progress
            $('#upload-zone').hide();
            $('#upload-progress').show();
            $('#upload-results').empty().show();

            const apiBaseUrl = getAPIBaseUrl();
            let uploadedCount = 0;
            let failedCount = 0;
            let lastNewCid = null;

            // Upload files one by one to show individual progress
            uploadNextFile(0);

            function uploadNextFile(index) {
                if (index >= files.length) {
                    // All files processed
                    completeUpload();
                    return;
                }

                const file = files[index];
                const formData = new FormData();
                formData.append('file', file);

                // Ajouter la npub si connecté à NOSTR
                console.log('DEBUG upload - isNostrConnected:', isNostrConnected, 'userPublicKey:', userPublicKey ? 'présente' : 'absente');

                if ((isNostrConnected && userPublicKey) || userPublicKey) {
                    // Utiliser la clé si elle est disponible, même si isNostrConnected peut être faux
                    let npub = userPublicKey;
                    if (userPublicKey.length === 64) {
                        // Si c'est une clé hex, on la convertit (nécessiterait NostrTools.nip19.npubEncode)
                        // Pour l'instant on utilise directement la clé
                        console.log('Ajout de la clé publique à l\'upload:', userPublicKey);
                        formData.append('npub', userPublicKey);
                    } else if (userPublicKey.startsWith('npub1')) {
                        console.log('Ajout de la npub à l\'upload:', userPublicKey);
                        formData.append('npub', userPublicKey);
                    }
                } else {
                    console.log('Aucune clé publique NOSTR disponible pour cet upload');
                }

                // Update progress
                const progress = ((index + 1) / files.length) * 100;
                $('#progress-fill').css('width', progress + '%');
                $('#progress-text').text(`Uploading ${file.name} (${index + 1}/${files.length})`);

                console.log(`Uploading file ${index + 1}/${files.length}: ${file.name}`);

                $.ajax({
                    url: `${apiBaseUrl}/api/upload`,
                    type: 'POST',
                    data: formData,
                    processData: false,
                    contentType: false,
                    success: function(response) {
                        console.log('Upload success:', response);
                        uploadedCount++;

                        if (response.new_cid) {
                            lastNewCid = response.new_cid;
                        }

                        // Add success result
                        $('#upload-results').append(`
                            <div class="upload-result-item">
                                <div class="upload-result-file">
                                    <strong>${file.name}</strong><br>
                                    <small>→ ${response.target_directory}/${file.name}</small>
                                </div>
                                <div class="upload-result-status success">✅ Success</div>
                            </div>
                        `);

                        // Upload next file
                        uploadNextFile(index + 1);
                    },
                    error: function(xhr, status, error) {
                        console.error('Upload error:', error, xhr.responseJSON);
                        failedCount++;

                        let errorMessage = 'Upload failed';
                        if (xhr.responseJSON && xhr.responseJSON.detail) {
                            errorMessage = xhr.responseJSON.detail;
                        }

                        // Add error result
                        $('#upload-results').append(`
                            <div class="upload-result-item error">
                                <div class="upload-result-file">
                                    <strong>${file.name}</strong><br>
                                    <small>${errorMessage}</small>
                                </div>
                                <div class="upload-result-status error">Failed</div>
                            </div>
                        `);

                        // Upload next file
                        uploadNextFile(index + 1);
                    }
                });
            }

            function completeUpload() {
                $('#progress-fill').css('width', '100%');
                $('#progress-text').text(`Upload complete: ${uploadedCount} success, ${failedCount} failed`);

                if (lastNewCid && uploadedCount > 0) {
                    // Show redirect notice
                    $('#upload-results').append(`
                        <div class="redirect-notice">
                            <i class="fas fa-rocket"></i> Upload successful!
                            <br>New IPFS structure generated.
                            <div class="redirect-countdown" id="redirect-countdown">
                                Redirecting to new content in 3 seconds...
                            </div>
                        </div>
                    `);

                    // Countdown and redirect
                    let countdown = 3;
                    const countdownInterval = setInterval(() => {
                        countdown--;
                        if (countdown > 0) {
                            $('#redirect-countdown').text(`Redirecting to new content in ${countdown} seconds...`);
                        } else {
                            clearInterval(countdownInterval);
                            redirectToNewCid(lastNewCid);
                        }
                    }, 1000);
                }
            }
        }

        function redirectToNewCid(newCid) {
            console.log('Redirecting to new CID:', newCid);

            // Build new URL with the new CID
            const currentURL = new URL(window.location.href);
            const newURL = `${currentURL.protocol}//${currentURL.host}/ipfs/${newCid}/`;

            console.log('Redirecting to:', newURL);

            // Close modal and redirect
            closeUploadModal();
            window.location.href = newURL;
        }

        function deleteCurrentFile(index) {
            const item = filteredItems[index !== undefined ? index : currentFileIndex];
            if (!item) return;

            const originalButton = $(`.delete-btn[data-index="${index}"]`);
            const originalContent = originalButton.html(); // Save original content

            // Vérifier l'authentification NOSTR
            if (!userPublicKey) {
                console.log('❌ Authentification NOSTR requise pour supprimer un fichier.');
                originalButton.html('<i class="fas fa-exclamation-triangle"></i> No Auth'); // Temporary message
                setTimeout(() => {
                    originalButton.html(originalContent).prop('disabled', false); // Restore button
                }, 2000);
                return;
            }

            // Demander confirmation avec détails (on conserve le confirm)
            const confirmMessage = `⚠️ ATTENTION - Suppression définitive ⚠️\n\n` +
                                 `Fichier : ${item.name}\n` +
                                 `Type : ${item.type}\n` +
                                 `Chemin : ${item.path}\n\n` +
                                 `Cette action est IRRÉVERSIBLE.\n` +
                                 `Êtes-vous sûr de vouloir supprimer ce fichier ?`;

            if (!confirm(confirmMessage)) {
                console.log('Suppression annulée par l\'utilisateur');
                return;
            }

            console.log('DEBUG delete - isNostrConnected:', isNostrConnected, 'userPublicKey:', userPublicKey ? 'présente' : 'absente');
            console.log('Suppression du fichier:', item.name, 'chemin:', item.path);

            const apiBaseUrl = getAPIBaseUrl();

            // Préparer les données de suppression
            const deleteData = {
                file_path: item.path,
                npub: userPublicKey
            };

            console.log('Envoi de la requête de suppression:', deleteData);

            // Afficher un indicateur de progression sur le bouton
            originalButton.html('<i class="fas fa-spinner fa-spin"></i>').prop('disabled', true);

            $.ajax({
                url: `${apiBaseUrl}/api/delete`,
                type: 'POST',
                data: JSON.stringify(deleteData),
                contentType: 'application/json',
                success: function(response) {
                    console.log('Suppression réussie:', response);
                    originalButton.html('<i class="fas fa-check"></i> Deleted!'); // Temporary success message

                    // Rediriger vers le nouveau CID ou recharger la page
                    if (response.new_cid) {
                        redirectToNewCid(response.new_cid);
                    } else {
                        // Recharger la page si pas de nouveau CID
                        setTimeout(() => {
                            window.location.reload(); // Reload after a short delay to show message
                        }, 1000);
                    }
                },
                error: function(xhr, status, error) {
                    console.error('Erreur de suppression:', error, xhr.responseJSON);

                    let errorMessage = 'Deletion failed';
                    if (xhr.responseJSON && xhr.responseJSON.detail) {
                        errorMessage = xhr.responseJSON.detail;
                    }

                    originalButton.html('<i class="fas fa-times"></i> Failed!').prop('disabled', false); // Temporary error message
                    setTimeout(() => {
                        originalButton.html(originalContent); // Restore button
                    }, 3000);
                }
            });
        }
    </script>
</body>
</html>
HTML_EOF

log_message "✅ _index.html généré"

# Créer un index.html de redirection simple
log_message "🔄 Vérification du fichier index.html..."

# Marqueur pour identifier notre fichier
MARKER="<!-- UPLANET_IPFS_GENERATOR -->"
CREATE_INDEX=true

# Vérifier si index.html existe déjà
if [ -f "$SOURCE_DIR/index.html" ]; then
    log_message "   📄 Fichier index.html existant trouvé"

    # Lire les premières lignes pour détecter notre marqueur
    if grep -q "$MARKER" "$SOURCE_DIR/index.html" 2>/dev/null; then
        log_message "   ✅ Marqueur UPlanet détecté - c'est notre fichier de redirection"
        log_message "   ↻ Mise à jour de l'index.html existant (généré par ce script)"
    else
        log_message "   ⚠️  index.html existe mais n'a pas notre marqueur"
        log_message "   📖 Aperçu du contenu actuel:"
        log_message "$(head -5 "$SOURCE_DIR/index.html" 2>/dev/null | sed 's/^/      /')"
        log_message "   📄 Création de _redirect.html à la place"
        log_message "   💡 Pour utiliser notre redirection, renommez manuellement :"
        log_message "      mv index.html index_original.html"
        log_message "      mv _redirect.html index.html"

        # Créer _redirect.html au lieu d'index.html
        cat > "$SOURCE_DIR/_redirect.html" << REDIRECT_EOF
<!DOCTYPE html>
<html>
$MARKER
<head>
    <meta charset="utf-8">
    <title>UPlanet IPFS Explorer</title>
    <script>
        // Redirection immédiate vers _index.html
        window.location.replace('./_index.html');
    </script>
</head>
<body>
    <p>If you are not redirected automatically, <a href="_index.html">click here</a>.</p>
</body>
</html>
REDIRECT_EOF
        log_message "✅ _redirect.html créé (sauvegarde de votre index.html préservée)"
        CREATE_INDEX=false
    fi
else
    log_message "   📄 Aucun fichier index.html existant - création d'un nouveau"
fi

# Créer ou remplacer index.html avec notre version seulement si nécessaire
if [ "$CREATE_INDEX" = true ]; then
    log_message "   🔧 Création du fichier index.html de redirection..."
    cat > "$SOURCE_DIR/index.html" << REDIRECT_EOF
<!DOCTYPE html>
<html>
$MARKER
<head>
    <meta charset="utf-8">
    <title>UPlanet IPFS Explorer</title>
    <script>
        // Redirection immédiate vers _index.html
        window.location.replace('./_index.html');
    </script>
</head>
<body>
    <p>If you are not redirected automatically, <a href="_index.html">click here</a>.</p>
</body>
</html>
REDIRECT_EOF

    log_message "✅ index.html de redirection créé avec marqueur UPlanet"
fi

# Fonction pour obtenir le CID actuel du répertoire depuis IPFS
get_current_directory_cid() {
    # Essayer d'obtenir le CID du répertoire actuel s'il est déjà dans IPFS
    # Utiliser cd pour éviter le wrapping avec le nom du répertoire
    local current_cid=$(cd "$SOURCE_DIR" && ipfs add -rw --only-hash ./* 2>/dev/null | tail -1 | awk '{print $2}')
    echo "$current_cid"
}

# Ajouter tout le répertoire à IPFS pour obtenir le CID final
log_message ""

# Optimisation: si aucun fichier n'a changé ET aucun fichier supprimé, pas besoin de refaire l'ajout IPFS
if [ "$updated_count" -eq 0 ] && [ "$deleted_count" -eq 0 ]; then
    log_message "💾 Aucun fichier modifié ou supprimé - récupération du CID existant..."

    # Utiliser le CID sauvegardé avant la régénération du manifest
    if [ -n "$EXISTING_FINAL_CID" ]; then
        log_message "✅ CID récupéré depuis le manifest précédent: $EXISTING_FINAL_CID"
        update_final_cid_in_manifest "$EXISTING_FINAL_CID"
        echo "$EXISTING_FINAL_CID"  # Sortie principale : le CID final
    else
        log_message "⚠️  Aucun CID sauvegardé - calcul du CID..."
        FINAL_CID=$(get_current_directory_cid)

        if [ -n "$FINAL_CID" ]; then
            log_message "✅ CID calculé: $FINAL_CID"
            update_final_cid_in_manifest "$FINAL_CID"
            echo "$FINAL_CID"  # Sortie principale : le CID final
        else
            log_message "⚠️  Impossible de calculer le CID - ajout IPFS forcé..."
            log_message "🔗 Ajout final du répertoire complet à IPFS..."
            FINAL_CID=$(cd "$SOURCE_DIR" && ipfs add -rw ./* 2>/dev/null | tail -1 | awk '{print $2}')

            if [ -n "$FINAL_CID" ]; then
                update_final_cid_in_manifest "$FINAL_CID"
                echo "$FINAL_CID"  # Sortie principale : le CID final
                log_message "✅ CID final de l'application: $FINAL_CID"
            else
                error_message "❌ Erreur lors de l'ajout final à IPFS"
                exit 1
            fi
        fi
    fi
else
    changes_description=""
    if [ "$updated_count" -gt 0 ] && [ "$deleted_count" -gt 0 ]; then
        changes_description="$updated_count modifié(s), $deleted_count supprimé(s)"
    elif [ "$updated_count" -gt 0 ]; then
        changes_description="$updated_count fichier(s) modifié(s)"
    elif [ "$deleted_count" -gt 0 ]; then
        changes_description="$deleted_count fichier(s) supprimé(s)"
    fi

    log_message "🔗 Ajout final du répertoire complet à IPFS ($changes_description)..."
    FINAL_CID=$(cd "$SOURCE_DIR" && ipfs add -rw ./* 2>/dev/null | tail -1 | awk '{print $2}')

    if [ -n "$FINAL_CID" ]; then
        update_final_cid_in_manifest "$FINAL_CID"
        echo "$FINAL_CID"  # Sortie principale : le CID final
        log_message "✅ CID final de l'application: $FINAL_CID"
    else
        error_message "❌ Erreur lors de l'ajout final à IPFS"
        exit 1
    fi
fi

log_message ""
log_message "🎉 Structure IPFS générée avec succès!"
log_message ""
log_message "📋 Fichiers créés:"
log_message "  - manifest.json (structure optimisée avec liens IPFS individuels)"
log_message "  - _index.html (interface d'exploration moderne avec éditeur Markdown)"
log_message "  - index.html (redirection vers _index.html)"
log_message ""
log_message "🔧 Nouvelles fonctionnalités ajoutées:"
log_message "  - ⚡ Mise à jour incrémentale (seuls les fichiers modifiés sont re-ajoutés à IPFS)"
log_message "  - 🔗 Liens IPFS individuels pour chaque fichier"
log_message "  - 📝 Éditeur Markdown intégré avec aperçu en temps réel"
log_message "  - 📥 Boutons de téléchargement sur les cartes et dans les modals"
log_message "  - 🌙 Toggle thème sombre/clair avec sauvegarde"
log_message "  - 📱 Interface optimisée pour tous types d'écrans"
log_message "  - 🚀 Navigation directe vers UPlanet, Scanner, NOSTR, et Coracle"
log_message ""
log_message "📊 Statistiques de cette exécution:"
log_message "  - $updated_count fichier(s) ajouté(s) ou mis à jour dans IPFS"
log_message "  - $cached_count fichier(s) inchangé(s) (utilisent le cache)"
log_message "  - $deleted_count fichier(s) supprimé(s) du manifest"
log_message ""
log_message "🌐 Accès à l'application:"
log_message "  - URL IPFS: http://127.0.0.1:8080/ipfs/$FINAL_CID/"
log_message "  - CID: $FINAL_CID"
log_message ""
log_message "💡 Conseil: Réexécutez ce script après modification de fichiers pour une mise à jour incrémentale automatique!"
