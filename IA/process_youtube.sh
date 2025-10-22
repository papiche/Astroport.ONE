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
    
    # Build NOSTR message
    local message="🎬 Nouvelle vidéo téléchargée: $title par $uploader

🔗 IPFS: $ipfs_url
📺 YouTube: $youtube_url

#YouTubeDownload #uDRIVE #IPFS"
    
    # Send NOSTR note
    echo "📡 Sending NOSTR notification for: $title" >&2
    local nostr_result=$(python3 "$nostr_script" "$nsec_key" "$message" "ws://127.0.0.1:7777" 2>&1)
    local nostr_exit_code=$?
    
    if [[ $nostr_exit_code -eq 0 ]]; then
        log_debug "NOSTR notification sent successfully for: $title"
        echo "✅ NOSTR notification published for: $title"
        return 0
    else
        log_debug "Failed to send NOSTR notification for: $title (exit code: $nostr_exit_code)"
        echo "⚠️ NOSTR notification failed for: $title"
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
    
    # Clean title safely
    if [[ -n "$raw_title" ]]; then
        media_title=$(echo "$raw_title" | detox --inline)
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
                media_title=$(echo "$raw_title" | detox --inline)
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
                -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$url" >&2 2>> "$LOGFILE"
            ;;
        mp4)
            yt-dlp $browser_cookies -f "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best" \
                --no-mtime --embed-thumbnail --add-metadata \
                -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$url" >&2 2>> "$LOGFILE"
            ;;
    esac
    media_file=$(ls "$OUTPUT_DIR"/${media_title}.* 2>/dev/null | head -n 1)
    filename=$(basename "$media_file")
    log_debug "Downloaded file: $media_file"
    if [[ -n "$media_file" ]]; then
        media_ipfs=$(ipfs add -wq "$media_file" 2>> "$LOGFILE" | tail -n 1)
        log_debug "IPFS add result: $media_ipfs"
        if [[ -n "$media_ipfs" ]]; then
            ipfs_url="$myIPFS/ipfs/$media_ipfs/$filename"
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
                send_nostr_notification "$PLAYER_EMAIL" "$media_title" "$uploader" "$ipfs_url" "$url"
            fi
            
            cat << EOF
{
  "ipfs_url": "$ipfs_url",
  "title": "$media_title",
  "duration": "$duration",
  "uploader": "$uploader",
  "original_url": "$url",
  "filename": "$filename"
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