#!/bin/bash
########################################################################
# process_youtube.sh
# Script de téléchargement et traitement des vidéos YouTube
#
# Usage: $0 [--debug] <url> <format> [player_email]
#
# --debug : active le mode verbeux, log dans ~/.zen/tmp/IA.log
#
# Fonctionnalités:
# - Téléchargement de vidéos YouTube avec yt-dlp
# - Support des formats MP3 et MP4
# - Gestion automatique des cookies :
#   1. Priorité aux cookies uploadés par l'utilisateur (.cookie.txt)
#      via l'interface astro_base.html (/api/fileupload)
#   2. Cookies du navigateur par défaut (chrome, firefox, brave, edge)
#   3. Fallback sur génération de cookies basiques avec curl
# - Upload automatique vers IPFS
# - Limitations de durée (3h max)
#
# Cookie Upload:
# Les utilisateurs peuvent uploader n'importe quel fichier .txt
# Le système détecte automatiquement le format Netscape (cookies)
# et le sauvegarde dans ~/.zen/game/nostr/<email>/.cookie.txt
# Les cookies sont utilisés en priorité pour tous les téléchargements YouTube.
########################################################################
# Source my.sh to get all necessary constants and functions
source "$HOME/.zen/Astroport.ONE/tools/my.sh"

DEBUG=0
if [[ "$1" == "--debug" ]]; then
    DEBUG=1
    shift
fi

LOGFILE="$HOME/.zen/tmp/IA.log"
mkdir -p "$(dirname "$LOGFILE")"

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
    fi
}

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Vérifie si les arguments sont fournis
if [ $# -lt 2 ]; then
    log_debug "Usage: $0 <url> <format> [player_email]"
    echo "Usage: $0 <url> <format> [player_email]" >&2
    exit 1
fi

URL="$1"
FORMAT="$2"
PLAYER_EMAIL="$3"

. "$MY_PATH/../tools/my.sh"

# Create temporary directory
TMP_DIR="$HOME/.zen/tmp/youtube_$(date +%s)"
mkdir -p "$TMP_DIR"

# Always use temporary directory for download
OUTPUT_DIR="$TMP_DIR"
echo "Using temporary directory for download: $OUTPUT_DIR" >&2
log_debug "Using temporary directory for download: $OUTPUT_DIR"

# Check if player email is provided and construct uDRIVE path
UDRIVE_COPY_PATH=""
if [ -n "$PLAYER_EMAIL" ]; then
    UDRIVE_COPY_PATH="$HOME/.zen/game/nostr/$PLAYER_EMAIL/APP/uDRIVE"
    if [ -d "$UDRIVE_COPY_PATH" ]; then
        echo "Will copy final file to uDRIVE: $UDRIVE_COPY_PATH" >&2
        log_debug "Will copy final file to uDRIVE: $UDRIVE_COPY_PATH"
    else
        echo "uDRIVE directory not found for player: $PLAYER_EMAIL" >&2
        log_debug "uDRIVE directory not found for player: $PLAYER_EMAIL"
        UDRIVE_COPY_PATH=""
    fi
fi

# Cleanup function
cleanup() {
    rm -rf "$TMP_DIR"
    [[ -f "$HOME/.zen/tmp/youtube_cookies.txt" ]] && rm -f "$HOME/.zen/tmp/youtube_cookies.txt"
}
trap cleanup EXIT

# Function to send NOSTR notification
send_nostr_notification() {
    local player_email="$1"
    local title="$2"
    local uploader="$3"
    local ipfs_url="$4"
    local youtube_url="$5"
    local metadata_ipfs="$6"
    local thumbnail_ipfs="$7"
    local subtitles_info="$8"
    
    log_debug "Sending NOSTR notification for video: $title"
    
    # Check if NOSTR script exists
    local nostr_script="$MY_PATH/../tools/nostr_send_note.py"
    if [[ ! -f "$nostr_script" ]]; then
        log_debug "NOSTR script not found: $nostr_script"
        return 1
    fi
    
    # Check if player has NOSTR keys in .secret.nostr format
    local secret_file="$HOME/.zen/game/nostr/$player_email/.secret.nostr"
    if [[ ! -f "$secret_file" ]]; then
        log_debug "NOSTR keys file not found for $player_email: $secret_file"
        return 1
    fi
    
    # Source the .secret.nostr file to get NSEC, NPUB, HEX
    source "$secret_file" 2>/dev/null
    
    if [[ -z "$NSEC" ]] || [[ -z "$NPUB" ]]; then
        log_debug "Invalid .secret.nostr file format for $player_email"
        log_debug "Expected format: NSEC=nsec1...; NPUB=npub1...; HEX=..."
        return 1
    fi
    
    local nsec_key="$NSEC"
    
    # Extract video description from metadata if available
    local video_description=""
    if [[ -n "$metadata_ipfs" ]]; then
        # Try to extract description from the metadata JSON file
        local metadata_file=$(find "$OUTPUT_DIR" -name "*.info.json" 2>/dev/null | head -n 1)
        if [[ -n "$metadata_file" && -f "$metadata_file" ]]; then
            video_description=$(jq -r '.description // empty' "$metadata_file" 2>/dev/null | head -c 500)
            if [[ -n "$video_description" && "$video_description" != "null" ]]; then
                # Clean description (remove HTML tags, limit length)
                video_description=$(echo "$video_description" | sed 's/<[^>]*>//g' | sed 's/&nbsp;/ /g' | head -c 300)
            else
                video_description=""
            fi
        fi
    fi
    
    # Generate AI analysis if description is available
    local ai_analysis=""
    if [[ -n "$video_description" && -n "$MY_PATH/../question.py" ]]; then
        log_debug "Generating AI analysis for video: $title"
        local ai_prompt="Analyse cette vidéo YouTube et donne un résumé en 2-3 phrases: Titre: $title, Auteur: $uploader, Description: $video_description"
        ai_analysis=$(python3 "$MY_PATH/../question.py" "$ai_prompt" 2>/dev/null | head -c 200)
        if [[ -n "$ai_analysis" && "$ai_analysis" != "Failed to get answer from Ollama." ]]; then
            log_debug "AI analysis generated: $ai_analysis"
        else
            ai_analysis=""
        fi
    fi
    
    # Build NOSTR message with enhanced metadata
    local message="🎬 Nouvelle vidéo téléchargée: $title par $uploader"

    # Add AI analysis if available
    if [[ -n "$ai_analysis" ]]; then
        message="$message

🤖 Analyse IA: $ai_analysis"
    fi
    
    # Add description if available
    if [[ -n "$video_description" ]]; then
        message="$message

📝 Description: $video_description"
    fi
    
    message="$message

🔗 IPFS: $ipfs_url

--- debug ---"

    # Add metadata links if available
    if [[ -n "$metadata_ipfs" ]]; then
        message="$message
📋 Métadonnées: $myIPFS/ipfs/$metadata_ipfs"
    fi
    
    if [[ -n "$thumbnail_ipfs" ]]; then
        message="$message
🖼️ Miniature: $myIPFS/ipfs/$thumbnail_ipfs"
    fi
    
    # Subtitle handling removed for simplicity
    
    message="$message

#YouTubeDownload #uDRIVE #IPFS"
    
    # Build NOSTR tags optimized for video channels
    local tags_json="[[\"r\",\"$youtube_url\",\"YouTube\"],[\"t\",\"YouTubeDownload\"],[\"t\",\"uDRIVE\"],[\"t\",\"IPFS\"]"
    
    # Add channel-specific tags
    tags_json="$tags_json,[\"t\",\"VideoChannel\"]"
    
    # Add uploader as channel tag for grouping
    if [[ -n "$uploader" && "$uploader" != "null" ]]; then
        local channel_name=$(echo "$uploader" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
        tags_json="$tags_json,[\"t\",\"Channel-$channel_name\"]"
    fi
    
    # Add video category/topic tags (extracted from title)
    local topic_tags=$(echo "$title" | tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-zA-Z0-9 ]//g' | \
        awk '{for(i=1;i<=NF;i++) if(length($i)>3) print $i}' | \
        head -3 | \
        sed 's/^/["t","Topic-/' | sed 's/$/"]/' | \
        tr '\n' ',' | sed 's/,$//')
    
    if [[ -n "$topic_tags" ]]; then
        tags_json="$tags_json,$topic_tags"
    fi
    
    # Add duration tag for filtering
    if [[ -n "$duration" && "$duration" =~ ^[0-9]+$ ]]; then
        local duration_min=$((duration / 60))
        if [[ $duration_min -lt 5 ]]; then
            tags_json="$tags_json,[\"t\",\"Duration-Short\"]"
        elif [[ $duration_min -lt 30 ]]; then
            tags_json="$tags_json,[\"t\",\"Duration-Medium\"]"
        else
            tags_json="$tags_json,[\"t\",\"Duration-Long\"]"
        fi
    fi
    
    # Add AI analysis tag if available
    if [[ -n "$ai_analysis" ]]; then
        tags_json="$tags_json,[\"t\",\"AI-Analysis\"]"
    fi
    
    # Add description tag if available
    if [[ -n "$video_description" ]]; then
        tags_json="$tags_json,[\"t\",\"Description\"]"
    fi
    
    # Subtitle handling removed for simplicity
    
    # Add main video IPFS URL as primary 'r' tag
    if [[ -n "$ipfs_url" ]]; then
        tags_json="$tags_json,[\"r\",\"$ipfs_url\",\"Video\"]"
    fi
    
    # Add metadata tags if available
    if [[ -n "$metadata_ipfs" ]]; then
        tags_json="$tags_json,[\"r\",\"/ipfs/$metadata_ipfs\",\"Metadata\"]"
    fi
    
    if [[ -n "$thumbnail_ipfs" ]]; then
        tags_json="$tags_json,[\"r\",\"/ipfs/$thumbnail_ipfs\",\"Thumbnail\"]"
    fi
    
    # Add duration and file size as custom tags
    if [[ -n "$duration" && "$duration" =~ ^[0-9]+$ ]]; then
        tags_json="$tags_json,[\"t\",\"Duration-$duration\"]"
    fi
    
    # Add file size tag (get from the actual downloaded file)
    if [[ -n "$media_file" && -f "$media_file" ]]; then
        local file_size=$(stat -c%s "$media_file" 2>/dev/null || echo "0")
        if [[ "$file_size" =~ ^[0-9]+$ && "$file_size" -gt 0 ]]; then
            tags_json="$tags_json,[\"t\",\"FileSize-$file_size\"]"
        fi
    fi
    
    tags_json="$tags_json]"
    
    # Send NOSTR note with tags (kind: 1 for compatibility)
    echo "📡 Sending NOSTR notification (kind: 1) for: $title" >&2
    local nostr_result=$(python3 "$nostr_script" "$nsec_key" "$message" "ws://127.0.0.1:7777" "$tags_json" 2>&1)
    local nostr_exit_code=$?
    
    if [[ $nostr_exit_code -eq 0 ]]; then
        log_debug "NOSTR notification (kind: 1) sent successfully for: $title"
        echo "✅ NOSTR notification (kind: 1) published for: $title"
        
    # Determine video kind based on dimensions and duration
    local video_kind=$(determine_video_kind "$duration" "$video_dimensions")
    echo "📡 Sending NIP-71 video event (kind: $video_kind) for: $title" >&2
    send_nip71_video_event "$nsec_key" "$title" "$uploader" "$ipfs_url" "$youtube_url" "$metadata_ipfs" "$thumbnail_ipfs" "$duration" "$file_size" "$media_file" "$video_kind"
        
        return 0
    else
        log_debug "Failed to send NOSTR notification for: $title (exit code: $nostr_exit_code)"
        echo "⚠️ NOSTR notification failed for: $title"
        return 1
    fi
}

# Function to determine video kind based on duration and dimensions
determine_video_kind() {
    local duration="$1"
    local dimensions="$2"
    
    log_debug "Determining video kind for duration: ${duration}s, dimensions: ${dimensions}"
    
    # Extract width and height from dimensions (format: WIDTHxHEIGHT)
    local width=$(echo "$dimensions" | cut -d'x' -f1)
    local height=$(echo "$dimensions" | cut -d'x' -f2)
    
    # Default to kind 21 if we can't parse dimensions
    if [[ ! "$width" =~ ^[0-9]+$ ]] || [[ ! "$height" =~ ^[0-9]+$ ]]; then
        log_debug "Invalid dimensions format, defaulting to kind 21"
        echo "21"
        return
    fi
    
    # Calculate aspect ratio
    local aspect_ratio=$(echo "scale=2; $width / $height" | bc -l 2>/dev/null || echo "1.78")
    
    # Determine if it's a short video based on:
    # 1. Vertical aspect ratio (height > width) regardless of duration
    # 2. Square aspect ratio regardless of duration  
    # 3. Small dimensions (<= 720p) regardless of duration
    # 4. Duration <= 30 seconds for horizontal videos (more strict)
    
    local is_short_duration=false
    local is_short_format=false
    
    # Check duration (30 seconds or less for horizontal videos)
    if [[ "$duration" -le 30 ]]; then
        is_short_duration=true
        log_debug "Short duration detected: ${duration}s <= 30s"
    fi
    
    # Check aspect ratio and dimensions
    if (( height > width )); then
        # Vertical video (portrait) - always short format
        is_short_format=true
        log_debug "Vertical video detected: ${width}x${height}"
    elif (( width == height )); then
        # Square video - always short format
        is_short_format=true
        log_debug "Square video detected: ${width}x${height}"
    elif (( width <= 720 && height <= 720 )); then
        # Small dimensions (likely short)
        is_short_format=true
        log_debug "Small dimensions detected: ${width}x${height}"
    fi
    
    # Determine kind with improved logic
    if [[ "$is_short_format" == true ]]; then
        # Format-based classification (vertical, square, small) - always short
        log_debug "Classified as short video (kind 22) - format-based"
        echo "22"
    elif [[ "$is_short_duration" == true ]]; then
        # Duration-based classification (<= 60s) but only for horizontal videos
        log_debug "Classified as short video (kind 22) - duration-based"
        echo "22"
    else
        log_debug "Classified as regular video (kind 21)"
        echo "21"
    fi
}

# Function to send NIP-71 video event
send_nip71_video_event() {
    local nsec_key="$1"
    local title="$2"
    local uploader="$3"
    local ipfs_url="$4"
    local youtube_url="$5"
    local metadata_ipfs="$6"
    local thumbnail_ipfs="$7"
    local duration="$8"
    local file_size="$9"
    local media_file="${10}"
    local video_kind="${11}"
    
    log_debug "Sending NIP-71 video event for: $title"
    
    # Check if NOSTR script exists
    local nostr_script="$MY_PATH/../tools/nostr_send_note.py"
    if [[ ! -f "$nostr_script" ]]; then
        log_debug "NOSTR script not found: $nostr_script"
        return 1
    fi
    
    # Create NIP-71 video event content
    local video_content="🎬 $title
    
📺 YouTube: $youtube_url
🔗 IPFS: $ipfs_url"

    # Add metadata if available
    if [[ -n "$metadata_ipfs" ]]; then
        video_content="$video_content
📋 Métadonnées: $myIPFS/ipfs/$metadata_ipfs"
    fi
    
    if [[ -n "$thumbnail_ipfs" ]]; then
        video_content="$video_content
🖼️ Miniature: $myIPFS/ipfs/$thumbnail_ipfs"
    fi
    
    # Build NIP-71 specific tags
    local nip71_tags="[[\"url\",\"$ipfs_url\"],[\"m\",\"video/mp4\"],[\"x\",\"$(echo -n "$ipfs_url" | sha256sum | cut -d' ' -f1)\"]]"
    
    # Add file size if available
    if [[ -n "$file_size" && "$file_size" -gt 0 ]]; then
        nip71_tags="$nip71_tags,[\"size\",\"$file_size\"]"
    fi
    
    # Add duration if available
    if [[ -n "$duration" && "$duration" -gt 0 ]]; then
        nip71_tags="$nip71_tags,[\"duration\",\"$duration\"]"
    fi
    
    # Extract real video dimensions using ffprobe
    local video_dimensions="1920x1080"  # Default fallback
    if [[ -n "$media_file" && -f "$media_file" ]]; then
        log_debug "Extracting video dimensions from: $media_file"
        local dimensions_output=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$media_file" 2>/dev/null)
        if [[ -n "$dimensions_output" && "$dimensions_output" =~ ^[0-9]+x[0-9]+$ ]]; then
            video_dimensions="$dimensions_output"
            log_debug "Extracted video dimensions: $video_dimensions"
        else
            log_debug "Could not extract dimensions, using default: $video_dimensions"
        fi
    fi
    nip71_tags="$nip71_tags,[\"dim\",\"$video_dimensions\"]"
    
    # Add channel and topic tags
    nip71_tags="$nip71_tags,[\"t\",\"YouTubeDownload\"],[\"t\",\"VideoChannel\"]"
    
    # Add channel-specific tag
    if [[ -n "$uploader" && "$uploader" != "null" ]]; then
        local channel_name=$(echo "$uploader" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
        nip71_tags="$nip71_tags,[\"t\",\"Channel-$channel_name\"]"
    fi
    
    # Add topic tags from title
    local topic_tags=$(echo "$title" | tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-zA-Z0-9 ]//g' | \
        awk '{for(i=1;i<=NF;i++) if(length($i)>3) print $i}' | \
        head -3 | \
        sed 's/^/["t","Topic-/' | sed 's/$/"]/' | \
        tr '\n' ',' | sed 's/,$//')
    
    if [[ -n "$topic_tags" ]]; then
        nip71_tags="$nip71_tags,$topic_tags"
    fi
    
    nip71_tags="$nip71_tags]"
    
    # Send NIP-71 video event (kind: 21 or 22)
    echo "📡 Sending NIP-71 video event (kind: $video_kind) for: $title" >&2
    local nip71_result=$(python3 "$nostr_script" "$nsec_key" "$video_content" "ws://127.0.0.1:7777" "$nip71_tags" "$video_kind" 2>&1)
    local nip71_exit_code=$?
    
    if [[ $nip71_exit_code -eq 0 ]]; then
        log_debug "NIP-71 video event sent successfully for: $title"
        echo "✅ NIP-71 video event published for: $title"
        return 0
    else
        log_debug "Failed to send NIP-71 video event for: $title (exit code: $nip71_exit_code)"
        echo "⚠️ NIP-71 video event failed for: $title"
        return 1
    fi
}

find_user_cookie_file() {
    # Search for .cookie.txt in user NOSTR directories
    local nostr_dir="$HOME/.zen/game/nostr"
    log_debug "Searching for user cookie files in: $nostr_dir"
    if [[ -d "$nostr_dir" ]]; then
        for user_dir in "$nostr_dir"/*@*; do
            if [[ -f "$user_dir/.cookie.txt" ]]; then
                log_debug "✓ Found user cookie file: $user_dir/.cookie.txt"
                local cookie_age=$(($(date +%s) - $(stat -c %Y "$user_dir/.cookie.txt" 2>/dev/null || echo 0)))
                log_debug "  Cookie file age: $((cookie_age / 86400)) days old"
                echo "--cookies $user_dir/.cookie.txt"
                return 0
            fi
        done
    fi
    log_debug "✗ No user cookie file found"
    return 1
}

get_youtube_cookies() {
    local cookie_file="$HOME/.zen/tmp/youtube_cookies.txt"
    local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    log_debug "Attempting to generate YouTube cookies..."
    mkdir -p "$(dirname "$cookie_file")"
    cat > "$cookie_file" << EOF
# Netscape HTTP Cookie File
# https://www.youtube.com
.youtube.com	TRUE	/	TRUE	2147483647	CONSENT	YES+cb.$(date +%Y%m%d)-14-p0.en+FX+$(openssl rand -hex 8)
.youtube.com	TRUE	/	TRUE	2147483647	VISITOR_INFO1_LIVE	$(openssl rand -hex 16)
.youtube.com	TRUE	/	TRUE	2147483647	YSC	$(openssl rand -hex 16)
.youtube.com	TRUE	/	FALSE	2147483647	PREF	f4=4000000&tz=Europe.Paris&f5=30000&f6=8
.youtube.com	TRUE	/	TRUE	2147483647	GPS	1
EOF
    local strategies=(
        "https://www.youtube.com/"
        "https://consent.youtube.com/"
        "https://www.youtube.com/robots.txt"
    )
    for strategy_url in "${strategies[@]}"; do
        log_debug "Trying cookie strategy: $strategy_url"
        curl -s -L --max-time 10 \
            -A "$user_agent" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8" \
            -H "Accept-Language: en-US,en;q=0.5" \
            -H "Accept-Encoding: gzip, deflate, br" \
            -H "DNT: 1" \
            -H "Connection: keep-alive" \
            -H "Upgrade-Insecure-Requests: 1" \
            -H "Sec-Fetch-Dest: document" \
            -H "Sec-Fetch-Mode: navigate" \
            -H "Sec-Fetch-Site: none" \
            -H "Sec-Fetch-User: ?1" \
            -H "Pragma: no-cache" \
            -H "Cache-Control: no-cache" \
            -b "$cookie_file" \
            -c "$cookie_file" \
            "$strategy_url" > /dev/null 2>&1
        if grep -q "CONSENT" "$cookie_file" && [[ $(wc -l < "$cookie_file") -gt 5 ]]; then
            log_debug "Successfully obtained cookies from: $strategy_url"
            break
        fi
    done
    if [[ -f "$cookie_file" ]] && grep -q "CONSENT" "$cookie_file"; then
        log_debug "Cookie file created successfully: $cookie_file"
        echo "--cookies $cookie_file"
    else
        log_debug "Failed to create valid cookie file"
        rm -f "$cookie_file"
        echo ""
    fi
}

process_youtube() {
    local url="$1"
    local media_type="$2"
    local temp_dir="$3"
    local browser_cookies=""
    local media_file=""
    local media_ipfs=""
    local line=""
    local yid media_title duration uploader
    local filename ipfs_url
    local user_cookie=""
    log_debug "=========================================="
    log_debug "START YouTube Processing"
    log_debug "URL: $url"
    log_debug "Format: $media_type"
    log_debug "Temp dir: $temp_dir"
    log_debug "=========================================="
    
    # 0. First, try to use user's uploaded cookie file if available
    log_debug "STEP 1: Checking for user-uploaded cookie file..."
    user_cookie=$(find_user_cookie_file)
    if [[ -n "$user_cookie" ]]; then
        log_debug "✓ Using user's uploaded cookie file"
        browser_cookies="$user_cookie"
        log_debug "Attempting metadata extraction with user cookies..."
        line="$(yt-dlp $browser_cookies --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$url" 2>> "$LOGFILE")"
        local exit_code=$?
        log_debug "yt-dlp exit code: $exit_code"
        log_debug "yt-dlp output (user cookies): $line"
    else
        log_debug "✗ No user cookie file available"
    fi
    
    # 1. Try to extract metadata without cookies (if not already done with user cookies)
    if [[ -z "$line" ]]; then
        log_debug "STEP 2: Trying yt-dlp metadata extraction without cookies..."
        line="$(yt-dlp --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$url" 2>> "$LOGFILE")"
        local exit_code=$?
        log_debug "yt-dlp exit code: $exit_code"
        log_debug "yt-dlp output (no cookies): $line"
    fi
    
    if [[ $? -ne 0 || -z "$line" ]]; then
        # Try browser cookies if user cookies didn't work
        if [[ -z "$user_cookie" ]]; then
            log_debug "STEP 3: Trying browser cookies..."
            browser_pref=$(xdg-settings get default-web-browser 2>/dev/null | cut -d'.' -f1 | tr 'A-Z' 'a-z')
            log_debug "Default browser detected: $browser_pref"
            case "$browser_pref" in
                chromium|chrome) browser_cookies="--cookies-from-browser chrome" ;;
                firefox) browser_cookies="--cookies-from-browser firefox" ;;
                brave) browser_cookies="--cookies-from-browser brave" ;;
                edge) browser_cookies="--cookies-from-browser edge" ;;
                *) browser_cookies="" ;;
            esac
            if [[ -n "$browser_cookies" ]]; then
                log_debug "Attempting metadata extraction with: $browser_cookies"
                line="$(yt-dlp $browser_cookies --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$url" 2>> "$LOGFILE")"
                local exit_code=$?
                log_debug "yt-dlp exit code: $exit_code"
                log_debug "yt-dlp output (browser cookies): $line"
            else
                log_debug "No browser cookies strategy available"
            fi
        fi
        if [[ $? -ne 0 || -z "$line" ]]; then
            # Generate temporary cookies as last resort
            log_debug "STEP 4: Generating temporary cookies as last resort..."
            browser_cookies=$(get_youtube_cookies)
            if [[ -n "$browser_cookies" ]]; then
                log_debug "Attempting metadata extraction with generated cookies"
                line="$(yt-dlp $browser_cookies --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$url" 2>> "$LOGFILE")"
                local exit_code=$?
                log_debug "yt-dlp exit code: $exit_code"
                log_debug "yt-dlp output (generated cookies): $line"
            else
                log_debug "Failed to generate cookies"
            fi
        fi
    fi
    # Extract fields more safely
    yid=$(echo "$line" | cut -d '&' -f 1)
    raw_title=$(echo "$line" | cut -d '&' -f 2)
    duration=$(echo "$line" | cut -d '&' -f 3)
    uploader=$(echo "$line" | cut -d '&' -f 4)
    
    # Clean title safely and make it URL-compatible
    if [[ -n "$raw_title" ]]; then
        # First detox to remove special characters, then make URL-compatible
        media_title=$(echo "$raw_title" | detox --inline | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g')
        # Limit length to avoid filesystem issues
        media_title=$(echo "$media_title" | head -c 100)
    else
        media_title="media-$(date +%s)"
    fi
    
    # Debug the extracted values
    log_debug "Extracted fields:"
    log_debug "  yid: '$yid'"
    log_debug "  raw_title: '$raw_title'"
    log_debug "  media_title: '$media_title'"
    log_debug "  duration: '$duration'"
    log_debug "  uploader: '$uploader'"
    
    # Validate field separation - check if duration contains non-numeric characters
    if [[ -n "$duration" && ! "$duration" =~ ^[0-9]+$ ]]; then
        log_debug "Warning: Duration field may be corrupted: '$duration'"
        log_debug "Raw line was: '$line'"
        # Try to re-extract with different approach
        if [[ "$line" =~ ^([^&]+)\&(.+)\&([0-9]+)\&(.+)$ ]]; then
            yid="${BASH_REMATCH[1]}"
            raw_title="${BASH_REMATCH[2]}"
            duration="${BASH_REMATCH[3]}"
            uploader="${BASH_REMATCH[4]}"
            log_debug "Re-extracted with regex: yid='$yid', title='$raw_title', duration='$duration', uploader='$uploader'"
            if [[ -n "$raw_title" ]]; then
                # Make URL-compatible
                media_title=$(echo "$raw_title" | detox --inline | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g' | head -c 100)
            else
                media_title="media-$(date +%s)"
            fi
        fi
    fi
    # If we still don't have a valid title or id, try to extract from YouTube page JSON
    if [[ -z "$yid" || -z "$media_title" || "$media_title" == "media-$(date +%s)" ]]; then
        log_debug "yt-dlp metadata extraction failed, trying to extract from YouTube page JSON..."
        page_html=$(curl -sL "$url")
        player_json=$(echo "$page_html" | grep -oP 'var ytInitialPlayerResponse = \\K\\{.*?\\}(?=;)' | head -n1)
        if [[ -n "$player_json" ]]; then
            title=$(echo "$player_json" | jq -r '.videoDetails.title // empty' 2>/dev/null)
            uploader=$(echo "$player_json" | jq -r '.videoDetails.author // empty' 2>/dev/null)
            yid=$(echo "$player_json" | jq -r '.videoDetails.videoId // empty' 2>/dev/null)
            duration=$(echo "$player_json" | jq -r '.videoDetails.lengthSeconds // empty' 2>/dev/null)
            log_debug "Extracted from page: title=$title, uploader=$uploader, yid=$yid, duration=$duration"
            if [[ -n "$title" && -n "$yid" ]]; then
                [[ -z "$title" ]] && title=null || title="\"$title\""
                [[ -z "$uploader" ]] && uploader=null || uploader="\"$uploader\""
                [[ -z "$duration" ]] && duration=null || duration="\"$duration\""
                [[ -z "$url" ]] && original_url=null || original_url="\"$url\""
                cat << EOF
{
  "ipfs_url": null,
  "title": $title,
  "duration": $duration,
  "uploader": $uploader,
  "original_url": $original_url,
  "filename": null,
  "error": "Download not possible, but metadata extracted from YouTube page."
}
EOF
                log_debug "Fallback JSON outputted."
                exit 0
            fi
        fi
        log_debug "Failed to extract video metadata from YouTube page."
        echo '{"error":"❌ YouTube authentication failed. Please export fresh cookies from your browser.\n\n📖 Guide: https://ipfs.copylaradio.com/ipns/copylaradio.com/cookie.html\n\n💡 Upload your cookies.txt file via https://u.copylaradio.com/astro"}'
        exit 1
    fi
    # Set max duration to 3h (10800s) for both mp3 and mp4
    if [[ -n "$duration" ]]; then
        # Validate that duration is a number
        if [[ "$duration" =~ ^[0-9]+$ ]]; then
            if [ "$duration" -gt 10800 ]; then
                log_debug "Media duration exceeds 3 hour limit: ${duration}s"
                echo '{"error":"Media duration exceeds 3 hour limit"}'
                return 1
            fi
            log_debug "Duration validation passed: ${duration}s"
        else
            log_debug "Warning: Invalid duration format: '$duration' (not a number)"
            # Don't fail, just log the warning and continue
        fi
    else
        log_debug "No duration information available"
    fi
    # Download according to type, using the last successful browser_cookies (may be empty)
    log_debug "Starting download: $media_type, browser_cookies='$browser_cookies'"
    case "$media_type" in
        mp3)
            yt-dlp $browser_cookies -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail \
                --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$url" >&2 2>> "$LOGFILE"
            ;;
        mp4)
            yt-dlp $browser_cookies -f "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best" \
                --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail \
                --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$url" >&2 2>> "$LOGFILE"
            ;;
    esac
    # Find the actual media file (video/audio, not metadata files)
    media_file=$(ls "$OUTPUT_DIR"/${media_title}.{mp4,mp3,m4a,webm,mkv} 2>/dev/null | head -n 1)
    if [[ -z "$media_file" ]]; then
        # Fallback: look for any file that's not metadata
        media_file=$(ls "$OUTPUT_DIR"/${media_title}.* 2>/dev/null | grep -v -E '\.(info\.json|vtt|srt|jpg|jpeg|png|webp)$' | head -n 1)
    fi
    filename=$(basename "$media_file")
    log_debug "Downloaded file: $media_file"
    
    # Find metadata files
    info_json_file=$(ls "$OUTPUT_DIR"/${media_title}.info.json 2>/dev/null | head -n 1)
    thumbnail_file=$(ls "$OUTPUT_DIR"/${media_title}.* 2>/dev/null | grep -E '\.(jpg|jpeg|png|webp)$' | head -n 1)
    
    # Subtitle handling removed for simplicity
    
    if [[ -n "$media_file" && -f "$media_file" ]]; then
        # Verify it's actually a media file (not just metadata)
        local file_size=$(stat -c%s "$media_file" 2>/dev/null || echo "0")
        if [[ $file_size -lt 100000 ]]; then  # Less than 100KB is likely not a real video
            log_debug "File too small ($file_size bytes), likely not a real video: $media_file"
            echo '{"error":"❌ Downloaded file is too small, likely not a real video.\n\n💡 This might be due to:\n• YouTube blocking video downloads\n• Expired cookies\n• Network issues\n\n📖 Cookie Guide: https://ipfs.copylaradio.com/ipns/copylaradio.com/cookie.html\n💾 Upload cookies: https://u.copylaradio.com/astro"}'
            return 1
        fi
        
        # Add main media file to IPFS
        media_ipfs=$(ipfs add -wq "$media_file" 2>> "$LOGFILE" | tail -n 1)
        log_debug "IPFS add result: $media_ipfs"
        
        # Add metadata files to IPFS if they exist
        local metadata_ipfs=""
        if [[ -n "$info_json_file" ]]; then
            metadata_ipfs=$(ipfs add -q "$info_json_file" 2>> "$LOGFILE" | tail -n 1)
            log_debug "Metadata IPFS: $metadata_ipfs"
        fi
        
        # Add thumbnail to IPFS if it exists
        local thumbnail_ipfs=""
        if [[ -n "$thumbnail_file" ]]; then
            thumbnail_ipfs=$(ipfs add -q "$thumbnail_file" 2>> "$LOGFILE" | tail -n 1)
            log_debug "Thumbnail IPFS: $thumbnail_ipfs"
        fi
        
        # Subtitle handling removed for simplicity
        
        if [[ -n "$media_ipfs" ]]; then
            # Utiliser seulement le CID IPFS pur pour plus de flexibilité
            ipfs_url="/ipfs/$media_ipfs/$filename"
            echo "Media saved to: $media_file" >&2
            log_debug "Media saved to: $media_file"
            
            # Copy to uDRIVE if path provided
            if [[ -n "$UDRIVE_COPY_PATH" ]]; then
                # Determine target directory based on format
                if [[ "$media_type" == "mp3" ]]; then
                    # Extract artist from uploader or title
                    artist=$(echo "$uploader" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
                    if [[ -z "$artist" || "$artist" == "null" ]]; then
                        artist="Unknown_Artist"
                    fi
                    
                    # Create Music/Artist directory
                    music_dir="$UDRIVE_COPY_PATH/Music/$artist"
                    mkdir -p "$music_dir"
                    udrive_file="$music_dir/$filename"
                    
                    echo "Organizing MP3 in Music/$artist/" >&2
                    log_debug "Organizing MP3 in Music/$artist/"
                else
                    # For MP4 videos, use Videos directory
                    videos_dir="$UDRIVE_COPY_PATH/Videos"
                    mkdir -p "$videos_dir"
                    udrive_file="$videos_dir/$filename"
                    
                    echo "Organizing MP4 in Videos/" >&2
                    log_debug "Organizing MP4 in Videos/"
                fi
                
                if cp "$media_file" "$udrive_file"; then
                    echo "File copied to uDRIVE: $udrive_file" >&2
                    log_debug "File copied to uDRIVE: $udrive_file"
                else
                    echo "Warning: Failed to copy file to uDRIVE: $udrive_file" >&2
                    log_debug "Warning: Failed to copy file to uDRIVE: $udrive_file"
                fi
            fi
            
            # Send NOSTR notification if player email is provided
            if [[ -n "$PLAYER_EMAIL" ]]; then
                send_nostr_notification "$PLAYER_EMAIL" "$media_title" "$uploader" "$ipfs_url" "$url" "$metadata_ipfs" "$thumbnail_ipfs" ""
            fi
            
            # Generate channel-friendly JSON with enhanced metadata
            local channel_name=$(echo "$uploader" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
            # Example: For a video titled "How to Build a Blockchain in Python Tutorial"
            # topic_keywords would be: "build,blockchain,python,tutorial"
            local topic_keywords=$(echo "$raw_title" | tr '[:upper:]' '[:lower:]' | \
                sed 's/[^a-zA-Z0-9 ]//g' | \
                awk '{for(i=1;i<=NF;i++) if(length($i)>3) print $i}' | \
                head -5 | paste -sd,)
            # Subtitle handling removed for simplicity
            local subtitles_json="[]"
            
            cat << EOF
{
  "ipfs_url": "$ipfs_url",
  "title": "$media_title",
  "duration": "$duration",
  "uploader": "$uploader",
  "original_url": "$url",
  "filename": "$filename",
  "metadata_ipfs": "$metadata_ipfs",
  "thumbnail_ipfs": "$thumbnail_ipfs",
  "subtitles": $subtitles_json,
  "channel_info": {
    "name": "$channel_name",
    "display_name": "$uploader",
    "type": "youtube"
  },
  "content_info": {
    "description": "$video_description",
    "ai_analysis": "$ai_analysis",
    "topic_keywords": "$topic_keywords",
    "duration_category": "$(if [[ -n "$duration" && "$duration" =~ ^[0-9]+$ ]]; then duration_min=$((duration / 60)); if [[ $duration_min -lt 5 ]]; then echo "short"; elif [[ $duration_min -lt 30 ]]; then echo "medium"; else echo "long"; fi; fi)"
  },
  "technical_info": {
    "format": "$media_type",
    "file_size": "$(stat -c%s "$media_file" 2>/dev/null || echo "unknown")",
    "download_date": "$(date -Iseconds)"
  }
}
EOF
            log_debug "Success JSON outputted."
            return 0
        fi
    fi
    log_debug "Download or IPFS add failed."
    echo '{"error":"❌ Download or IPFS upload failed.\n\n💡 This might be due to:\n• Expired YouTube cookies\n• Bot detection by YouTube\n• Network issues\n\n📖 Cookie Guide: https://ipfs.copylaradio.com/ipns/copylaradio.com/cookie.html\n💾 Upload cookies: https://u.copylaradio.com/astro"}'
    return 1
}

# Main execution
process_youtube "$URL" "$FORMAT" "$TMP_DIR" 