#!/bin/bash
# WG-SSH Manager - Gestion WireGuard basée sur les clés SSH existantes

CONFIG_DIR="$HOME/.zen/wireguard"
mkdir -p "$CONFIG_DIR"

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

    convert_ssh_keys

    echo "[Interface]
Address = ${NETWORK%.*}.1/24
ListenPort = $SERVER_PORT
PrivateKey = $(cat "$CONFIG_DIR/server.priv")
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
" | sudo tee "$SERVER_CONF" > /dev/null

    sudo systemctl enable --now wg-quick@wg0
    echo "✅ Serveur configuré avec les clés SSH existantes"
}

# Ajout d'un client
add_client() {
    local CLIENT_NAME="$1"
    local CLIENT_SSH_PUBKEY="$2"
    local SERVER_CONF="/etc/wireguard/wg0.conf"
    local NETWORK="10.99.99.0/24"

    # Conversion de la clé SSH client
    local CLIENT_WG_PUBKEY=$(ssh_to_wg "$CLIENT_SSH_PUBKEY")

    # Vérification existence
    if grep -q "$CLIENT_WG_PUBKEY" "$SERVER_CONF"; then
        echo "⚠️ Ce client est déjà configuré"
        return 1
    fi

    # Trouver le prochain IP
    local NEXT_IP=$(($(grep -oP "${NETWORK%.*}\.\K\d+" "$SERVER_CONF" | sort -n | tail -1 || echo 1) + 1))

    # Ajout au serveur
    echo -e "\n[Peer]
# $CLIENT_NAME
PublicKey = $CLIENT_WG_PUBKEY
AllowedIPs = ${NETWORK%.*}.$NEXT_IP/32" | sudo tee -a "$SERVER_CONF" > /dev/null

    # Génération config client
    local CLIENT_CONF="$CONFIG_DIR/${CLIENT_NAME}.conf"
    cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $(wg genkey | tee "$CONFIG_DIR/${CLIENT_NAME}.priv")
Address = ${NETWORK%.*}.$NEXT_IP/32
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $(cat "$CONFIG_DIR/server.pub")
Endpoint = $(curl -s ifconfig.me):$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    # Appliquer la configuration
    sudo wg syncconf wg0 <(wg-quick strip wg0)

    echo -e "\n📋 Configuration client générée : $CLIENT_CONF"
    echo "🔑 Clé publique serveur : $(cat "$CONFIG_DIR/server.pub")"
    echo "📤 Pour envoyer : scp $CLIENT_CONF ${CLIENT_NAME}:~/wg0.conf"
    echo "🌐 Le client se connectera à : $(curl -s ifconfig.me):$SERVER_PORT"
}

# Interface interactive
show_menu() {
    while true; do
        echo -e "\n=== WG-SSH Manager ==="
        echo "1. Initialiser le serveur (utilise les clés SSH existantes)"
        echo "2. Ajouter un client via sa clé SSH publique"
        echo "3. Afficher la configuration actuelle"
        echo "4. Redémarrer le service"
        echo "5. Quitter"
        read -p "Choix : " choice

        case $choice in
            1) setup_server ;;
            2)
                read -p "Nom du client : " name
                echo "Collez la clé publique SSH du client (format: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...):"
                read -p "> " pubkey
                add_client "$name" "$pubkey"
                ;;
            3)
                echo -e "\n🔧 Configuration serveur :"
                sudo wg show wg0
                echo -e "\n📜 Fichier de configuration :"
                sudo grep -A3 "\[Peer\]" /etc/wireguard/wg0.conf || echo "Aucun client configuré"
                ;;
            4) sudo systemctl restart wg-quick@wg0 ;;
            5) exit 0 ;;
            *) echo "Option invalide" ;;
        esac
    done
}

# Vérification des dépendances
check_deps() {
    for cmd in wg curl; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "❌ Veuillez installer $cmd avant de continuer"
            exit 1
        fi
    done
}

check_deps
show_menu
