#!/bin/bash
########################################################################
# sync_youtube_likes.sh
# Script de synchronisation des vidéos YouTube likées pour les sociétaires
#
# Usage: $0 <player_email> [--debug]
#
# Fonctionnalités:
# - Récupère les vidéos likées depuis la dernière synchronisation (max 3 par run)
# - Utilise les cookies du sociétaire pour l'authentification YouTube
# - Télécharge les nouvelles vidéos via process_youtube.sh
# - Organise les vidéos dans uDRIVE/Music/ et uDRIVE/Videos/
# - Met à jour le fichier de dernière synchronisation
########################################################################

# Enhanced logging setup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting sync_youtube_likes.sh script" >&2

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

if [[ -f "$HOME/.zen/Astroport.ONE/tools/my.sh" ]]; then
    source "$HOME/.zen/Astroport.ONE/tools/my.sh"
else
    exit 1
fi

DEBUG=0
if [[ "$1" == "--debug" ]]; then
    DEBUG=1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG mode enabled" >&2
fi

# Force debug mode for uDRIVE checking
if [[ "$1" == "--debug-udrive" ]]; then
    DEBUG=1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG mode enabled for uDRIVE checking" >&2
fi

PLAYER="$1"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Player email: $PLAYER" >&2

if [[ -z "$PLAYER" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No player email provided" >&2
    echo "Usage: $0 <player_email> [--debug]"
    exit 1
fi

LOGFILE="$HOME/.zen/tmp/IA.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file: $LOGFILE" >&2
mkdir -p "$(dirname "$LOGFILE")"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Created log directory: $(dirname "$LOGFILE")" >&2

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "[sync_youtube_likes.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
    fi
}

# Enhanced logging for all checks
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting validation checks for player: $PLAYER" >&2

# Vérifier que le joueur est sociétaire (optionnel - maintenant ouvert à tous)
# if [[ ! -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
#     log_debug "Player $PLAYER is not a society member, skipping YouTube sync"
#     exit 0
# fi

# Vérifier l'existence du fichier cookie
COOKIE_FILE="$HOME/.zen/game/nostr/${PLAYER}/.cookie.txt"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking cookie file: $COOKIE_FILE" >&2
if [[ ! -f "$COOKIE_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No cookie file found for $PLAYER at $COOKIE_FILE" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking if directory exists: $(dirname "$COOKIE_FILE")" >&2
    if [[ -d "$(dirname "$COOKIE_FILE")" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Directory exists, listing contents:" >&2
        ls -la "$(dirname "$COOKIE_FILE")" >&2
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Directory does not exist: $(dirname "$COOKIE_FILE")" >&2
    fi
    log_debug "No cookie file found for $PLAYER, skipping YouTube sync"
    exit 0
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cookie file found: $COOKIE_FILE" >&2

# Vérifier l'existence du répertoire uDRIVE
UDRIVE_PATH="$HOME/.zen/game/nostr/${PLAYER}/APP/uDRIVE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking uDRIVE directory: $UDRIVE_PATH" >&2
if [[ ! -d "$UDRIVE_PATH" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] uDRIVE directory not found for $PLAYER, creating it" >&2
    mkdir -p "$UDRIVE_PATH"
    if [[ $? -eq 0 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully created uDRIVE directory: $UDRIVE_PATH" >&2
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to create uDRIVE directory: $UDRIVE_PATH" >&2
        exit 1
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] uDRIVE directory exists: $UDRIVE_PATH" >&2
fi

# Fichier de suivi de la dernière synchronisation
LAST_SYNC_FILE="$HOME/.zen/game/nostr/${PLAYER}/.last_youtube_sync"
# Fichier de suivi des vidéos déjà traitées
PROCESSED_VIDEOS_FILE="$HOME/.zen/game/nostr/${PLAYER}/.processed_youtube_videos"
TODAY=$(date '+%Y-%m-%d')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Today's date: $TODAY" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Last sync file: $LAST_SYNC_FILE" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processed videos file: $PROCESSED_VIDEOS_FILE" >&2

# Vérifier si une synchronisation a déjà eu lieu aujourd'hui
if [[ -f "$LAST_SYNC_FILE" ]]; then
    LAST_SYNC=$(cat "$LAST_SYNC_FILE")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Last sync date: $LAST_SYNC" >&2
    if [[ "$LAST_SYNC" == "$TODAY" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] YouTube sync already completed today for $PLAYER" >&2
        log_debug "YouTube sync already completed today for $PLAYER"
        exit 0
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No previous sync file found for $PLAYER" >&2
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting YouTube likes sync for $PLAYER" >&2
log_debug "Starting YouTube likes sync for $PLAYER"

# Fonction pour vérifier si une vidéo a déjà été traitée
is_video_processed() {
    local video_id="$1"
    local processed_file="$2"
    
    if [[ ! -f "$processed_file" ]]; then
        return 1  # Fichier n'existe pas, vidéo pas traitée
    fi
    
    # Vérifier si l'ID de la vidéo est dans le fichier
    if grep -q "^$video_id$" "$processed_file" 2>/dev/null; then
        return 0  # Vidéo déjà traitée
    else
        return 1  # Vidéo pas encore traitée
    fi
}

# Fonction pour marquer une vidéo comme traitée
mark_video_processed() {
    local video_id="$1"
    local processed_file="$2"
    
    # Créer le fichier s'il n'existe pas
    if [[ ! -f "$processed_file" ]]; then
        touch "$processed_file"
        chmod 600 "$processed_file"
    fi
    
    # Ajouter l'ID de la vidéo au fichier
    echo "$video_id" >> "$processed_file"
    log_debug "Marked video $video_id as processed"
}

# Fonction pour vérifier si une vidéo existe déjà dans uDRIVE
check_video_exists_in_udrive() {
    local video_id="$1"
    local title="$2"
    local player="$3"
    
    # Encoder le titre pour correspondre au nom de fichier
    local url_safe_title=$(url_encode_title "$title")
    
    log_debug "Checking if video exists in uDRIVE: ID=$video_id, title=$url_safe_title"
    
    # Vérifier dans le répertoire Videos
    local udrive_videos="$HOME/.zen/game/nostr/${player}/APP/uDRIVE/Videos"
    if [[ -d "$udrive_videos" ]]; then
        log_debug "Searching in Videos directory: $udrive_videos"
        # Chercher des fichiers qui contiennent l'ID de la vidéo ou le titre
        local found_files=$(find "$udrive_videos" -name "*${video_id}*" -o -name "*${url_safe_title}*" 2>/dev/null)
        if [[ -n "$found_files" ]]; then
            log_debug "Video $video_id already exists in uDRIVE/Videos: $found_files"
            return 0
        fi
        
        # Recherche plus large avec des parties du titre
        local title_parts=$(echo "$url_safe_title" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) if(length($i)>3) print $i}' | head -3)
        for part in $title_parts; do
            if [[ -n "$part" ]]; then
                local found_files=$(find "$udrive_videos" -name "*${part}*" 2>/dev/null)
                if [[ -n "$found_files" ]]; then
                    log_debug "Video found by title part '$part' in uDRIVE/Videos: $found_files"
                    return 0
                fi
            fi
        done
    else
        log_debug "Videos directory does not exist: $udrive_videos"
    fi
    
    # Vérifier dans le répertoire Music (pour les vidéos musicales)
    local udrive_music="$HOME/.zen/game/nostr/${player}/APP/uDRIVE/Music"
    if [[ -d "$udrive_music" ]]; then
        log_debug "Searching in Music directory: $udrive_music"
        local found_files=$(find "$udrive_music" -name "*${video_id}*" -o -name "*${url_safe_title}*" 2>/dev/null)
        if [[ -n "$found_files" ]]; then
            log_debug "Video $video_id already exists in uDRIVE/Music: $found_files"
            return 0
        fi
    else
        log_debug "Music directory does not exist: $udrive_music"
    fi
    
    log_debug "Video $video_id not found in uDRIVE"
    return 1
}

# Fonction pour nettoyer les anciennes entrées (garder seulement les 100 dernières)
cleanup_processed_videos() {
    local processed_file="$1"
    
    if [[ -f "$processed_file" ]]; then
        # Garder seulement les 100 dernières entrées
        tail -n 100 "$processed_file" > "${processed_file}.tmp" && mv "${processed_file}.tmp" "$processed_file"
        log_debug "Cleaned up processed videos database (kept last 100 entries)"
    fi
}

# Fonction pour récupérer les vidéos likées via l'API YouTube
get_liked_videos() {
    local player="$1"
    local cookie_file="$2"
    local max_results="${3:-3}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] get_liked_videos: Starting for $player (max: $max_results)" >&2
    log_debug "Fetching liked videos for $player (max: $max_results)"
    
    # Vérifier que yt-dlp est disponible
    if ! command -v yt-dlp &> /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: yt-dlp command not found" >&2
        return 1
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] yt-dlp command found" >&2
    
    # Utiliser yt-dlp pour récupérer la playlist "Liked videos"
    # La playlist "LL" correspond aux vidéos likées
    local liked_playlist_url="https://www.youtube.com/playlist?list=LL"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying liked videos playlist: $liked_playlist_url" >&2
    
    # Récupérer les métadonnées des vidéos likées avec gestion d'erreur améliorée
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running yt-dlp command..." >&2
    local videos_json=$(yt-dlp \
        --cookies "$cookie_file" \
        --print '%(id)s&%(title)s&%(duration)s&%(uploader)s&%(webpage_url)s' \
        --playlist-end "$max_results" \
        --no-warnings \
        --quiet \
        "$liked_playlist_url" 2>/dev/null)
    
    local exit_code=$?
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] yt-dlp exit code: $exit_code" >&2
    
    if [[ $exit_code -eq 0 && -n "$videos_json" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully fetched liked videos" >&2
        echo "$videos_json"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to fetch liked videos (exit code: $exit_code)" >&2
        log_debug "Failed to fetch liked videos for $player (exit code: $exit_code)"
        # Essayer une approche alternative avec l'historique
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying alternative approach with watch history" >&2
        log_debug "Trying alternative approach with watch history"
        local history_url="https://www.youtube.com/feed/history"
        videos_json=$(yt-dlp \
            --cookies "$cookie_file" \
            --print '%(id)s&%(title)s&%(duration)s&%(uploader)s&%(webpage_url)s' \
            --playlist-end "$max_results" \
            --no-warnings \
            --quiet \
            "$history_url" 2>/dev/null)
        
        local alt_exit_code=$?
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Alternative yt-dlp exit code: $alt_exit_code" >&2
        
        if [[ $alt_exit_code -eq 0 && -n "$videos_json" ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully fetched from watch history" >&2
            echo "$videos_json"
            return 0
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Alternative approach also failed" >&2
            log_debug "Alternative approach also failed for $player"
            return 1
        fi
    fi
}

# Fonction pour encoder un titre en URL-safe
url_encode_title() {
    local title="$1"
    # Remplacer les caractères spéciaux par des équivalents URL-safe
    echo "$title" | sed 's/ /_/g' | \
        sed 's/[^a-zA-Z0-9._-]/_/g' | \
        sed 's/__*/_/g' | \
        sed 's/^_\|_$//g' | \
        head -c 100
}

# Fonction pour envoyer une note NOSTR pour une vidéo synchronisée
send_nostr_note() {
    local player="$1"
    local title="$2"
    local uploader="$3"
    local ipfs_url="$4"
    local youtube_url="$5"
    
    log_debug "Sending NOSTR note for video: $title"
    
    # Vérifier que le script nostr_send_note.py existe
    local nostr_script="$MY_PATH/../tools/nostr_send_note.py"
    if [[ ! -f "$nostr_script" ]]; then
        log_debug "NOSTR script not found: $nostr_script"
        return 1
    fi
    
    # Vérifier que le fichier NSEC existe pour ce joueur
    local nsec_file="$HOME/.zen/game/nostr/${player}/.nsec"
    if [[ ! -f "$nsec_file" ]]; then
        log_debug "NSEC file not found for $player: $nsec_file"
        return 1
    fi
    
    # Lire la clé NSEC
    local nsec_key=$(cat "$nsec_file" 2>/dev/null)
    if [[ -z "$nsec_key" ]]; then
        log_debug "Failed to read NSEC key for $player"
        return 1
    fi
    
    # Construire le message NOSTR
    local message="🎬 Nouvelle vidéo synchronisée: $title par $uploader

🔗 IPFS: $ipfs_url
📺 YouTube: $youtube_url

#YouTubeSync #uDRIVE #IPFS"
    
    # Envoyer la note NOSTR
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sending NOSTR note for: $title" >&2
    local nostr_result=$(python3 "$nostr_script" "$nsec_key" "$message" "ws://127.0.0.1:7777" 2>&1)
    local nostr_exit_code=$?
    
    if [[ $nostr_exit_code -eq 0 ]]; then
        log_debug "NOSTR note sent successfully for: $title"
        echo "📡 NOSTR note published for: $title"
    else
        log_debug "Failed to send NOSTR note for: $title (exit code: $nostr_exit_code)"
        echo "⚠️ NOSTR note failed for: $title"
    fi
    
    return $nostr_exit_code
}

# Fonction pour traiter une vidéo likée
process_liked_video() {
    local video_id="$1"
    local title="$2"
    local duration="$3"
    local uploader="$4"
    local url="$5"
    local player="$6"
    local processed_file="$7"
    
    log_debug "Processing liked video: $title by $uploader (ID: $video_id)"
    
    # Vérifier si la vidéo a déjà été traitée
    if is_video_processed "$video_id" "$processed_file"; then
        log_debug "Video $video_id already processed, skipping"
        echo "⏭️ Skipping already processed video: $title"
        return 0
    fi
    
    # Vérifier si la vidéo existe déjà dans uDRIVE
    if check_video_exists_in_udrive "$video_id" "$title" "$player"; then
        log_debug "Video $video_id already exists in uDRIVE, marking as processed"
        echo "📁 Video already exists in uDRIVE: $title"
        mark_video_processed "$video_id" "$processed_file"
        return 2  # Code spécial pour vidéo existante (ne compte pas comme succès)
    fi
    
    # Encoder le titre pour compatibilité URL maximale
    local url_safe_title=$(url_encode_title "$title")
    log_debug "URL-safe title: $url_safe_title"
    
    # Utiliser uniquement le format MP4 pour toutes les vidéos
    local format="mp4"
    
    # Appeler process_youtube.sh pour télécharger la vidéo avec métadonnées pré-extraites
    local metadata_string="${video_id}&${title}&${duration}&${uploader}"
    log_debug "Calling process_youtube.sh with pre-extracted metadata: $url $format $player"
    log_debug "Metadata string: $metadata_string"
    local result=$($MY_PATH/process_youtube.sh --debug "$url" "$format" "$player" --metadata "$metadata_string" 2>&1)
    local process_exit_code=$?
    log_debug "process_youtube.sh exit code: $process_exit_code"
    log_debug "process_youtube.sh output: $result"
    
    if [[ $process_exit_code -eq 0 ]]; then
        # Extraire l'URL IPFS du résultat JSON
        local ipfs_url=$(echo "$result" | jq -r '.ipfs_url // empty' 2>/dev/null)
        log_debug "Extracted IPFS URL: '$ipfs_url'"
        log_debug "Raw result: $result"
        if [[ -n "$ipfs_url" ]]; then
            log_debug "Successfully processed: $url_safe_title -> $ipfs_url"
            echo "✅ $url_safe_title by $uploader -> $ipfs_url"
            
            # Marquer la vidéo comme traitée
            mark_video_processed "$video_id" "$processed_file"
            
            return 0
        else
            log_debug "Failed to extract IPFS URL for: $url_safe_title"
            echo "❌ Failed to process: $url_safe_title"
            return 1
        fi
    else
        log_debug "process_youtube.sh failed for: $url_safe_title"
        echo "❌ Download failed: $url_safe_title"
        
        # Vérifier si la vidéo existe quand même dans uDRIVE (peut-être téléchargée précédemment)
        if check_video_exists_in_udrive "$video_id" "$title" "$player"; then
            log_debug "Video $video_id exists in uDRIVE despite download failure, marking as processed"
            echo "📁 Video found in uDRIVE despite download failure: $title"
            mark_video_processed "$video_id" "$processed_file"
            return 2  # Code spécial pour vidéo existante
        fi
        
        return 1
    fi
}

# Fonction principale de synchronisation
sync_youtube_likes() {
    local player="$1"
    local cookie_file="$2"
    local processed_file="$3"
    
    log_debug "Starting YouTube likes synchronization for $player"
    
    # Nettoyer les anciennes entrées de la base de données
    cleanup_processed_videos "$processed_file"
    
    # Récupérer les vidéos likées (récupérer plus pour avoir 3 nouvelles)
    local liked_videos=$(get_liked_videos "$player" "$cookie_file" 15)
    
    if [[ $? -ne 0 || -z "$liked_videos" ]]; then
        log_debug "No liked videos found or failed to fetch for $player"
        return 1
    fi
    
    local processed_count=0
    local success_count=0
    local skipped_count=0
    local failed_count=0
    
    # Compter le nombre total de vidéos déjà traitées
    local total_processed=0
    if [[ -f "$processed_file" ]]; then
        total_processed=$(wc -l < "$processed_file" 2>/dev/null || echo "0")
    fi
    log_debug "Total videos already processed: $total_processed"
    
    # Traiter chaque vidéo likée jusqu'à avoir 3 succès
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Arrêter si on a déjà 3 succès
            if [[ $success_count -ge 3 ]]; then
                echo "🎯 Reached target of 3 successful downloads, stopping"
                log_debug "Reached target of 3 successful downloads, stopping"
                break
            fi
            
            # Parser les données de la vidéo
            local video_id=$(echo "$line" | cut -d '&' -f 1)
            local title=$(echo "$line" | cut -d '&' -f 2)
            local duration=$(echo "$line" | cut -d '&' -f 3)
            local uploader=$(echo "$line" | cut -d '&' -f 4)
            local url=$(echo "$line" | cut -d '&' -f 5)
            
            # Nettoyer le titre pour compatibilité URL
            title=$(echo "$title" | \
                sed 's/[^a-zA-Z0-9._-]/_/g' | \
                sed 's/__*/_/g' | \
                sed 's/^_\|_$//g' | \
                head -c 100)
            
            log_debug "Processing: $title (ID: $video_id)"
            
            # Vérifier si la vidéo a déjà été traitée avant de lancer le traitement
            if is_video_processed "$video_id" "$processed_file"; then
                skipped_count=$((skipped_count + 1))
                log_debug "Skipping already processed video: $title (ID: $video_id)"
                echo "⏭️ Skipping already processed: $title"
            else
                # Traiter la vidéo
                echo "🔄 Processing video: $title (ID: $video_id)"
                process_liked_video "$video_id" "$title" "$duration" "$uploader" "$url" "$player" "$processed_file"
                local process_exit_code=$?
                echo "🔍 Process exit code: $process_exit_code"
                
                if [[ $process_exit_code -eq 0 ]]; then
                    # Nouvelle vidéo téléchargée avec succès
                    success_count=$((success_count + 1))
                    processed_count=$((processed_count + 1))
                    echo "✅ Success count: $success_count/3"
                    log_debug "Success count: $success_count/3"
                elif [[ $process_exit_code -eq 2 ]]; then
                    # Vidéo existante trouvée (ne compte pas comme succès)
                    skipped_count=$((skipped_count + 1))
                    echo "📁 Video already exists, continuing search... (skipped: $skipped_count)"
                    log_debug "Video already exists, continuing search..."
                else
                    # Échec du téléchargement
                    failed_count=$((failed_count + 1))
                    echo "❌ Failed count: $failed_count"
                fi
            fi
            
            # Pause entre les téléchargements pour éviter la surcharge et la détection
            local delay_time=$((5 + RANDOM % 10))  # Random delay between 5-15 seconds
            log_debug "Waiting ${delay_time}s before next video to avoid detection"
            sleep $delay_time
        fi
    done <<< "$liked_videos"
    
    log_debug "YouTube sync completed for $player: $success_count successful, $failed_count failed, $skipped_count skipped"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sync stats: $success_count successful, $skipped_count skipped" >&2
    
    # Mettre à jour le fichier de dernière synchronisation
    echo "$TODAY" > "$LAST_SYNC_FILE"
    
    # Envoyer une notification par email si des vidéos ont été traitées
    if [[ $success_count -gt 0 ]]; then
        send_sync_notification "$player" "$success_count" "$failed_count" "$skipped_count"
    fi
    
    return 0
}

# Fonction d'envoi de notification par email
send_sync_notification() {
    local player="$1"
    local success_count="$2"
    local failed_count="$3"
    local skipped_count="$4"
    
    log_debug "Sending sync notification to $player: $success_count successful, $failed_count failed, $skipped_count skipped"
    
    # Créer le contenu HTML de la notification
    local email_content="<html><head><meta charset='UTF-8'>
    <title>🎵 YouTube Synchronisation Complétée</title>
<style>
    body { font-family: 'Courier New', monospace; background: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0; margin: -20px -20px 20px -20px; }
    .content { padding: 20px 0; }
    .stats { background: #e8f4fd; padding: 15px; border-radius: 5px; margin: 15px 0; }
    .footer { margin-top: 20px; padding-top: 15px; border-top: 1px solid #eee; font-size: 12px; color: #666; }
</style></head><body>
<div class='container'>
    <div class='header'>
        <h2>🎵 YouTube Synchronisation Complétée</h2>
        <p>Vos vidéos likées ont été synchronisées avec succès !</p>
    </div>
    <div class='content'>
        <div class='stats'>
            <h3>📊 Statistiques de synchronisation</h3>
            <p><strong>Nouvelles vidéos téléchargées :</strong> $success_count</p>
            <p><strong>Vidéos déjà synchronisées :</strong> $skipped_count</p>
            <p><strong>Date :</strong> $(date '+%d/%m/%Y à %H:%M')</p>
        </div>
        <p>Vos nouvelles vidéos sont maintenant disponibles dans votre uDRIVE :</p>
        <ul>
            <li>🎬 <strong>Vidéos :</strong> uDRIVE/Videos/ (format MP4)</li>
        </ul>
        <p><strong>🔗 Accéder à votre uDRIVE :</strong> <a href="$myIPFS$(cat ~/.zen/game/nostr/${player}/NOSTRNS 2>/dev/null || echo 'NOSTRNS_NOT_FOUND')/${player}/APP/uDRIVE/" target="_blank">Ouvrir uDRIVE</a></p>
        <p>Les vidéos sont également accessibles via IPFS pour un partage décentralisé.</p>
    </div>
    <div class='footer'>
        <p>Cette synchronisation est automatique pour tous les utilisateurs UPlanet avec <a href="$uSPOT/cookie" target="_blank">cookie YouTube</a>.</p>
    </div>
</div>
</body></html>"

    # Créer un fichier temporaire pour le contenu HTML
    local temp_email_file="$HOME/.zen/tmp/youtube_sync_email_$(date +%Y%m%d_%H%M%S).html"
    echo "$email_content" > "$temp_email_file"
    
    # Envoyer l'email via mailjet avec durée éphémère de 24h
    ${MY_PATH}/../tools/mailjet.sh --expire 24h "${player}" "$temp_email_file" "🎵 YouTube Sync - $success_count nouvelles vidéos" 2>/dev/null
    
    # Nettoyer le fichier temporaire
    rm -f "$temp_email_file"
    
    if [[ $? -eq 0 ]]; then
        log_debug "Sync notification sent successfully to $player"
    else
        log_debug "Failed to send sync notification to $player"
    fi
}

# Fonction de nettoyage des anciens processus
cleanup_old_sync_processes() {
    local player="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] cleanup_old_sync_processes: Starting for $player" >&2
    log_debug "Cleaning up old YouTube sync processes for $player"
    
    # Nettoyer les fichiers temporaires
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning temporary files..." >&2
    rm -f "$HOME/.zen/tmp/youtube_sync_${player}_*" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] cleanup_old_sync_processes: Completed" >&2
}

# Fonction de vérification de l'espace disque
check_disk_space() {
    local udrive_path="$1"
    local required_space_mb=1000  # 1GB minimum
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] check_disk_space: Starting for $udrive_path" >&2
    
    if [[ -d "$udrive_path" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Directory exists, checking disk space..." >&2
        local available_space=$(df "$udrive_path" | awk 'NR==2 {print $4}')
        local available_mb=$((available_space / 1024))
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Available space: ${available_mb}MB, Required: ${required_space_mb}MB" >&2
        
        if [[ $available_mb -lt $required_space_mb ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Insufficient disk space" >&2
            log_debug "Insufficient disk space: ${available_mb}MB available, ${required_space_mb}MB required"
            return 1
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Disk space check passed" >&2
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Directory does not exist, skipping disk space check" >&2
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] check_disk_space: Completed" >&2
    return 0
}

# Exécution principale
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== MAIN EXECUTION START =====" >&2
log_debug "Starting YouTube likes sync for sociétaire: $PLAYER"
log_debug "Cookie file: $COOKIE_FILE"
log_debug "uDRIVE path: $UDRIVE_PATH"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up old sync processes for $PLAYER" >&2
# Nettoyer les anciens processus
cleanup_old_sync_processes "$PLAYER"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking disk space for $UDRIVE_PATH" >&2
# Vérifier l'espace disque
if ! check_disk_space "$UDRIVE_PATH"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Insufficient disk space, skipping YouTube sync for $PLAYER" >&2
    log_debug "Insufficient disk space, skipping YouTube sync for $PLAYER"
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Disk space check passed" >&2

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting YouTube likes synchronization..." >&2
# Lancer la synchronisation
if sync_youtube_likes "$PLAYER" "$COOKIE_FILE" "$PROCESSED_VIDEOS_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: YouTube likes sync completed successfully for $PLAYER" >&2
    log_debug "YouTube likes sync completed successfully for $PLAYER"
    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: YouTube likes sync failed for $PLAYER" >&2
    log_debug "YouTube likes sync failed for $PLAYER"
    exit 1
fi
