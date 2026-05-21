#!/usr/bin/env bash
# issue.sh — Gestion des issues GitHub/Gitea en ligne de commande
# Credentials via cooperative_config.sh (GIT_HOST, GIT_TOKEN, GIT_OWNER)

set -euo pipefail

# Résoudre le chemin réel même lorsque le script est appelé via un symlink
# (ex: ~/.local/bin/issue.sh → /workspace/AAA/Astroport.ONE/issue.sh)
MY_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ME="${BASH_SOURCE[0]##*/}"

[[ ! -L ~/.local/bin/${ME} ]] && ln -sf "${MY_PATH}/${ME}" ~/.local/bin/${ME} \
    && echo "Auto Install into ~/.local/bin/${ME}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# RTK (Rust Token Killer) — proxy compact si disponible
RTK=$(command -v rtk 2>/dev/null || echo "")
_git() { ${RTK:+rtk} git "$@"; }
_grep() { ${RTK:+rtk} grep "$@"; }
_find() { ${RTK:+rtk} find "$@"; }

# ── Chargement config coopérative (subprocess pour éviter my.sh/exit) ────────
_TOOLS_DIR="${MY_PATH}/tools"
GIT_HOST="${GIT_HOST:-}"
GIT_TOKEN="${GIT_TOKEN:-}"
GIT_OWNER="${GIT_OWNER:-}"

_COOP_SH="${_TOOLS_DIR}/cooperative_config.sh"
if [[ -f "$_COOP_SH" ]]; then
    [[ -z "$GIT_HOST"  ]] && GIT_HOST=$(timeout 8 bash  "$_COOP_SH" get GIT_HOST  2>/dev/null || true)
    [[ -z "$GIT_TOKEN" ]] && GIT_TOKEN=$(timeout 8 bash "$_COOP_SH" get GIT_TOKEN 2>/dev/null || true)
    [[ -z "$GIT_OWNER" ]] && GIT_OWNER=$(timeout 8 bash "$_COOP_SH" get GIT_OWNER 2>/dev/null || true)
fi

GIT_HOST="${GIT_HOST:-https://github.com}"
GIT_TOKEN="${GIT_TOKEN:-}"
GIT_OWNER="${GIT_OWNER:-papiche}"

# API URL : GitHub public vs Gitea/Forgejo self-hosted
if [[ "$GIT_HOST" == *"github.com"* ]]; then
    GIT_API="https://api.github.com"
    _GH_ACCEPT=(-H "Accept: application/vnd.github.v3+json")
else
    GIT_API="${GIT_HOST}/api/v1"
    _GH_ACCEPT=()
fi

# ── Détection repo depuis git remote ─────────────────────────────────────────
# Priorité : remote dont l'URL correspond à GIT_HOST (évite de prendre origin
# quand plusieurs remotes existent pour des forges différentes).
_detect_repo() {
    # Extraire le hostname de GIT_HOST pour la comparaison
    local host_pattern
    if [[ "$GIT_HOST" == *"github.com"* ]]; then
        host_pattern="github.com"
    else
        host_pattern=$(echo "$GIT_HOST" | sed -E 's|https?://||; s|/.*||')
    fi

    local remote_url=""
    # Parcourir tous les remotes et retenir le premier qui correspond à GIT_HOST
    while IFS= read -r remote_name; do
        local url
        url=$(git remote get-url "$remote_name" 2>/dev/null || true)
        if [[ "$url" == *"$host_pattern"* ]]; then
            remote_url="$url"
            break
        fi
    done < <(git remote 2>/dev/null)

    # Fallback sur origin si aucun remote ne correspond à GIT_HOST
    [[ -z "$remote_url" ]] && remote_url=$(git remote get-url origin 2>/dev/null || echo '')
    [[ -z "$remote_url" ]] && return 1

    # Supprimer .git et extraire owner/repo
    echo "$remote_url" | sed -E 's|\.git$||' | grep -oE '[^/:]+/[^/:]+$'
}

REPO=""
VERBOSE=false
OUTPUT_FORMAT="pretty"

# ── Aide ─────────────────────────────────────────────────────────────────────
show_help() {
    local tok_status="${RED}[non configuré]${NC}"
    [[ -n "$GIT_TOKEN" ]] && tok_status="${GREEN}[configuré]${NC}"

    echo -e "${GREEN}issue.sh${NC} — Gestion des issues GitHub/Gitea"
    echo ""
    echo -e "${YELLOW}USAGE:${NC}  $0 [--repo OWNER/REPO] <commande> [args]"
    echo ""
    echo -e "${YELLOW}COMMANDES:${NC}"
    echo -e "  ${GREEN}list${NC}    [--state open|closed|all] [--label LABEL]"
    echo -e "              Lister les issues (défaut : open)"
    echo -e "  ${GREEN}show${NC}    <numéro>"
    echo -e "              Détail d'une issue + ses commentaires"
    echo -e "  ${GREEN}create${NC}  \"titre\" [\"description\"] [--label LABEL]"
    echo -e "              Créer une nouvelle issue"
    echo -e "  ${GREEN}close${NC}   <numéro> [\"commentaire\"]"
    echo -e "              Fermer une issue (avec commentaire optionnel)"
    echo -e "  ${GREEN}reopen${NC}  <numéro>"
    echo -e "              Réouvrir une issue fermée"
    echo -e "  ${GREEN}comment${NC} <numéro> \"message\""
    echo -e "              Ajouter un commentaire"
    echo -e "  ${GREEN}label${NC}   <numéro> <label> [label2...]"
    echo -e "              Ajouter des labels"
    echo -e "  ${GREEN}repos${NC}"
    echo -e "              Lister les repos de ${GIT_OWNER}"
    echo -e "  ${GREEN}analyze${NC} <numéro> [--ai ollama|claude|gemini] [--model M] [--template T]"
    echo -e "              [--depth N] [--maxtoken N] [--verbose] [fichiers...]"
    echo -e "              Analyse une issue avec l'IA et propose un plan de correction"
    echo -e "              CLAUDE.md du projet est injecté automatiquement comme contexte"
    echo -e "  ${GREEN}pr${NC}      <numéro> [--base BRANCH] [--title \"titre\"]"
    echo -e "              Créer une Pull Request référençant l'issue depuis la branche courante"
    echo ""
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo -e "  ${GREEN}--repo, -r${NC}   OWNER/REPO (ex: papiche/Astroport.ONE)"
    echo -e "  ${GREEN}--json${NC}        Sortie JSON brute"
    echo -e "  ${GREEN}--verbose, -v${NC} Mode verbeux"
    echo -e "  ${GREEN}--help, -h${NC}   Afficher cette aide"
    echo ""
    echo -e "${YELLOW}TEMPLATES IA (IA/prompts/) :${NC}"
    echo -e "  ${CYAN}issue_analyze${NC}  Diagnostic + plan de correction (défaut)"
    echo -e "  ${CYAN}issue_fix${NC}      Correctif prêt à appliquer (patch)"
    echo -e "  ${CYAN}issue_plan${NC}     Plan d'implémentation feature"
    echo -e "  ${CYAN}issue_review${NC}   Revue de code sécurité/qualité"
    echo ""
    echo -e "${YELLOW}ENVIRONNEMENT:${NC}"
    echo -e "  GIT_HOST         = ${CYAN}${GIT_HOST}${NC}"
    echo -e "  GIT_API          = ${CYAN}${GIT_API}${NC}"
    echo -e "  GIT_OWNER        = ${CYAN}${GIT_OWNER}${NC}"
    echo -e "  GIT_TOKEN        = ${tok_status}"
    echo ""
    echo -e "${YELLOW}CONFIGURATION (coopérative, chiffré via NOSTR) :${NC}"
    echo -e "  source ${_TOOLS_DIR}/cooperative_config.sh"
    echo -e "  coop_config_set GIT_TOKEN        \"ghp_xxx\""
    echo -e "  coop_config_set GIT_HOST         \"https://github.com\""
    echo -e "  coop_config_set GIT_OWNER        \"papiche\""
    echo -e "  coop_config_set ANTHROPIC_API_KEY \"sk-ant-xxx\"  # pour l'API directe (optionnel si claude CLI installé)"
    echo -e "  coop_config_set GEMINI_API_KEY    \"AIzaSy...\""
    echo ""
    echo -e "${YELLOW}EXEMPLES:${NC}"
    echo "  $0 list"
    echo "  $0 list --state closed"
    echo "  $0 show 42"
    echo "  $0 create \"Bug login\" \"Détails du problème...\""
    echo "  $0 close 42 \"Corrigé dans commit abc123\""
    echo "  $0 comment 42 \"Reproduit sur Firefox 124\""
    echo "  $0 --repo papiche/UPlanet list --label bug"
    echo "  $0 analyze 42"
    echo "  $0 analyze 42 --ai claude --template issue_fix"
    echo "  $0 analyze 42 --ai gemini tools/my.sh RUNTIME/ZEN.ECONOMY.sh"
    exit 0
}

# ── Prérequis ─────────────────────────────────────────────────────────────────
_need_jq() {
    command -v jq &>/dev/null && return 0
    echo -e "${RED}[ERREUR]${NC} jq est requis : sudo apt install jq" >&2
    exit 1
}

# ── Appel API générique ────────────────────────────────────────────────────────
_api() {
    local method="$1"; shift
    local endpoint="$1"; shift
    local data="${1:-}"

    # Écriture toujours authentifiée ; lecture anonyme possible sur repos publics
    if [[ -z "$GIT_TOKEN" ]] && [[ "$method" != "GET" ]]; then
        echo -e "${RED}[ERREUR]${NC} GIT_TOKEN requis pour les opérations d'écriture." >&2
        echo -e "  Configurer : coop_config_set GIT_TOKEN \"ghp_xxx\"" >&2
        exit 1
    fi

    local url="${GIT_API}${endpoint}"
    [[ "$VERBOSE" == "true" ]] && echo -e "\033[2m[API] ${method} ${url}\033[0m" >&2

    local curl_args=(-s -X "$method"
        -H "Content-Type: application/json"
        "${_GH_ACCEPT[@]+"${_GH_ACCEPT[@]}"}")

    [[ -n "$GIT_TOKEN" ]] && curl_args+=(-H "Authorization: token $GIT_TOKEN")

    [[ -n "$data" ]] && curl_args+=(-d "$data")

    local resp http_code body
    resp=$(curl "${curl_args[@]}" -w '\n%{http_code}' "$url" 2>/dev/null)
    http_code=$(echo "$resp" | tail -1)
    body=$(echo "$resp" | head -n -1)

    if [[ "$http_code" -lt 200 ]] || [[ "$http_code" -ge 400 ]]; then
        echo -e "${RED}[ERREUR]${NC} HTTP ${http_code}" >&2
        echo "$body" | jq -r '.message // .' 2>/dev/null >&2 || echo "$body" >&2
        exit 1
    fi

    echo "$body"
}

# ── Formater une issue ────────────────────────────────────────────────────────
_fmt_issue() {
    local json="$1"
    local number title state user created_at body labels

    number=$(echo "$json" | jq -r '.number')
    title=$(echo "$json" | jq -r '.title')
    state=$(echo "$json" | jq -r '.state')
    user=$(echo "$json" | jq -r '.user.login // .poster.login // "?"')
    created_at=$(echo "$json" | jq -r '.created_at // .created // ""' | cut -c1-16)
    body=$(echo "$json" | jq -r '.body // "" | gsub("\\r"; "") | .[0:600]')
    labels=$(echo "$json" | jq -r '[.labels[]?.name] | join(", ")' 2>/dev/null || echo '')

    local state_color="$GREEN"
    [[ "$state" == "closed" ]] && state_color="$RED"

    echo ""
    echo -e "${BLUE}#${number}${NC} ${YELLOW}${title}${NC}"
    echo -e "  État: ${state_color}${state}${NC}  •  Auteur: ${CYAN}${user}${NC}  •  Date: ${created_at}"
    [[ -n "$labels" ]] && echo -e "  Labels: ${MAGENTA}${labels}${NC}"
    if [[ -n "$body" ]] && [[ "$body" != "null" ]]; then
        echo -e "  ──────────────────────────────"
        echo "$body" | sed 's/^/  /'
    fi
}

# ── Parsing des arguments globaux ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)    show_help ;;
        --repo|-r)    shift; REPO="${1:?'--repo requiert OWNER/REPO'}"; shift ;;
        --json)       OUTPUT_FORMAT="json"; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        *)            break ;;
    esac
done

COMMAND="${1:-list}"
shift || true

# Détecter et normaliser le repo
if [[ -z "$REPO" ]]; then
    REPO=$(_detect_repo 2>/dev/null || echo '')
    if [[ -z "$REPO" ]]; then
        REPO="${GIT_OWNER}/Astroport.ONE"
        echo -e "${YELLOW}[INFO]${NC} Repo par défaut : ${CYAN}${REPO}${NC}" >&2
    else
        echo -e "${YELLOW}[INFO]${NC} Repo (git remote) : ${CYAN}${REPO}${NC}" >&2
    fi
else
    # Normaliser si URL complète collée
    REPO=$(echo "$REPO" | sed -E 's|\.git$||' | grep -oE '[^/:]+/[^/:]+$' || echo "$REPO")
fi

_need_jq

# ── COMMANDES ─────────────────────────────────────────────────────────────────

case "$COMMAND" in

    # ─── list ────────────────────────────────────────────────────────────────
    list)
        STATE="open"
        LABEL=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --state) shift; STATE="$1"; shift ;;
                --label) shift; LABEL="$1"; shift ;;
                open|closed|all) STATE="$1"; shift ;;
                *) shift ;;
            esac
        done

        endpoint="/repos/${REPO}/issues?state=${STATE}&per_page=50&sort=updated"
        if [[ -n "$LABEL" ]]; then
            encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${LABEL}'))" 2>/dev/null || echo "$LABEL")
            endpoint+="&labels=${encoded}"
        fi

        result=$(_api GET "$endpoint")
        count=$(echo "$result" | jq 'length')

        echo ""
        echo -e "${GREEN}Issues ${STATE}${NC} — ${CYAN}${REPO}${NC}  (${count})"
        echo -e "══════════════════════════════════════════════════════"

        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            echo "$result" | jq .
        elif [[ "$count" -eq 0 ]]; then
            echo -e "  ${YELLOW}Aucune issue.${NC}"
        else
            echo "$result" | jq -c '.[]' | while IFS= read -r issue; do
                num=$(echo "$issue" | jq -r '.number')
                ttl=$(echo "$issue" | jq -r '.title')
                st=$(echo "$issue" | jq -r '.state')
                usr=$(echo "$issue" | jq -r '.user.login // .poster.login // "?"')
                lbl=$(echo "$issue" | jq -r '[.labels[]?.name] | join(",")' 2>/dev/null || echo '')
                icon="🟢"; [[ "$st" == "closed" ]] && icon="🔴"
                lbl_str=""; [[ -n "$lbl" ]] && lbl_str=" [${lbl}]"
                printf "  ${BLUE}#%-4s${NC} %s %-52s ${CYAN}@%-15s${NC}%s\n" \
                    "$num" "$icon" "${ttl:0:52}" "$usr" "$lbl_str"
            done
        fi
        echo ""
        if [[ "$count" -gt 0 && "$STATE" == "open" ]]; then
            echo -ne "${CYAN}[t=triage / numéro=analyser / Entrée=quitter] :${NC} "
            read -r _lact </dev/tty
            case "${_lact:-}" in
                t)   exec "$0" triage ;;
                [0-9]*) exec "$0" analyze "$_lact" --ai claude ;;
            esac
        fi
        ;;

    # ─── triage ──────────────────────────────────────────────────────────────
    triage)
        _triage_ai() {
            local _num="$1" _title="$2" _body="$3" _created="$4"
            # Vérification rapide : commit mentionnant #N dans le dépôt ?
            local _fix_commit
            _fix_commit=$(git log --oneline --all --grep="#${_num}" 2>/dev/null | head -1 || echo "")
            if [[ -n "$_fix_commit" ]]; then
                echo "fixed|commit trouvé : ${_fix_commit:0:60}"
                return
            fi
            # Date de création pour git log --since
            local _since
            _since=$(python3 -c "
from datetime import datetime
try:
    dt=datetime.fromisoformat('$_created'.replace('Z','+00:00'))
    print(dt.strftime('%Y-%m-%dT%H:%M:%S'))
except: print('1970-01-01')
" 2>/dev/null || echo "1970-01-01")
            local _recent
            _recent=$(git log --oneline --since="$_since" --all 2>/dev/null | head -8 || echo "")
            # Appel IA
            if command -v claude &>/dev/null; then
                local _cfg="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
                local _pf; _pf=$(mktemp /tmp/triage_XXXXXX.txt)
                cat > "$_pf" <<TPROMPT
Issue GitHub #$_num: "$_title"
Créée le : $_created
Body (500c) : $(echo "$_body" | head -c 500)

Commits dépôt depuis creation :
${_recent:-"(aucun)"}

FORMAT STRICT — une ligne, sans rien d'autre :
verdict|raison_max_80_chars

Verdicts :
valid     → bug réel encore présent
fixed     → déjà corrigé (voir commits)
PFH       → erreur utilisateur/config (PEBKAC)
obsolete  → plus pertinent
TPROMPT
                local _r
                _r=$(CLAUDE_CONFIG_DIR="$_cfg" claude --print < "$_pf" 2>/dev/null | grep -m1 '|' | head -1) || true
                rm -f "$_pf"
                # Quota
                if echo "$_r" | grep -qi "weekly limit\|You've hit\|quota"; then
                    _r="valid|⚠️ quota épuisé — vérification manuelle"
                fi
                [[ -n "$_r" ]] && { echo "$_r"; return; }
            fi
            echo "valid|IA indisponible — vérification manuelle"
        }

        _issues=$(_api GET "/repos/${REPO}/issues?state=open&per_page=50&sort=updated")
        _count=$(echo "$_issues" | jq 'length')
        [[ "$_count" -eq 0 ]] && echo "Aucune issue ouverte." && exit 0

        echo ""
        echo -e "${CYAN}Triage — ${REPO} (${_count} issues)${NC}"
        echo -e "══════════════════════════════════════════════════════"

        echo "$_issues" | jq -c '.[]' | while IFS= read -r _iss; do
            _n=$(echo "$_iss"   | jq -r '.number')
            _t=$(echo "$_iss"   | jq -r '.title')
            _b=$(echo "$_iss"   | jq -r '.body // ""')
            _cr=$(echo "$_iss"  | jq -r '.created_at')
            _usr=$(echo "$_iss" | jq -r '.user.login // "?"')

            echo ""
            echo -e "${BLUE}#${_n}${NC} ${_t:0:70}  ${CYAN}@${_usr}${NC}"
            echo -ne "  ${YELLOW}analyse...${NC}"

            _verdict=$(_triage_ai "$_n" "$_t" "$_b" "$_cr")
            _vtype=$(echo "$_verdict" | cut -d'|' -f1 | tr -d '[:space:]')
            _vreason=$(echo "$_verdict" | cut -d'|' -f2-)

            case "$_vtype" in
                valid)    _vico="${GREEN}✅ valid${NC}" ;;
                fixed)    _vico="${CYAN}✓  fixed${NC}" ;;
                PFH)      _vico="${YELLOW}⚠️  PFH${NC}" ;;
                obsolete) _vico="${RED}🗑  obsolete${NC}" ;;
                *)        _vico="${YELLOW}?  ${_vtype}${NC}" ;;
            esac
            echo -e "\r  $(echo -e "$_vico") — ${_vreason}"

            case "$_vtype" in
                valid)
                    echo -ne "  ${CYAN}[Entrée=suivant / a=analyser / c=fermer] :${NC} "
                    read -r _act </dev/tty
                    case "${_act:-}" in
                        a) "$0" analyze "$_n" --ai claude ;;
                        c)
                            read -r -p "  Raison : " _cr_reason </dev/tty
                            "$0" close "$_n" "${_cr_reason:-fermée manuellement}" 2>/dev/null || true
                            ;;
                    esac ;;
                *)
                    echo -ne "  ${CYAN}[Entrée=fermer / k=garder / a=analyser] :${NC} "
                    read -r _act </dev/tty
                    case "${_act:-}" in
                        k) echo -e "  ${GREEN}→ gardée${NC}" ;;
                        a) "$0" analyze "$_n" --ai claude ;;
                        *)
                            _cb="Triage automatique : **${_vtype}** — ${_vreason}"
                            "$0" close "$_n" "$_cb" 2>/dev/null \
                                && echo -e "  ${GREEN}✓ Fermée${NC}" \
                                || echo -e "  ${YELLOW}⚠️ Fermeture échouée${NC}" ;;
                    esac ;;
            esac
        done
        echo ""
        ;;

    # ─── show ────────────────────────────────────────────────────────────────
    show)
        NUM="${1:?'show requiert un numéro d'"'"'issue'}"

        result=$(_api GET "/repos/${REPO}/issues/${NUM}")

        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            echo "$result" | jq .
        else
            _fmt_issue "$result"
            comments=$(_api GET "/repos/${REPO}/issues/${NUM}/comments")
            c_count=$(echo "$comments" | jq 'length')
            if [[ "$c_count" -gt 0 ]]; then
                echo ""
                echo -e "  ${YELLOW}━━━ ${c_count} commentaire(s) ━━━${NC}"
                echo "$comments" | jq -c '.[]' | while IFS= read -r c; do
                    usr=$(echo "$c" | jq -r '.user.login // .poster.login // "?"')
                    dt=$(echo "$c" | jq -r '.created_at // .created // ""' | cut -c1-16)
                    cbody=$(echo "$c" | jq -r '.body // "" | gsub("\\r"; "") | .[0:400]')
                    echo ""
                    echo -e "  ${CYAN}@${usr}${NC}  (${dt})"
                    echo "$cbody" | sed 's/^/  │ /'
                done
            fi
            echo ""
        fi
        ;;

    # ─── create ──────────────────────────────────────────────────────────────
    create)
        TITLE=""
        BODY=""
        LABEL_ARG=""
        # Support flags --title, --body, --label ET positionnels (rétrocompat)
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --title) shift; TITLE="$1"; shift ;;
                --body)  shift; BODY="$1";  shift ;;
                --label) shift; LABEL_ARG="$1"; shift ;;
                *)
                    [[ -z "$TITLE" ]] && TITLE="$1" || BODY="${BODY:+$BODY }$1"
                    shift ;;
            esac
        done
        [[ -z "$TITLE" ]] && { echo "create requiert un titre" >&2; exit 1; }

        labels_json="[]"
        [[ -n "$LABEL_ARG" ]] && labels_json="[\"${LABEL_ARG}\"]"

        payload=$(jq -n \
            --arg t "$TITLE" \
            --arg b "$BODY" \
            --argjson l "$labels_json" \
            '{title: $t, body: $b, labels: $l}')

        result=$(_api POST "/repos/${REPO}/issues" "$payload")
        num=$(echo "$result" | jq -r '.number')
        url=$(echo "$result" | jq -r '.html_url // .url')
        echo -e "${GREEN}✓ Issue #${num} créée${NC} : $(echo "$result" | jq -r '.title')"
        echo -e "  URL : ${CYAN}${url}${NC}"
        ;;

    # ─── close ───────────────────────────────────────────────────────────────
    close)
        NUM="${1:?'close requiert un numéro d'"'"'issue'}"
        COMMENT="${2:-}"

        if [[ -n "$COMMENT" ]]; then
            payload=$(jq -n --arg b "$COMMENT" '{body: $b}')
            _api POST "/repos/${REPO}/issues/${NUM}/comments" "$payload" >/dev/null
            echo -e "${GREEN}✓ Commentaire ajouté${NC}"
        fi

        _api PATCH "/repos/${REPO}/issues/${NUM}" '{"state":"closed"}' >/dev/null
        echo -e "${GREEN}✓ Issue #${NUM} fermée${NC}"
        ;;

    # ─── reopen ──────────────────────────────────────────────────────────────
    reopen)
        NUM="${1:?'reopen requiert un numéro d'"'"'issue'}"
        _api PATCH "/repos/${REPO}/issues/${NUM}" '{"state":"open"}' >/dev/null
        echo -e "${GREEN}✓ Issue #${NUM} réouverte${NC}"
        ;;

    # ─── comment ─────────────────────────────────────────────────────────────
    comment)
        NUM="${1:?'comment requiert un numéro d'"'"'issue'}"
        MSG="${2:?'comment requiert un message'}"
        payload=$(jq -n --arg b "$MSG" '{body: $b}')
        result=$(_api POST "/repos/${REPO}/issues/${NUM}/comments" "$payload")
        url=$(echo "$result" | jq -r '.html_url // .url')
        echo -e "${GREEN}✓ Commentaire ajouté${NC} sur #${NUM}"
        echo -e "  URL : ${CYAN}${url}${NC}"
        ;;

    # ─── label ───────────────────────────────────────────────────────────────
    label)
        NUM="${1:?'label requiert un numéro d'"'"'issue'}"
        shift
        if [[ $# -eq 0 ]]; then
            echo -e "${RED}[ERREUR]${NC} Fournir au moins un label" >&2
            exit 1
        fi
        labels_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
        _api POST "/repos/${REPO}/issues/${NUM}/labels" "{\"labels\": ${labels_json}}" >/dev/null
        echo -e "${GREEN}✓ Labels ajoutés${NC} sur #${NUM} : $*"
        ;;

    # ─── repos ───────────────────────────────────────────────────────────────
    repos)
        if [[ "$GIT_HOST" == *"github.com"* ]]; then
            result=$(_api GET "/users/${GIT_OWNER}/repos?sort=updated&per_page=30")
        else
            result=$(_api GET "/repos/search?q=${GIT_OWNER}&limit=30")
        fi
        echo ""
        echo -e "${GREEN}Repos de ${GIT_OWNER}${NC}"
        echo -e "══════════════════════════════════════════"
        echo "$result" | jq -r '.[] | "\(.full_name // .name)\t\(.description // "")"' 2>/dev/null | \
            awk -F'\t' '{printf "  %-38s %s\n", $1, substr($2,1,60)}'
        echo ""
        ;;

    # ─── analyze ─────────────────────────────────────────────────────────────
    analyze)
        NUM="${1:?'analyze requiert un numéro d'"'"'issue'}"
        shift

        AI_BACKEND="ollama"
        AI_MODEL=""
        PROMPT_TEMPLATE="issue_analyze"
        LOCAL_VERBOSE=false
        MINIFY=false
        declare -a EXTRA_FILES=()

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --ai)          shift; AI_BACKEND="${1:?'--ai requiert ollama|claude|gemini'}"; shift ;;
                --model)       shift; AI_MODEL="${1:?'--model requiert un nom de modèle'}"; shift ;;
                --template|-t) shift; PROMPT_TEMPLATE="${1:?'--template requiert un nom'}"; shift ;;
                --verbose|-v)  LOCAL_VERBOSE=true; VERBOSE=true; shift ;;
                --depth)       shift; CPSCRIPT_DEPTH="${1:-1}"; shift ;;
                --maxtoken)    shift; CPSCRIPT_MAXTOKEN="${1:-12000}"; shift ;;
                --minify)      MINIFY=true; shift ;;
                --*)           echo -e "${YELLOW}[AVERTISSEMENT]${NC} Option inconnue ignorée : $1" >&2; shift ;;
                *)             EXTRA_FILES+=("$1"); shift ;;
            esac
        done

        # Charger les clefs IA depuis cooperative_config (en plus des éventuelles vars d'env)
        ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
        GEMINI_API_KEY="${GEMINI_API_KEY:-}"
        if [[ -f "$_COOP_SH" ]]; then
            [[ -z "$ANTHROPIC_API_KEY" ]] && ANTHROPIC_API_KEY=$(bash "$_COOP_SH" get ANTHROPIC_API_KEY 2>/dev/null || true)
            [[ -z "$GEMINI_API_KEY"    ]] && GEMINI_API_KEY=$(bash    "$_COOP_SH" get GEMINI_API_KEY    2>/dev/null || true)
        fi

        # Récupérer l'issue
        echo -e "${CYAN}[issue #${NUM}]${NC} Récupération depuis ${REPO}..." >&2
        issue_json=$(_api GET "/repos/${REPO}/issues/${NUM}")
        _fmt_issue "$issue_json"

        ISSUE_TITLE=$(echo "$issue_json" | jq -r '.title')
        ISSUE_BODY=$(echo  "$issue_json" | jq -r '.body // ""' | head -c 4000)

        # Récupérer les commentaires (contexte supplémentaire)
        comments_json=$(_api GET "/repos/${REPO}/issues/${NUM}/comments")
        ISSUE_COMMENTS=$(echo "$comments_json" | jq -r '.[].body // ""' | head -c 2000)

        # ── Auto-détection des chemins de fichiers mentionnés dans l'issue ───
        _auto_detected=()
        while IFS= read -r _raw_path; do
            [[ -z "$_raw_path" ]] && continue
            _found=""
            # 1. Résolution directe (chemin relatif ou absolu)
            for _candidate in \
                "$_raw_path" \
                "${MY_PATH}/../../${_raw_path#/}" \
                "${MY_PATH}/../${_raw_path#/}" \
                "${MY_PATH}/${_raw_path#/}"; do
                if [[ -f "$_candidate" ]]; then
                    _found=$(realpath "$_candidate" 2>/dev/null || echo "$_candidate")
                    break
                fi
            done
            # 2. Fallback : find par nom de fichier (max 4 niveaux)
            if [[ -z "$_found" ]]; then
                _basename=$(basename "$_raw_path")
                _found=$(find . -maxdepth 4 -name "$_basename" -type f 2>/dev/null \
                    | grep -v node_modules | head -1)
                [[ -n "$_found" ]] && _found=$(realpath "$_found" 2>/dev/null || echo "$_found")
            fi
            [[ -n "$_found" ]] && _auto_detected+=("$_found")
        done < <(printf '%s\n%s\n%s' "$ISSUE_TITLE" "$ISSUE_BODY" "$ISSUE_COMMENTS" \
            | grep -oE '[A-Za-z0-9_./-]+\.(sh|py|html|js|ts|md)' \
            | grep -v '^[.-]' | sort -u)

        if [[ ${#_auto_detected[@]} -gt 0 ]]; then
            echo ""
            echo -e "${CYAN}[AUTO-DÉTECTION]${NC} Fichiers mentionnés dans l'issue :"
            for _f in "${_auto_detected[@]}"; do
                echo "  ✓ $_f"
            done
            read -r -p "Ajouter ces fichiers à l'analyse ? [O/n] : " _do_auto
            if [[ "${_do_auto,,}" != "n" ]]; then
                for _f in "${_auto_detected[@]}"; do
                    EXTRA_FILES+=("$_f")
                done
            fi
        fi

        # ── ÉTAPE 1 : Découverte intelligente des fichiers ────────────────────
        CPSCRIPT_BIN=$(command -v cpscript 2>/dev/null || echo "${MY_PATH}/cpscript")
        CPCODE_BIN=$(command   -v cpcode   2>/dev/null || echo "${MY_PATH}/cpcode")
        CPSCRIPT_MAXTOKEN="${CPSCRIPT_MAXTOKEN:-10000}"  # limite par fichier (qwen2.5-coder 32k ctx)

        if [[ ${#EXTRA_FILES[@]} -eq 0 ]]; then
            _INDEXER_PY="${MY_PATH}/admin/ia_db/codebase_index.py"
            _QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
            _PYTHON3="${HOME}/.astro/bin/python3"
            command -v "$_PYTHON3" &>/dev/null || _PYTHON3="$(command -v python3)"

            # Clé API Qdrant depuis ~/.zen/ai-company/.env (install-ai-company.docker.sh)
            if [[ -z "${QDRANT_API_KEY:-}" ]] && [[ -f "${HOME}/.zen/ai-company/.env" ]]; then
                _qk=$(grep -E '^QDRANT_API_KEY=' "${HOME}/.zen/ai-company/.env" | cut -d= -f2-)
                [[ -n "$_qk" ]] && export QDRANT_API_KEY="$_qk"
            fi
            _QDRANT_CURL_OPTS=()
            [[ -n "${QDRANT_API_KEY:-}" ]] && _QDRANT_CURL_OPTS=(-H "api-key: ${QDRANT_API_KEY}")

            echo ""
            echo -e "${YELLOW}[DÉCOUVERTE]${NC} Recherche de code pertinent..."

            mapfile -t _sorted_files < <(true)  # initialiser vide
            declare -A _file_scores=()
            _discovery_method="grep"

            # ── Priorité 1 : Recherche sémantique Qdrant ─────────────────────
            if curl -sf --max-time 1 "${_QDRANT_CURL_OPTS[@]}" "${_QDRANT_URL}/collections" &>/dev/null \
               && [[ -f "$_INDEXER_PY" ]]; then
                echo -e "  ${CYAN}[qdrant]${NC} Recherche sémantique..."
                _query="${ISSUE_TITLE} ${ISSUE_BODY}"
                _qdrant_raw=$("$_PYTHON3" "$_INDEXER_PY" \
                    --search "$_query" --limit 10 \
                    --workspace "${CODEBASE_ROOT:-${MY_PATH}/../..}" \
                    2>/dev/null)
                if [[ -n "$_qdrant_raw" ]]; then
                    while IFS=$'\t' read -r _score _rel_path; do
                        [[ -z "$_rel_path" ]] && continue
                        # Chercher le fichier relatif au répertoire courant ou au workspace
                        _abs=""
                        for _candidate in \
                            "$_rel_path" \
                            "${MY_PATH}/../../${_rel_path}" \
                            "${MY_PATH}/../${_rel_path}"; do
                            if [[ -f "$_candidate" ]]; then
                                _abs=$(realpath "$_candidate" 2>/dev/null || echo "$_candidate")
                                break
                            fi
                        done
                        [[ -z "$_abs" ]] && continue
                        _file_scores["$_abs"]="$_score"
                    done <<< "$_qdrant_raw"

                    mapfile -t _sorted_files < <(
                        for _f in "${!_file_scores[@]}"; do
                            printf '%s\t%s\n' "${_file_scores[$_f]}" "$_f"
                        done | sort -rn | awk -F'\t' '{print $2}' | head -10
                    )
                    _discovery_method="qdrant"
                fi
            fi

            # ── Fallback : grep par fréquence de mots-clés ───────────────────
            if [[ ${#_sorted_files[@]} -eq 0 ]]; then
                mapfile -t _keywords < <(
                    printf '%s\n%s' "$ISSUE_TITLE" "$ISSUE_BODY" \
                    | grep -oE '\b[A-Za-z_][A-Za-z0-9_]{4,}\b' \
                    | grep -vE '^(https?|ipfs|ipns|class|function|const|return|false|true|null|undefined|object|string|number|boolean|async|await|import|export|from|local|relay)$' \
                    | sort | uniq -c | sort -rn | awk '{print $2}' | head -8
                )
                declare -A _file_hits=()
                _search_root="."
                [[ -d "earth" ]] && _search_root="earth"

                for _kw in "${_keywords[@]:-}"; do
                    [[ -z "$_kw" ]] && continue
                    while IFS= read -r _hit; do
                        _f=$(echo "$_hit" | cut -d: -f1)
                        [[ -n "$_f" ]] && _file_hits["$_f"]=$(( ${_file_hits["$_f"]:-0} + 1 ))
                    done < <(_grep -rn "$_kw" "$_search_root" \
                        --include="*.sh" --include="*.py" --include="*.html" --include="*.js" \
                        -l 2>/dev/null | head -20 || true)
                done

                mapfile -t _sorted_files < <(
                    for _f in "${!_file_hits[@]}"; do
                        echo "${_file_hits[$_f]} $_f"
                    done | sort -rn | awk '{print $2}' | head -10
                )
                for _f in "${_sorted_files[@]}"; do
                    _file_scores["$_f"]="${_file_hits[$_f]:-0} hits"
                done
            fi

            # ── Affichage + sélection ─────────────────────────────────────────
            if [[ ${#_sorted_files[@]} -gt 0 ]]; then
                echo ""
                if [[ "$_discovery_method" == "qdrant" ]]; then
                    echo -e "${CYAN}Fichiers les plus pertinents (similarité sémantique Qdrant) :${NC}"
                else
                    echo -e "${CYAN}Fichiers les plus pertinents (par fréquence de mots-clés) :${NC}"
                fi
                _i=1
                for _f in "${_sorted_files[@]}"; do
                    printf "  [%d] %-50s (%s)\n" "$_i" "$_f" "${_file_scores[$_f]:-?}"
                    (( _i++ ))
                done
                echo ""
                echo -e "${CYAN}Numéros à analyser (ex: 1 3), chemins libres, ou Entrée pour [1 2] :${NC}"
                read -r -a _selection
                if [[ ${#_selection[@]} -eq 0 ]]; then
                    EXTRA_FILES=("${_sorted_files[@]:0:2}")
                else
                    for _s in "${_selection[@]}"; do
                        if [[ "$_s" =~ ^[0-9]+$ ]] && (( _s >= 1 && _s <= ${#_sorted_files[@]} )); then
                            EXTRA_FILES+=("${_sorted_files[$((_s - 1))]}")
                        else
                            EXTRA_FILES+=("$_s")  # chemin libre
                        fi
                    done
                fi
            else
                echo -e "${YELLOW}Aucun fichier trouvé automatiquement.${NC}"
                echo -e "${CYAN}Entrer les fichiers/dossiers à analyser (espace-séparés, vide pour passer) :${NC}"
                read -r -a EXTRA_FILES
            fi
        fi

        # ── ÉTAPE 2 : Bundle code — cpscript par fichier, déduplication Python ──
        CPSCRIPT_DEPTH="${CPSCRIPT_DEPTH:-1}"
        code_context=""
        _cpscript_jsons=()   # fichiers tmp JSON par fichier analysé
        _cpcode_dirs=()      # dossiers à traiter via cpcode

        for f in "${EXTRA_FILES[@]:-}"; do
            [[ -z "$f" ]] && continue
            if [[ -f "$f" ]]; then
                echo -e "${CYAN}[cpscript --depth ${CPSCRIPT_DEPTH} --maxtoken ${CPSCRIPT_MAXTOKEN}]${NC} $(basename "$f")..." >&2
                _tmp_json=$(mktemp /tmp/cpscript_XXXXXX.json)
                ${RTK:+rtk} "$CPSCRIPT_BIN" --json \
                    --depth "$CPSCRIPT_DEPTH" \
                    --maxtoken "$CPSCRIPT_MAXTOKEN" \
                    "$f" > "$_tmp_json" 2>/dev/null || true
                # Fallback direct si JSON vide/invalide
                if ! jq -e '.files[0]' "$_tmp_json" &>/dev/null; then
                    echo -e "${YELLOW}[fallback]${NC} lecture directe $(basename "$f")" >&2
                    echo "{\"files\":[{\"path\":\"$f\",\"content\":$(python3 -c "import json,sys; print(json.dumps(open('$f').read()[:48000]))" 2>/dev/null || echo '""')}]}" > "$_tmp_json"
                fi
                _cpscript_jsons+=("$_tmp_json")
            elif [[ -d "$f" ]]; then
                _cpcode_dirs+=("$f")
            else
                echo -e "${YELLOW}[AVERTISSEMENT]${NC} Introuvable : $f" >&2
            fi
        done

        # Fusionner + dédupliquer les JSON en un seul contexte (Python)
        if [[ ${#_cpscript_jsons[@]} -gt 0 ]]; then
            code_context=$(python3 - "${_cpscript_jsons[@]}" <<'PYMERGE'
import sys, json

seen = {}
for path in sys.argv[1:]:
    try:
        data = json.load(open(path))
        for f in data.get("files", []):
            p = f.get("path", "")
            if p and p not in seen:
                seen[p] = f.get("content", "")
    except Exception:
        pass

for p, c in seen.items():
    print(f"=== {p} ===")
    print(c)
    print()
PYMERGE
            )
            rm -f "${_cpscript_jsons[@]}"
            $VERBOSE && echo -e "${CYAN}[verbose]${NC} code_context : ~$(( ${#code_context} / 4 )) tokens ($(wc -l <<< "$code_context") lignes, ${#seen[@]:-?} fichiers dédupliqués)" >&2
        fi

        # Ajouter les dossiers via cpcode
        for _d in "${_cpcode_dirs[@]:-}"; do
            echo -e "${CYAN}[cpcode --maxfilesize 32768]${NC} ${_d}..." >&2
            code_context+="### Dossier : ${_d}"$'\n'
            code_context+=$("$CPCODE_BIN" --maxfilesize 32768 sh py html js "$_d" 2>/dev/null || true)
            code_context+=$'\n\n---\n\n'
        done

        [[ -z "$code_context" ]] && code_context="(aucun code fourni — analyse basée sur la description)"

        # ── Détection des fichiers log mentionnés dans le code ou l'issue ─────
        _log_found=()
        while IFS= read -r _lraw; do
            [[ -z "$_lraw" ]] && continue
            _lexp="${_lraw//\$HOME/$HOME}"
            [[ -f "$_lexp" ]] && _log_found+=("$_lexp")
        done < <(printf '%s\n%s\n%s' "$ISSUE_BODY" "$ISSUE_COMMENTS" "$code_context" \
            | grep -oE '[A-Za-z0-9_~/.$-]+\.log' | sort -u | head -5)

        if [[ ${#_log_found[@]} -gt 0 ]]; then
            echo ""
            echo -e "${YELLOW}[LOGS]${NC} Fichiers log détectés dans le code :"
            for _lp in "${_log_found[@]}"; do echo "  - $_lp"; done
            read -r -p "Ajouter ces logs au contexte ? [n=non / Entrée=50 / nombre de lignes] : " _do_logs
            if [[ "${_do_logs,,}" != "n" ]]; then
                _log_lines=50
                [[ "$_do_logs" =~ ^[0-9]+$ ]] && _log_lines="$_do_logs"
                for _lp in "${_log_found[@]}"; do
                    code_context+=$'\n\n'"### EXTRAIT LOGS RÉELS — $(basename "$_lp") (tail -${_log_lines})"$'\n''```'$'\n'
                    code_context+=$(tail -"$_log_lines" "$_lp" 2>/dev/null || echo "(fichier introuvable ou vide)")
                    code_context+=$'\n''```'
                done
            fi
        fi

        # ── Minification du contexte code ────────────────────────────────────
        _minify_code() {
            local _input="$1"
            # Supprime les commentaires, les lignes vides, et réduit les espaces
            echo "$_input" | sed -E '/^[[:space:]]*(\/\/|#|\/\*|\*)/d; /^[[:space:]]*$/d; s/[[:space:]]+/ /g'
        }

        # ── Budget de tokens ──────────────────────────────────────────────────
        _ctx_chars=${#code_context}
        _tok_estimate=$((_ctx_chars / 4))
        # Seuil selon le backend : Claude supporte jusqu'à ~180K tokens, Ollama ~15K
        _tok_warn=15000
        [[ "${AI_BACKEND:-ollama}" == "claude" ]] && _tok_warn=80000
        if (( _tok_estimate > _tok_warn )); then
            echo ""
            echo -e "${YELLOW}[AVERTISSEMENT]${NC} Volume de code élevé : ~${_tok_estimate} tokens (seuil ${AI_BACKEND}: ${_tok_warn})" >&2
            if [[ "$MINIFY" == "true" ]]; then
                code_context=$(_minify_code "$code_context")
                echo -e "  ${CYAN}[--minify]${NC} Après minification : ~$(( ${#code_context} / 4)) tokens" >&2
            elif [[ "${AI_BACKEND:-ollama}" != "claude" ]]; then
                echo -e "  ${CYAN}Conseil :${NC} --minify pour réduire, ou --maxtoken pour limiter par fichier." >&2
            else
                echo -e "  ${CYAN}[claude]${NC} Contexte étendu disponible." >&2
                # Proposer le groupage Claude si plusieurs fichiers
                if [[ ${#EXTRA_FILES[@]} -gt 3 ]]; then
                    read -r -p "  Laisser Claude prioriser les fichiers les plus pertinents ? [O/n] : " _do_group </dev/tty
                    if [[ "${_do_group:-O}" =~ ^[oOyY]?$ ]]; then
                        _grp_claude_bin=$(command -v claude 2>/dev/null || echo "")
                        if [[ -n "$_grp_claude_bin" ]]; then
                            _cfg_grp="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
                            _grp_prompt="Issue #${NUM} — ${ISSUE_TITLE}

Description : ${ISSUE_BODY:0:500}

Fichiers disponibles :
$(printf '  %s\n' "${EXTRA_FILES[@]}")

Sélectionne les 2-3 fichiers les plus pertinents. Réponds UNIQUEMENT avec les chemins, un par ligne."
                            echo -e "${CYAN}[claude]${NC} Priorisation des fichiers..." >&2
                            _grp_result=$(CLAUDE_CONFIG_DIR="$_cfg_grp" "$_grp_claude_bin" --print "$_grp_prompt" 2>/dev/null) || true
                            if [[ -n "$_grp_result" ]]; then
                                echo ""
                                echo -e "${CYAN}── Fichiers priorisés par Claude :${NC}"
                                echo "$_grp_result"
                                echo ""
                                read -r -p "Utiliser cette sélection ? [O/n] : " _use_grp </dev/tty
                                if [[ "${_use_grp:-O}" =~ ^[oOyY]?$ ]]; then
                                    _grp_new_files=()
                                    while IFS= read -r _gf; do
                                        _gf="${_gf// /}"
                                        [[ -f "$_gf" ]] && _grp_new_files+=("$_gf")
                                    done <<< "$_grp_result"
                                    if [[ ${#_grp_new_files[@]} -gt 0 ]]; then
                                        # Reconstruire code_context avec les fichiers priorisés
                                        _grp_jsons=()
                                        for _gf in "${_grp_new_files[@]}"; do
                                            echo -e "${CYAN}[rebuild]${NC} $(basename "$_gf")" >&2
                                            _gtmp=$(mktemp /tmp/cpscript_grp_XXXXXX.json)
                                            "$CPSCRIPT_BIN" --json --depth "$CPSCRIPT_DEPTH" \
                                                --maxtoken "$CPSCRIPT_MAXTOKEN" "$_gf" > "$_gtmp" 2>/dev/null || true
                                            _grp_jsons+=("$_gtmp")
                                        done
                                        code_context=$(python3 - "${_grp_jsons[@]}" <<'PYGRP'
import sys, json
seen = {}
for path in sys.argv[1:]:
    try:
        data = json.load(open(path))
        for f in data.get("files", []):
            p = f.get("path","")
            if p and p not in seen:
                seen[p] = f.get("content","")
    except: pass
for p, c in seen.items():
    print(f"=== {p} ==="); print(c); print()
PYGRP
                                        )
                                        rm -f "${_grp_jsons[@]}"
                                        _tok_estimate=$(( ${#code_context} / 4 ))
                                        echo -e "${GREEN}Contexte réduit : ~${_tok_estimate} tokens${NC}" >&2
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        elif [[ "$MINIFY" == "true" ]]; then
            code_context=$(_minify_code "$code_context")
            echo -e "  ${CYAN}[--minify]${NC} Après minification : ~$(( ${#code_context} / 4)) tokens" >&2
        fi

        # ── Charger le template de prompt ─────────────────────────────────────
        PROMPTS_DIR="${MY_PATH}/IA/prompts"
        template_file="${PROMPTS_DIR}/${PROMPT_TEMPLATE}.md"
        if [[ -f "$template_file" ]]; then
            # Supprimer le frontmatter YAML (entre --- et ---)
            prompt_template=$(awk '/^---/{p++; next} p==1{next} {print}' "$template_file")
        else
            echo -e "${YELLOW}[AVERTISSEMENT]${NC} Template '${PROMPT_TEMPLATE}' introuvable. Utilisation du prompt par défaut." >&2
            prompt_template="Tu es un expert UPlanet/Astroport.ONE. Analyse l'issue #{{ISSUE_NUMBER}} — {{ISSUE_TITLE}}.

Description :
{{ISSUE_BODY}}

Code concerné :
{{CODE_CONTEXT}}

Propose un plan de correction concis en français (fichiers à modifier, changements à apporter)."
        fi

        # Substitution des placeholders — via Python pour éviter l'interprétation
        # shell des caractères spéciaux (accolades, backslashes, antislashs dans code_context)
        _tpl_f=$(mktemp /tmp/issue_tpl_XXXXXX.txt)
        _num_f=$(mktemp /tmp/issue_num_XXXXXX.txt)
        _ttl_f=$(mktemp /tmp/issue_ttl_XXXXXX.txt)
        _bdy_f=$(mktemp /tmp/issue_bdy_XXXXXX.txt)
        _ctx_f=$(mktemp /tmp/issue_ctx_XXXXXX.txt)
        printf '%s' "$prompt_template" > "$_tpl_f"
        printf '%s' "$NUM"             > "$_num_f"
        printf '%s' "$ISSUE_TITLE"    > "$_ttl_f"
        printf '%s' "$ISSUE_BODY"     > "$_bdy_f"
        printf '%s' "$code_context"   > "$_ctx_f"
        prompt=$(python3 - "$_tpl_f" "$_num_f" "$_ttl_f" "$_bdy_f" "$_ctx_f" <<'PYEOF'
import sys
tpl = open(sys.argv[1]).read()
out = tpl.replace("{{ISSUE_NUMBER}}", open(sys.argv[2]).read())
out = out.replace("{{ISSUE_TITLE}}",  open(sys.argv[3]).read())
out = out.replace("{{ISSUE_BODY}}",   open(sys.argv[4]).read())
out = out.replace("{{CODE_CONTEXT}}", open(sys.argv[5]).read())
sys.stdout.write(out)
PYEOF
        )
        rm -f "$_tpl_f" "$_num_f" "$_ttl_f" "$_bdy_f" "$_ctx_f"
        [[ -n "$ISSUE_COMMENTS" ]] && prompt+=$'\n\n## Commentaires existants\n\n'"$ISSUE_COMMENTS"

        # Injecter CLAUDE.md du projet comme contexte système si présent
        _claudemd=""
        for _cmd_path in "CLAUDE.md" "../CLAUDE.md" "../../CLAUDE.md"; do
            if [[ -f "$_cmd_path" ]]; then
                _claudemd=$(head -c 1500 "$_cmd_path")
                echo -e "${CYAN}[contexte]${NC} CLAUDE.md injecté depuis '${_cmd_path}' (~$(( ${#_claudemd} / 4 )) tokens)" >&2
                break
            fi
        done
        [[ -n "$_claudemd" ]] && prompt="## Contexte projet (CLAUDE.md)"$'\n\n'"${_claudemd}"$'\n\n---\n\n'"$prompt"

        # ── Choix interactif du backend si non spécifié ───────────────────────
        if [[ "${AI_BACKEND}" == "ollama" ]] && [[ -z "$AI_MODEL" ]]; then
            echo ""
            echo -e "${YELLOW}Backend IA :${NC}"
            echo "  [1] Ollama  (constellation locale)"
            echo "  [2] Claude  (Anthropic API)"
            echo "  [3] Gemini  (Google API)"
            read -r -p "Choix [1-3, défaut: 1] : " ai_choice
            case "${ai_choice:-1}" in
                2) AI_BACKEND="claude" ;;
                3) AI_BACKEND="gemini" ;;
            esac
        fi

        # ── Presse-papier portable (X11 / Wayland / fallback) ────────────────
        _copy_to_clipboard() {
            local _content="$1"
            if command -v wl-copy &>/dev/null; then
                echo "$_content" | wl-copy 2>/dev/null && return 0
            fi
            if command -v xclip &>/dev/null; then
                echo "$_content" | xclip -selection clipboard 2>/dev/null && return 0
            fi
            if command -v xsel &>/dev/null; then
                echo "$_content" | xsel --clipboard --input 2>/dev/null && return 0
            fi
            return 1
        }

        # ── Fonction IA réutilisable (analyse + fix mode) ─────────────────────
        _call_ai() {
            local _pfile="$1"
            local _backend="${2:-$AI_BACKEND}"
            local _model_override="${3:-}"

            if $VERBOSE; then
                local _tok=$(( $(wc -c < "$_pfile") / 4 ))
                local _dump="/tmp/issue_${NUM}_$(date +%H%M%S).prompt.txt"
                cp "$_pfile" "$_dump"
                echo -e "\n${CYAN}── Prompt → ${_backend} (~${_tok} tokens) ──────────────────${NC}" >&2
                cat "$_pfile" >&2
                echo -e "${CYAN}────────────────────────────────────────────────────────${NC}" >&2
                read -r -p "[ Entrée pour envoyer à l'IA ] " _v_pause </dev/tty
            fi

            case "$_backend" in
                ollama)
                    local _q="${MY_PATH}/IA/question.py"
                    local _m="${_model_override:-${AI_MODEL:-qwen2.5-coder:14b}}"
                    if [[ -f "$_q" ]]; then
                        local _augmented_pfile
                        _augmented_pfile=$(mktemp /tmp/issue_aug_XXXXXX.txt)
                        cat > "$_augmented_pfile" <<'SYSPROMPT'
Tu es un développeur senior expert en débogage, spécialisé dans le projet UPlanet/Astroport.ONE.
RÈGLES ABSOLUES :
1. FACTUEL : Ne suppose rien qui ne soit pas explicitement dans le code ou les logs fournis.
2. TRIGGER "unknown" : Si la sortie ou les logs contiennent "unknown", cherche dans le code toutes les lignes où cette chaîne est assignée ou retournée. Cite le fichier et le numéro de ligne.
3. CONTEXTE STATION : Les chemins ~/.zen/game/ sont des bases de données filesystem critiques. Les fichiers manquants dans ces chemins expliquent souvent les erreurs "unknown" ou "non autorisé".
4. POINT DE RUPTURE : Identifie la dernière étape [✅ OK] et la première [❌]/[⚠️]. Analyse UNIQUEMENT cette transition.
5. INTERDIT : Répondre "le code est correct" si un échec est documenté.
6. PENSÉE ADVERSAIRE : Si une étape est [❌], il y a FORCÉMENT une erreur de logique, de chemin ou de format. Si tu ne trouves pas d'erreur évidente, ta mission est d'insérer des instructions de LOGGING (echo en bash, console.log en JS) à l'endroit précis de la rupture pour capturer l'état des variables.
RAPPEL DES LOIS UPLANET :
- NIP-42 : L'auth exige que le tag 'relay' soit IDENTIQUE à l'URL de connexion (attention aux slashs finaux).
- ROAMING : Si SOURCE=unknown, c'est que le dossier ~/.zen/game/nostr/PUBKEY n'existe pas sur cette station.
- MARKER : Le marker .nip42_auth_... doit être écrit dans un dossier validé par 'check_authorization'.
RÉPONDS EN FRANÇAIS. PAS D'INTRODUCTION.

---

SYSPROMPT
                        cat "$_pfile" >> "$_augmented_pfile"
                        python3 "$_q" --model "$_m" \
                            --prompt-file "$_augmented_pfile" \
                            --temperature 0.1 \
                            --ctx 32768 \
                            2>/dev/null
                        rm -f "$_augmented_pfile"
                    else
                        echo -e "${RED}[ERREUR]${NC} question.py introuvable : $_q" >&2
                    fi
                    ;;
                claude)
                    local _claude_bin; _claude_bin=$(command -v claude 2>/dev/null || echo "")
                    local _issue_log="${HOME}/.zen/tmp/code_issue_sh.log"
                    mkdir -p "${HOME}/.zen/tmp"
                    if [[ -z "$_claude_bin" ]]; then
                        echo -e "${YELLOW}⚠️  claude CLI introuvable — fallback Ollama${NC}" >&2
                        echo "[$(date '+%F %T')] _call_ai: claude introuvable, fallback Ollama" >> "$_issue_log"
                        local _q="${MY_PATH}/IA/question.py"
                        [[ -f "$_q" ]] && python3 "$_q" --model "${AI_MODEL:-qwen2.5-coder:14b}" \
                            --prompt-file "$_pfile" --temperature 0.1 --ctx 32768 2>/dev/null
                    else
                        # Sélection du compte ~/.claude-* (priorité à CLAUDE_CONFIG_DIR si déjà défini)
                        local _cfg="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
                        if [[ -z "${CLAUDE_CONFIG_DIR:-}" ]]; then
                            local _accs=()
                            for _d in "${HOME}"/.claude-*/; do
                                [[ -d "$_d" ]] || continue
                                _accs+=("$(basename "$_d" | sed 's/^\.claude-//')")
                            done
                            if [[ ${#_accs[@]} -gt 1 ]]; then
                                echo -e "${CYAN}Compte Claude pour l'analyse :${NC}" >&2
                                for _i in "${!_accs[@]}"; do
                                    local _mk=""; [[ "${HOME}/.claude-${_accs[$_i]}" == "$(readlink "${HOME}/.claude" 2>/dev/null)" ]] && _mk=" ✦"
                                    printf "  [%d] %s%s\n" "$((_i+1))" "${_accs[$_i]}" "$_mk" >&2
                                done
                                echo -ne "Choix [Entrée = défaut] : " >&2
                                read -r _acc_choice
                                if [[ "$_acc_choice" =~ ^[0-9]+$ ]] && (( _acc_choice >= 1 && _acc_choice <= ${#_accs[@]} )); then
                                    _cfg="${HOME}/.claude-${_accs[$((_acc_choice-1))]}"
                                fi
                            fi
                        fi
                        local _ptoks=$(( $(wc -c < "$_pfile") / 4 ))
                        echo "[$(date '+%F %T')] _call_ai: claude --print cfg=${_cfg##*/} prompt=~${_ptoks} tokens" >> "$_issue_log"
                        local _cerr_f; _cerr_f=$(mktemp /tmp/claude_err_XXXXXX.txt)
                        local _cout
                        _cout=$(CLAUDE_CONFIG_DIR="$_cfg" "$_claude_bin" --print < "$_pfile" 2>"$_cerr_f") || true
                        local _rc=$?
                        # Détection quota/rate-limit
                        if echo "$_cout" | grep -qi "weekly limit\|rate.limit\|You've hit\|quota\|resets.*am"; then
                            local _quota_msg; _quota_msg=$(echo "$_cout" | head -1)
                            echo -e "\n${YELLOW}⚠️  Quota Claude (${_cfg##*-}) : ${_quota_msg}${NC}" >&2
                            echo "[$(date '+%F %T')] quota: ${_quota_msg}" >> "$_issue_log"
                            _cout=""
                            # Lister les comptes alternatifs avec niveau restant
                            local _alt_accs=() _alt_slugs=()
                            for _ad in "${HOME}"/.claude-*/; do
                                [[ -d "$_ad" ]] || continue
                                [[ "$_ad" == "${_cfg%/}/" ]] && continue
                                local _aslug; _aslug=$(basename "$_ad" | sed 's/^\.claude-//')
                                _alt_accs+=("$_ad")
                                _alt_slugs+=("$_aslug")
                            done
                            if [[ ${#_alt_accs[@]} -gt 0 ]]; then
                                echo -e "${CYAN}Comptes Claude disponibles :${NC}" >&2
                                local _ai=1
                                for _as in "${_alt_slugs[@]}"; do
                                    local _amk=""; [[ "${HOME}/.claude-${_as}" == "$(readlink "${HOME}/.claude" 2>/dev/null)" ]] && _amk=" ✦"
                                    # Quota info depuis settings si disponible
                                    local _ainfo=""
                                    local _ahist="${HOME}/.claude-${_as}/history.jsonl"
                                    _ainfo=""
                                    [[ -f "$_ahist" ]] && _ainfo=$(python3 -c "
import json
from datetime import datetime
try:
    lines=[l for l in open('$_ahist').readlines() if l.strip()]
    if lines:
        d=json.loads(lines[-1])
        ts=d.get('timestamp',0)
        dt=datetime.fromtimestamp(ts/1000).strftime('%Y-%m-%d')
        print(f'dernière util.: {dt} ({len(lines)} req.)')
except: pass
" 2>/dev/null || true)
                                    printf "  [%d] %s%s%s\n" "$_ai" "$_as" "$_amk" "${_ainfo:+ — ${_ainfo}}" >&2
                                    (( _ai++ ))
                                done
                                read -r -p "  Utiliser ce compte [numéro/Entrée=abandonner] : " _alt_choice </dev/tty
                                if [[ "$_alt_choice" =~ ^[0-9]+$ ]] && (( _alt_choice >= 1 && _alt_choice < _ai )); then
                                    _cfg="${HOME}/.claude-${_alt_slugs[$((_alt_choice-1))]}"
                                    export CLAUDE_CONFIG_DIR="$_cfg"
                                    echo "[$(date '+%F %T')] switch to ${_cfg##*/}" >> "$_issue_log"
                                    _cout=$(CLAUDE_CONFIG_DIR="$_cfg" "$_claude_bin" --print < "$_pfile" 2>"$_cerr_f") || true
                                fi
                            else
                                echo -e "${YELLOW}[INFO]${NC} Aucun autre compte Claude — fallback Ollama." >&2
                            fi
                        fi
                        if [[ -z "$_cout" || $_rc -ne 0 ]]; then
                            local _errmsg; _errmsg=$(cat "$_cerr_f" 2>/dev/null | head -5)
                            echo "[$(date '+%F %T')] _call_ai: claude vide/erreur rc=${_rc} stderr=${_errmsg}" >> "$_issue_log"
                            if [[ -n "$_errmsg" ]]; then
                                echo -e "${YELLOW}[claude stderr]${NC} ${_errmsg}" >&2
                            fi
                            if [[ -z "$_cout" ]]; then
                                echo -e "${YELLOW}[retry]${NC} Claude via argument..." >&2
                                _cout=$(CLAUDE_CONFIG_DIR="$_cfg" "$_claude_bin" --print "$(cat "$_pfile")" 2>>"$_cerr_f") || true
                                echo "[$(date '+%F %T')] _call_ai: retry argument len=$(echo -n "$_cout" | wc -c)" >> "$_issue_log"
                            fi
                        fi
                        rm -f "$_cerr_f"
                        echo -n "$_cout"
                    fi
                    ;;
                gemini)
                    local _m="${_model_override:-${AI_MODEL:-gemini-2.0-flash}}"
                    local _pj; _pj=$(python3 -c "import json; print(json.dumps(open('$_pfile').read()))")
                    curl -s "https://generativelanguage.googleapis.com/v1beta/models/${_m}:generateContent?key=${GEMINI_API_KEY}" \
                        -H "Content-Type: application/json" \
                        -d "{\"contents\":[{\"parts\":[{\"text\":${_pj}}]}]}" \
                    | jq -r '.candidates[0].content.parts[0].text // .error.message // .' 2>/dev/null
                    ;;
                *)
                    echo -e "${RED}[ERREUR]${NC} Backend inconnu : $_backend" >&2
                    ;;
            esac
        }

        # ── Appel IA principal ────────────────────────────────────────────────
        prompt_file=$(mktemp /tmp/issue_prompt_XXXXXX.txt)
        printf '%s' "$prompt" > "$prompt_file"

        echo ""
        echo -e "${GREEN}[IA: ${AI_BACKEND}]${NC} Analyse issue #${NUM} — template '${PROMPT_TEMPLATE}'..."
        echo -e "══════════════════════════════════════════════════════"

        _issue_log="${HOME}/.zen/tmp/code_issue_sh.log"
        mkdir -p "${HOME}/.zen/tmp"
        echo "[$(date '+%F %T')] analyze #${NUM} backend=${AI_BACKEND} tokens=~$(( ${#prompt} / 4 ))" >> "$_issue_log"
        ai_result=$(_call_ai "$prompt_file") || true
        rm -f "$prompt_file"

        if [[ -n "$ai_result" ]]; then
            echo "[$(date '+%F %T')] ai_result ok len=$(echo -n "$ai_result" | wc -c)" >> "$_issue_log"
            echo -e "\n${ai_result}\n"
            $VERBOSE && { echo -e "${CYAN}── Fin réponse IA ──────────────────────────────────────${NC}"; read -r -p "[ Entrée pour continuer ] " _v_pause </dev/tty; }
        else
            echo "[$(date '+%F %T')] ai_result VIDE — vérifier ${_issue_log}" >> "$_issue_log"
            echo -e "${RED}[ERREUR]${NC} Aucune réponse IA reçue." >&2
            echo -e "  Log : ${CYAN}${_issue_log}${NC}" >&2
            read -r -p "Retenter l'analyse ? [o/N] : " _retry_ai </dev/tty
            if [[ "${_retry_ai,,}" == "o" ]]; then
                prompt_file=$(mktemp /tmp/issue_prompt_XXXXXX.txt)
                printf '%s' "$prompt" > "$prompt_file"
                ai_result=$(_call_ai "$prompt_file") || true
                rm -f "$prompt_file"
                [[ -n "$ai_result" ]] && echo -e "\n${ai_result}\n"
            fi
        fi

        # ── Workflow simplifié : analyse → fix → commit → close ─────────────────
        _wf_cfg="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
        _wf_claude=$(command -v claude 2>/dev/null || echo "")

        # Helper : commit + fermer l'issue (réutilisé par [a] et [x])
        _wf_commit_close() {
            # Stage seulement les fichiers liés à l'issue (EXTRA_FILES), fallback = tout
            local _cwd; _cwd=$(pwd)
            local _issue_mods=()
            for _ef in "${EXTRA_FILES[@]:-}"; do
                [[ -z "$_ef" ]] && continue
                local _rel="${_ef#"${_cwd}/"}"
                _rel="${_rel#./}"
                { git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null; } \
                    | grep -qxF "$_rel" && _issue_mods+=("$_rel")
            done
            # Dédoublonnage rapide
            local _unique=()
            for _f in "${_issue_mods[@]:-}"; do
                [[ " ${_unique[*]:-} " == *" $_f "* ]] || _unique+=("$_f")
            done
            if [[ ${#_unique[@]} -gt 0 ]]; then
                git add "${_unique[@]}" 2>/dev/null || true
            else
                git diff --name-only 2>/dev/null | xargs -r git add 2>/dev/null || true
                git diff --cached --name-only 2>/dev/null | xargs -r git add 2>/dev/null || true
            fi
            local _cmsg="fix(#${NUM}): ${ISSUE_TITLE}"
            if git commit -m "$_cmsg" 2>/dev/null; then
                echo -e "${GREEN}✓ Commit : ${_cmsg}${NC}"
                if [[ -n "${GIT_TOKEN:-}" ]]; then
                    _api PATCH "/repos/${REPO}/issues/${NUM}" '{"state":"closed"}' >/dev/null
                    _api POST "/repos/${REPO}/issues/${NUM}/comments" \
                        "$(jq -n --arg b "Fix commité : \`${_cmsg}\`" '{body:$b}')" >/dev/null
                    echo -e "${GREEN}✅ Issue #${NUM} fermée.${NC}"
                fi
                return 0
            else
                echo -e "${YELLOW}[INFO]${NC} Aucun changement à commiter." >&2
                return 1
            fi
        }

        _wf_done=false
        while ! $_wf_done; do
            echo ""
            echo -e "══════════════════════════════════════════════════════"
            # Compter uniquement les fichiers de l'issue modifiés (pas tous les unstaged)
            local _wf_issue_mods=0
            local _cwd2; _cwd2=$(pwd)
            for _ef in "${EXTRA_FILES[@]:-}"; do
                [[ -z "$_ef" ]] && continue
                local _rel2="${_ef#"${_cwd2}/"}"
                _rel2="${_rel2#./}"
                git diff --name-only 2>/dev/null | grep -qxF "$_rel2" && (( _wf_issue_mods++ )) || true
            done
            _wf_default="a"
            [[ $_wf_issue_mods -gt 0 ]] && _wf_default="x"

            echo -e "${YELLOW}#${NUM}${NC} ${ISSUE_TITLE}"
            [[ $_wf_issue_mods -gt 0 ]] && echo -e "  ${GREEN}[x]${NC} Commiter le fix + fermer (${_wf_issue_mods} fichier(s) modifié(s))"
            [[ -n "$_wf_claude" ]] && echo -e "  ${GREEN}[a]${NC} Auto-fix Claude — édite les fichiers directement"
            echo -e "  ${GREEN}[f]${NC} Fix texte (blocs AVANT/APRÈS → patch)"
            echo -e "  ${GREEN}[c]${NC} Commenter l'analyse sur GitHub"
            echo -e "  ${GREEN}[q]${NC} Quitter"
            echo ""
            read -r -p "Choix [Entrée=${_wf_default}] : " _wf_action </dev/tty
            _wf_action="${_wf_action:-$_wf_default}"

            case "$_wf_action" in

                # ── [a] Auto-fix : Claude interactif avec ses outils natifs ──────
                a)
                    if [[ -z "$_wf_claude" ]]; then
                        echo -e "${YELLOW}claude CLI introuvable — utilisez [f] à la place.${NC}" >&2
                        continue
                    fi
                    _af_prompt="Tu travailles dans le dépôt : $(pwd)

## Issue #${NUM} — ${ISSUE_TITLE}

${ISSUE_BODY:0:800}

## Analyse précédente

${ai_result}

## Code concerné

${code_context:0:20000}

## Consigne

1. Lis les fichiers concernés (Read tool)
2. Applique chaque correction identifiée dans l'analyse (Edit tool)
3. Vérifie le résultat (Bash: git diff)
4. Résume ce qui a changé en 3 lignes max.

Répertoire de travail : $(pwd)"
                    echo ""
                    echo -e "${CYAN}[claude]${NC} Mode auto-fix — Claude va éditer les fichiers..."
                    echo -e "${YELLOW}→ Validez chaque accès Edit/Write dans les prompts ci-dessous${NC}"
                    echo ""
                    CLAUDE_CONFIG_DIR="$_wf_cfg" "$_wf_claude" \
                        --allowedTools "Read,Bash(git diff*),Bash(git status*)" \
                        "$_af_prompt" </dev/tty || true
                    # Vérifier les modifications
                    _af_changed=$(git diff --name-only 2>/dev/null)
                    if [[ -n "$_af_changed" ]]; then
                        echo ""
                        echo -e "${CYAN}── Modifications apportées ─────────────────────────────${NC}"
                        git diff --stat 2>/dev/null
                        echo ""
                        read -r -p "Commiter et fermer l'issue #${NUM} ? [O/n] : " _af_cc </dev/tty
                        if [[ "${_af_cc:-O}" =~ ^[oOyY]?$ ]]; then
                            _wf_commit_close && _wf_done=true
                        fi
                    else
                        echo -e "${YELLOW}[INFO]${NC} Claude n'a pas modifié de fichiers — vérifiez les accès accordés."
                    fi
                    ;;

                # ── [x] Commiter les modifications existantes + fermer ────────────
                x)
                    if [[ -z "$_wf_pending" ]]; then
                        echo -e "${YELLOW}[INFO]${NC} Aucune modification non stagée. Appliquez d'abord un fix." >&2
                    else
                        echo -e "${CYAN}── Diff ────────────────────────────────────────────────────${NC}"
                        git diff --stat 2>/dev/null
                        echo ""
                        read -r -p "Commiter et fermer l'issue #${NUM} ? [O/n] : " _x_ok </dev/tty
                        [[ "${_x_ok:-O}" =~ ^[oOyY]?$ ]] && _wf_commit_close && _wf_done=true
                    fi
                    ;;

                # ── [f] Fix texte : demande à l'IA les blocs AVANT/APRÈS ─────────
                f)
                    _fix_tmpl_file="${MY_PATH}/IA/prompts/issue_fix.md"
                    if [[ -f "$_fix_tmpl_file" ]]; then
                        _fix_tmpl=$(awk '/^---/{p++; next} p==1{next} {print}' "$_fix_tmpl_file")
                    else
                        _fix_tmpl="Issue #{{ISSUE_NUMBER}} — {{ISSUE_TITLE}}

{{ISSUE_BODY}}

Code :
{{CODE_CONTEXT}}

Retourne UNIQUEMENT les blocs AVANT/APRÈS à modifier, au format :
### Fichier : <chemin>
AVANT :
\`\`\`
<ancien code>
\`\`\`
APRÈS :
\`\`\`
<nouveau code>
\`\`\`"
                    fi
                    _ftpl_f=$(mktemp /tmp/ish_ftpl_XXXXXX.txt)
                    _fnum_f=$(mktemp /tmp/ish_fnum_XXXXXX.txt)
                    _fttl_f=$(mktemp /tmp/ish_fttl_XXXXXX.txt)
                    _fbdy_f=$(mktemp /tmp/ish_fbdy_XXXXXX.txt)
                    _fctx_f=$(mktemp /tmp/ish_fctx_XXXXXX.txt)
                    printf '%s' "$_fix_tmpl"          > "$_ftpl_f"
                    printf '%s' "$NUM"                > "$_fnum_f"
                    printf '%s' "$ISSUE_TITLE"        > "$_fttl_f"
                    printf '%s' "${ISSUE_BODY:0:1000}" > "$_fbdy_f"
                    printf '%s' "${code_context:0:20000}" > "$_fctx_f"
                    _fix_p=$(python3 - "$_ftpl_f" "$_fnum_f" "$_fttl_f" "$_fbdy_f" "$_fctx_f" <<'PYEOF'
import sys
tpl = open(sys.argv[1]).read()
tpl = tpl.replace("{{ISSUE_NUMBER}}", open(sys.argv[2]).read())
tpl = tpl.replace("{{ISSUE_TITLE}}",  open(sys.argv[3]).read())
tpl = tpl.replace("{{ISSUE_BODY}}",   open(sys.argv[4]).read())
tpl = tpl.replace("{{CODE_CONTEXT}}", open(sys.argv[5]).read())
sys.stdout.write(tpl)
PYEOF
                    )
                    rm -f "$_ftpl_f" "$_fnum_f" "$_fttl_f" "$_fbdy_f" "$_fctx_f"
                    [[ -n "$_claudemd" ]] && _fix_p="$(printf '## Contexte projet\n\n%s\n\n---\n\n%s' "$_claudemd" "$_fix_p")"
                    read -r -p "💡 Indice pour guider l'IA (Entrée=vide) : " _fx_hint </dev/tty
                    [[ -n "$_fx_hint" ]] && _fix_p="PISTE : ${_fx_hint}"$'\n\n'"${_fix_p}"

                    _fix_file=$(mktemp /tmp/ish_fix_XXXXXX.txt)
                    printf '%s' "$_fix_p" > "$_fix_file"
                    echo ""
                    echo -e "${GREEN}[IA: ${AI_BACKEND}]${NC} Mode FIX — génération des blocs AVANT/APRÈS..."
                    echo -e "══════════════════════════════════════════════════════"
                    _fix_result=$(_call_ai "$_fix_file") || true
                    rm -f "$_fix_file"

                    if [[ -z "$_fix_result" ]]; then
                        echo -e "${RED}[ERREUR]${NC} Aucune réponse — voir ${HOME}/.zen/tmp/issue_sh.log" >&2
                        continue
                    fi
                    echo -e "\n${_fix_result}\n"

                    # Auto-apply des blocs AVANT/APRÈS
                    _apply_count=0; _apply_fail=0
                    _cur_file=""; _in_avant=false; _in_apres=false
                    _avant_buf=""; _apres_buf=""
                    _apply_patch() {
                        local _f="$1" _old="$2" _new="$3"
                        [[ ! -f "$_f" ]] && { echo -e "${RED}  ✗ Introuvable : $_f${NC}" >&2; ((_apply_fail++)); return; }
                        local _bak="${_f}.bak.$(date +%s)"
                        cp "$_f" "$_bak"
                        python3 - "$_f" "$_old" "$_new" <<'PYAPPLY' && {
import sys
path, old_s, new_s = sys.argv[1], open(sys.argv[2]).read(), open(sys.argv[3]).read()
src = open(path).read()
if old_s not in src: sys.exit(1)
open(path,'w').write(src.replace(old_s,new_s,1))
PYAPPLY
                            echo -e "${GREEN}  ✓${NC} $(basename "$_f")"
                            ((_apply_count++))
                        } || {
                            cp "$_bak" "$_f"; rm -f "$_bak"
                            echo -e "${RED}  ✗ AVANT non trouvé dans $_f${NC}" >&2
                            ((_apply_fail++))
                        }
                    }
                    _av_f=$(mktemp /tmp/ish_av_XXXXXX.txt)
                    _ap_f=$(mktemp /tmp/ish_ap_XXXXXX.txt)
                    while IFS= read -r _ln; do
                        if [[ "$_ln" =~ ^###[[:space:]]+Fichier[[:space:]]*:[[:space:]]*(.*) ]]; then
                            if [[ -n "$_cur_file" && -n "$_avant_buf" && -n "$_apres_buf" ]]; then
                                printf '%s' "$_avant_buf" > "$_av_f"
                                printf '%s' "$_apres_buf" > "$_ap_f"
                                _apply_patch "$_cur_file" "$_av_f" "$_ap_f"
                            fi
                            _cur_file="${BASH_REMATCH[1]// /}"
                            _avant_buf=""; _apres_buf=""; _in_avant=false; _in_apres=false
                        elif [[ "$_ln" == AVANT* ]]; then _in_avant=true; _in_apres=false
                        elif [[ "$_ln" == "APRÈS"* || "$_ln" == APRES* ]]; then _in_avant=false; _in_apres=true
                        elif [[ "$_ln" == '```'* ]]; then :
                        elif $_in_avant; then _avant_buf+="${_ln}"$'\n'
                        elif $_in_apres; then _apres_buf+="${_ln}"$'\n'
                        fi
                    done <<< "$_fix_result"
                    if [[ -n "$_cur_file" && -n "$_avant_buf" && -n "$_apres_buf" ]]; then
                        printf '%s' "$_avant_buf" > "$_av_f"
                        printf '%s' "$_apres_buf" > "$_ap_f"
                        _apply_patch "$_cur_file" "$_av_f" "$_ap_f"
                    fi
                    rm -f "$_av_f" "$_ap_f"
                    echo -e "${GREEN}Résultat : ${_apply_count} appliqué(s), ${_apply_fail} échec(s)${NC}"
                    if (( _apply_count > 0 )); then
                        git diff --stat 2>/dev/null
                        echo ""
                        read -r -p "Commiter et fermer l'issue #${NUM} ? [O/n] : " _f_cc </dev/tty
                        [[ "${_f_cc:-O}" =~ ^[oOyY]?$ ]] && _wf_commit_close && _wf_done=true
                    fi
                    ;;

                # ── [c] Commenter l'analyse sur GitHub ────────────────────────────
                c)
                    if [[ -z "$GIT_TOKEN" ]]; then
                        echo -e "${RED}[ERREUR]${NC} GIT_TOKEN requis." >&2
                    else
                        _cb="**Analyse IA (${AI_BACKEND}) — #${NUM}**"$'\n\n'"${ai_result}"
                        _cr=$(_api POST "/repos/${REPO}/issues/${NUM}/comments" \
                            "$(jq -n --arg b "$_cb" '{body:$b}')")
                        echo -e "${GREEN}✓ Commentaire posté${NC} : ${CYAN}$(echo "$_cr" | jq -r '.html_url // .url')${NC}"
                    fi
                    ;;

                q|*) _wf_done=true ;;
            esac
        done
        ;;

    # ─── pr ──────────────────────────────────────────────────────────────────
    pr)
        NUM="${1:?'pr requiert un numéro d'"'"'issue'}"
        shift
        PR_BASE=""
        PR_TITLE_OVERRIDE=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --base) shift; PR_BASE="$1"; shift ;;
                --title) shift; PR_TITLE_OVERRIDE="$1"; shift ;;
                *) shift ;;
            esac
        done

        # Issue pour le titre
        issue_json=$(_api GET "/repos/${REPO}/issues/${NUM}")
        _issue_title=$(echo "$issue_json" | jq -r '.title')

        _pr_branch=$(_git branch --show-current 2>/dev/null || echo "fix/issue-${NUM}")
        if [[ -z "$PR_BASE" ]]; then
            PR_BASE=$(_git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}' || echo "master")
        fi
        _pr_title="${PR_TITLE_OVERRIDE:-"fix: ${_issue_title} (closes #${NUM})"}"
        _pr_body="Closes #${NUM}"$'\n\n'"Correction de l'issue [#${NUM}](${GIT_HOST}/${REPO}/issues/${NUM}) : **${_issue_title}**"

        echo ""
        echo -e "${YELLOW}Création Pull Request${NC}"
        echo -e "  Branche source : ${CYAN}${_pr_branch}${NC} → cible : ${CYAN}${PR_BASE}${NC}"
        echo -e "  Titre : ${_pr_title}"

        # Pusher la branche si absente du remote
        if ! _git ls-remote --exit-code origin "$_pr_branch" &>/dev/null; then
            echo -e "${CYAN}[git]${NC} Push de '${_pr_branch}' vers origin..."
            _git push -u origin "$_pr_branch" 2>&1 | tail -3 || true
        fi

        _pr_payload=$(jq -n \
            --arg t "$_pr_title" \
            --arg b "$_pr_body" \
            --arg h "$_pr_branch" \
            --arg base "$PR_BASE" \
            '{title:$t, body:$b, head:$h, base:$base}')
        _pr_result=$(_api POST "/repos/${REPO}/pulls" "$_pr_payload")
        _pr_url=$(echo "$_pr_result" | jq -r '.html_url // .url')
        _pr_num=$(echo "$_pr_result" | jq -r '.number // ""')
        echo -e "${GREEN}✓ PR #${_pr_num} créée${NC} : ${CYAN}${_pr_url}${NC}"
        ;;

    *)
        echo -e "${RED}[ERREUR]${NC} Commande inconnue : ${COMMAND}"
        echo -e "  Utiliser '$0 --help' pour la liste des commandes."
        exit 1
        ;;

esac
