#!/bin/bash
# wireguard_control.sh
# WG-SSH Manager - Gestion WireGuard pour LAN & IPFS Multi-Noeuds
umask 077

# ==========================================
# VARIABLES GLOBALES
# ==========================================
WG_IFACE="wg0"
WG_PORT="51820"
WG_NET_BASE="10.99.99"
WG_NET="$WG_NET_BASE.0/24"
DNS_SERVERS="1.1.1.1, 2606:4700:4700::1111"

CONFIG_DIR="/etc/wireguard"
KEYS_DIR="/etc/wireguard/keys"
SERVER_CONF="$CONFIG_DIR/$WG_IFACE.conf"
FW_SCRIPT="$CONFIG_DIR/ipfs-fw.sh"

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

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗"
    printf "║%*s║\n" $((78)) ""
    printf "║%*s%s%*s║\n" $(((78-${#1})/2)) "" "$1" $(((78-${#1})/2)) ""
    printf "║%*s║\n" $((78)) ""
    echo -e "╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "│ %-76s │\n" "$1"
    echo -e "└──────────────────────────────────────────────────────────────────────────────┘${NC}"
}

get_wan_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

get_public_ip() {
    local ip=$(curl -4 -s ifconfig.me)
    if [[ -z "$ip" ]]; then ip=$(curl -s ifconfig.me | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1); fi
    echo "$ip"
}

# Génération des clés
generate_wg_keys() {
    wg genkey | sudo tee "$KEYS_DIR/server.priv" > /dev/null
    sudo cat "$KEYS_DIR/server.priv" | wg pubkey | sudo tee "$KEYS_DIR/server.pub" > /dev/null
    sudo chmod 600 "$KEYS_DIR/server.priv"
}

# Création du script Pare-feu dynamique pour IPFS
create_fw_script() {
    sudo bash -c "cat > $FW_SCRIPT <<'EOF'
#!/bin/bash
# Script de routage dynamique IPFS généré par WG-Manager
ACTION=\$1
WAN_IF=\$2
WG_NET_BASE="10.99.99"

if [[ -z "\$WAN_IF" ]]; then exit 1; fi

if [ "\$ACTION" == "up" ]; then
    # Créer une chaine dédiée pour nettoyer facilement plus tard
    iptables -t nat -N WG_IPFS 2>/dev/null || iptables -t nat -F WG_IPFS
    iptables -t nat -C PREROUTING -i \$WAN_IF -j WG_IPFS 2>/dev/null || iptables -t nat -I PREROUTING 1 -i \$WAN_IF -j WG_IPFS
    
    # Lire les IPs configurées dans WireGuard et créer le décalage de port (Port Offset)
    grep -oE "AllowedIPs = \$WG_NET_BASE\.[0-9]+" /etc/wireguard/wg0.conf | grep -oE "[0-9]+$" | while read octet; do
        ext_port=\$((4000 + octet))
        # Redirige IP_PUBLIQUE:400X vers CLIENT_VPN:4001
        iptables -t nat -A WG_IPFS -p tcp --dport \$ext_port -j DNAT --to-destination \$WG_NET_BASE.\$octet:4001
        iptables -t nat -A WG_IPFS -p udp --dport \$ext_port -j DNAT --to-destination \$WG_NET_BASE.\$octet:4001
    done

elif [ "\$ACTION" == "down" ]; then
    iptables -t nat -D PREROUTING -i \$WAN_IF -j WG_IPFS 2>/dev/null
    iptables -t nat -F WG_IPFS 2>/dev/null
    iptables -t nat -X WG_IPFS 2>/dev/null

elif [ "\$ACTION" == "reload" ]; then
    \$0 down \$WAN_IF
    \$0 up \$WAN_IF
fi
EOF"
    sudo chmod +x $FW_SCRIPT
}

# Configuration serveur
setup_server() {
    print_section "CONFIGURATION DU SERVEUR LAN"
    generate_wg_keys

    local WAN_INTERFACE=$(get_wan_interface)
    if [[ -z "$WAN_INTERFACE" ]]; then
        echo -e "${RED}❌ Impossible de détecter l'interface réseau${NC}"; return 1
    fi

    if [[ -f "$SERVER_CONF" ]]; then sudo cp "$SERVER_CONF" "${SERVER_CONF}.backup.$(date +%s)"; fi

    # Activer l'IP forwarding
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-wireguard.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/99-wireguard.conf > /dev/null

    # Créer le sous-script de pare-feu
    create_fw_script

    echo "[Interface]
Address = $WG_NET_BASE.1/24
ListenPort = $WG_PORT
PrivateKey = $(sudo cat "$KEYS_DIR/server.priv")

# Accès Internet
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $WAN_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $WAN_INTERFACE -j MASQUERADE

# Routage Dynamique IPFS Multi-Clients
PostUp = $FW_SCRIPT up $WAN_INTERFACE
PostDown = $FW_SCRIPT down $WAN_INTERFACE
" | sudo tee "$SERVER_CONF" > /dev/null

    sudo systemctl enable --now wg-quick@$WG_IFACE
    echo -e "${GREEN}✅ Serveur configuré avec succès${NC}"
    echo -e "${WHITE}Le serveur IPFS local doit écouter sur le port public 4001.${NC}"
}

# Ajout client
add_lan_client() {
    local CLIENT_NAME="$1"
    local CLIENT_WG_PUBKEY="$2"
    
    if [[ -z "$CLIENT_WG_PUBKEY" ]]; then return 1; fi
    if sudo grep -q "$CLIENT_WG_PUBKEY" "$SERVER_CONF" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Ce client est déjà configuré${NC}"; return 1
    fi

    # Trouver prochaine IP
    local LAST_IP=$(sudo grep -oE "AllowedIPs = $WG_NET_BASE\.[0-9]+" "$SERVER_CONF" 2>/dev/null | grep -oE "[0-9]+$" | sort -n | tail -1)
    if [[ -z "$LAST_IP" ]]; then LAST_IP=1; fi
    local NEXT_IP=$((LAST_IP + 1))
    local CLIENT_IP="$WG_NET_BASE.$NEXT_IP"
    local IPFS_PORT=$((4000 + NEXT_IP))

    echo -e "\n[Peer]
# $CLIENT_NAME
PublicKey = $CLIENT_WG_PUBKEY
AllowedIPs = $CLIENT_IP/32" | sudo tee -a "$SERVER_CONF" > /dev/null

    local SERVER_ENDPOINT=$(get_public_ip)
    local CLIENT_CONF="$CONFIG_DIR/${CLIENT_NAME}_lan.conf"
    
    sudo bash -c "cat > $CLIENT_CONF <<EOF
[Interface]
PrivateKey = _REPLACE_WITH_CLIENT_PRIVATE_KEY_
Address = $CLIENT_IP/32
DNS = $DNS_SERVERS

[Peer]
PublicKey = \$(cat $KEYS_DIR/server.pub)
Endpoint = $SERVER_ENDPOINT:$WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF"

    # Appliquer config WG et recharger Firewall IPFS
    sudo wg syncconf $WG_IFACE <(wg-quick strip $WG_IFACE)
    sudo $FW_SCRIPT reload $(get_wan_interface)

    echo -e "\n${GREEN}✅ Configuration LAN générée${NC}"
    echo -e "${WHITE}📱 IP VPN attribuée :${NC} $CLIENT_IP"
    echo -e "${CYAN}🌐 REDIRECTION IPFS :${NC} Port Public ${YELLOW}$IPFS_PORT${NC} -> $CLIENT_IP:4001"
    echo -e "${WHITE}⚠️  Sur ce client, configurez IPFS avec :${NC}"
    echo "ipfs config --json Addresses.Announce '[\"/ip4/$SERVER_ENDPOINT/tcp/$IPFS_PORT\"]'"
}

# Suppression client
remove_client() {
    print_section "SUPPRESSION D'UN CLIENT"
    
    local clients=()
    while IFS= read -r line; do
        if [[ $line =~ ^#\ (.+)$ ]]; then clients+=("${BASH_REMATCH[1]}"); fi
    done < <(sudo grep "^#" "$SERVER_CONF" 2>/dev/null || echo "")
    
    if [[ ${#clients[@]} -eq 0 ]]; then echo "Aucun client"; return 0; fi
    for i in "${!clients[@]}"; do echo "  $((i+1)). ${clients[$i]}"; done
    
    read -p "Numéro du client : " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le ${#clients[@]} ]]; then
        local CLIENT_NAME="${clients[$((choice-1))]}"
        local start_line=$(grep -n "# $CLIENT_NAME" "$SERVER_CONF" | cut -d: -f1)
        if [[ -n "$start_line" ]]; then
            local end_line=$((start_line + 3))
            sudo sed -i "${start_line},${end_line}d" "$SERVER_CONF"
            
            # Appliquer config WG et recharger Firewall IPFS
            sudo wg syncconf $WG_IFACE <(wg-quick strip $WG_IFACE)
            sudo $FW_SCRIPT reload $(get_wan_interface)
            
            echo -e "${GREEN}✅ Client supprimé et pare-feu mis à jour${NC}"
        fi
    fi
}

# Interface
show_menu() {
    while true; do
        clear
        print_header "WIREGUARD LAN MANAGER - MULTI IPFS"
        
        if systemctl is-active --quiet wg-quick@$WG_IFACE; then
            echo -e "  ✅ WireGuard ${GREEN}ACTIVE${NC}"
        else
            echo -e "  ❌ WireGuard ${RED}INACTIVE${NC}"
        fi
        
        echo -e "\n${CYAN}MENU PRINCIPAL${NC}"
        echo "1. 🚀 Initialiser serveur LAN"
        echo "2. 👥 Ajouter un client LAN"
        echo "3. 🗑️  Supprimer un client"
        echo "4. 🔄 Redémarrer service"
        echo "5. ❌ Quitter"
        echo ""
        read -p "Choix : " choice

        case $choice in
            1) setup_server ;;
            2)
                read -p "Nom du client : " name
                read -p "Clé publique WireGuard du client : " pubkey
                add_lan_client "$name" "$pubkey"
                ;;
            3) remove_client ;;
            4) sudo systemctl restart wg-quick@$WG_IFACE; echo "✅ Fait" ;;
            5) exit 0 ;;
        esac
        [[ $choice != "5" ]] && { echo ""; read -p "Appuyez sur ENTRÉE pour continuer..."; }
    done
}

check_deps() {
    for cmd in wg curl iptables sed grep awk systemctl tee mkdir chmod sort head tail command; do
        if ! command -v "$cmd" &> /dev/null; then echo "❌ Installez $cmd"; exit 1; fi
    done
}

check_deps
show_menu