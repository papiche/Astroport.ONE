#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0 - Optimisé pour l'essaim UPlanet
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# ♥️BOX CONTROL - Interface CLI pour la gestion des ♥️box UPlanet
# Utilise le cache JSON quotidien de heartbox_analysis.sh (20h12)
# Optimisé pour l'essaim de nodes interconnectés
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Forcer la locale numérique pour éviter les problèmes de virgule/point
export LC_NUMERIC=C

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
HEARTBOX_CACHE_FILE="$HOME/.zen/tmp/$IPFSNODEID/heartbox_analysis.json"

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
# Gestion du cache JSON quotidien
#######################################################################

# Vérifier si le cache JSON est disponible et récent (< 24h)
is_cache_valid() {
    if [[ ! -f "$HEARTBOX_CACHE_FILE" ]]; then
        return 1
    fi
    
    local file_age=$(( $(date +%s) - $(stat -c %Y "$HEARTBOX_CACHE_FILE" 2>/dev/null || echo 0) ))
    [[ $file_age -lt 86400 ]]  # 24 heures = 86400 secondes
}

# Charger les données depuis le cache JSON
load_cache_data() {
    if ! is_cache_valid; then
        echo -e "${YELLOW}⚠️  Cache JSON non disponible ou obsolète${NC}"
        echo "  Le cache sera mis à jour à 20h12 par heartbox_analysis.sh"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}❌ jq non disponible pour lire le cache JSON${NC}"
        return 1
    fi
    
    return 0
}

#######################################################################
# Affichage des informations système depuis le cache
#######################################################################

display_system_info() {
    if ! load_cache_data; then
        return
    fi
    
    print_section "💻 INFORMATIONS SYSTÈME"
    
    # Informations CPU
    local cpu_model=$(jq -r '.system.cpu.model' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local cpu_cores=$(jq -r '.system.cpu.cores' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local cpu_freq=$(jq -r '.system.cpu.frequency_mhz' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local cpu_load=$(jq -r '.system.cpu.load_average' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    
    echo -e "${WHITE}Processeur:${NC} $cpu_model"
    echo -e "${WHITE}Cœurs:${NC} $cpu_cores threads @ ${cpu_freq} MHz"
    echo -e "${WHITE}Charge CPU:${NC} $cpu_load"
    echo ""
    
    # Informations mémoire
    local mem_total=$(jq -r '.system.memory.total_gb' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local mem_used=$(jq -r '.system.memory.used_gb' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local mem_usage=$(jq -r '.system.memory.usage_percent' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    
    echo -e "${WHITE}Mémoire:${NC} ${mem_used}GB / ${mem_total}GB (${mem_usage}%)"
    
    # Informations stockage
    local disk_total=$(jq -r '.system.storage.total' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local disk_used=$(jq -r '.system.storage.used' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local disk_available=$(jq -r '.system.storage.available' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local disk_usage=$(jq -r '.system.storage.usage_percent' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    
    echo -e "${WHITE}Disque:${NC} $disk_used / $disk_total ($disk_usage utilisé)"
    echo -e "${WHITE}Libre:${NC} $disk_available"
    
    # GPU si disponible
    local gpu_info=$(jq -r '.system.gpu' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    if [[ "$gpu_info" != "null" ]]; then
        echo -e "${WHITE}GPU:${NC} $gpu_info"
    fi
}

#######################################################################
# Affichage des capacités d'abonnement depuis le cache
#######################################################################

display_capacities() {
    if ! load_cache_data; then
        return
    fi
    
    print_section "📊 CAPACITÉS D'ABONNEMENT"
    
    local zencard_slots=$(jq -r '.capacities.zencard_slots' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local nostr_slots=$(jq -r '.capacities.nostr_slots' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local available_gb=$(jq -r '.capacities.available_space_gb' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    
    echo -e "${WHITE}Capacités d'abonnement:${NC}"
    echo "  🎫 ZenCards (128 GB/slot): ${zencard_slots} slots"
    echo "  📻 NOSTR Cards (10 GB/slot): ${nostr_slots} slots"
    echo "  👨‍✈️  Réservé capitaine: 8 slots (1024 GB)"
    echo "  💾 Espace total disponible: ${available_gb} GB"
}

#######################################################################
# Affichage de l'état des services depuis le cache
#######################################################################

display_services_status() {
    if ! load_cache_data; then
        return
    fi
    
    print_section "🔧 ÉTAT DES SERVICES"
        
        # IPFS
    local ipfs_active=$(jq -r '.services.ipfs.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local ipfs_size=$(jq -r '.services.ipfs.size' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local ipfs_peers=$(jq -r '.services.ipfs.peers_connected' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    
    if [[ "$ipfs_active" == "true" ]]; then
            print_status "IPFS" "ACTIVE" "($ipfs_size, $ipfs_peers peers)"
        else
            print_status "IPFS" "INACTIVE" ""
        fi
        
        # Astroport
    local astroport_active=$(jq -r '.services.astroport.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    if [[ "$astroport_active" == "true" ]]; then
            print_status "Astroport" "ACTIVE" "(API: http://localhost:12345)"
        else
            print_status "Astroport" "INACTIVE" ""
        fi
    
    # UPassport API
    local upassport_active=$(jq -r '.services.upassport.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    if [[ "$upassport_active" == "true" ]]; then
        print_status "UPassport" "ACTIVE" "(API :54321)"
    else
        print_status "UPassport" "INACTIVE" ""
    fi
        
        # NextCloud
    local nextcloud_active=$(jq -r '.services.nextcloud.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local nc_aio=$(jq -r '.services.nextcloud.aio_https.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local nc_cloud=$(jq -r '.services.nextcloud.cloud_http.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    
    if [[ "$nextcloud_active" == "true" ]]; then
        local nc_status=""
        [[ "$nc_aio" == "true" ]] && nc_status+="AIO "
        [[ "$nc_cloud" == "true" ]] && nc_status+="Cloud"
        print_status "NextCloud" "ACTIVE" "($nc_status)"
    else
        print_status "NextCloud" "INACTIVE" ""
    fi
    
    # strfry NOSTR relay
    local strfry_active=$(jq -r '.services.strfry.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local strfry_db=$(jq -r '.services.strfry.db_size_bytes // 0' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    local strfry_db_mb=$(echo "scale=1; $strfry_db / 1048576" | bc 2>/dev/null || echo "0")
    if [[ "$strfry_active" == "true" ]]; then
        print_status "strfry" "ACTIVE" "(NOSTR relay :7777, DB: ${strfry_db_mb}MB)"
    else
        print_status "strfry" "INACTIVE" ""
    fi
        
        # G1Billet
    local g1billet_active=$(jq -r '.services.g1billet.active' "$HEARTBOX_CACHE_FILE" 2>/dev/null)
    if [[ "$g1billet_active" == "true" ]]; then
            print_status "G1Billet" "ACTIVE" ""
        else
            print_status "G1Billet" "INACTIVE" ""
    fi
}

#######################################################################
# Analyse du Swarm UPlanet
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
# Guide interactif
#######################################################################

show_guide() {
    clear
    print_header "📚 GUIDE DU CAPITAINE"
    
    echo "1. 🚀 Premiers pas"
    echo "2. 🔑 Gestion des clés"
    echo "3. 🌐 Services et réseaux"
    echo "4. 💰 Économie ZEN"
    echo "5. 📱 Applications"
    echo "0. ⬅️  Retour"
    echo ""
    read -p "Choix: " guide_choice
    
    case $guide_choice in
        1)
            echo -e "${CYAN}🚀 PREMIERS PAS${NC}"
            echo "1. Installation d'Astroport.ONE"
            echo "2. Création de votre ZEN Card"
            echo "3. Configuration de base"
            echo "4. Première connexion"
            echo ""
            echo "Appuyez sur ENTRÉE pour continuer..."
            read
            ;;
        2)
            echo -e "${CYAN}🔑 GESTION DES CLÉS${NC}"
            echo "1. Clé IPFS (niveau X)"
            echo "2. Clé SSH jumelle (niveau Y)"
            echo "3. Clé PGP/Yubikey (niveau Z)"
            echo "4. Clé MULTIPASS NOSTR"
            echo ""
            echo "Appuyez sur ENTRÉE pour continuer..."
            read
            ;;
        3)
            echo -e "${CYAN}🌐 SERVICES ET RÉSEAUX${NC}"
            echo "1. IPFS (stockage distribué)"
            echo "2. NOSTR relay (réseau social)"
            echo "3. NextCloud (stockage personnel)"
            echo "4. uSPOT (services locaux)"
            echo ""
            echo "Appuyez sur ENTRÉE pour continuer..."
            read
            ;;
        4)
            echo -e "${CYAN}💰 ÉCONOMIE ZEN${NC}"
            echo "1. Portefeuille NOSTR"
            echo "2. Récompenses (0.1 G1 par like)"
            echo "3. uDRIVE (stockage partagé)"
            echo "4. Règles de partage"
            echo ""
            echo "Appuyez sur ENTRÉE pour continuer..."
            read
            ;;
        5)
            echo -e "${CYAN}📱 APPLICATIONS${NC}"
            echo "1. Interface web (http://astroport.localhost:1234)"
            echo "2. CLI (command.sh)"
            echo "3. Applications mobiles"
            echo "4. Intégrations"
            echo ""
            echo "Appuyez sur ENTRÉE pour continuer..."
            read
            ;;
    esac
}

#######################################################################
# Menu principal simplifié
#######################################################################

show_main_menu() {
    clear
    
    print_header "♥️BOX CONTROL - Pilotage UPlanet"
    
    echo -e "${WHITE}Node ID:${NC} $IPFSNODEID"
    echo -e "${WHITE}Capitaine:${NC} $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'Non connecté')"
    echo -e "${WHITE}Type:${NC} $(if [[ -f ~/.zen/tmp/$IPFSNODEID/y_ssh.pub ]]; then echo "Y Level (Node autonome)"; elif [[ -f ~/.zen/tmp/$IPFSNODEID/z_ssh.pub ]]; then echo "Z Level (Node relais)"; else echo "X Level (Node standard)"; fi)"
    echo ""
    
    # Afficher les informations depuis le cache JSON
    display_system_info
    echo ""
    display_capacities
    echo ""
    display_services_status
    echo ""
    analyze_swarm
    echo ""
    
    # Informations sur le cache
    if is_cache_valid; then
        local cache_age=$(( ($(date +%s) - $(stat -c %Y "$HEARTBOX_CACHE_FILE" 2>/dev/null || echo 0)) / 3600 ))
        echo -e "${CYAN}📊 Cache JSON:${NC} Mis à jour il y a ${cache_age}h (prochaine mise à jour: 20h12)"
    else
        echo -e "${YELLOW}⚠️  Cache JSON:${NC} Obsolète ou manquant (mise à jour à 20h12)"
    fi
    echo ""
    
    echo -e "${YELLOW}ACTIONS DISPONIBLES:${NC}"
    echo "  1. 📊 Monitoring détaillé"
    echo "  2. 🌐 Gestion WireGuard"
    echo "  3. 🔗 Gestion Swarm UPlanet"
    echo "  4. ⚙️  Configuration"
    echo "  5. 📚 Guide du capitaine"
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
    print_section "🌐 RÉSEAU"
    echo "Connexions IPFS:"
    netstat -tan | grep ":5001\|:4001\|:8080" | head -5
    echo ""
    echo "Connexions Astroport:"
    netstat -tan | grep ":12345\|:54321" | head -5
    echo ""
    
    # Utilisation disque détaillée
    print_section "💾 UTILISATION DISQUE"
    echo "Répertoires nextcloud:"
    du -sh ~/.zen ~/.ipfs /nextcloud-data 2>/dev/null | sort -hr
    echo ""
    
    # Logs récents
    print_section "📝 LOGS RÉCENTS"
    echo "Dernières activités:"
    tail -5 ~/.zen/tmp/12345.log 2>/dev/null || echo "Aucun log 12345"
    echo ""
    tail -5 ~/.zen/tmp/ipfs.swarm.peers 2>/dev/null || echo "Aucun log IPFS"
    
    echo ""
    echo "Appuyez sur ENTRÉE pour revenir au menu principal..."
    read
}

#######################################################################
# Gestion WireGuard (AMÉLIORÉE)
#######################################################################

# Import des fonctions WireGuard si disponibles
if [[ -f "${MY_PATH}/wireguard_control.sh" ]]; then
    # Sourcer uniquement les fonctions utilitaires
    source <(grep -A20 "^ssh_to_wg\|^convert_ssh_keys\|^setup_server\|^add_client" "${MY_PATH}/wireguard_control.sh" | grep -v "^show_menu\|^check_deps")
    WG_FUNCTIONS_AVAILABLE=true
else
    WG_FUNCTIONS_AVAILABLE=false
fi

# Fonction pour vérifier l'état WireGuard
check_wireguard_status() {
    if systemctl is-active --quiet wg-quick@wg0; then
        local peers=$(sudo wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
        local endpoint=$(sudo wg show wg0 2>/dev/null | grep "endpoint:" | head -1 | awk '{print $2}' || echo "Non configuré")
        echo -e "${GREEN}✅ WireGuard actif${NC} - $peers clients connectés"
        echo -e "${WHITE}Endpoint:${NC} $endpoint"
        return 0
    else
        echo -e "${RED}❌ WireGuard inactif${NC}"
        return 1
    fi
}

# Fonction pour lister les clients configurés
list_wireguard_clients() {
    if [[ -f /etc/wireguard/wg0.conf ]]; then
        echo -e "${CYAN}📋 Clients configurés:${NC}"
        sudo grep -A2 "^# " /etc/wireguard/wg0.conf | while read -r line; do
            if [[ "$line" =~ ^#[[:space:]]+(.+) ]]; then
                local client_name="${BASH_REMATCH[1]}"
                echo "  🔐 $client_name"
            fi
        done
    else
        echo -e "${YELLOW}⚠️ Aucune configuration WireGuard trouvée${NC}"
    fi
}

# Interface WireGuard améliorée
manage_wireguard() {
    clear
    print_header "🌐 GESTION WIREGUARD"
    
    # Affichage du statut actuel
    check_wireguard_status
    echo ""
    list_wireguard_clients
    echo ""
    
    if [[ "$WG_FUNCTIONS_AVAILABLE" == "true" ]]; then
        echo "1. 🚀 Initialiser serveur WireGuard (depuis clés SSH)"
        echo "2. 👥 Ajouter un client avec restrictions"
        echo "3. 🔓 Ajouter un client (accès complet)"
        echo "4. 📋 Afficher configuration détaillée"
        echo "5. 🔄 Redémarrer service"
        echo "6. 🛠️  Configuration client (ce node)"
        echo "7. 📤 Générer QR Code client"
        echo "0. ⬅️  Retour"
    else
        echo -e "${RED}❌ Scripts WireGuard non disponibles${NC}"
        echo "3. 📋 Afficher configuration"
        echo "4. 🔄 Redémarrer service"
        echo "0. ⬅️  Retour"
    fi
    echo ""
    read -p "Choix: " wg_choice
    
    case $wg_choice in
        1) 
            if [[ "$WG_FUNCTIONS_AVAILABLE" == "true" ]]; then
                echo "🚀 Initialisation du serveur WireGuard..."
                if [[ -f ~/.ssh/id_ed25519 ]]; then
                    echo "🔑 Conversion des clés SSH existantes..."
                    setup_server
                    echo -e "${GREEN}✅ Serveur initialisé avec succès${NC}"
                else
                    echo -e "${RED}❌ Aucune clé SSH ED25519 trouvée${NC}"
                    echo "Générez d'abord vos clés SSH avec : ssh-keygen -t ed25519"
                fi
            fi
            ;;
        2)
            if [[ "$WG_FUNCTIONS_AVAILABLE" == "true" ]]; then
                echo "👥 Ajout d'un client avec restrictions de ports"
                read -p "Nom du client: " client_name
                echo ""
                echo "Collez la clé SSH publique du client:"
                echo -e "${CYAN}Format attendu: ssh-ed25519 AAAAC3Nz... user@host${NC}"
                read -p "> " client_ssh_key
                
                if [[ "$client_ssh_key" =~ ssh-ed25519[[:space:]]+([A-Za-z0-9+/=]+) ]]; then
                    local ssh_pubkey="${BASH_REMATCH[1]}"
                    echo ""
                    add_client "$client_name" "$ssh_pubkey"
                else
                    echo -e "${RED}❌ Format de clé SSH invalide${NC}"
                fi
            fi
            ;;
        3)
            if [[ "$WG_FUNCTIONS_AVAILABLE" == "true" ]]; then
                echo "🔓 Ajout d'un client (accès complet)"
                read -p "Nom du client: " client_name
                echo "Collez la clé SSH publique du client:"
                read -p "> " client_ssh_key
                
                if [[ "$client_ssh_key" =~ ssh-ed25519[[:space:]]+([A-Za-z0-9+/=]+) ]]; then
                    local ssh_pubkey="${BASH_REMATCH[1]}"
                    # Simulation d'input "all" pour accès complet
                    echo "all" | add_client "$client_name" "$ssh_pubkey"
                else
                    echo -e "${RED}❌ Format de clé SSH invalide${NC}"
                fi
            else
                echo "📋 Configuration WireGuard:"
                sudo wg show wg0 2>/dev/null || echo "❌ WireGuard non configuré"
            fi
            ;;
        4)
            echo "📋 Configuration WireGuard détaillée:"
            echo ""
            echo -e "${CYAN}=== Interface ===${NC}"
            sudo wg show wg0 2>/dev/null || echo "❌ WireGuard non configuré"
            echo ""
            echo -e "${CYAN}=== Configuration complète ===${NC}"
            if [[ -f /etc/wireguard/wg0.conf ]]; then
                sudo cat /etc/wireguard/wg0.conf | grep -v "PrivateKey"
            else
                echo "❌ Fichier de configuration non trouvé"
            fi
            echo ""
            echo -e "${CYAN}=== Règles iptables ===${NC}"
            sudo iptables -L FORWARD | grep -E "wg0|10\.99\.99" || echo "Aucune règle spécifique"
            ;;
        5)
            echo "🔄 Redémarrage WireGuard..."
            sudo systemctl restart wg-quick@wg0 2>/dev/null
            if systemctl is-active --quiet wg-quick@wg0; then
                echo -e "${GREEN}✅ Service redémarré avec succès${NC}"
            else
                echo -e "${RED}❌ Erreur lors du redémarrage${NC}"
            fi
            ;;
        6)
            if [[ "$WG_FUNCTIONS_AVAILABLE" == "true" && -x "${MY_PATH}/wg-client-setup.sh" ]]; then
                echo "🛠️  Configuration client (ce node)..."
                "${MY_PATH}/wg-client-setup.sh"
            else
                echo -e "${RED}❌ Script wg-client-setup.sh non disponible${NC}"
            fi
            ;;
        7)
            if [[ "$WG_FUNCTIONS_AVAILABLE" == "true" ]]; then
                echo "📤 Génération QR Code pour client"
                read -p "Nom du client: " client_name
                local client_conf="$HOME/.zen/wireguard/${client_name}.conf"
                if [[ -f "$client_conf" ]]; then
                    if command -v qrencode >/dev/null; then
                        qrencode -t ansiutf8 < "$client_conf"
                        echo ""
                        echo -e "${GREEN}✅ QR Code généré pour $client_name${NC}"
                        echo "Configuration également disponible dans: $client_conf"
                    else
                        echo -e "${YELLOW}⚠️ qrencode non installé. Installation recommandée:${NC}"
                        echo "sudo apt install qrencode"
                        echo ""
                        echo "Configuration manuelle disponible dans: $client_conf"
                    fi
                else
                    echo -e "${RED}❌ Configuration client '$client_name' non trouvée${NC}"
                    echo "Clients disponibles:"
                    ls "$HOME/.zen/wireguard/"*.conf 2>/dev/null | xargs -n1 basename | sed 's/.conf$//' | sed 's/^/  - /' || echo "  Aucun"
                fi
            fi
            ;;
    esac
    
    [[ $wg_choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE..."; }
}

#######################################################################
# Gestion Swarm
#######################################################################

manage_swarm() {
    clear
    print_header "🔗 GESTION SWARM UPLANET"
    
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
# Configuration
#######################################################################

manage_config() {
    clear
    print_header "⚙️  CONFIGURATION"
    
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
# Boucle principale améliorée
#######################################################################

main_loop() {
    while true; do
        show_main_menu
        read -p "Votre choix: " choice
        
        case $choice in
            1) show_detailed_monitoring ;;
            2) manage_wireguard ;;
            3) manage_swarm ;;
            4) manage_config ;;
            5) show_guide ;;
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