#!/bin/bash
########################################################################
# install_leann.sh — Installation LeAnn dans NextCloud AIO
#
# LeAnn = plugin NextCloud qui pont NextCloud ↔ Ollama ↔ Qdrant
# Source : https://chaton.g1sms.fr/fr/blog/leann-votre-base-vectorielle-nextcloud-pour-ollama
#
# Architecture résultante :
#   NextCloud /Astroport/     → fichiers de la constellation
#         ↓ (LeAnn watcher)
#   Ollama nomic-embed-text   → génération d'embeddings vectoriels
#         ↓
#   Qdrant nextcloud_kb       → base vectorielle de la constellation
#         ↓ (requêtes #BRO)
#   code_assistant / OpenWebUI → réponses contextuelles IA locale
#
# Prérequis :
#   - NextCloud AIO démarré (profil 'nextcloud')
#   - Ollama disponible (port 11434)
#   - Qdrant disponible (port 6333, profil 'ai-company' ou standalone)
#
# Usage :
#   bash install_leann.sh
#   bash install_leann.sh --collection Constellation --user admin
########################################################################

set -e

MY_PATH="$(dirname "$(realpath "$0")")"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

## ── Paramètres ────────────────────────────────────────────────────────
NC_COLLECTION="${1:-Astroport}"        # Dossier NextCloud à indexer
NC_ADMIN_USER="${2:-admin}"            # Utilisateur admin NextCloud
QDRANT_COLLECTION="nextcloud_kb"       # Collection Qdrant

## ── Couleurs ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC_C='\033[0m'
ok()   { echo -e "${GREEN}✅ $*${NC_C}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC_C}"; }
err()  { echo -e "${RED}❌ $*${NC_C}"; }
info() { echo -e "${CYAN}ℹ️  $*${NC_C}"; }

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🧠 LEANN — Pont NextCloud ↔ Ollama ↔ Qdrant               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

## ── Détection du conteneur NextCloud actif ────────────────────────────
NC_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'nextcloud-aio-nextcloud|nextcloud' | grep -v mastercontainer | head -1)
NC_MASTER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep 'nextcloud-aio-mastercontainer' | head -1)

if [[ -z "$NC_CONTAINER" && -z "$NC_MASTER" ]]; then
    err "NextCloud AIO non démarré. Lancez d'abord: bash install.sh \"\" \"\" \"\" nextcloud"
    exit 1
fi

## Si seul le mastercontainer tourne, NextCloud AIO est en cours d'init
if [[ -z "$NC_CONTAINER" && -n "$NC_MASTER" ]]; then
    warn "NextCloud AIO mastercontainer trouvé mais le conteneur PHP n'est pas encore prêt."
    info "Complétez d'abord le setup via https://127.0.0.1:8443 puis relancez ce script."
    exit 1
fi

ok "Conteneur NextCloud détecté : $NC_CONTAINER"

## ── Exécution de commandes occ ────────────────────────────────────────
occ() {
    docker exec -u www-data "$NC_CONTAINER" php occ "$@"
}

## ── Détection de l'IP hôte accessible depuis Docker ──────────────────
## Les conteneurs NextCloud AIO accèdent à l'hôte via host-gateway ou bridge
HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[^ ]+' || hostname -I | awk '{print $1}')
DOCKER_GW=$(docker inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "172.17.0.1")
## host.docker.internal fonctionne si extra_hosts est configuré, sinon utiliser bridge GW
OLLAMA_HOST="http://${DOCKER_GW}:11434"
QDRANT_HOST="http://${DOCKER_GW}:6333"

## ── Clé API Qdrant = UPLANETNAME (cohérence de constellation) ────────
## UPLANETNAME est partagé par toutes les stations du même essaim UPlanet ẐEN
## → tout Qdrant de la constellation accepte la même clé
## Fallback : lecture dans ~/.zen/ai-company/.env
QDRANT_API_KEY=""
if [[ -n "${UPLANETNAME:-}" ]]; then
    QDRANT_API_KEY="$UPLANETNAME"
    ok "Qdrant API Key = UPLANETNAME (${QDRANT_API_KEY:0:8}... — clé de constellation)"
else
    _AI_ENV="$HOME/.zen/ai-company/.env"
    if [[ -s "$_AI_ENV" ]]; then
        QDRANT_API_KEY=$(grep '^QDRANT_API_KEY=' "$_AI_ENV" | cut -d'=' -f2)
        [[ -n "$QDRANT_API_KEY" ]] && ok "Qdrant API Key depuis $_AI_ENV (${QDRANT_API_KEY:0:8}...)" \
            || warn "QDRANT_API_KEY absent dans $_AI_ENV"
    else
        warn "UPLANETNAME et .env absents — Qdrant sans authentification"
    fi
fi

info "IP hôte: $HOST_IP | Bridge Docker: $DOCKER_GW"
info "Ollama URL (depuis conteneur): $OLLAMA_HOST"
info "Qdrant URL (depuis conteneur): $QDRANT_HOST"
[[ -n "$QDRANT_API_KEY" ]] && info "Qdrant API Key : ${QDRANT_API_KEY:0:8}..."

## ── Vérification / Démarrage Ollama via ollama.me.sh (local ou P2P) ─────
## ollama.me.sh gère : local → SSH tunnel scorpio → IPFS P2P swarm
## Il bind sur 127.0.0.1:11434 ET sur ${DOCKER_BRIDGE_IP}:11434
## → LeAnn (dans le conteneur NextCloud) accède via DOCKER_GW:11434
echo ""
info "Vérification Ollama (${OLLAMA_HOST} depuis conteneur / 127.0.0.1:11434 sur hôte)..."
if ! curl -sf http://127.0.0.1:11434/api/tags &>/dev/null; then
    info "Ollama non local — tentative P2P via ollama.me.sh..."
    _OLLAMA_STARTER="${MY_PATH}/../IA/ollama.me.sh"
    if [[ -x "$_OLLAMA_STARTER" ]]; then
        bash "$_OLLAMA_STARTER" &>/dev/null &
        echo -n "  Attente Ollama"
        for _i in $(seq 1 15); do sleep 1; echo -n "."; curl -sf http://127.0.0.1:11434/api/tags &>/dev/null && { echo " ✅"; break; }; done
        echo ""
    fi
fi

if curl -sf http://127.0.0.1:11434/api/tags &>/dev/null; then
    ## Lire le type de connexion
    _CONN_FILE="$HOME/.zen/tmp/ollama_connection.status"
    _CONN=$(grep '^CONNECTION_TYPE=' "$_CONN_FILE" 2>/dev/null | cut -d'=' -f2 || echo "local")
    ok "Ollama accessible ($_CONN) — binding Docker bridge : $DOCKER_GW:11434"
    ## S'assurer que nomic-embed-text est téléchargé (via ollama CLI ou API)
    if ! curl -sf http://127.0.0.1:11434/api/tags | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if any('nomic-embed-text' in m.get('name','') for m in d.get('models',[])) else 1)" 2>/dev/null; then
        info "Téléchargement du modèle d'embedding nomic-embed-text..."
        curl -sf -X POST http://127.0.0.1:11434/api/pull -d '{"name":"nomic-embed-text"}' &>/dev/null &
        ok "nomic-embed-text en cours de téléchargement (arrière-plan)"
    else
        ok "nomic-embed-text déjà disponible"
    fi
else
    warn "Ollama non accessible — LeAnn fonctionnera quand Ollama sera actif"
    warn "Lancez manuellement : bash ~/.zen/Astroport.ONE/IA/ollama.me.sh"
fi

## ── Vérification Qdrant ───────────────────────────────────────────────
info "Vérification Qdrant ($QDRANT_HOST)..."
_qdrant_check_opts=()
[[ -n "$QDRANT_API_KEY" ]] && _qdrant_check_opts=(-H "api-key: $QDRANT_API_KEY")
if curl -sf "${_qdrant_check_opts[@]}" http://127.0.0.1:6333/collections &>/dev/null; then
    ok "Qdrant accessible (authentification OK)"
else
    warn "Qdrant non accessible sur :6333 — installez d'abord le profil ai-company"
    warn "Ou: docker run -d -p 6333:6333 -e QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY:-secret} qdrant/qdrant"
fi

## ── Installation de l'app LeAnn ──────────────────────────────────────
echo ""
info "Installation de l'app LeAnn dans NextCloud..."
if occ app:list 2>/dev/null | grep -q 'leann'; then
    ok "LeAnn déjà installé"
else
    occ app:install leann 2>/dev/null \
        && ok "LeAnn installé" \
        || { warn "Échec installation via occ — tentative via marketplace..."; \
             occ app:enable leann 2>/dev/null || warn "LeAnn non disponible dans la marketplace. Installez manuellement : https://apps.nextcloud.com/apps/leann"; }
fi

## ── Configuration LeAnn ──────────────────────────────────────────────
echo ""
info "Configuration LeAnn..."

## Ollama endpoint (accessible depuis l'intérieur des conteneurs NextCloud)
occ config:app:set leann ollama_host --value "$OLLAMA_HOST" 2>/dev/null \
    && ok "LeAnn → Ollama : $OLLAMA_HOST" \
    || warn "Impossible de configurer ollama_host (LeAnn absent ?)"

## Qdrant endpoint
occ config:app:set leann qdrant_host --value "$QDRANT_HOST" 2>/dev/null \
    && ok "LeAnn → Qdrant : $QDRANT_HOST" \
    || warn "Impossible de configurer qdrant_host"

## Qdrant API Key (obligatoire si ai-company-swarm est utilisé)
## La clé est dans ~/.zen/ai-company/.env → QDRANT_API_KEY
if [[ -n "$QDRANT_API_KEY" ]]; then
    occ config:app:set leann qdrant_api_key --value "$QDRANT_API_KEY" 2>/dev/null \
        && ok "LeAnn → Qdrant API Key : ${QDRANT_API_KEY:0:8}..." \
        || warn "occ qdrant_api_key non configuré (nom de clé LeAnn peut différer)"
    ## Vérifier que Qdrant est accessible avec ce token
    _qdrant_test=$(curl -sf -H "api-key: $QDRANT_API_KEY" "http://127.0.0.1:6333/collections" 2>/dev/null)
    if [[ -n "$_qdrant_test" ]]; then
        ok "Qdrant authentifié (API key valide)"
    else
        warn "Qdrant non accessible avec cette clé — vérifiez ~/.zen/ai-company/.env"
    fi
else
    warn "Pas de clé API Qdrant — Qdrant accepte les connexions sans auth (non recommandé)"
fi

## Modèle d'embedding
occ config:app:set leann embedding_model --value "nomic-embed-text" 2>/dev/null \
    && ok "Modèle d'embedding : nomic-embed-text"

## Collection Qdrant cible
occ config:app:set leann qdrant_collection --value "$QDRANT_COLLECTION" 2>/dev/null \
    && ok "Collection Qdrant : $QDRANT_COLLECTION"

## LLM pour les réponses (via Ollama)
_DEFAULT_LLM=$(curl -sf http://127.0.0.1:11434/api/tags 2>/dev/null | python3 -c "import sys,json; models=json.load(sys.stdin).get('models',[]); print(models[0]['name'] if models else 'llama3')" 2>/dev/null || echo "llama3")
occ config:app:set leann llm_model --value "$_DEFAULT_LLM" 2>/dev/null \
    && ok "LLM pour Q&R : $_DEFAULT_LLM"

## ── Création du dossier partagé $NC_COLLECTION ────────────────────────
echo ""
info "Création du dossier de base de connaissance '${NC_COLLECTION}'..."
occ files:scan --path "/${NC_ADMIN_USER}/files/" 2>/dev/null || true

## Créer le dossier s'il n'existe pas
docker exec -u www-data "$NC_CONTAINER" \
    php occ files:mkdir "${NC_ADMIN_USER}/${NC_COLLECTION}" 2>/dev/null \
    && ok "Dossier /${NC_COLLECTION} créé" \
    || info "Le dossier existe peut-être déjà"

## ── Configuration de l'indexation automatique ─────────────────────────
info "Activation de l'indexation automatique sur /${NC_COLLECTION}..."
occ config:app:set leann watch_folders --value "/${NC_ADMIN_USER}/files/${NC_COLLECTION}" 2>/dev/null \
    && ok "Indexation automatique activée sur /${NC_COLLECTION}" \
    || warn "Configuration du watch_folder peut nécessiter l'interface web LeAnn"

## ── Lancer un premier index ──────────────────────────────────────────
echo ""
info "Lancement de l'indexation initiale (peut prendre quelques minutes)..."
occ leann:index 2>/dev/null \
    && ok "Index initial créé" \
    || warn "Indexation initiale échouée (normal si dossier vide — ajoutez des documents d'abord)"

## ── Résumé final ─────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ LEANN CONFIGURÉ — BASE DE CONNAISSANCE ASTROPORT        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  📂 Dossier de connaissance :                                ║"
echo "║     NextCloud → /${NC_COLLECTION}/                          ║"
echo "║     Déposez vos .pdf, .md, .txt, .docx ici                  ║"
echo "║                                                              ║"
echo "║  🔄 Indexation :                                            ║"
echo "║     Automatique à chaque modification (LeAnn watcher)        ║"
echo "║     Manuel : docker exec -u www-data ${NC_CONTAINER} \\      ║"
echo "║              php occ leann:index                             ║"
echo "║                                                              ║"
echo "║  🧠 Requêtes depuis #BRO :                                  ║"
echo "║     ~/.zen/Astroport.ONE/IA/nextcloud_bro_sync.sh query     ║"
echo "║     Ou via OpenWebUI : http://localhost:8000                  ║"
echo "║                                                              ║"
echo "║  🔍 Interface chat NextCloud :                               ║"
echo "║     cloud.VOTRE_DOMAINE → Applications → LeAnn              ║"
echo "║                                                              ║"
echo "║  📊 Dashboard Qdrant :                                       ║"
echo "║     http://localhost:6333/dashboard → collection: ${QDRANT_COLLECTION}  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
info "Pour synchroniser depuis Nostr → Qdrant (sans NextCloud) :"
info "  ~/.zen/Astroport.ONE/IA/nextcloud_bro_sync.sh"
