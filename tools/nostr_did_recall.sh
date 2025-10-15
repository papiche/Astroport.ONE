#!/bin/bash
################################################################################
# Script: nostr_did_recall.sh
# Description: Migrate existing DID documents to Nostr relays
#
# This script finds all existing DID documents in the local filesystem
# and publishes them to Nostr relays as kind 30311 events, making
# Nostr the source of truth for all DIDs.
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
NOSTR_BASE_DIR="$HOME/.zen/game/nostr"
NOSTR_PUBLISH_SCRIPT="${MY_PATH}/nostr_publish_did.py"
NOSTR_RELAYS="${NOSTR_RELAYS:-ws://127.0.0.1:7777 wss://relay.copylaradio.com}"

# Counters
TOTAL_DIDS=0
MIGRATED_DIDS=0
FAILED_DIDS=0
SKIPPED_DIDS=0

################################################################################
# Show banner
################################################################################
show_banner() {
    cat <<EOF
${CYAN}
╔════════════════════════════════════════════════════════════════════════╗
║                     DID RECALL - Migration to Nostr                    ║
║                                                                        ║
║  This script migrates existing DID documents from local filesystem    ║
║  to Nostr relays (kind 30311 events).                                 ║
║                                                                        ║
║  After migration, Nostr becomes the SOURCE OF TRUTH for DIDs.         ║
╚════════════════════════════════════════════════════════════════════════╝
${NC}

EOF
}

################################################################################
# Check prerequisites
################################################################################
check_prerequisites() {
    echo -e "${CYAN}🔍 Checking prerequisites...${NC}"
    
    # Check if nostr_publish_did.py exists
    if [[ ! -f "$NOSTR_PUBLISH_SCRIPT" ]]; then
        echo -e "${RED}❌ Error: nostr_publish_did.py not found at: ${NOSTR_PUBLISH_SCRIPT}${NC}"
        exit 1
    fi
    
    # Check Python3
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: python3 not found${NC}"
        exit 1
    fi
    
    # Check if base directory exists
    if [[ ! -d "$NOSTR_BASE_DIR" ]]; then
        echo -e "${RED}❌ Error: Nostr directory not found: ${NOSTR_BASE_DIR}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}\n"
}

################################################################################
# Find all DID documents
################################################################################
find_did_documents() {
    echo -e "${CYAN}🔍 Scanning for DID documents...${NC}"
    
    local did_files=()
    
    # Find all did.json.cache files (excluding backups)
    while IFS= read -r -d '' file; do
        did_files+=("$file")
    done < <(find "$NOSTR_BASE_DIR" -type f -name "did.json.cache" -print0 2>/dev/null)
    
    TOTAL_DIDS=${#did_files[@]}
    
    if [[ $TOTAL_DIDS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No DID documents found${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}✅ Found ${TOTAL_DIDS} DID documents${NC}\n"
    
    # Return array
    printf '%s\n' "${did_files[@]}"
}

################################################################################
# Extract email from DID file path
################################################################################
extract_email_from_path() {
    local did_file="$1"
    local email=$(echo "$did_file" | sed "s|${NOSTR_BASE_DIR}/||" | cut -d'/' -f1)
    echo "$email"
}

################################################################################
# Get Nostr keys for email
################################################################################
get_nostr_keys() {
    local email="$1"
    local secret_file="$NOSTR_BASE_DIR/${email}/.secret.nostr"
    
    if [[ ! -f "$secret_file" ]]; then
        echo -e "${RED}❌ Keys file not found: ${secret_file}${NC}" >&2
        return 1
    fi
    
    # Source the file to get NSEC
    source "$secret_file" 2>/dev/null
    
    if [[ -z "$NSEC" ]]; then
        echo -e "${RED}❌ NSEC not found in ${secret_file}${NC}" >&2
        return 1
    fi
    
    echo "$NSEC"
    return 0
}

################################################################################
# Migrate single DID to Nostr
################################################################################
migrate_did_to_nostr() {
    local did_file="$1"
    local email="$2"
    
    echo -e "${BLUE}📄 Processing: ${email}${NC}"
    
    # Validate DID file
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}  ❌ DID file not found${NC}"
        ((FAILED_DIDS++))
        return 1
    fi
    
    # Validate JSON
    if ! jq empty "$did_file" 2>/dev/null; then
        echo -e "${RED}  ❌ Invalid JSON in DID file${NC}"
        ((FAILED_DIDS++))
        return 1
    fi
    
    # Get Nostr keys
    local nsec=$(get_nostr_keys "$email")
    if [[ $? -ne 0 ]] || [[ -z "$nsec" ]]; then
        echo -e "${YELLOW}  ⚠️  Skipped: No Nostr keys found${NC}"
        ((SKIPPED_DIDS++))
        return 1
    fi
    
    # Extract DID ID for logging
    local did_id=$(jq -r '.id // "unknown"' "$did_file" 2>/dev/null)
    echo -e "${CYAN}  📝 DID: ${did_id}${NC}"
    
    # Publish to Nostr
    echo -e "${CYAN}  📡 Publishing to Nostr...${NC}"
    
    if python3 "$NOSTR_PUBLISH_SCRIPT" "$nsec" "$did_file" $NOSTR_RELAYS 2>/dev/null; then
        echo -e "${GREEN}  ✅ Successfully migrated to Nostr${NC}"
        ((MIGRATED_DIDS++))
        return 0
    else
        echo -e "${RED}  ❌ Failed to publish to Nostr${NC}"
        ((FAILED_DIDS++))
        return 1
    fi
}

################################################################################
# Show migration summary
################################################################################
show_summary() {
    echo -e "\n${MAGENTA}${'='*80}${NC}"
    echo -e "${CYAN}📊 Migration Summary${NC}"
    echo -e "${MAGENTA}${'='*80}${NC}"
    echo -e "${BLUE}Total DIDs found:     ${TOTAL_DIDS}${NC}"
    echo -e "${GREEN}✅ Successfully migrated: ${MIGRATED_DIDS}${NC}"
    echo -e "${RED}❌ Failed:              ${FAILED_DIDS}${NC}"
    echo -e "${YELLOW}⚠️  Skipped:             ${SKIPPED_DIDS}${NC}"
    echo -e "${MAGENTA}${'='*80}${NC}\n"
    
    if [[ $MIGRATED_DIDS -gt 0 ]]; then
        echo -e "${GREEN}🎉 Migration completed!${NC}"
        echo -e "${CYAN}💡 DIDs are now available on Nostr relays${NC}"
        echo -e "${CYAN}💡 You can verify with: nak req -k 30311 -t d=did <relay_url>${NC}\n"
    fi
    
    if [[ $FAILED_DIDS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Some DIDs failed to migrate. Check logs above.${NC}\n"
    fi
}

################################################################################
# Main execution
################################################################################
main() {
    # Parse arguments
    case "${1:-}" in
        "-h"|"--help")
            show_banner
            cat <<EOF
${CYAN}Usage:${NC}
  $0 [OPTIONS]

${CYAN}Options:${NC}
  -h, --help     Show this help message
  --dry-run      Show what would be migrated without actually migrating
  --email EMAIL  Migrate only a specific email address

${CYAN}Description:${NC}
  This script finds all existing DID documents (did.json.cache files)
  and publishes them to Nostr relays as kind 30311 events.

${CYAN}Examples:${NC}
  $0                              # Migrate all DIDs
  $0 --dry-run                    # Preview migration
  $0 --email user@example.com     # Migrate single email

EOF
            exit 0
            ;;
        "--dry-run")
            DRY_RUN=true
            shift
            ;;
        "--email")
            SINGLE_EMAIL="$2"
            shift 2
            ;;
    esac
    
    # Show banner
    show_banner
    
    # Check prerequisites
    check_prerequisites
    
    # Find DID documents
    local did_files
    if [[ -n "${SINGLE_EMAIL:-}" ]]; then
        echo -e "${CYAN}🔍 Searching for DID: ${SINGLE_EMAIL}${NC}\n"
        did_files=("${NOSTR_BASE_DIR}/${SINGLE_EMAIL}/did.json.cache")
        TOTAL_DIDS=1
    else
        mapfile -t did_files < <(find_did_documents)
    fi
    
    if [[ $TOTAL_DIDS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No DID documents to migrate${NC}"
        exit 0
    fi
    
    # Dry run mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${YELLOW}🔍 DRY RUN MODE - No actual migration will be performed${NC}\n"
        for did_file in "${did_files[@]}"; do
            local email=$(extract_email_from_path "$did_file")
            local did_id=$(jq -r '.id // "unknown"' "$did_file" 2>/dev/null)
            echo -e "${BLUE}  Would migrate: ${email}${NC}"
            echo -e "${CYAN}    DID: ${did_id}${NC}"
            echo -e "${CYAN}    File: ${did_file}${NC}"
        done
        echo -e "\n${GREEN}✅ Dry run completed${NC}"
        exit 0
    fi
    
    # Migrate each DID
    echo -e "${CYAN}🚀 Starting migration...${NC}\n"
    
    local count=0
    for did_file in "${did_files[@]}"; do
        ((count++))
        echo -e "${MAGENTA}[${count}/${TOTAL_DIDS}]${NC}"
        
        local email=$(extract_email_from_path "$did_file")
        migrate_did_to_nostr "$did_file" "$email"
        
        echo ""
        
        # Small delay between migrations to avoid overwhelming relays
        sleep 1
    done
    
    # Show summary
    show_summary
    
    # Exit code based on results
    if [[ $FAILED_DIDS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Execute main
main "$@"
