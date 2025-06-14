#!/bin/bash
# WG-SSH Manager - Gestion WireGuard pour Steam Link

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

# Fonction de conversion SSH vers WireGuard
ssh_to_wg() {
    echo "$1" | base64 -d | tail -c +12 | head -c 32 | base64 | tr -d '\n'
}

# Conversion des clés SSH existantes
convert_ssh_keys() {
    # Clé privée
    awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1; next} /END OPENSSH PRIVATE KEY/{flag=0} flag' ~/.ssh/id_ed25519 \
        | base64 -d | tail -c +16 | head -c 32 | base64 | tr -d '\n' > "$CONFIG_DIR/server.priv"

    # Clé publique
    ssh_to_wg "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)" > "$CONFIG_DIR/server.pub"

    chmod 600 "$CONFIG_DIR/server.priv"
}

# Configuration serveur
setup_server() {
    local SERVER_CONF="/etc/wireguard/wg0.conf"
    local SERVER_PORT=51820
    local NETWORK="10.99.99.0/24"

    print_section "CONFIGURATION DU SERVEUR STEAM LINK"
    echo "🚀 Initialisation du serveur WireGuard..."
    
    convert_ssh_keys

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
}

# Ajout d'un client Steam Link
add_steam_client() {
    local CLIENT_NAME="$1"
    local CLIENT_SSH_PUBKEY="$2"
    local SERVER_CONF="/etc/wireguard/wg0.conf"
    local NETWORK="10.99.99.0/24"

    print_section "AJOUT D'UN CLIENT STEAM LINK"
    echo "👤 Client: $CLIENT_NAME"
    
    # Conversion de la clé SSH client
    local CLIENT_WG_PUBKEY=$(ssh_to_wg "$CLIENT_SSH_PUBKEY")

    # Vérification existence
    if grep -q "$CLIENT_WG_PUBKEY" "$SERVER_CONF"; then
        echo -e "${YELLOW}⚠️ Ce client est déjà configuré${NC}"
        return 1
    fi

    # Trouver le prochain IP
    local NEXT_IP=$(($(sudo grep -oP "${NETWORK%.*}\.\K\d+" "$SERVER_CONF" | sort -n | tail -1 || echo 1) + 1))
    local CLIENT_IP="${NETWORK%.*}.$NEXT_IP"

    # Configuration des ports Steam Link
    local STEAM_PORTS="tcp/27036,tcp/27037,tcp/27031,tcp/27030,udp/27036,udp/27037"
    
    echo -e "\n${WHITE}Configuration des ports Steam Link:${NC}"
    echo "  • TCP 27036,27037,27031,27030"
    echo "  • UDP 27036,27037"
    
    local IPTABLES_RULES=""
    local POSTUP_RULES=""
    local POSTDOWN_RULES=""

    # Ajout des règles pour les ports Steam
    IFS=',' read -ra ports_list <<< "$STEAM_PORTS"
    for port_spec in "${ports_list[@]}"; do
        local proto=$(echo "$port_spec" | cut -d'/' -f1)
        local port=$(echo "$port_spec" | cut -d'/' -f2)
        IPTABLES_RULES+="# Autorisation Steam $proto/$port pour $CLIENT_NAME ($CLIENT_IP)\n"
        IPTABLES_RULES+="iptables -I FORWARD -i wg0 -s $CLIENT_IP -p $proto --dport $port -j ACCEPT\n"
        POSTUP_RULES+="$IPTABLES_RULES"
        POSTDOWN_RULES+="iptables -D FORWARD -i wg0 -s $CLIENT_IP -p $proto --dport $port -j ACCEPT\n"
    done

    # Règle de DROP par défaut
    IPTABLES_RULES+="# Refus par défaut pour les autres ports pour $CLIENT_NAME ($CLIENT_IP)\n"
    IPTABLES_RULES+="iptables -I FORWARD -i wg0 -s $CLIENT_IP -j DROP\n"
    POSTUP_RULES+="$IPTABLES_RULES"
    POSTDOWN_RULES+="iptables -D FORWARD -i wg0 -s $CLIENT_IP -j DROP\n"

    # Ajout au serveur
    echo -e "\n[Peer]
# $CLIENT_NAME (Steam Link)
PublicKey = $CLIENT_WG_PUBKEY
AllowedIPs = $CLIENT_IP/32" | sudo tee -a "$SERVER_CONF" > /dev/null

    # Mise à jour PostUp et PostDown
    sudo sed -i "/^PostUp = iptables -A FORWARD -i %i -j ACCEPT;/a\\
### Règles Steam pour $CLIENT_NAME ($CLIENT_IP) START ###\n$POSTUP_RULES### Règles Steam pour $CLIENT_NAME ($CLIENT_IP) END ###" "$SERVER_CONF"

    sudo sed -i "/^PostDown = iptables -D FORWARD -i %i -j ACCEPT;/a\\
### Suppression des règles Steam pour $CLIENT_NAME ($CLIENT_IP) START ###\n$POSTDOWN_RULES### Suppression des règles Steam pour $CLIENT_NAME ($CLIENT_IP) END ###" "$SERVER_CONF"

    # Génération config client
    local CLIENT_CONF="$CONFIG_DIR/${CLIENT_NAME}_steam.conf"
    cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = _FROMYOURSSH_
Address = $CLIENT_IP/32
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $(cat "$CONFIG_DIR/server.pub")
Endpoint = $(curl -s ifconfig.me):$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    # Appliquer la configuration
    sudo wg syncconf wg0 <(wg-quick strip wg0)

    echo -e "\n${GREEN}✅ Configuration Steam Link générée${NC}"
    echo -e "${WHITE}📋 Fichier:${NC} $CLIENT_CONF"
    echo -e "${WHITE}🔑 Clé serveur:${NC} $(cat "$CONFIG_DIR/server.pub")"
    echo -e "${WHITE}🌐 Endpoint:${NC} $(curl -s ifconfig.me):$SERVER_PORT"
    echo -e "\n${YELLOW}📤 Pour envoyer au client:${NC}"
    echo "scp $CLIENT_CONF ${CLIENT_NAME}:~/steam_link.conf"
}

# Interface interactive
show_menu() {
    while true; do
        clear
        print_header "STEAM LINK MANAGER"
        
        echo -e "${WHITE}État du serveur:${NC}"
        if systemctl is-active --quiet wg-quick@wg0; then
            print_status "WireGuard" "ACTIVE" "($(sudo wg show wg0 | grep -c "peer:" || echo "0") clients)"
        else
            print_status "WireGuard" "INACTIVE" ""
        fi
        
        echo -e "\n${CYAN}MENU PRINCIPAL${NC}"
        echo "1. 🚀 Initialiser serveur Steam Link"
        echo "2. 👥 Ajouter un client Steam Link"
        echo "3. 📋 Liste des clients"
        echo "4. 🔄 Redémarrer service"
        echo "5. ❌ Quitter"
        echo ""
        read -p "Choix : " choice

        case $choice in
            1) setup_server ;;
            2)
                read -p "Nom du client : " name
                echo -e "${YELLOW}Collez la clé publique SSH du client:${NC}"
                read -p "> " pubkey
                add_steam_client "$name" "$pubkey"
                ;;
            3)
                print_section "CLIENTS CONNECTÉS"
                echo -e "${WHITE}Configuration serveur:${NC}"
                sudo wg show wg0
                echo -e "\n${WHITE}Clients configurés:${NC}"
                sudo grep -A3 "\[Peer\]" /etc/wireguard/wg0.conf || echo "Aucun client configuré"
                ;;
            4) 
                echo "🔄 Redémarrage du service..."
                sudo systemctl restart wg-quick@wg0
                echo -e "${GREEN}✅ Service redémarré${NC}"
                ;;
            5) exit 0 ;;
            *) echo -e "${RED}❌ Option invalide${NC}" ;;
        esac
        
        [[ $choice != "5" ]] && { echo ""; read -p "Appuyez sur ENTRÉE pour continuer..."; }
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
