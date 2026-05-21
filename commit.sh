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

# RTK (Rust Token Killer) — proxy compact si disponible
RTK=$(command -v rtk 2>/dev/null || echo "")
_git() { ${RTK:+rtk} git "$@"; }

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
AI_BACKEND="ollama"    # ollama | claude | gemini
VERBOSE=false
PR_MODE=false
AI_ENHANCED=false

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
    echo -e "  ${GREEN}--pr,          -p${NC}   Proposer une Pull Request après push (assistance IA)"
    echo -e "  ${GREEN}--ai [BACKEND],-a${NC}   Revue de code IA. BACKEND: ollama (défaut) | claude | gemini"
    echo -e "                        claude → utilise claude CLI (OAuth ~/.claude-*), sélection du compte"
    echo -e "                        gemini → GEMINI_API_KEY requis"
    echo -e "  ${GREEN}--model MODEL, -M${NC}   Modèle LLM (défaut Ollama: qwen2.5-coder:14b | Claude: haiku)"
    echo -e "  ${GREEN}--verbose,     -v${NC}   Mode verbeux : affiche diff, prompt et réponse brute"
    echo -e "  ${GREEN}--help,        -h${NC}   Afficher cette aide"
    echo ""
    echo -e "${YELLOW}EXEMPLES:${NC}"
    echo "  $0                              # diff depuis le dernier commit (avec sélection branche)"
    echo "  $0 --staged                     # staging interactif par date → commit IA en boucle"
    echo "  $0 --staged --pr               # idem + propose une PR après push (IA)"
    echo "  $0 --staged --ai              # revue Ollama (local) + code_assistant si problèmes"
    echo "  $0 --staged --ai claude       # revue claude CLI (OAuth) + issue.sh guidé si problèmes"
    echo "  $0 --staged --ai gemini       # revue Gemini API + issue.sh guidé si problèmes"
    echo "  $0 --staged --ai --pr         # tout activé : staging guidé, revue, commit, PR"
    echo "  $0 --branch fix/issue-7 --staged  # basculer fix/issue-7 puis staging interactif"
    echo "  $0 --day                        # tout ce qui a changé aujourd'hui"
    echo "  $0 --week --model qwen2.5-coder:7b  # fallback alienware (orpheus actif)"
    echo "  $0 --staged --verbose           # mode verbeux pour diagnostiquer"
    echo ""
    echo -e "${YELLOW}SORTIE:${NC}  Le message généré est affiché et copié dans le presse-papier."
    exit 0
}

# ── Staging interactif par temporalité ───────────────────────────────────────
interactive_stage() {
    local -a unstaged untracked all_files
    local -A _fmap _fstats
    local _idx=1 _total _today _sel entry mtime fname ftype dt statinfo

    mapfile -t unstaged  < <(git diff --name-only 2>/dev/null)
    mapfile -t untracked < <(git ls-files --others --exclude-standard 2>/dev/null)
    all_files=("${unstaged[@]:-}" "${untracked[@]:-}")

    if [[ ${#all_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Aucun fichier modifié ou non-tracké.${NC}"
        return 1
    fi

    _today=$(date "+%Y-%m-%d")

    # ── Stats de lignes modifiées par fichier ─────────────────────────────────
    while IFS=$'\t' read -r added removed fnm; do
        if [[ "$added" == "-" ]]; then
            _fstats["$fnm"]="binaire"
        else
            _fstats["$fnm"]="+${added}/-${removed}"
        fi
    done < <(git diff --numstat 2>/dev/null)
    for f in "${untracked[@]:-}"; do
        [[ -f "$f" ]] && _fstats["$f"]="$(wc -l < "$f" 2>/dev/null || echo 0)L new"
    done

    echo -e "${YELLOW}📁 Fichiers disponibles (plus récent d'abord) :${NC}"
    echo ""

    while read -r entry; do
        mtime="${entry%% *}"
        fname="${entry#* }"
        dt=$(date -d "@$mtime" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
        ftype="M"
        printf '%s\n' "${untracked[@]:-}" | grep -qx "$fname" 2>/dev/null && ftype="?"
        local color="${GREEN}"; [[ "$ftype" == "?" ]] && color="${CYAN}"
        statinfo="${_fstats[$fname]:-}"
        printf "  [%2d] ${BLUE}%s${NC}  %b%-48s%b  %-14s  ${YELLOW}%s${NC}\n" \
            "$_idx" "$dt" "$color" "$fname" "${NC}" "$statinfo" "($ftype)"
        _fmap[$_idx]="$fname"
        _idx=$(( _idx + 1 ))
    done < <(
        for f in "${all_files[@]:-}"; do
            [[ -n "$f" && -e "$f" ]] || continue
            printf '%s %s\n' "$(stat -c '%Y' "$f" 2>/dev/null || echo 0)" "$f"
        done | sort -rn
    )

    _total=$(( _idx - 1 ))
    if [[ $_total -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Aucun fichier trouvé.${NC}"
        return 1
    fi

    # ── Suggestion IA de regroupement sémantique (si --ai) ───────────────────
    if [[ "${AI_ENHANCED:-false}" == "true" ]] && [[ -f "${QUESTION_PY:-}" ]]; then
        echo ""
        echo -e "${BLUE}🤖 Analyse sémantique des fichiers (--ai)...${NC}"
        local _gp_list=""
        for i in $(seq 1 "$_total"); do
            _gp_list+="  [$i] ${_fmap[$i]}  (${_fstats[${_fmap[$i]}]:-})\n"
        done
        local _gp_file
        _gp_file=$(mktemp /tmp/group_prompt_XXXXXX.txt)
        cat > "$_gp_file" <<GPROMPT
Regroupe ces fichiers git modifiés en commits logiques et cohérents.
RÉPONSE ULTRA-COURTE (max 10 lignes). FORMAT STRICT, FRANÇAIS :

Groupe A [numéros]: <type>(<scope>): <description>
Groupe B [numéros]: <type>(<scope>): <description>
...

Fichiers :
$(printf '%b' "$_gp_list")
GPROMPT
        local _groups
        _groups=$(timeout 25 python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 2048 \
            --prompt-file "$_gp_file" --temperature 0.1 2>/dev/null) || true
        rm -f "$_gp_file"
        # Nettoyer les artefacts IA (chiffres parasites en début de ligne)
        _groups=$(echo "$_groups" | sed 's/^[0-9]\+─/─/g' | sed '/^[[:space:]]*$/d')
        if [[ -n "$_groups" ]]; then
            echo -e "${CYAN}── Groupes suggérés ────────────────────────────────────────────${NC}"
            echo -e "\033[2m$_groups\033[0m"
            echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
        fi
    fi

    echo ""
    echo -e "${CYAN}Fichiers à stager pour ce commit :${NC}"
    echo -e "  ${GREEN}tout${NC} / ${GREEN}all${NC}   — tous ($_total fichiers)"
    echo -e "  ${GREEN}1-5${NC}          — plage continue"
    echo -e "  ${GREEN}1,3,7${NC}        — sélection individuelle"
    echo -e "  ${GREEN}aujourd'hui${NC}  — modifiés aujourd'hui"
    echo -e "  ${GREEN}Entrée${NC}       — annuler"
    echo ""
    echo -ne "${YELLOW}Sélection : ${NC}"
    read -r _sel

    [[ -z "$_sel" ]] && return 1

    local -a selected=()
    case "$_sel" in
        tout|all|ALL|TOUT)
            for i in $(seq 1 "$_total"); do selected+=("${_fmap[$i]}"); done ;;
        aujourd*|today|TODAY)
            for i in $(seq 1 "$_total"); do
                local f="${_fmap[$i]}"
                local mt fdt
                mt=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
                fdt=$(date -d "@$mt" "+%Y-%m-%d" 2>/dev/null || echo "")
                [[ "$fdt" == "$_today" ]] && selected+=("$f")
            done ;;
        *-*)
            if [[ "$_sel" =~ ^[0-9]+-[0-9]+$ ]]; then
                local s="${_sel%-*}" e="${_sel#*-}"
                for i in $(seq "$s" "$e"); do
                    [[ -n "${_fmap[$i]:-}" ]] && selected+=("${_fmap[$i]}")
                done
            fi ;;
        *)
            IFS=',' read -ra idxs <<< "$_sel"
            for i in "${idxs[@]}"; do
                i="${i//[[:space:]]/}"   # trim espaces (ex: "1, 4, 5" → "1","4","5")
                [[ "$i" =~ ^[0-9]+$ ]] && [[ -n "${_fmap[$i]:-}" ]] && selected+=("${_fmap[$i]}")
            done ;;
    esac

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Aucun fichier sélectionné.${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}📦 Staging :${NC}"
    for f in "${selected[@]}"; do
        git add -- "$f" 2>/dev/null \
            && echo -e "  ${GREEN}✓${NC} $f" \
            || echo -e "  ${RED}✗${NC} $f"
    done
    echo ""
    return 0
}

# ── Sélection d'un compte Claude alternatif (quota épuisé) ───────────────────
# Usage : _claude_pick_alternate "$current_cfg_path" → écrit nouveau cfg sur stdout
_claude_pick_alternate() {
    local _cur="$1"
    local _claude_bin; _claude_bin=$(command -v claude 2>/dev/null || echo "")
    [[ -z "$_claude_bin" ]] && return 1
    local _alts=()
    for _d in "${HOME}"/.claude-*/; do
        [[ -d "$_d" ]] || continue
        [[ "$_d" == "${_cur%/}/" || "$_d" == "${_cur}/" ]] && continue
        _alts+=("$_d")
    done
    if [[ ${#_alts[@]} -eq 0 ]]; then
        echo -e "${YELLOW}[INFO]${NC} Aucun autre compte Claude disponible." >&2
        return 1
    fi
    echo -e "${CYAN}Comptes Claude disponibles :${NC}" >&2
    local _i=1
    for _d in "${_alts[@]}"; do
        local _slug; _slug=$(basename "$_d" | sed 's/^\.claude-//')
        local _mk=""; [[ "$_d" == "$(readlink "${HOME}/.claude" 2>/dev/null)/" ]] && _mk=" ✦"
        # Lire le quota depuis ~/.claude-slug/settings.json ou ~/.claude-slug/quota.json si dispo
        local _quota_info=""
        local _hist_file="${_d}history.jsonl"
        if [[ -f "$_hist_file" ]]; then
            _quota_info=$(python3 -c "
import json
from datetime import datetime
try:
    lines=[l for l in open('$_hist_file').readlines() if l.strip()]
    if lines:
        d=json.loads(lines[-1])
        ts=d.get('timestamp',0)
        dt=datetime.fromtimestamp(ts/1000).strftime('%Y-%m-%d')
        print(f'dernière util.: {dt} ({len(lines)} req.)')
except: pass
" 2>/dev/null || true)
        fi
        printf "  [%d] %s%s%s\n" "$_i" "$_slug" "$_mk" "${_quota_info:+ — ${_quota_info}}" >&2
        (( _i++ ))
    done
    read -r -p "Utiliser ce compte ? [numéro/Entrée=abandonner] : " _choice </dev/tty
    if [[ "$_choice" =~ ^[0-9]+$ ]] && (( _choice >= 1 && _choice < _i )); then
        echo "${_alts[$((_choice-1))]}"
    fi
}

# ── Revue de code IA avant commit (si --ai) ───────────────────────────────────
ai_code_review() {
    [[ "${AI_ENHANCED:-false}" != "true" ]] && return
    # En mode claude, QUESTION_PY n'est pas requis
    [[ "${AI_BACKEND:-ollama}" != "claude" ]] && [[ ! -f "${QUESTION_PY:-}" ]] && return
    local diff_content="${1:-}"
    [[ -z "$diff_content" ]] && return

    echo -e "${BLUE}🔍 Revue de code IA (--ai)...${NC}"
    local _rv_file
    _rv_file=$(mktemp /tmp/review_prompt_XXXXXX.txt)
    cat > "$_rv_file" <<RVPROMPT
Tu es un reviewer de code senior. Analyse ce diff git.
RÉPONSE COURTE (max 8 lignes). EN FRANÇAIS. PAS D'INTRODUCTION.

Cherche uniquement ce qui est clairement problématique :
• Bugs évidents ou régressions (comportement cassé)
• TODOs oubliés, code mort laissé en place
• Failles de sécurité ou données sensibles exposées
• Incohérences majeures (ex: fonction modifiée mais appelants non mis à jour)

Si tout va bien → une seule ligne : "✅ Aucun problème détecté."
Si problème → "⚠️ [fichier] description courte" (une ligne par problème)

DIFF :
\`\`\`
${diff_content:0:14000}
\`\`\`
RVPROMPT

    local _review
    case "${AI_BACKEND:-ollama}" in
        claude)
            local _claude_bin; _claude_bin=$(command -v claude 2>/dev/null || echo "")
            if [[ -z "$_claude_bin" ]]; then
                echo -e "${YELLOW}⚠️  claude CLI introuvable — fallback Ollama${NC}" >&2
                _review=$(timeout 35 python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 16384 \
                    --prompt-file "$_rv_file" --temperature 0.1 2>/dev/null) || true
            else
                # Sélection du profil ~/.claude-* si plusieurs comptes existent
                local _claude_cfg="${HOME}/.claude"
                local _accs=()
                for _d in "${HOME}"/.claude-*/; do
                    [[ -d "$_d" ]] || continue
                    _accs+=("$(basename "$_d" | sed 's/^\.claude-//')")
                done
                if [[ ${#_accs[@]} -gt 1 ]]; then
                    echo -e "${CYAN}Compte Claude à utiliser pour la revue :${NC}"
                    for _i in "${!_accs[@]}"; do
                        local _mk=""; [[ "${HOME}/.claude-${_accs[$_i]}" == "$(readlink "${HOME}/.claude" 2>/dev/null)" ]] && _mk=" ✦"
                        printf "  [%d] %s%s\n" "$((_i+1))" "${_accs[$_i]}" "$_mk"
                    done
                    echo -ne "Choix [Entrée = défaut] : "
                    read -r _acc_choice
                    if [[ "$_acc_choice" =~ ^[0-9]+$ ]] && (( _acc_choice >= 1 && _acc_choice <= ${#_accs[@]} )); then
                        _claude_cfg="${HOME}/.claude-${_accs[$((_acc_choice-1))]}"
                    fi
                fi
                _review=$(CLAUDE_CONFIG_DIR="$_claude_cfg" \
                    "$_claude_bin" --print < "$_rv_file" 2>/dev/null) || true
                # Détection quota
                if echo "$_review" | grep -qi "weekly limit\|rate.limit\|You've hit\|quota\|resets.*am"; then
                    echo -e "${YELLOW}⚠️  Quota Claude (${_claude_cfg##*-}) atteint.${NC}" >&2
                    _review=""
                    local _alt_cfg; _alt_cfg=$(_claude_pick_alternate "$_claude_cfg")
                    if [[ -n "$_alt_cfg" ]]; then
                        export CLAUDE_CONFIG_DIR="$_alt_cfg"
                        _claude_cfg="$_alt_cfg"
                        _review=$(CLAUDE_CONFIG_DIR="$_claude_cfg" \
                            "$_claude_bin" --print < "$_rv_file" 2>/dev/null) || true
                    fi
                fi
            fi ;;
        gemini)
            local _api_key="${GEMINI_API_KEY:-}"
            if [[ -z "$_api_key" ]]; then
                echo -e "${YELLOW}⚠️  GEMINI_API_KEY absent — fallback Ollama${NC}" >&2
                _review=$(timeout 35 python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 16384 \
                    --prompt-file "$_rv_file" --temperature 0.1 2>/dev/null) || true
            else
                local _pj; _pj=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" < "$_rv_file")
                local _gm="${AI_MODEL:-gemini-2.0-flash}"
                _review=$(curl -sf "https://generativelanguage.googleapis.com/v1beta/models/${_gm}:generateContent?key=${_api_key}" \
                    -H "content-type: application/json" \
                    -d "{\"contents\":[{\"parts\":[{\"text\":${_pj}}]}]}" \
                    | jq -r '.candidates[0].content.parts[0].text // .error.message // empty' 2>/dev/null) || true
            fi ;;
        *)
            _review=$(timeout 35 python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 16384 \
                --prompt-file "$_rv_file" --temperature 0.1 2>/dev/null) || true ;;
    esac
    rm -f "$_rv_file"

    if [[ -n "$_review" ]]; then
        echo -e "${CYAN}── Revue de code ────────────────────────────────────────────────${NC}"
        echo -e "$_review"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
        echo ""

        # ── Cycle de correction si problèmes détectés ────────────────────
        if echo "$_review" | grep -q '⚠'; then
            echo -e "${YELLOW}🔧 Des problèmes ont été détectés par la revue.${NC}"

            # Extraire fichiers + messages depuis les lignes ⚠️
            local -A _warn_map=()
            while IFS= read -r _wl; do
                echo "$_wl" | grep -q '⚠' || continue
                local _wraw; _wraw=$(echo "$_wl" | sed 's/^[^a-zA-Z_./]*//')
                local _wf="${_wraw%% *}"
                local _wmsg="${_wraw#* }"
                [[ "$_wmsg" == "$_wf" ]] && _wmsg=""
                [[ -z "$_wf" ]] && continue
                local _wpath="$_wf"
                [[ ! -f "$_wpath" && -f "${MY_PATH}/$_wf" ]] && _wpath="${MY_PATH}/$_wf"
                [[ ! -f "$_wpath" ]] && continue
                _warn_map["$_wpath"]+="${_wmsg}; "
            done <<< "$_review"

            if [[ "${AI_BACKEND:-ollama}" == "claude" ]]; then
                # ── Mode Claude : déléguer à issue.sh pour workflow guidé ──────
                local _iss="${MY_PATH}/issue.sh"
                [[ ! -x "$_iss" ]] && _iss=$(command -v issue.sh 2>/dev/null || echo "")

                if [[ -n "$_iss" && -x "$_iss" ]]; then
                    echo -ne "${CYAN}   Créer une issue et analyser avec Claude ? [O/n] : ${NC}"
                    read -r _iss_confirm
                    if [[ "${_iss_confirm:-O}" =~ ^[oOyYÿ]?$ ]]; then
                        local _iss_title="fix(review): problèmes détectés le $(date +%Y-%m-%d)"
                        local _iss_body
                        _iss_body=$(printf "## Revue de code\n\n%s\n\n## Fichiers concernés\n\n%s" \
                            "$_review" \
                            "$(printf '%s\n' "${!_warn_map[@]}" 2>/dev/null)")
                        local _iss_num
                        _iss_num=$("$_iss" create --title "$_iss_title" --body "$_iss_body" 2>/dev/null \
                            | grep -oP '#\K[0-9]+' | head -1 || echo "")
                        if [[ -n "$_iss_num" ]]; then
                            local _commit_log="${HOME}/.zen/tmp/code_commit_sh.log"
                            mkdir -p "${HOME}/.zen/tmp"
                            echo -e "${GREEN}✅ Issue #${_iss_num} créée${NC}"
                            echo ""
                            local _head_before
                            _head_before=$(git rev-parse HEAD 2>/dev/null || echo "")
                            echo "[$(date '+%F %T')] issue.sh analyze #${_iss_num} start head=${_head_before:0:8}" >> "$_commit_log"
                            CLAUDE_CONFIG_DIR="$_claude_cfg" "$_iss" analyze "$_iss_num" --ai claude || true
                            local _head_after
                            _head_after=$(git rev-parse HEAD 2>/dev/null || echo "")
                            echo "[$(date '+%F %T')] issue.sh analyze #${_iss_num} end head=${_head_after:0:8}" >> "$_commit_log"
                            echo ""
                            # Détecter si issue.sh [x] a déjà commité le fix
                            if [[ -n "$_head_before" && "$_head_before" != "$_head_after" ]]; then
                                echo -e "${GREEN}✅ Fix commité via issue.sh — cycle terminé.${NC}"
                                echo "[$(date '+%F %T')] fix committed by issue.sh [x]" >> "$_commit_log"
                                git reset HEAD 2>/dev/null || true
                                return 0
                            fi
                            # Vérifier s'il y a des modifications non commitées
                            local _uncommitted
                            _uncommitted=$(git diff --name-only 2>/dev/null)
                            if [[ -n "$_uncommitted" ]]; then
                                echo -e "${CYAN}── Fichiers modifiés (non stagés) ──────────────────────────${NC}"
                                git diff --stat 2>/dev/null
                                echo ""
                                echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
                                echo -e "${CYAN}║  Que faire avec ces modifications ?                      ║${NC}"
                                echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
                                echo -e "${CYAN}║  [o] Re-stager et re-commiter (fix appliqué manuell.)    ║${NC}"
                                echo -e "${CYAN}║  [n] Ignorer et commiter quand même (sans les fix)       ║${NC}"
                                echo -e "${CYAN}║  [q] Quitter — corriger puis relancer commit.sh          ║${NC}"
                                echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
                                read -r -p "Choix [o/n/q] : " _fix_applied
                                echo "[$(date '+%F %T')] post-analyze choice=${_fix_applied}" >> "$_commit_log"
                                case "${_fix_applied:-q}" in
                                    o|O)
                                        git reset HEAD 2>/dev/null || true
                                        exec "$0" --staged${_cur_branch:+ --branch "$_cur_branch"}${PR_MODE:+ --pr}${AI_ENHANCED:+ --ai claude}
                                        ;;
                                    n|N)
                                        echo -e "${YELLOW}⚠️  Poursuite du commit avec les warnings en suspens.${NC}"
                                        ;;
                                    *)
                                        echo -e "${YELLOW}→ Relancez après corrections : commit.sh --staged --ai claude${NC}"
                                        echo -e "  Log : ${CYAN}${_commit_log}${NC}"
                                        git reset HEAD 2>/dev/null || true
                                        return 0
                                        ;;
                                esac
                            else
                                echo -e "${YELLOW}[INFO]${NC} Aucune modification non stagée — poursuite du commit."
                            fi
                        else
                            echo -e "${YELLOW}💡 issue.sh create a échoué (credentials ?) — correction manuelle.${NC}"
                            echo -e "${YELLOW}   issue.sh analyze --ai claude${NC}"
                        fi
                    fi
                else
                    echo -e "${YELLOW}💡 issue.sh introuvable — lance : issue.sh analyze --ai claude${NC}"
                fi
            else
                # ── Mode Ollama : code_assistant (comportement classique) ───────
                local _ca="${MY_PATH}/code_assistant"
                [[ ! -x "$_ca" ]] && _ca=$(command -v code_assistant 2>/dev/null || echo "")

                if [[ -n "$_ca" && -x "$_ca" ]]; then
                    echo -ne "${CYAN}   Corriger avec code_assistant (analyse → correction → patch) ? [o/N] : ${NC}"
                    read -r _ca_confirm
                    if [[ "$_ca_confirm" =~ ^[oOyY]$ ]]; then
                        if [[ ${#_warn_map[@]} -gt 0 ]]; then
                            for _wpath in "${!_warn_map[@]}"; do
                                local _issues="${_warn_map[$_wpath]%; }"
                                local _session
                                _session="ca-$(basename "$_wpath" | sed 's/\.[^.]*$//')-$(date +%Y%m%d)"
                                echo ""
                                echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
                                printf "${GREEN}║  🤖 code_assistant : %-38s║${NC}\n" "$(basename "$_wpath")"
                                echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
                                echo -e "${YELLOW}   Session   : $_session${NC}"
                                echo -e "${YELLOW}   Problèmes : ${_issues}${NC}"
                                echo ""
                                "$_ca" "$_wpath" \
                                    --kvbasename "$_session" \
                                    --supplement "REVUE DE COMMIT : ${_issues}" || true
                            done
                            echo ""
                            echo -e "${GREEN}✅ code_assistant terminé — relance du cycle de commit...${NC}"
                            git reset HEAD 2>/dev/null || true
                            exec "$0" --staged${_cur_branch:+ --branch "$_cur_branch"}${PR_MODE:+ --pr}${AI_ENHANCED:+ --ai}
                        else
                            echo -e "${YELLOW}💡 Fichiers non localisés — lance manuellement :${NC}"
                            echo -e "${YELLOW}   code_assistant <fichier> --kvbasename session${NC}"
                        fi
                    fi
                else
                    echo -e "${YELLOW}💡 code_assistant disponible dans ${MY_PATH}/ — correction manuelle :${NC}"
                    echo -e "${YELLOW}   code_assistant <fichier> --kvbasename session --supplement \"<problème>\"${NC}"
                fi
            fi
        fi
    fi
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
        --pr|-p)     PR_MODE=true ; shift ;;
        --ai|-a)
            AI_ENHANCED=true
            case "${2:-}" in
                claude|gemini|ollama) AI_BACKEND="${2}"; shift ;;
                *)
                    # Auto-détection : Claude si disponible, sinon Ollama
                    if command -v claude &>/dev/null && \
                       { [[ -L "${HOME}/.claude" ]] || ls "${HOME}"/.claude-*/ &>/dev/null 2>&1; }; then
                        AI_BACKEND="claude"
                    fi
                    ;;
            esac
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

if [[ ${#_all_branches[@]} -gt 1 ]] && [[ -z "${TARGET_BRANCH:-}" ]]; then
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

# ── Pull avant analyse ────────────────────────────────────────────────────────
if git remote get-url origin &>/dev/null; then
    echo -e "${BLUE}⬇️  git pull...${NC}"
    git pull --ff-only 2>&1 | grep -v '^$' || \
        echo -e "${YELLOW}⚠️  pull non fast-forward — continuez manuellement si nécessaire.${NC}"
fi

# ── Collecte du diff ──────────────────────────────────────────────────────────
echo -e "${BLUE}📊 Collecte des modifications ($SINCE_LABEL)...${NC}"

DIFF_CONTENT=""
DIFF_RAW=""
FILES_CHANGED=""
COMMITS_INFO=""
DIFF_STAT=""

case "$MODE" in
    staged)
        # Staging interactif si rien n'est encore stagé
        if [[ -z "$(git diff --cached --name-only 2>/dev/null)" ]]; then
            echo -e "${YELLOW}⚠️  Aucun fichier stagé.${NC}"
            interactive_stage || exit 0
        fi
        DIFF_RAW=$(git diff --cached -U0 -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' 2>/dev/null | tr -d '\0' | iconv -c -f UTF-8 -t UTF-8 || true)
        FILES_CHANGED=$(git diff --cached -- . ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)dist/*' ':(exclude)node_modules/*' ':(exclude)*-core.js' ':(exclude)*.wasm' ':(exclude)earth/ffmpeg/*' --name-status 2>/dev/null || true)
        DIFF_STAT=$(_git diff --cached --stat 2>/dev/null || true)
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
        DIFF_STAT=$(_git diff HEAD --stat 2>/dev/null || true)
        COMMITS_INFO=$(_git log -1 --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
        if [[ -z "$DIFF_RAW" || "$DIFF_RAW" =~ ^[[:space:]]*$ ]]; then
            echo -e "${YELLOW}⚠️  Aucune modification non commitée détectée.${NC}"
            echo -e "${BLUE}💡 Le dernier commit:${NC} $COMMITS_INFO"
            echo -e "${BLUE}   Utilisez --staged pour les fichiers en attente, ou --day pour les commits récents.${NC}"
            exit 0
        fi
        ;;
    day)
        SINCE_DATE=$(date -d "24 hours ago" -Iseconds 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%S")
        COMMITS_INFO=$(_git log --since="$SINCE_DATE" --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
        FILES_CHANGED=$(git log --since="$SINCE_DATE" --name-status --pretty=format: 2>/dev/null | grep -v '^$' | sort -u || true)
        DIFF_CONTENT=$(git diff "HEAD@{24.hours.ago}" HEAD 2>/dev/null || git log --since="$SINCE_DATE" -p 2>/dev/null || true)
        if [[ -z "$COMMITS_INFO" ]]; then
            echo -e "${YELLOW}⚠️  Aucun commit dans les dernières 24 heures.${NC}"
            exit 0
        fi
        ;;
    week)
        SINCE_DATE=$(date -d "7 days ago" -Iseconds 2>/dev/null || date -u -v-7d +"%Y-%m-%dT%H:%M:%S")
        COMMITS_INFO=$(_git log --since="$SINCE_DATE" --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
        FILES_CHANGED=$(git log --since="$SINCE_DATE" --name-status --pretty=format: 2>/dev/null | grep -v '^$' | sort -u || true)
        DIFF_CONTENT=$(git diff "HEAD@{7.days.ago}" HEAD 2>/dev/null || git log --since="$SINCE_DATE" -p 2>/dev/null || true)
        if [[ -z "$COMMITS_INFO" ]]; then
            echo -e "${YELLOW}⚠️  Aucun commit dans les 7 derniers jours.${NC}"
            exit 0
        fi
        ;;
    month)
        SINCE_DATE=$(date -d "30 days ago" -Iseconds 2>/dev/null || date -u -v-30d +"%Y-%m-%dT%H:%M:%S")
        COMMITS_INFO=$(_git log --since="$SINCE_DATE" --pretty=format:"[%h] %s (%an, %ar)" 2>/dev/null || true)
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
Tu es un automate d'analyse Git pour UPlanet/Astroport.ONE.
INTERDICTION de faire une introduction ou des commentaires.
NE FAIS AUCUNE INTRODUCTION NI CONCLUSION. Commence directement par # COMMIT.
RÉPONSE STRICTEMENT AU FORMAT DEMANDÉ.
RÉPONDS UNIQUEMENT EN FRANÇAIS.

**ANALYSE :**
1. **MESSAGE DE COMMIT :** Format <type>(<scope>): <description>
   - Scope : dossier principal des fichiers changés (ex: earth, tools, RUNTIME, tests, docs, install).
     Si plusieurs dossiers → scope = sous-projet le plus significatif (earth > tools > RUNTIME).
     Si fichier à la racine → scope = basename sans extension.
   - Description : impératif présent, pas de majuscule, pas de point final, max 72 chars.
   - Types : feat (nouvelle fonctionnalité), fix (correction), refactor, docs, chore, test
2. **SCAN DE PATTERNS TECHNIQUES :** Cherche EXACTEMENT ces chaînes dans le diff :
   - "kind.*30311" ou "NIP-53" → "Live Streaming NIP-53"
   - "kind.*1311"              → "chat live NIP-53"
   - "kind.*22\b"              → "publication vidéo Kind 22"
   - "kind.*30504" ou "uDRIVE" → "formation WoTx2 (Kind 30504)"
   - "kind.*30500"             → "permis WoTx2 (Kind 30500)"
   - "app_switch" ou "FAB"     → "navigation FAB circulaire"
   - "cidirect"                → "accès CID direct IPFS"
   - "NIP-42"                  → "auth NIP-42"
   - "MULTIPASS"               → "MULTIPASS UPlanet"
   - "keygen.*nostr"           → "dérivation clé NOSTR"
   - "rtk"                     → "intégration RTK (économie tokens)"
3. **RÈGLE FICHIERS :** Ne cite QUE les fichiers présents dans les Stats globales. Pas d'invention.
4. **STYLE :** Technique et précis. "corrige accès CID direct" plutôt que "corrige le code".

**CONTEXTE :**
- Branche : $_cur_branch
- Période : $SINCE_LABEL
- Commits : $COMMITS_INFO

**Stats globales (seuls ces fichiers existent) :**
$DIFF_STAT

**DIFF (compact -U0, head+tail si tronqué) :**
\`\`\`
$DIFF_CONTENT
\`\`\`

**FORMAT EXACT DE RÉPONSE (ne rien ajouter avant # COMMIT) :**
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
        echo -e "\033[2m[VERBOSE] ── Prompt ($(wc -c < "$prompt_file") bytes) → ${AI_BACKEND} ──\033[0m" >&2
        cat "$prompt_file" >&2
        echo -e "\033[2m[VERBOSE] ──────────────────────────────────────────────────────────\033[0m" >&2
    fi

    local result
    # Claude --print pour le résumé de commit (meilleure qualité + pas d'Ollama requis)
    if [[ "${AI_BACKEND:-ollama}" == "claude" ]] && command -v claude &>/dev/null; then
        local _sum_cfg="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
        dbg "Appel : claude --print (cfg=${_sum_cfg##*/})"
        result=$(CLAUDE_CONFIG_DIR="$_sum_cfg" claude --print < "$prompt_file" 2>/dev/null) || true
        # Détection quota/rate-limit → proposer un autre compte
        if echo "$result" | grep -qi "weekly limit\|rate.limit\|You've hit\|quota\|resets.*am\|limit.*reset"; then
            echo -e "${YELLOW}⚠️  Quota Claude (${_sum_cfg##*-}) atteint — $(echo "$result" | head -1)${NC}" >&2
            result=""
            _sum_cfg=$(_claude_pick_alternate "$_sum_cfg")
            [[ -n "$_sum_cfg" ]] && {
                export CLAUDE_CONFIG_DIR="$_sum_cfg"
                result=$(CLAUDE_CONFIG_DIR="$_sum_cfg" claude --print < "$prompt_file" 2>/dev/null) || true
            }
        fi
        if [[ -z "$result" ]] && [[ -f "${QUESTION_PY:-}" ]]; then
            dbg "Claude vide — fallback Ollama"
            result=$(python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 32768 \
                --prompt-file "$prompt_file" --temperature 0.1 2>/dev/null) || true
        fi
    else
        dbg "Appel : python3 $QUESTION_PY --model $AI_MODEL"
        if [[ "$VERBOSE" == "true" ]]; then
            result=$(python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 32768 \
                --prompt-file "$prompt_file" --temperature 0.1 2>&1) || true
            echo -e "\033[2m[VERBOSE] ── Réponse brute ───────────────────────────────────────\033[0m" >&2
            echo -e "\033[2m$result\033[0m" >&2
            echo -e "\033[2m[VERBOSE] ──────────────────────────────────────────────────────────\033[0m" >&2
        else
            result=$(python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 32768 \
                --prompt-file "$prompt_file" --temperature 0.1 2>/dev/null) || true
        fi
    fi
    rm -f "$prompt_file"
    [[ -n "$result" ]] || return 1
    echo "$result"
}

# ── Génération du résumé ──────────────────────────────────────────────────────
SUMMARY=""

if [[ -f "$QUESTION_PY" ]] || { [[ "${AI_BACKEND:-ollama}" == "claude" ]] && command -v claude &>/dev/null; }; then
    if [[ "${AI_BACKEND:-ollama}" == "claude" ]] && command -v claude &>/dev/null; then
        echo -e "${BLUE}🤖 Résumé de commit via Claude...${NC}"
    else
        echo -e "${BLUE}🤖 Analyse IA en cours (question.py)...${NC}"
    fi

    # Démarrer Ollama seulement si le backend n'est pas Claude
    if [[ "${AI_BACKEND:-ollama}" != "claude" ]]; then
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
COMMIT_MSG=$(echo "$SUMMARY" | grep -A1 '^# COMMIT' | tail -n1 | sed 's/^`//;s/`$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
if [[ -z "$COMMIT_MSG" ]]; then
    COMMIT_MSG=$(echo "$SUMMARY" | grep -Ei '^(feat|fix|refactor|docs|chore)\(' | head -n1 | sed 's/^`//;s/`$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
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
    # Revue de code IA avant validation (si --ai)
    ai_code_review "$DIFF_CONTENT"

    echo ""
    echo -e "${YELLOW}Message de commit suggéré :${NC}"
    echo -e "${GREEN}  $COMMIT_MSG${NC}"
    echo ""
    echo -ne "${CYAN}Conclusion / note à ajouter ? (Entrée pour garder tel quel) : ${NC}"
    read -r _extra
    if [[ -n "$_extra" ]]; then
        COMMIT_MSG="${COMMIT_MSG}

${_extra}"
        echo -e "${GREEN}  → Message final :${NC}"
        echo -e "${GREEN}  $COMMIT_MSG${NC}"
        echo ""
    fi
    echo -ne "${YELLOW}Valider ce commit ? [o / N / r=refaire la sélection] : ${NC}"
    read -r confirm
    if [[ "$confirm" =~ ^[rR]$ ]]; then
        echo -e "${BLUE}↩️  Dé-staging et nouvelle sélection...${NC}"
        git reset HEAD 2>/dev/null || true
        exec "$0" --staged${_cur_branch:+ --branch "$_cur_branch"}${PR_MODE:+ --pr}${AI_ENHANCED:+ --ai}
    elif [[ "$confirm" =~ ^[oOyY]$ ]]; then
        git commit -m "$COMMIT_MSG"
        echo -e "${GREEN}✅ Commit créé.${NC}"
        _pushed=false
        if git remote get-url origin &>/dev/null; then
            echo -e "${BLUE}⬆️  git push...${NC}"
            git push 2>&1 | grep -v '^$' \
                && { echo -e "${GREEN}✅ Push réussi.${NC}"; _pushed=true; } \
                || echo -e "${YELLOW}⚠️  Push échoué — vérifiez la connexion ou les droits.${NC}"
        fi

        # ── Proposition Pull Request (IA) ─────────────────────────────────────
        _main_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}' || echo "master")
        if [[ "$_pushed" == "true" && "$_cur_branch" != "$_main_branch" && "$_cur_branch" != "main" && "$_cur_branch" != "master" ]] \
           && command -v gh &>/dev/null; then
            echo ""
            if [[ "$PR_MODE" == "true" ]]; then
                _do_pr=true
            else
                echo -ne "${CYAN}Créer une Pull Request pour '${_cur_branch}' → '${_main_branch}' ? [o/N] : ${NC}"
                read -r _pr_confirm
                _do_pr=false
                [[ "$_pr_confirm" =~ ^[oOyY]$ ]] && _do_pr=true
            fi

            if [[ "$_do_pr" == "true" ]]; then
                echo -e "${BLUE}🤖 Génération du titre et corps de PR par l'IA...${NC}"
                _pr_prompt=$(cat <<PRPROMPT
Tu rédiges une Pull Request GitHub pour la branche '$_cur_branch' à merger dans '$_main_branch'.
RÉPONDS UNIQUEMENT EN FRANÇAIS. AUCUNE INTRODUCTION.
FORMAT STRICT (commence directement par TITRE:) :

TITRE: <titre court et précis, max 72 caractères>

## Résumé
<2-3 lignes expliquant le but de cette PR>

## Changements principaux
- …

## Tests effectués
- …

CONTEXTE :
Branche source : $_cur_branch
Branche cible  : $_main_branch
Dernier message de commit : $COMMIT_MSG

Résumé IA des modifications :
$SUMMARY
PRPROMPT
)
                _pr_prompt_file=$(mktemp /tmp/pr_prompt_XXXXXX.txt)
                echo "$_pr_prompt" > "$_pr_prompt_file"
                _pr_raw=""
                if [[ -f "$QUESTION_PY" ]]; then
                    _pr_raw=$(python3 "$QUESTION_PY" --model "$AI_MODEL" --ctx 8192 --prompt-file "$_pr_prompt_file" --temperature 0.2 2>/dev/null) || true
                fi
                rm -f "$_pr_prompt_file"

                if [[ -n "$_pr_raw" ]]; then
                    _pr_title=$(echo "$_pr_raw" | grep -m1 '^TITRE:' | sed 's/^TITRE:[[:space:]]*//')
                    _pr_body=$(echo "$_pr_raw" | sed '1,/^TITRE:/d')
                    [[ -z "$_pr_title" ]] && _pr_title="$COMMIT_MSG"
                else
                    _pr_title="$COMMIT_MSG"
                    _pr_body="$SUMMARY"
                fi

                echo ""
                echo -e "${YELLOW}Titre PR :${NC} ${GREEN}$_pr_title${NC}"
                echo ""
                echo -ne "${CYAN}Modifier le titre ? (Entrée pour conserver) : ${NC}"
                read -r _pr_title_edit
                [[ -n "$_pr_title_edit" ]] && _pr_title="$_pr_title_edit"

                gh pr create \
                    --title "$_pr_title" \
                    --body "$_pr_body" \
                    --base "$_main_branch" \
                    --head "$_cur_branch" \
                    && echo -e "${GREEN}✅ Pull Request créée !${NC}" \
                    || echo -e "${RED}❌ Erreur gh pr create — vérifiez votre auth (gh auth login).${NC}"
            fi
        fi

        # ── Lot suivant : fichiers restants ───────────────────────────────────
        _rem=$(( $(git diff --name-only 2>/dev/null | wc -l) + $(git ls-files --others --exclude-standard 2>/dev/null | wc -l) ))
        if [[ $_rem -gt 0 ]]; then
            echo ""
            echo -e "${BLUE}📂 $_rem fichier(s) encore non commités.${NC}"
            echo -ne "${CYAN}Traiter le prochain lot ? [o/N] : ${NC}"
            read -r _next_batch
            if [[ "$_next_batch" =~ ^[oOyY]$ ]]; then
                exec "$0" --staged${_cur_branch:+ --branch "$_cur_branch"}${PR_MODE:+ --pr}${AI_ENHANCED:+ --ai}
            fi
        else
            echo -e "${GREEN}✅ Tous les fichiers commités !${NC}"
        fi
    else
        echo -e "${BLUE}→ Commit annulé (vous pouvez le faire manuellement).${NC}"
    fi
fi
