#!/bin/bash
########################################################################
# process_youtube.sh
# Script de téléchargement et traitement des vidéos YouTube
#
# Usage: $0 [--debug] <url> <format>
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
# Les autres .txt sont placés normalement dans uDRIVE/Documents
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
    log_debug "Usage: $0 <url> <format>"
    echo "Usage: $0 <url> <format>" >&2
    exit 1
fi

URL="$1"
FORMAT="$2"

. "$MY_PATH/../tools/my.sh"

# Create temporary directory
TMP_DIR="$HOME/.zen/tmp/youtube_$(date +%s)"
mkdir -p "$TMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TMP_DIR"
    [[ -f "$HOME/.zen/tmp/youtube_cookies.txt" ]] && rm -f "$HOME/.zen/tmp/youtube_cookies.txt"
}
trap cleanup EXIT

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
    yid=$(echo "$line" | cut -d '&' -f 1)
    media_title=$(echo "$line" | cut -d '&' -f 2 | detox --inline)
    duration=$(echo "$line" | cut -d '&' -f 3)
    uploader=$(echo "$line" | cut -d '&' -f 4)
    [[ -z "$media_title" ]] && media_title="media-$(date +%s)"
    # If we still don't have a valid title or id, try to extract from YouTube page JSON
    if [[ -z "$yid" || -z "$media_title" ]]; then
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
                echo '{'
                echo '  "ipfs_url": null,'
                echo '  "title": '$title','
                echo '  "duration": '$duration','
                echo '  "uploader": '$uploader','
                echo '  "original_url": '$original_url','
                echo '  "filename": null,'
                echo '  "error": "Download not possible, but metadata extracted from YouTube page."'
                echo '}'
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
        if [ "$duration" -gt 10800 ]; then
            log_debug "Media duration exceeds 3 hour limit."
            echo '{"error":"Media duration exceeds 3 hour limit"}'
            return 1
        fi
    fi
    # Download according to type, using the last successful browser_cookies (may be empty)
    log_debug "Starting download: $media_type, browser_cookies='$browser_cookies'"
    case "$media_type" in
        mp3)
            yt-dlp $browser_cookies -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url" 2>> "$LOGFILE"
            ;;
        mp4)
            yt-dlp $browser_cookies -f "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best" \
                --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url" 2>> "$LOGFILE"
            ;;
    esac
    media_file=$(ls "$temp_dir"/${media_title}.* 2>/dev/null | head -n 1)
    filename=$(basename "$media_file")
    log_debug "Downloaded file: $media_file"
    if [[ -n "$media_file" ]]; then
        media_ipfs=$(ipfs add -wq "$media_file" 2>> "$LOGFILE" | tail -n 1)
        log_debug "IPFS add result: $media_ipfs"
        if [[ -n "$media_ipfs" ]]; then
            ipfs_url="$myIPFS/ipfs/$media_ipfs/$filename"
            echo '{'
            echo '  "ipfs_url": '"\"$ipfs_url\"",'
            echo '  "title": '"\"$media_title\"",'
            echo '  "duration": '"\"$duration\"",'
            echo '  "uploader": '"\"$uploader\"",'
            echo '  "original_url": '"\"$url\"",'
            echo '  "filename": '"\"$filename\""'
            echo '}'
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