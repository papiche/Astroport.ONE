#!/bin/bash
# WG-SSH Manager - Gestion WireGuard pour LAN

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

CONFIG_DIR="$HOME/.zen/wireguard"
mkdir -p "$CONFIG_DIR"

print_header() {
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

# Fonction de conversion SSH vers WireGuard (corrigée)
ssh_to_wg() {
    local ssh_key="$1"
    # Extract the base64 part and decode, then take the last 32 bytes
    echo "$ssh_key" | base64 -d | tail -c 32 | base64 | tr -d '\n'
}

# Conversion des clés SSH existantes (corrigée)
convert_ssh_keys() {
    # Clé privée - prendre les 32 derniers bytes
    awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1; next} /END OPENSSH PRIVATE KEY/{flag=0} flag' ~/.ssh/id_ed25519 \
        | base64 -d | tail -c 32 | base64 | tr -d '\n' > "$CONFIG_DIR/server.priv"

    # Clé publique - extraire la partie base64 et convertir
    local ssh_pubkey=$(awk '{print $2}' ~/.ssh/id_ed25519.pub)
    ssh_to_wg "$ssh_pubkey" > "$CONFIG_DIR/server.pub"

    chmod 600 "$CONFIG_DIR/server.priv"
    echo -e "${GREEN}✅ Clés SSH converties en WireGuard${NC}"
}

# Configuration serveur
setup_server() {
    local SERVER_CONF="/etc/wireguard/wg0.conf"
    local SERVER_PORT=51820
    local NETWORK="10.99.99.0/24"

    print_section "CONFIGURATION DU SERVEUR LAN"
    echo "🚀 Initialisation du serveur WireGuard..."
    
    convert_ssh_keys

    # Vérifier si l'interface existe déjà
    if [[ -f "$SERVER_CONF" ]]; then
        echo -e "${YELLOW}⚠️ Configuration existante détectée. Sauvegarde...${NC}"
        sudo cp "$SERVER_CONF" "${SERVER_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    echo "[Interface]
Address = ${NETWORK%.*}.1/24
ListenPort = $SERVER_PORT
PrivateKey = $(cat "$CONFIG_DIR/server.priv")
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
" | sudo tee "$SERVER_CONF" > /dev/null

    sudo systemctl enable --now wg-quick@wg0
    echo -e "${GREEN}✅ Serveur configuré avec succès${NC}"
    echo -e "${WHITE}Port:${NC} $SERVER_PORT"
    echo -e "${WHITE}Réseau:${NC} $NETWORK"
    echo -e "${WHITE}Clé publique serveur:${NC} $(cat "$CONFIG_DIR/server.pub")"
}

# Ajout d'un client LAN
add_lan_client() {
    local CLIENT_NAME="$1"
    local CLIENT_SSH_PUBKEY="$2"
    local SERVER_CONF="/etc/wireguard/wg0.conf"
    local NETWORK="10.99.99.0/24"

    print_section "AJOUT D'UN CLIENT LAN"
    echo "👤 Client: $CLIENT_NAME"
    
    # Conversion de la clé SSH client
    local CLIENT_WG_PUBKEY=$(ssh_to_wg "$CLIENT_SSH_PUBKEY")

    # Vérification existence
    if grep -q "$CLIENT_WG_PUBKEY" "$SERVER_CONF"; then
        echo -e "${YELLOW}⚠️ Ce client est déjà configuré${NC}"
        return 1
    fi

    # Trouver le prochain IP disponible
    local NEXT_IP=2
    while grep -q "AllowedIPs = ${NETWORK%.*}.$NEXT_IP" "$SERVER_CONF"; do
        ((NEXT_IP++))
    done
    local CLIENT_IP="${NETWORK%.*}.$NEXT_IP"

    # Ajout au serveur
    echo -e "\n[Peer]
# $CLIENT_NAME (LAN Client)
PublicKey = $CLIENT_WG_PUBKEY
AllowedIPs = $CLIENT_IP/32" | sudo tee -a "$SERVER_CONF" > /dev/null

    # Génération config client
    local CLIENT_CONF="$CONFIG_DIR/${CLIENT_NAME}_lan.conf"
    cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = _REPLACE_WITH_CLIENT_PRIVATE_KEY_
Address = $CLIENT_IP/32
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $(cat "$CONFIG_DIR/server.pub")
Endpoint = $(curl -s ifconfig.me):$SERVER_PORT
AllowedIPs = $NETWORK
PersistentKeepalive = 25
EOF

    # Appliquer la configuration
    sudo wg syncconf wg0 <(wg-quick strip wg0)

    echo -e "\n${GREEN}✅ Configuration LAN générée${NC}"
    echo -e "${WHITE}📋 Fichier:${NC} $CLIENT_CONF"
    echo -e "${WHITE}🔑 Clé serveur:${NC} $(cat "$CONFIG_DIR/server.pub")"
    echo -e "${WHITE}🌐 Endpoint:${NC} $(curl -s ifconfig.me):$SERVER_PORT"
    echo -e "${WHITE}📱 IP attribuée:${NC} $CLIENT_IP"
    echo -e "\n${YELLOW}📤 Instructions pour le client:${NC}"
    echo "1. Copier le fichier: scp $CLIENT_CONF ${CLIENT_NAME}:~/lan_client.conf"
    echo "2. Sur le client, exécuter: ./wg-client-setup.sh auto $(curl -s ifconfig.me) $SERVER_PORT $(cat "$CONFIG_DIR/server.pub") $CLIENT_IP"
}

# Supprimer un client
remove_client() {
    local CLIENT_NAME="$1"
    local SERVER_CONF="/etc/wireguard/wg0.conf"
    
    print_section "SUPPRESSION D'UN CLIENT"
    
    # Trouver et supprimer le client
    local start_line=$(grep -n "# $CLIENT_NAME" "$SERVER_CONF" | cut -d: -f1)
    if [[ -n "$start_line" ]]; then
        local end_line=$((start_line + 3))
        sudo sed -i "${start_line},${end_line}d" "$SERVER_CONF"
        echo -e "${GREEN}✅ Client $CLIENT_NAME supprimé${NC}"
        
        # Redémarrer le service
        sudo systemctl restart wg-quick@wg0
    else
        echo -e "${RED}❌ Client $CLIENT_NAME non trouvé${NC}"
    fi
}

# Interface interactive
show_menu() {
    while true; do
        clear
        print_header "WIREGUARD LAN MANAGER"
        
        echo -e "${WHITE}État du serveur:${NC}"
        if systemctl is-active --quiet wg-quick@wg0; then
            local client_count=$(sudo wg show wg0 | grep -c "peer:" || echo "0")
            print_status "WireGuard" "ACTIVE" "($client_count clients)"
        else
            print_status "WireGuard" "INACTIVE" ""
        fi
        
        echo -e "\n${CYAN}MENU PRINCIPAL${NC}"
        echo "1. 🚀 Initialiser serveur LAN"
        echo "2. 👥 Ajouter un client LAN"
        echo "3. 🗑️  Supprimer un client"
        echo "4. 📋 Liste des clients"
        echo "5. 🔄 Redémarrer service"
        echo "6. ❌ Quitter"
        echo ""
        read -p "Choix : " choice

        case $choice in
            1) setup_server ;;
            2)
                read -p "Nom du client : " name
                echo -e "${YELLOW}Collez la clé publique SSH du client:${NC}"
                read -p "> " pubkey
                add_lan_client "$name" "$pubkey"
                ;;
            3)
                read -p "Nom du client à supprimer : " name
                remove_client "$name"
                ;;
            4)
                print_section "CLIENTS CONNECTÉS"
                echo -e "${WHITE}Configuration serveur:${NC}"
                sudo wg show wg0
                echo -e "\n${WHITE}Clients configurés:${NC}"
                sudo grep -A3 "\[Peer\]" /etc/wireguard/wg0.conf || echo "Aucun client configuré"
                ;;
            5) 
                echo "🔄 Redémarrage du service..."
                sudo systemctl restart wg-quick@wg0
                echo -e "${GREEN}✅ Service redémarré${NC}"
                ;;
            6) exit 0 ;;
            *) echo -e "${RED}❌ Option invalide${NC}" ;;
        esac
        
        [[ $choice != "6" ]] && { echo ""; read -p "Appuyez sur ENTRÉE pour continuer..."; }
    done
}

# Vérification des dépendances
check_deps() {
    for cmd in wg curl iptables sed grep awk base64 systemctl tee mkdir chmod sort head tail tr command; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}❌ Veuillez installer $cmd avant de continuer${NC}"
            exit 1
        fi
    done
}

check_deps
show_menu
