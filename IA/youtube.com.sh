#!/bin/bash
########################################################################
# youtube.com.sh
# YouTube likes synchronization for MULTIPASS holders
# Called by NOSTRCARD.refresh.sh when .youtube.com.cookie is detected
#
# Usage: $0 <player_email> [cookie_file] [--debug]
#
# Parameters:
#   player_email: Email of the MULTIPASS holder
#   cookie_file:  (Optional) Path to cookie file. If not provided, will search in user directory
#   --debug:     (Optional) Enable debug logging
#
# Fonctionnalités:
# - Récupère les vidéos likées depuis la dernière synchronisation (max 3 par run)
# - Utilise les cookies du sociétaire pour l'authentification YouTube
# - Télécharge les nouvelles vidéos via process_youtube.sh (download-only)
# - Upload via /api/fileupload (UPlanet_FILE_CONTRACT.md compliant)
# - Publie via /webcam (NIP-71 kind 21/22)
# - Organise automatiquement dans uDRIVE/Videos/ via /api/fileupload
# - Met à jour le fichier de dernière synchronisation
########################################################################

# Enhanced logging setup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting youtube.com.sh script (YouTube sync)" >&2

# Trap pour nettoyer les fichiers temporaires en cas d'interruption
cleanup_on_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up temporary files on exit" >&2
    rm -f "$HOME/.zen/tmp/process_youtube_output_*" 2>/dev/null || true
}
trap cleanup_on_exit EXIT INT TERM

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
    echo "Usage: $0 <player_email> [cookie_file] [--debug]"
    exit 1
fi

# Check if second parameter is a cookie file (not --debug)
COOKIE_PARAM=""
if [[ -n "$2" && "$2" != "--debug" && "$2" != "--debug-udrive" ]]; then
    COOKIE_PARAM="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cookie file provided as parameter: $COOKIE_PARAM" >&2
    shift  # Remove cookie param so --debug can still be processed
fi

LOGFILE="$HOME/.zen/tmp/IA.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file: $LOGFILE" >&2
mkdir -p "$(dirname "$LOGFILE")"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Created log directory: $(dirname "$LOGFILE")" >&2

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "[youtube.com.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
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
# Priority: 1) Parameter provided, 2) .youtube.com.cookie, 3) .cookie.txt
COOKIE_FILE=""
USER_DIR="$HOME/.zen/game/nostr/${PLAYER}"

# If cookie was provided as parameter, use it
if [[ -n "$COOKIE_PARAM" && -f "$COOKIE_PARAM" ]]; then
    COOKIE_FILE="$COOKIE_PARAM"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using cookie file from parameter: $COOKIE_FILE" >&2
elif [[ -n "$COOKIE_PARAM" && ! -f "$COOKIE_PARAM" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Cookie file provided as parameter but not found: $COOKIE_PARAM" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Falling back to searching in user directory..." >&2
fi

# If no cookie from parameter, search in user directory
if [[ -z "$COOKIE_FILE" ]]; then
    if [[ -f "$USER_DIR/.youtube.com.cookie" ]]; then
        COOKIE_FILE="$USER_DIR/.youtube.com.cookie"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using single-domain YouTube cookie: $COOKIE_FILE" >&2
    elif [[ -f "$USER_DIR/.cookie.txt" ]]; then
        COOKIE_FILE="$USER_DIR/.cookie.txt"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using cookie file: $COOKIE_FILE" >&2
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking cookie file: $COOKIE_FILE" >&2
if [[ ! -f "$COOKIE_FILE" || -z "$COOKIE_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No cookie file found for $PLAYER" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checked paths:" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - $USER_DIR/.youtube.com.cookie (single-domain)" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - $USER_DIR/.cookie.txt (multi-domain or legacy)" >&2
    if [[ -d "$USER_DIR" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] User directory exists, listing cookie files:" >&2
        ls -la "$USER_DIR"/.*.cookie "$USER_DIR"/.cookie.txt 2>&1 | grep -v "cannot access" >&2 || echo "  No cookie files found" >&2
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] User directory does not exist: $USER_DIR" >&2
    fi
    log_debug "No cookie file found for $PLAYER, skipping YouTube sync"
    exit 0
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cookie file found: $COOKIE_FILE" >&2

# Optional: manual PO Token for YouTube (PO Token Guide: https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide)
# If present, playlist fetch and process_youtube.sh will use mweb + po_token to reduce 403.
YT_PLAYLIST_EXTRACTOR_ARGS=""
for pot in "$USER_DIR/.youtube.potoken" "$USER_DIR/.youtube_po_token" "$(dirname "$COOKIE_FILE")/.youtube.potoken" "$(dirname "$COOKIE_FILE")/.youtube_po_token"; do
    if [[ -f "$pot" && -s "$pot" ]]; then
        po_token_value=$(tr -d '\n\r' < "$pot" | head -c 5000)
        if [[ -n "$po_token_value" ]]; then
            po_token_value="${po_token_value//\"/\\\"}"
            YT_PLAYLIST_EXTRACTOR_ARGS="--extractor-args \"youtube:player_client=default,mweb;po_token=mweb.gvs+$po_token_value\""
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using manual PO token file for YouTube (GVS)" >&2
            break
        fi
    fi
done
[[ -z "$YT_PLAYLIST_EXTRACTOR_ARGS" ]] && YT_PLAYLIST_EXTRACTOR_ARGS='--extractor-args "youtube:player_client=tv_embedded,tv,android,web"'

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
# Supports both old format (video_id) and new format (video_id|event_id)
is_video_processed() {
    local video_id="$1"
    local processed_file="$2"
    
    if [[ ! -f "$processed_file" ]]; then
        return 1  # Fichier n'existe pas, vidéo pas traitée
    fi
    
    # Vérifier si l'ID de la vidéo est dans le fichier (supports both formats)
    # Old format: video_id
    # New format: video_id|event_id
    if grep -q "^${video_id}$\|^${video_id}|" "$processed_file" 2>/dev/null; then
        return 0  # Vidéo déjà traitée
    else
        return 1  # Vidéo pas encore traitée
    fi
}

# Fonction pour marquer une vidéo comme traitée
# Format: video_id|event_id (event_id optional, for verification)
mark_video_processed() {
    local video_id="$1"
    local processed_file="$2"
    local event_id="${3:-}"  # Optional: NOSTR event ID for verification
    
    # Créer le fichier s'il n'existe pas
    if [[ ! -f "$processed_file" ]]; then
        touch "$processed_file"
        chmod 600 "$processed_file"
    fi
    
    # Format: video_id|event_id (event_id can be empty for videos found in uDRIVE)
    if [[ -n "$event_id" ]]; then
        echo "${video_id}|${event_id}" >> "$processed_file"
        log_debug "Marked video $video_id as processed with event_id: ${event_id:0:16}..."
    else
        echo "${video_id}|" >> "$processed_file"
        log_debug "Marked video $video_id as processed (no event_id)"
    fi
}

# Fonction pour vérifier si une vidéo existe déjà dans uDRIVE
check_video_exists_in_udrive() {
    local video_id="$1"
    local title="$2"
    local player="$3"
    
    # Encode title to match manifest naming convention as much as possible
    local url_safe_title
    url_safe_title=$(url_encode_title "$title")
    
    log_debug "Checking if video exists in uDRIVE manifest: ID=$video_id, title=$url_safe_title"
    
    # Path to uDRIVE manifest generated by generate_ipfs_structure.sh
    local manifest_path="$HOME/.zen/game/nostr/${player}/APP/uDRIVE/manifest.json"
    
    # Manifest must exist and jq must be available
    if [[ ! -f "$manifest_path" ]]; then
        log_debug "uDRIVE manifest.json not found: $manifest_path"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_debug "jq not available, cannot search in manifest.json"
        return 1
    fi
    
    # Lowercase search terms for case-insensitive matching
    local video_id_l
    local title_l
    video_id_l=$(echo "$video_id" | tr '[:upper:]' '[:lower:]')
    title_l=$(echo "$url_safe_title" | tr '[:upper:]' '[:lower:]')
    
    # Search in manifest files array for matching video/audio entries
    local matches
    matches=$(jq -r \
        --arg video_id "$video_id_l" \
        --arg title "$title_l" \
        '
        .files[]? 
        | select((.type == "video") or (.type == "audio"))
        | ( 
            ((.name // "") | ascii_downcase | contains($video_id) or contains($title)) or
            ((.path // "") | ascii_downcase | contains($video_id) or contains($title))
          )
        | .path
        ' "$manifest_path" 2>/dev/null || echo "")
    
    if [[ -n "$matches" ]]; then
        log_debug "Video $video_id already indexed in uDRIVE manifest at paths: $matches"
        return 0
    fi
    
    log_debug "Video $video_id not found in uDRIVE manifest"
    return 1
}


# Fonction pour vérifier et nettoyer les vidéos marquées comme traitées mais sans événement NOSTR
# Vérifie les 9 dernières entrées pour ne pas surcharger le système
verify_processed_videos() {
    local processed_file="$1"
    local player="$2"
    
    log_debug "Starting verification of last 9 processed videos for $player"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verifying last 9 processed videos..." >&2
    
    if [[ ! -f "$processed_file" ]]; then
        log_debug "No processed videos file found, nothing to verify"
        return 0
    fi
    
    # Get the nostr_get_events.sh script path
    local nostr_get_script="${MY_PATH}/../tools/nostr_get_events.sh"
    if [[ ! -f "$nostr_get_script" ]]; then
        log_debug "nostr_get_events.sh not found, skipping verification"
        return 0
    fi
    
    # Get player's HEX pubkey for querying their events
    local hex_file="$HOME/.zen/game/nostr/${player}/HEX"
    local player_hex=""
    if [[ -f "$hex_file" ]]; then
        player_hex=$(cat "$hex_file" 2>/dev/null)
    fi
    
    if [[ -z "$player_hex" ]]; then
        log_debug "No HEX pubkey found for $player, skipping verification"
        return 0
    fi
    
    # Read all entries into an array
    local all_entries=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_entries+=("$line")
    done < "$processed_file"
    
    local total_entries=${#all_entries[@]}
    if [[ $total_entries -eq 0 ]]; then
        log_debug "No entries in processed videos file"
        return 0
    fi
    
    # Calculate start index for last 9 entries
    local start_index=0
    if [[ $total_entries -gt 9 ]]; then
        start_index=$((total_entries - 9))
    fi
    
    log_debug "Checking entries from index $start_index to $((total_entries - 1)) (last 9)"
    
    local entries_to_remove=()
    local verified_count=0
    local invalid_count=0
    
    for ((i = start_index; i < total_entries; i++)); do
        local entry="${all_entries[$i]}"
        local video_id=""
        local event_id=""
        
        # Parse entry: video_id|event_id or just video_id (legacy)
        if [[ "$entry" == *"|"* ]]; then
            video_id=$(echo "$entry" | cut -d'|' -f1)
            event_id=$(echo "$entry" | cut -d'|' -f2)
        else
            # Legacy format: just video_id
            video_id="$entry"
            event_id=""
        fi
        
        log_debug "Checking entry: video_id=$video_id, event_id=${event_id:0:16}..."
        
        # Skip entries without event_id (videos found in uDRIVE, not published to NOSTR)
        if [[ -z "$event_id" ]]; then
            log_debug "Entry $video_id has no event_id, keeping (uDRIVE or legacy)"
            continue
        fi
        
        # Verify the event exists in the relay
        # Query for the specific event by author and kind (21 or 22)
        local event_exists=0
        
        # Try to find the event using strfry scan with the event ID
        # Use jq to check if any event has this ID
        local query_result=$("$nostr_get_script" --kind 21 --author "$player_hex" --limit 50 2>/dev/null | jq -r --arg eid "$event_id" 'select(.id == $eid) | .id' 2>/dev/null | head -1)
        
        if [[ -z "$query_result" ]]; then
            # Also check kind 22 (short videos)
            query_result=$("$nostr_get_script" --kind 22 --author "$player_hex" --limit 50 2>/dev/null | jq -r --arg eid "$event_id" 'select(.id == $eid) | .id' 2>/dev/null | head -1)
        fi
        
        if [[ -n "$query_result" ]]; then
            log_debug "Event $event_id verified, exists in relay"
            verified_count=$((verified_count + 1))
        else
            log_debug "Event $event_id NOT FOUND in relay, marking for removal"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  Event not found for video $video_id, removing from history" >&2
            entries_to_remove+=("$entry")
            invalid_count=$((invalid_count + 1))
        fi
    done
    
    # Remove invalid entries from the file
    if [[ ${#entries_to_remove[@]} -gt 0 ]]; then
        log_debug "Removing ${#entries_to_remove[@]} invalid entries from processed videos file"
        
        # Create a new file without the invalid entries
        local temp_file="${processed_file}.tmp"
        > "$temp_file"
        
        for entry in "${all_entries[@]}"; do
            local should_remove=0
            for invalid in "${entries_to_remove[@]}"; do
                if [[ "$entry" == "$invalid" ]]; then
                    should_remove=1
                    break
                fi
            done
            
            if [[ $should_remove -eq 0 ]]; then
                echo "$entry" >> "$temp_file"
            fi
        done
        
        mv "$temp_file" "$processed_file"
        chmod 600 "$processed_file"
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaned up $invalid_count invalid entries from history" >&2
        log_debug "Removed $invalid_count entries, verified $verified_count entries"
    else
        log_debug "All checked entries are valid, no cleanup needed"
    fi
    
    return 0
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
    
    # Vérifier l'état du fichier cookie
    if [[ -f "$cookie_file" ]]; then
        local cookie_size=$(wc -c < "$cookie_file" 2>/dev/null || echo "0")
        local cookie_lines=$(wc -l < "$cookie_file" 2>/dev/null || echo "0")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cookie file info: size=${cookie_size} bytes, lines=${cookie_lines}" >&2
        log_debug "Cookie file details: size=${cookie_size} bytes, lines=${cookie_lines}"
        
        # Vérifier si le fichier cookie contient des cookies valides
        if [[ $cookie_size -lt 100 ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Cookie file seems too small (${cookie_size} bytes)" >&2
            log_debug "Cookie file may be invalid or empty"
        fi
        
        # Vérifier la présence de cookies YouTube spécifiques
        if grep -q "youtube.com" "$cookie_file" 2>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cookie file contains YouTube cookies" >&2
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Cookie file may not contain YouTube cookies" >&2
            log_debug "Cookie file content preview: $(head -c 200 "$cookie_file")"
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Cookie file not found: $cookie_file" >&2
        return 1
    fi
    
    # Utiliser yt-dlp pour récupérer la playlist "Liked videos"
    # La playlist "LL" correspond aux vidéos likées
    local liked_playlist_url="https://www.youtube.com/playlist?list=LL"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying liked videos playlist: $liked_playlist_url" >&2
    
    # Skip connectivity tests to minimize requests - go directly to main request
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipping connectivity tests to minimize YouTube requests" >&2
    log_debug "Minimizing requests by skipping connectivity tests"
    
    # Single optimized request with multiple fallback strategies
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running optimized single yt-dlp request..." >&2
    
    # Try multiple URLs in order of preference (single request each)
    local urls_to_try=(
        "https://www.youtube.com/playlist?list=LL"
        "https://www.youtube.com/feed/history"
        "https://www.youtube.com/playlist?list=WL"
    )
    
    local videos_json=""
    local exit_code=1
    
    for url in "${urls_to_try[@]}"; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying URL: $url" >&2
        log_debug "Attempting yt-dlp with URL: $url"
        
        # Capture both stdout and stderr to detect cookie issues
        local yt_dlp_stderr_file="$HOME/.zen/tmp/yt_dlp_stderr_$$.txt"
        
        # Single request with minimal options (keep stderr for error detection)
        # Use YT_PLAYLIST_EXTRACTOR_ARGS (PO token or tv_embedded,tv,android,web per PO Token Guide)
        videos_json=$(yt-dlp \
            $YT_PLAYLIST_EXTRACTOR_ARGS \
            --cookies "$cookie_file" \
            --print '%(id)s&%(title)s&%(duration)s&%(uploader)s&%(webpage_url)s' \
            --playlist-end "$max_results" \
            --no-warnings \
            "$url" 2>"$yt_dlp_stderr_file")
        
        exit_code=$?
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] yt-dlp exit code for $url: $exit_code" >&2
        
        # Check for cookie invalidation error and surface yt-dlp errors on failure
        if [[ -f "$yt_dlp_stderr_file" ]]; then
            if grep -q "cookies are no longer valid" "$yt_dlp_stderr_file" 2>/dev/null; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ COOKIE ERROR: YouTube cookies are no longer valid!" >&2
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 💡 Please re-export cookies from a PRIVATE/INCOGNITO window" >&2
                log_debug "Cookie invalidation detected - user needs to re-export cookies from private window"
                rm -f "$yt_dlp_stderr_file"
                return 2  # Special exit code for invalid cookies
            fi
            # On failure, show yt-dlp stderr so user sees the actual reason (e.g. login required, private, 403)
            if [[ $exit_code -ne 0 && -s "$yt_dlp_stderr_file" ]]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] yt-dlp error output:" >&2
                tail -20 "$yt_dlp_stderr_file" | sed 's/^/  /' >&2
                log_debug "yt-dlp stderr: $(cat "$yt_dlp_stderr_file")"
            fi
            rm -f "$yt_dlp_stderr_file"
        fi
        
        # If we got results, break
        if [[ $exit_code -eq 0 && -n "$videos_json" ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Success with URL: $url" >&2
            log_debug "Successfully fetched videos from: $url"
            break
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed with URL: $url (exit_code: $exit_code, content_length: ${#videos_json})" >&2
            log_debug "Failed to get videos from: $url"
            videos_json=""
        fi
        
        # Small delay between attempts to avoid rate limiting
        sleep 2
    done
    
    # Log final result
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Final videos_json length: ${#videos_json}" >&2
    if [[ -n "$videos_json" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] videos_json preview: $(echo "$videos_json" | head -c 200)..." >&2
        log_debug "Final videos_json content: $videos_json"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] All URL attempts failed - videos_json is empty" >&2
    fi
    
    if [[ $exit_code -eq 0 && -n "$videos_json" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully fetched liked videos" >&2
        echo "$videos_json"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] All URL attempts failed - no videos found" >&2
        log_debug "All URL attempts failed for $player"
        return 1
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
# DEPRECATED: Videos are now published via /webcam endpoint (NIP-71 kind 21/22)
# This function is kept for backward compatibility but is no longer used
send_nostr_note() {
    local player="$1"
    local title="$2"
    local uploader="$3"
    local ipfs_url="$4"
    local youtube_url="$5"
    
    log_debug "Note: send_nostr_note() is deprecated. Videos are published via /webcam (NIP-71 kind 21/22)"
    # Videos are now published via /webcam endpoint in process_liked_video()
    return 0
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
    
    # UPlanet_FILE_CONTRACT.md Compliance:
    # 1. Download video via process_youtube.sh (download-only, no IPFS upload)
    # 2. Upload via /api/fileupload (standardized workflow)
    # 3. Publish via /webcam (NIP-71 kind 21/22)
    
    log_debug "Calling process_youtube.sh: $url $format $player"
    
    # Créer un fichier temporaire pour capturer la sortie et éviter les problèmes de pipe
    local temp_output_file="$HOME/.zen/tmp/process_youtube_output_$(date +%s)_$$.txt"
    local temp_output_dir="$HOME/.zen/tmp/youtube_sync_${player}_$$"
    mkdir -p "$temp_output_dir"
    
    # Create temporary JSON file for clean JSON output (separate from logs)
    local json_output_file="$HOME/.zen/tmp/process_youtube_json_$(date +%s)_$$.json"
    mkdir -p "$(dirname "$json_output_file")"
    
    # Exécuter process_youtube.sh avec --json-file pour isoler le JSON des logs
    # Use --no-ipfs flag for consistency with ajouter_media.sh (download-only, no IPFS upload)
    $MY_PATH/process_youtube.sh --json-file "$json_output_file" --debug --no-ipfs --output-dir "$temp_output_dir" "$url" "$format" "$player" > "$temp_output_file" 2>&1
    local process_exit_code=$?
    
    # Lire le JSON depuis le fichier séparé (méthode fiable)
    local result=""
    if [[ -f "$json_output_file" ]] && [[ -s "$json_output_file" ]]; then
        # Read JSON from separate file (clean, no mixing with logs)
        if command -v jq &> /dev/null; then
            result=$(jq -c '.' "$json_output_file" 2>/dev/null)
        else
            result=$(cat "$json_output_file" 2>/dev/null)
        fi
        rm -f "$json_output_file"
        log_debug "JSON read from file: $json_output_file"
    else
        # Fallback: try to extract JSON from output file (backward compatibility)
        log_debug "JSON file not found, attempting fallback extraction from output"
        if [[ -f "$temp_output_file" ]]; then
            # Vérifier que jq est disponible
            if ! command -v jq &> /dev/null; then
                log_debug "ERROR: jq is required but not found"
                echo "❌ jq is required for JSON parsing but not installed" >&2
                rm -f "$temp_output_file"
                return 1
            fi
            
            # Extract JSON from output using jq only
            # Try to extract JSON directly with jq (handles both marked and raw JSON)
            # First, try to parse the entire file as JSON
            result=$(jq -c '.' "$temp_output_file" 2>/dev/null)
            
            # If that fails, try to extract JSON between markers using jq
            if [[ -z "$result" ]] && grep -q "=== JSON OUTPUT START ===" "$temp_output_file"; then
                # Extract lines between markers, then parse with jq
                local json_lines=$(awk '/=== JSON OUTPUT START ===/{flag=1;next}/=== JSON OUTPUT END ===/{flag=0}flag' "$temp_output_file")
                if [[ -n "$json_lines" ]]; then
                    result=$(echo "$json_lines" | jq -c '.' 2>/dev/null)
                fi
            fi
            
            # If still no result, try to find and parse first JSON object/array in file
            if [[ -z "$result" ]]; then
                local first_json=$(grep -m 1 -E '^\{|^\[' "$temp_output_file" 2>/dev/null)
                if [[ -n "$first_json" ]]; then
                    result=$(echo "$first_json" | jq -c '.' 2>/dev/null)
                fi
            fi
        fi
    fi
    
    # Clean up temp output file
    rm -f "$temp_output_file"
    
    log_debug "process_youtube.sh exit code: $process_exit_code"
    log_debug "process_youtube.sh output: $result"
    
    # Check if JSON contains an error field (like ajouter_media.sh does)
    if [[ -n "$result" ]] && echo "$result" | jq -e '.error' >/dev/null 2>&1; then
        local error_msg=$(echo "$result" | jq -r '.error' 2>/dev/null)
        log_debug "process_youtube.sh returned error: $error_msg"
        echo "❌ process_youtube.sh error: $error_msg"
        return 1
    fi
    
    if [[ $process_exit_code -eq 0 ]]; then
        # Extract file_path and metadata_file from JSON using jq only (UPlanet_FILE_CONTRACT.md compliant)
        log_debug "Raw result from process_youtube.sh: $result"
        
        # Vérifier que le résultat n'est pas vide et est un JSON valide
        if [[ -z "$result" ]]; then
            log_debug "Empty result from process_youtube.sh for: $url_safe_title"
            echo "❌ Empty result from process_youtube.sh: $url_safe_title"
            return 1
        fi
        
        # Validate JSON with jq
        if ! echo "$result" | jq -e '.' >/dev/null 2>&1; then
            log_debug "Invalid JSON from process_youtube.sh: $result"
            echo "❌ Invalid JSON from process_youtube.sh: $url_safe_title"
            return 1
        fi
        
        # Extract file_path and metadata_file using jq only
        local file_path=""
        local metadata_file=""
        local duration_from_json=""
        local output_dir_from_json=""
        
        file_path=$(echo "$result" | jq -r '.file_path // empty' 2>/dev/null)
        metadata_file=$(echo "$result" | jq -r '.metadata_file // empty' 2>/dev/null)
        duration_from_json=$(echo "$result" | jq -r '.duration // empty' 2>/dev/null)
        output_dir_from_json=$(echo "$result" | jq -r '.output_dir // empty' 2>/dev/null)
        
        log_debug "Extracted file_path: '$file_path'"
        log_debug "Extracted metadata_file: '$metadata_file'"
        log_debug "Extracted output_dir: '$output_dir_from_json'"
        
        # If file_path doesn't exist, try to find it in output_dir (like ajouter_media.sh does)
        if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
            if [[ -n "$output_dir_from_json" ]] && [[ -d "$output_dir_from_json" ]]; then
                log_debug "File path from JSON not found, searching in output_dir: $output_dir_from_json"
                # Find any media file in the output directory
                file_path=$(find "$output_dir_from_json" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mp3" -o -name "*.m4a" -o -name "*.webm" -o -name "*.mkv" \) ! -name "*.info.json" ! -name "*.webp" ! -name "*.png" ! -name "*.jpg" 2>/dev/null | head -n 1)
                
                # If still not found, try to find the largest file
                if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
                    file_path=$(find "$output_dir_from_json" -maxdepth 1 -type f ! -name "*.info.json" ! -name "*.webp" ! -name "*.png" ! -name "*.jpg" -exec ls -S {} + 2>/dev/null | head -n 1)
                fi
                
                if [[ -n "$file_path" ]] && [[ -f "$file_path" ]]; then
                    log_debug "Found downloaded file in output_dir: $file_path"
                fi
            fi
        fi
        
        if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
            log_debug "Invalid or missing file_path from process_youtube.sh: $file_path"
            log_debug "Output directory contents:"
            if [[ -n "$output_dir_from_json" ]] && [[ -d "$output_dir_from_json" ]]; then
                ls -lh "$output_dir_from_json" 2>/dev/null | head -20 >&2 || true
            fi
            echo "❌ Downloaded file not found: $url_safe_title"
            return 1
        fi
        
        # Get player's npub for authentication
        local npub=""
        local npub_file="$HOME/.zen/game/nostr/${player}/NPUB"
        if [[ -f "$npub_file" ]]; then
            npub=$(cat "$npub_file" 2>/dev/null)
        else
            log_debug "NPUB file not found for $player, trying HEX conversion"
            local hex_file="$HOME/.zen/game/nostr/${player}/HEX"
            if [[ -f "$hex_file" ]]; then
                # Try to convert hex to npub (would need proper conversion script)
                log_debug "HEX found but npub conversion needed"
            fi
        fi
        
        if [[ -z "$npub" ]]; then
            log_debug "No NOSTR npub found for $player, upload will fail"
            echo "❌ No NOSTR key found for $player"
            return 1
        fi
        
        # Send NIP-42 authentication event before upload (like ajouter_media.sh does)
        log_debug "Sending NIP-42 authentication event..."
        local secret_nostr_file="$HOME/.zen/game/nostr/${player}/.secret.nostr"
        local nostr_send_script="${MY_PATH}/../tools/nostr_send_note.py"
        local nostr_relay="ws://127.0.0.1:7777"
        
        if [[ -f "$secret_nostr_file" ]] && [[ -f "$nostr_send_script" ]]; then
            # Send NIP-42 event (kind 22242) to authenticate with relay
            # Content includes IPFSNODEID and UPLANETNAME_G1 for identification
            . "${MY_PATH}/tools/my.sh" 2>/dev/null || true
            local nip42_content="${IPFSNODEID} ${UPLANETNAME_G1}"
            local nip42_tags='[["relay","'${nostr_relay}'"],["challenge",""]]'
            if python3 "$nostr_send_script" \
                --keyfile "$secret_nostr_file" \
                --content "$nip42_content" \
                --kind 22242 \
                --tags "$nip42_tags" \
                --relays "$nostr_relay" \
                >/dev/null 2>&1; then
                log_debug "NIP-42 authentication event sent"
                # Wait a bit for the event to be processed by the relay
                sleep 2
            else
                log_debug "Warning: Failed to send NIP-42 authentication event (upload may still work if already authenticated)"
            fi
        else
            if [[ ! -f "$secret_nostr_file" ]]; then
                log_debug "Warning: Secret key file not found: $secret_nostr_file"
            fi
            if [[ ! -f "$nostr_send_script" ]]; then
                log_debug "Warning: nostr_send_note.py not found: $nostr_send_script"
            fi
            log_debug "Warning: Cannot send NIP-42 authentication event (upload may still work if already authenticated)"
        fi
        
        # Upload via /api/fileupload (UPlanet_FILE_CONTRACT.md compliant)
        log_debug "Uploading video via /api/fileupload..."
        log_debug "File path: $file_path"
        log_debug "File exists: $([ -f "$file_path" ] && echo "yes" || echo "no")"
        if [[ -f "$file_path" ]]; then
            log_debug "File size: $(stat -c%s "$file_path" 2>/dev/null || echo "unknown") bytes"
        fi
        local api_url="http://127.0.0.1:54321"
        
        # Don't redirect stderr to stdout to avoid mixing error messages with JSON response
        local upload_response=$(curl -s -X POST "${api_url}/api/fileupload" \
            -F "file=@${file_path}" \
            -F "npub=${npub}")
        local curl_exit_code=$?
        
        # Log curl exit code for debugging
        log_debug "curl exit code: $curl_exit_code"
        log_debug "Upload response length: ${#upload_response} characters"
        log_debug "Upload response preview: ${upload_response:0:500}..."
        
        local upload_success=0
        local ipfs_cid=""
        local info_cid=""
        local thumbnail_cid=""
        local gifanim_cid=""
        local file_hash=""
        local dimensions=""
        local upload_chain=""
        local mime_type="video/mp4"
        
        # Check if curl succeeded
        if [[ $curl_exit_code -ne 0 ]]; then
            log_debug "curl command failed with exit code: $curl_exit_code"
            echo "❌ Upload request failed (curl exit code: $curl_exit_code): $url_safe_title"
            return 1
        fi
        
        # Check if response is valid JSON
        if ! echo "$upload_response" | jq -e '.' >/dev/null 2>&1; then
            log_debug "Invalid JSON response from /api/fileupload: $upload_response"
            echo "❌ Invalid JSON response from upload API: $url_safe_title"
            return 1
        fi
        
        if echo "$upload_response" | jq -e '.success' >/dev/null 2>&1; then
            upload_success=1
            ipfs_cid=$(echo "$upload_response" | jq -r '.new_cid // empty' 2>/dev/null)
            info_cid=$(echo "$upload_response" | jq -r '.info // empty' 2>/dev/null)
            thumbnail_cid=$(echo "$upload_response" | jq -r '.thumbnail_ipfs // empty' 2>/dev/null)
            gifanim_cid=$(echo "$upload_response" | jq -r '.gifanim_ipfs // empty' 2>/dev/null)
            file_hash=$(echo "$upload_response" | jq -r '.fileHash // empty' 2>/dev/null)
            dimensions=$(echo "$upload_response" | jq -r '.dimensions // empty' 2>/dev/null)
            upload_chain=$(echo "$upload_response" | jq -r '.upload_chain // empty' 2>/dev/null)
            mime_type=$(echo "$upload_response" | jq -r '.mimeType // "video/mp4"' 2>/dev/null)
            
            log_debug "Upload successful: CID=$ipfs_cid"
        else
            # Extract error message from response if available
            local error_msg=$(echo "$upload_response" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "Unknown error")
            log_debug "Upload failed: $error_msg"
            log_debug "Full upload response: $upload_response"
            echo "❌ Upload to IPFS failed: $url_safe_title ($error_msg)"
            return 1
        fi
        
        if [[ -z "$ipfs_cid" ]]; then
            log_debug "Failed to get IPFS CID from upload response"
            echo "❌ Failed to get IPFS CID: $url_safe_title"
            return 1
        fi
        
        # Use duration from JSON or upload response
        local final_duration="$duration"
        if [[ -n "$duration_from_json" && "$duration_from_json" != "null" ]]; then
            final_duration="$duration_from_json"
        fi
        
        # Publish via publish_nostr_video.sh directly (like ajouter_media.sh does)
        log_debug "Publishing video via publish_nostr_video.sh..."
        
        # Get publish script path
        local publish_script="${MY_PATH}/../tools/publish_nostr_video.sh"
        if [[ ! -f "$publish_script" ]]; then
            publish_script="${HOME}/.zen/Astroport.ONE/tools/publish_nostr_video.sh"
        fi
        
        if [[ ! -f "$publish_script" ]]; then
            log_debug "ERROR: publish_nostr_video.sh not found"
            echo "❌ ERROR: publish_nostr_video.sh not found"
            return 1
        fi
        
        # Get secret file path
        local secret_file="$HOME/.zen/game/nostr/${player}/.secret.nostr"
        if [[ ! -f "$secret_file" ]]; then
            log_debug "ERROR: Secret file not found: $secret_file"
            echo "❌ ERROR: Secret file not found: $secret_file"
            return 1
        fi
        
        # Save upload response to temporary file for --auto mode
        # Adapt JSON format to match what publish_nostr_video.sh expects (--auto mode)
        # publish_nostr_video.sh expects: .cid (not .new_cid), .fileName (not .filename)
        local upload_output_file="$HOME/.zen/tmp/youtube_upload_$(date +%s)_$$.json"
        local adapted_json=$(echo "$upload_response" | jq --arg filename "$(basename "$file_path")" --arg duration "$final_duration" '
            {
                cid: (.new_cid // .cid // ""),
                fileName: (.fileName // .filename // $filename),
                fileHash: (.fileHash // ""),
                mimeType: (.mimeType // "video/mp4"),
                thumbnail_ipfs: (.thumbnail_ipfs // ""),
                gifanim_ipfs: (.gifanim_ipfs // ""),
                info: (.info // ""),
                upload_chain: (.upload_chain // ""),
                dimensions: (.dimensions // ""),
                duration: (if .duration then .duration else ($duration | tonumber) end),
                fileSize: (.fileSize // .file_size // 0)
            }
        ' 2>/dev/null)
        
        if [[ -n "$adapted_json" ]] && echo "$adapted_json" | jq -e '.' >/dev/null 2>&1; then
            echo "$adapted_json" > "$upload_output_file"
            log_debug "Saved adapted upload response to: $upload_output_file"
        else
            # Fallback: use original response (may not work with --auto mode)
            echo "$upload_response" > "$upload_output_file"
            log_debug "Saved upload response (original format) to: $upload_output_file"
        fi
        
        # Clean title for publication (replace underscores with spaces, like ajouter_media.sh does)
        local title_for_publication=$(echo "$title" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
        log_debug "Title for publication: $title_for_publication"
        
        # Build description
        local description="YouTube sync: $title_for_publication by $uploader"
        if [[ -n "$url" ]]; then
            description="${description}\n\nSource: ${url}"
        fi
        
        # Build publish command using --auto mode (reads from upload response JSON)
        local publish_cmd=("$publish_script" "--auto" "$upload_output_file" "--nsec" "$secret_file" "--title" "$title_for_publication")
        
        if [[ -n "$description" ]]; then
            publish_cmd+=("--description" "$description")
        fi
        
        # Add source type: youtube
        publish_cmd+=("--source-type" "youtube")
        log_debug "Source type: youtube"
        
        # Add YouTube URL if available
        if [[ -n "$url" ]]; then
            publish_cmd+=("--youtube-url" "$url")
            log_debug "YouTube URL: $url"
        fi
        
        # Add dimensions and duration explicitly
        if [[ -n "$dimensions" ]] && [[ "$dimensions" != "empty" ]] && [[ "$dimensions" != "" ]] && [[ "$dimensions" != "640x480" ]]; then
            publish_cmd+=("--dimensions" "$dimensions")
            log_debug "Dimensions: $dimensions"
        fi
        
        if [[ -n "$final_duration" ]] && [[ "$final_duration" != "0" ]] && [[ "$final_duration" != "empty" ]] && [[ "$final_duration" != "" ]]; then
            publish_cmd+=("--duration" "$final_duration")
            log_debug "Duration: ${final_duration}s"
        fi
        
        publish_cmd+=("--channel" "$player" "--json")
        
        # Execute publish script
        log_debug "Executing: ${publish_cmd[*]}"
        local publish_output=$(bash "${publish_cmd[@]}" 2>&1)
        local publish_exit_code=$?
        
        # Cleanup upload output file
        rm -f "$upload_output_file"
        
        if [[ $publish_exit_code -eq 0 ]]; then
            # Try to extract event ID from output
            local event_id=$(echo "$publish_output" | jq -r '.event_id // empty' 2>/dev/null || echo "")
            if [[ -n "$event_id" ]]; then
                log_debug "Video published successfully to NOSTR! Event ID: ${event_id:0:16}..."
                echo "✅ $url_safe_title by $uploader -> Published (CID: ${ipfs_cid:0:16}..., Event: ${event_id:0:16}...)"
                
                # Marquer la vidéo comme traitée avec l'event_id pour vérification future
                mark_video_processed "$video_id" "$processed_file" "$event_id"
                
                # Cleanup temp directory
                rm -rf "$temp_output_dir" 2>/dev/null || true
                
                return 0
            else
                # Try regex extraction
                event_id=$(echo "$publish_output" | grep -oE '"event_id"\s*:\s*"[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}' | head -1)
                if [[ -n "$event_id" ]]; then
                    log_debug "Video published successfully to NOSTR! Event ID: ${event_id:0:16}..."
                    echo "✅ $url_safe_title by $uploader -> Published (CID: ${ipfs_cid:0:16}..., Event: ${event_id:0:16}...)"
                    
                    # Marquer la vidéo comme traitée avec l'event_id pour vérification future
                    mark_video_processed "$video_id" "$processed_file" "$event_id"
                    
                    # Cleanup temp directory
                    rm -rf "$temp_output_dir" 2>/dev/null || true
                    
                    return 0
                else
                    log_debug "Video uploaded but event ID not found in output"
                    echo "⚠️ Video uploaded but event ID not found: $url_safe_title"
                    echo "Publish output: $publish_output"
                    # Mark as processed WITHOUT event_id - will be flagged by verify_processed_videos
                    # Do NOT mark as processed to allow retry on next sync
                    log_debug "NOT marking video as processed to allow retry"
                    
                    # Cleanup temp directory
                    rm -rf "$temp_output_dir" 2>/dev/null || true
                    
                    return 1  # Return failure to allow retry
                fi
            fi
        else
            log_debug "Video uploaded but publication failed (exit code: $publish_exit_code)"
            echo "⚠️ Video uploaded but publication failed: $url_safe_title"
            echo "Publish output: $publish_output"
            # Do NOT mark as processed when publication fails - allow retry on next sync
            log_debug "NOT marking video as processed to allow retry"
            
            # Cleanup temp directory
            rm -rf "$temp_output_dir" 2>/dev/null || true
            
            return 1  # Return failure to allow retry
        fi
    else
        log_debug "process_youtube.sh failed for: $url_safe_title"
        echo "❌ Download failed: $url_safe_title"
        
        # Cleanup temp directory
        rm -rf "$temp_output_dir" 2>/dev/null || true
        
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
    
    # Vérifier et nettoyer les vidéos marquées sans événement NOSTR (dernières 9 entrées)
    verify_processed_videos "$processed_file" "$player"
    
    # Récupérer les vidéos likées (limiter à 5 pour minimiser les requêtes)
    local liked_videos=$(get_liked_videos "$player" "$cookie_file" 5)
    local get_videos_exit_code=$?
    
    if [[ $get_videos_exit_code -eq 2 ]]; then
        # Cookie invalidation detected
        log_debug "Cookie invalidation detected for $player - cookies need to be re-exported"
        echo "❌ COOKIE EXPIRED: Please re-export YouTube cookies from a PRIVATE/INCOGNITO window" >&2
        echo "💡 Instructions: Open private window → Login to YouTube → Export cookies → Close private window" >&2
        # Envoyer une notification d'erreur pour cookie expiré
        send_error_notification "$player" "cookie_expired" ""
        return 2
    elif [[ $get_videos_exit_code -ne 0 || -z "$liked_videos" ]]; then
        log_debug "No liked videos found or failed to fetch for $player"
        # Envoyer une notification d'erreur pour échec de synchronisation
        send_error_notification "$player" "sync_failed" "Failed to fetch liked videos"
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
    
    # Traiter chaque vidéo likée jusqu'à avoir 2 succès (réduit pour minimiser les requêtes)
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Arrêter si on a déjà 2 succès (réduit de 3 à 2)
            if [[ $success_count -ge 2 ]]; then
                echo "🎯 Reached target of 2 successful downloads, stopping"
                log_debug "Reached target of 2 successful downloads, stopping"
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
                    echo "✅ Success count: $success_count/2"
                    log_debug "Success count: $success_count/2"
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
    
    # Envoyer une notification d'erreur si des échecs ont eu lieu
    if [[ $failed_count -gt 0 ]]; then
        send_error_notification "$player" "download_failures" "$failed_count" "$success_count"
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
        <p>Les vidéos sont également accessibles sur <a href="$uSPOT/youtube?html=1">Nostr Tube</a> pour un partage décentralisé.</p>
    </div>
    <div class='footer'>
        <p>Cette synchronisation est automatique pour tous les MULTIPASS avec <a href="$uSPOT/cookie" target="_blank">cookie YouTube</a>.</p>
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

# Fonction d'envoi de notification d'erreur par email
send_error_notification() {
    local player="$1"
    local error_type="$2"
    local error_details="$3"
    local success_count="${4:-0}"
    
    log_debug "Sending error notification to $player: type=$error_type, details=$error_details"
    
    # Déterminer le message d'erreur selon le type
    local error_title=""
    local error_message=""
    local error_instructions=""
    
    case "$error_type" in
        "cookie_expired")
            error_title="⚠️ Cookie YouTube Expiré"
            error_message="Vos cookies YouTube ne sont plus valides et doivent être réexportés."
            error_instructions="<p><strong>💡 Instructions pour réexporter vos cookies :</strong></p><ol><li>Ouvrez une fenêtre de navigation <strong>PRIVÉE/INCOGNITO</strong></li><li>Connectez-vous à YouTube dans cette fenêtre</li><li>Exportez vos cookies (extension de navigateur ou outil d'export)</li><li>Fermez la fenêtre privée</li><li>Uploadez les nouveaux cookies sur <a href=\"${uSPOT}/cookie\" target=\"_blank\">la page cookie</a></li></ol><p><strong>⚠️ Important :</strong> Les cookies doivent être exportés depuis une fenêtre privée pour éviter les conflits avec votre session normale.</p>"
            ;;
        "download_failures")
            error_title="⚠️ Échecs de Téléchargement"
            error_message="Certaines vidéos n'ont pas pu être téléchargées lors de la synchronisation."
            error_instructions="<p><strong>Détails :</strong></p><ul><li><strong>Échecs :</strong> ${error_details}</li><li><strong>Succès :</strong> ${success_count}</li></ul><p>Les vidéos qui ont échoué seront réessayées lors de la prochaine synchronisation automatique.</p><p>Si le problème persiste, vérifiez :</p><ul><li>Votre connexion Internet</li><li>L'espace disque disponible dans votre uDRIVE</li><li>Les logs YouTube dans <code>~/.zen/tmp/ajouter_media.log</code></li></ul>"
            ;;
        "sync_failed")
            error_title="⚠️ Échec de Synchronisation"
            error_message="La synchronisation YouTube a échoué."
            error_instructions="<p>La synchronisation n'a pas pu récupérer vos vidéos likées.</p><p><strong>Vérifications à effectuer :</strong></p><ul><li>Vos cookies YouTube sont-ils valides ? (<a href=\"${uSPOT}/cookie\" target=\"_blank\">Vérifier</a>)</li><li>Votre connexion Internet fonctionne-t-elle ?</li><li>YouTube est-il accessible ?</li></ul><p>La synchronisation sera réessayée automatiquement lors du prochain cycle.</p>"
            ;;
        "disk_space")
            error_title="⚠️ Espace Disque Insuffisant"
            error_message="Il n'y a pas assez d'espace disque pour télécharger de nouvelles vidéos."
            error_instructions="<p><strong>Espace disponible :</strong> ${error_details}</p><p><strong>Espace requis :</strong> Au moins 1 GB</p><p><strong>Actions recommandées :</strong></p><ul><li>Libérez de l'espace disque sur votre système</li><li>Supprimez d'anciennes vidéos de votre uDRIVE si nécessaire</li><li>Vérifiez l'espace disponible : <code>df -h ~/.zen/game/nostr/${player}/APP/uDRIVE</code></li></ul>"
            ;;
        *)
            error_title="⚠️ Erreur de Synchronisation"
            error_message="Une erreur s'est produite lors de la synchronisation YouTube."
            error_instructions="<p><strong>Détails :</strong> ${error_details}</p><p>Vérifiez les logs YouTube dans <code>~/.zen/tmp/ajouter_media.log</code> pour plus d'informations.</p>"
            ;;
    esac
    
    # Extract last 42 lines from YouTube sync logs for debugging (process_youtube.sh writes to ajouter_media.log)
    local log_lines=""
    local log_section=""
    local youtube_log="$HOME/.zen/tmp/ajouter_media.log"
    if [[ -f "$youtube_log" ]] && [[ -s "$youtube_log" ]]; then
        log_lines=$(tail -n 42 "$youtube_log" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g' || echo "")
        if [[ -n "$log_lines" ]]; then
            log_section="<div class='log-section'><h4>🔍 Dernières lignes du log (YouTube sync / ajouter_media.log)</h4><pre>${log_lines}</pre></div>"
            log_debug "Extracted $(echo "$log_lines" | wc -l) lines from ajouter_media.log for notification"
        else
            log_section=""
            log_debug "ajouter_media.log is empty or could not be read"
        fi
    else
        # No YouTube log yet (e.g. failure before process_youtube was called: cookie, get_liked_videos)
        log_section="<div class='log-section'><h4>🔍 Log YouTube sync</h4><pre>No entries yet in ajouter_media.log (sync failed before download, e.g. cookie or playlist fetch). Check server stderr or run youtube.com.sh with --debug.</pre></div>"
        log_debug "Log file empty or not found: $youtube_log"
    fi
    
    # Chemin vers le template HTML
    local template_file="${MY_PATH}/../templates/NOSTR/cookie.youtube.alert.html"
    
    # Check if template file exists
    if [[ ! -f "$template_file" ]]; then
        log_debug "ERROR: Template file not found: $template_file"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Template file not found: $template_file" >&2
        return 1
    fi
    
    local temp_email_file="$HOME/.zen/tmp/youtube_error_email_$(date +%Y%m%d_%H%M%S).html"
    local current_date=$(date '+%d/%m/%Y à %H:%M')
    
    # Write log_section to a temp file to avoid shell escaping issues with awk
    local log_section_file="$HOME/.zen/tmp/log_section_$$.html"
    echo "$log_section" > "$log_section_file"
    
    # Use awk instead of sed to handle multi-line replacement properly
    # This avoids issues with special characters and newlines in HTML content
    # Read log_section from file to avoid argument length limits
    awk -v error_title="$error_title" \
        -v error_message="$error_message" \
        -v error_instructions="$error_instructions" \
        -v current_date="$current_date" \
        -v uspot="${uSPOT}" \
        -v log_section_file="$log_section_file" \
        'BEGIN {
            # Read log section from file
            log_section = ""
            while ((getline line < log_section_file) > 0) {
                log_section = log_section line "\n"
            }
            close(log_section_file)
        }
        {
            gsub(/_ERROR_TITLE_/, error_title);
            gsub(/_ERROR_MESSAGE_/, error_message);
            gsub(/_ERROR_INSTRUCTIONS_/, error_instructions);
            gsub(/_DATE_/, current_date);
            gsub(/_uSPOT_/, uspot);
            gsub(/_LOG_SECTION_/, log_section);
            print
        }' "$template_file" > "$temp_email_file"
    
    # Clean up temp log section file
    rm -f "$log_section_file" 2>/dev/null
    
    # Verify the output file is not empty
    if [[ ! -s "$temp_email_file" ]]; then
        log_debug "ERROR: Generated email file is empty"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Generated email file is empty" >&2
        # Fallback: create a simple HTML email directly
        cat > "$temp_email_file" << EOF
<!DOCTYPE html>
<html>
<head><meta charset='UTF-8'><title>${error_title}</title></head>
<body style="font-family: 'Courier New', monospace; background: #f5f5f5; padding: 20px;">
<div style="max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px;">
<h2 style="color: #f5576c;">${error_title}</h2>
<p>${error_message}</p>
<div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; border-radius: 5px; margin: 15px 0;">
${error_instructions}
<p><strong>Date :</strong> ${current_date}</p>
</div>
${log_section}
<p><a href="${uSPOT}/cookie">Gérer vos cookies YouTube</a></p>
</div>
</body>
</html>
EOF
        log_debug "Created fallback email file"
    fi
    
    log_debug "Template loaded from: $template_file"
    log_debug "Email file created: $temp_email_file (size: $(stat -c%s "$temp_email_file" 2>/dev/null || echo 0) bytes)"
    
    # Envoyer l'email via mailjet avec durée éphémère de 24h
    ${MY_PATH}/../tools/mailjet.sh --expire 24h "${player}" "$temp_email_file" "$error_title" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log_debug "Error notification sent successfully to $player"
    else
        log_debug "Failed to send error notification to $player"
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
    rm -f "$HOME/.zen/tmp/process_youtube_output_*" 2>/dev/null || true
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
    # Récupérer l'espace disponible pour la notification
    local available_space=$(df "$UDRIVE_PATH" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    local available_mb="unknown"
    if [[ "$available_space" =~ ^[0-9]+$ ]]; then
        available_mb=$((available_space / 1024))
    fi
    # Envoyer une notification d'erreur pour espace disque insuffisant
    send_error_notification "$PLAYER" "disk_space" "${available_mb}MB"
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Disk space check passed" >&2

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting YouTube likes synchronization..." >&2
# Lancer la synchronisation
sync_youtube_likes "$PLAYER" "$COOKIE_FILE" "$PROCESSED_VIDEOS_FILE"
sync_exit_code=$?

if [[ $sync_exit_code -eq 0 ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: YouTube likes sync completed successfully for $PLAYER" >&2
    log_debug "YouTube likes sync completed successfully for $PLAYER"
    exit 0
elif [[ $sync_exit_code -eq 2 ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COOKIE_EXPIRED: YouTube cookies are no longer valid for $PLAYER" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Please visit /cookie page to re-upload fresh cookies from a private window" >&2
    log_debug "YouTube cookies expired for $PLAYER - need re-export from private window"
    # La notification d'erreur pour cookie expiré est déjà envoyée dans sync_youtube_likes
    exit 2
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: YouTube likes sync failed for $PLAYER" >&2
    log_debug "YouTube likes sync failed for $PLAYER"
    # La notification d'erreur pour sync_failed est déjà envoyée dans sync_youtube_likes
    exit 1
fi
