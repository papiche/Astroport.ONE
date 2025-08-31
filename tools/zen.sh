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
ORANGE='\033[0;33m'
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
    
    # Check cache age (refresh if older than 5 minutes for performance)
    local cache_file="$CACHE_DIR/${pubkey}.COINS"
    local cache_age=0
    if [[ -f "$cache_file" ]]; then
        cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
    fi
    
    # Refresh cache if requested, pubkey is valid, and cache is old or missing
    if [[ "$auto_refresh" == "true" ]] && [[ -n "$pubkey" ]] && [[ $cache_age -gt 300 ]]; then
        ${MY_PATH}/G1check.sh "$pubkey" >/dev/null 2>&1
    fi
    
    # Get balance from cache
    local balance=$(cat "$cache_file" 2>/dev/null)
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
                ${MY_PATH}/G1check.sh "$pubkey" >/dev/null 2>&1
            fi
        fi
    done
    
    # Refresh MULTIPASS wallets
    if [[ -d ~/.zen/game/nostr ]]; then
        while IFS= read -r -d '' file; do
            local pubkey=$(cat "$file" 2>/dev/null)
            if [[ -n "$pubkey" ]]; then
                ${MY_PATH}/G1check.sh "$pubkey" >/dev/null 2>&1
            fi
        done < <(find ~/.zen/game/nostr -name "G1PUBNOSTR" -print0 2>/dev/null)
    fi
    
    # Refresh ZenCard wallets
    if [[ -d ~/.zen/game/players ]]; then
        while IFS= read -r -d '' file; do
            local pubkey=$(cat "$file" 2>/dev/null)
            if [[ -n "$pubkey" ]]; then
                ${MY_PATH}/G1check.sh "$pubkey" >/dev/null 2>&1
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
    echo -e "${YELLOW}🎯 GUIDE CAPITAINE - Gestionnaire de Transactions Zen${NC}"
    echo ""
    echo -e "${GREEN}Ce script vous permet de gérer l'économie UPlanet en toute sécurité:${NC}"
    echo ""
    echo -e "${BLUE}📊 TABLEAU DE BORD:${NC}"
    echo -e "   • Vision synthétique des utilisateurs et échéances"
    echo -e "   • Alertes automatiques pour les paiements en retard"
    echo -e "   • Suivi des revenus hebdomadaires"
    echo ""
    echo -e "${BLUE}💰 REPORTING OPENCOLLECTIVE:${NC}"
    echo -e "   • Identification automatique des paiements à reporter"
    echo -e "   • Instructions étape par étape pour OpenCollective"
    echo -e "   • Génération de rapports de suivi"
    echo ""
    echo -e "${BLUE}🏛️  PORTEFEUILLES SYSTÈME:${NC}"
    echo -e "   • UPLANETNAME.G1: Réserves et donations Ğ1"
    echo -e "   • UPLANETNAME: Services et MULTIPASS"
    echo -e "   • UPLANETNAME.SOCIETY: Capital social et ZenCard"
    echo ""
    echo -e "${GREEN}Options:${NC}"
    echo -e "  ${CYAN}--detailed${NC}  Affichage détaillé de tous les utilisateurs"
    echo ""
    echo -e "${YELLOW}⚠️  SÉCURITÉ:${NC}"
    echo -e "   • Validation automatique des transactions"
    echo -e "   • Vérification des chaînes primales"
    echo -e "   • Confirmations obligatoires pour les actions critiques"
    echo ""
    echo -e "${GREEN}Le script vous guidera pas à pas pour éviter toute erreur.${NC}"
    exit 1
}

# Function to display captain help and tips
show_captain_tips() {
    echo -e "\n${CYAN}💡 CONSEILS CAPITAINE${NC}"
    echo -e "${YELLOW}===================${NC}"
    echo -e "${GREEN}Bonnes pratiques pour une gestion sûre:${NC}"
    echo ""
    echo -e "${BLUE}1. VÉRIFICATIONS QUOTIDIENNES:${NC}"
    echo -e "   • Consulter le tableau de bord pour les paiements dus"
    echo -e "   • Vérifier les soldes des portefeuilles système"
    echo -e "   • Contrôler les nouvelles inscriptions"
    echo ""
    echo -e "${BLUE}2. REPORTING OPENCOLLECTIVE:${NC}"
    echo -e "   • Reporter les paiements reçus chaque semaine"
    echo -e "   • Conserver les fichiers de rapport générés"
    echo -e "   • Vérifier la cohérence avec les transactions blockchain"
    echo ""
    echo -e "${BLUE}3. GESTION DES SOCIÉTAIRES:${NC}"
    echo -e "   • Surveiller les dates d'expiration (alertes automatiques)"
    echo -e "   • Traiter les renouvellements via UPLANETNAME.SOCIETY"
    echo -e "   • Confirmer la création des fichiers U.SOCIETY"
    echo ""
    echo -e "${BLUE}4. SÉCURITÉ:${NC}"
    echo -e "   • Toujours vérifier les clés publiques avant transaction"
    echo -e "   • Confirmer les montants en Ẑen ET en Ğ1"
    echo -e "   • Sauvegarder les rapports de transaction"
    echo ""
    echo -e "${YELLOW}En cas de doute, utilisez l'option 'Analyse' pour vérifier les portefeuilles.${NC}"
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

# Function to create U.SOCIETY file for sociétaire
create_usociety_file() {
    local player_email="$1"
    local transaction_amount="$2"
    local zen_amount="$3"
    
    echo -e "\n${CYAN}⭐ CREATING U.SOCIETY FILE FOR SOCIÉTAIRE${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    # Check if player has ZenCard
    if [[ ! -d ~/.zen/game/players/${player_email} ]]; then
        echo -e "${RED}❌ ZenCard not found for ${player_email}${NC}"
        return 1
    fi
    
    # Determine subscription duration based on amount
    local subscription_type=""
    local duration_days=""
    
    # Convert Ğ1 amount to Ẑen for comparison (amount * 10)
    local total_zen=$(echo "$transaction_amount * 10" | bc | cut -d '.' -f 1)
    
    if [[ "$total_zen" -eq 50 ]]; then
        subscription_type="RPi Share (1 year)"
        duration_days=365
    elif [[ "$total_zen" -eq 540 ]]; then
        subscription_type="PC Share (3 years)"
        duration_days=1095
    else
        echo -e "${YELLOW}⚠ Custom amount: ${total_zen} Ẑen - Default 1 year subscription${NC}"
        subscription_type="Custom Share (1 year)"
        duration_days=365
    fi
    
    # Create U.SOCIETY file with current date
    local society_date="$TODATE"
    echo "$society_date" > ~/.zen/game/players/${player_email}/U.SOCIETY
    
    # Also create in NOSTR directory if exists (create symlink like u.command.sh)
    if [[ -d ~/.zen/game/nostr/${player_email} ]]; then
        ln -sf ~/.zen/game/players/${player_email}/U.SOCIETY ~/.zen/game/nostr/${player_email}/U.SOCIETY
    fi
    
    echo -e "${GREEN}✅ U.SOCIETY file created for ${player_email}${NC}"
    echo -e "${BLUE}Subscription Type:${NC} $subscription_type"
    echo -e "${BLUE}Start Date:${NC} $society_date"
    echo -e "${BLUE}Duration:${NC} $duration_days days"
    echo -e "${BLUE}Amount:${NC} ${YELLOW}$transaction_amount Ğ1${NC} (${CYAN}$total_zen Ẑen${NC})"
    
    # Send confirmation email
    local email_content="<html><head><meta charset='UTF-8'>
    <style>
        body { font-family: 'Courier New', monospace; }
        .header { color: #2E8B57; font-size: 24px; font-weight: bold; }
        .info { background-color: #f0f8ff; padding: 10px; margin: 10px 0; }
    </style></head><body>
    <div class='header'>🎉 Bienvenue dans la Coopérative UPlanet !</div>
    <div class='info'>
        <h3>Votre statut de Sociétaire est activé :</h3>
        <ul>
            <li><strong>Type :</strong> $subscription_type</li>
            <li><strong>Date d'activation :</strong> $society_date</li>
            <li><strong>Durée :</strong> $duration_days jours</li>
            <li><strong>Montant :</strong> $transaction_amount Ğ1 ($total_zen Ẑen)</li>
        </ul>
        <p><strong>Avantages :</strong></p>
        <ul>
            <li>✅ Exemption de loyer pendant la durée de votre souscription</li>
            <li>✅ Droit de vote dans la coopérative</li>
            <li>✅ Part de propriété sur les biens communs</li>
            <li>✅ Accès aux services sans frais supplémentaires</li>
        </ul>
        <p>Votre ZenCard est maintenant configurée en mode Sociétaire.</p>
        <p><a href='${myIPFS}/ipns/copylaradio.com'>Accéder à UPlanet</a></p>
    </div>
    </body></html>"
    
    echo "$email_content" > ~/.zen/tmp/usociety_welcome_${player_email//[@.]/_}.html
    ${MY_PATH}/mailjet.sh "${player_email}" ~/.zen/tmp/usociety_welcome_${player_email//[@.]/_}.html "🎉 Statut Sociétaire Activé - UPlanet Coopérative"
    
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
        
        # Special handling for UPLANETNAME.SOCIETY transactions (sociétaire creation)
        if [[ "$source_wallet_type" == "UPLANETNAME.SOCIETY" ]]; then
            # Find the player email from the destination pubkey
            local player_email=""
            if [[ -d ~/.zen/game/players ]]; then
                for player_dir in ~/.zen/game/players/*@*.*/; do
                    if [[ -d "$player_dir" ]]; then
                        local player_g1pub=$(cat "${player_dir}.g1pub" 2>/dev/null)
                        if [[ "$player_g1pub" == "$dest_pubkey" ]]; then
                            player_email=$(basename "$player_dir")
                            break
                        fi
                    fi
                done
            fi
            
            # Create U.SOCIETY file if player found
            if [[ -n "$player_email" ]]; then
                local zen_amount=$(echo "$amount * 10" | bc | cut -d '.' -f 1)
                create_usociety_file "$player_email" "$amount" "$zen_amount"
            else
                echo -e "${YELLOW}⚠ Could not identify player for U.SOCIETY creation${NC}"
            fi
        fi
        
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
    echo -e "${GREEN}Ce portefeuille gère les réserves Ğ1 et les donations externes.${NC}"
    echo -e "${GREEN}Flux: Donations externes → Gestion des réserves${NC}"
    
    show_flowchart_position "UPLANETNAME.G1" "Ğ1 Reserve Management"
    
    echo -e "\n${BLUE}OPTIONS DE TRANSACTION:${NC}"
    echo -e "  1. 💼 Alimenter UPLANETNAME (Services & Cash-Flow)"
    echo -e "  2. ⭐ Valoriser Capital Machine → UPLANETNAME.SOCIETY"
    echo -e "  3. 💰 Envoyer Ğ1 vers portefeuille externe"
    echo -e "  4. 📊 Voir le statut du portefeuille uniquement"
    echo -e "  5. 🚀 Assistant d'initialisation Astroport"
    echo -e "  6. 🔙 Retour au menu principal"
    
    read -p "Select option (1-6): " g1_choice
    
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
            # Valoriser Capital Machine
            handle_capital_valuation
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
        5)
            # Assistant d'initialisation
            handle_astroport_initialization
            ;;
        6)
            # Retour au menu principal
            echo -e "${GREEN}Retour au menu principal...${NC}"
            main "$@"
            ;;
        *)
            echo -e "${RED}Invalid selection. Please choose 1-6.${NC}"
            handle_g1_reserve
            ;;
    esac
}

# Function to handle capital machine valuation
handle_capital_valuation() {
    echo -e "\n${CYAN}⭐ VALORISATION DU CAPITAL MACHINE${NC}"
    echo -e "${YELLOW}=================================${NC}"
    echo -e "${GREEN}Valorisez l'apport en capital de votre machine dans la coopérative${NC}"
    
    echo -e "\n${BLUE}💻 TYPES DE MACHINES STANDARDS:${NC}"
    echo -e "  1. 🛰️  Satellite/RPi (500€ → 500 Ẑen)"
    echo -e "  2. 🎮 PC Gamer (4000€ → 4000 Ẑen)"
    echo -e "  3. 💼 Serveur Pro (8000€ → 8000 Ẑen)"
    echo -e "  4. 🔧 Valorisation personnalisée"
    
    read -p "Choisissez le type de machine (1-4): " machine_choice
    
    local machine_value=""
    local machine_type=""
    
    case "$machine_choice" in
        1)
            machine_value="500"
            machine_type="Satellite/RPi"
            ;;
        2)
            machine_value="4000"
            machine_type="PC Gamer"
            ;;
        3)
            machine_value="8000"
            machine_type="Serveur Pro"
            ;;
        4)
            echo -e "\n${YELLOW}Valorisation personnalisée:${NC}"
            read -p "Entrez la valeur en euros de votre machine: " custom_value
            if [[ "$custom_value" =~ ^[0-9]+$ ]] && [[ "$custom_value" -gt 0 ]]; then
                machine_value="$custom_value"
                machine_type="Machine personnalisée"
            else
                echo -e "${RED}Valeur invalide. Opération annulée.${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Sélection invalide.${NC}"
            return 1
            ;;
    esac
    
    # Convert euros to Ẑen (1€ = 1Ẑ) then to Ğ1 (1Ẑ = 0.1Ğ1)
    local zen_amount="$machine_value"
    local g1_amount=$(echo "scale=1; $zen_amount / 10" | bc)
    
    echo -e "\n${CYAN}📋 RÉCAPITULATIF DE LA VALORISATION:${NC}"
    echo -e "${BLUE}Type de machine:${NC} $machine_type"
    echo -e "${BLUE}Valeur:${NC} ${YELLOW}$machine_value €${NC} = ${CYAN}$zen_amount Ẑen${NC} = ${YELLOW}$g1_amount Ğ1${NC}"
    echo -e "\n${GREEN}Cette valorisation sera inscrite au capital social de la coopérative.${NC}"
    echo -e "${GREEN}Flux: UPLANETNAME.G1 → UPLANETNAME.SOCIETY → ZenCard Capitaine${NC}"
    
    read -p "Confirmer la valorisation? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Valorisation annulée.${NC}"
        return 0
    fi
    
    # Get UPLANETNAME.SOCIETY public key
    local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY")
    if [[ -z "$society_pubkey" ]]; then
        echo -e "${RED}UPLANETNAME.SOCIETY wallet not configured${NC}"
        return 1
    fi
    
    # Execute capital valuation transaction
    local comment="CAPITAL:MACHINE:$machine_type:$machine_value€"
    if execute_system_transaction "UPLANETNAME.G1" "$society_pubkey" "$g1_amount" "$comment"; then
        echo -e "\n${GREEN}✅ Valorisation du capital réussie!${NC}"
        echo -e "${GREEN}Votre machine ($machine_type) est maintenant inscrite au capital social.${NC}"
        
        # Update .env file with machine info
        update_env_machine_info "$machine_type" "$machine_value"
        
        return 0
    else
        echo -e "\n${RED}❌ Échec de la valorisation du capital${NC}"
        return 1
    fi
}

# Function to handle Astroport initialization
handle_astroport_initialization() {
    echo -e "\n${CYAN}🚀 ASSISTANT D'INITIALISATION ASTROPORT${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo -e "${GREEN}Cet assistant vous guide dans la configuration initiale de votre Astroport${NC}"
    
    echo -e "\n${BLUE}📋 ÉTAPES D'INITIALISATION:${NC}"
    echo -e "  1. ⚙️  Configuration des paramètres économiques (.env)"
    echo -e "  2. ⭐ Valorisation du capital machine"
    echo -e "  3. 💰 Initialisation des portefeuilles système"
    echo -e "  4. 📊 Vérification de la configuration"
    
    read -p "Commencer l'initialisation? (y/N): " start_init
    if [[ "$start_init" != "y" && "$start_init" != "Y" ]]; then
        echo -e "${YELLOW}Initialisation annulée.${NC}"
        return 0
    fi
    
    # Step 1: Configure economic parameters
    echo -e "\n${CYAN}⚙️  ÉTAPE 1: Configuration économique${NC}"
    configure_economic_parameters
    
    # Step 2: Machine valuation
    echo -e "\n${CYAN}⭐ ÉTAPE 2: Valorisation du capital${NC}"
    handle_capital_valuation
    
    # Step 3: Initialize system wallets
    echo -e "\n${CYAN}💰 ÉTAPE 3: Initialisation des portefeuilles${NC}"
    initialize_system_wallets_complete
    
    # Step 4: Verification
    echo -e "\n${CYAN}📊 ÉTAPE 4: Vérification${NC}"
    verify_astroport_configuration
    
    echo -e "\n${GREEN}🎉 Initialisation de l'Astroport terminée!${NC}"
    echo -e "${GREEN}Votre station est maintenant prête à accueillir des utilisateurs.${NC}"
}

# Function to configure economic parameters
configure_economic_parameters() {
    echo -e "\n${YELLOW}Configuration des paramètres économiques:${NC}"
    
    # Get current values or defaults
    local current_paf=$(grep "^PAF=" ~/.zen/Astroport.ONE/.env 2>/dev/null | cut -d '=' -f 2 || echo "14")
    local current_ncard=$(grep "^NCARD=" ~/.zen/Astroport.ONE/.env 2>/dev/null | cut -d '=' -f 2 || echo "1")
    local current_zcard=$(grep "^ZCARD=" ~/.zen/Astroport.ONE/.env 2>/dev/null | cut -d '=' -f 2 || echo "4")
    
    echo -e "${BLUE}Paramètres actuels:${NC}"
    echo -e "  • PAF (Participation Aux Frais hebdomadaire): ${CYAN}$current_paf Ẑen${NC}"
    echo -e "  • NCARD (MULTIPASS hebdomadaire): ${CYAN}$current_ncard Ẑen${NC}"
    echo -e "  • ZCARD (ZenCard hebdomadaire): ${CYAN}$current_zcard Ẑen${NC}"
    
    read -p "Modifier ces paramètres? (y/N): " modify_params
    if [[ "$modify_params" == "y" || "$modify_params" == "Y" ]]; then
        
        echo -e "\n${YELLOW}Nouveaux paramètres:${NC}"
        
        read -p "PAF hebdomadaire (Ẑen) [$current_paf]: " new_paf
        new_paf="${new_paf:-$current_paf}"
        
        read -p "NCARD hebdomadaire (Ẑen) [$current_ncard]: " new_ncard
        new_ncard="${new_ncard:-$current_ncard}"
        
        read -p "ZCARD hebdomadaire (Ẑen) [$current_zcard]: " new_zcard
        new_zcard="${new_zcard:-$current_zcard}"
        
        # Update .env file
        update_env_economic_params "$new_paf" "$new_ncard" "$new_zcard"
        
        echo -e "${GREEN}✅ Paramètres économiques mis à jour${NC}"
    else
        echo -e "${GREEN}✅ Paramètres économiques conservés${NC}"
    fi
}

# Function to update .env file with economic parameters
update_env_economic_params() {
    local paf="$1"
    local ncard="$2"
    local zcard="$3"
    
    local env_file="$HOME/.zen/Astroport.ONE/.env"
    
    # Create .env from template if it doesn't exist
    if [[ ! -f "$env_file" ]]; then
        cp "$HOME/.zen/Astroport.ONE/.env.template" "$env_file"
    fi
    
    # Update parameters
    sed -i "s/^PAF=.*/PAF=$paf/" "$env_file"
    sed -i "s/^NCARD=.*/NCARD=$ncard/" "$env_file"
    sed -i "s/^ZCARD=.*/ZCARD=$zcard/" "$env_file"
    
    echo -e "${GREEN}Fichier .env mis à jour: $env_file${NC}"
}

# Function to update .env file with machine info
update_env_machine_info() {
    local machine_type="$1"
    local machine_value="$2"
    
    local env_file="$HOME/.zen/Astroport.ONE/.env"
    
    # Add machine info section if not exists
    if ! grep -q "MACHINE_TYPE" "$env_file" 2>/dev/null; then
        echo "" >> "$env_file"
        echo "###################################" >> "$env_file"
        echo "## ASTROPORT MACHINE CONFIGURATION" >> "$env_file"
        echo "###################################" >> "$env_file"
        echo "MACHINE_TYPE=\"$machine_type\"" >> "$env_file"
        echo "MACHINE_VALUE=$machine_value" >> "$env_file"
        echo "CAPITAL_DATE=$(date +%Y%m%d%H%M%S)" >> "$env_file"
    else
        sed -i "s/^MACHINE_TYPE=.*/MACHINE_TYPE=\"$machine_type\"/" "$env_file"
        sed -i "s/^MACHINE_VALUE=.*/MACHINE_VALUE=$machine_value/" "$env_file"
    fi
}

# Function to initialize system wallets completely
initialize_system_wallets_complete() {
    echo -e "${YELLOW}Initialisation complète des portefeuilles système...${NC}"
    
    # Initialize all system wallets
    initialize_system_wallets
    
    # Display status
    echo -e "\n${BLUE}État des portefeuilles système:${NC}"
    
    # Check each wallet
    local wallets=("UPLANETNAME.G1" "UPLANETNAME" "UPLANETNAME.SOCIETY")
    for wallet in "${wallets[@]}"; do
        local pubkey=$(get_system_wallet_public_key "$wallet")
        if [[ -n "$pubkey" ]]; then
            local balance=$(get_wallet_balance "$pubkey")
            echo -e "  • ${GREEN}$wallet${NC}: ${CYAN}$pubkey${NC} (${YELLOW}$balance Ğ1${NC})"
        else
            echo -e "  • ${RED}$wallet${NC}: Non configuré"
        fi
    done
}

# Function to verify Astroport configuration
verify_astroport_configuration() {
    echo -e "${YELLOW}Vérification de la configuration...${NC}"
    
    local issues=0
    
    # Check .env file
    if [[ -f "$HOME/.zen/Astroport.ONE/.env" ]]; then
        echo -e "${GREEN}✓ Fichier .env configuré${NC}"
    else
        echo -e "${RED}✗ Fichier .env manquant${NC}"
        ((issues++))
    fi
    
    # Check system wallets
    local wallets=("UPLANETNAME.G1" "UPLANETNAME" "UPLANETNAME.SOCIETY")
    for wallet in "${wallets[@]}"; do
        local pubkey=$(get_system_wallet_public_key "$wallet")
        if [[ -n "$pubkey" ]]; then
            echo -e "${GREEN}✓ $wallet configuré${NC}"
        else
            echo -e "${RED}✗ $wallet non configuré${NC}"
            ((issues++))
        fi
    done
    
    # Summary
    if [[ $issues -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 Configuration complète et valide!${NC}"
        echo -e "${GREEN}Votre Astroport est prêt à fonctionner.${NC}"
    else
        echo -e "\n${YELLOW}⚠ Configuration incomplète ($issues problème(s))${NC}"
        echo -e "${YELLOW}Certains éléments nécessitent votre attention.${NC}"
    fi
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
    
    echo -e "\n${BLUE}OPTIONS D'ANALYSE:${NC}"
    echo -e "  1. 📊 Historique des transactions"
    echo -e "  2. 🔗 Analyse de la chaîne primale"
    echo -e "  3. 📈 Générer un rapport comptable"
    echo -e "  4. 🔍 Rechercher dans la chaîne primale"
    echo -e "  5. 📋 Exporter l'historique en CSV"
    echo -e "  6. 🔙 Retour au menu principal"
    
    read -p "Sélectionnez une option (1-6): " analysis_choice
    
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
            echo -e "${GREEN}Retour au menu principal...${NC}"
            main "$@"
            ;;
        *)
            echo -e "${RED}Sélection invalide. Veuillez choisir 1-6.${NC}"
            echo ""
            read -p "Appuyez sur Entrée pour réessayer..." 
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

# Function to get or create system wallet key  
get_system_wallet_key() {
    local wallet_type="$1"
    local wallet_name="$2"
    
    # Create the public key cache file path based on wallet type
    local pubkey_file=""
    case "$wallet_type" in
        "UPLANETNAME.G1")
            pubkey_file="$HOME/.zen/tmp/UPLANETNAME_G1"
            ;;
        "UPLANETNAME")
            pubkey_file="$HOME/.zen/tmp/UPLANETG1PUB"
            ;;
        "UPLANETNAME.SOCIETY")
            pubkey_file="$HOME/.zen/tmp/UPLANETNAME_SOCIETY"
            ;;
    esac
    
    # Check if public key file exists
    if [[ -f "$pubkey_file" ]]; then
        local existing_pubkey=$(cat "$pubkey_file" 2>/dev/null)
        if is_valid_public_key "$existing_pubkey"; then
            return 0  # Already initialized
        fi
    fi
    
    # Generate new key and extract public key
    local temp_dunikey="/tmp/${wallet_type}_temp.dunikey"
    ${MY_PATH}/keygen -t duniter -o "$temp_dunikey" "$wallet_name" "$wallet_name"
    
    if [[ -f "$temp_dunikey" ]]; then
        # Extract public key from dunikey file
        local pubkey=$(grep "pub:" "$temp_dunikey" | cut -d ' ' -f 2)
        if is_valid_public_key "$pubkey"; then
            echo "$pubkey" > "$pubkey_file"
            echo -e "${GREEN}✓ Created $wallet_type public key cache${NC}"
        fi
        rm -f "$temp_dunikey"
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

# Function to get user payment status and next due date
get_user_payment_status() {
    local user_email="$1"
    
    local status_info=""
    local next_payment_date=""
    local days_until_payment=""
    
    # Check if user is sociétaire (check both players and nostr directories)
    local is_societaire=false
    local society_date=""
    
    # Check if captain
    if [[ "${user_email}" == "${CAPTAINEMAIL}" ]]; then
        is_societaire=true
        status_info="${GREEN}✓ Sociétaire (Capitaine)${NC}"
        next_payment_date="PERMANENT"
        days_until_payment="∞"
    # Check U.SOCIETY file in players directory
    elif [[ -s ~/.zen/game/players/${user_email}/U.SOCIETY ]]; then
        is_societaire=true
        society_date=$(cat ~/.zen/game/players/${user_email}/U.SOCIETY 2>/dev/null)
    # Check U.SOCIETY file in nostr directory
    elif [[ -s ~/.zen/game/nostr/${user_email}/U.SOCIETY ]]; then
        is_societaire=true
        society_date=$(cat ~/.zen/game/nostr/${user_email}/U.SOCIETY 2>/dev/null)
    fi
    
    if [[ "$is_societaire" == true && -n "$society_date" ]]; then
        # Calculate expiration date (1 year from society date)
        local society_seconds=$(date -d "$society_date" +%s 2>/dev/null || echo "0")
        local expiry_seconds=$((society_seconds + 365*24*3600))
        local expiry_date=$(date -d "@$expiry_seconds" +%Y%m%d%H%M%S 2>/dev/null || echo "")
        local current_seconds=$(date +%s)
        local days_left=$(( (expiry_seconds - current_seconds) / 86400 ))
        
        if [[ $days_left -gt 0 ]]; then
            status_info="${GREEN}✓ Sociétaire (${days_left}j restants)${NC}"
            next_payment_date="$expiry_date"
            days_until_payment="$days_left"
        else
            status_info="${RED}✗ Sociétaire expiré${NC}"
            next_payment_date="EXPIRED"
            days_until_payment="0"
        fi
    elif [[ "$is_societaire" == false ]]; then
        # Locataire - look for birthdate in multiple locations
        local birthdate=""
        
        # Try ZenCard birthdate first (TODATE in players)
        if [[ -s ~/.zen/game/players/${user_email}/TODATE ]]; then
            birthdate=$(cat ~/.zen/game/players/${user_email}/TODATE 2>/dev/null)
        # Try MULTIPASS birthdate (TODATE in nostr)
        elif [[ -s ~/.zen/game/nostr/${user_email}/TODATE ]]; then
            birthdate=$(cat ~/.zen/game/nostr/${user_email}/TODATE 2>/dev/null)
        # Try .birthdate file
        elif [[ -s ~/.zen/game/players/${user_email}/.birthdate ]]; then
            birthdate=$(cat ~/.zen/game/players/${user_email}/.birthdate 2>/dev/null)
        elif [[ -s ~/.zen/game/nostr/${user_email}/.birthdate ]]; then
            birthdate=$(cat ~/.zen/game/nostr/${user_email}/.birthdate 2>/dev/null)
        fi
        
        if [[ -n "$birthdate" ]]; then
            local todate_seconds=$(date +%s)
            local birthdate_seconds=$(date -d "$birthdate" +%s 2>/dev/null || echo "$todate_seconds")
            local diff_days=$(( (todate_seconds - birthdate_seconds) / 86400 ))
            local days_until_next=$(( 7 - (diff_days % 7) ))
            
            if [[ $days_until_next -eq 7 ]]; then
                days_until_next=0  # Payment due today
            fi
            
            local next_payment_seconds=$((todate_seconds + days_until_next * 86400))
            next_payment_date=$(date -d "@$next_payment_seconds" +%Y%m%d%H%M%S 2>/dev/null || echo "")
            
            # Determine wallet type for better status display
            local wallet_type=""
            if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
                wallet_type="ZenCard"
            elif [[ -s ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
                wallet_type="MULTIPASS"
            fi
            
            if [[ $days_until_next -eq 0 ]]; then
                status_info="${YELLOW}⚠ Locataire $wallet_type (Paiement DÛ)${NC}"
            else
                status_info="${YELLOW}⚠ Locataire $wallet_type (${days_until_next}j)${NC}"
            fi
            days_until_payment="$days_until_next"
        else
            # No birthdate found - check if user has wallets at all
            local has_zencard=false
            local has_multipass=false
            
            if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
                has_zencard=true
            fi
            if [[ -s ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
                has_multipass=true
            fi
            
            if [[ "$has_zencard" == true || "$has_multipass" == true ]]; then
                local wallet_info=""
                if [[ "$has_zencard" == true && "$has_multipass" == true ]]; then
                    wallet_info="ZenCard+MULTIPASS"
                elif [[ "$has_zencard" == true ]]; then
                    wallet_info="ZenCard"
                else
                    wallet_info="MULTIPASS"
                fi
                status_info="${ORANGE}⚠ $wallet_info (Date d'inscription manquante)${NC}"
            else
                status_info="${RED}✗ Aucun portefeuille trouvé${NC}"
            fi
            next_payment_date="UNKNOWN"
            days_until_payment="?"
        fi
    fi
    
    echo "$status_info|$next_payment_date|$days_until_payment"
}

# Function to display users summary with payment status
display_users_summary() {
    echo -e "\n${CYAN}👥 RÉSUMÉ DES UTILISATEURS & ÉCHÉANCES${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    local total_users=0
    local societaires=0
    local locataires=0
    local payments_due=0
    local total_weekly_income=0
    local processed_users=()
    
    # Header with better formatting including wallet balances
    echo -e "${BLUE}$(printf "%-30s %-35s %-20s %-15s %-12s" "UTILISATEUR" "STATUT" "PROCHAINE ÉCHÉANCE" "SOLDES ACTUELS" "MONTANT")${NC}"
    echo -e "${YELLOW}$(printf '%.0s-' {1..115})${NC}"
    
    # Collect all unique users from both directories
    local all_users=()
    
    # Add users from players directory (ZenCard)
    if [[ -d ~/.zen/game/players ]]; then
        for player_dir in ~/.zen/game/players/*@*.*/; do
            if [[ -d "$player_dir" ]]; then
                local player_name=$(basename "$player_dir")
                if [[ "$player_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    all_users+=("$player_name")
                fi
            fi
        done
    fi
    
    # Add users from nostr directory (MULTIPASS) if not already in list
    if [[ -d ~/.zen/game/nostr ]]; then
        for nostr_dir in ~/.zen/game/nostr/*@*.*/; do
            if [[ -d "$nostr_dir" ]]; then
                local nostr_name=$(basename "$nostr_dir")
                if [[ "$nostr_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    # Check if user not already in list
                    local found=false
                    for existing_user in "${all_users[@]}"; do
                        if [[ "$existing_user" == "$nostr_name" ]]; then
                            found=true
                            break
                        fi
                    done
                    if [[ "$found" == false ]]; then
                        all_users+=("$nostr_name")
                    fi
                fi
            fi
        done
    fi
    
    # Process each unique user
    for user_email in "${all_users[@]}"; do
        # Check if user has any wallet
        local has_zencard=false
        local has_multipass=false
        
        if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
            has_zencard=true
        fi
        if [[ -s ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
            has_multipass=true
        fi
        
        # Only process users with at least one wallet
        if [[ "$has_zencard" == true || "$has_multipass" == true ]]; then
            ((total_users++))
            
            # Get payment status
            local payment_info=$(get_user_payment_status "$user_email")
            local status=$(echo "$payment_info" | cut -d '|' -f 1)
            local next_date=$(echo "$payment_info" | cut -d '|' -f 2)
            local days_until=$(echo "$payment_info" | cut -d '|' -f 3)
            
            # Format next payment date
            local formatted_date=""
            local amount_info=""
            if [[ "$next_date" == "PERMANENT" ]]; then
                formatted_date="${GREEN}Permanent${NC}"
                amount_info="${GREEN}0 Ẑen${NC}"
            elif [[ "$next_date" == "EXPIRED" ]]; then
                formatted_date="${RED}Expiré${NC}"
                amount_info="${RED}Renouveler${NC}"
            elif [[ "$next_date" == "UNKNOWN" ]]; then
                formatted_date="${ORANGE}À configurer${NC}"
                amount_info="${ORANGE}?${NC}"
            else
                # Format date as DD/MM/YYYY
                local year=${next_date:0:4}
                local month=${next_date:4:2}
                local day=${next_date:6:2}
                formatted_date="$day/$month/$year"
                
                # Determine amount based on status
                if [[ "$status" == *"Sociétaire"* ]]; then
                    ((societaires++))
                    if [[ "$status" == *"expiré"* ]]; then
                        amount_info="${YELLOW}50-540 Ẑen${NC}"
                    else
                        amount_info="${GREEN}0 Ẑen${NC}"
                    fi
                else
                    ((locataires++))
                    # Different amounts for different wallet types
                    if [[ "$status" == *"ZenCard"* ]]; then
                        amount_info="${YELLOW}4 Ẑen${NC}"
                        total_weekly_income=$((total_weekly_income + 4))
                    elif [[ "$status" == *"MULTIPASS"* ]]; then
                        amount_info="${YELLOW}1 Ẑen${NC}"
                        total_weekly_income=$((total_weekly_income + 1))
                    else
                        amount_info="${YELLOW}1-4 Ẑen${NC}"
                        total_weekly_income=$((total_weekly_income + 2))  # Average
                    fi
                    
                    if [[ "$days_until" == "0" ]]; then
                        ((payments_due++))
                        formatted_date="${RED}🚨 $formatted_date (PAIEMENT DÛ!)${NC}"
                        # Mark user as needing urgent attention
                        user_email="${RED}⚠️  $user_email${NC}"
                    elif [[ "$days_until" -le "2" ]] && [[ "$days_until" != "?" ]]; then
                        formatted_date="${YELLOW}⏰ $formatted_date (bientôt)${NC}"
                    elif [[ "$days_until" != "?" ]]; then
                        formatted_date="${GREEN}✅ $formatted_date${NC}"
                    fi
                fi
            fi
            
            # Get current wallet balances
            local wallet_balances=""
            local multipass_balance=""
            local zencard_balance=""
            
            # Check MULTIPASS balance and primal source
            if [[ -s ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
                local multipass_pubkey=$(cat ~/.zen/game/nostr/${user_email}/G1PUBNOSTR 2>/dev/null)
                if [[ -n "$multipass_pubkey" ]]; then
                    local multipass_coins=$(get_wallet_balance "$multipass_pubkey" false)
                    if [[ -n "$multipass_coins" && "$multipass_coins" != "0" ]]; then
                        local multipass_zen=$(echo "($multipass_coins - 1) * 10" | bc | cut -d '.' -f 1)
                        # Check primal source for MULTIPASS
                        local multipass_primal=$(get_primal_info "$multipass_pubkey")
                        if [[ -n "$multipass_primal" ]]; then
                            multipass_balance="${CYAN}M:${multipass_zen}Ẑ${NC}"
                        else
                            multipass_balance="${ORANGE}M:${multipass_zen}Ẑ?${NC}"  # No primal yet
                        fi
                    else
                        multipass_balance="${RED}M:0Ẑ${NC}"
                    fi
                fi
            fi
            
            # Check ZenCard balance and primal source
            if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
                local zencard_pubkey=$(cat ~/.zen/game/players/${user_email}/.g1pub 2>/dev/null)
                if [[ -n "$zencard_pubkey" ]]; then
                    local zencard_coins=$(get_wallet_balance "$zencard_pubkey" false)
                    if [[ -n "$zencard_coins" && "$zencard_coins" != "0" ]]; then
                        local zencard_zen=$(echo "($zencard_coins - 1) * 10" | bc | cut -d '.' -f 1)
                        # Check primal source for ZenCard - determine if locataire or sociétaire
                        local zencard_primal=$(get_primal_info "$zencard_pubkey")
                        local primal_indicator=""
                        if [[ -n "$zencard_primal" ]]; then
                            # Get UPLANETNAME.SOCIETY pubkey for comparison
                            local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY" 2>/dev/null)
                            if [[ "$zencard_primal" == "$society_pubkey" ]]; then
                                primal_indicator="S"  # Sociétaire (from SOCIETY)
                                zencard_balance="${PURPLE}Z:${zencard_zen}Ẑ(S)${NC}"
                            else
                                primal_indicator="L"  # Locataire (from UPLANETNAME)
                                zencard_balance="${PURPLE}Z:${zencard_zen}Ẑ(L)${NC}"
                            fi
                        else
                            zencard_balance="${ORANGE}Z:${zencard_zen}Ẑ?${NC}"  # No primal yet
                        fi
                    else
                        zencard_balance="${RED}Z:0Ẑ${NC}"
                    fi
                fi
            fi
            
            # Combine balances
            if [[ -n "$multipass_balance" && -n "$zencard_balance" ]]; then
                wallet_balances="$multipass_balance $zencard_balance"
            elif [[ -n "$multipass_balance" ]]; then
                wallet_balances="$multipass_balance"
            elif [[ -n "$zencard_balance" ]]; then
                wallet_balances="$zencard_balance"
            else
                wallet_balances="${RED}Aucun${NC}"
            fi
            
            # Create clean versions for length calculations
            local clean_status=$(echo "$status" | sed 's/\x1b\[[0-9;]*m//g')
            local clean_formatted_date=$(echo "$formatted_date" | sed 's/\x1b\[[0-9;]*m//g')
            local clean_amount_info=$(echo "$amount_info" | sed 's/\x1b\[[0-9;]*m//g')
            local clean_wallet_balances=$(echo "$wallet_balances" | sed 's/\x1b\[[0-9;]*m//g')
            
            # Calculate padding for alignment
            local email_padding=$(printf "%-30s" "$user_email")
            local status_padding=$(printf "%-35s" "$clean_status")
            local date_padding=$(printf "%-20s" "$clean_formatted_date")
            local balance_padding=$(printf "%-15s" "$clean_wallet_balances")
            
            # Display with colors using echo -e for proper color rendering
            echo -e "${email_padding} ${status} ${formatted_date} ${wallet_balances} ${amount_info}"
        fi
    done
    
    # Summary statistics
    echo -e "${YELLOW}$(printf '%.0s-' {1..115})${NC}"
    echo -e "${BLUE}STATISTIQUES:${NC}"
    echo -e "  • Total utilisateurs: ${CYAN}$total_users${NC}"
    echo -e "  • Sociétaires: ${GREEN}$societaires${NC}"
    echo -e "  • Locataires: ${YELLOW}$locataires${NC}"
    echo -e "  • Paiements dus: ${RED}$payments_due${NC}"
    echo -e "  • Revenus hebdomadaires estimés: ${CYAN}$total_weekly_income Ẑen${NC} (${YELLOW}$(echo "scale=1; $total_weekly_income / 10" | bc) Ğ1${NC})"
    
    echo -e "\n${BLUE}LÉGENDE DES SOLDES:${NC}"
    echo -e "  • ${CYAN}M:XXẐ${NC} = Solde MULTIPASS (G1PUBNOSTR)"
    echo -e "  • ${PURPLE}Z:XXẐ(L)${NC} = Solde ZenCard Locataire (source: UPLANETNAME)"
    echo -e "  • ${PURPLE}Z:XXẐ(S)${NC} = Solde ZenCard Sociétaire (source: UPLANETNAME.SOCIETY)"
    echo -e "  • ${ORANGE}XX?${NC} = Portefeuille sans transaction primale"
    
    return $payments_due
}

# Function to handle OpenCollective reporting
handle_opencollective_reporting() {
    echo -e "\n${CYAN}💰 REPORTING OPENCOLLECTIVE${NC}"
    echo -e "${YELLOW}===========================${NC}"
    echo -e "${GREEN}Reporter les paiements reçus vers OpenCollective UPlanet${NC}"
    echo -e "${BLUE}URL: https://opencollective.com/uplanet-zeropar${NC}"
    
    # Display current pending payments
    echo -e "\n${CYAN}📋 PAIEMENTS EN ATTENTE DE REPORT:${NC}"
    
    local total_to_report=0
    local payments_list=()
    
    # Check for recent transactions in UPLANETNAME.SOCIETY wallet
    local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY")
    if [[ -n "$society_pubkey" ]]; then
        echo -e "${GREEN}Portefeuille UPLANETNAME.SOCIETY: ${CYAN}$society_pubkey${NC}"
        
        # Get recent transactions (last 30 days)
        echo -e "\n${YELLOW}Transactions récentes (30 derniers jours):${NC}"
        
        # Use silkaj to get recent history
        local temp_history="/tmp/society_history_$(date +%s).txt"
        silkaj money history "$society_pubkey" 2>/dev/null | head -20 > "$temp_history"
        
        if [[ -s "$temp_history" ]]; then
            local line_count=0
            while IFS= read -r line; do
                if [[ "$line" == *"+"* ]] && [[ "$line" != *"Ğ1"* ]]; then
                    # This is an incoming transaction
                    local amount=$(echo "$line" | grep -o '+[0-9.]*' | sed 's/+//')
                    if [[ -n "$amount" ]]; then
                        local zen_amount=$(echo "$amount * 10" | bc | cut -d '.' -f 1)
                        payments_list+=("$zen_amount Ẑen ($amount Ğ1)")
                        total_to_report=$((total_to_report + zen_amount))
                        echo -e "  • ${GREEN}+$zen_amount Ẑen${NC} (${YELLOW}$amount Ğ1${NC})"
                        ((line_count++))
                    fi
                fi
                
                if [[ $line_count -ge 10 ]]; then
                    break
                fi
            done < "$temp_history"
        fi
        
        rm -f "$temp_history"
    fi
    
    echo -e "\n${CYAN}💰 TOTAL À REPORTER: ${GREEN}$total_to_report Ẑen${NC}"
    
    if [[ $total_to_report -gt 0 ]]; then
        echo -e "\n${BLUE}ÉTAPES POUR REPORTER SUR OPENCOLLECTIVE:${NC}"
        echo -e "  1. ${YELLOW}Ouvrir: https://opencollective.com/uplanet-zeropar${NC}"
        echo -e "  2. ${YELLOW}Se connecter avec le compte administrateur${NC}"
        echo -e "  3. ${YELLOW}Aller dans 'Submit Expense' ou 'Add Funds'${NC}"
        echo -e "  4. ${YELLOW}Montant: $total_to_report Ẑen (équivalent $(echo "scale=2; $total_to_report / 10" | bc) Ğ1)${NC}"
        echo -e "  5. ${YELLOW}Description: 'Paiements UPlanet reçus - $(date +%d/%m/%Y)'${NC}"
        echo -e "  6. ${YELLOW}Catégorie: 'UPlanet Operations'${NC}"
        
        echo -e "\n${GREEN}Détail des paiements:${NC}"
        for payment in "${payments_list[@]}"; do
            echo -e "  • $payment"
        done
        
        echo -e "\n${CYAN}Confirmer le report sur OpenCollective?${NC}"
        read -p "Tapez 'CONFIRME' pour marquer comme reporté (ou 'q' pour revenir): " confirm
        
        if [[ "$confirm" == "CONFIRME" ]]; then
            # Create a report file
            local report_file="$HOME/.zen/tmp/opencollective_report_$(date +%Y%m%d_%H%M%S).txt"
            echo "OpenCollective Report - $(date)" > "$report_file"
            echo "Total reporté: $total_to_report Ẑen" >> "$report_file"
            echo "Équivalent Ğ1: $(echo "scale=2; $total_to_report / 10" | bc) Ğ1" >> "$report_file"
            echo "Détail des paiements:" >> "$report_file"
            for payment in "${payments_list[@]}"; do
                echo "  • $payment" >> "$report_file"
            done
            
            echo -e "${GREEN}✅ Report marqué comme effectué${NC}"
            echo -e "${GREEN}Fichier de rapport: ${CYAN}$report_file${NC}"
        elif [[ "$confirm" == "q" || "$confirm" == "Q" ]]; then
            echo -e "${YELLOW}Retour au menu principal${NC}"
            main "$@"
            return
        else
            echo -e "${YELLOW}Report annulé${NC}"
        fi
    else
        echo -e "${YELLOW}Aucun paiement récent à reporter${NC}"
    fi
    
    echo ""
    read -p "Appuyez sur Entrée pour revenir au menu principal..." 
    main "$@"
}

# Function to handle payment transcription
handle_payment_transcription() {
    echo -e "\n${CYAN}📋 RETRANSCRIPTION DES VERSEMENTS${NC}"
    echo -e "${YELLOW}=================================${NC}"
    echo -e "${GREEN}Retranscription des versements par utilisateur selon leur source primale${NC}"
    
    echo -e "\n${BLUE}OPTIONS DE RETRANSCRIPTION:${NC}"
    echo -e "  1. 📊 Rapport complet de tous les versements"
    echo -e "  2. 👤 Versements d'un utilisateur spécifique"
    echo -e "  3. 🏛️  Versements par source (UPLANETNAME vs UPLANETNAME.SOCIETY)"
    echo -e "  4. 📈 Générer rapport CSV des versements"
    echo -e "  5. 🔙 Retour au menu principal"
    
    read -p "Sélectionnez une option (1-5): " transcription_choice
    
    case "$transcription_choice" in
        1)
            generate_complete_payment_report
            ;;
        2)
            transcribe_user_payments
            ;;
        3)
            transcribe_payments_by_source
            ;;
        4)
            generate_payment_csv_report
            ;;
        5)
            echo -e "${GREEN}Retour au menu principal...${NC}"
            main "$@"
            ;;
        *)
            echo -e "${RED}Sélection invalide. Veuillez choisir 1-5.${NC}"
            echo ""
            read -p "Appuyez sur Entrée pour réessayer..." 
            handle_payment_transcription
            ;;
    esac
}

# Function to generate complete payment report
generate_complete_payment_report() {
    echo -e "\n${CYAN}📊 RAPPORT COMPLET DES VERSEMENTS${NC}"
    echo -e "${YELLOW}=================================${NC}"
    
    local report_file="$HOME/.zen/tmp/payment_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "RAPPORT DES VERSEMENTS - $(date)" > "$report_file"
    echo "=======================================" >> "$report_file"
    echo "" >> "$report_file"
    
    # Collect all unique users
    local all_users=()
    
    # Add users from players directory (ZenCard)
    if [[ -d ~/.zen/game/players ]]; then
        for player_dir in ~/.zen/game/players/*@*.*/; do
            if [[ -d "$player_dir" ]]; then
                local player_name=$(basename "$player_dir")
                if [[ "$player_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    all_users+=("$player_name")
                fi
            fi
        done
    fi
    
    # Add users from nostr directory (MULTIPASS) if not already in list
    if [[ -d ~/.zen/game/nostr ]]; then
        for nostr_dir in ~/.zen/game/nostr/*@*.*/; do
            if [[ -d "$nostr_dir" ]]; then
                local nostr_name=$(basename "$nostr_dir")
                if [[ "$nostr_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    local found=false
                    for existing_user in "${all_users[@]}"; do
                        if [[ "$existing_user" == "$nostr_name" ]]; then
                            found=true
                            break
                        fi
                    done
                    if [[ "$found" == false ]]; then
                        all_users+=("$nostr_name")
                    fi
                fi
            fi
        done
    fi
    
    local total_multipass_zen=0
    local total_zencard_zen=0
    local total_locataire_zen=0
    local total_societaire_zen=0
    
    echo -e "${BLUE}UTILISATEUR                    TYPE PORTEFEUILLE    SOLDE ACTUEL    SOURCE PRIMALE${NC}"
    echo -e "${YELLOW}$(printf '%.0s-' {1..85})${NC}"
    
    for user_email in "${all_users[@]}"; do
        local user_report=""
        local multipass_zen=0
        local zencard_zen=0
        local primal_source=""
        
        # Check MULTIPASS
        if [[ -s ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
            local multipass_pubkey=$(cat ~/.zen/game/nostr/${user_email}/G1PUBNOSTR 2>/dev/null)
            if [[ -n "$multipass_pubkey" ]]; then
                local multipass_coins=$(get_wallet_balance "$multipass_pubkey" false)
                if [[ -n "$multipass_coins" && "$multipass_coins" != "0" ]]; then
                    multipass_zen=$(echo "($multipass_coins - 1) * 10" | bc | cut -d '.' -f 1)
                    total_multipass_zen=$((total_multipass_zen + multipass_zen))
                fi
            fi
        fi
        
        # Check ZenCard
        if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
            local zencard_pubkey=$(cat ~/.zen/game/players/${user_email}/.g1pub 2>/dev/null)
            if [[ -n "$zencard_pubkey" ]]; then
                local zencard_coins=$(get_wallet_balance "$zencard_pubkey" false)
                if [[ -n "$zencard_coins" && "$zencard_coins" != "0" ]]; then
                    zencard_zen=$(echo "($zencard_coins - 1) * 10" | bc | cut -d '.' -f 1)
                    total_zencard_zen=$((total_zencard_zen + zencard_zen))
                    
                    # Determine primal source
                    local zencard_primal=$(get_primal_info "$zencard_pubkey")
                    if [[ -n "$zencard_primal" ]]; then
                        local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY" 2>/dev/null)
                        if [[ "$zencard_primal" == "$society_pubkey" ]]; then
                            primal_source="UPLANETNAME.SOCIETY (Sociétaire)"
                            total_societaire_zen=$((total_societaire_zen + zencard_zen))
                        else
                            primal_source="UPLANETNAME (Locataire)"
                            total_locataire_zen=$((total_locataire_zen + zencard_zen))
                        fi
                    else
                        primal_source="Aucune transaction primale"
                    fi
                fi
            fi
        fi
        
        # Display user info if they have any wallet
        if [[ $multipass_zen -gt 0 || $zencard_zen -gt 0 ]]; then
            local wallet_type=""
            local balance_display=""
            
            if [[ $multipass_zen -gt 0 && $zencard_zen -gt 0 ]]; then
                wallet_type="MULTIPASS + ZenCard"
                balance_display="M:${multipass_zen}Ẑ Z:${zencard_zen}Ẑ"
            elif [[ $multipass_zen -gt 0 ]]; then
                wallet_type="MULTIPASS"
                balance_display="M:${multipass_zen}Ẑ"
                primal_source="UPLANETNAME (MULTIPASS)"
            else
                wallet_type="ZenCard"
                balance_display="Z:${zencard_zen}Ẑ"
            fi
            
            printf "%-30s %-18s %-15s %-25s\n" \
                "$user_email" \
                "$wallet_type" \
                "$balance_display" \
                "$primal_source"
            
            # Add to report file
            echo "$user_email,$wallet_type,$balance_display,$primal_source" >> "$report_file"
        fi
    done
    
    echo -e "${YELLOW}$(printf '%.0s-' {1..85})${NC}"
    echo -e "${BLUE}TOTAUX:${NC}"
    echo -e "  • Total MULTIPASS: ${CYAN}${total_multipass_zen} Ẑen${NC}"
    echo -e "  • Total ZenCard: ${PURPLE}${total_zencard_zen} Ẑen${NC}"
    echo -e "  • Total Locataires: ${YELLOW}${total_locataire_zen} Ẑen${NC}"
    echo -e "  • Total Sociétaires: ${GREEN}${total_societaire_zen} Ẑen${NC}"
    
    # Add totals to report file
    echo "" >> "$report_file"
    echo "TOTAUX:" >> "$report_file"
    echo "Total MULTIPASS: ${total_multipass_zen} Ẑen" >> "$report_file"
    echo "Total ZenCard: ${total_zencard_zen} Ẑen" >> "$report_file"
    echo "Total Locataires: ${total_locataire_zen} Ẑen" >> "$report_file"
    echo "Total Sociétaires: ${total_societaire_zen} Ẑen" >> "$report_file"
    
    echo -e "\n${GREEN}✅ Rapport généré: ${CYAN}$report_file${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour revenir au menu de retranscription..." 
    handle_payment_transcription
}

# Function to transcribe specific user payments
transcribe_user_payments() {
    echo -e "\n${CYAN}👤 VERSEMENTS D'UN UTILISATEUR SPÉCIFIQUE${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    # List available users
    echo -e "${GREEN}Utilisateurs disponibles:${NC}"
    local user_list=()
    local counter=1
    
    # Collect users from both directories
    if [[ -d ~/.zen/game/players ]]; then
        for player_dir in ~/.zen/game/players/*@*.*/; do
            if [[ -d "$player_dir" ]]; then
                local player_name=$(basename "$player_dir")
                if [[ "$player_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    user_list+=("$player_name")
                    echo -e "  ${counter}. $player_name"
                    ((counter++))
                fi
            fi
        done
    fi
    
    if [[ -d ~/.zen/game/nostr ]]; then
        for nostr_dir in ~/.zen/game/nostr/*@*.*/; do
            if [[ -d "$nostr_dir" ]]; then
                local nostr_name=$(basename "$nostr_dir")
                if [[ "$nostr_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    local found=false
                    for existing_user in "${user_list[@]}"; do
                        if [[ "$existing_user" == "$nostr_name" ]]; then
                            found=true
                            break
                        fi
                    done
                    if [[ "$found" == false ]]; then
                        user_list+=("$nostr_name")
                        echo -e "  ${counter}. $nostr_name"
                        ((counter++))
                    fi
                fi
            fi
        done
    fi
    
    if [[ ${#user_list[@]} -eq 0 ]]; then
        echo -e "${RED}Aucun utilisateur trouvé${NC}"
        echo ""
        read -p "Appuyez sur Entrée pour revenir au menu de retranscription..." 
        handle_payment_transcription
        return
    fi
    
    echo ""
    read -p "Sélectionnez un utilisateur (1-${#user_list[@]}) ou 'q' pour revenir: " user_choice
    
    if [[ "$user_choice" == "q" || "$user_choice" == "Q" ]]; then
        handle_payment_transcription
        return
    fi
    
    if ! [[ "$user_choice" =~ ^[0-9]+$ ]] || [[ "$user_choice" -lt 1 ]] || [[ "$user_choice" -gt ${#user_list[@]} ]]; then
        echo -e "${RED}Sélection invalide${NC}"
        echo ""
        read -p "Appuyez sur Entrée pour réessayer..." 
        transcribe_user_payments
        return
    fi
    
    local selected_user="${user_list[$((user_choice - 1))]}"
    
    echo -e "\n${CYAN}📋 DÉTAIL DES VERSEMENTS POUR: ${GREEN}$selected_user${NC}"
    echo -e "${YELLOW}$(printf '%.0s=' {1..60})${NC}"
    
    # Analyze user's wallets
    local has_multipass=false
    local has_zencard=false
    local multipass_zen=0
    local zencard_zen=0
    
    # Check MULTIPASS
    if [[ -s ~/.zen/game/nostr/${selected_user}/G1PUBNOSTR ]]; then
        has_multipass=true
        local multipass_pubkey=$(cat ~/.zen/game/nostr/${selected_user}/G1PUBNOSTR 2>/dev/null)
        if [[ -n "$multipass_pubkey" ]]; then
            local multipass_coins=$(get_wallet_balance "$multipass_pubkey" false)
            if [[ -n "$multipass_coins" && "$multipass_coins" != "0" ]]; then
                multipass_zen=$(echo "($multipass_coins - 1) * 10" | bc | cut -d '.' -f 1)
                echo -e "${CYAN}💳 MULTIPASS:${NC}"
                echo -e "  • Clé publique: ${CYAN}$multipass_pubkey${NC}"
                echo -e "  • Solde actuel: ${CYAN}${multipass_zen} Ẑen${NC} (${multipass_coins} Ğ1)"
                echo -e "  • Source primale: ${YELLOW}UPLANETNAME${NC}"
                echo -e "  • Type: ${YELLOW}Locataire${NC}"
            fi
        fi
    fi
    
    # Check ZenCard
    if [[ -s ~/.zen/game/players/${selected_user}/.g1pub ]]; then
        has_zencard=true
        local zencard_pubkey=$(cat ~/.zen/game/players/${selected_user}/.g1pub 2>/dev/null)
        if [[ -n "$zencard_pubkey" ]]; then
            local zencard_coins=$(get_wallet_balance "$zencard_pubkey" false)
            if [[ -n "$zencard_coins" && "$zencard_coins" != "0" ]]; then
                zencard_zen=$(echo "($zencard_coins - 1) * 10" | bc | cut -d '.' -f 1)
                echo -e "\n${PURPLE}💎 ZENCARD:${NC}"
                echo -e "  • Clé publique: ${PURPLE}$zencard_pubkey${NC}"
                echo -e "  • Solde actuel: ${PURPLE}${zencard_zen} Ẑen${NC} (${zencard_coins} Ğ1)"
                
                # Determine primal source
                local zencard_primal=$(get_primal_info "$zencard_pubkey")
                if [[ -n "$zencard_primal" ]]; then
                    local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY" 2>/dev/null)
                    if [[ "$zencard_primal" == "$society_pubkey" ]]; then
                        echo -e "  • Source primale: ${GREEN}UPLANETNAME.SOCIETY${NC}"
                        echo -e "  • Type: ${GREEN}Sociétaire${NC}"
                    else
                        echo -e "  • Source primale: ${YELLOW}UPLANETNAME${NC}"
                        echo -e "  • Type: ${YELLOW}Locataire${NC}"
                    fi
                else
                    echo -e "  • Source primale: ${RED}Aucune transaction primale${NC}"
                fi
            fi
        fi
    fi
    
    # Summary for this user
    local total_zen=$((multipass_zen + zencard_zen))
    echo -e "\n${BLUE}📊 RÉSUMÉ:${NC}"
    echo -e "  • Total des versements: ${CYAN}${total_zen} Ẑen${NC}"
    
    if [[ $has_multipass == true && $has_zencard == true ]]; then
        echo -e "  • Répartition: MULTIPASS ${multipass_zen}Ẑ + ZenCard ${zencard_zen}Ẑ"
    elif [[ $has_multipass == true ]]; then
        echo -e "  • Type: MULTIPASS uniquement"
    elif [[ $has_zencard == true ]]; then
        echo -e "  • Type: ZenCard uniquement"
    else
        echo -e "  • ${RED}Aucun portefeuille avec solde${NC}"
    fi
    
    echo ""
    read -p "Appuyez sur Entrée pour revenir au menu de retranscription..." 
    handle_payment_transcription
}

# Function to transcribe payments by source
transcribe_payments_by_source() {
    echo -e "\n${CYAN}🏛️  VERSEMENTS PAR SOURCE PRIMALE${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    local uplanetname_total=0
    local society_total=0
    local multipass_total=0
    local no_primal_total=0
    
    echo -e "${BLUE}RÉPARTITION PAR SOURCE:${NC}"
    echo ""
    
    # Collect all users and analyze their sources
    local all_users=()
    
    # Add users from both directories
    if [[ -d ~/.zen/game/players ]]; then
        for player_dir in ~/.zen/game/players/*@*.*/; do
            if [[ -d "$player_dir" ]]; then
                local player_name=$(basename "$player_dir")
                if [[ "$player_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    all_users+=("$player_name")
                fi
            fi
        done
    fi
    
    if [[ -d ~/.zen/game/nostr ]]; then
        for nostr_dir in ~/.zen/game/nostr/*@*.*/; do
            if [[ -d "$nostr_dir" ]]; then
                local nostr_name=$(basename "$nostr_dir")
                if [[ "$nostr_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    local found=false
                    for existing_user in "${all_users[@]}"; do
                        if [[ "$existing_user" == "$nostr_name" ]]; then
                            found=true
                            break
                        fi
                    done
                    if [[ "$found" == false ]]; then
                        all_users+=("$nostr_name")
                    fi
                fi
            fi
        done
    fi
    
    echo -e "${GREEN}🏛️  SOURCE: UPLANETNAME (Locataires)${NC}"
    echo -e "${YELLOW}$(printf '%.0s-' {1..50})${NC}"
    
    for user_email in "${all_users[@]}"; do
        local user_zen=0
        
        # Check MULTIPASS (always from UPLANETNAME)
        if [[ -s ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
            local multipass_pubkey=$(cat ~/.zen/game/nostr/${user_email}/G1PUBNOSTR 2>/dev/null)
            if [[ -n "$multipass_pubkey" ]]; then
                local multipass_coins=$(get_wallet_balance "$multipass_pubkey" false)
                if [[ -n "$multipass_coins" && "$multipass_coins" != "0" ]]; then
                    local multipass_zen=$(echo "($multipass_coins - 1) * 10" | bc | cut -d '.' -f 1)
                    user_zen=$((user_zen + multipass_zen))
                    multipass_total=$((multipass_total + multipass_zen))
                fi
            fi
        fi
        
        # Check ZenCard from UPLANETNAME
        if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
            local zencard_pubkey=$(cat ~/.zen/game/players/${user_email}/.g1pub 2>/dev/null)
            if [[ -n "$zencard_pubkey" ]]; then
                local zencard_coins=$(get_wallet_balance "$zencard_pubkey" false)
                if [[ -n "$zencard_coins" && "$zencard_coins" != "0" ]]; then
                    local zencard_zen=$(echo "($zencard_coins - 1) * 10" | bc | cut -d '.' -f 1)
                    local zencard_primal=$(get_primal_info "$zencard_pubkey")
                    if [[ -n "$zencard_primal" ]]; then
                        local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY" 2>/dev/null)
                        if [[ "$zencard_primal" != "$society_pubkey" ]]; then
                            user_zen=$((user_zen + zencard_zen))
                            uplanetname_total=$((uplanetname_total + zencard_zen))
                        fi
                    else
                        no_primal_total=$((no_primal_total + zencard_zen))
                    fi
                fi
            fi
        fi
        
        if [[ $user_zen -gt 0 ]]; then
            echo -e "  ${user_email}: ${CYAN}${user_zen} Ẑen${NC}"
        fi
    done
    
    echo -e "${YELLOW}Sous-total UPLANETNAME: ${CYAN}$((uplanetname_total + multipass_total)) Ẑen${NC}"
    echo ""
    
    echo -e "${GREEN}⭐ SOURCE: UPLANETNAME.SOCIETY (Sociétaires)${NC}"
    echo -e "${YELLOW}$(printf '%.0s-' {1..50})${NC}"
    
    for user_email in "${all_users[@]}"; do
        local user_zen=0
        
        # Check ZenCard from UPLANETNAME.SOCIETY
        if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
            local zencard_pubkey=$(cat ~/.zen/game/players/${user_email}/.g1pub 2>/dev/null)
            if [[ -n "$zencard_pubkey" ]]; then
                local zencard_coins=$(get_wallet_balance "$zencard_pubkey" false)
                if [[ -n "$zencard_coins" && "$zencard_coins" != "0" ]]; then
                    local zencard_zen=$(echo "($zencard_coins - 1) * 10" | bc | cut -d '.' -f 1)
                    local zencard_primal=$(get_primal_info "$zencard_pubkey")
                    if [[ -n "$zencard_primal" ]]; then
                        local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY" 2>/dev/null)
                        if [[ "$zencard_primal" == "$society_pubkey" ]]; then
                            user_zen=$((user_zen + zencard_zen))
                            society_total=$((society_total + zencard_zen))
                        fi
                    fi
                fi
            fi
        fi
        
        if [[ $user_zen -gt 0 ]]; then
            echo -e "  ${user_email}: ${PURPLE}${user_zen} Ẑen${NC}"
        fi
    done
    
    echo -e "${YELLOW}Sous-total UPLANETNAME.SOCIETY: ${PURPLE}${society_total} Ẑen${NC}"
    echo ""
    
    if [[ $no_primal_total -gt 0 ]]; then
        echo -e "${ORANGE}⚠️  PORTEFEUILLES SANS TRANSACTION PRIMALE: ${no_primal_total} Ẑen${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}📊 TOTAUX GÉNÉRAUX:${NC}"
    echo -e "${YELLOW}$(printf '%.0s=' {1..40})${NC}"
    echo -e "  • MULTIPASS (UPLANETNAME): ${CYAN}${multipass_total} Ẑen${NC}"
    echo -e "  • ZenCard Locataires: ${CYAN}${uplanetname_total} Ẑen${NC}"
    echo -e "  • ZenCard Sociétaires: ${PURPLE}${society_total} Ẑen${NC}"
    if [[ $no_primal_total -gt 0 ]]; then
        echo -e "  • Sans transaction primale: ${ORANGE}${no_primal_total} Ẑen${NC}"
    fi
    echo -e "${YELLOW}$(printf '%.0s-' {1..40})${NC}"
    echo -e "  • ${GREEN}TOTAL GÉNÉRAL: $((multipass_total + uplanetname_total + society_total + no_primal_total)) Ẑen${NC}"
    
    echo ""
    read -p "Appuyez sur Entrée pour revenir au menu de retranscription..." 
    handle_payment_transcription
}

# Function to generate CSV report
generate_payment_csv_report() {
    echo -e "\n${CYAN}📈 GÉNÉRATION RAPPORT CSV${NC}"
    echo -e "${YELLOW}=========================${NC}"
    
    local csv_file="$HOME/.zen/tmp/versements_$(date +%Y%m%d_%H%M%S).csv"
    
    # CSV Header
    echo "Email,Type_Portefeuille,Solde_MULTIPASS_Zen,Solde_ZenCard_Zen,Source_Primale,Statut,Total_Zen" > "$csv_file"
    
    # Collect all users
    local all_users=()
    
    if [[ -d ~/.zen/game/players ]]; then
        for player_dir in ~/.zen/game/players/*@*.*/; do
            if [[ -d "$player_dir" ]]; then
                local player_name=$(basename "$player_dir")
                if [[ "$player_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    all_users+=("$player_name")
                fi
            fi
        done
    fi
    
    if [[ -d ~/.zen/game/nostr ]]; then
        for nostr_dir in ~/.zen/game/nostr/*@*.*/; do
            if [[ -d "$nostr_dir" ]]; then
                local nostr_name=$(basename "$nostr_dir")
                if [[ "$nostr_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    local found=false
                    for existing_user in "${all_users[@]}"; do
                        if [[ "$existing_user" == "$nostr_name" ]]; then
                            found=true
                            break
                        fi
                    done
                    if [[ "$found" == false ]]; then
                        all_users+=("$nostr_name")
                    fi
                fi
            fi
        done
    fi
    
    local total_entries=0
    
    for user_email in "${all_users[@]}"; do
        local multipass_zen=0
        local zencard_zen=0
        local wallet_type=""
        local primal_source=""
        local status=""
        
        # Check MULTIPASS
        if [[ -s ~/.zen/game/nostr/${user_email}/G1PUBNOSTR ]]; then
            local multipass_pubkey=$(cat ~/.zen/game/nostr/${user_email}/G1PUBNOSTR 2>/dev/null)
            if [[ -n "$multipass_pubkey" ]]; then
                local multipass_coins=$(get_wallet_balance "$multipass_pubkey" false)
                if [[ -n "$multipass_coins" && "$multipass_coins" != "0" ]]; then
                    multipass_zen=$(echo "($multipass_coins - 1) * 10" | bc | cut -d '.' -f 1)
                fi
            fi
        fi
        
        # Check ZenCard
        if [[ -s ~/.zen/game/players/${user_email}/.g1pub ]]; then
            local zencard_pubkey=$(cat ~/.zen/game/players/${user_email}/.g1pub 2>/dev/null)
            if [[ -n "$zencard_pubkey" ]]; then
                local zencard_coins=$(get_wallet_balance "$zencard_pubkey" false)
                if [[ -n "$zencard_coins" && "$zencard_coins" != "0" ]]; then
                    zencard_zen=$(echo "($zencard_coins - 1) * 10" | bc | cut -d '.' -f 1)
                    
                    # Determine primal source
                    local zencard_primal=$(get_primal_info "$zencard_pubkey")
                    if [[ -n "$zencard_primal" ]]; then
                        local society_pubkey=$(get_system_wallet_public_key "UPLANETNAME.SOCIETY" 2>/dev/null)
                        if [[ "$zencard_primal" == "$society_pubkey" ]]; then
                            primal_source="UPLANETNAME.SOCIETY"
                            status="Sociétaire"
                        else
                            primal_source="UPLANETNAME"
                            status="Locataire"
                        fi
                    else
                        primal_source="Aucune_transaction_primale"
                        status="Non_initialisé"
                    fi
                fi
            fi
        fi
        
        # Determine wallet type
        if [[ $multipass_zen -gt 0 && $zencard_zen -gt 0 ]]; then
            wallet_type="MULTIPASS+ZenCard"
        elif [[ $multipass_zen -gt 0 ]]; then
            wallet_type="MULTIPASS"
            primal_source="UPLANETNAME"
            status="Locataire"
        elif [[ $zencard_zen -gt 0 ]]; then
            wallet_type="ZenCard"
        else
            continue  # Skip users with no balance
        fi
        
        local total_zen=$((multipass_zen + zencard_zen))
        
        # Add to CSV
        echo "$user_email,$wallet_type,$multipass_zen,$zencard_zen,$primal_source,$status,$total_zen" >> "$csv_file"
        ((total_entries++))
    done
    
    echo -e "${GREEN}✅ Rapport CSV généré: ${CYAN}$csv_file${NC}"
    echo -e "${GREEN}📊 Nombre d'entrées: ${CYAN}$total_entries${NC}"
    echo -e "${GREEN}📁 Taille du fichier: ${CYAN}$(du -h "$csv_file" | cut -f1)${NC}"
    
    echo ""
    echo -e "${BLUE}Colonnes du rapport:${NC}"
    echo -e "  • Email: Adresse email de l'utilisateur"
    echo -e "  • Type_Portefeuille: MULTIPASS, ZenCard, ou MULTIPASS+ZenCard"
    echo -e "  • Solde_MULTIPASS_Zen: Solde en Ẑen du portefeuille MULTIPASS"
    echo -e "  • Solde_ZenCard_Zen: Solde en Ẑen du portefeuille ZenCard"
    echo -e "  • Source_Primale: UPLANETNAME ou UPLANETNAME.SOCIETY"
    echo -e "  • Statut: Locataire ou Sociétaire"
    echo -e "  • Total_Zen: Somme des soldes en Ẑen"
    
    echo ""
    read -p "Appuyez sur Entrée pour revenir au menu de retranscription..." 
    handle_payment_transcription
}

# Function to display station overview
display_station_overview() {
    echo -e "\n${CYAN}🏠 APERÇU DE LA STATION UPLANET ẐEN${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # Station identity
    echo -e "${BLUE}🏛️  IDENTITÉ DE LA STATION:${NC}"
    echo -e "  • Nom: ${GREEN}$UPLANETNAME${NC}"
    echo -e "  • Capitaine: ${GREEN}$CAPTAINEMAIL${NC}"
    echo -e "  • Date: ${CYAN}$(date +%d/%m/%Y)${NC}"
    echo -e "  • Heure: ${CYAN}$(date +%H:%M:%S)${NC}"
    
    # System wallets status
    echo -e "\n${BLUE}💰 PORTEFEUILLES SYSTÈME:${NC}"
    
    # UPLANETNAME.G1
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1" 2>/dev/null)
        if [[ -n "$g1_pubkey" ]]; then
            g1_balance=$(get_wallet_balance "$g1_pubkey")
            echo -e "  • ${GREEN}UPLANETNAME.G1:${NC} ${YELLOW}$g1_balance Ğ1${NC} (Réserves)"
        else
            echo -e "  • ${RED}UPLANETNAME.G1: Erreur de configuration${NC}"
        fi
    else
        echo -e "  • ${RED}UPLANETNAME.G1: Non configuré${NC}"
    fi
    
    # UPLANETNAME
    if [[ -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        services_pubkey=$(cat "$HOME/.zen/tmp/UPLANETG1PUB" 2>/dev/null)
        if [[ -n "$services_pubkey" ]]; then
            local status=$(get_wallet_status "$services_pubkey" "UPLANETNAME")
            services_balance=$(echo "$status" | cut -d '|' -f 1)
            zen_balance=$(echo "$status" | cut -d '|' -f 3)
            echo -e "  • ${GREEN}UPLANETNAME:${NC} ${YELLOW}$services_balance Ğ1${NC} (${CYAN}$zen_balance Ẑen${NC})"
        else
            echo -e "  • ${RED}UPLANETNAME: Erreur de configuration${NC}"
        fi
    else
        echo -e "  • ${RED}UPLANETNAME: Non configuré${NC}"
    fi
    
    # UPLANETNAME.SOCIETY
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" ]]; then
        society_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" 2>/dev/null)
        if [[ -n "$society_pubkey" ]]; then
            local status=$(get_wallet_status "$society_pubkey" "UPLANETNAME.SOCIETY")
            society_balance=$(echo "$status" | cut -d '|' -f 1)
            zen_balance=$(echo "$status" | cut -d '|' -f 3)
            echo -e "  • ${GREEN}UPLANETNAME.SOCIETY:${NC} ${YELLOW}$society_balance Ğ1${NC} (${CYAN}$zen_balance Ẑen${NC})"
        else
            echo -e "  • ${RED}UPLANETNAME.SOCIETY: Non configuré${NC}"
        fi
    else
        echo -e "  • ${RED}UPLANETNAME.SOCIETY: Non configuré${NC}"
    fi
    
    # Quick user stats
    echo -e "\n${BLUE}👥 UTILISATEURS:${NC}"
    local multipass_count=$(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | wc -l)
    local zencard_count=$(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | wc -l)
    echo -e "  • MULTIPASS: ${CYAN}$multipass_count${NC}"
    echo -e "  • ZenCard: ${PURPLE}$zencard_count${NC}"
    
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
}

# Function to display economic dashboard (full version)
display_economic_dashboard() {
    echo -e "\n${CYAN}📊 TABLEAU DE BORD ÉCONOMIQUE COMPLET${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
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
    echo -e "  4. 🔙 Retour au menu principal"
    
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
            echo -e "${GREEN}Retour au menu principal...${NC}"
            main "$@"
            ;;
        *)
            echo -e "${RED}Sélection invalide. Veuillez choisir 1-4.${NC}"
            echo ""
            read -p "Appuyez sur Entrée pour réessayer..." 
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
    
    # Check G1check.sh script
    if [[ -f "${MY_PATH}/G1check.sh" ]]; then
        echo -e "${GREEN}✓ G1check.sh: Available${NC}"
    else
        echo -e "${RED}✗ G1check.sh: Not found${NC}"
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
    while true; do
        clear
        echo -e "${CYAN}🌟 ASTROPORT.ONE ZEN TRANSACTION MANAGER${NC}"
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${GREEN}Bienvenue, Capitaine ! Gérez votre station UPlanet ẐEN${NC}"
        
        # Initialize system
        initialize_system
        
        # Check if UPLANETNAME is defined
        if [[ -z "$UPLANETNAME" ]]; then
            echo -e "${RED}❌ ERREUR: UPLANETNAME n'est pas défini !${NC}"
            echo -e "${YELLOW}Veuillez vous assurer que UPLANETNAME est défini dans votre environnement.${NC}"
            exit 1
        fi
        
        # Initialize system wallets
        initialize_system_wallets
        
        # Display station overview
        display_station_overview
        
        # Display users summary with payment tracking
        display_users_summary
        local payments_due=$?
        
        # Alert for due payments
        if [[ $payments_due -gt 0 ]]; then
            echo -e "\n${RED}🚨 ALERTE CAPITAINE: $payments_due paiement(s) en retard !${NC}"
            echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
            
            # Show overdue users specifically
            echo -e "${RED}👥 UTILISATEURS EN RETARD:${NC}"
            
            # Collect overdue users from both directories
            local overdue_users=()
            
            # Check players directory (ZenCard)
            if [[ -d ~/.zen/game/players ]]; then
                for player_dir in ~/.zen/game/players/*@*.*/; do
                    if [[ -d "$player_dir" ]]; then
                        local player_name=$(basename "$player_dir")
                        if [[ "$player_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                            local payment_info=$(get_user_payment_status "$player_name")
                            local days_until=$(echo "$payment_info" | cut -d '|' -f 3)
                            if [[ "$days_until" == "0" ]]; then
                                overdue_users+=("$player_name")
                            fi
                        fi
                    fi
                done
            fi
            
            # Check nostr directory (MULTIPASS) 
            if [[ -d ~/.zen/game/nostr ]]; then
                for nostr_dir in ~/.zen/game/nostr/*@*.*/; do
                    if [[ -d "$nostr_dir" ]]; then
                        local nostr_name=$(basename "$nostr_dir")
                        if [[ "$nostr_name" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                            # Check if not already in overdue list
                            local found=false
                            for existing_user in "${overdue_users[@]}"; do
                                if [[ "$existing_user" == "$nostr_name" ]]; then
                                    found=true
                                    break
                                fi
                            done
                            if [[ "$found" == false ]]; then
                                local payment_info=$(get_user_payment_status "$nostr_name")
                                local days_until=$(echo "$payment_info" | cut -d '|' -f 3)
                                if [[ "$days_until" == "0" ]]; then
                                    overdue_users+=("$nostr_name")
                                fi
                            fi
                        fi
                    fi
                done
            fi
            
            # Display overdue users
            for overdue_user in "${overdue_users[@]}"; do
                echo -e "  ${RED}⚠️  $overdue_user${NC} - Paiement immédiatement requis"
            done
            
            echo -e "\n${YELLOW}📋 ACTIONS RECOMMANDÉES:${NC}"
            echo -e "  1. ${CYAN}Vérifier les soldes des locataires concernés${NC} (Option 6: Analyse)"
            echo -e "  2. ${CYAN}Envoyer des rappels de paiement${NC}"
            echo -e "  3. ${CYAN}Considérer la déconnexion automatique après 28 jours${NC}"
            echo -e "\n${CYAN}💡 Conseil: Utilisez l'option 6 (Analyse des portefeuilles) pour examiner en détail${NC}"
            echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
        else
            echo -e "\n${GREEN}✅ Tous les paiements sont à jour - Aucune action requise${NC}"
        fi
        
        # Display main menu
        echo -e "\n${CYAN}🎯 MENU PRINCIPAL - GESTION DE LA STATION${NC}"
        echo -e "${YELLOW}===========================================${NC}"
        
        echo -e "${BLUE}1. 🏛️  PORTEFEUILLES SYSTÈME${NC} - Gestion des comptes centraux"
        echo -e "   • UPLANETNAME.G1 (Réserves Ğ1)"
        echo -e "   • UPLANETNAME (Services & MULTIPASS)"
        echo -e "   • UPLANETNAME.SOCIETY (Capital social)"
        echo ""
        
        echo -e "${BLUE}2. 👥 GESTION DES UTILISATEURS${NC} - Suivi et paiements"
        echo -e "   • Tableau de bord des utilisateurs"
        echo -e "   • Gestion des paiements en retard"
        echo -e "   • Création de comptes utilisateurs"
        echo ""
        
        echo -e "${BLUE}3. 💰 REPORTING & COMPTABILITÉ${NC} - Suivi financier"
        echo -e "   • Reporting OpenCollective"
        echo -e "   • Retranscription des versements"
        echo -e "   • Rapports comptables"
        echo ""
        
        echo -e "${BLUE}4. 🔍 ANALYSE & DIAGNOSTIC${NC} - Outils avancés"
        echo -e "   • Analyse des portefeuilles"
        echo -e "   • Historique des transactions"
        echo -e "   • Diagnostic de la chaîne primale"
        echo ""
        
        echo -e "${BLUE}5. ⚙️  CONFIGURATION & MAINTENANCE${NC} - Administration"
        echo -e "   • Configuration de la station"
        echo -e "   • Maintenance système"
        echo -e "   • Santé de la station"
        echo ""
        
        echo -e "${BLUE}6. 📚 AIDE & DOCUMENTATION${NC} - Guide et conseils"
        echo -e "   • Guide du capitaine"
        echo -e "   • Documentation ẐEN"
        echo -e "   • Bonnes pratiques"
        echo ""
        
        echo -e "${BLUE}0. 🚪 QUITTER${NC} - Sortir du gestionnaire"
        echo ""
        
        # Get user selection
        read -p "Sélectionnez une option (0-6): " choice
        
        case "$choice" in
            0)
                echo -e "${GREEN}👋 Au revoir, Capitaine !${NC}"
                exit 0
                ;;
            1)
                handle_system_wallets
                ;;
            2)
                handle_user_management
                ;;
            3)
                handle_reporting_accounting
                ;;
            4)
                handle_analysis_diagnostics
                ;;
            5)
                handle_configuration_maintenance
                ;;
            6)
                handle_help_documentation
                ;;
            *)
                echo -e "${RED}Sélection invalide. Veuillez choisir 0-6.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
        esac
    done
}

# Function to handle system wallets management
handle_system_wallets() {
    while true; do
        clear
        echo -e "${CYAN}🏛️  GESTION DES PORTEFEUILLES SYSTÈME${NC}"
        echo -e "${YELLOW}=====================================${NC}"
        echo -e "${GREEN}Gérez les comptes centraux de votre station UPlanet${NC}"
        
        echo -e "\n${BLUE}PORTEFEUILLES DISPONIBLES:${NC}"
        echo -e "  1. 🏛️  UPLANETNAME.G1 - Réserves Ğ1 et donations"
        echo -e "  2. 💼 UPLANETNAME - Services et MULTIPASS"
        echo -e "  3. ⭐ UPLANETNAME.SOCIETY - Capital social et ZenCard"
        echo -e "  4. 📊 Vue d'ensemble de tous les portefeuilles"
        echo -e "  5. 🔧 Initialisation des portefeuilles manquants"
        echo -e "  0. 🔙 Retour au menu principal"
        
        read -p "Sélectionnez une option (0-5): " wallet_choice
        
        case "$wallet_choice" in
            0)
                return 0
                ;;
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
                display_all_system_wallets
                ;;
            5)
                initialize_missing_wallets
                ;;
            *)
                echo -e "${RED}Sélection invalide. Veuillez choisir 0-5.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
        esac
    done
}

# Function to handle user management
handle_user_management() {
    while true; do
        clear
        echo -e "${CYAN}👥 GESTION DES UTILISATEURS${NC}"
        echo -e "${YELLOW}===========================${NC}"
        echo -e "${GREEN}Gérez les utilisateurs et suivez leurs paiements${NC}"
        
        echo -e "\n${BLUE}OPTIONS DISPONIBLES:${NC}"
        echo -e "  1. 📊 Tableau de bord des utilisateurs"
        echo -e "  2. 🚨 Gestion des paiements en retard"
        echo -e "  3. ➕ Créer un nouveau compte utilisateur"
        echo -e "  4. 🔍 Rechercher un utilisateur spécifique"
        echo -e "  5. 📧 Envoyer des rappels de paiement"
        echo -e "  0. 🔙 Retour au menu principal"
        
        read -p "Sélectionnez une option (0-5): " user_choice
        
        case "$user_choice" in
            0)
                return 0
                ;;
            1)
                display_users_summary
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
            2)
                handle_overdue_payments
                ;;
            3)
                create_new_user_account
                ;;
            4)
                search_user_account
                ;;
            5)
                send_payment_reminders
                ;;
            *)
                echo -e "${RED}Sélection invalide. Veuillez choisir 0-5.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
        esac
    done
}

# Function to handle reporting and accounting
handle_reporting_accounting() {
    while true; do
        clear
        echo -e "${CYAN}💰 REPORTING & COMPTABILITÉ${NC}"
        echo -e "${YELLOW}================================${NC}"
        echo -e "${GREEN}Suivi financier et rapports de votre station${NC}"
        
        echo -e "\n${BLUE}OPTIONS DISPONIBLES:${NC}"
        echo -e "  1. 📊 Reporting OpenCollective"
        echo -e "  2. 📋 Retranscription des versements"
        echo -e "  3. 📈 Rapports comptables"
        echo -e "  4. 💳 Suivi des revenus hebdomadaires"
        echo -e "  5. 📁 Export des données financières"
        echo -e "  0. 🔙 Retour au menu principal"
        
        read -p "Sélectionnez une option (0-5): " report_choice
        
        case "$report_choice" in
            0)
                return 0
                ;;
            1)
                handle_opencollective_reporting
                ;;
            2)
                handle_payment_transcription
                ;;
            3)
                generate_accounting_reports
                ;;
            4)
                track_weekly_revenue
                ;;
            5)
                export_financial_data
                ;;
            *)
                echo -e "${RED}Sélection invalide. Veuillez choisir 0-5.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
        esac
    done
}

# Function to handle analysis and diagnostics
handle_analysis_diagnostics() {
    while true; do
        clear
        echo -e "${CYAN}🔍 ANALYSE & DIAGNOSTIC${NC}"
        echo -e "${YELLOW}==========================${NC}"
        echo -e "${GREEN}Outils avancés pour analyser votre station${NC}"
        
        echo -e "\n${BLUE}OUTILS DISPONIBLES:${NC}"
        echo -e "  1. 🔍 Analyse des portefeuilles"
        echo -e "  2. 📜 Historique des transactions"
        echo -e "  3. 🔗 Diagnostic de la chaîne primale"
        echo -e "  4. 📊 Statistiques de la station"
        echo -e "  5. 🚨 Vérification de la santé système"
        echo -e "  0. 🔙 Retour au menu principal"
        
        read -p "Sélectionnez une option (0-5): " analysis_choice
        
        case "$analysis_choice" in
            0)
                return 0
                ;;
            1)
                handle_wallet_analysis
                ;;
            2)
                show_transaction_history_menu
                ;;
            3)
                diagnose_primal_chain
                ;;
            4)
                show_station_statistics
                ;;
            5)
                perform_system_health_check
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
            *)
                echo -e "${RED}Sélection invalide. Veuillez choisir 0-5.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
        esac
    done
}

# Function to handle configuration and maintenance
handle_configuration_maintenance() {
    while true; do
        clear
        echo -e "${CYAN}⚙️  CONFIGURATION & MAINTENANCE${NC}"
        echo -e "${YELLOW}==================================${NC}"
        echo -e "${GREEN}Administrez et maintenez votre station${NC}"
        
        echo -e "\n${BLUE}OPTIONS DISPONIBLES:${NC}"
        echo -e "  1. ⚙️  Configuration de la station"
        echo -e "  2. 🛠️  Maintenance système"
        echo -e "  3. 🔄 Rafraîchir les soldes"
        echo -e "  4. 🧹 Nettoyer le cache"
        echo -e "  5. 🚀 Assistant d'initialisation"
        echo -e "  0. 🔙 Retour au menu principal"
        
        read -p "Sélectionnez une option (0-5): " config_choice
        
        case "$config_choice" in
            0)
                return 0
                ;;
            1)
                configure_station
                ;;
            2)
                handle_maintenance
                ;;
            3)
                refresh_all_balances
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
            4)
                read -p "Entrez la limite d'âge du cache en heures (défaut: 24): " cache_age
                cache_age="${cache_age:-24}"
                clean_cache "$cache_age"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
            5)
                handle_astroport_initialization
                ;;
            *)
                echo -e "${RED}Sélection invalide. Veuillez choisir 0-5.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
        esac
    done
}

# Function to handle help and documentation
handle_help_documentation() {
    while true; do
        clear
        echo -e "${CYAN}📚 AIDE & DOCUMENTATION${NC}"
        echo -e "${YELLOW}==========================${NC}"
        echo -e "${GREEN}Guide et conseils pour le capitaine${NC}"
        
        echo -e "\n${BLUE}RESSOURCES DISPONIBLES:${NC}"
        echo -e "  1. 💡 Guide du capitaine"
        echo -e "  2. 📖 Documentation ẐEN"
        echo -e "  3. ✅ Bonnes pratiques"
        echo -e "  4. 🔧 Procédures recommandées"
        echo -e "  5. 📞 Support et contact"
        echo -e "  0. 🔙 Retour au menu principal"
        
        read -p "Sélectionnez une option (0-5): " help_choice
        
        case "$help_choice" in
            0)
                return 0
                ;;
            1)
                show_captain_tips
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
            2)
                show_zen_documentation
                ;;
            3)
                show_best_practices
                ;;
            4)
                show_recommended_procedures
                ;;
            5)
                show_support_contact
                ;;
            *)
                echo -e "${RED}Sélection invalide. Veuillez choisir 0-5.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..." 
                ;;
        esac
    done
}

# Function to display all system wallets
display_all_system_wallets() {
    echo -e "\n${CYAN}📊 VUE D'ENSEMBLE DES PORTEFEUILLES SYSTÈME${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    local wallets=("UPLANETNAME.G1" "UPLANETNAME" "UPLANETNAME.SOCIETY")
    for wallet in "${wallets[@]}"; do
        local pubkey=$(get_system_wallet_public_key "$wallet")
        if [[ -n "$pubkey" ]]; then
            local balance=$(get_wallet_balance "$pubkey")
            echo -e "${BLUE}$wallet:${NC} ${CYAN}$pubkey${NC} (${YELLOW}$balance Ğ1${NC})"
        else
            echo -e "${RED}$wallet: Non configuré${NC}"
        fi
    done
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to initialize missing wallets
initialize_missing_wallets() {
    echo -e "\n${CYAN}🔧 INITIALISATION DES PORTEFEUILLES MANQUANTS${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    
    echo -e "${GREEN}Initialisation des portefeuilles système...${NC}"
    initialize_system_wallets
    
    echo -e "\n${BLUE}État des portefeuilles:${NC}"
    local wallets=("UPLANETNAME.G1" "UPLANETNAME" "UPLANETNAME.SOCIETY")
    for wallet in "${wallets[@]}"; do
        local pubkey=$(get_system_wallet_public_key "$wallet")
        if [[ -n "$pubkey" ]]; then
            local balance=$(get_wallet_balance "$pubkey")
            echo -e "  • ${GREEN}$wallet${NC}: ${CYAN}$pubkey${NC} (${YELLOW}$balance Ğ1${NC})"
        else
            echo -e "  • ${RED}$wallet${NC}: Non configuré"
        fi
    done
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to handle overdue payments
handle_overdue_payments() {
    echo -e "\n${CYAN}🚨 GESTION DES PAIEMENTS EN RETARD${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # This function would implement overdue payment management
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to create new user account
create_new_user_account() {
    echo -e "\n${CYAN}➕ CRÉATION D'UN NOUVEAU COMPTE UTILISATEUR${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    # This function would implement user account creation
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to search user account
search_user_account() {
    echo -e "\n${CYAN}🔍 RECHERCHE D'UN COMPTE UTILISATEUR${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # This function would implement user account search
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to send payment reminders
send_payment_reminders() {
    echo -e "\n${CYAN}📧 ENVOI DE RAPPELS DE PAIEMENT${NC}"
    echo -e "${YELLOW}===================================${NC}"
    
    # This function would implement payment reminder sending
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to generate accounting reports
generate_accounting_reports() {
    echo -e "\n${CYAN}📈 GÉNÉRATION DE RAPPORTS COMPTABLES${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # This function would implement accounting report generation
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to track weekly revenue
track_weekly_revenue() {
    echo -e "\n${CYAN}💳 SUIVI DES REVENUS HEBDOMADAIRES${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # This function would implement weekly revenue tracking
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to export financial data
export_financial_data() {
    echo -e "\n${CYAN}📁 EXPORT DES DONNÉES FINANCIÈRES${NC}"
    echo -e "${YELLOW}===================================${NC}"
    
    # This function would implement financial data export
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to show transaction history menu
show_transaction_history_menu() {
    echo -e "\n${CYAN}📜 HISTORIQUE DES TRANSACTIONS${NC}"
    echo -e "${YELLOW}=================================${NC}"
    
    # This function would implement transaction history menu
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to diagnose primal chain
diagnose_primal_chain() {
    echo -e "\n${CYAN}🔗 DIAGNOSTIC DE LA CHAÎNE PRIMALE${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    
    # This function would implement primal chain diagnosis
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to show station statistics
show_station_statistics() {
    echo -e "\n${CYAN}📊 STATISTIQUES DE LA STATION${NC}"
    echo -e "${YELLOW}=================================${NC}"
    
    # This function would implement station statistics display
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to configure station
configure_station() {
    echo -e "\n${CYAN}⚙️  CONFIGURATION DE LA STATION${NC}"
    echo -e "${YELLOW}===================================${NC}"
    
    # This function would implement station configuration
    echo -e "${GREEN}Fonctionnalité en cours de développement...${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to show zen documentation
show_zen_documentation() {
    echo -e "\n${CYAN}📖 DOCUMENTATION ẐEN${NC}"
    echo -e "${YELLOW}========================${NC}"
    
    echo -e "${GREEN}Documentation de l'écosystème UPlanet ẐEN:${NC}"
    echo -e "  • Constitution: ${CYAN}./LEGAL.md${NC}"
    echo -e "  • Code de la Route: ${CYAN}./RUNTIME/ZEN.ECONOMY.readme.md${NC}"
    echo -e "  • Diagramme des flux: ${CYAN}./templates/mermaid_LEGAL_UPLANET_FLUX.mmd${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to show best practices
show_best_practices() {
    echo -e "\n${CYAN}✅ BONNES PRATIQUES${NC}"
    echo -e "${YELLOW}========================${NC}"
    
    echo -e "${GREEN}Bonnes pratiques pour la gestion de la station:${NC}"
    echo -e "  • Vérifier quotidiennement les paiements dus"
    echo -e "  • Maintenir des sauvegardes régulières"
    echo -e "  • Surveiller la santé du système"
    echo -e "  • Documenter toutes les opérations importantes"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to show recommended procedures
show_recommended_procedures() {
    echo -e "\n${CYAN}🔧 PROCÉDURES RECOMMANDÉES${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    echo -e "${GREEN}Procédures recommandées:${NC}"
    echo -e "  • Initialisation hebdomadaire des paiements"
    echo -e "  • Vérification mensuelle des portefeuilles"
    echo -e "  • Rapport trimestriel OpenCollective"
    echo -e "  • Maintenance système mensuelle"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Function to show support and contact
show_support_contact() {
    echo -e "\n${CYAN}📞 SUPPORT ET CONTACT${NC}"
    echo -e "${YELLOW}==========================${NC}"
    
    echo -e "${GREEN}Support disponible:${NC}"
    echo -e "  • Email: ${CYAN}support@qo-op.com${NC}"
    echo -e "  • Documentation: ${CYAN}./docs/${NC}"
    echo -e "  • Communauté: ${CYAN}https://uplanet.one${NC}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." 
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@" 