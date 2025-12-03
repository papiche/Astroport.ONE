#!/bin/bash

# --- CONFIGURATION ---
# Nom du conteneur (vérifiez avec "docker ps", souvent nomdudossier-duniter-1)
CONTAINER_NAME="duniter187-duniter-1"
# Chemin interne des données Duniter (standard)
INTERNAL_PATH="/var/lib/duniter"
# Nom du fichier temporaire
ARCHIVE_NAME="duniter_db_snapshot.tar.gz"
EXPORT_DIR="./duniter_export_tmp"

echo "=== Étape 1 : Arrêt du nœud Duniter ==="
docker stop $CONTAINER_NAME

echo "=== Étape 2 : Extraction des données ==="
# On nettoie d'anciens exports si existent
rm -rf $EXPORT_DIR
mkdir -p $EXPORT_DIR

# On copie le dossier de données du docker vers l'hôte
docker cp $CONTAINER_NAME:$INTERNAL_PATH $EXPORT_DIR/

echo "=== Étape 3 : Sécurisation (Suppression des clés privées) ==="
# IMPORTANT : On ne publie JAMAIS le key.yml ou key.priv sur IPFS
# La structure est souvent dans le sous-dossier 'duniter' extrait
find $EXPORT_DIR -name "key.yml" -delete
find $EXPORT_DIR -name "key.priv" -delete

echo "=== Étape 4 : Compression de la DB ==="
# On compresse le contenu (duniter_default, currency, etc.)
cd $EXPORT_DIR
# On suppose que 'docker cp' a créé un dossier 'duniter' contenant les données
tar -czf ../$ARCHIVE_NAME *
cd ..

echo "=== Étape 5 : Envoi vers IPFS ==="
# On ajoute à IPFS et on récupère le CID (hash)
CID=$(ipfs add -Q $ARCHIVE_NAME)

echo "=== Étape 6 : Redémarrage du nœud ==="
docker start $CONTAINER_NAME

# Nettoyage
rm -rf $EXPORT_DIR
rm $ARCHIVE_NAME

echo "----------------------------------------------------"
echo "SUCCÈS ! La base de données est sur IPFS."
echo "CID : $CID"
echo "Copiez ce CID pour l'utiliser avec le script d'import."
echo "----------------------------------------------------"