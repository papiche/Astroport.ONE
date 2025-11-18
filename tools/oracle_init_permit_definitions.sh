#!/bin/bash
################################################################################
# Script: oracle_init_permit_definitions.sh
# Description: Interactive permit definitions management via NOSTR
#
# This script allows to:
# - Add permit definitions from JSON template to NOSTR (OFFICIAL PERMITS ONLY)
# - Edit existing permit definitions on NOSTR
# - Delete permit definitions (with safety checks)
#
# ⚠️  IMPORTANT: This script is for OFFICIAL PERMITS only (PERMIT_ORE_V1, etc.)
#    For AUTO-PROCLAIMED PROFESSIONS (WoTx2), use the web interface:
#    → /wotx2 → "Créer une Nouvelle Profession WoTx2"
#
#    Auto-proclaimed professions:
#    - Created via /wotx2 interface (100% dynamic)
#    - ID format: PERMIT_[NOM]_X1
#    - Automatic progression: X1 → X2 → ... → X144 → ... (unlimited)
#    - No bootstrap required (starts with 1 signature)
#
# Usage: ./oracle_init_permit_definitions.sh
#
# License: AGPL-3.0
# Author: UPlanet/Astroport.ONE Team (support@qo-op.com)
# Version: 3.0 - Updated for 100% Dynamic System
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

# Paths
DEFINITIONS_FILE="${MY_PATH}/../templates/NOSTR/permit_definitions.json"
NOSTR_GET_EVENTS="${MY_PATH}/nostr_get_events.sh"
NOSTR_SEND_NOTE="${MY_PATH}/nostr_send_note.py"
UPLANET_G1_KEYFILE="${HOME}/.zen/game/uplanet.G1.nostr"
KEYGEN="${MY_PATH}/keygen"
NOSTR2HEX="${MY_PATH}/nostr2hex.py"

################################################################################
# Helper functions
################################################################################

generate_uplanet_g1_nostr_key() {
    # Generate NOSTR key for UPLANETNAME.G1 if it doesn't exist
    # Similar to make_NOSTRCARD.sh but for UPLANETNAME.G1 wallet
    
    if [[ -f "$UPLANET_G1_KEYFILE" ]]; then
        return 0  # Keyfile already exists
    fi
    
    if [[ -z "$UPLANETNAME" ]]; then
        echo -e "${RED}❌ UPLANETNAME not set in environment${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔑 Generating NOSTR key for UPLANETNAME.G1...${NC}"
    
    # Generate NOSTR keys using UPLANETNAME.G1 as SALT and PEPPER (like dunikey generation)
    local salt="${UPLANETNAME}.G1"
    local pepper="${UPLANETNAME}.G1"
    
    if [[ ! -f "$KEYGEN" ]]; then
        echo -e "${RED}❌ keygen tool not found at ${KEYGEN}${NC}"
        return 1
    fi
    
    # Generate private key
    local npriv=$("$KEYGEN" -t nostr "$salt" "$pepper" -s 2>/dev/null)
    if [[ -z "$npriv" ]]; then
        echo -e "${RED}❌ Failed to generate NOSTR private key${NC}"
        return 1
    fi
    
    # Generate public key
    local npub=$("$KEYGEN" -t nostr "$salt" "$pepper" 2>/dev/null)
    if [[ -z "$npub" ]]; then
        echo -e "${RED}❌ Failed to generate NOSTR public key${NC}"
        return 1
    fi
    
    # Generate HEX from public key
    local hex=""
    if [[ -f "$NOSTR2HEX" ]]; then
        hex=$("$NOSTR2HEX" "$npub" 2>/dev/null)
    fi
    
    # Create keyfile in the same format as make_NOSTRCARD.sh
    mkdir -p "$(dirname "$UPLANET_G1_KEYFILE")"
    cat > "$UPLANET_G1_KEYFILE" <<EOF
NSEC=$npriv; NPUB=$npub; HEX=$hex;
EOF
    chmod 600 "$UPLANET_G1_KEYFILE"
    
    echo -e "${GREEN}✅ Generated NOSTR keyfile: $UPLANET_G1_KEYFILE${NC}"
    return 0
}

check_tools() {
    local missing=0
    
    if [[ ! -f "$NOSTR_GET_EVENTS" ]]; then
        echo -e "${RED}❌ nostr_get_events.sh not found at ${NOSTR_GET_EVENTS}${NC}"
        missing=$((missing + 1))
    fi
    
    if [[ ! -f "$NOSTR_SEND_NOTE" ]]; then
        echo -e "${RED}❌ nostr_send_note.py not found at ${NOSTR_SEND_NOTE}${NC}"
        missing=$((missing + 1))
    fi
    
    if [[ ! -f "$DEFINITIONS_FILE" ]]; then
        echo -e "${RED}❌ Template file not found: ${DEFINITIONS_FILE} Attempting to create it"
        missing=$((missing + 1))
    fi
    
    # Generate UPLANETNAME.G1 NOSTR keyfile if it doesn't exist
    if [[ ! -f "$UPLANET_G1_KEYFILE" ]]; then
        if ! generate_uplanet_g1_nostr_key; then
            echo -e "${RED}❌ Failed to generate UPLANETNAME.G1 keyfile${NC}"
            echo -e "${YELLOW}   This script requires UPLANETNAME.G1 to publish permit definitions${NC}"
            missing=$((missing + 1))
        fi
    fi
    
    if [[ $missing -gt 0 ]]; then
        exit 1
    fi
}

get_nostr_definitions() {
    # Fetch permit definitions from NOSTR (kind 30500)
    "$NOSTR_GET_EVENTS" --kind 30500 --limit 100 2>/dev/null | \
        jq -c 'select(.kind == 30500)' 2>/dev/null || echo ""
}

get_nostr_definition_by_id() {
    # Fetch a specific permit definition by ID (using tag-d filter)
    local permit_id="$1"
    if [[ -z "$permit_id" ]]; then
        echo ""
        return
    fi
    "$NOSTR_GET_EVENTS" --kind 30500 --tag-d "$permit_id" --limit 1 2>/dev/null | \
        jq -c 'select(.kind == 30500)' 2>/dev/null | head -1 || echo ""
}

get_template_definitions() {
    # Get definitions from JSON template
    if [[ -f "$DEFINITIONS_FILE" ]]; then
        jq -c '.definitions[]' "$DEFINITIONS_FILE" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

parse_permit_from_nostr_event() {
    local event_json="$1"
    local permit_id=$(echo "$event_json" | jq -r '.tags[] | select(.[0] == "d") | .[1]' 2>/dev/null)
    local content=$(echo "$event_json" | jq -r '.content' 2>/dev/null)
    
    if [[ -n "$permit_id" && -n "$content" ]]; then
        echo "$content" | jq -c ". + {id: \"$permit_id\"}" 2>/dev/null
    fi
}

check_permit_in_use() {
    local permit_id="$1"
    
    # Check if there are active credentials for this permit (kind 30503)
    local credentials=$("$NOSTR_GET_EVENTS" --kind 30503 --limit 1000 2>/dev/null | \
        jq -c "select(.kind == 30503 and (.content | fromjson | .permit_definition_id) == \"$permit_id\")" 2>/dev/null)
    
    local count=$(echo "$credentials" | grep -c '"kind":30503' 2>/dev/null || echo "0")
    
    if [[ "$count" -gt 0 ]]; then
        echo "$credentials"
        return 1  # In use
    fi
    
    return 0  # Not in use
}

display_permit() {
    local permit_json="$1"
    local permit_id=$(echo "$permit_json" | jq -r '.id // "N/A"')
    local name=$(echo "$permit_json" | jq -r '.name // "N/A"')
    local min_attestations=$(echo "$permit_json" | jq -r '.min_attestations // "N/A"')
    local valid_days=$(echo "$permit_json" | jq -r '.valid_duration_days // "N/A"')
    
    echo -e "  ${CYAN}ID:${NC} $permit_id"
    echo -e "  ${CYAN}Name:${NC} $name"
    echo -e "  ${CYAN}Min Attestations:${NC} $min_attestations"
    echo -e "  ${CYAN}Valid Duration:${NC} $valid_days days"
}

publish_permit_to_nostr() {
    local permit_json="$1"
    local permit_id=$(echo "$permit_json" | jq -r '.id')
    
    if [[ -z "$permit_id" ]]; then
        echo -e "${RED}❌ Invalid permit: missing ID${NC}"
        return 1
    fi
    
    # Build tags for parameterized replaceable event (NIP-33)
    # Tag 'd' is required for parameterized replaceable events
    local tags_json="[[\"d\",\"$permit_id\"]]"
    
    # Build content (permit definition as JSON)
    local content_json=$(echo "$permit_json" | jq -c '.')
    
    # Publish to NOSTR (kind 30500)
    # Publish to local strfry relay only - backfill_constellation.sh will sync to other nodes
    echo -e "${CYAN}📤 Publishing permit definition to NOSTR...${NC}"
    
    # Capture output to check for success
    local publish_output=$(python3 "$NOSTR_SEND_NOTE" \
        --keyfile "$UPLANET_G1_KEYFILE" \
        --kind 30500 \
        --content "$content_json" \
        --tags "$tags_json" \
        --relays "ws://127.0.0.1:7777" 2>&1)
    
    local publish_exit_code=$?
    
    # Check if publication was successful (exit code 0 means success)
    if [[ $publish_exit_code -eq 0 ]] && echo "$publish_output" | grep -q "successfully"; then
        echo -e "${GREEN}✅ Published permit definition: $permit_id${NC}"
        echo -e "${CYAN}⏳ Waiting for strfry database to sync (3 seconds)...${NC}"
        sleep 3
        
        # Verify the event was actually stored by querying for it using tag-d filter
        echo -e "${CYAN}🔍 Verifying event was stored...${NC}"
        local verification=$(get_nostr_definition_by_id "$permit_id")
        
        if [[ -n "$verification" ]]; then
            echo -e "${GREEN}✅ Verified: permit definition found in strfry database${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Warning: permit definition published but not yet visible in database${NC}"
            echo -e "${CYAN}💡 This may be normal - strfry may need a few more seconds to index the event${NC}"
            echo -e "${CYAN}💡 Try listing definitions again in a few seconds${NC}"
            return 0  # Still return success since publication succeeded
        fi
    else
        echo -e "${RED}❌ Failed to publish permit definition: $permit_id${NC}"
        if [[ -n "$publish_output" ]]; then
            echo -e "${YELLOW}Error details:${NC}"
            echo "$publish_output" | head -5
        fi
        return 1
    fi
}

################################################################################
# Menu functions
################################################################################

show_main_menu() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║     🎫 ORACLE PERMIT DEFINITIONS MANAGEMENT                   ║${NC}"
    echo -e "${MAGENTA}║     (Official Permits Only - WoTx2 via /wotx2)               ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  NOTE: This script manages OFFICIAL PERMITS only${NC}"
    echo -e "${YELLOW}   For AUTO-PROCLAIMED PROFESSIONS (WoTx2), use:${NC}"
    echo -e "${GREEN}   → Web Interface: /wotx2${NC}"
    echo -e "${GREEN}   → Creates: PERMIT_[NOM]_X1${NC}"
    echo -e "${GREEN}   → Auto-progression: X1 → X2 → ... → X144 → ...${NC}"
    echo ""
    echo -e "${CYAN}1.${NC} Add permit definition (from template) - OFFICIAL ONLY"
    echo -e "${CYAN}2.${NC} Edit permit definition (from NOSTR)"
    echo -e "${CYAN}3.${NC} Delete permit definition (from NOSTR)"
    echo -e "${CYAN}4.${NC} List all permit definitions (NOSTR)"
    echo -e "${CYAN}5.${NC} List template definitions (JSON)"
    echo -e "${CYAN}6.${NC} Exit"
    echo ""
}

show_template_list() {
    local definitions=$(get_template_definitions)
    
    if [[ -z "$definitions" ]]; then
        echo -e "${YELLOW}⚠️  No definitions found in template${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 Template Permit Definitions:${NC}"
    echo ""
    
    local index=1
    while IFS= read -r def; do
        local permit_id=$(echo "$def" | jq -r '.id')
        local name=$(echo "$def" | jq -r '.name')
        echo -e "  ${GREEN}$index.${NC} ${CYAN}$permit_id${NC} - $name"
        index=$((index + 1))
    done <<< "$definitions"
    
    echo ""
    return 0
}

show_nostr_list() {
    local events=$(get_nostr_definitions)
    
    if [[ -z "$events" ]]; then
        echo -e "${YELLOW}⚠️  No permit definitions found on NOSTR${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 NOSTR Permit Definitions:${NC}"
    echo ""
    
    local index=1
    local official_count=0
    local wotx2_count=0
    
    while IFS= read -r event; do
        local permit_json=$(parse_permit_from_nostr_event "$event")
        if [[ -n "$permit_json" ]]; then
            local permit_id=$(echo "$permit_json" | jq -r '.id')
            local name=$(echo "$permit_json" | jq -r '.name')
            
            # Check if it's a WoTx2 auto-proclaimed profession
            if [[ "$permit_id" =~ ^PERMIT_.*_X[0-9]+$ ]]; then
                local level=$(echo "$permit_id" | grep -oE '_X[0-9]+$' | sed 's/_X//')
                echo -e "  ${GREEN}$index.${NC} ${CYAN}$permit_id${NC} - $name ${MAGENTA}[WoTx2 - Niveau X${level}]${NC}"
                wotx2_count=$((wotx2_count + 1))
            else
                echo -e "  ${GREEN}$index.${NC} ${CYAN}$permit_id${NC} - $name ${YELLOW}[Officiel]${NC}"
                official_count=$((official_count + 1))
            fi
            index=$((index + 1))
        fi
    done <<< "$events"
    
    echo ""
    echo -e "${CYAN}Summary:${NC} ${YELLOW}$official_count${NC} Official | ${MAGENTA}$wotx2_count${NC} WoTx2 Auto-Proclaimed"
    echo ""
    return 0
}

add_permit() {
    local definitions=$(get_template_definitions)
    
    if [[ -z "$definitions" ]]; then
        echo -e "${RED}❌ No definitions available in template${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    show_template_list
    echo -e "${CYAN}Select permit definition to add (number):${NC} "
    read -r selection
    
    local permit_json=$(echo "$definitions" | sed -n "${selection}p")
    
    if [[ -z "$permit_json" ]]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    local permit_id=$(echo "$permit_json" | jq -r '.id')
    
    # Warn if trying to create auto-proclaimed profession via this script
    if [[ "$permit_id" =~ ^PERMIT_.*_X[0-9]+$ ]]; then
        echo -e "${YELLOW}⚠️  WARNING: This is an auto-proclaimed profession (WoTx2)${NC}"
        echo -e "${YELLOW}   Auto-proclaimed professions should be created via /wotx2 interface${NC}"
        echo -e "${CYAN}   This script is for OFFICIAL PERMITS only (PERMIT_ORE_V1, etc.)${NC}"
        echo ""
        echo -e "${CYAN}Continue anyway? (y/N):${NC} "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled${NC}"
            echo -e "${GREEN}💡 Use /wotx2 to create auto-proclaimed professions${NC}"
            read -p "Press Enter to continue..."
            return
        fi
    fi
    
    # Check if already exists on NOSTR
    local existing=$(get_nostr_definition_by_id "$permit_id")
    
    if [[ -n "$existing" ]]; then
        echo -e "${YELLOW}⚠️  Permit definition already exists on NOSTR: $permit_id${NC}"
        echo -e "${CYAN}Would you like to edit it instead? (y/N):${NC} "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            edit_permit_interactive "$permit_id"
        fi
        return
    fi
    
    echo -e "${CYAN}Permit Definition Preview:${NC}"
    display_permit "$permit_json"
    echo ""
    echo -e "${CYAN}Confirm publication to NOSTR? (y/N):${NC} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        publish_permit_to_nostr "$permit_json"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

edit_permit_interactive() {
    local target_permit_id="$1"
    local events=$(get_nostr_definitions)
    
    if [[ -z "$events" ]]; then
        echo -e "${RED}❌ No permit definitions found on NOSTR${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [[ -z "$target_permit_id" ]]; then
        show_nostr_list
        echo -e "${CYAN}Select permit definition to edit (number):${NC} "
        read -r selection
        
        local permit_json=$(echo "$events" | sed -n "${selection}p" | \
            jq -c 'select(.kind == 30500)' 2>/dev/null)
        
        if [[ -z "$permit_json" ]]; then
            echo -e "${RED}❌ Invalid selection${NC}"
            read -p "Press Enter to continue..."
            return
        fi
        
        target_permit_id=$(parse_permit_from_nostr_event "$permit_json" | jq -r '.id')
    fi
    
    # Find the permit - use direct query by ID if available for better performance
    local permit_event=""
    if [[ -n "$target_permit_id" ]]; then
        permit_event=$(get_nostr_definition_by_id "$target_permit_id")
    fi
    
    # Fallback to searching in events list if direct query didn't find it
    if [[ -z "$permit_event" ]]; then
        permit_event=$(echo "$events" | \
            jq -c "select(.tags[]? | .[0] == \"d\" and .[1] == \"$target_permit_id\")" 2>/dev/null | head -1)
    fi
    
    if [[ -z "$permit_event" ]]; then
        echo -e "${RED}❌ Permit definition not found: $target_permit_id${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    local permit_json=$(parse_permit_from_nostr_event "$permit_event")
    
    echo -e "${CYAN}Current Permit Definition:${NC}"
    display_permit "$permit_json"
    echo ""
    
    # Load from template if available (for editing)
    local template_def=$(get_template_definitions | \
        jq -c "select(.id == \"$target_permit_id\")" 2>/dev/null)
    
    if [[ -n "$template_def" ]]; then
        echo -e "${YELLOW}📋 Template version found. Use template as base? (y/N):${NC} "
        read -r use_template
        
        if [[ "$use_template" =~ ^[Yy]$ ]]; then
            permit_json="$template_def"
            echo -e "${GREEN}✅ Using template version${NC}"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Permit will be republished to NOSTR (parameterized replaceable event)${NC}"
    echo -e "${CYAN}Confirm edit? (y/N):${NC} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        publish_permit_to_nostr "$permit_json"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

delete_permit() {
    local events=$(get_nostr_definitions)
    
    if [[ -z "$events" ]]; then
        echo -e "${RED}❌ No permit definitions found on NOSTR${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    show_nostr_list
    echo -e "${CYAN}Select permit definition to delete (number):${NC} "
    read -r selection
    
    local permit_event=$(echo "$events" | sed -n "${selection}p" | \
        jq -c 'select(.kind == 30500)' 2>/dev/null)
    
    if [[ -z "$permit_event" ]]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    local permit_json=$(parse_permit_from_nostr_event "$permit_event")
    local permit_id=$(echo "$permit_json" | jq -r '.id')
    
    echo -e "${CYAN}Permit to delete:${NC}"
    display_permit "$permit_json"
    echo ""
    
    # Check if permit is in use
    echo -e "${CYAN}Checking if permit is in use...${NC}"
    local credentials=$(check_permit_in_use "$permit_id")
    local in_use=$?
    
    if [[ $in_use -eq 1 ]]; then
        local count=$(echo "$credentials" | grep -c '"kind":30503' 2>/dev/null || echo "0")
        echo -e "${RED}❌ Cannot delete permit definition: $permit_id${NC}"
        echo -e "${RED}   Active credentials found: $count${NC}"
        echo -e "${YELLOW}   This permit is currently in use and cannot be deleted${NC}"
        echo ""
        echo -e "${CYAN}Active credentials holders:${NC}"
        echo "$credentials" | jq -r '.content | fromjson | "  - \(.holder_npub)"' 2>/dev/null | head -5
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${GREEN}✅ No active credentials found${NC}"
    echo ""
    echo -e "${RED}⚠️  WARNING: This will remove the permit definition from NOSTR${NC}"
    echo -e "${CYAN}Confirm deletion? (type DELETE to confirm):${NC} "
    read -r confirm
    
    if [[ "$confirm" == "DELETE" ]]; then
        # Publish deletion event (kind 5 - event deletion)
        # Note: Parameterized replaceable events can be "deleted" by publishing empty content
        # But we'll publish a deletion marker
        local deletion_content=$(echo '{"deleted": true, "reason": "Admin deletion", "deleted_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' | jq -c '.')
        local tags_json="[[\"d\",\"$permit_id\"]]"
        
        echo -e "${CYAN}📤 Publishing deletion marker...${NC}"
        # Publish to local strfry relay only - backfill_constellation.sh will sync to other nodes
        python3 "$NOSTR_SEND_NOTE" \
            --keyfile "$UPLANET_G1_KEYFILE" \
            --kind 30500 \
            --content "$deletion_content" \
            --tags "$tags_json" \
            --relays "ws://127.0.0.1:7777" > /dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Permit definition marked as deleted: $permit_id${NC}"
        else
            echo -e "${RED}❌ Failed to delete permit definition${NC}"
        fi
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

list_nostr_definitions() {
    show_nostr_list
    read -p "Press Enter to continue..."
}

list_template_definitions() {
    show_template_list
    read -p "Press Enter to continue..."
}

################################################################################
# Main script
################################################################################

main() {
    check_tools
    
    while true; do
        show_main_menu
        echo -e "${CYAN}Select an option:${NC} "
        read -r choice
        
        case "$choice" in
            1)
                add_permit
                ;;
            2)
                edit_permit_interactive
                ;;
            3)
                delete_permit
                ;;
            4)
                list_nostr_definitions
                ;;
            5)
                list_template_definitions
                ;;
            6)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

main
