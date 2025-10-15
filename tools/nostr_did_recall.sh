#!/bin/bash
################################################################################
# Script: nostr_did_recall.sh
# Description: Migration script - Push existing local DID documents to Nostr
# 
# This script migrates DIDs from local filesystem to Nostr relays.
# After migration, Nostr becomes the source of truth.
#
# Usage: ./nostr_did_recall.sh [options]
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
NOSTR_BASE_DIR="$HOME/.zen/game/nostr"
NOSTR_PUBLISH_DID_SCRIPT="${MY_PATH}/nostr_publish_did.py"
NOSTR_RELAYS="${NOSTR_RELAYS:-ws://127.0.0.1:7777 wss://relay.copylaradio.com}"

# Migration statistics
TOTAL_FOUND=0
TOTAL_MIGRATED=0
TOTAL_SKIPPED=0
TOTAL_FAILED=0

# Dry run mode
DRY_RUN=0

################################################################################
# Print banner
################################################################################
print_banner() {
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                     DID RECALL - Migration to Nostr                    ║"
    echo "║                                                                        ║"
    echo "║  This script migrates existing DID documents from local filesystem    ║"
    echo "║  to Nostr relays (kind 30311 events).                                 ║"
    echo "║                                                                        ║"
    echo "║  After migration, Nostr becomes the SOURCE OF TRUTH for DIDs.         ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

################################################################################
# Validate DID document
################################################################################
validate_did() {
    local did_file="$1"
    
    # Check if file exists
    if [[ ! -f "$did_file" ]]; then
        return 1
    fi
    
    # Check JSON validity
    if ! jq empty "$did_file" 2>/dev/null; then
        return 1
    fi
    
    # Check required fields
    if ! jq -e '.id' "$did_file" >/dev/null 2>&1; then
        return 1
    fi
    
    if ! jq -e '.verificationMethod' "$did_file" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

################################################################################
# Get Nostr keys for user from .secret.nostr
################################################################################
get_user_keys() {
    local email="$1"
    local secret_file="$NOSTR_BASE_DIR/${email}/.secret.nostr"
    
    if [[ ! -f "$secret_file" ]]; then
        return 1
    fi
    
    # Source the .secret.nostr file
    source "$secret_file" 2>/dev/null
    
    if [[ -z "$NSEC" ]] || [[ -z "$NPUB" ]]; then
        return 1
    fi
    
    echo "${NSEC}|${NPUB}"
    return 0
}

################################################################################
# Migrate single DID
################################################################################
migrate_did() {
    local email="$1"
    local did_file="$2"
    
    echo -e "\n${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📧 Processing: ${email}${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    
    # Validate DID file
    echo -e "${CYAN}🔍 Validating DID document...${NC}"
    if ! validate_did "$did_file"; then
        echo -e "${RED}❌ Invalid DID document, skipping${NC}"
        ((TOTAL_SKIPPED++))
        return 1
    fi
    echo -e "${GREEN}✅ DID document valid${NC}"
    
    # Get user's Nostr keys
    echo -e "${CYAN}🔑 Fetching Nostr keys...${NC}"
    local keys=$(get_user_keys "$email")
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Nostr keys not found, skipping${NC}"
        ((TOTAL_SKIPPED++))
        return 1
    fi
    
    local nsec=$(echo "$keys" | cut -d'|' -f1)
    local npub=$(echo "$keys" | cut -d'|' -f2)
    echo -e "${GREEN}✅ Keys found (npub: ${npub:0:16}...)${NC}"
    
    # Show DID info
    local did_id=$(jq -r '.id' "$did_file" 2>/dev/null)
    local updated=$(jq -r '.metadata.updated // .metadata.created // "unknown"' "$did_file" 2>/dev/null)
    local contract=$(jq -r '.metadata.contractStatus // "unknown"' "$did_file" 2>/dev/null)
    
    echo -e "${BLUE}📄 DID Info:${NC}"
    echo -e "   ${CYAN}ID: ${did_id}${NC}"
    echo -e "   ${CYAN}Last Updated: ${updated}${NC}"
    echo -e "   ${CYAN}Contract Status: ${contract}${NC}"
    
    # Dry run check
    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would migrate this DID to Nostr${NC}"
        ((TOTAL_SKIPPED++))
        return 0
    fi
    
    # Publish to Nostr
    echo -e "${CYAN}📡 Publishing to Nostr relays...${NC}"
    
    if [[ ! -f "$NOSTR_PUBLISH_DID_SCRIPT" ]]; then
        echo -e "${RED}❌ Publish script not found: ${NOSTR_PUBLISH_DID_SCRIPT}${NC}"
        ((TOTAL_FAILED++))
        return 1
    fi
    
    # Execute publish
    if python3 "$NOSTR_PUBLISH_DID_SCRIPT" "$nsec" "$did_file" $NOSTR_RELAYS >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Successfully migrated to Nostr${NC}"
        
        # Create backup of original
        local backup_file="${did_file}.pre-nostr-backup.$(date +%Y%m%d_%H%M%S)"
        cp "$did_file" "$backup_file"
        echo -e "${GREEN}✅ Backup created: $(basename "$backup_file")${NC}"
        
        # Rename original to .cache
        local cache_file="${did_file}.cache"
        mv "$did_file" "$cache_file"
        echo -e "${GREEN}✅ Original renamed to cache: $(basename "$cache_file")${NC}"
        
        ((TOTAL_MIGRATED++))
        return 0
    else
        echo -e "${RED}❌ Failed to publish to Nostr${NC}"
        ((TOTAL_FAILED++))
        return 1
    fi
}

################################################################################
# Find all DID documents
################################################################################
find_all_dids() {
    echo -e "${CYAN}🔍 Scanning for DID documents in: ${NOSTR_BASE_DIR}${NC}"
    
    local did_files=()
    
    # Find all did.json files (excluding backups and caches)
    while IFS= read -r did_file; do
        local email=$(basename "$(dirname "$did_file")")
        
        # Skip backup and cache files
        if [[ "$did_file" == *.backup.* ]] || [[ "$did_file" == *.cache ]]; then
            continue
        fi
        
        # Check if this is a valid email directory (has .secret.nostr)
        if [[ ! -f "$NOSTR_BASE_DIR/${email}/.secret.nostr" ]]; then
            continue
        fi
        
        did_files+=("$did_file")
        ((TOTAL_FOUND++))
    done < <(find "$NOSTR_BASE_DIR" -type f -name "did.json" 2>/dev/null)
    
    echo -e "${BLUE}📊 Found ${TOTAL_FOUND} DID document(s)${NC}"
    
    # Return array
    for file in "${did_files[@]}"; do
        echo "$file"
    done
}

################################################################################
# Migrate all DIDs
################################################################################
migrate_all() {
    local did_files=()
    
    # Read all DID files into array
    while IFS= read -r file; do
        did_files+=("$file")
    done < <(find_all_dids)
    
    if [[ ${#did_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No DID documents found${NC}"
        return 0
    fi
    
    echo -e "\n${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Starting migration of ${#did_files[@]} DID document(s)${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    
    # Migrate each DID
    for did_file in "${did_files[@]}"; do
        local email=$(basename "$(dirname "$did_file")")
        migrate_did "$email" "$did_file"
        
        # Small delay to avoid overwhelming relays
        sleep 1
    done
}

################################################################################
# Migrate single user
################################################################################
migrate_single() {
    local email="$1"
    local did_file="$NOSTR_BASE_DIR/${email}/did.json"
    
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}❌ DID file not found: ${did_file}${NC}"
        exit 1
    fi
    
    ((TOTAL_FOUND++))
    migrate_did "$email" "$did_file"
}

################################################################################
# Print summary
################################################################################
print_summary() {
    echo -e "\n${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                        Migration Summary                               ║${NC}"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC}  ${BLUE}Total DIDs found:      ${TOTAL_FOUND}${NC}"
    echo -e "${MAGENTA}║${NC}  ${GREEN}Successfully migrated: ${TOTAL_MIGRATED}${NC}"
    echo -e "${MAGENTA}║${NC}  ${YELLOW}Skipped:               ${TOTAL_SKIPPED}${NC}"
    echo -e "${MAGENTA}║${NC}  ${RED}Failed:                ${TOTAL_FAILED}${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    
    if [[ $TOTAL_MIGRATED -gt 0 ]]; then
        echo -e "\n${GREEN}✅ Migration completed successfully!${NC}"
        echo -e "${CYAN}📝 Next steps:${NC}"
        echo -e "   1. Verify DIDs on Nostr using: nak req -k 30311 -t d=did <relay>"
        echo -e "   2. Update scripts to use did_manager_nostr.sh"
        echo -e "   3. Backups are kept with .pre-nostr-backup suffix"
        echo -e "   4. Original files renamed to .cache for fallback"
    fi
    
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        echo -e "\n${RED}⚠️  Some DIDs failed to migrate. Check logs above.${NC}"
    fi
}

################################################################################
# Show help
################################################################################
show_help() {
    cat <<EOF
${BLUE}nostr_did_recall.sh - Migrate DIDs from local filesystem to Nostr${NC}

Usage:
  $0 [OPTIONS] [COMMAND] [EMAIL]

Commands:
  all              - Migrate all DID documents found (default)
  single EMAIL     - Migrate single user's DID
  list             - List all DIDs found (no migration)

Options:
  --dry-run        - Show what would be migrated without doing it
  --help, -h       - Show this help message

Environment Variables:
  NOSTR_RELAYS     - Space-separated relay URLs
                     (default: ws://127.0.0.1:7777 wss://relay.copylaradio.com)

Examples:
  $0                              # Migrate all DIDs
  $0 --dry-run                    # Dry run (no changes)
  $0 single user@example.com      # Migrate single user
  $0 list                         # List all DIDs

Safety Features:
  - Validates DID before migration
  - Creates .pre-nostr-backup of original
  - Renames original to .cache for fallback
  - Continues on errors (doesn't stop entire batch)

Requirements:
  - Python 3 with pynostr library
  - nostr_publish_did.py script in same directory
  - Nostr keys (SECRET, PUBKEY) for each user

EOF
}

################################################################################
# Main entry point
################################################################################
main() {
    print_banner
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                echo -e "${YELLOW}🔍 DRY RUN MODE: No changes will be made${NC}\n"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            list)
                find_all_dids
                echo -e "\n${BLUE}Total: ${TOTAL_FOUND} DID(s)${NC}"
                exit 0
                ;;
            single)
                if [[ -z "$2" ]]; then
                    echo -e "${RED}❌ Email required for 'single' command${NC}"
                    echo "Usage: $0 single EMAIL"
                    exit 1
                fi
                migrate_single "$2"
                print_summary
                exit 0
                ;;
            all|"")
                migrate_all
                print_summary
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check dependencies
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}❌ Python 3 not found${NC}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}❌ jq not found${NC}"
    exit 1
fi

if [[ ! -f "$NOSTR_PUBLISH_DID_SCRIPT" ]]; then
    echo -e "${YELLOW}⚠️  Warning: nostr_publish_did.py not found at: ${NOSTR_PUBLISH_DID_SCRIPT}${NC}"
    echo -e "${YELLOW}   Migration will fail without this script.${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Execute main
main "$@"

