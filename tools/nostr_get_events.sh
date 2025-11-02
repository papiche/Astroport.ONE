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
declare -a AUTHORS=()  # Array to support multiple authors
LIMIT=100
SINCE=""
UNTIL=""
TAG_D=""
TAG_P=""
TAG_E=""
TAG_T=""
TAG_G=""
OUTPUT_FORMAT="json"  # json or count
DELETE_MODE=false      # Delete found events
FORCE_MODE=false       # Skip confirmation prompt

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
                              Can be specified multiple times or as comma-separated list
    -d, --tag-d VALUE         Filter by 'd' tag (identifier for parameterized replaceable events)
    -p, --tag-p HEX           Filter by 'p' tag (mentioned pubkey)
    -e, --tag-e ID            Filter by 'e' tag (referenced event)
    -t, --tag-t VALUE         Filter by 't' tag (hashtag, e.g., "plantnet", "UPlanet")
    -g, --tag-g COORDS        Filter by 'g' tag (geolocation, format: "lat,lon")
    -s, --since TIMESTAMP     Filter events after this timestamp (unix timestamp)
    -u, --until TIMESTAMP     Filter events before this timestamp (unix timestamp)
    -l, --limit NUMBER        Limit number of results (default: 100)
    -o, --output FORMAT       Output format: 'json' or 'count' (default: json)
        --del                 Delete found events (⚠️  DESTRUCTIVE - use with caution!)
        --force               Skip confirmation prompt when using --del (⚠️  VERY DANGEROUS!)
    -h, --help                Show this help message

EXAMPLES:
    # Get all permit definitions (kind 30500)
    nostr_get_events.sh --kind 30500

    # Get permit requests by specific author
    nostr_get_events.sh --kind 30501 --author a1b2c3d4e5f6...
    
    # Get messages from multiple authors (multiple --author)
    nostr_get_events.sh --kind 1 --author hex1 --author hex2 --author hex3
    
    # Get messages from multiple authors (comma-separated)
    nostr_get_events.sh --kind 1 --author "hex1,hex2,hex3"

    # Get specific permit request by identifier
    nostr_get_events.sh --kind 30501 --tag-d "req_abc123"

    # Get credentials for a specific holder
    nostr_get_events.sh --kind 30503 --tag-p "holder_pubkey_hex"

    # Get PlantNet observations (with hashtags - multiple tags separated by comma)
    nostr_get_events.sh --kind 1 --tag-t "plantnet,UPlanet"

    # Get events in specific UMAP (geolocation)
    nostr_get_events.sh --kind 1 --tag-g "43.60,1.44"

    # Count recent events (last 24 hours)
    nostr_get_events.sh --kind 1 --since \$(date -d '24 hours ago' +%s) --output count

    # Get events with limit
    nostr_get_events.sh --kind 1 --limit 10

    # Delete all events of a specific kind (⚠️  DANGEROUS!)
    nostr_get_events.sh --kind 30500 --del

    # Delete events by specific author
    nostr_get_events.sh --kind 1 --author a1b2c3d4e5f6... --del

    # Delete events without confirmation (use with extreme caution!)
    nostr_get_events.sh --kind 30500 --del --force

NOTES:
    - Requires strfry relay to be running at ~/.zen/strfry/
    - Returns events in JSON format (one per line)
    - Use jq for further JSON processing: nostr_get_events.sh --kind 1 | jq '.'
    - ⚠️  --del is DESTRUCTIVE and cannot be undone! Always test your filter first without --del
    - ⚠️  --force with --del is VERY DANGEROUS! Use only in scripts or when you're absolutely sure

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
            # Support multiple authors: accumulate in array
            # Also support comma-separated list for backward compatibility
            if [[ "$2" == *","* ]]; then
                # Comma-separated list: split and add each
                IFS=',' read -ra AUTHOR_LIST <<< "$2"
                for author in "${AUTHOR_LIST[@]}"; do
                    [[ -n "$author" ]] && AUTHORS+=("$author")
                done
            else
                # Single author: add to array
                [[ -n "$2" ]] && AUTHORS+=("$2")
            fi
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
        -t|--tag-t)
            TAG_T="$2"
            shift 2
            ;;
        -g|--tag-g)
            TAG_G="$2"
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
        --del)
            DELETE_MODE=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
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

# Add authors filter (support multiple authors)
if [[ ${#AUTHORS[@]} -gt 0 ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    # Build JSON array of authors
    AUTHORS_JSON=$(printf '"%s",' "${AUTHORS[@]}" | sed 's/,$//')
    FILTER+="\"authors\":[$AUTHORS_JSON]"
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

if [[ -n "$TAG_T" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    # Support multiple values separated by commas (e.g., "plantnet,UPlanet")
    IFS=',' read -ra TAG_T_VALUES <<< "$TAG_T"
    TAG_T_JSON=$(printf '"%s",' "${TAG_T_VALUES[@]}" | sed 's/,$//')
    FILTER+="\"#t\":[$TAG_T_JSON]"
fi

if [[ -n "$TAG_G" ]]; then
    [[ "$FILTER" != "{" ]] && FILTER+=","
    FILTER+="\"#g\":[\"$TAG_G\"]"
fi

FILTER+="}"

################################################################################
# Query strfry
################################################################################
cd "$STRFRY_DIR" || exit 1

# Execute query
if [[ "$DELETE_MODE" == "true" ]]; then
    # Delete mode: extract event IDs and delete them
    echo "[INFO] 🔍 Searching for events to delete..." >&2
    
    # Get events
    EVENTS=$(./strfry scan "$FILTER" 2>/dev/null)
    
    if [[ -z "$EVENTS" ]]; then
        echo "[INFO] No events found matching the filter" >&2
        exit 0
    fi
    
    # Extract all event IDs first (optimized - single pass)
    echo "[INFO] 📋 Extracting event IDs..." >&2
    EVENT_IDS=()
    
    if command -v jq &> /dev/null; then
        # Use jq for efficient batch processing
        while IFS= read -r event_id; do
            if [[ -n "$event_id" && "$event_id" != "null" ]]; then
                EVENT_IDS+=("$event_id")
            fi
        done < <(echo "$EVENTS" | jq -r '.id' 2>/dev/null)
    else
        # Fallback: extract IDs with grep/sed
        while IFS= read -r event; do
            EVENT_ID=$(echo "$event" | grep -o '"id":"[^"]*"' | sed 's/"id":"\([^"]*\)"/\1/')
            if [[ -n "$EVENT_ID" ]]; then
                EVENT_IDS+=("$EVENT_ID")
            fi
        done <<< "$EVENTS"
    fi
    
    EVENT_COUNT=${#EVENT_IDS[@]}
    
    if [[ "$EVENT_COUNT" -eq 0 ]]; then
        echo "[INFO] No valid event IDs found" >&2
        exit 0
    fi
    
    echo "[INFO] Found $EVENT_COUNT event(s) to delete" >&2
    
    # Show confirmation unless --force is used
    if [[ "$FORCE_MODE" != "true" ]]; then
        echo "[WARNING] ⚠️  This operation is DESTRUCTIVE and cannot be undone!" >&2
        echo "[WARNING] Event IDs to delete:" >&2
        for id in "${EVENT_IDS[@]:0:5}"; do
            echo "  - $id" >&2
        done
        if [[ "$EVENT_COUNT" -gt 5 ]]; then
            echo "  ... and $((EVENT_COUNT - 5)) more" >&2
        fi
        echo "" >&2
        echo -n "[PROMPT] Continue with deletion? (yes/NO): " >&2
        read -r CONFIRM
        
        if [[ "$CONFIRM" != "yes" ]]; then
            echo "[INFO] Deletion cancelled by user" >&2
            exit 0
        fi
    else
        echo "[WARNING] ⚠️  --force mode: skipping confirmation" >&2
    fi
    
    echo "[INFO] 🗑️  Deleting $EVENT_COUNT event(s)..." >&2
    
    # Build filter with IDs for batch deletion
    # strfry delete uses --filter with JSON containing ids array
    IDS_JSON=$(printf '%s\n' "${EVENT_IDS[@]}" | jq -R . | jq -s -c '{ids: .}')
    
    echo "[INFO] 🔄 Executing batch deletion with filter..." >&2
    
    # Execute deletion with filter
    DELETE_OUTPUT=$(./strfry delete --filter="$IDS_JSON" 2>&1)
    DELETE_EXIT_CODE=$?
    
    if [[ $DELETE_EXIT_CODE -eq 0 ]]; then
        echo "[OK] ✅ Successfully deleted $EVENT_COUNT event(s)" >&2
        echo "" >&2
        echo "[SUMMARY] Deletion complete:" >&2
        echo "  - Total found: $EVENT_COUNT" >&2
        echo "  - Successfully deleted: $EVENT_COUNT" >&2
        echo "  - Failed: 0" >&2
    else
        echo "[ERROR] ❌ Batch deletion failed" >&2
        echo "[ERROR] Exit code: $DELETE_EXIT_CODE" >&2
        echo "[ERROR] Output: $DELETE_OUTPUT" >&2
        echo "" >&2
        echo "[SUMMARY] Deletion failed:" >&2
        echo "  - Total found: $EVENT_COUNT" >&2
        echo "  - Successfully deleted: 0" >&2
        echo "  - Failed: $EVENT_COUNT" >&2
    fi
    
elif [[ "$OUTPUT_FORMAT" == "count" ]]; then
    # Count mode: just count lines
    COUNT=$(./strfry scan "$FILTER" 2>/dev/null | wc -l)
    echo "$COUNT"
else
    # JSON mode: output events
    ./strfry scan "$FILTER" 2>/dev/null
fi

cd - > /dev/null 2>&1

exit 0

