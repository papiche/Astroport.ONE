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

# Default values - "last" mode (since last execution)
PERIOD="last"
PERIOD_LABEL="Depuis dernière exécution"
PERIOD_GIT=""  # Will be set from marker file
PERIOD_REF=""  # Will be set from marker file
LAST_RUN_MARKER="$HOME/.zen/game/todo_last_run.marker"

TODO_OUTPUT="$REPO_ROOT/TODO.last.md"
TODO_MAIN="$REPO_ROOT/TODO.md"
QUESTION_PY="$REPO_ROOT/IA/question.py"
GIT_LOG_FILE="$REPO_ROOT/.git_changes.txt"

# N² Memory System - Shared across all stations via NOSTR
# Uses uplanet.G1.nostr key for constellation-wide learning
N2_MEMORY_KIND=31910  # Dedicated kind for N² development memory
N2_MEMORY_KEYFILE="$HOME/.zen/game/uplanet.G1.nostr"
N2_MEMORY_RELAY="${myRELAY:-wss://relay.copylaradio.com}"
NOSTR_SEND_SCRIPT="$REPO_ROOT/tools/nostr_send_note.py"
NOSTR_GET_SCRIPT="$REPO_ROOT/tools/nostr_get_events.sh"

# N² Architecture context for AI recommendations (comprehensive)
N2_CONTEXT='## Architecture N² Constellation Protocol

### Principe Fondamental: Conway Angel Game
- Un "ange de force 2" peut toujours échapper au démon (prouvé mathématiquement)
- Force 2 = graphe social N1 (amis) + N2 (amis d amis)
- Résultat: coordination décentralisée sans autorité centrale

### Architecture Hybride NOSTR/IPFS
| Couche | Technologie | Portée | Synchronisation |
|--------|-------------|--------|-----------------|
| Coordination | NOSTR | Globale (N²) | 40 event kinds entre tous les essaims |
| Stockage | IPFS | Locale (Essaim) | Isolé par constellation |

### Topologie: Hub + 24 Satellites
- Hub Central: coordonne, agrège économie, sync globale
- Satellites: services locaux (MULTIPASS, ZEN Cards), gestion UMAP (0.01° = 1.2km²)
- Chaque satellite publie amisOfAmis.txt via IPFS pour le graphe N²

### Économie Ẑen
- 1Ẑ = 1€ (parité maintenue via PAF burn + Open Collective)
- Flux: CASH → NODE (loyer) + CAPTAIN (travail)
- Burn 4 semaines: conversion Ẑen → € sur Open Collective

### Systèmes Clés et Priorités
1. **RUNTIME/** - Scripts "smart contract" exécutés par le scheduler N² (20h12.process.sh)
2. **NOSTR (NIP-101)** - Extensions: DID (30800), ORE (30312-30313), Permits (30500-30503), Economy (30850-30851)
3. **DID/ORE** - Identité décentralisée + Object Resource Events (attestations environnementales)
4. **UPlanet** - Grille géographique, chaque UMAP = communauté locale
5. **Economy** - ZEN.ECONOMY.sh, ZEN.COOPERATIVE.3x1-3.sh, flux coopératifs

### Patterns de Développement Recommandés
- Toujours synchroniser les événements NOSTR entre essaims (backfill_constellation.sh)
- Garder les données volumineuses en IPFS local (pas de sync globale)
- Utiliser les tags géographiques ["g", "lat,lon"] pour le routage intelligent
- Implémenter les nouveaux kinds selon NIP-101 extensions
- Respecter la parité 1Ẑ=1€ dans tous les calculs économiques

### Anti-Patterns à Éviter
- ❌ Centraliser les données (casser la force 2)
- ❌ Synchroniser IPFS globalement (saturation réseau)
- ❌ Ignorer le graphe social N² (perte de relativisme)
- ❌ Créer des kinds NOSTR non documentés

### Roadmap Intégrations (Développement Décentralisé)
1. **Radicle** (https://radicle.xyz/) - Forge P2P pour le code
   - Remplacer GitHub/GitLab par COBs (Collaborative Objects)
   - Identités crypto compatibles Ed25519
   - Issues/Patches décentralisés

2. **NextGraph** (https://nextgraph.org/) - Documents CRDT + RDF
   - Collaboration temps réel sur documents UPlanet
   - Requêtes SPARQL sur données géographiques
   - Fusion sans conflit (CRDTs)

Ces intégrations permettront la prise de décision collective distribuée.
'

# Function to display help
show_help() {
    echo -e "${GREEN}todo.sh${NC} - Generate automatic TODO reports based on Git changes"
    echo -e "${BLUE}N² Constellation Protocol - Conway's Angel Game (force 2 escapes demon)${NC}"
    echo ""
    echo -e "${YELLOW}USAGE:${NC}"
    echo "    $0 [OPTIONS]"
    echo ""
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo -e "    ${GREEN}--help, -h${NC}      Display this help message"
    echo -e "    ${GREEN}--last, -l${NC}      Analyze since last execution (DEFAULT)"
    echo -e "    ${GREEN}--day, -d${NC}       Analyze last 24 hours"
    echo -e "    ${GREEN}--week, -w${NC}      Analyze last 7 days"
    echo ""
    echo -e "${YELLOW}MEMORY COMMANDS (N² Learning):${NC}"
    echo -e "    ${GREEN}--add \"text\"${NC}  Add a captain TODO (human-written idea)"
    echo -e "    ${GREEN}--list${NC}        List pending recommendations (proposed/accepted)"
    echo -e "    ${GREEN}--accept ID${NC}   Mark recommendation as accepted (human validated)"
    echo -e "    ${GREEN}--reject ID${NC}   Mark recommendation as rejected (human override)"
    echo -e "    ${GREEN}--done ID${NC}     Mark recommendation as implemented"
    echo -e "    ${GREEN}--vote ID${NC}     Vote for a recommendation (+1 priority)"
    echo -e "    ${GREEN}--memory${NC}      Show recent memory entries (last 20)"
    echo -e "    ${GREEN}--no-interactive${NC} Skip interactive selection (batch mode)"
    echo ""
    echo -e "${YELLOW}DESCRIPTION:${NC}"
    echo "    This script analyzes Git changes and generates a structured TODO report."
    echo "    It uses question.py with AI to:"
    echo "      1. Summarize what was coded"
    echo "      2. Recommend NEXT STEPS based on N² architecture"
    echo "      3. LEARN from past decisions (memory stored in NOSTR)"
    echo ""
    echo -e "${YELLOW}N² MEMORY SYSTEM:${NC}"
    echo "    Recommendations are stored in NOSTR (kind $N2_MEMORY_KIND) using:"
    echo "      Key: ~/.zen/game/uplanet.G1.nostr"
    echo "    This memory is shared across ALL stations in the constellation."
    echo "    The AI learns from accepted/rejected recommendations to improve advice."
    echo ""
    echo -e "${YELLOW}KEY SETUP (required for N² Memory + Oracle):${NC}"
    echo "    The uplanet.G1.nostr key is the Ğ1 Central Bank key for UPlanet."
    echo "    It's used by both the Oracle system and N² Memory."
    echo ""
    echo "    Create via UPLANET.init.sh (recommended) or manually:"
    echo "      \$HOME/.zen/Astroport.ONE/tools/keygen -t nostr \"\${UPLANETNAME}.G1\" \"\${UPLANETNAME}.G1\" \\"
    echo "          > ~/.zen/game/uplanet.G1.nostr"
    echo ""
    echo "    ⚠️  Use the SAME seed across all stations: \${UPLANETNAME}.G1"
    echo "    This key signs Oracle credentials (30503) and N² Memory events (31910)."
    echo ""
    echo -e "${YELLOW}OUTPUT:${NC}"
    echo "    Default (--last): TODO.last.md"
    echo "    Daily (--day):    TODO.today.md"
    echo "    Weekly (--week):  TODO.week.md"
    echo ""
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "    $0              # Analyze since last run, generate TODO.last.md"
    echo "    $0 --day        # Analyze last 24 hours, generate TODO.today.md"
    echo "    $0 --week       # Analyze last 7 days, generate TODO.week.md"
    echo ""
    echo -e "${YELLOW}REQUIREMENTS:${NC}"
    echo "    - Git repository"
    echo "    - Python 3 with question.py"
    echo "    - Ollama (optional, falls back to basic summary)"
    echo ""
    echo -e "${YELLOW}OPEN COLLECTIVE INTEGRATION:${NC}"
    echo "    Add to ~/.zen/Astroport.ONE/.env:"
    echo "      OPENCOLLECTIVE_PERSONAL_TOKEN=\"your_token\""
    echo "      OPENCOLLECTIVE_SLUG=\"monnaie-libre\"  # optional, default: monnaie-libre"
    echo ""
    echo "    Get your token at:"
    echo "      https://opencollective.com/dashboard/monnaie-libre/admin/for-developers"
    echo ""
    echo -e "${YELLOW}DOCUMENTATION:${NC}"
    echo "    Full documentation: docs/N2_MEMORY_SYSTEM.md"
    echo "    Architecture: nostr-nips/101-n2-constellation-sync-extension.md"
    echo ""
    exit 0
}

# Global flags
INTERACTIVE_MODE=true
SHOW_MEMORY_ONLY=false

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                ;;
            --last|-l)
                # Default mode - since last execution
                PERIOD="last"
                TODO_OUTPUT="$REPO_ROOT/TODO.last.md"
                shift
                ;;
            --day|-d)
                PERIOD="day"
                PERIOD_LABEL="Dernières 24h"
                PERIOD_GIT="24 hours ago"
                PERIOD_REF="24.hours.ago"
                TODO_OUTPUT="$REPO_ROOT/TODO.today.md"
                shift
                ;;
            --week|-w)
                PERIOD="week"
                PERIOD_LABEL="Derniers 7 jours"
                PERIOD_GIT="7 days ago"
                PERIOD_REF="7.days.ago"
                TODO_OUTPUT="$REPO_ROOT/TODO.week.md"
                shift
                ;;
            --no-interactive)
                INTERACTIVE_MODE=false
                shift
                ;;
            --memory)
                SHOW_MEMORY_ONLY=true
                shift
                ;;
            --accept)
                if [[ -n "$2" ]]; then
                    update_recommendation_status "$2" "accepted"
                    exit 0
                else
                    echo -e "${RED}❌ --accept requires a recommendation ID${NC}"
                    exit 1
                fi
                ;;
            --reject)
                if [[ -n "$2" ]]; then
                    update_recommendation_status "$2" "rejected"
                    exit 0
                else
                    echo -e "${RED}❌ --reject requires a recommendation ID${NC}"
                    exit 1
                fi
                ;;
            --done)
                if [[ -n "$2" ]]; then
                    update_recommendation_status "$2" "done"
                    exit 0
                else
                    echo -e "${RED}❌ --done requires a recommendation ID${NC}"
                    exit 1
                fi
                ;;
            --add)
                if [[ -n "$2" ]]; then
                    add_captain_todo "$2"
                    exit 0
                else
                    echo -e "${RED}❌ --add requires a TODO text${NC}"
                    echo -e "Usage: $0 --add \"Description of the TODO\""
                    exit 1
                fi
                ;;
            --list)
                list_pending_recommendations
                exit 0
                ;;
            --vote)
                if [[ -n "$2" ]]; then
                    vote_recommendation "$2"
                    exit 0
                else
                    echo -e "${RED}❌ --vote requires a recommendation ID${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo -e "Use ${GREEN}--help${NC} for usage information"
                exit 1
                ;;
        esac
    done
    
    # Handle --memory command
    if [[ "$SHOW_MEMORY_ONLY" == "true" ]]; then
        echo -e "${BLUE}📚 N² Memory - Recent constellation decisions${NC}\n"
        local memory=$(fetch_n2_memory 20)
        if [[ -n "$memory" && "$memory" != "[]" ]]; then
            echo "$memory" | jq -r '
                .[] |
                "[\(.created_at // "?")] " +
                (.tags | map(select(.[0]=="status")) | .[0][1] // "?") + " - " +
                (.content | fromjson? | .content[:80] // "?") + "..."
            ' 2>/dev/null || echo "$memory" | head -20
        else
            echo -e "${YELLOW}Aucune mémoire N² trouvée.${NC}"
            echo -e "La mémoire sera créée lors de la première sélection de recommandation."
        fi
        exit 0
    fi
}

# Initialize period based on last run marker (for --last mode)
init_last_run_period() {
    if [[ "$PERIOD" != "last" ]]; then
        return 0
    fi
    
    local last_commit=""
    local last_timestamp=""
    
    if [[ -f "$LAST_RUN_MARKER" ]]; then
        last_commit=$(sed -n '1p' "$LAST_RUN_MARKER" 2>/dev/null)
        last_timestamp=$(sed -n '2p' "$LAST_RUN_MARKER" 2>/dev/null)
        
        if [[ -n "$last_timestamp" ]]; then
            PERIOD_LABEL="Depuis $last_timestamp"
            # Use commit hash for precise diff
            if [[ -n "$last_commit" ]] && git rev-parse "$last_commit" >/dev/null 2>&1; then
                PERIOD_GIT="$last_commit"
                PERIOD_REF=""  # Will use commit hash directly
                echo -e "${BLUE}📍 Last run: $last_timestamp (commit: ${last_commit:0:8})${NC}"
            else
                # Fallback to timestamp-based
                PERIOD_GIT="$last_timestamp"
                PERIOD_REF=""
                echo -e "${BLUE}📍 Last run: $last_timestamp${NC}"
            fi
        else
            # First run - default to 24h
            echo -e "${YELLOW}⚠️  First run detected, using last 24 hours${NC}"
            PERIOD_LABEL="Dernières 24h (première exécution)"
            PERIOD_GIT="24 hours ago"
            PERIOD_REF="24.hours.ago"
        fi
    else
        # First run - default to 24h
        echo -e "${YELLOW}⚠️  First run detected, using last 24 hours${NC}"
        PERIOD_LABEL="Dernières 24h (première exécution)"
        PERIOD_GIT="24 hours ago"
        PERIOD_REF="24.hours.ago"
    fi
}

# Save current run marker
save_run_marker() {
    mkdir -p "$(dirname "$LAST_RUN_MARKER")"
    local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local current_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$current_commit" > "$LAST_RUN_MARKER"
    echo "$current_time" >> "$LAST_RUN_MARKER"
    echo -e "${GREEN}📍 Saved run marker: $current_time${NC}"
}

#######################################################################
# N² MEMORY SYSTEM - Shared learning across constellation
# Events stored in NOSTR (kind 31910) using uplanet.G1.nostr key
#######################################################################

# Fetch recent N² memory entries from NOSTR
# Returns JSON array of past recommendations and their outcomes
fetch_n2_memory() {
    local limit="${1:-20}"
    
    if [[ ! -f "$N2_MEMORY_KEYFILE" ]]; then
        echo "[]"
        return 0
    fi
    
    # Get pubkey from keyfile
    local pubkey=$(grep -E "^npub|^pub:" "$N2_MEMORY_KEYFILE" 2>/dev/null | head -1 | awk '{print $NF}')
    if [[ -z "$pubkey" ]]; then
        echo "[]"
        return 0
    fi
    
    # Fetch memory events from NOSTR
    if [[ -f "$NOSTR_GET_SCRIPT" ]]; then
        local memory_events=$("$NOSTR_GET_SCRIPT" \
            --kind "$N2_MEMORY_KIND" \
            --author "$pubkey" \
            --limit "$limit" \
            --relay "$N2_MEMORY_RELAY" 2>/dev/null || echo "[]")
        echo "$memory_events"
    else
        echo "[]"
    fi
}

# Store a recommendation in N² memory (each recommendation = 1 NOSTR event)
# Args: $1=recommendation_id, $2=content, $3=status, $4=type, $5=priority, $6=reference_id (for votes)
store_n2_memory() {
    local rec_id="$1"
    local content="$2"
    local status="${3:-proposed}"
    local rec_type="${4:-ai_recommendation}"  # ai_recommendation | captain_todo | vote | status_update
    local priority="${5:-medium}"  # high | medium | low
    local reference_id="${6:-}"  # Optional: ID of the recommendation this event references (for votes)
    local station_id="${IPFSNODEID:-unknown}"
    local captain="${CAPTAINEMAIL:-unknown}"
    
    if [[ ! -f "$N2_MEMORY_KEYFILE" ]]; then
        echo -e "${YELLOW}⚠️  N² memory key not found: $N2_MEMORY_KEYFILE${NC}"
        return 1
    fi
    
    if [[ ! -f "$NOSTR_SEND_SCRIPT" ]]; then
        echo -e "${YELLOW}⚠️  NOSTR send script not found${NC}"
        return 1
    fi
    
    # Generate unique ID if not provided (12 chars = 281 trillion combinations, collision-resistant)
    [[ -z "$rec_id" ]] && rec_id="$(date +%Y%m%d%H%M%S)_$(echo -n "$content" | md5sum | cut -c1-12)"
    
    # Create memory entry as JSON (include reference_id for votes)
    local ref_field=""
    [[ -n "$reference_id" ]] && ref_field=",\"reference_id\": \"$reference_id\""
    
    local memory_json=$(cat <<EOF
{
    "type": "n2_todo",
    "version": "2.1",
    "id": "$rec_id",
    "content": $(echo "$content" | jq -Rs '.'),
    "status": "$status",
    "rec_type": "$rec_type",
    "priority": "$priority",
    "station": "$station_id",
    "captain": "$captain",
    "votes": 0,
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"$ref_field
}
EOF
)
    
    # Create tags for the event (each tag enables filtering)
    # Add ["e", reference_id] tag for votes to link to original recommendation (NIP-10 compliant)
    local ref_tag=""
    [[ -n "$reference_id" ]] && ref_tag=",
    [\"e\", \"$reference_id\", \"\", \"reply\"]"
    
    local tags_json=$(cat <<EOF
[
    ["d", "$rec_id"],
    ["t", "n2-todo"],
    ["t", "$rec_type"],
    ["status", "$status"],
    ["priority", "$priority"],
    ["station", "$station_id"],
    ["captain", "$captain"],
    ["created", "$(date +%Y%m%d)"]$ref_tag
]
EOF
)
    
    # Publish to NOSTR
    local result=$(python3 "$NOSTR_SEND_SCRIPT" \
        --keyfile "$N2_MEMORY_KEYFILE" \
        --content "$memory_json" \
        --tags "$tags_json" \
        --kind "$N2_MEMORY_KIND" \
        --relays "$N2_MEMORY_RELAY" \
        --json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        local event_id=$(echo "$result" | jq -r '.event_id // empty' 2>/dev/null)
        if [[ -n "$event_id" ]]; then
            echo -e "${GREEN}✅ N² memory stored: $status → ${event_id:0:16}...${NC}"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}⚠️  Failed to store N² memory${NC}"
    return 1
}

# Format memory for AI context (extract learnings from past decisions)
format_memory_for_ai() {
    local memory_json="$1"
    
    if [[ -z "$memory_json" || "$memory_json" == "[]" ]]; then
        echo "Aucune mémoire N² disponible (première utilisation ou clé non configurée)."
        return 0
    fi
    
    # Parse and format memory entries
    local formatted=$(echo "$memory_json" | jq -r '
        .[] | 
        select(.content != null) |
        "- [\(.tags | map(select(.[0]=="status")) | .[0][1] // "unknown")] " +
        (.content | fromjson? | .content // .recommendation_id // "?") + 
        " (station: " + (.tags | map(select(.[0]=="station")) | .[0][1] // "?") + ")"
    ' 2>/dev/null || echo "Erreur de parsing mémoire")
    
    if [[ -n "$formatted" ]]; then
        echo "### Mémoire N² (décisions passées de la constellation)"
        echo ""
        echo "$formatted" | head -15
        echo ""
        echo "_Les recommandations 'accepted' ont été validées par un humain, 'rejected' ont été refusées._"
    else
        echo "Aucune entrée mémoire valide."
    fi
}

# Interactive UX for captain to select recommendations
# Parses AI output and presents numbered choices
interactive_select_recommendations() {
    local ai_output="$1"
    local recommendations_file="$REPO_ROOT/.todo_recommendations_$$.json"
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎯 SÉLECTION DES RECOMMANDATIONS (Capitaine décide)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    
    # Extract recommendations from AI output (look for table rows or bullet points)
    # Format: lines starting with | 🔴 or | 🟡 or | 🟢 or - 🔴 etc.
    local rec_lines=$(echo "$ai_output" | grep -E '^\|?\s*(🔴|🟡|🟢|-\s*(🔴|🟡|🟢))' | head -10)
    
    if [[ -z "$rec_lines" ]]; then
        # Try alternative format: numbered list or bullet points with priority keywords
        rec_lines=$(echo "$ai_output" | grep -iE '(haute|moyenne|basse|high|medium|low|priorit)' | head -10)
    fi
    
    if [[ -z "$rec_lines" ]]; then
        echo -e "${YELLOW}⚠️  Aucune recommandation structurée détectée dans la sortie IA${NC}"
        echo -e "${YELLOW}   Consultez le fichier TODO généré pour les détails.${NC}"
        return 0
    fi
    
    # Create array of recommendations and their IDs
    local -a recommendations=()
    local -a rec_ids=()
    local idx=1
    
    echo -e "${BLUE}📤 Stockage des recommandations IA en événements NOSTR séparés...${NC}"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            recommendations+=("$line")
            
            # Extract priority from emoji
            local priority="medium"
            echo "$line" | grep -q "🔴" && priority="high"
            echo "$line" | grep -q "🟡" && priority="medium"
            echo "$line" | grep -q "🟢" && priority="low"
            
            # Store each recommendation as separate NOSTR event (proposed)
            local rec_id="ai_$(date +%Y%m%d%H%M%S)_${idx}_$(echo -n "$line" | md5sum | cut -c1-12)"
            rec_ids+=("$rec_id")
            
            # Store in NOSTR (silent, just track ID)
            store_n2_memory "$rec_id" "$line" "proposed" "ai_recommendation" "$priority" >/dev/null 2>&1 || true
            
            # Display with ID
            local priority_emoji=$(echo "$line" | grep -oE '🔴|🟡|🟢' | head -1)
            local clean_line=$(echo "$line" | sed 's/^|//; s/|$//; s/^\s*-\s*//' | tr -s ' ')
            echo -e "  ${BLUE}[$idx]${NC} $priority_emoji $clean_line"
            echo -e "      ${YELLOW}ID: ${rec_id}${NC}"
            ((idx++))
        fi
    done <<< "$rec_lines"
    
    local rec_count=${#recommendations[@]}
    
    if [[ $rec_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Aucune recommandation à sélectionner${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}Actions disponibles:${NC}"
    echo -e "  ${GREEN}a <num>${NC}  - Accepter la recommandation (ajouter au TODO)"
    echo -e "  ${RED}r <num>${NC}  - Rejeter la recommandation"
    echo -e "  ${BLUE}v <num>${NC}  - Voter pour cette recommandation"
    echo -e "  ${BLUE}s${NC}        - Tout sauter (skip)"
    echo -e "  ${GREEN}q${NC}        - Quitter la sélection"
    echo ""
    
    # Interactive loop
    while true; do
        echo -ne "${GREEN}Votre choix [a/r/v/s/q + numéro]: ${NC}"
        read -r choice
        
        case "$choice" in
            a\ [0-9]*)
                local num=$(echo "$choice" | grep -oE '[0-9]+')
                if [[ $num -ge 1 && $num -le $rec_count ]]; then
                    local selected="${recommendations[$((num-1))]}"
                    local rec_id="${rec_ids[$((num-1))]}"
                    echo -e "${GREEN}✅ Recommandation #$num acceptée${NC}"
                    store_n2_memory "$rec_id" "$selected" "accepted" "ai_recommendation"
                    # Append to TODO.md
                    echo "" >> "$TODO_MAIN"
                    echo "## [$(date +%Y-%m-%d)] Recommandation acceptée" >> "$TODO_MAIN"
                    echo "" >> "$TODO_MAIN"
                    echo "- [ ] $selected" >> "$TODO_MAIN"
                    echo "  - ID: $rec_id" >> "$TODO_MAIN"
                    echo -e "${GREEN}   → Ajoutée à TODO.md${NC}"
                else
                    echo -e "${RED}Numéro invalide (1-$rec_count)${NC}"
                fi
                ;;
            r\ [0-9]*)
                local num=$(echo "$choice" | grep -oE '[0-9]+')
                if [[ $num -ge 1 && $num -le $rec_count ]]; then
                    local selected="${recommendations[$((num-1))]}"
                    local rec_id="${rec_ids[$((num-1))]}"
                    echo -e "${RED}❌ Recommandation #$num rejetée${NC}"
                    store_n2_memory "$rec_id" "$selected" "rejected" "ai_recommendation"
                    echo -e "${RED}   → Enregistrée comme rejetée (apprentissage N²)${NC}"
                else
                    echo -e "${RED}Numéro invalide (1-$rec_count)${NC}"
                fi
                ;;
            v\ [0-9]*)
                local num=$(echo "$choice" | grep -oE '[0-9]+')
                if [[ $num -ge 1 && $num -le $rec_count ]]; then
                    local rec_id="${rec_ids[$((num-1))]}"
                    echo -e "${BLUE}🗳️  Vote pour recommandation #$num${NC}"
                    vote_recommendation "$rec_id"
                else
                    echo -e "${RED}Numéro invalide (1-$rec_count)${NC}"
                fi
                ;;
            s|S)
                echo -e "${BLUE}⏭️  Sélection passée (recommandations restent 'proposed')${NC}"
                break
                ;;
            q|Q|"")
                echo -e "${GREEN}✓ Fin de la sélection${NC}"
                echo -e "${BLUE}ℹ️  Les recommandations non traitées restent disponibles avec --list${NC}"
                break
                ;;
            *)
                echo -e "${YELLOW}Commande non reconnue. Utilisez: a 1, r 2, v 1, s, ou q${NC}"
                ;;
        esac
    done
    
    rm -f "$recommendations_file"
}

# Update recommendation status (for --accept, --reject, --done commands)
update_recommendation_status() {
    local rec_id="$1"
    local new_status="$2"
    
    echo -e "${BLUE}🔄 Mise à jour du statut: $rec_id → $new_status${NC}"
    store_n2_memory "$rec_id" "Status update: $new_status" "$new_status" "status_update"
}

# Add a captain TODO (human-written idea)
# Usage: ./todo.sh --add "My new idea for the project"
add_captain_todo() {
    local content="$1"
    local priority="${2:-medium}"
    
    if [[ -z "$content" ]]; then
        echo -e "${RED}❌ TODO content cannot be empty${NC}"
        return 1
    fi
    
    # Generate unique ID (12 chars hash for collision resistance)
    local rec_id="captain_$(date +%Y%m%d%H%M%S)_$(echo -n "$content" | md5sum | cut -c1-12)"
    
    echo -e "${BLUE}📝 Adding captain TODO...${NC}"
    echo -e "   Content: $content"
    echo -e "   Priority: $priority"
    
    # Store in NOSTR as individual event
    if store_n2_memory "$rec_id" "$content" "proposed" "captain_todo" "$priority"; then
        echo -e "${GREEN}✅ Captain TODO added successfully${NC}"
        echo -e "${GREEN}   ID: $rec_id${NC}"
        
        # Also add to local TODO.md
        echo "" >> "$TODO_MAIN"
        echo "## [$(date +%Y-%m-%d)] Captain TODO" >> "$TODO_MAIN"
        echo "" >> "$TODO_MAIN"
        echo "- [ ] $content (ID: ${rec_id:0:20}...)" >> "$TODO_MAIN"
        echo -e "${GREEN}   → Added to TODO.md${NC}"
    else
        echo -e "${RED}❌ Failed to store captain TODO${NC}"
        return 1
    fi
}

# List pending recommendations (proposed or accepted, not done)
# Shows all constellation TODOs that can be worked on
list_pending_recommendations() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 N² Constellation - Pending Recommendations${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    
    local memory=$(fetch_n2_memory 50)
    
    if [[ -z "$memory" || "$memory" == "[]" ]]; then
        echo -e "${YELLOW}Aucune recommandation en attente.${NC}"
        echo -e "Utilisez ${GREEN}./todo.sh${NC} pour générer des recommandations IA"
        echo -e "ou ${GREEN}./todo.sh --add \"votre idée\"${NC} pour ajouter un TODO manuel."
        return 0
    fi
    
    # Parse and display by type and status
    echo -e "${YELLOW}🤖 AI Recommendations:${NC}"
    echo "$memory" | jq -r '
        .[] |
        select(.content != null) |
        select((.content | fromjson? | .rec_type // "ai_recommendation") == "ai_recommendation") |
        select((.content | fromjson? | .status // "proposed") | test("proposed|accepted")) |
        "  [\(.content | fromjson? | .priority // "?")] " +
        "[\(.content | fromjson? | .status // "?")] " +
        (.content | fromjson? | .id[:16] // "?") + " - " +
        (.content | fromjson? | .content[:60] // "?") + "..."
    ' 2>/dev/null | head -15 || echo "  (none)"
    
    echo ""
    echo -e "${YELLOW}👨‍✈️ Captain TODOs:${NC}"
    echo "$memory" | jq -r '
        .[] |
        select(.content != null) |
        select((.content | fromjson? | .rec_type // "") == "captain_todo") |
        select((.content | fromjson? | .status // "proposed") | test("proposed|accepted")) |
        "  [\(.content | fromjson? | .priority // "?")] " +
        "[\(.content | fromjson? | .status // "?")] " +
        (.content | fromjson? | .id[:16] // "?") + " - " +
        (.content | fromjson? | .content[:60] // "?") + "..."
    ' 2>/dev/null | head -15 || echo "  (none)"
    
    echo ""
    echo -e "${BLUE}Actions:${NC}"
    echo -e "  ${GREEN}./todo.sh --accept <ID>${NC} - Accept a recommendation"
    echo -e "  ${GREEN}./todo.sh --reject <ID>${NC} - Reject a recommendation"
    echo -e "  ${GREEN}./todo.sh --done <ID>${NC}   - Mark as implemented"
    echo -e "  ${GREEN}./todo.sh --vote <ID>${NC}   - Vote for priority"
}

# Vote for a recommendation (increases priority)
# Multiple votes from different stations = higher collective priority
# Votes are linked to the original recommendation via ["e", rec_id] tag
vote_recommendation() {
    local rec_id="$1"
    local station_id="${IPFSNODEID:-unknown}"
    local captain="${CAPTAINEMAIL:-unknown}"
    
    echo -e "${BLUE}🗳️  Voting for recommendation: $rec_id${NC}"
    
    # Create a vote event linked to the original recommendation
    local vote_id="vote_${rec_id}_${station_id:0:12}_$(date +%Y%m%d%H%M%S)"
    local vote_content="Vote for $rec_id by $captain"
    
    # Store vote with reference to original recommendation
    if store_n2_memory "$vote_id" "$vote_content" "vote" "vote" "high" "$rec_id"; then
        echo -e "${GREEN}✅ Vote recorded${NC}"
        echo -e "${GREEN}   From: $captain @ ${station_id:0:12}...${NC}"
        echo -e "${GREEN}   For: $rec_id${NC}"
        
        # Display current vote count for this recommendation
        local vote_count=$(count_votes_for_recommendation "$rec_id")
        echo -e "${GREEN}   Total votes: $vote_count${NC}"
    else
        echo -e "${RED}❌ Failed to record vote${NC}"
        return 1
    fi
}

# Count votes for a specific recommendation
# Queries NOSTR for all vote events referencing this recommendation ID
count_votes_for_recommendation() {
    local rec_id="$1"
    local memory=$(fetch_n2_memory 100)
    
    if [[ -z "$memory" || "$memory" == "[]" ]]; then
        echo "0"
        return 0
    fi
    
    # Count events where rec_type=vote AND content references the rec_id
    local count=$(echo "$memory" | jq -r "
        [.[] | 
         select(.content != null) |
         select((.content | fromjson? | .rec_type // \"\") == \"vote\") |
         select(.content | contains(\"$rec_id\"))
        ] | length
    " 2>/dev/null || echo "0")
    
    echo "$count"
}

# Store each AI recommendation as a separate NOSTR event
# Called from interactive_select_recommendations
store_ai_recommendation() {
    local content="$1"
    local priority="$2"  # high | medium | low based on emoji
    
    # Extract priority from emoji if present
    if echo "$content" | grep -q "🔴"; then
        priority="high"
    elif echo "$content" | grep -q "🟡"; then
        priority="medium"
    elif echo "$content" | grep -q "🟢"; then
        priority="low"
    fi
    [[ -z "$priority" ]] && priority="medium"
    
    # Generate unique ID (12 chars hash for collision resistance)
    local rec_id="ai_$(date +%Y%m%d%H%M%S)_$(echo -n "$content" | md5sum | cut -c1-12)"
    
    # Store as individual event
    store_n2_memory "$rec_id" "$content" "proposed" "ai_recommendation" "$priority"
    
    echo "$rec_id"
}


# Vérifier que nous sommes dans un dépôt Git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Erreur: Ce répertoire n'est pas un dépôt Git${NC}"
    exit 1
fi

# Fonction pour obtenir les modifications selon la période configurée
get_git_changes() {
    echo -e "${BLUE}📊 Récupération des modifications Git ($PERIOD_LABEL)...${NC}"
    
    local commit_count=0
    local file_count=0
    
    # Check if PERIOD_GIT looks like a commit hash (40 hex chars or short hash)
    if [[ "$PERIOD_GIT" =~ ^[a-f0-9]{7,40}$ ]] && git rev-parse "$PERIOD_GIT" >/dev/null 2>&1; then
        # Use commit range for precise diff
        git log "${PERIOD_GIT}..HEAD" \
            --pretty=format:"%H|%an|%ae|%ad|%s" \
            --date=iso \
            --name-status \
            > "$GIT_LOG_FILE" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Aucune modification trouvée ($PERIOD_LABEL)${NC}"
            return 1
        }
        commit_count=$(git log "${PERIOD_GIT}..HEAD" --oneline 2>/dev/null | wc -l)
        file_count=$(git diff --name-only "$PERIOD_GIT" HEAD 2>/dev/null | wc -l)
    else
        # Use date-based query
        local since_date=$(date -d "$PERIOD_GIT" -Iseconds 2>/dev/null || date -v-${PERIOD_GIT// /} -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -u -d "$PERIOD_GIT" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "")
        
        if [[ -z "$since_date" ]]; then
            echo -e "${YELLOW}⚠️  Cannot parse date '$PERIOD_GIT', using 24h fallback${NC}"
            since_date=$(date -d "24 hours ago" -Iseconds 2>/dev/null || date -v-24H -u +"%Y-%m-%dT%H:%M:%S")
        fi
        
        git log --since="$since_date" \
            --pretty=format:"%H|%an|%ae|%ad|%s" \
            --date=iso \
            --name-status \
            > "$GIT_LOG_FILE" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Aucune modification trouvée ($PERIOD_LABEL)${NC}"
            return 1
        }
        commit_count=$(git log --since="$since_date" --oneline 2>/dev/null | wc -l)
        
        if [[ -n "$PERIOD_REF" ]]; then
            file_count=$(git diff --name-only "HEAD@{$PERIOD_REF}" HEAD 2>/dev/null | wc -l)
        else
            file_count=$(git log --since="$since_date" --name-only --pretty=format: 2>/dev/null | sort -u | grep -v '^$' | wc -l)
        fi
    fi
    
    if [[ $commit_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Aucune modification trouvée ($PERIOD_LABEL)${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ ${commit_count} commit(s) trouvé(s), ${file_count} fichier(s) modifié(s)${NC}"
    return 0
}

# Fonction pour analyser les modifications par système
analyze_changes_by_system() {
    local changes_summary=""
    local all_matched_files=""
    
    # Get all changed files for the period
    local all_changes=$(git diff --name-only HEAD@{$PERIOD_REF} HEAD 2>/dev/null || git log --since="$PERIOD_GIT" --name-only --pretty=format: | sort -u | grep -v '^$')
    
    if [[ -z "$all_changes" ]]; then
        echo "Aucune modification détectée."
        return
    fi
    
    # Systèmes à suivre (patterns regex corrigés)
    # Format: "NOM_SYSTEME:pattern1|pattern2|..."
    local -a system_definitions=(
        "UPassport:^UPassport/.*"
        "UPlanet:^UPlanet/.*"
        "RUNTIME:^RUNTIME/.*"
        "IA:^IA/.*"
        "Tools:^tools/.*"
        "Nostr:nostr.*|.*nostr.*\.py|.*nostr.*\.sh"
        "Economy:ZEN\.|LEGAL|economy|accounting"
        "DID:did_|make_NOSTRCARD|DID_IMPLEMENTATION"
        "ORE:ore_|ORE_SYSTEM"
        "Oracle:oracle|ORACLE|wotx"
        "PlantNet:plantnet|PLANTNET"
        "Cookie:cookie|COOKIE"
        "CoinFlip:coinflip|COINFLIP"
        "uMARKET:uMARKET|umarket"
        "NostrTube:youtube|NostrTube"
        "N8N:n8n|N8N"
        "Docs:^docs/.*|\.md$"
        "Config:\.json$|\.env|\.conf|requirements"
    )
    
    echo -e "${BLUE}🔍 Analyse des modifications par système...${NC}" >&2
    
    for system_def in "${system_definitions[@]}"; do
        local system_name="${system_def%%:*}"
        local patterns="${system_def#*:}"
        
        local system_changes=$(echo "$all_changes" | grep -iE "$patterns" 2>/dev/null || true)
        
        if [[ -n "$system_changes" ]]; then
            local file_count=$(echo "$system_changes" | wc -l)
            
            # Calculate stats (lines added/removed)
            local stats_add=0
            local stats_del=0
            while IFS= read -r file; do
                if [[ -n "$file" ]]; then
                    local file_stats=$(git diff --numstat HEAD@{$PERIOD_REF} HEAD -- "$file" 2>/dev/null || git log --since="$PERIOD_GIT" --numstat --pretty=format: -- "$file" 2>/dev/null | awk '{a+=$1; d+=$2} END {print a" "d}')
                    if [[ -n "$file_stats" ]]; then
                        local add=$(echo "$file_stats" | awk '{sum+=$1} END {print sum+0}')
                        local del=$(echo "$file_stats" | awk '{sum+=$2} END {print sum+0}')
                        stats_add=$((stats_add + add))
                        stats_del=$((stats_del + del))
                    fi
                    all_matched_files+="$file"$'\n'
                fi
            done <<< "$system_changes"
            
            # Format file list (max 8 files shown)
            local file_list=$(echo "$system_changes" | head -8 | sed 's/^/  - /')
            local remaining=$((file_count - 8))
            if [[ $remaining -gt 0 ]]; then
                file_list+=$'\n'"  - ... et $remaining autre(s)"
            fi
            
            # Add to summary with stats
            if [[ $stats_add -gt 0 || $stats_del -gt 0 ]]; then
                changes_summary+="\n### $system_name ($file_count fichier(s), +${stats_add}/-${stats_del} lignes)\n$file_list\n"
            else
                changes_summary+="\n### $system_name ($file_count fichier(s))\n$file_list\n"
            fi
        fi
    done
    
    # Find uncategorized files (Autres)
    local other_files=""
    while IFS= read -r file; do
        if [[ -n "$file" ]] && ! echo "$all_matched_files" | grep -qF "$file"; then
            other_files+="$file"$'\n'
        fi
    done <<< "$all_changes"
    
    if [[ -n "$other_files" ]]; then
        other_files=$(echo "$other_files" | grep -v '^$' | sort -u)
        local other_count=$(echo "$other_files" | wc -l)
        local other_list=$(echo "$other_files" | head -8 | sed 's/^/  - /')
        local remaining=$((other_count - 8))
        if [[ $remaining -gt 0 ]]; then
            other_list+=$'\n'"  - ... et $remaining autre(s)"
        fi
        changes_summary+="\n### Autres ($other_count fichier(s))\n$other_list\n"
    fi
    
    # Summary stats
    local total_files=$(echo "$all_changes" | wc -l)
    local total_stats=$(git diff --stat HEAD@{$PERIOD_REF} HEAD 2>/dev/null | tail -1 || echo "")
    
    if [[ -n "$total_stats" ]]; then
        changes_summary="\n**Total: $total_files fichier(s) modifié(s)** - $total_stats\n$changes_summary"
    else
        changes_summary="\n**Total: $total_files fichier(s) modifié(s)**\n$changes_summary"
    fi
    
    echo -e "$changes_summary"
}

# Fonction pour générer le prompt pour question.py (analyse + recommandations)
generate_ai_prompt() {
    local git_summary=$(cat "$GIT_LOG_FILE" 2>/dev/null | head -100)
    local changes_by_system=$(analyze_changes_by_system)
    
    # Lire TODO.md principal pour assurer la continuité
    local todo_main_content=""
    if [[ -f "$TODO_MAIN" ]]; then
        todo_main_content=$(cat "$TODO_MAIN" | head -200)
    else
        todo_main_content="TODO.md n'existe pas encore."
    fi
    
    # Fetch N² memory for learning context
    echo -e "${BLUE}📚 Récupération de la mémoire N²...${NC}" >&2
    local memory_json=$(fetch_n2_memory 15)
    local memory_context=$(format_memory_for_ai "$memory_json")
    
    cat <<EOF
Tu es un architecte logiciel expert en systèmes distribués, protocoles décentralisés (NOSTR, IPFS), et économie des communs.

**IMPORTANT - Apprentissage N²:**
Tu as accès à la mémoire partagée de la constellation. Les recommandations marquées "accepted" ont été validées par des humains (capitaines/développeurs). Les recommandations "rejected" ont été refusées. Apprends de ces décisions pour améliorer tes conseils.

$N2_CONTEXT

---

## Ta Mission

Analyse les modifications Git ($PERIOD_LABEL) et génère un rapport **actionnable** en français.

### PARTIE 1 - BILAN (50% du rapport)
- **Résumé exécutif** : 2-3 phrases sur les avancées majeures
- **Par système** : liste les modifications significatives (pas les détails mineurs)
- **Cohérence N²** : est-ce que les changements respectent l'architecture hybride NOSTR/IPFS ?

### PARTIE 2 - RECOMMANDATIONS STRATÉGIQUES (50% du rapport)

Propose **3-5 actions concrètes** en suivant ce format :

| Priorité | Action | Système | Justification N² |
|----------|--------|---------|------------------|
| 🔴 Haute | ... | RUNTIME/NOSTR/... | Pourquoi c'est critique pour la force 2 |
| 🟡 Moyenne | ... | ... | ... |
| 🟢 Basse | ... | ... | ... |

**Critères pour une bonne recommandation :**
1. **Renforce la force 2** : améliore le graphe social N1+N2 ou la sync constellation
2. **Respecte l'hybride** : NOSTR global, IPFS local
3. **Économiquement viable** : compatible avec le modèle Ẑen (1Ẑ=1€)
4. **Concrète** : peut être implémentée en 1-3 jours

**Exemples de bonnes recommandations :**
- "Ajouter le kind 30851 (Swarm Aggregate) au backfill_constellation.sh" → renforce sync N²
- "Implémenter expiration automatique des événements DID" → respect du protocole
- "Optimiser amisOfAmis.txt pour réduire la taille IPFS" → améliore perf locale

**Évite les recommandations génériques :**
- ❌ "Améliorer la documentation"
- ❌ "Ajouter des tests"
- ❌ "Refactoriser le code"

Format: Markdown structuré, **maximum 500 mots**, privilégie les tableaux.

---

## TODO.md principal (extrait) :
$todo_main_content

---

## Mémoire N² (apprentissage constellation) :
$memory_context

---

## Modifications Git ($PERIOD_LABEL) :
$git_summary

## Modifications par système :
$changes_by_system
EOF
}

# Fonction principale
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Initialize period for --last mode (since last execution)
    init_last_run_period
    
    local output_name=$(basename "$TODO_OUTPUT")
    echo -e "${GREEN}🚀 Génération de $output_name ($PERIOD_LABEL)${NC}"
    echo -e "${BLUE}🎮 N² Constellation Protocol (Conway's Angel Game - force 2)${NC}\n"
    
    # Récupérer les modifications Git
    if ! get_git_changes; then
        echo -e "${YELLOW}⚠️  Aucune modification à analyser${NC}"
        # Still save marker for next run
        save_run_marker
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
    
    # Générer le fichier TODO avec le résumé et recommandations
    local report_title="TODO - Dernière Session"
    [[ "$PERIOD" == "day" ]] && report_title="TODO Quotidien"
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

**Note** : Ce fichier est généré automatiquement par \`todo.sh\`. Le résumé IA compare déjà TODO.md avec les modifications Git pour assurer la continuité. Vérifiez et intégrez les informations pertinentes dans TODO.md manuellement.
EOF
    
    echo -e "${GREEN}✅ $output_name généré avec succès${NC}"
    echo -e "${BLUE}📄 Fichier: $TODO_OUTPUT${NC}\n"
    
    # Afficher un aperçu
    echo -e "${YELLOW}📋 Aperçu (premières 30 lignes):${NC}"
    head -30 "$TODO_OUTPUT"
    
    # Interactive mode: let captain select recommendations
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        interactive_select_recommendations "$ai_summary"
    else
        echo -e "\n${GREEN}💡 Mode batch: utilisez --accept/--reject pour valider les recommandations${NC}"
    fi
    
    echo -e "\n${GREEN}💡 Utilisez votre éditeur pour ouvrir $output_name et intégrer les informations dans TODO.md${NC}"
    
    # Publier le rapport sur le mur du CAPTAIN
    publish_todo_report
    
    # Publier sur Open Collective (si configuré)
    publish_opencollective_update
    
    # Save run marker for next --last execution
    save_run_marker
    
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

# Function to publish update to Open Collective using GraphQL API
# Requires OPENCOLLECTIVE_PERSONAL_TOKEN in ~/.zen/Astroport.ONE/.env
# Ref: https://graphql-docs-v2.opencollective.com
publish_opencollective_update() {
    # Check if Open Collective token is configured (use :- to avoid unbound variable error with set -u)
    local oc_token="${OPENCOLLECTIVE_PERSONAL_TOKEN:-}"
    if [[ -z "$oc_token" ]]; then
        echo -e "${YELLOW}⚠️  OPENCOLLECTIVE_PERSONAL_TOKEN not configured${NC}"
        echo -e "${YELLOW}   Add to ~/.zen/Astroport.ONE/.env:${NC}"
        echo -e "${YELLOW}   OPENCOLLECTIVE_PERSONAL_TOKEN=\"your_personal_token\"${NC}"
        echo -e "${YELLOW}   Get token: https://opencollective.com/dashboard/monnaie-libre/admin/for-developers${NC}"
        return 1
    fi
    
    # Check if TODO file exists
    if [[ ! -f "$TODO_OUTPUT" ]]; then
        echo -e "${YELLOW}⚠️  TODO file not found, skipping Open Collective publish${NC}"
        return 1
    fi
    
    # Track last update to avoid duplicates
    local OC_MARKER_DIR="$HOME/.zen/game/opencollective"
    local OC_MARKER_FILE="$OC_MARKER_DIR/last_update_${PERIOD}.marker"
    local OC_COLLECTIVE_SLUG="${OPENCOLLECTIVE_SLUG:-monnaie-libre}"
    
    mkdir -p "$OC_MARKER_DIR"
    
    # Get the last commit hash that was published
    local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local last_published_commit=""
    
    if [[ -f "$OC_MARKER_FILE" ]]; then
        last_published_commit=$(cat "$OC_MARKER_FILE" 2>/dev/null | head -1)
    fi
    
    # Check if we have new commits since last publish
    if [[ "$current_commit" == "$last_published_commit" ]]; then
        echo -e "${YELLOW}⚠️  No new commits since last Open Collective update, skipping${NC}"
        return 0
    fi
    
    local report_type="quotidien"
    [[ "$PERIOD" == "week" ]] && report_type="hebdomadaire"
    echo -e "${BLUE}📤 Publishing $report_type update to Open Collective ($OC_COLLECTIVE_SLUG)...${NC}"
    
    # Prepare content for Open Collective (convert Markdown to HTML-compatible)
    local report_content=$(cat "$TODO_OUTPUT")
    
    # Create title based on period
    local oc_title="Development Report - $(date +"%Y-%m-%d")"
    [[ "$PERIOD" == "week" ]] && oc_title="Weekly Development Report - $(date +"%Y-%m-%d")"
    
    # Extract summary from the report (first section after AI summary)
    local oc_summary=$(echo "$report_content" | sed -n '/## 📊 Résumé/,/^---/p' | head -15 | tail -n +2 | sed '/^---/d')
    [[ -z "$oc_summary" ]] && oc_summary="Automatic development report generated from Git changes"
    
    # Escape content for JSON (handle newlines, quotes, special chars)
    local escaped_content=$(echo "$report_content" | jq -Rs '.' | sed 's/^"//;s/"$//')
    local escaped_title=$(echo "$oc_title" | jq -Rs '.' | sed 's/^"//;s/"$//')
    
    # Prepare GraphQL mutation for createUpdate
    # Ref: https://docs.opencollective.com/help/contributing/development/api
    local graphql_query=$(cat <<EOF
{
    "query": "mutation CreateUpdate(\$update: UpdateCreateInput!) { createUpdate(update: \$update) { id slug title publishedAt } }",
    "variables": {
        "update": {
            "account": { "slug": "$OC_COLLECTIVE_SLUG" },
            "title": "$escaped_title",
            "html": "<pre style='white-space: pre-wrap; font-family: monospace;'>$escaped_content</pre>",
            "isPrivate": false,
            "makePublicOn": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        }
    }
}
EOF
)
    
    # Send GraphQL request
    local response=$(curl -s -X POST "https://api.opencollective.com/graphql/v2" \
        -H "Personal-Token: $oc_token" \
        -H "Content-Type: application/json" \
        -d "$graphql_query" 2>/dev/null)
    
    local curl_exit_code=$?
    
    if [[ $curl_exit_code -eq 0 && -n "$response" ]]; then
        # Check for GraphQL errors
        local errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
        
        if [[ -n "$errors" && "$errors" != "null" && "$errors" != "[]" ]]; then
            echo -e "${RED}❌ Open Collective GraphQL API errors:${NC}"
            echo "$errors" | jq -r '.[] | "  - \(.message // .)"' 2>/dev/null || echo "  $errors"
            return 1
        else
            # Parse successful response
            local update_id=$(echo "$response" | jq -r '.data.createUpdate.id // empty' 2>/dev/null)
            local update_slug=$(echo "$response" | jq -r '.data.createUpdate.slug // empty' 2>/dev/null)
            
            if [[ -n "$update_id" ]]; then
                echo -e "${GREEN}✅ Open Collective update published successfully${NC}"
                echo -e "${GREEN}   ID: $update_id${NC}"
                echo -e "${GREEN}   Title: $oc_title${NC}"
                echo -e "${GREEN}   URL: https://opencollective.com/$OC_COLLECTIVE_SLUG/updates/$update_slug${NC}"
                
                # Save marker with current commit hash
                echo "$current_commit" > "$OC_MARKER_FILE"
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OC_MARKER_FILE"
                echo "$update_id" >> "$OC_MARKER_FILE"
                
                # Log for tracking
                echo "$(date -u +%Y%m%d%H%M%S) UPDATE_PUBLISHED $update_id $OC_COLLECTIVE_SLUG $PERIOD $current_commit" >> "$OC_MARKER_DIR/updates.log"
            else
                echo -e "${YELLOW}⚠️  Unexpected response format:${NC}"
                echo "$response" | head -c 300
            fi
        fi
    else
        echo -e "${RED}❌ Open Collective API request failed (exit code: $curl_exit_code)${NC}"
        return 1
    fi
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
    
    # Publier sur Open Collective même en mode fallback
    publish_opencollective_update
}

# Exécuter le script
main "$@"
