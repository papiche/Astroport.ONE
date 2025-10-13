#!/bin/bash
########################################################################
# sync_youtube_likes.sh
# Script de synchronisation des vidéos YouTube likées pour les sociétaires
#
# Usage: $0 <player_email> [--debug]
#
# Fonctionnalités:
# - Récupère les vidéos likées depuis la dernière synchronisation
# - Utilise les cookies du sociétaire pour l'authentification YouTube
# - Télécharge les nouvelles vidéos via process_youtube.sh
# - Organise les vidéos dans uDRIVE/Music/ et uDRIVE/Videos/
# - Met à jour le fichier de dernière synchronisation
########################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
source "$HOME/.zen/Astroport.ONE/tools/my.sh"

DEBUG=0
if [[ "$1" == "--debug" ]]; then
    DEBUG=1
    shift
fi

PLAYER="$1"
if [[ -z "$PLAYER" ]]; then
    echo "Usage: $0 <player_email> [--debug]"
    exit 1
fi

LOGFILE="$HOME/.zen/tmp/youtube_sync.log"
mkdir -p "$(dirname "$LOGFILE")"

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "[sync_youtube_likes.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
    fi
}

# Vérifier que le joueur est sociétaire
if [[ ! -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
    log_debug "Player $PLAYER is not a society member, skipping YouTube sync"
    exit 0
fi

# Vérifier l'existence du fichier cookie
COOKIE_FILE="$HOME/.zen/game/nostr/${PLAYER}/.cookie.txt"
if [[ ! -f "$COOKIE_FILE" ]]; then
    log_debug "No cookie file found for $PLAYER, skipping YouTube sync"
    exit 0
fi

# Vérifier l'existence du répertoire uDRIVE
UDRIVE_PATH="$HOME/.zen/game/nostr/${PLAYER}/APP/uDRIVE"
if [[ ! -d "$UDRIVE_PATH" ]]; then
    log_debug "uDRIVE directory not found for $PLAYER, creating it"
    mkdir -p "$UDRIVE_PATH"
fi

# Fichier de suivi de la dernière synchronisation
LAST_SYNC_FILE="$HOME/.zen/game/nostr/${PLAYER}/.last_youtube_sync"
TODAY=$(date '+%Y-%m-%d')

# Vérifier si une synchronisation a déjà eu lieu aujourd'hui
if [[ -f "$LAST_SYNC_FILE" ]]; then
    LAST_SYNC=$(cat "$LAST_SYNC_FILE")
    if [[ "$LAST_SYNC" == "$TODAY" ]]; then
        log_debug "YouTube sync already completed today for $PLAYER"
        exit 0
    fi
fi

log_debug "Starting YouTube likes sync for $PLAYER"

# Fonction pour récupérer les vidéos likées via l'API YouTube
get_liked_videos() {
    local player="$1"
    local cookie_file="$2"
    local max_results="${3:-20}"
    
    log_debug "Fetching liked videos for $player (max: $max_results)"
    
    # Utiliser yt-dlp pour récupérer la playlist "Liked videos"
    # La playlist "LL" correspond aux vidéos likées
    local liked_playlist_url="https://www.youtube.com/playlist?list=LL"
    
    # Récupérer les métadonnées des vidéos likées avec gestion d'erreur améliorée
    local videos_json=$(yt-dlp \
        --cookies "$cookie_file" \
        --print '%(id)s&%(title)s&%(duration)s&%(uploader)s&%(webpage_url)s' \
        --playlist-end "$max_results" \
        --no-warnings \
        --quiet \
        "$liked_playlist_url" 2>/dev/null)
    
    local exit_code=$?
    if [[ $exit_code -eq 0 && -n "$videos_json" ]]; then
        echo "$videos_json"
        return 0
    else
        log_debug "Failed to fetch liked videos for $player (exit code: $exit_code)"
        # Essayer une approche alternative avec l'historique
        log_debug "Trying alternative approach with watch history"
        local history_url="https://www.youtube.com/feed/history"
        videos_json=$(yt-dlp \
            --cookies "$cookie_file" \
            --print '%(id)s&%(title)s&%(duration)s&%(uploader)s&%(webpage_url)s' \
            --playlist-end "$max_results" \
            --no-warnings \
            --quiet \
            "$history_url" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$videos_json" ]]; then
            echo "$videos_json"
            return 0
        else
            log_debug "Alternative approach also failed for $player"
            return 1
        fi
    fi
}

# Fonction pour traiter une vidéo likée
process_liked_video() {
    local video_id="$1"
    local title="$2"
    local duration="$3"
    local uploader="$4"
    local url="$5"
    local player="$6"
    local udrive_path="$7"
    
    log_debug "Processing liked video: $title by $uploader"
    
    # Déterminer le format basé sur la durée et le type de contenu
    local format="mp4"
    if [[ "$duration" =~ ^[0-9]+$ ]] && [[ "$duration" -lt 600 ]]; then
        # Vidéos courtes (< 10 min) - probablement de la musique
        format="mp3"
    fi
    
    # Appeler process_youtube.sh pour télécharger la vidéo
    local result=$($MY_PATH/process_youtube.sh --debug "$url" "$format" "$udrive_path" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Extraire l'URL IPFS du résultat JSON
        local ipfs_url=$(echo "$result" | jq -r '.ipfs_url // empty' 2>/dev/null)
        if [[ -n "$ipfs_url" ]]; then
            log_debug "Successfully processed: $title -> $ipfs_url"
            echo "✅ $title by $uploader -> $ipfs_url"
            return 0
        else
            log_debug "Failed to extract IPFS URL for: $title"
            echo "❌ Failed to process: $title"
            return 1
        fi
    else
        log_debug "process_youtube.sh failed for: $title"
        echo "❌ Download failed: $title"
        return 1
    fi
}

# Fonction principale de synchronisation
sync_youtube_likes() {
    local player="$1"
    local cookie_file="$2"
    local udrive_path="$3"
    
    log_debug "Starting YouTube likes synchronization for $player"
    
    # Récupérer les vidéos likées
    local liked_videos=$(get_liked_videos "$player" "$cookie_file" 20)
    
    if [[ $? -ne 0 || -z "$liked_videos" ]]; then
        log_debug "No liked videos found or failed to fetch for $player"
        return 1
    fi
    
    local processed_count=0
    local success_count=0
    
    # Traiter chaque vidéo likée
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Parser les données de la vidéo
            local video_id=$(echo "$line" | cut -d '&' -f 1)
            local title=$(echo "$line" | cut -d '&' -f 2)
            local duration=$(echo "$line" | cut -d '&' -f 3)
            local uploader=$(echo "$line" | cut -d '&' -f 4)
            local url=$(echo "$line" | cut -d '&' -f 5)
            
            # Nettoyer le titre
            title=$(echo "$title" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)
            
            log_debug "Processing: $title (ID: $video_id)"
            
            # Traiter la vidéo
            if process_liked_video "$video_id" "$title" "$duration" "$uploader" "$url" "$player" "$udrive_path"; then
                success_count=$((success_count + 1))
            fi
            
            processed_count=$((processed_count + 1))
            
            # Pause entre les téléchargements pour éviter la surcharge
            sleep 2
        fi
    done <<< "$liked_videos"
    
    log_debug "YouTube sync completed for $player: $success_count/$processed_count videos processed"
    
    # Mettre à jour le fichier de dernière synchronisation
    echo "$TODAY" > "$LAST_SYNC_FILE"
    
    # Envoyer une notification par email si des vidéos ont été traitées
    if [[ $success_count -gt 0 ]]; then
        send_sync_notification "$player" "$success_count" "$processed_count"
    fi
    
    return 0
}

# Fonction d'envoi de notification par email
send_sync_notification() {
    local player="$1"
    local success_count="$2"
    local processed_count="$3"
    
    log_debug "Sending sync notification to $player: $success_count/$processed_count videos"
    
    # Créer le contenu HTML de la notification
    local email_content="<html><head><meta charset='UTF-8'>
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
            <p><strong>Vidéos traitées :</strong> $processed_count</p>
            <p><strong>Vidéos téléchargées :</strong> $success_count</p>
            <p><strong>Date :</strong> $(date '+%d/%m/%Y à %H:%M')</p>
        </div>
        <p>Vos nouvelles vidéos sont maintenant disponibles dans votre uDRIVE :</p>
        <ul>
            <li>🎵 <strong>Musique :</strong> uDRIVE/Music/</li>
            <li>🎬 <strong>Vidéos :</strong> uDRIVE/Videos/</li>
        </ul>
        <p>Les vidéos sont également accessibles via IPFS pour un partage décentralisé.</p>
    </div>
    <div class='footer'>
        <p>Cette synchronisation est automatique pour les sociétaires CopyLaRadio.</p>
        <p>Pour désactiver cette fonctionnalité, contactez le support.</p>
    </div>
</div>
</body></html>"

    # Envoyer l'email via mailjet
    ${MY_PATH}/../tools/mailjet.sh "${player}" <(echo "$email_content") "🎵 YouTube Sync - $success_count nouvelles vidéos" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log_debug "Sync notification sent successfully to $player"
    else
        log_debug "Failed to send sync notification to $player"
    fi
}

# Fonction de nettoyage des anciens processus
cleanup_old_sync_processes() {
    local player="$1"
    log_debug "Cleaning up old YouTube sync processes for $player"
    
    # Tuer les anciens processus de synchronisation pour ce joueur
    pkill -f "sync_youtube_likes.sh.*${player}" 2>/dev/null || true
    
    # Nettoyer les fichiers temporaires
    rm -f "$HOME/.zen/tmp/youtube_sync_${player}_*" 2>/dev/null || true
}

# Fonction de vérification de l'espace disque
check_disk_space() {
    local udrive_path="$1"
    local required_space_mb=1000  # 1GB minimum
    
    if [[ -d "$udrive_path" ]]; then
        local available_space=$(df "$udrive_path" | awk 'NR==2 {print $4}')
        local available_mb=$((available_space / 1024))
        
        if [[ $available_mb -lt $required_space_mb ]]; then
            log_debug "Insufficient disk space: ${available_mb}MB available, ${required_space_mb}MB required"
            return 1
        fi
    fi
    return 0
}

# Exécution principale
log_debug "Starting YouTube likes sync for sociétaire: $PLAYER"
log_debug "Cookie file: $COOKIE_FILE"
log_debug "uDRIVE path: $UDRIVE_PATH"

# Nettoyer les anciens processus
cleanup_old_sync_processes "$PLAYER"

# Vérifier l'espace disque
if ! check_disk_space "$UDRIVE_PATH"; then
    log_debug "Insufficient disk space, skipping YouTube sync for $PLAYER"
    exit 1
fi

# Lancer la synchronisation
if sync_youtube_likes "$PLAYER" "$COOKIE_FILE" "$UDRIVE_PATH"; then
    log_debug "YouTube likes sync completed successfully for $PLAYER"
    exit 0
else
    log_debug "YouTube likes sync failed for $PLAYER"
    exit 1
fi
