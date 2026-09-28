#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# log_observation.sh
# Observation des logs de l'écosystème UPlanet — outil unique (remplace
# log_file_watch.sh, fusionné ici).
#
# Tout part du CATALOGUE ci-dessous : une ligne = une source réellement écrite
# par le code (vérifié par grep dans Astroport.ONE / UPassport / NIP-101).
# Pour suivre un nouveau traitement, ajouter une ligne — rien d'autre à toucher.
#
# Script de terminal autonome : ne source pas tools/my.sh.
################################################################################

T="$HOME/.zen/tmp"
L="$HOME/.zen/log"
# Node local (même convention que NIP-101/relay.writePolicy.plugin/filter/common.sh)
IPFSNODEID=$(jq -r '.Identity.PeerID // empty' "$HOME/.ipfs/config" 2>/dev/null)
NODE_ACTIVITY_LOG="$T/${IPFSNODEID:-_local}/observability/node-activity.jsonl"

################################################################################
# GROUPES : clé|emoji|titre
################################################################################
GROUPS_DEF=(
    "core|📡|Station Astroport (12345, 20h12, observabilité JSONL)"
    "bro|🤖|BRO / IA (daemon DM NIP-44, responder, N², pool NOSTR)"
    "facecloud|👁️|FaceCloud — reconnaissance faciale des images /dav/"
    "roaming|✈️|Roaming & swarm P2P (tunnels IPFS, sync uDRIVE, intrus)"
    "multipass|🎫|MULTIPASS (refresh, sync forums, restrictions ZenCard)"
    "upassport|🗝️|UPassport API 54321 (routes, tâches admin, mailjet)"
    "media|📹|Upload & médias (ajouter_media, YouTube, TMDB)"
    "economy|💰|Économie ẐEN / Ğ1 (ZEN.ECONOMY, paiements, OC webhook)"
    "relay|🌐|Relay NOSTR strfry + filtres NIP-101 par kind"
    "system|📦|IPFS, Docker, installation"
)

################################################################################
# CATALOGUE : groupe|TAG|source|filtre ERE (optionnel, insensible à la casse)
#   source = chemin (glob accepté, développé au démarrage) ou journal:<unité>
#   Un même fichier peut figurer dans plusieurs groupes avec des filtres
#   différents ; si plusieurs groupes sont suivis ensemble et que l'un d'eux
#   prend le fichier en brut, les vues filtrées de ce fichier sont omises.
################################################################################
CATALOG=(
    # ── core ────────────────────────────────────────────────────────────────
    "core|ASTROPORT|journal:astroport|"
    "core|API-12345|$T/12345.log|"                      # launch.sh
    "core|GEOKEYS|$T/_12345.log|"                       # RUNTIME/GEOKEYS_refresh.sh
    "core|ACCESS|$T/12345_access.log|"                  # _12345.sh
    "core|20H12|$L/20h12_$(date +%Y%m%d).log|"          # 20h12.process.sh (exec >> du jour)
    "core|20H12-CRON|$L/20h12.log|"                     # crontab : sortie avant l'exec seulement
    "core|BOOTSTRAP|$T/bootstrap_on_start.log|"         # admin/system/cron_VRFY.sh
    "core|NODE-JSON|$NODE_ACTIVITY_LOG|"                # bro_log_event / observability.py

    # ── bro ─────────────────────────────────────────────────────────────────
    "bro|IA|$T/IA.log|"                                 # _log de tous les scripts IA
    "bro|BRO-DM|$T/bro_dm_daemon.log|"                  # IA/bro/bro_dm_daemon.sh (lancé par _12345.sh)
    "bro|UDRIVE-PUB|$T/bro_udrive_republish.log|"       # bro_dm_daemon.sh
    "bro|NEXTCLOUD|$T/nextcloud_sync.log|"              # IA/bro/nextcloud_bro_sync.sh
    "bro|N2|$T/N2.journal.log|"                         # IA/N2.journal.sh
    "bro|POOL|$T/nostr_pool_daemon.log|"                # tools/nostr_pool_daemon.py
    "bro|PLANTNET|$T/plantnet.log|"                     # IA/plantnet_recognition.py
    "bro|INVENTORY|$T/inventory.log|"                   # IA/inventory_recognition.py

    # ── facecloud : PUT /dav/ → trigger → Brain (faceid.sh) → matcher ──────
    "facecloud|1-DAV|$T/54321.log|ucloud|faceid"                     # cloud_storage.py
    "facecloud|2-TRIGGER|$T/bro_vision_trigger.log|"                 # trigger_bro_vision_analysis.sh
    "facecloud|3-BRAIN|$T/bro_dm_daemon.log|vision|faceid|👁"         # faceid.sh + satellite_face_matcher.py
    "facecloud|3-SCENE|$T/faceid_scene.log|"                         # faceid.sh (0 visage)
    "facecloud|4-MATCH|$T/IA.log|vision|faceid|👁"

    # ── roaming ─────────────────────────────────────────────────────────────
    "roaming|ROAM-MON|$T/roaming_bro_monitor.log|"      # admin/monitor/roaming.bro.NODE44.sh
    "roaming|ROAM-DM|$T/bro_dm_daemon.log|roaming|✈|udrive|intercom"
    "roaming|ROAM-IA|$T/IA.log|roaming|✈"
    "roaming|ROAM-CARD|$T/MULTIPASS.refresh.log|roaming|✈|swarm"
    "roaming|TUNNEL|$T/tunnel.log|"                     # astrosystemctl.sh / tunnel.sh
    "roaming|INTRUS|$T/swarm_intruders.log|"            # _12345.sh

    # ── multipass ───────────────────────────────────────────────────────────
    "multipass|CARD-RUN|$T/nostrcard_refresh.log|"      # _12345.sh → NOSTRCARD.refresh.sh
    "multipass|CARD|$T/MULTIPASS.refresh.log|"          # RUNTIME/NOSTRCARD.refresh.sh
    "multipass|FORUM-SYNC|$T/*_sync_*.log|"             # NOSTRCARD.refresh.sh / IA/bro/media.py
    "multipass|ZENCARD|$T/zencard_restrictions.log|"    # RUNTIME/VISA.new.sh
    "multipass|PROFILE|$T/hex-to-profile.log|"          # tools/nostr_hex_to_profile.sh

    # ── upassport ───────────────────────────────────────────────────────────
    "upassport|UPASSPORT|journal:upassport|"
    "upassport|API-54321|$T/54321.log|"                 # UPassport/core/logging.py
    "upassport|MAILJET|$T/mailjet.log|"                 # tools/mailjet.sh
    "upassport|PURGE|$T/purge_nostr_strangers.log|"     # routers/node_admin.py
    "upassport|DESTROY-TW|$T/nostr_destroy_tw.log|"     # routers/node_admin.py
    "upassport|SYNASTRY|$T/kin_synastry_trigger.log|"   # routers/node_admin.py

    # ── media ───────────────────────────────────────────────────────────────
    "media|MEDIA|$T/ajouter_media.log|"                 # ajouter_media.sh, process_youtube.sh
    "media|UPLOAD|$T/upload2ipfs.log|"                  # ajouter_media.sh
    "media|API-UP|$T/54321.log|upload|ipfs add|media"
    "media|IA-MEDIA|$T/IA.log|youtube|yt-dlp|tmdb"      # youtube.com.sh écrit dans IA.log
    "media|NODE-JSON|$NODE_ACTIVITY_LOG|\"category\": \"(media|youtube|tmdb)\""

    # ── economy ─────────────────────────────────────────────────────────────
    "economy|20H12-ZEN|$L/20h12_$(date +%Y%m%d).log|zen|economy|paf|g1|payforsure|treasury"
    "economy|API-FIN|$T/54321.log|zen_send|oc_webhook|balance|finance"
    "economy|NODE-JSON|$NODE_ACTIVITY_LOG|\"category\": \"finance\""

    # ── relay : relay.writePolicy.plugin/filter/<kind>.sh ──────────────────
    "relay|STRFRY|journal:strfry|"
    "relay|RELAY|$T/strfry.log|"
    "relay|K0|$T/nostr_kind0.log|"
    "relay|K1|$T/nostr_kind1_messages.log|"
    "relay|K4-DM|$T/nostr_kind4_dm.log|"
    "relay|K5|$T/nostr_kind5.log|"
    "relay|K7|$T/nostr_likes.log|"
    "relay|K1059|$T/nostr_kind1059_giftwrap.log|"
    "relay|K1984|$T/nostr_reports.1984.log|"
    "relay|JUSTICE|$T/justice_cases.log|"
    "relay|K9735|$T/nostr_zaps.9735.log|"
    "relay|K22242|$T/nostr.auth.22242.log|"
    "relay|K30023|$T/nostr_kind30023.log|"
    "relay|K30078|$T/nostr_statuses.30078.log|"
    "relay|ATOM4LOVE|$T/nostr_atom4love.log|"
    "relay|K30303|$T/nostr_kind30303.log|"
    "relay|K30500|$T/nostr_kind30500.log|"
    "relay|K30506|$T/nostr_kind30506.log|"
    "relay|K30508|$T/nostr_kind30508.log|"
    "relay|K30800|$T/nostr_30800.log|"
    "relay|K30850|$T/nostr_kind30850.log|"
    "relay|K30851|$T/nostr_kind30851.log|"
    "relay|K30852|$T/nostr_kind30852.log|"
    "relay|K30904|$T/nostr_crowdfunding.log|"

    # ── system ──────────────────────────────────────────────────────────────
    "system|IPFS|journal:ipfs|"
    "system|DOCKER|$T/docker_admin.log|"                # admin/docker.sh
    "system|SWALLOW|$T/swallow_me.log|"                 # tools/swallow_me.sh
    "system|INSTALL|$L/install.log|"
    "system|INSTALL-ERR|$L/install.errors.log|"
    "system|POWERJOULAR|$T/powerjoular_build.log|"      # install/install_powerjoular.sh
)

################################################################################
# Couleurs (désactivables par --no-color ou si stdout n'est pas un terminal)
################################################################################
set_colors() {
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
        BLUE='\033[0;34m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
        PALETTE=('\033[0;36m' '\033[0;35m' '\033[0;33m' '\033[0;32m' '\033[0;34m'
                 '\033[1;36m' '\033[1;35m' '\033[1;33m' '\033[1;32m' '\033[1;34m')
    else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; DIM=''; NC=''
        PALETTE=('')
    fi
}

################################################################################
# Accès au catalogue
################################################################################
group_keys() { local g; for g in "${GROUPS_DEF[@]}"; do echo "${g%%|*}"; done; }

group_title() {
    local g
    for g in "${GROUPS_DEF[@]}"; do
        [[ "${g%%|*}" == "$1" ]] && { local r="${g#*|}"; echo "${r%%|*} ${r#*|}"; return; }
    done
}

is_group() { group_keys | grep -qxF "$1"; }

# Couleur stable par groupe (index dans GROUPS_DEF)
group_color() {
    local i=0 g
    for g in "${GROUPS_DEF[@]}"; do
        [[ "${g%%|*}" == "$1" ]] && { echo "${PALETTE[$(( i % ${#PALETTE[@]} ))]}"; return; }
        i=$((i + 1))
    done
}

# Entrées d'un groupe, ou de tous si $1 vide. Sortie : groupe|TAG|source|filtre
entries_of() {
    local e
    for e in "${CATALOG[@]}"; do
        [[ -z "$1" || "${e%%|*}" == "$1" ]] && echo "$e"
    done
}

# Développe un glob ; renvoie le motif tel quel s'il ne matche rien.
expand_source() {
    local src="$1" f found=0
    if [[ "$src" == *'*'* ]]; then
        for f in $src; do [[ -e "$f" ]] && { echo "$f"; found=1; }; done
        (( found )) || echo "$src"
    else
        echo "$src"
    fi
}

unit_exists() { systemctl list-unit-files "$1.service" 2>/dev/null | grep -q "^$1.service"; }

human_age() {
    local s=$1
    if   (( s < 60 ));    then echo "${s}s"
    elif (( s < 3600 ));  then echo "$((s / 60))min"
    elif (( s < 86400 )); then echo "$((s / 3600))h"
    else                       echo "$((s / 86400))j"
    fi
}

################################################################################
# --check : disponibilité, taille, fraîcheur
################################################################################
check_group() {
    local grp="$1" e _g tag src filter f now size lines age
    now=$(date +%s)
    echo ""
    echo -e "${BLUE}$(group_title "$grp")${NC}  ${DIM}[$grp]${NC}"
    while IFS= read -r e; do
        IFS='|' read -r _g tag src filter <<< "$e"
        filter="${e#*|*|*|}"; [[ "$filter" == "$e" ]] && filter=""
        if [[ "$src" == journal:* ]]; then
            local unit="${src#journal:}"
            if systemctl is-active --quiet "$unit" 2>/dev/null; then
                printf "  ${GREEN}✅${NC} %-12s journalctl -u %s ${GREEN}(actif)${NC}\n" "$tag" "$unit"
            elif unit_exists "$unit"; then
                printf "  ${YELLOW}⚠️ ${NC} %-12s journalctl -u %s ${YELLOW}(inactif)${NC}\n" "$tag" "$unit"
            else
                printf "  ${DIM}—  %-12s journalctl -u %s (unité absente)${NC}\n" "$tag" "$unit"
            fi
            continue
        fi
        while IFS= read -r f; do
            if [[ -f "$f" ]]; then
                size=$(du -h "$f" 2>/dev/null | cut -f1)
                lines=$(wc -l < "$f" 2>/dev/null)
                age=$(human_age $(( now - $(stat -c %Y "$f") )))
                printf "  ${GREEN}✅${NC} %-12s %s ${DIM}(%s, %s lignes, modifié il y a %s)%s${NC}\n" \
                    "$tag" "${f/#$HOME/\~}" "$size" "$lines" "$age" "${filter:+ filtre: $filter}"
            else
                printf "  ${DIM}·  %-12s %s (pas encore créé)${NC}\n" "$tag" "${f/#$HOME/\~}"
            fi
        done < <(expand_source "$src")
    done < <(entries_of "$grp")
}

check_all() {
    echo -e "${CYAN}🔍 DISPONIBILITÉ DES LOGS${NC}  ${DIM}(· = créé à la première écriture, normal)${NC}"
    local grp groups=("$@")
    (( ${#groups[@]} )) || mapfile -t groups < <(group_keys)
    for grp in "${groups[@]}"; do check_group "$grp"; done
    echo ""
}

################################################################################
# Observation
################################################################################
# Lance un suiveur : source (fichier ou journal:unité), TAG, filtre, couleur
start_watcher() {
    local src="$1" tag="$2" filter="$3" color="$4"
    local prefix="${color}[${tag}]${NC} "
    {
        if [[ "$src" == journal:* ]]; then
            journalctl -n "$LINES_BACK" -f -u "${src#journal:}" -o short 2>/dev/null
        else
            # -F : suit aussi un fichier pas encore créé ou tourné (logrotate)
            tail -n "$LINES_BACK" -F "$src" 2>/dev/null
        fi
    } | {
        if [[ -n "$filter" ]]; then grep --line-buffered -iE -- "$filter"; else cat; fi
    } | {
        if [[ -n "$GLOBAL_GREP" ]]; then grep --line-buffered -iE -- "$GLOBAL_GREP"; else cat; fi
    } | sed -u "s/^/$(printf '%b' "$prefix" | sed 's/[&/\]/\\&/g')/" &
    WATCHER_PGIDS+=("$(ps -o pgid= -p "$!" | tr -d ' ')")
}

# watch_groups GRP... : un fichier déjà suivi en brut (sans filtre) n'est pas
# suivi une seconde fois via une vue filtrée — le flux brut la contient déjà.
watch_groups() {
    local grp e _g tag src filter f color
    declare -A seen=() raw=()
    local plan=()

    for grp in "$@"; do
        while IFS= read -r e; do
            IFS='|' read -r _g tag src _ <<< "$e"
            filter="${e#*|*|*|}"; [[ "$filter" == "$e" ]] && filter=""
            [[ "$src" == journal:* ]] && { unit_exists "${src#journal:}" || continue; }
            while IFS= read -r f; do
                [[ -z "$filter" ]] && raw["$f"]=1
                plan+=("$grp|$tag|$f|$filter")
            done < <(expand_source "$src")
        done < <(entries_of "$grp")
    done

    local n=0 p
    for p in "${plan[@]}"; do
        IFS='|' read -r grp tag f _ <<< "$p"
        filter="${p#*|*|*|}"; [[ "$filter" == "$p" ]] && filter=""
        [[ -n "$filter" && -n "${raw[$f]:-}" ]] && continue
        local key="$f|$filter"
        [[ -n "${seen[$key]:-}" ]] && continue
        seen["$key"]=1
        color=$(group_color "$grp")
        start_watcher "$f" "$tag" "$filter" "$color"
        printf "  ${DIM}→ %-12s %s%s${NC}\n" "$tag" "${f/#$HOME/\~}" "${filter:+  ⟨$filter⟩}"
        n=$((n + 1))
    done

    echo ""
    echo -e "${GREEN}📋 ${n} flux suivis${NC}${GLOBAL_GREP:+ — filtre global ⟨$GLOBAL_GREP⟩}. ${YELLOW}Ctrl+C pour arrêter.${NC}"
    echo ""
    wait
}

# Chaque suiveur tourne dans son propre groupe de processus (set -m) : un seul
# kill par groupe arrête tail/grep/sed d'un coup — et seulement CEUX de ce
# script (jamais un killall tail global).
stop_watchers() {
    local g
    # set +m le temps du kill : sinon bash affiche un « [n] Terminated … »
    # par suiveur.
    set +m
    for g in "${WATCHER_PGIDS[@]}"; do kill -TERM -- "-$g" 2>/dev/null; done
    WATCHER_PGIDS=()
    wait 2>/dev/null
    jobs >/dev/null 2>&1   # purge les notifications de fin de tâche en attente
    set -m
}

################################################################################
# Menu
################################################################################
show_menu() {
    MENU_MODE=1
    local keys choice i
    mapfile -t keys < <(group_keys)
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║        🔍 OBSERVATION DES LOGS UPLANET             ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
        echo ""
        for i in "${!keys[@]}"; do
            printf "  ${GREEN}%2d)${NC} %s\n" $((i + 1)) "$(group_title "${keys[$i]}")"
        done
        echo ""
        echo -e "  ${GREEN} a)${NC} 🚀 Tous les logs"
        echo -e "  ${GREEN} c)${NC} 📊 Vérifier la disponibilité"
        echo -e "  ${GREEN} g)${NC} 🔎 Filtre global ${DIM}(actuel : ${GLOBAL_GREP:-aucun})${NC}"
        echo -e "  ${GREEN} q)${NC} ❌ Quitter"
        echo ""
        read -r -p "Choix (plusieurs numéros possibles, ex: 3 4) : " choice || exit 0
        case "$choice" in
            q|Q|0) exit 0 ;;
            c|C)   check_all; read -r -p "ENTRÉE pour continuer…" _ ;;
            g|G)   read -r -p "Regex (vide = aucun) : " GLOBAL_GREP ;;
            a|A)   clear; watch_groups "${keys[@]}" ;;
            *)
                local sel=() n
                for n in $choice; do
                    [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#keys[@]} )) && sel+=("${keys[$((n - 1))]}")
                done
                if (( ${#sel[@]} )); then clear; watch_groups "${sel[@]}"
                else echo -e "${RED}❌ Choix invalide${NC}"; sleep 1; fi
                ;;
        esac
    done
}

################################################################################
# Aide
################################################################################
show_help() {
    local k
    echo "
🔍 LOG OBSERVATION — Écosystème UPlanet

USAGE:
    ./log_observation.sh [OPTIONS] [GROUPE...]

    (sans groupe)      suit tous les logs
    GROUPE...          suit uniquement ces groupes (ex: facecloud, bro roaming)

OPTIONS:
    -m, --menu         menu interactif (plusieurs groupes à la fois)
    -c, --check [G…]   disponibilité / taille / fraîcheur des logs
    -l, --list         liste des groupes et des sources
    -g, --grep REGEX   filtre global (ex: un email, un CID, un HEX)
    -n, --lines N      afficher les N dernières lignes au démarrage (défaut 0)
        --no-color     sortie sans couleurs
    -h, --help         cette aide

GROUPES:"
    for k in $(group_keys); do printf "    %-11s %s\n" "$k" "$(group_title "$k")"; done
    echo "
EXEMPLES:
    ./log_observation.sh facecloud                 # suivre une image téléversée sur /dav/
    ./log_observation.sh -g fred@qo-op.com bro roaming
    ./log_observation.sh -n 50 relay               # contexte récent + temps réel
    ./log_observation.sh --check facecloud

Les lignes sont préfixées [TAG] ; dans facecloud, 1-…4- donnent l'ordre du
pipeline (DAV → trigger → Brain → matcher). Sources : voir CATALOG dans ce script.
"
}

list_catalog() {
    local grp e _g tag src filter
    for grp in $(group_keys); do
        echo -e "${BLUE}$(group_title "$grp")${NC}  ${DIM}[$grp]${NC}"
        while IFS= read -r e; do
            IFS='|' read -r _g tag src _ <<< "$e"
            filter="${e#*|*|*|}"; [[ "$filter" == "$e" ]] && filter=""
            printf "    %-12s %s${DIM}%s${NC}\n" "$tag" "${src/#$HOME/\~}" "${filter:+  ⟨$filter⟩}"
        done < <(entries_of "$grp")
    done
}

################################################################################
# Point d'entrée
################################################################################
LINES_BACK=0
GLOBAL_GREP=""
WATCHER_PGIDS=()
# shellcheck disable=SC2034  # MENU_MODE est lu dans le trap INT
MENU_MODE=0
MODE=watch
SELECTED=()

while (( $# )); do
    case "$1" in
        -h|--help)  MODE=help ;;
        -m|--menu)  MODE=menu ;;
        -c|--check) MODE=check ;;
        -l|--list)  MODE=list ;;
        -g|--grep)  GLOBAL_GREP="${2:-}"; shift ;;
        -n|--lines) LINES_BACK="${2:-0}"; shift ;;
        --no-color) NO_COLOR=1 ;;
        -*)         echo "❌ Option inconnue : $1 (voir --help)"; exit 1 ;;
        *)
            is_group "$1" || { echo "❌ Groupe inconnu : $1 — groupes : $(group_keys | tr '\n' ' ')"; exit 1; }
            SELECTED+=("$1")
            ;;
    esac
    shift
done
[[ "$LINES_BACK" =~ ^[0-9]+$ ]] || { echo "❌ --lines attend un entier"; exit 1; }

set_colors
# Contrôle de tâches : un groupe de processus par suiveur (cf. stop_watchers).
# Ctrl+C n'atteint alors que ce script, dont le trap arrête les suiveurs.
set -m

# Ctrl+C : en menu on revient au menu, sinon on quitte — toujours proprement.
trap 'stop_watchers; (( MENU_MODE )) || { echo; exit 0; }' INT TERM
trap 'stop_watchers' EXIT

case "$MODE" in
    help)  show_help ;;
    list)  list_catalog ;;
    check) check_all "${SELECTED[@]}" ;;
    menu)  show_menu ;;
    watch)
        (( ${#SELECTED[@]} )) || mapfile -t SELECTED < <(group_keys)
        echo -e "${GREEN}🚀 Observation : ${SELECTED[*]}${NC}"
        watch_groups "${SELECTED[@]}"
        ;;
esac
