#!/bin/bash
###################################################################
# process_youtube.sh
# Script de téléchargement et traitement des vidéos YouTube
#
# Usage: $0 <url> <format>
#
# Fonctionnalités:
# - Téléchargement de vidéos YouTube avec yt-dlp
# - Support des formats MP3 et MP4
# - Gestion automatique des cookies de navigateurs
# - Fallback sur génération de cookies avec curl
# - Upload automatique vers IPFS
# - Limitations de durée (1h pour MP3, 15min pour MP4)
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Vérifie si les arguments sont fournis
if [ $# -lt 2 ]; then
    echo "Usage: $0 <url> <format>" >&2
    echo "  url: URL YouTube à télécharger" >&2
    echo "  format: Format de sortie (mp3 ou mp4)" >&2
    exit 1
fi

URL="$1"
FORMAT="$2"

. "${MY_PATH}/../tools/my.sh"

# Create temporary directory
TMP_DIR="$HOME/.zen/tmp/youtube_$(date +%s)"
mkdir -p "$TMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TMP_DIR"
    # Cleanup cookie file if it exists
    [[ -f "$HOME/.zen/tmp/youtube_cookies.txt" ]] && rm -f "$HOME/.zen/tmp/youtube_cookies.txt"
}
trap cleanup EXIT

# Function to get YouTube cookies
get_youtube_cookies() {
    local cookie_file="$HOME/.zen/tmp/youtube_cookies.txt"
    local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

    echo "Attempting to generate YouTube cookies..." >&2
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$cookie_file")"
    
    # Create cookie file with initial consent cookie
    cat > "$cookie_file" << EOF
# Netscape HTTP Cookie File
# https://www.youtube.com
.youtube.com	TRUE	/	TRUE	2147483647	CONSENT	YES+cb.$(date +%Y%m%d)-14-p0.en+FX+$(openssl rand -hex 8)
.youtube.com	TRUE	/	TRUE	2147483647	VISITOR_INFO1_LIVE	$(openssl rand -hex 16)
.youtube.com	TRUE	/	TRUE	2147483647	YSC	$(openssl rand -hex 16)
.youtube.com	TRUE	/	FALSE	2147483647	PREF	f4=4000000&tz=Europe.Paris&f5=30000&f6=8
.youtube.com	TRUE	/	TRUE	2147483647	GPS	1
EOF

    # Try to get additional cookies with multiple strategies
    local strategies=(
        "https://www.youtube.com/"
        "https://consent.youtube.com/"
        "https://www.youtube.com/robots.txt"
    )
    
    for strategy_url in "${strategies[@]}"; do
        echo "Trying cookie strategy: $strategy_url" >&2
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
        
        # Check if we got valid cookies
        if grep -q "CONSENT" "$cookie_file" && [[ $(wc -l < "$cookie_file") -gt 5 ]]; then
            echo "Successfully obtained cookies from: $strategy_url" >&2
            break
        fi
    done

    # Verify cookie file validity
    if [[ -f "$cookie_file" ]] && grep -q "CONSENT" "$cookie_file"; then
        echo "Cookie file created successfully: $cookie_file" >&2
        echo "--cookies $cookie_file"
    else
        echo "Failed to create valid cookie file" >&2
        rm -f "$cookie_file"
        echo ""
    fi
}

# Fonction pour télécharger et traiter les médias
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

    # 1. Try to extract metadata without cookies
    line="$(yt-dlp --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$url" 2>> ~/.zen/tmp/IA.log)"
    if [[ $? -ne 0 || -z "$line" ]]; then
        # 2. Try with preferred browser cookies
        browser_pref=$(xdg-settings get default-web-browser 2>/dev/null | cut -d'.' -f1 | tr 'A-Z' 'a-z')
        case "$browser_pref" in
            chromium|chrome) browser_cookies="--cookies-from-browser chrome" ;;
            firefox) browser_cookies="--cookies-from-browser firefox" ;;
            brave) browser_cookies="--cookies-from-browser brave" ;;
            edge) browser_cookies="--cookies-from-browser edge" ;;
            *) browser_cookies="" ;;
        esac
        if [[ -n "$browser_cookies" ]]; then
            line="$(yt-dlp $browser_cookies --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$url" 2>> ~/.zen/tmp/IA.log)"
        fi
        # 3. Try with generated cookies if still not working
        if [[ $? -ne 0 || -z "$line" ]]; then
            browser_cookies=$(get_youtube_cookies)
            if [[ -n "$browser_cookies" ]]; then
                line="$(yt-dlp $browser_cookies --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$url" 2>> ~/.zen/tmp/IA.log)"
            fi
        fi
    fi

    yid=$(echo "$line" | cut -d '&' -f 1)
    media_title=$(echo "$line" | cut -d '&' -f 2 | detox --inline)
    duration=$(echo "$line" | cut -d '&' -f 3)
    uploader=$(echo "$line" | cut -d '&' -f 4)
    [[ -z "$media_title" ]] && media_title="media-$(date +%s)"

    # If we still don't have a valid title or id, fail
    if [[ -z "$yid" || -z "$media_title" ]]; then
        echo '{"error":"Failed to extract video metadata (title/id) from YouTube. Authentication or consent may be required."}'
        return 1
    fi

    # Set max duration to 3h (10800s) for both mp3 and mp4
    if [[ -n "$duration" ]]; then
        if [ "$duration" -gt 10800 ]; then
            echo '{"error":"Media duration exceeds 3 hour limit"}'
            return 1
        fi
    fi

    # Download according to type, using the last successful browser_cookies (may be empty)
    case "$media_type" in
        mp3)
            yt-dlp $browser_cookies -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url" 2>> ~/.zen/tmp/IA.log
            ;;
        mp4)
            yt-dlp $browser_cookies -f "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best" \
                --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url" 2>> ~/.zen/tmp/IA.log
            ;;
    esac

    media_file=$(ls "$temp_dir"/${media_title}.* 2>/dev/null | head -n 1)
    filename=$(basename "$media_file")

    if [[ -n "$media_file" ]]; then
        media_ipfs=$(ipfs add -wq "$media_file" 2>/dev/null | tail -n 1)
        if [[ -n "$media_ipfs" ]]; then
            ipfs_url="$myIPFS/ipfs/$media_ipfs/$filename"
            # Output JSON with all metadata (quoted values)
            echo '{'
            echo '  "ipfs_url": '"\"$ipfs_url\"",'
            echo '  "title": '"\"$media_title\"",'
            echo '  "duration": '"\"$duration\"",'
            echo '  "uploader": '"\"$uploader\"",'
            echo '  "original_url": '"\"$url\"",'
            echo '  "filename": '"\"$filename\""'
            echo '}'
            return 0
        fi
    fi
    echo '{"error":"Download or IPFS add failed"}'
    return 1
}

# Main execution
process_youtube "$URL" "$FORMAT" "$TMP_DIR" 