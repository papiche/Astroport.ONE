#!/usr/bin/env bash
# commit.sh — Génère un message de commit à partir des modifications Git
# Analyse le code modifié, résume les tâches réalisées, copie dans le presse-papier.

set -euo pipefail

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ME="${0##*/}"
[[ ! -L ~/.local/bin/${ME} ]] && ln -sf "${MY_PATH}/${ME}" ~/.local/bin/${ME} && echo "Auto Install into ~/.local/bin/${ME}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Recherche question.py : repo courant, install standard ~/.zen, répertoire du script
QUESTION_PY=""
for _candidate in \
    "$HOME/.zen/Astroport.ONE/IA/question.py" \
    "${MY_PATH}/IA/question.py" \
    "$(dirname "${MY_PATH}")/IA/question.py"; do
    if [[ -f "$_candidate" ]]; then
        QUESTION_PY="$_candidate"
        break
    fi
done

# ── Paramètres par défaut ─────────────────────────────────────────────────────
MODE="commit"         # commit | staged | day | week | month
SINCE_COMMIT="HEAD"   # référence git de base pour le diff
SINCE_LABEL="dernier commit"
AI_MODEL="qwen2.5-coder:14b"
VERBOSE=false

dbg() { [[ "$VERBOSE" == "true" ]] && echo -e "\033[2m[verbose] $*\033[0m" >&2 || true; }

# ── Aide ──────────────────────────────────────────────────────────────────────
show_help() {
    echo -e "${GREEN}commit.sh${NC} — Résumé des tâches réalisées + message de commit"
    echo ""
    echo -e "${YELLOW}USAGE:${NC}  $0 [OPTIONS]"
    echo ""
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo -e "  ${GREEN}--commit,      -c${NC}   Depuis le dernier commit (défaut)"
    echo -e "  ${GREEN}--staged,      -s${NC}   Uniquement les fichiers stagés (git add)"
    echo -e "  ${GREEN}--day,         -d${NC}   Dernières 24 heures"
    echo -e "  ${GREEN}--week,        -w${NC}   Derniers 7 jours"
    echo -e "  ${GREEN}--month,       -m${NC}   Derniers 30 jours"
    echo -e "  ${GREEN}--branch,      -b${NC}   Basculer sur cette branche avant d'analyser"
    echo -e "  ${GREEN}--model MODEL, -M${NC}   Modèle Ollama (défaut: qwen2.5-coder:14b)"
    echo -e "  ${GREEN}--verbose,     -v${NC}   Mode verbeux : affiche diff, prompt et réponse brute"
    echo -e "  ${GREEN}--help,        -h${NC}   Afficher cette aide"
    echo ""
    echo -e "${YELLOW}EXEMPLES:${NC}"
    echo "  $0                              # diff depuis le dernier commit (avec sélection branche)"
    echo "  $0 --branch fix/issue-7 --staged  # analyser la branche fix/issue-7"
    echo "  $0 --staged                     # diff des fichiers en attente de commit"
    echo "  $0 --day                        # tout ce qui a changé aujourd'hui"
    echo "  $0 --week --model qwen2.5-coder:7b  # fallback alienware (orpheus actif)"
    echo "  $0 --staged --verbose           # mode verbeux pour diagnostiquer"
    echo ""
    echo -e "${YELLOW}SORTIE:${NC}  Le message généré est affiché et copié dans le presse-papier."
    exit 0
}

# ── Parsing des arguments ─────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)   show_help ;;
        --commit|-c) MODE="commit";  SINCE_LABEL="dernier commit" ;  shift ;;
        --staged|-s) MODE="staged";  SINCE_LABEL="fichiers stagés" ; shift ;;
        --day|-d)    MODE="day";     SINCE_LABEL="24 dernières heures" ; shift ;;
        --week|-w)   MODE="week";    SINCE_LABEL="7 derniers jours" ;   shift ;;
        --month|-m)  MODE="month";   SINCE_LABEL="30 derniers jours" ;  shift ;;
        --model|-M)
            shift
            AI_MODEL="${1:?'--model requiert un nom de modèle'}"
            shift ;;
        --branch|-b)
            shift
            TARGET_BRANCH="${1:?'--branch requiert un nom de branche'}"
            shift ;;
        --verbose|-v) VERBOSE=true ; shift ;;
        *)
            echo -e "${RED}Option inconnue: $1${NC}"
            echo "Utilisez --help pour l'aide."
            exit 1 ;;
    esac
done

# ── Vérification dépôt Git ────────────────────────────────────────────────────
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Ce répertoire n'est pas un dépôt Git.${NC}"
    exit 1
fi

# ── Sélection de branche ──────────────────────────────────────────────────────
_cur_branch=$(git branch --show-current 2>/dev/null || echo "?")

# Si --branch est passé en argument, basculer directement
if [[ -n "${TARGET_BRANCH:-}" ]] && [[ "$TARGET_BRANCH" != "$_cur_branch" ]]; then
    git checkout "$TARGET_BRANCH" 2>/dev/null \
        && echo -e "${GREEN}✓ Basculé sur '${TARGET_BRANCH}'${NC}" \
        || echo -e "${RED}[ERREUR]${NC} Impossible de basculer sur '${TARGET_BRANCH}'" >&2
    _cur_branch=$(git branch --show-current 2>/dev/null || echo "?")
fi

echo -e "${BLUE}🌿 Branche courante :${NC} ${GREEN}${_cur_branch}${NC}"

# Lister les branches fix/issue-* (workflow issue.sh) + toutes les branches locales
mapfile -t _fix_branches < <(git branch --list "fix/issue-*" 2>/dev/null | sed 's/^[* ]*//' | grep -v "^$")
mapfile -t _all_branches < <(git branch 2>/dev/null | sed 's/^[* ]*//' | grep -v "^$")

if [[ ${#_all_branches[@]} -gt 1 ]]; then
    echo ""
    if [[ ${#_fix_branches[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔧 Branches de correctif (fix/issue-*) :${NC}"
        _i=1
        for _b in "${_fix_branches[@]}"; do
            _star=""; [[ "$_b" == "$_cur_branch" ]] && _star=" ${GREEN}← courante${NC}"
            printf "  [%d] %b%s%b\n" "$_i" "${GREEN}" "$_b" "${NC}${_star}"
            (( _i++ ))
        done
        echo ""
        echo -e "${YELLOW}📋 Autres branches :${NC}"
    else
        echo -e "${YELLOW}📋 Branches disponibles :${NC}"
    fi
    _j=1
    for _b in "${_all_branches[@]}"; do
        # Ne pas relister les fix branches déjà affichées si elles existent
        [[ ${#_fix_branches[@]} -gt 0 ]] && printf '%s\n' "${_fix_branches[@]}" | grep -qx "$_b" && continue
        _star=""; [[ "$_b" == "$_cur_branch" ]] && _star=" ${GREEN}← courante${NC}"
        printf "  [%s] %s%b\n" "$(( ${#_fix_branches[@]} + _j ))" "$_b" "${NC}${_star}"
        (( _j++ ))
    done

    echo ""
    echo -ne "${CYAN}Basculer sur une branche ? (numéro ou nom, Entrée pour garder '${_cur_branch}') : ${NC}"
    read -r _branch_choice

    if [[ -n "$_branch_choice" ]]; then
        # Sélection par numéro
        if [[ "$_branch_choice" =~ ^[0-9]+$ ]]; then
            _all_combined=("${_fix_branches[@]}" "${_all_branches[@]}")
            # Reconstruire la liste combinée unique en excluant doublons fix dans all
            mapfile -t _combined_unique < <(printf '%s\n' "${_fix_branches[@]}" \
                $(printf '%s\n' "${_all_branches[@]}" | grep -vxF -f <(printf '%s\n' "${_fix_branches[@]}")) \
                | grep -v "^$")
            _idx=$(( _branch_choice - 1 ))
            if (( _idx >= 0 && _idx < ${#_combined_unique[@]} )); then
                _target="${_combined_unique[$_idx]}"
                if [[ "$_target" != "$_cur_branch" ]]; then
                    git checkout "$_target" 2>/dev/null \
                        && echo -e "${GREEN}✓ Basculé sur '${_target}'${NC}" \
                        || echo -e "${RED}[ERREUR]${NC} Impossible de basculer sur '${_target}'" >&2
                    _cur_branch=$(git branch --show-current 2>/dev/null || echo "?")
                fi
            fi
        else
            # Sélection par nom
            if [[ "$_branch_choice" != "$_cur_branch" ]]; then
                git checkout "$_branch_choice" 2>/dev/null \
                    && echo -e "${GREEN}✓ Basculé sur '${_branch_choice}'${NC}" \
                    || echo -e "${RED}[ERREUR]${NC} Branche '${_branch_choice}' introuvable" >&2
                _cur_branch=$(git branch --show-current 2>/dev/null || echo "?")
            fi
        fi
    fi
fi

dbg "Dépôt Git : $(git rev-parse --show-toplevel)"
dbg "Branche   : $_cur_branch"
dbg "Mode      : $MODE"
dbg "Modèle IA : $AI_MODEL"
dbg "question.py : $QUESTION_PY ($([ -f "$QUESTION_PY" ] && echo 'trouvé' || echo 'ABSENT'))"

# ── Collecte du diff ──────────────────────────────────────────────────────────
echo -e "${BLUE}📊 Collecte des modifications ($SINCE_LABEL)...${NC}"

DIFF_CONTENT=""
DIFF_RAW=""
FILES_CHANGED=""
COMMITS_INFO=""
DIFF_STAT=""

case "$MODE" in
    staged)
        DIFF_RAW=$(git diff --cached -U0 -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' 2>/dev/null | tr -d '\0' | iconv -c -f UTF-8 -t UTF-8 || true)
        FILES_CHANGED=$(git diff --cached -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' --name-status 2>/dev/null || true)
        DIFF_STAT=$(git diff --cached --stat 2>/dev/null || true)
        if [[ -z "$DIFF_RAW" ]]; then
            echo -e "${YELLOW}⚠️  Aucun fichier stagé (git add).${NC}"
            exit 0
        fi
        ;;
    commit)
        DIFF_RAW=$(git diff HEAD -U0 -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' 2>/dev/null | tr -d '\0' | iconv -c -f UTF-8 -t UTF-8 || true)
        DIFF_RAW+=$'\n'$(git diff --cached -U0 -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' 2>/dev/null | tr -d '\0' | iconv -c -f UTF-8 -t UTF-8 || true)
        FILES_CHANGED=$(git diff HEAD -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' --name-status 2>/dev/null || true)
        FILES_CHANGED+=$'\n'$(git diff --cached -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' --name-status 2>/dev/null || true)
        DIFF_STAT=$(git diff HEAD --stat 2>/dev/null || true)
        COMMITS_INFO=$(git log -1 --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
        if [[ -z "$DIFF_RAW" || "$DIFF_RAW" =~ ^[[:space:]]*$ ]]; then
            echo -e "${YELLOW}⚠️  Aucune modification non commitée détectée.${NC}"
            echo -e "${BLUE}💡 Le dernier commit:${NC} $COMMITS_INFO"
            echo -e "${BLUE}   Utilisez --staged pour les fichiers en attente, ou --day pour les commits récents.${NC}"
            exit 0
        fi
        ;;
    day)
        SINCE_DATE=$(date -d "24 hours ago" -Iseconds 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%S")
        COMMITS_INFO=$(git log --since="$SINCE_DATE" --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
        FILES_CHANGED=$(git log --since="$SINCE_DATE" --name-status --pretty=format: 2>/dev/null | grep -v '^$' | sort -u || true)
        DIFF_CONTENT=$(git diff "HEAD@{24.hours.ago}" HEAD 2>/dev/null || git log --since="$SINCE_DATE" -p 2>/dev/null || true)
        if [[ -z "$COMMITS_INFO" ]]; then
            echo -e "${YELLOW}⚠️  Aucun commit dans les dernières 24 heures.${NC}"
            exit 0
        fi
        ;;
    week)
        SINCE_DATE=$(date -d "7 days ago" -Iseconds 2>/dev/null || date -u -v-7d +"%Y-%m-%dT%H:%M:%S")
        COMMITS_INFO=$(git log --since="$SINCE_DATE" --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
        FILES_CHANGED=$(git log --since="$SINCE_DATE" --name-status --pretty=format: 2>/dev/null | grep -v '^$' | sort -u || true)
        DIFF_CONTENT=$(git diff "HEAD@{7.days.ago}" HEAD 2>/dev/null || git log --since="$SINCE_DATE" -p 2>/dev/null || true)
        if [[ -z "$COMMITS_INFO" ]]; then
            echo -e "${YELLOW}⚠️  Aucun commit dans les 7 derniers jours.${NC}"
            exit 0
        fi
        ;;
    month)
        SINCE_DATE=$(date -d "30 days ago" -Iseconds 2>/dev/null || date -u -v-30d +"%Y-%m-%dT%H:%M:%S")
        COMMITS_INFO=$(git log --since="$SINCE_DATE" --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
        FILES_CHANGED=$(git log --since="$SINCE_DATE" --name-status --pretty=format: 2>/dev/null | grep -v '^$' | sort -u || true)
        DIFF_CONTENT=$(git diff "HEAD@{30.days.ago}" HEAD 2>/dev/null || git log --since="$SINCE_DATE" -p 2>/dev/null || true)
        if [[ -z "$COMMITS_INFO" ]]; then
            echo -e "${YELLOW}⚠️  Aucun commit dans les 30 derniers jours.${NC}"
            exit 0
        fi
        ;;
esac

dbg "Commits trouvés :"
dbg "$COMMITS_INFO"
dbg "---"
dbg "Fichiers modifiés :"
dbg "$FILES_CHANGED"

# ── Troncature head+tail (staged/commit) ou simple (day/week/month) ──────────
if [[ -n "$DIFF_RAW" ]]; then
    DIFF_ORIGINAL_LEN=${#DIFF_RAW}
    if [[ $DIFF_ORIGINAL_LEN -gt 25000 ]]; then
        DIFF_CONTENT="${DIFF_RAW:0:15000}"
        DIFF_CONTENT+=$'\n... [TRONCATURE CENTRALE] ...\n'
        DIFF_CONTENT+="${DIFF_RAW: -10000}"
        dbg "Diff tronqué head+tail : $DIFF_ORIGINAL_LEN → ~25000 caractères"
    else
        DIFF_CONTENT="$DIFF_RAW"
        dbg "Diff complet : $DIFF_ORIGINAL_LEN caractères"
    fi
else
    DIFF_ORIGINAL_LEN=${#DIFF_CONTENT}
    if [[ $DIFF_ORIGINAL_LEN -gt 24000 ]]; then
        DIFF_CONTENT="${DIFF_CONTENT:0:24000}"$'\n...[tronqué]'
        dbg "Diff tronqué : $DIFF_ORIGINAL_LEN → 24000 caractères"
    else
        dbg "Diff complet : $DIFF_ORIGINAL_LEN caractères"
    fi
fi

if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\033[2m[VERBOSE] ── Diff complet envoyé à l'IA ──────────────────────────\033[0m" >&2
    echo -e "\033[2m$DIFF_CONTENT\033[0m" >&2
    echo -e "\033[2m[VERBOSE] ────────────────────────────────────────────────────────\033[0m" >&2
fi

echo -e "${GREEN}✅ Modifications collectées${NC}"

# ── Résumé basic sans IA ──────────────────────────────────────────────────────
basic_summary() {
    local summary="## Résumé des modifications — $(date +"%Y-%m-%d")\n\n"
    summary+="**Période :** $SINCE_LABEL\n\n"

    if [[ -n "$COMMITS_INFO" ]]; then
        summary+="### Commits\n"
        while IFS= read -r line; do
            [[ -n "$line" ]] && summary+="- $line\n"
        done <<< "$COMMITS_INFO"
        summary+="\n"
    fi

    if [[ -n "$FILES_CHANGED" ]]; then
        summary+="### Fichiers modifiés\n"
        local count=0
        while IFS= read -r line; do
            if [[ -n "$line" && $count -lt 20 ]]; then
                summary+="- $line\n"
                ((count++))
            fi
        done <<< "$FILES_CHANGED"
        summary+="\n"
    fi

    echo -e "$summary"
}

# ── Appel IA via question.py ──────────────────────────────────────────────────
generate_ai_summary() {
    local prompt
    prompt=$(cat <<PROMPT
Tu es un automate d'analyse Git pour UPlanet.
INTERDICTION de faire une introduction ou des commentaires.
NE FAIS AUCUNE INTRODUCTION NI CONCLUSION. Commence directement par # COMMIT.
RÉPONSE STRICTEMENT AU FORMAT DEMANDÉ. Si tu ne respectes pas le format, un développeur sera triste.
RÉPONDS UNIQUEMENT EN FRANÇAIS.

**ANALYSE :**
1. **MESSAGE DE COMMIT :** Format <type>(<scope>): <description>
   - Scope : nom du module ou dossier principal (ex: grimoire, wotx2, live).
   - Description : impératif, pas de majuscule au début, pas de point à la fin.
   - Types autorisés : feat, fix, refactor, docs, chore
2. **SCAN DE PROTOCOLES :** Cherche dans le diff :
   - "kind.*30311" ou "NIP-53" → mentionne "Live Streaming NIP-53"
   - "kind.*22" → mentionne "publication vidéo (Kind 22)"
   - "kind.*30504" ou "uDRIVE" → mentionne "formation WoTx2 (Kind 30504)"
3. **VÉRIFICATION :** Ne cite QUE les fichiers présents dans les "Stats globales". Ne devine pas.
4. **STYLE :** Sois technique (ex: "Intègre FFmpeg WASM" plutôt que "Ajoute des vidéos").

**CONTEXTE :**
- Branche : $_cur_branch
- Période : $SINCE_LABEL
- Commits : $COMMITS_INFO

**Stats globales (seuls ces fichiers existent) :**
$DIFF_STAT

**DIFF (Extrait compact -U0, head+tail si tronqué) :**
\`\`\`
$DIFF_CONTENT
\`\`\`

**FORMAT DE RÉPONSE OBLIGATOIRE :**
# COMMIT
<type>(<scope>): <description>

## Tâches réalisées
- …

## Fichiers clés
- …
PROMPT
)

    local prompt_file
    prompt_file=$(mktemp /tmp/commit_prompt_XXXXXX.txt)
    echo "$prompt" > "$prompt_file"

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[2m[VERBOSE] ── Prompt envoyé à $AI_MODEL ──────────────────────────\033[0m" >&2
        cat "$prompt_file" >&2
        echo -e "\033[2m[VERBOSE] ────────────────────────────────────────────────────────\033[0m" >&2
    fi

    dbg "Appel : python3 $QUESTION_PY --model $AI_MODEL --prompt-file $prompt_file"
    local result
    if [[ "$VERBOSE" == "true" ]]; then
        result=$(python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 32768 --prompt-file "$prompt_file" --temperature 0.1 2>&1) || {
            rm -f "$prompt_file"
            return 1
        }
        echo -e "\033[2m[VERBOSE] ── Réponse brute de l'IA ──────────────────────────────\033[0m" >&2
        echo -e "\033[2m$result\033[0m" >&2
        echo -e "\033[2m[VERBOSE] ────────────────────────────────────────────────────────\033[0m" >&2
    else
        result=$(python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 32768 --prompt-file "$prompt_file" --temperature 0.1 2>/dev/null) || {
            rm -f "$prompt_file"
            return 1
        }
    fi
    rm -f "$prompt_file"
    echo "$result"
}

# ── Génération du résumé ──────────────────────────────────────────────────────
SUMMARY=""

if [[ -f "$QUESTION_PY" ]]; then
    echo -e "${BLUE}🤖 Analyse IA en cours (question.py)...${NC}"

    # Vérifier Ollama
    OLLAMA_SCRIPT="$HOME/.zen/Astroport.ONE/IA/ollama.me.sh"
    if [[ -f "$OLLAMA_SCRIPT" ]]; then
        dbg "Démarrage Ollama via $OLLAMA_SCRIPT"
        if [[ "$VERBOSE" == "true" ]]; then
            bash "$OLLAMA_SCRIPT" 2>&1 || true
        else
            bash "$OLLAMA_SCRIPT" >/dev/null 2>&1 || true
        fi
        sleep 1
    else
        dbg "ollama.me.sh absent, tentative directe"
    fi

    if SUMMARY=$(generate_ai_summary) && [[ -n "$SUMMARY" ]]; then
        echo -e "${GREEN}✅ Résumé IA généré${NC}"
    else
        echo -e "${YELLOW}⚠️  IA indisponible, résumé basique généré${NC}"
        SUMMARY=$(basic_summary)
    fi
else
    echo -e "${YELLOW}⚠️  question.py introuvable, résumé basique généré${NC}"
    SUMMARY=$(basic_summary)
fi

# ── Affichage ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              RÉSUMÉ DES MODIFICATIONS                       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "$SUMMARY"
echo ""

# ── Copie dans le presse-papier ───────────────────────────────────────────────
CLIPBOARD_OK=false

# Extraire uniquement le message de commit (ligne après "## Message de commit")
# Ligne sous "# COMMIT", sinon première ligne conventional commit, sinon résumé complet
COMMIT_MSG=$(echo "$SUMMARY" | grep -A1 '^# COMMIT' | tail -n1 | sed 's/^`//;s/`$//' | xargs)
if [[ -z "$COMMIT_MSG" ]]; then
    COMMIT_MSG=$(echo "$SUMMARY" | grep -Ei '^(feat|fix|refactor|docs|chore)\(' | head -n1 | sed 's/^`//;s/`$//' | xargs)
fi
if [[ -z "$COMMIT_MSG" ]]; then
    COMMIT_MSG="$SUMMARY"
fi

if command -v xclip &>/dev/null; then
    echo "$SUMMARY" | xclip -selection clipboard 2>/dev/null && CLIPBOARD_OK=true
elif command -v xsel &>/dev/null; then
    echo "$SUMMARY" | xsel --clipboard --input 2>/dev/null && CLIPBOARD_OK=true
elif command -v wl-copy &>/dev/null; then
    echo "$SUMMARY" | wl-copy 2>/dev/null && CLIPBOARD_OK=true
fi

dbg "COMMIT_MSG extrait : '$COMMIT_MSG'"

if [[ "$CLIPBOARD_OK" == "true" ]]; then
    echo -e "${GREEN}📋 Résumé copié dans le presse-papier !${NC}"
else
    echo -e "${YELLOW}⚠️  Presse-papier indisponible (xclip/xsel non trouvé).${NC}"
fi

# ── Proposition de commit ─────────────────────────────────────────────────────
if [[ "$MODE" == "staged" && -n "$COMMIT_MSG" ]]; then
    echo ""
    echo -e "${YELLOW}Message de commit suggéré :${NC}"
    echo -e "${GREEN}  $COMMIT_MSG${NC}"
    echo ""
    echo -ne "${YELLOW}Valider ce commit ? [o/N] : ${NC}"
    read -r confirm
    if [[ "$confirm" =~ ^[oOyY]$ ]]; then
        git commit -m "$COMMIT_MSG"
        echo -e "${GREEN}✅ Commit créé.${NC}"
    else
        echo -e "${BLUE}→ Commit annulé (vous pouvez le faire manuellement).${NC}"
    fi
fi
