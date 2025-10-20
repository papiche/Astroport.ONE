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
NOSTR_DID_CLIENT_SCRIPT="${MY_PATH}/nostr_did_client.py"
NOSTR_RELAYS="${NOSTR_RELAYS:-ws://127.0.0.1:7777 wss://relay.copylaradio.com}"

# Migration statistics
TOTAL_FOUND=0
TOTAL_MIGRATED=0
TOTAL_SKIPPED=0
TOTAL_FAILED=0

# Dry run mode
DRY_RUN=0

# Force migration even if DID exists on Nostr
FORCE_MIGRATION=0

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
# Check if DID already exists on Nostr
################################################################################
check_did_on_nostr() {
    local npub="$1"
    
    # Check if nostr_did_client.py is available
    if [[ ! -f "$NOSTR_DID_CLIENT_SCRIPT" ]]; then
        echo -e "${YELLOW}⚠️  nostr_did_client.py not found, skipping Nostr check${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔍 Checking if DID already exists on Nostr...${NC}"
    
    # Use nostr_did_client.py to check if DID exists
    if python3 "$NOSTR_DID_CLIENT_SCRIPT" check "$npub" $NOSTR_RELAYS -q 2>/dev/null; then
        echo -e "${YELLOW}⚠️  DID already exists on Nostr${NC}"
        
        # Get more details for display
        local event_info=$(python3 "$NOSTR_DID_CLIENT_SCRIPT" read "$npub" $NOSTR_RELAYS -q 2>/dev/null | jq -r '.event_id // empty' 2>/dev/null | head -1)
        if [[ -n "$event_info" ]]; then
            echo -e "${CYAN}   Event ID: ${event_info:0:16}...${NC}"
        fi
        
        return 0  # DID exists
    else
        echo -e "${GREEN}✅ No existing DID found on Nostr${NC}"
        return 1  # DID doesn't exist
    fi
}

################################################################################
# Create DID from filesystem data (like make_NOSTRCARD.sh)
################################################################################
create_did_from_filesystem() {
    local email="$1"
    local user_dir="$NOSTR_BASE_DIR/${email}"
    
    echo -e "${CYAN}📝 Creating DID from filesystem data...${NC}"
    
    # Check for required files
    local required_files=("HEX" "G1PUBNOSTR" "NPUB")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$user_dir/$file" ]]; then
            echo -e "${RED}❌ Missing required file: $file${NC}"
            return 1
        fi
    done
    
    # Read data from files
    local HEX=$(cat "$user_dir/HEX" 2>/dev/null | tr -d '[:space:]')
    local G1PUBNOSTR=$(cat "$user_dir/G1PUBNOSTR" 2>/dev/null | tr -d '[:space:]')
    local NPUB=$(cat "$user_dir/NPUB" 2>/dev/null | tr -d '[:space:]')
    local BITCOIN=$(cat "$user_dir/BITCOIN" 2>/dev/null | tr -d '[:space:]')
    local MONERO=$(cat "$user_dir/MONERO" 2>/dev/null | tr -d '[:space:]')
    local NOSTRNS=$(cat "$user_dir/NOSTRNS" 2>/dev/null | tr -d '[:space:]')
    local LANG=$(cat "$user_dir/LANG" 2>/dev/null | tr -d '[:space:]' || echo "fr")
    
    # Get coordinates from GPS or ZUMAP file
    local ZLAT="0.0"
    local ZLON="0.0"
    if [[ -f "$user_dir/GPS" ]]; then
        source "$user_dir/GPS" 2>/dev/null
        ZLAT="${LAT:-0.0}"
        ZLON="${LON:-0.0}"
    fi
    
    # Get YOUSER (username)
    local YOUSER=$(echo "$email" | cut -d'@' -f1)
    
    # Get UPLANETG1PUB from environment or default
    local UPLANETG1PUB="${UPLANETG1PUB:-AwdjhpJNDQQNMsL8Kqndrz6rkRDsJ8wNDp7MRQJmKLGg}"
    
    # Create DID document
    local did_file="$user_dir/did.json.cache"
    
    cat > "$did_file" <<EOF
{
  "@context": [
    "https://www.w3.org/ns/did/v1",
    "https://w3id.org/security/suites/ed25519-2020/v1",
    "https://w3id.org/security/suites/x25519-2020/v1"
  ],
  "id": "did:nostr:${HEX}",
  "type": "DIDNostr",
  "alsoKnownAs": [
    "mailto:${email}",
    "did:g1:${G1PUBNOSTR}",
    "ipns://${NOSTRNS}"
  ],
  "verificationMethod": [
    {
      "id": "did:nostr:${HEX}#key1",
      "type": "Multikey",
      "controller": "did:nostr:${HEX}",
      "publicKeyMultibase": "fe70102${HEX}"
    },
    {
      "id": "did:nostr:${HEX}#g1-key",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:nostr:${HEX}",
      "publicKeyBase58": "${G1PUBNOSTR}",
      "blockchainAccountId": "duniter:g1:${G1PUBNOSTR}"
    }
EOF
    
    # Add Bitcoin key if available
    if [[ -n "$BITCOIN" ]]; then
        cat >> "$did_file" <<EOF
    ,
    {
      "id": "did:nostr:${HEX}#bitcoin-key",
      "type": "EcdsaSecp256k1VerificationKey2019",
      "controller": "did:nostr:${HEX}",
      "blockchainAccountId": "bitcoin:mainnet:${BITCOIN}"
    }
EOF
    fi
    
    # Add Monero key if available
    if [[ -n "$MONERO" ]]; then
        cat >> "$did_file" <<EOF
    ,
    {
      "id": "did:nostr:${HEX}#monero-key",
      "type": "MoneroVerificationKey",
      "controller": "did:nostr:${HEX}",
      "blockchainAccountId": "monero:mainnet:${MONERO}"
    }
EOF
    fi
    
    # Close verificationMethod and add rest of DID
    cat >> "$did_file" <<EOF
  ],
  "authentication": [
    "did:nostr:${HEX}#key1",
    "did:nostr:${HEX}#g1-key"
  ],
  "assertionMethod": [
    "did:nostr:${HEX}#key1",
    "did:nostr:${HEX}#g1-key"
  ],
  "keyAgreement": [
    "did:nostr:${HEX}#key1"
  ],
  "service": [
    {
      "id": "did:nostr:${HEX}#nostr-relay",
      "type": "NostrRelay",
      "serviceEndpoint": "${myRELAY:-wss://relay.copylaradio.com}",
      "description": "Primary NOSTR relay endpoint"
    },
    {
      "id": "did:nostr:${HEX}#ipns-storage",
      "type": "DecentralizedWebNode",
      "serviceEndpoint": "${myIPFS:-http://127.0.0.1:8080}/ipns/${NOSTRNS}",
      "description": "IPNS personal storage vault"
    },
    {
      "id": "did:nostr:${HEX}#udrive",
      "type": "DecentralizedWebNode",
      "serviceEndpoint": "${myIPFS:-http://127.0.0.1:8080}/ipns/${NOSTRNS}/${email}/APP/uDRIVE",
      "description": "Personal cloud storage and application platform"
    },
    {
      "id": "did:nostr:${HEX}#uspot",
      "type": "CredentialRegistry",
      "serviceEndpoint": "${uSPOT:-https://copylaradio.com/54321}",
      "description": "UPlanet wallet and credential service"
    }
  ],
  "metadata": {
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "email": "${email}",
    "uplanet": "${UPLANETG1PUB:0:8}",
    "coordinates": {
      "latitude": "${ZLAT}",
      "longitude": "${ZLON}"
    },
    "language": "${LANG}",
    "youser": "${YOUSER}",
    "contractStatus": "migrated_from_filesystem"
  }
}
EOF
    
    if validate_did "$did_file"; then
        echo -e "${GREEN}✅ DID created successfully from filesystem${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create valid DID${NC}"
        rm -f "$did_file"
        return 1
    fi
}

################################################################################
# Migrate single DID
################################################################################
migrate_did() {
    local email="$1"
    local did_file="$2"
    local create_if_missing="${3:-false}"
    
    echo -e "\n${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📧 Processing: ${email}${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    
    # Get user's Nostr keys FIRST (needed for checking Nostr)
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
    
    # Check if DID already exists on Nostr EARLY (unless --force is used)
    if [[ $FORCE_MIGRATION -eq 0 ]]; then
        if check_did_on_nostr "$npub"; then
            echo -e "${YELLOW}⚠️  DID already exists on Nostr${NC}"
            
            # Try to fetch and display the DID
            if [[ -f "$NOSTR_DID_CLIENT_SCRIPT" ]]; then
                echo -e "${CYAN}📥 Fetching DID from Nostr...${NC}"
                local did_output=$(python3 "$NOSTR_DID_CLIENT_SCRIPT" read "$npub" $NOSTR_RELAYS -q 2>/dev/null)
                
                if [[ -n "$did_output" ]]; then
                    echo -e "${GREEN}✅ DID retrieved from Nostr:${NC}"
                    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
                    echo "$did_output" | jq -C '.' 2>/dev/null || echo "$did_output"
                    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
                    
                    # Save to cache if it doesn't exist
                    local cache_file="$NOSTR_BASE_DIR/${email}/did.json.cache"
                    if [[ ! -f "$cache_file" ]]; then
                        echo "$did_output" | jq '.' > "$cache_file" 2>/dev/null
                        echo -e "${GREEN}💾 DID saved to cache: ${cache_file}${NC}"
                    fi
                fi
            fi
            
            echo -e "${CYAN}💡 Use --force to force re-migration${NC}"
            ((TOTAL_SKIPPED++))
            return 0
        fi
    else
        echo -e "${YELLOW}🔄 Force migration mode enabled, will re-publish${NC}"
        # Skip the Nostr check in force mode - continue with migration
    fi
    
    # If DID file doesn't exist but create_if_missing is true, try to create it
    if [[ ! -f "$did_file" && "$create_if_missing" == "true" ]]; then
        echo -e "${YELLOW}⚠️  No local DID found, creating from filesystem...${NC}"
        if create_did_from_filesystem "$email"; then
            did_file="$NOSTR_BASE_DIR/${email}/did.json.cache"
            echo -e "${GREEN}✅ DID created from filesystem${NC}"
        else
            echo -e "${RED}❌ Could not create DID from filesystem, skipping${NC}"
            ((TOTAL_SKIPPED++))
            return 1
        fi
    fi
    
    # Validate DID file
    echo -e "${CYAN}🔍 Validating DID document...${NC}"
    if ! validate_did "$did_file"; then
        echo -e "${RED}❌ Invalid DID document, skipping${NC}"
        ((TOTAL_SKIPPED++))
        return 1
    fi
    echo -e "${GREEN}✅ DID document valid${NC}"
    
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
# Find all user directories (with or without did.json)
################################################################################
find_all_users() {
    echo -e "${CYAN}🔍 Scanning for user directories in: ${NOSTR_BASE_DIR}${NC}"
    
    local user_dirs=()
    
    # Find all directories with .secret.nostr (valid users)
    while IFS= read -r secret_file; do
        local user_dir=$(dirname "$secret_file")
        local email=$(basename "$user_dir")
        
        # Validate email format
        if [[ $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            user_dirs+=("$email")
            ((TOTAL_FOUND++))
        fi
    done < <(find "$NOSTR_BASE_DIR" -type f -name ".secret.nostr" 2>/dev/null)
    
    echo -e "${BLUE}📊 Found ${TOTAL_FOUND} user(s) with Nostr keys${NC}"
    
    # Return array
    for user in "${user_dirs[@]}"; do
        echo "$user"
    done
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
    done < <(find "$NOSTR_BASE_DIR" -type f -name "did.json" 2>/dev/null)
    
    echo -e "${BLUE}📊 Found ${#did_files[@]} existing DID document(s)${NC}"
    
    # Return array
    for file in "${did_files[@]}"; do
        echo "$file"
    done
}

################################################################################
# Migrate all DIDs (create if missing)
################################################################################
migrate_all() {
    local create_if_missing="${1:-true}"
    local users=()
    
    # Read all users into array
    while IFS= read -r email; do
        users+=("$email")
    done < <(find_all_users)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No users found${NC}"
        return 0
    fi
    
    echo -e "\n${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Starting migration of ${#users[@]} user(s)${NC}"
    if [[ "$create_if_missing" == "true" ]]; then
        echo -e "${CYAN}Will create DIDs from filesystem if missing${NC}"
    fi
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    
    # Migrate each user
    for email in "${users[@]}"; do
        local did_file="$NOSTR_BASE_DIR/${email}/did.json"
        local cache_file="$NOSTR_BASE_DIR/${email}/did.json.cache"
        
        # Check for existing DID (prefer did.json, fallback to did.json.cache)
        if [[ -f "$did_file" ]]; then
            migrate_did "$email" "$did_file" "false"
        elif [[ -f "$cache_file" ]]; then
            migrate_did "$email" "$cache_file" "false"
        else
            # No DID found, create if requested
            migrate_did "$email" "$did_file" "$create_if_missing"
        fi
        
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
    local cache_file="$NOSTR_BASE_DIR/${email}/did.json.cache"
    
    # Check if user directory exists
    if [[ ! -d "$NOSTR_BASE_DIR/${email}" ]]; then
        echo -e "${RED}❌ User directory not found: ${NOSTR_BASE_DIR/${email}}${NC}"
        exit 1
    fi
    
    # Check for Nostr keys
    if [[ ! -f "$NOSTR_BASE_DIR/${email}/.secret.nostr" ]]; then
        echo -e "${RED}❌ Nostr keys not found for: ${email}${NC}"
        echo -e "${CYAN}💡 Expected: ${NOSTR_BASE_DIR}/${email}/.secret.nostr${NC}"
        exit 1
    fi
    
    ((TOTAL_FOUND++))
    
    # Try to find existing DID or create from filesystem
    if [[ -f "$did_file" ]]; then
        echo -e "${CYAN}📄 Found did.json${NC}"
        migrate_did "$email" "$did_file" "false"
    elif [[ -f "$cache_file" ]]; then
        echo -e "${CYAN}📄 Found did.json.cache${NC}"
        migrate_did "$email" "$cache_file" "false"
    else
        echo -e "${YELLOW}⚠️  No DID found, will create from filesystem${NC}"
        migrate_did "$email" "$did_file" "true"
    fi
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
        echo -e "   1. Verify DIDs on Nostr: python3 nostr_read_did.py <npub> [relay...]"
        echo -e "   2. DIDs are now synchronized across constellation relays"
        echo -e "   3. Backups are kept with .pre-nostr-backup suffix"
        echo -e "   4. Original files renamed to .cache for fallback"
        echo -e "   5. Use did_manager_nostr.sh for future updates"
    fi
    
    if [[ $TOTAL_SKIPPED -gt 0 && $FORCE_MIGRATION -eq 0 ]]; then
        echo -e "\n${YELLOW}💡 Tip: Some DIDs were skipped (already on Nostr)${NC}"
        echo -e "${CYAN}   Use --force to re-migrate them if needed${NC}"
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
  all              - Migrate all users (create DIDs if missing) (default)
  single EMAIL     - Migrate single user's DID (create if missing)
  list             - List all users found (no migration)
  existing-only    - Migrate only existing DIDs (no creation)

Options:
  --dry-run        - Show what would be migrated without doing it
  --force          - Force migration even if DID exists on Nostr
  --help, -h       - Show this help message

Environment Variables:
  NOSTR_RELAYS     - Space-separated relay URLs
                     (default: ws://127.0.0.1:7777 wss://relay.copylaradio.com)

Examples:
  $0                              # Migrate all users (create DIDs if missing)
  $0 --dry-run                    # Dry run (no changes)
  $0 --force                      # Force re-migration of all DIDs
  $0 single user@example.com      # Migrate single user (create if needed)
  $0 existing-only                # Migrate only existing DIDs
  $0 list                         # List all users

Safety Features:
  - Checks if DID already exists on Nostr (skips if found)
  - Validates DID before migration
  - Creates DIDs from filesystem if missing (compatible with make_NOSTRCARD.sh)
  - Creates .pre-nostr-backup of original
  - Renames original to .cache for fallback
  - Continues on errors (doesn't stop entire batch)
  - Use --force to override existing DIDs on Nostr

DID Creation:
  If no did.json exists, script creates one from filesystem data:
  - HEX, NPUB, G1PUBNOSTR (required)
  - BITCOIN, MONERO, NOSTRNS (optional)
  - GPS coordinates, LANG (optional)
  - Compatible with DID_IMPLEMENTATION.md spec

Requirements:
  - Python 3 with pynostr library
  - nostr_publish_did.py script in same directory
  - nostr_did_client.py script in same directory (for checking existing DIDs)
  - Nostr keys (.secret.nostr) for each user

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
            --force)
                FORCE_MIGRATION=1
                echo -e "${YELLOW}🔄 FORCE MODE: Will re-migrate existing DIDs${NC}\n"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            list)
                find_all_users
                echo -e "\n${BLUE}Total: ${TOTAL_FOUND} user(s)${NC}"
                exit 0
                ;;
            existing-only)
                echo -e "${CYAN}📋 Migration mode: existing DIDs only (no creation)${NC}\n"
                shift
                migrate_all "false"
                print_summary
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
                migrate_all "true"
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

# Check for nostr_did_client.py (optional but recommended)
if [[ ! -f "$NOSTR_DID_CLIENT_SCRIPT" ]]; then
    echo -e "${YELLOW}⚠️  Note: nostr_did_client.py not found${NC}"
    echo -e "${YELLOW}   DID existence check will be skipped (may cause duplicates)${NC}"
fi

# Execute main
main "$@"

