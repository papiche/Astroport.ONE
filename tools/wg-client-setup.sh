#!/bin/bash
# wg-client-setup.sh
# Client WG-SSH Setup - Configure WireGuard et IPFS au travers du VPN
umask 077

# ==========================================
# VARIABLES GLOBALES
# ==========================================
WG_IFACE="wg0"
CONFIG_DIR="/etc/wireguard"
KEYS_DIR="/etc/wireguard/keys"
WG_CONFIG="$CONFIG_DIR/$WG_IFACE.conf"
DNS_SERVERS="1.1.1.1, 2606:4700:4700::1111"

# ==========================================
# COULEURS
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

sudo mkdir -p "$KEYS_DIR"
sudo chmod 700 "$KEYS_DIR"

# Vérification des dépendances
check_deps() {
    for cmd in wg curl systemctl sudo awk; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}❌ Veuillez installer $cmd avant de continuer${NC}"
            exit 1
        fi
    done
}

# Génération des clés WireGuard natives
generate_wg_keys() {
    wg genkey | sudo tee "$KEYS_DIR/client.priv" > /dev/null
    sudo cat "$KEYS_DIR/client.priv" | wg pubkey | sudo tee "$KEYS_DIR/client.pub" > /dev/null
    sudo chmod 600 "$KEYS_DIR/client.priv"
}

# Calcul du port IPFS selon l'IP (ex: 10.99.99.2 -> 4002)
get_ipfs_port() {
    local ip=$1
    # On retire le /32 s'il existe pour récupérer le dernier octet
    local clean_ip=$(echo "$ip" | cut -d'/' -f1)
    local last_octet=$(echo "$clean_ip" | awk -F. '{print $4}')
    echo $((4000 + last_octet))
}

# Affichage des instructions IPFS
print_ipfs_instructions() {
    local endpoint=$1
    local ip=$2
    local ipfs_port=$(get_ipfs_port "$ip")
    # On enlève le port WireGuard de l'endpoint pour ne garder que l'IP
    local server_ip=$(echo "$endpoint" | cut -d':' -f1)

    echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}🌐 CONFIGURATION IPFS POUR CONTOURNER LE CGNAT${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "Grâce au VPN, ce client est accessible de l'extérieur via le port : ${YELLOW}$ipfs_port${NC}"
    echo -e "Exécutez cette commande sur cette machine pour configurer IPFS :\n"
    echo -e "${GREEN}ipfs config --json Addresses.Announce '[\"/ip4/$server_ip/tcp/$ipfs_port\"]'${NC}\n"
    echo -e "Puis redémarrez votre daemon IPFS."
}

# Configuration interactive
interactive_setup() {
    echo -e "\n${BLUE}=== Configuration Client WireGuard ===${NC}"

    read -p "Adresse du serveur (IP ou domaine) : " SERVER_ENDPOINT
    read -p "Port du serveur [51820] : " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-51820}

    read -p "Clé publique du serveur : " SERVER_PUBKEY
    read -p "Adresse IP VPN attribuée (ex: 10.99.99.2) : " CLIENT_IP

    if [[ -z "$SERVER_ENDPOINT" || -z "$SERVER_PUBKEY" || -z "$CLIENT_IP" ]]; then
        echo -e "${RED}❌ Toutes les informations sont requises${NC}"
        exit 1
    fi

    # (À ajouter dans la fonction interactive_setup de wg-client-setup.sh)
    echo -e "\nQuel est l'usage principal de ce client ?"
    echo "1) Nœud IPFS Astroport (Route tout internet par le VPN - Recommandé)"
    echo "2) Uniquement Steam Link / LAN (Garde la connexion internet locale)"
    read -p "Choix [1] : " ROUTE_CHOICE
    
    if [[ "$ROUTE_CHOICE" == "2" ]]; then
        CLIENT_ALLOWED_IPS="10.99.99.0/24"
    else
        CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0"
    fi
    
    # S'assurer que l'IP se termine par /32
    if [[ ! "$CLIENT_IP" == */* ]]; then
        CLIENT_IP="$CLIENT_IP/32"
    fi

    echo -e "\n🔐 Génération des clés WireGuard..."
    generate_wg_keys
    local CLIENT_PUBKEY=$(sudo cat "$KEYS_DIR/client.pub")

    echo "📁 Génération de la configuration dans $WG_CONFIG"
    if [[ -f "$WG_CONFIG" ]]; then
        echo -e "${YELLOW}⚠️ Configuration existante détectée. Sauvegarde...${NC}"
        sudo cp "$WG_CONFIG" "${WG_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Génération du fichier avec route par défaut
    sudo bash -c "cat > $WG_CONFIG <<EOF
[Interface]
PrivateKey = \$(cat $KEYS_DIR/client.priv)
Address = $CLIENT_IP
DNS = $DNS_SERVERS

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_ENDPOINT:$SERVER_PORT
AllowedIPs = $CLIENT_ALLOWED_IPS
PersistentKeepalive = 25
EOF"

    echo "🚀 Activation du service WireGuard..."
    sudo systemctl enable --now wg-quick@$WG_IFACE

    echo -e "\n${GREEN}✅ Configuration terminée !${NC}"
    echo -e "🔑 Votre clé publique client : ${WHITE}$CLIENT_PUBKEY${NC}\n"
    echo -e "${YELLOW}📤 IMPORTANT: Fournissez cette clé publique au serveur s'il ne l'a pas encore.${NC}"
    echo "📋 Vérifier la connexion : sudo wg show"
    echo "🌐 Test de connectivité  : ping 10.99.99.1"

    print_ipfs_instructions "$SERVER_ENDPOINT" "$CLIENT_IP"
}

# Version automatique (pour déploiement scripté)
auto_setup() {
    local SERVER_ENDPOINT=$1
    local SERVER_PORT=${2:-51820}
    local SERVER_PUBKEY=$3
    local CLIENT_IP=$4

    if [[ -z "$SERVER_ENDPOINT" || -z "$SERVER_PUBKEY" || -z "$CLIENT_IP" ]]; then
        echo -e "${RED}❌ Usage: $0 auto <endpoint> [port] <pubkey> <client_ip>${NC}"
        exit 1
    fi

    if [[ ! "$CLIENT_IP" == */* ]]; then
        CLIENT_IP="$CLIENT_IP/32"
    fi

    echo -e "🚀 Configuration automatique WireGuard..."
    echo "   Serveur: $SERVER_ENDPOINT:$SERVER_PORT"
    echo "   IP client: $CLIENT_IP"

    generate_wg_keys

    sudo bash -c "cat > $WG_CONFIG <<EOF
[Interface]
PrivateKey = \$(cat $KEYS_DIR/client.priv)
Address = $CLIENT_IP
DNS = $DNS_SERVERS

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_ENDPOINT:$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF"
    
    sudo systemctl enable --now wg-quick@$WG_IFACE
    echo -e "${GREEN}✅ Configuration automatique terminée.${NC}"
    
    print_ipfs_instructions "$SERVER_ENDPOINT" "$CLIENT_IP"
}

# Génération de QR code pour configuration existante
generate_qr() {
    local CONFIG_FILE="$WG_CONFIG"
    
    if ! command -v qrencode &> /dev/null; then
        echo -e "${RED}❌ qrencode n'est pas installé${NC}"
        echo "   Installez-le avec: sudo apt install qrencode"
        exit 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Aucune configuration WireGuard trouvée dans $CONFIG_FILE${NC}"
        
        local client_configs=($(sudo find /etc/wireguard -name "*_lan.conf" 2>/dev/null))
        if [[ ${#client_configs[@]} -eq 0 ]]; then
            echo -e "   Exécutez d'abord la configuration avec: $0"
            exit 1
        fi
        
        echo -e "\n📋 Configurations client trouvées:"
        for i in "${!client_configs[@]}"; do
            echo "  $((i+1)). ${client_configs[$i]}"
        done
        echo ""
        read -p "Sélectionnez une configuration (numéro) : " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#client_configs[@]} ]]; then
            CONFIG_FILE="${client_configs[$((choice-1))]}"
        else
            echo -e "${RED}❌ Sélection invalide${NC}"
            exit 1
        fi
    fi
    
    echo -e "\n${CYAN}📱 Configuration WireGuard ($CONFIG_FILE):${NC}"
    sudo cat "$CONFIG_FILE"
    echo -e "\n${CYAN}QR Code (scannez avec l'application WireGuard):${NC}"
    sudo cat "$CONFIG_FILE" | qrencode -t ansiutf8
}

# Point d'entrée du script
check_deps

if [[ $# -ge 1 ]] && [[ "$1" == "qr" ]]; then
    generate_qr
elif [[ $# -ge 5 ]] && [[ "$1" == "auto" ]]; then
    auto_setup "$2" "$3" "$4" "$5"
elif [[ $# -ge 4 ]] && [[ "$1" == "auto" ]]; then
    auto_setup "$2" "51820" "$3" "$4"
else
    interactive_setup
fi