#!/bin/bash

# =============================================================================
# install-ai-company.sh - UPLANET ZEN[0] Swarm AI Stack Manager
# Architecture : Multi-arch (x86_64 / aarch64)
#
# Stack :
#   Paperclip  (3100) — Gestion d'agents IA
#   Open WebUI (8000) — Interface web IA (remplace OpenClaw)
#   LiteLLM    (8001) — Proxy multi-modèles (OpenAI-compatible)
#   Qdrant     (6333) — Base vectorielle (api-key = UPLANETNAME)
#   Ollama     (11434, sur hôte) — Moteur LLM local
# =============================================================================

set -e

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
## Charger UPLANETNAME depuis my.sh (QDRANT_API_KEY = UPLANETNAME pour cohérence constellation)
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

# --- CONFIGURATION ---
INSTALL_DIR="$HOME/.zen/ai-company"
OLLAMA_PORT=11434
OLLAMA_MODEL="gemma3"
EMBEDDING_MODEL="nomic-embed-text"
LLM_CEO_MODEL="claude-sonnet-4.6"

# Couleurs
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# --- CONFIGURATION DES PORTS ---
# Aucun conflit avec les autres services Astroport
PORT_PAPERCLIP=${PORT_PAPERCLIP:-3100}   # Paperclip agents
PORT_WEBUI=${PORT_WEBUI:-8000}           # Open WebUI interface
PORT_LITELLM=${PORT_LITELLM:-8010}       # LiteLLM proxy (8010 — évite le conflit avec NextCloud Apache sur 8001)
PORT_QDRANT=${PORT_QDRANT:-6333}         # Qdrant vector DB

# --- DETECTION DOCKER COMPOSE ---
if docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo -e "${RED}Erreur: Docker Compose n'est pas installé.${NC}"
    exit 1
fi

# --- FONCTIONS D'AIDE ---
show_help() {
    echo -e "${BOLD}${CYAN}AI Company Stack Manager (Open WebUI Edition)${NC}"
    echo -e "Ce script installe une infrastructure IA privée complète.\n"
    echo -e "${BOLD}COMMANDES :${NC}"
    echo -e "  ${GREEN}(sans option)${NC}  Installe ou met à jour la stack"
    echo -e "  ${YELLOW}--howto${NC}       Affiche le guide d'utilisation"
    echo -e "  ${YELLOW}--uninstall${NC}   Supprime les données et conteneurs"
    echo -e "  ${YELLOW}--help${NC}        Affiche cette aide"
}

show_howto() {
    echo -e "${BOLD}${CYAN}COMMENT DÉMARRER VOTRE IA COMPANY${NC}\n"
    echo -e "1. Open WebUI (interface principale) : ${GREEN}http://localhost:8000${NC}"
    echo -e "   → Créez un compte admin à la première connexion"
    echo -e "   → Configurez Ollama via Paramètres → Connexions"
    echo -e ""
    echo -e "2. Paperclip (agents IA)    : ${GREEN}http://localhost:3100${NC}"
    echo -e "3. LiteLLM (proxy modèles)  : ${GREEN}http://localhost:8001${NC}"
    echo -e "4. Qdrant (base vectorielle): ${GREEN}http://localhost:6333/dashboard${NC}"
    echo -e ""
    echo -e "Accès distant (SSH tunnel) :"
    echo -e "  ${YELLOW}ssh -L 8000:127.0.0.1:8000 -L 3100:127.0.0.1:3100 user@VOTRE_IP${NC}"
    echo -e "  Puis : http://localhost:8000"
    echo -e ""
    echo -e "Logs : cd ~/.zen/ai-company && $DOCKER_CMD -p ai-company-swarm logs -f"
}

# --- LOGIQUE DE COMMANDE ---
case "$1" in
    --help|-h) show_help; exit 0 ;;
    --howto)   show_howto; exit 0 ;;
    --uninstall)
        echo -e "${RED}${BOLD}🗑️ DÉINSTALLATION COMPLÈTE${NC}"
        if [ -d "$INSTALL_DIR" ]; then
            cd "$INSTALL_DIR"
            read -p "Confirmer la suppression des données ? (y/N) : " confirm
            if [[ $confirm =~ ^[Yy] ]]; then
                $DOCKER_CMD -p ai-company-swarm down -v
                cd .. && rm -rf "$INSTALL_DIR"
                echo -e "${GREEN}✅ Tout a été nettoyé.${NC}"
            fi
        fi
        exit 0
        ;;
esac

# --- INSTALLATION ---
echo -e "${BOLD}${CYAN}🚀 Initialisation AI Company (Open WebUI) dans $INSTALL_DIR${NC}"
mkdir -p "$INSTALL_DIR/paperclip_data" "$INSTALL_DIR/webui_data"
cd "$INSTALL_DIR"

# Détection Architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)       PLATFORM="linux/amd64" ;;
    aarch64|arm64) PLATFORM="linux/arm64" ;;
    *)             PLATFORM="linux/amd64" ;;
esac

# --- GESTION DES SECRETS ---
if [ -f .env ]; then
    echo "♻️  Chargement des secrets existants..."
    set -a
    source .env
    set +a
else
    echo "🔑 Génération des nouveaux secrets..."
    PG_PASS=$(openssl rand -hex 12)
    AUTH_SECRET=$(openssl rand -base64 32)
    PROXY_KEY="sk-swarm-$(openssl rand -hex 8)"
    WEBUI_SECRET=$(openssl rand -hex 32)

    ## QDRANT_API_KEY = UPLANETNAME pour cohérence constellation
    ## → toutes les stations du même essaim UPlanet ẐEN partagent la même clé Qdrant
    ## → ORIGIN (000...000) = clé commune sandbox (non critique)
    if [[ -n "$UPLANETNAME" && "$UPLANETNAME" != "0000000000000000000000000000000000000000000000000000000000000000" ]]; then
        QDRANT_KEY="${UPLANETNAME}"
        echo "🔑 Qdrant API Key = UPLANETNAME (${QDRANT_KEY:0:8}... — clé de constellation)"
    elif [[ -n "$UPLANETNAME" ]]; then
        QDRANT_KEY="${UPLANETNAME}"
        echo "ℹ️  Qdrant API Key = UPLANETNAME ORIGIN (sandbox partagé)"
    else
        QDRANT_KEY=$(openssl rand -hex 16)
        echo "⚠️  UPLANETNAME absent — Qdrant API Key aléatoire"
    fi

# (Extrait à ajouter lors de la création du .env)
    echo "🔑 Configuration OpenRouter (pour le modèle CEO)"
    read -p "Entrez votre clé API OpenRouter (laissez vide pour ignorer) : " OR_KEY

    cat > .env << EOF
POSTGRES_PASSWORD=${PG_PASS}
POSTGRES_USER=paperclip
POSTGRES_DB=paperclip
QDRANT_API_KEY=${QDRANT_KEY}
PAPERCLIP_AUTH_SECRET=${AUTH_SECRET}
LITELLM_MASTER_KEY=${PROXY_KEY}
WEBUI_SECRET_KEY=${WEBUI_SECRET}
OPENROUTER_API_KEY=${OR_KEY}
LLM_CEO_MODEL=${LLM_CEO_MODEL}
EOF
    export $(grep -v '^#' .env | xargs)
fi

DOCKER_BRIDGE_IP=$(ip addr show docker0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "172.17.0.1")
echo -e "${CYAN}📡 Bridge Docker (accès Ollama depuis conteneurs) : ${DOCKER_BRIDGE_IP}${NC}"

# --- CONFIG LITELLM ---
cat > litellm-config.yaml << EOF
model_list:
  - model_name: "openai/$OLLAMA_MODEL"
    litellm_params:
      model: "ollama_chat/$OLLAMA_MODEL"
      api_base: "http://$DOCKER_BRIDGE_IP:$OLLAMA_PORT"
  - model_name: "$OLLAMA_MODEL"
    litellm_params:
      model: "ollama_chat/$OLLAMA_MODEL"
      api_base: "http://$DOCKER_BRIDGE_IP:$OLLAMA_PORT"
  - model_name: "openai/$EMBEDDING_MODEL"
    litellm_params:
      model: "ollama/$EMBEDDING_MODEL"
      api_base: "http://$DOCKER_BRIDGE_IP:$OLLAMA_PORT"
  - model_name: "$EMBEDDING_MODEL"
    litellm_params:
      model: "ollama/$EMBEDDING_MODEL"
      api_base: "http://$DOCKER_BRIDGE_IP:$OLLAMA_PORT"

  # --- Modèles Distants (OpenRouter) ---
  - model_name: "$LLM_CEO_MODEL"
    litellm_params:
      model: "openrouter/anthropic/$LLM_CEO_MODEL"
      api_key: "os.environ/OPENROUTER_API_KEY"

EOF

# --- DOCKER COMPOSE ---
cat > docker-compose.yml << EOF
version: '3.8'
services:

  ## PostgreSQL — base de données Paperclip
  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_USER=paperclip
      - POSTGRES_DB=paperclip
    volumes: ["postgres_data:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U paperclip -d paperclip"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  ## LiteLLM — proxy multi-modèles (OpenAI-compatible)
  ## Port hôte 8001 ⚠️ même que NextCloud Apache — profils mutuellement exclusifs
  llm-proxy:
    image: ghcr.io/berriai/litellm:main-latest
    platform: ${PLATFORM}
    ports: ["${PORT_LITELLM}:4000"]
    environment:
      - LITELLM_MASTER_KEY=\${LITELLM_MASTER_KEY}
      - DATABASE_URL=postgresql://paperclip:\${POSTGRES_PASSWORD}@postgres:5432/litellm
      - OPENROUTER_API_KEY=\${OPENROUTER_API_KEY}
      - PRISMA_CLI_BINARY_TARGETS=debian-openssl-3.0.x
    volumes: ["./litellm-config.yaml:/app/config.yaml"]
    extra_hosts: ["host.docker.internal:host-gateway"]
    command: ["--config", "/app/config.yaml", "--port", "4000"]
    depends_on: [postgres]
    restart: unless-stopped

  ## Qdrant — base vectorielle (api-key = UPLANETNAME pour cohérence constellation)
  qdrant:
    image: qdrant/qdrant:latest
    platform: ${PLATFORM}
    ports: ["${PORT_QDRANT}:6333"]
    environment:
      - QDRANT__SERVICE__API_KEY=\${QDRANT_API_KEY}
    volumes: ["qdrant_storage:/qdrant/storage"]
    restart: unless-stopped

  ## Paperclip — gestion d'agents IA
  paperclip:
    image: reeoss/paperclipai-paperclip:latest
    user: "1000:1000"
    platform: ${PLATFORM}
    ports: ["${PORT_PAPERCLIP}:3100"]
    volumes: ["./paperclip_data:/paperclip/instances"]
    env_file:
      - .env 
    environment:
      - DATABASE_URL=postgres://paperclip:\${POSTGRES_PASSWORD}@postgres:5432/paperclip
      - OPENAI_API_BASE=http://llm-proxy:4000/v1
      - OPENAI_API_KEY=\${LITELLM_MASTER_KEY}
      - QDRANT_URL=http://qdrant:6333
      - QDRANT_API_KEY=\${QDRANT_API_KEY}
      - BETTER_AUTH_SECRET=\${PAPERCLIP_AUTH_SECRET}
      - PAPERCLIP_PUBLIC_URL=http://localhost:3100
      - EMBEDDING_MODEL=${EMBEDDING_MODEL}
    depends_on: [postgres, llm-proxy, qdrant]
    restart: unless-stopped

  ## Open WebUI — interface IA complète (RAG, multi-modèles, documents)
  ## Remplace OpenClaw — plus actif, supporte Ollama nativement
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: ai-company-webui
    platform: ${PLATFORM}
    ports: ["${PORT_WEBUI}:8080"]
    volumes: ["./webui_data:/app/backend/data"]
    environment:
      - 'OPENAI_API_BASE_URL=http://llm-proxy:4000/v1'
      - 'OPENAI_API_KEY=\${LITELLM_MASTER_KEY}'
      - 'WEBUI_SECRET_KEY=\${WEBUI_SECRET_KEY}'
      - 'ENABLE_RAG_LOCAL_WEB_FETCH=True'
      ## Accès Ollama direct (en plus du proxy LiteLLM)
      - 'OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}'
    extra_hosts: ["host.docker.internal:host-gateway"]
    restart: unless-stopped

volumes:
  postgres_data:
  qdrant_storage:
EOF

# --- LANCEMENT SÉQUENTIEL ---
echo -e "⏳ Démarrage de PostgreSQL..."
$DOCKER_CMD -p ai-company-swarm up -d postgres
echo -e "Attente PostgreSQL (10s)..."
sleep 10

echo -e "⏳ Création base LiteLLM..."
docker exec ai-company-swarm-postgres-1 psql -U paperclip -d paperclip -c "CREATE DATABASE litellm;" 2>/dev/null || true

echo -e "⏳ Démarrage de la stack complète..."
$DOCKER_CMD -p ai-company-swarm up -d

sleep 10
docker ps --filter "name=ai-company" --format "  {{.Names}}: {{.Status}}"

# --- RÉCAPITULATIF ---
echo -e "\n${BOLD}${YELLOW}====================================================${NC}"
echo -e "      🚀 AI COMPANY SWARM EST OPÉRATIONNELLE"
echo -e "${BOLD}${YELLOW}====================================================${NC}"

echo -e "\n${BOLD}🌐 INTERFACES UTILISATEUR :${NC}"
echo -e "  🔗 Open WebUI (Interface IA)  : ${CYAN}http://localhost:8000${NC}"
echo -e "  🔗 Paperclip (Agents IA)      : ${CYAN}http://localhost:3100${NC}"

echo -e "\n${BOLD}🛠️ INFRASTRUCTURE :${NC}"
echo -e "  📊 LiteLLM (Proxy modèles)    : ${CYAN}http://localhost:8001${NC}"
echo -e "  🧠 Qdrant (Base vectorielle)  : ${CYAN}http://localhost:6333/dashboard${NC}"
echo -e "  🦙 Ollama (Moteur local)      : ${CYAN}http://localhost:11434${NC}"

echo -e "\n${BOLD}🔑 SÉCURITÉ :${NC}"
echo -e "  Qdrant API Key   : ${YELLOW}${QDRANT_KEY:0:8}...${NC} (= UPLANETNAME si constellation ẐEN)"
echo -e "  LiteLLM API Key  : ${YELLOW}${LITELLM_MASTER_KEY}${NC}"

echo -e "\n${BOLD}📂 ADMINISTRATION :${NC}"
echo -e "  Dossier          : ${YELLOW}$INSTALL_DIR${NC}"
echo -e "  Secrets (.env)   : ${RED}cat $INSTALL_DIR/.env${NC}"
echo -e "  Logs             : ${GREEN}docker compose -p ai-company-swarm logs -f${NC}"

echo -e "\n${BOLD}⚡ ACCÈS DISTANT (SSH tunnel) :${NC}"
echo -e "  ${YELLOW}ssh -L 8000:127.0.0.1:8000 -L 3100:127.0.0.1:3100 user@VOTRE_IP${NC}"
echo -e "  Puis ouvrir : http://localhost:8000"

echo -e "\n${BOLD}💡 PREMIÈRE CONNEXION Open WebUI :${NC}"
echo -e "  1. Ouvrez http://localhost:8000"
echo -e "  2. Créez un compte admin"
echo -e "  3. Paramètres → Connexions → Ollama : http://host.docker.internal:11434"
echo -e "  4. Ou utilisez le proxy LiteLLM déjà configuré"

echo -e "\n${GREEN}${BOLD}✅ STACK AI COMPANY (Open WebUI) DÉPLOYÉE !${NC}"

# =============================================================================
# ÉTAPES SUIVANTES — Initialisation Paperclip
# =============================================================================

echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         PROCHAINES ÉTAPES — À FAIRE MAINTENANT           ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BOLD}① Initialiser le compte CEO dans Paperclip :${NC}"
echo -e "   ${YELLOW}docker exec -it ai-company-swarm-paperclip-1 \\"
echo -e "     pnpm paperclipai auth bootstrap-ceo${NC}"
echo -e "   ${CYAN}→ Crée le premier utilisateur admin (email + mot de passe)${NC}"

echo -e "\n${BOLD}② Lancer l'assistant d'intégration (onboarding) :${NC}"
echo -e "   ${YELLOW}docker exec -it ai-company-swarm-paperclip-1 \\"
echo -e "     pnpm paperclipai onboard${NC}"
echo -e "   ${CYAN}→ Crée la company, les agents et les premiers tickets guidés${NC}"

echo -e "\n${BOLD}③ Configurer les canaux de diffusion (Telegram · Gmail · Mastodon · Nostr) :${NC}"
echo -e "   ${YELLOW}$MY_PATH/setup/paperclip-configure-channels.sh${NC}"
echo -e "   ${CYAN}→ Génère les skills Node.js natifs dans :${NC}"
echo -e "   ${CYAN}   $INSTALL_DIR/paperclip_data/skills/${NC}"
echo -e ""
echo -e "   ${CYAN}Options disponibles :${NC}"
echo -e "   ${YELLOW}  --deps     ${NC}Vérifier Node.js ≥ 18 dans le conteneur Paperclip"
echo -e "   ${YELLOW}  --telegram ${NC}Configurer le bot Telegram"
echo -e "   ${YELLOW}  --gmail    ${NC}Configurer Gmail OAuth2"
echo -e "   ${YELLOW}  --mastodon ${NC}Configurer Mastodon"
echo -e "   ${YELLOW}  --all      ${NC}Tout configurer en une seule passe"
echo -e "   ${YELLOW}  --health   ${NC}Rapport de santé complet"

echo -e "\n${BOLD}④ Accéder à l'interface Paperclip :${NC}"
echo -e "   ${CYAN}http://localhost:3100${NC}"
echo -e "   ${CYAN}→ Créez vos agents, goals, tickets et routines via l'UI${NC}"

echo -e "\n${BOLD}${GREEN}────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}Ordre recommandé :${NC}  ${YELLOW}bootstrap-ceo${NC} → ${YELLOW}onboard${NC} → ${YELLOW}configure-channels --all${NC} → ${CYAN}http://localhost:3100${NC}"
echo -e "${BOLD}${GREEN}────────────────────────────────────────────────────────────${NC}\n"
