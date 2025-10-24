#!/bin/bash
########################################################################
# process_youtube_simple.sh
# Version simplifiée pour éviter les protections YouTube
#
# Usage: $0 [--debug] <url> <format> [player_email]
########################################################################

# Source my.sh to get all necessary constants and functions
source "$HOME/.zen/Astroport.ONE/tools/my.sh"

DEBUG=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=1
            shift
            ;;
        *)
            break
            ;;
    esac
done

LOGFILE="$HOME/.zen/tmp/IA.log"
mkdir -p "$(dirname "$LOGFILE")"

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "[process_youtube_simple.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
    fi
}

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Vérifie si les arguments sont fournis
if [ $# -lt 2 ]; then
    log_debug "Usage: $0 [--debug] <url> <format> [player_email]"
    echo "Usage: $0 [--debug] <url> <format> [player_email]" >&2
    exit 1
fi

URL="$1"
FORMAT="$2"
PLAYER_EMAIL="$3"

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
    UDRIVE_COPY_PATH="$HOME/.zen/game/nostr/$PLAYER_EMAIL/APP/uDRIVE/Videos"
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
}
trap cleanup EXIT

# Extract metadata first
log_debug "Extracting metadata for: $URL"
metadata_line=$(yt-dlp --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$URL" 2>> "$LOGFILE")
log_debug "Metadata line: $metadata_line"

if [[ -z "$metadata_line" ]]; then
    echo '{"error":"❌ Failed to extract metadata from YouTube URL"}'
    exit 1
fi

# Parse metadata
yid=$(echo "$metadata_line" | cut -d '&' -f 1)
raw_title=$(echo "$metadata_line" | cut -d '&' -f 2)
duration=$(echo "$metadata_line" | cut -d '&' -f 3)
uploader=$(echo "$metadata_line" | cut -d '&' -f 4)

# Clean title
media_title=$(echo "$raw_title" | detox --inline | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g' | head -c 100)

log_debug "Extracted: yid=$yid, title=$media_title, duration=$duration, uploader=$uploader"

# Check duration limit (3 hours)
if [[ -n "$duration" && "$duration" =~ ^[0-9]+$ && "$duration" -gt 10800 ]]; then
    log_debug "Media duration exceeds 3 hour limit: ${duration}s"
    echo '{"error":"Media duration exceeds 3 hour limit"}'
    exit 1
fi

# Try simple download strategies
log_debug "Starting download with simplified approach"

# Strategy 1: Default yt-dlp with cookies
log_debug "Strategy 1: Default yt-dlp with cookies"
cookie_file="$HOME/.zen/game/nostr/$PLAYER_EMAIL/.cookie.txt"
if [[ -f "$cookie_file" ]]; then
    case "$FORMAT" in
        mp3)
            yt-dlp --cookies "$cookie_file" -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$URL" >&2 2>> "$LOGFILE"
            ;;
        mp4)
            yt-dlp --cookies "$cookie_file" --recode-video mp4 --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.mp4" "$URL" >&2 2>> "$LOGFILE"
            ;;
    esac
else
    # Fallback without cookies
    case "$FORMAT" in
        mp3)
            yt-dlp -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$URL" >&2 2>> "$LOGFILE"
            ;;
        mp4)
            yt-dlp --recode-video mp4 --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.mp4" "$URL" >&2 2>> "$LOGFILE"
            ;;
    esac
fi

download_exit_code=$?
log_debug "Strategy 1 exit code: $download_exit_code"

# Check if files were created
files_created=$(ls "$OUTPUT_DIR"/* 2>/dev/null | wc -l)
log_debug "Files created: $files_created"

if [[ $download_exit_code -eq 0 && $files_created -gt 0 ]]; then
    log_debug "Strategy 1 successful"
else
    # Strategy 2: With format specification
    log_debug "Strategy 2: With format specification"
    case "$FORMAT" in
        mp3)
            yt-dlp -f "bestaudio/best" -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$URL" >&2 2>> "$LOGFILE"
            ;;
        mp4)
            yt-dlp -f "best[height<=720]/best" --recode-video mp4 --no-mtime --embed-thumbnail --add-metadata \
                --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                -o "${OUTPUT_DIR}/${media_title}.mp4" "$URL" >&2 2>> "$LOGFILE"
            ;;
    esac
    
    download_exit_code=$?
    log_debug "Strategy 2 exit code: $download_exit_code"
    
    # Check if files were created
    files_created=$(ls "$OUTPUT_DIR"/* 2>/dev/null | wc -l)
    log_debug "Files created after strategy 2: $files_created"
    
    if [[ $download_exit_code -ne 0 || $files_created -eq 0 ]]; then
        # Strategy 3: With cookies if available
        log_debug "Strategy 3: With cookies"
        cookie_file="$HOME/.zen/game/nostr/$PLAYER_EMAIL/.cookie.txt"
        if [[ -f "$cookie_file" ]]; then
            case "$FORMAT" in
                mp3)
                    yt-dlp --cookies "$cookie_file" -f "bestaudio/best" -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
                        --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                        -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$URL" >&2 2>> "$LOGFILE"
                    ;;
                mp4)
                    yt-dlp --cookies "$cookie_file" -f "best[height<=720]/best" --recode-video mp4 --no-mtime --embed-thumbnail --add-metadata \
                        --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
                        -o "${OUTPUT_DIR}/${media_title}.mp4" "$URL" >&2 2>> "$LOGFILE"
                    ;;
            esac
            
            download_exit_code=$?
            log_debug "Strategy 3 exit code: $download_exit_code"
            
            # Check if files were created
            files_created=$(ls "$OUTPUT_DIR"/* 2>/dev/null | wc -l)
            log_debug "Files created after strategy 3: $files_created"
        fi
    fi
fi

# Check final result
if [[ $download_exit_code -eq 0 && $files_created -gt 0 ]]; then
    # Find the downloaded file
    media_file=$(ls "$OUTPUT_DIR"/*.{mp4,mp3,m4a,webm,mkv} 2>/dev/null | head -n 1)
    
    if [[ -n "$media_file" ]]; then
        filename=$(basename "$media_file")
        log_debug "Found downloaded file: $media_file"
        
        # Add to IPFS
        media_ipfs=$(ipfs add -wq "$media_file" 2>> "$LOGFILE" | tail -n 1)
        log_debug "IPFS add result: $media_ipfs"
        
        if [[ -n "$media_ipfs" ]]; then
            ipfs_url="/ipfs/$media_ipfs/$filename"
            echo "Media saved to: $media_file" >&2
            log_debug "Media saved to: $media_file"
            
            # Copy to uDRIVE if path provided
            if [[ -n "$UDRIVE_COPY_PATH" ]]; then
                if [[ "$FORMAT" == "mp3" ]]; then
                    artist=$(echo "$uploader" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
                    if [[ -z "$artist" || "$artist" == "null" ]]; then
                        artist="Unknown_Artist"
                    fi
                    music_dir="$UDRIVE_COPY_PATH/Music/$artist"
                    mkdir -p "$music_dir"
                    udrive_file="$music_dir/$filename"
                    echo "Organizing MP3 in Music/$artist/" >&2
                else
                    videos_dir="$UDRIVE_COPY_PATH/Videos"
                    mkdir -p "$videos_dir"
                    udrive_file="$videos_dir/$filename"
                    echo "Organizing MP4 in Videos/" >&2
                fi
                
                if cp "$media_file" "$udrive_file"; then
                    echo "File copied to uDRIVE: $udrive_file" >&2
                    log_debug "File copied to uDRIVE: $udrive_file"
                else
                    echo "Warning: Failed to copy file to uDRIVE: $udrive_file" >&2
                    log_debug "Warning: Failed to copy file to uDRIVE: $udrive_file"
                fi
            fi
            
            # Generate JSON response
            cat << EOF
{
  "ipfs_url": "$ipfs_url",
  "title": "$media_title",
  "duration": "$duration",
  "uploader": "$uploader",
  "original_url": "$URL",
  "filename": "$filename",
  "metadata_ipfs": "",
  "thumbnail_ipfs": "",
  "subtitles": [],
  "channel_info": {
    "name": "$(echo "$uploader" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)",
    "display_name": "$uploader",
    "type": "youtube"
  },
  "content_info": {
    "description": "",
    "ai_analysis": "",
    "topic_keywords": "",
    "duration_category": "$(if [[ -n "$duration" && "$duration" =~ ^[0-9]+$ ]]; then duration_min=$((duration / 60)); if [[ $duration_min -lt 5 ]]; then echo "short"; elif [[ $duration_min -lt 30 ]]; then echo "medium"; else echo "long"; fi; fi)"
  },
  "technical_info": {
    "format": "$FORMAT",
    "file_size": "$(stat -c%s "$media_file" 2>/dev/null || echo "unknown")",
    "download_date": "$(date -Iseconds)"
  }
}
EOF
            log_debug "Success JSON outputted."
            exit 0
        fi
    fi
fi

log_debug "Download failed."
echo '{"error":"❌ Download failed with all strategies"}'
exit 1
