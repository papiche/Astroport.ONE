#!/usr/bin/env bash
# Script pour générer automatiquement TODO.today.md basé sur les modifications Git des dernières 24h
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
TODO_TODAY="$REPO_ROOT/TODO.today.md"
TODO_MAIN="$REPO_ROOT/TODO.md"
QUESTION_PY="$REPO_ROOT/IA/question.py"
GIT_LOG_FILE="$REPO_ROOT/.git_changes_24h.txt"

# Vérifier que nous sommes dans un dépôt Git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Erreur: Ce répertoire n'est pas un dépôt Git${NC}"
    exit 1
fi

# Fonction pour obtenir les modifications des dernières 24h
get_git_changes_24h() {
    local since_date=$(date -d '24 hours ago' -Iseconds 2>/dev/null || date -v-24H -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%S")
    
    echo -e "${BLUE}📊 Récupération des modifications Git des dernières 24h...${NC}"
    
    # Récupérer les commits des dernières 24h
    git log --since="$since_date" \
        --pretty=format:"%H|%an|%ae|%ad|%s" \
        --date=iso \
        --name-status \
        > "$GIT_LOG_FILE" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Aucune modification trouvée dans les dernières 24h${NC}"
        return 1
    }
    
    # Compter les modifications
    local commit_count=$(git log --since="$since_date" --oneline | wc -l)
    local file_count=$(git diff --name-only HEAD@{24.hours.ago} HEAD 2>/dev/null | wc -l)
    
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
        ["ORACLE"]="docs/ORACLE.doc.md|RUNTIME/ORACLE.refresh.sh|tools/oracle.*.sh|UPassport/templates/wotx2.html|UPassport/templates/oracle.html"
        ["NostrTube"]="docs/README.NostrTube.md|IA/youtube.com.sh|IA/create_video_channel.py|UPassport/templates/youtube.html"
        ["Cookie"]="IA/COOKIE_SYSTEM.md|IA/cookie_workflow_engine.sh|UPassport/templates/cookie.html"
        ["N8N"]="docs/N8N.md|docs/N8N.todo.md|UPassport/templates/n8n.html|nostr-nips/101-cookie-workflow-extension.md"
        ["PlantNet"]="docs/PLANTNET_ORE.md|IA/plantnet_recognition.py|IA/plantnet_ore_integration.py|UPlanet/earth/plantnet.html"
    )
    
    echo -e "${BLUE}🔍 Analyse des modifications par système...${NC}"
    
    for system in "${!systems[@]}"; do
        local patterns="${systems[$system]}"
        local system_changes=$(git diff --name-only HEAD@{24.hours.ago} HEAD 2>/dev/null | grep -E "$patterns" || true)
        
        if [ -n "$system_changes" ]; then
            local file_list=$(echo "$system_changes" | sed 's/^/  - /' | head -10)
            local file_count=$(echo "$system_changes" | wc -l)
            changes_summary+="\n### $system ($file_count fichier(s))\n$file_list\n"
        fi
    done
    
    echo "$changes_summary"
}

# Fonction pour générer le prompt pour question.py
generate_ai_prompt() {
    local git_summary=$(cat "$GIT_LOG_FILE" 2>/dev/null | head -100)
    local changes_by_system=$(analyze_changes_by_system)
    
    cat <<EOF
Analyse les modifications Git suivantes des dernières 24h et génère un résumé structuré pour TODO.today.md.

Modifications Git :
$git_summary

Modifications par système :
$changes_by_system

Génère un résumé en format Markdown avec :
1. Date du jour
2. Systèmes modifiés avec détails
3. Fichiers créés/modifiés/supprimés
4. Résumé des changements par système
5. Prochaines étapes suggérées

Format de sortie : Markdown structuré, en français, avec emojis pour la lisibilité.
EOF
}

# Fonction principale
main() {
    echo -e "${GREEN}🚀 Génération de TODO.today.md${NC}\n"
    
    # Récupérer les modifications Git
    if ! get_git_changes_24h; then
        echo -e "${YELLOW}⚠️  Aucune modification à analyser${NC}"
        exit 0
    fi
    
    # Vérifier que question.py existe
    if [ ! -f "$QUESTION_PY" ]; then
        echo -e "${RED}❌ Erreur: question.py introuvable à $QUESTION_PY${NC}"
        exit 1
    fi
    
    # Générer le prompt
    local prompt=$(generate_ai_prompt)
    
    echo -e "${BLUE}🤖 Analyse des modifications avec question.py...${NC}"
    
    # Appeler question.py avec le prompt
    local ai_summary=$(echo "$prompt" | python3 "$QUESTION_PY" --model "gemma3:latest" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Erreur lors de l'appel à question.py, génération d'un résumé basique${NC}"
        generate_basic_summary
        return
    })
    
    # Générer TODO.today.md
    cat > "$TODO_TODAY" <<EOF
# TODO Quotidien - $(date +"%Y-%m-%d")

**Généré automatiquement** : $(date +"%Y-%m-%d %H:%M:%S")  
**Période analysée** : Dernières 24h

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

---

**Note** : Ce fichier est généré automatiquement par \`todo.sh\`. Vérifiez et intégrez les informations pertinentes dans TODO.md manuellement.
EOF
    
    echo -e "${GREEN}✅ TODO.today.md généré avec succès${NC}"
    echo -e "${BLUE}📄 Fichier: $TODO_TODAY${NC}\n"
    
    # Afficher un aperçu
    echo -e "${YELLOW}📋 Aperçu (premières 30 lignes):${NC}"
    head -30 "$TODO_TODAY"
    echo -e "\n${GREEN}💡 Utilisez votre éditeur pour ouvrir $TODO_TODAY et intégrer les informations dans TODO.md${NC}"
    
    # Nettoyer le fichier temporaire
    rm -f "$GIT_LOG_FILE"
}

# Fonction de fallback si question.py échoue
generate_basic_summary() {
    local changes_by_system=$(analyze_changes_by_system)
    local commit_count=$(git log --since="24 hours ago" --oneline | wc -l)
    
    cat > "$TODO_TODAY" <<EOF
# TODO Quotidien - $(date +"%Y-%m-%d")

**Généré automatiquement** : $(date +"%Y-%m-%d %H:%M:%S")  
**Période analysée** : Dernières 24h  
**Commits détectés** : $commit_count

---

## 📊 Résumé Basique

Modifications détectées dans les systèmes suivants :

$changes_by_system

---

## 📝 Détails des Modifications

$(git log --since="24 hours ago" --pretty=format:"- **%ad** : %s (%an)" --date=short | head -20)

---

## 🔗 Liens Utiles

- [TODO Principal](TODO.md)
- [Documentation](DOCUMENTATION.md)

---

**Note** : Ce fichier est généré automatiquement par \`todo.sh\`. Analysez les modifications et intégrez les informations pertinentes dans TODO.md manuellement.
EOF
}

# Exécuter le script
main "$@"

