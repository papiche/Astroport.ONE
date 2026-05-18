#!/bin/bash
###########################################################################
# knowledge_index.sh — Mémoire vectorielle des connaissances WoTx2
#
# Indexe les documents de formation (.md, .pdf) liés aux skills WoTx2
# dans Qdrant via nomic-embed-text (Ollama).
#
# Sources :
#   1. Relay NOSTR  — Kind 30504 (ressources) + Kind 30500 (r tags)
#   2. uDRIVE local — ~/.zen/game/players/<G1PUB>/Documents/
#   3. Répertoire libre — Nextcloud, dossier admin, chemin quelconque
#
# Usage :
#   ./tools/knowledge_index.sh [--index-nostr] [--index-udrive]
#                              [--index-dir /path] [--reset]
#                              [--search "query" [--skill devops]]
#                              [--stats]
#
# Variables d'environnement :
#   QDRANT_URL    http://127.0.0.1:6333
#   OLLAMA_URL    http://localhost:11434
#   IPFS_GATEWAY  http://localhost:8080
#   NOSTR_RELAY   ws://localhost:7777
#   EMBED_MODEL   nomic-embed-text
###########################################################################
_ME="${BASH_SOURCE[0]##*/}"
_MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${CODEBASE_ROOT:-${_MY_PATH}/../..}"
WORKSPACE="$(realpath "$WORKSPACE" 2>/dev/null || echo "$WORKSPACE")"

# Auto-symlink dans ~/.local/bin
[[ ! -L ~/.local/bin/${_ME} ]] && \
    ln -sf "${_MY_PATH}/${_ME}" ~/.local/bin/${_ME} 2>/dev/null && \
    echo "[knowledge_index] symlink → ~/.local/bin/${_ME}"

QDRANT_URL="${QDRANT_URL:-http://127.0.0.1:6333}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
IPFS_GATEWAY="${IPFS_GATEWAY:-http://localhost:8080}"
NOSTR_RELAY="${NOSTR_RELAY:-ws://localhost:7777}"
EMBED_MODEL="${EMBED_MODEL:-nomic-embed-text}"

# Clé API Qdrant depuis ~/.zen/ai-company/.env
_AI_ENV="${HOME}/.zen/ai-company/.env"
if [[ -z "${QDRANT_API_KEY:-}" ]] && [[ -f "$_AI_ENV" ]]; then
    _val=$(grep -E '^QDRANT_API_KEY=' "$_AI_ENV" | cut -d= -f2-)
    [[ -n "$_val" ]] && export QDRANT_API_KEY="$_val"
fi
export QDRANT_API_KEY="${QDRANT_API_KEY:-}"

_QDRANT_CURL_OPTS=()
[[ -n "$QDRANT_API_KEY" ]] && _QDRANT_CURL_OPTS=(-H "api-key: ${QDRANT_API_KEY}")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

PYTHON3="${HOME}/.astro/bin/python3"
command -v "$PYTHON3" &>/dev/null || PYTHON3="$(command -v python3)"

INDEXER="${_MY_PATH}/knowledge_index.py"

_check_qdrant() {
    if ! curl -sf --max-time 2 "${_QDRANT_CURL_OPTS[@]}" "${QDRANT_URL}/collections" &>/dev/null; then
        echo -e "${RED}[ERREUR]${NC} Qdrant non disponible sur ${QDRANT_URL}"
        echo -e "  → Démarrer avec : ${CYAN}docker compose --profile ai up -d${NC}"
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

_run() {
    QDRANT_URL="$QDRANT_URL" \
    QDRANT_API_KEY="$QDRANT_API_KEY" \
    OLLAMA_URL="$OLLAMA_URL" \
    IPFS_GATEWAY="$IPFS_GATEWAY" \
    NOSTR_RELAY="$NOSTR_RELAY" \
    EMBED_MODEL="$EMBED_MODEL" \
    "$PYTHON3" "$INDEXER" --workspace "$WORKSPACE" "$@"
}

case "${1:-}" in

    --index-nostr|index-nostr)
        echo -e "${CYAN}[knowledge_index]${NC} Indexation NOSTR (Kind 30504/30500)..."
        _check_qdrant && _check_ollama || exit 1
        _run --index-nostr --relay "${NOSTR_RELAY}" "${@:2}"
        ;;

    --index-udrive|index-udrive)
        echo -e "${CYAN}[knowledge_index]${NC} Indexation uDRIVE local..."
        _check_qdrant && _check_ollama || exit 1
        _run --index-udrive "${@:2}"
        ;;

    --index-dir|index-dir)
        DIR="${2:-}"
        [[ -z "$DIR" ]] && { echo "Usage : $0 --index-dir <chemin> [--skill <skill>]"; exit 1; }
        echo -e "${CYAN}[knowledge_index]${NC} Indexation répertoire : ${DIR}..."
        _check_qdrant && _check_ollama || exit 1
        _run --index-dir "$DIR" "${@:3}"
        ;;

    --all|all)
        echo -e "${CYAN}[knowledge_index]${NC} Indexation complète (NOSTR + uDRIVE)..."
        _check_qdrant && _check_ollama || exit 1
        _run --index-nostr --relay "${NOSTR_RELAY}" --index-udrive "${@:2}"
        ;;

    --reset|reset)
        echo -e "${YELLOW}[knowledge_index]${NC} Reset + réindexation complète..."
        _check_qdrant && _check_ollama || exit 1
        _run --reset --index-nostr --relay "${NOSTR_RELAY}" --index-udrive "${@:2}"
        ;;

    --search|search)
        QUERY="${2:-}"
        [[ -z "$QUERY" ]] && { echo "Usage : $0 --search \"query\" [--skill devops]"; exit 1; }
        _check_qdrant || exit 1
        _run --search "$QUERY" "${@:3}" --limit "${LIMIT:-10}"
        ;;

    --stats|stats)
        _check_qdrant || exit 1
        _run --stats
        ;;

    --help|-h|help|"")
        echo ""
        echo -e "  ${CYAN}knowledge_index.sh${NC} — Mémoire vectorielle des connaissances WoTx2"
        echo ""
        echo "  Commandes :"
        echo "    --index-nostr         Indexer Kind 30504/30500 depuis relay NOSTR"
        echo "    --index-udrive        Indexer .md/.pdf depuis uDRIVE local"
        echo "    --index-dir <path>    Indexer un répertoire libre"
        echo "    --all                 NOSTR + uDRIVE"
        echo "    --reset               Supprimer et réindexer"
        echo "    --search TEXT         Recherche sémantique (score⇥cid⇥auteur⇥titre⇥skill)"
        echo "    --skill SKILL         Filtre skill pour --search"
        echo "    --stats               Stats collection"
        echo ""
        echo "  Variables :"
        echo "    QDRANT_URL    ${QDRANT_URL}"
        echo "    NOSTR_RELAY   ${NOSTR_RELAY}"
        echo "    IPFS_GATEWAY  ${IPFS_GATEWAY}"
        echo "    OLLAMA_URL    ${OLLAMA_URL}"
        echo "    EMBED_MODEL   ${EMBED_MODEL}"
        echo ""
        echo "  Exemples :"
        echo "    ./tools/knowledge_index.sh --index-nostr"
        echo "    ./tools/knowledge_index.sh --index-dir ~/nextcloud/Astroport --skill devops"
        echo "    ./tools/knowledge_index.sh --search 'introduction Docker conteneurs'"
        echo "    ./tools/knowledge_index.sh --search 'linux' --skill linux"
        echo ""
        echo "  Format sortie --search :"
        echo "    score<TAB>/ipfs/Qm...<TAB>auteur_hex<TAB>titre<TAB>skill"
        echo ""
        ;;

    *)
        _check_qdrant || exit 1
        _run "$@" --workspace "$WORKSPACE"
        ;;
esac
