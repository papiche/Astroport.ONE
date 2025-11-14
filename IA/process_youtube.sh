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
JSON_OUTPUT=0
JSON_FILE=""
LOGFILE="$HOME/.zen/tmp/ajouter_media.log"
mkdir -p "$(dirname "$LOGFILE")"

# Define log_debug function early (before argument parsing)
log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        # Use subshell with error handling to prevent broken pipe errors
        (
            echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
        ) 2>/dev/null || true
    fi
}

# Function to output JSON safely (to file if specified, and to stdout)
output_json() {
    local json_content="$1"
    
    # Write to file if JSON_FILE is specified
    if [[ -n "$JSON_FILE" ]]; then
        # Create directory if it doesn't exist
        local json_dir=$(dirname "$JSON_FILE")
        if [[ ! -d "$json_dir" ]]; then
            mkdir -p "$json_dir" 2>/dev/null || true
        fi
        # Write JSON to file
        echo "$json_content" > "$JSON_FILE" 2>/dev/null || {
            log_debug "WARNING: Failed to write JSON to file: $JSON_FILE"
        }
        log_debug "JSON written to file: $JSON_FILE"
    fi
    
    # Also output to stdout for backward compatibility
    if [[ $JSON_OUTPUT -eq 1 ]]; then
        # Pure JSON output (no separators)
        echo "$json_content"
    else
        # Write separators to stderr, then JSON to stdout (backward compatibility)
        (echo "=== JSON OUTPUT START ===" >&2) 2>/dev/null || true
        echo "$json_content"
        (echo "=== JSON OUTPUT END ===" >&2) 2>/dev/null || true
    fi
}

# Parse arguments
# Note: --no-ipfs flag is deprecated (now default behavior for UPlanet_FILE_CONTRACT.md compliance)
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=1
            shift
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        --json-file)
            JSON_OUTPUT=1
            JSON_FILE="$2"
            shift 2
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
    # Also cleanup browser cookie file if it was created
    if [[ -n "$BROWSER_COOKIE_FILE" ]] && [[ -f "$BROWSER_COOKIE_FILE" ]]; then
        rm -f "$BROWSER_COOKIE_FILE" 2>/dev/null
    fi
}
trap cleanup EXIT

# Extract metadata first
log_debug "Extracting metadata for: $URL"

# Function to extract YouTube cookies from browser's cookie database
extract_browser_cookies() {
    local temp_cookie_file="$HOME/.zen/tmp/youtube_browser_cookies_$$.txt"
    mkdir -p "$(dirname "$temp_cookie_file")"
    
    # Try Chrome/Chromium/Brave
    for chrome_dir in "$HOME/.config/google-chrome" "$HOME/.config/chromium" "$HOME/.config/BraveSoftware/Brave-Browser"; do
        if [[ -d "$chrome_dir" ]]; then
            for profile in "$chrome_dir"/*/Cookies; do
                if [[ -f "$profile" ]]; then
                    log_debug "Trying Chrome cookie database: $profile"
                    # Extract YouTube cookies using sqlite3
                    if command -v sqlite3 &> /dev/null; then
                        # Use process substitution to avoid subshell issues
                        while IFS='|' read -r name value host path expires_utc is_secure is_httponly; do
                            if [[ -n "$name" && -n "$value" ]]; then
                                # Convert Chrome timestamp to Unix timestamp (Chrome uses microseconds since 1601-01-01)
                                # expires_utc is in microseconds, convert to seconds
                                expires=$((expires_utc / 1000000 - 11644473600))
                                # Format as Netscape cookie format: domain flag path secure expiration name value
                                # flag: TRUE if cookie applies to subdomains, FALSE otherwise
                                domain_flag="FALSE"
                                [[ "$host" =~ ^\. ]] && domain_flag="TRUE"
                                secure_flag="FALSE"
                                [[ "$is_secure" == "1" ]] && secure_flag="TRUE"
                                httponly_flag=""
                                [[ "$is_httponly" == "1" ]] && httponly_flag="#HttpOnly_"
                                echo -e "${httponly_flag}${host}\t${domain_flag}\t${path}\t${secure_flag}\t${expires}\t${name}\t${value}" >> "$temp_cookie_file"
                            fi
                        done < <(sqlite3 "$profile" "SELECT name, value, host_key, path, expires_utc, is_secure, is_httponly FROM cookies WHERE host_key LIKE '%youtube.com%' OR host_key LIKE '%.youtube.com%'" 2>/dev/null)
                        
                        if [[ -f "$temp_cookie_file" ]] && [[ -s "$temp_cookie_file" ]]; then
                            break 2
                        fi
                    fi
                fi
            done
        fi
    done
    
    # Try Firefox if Chrome didn't work
    if [[ ! -f "$temp_cookie_file" ]] || [[ ! -s "$temp_cookie_file" ]]; then
        if command -v sqlite3 &> /dev/null; then
            for firefox_profile in "$HOME/.mozilla/firefox"/*/cookies.sqlite*; do
                if [[ -f "$firefox_profile" ]]; then
                    log_debug "Trying Firefox cookie database: $firefox_profile"
                    while IFS='|' read -r name value host path expiry is_secure is_httponly; do
                        if [[ -n "$name" && -n "$value" ]]; then
                            # Format as Netscape cookie format: domain flag path secure expiration name value
                            # flag: TRUE if cookie applies to subdomains, FALSE otherwise
                            domain_flag="FALSE"
                            [[ "$host" =~ ^\. ]] && domain_flag="TRUE"
                            secure_flag="FALSE"
                            [[ "$is_secure" == "1" ]] && secure_flag="TRUE"
                            httponly_flag=""
                            [[ "$is_httponly" == "1" ]] && httponly_flag="#HttpOnly_"
                            echo -e "${httponly_flag}${host}\t${domain_flag}\t${path}\t${secure_flag}\t${expiry}\t${name}\t${value}" >> "$temp_cookie_file"
                        fi
                    done < <(sqlite3 "$firefox_profile" "SELECT name, value, host, path, expiry, isSecure, isHttpOnly FROM moz_cookies WHERE host LIKE '%youtube.com%' OR host LIKE '%.youtube.com%'" 2>/dev/null)
                    
                    if [[ -f "$temp_cookie_file" ]] && [[ -s "$temp_cookie_file" ]]; then
                        break
                    fi
                fi
            done
        fi
    fi
    
    if [[ -f "$temp_cookie_file" ]] && [[ -s "$temp_cookie_file" ]]; then
        # Add Netscape cookie file header
        echo -e "# Netscape HTTP Cookie File\n# This file was generated by process_youtube.sh from browser cookies\n" > "${temp_cookie_file}.netscape"
        cat "$temp_cookie_file" >> "${temp_cookie_file}.netscape"
        rm -f "$temp_cookie_file"
        echo "${temp_cookie_file}.netscape"
        return 0
    else
        rm -f "$temp_cookie_file" "${temp_cookie_file}.netscape" 2>/dev/null
        return 1
    fi
}

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

# If no MULTIPASS cookie found, try to extract from browser
BROWSER_COOKIE_FILE=""
if [[ -z "$cookie_file" || ! -f "$cookie_file" ]]; then
    log_debug "No MULTIPASS cookie found, trying to extract from browser..."
    BROWSER_COOKIE_FILE=$(extract_browser_cookies)
    if [[ -n "$BROWSER_COOKIE_FILE" ]] && [[ -f "$BROWSER_COOKIE_FILE" ]]; then
        cookie_file="$BROWSER_COOKIE_FILE"
        log_debug "Using browser cookie file: $cookie_file"
    fi
fi

if [[ -z "$cookie_file" || ! -f "$cookie_file" ]]; then
    # Build detailed error message
    error_msg="❌ No YouTube cookie file found"
    if [[ -n "$PLAYER_EMAIL" ]]; then
        error_msg="${error_msg} for MULTIPASS: ${PLAYER_EMAIL}"
    fi
    error_msg="${error_msg}. Please upload a YouTube cookie file via /api/fileupload"
    
    if [[ -n "$PLAYER_EMAIL" ]]; then
        error_msg="${error_msg}. Expected location: ~/.zen/game/nostr/${PLAYER_EMAIL}/.youtube.com.cookie or ~/.zen/game/nostr/${PLAYER_EMAIL}/.cookie.txt"
    fi
    error_msg="${error_msg}. Also tried to extract cookies from browser but failed."
    
    # Log detailed error to file
    echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $error_msg" >> "$LOGFILE"
    if [[ -n "$PLAYER_EMAIL" ]]; then
        echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] Checked paths:" >> "$LOGFILE"
        echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')]   - $HOME/.zen/game/nostr/${PLAYER_EMAIL}/.youtube.com.cookie" >> "$LOGFILE"
        echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')]   - $HOME/.zen/game/nostr/${PLAYER_EMAIL}/.cookie.txt" >> "$LOGFILE"
    fi
    echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] Also tried browser cookie extraction (Chrome/Firefox)" >> "$LOGFILE"
    
    # Output JSON to stdout (not stderr) to avoid broken pipe issues
    # Escape quotes for JSON
    error_msg_json=$(echo "$error_msg" | sed 's/"/\\"/g')
    if [[ $JSON_OUTPUT -eq 1 ]]; then
        # JSON-only output mode
        local error_json="{\"error\":\"${error_msg_json}\",\"success\":false}"
        output_json "$error_json"
    else
        # Legacy mode with markers
        (echo "=== JSON OUTPUT START ===" >&2) 2>/dev/null || true
        echo "{\"error\":\"${error_msg_json}\"}" 2>/dev/null || echo "{\"error\":\"No cookie file found\"}"
        (echo "=== JSON OUTPUT END ===" >&2) 2>/dev/null || true
    fi
    exit 1
fi

# Note: Playlist handling is now done by ajouter_media.sh
# This script only processes single videos. If a playlist URL is provided,
# it will download only the first video (or the video specified by ?v= parameter)
# ajouter_media.sh will detect playlists and loop through videos if needed

log_debug "Extracting metadata with yt-dlp..."
# Run yt-dlp with --quiet to suppress warnings, but keep errors
# Use --no-warnings to suppress warnings, but keep errors in stderr
# Single video processing only (playlists handled by ajouter_media.sh)
metadata_output=$(yt-dlp --cookies "$cookie_file" --no-warnings --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$URL" 2>> "$LOGFILE")
metadata_exit_code=$?
log_debug "yt-dlp metadata extraction exit code: $metadata_exit_code"

# Log errors to file
if [[ $metadata_exit_code -ne 0 ]]; then
    echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] ERROR: yt-dlp metadata extraction failed (exit code: $metadata_exit_code)" >> "$LOGFILE"
    echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] yt-dlp output: $metadata_output" >> "$LOGFILE"
    log_debug "yt-dlp error output: $metadata_output"
    # Output JSON to stdout (not stderr) to avoid broken pipe issues
    error_msg=$(echo "$metadata_output" | head -n 1 | sed 's/"/\\"/g')
    echo "{\"error\":\"❌ Failed to extract metadata from YouTube URL: $error_msg\"}" 2>/dev/null || echo "{\"error\":\"Failed to extract metadata from YouTube URL\"}"
    exit 1
fi

# Filter out warnings and extract only the line matching the expected format (id&title&duration&uploader)
# YouTube video IDs are 11 characters (alphanumeric, hyphens, underscores)
# The format should be: video_id&title&duration&uploader
# Filter lines that match the pattern: 11-char ID followed by & followed by title&duration&uploader
metadata_line=$(echo "$metadata_output" | grep -v "^WARNING" | grep -v "^ERROR" | grep -v "Please report" | grep -v "Falling back" | grep -E "^[a-zA-Z0-9_-]{11}&" | head -n 1)

# If still no valid line, try to extract any line with exactly 4 fields separated by &
if [[ -z "$metadata_line" ]]; then
    # Count fields separated by & - should be exactly 4 (id, title, duration, uploader)
    metadata_line=$(echo "$metadata_output" | grep -v "WARNING" | grep -v "ERROR" | while IFS= read -r line; do
        field_count=$(echo "$line" | tr '&' '\n' | wc -l)
        # Check if line starts with 11-char ID followed by & (escape & in regex)
        if [[ $field_count -eq 4 ]] && echo "$line" | grep -qE '^[a-zA-Z0-9_-]{11}&'; then
            echo "$line"
            break
        fi
    done | head -n 1)
fi

# Last resort: extract the last line that contains & and has 4 fields
if [[ -z "$metadata_line" ]]; then
    metadata_line=$(echo "$metadata_output" | grep -E "&" | grep -v "WARNING" | grep -v "ERROR" | while IFS= read -r line; do
        field_count=$(echo "$line" | tr '&' '\n' | wc -l)
        if [[ $field_count -eq 4 ]]; then
            echo "$line"
        fi
    done | tail -n 1)
fi

log_debug "Metadata line (filtered): $metadata_line"

if [[ -z "$metadata_line" ]]; then
    # Output JSON to stdout (not stderr) to avoid broken pipe issues
    echo '{"error":"❌ Failed to extract metadata from YouTube URL (empty result)"}' 2>/dev/null || echo '{"error":"Failed to extract metadata from YouTube URL"}'
    exit 1
fi

# Parse metadata - extract fields separated by &
yid=$(echo "$metadata_line" | cut -d '&' -f 1 | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
raw_title=$(echo "$metadata_line" | cut -d '&' -f 2 | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
duration=$(echo "$metadata_line" | cut -d '&' -f 3 | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
uploader=$(echo "$metadata_line" | cut -d '&' -f 4 | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Validate extracted fields
if [[ -z "$yid" ]] || [[ "$yid" =~ ^WARNING|^ERROR ]]; then
    log_debug "Invalid video ID extracted: $yid"
    echo '{"error":"❌ Failed to extract valid metadata from YouTube URL (invalid video ID)"}' 2>/dev/null || echo '{"error":"Failed to extract metadata from YouTube URL"}'
    exit 1
fi

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

# Calculate optimal video format to stay under 650MB limit
# Formula: max_bitrate (kbps) = (650MB * 8 * 1024) / duration_seconds
# We reserve ~50MB for audio and metadata, so target ~600MB for video
MAX_FILE_SIZE_MB=650
TARGET_VIDEO_SIZE_MB=600
TARGET_VIDEO_SIZE_BYTES=$((TARGET_VIDEO_SIZE_MB * 1024 * 1024))

# Determine optimal resolution based on duration
VIDEO_HEIGHT_LIMIT=720
VIDEO_FORMAT_FILTER="best[height<=720]/best"

if [[ -n "$duration" && "$duration" =~ ^[0-9]+$ && "$duration" -gt 0 ]]; then
    # Calculate max bitrate in kbps (kilobits per second)
    # Reserve ~128 kbps for audio, so video gets the rest
    MAX_TOTAL_BITRATE_KBPS=$(echo "$TARGET_VIDEO_SIZE_BYTES $duration" | awk '{if ($2 > 0) printf "%.0f", ($1 * 8) / ($2 * 1000); else print "0"}' 2>/dev/null || echo "0")
    
    # Validate and calculate video bitrate
    if [[ -n "$MAX_TOTAL_BITRATE_KBPS" ]] && [[ "$MAX_TOTAL_BITRATE_KBPS" =~ ^[0-9]+$ ]] && [[ $MAX_TOTAL_BITRATE_KBPS -gt 128 ]]; then
        MAX_VIDEO_BITRATE_KBPS=$((MAX_TOTAL_BITRATE_KBPS - 128))
    else
        # Fallback: use conservative estimate for very long videos
        MAX_VIDEO_BITRATE_KBPS=300
        log_debug "Warning: Could not calculate bitrate, using conservative default: ${MAX_VIDEO_BITRATE_KBPS} kbps"
    fi
    
    log_debug "Duration: ${duration}s, Max video bitrate: ${MAX_VIDEO_BITRATE_KBPS} kbps"
    
    # Choose resolution based on duration and bitrate constraints
    # Approximate bitrates: 720p ~2-3 Mbps, 480p ~1-1.5 Mbps, 360p ~0.5-1 Mbps, 240p ~0.3-0.5 Mbps
    # For a 2h video (7200s) with 600MB target: ~655 kbps total, ~527 kbps video -> need 360p or lower
    if [[ -n "$MAX_VIDEO_BITRATE_KBPS" ]] && [[ "$MAX_VIDEO_BITRATE_KBPS" =~ ^[0-9]+$ ]] && [[ $MAX_VIDEO_BITRATE_KBPS -lt 400 ]]; then
        # Very long video (>2h), use 240p or 360p
        VIDEO_HEIGHT_LIMIT=240
        VIDEO_FORMAT_FILTER="best[height<=240]/best[height<=360]/best[height<=480]/best"
        log_debug "Very long video detected (${duration}s, ${MAX_VIDEO_BITRATE_KBPS} kbps), selecting 240p max to stay under size limit"
    elif [[ -n "$MAX_VIDEO_BITRATE_KBPS" ]] && [[ "$MAX_VIDEO_BITRATE_KBPS" =~ ^[0-9]+$ ]] && [[ $MAX_VIDEO_BITRATE_KBPS -lt 700 ]]; then
        # Long video (1.5-2h), use 360p
        VIDEO_HEIGHT_LIMIT=360
        VIDEO_FORMAT_FILTER="best[height<=360]/best[height<=480]/best[height<=720]/best"
        log_debug "Long video detected (${duration}s, ${MAX_VIDEO_BITRATE_KBPS} kbps), selecting 360p max to stay under size limit"
    elif [[ -n "$MAX_VIDEO_BITRATE_KBPS" ]] && [[ "$MAX_VIDEO_BITRATE_KBPS" =~ ^[0-9]+$ ]] && [[ $MAX_VIDEO_BITRATE_KBPS -lt 1200 ]]; then
        # Medium video (45min-1.5h), use 480p
        VIDEO_HEIGHT_LIMIT=480
        VIDEO_FORMAT_FILTER="best[height<=480]/best[height<=720]/best"
        log_debug "Medium video detected (${duration}s, ${MAX_VIDEO_BITRATE_KBPS} kbps), selecting 480p max to stay under size limit"
    else
        # Short video (<45min), can use 720p (or fallback if calculation failed)
        VIDEO_HEIGHT_LIMIT=720
        VIDEO_FORMAT_FILTER="best[height<=720]/best"
        log_debug "Short video detected (${duration}s, ${MAX_VIDEO_BITRATE_KBPS} kbps), using 720p max"
    fi
fi

# Simple download with cookies (guaranteed to exist by youtube.com.sh)
log_debug "Starting download with cookies"
case "$FORMAT" in
    mp3)
        log_debug "Running yt-dlp for MP3 download..."
        download_output=$(yt-dlp --cookies "$cookie_file" -f "bestaudio/best" -x --audio-format mp3 --audio-quality 0 --no-mtime --embed-thumbnail --add-metadata \
            --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
            -o "${OUTPUT_DIR}/${media_title}.%(ext)s" "$URL" 2>&1)
        download_exit_code=$?
        echo "$download_output" >> "$LOGFILE"
        # Show output on stderr for debugging
        (echo "$download_output" >&2) 2>/dev/null || true
        ;;
    mp4)
        log_debug "Running yt-dlp for MP4 download with format filter: $VIDEO_FORMAT_FILTER"
        # Use format filter to select appropriate resolution based on duration
        # The format filter ensures we download at the right resolution to stay under size limit
        # If recoding is needed, yt-dlp will handle it with default settings
        download_output=$(yt-dlp --cookies "$cookie_file" -f "$VIDEO_FORMAT_FILTER" \
            --recode-video mp4 --no-mtime --embed-thumbnail --add-metadata \
            --write-info-json --write-thumbnail --embed-metadata --embed-thumbnail \
            -o "${OUTPUT_DIR}/${media_title}.mp4" "$URL" 2>&1)
        download_exit_code=$?
        echo "$download_output" >> "$LOGFILE"
        # Show output on stderr for debugging
        (echo "$download_output" >&2) 2>/dev/null || true
        ;;
esac

log_debug "Download exit code: $download_exit_code"
if [[ $download_exit_code -ne 0 ]]; then
    echo "[process_youtube.sh][$(date '+%Y-%m-%d %H:%M:%S')] ERROR: yt-dlp download failed (exit code: $download_exit_code)" >> "$LOGFILE"
    log_debug "yt-dlp download error output: $download_output"
fi

# Check if files were created
files_created=$(ls "$OUTPUT_DIR"/* 2>/dev/null | wc -l)
log_debug "Files created: $files_created"

# Check final result
if [[ $download_exit_code -eq 0 && $files_created -gt 0 ]]; then
    # Find the downloaded file - try multiple methods
    media_file=""
    
    # Method 1: Look for files with expected extension
    media_file=$(find "$OUTPUT_DIR" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mp3" -o -name "*.m4a" -o -name "*.webm" -o -name "*.mkv" \) ! -name "*.info.json" ! -name "*.webp" ! -name "*.png" ! -name "*.jpg" 2>/dev/null | head -n 1)
    
    # Method 2: If not found, try to find the largest file (likely the video)
    if [[ -z "$media_file" ]] || [[ ! -f "$media_file" ]]; then
        media_file=$(find "$OUTPUT_DIR" -maxdepth 1 -type f ! -name "*.info.json" ! -name "*.webp" ! -name "*.png" ! -name "*.jpg" -exec ls -S {} + 2>/dev/null | head -n 1)
    fi
    
    # Method 3: List all files and find media file
    if [[ -z "$media_file" ]] || [[ ! -f "$media_file" ]]; then
        for file in "$OUTPUT_DIR"/*; do
            if [[ -f "$file" ]] && [[ ! "$file" =~ \.(info\.json|webp|png|jpg)$ ]]; then
                # Check if it's a media file by extension or size (media files are usually > 1MB)
                if [[ "$file" =~ \.(mp4|mp3|m4a|webm|mkv)$ ]] || [[ $(stat -c%s "$file" 2>/dev/null || echo 0) -gt 1048576 ]]; then
                    media_file="$file"
                    break
                fi
            fi
        done
    fi
    
    if [[ -n "$media_file" ]] && [[ -f "$media_file" ]]; then
        filename=$(basename "$media_file")
        log_debug "Found downloaded file: $media_file"
        log_debug "File size: $(stat -c%s "$media_file" 2>/dev/null || echo "unknown") bytes"
        
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
            
        # Extract comprehensive metadata from .info.json if available
        YOUTUBE_METADATA_JSON="{}"
        if [[ -n "$metadata_file" ]] && [[ -f "$metadata_file" ]] && command -v jq &> /dev/null; then
            log_debug "Extracting comprehensive metadata from: $metadata_file"
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
            }' "$metadata_file" 2>/dev/null || echo "{}")
        fi
        
        # Generate JSON response with comprehensive metadata - write to stdout ONLY
        # Use jq to merge base JSON with extracted metadata
        # Validate media_file before generating JSON
        if [[ -z "$media_file" ]] || [[ ! -f "$media_file" ]]; then
            log_debug "ERROR: media_file is empty or does not exist before JSON generation: '$media_file'"
            log_debug "OUTPUT_DIR: $OUTPUT_DIR"
            log_debug "OUTPUT_DIR contents:"
            ls -la "$OUTPUT_DIR" 2>/dev/null | head -20 >&2 || true
            error_msg="Downloaded file not found in output directory: $OUTPUT_DIR"
            if [[ $JSON_OUTPUT -eq 1 ]]; then
                local error_json="{\"error\":\"${error_msg}\",\"success\":false}"
                output_json "$error_json"
            else
                echo "ERROR: $error_msg" >&2
            fi
            exit 1
        fi
        
        log_debug "Generating JSON with file_path: $media_file"
        
        # Validate YOUTUBE_METADATA_JSON before using it
        if command -v jq &> /dev/null; then
            if ! echo "$YOUTUBE_METADATA_JSON" | jq '.' >/dev/null 2>&1; then
                log_debug "WARNING: YOUTUBE_METADATA_JSON is invalid JSON, using empty object"
                YOUTUBE_METADATA_JSON="{}"
            fi
        fi
        
        json_output=""
        
        if command -v jq &> /dev/null; then
            # Try to generate JSON with jq, capture errors
            log_debug "Attempting to generate JSON with jq and comprehensive metadata"
            
            # Use metadata file directly if available, or write YOUTUBE_METADATA_JSON to temp file
            # to avoid "argument list too long" error
            metadata_temp_file=""
            if [[ -n "$metadata_file" ]] && [[ -f "$metadata_file" ]]; then
                # Use metadata file directly
                metadata_temp_file="$metadata_file"
                log_debug "Using metadata file directly: $metadata_temp_file"
            elif [[ "$YOUTUBE_METADATA_JSON" != "{}" ]] && [[ -n "$YOUTUBE_METADATA_JSON" ]]; then
                # Write metadata JSON to temp file to avoid argument length limit
                metadata_temp_file=$(mktemp "$HOME/.zen/tmp/youtube_metadata_$$.json" 2>/dev/null || echo "$HOME/.zen/tmp/youtube_metadata_$$.json")
                echo "$YOUTUBE_METADATA_JSON" > "$metadata_temp_file" 2>/dev/null
                log_debug "Wrote metadata JSON to temp file: $metadata_temp_file"
            fi
            
            if [[ -n "$metadata_temp_file" ]] && [[ -f "$metadata_temp_file" ]]; then
                # Use --slurpfile to read metadata from file (avoids argument length limit)
                jq_temp_output=$(jq -n \
                    --arg title "$media_title" \
                    --arg raw_title "$raw_title" \
                    --arg duration "$duration" \
                    --arg uploader "$uploader" \
                    --arg original_url "$URL" \
                    --arg youtube_url "$URL" \
                    --arg filename "$filename" \
                    --arg file_path "$media_file" \
                    --arg output_dir "$OUTPUT_DIR" \
                    --arg metadata_file "${metadata_file:-}" \
                    --arg format "$FORMAT" \
                    --arg file_size "$(stat -c%s "$media_file" 2>/dev/null || echo "0")" \
                    --arg download_date "$(date -Iseconds)" \
                    --slurpfile youtube_metadata "$metadata_temp_file" \
                    '($youtube_metadata[0] // {}) as $yt_meta | {
                    ipfs_url: "",
                    title: $title,
                    raw_title: $raw_title,
                    duration: ($duration | tonumber? // 0),
                    uploader: $uploader,
                    original_url: $original_url,
                    youtube_url: $youtube_url,
                    filename: $filename,
                    file_path: $file_path,
                    output_dir: $output_dir,
                    metadata_file: $metadata_file,
                    metadata_ipfs: "",
                    thumbnail_ipfs: "",
                    subtitles: [],
                    channel_info: {
                        name: ($uploader | gsub("[^a-zA-Z0-9._-]"; "_") | .[0:50]),
                        display_name: $uploader,
                        type: "youtube",
                        channel_id: ($yt_meta.channel_id // ""),
                        channel_url: ($yt_meta.channel_url // ""),
                        uploader_id: ($yt_meta.uploader_id // ""),
                        uploader_url: ($yt_meta.uploader_url // ""),
                        channel_follower_count: ($yt_meta.channel_follower_count // 0)
                    },
                    content_info: {
                        description: ($yt_meta.description // ""),
                        ai_analysis: "",
                        topic_keywords: (($yt_meta.tags // []) | join(", ")),
                        duration_category: (if ($duration | tonumber? // 0) > 0 then 
                            (($duration | tonumber) / 60 | floor) as $mins |
                            if $mins < 5 then "short" elif $mins < 30 then "medium" else "long" end
                        else "" end),
                        categories: ($yt_meta.categories // []),
                        tags: ($yt_meta.tags // []),
                        license: ($yt_meta.license // ""),
                        language: ($yt_meta.language // ""),
                        languages: ($yt_meta.languages // [])
                    },
                    technical_info: {
                        format: $format,
                        file_size: ($file_size | tonumber? // 0),
                        download_date: $download_date,
                        format_id: ($yt_meta.format_id // ""),
                        format_note: ($yt_meta.format_note // ""),
                        width: ($yt_meta.width // 0),
                        height: ($yt_meta.height // 0),
                        fps: ($yt_meta.fps // 0),
                        vcodec: ($yt_meta.vcodec // ""),
                        acodec: ($yt_meta.acodec // ""),
                        abr: ($yt_meta.abr // 0),
                        vbr: ($yt_meta.vbr // 0),
                        tbr: ($yt_meta.tbr // 0),
                        resolution: ($yt_meta.resolution // ""),
                        ext: ($yt_meta.ext // "")
                    },
                    youtube_metadata: $yt_meta,
                    statistics: {
                        view_count: ($yt_meta.view_count // 0),
                        like_count: ($yt_meta.like_count // 0),
                        comment_count: ($yt_meta.comment_count // 0),
                        average_rating: ($yt_meta.average_rating // 0)
                    },
                    dates: {
                        upload_date: ($yt_meta.upload_date // ""),
                        release_date: ($yt_meta.release_date // ""),
                        timestamp: ($yt_meta.timestamp // 0),
                        release_timestamp: ($yt_meta.release_timestamp // 0),
                        modified_timestamp: ($yt_meta.modified_timestamp // 0),
                        modified_date: ($yt_meta.modified_date // "")
                    },
                    media_info: {
                        artist: ($yt_meta.artist // ""),
                        album: ($yt_meta.album // ""),
                        track: ($yt_meta.track // ""),
                        creator: ($yt_meta.creator // ""),
                        alt_title: ($yt_meta.alt_title // ""),
                        series: ($yt_meta.series // ""),
                        season: ($yt_meta.season // ""),
                        season_number: ($yt_meta.season_number // 0),
                        episode: ($yt_meta.episode // ""),
                        episode_number: ($yt_meta.episode_number // 0)
                    },
                    playlist_info: {
                        playlist: ($yt_meta.playlist // ""),
                        playlist_id: ($yt_meta.playlist_id // ""),
                        playlist_title: ($yt_meta.playlist_title // ""),
                        playlist_index: ($yt_meta.playlist_index // 0),
                        n_entries: ($yt_meta.n_entries // 0)
                    },
                    thumbnails: {
                        thumbnail: ($yt_meta.thumbnail // ""),
                        thumbnails: ($yt_meta.thumbnails // [])
                    },
                    subtitles_info: {
                        subtitles: ($yt_meta.subtitles // {}),
                        automatic_captions: ($yt_meta.automatic_captions // {}),
                        requested_subtitles: ($yt_meta.requested_subtitles // {})
                    },
                    chapters: ($yt_meta.chapters // []),
                    location: ($yt_meta.location // ""),
                    age_limit: ($yt_meta.age_limit // 0),
                    live_info: {
                        live_status: ($yt_meta.live_status // ""),
                        was_live: ($yt_meta.was_live // false),
                        is_live: ($yt_meta.is_live // false)
                    }
                }' 2>>"$LOGFILE")
                
                # Clean up temp file if we created it
                if [[ "$metadata_temp_file" != "$metadata_file" ]] && [[ -f "$metadata_temp_file" ]]; then
                    rm -f "$metadata_temp_file" 2>/dev/null
                fi
            else
                # No metadata available, generate basic JSON without metadata
                log_debug "No metadata file available, generating basic JSON"
                jq_temp_output=$(jq -n \
                    --arg title "$media_title" \
                    --arg raw_title "$raw_title" \
                    --arg duration "$duration" \
                    --arg uploader "$uploader" \
                    --arg original_url "$URL" \
                    --arg youtube_url "$URL" \
                    --arg filename "$filename" \
                    --arg file_path "$media_file" \
                    --arg output_dir "$OUTPUT_DIR" \
                    --arg metadata_file "${metadata_file:-}" \
                    --arg format "$FORMAT" \
                    --arg file_size "$(stat -c%s "$media_file" 2>/dev/null || echo "0")" \
                    --arg download_date "$(date -Iseconds)" \
                    '{
                    ipfs_url: "",
                    title: $title,
                    raw_title: $raw_title,
                    duration: ($duration | tonumber? // 0),
                    uploader: $uploader,
                    original_url: $original_url,
                    youtube_url: $youtube_url,
                    filename: $filename,
                    file_path: $file_path,
                    output_dir: $output_dir,
                    metadata_file: $metadata_file,
                    metadata_ipfs: "",
                    thumbnail_ipfs: "",
                    subtitles: [],
                    channel_info: {
                        name: ($uploader | gsub("[^a-zA-Z0-9._-]"; "_") | .[0:50]),
                        display_name: $uploader,
                        type: "youtube"
                    },
                    content_info: {
                        description: "",
                        ai_analysis: "",
                        topic_keywords: "",
                        duration_category: (if ($duration | tonumber? // 0) > 0 then 
                            (($duration | tonumber) / 60 | floor) as $mins |
                            if $mins < 5 then "short" elif $mins < 30 then "medium" else "long" end
                        else "" end)
                    },
                    technical_info: {
                        format: $format,
                        file_size: ($file_size | tonumber? // 0),
                        download_date: $download_date
                    },
                    youtube_metadata: {},
                    statistics: {},
                    dates: {},
                    media_info: {},
                    playlist_info: {},
                    thumbnails: {},
                    subtitles_info: {},
                    chapters: [],
                    location: "",
                    age_limit: 0,
                    live_info: {}
                }' 2>>"$LOGFILE")
            fi
            
            jq_exit_code=$?
            if [[ $jq_exit_code -eq 0 ]] && [[ -n "$jq_temp_output" ]] && [[ "$jq_temp_output" != "{}" ]]; then
                json_output="$jq_temp_output"
                log_debug "JSON generated successfully with jq (length: ${#json_output} chars)"
            else
                log_debug "jq command failed (exit code: $jq_exit_code) or returned empty/invalid JSON"
                log_debug "jq output: ${jq_temp_output:0:200}..."
                log_debug "jq error output saved to: $LOGFILE"
                json_output=""
            fi
        fi
        
        # Use fallback if jq is not available or failed
        if [[ -z "$json_output" ]] || [[ "$json_output" == "{}" ]]; then
            log_debug "Using fallback JSON generation (no jq or jq failed)"
            # Fallback: use jq if available for proper escaping, otherwise use printf with escaped strings
            if command -v jq &> /dev/null; then
                # Use jq for fallback to ensure proper JSON escaping
                json_output=$(jq -n \
                    --arg title "$media_title" \
                    --arg raw_title "$raw_title" \
                    --arg duration "$duration" \
                    --arg uploader "$uploader" \
                    --arg original_url "$URL" \
                    --arg youtube_url "$URL" \
                    --arg filename "$filename" \
                    --arg file_path "$media_file" \
                    --arg output_dir "$OUTPUT_DIR" \
                    --arg metadata_file "${metadata_file:-}" \
                    --arg format "$FORMAT" \
                    --arg file_size "$(stat -c%s "$media_file" 2>/dev/null || echo "0")" \
                    --arg download_date "$(date -Iseconds)" \
                    '{
                    ipfs_url: "",
                    title: $title,
                    raw_title: $raw_title,
                    duration: ($duration | tonumber? // 0),
                    uploader: $uploader,
                    original_url: $original_url,
                    youtube_url: $youtube_url,
                    filename: $filename,
                    file_path: $file_path,
                    output_dir: $output_dir,
                    metadata_file: $metadata_file,
                    metadata_ipfs: "",
                    thumbnail_ipfs: "",
                    subtitles: [],
                    channel_info: {
                        name: ($uploader | gsub("[^a-zA-Z0-9._-]"; "_") | .[0:50]),
                        display_name: $uploader,
                        type: "youtube"
                    },
                    content_info: {
                        description: "",
                        ai_analysis: "",
                        topic_keywords: "",
                        duration_category: (if ($duration | tonumber? // 0) > 0 then 
                            (($duration | tonumber) / 60 | floor) as $mins |
                            if $mins < 5 then "short" elif $mins < 30 then "medium" else "long" end
                        else "" end)
                    },
                    technical_info: {
                        format: $format,
                        file_size: ($file_size | tonumber? // 0),
                        download_date: $download_date
                    },
                    youtube_metadata: {},
                    statistics: {},
                    dates: {},
                    media_info: {},
                    playlist_info: {},
                    thumbnails: {},
                    subtitles_info: {},
                    chapters: [],
                    location: "",
                    age_limit: 0,
                    live_info: {}
                }' 2>/dev/null || echo "")
            fi
            
            # If jq fallback also failed or jq not available, use printf with manual escaping
            if [[ -z "$json_output" ]] || [[ "$json_output" == "{}" ]]; then
                # Escape JSON special characters manually
                escape_json() {
                    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
                }
                escaped_title=$(escape_json "$media_title")
                escaped_raw_title=$(escape_json "$raw_title")
                escaped_uploader=$(escape_json "$uploader")
                escaped_url=$(escape_json "$URL")
                escaped_filename=$(escape_json "$filename")
                escaped_file_path=$(escape_json "$media_file")
                escaped_output_dir=$(escape_json "$OUTPUT_DIR")
                escaped_metadata_file=$(escape_json "${metadata_file:-}")
                duration_category=""
                if [[ -n "$duration" && "$duration" =~ ^[0-9]+$ ]]; then
                    duration_min=$((duration / 60))
                    if [[ $duration_min -lt 5 ]]; then
                        duration_category="short"
                    elif [[ $duration_min -lt 30 ]]; then
                        duration_category="medium"
                    else
                        duration_category="long"
                    fi
                fi
                file_size=$(stat -c%s "$media_file" 2>/dev/null || echo "0")
                download_date=$(date -Iseconds)
                
                json_output=$(printf '{
  "ipfs_url": "",
  "title": "%s",
  "raw_title": "%s",
  "duration": "%s",
  "uploader": "%s",
  "original_url": "%s",
  "youtube_url": "%s",
  "filename": "%s",
  "file_path": "%s",
  "output_dir": "%s",
  "metadata_file": "%s",
  "metadata_ipfs": "",
  "thumbnail_ipfs": "",
  "subtitles": [],
  "channel_info": {
    "name": "%s",
    "display_name": "%s",
    "type": "youtube"
  },
  "content_info": {
    "description": "",
    "ai_analysis": "",
    "topic_keywords": "",
    "duration_category": "%s"
  },
  "technical_info": {
    "format": "%s",
    "file_size": "%s",
    "download_date": "%s"
  },
  "youtube_metadata": {},
  "statistics": {},
  "dates": {},
  "media_info": {},
  "playlist_info": {},
  "thumbnails": {},
  "subtitles_info": {},
  "chapters": [],
  "location": "",
  "age_limit": 0,
  "live_info": {}
}' "$escaped_title" "$escaped_raw_title" "$duration" "$escaped_uploader" "$escaped_url" "$escaped_url" "$escaped_filename" "$escaped_file_path" "$escaped_output_dir" "$escaped_metadata_file" "$(echo "$uploader" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)" "$escaped_uploader" "$duration_category" "$FORMAT" "$file_size" "$download_date")
            fi
        fi
        
        # Validate that file_path is in JSON before outputting
        if command -v jq &> /dev/null; then
            if ! echo "$json_output" | jq -e '.file_path' >/dev/null 2>&1; then
                log_debug "ERROR: file_path missing from JSON output"
                log_debug "media_file value: '$media_file'"
                log_debug "JSON preview: ${json_output:0:500}..."
                error_json="{\"error\":\"Failed to include file_path in JSON output\",\"success\":false}"
                output_json "$error_json"
                exit 1
            fi
            log_debug "JSON file_path validated: $(echo "$json_output" | jq -r '.file_path // "MISSING"')"
        else
            # Without jq, check if file_path appears in JSON string
            if ! echo "$json_output" | grep -q "\"file_path\""; then
                log_debug "ERROR: file_path missing from JSON output (no jq available)"
                log_debug "media_file value: '$media_file'"
                log_debug "JSON preview: ${json_output:0:500}..."
                error_json="{\"error\":\"Failed to include file_path in JSON output\",\"success\":false}"
                output_json "$error_json"
                exit 1
            fi
            log_debug "JSON file_path found in output (no jq validation)"
        fi
        
        # Use output_json function to write to file and stdout
        output_json "$json_output"
        
        log_debug "Success JSON outputted. File ready for /api/fileupload workflow."
        if command -v jq &> /dev/null; then
            log_debug "JSON file_path: $(echo "$json_output" | jq -r '.file_path // "MISSING"')"
        fi
        exit 0
    fi
fi

log_debug "Download failed."
# Output JSON to stdout (not stderr) to avoid broken pipe issues
echo '{"error":"❌ Download failed with all strategies"}' 2>/dev/null || echo '{"error":"Download failed with all strategies"}'
exit 1
