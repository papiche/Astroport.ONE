#!/bin/bash
# Ce script permet de créer
# ./Nextcloud.me.sh "$PLAYER" "$PEPPER" "$SAGITTARIUS_A" "20GB"
# Vérification des arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <email> <mot_de_passe> <ipfs_node_id> [quota]"
    exit 1
fi

EMAIL="$1"
PASSWORD="$2"
IPFS_NODE_ID="$3"
QUOTA="${4:-10GB}"

# Activation du tunnel SSH
if [[ ! $(ipfs p2p ls | grep x/ssh-${IPFS_NODE_ID}) ]]; then
    ipfs --timeout=10s ping -n 4 /p2p/${IPFS_NODE_ID}
    if [ $? -eq 0 ]; then
        ipfs p2p forward /x/ssh-${IPFS_NODE_ID} /ip4/127.0.0.1/tcp/22301 /p2p/${IPFS_NODE_ID}
    else
        echo "Erreur : Impossible de contacter le nœud IPFS"
        exit 1
    fi
else
    echo "Le tunnel SSH est déjà actif"
fi

# Création du compte NextCloud via SSH
ssh -p 22301 frd@127.0.0.1 << EOF
    docker exec -u www-data nextcloud-aio-nextcloud php occ user:add \
    --display-name="${EMAIL%%@*}" \
    --group="users" \
    --password="${PASSWORD}" \
    --quota="${QUOTA}" \
    "${EMAIL}"
EOF

# Vérification du résultat
if [ $? -eq 0 ]; then
    echo "Le compte NextCloud pour ${EMAIL} a été créé avec succès"
else
    echo "Erreur lors de la création du compte NextCloud"
fi

# Fermeture du tunnel SSH (optionnel, décommentez si nécessaire)
# ipfs p2p close -p /x/ssh-${IPFS_NODE_ID}
