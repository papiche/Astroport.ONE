#!/bin/bash

# Vérification des arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <email> <ipfs_node_id> <backup_path>"
    exit 1
fi

EMAIL="$1"
IPFS_NODE_ID="$2"
BACKUP_PATH="$3"

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

# Sauvegarde du compte NextCloud
ssh -p 22301 frd@127.0.0.1 << EOF
    docker exec -u www-data nextcloud-aio-nextcloud php occ user:export ${EMAIL} ${BACKUP_PATH}
EOF

# Vérification du résultat
if [ $? -eq 0 ]; then
    echo "Le compte NextCloud pour ${EMAIL} a été sauvegardé avec succès dans ${BACKUP_PATH}"
else
    echo "Erreur lors de la sauvegarde du compte NextCloud"
fi
