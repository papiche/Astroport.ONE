#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# SCRIPT POUR TRAITER ET AVALER DIFFÉRENTS TYPES DE MÉDIAS
# Crée un JSON compatible avec le format blog Nostr
# Traite: vidéos, pages web (→PDF→image), YouTube (→MP3), PDF
########################################################################

# Help function
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <input>

Process different media types and generate Nostr blog compatible JSON.

OPTIONS:
    -h, --help          Show this help message and exit
    -v, --verbose       Enable verbose output
    -d, --debug         Enable debug mode with detailed logging
    -o, --output        Output directory (default: ~/.zen/tmp/swallow)
    -p, --publish       Auto-publish to Nostr after processing
    -t, --title         Custom title for the content
    -c, --content       Custom content/description
    -g, --tags          Comma-separated tags

INPUT TYPES:
    - Video files (mp4, avi, mov, etc.)
    - Web URLs (converted to PDF then image)
    - YouTube URLs (extracted as MP3)
    - PDF files
    - Image files

EXAMPLES:
    $(basename "$0") /path/to/video.mp4
    $(basename "$0") -t "My Video" -c "Amazing content" /path/to/video.mp4
    $(basename "$0") -p https://example.com
    $(basename "$0") -g "video,art,nostr" https://youtube.com/watch?v=abc123

REQUIREMENTS:
    - ffmpeg (for video processing)
    - ffprobe (for video metadata)
    - ipfs (for IPFS operations)
    - yt-dlp (for YouTube downloads)
    - chromium (for web to PDF conversion)
    - bc (for calculations)

EXIT CODES:
    0 - Success
    1 - File not found or invalid parameters
    2 - Missing required tools
    3 - Processing error

EOF
}

# Parse command line arguments
VERBOSE=0
DEBUG=0
OUTPUT_DIR=""
AUTO_PUBLISH=0
CUSTOM_TITLE=""
CUSTOM_CONTENT=""
CUSTOM_TAGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -d|--debug)
            DEBUG=1
            VERBOSE=1
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--publish)
            AUTO_PUBLISH=1
            shift
            ;;
        -t|--title)
            CUSTOM_TITLE="$2"
            shift 2
            ;;
        -c|--content)
            CUSTOM_CONTENT="$2"
            shift 2
            ;;
        -g|--tags)
            CUSTOM_TAGS="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check if we have the required number of arguments
if [[ $# -ne 1 ]]; then
    echo "Error: Invalid number of arguments" >&2
    echo "Usage: $(basename "$0") [OPTIONS] <input>" >&2
    echo "Use --help for more information" >&2
    exit 1
fi

INPUT="$1"

# Set default output directory
[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$HOME/.zen/tmp/swallow"

# Check for required tools
check_requirements() {
    local missing_tools=()
    
    if ! command -v ffmpeg &> /dev/null; then
        missing_tools+=("ffmpeg")
    fi
    
    if ! command -v ffprobe &> /dev/null; then
        missing_tools+=("ffprobe")
    fi
    
    if ! command -v ipfs &> /dev/null; then
        missing_tools+=("ipfs")
    fi
    
    if ! command -v yt-dlp &> /dev/null; then
        missing_tools+=("yt-dlp")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "Error: Missing required tools: ${missing_tools[*]}" >&2
        echo "Please install the missing tools and try again." >&2
        exit 2
    fi
}

# Validate input
validate_input() {
    local input="$1"
    
    # Check if it's a URL
    if [[ "$input" =~ ^https?:// ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "Input is a URL: $input"
        return 0
    fi
    
    # Check if it's a local file
    if [[ -f "$input" ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "Input is a local file: $input"
        return 0
    fi
    
    echo "Error: Input '$input' is neither a valid URL nor an existing file" >&2
    exit 1
}

# Detect input type
detect_input_type() {
    local input="$1"
    
    if [[ "$input" =~ ^https?:// ]]; then
        if [[ "$input" =~ youtube\.com|youtu\.be ]]; then
            echo "youtube"
        else
            echo "web"
        fi
    else
        local ext="${input##*.}"
        case $ext in
            mp4|avi|mov|mkv|webm|flv) echo "video" ;;
            pdf) echo "pdf" ;;
            jpg|jpeg|png|gif|webp|bmp) echo "image" ;;
            *) echo "unknown" ;;
        esac
    fi
}

# Process video file
process_video() {
    local input="$1"
    local output_dir="$2"
    
    [[ $VERBOSE -eq 1 ]] && echo "Processing video: $input"
    
    # Get video metadata
    local duration=$(ffprobe -v error -i "$input" -show_entries format=duration -v quiet -of csv="p=0" | cut -d '.' -f 1)
    local duree=$(ffprobe -v error -i "$input" -show_entries format=duration -sexagesimal -v quiet -of csv="p=0" | cut -d '.' -f 1)
    local resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$input")
    local file_size=$(du -b "$input" | awk '{print $1}')
    
    # Calculate Phi ratio time for GIF
    local probetime=$(echo "0.618 * $duration" | bc -l | cut -d '.' -f 1)
    [[ ! $probetime ]] && probetime="1.0"
    
    # Create GIF animation
    local gif_file="$output_dir/screen.gif"
    ffmpeg -loglevel quiet -ss $probetime -t 1.6 -i "$input" "$gif_file"
    
    # Add to IPFS
    local gif_hash=$(ipfs add -q "$gif_file")
    local video_hash=$(ipfs add -q "$input")
    
    # Create video info
    cat > "$output_dir/video_info.json" << EOF
{
    "type": "video",
    "duration": "$duration",
    "duree": "$duree",
    "resolution": "$resolution",
    "file_size": "$file_size",
    "probetime": "$probetime",
    "gif_hash": "$gif_hash",
    "video_hash": "$video_hash",
    "gif_url": "/ipfs/$gif_hash",
    "video_url": "/ipfs/$video_hash"
}
EOF
    
    echo "$output_dir/video_info.json"
}

# Process web URL
process_web() {
    local url="$1"
    local output_dir="$2"
    
    [[ $VERBOSE -eq 1 ]] && echo "Processing web URL: $url"
    
    # Convert web page to PDF
    local pdf_file="$output_dir/webpage.pdf"
    chromium --headless --use-mobile-user-agent --no-sandbox --print-to-pdf "$url" --output="$pdf_file"
    
    if [[ ! -f "$pdf_file" ]]; then
        echo "Error: Failed to convert web page to PDF" >&2
        return 1
    fi
    
    # Convert PDF to image
    local image_file="$output_dir/webpage.png"
    convert "$pdf_file[0]" "$image_file"
    
    # Add to IPFS
    local pdf_hash=$(ipfs add -q "$pdf_file")
    local image_hash=$(ipfs add -q "$image_file")
    
    # Create web info
    cat > "$output_dir/web_info.json" << EOF
{
    "type": "web",
    "url": "$url",
    "pdf_hash": "$pdf_hash",
    "image_hash": "$image_hash",
    "pdf_url": "/ipfs/$pdf_hash",
    "image_url": "/ipfs/$image_hash"
}
EOF
    
    echo "$output_dir/web_info.json"
}

# Process YouTube URL
process_youtube() {
    local url="$1"
    local output_dir="$2"
    
    [[ $VERBOSE -eq 1 ]] && echo "Processing YouTube URL: $url"
    
    # Get video info
    local video_info=$(yt-dlp --print "%(id)s&%(title)s&%(duration)s" "$url")
    local video_id=$(echo "$video_info" | cut -d '&' -f 1)
    local title=$(echo "$video_info" | cut -d '&' -f 2- | detox --inline)
    local duration=$(echo "$video_info" | cut -d '&' -f 3)
    
    # Download as MP3
    local mp3_file="$output_dir/${title}.mp3"
    yt-dlp -x --audio-format mp3 --no-mtime --embed-thumbnail --add-metadata -o "$mp3_file" "$url"
    
    if [[ ! -f "$mp3_file" ]]; then
        echo "Error: Failed to download YouTube video as MP3" >&2
        return 1
    fi
    
    # Add to IPFS
    local mp3_hash=$(ipfs add -q "$mp3_file")
    
    # Create YouTube info
    cat > "$output_dir/youtube_info.json" << EOF
{
    "type": "youtube",
    "url": "$url",
    "video_id": "$video_id",
    "title": "$title",
    "duration": "$duration",
    "mp3_hash": "$mp3_hash",
    "mp3_url": "/ipfs/$mp3_hash"
}
EOF
    
    echo "$output_dir/youtube_info.json"
}

# Process PDF file
process_pdf() {
    local input="$1"
    local output_dir="$2"
    
    [[ $VERBOSE -eq 1 ]] && echo "Processing PDF: $input"
    
    # Convert first page to image
    local image_file="$output_dir/pdf_page.png"
    convert "$input[0]" "$image_file"
    
    # Add to IPFS
    local pdf_hash=$(ipfs add -q "$input")
    local image_hash=$(ipfs add -q "$image_file")
    
    # Create PDF info
    cat > "$output_dir/pdf_info.json" << EOF
{
    "type": "pdf",
    "pdf_hash": "$pdf_hash",
    "image_hash": "$image_hash",
    "pdf_url": "/ipfs/$pdf_hash",
    "image_url": "/ipfs/$image_hash"
}
EOF
    
    echo "$output_dir/pdf_info.json"
}

# Process image file
process_image() {
    local input="$1"
    local output_dir="$2"
    
    [[ $VERBOSE -eq 1 ]] && echo "Processing image: $input"
    
    # Get image metadata
    local dimensions=$(identify -format "%wx%h" "$input" 2>/dev/null)
    local file_size=$(du -b "$input" | awk '{print $1}')
    
    # Add to IPFS
    local image_hash=$(ipfs add -q "$input")
    
    # Create image info
    cat > "$output_dir/image_info.json" << EOF
{
    "type": "image",
    "dimensions": "$dimensions",
    "file_size": "$file_size",
    "image_hash": "$image_hash",
    "image_url": "/ipfs/$image_hash"
}
EOF
    
    echo "$output_dir/image_info.json"
}

# Generate Nostr blog JSON
generate_nostr_json() {
    local info_file="$1"
    local output_dir="$2"
    local title="$3"
    local content="$4"
    local tags="$5"
    
    [[ $VERBOSE -eq 1 ]] && echo "Generating Nostr blog JSON"
    
    # Read info from processed file
    local info_json=$(cat "$info_file")
    local media_type=$(echo "$info_json" | jq -r '.type')
    local ipfs_url=$(echo "$info_json" | jq -r '.image_url // .video_url // .mp3_url // .pdf_url')
    
    # Generate content based on type
    local nostr_content=""
    case $media_type in
        video)
            local duration=$(echo "$info_json" | jq -r '.duree')
            local resolution=$(echo "$info_json" | jq -r '.resolution')
            nostr_content="🎬 Video: $title\n\nDuration: $duration\nResolution: $resolution\n\n$content"
            ;;
        web)
            local url=$(echo "$info_json" | jq -r '.url')
            nostr_content="🌐 Web Page: $title\n\nSource: $url\n\n$content"
            ;;
        youtube)
            local video_id=$(echo "$info_json" | jq -r '.video_id')
            local duration=$(echo "$info_json" | jq -r '.duration')
            nostr_content="🎵 YouTube Audio: $title\n\nVideo ID: $video_id\nDuration: $duration\n\n$content"
            ;;
        pdf)
            nostr_content="📄 PDF Document: $title\n\n$content"
            ;;
        image)
            local dimensions=$(echo "$info_json" | jq -r '.dimensions')
            nostr_content="🖼️ Image: $title\n\nDimensions: $dimensions\n\n$content"
            ;;
    esac
    
    # Add IPFS link
    nostr_content="$nostr_content\n\n🔗 IPFS: $ipfs_url"
    
    # Generate tags
    local nostr_tags=""
    if [[ -n "$tags" ]]; then
        nostr_tags=$(echo "$tags" | tr ',' '\n' | sed 's/^/["t", "/' | sed 's/$/"]/' | tr '\n' ' ')
    fi
    
    # Create Nostr event JSON
    local timestamp=$(date +%s)
    local event_id=$(echo -n "$timestamp$nostr_content" | sha256sum | cut -d ' ' -f 1)
    
    cat > "$output_dir/nostr_event.json" << EOF
{
    "id": "$event_id",
    "pubkey": "YOUR_PUBKEY_HERE",
    "created_at": $timestamp,
    "kind": 1,
    "tags": [
        ["t", "swallow"],
        ["t", "$media_type"]
        $nostr_tags
    ],
    "content": $(echo "$nostr_content" | jq -R .),
    "sig": "YOUR_SIGNATURE_HERE"
}
EOF
    
    echo "$output_dir/nostr_event.json"
}

# Publish to Nostr (placeholder)
publish_to_nostr() {
    local event_file="$1"
    
    [[ $VERBOSE -eq 1 ]] && echo "Publishing to Nostr..."
    
    echo "⚠️  Nostr publishing is not implemented yet."
    echo "📄 Event JSON saved to: $event_file"
    echo "🔧 You can manually publish using your Nostr client."
}

# Main execution
main() {
    # Check requirements and validate input
    check_requirements
    validate_input "$INPUT"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Set up logging if debug mode is enabled
    if [[ $DEBUG -eq 1 ]]; then
        exec 2>&1 >> ~/.zen/tmp/swallow_me.log
    fi
    
    # Detect input type
    local input_type=$(detect_input_type "$INPUT")
    [[ $VERBOSE -eq 1 ]] && echo "Detected input type: $input_type"
    
    # Process based on type
    local info_file=""
    case $input_type in
        video)
            info_file=$(process_video "$INPUT" "$OUTPUT_DIR")
            ;;
        web)
            info_file=$(process_web "$INPUT" "$OUTPUT_DIR")
            ;;
        youtube)
            info_file=$(process_youtube "$INPUT" "$OUTPUT_DIR")
            ;;
        pdf)
            info_file=$(process_pdf "$INPUT" "$OUTPUT_DIR")
            ;;
        image)
            info_file=$(process_image "$INPUT" "$OUTPUT_DIR")
            ;;
        *)
            echo "Error: Unsupported input type: $input_type" >&2
            exit 1
            ;;
    esac
    
    if [[ ! -f "$info_file" ]]; then
        echo "Error: Failed to process input" >&2
        exit 3
    fi
    
    # Generate title and content
    local title="$CUSTOM_TITLE"
    local content="$CUSTOM_CONTENT"
    
    if [[ -z "$title" ]]; then
        case $input_type in
            video|image|pdf)
                title=$(basename "$INPUT" | sed 's/\.[^.]*$//')
                ;;
            web)
                title=$(echo "$INPUT" | sed 's|^https?://||' | sed 's|/.*$||')
                ;;
            youtube)
                title=$(cat "$info_file" | jq -r '.title')
                ;;
        esac
    fi
    
    if [[ -z "$content" ]]; then
        content="Processed with swallow_me.sh"
    fi
    
    # Generate Nostr JSON
    local nostr_file=$(generate_nostr_json "$info_file" "$OUTPUT_DIR" "$title" "$content" "$CUSTOM_TAGS")
    
    # Publish if requested
    if [[ $AUTO_PUBLISH -eq 1 ]]; then
        publish_to_nostr "$nostr_file"
    fi
    
    # Output results
    echo "✅ Processing completed successfully!"
    echo "📁 Output directory: $OUTPUT_DIR"
    echo "📄 Info file: $info_file"
    echo "📝 Nostr event: $nostr_file"
    
    if [[ $VERBOSE -eq 1 ]]; then
        echo ""
        echo "📋 Generated Nostr event:"
        cat "$nostr_file" | jq .
    fi
    
    exit 0
}

# Run main function
main "$@" 