#!/bin/bash
################################################################################
# arbor_run.sh — Enveloppe d'exécution ARBOR, unique point d'entrée des runs
# non interactifs (HTTP, cron, CLI). Ne merge JAMAIS : elle ne fait qu'invoquer
# arbor_self_improve.py, dont la seule mutation git est un `worktree add -b` +
# commit sur une branche isolée (voir arbor_self_improve.py::_create_worktree)
# — jamais master/main, jamais de `git merge`.
#
# Trois raisons d'exister (pas une) :
#   1. flock -n : un run ARBOR dure plusieurs minutes (embeddings + LLM) —
#      deux runs concurrents se disputeraient Ollama/Claude pour rien.
#   2. source my.sh : CAPTAINEMAIL, absent de l'environnement uvicorn, est
#      REQUIS par _notify_captain_arbor()/_notify_captain() (arbor_self_
#      improve.py, arbor_tool_forge.py) — sans lui, aucun DM ne partirait,
#      silencieusement.
#   3. État + audit : arbor_run.state.json et arbor_audit.jsonl, lus par
#      GET /api/nostr/admin/arbor_status (UPassport).
#
# Usage: arbor_run.sh --mode MODE [--model M] [--need TEXTE] [--slug SLUG]
#                      [--owner-email EMAIL] [--domain DOMAIN] [--url URL]
#                      [--origin http|cron|cli] [--captain-hex HEX]
#   MODE ∈ mine-requests | observe-love | explore | apply | forge | forge-scraper
#
#   forge invoque arbor_tool_forge.py (génération de code par Claude CLI) au
#   lieu de arbor_self_improve.py — nécessite --need, et que le capitaine ait
#   configuré/authentifié son compte Claude au préalable :
#     bash claude.vscodium.setup.sh setup   (ou migrate si config existante)
#   Sans quoi arbor_tool_forge.py::claude_available() échoue proprement
#   (message clair dans le log, rc=1 depuis le sys.exit ajouté à main()).
#
#   forge-scraper invoque arbor_scraper_forge.py (génère un scraper pour un
#   cookie déjà déposé sans scraper correspondant) — nécessite --owner-email
#   et --domain, --url optionnel. Même dépendance à Claude CLI que forge.
################################################################################

set -uo pipefail

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ZEN_HOME="${HOME}/.zen"
LOCK_FILE="${ZEN_HOME}/tmp/arbor_run.lock"
STATE_FILE="${ZEN_HOME}/tmp/arbor_run.state.json"
AUDIT_FILE="${ZEN_HOME}/flashmem/arbor_audit.jsonl"
AUDIT_MAX_LINES=500

mkdir -p "$(dirname "$LOCK_FILE")" "$(dirname "$AUDIT_FILE")"

MODE=""
MODEL=""
NEED=""
SLUG=""
OWNER_EMAIL=""
DOMAIN=""
URL=""
ORIGIN="cli"
CAPTAIN_HEX=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --need) NEED="$2"; shift 2 ;;
        --slug) SLUG="$2"; shift 2 ;;
        --owner-email) OWNER_EMAIL="$2"; shift 2 ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --origin) ORIGIN="$2"; shift 2 ;;
        --captain-hex) CAPTAIN_HEX="$2"; shift 2 ;;
        *) echo "[ERROR] Argument inconnu : $1" >&2; exit 2 ;;
    esac
done

case "$MODE" in
    mine-requests|observe-love|explore|apply|forge|forge-scraper) ;;
    *) echo "[ERROR] --mode requis parmi : mine-requests|observe-love|explore|apply|forge|forge-scraper (reçu: '${MODE}')" >&2; exit 2 ;;
esac
if [[ "$MODE" == "forge" ]] && [[ -z "$NEED" ]]; then
    echo "[ERROR] --need requis pour le mode forge" >&2
    exit 2
fi
if [[ "$MODE" == "forge-scraper" ]] && { [[ -z "$OWNER_EMAIL" ]] || [[ -z "$DOMAIN" ]]; }; then
    echo "[ERROR] --owner-email et --domain requis pour le mode forge-scraper" >&2
    exit 2
fi

# flock -n : jamais bloquant — un appelant HTTP doit recevoir 409 immédiatement
# plutôt qu'attendre la fin d'un run en cours. Le lock est libéré par le noyau
# même sur SIGKILL/reboot (contrairement à un fichier PID à valider manuellement).
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo '{"error":"run ARBOR déjà en cours"}'
    exit 75
fi

# Environnement complet de la station (CAPTAINEMAIL notamment) — jamais
# disponible sous uvicorn, requis pour toute notification capitaine.
source "${ZEN_HOME}/Astroport.ONE/tools/my.sh" >/dev/null 2>&1 || true

# Le mode forge invoque `claude` (CLI Claude Code) en sous-processus depuis
# arbor_tool_forge.py — installé typiquement dans ~/.local/bin/claude, absent
# du PATH restreint d'un service systemd (constaté : PATH sans ~/.local/bin
# sous le service upassport). Sans cette ligne, claude_available() renverrait
# faux même avec un compte parfaitement configuré.
export PATH="${HOME}/.local/bin:${PATH}"

RUN_ID="$(date +%s)-$$"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG_FILE="${ZEN_HOME}/tmp/arbor_run.${RUN_ID}.log"

_json_str() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1" 2>/dev/null || printf '"%s"' "$1"
}

cat > "$STATE_FILE" <<EOF
{"status":"running","run_id":"${RUN_ID}","mode":$(_json_str "$MODE"),"origin":$(_json_str "$ORIGIN"),"captain_hex":$(_json_str "$CAPTAIN_HEX"),"started_at":$(_json_str "$NOW_ISO"),"log":$(_json_str "$LOG_FILE")}
EOF

printf '%s\n' "{\"event\":\"start\",\"run_id\":\"${RUN_ID}\",\"mode\":$(_json_str "$MODE"),\"origin\":$(_json_str "$ORIGIN"),\"captain_hex\":$(_json_str "$CAPTAIN_HEX"),\"at\":$(_json_str "$NOW_ISO")}" >> "$AUDIT_FILE"

PYTHON_BIN="${HOME}/.astro/bin/python3"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

ARBOR_SCRIPT="${MY_PATH}/arbor_self_improve.py"
ARBOR_PY_ARGS=()
case "$MODE" in
    mine-requests) ARBOR_PY_ARGS=(--mine-requests --notify-captain) ;;
    observe-love)  ARBOR_PY_ARGS=(--observe-love-channel --notify-captain) ;;
    explore)       ARBOR_PY_ARGS=(--notify-captain) ;;
    apply)         ARBOR_PY_ARGS=(--apply --notify-captain) ;;
    forge)
        ARBOR_SCRIPT="${MY_PATH}/arbor_tool_forge.py"
        ARBOR_PY_ARGS=(--need "$NEED" --notify-captain)
        [[ -n "$SLUG" ]] && ARBOR_PY_ARGS+=(--slug "$SLUG")
        ;;
    forge-scraper)
        ARBOR_SCRIPT="${MY_PATH}/arbor_scraper_forge.py"
        ARBOR_PY_ARGS=(--owner-email "$OWNER_EMAIL" --domain "$DOMAIN" --notify-captain)
        [[ -n "$URL" ]] && ARBOR_PY_ARGS+=(--url "$URL")
        ;;
esac
[[ -n "$MODEL" ]] && [[ "$MODE" != "forge" ]] && [[ "$MODE" != "forge-scraper" ]] && ARBOR_PY_ARGS+=(--model "$MODEL")

START_TS=$(date +%s)
"$PYTHON_BIN" "$ARBOR_SCRIPT" "${ARBOR_PY_ARGS[@]}" >> "$LOG_FILE" 2>&1
RC=$?
END_TS=$(date +%s)
DURATION=$(( END_TS - START_TS ))

# Branche produite (si apply/forge/forge-scraper a réussi) — best-effort, ne
# bloque jamais la finalisation de l'état même si git échoue.
# arbor_tool_forge.py et arbor_scraper_forge.py réutilisent le même préfixe
# de branche refs/heads/arbor/ (cf. arbor_self_improve.py::BRANCH_PREFIX) —
# même détection pour les trois modes.
BRANCH=""
if [[ "$MODE" == "apply" || "$MODE" == "forge" || "$MODE" == "forge-scraper" ]] && [[ $RC -eq 0 ]]; then
    BRANCH=$(cd "${ZEN_HOME}/Astroport.ONE" 2>/dev/null \
        && git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/arbor/ 2>/dev/null \
        | head -1)
fi

FINISHED_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$STATE_FILE" <<EOF
{"status":"done","run_id":"${RUN_ID}","mode":$(_json_str "$MODE"),"origin":$(_json_str "$ORIGIN"),"rc":${RC},"branch":$(_json_str "$BRANCH"),"finished_at":$(_json_str "$FINISHED_ISO"),"log":$(_json_str "$LOG_FILE")}
EOF

printf '%s\n' "{\"event\":\"end\",\"run_id\":\"${RUN_ID}\",\"mode\":$(_json_str "$MODE"),\"rc\":${RC},\"branch\":$(_json_str "$BRANCH"),\"duration_s\":${DURATION},\"at\":$(_json_str "$FINISHED_ISO")}" >> "$AUDIT_FILE"

# Fenêtre glissante — même esprit que bro/identity.py::_trim_preferences_history.
if [[ -f "$AUDIT_FILE" ]]; then
    LINE_COUNT=$(wc -l < "$AUDIT_FILE")
    if [[ "$LINE_COUNT" -gt "$AUDIT_MAX_LINES" ]]; then
        tail -n "$AUDIT_MAX_LINES" "$AUDIT_FILE" > "${AUDIT_FILE}.tmp" && mv "${AUDIT_FILE}.tmp" "$AUDIT_FILE"
    fi
fi

exit $RC
