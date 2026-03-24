#!/bin/bash
# -----------------------------------------------------------------------------
# UPLANET.init.sh - Initialisation des Portefeuilles de la Coopérative UPlanet
#
# Ce script vérifie et initialise les portefeuilles de la coopérative UPlanet :
# - UPLANETNAME (Services & MULTIPASS)
# - UPLANETNAME_SOCIETY (Capital social)
# - UPLANETNAME_CASH (Trésorerie - uplanet.CASH.dunikey)
# - UPLANETNAME_RND (R&D - uplanet.RnD.dunikey)
# - UPLANETNAME_ASSETS (Actifs - uplanet.ASSETS.dunikey)
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
    ["UPLANETNAME_SOCIETY"]="$HOME/.zen/game/uplanet.SOCIETY.dunikey"
    ["UPLANETNAME_CASH"]="$HOME/.zen/game/uplanet.CASH.dunikey"
    ["UPLANETNAME_RND"]="$HOME/.zen/game/uplanet.RnD.dunikey"
    ["UPLANETNAME_ASSETS"]="$HOME/.zen/game/uplanet.ASSETS.dunikey"
    ["UPLANETNAME_IMPOT"]="$HOME/.zen/game/uplanet.IMPOT.dunikey"
    ["UPLANETNAME.CAPTAIN"]="$HOME/.zen/game/uplanet.captain.dunikey"
    ["UPLANETNAME_INTRUSION"]="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
    ["UPLANETNAME_CAPITAL"]="$HOME/.zen/game/uplanet.CAPITAL.dunikey"
    ["UPLANETNAME_AMORTISSEMENT"]="$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey"
)

# Node and Captain wallets to check and initialize (if they exist)
declare -A NODE_CAPTAIN_WALLETS=(
    ["NODE"]="$HOME/.zen/game/secret.NODE.dunikey"
)

# NOSTR keys for Oracle and N² Memory systems
declare -A NOSTR_KEYS=(
    ["UPLANETNAME_G1_NOSTR"]="$HOME/.zen/game/uplanet.G1.nostr"
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
    echo -e "  • UPLANETNAME_SOCIETY (Capital social)"
    echo -e "  • UPLANETNAME_CASH (Trésorerie)"
    echo -e "  • UPLANETNAME_RND (R&D)"
    echo -e "  • UPLANETNAME_ASSETS (Actifs)"
    echo -e "  • UPLANETNAME_IMPOT (Fiscalité)"
    echo -e "  • UPLANETNAME.CAPTAIN (Rémunération capitaine)"
    echo -e "  • UPLANETNAME_INTRUSION (Fonds d'intrusions détectées)"
    echo -e "  • UPLANETNAME_CAPITAL (Immobilisations - Compte 21)"
    echo -e "  • UPLANETNAME_AMORTISSEMENT (Amortissements - Compte 28)"
    echo -e "  • NODE (Armateur - revenus locatifs)"
    echo -e "  • CAPTAIN (si configuré)"
    echo ""
    echo -e "${GREEN}Et les clés NOSTR pour:${NC}"
    echo -e "  • ${CYAN}uplanet.G1.nostr${NC} (Ğ1 Central Bank - Oracle + N² Memory)"
    echo ""
    echo -e "${GREEN}Configuration coopérative via DID NOSTR:${NC}"
    echo -e "  • ${CYAN}cooperative-config${NC} (Configuration partagée essaim IPFS)"
    echo -e "  • Valeurs chiffrées avec \$UPLANETNAME (AES-256-CBC)"
    echo -e "  • Stocké dans kind 30800, d-tag 'cooperative-config'"
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

    # Check if source wallet file exists
    if [[ ! -f "$SOURCE_WALLET" ]]; then
        echo -e "${RED}❌ Portefeuille source non trouvé: $SOURCE_WALLET${NC}"
        SOURCE_INSUFFICIENT=1
        return 1
    fi

    echo -e "${GREEN}✅ Portefeuille source trouvé: ${CYAN}$SOURCE_WALLET${NC}"

    # Extract public key from source wallet
    local source_pubkey=$(cat "$SOURCE_WALLET" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    if [[ -z "$source_pubkey" ]]; then
        echo -e "${RED}❌ Impossible d'extraire la clé publique depuis $SOURCE_WALLET${NC}"
        SOURCE_INSUFFICIENT=1
        return 1
    fi

    echo -e "${BLUE}Portefeuille source:${NC} ${CYAN}${source_pubkey:0:8}...${NC}"

    # Check source wallet balance using G1check.sh
    echo -e "${YELLOW}Vérification du solde...${NC}"
    local source_balance=$(get_wallet_balance "$source_pubkey")

    if [[ -z "$source_balance" || "$source_balance" == "null" ]]; then
        echo -e "${YELLOW}⚠️  Impossible de récupérer le solde (réseau indisponible ?)${NC}"
        SOURCE_INSUFFICIENT=1
        return 1
    fi
    
    echo -e "${BLUE}Solde actuel:${NC} ${YELLOW}$source_balance Ğ1${NC}"
    
    # Calculate required amount (dynamic based on COOPERATIVE_WALLETS + NODE + CAPTAIN)
    local coop_count=${#COOPERATIVE_WALLETS[@]}
    local node_captain_estimate=2 # NODE + CAPTAIN
    local required_amount=$((coop_count + node_captain_estimate))
    local available_balance=$(echo "$source_balance" | bc -l 2>/dev/null || echo "0")
    
    # Calculate how many wallets can be initialized
    WALLETS_TO_INITIALIZE=$(echo "$available_balance" | bc -l | cut -d. -f1)
    if [[ -z "$WALLETS_TO_INITIALIZE" ]] || [[ "$WALLETS_TO_INITIALIZE" -lt 1 ]]; then
        WALLETS_TO_INITIALIZE=0
    elif [[ "$WALLETS_TO_INITIALIZE" -gt "$required_amount" ]]; then
        WALLETS_TO_INITIALIZE="$required_amount"
    fi
    
    if (( $(echo "$available_balance < 1" | bc -l) )); then
        echo -e "${YELLOW}⚠️  Solde insuffisant pour les transactions primales${NC}"
        echo -e "${BLUE}Solde disponible:${NC} ${YELLOW}$available_balance Ğ1${NC}"
        echo -e "${BLUE}Solde requis pour initialisation complète:${NC} ${YELLOW}1 Ğ1 minimum${NC}"
        echo -e "${CYAN}Les portefeuilles seront créés ; ajoutez au moins 1 Ğ1 au portefeuille source puis relancez ce script pour finaliser.${NC}"
        SOURCE_INSUFFICIENT=1
        return 1
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
    
    # Use G1check.sh to get balance (stderr to /dev/null to hide log messages)
    local balance_result=$("${MY_PATH}/tools/G1check.sh" "$pubkey" 2>/dev/null)
    local exit_code=$?
    
    # Debug: show raw result if DEBUG mode
    [[ -n "$DEBUG" ]] && echo -e "${YELLOW}DEBUG G1check result: '$balance_result' (exit: $exit_code)${NC}" >&2
    
    # Clean the result: remove whitespace, handle bc format (.45 -> 0.45)
    local balance=$(echo "$balance_result" | tr -d '[:space:]')
    
    # Handle bc format where numbers < 1 start with decimal point (e.g., .45 -> 0.45)
    if [[ "$balance" =~ ^\.([0-9]+)$ ]]; then
        balance="0${balance}"
    fi
    
    # Validate: accept numbers like 123, 123.45, 0.45, .45, 0
    if [[ "$balance" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "$balance"
    else
        # If G1check.sh failed or returned invalid data, return 0
        echo "0"
    fi
}

# Function to get wallet public key from dunikey file and convert to v2 (g1+ss58)
get_wallet_public_key() {
    local dunikey_file="$1"
    
    if [[ -f "$dunikey_file" ]]; then
        local pubkey=$(cat "$dunikey_file" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        echo $($HOME/.zen/Astroport.ONE/tools/g1pub_to_ss58.py "$pubkey")
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
    local keygen_name=""
    local keygen_pass=""

    case "$wallet_name" in
        "UPLANETNAME_CASH")
            keygen_name="${UPLANETNAME}.TREASURY"; keygen_pass="${UPLANETNAME}.TREASURY"
            ;;
        "UPLANETNAME_RND")
            keygen_name="${UPLANETNAME}.RND"; keygen_pass="${UPLANETNAME}.RND"
            ;;
        "UPLANETNAME_ASSETS")
            keygen_name="${UPLANETNAME}.ASSETS"; keygen_pass="${UPLANETNAME}.ASSETS"
            ;;
        "UPLANETNAME_IMPOT")
            keygen_name="${UPLANETNAME}.IMPOT"; keygen_pass="${UPLANETNAME}.IMPOT"
            ;;
        "UPLANETNAME_SOCIETY")
            keygen_name="${UPLANETNAME}.SOCIETY"; keygen_pass="${UPLANETNAME}.SOCIETY"
            ;;
        "UPLANETNAME")
            keygen_name="${UPLANETNAME}"; keygen_pass="${UPLANETNAME}"
            ;;
        "UPLANETNAME.CAPTAIN")
            keygen_name="${UPLANETNAME}.${CAPTAINEMAIL}"; keygen_pass="${UPLANETNAME}.${CAPTAINEMAIL}"
            ;;
        "UPLANETNAME_INTRUSION")
            keygen_name="${UPLANETNAME}.INTRUSION"; keygen_pass="${UPLANETNAME}.INTRUSION"
            ;;
        "UPLANETNAME_CAPITAL")
            keygen_name="${UPLANETNAME}.CAPITAL"; keygen_pass="${UPLANETNAME}.CAPITAL"
            ;;
        "UPLANETNAME_AMORTISSEMENT")
            keygen_name="${UPLANETNAME}.AMORTISSEMENT"; keygen_pass="${UPLANETNAME}.AMORTISSEMENT"
            ;;
        *)
            echo -e "${RED}❌ Type de portefeuille non reconnu: $wallet_name${NC}"
            return 1
            ;;
    esac

    "${MY_PATH}/tools/keygen" -t duniter -o "$dunikey_file" "$keygen_name" "$keygen_pass"
    
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

# Function to check and create NOSTR keys (for Oracle and N² Memory systems)
check_and_create_nostr_keys() {
    echo -e "${CYAN}🔑 VÉRIFICATION DES CLÉS NOSTR (Ğ1 Central Bank)${NC}"
    echo -e "${YELLOW}================================================${NC}"
    
    local keys_created=0
    local keys_exist=0
    
    for key_name in "${!NOSTR_KEYS[@]}"; do
        local key_file="${NOSTR_KEYS[$key_name]}"
        
        if [[ -f "$key_file" ]]; then
            # Prefer NSEC=; NPUB=; HEX= format (same as myswarm_secret.nostr for NIP-101 backfill)
            local npub=$(grep -oP 'NPUB=\K[^;]+' "$key_file" 2>/dev/null || grep -oE 'npub1[a-zA-Z0-9]{58}' "$key_file" 2>/dev/null | head -1)
            local has_hex=$(grep -c 'HEX=' "$key_file" 2>/dev/null || echo 0)
            if [[ -n "$npub" ]]; then
                # Upgrade old format (npub only) to NSEC=; NPUB=; HEX=
                if [[ "$has_hex" == "0" ]] && [[ -x "${MY_PATH}/tools/keygen" ]] && [[ -x "${MY_PATH}/tools/nostr2hex.py" ]]; then
                    local nsec=$(grep -oE 'nsec1[a-zA-Z0-9]{58}' "$key_file" 2>/dev/null | head -1)
                    if [[ -z "$nsec" ]]; then
                        nsec=$("${MY_PATH}/tools/keygen" -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" -s 2>/dev/null | grep -oE 'nsec1[a-zA-Z0-9]{58}' | head -1)
                    fi
                    if [[ -n "$nsec" ]]; then
                        local hex=$("${MY_PATH}/tools/nostr2hex.py" "$npub" 2>/dev/null)
                        if [[ -n "$hex" ]]; then
                            echo "NSEC=$nsec; NPUB=$npub; HEX=$hex;" > "$key_file"
                            chmod 600 "$key_file"
                        fi
                    fi
                fi
                echo -e "${GREEN}✅ $key_name existe${NC}"
                echo -e "   NPUB: ${CYAN}${npub:0:20}...${NC}"
                ((keys_exist++))
            else
                echo -e "${YELLOW}⚠️  $key_name existe mais format invalide${NC}"
            fi
        else
            echo -e "${BLUE}📝 Création de $key_name...${NC}"
            
            # Create directory if needed
            local key_dir=$(dirname "$key_file")
            [[ ! -d "$key_dir" ]] && mkdir -p "$key_dir"
            
            # Generate NOSTR key in NSEC=; NPUB=; HEX= format (same as myswarm_secret.nostr, NIP-101 backfill)
            if [[ -x "${MY_PATH}/tools/keygen" ]] && [[ -x "${MY_PATH}/tools/nostr2hex.py" ]]; then
                local keygen_out=$("${MY_PATH}/tools/keygen" -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" 2>/dev/null)
                local npub=$(echo "$keygen_out" | grep -oE 'npub1[a-zA-Z0-9]{58}' | head -1)
                local nsec=$(echo "$keygen_out" | grep -oE 'nsec1[a-zA-Z0-9]{58}' | head -1)
                if [[ -z "$nsec" ]]; then
                    nsec=$("${MY_PATH}/tools/keygen" -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" -s 2>/dev/null | grep -oE 'nsec1[a-zA-Z0-9]{58}' | head -1)
                fi
                local hex=""
                [[ -n "$npub" ]] && hex=$("${MY_PATH}/tools/nostr2hex.py" "$npub" 2>/dev/null)
                if [[ -n "$npub" ]] && [[ -n "$nsec" ]] && [[ -n "$hex" ]]; then
                    echo "NSEC=$nsec; NPUB=$npub; HEX=$hex;" > "$key_file"
                    chmod 600 "$key_file"
                    echo -e "${GREEN}✅ $key_name créée avec succès${NC}"
                    echo -e "   NPUB: ${CYAN}${npub:0:20}...${NC}"
                    echo -e "   Seed: ${YELLOW}\${UPLANETNAME}.G1${NC}"
                    ((keys_created++))
                else
                    echo -e "${RED}❌ Échec de la création de $key_name${NC}"
                fi
            else
                echo -e "${RED}❌ keygen ou nostr2hex.py non disponible${NC}"
            fi
        fi
    done
    
    echo ""
    if [[ $keys_created -gt 0 ]]; then
        echo -e "${GREEN}🔐 $keys_created clé(s) NOSTR créée(s)${NC}"
        echo -e "${YELLOW}⚠️  Ces clés sont utilisées par:${NC}"
        echo -e "   • Oracle System (NIP-42 auth, kind 30503 credentials)"
        echo -e "   • N² Memory System (kind 31910 recommendations)"
        echo -e "   • Economy (Ğ1 Central Bank authority)"
    fi
    
    if [[ $keys_exist -gt 0 ]]; then
        echo -e "${GREEN}✅ $keys_exist clé(s) NOSTR déjà présente(s)${NC}"
    fi
    
    echo ""
}

# Function to check and initialize cooperative config DID
# Stores encrypted configuration in NOSTR DID for swarm-wide access
check_and_init_cooperative_config() {
    echo -e "${CYAN}📋 VÉRIFICATION DE LA CONFIGURATION COOPÉRATIVE DID${NC}"
    echo -e "${YELLOW}==================================================${NC}"
    
    local config_helper="${MY_PATH}/tools/cooperative_config.sh"
    
    if [[ ! -f "$config_helper" ]]; then
        echo -e "${RED}❌ cooperative_config.sh non trouvé${NC}"
        return 1
    fi
    
    # Source the helper (save/restore MY_PATH as cooperative_config.sh overwrites it)
    local _saved_my_path="$MY_PATH"
    source "$config_helper"
    MY_PATH="$_saved_my_path"
    
    # Check if NOSTR key exists
    if [[ ! -f "$COOP_CONFIG_KEYFILE" ]]; then
        echo -e "${YELLOW}⚠️  Clé NOSTR UPLANETNAME_G1 non trouvée${NC}"
        echo -e "${BLUE}   La configuration coopérative sera initialisée après création de la clé${NC}"
        return 1
    fi
    
    # Get pubkey for display (keyfile may use npub: format from keygen; coop_get_pubkey converts via nostr2hex)
    local pubkey=$(coop_get_pubkey 2>/dev/null)
    if [[ -z "$pubkey" ]]; then
        echo -e "${YELLOW}⚠️  Clé coopérative non lisible (format keyfile) – DID sera initialisé après prochaine exécution${NC}"
        return 1
    fi
    
    echo -e "${BLUE}DID Coopératif:${NC} ${CYAN}did:nostr:${pubkey:0:16}...${NC}"
    echo -e "${BLUE}D-tag:${NC} ${CYAN}$COOP_CONFIG_D_TAG${NC}"
    
    # Try to load existing config
    local existing_config=$(coop_load_config 2>/dev/null)
    
    if [[ -n "$existing_config" ]] && [[ "$existing_config" != "{}" ]]; then
        echo -e "${GREEN}✅ Configuration coopérative existante trouvée${NC}"
        
        # Show config summary (without sensitive values)
        local config_keys=$(echo "$existing_config" | jq -r 'keys | length' 2>/dev/null || echo "0")
        echo -e "${BLUE}   Nombre de clés:${NC} ${CYAN}$config_keys${NC}"
        
        # Check for OpenCollective token
        local has_oc_token=$(echo "$existing_config" | jq -r 'has("OCAPIKEY")' 2>/dev/null)
        if [[ "$has_oc_token" == "true" ]]; then
            echo -e "${GREEN}   ✓ OCAPIKEY configuré${NC}"
        else
            echo -e "${YELLOW}   ⚠️  OCAPIKEY non configuré${NC}"
        fi
        
        # Check for slug
        local oc_slug=$(echo "$existing_config" | jq -r '.OCSLUG // "monnaie-libre"' 2>/dev/null)
        echo -e "${BLUE}   OpenCollective Slug:${NC} ${CYAN}$oc_slug${NC}"
        
    else
        echo -e "${YELLOW}⚠️  Aucune configuration coopérative trouvée${NC}"
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║        🛠️  CONFIGURATION COOPÉRATIVE INTERACTIVE                ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}Voulez-vous configurer les paramètres coopératifs maintenant ?${NC}"
        echo -e "  ${GREEN}[y]${NC} Configurer interactivement (recommandé pour 1er démarrage)"
        echo -e "  ${YELLOW}[n]${NC} Passer avec les valeurs par défaut"
        echo ""
        read -r -t 30 -p "Votre choix (y/N) : " _coop_choice
        echo ""

        # Initialize default config first (always needed)
        echo -e "${BLUE}   Initialisation de la configuration par défaut...${NC}"
        coop_config_init 2>/dev/null
        _coop_init_ok=$?

        if [[ $_coop_init_ok -eq 0 ]]; then
            echo -e "${GREEN}✅ Configuration coopérative initialisée${NC}"
        else
            echo -e "${RED}❌ Échec de l'initialisation de la configuration${NC}"
            return 1
        fi

        if [[ "${_coop_choice,,}" == "y" ]]; then
            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}📋 PARAMÈTRES ÉCONOMIQUES${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

            # PAF
            read -r -t 30 -p "$(echo -e "${BLUE}PAF hebdomadaire (défaut: 14 Ẑen) :${NC} ")" _input_paf
            if [[ -n "$_input_paf" && "$_input_paf" =~ ^[0-9]+$ ]]; then
                coop_config_set PAF "$_input_paf" 2>/dev/null \
                    && echo -e "${GREEN}  ✓ PAF = $_input_paf Ẑen${NC}"
            else
                echo -e "${YELLOW}  → PAF = 14 Ẑen (défaut)${NC}"
            fi

            # NCARD
            read -r -t 30 -p "$(echo -e "${BLUE}Coût hebdo MULTIPASS NCARD (défaut: 1 Ẑen) :${NC} ")" _input_ncard
            if [[ -n "$_input_ncard" && "$_input_ncard" =~ ^[0-9]+$ ]]; then
                coop_config_set NCARD "$_input_ncard" 2>/dev/null \
                    && echo -e "${GREEN}  ✓ NCARD = $_input_ncard Ẑen${NC}"
            else
                echo -e "${YELLOW}  → NCARD = 1 Ẑen (défaut)${NC}"
            fi

            # ZCARD
            read -r -t 30 -p "$(echo -e "${BLUE}Coût hebdo ZEN Card ZCARD (défaut: 4 Ẑen) :${NC} ")" _input_zcard
            if [[ -n "$_input_zcard" && "$_input_zcard" =~ ^[0-9]+$ ]]; then
                coop_config_set ZCARD "$_input_zcard" 2>/dev/null \
                    && echo -e "${GREEN}  ✓ ZCARD = $_input_zcard Ẑen${NC}"
            else
                echo -e "${YELLOW}  → ZCARD = 4 Ẑen (défaut)${NC}"
            fi

            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}🌐 OPENCOLLECTIVE (optionnel — pour conversion Ẑen → €)${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}   Obtenez votre token sur :${NC}"
            echo -e "   ${CYAN}https://opencollective.com/dashboard/monnaie-libre/admin/for-developers${NC}"
            echo ""

            # OCSLUG
            read -r -t 30 -p "$(echo -e "${BLUE}Slug OpenCollective (ex: monnaie-libre) :${NC} ")" _input_ocslug
            if [[ -n "$_input_ocslug" ]]; then
                coop_config_set OCSLUG "$_input_ocslug" 2>/dev/null \
                    && echo -e "${GREEN}  ✓ OCSLUG = $_input_ocslug${NC}"
            else
                echo -e "${YELLOW}  → OCSLUG non configuré (PAF burn désactivé)${NC}"
            fi

            # OCAPIKEY (sensitive — auto-encrypted)
            read -r -t 60 -s -p "$(echo -e "${BLUE}Token API OpenCollective (laissez vide pour passer) :${NC} ")" _input_ockey
            echo ""
            if [[ -n "$_input_ockey" ]]; then
                coop_config_set OCAPIKEY "$_input_ockey" 2>/dev/null \
                    && echo -e "${GREEN}  ✓ OCAPIKEY configuré (chiffré)${NC}"
            else
                echo -e "${YELLOW}  → OCAPIKEY non configuré (conversion manuelle requise)${NC}"
            fi

            # PLANTNET_API_KEY (sensitive — auto-encrypted)
            read -r -t 30 -s -p "$(echo -e "${BLUE}Clé API PlantNet (laissez vide pour passer) :${NC} ")" _input_plantnet
            echo ""
            if [[ -n "$_input_plantnet" ]]; then
                coop_config_set PLANTNET_API_KEY "$_input_plantnet" 2>/dev/null \
                    && echo -e "${GREEN}  ✓ PLANTNET_API_KEY configuré (chiffré)${NC}"
            else
                echo -e "${YELLOW}  → PLANTNET_API_KEY non configuré${NC}"
            fi

            echo ""
            echo -e "${GREEN}✅ Configuration coopérative personnalisée enregistrée.${NC}"
        else
            echo -e "${YELLOW}ℹ️  Configuration par défaut conservée. Pour modifier plus tard :${NC}"
            echo ""
            echo -e "   ${CYAN}source ${config_helper}${NC}"
            echo -e "   ${CYAN}coop_config_set PAF 14${NC}"
            echo -e "   ${CYAN}coop_config_set OCSLUG \"monnaie-libre\"${NC}"
            echo -e "   ${CYAN}coop_config_set OCAPIKEY \"votre_token\"${NC}"
        fi
    fi
    
    echo ""
}

# Function to display cooperative config
show_cooperative_config() {
    echo -e "${CYAN}📋 CONFIGURATION COOPÉRATIVE (DID NOSTR)${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    local config_helper="${MY_PATH}/tools/cooperative_config.sh"
    
    if [[ -f "$config_helper" ]]; then
        # Save/restore MY_PATH as cooperative_config.sh overwrites it
        local _saved_my_path="$MY_PATH"
        source "$config_helper"
        MY_PATH="$_saved_my_path"
        coop_config_list
    else
        echo -e "${YELLOW}⚠️  cooperative_config.sh non disponible${NC}"
    fi
    
    echo ""
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

        # Check CAPTAIN MULTIPASS (G1 pubkey is in G1PUBNOSTR, primo TX done by make_NOSTRCARD.sh)
        local captain_multipass_pub="$HOME/.zen/game/nostr/${captain_email}/G1PUBNOSTR"
        if [[ -s "$captain_multipass_pub" ]]; then
            local multipass_pubkey=$(cat "$captain_multipass_pub" 2>/dev/null)
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
            pubkey=$(get_wallet_public_key "$dunikey_file")
            ;;
        "CAPTAIN_MULTIPASS")
            description="Initialisation CAPTAIN MULTIPASS"
            ## MULTIPASS has no dunikey — G1 pubkey is in G1PUBNOSTR (primo TX done by make_NOSTRCARD.sh)
            pubkey=$(cat "$HOME/.zen/game/nostr/${captain_email}/G1PUBNOSTR" 2>/dev/null)
            ;;
        "CAPTAIN_ZENCARD")
            dunikey_file="$HOME/.zen/game/players/${captain_email}/secret.dunikey"
            description="Initialisation CAPTAIN ZEN Card"
            pubkey=$(get_wallet_public_key "$dunikey_file")
            ;;
        *)
            echo -e "${RED}❌ Type de portefeuille non reconnu: $wallet_type${NC}"
            return 1
            ;;
    esac

    # Get destination public key
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
    transfer_result=$("${MY_PATH}/tools/PAYforSURE.sh" "$SOURCE_WALLET" "$transfer_amount_g1" "$pubkey" "UPLANET:${UPLANETG1PUB:0:8}:INIT:$wallet_type" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Transaction réussie pour $wallet_type${NC}"
        echo -e "${GREEN}✅ $wallet_type initialisé avec succès${NC}"
        # Invalider le cache pour ce wallet et la source
        rm -f "${HOME}/.zen/tmp/coucou/${pubkey}.COINS" 2>/dev/null
        local source_pub
        source_pub=$(grep '^pub:' "$SOURCE_WALLET" | awk '{print $2}')
        [[ -n "$source_pub" ]] && rm -f "${HOME}/.zen/tmp/coucou/${source_pub}.COINS" 2>/dev/null
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
    transfer_result=$("${MY_PATH}/tools/PAYforSURE.sh" "$SOURCE_WALLET" "$transfer_amount_g1" "$pubkey" "UPLANET:${UPLANETG1PUB:0:8}:INIT:$wallet_name" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Transaction réussie pour $wallet_name${NC}"
        echo -e "${GREEN}✅ $wallet_name initialisé avec succès${NC}"
        # Invalider le cache pour ce wallet et la source
        rm -f "${HOME}/.zen/tmp/coucou/${pubkey}.COINS" 2>/dev/null
        local source_pub
        source_pub=$(grep '^pub:' "$SOURCE_WALLET" | awk '{print $2}')
        [[ -n "$source_pub" ]] && rm -f "${HOME}/.zen/tmp/coucou/${source_pub}.COINS" 2>/dev/null
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
    # Invalider le cache G1check pour forcer un refresh depuis le squid
    echo -e "\n${YELLOW}Invalidation du cache G1check...${NC}"
    find "${HOME}/.zen/tmp/coucou" -name "*.COINS" -delete 2>/dev/null

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
        # CAPTAIN MULTIPASS (G1 pubkey is in G1PUBNOSTR, not in a dunikey file)
        local captain_multipass_pub="$HOME/.zen/game/nostr/${captain_email}/G1PUBNOSTR"
        if [[ -s "$captain_multipass_pub" ]]; then
            local multipass_pubkey=$(cat "$captain_multipass_pub" 2>/dev/null)
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
    
    # Check and create NOSTR keys (Ğ1 Central Bank for Oracle + N² Memory)
    check_and_create_nostr_keys
    
    # Check and initialize cooperative config DID (encrypted config in NOSTR)
    check_and_init_cooperative_config
    
    # Check source wallet (may set SOURCE_INSUFFICIENT=1 without exiting)
    SOURCE_INSUFFICIENT=0
    check_source_wallet || true
    
    # Check cooperative wallet status (creates missing wallet files even if source has 0 balance)
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
    
    # Skip PAY steps when source has insufficient balance (wallets already created above)
    if [[ "${SOURCE_INSUFFICIENT:-0}" == "1" ]]; then
        echo ""
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}📋 Portefeuilles créés. Pour finaliser l'initialisation :${NC}"
        echo -e "   1. Alimentez le portefeuille source avec au moins ${GREEN}1 Ğ1${NC}"
        local source_pub=$(cat "$SOURCE_WALLET" 2>/dev/null | grep 'pub:' | cut -d ' ' -f 2)
        [[ -n "$source_pub" ]] && echo -e "   2. Adresse source (uplanet.G1) : ${CYAN}$source_pub${NC}"
        echo -e "   3. Relancez : ${CYAN}$MY_PATH/UPLANET.init.sh${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        display_final_status
        exit 0
    fi
    
    # Initialize cooperative wallets (PAY 1 G1 to each)
    if [[ "$cooperative_needs_init" == true ]]; then
        initialize_cooperative_wallets
    fi
    
    # Initialize node and captain wallets
    if [[ "$node_captain_needs_init" == true ]]; then
        initialize_node_captain_wallets
    fi
    
    # Display final status
    display_final_status
    
    # Display cooperative config summary
    show_cooperative_config
    
    echo -e "\n${GREEN}🎯 Initialisation terminée !${NC}"
    echo -e "${BLUE}Les portefeuilles coopératifs sont maintenant prêts à fonctionner.${NC}"
    echo ""
    echo -e "${CYAN}💡 Configuration coopérative partagée via DID NOSTR:${NC}"
    echo -e "   ${BLUE}Toutes les machines de l'essaim IPFS partagent la même configuration.${NC}"
    echo -e "   ${BLUE}Les valeurs sensibles sont chiffrées avec \$UPLANETNAME.${NC}"
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"
