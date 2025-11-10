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
alias espeak='espeak >/dev/null 2>&1'

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
if [[ ! -f ~/.zen/game/players/${PLAYER}/legal ]]; then
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

        # Download YouTube video using process_youtube.sh
echo "📥 Downloading YouTube video using process_youtube.sh..."

# Create temporary download directory
TEMP_YOUTUBE_DIR="$HOME/.zen/tmp/youtube_$(date -u +%s%N | cut -b1-13)"
mkdir -p "$TEMP_YOUTUBE_DIR"

# Call process_youtube.sh with --json, --no-ipfs and --output-dir options
echo "📥 Calling process_youtube.sh with: --json --no-ipfs --output-dir \"$TEMP_YOUTUBE_DIR\" \"$YTURL\" \"mp4\" \"$PLAYER\""
YOUTUBE_RESULT=$(${MY_PATH}/IA/process_youtube.sh --json --debug --no-ipfs --output-dir "$TEMP_YOUTUBE_DIR" "$YTURL" "mp4" "$PLAYER" 2>&1)
YTDLP_EXIT=$?

echo "📋 process_youtube.sh exit code: $YTDLP_EXIT"

# Extract JSON from result (with --json flag, output is pure JSON)
YOUTUBE_JSON=$(echo "$YOUTUBE_RESULT" | grep -E '^\{|^\[' | head -n 1)

# If no JSON found, try to extract from stderr messages
if [[ -z "$YOUTUBE_JSON" ]] || ! echo "$YOUTUBE_JSON" | jq '.' >/dev/null 2>&1; then
    # Try to find JSON in the output
    YOUTUBE_JSON=$(echo "$YOUTUBE_RESULT" | jq -c '.' 2>/dev/null | head -n 1)
    
    # If still no valid JSON, try to extract error JSON
    if [[ -z "$YOUTUBE_JSON" ]] || ! echo "$YOUTUBE_JSON" | jq '.' >/dev/null 2>&1; then
        YOUTUBE_JSON=$(echo "$YOUTUBE_RESULT" | grep -oE '\{[^}]*"error"[^}]*\}' | head -n 1)
    fi
fi

# Check if JSON contains an error field
if [[ -n "$YOUTUBE_JSON" ]] && echo "$YOUTUBE_JSON" | jq -e '.error' >/dev/null 2>&1; then
    ERROR_MSG=$(echo "$YOUTUBE_JSON" | jq -r '.error')
    
    # Build user-friendly error message for zenity
    ERROR_DISPLAY="❌ ERROR: $ERROR_MSG"
    
    # Check if error is about missing cookie
    if echo "$ERROR_MSG" | grep -qi "cookie"; then
        ERROR_DISPLAY="${ERROR_DISPLAY}  💡 Solution:\n"
        ERROR_DISPLAY="${ERROR_DISPLAY}   1. Export your YouTube cookies from your browser\n"
        ERROR_DISPLAY="${ERROR_DISPLAY}   2. Upload the cookie file via: http://127.0.0.1:54321/api/fileupload\n"
        ERROR_DISPLAY="${ERROR_DISPLAY}   3. The cookie file should be saved as:\n"
        ERROR_DISPLAY="${ERROR_DISPLAY}      ~/.zen/game/nostr/${PLAYER}/.youtube.com.cookie  "
        ERROR_DISPLAY="${ERROR_DISPLAY}   Or use the cookie upload interface at:\n"
        ERROR_DISPLAY="${ERROR_DISPLAY}   http://127.0.0.1:54321/cookie"
    fi
    
    # Display error to user via zenity (if available and not in non-interactive mode)
    if [[ -z "$2" ]] && command -v zenity &> /dev/null; then
        zenity --error \
            --width 600 \
            --title="YouTube Download Error" \
            --text="$ERROR_DISPLAY" 2>/dev/null || true
    fi
    
    # Also display in console
    echo "$ERROR_DISPLAY" | sed 's/\\n/\n/g'
    echo ""
    echo "Full output from process_youtube.sh:"
    echo "$YOUTUBE_RESULT"
    echo ""
    echo "📋 Check also: ~/.zen/tmp/IA.log for detailed process_youtube.sh logs"
    espeak "YouTube processing error"
    exit 1
fi

# If exit code is non-zero but no JSON error was found, show generic error
if [[ $YTDLP_EXIT -ne 0 ]]; then
    ERROR_DISPLAY="❌ ERROR: YouTube download failed (exit code: $YTDLP_EXIT)"
    
    # Display error to user via zenity (if available and not in non-interactive mode)
    if [[ -z "$2" ]] && command -v zenity &> /dev/null; then
        zenity --error \
            --width 500 \
            --title="YouTube Download Error" \
            --text="${ERROR_DISPLAY}  Check ~/.zen/tmp/IA.log for details." 2>/dev/null || true
    fi
    
    echo "$ERROR_DISPLAY"
    echo "Full output from process_youtube.sh:"
    echo "$YOUTUBE_RESULT"
    echo ""
    echo "📋 Check also: ~/.zen/tmp/IA.log for detailed process_youtube.sh logs"
    espeak "YouTube download failed"
    exit 1
fi

# Validate JSON
if ! echo "$YOUTUBE_JSON" | jq '.' >/dev/null 2>&1; then
    echo "❌ ERROR: Invalid JSON from process_youtube.sh"
    echo "Full output:"
    echo "$YOUTUBE_RESULT"
    echo ""
    echo "📋 Check also: ~/.zen/tmp/IA.log for detailed process_youtube.sh logs"
    espeak "Invalid JSON from YouTube processing"
    exit 1
fi

# Extract metadata from JSON result
TITLE=$(echo "$YOUTUBE_JSON" | jq -r '.title // empty')
DURATION=$(echo "$YOUTUBE_JSON" | jq -r '.duration // "0"')
FILENAME=$(echo "$YOUTUBE_JSON" | jq -r '.filename // empty')
FILE_PATH_DOWNLOADED=$(echo "$YOUTUBE_JSON" | jq -r '.file_path // empty')
METADATA_FILE_FROM_JSON=$(echo "$YOUTUBE_JSON" | jq -r '.metadata_file // empty')
OUTPUT_DIR_FROM_JSON=$(echo "$YOUTUBE_JSON" | jq -r '.output_dir // empty')

# Validate extracted values - if file_path doesn't exist, try to find it in output_dir
if [[ -z "$FILE_PATH_DOWNLOADED" ]] || [[ ! -f "$FILE_PATH_DOWNLOADED" ]]; then
    # Try to find the file in output_dir
    if [[ -n "$OUTPUT_DIR_FROM_JSON" ]] && [[ -d "$OUTPUT_DIR_FROM_JSON" ]]; then
        echo "🔍 File path from JSON not found, searching in output_dir: $OUTPUT_DIR_FROM_JSON"
        # Find any media file in the output directory
        FILE_PATH_DOWNLOADED=$(find "$OUTPUT_DIR_FROM_JSON" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mp3" -o -name "*.m4a" -o -name "*.webm" -o -name "*.mkv" \) ! -name "*.info.json" ! -name "*.webp" ! -name "*.png" ! -name "*.jpg" 2>/dev/null | head -n 1)
        
        # If still not found, try to find the largest file
        if [[ -z "$FILE_PATH_DOWNLOADED" ]] || [[ ! -f "$FILE_PATH_DOWNLOADED" ]]; then
            FILE_PATH_DOWNLOADED=$(find "$OUTPUT_DIR_FROM_JSON" -maxdepth 1 -type f ! -name "*.info.json" ! -name "*.webp" ! -name "*.png" ! -name "*.jpg" -exec ls -S {} + 2>/dev/null | head -n 1)
        fi
        
        if [[ -n "$FILE_PATH_DOWNLOADED" ]] && [[ -f "$FILE_PATH_DOWNLOADED" ]]; then
            FILENAME=$(basename "$FILE_PATH_DOWNLOADED")
            echo "✅ Found downloaded file: $FILE_PATH_DOWNLOADED"
        fi
    fi
fi

# Final validation
if [[ -z "$FILENAME" || -z "$FILE_PATH_DOWNLOADED" || ! -f "$FILE_PATH_DOWNLOADED" ]]; then
    echo "❌ ERROR: Downloaded file not found or invalid metadata"
    echo "   Searched for: $FILE_PATH_DOWNLOADED"
    if [[ -n "$OUTPUT_DIR_FROM_JSON" ]]; then
        echo "   In directory: $OUTPUT_DIR_FROM_JSON"
        echo "   Files in directory:"
        ls -lh "$OUTPUT_DIR_FROM_JSON" 2>/dev/null || echo "   (directory not accessible)"
    fi
    espeak "Download failed"
    exit 1
fi

echo "✅ Downloaded: $FILENAME"
echo "   Title: $TITLE"
echo "   Duration: $DURATION seconds"
       
        # Upload via /api/fileupload (copies to uDRIVE automatically)
        echo "📤 Uploading video via /api/fileupload..."
        
        if [[ -z "$NPUB" ]]; then
            echo "❌ ERROR: No NOSTR npub found, upload will fail"
            espeak "No NOSTR key found"
    exit 1
fi

        # Send NIP-42 authentication event before upload
        echo "🔐 Sending NIP-42 authentication event..."
        SECRET_NOSTR_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
        NOSTR_SEND_SCRIPT="${MY_PATH}/tools/nostr_send_note.py"
        NOSTR_RELAY="ws://127.0.0.1:7777"
        
        if [[ -f "$SECRET_NOSTR_FILE" ]] && [[ -f "$NOSTR_SEND_SCRIPT" ]]; then
            # Send NIP-42 event (kind 22242) to authenticate with relay
            # Content includes IPFSNODEID and UPLANETNAME_G1 for identification
            NIP42_CONTENT="${IPFSNODEID} ${UPLANETNAME_G1}"
            NIP42_TAGS='[["relay","'${NOSTR_RELAY}'"],["challenge",""]]'
            if python3 "$NOSTR_SEND_SCRIPT" \
                --keyfile "$SECRET_NOSTR_FILE" \
                --content "$NIP42_CONTENT" \
                --kind 22242 \
                --tags "$NIP42_TAGS" \
                --relays "$NOSTR_RELAY" \
                >/dev/null 2>&1; then
                echo "✅ NIP-42 authentication event sent"
                # Wait a bit for the event to be processed by the relay
                sleep 2
            else
                echo "⚠️  Warning: Failed to send NIP-42 authentication event (upload may still work if already authenticated)"
            fi
        else
            if [[ ! -f "$SECRET_NOSTR_FILE" ]]; then
                echo "⚠️  Warning: Secret key file not found: $SECRET_NOSTR_FILE"
            fi
            if [[ ! -f "$NOSTR_SEND_SCRIPT" ]]; then
                echo "⚠️  Warning: nostr_send_note.py not found: $NOSTR_SEND_SCRIPT"
            fi
            echo "⚠️  Warning: Cannot send NIP-42 authentication event (upload may still work if already authenticated)"
        fi

        # Upload with YouTube metadata if available
        if [[ -n "$YOUTUBE_METADATA_JSON_FILE" ]] && [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]]; then
            echo "📤 Uploading video with YouTube metadata..."
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_PATH_DOWNLOADED}" \
                -F "npub=${NPUB}" \
                -F "youtube_metadata=@${YOUTUBE_METADATA_JSON_FILE}")
        else
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_PATH_DOWNLOADED}" \
                -F "npub=${NPUB}")
        fi
        
        if ! echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
            echo "❌ ERROR: /api/fileupload failed"
            echo "Response: $UPLOAD_RESPONSE"
            espeak "Upload failed"
    exit 1
fi

        # Extract values from upload response
        IPFS_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.new_cid // empty')
        INFO_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.info // empty')
        THUMBNAIL_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.thumbnail_ipfs // empty')
        GIFANIM_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.gifanim_ipfs // empty')
        FILE_HASH=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileHash // empty')
        DIMENSIONS=$(echo "$UPLOAD_RESPONSE" | jq -r '.dimensions // empty')
        UPLOAD_CHAIN=$(echo "$UPLOAD_RESPONSE" | jq -r '.upload_chain // empty')

if [[ -z "$IPFS_CID" ]]; then
            echo "❌ ERROR: Failed to get IPFS CID from upload response"
    espeak "IPFS upload failed"
    exit 1
fi

        echo "✅ Video uploaded to IPFS and copied to uDRIVE!"
echo "   CID: $IPFS_CID"
        
        # Find YouTube metadata.json file (yt-dlp .info.json contains all YouTube metadata)
        YOUTUBE_METADATA_FILE=""
        if [[ -n "$METADATA_FILE_FROM_JSON" ]] && [[ -f "$METADATA_FILE_FROM_JSON" ]]; then
            YOUTUBE_METADATA_FILE="$METADATA_FILE_FROM_JSON"
        else
            METADATA_BASENAME=$(basename "$FILE_PATH_DOWNLOADED" | sed 's/\.[^.]*$//')
            for possible_metadata in "${TEMP_YOUTUBE_DIR}/${METADATA_BASENAME}.info.json" "$(dirname "$FILE_PATH_DOWNLOADED")/${METADATA_BASENAME}.info.json"; do
                if [[ -f "$possible_metadata" ]]; then
                    YOUTUBE_METADATA_FILE="$possible_metadata"
                    break
                fi
            done
        fi
        
        # Extract and structure all YouTube metadata for info.json
        YOUTUBE_METADATA_JSON_FILE="$HOME/.zen/tmp/youtube_metadata_$(date +%s).json"
        if [[ -n "$YOUTUBE_METADATA_FILE" ]] && [[ -f "$YOUTUBE_METADATA_FILE" ]] && command -v jq &> /dev/null; then
            echo "📋 Extracting comprehensive YouTube metadata..."
            
            # Extract all relevant YouTube metadata from yt-dlp .info.json
            YOUTUBE_METADATA_JSON=$(jq '{
                youtube_id: .id,
                youtube_url: .webpage_url,
                youtube_short_url: .short_url,
                title: .title,
                description: .description,
                uploader: .uploader,
                uploader_id: .uploader_id,
                uploader_url: .uploader_url,
                channel: .channel,
                channel_id: .channel_id,
                channel_url: .channel_url,
                channel_follower_count: .channel_follower_count,
                duration: .duration,
                view_count: .view_count,
                like_count: .like_count,
                comment_count: .comment_count,
                average_rating: .average_rating,
                age_limit: .age_limit,
                upload_date: .upload_date,
                release_date: .release_date,
                timestamp: .timestamp,
                availability: .availability,
                live_status: .live_status,
                was_live: .was_live,
                format: .format,
                format_id: .format_id,
                format_note: .format_note,
                width: .width,
                height: .height,
                fps: .fps,
                vcodec: .vcodec,
                acodec: .acodec,
                abr: .abr,
                vbr: .vbr,
                tbr: .tbr,
                filesize: .filesize,
                filesize_approx: .filesize_approx,
                ext: .ext,
                resolution: .resolution,
                categories: .categories,
                tags: .tags,
                chapters: .chapters,
                subtitles: .subtitles,
                automatic_captions: .automatic_captions,
                thumbnail: .thumbnail,
                thumbnails: .thumbnails,
                license: .license,
                language: .language,
                languages: .languages,
                location: .location,
                artist: .artist,
                album: .album,
                track: .track,
                creator: .creator,
                alt_title: .alt_title,
                series: .series,
                season: .season,
                season_number: .season_number,
                episode: .episode,
                episode_number: .episode_number,
                playlist: .playlist,
                playlist_id: .playlist_id,
                playlist_title: .playlist_title,
                playlist_index: .playlist_index,
                n_entries: .n_entries,
                webpage_url_basename: .webpage_url_basename,
                webpage_url_domain: .webpage_url_domain,
                extractor: .extractor,
                extractor_key: .extractor_key,
                epoch: .epoch,
                modified_timestamp: .modified_timestamp,
                modified_date: .modified_date,
                requested_subtitles: .requested_subtitles,
                has_drm: .has_drm,
                is_live: .is_live,
                was_live: .was_live,
                live_status: .live_status,
                release_timestamp: .release_timestamp,
                comment_count: .comment_count,
                heatmap: .heatmap
            }' "$YOUTUBE_METADATA_FILE" 2>/dev/null)
            
            if [[ -n "$YOUTUBE_METADATA_JSON" ]] && echo "$YOUTUBE_METADATA_JSON" | jq -e '.' >/dev/null 2>&1; then
                echo "$YOUTUBE_METADATA_JSON" > "$YOUTUBE_METADATA_JSON_FILE"
                echo "✅ YouTube metadata extracted and saved to: $YOUTUBE_METADATA_JSON_FILE"
                
                # Display key metadata
                YT_UPLOADER=$(echo "$YOUTUBE_METADATA_JSON" | jq -r '.uploader // .channel // empty')
                YT_CHANNEL=$(echo "$YOUTUBE_METADATA_JSON" | jq -r '.channel // empty')
                YT_VIEWS=$(echo "$YOUTUBE_METADATA_JSON" | jq -r '.view_count // empty')
                YT_LIKES=$(echo "$YOUTUBE_METADATA_JSON" | jq -r '.like_count // empty')
                YT_WEBPAGE_URL=$(echo "$YOUTUBE_METADATA_JSON" | jq -r '.youtube_url // .webpage_url // empty')
                
                echo "   📺 Channel: ${YT_CHANNEL:-$YT_UPLOADER}"
                [[ -n "$YT_VIEWS" ]] && echo "   👁️  Views: $YT_VIEWS"
                [[ -n "$YT_LIKES" ]] && echo "   👍 Likes: $YT_LIKES"
            else
                echo "⚠️  Failed to extract YouTube metadata JSON"
                YOUTUBE_METADATA_JSON_FILE=""
            fi
        else
            echo "⚠️  YouTube metadata file not found, skipping metadata extraction"
            YOUTUBE_METADATA_JSON_FILE=""
        fi
        
        # Ask for title and description for video publication
        [ ! $2 ] && VIDEO_TITLE=$(zenity --entry --width 600 --title "Titre de la vidéo" --text "Titre de la vidéo YouTube" --entry-text="$TITLE")
        [[ -z "$VIDEO_TITLE" ]] && VIDEO_TITLE="$TITLE"
        
        [ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description de la vidéo (optionnel)" --entry-text="")
        
        # Build description with YouTube metadata if available
        if [[ -n "$YOUTUBE_METADATA_FILE" ]] && command -v jq &> /dev/null; then
            YT_UPLOADER=$(jq -r '.uploader // .channel // empty' "$YOUTUBE_METADATA_FILE" 2>/dev/null)
            YT_WEBPAGE_URL=$(jq -r '.webpage_url // .url // empty' "$YOUTUBE_METADATA_FILE" 2>/dev/null)
            if [[ -n "$YT_UPLOADER" ]] || [[ -n "$YT_WEBPAGE_URL" ]]; then
                if [[ -n "$VIDEO_DESC" ]]; then
                    VIDEO_DESC="${VIDEO_DESC}  Source YouTube: ${YT_UPLOADER}"
                    [[ -n "$YT_WEBPAGE_URL" ]] && VIDEO_DESC="${VIDEO_DESC}\n${YT_WEBPAGE_URL}"
                else
                    VIDEO_DESC="Source YouTube: ${YT_UPLOADER}"
                    [[ -n "$YT_WEBPAGE_URL" ]] && VIDEO_DESC="${VIDEO_DESC}\n${YT_WEBPAGE_URL}"
                fi
            fi
        fi
        
        # Publish video via /webcam endpoint (NIP-71)
        echo "📹 Publishing video via /webcam endpoint..."
        
        PUBLISH_DATA="player=${PLAYER}"
        PUBLISH_DATA="${PUBLISH_DATA}&ipfs_cid=${IPFS_CID}"
        PUBLISH_DATA="${PUBLISH_DATA}&thumbnail_ipfs=${THUMBNAIL_CID}"
        PUBLISH_DATA="${PUBLISH_DATA}&gifanim_ipfs=${GIFANIM_CID}"
        PUBLISH_DATA="${PUBLISH_DATA}&info_cid=${INFO_CID}"
        PUBLISH_DATA="${PUBLISH_DATA}&file_hash=${FILE_HASH}"
        PUBLISH_DATA="${PUBLISH_DATA}&mime_type=video/mp4"
        PUBLISH_DATA="${PUBLISH_DATA}&upload_chain=${UPLOAD_CHAIN}"
        PUBLISH_DATA="${PUBLISH_DATA}&duration=${DURATION}"
        PUBLISH_DATA="${PUBLISH_DATA}&video_dimensions=${DIMENSIONS}"
        PUBLISH_DATA="${PUBLISH_DATA}&title=${VIDEO_TITLE}"
        PUBLISH_DATA="${PUBLISH_DATA}&description=${VIDEO_DESC}"
        PUBLISH_DATA="${PUBLISH_DATA}&publish_nostr=true"
        PUBLISH_DATA="${PUBLISH_DATA}&npub=${NPUB}"
        # Add YouTube URL if available (for source:youtube tag)
        if [[ -n "$YTURL" ]]; then
            PUBLISH_DATA="${PUBLISH_DATA}&youtube_url=${YTURL}"
        fi
        
        PUBLISH_RESPONSE=$(curl -s -X POST "${API_URL}/webcam" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "$PUBLISH_DATA")
        
        if echo "$PUBLISH_RESPONSE" | grep -q "success\|✅"; then
            echo "✅ Video published successfully!"
            espeak "YouTube video published"
        else
            echo "⚠️  Video upload succeeded but publication may have failed"
            echo "Response: $PUBLISH_RESPONSE"
        fi
        
        # Cleanup temp files
        rm -rf "$TEMP_YOUTUBE_DIR"
        [[ -n "$YOUTUBE_METADATA_JSON_FILE" ]] && [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]] && rm -f "$YOUTUBE_METADATA_JSON_FILE"
        
        espeak "YouTube video ready"
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
        [[ $URL == "" ]] && URL=$(zenity --entry --width 500 --title "Lien Youtube à convertir en MP3" --text "Indiquez le lien (URL)" --entry-text="")
        [[ $URL == "" ]] && echo "URL EMPTY" && exit 1
        
        echo "Processing URL: $URL"
        espeak "OK."
        
        # Use process_youtube.sh for MP3 processing
        MP3_RESULT=$(${MY_PATH}/IA/process_youtube.sh --debug "$URL" "mp3" "$PLAYER")
        MP3_EXIT_CODE=$?
        
        # Check if the result is valid JSON
        if ! echo "$MP3_RESULT" | jq . >/dev/null 2>&1; then
            echo "Invalid JSON returned from process_youtube.sh"
            espeak "Invalid JSON from YouTube processing"
            exit 1
        fi
        
        # Check if process_youtube.sh succeeded
        if echo "$MP3_RESULT" | jq -e '.error' >/dev/null 2>&1; then
            ERROR_MSG=$(echo "$MP3_RESULT" | jq -r '.error')
            echo "MP3 processing failed: $ERROR_MSG"
            espeak "MP3 processing failed"
            exit 1
        fi
        
        # Extract values from JSON result
        FILE_TITLE=$(echo "$MP3_RESULT" | jq -r '.title // empty' 2>/dev/null)
        FILE_NAME=$(echo "$MP3_RESULT" | jq -r '.filename // empty' 2>/dev/null)
        IPFS_URL=$(echo "$MP3_RESULT" | jq -r '.ipfs_url // empty' 2>/dev/null)
        
        if [[ -z "$FILE_TITLE" || -z "$FILE_NAME" ]]; then
            echo "Failed to extract required data from MP3 processing"
            espeak "Failed to extract data"
            exit 1
        fi
        
        # Find file path from process_youtube.sh result (it should already be in uDRIVE or temp)
        FILE_PATH_FROM_RESULT=$(echo "$MP3_RESULT" | jq -r '.file_path // empty' 2>/dev/null)
        if [[ -n "$FILE_PATH_FROM_RESULT" && -f "$FILE_PATH_FROM_RESULT" ]]; then
            FILE_TO_UPLOAD="$FILE_PATH_FROM_RESULT"
        else
            # Fallback: try to find in uDRIVE
            if [[ -n "$USER_UDRIVE_PATH" && -f "$USER_UDRIVE_PATH/Music/$FILE_NAME" ]]; then
                FILE_TO_UPLOAD="$USER_UDRIVE_PATH/Music/$FILE_NAME"
            else
                echo "⚠️  MP3 file not found: $FILE_PATH_FROM_RESULT or $USER_UDRIVE_PATH/Music/$FILE_NAME"
                espeak "Error: MP3 file not found"
            exit 1
        fi
        fi
        
        # Upload via API (upload2ipfs.sh will handle uDRIVE storage, will auto-publish as NIP-94 kind 1063)
        echo "📤 Uploading MP3 via /api/fileupload..."
        
        if [[ -n "$NPUB" ]]; then
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_TO_UPLOAD}" \
                -F "npub=${NPUB}")
        else
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_TO_UPLOAD}" \
                -F "npub=")
        fi
        
        if echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
            echo "✅ MP3 uploaded and published successfully!"
            espeak "Ready. MP3 file processed"
        else
            echo "❌ Upload failed"
            echo "Response: $UPLOAD_RESPONSE"
            espeak "Upload failed"
            exit 1
        fi
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
if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
    TITLE=$(echo "$SCRAPED_METADATA" | jq -r '.title // empty' 2>/dev/null)
    if [[ -z "$TITLE" ]]; then
        TITLE="$FILE_TITLE"
    fi
else
    TITLE="$FILE_TITLE"
fi

# VIDEO TITLE (ask user to confirm/edit)
TITLE=$(zenity --entry --width 300 --title "Titre" --text "Indiquez le titre de la vidéo" --entry-text="$TITLE")
[[ $TITLE == "" ]] && exit 1
        TITLE=$(echo "${TITLE}" | detox --inline)

# Extract or ask for year
if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
    YEAR=$(echo "$SCRAPED_METADATA" | jq -r '.year // empty' 2>/dev/null)
fi
YEAR=$(zenity --entry --width 300 --title "Année" --text "Indiquez année de la vidéo. Exemple: 1985" --entry-text="$YEAR")
        
# Extract genres from scraped data or ask user
GENRES=""
GENRES_ARRAY="[]"
if [[ "$SCRAPE_TMDB" == "yes" ]] && [[ -n "$SCRAPED_METADATA" ]]; then
    # Try to get genres as array first (preferred format)
    GENRES_ARRAY=$(echo "$SCRAPED_METADATA" | jq -c '.genres // []' 2>/dev/null)
    if [[ -z "$GENRES_ARRAY" ]] || [[ "$GENRES_ARRAY" == "[]" ]]; then
        # Fallback: try to get as comma-separated string
        GENRES=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
    else
        # Convert array to comma-separated string for display
        GENRES=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
    fi
fi
if [[ -z "$GENRES" ]] || [[ "$GENRES" == "" ]]; then
    GENRES=$(zenity --entry --width 400 --title "Genres" --text "Indiquez les genres (séparés par des virgules). Ex: Action, Science Fiction, Thriller" --entry-text="")
fi
# Convert genres string to array format for JSON
if [[ -n "$GENRES" ]]; then
    GENRES_ARRAY=$(echo "$GENRES" | jq -R 'split(", ") | map(select(. != "")) | map(gsub("^\\s+|\\s+$"; ""))' 2>/dev/null || echo "[]")
    echo "📋 Genres: $GENRES"
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
            UPLOAD_SCRIPT="${HOME}/.zen/Astroport.ONE/UPassport/upload2ipfs.sh"
        fi
        if [[ ! -f "$UPLOAD_SCRIPT" ]]; then
            UPLOAD_SCRIPT="${HOME}/workspace/AAA/UPassport/upload2ipfs.sh"
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
        PUBLISH_TITLE="$TITLE"
        if [[ "$CAT" == "serie" ]] && [[ -n "$TITLE_WITH_EPISODE" ]]; then
            PUBLISH_TITLE="$TITLE_WITH_EPISODE"
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

    # VIDEO TITLE
    TITLE=$(zenity --entry --width 600 --title "Titre" --text "Indiquez le titre de cette vidéo" --entry-text="${FILE_TITLE}")
    [[ $TITLE == "" ]] && exit 1
        TITLE=$(echo "${TITLE}" | detox --inline)
        
        # Copy to temp
        FINAL_FILE="$HOME/.zen/tmp/${TITLE}.${FILE_EXT}"
        cp "${FILE}" "$FINAL_FILE"
        
        # Ask for description
        [ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description de la vidéo (optionnel)" --entry-text="")
        
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
        
        # Call upload2ipfs.sh
        if [[ -n "$NPUB_HEX" ]]; then
            echo "📤 Using upload2ipfs.sh with provenance tracking (hex: ${NPUB_HEX:0:16}...)"
            bash "$UPLOAD_SCRIPT" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" "$NPUB_HEX" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
        else
            echo "📤 Using upload2ipfs.sh without provenance tracking"
            bash "$UPLOAD_SCRIPT" "$FINAL_FILE" "$UPLOAD_OUTPUT_FILE" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
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
        
        if [[ -z "$IPFS_CID" ]]; then
            echo "❌ ERROR: Failed to get IPFS CID from upload result"
            espeak "IPFS upload failed"
            rm -f "$UPLOAD_OUTPUT_FILE"
            exit 1
        fi
        
        echo "✅ Video uploaded to IPFS and copied to uDRIVE!"
        echo "   CID: $IPFS_CID"
        
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
        PUBLISH_CMD=("$PUBLISH_SCRIPT" "--auto" "$UPLOAD_OUTPUT_FILE" "--nsec" "$SECRET_FILE" "--title" "$TITLE")
        
        if [[ -n "$VIDEO_DESC" ]]; then
            PUBLISH_CMD+=("--description" "$VIDEO_DESC")
        fi
        
        # Add source type: webcam for personal videos
        PUBLISH_CMD+=("--source-type" "webcam")
        echo "📹 Source type: webcam (personal video)"
        
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
    ;;

    ########################################################################
# CASE ## DEFAULT
    ########################################################################
    *)
        [ ! $2 ] && zenity --warning --width 600 --text "Impossible d'interpréter votre commande $CAT"
    exit 1
    ;;

esac

end=`date +%s`
dur=`expr $end - $start`
espeak "It tooks $dur seconds to accomplish"

exit 0
