#!/bin/bash
################################################################################
# Script: nostr_get_events.sh
# Description: Query NOSTR events from local strfry relay with flexible filters
# Usage: nostr_get_events.sh [OPTIONS]
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

################################################################################
# Default values
################################################################################
KIND=""
AUTHOR=""
LIMIT=100
SINCE=""
UNTIL=""
TAG_D=""
TAG_P=""
TAG_E=""
OUTPUT_FORMAT="json"  # json or count

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
Usage: nostr_get_events.sh [OPTIONS]

Query NOSTR events from local strfry relay with flexible filters.

OPTIONS:
    -k, --kind KIND           Filter by event kind (e.g., 30500, 30501, 1)
    -a, --author HEX          Filter by author pubkey (hex format)
    -d, --tag-d VALUE         Filter by 'd' tag (identifier for parameterized replaceable events)
    -p, --tag-p HEX           Filter by 'p' tag (mentioned pubkey)
    -e, --tag-e ID            Filter by 'e' tag (referenced event)
    -s, --since TIMESTAMP     Filter events after this timestamp (unix timestamp)
    -u, --until TIMESTAMP     Filter events before this timestamp (unix timestamp)
    -l, --limit NUMBER        Limit number of results (default: 100)
    -o, --output FORMAT       Output format: 'json' or 'count' (default: json)
    -h, --help                Show this help message

EXAMPLES:
    # Get all permit definitions (kind 30500)
    nostr_get_events.sh --kind 30500

    # Get permit requests by specific author
    nostr_get_events.sh --kind 30501 --author a1b2c3d4e5f6...

    # Get specific permit request by identifier
    nostr_get_events.sh --kind 30501 --tag-d "req_abc123"

    # Get credentials for a specific holder
    nostr_get_events.sh --kind 30503 --tag-p "holder_pubkey_hex"

    # Count recent events (last 24 hours)
    nostr_get_events.sh --kind 1 --since \$(date -d '24 hours ago' +%s) --output count

    # Get events with limit
    nostr_get_events.sh --kind 1 --limit 10

NOTES:
    - Requires strfry relay to be running at ~/.zen/strfry/
    - Returns events in JSON format (one per line)
    - Use jq for further JSON processing: nostr_get_events.sh --kind 1 | jq '.'

EOF
    exit 0
}

################################################################################
# Parse arguments
################################################################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--kind)
            KIND="$2"
            shift 2
            ;;
        -a|--author)
            AUTHOR="$2"
            shift 2
            ;;
        -d|--tag-d)
            TAG_D="$2"
            shift 2
            ;;
        -p|--tag-p)
            TAG_P="$2"
            shift 2
            ;;
        -e|--tag-e)
            TAG_E="$2"
            shift 2
            ;;
        -s|--since)
            SINCE="$2"
            shift 2
            ;;
        -u|--until)
            UNTIL="$2"
            shift 2
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

################################################################################
# Check strfry exists
################################################################################
STRFRY_DIR="$HOME/.zen/strfry"
STRFRY_BIN="${STRFRY_DIR}/strfry"

if [[ ! -f "${STRFRY_BIN}" ]]; then
    echo "[ERROR] strfry not found at ${STRFRY_BIN}" >&2
    echo "[INFO] Please install strfry relay first" >&2
    exit 1
fi

################################################################################
# Build filter JSON
################################################################################
FILTER="{"

# Add kinds filter
if [[ -n "$KIND" ]]; then
    FILTER+="\"kinds\":[$KIND]"
fi

# Add authors filter
if [[ -n "$AUTHOR" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"authors\":[\"$AUTHOR\"]"
fi

# Add since filter
if [[ -n "$SINCE" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"since\":$SINCE"
fi

# Add until filter
if [[ -n "$UNTIL" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"until\":$UNTIL"
fi

# Add limit filter
if [[ -n "$LIMIT" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"limit\":$LIMIT"
fi

# Add tag filters
if [[ -n "$TAG_D" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"#d\":[\"$TAG_D\"]"
fi

if [[ -n "$TAG_P" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"#p\":[\"$TAG_P\"]"
fi

if [[ -n "$TAG_E" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"#e\":[\"$TAG_E\"]"
fi

FILTER+="}"

################################################################################
# Query strfry
################################################################################
cd "$STRFRY_DIR" || exit 1

# Execute query
if [[ "$OUTPUT_FORMAT" == "count" ]]; then
    # Count mode: just count lines
    COUNT=$(./strfry scan "$FILTER" 2>/dev/null | wc -l)
    echo "$COUNT"
else
    # JSON mode: output events
    ./strfry scan "$FILTER" 2>/dev/null
fi

cd - > /dev/null 2>&1

exit 0

