#!/bin/bash
################################################################ admin/docker.sh
# Gestion Docker pour le Capitaine — pull, update, status, logs
# Usage : docker.sh [status|update|pull|logs|restart] [service]
################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

. "${MY_PATH}/../tools/my.sh" 2>/dev/null || true

COMPOSE_FILE="${MY_PATH}/../docker/docker-compose.yml"
GPU_OVERLAY="${MY_PATH}/../docker/docker-compose.gpu.yml"
LOG_FILE="$HOME/.zen/tmp/docker_admin.log"
mkdir -p "$(dirname "$LOG_FILE")"

_log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

_require_docker() {
    command -v docker >/dev/null 2>&1 || { echo "❌ Docker non installé"; exit 1; }
    docker info >/dev/null 2>&1 || { echo "❌ Docker daemon non accessible"; exit 1; }
}

_gpu_flag() {
    if docker info 2>/dev/null | grep -q 'nvidia'; then
        echo "-f $COMPOSE_FILE -f $GPU_OVERLAY"
    else
        echo "-f $COMPOSE_FILE"
    fi
}

# ── status ────────────────────────────────────────────────────────────────────
cmd_status() {
    _require_docker
    echo "═══════════════════════════════════════════════════════"
    echo "  🐳 Conteneurs Astroport — $(date '+%Y-%m-%d %H:%M')"
    echo "═══════════════════════════════════════════════════════"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" \
        --filter "label=astroport.monitor=true" 2>/dev/null

    echo ""
    echo "── Tous les conteneurs actifs ──────────────────────────"
    docker ps --format "  {{.Names}}: {{.Status}}" 2>/dev/null
    echo ""
    echo "── Images locales ──────────────────────────────────────"
    docker images --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | head -20
}

# ── pull ──────────────────────────────────────────────────────────────────────
cmd_pull() {
    local service="${1:-}"
    _require_docker
    _log "Pull images${service:+ ($service)}..."
    if [[ -n "$service" ]]; then
        docker compose $(_gpu_flag) pull "$service" && _log "✅ $service mis à jour"
    else
        docker compose $(_gpu_flag) pull && _log "✅ Toutes les images à jour"
    fi
}

# ── update ────────────────────────────────────────────────────────────────────
cmd_update() {
    local service="${1:-}"
    _require_docker
    _log "=== Mise à jour${service:+ ($service)} ==="

    if [[ -n "$service" ]]; then
        _log "Pull $service..."
        docker compose $(_gpu_flag) pull "$service"
        _log "Redémarrage $service..."
        docker compose $(_gpu_flag) up -d --no-deps "$service"
        _log "✅ $service redémarré"
    else
        _log "Pull toutes les images..."
        docker compose $(_gpu_flag) pull

        # Identifie les conteneurs avec image mise à jour
        local updated=()
        while IFS= read -r name; do
            local image
            image=$(docker inspect "$name" --format '{{.Config.Image}}' 2>/dev/null)
            local running_id
            running_id=$(docker inspect "$name" --format '{{.Image}}' 2>/dev/null)
            local latest_id
            latest_id=$(docker image inspect "$image" --format '{{.Id}}' 2>/dev/null)
            [[ "$running_id" != "$latest_id" ]] && updated+=("$name")
        done < <(docker ps --format '{{.Names}}' 2>/dev/null)

        if [[ ${#updated[@]} -eq 0 ]]; then
            _log "✅ Tous les conteneurs sont déjà à jour"
            return 0
        fi

        _log "Conteneurs à redémarrer : ${updated[*]}"
        docker compose $(_gpu_flag) up -d --remove-orphans
        _log "✅ Mise à jour terminée"

        # Nettoyage images obsolètes
        docker image prune -f >/dev/null 2>&1 && _log "🧹 Images obsolètes supprimées"
    fi
}

# ── restart ───────────────────────────────────────────────────────────────────
cmd_restart() {
    local service="${1:-}"
    _require_docker
    if [[ -n "$service" ]]; then
        _log "Redémarrage $service..."
        docker compose $(_gpu_flag) restart "$service"
        _log "✅ $service redémarré"
    else
        _log "Redémarrage complet de la stack..."
        docker compose $(_gpu_flag) restart
        _log "✅ Stack redémarrée"
    fi
}

# ── logs ──────────────────────────────────────────────────────────────────────
cmd_logs() {
    local service="${1:-astroport}"
    _require_docker
    docker compose $(_gpu_flag) logs --tail=100 -f "$service"
}

# ── clean ─────────────────────────────────────────────────────────────────────
cmd_clean() {
    _require_docker
    _log "Nettoyage images et volumes orphelins..."
    docker image prune -f
    docker volume prune -f
    docker network prune -f
    _log "✅ Nettoyage terminé"
}

# ── watchtower ────────────────────────────────────────────────────────────────
cmd_watchtower() {
    local action="${1:-status}"
    _require_docker
    case "$action" in
        start)
            _log "Démarrage Watchtower (auto-update labelisés)..."
            docker compose $(_gpu_flag) --profile updates up -d watchtower
            _log "✅ Watchtower actif"
            ;;
        stop)
            docker compose $(_gpu_flag) stop watchtower
            _log "Watchtower arrêté"
            ;;
        status)
            if docker ps --format '{{.Names}}' | grep -q watchtower; then
                echo "✅ Watchtower actif"
                docker ps --format "  {{.Names}}: {{.Status}}" --filter name=watchtower
            else
                echo "⏹  Watchtower inactif"
            fi
            ;;
        *)
            echo "Usage: docker.sh watchtower [start|stop|status]"
            ;;
    esac
}

# ── help ──────────────────────────────────────────────────────────────────────
cmd_help() {
    cat << EOF
Usage: $(basename "$0") <commande> [service]

Commandes :
  status              Affiche l'état de tous les conteneurs
  pull   [service]    Télécharge la dernière version de l'image
  update [service]    Pull + redémarre (uniquement les conteneurs mis à jour)
  restart [service]   Redémarre un ou tous les services
  logs   [service]    Affiche les logs en temps réel (défaut: astroport)
  clean               Supprime images et volumes orphelins
  watchtower [action] Gère Watchtower : start | stop | status

Exemples :
  $(basename "$0") status
  $(basename "$0") update astroport
  $(basename "$0") update                  # toute la stack
  $(basename "$0") logs open-webui
  $(basename "$0") watchtower start        # active les mises à jour automatiques
  $(basename "$0") pull                    # pré-charge les images sans redémarrer

Logs : $LOG_FILE
EOF
}

# ── dispatch ──────────────────────────────────────────────────────────────────
case "${1:-help}" in
    status)     cmd_status ;;
    pull)       cmd_pull   "${2:-}" ;;
    update)     cmd_update "${2:-}" ;;
    restart)    cmd_restart "${2:-}" ;;
    logs)       cmd_logs   "${2:-astroport}" ;;
    clean)      cmd_clean ;;
    watchtower) cmd_watchtower "${2:-status}" ;;
    help|--help|-h) cmd_help ;;
    *)          echo "Commande inconnue: $1"; cmd_help; exit 1 ;;
esac
