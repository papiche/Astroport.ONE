#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# ♥️BOX CONTROL - Interface CLI complète pour la gestion des ♥️box UPlanet
# Intègre : monitoring système, WireGuard, Swarm, VISA, services
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration globale
HEARTBOX_DIR="$HOME/.zen/heartbox"
mkdir -p "$HEARTBOX_DIR"

#######################################################################
# Fonctions utilitaires d'affichage
#######################################################################

print_header() {
    local title="$1"
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    printf "║%*s║\n" $((78)) ""
    printf "║%*s%s%*s║\n" $(((78-${#title})/2)) "" "$title" $(((78-${#title})/2)) ""
    printf "║%*s║\n" $((78)) ""
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    local title="$1"
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "│ %-76s │\n" "$title"
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

#######################################################################
# Analyse matérielle et système
#######################################################################

get_system_info() {
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "Non détecté")
    local cpu_cores=$(grep "processor" /proc/cpuinfo | wc -l 2>/dev/null || echo "0")
    local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "Non détecté")
    local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | xargs)
    
    local mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local mem_used=$((mem_total - mem_available))
    local mem_total_gb=$((mem_total / 1024 / 1024))
    local mem_used_gb=$((mem_used / 1024 / 1024))
    local mem_usage_percent=$((mem_used * 100 / mem_total))
    
    local disk_info=$(df -h / | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_available=$(echo "$disk_info" | awk '{print $4}')
    local disk_usage_percent=$(echo "$disk_info" | awk '{print $5}')
    
    echo -e "${WHITE}Processeur:${NC} $cpu_model"
    echo -e "${WHITE}Cœurs:${NC} $cpu_cores threads @ ${cpu_freq} MHz"
    echo -e "${WHITE}Charge CPU:${NC} $cpu_load"
    echo ""
    echo -e "${WHITE}Mémoire:${NC} ${mem_used_gb}GB / ${mem_total_gb}GB (${mem_usage_percent}%)"
    echo -e "${WHITE}Disque:${NC} $disk_used / $disk_total ($disk_usage_percent utilisé)"
    echo -e "${WHITE}Libre:${NC} $disk_available"
    
    # GPU detection
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_info=$(nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$gpu_info" ]]; then
            echo -e "${WHITE}GPU:${NC} $gpu_info"
        fi
    fi
}

#######################################################################
# Calcul des capacités d'abonnement
#######################################################################

calculate_subscription_capacity() {
    local disk_info=$(df -h / | tail -1)
    local disk_available_str=$(echo "$disk_info" | awk '{print $4}')
    
    # Conversion en GB
    local available_gb=$(echo "$disk_available_str" | sed 's/G//' | sed 's/T/*1024/' | bc 2>/dev/null || echo "0")
    
    if [[ $(echo "$available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        local zencard_parts=$(echo "($available_gb - 8*128) / 128" | bc 2>/dev/null || echo "0")
        local nostr_parts=$(echo "($available_gb - 8*10) / 10" | bc 2>/dev/null || echo "0")
        
        [[ $(echo "$zencard_parts < 0" | bc 2>/dev/null) -eq 1 ]] && zencard_parts=0
        [[ $(echo "$nostr_parts < 0" | bc 2>/dev/null) -eq 1 ]] && nostr_parts=0
        
        echo -e "${WHITE}Capacités d'abonnement:${NC}"
        echo "  🎫 ZenCards (128 GB/slot): $zencard_parts slots"
        echo "  📻 NOSTR Cards (10 GB/slot): $nostr_parts slots"
        echo "  👨‍✈️  Réservé capitaine: 8 slots (1024 GB)"
    else
        echo -e "${RED}❌ Impossible de calculer les capacités${NC}"
    fi
}

#######################################################################
# État des services
#######################################################################

check_services_status() {
    print_section "🔧 ÉTAT DES SERVICES"
    
    # IPFS
    if pgrep ipfs >/dev/null; then
        local ipfs_size=$(du -sh ~/.ipfs 2>/dev/null | cut -f1 || echo "N/A")
        local ipfs_peers=$(ipfs swarm peers 2>/dev/null | wc -l || echo "0")
        print_status "IPFS" "ACTIVE" "($ipfs_size, $ipfs_peers peers)"
    else
        print_status "IPFS" "INACTIVE" ""
    fi
    
    # Astroport
    if pgrep -f "12345" >/dev/null; then
        print_status "Astroport" "ACTIVE" "(API: http://localhost:12345)"
    else
        print_status "Astroport" "INACTIVE" ""
    fi
    
    # NextCloud
    if command -v docker >/dev/null 2>&1 && docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | grep -q nextcloud; then
        local nc_status=$(docker ps --filter "name=nextcloud" --format "{{.Status}}" 2>/dev/null | head -1)
        print_status "NextCloud" "ACTIVE" "($nc_status)"
    else
        print_status "NextCloud" "INACTIVE" "(Docker ou conteneurs non démarrés)"
    fi
    
    # WireGuard
    if sudo wg show wg0 >/dev/null 2>&1; then
        local wg_peers=$(sudo wg show wg0 | grep -c "peer:" || echo "0")
        print_status "WireGuard" "ACTIVE" "($wg_peers clients connectés)"
    else
        print_status "WireGuard" "INACTIVE" ""
    fi
    
    # G1Billet
    if pgrep -f "G1BILLETS" >/dev/null; then
        print_status "G1Billet" "ACTIVE" ""
    else
        print_status "G1Billet" "INACTIVE" ""
    fi
}

#######################################################################
# Analyse du Swarm
#######################################################################

analyze_swarm() {
    print_section "🌐 ANALYSE DE L'ESSAIM UPLANET"
    
    local swarm_dir="$HOME/.zen/tmp/swarm"
    if [[ -d "$swarm_dir" ]]; then
        local node_count=$(find "$swarm_dir" -maxdepth 1 -type d -name "12D*" | wc -l)
        local active_nodes=0
        
        echo -e "${WHITE}Nodes découverts:${NC} $node_count"
        
        for node_dir in "$swarm_dir"/12D*; do
            if [[ -d "$node_dir" && -f "$node_dir/12345.json" ]]; then
                local node_id=$(basename "$node_dir")
                local captain=$(jq -r '.captain' "$node_dir/12345.json" 2>/dev/null)
                local paf=$(jq -r '.PAF' "$node_dir/12345.json" 2>/dev/null)
                local hostname=$(jq -r '.hostname' "$node_dir/12345.json" 2>/dev/null)
                
                if [[ "$captain" != "null" && "$captain" != "" ]]; then
                    echo "  📡 ${node_id:0:8}... → $captain ($hostname) - PAF: $paf Ẑ"
                    ((active_nodes++))
                fi
            fi
        done
        
        echo -e "${WHITE}Nodes actifs:${NC} $active_nodes/$node_count"
    else
        echo "❌ Aucun répertoire swarm trouvé"
    fi
    
    # Abonnements locaux
    local sub_file="$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions.json"
    if [[ -f "$sub_file" ]]; then
        local sub_count=$(jq '.subscriptions | length' "$sub_file" 2>/dev/null || echo "0")
        echo -e "${WHITE}Abonnements sortants:${NC} $sub_count"
    fi
    
    # Abonnements reçus
    local recv_file="$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions_received.json"
    if [[ -f "$recv_file" ]]; then
        local recv_count=$(jq '.received_subscriptions | length' "$recv_file" 2>/dev/null || echo "0")
        echo -e "${WHITE}Abonnements reçus:${NC} $recv_count"
    fi
}

#######################################################################
# Menu principal
#######################################################################

show_main_menu() {
    clear
    print_header "♥️BOX CONTROL - Pilotage UPlanet"
    
    echo -e "${WHITE}Node ID:${NC} $IPFSNODEID"
    echo -e "${WHITE}Capitaine:${NC} $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'Non connecté')"
    echo -e "${WHITE}Type:${NC} $(if [[ -f ~/.zen/game/secret.dunikey ]]; then echo "Y Level (Node autonome)"; else echo "Standard"; fi)"
    echo ""
    
    get_system_info
    echo ""
    calculate_subscription_capacity
    echo ""
    check_services_status
    echo ""
    analyze_swarm
    echo ""
    
    echo -e "${YELLOW}ACTIONS DISPONIBLES:${NC}"
    echo "  1. 📊 Monitoring détaillé"
    echo "  2. 🌐 Gestion WireGuard"
    echo "  3. 🔗 Gestion Swarm UPlanet"
    echo "  4. 🎫 Impression VISA/ZenCard"
    echo "  5. 🛠️  Gestion des services"
    echo "  6. 📱 NextCloud Docker"
    echo "  7. 📋 Logs et diagnostics"
    echo "  8. ⚙️  Configuration"
    echo "  0. ❌ Quitter"
    echo ""
}

#######################################################################
# Monitoring détaillé
#######################################################################

show_detailed_monitoring() {
    clear
    print_header "📊 MONITORING DÉTAILLÉ"
    
    # Processus en cours
    print_section "🔄 PROCESSUS ACTIFS"
    echo "Processus UPlanet:"
    pgrep -af "ipfs\|12345\|astroport\|zen" | head -10
    echo ""
    
    # Utilisation réseau
    print_section "🌐 RÉSEAU")
    echo "Connexions IPFS:"
    netstat -tan | grep ":5001\|:4001\|:8080" | head -5
    echo ""
    echo "Connexions Astroport:"
    netstat -tan | grep ":12345\|:54321" | head -5
    echo ""
    
    # Utilisation disque détaillée
    print_section "💾 UTILISATION DISQUE")
    echo "Répertoires principaux:"
    du -sh ~/.zen ~/.ipfs /nextcloud-data 2>/dev/null | sort -hr
    echo ""
    
    # Logs récents
    print_section "📝 LOGS RÉCENTS")
    echo "Dernières activités:"
    tail -5 ~/.zen/tmp/12345.log 2>/dev/null || echo "Aucun log 12345"
    echo ""
    tail -5 ~/.zen/tmp/ipfs.swarm.peers 2>/dev/null || echo "Aucun log IPFS"
    
    echo ""
    echo "Appuyez sur ENTRÉE pour revenir au menu principal..."
    read
}

#######################################################################
# Gestion WireGuard
#######################################################################

manage_wireguard() {
    clear
    print_header "🌐 GESTION WIREGUARD")
    
    echo "1. 🚀 Initialiser serveur WireGuard"
    echo "2. 👥 Ajouter un client"
    echo "3. 📋 Afficher configuration"
    echo "4. 🔄 Redémarrer service"
    echo "5. 🛠️  Client setup (ce node)"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Choix: " wg_choice
    
    case $wg_choice in
        1) 
            echo "🚀 Initialisation du serveur WireGuard..."
            sudo "${MY_PATH}/wireguard_control.sh"
            ;;
        2)
            read -p "Nom du client: " client_name
            echo "Collez la clé SSH publique du client:"
            read -p "> " client_pubkey
            echo "$client_name|$client_pubkey" | sudo "${MY_PATH}/wireguard_control.sh"
            ;;
        3)
            echo "📋 Configuration WireGuard:"
            sudo wg show wg0 2>/dev/null || echo "❌ WireGuard non configuré"
            ;;
        4)
            echo "🔄 Redémarrage WireGuard..."
            sudo systemctl restart wg-quick@wg0
            ;;
        5)
            "${MY_PATH}/wg-client-setup.sh"
            ;;
    esac
    
    [[ $wg_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# Gestion Swarm
#######################################################################

manage_swarm() {
    clear
    print_header "🔗 GESTION SWARM UPLANET")
    
    echo "1. 🔍 Découvrir l'essaim"
    echo "2. 📊 Statut des abonnements"
    echo "3. 🔔 Notifications reçues"
    echo "4. 💰 Paiements Swarm"
    echo "5. ❓ Aide Swarm"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Choix: " swarm_choice
    
    case $swarm_choice in
        1) "${MY_PATH}/../RUNTIME/SWARM.discover.sh" ;;
        2) 
            echo "📊 Statut des abonnements Swarm:"
            if [[ -f "$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions.json" ]]; then
                jq '.' "$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions.json"
            else
                echo "❌ Aucun abonnement trouvé"
            fi
            ;;
        3) "${MY_PATH}/SWARM.notifications.sh" ;;
        4) "${MY_PATH}/../ZEN.SWARM.payments.sh" ;;
        5) "${MY_PATH}/SWARM.help.sh" ;;
    esac
    
    [[ $swarm_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# Impression VISA/ZenCard
#######################################################################

manage_visa() {
    clear
    print_header "🎫 IMPRESSION VISA/ZENCARD")
    
    local current_player=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
    
    echo "1. 🖨️  Imprimer VISA du capitaine actuel"
    echo "2. 🆕 Créer nouvelle ZenCard"
    echo "3. 🎨 Imprimer ZenCard personnalisée"
    echo "0. ⬅️  Retour"
    echo ""
    
    if [[ -n "$current_player" ]]; then
        echo -e "${WHITE}Capitaine actuel:${NC} $current_player"
    else
        echo -e "${RED}❌ Aucun capitaine connecté${NC}"
    fi
    echo ""
    
    read -p "Choix: " visa_choice
    
    case $visa_choice in
        1)
            if [[ -n "$current_player" ]]; then
                echo "🖨️  Impression VISA pour $current_player..."
                "${MY_PATH}/VISA.print.sh" "$current_player"
            else
                echo "❌ Aucun capitaine connecté"
            fi
            ;;
        2)
            read -p "Email: " email
            read -p "Secret 1: " salt
            read -p "Secret 2: " pepper
            read -p "PIN (4 chiffres): " pin
            echo "🆕 Création ZenCard..."
            "${MY_PATH}/VISA.print.sh" "$email" "$salt" "$pepper" "$pin"
            ;;
        3)
            echo "🎨 Fonctionnalité à venir..."
            ;;
    esac
    
    [[ $visa_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# Gestion des services
#######################################################################

manage_services() {
    clear
    print_header "🛠️  GESTION DES SERVICES")
    
    echo "1. 🔄 Redémarrer IPFS"
    echo "2. 🔄 Redémarrer Astroport"
    echo "3. 🔄 Redémarrer G1Billet"
    echo "4. 🔄 Redémarrer tous les services"
    echo "5. 🛑 Arrêter tous les services"
    echo "6. 🚀 Démarrer tous les services"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Choix: " service_choice
    
    case $service_choice in
        1) 
            echo "🔄 Redémarrage IPFS..."
            sudo systemctl restart ipfs
            ;;
        2)
            echo "🔄 Redémarrage Astroport..."
            sudo systemctl restart astroport 2>/dev/null || {
                killall nc 12345.sh 2>/dev/null
                "${MY_PATH}/../12345.sh" > ~/.zen/tmp/12345.log &
            }
            ;;
        3)
            echo "🔄 Redémarrage G1Billet..."
            sudo systemctl restart g1billet 2>/dev/null || echo "Service G1Billet non trouvé"
            ;;
        4)
            echo "🔄 Redémarrage de tous les services..."
            sudo systemctl restart ipfs astroport g1billet 2>/dev/null
            ;;
        5)
            echo "🛑 Arrêt de tous les services..."
            sudo systemctl stop ipfs astroport g1billet 2>/dev/null
            ;;
        6)
            echo "🚀 Démarrage de tous les services..."
            sudo systemctl start ipfs astroport g1billet 2>/dev/null
            ;;
    esac
    
    [[ $service_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# NextCloud Docker
#######################################################################

manage_nextcloud() {
    clear
    print_header "📱 NEXTCLOUD DOCKER")
    
    local compose_file="$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/docker-compose.yml"
    
    echo "1. 🚀 Démarrer NextCloud"
    echo "2. 🛑 Arrêter NextCloud"
    echo "3. 🔄 Redémarrer NextCloud"
    echo "4. 📊 État des conteneurs"
    echo "5. 📋 Logs NextCloud"
    echo "0. ⬅️  Retour"
    echo ""
    
    if [[ -f "$compose_file" ]]; then
        echo -e "${WHITE}Configuration:${NC} $compose_file"
    else
        echo -e "${RED}❌ Configuration NextCloud non trouvée${NC}"
    fi
    echo ""
    
    read -p "Choix: " nc_choice
    
    case $nc_choice in
        1)
            if [[ -f "$compose_file" ]]; then
                echo "🚀 Démarrage NextCloud..."
                cd "$(dirname "$compose_file")" && docker-compose up -d
            else
                echo "❌ Fichier docker-compose.yml non trouvé"
            fi
            ;;
        2)
            echo "🛑 Arrêt NextCloud..."
            cd "$(dirname "$compose_file")" && docker-compose down 2>/dev/null
            ;;
        3)
            echo "🔄 Redémarrage NextCloud..."
            cd "$(dirname "$compose_file")" && docker-compose restart 2>/dev/null
            ;;
        4)
            echo "📊 État des conteneurs NextCloud:"
            docker ps --filter "name=nextcloud"
            ;;
        5)
            echo "📋 Logs NextCloud:"
            docker logs nextcloud-aio-mastercontainer 2>/dev/null | tail -20
            ;;
    esac
    
    [[ $nc_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# Logs et diagnostics
#######################################################################

show_logs() {
    clear
    print_header "📋 LOGS ET DIAGNOSTICS")
    
    echo "1. 📊 Observer logs en temps réel"
    echo "2. 📝 Logs Astroport"
    echo "3. 🌐 Logs IPFS"
    echo "4. 🔗 Logs Swarm"
    echo "5. 💾 Archive 20h12"
    echo "6. 🔍 Diagnostic complet"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Choix: " log_choice
    
    case $log_choice in
        1) "${MY_PATH}/log_observation.sh" --menu ;;
        2) tail -f ~/.zen/tmp/12345.log 2>/dev/null || echo "❌ Aucun log Astroport" ;;
        3) tail -f ~/.zen/tmp/ipfs.swarm.peers 2>/dev/null || echo "❌ Aucun log IPFS" ;;
        4) tail -f ~/.zen/tmp/DRAGON.log 2>/dev/null || echo "❌ Aucun log Swarm" ;;
        5) 
            if [[ -f /tmp/20h12.log ]]; then
                less /tmp/20h12.log
            else
                echo "❌ Archive 20h12 non trouvée"
            fi
            ;;
        6)
            echo "🔍 Diagnostic complet en cours..."
            "${MY_PATH}/../20h12.process.sh" 2>&1 | tail -50
            ;;
    esac
    
    [[ $log_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# Configuration
#######################################################################

manage_config() {
    clear
    print_header "⚙️  CONFIGURATION")
    
    echo "1. 🔧 Configuration IPFS"
    echo "2. 🌐 Configuration réseau"
    echo "3. 💰 Configuration économie ZEN"
    echo "4. 🔑 Gestion clés SSH"
    echo "5. 📧 Configuration email"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Choix: " config_choice
    
    case $config_choice in
        1)
            echo "🔧 Configuration IPFS:"
            if [[ -f ~/.ipfs/config ]]; then
                echo "StorageMax: $(jq -r '.Datastore.StorageMax' ~/.ipfs/config)"
                echo "GC Watermark: $(jq -r '.Datastore.StorageGCWatermark' ~/.ipfs/config)%"
                echo "Swarm HighWater: $(jq -r '.Swarm.ConnMgr.HighWater' ~/.ipfs/config)"
            else
                echo "❌ Configuration IPFS non trouvée"
            fi
            ;;
        2)
            echo "🌐 Configuration réseau:"
            echo "Node ID: $IPFSNODEID"
            echo "Ports IPFS: $(netstat -tan | grep LISTEN | grep -E ':4001|:5001|:8080')"
            ;;
        3)
            echo "💰 Configuration économie ZEN:"
            if [[ -f ~/.zen/tmp/economics.json ]]; then
                cat ~/.zen/tmp/economics.json
            else
                echo "❌ Configuration économique non trouvée"
            fi
            ;;
        4)
            echo "🔑 Clés SSH:"
            if [[ -f ~/.ssh/id_ed25519.pub ]]; then
                echo "Clé publique ED25519:"
                cat ~/.ssh/id_ed25519.pub
            else
                echo "❌ Aucune clé SSH ED25519 trouvée"
            fi
            ;;
        5)
            echo "📧 Configuration email:"
            echo "Capitaine email: $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'Non configuré')"
            ;;
    esac
    
    [[ $config_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# Boucle principale
#######################################################################

main_loop() {
    while true; do
        show_main_menu
        read -p "Votre choix: " choice
        
        case $choice in
            1) show_detailed_monitoring ;;
            2) manage_wireguard ;;
            3) manage_swarm ;;
            4) manage_visa ;;
            5) manage_services ;;
            6) manage_nextcloud ;;
            7) show_logs ;;
            8) manage_config ;;
            0) 
                echo -e "${GREEN}👋 Au revoir !${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

#######################################################################
# Point d'entrée
#######################################################################

# Vérification des prérequis
if [[ ! -f "${MY_PATH}/my.sh" ]]; then
    echo "❌ Fichier my.sh non trouvé. Exécutez depuis le répertoire Astroport.ONE/tools/"
    exit 1
fi

# Démarrage de l'interface
clear
echo -e "${CYAN}♥️BOX CONTROL${NC} - Chargement..."
sleep 1

main_loop 