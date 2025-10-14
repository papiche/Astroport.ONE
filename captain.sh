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
        ${HOME}/.zen/Astroport.ONE/tools/mailjet.sh "${email}" "${HOME}/.zen/game/nostr/${email}/.nostr.zine.html" "$YOUSER MULTIPASS"
        
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
        
        if [[ -n "$npub" ]]; then
            echo -e "  🔑 NPUB: ${GREEN}$npub${NC}"
        fi
        if [[ -n "$hex" ]]; then
            echo -e "  🟩 HEX: ${GREEN}$hex${NC}"
        fi
        echo -e "  📍 Latitude: ${GREEN}$lat${NC}"
        echo -e "  📍 Longitude: ${GREEN}$lon${NC}"
        echo -e "  📧 Email: ${GREEN}$email${NC}"
        echo ""
        echo -e "${CYAN}Vous pouvez maintenant créer votre ZEN Card avec ces informations.${NC}"
        echo ""
        
        if [[ "$AUTO_MODE" == "false" ]]; then
            read -p "Voulez-vous utiliser ces informations pour créer la ZEN Card ? (oui/non): " use_multipass_info
            
            if [[ "$use_multipass_info" != "oui" && "$use_multipass_info" != "o" && "$use_multipass_info" != "y" && "$use_multipass_info" != "yes" ]]; then
                print_info "Création de la ZEN Card annulée"
                return 1
            fi
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
        
        # Mettre à jour .current
        rm -f ~/.zen/game/players/.current
        ln -s ~/.zen/game/players/${player} ~/.zen/game/players/.current
        
        print_success "Configuration terminée avec succès!"
        echo ""
        echo -e "${GREEN}🎉 Félicitations! Votre station est maintenant configurée:${NC}"
        echo "  • Compte MULTIPASS: $email"
        echo "  • ZEN Card: $player"
        echo "  • G1PUB: $g1pub"
        echo "  • IPNS: $myIPFS/ipns/$astronautens"
        echo ""
        echo -e "${CYAN}Vous pouvez maintenant utiliser toutes les fonctionnalités d'Astroport.ONE!${NC}"
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
        local zen=$(echo "($g1_balance - 1) * 10" | bc -l 2>/dev/null | cut -d '.' -f 1)
        echo "$zen"
    else
        echo "0"
    fi
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

# Fonction pour afficher le tableau de bord économique du capitaine
show_captain_dashboard() {
    print_header "ASTROPORT.ONE - TABLEAU DE BORD DU CAPITAINE"
    
    # Récupérer le capitaine actuel
    local current_captain=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
    if [[ -z "$current_captain" ]]; then
        print_error "Aucun capitaine connecté"
        return 1
    fi
    
    echo -e "${GREEN}👑 CAPITAINE ACTUEL: ${WHITE}$current_captain${NC}"
    echo ""
    
    # Informations détaillées du capitaine
    show_captain_details "$current_captain"
    
    # Portefeuilles système UPlanet
    print_section "PORTEFEUILLES SYSTÈME UPLANET"
    
    # UPLANETNAME.G1 (Réserve Ğ1) - Source primale, pas de conversion ẐEN
    local uplanet_g1_pubkey=""
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        uplanet_g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1" 2>/dev/null)
    fi
    
    if [[ -n "$uplanet_g1_pubkey" ]]; then
        local g1_balance=$(get_wallet_balance "$uplanet_g1_pubkey")
        echo -e "${BLUE}🏛️  UPLANETNAME.G1 (Réserve Ğ1):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$g1_balance Ğ1${NC}"
        echo -e "  📝 Usage: Source primale - Alimentation de tous les portefeuilles"
        echo -e "  ℹ️  Note: Réserve en Ğ1 pure (non convertie en ẐEN)"
        echo ""
    else
        echo -e "${RED}🏛️  UPLANETNAME.G1: ${YELLOW}Non configuré${NC}"
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
        echo -e "  📊 Chiffre d'Affaires (historique RENTAL): ${CYAN}$revenue_zen Ẑen${NC} (${YELLOW}$revenue_g1 Ğ1${NC})"
        echo -e "  📈 Ventes de services: ${WHITE}$revenue_txcount${NC} transactions"
        echo -e "  📝 Usage: Revenus locatifs MULTIPASS + services"
        echo ""
    else
        echo -e "${RED}💼 UPLANETNAME: ${YELLOW}Non configuré${NC}"
        echo -e "  💡 Pour configurer: Lancez UPLANET.init.sh"
        echo ""
    fi
    
    # UPLANETNAME.SOCIETY (Capital Social) - Utilise G1society.sh pour l'historique
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
        
        echo -e "${BLUE}⭐ UPLANETNAME.SOCIETY (Capital Social):${NC}"
        echo -e "  💰 Solde brut: ${YELLOW}$society_balance Ğ1${NC}"
        echo -e "  📊 Parts sociales distribuées (historique): ${CYAN}$society_zen Ẑen${NC} (${YELLOW}$society_g1 Ğ1${NC})"
        echo -e "  👥 Sociétaires enregistrés: ${WHITE}$society_txcount${NC} membres"
        echo -e "  📝 Usage: Émission parts sociales ZEN Cards"
        echo ""
    else
        echo -e "${RED}⭐ UPLANETNAME.SOCIETY: ${YELLOW}Non configuré${NC}"
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
        echo -e "${GREEN}💰 UPLANETNAME.CASH (Trésorerie 1/3):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$cash_balance Ğ1${NC} (${CYAN}$cash_zen Ẑen${NC})"
        echo -e "  📝 Usage: Solidarité PAF + réserve opérationnelle"
    else
        echo -e "${RED}💰 UPLANETNAME.CASH: ${YELLOW}Non configuré${NC}"
    fi
    
    # RND (R&D)
    local rnd_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
        rnd_pubkey=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$rnd_pubkey" ]]; then
        local rnd_balance=$(get_wallet_balance "$rnd_pubkey")
        local rnd_zen=$(calculate_zen "$rnd_balance")
        echo -e "${CYAN}🔬 UPLANETNAME.RND (R&D 1/3):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$rnd_balance Ğ1${NC} (${CYAN}$rnd_zen Ẑen${NC})"
        echo -e "  📝 Usage: Développement + innovation"
    else
        echo -e "${RED}🔬 UPLANETNAME.RND: ${YELLOW}Non configuré${NC}"
    fi
    
    # ASSETS (Actifs)
    local assets_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$assets_pubkey" ]]; then
        local assets_balance=$(get_wallet_balance "$assets_pubkey")
        local assets_zen=$(calculate_zen "$assets_balance")
        echo -e "${YELLOW}🌳 UPLANETNAME.ASSETS (Actifs 1/3):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$assets_balance Ğ1${NC} (${CYAN}$assets_zen Ẑen${NC})"
        echo -e "  📝 Usage: Forêts jardins + impact écologique"
    else
        echo -e "${RED}🌳 UPLANETNAME.ASSETS: ${YELLOW}Non configuré${NC}"
    fi
    
    # IMPOT (Fiscalité)
    local impot_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.IMPOT.dunikey" ]]; then
        impot_pubkey=$(cat "$HOME/.zen/game/uplanet.IMPOT.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    fi
    
    if [[ -n "$impot_pubkey" ]]; then
        local impot_balance=$(get_wallet_balance "$impot_pubkey")
        local impot_zen=$(calculate_zen "$impot_balance")
        echo -e "${PURPLE}🏛️  UPLANETNAME.IMPOT (Fiscalité):${NC}"
        echo -e "  💰 Solde: ${YELLOW}$impot_balance Ğ1${NC} (${CYAN}$impot_zen Ẑen${NC})"
        echo -e "  📝 Usage: TVA collectée + provision IS"
    else
        echo -e "${RED}🏛️  UPLANETNAME.IMPOT: ${YELLOW}Non configuré${NC}"
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
    
    # Afficher le diagramme de flux économique
    show_economic_flow_diagram
    
    # Menu de navigation
    show_captain_navigation_menu
}

# Fonction pour afficher les détails du capitaine
show_captain_details() {
    local captain_email="$1"
    
    print_section "DÉTAILS DU CAPITAINE"
    
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
    echo -e "${BLUE}1️⃣  FLUX LOCATAIRE:${NC}"
    echo -e "   OpenCollective → UPLANETNAME → MULTIPASS"
    echo -e "   💰 Paiement loyer → Services → Primo TX"
    echo ""
    
    # Flux 2: Sociétaire (Vert)
    echo -e "${GREEN}2️⃣  FLUX SOCIÉTAIRE:${NC}"
    echo -e "   OpenCollective → UPLANETNAME.SOCIETY → ZenCard"
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

# Fonction pour afficher le menu de navigation du capitaine
show_captain_navigation_menu() {
    print_section "NAVIGATION DU CAPITAINE"
    
    echo -e "${WHITE}Choisissez votre action:${NC}"
    echo ""
    
    echo -e "${GREEN}1. 💰 Gestion Économique (zen.sh)${NC}"
    echo -e "   • Transactions UPLANETNAME.G1, UPLANETG1PUB, UPLANETNAME.SOCIETY"
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
    
    echo -e "${GREEN}6. 🔄 Actualiser les Données${NC}"
    echo -e "   • Mise à jour des soldes et cache"
    echo -e "   • Synchronisation avec le réseau Ğ1"
    echo -e "   • Actualisation des statistiques"
    echo ""
    
    echo -e "${GREEN}7. 📋 Nouvel Embarquement${NC}"
    echo -e "   • Créer un nouveau MULTIPASS ou ZEN Card"
    echo -e "   • Configuration d'un nouvel utilisateur"
    echo -e "   • Intégration dans l'écosystème"
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
            refresh_data
            ;;
        7)
            embark_captain
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
    echo -e "   • Burn 4-semaines (NODE → UPLANETNAME.G1 → OpenCollective)"
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
    
    # Vérifier UPLANETNAME.G1 (réserve principale)
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        uplanet_initialized=false
        print_warning "UPLANETNAME.G1 (Réserve Ğ1) non initialisé"
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

# Fonction principale d'embarquement
embark_captain() {
    print_header "BIENVENUE SUR ASTROPORT.ONE - EMBARQUEMENT DU CAPITAINE"
    
    echo -e "${GREEN}🎉 Félicitations! Votre station Astroport.ONE est prête.${NC}"
    echo ""
    echo -e "${CYAN}Nous allons vous guider pour créer votre écosystème ẐEN complet:${NC}"
    echo "  1. Initialiser l'infrastructure UPLANET (portefeuilles coopératifs)"
    echo "  2. Créer un compte MULTIPASS (interface CLI)"
    echo "  3. Créer une ZEN Card (interface CLI)"
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
    
    if [[ "$AUTO_MODE" == "false" ]]; then
        read -p "Appuyez sur ENTRÉE pour continuer..."
    fi
    
    return 0
}

# Fonction principale
main() {
    # Parser les arguments
    parse_arguments "$@"
    
    # Vérifier si c'est la première utilisation
    if ! check_first_time_usage; then
        # Il y a déjà des comptes - afficher le tableau de bord du capitaine
        show_captain_dashboard
    else
        # Première utilisation - procéder à l'embarquement
        embark_captain
    fi
}

# Point d'entrée
main "$@" 