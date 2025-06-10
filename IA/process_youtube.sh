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

    # Try to get cookies from common browsers with correct paths
    echo "Searching for browser cookies..." >&2
    
    # Chrome/Chromium paths
    for chrome_path in \
        "$HOME/.config/google-chrome/Default/Cookies" \
        "$HOME/.config/chromium/Default/Cookies" \
        "$HOME/snap/chromium/common/chromium/Default/Cookies" \
        "$HOME/.var/app/com.google.Chrome/config/google-chrome/Default/Cookies"; do
        if [[ -f "$chrome_path" ]]; then
            browser_cookies="--cookies-from-browser chrome"
            echo "Found Chrome/Chromium cookies: $chrome_path" >&2
            break
        fi
    done
    
    # Firefox paths (if Chrome not found)
    if [[ -z "$browser_cookies" ]]; then
        for firefox_path in \
            "$HOME/.mozilla/firefox/"*/cookies.sqlite \
            "$HOME/snap/firefox/common/.mozilla/firefox/"*/cookies.sqlite \
            "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox/"*/cookies.sqlite; do
            if [[ -f "$firefox_path" ]]; then
                browser_cookies="--cookies-from-browser firefox"
                echo "Found Firefox cookies: $firefox_path" >&2
                break
            fi
        done
    fi
    
    # Brave paths (if others not found)
    if [[ -z "$browser_cookies" ]]; then
        for brave_path in \
            "$HOME/.config/BraveSoftware/Brave-Browser/Default/Cookies" \
            "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/Default/Cookies"; do
            if [[ -f "$brave_path" ]]; then
                browser_cookies="--cookies-from-browser brave"
                echo "Found Brave cookies: $brave_path" >&2
                break
            fi
        done
    fi
    
    # Edge paths (if others not found)
    if [[ -z "$browser_cookies" ]]; then
        for edge_path in \
            "$HOME/.config/microsoft-edge/Default/Cookies" \
            "$HOME/.var/app/com.microsoft.Edge/config/microsoft-edge/Default/Cookies"; do
            if [[ -f "$edge_path" ]]; then
                browser_cookies="--cookies-from-browser edge"
                echo "Found Edge cookies: $edge_path" >&2
                break
            fi
        done
    fi

    # If no browser cookies found, try to get them with curl
    if [[ -z "$browser_cookies" ]]; then
        echo "No browser cookies found, trying to generate cookies with curl..." >&2
        browser_cookies=$(get_youtube_cookies)
    else
        echo "Using browser cookies: $browser_cookies" >&2
    fi

    # Obtenir le titre et la durée
    local line=""
    if [[ -n "$browser_cookies" ]]; then
        line="$(yt-dlp $browser_cookies --print "%(id)s&%(title)s&%(duration)s" "$url" 2>> ~/.zen/tmp/IA.log)"
        if [[ $? -ne 0 ]]; then
            echo "Warning: Failed to get video info with cookies, trying without" >&2
            line="$(yt-dlp --print "%(id)s&%(title)s&%(duration)s" "$url" 2>> ~/.zen/tmp/IA.log)"
        fi
    else
        line="$(yt-dlp --print "%(id)s&%(title)s&%(duration)s" "$url" 2>> ~/.zen/tmp/IA.log)"
    fi

    local yid=$(echo "$line" | cut -d '&' -f 1)
    local media_title=$(echo "$line" | cut -d '&' -f 2- | sed 's/&[0-9]*$//' | detox --inline)
    local duration=$(echo "$line" | grep -o '[0-9]*$')
    [[ -z "$media_title" ]] && media_title="media-$(date +%s)"

    # Vérifier la durée selon le type
    if [[ -n "$duration" ]]; then
        case "$media_type" in
            mp3)
                if [ "$duration" -gt 3600 ]; then
                    echo "Error: Audio duration exceeds 1 hour limit" >&2
                    return 1
                fi
                ;;
            mp4)
                if [ "$duration" -gt 900 ]; then
                    echo "Error: Video duration exceeds 15 minutes limit" >&2
                    return 1
                fi
                ;;
        esac
    fi

    # Télécharger selon le type
    case "$media_type" in
        mp3)
            echo "Downloading and converting to MP3..." >&2
            yt-dlp $browser_cookies -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url" 2>> ~/.zen/tmp/IA.log
            ;;
        mp4)
            echo "Downloading and converting to MP4 (720p max)..." >&2
            yt-dlp $browser_cookies -f "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best" \
                --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url" 2>> ~/.zen/tmp/IA.log
            ;;
    esac

    # Trouver le fichier téléchargé
    media_file=$(ls "$temp_dir"/${media_title}.* 2>/dev/null | head -n 1)

    if [[ -n "$media_file" ]]; then
        # Ajouter à IPFS
        media_ipfs=$(ipfs add -wq "$media_file" 2>/dev/null | tail -n 1)
        if [[ -n "$media_ipfs" ]]; then
            echo "$myIPFS/ipfs/$media_ipfs/$media_title.$media_type"
        fi
    fi
}

# Main execution
process_youtube "$URL" "$FORMAT" "$TMP_DIR" 