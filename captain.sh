#!/bin/bash
# -----------------------------------------------------------------------------
# captain.sh - Astroport.ONE Captain Onboarding Script
#
# This script handles the onboarding process for new captains on Astroport.ONE
# It guides users through creating their first MULTIPASS and ZEN Card identities.
# For existing captains, it provides an economic dashboard and navigation.
#
# Usage: ./captain.sh [options]
# Options:
#   --auto          - Automatic mode with default values
#   --email EMAIL   - Pre-set email address
#   --lat LAT       - Pre-set latitude
#   --lon LON       - Pre-set longitude
#   --lang LANG     - Pre-set language (default: en)
#   --help          - Show this help message
# -----------------------------------------------------------------------------

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ME="${0##*/}"

# Chargement des variables d'environnement
. "${MY_PATH}/tools/my.sh"

# Chargement de la configuration coopérative (DID NOSTR)
COOP_CONFIG_HELPER="${MY_PATH}/tools/cooperative_config.sh"
if [[ -f "$COOP_CONFIG_HELPER" ]]; then
    source "$COOP_CONFIG_HELPER" 2>/dev/null || true
    COOP_CONFIG_AVAILABLE=true
else
    COOP_CONFIG_AVAILABLE=false
fi

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales
AUTO_MODE=false
PRESET_EMAIL=""
PRESET_LAT=""
PRESET_LON=""
PRESET_LANG="en"

# Fonctions d'affichage
print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    printf "║%*s║\n" $((78)) ""
    printf "║%*s%s%*s║\n" $(((78-${#1})/2)) "" "$1" $(((78-${#1})/2)) ""
    printf "║%*s║\n" $((78)) ""
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "│ %-76s │\n" "$1"
    echo "└──────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Fonction pour afficher l'aide
show_help() {
    echo -e "${WHITE}Usage: $ME [options]${NC}"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "  --auto          - Automatic mode with default values"
    echo "  --email EMAIL   - Pre-set email address"
    echo "  --lat LAT       - Pre-set latitude"
    echo "  --lon LON       - Pre-set longitude"
    echo "  --lang LANG     - Pre-set language (default: en)"
    echo "  --help          - Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $ME                                    # Interactive mode"
    echo "  $ME --auto                            # Automatic mode"
    echo "  $ME --email user@domain.com --lat 48.8566 --lon 2.3522"
    echo "  $ME --email user@domain.com --auto"
    echo ""
    exit 0
}

# Fonction de parsing des arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --email)
                PRESET_EMAIL="$2"
                shift 2
                ;;
            --lat)
                PRESET_LAT="$2"
                shift 2
                ;;
            --lon)
                PRESET_LON="$2"
                shift 2
                ;;
            --lang)
                PRESET_LANG="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                ;;
            *)
                print_error "Option inconnue: $1"
                show_help
                ;;
        esac
    done
}

# Fonction pour vérifier si le capitaine est configuré
check_captain_configured() {
    # Vérifier si le lien .current existe et pointe vers un dossier valide
    if [[ -L ~/.zen/game/players/.current ]] && [[ -d ~/.zen/game/players/.current ]]; then
        local player_file="$HOME/.zen/game/players/.current/.player"
        if [[ -f "$player_file" ]]; then
            local captain_email=$(cat "$player_file" 2>/dev/null | tr -d '\n')
            if [[ -n "$captain_email" ]]; then
                # Vérifier que le MULTIPASS et la ZEN Card existent
                if [[ -d ~/.zen/game/nostr/$captain_email ]] && [[ -d ~/.zen/game/players/$captain_email ]]; then
                    return 0  # Capitaine configuré
                fi
            fi
        fi
    fi
    return 1  # Capitaine non configuré
}

# Fonction pour vérifier si c'est la première utilisation
check_first_time_usage() {
    # Vérifier s'il y a des cartes existantes
    local nostr_cards=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
    local zen_cards=$(ls ~/.zen/game/players 2>/dev/null | grep "@" | wc -l)
    
    if [[ $nostr_cards -eq 0 && $zen_cards -eq 0 ]]; then
        return 0  # Première utilisation
    else
        return 1  # Pas la première utilisation
    fi
}

# Fonction pour récupérer la géolocalisation automatique
get_auto_geolocation() {
    print_info "Récupération automatique de votre localisation..."
    GEO_INFO=$(curl -s ipinfo.io/json 2>/dev/null)
    
    if [[ -n "$GEO_INFO" ]]; then
        AUTO_LAT=$(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f1 2>/dev/null)
        AUTO_LON=$(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f2 2>/dev/null)
        
        if [[ "$AUTO_LAT" != "null" && "$AUTO_LON" != "null" ]]; then
            print_success "Localisation détectée: $AUTO_LAT, $AUTO_LON"
            return 0
        fi
    fi
    
    print_warning "Impossible de détecter automatiquement la localisation"
    return 1
}

# Fonction pour créer un MULTIPASS
create_multipass() {
    local email="$1"
    local lat="$2"
    local lon="$3"
    local lang="$4"
    
    print_section "CRÉATION DU COMPTE MULTIPASS"
    
    if [[ "$AUTO_MODE" == "false" ]]; then
        echo -e "${CYAN}Nous allons créer votre compte MULTIPASS en ligne de commande.${NC}"
        echo ""
    fi
    
    # Validation des paramètres
    if [[ -z "$email" ]]; then
        print_error "Email requis pour créer un MULTIPASS"
        return 1
    fi
    
    # Valeurs par défaut
    [[ -z "$lat" ]] && lat="0.00"
    [[ -z "$lon" ]] && lon="0.00"
    [[ -z "$lang" ]] && lang="en"
    
    print_info "Création de la MULTIPASS pour $email..."
    print_info "Coordonnées: $lat, $lon"
    print_info "Langue: $lang"
    
    if "${MY_PATH}/tools/make_NOSTRCARD.sh" "$email" "$lang" "$lat" "$lon"; then
        ## MAILJET SEND MULTIPASS
        YOUSER=$(${HOME}/.zen/Astroport.ONE/tools/clyuseryomail.sh ${email})
        ${HOME}/.zen/Astroport.ONE/tools/mailjet.sh --template "${HOME}/.zen/game/nostr/${email}/.nostr.zine.html" --expire 0s "${email}" "${HOME}/.zen/game/nostr/${email}/.nostr.zine.html" "$YOUSER MULTIPASS"
        
        print_success "MULTIPASS créée avec succès pour $email !"
        return 0
    else
        print_error "Erreur lors de la création de la MULTIPASS"
        return 1
    fi
}

# Fonction pour créer une ZEN Card
create_zen_card() {
    local email="$1"
    local lat="$2"
    local lon="$3"
    local npub="$4"
    local hex="$5"
    
    print_section "CRÉATION DE LA ZEN CARD"
    
    if [[ "$AUTO_MODE" == "false" ]]; then
        echo -e "${CYAN}Nous allons utiliser les informations de votre compte MULTIPASS pour créer votre ZEN Card.${NC}"
        echo ""
        echo -e "${YELLOW}Informations récupérées de votre MULTIPASS:${NC}"
        [[ -n "$npub" ]] && echo -e "  🔑 NPUB: ${GREEN}$npub${NC}"
        [[ -n "$hex"  ]] && echo -e "  🟩 HEX:  ${GREEN}$hex${NC}"
        echo -e "  📍 Latitude:  ${GREEN}$lat${NC}"
        echo -e "  📍 Longitude: ${GREEN}$lon${NC}"
        echo -e "  📧 Email:     ${GREEN}$email${NC}"
        echo ""
        read -p "Voulez-vous utiliser ces informations pour créer la ZEN Card ? (oui/non): " use_multipass_info
        if [[ "$use_multipass_info" != "oui" && "$use_multipass_info" != "o" && \
              "$use_multipass_info" != "y"   && "$use_multipass_info" != "yes" ]]; then
            print_info "Création de la ZEN Card annulée"
            return 1
        fi
    fi
    
    # Créer la ZEN Card avec les informations du MULTIPASS
    print_info "Création de la ZEN Card..."
    
    # Génération automatique des secrets
    local ppass=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)
    local npass=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) )) | xargs)
    
    print_info "Secret 1 généré: $ppass"
    print_info "Secret 2 généré: $npass"
    
    # Créer la ZEN Card
    if "${MY_PATH}/RUNTIME/VISA.new.sh" "$ppass" "$npass" "$email" "UPlanet" "$PRESET_LANG" "$lat" "$lon" "$npub" "$hex"; then
        local pseudo=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null)
        rm -f ~/.zen/tmp/PSEUDO
        
        print_success "ZEN Card créée avec succès pour $pseudo!"
        
        # Définir comme carte courante
        local player="$email"
        local g1pub=$(cat ~/.zen/game/players/$player/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
        local astronautens=$(ipfs key list -l | grep -w "$player" | head -n1 | cut -d ' ' -f 1)
        
        # Mettre à jour .current (créer le lien symbolique)
        rm -f ~/.zen/game/players/.current
        ln -s ~/.zen/game/players/${player} ~/.zen/game/players/.current
        
        print_success "Lien .current créé vers ${player}"
        echo ""
        echo -e "${GREEN}✅ ZEN Card configurée:${NC}"
        echo "  • ZEN Card: $player"
        echo "  • G1PUB: $g1pub"
        echo "  • IPNS: $myIPFS/ipns/$astronautens"
        echo "  • Lien .current: ~/.zen/game/players/.current → $player"
        echo ""
        
        # Proposer d'imprimer la VISA en mode interactif
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "Voulez-vous imprimer votre VISA maintenant ? (oui/non): " print_visa
            if [[ "$print_visa" == "oui" || "$print_visa" == "o" || "$print_visa" == "y" || "$print_visa" == "yes" ]]; then
                print_info "Impression de la VISA..."
                "${MY_PATH}/tools/VISA.print.sh" "$player"
            fi
        fi
        
        return 0
    else
        print_error "Erreur lors de la création de la ZEN Card"
        return 1
    fi
}

# Fonction pour récupérer les informations du MULTIPASS
get_multipass_info() {
    local email="$1"
    local multipass_dir="$HOME/.zen/game/nostr/$email"
    local npub=""
    local hex=""
    local lat=""
    local lon=""
    
    if [[ -d "$multipass_dir" ]]; then
        # Récupérer NPUB
        if [[ -f "$multipass_dir/NPUB" ]]; then
            npub=$(cat "$multipass_dir/NPUB")
        fi
        
        # Récupérer HEX
        if [[ -f "$multipass_dir/HEX" ]]; then
            hex=$(cat "$multipass_dir/HEX")
        fi
        
        # Récupérer GPS
        if [[ -f "$multipass_dir/GPS" ]]; then
            source "$multipass_dir/GPS"
            lat=$LAT
            lon=$LON
        fi
    fi
    
    echo "$npub|$hex|$lat|$lon"
}

# Fonction pour obtenir le solde d'un portefeuille depuis le cache
get_wallet_balance() {
    local pubkey="$1"
    
    # Utiliser le cache si disponible
    local cache_file="$HOME/.zen/tmp/coucou/${pubkey}.COINS"
    if [[ -f "$cache_file" ]]; then
        local balance=$(cat "$cache_file" 2>/dev/null)
        if [[ -n "$balance" && "$balance" != "null" ]]; then
            echo "$balance"
            return 0
        fi
    fi
    
    # Fallback: actualiser le cache
    "${MY_PATH}/tools/G1check.sh" "$pubkey" >/dev/null 2>&1
    local balance=$(cat "$cache_file" 2>/dev/null)
    if [[ -n "$balance" && "$balance" != "null" ]]; then
        echo "$balance"
    else
        echo "0"
    fi
}

# Fonction pour calculer les Ẑen (excluant la transaction primale)
calculate_zen() {
    local g1_balance="$1"
    
    if (( $(echo "$g1_balance > 1" | bc -l 2>/dev/null) )); then
        local zen=$(echo "scale=1; ($g1_balance - 1) * 10" | bc -l 2>/dev/null)
        echo "$zen"
    else
        echo "0"
    fi
}

# Fonction pour convertir Ẑen en Ğ1
# Taux standard : 1Ẑ = 0.1Ğ1 (ou 10Ẑ = 1Ğ1)
zen_to_g1() {
    local zen_amount="$1"
    
    # Valider que l'entrée est un nombre
    if [[ -z "$zen_amount" ]] || ! [[ "$zen_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "0"
        return 1
    fi
    
    echo "scale=2; $zen_amount / 10" | bc -l
}

# Fonction pour récupérer les données de revenu depuis G1revenue.sh
get_revenue_data() {
    local revenue_json=$(${MY_PATH}/tools/G1revenue.sh 2>/dev/null)
    
    if [[ -n "$revenue_json" ]] && echo "$revenue_json" | jq empty 2>/dev/null; then
        echo "$revenue_json"
        return 0
    else
        echo '{"total_revenue_zen": 0, "total_revenue_g1": 0, "total_transactions": 0}'
        return 1
    fi
}

# Fonction pour récupérer les données de capital social depuis G1society.sh
get_society_data() {
    local society_json=$(${MY_PATH}/tools/G1society.sh 2>/dev/null)
    
    if [[ -n "$society_json" ]] && echo "$society_json" | jq empty 2>/dev/null; then
        echo "$society_json"
        return 0
    else
        echo '{"total_outgoing_zen": 0, "total_outgoing_g1": 0, "total_transfers": 0}'
        return 1
    fi
}

# Fonction pour afficher le statut de la configuration coopérative
show_cooperative_config_status() {
    if [[ "$COOP_CONFIG_AVAILABLE" != "true" ]]; then
        return
    fi
    
    # Vérifier rapidement l'état de la configuration DID
    local config_ok=true
    local missing_keys=0
    local configured_apis=0
    
    # Vérifier les clés essentielles
    local essential_keys=("NCARD" "ZCARD" "TVA_RATE")
    for key in "${essential_keys[@]}"; do
        local value=$(coop_config_get "$key" 2>/dev/null)
        if [[ -z "$value" ]]; then
            missing_keys=$((missing_keys + 1))
            config_ok=false
        fi
    done
    
    # Vérifier les APIs configurées
    local api_keys=("OCAPIKEY" "PLANTNET_API_KEY")
    for key in "${api_keys[@]}"; do
        local value=$(coop_config_get "$key" 2>/dev/null)
        if [[ -n "$value" ]]; then
            configured_apis=$((configured_apis + 1))
        fi
    done
    
    # Afficher un résumé compact
    if [[ "$config_ok" == "true" ]]; then
        if [[ $configured_apis -gt 0 ]]; then
            echo -e "${GREEN}⚙️  Config coopérative DID: ✅ OK (${configured_apis} API configurées)${NC}"
        else
            echo -e "${GREEN}⚙️  Config coopérative DID: ✅ OK${NC} ${YELLOW}(APIs non configurées)${NC}"
        fi
    else
        echo -e "${YELLOW}⚙️  Config coopérative DID: ⚠️  ${missing_keys} paramètres manquants${NC}"
        echo -e "   ${CYAN}→ Utilisez 'c' pour configurer${NC}"
    fi
    echo ""
}

# Fonction pour afficher un résumé rapide de la santé de l'essaim
show_quick_swarm_health() {
    local swarm_cache="$HOME/.zen/tmp/swarm"
    local stations_red=0
    local stations_orange=0
    local total_stations=1  # Station locale
    
    # Vérifier la station locale
    local local_json="$HOME/.zen/tmp/${IPFSNODEID}/12345.json"
    if [[ -f "$local_json" ]]; then
        local local_risk=$(cat "$local_json" | jq -r '.economy.risk_level // "UNKNOWN"' 2>/dev/null)
        [[ "$local_risk" == "RED" ]] && stations_red=$((stations_red + 1))
        [[ "$local_risk" == "ORANGE" ]] && stations_orange=$((stations_orange + 1))
    fi
    
    # Scanner les stations de l'essaim
    if [[ -d "$swarm_cache" ]]; then
        for station_json in "$swarm_cache"/*/12345.json; do
            [[ ! -f "$station_json" ]] && continue
            
            # Vérifier la fraîcheur (< 24h)
            local file_age=$(( $(date +%s) - $(stat -c %Y "$station_json" 2>/dev/null || echo 0) ))
            [[ $file_age -gt 86400 ]] && continue
            
            # Vérifier le même UPlanet
            local uplanet_pub=$(cat "$station_json" | jq -r '.UPLANETG1PUB // ""' 2>/dev/null)
            [[ "$uplanet_pub" != "$UPLANETG1PUB" && -n "$uplanet_pub" ]] && continue
            
            local risk=$(cat "$station_json" | jq -r '.economy.risk_level // "UNKNOWN"' 2>/dev/null)
            [[ "$risk" == "UNKNOWN" || "$risk" == "null" ]] && continue
            
            total_stations=$((total_stations + 1))
            [[ "$risk" == "RED" ]] && stations_red=$((stations_red + 1))
            [[ "$risk" == "ORANGE" ]] && stations_orange=$((stations_orange + 1))
        done
    fi
    
    # Afficher un résumé compact
    if [[ $stations_red -gt 0 ]]; then
        print_section "🚨 ALERTE ESSAIM"
        echo -e "${RED}⛔ $stations_red station(s) en FAILLITE sur $total_stations${NC}"
        echo -e "${YELLOW}💡 Utilisez l'option 6 pour plus de détails${NC}"
        echo ""
    elif [[ $stations_orange -gt 0 ]]; then
        print_section "⚠️  SURVEILLANCE ESSAIM"
        echo -e "${YELLOW}⚠️  $stations_orange station(s) en solidarité active sur $total_stations${NC}"
        echo ""
    else
        if [[ $total_stations -gt 1 ]]; then
            echo -e "${GREEN}🌐 Essaim: $total_stations stations en bonne santé${NC}"
            echo ""
        fi
    fi
}

# Fonction pour afficher le tableau de bord économique du capitaine
show_captain_dashboard() {
    print_header "ASTROPORT.ONE - TABLEAU DE BORD DU CAPITAINE"
    
    # Récupérer le capitaine actuel
    local current_captain=""
    if [[ -L ~/.zen/game/players/.current ]] && [[ -f ~/.zen/game/players/.current/.player ]]; then
        current_captain=$(cat ~/.zen/game/players/.current/.player 2>/dev/null | tr -d '\n')
    fi
    
    if [[ -z "$current_captain" ]]; then
        print_error "Aucun capitaine connecté"
        echo ""
        echo -e "${YELLOW}💡 Il semble que votre compte Capitaine ne soit pas configuré.${NC}"
        echo ""
        
        # Vérifier s'il y a des cartes existantes
        local nostr_cards=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
        local zen_cards=$(ls ~/.zen/game/players 2>/dev/null | grep "@" | wc -l)
        
        if [[ $nostr_cards -gt 0 || $zen_cards -gt 0 ]]; then
            echo -e "${CYAN}📋 Des comptes existent mais aucun n'est configuré comme Capitaine.${NC}"
            echo ""
            
            # Proposer de créer le compte Capitaine
            if [[ "$AUTO_MODE" == "false" ]]; then
                read -p "Voulez-vous configurer un compte Capitaine maintenant ? (oui/non): " setup_captain
                if [[ "$setup_captain" == "oui" || "$setup_captain" == "o" || "$setup_captain" == "y" || "$setup_captain" == "yes" ]]; then
                    embark_captain
                    return $?
                fi
            else
                # Mode automatique : proposer l'embarquement
                print_info "Lancement de la configuration du Capitaine..."
                embark_captain
                return $?
            fi
        else
            # Aucune carte existante : proposer l'embarquement complet
            echo -e "${CYAN}📋 Aucun compte n'existe encore.${NC}"
            echo ""
            
            if [[ "$AUTO_MODE" == "false" ]]; then
                read -p "Voulez-vous créer votre compte Capitaine maintenant ? (oui/non): " create_captain
                if [[ "$create_captain" == "oui" || "$create_captain" == "o" || "$create_captain" == "y" || "$create_captain" == "yes" ]]; then
                    embark_captain
                    return $?
                fi
            else
                # Mode automatique : lancer l'embarquement
                print_info "Lancement de la création du compte Capitaine..."
                embark_captain
                return $?
            fi
        fi
        
        return 1
    fi
    
    echo -e "${GREEN}👑 CAPITAINE ACTUEL: ${WHITE}$current_captain${NC}"
    echo ""
    
    # Informations détaillées du capitaine
    show_captain_details "$current_captain"
    
    # Portefeuilles système UPlanet
    print_section "PORTEFEUILLES SYSTÈME UPLANET"
    
    # UPLANETNAME_G1 (Réserve Ğ1) - Source primale, pas de conversion ẐEN
    local uplanet_g1_pubkey=""
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        uplanet_g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1" 2>/dev/null)
    fi
    
    if [[ -n "$uplanet_g1_pubkey" ]]; then
        local g1_balance=$(get_wallet_balance "$uplanet_g1_pubkey")
        echo -e "${BLUE}🏛️  UPLANETNAME_G1 (Réserve Ğ1):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$g1_balance Ğ1${NC}"
        echo -e "  📝 Usage: Source primale - Alimentation de tous les portefeuilles"
        echo -e "  ℹ️  Note: Réserve en Ğ1 pure (non convertie en ẐEN)"
        echo ""
    else
        echo -e "${RED}🏛️  UPLANETNAME_G1: ${YELLOW}Non configuré${NC}"
        echo -e "  💡 Pour configurer: Lancez UPLANET.init.sh"
        echo ""
    fi
    
    # UPLANETG1PUB (Services & Cash-Flow) - Utilise G1revenue.sh pour l'historique
    local uplanet_services_pubkey=""
    if [[ -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        uplanet_services_pubkey=$(cat "$HOME/.zen/tmp/UPLANETG1PUB" 2>/dev/null)
    fi
    
    if [[ -n "$uplanet_services_pubkey" ]]; then
        local services_balance=$(get_wallet_balance "$uplanet_services_pubkey")
        
        # Récupérer les données de revenu depuis G1revenue.sh (historique analysé)
        local revenue_data=$(get_revenue_data)
        local revenue_zen=$(echo "$revenue_data" | jq -r '.total_revenue_zen // 0' 2>/dev/null)
        local revenue_g1=$(echo "$revenue_data" | jq -r '.total_revenue_g1 // 0' 2>/dev/null)
        local revenue_txcount=$(echo "$revenue_data" | jq -r '.total_transactions // 0' 2>/dev/null)
        
        echo -e "${BLUE}💼 UPLANETNAME (Services & MULTIPASS):${NC}"
        echo -e "  💰 Solde brut: ${YELLOW}$services_balance Ğ1${NC}"
        echo -e "  📊 Chiffre d'Affaires (historique ZENCOIN): ${CYAN}$revenue_zen Ẑen${NC} (${YELLOW}$revenue_g1 Ğ1${NC})"
        echo -e "  📈 Ventes de services: ${WHITE}$revenue_txcount${NC} transactions"
        echo -e "  📝 Usage: Revenus locatifs MULTIPASS + services"
        echo ""
    else
        echo -e "${RED}💼 UPLANETNAME: ${YELLOW}Non configuré${NC}"
        echo -e "  💡 Pour configurer: Lancez UPLANET.init.sh"
        echo ""
    fi
    
    # UPLANETNAME_SOCIETY (Capital Social) - Utilise G1society.sh pour l'historique
    local uplanet_society_pubkey=""
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" ]]; then
        uplanet_society_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" 2>/dev/null)
    fi
    
    if [[ -n "$uplanet_society_pubkey" ]]; then
        local society_balance=$(get_wallet_balance "$uplanet_society_pubkey")
        
        # Récupérer les données de capital social depuis G1society.sh (historique analysé)
        local society_data=$(get_society_data)
        local society_zen=$(echo "$society_data" | jq -r '.total_outgoing_zen // 0' 2>/dev/null)
        local society_g1=$(echo "$society_data" | jq -r '.total_outgoing_g1 // 0' 2>/dev/null)
        local society_txcount=$(echo "$society_data" | jq -r '.total_transfers // 0' 2>/dev/null)
        
        echo -e "${BLUE}⭐ UPLANETNAME_SOCIETY (Capital Social):${NC}"
        echo -e "  💰 Solde brut: ${YELLOW}$society_balance Ğ1${NC}"
        echo -e "  📊 Parts sociales distribuées (historique): ${CYAN}$society_zen Ẑen${NC} (${YELLOW}$society_g1 Ğ1${NC})"
        echo -e "  👥 Sociétaires enregistrés: ${WHITE}$society_txcount${NC} membres"
        echo -e "  📝 Usage: Émission parts sociales ZEN Cards"
        echo ""
    else
        echo -e "${RED}⭐ UPLANETNAME_SOCIETY: ${YELLOW}Non configuré${NC}"
        echo -e "  💡 Pour configurer: Lancez UPLANET.init.sh"
        echo ""
    fi
    
    # NODE (Armateur - Infrastructure)
    local node_pubkey=""
    if [[ -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
        node_pubkey=$(cat "$HOME/.zen/game/secret.NODE.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$node_pubkey" ]]; then
        local node_balance=$(get_wallet_balance "$node_pubkey")
        local node_zen=$(calculate_zen "$node_balance")
        echo -e "${BLUE}🖥️  NODE (Armateur - Infrastructure):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$node_balance Ğ1${NC} (${CYAN}$node_zen Ẑen${NC})"
        echo -e "  📝 Usage: Réception PAF + Burn 4-semaines → OpenCollective"
        echo ""
    else
        echo -e "${RED}🖥️  NODE: ${YELLOW}Non configuré${NC}"
        echo -e "  💡 Pour configurer: Lancez UPLANET.init.sh"
        echo ""
    fi
    
    # CAPTAIN dedicated wallet (2x PAF remuneration from ZEN.ECONOMY.sh)
    local captain_dedicated_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.captain.dunikey" ]]; then
        captain_dedicated_pubkey=$(cat "$HOME/.zen/game/uplanet.captain.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$captain_dedicated_pubkey" ]]; then
        local captain_dedicated_balance=$(get_wallet_balance "$captain_dedicated_pubkey")
        local captain_dedicated_zen=$(calculate_zen "$captain_dedicated_balance")
        echo -e "${BLUE}👑 CAPTAIN (Rémunération 2xPAF):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$captain_dedicated_balance Ğ1${NC} (${CYAN}$captain_dedicated_zen Ẑen${NC})"
        echo -e "  📝 Usage: Revenus du Capitaine (2xPAF hebdomadaire via ZEN.ECONOMY.sh)"
        echo ""
    else
        echo -e "${RED}👑 CAPTAIN (Rémunération): ${YELLOW}Non configuré${NC}"
        echo -e "  💡 Sera créé automatiquement par ZEN.ECONOMY.sh"
        echo ""
    fi
    
    # Portefeuilles Coopératifs
    print_section "PORTEFEUILLES COOPÉRATIFS (3x1/3)"
    
    # CASH (Trésorerie)
    local cash_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
        cash_pubkey=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$cash_pubkey" ]]; then
        local cash_balance=$(get_wallet_balance "$cash_pubkey")
        local cash_zen=$(calculate_zen "$cash_balance")
        echo -e "${GREEN}💰 UPLANETNAME_CASH (Trésorerie 1/3):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$cash_balance Ğ1${NC} (${CYAN}$cash_zen Ẑen${NC})"
        echo -e "  📝 Usage: Solidarité PAF + réserve opérationnelle"
    else
        echo -e "${RED}💰 UPLANETNAME_CASH: ${YELLOW}Non configuré${NC}"
    fi
    
    # RND (R&D)
    local rnd_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
        rnd_pubkey=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$rnd_pubkey" ]]; then
        local rnd_balance=$(get_wallet_balance "$rnd_pubkey")
        local rnd_zen=$(calculate_zen "$rnd_balance")
        echo -e "${CYAN}🔬 UPLANETNAME_RND (R&D 1/3):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$rnd_balance Ğ1${NC} (${CYAN}$rnd_zen Ẑen${NC})"
        echo -e "  📝 Usage: Développement + innovation"
    else
        echo -e "${RED}🔬 UPLANETNAME_RND: ${YELLOW}Non configuré${NC}"
    fi
    
    # ASSETS (Actifs)
    local assets_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$assets_pubkey" ]]; then
        local assets_balance=$(get_wallet_balance "$assets_pubkey")
        local assets_zen=$(calculate_zen "$assets_balance")
        echo -e "${YELLOW}🌳 UPLANETNAME_ASSETS (Actifs 1/3):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$assets_balance Ğ1${NC} (${CYAN}$assets_zen Ẑen${NC})"
        echo -e "  📝 Usage: Forêts jardins + impact écologique"
    else
        echo -e "${RED}🌳 UPLANETNAME_ASSETS: ${YELLOW}Non configuré${NC}"
    fi
    
    # IMPOT (Fiscalité)
    local impot_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.IMPOT.dunikey" ]]; then
        impot_pubkey=$(cat "$HOME/.zen/game/uplanet.IMPOT.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$impot_pubkey" ]]; then
        local impot_balance=$(get_wallet_balance "$impot_pubkey")
        local impot_zen=$(calculate_zen "$impot_balance")
        echo -e "${PURPLE}🏛️  UPLANETNAME_IMPOT (Fiscalité):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$impot_balance Ğ1${NC} (${CYAN}$impot_zen Ẑen${NC})"
        echo -e "  📝 Usage: TVA collectée + provision IS"
    else
        echo -e "${RED}🏛️  UPLANETNAME_IMPOT: ${YELLOW}Non configuré${NC}"
    fi
    echo ""
    
    # Statistiques des utilisateurs
    print_section "STATISTIQUES DES UTILISATEURS"
    
    # Compter les MULTIPASS
    local multipass_count=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
    echo -e "${CYAN}👥 MULTIPASS: ${WHITE}$multipass_count${NC} compte(s)"
    
    # Compter les ZEN Cards
    local zencard_count=$(ls ~/.zen/game/players 2>/dev/null | grep "@" | wc -l)
    echo -e "${CYAN}🎫 ZEN Cards: ${WHITE}$zencard_count${NC} carte(s)"
    
    # Compter les sociétaires
    local societaire_count=0
    for player_dir in ~/.zen/game/players/*@*.*/; do
        if [[ -d "$player_dir" ]]; then
            if [[ -s "${player_dir}U.SOCIETY" ]] || [[ "$(basename "$player_dir")" == "$current_captain" ]]; then
                ((societaire_count++))
            fi
        fi
    done
    echo -e "${CYAN}⭐ Sociétaires: ${WHITE}$societaire_count${NC} membre(s)"
    echo ""
    
    # Résumé rapide de l'état de l'essaim
    show_quick_swarm_health
    
    # Statut de la configuration coopérative DID
    show_cooperative_config_status
    
    # Afficher le diagramme de flux économique
    show_economic_flow_diagram
    
    # Menu de navigation
    show_captain_navigation_menu
}

# Fonction pour afficher les détails du capitaine
show_captain_details() {
    local captain_email="$1"
    
    print_section "DÉTAILS DU CAPITAINE"
    
    # Initialisation explicite pour éviter les références hors-scope
    local multipass_g1pub=""
    local multipass_balance=0
    local multipass_zen=0
    
    # Informations ZEN Card du capitaine (historique des parts sociales)
    local captain_g1pub=$(cat ~/.zen/game/players/$captain_email/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    local captain_balance=$(get_wallet_balance "$captain_g1pub")
    
    # Récupérer l'historique des parts sociales via G1zencard_history.sh
    local zencard_history=""
    if [[ -n "$captain_g1pub" ]]; then
        zencard_history=$("${MY_PATH}/tools/G1zencard_history.sh" "$captain_email" "true" 2>/dev/null)
    fi
    
    echo -e "${CYAN}🎫 ZEN CARD (ẐEN Capital - Parts Sociales):${NC}"
    echo -e "  📧 Email: ${WHITE}$captain_email${NC}"
    echo -e "  🔑 G1PUB: ${WHITE}${captain_g1pub:0:20}...${NC}"
    echo -e "  💰 Solde technique: ${YELLOW}$captain_balance Ğ1${NC} (minimum 1Ğ1)"
    
    if [[ -n "$zencard_history" ]] && echo "$zencard_history" | jq empty 2>/dev/null; then
        local total_received_zen=$(echo "$zencard_history" | jq -r '.total_received_zen // 0' 2>/dev/null)
        local valid_balance_zen=$(echo "$zencard_history" | jq -r '.valid_balance_zen // 0' 2>/dev/null)
        local total_transfers=$(echo "$zencard_history" | jq -r '.total_transfers // 0' 2>/dev/null)
        local valid_transfers=$(echo "$zencard_history" | jq -r '.valid_transfers // 0' 2>/dev/null)
        
        echo -e "  📊 Capital social reçu: ${CYAN}$total_received_zen Ẑen${NC} (${WHITE}$total_transfers${NC} transferts)"
        echo -e "  ⭐ Capital social valide: ${GREEN}$valid_balance_zen Ẑen${NC} (${WHITE}$valid_transfers${NC} transferts valides)"
        
        if [[ "$valid_balance_zen" -gt 0 ]]; then
            echo -e "  🎯 Statut: ${GREEN}Sociétaire actif${NC} ($valid_balance_zen Ẑen de parts sociales)"
        else
            echo -e "  🎯 Statut: ${YELLOW}Capitaine (Sociétaire par défaut)${NC}"
        fi
    else
        echo -e "  📊 Capital social: ${YELLOW}Non analysé${NC}"
        echo -e "  🎯 Statut: ${YELLOW}Capitaine (Sociétaire par défaut)${NC}"
    fi
    
    # Vérifier le statut sociétaire
    if [[ -s ~/.zen/game/players/$captain_email/U.SOCIETY ]]; then
        echo -e "  ⭐ Statut: ${GREEN}Sociétaire${NC}"
    else
        echo -e "  ⭐ Statut: ${YELLOW}Capitaine (Sociétaire par défaut)${NC}"
    fi
    
    # Vérifier les fichiers importants
    local zen_files=("secret.dunikey" ".pass" "ipfs/moa/index.html")
    echo -e "  📄 Fichiers:"
    for file in "${zen_files[@]}"; do
        if [[ -f ~/.zen/game/players/$captain_email/$file ]]; then
            echo -e "    ✅ $file: ${GREEN}Présent${NC}"
        else
            echo -e "    ❌ $file: ${RED}Absent${NC}"
        fi
    done
    echo ""
    
    # Informations MULTIPASS du capitaine
    if [[ -d ~/.zen/game/nostr/$captain_email ]]; then
        local multipass_g1pub=$(cat ~/.zen/game/nostr/$captain_email/G1PUBNOSTR 2>/dev/null)
        if [[ -n "$multipass_g1pub" ]]; then
            local multipass_balance=$(get_wallet_balance "$multipass_g1pub")
            local multipass_zen=$(calculate_zen "$multipass_balance")
            
            echo -e "${CYAN}👥 MULTIPASS (ẐEN Usage - Solde Utilisable):${NC}"
            echo -e "  📧 Email: ${WHITE}$captain_email${NC}"
            echo -e "  🔑 G1PUB: ${WHITE}${multipass_g1pub:0:20}...${NC}"
            echo -e "  💰 Solde utilisable: ${YELLOW}$multipass_balance Ğ1${NC} (${CYAN}$multipass_zen Ẑen${NC})"
            echo -e "  📝 Usage: Transactions quotidiennes, likes, services"
            
            # Vérifier les fichiers MULTIPASS importants
            local multipass_files=("G1PUBNOSTR" "NPUB" "HEX" "GPS" ".nostr.zine.html")
            echo -e "  📄 Fichiers:"
            for file in "${multipass_files[@]}"; do
                if [[ -f ~/.zen/game/nostr/$captain_email/$file ]]; then
                    case $file in
                        "G1PUBNOSTR"|"NPUB"|"HEX")
                            local content=$(cat ~/.zen/game/nostr/$captain_email/$file | head -c 20)
                            echo -e "    ✅ $file: ${GREEN}${content}...${NC}"
                            ;;
                        "GPS")
                            local content=$(cat ~/.zen/game/nostr/$captain_email/$file)
                            echo -e "    ✅ $file: ${GREEN}$content${NC}"
                            ;;
                        ".nostr.zine.html")
                            echo -e "    ✅ $file: ${GREEN}Présent${NC}"
                            ;;
                    esac
                else
                    echo -e "    ❌ $file: ${RED}Absent${NC}"
                fi
            done
        else
            echo -e "${CYAN}👥 MULTIPASS:${NC}"
            echo -e "  ❌ ${RED}Aucun MULTIPASS trouvé pour $captain_email${NC}"
        fi
    else
        echo -e "${CYAN}👥 MULTIPASS:${NC}"
        echo -e "  ❌ ${RED}Répertoire MULTIPASS non trouvé pour $captain_email${NC}"
    fi
    echo ""
    
    # Résumé économique du capitaine
    local total_captain_g1=0
    local total_captain_zen=0
    local zencard_capital_zen=0
    local multipass_usage_zen=0
    
    # Ajouter le solde ZEN Card (minimum technique)
    total_captain_g1=$(echo "$total_captain_g1 + $captain_balance" | bc -l 2>/dev/null || echo "$total_captain_g1")
    
    # Ajouter le solde MULTIPASS si différent
    if [[ -n "$multipass_g1pub" ]] && [[ "$multipass_g1pub" != "$captain_g1pub" ]]; then
        total_captain_g1=$(echo "$total_captain_g1 + $multipass_balance" | bc -l 2>/dev/null || echo "$total_captain_g1")
    fi
    
    # Calculer les ẐEN selon leur nature
    if [[ -n "$zencard_history" ]] && echo "$zencard_history" | jq empty 2>/dev/null; then
        zencard_capital_zen=$(echo "$zencard_history" | jq -r '.valid_balance_zen // 0' 2>/dev/null)
    fi
    
    if [[ -n "$multipass_g1pub" ]]; then
        multipass_usage_zen=$multipass_zen
    fi
    
    total_captain_zen=$(echo "$zencard_capital_zen + $multipass_usage_zen" | bc -l 2>/dev/null || echo "$total_captain_zen")
    
    echo -e "${BLUE}💰 RÉSUMÉ ÉCONOMIQUE DU CAPITAINE:${NC}"
    echo -e "  💎 Capital social (ZEN Card): ${CYAN}$zencard_capital_zen Ẑen${NC}"
    echo -e "  💰 Solde utilisable (MULTIPASS): ${CYAN}$multipass_usage_zen Ẑen${NC}"
    echo -e "  📊 Total Ẑen: ${GREEN}$total_captain_zen Ẑen${NC}"
    echo -e "  💰 Total Ğ1 technique: ${YELLOW}$total_captain_g1 Ğ1${NC}"
    echo ""
}

# Fonction pour afficher le diagramme de flux économique
show_economic_flow_diagram() {
    print_section "DIAGRAMME DE FLUX ÉCONOMIQUE"
    
    echo -e "${CYAN}🔄 FLUX ÉCONOMIQUE UPLANET:${NC}"
    echo ""
    
    # Flux 1: Locataire (Bleu)
    echo -e "${BLUE}1️⃣  FLUX MULTIPASS:${NC}"
    echo -e "   OpenCollective → UPLANETNAME → MULTIPASS"
    echo -e "   💰 Paiement loyer → Services → Primo TX"
    echo ""
    
    # Flux 2: Sociétaire (Vert)
    echo -e "${GREEN}2️⃣  FLUX SOCIÉTAIRE:${NC}"
    echo -e "   OpenCollective → UPLANETNAME_SOCIETY → ZenCard"
    echo -e "   💰 Achat parts sociales → Investissement → Primo TX"
    echo ""
    
    # Flux 3: Pionnier (Lavande)
    echo -e "${PURPLE}3️⃣  FLUX PIONNIER:${NC}"
    echo -e "   MADEINZEN.SOCIETY → UPassport"
    echo -e "   🎯 Jetons NEẐ → Gouvernance"
    echo ""
    
    # Flux 4: Économique Interne (Saumon)
    echo -e "${YELLOW}4️⃣  FLUX ÉCONOMIQUE INTERNE:${NC}"
    echo -e "   ZEN.ECONOMY.sh → Capitaine → Armateur"
    echo -e "   💰 Loyers → PAF_Node → Rémunération"
    echo ""
    
    # Flux 5: Peer-to-Peer (Pêche)
    echo -e "${CYAN}5️⃣  FLUX PEER-TO-PEER:${NC}"
    echo -e "   MULTIPASS A ↔ MULTIPASS B"
    echo -e "   ❤️  Likes → +1 Ẑen"
    echo ""
    
    echo -e "${WHITE}📊 Surplus réparti: 1/3 Trésorerie, 1/3 R&D, 1/3 Impact${NC}"
    echo ""
}

# Fonction pour agréger les données économiques de l'essaim
# Utilise le cache des stations depuis ~/.zen/tmp/swarm/*/12345.json
show_swarm_economy() {
    print_section "ÉCONOMIE DE L'ESSAIM UPLANET"
    
    local swarm_cache="$HOME/.zen/tmp/swarm"
    
    # Compteurs globaux
    local total_stations=0
    local stations_green=0
    local stations_yellow=0
    local stations_orange=0
    local stations_red=0
    local total_multipass=0
    local total_zencard=0
    local total_weekly_revenue=0
    local total_weekly_costs=0
    local total_captain_zen=0
    local total_treasury_zen=0
    local total_node_zen=0
    
    # Alertes des stations en difficulté
    local alerts=""
    
    echo -e "${CYAN}🔄 Analyse des données économiques de l'essaim...${NC}"
    echo ""
    
    # Station locale d'abord
    local local_json="$HOME/.zen/tmp/${IPFSNODEID}/12345.json"
    if [[ -f "$local_json" ]]; then
        local hostname=$(cat "$local_json" | jq -r '.hostname // "local"')
        local risk=$(cat "$local_json" | jq -r '.economy.risk_level // "UNKNOWN"')
        local mp=$(cat "$local_json" | jq -r '.economy.multipass_count // 0')
        local zc=$(cat "$local_json" | jq -r '.economy.zencard_count // 0')
        local wr=$(cat "$local_json" | jq -r '.economy.weekly_revenue // 0')
        local wc=$(cat "$local_json" | jq -r '.economy.weekly_costs // 0')
        local captain_zen=$(cat "$local_json" | jq -r '.captainZEN // 0')
        local treasury=$(cat "$local_json" | jq -r '.economy.treasury_zen // 0')
        local node_zen=$(cat "$local_json" | jq -r '.NODEZEN // 0')
        
        total_stations=$((total_stations + 1))
        total_multipass=$((total_multipass + mp))
        total_zencard=$((total_zencard + zc))
        total_weekly_revenue=$(echo "$total_weekly_revenue + $wr" | bc -l)
        total_weekly_costs=$(echo "$total_weekly_costs + $wc" | bc -l)
        total_captain_zen=$(echo "$total_captain_zen + $captain_zen" | bc -l)
        total_treasury_zen=$(echo "$total_treasury_zen + $treasury" | bc -l)
        total_node_zen=$(echo "$total_node_zen + $node_zen" | bc -l)
        
        case $risk in
            "GREEN") stations_green=$((stations_green + 1)) ;;
            "YELLOW") stations_yellow=$((stations_yellow + 1)) ;;
            "ORANGE") stations_orange=$((stations_orange + 1)) ;;
            "RED") stations_red=$((stations_red + 1)); alerts="${alerts}\n  ${RED}⛔ ${hostname} (LOCAL): FAILLITE IMMINENTE${NC}" ;;
        esac
        
        echo -e "${GREEN}📍 Station locale ($hostname): $risk${NC}"
    fi
    
    # Parcourir les stations de l'essaim (cache)
    if [[ -d "$swarm_cache" ]]; then
        for station_dir in "$swarm_cache"/*/; do
            local station_id=$(basename "$station_dir")
            local station_json="${station_dir}12345.json"
            
            # Ignorer si c'est notre propre station
            [[ "$station_id" == "$IPFSNODEID" ]] && continue
            
            if [[ -f "$station_json" ]]; then
                # Vérifier la fraîcheur des données (< 24h)
                local file_age=$(( $(date +%s) - $(stat -c %Y "$station_json" 2>/dev/null || echo 0) ))
                [[ $file_age -gt 86400 ]] && continue
                
                # Vérifier que c'est le même UPlanet
                local uplanet_pub=$(cat "$station_json" | jq -r '.UPLANETG1PUB // ""')
                [[ "$uplanet_pub" != "$UPLANETG1PUB" && -n "$uplanet_pub" ]] && continue
                
                local hostname=$(cat "$station_json" | jq -r '.hostname // "unknown"')
                local risk=$(cat "$station_json" | jq -r '.economy.risk_level // "UNKNOWN"')
                local mp=$(cat "$station_json" | jq -r '.economy.multipass_count // 0')
                local zc=$(cat "$station_json" | jq -r '.economy.zencard_count // 0')
                local wr=$(cat "$station_json" | jq -r '.economy.weekly_revenue // 0')
                local wc=$(cat "$station_json" | jq -r '.economy.weekly_costs // 0')
                local captain_zen=$(cat "$station_json" | jq -r '.captainZEN // 0')
                local treasury=$(cat "$station_json" | jq -r '.economy.treasury_zen // 0')
                local node_zen=$(cat "$station_json" | jq -r '.NODEZEN // 0')
                
                # Ignorer les stations sans données économiques valides
                [[ "$risk" == "UNKNOWN" || "$risk" == "null" ]] && continue
                
                total_stations=$((total_stations + 1))
                total_multipass=$((total_multipass + mp))
                total_zencard=$((total_zencard + zc))
                total_weekly_revenue=$(echo "$total_weekly_revenue + $wr" | bc -l)
                total_weekly_costs=$(echo "$total_weekly_costs + $wc" | bc -l)
                total_captain_zen=$(echo "$total_captain_zen + $captain_zen" | bc -l)
                total_treasury_zen=$(echo "$total_treasury_zen + $treasury" | bc -l)
                total_node_zen=$(echo "$total_node_zen + $node_zen" | bc -l)
                
                case $risk in
                    "GREEN") stations_green=$((stations_green + 1)) ;;
                    "YELLOW") stations_yellow=$((stations_yellow + 1)) ;;
                    "ORANGE") 
                        stations_orange=$((stations_orange + 1))
                        alerts="${alerts}\n  ${YELLOW}⚠️  ${hostname}: Solidarité active${NC}"
                        ;;
                    "RED") 
                        stations_red=$((stations_red + 1))
                        alerts="${alerts}\n  ${RED}⛔ ${hostname}: FAILLITE IMMINENTE${NC}"
                        ;;
                esac
                
                echo -e "  📡 ${station_id:0:8}... ($hostname): $risk"
            fi
        done
    fi
    
    echo ""
    
    # Calculer le bilan global
    local total_balance=$(echo "$total_weekly_revenue - $total_weekly_costs" | bc -l)
    local total_reserves=$(echo "$total_captain_zen + $total_treasury_zen" | bc -l)
    
    # Afficher le résumé
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    📊 RÉSUMÉ ÉCONOMIQUE DE L'ESSAIM                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Santé des stations
    echo -e "${CYAN}🏥 SANTÉ DES STATIONS (${total_stations} total):${NC}"
    echo -e "  ${GREEN}✅ En bonne santé:${NC}     $stations_green station(s)"
    echo -e "  ${YELLOW}⚡ Surveillance:${NC}       $stations_yellow station(s)"
    echo -e "  ${YELLOW}⚠️  Solidarité active:${NC} $stations_orange station(s)"
    echo -e "  ${RED}⛔ Faillite:${NC}           $stations_red station(s)"
    echo ""
    
    # Économie globale
    echo -e "${CYAN}💰 ÉCONOMIE GLOBALE:${NC}"
    echo -e "  👥 Total MULTIPASS:          ${WHITE}$total_multipass${NC} utilisateurs"
    echo -e "  🎫 Total ZEN Cards:          ${WHITE}$total_zencard${NC} sociétaires"
    echo -e "  📈 Revenus hebdo totaux:     ${GREEN}$total_weekly_revenue Ẑen${NC}"
    echo -e "  📉 Coûts hebdo totaux:       ${RED}$total_weekly_costs Ẑen${NC}"
    if [[ $(echo "$total_balance >= 0" | bc -l) -eq 1 ]]; then
        echo -e "  📊 Balance globale:          ${GREEN}+$total_balance Ẑen/semaine${NC}"
    else
        echo -e "  📊 Balance globale:          ${RED}$total_balance Ẑen/semaine${NC}"
    fi
    echo ""
    
    # Réserves coopératives
    echo -e "${CYAN}🏦 RÉSERVES COOPÉRATIVES:${NC}"
    echo -e "  👑 Total Capitaines:         ${YELLOW}$total_captain_zen Ẑen${NC}"
    echo -e "  💰 Total Trésoreries:        ${YELLOW}$total_treasury_zen Ẑen${NC}"
    echo -e "  🖥️  Total Nodes:              ${YELLOW}$total_node_zen Ẑen${NC}"
    echo -e "  📊 Réserves totales:         ${GREEN}$total_reserves Ẑen${NC}"
    echo ""
    
    # Alertes
    if [[ -n "$alerts" ]]; then
        echo -e "${RED}🚨 ALERTES DE L'ESSAIM:${NC}"
        echo -e "$alerts"
        echo ""
        
        # Recommandations si stations en difficulté
        if [[ $stations_red -gt 0 ]]; then
            echo -e "${YELLOW}💡 ACTIONS RECOMMANDÉES:${NC}"
            echo -e "  1️⃣  Contacter les capitaines des stations en faillite"
            echo -e "  2️⃣  Proposer un transfert de solidarité depuis la trésorerie"
            echo -e "  3️⃣  Aider à recruter des utilisateurs MULTIPASS"
            echo -e "  4️⃣  Envisager une consolidation de stations"
            echo ""
        fi
    else
        echo -e "${GREEN}✅ Aucune alerte - Toutes les stations sont en bonne santé${NC}"
        echo ""
    fi
    
    # Afficher le template bankrupt.html si stations en faillite
    if [[ $stations_red -gt 0 ]]; then
        echo -e "${YELLOW}📋 Pour plus de détails sur les causes de faillite:${NC}"
        echo -e "  Consultez le template: templates/NOSTR/bankrupt.html"
        echo -e "  Ce rapport est envoyé automatiquement aux utilisateurs concernés"
        echo ""
    fi
}

# Fonction pour afficher et gérer la configuration coopérative
show_cooperative_config_menu() {
    print_header "CONFIGURATION COOPÉRATIVE (DID NOSTR)"
    
    if [[ "$COOP_CONFIG_AVAILABLE" != "true" ]]; then
        print_error "Système de configuration coopérative non disponible"
        echo -e "${YELLOW}Le fichier cooperative_config.sh n'est pas trouvé.${NC}"
        read -p "Appuyez sur ENTRÉE pour continuer..."
        show_captain_dashboard
        return
    fi
    
    print_section "PARAMÈTRES COOPÉRATIFS (PARTAGÉS VIA DID)"
    
    echo -e "${CYAN}Ces paramètres sont partagés entre toutes les stations de l'essaim.${NC}"
    echo -e "${CYAN}Ils sont stockés dans le DID NOSTR de UPLANETNAME_G1 (kind 30800).${NC}"
    echo -e "${CYAN}Les valeurs sensibles sont chiffrées avec \$UPLANETNAME.${NC}"
    echo ""
    
    # Vérifier si la configuration DID existe
    if coop_config_exists 2>/dev/null; then
        echo -e "${GREEN}✅ Configuration coopérative DID active${NC}"
        echo ""
        
        # Afficher les paramètres économiques
        echo -e "${BLUE}📊 Paramètres économiques:${NC}"
        local econ_keys=("NCARD" "ZCARD" "TVA_RATE" "IS_RATE_REDUCED" "IS_RATE_NORMAL" "IS_THRESHOLD")
        for key in "${econ_keys[@]}"; do
            local value=$(coop_config_get "$key" 2>/dev/null)
            if [[ -n "$value" ]]; then
                echo -e "   • $key: ${GREEN}$value${NC}"
            else
                echo -e "   • $key: ${YELLOW}(non défini)${NC}"
            fi
        done
        echo ""
        
        # Afficher les paramètres de parts sociales
        echo -e "${BLUE}⭐ Parts sociales:${NC}"
        local society_keys=("ZENCARD_SATELLITE" "ZENCARD_CONSTELLATION")
        for key in "${society_keys[@]}"; do
            local value=$(coop_config_get "$key" 2>/dev/null)
            if [[ -n "$value" ]]; then
                echo -e "   • $key: ${GREEN}$value${NC}"
            else
                echo -e "   • $key: ${YELLOW}(non défini)${NC}"
            fi
        done
        echo ""
        
        # Afficher les règles 3x1/3
        echo -e "${BLUE}🤝 Règle 3x1/3 (répartition surplus):${NC}"
        local rule_keys=("TREASURY_PERCENT" "RND_PERCENT" "ASSETS_PERCENT")
        for key in "${rule_keys[@]}"; do
            local value=$(coop_config_get "$key" 2>/dev/null)
            if [[ -n "$value" ]]; then
                echo -e "   • $key: ${GREEN}$value%${NC}"
            else
                echo -e "   • $key: ${YELLOW}(non défini)${NC}"
            fi
        done
        echo ""
        
        # Statut des clés API (masquées)
        echo -e "${BLUE}🔐 Clés API (chiffrées):${NC}"
        local api_keys=("OCAPIKEY" "MAILJET_APIKEY" "PLANTNET_API_KEY")
        for key in "${api_keys[@]}"; do
            local value=$(coop_config_get "$key" 2>/dev/null)
            if [[ -n "$value" && "$value" != "" ]]; then
                echo -e "   • $key: ${GREEN}✅ Configurée${NC}"
            else
                echo -e "   • $key: ${YELLOW}❌ Non configurée${NC}"
            fi
        done
        echo ""
    else
        echo -e "${YELLOW}⚠️  Configuration coopérative DID non initialisée${NC}"
        echo -e "${CYAN}Lancez UPLANET.init.sh pour initialiser la configuration.${NC}"
        echo ""
    fi
    
    # Menu d'actions
    echo -e "${WHITE}Actions disponibles:${NC}"
    echo ""
    echo -e "${GREEN}1. 📋 Lister toutes les clés de configuration${NC}"
    echo -e "${GREEN}2. ✏️  Modifier une valeur${NC}"
    echo -e "${GREEN}3. 🔄 Actualiser depuis le DID${NC}"
    echo -e "${GREEN}4. 📤 Publier config locale vers DID${NC}"
    echo -e "${GREEN}5. 🔐 Configurer clé API (chiffrée)${NC}"
    echo -e "${GREEN}0. ⬅️  Retour au tableau de bord${NC}"
    echo ""
    
    read -p "Votre choix: " config_choice
    
    case $config_choice in
        1)
            print_section "TOUTES LES CLÉS DE CONFIGURATION"
            coop_config_list 2>/dev/null || echo "Impossible de lister la configuration"
            read -p "Appuyez sur ENTRÉE pour continuer..."
            show_cooperative_config_menu
            ;;
        2)
            echo ""
            read -p "Nom de la clé à modifier: " key_name
            read -p "Nouvelle valeur: " key_value
            if [[ -n "$key_name" && -n "$key_value" ]]; then
                if coop_config_set "$key_name" "$key_value" 2>/dev/null; then
                    print_success "Valeur '$key_name' mise à jour: $key_value"
                else
                    print_error "Erreur lors de la mise à jour"
                fi
            else
                print_error "Clé ou valeur vide"
            fi
            read -p "Appuyez sur ENTRÉE pour continuer..."
            show_cooperative_config_menu
            ;;
        3)
            print_info "Actualisation depuis le DID..."
            coop_config_refresh 2>/dev/null && print_success "Configuration actualisée" || print_error "Erreur d'actualisation"
            read -p "Appuyez sur ENTRÉE pour continuer..."
            show_cooperative_config_menu
            ;;
        4)
            publish_local_config_to_did
            read -p "Appuyez sur ENTRÉE pour continuer..."
            show_cooperative_config_menu
            ;;
        5)
            configure_api_key
            read -p "Appuyez sur ENTRÉE pour continuer..."
            show_cooperative_config_menu
            ;;
        0)
            show_captain_dashboard
            return
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            show_cooperative_config_menu
            ;;
    esac
}

# Fonction pour publier la config locale vers le DID
publish_local_config_to_did() {
    print_section "PUBLICATION CONFIG LOCALE → DID"
    
    local env_file="$HOME/.zen/Astroport.ONE/.env"
    
    if [[ ! -f "$env_file" ]]; then
        print_error "Fichier .env non trouvé"
        return 1
    fi
    
    echo -e "${CYAN}Paramètres à publier depuis .env:${NC}"
    
    local keys_to_publish=("NCARD" "ZCARD" "TVA_RATE" "IS_RATE_REDUCED" "IS_RATE_NORMAL" "IS_THRESHOLD" "ZENCARD_SATELLITE" "ZENCARD_CONSTELLATION" "TREASURY_PERCENT" "RND_PERCENT" "ASSETS_PERCENT")
    
    for key in "${keys_to_publish[@]}"; do
        local value=$(grep "^$key=" "$env_file" 2>/dev/null | cut -d'=' -f2)
        if [[ -n "$value" ]]; then
            echo -e "   • $key: ${YELLOW}$value${NC}"
        fi
    done
    echo ""
    
    read -p "Confirmer la publication vers le DID ? (oui/non): " confirm
    if [[ "$confirm" == "oui" || "$confirm" == "o" ]]; then
        for key in "${keys_to_publish[@]}"; do
            local value=$(grep "^$key=" "$env_file" 2>/dev/null | cut -d'=' -f2)
            if [[ -n "$value" ]]; then
                if coop_config_set "$key" "$value" 2>/dev/null; then
                    echo -e "${GREEN}✅ $key${NC}"
                else
                    echo -e "${RED}❌ $key${NC}"
                fi
            fi
        done
        print_success "Publication terminée"
    else
        print_info "Publication annulée"
    fi
}

# Fonction pour configurer une clé API (chiffrée)
configure_api_key() {
    print_section "CONFIGURATION CLÉ API (CHIFFRÉE)"
    
    echo -e "${CYAN}Les clés API sont automatiquement chiffrées avec \$UPLANETNAME.${NC}"
    echo ""
    echo -e "${WHITE}Clés API disponibles:${NC}"
    echo "  1. OCAPIKEY       (OpenCollective API key)"
    echo "  2. MAILJET_APIKEY (Service email Mailjet)"
    echo "  3. PLANTNET_API_KEY (Identification plantes)"
    echo "  4. Autre (personnalisée)"
    echo ""
    
    read -p "Votre choix: " api_choice
    
    local key_name=""
    case $api_choice in
        1) key_name="OCAPIKEY" ;;
        2) key_name="MAILJET_APIKEY" ;;
        3) key_name="PLANTNET_API_KEY" ;;
        4)
            read -p "Nom de la clé API: " key_name
            ;;
        *)
            print_error "Choix invalide"
            return 1
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}⚠️  Saisissez la valeur (elle ne sera pas affichée):${NC}"
    read -s -p "$key_name: " key_value
    echo ""
    
    if [[ -n "$key_value" ]]; then
        if coop_config_set "$key_name" "$key_value" 2>/dev/null; then
            print_success "Clé API '$key_name' configurée et chiffrée"
        else
            print_error "Erreur lors de la configuration"
        fi
    else
        print_error "Valeur vide"
    fi
}

# Fonction pour afficher le menu de navigation du capitaine
show_captain_navigation_menu() {
    print_section "NAVIGATION DU CAPITAINE"
    
    echo -e "${WHITE}Choisissez votre action:${NC}"
    echo ""
    
    echo -e "${GREEN}1. 💰 Gestion Économique (zen.sh)${NC}"
    echo -e "   • Transactions UPLANETNAME_G1, UPLANETG1PUB, UPLANETNAME_SOCIETY"
    echo -e "   • Analyse des portefeuilles et flux économiques"
    echo -e "   • Gestion des investissements et répartitions"
    echo ""
    
    echo -e "${GREEN}2. 🏛️  Infrastructure UPLANET (UPLANET.init.sh)${NC}"
    echo -e "   • Initialisation complète des portefeuilles coopératifs"
    echo -e "   • Configuration NODE, CASH, RND, ASSETS, IMPOT"
    echo -e "   • Vérification de l'architecture ẐEN ECONOMY"
    echo ""
    
    echo -e "${GREEN}3. ⚡ Scripts Économiques Automatisés${NC}"
    echo -e "   • ZEN.ECONOMY.sh : PAF + Burn 4-semaines + Apport capital"
    echo -e "   • ZEN.COOPERATIVE.3x1-3.sh : Allocation coopérative"
    echo -e "   • NOSTRCARD/PLAYER.refresh.sh : Collecte loyers + TVA"
    echo ""
    
    echo -e "${GREEN}4. 🎮 Interface Principale (command.sh)${NC}"
    echo -e "   • Gestion des identités MULTIPASS & ZEN Card"
    echo -e "   • Connexion swarm et statut des services"
    echo -e "   • Applications et configuration système"
    echo ""
    
    echo -e "${GREEN}5. 📊 Tableau de Bord Détaillé${NC}"
    echo -e "   • Solde détaillé de tous les portefeuilles"
    echo -e "   • Historique des transactions"
    echo -e "   • Analyse des flux économiques"
    echo ""
    
    echo -e "${GREEN}6. 🌐 Économie de l'Essaim${NC}"
    echo -e "   • État économique de toutes les stations"
    echo -e "   • Alertes de faillite du réseau"
    echo -e "   • Vision globale de la coopérative"
    echo ""
    
    echo -e "${GREEN}7. 🔄 Actualiser les Données${NC}"
    echo -e "   • Mise à jour des soldes et cache"
    echo -e "   • Synchronisation avec le réseau Ğ1"
    echo -e "   • Actualisation des statistiques"
    echo ""
    
    echo -e "${GREEN}8. 📋 Nouvel Embarquement${NC}"
    echo -e "   • Créer un nouveau MULTIPASS ou ZEN Card"
    echo -e "   • Configuration d'un nouvel utilisateur"
    echo -e "   • Intégration dans l'écosystème"
    echo ""
    
    echo -e "${GREEN}9. 📢 Broadcast NOSTR${NC}"
    echo -e "   • Envoyer un message à tous les utilisateurs MULTIPASS"
    echo -e "   • Communication réseau via NOSTR"
    echo -e "   • Diffusion d'annonces importantes"
    echo ""
    
    echo -e "${GREEN}c. ⚙️  Configuration Coopérative (DID)${NC}"
    echo -e "   • Paramètres partagés entre stations"
    echo -e "   • Clés API chiffrées (OpenCollective, PlantNet)"
    echo -e "   • Règles économiques de l'essaim"
    echo ""
    
    echo -e "${GREEN}u. 🚀 Assistant UPlanet (onboarding)${NC}"
    echo -e "   • Configuration complète de la station"
    echo -e "   • Valorisation machine et économie"
    echo -e "   • Mode ORIGIN/ẐEN"
    echo ""
    
    echo -e "${GREEN}0. ❌ Quitter${NC}"
    echo ""
    
    read -p "Votre choix: " choice
    
    case $choice in
        1)
            print_info "Lancement de zen.sh..."
            echo ""
            "${MY_PATH}/tools/zen.sh"
            ;;
        2)
            print_info "Lancement de UPLANET.init.sh..."
            echo ""
            "${MY_PATH}/UPLANET.init.sh"
            ;;
        3)
            show_economic_scripts_menu
            ;;
        4)
            print_info "Lancement de command.sh..."
            echo ""
            "${MY_PATH}/command.sh"
            ;;
        5)
            show_detailed_dashboard
            ;;
        6)
            show_swarm_economy
            read -p "Appuyez sur ENTRÉE pour continuer..."
            show_captain_dashboard
            ;;
        7)
            refresh_data
            ;;
        8)
            embark_captain
            ;;
        9)
            show_nostr_broadcast_menu
            ;;
        c|C)
            show_cooperative_config_menu
            ;;
        u|U)
            if [[ -f "${MY_PATH}/uplanet_onboarding.sh" ]]; then
                print_info "Lancement de l'assistant UPlanet..."
                echo ""
                "${MY_PATH}/uplanet_onboarding.sh"
            else
                print_error "uplanet_onboarding.sh non trouvé"
                sleep 2
                show_captain_dashboard
            fi
            ;;
        0)
            print_success "Au revoir, Capitaine !"
            exit 0
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            show_captain_dashboard
            ;;
    esac
}

# Fonction pour afficher le menu des scripts économiques
show_economic_scripts_menu() {
    print_header "SCRIPTS ÉCONOMIQUES AUTOMATISÉS"
    
    echo -e "${CYAN}Choisissez le script à exécuter:${NC}"
    echo ""
    
    echo -e "${GREEN}1. 💰 ZEN.ECONOMY.sh${NC}"
    echo -e "   • Paiement PAF hebdomadaire (Captain → NODE)"
    echo -e "   • Burn 4-semaines (NODE → UPLANETNAME_G1 → OpenCollective)"
    echo -e "   • Apport capital machine (ZEN Card → NODE, une fois)"
    echo -e "   • Contrôle primal des portefeuilles coopératifs"
    echo ""
    
    echo -e "${GREEN}2. 🤝 ZEN.COOPERATIVE.3x1-3.sh${NC}"
    echo -e "   • Calcul et allocation du surplus coopératif"
    echo -e "   • Répartition 3x1/3 : CASH, RND, ASSETS"
    echo -e "   • Provision fiscale (IS) vers IMPOT"
    echo ""
    
    echo -e "${GREEN}3. 👥 NOSTRCARD.refresh.sh${NC}"
    echo -e "   • Collecte loyers MULTIPASS (1Ẑ HT + 0.2Ẑ TVA)"
    echo -e "   • Paiement direct TVA → IMPOT"
    echo -e "   • Revenus HT → Captain MULTIPASS"
    echo ""
    
    echo -e "${GREEN}4. 🎫 PLAYER.refresh.sh${NC}"
    echo -e "   • Collecte loyers ZEN Cards (4Ẑ HT + 0.8Ẑ TVA)"
    echo -e "   • Paiement direct TVA → IMPOT"
    echo -e "   • Revenus HT → Captain MULTIPASS"
    echo ""
    
    echo -e "${GREEN}5. 🏛️  UPLANET.official.sh${NC}"
    echo -e "   • Émission officielle de Ẑen"
    echo -e "   • Création MULTIPASS et ZEN Cards"
    echo -e "   • Gestion des parts sociales"
    echo ""
    
    echo -e "${GREEN}0. ⬅️  Retour au tableau de bord${NC}"
    echo ""
    
    read -p "Votre choix: " script_choice
    
    case $script_choice in
        1)
            print_info "Lancement de ZEN.ECONOMY.sh..."
            echo ""
            "${MY_PATH}/RUNTIME/ZEN.ECONOMY.sh"
            ;;
        2)
            print_info "Lancement de ZEN.COOPERATIVE.3x1-3.sh..."
            echo ""
            "${MY_PATH}/RUNTIME/ZEN.COOPERATIVE.3x1-3.sh"
            ;;
        3)
            print_info "Lancement de NOSTRCARD.refresh.sh..."
            echo ""
            "${MY_PATH}/RUNTIME/NOSTRCARD.refresh.sh"
            ;;
        4)
            print_info "Lancement de PLAYER.refresh.sh..."
            echo ""
            "${MY_PATH}/RUNTIME/PLAYER.refresh.sh"
            ;;
        5)
            print_info "Lancement de UPLANET.official.sh..."
            echo ""
            "${MY_PATH}/UPLANET.official.sh"
            ;;
        0)
            show_captain_dashboard
            return
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            show_economic_scripts_menu
            ;;
    esac
    
    if [[ "$script_choice" != "0" ]]; then
        read -p "Appuyez sur ENTRÉE pour continuer..."
        show_captain_dashboard
    fi
}

# Fonction pour afficher un tableau de bord détaillé
show_detailed_dashboard() {
    print_header "TABLEAU DE BORD DÉTAILLÉ"
    
    # Actualiser les données
    refresh_data
    
    # Afficher les détails des portefeuilles utilisateurs
    print_section "PORTEFEUILLES UTILISATEURS"
    
    # MULTIPASS avec soldes
    if [[ -d ~/.zen/game/nostr ]]; then
        local account_names=($(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        if [[ ${#account_names[@]} -gt 0 ]]; then
            echo -e "${CYAN}👥 MULTIPASS WALLETS:${NC}"
            for account_name in "${account_names[@]}"; do
                local g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
                if [[ -n "$g1pub" ]]; then
                    local balance=$(get_wallet_balance "$g1pub")
                    local zen=$(calculate_zen "$balance")
                    echo -e "  📧 ${GREEN}$account_name${NC}: ${YELLOW}$balance Ğ1${NC} (${CYAN}$zen Ẑen${NC})"
                fi
            done
            echo ""
        fi
    fi
    
    # ZenCard avec soldes
    if [[ -d ~/.zen/game/players ]]; then
        local player_dirs=($(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        if [[ ${#player_dirs[@]} -gt 0 ]]; then
            echo -e "${CYAN}🎫 ZENCARD WALLETS:${NC}"
            for player_dir in "${player_dirs[@]}"; do
                local g1pub=$(cat ~/.zen/game/players/${player_dir}/.g1pub 2>/dev/null)
                if [[ -n "$g1pub" ]]; then
                    local balance=$(get_wallet_balance "$g1pub")
                    local zen=$(calculate_zen "$balance")
                    local status=""
                    if [[ -s ~/.zen/game/players/${player_dir}/U.SOCIETY ]] || [[ "${player_dir}" == "$(cat ~/.zen/game/players/.current/.player 2>/dev/null)" ]]; then
                        status="${GREEN}⭐ Sociétaire${NC}"
                    else
                        status="${YELLOW}🏠 Locataire${NC}"
                    fi
                    echo -e "  🎫 ${GREEN}$player_dir${NC}: ${YELLOW}$balance Ğ1${NC} (${CYAN}$zen Ẑen${NC}) | $status"
                fi
            done
            echo ""
        fi
    fi
    
    # Statistiques économiques
    print_section "STATISTIQUES ÉCONOMIQUES"
    
    # Calculer les totaux
    local total_g1=0
    local total_zen=0
    
    # Afficher le portefeuille CAPTAIN dédié (2xPAF)
    if [[ -f "$HOME/.zen/game/uplanet.captain.dunikey" ]]; then
        local captain_ded_pubkey=$(cat "$HOME/.zen/game/uplanet.captain.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        if [[ -n "$captain_ded_pubkey" ]]; then
            local captain_ded_balance=$(get_wallet_balance "$captain_ded_pubkey")
            local captain_ded_zen=$(calculate_zen "$captain_ded_balance")
            echo -e "${CYAN}👑 CAPTAIN WALLET (2xPAF Rémunération):${NC}"
            echo -e "  💰 ${GREEN}Capitaine${NC}: ${YELLOW}$captain_ded_balance Ğ1${NC} (${CYAN}$captain_ded_zen Ẑen${NC})"
            echo ""
        fi
    fi
    
    # Total des portefeuilles système
    for wallet_file in "UPLANETNAME_G1" "UPLANETG1PUB" "UPLANETNAME_SOCIETY"; do
        if [[ -f "$HOME/.zen/tmp/$wallet_file" ]]; then
            local pubkey=$(cat "$HOME/.zen/tmp/$wallet_file" 2>/dev/null)
            if [[ -n "$pubkey" ]]; then
                local balance=$(get_wallet_balance "$pubkey")
                total_g1=$(echo "$total_g1 + $balance" | bc -l 2>/dev/null || echo "$total_g1")
            fi
        fi
    done
    
    # Total des portefeuilles utilisateurs
    for account_name in "${account_names[@]}"; do
        local g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
        if [[ -n "$g1pub" ]]; then
            local balance=$(get_wallet_balance "$g1pub")
            total_g1=$(echo "$total_g1 + $balance" | bc -l 2>/dev/null || echo "$total_g1")
        fi
    done
    
    for player_dir in "${player_dirs[@]}"; do
        local g1pub=$(cat ~/.zen/game/players/${player_dir}/.g1pub 2>/dev/null)
        if [[ -n "$g1pub" ]]; then
            local balance=$(get_wallet_balance "$g1pub")
            total_g1=$(echo "$total_g1 + $balance" | bc -l 2>/dev/null || echo "$total_g1")
        fi
    done
    
    total_zen=$(calculate_zen "$total_g1")
    
    echo -e "${BLUE}💰 TOTAL ÉCONOMIQUE:${NC}"
    echo -e "  Ğ1: ${YELLOW}$total_g1${NC}"
    echo -e "  Ẑen: ${CYAN}$total_zen${NC}"
    echo ""
    
    read -p "Appuyez sur ENTRÉE pour continuer..."
    show_captain_dashboard
}

# Fonction pour actualiser les données
refresh_data() {
    print_info "Actualisation des données..."
    
    # Actualiser tous les portefeuilles système
    for wallet_file in "UPLANETNAME_G1" "UPLANETG1PUB" "UPLANETNAME_SOCIETY"; do
        if [[ -f "$HOME/.zen/tmp/$wallet_file" ]]; then
            local pubkey=$(cat "$HOME/.zen/tmp/$wallet_file" 2>/dev/null)
            if [[ -n "$pubkey" ]]; then
                "${MY_PATH}/tools/G1check.sh" "$pubkey" >/dev/null 2>&1
            fi
        fi
    done
    
    # Actualiser le portefeuille CAPTAIN dédié (2xPAF)
    if [[ -f "$HOME/.zen/game/uplanet.captain.dunikey" ]]; then
        local captain_pubkey=$(cat "$HOME/.zen/game/uplanet.captain.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        if [[ -n "$captain_pubkey" ]]; then
            "${MY_PATH}/tools/G1check.sh" "$captain_pubkey" >/dev/null 2>&1
        fi
    fi
    
    # Actualiser les portefeuilles utilisateurs
    if [[ -d ~/.zen/game/nostr ]]; then
        for account_name in $(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev); do
            local g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
            if [[ -n "$g1pub" ]]; then
                "${MY_PATH}/tools/G1check.sh" "$g1pub" >/dev/null 2>&1
            fi
        done
    fi
    
    if [[ -d ~/.zen/game/players ]]; then
        for player_dir in $(ls ~/.zen/game/players/*@*.*/.g1pub 2>/dev/null | rev | cut -d '/' -f 2 | rev); do
            local g1pub=$(cat ~/.zen/game/players/${player_dir}/.g1pub 2>/dev/null)
            if [[ -n "$g1pub" ]]; then
                "${MY_PATH}/tools/G1check.sh" "$g1pub" >/dev/null 2>&1
            fi
        done
    fi
    
    print_success "Données actualisées avec succès !"
    echo ""
}

# Fonction pour vérifier et initialiser l'infrastructure UPLANET
check_and_init_uplanet_infrastructure() {
    print_section "VÉRIFICATION DE L'INFRASTRUCTURE UPLANET"
    
    # Vérifier si UPLANET.init.sh existe
    if [[ ! -f "${MY_PATH}/UPLANET.init.sh" ]]; then
        print_error "UPLANET.init.sh non trouvé. Infrastructure manquante."
        return 1
    fi
    
    # Vérifier si les portefeuilles UPLANET sont initialisés
    local uplanet_initialized=true
    
    # Vérifier UPLANETNAME_G1 (réserve principale)
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        uplanet_initialized=false
        print_warning "UPLANETNAME_G1 (Réserve Ğ1) non initialisé"
    fi
    
    # Vérifier les portefeuilles coopératifs
    local coop_wallets=("uplanet.CASH.dunikey" "uplanet.RnD.dunikey" "uplanet.ASSETS.dunikey" "uplanet.IMPOT.dunikey")
    for wallet in "${coop_wallets[@]}"; do
        if [[ ! -f "$HOME/.zen/game/$wallet" ]]; then
            uplanet_initialized=false
            print_warning "Portefeuille coopératif $wallet non initialisé"
        fi
    done
    
    # Vérifier le portefeuille NODE (Armateur)
    if [[ ! -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
        uplanet_initialized=false
        print_warning "Portefeuille NODE (Armateur) non initialisé"
    fi
    
    if [[ "$uplanet_initialized" == "false" ]]; then
        print_info "Initialisation de l'infrastructure UPLANET requise..."
        
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "Voulez-vous initialiser l'infrastructure UPLANET maintenant ? (oui/non): " init_uplanet
            if [[ "$init_uplanet" != "oui" && "$init_uplanet" != "o" && "$init_uplanet" != "y" && "$init_uplanet" != "yes" ]]; then
                print_error "Infrastructure UPLANET requise pour continuer"
                return 1
            fi
        fi
        
        print_info "Lancement de UPLANET.init.sh..."
        if "${MY_PATH}/UPLANET.init.sh"; then
            print_success "Infrastructure UPLANET initialisée avec succès !"
        else
            print_error "Échec de l'initialisation UPLANET"
            return 1
        fi
    else
        print_success "Infrastructure UPLANET déjà initialisée !"
    fi
    
    return 0
}

# Fonction pour afficher le menu de broadcast NOSTR
show_nostr_broadcast_menu() {
    print_header "BROADCAST NOSTR - COMMUNICATION RÉSEAU"
    
    echo -e "${CYAN}Choisissez votre action de communication:${NC}"
    echo ""
    
    echo -e "${GREEN}1. 📢 Message Personnalisé${NC}"
    echo -e "   • Saisir un message personnalisé"
    echo -e "   • Envoi à tous les utilisateurs MULTIPASS"
    echo -e "   • Mode interactif avec confirmation"
    echo ""
    
    echo -e "${GREEN}2. 🔔 Message de Test${NC}"
    echo -e "   • Message de test prédéfini"
    echo -e "   • Vérification de la connectivité réseau"
    echo -e "   • Test des clés NOSTR du capitaine"
    echo ""
    
    echo -e "${GREEN}3. 📋 Mode Dry-Run${NC}"
    echo -e "   • Simulation sans envoi réel"
    echo -e "   • Vérification des destinataires"
    echo -e "   • Test de la configuration"
    echo ""
    
    echo -e "${GREEN}4. 📊 Statistiques Réseau${NC}"
    echo -e "   • Nombre d'utilisateurs MULTIPASS"
    echo -e "   • État de la connectivité NOSTR"
    echo -e "   • Vérification des clés du capitaine"
    echo ""
    
    echo -e "${GREEN}0. ⬅️  Retour au tableau de bord${NC}"
    echo ""
    
    read -p "Votre choix: " broadcast_choice
    
    case $broadcast_choice in
        1)
            send_custom_nostr_message
            ;;
        2)
            send_test_nostr_message
            ;;
        3)
            test_nostr_broadcast
            ;;
        4)
            show_network_statistics
            ;;
        0)
            show_captain_dashboard
            return
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            show_nostr_broadcast_menu
            ;;
    esac
}

# Fonction pour envoyer un message personnalisé
send_custom_nostr_message() {
    print_section "ENVOI DE MESSAGE PERSONNALISÉ"
    
    echo -e "${CYAN}Saisissez votre message (appuyez sur ENTRÉE pour terminer):${NC}"
    echo ""
    
    # Lire le message sur plusieurs lignes
    local message=""
    local line=""
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            break
        fi
        if [[ -n "$message" ]]; then
            message="$message"$'\n'"$line"
        else
            message="$line"
        fi
    done
    
    if [[ -z "$message" ]]; then
        print_error "Message vide"
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}Message à envoyer:${NC}"
    echo "----------------------------------------"
    echo "$message"
    echo "----------------------------------------"
    echo ""
    
    read -p "Confirmer l'envoi ? (oui/non): " confirm
    if [[ "$confirm" != "oui" && "$confirm" != "o" && "$confirm" != "y" && "$confirm" != "yes" ]]; then
        print_info "Envoi annulé"
        return 1
    fi
    
    print_info "Envoi du message personnalisé..."
    echo ""
    
    if "${MY_PATH}/tools/nostr_CAPTAIN_broadcast.sh" "$message" --verbose; then
        print_success "Message envoyé avec succès !"
    else
        print_error "Erreur lors de l'envoi du message"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
    show_nostr_broadcast_menu
}

# Fonction pour envoyer un message de test
send_test_nostr_message() {
    print_section "ENVOI DE MESSAGE DE TEST"
    
    print_info "Envoi d'un message de test à tous les utilisateurs MULTIPASS..."
    echo ""
    
    if "${MY_PATH}/tools/nostr_CAPTAIN_broadcast.sh" --verbose; then
        print_success "Message de test envoyé avec succès !"
    else
        print_error "Erreur lors de l'envoi du message de test"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
    show_nostr_broadcast_menu
}

# Fonction pour tester le broadcast sans envoi
test_nostr_broadcast() {
    print_section "TEST DRY-RUN DU BROADCAST"
    
    print_info "Test de la configuration sans envoi réel..."
    echo ""
    
    if "${MY_PATH}/tools/nostr_CAPTAIN_broadcast.sh" --dry-run --verbose; then
        print_success "Test réussi ! La configuration est correcte."
    else
        print_error "Problème détecté dans la configuration"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
    show_nostr_broadcast_menu
}

# Fonction pour afficher les statistiques du réseau
show_network_statistics() {
    print_section "STATISTIQUES DU RÉSEAU NOSTR"
    
    # Vérifier les clés du capitaine
    if [[ -z "$CAPTAINEMAIL" ]]; then
        print_error "CAPTAINEMAIL non défini"
        return 1
    fi
    
    local captain_nostr_file="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    if [[ -f "$captain_nostr_file" ]]; then
        print_success "Clés NOSTR du capitaine: Présentes"
        source "$captain_nostr_file"
        if [[ -n "$NSEC" ]]; then
            echo -e "  🔑 NSEC: ${GREEN}${NSEC:0:20}...${NC}"
        else
            print_warning "NSEC non trouvé dans les clés"
        fi
    else
        print_error "Clés NOSTR du capitaine: Absentes"
        echo -e "  📁 Fichier attendu: $captain_nostr_file"
    fi
    
    echo ""
    
    # Compter les utilisateurs MULTIPASS
    local multipass_count=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
    echo -e "${CYAN}👥 Utilisateurs MULTIPASS: ${WHITE}$multipass_count${NC}"
    
    # Tester la découverte des utilisateurs
    print_info "Test de découverte des utilisateurs réseau..."
    local users_json=$("${MY_PATH}/tools/search_for_this_hex_in_uplanet.sh" --json --multipass 2>/dev/null)
    
    if [[ -n "$users_json" ]]; then
        local user_count=$(echo "$users_json" | jq length 2>/dev/null || echo "0")
        echo -e "  📊 Utilisateurs découverts: ${GREEN}$user_count${NC}"
        
        if [[ "$user_count" -gt 0 ]]; then
            echo -e "  📋 Détails des utilisateurs:"
            echo "$users_json" | jq -r '.[] | "    • \(.hex) (\(.source))"' 2>/dev/null
        fi
    else
        print_warning "Aucun utilisateur découvert dans le réseau"
    fi
    
    echo ""
    
    # Vérifier la connectivité relay
    if [[ -n "$myRELAY" ]]; then
        echo -e "${CYAN}🌐 Relay NOSTR: ${GREEN}$myRELAY${NC}"
    else
        print_warning "Relay NOSTR non configuré"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
    show_nostr_broadcast_menu
}

# Fonction pour vérifier que les comptes coopératifs peuvent couvrir 3xPAF/semaine
check_cooperative_balance() {
    local paf_weekly="${PAF:-14}"
    local required_zen=$(echo "$paf_weekly * 3" | bc -l)
    local required_g1=$(zen_to_g1 "$required_zen")
    
    print_section "VÉRIFICATION DES COMPTES COOPÉRATIFS"
    
    echo -e "${CYAN}💰 Vérification que les comptes coopératifs peuvent couvrir 3xPAF/semaine${NC}"
    echo -e "${YELLOW}  Requis: ${required_zen} Ẑen (${required_g1} Ğ1) pour 3xPAF hebdomadaire${NC}"
    echo ""
    
    # Vérifier UPLANETNAME_G1 (réserve principale)
    local g1_pubkey=""
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1" 2>/dev/null)
        if [[ -n "$g1_pubkey" ]]; then
            local g1_balance=$(get_wallet_balance "$g1_pubkey")
            local g1_zen=$(calculate_zen "$g1_balance")
            echo -e "${BLUE}🏛️  UPLANETNAME_G1: ${g1_zen} Ẑen (${g1_balance} Ğ1)${NC}"
            
            if (( $(echo "$g1_zen >= $required_zen" | bc -l) )); then
                print_success "✅ UPLANETNAME_G1 a suffisamment de fonds"
            else
                print_warning "⚠️  UPLANETNAME_G1 insuffisant (${g1_zen} Ẑen < ${required_zen} Ẑen requis)"
                echo -e "${YELLOW}💡 Vous devrez alimenter UPLANETNAME_G1 depuis OpenCollective${NC}"
            fi
        fi
    else
        print_warning "⚠️  UPLANETNAME_G1 non configuré"
    fi
    
    # UPLANETNAME_G1 est la source de tous les ẐEN de la UPlanet
    local total_coop_zen=0
    if [[ -n "$g1_pubkey" ]]; then
        local g1_balance_val=$(get_wallet_balance "$g1_pubkey")
        local g1_zen_val=$(calculate_zen "$g1_balance_val")
        total_coop_zen=$(echo "$total_coop_zen + $g1_zen_val" | bc -l)
    fi

    # Vérifier les portefeuilles coopératifs dérivés
    local coop_wallets=("CASH" "RnD" "ASSETS")

    for wallet_type in "${coop_wallets[@]}"; do
        local wallet_file="$HOME/.zen/game/uplanet.${wallet_type}.dunikey"
        if [[ -f "$wallet_file" ]]; then
            local wallet_pubkey=$(cat "$wallet_file" | grep "pub:" | cut -d ' ' -f 2 2>/dev/null)
            if [[ -n "$wallet_pubkey" ]]; then
                local wallet_balance=$(get_wallet_balance "$wallet_pubkey")
                local wallet_zen=$(calculate_zen "$wallet_balance")
                total_coop_zen=$(echo "$total_coop_zen + $wallet_zen" | bc -l)

                case $wallet_type in
                    "CASH")
                        echo -e "${GREEN}💰 UPLANETNAME_CASH: ${wallet_zen} Ẑen${NC}"
                        ;;
                    "RnD")
                        echo -e "${CYAN}🔬 UPLANETNAME_RND: ${wallet_zen} Ẑen${NC}"
                        ;;
                    "ASSETS")
                        echo -e "${YELLOW}🌳 UPLANETNAME_ASSETS: ${wallet_zen} Ẑen${NC}"
                        ;;
                esac
            fi
        fi
    done

    echo ""
    echo -e "${BLUE}📊 Total coopératif (UPLANETNAME_G1 + dérivés): ${total_coop_zen} Ẑen${NC}"

    if (( $(echo "$total_coop_zen >= $required_zen" | bc -l) )); then
        print_success "✅ Les comptes coopératifs peuvent couvrir 3xPAF/semaine"
        return 0
    else
        print_warning "⚠️  Les comptes coopératifs sont insuffisants pour couvrir 3xPAF/semaine"
        echo -e "${YELLOW}💡 Recommandation: Alimenter les comptes depuis OpenCollective avant de lancer ZEN.ECONOMY.sh${NC}"
        echo ""
        
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "Voulez-vous continuer quand même ? (oui/non): " continue_anyway
            if [[ "$continue_anyway" != "oui" && "$continue_anyway" != "o" && "$continue_anyway" != "y" && "$continue_anyway" != "yes" ]]; then
                return 1
            fi
        fi
    fi
    
    return 0
}

# Fonction principale d'embarquement
embark_captain() {
    print_header "BIENVENUE SUR ASTROPORT.ONE - EMBARQUEMENT DU CAPITAINE"
    
    echo -e "${GREEN}🎉 Félicitations! Votre station Astroport.ONE est prête.${NC}"
    echo ""
    echo -e "${CYAN}Nous allons vous guider pour créer votre écosystème ẐEN complet:${NC}"
    echo "  1. Initialiser l'infrastructure UPLANET (portefeuilles coopératifs)"
    echo "  2. Créer un compte MULTIPASS (interface CLI)"
    echo "  3. Créer une ZEN Card (interface CLI)"
    echo "  4. Inscrire le Capitaine avec DID (astroport_captain)"
    echo "  5. Inscrire l'Armateur avec apport capital infrastructure"
    echo "  6. Calculer la PAF minimum depuis l'amortissement machine"
    echo "  7. Vérifier que les comptes coopératifs peuvent couvrir 3xPAF/semaine"
    echo ""
    echo -e "${YELLOW}Cette configuration vous permettra de:${NC}"
    echo "  • Gérer une constellation locale UPlanet"
    echo "  • Participer au réseau social NOSTR"
    echo "  • Stocker et partager des fichiers sur IPFS"
    echo "  • Gagner des récompenses Ẑen et Ğ1"
    echo "  • Administrer l'économie coopérative automatisée"
    echo ""
    
    if [[ "$AUTO_MODE" == "false" ]]; then
        read -p "Voulez-vous commencer la configuration ? (oui/non): " start_config
        
        if [[ "$start_config" != "oui" && "$start_config" != "o" && "$start_config" != "y" && "$start_config" != "yes" ]]; then
            print_info "Configuration reportée. Vous pourrez la faire plus tard."
            return 1
        fi
    fi
    
    # Étape 0: Vérifier et initialiser l'infrastructure UPLANET
    if ! check_and_init_uplanet_infrastructure; then
        print_error "Impossible de continuer sans infrastructure UPLANET"
        return 1
    fi
    
    # Étape 1: Création MULTIPASS
    local email="$PRESET_EMAIL"
    local lat="$PRESET_LAT"
    local lon="$PRESET_LON"
    
    if [[ -z "$email" ]]; then
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "📧 Email: " email
            [[ -z "$email" ]] && { print_error "Email requis"; return 1; }
        else
            print_error "Email requis en mode automatique. Utilisez --email"
        return 1
        fi
    fi
    
    # Géolocalisation automatique si pas fournie
    if [[ -z "$lat" || -z "$lon" ]]; then
        if get_auto_geolocation; then
            if [[ "$AUTO_MODE" == "false" ]]; then
                read -p "📍 Latitude [$AUTO_LAT]: " lat
                read -p "📍 Longitude [$AUTO_LON]: " lon
                
                [[ -z "$lat" ]] && lat="$AUTO_LAT"
                [[ -z "$lon" ]] && lon="$AUTO_LON"
            else
                lat="$AUTO_LAT"
                lon="$AUTO_LON"
            fi
        else
            if [[ "$AUTO_MODE" == "false" ]]; then
                read -p "📍 Latitude: " lat
                read -p "📍 Longitude: " lon
            else
                print_error "Coordonnées requises en mode automatique. Utilisez --lat et --lon"
                return 1
            fi
        fi
    fi
    
    # Valeurs par défaut
    [[ -z "$lat" ]] && lat="0.00"
    [[ -z "$lon" ]] && lon="0.00"
    
    # Créer le MULTIPASS
    if ! create_multipass "$email" "$lat" "$lon" "$PRESET_LANG"; then
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "Appuyez sur ENTRÉE pour retourner au menu."
        fi
        return 1
    fi
    
    # Vérifier que le compte MULTIPASS a bien été créé
    local multipass_count=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
    if [[ $multipass_count -eq 0 ]]; then
        print_error "Aucun compte MULTIPASS trouvé. La création a échoué."
        return 1
    fi
    
    print_success "Compte MULTIPASS détecté!"
    
    # Étape 2: Création ZEN Card
    # Récupérer les informations du MULTIPASS
    local multipass_info=$(get_multipass_info "$email")
    local npub=$(echo "$multipass_info" | cut -d'|' -f1)
    local hex=$(echo "$multipass_info" | cut -d'|' -f2)
    local multipass_lat=$(echo "$multipass_info" | cut -d'|' -f3)
    local multipass_lon=$(echo "$multipass_info" | cut -d'|' -f4)
    
    # Utiliser les coordonnées du MULTIPASS si disponibles
    [[ -n "$multipass_lat" ]] && lat="$multipass_lat"
    [[ -n "$multipass_lon" ]] && lon="$multipass_lon"
    
    # Créer la ZEN Card
    if ! create_zen_card "$email" "$lat" "$lon" "$npub" "$hex"; then
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "Appuyez sur ENTRÉE pour continuer..."
        fi
        return 1
    fi
    
    # Étape 3: Mettre à jour le DID avec le statut CAPTAIN
    print_section "INSCRIPTION CAPITAINE - MISE À JOUR DU DID"
    
    echo -e "${CYAN}Mise à jour de votre identité décentralisée avec le statut Capitaine...${NC}"
    
    if "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "CAPTAIN" 0 0; then
        print_success "✅ DID mis à jour avec statut astroport_captain"
        echo -e "  • contractStatus: ${GREEN}astroport_captain${NC}"
        echo -e "  • storageQuota: ${GREEN}unlimited${NC}"
        echo -e "  • services: ${GREEN}Full access${NC}"
    else
        print_warning "⚠️  Mise à jour DID échouée - vous pouvez la faire manuellement:"
        echo -e "${CYAN}   ${MY_PATH}/UPLANET.official.sh -c $email${NC}"
    fi
    echo ""
    
    # Étape 4: Inscrire l'Armateur avec apport capital infrastructure
    print_section "INSCRIPTION ARMATEUR - APPORT CAPITAL INFRASTRUCTURE"
    
    echo -e "${CYAN}Nous allons maintenant enregistrer votre apport capital infrastructure.${NC}"
    echo -e "${YELLOW}Cet apport représente la valeur de votre machine (Raspberry Pi, PC, etc.)${NC}"
    echo ""
    
    # Demander la valeur de la machine
    local machine_value="${MACHINE_VALUE_ZEN:-500}"
    if [[ "$AUTO_MODE" == "false" ]]; then
        read -p "Valeur de votre machine en Ẑen (défaut: ${machine_value}): " input_machine_value
        [[ -n "$input_machine_value" ]] && machine_value="$input_machine_value"
    fi
    
    # Valider que c'est un nombre
    if ! [[ "$machine_value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        print_error "Valeur invalide: '$machine_value'. Utilisez un nombre (ex: 500)"
        machine_value="500"
    fi
    
    # Calculer l'amortissement suggéré pour la PAF (3 ans = 156 semaines)
    local amortization_weeks="${MACHINE_AMORTIZATION_WEEKS:-156}"  # 3 ans par défaut
    local paf_minimum=$(echo "scale=2; $machine_value / $amortization_weeks" | bc -l)
    local current_paf=$(grep "^PAF=" "${MY_PATH}/.env" 2>/dev/null | cut -d'=' -f2)
    [[ -z "$current_paf" ]] && current_paf="0"
    
    echo -e "${CYAN}💰 Apport capital infrastructure: ${machine_value} Ẑen${NC}"
    echo ""
    echo -e "${BLUE}📊 Calcul de l'amortissement:${NC}"
    echo -e "  • Valeur machine: ${YELLOW}${machine_value} Ẑen${NC}"
    echo -e "  • Période d'amortissement: ${YELLOW}${amortization_weeks} semaines${NC} ($(echo "scale=1; $amortization_weeks / 52" | bc -l) ans)"
    echo -e "  • PAF minimum suggérée: ${GREEN}${paf_minimum} Ẑen/semaine${NC}"
    echo -e "  • PAF actuelle configurée: ${YELLOW}${current_paf} Ẑen/semaine${NC}"
    echo ""
    
    if [[ $(echo "$current_paf < $paf_minimum" | bc -l) -eq 1 ]]; then
        print_warning "⚠️  Votre PAF actuelle (${current_paf}) est inférieure à l'amortissement minimum (${paf_minimum})"
        echo -e "${YELLOW}💡 Conseil: Augmentez votre PAF à au moins ${paf_minimum} Ẑen/semaine pour couvrir l'amortissement${NC}"
        echo ""
        
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "Voulez-vous mettre à jour la PAF à ${paf_minimum} Ẑen/semaine ? (oui/non): " update_paf
            if [[ "$update_paf" == "oui" || "$update_paf" == "o" || "$update_paf" == "y" || "$update_paf" == "yes" ]]; then
                sed -i "s/^PAF=.*/PAF=$paf_minimum/" "${MY_PATH}/.env" 2>/dev/null || \
                    echo "PAF=$paf_minimum" >> "${MY_PATH}/.env"
                print_success "PAF mise à jour: ${paf_minimum} Ẑen/semaine"
            fi
        fi
    else
        print_success "✅ PAF actuelle (${current_paf}) couvre l'amortissement (${paf_minimum})"
    fi
    echo ""
    
    if [[ "$AUTO_MODE" == "false" ]]; then
        read -p "Confirmer l'inscription de l'Armateur avec cet apport ? (oui/non): " confirm_armateur
        if [[ "$confirm_armateur" != "oui" && "$confirm_armateur" != "o" && "$confirm_armateur" != "y" && "$confirm_armateur" != "yes" ]]; then
            print_info "Inscription Armateur reportée"
        else
            print_info "Inscription de l'Armateur avec apport capital infrastructure..."
            if "${MY_PATH}/UPLANET.official.sh" --infrastructure -m "$machine_value"; then
                print_success "✅ Armateur inscrit avec succès !"
            else
                print_warning "⚠️  L'inscription de l'Armateur a peut-être échoué"
                echo -e "${YELLOW}💡 Vous pourrez la refaire plus tard avec:${NC}"
                echo -e "${CYAN}   ${MY_PATH}/UPLANET.official.sh --infrastructure -m ${machine_value}${NC}"
            fi
        fi
    else
        # Mode automatique
        if "${MY_PATH}/UPLANET.official.sh" --infrastructure -m "$machine_value"; then
            print_success "✅ Armateur inscrit avec succès !"
        else
            print_warning "⚠️  L'inscription de l'Armateur a peut-être échoué"
        fi
    fi
    
    echo ""
    
    # Étape 5: Vérifier que les comptes coopératifs peuvent couvrir 3xPAF/semaine
    if ! check_cooperative_balance; then
        print_warning "⚠️  Les comptes coopératifs sont insuffisants"
        echo -e "${YELLOW}💡 Important: Assurez-vous d'alimenter les comptes depuis OpenCollective avant de lancer ZEN.ECONOMY.sh${NC}"
        echo ""
    fi
    
    if [[ "$AUTO_MODE" == "false" ]]; then
        read -p "Appuyez sur ENTRÉE pour continuer..."
    fi
    
    print_success "🎉 Configuration du Capitaine terminée avec succès !"
    echo ""
    echo -e "${GREEN}✅ Votre station Astroport.ONE est maintenant configurée:${NC}"
    echo -e "  • Compte MULTIPASS: $email"
    echo -e "  • ZEN Card: $email"
    echo -e "  • DID: ${GREEN}astroport_captain${NC} (accès complet)"
    echo -e "  • Armateur: Apport capital ${machine_value} Ẑen"
    echo -e "  • PAF minimum: ${paf_minimum} Ẑen/semaine (amortissement ${amortization_weeks} semaines)"
    echo ""
    echo -e "${CYAN}📋 Prochaines étapes:${NC}"
    echo -e "  1. Alimenter UPLANETNAME_G1 depuis OpenCollective si nécessaire"
    echo -e "  2. Lancer ZEN.ECONOMY.sh pour le paiement PAF hebdomadaire"
    echo -e "  3. Utiliser le tableau de bord avec: ${MY_PATH}/captain.sh"
    echo ""
    
    return 0
}

# Fonction principale
main() {
    parse_arguments "$@"

    # Capitaine configuré → tableau de bord
    if check_captain_configured; then
        show_captain_dashboard
        return
    fi

    # Pas de capitaine configuré : proposer l'embarquement
    # (qu'il existe déjà des cartes ou non, le chemin est le même)
    if ! check_first_time_usage; then
        print_warning "Des comptes existent mais aucun Capitaine n'est configuré"
        echo ""
    fi

    if [[ "$AUTO_MODE" == "false" ]]; then
        read -p "Voulez-vous configurer un compte Capitaine maintenant ? (oui/non): " setup_captain
        if [[ "$setup_captain" == "oui" || "$setup_captain" == "o" || \
              "$setup_captain" == "y"   || "$setup_captain" == "yes" ]]; then
            embark_captain
        else
            print_info "Configuration reportée. Relancez './captain.sh' quand vous êtes prêt."
        fi
    else
        print_info "Mode automatique : lancement de l'embarquement du Capitaine..."
        embark_captain
    fi
}

# Point d'entrée
main "$@" 