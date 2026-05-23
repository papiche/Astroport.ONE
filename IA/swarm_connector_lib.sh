#!/bin/bash
################################################################################
## swarm_connector_lib.sh — Bibliothèque commune pour les Swarm Connectors
## Source this file AFTER defining the required variables and test_api().
##
## CONTRAT — chaque script doit définir avant de sourcer cette lib :
##
##   SERVICE_NAME      — nom du service, ex: "ollama", "comfyui"
##                       Utilisé pour trouver  ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh
##
##   SERVICE_PORT      — port local principal du service
##
##   SERVICE_P2P_PORT  — port écouté après tunnel P2P (facultatif ; défaut = SERVICE_PORT)
##                       Différent seulement pour les services où le tunnel remappe le port
##                       (ex: rnostr écoute sur 9999 mais est exposé sur 7777)
##
##   STATUS_FILE       — chemin du fichier de statut connexion
##                       ex: "$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"
##
##   test_api PORT     — fonction définie par le script, teste l'API sur le port donné.
##                       Signature : test_api [silent]
##                       La lib appelle :  test_api "true"  après connexion P2P.
##                       Note : la plupart des scripts ignorent le paramètre PORT et
##                       utilisent leur variable locale (SERVICE_PORT / ORPHEUS_PORT etc.)
##                       — c'est correct, la lib ne passe pas de port, elle appelle juste
##                       test_api "true".
##
## FONCTIONS FOURNIES :
##   print_status STATUS MESSAGE
##   save_connection_status TYPE DETAILS
##   check_port [silent]
##   count_p2p_nodes
##   check_p2p_connections [silent]
##   close_ipfs_p2p [silent]
##   connect_via_swarm [TARGET]   — sélection ALÉATOIRE (sort -R) dans tous les cas ;
##                                  n'inclut JAMAIS IPFSNODEID (pas de tunnel vers soi)
##
## Variables de couleur RED/GREEN/YELLOW/BLUE/CYAN/NC/BOLD sont définies ici
## si elles ne sont pas déjà définies par le script appelant.
################################################################################

# Guard : ne pas sourcer deux fois
[[ -n "${_SWARM_CONNECTOR_LIB_LOADED:-}" ]] && return 0
_SWARM_CONNECTOR_LIB_LOADED=1

# ── Couleurs (définies seulement si absentes) ──────────────────────────────
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"
BOLD="${BOLD:-\033[1m}"

# ── Port P2P (peut différer de SERVICE_PORT) ──────────────────────────────
# SERVICE_P2P_PORT est utilisé uniquement par test_api appelée après connexion.
# Si non défini par le script, on utilise SERVICE_PORT.
: "${SERVICE_P2P_PORT:=${SERVICE_PORT:-}}"

########################################################
## print_status STATUS MESSAGE
## Affiche une ligne colorée selon le statut.
########################################################
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "OK")     echo -e "  ${GREEN}✓${NC} $message" ;;
        "FAIL")   echo -e "  ${RED}✗${NC} $message" ;;
        "WARN")   echo -e "  ${YELLOW}⚠${NC} $message" ;;
        "INFO")   echo -e "  ${BLUE}ℹ${NC} $message" ;;
        "ACTIVE") echo -e "  ${GREEN}●${NC} $message ${GREEN}[ACTIVE]${NC}" ;;
        *)        echo -e "  $message" ;;
    esac
}

########################################################
## save_connection_status TYPE DETAILS
## Écrit le fichier STATUS_FILE avec les infos de connexion.
########################################################
save_connection_status() {
    local conn_type="$1"
    local details="$2"
    mkdir -p "$(dirname "$STATUS_FILE")"
    echo "CONNECTION_TYPE=$conn_type"             > "$STATUS_FILE"
    echo "CONNECTION_DETAILS=$details"           >> "$STATUS_FILE"
    echo "CONNECTION_TIME=$(date -Iseconds)"     >> "$STATUS_FILE"
    echo "CONNECTION_PORT=${SERVICE_PORT:-}"     >> "$STATUS_FILE"
}

########################################################
## check_port [silent]
## Retourne 0 si SERVICE_PORT est ouvert en écoute.
########################################################
check_port() {
    local silent="${1:-false}"
    local port="${SERVICE_PORT:-}"
    if netstat -tulnp 2>/dev/null | grep -q ":${port} " || \
       ss -tln 2>/dev/null | grep -qw ":${port}"; then
        [[ "$silent" != "true" ]] && echo "Port ${port} is open."
        return 0
    fi
    [[ "$silent" != "true" ]] && echo "Port ${port} is not available."
    return 1
}

########################################################
## count_p2p_nodes
## Compte les nœuds swarm disponibles pour SERVICE_NAME.
## N'inclut PAS IPFSNODEID (évite le tunnel vers soi-même).
########################################################
count_p2p_nodes() {
    local count=0
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        [[ -f "$script" ]] && ((count++))
    done
    echo $count
}

########################################################
## check_p2p_connections [silent]
## Retourne 0 si au moins une connexion IPFS P2P est active.
########################################################
check_p2p_connections() {
    local silent="${1:-false}"
    local p2p_conns
    p2p_conns=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | wc -l)
    if [[ $p2p_conns -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "ACTIVE" "IPFS P2P ($p2p_conns connection(s))"
        return 0
    fi
    return 1
}

########################################################
## close_ipfs_p2p [silent]
## Ferme toutes les connexions IPFS P2P pour SERVICE_NAME.
########################################################
close_ipfs_p2p() {
    local silent="${1:-false}"
    local closed=0
    for conn in $(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $1}'); do
        ipfs p2p close -p "$conn" 2>/dev/null && ((closed++))
    done
    if [[ $closed -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "OK" "Closed $closed P2P connection(s)"
        rm -f "$STATUS_FILE"
        return 0
    fi
    [[ "$silent" != "true" ]] && print_status "INFO" "No P2P connections to close"
    return 1
}

########################################################
## connect_via_swarm [TARGET]
##
## Connecte le service via IPFS P2P swarm.
## TARGET peut être :
##   ""           — sélection aléatoire (sort -R)
##   "auto"       — sélection aléatoire explicite
##   <N>          — numéro de nœud (1-based)
##   <partial-id> — correspondance partielle sur l'ID IPFS
##
## La fonction appelle  test_api "true"  après chaque tentative.
## IPFSNODEID est toujours EXCLU de la liste (pas de tunnel vers soi).
########################################################
connect_via_swarm() {
    local target="${1:-}"

    echo -e "\n${BOLD}Connecting via IPFS P2P swarm...${NC}"

    local nodes=()
    local node_ids=()

    # Collecter uniquement les nœuds swarm distants (pas IPFSNODEID)
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        if [[ -f "$script" ]]; then
            local nid
            nid=$(basename "$(dirname "$script")")
            # Exclure notre propre nœud
            [[ -n "${IPFSNODEID:-}" && "$nid" == "$IPFSNODEID" ]] && continue
            nodes+=("$script")
            node_ids+=("$nid")
        fi
    done

    if [[ ${#nodes[@]} -eq 0 ]]; then
        print_status "FAIL" "No ${SERVICE_NAME} nodes found in swarm"
        return 1
    fi

    local selected_script=""
    local selected_node=""

    if [[ -n "$target" && "$target" != "auto" && "$target" != "AUTO" && \
          "$target" != "random" && "$target" != "RANDOM" ]]; then
        # Sélection par numéro
        if [[ "$target" =~ ^[0-9]+$ ]]; then
            local idx=$((target - 1))
            if [[ $idx -ge 0 && $idx -lt ${#nodes[@]} ]]; then
                selected_script="${nodes[$idx]}"
                selected_node="${node_ids[$idx]}"
            else
                print_status "FAIL" "Invalid selection: $target (valid: 1-${#nodes[@]})"
                return 1
            fi
        else
            # Sélection par ID partiel
            for i in "${!node_ids[@]}"; do
                if [[ "${node_ids[$i]}" == "$target" || "${node_ids[$i]}" == *"$target"* ]]; then
                    selected_script="${nodes[$i]}"
                    selected_node="${node_ids[$i]}"
                    break
                fi
            done
            if [[ -z "$selected_script" ]]; then
                print_status "FAIL" "Node not found: $target"
                echo -e "\nAvailable nodes:"
                for i in "${!node_ids[@]}"; do
                    echo -e "  [$((i+1))] ${node_ids[$i]:0:30}..."
                done
                return 1
            fi
        fi

        # Connexion au nœud sélectionné explicitement
        echo "Connecting to: $selected_node"
        ipfs p2p close -p "/x/${SERVICE_NAME}-${selected_node}" 2>/dev/null || true
        if bash "$selected_script" 2>/dev/null; then
            sleep 2
            if test_api "true"; then
                save_connection_status "P2P" "$selected_node"
                print_status "OK" "Connected to $selected_node via IPFS P2P"
                return 0
            else
                ipfs p2p close -p "/x/${SERVICE_NAME}-$selected_node" 2>/dev/null
                print_status "FAIL" "Connected but API not responding"
            fi
        else
            ipfs p2p close -p "/x/${SERVICE_NAME}-${selected_node}" 2>/dev/null || true
            print_status "FAIL" "Failed to establish P2P connection to $selected_node"
        fi
        return 1
    fi

    # Sélection aléatoire (cas "auto", "random", ou pas de target)
    # Afficher la liste si plusieurs nœuds disponibles
    if [[ ${#nodes[@]} -gt 1 ]]; then
        echo -e "\n${BOLD}Available P2P nodes:${NC}\n"
        for i in "${!node_ids[@]}"; do
            local myipfs_file
            myipfs_file="$(dirname "${nodes[$i]}")/myIPFS.txt"
            local gateway=""
            [[ -f "$myipfs_file" ]] && gateway=$(cat "$myipfs_file")
            echo -e "  ${CYAN}[$((i+1))]${NC} ${node_ids[$i]:0:20}..."
            [[ -n "$gateway" ]] && echo -e "      └─ $gateway"
        done
        echo ""
        echo -e "${YELLOW}Tip:${NC} Use 'P2P <number>' or 'P2P <node_id>' to select. Connecting randomly..."
        echo ""
    fi

    # Mélanger et essayer chaque nœud dans un ordre aléatoire
    local shuffled
    shuffled=($(printf '%s\n' "${!nodes[@]}" | sort -R))
    for idx in "${shuffled[@]}"; do
        selected_script="${nodes[$idx]}"
        selected_node="${node_ids[$idx]}"
        echo "Trying node: $selected_node"
        ipfs p2p close -p "/x/${SERVICE_NAME}-${selected_node}" 2>/dev/null || true
        if bash "$selected_script" 2>/dev/null; then
            sleep 2
            if test_api "true"; then
                save_connection_status "P2P" "$selected_node"
                print_status "OK" "Connected to $selected_node via IPFS P2P"
                return 0
            fi
            ipfs p2p close -p "/x/${SERVICE_NAME}-$selected_node" 2>/dev/null
        else
            ipfs p2p close -p "/x/${SERVICE_NAME}-${selected_node}" 2>/dev/null || true
        fi
    done

    print_status "FAIL" "No working ${SERVICE_NAME} nodes available in swarm"
    return 1
}
