#!/bin/bash
# Ce script permet de créer un utilisateur sur NextCloud (docker aio)
# ./Nextcloud.me.sh "$PLAYER" "$PEPPER" "10GB"
# Vérification des arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <email> <mot_de_passe> [quota]"
    exit 1
fi

EMAIL="$1"
PASSWORD="$2"
QUOTA="${3:-128GB}"

export OC_PASS="${PASSWORD}"
# Création du compte NextCloud via SSH
docker exec -u www-data nextcloud-aio-nextcloud php occ user:add \
    --display-name="${EMAIL%%@*}" \
    --group="${QUOTA}" \
    --password-from-env \
    --quota="${QUOTA}" \
    "${EMAIL}"

# Vérification du résultat
if [ $? -eq 0 ]; then
    echo "Le compte NextCloud pour ${EMAIL} a été créé avec succès"
else
    echo "Erreur lors de la création du compte NextCloud"
fi
