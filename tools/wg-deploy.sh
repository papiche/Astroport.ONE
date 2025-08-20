#!/bin/bash
# WireGuard LAN Deployment Script - Automatise la configuration complète

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        WIREGUARD LAN DEPLOYMENT                              ║"
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

# Vérification des dépendances
check_deps() {
    local missing_deps=()
    
    for cmd in wg curl systemctl sudo ssh-keygen; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Dépendances manquantes:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "   - $dep"
        done
        echo -e "\n${YELLOW}Installation des dépendances...${NC}"
        
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y wireguard curl openssh-client
        elif command -v yum &> /dev/null; then
            sudo yum install -y wireguard-tools curl openssh-clients
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y wireguard-tools curl openssh-clients
        else
            echo -e "${RED}❌ Gestionnaire de paquets non reconnu${NC}"
            exit 1
        fi
    fi
}

# Vérification de WireGuard
check_wireguard() {
    if ! command -v wg &> /dev/null; then
        echo -e "${RED}❌ WireGuard n'est pas installé${NC}"
        echo "   Installation en cours..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y wireguard
        elif command -v yum &> /dev/null; then
            sudo yum install -y wireguard-tools
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y wireguard-tools
        fi
    else
        echo -e "${GREEN}✅ WireGuard détecté${NC}"
    fi
}

# Configuration du serveur
setup_server() {
    print_section "CONFIGURATION DU SERVEUR"
    
    # Vérifier si WireGuard est déjà configuré
    if systemctl is-active --quiet wg-quick@wg0; then
        echo -e "${YELLOW}⚠️ WireGuard est déjà actif sur ce serveur${NC}"
        read -p "Voulez-vous le reconfigurer ? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        sudo systemctl stop wg-quick@wg0
    fi
    
    # Exécuter le script de configuration serveur
    echo "🚀 Configuration du serveur WireGuard..."
    ./wireguard_control.sh
    
    # Attendre que l'utilisateur configure le serveur
    echo -e "\n${YELLOW}⚠️ Veuillez configurer le serveur via le menu WireGuard Control${NC}"
    echo "   Appuyez sur ENTRÉE quand c'est fait..."
    read
    
    # Vérifier que le serveur est actif
    if systemctl is-active --quiet wg-quick@wg0; then
        echo -e "${GREEN}✅ Serveur WireGuard configuré et actif${NC}"
        return 0
    else
        echo -e "${RED}❌ Échec de la configuration du serveur${NC}"
        return 1
    fi
}

# Configuration du client
setup_client() {
    print_section "CONFIGURATION DU CLIENT"
    
    # Demander les informations de connexion
    echo -e "${WHITE}Informations du serveur:${NC}"
    read -p "Adresse IP ou domaine du serveur : " SERVER_IP
    read -p "Port du serveur [51820] : " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-51820}
    
    echo -e "\n${WHITE}Clé publique du serveur:${NC}"
    echo "   (Copiez la clé affichée par le serveur)"
    read -p "> " SERVER_PUBKEY
    
    # Vérifier que la clé est valide
    if [[ ${#SERVER_PUBKEY} -lt 40 ]]; then
        echo -e "${RED}❌ Clé publique invalide${NC}"
        return 1
    fi
    
    # Trouver une IP disponible
    echo -e "\n${WHITE}IP du client dans le réseau VPN:${NC}"
    echo "   (10.99.99.2 à 10.99.99.254)"
    read -p "IP client [10.99.99.2] : " CLIENT_IP
    CLIENT_IP=${CLIENT_IP:-10.99.99.2}
    
    # Configuration automatique du client
    echo "🚀 Configuration automatique du client..."
    ./wg-client-setup.sh auto "$SERVER_IP" "$SERVER_PORT" "$SERVER_PUBKEY" "$CLIENT_IP"
    
    if [[ $? -eq 0 ]]; then
        echo -e "\n${GREEN}✅ Client WireGuard configuré avec succès${NC}"
        
        # Test de connectivité
        echo -e "\n${WHITE}🧪 Test de connectivité...${NC}"
        sleep 3
        if ping -c 3 -W 5 10.99.99.1 &> /dev/null; then
            echo -e "${GREEN}✅ Connexion VPN établie${NC}"
        else
            echo -e "${YELLOW}⚠️ Connexion VPN non établie - vérifiez la configuration${NC}"
        fi
    else
        echo -e "${RED}❌ Échec de la configuration du client${NC}"
        return 1
    fi
}

# Menu principal
show_menu() {
    while true; do
        clear
        print_header
        
        echo -e "${WHITE}Mode de déploiement:${NC}"
        echo "1. 🖥️  Configurer ce serveur WireGuard"
        echo "2. 💻 Configurer ce client WireGuard"
        echo "3. 🔧 Vérifier l'état des services"
        echo "4. 📋 Afficher les informations de connexion"
        echo "5. ❌ Quitter"
        echo ""
        read -p "Choix : " choice

        case $choice in
            1) setup_server ;;
            2) setup_client ;;
            3)
                print_section "ÉTAT DES SERVICES"
                if systemctl is-active --quiet wg-quick@wg0; then
                    echo -e "${GREEN}✅ WireGuard: ACTIF${NC}"
                    echo -e "${WHITE}Clients connectés:${NC}"
                    sudo wg show wg0 | grep -E "(peer:|latest handshake:|transfer:)" || echo "Aucun client"
                else
                    echo -e "${RED}❌ WireGuard: INACTIF${NC}"
                fi
                ;;
            4)
                print_section "INFORMATIONS DE CONNEXION"
                if [[ -f /etc/wireguard/keys/server.pub ]]; then
                    echo -e "${WHITE}Clé publique serveur:${NC}"
                    sudo cat /etc/wireguard/keys/server.pub
                    echo -e "\n${WHITE}Endpoint:${NC} $(curl -s ifconfig.me):51820"
                    echo -e "${WHITE}Réseau VPN:${NC} 10.99.99.0/24"
                else
                    echo -e "${YELLOW}⚠️ Serveur non configuré${NC}"
                fi
                ;;
            5) exit 0 ;;
            *) echo -e "${RED}❌ Option invalide${NC}" ;;
        esac
        
        [[ $choice != "5" ]] && { echo ""; read -p "Appuyez sur ENTRÉE pour continuer..."; }
    done
}

# Vérification des permissions
check_permissions() {
    # Vérifier que sudo est disponible
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}❌ sudo n'est pas installé${NC}"
        echo "   Installez sudo ou exécutez en tant que root"
        exit 1
    fi
    
    # Tester si sudo fonctionne (demandera le mot de passe si nécessaire)
    echo -e "${YELLOW}🔐 Vérification des privilèges sudo...${NC}"
    if ! sudo -v; then
        echo -e "${RED}❌ Impossible d'obtenir les privilèges sudo${NC}"
        echo "   Vérifiez votre configuration sudo"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Privilèges sudo confirmés${NC}"
}

# Main
main() {
    print_header
    echo -e "${WHITE}Vérification de l'environnement...${NC}"
    
    check_permissions
    check_deps
    check_wireguard
    
    echo -e "${GREEN}✅ Environnement prêt${NC}"
    echo ""
    
    show_menu
}

# Exécution
main "$@"
