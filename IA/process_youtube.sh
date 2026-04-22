#!/bin/bash
########################################################################
# process_youtube.sh (Version Optimisée & Complète)
# Conserve l'anti-blocage (Deno, PO tokens, retry), la limite des 650Mo, 
# et la priorité aux cookies du MULTIPASS. Désactive les playlists.
# Usage: $0 [--json-file FILE] [--debug] [--output-dir DIR] <url> <format> [player_email]
########################################################################

source "$HOME/.zen/Astroport.ONE/tools/my.sh"

DEBUG=0
CUSTOM_OUTPUT_DIR=""
JSON_FILE=""
LOGFILE="$HOME/.zen/tmp/ajouter_media.log"
mkdir -p "$(dirname "$LOGFILE")"

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        ( echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2 ) 2>/dev/null || true
    fi
}

output_json() {
    local json_content="$1"
    if [[ -n "$JSON_FILE" ]]; then
        mkdir -p "$(dirname "$JSON_FILE")" 2>/dev/null
        echo "$json_content" > "$JSON_FILE"
    fi
    echo "$json_content"
}

# --- 1. PARSING DES ARGUMENTS ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug) DEBUG=1; shift ;;
        --json|--no-ipfs) shift ;; # Ignorés
        --json-file) JSON_FILE="$2"; shift 2 ;;
        --output-dir) CUSTOM_OUTPUT_DIR="$2"; shift 2 ;;
        *) break ;;
    esac
done

if [ $# -lt 2 ]; then
    log_debug "Usage: $0 [--debug] [--output-dir DIR] <url> <format> [player_email]"
    exit 1
fi

URL="$1"
FORMAT="$2"
PLAYER_EMAIL="$3"

if [[ ! "$URL" =~ ^https?:// ]]; then URL="ytsearch1:$URL"; fi

if [[ -n "$CUSTOM_OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$CUSTOM_OUTPUT_DIR"
else
    OUTPUT_DIR="$HOME/.zen/tmp.media/youtube_$(date +%s)"
fi
mkdir -p "$OUTPUT_DIR"

# --- 2. ANTI-BLOCAGE : DENO & PO TOKENS ---
DENO_BIN=""
if command -v deno >/dev/null 2>&1; then DENO_BIN="$(command -v deno)"
elif [[ -x "$HOME/.deno/bin/deno" ]]; then DENO_BIN="$HOME/.deno/bin/deno"
fi

JS_RUNTIME_ARG=""
if [[ -n "$DENO_BIN" ]]; then
    JS_RUNTIME_ARG="--js-runtimes deno:${DENO_BIN}"
    log_debug "Using Deno: $DENO_BIN"
fi

BGUTIL_ARG=""
if curl -sf --max-time 2 "http://localhost:4416/" >/dev/null 2>&1; then
    BGUTIL_ARG="--extractor-args youtube:pot_provider=bgutil"
    log_debug "PO tokens enabled via bgutil"
fi

# --- 3. GESTION DES COOKIES (PRIORITÉ JOUEUR) ---
extract_browser_cookies() {
    local temp_cookie_file="$HOME/.zen/tmp/youtube_browser_cookies_$$.txt"
    # (La même fonction SQLite robuste que votre script original pour Chrome/Firefox)
    for chrome_dir in "$HOME/.config/google-chrome" "$HOME/.config/chromium" "$HOME/.config/BraveSoftware/Brave-Browser"; do
        if [[ -d "$chrome_dir" ]]; then
            for profile in "$chrome_dir"/*/Cookies; do
                if [[ -f "$profile" ]] && command -v sqlite3 &> /dev/null; then
                    sqlite3 "$profile" "SELECT host_key, path, is_secure, expires_utc, name, value FROM cookies WHERE host_key LIKE '%youtube.com%'" | while IFS='|' read -r host path secure exp name val; do
                        [[ -n "$name" && -n "$val" ]] && echo -e "${host}\tTRUE\t${path}\tFALSE\t0\t${name}\t${val}" >> "$temp_cookie_file"
                    done 2>/dev/null
                fi
            done
        fi
    done
    if [[ -f "$temp_cookie_file" ]]; then echo "$temp_cookie_file"; else return 1; fi
}

cookie_file=""
if [[ -n "$PLAYER_EMAIL" ]]; then
    if [[ -f "$HOME/.zen/game/nostr/$PLAYER_EMAIL/.youtube.com.cookie" ]]; then
        cookie_file="$HOME/.zen/game/nostr/$PLAYER_EMAIL/.youtube.com.cookie"
    elif [[ -f "$HOME/.zen/game/nostr/$PLAYER_EMAIL/.cookie.txt" ]]; then
        cookie_file="$HOME/.zen/game/nostr/$PLAYER_EMAIL/.cookie.txt"
    fi
fi

if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
    COOKIESRC="--cookies $cookie_file"
    log_debug "Using MULTIPASS cookie: $cookie_file"
else
    BROWSER_COOKIE_FILE=$(extract_browser_cookies)
    if [[ -n "$BROWSER_COOKIE_FILE" && -f "$BROWSER_COOKIE_FILE" ]]; then
        COOKIESRC="--cookies $BROWSER_COOKIE_FILE"
        log_debug "Using extracted browser cookies"
    else
        COOKIESRC="--cookies-from-browser firefox" # Fallback yt-dlp native
    fi
fi

# --- 4. METADATA & RESOLUTION INTELLIGENTE ---
log_debug "Extracting metadata for: $URL"
metadata_output=$(yt-dlp $JS_RUNTIME_ARG $BGUTIL_ARG $COOKIESRC --no-warnings --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$URL" 2>> "$LOGFILE")

metadata_line=$(echo "$metadata_output" | grep -E "^[a-zA-Z0-9_-]{11}&" | head -n 1)
if [[ -z "$metadata_line" ]]; then
    output_json '{"error":"Failed to extract metadata. Check URL or Cookies."}'
    exit 1
fi

raw_title=$(echo "$metadata_line" | cut -d '&' -f 2 | tr -d '\n')
duration=$(echo "$metadata_line" | cut -d '&' -f 3 | tr -d '\n')
media_title=$(echo "$raw_title" | detox --inline | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)

# Calcul dynamique pour rester sous 650Mo
VIDEO_FORMAT_FILTER="(bv*[ext=mp4][height<=480]+ba/b[height<=480]/bv*[ext=mp4]+ba/b)"
if [[ -n "$duration" && "$duration" -gt 0 ]]; then
    MAX_TOTAL_BITRATE_KBPS=$(( (600 * 1024 * 8) / duration ))
    if [[ $MAX_TOTAL_BITRATE_KBPS -lt 400 ]]; then
        VIDEO_FORMAT_FILTER="(bv*[ext=mp4][height<=240]+ba/b[height<=240]/bv*[ext=mp4]+ba/b)"
        log_debug "Very long video (${duration}s), capping at 240p to fit 650MB"
    elif [[ $MAX_TOTAL_BITRATE_KBPS -lt 700 ]]; then
        VIDEO_FORMAT_FILTER="(bv*[ext=mp4][height<=360]+ba/b[height<=360]/bv*[ext=mp4]+ba/b)"
        log_debug "Long video (${duration}s), capping at 360p to fit 650MB"
    fi
fi

# --- 5. TÉLÉCHARGEMENT ---
# SIMPLIFICATION ICI : --playlist-items 1 garantit qu'on ne pompe pas une playlist entière
log_debug "Starting download"
case "$FORMAT" in
    mp3)
        download_output=$(yt-dlp $JS_RUNTIME_ARG $BGUTIL_ARG $COOKIESRC --playlist-items 1 --concurrent-fragments 1 --socket-timeout 120 -f "bestaudio/best" -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata --write-info-json -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$URL" 2>&1)
        ;;
    mp4)
        download_output=$(yt-dlp $JS_RUNTIME_ARG $BGUTIL_ARG $COOKIESRC --playlist-items 1 --concurrent-fragments 1 --socket-timeout 120 -f "$VIDEO_FORMAT_FILTER" -S "res,ext:mp4:m4a" --recode-video mp4 --no-mtime --embed-thumbnail --add-metadata --write-info-json -o "${OUTPUT_DIR}/${media_title}.mp4" "$URL" 2>&1)
        ;;
esac
download_exit_code=$?

# RETRY SI ERREUR 403
if [[ $download_exit_code -ne 0 ]] && echo "$download_output" | grep -qE "403|Forbidden"; then
    log_debug "403 Forbidden. Retrying with tv_embedded client..."
    YT_EXTRACTOR_ARGS='--extractor-args youtube:player_client=tv_embedded,tv'
    
    if [[ "$FORMAT" == "mp4" ]]; then
        download_output=$(yt-dlp $JS_RUNTIME_ARG $BGUTIL_ARG $YT_EXTRACTOR_ARGS $COOKIESRC --playlist-items 1 -f "$VIDEO_FORMAT_FILTER" --recode-video mp4 --write-info-json -o "${OUTPUT_DIR}/${media_title}.mp4" "$URL" 2>&1)
    else
        download_output=$(yt-dlp $JS_RUNTIME_ARG $BGUTIL_ARG $YT_EXTRACTOR_ARGS $COOKIESRC --playlist-items 1 -f "bestaudio/best" -x --audio-format mp3 --write-info-json -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$URL" 2>&1)
    fi
    download_exit_code=$?
fi

if [[ $download_exit_code -ne 0 ]]; then
    output_json "{\"error\":\"Download failed (exit code: $download_exit_code)\"}"
    exit 1
fi

# --- 6. IDENTIFICATION DU FICHIER ET CREATION DU JSON COMPLET ---
media_file=$(find "$OUTPUT_DIR" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mp3" -o -name "*.m4a" \) ! -name "*.info.json" 2>/dev/null | head -n 1)

if [[ -z "$media_file" ]]; then
    output_json '{"error":"Media file not found after download"}'
    exit 1
fi

filename=$(basename "$media_file")
metadata_file=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.info.json" 2>/dev/null | head -n 1)

# LE GROS BLOC JQ (Vital pour l'info.json v2.0 du contrat)
YOUTUBE_METADATA_JSON="{}"
if [[ -n "$metadata_file" && -f "$metadata_file" ]] && command -v jq &> /dev/null; then
    YOUTUBE_METADATA_JSON=$(jq -c '{
        youtube_id: .id, youtube_url: .webpage_url, title: .title, duration: .duration,
        uploader: .uploader, channel: .channel, view_count: .view_count, 
        like_count: .like_count, upload_date: .upload_date, tags: .tags, 
        categories: .categories, thumbnail: .thumbnail, format_id: .format_id
    }' "$metadata_file" 2>/dev/null || echo "{}")
fi

json_output=$(jq -n \
    --arg title "$media_title" \
    --arg filename "$filename" \
    --arg file_path "$media_file" \
    --arg output_dir "$OUTPUT_DIR" \
    --arg duration "${duration:-0}" \
    --arg metadata_file "${metadata_file:-}" \
    --argjson yt_meta "$YOUTUBE_METADATA_JSON" \
    '{
    success: true,
    title: $title,
    filename: $filename,
    file_path: $file_path,
    output_dir: $output_dir,
    duration: ($duration | tonumber? // 0),
    metadata_file: $metadata_file,
    youtube_metadata: $yt_meta
}')

output_json "$json_output"
exit 0