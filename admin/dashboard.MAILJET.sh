#!/bin/bash
################################################################################
# Script: dashboard.MAILJET.sh
# Description: Interface d'administration Mailjet pour le Capitaine UPlanet.
#              Gestion des clés API, suivi opt-outs, préférences KIN Oracle,
#              envoi test, consultation logs.
# Usage: dashboard.MAILJET.sh [COMMAND] [OPTIONS]
# Depends on: mailjet.sh, kin_prefs.sh, cooperative_config.sh, my.sh
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
MAILJET_SH="${TOOLS_PATH}/mailjet.sh"
KIN_PREFS_SH="${TOOLS_PATH}/kin_prefs.sh"
COOP_CFG_SH="${TOOLS_PATH}/cooperative_config.sh"
NOSTR_DIR="${HOME}/.zen/game/nostr"
PLAYERS_DIR="${HOME}/.zen/game/players"
MAILJET_LOG="${HOME}/.zen/tmp/mailjet.log"
MJ_LEGACY="${HOME}/.zen/MJ_APIKEY"
TEMP_DIR="${HOME}/.zen/tmp/mj_mgr_$$"
MAILJET_API_URL="https://api.mailjet.com/v3.1/send"

# Source kin_prefs si disponible
[[ -s "$KIN_PREFS_SH" ]] && source "$KIN_PREFS_SH"

################################################################################
# Logging
################################################################################
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

################################################################################
# Credentials loader
################################################################################
_load_mj_credentials() {
    MJ_APIKEY_PUBLIC=""
    MJ_APIKEY_PRIVATE=""
    SENDER_EMAIL=""

    # Priorité 1 : cooperative-config (Kind 30800)
    if [[ -s "$COOP_CFG_SH" ]]; then
        source "$COOP_CFG_SH" 2>/dev/null
        MJ_APIKEY_PUBLIC="$(coop_config_get "MJ_APIKEY_PUBLIC" 2>/dev/null)"
        MJ_APIKEY_PRIVATE="$(coop_config_get "MJ_APIKEY_PRIVATE" 2>/dev/null)"
        SENDER_EMAIL="$(coop_config_get "MJ_SENDER_EMAIL" 2>/dev/null)"
    fi

    # Priorité 2 : fichier legacy
    if [[ -z "$MJ_APIKEY_PUBLIC" && -s "$MJ_LEGACY" ]]; then
        source "$MJ_LEGACY"
    fi
}

################################################################################
# Usage
################################################################################
usage() {
    cat << EOF
${CYAN}${BOLD}dashboard.MAILJET.sh — Administration Notifications UPlanet${NC}

${YELLOW}COMMANDES:${NC}
  status              État de la configuration Mailjet + stats globales
  check-keys          Vérifier les clés API Mailjet (appel test)
  set-keys            Configurer les clés API (interactive)
  list                Lister tous les membres avec leur statut email/KIN
  optouts             Membres ayant opt-out (email ou all)
  show EMAIL          Détail des préférences d'un membre
  kin-stats           Statistiques des préférences KIN Oracle
  test EMAIL          Envoyer un email de test au membre
  send EMAIL FILE S   Envoi manuel : EMAIL, fichier HTML, sujet
  logs [N]            Afficher les N dernières lignes du log (défaut: 50)
  browse              Navigateur interactif membres → préférences → actions

${YELLOW}OPTIONS:${NC}
  --email EMAIL       Adresse email du membre
  --verbose           Sortie détaillée
  --force             Sans confirmation interactive

${YELLOW}FICHIERS CLÉS:${NC}
  ~/.zen/game/nostr/EMAIL/.mailjet   Préférences JSON par membre
  ~/.zen/tmp/mailjet.log             Log complet des envois
  ~/.zen/MJ_APIKEY                   Credentials legacy (si pas de coop-config)

${YELLOW}FORMAT .mailjet JSON:${NC}
  { "email_channel": bool, "nostr_channel": bool, "channels": [],
    "kin": { "daily": bool, "weekly": bool, "scope": "relay|n1|n2",
             "types": ["quartet","occult","analog","tone","guide","antipode"],
             "langage": "pragmatique|curieux|symbolique|cosmique" } }

${YELLOW}EXEMPLES:${NC}
  $0 status
  $0 check-keys
  $0 list
  $0 show user@example.com
  $0 optouts
  $0 kin-stats
  $0 test user@example.com
  $0 logs 100
  $0 browse

EOF
    exit 0
}

################################################################################
# status — Configuration + stats globales
################################################################################
cmd_status() {
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}   MAILJET — CONFIGURATION STATION${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════${NC}"

    _load_mj_credentials

    # Affichage credentials
    echo ""
    echo -e "${YELLOW}── Credentials ──${NC}"
    if [[ -n "$MJ_APIKEY_PUBLIC" ]]; then
        echo -e "  ${GREEN}✅ MJ_APIKEY_PUBLIC${NC}  : ${MJ_APIKEY_PUBLIC:0:12}…"
        echo -e "  ${GREEN}✅ MJ_APIKEY_PRIVATE${NC} : ${MJ_APIKEY_PRIVATE:0:8}…"
        echo -e "  ${GREEN}✅ SENDER_EMAIL${NC}      : ${SENDER_EMAIL}"
    else
        echo -e "  ${RED}❌ Aucune clé API Mailjet configurée.${NC}"
        echo -e "     → Lancer : $0 set-keys"
    fi

    # Source coopérative
    if [[ -s "$COOP_CFG_SH" ]]; then
        echo -e "  ${CYAN}Source${NC}              : cooperative-config (Kind 30800)"
    elif [[ -s "$MJ_LEGACY" ]]; then
        echo -e "  ${YELLOW}Source${NC}              : ~/.zen/MJ_APIKEY (legacy)"
    fi

    # Stats membres
    echo ""
    echo -e "${YELLOW}── Membres ──${NC}"
    local total_mj=0 total_optout=0 total_kin_on=0
    while IFS= read -r -d '' mj_file; do
        (( total_mj++ ))
        local optout
        optout=$(jq -r '.channels[]?' "$mj_file" 2>/dev/null | grep -c "email\|all" || echo 0)
        [[ "$optout" -gt 0 ]] && (( total_optout++ ))
        local daily
        daily=$(jq -r '.kin.daily // true' "$mj_file" 2>/dev/null)
        [[ "$daily" == "true" ]] && (( total_kin_on++ ))
    done < <(find "$NOSTR_DIR" -maxdepth 2 -name ".mailjet" -print0 2>/dev/null)

    echo -e "  Membres avec prefs     : ${CYAN}${total_mj}${NC}"
    echo -e "  Opt-out email          : ${RED}${total_optout}${NC}"
    echo -e "  KIN daily activé       : ${GREEN}${total_kin_on}${NC}"

    # Log récent
    echo ""
    echo -e "${YELLOW}── Log récent (10 dernières lignes) ──${NC}"
    if [[ -f "$MAILJET_LOG" ]]; then
        tail -10 "$MAILJET_LOG" | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}(aucun log : $MAILJET_LOG)${NC}"
    fi

    # mailjet.sh disponible ?
    echo ""
    echo -e "${YELLOW}── Scripts ──${NC}"
    [[ -x "$MAILJET_SH" ]] && echo -e "  ${GREEN}✅${NC} mailjet.sh        : $MAILJET_SH" \
                            || echo -e "  ${RED}❌${NC} mailjet.sh        : introuvable"
    [[ -s "$KIN_PREFS_SH" ]]  && echo -e "  ${GREEN}✅${NC} kin_prefs.sh      : $KIN_PREFS_SH" \
                              || echo -e "  ${YELLOW}⚠${NC}  kin_prefs.sh      : absent"
    echo ""
}

################################################################################
# check-keys — Tester les clés API Mailjet
################################################################################
cmd_check_keys() {
    _load_mj_credentials

    echo ""
    echo -e "${CYAN}${BOLD}── Test clés API Mailjet ──${NC}"

    if [[ -z "$MJ_APIKEY_PUBLIC" || -z "$MJ_APIKEY_PRIVATE" ]]; then
        log_error "Aucune clé API configurée. Lancer : $0 set-keys"
        return 1
    fi

    echo -n "  Appel API Mailjet… "
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --user "${MJ_APIKEY_PUBLIC}:${MJ_APIKEY_PRIVATE}" \
        "https://api.mailjet.com/v3/REST/sender" 2>/dev/null)

    case "$http_code" in
        200) echo -e "${GREEN}OK ($http_code)${NC}"
             log_success "Clés API valides — sender vérifié." ;;
        401) echo -e "${RED}ÉCHEC ($http_code)${NC}"
             log_error "Clés API invalides (401 Unauthorized)." ;;
        *)   echo -e "${YELLOW}?? ($http_code)${NC}"
             log_warning "Réponse inattendue : $http_code" ;;
    esac
}

################################################################################
# set-keys — Configurer les clés API (interactive ou via coop-config)
################################################################################
cmd_set_keys() {
    echo ""
    echo -e "${CYAN}${BOLD}── Configuration clés API Mailjet ──${NC}"
    echo ""
    echo -e "Les clés seront stockées dans la config coopérative (Kind 30800 NOSTR)"
    echo -e "ou dans ${YELLOW}~/.zen/MJ_APIKEY${NC} si la coop-config n'est pas disponible."
    echo ""

    read -r -p "MJ_APIKEY_PUBLIC  : " new_pub
    read -r -p "MJ_APIKEY_PRIVATE : " new_priv
    read -r -p "MJ_SENDER_EMAIL   : " new_sender

    if [[ -z "$new_pub" || -z "$new_priv" || -z "$new_sender" ]]; then
        log_error "Champs incomplets — annulé."
        return 1
    fi

    if [[ -s "$COOP_CFG_SH" ]]; then
        source "$COOP_CFG_SH"
        coop_config_set "MJ_APIKEY_PUBLIC"  "$new_pub"   2>/dev/null
        coop_config_set "MJ_APIKEY_PRIVATE" "$new_priv"  2>/dev/null
        coop_config_set "MJ_SENDER_EMAIL"   "$new_sender" 2>/dev/null
        log_success "Clés sauvegardées dans cooperative-config (Kind 30800)."
    else
        cat > "$MJ_LEGACY" << ENVEOF
MJ_APIKEY_PUBLIC="$new_pub"
MJ_APIKEY_PRIVATE="$new_priv"
SENDER_EMAIL="$new_sender"
ENVEOF
        log_success "Clés sauvegardées dans ~/.zen/MJ_APIKEY (legacy)."
    fi

    # Vérification immédiate
    MJ_APIKEY_PUBLIC="$new_pub"
    MJ_APIKEY_PRIVATE="$new_priv"
    cmd_check_keys
}

################################################################################
# list — Tous les membres avec état opt-out + KIN
################################################################################
cmd_list() {
    echo ""
    echo -e "${CYAN}${BOLD}══ MEMBRES — Préférences notifications ══${NC}"
    printf "\n  %-36s %-6s %-6s %-12s %-10s %s\n" \
        "EMAIL" "EMAIL" "NOSTR" "KIN" "SCOPE" "LANGAGE"
    printf "  %-36s %-6s %-6s %-12s %-10s %s\n" \
        "────────────────────────────────────" "──────" "──────" "────────────" "──────────" "───────"

    local count=0
    while IFS= read -r -d '' mj_file; do
        local email
        email=$(echo "$mj_file" | sed "s|${NOSTR_DIR}/||;s|/.mailjet||")
        local email_ch nostr_ch kin_daily kin_weekly kin_scope kin_lang opt_str kin_str

        email_ch=$(jq -r '.email_channel // true' "$mj_file" 2>/dev/null)
        nostr_ch=$(jq -r '.nostr_channel // false' "$mj_file" 2>/dev/null)
        kin_daily=$(jq -r '.kin.daily // true' "$mj_file" 2>/dev/null)
        kin_weekly=$(jq -r '.kin.weekly // true' "$mj_file" 2>/dev/null)
        kin_scope=$(jq -r '.kin.scope // "relay"' "$mj_file" 2>/dev/null)
        kin_lang=$(jq -r '.kin.langage // "-"' "$mj_file" 2>/dev/null)

        # Opt-out global ?
        local channels
        channels=$(jq -r '.channels[]?' "$mj_file" 2>/dev/null)
        if echo "$channels" | grep -q "all"; then
            opt_str="${RED}OPT-OUT${NC}"
        elif [[ "$email_ch" == "false" ]]; then
            opt_str="${YELLOW}optout${NC}"
        else
            opt_str="${GREEN}actif ${NC}"
        fi

        if [[ "$nostr_ch" == "true" ]]; then
            nostr_str="${GREEN}actif ${NC}"
        else
            nostr_str="${YELLOW}non   ${NC}"
        fi

        if [[ "$kin_daily" == "true" || "$kin_weekly" == "true" ]]; then
            kin_str="${CYAN}daily=${kin_daily:0:1} wk=${kin_weekly:0:1}${NC}"
        else
            kin_str="${RED}désact${NC}      "
        fi

        printf "  %-36s " "${email:0:36}"
        echo -ne "${opt_str}  ${nostr_str}  ${kin_str}  %-10s %s\n" "$kin_scope" "$kin_lang"
        (( count++ ))
    done < <(find "$NOSTR_DIR" -maxdepth 2 -name ".mailjet" -print0 2>/dev/null | sort -z)

    echo ""
    echo -e "  ${CYAN}Total : ${count} membres avec préférences${NC}"
    echo ""
}

################################################################################
# optouts — Membres ayant désactivé les emails
################################################################################
cmd_optouts() {
    echo ""
    echo -e "${CYAN}${BOLD}══ OPT-OUTS EMAIL ══${NC}"
    echo ""

    local count_all=0 count_email=0
    while IFS= read -r -d '' mj_file; do
        local email channels email_ch
        email=$(echo "$mj_file" | sed "s|${NOSTR_DIR}/||;s|/.mailjet||")
        channels=$(jq -r '.channels[]?' "$mj_file" 2>/dev/null)
        email_ch=$(jq -r '.email_channel // true' "$mj_file" 2>/dev/null)

        if echo "$channels" | grep -q "all"; then
            echo -e "  ${RED}🚫 ALL   ${NC} $email"
            (( count_all++ ))
        elif [[ "$email_ch" == "false" ]] || echo "$channels" | grep -q "email"; then
            echo -e "  ${YELLOW}📧 EMAIL ${NC} $email"
            (( count_email++ ))
        fi
    done < <(find "$NOSTR_DIR" -maxdepth 2 -name ".mailjet" -print0 2>/dev/null | sort -z)

    echo ""
    [[ $((count_all + count_email)) -eq 0 ]] \
        && echo -e "  ${GREEN}Aucun opt-out enregistré.${NC}" \
        || echo -e "  ${YELLOW}Total : ${count_all} opt-out ALL, ${count_email} opt-out EMAIL${NC}"
    echo ""
}

################################################################################
# show EMAIL — Détail des préférences d'un membre
################################################################################
cmd_show() {
    local email="${1:-${OPT_EMAIL}}"
    if [[ -z "$email" ]]; then
        log_error "Usage : $0 show EMAIL"
        return 1
    fi

    local mj_file="${NOSTR_DIR}/${email}/.mailjet"
    echo ""
    echo -e "${CYAN}${BOLD}── Préférences : ${email} ──${NC}"
    echo ""

    if [[ ! -f "$mj_file" ]]; then
        log_warning "Aucun fichier .mailjet pour ${email}"
        echo -e "  Chemin attendu : ${YELLOW}${mj_file}${NC}"
        return 0
    fi

    echo -e "${YELLOW}Fichier :${NC} $mj_file"
    echo ""
    jq '.' "$mj_file"
    echo ""

    # Résumé lisible
    local email_ch nostr_ch daily weekly scope types lang
    email_ch=$(jq -r '.email_channel // true' "$mj_file")
    nostr_ch=$(jq -r '.nostr_channel // false' "$mj_file")
    daily=$(jq -r '.kin.daily // true' "$mj_file")
    weekly=$(jq -r '.kin.weekly // true' "$mj_file")
    scope=$(jq -r '.kin.scope // "relay"' "$mj_file")
    types=$(jq -r '.kin.types // [] | join(", ")' "$mj_file" 2>/dev/null)
    lang=$(jq -r '.kin.langage // "non déterminé"' "$mj_file")

    echo -e "${YELLOW}── Résumé ──${NC}"
    echo -e "  Canal email    : $([[ $email_ch == true ]] && echo "${GREEN}actif${NC}" || echo "${RED}opt-out${NC}")"
    echo -e "  Canal NOSTR    : $([[ $nostr_ch == true ]] && echo "${GREEN}actif${NC}" || echo "${YELLOW}inactif${NC}")"
    echo -e "  KIN daily      : $([[ $daily == true ]] && echo "${GREEN}activé${NC}" || echo "${RED}désactivé${NC}")"
    echo -e "  KIN weekly     : $([[ $weekly == true ]] && echo "${GREEN}activé${NC}" || echo "${RED}désactivé${NC}")"
    echo -e "  Portée scan    : ${CYAN}${scope}${NC}"
    echo -e "  Types actifs   : ${MAGENTA}${types:-tous}${NC}"
    echo -e "  Langage vibe   : ${CYAN}${lang}${NC}"
    echo ""
}

################################################################################
# kin-stats — Statistiques préférences KIN
################################################################################
cmd_kin_stats() {
    echo ""
    echo -e "${CYAN}${BOLD}══ STATISTIQUES KIN ORACLE ══${NC}"
    echo ""

    declare -A lang_count=()  scope_count=()  type_count=()
    local total=0 daily_on=0 weekly_on=0

    while IFS= read -r -d '' mj_file; do
        (( total++ ))
        local daily weekly scope lang types_arr
        daily=$(jq -r '.kin.daily // true' "$mj_file" 2>/dev/null)
        weekly=$(jq -r '.kin.weekly // true' "$mj_file" 2>/dev/null)
        scope=$(jq -r '.kin.scope // "relay"' "$mj_file" 2>/dev/null)
        lang=$(jq -r '.kin.langage // "non_défini"' "$mj_file" 2>/dev/null)
        [[ "$daily" == "true" ]]  && (( daily_on++ ))
        [[ "$weekly" == "true" ]] && (( weekly_on++ ))
        lang_count["$lang"]=$(( ${lang_count["$lang"]:-0} + 1 ))
        scope_count["$scope"]=$(( ${scope_count["$scope"]:-0} + 1 ))
        while IFS= read -r t; do
            [[ -n "$t" ]] && type_count["$t"]=$(( ${type_count["$t"]:-0} + 1 ))
        done < <(jq -r '.kin.types[]?' "$mj_file" 2>/dev/null)
    done < <(find "$NOSTR_DIR" -maxdepth 2 -name ".mailjet" -print0 2>/dev/null)

    echo -e "${YELLOW}── Membres avec préférences KIN : ${total} ──${NC}"
    echo -e "  KIN daily activé  : ${GREEN}${daily_on}${NC}"
    echo -e "  KIN weekly activé : ${GREEN}${weekly_on}${NC}"

    echo ""
    echo -e "${YELLOW}── Langages vibe ──${NC}"
    for lang in "pragmatique" "curieux" "symbolique" "cosmique" "non_défini"; do
        local n=${lang_count["$lang"]:-0}
        local bar=""
        for ((i=0; i<n; i++)); do bar+="█"; done
        printf "  %-14s : %s ${CYAN}%d${NC}\n" "$lang" "$bar" "$n"
    done

    echo ""
    echo -e "${YELLOW}── Portée scan ──${NC}"
    for scope in "relay" "n2" "n1"; do
        local n=${scope_count["$scope"]:-0}
        printf "  %-10s : ${CYAN}%d${NC}\n" "$scope" "$n"
    done

    echo ""
    echo -e "${YELLOW}── Types résonance activés ──${NC}"
    for type in "quartet" "occult" "analog" "tone" "guide" "antipode"; do
        local n=${type_count["$type"]:-0}
        printf "  %-12s : ${MAGENTA}%d${NC}\n" "$type" "$n"
    done
    echo ""
}

################################################################################
# test EMAIL — Envoyer un email de test
################################################################################
cmd_test() {
    local email="${1:-${OPT_EMAIL}}"
    if [[ -z "$email" ]]; then
        log_error "Usage : $0 test EMAIL"
        return 1
    fi

    _load_mj_credentials
    if [[ -z "$MJ_APIKEY_PUBLIC" ]]; then
        log_error "Clés API Mailjet non configurées. Lancer : $0 set-keys"
        return 1
    fi

    mkdir -p "$TEMP_DIR"
    local test_file="${TEMP_DIR}/test_mailjet.html"
    local station_url="https://astroport.${MYDOMAIN:-localhost}"

    cat > "$test_file" << HTMLEOF
<div style="font-family:monospace;background:#050a12;color:#e0f0ff;padding:24px;border-radius:8px">
  <h2 style="color:#00f5ff;letter-spacing:3px">ASTROPORT.ONE</h2>
  <p style="color:rgba(255,255,255,0.65)">
    Ceci est un <strong>email de test</strong> envoyé via dashboard.MAILJET.sh.<br>
    Si vous lisez ce message, la configuration Mailjet est correcte.
  </p>
  <hr style="border-color:rgba(0,245,255,0.15)">
  <p style="font-size:0.8rem;color:rgba(255,255,255,0.3)">
    Station : <code>${IPFSNODEID:-local}</code><br>
    Domaine : <code>${MYDOMAIN:-localhost}</code><br>
    Heure   : <code>$(date -u '+%Y-%m-%dT%H:%M:%SZ')</code>
  </p>
  <a href="${station_url}" style="color:#00f5ff">→ ${station_url}</a>
</div>
HTMLEOF

    log_info "Envoi email de test vers : $email"
    if [[ "$VERBOSE" == "true" ]]; then
        bash "$MAILJET_SH" "$email" "$test_file" "Test station UPlanet — $(date +%Y-%m-%d)"
    else
        bash "$MAILJET_SH" "$email" "$test_file" "Test station UPlanet — $(date +%Y-%m-%d)" \
            > /dev/null 2>&1
        log_success "Email de test envoyé (voir mailjet.log pour le résultat)."
    fi
    rm -f "$test_file"
}

################################################################################
# send EMAIL FILE SUBJECT — Envoi manuel
################################################################################
cmd_send() {
    local email="$1" msg_file="$2" subject="$3"
    if [[ -z "$email" || -z "$msg_file" || -z "$subject" ]]; then
        log_error "Usage : $0 send EMAIL FICHIER_HTML SUJET"
        return 1
    fi
    if [[ ! -f "$msg_file" ]]; then
        log_error "Fichier introuvable : $msg_file"
        return 1
    fi
    _load_mj_credentials
    if [[ -z "$MJ_APIKEY_PUBLIC" ]]; then
        log_error "Clés API non configurées."
        return 1
    fi
    log_info "Envoi vers $email — sujet : $subject"
    bash "$MAILJET_SH" "$email" "$msg_file" "$subject"
}

################################################################################
# logs [N] — Afficher le log mailjet
################################################################################
cmd_logs() {
    local n="${1:-50}"
    echo ""
    echo -e "${CYAN}${BOLD}── Log Mailjet (${n} dernières lignes) ──${NC}"
    echo -e "${YELLOW}Fichier : ${MAILJET_LOG}${NC}"
    echo ""
    if [[ -f "$MAILJET_LOG" ]]; then
        tail -"$n" "$MAILJET_LOG" | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}Log vide ou absent : $MAILJET_LOG${NC}"
    fi
    echo ""
}

################################################################################
# browse — Navigateur interactif
################################################################################
cmd_browse() {
    while true; do
        echo ""
        echo -e "${CYAN}${BOLD}══ MAILJET MANAGER — Menu principal ══${NC}"
        echo ""
        echo -e "  ${YELLOW}1${NC}) Status & config"
        echo -e "  ${YELLOW}2${NC}) Lister les membres"
        echo -e "  ${YELLOW}3${NC}) Opt-outs"
        echo -e "  ${YELLOW}4${NC}) Stats KIN Oracle"
        echo -e "  ${YELLOW}5${NC}) Vérifier les clés API"
        echo -e "  ${YELLOW}6${NC}) Configurer les clés API"
        echo -e "  ${YELLOW}7${NC}) Afficher préférences d'un membre"
        echo -e "  ${YELLOW}8${NC}) Envoyer email de test"
        echo -e "  ${YELLOW}9${NC}) Logs (50 dernières lignes)"
        echo -e "  ${YELLOW}q${NC}) Quitter"
        echo ""
        read -r -p "  Choix : " choice
        case "$choice" in
            1) cmd_status ;;
            2) cmd_list ;;
            3) cmd_optouts ;;
            4) cmd_kin_stats ;;
            5) cmd_check_keys ;;
            6) cmd_set_keys ;;
            7)
                read -r -p "  Email du membre : " em
                cmd_show "$em"
                ;;
            8)
                read -r -p "  Email du destinataire : " em
                cmd_test "$em"
                ;;
            9) cmd_logs 50 ;;
            q|Q|quit|exit) echo ""; log_info "Au revoir."; break ;;
            *) log_warning "Choix invalide." ;;
        esac
        echo ""
        read -r -p "  [Entrée pour continuer]"
    done
}

################################################################################
# Cleanup
################################################################################
cleanup() { rm -rf "$TEMP_DIR" 2>/dev/null; }
trap cleanup EXIT

################################################################################
# Parsing des options globales
################################################################################
OPT_EMAIL="" VERBOSE="false" FORCE="false"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --email)  OPT_EMAIL="$2"; shift 2 ;;
        --verbose) VERBOSE="true"; shift ;;
        --force)   FORCE="true"; shift ;;
        --help|-h) usage ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done
set -- "${POSITIONAL[@]}"

COMMAND="${1:-browse}"
shift || true

################################################################################
# Dispatch
################################################################################
case "$COMMAND" in
    status)       cmd_status ;;
    check-keys)   cmd_check_keys ;;
    set-keys)     cmd_set_keys ;;
    list)         cmd_list ;;
    optouts)      cmd_optouts ;;
    show)         cmd_show "${1:-$OPT_EMAIL}" ;;
    kin-stats)    cmd_kin_stats ;;
    test)         cmd_test "${1:-$OPT_EMAIL}" ;;
    send)         cmd_send "$1" "$2" "$3" ;;
    logs)         cmd_logs "${1:-50}" ;;
    browse)       cmd_browse ;;
    help|--help)  usage ;;
    *)
        log_error "Commande inconnue : $COMMAND"
        echo "Lancer '$0 help' pour la liste des commandes."
        exit 1
        ;;
esac
