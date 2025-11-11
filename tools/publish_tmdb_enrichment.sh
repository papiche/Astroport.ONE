#!/bin/bash
################################################################################
# publish_tmdb_enrichment.sh - Publish TMDB Metadata Enrichment Events (NIP-71 Extension)
#
# This script publishes kind 1986 events to enrich or correct TMDB metadata
# for video events (kind 21/22). It follows the NIP-71 TMDB Metadata Enrichment Extension.
#
# USAGE:
#   # Correction mode
#   ./publish_tmdb_enrichment.sh \
#       --nsec <nsec_key_or_file> \
#       --video-event-id <event_id> \
#       --video-kind <21|22> \
#       --type correction \
#       --tmdb-json <path_to_tmdb_metadata.json> \
#       [--reason "Explanation"] \
#       [--source "tmdb.org"] \
#       [--json]
#
#   # Enrichment mode
#   ./publish_tmdb_enrichment.sh \
#       --nsec <nsec_key_or_file> \
#       --video-event-id <event_id> \
#       --video-kind <21|22> \
#       --type enrichment \
#       --tmdb-json <path_to_tmdb_metadata.json> \
#       [--reason "Explanation"] \
#       [--json]
#
#   # Author update mode (replaceable, kind 30001)
#   ./publish_tmdb_enrichment.sh \
#       --nsec <nsec_key_or_file> \
#       --video-event-id <event_id> \
#       --video-kind <21|22> \
#       --type author_update \
#       --tmdb-json <path_to_tmdb_metadata.json> \
#       [--reason "Explanation"] \
#       [--json]
#
# RETURNS:
#   - Exit code 0 on success
#   - JSON output if --json flag is set
#   - Event ID printed to stdout
#
################################################################################

# Find uSPOT ENV
source $HOME/.zen/Astroport.ONE/tools/my.sh

# Default values
RELAYS="ws://127.0.0.1:7777,wss://relay.copylaradio.com"
ENRICHMENT_TYPE="enrichment"
JSON_OUTPUT=false
NOSTR_SCRIPT="${HOME}/.zen/Astroport.ONE/tools/nostr_send_note.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    if [ "$JSON_OUTPUT" != "true" ]; then
        echo -e "${BLUE}ℹ${NC} $1" >&2
    fi
}

log_success() {
    if [ "$JSON_OUTPUT" != "true" ]; then
        echo -e "${GREEN}✓${NC} $1" >&2
    fi
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    if [ "$JSON_OUTPUT" != "true" ]; then
        echo -e "${YELLOW}⚠${NC} $1" >&2
    fi
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 --nsec <nsec_key_or_file> --video-event-id <event_id> --video-kind <21|22> --type <type> --tmdb-json <json_file> [OPTIONS]

Required arguments:
  --nsec <key_or_file>      NSEC private key (nsec1...) or path to .secret.nostr file
  --video-event-id <id>      Event ID of the video event (kind 21/22) to enrich
  --video-kind <21|22>       Kind of the target video event
  --type <type>              Type of enrichment: correction, enrichment, update, or author_update
  --tmdb-json <file>         Path to JSON file containing TMDB metadata to add/correct

Optional arguments:
  --reason <text>            Explanation for the enrichment
  --source <text>            Source of the correction (e.g., "tmdb.org")
  --relays <urls>            Comma-separated relay URLs (default: local+copylaradio)
  --json                     Output JSON format
  --help                     Show this help message

Examples:
  # Correction
  $0 --nsec ~/.zen/secret.nostr \\
     --video-event-id abc123... \\
     --video-kind 21 \\
     --type correction \\
     --tmdb-json /tmp/tmdb_correction.json \\
     --reason "Corrected title spelling" \\
     --json

  # Author update (replaceable)
  $0 --nsec ~/.zen/secret.nostr \\
     --video-event-id abc123... \\
     --video-kind 21 \\
     --type author_update \\
     --tmdb-json /tmp/tmdb_update.json \\
     --json
EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --nsec)
            NSEC_INPUT="$2"
            shift 2
            ;;
        --video-event-id)
            VIDEO_EVENT_ID="$2"
            shift 2
            ;;
        --video-kind)
            VIDEO_KIND="$2"
            shift 2
            ;;
        --type)
            ENRICHMENT_TYPE="$2"
            shift 2
            ;;
        --tmdb-json)
            TMDB_JSON_FILE="$2"
            shift 2
            ;;
        --reason)
            REASON="$2"
            shift 2
            ;;
        --source)
            SOURCE="$2"
            shift 2
            ;;
        --relays)
            RELAYS="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$NSEC_INPUT" ]; then
    log_error "Missing required argument: --nsec"
    usage
fi

if [ -z "$VIDEO_EVENT_ID" ]; then
    log_error "Missing required argument: --video-event-id"
    usage
fi

if [ -z "$VIDEO_KIND" ]; then
    log_error "Missing required argument: --video-kind"
    usage
fi

if [ -z "$TMDB_JSON_FILE" ] || [ ! -f "$TMDB_JSON_FILE" ]; then
    log_error "Missing or invalid TMDB JSON file: --tmdb-json"
    usage
fi

# Validate enrichment type
if [[ "$ENRICHMENT_TYPE" != "correction" ]] && \
   [[ "$ENRICHMENT_TYPE" != "enrichment" ]] && \
   [[ "$ENRICHMENT_TYPE" != "update" ]] && \
   [[ "$ENRICHMENT_TYPE" != "author_update" ]]; then
    log_error "Invalid enrichment type: $ENRICHMENT_TYPE (must be: correction, enrichment, update, or author_update)"
    usage
fi

# Validate video kind
if [[ "$VIDEO_KIND" != "21" ]] && [[ "$VIDEO_KIND" != "22" ]]; then
    log_error "Invalid video kind: $VIDEO_KIND (must be 21 or 22)"
    usage
fi

# Extract NSEC key
if [ -f "$NSEC_INPUT" ]; then
    log_info "Reading NSEC from file: $NSEC_INPUT"
    NSEC_KEY=$(grep -oP 'NSEC=\K[^\s;]+' "$NSEC_INPUT" 2>/dev/null || echo "")
    if [ -z "$NSEC_KEY" ]; then
        log_error "Could not extract NSEC from file: $NSEC_INPUT"
        exit 1
    fi
    KEYFILE="$NSEC_INPUT"
else
    NSEC_KEY="$NSEC_INPUT"
    TEMP_KEYFILE=$(mktemp)
    echo "NSEC=$NSEC_KEY" > "$TEMP_KEYFILE"
    KEYFILE="$TEMP_KEYFILE"
    log_info "Using provided NSEC key"
fi

# Read and validate TMDB JSON
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not found"
    exit 1
fi

if ! jq -e '.' "$TMDB_JSON_FILE" >/dev/null 2>&1; then
    log_error "Invalid JSON in TMDB file: $TMDB_JSON_FILE"
    exit 1
fi

TMDB_JSON=$(cat "$TMDB_JSON_FILE")

# Build content JSON
CONTENT_JSON="{}"
CONTENT_JSON=$(echo "$CONTENT_JSON" | jq --argjson tmdb "$TMDB_JSON" '.tmdb = $tmdb' 2>/dev/null || echo "$CONTENT_JSON")

if [ -n "$REASON" ]; then
    CONTENT_JSON=$(echo "$CONTENT_JSON" | jq --arg reason "$REASON" '.reason = $reason' 2>/dev/null || echo "$CONTENT_JSON")
fi

if [ -n "$SOURCE" ]; then
    CONTENT_JSON=$(echo "$CONTENT_JSON" | jq --arg source "$SOURCE" '.source = $source' 2>/dev/null || echo "$CONTENT_JSON")
fi

# Determine event kind
if [[ "$ENRICHMENT_TYPE" == "author_update" ]]; then
    EVENT_KIND="30001"  # Replaceable event for author updates
    log_info "Using kind 30001 (replaceable) for author update"
else
    EVENT_KIND="1986"  # Non-replaceable for community enrichments
    log_info "Using kind 1986 (non-replaceable) for community enrichment"
fi

# Build tags
TAGS="[
    [\"e\", \"${VIDEO_EVENT_ID}\", \"${RELAYS%%,*}\"],
    [\"k\", \"${VIDEO_KIND}\"],
    [\"L\", \"tmdb.metadata\"],
    [\"l\", \"${ENRICHMENT_TYPE}\", \"tmdb.metadata\"]"

# Add 'd' tag for replaceable events (author updates)
if [[ "$EVENT_KIND" == "30001" ]]; then
    TAGS="${TAGS},
    [\"d\", \"tmdb-metadata\"]"
fi

# Close tags array
TAGS="${TAGS}
]"

# Check if nostr_send_note.py exists
if [ ! -f "$NOSTR_SCRIPT" ]; then
    log_error "NOSTR script not found: $NOSTR_SCRIPT"
    [ -n "$TEMP_KEYFILE" ] && rm -f "$TEMP_KEYFILE"
    exit 1
fi

# Publish to NOSTR
log_info "Publishing TMDB metadata enrichment event..."

# Determine which Python3 to use
PYTHON_CMD="python3"
if [ -x "$HOME/.astro/bin/python3" ]; then
    PYTHON_CMD="$HOME/.astro/bin/python3"
elif [ -x "/usr/bin/python3" ]; then
    PYTHON_CMD="/usr/bin/python3"
fi

log_info "Using Python: $PYTHON_CMD"

# Convert content JSON to string
CONTENT_STR=$(echo "$CONTENT_JSON" | jq -c '.' 2>/dev/null || echo "$CONTENT_JSON")

# Execute nostr_send_note.py
NOSTR_OUTPUT=$($PYTHON_CMD "$NOSTR_SCRIPT" \
    --keyfile "$KEYFILE" \
    --content "$CONTENT_STR" \
    --relays "$RELAYS" \
    --tags "$TAGS" \
    --kind "$EVENT_KIND" \
    --json 2>&1)

NOSTR_EXIT_CODE=$?

# Clean up temporary keyfile if created
[ -n "$TEMP_KEYFILE" ] && rm -f "$TEMP_KEYFILE"

# Check result
if [ $NOSTR_EXIT_CODE -eq 0 ]; then
    # Parse JSON output
    EVENT_ID=$(echo "$NOSTR_OUTPUT" | jq -r '.event_id // empty' 2>/dev/null || echo "")
    RELAYS_SUCCESS=$(echo "$NOSTR_OUTPUT" | jq -r '.relays_success // 0' 2>/dev/null || echo "0")
    RELAYS_TOTAL=$(echo "$NOSTR_OUTPUT" | jq -r '.relays_total // 0' 2>/dev/null || echo "0")
    
    if [ -z "$EVENT_ID" ]; then
        # Fallback to old parsing method
        EVENT_ID=$(echo "$NOSTR_OUTPUT" | grep -oP '(Event ID:|event_id:|- ID:)\s*\K[a-f0-9]{64}' | head -1 || echo "")
    fi
    
    if [ -n "$EVENT_ID" ]; then
        log_success "TMDB metadata enrichment event published successfully!"
        log_success "Event ID: $EVENT_ID"
        log_success "Kind: $EVENT_KIND"
        log_success "Type: $ENRICHMENT_TYPE"
        log_success "Published to $RELAYS_SUCCESS/$RELAYS_TOTAL relay(s)"
        
        if [ "$JSON_OUTPUT" = "true" ]; then
            cat << EOF
{
  "success": true,
  "event_id": "$EVENT_ID",
  "kind": $EVENT_KIND,
  "type": "$ENRICHMENT_TYPE",
  "relays_success": $RELAYS_SUCCESS,
  "relays_total": $RELAYS_TOTAL,
  "video_event_id": "$VIDEO_EVENT_ID",
  "video_kind": $VIDEO_KIND
}
EOF
        else
            echo "$EVENT_ID"
        fi
        exit 0
    else
        log_error "Event published but could not extract event ID"
        log_error "Output: $NOSTR_OUTPUT"
        exit 1
    fi
else
    log_error "Failed to publish NOSTR event (exit code: $NOSTR_EXIT_CODE)"
    log_error "Output: $NOSTR_OUTPUT"
    if [ "$JSON_OUTPUT" = "true" ]; then
        cat << EOF
{
  "success": false,
  "error": "Failed to publish NOSTR event",
  "exit_code": $NOSTR_EXIT_CODE,
  "output": "$NOSTR_OUTPUT"
}
EOF
    fi
    exit 1
fi

