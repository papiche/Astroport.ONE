#!/bin/bash
################################################################################
# update_config.sh - Mise à jour configuration UPlanet ẐEN
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Met à jour la configuration pour les utilisateurs existants d'Astroport.ONE
# vers la nouvelle architecture UPlanet ẐEN
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ENV_FILE="$HOME/.zen/Astroport.ONE/.env"
ENV_TEMPLATE="$MY_PATH/.env.template"

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                    ${YELLOW}🔄 MISE À JOUR UPLANET ẐEN${NC}                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}              ${CYAN}Mise à jour de votre configuration existante${NC}               ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}💡 $1${NC}"
}

# Fonction pour détecter le mode UPlanet actuel
detect_uplanet_mode() {
    local has_swarm_key=false
    local has_origin_accounts=false
    local current_mode="unknown"
    
    # Vérifier la présence de swarm.key
    if [[ -f "$HOME/.ipfs/swarm.key" ]]; then
        has_swarm_key=true
    fi
    
    # Vérifier la présence de comptes ORIGIN
    if [[ -d "$HOME/.zen/game/nostr" ]] || [[ -d "$HOME/.zen/game/players" ]]; then
        has_origin_accounts=true
    fi
    
    # Déterminer le mode
    if [[ "$has_swarm_key" == true ]]; then
        current_mode="zen"
    elif [[ "$has_origin_accounts" == true ]]; then
        current_mode="origin"
    else
        current_mode="fresh"
    fi
    
    echo "$current_mode|$has_swarm_key|$has_origin_accounts"
}

# Fonction principale de mise à jour
update_configuration() {
    print_header
    
    echo -e "${BLUE}🔄 Mise à jour de votre configuration UPlanet${NC}"
    echo ""
    
    # Détecter le mode actuel
    local mode_info=$(detect_uplanet_mode)
    local current_mode=$(echo "$mode_info" | cut -d'|' -f1)
    local has_swarm_key=$(echo "$mode_info" | cut -d'|' -f2)
    local has_origin_accounts=$(echo "$mode_info" | cut -d'|' -f3)
    
    # Afficher le mode détecté
    case "$current_mode" in
        "zen")
            local uplanetname=$(cat "$HOME/.ipfs/swarm.key" 2>/dev/null | head -c 20)
            echo -e "${GREEN}🏴‍☠️ Mode détecté: UPlanet ẐEN${NC}"
            echo -e "   UPlanet: ${YELLOW}${uplanetname}...${NC}"
            ;;
        "origin")
            echo -e "${BLUE}🌍 Mode détecté: UPlanet ORIGIN${NC}"
            echo -e "   Réseau IPFS public, économie simplifiée"
            ;;
        "fresh")
            echo -e "${CYAN}🆕 Installation fraîche détectée${NC}"
            echo -e "   Aucun mode UPlanet configuré"
            ;;
    esac
    echo ""
    
    # Gestion spécifique selon le mode
    case "$current_mode" in
        "zen")
            handle_zen_update
            ;;
        "origin")
            handle_origin_update
            ;;
        "fresh")
            handle_fresh_update
            ;;
    esac
}

# Gestion de la mise à jour pour mode ẐEN
handle_zen_update() {
    echo -e "${GREEN}🏴‍☠️ Gestion UPlanet ẐEN${NC}"
    echo ""
    
    print_warning "Vous êtes déjà en mode ẐEN"
    echo -e "${YELLOW}Rappel: Une fois en ẐEN, impossible de changer de UPlanet${NC}"
    echo -e "${YELLOW}sans réinstallation complète de Astroport.ONE${NC}"
    echo ""
    
    # Mise à jour de la configuration existante
    update_existing_config
    
    echo ""
    echo -e "${CYAN}Actions disponibles:${NC}"
    echo -e "  1. 📊 Mettre à jour les paramètres économiques"
    echo -e "  2. 🚀 Lancer l'assistant d'embarquement complet"
    echo -e "  3. ❌ Annuler"
    echo ""
    
    read -p "Votre choix [1]: " zen_choice
    zen_choice="${zen_choice:-1}"
    
    case "$zen_choice" in
        1)
            launch_onboarding_assistant
            ;;
        2)
            launch_full_onboarding
            ;;
        3)
            print_info "Mise à jour annulée"
            ;;
        *)
            print_warning "Choix invalide, lancement des paramètres économiques"
            launch_onboarding_assistant
            ;;
    esac
}

# Gestion de la mise à jour pour mode ORIGIN
handle_origin_update() {
    echo -e "${BLUE}🌍 Gestion UPlanet ORIGIN${NC}"
    echo ""
    
    print_info "Vous êtes actuellement en mode ORIGIN (réseau IPFS public)"
    echo ""
    
    # Compter les comptes existants
    local nostr_count=0
    local player_count=0
    
    if [[ -d "$HOME/.zen/game/nostr" ]]; then
        nostr_count=$(ls -1d "$HOME/.zen/game/nostr"/*@*.* 2>/dev/null | wc -l)
    fi
    
    if [[ -d "$HOME/.zen/game/players" ]]; then
        player_count=$(ls -1d "$HOME/.zen/game/players"/*@*.* 2>/dev/null | wc -l)
    fi
    
    if [[ $nostr_count -gt 0 ]] || [[ $player_count -gt 0 ]]; then
        echo -e "${YELLOW}Comptes ORIGIN détectés:${NC}"
        echo -e "   • MULTIPASS NOSTR: ${CYAN}$nostr_count${NC}"
        echo -e "   • ZEN Card PLAYER: ${CYAN}$player_count${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}Options disponibles:${NC}"
    echo -e "  1. 🔄 Rester en ORIGIN et mettre à jour la configuration"
    echo -e "  2. 🏴‍☠️ Passer en mode ẐEN (DESTRUCTIF - désinscrit tous les comptes)"
    echo -e "  3. ❌ Annuler"
    echo ""
    
    read -p "Votre choix [1]: " origin_choice
    origin_choice="${origin_choice:-1}"
    
    case "$origin_choice" in
        1)
            handle_origin_stay
            ;;
        2)
            handle_origin_to_zen_migration
            ;;
        3)
            print_info "Mise à jour annulée"
            ;;
        *)
            print_warning "Choix invalide, conservation du mode ORIGIN"
            handle_origin_stay
            ;;
    esac
}

# Rester en mode ORIGIN
handle_origin_stay() {
    echo -e "${BLUE}🌍 Conservation du mode ORIGIN${NC}"
    echo ""
    
    # Mise à jour de la configuration
    update_existing_config
    
    echo ""
    print_success "Configuration ORIGIN mise à jour"
    
    # Proposer l'assistant d'embarquement
    launch_onboarding_assistant
}

# Migration ORIGIN vers ẐEN
handle_origin_to_zen_migration() {
    echo -e "${RED}🏴‍☠️ MIGRATION ORIGIN → ẐEN${NC}"
    echo ""
    
    print_warning "ATTENTION: Cette opération est DESTRUCTIVE et IRRÉVERSIBLE"
    echo ""
    echo -e "${RED}Actions qui seront effectuées:${NC}"
    echo "   • Désinscription de TOUS les MULTIPASS NOSTR existants"
    echo "   • Désinscription de TOUTES les ZEN Card PLAYER existantes"
    echo "   • Suppression des wallets coopératifs ORIGIN"
    echo "   • Nettoyage complet du cache"
    echo ""
    echo -e "${YELLOW}Raison: Les comptes ORIGIN proviennent de la source primale${NC}"
    echo -e "${YELLOW}'EnfinLibre', incompatible avec la source ẐEN (swarm.key)${NC}"
    echo ""
    
    read -p "Êtes-vous ABSOLUMENT SÛR de vouloir migrer vers ẐEN ? (tapez 'OUI'): " confirm_migration
    
    if [[ "$confirm_migration" != "OUI" ]]; then
        print_info "Migration annulée - conservation du mode ORIGIN"
        handle_origin_stay
        return 0
    fi
    
    echo ""
    print_info "Démarrage de la migration ORIGIN → ẐEN..."
    
    # Exécuter le nettoyage via l'assistant d'embarquement
    if [[ -f "$MY_PATH/uplanet_onboarding.sh" ]]; then
        echo ""
        print_info "Lancement de l'assistant d'embarquement pour la migration..."
        echo -e "${CYAN}L'assistant vous guidera pour:${NC}"
        echo "   1. Effectuer le nettoyage ORIGIN"
        echo "   2. Configurer le mode ẐEN"
        echo "   3. Obtenir une swarm.key"
        echo "   4. Passer au niveau Y"
        echo "   5. Initialiser UPLANET ẐEN"
        echo ""
        
        # Forcer le mode ẐEN dans l'assistant
        export FORCE_ZEN_MODE=true
        "$MY_PATH/uplanet_onboarding.sh"
    else
        print_error "Assistant d'embarquement non trouvé"
        print_error "Migration impossible sans l'assistant"
    fi
}

# Gestion installation fraîche
handle_fresh_update() {
    echo -e "${CYAN}🆕 Installation fraîche${NC}"
    echo ""
    
    print_info "Aucun mode UPlanet configuré"
    echo ""
    
    # Créer la configuration de base
    update_existing_config
    
    echo ""
    echo -e "${CYAN}Voulez-vous configurer UPlanet maintenant ?${NC}"
    echo ""
    read -p "Lancer l'assistant d'embarquement ? (O/n): " launch_choice
    
    if [[ "$launch_choice" != "n" && "$launch_choice" != "N" ]]; then
        launch_full_onboarding
    else
        echo ""
        echo -e "${BLUE}📋 Configuration de base créée${NC}"
        echo -e "   Fichier: ${CYAN}$ENV_FILE${NC}"
        echo ""
        echo -e "${YELLOW}Prochaines étapes:${NC}"
        echo -e "   • Embarquement: ${CYAN}$MY_PATH/uplanet_onboarding.sh${NC}"
        echo -e "   • Tableau de bord: ${CYAN}$MY_PATH/tools/dashboard.sh${NC}"
    fi
}

# Mise à jour de la configuration existante
update_existing_config() {
    if [[ -f "$ENV_FILE" ]]; then
        print_info "Configuration existante trouvée: $ENV_FILE"
        
        # Sauvegarder l'ancienne configuration
        local backup_file="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_FILE" "$backup_file"
        print_success "Sauvegarde créée: $backup_file"
    fi
    
    # Copier le template si nécessaire
    if [[ -f "$ENV_TEMPLATE" ]]; then
        if [[ ! -f "$ENV_FILE" ]]; then
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            print_success "Configuration créée depuis le template"
        else
            # Fusionner avec la configuration existante
            merge_configurations
        fi
    else
        print_error "Template de configuration manquant: $ENV_TEMPLATE"
        return 1
    fi
    
    print_success "Configuration mise à jour"
}

# Lancer l'assistant d'embarquement (paramètres économiques)
launch_onboarding_assistant() {
    echo ""
    echo -e "${CYAN}Lancement de l'assistant d'embarquement...${NC}"
    
    if [[ -f "$MY_PATH/uplanet_onboarding.sh" ]]; then
        "$MY_PATH/uplanet_onboarding.sh"
    else
        print_error "Assistant d'embarquement non trouvé"
        echo ""
        echo -e "${BLUE}📋 Prochaines étapes recommandées:${NC}"
        echo -e "   • Tableau de bord: ${CYAN}$MY_PATH/tools/dashboard.sh${NC}"
        echo -e "   • Configuration: ${CYAN}$ENV_FILE${NC}"
    fi
}

# Lancer l'embarquement complet
launch_full_onboarding() {
    echo ""
    echo -e "${CYAN}Lancement de l'embarquement complet...${NC}"
    
    if [[ -f "$MY_PATH/uplanet_onboarding.sh" ]]; then
        "$MY_PATH/uplanet_onboarding.sh"
    else
        print_error "Assistant d'embarquement non trouvé"
    fi
}

# Fonction pour fusionner les configurations
merge_configurations() {
    print_info "Fusion de la configuration existante avec le nouveau template..."
    
    # Lire les valeurs existantes
    local existing_values=()
    while IFS='=' read -r key value; do
        if [[ "$key" =~ ^[A-Z_]+$ ]] && [[ ! "$key" =~ ^# ]]; then
            existing_values["$key"]="$value"
        fi
    done < "$ENV_FILE"
    
    # Copier le nouveau template
    cp "$ENV_TEMPLATE" "${ENV_FILE}.new"
    
    # Restaurer les valeurs existantes
    for key in "${!existing_values[@]}"; do
        local value="${existing_values[$key]}"
        if grep -q "^${key}=" "${ENV_FILE}.new"; then
            sed -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}.new"
        fi
    done
    
    # Remplacer l'ancien fichier
    mv "${ENV_FILE}.new" "$ENV_FILE"
    
    print_success "Configuration fusionnée"
}

# Fonction pour afficher la configuration actuelle
show_current_config() {
    print_header
    
    echo -e "${BLUE}📋 Configuration actuelle:${NC}"
    echo ""
    
    if [[ -f "$ENV_FILE" ]]; then
        echo -e "${GREEN}Fichier: $ENV_FILE${NC}"
        echo ""
        
        # Afficher les paramètres principaux
        echo -e "${CYAN}Paramètres économiques:${NC}"
        grep -E "^(PAF|NCARD|ZCARD|MACHINE_VALUE_ZEN|MACHINE_TYPE)=" "$ENV_FILE" 2>/dev/null | while IFS='=' read -r key value; do
            echo -e "   • $key: ${YELLOW}$value${NC}"
        done
        
        echo ""
        echo -e "${CYAN}Configuration réseau:${NC}"
        grep -E "^(myIPFS|myAPI|myASTROPORT|myHOST)=" "$ENV_FILE" 2>/dev/null | while IFS='=' read -r key value; do
            if [[ -n "$value" ]]; then
                echo -e "   • $key: ${YELLOW}$value${NC}"
            fi
        done
        
        echo ""
        echo -e "${CYAN}Autres paramètres:${NC}"
        grep -E "^(DEBUG|isLAN|COOPERATIVE_ADMIN_EMAIL)=" "$ENV_FILE" 2>/dev/null | while IFS='=' read -r key value; do
            if [[ -n "$value" ]]; then
                echo -e "   • $key: ${YELLOW}$value${NC}"
            fi
        done
    else
        print_warning "Aucune configuration trouvée"
        echo -e "   Fichier attendu: ${CYAN}$ENV_FILE${NC}"
    fi
    
    echo ""
}

# Menu principal
show_menu() {
    print_header
    
    echo -e "${BLUE}🔧 Gestionnaire de configuration UPlanet ẐEN${NC}"
    echo ""
    echo -e "${CYAN}Options disponibles:${NC}"
    echo -e "  1. 🔄 Mettre à jour la configuration"
    echo -e "  2. 📋 Afficher la configuration actuelle"
    echo -e "  3. 🚀 Lancer l'assistant d'embarquement"
    echo -e "  4. 🏛️  Initialiser UPLANET"
    echo -e "  5. 📊 Ouvrir le tableau de bord"
    echo -e "  0. ❌ Quitter"
    echo ""
    
    read -p "Votre choix: " choice
    
    case "$choice" in
        1)
            update_configuration
            ;;
        2)
            show_current_config
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
        3)
            if [[ -f "$MY_PATH/uplanet_onboarding.sh" ]]; then
                "$MY_PATH/uplanet_onboarding.sh"
            else
                print_error "Assistant d'embarquement non trouvé"
                read -p "Appuyez sur Entrée pour continuer..."
                show_menu
            fi
            ;;
        4)
            if [[ -f "$MY_PATH/UPLANET.init.sh" ]]; then
                "$MY_PATH/UPLANET.init.sh"
            else
                print_error "Script UPLANET.init.sh non trouvé"
                read -p "Appuyez sur Entrée pour continuer..."
                show_menu
            fi
            ;;
        5)
            if [[ -f "$MY_PATH/tools/dashboard.sh" ]]; then
                "$MY_PATH/tools/dashboard.sh"
            else
                print_error "Tableau de bord non trouvé"
                read -p "Appuyez sur Entrée pour continuer..."
                show_menu
            fi
            ;;
        0)
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            show_menu
            ;;
    esac
}

# Point d'entrée principal
main() {
    # Vérifier les prérequis
    if [[ ! -d "$HOME/.zen" ]]; then
        print_error "Répertoire ~/.zen non trouvé. Astroport.ONE est-il installé ?"
        exit 1
    fi
    
    # Créer le répertoire de configuration si nécessaire
    mkdir -p "$(dirname "$ENV_FILE")"
    
    # Si des arguments sont fournis, exécuter directement
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --update|-u)
                update_configuration
                ;;
            --show|-s)
                show_current_config
                ;;
            --onboard|-o)
                if [[ -f "$MY_PATH/uplanet_onboarding.sh" ]]; then
                    "$MY_PATH/uplanet_onboarding.sh"
                else
                    print_error "Assistant d'embarquement non trouvé"
                    exit 1
                fi
                ;;
            --help|-h)
                echo "Usage: $0 [option]"
                echo "Options:"
                echo "  -u, --update    Mettre à jour la configuration"
                echo "  -s, --show      Afficher la configuration actuelle"
                echo "  -o, --onboard   Lancer l'assistant d'embarquement"
                echo "  -h, --help      Afficher cette aide"
                exit 0
                ;;
            *)
                print_error "Option inconnue: $1"
                echo "Utilisez --help pour voir les options disponibles"
                exit 1
                ;;
        esac
    else
        # Lancer le menu interactif
        show_menu
    fi
}

# Lancement du script
main "$@"
