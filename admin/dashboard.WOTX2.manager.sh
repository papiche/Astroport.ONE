#!/bin/bash
################################################################################
# Script: dashboard.WOTX2.manager.sh
# Description: Administrer les événements WoTx2 / Grimoire / Oracle NOSTR
#              pour les comptes MULTIPASS locaux et la coopérative UPlanet.
# Usage: dashboard.WOTX2.manager.sh [COMMAND] [OPTIONS]
# Depends on: nostr_get_events.sh, nostr_send_note.py, strfry relay
################################################################################
MY_PATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TOOLS_PATH="${MY_PATH}/../tools"
# Source my.sh
[[ -s "${TOOLS_PATH}/my.sh" ]] \
    && source "${TOOLS_PATH}/my.sh"

################################################################################
# Colors
################################################################################
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

################################################################################
# Configuration
################################################################################
NOSTR_GET="${TOOLS_PATH}/nostr_get_events.sh"
NOSTR_SEND="${TOOLS_PATH}/nostr_send_note.py"
STRFRY_DIR="${HOME}/.zen/strfry"
STRFRY_BIN="${STRFRY_DIR}/strfry"
TEMP_DIR="${HOME}/.zen/tmp/wotx2_mgr_$$"

################################################################################
# WoTx2 / Grimoire / Oracle kind map
################################################################################
declare -A KIND_LABEL=(
    [7]="Avis pair (+ / -)"
    [21]="Vidéo formation — Grimoire (NIP-71 long)"
    [22]="Vidéo craft — Grimoire (NIP-71 short)"
    [1311]="Message chat LIVE (NIP-53)"
    [30311]="Session LIVE (NIP-53)"
    [30500]="Savoir-faire — Permit (WoTx2 auto-déclaré)"
    [30501]="Demande d'attestation (WoTx2)"
    [30502]="Attestation pair — Adoubement (WoTx2 Règle B)"
    [30503]="Certification WoTx2 (Règle A ou B)"
    [30504]="Ressource Formation (video/link/PDF)"
)

WOTX2_KINDS="30500 30501 30502 30503 30504 22 21 30311 1311 7"
SKILL_KINDS="30500 30501 30502 30503 30504"
MEDIA_KINDS="22 21"
LIVE_KINDS="30311 1311"

################################################################################
# Helpers pour requêtes liées à un skill
# nostr_get_events.sh supporte: --tag-d --tag-p --tag-e --tag-t --tag-g --tag-x
# Pas de --tag-a : les références NIP-33 (#a) sont filtrées côté client (jq)
################################################################################

# Récupérer l'event ID du Permit Kind 30500 d'un skill pour un auteur donné
_get_permit_id() {
    local user_hex="$1"
    local skill="$2"
    # Cherche par d-tag exact (MineLife: skill brut, TrocZen: PERMIT_SKILL_X1)
    local pid
    pid=$(bash "$NOSTR_GET" --kind 30500 --author "$user_hex" --tag-d "$skill" --limit 1 2>/dev/null \
          | jq -r '.id // empty' 2>/dev/null | head -n1)
    if [[ -z "$pid" ]]; then
        # Fallback: scan tous les 30500 de l'auteur et cherche le d-tag client-side
        pid=$(bash "$NOSTR_GET" --kind 30500 --author "$user_hex" --limit 200 2>/dev/null \
              | jq -r --arg sk "$skill" \
                  'select(.tags[]? | select(.[0] == "d" and .[1] == $sk)) | .id' 2>/dev/null \
              | head -n1)
    fi
    echo "$pid"
}

# Requêter les événements d'un kind qui référencent un skill (par e-tag ET a-tag)
# $1 = kind(s) espace-séparés ou unique, $2 = permit_id (event ID du 30500),
# $3 = user_hex (auteur du permit), $4 = skill, $5 = limit
_find_skill_refs() {
    local kinds="$1"
    local permit_id="$2"
    local user_hex="$3"
    local skill="$4"
    local limit="${5:-200}"
    local aref="30500:${user_hex}:${skill}"

    local results=""

    for k in $kinds; do
        # Style TrocZen: référence via #e → event ID du permit
        if [[ -n "$permit_id" ]]; then
            local by_e
            by_e=$(bash "$NOSTR_GET" --kind "$k" --tag-e "$permit_id" --limit "$limit" 2>/dev/null)
            results+="${by_e}"$'\n'
        fi

        # Style MineLife: référence via #a → "30500:hex:skill" (filtre client-side)
        local all_k
        all_k=$(bash "$NOSTR_GET" --kind "$k" --tag-p "$user_hex" --limit "$limit" 2>/dev/null)
        if [[ -n "$all_k" ]]; then
            local by_a
            by_a=$(printf '%s\n' "$all_k" | jq -c \
                --arg ar "$aref" \
                'select(.tags[]? | select(.[0] == "a" and .[1] == $ar))' 2>/dev/null)
            results+="${by_a}"$'\n'
        fi
    done

    # Dédupliquer par id
    printf '%s\n' "$results" | grep -v '^$' \
        | sort -t'"' -k4 | awk '!seen[$0]++' 2>/dev/null
}

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
${CYAN}dashboard.WOTX2.manager.sh — Gestionnaire WoTx2 / Grimoire / Oracle${NC}

${YELLOW}COMMANDES:${NC}
    stats               Statistiques globales par kind et par utilisateur
    list-all            Lister tous les événements WoTx2 du relay, groupés par skill
    list                Lister les événements d'un utilisateur (tous kinds)
    browse              Navigateur interactif (utilisateur → événements → détail)
    user                Administration interactive d'un MULTIPASS local
    check               Audit de complétude WoTx2 pour un utilisateur
    certify             Vérifier Règle A/B et publier une Kind 30503
    cleanup             Nettoyer les événements invalides / orphelins
    republish KIND      Ré-injecter les événements d'un kind dans le relay
    export-skill        Exporter l'arbre d'un skill (tous les événements liés)
    delete-skill        Supprimer l'arbre complet d'un skill (backup + kind5 + physique)
    demo                Gérer les comptes de démonstration (~/.zen/demo/)

${YELLOW}OPTIONS (communes):${NC}
    --npub NPUB         Clé npub de l'utilisateur
    --hex HEX           Clé pubkey hex de l'utilisateur
    --email EMAIL       Email du MULTIPASS
    --skill SKILL       Tag skill (ex: cuisine, soudure, Python)
    --kind KIND         Kind NOSTR (ex: 30503)
    --limit N           Limite résultats (défaut: 100)
    --since UNIX        Depuis timestamp Unix
    --until UNIX        Jusqu'à timestamp Unix
    --force             Pas de confirmation
    --verbose           Sortie détaillée

${YELLOW}EXEMPLES:${NC}
    $0 stats
    $0 list-all
    $0 list --email alice@example.com
    $0 browse
    $0 user --email alice@example.com
    $0 check --hex a1b2c3...
    $0 certify --email alice@example.com --skill cuisine
    $0 cleanup --force
    $0 republish 30311
    $0 export-skill --email alice@example.com --skill cuisine
    $0 delete-skill --email alice@example.com --skill cuisine

${YELLOW}ARBRE D'UN SKILL (tag d=«skill») :${NC}
    Kind 30500  Permit auto-déclaré
    Kind 7      Avis pair (références vers 30500)
    Kind 30501  Demande d'attestation
    Kind 30502  Adoubement pair (Règle B)
    Kind 30503  Certification (Règle A ou B)
    Kind 30504  Ressource formation
    Kind 22/21  Craft vidéo lié au skill
    Kind 30311  Sessions LIVE liées

EOF
    exit 0
}

################################################################################
# Logging
################################################################################
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug()   { [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"; }

################################################################################
# Dépendances
################################################################################
check_dependencies() {
    local missing=()
    command -v jq   &>/dev/null || missing+=("jq")
    command -v date &>/dev/null || missing+=("date")
    [[ ! -x "$NOSTR_GET" ]] && missing+=("nostr_get_events.sh")
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dépendances manquantes: ${missing[*]}"
        return 1
    fi
    return 0
}

################################################################################
# Conversion npub → hex
################################################################################
npub_to_hex() {
    local npub="$1"
    NPUB_ARG="$npub" python3 -c "
import os
from nostr.key import PublicKey
print(PublicKey.from_npub(os.environ['NPUB_ARG']).hex())
" 2>/dev/null || echo "$npub"
}

################################################################################
# Trouver le hex à partir de l'email
################################################################################
find_hex_from_email() {
    local email="$1"
    local player_dir="${HOME}/.zen/game/players"
    local found_hex="" found_count=0

    for dir in "$player_dir"/*/"$email"; do
        if [[ -d "$dir" ]] && [[ -f "$dir/.secret.nostr" ]]; then
            local hex
            hex=$(grep -oP 'HEX=\K[a-f0-9]{64}' "$dir/.secret.nostr" 2>/dev/null)
            if [[ -n "$hex" ]]; then
                (( found_count++ ))
                [[ $found_count -eq 1 ]] && found_hex="$hex"
            fi
        fi
    done
    if [[ $found_count -gt 1 ]]; then
        log_warning "Plusieurs entrées players/ pour: $email — premier résultat utilisé" >&2
    fi
    if [[ -n "$found_hex" ]]; then echo "$found_hex"; return 0; fi

    # Fallback: ~/.zen/game/nostr/email/.secret.nostr
    local nostr_secret="${HOME}/.zen/game/nostr/${email}/.secret.nostr"
    if [[ -f "$nostr_secret" ]]; then
        local hex
        hex=$(grep -oP 'HEX=\K[a-f0-9]{64}' "$nostr_secret" 2>/dev/null)
        [[ -n "$hex" ]] && { echo "$hex"; return 0; }
    fi

    log_error "Impossible de trouver le hex pour: $email" >&2
    return 1
}

################################################################################
# Vérifier si une pubkey est locale (MULTIPASS sur cette station)
################################################################################
check_local_pubkey() {
    local pubkey_hex="$1"
    grep -qr "^${pubkey_hex}$" "${HOME}/.zen/game/nostr"/*@*/HEX 2>/dev/null
}

################################################################################
# Trouver le fichier .secret.nostr à partir du hex (via DID Kind 30800)
################################################################################
find_secret_file_by_hex() {
    local user_hex="$1"

    # Cherche directement par HEX dans ~/.zen/game/nostr/*/HEX
    local nostr_base="${HOME}/.zen/game/nostr"
    if [[ -d "$nostr_base" ]]; then
        for email_dir in "$nostr_base"/*; do
            [[ -d "$email_dir" ]] || continue
            local hex_file="${email_dir}/HEX"
            if [[ -f "$hex_file" ]]; then
                local stored_hex
                stored_hex=$(tr -d '\n\r ' < "$hex_file")
                if [[ "$stored_hex" == "$user_hex" ]]; then
                    local secret="${email_dir}/.secret.nostr"
                    [[ -f "$secret" ]] && { echo "$secret"; return 0; }
                fi
            fi
        done
    fi

    # Fallback via DID (Kind 30800)
    log_debug "Requête DID pour ${user_hex:0:16}..."
    local did_event
    did_event=$(bash "$NOSTR_GET" --kind 30800 --author "$user_hex" --limit 1 2>/dev/null)
    if [[ -n "$did_event" ]]; then
        local email
        email=$(echo "$did_event" | jq -r '
            if type == "array" then .[0] else . end
            | .tags[]? | select(.[0] == "email") | .[1]
        ' 2>/dev/null | head -n1)
        if [[ -z "$email" ]]; then
            email=$(echo "$did_event" | jq -r '
                if type == "array" then .[0] else . end
                | .content | fromjson | .alsoKnownAs[]?
                | select(startswith("mailto:")) | sub("^mailto:"; "")
            ' 2>/dev/null | head -n1)
        fi
        if [[ -n "$email" ]]; then
            local secret="${HOME}/.zen/game/nostr/${email}/.secret.nostr"
            [[ -f "$secret" ]] && { echo "$secret"; return 0; }
        fi
    fi

    return 1
}

################################################################################
# Supprimer un événement (kind5 / physical / both)
################################################################################
delete_event_by_id() {
    local event_id="$1"
    local user_hex="$2"
    local force="${3:-false}"
    local mode="${4:-kind5}"   # kind5 | physical | both

    case "$mode" in
    both)
        delete_event_by_id "$event_id" "$user_hex" "true" "kind5"   || return 1
        delete_event_by_id "$event_id" "$user_hex" "true" "physical" || return 1
        return 0
        ;;
    physical)
        if [[ ! -f "$STRFRY_BIN" ]]; then
            log_error "strfry introuvable: $STRFRY_BIN"; return 1
        fi
        local ids_json
        ids_json=$(printf '%s' "$event_id" | jq -Rs '{ids: [.]}')
        cd "$STRFRY_DIR" || return 1
        ./strfry delete --filter="$ids_json" &>/dev/null
        local rc=$?
        cd - >/dev/null 2>&1
        [[ $rc -eq 0 ]] && log_success "Supprimé physiquement: ${event_id:0:16}…" || log_error "Échec suppression physique: ${event_id:0:16}…"
        return $rc
        ;;
    kind5)
        # Publier un événement Kind 5 (NIP-09)
        if [[ ! -f "$NOSTR_SEND" ]]; then
            log_error "nostr_send_note.py introuvable: $NOSTR_SEND"; return 1
        fi
        local secret_file
        secret_file=$(find_secret_file_by_hex "$user_hex")
        if [[ -z "$secret_file" ]]; then
            log_error "Fichier .secret.nostr introuvable pour ${user_hex:0:16}…"; return 1
        fi
        case "$secret_file" in
            "${HOME}/.zen/game/nostr"/*) ;;
            *) log_error "Chemin .secret.nostr hors limites: $secret_file"; return 1 ;;
        esac
        local tags_json="[[\"e\",\"$event_id\"]]"
        local result
        result=$(python3 "$NOSTR_SEND" \
            --keyfile "$secret_file" \
            --content "Supprimé par le propriétaire" \
            --kind 5 \
            --tags "$tags_json" \
            --json 2>&1)
        local rc=$?
        if [[ $rc -eq 0 ]] && echo "$result" | jq -e '.success == true' &>/dev/null; then
            log_success "Kind 5 publié pour: ${event_id:0:16}…"
            return 0
        else
            log_error "Échec publication Kind 5: ${event_id:0:16}…"
            log_debug "Résultat: $result"
            return 1
        fi
        ;;
    esac
}

################################################################################
# cmd_stats — statistiques globales
################################################################################
cmd_stats() {
    local user_hex="${USER_HEX:-}"
    local limit="${LIMIT:-1000}"

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${YELLOW}WoTx2 / Grimoire / Oracle — État du relay local${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total_all=0

    for kind in $WOTX2_KINDS; do
        local args=("--kind" "$kind" "--limit" "$limit" "--output" "count")
        [[ -n "$user_hex" ]] && args+=("--author" "$user_hex")
        local count
        count=$(bash "$NOSTR_GET" "${args[@]}" 2>/dev/null)
        count=${count:-0}
        total_all=$((total_all + count))
        local label="${KIND_LABEL[$kind]:-?}"
        local color="$YELLOW"
        [[ "$count" -gt 0 ]] && color="$GREEN"
        printf "  ${color}%-8s${NC} %-6s  %s\n" "Kind $kind" "[$count]" "$label"
    done

    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  Total : ${GREEN}$total_all${NC} événements WoTx2"
    echo ""

    # Breakdown par MULTIPASS local
    local nostr_base="${HOME}/.zen/game/nostr"
    if [[ -z "$user_hex" ]] && [[ -d "$nostr_base" ]]; then
        echo -e "${YELLOW}Comptes MULTIPASS locaux :${NC}"
        local has_account=false
        for email_dir in "$nostr_base"/*; do
            [[ -d "$email_dir" ]] || continue
            local hex_file="${email_dir}/HEX"
            [[ -f "$hex_file" ]] || continue
            local hex; hex=$(tr -d '\n\r ' < "$hex_file")
            local email; email=$(basename "$email_dir")
            local permits certs crafts lives
            permits=$(bash "$NOSTR_GET" --kind 30500 --author "$hex" --limit 1000 --output count 2>/dev/null)
            certs=$(bash "$NOSTR_GET" --kind 30503 --author "$hex" --limit 1000 --output count 2>/dev/null)
            crafts=$(bash "$NOSTR_GET" --kind 22 --author "$hex" --limit 1000 --output count 2>/dev/null)
            lives=$(bash "$NOSTR_GET" --kind 30311 --author "$hex" --limit 1000 --output count 2>/dev/null)
            permits=${permits:-0}; certs=${certs:-0}; crafts=${crafts:-0}; lives=${lives:-0}
            if [[ $((permits + certs + crafts + lives)) -gt 0 ]]; then
                has_account=true
                printf "  ${CYAN}%-32s${NC}  Permits:${GREEN}%2d${NC}  Certs:${GREEN}%2d${NC}  Crafts:${GREEN}%2d${NC}  LIVE:${GREEN}%2d${NC}\n" \
                    "$email" "$permits" "$certs" "$crafts" "$lives"
            fi
        done
        [[ "$has_account" == "false" ]] && echo "  (aucun compte local avec des événements WoTx2)"
        echo ""
    fi
}

################################################################################
# cmd_list_all — tous les événements WoTx2, groupés par skill
################################################################################
cmd_list_all() {
    local kind="${KIND:-}"
    local limit="${LIMIT:-200}"

    log_info "Chargement de tous les événements WoTx2 du relay..."

    local kinds_to_query="$WOTX2_KINDS"
    [[ -n "$kind" ]] && kinds_to_query="$kind"

    local -A skill_permits  # skill → author hex list
    local -A skill_certs    # skill → cert count
    local total_count=0

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                   ${YELLOW}Tous les événements WoTx2 du relay${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    for k in $kinds_to_query; do
        local events
        events=$(bash "$NOSTR_GET" --kind "$k" --limit "$limit" 2>/dev/null)
        [[ -z "$events" ]] && continue

        local label="${KIND_LABEL[$k]:-Kind $k}"
        local count=0
        echo -e "${YELLOW}── Kind $k : $label ──${NC}"

        while IFS= read -r event; do
            [[ -z "$event" ]] && continue
            local event_id author created_at skill content
            event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null); [[ -z "$event_id" ]] && continue
            author=$(echo "$event"   | jq -r '.pubkey // "?"' 2>/dev/null)
            created_at=$(echo "$event" | jq -r '.created_at // 0' 2>/dev/null)
            local date; date=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created_at")
            skill=$(echo "$event" | jq -r '
                (.tags[]? | select(.[0] == "d") | .[1]) //
                (.tags[]? | select(.[0] == "t") | .[1]) //
                "—"
            ' 2>/dev/null | head -n1)
            content=$(echo "$event" | jq -r '.content // ""' 2>/dev/null | head -c 70 | tr '\n' ' ')

            # Indicateur LOCAL
            local loc=""
            check_local_pubkey "$author" && loc="${GREEN}[LOCAL]${NC} "

            printf "  ${GREEN}%s${NC} ${loc}${YELLOW}%-20s${NC} ${BLUE}%s${NC}  %s\n" \
                "${event_id:0:12}…" "${skill}" "$date" "${content:0:60}"

            # Indexer pour résumé
            case "$k" in
                30500) skill_permits["$skill"]+="${author} " ;;
                30503) skill_certs["$skill"]=$((${skill_certs["$skill"]:-0} + 1)) ;;
            esac

            count=$((count + 1))
            total_count=$((total_count + 1))
        done <<< "$events"

        echo -e "  → ${GREEN}$count${NC} événement(s)"
        echo ""
    done

    echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  Total global : ${GREEN}$total_count${NC} événements WoTx2"
    echo ""

    # Résumé par skill
    if [[ ${#skill_permits[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Résumé par skill (Permits déclarés) :${NC}"
        for skill in "${!skill_permits[@]}"; do
            local nb_permits; nb_permits=$(echo "${skill_permits[$skill]}" | wc -w)
            local nb_certs="${skill_certs[$skill]:-0}"
            local cert_color="$RED"; [[ "$nb_certs" -gt 0 ]] && cert_color="$GREEN"
            printf "  ${CYAN}%-24s${NC}  Permits:${GREEN}%2d${NC}  Certs:${cert_color}%2d${NC}\n" \
                "$skill" "$nb_permits" "$nb_certs"
        done
        echo ""
    fi
}

################################################################################
# cmd_list — événements WoTx2 d'un utilisateur
################################################################################
cmd_list() {
    local user_hex="${USER_HEX:-$1}"
    local limit="${LIMIT:-100}"
    [[ -z "$user_hex" ]] && { log_error "Fournir --hex, --npub ou --email"; return 1; }

    local is_local=false
    check_local_pubkey "$user_hex" && is_local=true

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    if [[ "$is_local" == "true" ]]; then
        echo -e "${CYAN}║${NC}        ${GREEN}Événements WoTx2 — MULTIPASS LOCAL${NC}  ${user_hex:0:20}…           ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC}        ${YELLOW}Événements WoTx2 — COMPTE DISTANT${NC}  ${user_hex:0:20}…           ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total_user=0
    declare -A user_skills

    for kind in $WOTX2_KINDS; do
        local events
        events=$(bash "$NOSTR_GET" --kind "$kind" --author "$user_hex" --limit "$limit" 2>/dev/null)
        [[ -z "$events" ]] && continue

        local label="${KIND_LABEL[$kind]:-Kind $kind}"
        echo -e "${YELLOW}── Kind $kind : $label ──${NC}"

        while IFS= read -r event; do
            [[ -z "$event" ]] && continue
            local event_id author created_at skill content status_tag
            event_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null); [[ -z "$event_id" ]] && continue
            created_at=$(echo "$event" | jq -r '.created_at // 0' 2>/dev/null)
            local date; date=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created_at")
            skill=$(echo "$event" | jq -r '
                (.tags[]? | select(.[0] == "d") | .[1]) //
                (.tags[]? | select(.[0] == "t") | .[1]) //
                "—"
            ' 2>/dev/null | head -n1)
            content=$(echo "$event" | jq -r '.content // ""' 2>/dev/null | head -c 60 | tr '\n' ' ')

            # Statut pour Kind 30311 (LIVE)
            if [[ "$kind" == "30311" ]]; then
                status_tag=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "status") | .[1]' 2>/dev/null | head -n1)
                local status_color="$YELLOW"
                [[ "$status_tag" == "live"  ]] && status_color="$RED"
                [[ "$status_tag" == "ended" ]] && status_color="$BLUE"
                printf "  ${GREEN}%s${NC} [${status_color}%s${NC}] ${CYAN}%-20s${NC} ${BLUE}%s${NC}\n" \
                    "${event_id:0:12}…" "${status_tag:-?}" "$skill" "$date"
            else
                printf "  ${GREEN}%s${NC} ${CYAN}%-20s${NC} ${BLUE}%s${NC}  %s\n" \
                    "${event_id:0:12}…" "$skill" "$date" "${content:0:55}"
            fi

            [[ "$skill" != "—" ]] && user_skills["$skill"]=1
            total_user=$((total_user + 1))
        done <<< "$events"
        echo ""
    done

    echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  Total : ${GREEN}$total_user${NC} événements"
    echo -e "  Skills déclarés : ${CYAN}${!user_skills[*]}${NC}"
    echo ""
}

################################################################################
# cmd_check — audit de complétude WoTx2 pour un utilisateur
################################################################################
cmd_check() {
    local user_hex="${USER_HEX:-$1}"
    [[ -z "$user_hex" ]] && { log_error "Fournir --hex, --npub ou --email"; return 1; }

    log_info "Audit de complétude WoTx2 pour ${user_hex:0:20}…"

    # Collecter tous les skills déclarés (Kind 30500)
    local permits
    permits=$(bash "$NOSTR_GET" --kind 30500 --author "$user_hex" --limit 200 2>/dev/null)

    if [[ -z "$permits" ]]; then
        log_warning "Aucun Permit (Kind 30500) trouvé pour cet utilisateur."
        return 0
    fi

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}Audit WoTx2 — Complétude par skill${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        local permit_id skill
        permit_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null); [[ -z "$permit_id" ]] && continue
        skill=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "d") | .[1]' 2>/dev/null | head -n1)
        [[ -z "$skill" ]] && skill=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "t") | .[1]' 2>/dev/null | head -n1)
        [[ -z "$skill" ]] && skill="(sans tag)"

        # Récupérer l'ID du permit pour les requêtes par #e (TrocZen) + filtre #a (MineLife)
        local permit_ev_id
        permit_ev_id=$(echo "$event" | jq -r '.id // empty' 2>/dev/null)

        # Avis positifs Kind 7 visant ce permit (styles e-tag et a-tag)
        local votes_raw
        votes_raw=$(_find_skill_refs "7" "$permit_ev_id" "$user_hex" "$skill" 50)
        local votes_pos=0
        while IFS= read -r v; do
            [[ -z "$v" ]] && continue
            local vpub vauthor vcontent
            vpub=$(echo "$v" | jq -r '.pubkey' 2>/dev/null)
            vcontent=$(echo "$v" | jq -r '.content' 2>/dev/null)
            # Ignorer les auto-votes et compter les + (pas -)
            if [[ "$vpub" != "$user_hex" ]] && [[ "$vcontent" =~ ^\+ ]]; then
                votes_pos=$((votes_pos + 1))
            fi
        done <<< "$votes_raw"

        # Kind 30501 (demande attestation) — référence par e-tag ou a-tag
        local req_raw
        req_raw=$(_find_skill_refs "30501" "$permit_ev_id" "$user_hex" "$skill" 10)
        local req_count; req_count=$(printf '%s\n' "$req_raw" | grep -c '"id"' 2>/dev/null || echo 0)
        req_count=${req_count:-0}

        # Kind 30502 (adoubement) — référence par e-tag ou a-tag
        local ado_raw
        ado_raw=$(_find_skill_refs "30502" "$permit_ev_id" "$user_hex" "$skill" 10)
        local ado_count; ado_count=$(printf '%s\n' "$ado_raw" | grep -c '"id"' 2>/dev/null || echo 0)
        ado_count=${ado_count:-0}

        # Kind 30503 (certification)
        local cert_count
        cert_count=$(bash "$NOSTR_GET" --kind 30503 --author "$user_hex" --limit 50 --output count 2>/dev/null)
        # Filtrer ceux qui référencent ce skill
        # (simplifié: on compte tous les 30503 de l'utilisateur pour ce skill)
        cert_count=${cert_count:-0}

        # Kind 30504 (ressource)
        local res_count
        res_count=$(bash "$NOSTR_GET" --kind 30504 --author "$user_hex" --limit 20 --output count 2>/dev/null)
        res_count=${res_count:-0}

        # Kind 22 (craft vidéo)
        local craft_count
        craft_count=$(bash "$NOSTR_GET" --kind 22 --author "$user_hex" --limit 50 --output count 2>/dev/null)
        craft_count=${craft_count:-0}

        # Règle A: 3 votes positifs distincts → éligible certification
        local regle_a="❌"; [[ $votes_pos -ge 3 ]] && regle_a="✅"
        local regle_b="❌"; [[ $ado_count -ge 1 ]] && regle_b="✅"
        local certified="❌"; [[ $cert_count -ge 1 ]] && certified="✅"

        echo -e "${YELLOW}Skill : ${CYAN}$skill${NC}"
        printf "  Permit  (30500) : %s${event_id:0:12}…\n" "${permit_id:0:12}"
        printf "  Avis +  (Kind 7): %d  %s\n" "$votes_pos" "$regle_a (Règle A: ≥3)"
        printf "  Demande (30501) : %d\n"  "$req_count"
        printf "  Adoubt  (30502) : %d  %s\n" "$ado_count" "$regle_b (Règle B: ≥1)"
        printf "  Certif  (30503) : %d  %s\n" "$cert_count" "$certified"
        printf "  Ressrc  (30504) : %d\n"  "$res_count"
        printf "  Crafts  (Kind22): %d\n"  "$craft_count"
        echo ""

    done <<< "$permits"
}

################################################################################
# export_skill_tree — exporter l'arbre complet d'un skill
################################################################################
export_skill_tree() {
    local user_hex="$1"
    local skill="$2"
    local export_dir="${HOME}/.zen/tmp/wotx2_export_${skill}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"

    local export_file="${export_dir}/skill_tree_${skill}.jsonl"
    local summary_file="${export_dir}/summary.txt"

    log_info "Export arbre skill «$skill» pour ${user_hex:0:16}…"
    : > "$export_file"

    # Récupérer le permit event ID pour les requêtes #e
    local permit_ev_id
    permit_ev_id=$(_get_permit_id "$user_hex" "$skill")
    local aref="30500:${user_hex}:${skill}"
    [[ -n "$permit_ev_id" ]] && log_debug "Permit ID: ${permit_ev_id:0:16}…"

    local -A exported_kinds
    local total=0

    # Permit lui-même (Kind 30500)
    local permit_events
    permit_events=$(bash "$NOSTR_GET" --kind 30500 --author "$user_hex" --limit 200 2>/dev/null)
    local pc=0
    while IFS= read -r ev; do
        [[ -z "$ev" ]] && continue
        local ev_d; ev_d=$(echo "$ev" | jq -r '.tags[]? | select(.[0] == "d") | .[1]' 2>/dev/null | head -n1)
        if [[ "$ev_d" == "$skill" ]]; then
            echo "$ev" >> "$export_file"; pc=$((pc + 1)); total=$((total + 1))
        fi
    done <<< "$permit_events"
    exported_kinds[30500]=$pc

    # Avis Kind 7 — styles e-tag (TrocZen) et a-tag (MineLife)
    local votes
    votes=$(_find_skill_refs "7" "$permit_ev_id" "$user_hex" "$skill" 500)
    local vc=0
    while IFS= read -r ev; do
        [[ -z "$ev" ]] && continue
        echo "$ev" >> "$export_file"; vc=$((vc + 1)); total=$((total + 1))
    done <<< "$votes"
    exported_kinds[7]=$vc

    # Kinds 30501 30502 30503 30504 — événements liés au skill
    for k in 30501 30502 30503 30504; do
        local refs
        refs=$(_find_skill_refs "$k" "$permit_ev_id" "$user_hex" "$skill" 200)
        # Pour 30503/30504 aussi chercher par d-tag direct (auto-signé par l'utilisateur)
        local by_d
        by_d=$(bash "$NOSTR_GET" --kind "$k" --author "$user_hex" --limit 200 2>/dev/null | \
            jq -c --arg sk "$skill" \
                'select(.tags[]? | select(.[0] == "d" and .[1] == $sk))' 2>/dev/null)
        local count=0
        local seen_ids=()
        while IFS= read -r ev; do
            [[ -z "$ev" ]] && continue
            local eid; eid=$(echo "$ev" | jq -r '.id // empty' 2>/dev/null)
            [[ -z "$eid" ]] && continue
            # Dédupliquer
            local already=false
            for sid in "${seen_ids[@]}"; do [[ "$sid" == "$eid" ]] && { already=true; break; }; done
            if [[ "$already" == "false" ]]; then
                echo "$ev" >> "$export_file"; count=$((count + 1)); total=$((total + 1))
                seen_ids+=("$eid")
            fi
        done < <(printf '%s\n' "$refs" "$by_d" | grep -v '^$')
        exported_kinds[$k]=$count
    done

    # Kind 22/21 liés (craft portant le skill en tag t)
    for k in 22 21; do
        local events
        events=$(bash "$NOSTR_GET" --kind "$k" --author "$user_hex" --limit 200 2>/dev/null)
        local count=0
        while IFS= read -r ev; do
            [[ -z "$ev" ]] && continue
            local ev_t
            ev_t=$(echo "$ev" | jq -r ".tags[]? | select(.[0] == \"t\" and .[1] == \"$skill\") | .[1]" 2>/dev/null)
            if [[ -n "$ev_t" ]]; then
                echo "$ev" >> "$export_file"
                count=$((count + 1)); total=$((total + 1))
            fi
        done <<< "$events"
        exported_kinds[$k]=$count
    done

    # LIVE sessions Kind 30311 liées
    local lives
    lives=$(bash "$NOSTR_GET" --kind 30311 --author "$user_hex" --limit 100 2>/dev/null)
    local lcount=0
    while IFS= read -r ev; do
        [[ -z "$ev" ]] && continue
        local ev_t
        ev_t=$(echo "$ev" | jq -r ".tags[]? | select(.[0] == \"t\" and .[1] == \"$skill\") | .[1]" 2>/dev/null)
        if [[ -n "$ev_t" ]]; then
            echo "$ev" >> "$export_file"
            lcount=$((lcount + 1)); total=$((total + 1))
        fi
    done <<< "$lives"
    exported_kinds[30311]=$lcount

    # Résumé
    {
        echo "WoTx2 Skill Tree Export"
        echo "========================"
        echo "Skill       : $skill"
        echo "Auteur      : ${user_hex:0:20}…"
        echo "Date        : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Total       : $total événements"
        echo ""
        echo "Par kind:"
        for k in "${!exported_kinds[@]}"; do
            echo "  Kind $k (${KIND_LABEL[$k]:-?}): ${exported_kinds[$k]}"
        done
        echo ""
        echo "Fichier: $export_file"
    } > "$summary_file"

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${YELLOW}Export Skill Tree — Résumé${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Répertoire export :${NC} $export_dir"
    echo -e "${GREEN}Total exporté     :${NC} $total événements"
    echo ""
    for k in 30500 7 30501 30502 30503 30504 22 21 30311; do
        [[ -n "${exported_kinds[$k]}" ]] && \
            printf "  Kind %-5s %-42s %2d evt(s)\n" "$k" "(${KIND_LABEL[$k]:-?})" "${exported_kinds[$k]}"
    done
    echo ""
    echo -e "${CYAN}Fichiers :${NC}"
    echo -e "  📄 $export_file"
    echo -e "  📋 $summary_file"
    echo ""

    # Retourner le chemin pour delete_skill_tree
    echo "$export_dir"
}

################################################################################
# delete_skill_tree — supprimer l'arbre complet d'un skill
################################################################################
delete_skill_tree() {
    local user_hex="$1"
    local skill="$2"
    local force="${3:-false}"

    if ! check_local_pubkey "$user_hex"; then
        log_error "Suppression d'arbre réservée aux comptes MULTIPASS locaux."
        return 1
    fi

    echo ""
    echo -e "${RED}⚠️  SUPPRESSION COMPLÈTE DE L'ARBRE SKILL «$skill»${NC}"
    echo -e "${RED}Cela effacera TOUS les événements liés à ce skill :${NC}"
    echo -e "  • Permit (30500), Avis (Kind 7), Demandes (30501)"
    echo -e "  • Adoubements (30502), Certifications (30503)"
    echo -e "  • Ressources (30504), Crafts (22/21), LIVE (30311)"
    echo ""
    echo -e "${RED}⚠️  Cette opération est irréversible !${NC}"
    echo ""

    if [[ "$force" != "true" ]]; then
        read -rp "Tapez 'SUPPRIMER SKILL' pour confirmer : " confirm
        if [[ "$confirm" != "SUPPRIMER SKILL" ]]; then
            log_warning "Suppression annulée."
            return 1
        fi
    fi

    # Backup avant suppression
    log_info "Sauvegarde avant suppression…"
    local export_dir
    export_dir=$(export_skill_tree "$user_hex" "$skill" 2>/dev/null | tail -1)
    if [[ -z "$export_dir" ]] || [[ ! -d "$export_dir" ]]; then
        log_warning "Export de sauvegarde incomplet, mais on continue…"
    else
        log_success "Backup créé : $export_dir"
    fi

    # Récupérer permit event ID
    local permit_ev_id
    permit_ev_id=$(_get_permit_id "$user_hex" "$skill")

    # Collecter les event_ids à supprimer depuis l'export
    local -a ids_to_delete=()

    # Lire le fichier d'export (créé par export_skill_tree ci-dessus)
    local export_jsonl="${export_dir}/skill_tree_${skill}.jsonl"
    if [[ -f "$export_jsonl" ]]; then
        while IFS= read -r ev; do
            [[ -z "$ev" ]] && continue
            local eid; eid=$(echo "$ev" | jq -r '.id // empty' 2>/dev/null)
            [[ -n "$eid" ]] && ids_to_delete+=("$eid")
        done < "$export_jsonl"
    else
        log_warning "Fichier d'export introuvable — collecte directe…"
        # Fallback: collecter directement
        for k in 30500 30503 30504; do
            local events
            events=$(bash "$NOSTR_GET" --kind "$k" --author "$user_hex" --limit 500 2>/dev/null)
            while IFS= read -r ev; do
                [[ -z "$ev" ]] && continue
                local ev_d eid
                ev_d=$(echo "$ev" | jq -r '.tags[]? | select(.[0] == "d") | .[1]' 2>/dev/null | head -n1)
                [[ "$ev_d" == "$skill" ]] || continue
                eid=$(echo "$ev" | jq -r '.id // empty' 2>/dev/null)
                [[ -n "$eid" ]] && ids_to_delete+=("$eid")
            done <<< "$events"
        done
        local refs_raw
        refs_raw=$(_find_skill_refs "7 30501 30502" "$permit_ev_id" "$user_hex" "$skill" 500)
        while IFS= read -r ev; do
            [[ -z "$ev" ]] && continue
            local eid; eid=$(echo "$ev" | jq -r '.id // empty' 2>/dev/null)
            [[ -n "$eid" ]] && ids_to_delete+=("$eid")
        done <<< "$refs_raw"
    fi

    # Dédupliquer ids_to_delete
    local -a unique_ids=()
    declare -A seen_eid=()
    for eid in "${ids_to_delete[@]}"; do
        if [[ -z "${seen_eid[$eid]}" ]]; then
            unique_ids+=("$eid"); seen_eid["$eid"]=1
        fi
    done
    ids_to_delete=("${unique_ids[@]}")

    local total=${#ids_to_delete[@]}
    if [[ $total -eq 0 ]]; then
        log_warning "Aucun événement trouvé pour le skill «$skill»."; return 0
    fi

    log_info "Suppression de $total événements…"

    local ok5=0 fail5=0 ok_phy=0 fail_phy=0
    for eid in "${ids_to_delete[@]}"; do
        # Kind 5
        if delete_event_by_id "$eid" "$user_hex" "true" "kind5"; then
            ok5=$((ok5 + 1))
        else
            fail5=$((fail5 + 1))
        fi
        # Physique
        if delete_event_by_id "$eid" "$user_hex" "true" "physical"; then
            ok_phy=$((ok_phy + 1))
        else
            fail_phy=$((fail_phy + 1))
        fi
    done

    echo ""
    echo -e "${CYAN}══ Résumé suppression ══${NC}"
    echo -e "  Total traité  : $total"
    echo -e "  Kind 5 OK     : ${GREEN}$ok5${NC}  ${fail5:+Erreurs: ${RED}$fail5${NC}}"
    echo -e "  Physique OK   : ${GREEN}$ok_phy${NC}  ${fail_phy:+Erreurs: ${RED}$fail_phy${NC}}"
    echo ""
    [[ $ok_phy -eq $total ]] && log_success "🎉 Arbre skill «$skill» supprimé complètement!" \
        || log_warning "Suppression partielle — vérifier les erreurs."
}

################################################################################
# show_event_details — affichage détaillé d'un événement avec actions
################################################################################
show_event_details() {
    local event="$1"
    local user_hex="$2"

    while true; do
        clear
        local event_id kind author created_at content
        event_id=$(echo "$event"  | jq -r '.id // "?"' 2>/dev/null)
        kind=$(echo "$event"      | jq -r '.kind // "?"' 2>/dev/null)
        author=$(echo "$event"    | jq -r '.pubkey // "?"' 2>/dev/null)
        created_at=$(echo "$event"| jq -r '.created_at // 0' 2>/dev/null)
        content=$(echo "$event"   | jq -r '.content // ""' 2>/dev/null)
        local date; date=$(date -d "@$created_at" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$created_at")
        local label="${KIND_LABEL[$kind]:-Kind $kind}"

        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}              ${YELLOW}Détail Événement NOSTR — $label${NC}                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Kind    :${NC} $kind — $label"
        echo -e "${YELLOW}ID      :${NC} $event_id"
        echo -e "${YELLOW}Auteur  :${NC} ${author:0:20}…"
        echo -e "${YELLOW}Date    :${NC} $date"
        echo ""

        # Tags pertinents
        echo -e "${YELLOW}Tags :${NC}"
        echo "$event" | jq -r '.tags[]? | "  [" + .[0] + "] " + (.[1:] | join(" "))' 2>/dev/null
        echo ""

        if [[ -n "$content" ]]; then
            echo -e "${YELLOW}Contenu :${NC}"
            echo "$content" | fold -w 78 -s | sed 's/^/  /'
            echo ""
        fi

        # Liens IPFS si présents
        local url; url=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "url") | .[1]' 2>/dev/null | head -n1)
        local thumb; thumb=$(echo "$event" | jq -r '.tags[]? | select(.[0] == "thumbnail") | .[1]' 2>/dev/null | head -n1)
        [[ -n "$url" ]]   && echo -e "${GREEN}URL     :${NC} $url"
        [[ -n "$thumb" ]] && echo -e "${GREEN}Thumb   :${NC} $thumb"
        [[ -n "$url" || -n "$thumb" ]] && echo ""

        local is_local=false
        check_local_pubkey "$author" && is_local=true

        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${YELLOW}1.${NC} 📋 Copier l'ID dans le presse-papier"
        echo -e "  ${YELLOW}2.${NC} 📄 Voir le JSON brut"
        if [[ "$is_local" == "true" ]]; then
            echo -e "  ${YELLOW}3.${NC} 🗑️  Supprimer (Kind 5 — NIP-09)"
            echo -e "  ${YELLOW}4.${NC} ⚠️  Supprimer physiquement du relay"
            echo -e "  ${YELLOW}5.${NC} 💥 Supprimer complètement (Kind5 + physique)"
        fi
        echo -e "  ${YELLOW}b.${NC} 🔙 Retour"
        echo -e "  ${YELLOW}0.${NC} 🚪 Quitter"
        echo ""

        read -rp "Action : " action
        case "$action" in
            1)
                echo "$event_id" | xclip -selection clipboard 2>/dev/null \
                    || echo "$event_id"
                log_success "ID copié: ${event_id:0:20}…"
                sleep 1
                ;;
            2)
                echo ""
                echo "$event" | jq '.' 2>/dev/null || echo "$event"
                echo ""
                read -rp "Appuyez sur ENTRÉE pour continuer…"
                ;;
            3)
                if [[ "$is_local" == "true" ]]; then
                    read -rp "Supprimer via Kind 5 ? (yes/NO): " c
                    if [[ "$c" == "yes" ]]; then
                        delete_event_by_id "$event_id" "$author" "true" "kind5" && return 0
                    fi
                fi
                ;;
            4)
                if [[ "$is_local" == "true" ]]; then
                    read -rp "Supprimer physiquement ? (yes/NO): " c
                    if [[ "$c" == "yes" ]]; then
                        delete_event_by_id "$event_id" "$author" "true" "physical" && return 0
                    fi
                fi
                ;;
            5)
                if [[ "$is_local" == "true" ]]; then
                    read -rp "Suppression complète (Kind5 + physique) ? (yes/NO): " c
                    if [[ "$c" == "yes" ]]; then
                        delete_event_by_id "$event_id" "$author" "true" "both" && return 0
                    fi
                fi
                ;;
            b) return 0 ;;
            0) clear; exit 0 ;;
        esac
    done
}

################################################################################
# browse_kind_events — naviguer dans les événements d'un kind pour un utilisateur
################################################################################
browse_kind_events() {
    local user_hex="$1"
    local kind="$2"
    local per_page=6
    local current_page=0
    local needs_reload=true
    local -a event_ids=()
    local -A event_data=()

    load_events() {
        event_ids=(); event_data=()
        local raw
        raw=$(bash "$NOSTR_GET" --kind "$kind" --author "$user_hex" --limit 500 2>/dev/null)
        [[ -z "$raw" ]] && return 1
        while IFS= read -r ev; do
            [[ -z "$ev" ]] && continue
            local eid; eid=$(echo "$ev" | jq -r '.id // empty' 2>/dev/null)
            [[ -z "$eid" ]] && continue
            event_ids+=("$eid"); event_data["$eid"]="$ev"
        done <<< "$raw"
        return 0
    }

    while true; do
        if [[ "$needs_reload" == "true" ]]; then
            load_events || { log_warning "Aucun événement."; read -rp "ENTRÉE…"; return 0; }
            needs_reload=false
            local total_pages=$(( (${#event_ids[@]} + per_page - 1) / per_page ))
            [[ $current_page -ge $total_pages ]] && current_page=0
        fi

        local total_ev=${#event_ids[@]}
        local total_pages=$(( (total_ev + per_page - 1) / per_page ))
        clear
        local label="${KIND_LABEL[$kind]:-Kind $kind}"
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}Kind $kind — $label${NC}  (page $((current_page+1))/$total_pages, $total_ev evt)  ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        local start_idx=$((current_page * per_page))
        local end_idx=$((start_idx + per_page))
        [[ $end_idx -gt $total_ev ]] && end_idx=$total_ev

        local disp=1
        for ((i=start_idx; i<end_idx; i++)); do
            local eid="${event_ids[$i]}"
            local ev="${event_data[$eid]}"
            local skill created_at
            skill=$(echo "$ev" | jq -r '
                (.tags[]? | select(.[0] == "d") | .[1]) //
                (.tags[]? | select(.[0] == "t") | .[1]) //
                "—"
            ' 2>/dev/null | head -n1)
            created_at=$(echo "$ev" | jq -r '.created_at // 0' 2>/dev/null)
            local date; date=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")
            local snippet; snippet=$(echo "$ev" | jq -r '.content // ""' 2>/dev/null | head -c 50 | tr '\n' ' ')

            echo -e "  ${YELLOW}$disp.${NC} ${GREEN}${eid:0:12}…${NC} ${CYAN}[${skill:0:18}]${NC} $date  ${snippet:0:45}"
            disp=$((disp + 1))
        done
        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        [[ $current_page -gt 0 ]] && echo -e "  ${YELLOW}p${NC} ⬅ Page précédente"
        [[ $current_page -lt $((total_pages-1)) ]] && echo -e "  ${YELLOW}n${NC} ➡ Page suivante"
        echo -e "  ${YELLOW}1-$per_page${NC} Voir le détail"
        echo -e "  ${YELLOW}b${NC} 🔙 Retour   ${YELLOW}0${NC} 🚪 Quitter"
        echo ""
        read -rp "Action : " act

        case "$act" in
            p) [[ $current_page -gt 0 ]] && current_page=$((current_page - 1)) ;;
            n) [[ $current_page -lt $((total_pages-1)) ]] && current_page=$((current_page + 1)) ;;
            b) return 0 ;;
            0) clear; exit 0 ;;
            [1-9])
                local idx=$((start_idx + act - 1))
                if [[ $idx -ge $start_idx && $idx -lt $end_idx ]]; then
                    local sel_eid="${event_ids[$idx]}"
                    show_event_details "${event_data[$sel_eid]}" "$user_hex"
                    needs_reload=true
                fi
                ;;
        esac
    done
}

################################################################################
# cmd_browse — navigateur interactif principal
################################################################################
cmd_browse() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}               ${YELLOW}WoTx2 / Grimoire — Navigateur Interactif${NC}               ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Lister les MULTIPASS locaux
        local nostr_base="${HOME}/.zen/game/nostr"
        local -a local_accounts=()
        local -A account_hex=()

        if [[ -d "$nostr_base" ]]; then
            for email_dir in "$nostr_base"/*; do
                [[ -d "$email_dir" ]] || continue
                local hf="${email_dir}/HEX"
                [[ -f "$hf" ]] || continue
                local h; h=$(tr -d '\n\r ' < "$hf")
                local em; em=$(basename "$email_dir")
                local_accounts+=("$em")
                account_hex["$em"]="$h"
            done
        fi

        echo -e "${YELLOW}MULTIPASS locaux :${NC}"
        local idx=1
        for em in "${local_accounts[@]}"; do
            local h="${account_hex[$em]}"
            local nb
            nb=$(bash "$NOSTR_GET" --kind 30500 --author "$h" --limit 1000 --output count 2>/dev/null)
            nb=${nb:-0}
            echo -e "  ${YELLOW}$idx.${NC} ${CYAN}$em${NC}  (${GREEN}$nb${NC} permits)"
            idx=$((idx + 1))
        done

        echo ""
        echo -e "${YELLOW}Global :${NC}"
        echo -e "  ${YELLOW}a.${NC} 📊 Statistiques globales"
        echo -e "  ${YELLOW}b.${NC} 🌐 Tous les événements WoTx2 (list-all)"
        echo -e "  ${YELLOW}c.${NC} 🧹 Nettoyage (cleanup)"
        echo -e "  ${YELLOW}d.${NC} 🎭 Comptes de démonstration (~/.zen/demo/)"
        echo -e "  ${YELLOW}0.${NC} 🚪 Quitter"
        echo ""
        read -rp "Sélection : " choice

        case "$choice" in
            [0-9]*)
                if [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#local_accounts[@]} ]]; then
                    local sel_email="${local_accounts[$((choice-1))]}"
                    USER_HEX="${account_hex[$sel_email]}"
                    cmd_user
                elif [[ "$choice" == "0" ]]; then
                    clear; return 0
                fi
                ;;
            a) cmd_stats ;;
            b) cmd_list_all; read -rp "ENTRÉE…" ;;
            c) cmd_cleanup ;;
            d) cmd_demo ;;
        esac
    done
}

################################################################################
# cmd_user — administration interactive d'un MULTIPASS
################################################################################
cmd_user() {
    local user_hex="${USER_HEX:-}"
    [[ -z "$user_hex" ]] && { log_error "Fournir --hex, --npub ou --email"; return 1; }

    local is_local=false
    check_local_pubkey "$user_hex" && is_local=true

    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        local loc_label="${YELLOW}DISTANT${NC}"
        [[ "$is_local" == "true" ]] && loc_label="${GREEN}LOCAL${NC}"
        echo -e "${CYAN}║${NC}  Administration MULTIPASS [$loc_label]  ${user_hex:0:24}…  ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Stats rapides
        local permits certs crafts lives
        permits=$(bash "$NOSTR_GET" --kind 30500 --author "$user_hex" --limit 200 --output count 2>/dev/null)
        certs=$(bash "$NOSTR_GET" --kind 30503 --author "$user_hex" --limit 200 --output count 2>/dev/null)
        crafts=$(bash "$NOSTR_GET" --kind 22 --author "$user_hex" --limit 200 --output count 2>/dev/null)
        lives=$(bash "$NOSTR_GET" --kind 30311 --author "$user_hex" --limit 100 --output count 2>/dev/null)
        printf "  Permits:${GREEN}%2d${NC}  Certs:${GREEN}%2d${NC}  Crafts:${GREEN}%2d${NC}  LIVE:${GREEN}%2d${NC}\n" \
            "${permits:-0}" "${certs:-0}" "${crafts:-0}" "${lives:-0}"
        echo ""

        echo -e "  ${YELLOW}1.${NC} 📋 Lister tous les événements"
        echo -e "  ${YELLOW}2.${NC} 🔍 Naviguer par kind"
        echo -e "  ${YELLOW}3.${NC} ✅ Audit de complétude WoTx2"
        echo -e "  ${YELLOW}4.${NC} 📤 Exporter un skill (arbre complet)"
        if [[ "$is_local" == "true" ]]; then
            echo -e "  ${YELLOW}5.${NC} 🏅 Certifier un skill (Règle A/B)"
            echo -e "  ${YELLOW}6.${NC} 🗑️  Supprimer l'arbre d'un skill"
            echo -e "  ${YELLOW}7.${NC} 📦 Exporter tous les événements (.jsonl)"
        fi
        echo -e "  ${YELLOW}b.${NC} 🔙 Retour"
        echo -e "  ${YELLOW}0.${NC} 🚪 Quitter"
        echo ""
        read -rp "Action : " act

        case "$act" in
            1) cmd_list; read -rp "ENTRÉE…" ;;
            2)
                echo ""
                echo -e "${YELLOW}Naviguer quel kind ?${NC}"
                local kidx=1
                for k in $WOTX2_KINDS; do
                    echo -e "  ${YELLOW}$kidx.${NC} Kind $k — ${KIND_LABEL[$k]:-?}"
                    kidx=$((kidx + 1))
                done
                echo ""
                read -rp "Numéro : " knum
                local karr=($WOTX2_KINDS)
                local sel_kind="${karr[$((knum-1))]}"
                if [[ -n "$sel_kind" ]]; then
                    browse_kind_events "$user_hex" "$sel_kind"
                fi
                ;;
            3) cmd_check; read -rp "ENTRÉE…" ;;
            4)
                read -rp "Skill à exporter : " sk
                [[ -n "$sk" ]] && export_skill_tree "$user_hex" "$sk"
                read -rp "ENTRÉE…"
                ;;
            5)
                if [[ "$is_local" == "true" ]]; then
                    read -rp "Skill à certifier : " sk
                    [[ -n "$sk" ]] && { SKILL="$sk"; cmd_certify; }
                    read -rp "ENTRÉE…"
                fi
                ;;
            6)
                if [[ "$is_local" == "true" ]]; then
                    read -rp "Skill à supprimer (arbre complet) : " sk
                    if [[ -n "$sk" ]]; then
                        delete_skill_tree "$user_hex" "$sk" "false"
                    fi
                    read -rp "ENTRÉE…"
                fi
                ;;
            7)
                if [[ "$is_local" == "true" ]]; then
                    local exp_file="${HOME}/.zen/tmp/wotx2_export_all_${user_hex:0:8}_$(date +%Y%m%d_%H%M%S).jsonl"
                    log_info "Export de tous les événements → $exp_file"
                    for k in $WOTX2_KINDS; do
                        bash "$NOSTR_GET" --kind "$k" --author "$user_hex" --limit 1000 2>/dev/null >> "$exp_file"
                    done
                    local lc; lc=$(wc -l < "$exp_file")
                    log_success "Exporté: $lc événements → $exp_file"
                    read -rp "ENTRÉE…"
                fi
                ;;
            b) return 0 ;;
            0) clear; exit 0 ;;
        esac
    done
}

################################################################################
# cmd_certify — vérifier Règle A/B et publier Kind 30503
################################################################################
cmd_certify() {
    local user_hex="${USER_HEX:-}"
    local skill="${SKILL:-}"
    [[ -z "$user_hex" ]] && { log_error "Fournir --hex, --npub ou --email"; return 1; }
    [[ -z "$skill" ]]    && { read -rp "Skill à certifier : " skill; }

    if ! check_local_pubkey "$user_hex"; then
        log_error "La certification ne peut être publiée que pour des comptes MULTIPASS locaux."
        return 1
    fi

    local secret_file
    secret_file=$(find_secret_file_by_hex "$user_hex")
    if [[ -z "$secret_file" ]]; then
        log_error "Fichier .secret.nostr introuvable."
        return 1
    fi

    echo ""
    log_info "Vérification des conditions de certification pour skill «$skill»…"

    # Récupérer l'ID du permit Kind 30500 pour ce skill
    local permit_ev_id
    permit_ev_id=$(_get_permit_id "$user_hex" "$skill")
    if [[ -z "$permit_ev_id" ]]; then
        log_warning "Permit Kind 30500 introuvable pour «$skill» (utilisateur: ${user_hex:0:16}…)"
    else
        log_debug "Permit event ID: ${permit_ev_id:0:16}…"
    fi

    # Règle A : 3 avis positifs distincts (styles e-tag et a-tag)
    local votes_raw
    votes_raw=$(_find_skill_refs "7" "$permit_ev_id" "$user_hex" "$skill" 100)
    local votes_pos=0
    local -A voters_seen=()
    while IFS= read -r v; do
        [[ -z "$v" ]] && continue
        local vpub vcontent
        vpub=$(echo "$v" | jq -r '.pubkey' 2>/dev/null)
        vcontent=$(echo "$v" | jq -r '.content' 2>/dev/null)
        if [[ "$vpub" != "$user_hex" ]] && [[ "$vcontent" =~ ^\+ ]] && [[ -z "${voters_seen[$vpub]}" ]]; then
            voters_seen["$vpub"]=1
            votes_pos=$((votes_pos + 1))
        fi
    done <<< "$votes_raw"

    # Règle B : 1 adoubement d'un pair certifié (styles e-tag et a-tag)
    local ado_events
    ado_events=$(_find_skill_refs "30502" "$permit_ev_id" "$user_hex" "$skill" 10)
    local ado_count=0
    [[ -n "$ado_events" ]] && ado_count=$(printf '%s\n' "$ado_events" | grep -c '"id"' 2>/dev/null || echo 0)

    local regle_a="❌ ($votes_pos/3)"; [[ $votes_pos -ge 3 ]] && regle_a="✅ ($votes_pos avis +)"
    local regle_b="❌ (0 adoubement)"; [[ $ado_count -ge 1 ]] && regle_b="✅ ($ado_count adoubement(s))"

    # Vérifier si déjà certifié
    local existing_cert
    existing_cert=$(bash "$NOSTR_GET" --kind 30503 --author "$user_hex" --limit 20 2>/dev/null | \
        jq -r --arg sk "$skill" 'select(.tags[]? | select(.[0] == "d" and .[1] == $sk)) | .id' 2>/dev/null | head -n1)

    echo ""
    echo -e "${CYAN}── Résultat audit pour «$skill» ──${NC}"
    echo -e "  Règle A (3 avis +) : $regle_a"
    echo -e "  Règle B (adoubt)   : $regle_b"
    [[ -n "$existing_cert" ]] && echo -e "  ${GREEN}⚠️  Déjà certifié (Kind 30503: ${existing_cert:0:12}…)${NC}"
    echo ""

    if [[ $votes_pos -lt 3 && $ado_count -lt 1 ]]; then
        log_warning "Aucune règle satisfaite. Certification impossible."
        return 1
    fi

    if [[ -n "$existing_cert" ]]; then
        read -rp "Déjà certifié — Forcer une nouvelle certification ? (yes/NO): " c
        [[ "$c" != "yes" ]] && { log_warning "Annulé."; return 0; }
    fi

    local rule="A"
    [[ $ado_count -ge 1 ]] && rule="B"
    [[ $votes_pos -ge 3 && $ado_count -ge 1 ]] && rule="A+B"

    echo ""
    read -rp "Publier la certification Kind 30503 pour «$skill» (Règle $rule) ? (yes/NO): " confirm
    [[ "$confirm" != "yes" ]] && { log_warning "Annulé."; return 0; }

    # Construire les tags pour Kind 30503
    local aref="30500:${user_hex}:${skill}"
    local tags_json
    tags_json=$(jq -nc \
        --arg d "$skill" \
        --arg a "$aref" \
        --arg rule "$rule" \
        '[ ["d",$d], ["a",$a], ["t","WoTx2"], ["t","certification"], ["rule",$rule] ]')

    local content="Certification WoTx2 du skill «$skill» — Règle $rule. $(date '+%Y-%m-%d')"

    log_info "Publication de la Kind 30503…"
    local result
    result=$(python3 "$NOSTR_SEND" \
        --keyfile "$secret_file" \
        --content "$content" \
        --kind 30503 \
        --tags "$tags_json" \
        --json 2>&1)

    if echo "$result" | jq -e '.success == true' &>/dev/null; then
        local new_id; new_id=$(echo "$result" | jq -r '.event_id // "?"' 2>/dev/null)
        log_success "🏅 Certification publiée ! Event: ${new_id:0:16}…"
    else
        log_error "Échec publication Kind 30503."
        log_debug "Résultat: $result"
        return 1
    fi
}

################################################################################
# cmd_cleanup — nettoyer les événements invalides / orphelins
################################################################################
cmd_cleanup() {
    log_info "Scan des événements WoTx2 non conformes…"
    echo ""

    local -a orphan_ids=()    # événements sans permit parent (30501/30502/30503 sans 30500)
    local -a invalid_ids=()   # auteur invalide
    local -a invalid_events=()

    for kind in 30501 30502 30503 30504; do
        local events
        events=$(bash "$NOSTR_GET" --kind "$kind" --limit 2000 2>/dev/null)
        [[ -z "$events" ]] && continue

        while IFS= read -r ev; do
            [[ -z "$ev" ]] && continue
            local eid author
            eid=$(echo "$ev" | jq -r '.id // empty' 2>/dev/null); [[ -z "$eid" ]] && continue
            author=$(echo "$ev" | jq -r '.pubkey // ""' 2>/dev/null)

            # Auteur invalide
            if [[ ${#author} -ne 64 ]] || ! [[ "$author" =~ ^[0-9a-f]{64}$ ]]; then
                invalid_ids+=("$eid"); invalid_events+=("$ev")
                continue
            fi

            # Vérifier qu'un Kind 30500 parent existe
            local aref; aref=$(echo "$ev" | jq -r '.tags[]? | select(.[0] == "a" and (.[1] | startswith("30500:"))) | .[1]' 2>/dev/null | head -n1)
            if [[ -n "$aref" ]]; then
                local permit_author; permit_author=$(echo "$aref" | cut -d: -f2)
                local permit_skill; permit_skill=$(echo "$aref" | cut -d: -f3)
                local permit_count
                permit_count=$(bash "$NOSTR_GET" --kind 30500 --author "$permit_author" --limit 1 --output count 2>/dev/null)
                permit_count=${permit_count:-0}
                if [[ $permit_count -eq 0 ]]; then
                    orphan_ids+=("$eid")
                fi
            fi
        done <<< "$events"
    done

    local total_inv=${#invalid_ids[@]}
    local total_orp=${#orphan_ids[@]}

    if [[ $((total_inv + total_orp)) -eq 0 ]]; then
        log_success "✅ Tous les événements WoTx2 sont conformes!"
        return 0
    fi

    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${YELLOW}Événements non conformes${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    [[ $total_inv -gt 0 ]] && echo -e "  ${RED}Auteur invalide :${NC} $total_inv événement(s) → à supprimer"
    [[ $total_orp -gt 0 ]] && echo -e "  ${YELLOW}Orphelins (sans Permit parent) :${NC} $total_orp événement(s)"
    echo ""

    if [[ "$FORCE" != "true" ]]; then
        echo -e "  ${YELLOW}1.${NC} Supprimer les événements à auteur invalide ($total_inv)"
        [[ $total_orp -gt 0 ]] && echo -e "  ${YELLOW}2.${NC} Supprimer les événements orphelins ($total_orp)"
        echo -e "  ${YELLOW}0.${NC} Annuler"
        echo ""
        read -rp "Choix : " choice
    else
        choice=1
    fi

    case "$choice" in
        1)
            [[ $total_inv -eq 0 ]] && { log_warning "Aucun événement à auteur invalide."; return 0; }
            echo ""
            read -rp "Confirmer la suppression de $total_inv événement(s) invalide(s) ? (DELETE/NON): " c
            [[ "$c" != "DELETE" ]] && { log_warning "Annulé."; return 0; }
            if [[ ! -f "$STRFRY_BIN" ]]; then log_error "strfry introuvable."; return 1; fi
            local succ=0 fail=0
            cd "$STRFRY_DIR" || return 1
            for eid in "${invalid_ids[@]}"; do
                local ids_json; ids_json=$(printf '%s' "$eid" | jq -Rs '{ids: [.]}')
                if ./strfry delete --filter="$ids_json" &>/dev/null; then
                    succ=$((succ + 1))
                else
                    fail=$((fail + 1))
                fi
            done
            cd - >/dev/null 2>&1
            log_success "Supprimés: $succ  Erreurs: $fail"
            ;;
        2)
            [[ $total_orp -eq 0 ]] && { log_warning "Aucun orphelin trouvé."; return 0; }
            echo ""
            read -rp "Confirmer la suppression de $total_orp orphelin(s) ? (DELETE/NON): " c
            [[ "$c" != "DELETE" ]] && { log_warning "Annulé."; return 0; }
            if [[ ! -f "$STRFRY_BIN" ]]; then log_error "strfry introuvable."; return 1; fi
            local succ=0 fail=0
            cd "$STRFRY_DIR" || return 1
            for eid in "${orphan_ids[@]}"; do
                local ids_json; ids_json=$(printf '%s' "$eid" | jq -Rs '{ids: [.]}')
                if ./strfry delete --filter="$ids_json" &>/dev/null; then
                    succ=$((succ + 1))
                else
                    fail=$((fail + 1))
                fi
            done
            cd - >/dev/null 2>&1
            log_success "Orphelins supprimés: $succ  Erreurs: $fail"
            ;;
        0) log_warning "Annulé." ;;
    esac
}

################################################################################
# cmd_republish — ré-injecter les événements d'un kind dans le relay
################################################################################
cmd_republish() {
    local kind="${REPUBLISH_KIND:-${1:-}}"
    [[ -z "$kind" ]] && { log_error "Fournir un kind en argument ou --kind"; return 1; }
    local label="${KIND_LABEL[$kind]:-Kind $kind}"
    local limit="${LIMIT:-5000}"

    local tmpfile; tmpfile=$(mktemp /tmp/wotx2_export_XXXX.jsonl)

    log_info "Export Kind $kind ($label) → $tmpfile"
    bash "$NOSTR_GET" --kind "$kind" --limit "$limit" 2>/dev/null > "$tmpfile"

    local count; count=$(wc -l < "$tmpfile")
    log_info "$count événements exportés"

    if [[ "$count" -eq 0 ]]; then
        log_warning "Rien à republier."
        rm -f "$tmpfile"
        return 0
    fi

    if [[ "$FORCE" != "true" ]]; then
        read -rp "[PROMPT] Ré-injecter $count événements dans strfry ? (yes/NO): " confirm
        [[ "$confirm" != "yes" ]] && { log_warning "Annulé."; rm -f "$tmpfile"; return 0; }
    fi

    if [[ ! -f "$STRFRY_BIN" ]]; then
        log_error "strfry introuvable: $STRFRY_BIN"
        rm -f "$tmpfile"
        return 1
    fi

    cd "$STRFRY_DIR" || { rm -f "$tmpfile"; return 1; }
    ./strfry import < "$tmpfile" && log_success "Ré-injection terminée."
    cd - >/dev/null 2>&1
    rm -f "$tmpfile"
}

################################################################################
# cmd_export_skill — wrapper CLI pour export_skill_tree
################################################################################
cmd_export_skill() {
    local user_hex="${USER_HEX:-}"
    local skill="${SKILL:-}"
    [[ -z "$user_hex" ]] && { log_error "Fournir --hex, --npub ou --email"; return 1; }
    [[ -z "$skill" ]]    && { read -rp "Skill à exporter : " skill; }
    export_skill_tree "$user_hex" "$skill"
}

################################################################################
# cmd_delete_skill — wrapper CLI pour delete_skill_tree
################################################################################
cmd_delete_skill() {
    local user_hex="${USER_HEX:-}"
    local skill="${SKILL:-}"
    [[ -z "$user_hex" ]] && { log_error "Fournir --hex, --npub ou --email"; return 1; }
    [[ -z "$skill" ]]    && { read -rp "Skill à supprimer : " skill; }
    delete_skill_tree "$user_hex" "$skill" "$FORCE"
}

################################################################################
# cmd_demo — gérer les comptes de démonstration (~/.zen/demo/*.keys)
################################################################################
cmd_demo() {
    local DEMO_DIR="${HOME}/.zen/demo"

    if [[ ! -d "$DEMO_DIR" ]]; then
        log_warning "Répertoire démo introuvable: $DEMO_DIR"
        log_info "Créez les comptes démo via: ./install.sh (section COMPTES DÉMO)"
        return 1
    fi

    # Charger tous les comptes démo disponibles
    local -a demo_names=()
    local -A demo_nsec demo_npub demo_email demo_hex

    for keys_file in "$DEMO_DIR"/*.keys; do
        [[ -f "$keys_file" ]] || continue
        local dname; dname=$(basename "$keys_file" .keys)
        local d_nsec d_npub d_email d_hex
        d_nsec=$(grep "^NSEC=" "$keys_file" 2>/dev/null | cut -d= -f2)
        d_npub=$(grep "^NPUB=" "$keys_file" 2>/dev/null | cut -d= -f2)
        d_email=$(grep "^EMAIL=" "$keys_file" 2>/dev/null | cut -d= -f2)
        [[ -z "$d_npub" ]] && continue
        # Convertir npub → hex
        d_hex=$(python3 -c "
from nostr.key import PublicKey
print(PublicKey.from_npub('$d_npub').hex())
" 2>/dev/null)
        [[ -z "$d_hex" ]] && continue
        demo_names+=("$dname")
        demo_nsec["$dname"]="$d_nsec"
        demo_npub["$dname"]="$d_npub"
        demo_email["$dname"]="$d_email"
        demo_hex["$dname"]="$d_hex"
    done

    if [[ ${#demo_names[@]} -eq 0 ]]; then
        log_warning "Aucun fichier *.keys dans $DEMO_DIR"
        return 1
    fi

    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}              ${MAGENTA}Comptes de Démonstration WoTx2${NC} — ~/.zen/demo/             ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Afficher l'état de chaque compte démo
        local idx=1
        local -A demo_totals
        for dname in "${demo_names[@]}"; do
            local hex="${demo_hex[$dname]}"
            local email="${demo_email[$dname]}"
            local total=0
            local counts=""
            for kind in $WOTX2_KINDS 0; do
                local c
                c=$(bash "$NOSTR_GET" --kind "$kind" --author "$hex" --limit 1000 --output count 2>/dev/null)
                c=${c:-0}
                total=$((total + c))
                [[ $c -gt 0 ]] && counts+=" K${kind}:${c}"
            done
            demo_totals["$dname"]=$total
            local total_color="$YELLOW"; [[ $total -gt 0 ]] && total_color="$GREEN"
            printf "  ${YELLOW}%d.${NC} ${MAGENTA}%-8s${NC}  <%s>\n" "$idx" "$dname" "$email"
            printf "      npub : %s…\n" "${demo_npub[$dname]:0:32}"
            printf "      hex  : %s…\n" "${hex:0:24}"
            if [[ $total -gt 0 ]]; then
                printf "      evts : ${total_color}%d${NC} [%s ]\n" "$total" "$counts"
            else
                printf "      evts : ${BLUE}0${NC} (relay vierge)\n"
            fi
            echo ""
            idx=$((idx + 1))
        done

        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${YELLOW}1-${#demo_names[@]}.${NC}  Gérer un compte démo"
        echo -e "  ${YELLOW}a.${NC}   Réinitialiser TOUS les comptes démo (supprimer tous leurs événements)"
        echo -e "  ${YELLOW}w.${NC}   Effacer TOUS les comptes démo (événements + fichiers .keys)"
        echo -e "  ${YELLOW}b.${NC}   Retour   ${YELLOW}0.${NC} Quitter"
        echo ""
        read -rp "Action : " action

        case "$action" in
            [1-9])
                local sel_name="${demo_names[$((action-1))]}"
                if [[ -n "$sel_name" ]]; then
                    _demo_manage_one "$sel_name" \
                        "${demo_hex[$sel_name]}" \
                        "${demo_nsec[$sel_name]}" \
                        "${demo_email[$sel_name]}" \
                        "$DEMO_DIR/${sel_name}.keys"
                fi
                ;;
            a)
                echo ""
                echo -e "${RED}⚠️  Réinitialisation de TOUS les comptes démo.${NC}"
                echo -e "Tous leurs événements seront supprimés physiquement du relay."
                read -rp "Confirmer ? (RESET/NON): " c
                if [[ "$c" == "RESET" ]]; then
                    for dname in "${demo_names[@]}"; do
                        log_info "Réinitialisation de $dname…"
                        _demo_wipe_events "${demo_hex[$dname]}" "$dname"
                    done
                    log_success "Tous les comptes démo réinitialisés."
                    read -rp "ENTRÉE…"
                fi
                ;;
            w)
                echo ""
                echo -e "${RED}⚠️  SUPPRESSION TOTALE : événements + fichiers .keys${NC}"
                echo -e "Les comptes démo devront être recréés via ./install.sh"
                read -rp "Confirmer ? (WIPE/NON): " c
                if [[ "$c" == "WIPE" ]]; then
                    for dname in "${demo_names[@]}"; do
                        log_info "Suppression de $dname…"
                        _demo_wipe_events "${demo_hex[$dname]}" "$dname"
                        rm -f "$DEMO_DIR/${dname}.keys"
                        log_success "Fichier $dname.keys supprimé."
                    done
                    log_success "Tous les comptes démo effacés."
                    read -rp "ENTRÉE…"
                    return 0
                fi
                ;;
            b) return 0 ;;
            0) clear; exit 0 ;;
        esac
    done
}

# Supprimer physiquement tous les événements d'un compte démo du relay
_demo_wipe_events() {
    local hex="$1"
    local dname="$2"

    if [[ ! -f "$STRFRY_BIN" ]]; then
        log_error "strfry introuvable: $STRFRY_BIN"; return 1
    fi

    local total=0 errs=0
    for kind in $WOTX2_KINDS 0 1 3; do
        local events
        events=$(bash "$NOSTR_GET" --kind "$kind" --author "$hex" --limit 5000 2>/dev/null)
        [[ -z "$events" ]] && continue
        while IFS= read -r ev; do
            [[ -z "$ev" ]] && continue
            local eid; eid=$(echo "$ev" | jq -r '.id // empty' 2>/dev/null)
            [[ -z "$eid" ]] && continue
            local ids_json; ids_json=$(printf '%s' "$eid" | jq -Rs '{ids: [.]}')
            cd "$STRFRY_DIR" || return 1
            if ./strfry delete --filter="$ids_json" &>/dev/null; then
                total=$((total + 1))
            else
                errs=$((errs + 1))
            fi
            cd - >/dev/null 2>&1
        done <<< "$events"
    done

    log_success "$dname : $total événement(s) supprimé(s)${errs:+, $errs erreur(s)}"
}

# Gérer un compte démo individuel
_demo_manage_one() {
    local dname="$1"
    local hex="$2"
    local nsec="$3"
    local email="$4"
    local keys_file="$5"

    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}          ${MAGENTA}Compte Démo : $dname${NC}                                          ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Email  :${NC} $email"
        echo -e "${YELLOW}Hex    :${NC} ${hex:0:32}…"
        echo -e "${YELLOW}Fichier:${NC} $keys_file"
        echo ""

        # Compter les événements par kind
        local total=0
        for kind in $WOTX2_KINDS 0; do
            local c
            c=$(bash "$NOSTR_GET" --kind "$kind" --author "$hex" --limit 1000 --output count 2>/dev/null)
            c=${c:-0}
            if [[ $c -gt 0 ]]; then
                printf "  Kind %-5s %-40s ${GREEN}%3d${NC}\n" "$kind" "(${KIND_LABEL[$kind]:-?})" "$c"
                total=$((total + c))
            fi
        done
        [[ $total -eq 0 ]] && echo -e "  ${BLUE}Aucun événement WoTx2 pour ce compte.${NC}"
        echo ""
        echo -e "  Total : ${GREEN}$total${NC} événement(s)"
        echo ""

        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${YELLOW}1.${NC} 🗑️  Supprimer tous les événements de ce compte (physique)"
        echo -e "  ${YELLOW}2.${NC} 📋 Lister les événements (cmd list)"
        echo -e "  ${YELLOW}3.${NC} 💥 Supprimer événements ET fichier .keys"
        echo -e "  ${YELLOW}b.${NC} 🔙 Retour"
        echo ""
        read -rp "Action : " act

        case "$act" in
            1)
                echo ""
                echo -e "${RED}⚠️  Suppression de TOUS les événements de $dname depuis le relay.${NC}"
                read -rp "Confirmer ? (yes/NO): " c
                if [[ "$c" == "yes" ]]; then
                    _demo_wipe_events "$hex" "$dname"
                    read -rp "ENTRÉE…"
                fi
                ;;
            2)
                USER_HEX="$hex"
                cmd_list
                read -rp "ENTRÉE…"
                ;;
            3)
                echo ""
                echo -e "${RED}⚠️  Suppression événements + fichier $dname.keys${NC}"
                echo -e "${RED}Le compte devra être recréé via ./install.sh${NC}"
                read -rp "Confirmer ? (WIPE/NON): " c
                if [[ "$c" == "WIPE" ]]; then
                    _demo_wipe_events "$hex" "$dname"
                    rm -f "$keys_file"
                    log_success "Fichier $keys_file supprimé."
                    read -rp "ENTRÉE…"
                    return 0
                fi
                ;;
            b) return 0 ;;
        esac
    done
}

################################################################################
# Main
################################################################################
main() {
    local COMMAND="${1:-stats}"; shift || true

    # Options globales
    USER_HEX=""
    NPUB=""
    EMAIL=""
    SKILL=""
    KIND=""
    LIMIT=100
    FORCE=false
    VERBOSE=false
    REPUBLISH_KIND=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --npub)    NPUB="$2";    shift 2 ;;
            --hex)     USER_HEX="$2"; shift 2 ;;
            --email)   EMAIL="$2";   shift 2 ;;
            --skill)   SKILL="$2";   shift 2 ;;
            --kind)    KIND="$2";    shift 2 ;;
            --limit)   LIMIT="$2";   shift 2 ;;
            --since)   SINCE="$2";   shift 2 ;;
            --until)   UNTIL="$2";   shift 2 ;;
            --force)   FORCE=true;   shift   ;;
            --verbose) VERBOSE=true; shift   ;;
            -h|--help) usage ;;
            *) log_error "Option inconnue: $1"; usage ;;
        esac
    done

    check_dependencies || exit 1

    # Résolution de l'identité utilisateur
    if [[ -n "$NPUB" ]] && [[ -z "$USER_HEX" ]]; then
        USER_HEX=$(npub_to_hex "$NPUB")
    fi
    if [[ -n "$EMAIL" ]] && [[ -z "$USER_HEX" ]]; then
        USER_HEX=$(find_hex_from_email "$EMAIL") || exit 1
    fi

    # Commandes qui n'exigent pas d'utilisateur identifié
    local no_user_cmds="stats list-all browse cleanup demo -h --help"

    if ! echo "$no_user_cmds" | grep -qwF -- "$COMMAND"; then
        if [[ "$COMMAND" == "republish" ]]; then
            REPUBLISH_KIND="${1:-$KIND}"
        elif [[ -z "$USER_HEX" ]]; then
            log_error "Commande «$COMMAND» requiert --npub, --hex ou --email"
            exit 1
        fi
    fi

    case "$COMMAND" in
        stats)          cmd_stats ;;
        list-all)       cmd_list_all ;;
        list)           cmd_list ;;
        browse)         cmd_browse ;;
        user)           cmd_user ;;
        check)          cmd_check ;;
        certify)        cmd_certify ;;
        cleanup)        cmd_cleanup ;;
        republish)      cmd_republish "$REPUBLISH_KIND" ;;
        export-skill)   cmd_export_skill ;;
        delete-skill)   cmd_delete_skill ;;
        demo)           cmd_demo ;;
        -h|--help)      usage ;;
        *)              log_error "Commande inconnue: $COMMAND"; usage ;;
    esac
}

trap "rm -rf '$TEMP_DIR'" EXIT
main "$@"
