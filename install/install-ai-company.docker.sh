#!/bin/bash

# =============================================================================
# install-ai-company.sh - UPLANET ZEN[0] Swarm AI Stack Manager
# Architecture : Multi-arch (x86_64 / aarch64)
# =============================================================================

set -e

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# --- CONFIGURATION ---
INSTALL_DIR="$HOME/.zen/ai-company"
OLLAMA_PORT=11434
OLLAMA_MODEL="gemma3:latest"
EMBEDDING_MODEL="nomic-embed-text:latest"

# Couleurs
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# --- CONFIGURATION DES PORTS ---
# Vous pouvez changer ces variables ici si conflit
PORT_PAPERCLIP=${PORT_PAPERCLIP:-3100}
PORT_OPENCLAW=${PORT_OPENCLAW:-8000}
PORT_LITELLM=${PORT_LITELLM:-8001}
PORT_QDRANT=${PORT_QDRANT:-6333}
PORT_OLLAMA=11434 # Généralement sur l'hôte

# --- FONCTION DE VÉRIFICATION DE PORT ---
check_ports() {
    local ports=("$PORT_PAPERCLIP" "$PORT_OPENCLAW" "$PORT_LITELLM" "$PORT_QDRANT")
    local conflict=0
    echo -e "${CYAN}🔍 Vérification de la disponibilité des ports...${NC}"
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            echo -e "${RED}❌ Le port $port est déjà utilisé par un autre service !${NC}"
            conflict=1
        fi
    done

    if [ $conflict -eq 1 ]; then
        echo -e "${YELLOW}Conseil : Modifiez les variables PORT_XXX au début du script ou arrêtez les services gênants.${NC}"
        read -p "Voulez-vous quand même tenter l'installation ? (y/N) : " confirm
        [[ $confirm == [yY] ]] || exit 1
    else
        echo -e "${GREEN}✅ Tous les ports sont libres.${NC}"
    fi
}

# --- DETECTION DOCKER COMPOSE ---
if docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo -e "${RED}Erreur: Docker Compose n'est pas installé.${NC}"
    echo -e "Veuillez installer 'docker-compose-plugin' ou 'docker-compose'."
    exit 1
fi

# --- FONCTIONS D'AIDE ---

show_help() {
    echo -e "${BOLD}${CYAN}AI Company Stack Manager${NC}"
    echo -e "Ce script installe une infrastructure IA privée complète.\n"
    echo -e "${BOLD}COMMANDES :${NC}"
    echo -e "  ${GREEN}(sans option)${NC}  Installe ou met à jour la stack"
    echo -e "  ${YELLOW}--howto${NC}       Affiche le guide d'utilisation"
    echo -e "  ${YELLOW}--uninstall${NC}   Supprime les données et conteneurs"
}

show_howto() {
    echo -e "${BOLD}${CYAN}COMMENT DÉMARRER VOTRE IA COMPANY${NC}\n"
    echo -e "1. Accès Paperclip : ${GREEN}http://localhost:3100${NC}"
    echo -e "2. Accès OpenClaw  : ${GREEN}http://localhost:8000${NC}"
    echo -e "3. Logs : ${CYAN}cd $INSTALL_DIR && $DOCKER_CMD logs -f${NC}"
}

# --- LOGIQUE DE COMMANDE ---

case "$1" in
    --help) show_help; exit 0 ;;
    --howto) show_howto; exit 0 ;;
    --uninstall)
        echo -e "${RED}${BOLD}🗑️ DÉINSTALLATION COMPLÈTE${NC}"
        if [ -d "$INSTALL_DIR" ]; then
            cd "$INSTALL_DIR"
            read -p "Confirmer la suppression ? (y/N) : " confirm
            if [[ $confirm =~ ^[Yy] ]]; then
                $DOCKER_CMD -p ai-company-swarm down -v   # <-- add -p ai-company-swarm
                cd .. && rm -rf "$INSTALL_DIR"
                echo -e "${GREEN}✅ Tout a été nettoyé.${NC}"
            fi
        fi
        exit 0
        ;;
esac

# --- INSTALLATION ---

echo -e "${BOLD}${CYAN}🚀 Initialisation AI Company dans $INSTALL_DIR${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Détection Architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) PLATFORM="linux/amd64" ;;
    aarch64|arm64) PLATFORM="linux/arm64" ;;
    *) PLATFORM="linux/amd64" ;;
esac

# --- GESTION DES SECRETS ---
if [ -f .env ]; then
    echo "♻️  Chargement des secrets existants..."
    # Cette ligne est CRUCIALE pour que Bash puisse lire les variables
    export $(grep -v '^#' .env | xargs)
else
    echo "🔑 Génération des nouveaux secrets..."
    PG_PASS=$(openssl rand -hex 12)
    QDRANT_KEY=$(openssl rand -hex 16)
    AUTH_SECRET=$(openssl rand -base64 32)
    PROXY_KEY="sk-swarm-$(openssl rand -hex 8)"
    GATEWAY_TOKEN=$(openssl rand -hex 16)

    cat > .env << EOF
POSTGRES_PASSWORD=${PG_PASS}
POSTGRES_USER=paperclip
POSTGRES_DB=paperclip
QDRANT_API_KEY=${QDRANT_KEY}
PAPERCLIP_AUTH_SECRET=${AUTH_SECRET}
LITELLM_MASTER_KEY=${PROXY_KEY}
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
EOF
    export $(grep -v '^#' .env | xargs)
fi

# --- CONFIG LITELLM ---
cat > litellm-config.yaml << EOF
model_list:
  - model_name: "$OLLAMA_MODEL"
    litellm_params:
      model: "ollama_chat/$OLLAMA_MODEL"
      api_base: "http://host.docker.internal:$OLLAMA_PORT"
  - model_name: "$EMBEDDING_MODEL"
    litellm_params:
      model: "ollama/$EMBEDDING_MODEL"
      api_base: "http://host.docker.internal:$OLLAMA_PORT"
EOF

# --- DOCKER COMPOSE ---
# Note : On utilise les variables directement ici car elles sont maintenant 'exportées'
cat > docker-compose.yml << EOF
version: '3.8'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_DB=\${POSTGRES_DB}
    volumes: ["postgres_data:/var/lib/postgresql/data"]
    restart: unless-stopped

  llm-proxy:
    image: ghcr.io/berriai/litellm:main-latest
    platform: ${PLATFORM}
    ports: ["${PORT_LITELLM}:4000"]
    environment:
      - LITELLM_MASTER_KEY=\${LITELLM_MASTER_KEY}
      - DATABASE_URL=postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@postgres:5432/\${POSTGRES_DB}
      - PRISMA_CLI_BINARY_TARGETS=debian-openssl-3.0.x
    volumes: ["./litellm-config.yaml:/app/config.yaml"]
    extra_hosts: ["host.docker.internal:host-gateway"]
    command: ["--config", "/app/config.yaml", "--port", "4000"]
    depends_on: [postgres]
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:latest
    platform: ${PLATFORM}
    ports: ["${PORT_QDRANT}:6333"]
    environment:
      - QDRANT__SERVICE__API_KEY=\${QDRANT_API_KEY}
    volumes: ["qdrant_storage:/qdrant/storage"]
    restart: unless-stopped

  browser:
    image: browserless/chrome:latest
    platform: ${PLATFORM}
    environment:
      - MAX_CONCURRENT_SESSIONS=10
    restart: unless-stopped

  paperclip:
    image: reeoss/paperclipai-paperclip:latest
    platform: ${PLATFORM}
    ports: ["${PORT_PAPERCLIP}:3100"]
    environment:
      - DATABASE_URL=postgres://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@postgres:5432/\${POSTGRES_DB}
      - OPENAI_API_BASE=http://llm-proxy:4000/v1
      - OPENAI_API_KEY=\${LITELLM_MASTER_KEY}
      - QDRANT_URL=http://qdrant:6333
      - QDRANT_API_KEY=\${QDRANT_API_KEY}
      - BETTER_AUTH_SECRET=\${PAPERCLIP_AUTH_SECRET}
      - PAPERCLIP_PUBLIC_URL=http://localhost:3100
      - EMBEDDING_MODEL=${EMBEDDING_MODEL}
      - OPENCLAW_GATEWAY_TOKEN=\${OPENCLAW_GATEWAY_TOKEN}
    depends_on: [postgres, llm-proxy, qdrant]
    restart: unless-stopped

  openclaw:
    image: coollabsio/openclaw:latest
    platform: ${PLATFORM}
    ports: ["${PORT_OPENCLAW}:8000"]
    environment:
      - OPENAI_API_BASE=http://llm-proxy:4000/v1
      - OPENAI_API_KEY=\${LITELLM_MASTER_KEY}
      - OPENCLAW_VECTOR_DB_URL=http://qdrant:6333
      - OPENCLAW_VECTOR_DB_API_KEY=\${QDRANT_API_KEY}
      - OPENCLAW_PRIMARY_MODEL=openai/${OLLAMA_MODEL}
      - OPENCLAW_EMBEDDING_MODEL=openai/${EMBEDDING_MODEL}
      - OPENCLAW_GATEWAY_TOKEN=\${OPENCLAW_GATEWAY_TOKEN}
      - OPENCLAW_BROWSER_URL=http://browser:3000
    depends_on: [llm-proxy, qdrant, browser]
    restart: unless-stopped

volumes:
  postgres_data:
  qdrant_storage:
EOF


# Lancement
echo -e "⏳ Démarrage des conteneurs..."
$DOCKER_CMD -p ai-company-swarm up -d

echo -e "Waiting for services to be ready..."
sleep 15 # Attente minimale pour Postgres et LiteLLM

docker ps

echo -e "### COMMANDE OPTIONNELLE (si agent ne demarre pas dans paperclip)"
echo -e "docker exec -u root ai-company-swarm-paperclip-1 npm install -g @paperclipai/agent"

# --- RÉCAPITULATIF DES SERVICES ---
echo -e "\n${BOLD}${YELLOW}====================================================${NC}"
echo -e "      🚀 AI COMPANY SWARM EST OPÉRATIONNELLE"
echo -e "${BOLD}${YELLOW}====================================================${NC}"

echo -e "\n${BOLD}🌐 INTERFACES UTILISATEUR :${NC}"
echo -e "  🔗 Paperclip (Gestion Agents) : ${CYAN}http://localhost:3100${NC}"
echo -e "  🔗 OpenClaw (Gateway & Tools) : ${CYAN}http://localhost:8000${NC}"

echo -e "\n${BOLD}🛠️ INFRASTRUCTURE & BACKEND :${NC}"
echo -e "  📊 LiteLLM (Modèles & Proxy)  : ${CYAN}http://localhost:8001${NC}"
echo -e "  🧠 Qdrant (Mémoire Vectorielle): ${CYAN}http://localhost:6333/dashboard${NC}"
echo -e "  🦙 Ollama (Moteur local)      : ${CYAN}http://localhost:11434${NC}"

echo -e "\n${BOLD}📂 ADMINISTRATION :${NC}"
echo -e "  📁 Dossier d'installation     : ${YELLOW}$INSTALL_DIR${NC}"
echo -e "  🔑 Clés et secrets (.env)     : ${RED}cat $INSTALL_DIR/.env${NC}"
echo -e "  📜 Voir les logs en direct    : ${GREEN}docker compose -p ai-company-swarm logs -f${NC}"

echo -e "\n${BOLD}⚡ COMMANDES UTILES :${NC}"
echo -e "  🔄 Redémarrer : ${YELLOW}docker compose -p ai-company-swarm restart${NC}"
echo -e "  🛑 Arrêter    : ${YELLOW}docker compose -p ai-company-swarm stop${NC}"
echo -e "\n${GREEN}${BOLD}✅ STACK AI COMPANY DÉPLOYÉE !${NC}"
# --- SETUP ---
cp -f $MY_PATH/install-ai-company.md ~/.zen/ai-company/
echo -e "${YELLOW}⚙️ Configuration initiale de Paperclip :${NC}"
echo -e "Pour bootstrap l'admin, lance : cd ~/.zen/ai-company/"
echo -e "DOC : install-ai-company.md"
echo -e "MIGRATE DB : docker exec -it ai-company-swarm-paperclip-1 npx prisma migrate deploy --schema packages/db/prisma/schema.prisma"
echo -e "PAPERCLIP INIT : docker exec -it ai-company-swarm-paperclip-1 pnpm paperclipai auth bootstrap-ceo"
echo -e "Puis :"
echo -e "docker exec -it ai-company-swarm-paperclip-1 pnpm paperclipai onboard"