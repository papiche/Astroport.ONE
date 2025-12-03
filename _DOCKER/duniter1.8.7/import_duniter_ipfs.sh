#!/bin/bash

if [ -z "$1" ]; then
    echo "Erreur : Veuillez fournir le CID IPFS en argument."
    echo "Usage : ./import_duniter_ipfs.sh QmHash..."
    exit 1
fi

CID=$1

# --- CONFIGURATION ---
# Nom du conteneur cible
CONTAINER_NAME="duniter187-duniter-1"
INTERNAL_PATH="/var/lib/duniter"
TEMP_IMPORT_DIR="./duniter_import_tmp"
ARCHIVE_NAME="duniter_import.tar.gz"

echo "=== Étape 1 : Téléchargement depuis IPFS ($CID) ==="
ipfs get $CID -o $ARCHIVE_NAME
if [ $? -ne 0 ]; then
    echo "Erreur lors du téléchargement IPFS."
    exit 1
fi

echo "=== Étape 2 : Arrêt du nœud cible ==="
docker stop $CONTAINER_NAME

echo "=== Étape 3 : Sauvegarde de la clé privée existante ==="
# On crée un dossier temporaire pour manipuler les fichiers
rm -rf $TEMP_IMPORT_DIR
mkdir -p $TEMP_IMPORT_DIR/conf

# On essaie de récupérer key.yml du conteneur pour ne pas le perdre
docker cp $CONTAINER_NAME:$INTERNAL_PATH/conf/key.yml $TEMP_IMPORT_DIR/conf/key.yml 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Clé privée sauvegardée."
else
    echo "ATTENTION : Pas de key.yml trouvé ou erreur de copie. Le nœud démarrera sans identité."
fi

echo "=== Étape 4 : Remplacement des données ==="
# Méthode radicale : on vide le dossier de données dans le conteneur
# On utilise une commande shell dans docker pour nettoyer
docker start $CONTAINER_NAME
# On attend un peu que le conteneur soit UP (mais Duniter ne doit pas écrire la DB tout de suite)
# Idéalement, il faudrait une image avec un 'sleep' comme entrypoint, mais faisons simple :
# On arrête le service duniter tout en gardant le conteneur...
# C'est compliqué avec Docker Compose standard. 
# -> Stratégie alternative : On prépare le dossier sur l'hôte et on l'écrase.

docker stop $CONTAINER_NAME

# Décompression de l'archive IPFS
mkdir -p $TEMP_IMPORT_DIR/data
tar -xzf $ARCHIVE_NAME -C $TEMP_IMPORT_DIR/data

# Si l'archive contient un dossier 'duniter', on ajuste le chemin
if [ -d "$TEMP_IMPORT_DIR/data/duniter" ]; then
    mv $TEMP_IMPORT_DIR/data/duniter/* $TEMP_IMPORT_DIR/data/
    rmdir $TEMP_IMPORT_DIR/data/duniter
fi

# Restauration de la clé sauvegardée dans le nouveau dossier de données
if [ -f "$TEMP_IMPORT_DIR/conf/key.yml" ]; then
    mkdir -p $TEMP_IMPORT_DIR/data/conf
    cp $TEMP_IMPORT_DIR/conf/key.yml $TEMP_IMPORT_DIR/data/conf/
fi

# Injection des données dans le conteneur
# Note : 'docker cp' ne permet pas d'écraser proprement un volume monté si les fichiers sont locked.
# Mais le conteneur est stoppé, donc ça va.
echo "Copie des nouvelles données vers le conteneur..."
# Astuce : copier le CONTENU du dossier data vers le dossier duniter du conteneur
docker cp $TEMP_IMPORT_DIR/data/. $CONTAINER_NAME:$INTERNAL_PATH/

echo "=== Étape 5 : Correction des permissions ==="
# Duniter tourne souvent avec l'UID 1000. Il faut s'assurer que les fichiers copiés appartiennent au bon user.
# On lance un fix rapide via une image alpine temporaire montant les volumes du conteneur duniter ?
# Plus simple : on démarre le conteneur et on lance un chown immédiatement si possible, 
# ou on utilise 'docker run --volumes-from' pour fix.
# Ici, on tente de lancer duniter, s'il plante sur les droits, il faudra faire un chown.
# Commande générique pour fixer les droits (suppose user duniter uid 1000:1000) :
# (Cette commande nécessite que le conteneur tourne, ce qui est paradoxal si les droits bloquent le start)

# La méthode propre "Docker" :
docker run --rm --volumes-from $CONTAINER_NAME debian:bullseye-slim chown -R 1000:1000 $INTERNAL_PATH

echo "=== Étape 6 : Redémarrage ==="
docker start $CONTAINER_NAME
rm -rf $TEMP_IMPORT_DIR
rm $ARCHIVE_NAME

echo "----------------------------------------------------"
echo "Mise à jour terminée."
echo "Vérifiez les logs : docker logs $CONTAINER_NAME"
echo "----------------------------------------------------"