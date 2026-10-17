#!/bin/bash
################################################################ admin/docker.sh
# Gestion Docker pour le Capitaine — pull, update, status, logs
# Usage : docker.sh [status|update|pull|logs|restart] [service]
################################################################
MY_PATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

. "${MY_PATH}/../tools/my.sh" 2>/dev/null || true
. "${MY_PATH}/../tools/astro_compose.sh"

COMPOSE_FILE="${MY_PATH}/../docker/docker-compose.yml"
GPU_OVERLAY="${MY_PATH}/../docker/docker-compose.gpu.yml"
LOG_FILE="$HOME/.zen/tmp/docker_admin.log"
mkdir -p "$(dirname "$LOG_FILE")"

_log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

_require_docker() {
    command -v docker >/dev/null 2>&1 || { echo "❌ Docker non installé"; exit 1; }
    docker info >/dev/null 2>&1 || { echo "❌ Docker daemon non accessible"; exit 1; }
}

# Tous les profils : indispensable pour nommer un service (qdrant, open-webui…) ; on ne démarre jamais
# « tout » — chaque appel cible des services explicites ou déjà créés.
_ac() { COMPOSE_PROFILES="ai,cloud,dev,updates,full" astro_compose "$@"; }
# Garde-fou : une liste de services vide ferait agir compose sur TOUS les profils
_need_svcs() { [[ ${#_svcs[@]} -gt 0 ]] || { _log "ℹ️  Aucun service Astroport installé — rien à faire"; return 1; }; }

# Services de la pile principale ayant déjà un conteneur (les profils non installés ne sont jamais touchés)
_existing_services() {
    docker ps -a --filter "label=com.docker.compose.project.working_dir=$(dirname "$ASTRO_COMPOSE_FILE")" \
        --format '{{.Label "com.docker.compose.service"}}' | sort -u
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
        _ac pull "$service" && _log "✅ $service mis à jour"
    else
        mapfile -t _svcs < <(_existing_services)
        _need_svcs || return 0
        _ac pull "${_svcs[@]}" && _log "✅ Toutes les images à jour"
    fi
}

# ── update ────────────────────────────────────────────────────────────────────
cmd_update() {
    local service="${1:-}"
    _require_docker
    _log "=== Mise à jour${service:+ ($service)} ==="

    if [[ -n "$service" ]]; then
        _log "Pull $service..."
        _ac pull "$service"
        _log "Redémarrage $service..."
        _ac up -d --no-deps "$service"
        _log "✅ $service redémarré"
    else
        _log "Pull toutes les images..."
        mapfile -t _svcs < <(_existing_services)
        _need_svcs || return 0
        _ac pull "${_svcs[@]}"

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
        _ac up -d --no-deps "${_svcs[@]}"
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
        _ac restart "$service"
        _log "✅ $service redémarré"
    else
        _log "Redémarrage complet de la stack..."
        mapfile -t _svcs < <(_existing_services); _need_svcs && _ac restart "${_svcs[@]}"
        _log "✅ Stack redémarrée"
    fi
}

# ── logs ──────────────────────────────────────────────────────────────────────
cmd_logs() {
    local service="${1:-astroport}"
    _require_docker
    _ac logs --tail=100 -f "$service"
}

# ── clean ─────────────────────────────────────────────────────────────────────
cmd_clean() {
    _require_docker
    _log "Nettoyage des images obsolètes..."
    docker image prune -f
    # Volontairement ni « volume prune » ni « network prune » : un volume de pile arrêtée
    # (Qdrant, Open WebUI…) ou dragon-net (réseau externe) serait détruit.
    _log "✅ Nettoyage terminé"
}

# ── watchtower ────────────────────────────────────────────────────────────────
cmd_watchtower() {
    local action="${1:-status}"
    _require_docker
    case "$action" in
        start)
            _log "Démarrage Watchtower (auto-update labelisés)..."
            _ac up -d watchtower
            _log "✅ Watchtower actif"
            ;;
        stop)
            _ac stop watchtower
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

# ── doctor ────────────────────────────────────────────────────────────────────
# Diagnostic lecture seule : collisions de projets, secrets, doublons, volumes orphelins.
cmd_doctor() {
    _require_docker
    local bad=0 dir; dir="$(dirname "$ASTRO_COMPOSE_FILE")"
    echo "── Projets compose (un dossier = un projet ; deux dossiers sous le même nom = collision)"
    docker ps -a --format '{{.Label "com.docker.compose.project"}}|{{.Label "com.docker.compose.project.working_dir"}}' \
        | grep -v '^|' | sort -u | awk -F'|' '{n[$1]++; d[$1]=d[$1]" "$2} END{for(p in n) print (n[p]>1?"❌":"✅"), p, "→", d[p]}' | tee /tmp/.astro_doctor.$$
    grep -q '^❌' /tmp/.astro_doctor.$$ && { bad=1; echo "   → relancer : install/migrate-dify-project.sh --yes"; }
    rm -f /tmp/.astro_doctor.$$
    echo "── Secrets IA"
    if [[ -s "$ASTRO_AI_DIR/.env" ]]; then
        astro_compose_sync_env && echo "✅ $dir/.env synchronisé avec $ASTRO_AI_DIR/.env"
        local k run; k=$(grep '^QDRANT_API_KEY=' "$ASTRO_AI_DIR/.env" | cut -d= -f2)
        run=$(docker inspect astroport-qdrant --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^QDRANT__SERVICE__API_KEY=' | cut -d= -f2)
        if [[ -n "$run" && "$run" != "$k" ]]; then echo "❌ astroport-qdrant tourne avec une AUTRE clé que le .env (recréé sans secrets ?)"; bad=1; fi
    else
        echo "ℹ️  Pas de secrets IA ($ASTRO_AI_DIR/.env) — pile IA non installée"
    fi
    echo "── Doublons connus"
    docker ps -a --format '{{.Names}}' | grep -qx qdrant && { echo "❌ conteneur « qdrant » isolé (sans clé API) en doublon de astroport-qdrant → docker rm qdrant"; bad=1; }
    docker ps -a --format '{{.Names}}' | grep -qx ai-company-webui && { echo "❌ ai-company-webui (ancien compose) en doublon de astroport-webui, même port 8000"; bad=1; }
    echo "── Volumes sans conteneur (informatif, jamais supprimés automatiquement)"
    docker volume ls -qf dangling=true | sed 's/^/   /'
    [[ $bad -eq 0 ]] && echo "✅ Rien à signaler" || return 1
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
  clean               Supprime les images obsolètes (jamais les volumes)
  doctor              Diagnostic (collisions de projets, secrets, doublons)
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
    doctor)     cmd_doctor ;;
    watchtower) cmd_watchtower "${2:-status}" ;;
    help|--help|-h) cmd_help ;;
    *)          echo "Commande inconnue: $1"; cmd_help; exit 1 ;;
esac
