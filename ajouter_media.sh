#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# SCRIPT INTERACTIF POUR AJOUTER UN FICHIER à UPLANET
# Compatible avec UPlanet_FILE_CONTRACT.md
# Utilise upload2ipfs.sh et l'API FastAPI (/api/fileupload, /webcam)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# REMOVE GtkDialog errors for zenity
shopt -s expand_aliases
alias zenity='zenity 2> >(grep -v GtkDialog >&2)'

# Notification function - supports multiple methods
# Alternatives to espeak: notify-send (desktop notifications), zenity (GUI), or console output
notify_user() {
    local message="$1"
    local priority="${2:-normal}"  # low, normal, critical
    
    # Method 1: Desktop notifications (notify-send) - RECOMMENDED
    # Works on most Linux desktop environments (GNOME, KDE, XFCE, etc.)
    if command -v notify-send &> /dev/null; then
        notify-send --urgency="$priority" --expire-time=3000 \
            "UPlanet Media" "$message" 2>/dev/null || true
        return 0
    fi
    
    # Method 2: Zenity info dialog (fallback if notify-send not available)
    # Non-intrusive popup that auto-closes after 3 seconds
    if command -v zenity &> /dev/null && [[ -z "$2" ]]; then
        zenity --info --title="UPlanet Media" --text="$message" --timeout=3 2>/dev/null || true
        return 0
    fi
    
    # Method 3: Console output with emoji (always available)
    # Fallback that always works, even in headless environments
    echo "🔔 $message" >&2
    
    # Method 4: espeak (if available and user explicitly enables audio)
    # Only used if ENABLE_AUDIO_NOTIFICATIONS=yes environment variable is set
    if command -v espeak &> /dev/null && [[ "${ENABLE_AUDIO_NOTIFICATIONS:-}" == "yes" ]]; then
        /usr/bin/espeak "$message" >/dev/null 2>&1 || true
    fi
}

# Legacy espeak alias for backward compatibility
# All existing espeak calls will now use notify_user() instead
# This provides desktop notifications by default, with espeak as optional fallback
alias espeak='notify_user'

## CHECK IF IPFS DAEMON IS RUNNING
floop=0
while [[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]]; do
    sleep 1
    ((floop++)) && [ $floop -gt 5 ] \
        && echo "ERROR. IPFS daemon not running on port 5001" \
        && espeak 'ERROR. I P F S daemon not running' \
        && exit 1
done

. "${MY_PATH}/tools/my.sh"
[[ $IPFSNODEID == "" ]] && echo "IPFSNODEID manquant" && espeak "IPFS NODE ID Missing" && exit 1

start=`date +%s`

########################################################################
# Check dependencies
[[ $(which ipfs) == "" ]] && echo "ERREUR! Installez ipfs" && exit 1
[[ $(which zenity) == "" ]] && echo "ERREUR! Installez zenity" && echo "sudo apt install zenity" && exit 1
[[ $(which curl) == "" ]] && echo "ERREUR! Installez curl" && exit 1
[[ $(which jq) == "" ]] && echo "ERREUR! Installez jq" && exit 1

mkdir -p ~/.zen/tmp/
LOG_FILE="$HOME/.zen/tmp/ajouter_media.log"
# Properly redirect both stdout and stderr to log file while also showing on terminal
exec > >(tee -a "$LOG_FILE")
exec 2>&1

URL="$1"
PLAYER="$2"
CHOICE="$3"
echo ">>> RUNNING 'ajouter_media.sh' URL=$URL PLAYER=$PLAYER CHOICE=$CHOICE"
echo ">>> Log file: $LOG_FILE"

# API endpoint
API_URL="http://127.0.0.1:54321"

# Check who is PLAYER ?
if [[ ${PLAYER} == "" ]]; then
    players=($(ls ~/.zen/game/nostr 2>/dev/null | grep "@"))
    if [[ ${#players[@]} -ge 1 ]]; then
        espeak "SELECT YOUR MULTIPASS"
        OUTPUT=$(zenity --list --width 480 --height 200 --title="Choix du PLAYER" --column="Astronaute" "${players[@]}")
        [[ ${OUTPUT} == "" ]] && espeak "No player selected. EXIT" && exit 1
    else
        OUTPUT="${players}"
    fi
    PLAYER=${OUTPUT}
else
    OUTPUT=${PLAYER}
fi

####### NO CURRENT ? PLAYER = .current
[[ ! -d $(readlink ~/.zen/game/players/.current 2>/dev/null) ]] \
    && rm -f ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

echo "ADMIN : "$(cat ~/.zen/game/players/.current/.player 2>/dev/null)

[[ ${OUTPUT} != ""  ]] \
&& espeak "${OUTPUT} CONNECTED" \
&& . "${MY_PATH}/tools/my.sh"

## NO PLAYER AT ALL
[[ ${OUTPUT} == "" ]] \
&& espeak "Astronaut. Please register." \
&& xdg-open "$API_URL/g1" \
&& exit 1 \
PSEUDO=$(myPlayerUser)

$($MY_PATH/tools/search_for_this_email_in_players.sh ${PLAYER} | tail -n 1)

espeak "Hello $PSEUDO"

## MULTIPASS (Zen)
G1PUB=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
[[ $G1PUB == "" ]] && espeak "ERROR NO G 1 PUBLIC KEY FOUND - EXIT" && exit 1

# Get NOSTR npub and hex from player
NPUB=$(cat ~/.zen/game/nostr/${PLAYER}/NPUB 2>/dev/null || echo "")
    NPUB_HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX 2>/dev/null || echo "")

# If we have NPUB but not HEX, try to convert (or use search_for_this_email_in_players.sh)
if [[ -z "$NPUB_HEX" ]] && [[ -n "$NPUB" ]]; then
    # Try to get HEX from user directory lookup
    USER_NOSTR_DIR="$HOME/.zen/game/nostr/${PLAYER}"
    if [[ -d "$USER_NOSTR_DIR" ]]; then
        # Check if there's a .secret.nostr file we can extract pubkey from
        if [[ -f "$USER_NOSTR_DIR/.secret.nostr" ]]; then
            # Try to extract pubkey from secret file (if it contains pubkey info)
            # For now, we'll use a helper script if available
            if [[ -f "${MY_PATH}/tools/nostr2hex.py" ]]; then
                NPUB_HEX=$(python3 "${MY_PATH}/tools/nostr2hex.py" "$NPUB" 2>/dev/null || echo "")
            fi
        fi
    fi
fi

# If still no HEX, try to get from search_for_this_email_in_players.sh output
if [[ -z "$NPUB_HEX" ]]; then
    SEARCH_OUTPUT=$($MY_PATH/tools/search_for_this_email_in_players.sh ${PLAYER} 2>/dev/null | tail -n 1)
    # Extract hex from output if available
    if echo "$SEARCH_OUTPUT" | grep -qE '^[a-f0-9]{64}$'; then
        NPUB_HEX="$SEARCH_OUTPUT"
    fi
fi

if [[ -z "$NPUB_HEX" ]] && [[ -z "$NPUB" ]]; then
        echo "⚠️  No NOSTR keys found for player ${PLAYER}"
    echo "⚠️  Upload will work but provenance tracking will be disabled"
fi

# Function to get user uDRIVE path
get_user_udrive_path() {
    local player="$1"
    if [[ -n "$player" && "$player" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        local nostr_base_path="$HOME/.zen/game/nostr"
        if [ -d "$nostr_base_path" ]; then
            for email_dir in "$nostr_base_path"/*; do
                if [ -d "$email_dir" ] && [[ "$email_dir" == *"$player"* ]]; then
                    local udrive_path="$email_dir/APP/uDRIVE"
                    mkdir -p "$udrive_path"
                    echo "$udrive_path"
                    return 0
                fi
            done
        fi
    fi
    return 1
}

# Get user uDRIVE path for file storage
USER_UDRIVE_PATH=$(get_user_udrive_path "$PLAYER")
if [[ -n "$USER_UDRIVE_PATH" ]]; then
    echo "✅ Using uDRIVE path: $USER_UDRIVE_PATH"
else
    echo "⚠️  Could not determine uDRIVE path for player: $PLAYER"
    USER_UDRIVE_PATH="$HOME/.zen/tmp"
fi

########################################################################
## EXCEPTION COPIE PRIVE
if [[ ! -f ~/.zen/game/nostr/${PLAYER}/legal ]]; then
    zenity --width 600 --height 400 --text-info \
       --title="Action conforme avec le Code de la propriété intellectuelle" \
       --html \
       --url="https://fr.wikipedia.org/wiki/Droit_d%27auteur_en_France#Les_exceptions_au_droit_d%E2%80%99auteur" \
       --checkbox="J'ai lu et j'accepte les termes."

case $? in
    0)
            echo "AUTORISATION COPIE PRIVE UPLANET OK !"
        echo "$G1PUB" > ~/.zen/game/players/${PLAYER}/legal
    ;;
    1)
        echo "Refus conditions"
        rm -f ~/.zen/game/players/${PLAYER}/legal
        exit 1
    ;;
    -1)
        echo "Erreur."
        exit 1
    ;;
esac
fi

########################################################################
# CHOOSE CATEGORY
if [ $URL ]; then
    echo "URL: $URL"
    REVSOURCE="$(echo "$URL" | awk -F/ '{print $3}' | rev)_"
    [[ ${CHOICE} == "" ]] && IMPORT=$(zenity --entry --width 640 --title="$URL => UPlanet" --text="${PLAYER} Type de media à importer ?" --entry-text="Video" PDF MP3) || IMPORT="$CHOICE"
    [[ $IMPORT == "" ]] && espeak "No choice made. Exit" && exit 1
    [[ $IMPORT == "Video" ]] && IMPORT="Youtube"
    CHOICE="$IMPORT"
fi

[ ! $2 ] && [[ $CHOICE == "" ]] && CHOICE=$(zenity --list --width 300 --height 250 --title="Catégorie" --text="Quelle catégorie pour ce media ?" --column="Catégorie" "Vlog" "Video" "Film" "Serie" "PDF" "Youtube" "MP3" 2>/dev/null)
[[ $CHOICE == "" ]] && echo "NO CHOICE MADE" && exit 1

# LOWER CARACTERS
CAT=$(echo "${CHOICE}" | awk '{print tolower($0)}')
# UPPER CARACTERS
CHOICE=$(echo "${CAT}" | awk '{print toupper($0)}')

PREFIX=$(echo "${CAT}" | head -c 1 | awk '{ print toupper($0) }' ) # ex: F, S, A, Y, M ... P W
[[ $PREFIX == "" ]] && exit 1

########################################################################
########################################################################
case ${CAT} in
########################################################################
# CASE ## VLOG - Redirect to webcam endpoint
########################################################################
    vlog)
        espeak "Opening webcam interface"
        xdg-open "${API_URL}/webcam" 2>/dev/null || echo "Open ${API_URL}/webcam in your browser"
    exit 0
    ;;

########################################################################
# CASE ## YOUTUBE
########################################################################
    youtube)
    espeak "youtube : video copying"

    YTURL="$URL"
    [ ! $2 ] && [[ $YTURL == "" ]] && YTURL=$(zenity --entry --width 420 --title "Lien ou identifiant à copier" --text "Indiquez le lien (URL) ou l'ID de la vidéo" --entry-text="")
    [[ $YTURL == "" ]] && echo "URL EMPTY " && exit 1

    echo "VIDEO $YTURL"
    echo "Processing URL: $YTURL"

    # Create temporary download directory
    TEMP_YOUTUBE_DIR="$HOME/.zen/tmp.media/youtube_$(date -u +%s%N | cut -b1-13)"
    mkdir -p "$TEMP_YOUTUBE_DIR"

    # CONSERVÉ : Monitor download progress (feedback vocal)
    monitor_download_progress() {
        local download_dir="$1"
        local start_time=$(date +%s)
        local last_announce_time=$start_time
        local announce_interval=30
        local step=0
        
        while true; do
            sleep 5
            local mp4_files=$(find "$download_dir" -maxdepth 1 -name "*.mp4" -type f 2>/dev/null)
            if [[ -n "$mp4_files" ]]; then
                local file_size1=$(stat -c%s "$mp4_files" 2>/dev/null || echo "0")
                sleep 3
                local file_size2=$(stat -c%s "$mp4_files" 2>/dev/null || echo "0")
                if [[ "$file_size1" == "$file_size2" ]] && [[ $file_size1 -gt 1000000 ]]; then
                    espeak "Download complete" 2>/dev/null || true
                    break
                fi
            fi
            
            local current_time=$(date +%s)
            local elapsed=$((current_time - last_announce_time))
            local total_elapsed=$((current_time - start_time))
            
            if [[ $total_elapsed -gt 7200 ]]; then break; fi
            
            if [[ $elapsed -ge $announce_interval ]]; then
                step=$((step + 1))
                local minutes=$((total_elapsed / 60))
                local seconds=$((total_elapsed % 60))
                if [[ -n "$mp4_files" ]]; then
                    local current_size=$(stat -c%s "$mp4_files" 2>/dev/null || echo "0")
                    local size_mb=$(echo "$current_size" | awk '{printf "%.1f", $1 / (1024 * 1024)}')
                    espeak "Download in progress. Step $step. ${minutes} minutes ${seconds} seconds. ${size_mb} megabytes downloaded" 2>/dev/null || true
                else
                    espeak "Download in progress. Step $step. ${minutes} minutes ${seconds} seconds" 2>/dev/null || true
                fi
                last_announce_time=$current_time
            fi
        done
    }

    espeak "Starting YouTube download" 2>/dev/null || true
    monitor_download_progress "$TEMP_YOUTUBE_DIR" &
    MONITOR_PID=$!

    JSON_OUTPUT_FILE="$HOME/.zen/tmp/youtube_json_$$.json"
    mkdir -p "$(dirname "$JSON_OUTPUT_FILE")"

    # $PLAYER pour les cookies
    echo "📥 Downloading YouTube video (Max 480p) via process_youtube.sh..."
    ${MY_PATH}/IA/process_youtube.sh --json-file "$JSON_OUTPUT_FILE" --output-dir "$TEMP_YOUTUBE_DIR" "$YTURL" "mp4" "$PLAYER"
    YTDLP_EXIT=$?

    # Stop monitoring
    kill $MONITOR_PID 2>/dev/null || true
    wait $MONITOR_PID 2>/dev/null || true

    # Validation JSON
    if [[ ! -f "$JSON_OUTPUT_FILE" || ! -s "$JSON_OUTPUT_FILE" ]]; then
        echo "❌ ERROR: Le JSON de retour est manquant ou vide."
        espeak "YouTube download failed"
        exit 1
    fi

    YOUTUBE_JSON=$(cat "$JSON_OUTPUT_FILE")
    rm -f "$JSON_OUTPUT_FILE"

    if echo "$YOUTUBE_JSON" | jq -e '.error' >/dev/null 2>&1; then
        ERROR_MSG=$(echo "$YOUTUBE_JSON" | jq -r '.error')
        [ -z "$2" ] && command -v zenity &> /dev/null && zenity --error --width 600 --title="YouTube Download Error" --text="❌ ERROR: $ERROR_MSG" 2>/dev/null || true
        echo "❌ ERROR: $ERROR_MSG"
        espeak "YouTube processing error"
        exit 1
    fi

    # Extraction des données
    TITLE_RAW=$(echo "$YOUTUBE_JSON" | jq -r '.title // empty')
    TITLE=$(echo "$TITLE_RAW" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
    DURATION=$(echo "$YOUTUBE_JSON" | jq -r '.duration // "0"')
    FILENAME=$(echo "$YOUTUBE_JSON" | jq -r '.filename // empty')
    FILE_PATH_DOWNLOADED=$(echo "$YOUTUBE_JSON" | jq -r '.file_path // empty')
    METADATA_FILE_FROM_JSON=$(echo "$YOUTUBE_JSON" | jq -r '.metadata_file // empty')

    if [[ -z "$FILENAME" || -z "$FILE_PATH_DOWNLOADED" || ! -f "$FILE_PATH_DOWNLOADED" ]]; then
        echo "❌ ERROR: Downloaded file not found."
        espeak "Download failed"
        exit 1
    fi

    echo "✅ Downloaded: $FILENAME (Duration: $DURATION s)"
    espeak "Download completed successfully." 2>/dev/null || true

    # IMPORTANT : NIP-42 Authentication (Critique pour l'API)
    echo "🔐 Sending NIP-42 authentication event..."
    SECRET_NOSTR_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
    NOSTR_SEND_SCRIPT="${MY_PATH}/tools/nostr_send_note.py"
    NOSTR_RELAY="ws://127.0.0.1:7777"

    _write_nip42_marker() {
        local marker_hex="$1"
        local event_hash="$2"
        local marker_dir="$HOME/.zen/game/nostr/${PLAYER}"
        local marker_file="${marker_dir}/.nip42_auth_${marker_hex}"
        local now_ts=$(date +%s)
        printf '{"pubkey":"%s","event_hash":"%s","created_at":%d}' "$marker_hex" "$event_hash" "$now_ts" > "$marker_file" 2>/dev/null
        [[ -f "${marker_dir}/.nip42_auth" ]] && rm -f "${marker_dir}/.nip42_auth" 2>/dev/null || true
    }

    if [[ -f "$SECRET_NOSTR_FILE" ]] && [[ -f "$NOSTR_SEND_SCRIPT" ]]; then
        NIP42_CHALLENGE=""
        if [[ -n "$NPUB_HEX" ]]; then
            NIP42_CHALLENGE=$(curl -sf "http://127.0.0.1:54321/api/nip42/challenge?npub=${NPUB_HEX}" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('challenge',''))" 2>/dev/null || echo "")
        fi
        [[ -z "$NIP42_CHALLENGE" ]] && NIP42_CHALLENGE="local-$(date +%s)-${IPFSNODEID:0:8}"

        NIP42_OUTPUT=$(python3 "$NOSTR_SEND_SCRIPT" --keyfile "$SECRET_NOSTR_FILE" --content "${IPFSNODEID} ${UPLANETNAME_G1}" --kind 22242 --tags '[["relay","'${NOSTR_RELAY}'"],["challenge","'"${NIP42_CHALLENGE}"'"]]' --relays "$NOSTR_RELAY" 2>&1)
        
        NIP42_EVENT_ID=$(echo "$NIP42_OUTPUT" | grep -oE '"event_id"\s*:\s*"[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}' | head -1)
        if [[ -n "$NIP42_EVENT_ID" ]]; then
            [[ -n "$NPUB_HEX" ]] && _write_nip42_marker "$NPUB_HEX" "$NIP42_EVENT_ID"
            sleep 2
        else
            [[ -n "$NPUB_HEX" ]] && _write_nip42_marker "$NPUB_HEX" "" || true
        fi
    else
        [[ -n "$NPUB_HEX" ]] && _write_nip42_marker "$NPUB_HEX" "" || true
    fi

    # CONSERVÉ : Extraction Complète des Métadonnées Youtube (Pour le contrat UPlanet v2.0)
    YOUTUBE_METADATA_JSON_FILE="$HOME/.zen/tmp/youtube_metadata_$(date +%s).json"
    if [[ -n "$METADATA_FILE_FROM_JSON" ]] && [[ -f "$METADATA_FILE_FROM_JSON" ]] && command -v jq &> /dev/null; then
        echo "📋 Extracting comprehensive YouTube metadata..."
        jq '{
            youtube_id: .id, youtube_url: .webpage_url, youtube_short_url: .short_url,
            title: .title, description: .description, uploader: .uploader,
            uploader_id: .uploader_id, uploader_url: .uploader_url, channel: .channel,
            channel_id: .channel_id, channel_url: .channel_url, channel_follower_count: .channel_follower_count,
            duration: .duration, view_count: .view_count, like_count: .like_count, comment_count: .comment_count,
            average_rating: .average_rating, age_limit: .age_limit, upload_date: .upload_date, release_date: .release_date,
            timestamp: .timestamp, availability: .availability, live_status: .live_status, was_live: .was_live,
            format: .format, format_id: .format_id, format_note: .format_note, width: .width, height: .height,
            fps: .fps, vcodec: .vcodec, acodec: .acodec, abr: .abr, vbr: .vbr, tbr: .tbr, filesize: .filesize,
            filesize_approx: .filesize_approx, ext: .ext, resolution: .resolution, categories: .categories,
            tags: .tags, chapters: .chapters, subtitles: .subtitles, automatic_captions: .automatic_captions,
            thumbnail: .thumbnail, thumbnails: .thumbnails, license: .license, language: .language,
            languages: .languages, location: .location, artist: .artist, album: .album, track: .track,
            creator: .creator, alt_title: .alt_title, series: .series, season: .season, season_number: .season_number,
            episode: .episode, episode_number: .episode_number, playlist: .playlist, playlist_id: .playlist_id,
            playlist_title: .playlist_title, playlist_index: .playlist_index, n_entries: .n_entries,
            webpage_url_basename: .webpage_url_basename, webpage_url_domain: .webpage_url_domain, extractor: .extractor,
            extractor_key: .extractor_key, epoch: .epoch, modified_timestamp: .modified_timestamp, modified_date: .modified_date,
            requested_subtitles: .requested_subtitles, has_drm: .has_drm, is_live: .is_live, release_timestamp: .release_timestamp, heatmap: .heatmap
        }' "$METADATA_FILE_FROM_JSON" > "$YOUTUBE_METADATA_JSON_FILE" 2>/dev/null || rm -f "$YOUTUBE_METADATA_JSON_FILE"
    fi

    # API UPLOAD
    echo "📤 Uploading video via /api/fileupload..."
    espeak "Starting video upload to IPFS" 2>/dev/null || true
    
    if [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]]; then
        UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_PATH_DOWNLOADED}" -F "npub=${NPUB}" -F "youtube_metadata=@${YOUTUBE_METADATA_JSON_FILE}")
    else
        UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_PATH_DOWNLOADED}" -F "npub=${NPUB}")
    fi
    
    if ! echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
        echo "❌ ERROR: /api/fileupload failed. Response: $UPLOAD_RESPONSE"
        espeak "Upload failed"
        exit 1
    fi

    IPFS_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.new_cid // empty')
    INFO_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.info // empty')
    THUMBNAIL_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.thumbnail_ipfs // empty')
    GIFANIM_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.gifanim_ipfs // empty')
    FILE_HASH=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileHash // empty')
    DIMENSIONS=$(echo "$UPLOAD_RESPONSE" | jq -r '.dimensions // empty')
    UPLOAD_CHAIN=$(echo "$UPLOAD_RESPONSE" | jq -r '.upload_chain // empty')

    echo "✅ Video uploaded to IPFS! CID: $IPFS_CID"
    espeak "Video uploaded successfully" 2>/dev/null || true

    # User Input & Description
    [ ! $2 ] && VIDEO_TITLE=$(zenity --entry --width 600 --title "Titre de la vidéo" --text "Confirmez le titre" --entry-text="$TITLE")
    [[ -z "$VIDEO_TITLE" ]] && VIDEO_TITLE="$TITLE"
    
    [ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description de la vidéo (optionnel)" --entry-text="")
    
    # Auto-enrich desc with YouTube Info
    if [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]] && command -v jq &> /dev/null; then
        YT_UPLOADER=$(jq -r '.uploader // .channel // empty' "$YOUTUBE_METADATA_JSON_FILE" 2>/dev/null)
        YT_URL=$(jq -r '.youtube_url // .webpage_url // empty' "$YOUTUBE_METADATA_JSON_FILE" 2>/dev/null)
        if [[ -n "$YT_UPLOADER" ]] || [[ -n "$YT_URL" ]]; then
            [[ -n "$VIDEO_DESC" ]] && VIDEO_DESC="${VIDEO_DESC}  Source YouTube: ${YT_UPLOADER}\n${YT_URL}" || VIDEO_DESC="Source YouTube: ${YT_UPLOADER}\n${YT_URL}"
        fi
    fi

    # API PUBLISH (NIP-71)
    echo "📹 Publishing video via /webcam endpoint..."
    PUBLISH_DATA="player=${PLAYER}&ipfs_cid=${IPFS_CID}&thumbnail_ipfs=${THUMBNAIL_CID}&gifanim_ipfs=${GIFANIM_CID}&info_cid=${INFO_CID}&file_hash=${FILE_HASH}&mime_type=video/mp4&upload_chain=${UPLOAD_CHAIN}&duration=${DURATION}&video_dimensions=${DIMENSIONS}&title=${VIDEO_TITLE}&description=${VIDEO_DESC}&publish_nostr=true&npub=${NPUB}&youtube_url=${YTURL}"
    
    PUBLISH_RESPONSE=$(curl -s -X POST "${API_URL}/webcam" -H "Content-Type: application/x-www-form-urlencoded" -d "$PUBLISH_DATA")
    
    if echo "$PUBLISH_RESPONSE" | grep -q "success\|✅"; then
        echo "✅ Video published successfully!"
        espeak "YouTube video published"
    else
        echo "⚠️ Publication may have failed. Response: $PUBLISH_RESPONSE"
    fi

    # Cleanup
    rm -rf "$TEMP_YOUTUBE_DIR"
    [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]] && rm -f "$YOUTUBE_METADATA_JSON_FILE"
    ;;

########################################################################
# CASE ## PDF
########################################################################
    pdf)
        espeak "Importing file or web page to P D F"

        [ ! $2 ] && [[ $URL == "" ]] && URL=$(zenity --entry --width 500 --title "Convertir lien PDF (ANNULER ET CHOISIR UN FICHIER LOCAL)" --text "Indiquez le lien (URL)" --entry-text="")

        if [[ $URL != "" ]]; then
    ## record one page to PDF
            [ ! $2 ] && [[ ! $(which chromium) ]] && zenity --warning --width 600 --text "Utilitaire de copie de page web absent.. Lancez la commande 'sudo apt install chromium'" && exit 1

            cd ~/.zen/tmp/ && rm -f output.pdf

            ${MY_PATH}/tools/timeout.sh -t 30 \
            chromium --headless --use-mobile-user-agent --no-sandbox --print-to-pdf "$URL"
        fi

        if [[ $URL == "" ]]; then
            # SELECT FILE TO ADD
            [ ! $2 ] && FILE=$(zenity --file-selection --title="Sélectionner le fichier à ajouter")
            echo "${FILE}"
            [[ ! -s "${FILE}" ]] && echo "NO FILE" && exit 1

            FILE_NAME="$(basename "${FILE}")"
            cp "${FILE}" ~/.zen/tmp/output.pdf
        fi

        [[ ! -s ~/.zen/tmp/output.pdf ]] && espeak "No file Sorry. Exit" && exit 1

        espeak "OK P D F received"

        CTITLE=$(echo $URL | rev | cut -d '/' -f 1 | rev 2>/dev/null || echo "document")
        [ ! $2 ] && TITLE=$(zenity --entry --width 480 --title "Titre" --text "Quel nom donner à ce fichier ? " --entry-text="${CTITLE}") || TITLE="$CTITLE"
        [[ "$TITLE" == "" ]] && echo "NO TITLE" && exit 1

        FILE_NAME="$(echo "${TITLE}" | detox --inline).pdf"
        
        # Rename temp file (upload2ipfs.sh will handle uDRIVE storage)
        FILE_TO_UPLOAD="$HOME/.zen/tmp/$FILE_NAME"
        mv ~/.zen/tmp/output.pdf "$FILE_TO_UPLOAD"
        
        # Upload via API (upload2ipfs.sh will copy to uDRIVE)
        echo "📤 Uploading PDF via /api/fileupload..."
        
        if [[ -n "$NPUB" ]]; then
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_TO_UPLOAD}" \
                -F "npub=${NPUB}")
        else
            echo "⚠️  No NOSTR npub found, upload may fail"
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_TO_UPLOAD}" \
                -F "npub=")
        fi
        
        if echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
            echo "✅ PDF uploaded and published successfully!"
            espeak "Document ready"
        else
            echo "❌ Upload failed"
            echo "Response: $UPLOAD_RESPONSE"
            espeak "Upload failed"
            exit 1
        fi
    ;;

########################################################################
# CASE ## MP3
########################################################################
    mp3)
        [[ "$URL" == "" ]] && URL=$(zenity --entry --width 500 --title "Lien Youtube à convertir en MP3" --text "Indiquez le lien (URL)" --entry-text="")
        [[ "$URL" == "" ]] && echo "URL EMPTY" && exit 1
        
        echo "Processing URL: $URL"
        espeak "OK. Downloading MP 3"

        TEMP_MP3_DIR="$HOME/.zen/tmp.media/mp3_$(date -u +%s%N | cut -b1-13)"
        mkdir -p "$TEMP_MP3_DIR"
        MP3_JSON_FILE="$HOME/.zen/tmp/youtube_mp3_json_$$.json"
        
        # 1. Téléchargement local
        bash "${MY_PATH}/IA/process_youtube.sh" --json-file "$MP3_JSON_FILE" --output-dir "$TEMP_MP3_DIR" "$URL" "mp3"
        
        if [[ ! -f "$MP3_JSON_FILE" ]]; then
            espeak "MP3 processing failed"
            exit 1
        fi
        
        MP3_RESULT=$(cat "$MP3_JSON_FILE")
        rm -f "$MP3_JSON_FILE"
        
        if echo "$MP3_RESULT" | jq -e '.error' >/dev/null 2>&1; then
            ERROR_MSG=$(echo "$MP3_RESULT" | jq -r '.error')
            echo "MP3 processing failed: $ERROR_MSG"
            espeak "MP3 processing failed"
            exit 1
        fi
        
        FILE_TO_UPLOAD=$(echo "$MP3_RESULT" | jq -r '.file_path')
        FILENAME=$(echo "$MP3_RESULT" | jq -r '.filename')
        TITLE=$(echo "$MP3_RESULT" | jq -r '.title')
        DURATION=$(echo "$MP3_RESULT" | jq -r '.duration')
        YOUTUBE_METADATA_FILE=$(echo "$MP3_RESULT" | jq -r '.metadata_file')
        
        if [[ -z "$FILE_TO_UPLOAD" || ! -f "$FILE_TO_UPLOAD" ]]; then
            echo "⚠️ MP3 file not found."
            exit 1
        fi
        
        # Demande du titre à l'utilisateur
        [ ! "$2" ] && AUDIO_TITLE=$(zenity --entry --width 600 --title "Titre de l'audio" --text "Confirmez le titre" --entry-text="$TITLE")
        [[ -z "$AUDIO_TITLE" ]] && AUDIO_TITLE="$TITLE"

        # NIP-42 Authentication (Requis par le contrat)
        echo "🔐 Sending NIP-42 authentication event..."
        SECRET_NOSTR_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
        NOSTR_SEND_SCRIPT="${MY_PATH}/tools/nostr_send_note.py"
        if [[ -f "$SECRET_NOSTR_FILE" ]] && [[ -f "$NOSTR_SEND_SCRIPT" ]]; then
            NIP42_CHALLENGE="local-$(date +%s)-${IPFSNODEID:0:8}"
            python3 "$NOSTR_SEND_SCRIPT" --keyfile "$SECRET_NOSTR_FILE" --content "${IPFSNODEID} ${UPLANETNAME_G1}" --kind 22242 --tags '[["relay","ws://127.0.0.1:7777"],["challenge","'"${NIP42_CHALLENGE}"'"]]' --relays "ws://127.0.0.1:7777" >/dev/null 2>&1
            sleep 1
        fi

        # 2. Upload IPFS (Phase 1 du workflow Audio)
        echo "📤 Uploading MP3 via /api/fileupload..."
        if [[ -f "$YOUTUBE_METADATA_FILE" ]]; then
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_TO_UPLOAD}" -F "npub=${NPUB}" -F "youtube_metadata=@${YOUTUBE_METADATA_FILE}")
        else
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_TO_UPLOAD}" -F "npub=${NPUB}")
        fi
        
        if ! echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
            echo "❌ Upload failed: $UPLOAD_RESPONSE"
            espeak "Upload failed"
            exit 1
        fi
        
        IPFS_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.new_cid // empty')
        INFO_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.info // empty')
        FILE_HASH=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileHash // empty')

        echo "✅ MP3 uploaded to IPFS! CID: $IPFS_CID"

        # 3. Publication NOSTR via /vocals (Phase 2 du workflow Audio - Section 3.3 et 7.3.3)
        echo "🎤 Publishing audio via /vocals endpoint (NIP-A0)..."
        PUBLISH_DATA="player=${PLAYER}&ipfs_cid=${IPFS_CID}&info_cid=${INFO_CID}&file_hash=${FILE_HASH}&mime_type=audio/mp3&file_name=${FILENAME}&duration=${DURATION}&title=${AUDIO_TITLE}&description=Source YouTube: ${URL}&npub=${NPUB}&publish_nostr=true&encrypted=false"
        
        VOCALS_RESPONSE=$(curl -s -X POST "${API_URL}/vocals" -H "Content-Type: application/x-www-form-urlencoded" -d "$PUBLISH_DATA")
        
        echo "✅ MP3 published successfully!"
        espeak "Ready. MP3 file processed and published"
        
        # Nettoyage
        rm -rf "$TEMP_MP3_DIR"
    ;;

########################################################################
# CASE ## FILM / SERIE
########################################################################
    film | serie)
    espeak "please select your file"

        # SELECT FILE TO ADD
FILE=$(zenity --file-selection --title="Sélectionner le fichier à ajouter")
echo "${FILE}"
[[ $FILE == "" ]] && exit 1

# Remove file extension to get file name => STITLE
FILE_PATH="$(dirname "${FILE}")"
FILE_NAME="$(basename "${FILE}")"
FILE_EXT="${FILE_NAME##*.}"
FILE_TITLE="${FILE_NAME%.*}"

# OPEN default browser and search TMDB
        zenity --question --width 300 --text "Ouvrir https://www.themoviedb.org pour récupérer le numéro d'identification de $(echo ${FILE_TITLE} | sed 's/_/%20/g') ?"
[ $? == 0 ] && xdg-open "https://www.themoviedb.org/search?query=$(echo ${FILE_TITLE} | sed 's/_/%20/g')"

# Get TMDB URL or ID from user
TMDB_URL_INPUT=$(zenity --entry --title="Identification TMDB" --text="Copiez l'URL complète ou le nom de la page du film.\nEx: https://www.themoviedb.org/movie/301528-toy-story-4\nou: 301528-toy-story-4" --entry-text="")
[[ $TMDB_URL_INPUT == "" ]] && exit 1

# Extract MEDIAID and build full URL
if [[ "$TMDB_URL_INPUT" =~ ^https?:// ]]; then
    # Full URL provided
    TMDB_URL="$TMDB_URL_INPUT"
    MEDIAID=$(echo "$TMDB_URL_INPUT" | rev | cut -d '/' -f 1 | rev)
else
    # Just ID or slug provided
    MEDIAID="$TMDB_URL_INPUT"
    # Determine media type and build URL
    if [[ "$CAT" == "serie" ]]; then
        MEDIA_TYPE="tv"
        TMDB_URL="https://www.themoviedb.org/tv/$MEDIAID"
    else
        MEDIA_TYPE="movie"
        TMDB_URL="https://www.themoviedb.org/movie/$MEDIAID"
    fi
fi

# Extract numeric ID from slug (e.g., "301528-toy-story-4" -> "301528")
        MEDIAID=$(echo $MEDIAID | rev | cut -d '/' -f 1 | rev)
CMED=$(echo $MEDIAID | cut -d '-' -f 1)

        if ! [[ "$CMED" =~ ^[0-9]+$ ]]; then
            zenity --warning --width 600 --text "Vous devez renseigner un numéro! Merci de recommencer... Seules les vidéos référencées sur The Movie Database sont acceptées. Sinon importez en mode 'Video'" && exit 1
fi
MEDIAID=$CMED

# Determine media type (film or serie)
if [[ "$CAT" == "serie" ]]; then
    MEDIA_TYPE="tv"
    [[ ! "$TMDB_URL" =~ ^https?:// ]] && TMDB_URL="https://www.themoviedb.org/tv/$MEDIAID"
else
    MEDIA_TYPE="movie"
    [[ ! "$TMDB_URL" =~ ^https?:// ]] && TMDB_URL="https://www.themoviedb.org/movie/$MEDIAID"
fi

# Ask if user wants to scrape TMDB page for metadata
SCRAPE_TMDB="no"
SCRAPED_METADATA=""
if zenity --question --width 400 --title="Scraper TMDB ?" --text="Voulez-vous scraper la page TMDB pour enrichir automatiquement les métadonnées ?  URL: $TMDB_URL"; then
    SCRAPE_TMDB="yes"
    echo "🔍 Scraping TMDB page: $TMDB_URL"
    
    # Get scraper script path
    SCRAPER_SCRIPT="${MY_PATH}/IA/scraper.TMDB.py"
    if [[ ! -f "$SCRAPER_SCRIPT" ]]; then
        SCRAPER_SCRIPT="${HOME}/.zen/Astroport.ONE/IA/scraper.TMDB.py"
    fi
    if [[ ! -f "$SCRAPER_SCRIPT" ]]; then
        SCRAPER_SCRIPT="${HOME}/workspace/AAA/Astroport.ONE/IA/scraper.TMDB.py"
    fi
    
    if [[ -f "$SCRAPER_SCRIPT" ]]; then
        SCRAPED_METADATA=$(python3 "$SCRAPER_SCRIPT" "$TMDB_URL" 2>/dev/null)
        if [[ -n "$SCRAPED_METADATA" ]] && echo "$SCRAPED_METADATA" | jq -e '.' >/dev/null 2>&1; then
            echo "✅ TMDB metadata scraped successfully"
            # Display extracted genres if available
            SCRAPED_GENRES=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
            if [[ -n "$SCRAPED_GENRES" ]] && [[ "$SCRAPED_GENRES" != "" ]]; then
                echo "   📋 Genres found: $SCRAPED_GENRES"
            fi
        else
            echo "⚠️  Failed to scrape TMDB metadata, using manual input"
            SCRAPED_METADATA=""
        fi
    else
        echo "⚠️  Scraper script not found, using manual input"
        SCRAPE_TMDB="no"
    fi
fi

# Extract or ask for title
# For series, we need to distinguish between series name and episode title
SERIES_NAME=""
EPISODE_NAME=""
if [[ "$CAT" == "serie" ]]; then
    # For series, extract series name from scraped metadata
    if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
        SERIES_NAME=$(echo "$SCRAPED_METADATA" | jq -r '.title // .name // empty' 2>/dev/null)
    fi
    # If series name not found, ask user or use base title
    if [[ -z "$SERIES_NAME" ]]; then
        [ ! $2 ] && SERIES_NAME=$(zenity --entry --width 400 --title "Nom de la série" --text "Indiquez le nom de la série" --entry-text="$FILE_TITLE")
        [[ -z "$SERIES_NAME" ]] && SERIES_NAME="$FILE_TITLE"
    fi
    SERIES_NAME=$(echo "${SERIES_NAME}" | detox --inline)
    
    # Episode title (default to file title, user can edit)
    EPISODE_NAME_DEFAULT="$FILE_TITLE"
    if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
        # Try to get episode title from scraped metadata
        EPISODE_TITLE_FROM_META=$(echo "$SCRAPED_METADATA" | jq -r '.episode_title // .episode_name // empty' 2>/dev/null)
        [[ -n "$EPISODE_TITLE_FROM_META" ]] && EPISODE_NAME_DEFAULT="$EPISODE_TITLE_FROM_META"
    fi
    # Clean episode title before showing to user (remove underscores that might come from scraper)
    EPISODE_NAME_CLEAN=$(echo "$EPISODE_NAME_DEFAULT" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
    # Ask user for episode title
    [ ! $2 ] && EPISODE_NAME=$(zenity --entry --width 400 --title "Titre de l'épisode" --text "Indiquez le titre de l'épisode" --entry-text="$EPISODE_NAME_CLEAN") || EPISODE_NAME="$EPISODE_NAME_CLEAN"
    [[ -z "$EPISODE_NAME" ]] && EPISODE_NAME="$EPISODE_NAME_CLEAN"
    # Clean episode name for filename only (detox replaces spaces with underscores)
    EPISODE_NAME_FOR_FILENAME=$(echo "${EPISODE_NAME}" | detox --inline)
    # Keep original episode name (with spaces) for NOSTR publication
    EPISODE_NAME_FOR_PUBLICATION="$EPISODE_NAME"
    
    # Use episode name as TITLE for compatibility with existing code
    TITLE="$EPISODE_NAME_FOR_FILENAME"
    # Keep original title (with spaces) for NOSTR publication
    TITLE_FOR_PUBLICATION="$EPISODE_NAME_FOR_PUBLICATION"
else
    # For films/videos, use regular title extraction
    if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
        TITLE=$(echo "$SCRAPED_METADATA" | jq -r '.title // empty' 2>/dev/null)
        if [[ -z "$TITLE" ]]; then
            TITLE="$FILE_TITLE"
        fi
    else
        TITLE="$FILE_TITLE"
    fi
    
    # VIDEO TITLE (ask user to confirm/edit)
    # Clean title before showing to user (remove underscores that might come from scraper)
    TITLE_CLEAN_FOR_DISPLAY=$(echo "$TITLE" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
    [ ! $2 ] && TITLE=$(zenity --entry --width 300 --title "Titre" --text "Indiquez le titre de la vidéo" --entry-text="$TITLE_CLEAN_FOR_DISPLAY") || TITLE="$TITLE_CLEAN_FOR_DISPLAY"
    [[ $TITLE == "" ]] && exit 1
    # Clean title for filename (detox replaces spaces with underscores, but we want to preserve user's input)
    # Only sanitize special characters, keep spaces as spaces for the title tag
    TITLE_FOR_FILENAME=$(echo "${TITLE}" | detox --inline)
    # Keep original title (with spaces) for NOSTR publication, use sanitized version only for filename
    TITLE_FOR_PUBLICATION="$TITLE"
fi

# Extract or ask for year
if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
    YEAR=$(echo "$SCRAPED_METADATA" | jq -r '.year // empty' 2>/dev/null)
fi
YEAR=$(zenity --entry --width 300 --title "Année" --text "Indiquez année de la vidéo. Exemple: 1985" --entry-text="$YEAR")
        
# Extract genres from scraped data or ask user
GENRES=""
GENRES_ARRAY="[]"
GENRES_DEFAULT=""
if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
    # Try to get genres as array first (preferred format)
    GENRES_ARRAY=$(echo "$SCRAPED_METADATA" | jq -c '.genres // []' 2>/dev/null)
    if [[ -z "$GENRES_ARRAY" ]] || [[ "$GENRES_ARRAY" == "[]" ]]; then
        # Fallback: try to get as comma-separated string
        GENRES_DEFAULT=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
    else
        # Convert array to comma-separated string for display/confirmation
        GENRES_DEFAULT=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
    fi
fi

# Always ask user to confirm/edit genres (even if scraped)
[ ! $2 ] && GENRES=$(zenity --entry --width 400 --title "Genres" --text "Indiquez les genres (séparés par des virgules). Ex: Action, Science Fiction, Thriller" --entry-text="$GENRES_DEFAULT") || GENRES="$GENRES_DEFAULT"

# If user cancelled or left empty, use default if available
if [[ -z "$GENRES" ]] || [[ "$GENRES" == "" ]]; then
    if [[ -n "$GENRES_DEFAULT" ]] && [[ "$GENRES_DEFAULT" != "" ]]; then
        GENRES="$GENRES_DEFAULT"
        echo "📋 Using scraped genres: $GENRES"
    else
        echo "⚠️  No genres provided, skipping genre tags"
        GENRES=""
        GENRES_ARRAY="[]"
    fi
fi

# Convert genres string to array format for JSON
if [[ -n "$GENRES" ]] && [[ "$GENRES" != "" ]]; then
    GENRES_ARRAY=$(echo "$GENRES" | jq -R 'split(", ") | map(select(. != "")) | map(gsub("^\\s+|\\s+$"; ""))' 2>/dev/null || echo "[]")
    echo "📋 Genres confirmed: $GENRES"
fi

# For series: ask for season and episode numbers
SEASON_NUMBER=""
EPISODE_NUMBER=""
if [[ "$CAT" == "serie" ]]; then
    # Try to extract season/episode from filename if available (e.g., "S01E05" or "s1e5")
    if echo "$FILE_NAME" | grep -qiE 's[0-9]+e[0-9]+'; then
        SEASON_NUMBER=$(echo "$FILE_NAME" | grep -oiE 's([0-9]+)' | grep -oiE '[0-9]+' | head -1)
        EPISODE_NUMBER=$(echo "$FILE_NAME" | grep -oiE 'e([0-9]+)' | grep -oiE '[0-9]+' | head -1)
    fi
    
    # Ask user for season number
    [ ! $2 ] && SEASON_NUMBER=$(zenity --entry --width 300 --title "Numéro de saison" --text "Indiquez le numéro de saison (ex: 1, 2, 3...)" --entry-text="$SEASON_NUMBER")
    
    # Ask user for episode number
    [ ! $2 ] && EPISODE_NUMBER=$(zenity --entry --width 300 --title "Numéro d'épisode" --text "Indiquez le numéro d'épisode (ex: 1, 2, 3...)" --entry-text="$EPISODE_NUMBER")
    
    # Validate season and episode numbers
    if [[ -n "$SEASON_NUMBER" ]] && ! [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Invalid season number, ignoring: $SEASON_NUMBER"
        SEASON_NUMBER=""
    fi
    if [[ -n "$EPISODE_NUMBER" ]] && ! [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Invalid episode number, ignoring: $EPISODE_NUMBER"
        EPISODE_NUMBER=""
    fi
    
    # Update title to include season/episode if available
    if [[ -n "$SEASON_NUMBER" ]] && [[ -n "$EPISODE_NUMBER" ]]; then
        TITLE_WITH_EPISODE="${TITLE} - S${SEASON_NUMBER}E${EPISODE_NUMBER}"
        echo "📺 Episode: Season $SEASON_NUMBER, Episode $EPISODE_NUMBER"
        echo "📺 Episode title: $TITLE_WITH_EPISODE"
    elif [[ -n "$SEASON_NUMBER" ]]; then
        echo "📺 Season: $SEASON_NUMBER (episode number missing)"
    elif [[ -n "$EPISODE_NUMBER" ]]; then
        echo "📺 Episode: $EPISODE_NUMBER (season number missing)"
    fi
fi

# Extract or ask for description
if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
    SCRAPED_OVERVIEW=$(echo "$SCRAPED_METADATA" | jq -r '.overview // empty' 2>/dev/null)
    SCRAPED_TAGLINE=$(echo "$SCRAPED_METADATA" | jq -r '.tagline // empty' 2>/dev/null)
    if [[ -n "$SCRAPED_TAGLINE" ]]; then
        VIDEO_DESC="$SCRAPED_TAGLINE"
    fi
    if [[ -n "$SCRAPED_OVERVIEW" ]]; then
        if [[ -n "$VIDEO_DESC" ]]; then
            VIDEO_DESC="${VIDEO_DESC}  ${SCRAPED_OVERVIEW}"
        else
            VIDEO_DESC="$SCRAPED_OVERVIEW"
        fi
    fi
    
    # Extract additional metadata from scraped data for JSON and display
    SCRAPED_DIRECTOR=$(echo "$SCRAPED_METADATA" | jq -r '.director // empty' 2>/dev/null)
    SCRAPED_CREATOR=$(echo "$SCRAPED_METADATA" | jq -r '.creator // empty' 2>/dev/null)
    SCRAPED_RUNTIME=$(echo "$SCRAPED_METADATA" | jq -r '.runtime // empty' 2>/dev/null)
    SCRAPED_VOTE_AVG=$(echo "$SCRAPED_METADATA" | jq -r '.vote_average // empty' 2>/dev/null)
    SCRAPED_VOTE_COUNT=$(echo "$SCRAPED_METADATA" | jq -r '.vote_count // empty' 2>/dev/null)
    # Note: SCRAPED_TAGLINE already extracted above
fi
        
# Ask for description (user can edit scraped content)
[ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description de la vidéo (optionnel)" --entry-text="$VIDEO_DESC")

# Create TMDB metadata JSON file (merge scraped data with manual input)
        TMDB_METADATA_FILE="$HOME/.zen/tmp/tmdb_${MEDIAID}_$(date +%s).json"

# Build base JSON structure with genres array
if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
    # Merge scraped metadata with manual inputs
    # Preserve ALL scraped fields (director, creator, runtime, vote_average, vote_count, tagline,
    # network, status, certification, production_companies, countries, languages, number_of_seasons,
    # number_of_episodes, etc.) and override only with user inputs (title, year, genres, season/episode)
    # Use GENRES_ARRAY if available, otherwise parse from GENRES string
    if [[ "$GENRES_ARRAY" != "[]" ]] && [[ -n "$GENRES_ARRAY" ]]; then
        # Use existing array format - preserve all scraped metadata
        TMDB_METADATA_JSON=$(echo "$SCRAPED_METADATA" | jq --arg title "$TITLE" --arg year "$YEAR" --argjson genres_array "$GENRES_ARRAY" --arg tmdb_url "$TMDB_URL" --arg tmdb_id "$MEDIAID" --arg media_type "$MEDIA_TYPE" '
            .title = $title |
            .year = $year |
            .tmdb_id = ($tmdb_id | tonumber) |
            .media_type = $media_type |
            .tmdb_url = $tmdb_url |
            .genres = $genres_array
        ' 2>/dev/null)
    else
        # Parse genres from string - preserve all scraped metadata
        TMDB_METADATA_JSON=$(echo "$SCRAPED_METADATA" | jq --arg title "$TITLE" --arg year "$YEAR" --arg genres "$GENRES" --arg tmdb_url "$TMDB_URL" --arg tmdb_id "$MEDIAID" --arg media_type "$MEDIA_TYPE" '
            .title = $title |
            .year = $year |
            .tmdb_id = ($tmdb_id | tonumber) |
            .media_type = $media_type |
            .tmdb_url = $tmdb_url |
            (if $genres != "" then .genres = ($genres | split(", ") | map(select(. != "")) | map(gsub("^\\s+|\\s+$"; ""))) else . end)
        ' 2>/dev/null)
    fi
    
    # Add season and episode numbers for series
    if [[ "$CAT" == "serie" ]]; then
        # Add series name and episode name
        if [[ -n "$SERIES_NAME" ]]; then
            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg series_name "$SERIES_NAME" '.series_name = $series_name' 2>/dev/null || echo "$TMDB_METADATA_JSON")
        fi
        if [[ -n "$EPISODE_NAME" ]]; then
            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg episode_name "$EPISODE_NAME" '.episode_name = $episode_name' 2>/dev/null || echo "$TMDB_METADATA_JSON")
        fi
        if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson season "$SEASON_NUMBER" '.season_number = ($season | tonumber)' 2>/dev/null || echo "$TMDB_METADATA_JSON")
        fi
        if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson episode "$EPISODE_NUMBER" '.episode_number = ($episode | tonumber)' 2>/dev/null || echo "$TMDB_METADATA_JSON")
        fi
    fi
    
    if [[ -z "$TMDB_METADATA_JSON" ]] || ! echo "$TMDB_METADATA_JSON" | jq -e '.' >/dev/null 2>&1; then
        # Fallback to basic structure - preserve all scraped metadata
        TMDB_METADATA_JSON=$(echo "$SCRAPED_METADATA" | jq --arg title "$TITLE" --arg year "$YEAR" --argjson genres_array "$GENRES_ARRAY" --arg tmdb_url "$TMDB_URL" --arg tmdb_id "$MEDIAID" --arg media_type "$MEDIA_TYPE" '
            .title = $title |
            .year = $year |
            .tmdb_id = ($tmdb_id | tonumber) |
            .media_type = $media_type |
            .tmdb_url = $tmdb_url |
            .genres = $genres_array
        ' 2>/dev/null)
        
        # If jq merge failed, use basic structure
        if [[ -z "$TMDB_METADATA_JSON" ]] || ! echo "$TMDB_METADATA_JSON" | jq -e '.' >/dev/null 2>&1; then
            TMDB_METADATA_JSON=$(cat << EOF
{
  "tmdb_id": $MEDIAID,
  "media_type": "$MEDIA_TYPE",
  "title": "$TITLE",
  "year": "$YEAR",
  "tmdb_url": "$TMDB_URL",
  "genres": $GENRES_ARRAY
EOF
            )
            # Add additional fields from scraped data if available
            if [[ -n "$SCRAPED_DIRECTOR" ]] && [[ "$SCRAPED_DIRECTOR" != "" ]]; then
                TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"director\": \"$SCRAPED_DIRECTOR\""
            fi
            if [[ -n "$SCRAPED_CREATOR" ]] && [[ "$SCRAPED_CREATOR" != "" ]]; then
                TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"creator\": \"$SCRAPED_CREATOR\""
            fi
            if [[ -n "$SCRAPED_RUNTIME" ]] && [[ "$SCRAPED_RUNTIME" != "" ]]; then
                TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"runtime\": \"$SCRAPED_RUNTIME\""
            fi
            if [[ -n "$SCRAPED_VOTE_AVG" ]] && [[ "$SCRAPED_VOTE_AVG" != "" ]]; then
                TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"vote_average\": \"$SCRAPED_VOTE_AVG\""
            fi
            if [[ -n "$SCRAPED_TAGLINE" ]] && [[ "$SCRAPED_TAGLINE" != "" ]]; then
                TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"tagline\": \"$SCRAPED_TAGLINE\""
            fi
            if [[ -n "$SCRAPED_VOTE_COUNT" ]] && [[ "$SCRAPED_VOTE_COUNT" != "" ]]; then
                TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"vote_count\": \"$SCRAPED_VOTE_COUNT\""
            fi
            # Add season/episode for series
            if [[ "$CAT" == "serie" ]]; then
                if [[ -n "$SERIES_NAME" ]]; then
                    TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"series_name\": \"$SERIES_NAME\""
                fi
                if [[ -n "$EPISODE_NAME" ]]; then
                    TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"episode_name\": \"$EPISODE_NAME\""
                fi
                if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
                    TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"season_number\": $SEASON_NUMBER"
                fi
                if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
                    TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"episode_number\": $EPISODE_NUMBER"
                fi
            fi
            TMDB_METADATA_JSON="${TMDB_METADATA_JSON}
}"
        else
            # Add season/episode if not already in merged JSON
            if [[ "$CAT" == "serie" ]]; then
                if [[ -n "$SERIES_NAME" ]]; then
                    TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg series_name "$SERIES_NAME" '.series_name = $series_name' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                fi
                if [[ -n "$EPISODE_NAME" ]]; then
                    TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg episode_name "$EPISODE_NAME" '.episode_name = $episode_name' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                fi
                if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
                    TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson season "$SEASON_NUMBER" '.season_number = ($season | tonumber)' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                fi
                if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
                    TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson episode "$EPISODE_NUMBER" '.episode_number = ($episode | tonumber)' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                fi
            fi
        fi
    fi
else
    # Basic structure without scraping
    TMDB_METADATA_JSON=$(cat << EOF
{
  "tmdb_id": $MEDIAID,
  "media_type": "$MEDIA_TYPE",
  "title": "$TITLE",
  "year": "$YEAR",
  "tmdb_url": "$TMDB_URL",
  "genres": $GENRES_ARRAY
EOF
    )
    # Add season/episode for series
    if [[ "$CAT" == "serie" ]]; then
        if [[ -n "$SERIES_NAME" ]]; then
            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"series_name\": \"$SERIES_NAME\""
        fi
        if [[ -n "$EPISODE_NAME" ]]; then
            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"episode_name\": \"$EPISODE_NAME\""
        fi
        if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"season_number\": $SEASON_NUMBER"
        fi
        if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"episode_number\": $EPISODE_NUMBER"
        fi
    fi
    TMDB_METADATA_JSON="${TMDB_METADATA_JSON}
}"
fi

        echo "$TMDB_METADATA_JSON" > "$TMDB_METADATA_FILE"
        echo "✅ Created TMDB metadata file: $TMDB_METADATA_FILE"
        
        # Debug: verify genres are in the metadata file
        if command -v jq &> /dev/null; then
            GENRES_IN_FILE=$(echo "$TMDB_METADATA_JSON" | jq -c '.genres // []' 2>/dev/null)
            echo "🔍 Debug: Genres in TMDB_METADATA_FILE: $GENRES_IN_FILE"
        fi
        
        # Extract additional metadata for display (if scraped)
        if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
            SCRAPED_NETWORK=$(echo "$SCRAPED_METADATA" | jq -r '.network // empty' 2>/dev/null)
            SCRAPED_STATUS=$(echo "$SCRAPED_METADATA" | jq -r '.status // empty' 2>/dev/null)
            SCRAPED_CERTIFICATION=$(echo "$SCRAPED_METADATA" | jq -r '.certification // empty' 2>/dev/null)
            SCRAPED_PRODUCTION=$(echo "$SCRAPED_METADATA" | jq -r '.production_companies // [] | join(", ")' 2>/dev/null)
            SCRAPED_COUNTRIES=$(echo "$SCRAPED_METADATA" | jq -r '.countries // [] | join(", ")' 2>/dev/null)
            SCRAPED_LANGUAGES=$(echo "$SCRAPED_METADATA" | jq -r '.languages // [] | join(", ")' 2>/dev/null)
            SCRAPED_NUM_SEASONS=$(echo "$SCRAPED_METADATA" | jq -r '.number_of_seasons // empty' 2>/dev/null)
            SCRAPED_NUM_EPISODES=$(echo "$SCRAPED_METADATA" | jq -r '.number_of_episodes // empty' 2>/dev/null)
        fi
        
        # Display summary of metadata
        echo ""
        echo "📋 Metadata Summary:"
        echo "   Title: $TITLE"
        echo "   Year: $YEAR"
        echo "   TMDB ID: $MEDIAID"
        echo "   Media Type: $MEDIA_TYPE"
        if [[ -n "$GENRES" ]] && [[ "$GENRES" != "" ]]; then
            echo "   Genres: $GENRES"
        fi
        if [[ -n "$SCRAPED_DIRECTOR" ]] && [[ "$SCRAPED_DIRECTOR" != "" ]]; then
            echo "   Director: $SCRAPED_DIRECTOR"
        fi
        if [[ -n "$SCRAPED_CREATOR" ]] && [[ "$SCRAPED_CREATOR" != "" ]]; then
            echo "   Creator: $SCRAPED_CREATOR"
        fi
        if [[ -n "$SCRAPED_RUNTIME" ]] && [[ "$SCRAPED_RUNTIME" != "" ]]; then
            echo "   Runtime: $SCRAPED_RUNTIME"
        fi
        if [[ -n "$SCRAPED_VOTE_AVG" ]] && [[ "$SCRAPED_VOTE_AVG" != "" ]]; then
            echo "   Rating: $SCRAPED_VOTE_AVG"
            if [[ -n "$SCRAPED_VOTE_COUNT" ]] && [[ "$SCRAPED_VOTE_COUNT" != "" ]]; then
                echo "   Votes: $SCRAPED_VOTE_COUNT"
            fi
        fi
        if [[ -n "$SCRAPED_CERTIFICATION" ]] && [[ "$SCRAPED_CERTIFICATION" != "" ]]; then
            echo "   Certification: $SCRAPED_CERTIFICATION"
        fi
        if [[ "$CAT" == "serie" ]]; then
            if [[ -n "$SEASON_NUMBER" ]] && [[ -n "$EPISODE_NUMBER" ]]; then
                echo "   Season: $SEASON_NUMBER, Episode: $EPISODE_NUMBER"
            fi
            if [[ -n "$SCRAPED_NETWORK" ]] && [[ "$SCRAPED_NETWORK" != "" ]]; then
                echo "   Network: $SCRAPED_NETWORK"
            fi
            if [[ -n "$SCRAPED_STATUS" ]] && [[ "$SCRAPED_STATUS" != "" ]]; then
                echo "   Status: $SCRAPED_STATUS"
            fi
            if [[ -n "$SCRAPED_NUM_SEASONS" ]] && [[ "$SCRAPED_NUM_SEASONS" != "" ]]; then
                echo "   Total Seasons: $SCRAPED_NUM_SEASONS"
            fi
            if [[ -n "$SCRAPED_NUM_EPISODES" ]] && [[ "$SCRAPED_NUM_EPISODES" != "" ]]; then
                echo "   Total Episodes: $SCRAPED_NUM_EPISODES"
            fi
        fi
        if [[ -n "$SCRAPED_PRODUCTION" ]] && [[ "$SCRAPED_PRODUCTION" != "" ]] && [[ "$SCRAPED_PRODUCTION" != "[]" ]]; then
            echo "   Production: $SCRAPED_PRODUCTION"
        fi
        if [[ -n "$SCRAPED_COUNTRIES" ]] && [[ "$SCRAPED_COUNTRIES" != "" ]] && [[ "$SCRAPED_COUNTRIES" != "[]" ]]; then
            echo "   Countries: $SCRAPED_COUNTRIES"
        fi
        if [[ -n "$SCRAPED_LANGUAGES" ]] && [[ "$SCRAPED_LANGUAGES" != "" ]] && [[ "$SCRAPED_LANGUAGES" != "[]" ]]; then
            echo "   Languages: $SCRAPED_LANGUAGES"
        fi
        echo ""
        
        # CONVERT INPUT TO MP4 if needed
        if [[ $FILE_EXT != "mp4" ]]; then
            espeak "Converting to M P 4. Please wait"
            FINAL_FILE="$HOME/.zen/tmp/${TITLE}.mp4"
            ffmpeg -loglevel quiet -i "${FILE}" -c:v libx264 -c:a aac "$FINAL_FILE"
            FILE_EXT="mp4"
            FILE_NAME="${TITLE}.mp4"
            espeak "M P 4 ready"
        else
            FINAL_FILE="$HOME/.zen/tmp/${TITLE}.${FILE_EXT}"
            cp "${FILE}" "$FINAL_FILE"
        fi
        
        # Upload via upload2ipfs.sh directly (no API, no NIP-42 required)
        echo "📤 Uploading video via upload2ipfs.sh..."
        
        # Create temp output file for upload2ipfs.sh JSON response
        UPLOAD_OUTPUT_FILE="$HOME/.zen/tmp/upload_$(date +%s).json"
        
        # Get upload2ipfs.sh path
        UPLOAD_SCRIPT="${MY_PATH}/../UPassport/upload2ipfs.sh"
        if [[ ! -f "$UPLOAD_SCRIPT" ]]; then
            UPLOAD_SCRIPT="${HOME}/.zen/UPassport/upload2ipfs.sh"
        fi

        if [[ ! -f "$UPLOAD_SCRIPT" ]]; then
            echo "❌ ERROR: upload2ipfs.sh not found"
            espeak "Upload script not found"
            rm -f "$TMDB_METADATA_FILE"
            exit 1
        fi
        
        # Call upload2ipfs.sh with metadata file
        if [[ -n "$NPUB_HEX" ]]; then
            echo "📤 Using upload2ipfs.sh with provenance tracking (hex: ${NPUB_HEX:0:16}...)"
            bash "$UPLOAD_SCRIPT" --metadata "$TMDB_METADATA_FILE" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" "$NPUB_HEX" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
        else
            echo "📤 Using upload2ipfs.sh without provenance tracking"
            bash "$UPLOAD_SCRIPT" --metadata "$TMDB_METADATA_FILE" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
        fi
        
        UPLOAD_EXIT_CODE=$?
        
        if [[ $UPLOAD_EXIT_CODE -ne 0 ]] || [[ ! -f "$UPLOAD_OUTPUT_FILE" ]]; then
            echo "❌ ERROR: upload2ipfs.sh failed (exit code: $UPLOAD_EXIT_CODE)"
            echo "Log output:"
            cat "$HOME/.zen/tmp/upload2ipfs.log" 2>/dev/null || echo "(no log)"
            espeak "Upload failed"
            rm -f "$TMDB_METADATA_FILE" "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Read upload result JSON
        if ! command -v jq &> /dev/null; then
            echo "❌ ERROR: jq is required but not found"
            espeak "jq required"
            rm -f "$TMDB_METADATA_FILE" "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Validate JSON
        if ! jq -e '.' "$UPLOAD_OUTPUT_FILE" >/dev/null 2>&1; then
            echo "❌ ERROR: Invalid JSON from upload2ipfs.sh"
            echo "Output:"
            cat "$UPLOAD_OUTPUT_FILE"
            espeak "Invalid JSON"
            rm -f "$TMDB_METADATA_FILE" "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Extract values from upload result
        IPFS_CID=$(jq -r '.cid // empty' "$UPLOAD_OUTPUT_FILE")
        INFO_CID=$(jq -r '.info // empty' "$UPLOAD_OUTPUT_FILE")
        THUMBNAIL_CID=$(jq -r '.thumbnail_ipfs // empty' "$UPLOAD_OUTPUT_FILE")
        GIFANIM_CID=$(jq -r '.gifanim_ipfs // empty' "$UPLOAD_OUTPUT_FILE")
        FILE_HASH=$(jq -r '.fileHash // empty' "$UPLOAD_OUTPUT_FILE")
        DIMENSIONS=$(jq -r '.dimensions // empty' "$UPLOAD_OUTPUT_FILE")
        UPLOAD_CHAIN=$(jq -r '.upload_chain // empty' "$UPLOAD_OUTPUT_FILE")
        DURATION=$(jq -r '.duration // 0' "$UPLOAD_OUTPUT_FILE")
        MIME_TYPE=$(jq -r '.mimeType // "video/mp4"' "$UPLOAD_OUTPUT_FILE")
        FILENAME_FROM_UPLOAD=$(jq -r '.fileName // empty' "$UPLOAD_OUTPUT_FILE")
        
        if [[ -z "$IPFS_CID" ]]; then
            echo "❌ ERROR: Failed to get IPFS CID from upload result"
            espeak "IPFS upload failed"
            rm -f "$TMDB_METADATA_FILE" "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        echo "✅ Video uploaded to IPFS and copied to uDRIVE!"
        echo "   CID: $IPFS_CID"
        
        # Build description with TMDB metadata
        if [[ -n "$TMDB_METADATA_FILE" ]] && command -v jq &> /dev/null; then
            TMDB_URL=$(jq -r '.tmdb_url // empty' "$TMDB_METADATA_FILE" 2>/dev/null)
            if [[ -n "$TMDB_URL" ]]; then
                if [[ -n "$VIDEO_DESC" ]]; then
                    VIDEO_DESC="${VIDEO_DESC}  TMDB: ${TMDB_URL}"
                else
                    VIDEO_DESC="TMDB: ${TMDB_URL}"
                fi
            fi
        fi
        
        # Publish via publish_nostr_video.sh directly (no API, no NIP-42 required)
        echo "📹 Publishing video via publish_nostr_video.sh..."
        
        # Get publish script path
        PUBLISH_SCRIPT="${MY_PATH}/tools/publish_nostr_video.sh"
        if [[ ! -f "$PUBLISH_SCRIPT" ]]; then
            PUBLISH_SCRIPT="${HOME}/.zen/Astroport.ONE/tools/publish_nostr_video.sh"
        fi
        
        if [[ ! -f "$PUBLISH_SCRIPT" ]]; then
            echo "❌ ERROR: publish_nostr_video.sh not found"
            espeak "Publish script not found"
            rm -f "$TMDB_METADATA_FILE" "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Get secret file path
        SECRET_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
        if [[ ! -f "$SECRET_FILE" ]]; then
            echo "❌ ERROR: Secret file not found: $SECRET_FILE"
            espeak "Secret file not found"
            rm -f "$TMDB_METADATA_FILE" "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Build publish command using --auto mode (reads from upload2ipfs.sh output)
        # Use episode title for series if available, otherwise use regular title
        # Use TITLE_FOR_PUBLICATION (with spaces, no underscores) for NOSTR publication
        PUBLISH_TITLE="${TITLE_FOR_PUBLICATION:-$TITLE}"
        if [[ "$CAT" == "serie" ]] && [[ -n "$TITLE_WITH_EPISODE" ]]; then
            # Clean episode title too
            PUBLISH_TITLE=$(echo "$TITLE_WITH_EPISODE" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
            echo "📺 Using episode title: $PUBLISH_TITLE"
        fi
        PUBLISH_CMD=("$PUBLISH_SCRIPT" "--auto" "$UPLOAD_OUTPUT_FILE" "--nsec" "$SECRET_FILE" "--title" "$PUBLISH_TITLE")
        
        if [[ -n "$VIDEO_DESC" ]]; then
            PUBLISH_CMD+=("--description" "$VIDEO_DESC")
        fi
        
        # Add source type based on category (film or serie)
        if [[ "$CAT" == "film" ]]; then
            PUBLISH_CMD+=("--source-type" "film")
            echo "📽️ Source type: film"
        elif [[ "$CAT" == "serie" ]]; then
            PUBLISH_CMD+=("--source-type" "serie")
            echo "📺 Source type: serie"
            
            # Add series metadata tags
            if [[ -n "$SERIES_NAME" ]]; then
                PUBLISH_CMD+=("--series-name" "$SERIES_NAME")
                echo "📺 Series name: $SERIES_NAME"
            fi
            if [[ -n "$EPISODE_NAME_FOR_PUBLICATION" ]]; then
                PUBLISH_CMD+=("--episode-name" "$EPISODE_NAME_FOR_PUBLICATION")
                echo "📺 Episode name: $EPISODE_NAME_FOR_PUBLICATION"
            elif [[ -n "$EPISODE_NAME" ]]; then
                PUBLISH_CMD+=("--episode-name" "$EPISODE_NAME")
                echo "📺 Episode name: $EPISODE_NAME"
            fi
            if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
                PUBLISH_CMD+=("--season-number" "$SEASON_NUMBER")
                echo "📺 Season number: $SEASON_NUMBER"
            fi
            if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
                PUBLISH_CMD+=("--episode-number" "$EPISODE_NUMBER")
                echo "📺 Episode number: $EPISODE_NUMBER"
            fi
        fi
        
        # Add genres for tag publication (kind 1985)
        if [[ -n "$GENRES_ARRAY" ]] && [[ "$GENRES_ARRAY" != "[]" ]] && [[ "$GENRES_ARRAY" != "null" ]]; then
            # Validate JSON array format and clean it (remove newlines, extra spaces)
            GENRES_ARRAY_CLEAN=$(echo "$GENRES_ARRAY" | jq -c '.' 2>/dev/null | tr -d '\n\r')
            
            if [[ -n "$GENRES_ARRAY_CLEAN" ]] && echo "$GENRES_ARRAY_CLEAN" | jq -e '.' >/dev/null 2>&1; then
                PUBLISH_CMD+=("--genres" "$GENRES_ARRAY_CLEAN")
                echo "🏷️  Genres for tagging (kind 1985): $GENRES_ARRAY_CLEAN"
                echo "🔍 Debug: GENRES_ARRAY_CLEAN length: ${#GENRES_ARRAY_CLEAN}, format: $(echo "$GENRES_ARRAY_CLEAN" | jq -c '.' 2>/dev/null || echo "invalid")"
            else
                echo "⚠️  WARNING: Invalid JSON format for genres, skipping genre tags"
                echo "   GENRES_ARRAY (original): $GENRES_ARRAY"
                echo "   GENRES_ARRAY_CLEAN: $GENRES_ARRAY_CLEAN"
            fi
        else
            echo "⚠️  No genres provided, skipping kind 1985 tag events"
            echo "🔍 Debug: GENRES_ARRAY='$GENRES_ARRAY' (empty check: $([ -z "$GENRES_ARRAY" ] && echo "empty" || echo "not empty"))"
        fi
        
        # Add dimensions and duration explicitly to ensure correct values (film/serie)
        if [[ -n "$DIMENSIONS" ]] && [[ "$DIMENSIONS" != "empty" ]] && [[ "$DIMENSIONS" != "" ]] && [[ "$DIMENSIONS" != "640x480" ]]; then
            PUBLISH_CMD+=("--dimensions" "$DIMENSIONS")
            echo "📐 Dimensions: $DIMENSIONS"
        fi
        
        if [[ -n "$DURATION" ]] && [[ "$DURATION" != "0" ]] && [[ "$DURATION" != "empty" ]] && [[ "$DURATION" != "" ]]; then
            PUBLISH_CMD+=("--duration" "$DURATION")
            echo "⏱️  Duration: ${DURATION}s"
        fi
        
        PUBLISH_CMD+=("--channel" "$PLAYER" "--json")
        
        # Execute publish script
        PUBLISH_OUTPUT=$(bash "${PUBLISH_CMD[@]}" 2>&1)
        PUBLISH_EXIT_CODE=$?
        
        if [[ $PUBLISH_EXIT_CODE -eq 0 ]]; then
            # Try to extract event ID from output
            EVENT_ID=$(echo "$PUBLISH_OUTPUT" | jq -r '.event_id // empty' 2>/dev/null || echo "")
            if [[ -n "$EVENT_ID" ]]; then
                echo "✅ Video published successfully to NOSTR!"
                echo "   Event ID: ${EVENT_ID:0:16}..."
            espeak "Video published"
        else
                # Try regex extraction
                EVENT_ID=$(echo "$PUBLISH_OUTPUT" | grep -oE '"event_id"\s*:\s*"[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}' | head -1)
                if [[ -n "$EVENT_ID" ]]; then
                    echo "✅ Video published successfully to NOSTR!"
                    echo "   Event ID: ${EVENT_ID:0:16}..."
                    espeak "Video published"
                else
                    echo "⚠️  Video uploaded but event ID not found in output"
                    echo "Publish output: $PUBLISH_OUTPUT"
                fi
            fi
        else
            echo "⚠️  Video uploaded but publication may have failed (exit code: $PUBLISH_EXIT_CODE)"
            echo "Publish output: $PUBLISH_OUTPUT"
        fi
        
        # Cleanup metadata and temp files
        rm -f "$TMDB_METADATA_FILE" "$UPLOAD_OUTPUT_FILE"
    ;;

########################################################################
# CASE ## VIDEO (personal video)
########################################################################
    video)
        espeak "Add your personal video"
        
        # SELECT FILE TO ADD
    FILE=$(zenity --file-selection --title="Sélectionner votre vidéo")
    echo "${FILE}"
    [[ $FILE == "" ]] && exit 1

    # Remove file extension to get file name => STITLE
    FILE_PATH="$(dirname "${FILE}")"
    FILE_NAME="$(basename "${FILE}")"
    FILE_EXT="${FILE_NAME##*.}"
    FILE_TITLE="${FILE_NAME%.*}"

    # Ask if user wants to enrich with TMDB metadata (film or serie)
    TMDB_ENRICHMENT="Aucun"
    [ ! $2 ] && TMDB_ENRICHMENT=$(zenity --list --width 400 --height 200 --title="Enrichissement TMDB" \
        --text="Voulez-vous enrichir cette vidéo avec des métadonnées TMDB ?" \
        --column="Option" "Aucun" "Film" "Serie" 2>/dev/null || echo "Aucun")
    [[ $TMDB_ENRICHMENT == "" ]] && TMDB_ENRICHMENT="Aucun"
    
    # Determine media type for TMDB
    if [[ "$TMDB_ENRICHMENT" == "Film" ]]; then
        MEDIA_TYPE="movie"
        CAT_FOR_TMDB="film"
    elif [[ "$TMDB_ENRICHMENT" == "Serie" ]]; then
        MEDIA_TYPE="tv"
        CAT_FOR_TMDB="serie"
    else
        MEDIA_TYPE=""
        CAT_FOR_TMDB=""
    fi
    
    # If TMDB enrichment requested, follow similar flow as film/serie
    TMDB_METADATA_FILE=""
    if [[ "$TMDB_ENRICHMENT" != "Aucun" ]] && [[ -n "$MEDIA_TYPE" ]]; then
        echo "🎬 TMDB enrichment requested: $TMDB_ENRICHMENT"
        
        # OPEN default browser and search TMDB
        zenity --question --width 300 --text "Ouvrir https://www.themoviedb.org pour récupérer le numéro d'identification de $(echo ${FILE_TITLE} | sed 's/_/%20/g') ?"
        [ $? == 0 ] && xdg-open "https://www.themoviedb.org/search?query=$(echo ${FILE_TITLE} | sed 's/_/%20/g')"
        
        # Get TMDB URL or ID from user
        TMDB_URL_INPUT=$(zenity --entry --title="Identification TMDB" --text="Copiez l'URL complète ou le nom de la page du ${TMDB_ENRICHMENT}.\nEx: https://www.themoviedb.org/${MEDIA_TYPE}/301528-toy-story-4\nou: 301528-toy-story-4" --entry-text="")
        
        if [[ -n "$TMDB_URL_INPUT" ]]; then
            # Extract MEDIAID and build full URL
            if [[ "$TMDB_URL_INPUT" =~ ^https?:// ]]; then
                TMDB_URL="$TMDB_URL_INPUT"
                MEDIAID=$(echo "$TMDB_URL_INPUT" | rev | cut -d '/' -f 1 | rev)
            else
                MEDIAID="$TMDB_URL_INPUT"
                if [[ "$MEDIA_TYPE" == "tv" ]]; then
                    TMDB_URL="https://www.themoviedb.org/tv/$MEDIAID"
                else
                    TMDB_URL="https://www.themoviedb.org/movie/$MEDIAID"
                fi
            fi
            
            # Extract numeric ID from slug
            MEDIAID=$(echo $MEDIAID | rev | cut -d '/' -f 1 | rev)
            CMED=$(echo $MEDIAID | cut -d '-' -f 1)
            
            if [[ "$CMED" =~ ^[0-9]+$ ]]; then
                MEDIAID=$CMED
                
                # Ask if user wants to scrape TMDB page for metadata
                SCRAPE_TMDB="no"
                SCRAPED_METADATA=""
                if zenity --question --width 400 --title="Scraper TMDB ?" --text="Voulez-vous scraper la page TMDB pour enrichir automatiquement les métadonnées ?  URL: $TMDB_URL"; then
                    SCRAPE_TMDB="yes"
                    echo "🔍 Scraping TMDB page: $TMDB_URL"
                    
                    # Get scraper script path
                    SCRAPER_SCRIPT="${MY_PATH}/IA/scraper.TMDB.py"
                    if [[ ! -f "$SCRAPER_SCRIPT" ]]; then
                        SCRAPER_SCRIPT="${HOME}/.zen/Astroport.ONE/IA/scraper.TMDB.py"
                    fi
                    if [[ ! -f "$SCRAPER_SCRIPT" ]]; then
                        SCRAPER_SCRIPT="${HOME}/workspace/AAA/Astroport.ONE/IA/scraper.TMDB.py"
                    fi
                    
                    if [[ -f "$SCRAPER_SCRIPT" ]]; then
                        SCRAPED_METADATA=$(python3 "$SCRAPER_SCRIPT" "$TMDB_URL" 2>/dev/null)
                        if [[ -n "$SCRAPED_METADATA" ]] && echo "$SCRAPED_METADATA" | jq -e '.' >/dev/null 2>&1; then
                            echo "✅ TMDB metadata scraped successfully"
                            SCRAPED_GENRES=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
                            if [[ -n "$SCRAPED_GENRES" ]] && [[ "$SCRAPED_GENRES" != "" ]]; then
                                echo "   📋 Genres found: $SCRAPED_GENRES"
                            fi
                        else
                            echo "⚠️  Failed to scrape TMDB metadata, using manual input"
                            SCRAPED_METADATA=""
                        fi
                    else
                        echo "⚠️  Scraper script not found, using manual input"
                        SCRAPE_TMDB="no"
                    fi
                fi
                
                # Extract or ask for title
                SERIES_NAME=""
                EPISODE_NAME=""
                if [[ "$CAT_FOR_TMDB" == "serie" ]]; then
                    if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
                        SERIES_NAME=$(echo "$SCRAPED_METADATA" | jq -r '.title // .name // empty' 2>/dev/null)
                    fi
                    if [[ -z "$SERIES_NAME" ]]; then
                        [ ! $2 ] && SERIES_NAME=$(zenity --entry --width 400 --title "Nom de la série" --text "Indiquez le nom de la série" --entry-text="$FILE_TITLE")
                        [[ -z "$SERIES_NAME" ]] && SERIES_NAME="$FILE_TITLE"
                    fi
                    SERIES_NAME=$(echo "${SERIES_NAME}" | detox --inline)
                    
                    EPISODE_NAME_DEFAULT="$FILE_TITLE"
                    if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
                        EPISODE_TITLE_FROM_META=$(echo "$SCRAPED_METADATA" | jq -r '.episode_title // .episode_name // empty' 2>/dev/null)
                        [[ -n "$EPISODE_TITLE_FROM_META" ]] && EPISODE_NAME_DEFAULT="$EPISODE_TITLE_FROM_META"
                    fi
                    EPISODE_NAME_CLEAN=$(echo "$EPISODE_NAME_DEFAULT" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
                    [ ! $2 ] && EPISODE_NAME=$(zenity --entry --width 400 --title "Titre de l'épisode" --text "Indiquez le titre de l'épisode" --entry-text="$EPISODE_NAME_CLEAN") || EPISODE_NAME="$EPISODE_NAME_CLEAN"
                    [[ -z "$EPISODE_NAME" ]] && EPISODE_NAME="$EPISODE_NAME_CLEAN"
                    EPISODE_NAME_FOR_FILENAME=$(echo "${EPISODE_NAME}" | detox --inline)
                    EPISODE_NAME_FOR_PUBLICATION="$EPISODE_NAME"
                    TITLE="$EPISODE_NAME_FOR_FILENAME"
                    TITLE_FOR_PUBLICATION="$EPISODE_NAME_FOR_PUBLICATION"
                else
                    if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
                        TITLE=$(echo "$SCRAPED_METADATA" | jq -r '.title // empty' 2>/dev/null)
                        if [[ -z "$TITLE" ]]; then
                            TITLE="$FILE_TITLE"
                        fi
                    else
                        TITLE="$FILE_TITLE"
                    fi
                    TITLE_CLEAN_FOR_DISPLAY=$(echo "$TITLE" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
                    [ ! $2 ] && TITLE=$(zenity --entry --width 300 --title "Titre" --text "Indiquez le titre de la vidéo" --entry-text="$TITLE_CLEAN_FOR_DISPLAY") || TITLE="$TITLE_CLEAN_FOR_DISPLAY"
                    [[ $TITLE == "" ]] && exit 1
                    TITLE_FOR_FILENAME=$(echo "${TITLE}" | detox --inline)
                    TITLE_FOR_PUBLICATION="$TITLE"
                fi
                
                # Extract or ask for year
                YEAR=""
                if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
                    YEAR=$(echo "$SCRAPED_METADATA" | jq -r '.year // empty' 2>/dev/null)
                fi
                [ ! $2 ] && YEAR=$(zenity --entry --width 300 --title "Année" --text "Indiquez année de la vidéo. Exemple: 1985" --entry-text="$YEAR")
                
                # Extract genres from scraped data or ask user
                GENRES=""
                GENRES_ARRAY="[]"
                GENRES_DEFAULT=""
                if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
                    GENRES_ARRAY=$(echo "$SCRAPED_METADATA" | jq -c '.genres // []' 2>/dev/null)
                    if [[ -z "$GENRES_ARRAY" ]] || [[ "$GENRES_ARRAY" == "[]" ]]; then
                        GENRES_DEFAULT=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
                    else
                        GENRES_DEFAULT=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
                    fi
                fi
                
                [ ! $2 ] && GENRES=$(zenity --entry --width 400 --title "Genres" --text "Indiquez les genres (séparés par des virgules). Ex: Action, Science Fiction, Thriller" --entry-text="$GENRES_DEFAULT") || GENRES="$GENRES_DEFAULT"
                
                if [[ -z "$GENRES" ]] || [[ "$GENRES" == "" ]]; then
                    if [[ -n "$GENRES_DEFAULT" ]] && [[ "$GENRES_DEFAULT" != "" ]]; then
                        GENRES="$GENRES_DEFAULT"
                        echo "📋 Using scraped genres: $GENRES"
                    else
                        GENRES=""
                        GENRES_ARRAY="[]"
                    fi
                fi
                
                if [[ -n "$GENRES" ]] && [[ "$GENRES" != "" ]]; then
                    GENRES_ARRAY=$(echo "$GENRES" | jq -R 'split(", ") | map(select(. != "")) | map(gsub("^\\s+|\\s+$"; ""))' 2>/dev/null || echo "[]")
                fi
                
                # For series: ask for season and episode numbers
                SEASON_NUMBER=""
                EPISODE_NUMBER=""
                if [[ "$CAT_FOR_TMDB" == "serie" ]]; then
                    if echo "$FILE_NAME" | grep -qiE 's[0-9]+e[0-9]+'; then
                        SEASON_NUMBER=$(echo "$FILE_NAME" | grep -oiE 's([0-9]+)' | grep -oiE '[0-9]+' | head -1)
                        EPISODE_NUMBER=$(echo "$FILE_NAME" | grep -oiE 'e([0-9]+)' | grep -oiE '[0-9]+' | head -1)
                    fi
                    [ ! $2 ] && SEASON_NUMBER=$(zenity --entry --width 300 --title "Numéro de saison" --text "Indiquez le numéro de saison (ex: 1, 2, 3...)" --entry-text="$SEASON_NUMBER")
                    [ ! $2 ] && EPISODE_NUMBER=$(zenity --entry --width 300 --title "Numéro d'épisode" --text "Indiquez le numéro d'épisode (ex: 1, 2, 3...)" --entry-text="$EPISODE_NUMBER")
                    
                    if [[ -n "$SEASON_NUMBER" ]] && ! [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
                        SEASON_NUMBER=""
                    fi
                    if [[ -n "$EPISODE_NUMBER" ]] && ! [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
                        EPISODE_NUMBER=""
                    fi
                fi
                
                # Extract or ask for description
                VIDEO_DESC=""
                if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
                    SCRAPED_OVERVIEW=$(echo "$SCRAPED_METADATA" | jq -r '.overview // empty' 2>/dev/null)
                    SCRAPED_TAGLINE=$(echo "$SCRAPED_METADATA" | jq -r '.tagline // empty' 2>/dev/null)
                    if [[ -n "$SCRAPED_TAGLINE" ]]; then
                        VIDEO_DESC="$SCRAPED_TAGLINE"
                    fi
                    if [[ -n "$SCRAPED_OVERVIEW" ]]; then
                        if [[ -n "$VIDEO_DESC" ]]; then
                            VIDEO_DESC="${VIDEO_DESC}  ${SCRAPED_OVERVIEW}"
                        else
                            VIDEO_DESC="$SCRAPED_OVERVIEW"
                        fi
                    fi
                fi
                
                [ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description de la vidéo (optionnel)" --entry-text="$VIDEO_DESC")
                
                # Create TMDB metadata JSON file (similar to film/serie case)
                TMDB_METADATA_FILE="$HOME/.zen/tmp/tmdb_${MEDIAID}_$(date +%s).json"
                
                if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
                    if [[ "$GENRES_ARRAY" != "[]" ]] && [[ -n "$GENRES_ARRAY" ]]; then
                        TMDB_METADATA_JSON=$(echo "$SCRAPED_METADATA" | jq --arg title "$TITLE" --arg year "$YEAR" --argjson genres_array "$GENRES_ARRAY" --arg tmdb_url "$TMDB_URL" --arg tmdb_id "$MEDIAID" --arg media_type "$MEDIA_TYPE" '
                            .title = $title |
                            .year = $year |
                            .tmdb_id = ($tmdb_id | tonumber) |
                            .media_type = $media_type |
                            .tmdb_url = $tmdb_url |
                            .genres = $genres_array
                        ' 2>/dev/null)
                    else
                        TMDB_METADATA_JSON=$(echo "$SCRAPED_METADATA" | jq --arg title "$TITLE" --arg year "$YEAR" --arg genres "$GENRES" --arg tmdb_url "$TMDB_URL" --arg tmdb_id "$MEDIAID" --arg media_type "$MEDIA_TYPE" '
                            .title = $title |
                            .year = $year |
                            .tmdb_id = ($tmdb_id | tonumber) |
                            .media_type = $media_type |
                            .tmdb_url = $tmdb_url |
                            (if $genres != "" then .genres = ($genres | split(", ") | map(select(. != "")) | map(gsub("^\\s+|\\s+$"; ""))) else . end)
                        ' 2>/dev/null)
                    fi
                    
                    if [[ "$CAT_FOR_TMDB" == "serie" ]]; then
                        if [[ -n "$SERIES_NAME" ]]; then
                            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg series_name "$SERIES_NAME" '.series_name = $series_name' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                        fi
                        if [[ -n "$EPISODE_NAME" ]]; then
                            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg episode_name "$EPISODE_NAME" '.episode_name = $episode_name' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                        fi
                        if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
                            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson season "$SEASON_NUMBER" '.season_number = ($season | tonumber)' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                        fi
                        if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
                            TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson episode "$EPISODE_NUMBER" '.episode_number = ($episode | tonumber)' 2>/dev/null || echo "$TMDB_METADATA_JSON")
                        fi
                    fi
                else
                    TMDB_METADATA_JSON=$(cat << EOF
{
  "tmdb_id": $MEDIAID,
  "media_type": "$MEDIA_TYPE",
  "title": "$TITLE",
  "year": "$YEAR",
  "tmdb_url": "$TMDB_URL",
  "genres": $GENRES_ARRAY
EOF
                    )
                    if [[ "$CAT_FOR_TMDB" == "serie" ]]; then
                        if [[ -n "$SERIES_NAME" ]]; then
                            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"series_name\": \"$SERIES_NAME\""
                        fi
                        if [[ -n "$EPISODE_NAME" ]]; then
                            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"episode_name\": \"$EPISODE_NAME\""
                        fi
                        if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
                            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"season_number\": $SEASON_NUMBER"
                        fi
                        if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
                            TMDB_METADATA_JSON="${TMDB_METADATA_JSON},
  \"episode_number\": $EPISODE_NUMBER"
                        fi
                    fi
                    TMDB_METADATA_JSON="${TMDB_METADATA_JSON}
}"
                fi
                
                echo "$TMDB_METADATA_JSON" > "$TMDB_METADATA_FILE"
                echo "✅ Created TMDB metadata file: $TMDB_METADATA_FILE"
            else
                zenity --warning --width 600 --text "Vous devez renseigner un numéro! Merci de recommencer... Seules les vidéos référencées sur The Movie Database sont acceptées." && exit 1
            fi
        fi
    fi
    
    # If no TMDB enrichment, use simple title input
    if [[ "$TMDB_ENRICHMENT" == "Aucun" ]] || [[ -z "$TMDB_METADATA_FILE" ]]; then
        # VIDEO TITLE
        TITLE=$(zenity --entry --width 600 --title "Titre" --text "Indiquez le titre de cette vidéo" --entry-text="${FILE_TITLE}")
        [[ $TITLE == "" ]] && exit 1
        TITLE=$(echo "${TITLE}" | detox --inline)
        TITLE_FOR_PUBLICATION="$TITLE"
        
        # Ask for description
        [ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description de la vidéo (optionnel)" --entry-text="")
    fi
    
    # Copy to temp (use sanitized title for filename)
    TITLE_FOR_FILENAME="${TITLE_FOR_FILENAME:-$TITLE}"
    FINAL_FILE="$HOME/.zen/tmp/${TITLE_FOR_FILENAME}.${FILE_EXT}"
    cp "${FILE}" "$FINAL_FILE"
        
        # Upload via upload2ipfs.sh directly (no API, no NIP-42 required)
        echo "📤 Uploading video via upload2ipfs.sh..."
        
        # Create temp output file for upload2ipfs.sh JSON response
        UPLOAD_OUTPUT_FILE="$HOME/.zen/tmp/upload_$(date +%s).json"
        
        # Get upload2ipfs.sh path
        UPLOAD_SCRIPT="${MY_PATH}/../UPassport/upload2ipfs.sh"
        if [[ ! -f "$UPLOAD_SCRIPT" ]]; then
            UPLOAD_SCRIPT="${HOME}/.zen/Astroport.ONE/UPassport/upload2ipfs.sh"
        fi
        if [[ ! -f "$UPLOAD_SCRIPT" ]]; then
            UPLOAD_SCRIPT="${HOME}/workspace/AAA/UPassport/upload2ipfs.sh"
        fi
        
        if [[ ! -f "$UPLOAD_SCRIPT" ]]; then
            echo "❌ ERROR: upload2ipfs.sh not found"
            espeak "Upload script not found"
            exit 1
        fi
        
        # Call upload2ipfs.sh (with TMDB metadata if available)
        if [[ -n "$NPUB_HEX" ]]; then
            if [[ -n "$TMDB_METADATA_FILE" ]] && [[ -f "$TMDB_METADATA_FILE" ]]; then
                echo "📤 Using upload2ipfs.sh with provenance tracking and TMDB metadata (hex: ${NPUB_HEX:0:16}...)"
                bash "$UPLOAD_SCRIPT" --metadata "$TMDB_METADATA_FILE" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" "$NPUB_HEX" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
            else
                echo "📤 Using upload2ipfs.sh with provenance tracking (hex: ${NPUB_HEX:0:16}...)"
                bash "$UPLOAD_SCRIPT" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" "$NPUB_HEX" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
            fi
        else
            if [[ -n "$TMDB_METADATA_FILE" ]] && [[ -f "$TMDB_METADATA_FILE" ]]; then
                echo "📤 Using upload2ipfs.sh with TMDB metadata (no provenance tracking)"
                bash "$UPLOAD_SCRIPT" --metadata "$TMDB_METADATA_FILE" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
            else
                echo "📤 Using upload2ipfs.sh without provenance tracking"
                bash "$UPLOAD_SCRIPT" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
            fi
        fi
        
        UPLOAD_EXIT_CODE=$?
        
        if [[ $UPLOAD_EXIT_CODE -ne 0 ]] || [[ ! -f "$UPLOAD_OUTPUT_FILE" ]]; then
            echo "❌ ERROR: upload2ipfs.sh failed (exit code: $UPLOAD_EXIT_CODE)"
            echo "Log output:"
            cat "$HOME/.zen/tmp/upload2ipfs.log" 2>/dev/null || echo "(no log)"
            espeak "Upload failed"
            rm -f "$UPLOAD_OUTPUT_FILE"
    exit 1
        fi
        
        # Read upload result JSON
        if ! command -v jq &> /dev/null; then
            echo "❌ ERROR: jq is required but not found"
            espeak "jq required"
            rm -f "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Validate JSON
        if ! jq -e '.' "$UPLOAD_OUTPUT_FILE" >/dev/null 2>&1; then
            echo "❌ ERROR: Invalid JSON from upload2ipfs.sh"
            echo "Output:"
            cat "$UPLOAD_OUTPUT_FILE"
            espeak "Invalid JSON"
            rm -f "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Extract values from upload result
        IPFS_CID=$(jq -r '.cid // empty' "$UPLOAD_OUTPUT_FILE")
        DIMENSIONS=$(jq -r '.dimensions // empty' "$UPLOAD_OUTPUT_FILE")
        DURATION=$(jq -r '.duration // 0' "$UPLOAD_OUTPUT_FILE")
        
        if [[ -z "$IPFS_CID" ]]; then
            echo "❌ ERROR: Failed to get IPFS CID from upload result"
            espeak "IPFS upload failed"
            rm -f "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        echo "✅ Video uploaded to IPFS and copied to uDRIVE!"
        echo "   CID: $IPFS_CID"
        [[ -n "$DIMENSIONS" ]] && echo "   Dimensions: $DIMENSIONS"
        [[ -n "$DURATION" ]] && [[ "$DURATION" != "0" ]] && echo "   Duration: ${DURATION}s"
        
        # Publish via publish_nostr_video.sh directly (no API, no NIP-42 required)
        echo "📹 Publishing video via publish_nostr_video.sh..."
        
        # Get publish script path
        PUBLISH_SCRIPT="${MY_PATH}/tools/publish_nostr_video.sh"
        if [[ ! -f "$PUBLISH_SCRIPT" ]]; then
            PUBLISH_SCRIPT="${HOME}/.zen/Astroport.ONE/tools/publish_nostr_video.sh"
        fi
        
        if [[ ! -f "$PUBLISH_SCRIPT" ]]; then
            echo "❌ ERROR: publish_nostr_video.sh not found"
            espeak "Publish script not found"
            rm -f "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Get secret file path
        SECRET_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
        if [[ ! -f "$SECRET_FILE" ]]; then
            echo "❌ ERROR: Secret file not found: $SECRET_FILE"
            espeak "Secret file not found"
            rm -f "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        # Build publish command using --auto mode (reads from upload2ipfs.sh output)
        # Use TITLE_FOR_PUBLICATION if available (from TMDB enrichment), otherwise use TITLE
        PUBLISH_TITLE="${TITLE_FOR_PUBLICATION:-$TITLE}"
        PUBLISH_CMD=("$PUBLISH_SCRIPT" "--auto" "$UPLOAD_OUTPUT_FILE" "--nsec" "$SECRET_FILE" "--title" "$PUBLISH_TITLE")
        
        if [[ -n "$VIDEO_DESC" ]]; then
            PUBLISH_CMD+=("--description" "$VIDEO_DESC")
        fi
        
        # Add source type based on TMDB enrichment or default to webcam
        if [[ "$TMDB_ENRICHMENT" == "Film" ]]; then
            PUBLISH_CMD+=("--source-type" "film")
            echo "📽️ Source type: film (personal video with TMDB enrichment)"
        elif [[ "$TMDB_ENRICHMENT" == "Serie" ]]; then
            PUBLISH_CMD+=("--source-type" "serie")
            echo "📺 Source type: serie (personal video with TMDB enrichment)"
            
            # Add series metadata tags if available
            if [[ -n "$SERIES_NAME" ]]; then
                PUBLISH_CMD+=("--series-name" "$SERIES_NAME")
                echo "📺 Series name: $SERIES_NAME"
            fi
            if [[ -n "$EPISODE_NAME_FOR_PUBLICATION" ]]; then
                PUBLISH_CMD+=("--episode-name" "$EPISODE_NAME_FOR_PUBLICATION")
                echo "📺 Episode name: $EPISODE_NAME_FOR_PUBLICATION"
            elif [[ -n "$EPISODE_NAME" ]]; then
                PUBLISH_CMD+=("--episode-name" "$EPISODE_NAME")
                echo "📺 Episode name: $EPISODE_NAME"
            fi
            if [[ -n "$SEASON_NUMBER" ]] && [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]]; then
                PUBLISH_CMD+=("--season-number" "$SEASON_NUMBER")
                echo "📺 Season number: $SEASON_NUMBER"
            fi
            if [[ -n "$EPISODE_NUMBER" ]] && [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]]; then
                PUBLISH_CMD+=("--episode-number" "$EPISODE_NUMBER")
                echo "📺 Episode number: $EPISODE_NUMBER"
            fi
        else
            PUBLISH_CMD+=("--source-type" "webcam")
            echo "📹 Source type: webcam (personal video)"
        fi
        
        # Add genres for tag publication (kind 1985) if available from TMDB
        if [[ -n "$GENRES_ARRAY" ]] && [[ "$GENRES_ARRAY" != "[]" ]] && [[ "$GENRES_ARRAY" != "null" ]]; then
            GENRES_ARRAY_CLEAN=$(echo "$GENRES_ARRAY" | jq -c '.' 2>/dev/null | tr -d '\n\r')
            if [[ -n "$GENRES_ARRAY_CLEAN" ]] && echo "$GENRES_ARRAY_CLEAN" | jq -e '.' >/dev/null 2>&1; then
                PUBLISH_CMD+=("--genres" "$GENRES_ARRAY_CLEAN")
                echo "🏷️  Genres for tagging (kind 1985): $GENRES_ARRAY_CLEAN"
            fi
        fi
        
        # Add dimensions and duration explicitly to ensure correct values (personal video)
        if [[ -n "$DIMENSIONS" ]] && [[ "$DIMENSIONS" != "empty" ]] && [[ "$DIMENSIONS" != "" ]] && [[ "$DIMENSIONS" != "640x480" ]]; then
            PUBLISH_CMD+=("--dimensions" "$DIMENSIONS")
            echo "📐 Dimensions: $DIMENSIONS"
        fi
        
        if [[ -n "$DURATION" ]] && [[ "$DURATION" != "0" ]] && [[ "$DURATION" != "empty" ]] && [[ "$DURATION" != "" ]]; then
            PUBLISH_CMD+=("--duration" "$DURATION")
            echo "⏱️  Duration: ${DURATION}s"
        fi
        
        PUBLISH_CMD+=("--channel" "$PLAYER" "--json")
        
        # Execute publish script
        PUBLISH_OUTPUT=$(bash "${PUBLISH_CMD[@]}" 2>&1)
        PUBLISH_EXIT_CODE=$?
        
        if [[ $PUBLISH_EXIT_CODE -eq 0 ]]; then
            # Try to extract event ID from output
            EVENT_ID=$(echo "$PUBLISH_OUTPUT" | jq -r '.event_id // empty' 2>/dev/null || echo "")
            if [[ -n "$EVENT_ID" ]]; then
                echo "✅ Video published successfully to NOSTR!"
                echo "   Event ID: ${EVENT_ID:0:16}..."
            espeak "Video published"
        else
                # Try regex extraction
                EVENT_ID=$(echo "$PUBLISH_OUTPUT" | grep -oE '"event_id"\s*:\s*"[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}' | head -1)
                if [[ -n "$EVENT_ID" ]]; then
                    echo "✅ Video published successfully to NOSTR!"
                    echo "   Event ID: ${EVENT_ID:0:16}..."
                    espeak "Video published"
                else
                    echo "⚠️  Video uploaded but event ID not found in output"
                    echo "Publish output: $PUBLISH_OUTPUT"
                fi
            fi
        else
            echo "⚠️  Video uploaded but publication may have failed (exit code: $PUBLISH_EXIT_CODE)"
            echo "Publish output: $PUBLISH_OUTPUT"
        fi
        
        # Cleanup temp files
        rm -f "$UPLOAD_OUTPUT_FILE"
        [[ -n "$TMDB_METADATA_FILE" ]] && [[ -f "$TMDB_METADATA_FILE" ]] && rm -f "$TMDB_METADATA_FILE"
    ;;

    ########################################################################
# CASE ## DEFAULT
    ########################################################################
    *)
        [ ! $2 ] && zenity --warning --width 600 --text "Impossible d'interpréter votre commande $CAT"
    exit 1
    ;;

esac

end=$(date +%s)
dur=$((end - start))
espeak "It took $dur seconds to accomplish" 2>/dev/null || true

exit 0
