#!/bin/bash
# Client WG-SSH Setup - Configure WireGuard à partir des clés SSH client

CONFIG_DIR="/etc/wireguard"
KEYS_DIR="/etc/wireguard/keys"
sudo mkdir -p "$KEYS_DIR"
sudo chmod 700 "$KEYS_DIR"

# Génération des clés WireGuard natives
generate_wg_keys() {
    # Générer une nouvelle clé privée WireGuard
    wg genkey | sudo tee "$KEYS_DIR/client.priv" > /dev/null
    
    # Générer la clé publique correspondante
    sudo cat "$KEYS_DIR/client.priv" | wg pubkey | sudo tee "$KEYS_DIR/client.pub" > /dev/null
    
    sudo chmod 600 "$KEYS_DIR/client.priv"
    echo -e "${GREEN}✅ Clés WireGuard générées${NC}"
}

# Vérification des dépendances
check_deps() {
    for cmd in wg curl systemctl sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "❌ Veuillez installer $cmd avant de continuer"
            exit 1
        fi
    done
}

# Vérification de WireGuard
check_wireguard() {
    if ! command -v wg &> /dev/null; then
        echo "❌ WireGuard n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    fi
}

# Configuration interactive
interactive_setup() {
    echo -e "\n=== Configuration Client WireGuard ==="

    # Demander les infos de connexion
    read -p "Adresse du serveur (IP ou domaine) : " SERVER_ENDPOINT
    read -p "Port du serveur [51820] : " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-51820}

    read -p "Clé publique du serveur : " SERVER_PUBKEY
    read -p "Adresse IP VPN attribuée (ex: 10.99.99.2/32) : " CLIENT_IP

    # Validation des entrées
    if [[ -z "$SERVER_ENDPOINT" || -z "$SERVER_PUBKEY" || -z "$CLIENT_IP" ]]; then
        echo "❌ Toutes les informations sont requises"
        exit 1
    fi

    # Générer les clés WireGuard
    echo -e "\n🔐 Génération des clés WireGuard..."
    generate_wg_keys

    # Obtenir la clé publique client
    CLIENT_PUBKEY=$(sudo cat "$KEYS_DIR/client.pub")

    # Générer la configuration WireGuard
    WG_CONFIG="/etc/wireguard/wg0.conf"
    echo "📁 Génération de la configuration dans $WG_CONFIG"

    # Sauvegarder l'ancienne config si elle existe
    if [[ -f "$WG_CONFIG" ]]; then
        echo "⚠️ Configuration existante détectée. Sauvegarde..."
        sudo cp "$WG_CONFIG" "${WG_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    sudo bash -c "cat > $WG_CONFIG <<EOF
[Interface]
PrivateKey = \$(cat $KEYS_DIR/client.priv)
Address = $CLIENT_IP
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_ENDPOINT:$SERVER_PORT
AllowedIPs = 10.99.99.0/24
PersistentKeepalive = 25
EOF"

    # Démarrer le service
    echo "🚀 Activation du service WireGuard..."
    sudo systemctl enable --now wg-quick@wg0

    # Afficher le résumé
    echo -e "\n✅ Configuration terminée !"
    echo "🔑 Votre clé publique client : $CLIENT_PUBKEY"
    echo "📋 Vous pouvez vérifier la connexion avec : sudo wg show"
    echo "🌐 Test de connectivité : ping 10.99.99.1"
}

# Version automatique (pour déploiement scripté)
auto_setup() {
    SERVER_ENDPOINT=$1
    SERVER_PORT=${2:-51820}
    SERVER_PUBKEY=$3
    CLIENT_IP=$4

    # Validation des paramètres
    if [[ -z "$SERVER_ENDPOINT" || -z "$SERVER_PUBKEY" || -z "$CLIENT_IP" ]]; then
        echo "❌ Usage: $0 auto <endpoint> [port] <pubkey> <client_ip>"
        exit 1
    fi

    echo "🚀 Configuration automatique WireGuard..."
    echo "   Serveur: $SERVER_ENDPOINT:$SERVER_PORT"
    echo "   IP client: $CLIENT_IP"

    # Génération des clés WireGuard
    generate_wg_keys

    # Génération config
    sudo bash -c "cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = \$(cat $KEYS_DIR/client.priv)
Address = $CLIENT_IP
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_ENDPOINT:$SERVER_PORT
AllowedIPs = 10.99.99.0/24
PersistentKeepalive = 25
EOF"

    sudo systemctl enable --now wg-quick@wg0
    echo "✅ Configuration automatique terminée."
    echo "🔑 Clé publique client : $(sudo cat "$KEYS_DIR/client.pub")"
    echo "🌐 Test de connectivité : ping 10.99.99.1"
}

# Mode d'utilisation
if [[ $# -ge 5 ]] && [[ "$1" == "auto" ]]; then
    check_deps
    check_wireguard
    auto_setup "$2" "$3" "$4" "$5"
elif [[ $# -ge 4 ]]; then
    check_deps
    check_wireguard
    auto_setup "$1" "$2" "$3" "$4"
else
    check_deps
    check_wireguard
    interactive_setup
fi
