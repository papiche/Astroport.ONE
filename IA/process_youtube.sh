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
CUSTOM_OUTPUT_DIR=""

# Parse arguments
# Note: --no-ipfs flag is deprecated (now default behavior for UPlanet_FILE_CONTRACT.md compliance)
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=1
            shift
            ;;
        --no-ipfs)
            # Deprecated: IPFS upload removed. This flag is kept for backward compatibility but does nothing.
            log_debug "Note: --no-ipfs flag is deprecated (IPFS upload removed for UPlanet_FILE_CONTRACT.md compliance)"
            shift
            ;;
        --output-dir)
            CUSTOM_OUTPUT_DIR="$2"
            shift 2
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
        # Use subshell with error handling to prevent broken pipe errors
        (
            echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
        ) 2>/dev/null || true
    fi
}

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Vérifie si les arguments sont fournis
if [ $# -lt 2 ]; then
    log_debug "Usage: $0 [--debug] [--output-dir DIR] <url> <format> [player_email]"
    # Use subshell to prevent broken pipe errors
    (echo "Usage: $0 [--debug] [--output-dir DIR] <url> <format> [player_email]" >&2) 2>/dev/null || echo "Usage: $0 [--debug] [--output-dir DIR] <url> <format> [player_email]"
    (echo "Note: This script downloads only. Uploads must go through /api/fileupload (UPlanet_FILE_CONTRACT.md)" >&2) 2>/dev/null || true
    exit 1
fi

URL="$1"
FORMAT="$2"
PLAYER_EMAIL="$3"

# Create temporary directory or use custom output dir
if [[ -n "$CUSTOM_OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$CUSTOM_OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    log_debug "Using custom output directory: $OUTPUT_DIR"
else
    TMP_DIR="$HOME/.zen/tmp/youtube_$(date +%s)"
    mkdir -p "$TMP_DIR"
    OUTPUT_DIR="$TMP_DIR"
fi

# Use subshell to prevent broken pipe errors when writing to stderr
(echo "Using directory for download: $OUTPUT_DIR" >&2) 2>/dev/null || true
log_debug "Using directory for download: $OUTPUT_DIR"

# Note: uDRIVE copy is now handled by /api/fileupload endpoint
# (UPlanet_FILE_CONTRACT.md compliance - standardized workflow)

# Cleanup function (only cleanup if using temp dir)
cleanup() {
    if [[ -z "$CUSTOM_OUTPUT_DIR" && -n "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# Extract metadata first
log_debug "Extracting metadata for: $URL"

# Find cookie file - cookies are stored at user's NOSTR root directory
cookie_file=""
if [[ -n "$PLAYER_EMAIL" ]]; then
    user_dir="$HOME/.zen/game/nostr/$PLAYER_EMAIL"
    if [[ -f "$user_dir/.youtube.com.cookie" ]]; then
        cookie_file="$user_dir/.youtube.com.cookie"
        log_debug "Using single-domain YouTube cookie: $cookie_file"
    elif [[ -f "$user_dir/.cookie.txt" ]]; then
        cookie_file="$user_dir/.cookie.txt"
        log_debug "Using cookie file: $cookie_file"
    fi
fi

if [[ -z "$cookie_file" || ! -f "$cookie_file" ]]; then
    # Output JSON to stdout (not stderr) to avoid broken pipe issues
    echo '{"error":"❌ No cookie file found. Please upload a YouTube cookie file via /api/fileupload"}' 2>/dev/null || echo '{"error":"No cookie file found"}'
    exit 1
fi

metadata_line=$(yt-dlp --cookies "$cookie_file" --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$URL" 2>> "$LOGFILE")
log_debug "Metadata line: $metadata_line"

if [[ -z "$metadata_line" ]]; then
    # Output JSON to stdout (not stderr) to avoid broken pipe issues
    echo '{"error":"❌ Failed to extract metadata from YouTube URL"}' 2>/dev/null || echo '{"error":"Failed to extract metadata from YouTube URL"}'
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
    # Output JSON to stdout (not stderr) to avoid broken pipe issues
    echo '{"error":"Media duration exceeds 3 hour limit"}' 2>/dev/null || echo '{"error":"Media duration exceeds 3 hour limit"}'
    exit 1
fi

# Simple download with cookies (guaranteed to exist by youtube.com.sh)
log_debug "Starting download with cookies"
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
log_debug "Download exit code: $download_exit_code"

# Check if files were created
files_created=$(ls "$OUTPUT_DIR"/* 2>/dev/null | wc -l)
log_debug "Files created: $files_created"

# Check final result
if [[ $download_exit_code -eq 0 && $files_created -gt 0 ]]; then
    # Find the downloaded file
    media_file=$(ls "$OUTPUT_DIR"/*.{mp4,mp3,m4a,webm,mkv} 2>/dev/null | head -n 1)
    
    if [[ -n "$media_file" ]]; then
        filename=$(basename "$media_file")
        log_debug "Found downloaded file: $media_file"
        
        # Find metadata.json file created by yt-dlp (--write-info-json)
        metadata_file=""
        metadata_basename=$(basename "$media_file" | sed 's/\.[^.]*$//')
        # yt-dlp creates .info.json files
        for possible_metadata in "${OUTPUT_DIR}/${metadata_basename}.info.json" "$(dirname "$media_file")/${metadata_basename}.info.json"; do
            if [[ -f "$possible_metadata" ]]; then
                metadata_file="$possible_metadata"
                log_debug "Found metadata file: $metadata_file"
                break
            fi
        done
        
        # UPlanet_FILE_CONTRACT.md Compliance:
        # This script is a download-only tool. All uploads must go through /api/fileupload
        # which uses upload2ipfs.sh for standardized metadata extraction, info.json generation,
        # provenance tracking, and uDRIVE organization.
        # 
        # The --no-ipfs flag is now the default behavior (legacy IPFS upload removed).
        # Files are downloaded and returned to the caller (ajouter_media.sh) which handles
        # the complete workflow via /api/fileupload and /webcam endpoints.
        
        (echo "Media downloaded to: $media_file" >&2) 2>/dev/null || true
        log_debug "Media downloaded to: $media_file"
        log_debug "File will be uploaded via /api/fileupload (UPlanet_FILE_CONTRACT.md compliant)"
            
        # Generate JSON response - write to stdout ONLY
            # Use echo to ensure clean output
            json_output=$(cat << EOF
{
  "ipfs_url": "",
  "title": "$media_title",
  "duration": "$duration",
  "uploader": "$uploader",
  "original_url": "$URL",
  "filename": "$filename",
  "file_path": "$media_file",
  "output_dir": "$OUTPUT_DIR",
  "metadata_file": "${metadata_file:-}",
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
)
            # Write a clear separator to stderr, then JSON to stdout
            (echo "=== JSON OUTPUT START ===" >&2) 2>/dev/null || true
            echo "$json_output"
            (echo "=== JSON OUTPUT END ===" >&2) 2>/dev/null || true
        log_debug "Success JSON outputted. File ready for /api/fileupload workflow."
            exit 0
    fi
fi

log_debug "Download failed."
# Output JSON to stdout (not stderr) to avoid broken pipe issues
echo '{"error":"❌ Download failed with all strategies"}' 2>/dev/null || echo '{"error":"Download failed with all strategies"}'
exit 1
