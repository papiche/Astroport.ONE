#!/bin/bash
################################################################################
# Script: nostr_cleanup_deactivated.sh
# Description: Find [DEACTIVATED] profiles and delete all their events
# Usage: nostr_cleanup_deactivated.sh [--dry-run] [--force]
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

. "${MY_PATH}/my.sh" 2>/dev/null

################################################################################
# Configuration
################################################################################
NOSTR_GET_EVENTS="${MY_PATH}/nostr_get_events.sh"
STRFRY_DIR="$HOME/.zen/strfry"
DRY_RUN=false
FORCE_MODE=false

################################################################################
# Colors
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Find [DEACTIVATED] profiles and delete all their events from the local strfry relay.

OPTIONS:
    --dry-run       Show what would be deleted without actually deleting
    --force         Skip confirmation prompts
    -h, --help      Show this help message

EXAMPLES:
    # Preview what would be deleted
    $(basename "$0") --dry-run

    # Delete with confirmation
    $(basename "$0")

    # Delete without confirmation (use with caution!)
    $(basename "$0") --force

NOTES:
    - Searches for kind 0 (profile) events containing "[DEACTIVATED]" in name
    - Deletes ALL events from matching authors
    - This operation is DESTRUCTIVE and cannot be undone!

EOF
    exit 0
}

################################################################################
# Parse arguments
################################################################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
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
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage
            ;;
    esac
done

################################################################################
# Check dependencies
################################################################################
if [[ ! -x "$NOSTR_GET_EVENTS" ]]; then
    echo -e "${RED}[ERROR] nostr_get_events.sh not found at $NOSTR_GET_EVENTS${NC}"
    exit 1
fi

if [[ ! -f "${STRFRY_DIR}/strfry" ]]; then
    echo -e "${RED}[ERROR] strfry not found at ${STRFRY_DIR}/strfry${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERROR] jq is required but not installed${NC}"
    exit 1
fi

################################################################################
# Main
################################################################################
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}       NOSTR Deactivated Profiles Cleanup${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY-RUN MODE - No events will be deleted${NC}"
    echo ""
fi

# Step 1: Find all profile events (kind 0)
echo -e "${CYAN}📡 Searching for profile events (kind 0)...${NC}"
PROFILES=$("$NOSTR_GET_EVENTS" --kind 0 --limit 10000 2>/dev/null)

if [[ -z "$PROFILES" ]]; then
    echo -e "${YELLOW}No profile events found${NC}"
    exit 0
fi

TOTAL_PROFILES=$(echo "$PROFILES" | wc -l)
echo -e "   Found ${GREEN}$TOTAL_PROFILES${NC} profile events"

# Step 2: Filter profiles with [DEACTIVATED] in name
echo -e "${CYAN}🔍 Filtering [DEACTIVATED] profiles...${NC}"

declare -a DEACTIVATED_AUTHORS=()
declare -a DEACTIVATED_NAMES=()

while IFS= read -r profile; do
    [[ -z "$profile" ]] && continue
    
    # Parse content JSON to get name
    CONTENT=$(echo "$profile" | jq -r '.content' 2>/dev/null)
    if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
        continue
    fi
    
    # Parse the content as JSON and extract name
    NAME=$(echo "$CONTENT" | jq -r '.name // empty' 2>/dev/null)
    
    # Check if name contains [DEACTIVATED]
    if [[ "$NAME" == *"[DEACTIVATED]"* ]]; then
        AUTHOR=$(echo "$profile" | jq -r '.pubkey' 2>/dev/null)
        if [[ -n "$AUTHOR" ]] && [[ "$AUTHOR" != "null" ]]; then
            DEACTIVATED_AUTHORS+=("$AUTHOR")
            DEACTIVATED_NAMES+=("$NAME")
        fi
    fi
done <<< "$PROFILES"

DEACTIVATED_COUNT=${#DEACTIVATED_AUTHORS[@]}

if [[ "$DEACTIVATED_COUNT" -eq 0 ]]; then
    echo -e "${GREEN}✅ No [DEACTIVATED] profiles found. Nothing to clean up.${NC}"
    exit 0
fi

echo -e "   Found ${RED}$DEACTIVATED_COUNT${NC} deactivated profile(s):"
echo ""

# Step 3: Show deactivated profiles and count their events
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Deactivated Profiles:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TOTAL_EVENTS_TO_DELETE=0

for i in "${!DEACTIVATED_AUTHORS[@]}"; do
    AUTHOR="${DEACTIVATED_AUTHORS[$i]}"
    NAME="${DEACTIVATED_NAMES[$i]}"
    
    # Count events for this author
    EVENT_COUNT=$("$NOSTR_GET_EVENTS" --author "$AUTHOR" --limit 100000 --output count 2>/dev/null)
    [[ -z "$EVENT_COUNT" ]] && EVENT_COUNT=0
    
    TOTAL_EVENTS_TO_DELETE=$((TOTAL_EVENTS_TO_DELETE + EVENT_COUNT))
    
    echo -e "  ${RED}✖${NC} ${NAME}"
    echo -e "    Pubkey: ${AUTHOR:0:20}..."
    echo -e "    Events: ${YELLOW}$EVENT_COUNT${NC}"
    echo ""
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Summary:${NC}"
echo -e "  Deactivated profiles: ${RED}$DEACTIVATED_COUNT${NC}"
echo -e "  Total events to delete: ${RED}$TOTAL_EVENTS_TO_DELETE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# If dry-run, stop here
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY-RUN complete. Use without --dry-run to actually delete.${NC}"
    exit 0
fi

# Step 4: Confirmation
if [[ "$FORCE_MODE" != "true" ]]; then
    echo -e "${RED}⚠️  WARNING: This operation is DESTRUCTIVE and cannot be undone!${NC}"
    echo ""
    echo -n "Type 'DELETE' to confirm deletion: "
    read -r CONFIRM
    
    if [[ "$CONFIRM" != "DELETE" ]]; then
        echo -e "${YELLOW}Deletion cancelled by user${NC}"
        exit 0
    fi
fi

# Step 5: Delete events for each deactivated author
echo ""
echo -e "${CYAN}🗑️  Deleting events from deactivated profiles...${NC}"
echo ""

DELETED_TOTAL=0
FAILED_TOTAL=0

for i in "${!DEACTIVATED_AUTHORS[@]}"; do
    AUTHOR="${DEACTIVATED_AUTHORS[$i]}"
    NAME="${DEACTIVATED_NAMES[$i]}"
    
    echo -e "${YELLOW}Processing: ${NAME}${NC}"
    echo -e "   Author: ${AUTHOR:0:20}..."
    
    # Delete all events from this author using nostr_get_events.sh --del --force
    if "$NOSTR_GET_EVENTS" --author "$AUTHOR" --limit 100000 --del --force 2>&1; then
        echo -e "   ${GREEN}✅ Events deleted successfully${NC}"
        DELETED_TOTAL=$((DELETED_TOTAL + 1))
    else
        echo -e "   ${RED}❌ Failed to delete events${NC}"
        FAILED_TOTAL=$((FAILED_TOTAL + 1))
    fi
    echo ""
done

# Step 6: Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Cleanup Complete${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Profiles processed: $DEACTIVATED_COUNT"
echo -e "  ${GREEN}Successful: $DELETED_TOTAL${NC}"
echo -e "  ${RED}Failed: $FAILED_TOTAL${NC}"
echo ""

exit 0


