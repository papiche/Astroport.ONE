#!/bin/bash
################################################################################
## strfry Swarm Connector
## Checks for local strfry NOSTR relay on port 7777
## Fallback to IPFS P2P swarm discovery (x_strfry.sh → port 9999)
################################################################################
## ZEN[0] Swarm Integration - strfry Relay Connection Manager
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../Astroport.ONE/tools/my.sh" 2>/dev/null || true

# Configuration
STRFRY_LOCAL_PORT=7777
STRFRY_P2P_PORT=9999
SERVICE_NAME="strfry"
STRFRY_BIN="${HOME}/.zen/strfry/strfry"
STRFRY_PID="${HOME}/.zen/strfry/.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

STATUS_FILE="$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"

########################################################
## Helper Functions
########################################################

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}strfry NOSTR Relay Connection Manager${NC}  (port $STRFRY_LOCAL_PORT)  ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

print_status() {
    case "$1" in
        "OK")     echo -e "  ${GREEN}✓${NC} $2" ;;
        "FAIL")   echo -e "  ${RED}✗${NC} $2" ;;
        "WARN")   echo -e "  ${YELLOW}⚠${NC} $2" ;;
        "INFO")   echo -e "  ${BLUE}ℹ${NC} $2" ;;
        "ACTIVE") echo -e "  ${GREEN}●${NC} $2 ${GREEN}[ACTIVE]${NC}" ;;
        *)        echo -e "  $2" ;;
    esac
}

save_connection_status() {
    local conn_type="$1"
    local details="$2"
    local relay_url="$3"
    mkdir -p "$(dirname "$STATUS_FILE")"
    {
        echo "CONNECTION_TYPE=$conn_type"
        echo "CONNECTION_DETAILS=$details"
        echo "CONNECTION_TIME=$(date -Iseconds)"
        echo "RELAY_URL=$relay_url"
    } > "$STATUS_FILE"
}

########################################################
## Detection Functions
########################################################

check_port() {
    local port="${1:-$STRFRY_LOCAL_PORT}"
    ss -tln 2>/dev/null | grep -qw ":${port}"
}

# Test relay HTTP handshake on given port (strfry responds to plain HTTP)
test_relay() {
    local port="${1:-$STRFRY_LOCAL_PORT}"
    local resp
    resp=$(curl -sf --connect-timeout 5 "http://localhost:${port}" 2>&1)
    # strfry replies with "Please use a Nostr client" or similar non-empty body
    [[ -n "$resp" ]]
}

check_local_service() {
    local silent="${1:-false}"

    # Check running process
    if [[ -f "$STRFRY_PID" ]]; then
        local pid
        pid=$(cat "$STRFRY_PID" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            [[ "$silent" != "true" ]] && print_status "OK" "strfry process running (PID $pid)"
            return 0
        fi
    fi
    # Fallback: check port
    if check_port "$STRFRY_LOCAL_PORT"; then
        [[ "$silent" != "true" ]] && print_status "OK" "strfry relay detected on port $STRFRY_LOCAL_PORT"
        return 0
    fi
    return 1
}

check_p2p_connections() {
    local silent="${1:-false}"
    local p2p_conns
    p2p_conns=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | wc -l)
    if [[ $p2p_conns -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "ACTIVE" "IPFS P2P (${p2p_conns} connexion(s))"
        return 0
    fi
    return 1
}

count_p2p_nodes() {
    local count=0
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        [[ -f "$script" ]] && ((count++))
    done
    echo $count
}

# Show strfry DB stats if binary available
show_stats() {
    [[ ! -x "$STRFRY_BIN" ]] && return
    local count
    count=$(cd "$(dirname "$STRFRY_BIN")" && ./strfry stats 2>/dev/null | grep -i "total\|events" | head -3)
    [[ -n "$count" ]] && echo -e "\n${BOLD}Relay Stats:${NC}\n$count"
}

########################################################
## Connection Functions
########################################################

connect_via_swarm() {
    local target="${1:-}"

    echo -e "\n${BOLD}Connecting via IPFS P2P swarm...${NC}"

    local nodes=()
    local node_ids=()

    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        if [[ -f "$script" ]]; then
            nodes+=("$script")
            node_ids+=("$(basename "$(dirname "$script")")")
        fi
    done

    if [[ ${#nodes[@]} -eq 0 ]]; then
        print_status "FAIL" "Aucun nœud strfry trouvé dans le swarm"
        return 1
    fi

    local selected_script="" selected_node=""

    if [[ -n "$target" ]]; then
        case "$target" in
            "auto"|"random"|"AUTO"|"RANDOM")
                local shuffled
                mapfile -t shuffled < <(printf '%s\n' "${!nodes[@]}" | sort -R)
                for idx in "${shuffled[@]}"; do
                    selected_script="${nodes[$idx]}"
                    selected_node="${node_ids[$idx]}"
                    echo "Essai nœud : $selected_node"
                    if bash "$selected_script" 2>/dev/null; then
                        sleep 2
                        if test_relay "$STRFRY_P2P_PORT"; then
                            save_connection_status "P2P" "$selected_node" "ws://127.0.0.1:$STRFRY_P2P_PORT"
                            print_status "OK" "Connecté à $selected_node via IPFS P2P"
                            return 0
                        fi
                        ipfs p2p close -p "/x/${SERVICE_NAME}-${selected_node}" 2>/dev/null
                    fi
                done
                print_status "FAIL" "Aucun nœud disponible"
                return 1
                ;;
            [0-9]|[0-9][0-9])
                local idx=$((target - 1))
                if [[ $idx -ge 0 && $idx -lt ${#nodes[@]} ]]; then
                    selected_script="${nodes[$idx]}"
                    selected_node="${node_ids[$idx]}"
                else
                    print_status "FAIL" "Sélection invalide : $target (valide : 1-${#nodes[@]})"
                    return 1
                fi
                ;;
            *)
                for i in "${!node_ids[@]}"; do
                    if [[ "${node_ids[$i]}" == "$target" || "${node_ids[$i]}" == *"$target"* ]]; then
                        selected_script="${nodes[$i]}"
                        selected_node="${node_ids[$i]}"
                        break
                    fi
                done
                if [[ -z "$selected_script" ]]; then
                    print_status "FAIL" "Nœud introuvable : $target"
                    echo -e "\nNœuds disponibles :"
                    for i in "${!node_ids[@]}"; do
                        echo -e "  [$((i+1))] ${node_ids[$i]:0:30}..."
                    done
                    return 1
                fi
                ;;
        esac
    else
        # Sélection aléatoire parmi les nœuds disponibles (appelé programmatiquement)
        local shuffled
        mapfile -t shuffled < <(printf '%s\n' "${!nodes[@]}" | sort -R)
        for idx in "${shuffled[@]}"; do
            selected_script="${nodes[$idx]}"
            selected_node="${node_ids[$idx]}"
            echo "Essai nœud : ${selected_node:0:20}..."
            if bash "$selected_script" 2>/dev/null; then
                sleep 2
                if test_relay "$STRFRY_P2P_PORT"; then
                    save_connection_status "P2P" "$selected_node" "ws://127.0.0.1:$STRFRY_P2P_PORT"
                    print_status "OK" "Connecté à $selected_node via IPFS P2P"
                    return 0
                fi
                ipfs p2p close -p "/x/${SERVICE_NAME}-${selected_node}" 2>/dev/null
            fi
        done
        print_status "FAIL" "Aucun nœud swarm disponible"
        return 1
    fi

    if [[ -n "$selected_script" ]]; then
        echo "Connexion à : $selected_node"
        if bash "$selected_script" 2>/dev/null; then
            sleep 2
            if test_relay "$STRFRY_P2P_PORT"; then
                save_connection_status "P2P" "$selected_node" "ws://127.0.0.1:$STRFRY_P2P_PORT"
                print_status "OK" "Connecté à $selected_node via IPFS P2P"
                return 0
            else
                ipfs p2p close -p "/x/${SERVICE_NAME}-${selected_node}" 2>/dev/null
                print_status "FAIL" "Connecté mais relay ne répond pas (port $STRFRY_P2P_PORT)"
                return 1
            fi
        else
            print_status "FAIL" "Échec connexion P2P vers $selected_node"
            return 1
        fi
    fi

    return 1
}

close_ipfs_p2p() {
    local silent="${1:-false}"
    local closed=0

    for conn in $(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $1}'); do
        ipfs p2p close -p "$conn" 2>/dev/null && ((closed++))
    done

    if [[ $closed -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "OK" "$closed connexion(s) P2P fermée(s)"
        rm -f "$STATUS_FILE"
        return 0
    fi
    [[ "$silent" != "true" ]] && print_status "INFO" "Pas de connexions P2P à fermer"
    return 1
}

########################################################
## Command Handlers
########################################################

cmd_status() {
    print_header
    echo -e "\n${BOLD}État de connexion :${NC}"

    local active_type="NONE" active_details="" relay_url=""

    if check_p2p_connections "true" && check_port "$STRFRY_P2P_PORT"; then
        active_type="P2P"
        relay_url="ws://127.0.0.1:$STRFRY_P2P_PORT"
        if [[ -f "$STATUS_FILE" ]]; then
            # shellcheck source=/dev/null
            source "$STATUS_FILE"
            active_details="$CONNECTION_DETAILS"
            relay_url="${RELAY_URL:-$relay_url}"
        else
            active_details=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $3}' | head -1)
        fi
        if test_relay "$STRFRY_P2P_PORT"; then
            echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTÉ${NC} via ${CYAN}P2P${NC}"
            [[ -n "$active_details" ]] && echo -e "    └─ Nœud : $active_details"
            echo -e "    └─ Relay : ${GREEN}${relay_url}${NC}"
            return 0
        fi
    fi

    if check_local_service "true" && test_relay "$STRFRY_LOCAL_PORT"; then
        active_type="LOCAL"
        relay_url="${myRELAY:-ws://127.0.0.1:$STRFRY_LOCAL_PORT}"
        echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTÉ${NC} via ${CYAN}LOCAL${NC}"
        echo -e "    └─ Relay : ${GREEN}${relay_url}${NC}"
        show_stats
        return 0
    fi

    echo -e "\n  ${RED}●${NC} ${BOLD}DÉCONNECTÉ${NC}"
    echo -e "    └─ Pas de relay strfry actif"
    return 1
}

cmd_scan() {
    print_header
    echo -e "\n${BOLD}Scan des connexions disponibles :${NC}\n"

    echo -e "${BOLD}[LOCAL]${NC}"
    if check_local_service "true"; then
        if test_relay "$STRFRY_LOCAL_PORT"; then
            print_status "OK" "strfry local opérationnel (port $STRFRY_LOCAL_PORT)"
        else
            print_status "WARN" "Processus détecté mais relay ne répond pas"
        fi
    else
        print_status "FAIL" "Pas de service strfry local"
    fi

    echo -e "\n${BOLD}[P2P]${NC} Nœuds IPFS Swarm"
    local p2p_count
    p2p_count=$(count_p2p_nodes)

    if [[ $p2p_count -gt 0 ]]; then
        print_status "OK" "$p2p_count nœud(s) disponible(s) :"
        for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
            [[ ! -f "$script" ]] && continue
            local node_id
            node_id=$(basename "$(dirname "$script")")
            local relay_file
            relay_file="$(dirname "$script")/12345.json"
            local relay_url=""
            [[ -f "$relay_file" ]] && relay_url=$(python3 -c "
import json,sys
try: print(json.load(open(sys.argv[1])).get('myRELAY',''))
except: pass
" "$relay_file" 2>/dev/null)
            echo -e "    ├─ ${CYAN}${node_id}${NC}"
            [[ -n "$relay_url" ]] && echo -e "    │  └─ relay: ${relay_url}"
        done
    else
        print_status "FAIL" "Pas de nœuds P2P avec strfry dans le swarm"
    fi

    if check_p2p_connections "true"; then
        local active_p2p
        active_p2p=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $3}' | head -1)
        echo -e "  ${GREEN}●${NC} P2P actif : $active_p2p → ws://127.0.0.1:$STRFRY_P2P_PORT"
    fi

    local local_avail p2p_avail
    local_avail=$(check_local_service "true" && echo Y || echo N)
    p2p_avail=$([[ $p2p_count -gt 0 ]] && echo Y || echo N)

    echo -e "\n${BOLD}Résumé :${NC}"
    echo -e "  LOCAL=$local_avail  P2P=$p2p_avail"
    echo -e "  Port local  : $STRFRY_LOCAL_PORT (ws://127.0.0.1:$STRFRY_LOCAL_PORT)"
    echo -e "  Port P2P    : $STRFRY_P2P_PORT  (ws://127.0.0.1:$STRFRY_P2P_PORT)"
}

cmd_help() {
    print_header
    echo -e "\n${BOLD}Usage :${NC} $(basename "$0") [COMMANDE] [OPTIONS]\n"

    echo -e "${BOLD}Commandes :${NC}"
    echo -e "  ${CYAN}(aucune)${NC}     Auto-connect (LOCAL → P2P swarm)"
    echo -e "  ${CYAN}STATUS${NC}       État de connexion actuel"
    echo -e "  ${CYAN}SCAN${NC}         Détecte toutes les connexions disponibles"
    echo -e "  ${CYAN}LOCAL${NC}        Connexion via strfry local (port $STRFRY_LOCAL_PORT)"
    echo -e "  ${CYAN}P2P${NC}          Connexion via IPFS P2P (port $STRFRY_P2P_PORT)"
    echo -e "  ${CYAN}P2P <n>${NC}      Nœud par numéro (1, 2, 3...)"
    echo -e "  ${CYAN}P2P <id>${NC}     Nœud par ID partiel"
    echo -e "  ${CYAN}P2P auto${NC}     Sélection aléatoire"
    echo -e "  ${CYAN}OFF${NC}          Déconnecte toutes les connexions P2P"
    echo -e "  ${CYAN}TEST${NC}         Teste le relay actif"
    echo -e "  ${CYAN}STATS${NC}        Affiche les statistiques du relay local"
    echo -e "  ${CYAN}HELP${NC}         Affiche cette aide"

    echo -e "\n${BOLD}Architecture :${NC}"
    echo -e "  LOCAL  → ws://127.0.0.1:$STRFRY_LOCAL_PORT  (strfry daemon local)"
    echo -e "  P2P    → ws://127.0.0.1:$STRFRY_P2P_PORT  (DRAGON tunnel → strfry distant)"
    echo -e "  Binary → $STRFRY_BIN"
}

########################################################
## Main Script
########################################################

case "${1^^}" in
    "STATUS"|"ST")
        cmd_status
        exit $?
        ;;
    "SCAN"|"DETECT"|"LIST"|"DISCOVER")
        cmd_scan
        exit 0
        ;;
    "HELP"|"-H"|"--HELP")
        cmd_help
        exit 0
        ;;
    "OFF"|"DISCONNECT"|"CLOSE")
        print_header
        echo -e "\n${BOLD}Déconnexion...${NC}"
        close_ipfs_p2p
        exit 0
        ;;
    "TEST")
        print_header
        if check_port "$STRFRY_P2P_PORT" && test_relay "$STRFRY_P2P_PORT"; then
            print_status "OK" "Relay P2P répond sur port $STRFRY_P2P_PORT"
            echo -e "  Relay URL : ${GREEN}ws://127.0.0.1:$STRFRY_P2P_PORT${NC}"
            exit 0
        fi
        if check_port "$STRFRY_LOCAL_PORT" && test_relay "$STRFRY_LOCAL_PORT"; then
            print_status "OK" "Relay local répond sur port $STRFRY_LOCAL_PORT"
            echo -e "  Relay URL : ${GREEN}${myRELAY:-ws://127.0.0.1:$STRFRY_LOCAL_PORT}${NC}"
            exit 0
        fi
        print_status "FAIL" "Aucun relay strfry ne répond"
        exit 1
        ;;
    "STATS")
        print_header
        if check_local_service "true"; then
            show_stats
        else
            print_status "WARN" "strfry local non actif — stats indisponibles"
            exit 1
        fi
        exit 0
        ;;
    "LOCAL")
        print_header
        echo -e "\n${BOLD}Connexion via LOCAL...${NC}"
        if check_local_service && test_relay "$STRFRY_LOCAL_PORT"; then
            save_connection_status "LOCAL" "Local strfry" "${myRELAY:-ws://127.0.0.1:$STRFRY_LOCAL_PORT}"
            print_status "OK" "Relay strfry local opérationnel"
            echo -e "  Relay URL : ${GREEN}${myRELAY:-ws://127.0.0.1:$STRFRY_LOCAL_PORT}${NC}"
            show_stats
            exit 0
        fi
        print_status "FAIL" "strfry local non disponible"
        exit 1
        ;;
    "P2P"|"SWARM"|"IPFS")
        print_header
        if connect_via_swarm "$2"; then
            echo -e "  Relay URL : ${GREEN}ws://127.0.0.1:$STRFRY_P2P_PORT${NC}"
            exit 0
        fi
        exit 1
        ;;
    "")
        # Auto-connect : LOCAL → P2P
        if check_port "$STRFRY_LOCAL_PORT" && test_relay "$STRFRY_LOCAL_PORT"; then
            save_connection_status "LOCAL" "Local strfry" "${myRELAY:-ws://127.0.0.1:$STRFRY_LOCAL_PORT}"
            echo "strfry relay ready (local) at ${myRELAY:-ws://127.0.0.1:$STRFRY_LOCAL_PORT}"
            exit 0
        fi

        echo "Pas de relay local — tentative swarm P2P..."
        if connect_via_swarm; then
            echo "strfry relay ready (P2P) at ws://127.0.0.1:$STRFRY_P2P_PORT"
            exit 0
        fi

        echo "Pas de relay strfry disponible (local ni P2P)."
        exit 1
        ;;
    *)
        echo "Commande inconnue : $1"
        echo "Utilisez '$(basename "$0") HELP' pour l'aide."
        exit 1
        ;;
esac
