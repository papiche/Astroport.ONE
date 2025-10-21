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
    echo ""
    echo -e "${YELLOW}📤 IMPORTANT: Copiez cette clé publique et fournissez-la au serveur${NC}"
    echo "   Le serveur a besoin de cette clé pour configurer le client"
    echo ""
    echo "📋 Vous pouvez vérifier la connexion avec : sudo wg show"
    echo "🌐 Test de connectivité : ping 10.99.99.1"
    
    # Proposer de générer un QR code
    echo ""
    read -p "Générer un QR code pour cette configuration ? (y/N) : " generate_qr
    if [[ "$generate_qr" =~ ^[Yy]$ ]]; then
        if command -v qrencode &> /dev/null; then
            echo -e "\n${CYAN}QR Code de votre configuration:${NC}"
            sudo cat "$WG_CONFIG" | qrencode -t ansiutf8
            echo ""
            echo -e "${YELLOW}📱 Instructions:${NC}"
            echo "1. Installez l'application WireGuard sur votre appareil"
            echo "2. Ouvrez l'application et sélectionnez 'Scanner un QR code'"
            echo "3. Scannez le QR code affiché ci-dessus"
        else
            echo -e "${YELLOW}⚠️ qrencode non installé. Installez-le avec: sudo apt install qrencode${NC}"
        fi
    fi
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
    
    # Si un fichier de configuration existe déjà, remplacer le placeholder
    if [[ -f "/etc/wireguard/wg0.conf" ]] && grep -q "_REPLACE_WITH_CLIENT_PRIVATE_KEY_" "/etc/wireguard/wg0.conf"; then
        echo "🔄 Remplacement du placeholder par la clé privée générée..."
        sudo sed -i "s/_REPLACE_WITH_CLIENT_PRIVATE_KEY_/$(sudo cat $KEYS_DIR/client.priv)/g" /etc/wireguard/wg0.conf
    fi

    sudo systemctl enable --now wg-quick@wg0
    echo "✅ Configuration automatique terminée."
    echo "🔑 Clé publique client : $(sudo cat "$KEYS_DIR/client.pub")"
    echo ""
    echo -e "${YELLOW}📤 IMPORTANT: Copiez cette clé publique et fournissez-la au serveur${NC}"
    echo "   Le serveur a besoin de cette clé pour configurer le client"
    echo ""
    echo "🌐 Test de connectivité : ping 10.99.99.1"
}

# Génération de QR code pour configuration existante
generate_qr() {
    local CONFIG_FILE="/etc/wireguard/wg0.conf"
    
    # Vérifier si qrencode est installé
    if ! command -v qrencode &> /dev/null; then
        echo "❌ qrencode n'est pas installé"
        echo "   Installez-le avec: sudo apt install qrencode"
        exit 1
    fi
    
    # Chercher une configuration client
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ Aucune configuration WireGuard trouvée dans $CONFIG_FILE"
        echo ""
        echo "🔍 Recherche de configurations client..."
        
        # Chercher des fichiers de configuration client
        local client_configs=($(sudo find /etc/wireguard -name "*_lan.conf" 2>/dev/null))
        
        if [[ ${#client_configs[@]} -eq 0 ]]; then
            echo "❌ Aucune configuration client trouvée"
            echo "   Exécutez d'abord la configuration avec: $0"
            exit 1
        fi
        
        echo "📋 Configurations client trouvées:"
        for i in "${!client_configs[@]}"; do
            echo "  $((i+1)). ${client_configs[$i]}"
        done
        echo ""
        
        read -p "Sélectionnez une configuration (numéro) : " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#client_configs[@]} ]]; then
            CONFIG_FILE="${client_configs[$((choice-1))]}"
        else
            echo "❌ Sélection invalide"
            exit 1
        fi
    fi
    
    echo "📱 Génération du QR code pour: $CONFIG_FILE"
    echo ""
    echo "Configuration WireGuard:"
    sudo cat "$CONFIG_FILE"
    echo ""
    echo "QR Code (scannez avec votre application WireGuard):"
    sudo cat "$CONFIG_FILE" | qrencode -t ansiutf8
    echo ""
    echo "📱 Instructions:"
    echo "1. Installez l'application WireGuard sur votre appareil"
    echo "2. Ouvrez l'application et sélectionnez 'Scanner un QR code'"
    echo "3. Scannez le QR code affiché ci-dessus"
}

# Mode d'utilisation
if [[ $# -ge 1 ]] && [[ "$1" == "qr" ]]; then
    check_deps
    check_wireguard
    generate_qr
elif [[ $# -ge 5 ]] && [[ "$1" == "auto" ]]; then
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
