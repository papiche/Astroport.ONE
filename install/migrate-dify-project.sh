#!/bin/bash
# Migre Dify du projet compose "docker" (collision avec Astroport.ONE/docker)
# vers un projet dédié "dify". Données conservées (bind mounts ./volumes).
# Usage : migrate-dify-project.sh [--yes]   (sans --yes : simple aperçu)
DIFY_DIR="$HOME/.zen/ai-company/dify/docker"
[[ -f "$DIFY_DIR/docker-compose.yaml" ]] || { echo "ERROR:Dify absent ($DIFY_DIR)" >&2; exit 1; }
cd "$DIFY_DIR" || exit 1
old=$(docker ps -a --filter "label=com.docker.compose.project.working_dir=$DIFY_DIR" \
      --format '{{.Names}} ({{.Label "com.docker.compose.project"}})')
echo "Conteneurs Dify actuels :"; echo "${old:-  (aucun)}"
if [[ "$1" != "--yes" ]]; then
    echo "Aperçu seulement. Relancer avec --yes pour : down (ancien projet) puis up -p dify."
    exit 0
fi
oldproj=$(docker ps -a --filter "label=com.docker.compose.project.working_dir=$DIFY_DIR" \
          --format '{{.Label "com.docker.compose.project"}}' | sort -u | grep -v '^dify$' | head -1)
if [[ -n "$oldproj" ]]; then
    docker compose -p "$oldproj" --project-directory "$DIFY_DIR" -f docker-compose.yaml down || exit 1
fi
docker compose -p dify --project-directory "$DIFY_DIR" -f docker-compose.yaml up -d
