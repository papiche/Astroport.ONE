#!/bin/bash

# =============================================================================
# install-ai-company.sh - UPLANET ZEN[0] Swarm AI Stack Manager (Dify Edition)
# Architecture : Multi-arch (x86_64 / aarch64)
#
# Stack :
#   Open WebUI (8000) — Interface web IA pour les membres (Humain ↔ IA)
#   Dify.ai    (8010) — Workflows et Agents d'automatisation (Nostr, Telegram...)
#   Qdrant     (6333) — Base vectorielle autonome (api-key = sha256 UPLANETNAME)
#   Ollama     (11434, sur hôte) — Moteur LLM local
# =============================================================================

set -e

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

# --- CONFIGURATION ---
INSTALL_DIR="$HOME/.zen/ai-company"
PORT_WEBUI=${PORT_WEBUI:-8000}
PORT_DIFY=${PORT_DIFY:-8010}
PORT_QDRANT=${PORT_QDRANT:-6333}
OLLAMA_PORT=11434

# Couleurs
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# --- DETECTION DOCKER COMPOSE ---
if docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
else
    echo -e "${RED}Erreur: Docker Compose n'est pas installé.${NC}"
    exit 1
fi

case "$1" in
    --help|-h)
        echo -e "${BOLD}${CYAN}AI Company Stack Manager (Dify + Open WebUI Edition)${NC}"
        exit 0 ;;
    --uninstall)
        echo -e "${RED}${BOLD}🗑️ DÉINSTALLATION COMPLÈTE${NC}"
        if [ -d "$INSTALL_DIR" ]; then
            cd "$INSTALL_DIR"
            $DOCKER_CMD down -v 2>/dev/null || true
            [ -d "dify/docker" ] && cd dify/docker && $DOCKER_CMD down -v 2>/dev/null || true
            cd "$HOME/.zen" && rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}✅ Tout a été nettoyé.${NC}"
        fi
        exit 0 ;;
esac

echo -e "${BOLD}${CYAN}🚀 Initialisation AI Company (Dify + Open WebUI) dans $INSTALL_DIR${NC}"
mkdir -p "$INSTALL_DIR/webui_data"
cd "$INSTALL_DIR"

if [ -f .env ]; then
    source .env
else
    WEBUI_SECRET=$(openssl rand -hex 32)
    if [[ -n "$UPLANETNAME" ]]; then
        QDRANT_KEY=$(echo -n "$UPLANETNAME" | openssl dgst -sha256 | sed 's/^.* //')
    else
        QDRANT_KEY=$(openssl rand -hex 32)
    fi

    cat > .env << EOF
WEBUI_SECRET_KEY=${WEBUI_SECRET}
QDRANT_API_KEY=${QDRANT_KEY}
EOF
    source .env
fi

# --- 1. DOCKER COMPOSE : OPEN WEBUI + QDRANT ---
cat > docker-compose.yml << EOF
version: '3.8'
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: ai-company-webui
    ports:["${PORT_WEBUI}:8080"]
    volumes: ["./webui_data:/app/backend/data"]
    environment:
      - 'WEBUI_SECRET_KEY=\${WEBUI_SECRET_KEY}'
      - 'ENABLE_RAG_LOCAL_WEB_FETCH=True'
      - 'OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}'
    extra_hosts:["host.docker.internal:host-gateway"]
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:latest
    container_name: ai-company-qdrant
    ports: ["${PORT_QDRANT}:6333"]
    environment:
      - QDRANT__SERVICE__API_KEY=\${QDRANT_API_KEY}
    volumes:["qdrant_storage:/qdrant/storage"]
    restart: unless-stopped

volumes:
  qdrant_storage:
EOF

# --- 2. INSTALLATION DE DIFY.AI ---
echo -e "⏳ Téléchargement de Dify.ai..."
if [ ! -d "dify" ]; then
    git clone --depth 1 https://github.com/langgenius/dify.git dify
fi

cd dify/docker
if [ ! -f .env ]; then
    cp .env.example .env
    # On modifie le port Nginx par défaut de Dify (80) vers 8010
    sed -i "s/EXPOSE_NGINX_PORT=80/EXPOSE_NGINX_PORT=${PORT_DIFY}/g" .env
    sed -i "s/EXPOSE_NGINX_SSL_PORT=443/EXPOSE_NGINX_SSL_PORT=8444/g" .env
fi

# --- LANCEMENT DE LA STACK ---
echo -e "⏳ Démarrage de Open WebUI et Qdrant..."
cd "$INSTALL_DIR"
$DOCKER_CMD up -d

echo -e "⏳ Démarrage de l'orchestrateur Dify.ai (peut prendre quelques minutes)..."
cd "$INSTALL_DIR/dify/docker"
$DOCKER_CMD up -d

# --- RÉCAPITULATIF ---
echo -e "\n${BOLD}${YELLOW}====================================================${NC}"
echo -e "      🚀 AI COMPANY SWARM (DIFY) EST OPÉRATIONNELLE"
echo -e "${BOLD}${YELLOW}====================================================${NC}"
echo -e "\n${BOLD}🌐 INTERFACES UTILISATEUR :${NC}"
echo -e "  🧑‍💻 Open WebUI (Pour les membres) : ${CYAN}http://localhost:8000${NC}"
echo -e "  🤖 Dify.ai (Création d'agents)   : ${CYAN}http://localhost:8010${NC}"
echo -e "  🧠 Qdrant (Base vectorielle)     : ${CYAN}http://localhost:6333/dashboard${NC}"
echo -e "\n${BOLD}💡 PREMIÈRE ÉTAPE :${NC}"
echo -e "  1. Ouvrez Dify.ai sur http://localhost:8010 et créez le compte administrateur."
echo -e "  2. Dans Dify : Nom d'utilisateur → Paramètres → Fournisseurs de Modèles → Ollama."
echo -e "     (URL de base : http://host.docker.internal:11434)"
echo -e "\n${GREEN}${BOLD}✅ STACK AI COMPANY (Dify.ai) DÉPLOYÉE !${NC}"