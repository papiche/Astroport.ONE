#!/bin/bash

# Fonction pour afficher les messages d'erreur et quitter le script :
error_exit() {
    echo "$1" 1>&2
    exit 1
}

# Vérifie si Git est installé :
if ! command -v git &> /dev/null; then
    error_exit "Erreur : Git n'est pas installé."
fi

# Vérifie si Docker est installé :
if ! command -v docker &> /dev/null; then
    error_exit "Erreur : Docker n'est pas installé." | sudo apt install docker.io
fi

# Répertoire où Nextcloud sera cloné :
mkdir"/home/$USER/opt"
mkdir"/home/$USER/opt/nextcloud"
install_dir="/opt/nextcloud"

# Clone le dépôt Nextcloud depuis GitHub :
echo "Clonage du dépôt Nextcloud depuis GitHub..."
git clone https://github.com/nextcloud/server.git "$install_dir" || error_exit "Erreur lors du clonage du dépôt Nextcloud."

# Se déplace dans le répertoire Nextcloud :
cd "$install_dir" || error_exit "Le répertoire Nextcloud n'existe pas : $install_dir"

# Lance Nextcloud via Docker :
echo "Lancement de Nextcloud via Docker..."
docker-compose up -d || error_exit "Erreur lors du lancement de Nextcloud via Docker."

echo "Nextcloud a été lancé avec succès."

echo "Sur votre navigateur connectez vous sur http://localhost:8080/"
