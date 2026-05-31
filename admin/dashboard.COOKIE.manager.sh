#!/bin/bash
################################################################################
# Script: dashboard.COOKIE.manager.sh
# Description: Manage local NOSTR Cookie Vault (kind 31903) for all MULTIPASS players
#
# Cookies are stored as:
#   - Disk:  ~/.zen/game/nostr/<email>/.<domain>.cookie  (Netscape plain, chmod 600)
#   - IPFS:  natools NaCl-encrypted blob (CID in manifest)
#   - NOSTR: kind 31903 (d=cookies) — manifest complet {domain→CID}
#
# Usage: dashboard.COOKIE.manager.sh [COMMAND] [OPTIONS]
################################################################################
MY_PATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TOOLS_PATH="${MY_PATH}/../tools"

[[ -s "${TOOLS_PATH}/my.sh" ]] && source "${TOOLS_PATH}/my.sh"

################################################################################
# Colors
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

################################################################################
# Configuration
################################################################################
NOSTR_DIR="${HOME}/.zen/game/nostr"
UPASSPORT_API="${myHOST:-http://127.0.0.1:54321}"
NOSTR_GET_EVENTS="${TOOLS_PATH}/nostr_get_events.sh"
COOKIE_KIND=31903

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}
${CYAN}║${NC}          ${YELLOW}dashboard.COOKIE.manager.sh - UPlanet Cookie Vault${NC}              ${CYAN}║${NC}
${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}

${YELLOW}DESCRIPTION:${NC}
    Manage encrypted cookies (kind 31903) for all MULTIPASS players.
    Cookies are NaCl-encrypted on IPFS, referenced in NOSTR kind 31903 d=cookies.

${YELLOW}USAGE:${NC}
    dashboard.COOKIE.manager.sh [COMMAND] [OPTIONS]

${YELLOW}COMMANDS:${NC}
    menu              Interactive main menu (default)
    list-all          List cookies for all local players
    list              List cookies for a specific player
    browse            Interactive browser (player → domains)
    check             Verify IPFS availability of encrypted cookies
    stats             Global statistics across all players
    delete            Delete a cookie for a player/domain
    publish           Re-publish kind 31903 manifest to relay
    purge-expired     Remove cookies older than N days (default: 90)

${YELLOW}OPTIONS:${NC}
    -e, --email EMAIL     Player email
    -d, --domain DOMAIN   Cookie domain
    -n, --days N          Age threshold for purge (default: 90)
    -f, --force           Skip confirmations
    -v, --verbose         Verbose output
    -h, --help            Show this help

${YELLOW}EXAMPLES:${NC}
    dashboard.COOKIE.manager.sh menu
    dashboard.COOKIE.manager.sh list --email user@example.com
    dashboard.COOKIE.manager.sh check --email user@example.com
    dashboard.COOKIE.manager.sh delete --email user@example.com --domain youtube.com
    dashboard.COOKIE.manager.sh purge-expired --days 60 --force

${YELLOW}STORAGE:${NC}
    ${GREEN}Disk${NC}    ~/.zen/game/nostr/<email>/.<domain>.cookie   (Netscape, 600)
    ${GREEN}IPFS${NC}    natools seal (G1 pubkey) → CID
    ${GREEN}NOSTR${NC}   kind 31903  d=cookies  manifest JSON {domain→{cid,uploaded_at,size}}

EOF
    exit 0
}

################################################################################
# Helpers
################################################################################
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_debug()   { [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"; }

check_dependencies() {
    local missing=()
    command -v jq   &>/dev/null || missing+=("jq")
    command -v curl &>/dev/null || missing+=("curl")
    command -v ipfs &>/dev/null || missing+=("ipfs")
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dépendances manquantes: ${missing[*]}"
        return 1
    fi
}

# List all player emails
list_players() {
    find "$NOSTR_DIR" -maxdepth 1 -type d -name "*@*" 2>/dev/null \
        | xargs -I{} basename {} 2>/dev/null | sort
}

# Cookie files for a player: returns "domain cookiepath" lines
list_cookie_files() {
    local email="$1"
    local player_dir="${NOSTR_DIR}/${email}"
    [[ ! -d "$player_dir" ]] && return 1
    find "$player_dir" -maxdepth 1 -name ".*.cookie" -type f 2>/dev/null \
        | while read -r f; do
            local domain
            domain=$(basename "$f" | sed 's/^\.//' | sed 's/\.cookie$//')
            echo "$domain $f"
        done
}

# Load manifest for a player → prints JSON or {}
load_manifest() {
    local email="$1"
    local mfile="${NOSTR_DIR}/${email}/.cookie_manifest.json"
    [[ -f "$mfile" ]] && cat "$mfile" 2>/dev/null || echo "{}"
}

# Age in days from ISO date string
age_days() {
    local iso="$1"
    [[ -z "$iso" ]] && echo "?" && return
    local epoch
    epoch=$(date -d "$iso" +%s 2>/dev/null) || { echo "?"; return; }
    echo $(( ( $(date +%s) - epoch ) / 86400 ))
}

# Color for cookie age
age_color() {
    local age="$1"
    [[ "$age" == "?" ]] && echo "$YELLOW" && return
    if   (( age < 14 )); then echo "$GREEN"
    elif (( age < 30 )); then echo "$YELLOW"
    else echo "$RED"
    fi
}

# Check IPFS availability of a CID (non-blocking, 5s timeout)
check_ipfs_cid() {
    local cid="$1"
    [[ -z "$cid" ]] && return 1
    ipfs cat "$cid" --timeout=5s >/dev/null 2>&1
}

# Get npub for a player (from NPUB file or .secret.nostr)
get_player_npub() {
    local email="$1"
    local d="${NOSTR_DIR}/${email}"
    [[ -f "$d/NPUB" ]] && cat "$d/NPUB" && return
    grep -oP 'NPUB=\K[^;]+' "$d/.secret.nostr" 2>/dev/null | head -1
}

# Call UPassport DELETE /cookie/{domain}?npub=...
api_delete_cookie() {
    local email="$1"
    local domain="$2"
    local npub
    npub=$(get_player_npub "$email")
    if [[ -z "$npub" ]]; then
        log_error "Impossible de trouver le npub pour $email"
        return 1
    fi
    local url="${UPASSPORT_API}/cookie/$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$domain" 2>/dev/null || echo "$domain")?npub=${npub}"
    local resp
    resp=$(curl -sf -X DELETE "$url" 2>/dev/null)
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        echo "$resp" | jq -e '.success' >/dev/null 2>&1 && return 0
    fi
    return 1
}

################################################################################
# Display helpers
################################################################################
print_cookie_row() {
    local domain="$1" age="$2" cid="$3" size="$4" disk_ok="$5"
    local acolor
    acolor=$(age_color "$age")
    local cid_short="${cid:0:14}…"
    [[ -z "$cid" ]] && cid_short="${YELLOW}—${NC}"
    local disk_icon="💾"
    [[ "$disk_ok" != "true" ]] && disk_icon="${RED}✗${NC}"
    local size_kb=""
    [[ -n "$size" && "$size" != "0" ]] && size_kb=" ($(( size / 1024 ))KB)"
    printf "  %-35s ${acolor}%4s j${NC}  %-20s %s%s\n" \
        "$domain" "$age" "$cid_short" "$disk_icon" "$size_kb"
}

################################################################################
# cmd_list_all
################################################################################
cmd_list_all() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${YELLOW}🍪 Cookie Vault — Tous les joueurs${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total_players=0 total_cookies=0 total_missing_ipfs=0

    while IFS= read -r email; do
        [[ -z "$email" ]] && continue
        local manifest
        manifest=$(load_manifest "$email")
        local domain_count
        domain_count=$(echo "$manifest" | jq 'keys | length' 2>/dev/null || echo 0)
        local disk_count
        disk_count=$(list_cookie_files "$email" | wc -l)

        total_players=$(( total_players + 1 ))
        total_cookies=$(( total_cookies + disk_count ))

        [[ $disk_count -eq 0 ]] && continue

        echo -e "  ${MAGENTA}▶${NC} ${GREEN}${email}${NC}  ${CYAN}(${disk_count} cookies)${NC}"
        printf "    %-35s %-6s %-20s %s\n" "Domaine" "Âge" "CID IPFS" "Disque"
        echo -e "    ${CYAN}────────────────────────────────────────────────────────────────${NC}"

        list_cookie_files "$email" | while read -r domain cookiepath; do
            local cid uploaded_at size
            cid=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].cid // empty' 2>/dev/null)
            uploaded_at=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].uploaded_at // empty' 2>/dev/null)
            size=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].size // 0' 2>/dev/null)
            local age
            age=$(age_days "$uploaded_at")
            local disk_ok="true"
            [[ ! -f "$cookiepath" ]] && disk_ok="false"
            print_cookie_row "$domain" "$age" "$cid" "$size" "$disk_ok"
        done
        echo ""
    done < <(list_players)

    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}Joueurs:${NC} $total_players  ${GREEN}Cookies total:${NC} $total_cookies"
    echo ""
}

################################################################################
# cmd_list (single player)
################################################################################
cmd_list() {
    local email="$1"
    [[ -z "$email" ]] && { log_error "Email requis (--email)"; return 1; }
    [[ ! -d "${NOSTR_DIR}/${email}" ]] && { log_error "Joueur inconnu: $email"; return 1; }

    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}🍪 Cookie Vault — ${email}${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local manifest
    manifest=$(load_manifest "$email")

    local count=0
    printf "    %-35s %-6s %-20s %s\n" "Domaine" "Âge" "CID IPFS" "Disque"
    echo -e "    ${CYAN}────────────────────────────────────────────────────────────────${NC}"

    list_cookie_files "$email" | while read -r domain cookiepath; do
        count=$(( count + 1 ))
        local cid uploaded_at size
        cid=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].cid // empty' 2>/dev/null)
        uploaded_at=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].uploaded_at // empty' 2>/dev/null)
        size=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].size // 0' 2>/dev/null)
        print_cookie_row "$domain" "$(age_days "$uploaded_at")" "$cid" "$size" "true"
    done

    echo ""
    local npub
    npub=$(get_player_npub "$email")
    [[ -n "$npub" ]] && echo -e "  ${CYAN}NPUB:${NC} ${npub:0:20}…"

    # NOSTR kind 31903 status
    if [[ -f "$NOSTR_GET_EVENTS" ]]; then
        local hex
        hex=$(cat "${NOSTR_DIR}/${email}/HEX" 2>/dev/null)
        if [[ -n "$hex" ]]; then
            local nostr_event
            nostr_event=$(bash "$NOSTR_GET_EVENTS" --kind $COOKIE_KIND --author "$hex" --limit 1 2>/dev/null)
            if [[ -n "$nostr_event" && "$nostr_event" != "[]" ]]; then
                echo -e "  ${GREEN}NOSTR kind 31903:${NC} ✅ manifest publié"
            else
                echo -e "  ${YELLOW}NOSTR kind 31903:${NC} ⚠️  non publié"
            fi
        fi
    fi
    echo ""
}

################################################################################
# cmd_check — verify IPFS CIDs for a player
################################################################################
cmd_check() {
    local email="$1"
    [[ -z "$email" ]] && { log_error "Email requis (--email)"; return 1; }

    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${YELLOW}🔍 Vérification IPFS — ${email}${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local manifest
    manifest=$(load_manifest "$email")
    local ok=0 ko=0 nocid=0

    list_cookie_files "$email" | while read -r domain cookiepath; do
        local cid
        cid=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].cid // empty' 2>/dev/null)
        printf "  %-40s " "$domain"
        if [[ -z "$cid" ]]; then
            echo -e "${YELLOW}⚠️  Pas de CID (disque seulement)${NC}"
            nocid=$(( nocid + 1 ))
        else
            printf "CID %-18s " "${cid:0:16}…"
            if check_ipfs_cid "$cid"; then
                echo -e "${GREEN}✅ IPFS OK${NC}"
                ok=$(( ok + 1 ))
            else
                echo -e "${RED}❌ IPFS inaccessible${NC}"
                ko=$(( ko + 1 ))
            fi
        fi
    done

    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}IPFS OK: $ok${NC}  ${RED}Inaccessible: $ko${NC}  ${YELLOW}Sans CID: $nocid${NC}"
    echo ""
}

################################################################################
# cmd_stats — global statistics
################################################################################
cmd_stats() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                   ${YELLOW}📊 Cookie Vault — Statistiques${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total_players=0 total_cookies=0
    local cookies_with_cid=0 cookies_nostr=0
    local age_ok=0 age_warn=0 age_old=0
    declare -A domain_count

    while IFS= read -r email; do
        [[ -z "$email" ]] && continue
        local manifest
        manifest=$(load_manifest "$email")
        local hex
        hex=$(cat "${NOSTR_DIR}/${email}/HEX" 2>/dev/null)

        local has_nostr=0
        if [[ -f "$NOSTR_GET_EVENTS" && -n "$hex" ]]; then
            local ev
            ev=$(bash "$NOSTR_GET_EVENTS" --kind $COOKIE_KIND --author "$hex" --limit 1 2>/dev/null)
            [[ -n "$ev" && "$ev" != "[]" ]] && has_nostr=1
        fi

        local player_cookies=0
        list_cookie_files "$email" | while read -r domain cookiepath; do
            :
        done

        local disk_count
        disk_count=$(list_cookie_files "$email" | wc -l)
        [[ $disk_count -eq 0 ]] && continue

        total_players=$(( total_players + 1 ))
        total_cookies=$(( total_cookies + disk_count ))
        [[ $has_nostr -eq 1 ]] && cookies_nostr=$(( cookies_nostr + 1 ))

        list_cookie_files "$email" | while read -r domain cookiepath; do
            local cid uploaded_at
            cid=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].cid // empty' 2>/dev/null)
            uploaded_at=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].uploaded_at // empty' 2>/dev/null)
            [[ -n "$cid" ]] && cookies_with_cid=$(( cookies_with_cid + 1 ))
            local age
            age=$(age_days "$uploaded_at")
            if [[ "$age" == "?" ]]; then :
            elif (( age < 14 )); then age_ok=$(( age_ok + 1 ))
            elif (( age < 30 )); then age_warn=$(( age_warn + 1 ))
            else age_old=$(( age_old + 1 ))
            fi
            domain_count["$domain"]=$(( ${domain_count["$domain"]:-0} + 1 ))
        done
    done < <(list_players)

    echo -e "${YELLOW}📦 Vue d'ensemble${NC}"
    echo -e "  Joueurs avec cookies : ${GREEN}$total_players${NC}"
    echo -e "  Cookies total (disque): ${GREEN}$total_cookies${NC}"
    echo -e "  Avec CID IPFS         : ${GREEN}$cookies_with_cid${NC}"
    echo -e "  Manifest NOSTR 31903  : ${GREEN}$cookies_nostr${NC} joueurs"
    echo ""
    echo -e "${YELLOW}⏰ Ancienneté des cookies${NC}"
    echo -e "  ${GREEN}< 14j (frais)   :${NC} $age_ok"
    echo -e "  ${YELLOW}14-30j (attention):${NC} $age_warn"
    echo -e "  ${RED}> 30j (périmé?)  :${NC} $age_old"
    echo ""
    echo -e "${YELLOW}🌐 Domaines les plus stockés${NC}"
    for domain in $(for k in "${!domain_count[@]}"; do echo "${domain_count[$k]} $k"; done | sort -rn | head -10 | awk '{print $2}'); do
        printf "  %-40s %s joueur(s)\n" "$domain" "${domain_count[$domain]}"
    done
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# cmd_delete — delete a cookie (via API or disk fallback)
################################################################################
cmd_delete() {
    local email="$1"
    local domain="$2"
    local force="${FORCE:-false}"

    [[ -z "$email" ]]  && { log_error "Email requis (--email)"; return 1; }
    [[ -z "$domain" ]] && { log_error "Domaine requis (--domain)"; return 1; }

    local cookiepath="${NOSTR_DIR}/${email}/.${domain}.cookie"

    if [[ "$force" != "true" ]]; then
        echo -e "${YELLOW}Supprimer le cookie ${domain} pour ${email} ?${NC}"
        echo "  Disque : $cookiepath"
        read -p "Confirmer (oui/NON) : " confirm
        [[ "$confirm" != "oui" ]] && { log_warning "Annulé"; return 0; }
    fi

    log_info "Suppression via UPassport API..."
    if api_delete_cookie "$email" "$domain"; then
        log_success "Cookie $domain supprimé via API (manifest + IPFS unpin + NOSTR republié)"
    else
        log_warning "API indisponible — suppression disque uniquement"
        if [[ -f "$cookiepath" ]]; then
            rm -f "$cookiepath"
            log_success "Fichier disque supprimé: $cookiepath"
            # Remove from manifest manually
            local mfile="${NOSTR_DIR}/${email}/.cookie_manifest.json"
            if [[ -f "$mfile" ]]; then
                local new_manifest
                new_manifest=$(jq --arg d "$domain" 'del(.[$d])' "$mfile" 2>/dev/null)
                [[ -n "$new_manifest" ]] && echo "$new_manifest" > "$mfile"
                log_info "Manifest local mis à jour"
            fi
        else
            log_error "Fichier introuvable: $cookiepath"
            return 1
        fi
    fi
}

################################################################################
# cmd_publish — re-publish kind 31903 manifest for a player
################################################################################
cmd_publish() {
    local email="$1"
    [[ -z "$email" ]] && { log_error "Email requis (--email)"; return 1; }

    local secret="${NOSTR_DIR}/${email}/.secret.nostr"
    [[ ! -f "$secret" ]] && { log_error "Clef secrète introuvable: $secret"; return 1; }

    local manifest
    manifest=$(load_manifest "$email")
    if [[ "$manifest" == "{}" ]]; then
        log_warning "Manifest vide — rien à publier"
        return 0
    fi

    local nostr_send="${TOOLS_PATH}/nostr_send_note.py"
    [[ ! -f "$nostr_send" ]] && { log_error "nostr_send_note.py introuvable"; return 1; }

    log_info "Publication kind $COOKIE_KIND d=cookies pour $email..."

    local tags='[["d","cookies"],["t","cookies"],["t","uplanet"]]'
    local result
    result=$(python3 "$nostr_send" \
        --keyfile "$secret" \
        --content "$manifest" \
        --tags "$tags" \
        --kind "$COOKIE_KIND" \
        --relays "ws://127.0.0.1:7777" \
        --json 2>&1)

    if echo "$result" | jq -e '.success // false' >/dev/null 2>&1; then
        local event_id
        event_id=$(echo "$result" | jq -r '.event_id // empty' 2>/dev/null)
        log_success "Manifest publié — event: ${event_id:0:16}…"
    else
        log_error "Échec publication: $result"
        return 1
    fi
}

################################################################################
# cmd_purge_expired — remove cookies older than N days
################################################################################
cmd_purge_expired() {
    local days="${PURGE_DAYS:-90}"
    local force="${FORCE:-false}"

    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${YELLOW}🗑️  Purge cookies > ${days} jours${NC}                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local -a to_delete=()

    while IFS= read -r email; do
        [[ -z "$email" ]] && continue
        local manifest
        manifest=$(load_manifest "$email")
        list_cookie_files "$email" | while read -r domain cookiepath; do
            local uploaded_at
            uploaded_at=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].uploaded_at // empty' 2>/dev/null)
            local age
            age=$(age_days "$uploaded_at")
            if [[ "$age" != "?" ]] && (( age > days )); then
                echo -e "  ${RED}$age j${NC}  $email  →  $domain"
                to_delete+=("$email:$domain")
            fi
        done
    done < <(list_players)

    if [[ ${#to_delete[@]} -eq 0 ]]; then
        log_success "Aucun cookie expiré (seuil: ${days}j)"
        return 0
    fi

    echo ""
    if [[ "$force" != "true" ]]; then
        read -p "Supprimer ces ${#to_delete[@]} cookies ? (oui/NON) : " confirm
        [[ "$confirm" != "oui" ]] && { log_warning "Annulé"; return 0; }
    fi

    for entry in "${to_delete[@]}"; do
        local em="${entry%%:*}"
        local dom="${entry#*:}"
        cmd_delete "$em" "$dom" 2>/dev/null && log_success "Supprimé: $em / $dom" || log_error "Échec: $em / $dom"
    done
}

################################################################################
# cmd_browse — interactive browser
################################################################################
cmd_browse() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                  ${YELLOW}🍪 Cookie Vault Browser${NC}                                 ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        local -a players=()
        local -a player_counts=()
        local idx=1

        while IFS= read -r email; do
            [[ -z "$email" ]] && continue
            local count
            count=$(list_cookie_files "$email" | wc -l)
            [[ $count -eq 0 ]] && continue
            players+=("$email")
            player_counts+=("$count")
            # NOSTR status
            local hex
            hex=$(cat "${NOSTR_DIR}/${email}/HEX" 2>/dev/null)
            local nostr_icon="⚠️"
            if [[ -f "$NOSTR_GET_EVENTS" && -n "$hex" ]]; then
                local ev
                ev=$(bash "$NOSTR_GET_EVENTS" --kind $COOKIE_KIND --author "$hex" --limit 1 2>/dev/null)
                [[ -n "$ev" && "$ev" != "[]" ]] && nostr_icon="📡"
            fi
            echo -e "  ${YELLOW}$idx.${NC} ${GREEN}$email${NC}  ${CYAN}(${count} cookies)${NC} $nostr_icon"
            idx=$(( idx + 1 ))
        done < <(list_players)

        if [[ ${#players[@]} -eq 0 ]]; then
            log_warning "Aucun joueur n'a de cookies stockés"
            echo ""
            read -p "Appuyez sur ENTRÉE..."
            return 0
        fi

        echo ""
        echo -e "  ${YELLOW}0.${NC} 🚪 Quitter"
        echo ""
        read -p "$(echo -e ${CYAN}Choisir un joueur [0-${#players[@]}]:${NC} )" choice

        [[ "$choice" == "0" ]] && { clear; return 0; }

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#players[@]} )); then
            browse_player_cookies "${players[$(( choice - 1 ))]}"
        else
            log_error "Choix invalide"
            sleep 1
        fi
    done
}

browse_player_cookies() {
    local email="$1"

    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}         ${YELLOW}🍪 ${email}${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        local manifest
        manifest=$(load_manifest "$email")

        local -a domains=()
        local -a cookiepaths=()
        local idx=1

        list_cookie_files "$email" | while read -r domain cookiepath; do
            domains+=("$domain")
            cookiepaths+=("$cookiepath")

            local cid uploaded_at size
            cid=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].cid // empty' 2>/dev/null)
            uploaded_at=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].uploaded_at // empty' 2>/dev/null)
            size=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].size // 0' 2>/dev/null)
            local age
            age=$(age_days "$uploaded_at")
            local acolor
            acolor=$(age_color "$age")
            local cid_short="—"
            [[ -n "$cid" ]] && cid_short="${cid:0:12}…"
            local size_kb=""
            [[ -n "$size" && "$size" != "0" ]] && size_kb=" $(( size / 1024 ))KB"

            echo -e "  ${YELLOW}$idx.${NC} ${GREEN}${domain}${NC}${size_kb}  ${acolor}${age}j${NC}  ${CYAN}${cid_short}${NC}"
            idx=$(( idx + 1 ))
        done
        # Re-populate arrays (can't use while+pipe for arrays)
        mapfile -t domains < <(list_cookie_files "$email" | awk '{print $1}')
        mapfile -t cookiepaths < <(list_cookie_files "$email" | awk '{print $2}')

        echo ""
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${YELLOW}1-${#domains[@]}.${NC} 🔍 Détails / actions"
        echo -e "  ${YELLOW}c.${NC} 🔍 Vérifier IPFS"
        echo -e "  ${YELLOW}p.${NC} 📡 (Re)publier manifest NOSTR kind $COOKIE_KIND"
        echo -e "  ${YELLOW}b.${NC} 🔙 Retour"
        echo ""
        read -p "$(echo -e ${CYAN}Action:${NC} )" action

        case "$action" in
            b) return 0 ;;
            c) cmd_check "$email"; read -p "Appuyez sur ENTRÉE..." ;;
            p) cmd_publish "$email"; read -p "Appuyez sur ENTRÉE..." ;;
            [0-9]|[0-9][0-9])
                local didx=$(( action - 1 ))
                if (( didx >= 0 && didx < ${#domains[@]} )); then
                    show_cookie_details "$email" "${domains[$didx]}" "${cookiepaths[$didx]}" "$manifest"
                else
                    log_error "Numéro invalide"; sleep 1
                fi
                ;;
            *) log_error "Action invalide"; sleep 1 ;;
        esac
    done
}

show_cookie_details() {
    local email="$1"
    local domain="$2"
    local cookiepath="$3"
    local manifest="$4"

    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}🍪 ${domain}${NC}  — ${email}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local cid uploaded_at size
    cid=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].cid // empty' 2>/dev/null)
    uploaded_at=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].uploaded_at // empty' 2>/dev/null)
    size=$(echo "$manifest" | jq -r --arg d "$domain" '.[$d].size // 0' 2>/dev/null)
    local age
    age=$(age_days "$uploaded_at")
    local acolor
    acolor=$(age_color "$age")

    echo -e "${YELLOW}📋 Informations${NC}"
    echo -e "  Domaine   : ${GREEN}$domain${NC}"
    echo -e "  Email     : $email"
    echo -e "  Uploadé   : ${uploaded_at:-inconnu}"
    echo -e "  Âge       : ${acolor}${age} jours${NC}"
    echo -e "  Taille    : $(( ${size:-0} / 1024 )) KB"
    echo ""

    echo -e "${YELLOW}📁 Disque${NC}"
    if [[ -f "$cookiepath" ]]; then
        local lines
        lines=$(wc -l < "$cookiepath" 2>/dev/null || echo "?")
        echo -e "  Fichier : ${GREEN}$cookiepath${NC}"
        echo -e "  Lignes  : $lines"
    else
        echo -e "  ${RED}Fichier disque absent${NC}"
    fi
    echo ""

    echo -e "${YELLOW}📦 IPFS${NC}"
    if [[ -n "$cid" ]]; then
        echo -e "  CID : $cid"
        printf "  État IPFS : "
        if check_ipfs_cid "$cid"; then
            echo -e "${GREEN}✅ accessible${NC}"
        else
            echo -e "${RED}❌ inaccessible (5s timeout)${NC}"
        fi
    else
        echo -e "  ${YELLOW}Pas de CID (stockage disque seulement)${NC}"
    fi
    echo ""

    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}d.${NC} 🗑️  Supprimer ce cookie"
    echo -e "  ${YELLOW}b.${NC} 🔙 Retour"
    echo ""
    read -p "$(echo -e ${CYAN}Action:${NC} )" action

    case "$action" in
        d)
            cmd_delete "$email" "$domain"
            read -p "Appuyez sur ENTRÉE..."
            return 0  # force reload in caller
            ;;
        b) return 0 ;;
    esac
}

################################################################################
# cmd_menu — interactive main menu
################################################################################
cmd_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}               ${YELLOW}🍪 UPlanet Cookie Vault Manager${NC}                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}          kind ${MAGENTA}${COOKIE_KIND}${NC} · IPFS NaCl · NOSTR d=cookies                     ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Quick stats
        local total_players=0 total_cookies=0
        while IFS= read -r email; do
            local c
            c=$(list_cookie_files "$email" | wc -l)
            (( c > 0 )) && total_players=$(( total_players + 1 ))
            total_cookies=$(( total_cookies + c ))
        done < <(list_players)

        echo -e "  ${CYAN}Station:${NC} ${IPFSNODEID:0:20}…  ${CYAN}|${NC}  ${GREEN}$total_players${NC} joueurs  ${GREEN}$total_cookies${NC} cookies"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${YELLOW}1.${NC} 📋 Lister tous les cookies (tous joueurs)"
        echo -e "  ${YELLOW}2.${NC} 🔍 Browser interactif (joueur → domaine)"
        echo -e "  ${YELLOW}3.${NC} 📊 Statistiques globales"
        echo -e "  ${YELLOW}4.${NC} 🔍 Vérifier IPFS (un joueur)"
        echo -e "  ${YELLOW}5.${NC} 📡 Republier manifest NOSTR (un joueur)"
        echo -e "  ${YELLOW}6.${NC} 🗑️  Supprimer un cookie"
        echo -e "  ${YELLOW}7.${NC} 🧹 Purger cookies expirés (> N jours)"
        echo ""
        echo -e "  ${YELLOW}0.${NC} 🚪 Quitter"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        read -p "$(echo -e ${CYAN}Choisir:${NC} )" choice

        case "$choice" in
            1) cmd_list_all ;;
            2) cmd_browse ;;
            3) cmd_stats ;;
            4)
                read -p "Email du joueur: " em
                cmd_check "$em"
                ;;
            5)
                read -p "Email du joueur: " em
                cmd_publish "$em"
                ;;
            6)
                read -p "Email du joueur: " em
                read -p "Domaine: " dom
                EMAIL="$em" DOMAIN="$dom" cmd_delete "$em" "$dom"
                ;;
            7)
                read -p "Seuil en jours (défaut 90): " dd
                PURGE_DAYS="${dd:-90}" cmd_purge_expired
                ;;
            0) clear; exit 0 ;;
            *) log_error "Option invalide"; sleep 1 ;;
        esac

        echo ""
        read -p "Appuyez sur ENTRÉE pour continuer…"
    done
}

################################################################################
# Argument parsing
################################################################################
VERBOSE="false"
FORCE="false"
EMAIL=""
DOMAIN=""
PURGE_DAYS=90
COMMAND="menu"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--email)   EMAIL="$2";       shift 2 ;;
        -d|--domain)  DOMAIN="$2";      shift 2 ;;
        -n|--days)    PURGE_DAYS="$2";  shift 2 ;;
        -f|--force)   FORCE="true";     shift ;;
        -v|--verbose) VERBOSE="true";   shift ;;
        -h|--help)    usage ;;
        menu|list|list-all|browse|check|stats|delete|publish|purge-expired)
            COMMAND="$1"; shift ;;
        *) log_error "Option inconnue: $1"; usage ;;
    esac
done

check_dependencies || exit 1

case "$COMMAND" in
    menu)           cmd_menu ;;
    list-all)       cmd_list_all ;;
    list)           cmd_list "$EMAIL" ;;
    browse)         cmd_browse ;;
    check)          cmd_check "$EMAIL" ;;
    stats)          cmd_stats ;;
    delete)         cmd_delete "$EMAIL" "$DOMAIN" ;;
    publish)        cmd_publish "$EMAIL" ;;
    purge-expired)  cmd_purge_expired ;;
    *)              usage ;;
esac
