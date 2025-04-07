#!/bin/bash
# Client WG-SSH Setup - Configure WireGuard à partir des clés SSH client

CONFIG_DIR="$HOME/.zen/wireguard/wg-ssh-client"
mkdir -p "$CONFIG_DIR"

# Fonction de conversion SSH vers WireGuard
ssh_to_wg() {
    echo "$1" | base64 -d | tail -c +12 | head -c 32 | base64 | tr -d '\n'
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

# Configuration interactive
interactive_setup() {
    echo -e "\n=== Configuration Client WireGuard ==="

    # Demander les infos de connexion
    read -p "Adresse du serveur (IP ou domaine) : " SERVER_ENDPOINT
    read -p "Port du serveur [51820] : " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-51820}

    read -p "Clé publique du serveur : " SERVER_PUBKEY
    read -p "Adresse IP VPN attribuée (ex: 10.99.99.2/32) : " CLIENT_IP

    # Convertir la clé privée SSH
    echo -e "\n🔐 Conversion de la clé SSH en clé WireGuard..."
    awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1; next} /END OPENSSH PRIVATE KEY/{flag=0} flag' ~/.ssh/id_ed25519 \
        | base64 -d | tail -c +16 | head -c 32 | base64 | tr -d '\n' > "$CONFIG_DIR/client.priv"
    chmod 600 "$CONFIG_DIR/client.priv"

    # Convertir la clé publique SSH
    CLIENT_PUBKEY=$(ssh_to_wg "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)")

    # Générer la configuration WireGuard
    WG_CONFIG="/etc/wireguard/wg0.conf"
    echo "📁 Génération de la configuration dans $WG_CONFIG"

    sudo bash -c "cat > $WG_CONFIG <<EOF
[Interface]
PrivateKey = $(cat "$CONFIG_DIR/client.priv")
Address = $CLIENT_IP
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_ENDPOINT:$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF"

    # Démarrer le service
    echo "🚀 Activation du service WireGuard..."
    sudo systemctl enable --now wg-quick@wg0

    # Afficher le résumé
    echo -e "\n✅ Configuration terminée !"
    echo "🔑 Votre clé publique client : $CLIENT_PUBKEY"
    echo "📋 Vous pouvez vérifier la connexion avec : sudo wg show"
}

# Version automatique (pour déploiement scripté)
auto_setup() {
    SERVER_ENDPOINT=$1
    SERVER_PORT=${2:-51820}
    SERVER_PUBKEY=$3
    CLIENT_IP=$4

    # Conversion des clés
    awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1; next} /END OPENSSH PRIVATE KEY/{flag=0} flag' ~/.ssh/id_ed25519 \
        | base64 -d | tail -c +16 | head -c 32 | base64 | tr -d '\n' > "$CONFIG_DIR/client.priv"
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
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF"

    sudo systemctl enable --now wg-quick@wg0
    echo "Configuration automatique terminée. Clé publique client : $(ssh_to_wg "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)")"
}

# Mode d'utilisation
if [[ $# -ge 4 ]]; then
    auto_setup "$1" "$2" "$3" "$4"
else
    check_deps
    interactive_setup
fi
