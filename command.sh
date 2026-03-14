#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0 - Enhanced UX
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# Indicateur de progression
echo -e "\033[0;36m🔄 Initialisation d'Astroport.ONE...\033[0m"

# Chargement des variables d'environnement
echo -e "\033[0;36m  📦 Chargement des variables système...\033[0m"
. "${MY_PATH}/tools/my.sh"

echo -e "\033[0;32m  ✅ Variables système chargées\033[0m"

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

TS=$(date -u +%s%N | cut -b1-13)
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Variables globales
CURRENT=""
PLAYER=""
ASTRONAUTENS=""
G1PUB=""

SYSLANG=${LANG:0:2}
[[ -z "$SYSLANG" ]] && SYSLANG="en" # Fallback to english

echo -e "\033[0;36m  🎫 Vérification du capitaine connecté...\033[0m"

### CHECK and CORRECT .current
CURRENT=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${CURRENT} == "" ]] \
    && lastplayer=$(ls -t ~/.zen/game/players 2>/dev/null | grep "@" | head -n 1) \
    && [[ ${lastplayer} ]] \
    && rm -f ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${lastplayer} ~/.zen/game/players/.current && CURRENT=${lastplayer}

# Vérifier que le capitaine est bien connecté
if [[ -n "$CURRENT" ]]; then
    PLAYER="$CURRENT"
    echo -e "\033[0;36m    🔑 Récupération des clés du capitaine...\033[0m"
    G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | head -n1 | cut -d ' ' -f 1 2>/dev/null)
    echo -e "\033[0;32m    ✅ Capitaine connecté: $PLAYER\033[0m"
else
    echo -e "\033[0;33m    ⚠️  Aucun capitaine connecté\033[0m"
fi

echo -e "\033[0;36m  🌐 Génération de la clé UPlanet...\033[0m"
UPLANETG1PUB=$(${MY_PATH}/tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}")
echo -e "\033[0;32m  ✅ Clé UPlanet générée\033[0m"

# Fonctions d'affichage améliorées
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

print_status() {
    local service="$1"
    local status="$2"
    local details="$3"

    if [[ "$status" == "ACTIVE" ]]; then
        printf "  ✅ %-20s ${GREEN}%-10s${NC} %s\n" "$service" "$status" "$details"
    elif [[ "$status" == "INACTIVE" ]]; then
        printf "  ❌ %-20s ${RED}%-10s${NC} %s\n" "$service" "$status" "$details"
    else
        printf "  ⚠️  %-20s ${YELLOW}%-10s${NC} %s\n" "$service" "$status" "$details"
    fi
}

print_error() {
    echo -e "${RED}❌ ERREUR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  ATTENTION: $1${NC}"
}

# Fonction de vérification des dépendances
check_dependencies() {
    if [[ ! $(which ipfs) ]]; then
        print_error "IPFS CLI n'est pas installé"
        echo "Installez-le depuis: https://dist.ipfs.io/#go-ipfs"
        exit 1
    fi
    
    if ! pgrep -au $USER -f "ipfs daemon" > /dev/null; then
        print_error "Le daemon IPFS n'est pas démarré"
        echo "Démarrez-le avec: sudo systemctl start ipfs"
        exit 1
    fi
}

# Fonction pour vérifier le statut réel des services - Optimisée avec cache
check_services_status() {
    local services_status=()
    local nextcloud_available=false
    
    # Utiliser le cache heartbox_analysis.sh pour une détection rapide et cohérente
    local heartbox_cache="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"
    local use_cache=false
    
    if [[ -f "$heartbox_cache" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$heartbox_cache" 2>/dev/null || echo 0) ))
        if [[ $cache_age -lt 300 ]]; then  # 5 minutes = 300 secondes
            use_cache=true
        fi
    fi
    
    if [[ "$use_cache" == "true" ]]; then
        # Lire les statuts depuis le cache heartbox_analysis
        local ipfs_active=$(jq -r '.services.ipfs.active // false' "$heartbox_cache" 2>/dev/null)
        local astroport_active=$(jq -r '.services.astroport.active // false' "$heartbox_cache" 2>/dev/null)
        local upassport_active=$(jq -r '.services.upassport.active // false' "$heartbox_cache" 2>/dev/null)
        local nextcloud_active=$(jq -r '.services.nextcloud.active // false' "$heartbox_cache" 2>/dev/null)
        local strfry_active=$(jq -r '.services.strfry.active // false' "$heartbox_cache" 2>/dev/null)
        local g1billet_active=$(jq -r '.services.g1billet.active // false' "$heartbox_cache" 2>/dev/null)
        
        # Récupérer les détails IPFS depuis le cache
        ipfs_peers=$(jq -r '.services.ipfs.peers_connected // 0' "$heartbox_cache" 2>/dev/null)
        
        # Récupérer les détails UPassport et strfry depuis le cache
        upassport_proc=""
        strfry_proc=""

    else
        # Vérification en temps réel (fallback)
        local ipfs_active=false
        local astroport_active=false
        local upassport_active=false
        local nextcloud_active=false
        local strfry_active=false
        local g1billet_active=false

        # IPFS - vérifier le processus
        ipfs_active=false
        ipfs_peers=0
        if pgrep ipfs >/dev/null; then
            ipfs_active=true
            ipfs_peers=$(ipfs swarm peers 2>/dev/null | wc -l)
        fi

        # Astroport - vérifier le processus principal
        if pgrep -f "12345" >/dev/null; then
            astroport_active=true
        fi

        # UPassport API - simple port check
        if ss -tlnp 2>/dev/null | grep -q ":54321 "; then
            upassport_active=true
            upassport_proc=$(ss -tlnp 2>/dev/null | grep ":54321 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
        else
            upassport_active=false
            upassport_proc=""
        fi

        # NextCloud - vérifier les conteneurs Docker
        if command -v docker >/dev/null 2>&1 && docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | grep -q nextcloud; then
            nextcloud_active=true
        fi

        # strfry NOSTR relay - simple port check
        if ss -tlnp 2>/dev/null | grep -q ":7777 "; then
            strfry_active=true
            strfry_proc=$(ss -tlnp 2>/dev/null | grep ":7777 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
        else
            strfry_active=false
            strfry_proc=""
        fi

        # G1Billet - vérifier le processus
        if pgrep -f "G1BILLETS" >/dev/null; then
            g1billet_active=true
        fi
        
        # Mettre à jour le cache en arrière-plan si nécessaire
        if [[ ! -f "$heartbox_cache" ]] || [[ $cache_age -ge 300 ]]; then
            (${MY_PATH}/tools/heartbox_analysis.sh update >/dev/null 2>&1) &
        fi
    fi
    
    # Vérifier si NextCloud est disponible (fichiers de configuration présents)
    if [[ -f "$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/docker-compose.yml" ]]; then
        nextcloud_available=true
    fi
    
    # Stocker les statuts
    services_status=(
        "IPFS:$ipfs_active"
        "Astroport:$astroport_active"
        "UPassport:$upassport_active"
        "NextCloud:$nextcloud_active"
        "strfry:$strfry_active"
        "G1Billet:$g1billet_active"
    )
    
    # Retourner les statuts et la disponibilité de NextCloud
    echo "${services_status[@]}"
    echo "NEXTCLOUD_AVAILABLE:$nextcloud_available"
}

# Fonction pour gérer les paiements NOSTR
handle_nostr_payment() {
    print_section "PAIEMENT NOSTR"
    
    # Vérifier si des comptes NOSTR existent
    nostr_accounts=($(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev))
    
    if [[ ${#nostr_accounts[@]} -eq 0 ]]; then
        print_error "Aucun compte NOSTR trouvé."
        echo ""
        echo -e "${YELLOW}Pour créer un compte NOSTR:${NC}"
        echo "  1. Utilisez l'interface web: http://127.0.0.1:54321/g1"
        echo "  2. Ou utilisez l'option 'Créer une ZEN Card' dans le menu principal"
        echo ""
        read -p "Appuyez sur ENTRÉE pour continuer..."
        return
    fi
    
    print_info "Assistant de paiement NOSTR - Transfert de Ğ1 entre comptes"
    echo ""
    echo -e "${CYAN}Comptes NOSTR disponibles:${NC}"
    
    # Afficher les comptes disponibles
    for i in "${!nostr_accounts[@]}"; do
        account_name="${nostr_accounts[$i]}"
        g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
        balance=$(cat ~/.zen/tmp/coucou/${g1pub}.COINS 2>/dev/null)
        if [[ -z "$balance" || "$balance" == "null" ]]; then
            balance="0"
        fi
        
        echo -e "  ${BLUE}$((i+1)))${NC} ${WHITE}$account_name${NC}"
        echo -e "      ${WHITE}💰 Balance: ${GREEN}$balance Ğ1${NC}"
        echo -e "      ${WHITE}🔑 Public Key: ${CYAN}${g1pub:0:20}...${NC}"
        echo ""
    done
    
    echo -e "${YELLOW}Options:${NC}"
    echo "  1. 🔄 Lancer l'assistant de paiement interactif"
    echo "  2. 📊 Voir les soldes détaillés"
    echo "  3. ⬅️  Retour au menu principal"
    echo ""
    
    read -p "Votre choix: " payment_choice
    
    case $payment_choice in
        1)
            print_info "Lancement de l'assistant de paiement NOSTR..."
            echo ""
            # Lancer le script de paiement en mode interactif
            if "${MY_PATH}/tools/nostr_PAY.sh"; then
                print_success "Assistant de paiement terminé"
            else
                print_error "Erreur lors de l'exécution de l'assistant de paiement"
            fi
            read -p "Appuyez sur ENTRÉE pour continuer..."
            ;;
        2)
            print_section "SOLDES DÉTAILLÉS"
            echo -e "${WHITE}Comptes NOSTR et leurs soldes:${NC}"
            echo ""
            
            total_balance=0
            for account_name in "${nostr_accounts[@]}"; do
                g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
                balance=$(cat ~/.zen/tmp/coucou/${g1pub}.COINS 2>/dev/null)
                if [[ -z "$balance" || "$balance" == "null" ]]; then
                    balance="0"
                fi
                
                echo -e "${WHITE}📧 $account_name${NC}"
                echo -e "  ${WHITE}💰 Balance: ${GREEN}$balance Ğ1${NC}"
                echo -e "  ${WHITE}🔑 Public Key: ${CYAN}$g1pub${NC}"
                echo ""
                
                # Ajouter au total
                total_balance=$(echo "$total_balance + $balance" | bc -l 2>/dev/null || echo "$total_balance")
            done
            
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${WHITE}💰 Total de tous les comptes: ${GREEN}$total_balance Ğ1${NC}"
            echo ""
            read -p "Appuyez sur ENTRÉE pour continuer..."
            ;;
        3)
            return
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            ;;
    esac
}

# Fonction pour afficher les services avec statut réel
show_services_status() {
    echo -e "\033[0;36m  🔍 Vérification des services...\033[0m"
    local services_info=$(check_services_status)
    local nextcloud_available=false
    
    # Détection en temps réel des services réseau
    local ipfs_active=false
    local ipfs_peers=0
    if pgrep ipfs >/dev/null; then
        ipfs_active=true
        ipfs_peers=$(ipfs swarm peers 2>/dev/null | wc -l)
    fi
    local upassport_active=false
    local upassport_proc=""
    if ss -tlnp 2>/dev/null | grep -q ":54321 "; then
        upassport_active=true
        upassport_proc=$(ss -tlnp 2>/dev/null | grep ":54321 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
    fi
    local strfry_active=false
    local strfry_proc=""
    if ss -tlnp 2>/dev/null | grep -q ":7777 "; then
        strfry_active=true
        strfry_proc=$(ss -tlnp 2>/dev/null | grep ":7777 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
    fi
    
    # Extraire la disponibilité de NextCloud
    for info in $services_info; do
        if [[ "$info" == "NEXTCLOUD_AVAILABLE:"* ]]; then
            nextcloud_available="${info#NEXTCLOUD_AVAILABLE:}"
            break
        fi
    done
    
    echo -e "${GREEN}Services disponibles:${NC}"
    
    for service_info in $services_info; do
        if [[ "$service_info" == "NEXTCLOUD_AVAILABLE:"* ]]; then
            continue
        fi
        
        local service_name="${service_info%:*}"
        local service_active="${service_info#*:}"
        
        if [[ "$service_name" == "UPassport" ]]; then
            if [[ "$upassport_active" == true ]]; then
                print_status "UPassport" "ACTIVE" "(API :54321)${upassport_proc:+ - $upassport_proc}"
            else
                print_status "UPassport" "INACTIVE" "(API :54321)"
            fi
            continue
        fi
        if [[ "$service_name" == "strfry" ]]; then
            if [[ "$strfry_active" == true ]]; then
                print_status "strfry" "ACTIVE" "(NOSTR relay :7777)${strfry_proc:+ - $strfry_proc}"
            else
                print_status "strfry" "INACTIVE" "(NOSTR relay :7777)"
            fi
            continue
        fi
        
        if [[ "$service_active" == "true" ]]; then
            case "$service_name" in
                "IPFS")
                    if [[ "$ipfs_active" == true ]]; then
                        print_status "IPFS" "ACTIVE" "(Stockage distribué)"
                        if [[ "$ipfs_peers" == "0" ]]; then
                            echo -e "  ${YELLOW}⚠️  IPFS actif mais aucun peer connecté${NC}"
                        fi
                    else
                        print_status "IPFS" "INACTIVE" "(Stockage distribué)"
                    fi
                    ;;
                "Astroport")
                    print_status "Astroport" "ACTIVE" "(Interface web)"
                    ;;
                "UPassport")
                    print_status "UPassport" "ACTIVE" "(API :54321)${upassport_proc:+ - $upassport_proc}"
                    ;;
                "NextCloud")
                    print_status "NextCloud" "ACTIVE" "(Stockage personnel)"
                    ;;
                "strfry")
                    print_status "strfry" "ACTIVE" "(NOSTR relay :7777)${strfry_proc:+ - $strfry_proc}"
                    ;;
                "G1Billet")
                    print_status "G1Billet" "ACTIVE" "(Économie G1)"
                    ;;
            esac
        else
            case "$service_name" in
                "IPFS")
                    if [[ "$ipfs_active" == true ]]; then
                        print_status "IPFS" "INACTIVE" "(Stockage distribué)"
                    else
                        print_status "IPFS" "INACTIVE" "(Stockage distribué)"
                    fi
                    ;;
                "Astroport")
                    print_status "Astroport" "INACTIVE" "(Interface web)"
                    ;;
                "UPassport")
                    print_status "UPassport" "INACTIVE" "(API :54321)"
                    ;;
                "NextCloud")
                    if [[ "$nextcloud_available" == "true" ]]; then
                        print_status "NextCloud" "INACTIVE" "(Stockage personnel) - Installé mais non démarré"
                    else
                        print_status "NextCloud" "MISSING" "(Stockage personnel) - Non installé"
                    fi
                    ;;
                "strfry")
                    print_status "strfry" "INACTIVE" "(NOSTR relay :7777)"
                    ;;
                "G1Billet")
                    print_status "G1Billet" "INACTIVE" "(Économie G1)"
                    ;;
            esac
        fi
    done
    
    # Afficher les avertissements pour les services manquants
    local missing_services=()
    for service_info in $services_info; do
        if [[ "$service_info" == "NEXTCLOUD_AVAILABLE:"* ]]; then
            continue
        fi
        
        local service_name="${service_info%:*}"
        local service_active="${service_info#*:}"
        
        if [[ "$service_active" == "false" ]]; then
            case "$service_name" in
                "NextCloud")
                    if [[ "$nextcloud_available" == "false" ]]; then
                        missing_services+=("NextCloud")
                    fi
                    ;;
                "UPassport")
                    if [[ "$upassport_active" == false ]]; then
                        missing_services+=("UPassport")
                    fi
                    ;;
                "strfry")
                    if [[ "$strfry_active" == false ]]; then
                        missing_services+=("strfry")
                    fi
                    ;;
                "IPFS"|"Astroport"|"G1Billet")
                    missing_services+=("$service_name")
                    ;;
            esac
        fi
    done
    
    if [[ ${#missing_services[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Services manquants ou inactifs:${NC}"
        for service in "${missing_services[@]}"; do
            echo -e "  • $service"
        done
        
        # Proposition d'installation pour NextCloud
        if [[ " ${missing_services[@]} " =~ " NextCloud " ]] && [[ "$nextcloud_available" == "false" ]]; then
            echo ""
            echo -e "${CYAN}💡 Voulez-vous installer NextCloud ?${NC}"
            echo "  NextCloud fournit un stockage personnel sécurisé et partagé."
            read -p "  Installer NextCloud maintenant ? (oui/non): " install_nc
            
            if [[ "$install_nc" == "oui" || "$install_nc" == "o" || "$install_nc" == "y" || "$install_nc" == "yes" ]]; then
                install_nextcloud
            fi
        fi
    fi
    
    echo ""
}

# Fonction d'installation de NextCloud
install_nextcloud() {
    print_section "INSTALLATION NEXTCLOUD"
    
    local docker_compose_file="$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/docker-compose.yml"
    local install_script="$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/install.sh"
    
    print_info "Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker n'est pas installé"
        echo "Installez Docker avec: sudo apt install docker.io docker-compose"
        return
    fi
    
    # Vérifier si Docker est en cours d'exécution
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker n'est pas démarré"
        echo "Démarrez Docker avec: sudo systemctl start docker"
        return
    fi
    
    print_success "Docker est disponible"
    
    # Vérifier les fichiers de configuration
    if [[ ! -f "$docker_compose_file" ]]; then
        print_error "Fichier docker-compose.yml introuvable: $docker_compose_file"
        return
    fi
    
    if [[ ! -f "$install_script" ]]; then
        print_error "Script d'installation introuvable: $install_script"
        return
    fi
    
    print_success "Fichiers de configuration trouvés"
    
    # Créer le répertoire de données NextCloud
    print_info "Création du répertoire de données..."
    if sudo mkdir -p /nextcloud-data 2>/dev/null; then
        print_success "Répertoire /nextcloud-data créé"
    else
        print_warning "Impossible de créer /nextcloud-data, utilisation d'un répertoire local"
        mkdir -p ~/nextcloud-data
        # Modifier le docker-compose pour utiliser le répertoire local
        sed -i 's|/nextcloud-data|~/nextcloud-data|g' "$docker_compose_file"
    fi
    
    # Lancer l'installation
    print_info "Lancement de l'installation NextCloud..."
    echo ""
    
    if bash "$install_script"; then
        print_success "NextCloud installé avec succès!"
        echo ""
        echo -e "${CYAN}📋 Informations d'accès:${NC}"
        echo "  • Interface AIO (HTTPS): https://localhost:8002"
        echo "  • Interface Cloud (HTTP): http://localhost:8001"
        echo "  • Port alternatif: http://localhost:8008"
        echo ""
        echo -e "${YELLOW}⚠️  Note:${NC}"
        echo "  • La première connexion peut prendre quelques minutes"
        echo "  • Acceptez les certificats auto-signés dans votre navigateur"
        echo "  • Créez votre compte administrateur lors de la première connexion"
        echo ""
        
        # Proposer d'ouvrir l'interface
        read -p "Ouvrir l'interface NextCloud maintenant ? (oui/non): " open_nc
        if [[ "$open_nc" == "oui" || "$open_nc" == "o" || "$open_nc" == "y" || "$open_nc" == "yes" ]]; then
            xdg-open "https://localhost:8002" 2>/dev/null || xdg-open "http://localhost:8001" 2>/dev/null
        fi
    else
        print_error "Erreur lors de l'installation de NextCloud"
        echo "Consultez les logs Docker pour plus d'informations:"
        echo "  docker logs nextcloud-aio-mastercontainer"
    fi
    
    read -p "Appuyez sur ENTRÉE pour continuer..."
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

# Fonction d'onboarding pour nouveaux utilisateurs
handle_first_time_onboarding() {
    print_header "BIENVENUE SUR ASTROPORT.ONE - PREMIÈRE CONFIGURATION"
    
    echo -e "${GREEN}🎉 Félicitations! Votre station Astroport.ONE est prête.${NC}"
    echo ""
    echo -e "${CYAN}Nous allons vous guider pour créer votre première identité numérique:${NC}"
    echo "  1. Créer un compte MULTIPASS (interface CLI)"
    echo "  2. Créer une ZEN Card (interface CLI)"
    echo ""
    echo -e "${YELLOW}Cette configuration vous permettra de:${NC}"
    echo "  • Participer au réseau social NOSTR"
    echo "  • Stocker et partager des fichiers sur IPFS"
    echo "  • Gagner des récompenses G1"
    echo "  • Rejoindre la communauté UPlanet"
    echo ""
    
    read -p "Voulez-vous commencer la configuration ? (oui/non): " start_config
    
    if [[ "$start_config" != "oui" && "$start_config" != "o" && "$start_config" != "y" && "$start_config" != "yes" ]]; then
        print_info "Configuration reportée. Vous pourrez la faire plus tard."
        return
    fi
    
    # Utiliser le script captain.sh pour l'embarquement
    print_info "Lancement de l'assistant d'embarquement..."
    echo ""
    
    if "${MY_PATH}/captain.sh"; then
        print_success "Embarquement terminé avec succès!"
        
        # Mettre à jour les variables globales après l'embarquement
        CURRENT=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
        if [[ -n "$CURRENT" ]]; then
            PLAYER="$CURRENT"
            G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
            ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | head -n1 | cut -d ' ' -f 1 2>/dev/null)
        fi
    else
        print_error "Erreur lors de l'embarquement"
        echo "Vous pouvez réessayer plus tard avec la commande: ./captain.sh"
        fi
        
        read -p "Appuyez sur ENTRÉE pour continuer..."
}

# Fonction d'affichage du tableau de bord
show_dashboard() {
    print_header "ASTROPORT.ONE - STATION ZEN"

    echo -e "${WHITE}Node ID:${NC} $IPFSNODEID"
    echo -e "${WHITE}Capitaine:${NC} ${CURRENT:-'Non connecté'}"
    echo -e "${WHITE}UPlanet:${NC} $UPLANETG1PUB"
    echo ""

    if [[ -n "$PLAYER" ]]; then
        echo -e "${GREEN}🎫 Capitaine connecté: $PLAYER${NC}"
        if [[ -n "$G1PUB" ]]; then
            echo -e "${WHITE}G1PUB:${NC} $G1PUB"
        fi
        if [[ -n "$ASTRONAUTENS" ]]; then
            echo -e "${WHITE}IPNS:${NC} $myIPFS/ipns/$ASTRONAUTENS"
        fi
        echo ""
    fi

    echo -e "${CYAN}Astroport est un moteur Web3 exécutant UPlanet sur IPFS${NC}"
    echo "Il vous permet de:"
    echo "  • Gérer votre identité numérique (ZEN Card)"
    echo "  • Participer au réseau social NOSTR"
    echo "  • Stocker et partager des fichiers (uDRIVE)"
    echo "  • Gagner des récompenses (0.1 G1 par like)"
    echo ""

    # Vérifier le niveau de la station
    local level_info=$(check_station_level)
    local current_level=$(echo "$level_info" | grep "LEVEL:" | cut -d':' -f2)
    local ssh_mismatch=$(echo "$level_info" | grep "MISMATCH:" | cut -d':' -f2)

    echo -e "${YELLOW}Niveaux de capitaine:${NC}"
    if [[ "$current_level" == "Y" ]]; then
        echo -e "  X: Clé IPFS standard" UPlanet ORIGIN
        echo -e "  Y: Clé SSH jumelle" UPlanet Ẑen " ${GREEN}← Votre niveau${NC}"
        echo -e "  Z: Clé PGP/Yubikey" UPlanet PGP
    else
        echo -e "  X: Clé IPFS standard" UPlanet ORIGIN " ${YELLOW}← Votre niveau${NC}"
        echo -e "  Y: Clé SSH jumelle" UPlanet Ẑen " ${CYAN}← Niveau supérieur${NC}"
        echo -e "  Z: Clé PGP/Yubikey" UPlanet PGP
    fi
    echo ""

    show_services_status
    
    # Proposer le passage au niveau Y si nécessaire
    if [[ "$current_level" == "X" ]] && [[ "$ssh_mismatch" == "true" ]]; then
    echo ""
        echo -e "${CYAN}🚀 OPPORTUNITÉ D'ÉVOLUTION${NC}"
        echo -e "${YELLOW}Votre station peut passer au niveau Y pour rejoindre UPlanet Ẑen${NC}"
        echo -e "  • Intégration à la toile de confiance CopyLaRadio"
        echo -e "  • Hébergement pour vous et vos amis"
        echo -e "  • Identité SSH/IPFS unifiée et sécurisée"
    echo ""
        read -p "Voulez-vous en savoir plus sur le passage au niveau Y ? (oui/non): " info_choice
        
        if [[ "$info_choice" == "oui" || "$info_choice" == "o" || "$info_choice" == "y" || "$info_choice" == "yes" ]]; then
            propose_y_level_upgrade
        fi
    fi
    
    echo -e "\033[0;32m✅ Initialisation terminée - Prêt à utiliser\033[0m"
    echo ""
}

# Fonction pour lister et installer les applications Docker
list_docker_apps() {
    print_section "APPLICATIONS DOCKER INSTALLABLES"
    local docker_dir="$HOME/.zen/Astroport.ONE/_DOCKER"
    local workspace_dir="$HOME/.zen/workspace"
    local found_apps=()
    local i=1
    
    # Recherche des apps avec docker-compose.yml
    for app_path in "$docker_dir"/*; do
        if [[ -d "$app_path" && -f "$app_path/docker-compose.yml" ]]; then
            app_name=$(basename "$app_path")
            found_apps+=("$app_name")
        fi
    done
    
    if [[ ${#found_apps[@]} -eq 0 ]]; then
        print_warning "Aucune application Docker installable trouvée."
        read -p "Appuyez sur ENTRÉE pour revenir au menu..."
        return
    fi
    
    echo "Applications détectées :"
    for app in "${found_apps[@]}"; do
        local install_dir="$workspace_dir/.$app"
        if [[ -d "$install_dir" ]]; then
            echo -e "  $i. ${GREEN}$app${NC} - Installée dans $install_dir"
        else
            echo -e "  $i. ${YELLOW}$app${NC} - Non installée"
        fi
        ((i++))
    done
    echo ""
    echo "Sélectionnez le numéro de l'application à installer, ou 0 pour revenir :"
    read -p "Votre choix: " app_choice
    
    if [[ "$app_choice" == "0" || -z "$app_choice" ]]; then
        return
    fi
    
    # Vérifier que le choix est valide
    if ! [[ "$app_choice" =~ ^[0-9]+$ ]] || (( app_choice < 1 || app_choice > ${#found_apps[@]} )); then
        print_error "Choix invalide."
        read -p "Appuyez sur ENTRÉE pour continuer..."
        return
    fi
    
    local selected_app="${found_apps[$((app_choice-1))]}"
    local app_src="$docker_dir/$selected_app"
    local app_dst="$workspace_dir/.$selected_app"
    
    if [[ -d "$app_dst" ]]; then
        print_success "L'application $selected_app est déjà installée dans $app_dst."
        read -p "Appuyez sur ENTRÉE pour continuer..."
        return
    fi
    
    print_info "Installation de $selected_app dans $app_dst..."
    mkdir -p "$app_dst"
    cp -r "$app_src"/* "$app_dst/"
    
    # Lancer docker-compose up -d
    if command -v docker-compose >/dev/null 2>&1; then
        (cd "$app_dst" && docker-compose up -d)
        print_success "$selected_app installé et démarré avec docker-compose."
    else
        print_warning "docker-compose n'est pas installé. Installez-le pour démarrer l'application."
    fi
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

# Fonction de menu principal
show_main_menu() {
    print_section "MENU PRINCIPAL"
    
    if [[ -z "$PLAYER" ]]; then
        echo "1. 🎫 Créer/Connecter MULTIPASS / ZEN Card"
        echo "2. 📋 Lister les cartes existantes"
        echo "3. 🗑️  Supprimer une carte"
        echo "4. 🛠️ EXTRA"
        echo "0. ❌ Quitter"
    else
    echo "1. 🎫 Gérer MULTIPASS / ZEN Card"
    echo "2. 🌐 Connexion Swarm"
    echo "3. 📊 Statut Swarm"
     echo "4. 🛠️ EXTRA"
    echo "0. ❌ Quitter"
    fi
    echo ""
}

# Fonction de création/connexion de carte
handle_card_creation() {
    print_section "CRÉATION/CONNEXION DE CARTE"
    echo "1. 🆕 Créer une nouvelle MULTIPASS"
    echo "2. 🎫 Créer une nouvelle ZEN Card"
    echo "3. 📋 Lister les cartes existantes"
    echo "4. 🔗 Se connecter avec une carte existante"
    echo "0. ⬅️  Retour"
    echo ""
    
    read -p "Votre choix: " card_choice
    
    case $card_choice in
        1) create_multipass ;;
        2) create_zencard ;;
        3) list_existing_cards ;;
        4) connect_existing_card ;;
        0) return ;;
        *) print_error "Choix invalide" ;;
    esac
}

# Fonction de création MULTIPASS
create_multipass() {
    print_section "CRÉATION MULTIPASS"
    
        # Récupérer les informations de géolocalisation
    print_info "Récupération de votre localisation..."
    GEO_INFO=$(curl -s ipinfo.io/json 2>/dev/null)
    
    read -p "📧 Email: " EMAIL
    [[ -z "$EMAIL" ]] && { print_error "Email requis"; return; }
    
    # Géolocalisation automatique
    if [[ -n "$GEO_INFO" ]]; then
        AUTO_LAT=$(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f1 2>/dev/null)
        AUTO_LON=$(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f2 2>/dev/null)
        
        if [[ "$AUTO_LAT" != "null" && "$AUTO_LON" != "null" ]]; then
            print_info "Localisation détectée: $AUTO_LAT, $AUTO_LON"
            read -p "📍 Latitude [$AUTO_LAT]: " LAT
            read -p "📍 Longitude [$AUTO_LON]: " LON
            
            [[ -z "$LAT" ]] && LAT="$AUTO_LAT"
            [[ -z "$LON" ]] && LON="$AUTO_LON"
        else
            read -p "📍 Latitude: " LAT
            read -p "📍 Longitude: " LON
        fi
    else
        read -p "📍 Latitude: " LAT
        read -p "📍 Longitude: " LON
    fi
    
    # Valeurs par défaut
    [[ -z "$LAT" ]] && LAT="0.00"
    [[ -z "$LON" ]] && LON="0.00"
    
    print_info "Création de la MULTIPASS..."
    if "${MY_PATH}/tools/make_NOSTRCARD.sh" "$EMAIL" "$SYSLANG" "$LAT" "$LON"; then
        ## MAILJET SEND MULTIPASS
        YOUSER=$(${HOME}/.zen/Astroport.ONE/tools/clyuseryomail.sh ${EMAIL})
        ${HOME}/.zen/Astroport.ONE/tools/mailjet.sh "${EMAIL}" "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html" "UPlanet MULTIPASS - $YOUSER"
        print_success "MULTIPASS créée avec succès pour $EMAIL"
        
        # Vérifier si c'est le premier utilisateur (pas de ZEN Card existante)
        local zen_cards_count=$(ls ~/.zen/game/players 2>/dev/null | grep "@" | wc -l)
        local multipass_dir="$HOME/.zen/game/nostr/$EMAIL"
        
        # Si c'est le premier utilisateur, proposer automatiquement de créer la ZEN Card
        if [[ $zen_cards_count -eq 0 ]]; then
            echo ""
            print_info "C'est votre premier compte ! Pour devenir capitaine, vous devez créer une ZEN Card."
            echo ""
            read -p "Voulez-vous créer votre ZEN Card maintenant ? (oui/non): " create_zencard_choice
            
            if [[ "$create_zencard_choice" == "oui" || "$create_zencard_choice" == "o" || "$create_zencard_choice" == "y" || "$create_zencard_choice" == "yes" ]]; then
                # Récupérer les informations du MULTIPASS
                local npub=""
                local hex=""
                local multipass_lat="$LAT"
                local multipass_lon="$LON"
                
                if [[ -d "$multipass_dir" ]]; then
                    # Récupérer NPUB
                    if [[ -f "$multipass_dir/NPUB" ]]; then
                        npub=$(cat "$multipass_dir/NPUB")
                    fi
                    
                    # Récupérer HEX
                    if [[ -f "$multipass_dir/HEX" ]]; then
                        hex=$(cat "$multipass_dir/HEX")
                    fi
                    
                    # Récupérer GPS si disponible
                    if [[ -f "$multipass_dir/GPS" ]]; then
                        # Source GPS file in a subshell to avoid variable conflicts
                        local gps_lat=$(grep "^LAT=" "$multipass_dir/GPS" | cut -d'=' -f2 | tr -d ';')
                        local gps_lon=$(grep "^LON=" "$multipass_dir/GPS" | cut -d'=' -f2 | tr -d ';')
                        if [[ -n "$gps_lat" ]]; then
                            multipass_lat="$gps_lat"
                        fi
                        if [[ -n "$gps_lon" ]]; then
                            multipass_lon="$gps_lon"
                        fi
                    fi
                fi
                
                # Génération automatique des secrets
                print_info "Génération automatique des secrets pour la ZEN Card..."
                local ppass=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)
                local npass=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) )) | xargs)
                
                print_info "Secret 1 généré: $ppass"
                print_info "Secret 2 généré: $npass"
                
                # Créer la ZEN Card avec les informations du MULTIPASS
                print_info "Création de la ZEN Card avec les informations du MULTIPASS..."
                if "${MY_PATH}/RUNTIME/VISA.new.sh" "$ppass" "$npass" "$EMAIL" "UPlanet" "$SYSLANG" "$multipass_lat" "$multipass_lon" "$npub" "$hex"; then
                    local pseudo=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null)
                    rm -f ~/.zen/tmp/PSEUDO
                    
                    print_success "ZEN Card créée avec succès pour $pseudo !"
                    
                    # Définir comme carte courante (capitaine)
                    local player="$EMAIL"
                    if [[ -d ~/.zen/game/players/$player ]]; then
                        rm -f ~/.zen/game/players/.current
                        ln -s ~/.zen/game/players/${player} ~/.zen/game/players/.current
                        
                        # Mettre à jour les variables globales
                        PLAYER="$player"
                        G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
                        ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | head -n1 | cut -d ' ' -f 1 2>/dev/null)
                        
                        print_success "Vous êtes maintenant le capitaine de cette station !"
                        echo ""
                        echo -e "${GREEN}🎉 Configuration terminée avec succès !${NC}"
                        echo "  • Compte MULTIPASS: $EMAIL"
                        echo "  • ZEN Card: $player"
                        if [[ -n "$G1PUB" ]]; then
                            echo "  • G1PUB: $G1PUB"
                        fi
                        if [[ -n "$ASTRONAUTENS" ]]; then
                            echo "  • IPNS: $myIPFS/ipns/$ASTRONAUTENS"
                        fi
                        echo ""
                    fi
                else
                    print_error "Erreur lors de la création de la ZEN Card"
                    print_info "Vous pourrez créer votre ZEN Card plus tard depuis le menu principal"
                fi
            else
                print_info "Création de la ZEN Card reportée. Vous pourrez la créer plus tard depuis le menu principal."
            fi
        else
            echo ""
            print_info "Vous pouvez créer une ZEN Card à partir de ce MULTIPASS depuis le menu principal."
        fi
        
        read -p "Appuyez sur ENTRÉE pour continuer..."
    else
        print_error "Erreur lors de la création de la MULTIPASS"
    fi
}

# Fonction de création ZEN Card
create_zencard() {
    print_section "CRÉATION ZEN CARD"
    
    read -p "📧 Email: " EMAIL
    [[ -z "$EMAIL" ]] && { print_error "Email requis"; return; }
    
    # Génération automatique des secrets
    print_info "Génération automatique des secrets..."
    PPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
    NPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
    
    print_info "Secret 1 généré: $PPASS"
    print_info "Secret 2 généré: $NPASS"
    
    read -p "🔐 Secret 1 [$PPASS]: " CUSTOM_PPASS
    read -p "🔐 Secret 2 [$NPASS]: " CUSTOM_NPASS
    
    [[ -n "$CUSTOM_PPASS" ]] && PPASS="$CUSTOM_PPASS"
    [[ -n "$CUSTOM_NPASS" ]] && NPASS="$CUSTOM_NPASS"
    
    read -p "📍 Latitude [0.00]: " LAT
    read -p "📍 Longitude [0.00]: " LON
    read -p "🔑 NPUB (NOSTR Card, optionnel): " NPUB
    
    [[ -z "$LAT" ]] && LAT="0.00"
    [[ -z "$LON" ]] && LON="0.00"
    
    if [[ -n "$NPUB" ]]; then
        HEX=$(${MY_PATH}/tools/nostr2hex.py "$NPUB" 2>/dev/null)
        [[ -n "$HEX" ]] && print_info "Clé NOSTR convertie: $HEX"
    fi
    
    print_info "Création de la ZEN Card..."
    if "${MY_PATH}/RUNTIME/VISA.new.sh" "$PPASS" "$NPASS" "$EMAIL" "UPlanet" "$SYSLANG" "$LAT" "$LON" "$NPUB" "$HEX"; then
        PSEUDO=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null)
        rm -f ~/.zen/tmp/PSEUDO
        print_success "ZEN Card créée avec succès pour $PSEUDO"
        read -p "Appuyez sur ENTRÉE pour continuer..."
    else
        print_error "Erreur lors de la création de la ZEN Card"
    fi
}

# Fonction de liste des cartes existantes
list_existing_cards() {
    print_section "CARTES EXISTANTES"
    
    # Cartes MULTIPASS
    echo -e "${CYAN}MULTIPASS:${NC}"
    NOSTR_CARDS=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" || echo "Aucune")
    if [[ "$NOSTR_CARDS" != "Aucune" ]]; then
        echo "$NOSTR_CARDS" | nl                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
    else
        echo "  Aucune carte MULTIPASS trouvée"
    fi
    
    echo ""
    
    # Cartes ZEN
    echo -e "${CYAN}ZEN CARDS:${NC}"
    ZEN_CARDS=$(ls ~/.zen/game/players 2>/dev/null | grep "@" || echo "Aucune")
    if [[ "$ZEN_CARDS" != "Aucune" ]]; then
        echo "$ZEN_CARDS" | nl
    else
        echo "  Aucune carte ZEN trouvée"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

# Fonction de connexion avec une carte existante
connect_existing_card() {
    print_section "CONNEXION AVEC UNE CARTE EXISTANTE"
    
    # Lister les cartes disponibles
    ZEN_CARDS=$(ls ~/.zen/game/players 2>/dev/null | grep "@")
    if [[ -z "$ZEN_CARDS" ]]; then
        print_error "Aucune carte ZEN trouvée"
        return
    fi
    
    echo "Cartes disponibles:"
    echo "$ZEN_CARDS" | nl
    echo ""
    
    read -p "Numéro de la carte: " CARD_NUM
    if [[ -z "$CARD_NUM" ]]; then
        print_error "Numéro requis"
        return
    fi
    
    SELECTED_CARD=$(echo "$ZEN_CARDS" | sed -n "${CARD_NUM}p")
    if [[ -z "$SELECTED_CARD" ]]; then
        print_error "Carte invalide"
        return
    fi
    
    print_info "Connexion à $SELECTED_CARD..."
    
    # Vérifier le mot de passe
    PASS_FILE="$HOME/.zen/game/players/$SELECTED_CARD/.pass"
    if [[ ! -f "$PASS_FILE" ]]; then
        print_error "Fichier de mot de passe introuvable"
        return
    fi
    
    STORED_PASS=$(cat "$PASS_FILE")
    read -s -p "🔐 Mot de passe: " INPUT_PASS
    echo ""
    
    if [[ "$INPUT_PASS" != "$STORED_PASS" ]]; then
        print_error "Mot de passe incorrect"
        return
    fi
    
    # Connexion réussie
    PLAYER="$SELECTED_CARD"
    G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | head -n1 | cut -d ' ' -f 1)
    
    # Mettre à jour .current
    rm -f ~/.zen/game/players/.current
    ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current
    
    print_success "Connexion réussie! Bienvenue $PLAYER"
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

# Fonction de gestion ZEN Card
handle_zen_card_management() {
    print_section "GESTION IDENTITÉS (MULTIPASS & ZEN Card)"
    echo "1. 📋 Lister MULTIPASS & ZEN Card"
    echo "2. 🆕 Créer un nouveau MULTIPASS"
    echo "3. 🆕 Créer une nouvelle ZEN Card (à partir d'un MULTIPASS)"
    echo "4. 🗑️  Supprimer un MULTIPASS ou une ZEN Card"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Votre choix: " zen_choice
    case $zen_choice in
        1) 
            list_multipass_zen_cards
            handle_zen_card_management
            ;;
        2)
            print_section "CRÉATION D'UN NOUVEAU MULTIPASS"
            echo "0. ⬅️  Annuler"
            echo ""
            read -p "📧 Email: " EMAIL
            if [[ "$EMAIL" == "0" ]]; then
                handle_zen_card_management
                return
            fi
            [[ -z "$EMAIL" ]] && { print_error "Email requis"; return; }
            print_info "Récupération de votre localisation..."
            GEO_INFO=$(curl -s ipinfo.io/json 2>/dev/null)
            if [[ -n "$GEO_INFO" ]]; then
                AUTO_LAT=$(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f1 2>/dev/null)
                AUTO_LON=$(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f2 2>/dev/null)
                print_info "Localisation détectée: $AUTO_LAT, $AUTO_LON"
                read -p "📍 Latitude [$AUTO_LAT]: " LAT
                read -p "📍 Longitude [$AUTO_LON]: " LON
                [[ -z "$LAT" ]] && LAT="$AUTO_LAT"
                [[ -z "$LON" ]] && LON="$AUTO_LON"
            else
                read -p "📍 Latitude: " LAT
                read -p "📍 Longitude: " LON
            fi
            [[ -z "$LAT" ]] && LAT="0.00"
            [[ -z "$LON" ]] && LON="0.00"
            print_info "Création de la MULTIPASS..."
            if "${MY_PATH}/tools/make_NOSTRCARD.sh" "$EMAIL" "$SYSLANG" "$LAT" "$LON"; then
                print_success "MULTIPASS créée avec succès pour $EMAIL"
            else
                print_error "Erreur lors de la création de la MULTIPASS"
            fi
            read -p "Appuyez sur ENTRÉE pour continuer..."
            handle_zen_card_management
            ;;
        3)
            print_section "CRÉATION D'UNE NOUVELLE ZEN CARD (à partir d'un MULTIPASS)"
            # Lister les MULTIPASS existants qui n'ont PAS de ZEN Card associée
            mps=()
            for mp in $(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | sort); do
                # Vérifier si ce MULTIPASS a déjà une ZEN Card associée
                has_zencard=false
                for zc in $(ls ~/.zen/game/players 2>/dev/null | grep "@" | sort); do
                    if [[ "$mp" == "$zc" ]]; then
                        has_zencard=true
                        break
                    fi
                done
                # Ajouter seulement si pas de ZEN Card associée
                if [[ "$has_zencard" == false ]]; then
                    mps+=("$mp")
                fi
            done
            if [[ ${#mps[@]} -eq 0 ]]; then
                print_error "Aucun MULTIPASS sans ZEN Card trouvé. Tous les MULTIPASS ont déjà une ZEN Card associée."
                read -p "Appuyez sur ENTRÉE pour continuer..."
                return
            fi
            echo "MULTIPASS disponibles (sans ZEN Card) :"
            for i in "${!mps[@]}"; do
                local email="${mps[$i]}"
                if [[ -f "${HOME}/.zen/game/nostr/${email}/.secret.nostr" ]]; then
                    echo -e "$((i+1)). ${GREEN}${email}${NC} ${CYAN}[LOCAL]${NC}"
                else
                    echo -e "$((i+1)). ${YELLOW}${email}${NC} ${RED}[REMOTE]${NC}"
                fi
            done
            echo "0. ⬅️  Annuler"
            echo ""
            read -p "Sélectionnez le numéro du MULTIPASS: " mp_choice
            if [[ "$mp_choice" == "0" ]]; then
                handle_zen_card_management
                return
            fi
            if ! [[ "$mp_choice" =~ ^[0-9]+$ ]] || (( mp_choice < 1 || mp_choice > ${#mps[@]} )); then
                print_error "Choix invalide."
                read -p "Appuyez sur ENTRÉE pour continuer..."
                return
            fi
            EMAIL="${mps[$((mp_choice-1))]}"
            # Récupérer les infos associées
            mp_dir="$HOME/.zen/game/nostr/$EMAIL"
            LAT=""; LON=""
            
            # Lire les coordonnées depuis le fichier GPS (format: LAT=43.63; LON=1.36;)
            if [[ -f "$mp_dir/GPS" ]]; then
                source "$mp_dir/GPS"
            fi
            
            # Fallback vers les fichiers LAT/LON séparés si GPS n'existe pas
            [[ -z "$LAT" ]] && [[ -f "$mp_dir/LAT" ]] && LAT=$(cat "$mp_dir/LAT")
            [[ -z "$LON" ]] && [[ -f "$mp_dir/LON" ]] && LON=$(cat "$mp_dir/LON")
            
            # Valeurs par défaut si aucune coordonnée trouvée
            [[ -z "$LAT" ]] && LAT="0.00"
            [[ -z "$LON" ]] && LON="0.00"
            
            # Récupérer NPUB et HEX depuis le MULTIPASS
            NPUB=""
            HEX=""
            if [[ -f "$mp_dir/NPUB" ]]; then
                NPUB=$(cat "$mp_dir/NPUB")
            fi
            if [[ -f "$mp_dir/HEX" ]]; then
                HEX=$(cat "$mp_dir/HEX")
            fi
            
            print_info "Création de la ZEN Card pour $EMAIL ($LAT, $LON)"
            print_info "NPUB: ${NPUB:0:20}..."
            print_info "HEX: ${HEX:0:20}..."
            
            # Génération automatique des secrets
            PPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
            NPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
            print_info "Secret 1 généré: $PPASS"
            print_info "Secret 2 généré: $NPASS"
            read -p "🔐 Secret 1 [$PPASS]: " CUSTOM_PPASS
            read -p "🔐 Secret 2 [$NPASS]: " CUSTOM_NPASS
            [[ -n "$CUSTOM_PPASS" ]] && PPASS="$CUSTOM_PPASS"
            [[ -n "$CUSTOM_NPASS" ]] && NPASS="$CUSTOM_NPASS"
            print_info "Création de la ZEN Card..."
            if "${MY_PATH}/RUNTIME/VISA.new.sh" "$PPASS" "$NPASS" "$EMAIL" "UPlanet" "$SYSLANG" "$LAT" "$LON" "$NPUB" "$HEX"; then
                PSEUDO=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null)
                rm -f ~/.zen/tmp/PSEUDO
                print_success "ZEN Card créée avec succès pour $PSEUDO"
            else
                print_error "Erreur lors de la création de la ZEN Card"
            fi
            read -p "Appuyez sur ENTRÉE pour continuer..."
            handle_zen_card_management
            ;;
        4)
            print_section "SUPPRESSION D'UN MULTIPASS OU D'UNE ZEN CARD"
            echo "1. Supprimer un MULTIPASS"
            echo "2. Supprimer une ZEN Card"
            echo "0. ⬅️  Retour"
            read -p "Votre choix: " del_choice
            case $del_choice in
                1)
                    mps=( $(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | sort) )
                    if [[ ${#mps[@]} -eq 0 ]]; then
                        print_error "Aucun MULTIPASS à supprimer."
                        read -p "Appuyez sur ENTRÉE pour continuer..."
                        return
                    fi
                    echo "MULTIPASS disponibles :"
                    for i in "${!mps[@]}"; do
                        echo "$((i+1)). ${mps[$i]}"
                    done
                    echo "0. ⬅️  Annuler"
                    echo ""
                    read -p "Sélectionnez le numéro du MULTIPASS à supprimer: " mp_del
                    if [[ "$mp_del" == "0" ]]; then
                        handle_zen_card_management
                        return
                    fi
                    if ! [[ "$mp_del" =~ ^[0-9]+$ ]] || (( mp_del < 1 || mp_del > ${#mps[@]} )); then
                        print_error "Choix invalide."
                        read -p "Appuyez sur ENTRÉE pour continuer..."
                        return
                    fi
                    EMAIL="${mps[$((mp_del-1))]}"
                    read -p "Êtes-vous sûr de vouloir supprimer le MULTIPASS $EMAIL ? (oui/non): " confirm
                    if [[ "$confirm" =~ ^(oui|o|y|yes)$ ]]; then
                        print_info "Suppression de $EMAIL..."
                        if "${MY_PATH}/tools/nostr_DESTROY_TW.sh" "$EMAIL"; then
                            print_success "MULTIPASS $EMAIL supprimé."
                        else
                            print_error "Erreur lors de la suppression du MULTIPASS."
                        fi
                    else
                        print_info "Suppression annulée."
                    fi
                    read -p "Appuyez sur ENTRÉE pour continuer..."
                    handle_zen_card_management
                    ;;
                2)
                    zcs=( $(ls ~/.zen/game/players 2>/dev/null | grep "@" | sort) )
                    if [[ ${#zcs[@]} -eq 0 ]]; then
                        print_error "Aucune ZEN Card à supprimer."
                        read -p "Appuyez sur ENTRÉE pour continuer..."
                        return
                    fi
                    echo "ZEN Cards disponibles :"
                    for i in "${!zcs[@]}"; do
                        echo "$((i+1)). ${zcs[$i]}"
                    done
                    echo "0. ⬅️  Annuler"
                    echo ""
                    read -p "Sélectionnez le numéro de la ZEN Card à supprimer: " zc_del
                    if [[ "$zc_del" == "0" ]]; then
                        handle_zen_card_management
                        return
                    fi
                    if ! [[ "$zc_del" =~ ^[0-9]+$ ]] || (( zc_del < 1 || zc_del > ${#zcs[@]} )); then
                        print_error "Choix invalide."
                        read -p "Appuyez sur ENTRÉE pour continuer..."
                        return
                    fi
                    PSEUDO="${zcs[$((zc_del-1))]}"
                    read -p "Êtes-vous sûr de vouloir supprimer la ZEN Card $PSEUDO ? (oui/non): " confirm
                    if [[ "$confirm" =~ ^(oui|o|y|yes)$ ]]; then
                        print_info "Suppression de $PSEUDO..."
                        if "${MY_PATH}/RUNTIME/PLAYER.unplug.sh" "$HOME/.zen/game/players/$PSEUDO/ipfs/moa/index.html" "$PSEUDO" "ALL"; then
                            print_success "ZEN Card $PSEUDO supprimée."
                        else
                            print_error "Erreur lors de la suppression de la ZEN Card."
                        fi
                    else
                        print_info "Suppression annulée."
                    fi
                    read -p "Appuyez sur ENTRÉE pour continuer..."
                    handle_zen_card_management
                    ;;
                0)
                    return
                    ;;
                *)
                    print_error "Choix invalide."
                    sleep 1
                    ;;
            esac
            ;;
        0)
            return
            ;;
        *)
            print_error "Choix invalide."
            sleep 1
            ;;
    esac
}

# Fonction de gestion des applications
handle_applications() {
    print_section "APPLICATIONS"
    echo "1. 🌐 Interface web (http://astroport.localhost:1234)"
    echo "2. 📊 IPFS Web UI (http://ipfs.localhost:8080)"
    echo "3. 🎮 Interface de jeu"
    echo "4. 📱 Applications mobiles"
    echo "0. ⬅️  Retour"
    echo ""
    
    read -p "Votre choix: " app_choice
    
    case $app_choice in
        1) 
            print_info "Ouverture de l'interface web..."
            xdg-open "http://astroport.localhost:1234" 2>/dev/null || print_error "Impossible d'ouvrir le navigateur"
            ;;
        2) 
            print_info "Ouverture de l'interface IPFS..."
            xdg-open "http://ipfs.localhost:8080" 2>/dev/null || print_error "Impossible d'ouvrir le navigateur"
            ;;
        3) 
            print_info "Interface de jeu à venir..."
            ;;
        4) 
            print_info "Applications mobiles à venir..."
            ;;
        0) return ;;
        *) print_error "Choix invalide" ;;
    esac
}

# Fonction de configuration
handle_configuration() {
    print_section "CONFIGURATION"
    echo "1. ⚙️  Paramètres IPFS"
    echo "2. 🌐 Configuration réseau"
    echo "3. 💰 Paramètres économiques"
    echo "4. 🔧 Maintenance système"
    echo "5. ☁️  Installer NextCloud"
    echo "6. 🚀 Passer au niveau Y (UPlanet Ẑen)"
    echo "7. 🐛 Debug détection"
    echo "0. ⬅️  Retour"
    echo ""
    
    read -p "Votre choix: " config_choice
    
    case $config_choice in
        1) 
            print_info "Configuration IPFS..."
            # TODO: Implémenter la configuration IPFS
            ;;
        2) 
            print_info "Configuration réseau..."
            # TODO: Implémenter la configuration réseau
            ;;
        3) 
            print_info "Paramètres économiques..."
            # TODO: Implémenter les paramètres économiques
            ;;
        4) 
            print_info "Maintenance système..."
            # TODO: Implémenter la maintenance
            ;;
        5)
            install_nextcloud
            ;;
        6)
            propose_y_level_upgrade
            ;;
        7)
            debug_detection
            ;;
        0) return ;;
        *) print_error "Choix invalide" ;;
    esac
}

# Fonction de déconnexion
handle_disconnect() {
    print_warning "Déconnexion de votre TW"
    echo "Cette action va déconnecter votre TimeWarp et arrêter les services."
    echo ""
    read -p "Êtes-vous sûr? (oui/non): " confirm
    
    if [[ "$confirm" == "oui" || "$confirm" == "o" || "$confirm" == "y" || "$confirm" == "yes" ]]; then
        print_info "Déconnexion en cours..."
        if "${MY_PATH}/RUNTIME/PLAYER.unplug.sh" "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}" "ALL"; then
            print_success "Déconnexion réussie"
            PLAYER=""
            G1PUB=""
            ASTRONAUTENS=""
        else
            print_error "Erreur lors de la déconnexion"
        fi
    else
        print_info "Déconnexion annulée"
    fi
    
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

# Fonction pour lister les MULTIPASS & ZEN Card avec pagination et recherche
list_multipass_zen_cards() {
    print_section "MULTIPASS & ZEN Card"
    
    # Récupérer tous les MULTIPASS
    local multipass_list=($(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | sort))
    local zen_cards_list=($(ls ~/.zen/game/players 2>/dev/null | grep "@" | sort))
    
    if [[ ${#multipass_list[@]} -eq 0 ]]; then
        print_error "Aucun MULTIPASS trouvé."
        read -p "Appuyez sur ENTRÉE pour continuer..."
        return
    fi
    
    # Configuration de la pagination
    local items_per_page=15
    local total_items=${#multipass_list[@]}
    local total_pages=$(( (total_items + items_per_page - 1) / items_per_page ))
    local current_page=1
    local filtered_list=("${multipass_list[@]}")
    
    # Fonction pour afficher la page courante
    display_cards_page() {
        local start_index=$(( (current_page - 1) * items_per_page ))
        local end_index=$(( start_index + items_per_page - 1 ))
        local display_count=${#filtered_list[@]}
        
        if [[ $end_index -ge $display_count ]]; then
            end_index=$(( display_count - 1 ))
        fi
        
        echo -e "${WHITE}MULTIPASS & ZEN Card (page $current_page/$total_pages) - ${display_count} comptes${NC}"
        echo ""
        
        # En-tête du tableau
        printf "%-4s %-35s %-35s %-15s\n" "N°" "MULTIPASS (Email)" "ZEN Card (Pseudo)" "Statut"
        echo "────────────────────────────────────────────────────────────────────────────────────────────────────────"
        
        for ((i=start_index; i<=end_index && i<display_count; i++)); do
            local multipass="${filtered_list[$i]}"
            local zen_card=""
            local status=""
            
            # Chercher une ZEN Card associée
            for zc in "${zen_cards_list[@]}"; do
                if [[ "$multipass" == "$zc" ]]; then
                    zen_card="$zc"
                    break
                fi
            done
            
            # Déterminer le statut
            if [[ -n "$zen_card" ]]; then
                status="${GREEN}Complète${NC}"
            else
                status="${YELLOW}MULTIPASS seul${NC}"
                zen_card="Aucune ZEN Card"
            fi
            
            local display_index=$((i + 1))
            
            # Tronquer les noms longs
            local short_multipass="${multipass:0:34}"
            if [[ ${#multipass} -gt 34 ]]; then
                short_multipass="${multipass:0:31}..."
            fi
            
            local short_zen_card="${zen_card:0:34}"
            if [[ ${#zen_card} -gt 34 ]]; then
                short_zen_card="${zen_card:0:31}..."
            fi
            
            printf "${BLUE}%-4s${NC} ${WHITE}%-35s${NC} ${CYAN}%-35s${NC} %-15s\n" \
                   "$display_index" "$short_multipass" "$short_zen_card" "$status"
        done
        echo ""
    }
    
    # Fonction pour afficher les commandes de navigation
    show_navigation_commands() {
        echo -e "${YELLOW}Navigation:${NC}"
        if [[ $total_pages -gt 1 ]]; then
            echo -e "  ${WHITE}n${NC} - Page suivante  ${WHITE}p${NC} - Page précédente"
        fi
        echo -e "  ${WHITE}s${NC} - Rechercher  ${WHITE}r${NC} - Réinitialiser  ${WHITE}q${NC} - Quitter"
        echo ""
    }
    
    # Fonction de recherche
    search_cards() {
        echo -e "${WHITE}Rechercher par:${NC}"
        echo "  1. Email MULTIPASS"
        echo "  2. Pseudo ZEN Card"
        echo "  3. Annuler"
        echo ""
        read -p "> " search_type
        
        case $search_type in
            1|2)
                echo -e "${WHITE}Terme de recherche:${NC}"
                read -p "> " search_term
                
                if [[ -n "$search_term" ]]; then
                    # Réinitialiser la liste filtrée
                    filtered_list=()
                    
                    for multipass in "${multipass_list[@]}"; do
                        local zen_card=""
                        for zc in "${zen_cards_list[@]}"; do
                            if [[ "$multipass" == "$zc" ]]; then
                                zen_card="$zc"
                                break
                            fi
                        done
                        
                        local match=false
                        case $search_type in
                            1) # Email MULTIPASS
                                if [[ "$multipass" == *"$search_term"* ]]; then
                                    match=true
                                fi
                                ;;
                            2) # Pseudo ZEN Card
                                if [[ -n "$zen_card" ]] && [[ "$zen_card" == *"$search_term"* ]]; then
                                    match=true
                                fi
                                ;;
                        esac
                        
                        if [[ "$match" == "true" ]]; then
                            filtered_list+=("$multipass")
                        fi
                    done
                    
                    # Réinitialiser la pagination
                    current_page=1
                    total_pages=$(( (${#filtered_list[@]} + items_per_page - 1) / items_per_page ))
                    if [[ $total_pages -eq 0 ]]; then
                        total_pages=1
                    fi
                    
                    print_success "Recherche terminée: ${#filtered_list[@]} comptes trouvés"
                fi
                ;;
            3)
                return
                ;;
            *)
                print_error "Choix invalide"
                ;;
        esac
    }
    
    # Boucle principale de sélection
    while true; do
        clear
        print_section "MULTIPASS & ZEN Card"
        
        if [[ ${#filtered_list[@]} -eq 0 ]]; then
            print_error "Aucun compte trouvé avec les critères de recherche."
            echo ""
            echo -e "${YELLOW}Options:${NC}"
            echo "  r - Réinitialiser la recherche"
            echo "  q - Quitter"
            echo ""
            read -p "> " choice
            
            case $choice in
                "r"|"R")
                    # Réinitialiser les filtres
                    filtered_list=("${multipass_list[@]}")
                    current_page=1
                    total_pages=$(( (${#filtered_list[@]} + items_per_page - 1) / items_per_page ))
                    ;;
                "q"|"Q")
                    return
                    ;;
                *)
                    print_error "Choix invalide"
                    sleep 1
                    ;;
            esac
            continue
        fi
        
        # Afficher les comptes de la page courante
        display_cards_page
        
        # Afficher les commandes de navigation
        show_navigation_commands
        
        # Afficher les options de sélection
        echo -e "${WHITE}Entrez le numéro du compte ou une commande:${NC}"
        read -p "> " selection
        
        case $selection in
            "n"|"N")
                if [[ $current_page -lt $total_pages ]]; then
                    current_page=$((current_page + 1))
                else
                    print_warning "Vous êtes déjà à la dernière page."
                    sleep 1
                fi
                ;;
            "p"|"P")
                if [[ $current_page -gt 1 ]]; then
                    current_page=$((current_page - 1))
                else
                    print_warning "Vous êtes déjà à la première page."
                    sleep 1
                fi
                ;;
            "s"|"S")
                search_cards
                ;;
            "r"|"R")
                # Réinitialiser les filtres
                filtered_list=("${multipass_list[@]}")
                current_page=1
                total_pages=$(( (${#filtered_list[@]} + items_per_page - 1) / items_per_page ))
                print_success "Recherche réinitialisée"
                sleep 1
                ;;
            "q"|"Q")
                return
                ;;
            *)
                # Vérifier si c'est un numéro de compte valide
                if [[ "$selection" =~ ^[0-9]+$ ]]; then
                    local selected_index=$((selection - 1))
                    if [[ $selected_index -ge 0 && $selected_index -lt ${#filtered_list[@]} ]]; then
                        local selected_multipass="${filtered_list[$selected_index]}"
                        
                        # Afficher les détails du compte sélectionné
                        show_account_details "$selected_multipass"
                        return
                    else
                        print_error "Numéro de compte invalide. Veuillez entrer un nombre entre 1 et ${#filtered_list[@]}."
                        sleep 2
                    fi
                else
                    print_error "Entrée invalide. Veuillez entrer un numéro de compte ou une commande."
                    sleep 1
                fi
                ;;
        esac
    done
}

# Fonction pour afficher les détails d'un compte
show_account_details() {
    local multipass="$1"
    local zen_card=""
    
    # Chercher une ZEN Card associée
    for zc in $(ls ~/.zen/game/players 2>/dev/null | grep "@" | sort); do
        if [[ "$multipass" == "$zc" ]]; then
            zen_card="$zc"
            break
        fi
    done
    
    print_section "DÉTAILS DU COMPTE"
    
    echo -e "${WHITE}MULTIPASS:${NC}"
    echo -e "  📧 Email: ${CYAN}$multipass${NC}"
    
    # Afficher les fichiers MULTIPASS
    local multipass_dir="$HOME/.zen/game/nostr/$multipass"
    if [[ -d "$multipass_dir" ]]; then
        echo -e "  📁 Répertoire: ${CYAN}$multipass_dir${NC}"
        
        # Lister les fichiers importants
        local important_files=("G1PUBNOSTR" "NPUB" "HEX" "GPS" ".nostr.zine.html")
        echo -e "  📄 Fichiers:"
        for file in "${important_files[@]}"; do
            if [[ -f "$multipass_dir/$file" ]]; then
                local content=""
                case $file in
                    "G1PUBNOSTR")
                        content=$(cat "$multipass_dir/$file" | head -c 20)
                        echo -e "    ✅ $file: ${GREEN}${content}...${NC}"
                        ;;
                    "NPUB")
                        content=$(cat "$multipass_dir/$file" | head -c 20)
                        echo -e "    ✅ $file: ${GREEN}${content}...${NC}"
                        ;;
                    "HEX")
                        content=$(cat "$multipass_dir/$file" | head -c 20)
                        echo -e "    ✅ $file: ${GREEN}${content}...${NC}"
                        ;;
                    "GPS")
                        content=$(cat "$multipass_dir/$file")
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
    fi
    
    echo ""
    
    if [[ -n "$zen_card" ]]; then
        echo -e "${WHITE}ZEN Card:${NC}"
        echo -e "  🎫 Pseudo: ${GREEN}$zen_card${NC}"
        
        # Afficher les fichiers ZEN Card
        local zen_dir="$HOME/.zen/game/players/$zen_card"
        if [[ -d "$zen_dir" ]]; then
            echo -e "  📁 Répertoire: ${CYAN}$zen_dir${NC}"
            
            # Vérifier les fichiers importants
            local zen_files=("secret.dunikey" ".pass" "ipfs/moa/index.html")
            echo -e "  📄 Fichiers:"
            for file in "${zen_files[@]}"; do
                if [[ -f "$zen_dir/$file" ]]; then
                    case $file in
                        "secret.dunikey")
                            local g1pub=$(grep "pub:" "$zen_dir/$file" | cut -d ' ' -f 2 2>/dev/null)
                            if [[ -n "$g1pub" ]]; then
                                echo -e "    ✅ $file: ${GREEN}${g1pub:0:20}...${NC}"
                            else
                                echo -e "    ✅ $file: ${GREEN}Présent${NC}"
                            fi
                            ;;
                        ".pass")
                            echo -e "    ✅ $file: ${GREEN}Présent${NC}"
                            ;;
                        "ipfs/moa/index.html")
                            echo -e "    ✅ $file: ${GREEN}Présent${NC}"
                            ;;
                    esac
                else
                    echo -e "    ❌ $file: ${RED}Absent${NC}"
                fi
            done
        fi
    else
        echo -e "${WHITE}ZEN Card:${NC}"
        echo -e "  ❌ ${RED}Aucune ZEN Card associée${NC}"
        echo ""
        echo -e "${YELLOW}💡 Pour créer une ZEN Card à partir de ce MULTIPASS:${NC}"
        echo "  Utilisez l'option '3. Créer une nouvelle ZEN Card' dans le menu de gestion"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

# Fonction pour vérifier le niveau de la station
check_station_level() {
    local current_level="X"
    local ssh_ipfs_mismatch=false
    local node_dir="$HOME/.zen/tmp/$IPFSNODEID"
    
    # Méthode principale : vérifier les fichiers de niveau dans le répertoire du node
    if [[ -d "$node_dir" ]]; then
        if ls "$node_dir"/z_ssh* >/dev/null 2>&1; then
            current_level="Z"
        elif ls "$node_dir"/y_ssh* >/dev/null 2>&1; then
            current_level="Y"
        elif ls "$node_dir"/x_ssh* >/dev/null 2>&1; then
            current_level="X"
        fi
    fi
    

    
    # Vérifier la cohérence SSH/IPFS pour les niveaux Y et Z
    if [[ "$current_level" == "Y" || "$current_level" == "Z" ]]; then
        if [[ -f ~/.zen/game/id_ssh.pub ]] && [[ -f ~/.ssh/id_ed25519.pub ]]; then
            if [[ $(diff ~/.zen/game/id_ssh.pub ~/.ssh/id_ed25519.pub 2>/dev/null) ]]; then
                ssh_ipfs_mismatch=true
            fi
        fi
    fi
    
    echo "LEVEL:$current_level"
    echo "MISMATCH:$ssh_ipfs_mismatch"
}

# Fonction de debug pour diagnostiquer les problèmes de détection
debug_detection() {
    print_section "DEBUG - DIAGNOSTIC DE DÉTECTION"
    
    echo -e "${CYAN}Informations système:${NC}"
    echo "  IPFSNODEID: $IPFSNODEID"
    echo "  CURRENT: $CURRENT"
    echo "  PLAYER: $PLAYER"
    echo "  G1PUB: $G1PUB"
    echo "  ASTRONAUTENS: $ASTRONAUTENS"
    echo ""
    
    echo -e "${CYAN}Vérification des fichiers de niveau:${NC}"
    local node_dir="$HOME/.zen/tmp/$IPFSNODEID"
    if [[ -d "$node_dir" ]]; then
        echo "  Répertoire node: $node_dir"
        echo "  Fichiers de niveau trouvés:"
        ls -la "$node_dir"/[xyz]_ssh* 2>/dev/null || echo "    Aucun fichier de niveau trouvé"
    else
        echo "  Répertoire node non trouvé: $node_dir"
    fi
    echo ""
    
    echo -e "${CYAN}Vérification des services en temps réel:${NC}"
    echo "  IPFS processus: $(pgrep ipfs | wc -l) processus(s)"
    echo "  IPFS peers: $(ipfs swarm peers 2>/dev/null | wc -l) peer(s)"
    echo "  Astroport processus: $(pgrep -f "12345" | wc -l) processus(s)"
    echo "  Port 54321: $(netstat -tln 2>/dev/null | grep -c ":54321 ") port(s) ouvert(s)"
    echo "  Port 7777: $(netstat -tln 2>/dev/null | grep -c ":7777 ") port(s) ouvert(s)"
    echo "  Docker NextCloud: $(docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | wc -l) conteneur(s)"
    echo "  G1Billet processus: $(pgrep -f "G1BILLETS" | wc -l) processus(s)"
    echo ""
    
    echo -e "${CYAN}Fichier 12345.json:${NC}"
    local json_file="$HOME/.zen/tmp/$IPFSNODEID/12345.json"
    if [[ -f "$json_file" ]]; then
        local file_age=$(( $(date +%s) - $(stat -c %Y "$json_file" 2>/dev/null || echo 0) ))
        echo "  Présent: OUI (âge: ${file_age}s)"
        if command -v jq >/dev/null 2>&1; then
            echo "  Services dans JSON:"
            jq -r '.services | to_entries[] | "    \(.key): \(.value.active)"' "$json_file" 2>/dev/null || echo "    Erreur de lecture JSON"
        else
            echo "  jq non disponible pour analyser le JSON"
        fi
    else
        echo "  Présent: NON"
    fi
    
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

# Fonction pour proposer le passage au niveau Y
propose_y_level_upgrade() {
    print_section "PASSAGE AU NIVEAU Y - UPLANET ẐEN"
    
    echo -e "${CYAN}Votre station est actuellement au niveau X (SSH ≠ IPFS)${NC}"
    echo ""
    echo -e "${YELLOW}Niveaux de capitaine:${NC}"
    echo "  X: Clé IPFS standard" UPlanet ORIGIN
    echo "  Y: Clé SSH jumelle" UPlanet Ẑen " ← Objectif"
    echo "  Z: Clé PGP/Yubikey" UPlanet PGP
    echo ""
    
    echo -e "${GREEN}Avantages du niveau Y:${NC}"
    echo "  • Identité unifiée SSH/IPFS sécurisée"
    echo "  • Intégration à la toile de confiance CopyLaRadio"
    echo "  • Hébergement pour vous et vos amis"
    echo "  • Participation au réseau UPlanet Ẑen"
    echo "  • Accès aux services coopératifs"
    echo ""
    
    echo -e "${BLUE}À propos de CopyLaRadio:${NC}"
    echo "  CopyLaRadio est la Coopérative des Auto-Hébergeurs Web2 & Web3"
    echo "  qui assure la cohésion de l'écosystème protocolaire décentralisé."
    echo "  Plus d'infos: https://copylaradio.com"
    echo ""
    
    echo -e "${YELLOW}⚠️  Attention:${NC}"
    echo "  Cette opération va :"
    echo "  • Générer de nouvelles clés SSH/IPFS jumelles"
    echo "  • Sauvegarder vos clés actuelles (~/.ssh/origin.*)"
    echo "  • Redémarrer les services IPFS"
    echo "  • Modifier l'identité de votre nœud"
    echo ""
    
    read -p "Voulez-vous passer au niveau Y maintenant ? (oui/non): " upgrade_choice
    
    if [[ "$upgrade_choice" == "oui" || "$upgrade_choice" == "o" || "$upgrade_choice" == "y" || "$upgrade_choice" == "yes" ]]; then
        print_info "Lancement de la transmutation SSH/IPFS..."
        echo ""
        
        # Vérifier que le script Ylevel.sh existe
        local ylevel_script="${MY_PATH}/tools/Ylevel.sh"
        if [[ ! -f "$ylevel_script" ]]; then
            print_error "Script Ylevel.sh introuvable: $ylevel_script"
            return
        fi
        
        # Vérifier les permissions
        if [[ ! -x "$ylevel_script" ]]; then
            print_info "Ajout des permissions d'exécution..."
            chmod +x "$ylevel_script"
        fi
        
        # Lancer le script Ylevel.sh
        print_info "Exécution de la transmutation..."
        echo ""
        
        if bash "$ylevel_script"; then
            print_success "Passage au niveau Y réussi!"
            echo ""
            echo -e "${GREEN}🎉 Félicitations! Votre station est maintenant au niveau Y${NC}"
            echo ""
            echo -e "${CYAN}Prochaines étapes:${NC}"
            echo "  1. Votre station peut maintenant rejoindre la toile de confiance"
            echo "  2. Contactez CopyLaRadio pour l'intégration: support@qo-op.com"
            echo "  3. Partagez votre expérience sur forum.monnaie-libre.fr (qoop)"
            echo "  4. Devenez hébergeur pour vous et vos amis"
            echo ""
            echo -e "${BLUE}Ressources:${NC}"
            echo "  • Site web: https://copylaradio.com"
            echo "  • Forum: forum.monnaie-libre.fr"
            echo "  • Email: support@qo-op.com"
            echo ""
            
            # Proposer de redémarrer les services
            read -p "Redémarrer les services Astroport maintenant ? (oui/non): " restart_choice
            if [[ "$restart_choice" == "oui" || "$restart_choice" == "o" || "$restart_choice" == "y" || "$restart_choice" == "yes" ]]; then
                print_info "Redémarrage des services..."
                if [[ -f "${MY_PATH}/start.sh" ]]; then
                    bash "${MY_PATH}/start.sh"
                    print_success "Services redémarrés avec succès!"
                else
                    print_warning "Script start.sh introuvable"
                fi
            fi
        else
            print_error "Erreur lors du passage au niveau Y"
            echo "Consultez les logs pour plus d'informations"
        fi
        
        read -p "Appuyez sur ENTRÉE pour continuer..."
    else
        print_info "Passage au niveau Y annulé"
    fi
}

handle_extra_menu() {
    print_section "MENU EXTRA"
    echo "1. 🚀 Passer au niveau Y (UPlanet Ẑen)"
    echo "2. ☁️  Installer NextCloud"
    echo "3. 🐳 Applications Docker"
    echo "4. 💫 Faire un vœu"
    echo "5. 💰 Paiement NOSTR"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Votre choix: " extra_choice
    case $extra_choice in
        1)
            propose_y_level_upgrade
            ;;
        2)
            install_nextcloud
            ;;
        3)
            list_docker_apps
            ;;
        4)
            if [[ -n "$PLAYER" ]]; then
                print_section "FAIRE UN VŒU"
                print_info "Création d'un QR Code pour les lieux ou objets portant une Gvaleur..."
                cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html
                "${MY_PATH}/RUNTIME/G1Voeu.sh" "" "$PLAYER" "$HOME/.zen/tmp/$PLAYER.html"
                DIFF=$(diff ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html)
                if [[ $DIFF ]]; then
                    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
                    cp ~/.zen/game/players/$PLAYER/ipfs/moa/.chain ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)
                    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
                    ipfs name publish --key=$PLAYER /ipfs/$TW
                    echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
                    print_success "Vœu publié avec succès"
                fi
                echo "================================================"
                echo "$PLAYER : $myIPFS/ipns/$ASTRONAUTENS"
                echo "================================================"
                read -p "Appuyez sur ENTRÉE pour continuer..."
            else
                print_error "Aucune ZEN Card connectée. Connectez-vous d'abord."
                read -p "Appuyez sur ENTRÉE pour continuer..."
            fi
            ;;
        5)
            handle_nostr_payment
            ;;
        0)
            return
            ;;
        *)
            print_error "Choix invalide"
            sleep 1
            ;;
    esac
}

# Fonction principale
main() {
    # Vérifier les dépendances
    check_dependencies
    
    # Vérifier si c'est la première utilisation
    if check_first_time_usage; then
        print_header "BIENVENUE SUR ASTROPORT.ONE"
        echo -e "${GREEN}🎉 Installation terminée avec succès!${NC}"
        echo ""
        echo -e "${CYAN}Il semble que ce soit votre première utilisation d'Astroport.ONE.${NC}"
        echo "Nous allons vous guider pour configurer votre première identité numérique."
        echo ""
        
        read -p "Voulez-vous commencer la configuration maintenant ? (oui/non): " start_onboarding
        
        if [[ "$start_onboarding" == "oui" || "$start_onboarding" == "o" || "$start_onboarding" == "y" || "$start_onboarding" == "yes" ]]; then
            handle_first_time_onboarding
        else
            print_info "Configuration reportée. Vous pourrez la faire plus tard."
            echo ""
            echo -e "${YELLOW}Pour configurer votre identité plus tard:${NC}"
            echo "  • Relancez: ./command.sh"
            echo "  • Ou utilisez l'interface web: http://127.0.0.1:54321/g1"
            echo ""
        fi
    fi
    
    # Boucle principale
while true; do
        show_dashboard
    show_main_menu
        
    read -p "Votre choix: " choice

    case $choice in
        1)
                if [[ -z "$PLAYER" ]]; then
                    handle_card_creation
                else
                    handle_zen_card_management
                fi
                ;;
            2)
                if [[ -z "$PLAYER" ]]; then
                    list_existing_cards
                else
            print_section "CONNEXION SWARM"
                    print_info "Découverte et connexion aux autres ♥️box..."
            "${MY_PATH}/RUNTIME/SWARM.discover.sh"
                    read -p "Appuyez sur ENTRÉE pour continuer..."
                fi
                ;;
            3)
                if [[ -z "$PLAYER" ]]; then
                    print_section "SUPPRESSION DE CARTE"
                    print_warning "Cette action est irréversible"
                    read -p "Êtes-vous sûr? (oui/non): " confirm
                    if [[ "$confirm" == "oui" || "$confirm" == "o" || "$confirm" == "y" || "$confirm" == "yes" ]]; then
                        "${MY_PATH}/tools/nostr_DESTROY_TW.sh"
                    fi
                else
            print_section "STATUT SWARM"
                    print_info "Notifications et abonnements reçus..."
            "${MY_PATH}/tools/SWARM.notifications.sh"
                    read -p "Appuyez sur ENTRÉE pour continuer..."
                fi
                ;;
            4)
                handle_extra_menu
                ;;
            0)
                print_success "Au revoir!"
            exit 0
            ;;
        *)
                print_error "Choix invalide"
            sleep 1
            ;;
    esac
done
}

# Point d'entrée
main "$@"
