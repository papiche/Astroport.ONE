#!/bin/bash
################################################################################
# Script: dashboard.DID.manager.sh
# Description: Interactive DID Manager for UPlanet Ecosystem
# 
# Manages all types of DID documents (kind 30800 events):
# - COOPERATIVE DIDs: UPLANETNAME wallets (CAPITAL, TREASURY, RnD, ASSETS, etc.)
# - UMAP DIDs: Geographic cells (0.01° x 0.01°) with environmental obligations
# - USER DIDs: MULTIPASS (usage tokens) and ZEN Card (ownership tokens)
#
# Uses Nostr as source of truth (kind 30800 - NIP-101)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# Source common tools
[[ -s "${HOME}/.zen/Astroport.ONE/tools/my.sh" ]] \
    && source "${HOME}/.zen/Astroport.ONE/tools/my.sh"

################################################################################
# Colors for output
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

################################################################################
# Configuration
################################################################################
NOSTR_GET_EVENTS="${MY_PATH}/nostr_get_events.sh"
NOSTR_GET_N1="${MY_PATH}/nostr_get_N1.sh"
DID_MANAGER="${MY_PATH}/did_manager_nostr.sh"
COOPERATIVE_CONFIG="${MY_PATH}/cooperative_config.sh"
G1CHECK="${MY_PATH}/G1check.sh"
DID_EVENT_KIND=30800  # NIP-101 DID events
TEMP_DIR="${HOME}/.zen/tmp/did_dashboard_$$"

# Cooperative wallet names - Complete infrastructure aligned with UPLANET.init.sh
# Reference: UPLANET.init.README.md - Infrastructure Complète Initialisée
declare -a COOP_WALLETS=(
    # Primary source wallet (Ğ1 Central Bank)
    "G1"                # uplanet.G1.dunikey - Source primale principale
    # Base cooperative wallets
    "UPLANET"           # uplanet.dunikey - Services locaux / MULTIPASS
    "SOCIETY"           # uplanet.SOCIETY.dunikey - Capital social / ZEN Card
    # Governance wallets (3x1/3 allocation)
    "TREASURY"          # uplanet.CASH.dunikey - Trésorerie (33.33%)
    "RND"               # uplanet.RnD.dunikey - R&D (33.33%)
    "ASSETS"            # uplanet.ASSETS.dunikey - Actifs (33.34%)
    # Fiscal and accounting wallets
    "IMPOT"             # uplanet.IMPOT.dunikey - Fiscalité (TVA + IS)
    "CAPITAL"           # uplanet.CAPITAL.dunikey - Immobilisations (Compte 21)
    "AMORTISSEMENT"     # uplanet.AMORTISSEMENT.dunikey - Amortissements (Compte 28)
    # Security wallet
    "INTRUSION"         # uplanet.INTRUSION.dunikey - Anti-intrusion funds
    # Operational wallet
    "CAPTAIN"           # uplanet.captain.dunikey - Captain coordinator
)

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}
${CYAN}║${NC}          ${YELLOW}dashboard.DID.manager.sh - UPlanet DID Manager${NC}                    ${CYAN}║${NC}
${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}

${YELLOW}DESCRIPTION:${NC}
    Interactive manager for all DID types in the UPlanet ecosystem:
    - COOPERATIVE DIDs: UPLANETNAME wallets (CAPITAL, TREASURY, RnD, ASSETS, etc.)
    - UMAP DIDs: Geographic cells with environmental obligations (ORE)
    - USER DIDs: MULTIPASS and ZEN Card identities

${YELLOW}USAGE:${NC}
    dashboard.DID.manager.sh [COMMAND] [OPTIONS]

${YELLOW}COMMANDS:${NC}
    menu              Launch interactive main menu (default)
    
    ${CYAN}=== COOPERATIVE DIDs ===${NC}
    coop-list         List all cooperative wallet DIDs
    coop-browse       Interactive browser for cooperative DIDs
    coop-check        Check cooperative wallet balances
    coop-init         Initialize ALL missing wallets and NOSTR keys
    coop-create       Create and publish cooperative DID to Nostr
    coop-sync         Sync cooperative DIDs from Nostr
    
    ${CYAN}=== UMAP DIDs ===${NC}
    umap-list         List all UMAP DIDs (geographic cells)
    umap-browse       Interactive browser for UMAP DIDs
    umap-check        Check UMAP metadata completeness
    umap-stats        Show UMAP statistics
    
    ${CYAN}=== USER DIDs ===${NC}
    user-list         List all user DIDs
    user-browse       Interactive browser for user DIDs
    user-check        Check user DID metadata
    user-update       Update user DID metadata interactively
    user-stats        Show user DID statistics
    
    ${CYAN}=== GENERAL ===${NC}
    list-all          List ALL DIDs from relay
    browse            Interactive browser for all DIDs
    stats             Show global statistics
    export            Export DIDs to JSON

${YELLOW}OPTIONS:${NC}
    -e, --email EMAIL         User's email address
    -x, --hex HEX             User's hex pubkey
    -l, --limit N             Limit number of results (default: 100)
    -v, --verbose             Verbose output
    -h, --help                Show this help message

${YELLOW}EXAMPLES:${NC}
    # Launch interactive menu
    dashboard.DID.manager.sh menu
    
    # List cooperative DIDs
    dashboard.DID.manager.sh coop-list
    
    # Initialize ALL missing cooperative wallets and NOSTR keys
    dashboard.DID.manager.sh coop-init
    
    # Create and publish cooperative DIDs to Nostr
    dashboard.DID.manager.sh coop-create
    
    # Browse UMAP DIDs
    dashboard.DID.manager.sh umap-browse
    
    # Check user DID
    dashboard.DID.manager.sh user-check --email user@example.com
    
    # Update user DID metadata
    dashboard.DID.manager.sh user-update --email user@example.com

${YELLOW}DID TYPES:${NC}
    ${GREEN}COOPERATIVE${NC}  - UPLANETNAME wallets for economic management
                   CAPITAL, TREASURY, RnD, ASSETS, AMORTISSEMENT, IMPOT, CAPTAIN
    
    ${GREEN}UMAP${NC}         - Geographic cells (0.01° x 0.01°)
                   Environmental obligations (ORE), PlantNet biodiversity
    
    ${GREEN}USER${NC}         - Individual identities
                   MULTIPASS (usage tokens), ZEN Card (ownership tokens)

EOF
    exit 0
}

################################################################################
# Helper functions
################################################################################
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    command -v jq &> /dev/null || missing+=("jq")
    command -v curl &> /dev/null || missing+=("curl")
    
    [[ ! -f "$NOSTR_GET_EVENTS" ]] && missing+=("nostr_get_events.sh")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Convert npub to hex
npub_to_hex() {
    local npub="$1"
    
    if command -v python3 &> /dev/null && [[ -f "${MY_PATH}/nostr2hex.py" ]]; then
        python3 "${MY_PATH}/nostr2hex.py" "$npub" 2>/dev/null && return 0
    fi
    
    echo "$npub"
}

# Find user's hex pubkey from email
find_hex_from_email() {
    local email="$1"
    local nostr_dir="${HOME}/.zen/game/nostr/${email}"
    
    if [[ -f "$nostr_dir/HEX" ]]; then
        cat "$nostr_dir/HEX"
        return 0
    fi
    
    if [[ -f "$nostr_dir/.secret.nostr" ]]; then
        grep -oP 'HEX=\K[a-f0-9]{64}' "$nostr_dir/.secret.nostr" 2>/dev/null && return 0
    fi
    
    return 1
}

# Find email from hex pubkey
find_email_from_hex() {
    local hex="$1"
    local found_file=$(grep -lr "^${hex}$" "${HOME}/.zen/game/nostr"/*@*/HEX 2>/dev/null | head -n1)
    
    if [[ -n "$found_file" ]]; then
        basename "$(dirname "$found_file")"
        return 0
    fi
    
    return 1
}

# Get wallet balance
get_wallet_balance() {
    local pubkey="$1"
    
    if [[ -f "$G1CHECK" ]]; then
        local balance=$("$G1CHECK" "$pubkey" 2>/dev/null | tr -d '[:space:]')
        if [[ "$balance" =~ ^\.([0-9]+)$ ]]; then
            balance="0${balance}"
        fi
        if [[ "$balance" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            echo "$balance"
            return 0
        fi
    fi
    
    echo "N/A"
}

# Classify DID type based on content
classify_did_type() {
    local content="$1"
    
    # Check for UMAP DID (geographic cell)
    local lat=$(echo "$content" | jq -r '.metadata.oreSystem.geographicCell.latitude // empty' 2>/dev/null)
    if [[ -n "$lat" ]]; then
        echo "UMAP"
        return 0
    fi
    
    # Check for cooperative DID
    local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // ""' 2>/dev/null)
    if [[ "$contract_status" =~ ^cooperative_ ]] || [[ "$contract_status" == "uplanet_wallet" ]]; then
        echo "COOPERATIVE"
        return 0
    fi
    
    # Check for UMAP based on DID id pattern
    local did_id=$(echo "$content" | jq -r '.id // ""' 2>/dev/null)
    if [[ "$did_id" =~ UMAP_ ]] || [[ "$did_id" =~ ^did:nostr:umap ]]; then
        echo "UMAP"
        return 0
    fi
    
    # Default to USER
    echo "USER"
}

################################################################################
# Interactive Main Menu
################################################################################
cmd_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                    ${YELLOW}🆔 UPlanet DID Manager${NC}                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  Manage Decentralized Identities for the UPlanet Ecosystem                ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Quick stats
        local total_dids=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit 1000 2>/dev/null | jq -s 'length' 2>/dev/null || echo "?")
        local local_users=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "*@*" 2>/dev/null | wc -l)
        local umap_count=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "UMAP*" 2>/dev/null | wc -l)
        
        echo -e "  ${CYAN}Quick Stats:${NC} ${GREEN}$total_dids${NC} DIDs on relay | ${GREEN}$local_users${NC} local users | ${GREEN}$umap_count${NC} UMAPs"
        echo ""
        
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${MAGENTA}🏛️  COOPERATIVE DIDs${NC}"
        echo -e "      ${YELLOW}1.${NC} 📋 List cooperative wallet DIDs"
        echo -e "      ${YELLOW}2.${NC} 🔍 Browse cooperative DIDs"
        echo -e "      ${YELLOW}3.${NC} 💰 Check cooperative wallet balances"
        echo -e "      ${YELLOW}c.${NC} ✨ Create/publish cooperative DIDs"
        echo ""
        echo -e "  ${MAGENTA}🗺️  UMAP DIDs (Geographic Cells)${NC}"
        echo -e "      ${YELLOW}4.${NC} 📋 List UMAP DIDs"
        echo -e "      ${YELLOW}5.${NC} 🔍 Browse UMAP DIDs"
        echo -e "      ${YELLOW}6.${NC} 📊 UMAP statistics"
        echo ""
        echo -e "  ${MAGENTA}👤 USER DIDs (MULTIPASS & ZEN Card)${NC}"
        echo -e "      ${YELLOW}7.${NC} 📋 List user DIDs"
        echo -e "      ${YELLOW}8.${NC} 🔍 Browse user DIDs"
        echo -e "      ${YELLOW}9.${NC} 📊 User statistics"
        echo -e "      ${YELLOW}u.${NC} 📝 Update user DID metadata"
        echo ""
        echo -e "  ${MAGENTA}📊 GLOBAL${NC}"
        echo -e "      ${YELLOW}a.${NC} 📋 List ALL DIDs"
        echo -e "      ${YELLOW}s.${NC} 📊 Global statistics"
        echo -e "      ${YELLOW}e.${NC} 💾 Export all DIDs"
        echo ""
        echo -e "      ${YELLOW}0.${NC} 🚪 Exit"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e ${CYAN}Select option:${NC} )" choice
        
        case "$choice" in
            1) cmd_coop_list ;;
            2) cmd_coop_browse ;;
            3) cmd_coop_check ;;
            c) cmd_coop_create ;;
            4) cmd_umap_list ;;
            5) cmd_umap_browse ;;
            6) cmd_umap_stats ;;
            7) cmd_user_list ;;
            8) cmd_user_browse ;;
            9) cmd_user_stats ;;
            u) cmd_user_update ;;
            a) cmd_list_all ;;
            s) cmd_stats ;;
            e) cmd_export_all ;;
            0) clear; exit 0 ;;
            *)
                log_error "Invalid option"
                sleep 1
                ;;
        esac
        
        echo ""
        read -p "Press ENTER to continue..."
    done
}

################################################################################
# COOPERATIVE DIDs
################################################################################
cmd_coop_list() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}🏛️  Cooperative Wallet DIDs${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get UPLANETNAME from environment or config
    local uplanetname="${UPLANETNAME:-}"
    if [[ -z "$uplanetname" ]] && [[ -f "${HOME}/.zen/game/uplanet.env" ]]; then
        source "${HOME}/.zen/game/uplanet.env" 2>/dev/null
        uplanetname="${UPLANETNAME:-}"
    fi
    
    if [[ -z "$uplanetname" ]]; then
        log_warning "UPLANETNAME not configured"
        echo ""
        echo -e "  ${YELLOW}Cooperative wallets require UPLANETNAME to be set.${NC}"
        echo -e "  ${YELLOW}Run UPLANET.init.sh to initialize the cooperative.${NC}"
        return 0
    fi
    
    echo -e "  ${CYAN}UPlanet:${NC} $uplanetname"
    echo ""
    
    # List cooperative wallets
    local count=0
    for wallet_type in "${COOP_WALLETS[@]}"; do
        local wallet_file="${HOME}/.zen/game/${uplanetname}_${wallet_type}.dunikey"
        local pubkey_file="${HOME}/.zen/game/${uplanetname}_${wallet_type}.pub"
        
        if [[ -f "$pubkey_file" ]]; then
            local pubkey=$(cat "$pubkey_file" 2>/dev/null)
            local balance=$(get_wallet_balance "$pubkey")
            
            count=$((count + 1))
            
            echo -e "  ${YELLOW}$count.${NC} 🏦 ${GREEN}${wallet_type}${NC}"
            echo -e "      G1PUB: ${pubkey:0:16}..."
            echo -e "      Balance: ${CYAN}${balance} Ğ1${NC}"
            echo ""
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_warning "No cooperative wallets found"
        echo ""
        echo -e "  ${YELLOW}Run UPLANET.init.sh to create cooperative wallets.${NC}"
    else
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}Total cooperative wallets: $count${NC}"
    fi
}

cmd_coop_browse() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${YELLOW}🏛️  Cooperative DID Browser${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get UPLANETNAME
    local uplanetname="${UPLANETNAME:-}"
    if [[ -z "$uplanetname" ]] && [[ -f "${HOME}/.zen/game/uplanet.env" ]]; then
        source "${HOME}/.zen/game/uplanet.env" 2>/dev/null
        uplanetname="${UPLANETNAME:-}"
    fi
    
    if [[ -z "$uplanetname" ]]; then
        log_warning "UPLANETNAME not configured"
        return 0
    fi
    
    # Build wallet list
    local -a wallet_names=()
    local -a wallet_pubkeys=()
    local -a wallet_balances=()
    
    for wallet_type in "${COOP_WALLETS[@]}"; do
        local pubkey_file="${HOME}/.zen/game/${uplanetname}_${wallet_type}.pub"
        
        if [[ -f "$pubkey_file" ]]; then
            local pubkey=$(cat "$pubkey_file" 2>/dev/null)
            local balance=$(get_wallet_balance "$pubkey")
            
            wallet_names+=("$wallet_type")
            wallet_pubkeys+=("$pubkey")
            wallet_balances+=("$balance")
        fi
    done
    
    if [[ ${#wallet_names[@]} -eq 0 ]]; then
        log_warning "No cooperative wallets found"
        return 0
    fi
    
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                 ${YELLOW}🏛️  Cooperative DID Browser${NC}                               ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}UPlanet:${NC} $uplanetname"
        echo ""
        
        local idx=1
        for i in "${!wallet_names[@]}"; do
            echo -e "  ${YELLOW}$idx.${NC} 🏦 ${GREEN}${wallet_names[$i]}${NC}"
            echo -e "      G1PUB: ${wallet_pubkeys[$i]:0:20}..."
            echo -e "      Balance: ${CYAN}${wallet_balances[$i]} Ğ1${NC}"
            echo ""
            idx=$((idx + 1))
        done
        
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${YELLOW}1-${#wallet_names[@]}.${NC} 🔍 View wallet details"
        echo -e "  ${YELLOW}r.${NC} 🔄 Refresh balances"
        echo -e "  ${YELLOW}b.${NC} 🔙 Back to menu"
        echo ""
        
        read -p "$(echo -e ${CYAN}Choose action:${NC} )" action
        
        case "$action" in
            r)
                log_info "Refreshing balances..."
                for i in "${!wallet_pubkeys[@]}"; do
                    wallet_balances[$i]=$(get_wallet_balance "${wallet_pubkeys[$i]}")
                done
                log_success "Balances refreshed"
                sleep 1
                ;;
            b)
                return 0
                ;;
            [1-9])
                local wallet_idx=$((action - 1))
                if [[ $wallet_idx -lt ${#wallet_names[@]} ]]; then
                    show_coop_wallet_details "${wallet_names[$wallet_idx]}" "${wallet_pubkeys[$wallet_idx]}" "${wallet_balances[$wallet_idx]}"
                else
                    log_error "Invalid wallet number"
                    sleep 1
                fi
                ;;
            *)
                log_error "Invalid action"
                sleep 1
                ;;
        esac
    done
}

show_coop_wallet_details() {
    local wallet_name="$1"
    local pubkey="$2"
    local balance="$3"
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}🏦 $wallet_name Wallet Details${NC}                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 Basic Information${NC}"
    echo -e "  Name: ${GREEN}$wallet_name${NC}"
    echo -e "  G1 Public Key: $pubkey"
    echo -e "  Balance: ${CYAN}$balance Ğ1${NC}"
    echo ""
    
    # Description based on wallet type
    echo -e "${YELLOW}📝 Description${NC}"
    case "$wallet_name" in
        CAPITAL)
            echo -e "  ${CYAN}Capital wallet for cooperative shares and investments.${NC}"
            echo -e "  Used for: Infrastructure funding, long-term investments"
            ;;
        TREASURY)
            echo -e "  ${CYAN}Treasury wallet for operational funds.${NC}"
            echo -e "  Used for: Day-to-day operations, service payments"
            ;;
        RND)
            echo -e "  ${CYAN}Research & Development wallet.${NC}"
            echo -e "  Used for: Oracle permits, innovation funding"
            ;;
        ASSETS)
            echo -e "  ${CYAN}Assets wallet for environmental obligations.${NC}"
            echo -e "  Used for: ORE rewards, environmental protection"
            ;;
        AMORTISSEMENT)
            echo -e "  ${CYAN}Amortization wallet for depreciation.${NC}"
            echo -e "  Used for: Equipment depreciation, asset management"
            ;;
        IMPOT)
            echo -e "  ${CYAN}Tax wallet for fiscal obligations.${NC}"
            echo -e "  Used for: Tax reserves, fiscal compliance"
            ;;
        CAPTAIN)
            echo -e "  ${CYAN}Captain wallet for node operator.${NC}"
            echo -e "  Used for: Node operations, captain rewards"
            ;;
    esac
    echo ""
    
    # Check for DID on Nostr
    echo -e "${YELLOW}🔍 Nostr DID Status${NC}"
    local did_event=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit 100 2>/dev/null | jq -r "select(.content | contains(\"$pubkey\"))" 2>/dev/null | head -1)
    
    if [[ -n "$did_event" ]]; then
        echo -e "  Status: ${GREEN}Published on Nostr${NC}"
        local event_id=$(echo "$did_event" | jq -r '.id // empty')
        echo -e "  Event ID: ${event_id:0:16}..."
    else
        echo -e "  Status: ${YELLOW}Not published on Nostr${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    read -p "Press ENTER to go back..."
}

cmd_coop_check() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${YELLOW}💰 Cooperative Wallet Balances${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get UPLANETNAME
    local uplanetname="${UPLANETNAME:-}"
    if [[ -z "$uplanetname" ]] && [[ -f "${HOME}/.zen/game/uplanet.env" ]]; then
        source "${HOME}/.zen/game/uplanet.env" 2>/dev/null
        uplanetname="${UPLANETNAME:-}"
    fi
    
    if [[ -z "$uplanetname" ]]; then
        log_warning "UPLANETNAME not configured"
        return 0
    fi
    
    echo -e "  ${CYAN}UPlanet:${NC} $uplanetname"
    echo ""
    
    local total_balance=0
    
    printf "  ${YELLOW}%-15s %-45s %15s${NC}\n" "WALLET" "G1 PUBLIC KEY" "BALANCE"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────${NC}"
    
    for wallet_type in "${COOP_WALLETS[@]}"; do
        local pubkey_file="${HOME}/.zen/game/${uplanetname}_${wallet_type}.pub"
        
        if [[ -f "$pubkey_file" ]]; then
            local pubkey=$(cat "$pubkey_file" 2>/dev/null)
            local balance=$(get_wallet_balance "$pubkey")
            
            printf "  %-15s %-45s %15s\n" "$wallet_type" "$pubkey" "${balance} Ğ1"
            
            if [[ "$balance" != "N/A" ]]; then
                total_balance=$(echo "$total_balance + $balance" | bc -l 2>/dev/null || echo "$total_balance")
            fi
        fi
    done
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────${NC}"
    printf "  ${GREEN}%-15s %-45s %15s${NC}\n" "TOTAL" "" "${total_balance} Ğ1"
    echo ""
}

################################################################################
# Create and Publish Cooperative DIDs
################################################################################
cmd_coop_create() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}🏛️  Create & Publish Cooperative DIDs${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get UPlanet name from my.sh (computed from swarm.key)
    local uplanetname=""
    if [[ -f "${MY_PATH}/my.sh" ]]; then
        # Source my.sh to get UPLANETNAME (computed from swarm.key or "EnfinLibre")
        source "${MY_PATH}/my.sh" 2>/dev/null
        uplanetname="$UPLANETNAME"
    fi
    
    if [[ -z "$uplanetname" ]]; then
        log_error "No UPLANETNAME found. Please initialize UPlanet first."
        log_info "UPLANETNAME is computed from ~/.zen/ipfs/swarm.key"
        return 1
    fi
    
    echo -e "  ${CYAN}UPlanet:${NC} $uplanetname"
    echo ""
    
    # Check for .env configuration (source of truth: $HOME/.zen/Astroport.ONE/.env)
    local env_file="${HOME}/.zen/Astroport.ONE/.env"
    if [[ -f "$env_file" ]]; then
        echo -e "  ${GREEN}✅ Configuration:${NC} $env_file"
    else
        log_warning "No .env config found at: $env_file"
    fi
    
    # Check for cooperative DID from UPLANET.init.sh (NOSTR DID source of truth)
    local coop_nostr_key="${HOME}/.zen/game/uplanet.G1.nostr"
    if [[ -f "$coop_nostr_key" ]]; then
        local coop_npub=$(grep -oP 'NPUB=\K[^;]+' "$coop_nostr_key" 2>/dev/null | head -1)
        echo -e "  ${GREEN}✅ Cooperative DID:${NC} ${coop_npub:0:20}..."
    else
        log_warning "No cooperative NOSTR key found (run UPLANET.init.sh first)"
    fi
    echo ""
    
    # Display wallet status and count missing items
    echo -e "${YELLOW}Cooperative Wallets Status:${NC}"
    echo ""
    
    local idx=1
    local missing_wallets=0
    local missing_nostr=0
    
    for wallet_type in "${COOP_WALLETS[@]}"; do
        local dunikey_file=$(get_coop_dunikey_path "$wallet_type")
        local status="❌ Missing"
        local nostr_status=""
        
        if [[ -f "$dunikey_file" ]]; then
            local pubkey=$(get_coop_g1pub "$wallet_type")
            status="✅ ${pubkey:0:12}..."
            
            # Check if Nostr keys exist (stored in ~/.zen/game/*.nostr)
            local nostr_file=$(get_coop_nostr_path "$wallet_type")
            if [[ -f "$nostr_file" ]]; then
                nostr_status=" 📡"
            else
                nostr_status=" ⚠️"
                ((missing_nostr++))
            fi
        else
            ((missing_wallets++))
        fi
        
        printf "  \033[1;33m%2d.\033[0m \033[0;32m%-13s\033[0m %s%s\n" "$idx" "$wallet_type" "$status" "$nostr_status"
        idx=$((idx + 1))
    done
    
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    
    # Show summary if there are missing items
    if [[ $missing_wallets -gt 0 ]] || [[ $missing_nostr -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠️  Missing: ${missing_wallets} wallets, ${missing_nostr} NOSTR keys${NC}"
        echo ""
    fi
    
    echo -e "  ${YELLOW}i.${NC} 🏗️  Initialize ALL missing (wallets + NOSTR keys)"
    echo -e "  ${YELLOW}a.${NC} 📦 Create & publish ALL cooperative DIDs"
    echo -e "  ${YELLOW}b.${NC} 🔙 Back"
    echo ""
    
    read -p "$(echo -e ${CYAN}Choose action [1-${#COOP_WALLETS[@]}, i, a, b]:${NC} )" action
    
    case "$action" in
        i)
            init_all_coop_infrastructure "$uplanetname"
            ;;
        a)
            create_all_coop_dids "$uplanetname"
            ;;
        b)
            return 0
            ;;
        [0-9]|[0-9][0-9])
            local wallet_idx=$((action - 1))
            if [[ $wallet_idx -ge 0 ]] && [[ $wallet_idx -lt ${#COOP_WALLETS[@]} ]]; then
                create_coop_did "$uplanetname" "${COOP_WALLETS[$wallet_idx]}"
            else
                log_error "Invalid wallet number (1-${#COOP_WALLETS[@]})"
            fi
            ;;
        *)
            log_error "Invalid action"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Get dunikey file path for a wallet type
# Reference: UPLANET.init.sh and my.sh naming convention
get_coop_dunikey_path() {
    local wallet_type="$1"
    
    case "$wallet_type" in
        # Primary source wallet
        G1)           echo "${HOME}/.zen/game/uplanet.G1.dunikey" ;;
        # Base cooperative wallets
        UPLANET)      echo "${HOME}/.zen/game/uplanet.dunikey" ;;
        SOCIETY)      echo "${HOME}/.zen/game/uplanet.SOCIETY.dunikey" ;;
        # Governance wallets (3x1/3)
        TREASURY)     echo "${HOME}/.zen/game/uplanet.CASH.dunikey" ;;  # TREASURY uses CASH file
        RND)          echo "${HOME}/.zen/game/uplanet.RnD.dunikey" ;;
        ASSETS)       echo "${HOME}/.zen/game/uplanet.ASSETS.dunikey" ;;
        # Fiscal and accounting
        IMPOT)        echo "${HOME}/.zen/game/uplanet.IMPOT.dunikey" ;;
        CAPITAL)      echo "${HOME}/.zen/game/uplanet.CAPITAL.dunikey" ;;
        AMORTISSEMENT) echo "${HOME}/.zen/game/uplanet.AMORTISSEMENT.dunikey" ;;
        # Security and operational
        INTRUSION)    echo "${HOME}/.zen/game/uplanet.INTRUSION.dunikey" ;;
        CAPTAIN)      echo "${HOME}/.zen/game/uplanet.captain.dunikey" ;;
        *)            echo "${HOME}/.zen/game/uplanet.${wallet_type}.dunikey" ;;
    esac
}

# Get NOSTR key file path for a wallet type
# G1: ~/.zen/game/uplanet.G1.nostr (root key)
# Others: ~/.zen/game/nostr/COOP_<TYPE>/.secret.nostr (dir with .secret.nostr + HEX for NIP-101 backfill)
get_coop_nostr_path() {
    local wallet_type="$1"
    
    case "$wallet_type" in
        G1)           echo "${HOME}/.zen/game/uplanet.G1.nostr" ;;
        UPLANET)      echo "${HOME}/.zen/game/nostr/COOP_UPLANET/.secret.nostr" ;;
        SOCIETY)      echo "${HOME}/.zen/game/nostr/COOP_SOCIETY/.secret.nostr" ;;
        TREASURY)     echo "${HOME}/.zen/game/nostr/COOP_TREASURY/.secret.nostr" ;;
        RND)          echo "${HOME}/.zen/game/nostr/COOP_RND/.secret.nostr" ;;
        ASSETS)       echo "${HOME}/.zen/game/nostr/COOP_ASSETS/.secret.nostr" ;;
        IMPOT)        echo "${HOME}/.zen/game/nostr/COOP_IMPOT/.secret.nostr" ;;
        CAPITAL)      echo "${HOME}/.zen/game/nostr/COOP_CAPITAL/.secret.nostr" ;;
        AMORTISSEMENT) echo "${HOME}/.zen/game/nostr/COOP_AMORTISSEMENT/.secret.nostr" ;;
        INTRUSION)    echo "${HOME}/.zen/game/nostr/COOP_INTRUSION/.secret.nostr" ;;
        CAPTAIN)      echo "${HOME}/.zen/game/nostr/COOP_CAPTAIN/.secret.nostr" ;;
        *)            echo "${HOME}/.zen/game/nostr/COOP_${wallet_type}/.secret.nostr" ;;
    esac
}

# Get keygen seed for a wallet type (matches UPLANET.init.sh convention)
get_coop_keygen_seed() {
    local wallet_type="$1"
    local uplanetname="$2"
    
    case "$wallet_type" in
        G1)           echo "${uplanetname}" ;;
        UPLANET)      echo "${uplanetname}" ;;
        SOCIETY)      echo "${uplanetname}.SOCIETY" ;;
        TREASURY)     echo "${uplanetname}.CASH" ;;
        RND)          echo "${uplanetname}.RnD" ;;
        ASSETS)       echo "${uplanetname}.ASSETS" ;;
        IMPOT)        echo "${uplanetname}.IMPOT" ;;
        CAPITAL)      echo "${uplanetname}.CAPITAL" ;;
        AMORTISSEMENT) echo "${uplanetname}.AMORTISSEMENT" ;;
        INTRUSION)    echo "${uplanetname}.INTRUSION" ;;
        CAPTAIN)      echo "${uplanetname}.captain" ;;
        *)            echo "${uplanetname}.${wallet_type}" ;;
    esac
}

# Get cache variable name for a wallet type
get_coop_cache_var() {
    local wallet_type="$1"
    
    case "$wallet_type" in
        G1)           echo "UPLANETNAME_G1" ;;
        UPLANET)      echo "UPLANETG1PUB" ;;
        SOCIETY)      echo "UPLANETNAME_SOCIETY" ;;
        TREASURY)     echo "UPLANETNAME_TREASURY" ;;
        RND)          echo "UPLANETNAME_RND" ;;
        ASSETS)       echo "UPLANETNAME_ASSETS" ;;
        IMPOT)        echo "UPLANETNAME_IMPOT" ;;
        CAPITAL)      echo "UPLANETNAME_CAPITAL" ;;
        AMORTISSEMENT) echo "UPLANETNAME_AMORTISSEMENT" ;;
        INTRUSION)    echo "UPLANETNAME_INTRUSION" ;;
        CAPTAIN)      echo "UPLANETNAME_CAPTAIN" ;;
        *)            echo "UPLANETNAME_${wallet_type}" ;;
    esac
}

# Get keygen seed for a wallet type (aligned with UPLANET.init.sh)
get_coop_keygen_seed() {
    local wallet_type="$1"
    local uplanetname="$2"
    
    case "$wallet_type" in
        G1)           echo "${uplanetname}.G1" ;;
        UPLANET)      echo "${uplanetname}" ;;
        SOCIETY)      echo "${uplanetname}.SOCIETY" ;;
        TREASURY)     echo "${uplanetname}.TREASURY" ;;
        RND)          echo "${uplanetname}.RND" ;;
        ASSETS)       echo "${uplanetname}.ASSETS" ;;
        IMPOT)        echo "${uplanetname}.IMPOT" ;;
        CAPITAL)      echo "${uplanetname}.CAPITAL" ;;
        AMORTISSEMENT) echo "${uplanetname}.AMORTISSEMENT" ;;
        INTRUSION)    echo "${uplanetname}.INTRUSION" ;;
        CAPTAIN)      echo "${uplanetname}.${CAPTAINEMAIL:-CAPTAIN}" ;;
        *)            echo "${uplanetname}.${wallet_type}" ;;
    esac
}

# Get G1 public key for a wallet type (from cache or dunikey)
get_coop_g1pub() {
    local wallet_type="$1"
    local cache_var=$(get_coop_cache_var "$wallet_type")
    
    # Try cache file first
    local cache_file="${HOME}/.zen/tmp/${cache_var}"
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file" 2>/dev/null
        return 0
    fi
    
    # Fall back to extracting from dunikey
    local dunikey=$(get_coop_dunikey_path "$wallet_type")
    if [[ -f "$dunikey" ]]; then
        grep "pub:" "$dunikey" 2>/dev/null | cut -d' ' -f2
        return 0
    fi
    
    return 1
}

################################################################################
# Infrastructure Creation Functions (aligned with UPLANET.init.sh)
################################################################################

# Create a cooperative dunikey wallet
create_coop_dunikey() {
    local wallet_type="$1"
    local uplanetname="$2"
    
    local dunikey_file=$(get_coop_dunikey_path "$wallet_type")
    
    if [[ -f "$dunikey_file" ]]; then
        log_info "Wallet $wallet_type already exists"
        return 0
    fi
    
    local seed=$(get_coop_keygen_seed "$wallet_type" "$uplanetname")
    
    log_info "Creating wallet $wallet_type with seed: $seed"
    
    # Create directory if needed
    local wallet_dir=$(dirname "$dunikey_file")
    [[ ! -d "$wallet_dir" ]] && mkdir -p "$wallet_dir"
    
    # Use keygen to create dunikey (same as UPLANET.init.sh)
    if [[ -x "${MY_PATH}/keygen" ]]; then
        "${MY_PATH}/keygen" -t duniter -o "$dunikey_file" "$seed" "$seed" 2>/dev/null
        
        if [[ -f "$dunikey_file" ]]; then
            chmod 600 "$dunikey_file"
            
            local pubkey=$(grep "pub:" "$dunikey_file" 2>/dev/null | cut -d' ' -f2)
            log_success "Wallet created: $wallet_type"
            log_info "G1 Public Key: ${pubkey:0:20}..."
            
            # Update cache
            local cache_var=$(get_coop_cache_var "$wallet_type")
            mkdir -p "${HOME}/.zen/tmp"
            echo "$pubkey" > "${HOME}/.zen/tmp/${cache_var}"
            
            return 0
        else
            log_error "Failed to create wallet $wallet_type"
            return 1
        fi
    else
        log_error "keygen tool not found at ${MY_PATH}/keygen"
        return 1
    fi
}

# Create cooperative NOSTR root key (uplanet.G1.nostr)
# Format: NSEC=...; NPUB=...; HEX=... (same as myswarm_secret.nostr for NIP-101 backfill)
create_coop_nostr_root_key() {
    local uplanetname="$1"
    
    local nostr_key_file="${HOME}/.zen/game/uplanet.G1.nostr"
    
    if [[ -f "$nostr_key_file" ]] && grep -q 'HEX=' "$nostr_key_file" 2>/dev/null; then
        log_info "Cooperative NOSTR root key already exists"
        return 0
    fi
    
    log_info "Creating cooperative NOSTR root key (uplanet.G1.nostr)..."
    
    if [[ -x "${MY_PATH}/keygen" ]] && [[ -x "${MY_PATH}/nostr2hex.py" ]]; then
        local keygen_out=$("${MY_PATH}/keygen" -t nostr "${uplanetname}.G1" "${uplanetname}.G1" 2>/dev/null)
        local npub=$(echo "$keygen_out" | grep -oE 'npub1[a-zA-Z0-9]{58}' | head -1)
        local nsec=$(echo "$keygen_out" | grep -oE 'nsec1[a-zA-Z0-9]{58}' | head -1)
        [[ -z "$nsec" ]] && nsec=$("${MY_PATH}/keygen" -t nostr "${uplanetname}.G1" "${uplanetname}.G1" -s 2>/dev/null | grep -oE 'nsec1[a-zA-Z0-9]{58}' | head -1)
        local hex=""
        [[ -n "$npub" ]] && hex=$("${MY_PATH}/nostr2hex.py" "$npub" 2>/dev/null)
        if [[ -n "$npub" ]] && [[ -n "$nsec" ]] && [[ -n "$hex" ]]; then
            echo "NSEC=$nsec; NPUB=$npub; HEX=$hex" > "$nostr_key_file"
            chmod 600 "$nostr_key_file"
            log_success "Cooperative NOSTR root key created"
            log_info "NPUB: ${npub:0:20}..."
            return 0
        fi
    fi
    log_error "Failed to create cooperative NOSTR root key (keygen or nostr2hex.py)"
    rm -f "$nostr_key_file"
    return 1
}

# Initialize all missing cooperative infrastructure
init_all_coop_infrastructure() {
    local uplanetname="$1"
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       ${YELLOW}🏗️  Initialize Cooperative Infrastructure${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}       ${BLUE}Aligned with UPLANET.init.sh${NC}                                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "  ${CYAN}UPlanet:${NC} $uplanetname"
    echo ""
    
    local wallets_created=0
    local wallets_existed=0
    local wallets_failed=0
    
    # Step 1: Create cooperative NOSTR root key
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}Step 1: Cooperative NOSTR Root Key${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if create_coop_nostr_root_key "$uplanetname"; then
        ((wallets_created++))
    fi
    echo ""
    
    # Step 2: Create all cooperative wallets
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}Step 2: Cooperative Wallets (dunikey)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    for wallet_type in "${COOP_WALLETS[@]}"; do
        local dunikey_file=$(get_coop_dunikey_path "$wallet_type")
        
        if [[ -f "$dunikey_file" ]]; then
            local pubkey=$(get_coop_g1pub "$wallet_type")
            echo -e "  ${GREEN}✅ $wallet_type${NC} - exists (${pubkey:0:12}...)"
            ((wallets_existed++))
        else
            if create_coop_dunikey "$wallet_type" "$uplanetname"; then
                ((wallets_created++))
            else
                ((wallets_failed++))
            fi
        fi
    done
    echo ""
    
    # Step 3: Create NOSTR keys for each wallet (for DID publication)
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}Step 3: NOSTR Keys for DIDs${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local nostr_created=0
    local nostr_existed=0
    
    for wallet_type in "${COOP_WALLETS[@]}"; do
        # NOSTR keys stored in ~/.zen/game/*.nostr (same location as dunikey files)
        local nostr_file=$(get_coop_nostr_path "$wallet_type")
        local seed=$(get_coop_keygen_seed "$wallet_type" "$uplanetname")
        
        if [[ -f "$nostr_file" ]] && grep -q "NSEC=" "$nostr_file" 2>/dev/null; then
            local npub=$(grep -oP 'NPUB=\K[^;]+' "$nostr_file" 2>/dev/null | head -1)
            echo -e "  ${GREEN}✅ ${wallet_type}${NC} - $(basename "$nostr_file") (${npub:0:16}...)"
            ((nostr_existed++))
        else
            # Create NOSTR key using keygen with -k flag and format as NSEC=...; NPUB=...; HEX=...;
            if [[ -x "${MY_PATH}/keygen" ]]; then
                local keygen_output=$("${MY_PATH}/keygen" -t nostr -k "$seed" "$seed" 2>/dev/null)
                local npub=$(echo "$keygen_output" | grep -E '^npub1' | head -1)
                local nsec=$(echo "$keygen_output" | grep -E '^nsec1' | head -1)
                
                if [[ -n "$npub" ]] && [[ -n "$nsec" ]]; then
                    # Get HEX from npub using nostr_nsec2npub2hex.py or manual conversion
                    local hex=""
                    if [[ -f "${MY_PATH}/nostr_nsec2npub2hex.py" ]]; then
                        hex=$(python3 "${MY_PATH}/nostr_nsec2npub2hex.py" "$nsec" 2>/dev/null)
                    fi
                    
                    # Write formatted output
                    echo "NSEC=${nsec}; NPUB=${npub}; HEX=${hex};" > "$nostr_file"
                    chmod 600 "$nostr_file"
                    
                    echo -e "  ${BLUE}📡 ${wallet_type}${NC} - $(basename "$nostr_file") created (${npub:0:16}...)"
                    ((nostr_created++))
                else
                    echo -e "  ${RED}❌ ${wallet_type}${NC} - Failed to create NOSTR key"
                    rm -f "$nostr_file"
                fi
            else
                echo -e "  ${RED}❌ keygen tool not found${NC}"
                break
            fi
        fi
    done
    echo ""
    
    # Summary
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                          ${YELLOW}📊 Summary${NC}                                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BLUE}Wallets:${NC}"
    echo -e "    Created: ${GREEN}$wallets_created${NC}"
    echo -e "    Existed: ${CYAN}$wallets_existed${NC}"
    echo -e "    Failed:  ${RED}$wallets_failed${NC}"
    echo ""
    echo -e "  ${BLUE}NOSTR Keys:${NC}"
    echo -e "    Created: ${GREEN}$nostr_created${NC}"
    echo -e "    Existed: ${CYAN}$nostr_existed${NC}"
    echo ""
    
    if [[ $wallets_failed -eq 0 ]]; then
        echo -e "${GREEN}✅ Infrastructure initialization complete!${NC}"
        echo -e "${BLUE}   All wallets and NOSTR keys are ready for DID publication.${NC}"
    else
        echo -e "${YELLOW}⚠️  Some wallets could not be created.${NC}"
        echo -e "${BLUE}   Check if keygen tool is available.${NC}"
    fi
    echo ""
    
    read -p "Press Enter to continue..."
}

# Command: Initialize cooperative infrastructure
cmd_coop_init() {
    # Get UPlanet name from my.sh
    local uplanetname=""
    if [[ -f "${MY_PATH}/my.sh" ]]; then
        source "${MY_PATH}/my.sh" 2>/dev/null
        uplanetname="$UPLANETNAME"
    fi
    
    if [[ -z "$uplanetname" ]]; then
        log_error "No UPLANETNAME found. Please initialize UPlanet first."
        return 1
    fi
    
    init_all_coop_infrastructure "$uplanetname"
}

# Create DID for a single cooperative wallet
create_coop_did() {
    local uplanetname="$1"
    local wallet_type="$2"
    
    log_info "Creating DID for ${wallet_type} wallet..."
    
    # Get correct file paths using my.sh naming convention
    local secret_file=$(get_coop_dunikey_path "$wallet_type")
    local g1pub=$(get_coop_g1pub "$wallet_type")
    
    if [[ ! -f "$secret_file" ]]; then
        log_error "Wallet $wallet_type not configured (missing $secret_file)"
        log_info "Available dunikey files:"
        ls -1 "${HOME}/.zen/game/uplanet."*.dunikey 2>/dev/null | sed 's/.*\//  /'
        return 1
    fi
    
    if [[ -z "$g1pub" ]]; then
        log_error "Cannot get G1 public key for $wallet_type"
        return 1
    fi
    
    log_info "G1 Public Key: ${g1pub:0:20}..."
    
    # Check if we have Nostr keys for this wallet (stored in ~/.zen/game/*.nostr)
    local nostr_file=$(get_coop_nostr_path "$wallet_type")
    local seed=$(get_coop_keygen_seed "$wallet_type" "$uplanetname")
    
    if [[ ! -f "$nostr_file" ]] || ! grep -q "NSEC=" "$nostr_file" 2>/dev/null; then
        log_warning "No Nostr keys found for $wallet_type"
        log_info "Generating Nostr keys to $(dirname "$nostr_file")/..."
        
        local coop_nostr_dir=$(dirname "$nostr_file")
        mkdir -p "$coop_nostr_dir"
        
        if [[ -x "${MY_PATH}/keygen" ]]; then
            local keygen_output=$("${MY_PATH}/keygen" -t nostr -k "$seed" "$seed" 2>/dev/null)
            local gen_npub=$(echo "$keygen_output" | grep -oE 'npub1[a-zA-Z0-9]{58}' | head -1)
            local gen_nsec=$(echo "$keygen_output" | grep -oE 'nsec1[a-zA-Z0-9]{58}' | head -1)
            local gen_hex=""
            if [[ -n "$gen_npub" ]] && [[ -x "${MY_PATH}/nostr2hex.py" ]]; then
                gen_hex=$("${MY_PATH}/nostr2hex.py" "$gen_npub" 2>/dev/null)
            fi
            if [[ -z "$gen_hex" ]] && [[ -f "${MY_PATH}/nostr_nsec2npub2hex.py" ]] && [[ -n "$gen_nsec" ]]; then
                gen_hex=$(python3 "${MY_PATH}/nostr_nsec2npub2hex.py" "$gen_nsec" 2>/dev/null | tail -1)
            fi
            
            if [[ -n "$gen_npub" ]] && [[ -n "$gen_nsec" ]] && [[ -n "$gen_hex" ]]; then
                echo "NSEC=${gen_nsec}; NPUB=${gen_npub}; HEX=${gen_hex};" > "$nostr_file"
                chmod 600 "$nostr_file"
                echo "$gen_hex" > "${coop_nostr_dir}/HEX"
                chmod 600 "${coop_nostr_dir}/HEX"
                log_success "Nostr keys generated: ${coop_nostr_dir}/ (.secret.nostr + HEX for NIP-101 backfill)"
            else
                log_error "Failed to generate Nostr keys"
                rm -f "$nostr_file" "${coop_nostr_dir}/HEX"
                return 1
            fi
        else
            log_error "keygen tool not found at ${MY_PATH}/keygen"
            return 1
        fi
    fi
    
    # Extract nsec from Nostr keys
    local nsec=$(grep -oP 'NSEC=\K[^;]+' "$nostr_file" 2>/dev/null | head -1)
    local npub=$(grep -oP 'NPUB=\K[^;]+' "$nostr_file" 2>/dev/null | head -1)
    local hex=$(grep -oP 'HEX=\K[^;]+' "$nostr_file" 2>/dev/null | head -1)
    
    if [[ -z "$nsec" ]]; then
        log_error "Could not extract nsec from Nostr keys"
        return 1
    fi
    
    # Get hex pubkey
    if [[ -z "$hex" ]]; then
        if [[ -x "${MY_PATH}/nostr2hex.py" ]]; then
            hex=$("${MY_PATH}/nostr2hex.py" "$npub" 2>/dev/null)
        fi
    fi
    
    # Ensure HEX file exists in same dir for NIP-101 backfill_constellation.sh
    local coop_nostr_dir=$(dirname "$nostr_file")
    if [[ -n "$hex" ]] && [[ -d "$coop_nostr_dir" ]] && [[ ! -f "${coop_nostr_dir}/HEX" ]]; then
        echo "$hex" > "${coop_nostr_dir}/HEX"
        chmod 600 "${coop_nostr_dir}/HEX"
    fi
    
    # Create DID document in same dir as .secret.nostr (e.g. COOP_RND/did.json)
    local did_file="${coop_nostr_dir}/did.json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Get cooperative root DID from UPLANET.init.sh (source of truth)
    local coop_root_nostr="${HOME}/.zen/game/uplanet.G1.nostr"
    local coop_root_hex=""
    local coop_root_npub=""
    if [[ -f "$coop_root_nostr" ]]; then
        coop_root_hex=$(grep -oP 'HEX=\K[^;]+' "$coop_root_nostr" 2>/dev/null | head -1)
        coop_root_npub=$(grep -oP 'NPUB=\K[^;]+' "$coop_root_nostr" 2>/dev/null | head -1)
    fi
    
    # Get IPFS gateway from .env
    local ipfs_gw="https://ipfs.copylaradio.com"
    local env_file="${HOME}/.zen/Astroport.ONE/.env"
    if [[ -f "$env_file" ]]; then
        local env_ipfs=$(grep -oP 'myIPFS=\K[^\s]+' "$env_file" 2>/dev/null | head -1)
        [[ -n "$env_ipfs" ]] && ipfs_gw="$env_ipfs"
    fi
    
    cat > "$did_file" << EOF
{
  "@context": [
    "https://www.w3.org/ns/did/v1",
    "https://w3id.org/security/v1",
    "https://u.copylaradio.com/ns/v1"
  ],
  "id": "did:nostr:${hex}",
  "alsoKnownAs": [
    "did:g1:${g1pub}",
    "nostr:${npub}"
  ],
  "controller": "did:nostr:${coop_root_hex:-${hex}}",
  "verificationMethod": [
    {
      "id": "did:nostr:${hex}#nostr-key",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:nostr:${hex}",
      "publicKeyMultibase": "z${npub}"
    }
  ],
  "authentication": ["did:nostr:${hex}#nostr-key"],
  "assertionMethod": ["did:nostr:${hex}#nostr-key"],
  "service": [
    {
      "id": "did:nostr:${hex}#cooperative-wallet",
      "type": "CooperativeWallet",
      "serviceEndpoint": {
        "g1pub": "${g1pub}",
        "walletType": "${wallet_type}",
        "cooperative": "${uplanetname}",
        "cesiumLink": "https://cesium.app/#/app/wot/${g1pub}/"
      }
    },
    {
      "id": "did:nostr:${hex}#ipfs-gateway",
      "type": "IPFSGateway",
      "serviceEndpoint": "${ipfs_gw}"
    }
  ],
  "metadata": {
    "created": "${timestamp}",
    "updated": "${timestamp}",
    "type": "CooperativeDID",
    "walletType": "${wallet_type}",
    "cooperative": "${uplanetname}",
    "description": "$(get_wallet_description $wallet_type)",
    "contractStatus": "cooperative_wallet_active",
    "rootDID": "did:nostr:${coop_root_hex:-${hex}}",
    "configSource": "${env_file}"
  }
}
EOF
    
    log_success "DID document created: $did_file"
    
    # Publish to Nostr
    log_info "Publishing DID to Nostr relays..."
    
    if [[ -f "${MY_PATH}/nostr_publish_did.py" ]]; then
        local relays="ws://127.0.0.1:7777 wss://relay.copylaradio.com"
        
        python3 "${MY_PATH}/nostr_publish_did.py" "$nsec" "$did_file" $relays 2>&1
        
        if [[ $? -eq 0 ]]; then
            log_success "DID published to Nostr for $wallet_type"
            
            # Save to local cache
            cp "$did_file" "${did_file}.cache"
        else
            log_error "Failed to publish DID to Nostr"
            return 1
        fi
    else
        log_warning "nostr_publish_did.py not found - DID saved locally only"
    fi
    
    return 0
}

# Get wallet description (aligned with UPLANET.init.README.md)
get_wallet_description() {
    local wallet_type="$1"
    
    case "$wallet_type" in
        # Primary source wallet
        G1)
            echo "Primary source wallet - Ğ1 Central Bank reserve (Source primale)"
            ;;
        # Base cooperative wallets
        UPLANET)
            echo "Local services wallet - MULTIPASS revenue management"
            ;;
        SOCIETY)
            echo "Social capital wallet - ZEN Card shares issuance (Capital social)"
            ;;
        # Governance wallets (3x1/3)
        TREASURY)
            echo "Treasury wallet - Daily operations (Trésorerie 33.33%)"
            ;;
        RND|RnD)
            echo "R&D wallet - Research and Development (33.33% allocation)"
            ;;
        ASSETS)
            echo "Assets wallet - Infrastructure funding (Actifs 33.34%)"
            ;;
        # Fiscal and accounting
        IMPOT)
            echo "Tax wallet - TVA + IS fiscal obligations (Fiscalité)"
            ;;
        CAPITAL)
            echo "Capital wallet - Fixed assets value (Compte 21 - Valeur Brute)"
            ;;
        AMORTISSEMENT)
            echo "Depreciation wallet - VNC tracking (Compte 28)"
            ;;
        # Security and operational
        INTRUSION)
            echo "Intrusion wallet - Anti-intrusion funds (Unauthorized funds)"
            ;;
        CAPTAIN)
            echo "Captain wallet - Coordinator remuneration"
            ;;
        *)
            echo "Cooperative wallet"
            ;;
    esac
}

# Create all cooperative DIDs
create_all_coop_dids() {
    local uplanetname="$1"
    local success=0
    local failed=0
    
    log_info "Creating DIDs for all cooperative wallets..."
    echo ""
    
    for wallet_type in "${COOP_WALLETS[@]}"; do
        local dunikey_file=$(get_coop_dunikey_path "$wallet_type")
        
        if [[ -f "$dunikey_file" ]]; then
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            if create_coop_did "$uplanetname" "$wallet_type"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
            fi
            echo ""
        else
            log_warning "Skipping $wallet_type (not configured at $dunikey_file)"
        fi
    done
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_success "Summary: $success created, $failed failed"
}

################################################################################
# UMAP DIDs
################################################################################
cmd_umap_list() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}🗺️  UMAP DIDs (Geographic Cells)${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Find local UMAP directories
    local umap_dirs=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "UMAP*" 2>/dev/null)
    
    if [[ -z "$umap_dirs" ]]; then
        log_warning "No local UMAP directories found"
        echo ""
        echo -e "  ${YELLOW}UMAPs are created automatically when users interact with geographic cells.${NC}"
        return 0
    fi
    
    local count=0
    
    while IFS= read -r umap_dir; do
        [[ -z "$umap_dir" ]] && continue
        
        local umap_name=$(basename "$umap_dir")
        local hex_file="${umap_dir}/HEX"
        
        if [[ -f "$hex_file" ]]; then
            local hex=$(cat "$hex_file" 2>/dev/null)
            count=$((count + 1))
            
            # Extract coordinates from UMAP name (format: UMAP_LAT_LON)
            local coords=$(echo "$umap_name" | sed 's/UMAP_//' | tr '_' ',')
            
            echo -e "  ${YELLOW}$count.${NC} 🗺️  ${GREEN}$umap_name${NC}"
            echo -e "      Coordinates: $coords"
            echo -e "      HEX: ${hex:0:16}..."
            echo ""
        fi
    done <<< "$umap_dirs"
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}Total UMAPs: $count${NC}"
}

cmd_umap_browse() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}🗺️  UMAP DID Browser${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Find local UMAP directories
    local -a umap_names=()
    local -a umap_hexes=()
    
    while IFS= read -r umap_dir; do
        [[ -z "$umap_dir" ]] && continue
        
        local umap_name=$(basename "$umap_dir")
        local hex_file="${umap_dir}/HEX"
        
        if [[ -f "$hex_file" ]]; then
            local hex=$(cat "$hex_file" 2>/dev/null)
            umap_names+=("$umap_name")
            umap_hexes+=("$hex")
        fi
    done < <(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "UMAP*" 2>/dev/null)
    
    if [[ ${#umap_names[@]} -eq 0 ]]; then
        log_warning "No UMAPs found"
        return 0
    fi
    
    local current_page=0
    local items_per_page=5
    local total_items=${#umap_names[@]}
    local total_pages=$(( (total_items + items_per_page - 1) / items_per_page ))
    
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                    ${YELLOW}🗺️  UMAP DID Browser${NC}                                    ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}Page $((current_page + 1))/$total_pages${NC} - ${GREEN}$total_items UMAPs${NC} total"
        echo ""
        
        local start_idx=$((current_page * items_per_page))
        local end_idx=$((start_idx + items_per_page))
        [[ $end_idx -gt $total_items ]] && end_idx=$total_items
        
        local display_idx=1
        for ((i=start_idx; i<end_idx; i++)); do
            local coords=$(echo "${umap_names[$i]}" | sed 's/UMAP_//' | tr '_' ',')
            
            echo -e "  ${YELLOW}$display_idx.${NC} 🗺️  ${GREEN}${umap_names[$i]}${NC}"
            echo -e "      Coordinates: $coords"
            echo -e "      HEX: ${umap_hexes[$i]:0:16}..."
            echo ""
            
            display_idx=$((display_idx + 1))
        done
        
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${YELLOW}1-$items_per_page.${NC} 🔍 View UMAP details"
        [[ $current_page -gt 0 ]] && echo -e "  ${YELLOW}p.${NC} ⬅️  Previous page"
        [[ $current_page -lt $((total_pages - 1)) ]] && echo -e "  ${YELLOW}n.${NC} ➡️  Next page"
        echo -e "  ${YELLOW}b.${NC} 🔙 Back to menu"
        echo ""
        
        read -p "$(echo -e ${CYAN}Choose action:${NC} )" action
        
        case "$action" in
            p)
                [[ $current_page -gt 0 ]] && current_page=$((current_page - 1))
                ;;
            n)
                [[ $current_page -lt $((total_pages - 1)) ]] && current_page=$((current_page + 1))
                ;;
            b)
                return 0
                ;;
            [1-5])
                local umap_idx=$((start_idx + action - 1))
                if [[ $umap_idx -lt $end_idx ]]; then
                    show_umap_details "${umap_names[$umap_idx]}" "${umap_hexes[$umap_idx]}"
                else
                    log_error "Invalid UMAP number"
                    sleep 1
                fi
                ;;
            *)
                log_error "Invalid action"
                sleep 1
                ;;
        esac
    done
}

show_umap_details() {
    local umap_name="$1"
    local hex="$2"
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}🗺️  UMAP Details: $umap_name${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local coords=$(echo "$umap_name" | sed 's/UMAP_//' | tr '_' ',')
    local lat=$(echo "$coords" | cut -d',' -f1)
    local lon=$(echo "$coords" | cut -d',' -f2)
    
    echo -e "${YELLOW}📋 Geographic Information${NC}"
    echo -e "  Name: ${GREEN}$umap_name${NC}"
    echo -e "  Latitude: $lat"
    echo -e "  Longitude: $lon"
    echo -e "  Cell Size: 0.01° x 0.01° (~1.1km x 1.1km)"
    echo -e "  HEX: $hex"
    echo ""
    
    # Check for DID on Nostr
    echo -e "${YELLOW}🔍 Nostr DID Status${NC}"
    local did_event=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --author "$hex" --limit 1 2>/dev/null)
    
    if [[ -n "$did_event" ]] && [[ "$did_event" != "[]" ]]; then
        echo -e "  Status: ${GREEN}Published on Nostr${NC}"
        
        local content=$(echo "$did_event" | jq -r '.content // "{}"' 2>/dev/null)
        local ore_status=$(echo "$content" | jq -r '.metadata.oreSystem.environmentalObligations.verification_status // "unknown"' 2>/dev/null)
        local plantnet_count=$(echo "$content" | jq -r '.metadata.plantnetBiodiversity.detections_count // "0"' 2>/dev/null)
        
        echo -e "  ORE Status: $ore_status"
        echo -e "  PlantNet Detections: $plantnet_count"
    else
        echo -e "  Status: ${YELLOW}Not published on Nostr${NC}"
    fi
    echo ""
    
    # Check local files
    local umap_dir="${HOME}/.zen/game/nostr/${umap_name}"
    echo -e "${YELLOW}📁 Local Files${NC}"
    if [[ -d "$umap_dir" ]]; then
        echo -e "  Directory: $umap_dir"
        local file_count=$(find "$umap_dir" -type f 2>/dev/null | wc -l)
        echo -e "  Files: $file_count"
    else
        echo -e "  Directory: ${RED}Not found${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    read -p "Press ENTER to go back..."
}

cmd_umap_stats() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}📊 UMAP Statistics${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local total_umaps=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "UMAP*" 2>/dev/null | wc -l)
    
    echo -e "${YELLOW}📊 Local UMAPs${NC}"
    echo -e "  Total: $total_umaps"
    echo ""
    
    # Count UMAPs by region (first digit of coordinates)
    echo -e "${YELLOW}🗺️  Geographic Distribution${NC}"
    
    local -A lat_counts
    local -A lon_counts
    
    while IFS= read -r umap_dir; do
        [[ -z "$umap_dir" ]] && continue
        
        local umap_name=$(basename "$umap_dir")
        local lat=$(echo "$umap_name" | sed 's/UMAP_//' | cut -d'_' -f1 | cut -d'.' -f1)
        local lon=$(echo "$umap_name" | sed 's/UMAP_//' | cut -d'_' -f2 | cut -d'.' -f1)
        
        lat_counts["$lat"]=$((${lat_counts["$lat"]:-0} + 1))
        lon_counts["$lon"]=$((${lon_counts["$lon"]:-0} + 1))
    done < <(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "UMAP*" 2>/dev/null)
    
    echo -e "  Latitude bands:"
    for lat in "${!lat_counts[@]}"; do
        echo -e "    ${lat}°: ${lat_counts[$lat]} UMAPs"
    done
    
    echo ""
    echo -e "  Longitude bands:"
    for lon in "${!lon_counts[@]}"; do
        echo -e "    ${lon}°: ${lon_counts[$lon]} UMAPs"
    done
    echo ""
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# USER DIDs
################################################################################
cmd_user_list() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}👤 User DIDs (MULTIPASS & ZEN Card)${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Find local user directories (email format)
    local user_dirs=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "*@*" 2>/dev/null)
    
    if [[ -z "$user_dirs" ]]; then
        log_warning "No local user directories found"
        return 0
    fi
    
    local count=0
    
    while IFS= read -r user_dir; do
        [[ -z "$user_dir" ]] && continue
        
        local email=$(basename "$user_dir")
        local hex_file="${user_dir}/HEX"
        local did_cache="${user_dir}/did.json.cache"
        
        if [[ -f "$hex_file" ]]; then
            local hex=$(cat "$hex_file" 2>/dev/null)
            count=$((count + 1))
            
            local contract_status="unknown"
            local token_types=""
            
            if [[ -f "$did_cache" ]]; then
                contract_status=$(jq -r '.metadata.contractStatus // "unknown"' "$did_cache" 2>/dev/null)
                token_types=$(jq -r '.metadata.tokenTypes // [] | join(",")' "$did_cache" 2>/dev/null)
            fi
            
            local token_display=""
            [[ -n "$token_types" ]] && [[ "$token_types" != "null" ]] && token_display=" | 🪙 $token_types"
            
            echo -e "  ${YELLOW}$count.${NC} 👤 ${GREEN}$email${NC}"
            echo -e "      HEX: ${hex:0:16}..."
            echo -e "      Status: ${CYAN}$contract_status${NC}$token_display"
            echo ""
        fi
    done <<< "$user_dirs"
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}Total users: $count${NC}"
}

cmd_user_browse() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}👤 User DID Browser${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Find local user directories
    local -a user_emails=()
    local -a user_hexes=()
    
    while IFS= read -r user_dir; do
        [[ -z "$user_dir" ]] && continue
        
        local email=$(basename "$user_dir")
        local hex_file="${user_dir}/HEX"
        
        if [[ -f "$hex_file" ]]; then
            local hex=$(cat "$hex_file" 2>/dev/null)
            user_emails+=("$email")
            user_hexes+=("$hex")
        fi
    done < <(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "*@*" 2>/dev/null)
    
    if [[ ${#user_emails[@]} -eq 0 ]]; then
        log_warning "No users found"
        return 0
    fi
    
    local current_page=0
    local items_per_page=5
    local total_items=${#user_emails[@]}
    local total_pages=$(( (total_items + items_per_page - 1) / items_per_page ))
    
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                    ${YELLOW}👤 User DID Browser${NC}                                      ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}Page $((current_page + 1))/$total_pages${NC} - ${GREEN}$total_items users${NC} total"
        echo ""
        
        local start_idx=$((current_page * items_per_page))
        local end_idx=$((start_idx + items_per_page))
        [[ $end_idx -gt $total_items ]] && end_idx=$total_items
        
        local display_idx=1
        for ((i=start_idx; i<end_idx; i++)); do
            local did_cache="${HOME}/.zen/game/nostr/${user_emails[$i]}/did.json.cache"
            local contract_status="unknown"
            local token_types=""
            
            if [[ -f "$did_cache" ]]; then
                contract_status=$(jq -r '.metadata.contractStatus // "unknown"' "$did_cache" 2>/dev/null)
                token_types=$(jq -r '.metadata.tokenTypes // [] | join(",")' "$did_cache" 2>/dev/null)
            fi
            
            local token_display=""
            [[ -n "$token_types" ]] && [[ "$token_types" != "null" ]] && token_display=" | 🪙 $token_types"
            
            echo -e "  ${YELLOW}$display_idx.${NC} 👤 ${GREEN}${user_emails[$i]}${NC}"
            echo -e "      HEX: ${user_hexes[$i]:0:16}..."
            echo -e "      Status: ${CYAN}$contract_status${NC}$token_display"
            echo ""
            
            display_idx=$((display_idx + 1))
        done
        
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${YELLOW}1-$items_per_page.${NC} 🔍 View user details"
        [[ $current_page -gt 0 ]] && echo -e "  ${YELLOW}p.${NC} ⬅️  Previous page"
        [[ $current_page -lt $((total_pages - 1)) ]] && echo -e "  ${YELLOW}n.${NC} ➡️  Next page"
        echo -e "  ${YELLOW}b.${NC} 🔙 Back to menu"
        echo ""
        
        read -p "$(echo -e ${CYAN}Choose action:${NC} )" action
        
        case "$action" in
            p)
                [[ $current_page -gt 0 ]] && current_page=$((current_page - 1))
                ;;
            n)
                [[ $current_page -lt $((total_pages - 1)) ]] && current_page=$((current_page + 1))
                ;;
            b)
                return 0
                ;;
            [1-5])
                local user_idx=$((start_idx + action - 1))
                if [[ $user_idx -lt $end_idx ]]; then
                    show_user_details "${user_emails[$user_idx]}" "${user_hexes[$user_idx]}"
                else
                    log_error "Invalid user number"
                    sleep 1
                fi
                ;;
            *)
                log_error "Invalid action"
                sleep 1
                ;;
        esac
    done
}

show_user_details() {
    local email="$1"
    local hex="$2"
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}👤 User Details: $email${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local user_dir="${HOME}/.zen/game/nostr/${email}"
    local did_cache="${user_dir}/did.json.cache"
    
    echo -e "${YELLOW}📋 Basic Information${NC}"
    echo -e "  Email: ${GREEN}$email${NC}"
    echo -e "  HEX: $hex"
    echo ""
    
    if [[ -f "$did_cache" ]]; then
        local did_id=$(jq -r '.id // empty' "$did_cache" 2>/dev/null)
        local contract_status=$(jq -r '.metadata.contractStatus // "unknown"' "$did_cache" 2>/dev/null)
        local storage_quota=$(jq -r '.metadata.storageQuota // "N/A"' "$did_cache" 2>/dev/null)
        local services=$(jq -r '.metadata.services // "N/A"' "$did_cache" 2>/dev/null)
        local token_types=$(jq -r '.metadata.tokenTypes // [] | join(", ")' "$did_cache" 2>/dev/null)
        
        echo -e "${YELLOW}📊 Contract Information${NC}"
        echo -e "  DID: ${did_id:0:50}..."
        echo -e "  Status: ${CYAN}$contract_status${NC}"
        echo -e "  Quota: $storage_quota"
        echo -e "  Services: $services"
        [[ -n "$token_types" ]] && [[ "$token_types" != "null" ]] && echo -e "  Token Types: ${CYAN}$token_types${NC}"
        echo ""
        
        # Wallets
        local g1_multipass=$(jq -r '.metadata.multipassWallet.g1pub // empty' "$did_cache" 2>/dev/null)
        local g1_zencard=$(jq -r '.metadata.zencardWallet.g1pub // empty' "$did_cache" 2>/dev/null)
        
        echo -e "${YELLOW}💰 Wallets${NC}"
        if [[ -n "$g1_multipass" ]]; then
            local mp_balance=$(get_wallet_balance "$g1_multipass")
            echo -e "  MULTIPASS: $g1_multipass"
            echo -e "             Balance: ${CYAN}$mp_balance Ğ1${NC}"
        else
            echo -e "  MULTIPASS: ${RED}Not set${NC}"
        fi
        
        if [[ -n "$g1_zencard" ]]; then
            local zc_balance=$(get_wallet_balance "$g1_zencard")
            echo -e "  ZEN Card:  $g1_zencard"
            echo -e "             Balance: ${CYAN}$zc_balance Ğ1${NC}"
        fi
        echo ""
        
        # France Connect
        local fc_compliance=$(jq -r '.metadata.franceConnect.compliance // empty' "$did_cache" 2>/dev/null)
        if [[ -n "$fc_compliance" ]]; then
            echo -e "${YELLOW}🇫🇷 France Connect${NC}"
            if [[ "$fc_compliance" == "enabled" ]]; then
                echo -e "  Status: ${GREEN}Enabled${NC}"
            else
                echo -e "  Status: ${YELLOW}Disabled${NC}"
            fi
            echo ""
        fi
    else
        echo -e "  ${YELLOW}No local DID cache found${NC}"
        echo ""
    fi
    
    # Check Nostr status
    echo -e "${YELLOW}🔍 Nostr DID Status${NC}"
    local did_event=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --author "$hex" --limit 1 2>/dev/null)
    
    if [[ -n "$did_event" ]] && [[ "$did_event" != "[]" ]]; then
        echo -e "  Status: ${GREEN}Published on Nostr${NC}"
        local event_id=$(echo "$did_event" | jq -r '.id // empty' 2>/dev/null)
        echo -e "  Event ID: ${event_id:0:16}..."
    else
        echo -e "  Status: ${YELLOW}Not published on Nostr${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} 🔄 Sync DID from Nostr"
    echo -e "  ${YELLOW}2.${NC} ✅ Validate DID structure"
    echo -e "  ${YELLOW}3.${NC} 💾 Export DID"
    echo -e "  ${YELLOW}b.${NC} 🔙 Back"
    echo ""
    
    read -p "$(echo -e ${CYAN}Choose action:${NC} )" action
    
    case "$action" in
        1)
            log_info "Syncing DID from Nostr..."
            if [[ -f "$DID_MANAGER" ]]; then
                bash "$DID_MANAGER" sync "$email"
            else
                log_error "DID manager not found"
            fi
            read -p "Press ENTER to continue..."
            ;;
        2)
            if [[ -f "$did_cache" ]]; then
                log_info "Validating DID structure..."
                if [[ -f "$DID_MANAGER" ]]; then
                    bash "$DID_MANAGER" validate "$did_cache"
                fi
            else
                log_error "No DID cache to validate"
            fi
            read -p "Press ENTER to continue..."
            ;;
        3)
            if [[ -f "$did_cache" ]]; then
                local export_file="${HOME}/.zen/tmp/did_${email//@/_}_$(date +%Y%m%d_%H%M%S).json"
                cp "$did_cache" "$export_file"
                log_success "DID exported to: $export_file"
            else
                log_error "No DID cache to export"
            fi
            read -p "Press ENTER to continue..."
            ;;
        b)
            return 0
            ;;
    esac
}

cmd_user_stats() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}📊 User DID Statistics${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local total_users=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "*@*" 2>/dev/null | wc -l)
    
    local with_did_cache=0
    local with_multipass=0
    local with_zencard=0
    local -A contract_types
    local -A token_type_counts
    
    while IFS= read -r user_dir; do
        [[ -z "$user_dir" ]] && continue
        
        local did_cache="${user_dir}/did.json.cache"
        
        if [[ -f "$did_cache" ]]; then
            with_did_cache=$((with_did_cache + 1))
            
            local contract_status=$(jq -r '.metadata.contractStatus // "unknown"' "$did_cache" 2>/dev/null)
            contract_types["$contract_status"]=$((${contract_types["$contract_status"]:-0} + 1))
            
            local multipass=$(jq -r '.metadata.multipassWallet.g1pub // empty' "$did_cache" 2>/dev/null)
            [[ -n "$multipass" ]] && with_multipass=$((with_multipass + 1))
            
            local zencard=$(jq -r '.metadata.zencardWallet.g1pub // empty' "$did_cache" 2>/dev/null)
            [[ -n "$zencard" ]] && with_zencard=$((with_zencard + 1))
            
            # Token types
            local has_zencoin=$(jq -r '.metadata.tokenTypes // [] | .[] | select(. == "ZENCOIN")' "$did_cache" 2>/dev/null)
            local has_zencard_token=$(jq -r '.metadata.tokenTypes // [] | .[] | select(. == "ZENCARD")' "$did_cache" 2>/dev/null)
            [[ -n "$has_zencoin" ]] && token_type_counts["ZENCOIN"]=$((${token_type_counts["ZENCOIN"]:-0} + 1))
            [[ -n "$has_zencard_token" ]] && token_type_counts["ZENCARD"]=$((${token_type_counts["ZENCARD"]:-0} + 1))
        fi
    done < <(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "*@*" 2>/dev/null)
    
    echo -e "${YELLOW}📊 User Overview${NC}"
    echo -e "  Total users: $total_users"
    echo -e "  With DID cache: $with_did_cache"
    echo ""
    
    echo -e "${YELLOW}💰 Wallet Distribution${NC}"
    echo -e "  MULTIPASS wallets: $with_multipass"
    echo -e "  ZEN Card wallets: $with_zencard"
    echo ""
    
    echo -e "${YELLOW}🪙 Token Types${NC}"
    for token_type in "${!token_type_counts[@]}"; do
        echo -e "  $token_type: ${token_type_counts[$token_type]}"
    done
    echo ""
    
    echo -e "${YELLOW}📋 Contract Types${NC}"
    for contract_type in "${!contract_types[@]}"; do
        echo -e "  $contract_type: ${contract_types[$contract_type]}"
    done
    echo ""
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Update User DID Metadata
################################################################################
cmd_user_update() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}📝 Update User DID Metadata${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Find user
    local email="$USER_EMAIL"
    local hex="$USER_HEX"
    
    if [[ -z "$email" ]] && [[ -z "$hex" ]]; then
        # List available users
        local -a user_emails=()
        
        while IFS= read -r user_dir; do
            [[ -z "$user_dir" ]] && continue
            user_emails+=("$(basename "$user_dir")")
        done < <(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "*@*" 2>/dev/null)
        
        if [[ ${#user_emails[@]} -eq 0 ]]; then
            log_warning "No users found"
            return 1
        fi
        
        echo -e "${YELLOW}Select user to update:${NC}"
        echo ""
        
        local idx=1
        for e in "${user_emails[@]}"; do
            echo -e "  ${YELLOW}$idx.${NC} $e"
            idx=$((idx + 1))
        done
        echo ""
        
        read -p "$(echo -e ${CYAN}Enter number:${NC} )" selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#user_emails[@]} ]]; then
            email="${user_emails[$((selection - 1))]}"
        else
            log_error "Invalid selection"
            return 1
        fi
    fi
    
    # Get hex from email
    if [[ -z "$hex" ]] && [[ -n "$email" ]]; then
        hex=$(find_hex_from_email "$email")
    fi
    
    if [[ -z "$hex" ]]; then
        log_error "Cannot find hex pubkey for user"
        return 1
    fi
    
    local nostr_dir="${HOME}/.zen/game/nostr/${email}"
    local did_cache="${nostr_dir}/did.json.cache"
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}📝 Update DID for: $email${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show current metadata
    if [[ -f "$did_cache" ]]; then
        echo -e "${YELLOW}Current Metadata:${NC}"
        local contract_status=$(jq -r '.metadata.contractStatus // "N/A"' "$did_cache" 2>/dev/null)
        local storage_quota=$(jq -r '.metadata.storageQuota // "N/A"' "$did_cache" 2>/dev/null)
        local services=$(jq -r '.metadata.services // "N/A"' "$did_cache" 2>/dev/null)
        local updated=$(jq -r '.metadata.updated // "N/A"' "$did_cache" 2>/dev/null)
        
        echo -e "  Contract Status: ${CYAN}$contract_status${NC}"
        echo -e "  Storage Quota:   ${CYAN}$storage_quota${NC}"
        echo -e "  Services:        ${CYAN}$services${NC}"
        echo -e "  Last Updated:    ${CYAN}$updated${NC}"
        echo ""
    fi
    
    echo -e "${YELLOW}Select update type:${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} 🎫 MULTIPASS - Renew usage tokens (10GB, uDRIVE)"
    echo -e "  ${YELLOW}2.${NC} 🛰️  SOCIETAIRE_SATELLITE - Cooperative member (128GB, NextCloud)"
    echo -e "  ${YELLOW}3.${NC} 🌟 SOCIETAIRE_CONSTELLATION - Full member (128GB, NextCloud + AI)"
    echo -e "  ${YELLOW}4.${NC} 🏗️  INFRASTRUCTURE - Infrastructure contributor"
    echo -e "  ${YELLOW}5.${NC} 💰 TREASURY_CONTRIBUTION - Treasury contributor"
    echo -e "  ${YELLOW}6.${NC} 🔬 RND_CONTRIBUTION - R&D contributor"
    echo -e "  ${YELLOW}7.${NC} 🏦 ASSETS_CONTRIBUTION - Assets contributor"
    echo -e "  ${YELLOW}8.${NC} 🔗 WOT_MEMBER - Web of Trust verification"
    echo -e "  ${YELLOW}9.${NC} 🌿 ORE_GUARDIAN - Environmental guardian authority"
    echo -e "  ${YELLOW}10.${NC} 🌱 PLANTNET_DETECTION - Biodiversity detection"
    echo -e "  ${YELLOW}11.${NC} ⚠️  ACCOUNT_DEACTIVATED - Deactivate account"
    echo ""
    echo -e "  ${YELLOW}c.${NC} 🛠️  Custom metadata update"
    echo -e "  ${YELLOW}b.${NC} 🔙 Back"
    echo ""
    
    read -p "$(echo -e ${CYAN}Choose update type:${NC} )" action
    
    local update_type=""
    local montant_zen="0"
    local montant_g1="0"
    local wot_g1pub=""
    
    case "$action" in
        1) update_type="MULTIPASS" ;;
        2) update_type="SOCIETAIRE_SATELLITE" ;;
        3) update_type="SOCIETAIRE_CONSTELLATION" ;;
        4) update_type="INFRASTRUCTURE" ;;
        5) update_type="TREASURY_CONTRIBUTION" ;;
        6) update_type="RND_CONTRIBUTION" ;;
        7) update_type="ASSETS_CONTRIBUTION" ;;
        8)
            update_type="WOT_MEMBER"
            read -p "Enter WoT G1 public key: " wot_g1pub
            if [[ -z "$wot_g1pub" ]]; then
                log_error "WoT G1 public key required"
                return 1
            fi
            ;;
        9) update_type="ORE_GUARDIAN" ;;
        10) update_type="PLANTNET_DETECTION" ;;
        11) update_type="ACCOUNT_DEACTIVATED" ;;
        c)
            update_user_metadata_custom "$email" "$hex"
            return $?
            ;;
        b) return 0 ;;
        *)
            log_error "Invalid selection"
            return 1
            ;;
    esac
    
    if [[ -n "$update_type" ]]; then
        # Ask for payment amounts for relevant types
        if [[ "$update_type" == "MULTIPASS" ]] || [[ "$update_type" =~ "SOCIETAIRE" ]]; then
            echo ""
            read -p "Enter Ẑen amount (or 0): " montant_zen
            read -p "Enter Ğ1 amount (or 0): " montant_g1
        fi
        
        echo ""
        log_info "Updating DID with type: $update_type"
        
        # Call did_manager_nostr.sh to update
        if [[ -f "${MY_PATH}/did_manager_nostr.sh" ]]; then
            bash "${MY_PATH}/did_manager_nostr.sh" update "$email" "$update_type" "$montant_zen" "$montant_g1" "$wot_g1pub"
            
            if [[ $? -eq 0 ]]; then
                log_success "DID updated successfully"
            else
                log_error "Failed to update DID"
            fi
        else
            log_error "did_manager_nostr.sh not found"
            return 1
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Custom metadata update
update_user_metadata_custom() {
    local email="$1"
    local hex="$2"
    
    local nostr_dir="${HOME}/.zen/game/nostr/${email}"
    local did_cache="${nostr_dir}/did.json.cache"
    
    if [[ ! -f "$did_cache" ]]; then
        log_error "No local DID cache found for $email"
        return 1
    fi
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}🛠️  Custom Metadata Update${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Select metadata field to update:${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} contractStatus - Change contract status"
    echo -e "  ${YELLOW}2.${NC} storageQuota - Update storage quota"
    echo -e "  ${YELLOW}3.${NC} services - Update available services"
    echo -e "  ${YELLOW}4.${NC} description - Add/update description"
    echo -e "  ${YELLOW}5.${NC} alias - Add alias (alsoKnownAs)"
    echo -e "  ${YELLOW}6.${NC} latitude/longitude - Update location"
    echo -e "  ${YELLOW}b.${NC} Back"
    echo ""
    
    read -p "$(echo -e ${CYAN}Choose field:${NC} )" field_choice
    
    local jq_update=""
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    case "$field_choice" in
        1)
            echo ""
            echo "Available statuses: new_user, active_rental, cooperative_member_satellite,"
            echo "cooperative_member_constellation, infrastructure_contributor, ore_guardian_authority"
            echo ""
            read -p "Enter new contract status: " new_status
            jq_update=".metadata.contractStatus = \"$new_status\" | .metadata.updated = \"$timestamp\""
            ;;
        2)
            read -p "Enter new storage quota (e.g., 10GB, 128GB): " new_quota
            jq_update=".metadata.storageQuota = \"$new_quota\" | .metadata.updated = \"$timestamp\""
            ;;
        3)
            echo "Example: uDRIVE IPFS storage, NextCloud private storage, AI services"
            read -p "Enter new services: " new_services
            jq_update=".metadata.services = \"$new_services\" | .metadata.updated = \"$timestamp\""
            ;;
        4)
            read -p "Enter description: " new_desc
            jq_update=".metadata.description = \"$new_desc\" | .metadata.updated = \"$timestamp\""
            ;;
        5)
            echo "Example: did:web:example.com, https://mastodon.social/@user"
            read -p "Enter alias to add: " new_alias
            jq_update=".alsoKnownAs = ((.alsoKnownAs // []) + [\"$new_alias\"]) | .metadata.updated = \"$timestamp\""
            ;;
        6)
            read -p "Enter latitude: " lat
            read -p "Enter longitude: " lon
            jq_update=".metadata.geolocation = {\"latitude\": \"$lat\", \"longitude\": \"$lon\"} | .metadata.updated = \"$timestamp\""
            ;;
        b) return 0 ;;
        *)
            log_error "Invalid selection"
            return 1
            ;;
    esac
    
    if [[ -n "$jq_update" ]]; then
        log_info "Applying update..."
        
        local temp_did=$(mktemp)
        
        if jq "$jq_update" "$did_cache" > "$temp_did" 2>/dev/null && [[ -s "$temp_did" ]]; then
            mv "$temp_did" "$did_cache"
            log_success "Local DID cache updated"
            
            # Publish to Nostr
            read -p "Publish updated DID to Nostr? (y/N): " publish_choice
            
            if [[ "$publish_choice" =~ ^[Yy] ]]; then
                local nsec_file="${nostr_dir}/.secret.nostr"
                local nsec=""
                
                if [[ -f "$nsec_file" ]]; then
                    nsec=$(grep -oP 'NSEC=\K[^;]+' "$nsec_file" 2>/dev/null | head -1 | tr -d ' ')
                fi
                
                if [[ -n "$nsec" ]] && [[ -f "${MY_PATH}/nostr_publish_did.py" ]]; then
                    log_info "Publishing to Nostr..."
                    python3 "${MY_PATH}/nostr_publish_did.py" "$nsec" "$did_cache" ws://127.0.0.1:7777 wss://relay.copylaradio.com 2>&1
                    
                    if [[ $? -eq 0 ]]; then
                        log_success "DID published to Nostr"
                    else
                        log_error "Failed to publish to Nostr"
                    fi
                else
                    log_warning "Cannot publish - missing keys or publish script"
                fi
            fi
        else
            rm -f "$temp_did"
            log_error "Failed to apply update"
            return 1
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# GLOBAL Commands
################################################################################
cmd_list_all() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}📋 All DIDs from Relay${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "Fetching DIDs from relay..."
    
    local events=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit "${LIMIT:-100}" 2>/dev/null)
    
    if [[ -z "$events" ]]; then
        log_warning "No DIDs found on relay"
        return 0
    fi
    
    local count=0
    local -A type_counts
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        
        local event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)
        [[ -z "$event_id" ]] && continue
        
        count=$((count + 1))
        
        local author=$(echo "$event" | jq -r '.pubkey // "unknown"')
        local created_at=$(echo "$event" | jq -r '.created_at // 0')
        local date=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
        
        local content=$(echo "$event" | jq -r '.content // "{}"' 2>/dev/null)
        local did_id=$(echo "$content" | jq -r '.id // empty' 2>/dev/null)
        local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // "unknown"' 2>/dev/null)
        
        local did_type=$(classify_did_type "$content")
        type_counts["$did_type"]=$((${type_counts["$did_type"]:-0} + 1))
        
        local email=$(find_email_from_hex "$author")
        [[ -z "$email" ]] && email="(unknown)"
        
        local type_icon=""
        case "$did_type" in
            COOPERATIVE) type_icon="🏛️" ;;
            UMAP) type_icon="🗺️" ;;
            USER) type_icon="👤" ;;
        esac
        
        echo -e "  ${YELLOW}$count.${NC} $type_icon ${GREEN}${did_id:0:40}...${NC}"
        echo -e "      Author: ${author:0:16}... ($email)"
        echo -e "      Type: ${CYAN}$did_type${NC} | Status: $contract_status | Date: $date"
        echo ""
        
    done <<< "$events"
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}Total DIDs: $count${NC}"
    echo ""
    echo -e "  ${YELLOW}By Type:${NC}"
    for type in "${!type_counts[@]}"; do
        echo -e "    $type: ${type_counts[$type]}"
    done
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

cmd_stats() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}📊 Global DID Statistics${NC}                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Local stats
    local local_users=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "*@*" 2>/dev/null | wc -l)
    local local_umaps=$(find "${HOME}/.zen/game/nostr" -maxdepth 1 -type d -name "UMAP*" 2>/dev/null | wc -l)
    
    echo -e "${YELLOW}📁 Local Data${NC}"
    echo -e "  Users: $local_users"
    echo -e "  UMAPs: $local_umaps"
    echo ""
    
    # Relay stats
    log_info "Fetching statistics from relay..."
    
    local events=$(bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit 1000 2>/dev/null)
    
    if [[ -n "$events" ]]; then
        local total=$(echo "$events" | jq -s 'length' 2>/dev/null || echo "0")
        
        local -A type_counts
        local -A contract_counts
        
        while IFS= read -r event; do
            [[ -z "$event" ]] && continue
            
            local content=$(echo "$event" | jq -r '.content // "{}"' 2>/dev/null)
            local did_type=$(classify_did_type "$content")
            local contract_status=$(echo "$content" | jq -r '.metadata.contractStatus // "unknown"' 2>/dev/null)
            
            type_counts["$did_type"]=$((${type_counts["$did_type"]:-0} + 1))
            contract_counts["$contract_status"]=$((${contract_counts["$contract_status"]:-0} + 1))
        done <<< "$events"
        
        echo -e "${YELLOW}🌐 Relay Data${NC}"
        echo -e "  Total DIDs: $total"
        echo ""
        
        echo -e "${YELLOW}📊 By Type${NC}"
        for type in "${!type_counts[@]}"; do
            local percent=$(( (${type_counts[$type]} * 100) / total ))
            echo -e "  $type: ${type_counts[$type]} ($percent%)"
        done
        echo ""
        
        echo -e "${YELLOW}📋 By Contract Status${NC}"
        for status in "${!contract_counts[@]}"; do
            echo -e "  $status: ${contract_counts[$status]}"
        done
    else
        echo -e "  ${YELLOW}No data from relay${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

cmd_export_all() {
    local export_dir="${HOME}/.zen/tmp/did_export_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    
    log_info "Exporting all DIDs to: $export_dir"
    
    # Export from relay
    local relay_file="${export_dir}/relay_dids.json"
    bash "$NOSTR_GET_EVENTS" --kind $DID_EVENT_KIND --limit 1000 2>/dev/null > "$relay_file"
    log_success "Relay DIDs exported: $relay_file"
    
    # Export local caches
    local local_dir="${export_dir}/local_caches"
    mkdir -p "$local_dir"
    
    local count=0
    while IFS= read -r cache_file; do
        [[ -z "$cache_file" ]] && continue
        
        local email=$(basename "$(dirname "$cache_file")")
        cp "$cache_file" "${local_dir}/${email}.json"
        count=$((count + 1))
    done < <(find "${HOME}/.zen/game/nostr" -name "did.json.cache" 2>/dev/null)
    
    log_success "Local caches exported: $count files"
    
    echo ""
    echo -e "  ${GREEN}Export complete!${NC}"
    echo -e "  Directory: $export_dir"
}

################################################################################
# Main
################################################################################
main() {
    # Default options
    EMAIL=""
    HEX=""
    LIMIT=100
    VERBOSE=false
    
    # Check for help first
    [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] && usage
    
    # Parse command
    COMMAND="${1:-menu}"
    shift || true
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -x|--hex)
                HEX="$2"
                shift 2
                ;;
            -l|--limit)
                LIMIT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Check dependencies
    check_dependencies || exit 1
    
    # Create temp dir
    mkdir -p "$TEMP_DIR"
    
    # Execute command
    case "$COMMAND" in
        menu)
            cmd_menu
            ;;
        coop-list)
            cmd_coop_list
            ;;
        coop-browse)
            cmd_coop_browse
            ;;
        coop-check)
            cmd_coop_check
            ;;
        coop-init)
            cmd_coop_init
            ;;
        coop-create)
            cmd_coop_create
            ;;
        umap-list)
            cmd_umap_list
            ;;
        umap-browse)
            cmd_umap_browse
            ;;
        umap-stats)
            cmd_umap_stats
            ;;
        user-list)
            cmd_user_list
            ;;
        user-browse)
            cmd_user_browse
            ;;
        user-stats)
            cmd_user_stats
            ;;
        user-update)
            cmd_user_update
            ;;
        list-all)
            cmd_list_all
            ;;
        stats)
            cmd_stats
            ;;
        export)
            cmd_export_all
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            ;;
    esac
}

# Trap cleanup
trap "rm -rf $TEMP_DIR" EXIT

# Run main
main "$@"
