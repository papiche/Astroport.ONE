#!/bin/bash

# =============================================================================
# UNIVERSEL DOCKER INSTALLER (Debian, Ubuntu, Mint)
# Architectures : amd64 (x86_64) & arm64 (aarch64)
# =============================================================================

set -e

# --- 1. NETTOYAGE CRITIQUE DES ERREURS APT ---
echo -e "\033[0;36m--- Nettoyage du système ---\033[0m"
# Supprime l'architecture arm64 si elle a été ajoutée par erreur sur un PC Intel/AMD
CURRENT_ARCH=$(dpkg --print-architecture)
FOREIGN_ARCHS=$(dpkg --print-foreign-architectures)

if [[ "$CURRENT_ARCH" == "amd64" ]] && [[ "$FOREIGN_ARCHS" == *"arm64"* ]]; then
    echo "Correction : Suppression de l'architecture arm64 étrangère qui cause des erreurs 404..."
    sudo dpkg --remove-architecture arm64 || true
fi

# Suppression des anciennes versions de Docker
sudo apt-get remove -y docker docker-engine docker.io containerd runc docker-compose || true

# --- 2. DÉTECTION DU SYSTÈME ---
echo -e "\033[0;36m--- Détection de l'OS ---\033[0m"
source /etc/os-release

if [ "$ID" = "linuxmint" ]; then
    OS_TYPE="ubuntu"
    CODENAME=$UBUNTU_CODENAME
    # Si UBUNTU_CODENAME est vide (vieilles versions de Mint)
    [ -z "$CODENAME" ] && CODENAME=$(grep 'VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
elif [ "$ID" = "ubuntu" ]; then
    OS_TYPE="ubuntu"
    CODENAME=$VERSION_CODENAME
else
    # Par défaut Debian
    OS_TYPE="debian"
    CODENAME=$VERSION_CODENAME
fi

echo "Système détecté : $ID ($CODENAME) sur $CURRENT_ARCH"

# --- 3. PRÉPARATION DES DÉPÔTS ---
echo -e "\033[0;36m--- Configuration du dépôt officiel Docker ---\033[0m"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
# Suppression de l'ancienne clé si elle existe
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/$OS_TYPE/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Ajout du dépôt Docker officiel
echo \
  "deb [arch=$CURRENT_ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_TYPE \
  $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# --- 4. INSTALLATION ---
echo -e "\033[0;36m--- Installation de Docker & Compose V2 ---\033[0m"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 5. POST-INSTALLATION ---
echo -e "\033[0;36m--- Configuration des groupes ---\033[0m"
sudo usermod -aG docker $USER

echo -e "\033[0;32m"
echo "✅ Docker et Docker Compose V2 sont installés !"
echo "------------------------------------------------"
echo "Version Docker  : $(docker --version)"
echo "Version Compose : $(docker compose version)"
echo "------------------------------------------------"
echo -e "\033[0m"
echo -e "ℹ️  INFO : L'utilisateur '$USER' a été ajouté au groupe docker."
echo -e "   Les permissions seront effectives à la prochaine session."
echo -e "   Pour les commandes suivantes de ce script, sudo docker est utilisé."
