#!/usr/bin/env bash
###############################################################################
# reporting.sh — Rapport automatique des évolutions de code multi-repos
#
# Analyse tous les dépôts synchronisés par pull.sh et génère des articles
# en langage accessible pour un public non-technique.
#
# Usage: ./reporting.sh [OPTIONS]
#
# Options:
#   --day   | -d    Analyser les dernières 24h (défaut)
#   --week  | -w    Analyser les 7 derniers jours
#   --month | -m    Analyser les 30 derniers jours
#   --publish       Publier les articles sur NOSTR (compte capitaine)
#   --json          Afficher index.json sur stdout (pour usage scriptable)
#   --output DIR    Répertoire de sortie (défaut: ~/.zen/tmp/reporting/)
#   --split N       Seuil de commits pour activer les sous-rubriques (défaut: 20)
#   --no-image      Ne pas générer d'illustrations
#   --help          Affiche cette aide
#
# Sorties:
#   ~/.zen/tmp/reporting/YYYY-MM-DD_<period>/
#     ├── index.json        Index global (usage JSON)
#     ├── summary.md        Vue d'ensemble multi-repos
#     └── <repo>.md         Article par dépôt actif
###############################################################################

set -euo pipefail

MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PULL_SCRIPT="$MY_PATH/pull.sh"
ARTICLE_SCRIPT="$MY_PATH/IA/generate_article.sh"
QUESTION_PY="$MY_PATH/IA/question.py"
NOSTR_SEND="$MY_PATH/tools/nostr_send_note.py"

# Source config UPlanet (CAPTAINEMAIL, myRELAY, etc.)
set +e
source "$HOME/.zen/Astroport.ONE/tools/my.sh" 2>/dev/null || true
set -e

PYTHON3="${HOME}/.astro/bin/python3"
command -v "$PYTHON3" &>/dev/null || PYTHON3="$(command -v python3 2>/dev/null || echo python3)"

# Couleurs (stderr uniquement)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ─── Valeurs par défaut ───────────────────────────────────────────────────────
PERIOD="day"
SINCE="24 hours ago"
PERIOD_LABEL="Dernières 24h"
PERIOD_TAG="daily"
PUBLISH=false
JSON_MODE=false
NO_IMAGE=false
VERBOSE=false         # --verbose: afficher prompts et réponses IA
SPLIT_THRESHOLD=20
OUTPUT_BASE="${HOME}/.zen/tmp/reporting"
DATE_STR="$(date +%Y-%m-%d)"

# ─── Aide ────────────────────────────────────────────────────────────────────
show_help() {
    cat >&2 <<'EOF'
reporting.sh — Rapport automatique des évolutions de code multi-repos

USAGE:
    ./reporting.sh [OPTIONS]

OPTIONS:
    --day,   -d       Analyser les dernières 24h (défaut)
    --week,  -w       Analyser les 7 derniers jours
    --month, -m       Analyser les 30 derniers jours
    --publish         Publier les articles sur NOSTR (compte capitaine)
    --json            Afficher index.json sur stdout (usage scriptable)
    --output DIR      Répertoire de sortie (défaut: ~/.zen/tmp/reporting/)
    --split N         Seuil de commits pour sous-rubriques (défaut: 20)
    --no-image        Ne pas générer d'illustrations
    --help, -h        Affiche cette aide

SORTIES:
    ~/.zen/tmp/reporting/YYYY-MM-DD_<period>/
      ├── index.json    Index global JSON
      ├── summary.md    Vue d'ensemble multi-repos
      └── <repo>.md     Article par dépôt actif

    --verbose, -v     Afficher les prompts et réponses IA (debug)

EXEMPLES:
    ./reporting.sh                          # Rapport 24h
    ./reporting.sh --week                   # Rapport 7 jours
    ./reporting.sh --month --publish        # Rapport 30 jours + NOSTR
    ./reporting.sh --day --json | jq .repos # JSON seul
    ./reporting.sh --day --verbose          # Afficher tous les échanges IA
EOF
    exit 0
}

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)   show_help ;;
        --day|-d)
            PERIOD="day"; SINCE="24 hours ago"
            PERIOD_LABEL="Dernières 24h"; PERIOD_TAG="daily"; shift ;;
        --week|-w)
            PERIOD="week"; SINCE="7 days ago"
            PERIOD_LABEL="7 derniers jours"; PERIOD_TAG="weekly"; shift ;;
        --month|-m)
            PERIOD="month"; SINCE="30 days ago"
            PERIOD_LABEL="30 derniers jours"; PERIOD_TAG="monthly"; shift ;;
        --publish)   PUBLISH=true; shift ;;
        --json)      JSON_MODE=true; shift ;;
        --no-image)  NO_IMAGE=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --output)    OUTPUT_BASE="$2"; shift 2 ;;
        --output=*)  OUTPUT_BASE="${1#--output=}"; shift ;;
        --split)     SPLIT_THRESHOLD="$2"; shift 2 ;;
        --split=*)   SPLIT_THRESHOLD="${1#--split=}"; shift ;;
        -*)          echo -e "${RED}Option inconnue: $1${NC}" >&2; show_help ;;
        *)           echo -e "${RED}Argument inattendu: $1${NC}" >&2; show_help ;;
    esac
done

OUTPUT_DIR="${OUTPUT_BASE}/${DATE_STR}_${PERIOD}"
mkdir -p "$OUTPUT_DIR"

# Redirection stderr selon le mode verbose (visible ou silencieux)
STDERR_DEV="/dev/null"
$VERBOSE && STDERR_DEV="/dev/stderr"

# ─── Activation Ollama local/swarm ────────────────────────────────────────────────────
~/.zen/Astroport.ONE/IA/ollama.me.sh 2>&1 > /dev/null

# ─── Fonctions utilitaires ────────────────────────────────────────────────────
log()     { echo -e "  ${BLUE}$*${NC}" >&2; }
ok()      { echo -e "  ${GREEN}$*${NC}" >&2; }
warn()    { echo -e "  ${YELLOW}$*${NC}" >&2; }
section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
            echo -e "${PURPLE}  $*${NC}" >&2; }

# ─── Extraire les repos depuis pull.sh ───────────────────────────────────────
# Parse les séquences "cd <path>" + "git pull" dans pull.sh
extract_repos_from_pull() {
    local pull_file="$1"
    [[ ! -f "$pull_file" ]] && return
    local prev_line=""
    while IFS= read -r line; do
        line="${line#"${line%%[! ]*}"}"  # trim leading spaces/tabs
        if [[ "$prev_line" =~ ^cd[[:space:]]+(.+) ]]; then
            local raw_path="${BASH_REMATCH[1]}"
            raw_path="${raw_path/#\~/$HOME}"
            # Résoudre les variables ($HOME, ~/.zen, etc.)
            raw_path="$(eval echo "$raw_path" 2>/dev/null || echo "$raw_path")"
            if [[ "$line" == git\ pull* ]]; then
                local repo_name
                repo_name="$(basename "$raw_path")"
                echo "${repo_name}:${raw_path}"
            fi
        fi
        prev_line="$line"
    done < "$pull_file"
}

# ─── Catégories par repo (nom:pattern_grep) ──────────────────────────────────
# Format: "CAT1:pattern1|CAT2:pattern2|..."
declare -A REPO_CATEGORIES
REPO_CATEGORIES["Astroport.ONE"]="Automatisation:^RUNTIME/|Intelligence Artificielle:^IA/|Outils:^tools/|Communication NOSTR:nostr|Économie:ZEN\.|UPlanet:^UPlanet/|UPassport:^UPassport/|Documentation:\.md$|Configuration:\.json$|\.env"
REPO_CATEGORIES["UPassport"]="API et Services:\.py$|Interfaces Web:^templates/|Outils:^tools/|Documentation:\.md$"
REPO_CATEGORIES["UPlanet"]="Applications:^Apps/|Cartographie:^earth/|Scripts:\.sh$|Documentation:\.md$"
REPO_CATEGORIES["NIP-101"]="Applications:^Apps/|Relais:relay|Synchronisation:backfill|Documentation:\.md$"
REPO_CATEGORIES["OC2UPlanet"]="Scripts:\.sh$|Documentation:\.md$"

# ─── Analyser un repo Git ─────────────────────────────────────────────────────
# Retourne les données sur stdout (format clé=valeur + blocs délimités)
analyze_repo() {
    local repo_name="$1"
    local repo_path="$2"

    if [[ ! -d "$repo_path/.git" ]]; then
        warn "⏭️  $repo_name: pas un dépôt Git ($repo_path)"
        return 1
    fi

    # Aller dans le repo
    local orig_dir="$PWD"
    cd "$repo_path"

    # Commits sur la période
    local commit_count
    commit_count=$(git log --since="$SINCE" --oneline 2>/dev/null | wc -l)
    commit_count="${commit_count// /}"  # trim whitespace

    if [[ "$commit_count" -eq 0 ]]; then
        cd "$orig_dir"
        warn "⏭️  $repo_name: aucun commit ($PERIOD_LABEL)"
        return 1
    fi

    ok "✅ $repo_name: $commit_count commit(s)"

    # Fichiers modifiés (dédupliqués)
    local changed_files
    changed_files=$(git log --since="$SINCE" --name-only --pretty=format: 2>/dev/null \
        | sort -u | grep -v '^$' || true)
    local file_count
    file_count=$(printf '%s\n' "$changed_files" | grep -c . 2>/dev/null || echo 0)
    file_count="${file_count// /}"

    # Stats résumées (+lignes/-lignes)
    local stats_str
    stats_str=$(git log --since="$SINCE" --shortstat --pretty=format: 2>/dev/null \
        | grep -E "changed" \
        | awk '{ins+=$4; del+=$6} END {printf "+%d/-%d", ins, del}' || echo "?")

    # Log lisible des commits (max 50 lignes)
    local git_log
    git_log=$(git log --since="$SINCE" \
        --pretty=format:"%ad | %s" --date=short 2>/dev/null | head -50)

    # Analyse par catégorie (si seuil dépassé et catégories définies)
    local cat_def_str="${REPO_CATEGORIES[$repo_name]:-}"
    local categories_md=""

    if [[ $commit_count -ge $SPLIT_THRESHOLD && -n "$cat_def_str" ]]; then
        # Scinder par sous-rubriques
        IFS='|' read -ra cat_defs <<< "$cat_def_str"
        for cat_def in "${cat_defs[@]}"; do
            local cat_label="${cat_def%%:*}"
            local cat_pattern="${cat_def#*:}"
            local cat_files
            cat_files=$(printf '%s\n' "$changed_files" \
                | grep -iE "$cat_pattern" 2>/dev/null | head -10 || true)
            if [[ -n "$cat_files" ]]; then
                local cat_count
                cat_count=$(printf '%s\n' "$cat_files" | wc -l)
                cat_count="${cat_count// /}"
                categories_md+="### ${cat_label}\n"
                categories_md+="$(printf '%s\n' "$cat_files" | sed 's/^/- /')\n"
                [[ $cat_count -gt 10 ]] && \
                    categories_md+="_...et $((cat_count-10)) autre(s)_\n"
                categories_md+="\n"
            fi
        done
    fi

    # Fallback : liste simple si pas de catégories
    if [[ -z "$categories_md" ]]; then
        local files_list
        files_list=$(printf '%s\n' "$changed_files" | head -20 | sed 's/^/- /')
        local remaining=$(( file_count - 20 ))
        categories_md="$files_list"
        [[ $remaining -gt 0 ]] && categories_md+="\n_...et $remaining autre(s)_"
    fi

    cd "$orig_dir"

    # Sortie structurée
    printf 'COMMIT_COUNT=%s\n' "$commit_count"
    printf 'FILE_COUNT=%s\n'   "$file_count"
    printf 'STATS=%s\n'        "$stats_str"
    printf 'SOURCE_TEXT_START\n'
    printf 'Dépôt: %s\n' "$repo_name"
    printf 'Période: %s\n' "$PERIOD_LABEL"
    printf 'Commits: %s\n' "$commit_count"
    printf 'Fichiers modifiés: %s (%s)\n\n' "$file_count" "$stats_str"
    printf 'Journal des commits:\n%s\n\n' "$git_log"
    printf 'Fichiers modifiés par catégorie:\n'
    printf '%b\n' "$categories_md"
    printf 'SOURCE_TEXT_END\n'
}

# ─── Générer l'article d'un repo ─────────────────────────────────────────────
generate_repo_article() {
    local repo_name="$1"
    local repo_path="$2"
    local output_file="$3"

    section "📦 $repo_name"

    # Analyser le repo
    local analysis
    analysis="$(analyze_repo "$repo_name" "$repo_path")" || return 1

    # Parser les données
    local commit_count file_count stats source_text
    commit_count="$(printf '%s\n' "$analysis" | grep '^COMMIT_COUNT=' | cut -d= -f2)"
    file_count="$(printf '%s\n'   "$analysis" | grep '^FILE_COUNT='   | cut -d= -f2)"
    stats="$(printf '%s\n'        "$analysis" | grep '^STATS='        | cut -d= -f2)"
    source_text="$(printf '%s\n' "$analysis" \
        | sed -n '/^SOURCE_TEXT_START$/,/^SOURCE_TEXT_END$/p' \
        | grep -v '^SOURCE_TEXT_' || true)"

    [[ -z "$commit_count" || "$commit_count" -eq 0 ]] && return 1

    # Construire le texte source brut (données Git, sans narrative — c'est generate_article.sh qui génère)
    local article_source
    article_source="$(cat <<SOURCE_EOF
📅 **Date** : ${DATE_STR}
📊 **Activité** : ${commit_count} commit(s), ${file_count} fichier(s) modifié(s)
📈 **Volume** : ${stats} lignes

---

## Détail des modifications

${source_text}

---

_Rapport généré automatiquement par \`reporting.sh\` le ${DATE_STR}_
SOURCE_EOF
)"

    # ── Appel à generate_article.sh --format json ─────────────────────────────
    # Toujours --no-image ici : les images sont générées en batch séparé (reporting.sh)
    # pour éviter les OOM quand ComfyUI est appelé N fois de suite sans libérer la RAM
    local img_opt="--no-image"

    log "🤖 Génération article JSON ($repo_name)..."

    # Mode verbose : afficher le texte source envoyé
    if $VERBOSE; then
        echo -e "\n${PURPLE}━━━ SOURCE → $repo_name ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo "$article_source" >&2
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    fi

    local article_json=""
    if [[ -f "$ARTICLE_SCRIPT" ]]; then
        article_json="$("$ARTICLE_SCRIPT" \
            --format json \
            --lang   fr \
            --title  "${repo_name} — Évolutions ${PERIOD_LABEL}" \
            --tags   "reporting uplanet ${PERIOD_TAG} opensource" \
            $img_opt \
            "$article_source" 2>"$STDERR_DEV" || echo "")"
    fi

    # Mode verbose : afficher le JSON retourné
    if $VERBOSE && [[ -n "$article_json" ]]; then
        echo -e "\n${PURPLE}━━━ JSON → $repo_name ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo "$article_json" | jq '{title, summary, tags, image_url, d_tag}' >&2 2>/dev/null \
            || echo "$article_json" >&2
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" >&2
    fi

    # ── Extraire les champs du JSON ─────────────────────────────────────────────
    local r_title r_summary r_tags_json r_image r_d_tag r_pub
    if [[ -n "$article_json" ]] && echo "$article_json" | jq . &>/dev/null 2>&1; then
        r_title="$(echo "$article_json"     | jq -r '.title // empty')"
        r_summary="$(echo "$article_json"   | jq -r '.summary // empty')"
        r_tags_json="$(echo "$article_json" | jq -c '.tags // []')"
        r_image="$(echo "$article_json"     | jq -r '.image_url // empty')"
        r_d_tag="$(echo "$article_json"     | jq -r '.d_tag // empty')"
        r_pub="$(echo "$article_json"       | jq -r '.published_at // empty')"
    fi

    # Fallbacks
    [[ -z "$r_title" ]]     && r_title="${repo_name} — Évolutions ${PERIOD_LABEL}"
    [[ -z "$r_summary" ]]   && r_summary="Évolutions de ${repo_name} sur ${PERIOD_LABEL}."
    [[ -z "$r_tags_json" ]] && r_tags_json='["uplanet","development","reporting"]'
    [[ -z "$r_image" ]]     && r_image=""
    [[ -z "$r_d_tag" ]]     && r_d_tag="repo_$(echo "${repo_name,,}" | tr -cd 'a-z0-9')_$(date +%Y%m%d)"
    [[ -z "$r_pub" ]]       && r_pub="$(date +%s)"

    # ── Écrire le fichier <repo>.md (structure propre, champs séparés) ─────────
    {
        echo "# ${r_title}"
        echo ""
        echo "> ${r_summary}"
        echo ""
        [[ -n "$r_image" ]] && echo "![Illustration](${r_image})" && echo ""
        echo "---"
        echo ""
        echo "${article_source}"
    } > "$output_file"
    ok "✅ Article: $(basename "$output_file")"

    # ── Retourner les métadonnées enrichies ─────────────────────────────────────
    printf 'RMETA_NAME=%s\n'    "$repo_name"
    printf 'RMETA_PATH=%s\n'    "$repo_path"
    printf 'RMETA_FILE=%s\n'    "$output_file"
    printf 'RMETA_COMMITS=%s\n' "$commit_count"
    printf 'RMETA_FILES=%s\n'   "$file_count"
    printf 'RMETA_TITLE=%s\n'   "$r_title"
    printf 'RMETA_IMAGE=%s\n'   "$r_image"
    printf 'RMETA_DTAG=%s\n'    "$r_d_tag"
    printf 'RMETA_PUB=%s\n'     "$r_pub"
    printf 'RMETA_TAGS=%s\n'    "$r_tags_json"
    printf 'RMETA_SUMMARY_START\n'
    printf '%s\n' "${r_summary:0:400}"
    printf 'RMETA_SUMMARY_END\n'
    printf 'RMETA_SOURCE_START\n'
    printf '%s\n' "$article_source"
    printf 'RMETA_SOURCE_END\n'
}

# ─── Publication NOSTR ────────────────────────────────────────────────────────
publish_nostr() {
    local article_file="$1"
    local title="$2"
    local summary="$3"

    [[ ! -f "$NOSTR_SEND" ]] && { warn "nostr_send_note.py introuvable"; return 1; }
    [[ -z "${CAPTAINEMAIL:-}" ]] && { warn "CAPTAINEMAIL non défini"; return 1; }

    local KEYFILE="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    [[ ! -f "$KEYFILE" ]] && { warn "Clé capitaine introuvable: $KEYFILE"; return 1; }

    local content expiration_days expiration_ts d_tag published_at tags_json
    content="$(cat "$article_file")"
    expiration_days=5
    [[ "$PERIOD" == "week" ]]  && expiration_days=14
    [[ "$PERIOD" == "month" ]] && expiration_days=28
    published_at="$(date +%s)"
    expiration_ts=$(( published_at + expiration_days * 86400 ))
    d_tag="report_${PERIOD_TAG}_${DATE_STR}_$(echo -n "$title" | md5sum | cut -c1-8)"

    tags_json="$(jq -n \
        --arg d   "$d_tag"  --arg tit "$title"   --arg sum "$summary" \
        --arg pub "$published_at" --arg exp "$expiration_ts" \
        '[ ["d",$d], ["title",$tit], ["summary",$sum],
           ["published_at",$pub], ["expiration",$exp],
           ["t","reporting"], ["t","uplanet"], ["t","development"] ]')"

    local result event_id
    result="$(python3 "$NOSTR_SEND" \
        --keyfile "$KEYFILE" --kind 30023 \
        --content "$content" --tags "$tags_json" \
        --relays "${myRELAY:-wss://relay.copylaradio.com}" \
        --json 2>&1 || true)"
    event_id="$(printf '%s\n' "$result" | jq -r '.event_id // empty' 2>/dev/null || true)"

    if [[ -n "$event_id" ]]; then
        ok "📡 Publié NOSTR: ${event_id:0:16}..."
    else
        warn "Publication NOSTR échouée"
    fi
}

# ─── Génération d'images en batch (une à la fois avec libération RAM entre chaque) ─
# generate_image.sh appelle déjà POST /free après chaque image, ce qui libère VRAM
# Appeler ici séquentiellement évite de charger ComfyUI N fois simultanément
generate_images_batch() {
    local gen_image_sh="$MY_PATH/IA/generate_image.sh"
    local comfyui_me="$MY_PATH/IA/comfyui.me.sh"

    [[ -f "$gen_image_sh" ]] || { warn "generate_image.sh introuvable"; return 1; }
    [[ -f "$comfyui_me" ]]   || { warn "comfyui.me.sh introuvable"; return 1; }
    "$comfyui_me" 2>/dev/null   || { warn "ComfyUI non accessible, images ignorées"; return 1; }

    section "🎨 Génération des illustrations (batch séquentiel)..."

    for rn in "${!REPO_SUMMARY[@]}"; do
        [[ -z "${REPO_SUMMARY[$rn]:-}" ]] && continue

        log "🖼️  Image: $rn..."

        # Générer un prompt Stable Diffusion depuis le résumé du repo
        local sd_prompt
        sd_prompt="$($PYTHON3 "$QUESTION_PY" \
            "Stable Diffusion image prompt for: ${REPO_SUMMARY[$rn]}
OUTPUT ONLY visual descriptors in English. NO text, words, brands.
Focus: composition, colors, lighting, style, abstract technology concept." \
            --model "gemma3:latest" 2>"$STDERR_DEV" | head -c 400 || true)"
        [[ -z "$sd_prompt" ]] && sd_prompt="abstract digital collaboration technology"

        # Générer l'image — generate_image.sh appelle POST /free automatiquement après
        local img_url
        img_url="$("$gen_image_sh" "$sd_prompt" 2>"$STDERR_DEV" || true)"

        if [[ -n "$img_url" ]]; then
            REPO_IMAGE[$rn]="$img_url"
            ok "  ✅ $rn → ${img_url##*/}"
            # Mettre à jour le fichier <repo>.md (ajouter l'image après le blockquote)
            local af="${OUTPUT_DIR}/${rn}.md"
            if [[ -f "$af" ]] && ! grep -q '!\[Illustration\]' "$af"; then
                # Insérer l'image après la première ligne "---"
                awk '/^---$/ && !done { print; print ""; print "![]('${img_url}')"; done=1; next } 1' \
                    "$af" > "${af}.tmp" 2>/dev/null && mv "${af}.tmp" "$af" || true
            fi
        else
            warn "  ⚠️  $rn: image non générée (ComfyUI timeout?)"
        fi

        # Pause de 2s entre chaque pour laisser la RAM se libérer
        sleep 2
    done
}

# ─── Programme principal ─────────────────────────────────────────────────────
main() {
    echo -e "${CYAN}" >&2
    echo -e "╔══════════════════════════════════════════════════════════════╗" >&2
    echo -e "║  🗞️  REPORTING — Évolutions code ($PERIOD_LABEL)" >&2
    echo -e "║  📁 Sortie : $OUTPUT_DIR" >&2
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}" >&2

    # Extraire les repos depuis pull.sh
    local -a REPOS=()
    if [[ -f "$PULL_SCRIPT" ]]; then
        while IFS= read -r entry; do
            [[ -n "$entry" ]] && REPOS+=("$entry")
        done < <(extract_repos_from_pull "$PULL_SCRIPT")
    fi

    if [[ ${#REPOS[@]} -eq 0 ]]; then
        warn "Aucun repo trouvé dans $PULL_SCRIPT"
        exit 1
    fi

    log "Repos détectés (${#REPOS[@]}) :"
    for r in "${REPOS[@]}"; do log "  • ${r%%:*}"; done

    # Traiter chaque repo
    local -a ARTICLE_FILES=()
    local total_commits=0
    local total_files=0
    local json_repos="[]"
    # Tableaux associatifs pour les champs JSON de chaque repo
    declare -A REPO_TITLE REPO_SUMMARY REPO_IMAGE REPO_SOURCE REPO_TAGS REPO_DTAG REPO_PUB

    for repo_entry in "${REPOS[@]}"; do
        local rname="${repo_entry%%:*}"
        local rpath="${repo_entry#*:}"
        local article_out="${OUTPUT_DIR}/${rname}.md"

        # Générer l'article (capture stdout = métadonnées RMETA)
        local meta
        if meta="$(generate_repo_article "$rname" "$rpath" "$article_out" 2>"$STDERR_DEV")"; then
            # Parser les métadonnées de base
            local r_commits r_files r_title r_summary r_image r_dtag r_pub r_tags r_source
            r_commits="$(printf '%s\n' "$meta" | grep '^RMETA_COMMITS=' | cut -d= -f2)"
            r_files="$(printf '%s\n'   "$meta" | grep '^RMETA_FILES='   | cut -d= -f2)"
            r_title="$(printf '%s\n'   "$meta" | grep '^RMETA_TITLE='   | cut -d= -f2-)"
            r_image="$(printf '%s\n'   "$meta" | grep '^RMETA_IMAGE='   | cut -d= -f2)"
            r_dtag="$(printf '%s\n'    "$meta" | grep '^RMETA_DTAG='    | cut -d= -f2)"
            r_pub="$(printf '%s\n'     "$meta" | grep '^RMETA_PUB='     | cut -d= -f2)"
            r_tags="$(printf '%s\n'    "$meta" | grep '^RMETA_TAGS='    | cut -d= -f2-)"
            r_summary="$(printf '%s\n' "$meta" \
                | sed -n '/^RMETA_SUMMARY_START$/,/^RMETA_SUMMARY_END$/p' \
                | grep -v '^RMETA_SUMMARY_' | tr '\n' ' ' | head -c 400)"
            r_source="$(printf '%s\n' "$meta" \
                | sed -n '/^RMETA_SOURCE_START$/,/^RMETA_SOURCE_END$/p' \
                | grep -v '^RMETA_SOURCE_')"

            total_commits=$(( total_commits + ${r_commits:-0} ))
            total_files=$(( total_files + ${r_files:-0} ))
            ARTICLE_FILES+=("$article_out")

            # Stocker dans les tableaux associatifs pour full_report.md
            REPO_TITLE[$rname]="${r_title:-$rname}"
            REPO_SUMMARY[$rname]="${r_summary:-}"
            REPO_IMAGE[$rname]="${r_image:-}"
            REPO_TAGS[$rname]="${r_tags:-[]}"
            REPO_DTAG[$rname]="${r_dtag:-}"
            REPO_PUB[$rname]="${r_pub:-}"
            REPO_SOURCE[$rname]="$r_source"

            # Ajouter au JSON index (enrichi avec image, tags, d_tag)
            json_repos="$(printf '%s\n' "$json_repos" | jq \
                --arg  name    "$rname" \
                --arg  path    "$rpath" \
                --arg  file    "$article_out" \
                --arg  title   "${r_title:-$rname}" \
                --arg  summary "${r_summary:-}" \
                --arg  image   "${r_image:-}" \
                --arg  dtag    "${r_dtag:-}" \
                --argjson tags "${r_tags:-[]}" \
                --argjson com  "${r_commits:-0}" \
                --argjson fil  "${r_files:-0}" \
                '. + [{
                    "name":$name,"path":$path,"article":$file,
                    "title":$title,"summary":$summary,
                    "image_url":$image,"d_tag":$dtag,"tags":$tags,
                    "commits":$com,"files":$fil
                }]')"

            # Pas de publication individuelle — tout sera consolidé dans full_report.md
        else
            warn "⏭️  $rname: ignoré"
        fi
    done

    if [[ ${#ARTICLE_FILES[@]} -eq 0 ]]; then
        warn "Aucun repo actif sur la période ($PERIOD_LABEL)"
        exit 0
    fi

    # ── Résumé global ─────────────────────────────────────────────────────────
    section "📋 Résumé global multi-repos..."
    local summary_file="${OUTPUT_DIR}/summary.md"

    # Extraits de chaque article pour l'IA
    local all_excerpts=""
    for af in "${ARTICLE_FILES[@]}"; do
        [[ -f "$af" ]] || continue
        local rn; rn="$(basename "$af" .md)"
        local excerpt
        excerpt="$(sed -n '/^## Résumé/,/^---/p' "$af" 2>/dev/null | head -10 || true)"
        all_excerpts+="=== ${rn} ===\n${excerpt}\n\n"
    done

    # Prompt résumé global
    local GLOBAL_PROMPT="Tu es un rédacteur de communication pour un projet collaboratif de logiciel libre.
Rédige un résumé GLOBAL de 3-4 paragraphes ACCESSIBLES pour un public NON-TECHNIQUE
sur l'ensemble des évolutions de tous les composants sur \"${PERIOD_LABEL}\".
Langue: français. COMMENCE DIRECTEMENT. Mets en valeur: avancées importantes,
impact utilisateur, fil directeur du projet. Évite le jargon technique.

Résumés par composant:
$(printf '%b\n' "$all_excerpts")"

    # Afficher le prompt global en mode verbose
    if $VERBOSE; then
        echo -e "\n${PURPLE}━━━ PROMPT GLOBAL ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo "$GLOBAL_PROMPT" >&2
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    fi
    local global_narrative
    global_narrative="$($PYTHON3 "$QUESTION_PY" "$GLOBAL_PROMPT" --model "gemma3:latest" 2>"$STDERR_DEV" \
        || echo "_Résumé global non disponible_")"
    if $VERBOSE; then
        echo -e "\n${PURPLE}━━━ RÉPONSE IA GLOBALE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo "$global_narrative" >&2
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" >&2
    fi

    # Écrire le summary.md
    {
        echo "# 🌍 Rapport Global — ${DATE_STR} (${PERIOD_LABEL})"
        echo ""
        echo "📊 **Total** : ${total_commits} commit(s), ${total_files} fichier(s) modifié(s)"
        echo ""
        echo "---"
        echo ""
        echo "## Vue d'ensemble"
        echo ""
        echo "$global_narrative"
        echo ""
        echo "---"
        echo ""
        echo "## Par composant"
        echo ""
        for af in "${ARTICLE_FILES[@]}"; do
            [[ -f "$af" ]] || continue
            local rn; rn="$(basename "$af" .md)"
            local first_para
            first_para="$(sed -n '/^## Résumé/,/^---/p' "$af" 2>/dev/null \
                | grep -v '^#\|^---' | head -3 | head -c 250 || true)"
            echo "### ${rn}"
            [[ -n "$first_para" ]] && echo "$first_para"
            echo ""
            echo "→ [Article complet](${rn}.md)"
            echo ""
        done
        echo "---"
        echo ""
        echo "_Généré par \`reporting.sh\` le ${DATE_STR}_"
    } > "$summary_file"
    ok "✅ Résumé global: $summary_file"

    # ── Article consolidé autonome pour NOSTR ────────────────────────────────
    # full_report.md est AUTONOME (pas de liens relatifs vers d'autres fichiers)
    # Structure : en-tête global + résumé narratif IA + articles inclus en corps
    local full_report="${OUTPUT_DIR}/full_report.md"
    {
        # En-tête autonome (pas emprunté à summary.md qui a des liens relatifs)
        echo "# 🌍 Rapport ${PERIOD_LABEL} — UPlanet"
        echo ""
        echo "📅 **Date** : ${DATE_STR}  "
        echo "📊 **Activité** : ${total_commits} commit(s), ${total_files} fichier(s) modifié(s)  "
        echo "📦 **Composants actifs** : ${#ARTICLE_FILES[@]}"
        echo ""
        echo "---"
        echo ""
        echo "## Vue d'ensemble"
        echo ""
        echo "$global_narrative"
        echo ""
        echo "---"
        echo ""
        # Corps : sections par repo construites depuis les champs JSON séparés
        # title/summary/image/source sont propres et autonomes (pas de liens relatifs)
        for af in "${ARTICLE_FILES[@]}"; do
            [[ -f "$af" ]] || continue
            local rn; rn="$(basename "$af" .md)"
            local sec_title="${REPO_TITLE[$rn]:-$rn}"
            local sec_summary="${REPO_SUMMARY[$rn]:-}"
            local sec_image="${REPO_IMAGE[$rn]:-}"
            local sec_source="${REPO_SOURCE[$rn]:-}"
            echo ""
            echo "---"
            echo ""
            echo "## ${sec_title}"
            echo ""
            [[ -n "$sec_summary" ]] && echo "> ${sec_summary}" && echo ""
            [[ -n "$sec_image"   ]] && echo "![Illustration](${sec_image})" && echo ""
            [[ -n "$sec_source"  ]] && echo "${sec_source}"
        done
        echo ""
        echo "---"
        echo ""
        echo "_Rapport généré par \`reporting.sh\` le ${DATE_STR}_"
    } > "$full_report"
    ok "✅ Rapport consolidé: $full_report"

    # Publication NOSTR : un seul événement kind 30023 avec tout le contenu
    if $PUBLISH; then
        log "📡 Publication NOSTR (article consolidé)..."
        publish_nostr "$full_report" \
            "Rapport ${PERIOD_LABEL} — UPlanet (${#ARTICLE_FILES[@]} composants)" \
            "${global_narrative:0:300}"
    fi

    # ── index.json ────────────────────────────────────────────────────────────
    local index_file="${OUTPUT_DIR}/index.json"
    jq -n \
        --arg  period    "$PERIOD" \
        --arg  label     "$PERIOD_LABEL" \
        --arg  date      "$DATE_STR" \
        --arg  dir       "$OUTPUT_DIR" \
        --arg  summary_f "$summary_file" \
        --argjson repos  "$json_repos" \
        --argjson commits "$total_commits" \
        --argjson files  "$total_files" \
        '{
            "period":        $period,
            "period_label":  $label,
            "date":          $date,
            "output_dir":    $dir,
            "summary_file":  $summary_f,
            "total_commits": $commits,
            "total_files":   $files,
            "repos":         $repos
        }' > "$index_file"
    ok "✅ Index JSON: $index_file"

    # ── Résumé final ──────────────────────────────────────────────────────────
    echo "" >&2
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}" >&2
    echo -e "${GREEN}║  ✅ RAPPORT TERMINÉ${NC}" >&2
    printf "${GREEN}║     📁 %s${NC}\n" "$OUTPUT_DIR" >&2
    printf "${GREEN}║     📊 %d commits, %d fichiers${NC}\n" "$total_commits" "$total_files" >&2
    printf "${GREEN}║     📝 %d article(s) — full_report.md${NC}\n" "${#ARTICLE_FILES[@]}" >&2
    printf "${GREEN}║     📋 summary.md + full_report.md + index.json${NC}\n" >&2
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}" >&2

    # Mode --json : index sur stdout
    $JSON_MODE && cat "$index_file"
    return 0
}

main "$@"