#!/bin/bash
# -----------------------------------------------------------------------------
# zen.sh - Astroport.ONE Zen Transaction Manager
#
# This script allows captains to perform transactions using different wallet types
# according to the UPlanet economic model flowchart:
# - UPLANETNAME.G1: Reserve wallet for Ğ1 donations
# - UPLANETNAME: Services wallet for MULTIPASS operations
# - UPLANETNAME.SOCIETY: Social capital wallet for ZenCard operations
#
# Usage: ./zen.sh
# -----------------------------------------------------------------------------

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Cache utility functions for optimized performance
CACHE_DIR="$HOME/.zen/tmp/coucou"

# Function to ensure cache directory exists
ensure_cache_dir() {
    [[ ! -d "$CACHE_DIR" ]] && mkdir -p "$CACHE_DIR"
}

# Function to get wallet balance from cache with automatic refresh
get_wallet_balance() {
    local pubkey="$1"
    local auto_refresh="${2:-true}"
    
    ensure_cache_dir
    
    # Refresh cache if requested and pubkey is valid
    if [[ "$auto_refresh" == "true" ]] && [[ -n "$pubkey" ]]; then
        ${MY_PATH}/COINScheck.sh "$pubkey" >/dev/null 2>&1
    fi
    
    # Get balance from cache
    local balance=$(cat "$CACHE_DIR/${pubkey}.COINS" 2>/dev/null)
    if [[ -z "$balance" || "$balance" == "null" ]]; then
        echo "0"
    else
        echo "$balance"
    fi
}

# Function to get primal transaction info from cache
get_primal_info() {
    local pubkey="$1"
    
    ensure_cache_dir
    cat "$CACHE_DIR/${pubkey}.primal" 2>/dev/null
}

# Function to check if wallet has primal transaction
has_primal_transaction() {
    local pubkey="$1"
    local primal_info=$(get_primal_info "$pubkey")
    [[ -n "$primal_info" ]]
}

# Function to calculate Ẑen from Ğ1 balance (excluding primal transaction)
calculate_zen_balance() {
    local g1_balance="$1"
    
    if (( $(echo "$g1_balance > 1" | bc -l) )); then
        echo "($g1_balance - 1) * 10" | bc | cut -d '.' -f 1
    else
        echo "0"
    fi
}

# Function to validate public key format
is_valid_public_key() {
    local pubkey="$1"
    [[ -n "$pubkey" ]] && [[ "$pubkey" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]
}

# Function to get wallet status with optimized cache usage
get_wallet_status() {
    local pubkey="$1"
    local wallet_type="$2"
    
    local balance=$(get_wallet_balance "$pubkey")
    local has_primal=$(has_primal_transaction "$pubkey" && echo "true" || echo "false")
    
    # Calculate Ẑen for non-G1 wallets
    local zen_balance=""
    if [[ "$wallet_type" != "UPLANETNAME.G1" ]]; then
        zen_balance=$(calculate_zen_balance "$balance")
    fi
    
    echo "$balance|$has_primal|$zen_balance"
}

# Function to display wallet status with consistent formatting
display_wallet_status() {
    local pubkey="$1"
    local wallet_name="$2"
    local wallet_type="$3"
    local show_zen="${4:-true}"
    
    local status=$(get_wallet_status "$pubkey" "$wallet_type")
    local balance=$(echo "$status" | cut -d '|' -f 1)
    local has_primal=$(echo "$status" | cut -d '|' -f 2)
    local zen_balance=$(echo "$status" | cut -d '|' -f 3)
    
    # Format primal status
    local primal_status=""
    if [[ "$has_primal" == "true" ]]; then
        primal_status="${GREEN}✓ Primal TX${NC}"
    else
        primal_status="${RED}✗ No Primal TX${NC}"
    fi
    
    # Display balance
    local balance_display="${YELLOW}$balance Ğ1${NC}"
    if [[ "$show_zen" == "true" ]] && [[ -n "$zen_balance" ]] && [[ "$zen_balance" != "0" ]]; then
        balance_display="${YELLOW}$balance Ğ1${NC} (${CYAN}$zen_balance Ẑen${NC})"
    fi
    
    echo -e "${BLUE}Wallet:${NC} ${GREEN}$wallet_name${NC}"
    echo -e "${BLUE}Public Key:${NC} ${CYAN}$pubkey${NC}"
    echo -e "${BLUE}Balance:${NC} $balance_display"
    echo -e "${BLUE}Status:${NC} $primal_status"
}

# Function to clean and optimize cache
clean_cache() {
    local max_age_hours="${1:-24}"
    local cache_dir="$CACHE_DIR"
    
    if [[ ! -d "$cache_dir" ]]; then
        return 0
    fi
    
    echo -e "${CYAN}🧹 Cleaning cache files older than $max_age_hours hours...${NC}"
    
    # Find and remove old cache files
    local removed_count=0
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            ((removed_count++))
        fi
    done < <(find "$cache_dir" -name "*.COINS" -o -name "*.primal" -mtime +$((max_age_hours/24)) -print0 2>/dev/null)
    
    echo -e "${GREEN}✅ Removed $removed_count old cache files${NC}"
}

# Function to refresh all wallet balances
refresh_all_balances() {
    echo -e "${CYAN}🔄 Refreshing all wallet balances...${NC}"
    
    # Refresh system wallets
    local system_wallets=("UPLANETNAME_G1" "UPLANETG1PUB" "UPLANETNAME_SOCIETY")
    for wallet_file in "${system_wallets[@]}"; do
        local keyfile="$HOME/.zen/tmp/$wallet_file"
        if [[ -f "$keyfile" ]]; then
            local pubkey=$(cat "$keyfile" 2>/dev/null)
            if [[ -n "$pubkey" ]]; then
                ${MY_PATH}/COINScheck.sh "$pubkey" >/dev/null 2>&1
            fi
        fi
    done
    
    # Refresh MULTIPASS wallets
    if [[ -d ~/.zen/game/nostr ]]; then
        while IFS= read -r -d '' file; do
            local pubkey=$(cat "$file" 2>/dev/null)
            if [[ -n "$pubkey" ]]; then
                ${MY_PATH}/COINScheck.sh "$pubkey" >/dev/null 2>&1
            fi
        done < <(find ~/.zen/game/nostr -name "G1PUBNOSTR" -print0 2>/dev/null)
    fi
    
    # Refresh ZenCard wallets
    if [[ -d ~/.zen/game/players ]]; then
        while IFS= read -r -d '' file; do
            local pubkey=$(cat "$file" 2>/dev/null)
            if [[ -n "$pubkey" ]]; then
                ${MY_PATH}/COINScheck.sh "$pubkey" >/dev/null 2>&1
            fi
        done < <(find ~/.zen/game/players -name ".g1pub" -print0 2>/dev/null)
    fi
    
    echo -e "${GREEN}✅ All wallet balances refreshed${NC}"
}

# Function to display the flowchart position
show_flowchart_position() {
    local wallet_type="$1"
    local transaction_type="$2"
    
    echo -e "\n${CYAN}📍 POSITION IN THE FLOWCHART:${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    case "$wallet_type" in
        "UPLANETNAME.G1")
            echo -e "${BLUE}🏛️  WALLET TYPE: UPLANETNAME.G1 (Ğ1 Reserve)${NC}"
            echo -e "${GREEN}   → External World & Inputs${NC}"
            echo -e "${GREEN}   → Parent Cooperative${NC}"
            echo -e "${GREEN}   → Operational Cooperative: CopyLaRadio${NC}"
            echo -e "${PURPLE}   → Flow: Donation/Reserve Management${NC}"
            ;;
        "UPLANETNAME")
            echo -e "${BLUE}💼 WALLET TYPE: UPLANETNAME (Services & Cash-Flow)${NC}"
            echo -e "${GREEN}   → Operational Cooperative: CopyLaRadio${NC}"
            echo -e "${GREEN}   → User Wallets${NC}"
            echo -e "${PURPLE}   → Flow: Service Operations → MULTIPASS${NC}"
            ;;
        "UPLANETNAME.SOCIETY")
            echo -e "${BLUE}⭐ WALLET TYPE: UPLANETNAME.SOCIETY (Social Capital)${NC}"
            echo -e "${GREEN}   → Operational Cooperative: CopyLaRadio${NC}"
            echo -e "${GREEN}   → User Wallets${NC}"
            echo -e "${PURPLE}   → Flow: Investment Operations → ZenCard${NC}"
            ;;
    esac
    
    echo -e "${YELLOW}   → Transaction Type: $transaction_type${NC}"
    echo -e "${YELLOW}================================${NC}\n"
}

# Function to display usage information
usage() {
    echo -e "${CYAN}Usage: $ME [--detailed]${NC}"
    echo ""
    echo -e "${YELLOW}This script allows captains to perform transactions using different wallet types:${NC}"
    echo ""
    echo -e "${BLUE}1. UPLANETNAME.G1${NC} - Ğ1 Reserve Wallet"
    echo -e "   • Purpose: Manage Ğ1 donations and reserves"
    echo -e "   • Flow: External donations → Reserve management"
    echo ""
    echo -e "${BLUE}2. UPLANETNAME${NC} - Services & Cash-Flow Wallet"
    echo -e "   • Purpose: Handle service operations and MULTIPASS transactions"
    echo -e "   • Flow: Service payments → MULTIPASS wallet operations"
    echo ""
    echo -e "${BLUE}3. UPLANETNAME.SOCIETY${NC} - Social Capital Wallet"
    echo -e "   • Purpose: Manage cooperative shares and ZenCard operations"
    echo -e "   • Flow: Investment operations → ZenCard wallet management"
    echo ""
    echo -e "${GREEN}Options:${NC}"
    echo -e "  ${CYAN}--detailed${NC}  Show detailed status of all users"
    echo ""
    echo -e "${GREEN}The script will guide you through the selection process.${NC}"
    exit 1
}

# Function to list available MULTIPASS wallets
list_multipass_wallets() {
    echo -e "\n${CYAN}🔍 SEARCHING FOR MULTIPASS WALLETS...${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    multipass_wallets=()
    
    if [[ -d ~/.zen/game/nostr ]]; then
        # Find all NOSTR accounts with G1PUBNOSTR files
        account_names=($(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        
        if [[ ${#account_names[@]} -eq 0 ]]; then
            echo -e "${RED}No MULTIPASS wallets found in ~/.zen/game/nostr/${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Found ${#account_names[@]} MULTIPASS wallet(s):${NC}\n"
        
        for i in "${!account_names[@]}"; do
            account_name="${account_names[$i]}"
            g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
            
            if [[ -n "$g1pub" ]]; then
                # Get wallet status with optimized cache usage
                local status=$(get_wallet_status "$g1pub" "MULTIPASS")
                local balance=$(echo "$status" | cut -d '|' -f 1)
                local has_primal=$(echo "$status" | cut -d '|' -f 2)
                
                # Format primal status
                local primal_status=""
                if [[ "$has_primal" == "true" ]]; then
                    primal_status="${GREEN}✓ Primal TX${NC}"
                else
                    primal_status="${RED}✗ No Primal TX${NC}"
                fi
                
                multipass_wallets+=("$account_name")
                
                echo -e "${BLUE}$((i+1))) ${GREEN}$account_name${NC}"
                echo -e "    Public Key: ${CYAN}$g1pub${NC}"
                echo -e "    Balance: ${YELLOW}$balance Ğ1${NC}"
                echo -e "    Status: $primal_status"
                echo ""
            fi
        done
    else
        echo -e "${RED}NOSTR directory not found: ~/.zen/game/nostr/${NC}"
        return 1
    fi
    
    return 0
}

# Function to list available ZenCard wallets
list_zencard_wallets() {
    echo -e "\n${CYAN}🔍 SEARCHING FOR ZENCARD WALLETS...${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    zencard_wallets=()
    
    if [[ -d ~/.zen/game/players ]]; then
        # Find all player directories with .g1pub files
        player_dirs=($(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        
        if [[ ${#player_dirs[@]} -eq 0 ]]; then
            echo -e "${RED}No ZenCard wallets found in ~/.zen/game/players/${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Found ${#player_dirs[@]} ZenCard wallet(s):${NC}\n"
        
        for i in "${!player_dirs[@]}"; do
            player_dir="${player_dirs[$i]}"
            g1pub=$(cat ~/.zen/game/players/${player_dir}/.g1pub 2>/dev/null)
            
            if [[ -n "$g1pub" ]]; then
                # Get wallet status with optimized cache usage
                local status=$(get_wallet_status "$g1pub" "ZenCard")
                local balance=$(echo "$status" | cut -d '|' -f 1)
                local has_primal=$(echo "$status" | cut -d '|' -f 2)
                
                # Format primal status
                local primal_status=""
                if [[ "$has_primal" == "true" ]]; then
                    primal_status="${GREEN}✓ Primal TX${NC}"
                else
                    primal_status="${RED}✗ No Primal TX${NC}"
                fi
                
                # Check if user is a sociétaire (has U.SOCIETY file or is captain)
                local societaire_status=""
                if [[ -s ~/.zen/game/players/${player_dir}/U.SOCIETY ]] || [[ "${player_dir}" == "${CAPTAINEMAIL}" ]]; then
                    societaire_status="${GREEN}✓ Sociétaire${NC}"
                else
                    societaire_status="${YELLOW}⚠ Locataire${NC}"
                fi
                
                zencard_wallets+=("$player_dir")
                
                echo -e "${BLUE}$((i+1))) ${GREEN}$player_dir${NC}"
                echo -e "    Public Key: ${CYAN}$g1pub${NC}"
                echo -e "    Balance: ${YELLOW}$balance Ğ1${NC}"
                echo -e "    Status: $primal_status | $societaire_status"
                echo -e "    Details: $(get_user_status "$player_dir")"
                echo ""
            fi
        done
    else
        echo -e "${RED}Players directory not found: ~/.zen/game/players/${NC}"
        return 1
    fi
    
    return 0
}

# Function to select wallet from list
select_wallet() {
    local wallets=("$@")
    local wallet_type="$1"
    shift
    local wallet_list=("$@")
    
    if [[ ${#wallet_list[@]} -eq 0 ]]; then
        echo -e "${RED}No $wallet_type wallets available.${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Select a $wallet_type wallet:${NC}"
    read -p "Enter the number (1-${#wallet_list[@]}): " selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#wallet_list[@]} ]; then
        echo -e "${RED}Invalid selection.${NC}"
        return 1
    fi
    
    selected_index=$((selection - 1))
    selected_wallet="${wallet_list[$selected_index]}"
    
    echo -e "${GREEN}Selected: $selected_wallet${NC}"
    echo "$selected_wallet"
}

# Function to check if primal transaction comes from UPLANETG1PUB
check_primal_source() {
    local pubkey="$1"
    local primal_source=""
    
    # Get primal transaction source
    primal_source=$(silkaj money primal "$pubkey" 2>/dev/null | grep "comes from:" | cut -d ':' -f 2 | xargs)
    
    if [[ -n "$primal_source" ]]; then
        # Check if it comes from UPLANETG1PUB
        if [[ "$primal_source" == "$UPLANETG1PUB" ]]; then
            echo "UPLANET"
        else
            echo "EXTERNAL"
        fi
    else
        echo "NONE"
    fi
}

# Function to get user status details
get_user_status() {
    local user_email="$1"
    
    local status_info=""
    
    # Check if user has MULTIPASS
    if [[ -f ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
        status_info="${status_info}${GREEN}✓ MULTIPASS${NC}"
    else
        status_info="${status_info}${RED}✗ MULTIPASS${NC}"
    fi
    
    # Check if user has ZenCard
    if [[ -f ~/.zen/game/players/${user_email}/.g1pub ]]; then
        status_info="${status_info} | ${GREEN}✓ ZenCard${NC}"
    else
        status_info="${status_info} | ${RED}✗ ZenCard${NC}"
    fi
    
    # Check if user is a sociétaire
    if [[ -s ~/.zen/game/players/${user_email}/U.SOCIETY ]] || [[ "${user_email}" == "${CAPTAINEMAIL}" ]]; then
        status_info="${status_info} | ${GREEN}✓ Sociétaire${NC}"
    else
        status_info="${status_info} | ${YELLOW}⚠ Locataire${NC}"
    fi
    
    # Check if user is captain
    if [[ "${user_email}" == "${CAPTAINEMAIL}" ]]; then
        status_info="${status_info} | ${PURPLE}👑 Capitaine${NC}"
    fi
    
    echo "$status_info"
}

# Function to get system wallet public key (read-only operations)
get_system_wallet_public_key() {
    local wallet_type="$1"
    
    local keyfile=""
    case "$wallet_type" in
        "UPLANETNAME.G1")
            keyfile="$HOME/.zen/tmp/UPLANETNAME_G1"
            ;;
        "UPLANETNAME")
            keyfile="$HOME/.zen/tmp/UPLANETG1PUB"
            ;;
        "UPLANETNAME.SOCIETY")
            keyfile="$HOME/.zen/tmp/UPLANETNAME_SOCIETY"
            ;;
    esac
    
    # Check if keyfile exists
    if [[ ! -f "$keyfile" ]]; then
        echo -e "${RED}Public key file not found: $keyfile${NC}"
        return 1
    fi
    
    # Read and validate public key from keyfile
    local pubkey=$(cat "$keyfile" 2>/dev/null)
    if [[ -z "$pubkey" ]]; then
        echo -e "${RED}Could not read public key from $keyfile${NC}"
        return 1
    fi
    
    # Validate public key format
    if ! is_valid_public_key "$pubkey"; then
        echo -e "${RED}Invalid public key format in $keyfile${NC}"
        return 1
    fi
    
    echo "$pubkey"
}

# Function to get or create system wallet private key
get_system_wallet_private_key() {
    local wallet_type="$1"
    local wallet_name="$2"
    
    local dunikey_file=""
    case "$wallet_type" in
        "UPLANETNAME.G1")
            dunikey_file="$HOME/.zen/tmp/UPLANETNAME_G1.dunikey"
            ;;
        "UPLANETNAME")
            dunikey_file="$HOME/.zen/tmp/UPLANETNAME.dunikey"
            ;;
        "UPLANETNAME.SOCIETY")
            dunikey_file="$HOME/.zen/tmp/UPLANETNAME_SOCIETY.dunikey"
            ;;
    esac
    
    # Create dunikey file if it doesn't exist
    if [[ ! -f "$dunikey_file" ]]; then
        echo -e "${YELLOW}Creating private key for $wallet_type...${NC}"
        ${MY_PATH}/keygen -t duniter -o "$dunikey_file" "$wallet_name" "$wallet_name"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Failed to create private key for $wallet_type${NC}"
            return 1
        fi
    fi
    
    # Verify dunikey file contains both pub: and sec: keys
    if ! grep -q "pub:" "$dunikey_file" || ! grep -q "sec:" "$dunikey_file"; then
        echo -e "${RED}Invalid dunikey file format: $dunikey_file${NC}"
        return 1
    fi
    
    echo "$dunikey_file"
}

# Function to display system wallet information
# Note: Ẑen calculation excludes the primal transaction (1 Ğ1)
# Display: ZEN = (COINS - 1) * 10
# Send: G1 = Ẑen / 10 (no +1 needed as we're sending from existing balance)
display_system_wallet_info() {
    local wallet_type="$1"
    local source_pubkey="$2"
    
    echo -e "\n${CYAN}🏦 SYSTEM WALLET INFORMATION${NC}"
    echo -e "${YELLOW}============================${NC}"
    
        if [[ -n "$source_pubkey" ]]; then
        # Get wallet status with optimized cache usage
        local status=$(get_wallet_status "$source_pubkey" "$wallet_type")
        local balance=$(echo "$status" | cut -d '|' -f 1)
        local has_primal=$(echo "$status" | cut -d '|' -f 2)
        local zen_balance=$(echo "$status" | cut -d '|' -f 3)
            
            echo -e "${BLUE}Wallet Type:${NC} $wallet_type"
            echo -e "${BLUE}Public Key:${NC} ${CYAN}$source_pubkey${NC}"
            
            # Display balance in correct unit
            case "$wallet_type" in
                "UPLANETNAME.G1")
                echo -e "${BLUE}Balance:${NC} ${YELLOW}$balance Ğ1${NC}"
                    ;;
                "UPLANETNAME"|"UPLANETNAME.SOCIETY")
                echo -e "${BLUE}Balance:${NC} ${YELLOW}$balance Ğ1${NC} (${CYAN}$zen_balance Ẑen${NC})"
                    ;;
            esac
            
        # Display status
        if [[ "$has_primal" == "true" ]]; then
                echo -e "${BLUE}Status:${NC} ${GREEN}✓ Active${NC}"
            else
                echo -e "${BLUE}Status:${NC} ${RED}✗ Inactive${NC}"
            fi
        else
        echo -e "${RED}Invalid public key provided${NC}"
    fi
    echo ""
}

# Function to validate transaction security
validate_transaction_security() {
    local source_pubkey="$1"
    local dest_pubkey="$2"
    local amount="$3"
    
    # Validate public keys
    if ! is_valid_public_key "$source_pubkey"; then
        echo -e "${RED}Invalid source public key format${NC}"
        return 1
    fi
    
    if ! is_valid_public_key "$dest_pubkey"; then
        echo -e "${RED}Invalid destination public key format${NC}"
        return 1
    fi
    
    # Check if source and destination are different
    if [[ "$source_pubkey" == "$dest_pubkey" ]]; then
        echo -e "${RED}Cannot send to the same wallet${NC}"
        return 1
    fi
    
    # Validate amount
    if ! [[ "$amount" =~ ^[0-9]+([.][0-9]+)?$ ]] || (( $(echo "$amount <= 0" | bc -l) )); then
        echo -e "${RED}Invalid amount: must be a positive number${NC}"
        return 1
    fi
    
    # Check source balance
    local source_balance=$(get_wallet_balance "$source_pubkey")
    if (( $(echo "$source_balance < $amount" | bc -l) )); then
        echo -e "${RED}Insufficient balance: $source_balance Ğ1 available, $amount Ğ1 required${NC}"
        return 1
    fi
    
    return 0
}

# Function to execute system wallet transaction
execute_system_transaction() {
    local source_wallet_type="$1"
    local dest_pubkey="$2"
    local amount="$3"
    local comment="$4"
    
    echo -e "\n${CYAN}🚀 EXECUTING SYSTEM TRANSACTION${NC}"
    echo -e "${YELLOW}==============================${NC}"
    
    # Get source wallet public key
    local source_pubkey=$(get_system_wallet_public_key "$source_wallet_type")
    if [[ -z "$source_pubkey" ]]; then
        echo -e "${RED}Failed to get source wallet public key${NC}"
        return 1
    fi
    
    # Validate transaction
    if ! validate_transaction_security "$source_pubkey" "$dest_pubkey" "$amount"; then
        echo -e "${RED}Transaction validation failed${NC}"
        return 1
    fi
    
    # Get source wallet private key
    local source_wallet_name=""
    case "$source_wallet_type" in
        "UPLANETNAME.G1")
            source_wallet_name="${UPLANETNAME}.G1"
            ;;
        "UPLANETNAME")
            source_wallet_name="${UPLANETNAME}"
            ;;
        "UPLANETNAME.SOCIETY")
            source_wallet_name="${UPLANETNAME}.SOCIETY"
            ;;
    esac
    
    local dunikey_file=$(get_system_wallet_private_key "$source_wallet_type" "$source_wallet_name")
    if [[ -z "$dunikey_file" ]]; then
        echo -e "${RED}Failed to get source wallet private key${NC}"
        return 1
    fi
    
    # Execute transaction using PAYforSURE.sh
    echo -e "${GREEN}Executing transaction with PAYforSURE.sh...${NC}"
    echo -e "${BLUE}From:${NC} $source_wallet_type (${CYAN}${source_pubkey:0:8}...${NC})"
    echo -e "${BLUE}To:${NC} ${CYAN}${dest_pubkey:0:8}...${NC}"
    echo -e "${BLUE}Amount:${NC} ${YELLOW}$amount Ğ1${NC}"
    
    if [[ -n "$comment" ]]; then
        echo -e "${BLUE}Comment:${NC} $comment"
    fi
    
    # Execute the transaction
    if ${MY_PATH}/PAYforSURE.sh "$dunikey_file" "$amount" "$dest_pubkey" "$comment"; then
        echo -e "\n${GREEN}✅ Transaction successful!${NC}"
        echo -e "${GREEN}System wallet transaction completed successfully.${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Transaction failed!${NC}"
        echo -e "${RED}Please check the error messages above.${NC}"
        return 1
    fi
}

# Function to validate economic flow
validate_economic_flow() {
    local wallet_type="$1"
    local dest_pubkey="$2"
    local amount="$3"
    
    echo -e "\n${CYAN}🔍 VALIDATING ECONOMIC FLOW${NC}"
    echo -e "${YELLOW}==========================${NC}"
    
    # Check destination wallet status
    dest_balance=$(get_wallet_balance "$dest_pubkey")
    
    dest_primal=$(get_primal_info "$dest_pubkey")
    
    case "$wallet_type" in
        "UPLANETNAME.G1")
            echo -e "${BLUE}Flow:${NC} External donations → Reserve management"
            if [[ -n "$dest_primal" ]]; then
                echo -e "${GREEN}✓ Destination has primal transaction${NC}"
            else
                echo -e "${YELLOW}⚠ Destination has no primal transaction${NC}"
            fi
            ;;
        "UPLANETNAME")
            echo -e "${BLUE}Flow:${NC} Service payments → MULTIPASS wallet operations"
            # Check if destination is a MULTIPASS wallet
            if ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | xargs grep -l "$dest_pubkey" >/dev/null; then
                echo -e "${GREEN}✓ Destination is a valid MULTIPASS wallet${NC}"
            else
                echo -e "${YELLOW}⚠ Destination is not a registered MULTIPASS wallet${NC}"
            fi
            ;;
        "UPLANETNAME.SOCIETY")
            echo -e "${BLUE}Flow:${NC} Investment operations → ZenCard wallet management"
                            # Check if destination is a ZenCard wallet
                if ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | xargs grep -l "$dest_pubkey" >/dev/null; then
                    echo -e "${GREEN}✓ Destination is a valid ZenCard wallet${NC}"
                    # Check if user is a sociétaire
                    societaire_email=$(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | xargs grep -l "$dest_pubkey" | rev | cut -d '/' -f 2 | rev)
                    if [[ -s ~/.zen/game/players/${societaire_email}/U.SOCIETY ]] || [[ "${societaire_email}" == "${CAPTAINEMAIL}" ]]; then
                        echo -e "${GREEN}✓ Destination user is a sociétaire${NC}"
                    else
                        echo -e "${YELLOW}⚠ Destination user is a locataire${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠ Destination is not a registered ZenCard wallet${NC}"
                fi
            ;;
    esac
    
    echo -e "${BLUE}Destination Balance:${NC} ${YELLOW}$dest_balance Ğ1${NC}"
    echo ""
}

# Function to get transaction details
get_transaction_details() {
    local wallet_type="$1"
    local target_wallet="$2"
    
    echo -e "\n${CYAN}📝 TRANSACTION DETAILS${NC}"
    echo -e "${YELLOW}=====================${NC}"
    
    # Get system wallet public key for display
    local source_pubkey=$(get_system_wallet_public_key "$wallet_type")
    if [[ -z "$source_pubkey" ]]; then
        echo -e "${RED}Failed to get system wallet public key for $wallet_type${NC}"
        exit 1
    fi
    
    # Display system wallet information
    display_system_wallet_info "$wallet_type" "$source_pubkey"
    
    # Get amount with correct unit
    local unit=""
    case "$wallet_type" in
        "UPLANETNAME.G1")
            unit="Ğ1"
            ;;
        "UPLANETNAME"|"UPLANETNAME.SOCIETY")
            unit="Ẑen"
            ;;
    esac
    
    while true; do
        read -p "Enter amount to transfer (in $unit): " amount
        if [[ -n "$amount" ]] && [[ $amount =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            # Convert Ẑen to Ğ1 for UPLANETNAME and UPLANETNAME.SOCIETY
            # Note: Ẑen / 10 = Ğ1 (excluding primal transaction)
            if [[ "$wallet_type" != "UPLANETNAME.G1" ]]; then
                g1_amount=$(echo "scale=2; ($amount / 10)" | bc -l)
                echo -e "${CYAN}Converting $amount $unit to $g1_amount Ğ1 for transaction${NC}"
                amount="$g1_amount"
            fi
            break
        else
            echo -e "${RED}Please enter a valid amount (e.g., 10.5)${NC}"
        fi
    done
    
    # Get destination public key
    local dest_pubkey=""
    if [[ "$target_wallet" == "UPLANETNAME" ]]; then
        # Send to UPLANETNAME wallet
        dest_pubkey=$(get_system_wallet_public_key "UPLANETNAME")
        if [[ -z "$dest_pubkey" ]]; then
            echo -e "${RED}UPLANETNAME wallet not configured${NC}"
            exit 1
        fi
        echo -e "${GREEN}Destination: UPLANETNAME (Services & Cash-Flow)${NC}"
    elif [[ "$target_wallet" == "UPLANETNAME.SOCIETY" ]]; then
        # Send to UPLANETNAME.SOCIETY wallet
        dest_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY")
        if [[ -z "$dest_pubkey" ]]; then
            echo -e "${RED}UPLANETNAME.SOCIETY wallet not configured${NC}"
            exit 1
        fi
        echo -e "${GREEN}Destination: UPLANETNAME.SOCIETY (Social Capital)${NC}"
    else
        # External wallet - prompt for public key
    while true; do
        read -p "Enter destination public key: " dest_pubkey
        if [[ -n "$dest_pubkey" ]]; then
                # Validate public key format
                if is_valid_public_key "$dest_pubkey"; then
            # Test the public key with g1_to_ipfs.py
            if ${MY_PATH}/g1_to_ipfs.py "$dest_pubkey" >/dev/null 2>&1; then
                break
            else
                echo -e "${RED}Please enter a valid G1 public key${NC}"
                    fi
                else
                    echo -e "${RED}Invalid public key format${NC}"
            fi
        else
            echo -e "${RED}Please enter a valid public key${NC}"
        fi
    done
    fi
    
    # Validate transaction security
    if ! validate_transaction_security "$source_pubkey" "$dest_pubkey" "$amount"; then
        echo -e "${RED}Transaction validation failed. Please check the errors above.${NC}"
        exit 1
    fi
    
    # Validate economic flow
    validate_economic_flow "$wallet_type" "$dest_pubkey" "$amount"
    
    # Get optional comment
    read -p "Enter comment (optional): " comment
    
    # Determine transaction type based on wallet type
    case "$wallet_type" in
        "UPLANETNAME.G1")
            transaction_type="Ğ1 Reserve Management"
            ;;
        "UPLANETNAME")
            transaction_type="Service Operation → MULTIPASS"
            ;;
        "UPLANETNAME.SOCIETY")
            transaction_type="Investment Operation → ZenCard"
            ;;
    esac
    
    # Show flowchart position
    show_flowchart_position "$wallet_type" "$transaction_type"
    
    # Display comprehensive transaction summary
    echo -e "${CYAN}📋 COMPREHENSIVE TRANSACTION SUMMARY${NC}"
    echo -e "${YELLOW}====================================${NC}"
    
    # Get source wallet info
    source_balance=$(get_wallet_balance "$source_pubkey")
    
    # Get destination wallet info
    dest_balance=$(get_wallet_balance "$dest_pubkey")
    
    echo -e "${BLUE}From:${NC} $wallet_type"
    echo -e "${BLUE}Source Public Key:${NC} ${CYAN}$source_pubkey${NC}"
    echo -e "${BLUE}Source Balance:${NC} ${YELLOW}$source_balance Ğ1${NC}"
    echo -e "${BLUE}To:${NC} $dest_pubkey"
    echo -e "${BLUE}Destination Balance:${NC} ${YELLOW}$dest_balance Ğ1${NC}"
    # Display amount in correct unit
    case "$wallet_type" in
        "UPLANETNAME.G1")
            echo -e "${BLUE}Amount:${NC} $amount Ğ1"
            ;;
        "UPLANETNAME"|"UPLANETNAME.SOCIETY")
            zen_amount=$(echo "$amount * 10" | bc | cut -d '.' -f 1)
            echo -e "${BLUE}Amount:${NC} $amount Ğ1 (${CYAN}$zen_amount Ẑen${NC})"
            ;;
    esac
    
    if [[ -n "$comment" ]]; then
        echo -e "${BLUE}Comment:${NC} $comment"
    fi
    echo -e "${BLUE}Type:${NC} $transaction_type"
    
    # Calculate new balances
    new_source_balance=$(echo "$source_balance - $amount" | bc -l 2>/dev/null || echo "0")
    new_dest_balance=$(echo "$dest_balance + $amount" | bc -l 2>/dev/null || echo "0")
    
    echo ""
    echo -e "${CYAN}💰 BALANCE PROJECTION${NC}"
    echo -e "${YELLOW}====================${NC}"
    echo -e "${BLUE}Source Balance After:${NC} ${YELLOW}$new_source_balance Ğ1${NC}"
    echo -e "${BLUE}Destination Balance After:${NC} ${YELLOW}$new_dest_balance Ğ1${NC}"
    
    # Check if sufficient balance
    if (( $(echo "$source_balance < $amount" | bc -l) )); then
        echo -e "\n${RED}❌ INSUFFICIENT BALANCE${NC}"
        echo -e "${RED}Available: $source_balance Ğ1, Required: $amount Ğ1${NC}"
        echo -e "${RED}Transaction cannot proceed.${NC}"
        exit 1
    fi
    
    echo ""
    read -p "Confirm transaction? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Transaction cancelled.${NC}"
        exit 0
    fi
    
    # Execute system wallet transaction
    if execute_system_transaction "$wallet_type" "$dest_pubkey" "$amount" "$comment"; then
        echo -e "\n${GREEN}✅ Transaction successful!${NC}"
        echo -e "${GREEN}System wallet transaction completed successfully.${NC}"
    else
        echo -e "\n${RED}❌ Transaction failed!${NC}"
        echo -e "${RED}Please check the error messages above and try again.${NC}"
        exit 1
    fi
}

# Function to handle UPLANETNAME.G1 operations
handle_g1_reserve() {
    echo -e "\n${CYAN}🏛️  UPLANETNAME.G1 - Ğ1 RESERVE WALLET${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo -e "${GREEN}This wallet manages Ğ1 donations and reserves.${NC}"
    echo -e "${GREEN}Flow: External donations → Reserve management${NC}"
    
    show_flowchart_position "UPLANETNAME.G1" "Ğ1 Reserve Management"
    
    echo -e "\n${BLUE}TRANSACTION OPTIONS:${NC}"
    echo -e "  1. Send Ğ1 to UPLANETNAME (Services & Cash-Flow)"
    echo -e "  2. Send Ğ1 to UPLANETNAME.SOCIETY (Social Capital)"
    echo -e "  3. Send Ğ1 to external wallet"
    echo -e "  4. View wallet status only"
    
    read -p "Select option (1-4): " g1_choice
    
    case "$g1_choice" in
        1)
            # Send to UPLANETNAME
            local dest_pubkey=$(get_system_wallet_public_key "UPLANETNAME")
            if [[ -n "$dest_pubkey" ]]; then
                get_transaction_details "UPLANETNAME.G1" "UPLANETNAME"
            else
                echo -e "${RED}UPLANETNAME wallet not configured${NC}"
                exit 1
            fi
            ;;
        2)
            # Send to UPLANETNAME.SOCIETY
            local dest_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY")
            if [[ -n "$dest_pubkey" ]]; then
                get_transaction_details "UPLANETNAME.G1" "UPLANETNAME.SOCIETY"
            else
                echo -e "${RED}UPLANETNAME.SOCIETY wallet not configured${NC}"
                exit 1
            fi
            ;;
        3)
            # Send to external wallet
    get_transaction_details "UPLANETNAME.G1" ""
            ;;
        4)
            # View status only
            local source_pubkey=$(get_system_wallet_public_key "UPLANETNAME.G1")
            if [[ -n "$source_pubkey" ]]; then
                display_system_wallet_info "UPLANETNAME.G1" "$source_pubkey"
            else
                echo -e "${RED}UPLANETNAME.G1 wallet not configured${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Invalid selection. Please choose 1-4.${NC}"
            exit 1
            ;;
    esac
}

# Function to handle UPLANETNAME operations
handle_services() {
    echo -e "\n${CYAN}💼 UPLANETNAME - SERVICES & CASH-FLOW WALLET${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${GREEN}This wallet handles service operations and MULTIPASS transactions.${NC}"
    echo -e "${GREEN}Flow: Service payments → MULTIPASS wallet operations${NC}"
    
    show_flowchart_position "UPLANETNAME" "Service Operation → MULTIPASS"
    
    # List available MULTIPASS wallets
    if list_multipass_wallets; then
        multipass_wallets=($(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        selected_multipass=$(select_wallet "MULTIPASS" "${multipass_wallets[@]}")
        
        if [[ -n "$selected_multipass" ]]; then
            get_transaction_details "UPLANETNAME" "$selected_multipass"
        fi
    else
        echo -e "${RED}No MULTIPASS wallets available for transaction.${NC}"
        exit 1
    fi
}

# Function to handle wallet analysis and advanced features
handle_wallet_analysis() {
    echo -e "\n${CYAN}🔍 WALLET DETAILS & ANALYSIS${NC}"
    echo -e "${YELLOW}============================${NC}"
    echo -e "${GREEN}Advanced wallet analysis and reporting features.${NC}"
    
    # List available wallets for analysis
    echo -e "\n${BLUE}📋 AVAILABLE WALLETS FOR ANALYSIS:${NC}"
    
    # MULTIPASS wallets
    if [[ -d ~/.zen/game/nostr ]]; then
        account_names=($(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        if [[ ${#account_names[@]} -gt 0 ]]; then
            echo -e "\n${CYAN}MULTIPASS WALLETS:${NC}"
            for i in "${!account_names[@]}"; do
                echo -e "  ${GREEN}$((i+1)))${NC} ${account_names[i]}"
            done
        fi
    fi
    
    # ZenCard wallets
    if [[ -d ~/.zen/game/players ]]; then
        player_dirs=($(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        if [[ ${#player_dirs[@]} -gt 0 ]]; then
            echo -e "\n${CYAN}ZENCARD WALLETS:${NC}"
            for i in "${!player_dirs[@]}"; do
                echo -e "  ${GREEN}$((i+1+${#account_names[@]}))${NC} ${player_dirs[i]}"
            done
        fi
    fi
    
    # System wallets
    echo -e "\n${CYAN}SYSTEM WALLETS:${NC}"
    echo -e "  ${GREEN}$((1+${#account_names[@]}+${#player_dirs[@]}))${NC} UPLANETNAME.G1 (Ğ1 Reserve)"
    echo -e "  ${GREEN}$((2+${#account_names[@]}+${#player_dirs[@]}))${NC} UPLANETNAME (Services & Cash-Flow)"
    echo -e "  ${GREEN}$((3+${#account_names[@]}+${#player_dirs[@]}))${NC} UPLANETNAME.SOCIETY (Social Capital)"
    
    # Get wallet selection
    echo -e "\n${YELLOW}Select wallet to analyze (1-$((3+${#account_names[@]}+${#player_dirs[@]}))):${NC}"
    read -p "Enter number: " wallet_choice
    
    # Determine selected wallet
    local selected_wallet=""
    local wallet_type=""
    local pubkey=""
    
    if [[ "$wallet_choice" -le "${#account_names[@]}" ]]; then
        # MULTIPASS wallet
        selected_wallet="${account_names[$((wallet_choice-1))]}"
        wallet_type="MULTIPASS"
        pubkey=$(cat ~/.zen/game/nostr/${selected_wallet}/G1PUBNOSTR 2>/dev/null)
    elif [[ "$wallet_choice" -le $((${#account_names[@]}+${#player_dirs[@]})) ]]; then
        # ZenCard wallet
        selected_wallet="${player_dirs[$((wallet_choice-1-${#account_names[@]}))]}"
        wallet_type="ZenCard"
        pubkey=$(cat ~/.zen/game/players/${selected_wallet}/.g1pub 2>/dev/null)
    elif [[ "$wallet_choice" -eq $((1+${#account_names[@]}+${#player_dirs[@]})) ]]; then
        # UPLANETNAME.G1
        selected_wallet="UPLANETNAME.G1"
        wallet_type="SYSTEM"
        pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1" 2>/dev/null)
    elif [[ "$wallet_choice" -eq $((2+${#account_names[@]}+${#player_dirs[@]})) ]]; then
        # UPLANETNAME
        selected_wallet="UPLANETNAME"
        wallet_type="SYSTEM"
        pubkey=$(cat "$HOME/.zen/tmp/UPLANETG1PUB" 2>/dev/null)
    elif [[ "$wallet_choice" -eq $((3+${#account_names[@]}+${#player_dirs[@]})) ]]; then
        # UPLANETNAME.SOCIETY
        selected_wallet="UPLANETNAME.SOCIETY"
        wallet_type="SYSTEM"
        pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" 2>/dev/null)
    else
        echo -e "${RED}Invalid selection.${NC}"
        exit 1
    fi
    
    if [[ -z "$pubkey" ]]; then
        echo -e "${RED}Could not retrieve public key for selected wallet.${NC}"
        exit 1
    fi
    
    # Show analysis menu
    show_analysis_menu "$selected_wallet" "$wallet_type" "$pubkey"
}

# Function to show analysis menu for a specific wallet
show_analysis_menu() {
    local wallet_name="$1"
    local wallet_type="$2"
    local pubkey="$3"
    
    echo -e "\n${CYAN}🔍 ANALYSIS MENU - $wallet_type: $wallet_name${NC}"
    echo -e "${YELLOW}===============================================${NC}"
    echo -e "${GREEN}Public Key: ${CYAN}$pubkey${NC}"
    
    # Get wallet status with optimized cache usage
    local status=$(get_wallet_status "$pubkey" "$wallet_type")
    balance=$(echo "$status" | cut -d '|' -f 1)
    ZEN=$(echo "$status" | cut -d '|' -f 3)
    
    # Display balance
    if [[ "$wallet_type" != "UPLANETNAME.G1" ]] && [[ -n "$ZEN" ]] && [[ "$ZEN" != "0" ]]; then
        echo -e "${GREEN}Balance: ${YELLOW}$balance Ğ1${NC} (${CYAN}$ZEN Ẑen${NC})"
    else
        echo -e "${GREEN}Balance: ${YELLOW}$balance Ğ1${NC}"
    fi
    
    echo -e "\n${BLUE}ANALYSIS OPTIONS:${NC}"
    echo -e "  1. 📊 View Transaction History"
    echo -e "  2. 🔗 View Primal Chain Analysis"
    echo -e "  3. 📈 Generate Accounting Report"
    echo -e "  4. 🔍 Search Primal Chain"
    echo -e "  5. 📋 Export History to CSV"
    echo -e "  6. 🔙 Back to Main Menu"
    
    read -p "Select option (1-6): " analysis_choice
    
    case "$analysis_choice" in
        1)
            show_transaction_history "$pubkey" "$wallet_name"
            ;;
        2)
            show_primal_chain "$pubkey" "$wallet_name"
            ;;
        3)
            generate_accounting_report "$pubkey" "$wallet_name"
            ;;
        4)
            search_primal_chain "$pubkey" "$wallet_name"
            ;;
        5)
            export_history_csv "$pubkey" "$wallet_name"
            ;;
        6)
            echo -e "${GREEN}Returning to main menu...${NC}"
            main "$@"
            ;;
        *)
            echo -e "${RED}Invalid selection. Please choose 1-6.${NC}"
            show_analysis_menu "$wallet_name" "$wallet_type" "$pubkey"
            ;;
    esac
}

# Function to show transaction history
show_transaction_history() {
    local pubkey="$1"
    local wallet_name="$2"
    
    echo -e "\n${CYAN}📊 TRANSACTION HISTORY - $wallet_name${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # Show recent transactions
    echo -e "${GREEN}Recent transactions:${NC}"
    silkaj money history "$pubkey" | head -20
    
    echo -e "\n${YELLOW}Options:${NC}"
    echo -e "  1. View full history"
    echo -e "  2. View with UIDs"
    echo -e "  3. View with full public keys"
    echo -e "  4. Back to analysis menu"
    
    read -p "Select option (1-4): " history_choice
    
    case "$history_choice" in
        1)
            silkaj money history "$pubkey"
            ;;
        2)
            silkaj money history --uids "$pubkey"
            ;;
        3)
            silkaj money history --full-pubkey "$pubkey"
            ;;
        4)
            show_analysis_menu "$wallet_name" "$wallet_type" "$pubkey"
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            ;;
    esac
}

# Function to show primal chain analysis
show_primal_chain() {
    local pubkey="$1"
    local wallet_name="$2"
    
    echo -e "\n${CYAN}🔗 PRIMAL CHAIN ANALYSIS - $wallet_name${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # Show primal transaction source
    echo -e "${GREEN}Primal transaction source:${NC}"
    silkaj money primal "$pubkey"
    
    echo -e "\n${YELLOW}Options:${NC}"
    echo -e "  1. Follow primal chain (recursive)"
    echo -e "  2. Follow primal chain (limited to 10)"
    echo -e "  3. Back to analysis menu"
    
    read -p "Select option (1-3): " primal_choice
    
    case "$primal_choice" in
        1)
            silkaj money primal --chain "$pubkey"
            ;;
        2)
            silkaj money primal --chain --limit 10 "$pubkey"
            ;;
        3)
            show_analysis_menu "$wallet_name" "$wallet_type" "$pubkey"
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            ;;
    esac
}

# Function to generate accounting report
generate_accounting_report() {
    local pubkey="$1"
    local wallet_name="$2"
    
    echo -e "\n${CYAN}📈 ACCOUNTING REPORT - $wallet_name${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    echo -e "${GREEN}Generate accounting report for:${NC}"
    echo -e "  1. Current year"
    echo -e "  2. Previous year"
    echo -e "  3. Current month"
    echo -e "  4. Custom period"
    echo -e "  5. Back to analysis menu"
    
    read -p "Select option (1-5): " report_choice
    
    case "$report_choice" in
        1)
            current_year=$(date +%Y)
            echo -e "${GREEN}Generating report for year $current_year...${NC}"
            silkaj money history --compta "$current_year" "$pubkey"
            ;;
        2)
            prev_year=$(( $(date +%Y) - 1 ))
            echo -e "${GREEN}Generating report for year $prev_year...${NC}"
            silkaj money history --compta "$prev_year" "$pubkey"
            ;;
        3)
            current_month=$(date +%m-%Y)
            echo -e "${GREEN}Generating report for month $current_month...${NC}"
            silkaj money history --compta "$current_month" "$pubkey"
            ;;
        4)
            read -p "Enter period (e.g., '2024' for year, '03-2024' for month): " custom_period
            echo -e "${GREEN}Generating report for period $custom_period...${NC}"
            silkaj money history --compta "$custom_period" "$pubkey"
            ;;
        5)
            show_analysis_menu "$wallet_name" "$wallet_type" "$pubkey"
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            ;;
    esac
}

# Function to search primal chain
search_primal_chain() {
    local pubkey="$1"
    local wallet_name="$2"
    
    echo -e "\n${CYAN}🔍 PRIMAL CHAIN SEARCH - $wallet_name${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    echo -e "${GREEN}Search options:${NC}"
    echo -e "  1. Follow chain until UPLANET source"
    echo -e "  2. Follow chain with custom limit"
    echo -e "  3. Back to analysis menu"
    
    read -p "Select option (1-3): " search_choice
    
    case "$search_choice" in
        1)
            echo -e "${GREEN}Following primal chain until UPLANET source...${NC}"
            silkaj money primal --chain --limit 50 "$pubkey" | grep -i "uplanet\|$UPLANETG1PUB" || echo "No UPLANET source found in chain"
            ;;
        2)
            read -p "Enter limit (1-100): " limit
            if [[ "$limit" =~ ^[0-9]+$ ]] && [[ "$limit" -ge 1 ]] && [[ "$limit" -le 100 ]]; then
                silkaj money primal --chain --limit "$limit" "$pubkey"
            else
                echo -e "${RED}Invalid limit. Please enter a number between 1 and 100.${NC}"
            fi
            ;;
        3)
            show_analysis_menu "$wallet_name" "$wallet_type" "$pubkey"
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            ;;
    esac
}

# Function to export history to CSV
export_history_csv() {
    local pubkey="$1"
    local wallet_name="$2"
    
    echo -e "\n${CYAN}📋 EXPORT HISTORY TO CSV - $wallet_name${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # Create export directory
    export_dir="$HOME/.zen/exports"
    mkdir -p "$export_dir"
    
    # Generate filename
    timestamp=$(date +%Y%m%d_%H%M%S)
    filename="${export_dir}/${wallet_name}_history_${timestamp}.csv"
    
    echo -e "${GREEN}Exporting transaction history to: ${CYAN}$filename${NC}"
    
    # Export to CSV
    silkaj money history --csv-file "$filename" "$pubkey"
    
    if [[ -f "$filename" ]]; then
        echo -e "${GREEN}✅ Export successful!${NC}"
        echo -e "${GREEN}File: ${CYAN}$filename${NC}"
        echo -e "${GREEN}Size: ${CYAN}$(du -h "$filename" | cut -f1)${NC}"
    else
        echo -e "${RED}❌ Export failed.${NC}"
    fi
}

# Function to handle UPLANETNAME.SOCIETY operations
handle_social_capital() {
    echo -e "\n${CYAN}⭐ UPLANETNAME.SOCIETY - SOCIAL CAPITAL WALLET${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    echo -e "${GREEN}This wallet manages cooperative shares and ZenCard operations.${NC}"
    echo -e "${GREEN}Flow: Investment operations → ZenCard wallet management${NC}"
    
    show_flowchart_position "UPLANETNAME.SOCIETY" "Investment Operation → ZenCard"
    
    # List available ZenCard wallets
    if list_zencard_wallets; then
        zencard_wallets=($(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        selected_zencard=$(select_wallet "ZenCard" "${zencard_wallets[@]}")
        
        if [[ -n "$selected_zencard" ]]; then
            get_transaction_details "UPLANETNAME.SOCIETY" "$selected_zencard"
        fi
    else
        echo -e "${RED}No ZenCard wallets available for transaction.${NC}"
        exit 1
    fi
}

# Function to initialize system wallets
initialize_system_wallets() {
    echo -e "${YELLOW}Initializing system wallets...${NC}"
    
    # Initialize UPLANETNAME.G1
    get_system_wallet_key "UPLANETNAME.G1" "${UPLANETNAME}.G1" >/dev/null 2>&1
    
    # Initialize UPLANETNAME
    get_system_wallet_key "UPLANETNAME" "${UPLANETNAME}" >/dev/null 2>&1
    
    # Initialize UPLANETNAME.SOCIETY
    get_system_wallet_key "UPLANETNAME.SOCIETY" "${UPLANETNAME}.SOCIETY" >/dev/null 2>&1
    
    echo -e "${GREEN}System wallets initialized.${NC}"
}

# Function to display economic dashboard
display_economic_dashboard() {
    echo -e "\n${CYAN}📊 ECONOMIC DASHBOARD${NC}"
    echo -e "${YELLOW}====================${NC}"
    
    # System wallets info
    echo -e "${BLUE}🏛️  SYSTEM WALLETS:${NC}"
    
    # UPLANETNAME.G1
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1" 2>/dev/null)
        if [[ -n "$g1_pubkey" ]]; then
            g1_balance=$(get_wallet_balance "$g1_pubkey")
            echo -e "   • UPLANETNAME.G1: ${YELLOW}$g1_balance Ğ1${NC}"
        else
            echo -e "   • UPLANETNAME.G1: ${RED}Invalid keyfile${NC}"
        fi
    else
        echo -e "   • UPLANETNAME.G1: ${RED}Not configured${NC}"
    fi
    
    # UPLANETNAME
    if [[ -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        services_pubkey=$(cat "$HOME/.zen/tmp/UPLANETG1PUB" 2>/dev/null)
        if [[ -n "$services_pubkey" ]]; then
            local status=$(get_wallet_status "$services_pubkey" "UPLANETNAME")
            services_balance=$(echo "$status" | cut -d '|' -f 1)
            zen_balance=$(echo "$status" | cut -d '|' -f 3)
            echo -e "   • UPLANETNAME: ${YELLOW}$services_balance Ğ1${NC} (${CYAN}$zen_balance Ẑen${NC})"
        else
            echo -e "   • UPLANETNAME: ${RED}Invalid keyfile${NC}"
        fi
    else
        echo -e "   • UPLANETNAME: ${RED}Not configured${NC}"
    fi
    
    # UPLANETNAME.SOCIETY
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" ]]; then
        society_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" 2>/dev/null)
        if [[ -n "$society_pubkey" ]]; then
            local status=$(get_wallet_status "$society_pubkey" "UPLANETNAME.SOCIETY")
            society_balance=$(echo "$status" | cut -d '|' -f 1)
            zen_balance=$(echo "$status" | cut -d '|' -f 3)
            echo -e "   • UPLANETNAME.SOCIETY: ${YELLOW}$society_balance Ğ1${NC} (${CYAN}$zen_balance Ẑen${NC})"
        else
            echo -e "   • UPLANETNAME.SOCIETY: ${RED}Invalid keyfile${NC}"
        fi
    else
        echo -e "   • UPLANETNAME.SOCIETY: ${RED}Not configured${NC}"
    fi
    
    # User wallets summary
    echo -e "\n${BLUE}👥 USER WALLETS:${NC}"
    
    # Count MULTIPASS wallets
    multipass_count=$(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | wc -l)
    echo -e "   • MULTIPASS wallets: ${CYAN}$multipass_count${NC}"
    
    # Count ZenCard wallets
    zencard_count=$(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | wc -l)
    echo -e "   • ZenCard wallets: ${CYAN}$zencard_count${NC}"
    
    # Count sociétaires (users with U.SOCIETY file or captain)
    societaire_count=0
    societaire_list=()
    for player_dir in ~/.zen/game/players/*@*.*/; do
        if [[ -d "$player_dir" ]]; then
            player_name=$(basename "$player_dir")
            if [[ -s "${player_dir}U.SOCIETY" ]] || [[ "$player_name" == "$CAPTAINEMAIL" ]]; then
                ((societaire_count++))
                societaire_list+=("$player_name")
            fi
        fi
    done
    echo -e "   • Sociétaires: ${GREEN}$societaire_count${NC}"
    
    # Show sociétaires details if any
    if [[ ${#societaire_list[@]} -gt 0 ]]; then
        echo -e "     ${CYAN}List:${NC} ${societaire_list[*]}"
    fi
    
    # Show detailed user status if requested
    if [[ "$1" == "--detailed" ]]; then
        echo -e "\n${BLUE}👥 DETAILED USER STATUS:${NC}"
        for player_dir in ~/.zen/game/players/*@*.*/; do
            if [[ -d "$player_dir" ]]; then
                player_name=$(basename "$player_dir")
                echo -e "   • ${GREEN}$player_name${NC}: $(get_user_status "$player_name")"
            fi
        done
    fi
    
    # Show user wallet details with balances
    echo -e "\n${BLUE}💰 USER WALLET DETAILS:${NC}"
    
    # MULTIPASS wallets with balances
    if [[ -d ~/.zen/game/nostr ]]; then
        account_names=($(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        for account_name in "${account_names[@]}"; do
            g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
            if [[ -n "$g1pub" ]]; then
                # Get wallet status with optimized cache usage
                local status=$(get_wallet_status "$g1pub" "MULTIPASS")
                balance=$(echo "$status" | cut -d '|' -f 1)
                ZEN=$(echo "$status" | cut -d '|' -f 3)
                
                # Check primal transaction and its source
                primal_info=$(get_primal_info "$g1pub")
                if [[ -n "$primal_info" ]]; then
                    primal_source=$(check_primal_source "$g1pub")
                    case "$primal_source" in
                        "UPLANET")
                            primal_status="${GREEN}✓ Primal TX (UPLANET)${NC}"
                            ;;
                        "EXTERNAL")
                            primal_status="${YELLOW}✓ Primal TX (EXTERNAL)${NC}"
                            ;;
                        *)
                            primal_status="${GREEN}✓ Primal TX${NC}"
                            ;;
                    esac
                else
                    primal_status="${RED}✗ No Primal TX${NC}"
                fi
                
                echo -e "   • ${CYAN}MULTIPASS${NC} ${GREEN}$account_name${NC}: ${YELLOW}$balance Ğ1${NC} (${CYAN}$ZEN Ẑen${NC}) | $primal_status"
            fi
        done
    fi
    
    # ZenCard wallets with balances
    if [[ -d ~/.zen/game/players ]]; then
        player_dirs=($(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        for player_dir in "${player_dirs[@]}"; do
            g1pub=$(cat ~/.zen/game/players/${player_dir}/.g1pub 2>/dev/null)
            if [[ -n "$g1pub" ]]; then
                # Get wallet status with optimized cache usage
                local status=$(get_wallet_status "$g1pub" "ZenCard")
                balance=$(echo "$status" | cut -d '|' -f 1)
                ZEN=$(echo "$status" | cut -d '|' -f 3)
                
                # Check primal transaction and its source
                primal_info=$(get_primal_info "$g1pub")
                if [[ -n "$primal_info" ]]; then
                    primal_source=$(check_primal_source "$g1pub")
                    case "$primal_source" in
                        "UPLANET")
                            primal_status="${GREEN}✓ Primal TX (UPLANET)${NC}"
                            ;;
                        "EXTERNAL")
                            primal_status="${YELLOW}✓ Primal TX (EXTERNAL)${NC}"
                            ;;
                        *)
                            primal_status="${GREEN}✓ Primal TX${NC}"
                            ;;
                    esac
                else
                    primal_status="${RED}✗ No Primal TX${NC}"
                fi
                
                # Check sociétaire status
                if [[ -s ~/.zen/game/players/${player_dir}/U.SOCIETY ]] || [[ "${player_dir}" == "${CAPTAINEMAIL}" ]]; then
                    societaire_status="${GREEN}✓ Sociétaire${NC}"
                else
                    societaire_status="${YELLOW}⚠ Locataire${NC}"
                fi
                
                echo -e "   • ${CYAN}ZenCard${NC} ${GREEN}$player_dir${NC}: ${YELLOW}$balance Ğ1${NC} (${CYAN}$ZEN Ẑen${NC}) | $primal_status | $societaire_status"
            fi
        done
    fi
    
    echo -e "${YELLOW}====================${NC}\n"
}

# Function to handle maintenance and optimization
handle_maintenance() {
    echo -e "\n${CYAN}🛠️  MAINTENANCE & OPTIMIZATION${NC}"
    echo -e "${YELLOW}=============================${NC}"
    echo -e "${GREEN}System maintenance and optimization tools.${NC}"
    
    echo -e "\n${BLUE}MAINTENANCE OPTIONS:${NC}"
    echo -e "  1. 🔄 Refresh all wallet balances"
    echo -e "  2. 🧹 Clean old cache files"
    echo -e "  3. 🔍 System health check"
    echo -e "  4. 🔙 Back to Main Menu"
    
    read -p "Select option (1-4): " maintenance_choice
    
    case "$maintenance_choice" in
        1)
            refresh_all_balances
            ;;
        2)
            read -p "Enter cache age limit in hours (default: 24): " cache_age
            cache_age="${cache_age:-24}"
            clean_cache "$cache_age"
            ;;
        3)
            perform_system_health_check
            ;;
        4)
            echo -e "${GREEN}Returning to main menu...${NC}"
            main "$@"
            ;;
        *)
            echo -e "${RED}Invalid selection. Please choose 1-4.${NC}"
            handle_maintenance
            ;;
    esac
}

# Function to initialize system
initialize_system() {
    # Ensure cache directory exists
    ensure_cache_dir
    
    # Set script options for better performance
    set -o pipefail  # Exit on pipe failure
    shopt -s nullglob  # Handle empty globs gracefully
    shopt -s extglob  # Extended globbing for better pattern matching
}

# Function to perform system health check
perform_system_health_check() {
    echo -e "\n${CYAN}🔍 SYSTEM HEALTH CHECK${NC}"
    echo -e "${YELLOW}====================${NC}"
    
    local issues=0
    
    # Check cache directory
    if [[ ! -d "$CACHE_DIR" ]]; then
        echo -e "${RED}✗ Cache directory not found: $CACHE_DIR${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ Cache directory exists${NC}"
    fi
    
    # Check system wallet keyfiles
    local system_wallets=("UPLANETNAME_G1" "UPLANETG1PUB" "UPLANETNAME_SOCIETY")
    for wallet_file in "${system_wallets[@]}"; do
        local keyfile="$HOME/.zen/tmp/$wallet_file"
        if [[ -f "$keyfile" ]]; then
            local pubkey=$(cat "$keyfile" 2>/dev/null)
            if is_valid_public_key "$pubkey"; then
                echo -e "${GREEN}✓ $wallet_file: Valid public key${NC}"
            else
                echo -e "${RED}✗ $wallet_file: Invalid public key format${NC}"
                ((issues++))
            fi
        else
            echo -e "${YELLOW}⚠ $wallet_file: Not configured${NC}"
        fi
    done
    
    # Check required tools
    local required_tools=("silkaj" "bc" "jq")
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $tool: Available${NC}"
        else
            echo -e "${RED}✗ $tool: Not found${NC}"
            ((issues++))
        fi
    done
    
    # Check COINScheck.sh script
    if [[ -f "${MY_PATH}/COINScheck.sh" ]]; then
        echo -e "${GREEN}✓ COINScheck.sh: Available${NC}"
    else
        echo -e "${RED}✗ COINScheck.sh: Not found${NC}"
        ((issues++))
    fi
    
    # Summary
    echo -e "\n${CYAN}HEALTH CHECK SUMMARY:${NC}"
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✅ System is healthy (0 issues found)${NC}"
    else
        echo -e "${YELLOW}⚠ System has $issues issue(s) that should be addressed${NC}"
    fi
}

# Main script logic
main() {
    echo -e "${CYAN}🌟 ASTROPORT.ONE ZEN TRANSACTION MANAGER${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}Welcome, Captain! Choose your transaction type:${NC}"
    
    # Initialize system
    initialize_system
    
    # Check if UPLANETNAME is defined
    if [[ -z "$UPLANETNAME" ]]; then
        echo -e "${RED}❌ ERROR: UPLANETNAME is not defined!${NC}"
        echo -e "${YELLOW}Please ensure UPLANETNAME is set in your environment.${NC}"
        exit 1
    fi
    
    # Initialize system wallets
    initialize_system_wallets
    
    # Display economic dashboard
    display_economic_dashboard "$1"
    
    # Display wallet options
    echo -e "${BLUE}1. 🏛️  UPLANETNAME.G1${NC} - Ğ1 Reserve Wallet"
    echo -e "   • Manage Ğ1 donations and reserves"
    echo -e "   • External donations → Reserve management"
    echo ""
    
    echo -e "${BLUE}2. 💼 UPLANETNAME${NC} - Services & Cash-Flow Wallet"
    echo -e "   • Handle service operations and MULTIPASS transactions"
    echo -e "   • Service payments → MULTIPASS wallet operations"
    echo ""
    
    echo -e "${BLUE}3. ⭐ UPLANETNAME.SOCIETY${NC} - Social Capital Wallet"
    echo -e "   • Manage cooperative shares and ZenCard operations"
    echo -e "   • Investment operations → ZenCard wallet management"
    echo ""
    
    echo -e "${BLUE}4. 🔍 WALLET DETAILS & ANALYSIS${NC} - Advanced Features"
    echo -e "   • View transaction history and primal chain"
    echo -e "   • Generate accounting reports"
    echo -e "   • Analyze wallet activities"
    echo ""
    
    echo -e "${BLUE}5. 🛠️  MAINTENANCE & OPTIMIZATION${NC} - System Tools"
    echo -e "   • Refresh all wallet balances"
    echo -e "   • Clean old cache files"
    echo -e "   • System health check"
    echo ""
    
    # Get user selection
    read -p "Select option (1-5): " choice
    
    case "$choice" in
        1)
            handle_g1_reserve
            ;;
        2)
            handle_services
            ;;
        3)
            handle_social_capital
            ;;
        4)
            handle_wallet_analysis
            ;;
        5)
            handle_maintenance
            ;;
        *)
            echo -e "${RED}Invalid selection. Please choose 1, 2, 3, 4, or 5.${NC}"
            exit 1
            ;;
    esac
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@" 