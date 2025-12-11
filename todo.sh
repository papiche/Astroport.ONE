#!/usr/bin/env bash
# Script pour générer automatiquement TODO.today.md ou TODO.week.md basé sur les modifications Git
# Utilise question.py pour analyser les changements et générer un résumé

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
# Disable set -e temporarily for sourcing my.sh (it has some commands that may return non-zero)
set +e
source $HOME/.zen/Astroport.ONE/tools/my.sh
set -e

# Default values
PERIOD="24h"
PERIOD_LABEL="Dernières 24h"
PERIOD_GIT="24 hours ago"
PERIOD_REF="24.hours.ago"

TODO_OUTPUT="$REPO_ROOT/TODO.today.md"
TODO_MAIN="$REPO_ROOT/TODO.md"
QUESTION_PY="$REPO_ROOT/IA/question.py"
GIT_LOG_FILE="$REPO_ROOT/.git_changes.txt"

# Function to display help
show_help() {
    cat <<EOF
${GREEN}todo.sh${NC} - Generate automatic TODO reports based on Git changes

${YELLOW}USAGE:${NC}
    $0 [OPTIONS]

${YELLOW}OPTIONS:${NC}
    ${GREEN}--help, -h${NC}      Display this help message
    ${GREEN}--week, -w${NC}      Analyze Git changes from the last 7 days (default: 24h)

${YELLOW}DESCRIPTION:${NC}
    This script analyzes recent Git changes and generates a structured TODO report.
    It uses question.py with an AI model to summarize modifications and suggest priorities.

${YELLOW}OUTPUT:${NC}
    Default (24h):  TODO.today.md
    Weekly (--week): TODO.week.md

${YELLOW}EXAMPLES:${NC}
    $0              # Analyze last 24 hours, generate TODO.today.md
    $0 --week       # Analyze last 7 days, generate TODO.week.md
    $0 -w           # Same as --week

${YELLOW}REQUIREMENTS:${NC}
    - Git repository
    - Python 3 with question.py
    - Ollama (optional, falls back to basic summary)

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                ;;
            --week|-w)
                PERIOD="week"
                PERIOD_LABEL="Derniers 7 jours"
                PERIOD_GIT="7 days ago"
                PERIOD_REF="7.days.ago"
                TODO_OUTPUT="$REPO_ROOT/TODO.week.md"
                shift
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo -e "Use ${GREEN}--help${NC} for usage information"
                exit 1
                ;;
        esac
    done
}


# Vérifier que nous sommes dans un dépôt Git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Erreur: Ce répertoire n'est pas un dépôt Git${NC}"
    exit 1
fi

# Fonction pour obtenir les modifications selon la période configurée
get_git_changes() {
    local since_date=$(date -d "$PERIOD_GIT" -Iseconds 2>/dev/null || date -v-${PERIOD_GIT// /} -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -u -d "$PERIOD_GIT" +"%Y-%m-%dT%H:%M:%S")
    
    echo -e "${BLUE}📊 Récupération des modifications Git ($PERIOD_LABEL)...${NC}"
    
    # Récupérer les commits de la période
    git log --since="$since_date" \
        --pretty=format:"%H|%an|%ae|%ad|%s" \
        --date=iso \
        --name-status \
        > "$GIT_LOG_FILE" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Aucune modification trouvée ($PERIOD_LABEL)${NC}"
        return 1
    }
    
    # Compter les modifications
    local commit_count=$(git log --since="$since_date" --oneline | wc -l)
    local file_count=$(git diff --name-only HEAD@{$PERIOD_REF} HEAD 2>/dev/null | wc -l)
    
    echo -e "${GREEN}✅ ${commit_count} commit(s) trouvé(s), ${file_count} fichier(s) modifié(s)${NC}"
    return 0
}

# Fonction pour analyser les modifications par système
analyze_changes_by_system() {
    local changes_summary=""
    
    # Systèmes à suivre
    declare -A systems=(
        ["ECONOMY"]="RUNTIME/ZEN.ECONOMY.readme.md|LEGAL.md|RUNTIME/ZEN.*.sh"
        ["DID"]="DID_IMPLEMENTATION.md|tools/make_NOSTRCARD.sh|tools/did_manager.*.sh"
        ["ORE"]="docs/ORE_SYSTEM.md|IA/ore_system.py|RUNTIME/NOSTR.UMAP.refresh.sh"
        ["ORACLE"]="docs/ORACLE_SYSTEM.md|RUNTIME/ORACLE.refresh.sh|tools/oracle.*.sh|UPassport/templates/wotx2.html|UPassport/templates/oracle.html"
        ["NostrTube"]="docs/README.NostrTube.md|IA/youtube.com.sh|IA/create_video_channel.py|UPassport/templates/youtube.html"
        ["Cookie"]="docs/COOKIE_SYSTEM.md|IA/cookie_workflow_engine.sh|UPassport/templates/cookie.html"
        ["N8N"]="docs/N8N.md|docs/N8N.todo.md|UPassport/templates/n8n.html|nostr-nips/101-cookie-workflow-extension.md"
        ["PlantNet"]="docs/PLANTNET_ORE.md|IA/plantnet_recognition.py|IA/plantnet_ore_integration.py|UPlanet/earth/plantnet.html"
        ["CoinFlip"]="docs/COINFLIP.md|UPlanet/earth/coinflip/index.html|UPlanet/earth/coinflip/README.md|UPassport/zen_send.sh"
        ["uMARKET"]="docs/uMARKET.md|docs/uMARKET.todo.md|tools/_uMARKET.*.sh|RUNTIME/NOSTR.UMAP.refresh.sh"
    )
    
    echo -e "${BLUE}🔍 Analyse des modifications par système...${NC}"
    
    for system in "${!systems[@]}"; do
        local patterns="${systems[$system]}"
        local system_changes=$(git diff --name-only HEAD@{$PERIOD_REF} HEAD 2>/dev/null | grep -E "$patterns" || true)
        
        if [ -n "$system_changes" ]; then
            local file_list=$(echo "$system_changes" | sed 's/^/  - /' | head -10)
            local file_count=$(echo "$system_changes" | wc -l)
            changes_summary+="\n### $system ($file_count fichier(s))\n$file_list\n"
        fi
    done
    
    echo "$changes_summary"
}

# Fonction pour générer le prompt pour question.py (une seule question pour continuité)
generate_ai_prompt() {
    local git_summary=$(cat "$GIT_LOG_FILE" 2>/dev/null | head -100)
    local changes_by_system=$(analyze_changes_by_system)
    
    # Lire TODO.md principal pour assurer la continuité
    local todo_main_content=""
    if [[ -f "$TODO_MAIN" ]]; then
        todo_main_content=$(cat "$TODO_MAIN")
    else
        todo_main_content="TODO.md n'existe pas encore."
    fi
    
    cat <<EOF
Compare le fichier TODO.md principal avec les modifications Git ($PERIOD_LABEL) et génère un résumé concis en français qui :

1. Identifie ce qui a été fait (tâches complétées, systèmes modifiés)
2. Identifie ce qu'il reste à faire (tâches en cours, prochaines étapes)
3. Met en évidence les avancées importantes
4. Suggère les priorités pour la suite

Format de réponse : Markdown structuré, concis (maximum 500 mots), avec des sections claires.

TODO.md principal :
$todo_main_content

---

Modifications Git ($PERIOD_LABEL) :
$git_summary

Modifications par système :
$changes_by_system
EOF
}

# Fonction principale
main() {
    # Parse command line arguments
    parse_args "$@"
    
    local output_name=$(basename "$TODO_OUTPUT")
    echo -e "${GREEN}🚀 Génération de $output_name ($PERIOD_LABEL)${NC}\n"
    
    # Récupérer les modifications Git
    if ! get_git_changes; then
        echo -e "${YELLOW}⚠️  Aucune modification à analyser${NC}"
        exit 0
    fi
    
    # Vérifier que question.py existe
    if [ ! -f "$QUESTION_PY" ]; then
        echo -e "${RED}❌ Erreur: question.py introuvable à $QUESTION_PY${NC}"
        exit 1
    fi
    
    # Vérifier et démarrer Ollama si nécessaire
    local OLLAMA_SCRIPT="$HOME/.zen/Astroport.ONE/IA/ollama.me.sh"
    if [ -f "$OLLAMA_SCRIPT" ]; then
        echo -e "${BLUE}🔧 Vérification/démarrage d'Ollama...${NC}"
        bash "$OLLAMA_SCRIPT" >/dev/null 2>&1 || {
            echo -e "${YELLOW}⚠️  Ollama non disponible, génération d'un résumé basique${NC}"
            generate_basic_summary
            return
        }
        # Attendre un peu que Ollama soit prêt
        sleep 2
    else
        echo -e "${YELLOW}⚠️  Script ollama.me.sh introuvable, tentative d'appel direct à question.py${NC}"
    fi
    
    # Générer le prompt
    local prompt=$(generate_ai_prompt)
    local prompt_file="$REPO_ROOT/.todo_prompt_$$.txt"
    
    # Écrire le prompt dans un fichier temporaire pour éviter les problèmes avec les sauts de ligne
    echo "$prompt" > "$prompt_file"
    
    echo -e "${BLUE}🤖 Analyse des modifications avec question.py...${NC}"
    
    # Appeler question.py avec le prompt depuis le fichier
    local ai_summary=$(python3 "$QUESTION_PY" --model "gemma3:latest" "$(cat "$prompt_file")" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Erreur lors de l'appel à question.py, génération d'un résumé basique${NC}"
        rm -f "$prompt_file"
        generate_basic_summary
        return
    })
    
    # Nettoyer le fichier temporaire
    rm -f "$prompt_file"
    
    # Générer le fichier TODO avec le résumé concis (une seule question)
    local report_title="TODO Quotidien"
    [[ "$PERIOD" == "week" ]] && report_title="TODO Hebdomadaire"
    
    cat > "$TODO_OUTPUT" <<EOF
# $report_title - $(date +"%Y-%m-%d")

**Généré automatiquement** : $(date +"%Y-%m-%d %H:%M:%S")  
**Période analysée** : $PERIOD_LABEL

---

## 📊 Résumé Généré par IA

$ai_summary

---

## 📝 Modifications Détectées

$(analyze_changes_by_system)

---

## 🔗 Liens Utiles

- [TODO Principal](TODO.md)
- [Documentation](DOCUMENTATION.md)
- [TODO System](docs/TODO_SYSTEM.md)

---

**Note** : Ce fichier est généré automatiquement par \`todo.sh\`. Le résumé IA compare déjà TODO.md avec les modifications Git pour assurer la continuité. Vérifiez et intégrez les informations pertinentes dans TODO.md manuellement.
EOF
    
    echo -e "${GREEN}✅ $output_name généré avec succès${NC}"
    echo -e "${BLUE}📄 Fichier: $TODO_OUTPUT${NC}\n"
    
    # Afficher un aperçu
    echo -e "${YELLOW}📋 Aperçu (premières 30 lignes):${NC}"
    head -30 "$TODO_OUTPUT"
    echo -e "\n${GREEN}💡 Utilisez votre éditeur pour ouvrir $output_name et intégrer les informations dans TODO.md${NC}"
    
    # Publier le rapport sur le mur du CAPTAIN
    publish_todo_report
    
    # Nettoyer le fichier temporaire
    rm -f "$GIT_LOG_FILE"
}

# Fonction pour publier le rapport quotidien sur le mur du CAPTAIN
publish_todo_report() {
    # Vérifier que CAPTAINEMAIL est défini
    if [[ -z "$CAPTAINEMAIL" ]]; then
        echo -e "${YELLOW}⚠️  CAPTAINEMAIL non défini, publication du rapport annulée${NC}"
        return 1
    fi
    
    # Vérifier que le fichier TODO existe
    if [[ ! -f "$TODO_OUTPUT" ]]; then
        echo -e "${YELLOW}⚠️  Fichier $(basename "$TODO_OUTPUT") introuvable, publication annulée${NC}"
        return 1
    fi
    
    # Vérifier que la clé du CAPTAIN existe
    local CAPTAIN_KEYFILE="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    if [[ ! -f "$CAPTAIN_KEYFILE" ]]; then
        echo -e "${YELLOW}⚠️  Clé du CAPTAIN introuvable à $CAPTAIN_KEYFILE, publication annulée${NC}"
        return 1
    fi
    
    local report_type="quotidien"
    [[ "$PERIOD" == "week" ]] && report_type="hebdomadaire"
    echo -e "${BLUE}📤 Publication du rapport $report_type sur le mur du CAPTAIN...${NC}"
    
    # Lire le contenu du rapport (déjà généré avec résumé concis)
    local report_content=$(cat "$TODO_OUTPUT")
    
    # Extraire le titre (première ligne après le #)
    local title=$(echo "$report_content" | head -1 | sed 's/^# //' | sed 's/^## //')
    if [[ -z "$title" ]]; then
        if [[ "$PERIOD" == "week" ]]; then
            title="TODO Hebdomadaire - $(date +"%Y-%m-%d")"
        else
            title="TODO Quotidien - $(date +"%Y-%m-%d")"
        fi
    fi
    
    # Extraire le résumé pour les métadonnées (première section après "Résumé Généré par IA")
    local summary=$(echo "$report_content" | sed -n '/## 📊 Résumé Généré par IA/,/^---/p' | head -20 | tail -n +2 | sed '/^---/d' | head -10)
    [[ -z "$summary" ]] && summary=$(echo "$report_content" | sed -n '/## 📊 Résumé/,/^---/p' | head -10 | tail -n +2 | sed '/^---/d')
    [[ -z "$summary" ]] && summary="Rapport quotidien des modifications Git des dernières 24h"
    
    # Nettoyer le résumé (limiter à 200 caractères)
    summary=$(echo "$summary" | tr '\n' ' ' | sed 's/  */ /g' | head -c 200)
    
    # Utiliser le contenu complet du rapport (déjà concis grâce à la question unique)
    local article_content="$report_content"
    
    # Calculer la date d'expiration (5 jours pour quotidien, 14 jours pour hebdomadaire)
    local expiration_days=5
    [[ "$PERIOD" == "week" ]] && expiration_days=14
    local expiration_seconds=$((expiration_days * 86400))
    local expiration_timestamp=$(date -d "+${expiration_days} days" +%s 2>/dev/null || date -v+${expiration_days}d +%s 2>/dev/null || echo $(($(date +%s) + expiration_seconds)))
    
    # Créer les tags pour l'article de blog (kind 30023)
    # Format: [["d", "unique-id"], ["title", "..."], ["summary", "..."], ["published_at", "timestamp"], ["expiration", "timestamp"], ["t", "todo"], ...]
    local period_tag="daily"
    [[ "$PERIOD" == "week" ]] && period_tag="weekly"
    local d_tag="todo_${period_tag}_$(date +%Y%m%d)_$(echo -n "$title" | md5sum | cut -d' ' -f1 | head -c 8)"
    local published_at=$(date +%s)
    
    # Créer un fichier JSON temporaire pour les tags
    local temp_tags_file="$REPO_ROOT/.todo_tags_$$.json"
    cat > "$temp_tags_file" <<EOF
[
  ["d", "$d_tag"],
  ["title", "$title"],
  ["summary", "$summary"],
  ["published_at", "$published_at"],
  ["expiration", "$expiration_timestamp"],
  ["t", "todo"],
  ["t", "rapport"],
  ["t", "$period_tag"],
  ["t", "git"],
  ["t", "UPlanet"]
]
EOF
    
    # Lire les tags depuis le fichier JSON
    local tags_json=$(cat "$temp_tags_file")
    
    # Vérifier que nostr_send_note.py existe
    local NOSTR_SEND_SCRIPT="$REPO_ROOT/tools/nostr_send_note.py"
    if [[ ! -f "$NOSTR_SEND_SCRIPT" ]]; then
        echo -e "${YELLOW}⚠️  nostr_send_note.py introuvable, publication annulée${NC}"
        rm -f "$temp_tags_file"
        return 1
    fi
    
    # Publier l'article avec kind 30023 (Long-form Content)
    echo -e "${BLUE}📝 Titre: $title${NC}"
    echo -e "${BLUE}📄 Résumé: $summary${NC}"
    echo -e "${BLUE}⏰ Expiration: $(date -d "@$expiration_timestamp" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$expiration_timestamp" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)${NC}"
    
    local publish_result=$(python3 "$NOSTR_SEND_SCRIPT" \
        --keyfile "$CAPTAIN_KEYFILE" \
        --content "$article_content" \
        --tags "$tags_json" \
        --kind 30023 \
        --ephemeral "$expiration_seconds" \
        --relays "$myRELAY" \
        --json 2>&1)
    
    local publish_exit_code=$?
    
    if [[ $publish_exit_code -eq 0 ]]; then
        # Parser la réponse JSON
        local event_id=$(echo "$publish_result" | jq -r '.event_id // empty' 2>/dev/null)
        local relays_success=$(echo "$publish_result" | jq -r '.relays_success // 0' 2>/dev/null)
        
        if [[ -n "$event_id" && "$relays_success" -gt 0 ]]; then
            echo -e "${GREEN}✅ Rapport publié avec succès sur le mur du CAPTAIN${NC}"
            echo -e "${GREEN}   Event ID: ${event_id:0:16}...${NC}"
            echo -e "${GREEN}   Relays: $relays_success${NC}"
            echo -e "${GREEN}   Expiration: $expiration_days jours${NC}"
            
            # Afficher l'événement créé avec nostr_get_events.sh
            echo -e "\n${BLUE}📋 Affichage de l'événement créé...${NC}"
            local NOSTR_GET_EVENTS="$REPO_ROOT/tools/nostr_get_events.sh"
            if [[ -f "$NOSTR_GET_EVENTS" ]]; then
                echo -e "${BLUE}   Récupération de l'événement kind 30023 avec tag d='$d_tag'...${NC}"
                "$NOSTR_GET_EVENTS" --kind 30023 --tag-d "$d_tag" 2>/dev/null | jq '.' 2>/dev/null || {
                    echo -e "${YELLOW}   ⚠️  Impossible d'afficher l'événement (jq peut-être manquant)${NC}"
                }
            else
                echo -e "${YELLOW}   ⚠️  nostr_get_events.sh introuvable${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Publication avec avertissements${NC}"
            echo -e "${YELLOW}   Réponse: $publish_result${NC}"
        fi
    else
        echo -e "${RED}❌ Échec de la publication${NC}"
        echo -e "${RED}   Code de sortie: $publish_exit_code${NC}"
        echo -e "${RED}   Erreur: $publish_result${NC}"
    fi
    
    # Nettoyer le fichier temporaire
    rm -f "$temp_tags_file"
}

# Fonction de fallback si question.py échoue
generate_basic_summary() {
    local changes_by_system=$(analyze_changes_by_system)
    local commit_count=$(git log --since="$PERIOD_GIT" --oneline | wc -l)
    
    local report_title="TODO Quotidien"
    [[ "$PERIOD" == "week" ]] && report_title="TODO Hebdomadaire"
    
    cat > "$TODO_OUTPUT" <<EOF
# $report_title - $(date +"%Y-%m-%d")

**Généré automatiquement** : $(date +"%Y-%m-%d %H:%M:%S")  
**Période analysée** : $PERIOD_LABEL  
**Commits détectés** : $commit_count

---

## 📊 Résumé Basique

Modifications détectées dans les systèmes suivants :

$changes_by_system

---

## 📝 Détails des Modifications

$(git log --since="$PERIOD_GIT" --pretty=format:"- **%ad** : %s (%an)" --date=short | head -20)

---

## 🔗 Liens Utiles

- [TODO Principal](TODO.md)
- [Documentation](DOCUMENTATION.md)

---

**Note** : Ce fichier est généré automatiquement par \`todo.sh\`. Analysez les modifications et intégrez les informations pertinentes dans TODO.md manuellement.
EOF
    
    # Publier le rapport sur le mur du CAPTAIN même en mode fallback
    publish_todo_report
}

# Exécuter le script
main "$@"
