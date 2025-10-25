#!/bin/bash
################################################################################
# Script: did_manager_nostr.sh
# Description: Nostr-native DID Document Manager
# 
# Manages DID documents using Nostr as the source of truth (kind 30311 events)
# Local files are only used as cache for performance
#
# Source of Truth: Nostr relays (Parameterized Replaceable Events)
# Cache: Local filesystem (~/.zen/game/nostr/${email}/did.json.cache)
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Colors for display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Nostr configuration
NOSTR_RELAYS="${NOSTR_RELAYS:-ws://127.0.0.1:7777 wss://relay.copylaradio.com}"
NOSTR_PUBLISH_DID_SCRIPT="${MY_PATH}/nostr_publish_did.py"
NOSTR_FETCH_DID_SCRIPT="${MY_PATH}/nostr_did_client.py"

# DID Event configuration
DID_EVENT_KIND=30311
DID_TAG_IDENTIFIER="did"

################################################################################
# Helper: Get user's Nostr keys from .secret.nostr
################################################################################
get_nostr_keys() {
    local email="$1"
    local secret_file="$HOME/.zen/game/nostr/${email}/.secret.nostr"
    
    if [[ ! -f "$secret_file" ]]; then
        echo -e "${RED}❌ Nostr keys file not found: ${secret_file}${NC}" >&2
        echo -e "${YELLOW}💡 Keys should be in .secret.nostr file (NSEC=...; NPUB=...; HEX=...)${NC}" >&2
        return 1
    fi
    
    # Source the .secret.nostr file to get NSEC, NPUB, HEX
    source "$secret_file" 2>/dev/null
    
    if [[ -z "$NSEC" ]] || [[ -z "$NPUB" ]]; then
        echo -e "${RED}❌ Invalid .secret.nostr file format for ${email}${NC}" >&2
        echo -e "${YELLOW}💡 Expected format: NSEC=nsec1...; NPUB=npub1...; HEX=...${NC}" >&2
        return 1
    fi
    
    echo "${NSEC}|${NPUB}"
    return 0
}

################################################################################
# Helper: Create initial DID document
################################################################################
create_initial_did() {
    local email="$1"
    local npub="$2"
    
    echo -e "${CYAN}📝 Creating initial DID document for ${email}${NC}"
    
    # Convert npub to hex for DID Nostr spec compliance
    local hex_pubkey=""
    if command -v python3 &> /dev/null; then
        # Use nostr2hex.py to convert npub to hex
        hex_pubkey=$(python3 "${MY_PATH}/nostr2hex.py" "$npub" 2>/dev/null)
    fi
    
    if [[ -z "$hex_pubkey" ]]; then
        echo -e "${RED}❌ Impossible de convertir npub en hex pour le DID${NC}" >&2
        return 1
    fi
    
    # Use external template (required)
    local template_file="${MY_PATH}/../templates/NOSTR/did_template.json"
    if [[ ! -f "$template_file" ]]; then
        echo -e "${RED}❌ DID template not found: ${template_file}${NC}" >&2
        echo -e "${YELLOW}💡 Template is required for DID creation${NC}" >&2
        return 1
    fi
    
    # Use external template with variable substitution
    local current_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create a temporary file for the template processing
    local temp_template=$(mktemp)
    
    # Copy template and substitute variables
    sed -e "s/_HEX_PUBKEY_/${hex_pubkey}/g" \
        -e "s/_EMAIL_/${email}/g" \
        -e "s/_CREATED_DATE_/${current_date}/g" \
        -e "s/_UPDATED_DATE_/${current_date}/g" \
        -e "s/_G1_PUBKEY_/${G1PUBNOSTR:-}/g" \
        -e "s/_BITCOIN_ADDRESS_/${BITCOIN:-}/g" \
        -e "s/_NOSTRNS_/${NOSTRNS:-}/g" \
        -e "s|_MY_RELAY_|${myRELAY:-wss://relay.copylaradio.com}|g" \
        -e "s|_MY_IPFS_|${myIPFS:-http://127.0.0.1:8080}|g" \
        -e "s|_USPOT_|${uSPOT:-https://u.copylaradio.com}|g" \
        -e "s/_UPLANET_G1PUB_8_/${UPLANETG1PUB:0:8}/g" \
        -e "s/_LATITUDE_/${ZLAT:-}/g" \
        -e "s/_LONGITUDE_/${ZLON:-}/g" \
        -e "s/_LANGUAGE_/${LANG:-fr}/g" \
        -e "s/_YOUSER_/${YOUSER:-}/g" \
        -e "s/_IPFS_NODE_ID_/${IPFSNODEID:-}/g" \
        "$template_file" > "$temp_template"
    
    # Output the processed template
    cat "$temp_template"
    
    # Cleanup
    rm -f "$temp_template"
}

################################################################################
# Fetch DID from Nostr relays
################################################################################
fetch_did_from_nostr() {
    local email="$1"
    local output_file="${2:-}"
    
    local keys=$(get_nostr_keys "$email")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local npub=$(echo "$keys" | cut -d'|' -f2)
    
    echo -e "${CYAN}📡 Fetching DID from Nostr relays for ${email}${NC}"
    echo -e "${BLUE}   NPub: ${npub:0:16}...${NC}"
    
    # Convert npub to hex for DID Nostr spec
    local hex_pubkey=""
    if command -v python3 &> /dev/null; then
        hex_pubkey=$(python3 "${MY_PATH}/nostr2hex.py" "$npub" 2>/dev/null)
    fi
    
    if [[ -z "$hex_pubkey" ]]; then
        echo -e "${RED}❌ Impossible de convertir npub en hex${NC}" >&2
        return 1
    fi
    
    # Fetch DID using nostr_did_client.py script
    if [[ -f "$NOSTR_FETCH_DID_SCRIPT" ]]; then
        echo -e "${CYAN}🔍 Using nostr_did_client.py to query relays...${NC}"
        
        local did_content=""
        for relay in $NOSTR_RELAYS; do
            echo -e "${BLUE}   Querying: ${relay}${NC}"
            
            # Use the fetch command with proper syntax for nostr_did_client.py
            did_content=$(python3 "$NOSTR_FETCH_DID_SCRIPT" fetch --author "$npub" --relay "$relay" --kind "$DID_EVENT_KIND" 2>/dev/null)
            
            if [[ -n "$did_content" ]] && [[ "$did_content" != "null" ]] && echo "$did_content" | jq empty 2>/dev/null; then
                echo -e "${GREEN}✅ DID found on ${relay}${NC}"
                break
            fi
        done
        
        if [[ -z "$did_content" ]] || [[ "$did_content" == "null" ]]; then
            echo -e "${YELLOW}⚠️  No DID found on Nostr relays for ${email}${NC}"
            return 1
        fi
        
        # Output or save
        if [[ -n "$output_file" ]]; then
            echo "$did_content" | jq . > "$output_file"
            echo -e "${GREEN}✅ DID saved to: ${output_file}${NC}"
        else
            echo "$did_content" | jq .
        fi
        
        return 0
    else
        echo -e "${YELLOW}⚠️  nostr_did_client.py script not found${NC}"
        echo -e "${CYAN}💡 Falling back to cache...${NC}"
        return 1
    fi
}

################################################################################
# Publish DID to Nostr relays
################################################################################
publish_did_to_nostr() {
    local email="$1"
    local did_file="$2"
    
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}❌ DID file not found: ${did_file}${NC}"
        return 1
    fi
    
    local keys=$(get_nostr_keys "$email")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local nsec=$(echo "$keys" | cut -d'|' -f1)
    
    echo -e "${CYAN}📡 Publishing DID to Nostr relays...${NC}"
    
    # Check if publish script exists
    if [[ ! -f "$NOSTR_PUBLISH_DID_SCRIPT" ]]; then
        echo -e "${RED}❌ Nostr publish script not found: ${NOSTR_PUBLISH_DID_SCRIPT}${NC}"
        return 1
    fi
    
    # Publish to all relays
    python3 "$NOSTR_PUBLISH_DID_SCRIPT" "$nsec" "$did_file" $NOSTR_RELAYS
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ DID published to Nostr${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to publish DID to Nostr${NC}"
        return 1
    fi
}

################################################################################
# Main function: Update DID document (Nostr-native)
################################################################################
update_did_document() {
    local email="$1"
    local update_type="$2"  # LOCATAIRE, SOCIETAIRE_SATELLITE, SOCIETAIRE_CONSTELLATION, INFRASTRUCTURE, WOT_MEMBER, etc.
    local montant_zen="${3:-0}"
    local montant_g1="${4:-0}"
    local wot_g1pub="${5:-}"
    
    # Paths
    local did_cache="$HOME/.zen/game/nostr/${email}/did.json.cache"
    local did_temp=$(mktemp)
    
    echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${NC}"
    echo -e "${CYAN}📝 DID Update Request${NC}"
    echo -e "${BLUE}   Email: ${email}${NC}"
    echo -e "${BLUE}   Type: ${update_type}${NC}"
    echo -e "${BLUE}   Amount: ${montant_zen} Ẑen / ${montant_g1} Ğ1${NC}"
    echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${NC}"
    
    # Get Nostr keys
    local keys=$(get_nostr_keys "$email")
    if [[ $? -ne 0 ]]; then
        rm -f "$did_temp"
        return 1
    fi
    
    local npub=$(echo "$keys" | cut -d'|' -f2)
    
    # Step 1: Fetch current DID from Nostr (source of truth)
    echo -e "\n${CYAN}Step 1/6: Fetching current DID from Nostr...${NC}"
    
    local current_did=""
    if fetch_did_from_nostr "$email" "$did_temp"; then
        current_did=$(cat "$did_temp")
        echo -e "${GREEN}✅ Current DID retrieved from Nostr${NC}"
    else
        echo -e "${YELLOW}⚠️  No DID found on Nostr, checking cache...${NC}"
        
        if [[ -f "$did_cache" ]]; then
            echo -e "${BLUE}📂 Loading from cache: ${did_cache}${NC}"
            current_did=$(cat "$did_cache")
        else
            echo -e "${YELLOW}⚠️  No cache found, creating new DID${NC}"
            current_did=$(create_initial_did "$email" "$npub")
        fi
        
        echo "$current_did" > "$did_temp"
    fi
    
    # Step 2: Update DID fields
    echo -e "\n${CYAN}Step 2/6: Updating DID fields...${NC}"
    
    local did_updated="${did_temp}.updated"
    
    # Prepare update metadata
    local quota=""
    local services=""
    local contract_status=""
    local wot_metadata=""
    
    case "$update_type" in
        "LOCATAIRE")
            quota="10GB"
            services="uDRIVE IPFS storage"
            contract_status="active_rental"
            ;;
        "SOCIETAIRE_SATELLITE")
            quota="128GB"
            services="uDRIVE + NextCloud private storage"
            contract_status="cooperative_member_satellite"
            ;;
        "SOCIETAIRE_CONSTELLATION")
            quota="128GB"
            services="uDRIVE + NextCloud + AI services"
            contract_status="cooperative_member_constellation"
            ;;
        "INFRASTRUCTURE")
            quota="N/A"
            services="Node infrastructure capital"
            contract_status="infrastructure_contributor"
            ;;
        "TREASURY_CONTRIBUTION")
            contract_status="cooperative_treasury_contributor"
            ;;
        "RND_CONTRIBUTION")
            contract_status="cooperative_rnd_contributor"
            ;;
        "ASSETS_CONTRIBUTION")
            contract_status="cooperative_assets_contributor"
            ;;
        "WOT_MEMBER")
            if [[ -n "$wot_g1pub" ]]; then
                wot_metadata="{
                    \"g1pub\": \"$wot_g1pub\",
                    \"cesiumLink\": \"$CESIUMIPFS/#/app/wot/$wot_g1pub/\",
                    \"verifiedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                    \"description\": \"WoT Duniter member forge (external to UPlanet)\"
                }"
            fi
            ;;
        "ACCOUNT_DEACTIVATED")
            quota="N/A"
            services="Account deactivated - no services available"
            contract_status="account_deactivated"
            ;;
        *)
            echo -e "${RED}❌ Unknown update type: ${update_type}${NC}"
            rm -f "$did_temp" "$did_updated"
            return 1
            ;;
    esac
    
    # Build jq command for updates
    local jq_cmd=".metadata.updated = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    
    [[ -n "$contract_status" ]] && jq_cmd="$jq_cmd | .metadata.contractStatus = \"$contract_status\""
    [[ -n "$quota" ]] && jq_cmd="$jq_cmd | .metadata.storageQuota = \"$quota\""
    [[ -n "$services" ]] && jq_cmd="$jq_cmd | .metadata.services = \"$services\""
    
    if [[ "$montant_zen" != "0" ]]; then
        jq_cmd="$jq_cmd | .metadata.lastPayment = {
            \"amount_zen\": \"$montant_zen\",
            \"amount_g1\": \"$montant_g1\",
            \"date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"nodeId\": \"$IPFSNODEID\"
        }"
    fi
    
    [[ -n "$wot_metadata" ]] && jq_cmd="$jq_cmd | .metadata.wotDuniterMember = $wot_metadata"
    
    # Add Astroport station info
    if [[ -n "$IPFSNODEID" ]]; then
        jq_cmd="$jq_cmd | .metadata.astroportStation = {
            \"ipns\": \"$IPFSNODEID\",
            \"description\": \"Astroport station IPNS address\",
            \"updatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
    fi
    
    # Add deactivation metadata for ACCOUNT_DEACTIVATED
    if [[ "$update_type" == "ACCOUNT_DEACTIVATED" ]]; then
        jq_cmd="$jq_cmd | .metadata.deactivation = {
            \"status\": \"deactivated\",
            \"reason\": \"Account destroyed by user request\",
            \"deactivatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"dataRetention\": \"backup_available\",
            \"recoveryPossible\": false,
            \"description\": \"This account has been permanently deactivated\"
        }"
    fi
    
    # Add wallet addresses
    local multipass_g1pub=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
    if [[ -n "$multipass_g1pub" ]]; then
        jq_cmd="$jq_cmd | .metadata.multipassWallet = {
            \"g1pub\": \"$multipass_g1pub\",
            \"type\": \"MULTIPASS\",
            \"description\": \"Ẑ revenue wallet for service operations\",
            \"updatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
    fi
    
    # Add France Connect compliance metadata (only for KYC-verified users)
    # Check if user has WoT verification (0.01Ğ1 transaction from Duniter forgeron)
    local wot_verified=false
    local zencard_g1pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
    if [[ -n "$zencard_g1pub" ]] && [[ -f "$HOME/.zen/tmp/coucou/${zencard_g1pub}.2nd" ]]; then
        wot_verified=true
    fi
    
    if [[ "$wot_verified" == "true" ]]; then
        jq_cmd="$jq_cmd | .metadata.franceConnect = {
            \"compliance\": \"enabled\",
            \"identityProvider\": \"UPlanet\",
            \"verificationLevel\": \"enhanced\",
            \"kycStatus\": \"verified\",
            \"wotVerification\": \"completed\",
            \"supportedServices\": [
                \"france-identite\",
                \"ameli\",
                \"impots\",
                \"caf\",
                \"pole-emploi\"
            ],
            \"dataSharing\": {
                \"consentRequired\": true,
                \"scope\": \"minimal\",
                \"retentionPeriod\": \"1_year\"
            },
            \"lastVerification\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"certificationLevel\": \"level_2\"
        }"
    else
        jq_cmd="$jq_cmd | .metadata.franceConnect = {
            \"compliance\": \"disabled\",
            \"identityProvider\": \"UPlanet\",
            \"verificationLevel\": \"basic\",
            \"kycStatus\": \"pending\",
            \"wotVerification\": \"required\",
            \"supportedServices\": [],
            \"dataSharing\": {
                \"consentRequired\": true,
                \"scope\": \"none\",
                \"retentionPeriod\": \"none\"
            },
            \"lastVerification\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"certificationLevel\": \"level_0\"
        }"
    fi
    
    local zencard_g1pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
    if [[ -n "$zencard_g1pub" ]]; then
        jq_cmd="$jq_cmd | .metadata.zencardWallet = {
            \"g1pub\": \"$zencard_g1pub\",
            \"type\": \"ZEN_CARD\",
            \"description\": \"Ẑ society wallet for cooperative shares\",
            \"updatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
    fi
    
    # Execute update with better error handling
    echo -e "${BLUE}🔧 Executing jq command...${NC}"
    if jq "$jq_cmd" "$did_temp" > "$did_updated" 2>/dev/null && [[ -s "$did_updated" ]]; then
        echo -e "${GREEN}✅ DID fields updated${NC}"
    else
        echo -e "${RED}❌ Failed to update DID fields${NC}"
        echo -e "${YELLOW}💡 Debug info:${NC}"
        echo -e "${YELLOW}   Input file: $did_temp${NC}"
        echo -e "${YELLOW}   Output file: $did_updated${NC}"
        echo -e "${YELLOW}   jq command: $jq_cmd${NC}"
        
        # Try to show the input file content for debugging
        if [[ -f "$did_temp" ]]; then
            echo -e "${YELLOW}   Input file content (first 200 chars):${NC}"
            head -c 200 "$did_temp" | cat
            echo ""
        fi
        
        rm -f "$did_temp" "$did_updated"
        return 1
    fi
    
    # Step 3: Validate updated DID
    echo -e "\n${CYAN}Step 3/6: Validating DID document...${NC}"
    
    if validate_did_document "$did_updated"; then
        echo -e "${GREEN}✅ DID validation passed${NC}"
    else
        echo -e "${RED}❌ DID validation failed${NC}"
        rm -f "$did_temp" "$did_updated"
        return 1
    fi
    
    # Step 4: Publish to Nostr (SOURCE OF TRUTH)
    echo -e "\n${CYAN}Step 4/6: Publishing to Nostr (source of truth)...${NC}"
    
    if publish_did_to_nostr "$email" "$did_updated"; then
        echo -e "${GREEN}✅ DID published to Nostr (source of truth updated)${NC}"
    else
        echo -e "${RED}❌ Failed to publish to Nostr${NC}"
        rm -f "$did_temp" "$did_updated"
        return 1
    fi
    
    # Step 5: Update local cache
    echo -e "\n${CYAN}Step 5/6: Updating local cache...${NC}"
    
    mkdir -p "$(dirname "$did_cache")"
    cp "$did_updated" "$did_cache"
    echo -e "${GREEN}✅ Local cache updated: ${did_cache}${NC}"
    
    # Step 6: Additional operations
    echo -e "\n${CYAN}Step 6/6: Additional operations...${NC}"
    
    # Update APP/uDRIVE/Apps/.well-known/did.json
    update_udrive_did "$email" "$did_updated"
    
    # Republish to IPNS (for web access)
    republish_did_ipns "$email"
    
    # Manage U.SOCIETY file (for TiddlyWiki compatibility)
    manage_usociety_file "$email" "$update_type" "$montant_zen"
    
    # Cleanup
    rm -f "$did_temp" "$did_updated"
    
    # Final summary
    echo -e "\n${MAGENTA}$(printf '=%.0s' {1..80})${NC}"
    echo -e "${GREEN}✅ DID Update Complete${NC}"
    echo -e "${BLUE}   Email: ${email}${NC}"
    echo -e "${BLUE}   Type: ${update_type}${NC}"
    echo -e "${BLUE}   Status: Published to Nostr + Cached locally${NC}"
    echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${NC}"
    
    return 0
}

################################################################################
# Update uDRIVE Apps/.well-known/did.json
################################################################################
update_udrive_did() {
    local email="$1"
    local did_file="$2"
    
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}❌ DID file not found: $did_file${NC}"
        return 1
    fi
    
    local udrive_did_path="$HOME/.zen/game/nostr/${email}/APP/uDRIVE/Apps/.well-known"
    local udrive_did_file="$udrive_did_path/did.json"
    
    echo -e "${CYAN}📁 Updating uDRIVE Apps/.well-known/index.html with embedded DID...${NC}"
    
    # Create directory if it doesn't exist
    mkdir -p "$udrive_did_path"
    
    # Update the index.html viewer with embedded JSON (no separate did.json file)
    local index_file="$udrive_did_path/index.html"
    local template_file="$HOME/.zen/Astroport.ONE/templates/NOSTR/did_viewer.html"
    
    if [[ -f "$template_file" ]]; then
        # Copy template and inject JSON data
        cp "$template_file" "$index_file"
        
        # Inject DID JSON data into the HTML file (properly escaped for JavaScript)
        local did_json_content=$(jq -c . "$did_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        sed -i "s|const _DID_JSON_ = null;|const _DID_JSON_ = JSON.parse(\"$did_json_content\");|g" "$index_file"
        
        echo -e "${GREEN}✅ uDRIVE DID viewer updated with embedded JSON: ${index_file}${NC}"
        return 0
    elif [[ -f "$index_file" ]]; then
        # Update existing file with new JSON data (properly escaped for JavaScript)
        local did_json_content=$(jq -c . "$did_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        sed -i "s|const _DID_JSON_ = .*;|const _DID_JSON_ = JSON.parse(\"$did_json_content\");|g" "$index_file"
        
        echo -e "${GREEN}✅ uDRIVE DID viewer updated with new JSON data${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  DID viewer (index.html) not found${NC}"
        echo -e "${CYAN}💡 Run make_NOSTRCARD.sh to create the viewer${NC}"
        return 1
    fi
}

################################################################################
# Validate DID document
################################################################################
validate_did_document() {
    local did_file="$1"
    
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}❌ DID file not found: $did_file${NC}"
        return 1
    fi
    
    # Check JSON validity
    if ! jq empty "$did_file" 2>/dev/null; then
        echo -e "${RED}❌ Invalid JSON: $did_file${NC}"
        return 1
    fi
    
    # Check required fields (W3C DID Core spec)
    local required_fields=("id" "verificationMethod")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$did_file" >/dev/null 2>&1; then
            echo -e "${RED}❌ Missing required field: $field${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}✅ DID document valid${NC}"
    return 0
}

################################################################################
# Republish DID to IPNS (for web access via IPFS gateways)
################################################################################
republish_did_ipns() {
    local email="$1"
    local nostrns_file="$HOME/.zen/game/nostr/${email}/NOSTRNS"
    
    if [[ -f "$nostrns_file" ]]; then
        local g1pubnostr=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
        
        if [[ -n "$g1pubnostr" ]]; then
            echo -e "${CYAN}📡 Republishing to IPNS for web access...${NC}"
            local nostripfs=$(ipfs add -rwq "$HOME/.zen/game/nostr/${email}/" | tail -n 1)
            ipfs name publish --key "${g1pubnostr}:NOSTR" "/ipfs/${nostripfs}" 2>&1 >/dev/null &
            echo -e "${GREEN}✅ IPNS publication launched in background${NC}"
        fi
    fi
}

################################################################################
# Manage U.SOCIETY file (for TiddlyWiki compatibility)
################################################################################
manage_usociety_file() {
    local email="$1"
    local update_type="$2"
    local montant_zen="${3:-0}"
    
    # Only create U.SOCIETY for cooperative member types
    case "$update_type" in
        "SOCIETAIRE_SATELLITE"|"SOCIETAIRE_CONSTELLATION"|"INFRASTRUCTURE")
            ;;
        *)
            return 0
            ;;
    esac
    
    echo -e "${CYAN}📝 Creating U.SOCIETY file...${NC}"
    
    if [[ ! -d "$HOME/.zen/game/players/${email}" ]]; then
        echo -e "${YELLOW}⚠️  Player directory not found, skipping U.SOCIETY${NC}"
        return 0
    fi
    
    local society_date=$(date '+%Y-%m-%d')
    local usociety_file="$HOME/.zen/game/players/${email}/U.SOCIETY"
    local usociety_end_file="$HOME/.zen/game/players/${email}/U.SOCIETY.end"
    
    echo "$society_date" > "$usociety_file"
    
    # Calculate end date
    local end_date
    case "$update_type" in
        "SOCIETAIRE_SATELLITE")
            end_date=$(date -d "$society_date + 365 days" '+%Y-%m-%d')
            ;;
        "SOCIETAIRE_CONSTELLATION")
            end_date=$(date -d "$society_date + 1095 days" '+%Y-%m-%d')
            ;;
        "INFRASTRUCTURE")
            end_date="9999-12-31"
            ;;
    esac
    
    echo "$end_date" > "$usociety_end_file"
    echo -e "${GREEN}✅ U.SOCIETY files created (expires: ${end_date})${NC}"
    
    # Create symlinks in nostr directory
    if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
        ln -sf "$usociety_file" "$HOME/.zen/game/nostr/${email}/U.SOCIETY"
        ln -sf "$usociety_end_file" "$HOME/.zen/game/nostr/${email}/U.SOCIETY.end"
        echo -e "${GREEN}✅ Symlinks created in nostr directory${NC}"
    fi
}

################################################################################
# Sync DID from Nostr to local cache (for performance)
################################################################################
sync_did_to_cache() {
    local email="$1"
    local did_cache="$HOME/.zen/game/nostr/${email}/did.json.cache"
    
    echo -e "${CYAN}🔄 Syncing DID from Nostr to cache...${NC}"
    
    if fetch_did_from_nostr "$email" "$did_cache"; then
        echo -e "${GREEN}✅ Cache synchronized with Nostr${NC}"
        
        # Also update uDRIVE if it exists
        update_udrive_did "$email" "$did_cache"
        
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to sync from Nostr${NC}"
        return 1
    fi
}

################################################################################
# Show wallet addresses
################################################################################
show_wallet_addresses() {
    local email="$1"
    
    if [[ -z "$email" ]]; then
        echo -e "${RED}❌ Usage: $0 show-wallets EMAIL${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Wallet Addresses for: ${email}${NC}"
    echo -e "${YELLOW}$(printf '=%.0s' {1..60})${NC}"
    
    # MULTIPASS (Ẑ revenue)
    local multipass_g1pub=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
    if [[ -n "$multipass_g1pub" ]]; then
        echo -e "${GREEN}💳 MULTIPASS (Ẑ revenue):${NC}"
        echo -e "   ${CYAN}G1PUB: ${multipass_g1pub}${NC}"
        echo -e "   ${CYAN}Type: Service operations wallet${NC}"
    else
        echo -e "${YELLOW}⚠️  MULTIPASS not found${NC}"
    fi
    
    # ZEN Card (Ẑ society)
    local zencard_g1pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
    if [[ -n "$zencard_g1pub" ]]; then
        echo -e "${GREEN}🏦 ZEN Card (Ẑ society):${NC}"
        echo -e "   ${CYAN}G1PUB: ${zencard_g1pub}${NC}"
        echo -e "   ${CYAN}Type: Cooperative shares wallet${NC}"
    else
        echo -e "${YELLOW}⚠️  ZEN Card not found${NC}"
    fi
    
    # Astroport station
    if [[ -n "$IPFSNODEID" ]]; then
        echo -e "${GREEN}🏭 Astroport Station:${NC}"
        echo -e "   ${CYAN}IPNS: ${IPFSNODEID}${NC}"
    fi
}

################################################################################
# Validate France Connect compliance
################################################################################
validate_france_connect() {
    local email="$1"
    local did_file="$2"
    
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}❌ DID file not found: $did_file${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🇫🇷 Validating France Connect compliance...${NC}"
    
    # Check if France Connect metadata exists
    if ! jq -e '.metadata.franceConnect' "$did_file" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  France Connect metadata not found${NC}"
        return 1
    fi
    
    # Validate required fields
    local required_fields=("compliance" "identityProvider" "verificationLevel" "supportedServices")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".metadata.franceConnect.$field" "$did_file" >/dev/null 2>&1; then
            echo -e "${RED}❌ Missing France Connect field: $field${NC}"
            return 1
        fi
    done
    
    # Check compliance status
    local compliance=$(jq -r '.metadata.franceConnect.compliance' "$did_file")
    if [[ "$compliance" != "enabled" ]]; then
        echo -e "${YELLOW}⚠️  France Connect compliance not enabled${NC}"
        return 1
    fi
    
    # Check verification level
    local verification_level=$(jq -r '.metadata.franceConnect.verificationLevel' "$did_file")
    if [[ "$verification_level" == "basic" ]]; then
        echo -e "${YELLOW}⚠️  Basic verification level - limited service access${NC}"
    elif [[ "$verification_level" == "enhanced" ]]; then
        echo -e "${GREEN}✅ Enhanced verification level - full service access${NC}"
    fi
    
    echo -e "${GREEN}✅ France Connect compliance validated${NC}"
    return 0
}

################################################################################
# Show help
################################################################################
show_help() {
    cat <<EOF
${BLUE}did_manager_nostr.sh - Nostr-native DID Document Manager${NC}

${CYAN}Source of Truth: Nostr relays (kind 30311 events)${NC}
${CYAN}Local Storage: Cache only (for performance)${NC}

Usage:
  $0 update EMAIL TYPE [MONTANT_ZEN] [MONTANT_G1] [WOT_G1PUB]
  $0 fetch EMAIL
  $0 sync EMAIL
  $0 update-udrive EMAIL
  $0 validate FILE
  $0 validate-france-connect EMAIL
  $0 show-wallets EMAIL
  $0 usociety EMAIL TYPE [MONTANT_ZEN]
  $0 help

Update Types:
  LOCATAIRE                    - MULTIPASS recharge (rental)
  SOCIETAIRE_SATELLITE        - Satellite cooperative shares
  SOCIETAIRE_CONSTELLATION    - Constellation cooperative shares
  INFRASTRUCTURE              - Infrastructure capital contribution
  TREASURY_CONTRIBUTION       - Treasury fund contribution
  RND_CONTRIBUTION            - R&D fund contribution
  ASSETS_CONTRIBUTION         - Assets fund contribution
  WOT_MEMBER                  - Duniter WoT member identification
  ACCOUNT_DEACTIVATED         - Account deactivated/destroyed

Examples:
  $0 update user@example.com LOCATAIRE 50 5.0
  $0 update user@example.com SOCIETAIRE_SATELLITE 512 51.2
  $0 fetch user@example.com
  $0 sync user@example.com
  $0 update-udrive user@example.com
  $0 show-wallets user@example.com

Requirements:
  - Python 3 with pynostr library
  - nostr_publish_did.py script

Environment Variables:
  NOSTR_RELAYS - Space-separated relay URLs (default: ws://127.0.0.1:7777 wss://relay.copylaradio.com)
  IPFSNODEID   - Astroport station IPNS address

EOF
}

################################################################################
# Main entry point
################################################################################
main() {
    case "${1:-}" in
        "update")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}❌ Usage: $0 update EMAIL TYPE [MONTANT_ZEN] [MONTANT_G1] [WOT_G1PUB]${NC}"
                exit 1
            fi
            update_did_document "$2" "$3" "${4:-0}" "${5:-0}" "${6:-}"
            ;;
        "fetch")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 fetch EMAIL${NC}"
                exit 1
            fi
            fetch_did_from_nostr "$2"
            ;;
        "sync")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 sync EMAIL${NC}"
                exit 1
            fi
            sync_did_to_cache "$2"
            ;;
        "update-udrive")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 update-udrive EMAIL${NC}"
                exit 1
            fi
            local did_cache="$HOME/.zen/game/nostr/$2/did.json.cache"
            if [[ -f "$did_cache" ]]; then
                update_udrive_did "$2" "$did_cache"
            else
                echo -e "${RED}❌ No DID cache found for $2${NC}"
                echo -e "${CYAN}💡 Run 'sync $2' first to fetch from Nostr${NC}"
                exit 1
            fi
            ;;
        "validate")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 validate FILE${NC}"
                exit 1
            fi
            validate_did_document "$2"
            ;;
        "validate-france-connect")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 validate-france-connect EMAIL${NC}"
                exit 1
            fi
            local did_cache="$HOME/.zen/game/nostr/$2/did.json.cache"
            if [[ -f "$did_cache" ]]; then
                validate_france_connect "$2" "$did_cache"
            else
                echo -e "${RED}❌ No DID cache found for $2${NC}"
                echo -e "${CYAN}💡 Run 'sync $2' first to fetch from Nostr${NC}"
                exit 1
            fi
            ;;
        "show-wallets")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 show-wallets EMAIL${NC}"
                exit 1
            fi
            show_wallet_addresses "$2"
            ;;
        "usociety")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}❌ Usage: $0 usociety EMAIL TYPE [MONTANT_ZEN]${NC}"
                exit 1
            fi
            manage_usociety_file "$2" "$3" "${4:-0}"
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: ${1:-}${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Execute main
main "$@"

