#!/bin/bash

# Script pour générer la structure IPFS d'une application Geo-RPG
# Usage: ./generate_ipfs_RPG.sh [repertoire_source]

set -e

# Fonction d'aide
show_help() {
    cat << 'HELP_EOF'
🌐 UPlanet Geo-RPG / World-Builder Generator

USAGE:
    ./generate_ipfs_RPG.sh [OPTIONS] DIRECTORY

ARGUMENTS:
    DIRECTORY    Répertoire source (OBLIGATOIRE)

OPTIONS:
    -h, --help   Afficher cette aide
    --log        Activer le logging détaillé (sinon sortie silencieuse)

DESCRIPTION:
    Génère une interface web IPFS pour un jeu de rôle géographique collaboratif (Geo-RPG).
    Inclut une carte, des infos de lieu, un profil joueur, un graphique social et un chat IA.

WORKFLOW:
    1. ./generate_ipfs_RPG.sh [--log] DIRECTORY
    2. Le script génère _index.html et d'autres fichiers pour l'application RPG.
    3. Il retourne le CID final de l'application IPFS.
    4. Accéder à http://127.0.0.1:8080/ipfs/[CID]/

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
if [[ ! -d "$SOURCE_DIR/Games" || ! -d "$SOURCE_DIR/Maps" || ! -d "$SOURCE_DIR/Players" || ! -d "$SOURCE_DIR/NPCs" ]]; then
    #ajouter les répertoires nécessaires pour le RPG
    mkdir -p "$SOURCE_DIR/Games"
    mkdir -p "$SOURCE_DIR/Maps"
    mkdir -p "$SOURCE_DIR/Players"
    mkdir -p "$SOURCE_DIR/NPCs"
    mkdir -p "$SOURCE_DIR/Items"
    mkdir -p "$SOURCE_DIR/Quests"
    mkdir -p "$SOURCE_DIR/Lore"
    # ecire un coucou dans le fichier README.md
    if [ ! -f "$SOURCE_DIR/Games/README.md" ]; then
        touch "$SOURCE_DIR/Games/README.md"
        echo "# Bienvenue dans votre UPlanet Geo-RPG !" >> "$SOURCE_DIR/Games/README.md"
        echo "" >> "$SOURCE_DIR/Games/README.md"
        echo "Ce répertoire est la base de votre monde de jeu. Vous pouvez y organiser :" >> "$SOURCE_DIR/Games/README.md"
        echo "" >> "$SOURCE_DIR/Games/README.md"
        echo "- **Maps/** : Les fichiers de cartes (images, json de tuiles, etc.)" >> "$SOURCE_DIR/Games/README.md"
        echo "- **Players/** : Les profils de joueurs (attention, les profils Nostr sont gérés via votre npub)" >> "$SOURCE_DIR/Games/README.md"
        echo "- **NPCs/** : Les données des personnages non-joueurs" >> "$SOURCE_DIR/Games/README.md"
        echo "- **Items/** : Les définitions des objets" >> "$SOURCE_DIR/Games/README.md"
        echo "- **Quests/** : Les descriptions de quêtes" >> "$SOURCE_DIR/Games/README.md"
        echo "- **Lore/** : Les éléments de l'histoire et du lore du monde" >> "$SOURCE_DIR/Games/README.md"
        echo "" >> "$SOURCE_DIR/Games/README.md"
        echo "Le script `generate_ipfs_RPG.sh` va indexer ces fichiers et générer une interface IPFS pour les explorer." >> "$SOURCE_DIR/Games/README.md"
    fi
fi

log_message "🚀 Génération de la structure IPFS pour le Geo-RPG..."
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
        pdf|doc|docx|xls|xlsx|ppt|pptx) echo "document" ;;
        mp3|wav|ogg|m4a|flac|aac|wma) echo "audio" ;;
        mp4|avi|mov|wmv|flv|webm|mkv|m4v) echo "video" ;;
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
    local deleted_files_list="/tmp/deleted_files_$$"

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
           [[ "$basename_file" == generate_ipfs_RPG.sh ]] || \
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
ORIGIN_IPFS_GATEWAY="$myIPFS"
##############################################################
## USED in ${HOME}/.zen/game/nostr/${OWNER_EMAIL}/APP/uWORLD
OWNER_PLAYER_DIR=$(dirname "$(dirname "$SOURCE_DIR")")
OWNER_EMAIL=$(basename "$OWNER_PLAYER_DIR")
OWNER_HEX_FILE="${HOME}/.zen/game/nostr/${OWNER_EMAIL}/HEX"
ENV_FILE="${HOME}/.zen/Astroport.ONE/.env"

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
    elif [[ "$basename_file" == generate_ipfs_RPG.sh ]]; then
        log_message "   ⏭️  Ignoré: script generate_ipfs_RPG.sh"
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

log_message "🎨 Génération de _index.html pour le Geo-RPG..."

cat > "$SOURCE_DIR/_index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <link rel="icon" type="image/x-icon" href="/ipfs/QmPPELF7HhM9BXtAUMnNUSNsrRJgsFzLNCQ5pFhWKr9ogk/favicon.galaxy.ico">
    <title>🌐 UPlanet Geo-RPG / World-Builder</title>
    <script src="/ipfs/QmQLQ5WdCEc7mpKw5rhUujUU1URKweei4Bb4esyVNd9Atx/G1PalPay_fichiers/jquery-3.6.3.min.js"></script>
    <script src="/ipfs/Qmab3sg8QLrKYw7wQGmBujEdxG3zTNsMQcsG9zoBdToAhQ/marked.min.js.js"></script>
    <script src="/ipfs/QmXEmaPRUaGcvhuyeG99mHHNyP43nn8GtNeuDok8jdpG4a/nostr.bundle.js"></script>
    <link rel="stylesheet" href="/ipfs/QmVAXbUyzyaZP4yVzN6WnkEhw7LFw3TY1bmMCTSKbHgYpR/css/all.min.css">
    <!-- Leaflet CSS -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
          integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
          crossorigin=""/>
    <!-- Leaflet JavaScript -->
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
            integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
            crossorigin=""></script>
    <style>
        /* General Styles */
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 50%, #16213e 100%);
            color: #e0e0e0;
            min-height: 100vh;
            overflow: hidden; /* Prevent body scroll */
            font-size: 14px; /* Base font size */
            display: flex;
            flex-direction: column;
        }
        * { box-sizing: border-box; }

        .header {
            background: linear-gradient(90deg, #ff6b6b, #ffa500, #ffff00, #00ff00, #00ffff, #0000ff, #ff00ff);
            padding: 1px;
            flex-shrink: 0;
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
        .main-content {
            display: flex;
            flex: 1;
            overflow: hidden; /* Allow scrolling within panels */
            padding: 10px;
            gap: 10px;
        }
        .panel {
            background: rgba(42, 42, 42, 0.9);
            border-radius: 10px;
            padding: 12px; /* Reduced padding */
            border: 1px solid #444;
            backdrop-filter: blur(10px);
            overflow-y: auto;
        }
        .left-panel {
            flex: 1;
            min-width: 250px;
            display: flex;
            flex-direction: column;
            gap: 8px; /* Reduced gap */
        }
        .center-panel {
            flex: 3;
            min-width: 500px;
            display: flex;
            flex-direction: column;
            gap: 8px; /* Reduced gap */
        }
        .right-panel {
            flex: 1;
            min-width: 250px;
            display: flex;
            flex-direction: column;
            gap: 8px; /* Reduced gap */
        }
        h2 {
            color: #4CAF50;
            margin-top: 0;
            margin-bottom: 8px; /* Reduced margin */
            font-size: 1.1em; /* Slightly smaller */
            display: flex;
            align-items: center;
            gap: 6px; /* Reduced gap */
        }
        h3 { /* Ensure h3 are also sized appropriately */
            font-size: 1em; /* Smaller h3 in collapsible sections */
            margin: 0;
            color: #e0e0e0;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .collapsible-section .section-header {
            background: rgba(52, 52, 52, 0.9);
            border-radius: 8px;
            padding: 8px; /* Reduced padding */
            margin-bottom: 5px;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border: 1px solid #555;
        }
        .collapsible-section .section-header:hover {
            background: rgba(62, 62, 62, 0.9);
        }
        .collapsible-section .section-content {
            max-height: 500px; /* Max height when open */
            overflow-y: auto;
            transition: max-height 0.3s ease-out, opacity 0.3s ease-out;
            opacity: 1;
            padding: 8px; /* Reduced padding */
            background: rgba(32, 32, 32, 0.9);
            border-radius: 0 0 8px 8px;
            border: 1px solid #555;
            border-top: none;
            margin-top: -5px;
        }
        .collapsible-section .section-content.collapsed {
            max-height: 0;
            opacity: 0;
            padding: 0 8px; /* Reduced padding */
        }
        .toggle-icon {
            transition: transform 0.3s ease;
            color: #aaa;
            transform: rotate(0deg); /* Default state: points down (open) */
        }
        .section-header.collapsed .toggle-icon {
            transform: rotate(-90deg); /* Rotated when collapsed */
        }

        /* New Map section styles (inspired by MULTIPASS DISCO) */
        .map-section {
            flex: 1; /* Allow map section to grow */
            display: flex;
            flex-direction: column;
            margin-bottom: 0; /* Remove margin from panel child */
            border: 1px solid #444;
            border-radius: 8px;
            overflow: hidden;
            background-color: #333;
        }

        .map-header {
            background-color: #383838;
            padding: 12px; /* Reduced padding */
            border-bottom: 1px solid #555;
        }

        .map-header h3 {
            margin: 0 0 8px 0; /* Reduced margin */
            color: #e0e0e0;
            font-size: 1.1em; /* Consistent with other h3 */
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .map-controls {
            display: flex;
            gap: 8px; /* Reduced gap */
            align-items: center;
            flex-wrap: wrap;
        }

        .coord-input {
            display: flex;
            align-items: center;
            gap: 4px; /* Reduced gap */
            min-width: 0;
        }

        .coord-input label {
            font-weight: bold;
            color: #cccccc;
            margin: 0;
            min-width: 25px; /* Slightly smaller */
            font-size: 0.85em; /* Adjusted for overall small font-size */
        }

        .coord-input input {
            width: 70px; /* Slightly smaller */
            padding: 5px; /* Reduced padding */
            border: 1px solid #555;
            border-radius: 4px;
            font-size: 0.8em; /* Adjusted for overall small font-size */
            background-color: #333;
            color: #e0e0e0;
            min-width: 0;
        }

        .coord-input input:focus {
            border-color: #4CAF50;
            outline: none;
        }

        .map-button {
            padding: 6px 9px; /* Reduced padding */
            background-color: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.75em; /* Slightly smaller */
            transition: background-color 0.3s ease;
            white-space: nowrap;
            min-height: 28px; /* Adjusted to fit the general UI */
        }

        .map-button:hover {
            background-color: #45a049;
        }

        .map-button.secondary {
            background-color: #2196F3;
        }

        .map-button.secondary:hover {
            background-color: #1976D2;
        }

        #map {
            height: 250px;
            width: 100%;
            border-top: 1px solid #555; /* Add separator */
        }

        .map-info {
            padding: 8px 12px; /* Reduced padding */
            background-color: #2a2a2a;
            font-size: 0.75em; /* Adjusted for overall small font-size */
            color: #cccccc;
            text-align: center;
        }

        /* End New Map specific styles */


        .chat-area {
            display: flex;
            flex-direction: column;
            flex: 1;
            background: rgba(22, 33, 62, 0.8);
            border-radius: 8px;
            border: 1px solid #444;
            padding: 10px;
        }
        .chat-messages {
            flex: 1;
            overflow-y: auto;
            padding: 5px;
            margin-bottom: 8px; /* Reduced margin */
            background: #0a0a0a;
            border-radius: 5px;
            color: #ccc;
            font-size: 0.85em; /* Slightly smaller */
        }
        .chat-input-group {
            display: flex;
            gap: 5px;
        }
        .chat-input {
            flex: 1;
            padding: 7px; /* Reduced padding */
            border-radius: 5px;
            border: 1px solid #555;
            background: #2a2a2a;
            color: #e0e0e0;
            font-size: 0.85em; /* Slightly smaller */
        }
        .chat-send-btn {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 7px 10px; /* Reduced padding */
            border-radius: 5px;
            cursor: pointer;
            transition: background 0.3s ease;
            font-size: 0.85em; /* Slightly smaller */
        }
        .chat-send-btn:hover {
            background: #45a049;
        }
        .player-info, .location-info, .social-list-item {
            padding: 6px 0; /* Reduced padding */
            border-bottom: 1px dashed #333;
            font-size: 0.9em; /* Consistent font size */
        }
        .player-info:last-child, .location-info:last-child, .social-list-item:last-child {
            border-bottom: none;
        }
        .player-info strong, .location-info strong, .social-list-item strong {
            color: #00ffff;
        }
        .social-list-item {
            display: flex;
            align-items: center;
            gap: 8px; /* Reduced gap */
            cursor: pointer;
        }
        .social-list-item:hover {
            background-color: rgba(76, 175, 80, 0.1);
            border-radius: 5px;
            padding-left: 5px;
        }
        .social-list-item img {
            width: 28px; /* Slightly smaller */
            height: 28px; /* Slightly smaller */
            border-radius: 50%;
            object-fit: cover;
            border: 1px solid #4CAF50;
        }
        .social-list-item .pubkey {
            font-family: monospace;
            font-size: 0.7em; /* Slightly smaller */
            color: #aaa;
        }
        .connect-btn-special {
            background: linear-gradient(45deg, #9c27b0, #7b1fa2);
            color: white;
            border: none;
            padding: 7px 14px; /* Reduced padding */
            border-radius: 20px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.75em; /* Slightly smaller */
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 5px; /* Reduced gap */
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
        .connect-btn-special.connected {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            box-shadow: 0 2px 4px rgba(76, 175, 80, 0.3);
        }
        .connect-btn-special.connected:hover {
            background: linear-gradient(45deg, #45a049, #388e3c);
            box-shadow: 0 4px 12px rgba(76, 175, 80, 0.5);
        }
        /* NEW: Chat Tag Buttons */
        .chat-tag-button {
            padding: 5px 10px;
            background-color: #333;
            color: #fff;
            border: 1px solid #555;
            border-radius: 5px;
            cursor: pointer;
            font-size: 0.75em;
            transition: all 0.3s ease;
            white-space: nowrap;
        }
        .chat-tag-button:hover {
            background-color: #444;
        }
        .chat-tag-button.active {
            background-color: #4CAF50;
            border-color: #45a049;
        }
        .chat-sub-tags {
            display: flex;
            gap: 5px;
            transition: opacity 0.3s ease, max-height 0.3s ease;
            max-height: 0;
            overflow: hidden;
            opacity: 0;
            flex-wrap: wrap; /* Allow wrapping */
        }
        .chat-sub-tags.show {
            max-height: 50px; /* Adjust as needed */
            opacity: 1;
            display: flex; /* Ensure it's flex when shown */
        }
        /* END NEW: Chat Tag Buttons */
        /* Player Actions */
        .player-actions {
            display: flex;
            gap: 5px;
            margin-top: 8px; /* Reduced margin */
            flex-wrap: wrap;
            justify-content: center;
        }
        .action-btn {
            background: #2196F3;
            color: white;
            border: none;
            padding: 7px 12px; /* Reduced padding */
            border-radius: 5px;
            cursor: pointer;
            transition: background 0.3s ease;
            font-size: 0.8em; /* Slightly smaller */
            white-space: nowrap;
        }
        .action-btn:hover {
            background: #1976D2;
        }
        .action-btn.move { background: #ff9800; }
        .action-btn.move:hover { background: #fb8c00; }
        .action-btn.create { background: #9c27b0; }
        .action-btn.create:hover { background: #7b1fa2; }
        .action-btn.post { background: #e91e63; }
        .action-btn.post:hover { background: #c2185b; }

        /* Profile & Wallet Display (from nostr.html) */
        #profile-display {
            display: flex;
            flex-direction: column; /* Changed to column for better stacking on smaller screens */
            gap: 12px; /* Reduced gap */
            padding: 12px; /* Reduced padding */
            background: #232733;
            border-radius: 8px;
            margin-bottom: 12px; /* Reduced margin */
        }
        #profile-display img {
            width: 45px; /* Slightly smaller */
            height: 45px; /* Slightly smaller */
            border-radius: 50%;
            margin-right: 8px; /* Reduced margin */
            border: 1px solid #555;
            object-fit: cover;
            flex-shrink: 0;
            }
            .profile-basic-info {
            display: flex;
            align-items: center;
            gap: 12px; /* Reduced gap */
        }
        .profile-info {
            display: flex;
                flex-direction: column;
        }
        .profile-info span { display: block; font-size: 0.9em;} /* Consistent font size */
        .profile-info .profile-name { font-weight: bold; color: #eee; }
        .profile-info .profile-nip05 { font-size: 0.8em; color: #aaa; } /* Slightly smaller */

        .wallet-section {
            display: flex;
            flex-direction: column;
            gap: 8px; /* Reduced gap */
            margin-top: 8px; /* Reduced margin */
        }
        .wallet-info {
            background: #1e2533;
            padding: 12px; /* Reduced padding */
            border-radius: 6px;
        }
        .wallet-label {
            font-weight: bold;
            color: #4CAF50;
            margin-bottom: 8px; /* Reduced margin */
            font-size: 1em; /* Slightly smaller */
        }
        .wallet-version {
            background: #2a2f3a;
            padding: 8px; /* Reduced padding */
            border-radius: 4px;
            margin-bottom: 8px; /* Reduced margin */
        }
        .wallet-address {
            font-family: monospace;
            font-size: 0.8em; /* Slightly smaller */
            color: #b8c6e0;
            word-break: break-all;
            margin: 4px 0; /* Reduced margin */
        }
        .wallet-balance-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 4px; /* Reduced margin */
            padding-top: 4px; /* Reduced padding */
            border-top: 1px solid #333;
        }
        .balance-label {
            color: #b8c6e0;
            font-size: 0.8em; /* Consistent font size */
        }
        .balance-amount {
            color: #4CAF50;
            font-weight: bold;
            font-size: 1.1em; /* Slightly smaller */
        }
        #g1-balance, #zen-balance { /* Main balance display */
            font-size: 1.1em; /* Slightly smaller */
            font-weight: bold;
            color: #4CAF50;
        }
        .wallet-balance-item {
            text-align: center;
            flex: 1;
        }

        /* Responsive */
        @media (max-width: 1024px) {
            .main-content {
                flex-direction: column;
            }
            .left-panel, .center-panel, .right-panel {
                min-width: unset;
                flex: none;
                width: 100%;
            }
        }

        @media screen and (max-width: 480px) {
            body { font-size: 13px; /* Smaller base font size for small screens */ }
            .panel {
            padding: 8px; /* Even less padding */
            }
            h2 {
                font-size: 1em;
            }
            h3 {
                font-size: 0.9em;
            }
            .map-controls {
            flex-direction: column;
                align-items: stretch;
            gap: 6px; /* Even less gap */
        }
            .coord-input {
                justify-content: center;
            }
            .action-btn {
                padding: 6px 9px;
                font-size: 0.75em;
            }
            .connect-btn-special {
                padding: 6px 10px;
                font-size: 0.7em;
            }
            .map-button {
                width: 100%;
                padding: 8px;
                font-size: 0.8em;
                min-height: unset;
            }
            .chat-messages, .chat-input {
                font-size: 0.8em;
            }
            .chat-send-btn {
                font-size: 0.8em;
            }
            .player-info span, .wallet-info, .wallet-label, .balance-label, .balance-amount, .map-info {
                font-size: 0.8em;
            }
            .profile-info .profile-name { font-size: 0.9em; }
            .social-list-item img { width: 24px; height: 24px; }
            .social-list-item span { font-size: 0.8em; }
            .social-list-item .pubkey { font-size: 0.65em; }
            #profile-display img { width: 40px; height: 40px; }
        }
        .world-map-panel iframe {
            display: block; /* Supprime l'espace sous l'iframe */
        }
    </style>
</head>
<body>
    <div class="container">
    <div class="header">
        <div class="header-content">
                <h1>🌐 UPlanet Geo-RPG / World-Builder<</h1>
        </div>
    </div>

    <div class="main-content">
        <!-- Left Panel: Player Info & Actions -->
        <div class="left-panel panel">
            <div class="collapsible-section">
                <div class="section-header" data-target="player-profile-content">
                    <h3><i class="fas fa-user-circle"></i> My Player Profile</h3>
                    <i class="fas fa-chevron-down toggle-icon"></i>
                </div>
                    <div class="section-content collapsed" id="player-profile-content">
                        <!-- Profile and Wallet Display (from nostr.html) -->
                        <div id="profile-display">
                            <div class="profile-basic-info">
                                <img id="player-picture" src="https://via.placeholder.com/50" alt="Player Picture" style="display:none;">
                                <div class="profile-info">
                                    <strong>Status:</strong> <span id="player-status">Disconnected</span><br>
                                    <strong>Name:</strong> <span id="player-name">Loading...</span><br>
                        <strong>Nostr PubKey:</strong> <code id="player-pubkey">N/A</code>
                    </div>
                    </div>
                            <div class="wallet-section">
                                <div class="wallet-info">
                                    <div class="wallet-label">Balances</div>
                                    <div style="display: flex; justify-content: space-around; gap: 10px;">
                                        <div class="wallet-balance-item">
                                            <div style="font-size: 0.9em; color: #aaa;">G1 Balance</div>
                                            <div id="g1-balance" style="font-size: 1.2em; color: #4CAF50; font-weight: bold;">0 G1</div>
                    </div>
                                        <div class="wallet-balance-item">
                                            <div style="font-size: 0.9em; color: #aaa;">Zen Balance</div>
                                            <div id="zen-balance" style="font-size: 1.2em; color: #2196F3; font-weight: bold;">0 ZEN</div>
                                        </div>
                                    </div>
                                    <div style="font-size: 0.75em; color: #aaa; margin-top: 10px; text-align: center;">(Requires UPassport API backend)</div>
                                </div>
                            </div>
                    </div>
                    <div class="player-actions">
                        <button class="connect-btn-special" id="connect-btn"><i class="fas fa-satellite-dish"></i> Connect Nostr</button>
                    </div>
                        <div class="player-info">
                            <strong>About:</strong> <span id="player-about">Loading...</span>
                        </div>
                </div>
            </div>

            <div class="collapsible-section">
                <div class="section-header" data-target="social-graph-content">
                    <h3><i class="fas fa-users"></i> Social Graph</h3>
                    <i class="fas fa-chevron-down toggle-icon"></i>
                </div>
                    <div class="section-content collapsed" id="social-graph-content">
                    <h4>Following (<span id="following-count">0</span>)</h4>
                    <div id="following-list">
                        <p>No one followed yet.</p>
                    </div>
                    <h4>Followers (<span id="followers-count">0</span>)</h4>
                    <div id="followers-list">
                        <p>No followers yet.</p>
                    </div>
                </div>
            </div>

            <div class="collapsible-section">
                <div class="section-header" data-target="inventory-content">
                    <h3><i class="fas fa-briefcase"></i> My Inventory</h3>
                    <i class="fas fa-chevron-down toggle-icon"></i>
                </div>
                    <div class="section-content collapsed" id="inventory-content">
                    <p>Load items from your IPFS drive.</p>
                        <!-- Inventory list will go here. Example: -->
                        <!-- <div class="inventory-item">Sword of Truth</div> -->
                        <!-- <div class="inventory-item">Healing Potion (x3)</div> -->
                </div>
            </div>
        </div>

        <!-- Center Panel: Map & Current Location Info -->
        <div class="center-panel panel">
                <!-- Map Section -->
                <div class="map-section">
                    <div class="map-header">
                    <h3><i class="fas fa-map"></i> World Map</h3>
                        <div class="map-controls">
                            <div class="coord-input">
                                <label>Lat:</label>
                                <input type="number" id="lat-display" step="0.01" min="-90" max="90">
                </div>
                            <div class="coord-input">
                                <label>Lon:</label>
                                <input type="number" id="lon-display" step="0.01" min="-180" max="180">
                    </div>
                            <button type="button" class="map-button" id="update-map-btn"><i class="fas fa-walking"></i> Y aller</button>
                            <button type="button" class="map-button secondary" id="get-location-btn"><i class="fas fa-crosshairs"></i> Ma position</button>
                        </div>
                    </div>
                    <div id="map"></div>
                    <div class="map-info">
                        💡 Cliquez sur la carte pour ajuster votre position.
                </div>
            </div>

            <div class="collapsible-section">
                <div class="section-header" data-target="location-info-content">
                    <h3><i class="fas fa-info-circle"></i> Current Location: <span id="current-location-name">Loading...</span></h3>
                    <i class="fas fa-chevron-down toggle-icon"></i>
                </div>
                    <div class="section-content collapsed" id="location-info-content">
                    <p id="location-description">Description of the current area.</p>
                    <h4>Players Here: (<span id="players-here-count">0</span>)</h4>
                    <div id="players-here-list">
                        <p>No other players detected.</p>
                    </div>
                    <h4>Quests & Items: (<span id="quests-items-count">0</span>)</h4>
                    <div id="quests-items-list">
                        <p>No quests or items here.</p>
                    </div>
                    <div class="player-actions">
                        <button class="action-btn move" id="move-btn"><i class="fas fa-walking"></i> Move</button>
                        <button class="action-btn create" id="create-location-btn"><i class="fas fa-plus"></i> Create Location</button>
                        <button class="action-btn post" id="post-event-btn"><i class="fas fa-comment-dots"></i> Post Update</button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Right Panel: AI Chat -->
        <div class="right-panel panel">
            <div class="collapsible-section" style="flex:1;">
                <div class="section-header" data-target="ai-chat-content">
                    <h3><i class="fas fa-robot"></i> Astrobot Chat</h3>
                    <i class="fas fa-chevron-down toggle-icon"></i>
                </div>
                    <div class="section-content collapsed" id="ai-chat-content" style="flex:1; display:flex; flex-direction:column;">
                    <div class="chat-messages" id="chat-messages">
                        <p><strong>Astrobot:</strong> Welcome, adventurer! How can I help you explore UPlanet?</p>
                    </div>
                    <div class="chat-input-group">
                        <input type="text" id="chat-input" class="chat-input" placeholder="Type your message to Astrobot...">
                        <button id="chat-send-btn" class="chat-send-btn"><i class="fas fa-paper-plane"></i> Send</button>
                    </div>
                    <!-- NEW: Astrobot Tag Buttons -->
                    <div id="astrobot-tag-buttons" style="display: flex; flex-wrap: wrap; gap: 5px; margin-top: 8px;">
                        <button type="button" class="chat-tag-button main-tag" data-tag="#BRO">🤖 IA</button>
                        <div class="chat-sub-tags" style="display: none; opacity: 0; transition: opacity 0.3s ease;">
                            <button type="button" class="chat-tag-button" data-tag="#search">🔍 Search</button>
                            <button type="button" class="chat-tag-button" data-tag="#market">💰 Market</button>
                        </div>
                    </div>
                    <!-- END NEW: Astrobot Tag Buttons -->
                </div>
            </div>
        </div>
    </div>


    </div>

    <!-- Navigation et informations en bas -->
    <div class="bottom-panel">
        <!-- Hidden Debug Info -->
        <details style="position: fixed; bottom: 10px; right: 10px; background: rgba(0,0,0,0.7); color: white; padding: 5px; border-radius: 5px; z-index: 999;">
            <summary style="cursor: pointer; font-size: 0.8em;">Debug Info</summary>
            <pre id="debug-info" style="font-size: 0.7em; max-height: 200px; overflow-y: auto; background: #111; padding: 5px; border-radius: 3px;"></pre>
        </details>
    </div>

    <script>
        // Déclarations des variables globales en haut du script pour éviter les erreurs "is not defined"
        let currentManifest = null;
        let allItems = [];
        let filteredItems = [];
        let currentFilter = 'all';
        let currentFileIndex = 0;
        let currentGateway = '';
        let upassportUrl = '';
        // let NOSTRws = ''; // Removed as it's no longer used globally and `detectNOSTRws` is removed.
        let nostrRelay = null;
        let isNostrConnected = false; // Initialisation explicite
        let userPublicKey = null;
        let userPrivateKey = null;

        $(document).ready(function() {
            console.log('Loading IPFS directory from manifest...');
            // We no longer need detectGatewayAndAPIs here, it's integrated into loadManifestAndInitRPG
            // Removed: detectNOSTRws(); // This was causing the error, it's not defined
            loadManifestAndInitRPG();
            setupEventListeners(); // Call once everything is set up
        });

        // --- Configuration ---
        const userNsec = ''; // Leave empty for browser extension (NIP-07)
        const UPLANET_APP_NAME = 'UPlanetV1';

        // --- Global Variables ---
        let debugInfo = '';
        let nostrExtensionAvailable = false;
        let privateKeyHex = null; // Stored if NSEC is provided
        let publicKey = '';       // User's active public key (from NSEC or extension)
        let userProfile = null;   // User's kind 0 profile data

        let manifestData = null;  // Loaded from manifest.json
        // OLD: let NOSTR_RELAY_WS = 'ws://127.0.0.1:7777'; // Default, updated by manifest
        // OLD: let DEFAULT_RELAYS = ['wss://relay.copylaradio.com', 'ws://127.0.0.1:7777']; // Initial list, updated by manifest

        // NEW: Define general purpose relays and a variable for the specific Astrobot relay
        const GENERAL_PUBLIC_RELAYS = ['wss://relay.copylaradio.com']; // Public, non-restricted relays
        let LOCAL_ASTROBOT_RELAY = 'ws://127.0.0.1:7777'; // Initial default for local/restricted relay, will be updated from manifest

        let allRelaysToPublish = []; // Combination of all relays (for subscribing and general publishing)

        let nostrPool = null; // The SimplePool instance
        let currentLatitude = 44.23; // Default starting location as requested
        let currentLongitude = 1.65; // Default starting location as requested

        // Map variables
        let map; // Changed from miniMap
        let marker; // Changed from miniMarker

        // --- Helper Functions ---
        function log(message) {
            console.log(message);
            const ts = new Date().toLocaleTimeString();
            debugInfo += `[${ts}] ${message}\n`;
            const el = $('#debug-info');
            if (el.length) {
                const lines = debugInfo.split('\n');
                if (lines.length > 150) debugInfo = lines.slice(-150).join('\n');
                el.text(debugInfo);
                el[0].scrollTop = el[0].scrollHeight;
            }
        }
        function updateStatus(message, isError = false, isSuccess = false) {
            // This function is not used in this specific HTML for status messages but kept for consistency if needed.
            // log(`Status Update: ${message}`);
            // console.log(`STATUS: ${message}`);
        }

        // Dummy function to prevent errors if it's called elsewhere and not fully removed
        function detectNOSTRws() {
            log("detectNOSTRws: This function is deprecated and does nothing.");
        }

        // NEW: USPOT API URL derivation (from user's nostr.html example)
        function getUSPOTUrl(route) {
            const currentUrl = new URL(window.location.href);
            let newUrl = new URL(currentUrl.origin);

            // Transformation de 'ipfs.domain.tld' en `u.domain.tld`
            if (currentUrl.hostname.startsWith('ipfs.')) {
                newUrl.hostname = newUrl.hostname.replace('ipfs.', 'u.');
            }

            // Changer le port en 54321 si nécessaire
            if (currentUrl.port === '8080' || currentUrl.port !== '') {
                newUrl.port = '54321';
            }

            return newUrl.toString() + route;
        }

        // --- Nostr Connection & Profile Management ---

        function getNostrPool() {
            if (!nostrPool) {
                if (typeof NostrTools?.SimplePool !== 'function') {
                    const m = "Error: NostrTools.SimplePool undefined or not a function!";
                    log(m);
                    console.error(m, "NostrTools:", NostrTools);
                    throw new Error(m);
                }
                try {
                    log("Initializing SimplePool...");
                    nostrPool = new NostrTools.SimplePool({ getTimeout: 6000, listTimeout: 6000 });
                    log("SimplePool initialized successfully.");
                } catch (e) {
                    log(`SimplePool initialization error: ${e.message}`);
                    console.error("SimplePool Init Details:", e);
                    throw e;
                }
            }
            return nostrPool;
        }

        async function connectToNostr() {
            if (!nostrExtensionAvailable && !userNsec) {
                // If no extension and no NSEC pre-configured, prompt user for NSEC
                const nsec = prompt('No Nostr extension found. Please enter your nsec key to connect (optional):');
                    if (nsec && nsec.startsWith('nsec1')) {
                        try {
                            const decoded = NostrTools.nip19.decode(nsec);
                        if (decoded.type !== 'nsec' || !decoded.data) throw new Error('Invalid NSEC format');
                        privateKeyHex = decoded.data;
                        publicKey = NostrTools.getPublicKey(privateKeyHex);
                        log(`NSEC provided. Pubkey: ${publicKey.slice(0, 10)}...`);
                            updateConnectionStatus(true);
                        await fetchProfileAndRelays(publicKey);
                        // No messages to fetch in RPG context, but update location and social graph
                        await updateCurrentLocation();
                        await loadSocialGraph();
                        return;
                    } catch (e) {
                        log(`Error initializing NSEC: ${e.message}`);
                        alert('Invalid NSEC key or NostrTools error. Please try again.');
                        updateConnectionStatus(false);
                        return;
                        }
                    } else {
                    log('No NSEC provided. Skipping Nostr connection.');
                        updateConnectionStatus(false);
                    return;
                }
            }

            // If extension is available or NSEC is set, proceed
            log('Attempting to connect via Nostr...');
            updateConnectionStatus(false, 'Connecting...'); // Set status to connecting

            try {
                if (userNsec) {
                    // Already set privateKeyHex and publicKey from userNsec init
                    log(`Using pre-configured NSEC. Pubkey: ${publicKey.slice(0, 10)}...`);
                } else if (window.nostr) {
                    log('NOSTR extension detected, requesting permissions...');
                    publicKey = await window.nostr.getPublicKey();
                    log('Connected with public key:', publicKey);
                } else {
                    // This case should ideally not be reached due to initial checks/prompts
                    throw new Error("No Nostr connection method available.");
                }

                updateConnectionStatus(true);
                await fetchProfileAndRelays(publicKey);
                await updateCurrentLocation();
                await loadSocialGraph();

            } catch (error) {
                log(`Error connecting to Nostr: ${error.message || error}`);
                alert(`Failed to connect to Nostr: ${error.message || 'Unknown error'}`);
                updateConnectionStatus(false);
                publicKey = '';
                privateKeyHex = null;
            }
        }

        function disconnectFromNostr() {
            if (nostrPool) {
                // SimplePool doesn't have a direct 'close' method, it manages connections internally.
                // To force disconnection, we might need to nullify and re-create it on next connect.
                nostrPool = null;
                log('Nostr pool reset (simulated disconnect).');
            }
            publicKey = '';
            privateKeyHex = null;
            userProfile = {};
            updateConnectionStatus(false);
            updatePlayerProfileUI(); // Clear profile UI
            $('#following-list').html('<p>No one followed yet.</p>');
            $('#followers-list').html('<p>No followers yet.</p>');
            $('#following-count').text('0');
            $('#followers-count').text('0');
            $('#g1-balance').text('0 G1');
            $('#zen-balance').text('0 ZEN');
            log('Disconnected from NOSTR.');
        }

        function updateConnectionStatus(connected, message = '') {
            const connectBtn = $('#connect-btn');
            isNostrConnected = connected;
            if (connected) {
                connectBtn.addClass('connected').html('<i class="fas fa-satellite-dish"></i> Connected');
                $('#player-status').text('Connected');
            } else {
                connectBtn.removeClass('connected').html('<i class="fas fa-satellite-dish"></i> Connect Nostr');
                $('#player-status').text(message || 'Disconnected');
            }
            // Update the UI state based on connection
            // For example, disable/enable player actions
            $('.player-actions button').prop('disabled', !connected);
            $('#chat-send-btn').prop('disabled', !connected); // Also disable chat send button
        }

        async function fetchProfileAndRelays(pubkey) {
            log(`Fetching profile/relays for ${pubkey.slice(0,10)}...`);
            let nostrPoolInstance;
            try {
                nostrPoolInstance = getNostrPool();
            } catch (e) {
                log("Failed to get Nostr pool in fetchProfileRelays.");
                return {};
            }

            let profileEv = null;
            let relayEv = null; // Keep for legacy, but not used for relay discovery anymore
            let userRelays = []; // User's listed relays from kind 10002 (will be ignored as per new instruction)
            let fetchedProfileData = {}; // Data from kind 0 event content
            let profileSource = '';

            try {
                // Fetch kind 0 (profile) event using all available relays for subscription
                const profileEvents = await nostrPoolInstance.list(allRelaysToPublish, [{ kinds: [0], authors: [pubkey], limit: 1 }]);
                if (profileEvents.length > 0) {
                    profileEv = profileEvents[0];
                    profileSource = profileEv.tags.find(t => t[0] === 'relay')?.[1] || 'unknown'; // This is not standard NIP-01. A relay would set this on a signed event.
                    log(`Profile event: ${profileEv.id} from ${profileSource}`);
                    try {
                        fetchedProfileData = JSON.parse(profileEv.content);
                        // Add special tags like G1/Zen addresses if they exist in event.tags
                        if (profileEv.tags) {
                            profileEv.tags.forEach(tag => {
                                if (tag[0] === 'i') { // NIP-31 "Identity" tag
                                    const [type, value] = tag[1].split(':');
                                    switch(type) {
                                        case 'g1pub': fetchedProfileData.g1_address = value; break;
                                        case 'g1pubv2': fetchedProfileData.g1_address_v2 = value; break;
                                        case 'zencard': fetchedProfileData.zen_address = value; break;
                                        // Add other tags like github, twitter etc if needed
                                    }
                                }
                            });
                        }
                        log(`Profile data: ${JSON.stringify(fetchedProfileData, null, 2)}`);
                    } catch (e) {
                        log(`Profile parse error: ${e.message}`);
                    }
                }

                // Removed: Fetch kind 10002 (relay list) event - As per user's request: "Ne plus découvrir les relais 10002"
                // Removed: and all logic related to userRelays from kind 10002

                userProfile = { ...fetchedProfileData, source: profileSource }; // Set global userProfile

                // allRelaysToPublish is already set in loadManifestAndInitRPG. No need to update it here.

                renderProfile(pubkey, userProfile); // Render profile info
                await checkWalletBalances(userProfile); // Check wallet balances

                return userProfile;

                } catch (e) {
                log(`Error fetching profile/relays: ${e}`);
                console.error("Fetch Profile/Relay Details:", e);
                return {};
            }
        }

        // --- Wallet Balance Functions (from nostr.html) ---
        async function checkWalletBalances(profileData) {
            try {
                if (profileData.g1_address) {
                    const response = await fetch(`/check_balance?g1pub=${profileData.g1_address}`);
                    const data = await response.json();
                    $('#g1-balance').text(`${data.balance || '0'} G1`);
                } else if (profileData.g1_address_v2) { // Prioritize V2 if available
                    const response = await fetch(`/check_balance?g1pub=${profileData.g1_address_v2}`);
                    const data = await response.json();
                    $('#g1-balance').text(`${data.balance || '0'} G1`);
                } else {
                    $('#g1-balance').text('N/A');
                }

                if (profileData.zen_address) {
                    const response = await fetch(`/check_balance?address=${profileData.zen_address}&currency=ZEN`);
                    const data = await response.json();
                    $('#zen-balance').text(`${data.balance || '0'} ZEN`);
            } else {
                    $('#zen-balance').text('N/A');
                }
            } catch (error) {
                log(`Error checking balances: ${error.message}`);
                $('#g1-balance').text('Error');
                $('#zen-balance').text('Error');
            }
        }

        // --- Render Profile UI (from nostr.html) ---
        function renderProfile(pubkey, profileData) {
            const defPic = '/ipfs/QmPPELF7HhM9BXtAUMnNUSNsrRJgsFzLNCQ5pFhWKr9ogk/favicon.galaxy.ico'; // Placeholder for default icon
            const pic = profileData?.picture || defPic;
            const name = profileData?.display_name || profileData?.name || NostrTools.nip19.npubEncode(pubkey).slice(0, 10) + '...';
            const nip05 = profileData?.nip05 || '';
            const npubEncoded = NostrTools.nip19.npubEncode(pubkey);

            $('#player-picture').attr('src', pic).show().on('error', function() { $(this).attr('src', defPic); });
            $('#player-name').text(name);
            $('#player-pubkey').text(npubEncoded.slice(0, 10) + '...' + npubEncoded.slice(-10));
            $('#player-about').text(profileData?.about || 'No description.');
            $('#player-status').text(isNostrConnected ? 'Connected' : 'Disconnected');

            // Optionally, if you have a full NIP-05 check:
            // if (nip05) { ... }
        }

        // function updateRelayListUI() { // No longer needed as we removed the relay list UI
        //     const l = $('#relay-list').empty();
        //     if (allRelaysToPublish.length > 0) {
        //         allRelaysToPublish.forEach(r => {
        //             $('<li>').text(r).appendTo(l);
        //         });
        //     } else {
        //         $('<li>').text('No relays configured.').appendTo(l);
        //     }
        //     log(`UI updated: ${allRelaysToPublish.length} relays.`);
        // }

        // --- RPG Core Logic ---

        // Function to update current location info (description, players, quests)
        async function updateCurrentLocation() {
            $('#current-location-name').text(`Lat: ${currentLatitude.toFixed(2)}, Lon: ${currentLongitude.toFixed(2)}`);
            $('#location-description').text('Fetching location description...');
            $('#players-here-list').html('<i class="fas fa-spinner fa-spin"></i> Loading players...');
            $('#quests-items-list').html('<i class="fas fa-spinner fa-spin"></i> Loading quests...');

            currentGeoKeyNpub = getGeoKeyNpub(currentLatitude, currentLongitude);
            log('Current GeoKey:', currentGeoKeyNpub);

            let nostrPoolInstance;
            try {
                nostrPoolInstance = getNostrPool();
            } catch (e) {
                $('#location-description').text('Connect to Nostr to load location details.');
                $('#players-here-list').html('<p>Connect to Nostr to see players.</p>');
                $('#quests-items-list').html('<p>Connect to Nostr to see quests.</p>');
                log("Failed to get Nostr pool in updateCurrentLocation.");
                return;
            }

            // Fetch location description (kind 1 event tagged with location)
            const locationDescEvents = [];
            const locationSub = nostrPoolInstance.sub(allRelaysToPublish, [
                {
                    kinds: [1],
                    '#latitude': [currentLatitude.toFixed(2)],
                    '#longitude': [currentLongitude.toFixed(2)],
                    limit: 5
                }
            ]);
            locationSub.on('event', (event) => { locationDescEvents.push(event); });
            locationSub.on('eose', () => {
                let bestDescription = '';
                const descEvent = locationDescEvents.find(e => e.tags.some(t => t[0] === 't' && t[1] === 'uplanet_rpg_location_desc')) ||
                                  locationDescEvents.sort((a,b) => b.created_at - a.created_at)[0];
                if (descEvent) { bestDescription = descEvent.content; }
                $('#location-description').text(bestDescription || 'No description available for this area yet. Be the first to create one!');
                locationSub.unsub();
            });


            // Fetch players in this location (kind 1 events tagged with this GeoKey or location)
            const playersHere = new Set();
            $('#players-here-list').empty();
            $('#players-here-count').text('0');

            const playersSub = nostrPoolInstance.sub(allRelaysToPublish, [
                {
                    kinds: [1],
                    '#latitude': [currentLatitude.toFixed(2)],
                    '#longitude': [currentLongitude.toFixed(2)],
                    since: Math.floor(Date.now() / 1000) - (60 * 60) // Events from last hour
                }
            ]);
            playersSub.on('event', async (event) => {
                if (event.pubkey !== publicKey && !playersHere.has(event.pubkey)) {
                    playersHere.add(event.pubkey);
                    const profile = await fetchProfile(event.pubkey);
                    const playerName = profile.name || NostrTools.nip19.npubEncode(event.pubkey).substring(0, 10) + '...';
                    $('#players-here-list').append(`
                        <div class="social-list-item" data-pubkey="${event.pubkey}">
                            <img src="${profile.picture || 'https://via.placeholder.com/30'}" alt="Player Icon">
                            <span>${playerName}</span>
                            <code class="pubkey">${NostrTools.nip19.npubEncode(event.pubkey).substring(0, 5)}...</code>
                        </div>
                    `);
                    $('#players-here-count').text(playersHere.size);
                }
            });
            playersSub.on('eose', () => {
                if (playersHere.size === 0) {
                    $('#players-here-list').html('<p>No other players detected.</p>');
                }
                playersSub.unsub();
            });

            // Fetch quests and items (custom kind or kind 1 with specific tags)
            const questsItems = new Set();
            $('#quests-items-list').empty();
            $('#quests-items-count').text('0');
            const questsItemsSub = nostrPoolInstance.sub(allRelaysToPublish, [
                {
                    kinds: [1],
                    '#latitude': [currentLatitude.toFixed(2)],
                    '#longitude': [currentLongitude.toFixed(2)],
                    '#rpg_type': ['quest', 'item'], // Custom tags for quests/items
                    limit: 10
                }
            ]);
            questsItemsSub.on('event', (event) => {
                if (!questsItems.has(event.id)) {
                    questsItems.add(event.id);
                    const rpgType = event.tags.find(tag => tag[0] === 'rpg_type')?.[1] || 'item/quest';
                    $('#quests-items-list').append(`
                        <div class="location-info">
                            <strong>${rpgType.charAt(0).toUpperCase() + rpgType.slice(1)}:</strong> ${event.content.substring(0, 100)}... <a href="#" data-event-id="${event.id}">[Read More]</a>
                        </div>
                    `);
                    $('#quests-items-count').text(questsItems.size);
                }
            });
            questsItemsSub.on('eose', () => {
                if (questsItems.size === 0) {
                    $('#quests-items-list').html('<p>No quests or items here.</p>');
                }
                questsItemsSub.unsub();
            });

            // Update map display with current location
            updateMapCoordinates(currentLatitude, currentLongitude);
            if (map) { // Use 'map' instead of 'miniMap'
                map.setView([currentLatitude, currentLongitude], map.getZoom());
            }
        }

        // Helper to fetch any Nostr profile
        async function fetchProfile(pubkey) {
            let nostrPoolInstance;
            try {
                nostrPoolInstance = getNostrPool();
                    } catch (e) {
                log("Failed to get Nostr pool in fetchProfile.");
                return {};
            }
            return new Promise(resolve => {
                const sub = nostrPoolInstance.sub(allRelaysToPublish, [
                    { kinds: [0], authors: [pubkey], limit: 1 }
                ]);
                sub.on('event', (event) => {
                    try { resolve(JSON.parse(event.content)); } catch (e) { console.error('Error parsing profile:', e); resolve({}); }
                    sub.unsub();
                });
                sub.on('eose', () => { resolve({}); });
            });
        }

        // Function to calculate GeoKey npub from lat/lon (placeholder)
        function getGeoKeyNpub(lat, lon) {
            const formattedLat = parseFloat(lat).toFixed(2);
            const formattedLon = parseFloat(lon).toFixed(2);
            // This is a dummy for client-side representation. The actual GeoKey
            // for signing location descriptions would be managed by a server (e.g., UPassport)
            // using the UPLANET_APP_NAME + coordinates as seed.
            return `npub1${formattedLat.replace('.', '')}${formattedLon.replace('.', '')}geokey`;
        }

        // --- Social Graph (N1, N2) ---
        async function loadSocialGraph() {
            if (!publicKey) { log("No public key to load social graph."); return; }
            let nostrPoolInstance;
            try { nostrPoolInstance = getNostrPool(); } catch (e) { log("Failed to get Nostr pool in loadSocialGraph."); return; }

            // N1: Following (kind 3 event)
            const followingList = new Set();
            $('#following-list').empty().append('<p><i class="fas fa-spinner fa-spin"></i> Loading...</p>');
            const followingSub = nostrPoolInstance.sub(allRelaysToPublish, [
                { kinds: [3], authors: [publicKey], limit: 1 }
            ]);
            followingSub.on('event', async (event) => {
                const tags = event.tags || [];
                $('#following-list').empty();
                for (const tag of tags) {
                    if (tag[0] === 'p' && tag[1]) {
                        if (!followingList.has(tag[1])) {
                            followingList.add(tag[1]);
                            const profile = await fetchProfile(tag[1]);
                            const playerName = profile.name || NostrTools.nip19.npubEncode(tag[1]).substring(0, 10) + '...';
                            $('#following-list').append(`
                                <div class="social-list-item" data-pubkey="${tag[1]}">
                                    <img src="${profile.picture || 'https://via.placeholder.com/30'}" alt="User Icon">
                                    <span>${playerName}</span>
                                    <code class="pubkey">${NostrTools.nip19.npubEncode(tag[1]).substring(0, 5)}...</code>
                                </div>
                            `);
                        }
                    }
                }
                $('#following-count').text(followingList.size);
                if (followingList.size === 0) { $('#following-list').html('<p>No one followed yet.</p>'); }
                followingSub.unsub();
            });
            followingSub.on('eose', () => { if (followingList.size === 0) { $('#following-list').html('<p>No one followed yet.</p>'); } });

            // N2: Followers (requires reverse lookup or query on relay - not directly supported by NIPs)
             $('#followers-list').html('<p>Followers list requires advanced relay features or server-side indexing.</p>');
             $('#followers-count').text('?');
        }

        // --- Player Actions ---
        function promptMove(newLat, newLon) { // Simplified, expects actual coords now
            if (!isNostrConnected || !publicKey) { alert('Please connect to Nostr to move.'); return; }

            // newLat and newLon are now directly passed from map inputs
            if (isNaN(newLat) || isNaN(newLon)) {
                alert('Invalid coordinates. Please enter numbers.');
                return;
            }

            currentLatitude = newLat;
            currentLongitude = newLon;

            updateMapCoordinates(currentLatitude, currentLongitude); // Update map display and inputs
            publishLocationUpdate(currentLatitude, currentLongitude);
            updateCurrentLocation();
        }

        async function publishLocationUpdate(lat, lon) {
            if (!publicKey) return;
            let nostrPoolInstance;
            try { nostrPoolInstance = getNostrPool(); } catch (e) { log("Failed to get Nostr pool in publishLocationUpdate."); return; }

            const content = `I have moved to ${lat.toFixed(2)}, ${lon.toFixed(2)} in the UPlanet RPG!`;
            const event = {
                kind: 1,
                created_at: Math.floor(Date.now() / 1000),
                tags: [
                    ['t', 'uplanet_rpg_location'],
                    ['latitude', lat.toFixed(6)],
                    ['longitude', lon.toFixed(6)],
                    ['application', UPLANET_APP_NAME]
                ],
                content: content,
                pubkey: publicKey
            };

            try {
                let signedEvent;
                if (window.nostr) { signedEvent = await window.nostr.signEvent(event); }
                else if (privateKeyHex) { signedEvent = NostrTools.finishEvent(event, privateKeyHex); }
                else { alert('No signing method available. Cannot publish.'); return; }

                // Publish to general relays only for user-signed events
                const relaysForPublish = GENERAL_PUBLIC_RELAYS;

                if (relaysForPublish.length === 0) {
                    log("No general relays to publish user's location update.");
                    alert("No general relays configured for location updates. Please check relay configuration.");
                    return;
                }

                const pub = nostrPoolInstance.publish(relaysForPublish, signedEvent);
                pub.on('ok', () => { log('✅ Location update published:', signedEvent.id); addChatMessage(`You: ${content}`); });
                pub.on('failed', (reason) => log('❌ Failed to publish location update:', reason));
            } catch (error) { log('Error publishing location update:', error); addChatMessage(`Astrobot: An error occurred while sending your location update.`); }
        }

        async function createLocationDescription() {
            if (!isNostrConnected || !publicKey) { alert('Please connect to Nostr to create a location description.'); return; }
            const description = prompt('Enter a description for this location:');
            if (!description) return;

            const geoKeyNpub = getGeoKeyNpub(currentLatitude, currentLongitude);
            const content = description;
            const event = {
                kind: 1,
                created_at: Math.floor(Date.now() / 1000),
                tags: [
                    ['t', 'uplanet_rpg_location_desc'],
                    ['latitude', currentLatitude.toFixed(6)],
                    ['longitude', currentLongitude.toFixed(6)],
                    ['application', UPLANET_APP_NAME],
                    ['p', geoKeyNpub]
                ],
                content: content,
                pubkey: publicKey
            };

            try {
                let signedEvent;
                if (window.nostr) { signedEvent = await window.nostr.signEvent(event); }
                else if (privateKeyHex) { signedEvent = NostrTools.finishEvent(event, privateKeyHex); }
                else { alert('No signing method available. Cannot publish.'); return; }

                // Publish to general relays only for user-signed events
                const relaysForPublish = GENERAL_PUBLIC_RELAYS;

                if (relaysForPublish.length === 0) {
                    log("No general relays to publish user's location description.");
                    alert("No general relays configured for location descriptions. Please check relay configuration.");
                    return;
                }

                const pub = getNostrPool().publish(relaysForPublish, signedEvent);
                pub.on('ok', () => { log('✅ Location description published:', signedEvent.id); alert('Location description created (published from your key).'); updateCurrentLocation(); });
                pub.on('failed', (reason) => log('❌ Failed to publish location description:', reason));
            } catch (error) { log('Error publishing location description:', error); addChatMessage(`Astrobot: An error occurred while sending your location description.`); }
        }

        async function postEvent() {
            if (!isNostrConnected || !publicKey) { alert('Please connect to Nostr to post.'); return; }
            const message = prompt('Enter your message for this location:');
            if (!message) return;

            const geoKeyNpub = getGeoKeyNpub(currentLatitude, currentLongitude);
            const event = {
                kind: 1,
                created_at: Math.floor(Date.now() / 1000),
                tags: [
                    ['t', 'uplanet_rpg_message'],
                    ['latitude', currentLatitude.toFixed(6)],
                    ['longitude', currentLongitude.toFixed(6)],
                    ['application', UPLANET_APP_NAME],
                    ['p', geoKeyNpub]
                ],
                content: message,
                pubkey: publicKey
            };

            try {
                let signedEvent;
                if (window.nostr) { signedEvent = await window.nostr.signEvent(event); }
                else if (privateKeyHex) { signedEvent = NostrTools.finishEvent(event, privateKeyHex); }
                else { alert('No signing method available. Cannot publish.'); return; }

                // Publish to general relays only for user-signed events
                const relaysForPublish = GENERAL_PUBLIC_RELAYS;

                if (relaysForPublish.length === 0) {
                    log("No general relays to publish user's message.");
                    alert("No general relays configured for messages. Please check relay configuration.");
                    return;
                }

                const pub = getNostrPool().publish(relaysForPublish, signedEvent);
                pub.on('ok', () => { log('✅ Message published:', signedEvent.id); alert('Message posted to this location.'); });
                pub.on('failed', (reason) => log('❌ Failed to publish message:', reason));
            } catch (error) { log('Error publishing message:', error); addChatMessage(`Astrobot: An error occurred while sending your message.`); }
        }

        // --- AI Chat Functions ---
        async function sendChatMessage() {
            const chatInput = $('#chat-input');
            let message = chatInput.val().trim();
            if (!message) return;

            addChatMessage(`You: ${message}`);
            chatInput.val('');

            if (!isNostrConnected || !publicKey) {
                addChatMessage("Astrobot: Please connect to Nostr to chat with me.");
                return;
            }

            // Determine if it's an Astrobot message
            const isAstrobotMessage = message.startsWith('#BRO') || message.startsWith('#BOT');

            if (isAstrobotMessage) {
                // Send AstroBot message via USPOT API
                try {
                    const uspotApiUrl = getUSPOTUrl('/astrobot_chat');
                    log(`Sending AstroBot message to USPOT API: ${uspotApiUrl}`);
                    const response = await fetch(uspotApiUrl, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            user_pubkey: publicKey,
                            message: message,
                            latitude: currentLatitude.toFixed(6),
                            longitude: currentLongitude.toFixed(6),
                            application: UPLANET_APP_NAME
                        })
                    });

                    if (response.ok) {
                        const data = await response.json();
                        if (data.status === 'success' && data.event_id) {
                            log(`✅ AstroBot message sent via USPOT, event ID: ${data.event_id}`);
                            const aiPubkey = manifestData && manifestData.owner_hex_pubkey ? manifestData.owner_hex_pubkey : '21543306915b45155f97379d71c1b3f02e6c43493721cf47f2010839e4a30e87'; // Fallback
                            listenForAIResponse(data.event_id, publicKey, aiPubkey);
                        } else {
                            log(`❌ USPOT API error: ${data.message || 'Unknown error'}`);
                            addChatMessage(`Astrobot: USPOT API error: ${data.message || 'Unknown error'}`);
                        }
                    } else {
                        const errorText = await response.text();
                        log(`❌ USPOT API HTTP error ${response.status}: ${errorText}`);
                        addChatMessage(`Astrobot: Error connecting to USPOT API (${response.status}).`);
                    }
                } catch (error) {
                    log(`Error sending AstroBot message via USPOT: ${error}`);
                    addChatMessage(`Astrobot: An error occurred while contacting the AstroBot service.`);
                }
            } else {
                // Regular Nostr event (user's personal chat/post), publish to general relays
                const event = {
                    kind: 1,
                    created_at: Math.floor(Date.now() / 1000),
                    tags: [
                        ['t', 'uplanet_rpg_chat'], // A more general tag for user chat
                        ['application', UPLANET_APP_NAME],
                        ['latitude', currentLatitude.toFixed(6)],
                        ['longitude', currentLongitude.toFixed(6)]
                    ],
                    content: message,
                    pubkey: publicKey
                };

                try {
                    let signedEvent;
                    if (window.nostr) { signedEvent = await window.nostr.signEvent(event); }
                    else if (privateKeyHex) { signedEvent = NostrTools.finishEvent(event, privateKeyHex); }
                    else { addChatMessage("Astrobot: Error - No signing method available to send your message."); return; }

                    // Publish to general public relays
                    const relaysForPublish = GENERAL_PUBLIC_RELAYS;

                    if (relaysForPublish.length === 0) {
                        addChatMessage("Astrobot: No general relays available for your message. Please check relay configuration.");
                        log("No general relays to publish user's non-AstroBot message.");
                        return;
                    }

                    const pub = getNostrPool().publish(relaysForPublish, signedEvent); // Publish to general relays
                    pub.on('ok', () => {
                        log('✅ General chat message published:', signedEvent.id);
                    });
                    pub.on('failed', (reason) => {
                        log('❌ Failed to publish general chat message:', reason);
                        addChatMessage(`Astrobot: Failed to send your message: ${reason}`);
                    });

                } catch (error) {
                    log('Error sending general chat message:', error);
                    addChatMessage(`Astrobot: An error occurred while sending your message.`);
                }
            }
        }

        function addChatMessage(msg) {
            const chatMessages = $('#chat-messages');
            chatMessages.append(`<p>${msg}</p>`);
            chatMessages.scrollTop(chatMessages[0].scrollHeight);
        }

        function listenForAIResponse(originalEventId, recipientPubkey, aiPubkey) {
            let nostrPoolInstance;
            try { nostrPoolInstance = getNostrPool(); } catch (e) { log("Failed to get Nostr pool in listenForAIResponse."); return; }

            log('Listening for AI response to event:', originalEventId);
            const sub = nostrPoolInstance.sub(allRelaysToPublish, [ // Listen on all configured relays
                {
                    kinds: [1],
                    '#e': [originalEventId],
                    '#p': [recipientPubkey],
                    authors: [aiPubkey]
                }
            ]);

            const timeoutId = setTimeout(() => {
                sub.unsub();
                log('AI response timeout for event:', originalEventId);
                addChatMessage("Astrobot: I'm thinking... or perhaps I didn't understand. Please try again.");
            }, 10000);

            sub.on('event', (event) => {
                clearTimeout(timeoutId);
                addChatMessage(`<strong>Astrobot:</strong> ${event.content}`);
                sub.unsub();
            });
            sub.on('eose', () => { /* EOSE handled by timeout if no event */ });
        }

        // --- Map UI Helper Functions (New streamlined version) ---
        // Initialize map
        function initializeMap(lat = currentLatitude, lon = currentLongitude) { // Use currentLatitude/Longitude defaults
            if (map) { map.remove(); }

            map = L.map('map').setView([lat, lon], 10); // Changed 'mini-map' to 'map'

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors'
            }).addTo(map);

            marker = L.marker([lat, lon], { draggable: true }).addTo(map);

            map.on('click', function(e) {
                const clickedLat = Math.round(e.latlng.lat * 100) / 100;
                const clickedLon = Math.round(e.latlng.lng * 100) / 100;
                updateMapCoordinates(clickedLat, clickedLon);
            });

            marker.on('dragend', function(e) {
                const markerLat = Math.round(e.target.getLatLng().lat * 100) / 100;
                const markerLon = Math.round(e.target.getLatLng().lng * 100) / 100;
                updateMapCoordinates(markerLat, markerLon);
            });

            // Set initial values in the input fields
            $('#lat-display').val(lat.toFixed(2));
            $('#lon-display').val(lon.toFixed(2));
            log(`Map initialized at: ${lat.toFixed(2)}, ${lon.toFixed(2)}`);
        }

        function updateMapCoordinates(lat, lon) {
            const roundedLat = Math.round(lat * 100) / 100;
            const roundedLon = Math.round(lon * 100) / 100;

            $('#lat-display').val(roundedLat.toFixed(2));
            $('#lon-display').val(roundedLon.toFixed(2));

            if (marker) { marker.setLatLng([roundedLat, roundedLon]); }
            if (map) { map.setView([roundedLat, roundedLon], map.getZoom()); }

            currentLatitude = roundedLat;
            currentLongitude = roundedLon;
            log(`Map coordinates updated to: ${roundedLat.toFixed(2)}, ${roundedLon.toFixed(2)}`);
        }

        function getCurrentLocation() { // Renamed from getCurrentLocationForMap
            if (navigator.geolocation) {
                $('#get-location-btn').text('Locating...').prop('disabled', true);

                navigator.geolocation.getCurrentPosition(
                    function(position) {
                        const lat = Math.round(position.coords.latitude * 100) / 100;
                        const lon = Math.round(position.coords.longitude * 100) / 100;

                        updateMapCoordinates(lat, lon);
                        if (map) { map.setView([lat, lon], 13); } // Use 'map'

                        $('#get-location-btn').text('Ma position').prop('disabled', false);
                        promptMove(lat, lon); // Also update game location with publish event
                    },
                    function(error) {
                        let errorMessage = "Geolocation error.";
                        switch(error.code) {
                            case error.PERMISSION_DENIED: errorMessage = "Geolocation denied."; break;
                            case error.POSITION_UNAVAILABLE: errorMessage = "Position unavailable."; break;
                            case error.TIMEOUT: errorMessage = "Geolocation timeout."; break;
                        }
                        log(`Geolocation error: ${errorMessage}`);
                        $('#get-location-btn').text('Ma position').prop('disabled', false);
                    }
                );
            } else {
                log("Geolocation not supported by browser");
            }
        }

        // --- Initialization ---
        async function loadManifestAndInitRPG() {
            $.ajax({
                url: './manifest.json',
                dataType: 'json',
                success: async function(manifest) {
                    log('Manifest loaded:', manifest);
                    manifestData = manifest;

                    // Update LOCAL_ASTROBOT_RELAY from manifest gateway using USPOT derivation logic
                    if (manifestData.my_ipfs_gateway) {
                        const gatewayUrl = new URL(manifestData.my_ipfs_gateway);
                        // Derive the websocket URL for the local relay based on USPOT logic
                        let relayPort = gatewayUrl.port;
                        if (relayPort === "8080") {
                            relayPort = "7777"; // Standard local relay port for strfry
                        } else if (relayPort === "54321") {
                            relayPort = "7777"; // If USPOT port, assume local relay is on 7777
                        }
                        const wsProtocol = gatewayUrl.protocol === 'https:' ? 'wss' : 'ws';
                        LOCAL_ASTROBOT_RELAY = `${wsProtocol}://${gatewayUrl.hostname}:${relayPort}`;
                        log('Derived LOCAL_ASTROBOT_RELAY:', LOCAL_ASTROBOT_RELAY);
                    }

                    // Populate allRelaysToPublish for general subscription
                    // Combine general public relays with the derived local Astrobot relay
                    allRelaysToPublish = [...new Set([...GENERAL_PUBLIC_RELAYS, LOCAL_ASTROBOT_RELAY])];
                    log('Combined allRelaysToPublish for subscription:', allRelaysToPublish);

                    // Initialize the map with default coordinates first
                    initializeMap(currentLatitude, currentLongitude);

                    // Then try to get current actual location
                    getCurrentLocation();

                    // Check Nostr extension or NSEC, then connect
                    if (userNsec) {
                        log("NSEC configured. Attempting local key initialization.");
                        try {
                            const decoded = NostrTools.nip19.decode(userNsec);
                            if (decoded.type !== 'nsec' || !decoded.data) throw new Error('Invalid NSEC format');
                            privateKeyHex = decoded.data;
                            publicKey = NostrTools.getPublicKey(privateKeyHex);
                            log(`NSEC init OK. Pubkey: ${publicKey.slice(0, 10)}...`);
                            await connectToNostr();
                        } catch (e) {
                            log(`Error initializing NSEC: ${e.message}.`);
                            alert('Error with provided NSEC key. Please check console.');
                            checkNostrExtension(); // Fallback to extension check
                        }
                    } else {
                        log("No NSEC configured. Checking for Nostr extension.");
                        checkNostrExtension();
                        await connectToNostr(); // Attempt connection using extension or prompt for NSEC
                    }
                },
                error: function(xhr, status, error) {
                    log('Error loading manifest: ' + error);
                    alert('Error loading manifest.json. Please ensure it exists and is valid JSON. Falling back to default settings.');
                    initializeMap(currentLatitude, currentLongitude); // Initialize map even on manifest error
                    getCurrentLocation(); // Still try to get current location
                    checkNostrExtension();
                    connectToNostr(); // Still try to connect Nostr
                }
            });
        }

        // Call this once on page load to check for Nostr extension
        function checkNostrExtension() {
            log('Checking for Nostr browser extension (NIP-07)...');
            if (typeof window.nostr !== 'undefined') {
                nostrExtensionAvailable = true;
                log('Nostr extension detected.');
            } else {
                nostrExtensionAvailable = false;
                log('Nostr extension not found.');
            }
        }

        // Setup common event listeners
        function setupEventListeners() {
            $('#connect-btn').on('click', connectToNostr);
            $('#chat-send-btn').on('click', sendChatMessage);
            $('#chat-input').keypress(function(e) { if (e.which == 13) { sendChatMessage(); } });
            $('#move-btn').on('click', function() { promptMove(currentLatitude, currentLongitude); }); // Use current coords
            $('#create-location-btn').on('click', createLocationDescription);
            $('#post-event-btn').on('click', postEvent);

            // Collapsible sections
            $('.section-header').click(function() {
                const target = $(this).data('target');
                const content = $('#' + target);
                $(this).toggleClass('collapsed');
                content.toggleClass('collapsed');
            });

            // Map event listeners (new elements)
            $('#update-map-btn').on('click', function() {
                const lat = parseFloat($('#lat-display').val());
                const lon = parseFloat($('#lon-display').val());
                if (!isNaN(lat) && !isNaN(lon)) {
                    updateMapCoordinates(lat, lon);
                    promptMove(lat, lon); // Update game location
                } else {
                    alert('Please enter valid numerical coordinates.');
                }
            });
            $('#get-location-btn').on('click', getCurrentLocation);

            // NEW: Astrobot Tag Button Handlers
            $('#astrobot-tag-buttons .chat-tag-button').on('click', function() {
                const tag = $(this).data('tag');
                const textarea = $('#chat-input');
                let currentText = textarea.val().trim();

                // Toggle the tag
                if (currentText.includes(tag)) {
                    // Remove the tag if it exists
                    currentText = currentText.replace(tag, '').trim();
                    $(this).removeClass('active');
                } else {
                    // Add the tag if it doesn't exist
                    currentText = (currentText ? currentText + ' ' : '') + tag;
                    $(this).addClass('active');
                }
                textarea.val(currentText);

                // If IA tag is removed, hide other tags
                if (tag === '#BRO') {
                    if (!$(this).hasClass('active')) {
                        $('.chat-sub-tags').removeClass('show');
                    } else {
                        $('.chat-sub-tags').addClass('show');
                    }
                }
            });

            // Update tag buttons on chat input change
            $('#chat-input').on('input', function() {
                const text = $(this).val();
                $('#astrobot-tag-buttons .chat-tag-button').each(function() {
                    const tag = $(this).data('tag');
                    const isActive = text.includes(tag);
                    $(this).toggleClass('active', isActive);

                    if (tag === '#BRO') {
                        $('.chat-sub-tags').toggleClass('show', isActive);
                    }
                });
            });
            // END NEW: Astrobot Tag Button Handlers
        }
    </script>
</body>
</html>
HTML_EOF

log_message "✅ _index.html pour le Geo-RPG généré dans $SOURCE_DIR/_index.html"

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
    <title>UPlanet IPFS RPG Explorer</title>
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
    <title>UPlanet IPFS RPG Explorer</title>
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
log_message "🎉 Structure IPFS Geo-RPG générée avec succès!"
log_message ""
log_message "📋 Fichiers créés:"
log_message "  - manifest.json (structure optimisée avec liens IPFS individuels pour le RPG)"
log_message "  - _index.html (interface Geo-RPG avec chargement du manifest)"
log_message "  - index.html (redirection vers _index.html)"
log_message ""
log_message "🔧 Nouvelles fonctionnalités ajoutées:"
log_message "  - ⚡ Mise à jour incrémentale des fichiers du jeu (seuls les fichiers modifiés sont re-ajoutés à IPFS)"
log_message "  - 🔗 Liens IPFS individuels pour chaque fichier du jeu"
log_message "  - 📝 Manifest.json centralisé pour les données du jeu"
log_message "  - ⚙️  Détection automatique de la passerelle IPFS et du relai Nostr à partir du manifest"
log_message "  - 🌍 Système de localisation par 'tumblers' et carte Leaflet interactive"
log_message "  - 🤖 Chat AstroBot intégré via Nostr avec gestion de la clé propriétaire"
log_message "  - 🔑 Gestion de la connexion Nostr (extension NIP-07 ou NSEC) et affichage du profil/soldes"
log_message ""
log_message "📊 Statistiques de cette exécution:"
log_message "  - $updated_count fichier(s) ajouté(s) ou mis à jour dans IPFS"
log_message "  - $cached_count fichier(s) inchangé(s) (utilisent le cache)"
log_message "  - $deleted_count fichier(s) supprimé(s)"
log_message ""
log_message "🌐 Accès à l'application:"
log_message "  - URL IPFS: http://127.0.0.1:8080/ipfs/$FINAL_CID/"
log_message "  - CID: $FINAL_CID"
log_message ""
log_message "💡 Conseils:"
log_message "  - Réexécutez ce script après modification de fichiers du jeu pour une mise à jour incrémentale automatique!"
log_message "  - Assurez-vous que votre relai Nostr (strfry) tourne et est accessible sur le port 7777 de votre gateway IPFS."
log_message "  - La logique du jeu (mouvement, création, interaction) est gérée par les événements Nostr. Le script génère les événements, votre backend (ex: UPassport) devra les traiter."
