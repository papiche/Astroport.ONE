#!/bin/bash
################################################################################
# tunnel.sh - Astroport Swarm Monitor & Controller
# ----------------------------------------------------------------------------
# Cet outil permet de visualiser et piloter les tunnels P2P (IPFS) de l'essaim
# Astroport via une interface interactive en temps réel.
#
# Auteurs : Fred & ses amis (Astroport project)
# Licence : AGPL-3.0 (https://www.gnu.org/licenses/agpl-3.0.html)
################################################################################

# --- CONFIGURATION ---
SWARM_DIR="$HOME/.zen/tmp/swarm"
REFRESH_RATE=3 
CACHE_TTL=10 
LOG_FILE="$HOME/.zen/tmp/tunnel.log"

# --- COULEURS ---
BG_BLUE='\033[44m'; FG_BLACK='\033[30m'; NC='\033[0m'
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'
BOLD='\033[1m'; YELLOW='\033[1;33m'

# --- AIDE ---
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTION]

tunnel est une interface interactive pour gérer vos connexions Astroport Swarm.

Commandes de l'interface :
  Touches fléchées : Navigation dans la liste des services
  Entrée           : Connecte le service (si le port est libre)
  R                : RESET (Force la fermeture et la réouverture du tunnel)
  X                : STOP (Ferme le tunnel et libère le port local)
  W                : WEB (Ouvre l'interface dans le navigateur par défaut)
  Q                : Quitter le moniteur

Options :
  -h, --help      Afficher ce message d'aide
  --log           Afficher le chemin du fichier log utilisé

EOF
}

# Vérification des arguments
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

if [[ "$1" == "--log" ]]; then
    echo "Fichier log : $LOG_FILE"
    exit 0
fi

# --- VARIABLES D'ÉTAT ---
cursor=0; running=true; last_msg="Prêt."; active_p2p=""; last_ipfs_check=0; busy=false

# --- FONCTIONS ---

update_list() {
    map_nodes=(); map_scripts=(); map_names=(); map_ports=(); map_protos=()
    # On trie par nom de machine pour plus de clarté
    for node_path in $(ls -d "$SWARM_DIR"/*/ 2>/dev/null); do
        node_id=$(basename "$node_path")
        
        # Identification du nom de la machine
        swarm_file=$(ls "$node_path" | grep -E "^_MySwarm\..*\.html$" | head -n 1)
        machine_name=$( [[ -n "$swarm_file" ]] && echo "$swarm_file" | cut -d'.' -f2 || cat "$node_path/myIPFS.txt" 2>/dev/null | head -n 1 )
        [[ -z "$machine_name" ]] && machine_name="${node_id:0:8}"

        for s in "$node_path"/x_*.sh; do
            [ ! -f "$s" ] && continue
            
            # Slug du service (ex: OLLAMA)
            svc_slug=$(basename "$s" | sed 's/x_//;s/\.sh//')
            
            # Extraction du port
            port=$(grep -oP '(PORT|LPORT)="\K\d+' "$s" | head -n 1)
            [[ -z "$port" ]] && port=$(grep -oP 'tcp/\K\d+' "$s" | head -n 1)
            [[ -z "$port" ]] && port="????"

            # Construction déterministe du PROTOCOLE
            # Format standard Astroport : /x/[service_minuscule]-[NODEID]
            proto="/x/${svc_slug,,}-${node_id}"
            
            map_nodes+=("$node_id")
            map_scripts+=("$s")
            map_names+=("${machine_name^^} - ${svc_slug^^}")
            map_ports+=("$port")
            map_protos+=("$proto")
        done
    done
}

fetch_ipfs_status() {
    [[ "$busy" == "true" ]] && return
    # On récupère la liste complète des tunnels actifs
    active_p2p=$(ipfs p2p ls 2>/dev/null)
    last_ipfs_check=$(date +%s)
}

kill_service() {
    local port=$1; local proto=$2
    # Fermeture par protocole (le plus propre)
    if [[ -n "$proto" ]]; then
        echo "[$(date +%T)] IPFS Close Proto: $proto" >> $LOG_FILE
        ipfs p2p close -p "$proto" >/dev/null 2>&1
    fi
    # Sécurité par Port
    if [[ "$port" != "????" ]]; then
        pid=$(lsof -ti :$port 2>/dev/null)
        [[ -n "$pid" ]] && kill -9 $pid 2>/dev/null
    fi
}

draw_ui() {
    clear
    tput civis
    echo -e "${BG_BLUE}${FG_BLACK}  tunnel v2.0 - [Q]->Quit [Entrée]->CONNECT [R]->RESET [X]->STOP [W]->WebOpen  ${NC}"
    echo -e "ID LOCAL: ${CYAN}$(ipfs id -f "<id>")${NC} | Port: ${YELLOW}${map_ports[$cursor]}${NC} | Auto-refresh ON${NC}\n"

    for i in "${!map_names[@]}"; do
        if [ $i -eq $cursor ]; then line_start="${BOLD}${YELLOW}> "; line_end="${NC}"; else line_start="  "; line_end=""; fi
        
        # La détection d'activité combine PROTOCOLE et PORT
        # On cherche la ligne qui contient EXACTEMENT le protocole ET le port
        is_p2p_active=$(echo "$active_p2p" | grep -F "${map_protos[$i]}" | grep -F "${map_ports[$i]}")
        is_lsof=$(lsof -Pi :${map_ports[$i]} -sTCP:LISTEN -t 2>/dev/null)
        lsofsrc=$(lsof -Pi :${map_ports[$i]} -sTCP:LISTEN | awk 'NR==2 {print $1}')

        if [[ -n "$is_p2p_active" ]]; then
            status="${GREEN}[ ACTIF $lsofsrc ]${NC}"
        else
            status="${RED}[  OFF  ]${NC}"
        fi

        name_part=$(printf "%-25s" "${map_names[$i]:0:24}")
        port_part=$(printf "%-10s" "P:${map_ports[$i]}")
        # Affichage des 10 derniers caractères du NodeID pour vérification visuelle
        node_short="${map_nodes[$i]: -10}"
        
        echo -e "${line_start}${name_part} ${status}  ${port_part}  ... ${node_short} ... ${line_end}"
    done
    echo -e "\n${BOLD}LOG:${NC} ${CYAN}${last_msg}${NC}"
}
# --- INITIALISATION ---
update_list
fetch_ipfs_status

# --- BOUCLE PRINCIPALE ---
while $running; do
    draw_ui
    read -rsn1 -t $REFRESH_RATE key
    
    case "$key" in
        $'\x1b') # Navigation
            read -rsn2 -t 0.1 key
            case "$key" in "[A") ((cursor--)) ;; "[B") ((cursor++)) ;; esac
            ;;
        $'\x0a'|$'\x0d') # CONNECT
            busy=true
            port="${map_ports[$cursor]}"
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                last_msg="Port $port déjà occupé localement."
            else
                last_msg="Lancement ${map_names[$cursor]}..."
                draw_ui
                bash "${map_scripts[$cursor]}" >> $LOG_FILE 2>&1 &
                sleep 2
            fi
            fetch_ipfs_status; busy=false
            ;;
        "r"|"R") # RESET
            busy=true
            last_msg="Reboot de ${map_names[$cursor]}..."
            draw_ui
            kill_service "${map_ports[$cursor]}" "${map_protos[$cursor]}"
            sleep 1
            bash "${map_scripts[$cursor]}" >> $LOG_FILE 2>&1 &
            sleep 2
            fetch_ipfs_status; busy=false
            ;;
        "x"|"X") # STOP
            busy=true
            last_msg="Arrêt de ${map_names[$cursor]}..."
            draw_ui
            # On essaie de passer l'argument stop au script s'il est géré
            bash "${map_scripts[$cursor]}" stop >> $LOG_FILE 2>&1
            kill_service "${map_ports[$cursor]}" "${map_protos[$cursor]}"
            sleep 1
            fetch_ipfs_status; busy=false
            last_msg="Service arrêté."
            ;;
        "w"|"W") # WEB
            port="${map_ports[$cursor]}"
            if [[ "$port" != "????" ]]; then
                last_msg="Ouverture http://localhost:$port"
                [[ "$port" == "6333" ]] && suffix="/dashboard" || suffix=""
                xdg-open "http://localhost:$port$suffix" >/dev/null 2>&1 || open "http://localhost:$port$suffix" &
            fi
            ;;
        "q"|"Q") running=false ;;
    esac

    [[ $cursor -lt 0 ]] && cursor=$((${#map_names[@]} - 1))
    [[ $cursor -ge ${#map_names[@]} ]] && cursor=0
done

tput cnorm; clear