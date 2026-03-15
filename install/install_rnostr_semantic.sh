#!/bin/bash
############################################################ install_rnostr_semantic.sh
# Installation de rnostr, embed-worker (Nomic) et Qdrant pour la recherche sémantique.
# Auteur : Fred R
# Date : 2026-03-14
########################################################################

set -e  # Arrête le script en cas d'erreur

echo "=== [1/7] Vérification des dépendances ==="

# Vérification des outils requis
for cmd in docker curl wget jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Erreur : $cmd n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
done

# Vérification de la version de Docker
if ! docker --version &> /dev/null; then
    echo "Erreur : Docker n'est pas correctement installé ou démarré."
    exit 1
fi

echo "=== [2/7] Création des répertoires ==="

# Création des répertoires avec vérification
mkdir -p ~/.zen/rnostr/extensions
mkdir -p ~/.zen/embed-worker/models
mkdir -p ~/.zen/qdrant-data

# Vérification des permissions
for dir in ~/.zen/rnostr/extensions ~/.zen/embed-worker/models ~/.zen/qdrant-data; do
    if [ ! -w "$dir" ]; then
        echo "Erreur : permissions insuffisantes sur $dir"
        exit 1
    fi
done

echo "=== [3/7] Téléchargement du modèle Nomic ==="

MODEL_PATH=~/.zen/embed-worker/models/nomic-embed-text-v1.Q4_K_M.gguf
MODEL_URL="https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q4_K_M.gguf"
MODEL_MIN_SIZE=$((100 * 1024 * 1024))  # 100 Mo minimum pour éviter les téléchargements corrompus

if [ ! -f "$MODEL_PATH" ] || [ $(stat -c%s "$MODEL_PATH") -lt $MODEL_MIN_SIZE ]; then
    echo "Téléchargement du modèle Nomic depuis $MODEL_URL..."
    if ! wget "$MODEL_URL" -O "$MODEL_PATH"; then
        echo "Erreur : échec du téléchargement du modèle."
        exit 1
    fi
    if [ $(stat -c%s "$MODEL_PATH") -lt $MODEL_MIN_SIZE ]; then
        echo "Erreur : le modèle téléchargé semble corrompu (taille insuffisante)."
        rm "$MODEL_PATH"
        exit 1
    fi
    echo "Modèle téléchargé avec succès : $(stat -c%s "$MODEL_PATH" | numfmt --to=iec)."
else
    echo "Modèle Nomic déjà présent : $(stat -c%s "$MODEL_PATH" | numfmt --to=iec)."
fi

echo "=== [4/7] Configuration de rnostr ==="

# Configuration de rnostr.toml
cat << 'EOF' > ~/.zen/rnostr/rnostr.toml
[extensions]
write_policy = "/data/extensions/uplanet_policy"

[limits]
max_conn = 1000
max_event_size = 65536

[network]
addr = "0.0.0.0:7777"
EOF

echo "=== [5/7] Configuration de Docker Compose ==="

# Génération du fichier docker-compose.yml
cat << 'EOF' > ~/.zen/rnostr/docker-compose.yml
version: "3.9"
services:
  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - ~/.zen/qdrant-data:/qdrant/storage
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333"]
      interval: 5s
      timeout: 3s
      retries: 10
    restart: unless-stopped

  embed-worker:
    image: papiche/embed-worker:latest
    container_name: embed-worker
    environment:
      - QDRANT_URL=http://qdrant:6333
      - MODEL_PATH=/models/nomic-embed-text-v1.Q4_K_M.gguf
    volumes:
      - ~/.zen/embed-worker/models:/models:ro
    depends_on:
      qdrant:
        condition: service_healthy
    restart: unless-stopped

  rnostr:
    image: papiche/rnostr:latest
    container_name: rnostr
    ports:
      - "7777:7777"
    volumes:
      - ~/.zen/game/nostr:/data/nostr:ro
      - ~/.zen/strfry/amisOfAmis.txt:/data/amisOfAmis.txt:ro
      - ~/.zen/rnostr/rnostr.toml:/etc/rnostr/rnostr.toml:ro
      - ~/.zen/rnostr/extensions:/data/extensions:ro
    depends_on:
      - embed-worker
    restart: unless-stopped
EOF

echo "=== [6/7] Initialisation de Qdrant et création de la collection ==="

# Démarrage de la stack
cd ~/.zen/rnostr

# Utilisation de docker compose (nouvelle syntaxe) ou docker-compose (ancienne)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    DOCKER_COMPOSE_CMD="docker-compose"
fi

echo "Démarrage des conteneurs..."
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo "Erreur : échec du démarrage des conteneurs."
    exit 1
fi

# Attente que Qdrant soit prêt
echo "Attente de la disponibilité de Qdrant..."
for i in {1..30}; do
    if curl -s "http://localhost:6333" &> /dev/null; then
        echo "Qdrant est prêt."
        break
    fi
    sleep 2
    echo "Tentative $i/30..."
done

if [ $i -eq 30 ]; then
    echo "Erreur : Qdrant n'a pas démarré correctement."
    exit 1
fi

# Création de la collection Qdrant
echo "Création de la collection 'nostr_events' dans Qdrant..."
COLLECTION_CONFIG='{
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  },
  "hnsw_config": {
    "m": 16,
    "ef_construct": 64
  },
  "optimizers_config": {
    "indexing_threshold": 1000
  }
}'

if ! curl -X PUT "http://localhost:6333/collections/nostr_events" \
     -H "Content-Type: application/json" \
     -d "$COLLECTION_CONFIG" &> /dev/null; then
    echo "Erreur : échec de la création de la collection Qdrant."
    exit 1
fi

echo "Collection 'nostr_events' créée avec succès."

echo "=== [7/7] Vérification finale ==="

# Vérification des conteneurs
if ! $DOCKER_COMPOSE_CMD ps | grep -E "qdrant.*Up|embed-worker.*Up|rnostr.*Up" &> /dev/null; then
    echo "Erreur : un ou plusieurs conteneurs ne sont pas démarrés."
    $DOCKER_COMPOSE_CMD logs
    exit 1
fi

echo "=== Installation terminée avec succès ! ==="
echo ""
echo "Accès aux services :"
echo "- Relais Nostr (rnostr) : ws://localhost:7777"
echo "- Dashboard Qdrant : http://localhost:6333/dashboard"
echo "- Logs : '$DOCKER_COMPOSE_CMD logs -f'"
echo ""
echo "Pour arrêter la stack : '$DOCKER_COMPOSE_CMD down'"
