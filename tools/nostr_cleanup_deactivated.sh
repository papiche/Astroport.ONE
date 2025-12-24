#!/bin/bash
################################################################################
# Script: nostr_cleanup_deactivated.sh
# Description: Find [DEACTIVATED] profiles and delete all their events
#              Also cleanup old UMAP ephemeral messages without expiration tags
# Usage: nostr_cleanup_deactivated.sh [--dry-run] [--force] [--umap-only] [--deactivated-only]
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
UMAP_ONLY=false
DEACTIVATED_ONLY=false
# Age threshold for UMAP ephemeral messages (in days) - messages older than this without expiration will be deleted
UMAP_MSG_AGE_DAYS=28

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
Also cleanup old UMAP ephemeral messages created without NIP-40 expiration tags.

OPTIONS:
    --dry-run           Show what would be deleted without actually deleting
    --force             Skip confirmation prompts
    --umap-only         Only cleanup old UMAP messages (skip deactivated profiles)
    --deactivated-only  Only cleanup deactivated profiles (skip UMAP messages)
    -h, --help          Show this help message

EXAMPLES:
    # Preview what would be deleted (both deactivated + UMAP messages)
    $(basename "$0") --dry-run

    # Delete with confirmation
    $(basename "$0")

    # Delete without confirmation (use with caution!)
    $(basename "$0") --force

    # Only cleanup old UMAP notification messages
    $(basename "$0") --umap-only --dry-run

    # Only cleanup deactivated profiles
    $(basename "$0") --deactivated-only

NOTES:
    - Searches for kind 0 (profile) events containing "[DEACTIVATED]" in name
    - Deletes ALL events from matching authors (deactivated profiles)
    - Finds UMAP identities and deletes old notification messages (>28 days) 
      that were created before NIP-40 expiration was implemented
    - UMAP messages detected: reminder (👋), goodbye (👋), ad removal (🛒), 
      inventory cleanup (🌱) messages sent to users
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
        --umap-only)
            UMAP_ONLY=true
            shift
            ;;
        --deactivated-only)
            DEACTIVATED_ONLY=true
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

# Validate conflicting options
if [[ "$UMAP_ONLY" == "true" ]] && [[ "$DEACTIVATED_ONLY" == "true" ]]; then
    echo -e "${RED}[ERROR] Cannot use --umap-only and --deactivated-only together${NC}" >&2
    exit 1
fi

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
# Deactivated Profiles Cleanup Function
################################################################################
cleanup_deactivated_profiles() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}       NOSTR Deactivated Profiles Cleanup${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Step 1: Find all profile events (kind 0)
    echo -e "${CYAN}📡 Searching for profile events (kind 0)...${NC}"
    PROFILES=$("$NOSTR_GET_EVENTS" --kind 0 --limit 10000 2>/dev/null)

    if [[ -z "$PROFILES" ]]; then
        echo -e "${YELLOW}No profile events found${NC}"
        return 0
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
        return 0
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
    echo -e "${YELLOW}Summary (Deactivated Profiles):${NC}"
    echo -e "  Deactivated profiles: ${RED}$DEACTIVATED_COUNT${NC}"
    echo -e "  Total events to delete: ${RED}$TOTAL_EVENTS_TO_DELETE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # If dry-run, return here
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    # Confirmation (only if not already confirmed globally)
    if [[ "$FORCE_MODE" != "true" ]] && [[ "$GLOBAL_CONFIRMED" != "true" ]]; then
        echo -e "${RED}⚠️  WARNING: This operation is DESTRUCTIVE and cannot be undone!${NC}"
        echo ""
        echo -n "Type 'DELETE' to confirm deletion of deactivated profiles: "
        read -r CONFIRM
        
        if [[ "$CONFIRM" != "DELETE" ]]; then
            echo -e "${YELLOW}Deletion cancelled by user${NC}"
            return 0
        fi
    fi

    # Delete events for each deactivated author
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

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Deactivated Profiles Cleanup Complete${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Profiles processed: $DEACTIVATED_COUNT"
    echo -e "  ${GREEN}Successful: $DELETED_TOTAL${NC}"
    echo -e "  ${RED}Failed: $FAILED_TOTAL${NC}"
    echo ""
}

################################################################################
# UMAP Ephemeral Messages Cleanup Function
################################################################################
# Finds and deletes old notification messages from UMAP identities that were
# created before NIP-40 expiration tags were implemented.
# 
# Messages targeted:
# - Reminder messages (👋 ... Haven't seen you around lately...)
# - Goodbye messages (👋 ... It seems you've been inactive...)
# - Ad removal notifications (🛒 ... your ad was removed...)
# - Inventory cleanup notifications (🌱 ... observation...)
################################################################################
cleanup_umap_old_messages() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}       UMAP Old Ephemeral Messages Cleanup${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}ℹ️  Looking for old UMAP notification messages without expiration tags${NC}"
    echo -e "${YELLOW}   (Created before NIP-40 expiration was implemented)${NC}"
    echo ""

    # Calculate timestamp threshold (messages older than UMAP_MSG_AGE_DAYS)
    THRESHOLD_TIMESTAMP=$(date -d "${UMAP_MSG_AGE_DAYS} days ago" +%s)
    echo -e "   Age threshold: ${YELLOW}${UMAP_MSG_AGE_DAYS} days${NC} (before $(date -d "@$THRESHOLD_TIMESTAMP" '+%Y-%m-%d'))"
    echo ""

    # Step 1: Find all UMAP profiles (kind 0 with UMAP_ or SECTOR_ or REGION_ pattern in name)
    echo -e "${CYAN}📡 Searching for UMAP/SECTOR/REGION identities...${NC}"
    PROFILES=$("$NOSTR_GET_EVENTS" --kind 0 --limit 10000 2>/dev/null)

    if [[ -z "$PROFILES" ]]; then
        echo -e "${YELLOW}No profile events found${NC}"
        return 0
    fi

    declare -a UMAP_AUTHORS=()
    declare -a UMAP_NAMES=()

    while IFS= read -r profile; do
        [[ -z "$profile" ]] && continue
        
        # Parse content JSON to get name
        CONTENT=$(echo "$profile" | jq -r '.content' 2>/dev/null)
        if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
            continue
        fi
        
        # Parse the content as JSON and extract name
        NAME=$(echo "$CONTENT" | jq -r '.name // empty' 2>/dev/null)
        
        # Check if name contains UMAP_, SECTOR_, or REGION_ pattern (UPlanet geographic identities)
        if [[ "$NAME" == *"UMAP_"* ]] || [[ "$NAME" == *"SECTOR_"* ]] || [[ "$NAME" == *"REGION_"* ]]; then
            AUTHOR=$(echo "$profile" | jq -r '.pubkey' 2>/dev/null)
            if [[ -n "$AUTHOR" ]] && [[ "$AUTHOR" != "null" ]]; then
                UMAP_AUTHORS+=("$AUTHOR")
                UMAP_NAMES+=("$NAME")
            fi
        fi
    done <<< "$PROFILES"

    UMAP_COUNT=${#UMAP_AUTHORS[@]}

    if [[ "$UMAP_COUNT" -eq 0 ]]; then
        echo -e "${GREEN}✅ No UMAP/SECTOR/REGION identities found. Nothing to clean up.${NC}"
        return 0
    fi

    echo -e "   Found ${GREEN}$UMAP_COUNT${NC} UMAP/SECTOR/REGION identit(ies)"
    echo ""

    # Step 2: For each UMAP identity, find old notification messages without expiration
    echo -e "${CYAN}🔍 Scanning for old ephemeral messages...${NC}"
    echo ""

    declare -a OLD_MSG_IDS=()
    declare -a OLD_MSG_AUTHORS=()
    declare -a OLD_MSG_CONTENTS=()
    declare -a OLD_MSG_DATES=()

    cd "$STRFRY_DIR"

    for i in "${!UMAP_AUTHORS[@]}"; do
        AUTHOR="${UMAP_AUTHORS[$i]}"
        NAME="${UMAP_NAMES[$i]}"
        
        # Get kind 1 messages from this UMAP identity older than threshold
        MESSAGES=$(./strfry scan '{
            "kinds": [1],
            "authors": ["'"$AUTHOR"'"],
            "until": '"$THRESHOLD_TIMESTAMP"',
            "limit": 1000
        }' 2>/dev/null)

        while IFS= read -r msg; do
            [[ -z "$msg" ]] && continue
            
            MSG_CONTENT=$(echo "$msg" | jq -r '.content' 2>/dev/null)
            MSG_ID=$(echo "$msg" | jq -r '.id' 2>/dev/null)
            MSG_CREATED=$(echo "$msg" | jq -r '.created_at' 2>/dev/null)
            MSG_TAGS=$(echo "$msg" | jq -c '.tags' 2>/dev/null)
            
            # Skip if no content
            [[ -z "$MSG_CONTENT" ]] || [[ "$MSG_CONTENT" == "null" ]] && continue
            
            # Check if message has expiration tag (NIP-40)
            HAS_EXPIRATION=$(echo "$MSG_TAGS" | jq 'any(.[0] == "expiration")' 2>/dev/null)
            
            # Only target messages WITHOUT expiration tag
            if [[ "$HAS_EXPIRATION" == "true" ]]; then
                continue
            fi
            
            # Check if this is an ephemeral notification message
            # These messages typically:
            # 1. Start with emoji indicators: 👋, 🛒, 🌱, 📬
            # 2. Contain "nostr:" references (mentions)
            # 3. Are notification/reminder type messages
            IS_EPHEMERAL=false
            
            # Reminder/Goodbye messages (👋)
            if [[ "$MSG_CONTENT" == *"👋"* ]] && [[ "$MSG_CONTENT" == *"nostr:"* ]]; then
                IS_EPHEMERAL=true
            fi
            
            # Ad removal notifications (🛒)
            if [[ "$MSG_CONTENT" == *"🛒"* ]] && [[ "$MSG_CONTENT" == *"nostr:"* ]]; then
                IS_EPHEMERAL=true
            fi
            
            # Inventory cleanup notifications (🌱)
            if [[ "$MSG_CONTENT" == *"🌱"* ]] && [[ "$MSG_CONTENT" == *"nostr:"* ]]; then
                IS_EPHEMERAL=true
            fi
            
            # Sent reminder indicator (📬)
            if [[ "$MSG_CONTENT" == *"📬"* ]]; then
                IS_EPHEMERAL=true
            fi
            
            # Additional patterns from NOSTR.UMAP.refresh.sh
            # "Haven't seen you around lately" - reminder
            if [[ "$MSG_CONTENT" == *"Haven't seen you around lately"* ]]; then
                IS_EPHEMERAL=true
            fi
            
            # "you've been inactive for a while" - goodbye
            if [[ "$MSG_CONTENT" == *"you've been inactive for a while"* ]]; then
                IS_EPHEMERAL=true
            fi
            
            # "your ad was removed" - market cleanup
            if [[ "$MSG_CONTENT" == *"your ad was removed"* ]]; then
                IS_EPHEMERAL=true
            fi
            
            # "observation" + "28 jours" or "28 days" - inventory cleanup
            if [[ "$MSG_CONTENT" == *"observation"* ]] && ([[ "$MSG_CONTENT" == *"28 jours"* ]] || [[ "$MSG_CONTENT" == *"28 days"* ]]); then
                IS_EPHEMERAL=true
            fi
            
            if [[ "$IS_EPHEMERAL" == "true" ]]; then
                OLD_MSG_IDS+=("$MSG_ID")
                OLD_MSG_AUTHORS+=("$NAME")
                OLD_MSG_CONTENTS+=("${MSG_CONTENT:0:60}...")
                OLD_MSG_DATES+=("$(date -d "@$MSG_CREATED" '+%Y-%m-%d')")
            fi
        done <<< "$MESSAGES"
    done

    cd - >/dev/null

    OLD_MSG_COUNT=${#OLD_MSG_IDS[@]}

    if [[ "$OLD_MSG_COUNT" -eq 0 ]]; then
        echo -e "${GREEN}✅ No old ephemeral messages found without expiration tags.${NC}"
        return 0
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Old UMAP Ephemeral Messages (without NIP-40 expiration):${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Show up to 20 messages as preview
    PREVIEW_COUNT=$((OLD_MSG_COUNT < 20 ? OLD_MSG_COUNT : 20))
    for i in $(seq 0 $((PREVIEW_COUNT - 1))); do
        echo -e "  ${RED}✖${NC} [${OLD_MSG_DATES[$i]}] ${OLD_MSG_AUTHORS[$i]}"
        echo -e "    ${OLD_MSG_CONTENTS[$i]}"
        echo ""
    done

    if [[ "$OLD_MSG_COUNT" -gt 20 ]]; then
        echo -e "  ... and $((OLD_MSG_COUNT - 20)) more messages"
        echo ""
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Summary (UMAP Old Messages):${NC}"
    echo -e "  UMAP/SECTOR/REGION identities: ${GREEN}$UMAP_COUNT${NC}"
    echo -e "  Old messages to delete: ${RED}$OLD_MSG_COUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # If dry-run, return here
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    # Confirmation (only if not already confirmed globally)
    if [[ "$FORCE_MODE" != "true" ]] && [[ "$GLOBAL_CONFIRMED" != "true" ]]; then
        echo -e "${RED}⚠️  WARNING: This operation is DESTRUCTIVE and cannot be undone!${NC}"
        echo ""
        echo -n "Type 'DELETE' to confirm deletion of old UMAP messages: "
        read -r CONFIRM
        
        if [[ "$CONFIRM" != "DELETE" ]]; then
            echo -e "${YELLOW}Deletion cancelled by user${NC}"
            return 0
        fi
    fi

    # Step 3: Delete old messages
    echo ""
    echo -e "${CYAN}🗑️  Deleting old UMAP ephemeral messages...${NC}"
    echo ""

    cd "$STRFRY_DIR"
    
    DELETED_COUNT=0
    FAILED_COUNT=0

    # Batch delete using strfry delete with IDs
    if [[ ${#OLD_MSG_IDS[@]} -gt 0 ]]; then
        # Build JSON filter with all IDs
        IDS_JSON=$(printf '%s\n' "${OLD_MSG_IDS[@]}" | jq -R . | jq -s -c '{ids: .}')
        
        echo -e "   Deleting ${#OLD_MSG_IDS[@]} messages..."
        
        if DELETE_OUTPUT=$(./strfry delete --filter="$IDS_JSON" 2>&1); then
            DELETED_COUNT=${#OLD_MSG_IDS[@]}
            echo -e "   ${GREEN}✅ Messages deleted successfully${NC}"
        else
            FAILED_COUNT=${#OLD_MSG_IDS[@]}
            echo -e "   ${RED}❌ Failed to delete messages${NC}"
            echo -e "   Error: $DELETE_OUTPUT"
        fi
    fi

    cd - >/dev/null

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}UMAP Messages Cleanup Complete${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}Deleted: $DELETED_COUNT${NC}"
    echo -e "  ${RED}Failed: $FAILED_COUNT${NC}"
    echo ""
}

################################################################################
# Main
################################################################################
GLOBAL_CONFIRMED=false

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY-RUN MODE - No events will be deleted${NC}"
    echo ""
fi

# Global confirmation if force mode and running both cleanups
if [[ "$FORCE_MODE" == "true" ]]; then
    GLOBAL_CONFIRMED=true
elif [[ "$UMAP_ONLY" != "true" ]] && [[ "$DEACTIVATED_ONLY" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
    echo -e "${RED}⚠️  WARNING: This operation is DESTRUCTIVE and cannot be undone!${NC}"
    echo -e "${YELLOW}   This will cleanup both deactivated profiles AND old UMAP messages.${NC}"
    echo ""
    echo -n "Type 'DELETE' to confirm: "
    read -r CONFIRM
    
    if [[ "$CONFIRM" == "DELETE" ]]; then
        GLOBAL_CONFIRMED=true
    else
        echo -e "${YELLOW}Deletion cancelled by user${NC}"
        exit 0
    fi
fi

# Run appropriate cleanup functions based on options
if [[ "$UMAP_ONLY" != "true" ]]; then
    cleanup_deactivated_profiles
fi

if [[ "$DEACTIVATED_ONLY" != "true" ]]; then
    cleanup_umap_old_messages
fi

# Final summary
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY-RUN complete. Use without --dry-run to actually delete.${NC}"
fi

exit 0
