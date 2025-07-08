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

# Fonction pour vérifier le statut réel des services
check_services_status() {
    local services_status=()
    local nextcloud_available=false
    
    # Vérifier si le fichier 12345.json existe et est récent (< 24 heures)
    local status_file="$HOME/.zen/tmp/$IPFSNODEID/12345.json"
    local use_json_status=false
    
    if [[ -f "$status_file" ]]; then
        local file_age=$(( $(date +%s) - $(stat -c %Y "$status_file" 2>/dev/null || echo 0) ))
        if [[ $file_age -lt 86400 ]]; then  # 24 heures = 86400 secondes
            use_json_status=true
        fi
    fi
    
    if [[ "$use_json_status" == "true" ]]; then
        # Lire les statuts depuis le fichier JSON récent
        local ipfs_active=$(jq -r '.services.ipfs.active // false' "$status_file" 2>/dev/null)
        local astroport_active=$(jq -r '.services.astroport.active // false' "$status_file" 2>/dev/null)
        local uspot_active=$(jq -r '.services.uspot.active // false' "$status_file" 2>/dev/null)
        local nextcloud_active=$(jq -r '.services.nextcloud.active // false' "$status_file" 2>/dev/null)
        local nostr_relay_active=$(jq -r '.services.nostr_relay.active // false' "$status_file" 2>/dev/null)
        local g1billet_active=$(jq -r '.services.g1billet.active // false' "$status_file" 2>/dev/null)
    else
        # Vérification en temps réel
        local ipfs_active=false
        local astroport_active=false
        local uspot_active=false
        local nextcloud_active=false
        local nostr_relay_active=false
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
        
        # uSPOT/uPassport - simple port check
        if ss -tlnp 2>/dev/null | grep -q ":54321 "; then
            uspot_active=true
            uspot_proc=$(ss -tlnp 2>/dev/null | grep ":54321 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
        else
            uspot_active=false
            uspot_proc=""
        fi
        
        # NextCloud - vérifier les conteneurs Docker
        if command -v docker >/dev/null 2>&1 && docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | grep -q nextcloud; then
            nextcloud_active=true
        fi
        
        # NOSTR Relay - simple port check
        if ss -tlnp 2>/dev/null | grep -q ":7777 "; then
            nostr_relay_active=true
            nostr_proc=$(ss -tlnp 2>/dev/null | grep ":7777 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
        else
            nostr_relay_active=false
            nostr_proc=""
        fi
        
        # G1Billet - vérifier le processus
        if pgrep -f "G1BILLETS" >/dev/null; then
            g1billet_active=true
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
        "uSPOT/uPassport:$uspot_active"
        "NextCloud:$nextcloud_active"
        "NOSTR_Relay:$nostr_relay_active"
        "G1Billet:$g1billet_active"
    )
    
    # Retourner les statuts et la disponibilité de NextCloud
    echo "${services_status[@]}"
    echo "NEXTCLOUD_AVAILABLE:$nextcloud_available"
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
    local uspot_active=false
    local uspot_proc=""
    if ss -tlnp 2>/dev/null | grep -q ":54321 "; then
        uspot_active=true
        uspot_proc=$(ss -tlnp 2>/dev/null | grep ":54321 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
    fi
    local nostr_relay_active=false
    local nostr_proc=""
    if ss -tlnp 2>/dev/null | grep -q ":7777 "; then
        nostr_relay_active=true
        nostr_proc=$(ss -tlnp 2>/dev/null | grep ":7777 " | sed -n 's/.*users:((("\([^"]*\)".*/\1/p' | head -n1)
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
        
        if [[ "$service_name" == "uSPOT/uPassport" ]]; then
            if [[ "$uspot_active" == true ]]; then
                print_status "uSPOT/uPassport" "ACTIVE" "(Services locaux)${uspot_proc:+ - $uspot_proc}"
            else
                print_status "uSPOT/uPassport" "INACTIVE" "(Services locaux)"
            fi
            continue
        fi
        if [[ "$service_name" == "NOSTR_Relay" ]]; then
            if [[ "$nostr_relay_active" == true ]]; then
                print_status "NOSTR Relay" "ACTIVE" "(Réseau social)${nostr_proc:+ - $nostr_proc}"
            else
                print_status "NOSTR Relay" "INACTIVE" "(Réseau social)"
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
                "uSPOT/uPassport")
                    print_status "uSPOT/uPassport" "ACTIVE" "(Services locaux)${uspot_proc:+ - $uspot_proc}"
                    ;;
                "NextCloud")
                    print_status "NextCloud" "ACTIVE" "(Stockage personnel)"
                    ;;
                "NOSTR_Relay")
                    print_status "NOSTR Relay" "ACTIVE" "(Réseau social)${nostr_proc:+ - $nostr_proc}"
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
                "uSPOT/uPassport")
                    print_status "uSPOT/uPassport" "INACTIVE" "(Services locaux)"
                    ;;
                "NextCloud")
                    if [[ "$nextcloud_available" == "true" ]]; then
                        print_status "NextCloud" "INACTIVE" "(Stockage personnel) - Installé mais non démarré"
                    else
                        print_status "NextCloud" "MISSING" "(Stockage personnel) - Non installé"
                    fi
                    ;;
                "NOSTR_Relay")
                    print_status "NOSTR Relay" "INACTIVE" "(Réseau social)"
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
                "uSPOT/uPassport")
                    if [[ "$uspot_active" == false ]]; then
                        missing_services+=("uSPOT/uPassport")
                    fi
                    ;;
                "NOSTR_Relay")
                    if [[ "$nostr_relay_active" == false ]]; then
                        missing_services+=("NOSTR_Relay")
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
    echo "  1. Créer un compte MULTIPASS (interface web ou CLI)"
    echo "  2. Créer une ZEN Card (interface CLI)"
    echo ""
    echo -e "${YELLOW}Cette configuration vous permettra de:${NC}"
    echo "  • Participer au réseau social NOSTR"
    echo "  • Stocker et partager des fichiers sur IPFS"
    echo "  • Gagner des récompenses G1"
    echo "  • Rejoindre la communauté UPlanet"
    echo ""

    # Choix de la méthode de création du MULTIPASS
    echo "Comment souhaitez-vous créer votre MULTIPASS ?"
    echo "  1. Interface web (recommandé)"
    echo "  2. En ligne de commande (CLI)"
    read -p "Votre choix [1/2]: " multipass_mode
    multipass_mode=${multipass_mode:-1}

    if [[ "$multipass_mode" == "2" ]]; then
        # Création MULTIPASS en CLI
        print_section "CRÉATION DU COMPTE MULTIPASS (CLI)"
        GEO_INFO=$(curl -s ipinfo.io/json 2>/dev/null)
        read -p "📧 Email: " EMAIL
        [[ -z "$EMAIL" ]] && { print_error "Email requis"; return; }
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
        if "${MY_PATH}/tools/make_NOSTRCARD.sh" "$EMAIL" "fr" "$LAT" "$LON"; then
            print_success "MULTIPASS créée avec succès pour $EMAIL"
        else
            print_error "Erreur lors de la création de la MULTIPASS"
            return
        fi
    else
        # Création MULTIPASS via interface web
        print_section "ÉTAPE 1: CRÉATION DU COMPTE MULTIPASS (WEB)"
        echo -e "${CYAN}Nous allons ouvrir l'interface web pour créer votre compte MULTIPASS.${NC}"
        echo ""
        echo -e "${YELLOW}Instructions:${NC}"
        echo "  1. L'interface web va s'ouvrir automatiquement"
        echo "  2. Remplissez le formulaire avec votre email et localisation"
        echo "  3. Notez bien l'email et les coordonnées GPS utilisés"
        echo "  4. Une fois terminé, revenez ici pour continuer"
        echo ""
        read -p "Appuyez sur ENTRÉE pour ouvrir l'interface web..."
        print_info "Ouverture de l'interface web..."
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "http://127.0.0.1:54321/g1" 2>/dev/null
        elif command -v open >/dev/null 2>&1; then
            open "http://127.0.0.1:54321/g1" 2>/dev/null
        else
            echo -e "${YELLOW}Ouvrez manuellement votre navigateur et allez sur:${NC}"
            echo "  http://127.0.0.1:54321/g1"
        fi
        echo ""
        echo -e "${GREEN}✅ Interface web ouverte!${NC}"
        echo ""
        echo -e "${CYAN}Une fois votre compte MULTIPASS créé, nous passerons à l'étape suivante.${NC}"
        echo ""
        read -p "Avez-vous créé votre compte MULTIPASS ? (oui/non): " multipass_created
        if [[ "$multipass_created" != "oui" && "$multipass_created" != "o" && "$multipass_created" != "y" && "$multipass_created" != "yes" ]]; then
            print_warning "Veuillez créer votre compte MULTIPASS d'abord, puis relancez command.sh"
            return
        fi
        # Vérifier que le compte MULTIPASS a bien été créé
        local multipass_count=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
        if [[ $multipass_count -eq 0 ]]; then
            print_error "Aucun compte MULTIPASS trouvé. Veuillez créer votre compte d'abord."
            return
        fi
    fi

    print_success "Compte MULTIPASS détecté!"

    # Étape 2: Création ZEN Card via CLI, pré-remplir avec infos MULTIPASS
    print_section "ÉTAPE 2: CRÉATION DE LA ZEN CARD"
    echo -e "${CYAN}Nous allons utiliser les informations de votre compte MULTIPASS pour créer votre ZEN Card.${NC}"
    # Récupérer les informations du compte MULTIPASS le plus récent
    local latest_multipass=$(ls -t ~/.zen/game/nostr 2>/dev/null | grep "@" | head -n 1)
    if [[ -z "$latest_multipass" ]]; then
        print_error "Impossible de trouver le compte MULTIPASS"
        return
    fi
    local multipass_dir="$HOME/.zen/game/nostr/$latest_multipass"
    local email_file="$multipass_dir/EMAIL"
    local lat_file="$multipass_dir/LAT"
    local lon_file="$multipass_dir/LON"
    local npub_file="$multipass_dir/NPUB"
    local email=""
    local lat=""
    local lon=""
    local npub=""
    if [[ -f "$email_file" ]]; then
        email=$(cat "$email_file")
    fi
    if [[ -f "$lat_file" ]]; then
        lat=$(cat "$lat_file")
    fi
    if [[ -f "$lon_file" ]]; then
        lon=$(cat "$lon_file")
    fi
    if [[ -f "$npub_file" ]]; then
        npub=$(cat "$npub_file")
    fi
    echo "Email: $email"
    echo "Latitude: $lat"
    echo "Longitude: $lon"
    echo "NPUB: $npub"
    echo ""
    read -p "Voulez-vous utiliser ces informations pour créer la ZEN Card ? (oui/non): " use_multipass_info
    if [[ "$use_multipass_info" != "oui" && "$use_multipass_info" != "o" && "$use_multipass_info" != "y" && "$use_multipass_info" != "yes" ]]; then
        read -p "📧 Email: " email
        read -p "📍 Latitude: " lat
        read -p "📍 Longitude: " lon
        read -p "🔑 NPUB (NOSTR Card, optionnel): " npub
    fi
    [[ -z "$lat" ]] && lat="0.00"
    [[ -z "$lon" ]] && lon="0.00"
    # Génération automatique des secrets
    local ppass=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
    local npass=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
    print_info "Secret 1 généré: $ppass"
    print_info "Secret 2 généré: $npass"
    read -p "🔐 Secret 1 [$ppass]: " custom_ppass
    read -p "🔐 Secret 2 [$npass]: " custom_npass
    [[ -n "$custom_ppass" ]] && ppass="$custom_ppass"
    [[ -n "$custom_npass" ]] && npass="$custom_npass"
    local hex=""
    if [[ -n "$npub" ]]; then
        hex=$(${MY_PATH}/tools/nostr2hex.py "$npub" 2>/dev/null)
        [[ -n "$hex" ]] && print_info "Clé NOSTR convertie: $hex"
    fi
    print_info "Création de la ZEN Card..."
    if "${MY_PATH}/RUNTIME/VISA.new.sh" "$ppass" "$npass" "$email" "UPlanet" "fr" "$lat" "$lon" "$npub" "$hex"; then
        local pseudo=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null)
        rm -f ~/.zen/tmp/PSEUDO
        print_success "ZEN Card créée avec succès pour $pseudo!"
        echo ""
        # Définir comme carte courante
        PLAYER="$pseudo"
        G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
        ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | head -n1 | cut -d ' ' -f 1)
        # Mettre à jour .current
        rm -f ~/.zen/game/players/.current
        ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current
        print_success "Configuration terminée avec succès!"
        echo ""
        echo -e "${GREEN}🎉 Félicitations! Votre station est maintenant configurée:${NC}"
        echo "  • Compte MULTIPASS: $latest_multipass"
        echo "  • ZEN Card: $PLAYER"
        echo "  • G1PUB: $G1PUB"
        echo "  • IPNS: $myIPFS/ipns/$ASTRONAUTENS"
        echo ""
        echo -e "${CYAN}Vous pouvez maintenant utiliser toutes les fonctionnalités d'Astroport.ONE!${NC}"
        echo ""
        # Proposer d'imprimer la VISA
        read -p "Voulez-vous imprimer votre VISA maintenant ? (oui/non): " print_visa
        if [[ "$print_visa" == "oui" || "$print_visa" == "o" || "$print_visa" == "y" || "$print_visa" == "yes" ]]; then
            print_info "Impression de la VISA..."
            "${MY_PATH}/tools/VISA.print.sh" "$PLAYER"
        fi
        # Proposer de redémarrer Astroport
        echo ""
        echo -e "${CYAN}Pour finaliser l'installation et activer tous les services, Astroport doit être redémarré.${NC}"
        read -p "Voulez-vous redémarrer Astroport maintenant ? (oui/non): " restart_astroport
        if [[ "$restart_astroport" == "oui" || "$restart_astroport" == "o" || "$restart_astroport" == "y" || "$restart_astroport" == "yes" ]]; then
            if systemctl --user status astroport >/dev/null 2>&1 || systemctl status astroport >/dev/null 2>&1; then
                print_info "Redémarrage du service Astroport..."
                sudo systemctl restart astroport && print_success "Astroport redémarré."
            elif [[ -f "${MY_PATH}/start.sh" ]]; then
                print_info "Redémarrage via start.sh..."
                bash "${MY_PATH}/start.sh" && print_success "Astroport redémarré."
            else
                print_warning "Impossible de trouver le service ou le script de démarrage Astroport. Redémarrez-le manuellement."
            fi
        fi
        read -p "Appuyez sur ENTRÉE pour continuer..."
    else
        print_error "Erreur lors de la création de la ZEN Card"
        echo "Vous pouvez réessayer plus tard avec la commande: ./command.sh"
    fi
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
            while true; do
                print_section "MULTIPASS & ZEN Card"
                printf "%-30s | %-20s\n" "MULTIPASS (Email)" "ZEN Card (Pseudo)"
                printf -- "%.0s-" {1..55}; echo
                for mp in $(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | sort); do
                    pseudo=""
                    # Cherche une ZEN Card associée (même email)
                    for zc in $(ls ~/.zen/game/players 2>/dev/null | grep "@" | sort); do
                        if [[ "$mp" == "$zc" ]]; then
                            pseudo="$zc"
                            break
                        fi
                    done
                    if [[ -n "$pseudo" ]]; then
                        printf "%-30s | %-20s\n" "$mp" "$pseudo"
                    else
                        printf "%-30s | %-20s\n" "$mp" "Aucune ZEN Card associée"
                    fi
                done
                echo ""
                read -p "Appuyez sur ENTRÉE pour revenir au menu de gestion..." _
                break
            done
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
            if "${MY_PATH}/tools/make_NOSTRCARD.sh" "$EMAIL" "fr" "$LAT" "$LON"; then
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
                echo "$((i+1)). ${mps[$i]}"
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
            LAT=""; LON=""; [[ -f "$mp_dir/LAT" ]] && LAT=$(cat "$mp_dir/LAT")
            [[ -f "$mp_dir/LON" ]] && LON=$(cat "$mp_dir/LON")
            [[ -z "$LAT" ]] && LAT="0.00"
            [[ -z "$LON" ]] && LON="0.00"
            print_info "Création de la ZEN Card pour $EMAIL ($LAT, $LON)"
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
            if "${MY_PATH}/RUNTIME/VISA.new.sh" "$PPASS" "$NPASS" "$EMAIL" "UPlanet" "fr" "$LAT" "$LON"; then
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
                        if "${MY_PATH}/RUNTIME/PLAYER.unplug.sh" "$HOME/.zen/game/players/$PSEUDO/ipfs/moa/index.html" "$PSEUDO"; then
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
        if "${MY_PATH}/RUNTIME/PLAYER.unplug.sh" "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}"; then
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
