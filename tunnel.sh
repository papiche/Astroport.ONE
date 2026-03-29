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
  W                : WEB/SSH (Ouvre l'interface Web ou un Terminal SSH)
  I                : IPNS (Ouvre http://127.0.0.1:8080/ipns/IPFSNODEID de la station)
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
cursor=0; running=true; last_msg="Prêt."; busy=false
active_p2p=""; all_listening=""
LOCAL_ID=$(ipfs id -f "<id>" 2>/dev/null || echo "Inconnu")

# --- FONCTIONS ---

update_list() {
    map_nodes=(); map_scripts=(); map_names=(); map_ports=(); map_protos=(); map_slugs=()
    for node_path in $(ls -d "$SWARM_DIR"/*/ 2>/dev/null); do
        node_id=$(basename "$node_path")
        
        swarm_file=$(ls "$node_path" | grep -E "^_MySwarm\..*\.html$" | head -n 1)
        machine_name=$( [[ -n "$swarm_file" ]] && echo "$swarm_file" | cut -d'.' -f2 || cat "$node_path/myIPFS.txt" 2>/dev/null | head -n 1 )
        [[ -z "$machine_name" ]] && machine_name="${node_id:0:8}"

        for s in "$node_path"/x_*.sh; do [ ! -f "$s" ] && continue
            
            svc_slug=$(basename "$s" | sed 's/x_//;s/\.sh//')
            port=$(grep -oP '(PORT|LPORT)="\K\d+' "$s" | head -n 1)
            [[ -z "$port" ]] && port=$(grep -oP 'tcp/\K\d+' "$s" | head -n 1)
            [[ -z "$port" ]] && port="????"

            proto="/x/${svc_slug,,}-${node_id}"
            
            map_nodes+=("$node_id")
            map_scripts+=("$s")
            map_names+=("${machine_name^^} - ${svc_slug^^}")
            map_ports+=("$port")
            map_protos+=("$proto")
            map_slugs+=("${svc_slug^^}")
        done
    done
}

fetch_system_status() {
    [[ "$busy" == "true" ]] && return
    active_p2p=$(ipfs p2p ls 2>/dev/null)
    all_listening=$(lsof -Pi -sTCP:LISTEN 2>/dev/null)
}

kill_service() {
    local proto=$2
    if [[ -n "$proto" ]]; then
        echo "[$(date +%T)] IPFS Close Proto: $proto" >> "$LOG_FILE"
        ipfs p2p close -p "$proto" >> "$LOG_FILE" 2>&1
    fi
}

draw_ui() {
    clear
    tput civis
    echo -e "${BG_BLUE}${FG_BLACK}  tunnel v2.0 -[Q]->Quit [↵]->CONNECT [R]->RESET [X]->STOP [W]->Web/SSH [I]->IPNS  ${NC}"
    echo -e "ID LOCAL: ${CYAN}${LOCAL_ID}${NC} | Port: ${YELLOW}${map_ports[$cursor]}${NC} | Auto-refresh ON${NC}\n"

    for i in "${!map_names[@]}"; do
        if [ $i -eq $cursor ]; then line_start="${BOLD}${YELLOW}> "; line_end="${NC}"; else line_start="  "; line_end=""; fi
        
        local is_p2p_active=$(echo "$active_p2p" | grep -F "${map_protos[$i]}" | grep -F "tcp/${map_ports[$i]}" | head -n 1)
        
        if [[ -n "$is_p2p_active" ]]; then
            status="${GREEN}[  ACTIF ipfs  ]${NC}"
        else
            local lsof_line=$(echo "$all_listening" | grep ":${map_ports[$i]} " | head -n 1)
            if [[ -n "$lsof_line" ]]; then
                local lsofsrc=$(echo "$lsof_line" | awk '{print $1}')
                status="${YELLOW}[ ACTIF $lsofsrc ]${NC}"
            else
                status="${RED}[  OFF  ]${NC}"
            fi
        fi

        name_part=$(printf "%-25s" "${map_names[$i]:0:24}")
        port_part=$(printf "%-10s" "P:${map_ports[$i]}")
        node_short="${map_nodes[$i]: -10}"
        
        echo -e "${line_start}${name_part} ${status}  ${port_part}  ... ${node_short} ... ${line_end}"
    done
    echo -e "\n${BOLD}LOG:${NC} ${CYAN}${last_msg}${NC}"
}

# --- INITIALISATION ---
update_list

# --- BOUCLE PRINCIPALE ---
while $running; do
    fetch_system_status
    draw_ui
    
    read -rsn1 -t $REFRESH_RATE key
    
    case "$key" in
        $'\x1b') # Navigation
            read -rsn2 -t 0.1 key
            case "$key" in "[A") ((cursor--)) ;; "[B") ((cursor++)) ;; esac
            ;;
        $'\x0a'|$'\x0d') # CONNECT
            port="${map_ports[$cursor]}"
            if echo "$all_listening" | grep ":$port " >/dev/null 2>&1; then
                last_msg="Port $port déjà occupé localement."
            else
                last_msg="Lancement ${map_names[$cursor]}..."
                draw_ui
                bash "${map_scripts[$cursor]}" >> "$LOG_FILE" 2>&1 &
                sleep 1
            fi
            ;;
        "r"|"R") # RESET
            last_msg="Reboot de ${map_names[$cursor]}..."
            draw_ui
            kill_service "${map_ports[$cursor]}" "${map_protos[$cursor]}"
            sleep 1
            bash "${map_scripts[$cursor]}" >> "$LOG_FILE" 2>&1 &
            sleep 1
            last_msg="Tunnel relancé."
            ;;
        "x"|"X") # STOP
            last_msg="Arrêt de ${map_names[$cursor]}..."
            draw_ui
            bash "${map_scripts[$cursor]}" stop >> "$LOG_FILE" 2>&1
            kill_service "${map_ports[$cursor]}" "${map_protos[$cursor]}"
            last_msg="Fermeture du tunnel ordonnée."
            ;;
        "w"|"W") # WEB / SSH
            port="${map_ports[$cursor]}"
            slug="${map_slugs[$cursor]}"
            
            if [[ "$port" != "????" ]]; then
                # --- SSH (Lancement Terminal) ---
                if [[ "$slug" == *"SSH"* ]]; then
                    # Lire le REMOTE_USER baked dans x_ssh.sh par DRAGON (user de la station distante)
                    ssh_remote_user=$(grep -oP 'REMOTE_USER="\K[^"]+' "${map_scripts[$cursor]}" 2>/dev/null \
                                      || echo "$USER")
                    last_msg="SSH → ${ssh_remote_user}@127.0.0.1:${port}"
                    draw_ui
                    
                    # On cherche explicitement le terminal utilisé pour lui passer la bonne syntaxe (-- ou -x ou -e)
                    if command -v gnome-terminal >/dev/null; then
                        nohup gnome-terminal -- ssh -p "${port}" "${ssh_remote_user}@127.0.0.1" >/dev/null 2>&1 &
                    elif command -v xfce4-terminal >/dev/null; then
                        nohup xfce4-terminal -x ssh -p "${port}" "${ssh_remote_user}@127.0.0.1" >/dev/null 2>&1 &
                    elif command -v terminator >/dev/null; then
                        nohup terminator -x ssh -p "${port}" "${ssh_remote_user}@127.0.0.1" >/dev/null 2>&1 &
                    elif command -v konsole >/dev/null; then
                        nohup konsole -e ssh -p "${port}" "${ssh_remote_user}@127.0.0.1" >/dev/null 2>&1 &
                    elif command -v tilix >/dev/null; then
                        nohup tilix -e ssh -p "${port}" "${ssh_remote_user}@127.0.0.1" >/dev/null 2>&1 &
                    # Si aucun terminal spécifique n'est détecté, on utilise l'alias Debian classique
                    elif command -v x-terminal-emulator >/dev/null; then
                        nohup x-terminal-emulator -e ssh -p "${port}" "${ssh_remote_user}@127.0.0.1" >/dev/null 2>&1 &
                    else
                        nohup xterm -e ssh -p "${port}" "${ssh_remote_user}@127.0.0.1" >/dev/null 2>&1 &
                    fi
                # --- WEB (HTTP/HTTPS) ---
                else
                    case "$port" in
                        6333)   proto="http";  suffix="/dashboard" ;;  
                        3001)   proto="https"; suffix="" ;;            
                        3002)   proto="http";  suffix="" ;;            
                        8443)   proto="https"; suffix="" ;;            
                        443)    proto="https"; suffix="" ;;            
                        *)      proto="http";  suffix="" ;;
                    esac
                    last_msg="Ouverture ${proto}://127.0.0.1:${port}${suffix}"
                    draw_ui
                    xdg-open "${proto}://127.0.0.1:${port}${suffix}" >/dev/null 2>&1 \
                        || open "${proto}://127.0.0.1:${port}${suffix}" >/dev/null 2>&1 &
                fi
            fi
            ;;
        "i"|"I") # IPNS — Ouvrir la page /ipns/IPFSNODEID de la station sélectionnée
            node_id="${map_nodes[$cursor]}"
            ipns_url="http://127.0.0.1:8080/ipns/${node_id}"
            last_msg="IPNS → ${ipns_url}"
            draw_ui
            xdg-open "${ipns_url}" >/dev/null 2>&1 \
                || open "${ipns_url}" >/dev/null 2>&1 &
            ;;
        "q"|"Q") running=false ;;
    esac

    [[ $cursor -lt 0 ]] && cursor=$((${#map_names[@]} - 1))
    [[ $cursor -ge ${#map_names[@]} ]] && cursor=0
done

tput cnorm; clear