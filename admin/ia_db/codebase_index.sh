#!/bin/bash
###########################################################################
# codebase_index.sh — Mémoire vectorielle du code source
#
# Indexe Astroport.ONE / UPlanet / UPassport / NIP-101 dans Qdrant
# en utilisant nomic-embed-text (Ollama) pour les embeddings.
# Le snapshot peut être publié sur IPFS et partagé dans la constellation.
#
# Usage :
#   ./admin/ia_db/codebase_index.sh [--index] [--incremental] [--reset]
#                              [--search "query"] [--snapshot] [--restore CID]
#                              [--stats] [--workspace /path]
#
# Variables d'environnement :
#   QDRANT_URL      http://localhost:6333
#   OLLAMA_URL      http://localhost:11434
#   EMBED_MODEL     nomic-embed-text
#   CODEBASE_ROOT   ~/workspace/AAA
###########################################################################
_ME="${BASH_SOURCE[0]##*/}"
_MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${CODEBASE_ROOT:-${_MY_PATH}/../..}"
WORKSPACE="$(realpath "$WORKSPACE" 2>/dev/null || echo "$WORKSPACE")"

# Auto-symlink dans ~/.local/bin
[[ ! -L ~/.local/bin/${_ME} ]] && \
    ln -sf "${_MY_PATH}/${_ME}" ~/.local/bin/${_ME} 2>/dev/null && \
    echo "[codebase_index] symlink → ~/.local/bin/${_ME}"

QDRANT_URL="${QDRANT_URL:-http://127.0.0.1:6333}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
EMBED_MODEL="${EMBED_MODEL:-nomic-embed-text}"

# Clé API Qdrant — source canonique : ~/.zen/ai-company/.env (install-ai-company.docker.sh)
_AI_ENV="${HOME}/.zen/ai-company/.env"
if [[ -z "${QDRANT_API_KEY:-}" ]] && [[ -f "$_AI_ENV" ]]; then
    _val=$(grep -E '^QDRANT_API_KEY=' "$_AI_ENV" | cut -d= -f2-)
    [[ -n "$_val" ]] && export QDRANT_API_KEY="$_val"
fi
export QDRANT_API_KEY="${QDRANT_API_KEY:-}"

# Header curl pour Qdrant (vide si pas de clé)
_QDRANT_CURL_OPTS=()
[[ -n "$QDRANT_API_KEY" ]] && _QDRANT_CURL_OPTS=(-H "api-key: ${QDRANT_API_KEY}")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

# Python interpréteur (préférer le venv Astroport)
PYTHON3="${HOME}/.astro/bin/python3"
command -v "$PYTHON3" &>/dev/null || PYTHON3="$(command -v python3)"

INDEXER="${_MY_PATH}/codebase_index.py"

# ── Vérifications préalables ──────────────────────────────────────────────
_check_qdrant() {
    if ! curl -sf --max-time 2 "${_QDRANT_CURL_OPTS[@]}" "${QDRANT_URL}/collections" &>/dev/null; then
        echo -e "${RED}[ERREUR]${NC} Qdrant non disponible sur ${QDRANT_URL}"
        [[ -n "$QDRANT_API_KEY" ]] && echo -e "  clé : ${QDRANT_API_KEY:0:8}..." \
            || echo -e "  ${YELLOW}[INFO]${NC} QDRANT_API_KEY non définie (source: ${_AI_ENV})"
        echo -e "  → Démarrer avec : ${CYAN}install/install-ai-company.docker.sh${NC}"
        return 1
    fi
    return 0
}

_check_ollama() {
    if ! curl -sf --max-time 2 "${OLLAMA_URL}/api/tags" &>/dev/null; then
        echo -e "${RED}[ERREUR]${NC} Ollama non disponible sur ${OLLAMA_URL}"
        return 1
    fi
    local _models
    _models=$(curl -sf "${OLLAMA_URL}/api/tags" | python3 -c \
        "import json,sys; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]" 2>/dev/null)
    if ! echo "$_models" | grep -q "${EMBED_MODEL%%:*}"; then
        echo -e "${YELLOW}[INFO]${NC} Modèle '${EMBED_MODEL}' absent — téléchargement..."
        ollama pull "${EMBED_MODEL}" || return 1
    fi
    return 0
}

# ── Commandes ─────────────────────────────────────────────────────────────
case "${1:-}" in

    --index|index)
        echo -e "${CYAN}[codebase_index]${NC} Indexation complète depuis ${WORKSPACE}..."
        _check_qdrant && _check_ollama || exit 1
        "$PYTHON3" "$INDEXER" --index --workspace "$WORKSPACE" "${@:2}"
        ;;

    --incremental|incremental)
        echo -e "${CYAN}[codebase_index]${NC} Mise à jour incrémentale..."
        _check_qdrant && _check_ollama || exit 1
        "$PYTHON3" "$INDEXER" --incremental --workspace "$WORKSPACE" "${@:2}"
        ;;

    --reset|reset)
        echo -e "${YELLOW}[codebase_index]${NC} Reset + réindexation complète..."
        _check_qdrant && _check_ollama || exit 1
        "$PYTHON3" "$INDEXER" --index --reset --workspace "$WORKSPACE" "${@:2}"
        ;;

    --search|search)
        _check_qdrant || exit 1
        QUERY="${2:-}"
        [[ -z "$QUERY" ]] && { echo "Usage : $0 --search \"query\""; exit 1; }
        "$PYTHON3" "$INDEXER" --search "$QUERY" --workspace "$WORKSPACE" \
            --limit "${3:-10}"
        ;;

    --snapshot|snapshot)
        echo -e "${CYAN}[codebase_index]${NC} Snapshot Qdrant → IPFS..."
        _check_qdrant || exit 1
        command -v ipfs &>/dev/null || { echo -e "${RED}[ERREUR]${NC} ipfs non disponible"; exit 1; }
        CID=$("$PYTHON3" "$INDEXER" --snapshot --workspace "$WORKSPACE")
        if [[ -n "$CID" ]]; then
            echo -e "${GREEN}✓ CID IPFS :${NC} ${CYAN}${CID}${NC}"
            # Mémoriser localement pour les autres nœuds
            echo "$CID" > "${_MY_PATH}/../.codebase_index.cid"
            echo -e "${CYAN}[ipfs]${NC} Partager dans la constellation :"
            echo -e "  ${YELLOW}${0} --restore ${CID}${NC}"
        fi
        ;;

    --restore|restore)
        CID="${2:-}"
        # Fallback sur le CID mémorisé localement
        [[ -z "$CID" ]] && CID=$(cat "${_MY_PATH}/../.codebase_index.cid" 2>/dev/null || true)
        [[ -z "$CID" ]] && { echo "Usage : $0 --restore <CID>"; exit 1; }
        echo -e "${CYAN}[codebase_index]${NC} Restauration depuis IPFS ${CID}..."
        _check_qdrant || exit 1
        "$PYTHON3" "$INDEXER" --restore "$CID" --workspace "$WORKSPACE"
        ;;

    --stats|stats)
        _check_qdrant || exit 1
        "$PYTHON3" "$INDEXER" --stats
        ;;

    --help|-h|help|"")
        echo ""
        echo -e "  ${CYAN}codebase_index.sh${NC} — Mémoire vectorielle du codebase UPlanet/Astroport"
        echo ""
        echo "  Commandes :"
        echo "    --index         Indexer tout le codebase (première fois)"
        echo "    --incremental   Réindexer seulement les fichiers modifiés"
        echo "    --reset         Supprimer et tout réindexer"
        echo "    --search TEXT   Recherche sémantique (retourne score<TAB>path)"
        echo "    --snapshot      Snapshot Qdrant → IPFS (partage constellation)"
        echo "    --restore CID   Restaurer depuis un snapshot IPFS"
        echo "    --stats         Afficher les stats de la collection"
        echo ""
        echo "  Variables :"
        echo "    QDRANT_URL    ${QDRANT_URL}"
        echo "    OLLAMA_URL    ${OLLAMA_URL}"
        echo "    EMBED_MODEL   ${EMBED_MODEL}"
        echo "    CODEBASE_ROOT ${WORKSPACE}"
        echo ""
        echo "  Indexation initiale (dev) :"
        echo "    docker compose --profile ai up -d"
        echo "    ./admin/ia_db/codebase_index.sh --index"
        echo ""
        echo "  Partage constellation :"
        echo "    ./admin/ia_db/codebase_index.sh --snapshot    # nœud maître"
        echo "    ./admin/ia_db/codebase_index.sh --restore CID # nœuds secondaires"
        echo ""
        ;;

    *)
        # Passe-plat direct vers Python pour les options non listées
        _check_qdrant || exit 1
        "$PYTHON3" "$INDEXER" "$@" --workspace "$WORKSPACE"
        ;;
esac
