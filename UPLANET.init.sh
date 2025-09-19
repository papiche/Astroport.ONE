#!/bin/bash
# -----------------------------------------------------------------------------
# UPLANET.init.sh - Initialisation des Portefeuilles de la Coopérative UPlanet
#
# Ce script vérifie et initialise les portefeuilles de la coopérative UPlanet :
# - UPLANETNAME (Services & MULTIPASS)
# - UPLANETNAME.SOCIETY (Capital social)
# - UPLANETNAME.CASH (Trésorerie - uplanet.CASH.dunikey)
# - UPLANETNAME.RND (R&D - uplanet.RnD.dunikey)
# - UPLANETNAME.ASSETS (Actifs - uplanet.ASSETS.dunikey)
#
# Si un portefeuille est vide (< 1 Ğ1), il reçoit 1 Ğ1 depuis secret.G1.dunikey
# pour l'initialiser à 0 Ẑen (1 Ğ1 = 0 Ẑen après transaction primale)
#
# Usage: ./UPLANET.init.sh [--force] [--dry-run]
# -----------------------------------------------------------------------------

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Source environment variables
. "${MY_PATH}/tools/my.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
INIT_AMOUNT="1"  # 1 Ğ1 pour initialiser chaque portefeuille
MIN_BALANCE="1"  # Solde minimum requis (1 Ğ1)
DRY_RUN=false
FORCE=false

# Cooperative wallets to check and initialize
declare -A COOPERATIVE_WALLETS=(
    ["UPLANETNAME"]="$HOME/.zen/game/uplanet.dunikey"
    ["UPLANETNAME.SOCIETY"]="$HOME/.zen/game/uplanet.SOCIETY.dunikey"
    ["UPLANETNAME.CASH"]="$HOME/.zen/game/uplanet.CASH.dunikey"
    ["UPLANETNAME.RND"]="$HOME/.zen/game/uplanet.RnD.dunikey"
    ["UPLANETNAME.ASSETS"]="$HOME/.zen/game/uplanet.ASSETS.dunikey"
    ["UPLANETNAME.IMPOT"]="$HOME/.zen/game/uplanet.IMPOT.dunikey"
    ["UPLANETNAME.CAPTAIN"]="$HOME/.zen/game/uplanet.captain.dunikey"
    ["UPLANETNAME.INTRUSION"]="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
)

# Node and Captain wallets to check and initialize (if they exist)
declare -A NODE_CAPTAIN_WALLETS=(
    ["NODE"]="$HOME/.zen/game/secret.NODE.dunikey"
)

# Source wallet for initialization (uplanet.G1.dunikey is the primary source for primal transactions)
SOURCE_WALLET="$HOME/.zen/game/uplanet.G1.dunikey"

# Function to display usage information
usage() {
    echo -e "${CYAN}Usage: $ME [OPTIONS]${NC}"
    echo ""
    echo -e "${YELLOW}🎯 INITIALISATION DES PORTEFEUILLES COOPÉRATIFS UPLANET${NC}"
    echo ""
    echo -e "${GREEN}Ce script vérifie et initialise les portefeuilles de la coopérative:${NC}"
    echo -e "  • UPLANETNAME (Services & MULTIPASS)"
    echo -e "  • UPLANETNAME.SOCIETY (Capital social)"
    echo -e "  • UPLANETNAME.CASH (Trésorerie)"
    echo -e "  • UPLANETNAME.RND (R&D)"
    echo -e "  • UPLANETNAME.ASSETS (Actifs)"
    echo -e "  • UPLANETNAME.IMPOT (Fiscalité)"
    echo -e "  • UPLANETNAME.CAPTAIN (Rémunération capitaine)"
    echo -e "  • UPLANETNAME.INTRUSION (Fonds d'intrusions détectées)"
    echo -e "  • NODE (Armateur - si existant)"
    echo -e "  • CAPTAIN (si configuré)"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo -e "  ${CYAN}--force${NC}     Forcer l'initialisation même si les portefeuilles ont des fonds"
    echo -e "  ${CYAN}--dry-run${NC}   Simulation sans effectuer de transactions"
    echo -e "  ${CYAN}--help${NC}      Afficher cette aide"
    echo ""
    echo -e "${YELLOW}⚠️  SÉCURITÉ:${NC}"
    echo -e "   • Vérification des soldes avant initialisation"
    echo -e "   • Transactions de 1 Ğ1 uniquement"
    echo -e "   • Source principale: uplanet.G1.dunikey (portefeuille de réserve)"
    echo ""
    echo -e "${GREEN}Le script initialise chaque portefeuille vide avec 1 Ğ1 pour 0 Ẑen.${NC}"
    exit 1
}

# Function to check if required tools are available
check_requirements() {
    echo -e "${CYAN}🔍 VÉRIFICATION DES PRÉREQUIS${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    local missing_tools=()
    
    # Check G1check.sh
    if [[ ! -f "${MY_PATH}/tools/G1check.sh" ]]; then
        missing_tools+=("G1check.sh")
    fi
    
    # Check bc
    if ! command -v bc >/dev/null 2>&1; then
        missing_tools+=("bc")
    fi
    
    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Outils manquants:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "  • $tool"
        done
        echo -e "${YELLOW}Veuillez installer les outils manquants.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Tous les outils requis sont disponibles${NC}"
    echo ""
}

# Function to check if source wallet exists and has sufficient balance
check_source_wallet() {
    echo -e "${CYAN}💰 VÉRIFICATION DU PORTEFEUILLE SOURCE${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo -e "${GREEN}✅ Portefeuille source trouvé: ${CYAN}$SOURCE_WALLET${NC}"
    
    # Extract public key from source wallet
    local source_pubkey=$(cat "$SOURCE_WALLET" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    if [[ -z "$source_pubkey" ]]; then
        echo -e "${RED}❌ Impossible d'extraire la clé publique depuis $SOURCE_WALLET${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Portefeuille source:${NC} ${CYAN}${source_pubkey:0:8}...${NC}"
    
    # Check source wallet balance using G1check.sh
    echo -e "${YELLOW}Vérification du solde...${NC}"
    local source_balance=$(get_wallet_balance "$source_pubkey")
    
    if [[ -z "$source_balance" || "$source_balance" == "null" ]]; then
        echo -e "${RED}❌ Impossible de récupérer le solde du portefeuille source${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Solde actuel:${NC} ${YELLOW}$source_balance Ğ1${NC}"
    
    # Calculate required amount (8 cooperative wallets + potential node/captain)
    local required_amount=8
    local available_balance=$(echo "$source_balance" | bc -l 2>/dev/null || echo "0")
    
    # Calculate how many wallets can be initialized
    WALLETS_TO_INITIALIZE=$(echo "$available_balance" | bc -l | cut -d. -f1)
    if [[ -z "$WALLETS_TO_INITIALIZE" ]] || [[ "$WALLETS_TO_INITIALIZE" -lt 1 ]]; then
        WALLETS_TO_INITIALIZE=0
    elif [[ "$WALLETS_TO_INITIALIZE" -gt 10 ]]; then
        WALLETS_TO_INITIALIZE=10  # Max: 8 cooperative + NODE + CAPTAIN
    fi
    
    if (( $(echo "$available_balance < 1" | bc -l) )); then
        echo -e "${RED}❌ Solde insuffisant pour l'initialisation${NC}"
        echo -e "${BLUE}Solde disponible:${NC} ${YELLOW}$available_balance Ğ1${NC}"
        echo -e "${BLUE}Solde requis:${NC} ${YELLOW}1 Ğ1 minimum${NC}"
        echo -e "${YELLOW}Veuillez alimenter le portefeuille source.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Portefeuille source vérifié avec succès${NC}"
    if [[ "$WALLETS_TO_INITIALIZE" -ge 8 ]]; then
        echo -e "${BLUE}Solde suffisant pour initialiser ${CYAN}tous les portefeuilles coopératifs${NC}"
    else
        echo -e "${BLUE}Solde suffisant pour initialiser ${CYAN}$WALLETS_TO_INITIALIZE portefeuilles${NC}"
        echo -e "${YELLOW}⚠️  Initialisation partielle (solde limité)${NC}"
    fi
    echo ""
}

# Function to get wallet balance using G1check.sh
get_wallet_balance() {
    local pubkey="$1"
    
    # Use G1check.sh to get balance
    local balance_result=$("${MY_PATH}/tools/G1check.sh" "$pubkey" 2>/dev/null)
    
    # Extract balance from result (assuming G1check.sh returns just the number)
    local balance=$(echo "$balance_result" | grep -E '^[0-9]+\.?[0-9]*$' | head -1)
    
    if [[ -z "$balance" ]]; then
        echo "0"
    else
        echo "$balance"
    fi
}

# Function to get wallet public key from dunikey file
get_wallet_public_key() {
    local dunikey_file="$1"
    
    if [[ -f "$dunikey_file" ]]; then
        local pubkey=$(cat "$dunikey_file" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        echo "$pubkey"
    else
        echo ""
    fi
}

# Function to create missing wallet files
create_missing_wallet() {
    local wallet_name="$1"
    local dunikey_file="$2"
    
    echo -e "${CYAN}🔧 CRÉATION DU PORTEFEUILLE $wallet_name${NC}"
    
    # Create directory if it doesn't exist
    local wallet_dir=$(dirname "$dunikey_file")
    [[ ! -d "$wallet_dir" ]] && mkdir -p "$wallet_dir"
    
    # Create wallet using keygen like in ZEN.COOPERATIVE.3x1-3.sh and my.sh
    case "$wallet_name" in
        "UPLANETNAME.CASH")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}.TREASURY" "${UPLANETNAME}.TREASURY"
            ;;
        "UPLANETNAME.RND")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}.RND" "${UPLANETNAME}.RND"
            ;;
        "UPLANETNAME.ASSETS")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}.ASSETS" "${UPLANETNAME}.ASSETS"
            ;;
        "UPLANETNAME.IMPOT")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
            ;;
        "UPLANETNAME.SOCIETY")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}.SOCIETY" "${UPLANETNAME}.SOCIETY"
            ;;
        "UPLANETNAME")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}" "${UPLANETNAME}"
            ;;
        "UPLANETNAME.CAPTAIN")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}.${CAPTAINEMAIL}" "${UPLANETNAME}.${CAPTAINEMAIL}"
            ;;
        "UPLANETNAME.INTRUSION")
            "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "${UPLANETNAME}.INTRUSION" "${UPLANETNAME}.INTRUSION"
            ;;
        *)
            echo -e "${RED}❌ Type de portefeuille non reconnu: $wallet_name${NC}"
            return 1
            ;;
    esac
    
    # Set proper permissions
    chmod 600 "$dunikey_file"
    
    if [[ -f "$dunikey_file" ]]; then
        local pubkey=$(get_wallet_public_key "$dunikey_file")
        echo -e "${GREEN}✅ Portefeuille $wallet_name créé avec succès${NC}"
        echo -e "${BLUE}Clé publique:${NC} ${CYAN}${pubkey:0:8}...${NC}"
        return 0
    else
        echo -e "${RED}❌ Échec de la création du portefeuille $wallet_name${NC}"
        return 1
    fi
}

# Function to get captain email
get_captain_email() {
    local captain_email=""
    if [[ -f "$HOME/.zen/game/players/.current/.player" ]]; then
        captain_email=$(cat "$HOME/.zen/game/players/.current/.player" 2>/dev/null)
    fi
    echo "$captain_email"
}

# Function to check node and captain wallets
check_node_captain_wallets() {
    echo -e "${CYAN}🚀 VÉRIFICATION DES PORTEFEUILLES NODE ET CAPTAIN${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    
    local wallets_to_initialize=()
    local captain_email=$(get_captain_email)
    
    # Check NODE wallet
    if [[ -f "${NODE_CAPTAIN_WALLETS["NODE"]}" ]]; then
        local node_pubkey=$(get_wallet_public_key "${NODE_CAPTAIN_WALLETS["NODE"]}")
        if [[ -n "$node_pubkey" ]]; then
            local balance=$(get_wallet_balance "$node_pubkey")
            if (( $(echo "$balance < $MIN_BALANCE" | bc -l) )); then
                echo -e "${YELLOW}📡 NODE wallet needs initialization: ${balance} Ğ1${NC}"
                wallets_to_initialize+=("NODE")
            else
                echo -e "${GREEN}✅ NODE wallet OK: ${balance} Ğ1${NC}"
            fi
        fi
    else
        echo -e "${BLUE}ℹ️  NODE wallet not found (normal for non-Y-level nodes)${NC}"
    fi
    
    # Check CAPTAIN wallets if captain is configured
    if [[ -n "$captain_email" ]]; then
        echo -e "${BLUE}👑 Captain configuré: ${captain_email}${NC}"
        
        # Check CAPTAIN MULTIPASS
        local captain_multipass="$HOME/.zen/game/nostr/${captain_email}/.secret.dunikey"
        if [[ -f "$captain_multipass" ]]; then
            local multipass_pubkey=$(get_wallet_public_key "$captain_multipass")
            if [[ -n "$multipass_pubkey" ]]; then
                local balance=$(get_wallet_balance "$multipass_pubkey")
                if (( $(echo "$balance < $MIN_BALANCE" | bc -l) )); then
                    echo -e "${YELLOW}📱 CAPTAIN MULTIPASS needs initialization: ${balance} Ğ1${NC}"
                    wallets_to_initialize+=("CAPTAIN_MULTIPASS")
                else
                    echo -e "${GREEN}✅ CAPTAIN MULTIPASS OK: ${balance} Ğ1${NC}"
                fi
            fi
        else
            echo -e "${BLUE}ℹ️  CAPTAIN MULTIPASS not found${NC}"
        fi
        
        # Check CAPTAIN ZEN Card
        local captain_zencard="$HOME/.zen/game/players/${captain_email}/secret.dunikey"
        if [[ -f "$captain_zencard" ]]; then
            local zencard_pubkey=$(get_wallet_public_key "$captain_zencard")
            if [[ -n "$zencard_pubkey" ]]; then
                local balance=$(get_wallet_balance "$zencard_pubkey")
                if (( $(echo "$balance < $MIN_BALANCE" | bc -l) )); then
                    echo -e "${YELLOW}💳 CAPTAIN ZEN Card needs initialization: ${balance} Ğ1${NC}"
                    wallets_to_initialize+=("CAPTAIN_ZENCARD")
                else
                    echo -e "${GREEN}✅ CAPTAIN ZEN Card OK: ${balance} Ğ1${NC}"
                fi
            fi
        else
            echo -e "${BLUE}ℹ️  CAPTAIN ZEN Card not found${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  No captain configured${NC}"
    fi
    
    # Store wallets to initialize for later use
    NODE_CAPTAIN_TO_INITIALIZE=("${wallets_to_initialize[@]}")
    
    echo ""
    if [[ ${#wallets_to_initialize[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  ${#wallets_to_initialize[@]} portefeuille(s) NODE/CAPTAIN à initialiser${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Tous les portefeuilles NODE/CAPTAIN sont OK${NC}"
        return 0
    fi
}

# Function to check cooperative wallet status
check_cooperative_wallets() {
    echo -e "${CYAN}🏛️  VÉRIFICATION DES PORTEFEUILLES COOPÉRATIFS${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    
    local wallets_to_initialize=()
    local wallets_to_create=()
    local total_required=0
    
    echo -e "${BLUE}Portefeuilles à vérifier:${NC}"
    printf "%-25s %-15s %-15s %-10s\n" "PORTEFEUILLE" "SOLDE ACTUEL" "STATUT" "ACTION"
    printf "%.0s-" {1..70}
    echo ""
    
    for wallet_name in "${!COOPERATIVE_WALLETS[@]}"; do
        local dunikey_file="${COOPERATIVE_WALLETS[$wallet_name]}"
        local pubkey=""
        local balance="0"
        local status=""
        local action=""
        
        # Check if dunikey file exists
        if [[ -f "$dunikey_file" ]]; then
            pubkey=$(get_wallet_public_key "$dunikey_file")
            if [[ -n "$pubkey" ]]; then
                # Get current balance
                balance=$(get_wallet_balance "$pubkey")
                
                # Determine status and action
                if (( $(echo "$balance < $MIN_BALANCE" | bc -l) )); then
                    status="Vide"
                    action="Initialiser"
                    wallets_to_initialize+=("$wallet_name")
                    total_required=$((total_required + 1))
                else
                    status="OK"
                    action="Aucune"
                fi
            else
                status="Erreur clé"
                action="Vérifier"
            fi
        else
            status="Fichier manquant"
            action="Créer"
            wallets_to_create+=("$wallet_name")
        fi
        
        # Display wallet status (without ANSI codes in printf)
        printf "%-25s %-15s %-15s %-10s\n" \
            "$wallet_name" \
            "$balance Ğ1" \
            "$status" \
            "$action"
    done
    
    printf "%.0s-" {1..70}
    echo ""
    
    # Create missing wallets first
    if [[ ${#wallets_to_create[@]} -gt 0 ]]; then
        echo -e "${BLUE}📁 CRÉATION DES PORTEFEUILLES MANQUANTS${NC}"
        for wallet_name in "${wallets_to_create[@]}"; do
            local dunikey_file="${COOPERATIVE_WALLETS[$wallet_name]}"
            if create_missing_wallet "$wallet_name" "$dunikey_file"; then
                # After creation, check if it needs initialization
                local pubkey=$(get_wallet_public_key "$dunikey_file")
                if [[ -n "$pubkey" ]]; then
                    local balance=$(get_wallet_balance "$pubkey")
                    if (( $(echo "$balance < $MIN_BALANCE" | bc -l) )); then
                        wallets_to_initialize+=("$wallet_name")
                        total_required=$((total_required + 1))
                    fi
                fi
            fi
        done
        echo ""
    fi
    
    # Summary
    if [[ ${#wallets_to_initialize[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ Tous les portefeuilles sont déjà initialisés${NC}"
        return 0
    else
        echo -e "${BLUE}📊 RÉSUMÉ:${NC}"
        echo -e "  • Portefeuilles à initialiser: ${CYAN}${#wallets_to_initialize[@]}${NC}"
        echo -e "  • Montant total requis: ${YELLOW}$total_required Ğ1${NC}"
        echo -e "  • Source: ${CYAN}uplanet.G1.dunikey${NC}"
        echo ""
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${YELLOW}🔍 MODE SIMULATION - Aucune transaction ne sera effectuée${NC}"
        fi
        
        return 1
    fi
}

# Function to initialize a node or captain wallet
initialize_node_captain_wallet() {
    local wallet_type="$1"
    local captain_email=$(get_captain_email)
    
    echo -e "\n${CYAN}🚀 INITIALISATION DE $wallet_type${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    local dunikey_file=""
    local pubkey=""
    local description=""
    
    case "$wallet_type" in
        "NODE")
            dunikey_file="${NODE_CAPTAIN_WALLETS["NODE"]}"
            description="Initialisation NODE (Armateur)"
            ;;
        "CAPTAIN_MULTIPASS")
            dunikey_file="$HOME/.zen/game/nostr/${captain_email}/.secret.dunikey"
            description="Initialisation CAPTAIN MULTIPASS"
            ;;
        "CAPTAIN_ZENCARD")
            dunikey_file="$HOME/.zen/game/players/${captain_email}/secret.dunikey"
            description="Initialisation CAPTAIN ZEN Card"
            ;;
        *)
            echo -e "${RED}❌ Type de portefeuille non reconnu: $wallet_type${NC}"
            return 1
            ;;
    esac
    
    # Get destination public key
    pubkey=$(get_wallet_public_key "$dunikey_file")
    if [[ -z "$pubkey" ]]; then
        echo -e "${RED}❌ Impossible de récupérer la clé publique de $wallet_type${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Portefeuille:${NC} $wallet_type"
    echo -e "${BLUE}Clé publique:${NC} ${CYAN}${pubkey:0:8}...${NC}"
    echo -e "${BLUE}Montant:${NC} ${YELLOW}$INIT_AMOUNT Ğ1${NC}"
    echo -e "${BLUE}Source:${NC} ${CYAN}uplanet.G1.dunikey${NC}"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 SIMULATION: Transaction de $INIT_AMOUNT Ğ1 vers $wallet_type${NC}"
        return 0
    fi
    
    # Execute transaction using PAYforSURE.sh
    echo -e "${YELLOW}Exécution de la transaction...${NC}"
    
    # Convert amount to G1 for PAYforSURE.sh
    local transfer_amount_g1=$(echo "scale=2; $INIT_AMOUNT" | bc -l)
    
    # Use PAYforSURE.sh
    local transfer_result
    transfer_result=$("${MY_PATH}/tools/PAYforSURE.sh" "$SOURCE_WALLET" "$transfer_amount_g1" "$pubkey" "UPLANET:INIT:$wallet_type" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Transaction réussie pour $wallet_type${NC}"
        echo -e "${GREEN}✅ $wallet_type initialisé avec succès${NC}"
        return 0
    else
        echo -e "${RED}❌ Échec de la transaction pour $wallet_type${NC}"
        echo "$transfer_result"
        return 1
    fi
}

# Function to initialize a cooperative wallet
initialize_wallet() {
    local wallet_name="$1"
    local dunikey_file="${COOPERATIVE_WALLETS[$wallet_name]}"
    local pubkey=""
    
    echo -e "\n${CYAN}🚀 INITIALISATION DE $wallet_name${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    # Get destination public key
    pubkey=$(get_wallet_public_key "$dunikey_file")
    if [[ -z "$pubkey" ]]; then
        echo -e "${RED}❌ Impossible de récupérer la clé publique de $wallet_name${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Portefeuille:${NC} $wallet_name"
    echo -e "${BLUE}Clé publique:${NC} ${CYAN}${pubkey:0:8}...${NC}"
    echo -e "${BLUE}Montant:${NC} ${YELLOW}$INIT_AMOUNT Ğ1${NC}"
    echo -e "${BLUE}Source:${NC} ${CYAN}secret.G1.dunikey${NC}"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 SIMULATION: Transaction de $INIT_AMOUNT Ğ1 vers $wallet_name${NC}"
        return 0
    fi
    
    # Execute transaction using PAYforSURE.sh (like in ZEN.COOPERATIVE.3x1-3.sh)
    echo -e "${YELLOW}Exécution de la transaction...${NC}"
    
    # Convert amount to G1 for PAYforSURE.sh
    local transfer_amount_g1=$(echo "scale=2; $INIT_AMOUNT" | bc -l)
    
    # Use PAYforSURE.sh like in the cooperative script
    local transfer_result
    transfer_result=$("${MY_PATH}/tools/PAYforSURE.sh" "$SOURCE_WALLET" "$transfer_amount_g1" "$pubkey" "UPLANET:INIT:$wallet_name" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Transaction réussie pour $wallet_name${NC}"
        echo -e "${GREEN}✅ $wallet_name initialisé avec succès${NC}"
        return 0
    else
        echo -e "${RED}❌ Échec de la transaction pour $wallet_name${NC}"
        echo "$transfer_result"
        return 1
    fi
}

# Function to initialize all empty cooperative wallets
initialize_cooperative_wallets() {
    echo -e "\n${CYAN}🚀 INITIALISATION DES PORTEFEUILLES COOPÉRATIFS${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    
    local wallets_to_initialize=()
    
    # Get list of wallets that need initialization
    for wallet_name in "${!COOPERATIVE_WALLETS[@]}"; do
        local dunikey_file="${COOPERATIVE_WALLETS[$wallet_name]}"
        if [[ -f "$dunikey_file" ]]; then
            local pubkey=$(get_wallet_public_key "$dunikey_file")
            if [[ -n "$pubkey" ]]; then
                local balance=$(get_wallet_balance "$pubkey")
                if (( $(echo "$balance < $MIN_BALANCE" | bc -l) )); then
                    wallets_to_initialize+=("$wallet_name")
                fi
            fi
        fi
    done
    
    if [[ ${#wallets_to_initialize[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ Aucun portefeuille à initialiser${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Portefeuilles à initialiser:${NC} ${CYAN}${#wallets_to_initialize[@]}${NC}"
    echo -e "${BLUE}Montant total:${NC} ${YELLOW}$((${#wallets_to_initialize[@]} * INIT_AMOUNT)) Ğ1${NC}"
    echo ""
    
    # Confirm initialization
    if [[ "$FORCE" != true ]]; then
        echo -e "${YELLOW}⚠️  CONFIRMATION REQUISE${NC}"
        echo -e "${BLUE}Ce processus va:${NC}"
        echo -e "  • Transférer ${YELLOW}$INIT_AMOUNT Ğ1${NC} vers chaque portefeuille vide"
        echo -e "  • Initialiser ${CYAN}$WALLETS_TO_INITIALIZE portefeuilles${NC}"
        echo -e "  • Utiliser ${CYAN}$(basename "$SOURCE_WALLET")${NC} comme source"
        echo ""
        read -p "Confirmer l'initialisation? (y/N): " confirm
        
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${YELLOW}Initialisation annulée.${NC}"
            return 0
        fi
    fi
    
    # Initialize wallets (limit to available balance)
    local success_count=0
    local failure_count=0
    local processed_count=0
    
    for wallet_name in "${wallets_to_initialize[@]}"; do
        # Stop if we've reached the limit based on available balance
        if [[ $processed_count -ge $WALLETS_TO_INITIALIZE ]]; then
            echo -e "${YELLOW}⚠️  Limite atteinte (solde disponible: $WALLETS_TO_INITIALIZE Ğ1)${NC}"
            break
        fi
        
        if initialize_wallet "$wallet_name"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
        
        ((processed_count++))
        
        # Small delay between transactions
        if [[ $processed_count -lt $WALLETS_TO_INITIALIZE ]]; then
            echo -e "${YELLOW}⏳ Pause entre transactions...${NC}"
            sleep 3
        fi
    done
    
    # Summary
    echo -e "\n${CYAN}📊 RÉSUMÉ DE L'INITIALISATION${NC}"
    echo -e "${YELLOW}================================${NC}"
    echo -e "${BLUE}Portefeuilles traités:${NC} ${CYAN}$processed_count${NC}"
    echo -e "${BLUE}Succès:${NC} ${GREEN}$success_count${NC}"
    echo -e "${BLUE}Échecs:${NC} ${RED}$failure_count${NC}"
    
    if [[ $failure_count -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 Tous les portefeuilles coopératifs ont été initialisés avec succès !${NC}"
        echo -e "${GREEN}Chaque portefeuille dispose maintenant de 1 Ğ1 (0 Ẑen après transaction primale).${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Certains portefeuilles n'ont pas pu être initialisés.${NC}"
        echo -e "${YELLOW}Vérifiez les erreurs ci-dessus et réessayez si nécessaire.${NC}"
    fi
}

# Function to initialize node and captain wallets
initialize_node_captain_wallets() {
    echo -e "\n${CYAN}🚀 INITIALISATION DES PORTEFEUILLES NODE ET CAPTAIN${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    
    if [[ ${#NODE_CAPTAIN_TO_INITIALIZE[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ Aucun portefeuille NODE/CAPTAIN à initialiser${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Portefeuilles à initialiser:${NC} ${CYAN}${#NODE_CAPTAIN_TO_INITIALIZE[@]}${NC}"
    echo ""
    
    # Confirm initialization
    if [[ "$FORCE" != true ]]; then
        echo -e "${YELLOW}⚠️  CONFIRMATION REQUISE${NC}"
        echo -e "${BLUE}Ce processus va:${NC}"
        echo -e "  • Transférer ${YELLOW}$INIT_AMOUNT Ğ1${NC} vers chaque portefeuille vide"
        echo -e "  • Initialiser ${CYAN}${#NODE_CAPTAIN_TO_INITIALIZE[@]} portefeuilles${NC} NODE/CAPTAIN"
        echo -e "  • Utiliser ${CYAN}$(basename "$SOURCE_WALLET")${NC} comme source"
        echo ""
        read -p "Confirmer l'initialisation? (y/N): " confirm
        
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${YELLOW}Initialisation annulée.${NC}"
            return 0
        fi
    fi
    
    # Initialize wallets
    local success_count=0
    local failure_count=0
    
    for wallet_type in "${NODE_CAPTAIN_TO_INITIALIZE[@]}"; do
        if initialize_node_captain_wallet "$wallet_type"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
        
        # Small delay between transactions
        if [[ $success_count -lt ${#NODE_CAPTAIN_TO_INITIALIZE[@]} ]]; then
            echo -e "${YELLOW}⏳ Pause entre transactions...${NC}"
            sleep 3
        fi
    done
    
    # Summary
    echo -e "\n${CYAN}📊 RÉSUMÉ DE L'INITIALISATION NODE/CAPTAIN${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${BLUE}Portefeuilles traités:${NC} ${CYAN}${#NODE_CAPTAIN_TO_INITIALIZE[@]}${NC}"
    echo -e "${BLUE}Succès:${NC} ${GREEN}$success_count${NC}"
    echo -e "${BLUE}Échecs:${NC} ${RED}$failure_count${NC}"
    
    if [[ $failure_count -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 Tous les portefeuilles NODE/CAPTAIN ont été initialisés avec succès !${NC}"
        echo -e "${GREEN}Chaque portefeuille dispose maintenant de 1 Ğ1 pour les transactions primales.${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Certains portefeuilles n'ont pas pu être initialisés.${NC}"
        echo -e "${YELLOW}Vérifiez les erreurs ci-dessus et réessayez si nécessaire.${NC}"
    fi
}

# Function to display final status
display_final_status() {
    echo -e "\n${CYAN}📊 STATUT FINAL DE TOUS LES PORTEFEUILLES${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    echo -e "${BLUE}Portefeuilles Coopératifs:${NC}"
    printf "%-25s %-15s %-15s\n" "PORTEFEUILLE" "SOLDE ACTUEL" "STATUT"
    printf "%.0s-" {1..60}
    echo ""
    
    for wallet_name in "${!COOPERATIVE_WALLETS[@]}"; do
        local dunikey_file="${COOPERATIVE_WALLETS[$wallet_name]}"
        local pubkey=""
        local balance="0"
        local status=""
        
        if [[ -f "$dunikey_file" ]]; then
            pubkey=$(get_wallet_public_key "$dunikey_file")
            if [[ -n "$pubkey" ]]; then
                balance=$(get_wallet_balance "$pubkey")
                
                if (( $(echo "$balance >= $MIN_BALANCE" | bc -l) )); then
                    status="✓ Initialisé"
                else
                    status="✗ Vide"
                fi
            else
                status="✗ Erreur clé"
            fi
        else
            status="✗ Fichier manquant"
        fi
        
        printf "%-25s %-15s %-15s\n" \
            "$wallet_name" \
            "$balance Ğ1" \
            "$status"
    done
    
    printf "%.0s-" {1..60}
    echo ""
    
    # Display Node and Captain status
    echo -e "${BLUE}Portefeuilles Node et Captain:${NC}"
    printf "%-25s %-15s %-15s\n" "PORTEFEUILLE" "SOLDE ACTUEL" "STATUT"
    printf "%.0s-" {1..60}
    echo ""
    
    # NODE wallet
    local node_dunikey="${NODE_CAPTAIN_WALLETS["NODE"]}"
    if [[ -f "$node_dunikey" ]]; then
        local node_pubkey=$(get_wallet_public_key "$node_dunikey")
        if [[ -n "$node_pubkey" ]]; then
            local balance=$(get_wallet_balance "$node_pubkey")
            local status=""
            if (( $(echo "$balance >= $MIN_BALANCE" | bc -l) )); then
                status="✓ Initialisé"
            else
                status="✗ Vide"
            fi
            printf "%-25s %-15s %-15s\n" "NODE (Armateur)" "$balance Ğ1" "$status"
        else
            printf "%-25s %-15s %-15s\n" "NODE (Armateur)" "0 Ğ1" "✗ Erreur clé"
        fi
    else
        printf "%-25s %-15s %-15s\n" "NODE (Armateur)" "N/A" "- Non Y-level"
    fi
    
    # CAPTAIN wallets
    local captain_email=$(get_captain_email)
    if [[ -n "$captain_email" ]]; then
        # CAPTAIN MULTIPASS
        local captain_multipass="$HOME/.zen/game/nostr/${captain_email}/.secret.dunikey"
        if [[ -f "$captain_multipass" ]]; then
            local multipass_pubkey=$(get_wallet_public_key "$captain_multipass")
            if [[ -n "$multipass_pubkey" ]]; then
                local balance=$(get_wallet_balance "$multipass_pubkey")
                local status=""
                if (( $(echo "$balance >= $MIN_BALANCE" | bc -l) )); then
                    status="✓ Initialisé"
                else
                    status="✗ Vide"
                fi
                printf "%-25s %-15s %-15s\n" "CAPTAIN MULTIPASS" "$balance Ğ1" "$status"
            else
                printf "%-25s %-15s %-15s\n" "CAPTAIN MULTIPASS" "0 Ğ1" "✗ Erreur clé"
            fi
        else
            printf "%-25s %-15s %-15s\n" "CAPTAIN MULTIPASS" "N/A" "- Non trouvé"
        fi
        
        # CAPTAIN ZEN Card
        local captain_zencard="$HOME/.zen/game/players/${captain_email}/secret.dunikey"
        if [[ -f "$captain_zencard" ]]; then
            local zencard_pubkey=$(get_wallet_public_key "$captain_zencard")
            if [[ -n "$zencard_pubkey" ]]; then
                local balance=$(get_wallet_balance "$zencard_pubkey")
                local status=""
                if (( $(echo "$balance >= $MIN_BALANCE" | bc -l) )); then
                    status="✓ Initialisé"
                else
                    status="✗ Vide"
                fi
                printf "%-25s %-15s %-15s\n" "CAPTAIN ZEN Card" "$balance Ğ1" "$status"
            else
                printf "%-25s %-15s %-15s\n" "CAPTAIN ZEN Card" "0 Ğ1" "✗ Erreur clé"
            fi
        else
            printf "%-25s %-15s %-15s\n" "CAPTAIN ZEN Card" "N/A" "- Non trouvé"
        fi
    else
        printf "%-25s %-15s %-15s\n" "CAPTAIN" "N/A" "- Non configuré"
    fi
    
    printf "%.0s-" {1..60}
    echo ""
}

# Main function
main() {
    echo -e "${CYAN}🌟 UPLANET.INIT.SH - INITIALISATION DES PORTEFEUILLES COOPÉRATIFS${NC}"
    echo -e "${YELLOW}================================================================${NC}"
    echo -e "${GREEN}Vérification et initialisation des portefeuilles de la coopérative UPlanet${NC}"
    echo ""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                echo -e "${RED}Option inconnue: $1${NC}"
                usage
                ;;
        esac
    done
    
    # Check requirements
    check_requirements
    
    # Check source wallet
    check_source_wallet
    
    # Check cooperative wallet status
    cooperative_needs_init=false
    if ! check_cooperative_wallets; then
        cooperative_needs_init=true
    fi
    
    # Check node and captain wallet status
    node_captain_needs_init=false
    if ! check_node_captain_wallets; then
        node_captain_needs_init=true
    fi
    
    # If nothing needs initialization, exit
    if [[ "$cooperative_needs_init" == false && "$node_captain_needs_init" == false ]]; then
        echo -e "${GREEN}✅ Tous les portefeuilles sont déjà initialisés${NC}"
        display_final_status
        exit 0
    fi
    
    # Initialize cooperative wallets
    if [[ "$cooperative_needs_init" == true ]]; then
    initialize_cooperative_wallets
    fi
    
    # Initialize node and captain wallets
    if [[ "$node_captain_needs_init" == true ]]; then
        initialize_node_captain_wallets
    fi
    
    # Display final status
    display_final_status
    
    echo -e "\n${GREEN}🎯 Initialisation terminée !${NC}"
    echo -e "${BLUE}Les portefeuilles coopératifs sont maintenant prêts à fonctionner.${NC}"
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"
