#!/bin/bash
################################################################################
# arbor_baton_eligibility.sh — Vérifie si CETTE station a réellement le droit
# de publier du code (clé SSH/credentials avec accès push sur un remote git
# configuré) — prérequis pour tenir le "bâton de parole" ARBOR (cf.
# arbor_baton.sh). Test RÉEL (git push --dry-run), pas une déclaration.
#
# Le remote testé est ${ARBOR_GIT_REMOTE_NAME:-origin} (configurable via
# cooperative_config.sh, cohérent avec le reste des seuils ARBOR). Une station
# standard n'a PAS de remote push-capable configuré par défaut — seule une
# station de développeur/mainteneur qui a mis en place ses identifiants l'a.
#
# Usage :
#   arbor_baton_eligibility.sh [status|check|--force]
#     status/check : sert le cache si < CACHE_TTL, sinon relance un check
#     --force       : ignore le cache, relance toujours
# Sortie : un seul objet JSON sur stdout, jamais rien d'autre (parsable tel
# quel par heartbox_analysis.sh / node_admin.py).
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
# shellcheck source=/dev/null
[[ -z "$UPLANETNAME" ]] && source "${MY_PATH}/../tools/my.sh" 2>/dev/null
# shellcheck source=/dev/null
source "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null

CACHE_FILE="$HOME/.zen/tmp/arbor_baton_eligibility.json"
CACHE_TTL=3600   # 1h — un check réseau par jour suffit en pratique (appelé par 20h12.process.sh)
REPO_DIR="$(cd "${MY_PATH}/.." && pwd)"

_remote_name() {
    local n
    n=$(coop_config_get "ARBOR_GIT_REMOTE_NAME" 2>/dev/null)
    echo "${n:-origin}"
}

_json_out() {
    local eligible="$1" remote="$2" reason="$3"
    printf '{"eligible": %s, "remote": %s, "reason": %s, "checked_at": %s}\n' \
        "$eligible" "$(jq -Rn --arg v "$remote" '$v')" "$(jq -Rn --arg v "$reason" '$v')" "$(date +%s)"
}

_check_now() {
    local remote; remote="$(_remote_name)"
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        _json_out false "$remote" "repo_not_found"
        return
    fi
    if ! git -C "$REPO_DIR" remote get-url "$remote" &>/dev/null; then
        _json_out false "$remote" "no_remote_configured"
        return
    fi
    # BatchMode=yes + ConnectTimeout : jamais d'invite interactive bloquante
    # (passphrase SSH, confirmation de host key, login HTTPS) — un échec doit
    # se résoudre en quelques secondes, jamais pendre le cron 20h12.
    local probe_ref="refs/heads/_arbor_eligibility_probe_$$"
    local out rc
    out=$(cd "$REPO_DIR" && GIT_TERMINAL_PROMPT=0 \
        GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10" \
        timeout 20 git push --dry-run "$remote" "HEAD:${probe_ref}" 2>&1)
    rc=$?
    if [[ $rc -eq 0 ]]; then
        _json_out true "$remote" "dry_run_ok"
    else
        local reason
        reason=$(echo "$out" | tail -2 | tr '\n' ' ' | tr -d '"' | cut -c1-160)
        _json_out false "$remote" "dry_run_failed: ${reason}"
    fi
}

_serve() {
    if [[ -f "$CACHE_FILE" ]]; then
        local checked_at age
        checked_at=$(jq -r '.checked_at // 0' "$CACHE_FILE" 2>/dev/null)
        [[ "$checked_at" =~ ^[0-9]+$ ]] || checked_at=0
        age=$(( $(date +%s) - checked_at ))
        if [[ $age -lt $CACHE_TTL ]]; then
            cat "$CACHE_FILE"
            return
        fi
    fi
    mkdir -p "$(dirname "$CACHE_FILE")"
    _check_now | tee "$CACHE_FILE"
}

case "${1:-status}" in
    --force|force)
        mkdir -p "$(dirname "$CACHE_FILE")"
        _check_now | tee "$CACHE_FILE"
        ;;
    status|check|"")
        _serve
        ;;
    *)
        echo "Usage: $0 [status|check|--force]" >&2
        exit 2
        ;;
esac
