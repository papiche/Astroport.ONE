#!/bin/bash
# Bibliothèque compose Astroport.ONE — à sourcer (. tools/astro_compose.sh)
#   astro_compose_sync_env   lie docker/.env → ~/.zen/ai-company/.env (secrets IA, source unique)
#   astro_compose ARGS…      docker compose sur la pile principale (avec secrets, overlay GPU si NVIDIA)
#   dify_compose ARGS…       docker compose sur la pile Dify (projet dédié « dify »)
# Sans docker/.env, compose retombe sur le mot de passe par défaut « changeme-… » (Qdrant, WebUI) :
# tout `up` recréerait alors le conteneur avec une autre clé et casserait BRO en silence.

_AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASTRO_COMPOSE_FILE="${ASTRO_COMPOSE_FILE:-$_AC_ROOT/docker/docker-compose.yml}"
ASTRO_AI_DIR="${ASTRO_AI_DIR:-$HOME/.zen/ai-company}"
DIFY_PROJECT="dify"
DIFY_DIR="$ASTRO_AI_DIR/dify/docker"

# Source unique des secrets : $ASTRO_AI_DIR/.env, passée explicitement à compose (--env-file).
# docker/.env n'est qu'un lien vers ce fichier, pour qu'un « docker compose up » manuel le trouve aussi.
astro_compose_sync_env() {
    local src="$ASTRO_AI_DIR/.env" dst; dst="$(dirname "$ASTRO_COMPOSE_FILE")/.env"
    [[ -s "$src" ]] || { echo "ERROR:secrets IA absents ($src) — lancer install/install-ai-company.docker.sh" >&2; return 1; }
    chmod 600 "$src"
    [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]] && return 0
    [[ -e "$dst" && ! -L "$dst" ]] && mv "$dst" "$dst.bak.$(date +%s)"
    ln -sfn "$src" "$dst"
}

astro_compose() {
    local f=(-f "$ASTRO_COMPOSE_FILE")
    local gpu; gpu="$(dirname "$ASTRO_COMPOSE_FILE")/docker-compose.gpu.yml"
    [[ -f "$gpu" ]] && docker info 2>/dev/null | grep -qi nvidia && f+=(-f "$gpu")
    astro_compose_sync_env || return 1
    docker compose --env-file "$ASTRO_AI_DIR/.env" "${f[@]}" "$@"
}

dify_compose() {
    local f
    for f in docker-compose.yaml docker-compose.yml; do
        [[ -f "$DIFY_DIR/$f" ]] && { docker compose -p "$DIFY_PROJECT" --project-directory "$DIFY_DIR" -f "$DIFY_DIR/$f" "$@"; return; }
    done
    echo "ERROR:Dify compose introuvable dans $DIFY_DIR" >&2; return 1
}
