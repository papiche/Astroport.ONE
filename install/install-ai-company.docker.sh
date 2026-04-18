#!/bin/bash

# =============================================================================
# install-ai-company.sh - UPLANET ZEN[0] Swarm AI Stack Manager
# Architecture : Multi-arch (x86_64 / aarch64)
#
# Stack principale (docker-compose.yml) :
#   Open WebUI  (8000) — Interface web IA pour les membres (Humain ↔ IA)
#   Mirofish    (5050) — Simulation d'opinion (Mem0 + Qdrant + Nostr)
#   Qdrant      (6333) — Base vectorielle souveraine (api-key = sha256 UPLANETNAME)
#   Vane        (3002) — Recherche IA augmentée (ex-Perplexica)
#   Ollama      (11434, sur hôte) — Moteur LLM local (non inclus dans Docker)
#
# Stack secondaire (dify/docker/docker-compose.yml) :
#   Dify.ai     (8010) — Agents & workflows IA (Nostr, Telegram…)
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
PORT_MIROFISH=${PORT_MIROFISH:-5050}
PORT_VANE=${PORT_VANE:-3002}
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
    echo -e "  https://docs.docker.com/engine/install/"
    exit 1
fi

case "$1" in
    --help|-h)
        cat << HELP
${BOLD}${CYAN}AI Company Stack Manager — UPlanet ZEN[0] (Mem0 + Qdrant)${NC}

Usage: install-ai-company.docker.sh [--uninstall [--purge]] [--check]

  (sans argument)   Installer / mettre à jour la stack
  --check           Vérifier la compatibilité matérielle sans installer
  --uninstall       Arrêter et supprimer les containers
  --uninstall --purge  + supprimer les volumes/données

Stack installée :
  open-webui  :${PORT_WEBUI:-8000}   Interface chat membres (Ollama backend)
  mirofish    :${PORT_MIROFISH:-5050} Simulation opinion (Mem0 + Qdrant)
  qdrant      :${PORT_QDRANT:-6333}   Base vectorielle souveraine (partagée)
  vane        :${PORT_VANE:-3002}    Recherche IA augmentée (ex-Perplexica)
  dify        :${PORT_DIFY:-8010}    Agents & workflows (stack séparée)

LLM : Ollama sur l'hôte (:${OLLAMA_PORT}) — non inclus dans Docker.
HELP
        exit 0 ;;

    --uninstall)
        echo -e "${RED}${BOLD}🗑️ DÉSINSTALLATION AI COMPANY${NC}"
        [[ "$2" == "--purge" ]] && echo -e "${YELLOW}  Mode --purge : volumes et données supprimés${NC}"
        if [[ -d "$INSTALL_DIR" ]]; then
            cd "$INSTALL_DIR"
            if [[ "$2" == "--purge" ]]; then
                $DOCKER_CMD down -v 2>/dev/null || true
                [[ -d "dify/docker" ]] && { cd dify/docker && $DOCKER_CMD down -v 2>/dev/null || true; cd "$INSTALL_DIR"; }
                cd "$HOME/.zen" && rm -rf "$INSTALL_DIR"
                echo -e "${GREEN}✅ Stack et données supprimées.${NC}"
            else
                $DOCKER_CMD down 2>/dev/null || true
                [[ -d "dify/docker" ]] && { cd dify/docker && $DOCKER_CMD down 2>/dev/null || true; }
                echo -e "${GREEN}✅ Containers arrêtés (données préservées dans $INSTALL_DIR).${NC}"
                echo    "   Pour tout supprimer : $0 --uninstall --purge"
            fi
        else
            echo "ℹ️  $INSTALL_DIR inexistant, rien à faire."
        fi
        exit 0 ;;

    --check)
        _SCORE=0; _AVAIL=0
        _CACHE="$HOME/.zen/tmp/$(ipfs id -f '<id>' 2>/dev/null)/heartbox_analysis.json"
        [[ -s "$_CACHE" ]] && {
            _SCORE=$(jq -r '.capacities.power_score        // 0' "$_CACHE" 2>/dev/null || echo 0)
            _AVAIL=$(jq -r '.capacities.available_space_gb // 0' "$_CACHE" 2>/dev/null || echo 0)
        }
        echo -e "${BOLD}=== COMPATIBILITÉ MATÉRIELLE ===${NC}"
        echo "  Power-Score    : ${_SCORE}"
        echo "  Espace disque  : ${_AVAIL} Go"
        command -v docker >/dev/null && echo "  Docker         : ✅" || echo -e "  Docker         : ${RED}❌ non installé${NC}"
        command -v ollama >/dev/null && echo "  Ollama         : ✅" || echo -e "  Ollama         : ${YELLOW}⚠️  non installé${NC}"
        ss -tln 2>/dev/null | grep -q ':11434 ' && echo "  Ollama actif   : ✅" || echo -e "  Ollama actif   : ${YELLOW}⚠️  inactif${NC}"
        echo ""
        [[ ${_SCORE:-0} -ge 41 ]] && echo -e "  ${GREEN}🔥 Brain — stack complète recommandée${NC}" \
        || [[ ${_SCORE:-0} -ge 11 ]] && echo -e "  ${YELLOW}⚡ Standard — open-webui + qdrant OK, éviter gros modèles${NC}" \
        || echo -e "  ${RED}🌿 Light — utiliser le swarm : astrosystemctl connect ollama${NC}"
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
MIROFISH_MODEL=${MIROFISH_MODEL:-gemma3:12b}
EOF
    source .env
fi

# --- 0. VÉRIFICATION MATÉRIELLE (non bloquante) ---
_CACHE="$HOME/.zen/tmp/$(ipfs id -f '<id>' 2>/dev/null)/heartbox_analysis.json"
_SCORE=0
[[ -s "$_CACHE" ]] && _SCORE=$(jq -r '.capacities.power_score // 0' "$_CACHE" 2>/dev/null || echo 0)
if [[ ${_SCORE:-0} -lt 11 ]]; then
    echo -e "${YELLOW}⚠️  Power-Score faible (${_SCORE}/10) — stack IA lourde pour cette machine.${NC}"
    echo -e "   Utilisez ${BOLD}$0 --check${NC} pour le détail."
    echo -e "   Continuer quand même ? [y/N] "
    read -r _CONFIRM
    [[ "$_CONFIRM" != "y" && "$_CONFIRM" != "Y" ]] && exit 1
fi
if ! ss -tln 2>/dev/null | grep -q ':11434 '; then
    echo -e "${YELLOW}⚠️  Ollama inactif sur :11434 — les services IA ne fonctionneront pas sans LLM local.${NC}"
    echo -e "   Démarrez Ollama : ${BOLD}ollama serve &${NC}   ou   ${BOLD}systemctl start ollama${NC}"
fi

# --- 1. DOCKER COMPOSE : OPEN WEBUI + MIROFISH (Mem0) + QDRANT + VANE ---
cat > docker-compose.yml << EOF
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: ai-company-webui
    ports:
      - "${PORT_WEBUI}:8080"
    volumes:
      - ./webui_data:/app/backend/data
    environment:
      - WEBUI_SECRET_KEY=\${WEBUI_SECRET_KEY}
      - ENABLE_RAG_LOCAL_WEB_FETCH=True
      - ENABLE_RAG_WEB_SEARCH=True
      - OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - ai-net
    restart: unless-stopped

  mirofish:
    image: ghcr.io/666ghj/mirofish:latest
    container_name: ai-company-mirofish
    ports:
      - "${PORT_MIROFISH}:5000"
    environment:
      - LLM_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}/v1
      - LLM_API_KEY=ollama
      - LLM_MODEL_NAME=\${MIROFISH_MODEL}
      - MEM0_VECTOR_STORE=qdrant
      - MEM0_QDRANT_URL=http://qdrant:6333
      - MEM0_QDRANT_API_KEY=\${QDRANT_API_KEY}
      - MEM0_COLLECTION=mirofish-agents
      - MEM0_EMBEDDING_MODEL=nomic-embed-text
      - MEM0_EMBEDDING_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}
      - NOSTR_RELAY=ws://host.docker.internal:7777
    extra_hosts:
      - "host.docker.internal:host-gateway"
    depends_on:
      - qdrant
    volumes:
      - ./mirofish_data:/app/data
    networks:
      - ai-net
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:latest
    container_name: ai-company-qdrant
    ports:
      - "${PORT_QDRANT}:6333"
    environment:
      - QDRANT__SERVICE__API_KEY=\${QDRANT_API_KEY}
      - QDRANT__SERVICE__ENABLE_CORS=true
    volumes:
      - qdrant_storage:/qdrant/storage
    networks:
      - ai-net
    restart: unless-stopped

  vane:
    image: ghcr.io/itzcrazzykns/vane:main
    container_name: ai-company-vane
    ports:
      - "${PORT_VANE}:3001"
    environment:
      - OLLAMA_API_URL=http://host.docker.internal:${OLLAMA_PORT}/api
      - SIMILARITY_MEASURE=cosine
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./vane_data:/home/perplexica/data
    networks:
      - ai-net
    restart: unless-stopped

volumes:
  qdrant_storage:

networks:
  ai-net:
    driver: bridge
EOF

# --- 2. INSTALLATION DE DIFY.AI ---
echo -e "⏳ Téléchargement de Dify.ai..."
if [ ! -d "dify" ]; then
    git clone --depth 1 https://github.com/langgenius/dify.git dify
fi

cd dify/docker
if [ ! -f .env ]; then
    cp .env.example .env
fi

# Always ensure the ports are set to our variables
sed -i "s/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=${PORT_DIFY}/" .env
sed -i "s/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=8444/" .env

# --- LANCEMENT DE LA STACK ---
echo -e "⏳ Démarrage de Open WebUI et Qdrant..."
cd "$INSTALL_DIR"
$DOCKER_CMD up -d

echo -e "⏳ Démarrage de l'orchestrateur Dify.ai (peut prendre quelques minutes)..."
cd "$INSTALL_DIR/dify/docker"
$DOCKER_CMD up -d

# --- RÉCAPITULATIF ---
echo -e "\n${BOLD}${YELLOW}====================================================${NC}"
echo -e "      🚀 AI COMPANY SWARM EST OPÉRATIONNELLE"
echo -e "${BOLD}${YELLOW}====================================================${NC}"
echo -e "\n${BOLD}🌐 INTERFACES UTILISATEUR :${NC}"
echo -e "  🧑 Open WebUI (chat membres)     : ${CYAN}http://localhost:${PORT_WEBUI}${NC}"
echo -e "  🐟 Mirofish  (agents Mem0+Nostr) : ${CYAN}http://localhost:${PORT_MIROFISH}${NC}"
echo -e "  🧠 Qdrant    (base vectorielle)  : ${CYAN}http://localhost:${PORT_QDRANT}/dashboard${NC}"
echo -e "  🔍 Vane      (recherche IA)      : ${CYAN}http://localhost:${PORT_VANE}${NC}"
echo -e "  🤖 Dify.ai   (agents & workflows): ${CYAN}http://localhost:${PORT_DIFY}${NC}"
echo -e "\n${BOLD}💡 PREMIÈRE ÉTAPE :${NC}"
echo -e "  1. Vérifier qu'Ollama tourne et possède le modèle configuré :"
echo -e "     ${BOLD}ollama list${NC}   →   modèle attendu : ${BOLD}${MIROFISH_MODEL:-gemma3:12b}${NC}"
echo -e "     Pour l'installer : ${BOLD}ollama pull ${MIROFISH_MODEL:-gemma3:12b}${NC}"
echo -e "     Pour l'embeddings Mem0 : ${BOLD}ollama pull nomic-embed-text${NC}"
echo -e "  2. (Optionnel) Ouvrez Dify.ai sur http://localhost:${PORT_DIFY} et créez le compte admin."
echo -e "     Dans Dify : Paramètres → Fournisseurs de Modèles → Ollama"
echo -e "     URL de base : http://host.docker.internal:${OLLAMA_PORT}"
echo -e "\n${BOLD}🔧 GESTION :${NC}"
echo -e "  Arrêter   : ${BOLD}$0 --uninstall${NC}"
echo -e "  Supprimer : ${BOLD}$0 --uninstall --purge${NC}"
echo -e "  Vérifier  : ${BOLD}$0 --check${NC}"
echo -e "\n${GREEN}${BOLD}✅ STACK AI COMPANY (Mem0 + Qdrant) DÉPLOYÉE !${NC}"