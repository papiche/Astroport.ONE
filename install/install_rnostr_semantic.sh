#!/bin/bash
############################################################ install_rnostr_semantic.sh
# Installation de rnostr et Qdrant pour la recherche sémantique.
# NOTE: Le container embed-worker n'est PAS installé sur petite configuration.
#       Les embeddings sont gérés par :
#         - IA/ollama.me.sh  → connexion Ollama (local, SSH ou IPFS P2P swarm)
#         - IA/embed.py      → embedding via nomic-embed-text + indexation Qdrant
#       Ces outils deviennent pleinement opérationnels après activation de l'essaim
#       IPFS privé (BLOOM.me) qui permet l'exécution de DRAGON_p2p_ssh.sh.
# Auteur : Fred R
# Date : 2026-03-14
########################################################################

set -e  # Arrête le script en cas d'erreur

echo "=== [1/5] Vérification des dépendances ==="

# Vérification des outils requis
for cmd in docker curl jq; do
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

echo "=== [2/5] Création des répertoires ==="

# Création des répertoires avec vérification
mkdir -p ~/.zen/rnostr/extensions
mkdir -p ~/.zen/qdrant-data

# Vérification des permissions
for dir in ~/.zen/rnostr/extensions ~/.zen/qdrant-data; do
    if [ ! -w "$dir" ]; then
        echo "Erreur : permissions insuffisantes sur $dir"
        exit 1
    fi
done

echo "=== [3/5] Configuration de rnostr ==="

# Configuration de rnostr.toml
cat << 'EOF' > ~/.zen/rnostr/rnostr.toml
[extensions]
write_policy = "/data/extensions/uplanet_policy"

[limits]
max_conn = 1000
max_event_size = 65536

[network]
addr = "0.0.0.0:8888"
EOF

echo "=== [4/5] Configuration de Docker Compose ==="

# Génération du fichier docker-compose.yml
# NOTE: embed-worker est intentionnellement absent — l'embedding est délégué
# à IA/ollama.me.sh (connexion Ollama via IPFS P2P swarm) et IA/embed.py.
cat << 'EOF' > ~/.zen/rnostr/docker-compose.yml
version: "3.9"
services:
  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    ports:
      # Bind sur localhost UNIQUEMENT — pas d'exposition publique directe
      # L'accès externe passe par NPM (si activé) ou reste interne
      - "127.0.0.1:6333:6333"
      - "127.0.0.1:6334:6334"
    volumes:
      - ~/.zen/qdrant-data:/qdrant/storage
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333"]
      interval: 5s
      timeout: 3s
      retries: 10
    restart: always

  rnostr:
    image: papiche/rnostr:latest
    container_name: rnostr
    ports:
      # rnostr écoute sur localhost — NPM proxie vers relay.DOMAIN (wss://)
      - "127.0.0.1:8888:7777"
    volumes:
      - ~/.zen/game/nostr:/data/nostr:ro
      - ~/.zen/strfry/amisOfAmis.txt:/data/amisOfAmis.txt:ro
      - ~/.zen/rnostr/rnostr.toml:/etc/rnostr/rnostr.toml:ro
      - ~/.zen/rnostr/extensions:/data/extensions:ro
    depends_on:
      qdrant:
        condition: service_healthy
    restart: always
EOF

echo "=== [5/5] Initialisation de Qdrant et création de la collection ==="

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

# Vérification des conteneurs (qdrant + rnostr uniquement)
if ! $DOCKER_COMPOSE_CMD ps | grep -E "qdrant.*Up|rnostr.*Up" &> /dev/null; then
    echo "Erreur : un ou plusieurs conteneurs ne sont pas démarrés."
    $DOCKER_COMPOSE_CMD logs
    exit 1
fi

echo "=== Installation terminée avec succès ! ==="
echo ""
echo "Accès aux services :"
echo "- Relais Nostr (rnostr)  : ws://localhost:8888"
echo "- Dashboard Qdrant       : http://localhost:6333/dashboard"
echo "- Logs : '$DOCKER_COMPOSE_CMD logs -f'"
echo ""
echo "Pour arrêter la stack : '$DOCKER_COMPOSE_CMD down'"
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Embedding sémantique — Utilisation sans embed-worker docker    ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  1. Activer l'essaim IPFS privé (BLOOM.me → DRAGON_p2p_ssh.sh) ║"
echo "║  2. Connecter Ollama :  ~/.zen/Astroport.ONE/IA/ollama.me.sh   ║"
echo "║  3. Indexer dans Qdrant : python3 IA/embed.py --index ...      ║"
echo "║  4. Rechercher :         python3 IA/embed.py --search ...      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
