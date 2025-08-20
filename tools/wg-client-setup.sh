#!/bin/bash
# Client WG-SSH Setup - Configure WireGuard à partir des clés SSH client

CONFIG_DIR="$HOME/.zen/wireguard/wg-ssh-client"
mkdir -p "$CONFIG_DIR"

# Fonction de conversion SSH vers WireGuard (corrigée)
ssh_to_wg() {
    local ssh_key="$1"
    # Extract the base64 part and decode, then take the last 32 bytes
    echo "$ssh_key" | base64 -d | tail -c 32 | base64 | tr -d '\n'
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

# Vérification des clés SSH
check_ssh_keys() {
    if [[ ! -f ~/.ssh/id_ed25519 ]] || [[ ! -f ~/.ssh/id_ed25519.pub ]]; then
        echo "❌ Clés SSH non trouvées. Veuillez générer des clés SSH d'abord:"
        echo "   ssh-keygen -t ed25519"
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

    # Convertir la clé privée SSH
    echo -e "\n🔐 Conversion de la clé SSH en clé WireGuard..."
    awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1; next} /END OPENSSH PRIVATE KEY/{flag=0} flag' ~/.ssh/id_ed25519 \
        | base64 -d | tail -c 32 | base64 | tr -d '\n' > "$CONFIG_DIR/client.priv"
    chmod 600 "$CONFIG_DIR/client.priv"

    # Convertir la clé publique SSH
    CLIENT_PUBKEY=$(ssh_to_wg "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)")

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
PrivateKey = $(cat "$CONFIG_DIR/client.priv")
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

    # Conversion des clés
    awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1; next} /END OPENSSH PRIVATE KEY/{flag=0} flag' ~/.ssh/id_ed25519 \
        | base64 -d | tail -c 32 | base64 | tr -d '\n' > "$CONFIG_DIR/client.priv"
    chmod 600 "$CONFIG_DIR/client.priv"

    # Génération config
    sudo bash -c "cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(cat "$CONFIG_DIR/client.priv")
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
    echo "🔑 Clé publique client : $(ssh_to_wg "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)")"
    echo "🌐 Test de connectivité : ping 10.99.99.1"
}

# Mode d'utilisation
if [[ $# -ge 5 ]] && [[ "$1" == "auto" ]]; then
    check_deps
    check_ssh_keys
    auto_setup "$2" "$3" "$4" "$5"
elif [[ $# -ge 4 ]]; then
    check_deps
    check_ssh_keys
    auto_setup "$1" "$2" "$3" "$4"
else
    check_deps
    check_ssh_keys
    interactive_setup
fi
