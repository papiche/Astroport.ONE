#!/bin/bash
################################################################################
# Script: dashboard.JUSTICE.manager.sh
# Description: Administrer le protocole de médiation WoTx² UPlanet
#              (Kind 30506 dossiers, Kind 1984 frictions, Kind 1506 actes)
# Usage: dashboard.JUSTICE.manager.sh [COMMAND] [OPTIONS]
# Depends on: nostr_get_events.sh, nostr_node_intercom.py, my.sh
################################################################################
MY_PATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TOOLS_PATH="${MY_PATH}/../tools"
[[ -s "${TOOLS_PATH}/my.sh" ]] && source "${TOOLS_PATH}/my.sh"

################################################################################
# Colors
################################################################################
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'
BOLD='\033[1m'

################################################################################
# Configuration
################################################################################
NOSTR_GET="${TOOLS_PATH}/nostr_get_events.sh"
NOSTR_INTERCOM="${TOOLS_PATH}/nostr_node_intercom.py"
STRFRY_DIR="${HOME}/.zen/strfry"
STRFRY_BIN="${STRFRY_DIR}/strfry"
PENDING_DIR="${HOME}/.zen/tmp/justice_pending"
PROCESSED_DIR="${HOME}/.zen/tmp/justice_processed"
JUSTICE_LOG="${HOME}/.zen/tmp/justice_cases.log"
TEMP_DIR="${HOME}/.zen/tmp/justice_mgr_$$"

NOSTR_RELAY="${NOSTR_RELAY_WS:-ws://127.0.0.1:7777}"

################################################################################
# Kind labels
################################################################################
declare -A STATUS_LABEL=(
    [N1_ouvert]="🟡 N1 ouvert   (médiation amiable en cours)"
    [N1_résolu]="✅ N1 résolu   (accord amiable)"
    [N2_ouvert]="🔴 N2 ouvert   (arbitrage formel en cours)"
    [N2_résolu]="🏛️  N2 résolu   (verdict formel rendu)"
    [classé]="⬜ Classé       (sans suite)"
)

################################################################################
# Logging
################################################################################
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug()   { [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"; }

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
${CYAN}${BOLD}dashboard.JUSTICE.manager.sh — Protocole de Médiation WoTx²${NC}

${YELLOW}COMMANDES:${NC}
  stats               Statistiques globales des dossiers (par statut)
  list                Lister tous les dossiers Kind 30506
  list-open           Lister les dossiers actifs (N1/N2 ouverts)
  list-friction       Lister les signalements Kind 1984 (frictions)
  list-acts           Lister les actes Kind 1506 pour un dossier
  show CASE_ID        Afficher le détail d'un dossier
  pending             Afficher les dossiers en attente de traitement
  resolve CASE_ID     Marquer N1_résolu + publier Kind 30506 mis à jour
  escalate CASE_ID    Escalader vers N2 (N1_résolu → N2_ouvert)
  archive CASE_ID     Classer sans suite (status=classé)
  audit               Audit de cohérence (1984 sans 30506, 30506 orphelins)
  log                 Afficher le journal justice_cases.log
  browse              Navigateur interactif (dossiers → détails → actions)

${YELLOW}OPTIONS:${NC}
  --case CASE_ID      Identifiant du dossier (friction-XXXXX)
  --hex HEX           Pubkey hex du plaignant ou défendeur
  --since UNIX        Depuis timestamp Unix
  --status STATUS     Filtrer par statut (N1_ouvert, N2_ouvert, …)
  --limit N           Limite résultats (défaut: 50)
  --force             Pas de confirmation
  --verbose           Sortie détaillée

${YELLOW}NIVEAUX DE MÉDIATION:${NC}
  N1 (≤ 10 ẐEN)  → Médiation amiable, contacts communs amisOfAmis
  N2 (> 10 ẐEN)  → Arbitrage formel, 5 membres N2 titrés
  Constellation (> 50 ẐEN) → Vote assemblée constellation

${YELLOW}EXEMPLES:${NC}
  $0 stats
  $0 list-open
  $0 list-friction --since 1700000000
  $0 show friction-abc123-def456-20260531
  $0 pending
  $0 resolve --case friction-abc123-def456-20260531
  $0 audit

EOF
    exit 0
}

################################################################################
# Dépendances
################################################################################
check_dependencies() {
    local missing=()
    command -v jq   &>/dev/null || missing+=("jq")
    [[ ! -x "$NOSTR_GET" ]] && missing+=("nostr_get_events.sh")
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dépendances manquantes: ${missing[*]}"
        return 1
    fi
    return 0
}

################################################################################
# Strfry local scan (plus rapide que websocket pour les stats)
################################################################################
_strfry_scan() {
    local filter_json="$1"
    if [[ -x "$STRFRY_BIN" ]]; then
        cd "$STRFRY_DIR" && ./strfry scan "$filter_json" 2>/dev/null
    fi
}

################################################################################
# Récupérer les dossiers Kind 30506
################################################################################
_get_cases() {
    local status_filter="$1"
    local limit="${OPT_LIMIT:-50}"
    local since="${OPT_SINCE:-0}"

    local filter
    if [[ -n "$status_filter" ]]; then
        filter="{\"kinds\":[30506],\"#t\":[\"friction\"],\"since\":$since,\"limit\":$limit}"
    else
        filter="{\"kinds\":[30506],\"#t\":[\"friction\"],\"since\":$since,\"limit\":$limit}"
    fi

    if [[ -x "$STRFRY_BIN" ]]; then
        _strfry_scan "$filter" | if [[ -n "$status_filter" ]]; then
            jq -c --arg s "$status_filter" \
                'select(.tags[]? | select(.[0] == "status" and .[1] == $s))'
        else
            cat
        fi
    else
        bash "$NOSTR_GET" --kind 30506 --limit "$limit" 2>/dev/null
    fi
}

################################################################################
# Afficher un dossier formaté
################################################################################
_print_case() {
    local evt="$1"
    [[ -z "$evt" || "$evt" == "null" ]] && return

    local case_id created_at status level content
    case_id=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="d") | .[1]' 2>/dev/null | head -1)
    created_at=$(echo "$evt" | jq -r '.created_at' 2>/dev/null)
    status=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="status") | .[1]' 2>/dev/null | head -1)
    content=$(echo "$evt" | jq -r '.content | fromjson? // {}' 2>/dev/null)

    local title level description reparation_zen
    title=$(echo "$content" | jq -r '.title // "—"' 2>/dev/null)
    level=$(echo "$content" | jq -r '.level // "N1"' 2>/dev/null)
    description=$(echo "$content" | jq -r '.description // "—"' 2>/dev/null)
    reparation_zen=$(echo "$content" | jq -r '.reparation_zen // 0' 2>/dev/null)

    local plaignant defendeur
    plaignant=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="p" and .[2]=="role:plaignant") | .[1]' 2>/dev/null | head -1)
    defendeur=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="p" and .[2]=="role:défendeur") | .[1]' 2>/dev/null | head -1)
    [[ -z "$plaignant" ]] && plaignant=$(echo "$evt" | jq -r '[.tags[]? | select(.[0]=="p") | .[1]] | .[0] // "?"' 2>/dev/null)
    [[ -z "$defendeur" ]] && defendeur=$(echo "$evt" | jq -r '[.tags[]? | select(.[0]=="p") | .[1]] | .[1] // "?"' 2>/dev/null)

    local object_ref
    object_ref=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="object") | .[1]' 2>/dev/null | head -1)

    local date_str
    date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created_at")

    local status_display="${STATUS_LABEL[$status]:-$status}"

    echo -e ""
    echo -e "${BOLD}──────────────────────────────────────────────────────${NC}"
    echo -e " ${CYAN}${case_id}${NC}"
    echo -e " ${status_display}"
    echo -e " Niveau       : ${YELLOW}${level}${NC}  |  Date: ${date_str}"
    echo -e " Titre        : ${title}"
    echo -e " Description  : ${description}"
    echo -e " Plaignant    : ${plaignant:0:16}…"
    echo -e " Défendeur    : ${defendeur:0:16}…"
    [[ -n "$object_ref" ]] && echo -e " Objet        : ${object_ref}"
    [[ "$reparation_zen" != "0" ]] && echo -e " Réparation   : ${YELLOW}${reparation_zen} ẐEN${NC}"
}

################################################################################
# COMMANDE: stats
################################################################################
cmd_stats() {
    echo -e "\n${CYAN}${BOLD}⚖️  Statistiques de Médiation WoTx²${NC}\n"

    # Dossiers par statut
    echo -e "${YELLOW}Dossiers Kind 30506 par statut :${NC}"
    local total=0
    for status in "N1_ouvert" "N1_résolu" "N2_ouvert" "N2_résolu" "classé"; do
        local count=0
        if [[ -x "$STRFRY_BIN" ]]; then
            count=$(cd "$STRFRY_DIR" && ./strfry scan \
                "{\"kinds\":[30506],\"#status\":[\"$status\"]}" 2>/dev/null | wc -l)
        fi
        echo -e "  ${STATUS_LABEL[$status]:-$status}  : ${count}"
        ((total += count))
    done
    echo -e "  ${BOLD}Total dossiers${NC}   : ${total}"

    echo ""
    echo -e "${YELLOW}Signalements Kind 1984 (frictions uniquement) :${NC}"
    local friction_count=0
    if [[ -x "$STRFRY_BIN" ]]; then
        friction_count=$(cd "$STRFRY_DIR" && ./strfry scan \
            '{"kinds":[1984],"#report-type":["friction"]}' 2>/dev/null | wc -l 2>/dev/null || echo 0)
    fi
    echo -e "  Frictions signalées : ${friction_count}"

    echo ""
    echo -e "${YELLOW}Actes de médiation Kind 1506 :${NC}"
    local acts_count=0
    if [[ -x "$STRFRY_BIN" ]]; then
        acts_count=$(cd "$STRFRY_DIR" && ./strfry scan \
            '{"kinds":[1506]}' 2>/dev/null | wc -l 2>/dev/null || echo 0)
    fi
    echo -e "  Actes enregistrés : ${acts_count}"

    echo ""
    echo -e "${YELLOW}Dossiers en attente de traitement oracle :${NC}"
    local pending_count=0
    local processed_count=0
    [[ -d "$PENDING_DIR" ]] && pending_count=$(ls "$PENDING_DIR"/*.json 2>/dev/null | wc -l)
    [[ -d "$PROCESSED_DIR" ]] && processed_count=$(ls "$PROCESSED_DIR"/*.json 2>/dev/null | wc -l)
    echo -e "  En attente  : ${YELLOW}${pending_count}${NC}"
    echo -e "  Traités     : ${GREEN}${processed_count}${NC}"

    echo ""
    echo -e "${YELLOW}Fichiers amisOfAmis (cercle N2) :${NC}"
    local amis_count=0
    local amis_file="${HOME}/.zen/strfry/amisOfAmis.txt"
    [[ -f "$amis_file" ]] && amis_count=$(grep -cE '^[0-9a-fA-F]{64}$' "$amis_file" 2>/dev/null || echo 0)
    echo -e "  Membres N2 enregistrés : ${amis_count}"
}

################################################################################
# COMMANDE: list
################################################################################
cmd_list() {
    local status_filter="$OPT_STATUS"
    echo -e "\n${CYAN}${BOLD}📋 Dossiers de Médiation (Kind 30506)${NC}"
    [[ -n "$status_filter" ]] && echo -e "   Filtre statut: ${YELLOW}${status_filter}${NC}"
    echo ""

    local count=0
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        _print_case "$evt"
        ((count++))
    done < <(_get_cases "$status_filter")

    echo ""
    if [[ $count -eq 0 ]]; then
        log_info "Aucun dossier trouvé"
    else
        log_info "Total: ${count} dossier(s)"
    fi
}

################################################################################
# COMMANDE: list-open
################################################################################
cmd_list_open() {
    OPT_STATUS="" cmd_list_by_statuses "N1_ouvert" "N2_ouvert"
}

cmd_list_by_statuses() {
    echo -e "\n${CYAN}${BOLD}🔴 Dossiers actifs${NC}\n"
    local count=0
    for status in "$@"; do
        while IFS= read -r evt; do
            [[ -z "$evt" ]] && continue
            _print_case "$evt"
            ((count++))
        done < <(_get_cases "$status")
    done
    echo ""
    [[ $count -eq 0 ]] && log_info "Aucun dossier actif" || log_info "${count} dossier(s) actif(s)"
}

################################################################################
# COMMANDE: list-friction
################################################################################
cmd_list_friction() {
    echo -e "\n${CYAN}${BOLD}⚡ Signalements Kind 1984 — Frictions${NC}\n"
    local limit="${OPT_LIMIT:-30}"
    local since="${OPT_SINCE:-0}"
    local count=0

    local filter="{\"kinds\":[1984],\"since\":${since},\"limit\":${limit}}"

    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local rtype created_at pubkey
        rtype=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="report-type") | .[1]' 2>/dev/null | head -1)
        [[ "$rtype" != "friction" ]] && continue
        created_at=$(echo "$evt" | jq -r '.created_at' 2>/dev/null)
        pubkey=$(echo "$evt" | jq -r '.pubkey' 2>/dev/null)
        local reported=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="p") | .[1]' 2>/dev/null | head -1)
        local reason=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="reason") | .[1]' 2>/dev/null | head -1)
        local date_str
        date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created_at")
        echo -e "  ${date_str}  ${YELLOW}${pubkey:0:12}…${NC} → ${RED}${reported:0:12}…${NC}  raison: ${reason}"
        ((count++))
    done < <(_strfry_scan "$filter" 2>/dev/null || bash "$NOSTR_GET" --kind 1984 --limit "$limit" 2>/dev/null)

    echo ""
    [[ $count -eq 0 ]] && log_info "Aucun signalement friction" || log_info "${count} signalement(s)"
}

################################################################################
# COMMANDE: list-acts
################################################################################
cmd_list_acts() {
    local case_id="$OPT_CASE"
    if [[ -z "$case_id" ]]; then
        log_error "Requis: --case CASE_ID"
        exit 1
    fi
    echo -e "\n${CYAN}${BOLD}📜 Actes Kind 1506 — Dossier ${case_id}${NC}\n"

    local filter="{\"kinds\":[1506],\"#d\":[\"$case_id\"],\"limit\":100}"
    local count=0
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local created_at action arbitre vote note
        created_at=$(echo "$evt" | jq -r '.created_at' 2>/dev/null)
        local content
        content=$(echo "$evt" | jq -r '.content | fromjson? // {}' 2>/dev/null)
        action=$(echo "$content" | jq -r '.action // "?"' 2>/dev/null)
        arbitre=$(echo "$content" | jq -r '.arbitre // "?"' 2>/dev/null)
        vote=$(echo "$content" | jq -r '.vote // ""' 2>/dev/null)
        note=$(echo "$content" | jq -r '.note // ""' 2>/dev/null)
        local date_str
        date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created_at")
        local vote_col=""
        [[ "$vote" == "+1" ]] && vote_col="${GREEN}+1${NC}"
        [[ "$vote" == "-1" ]] && vote_col="${RED}-1${NC}"
        [[ -z "$vote" ]] && vote_col=""
        echo -e "  ${date_str}  ${YELLOW}${action}${NC}  ${vote_col}  ${note}"
        ((count++))
    done < <(_strfry_scan "$filter" 2>/dev/null)
    echo ""
    [[ $count -eq 0 ]] && log_info "Aucun acte pour ce dossier" || log_info "${count} acte(s)"
}

################################################################################
# COMMANDE: show
################################################################################
cmd_show() {
    local case_id="${OPT_CASE:-$1}"
    if [[ -z "$case_id" ]]; then
        log_error "Requis: --case CASE_ID ou argument positionnel"
        exit 1
    fi
    echo -e "\n${CYAN}${BOLD}🔎 Détail du dossier : ${case_id}${NC}"

    local filter="{\"kinds\":[30506],\"#d\":[\"$case_id\"],\"limit\":1}"
    local evt
    evt=$(_strfry_scan "$filter" | head -1)
    if [[ -z "$evt" ]]; then
        log_error "Dossier introuvable: $case_id"
        exit 1
    fi
    _print_case "$evt"

    # Afficher les actes associés
    OPT_CASE="$case_id" cmd_list_acts
}

################################################################################
# COMMANDE: pending
################################################################################
cmd_pending() {
    echo -e "\n${CYAN}${BOLD}⏳ Dossiers en attente de traitement oracle${NC}\n"
    if [[ ! -d "$PENDING_DIR" ]]; then
        log_info "Répertoire pending absent (aucune friction traitée)"
        return
    fi
    local count=0
    for f in "$PENDING_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local case_id
        case_id=$(jq -r '.case_id // "?"' "$f" 2>/dev/null)
        local plaignant defendeur amount level created_at
        plaignant=$(jq -r '.plaignant // "?"' "$f" 2>/dev/null)
        defendeur=$(jq -r '.défendeur // .defendeur // "?"' "$f" 2>/dev/null)
        amount=$(jq -r '.amount_zen // 0' "$f" 2>/dev/null)
        level=$(jq -r '.case_level // "N1"' "$f" 2>/dev/null)
        created_at=$(jq -r '.created_at // "?"' "$f" 2>/dev/null)
        echo -e "  ${YELLOW}${case_id}${NC}"
        echo -e "    Plaignant : ${plaignant:0:16}…  |  Défendeur : ${defendeur:0:16}…"
        echo -e "    Montant   : ${amount} ẐEN  |  Niveau : ${level}  |  Créé : ${created_at}"
        echo -e "    Fichier   : $(basename "$f")"
        echo ""
        ((count++))
    done
    [[ $count -eq 0 ]] && log_info "Aucun dossier en attente"
}

################################################################################
# COMMANDE: resolve — met à jour le statut Kind 30506
################################################################################
cmd_resolve() {
    local case_id="${OPT_CASE}"
    if [[ -z "$case_id" ]]; then
        log_error "Requis: --case CASE_ID"
        exit 1
    fi

    # Récupérer le dossier courant
    local filter="{\"kinds\":[30506],\"#d\":[\"$case_id\"],\"limit\":1}"
    local evt
    evt=$(_strfry_scan "$filter" | head -1)
    if [[ -z "$evt" ]]; then
        log_error "Dossier introuvable: $case_id"
        exit 1
    fi

    _print_case "$evt"
    echo ""
    if [[ "$OPT_FORCE" != "true" ]]; then
        read -rp "Marquer comme N1_résolu ? (o/N) " confirm
        [[ "$confirm" != "o" && "$confirm" != "O" ]] && { log_info "Annulé"; exit 0; }
    fi

    # Publier Kind 30506 mis à jour (status=N1_résolu)
    local nsec=""
    local secret_file="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    [[ -f "$secret_file" ]] && nsec=$(grep -oP 'NSEC=\K[^;]+' "$secret_file" | head -1)
    if [[ -z "$nsec" ]]; then
        log_error "NSEC oracle introuvable — ${secret_file}"
        exit 1
    fi

    local old_content new_content new_tags
    old_content=$(echo "$evt" | jq -r '.content' 2>/dev/null)
    new_content=$(echo "$old_content" | jq -c --arg s "N1_résolu" '.status = $s | .resolution = "Accord amiable"' 2>/dev/null)
    new_tags=$(echo "$evt" | jq -c '[.tags[]? | if .[0] == "status" then ["status","N1_résolu"] else . end]' 2>/dev/null)

    log_info "Publication Kind 30506 status=N1_résolu pour ${case_id}…"
    local py="${HOME}/.astro/bin/python3"; [[ ! -x "$py" ]] && py="python3"
    "$py" "$NOSTR_INTERCOM" publish \
        --nsec "$nsec" --kind 30506 \
        --content "$new_content" --tags "$new_tags" \
        --relays "$NOSTR_RELAY" 2>/dev/null \
        && log_success "Dossier ${case_id} marqué N1_résolu" \
        || log_error "Échec publication"
}

################################################################################
# COMMANDE: escalate — N1_ouvert → N2_ouvert
################################################################################
cmd_escalate() {
    local case_id="${OPT_CASE}"
    if [[ -z "$case_id" ]]; then
        log_error "Requis: --case CASE_ID"
        exit 1
    fi

    local filter="{\"kinds\":[30506],\"#d\":[\"$case_id\"],\"limit\":1}"
    local evt
    evt=$(_strfry_scan "$filter" | head -1)
    if [[ -z "$evt" ]]; then
        log_error "Dossier introuvable: $case_id"
        exit 1
    fi

    _print_case "$evt"
    echo ""
    if [[ "$OPT_FORCE" != "true" ]]; then
        read -rp "Escalader vers N2 (arbitrage formel) ? (o/N) " confirm
        [[ "$confirm" != "o" && "$confirm" != "O" ]] && { log_info "Annulé"; exit 0; }
    fi

    local nsec=""
    local secret_file="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    [[ -f "$secret_file" ]] && nsec=$(grep -oP 'NSEC=\K[^;]+' "$secret_file" | head -1)
    if [[ -z "$nsec" ]]; then
        log_error "NSEC oracle introuvable"
        exit 1
    fi

    local old_content new_content new_tags
    old_content=$(echo "$evt" | jq -r '.content' 2>/dev/null)
    new_content=$(echo "$old_content" | jq -c --arg s "N2_ouvert" '.status = $s | .level = "N2"' 2>/dev/null)
    new_tags=$(echo "$evt" | jq -c '[.tags[]? | if .[0] == "status" then ["status","N2_ouvert"]
        elif .[0] == "level" then ["level","N2"] else . end]' 2>/dev/null)

    log_info "Escalade vers N2 pour ${case_id}…"
    local py="${HOME}/.astro/bin/python3"; [[ ! -x "$py" ]] && py="python3"
    "$py" "$NOSTR_INTERCOM" publish \
        --nsec "$nsec" --kind 30506 \
        --content "$new_content" --tags "$new_tags" \
        --relays "$NOSTR_RELAY" 2>/dev/null \
        && log_success "Dossier ${case_id} escaladé → N2_ouvert" \
        || log_error "Échec publication"
}

################################################################################
# COMMANDE: archive — status=classé
################################################################################
cmd_archive() {
    local case_id="${OPT_CASE}"
    if [[ -z "$case_id" ]]; then
        log_error "Requis: --case CASE_ID"
        exit 1
    fi

    local filter="{\"kinds\":[30506],\"#d\":[\"$case_id\"],\"limit\":1}"
    local evt
    evt=$(_strfry_scan "$filter" | head -1)
    [[ -z "$evt" ]] && { log_error "Dossier introuvable: $case_id"; exit 1; }

    _print_case "$evt"
    echo ""
    if [[ "$OPT_FORCE" != "true" ]]; then
        read -rp "Classer sans suite ? (o/N) " confirm
        [[ "$confirm" != "o" && "$confirm" != "O" ]] && { log_info "Annulé"; exit 0; }
    fi

    local nsec=""
    local secret_file="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    [[ -f "$secret_file" ]] && nsec=$(grep -oP 'NSEC=\K[^;]+' "$secret_file" | head -1)
    [[ -z "$nsec" ]] && { log_error "NSEC oracle introuvable"; exit 1; }

    local old_content new_content new_tags
    old_content=$(echo "$evt" | jq -r '.content' 2>/dev/null)
    new_content=$(echo "$old_content" | jq -c '.status = "classé"' 2>/dev/null)
    new_tags=$(echo "$evt" | jq -c '[.tags[]? | if .[0] == "status" then ["status","classé"] else . end]' 2>/dev/null)

    local py="${HOME}/.astro/bin/python3"; [[ ! -x "$py" ]] && py="python3"
    "$py" "$NOSTR_INTERCOM" publish \
        --nsec "$nsec" --kind 30506 \
        --content "$new_content" --tags "$new_tags" \
        --relays "$NOSTR_RELAY" 2>/dev/null \
        && log_success "Dossier ${case_id} classé sans suite" \
        || log_error "Échec publication"
}

################################################################################
# COMMANDE: audit — cohérence 1984 ↔ 30506
################################################################################
cmd_audit() {
    echo -e "\n${CYAN}${BOLD}🔍 Audit de cohérence Justice${NC}\n"

    echo -e "${YELLOW}1. Signalements 1984 sans dossier 30506 correspondant :${NC}"
    local orphan_count=0
    local friction_filter='{"kinds":[1984],"limit":200}'
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local rtype
        rtype=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="report-type") | .[1]' 2>/dev/null | head -1)
        [[ "$rtype" != "friction" ]] && continue
        local eid pubkey created_at
        eid=$(echo "$evt" | jq -r '.id' 2>/dev/null)
        pubkey=$(echo "$evt" | jq -r '.pubkey' 2>/dev/null)
        created_at=$(echo "$evt" | jq -r '.created_at' 2>/dev/null)
        # Chercher un 30506 référençant cet event via #e
        local refs=0
        if [[ -x "$STRFRY_BIN" ]]; then
            refs=$(cd "$STRFRY_DIR" && ./strfry scan \
                "{\"kinds\":[30506],\"#e\":[\"$eid\"],\"limit\":1}" 2>/dev/null | wc -l)
        fi
        if [[ "$refs" -eq 0 ]]; then
            local date_str
            date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created_at")
            echo -e "  ${RED}⚠${NC}  ${date_str}  ${pubkey:0:12}…  id=${eid:0:16}…"
            ((orphan_count++))
        fi
    done < <(_strfry_scan "$friction_filter" 2>/dev/null)
    [[ $orphan_count -eq 0 ]] && echo -e "  ${GREEN}✓ Tous les signalements ont un dossier associé${NC}" \
        || echo -e "\n  ${YELLOW}→ ${orphan_count} signalement(s) sans dossier 30506${NC}"

    echo ""
    echo -e "${YELLOW}2. Dossiers 30506 sans acte 1506 :${NC}"
    local no_act_count=0
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local case_id
        case_id=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="d") | .[1]' 2>/dev/null | head -1)
        [[ -z "$case_id" ]] && continue
        local act_count=0
        if [[ -x "$STRFRY_BIN" ]]; then
            act_count=$(cd "$STRFRY_DIR" && ./strfry scan \
                "{\"kinds\":[1506],\"#d\":[\"$case_id\"],\"limit\":1}" 2>/dev/null | wc -l)
        fi
        if [[ "$act_count" -eq 0 ]]; then
            echo -e "  ${YELLOW}⚠${NC}  ${case_id}"
            ((no_act_count++))
        fi
    done < <(_strfry_scan '{"kinds":[30506],"limit":100}' 2>/dev/null)
    [[ $no_act_count -eq 0 ]] && echo -e "  ${GREEN}✓ Tous les dossiers ont au moins un acte 1506${NC}" \
        || echo -e "\n  ${YELLOW}→ ${no_act_count} dossier(s) sans acte enregistré${NC}"

    echo ""
    echo -e "${YELLOW}3. Dossiers en attente (non traités par oracle) :${NC}"
    cmd_pending
}

################################################################################
# COMMANDE: log
################################################################################
cmd_log() {
    local limit="${OPT_LIMIT:-50}"
    echo -e "\n${CYAN}${BOLD}📋 Journal des frictions (justice_cases.log)${NC}\n"
    if [[ ! -f "$JUSTICE_LOG" ]]; then
        log_info "Aucun journal: $JUSTICE_LOG"
        return
    fi
    tail -"$limit" "$JUSTICE_LOG" | while IFS='|' read -r ts case_id plaignant defendeur skill; do
        echo -e "  ${CYAN}${ts}${NC}  ${YELLOW}${case_id}${NC}"
        echo -e "    ${plaignant:0:16}… → ${defendeur:0:16}…  skill: ${skill}"
    done
}

################################################################################
# COMMANDE: browse (navigateur interactif)
################################################################################
cmd_browse() {
    echo -e "\n${CYAN}${BOLD}🗂️  Navigateur de Dossiers de Médiation${NC}\n"

    # Collecter tous les dossiers ouverts
    local cases=()
    while IFS= read -r evt; do
        [[ -n "$evt" ]] && cases+=("$evt")
    done < <(_strfry_scan '{"kinds":[30506],"limit":50}' 2>/dev/null)

    if [[ ${#cases[@]} -eq 0 ]]; then
        log_info "Aucun dossier Kind 30506 dans le relay"
        return
    fi

    # Menu de sélection
    echo -e "${YELLOW}Sélectionnez un dossier :${NC}"
    local i=1
    for evt in "${cases[@]}"; do
        local case_id status
        case_id=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="d") | .[1]' 2>/dev/null | head -1)
        status=$(echo "$evt" | jq -r '.tags[]? | select(.[0]=="status") | .[1]' 2>/dev/null | head -1)
        echo "  $i) ${case_id}  [${status}]"
        ((i++))
    done
    echo ""
    read -rp "Numéro (ou q pour quitter) : " choice
    [[ "$choice" == "q" ]] && return

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#cases[@]} ]]; then
        local selected="${cases[$((choice-1))]}"
        _print_case "$selected"
        local case_id
        case_id=$(echo "$selected" | jq -r '.tags[]? | select(.[0]=="d") | .[1]' 2>/dev/null | head -1)
        echo ""
        echo -e "${YELLOW}Actions disponibles :${NC}"
        echo "  r) Marquer N1_résolu"
        echo "  e) Escalader vers N2"
        echo "  a) Classer sans suite"
        echo "  l) Voir les actes Kind 1506"
        echo "  q) Quitter"
        read -rp "Action : " action
        case "$action" in
            r) OPT_CASE="$case_id" cmd_resolve ;;
            e) OPT_CASE="$case_id" cmd_escalate ;;
            a) OPT_CASE="$case_id" cmd_archive ;;
            l) OPT_CASE="$case_id" cmd_list_acts ;;
            *) log_info "Quitter" ;;
        esac
    else
        log_warning "Sélection invalide"
    fi
}

################################################################################
# Parse options
################################################################################
OPT_CASE=""
OPT_HEX=""
OPT_STATUS=""
OPT_LIMIT="50"
OPT_SINCE="0"
OPT_FORCE="false"
VERBOSE="false"
COMMAND=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        stats|list|list-open|list-friction|list-acts|show|pending|resolve|escalate|archive|audit|log|browse)
            COMMAND="$1"; shift ;;
        --case)   OPT_CASE="$2";   shift 2 ;;
        --hex)    OPT_HEX="$2";    shift 2 ;;
        --status) OPT_STATUS="$2"; shift 2 ;;
        --limit)  OPT_LIMIT="$2";  shift 2 ;;
        --since)  OPT_SINCE="$2";  shift 2 ;;
        --force)  OPT_FORCE="true"; shift ;;
        --verbose|-v) VERBOSE="true"; shift ;;
        --help|-h) usage ;;
        *)
            # Argument positionnel après une commande (ex: show CASE_ID)
            if [[ -n "$COMMAND" && -z "$OPT_CASE" ]]; then
                OPT_CASE="$1"; shift
            else
                log_error "Option inconnue: $1"; usage
            fi
            ;;
    esac
done

[[ -z "$COMMAND" ]] && usage

check_dependencies || exit 1
mkdir -p "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

case "$COMMAND" in
    stats)         cmd_stats ;;
    list)          cmd_list ;;
    list-open)     cmd_list_open ;;
    list-friction) cmd_list_friction ;;
    list-acts)     cmd_list_acts ;;
    show)          cmd_show ;;
    pending)       cmd_pending ;;
    resolve)       cmd_resolve ;;
    escalate)      cmd_escalate ;;
    archive)       cmd_archive ;;
    audit)         cmd_audit ;;
    log)           cmd_log ;;
    browse)        cmd_browse ;;
    *)             log_error "Commande inconnue: $COMMAND"; usage ;;
esac
