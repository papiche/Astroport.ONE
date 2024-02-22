#!/bin/bash

############################################
#   
#
# Crédit Antoine Le dieu
#
#
############################################

# Fonction pour afficher les messages d'erreur et quitter le script
error_exit() {
    echo "$1" 1>&2
    exit 1
}

# Vérifier si Git est installé
if ! command -v git &> /dev/null; then
    error_exit "Erreur : Git n'est pas installé. Veuillez installer Git pour continuer."
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    error_exit "Erreur : Docker n'est pas installé. Veuillez installer Docker pour continuer."
fi

# Répertoire où Nextcloud sera cloné
mkdir="/home/$USER/opt"
mkdir="/home/$USER/opt/nextcloud"
install_dir="/home/$USER/opt/nextcloud"

# Cloner le dépôt Nextcloud depuis GitHub
echo "Clonage du dépôt Nextcloud depuis GitHub..."
git clone https://github.com/nextcloud/server.git "$install_dir" || error_exit "Erreur lors du clonage du dépôt Nextcloud."

# Aller dans le répertoire Nextcloud
cd "$install_dir" || error_exit "Le répertoire Nextcloud n'existe pas : $install_dir"

# Lancer le build de Nextcloud via Docker
echo "Lancement du build de Nextcloud via Docker..."
docker-compose up -d || error_exit "Erreur lors du lancement du build de Nextcloud via Docker."

echo "Le build de Nextcloud a été lancé avec succès."

echo "Sur votre navigateur lancez connectez vous sur http://localhost:8080/"