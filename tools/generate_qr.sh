#!/bin/bash
# QR Code Generator for WireGuard Configuration
# Usage: ./generate_qr.sh [config_file]

CONFIG_FILE="${1:-/etc/wireguard/wg0.conf}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 WireGuard QR Code Generator${NC}"
echo ""

# Check if qrencode is installed
if ! command -v qrencode &> /dev/null; then
    echo -e "${RED}❌ qrencode n'est pas installé${NC}"
    echo "   Installez-le avec:"
    echo "   • Ubuntu/Debian: sudo apt install qrencode"
    echo "   • CentOS/RHEL: sudo yum install qrencode"
    echo "   • Arch: sudo pacman -S qrencode"
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}❌ Fichier de configuration non trouvé: $CONFIG_FILE${NC}"
    echo ""
    echo "Usage: $0 [config_file]"
    echo "   Par défaut: /etc/wireguard/wg0.conf"
    echo ""
    echo "Exemples:"
    echo "   $0                                    # Utilise /etc/wireguard/wg0.conf"
    echo "   $0 /path/to/tunnel.conf             # Utilise un fichier spécifique"
    echo "   $0 /etc/wireguard/client_lan.conf   # Configuration client"
    exit 1
fi

# Check if file is readable
if ! sudo test -r "$CONFIG_FILE"; then
    echo -e "${RED}❌ Impossible de lire le fichier: $CONFIG_FILE${NC}"
    echo "   Vérifiez les permissions du fichier"
    exit 1
fi

echo -e "${GREEN}✅ Configuration trouvée: $CONFIG_FILE${NC}"
echo ""

# Display the configuration
echo -e "${YELLOW}📋 Configuration WireGuard:${NC}"
sudo cat "$CONFIG_FILE"
echo ""

# Generate QR code
echo -e "${CYAN}📱 QR Code (scannez avec votre application WireGuard):${NC}"
sudo cat "$CONFIG_FILE" | qrencode -t ansiutf8
echo ""

# Instructions
echo -e "${YELLOW}📱 Instructions pour le client:${NC}"
echo "1. Installez l'application WireGuard sur votre appareil"
echo "   • Android: Google Play Store"
echo "   • iOS: App Store"
echo "   • Desktop: https://www.wireguard.com/install/"
echo ""
echo "2. Ouvrez l'application WireGuard"
echo "3. Sélectionnez 'Ajouter un tunnel' ou 'Scanner un QR code'"
echo "4. Scannez le QR code affiché ci-dessus"
echo "5. La configuration sera automatiquement importée"
echo ""

# Optional: Save as PNG
read -p "Sauvegarder le QR code en image PNG ? (y/N) : " save_png
if [[ "$save_png" =~ ^[Yy]$ ]]; then
    local output_file="${CONFIG_FILE%.*}_qr.png"
    sudo cat "$CONFIG_FILE" | qrencode -o "$output_file"
    echo -e "${GREEN}✅ QR code sauvegardé: $output_file${NC}"
fi

echo -e "${GREEN}✅ Génération terminée${NC}"
