#!/bin/bash
################################################################################
# uplanet_onboarding.sh - Assistant d'embarquement UPlanet ẐEN
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Guide le nouveau capitaine pour rejoindre la coopérative UPlanet ẐEN
# - Configuration .env personnalisée
# - Valorisation machine et PAF
# - Récupération swarm.key
# - Initialisation UPLANET
# - Adhésion coopérative
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
ENV_FILE="$HOME/.zen/Astroport.ONE/.env"
ENV_TEMPLATE="$MY_PATH/.env.template"

################################################################################
# Fonctions utilitaires
################################################################################

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                    ${YELLOW}🏴‍☠️ EMBARQUEMENT UPLANET ẐEN${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                ${CYAN}Bienvenue dans la Coopérative des Autohébergeurs${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${CYAN}🔹 $1${NC}"
    echo -e "${YELLOW}$(printf '%.0s=' {1..60})${NC}"
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

# Fonction pour redémarrer IPFS
restart_ipfs_service() {
    print_info "Redémarrage d'IPFS pour appliquer la nouvelle configuration..."
    sudo systemctl restart ipfs
    sleep 3
    print_success "IPFS redémarré avec la nouvelle clé swarm"
}

# Fonction pour détecter les ressources système via heartbox_analysis.sh
detect_system_resources() {
    local heartbox_script="$MY_PATH/tools/heartbox_analysis.sh"
    
    if [[ -f "$heartbox_script" ]]; then
        # Utiliser heartbox_analysis.sh pour obtenir les données système
        local analysis_json=$("$heartbox_script" export --json 2>/dev/null)
        
        if [[ -n "$analysis_json" ]]; then
            local cpu_cores=$(echo "$analysis_json" | jq -r '.system.cpu.cores // "4"' 2>/dev/null || echo "4")
            local ram_gb=$(echo "$analysis_json" | jq -r '.system.memory.total_gb // "8"' 2>/dev/null || echo "8")
            local disk_available=$(echo "$analysis_json" | jq -r '.system.storage.available // "100G"' 2>/dev/null || echo "100G")
            local disk_gb=$(echo "$disk_available" | sed 's/G//' | sed 's/T/*1024/' | bc 2>/dev/null || echo "100")
            
            echo "$cpu_cores|$ram_gb|$disk_gb"
            return 0
        fi
    fi
    
    # Fallback si heartbox_analysis.sh n'est pas disponible
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}' 2>/dev/null || echo "8")
    local disk_gb=$(df -BG / | awk 'NR==2{print $2}' | sed 's/G//' 2>/dev/null || echo "100")
    
    echo "$cpu_cores|$ram_gb|$disk_gb"
}

# Fonction pour obtenir les capacités via heartbox_analysis.sh
get_system_capacities() {
    local heartbox_script="$MY_PATH/tools/heartbox_analysis.sh"
    
    if [[ -f "$heartbox_script" ]]; then
        local analysis_json=$("$heartbox_script" export --json 2>/dev/null)
        
        if [[ -n "$analysis_json" ]]; then
            local zencard_slots=$(echo "$analysis_json" | jq -r '.capacities.zencard_slots // "0"' 2>/dev/null || echo "0")
            local nostr_slots=$(echo "$analysis_json" | jq -r '.capacities.nostr_slots // "0"' 2>/dev/null || echo "0")
            local available_space=$(echo "$analysis_json" | jq -r '.capacities.available_space_gb // "0"' 2>/dev/null || echo "0")
            
            echo "$zencard_slots|$nostr_slots|$available_space"
            return 0
        fi
    fi
    
    # Fallback simple
    echo "0|0|0"
}

# Fonction pour suggérer le type de machine
suggest_machine_type() {
    local resources=$(detect_system_resources)
    local cpu_cores=$(echo "$resources" | cut -d'|' -f1)
    local ram_gb=$(echo "$resources" | cut -d'|' -f2)
    local disk_gb=$(echo "$resources" | cut -d'|' -f3)
    
    # Obtenir les capacités calculées
    local capacities=$(get_system_capacities)
    local zencard_slots=$(echo "$capacities" | cut -d'|' -f1)
    local nostr_slots=$(echo "$capacities" | cut -d'|' -f2)
    local available_space=$(echo "$capacities" | cut -d'|' -f3)
    
    echo -e "${BLUE}🖥️  Ressources détectées:${NC}"
    echo -e "   • CPU: ${CYAN}$cpu_cores cœurs${NC}"
    echo -e "   • RAM: ${CYAN}$ram_gb Go${NC}"
    echo -e "   • Disque disponible: ${CYAN}$disk_gb Go${NC}"
    echo ""
    
    echo -e "${BLUE}📊 Capacités d'hébergement calculées:${NC}"
    echo -e "   • ZEN Cards (128Go): ${YELLOW}$zencard_slots slots${NC}"
    echo -e "   • MULTIPASS (10Go): ${YELLOW}$nostr_slots slots${NC}"
    echo -e "   • Espace total disponible: ${CYAN}$available_space Go${NC}"
    echo ""
    
    # Suggestion basée sur les ressources ET les capacités
    if [[ $cpu_cores -ge 8 && $ram_gb -ge 16 && $zencard_slots -ge 10 ]]; then
        echo -e "${GREEN}💻 Machine recommandée: ${YELLOW}Constellation${NC} (serveur puissant)"
        echo "constellation"
    elif [[ $cpu_cores -ge 4 && $ram_gb -ge 8 && $zencard_slots -ge 2 ]]; then
        echo -e "${GREEN}💻 Machine recommandée: ${YELLOW}PC Gamer${NC} (station intermédiaire)"
        echo "pc_gamer"
    else
        echo -e "${GREEN}💻 Machine recommandée: ${YELLOW}Satellite${NC} (station légère)"
        echo "satellite"
    fi
}

################################################################################
# Étapes d'embarquement
################################################################################

# Étape 1: Introduction et présentation
step_introduction() {
    print_header
    print_section "PRÉSENTATION UPLANET ẐEN"
    
    echo -e "${GREEN}🌟 Félicitations ! Vous venez d'installer Astroport.ONE${NC}"
    echo ""
    echo -e "${BLUE}🏴‍☠️ Qu'est-ce qu'un Capitaine UPlanet ?${NC}"
    echo "   Vous êtes propriétaire d'une ♥️BOX (CoeurBox) qui participe"
    echo "   à l'économie décentralisée UPlanet en fournissant des services"
    echo "   d'hébergement et en recevant des Ẑen en échange."
    echo ""
    echo -e "${BLUE}💰 Économie ẐEN:${NC}"
    echo "   • 1 Ẑen = 0.1 Ğ1 (monnaie libre)"
    echo "   • PAF: Participation Aux Frais (coûts opérationnels)"
    echo "   • Parts sociales: Capital coopératif (valorisation machine)"
    echo "   • Revenus: Services d'hébergement pour locataires/sociétaires"
    echo ""
    echo -e "${BLUE}🤝 Coopérative:${NC}"
    echo "   • Gouvernance démocratique (1 membre = 1 voix)"
    echo "   • Répartition 3x1/3: Trésorerie, R&D, Actifs"
    echo "   • Mutualisation des risques et des bénéfices"
    echo ""
    
    read -p "Êtes-vous prêt à rejoindre la coopérative UPlanet ẐEN ? (o/N): " ready
    if [[ "$ready" != "o" && "$ready" != "O" ]]; then
        echo -e "${YELLOW}Vous pouvez relancer cet assistant plus tard avec:${NC}"
        echo -e "${CYAN}~/.zen/Astroport.ONE/uplanet_onboarding.sh${NC}"
        exit 0
    fi
}

# Étape 2: Configuration économique
step_economic_configuration() {
    print_section "CONFIGURATION ÉCONOMIQUE"
    
    # Copier le template si .env n'existe pas
    if [[ ! -f "$ENV_FILE" ]]; then
        if [[ -f "$ENV_TEMPLATE" ]]; then
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            print_success "Fichier de configuration créé: $ENV_FILE"
        else
            print_error "Template de configuration manquant: $ENV_TEMPLATE"
            return 1
        fi
    else
        print_info "Configuration existante trouvée: $ENV_FILE"
    fi
    
    echo ""
    echo -e "${BLUE}💰 Configuration des paramètres économiques:${NC}"
    echo ""
    
    # PAF (Participation Aux Frais)
    local current_paf=$(grep "^PAF=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "14")
    echo -e "${CYAN}PAF (Participation Aux Frais hebdomadaire):${NC}"
    echo "   La PAF couvre vos coûts opérationnels (électricité, internet, maintenance)"
    echo "   Valeur recommandée: 14 Ẑen/semaine (≈ 1.4 Ğ1)"
    read -p "PAF hebdomadaire en Ẑen [$current_paf]: " new_paf
    new_paf="${new_paf:-$current_paf}"
    
    # Tarifs services
    local current_ncard=$(grep "^NCARD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "1")
    local current_zcard=$(grep "^ZCARD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "4")
    
    echo ""
    echo -e "${CYAN}Tarifs de vos services d'hébergement:${NC}"
    echo "   MULTIPASS: Compte social NOSTR (10Go stockage)"
    read -p "Tarif MULTIPASS hebdomadaire en Ẑen [$current_ncard]: " new_ncard
    new_ncard="${new_ncard:-$current_ncard}"
    
    echo "   ZEN Card: Identité économique (128Go stockage)"
    read -p "Tarif ZEN Card hebdomadaire en Ẑen [$current_zcard]: " new_zcard
    new_zcard="${new_zcard:-$current_zcard}"
    
    # Mettre à jour le fichier .env
    sed -i "s/^PAF=.*/PAF=$new_paf/" "$ENV_FILE"
    sed -i "s/^NCARD=.*/NCARD=$new_ncard/" "$ENV_FILE"
    sed -i "s/^ZCARD=.*/ZCARD=$new_zcard/" "$ENV_FILE"
    
    print_success "Configuration économique mise à jour"
    
    # Résumé
    echo ""
    echo -e "${BLUE}📊 Résumé de votre configuration:${NC}"
    echo -e "   • PAF: ${YELLOW}$new_paf Ẑen/semaine${NC} (vos coûts)"
    echo -e "   • MULTIPASS: ${YELLOW}$new_ncard Ẑen/semaine${NC} (vos revenus)"
    echo -e "   • ZEN Card: ${YELLOW}$new_zcard Ẑen/semaine${NC} (vos revenus)"
    echo -e "   • Bénéfice potentiel: ${GREEN}$(echo "($new_ncard + $new_zcard) - $new_paf" | bc) Ẑen/semaine${NC} (par utilisateur)"
    echo ""
}

# Étape 3: Valorisation machine
step_machine_valuation() {
    print_section "VALORISATION DE VOTRE MACHINE"
    
    echo -e "${BLUE}💻 Évaluation de votre capital machine:${NC}"
    echo ""
    
    # Détecter et suggérer le type de machine
    local suggested_type=$(suggest_machine_type)
    echo ""
    
    echo -e "${CYAN}Types de valorisation disponibles:${NC}"
    echo -e "  1. 🛰️  ${YELLOW}Satellite${NC} (500€ → 500 Ẑen) - RPi, mini-PC"
    echo -e "  2. 🎮 ${YELLOW}PC Gamer${NC} (4000€ → 4000 Ẑen) - Station puissante"
    echo -e "  3. 💼 ${YELLOW}Serveur Pro${NC} (8000€ → 8000 Ẑen) - Infrastructure professionnelle"
    echo -e "  4. 🔧 ${YELLOW}Personnalisée${NC} - Valorisation sur mesure"
    echo ""
    
    local default_choice="1"
    case "$suggested_type" in
        "constellation") default_choice="3" ;;
        "pc_gamer") default_choice="2" ;;
        *) default_choice="1" ;;
    esac
    
    read -p "Choisissez le type de valorisation [$default_choice]: " machine_choice
    machine_choice="${machine_choice:-$default_choice}"
    
    local machine_value=""
    local machine_type=""
    
    case "$machine_choice" in
        1)
            machine_value="500"
            machine_type="Satellite"
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
            echo ""
            echo -e "${CYAN}Valorisation personnalisée:${NC}"
            echo "   Estimez la valeur de votre machine (coût d'achat ou remplacement)"
            read -p "Valeur en euros: " custom_value
            if [[ "$custom_value" =~ ^[0-9]+$ ]] && [[ "$custom_value" -gt 0 ]]; then
                machine_value="$custom_value"
                machine_type="Machine personnalisée"
            else
                print_error "Valeur invalide, utilisation de la valeur par défaut (500€)"
                machine_value="500"
                machine_type="Satellite"
            fi
            ;;
        *)
            print_warning "Choix invalide, utilisation de la valeur par défaut"
            machine_value="500"
            machine_type="Satellite"
            ;;
    esac
    
    # Mettre à jour le fichier .env (uniquement les paramètres économiques)
    sed -i "s/^MACHINE_VALUE_ZEN=.*/MACHINE_VALUE_ZEN=$machine_value/" "$ENV_FILE"
    sed -i "s/^MACHINE_TYPE=.*/MACHINE_TYPE=\"$machine_type\"/" "$ENV_FILE"
    
    # Note: Les ressources système sont maintenant obtenues dynamiquement via heartbox_analysis.sh
    # Plus besoin de les stocker dans .env
    
    print_success "Valorisation machine configurée"
    
    echo ""
    echo -e "${BLUE}💰 Votre apport au capital social:${NC}"
    echo -e "   • Type: ${YELLOW}$machine_type${NC}"
    echo -e "   • Valeur: ${YELLOW}$machine_value €${NC} = ${CYAN}$machine_value Ẑen${NC}"
    echo -e "   • Parts sociales: Vous devenez sociétaire de la coopérative"
    echo -e "   • Droits: Vote, gouvernance, répartition des bénéfices"
    echo ""
}

# Variable globale pour le parcours choisi
UPLANET_MODE=""

# Étape 4: Choix du mode UPlanet
step_uplanet_mode_choice() {
    print_section "CHOIX DU MODE UPLANET"
    
    # Si FORCE_ZEN_MODE est défini (migration depuis update_config.sh)
    if [[ "$FORCE_ZEN_MODE" == "true" ]]; then
        print_info "Migration ORIGIN → ẐEN en cours..."
        UPLANET_MODE="zen"
        
        # Effectuer le nettoyage ORIGIN → ẐEN
        cleanup_origin_to_zen
        
        echo ""
        print_success "Mode UPlanet ẐEN forcé pour la migration"
        return 0
    fi
    
    echo -e "${BLUE}🎯 Choisissez votre mode UPlanet:${NC}"
    echo ""
    
    # Vérifier si swarm.key existe déjà
    local has_swarm_key=false
    if [[ -f "$HOME/.ipfs/swarm.key" ]]; then
        has_swarm_key=true
        print_info "Clé swarm existante détectée"
        echo -e "   Fichier: ${CYAN}$HOME/.ipfs/swarm.key${NC}"
        echo -e "   Mode actuel: ${YELLOW}UPlanet ẐEN (Niveau Y)${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}Modes disponibles:${NC}"
    echo -e "  1. 🌍 ${YELLOW}UPlanet ORIGIN (Niveau X)${NC} - Réseau public, économie simplifiée"
    echo -e "  2. 🏴‍☠️ ${YELLOW}UPlanet ẐEN (Niveau Y)${NC} - Réseau privé, économie coopérative complète"
    echo ""
    
    echo -e "${BLUE}🌍 UPlanet ORIGIN (Niveau X):${NC}"
    echo "   • Réseau IPFS public standard"
    echo "   • Économie UPlanet basique"
    echo "   • Initialisation UPLANET immédiate"
    echo "   • Pas de swarm.key nécessaire"
    echo "   • Idéal pour débuter ou tester"
    echo ""
    
    echo -e "${BLUE}🏴‍☠️ UPlanet ẐEN (Niveau Y):${NC}"
    echo "   • Réseau IPFS privé avec swarm.key"
    echo "   • Économie coopérative complète"
    echo "   • Nécessite un ami capitaine ou BLOOM"
    echo "   • Passage au niveau Y obligatoire"
    echo "   • Production et gouvernance décentralisée"
    echo ""
    
    if [[ "$has_swarm_key" == true ]]; then
        echo -e "${YELLOW}⚠️  Attention: Vous avez déjà une clé swarm (mode ẐEN actuel)${NC}"
        echo -e "   Choisir ORIGIN supprimera la clé swarm et les wallets ẐEN existants"
        echo ""
    fi
    
    local default_choice="1"
    if [[ "$has_swarm_key" == true ]]; then
        default_choice="2"
    fi
    
    read -p "Choisissez votre mode [$default_choice]: " mode_choice
    mode_choice="${mode_choice:-$default_choice}"
    
    case "$mode_choice" in
        1)
            UPLANET_MODE="origin"
            print_success "Mode UPlanet ORIGIN (Niveau X) sélectionné"
            
            if [[ "$has_swarm_key" == true ]]; then
                echo ""
                print_error "Passage de ẐEN vers ORIGIN impossible !"
                echo -e "${RED}Une fois en mode ẐEN, vous ne pouvez pas revenir à ORIGIN${NC}"
                echo -e "${YELLOW}Raisons techniques:${NC}"
                echo "   • Les comptes sont liés à la source primale ẐEN"
                echo "   • La désinscription complète est complexe"
                echo "   • Risque de perte de données et de fonds"
                echo ""
                echo -e "${CYAN}Solutions:${NC}"
                echo "   • Restez en mode ẐEN (recommandé)"
                echo "   • Réinstallez Astroport.ONE sur un OS frais pour ORIGIN"
                echo ""
                print_info "Conservation forcée du mode ẐEN actuel"
                UPLANET_MODE="zen"
                return 0
            fi
            ;;
        2)
            UPLANET_MODE="zen"
            print_success "Mode UPlanet ẐEN (Niveau Y) sélectionné"
            
            if [[ "$has_swarm_key" == false ]]; then
                # Passage ORIGIN → ẐEN : désinscription nécessaire
                if [[ -d "$HOME/.zen/game/nostr" ]] || [[ -d "$HOME/.zen/game/players" ]]; then
                    echo ""
                    print_warning "Passage ORIGIN → ẐEN détecté"
                    echo -e "${YELLOW}Comptes ORIGIN existants détectés${NC}"
                    echo -e "${RED}Ces comptes doivent être désinscrits car ils proviennent${NC}"
                    echo -e "${RED}de la mauvaise source primale (EnfinLibre vs swarm.key)${NC}"
                    echo ""
                    echo -e "${CYAN}Actions qui seront effectuées:${NC}"
                    echo "   • Désinscription de tous les MULTIPASS NOSTR"
                    echo "   • Désinscription de toutes les ZEN Card PLAYER"
                    echo "   • Suppression des wallets coopératifs ORIGIN"
                    echo "   • Nettoyage du cache"
                    echo ""
                    read -p "Confirmer le passage ORIGIN → ẐEN ? (o/N): " confirm_zen
                    if [[ "$confirm_zen" != "o" && "$confirm_zen" != "O" ]]; then
                        print_info "Annulation - conservation du mode ORIGIN"
                        UPLANET_MODE="origin"
                        return 0
                    fi
                    
                    # Nettoyer les comptes ORIGIN
                    cleanup_origin_to_zen
                fi
                echo -e "${CYAN}Vous devrez obtenir une swarm.key pour rejoindre un réseau ẐEN${NC}"
            fi
            ;;
        *)
            print_warning "Choix invalide, sélection du mode ORIGIN par défaut"
            UPLANET_MODE="origin"
            ;;
    esac
    
    echo ""
    print_info "Mode sélectionné: $UPLANET_MODE"
}

# Fonction de nettoyage lors du passage ORIGIN → ẐEN
cleanup_origin_to_zen() {
    print_info "Nettoyage ORIGIN pour passage vers ẐEN..."
    
    # Désinscription de tous les MULTIPASS et ZEN Card ORIGIN
    print_warning "Désinscription des comptes ORIGIN (source primale incorrecte)..."
    
    # Désinscription des MULTIPASS NOSTR
    if [[ -d "$HOME/.zen/game/nostr" ]]; then
        for nostr_dir in "$HOME/.zen/game/nostr"/*@*.*; do
            if [[ -d "$nostr_dir" ]]; then
                local email=$(basename "$nostr_dir")
                print_info "Désinscription MULTIPASS: $email"
                
                # Utiliser nostr_DESTROY_TW.sh pour désinscription propre
                if [[ -f "$MY_PATH/tools/nostr_DESTROY_TW.sh" ]]; then
                    "$MY_PATH/tools/nostr_DESTROY_TW.sh" "$email" 2>/dev/null || true
                else
                    # Nettoyage manuel si le script n'existe pas
                    rm -rf "$nostr_dir"
                fi
            fi
        done
    fi
    
    # Désinscription des ZEN Card PLAYER
    if [[ -d "$HOME/.zen/game/players" ]]; then
        for player_dir in "$HOME/.zen/game/players"/*@*.*; do
            if [[ -d "$player_dir" ]]; then
                local email=$(basename "$player_dir")
                print_info "Désinscription ZEN Card: $email"
                
                # Utiliser PLAYER.unplug.sh si disponible
                if [[ -f "$MY_PATH/RUNTIME/PLAYER.unplug.sh" && -f "$player_dir/ipfs/moa/index.html" ]]; then
                    "$MY_PATH/RUNTIME/PLAYER.unplug.sh" "$player_dir/ipfs/moa/index.html" "$email" "ALL" 2>/dev/null || true
                else
                    # Nettoyage manuel
                    rm -rf "$player_dir"
                fi
            fi
        done
    fi
    
    # Supprimer les wallets coopératifs ORIGIN
    local origin_wallets=(
        "$HOME/.zen/game/uplanet.dunikey"
        "$HOME/.zen/game/uplanet.SOCIETY.dunikey"
        "$HOME/.zen/game/uplanet.CASH.dunikey"
        "$HOME/.zen/game/uplanet.RnD.dunikey"
        "$HOME/.zen/game/uplanet.ASSETS.dunikey"
        "$HOME/.zen/game/uplanet.IMPOT.dunikey"
        "$HOME/.zen/game/secret.NODE.dunikey"
    )
    
    for wallet in "${origin_wallets[@]}"; do
        if [[ -f "$wallet" ]]; then
            rm -f "$wallet"
            print_info "Wallet ORIGIN supprimé: $(basename "$wallet")"
        fi
    done
    
    # Supprimer les fichiers de configuration ORIGIN
    rm -f "$HOME/.zen/tmp/UPLANETG1PUB"
    rm -f "$HOME/.zen/game/MY_boostrap_nodes.txt"
    rm -f "$HOME/.zen/game/My_boostrap_ssh.txt"
    
    # Nettoyer le cache
    rm -f "$HOME/.zen/tmp/coucou"/*.* 2>/dev/null || true
    
    print_success "Nettoyage ORIGIN → ẐEN terminé"
    print_warning "Tous les comptes ORIGIN ont été désinscrits"
}


# Étape 5: Configuration réseau (selon le mode)
step_network_configuration() {
    if [[ "$UPLANET_MODE" == "origin" ]]; then
        step_network_origin
    elif [[ "$UPLANET_MODE" == "zen" ]]; then
        step_network_zen
    else
        print_error "Mode UPlanet non défini"
        return 1
    fi
}

# Configuration réseau pour UPlanet ORIGIN
step_network_origin() {
    print_section "CONFIGURATION RÉSEAU ORIGIN"
    
    echo -e "${BLUE}🌍 Configuration UPlanet ORIGIN (Niveau X):${NC}"
    echo ""
    
    # S'assurer qu'il n'y a pas de swarm.key (mode public)
    if [[ -f "$HOME/.ipfs/swarm.key" ]]; then
        print_info "Suppression de la clé swarm pour rester en mode public"
        rm -f "$HOME/.ipfs/swarm.key"
        restart_ipfs_service
    fi
    
    print_success "Configuration réseau ORIGIN terminée"
    echo -e "${CYAN}Vous êtes maintenant sur le réseau IPFS public${NC}"
}

# Configuration réseau pour UPlanet ẐEN
step_network_zen() {
    print_section "CONFIGURATION RÉSEAU ẐEN"
    
    echo -e "${BLUE}🏴‍☠️ Configuration UPlanet ẐEN (Niveau Y):${NC}"
    echo ""
    
    # Vérifier si swarm.key existe déjà
    if [[ -f "$HOME/.ipfs/swarm.key" ]]; then
        print_info "Clé swarm ẐEN existante trouvée"
        echo -e "   Fichier: ${CYAN}$HOME/.ipfs/swarm.key${NC}"
        
        # Afficher l'UPLANETNAME actuel
        local current_uplanetname=$(cat "$HOME/.ipfs/swarm.key" 2>/dev/null | head -c 20)
        echo -e "   UPlanet actuelle: ${YELLOW}${current_uplanetname}...${NC}"
        echo ""
        
        print_error "Changement d'UPlanet ẐEN impossible !"
        echo -e "${RED}Une fois connecté à une UPlanet ẐEN, vous ne pouvez pas${NC}"
        echo -e "${RED}changer vers une autre UPlanet sans réinstallation complète.${NC}"
        echo ""
        echo -e "${YELLOW}Raisons techniques:${NC}"
        echo "   • Les comptes sont liés à l'UPLANETNAME actuel"
        echo "   • Les sources primales sont différentes entre UPlanet"
        echo "   • La migration nécessite une désinscription complète"
        echo "   • Risque de perte de données et de fonds"
        echo ""
        echo -e "${CYAN}Solutions:${NC}"
        echo "   • Restez sur votre UPlanet ẐEN actuelle (recommandé)"
        echo "   • Réinstallez Astroport.ONE sur un OS frais pour changer"
        echo ""
        print_success "Conservation de la configuration UPlanet ẐEN actuelle"
        return 0
    fi
    
    echo -e "${CYAN}Options de connexion au réseau UPlanet ẐEN:${NC}"
    echo -e "  1. 🤝 ${YELLOW}Rejoindre UPlanet existante${NC} (ami capitaine - recommandé)"
    echo -e "  2. 🌍 ${YELLOW}Formation automatique BLOOM${NC} (9+ stations même région)"
    echo -e "  3. 🏠 ${YELLOW}Réseau local/privé${NC} (fournir swarm.key)"
    echo -e "  4. 🔧 ${YELLOW}Configuration manuelle${NC}"
    echo ""
    
    read -p "Choisissez votre mode de connexion [1]: " network_choice
    network_choice="${network_choice:-1}"
    
    case "$network_choice" in
        1)
            echo ""
            print_info "Rejoindre une UPlanet ẐEN existante..."
            echo ""
            echo -e "${CYAN}Pour rejoindre une UPlanet existante, vous devez:${NC}"
            echo "   1. Être ami avec un Capitaine d'un relais Astroport"
            echo "   2. Récupérer manuellement le fichier swarm.key"
            echo ""
            echo -e "${BLUE}Transfert SSH (~/.ssh/authorized.keys):${NC}"
            echo -e "   • ${CYAN}Capitaine ami${NC}: scp captain@armateurnode.oooz.fr:~/.ipfs/swarm.key"
            echo ""
            echo -e "${YELLOW}Contactez un capitaine ami pour obtenir la swarm.key${NC}"
            echo -e "${CYAN}Puis placez-la dans: $HOME/.ipfs/swarm.key${NC}"
            ;;
        2)
            echo ""
            print_info "Formation automatique d'un swarm via BLOOM.Me.sh..."
            echo ""
            echo -e "${CYAN}Conditions requises pour BLOOM automatique:${NC}"
            echo "   • Minimum 9 stations Astroport niveau Y dans la même région GPS"
            echo "   • Concordance SSH ↔ IPFS NodeID sur chaque station"
            echo "   • Connectivité WAN (IP publique)"
            echo ""
            
            # Vérifier si BLOOM.Me.sh existe
            if [[ -f "$MY_PATH/RUNTIME/BLOOM.Me.sh" ]]; then
                read -p "Lancer BLOOM.Me.sh maintenant ? (O/n): " launch_bloom
                if [[ "$launch_bloom" != "n" && "$launch_bloom" != "N" ]]; then
                    print_info "Lancement de BLOOM.Me.sh..."
                    if "$MY_PATH/RUNTIME/BLOOM.Me.sh"; then
                        print_success "BLOOM.Me.sh exécuté - vérifiez si un swarm s'est formé"
                    else
                        print_warning "BLOOM.Me.sh terminé - pas assez de stations ou conditions non remplies"
                    fi
                else
                    print_info "BLOOM.Me.sh sera exécuté automatiquement par le système"
                fi
            else
                print_error "Script BLOOM.Me.sh non trouvé"
            fi
            ;;
        3)
            echo ""
            echo -e "${CYAN}Configuration réseau local/privé:${NC}"
            echo "   Vous devez obtenir le fichier swarm.key du réseau que vous souhaitez rejoindre"
            echo ""
            read -p "Chemin vers le fichier swarm.key: " swarm_key_path
            
            if [[ -f "$swarm_key_path" ]]; then
                cp "$swarm_key_path" "$HOME/.ipfs/swarm.key"
                print_success "Clé swarm copiée"
                restart_ipfs_service
            else
                print_error "Fichier swarm.key non trouvé: $swarm_key_path"
            fi
            ;;
        4)
            print_info "Configuration manuelle sélectionnée"
            echo -e "${YELLOW}Vous devrez configurer manuellement:${NC}"
            echo "   • La clé swarm: $HOME/.ipfs/swarm.key"
            echo "   • Les paramètres réseau dans: $ENV_FILE"
            ;;
        *)
            print_warning "Choix invalide, configuration manuelle requise"
            ;;
    esac
    
    echo ""
    print_info "Configuration réseau terminée"
}

# Étape 6: Initialisation UPLANET (selon le mode)
step_uplanet_initialization() {
    if [[ "$UPLANET_MODE" == "origin" ]]; then
        step_uplanet_init_origin
    elif [[ "$UPLANET_MODE" == "zen" ]]; then
        step_uplanet_init_zen
    else
        print_error "Mode UPlanet non défini"
        return 1
    fi
}

# Initialisation UPLANET pour mode ORIGIN
step_uplanet_init_origin() {
    print_section "INITIALISATION UPLANET ORIGIN"
    
    echo -e "${BLUE}🌍 Initialisation UPlanet ORIGIN (Niveau X):${NC}"
    echo ""
    
    # Vérifier si UPLANET.init.sh existe
    if [[ ! -f "$MY_PATH/UPLANET.init.sh" ]]; then
        print_error "Script UPLANET.init.sh non trouvé"
        return 1
    fi
    
    print_info "Lancement de UPLANET.init.sh pour le mode ORIGIN..."
    echo -e "${CYAN}Ce script va:${NC}"
    echo "   • Créer les portefeuilles coopératifs de base"
    echo "   • Initialiser les clés cryptographiques"
    echo "   • Configurer l'économie UPlanet simplifiée"
    echo "   • Préparer l'infrastructure pour le niveau X"
    echo ""
    
    read -p "Lancer l'initialisation UPLANET ORIGIN ? (O/n): " launch_init
    if [[ "$launch_init" != "n" && "$launch_init" != "N" ]]; then
        echo ""
        print_info "Initialisation ORIGIN en cours..."
        
        # Lancer UPLANET.init.sh
        if "$MY_PATH/UPLANET.init.sh"; then
            print_success "Initialisation UPLANET ORIGIN terminée avec succès"
            print_success "Votre station est prête en mode ORIGIN (Niveau X)"
        else
            print_error "Erreur lors de l'initialisation UPLANET ORIGIN"
            echo -e "${YELLOW}Vous pouvez relancer manuellement:${NC}"
            echo -e "${CYAN}$MY_PATH/UPLANET.init.sh${NC}"
            return 1
        fi
    else
        print_warning "Initialisation UPLANET ORIGIN reportée"
        echo -e "${YELLOW}Vous devrez lancer manuellement:${NC}"
        echo -e "${CYAN}$MY_PATH/UPLANET.init.sh${NC}"
    fi
}

# Initialisation UPLANET pour mode ẐEN (après niveau Y)
step_uplanet_init_zen() {
    print_section "INITIALISATION UPLANET ẐEN"
    
    echo -e "${BLUE}🏴‍☠️ Initialisation UPlanet ẐEN (Niveau Y):${NC}"
    echo ""
    
    # Vérifier si la swarm.key est installée
    if [[ ! -f "$HOME/.ipfs/swarm.key" ]]; then
        print_error "Aucune clé swarm trouvée !"
        echo -e "${YELLOW}Pour le mode ẐEN, vous devez d'abord:${NC}"
        echo "   1. Obtenir une swarm.key d'un capitaine ami ou via BLOOM"
        echo "   2. La placer dans ~/.ipfs/swarm.key"
        echo "   3. Passer au niveau Y"
        echo "   4. Puis relancer cette initialisation"
        echo ""
        print_warning "Initialisation ẐEN impossible sans swarm.key"
        return 1
    fi
    
    # Vérifier si on est au niveau Y
    if [[ ! -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        print_warning "Niveau Y non détecté"
        echo -e "${YELLOW}L'initialisation ẐEN nécessite le passage au niveau Y${NC}"
        echo -e "${CYAN}L'initialisation sera faite après le passage au niveau Y${NC}"
        return 0
    fi
    
    # Vérifier si UPLANET.init.sh existe
    if [[ ! -f "$MY_PATH/UPLANET.init.sh" ]]; then
        print_error "Script UPLANET.init.sh non trouvé"
        return 1
    fi
    
    print_success "Clé swarm et niveau Y détectés - prêt pour l'initialisation ẐEN"
    echo ""
    
    print_info "Lancement de UPLANET.init.sh pour le mode ẐEN..."
    echo -e "${CYAN}Ce script va:${NC}"
    echo "   • Créer tous les portefeuilles coopératifs ẐEN"
    echo "   • Initialiser les clés cryptographiques"
    echo "   • Configurer les sources primales avec UPLANETNAME"
    echo "   • Préparer l'économie coopérative complète"
    echo "   • Synchroniser avec le réseau ẐEN"
    echo ""
    
    read -p "Lancer l'initialisation UPLANET ẐEN ? (O/n): " launch_init
    if [[ "$launch_init" != "n" && "$launch_init" != "N" ]]; then
        echo ""
        print_info "Initialisation ẐEN en cours..."
        
        # Lancer UPLANET.init.sh
        if "$MY_PATH/UPLANET.init.sh"; then
            print_success "Initialisation UPLANET ẐEN terminée avec succès"
            print_success "Votre station est maintenant intégrée au réseau ẐEN !"
        else
            print_error "Erreur lors de l'initialisation UPLANET ẐEN"
            echo -e "${YELLOW}Vous pouvez relancer manuellement:${NC}"
            echo -e "${CYAN}$MY_PATH/UPLANET.init.sh${NC}"
            return 1
        fi
    else
        print_warning "Initialisation UPLANET ẐEN reportée"
        echo -e "${YELLOW}Vous devrez lancer manuellement:${NC}"
        echo -e "${CYAN}$MY_PATH/UPLANET.init.sh${NC}"
    fi
}

# Étape 7: Passage au niveau Y (seulement pour mode ẐEN)
step_y_level_upgrade() {
    if [[ "$UPLANET_MODE" == "zen" ]]; then
        step_y_level_zen
    elif [[ "$UPLANET_MODE" == "origin" ]]; then
        step_skip_y_level_origin
    else
        print_error "Mode UPlanet non défini"
        return 1
    fi
}

# Passage au niveau Y pour mode ẐEN
step_y_level_zen() {
    print_section "PASSAGE AU NIVEAU Y - ẐEN"
    
    echo -e "${BLUE}🚀 Évolution vers le niveau Y (Autonome ẐEN):${NC}"
    echo ""
    echo -e "${CYAN}Le niveau Y ẐEN vous permet de:${NC}"
    echo "   • Devenir un nœud autonome du réseau ẐEN"
    echo "   • Participer à l'économie coopérative automatisée"
    echo "   • Recevoir des paiements automatiques"
    echo "   • Contribuer à la gouvernance décentralisée"
    echo "   • Synchroniser avec les autres capitaines ẐEN"
    echo ""
    
    # Vérifier si Ylevel.sh existe
    if [[ ! -f "$MY_PATH/tools/Ylevel.sh" ]]; then
        print_error "Script Ylevel.sh non trouvé"
        return 1
    fi
    
    # Vérifier que la swarm.key est bien installée
    if [[ ! -f "$HOME/.ipfs/swarm.key" ]]; then
        print_error "Clé swarm manquante pour le niveau Y ẐEN !"
        echo -e "${YELLOW}Le niveau Y nécessite une swarm.key installée${NC}"
        return 1
    fi
    
    read -p "Passer au niveau Y ẐEN maintenant ? (O/n): " upgrade_y
    if [[ "$upgrade_y" != "n" && "$upgrade_y" != "N" ]]; then
        echo ""
        print_info "Passage au niveau Y ẐEN en cours..."
        
        # Lancer Ylevel.sh
        if "$MY_PATH/tools/Ylevel.sh"; then
            print_success "Passage au niveau Y ẐEN terminé avec succès"
            print_success "Votre station est maintenant autonome dans le réseau ẐEN !"
            
            # Après le passage au niveau Y, relancer l'initialisation UPLANET ẐEN
            echo ""
            print_info "Maintenant que vous êtes au niveau Y, initialisation UPLANET ẐEN..."
            step_uplanet_init_zen
        else
            print_error "Erreur lors du passage au niveau Y ẐEN"
            echo -e "${YELLOW}Vous pouvez relancer manuellement:${NC}"
            echo -e "${CYAN}$MY_PATH/tools/Ylevel.sh${NC}"
            return 1
        fi
    else
        print_warning "Passage au niveau Y ẐEN reporté"
        echo -e "${YELLOW}Vous pouvez passer au niveau Y plus tard avec:${NC}"
        echo -e "${CYAN}$MY_PATH/tools/Ylevel.sh${NC}"
        echo -e "${YELLOW}N'oubliez pas de relancer l'initialisation UPLANET après !${NC}"
    fi
}

# Pas de niveau Y pour mode ORIGIN
step_skip_y_level_origin() {
    print_section "NIVEAU X - ORIGIN"
    
    echo -e "${BLUE}🌍 Vous restez au niveau X (UPlanet ORIGIN):${NC}"
    echo ""
    echo -e "${CYAN}Le niveau X ORIGIN vous offre:${NC}"
    echo "   • Accès au réseau IPFS public"
    echo "   • Économie UPlanet simplifiée"
    echo "   • Services d'hébergement de base"
    echo "   • Pas de complexité de réseau privé"
    echo "   • Idéal pour débuter ou tester"
    echo ""
    
    print_success "Configuration niveau X ORIGIN terminée"
    echo -e "${CYAN}Votre station fonctionne en mode simplifié${NC}"
}

# Étape 7: Premier embarquement capitaine
step_captain_onboarding() {
    print_section "EMBARQUEMENT CAPITAINE"
    
    echo -e "${BLUE}🏴‍☠️ Création de votre identité de Capitaine:${NC}"
    echo ""
    
    # Vérifier s'il y a déjà un capitaine
    if [[ -d "$HOME/.zen/game/players" ]] && [[ $(ls -1 "$HOME/.zen/game/players" | grep "@" | wc -l) -gt 0 ]]; then
        print_info "Capitaine(s) existant(s) détecté(s)"
        
        echo -e "${CYAN}Capitaines existants:${NC}"
        for player_dir in "$HOME/.zen/game/players"/*@*.*/; do
            if [[ -d "$player_dir" ]]; then
                local player_name=$(basename "$player_dir")
                echo -e "   • ${GREEN}$player_name${NC}"
            fi
        done
        
        echo ""
        read -p "Créer un nouveau capitaine ? (o/N): " create_new
        if [[ "$create_new" != "o" && "$create_new" != "O" ]]; then
            print_info "Conservation des capitaines existants"
            return 0
        fi
    fi
    
    echo -e "${CYAN}Lancement de l'assistant d'embarquement...${NC}"
    echo ""
    
    # Vérifier si captain.sh existe
    if [[ ! -f "$MY_PATH/captain.sh" ]]; then
        print_error "Script captain.sh non trouvé"
        return 1
    fi
    
    print_info "Lancement de captain.sh..."
    "$MY_PATH/captain.sh"
}

# Étape 8: Résumé et prochaines étapes
step_final_summary() {
    print_section "EMBARQUEMENT TERMINÉ"
    
    echo -e "${GREEN}🎉 Félicitations ! Votre embarquement UPlanet est terminé !${NC}"
    echo ""
    
    # Afficher le mode sélectionné
    if [[ "$UPLANET_MODE" == "origin" ]]; then
        echo -e "${BLUE}🌍 Mode sélectionné: ${YELLOW}UPlanet ORIGIN (Niveau X)${NC}"
        echo -e "   Réseau IPFS public, économie simplifiée"
    elif [[ "$UPLANET_MODE" == "zen" ]]; then
        echo -e "${BLUE}🏴‍☠️ Mode sélectionné: ${YELLOW}UPlanet ẐEN (Niveau Y)${NC}"
        echo -e "   Réseau IPFS privé, économie coopérative complète"
    fi
    echo ""
    
    echo -e "${BLUE}📋 Récapitulatif de votre configuration:${NC}"
    
    # Lire la configuration économique
    local paf=$(grep "^PAF=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "N/A")
    local ncard=$(grep "^NCARD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "N/A")
    local zcard=$(grep "^ZCARD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "N/A")
    local machine_value=$(grep "^MACHINE_VALUE_ZEN=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "N/A")
    local machine_type=$(grep "^MACHINE_TYPE=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "N/A")
    
    echo -e "   • PAF: ${YELLOW}$paf Ẑen/semaine${NC}"
    echo -e "   • MULTIPASS: ${YELLOW}$ncard Ẑen/semaine${NC}"
    echo -e "   • ZEN Card: ${YELLOW}$zcard Ẑen/semaine${NC}"
    echo -e "   • Machine: ${YELLOW}$machine_type${NC} (${CYAN}$machine_value Ẑen${NC})"
    echo ""
    
    # Afficher les capacités actuelles via heartbox_analysis.sh
    local capacities=$(get_system_capacities)
    local zencard_slots=$(echo "$capacities" | cut -d'|' -f1)
    local nostr_slots=$(echo "$capacities" | cut -d'|' -f2)
    local available_space=$(echo "$capacities" | cut -d'|' -f3)
    
    echo -e "${BLUE}📊 Capacités d'hébergement actuelles:${NC}"
    echo -e "   • ZEN Cards disponibles: ${GREEN}$zencard_slots slots${NC} (128Go chacune)"
    echo -e "   • MULTIPASS disponibles: ${GREEN}$nostr_slots slots${NC} (10Go chacune)"
    echo -e "   • Espace total disponible: ${CYAN}$available_space Go${NC}"
    
    # Calcul du potentiel de revenus
    if [[ "$zencard_slots" != "0" && "$nostr_slots" != "0" && "$zcard" != "N/A" && "$ncard" != "N/A" ]]; then
        local max_revenue_zen=$(echo "($zencard_slots * $zcard) + ($nostr_slots * $ncard)" | bc 2>/dev/null || echo "N/A")
        local net_revenue_zen=$(echo "$max_revenue_zen - $paf" | bc 2>/dev/null || echo "N/A")
        echo -e "   • Revenus max théoriques: ${YELLOW}$max_revenue_zen Ẑen/semaine${NC}"
        echo -e "   • Bénéfice net max: ${GREEN}$net_revenue_zen Ẑen/semaine${NC} (après PAF)"
    fi
    echo ""
    
    echo -e "${BLUE}🎯 Prochaines étapes:${NC}"
    echo ""
    echo -e "${CYAN}1. Interface principale:${NC}"
    echo -e "   ${WHITE}~/.zen/Astroport.ONE/tools/dashboard.sh${NC}"
    echo -e "   Vue d'ensemble et actions rapides quotidiennes"
    echo ""
    echo -e "${CYAN}2. Virements officiels:${NC}"
    echo -e "   ${WHITE}~/.zen/Astroport.ONE/UPLANET.official.sh${NC}"
    echo -e "   Émission de Ẑen pour locataires et sociétaires"
    echo ""
    echo -e "${CYAN}3. Analyse économique:${NC}"
    echo -e "   ${WHITE}~/.zen/Astroport.ONE/tools/zen.sh${NC}"
    echo -e "   Diagnostic et analyse des portefeuilles"
    echo ""
    echo -e "${CYAN}4. Gestion capitaines:${NC}"
    echo -e "   ${WHITE}~/.zen/Astroport.ONE/captain.sh${NC}"
    echo -e "   Embarquement nouveaux utilisateurs"
    echo ""
    
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo -e "   • Constitution ẐEN: ${CYAN}~/.zen/Astroport.ONE/RUNTIME/ZEN.ECONOMY.readme.md${NC}"
    echo -e "   • Rôles des scripts: ${CYAN}~/.zen/Astroport.ONE/SCRIPTS.ROLES.md${NC}"
    echo -e "   • Support: ${CYAN}support@qo-op.com${NC}"
    echo ""
    
    echo -e "${BLUE}🌐 Accès Web:${NC}"
    echo -e "   • Interface: ${CYAN}http://astroport.localhost/ipns/copylaradio.com${NC}"
    echo -e "   • API: ${CYAN}http://localhost:1234${NC}"
    echo ""
    
    # Vérifier l'état des services via heartbox_analysis.sh
    local heartbox_script="$MY_PATH/tools/heartbox_analysis.sh"
    if [[ -f "$heartbox_script" ]]; then
        local analysis_json=$("$heartbox_script" export --json 2>/dev/null)
        
        if [[ -n "$analysis_json" ]]; then
            echo -e "${BLUE}🔧 État des services:${NC}"
            
            local ipfs_active=$(echo "$analysis_json" | jq -r '.services.ipfs.active // false' 2>/dev/null)
            local astroport_active=$(echo "$analysis_json" | jq -r '.services.astroport.active // false' 2>/dev/null)
            local uspot_active=$(echo "$analysis_json" | jq -r '.services.uspot.active // false' 2>/dev/null)
            local nostr_active=$(echo "$analysis_json" | jq -r '.services.nostr_relay.active // false' 2>/dev/null)
            
            if [[ "$ipfs_active" == "true" ]]; then
                local ipfs_peers=$(echo "$analysis_json" | jq -r '.services.ipfs.peers_connected // 0' 2>/dev/null)
                echo -e "   • IPFS: ${GREEN}✅ Actif${NC} ($ipfs_peers pairs connectés)"
            else
                echo -e "   • IPFS: ${RED}❌ Inactif${NC}"
            fi
            
            if [[ "$astroport_active" == "true" ]]; then
                echo -e "   • Astroport: ${GREEN}✅ Actif${NC}"
            else
                echo -e "   • Astroport: ${RED}❌ Inactif${NC}"
            fi
            
            if [[ "$uspot_active" == "true" ]]; then
                echo -e "   • uSPOT: ${GREEN}✅ Actif${NC} (port 54321)"
            else
                echo -e "   • uSPOT: ${RED}❌ Inactif${NC}"
            fi
            
            if [[ "$nostr_active" == "true" ]]; then
                echo -e "   • NOSTR Relay: ${GREEN}✅ Actif${NC} (port 7777)"
            else
                echo -e "   • NOSTR Relay: ${RED}❌ Inactif${NC}"
            fi
            
            echo ""
        fi
    fi
    
    print_success "Bienvenue dans la coopérative UPlanet ẐEN !"
    echo -e "${YELLOW}Bon vent, Capitaine ! 🏴‍☠️${NC}"
    echo ""
}

################################################################################
# Menu principal
################################################################################

show_menu() {
    print_header
    
    echo -e "${BLUE}🎯 Assistant d'embarquement UPlanet ẐEN${NC}"
    echo ""
    echo -e "${CYAN}Étapes d'embarquement:${NC}"
    echo -e "  1. 📖 Présentation et introduction"
    echo -e "  2. 💰 Configuration économique (.env)"
    echo -e "  3. 💻 Valorisation de votre machine"
    echo -e "  4. 🎯 Choix du mode UPlanet (ORIGIN/ẐEN)"
    echo -e "  5. 🌐 Configuration réseau"
    echo -e "  6. 🏛️  Initialisation UPLANET"
    echo -e "  7. 🚀 Passage au niveau Y (ẐEN seulement)"
    echo -e "  8. 🏴‍☠️ Embarquement capitaine"
    echo -e "  9. 📋 Résumé et finalisation"
    echo ""
    echo -e "  ${GREEN}a${NC}. 🚀 Embarquement complet automatique"
    echo -e "  ${GREEN}c${NC}. 📊 Vérifier la configuration actuelle"
    echo -e "  ${GREEN}0${NC}. ❌ Quitter"
    echo ""
    
    read -p "Votre choix: " choice
    
    case "$choice" in
        1) step_introduction ;;
        2) step_economic_configuration ;;
        3) step_machine_valuation ;;
        4) step_uplanet_mode_choice ;;
        5) step_network_configuration ;;
        6) step_uplanet_initialization ;;
        7) step_y_level_upgrade ;;
        8) step_captain_onboarding ;;
        9) step_final_summary ;;
        a|A) 
            echo -e "${CYAN}🚀 Embarquement complet automatique...${NC}"
            step_introduction && \
            step_economic_configuration && \
            step_machine_valuation && \
            step_uplanet_mode_choice && \
            step_network_configuration && \
            step_uplanet_initialization && \
            step_y_level_upgrade && \
            step_captain_onboarding && \
            step_final_summary
            ;;
        c|C)
            print_section "CONFIGURATION ACTUELLE"
            if [[ -f "$ENV_FILE" ]]; then
                echo -e "${GREEN}Fichier de configuration: $ENV_FILE${NC}"
                echo ""
                grep -E "^(PAF|NCARD|ZCARD|MACHINE_VALUE_ZEN|MACHINE_TYPE)=" "$ENV_FILE" 2>/dev/null || echo "Configuration de base non trouvée"
            else
                echo -e "${YELLOW}Aucune configuration trouvée${NC}"
            fi
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
        0)
            echo -e "${GREEN}Au revoir ! Vous pouvez relancer cet assistant à tout moment.${NC}"
            exit 0
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            show_menu
            ;;
    esac
}

################################################################################
# Point d'entrée principal
################################################################################

main() {
    # Vérifier les prérequis
    if [[ ! -d "$HOME/.zen" ]]; then
        print_error "Répertoire ~/.zen non trouvé. Astroport.ONE est-il installé ?"
        exit 1
    fi
    
    # Créer le répertoire de configuration si nécessaire
    mkdir -p "$(dirname "$ENV_FILE")"
    
    # Lancer le menu principal
    show_menu
}

# Lancement du script
main "$@"
