#!/bin/bash
################################################################################
# tunnel.sh - Astroport Swarm Monitor & Controller v2.1
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
LOG_MAX=3

# --- COULEURS ---
BG_BLUE='\033[44m'; FG_BLACK='\033[30m'; NC='\033[0m'
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'
BOLD='\033[1m'; YELLOW='\033[1;33m'; MAGENTA='\033[1;35m'

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
  /                : Recherche (filtrer par nom, slug, port, capitaine)
    Caractères     :   Affiner la recherche
    Backspace      :   Effacer un caractère
    Entrée / Échap :   Quitter la recherche (filtre conservé / effacé)
  S                : Trier (cycler : NOM → PORT → CAPITAINE → STATUT)
  Q                : Quitter le moniteur

Options :
  -h, --help      Afficher ce message d'aide
  --log           Afficher le chemin du fichier log utilisé

EOF
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then show_help; exit 0; fi
if [[ "$1" == "--log" ]]; then echo "Fichier log : $LOG_FILE"; exit 0; fi

# --- VARIABLES D'ÉTAT ---
cursor=0; running=true; busy=false
log_lines=()
search_mode=false; search_query=""
sort_mode="name"      # name | port | captain | status
display_indices=()
active_p2p=""; all_listening=""
map_disp_ports=()
LOCAL_ID=$(ipfs id -f "<id>" 2>/dev/null || echo "Inconnu")

# --- FONCTIONS UTILITAIRES ---

add_log() {
    log_lines+=("$1")
    [[ ${#log_lines[@]} -gt $LOG_MAX ]] && log_lines=("${log_lines[@]: -$LOG_MAX}")
}

_sort_label() {
    case "$sort_mode" in
        port)    printf "PORT" ;;
        captain) printf "CAPITAINE" ;;
        status)  printf "STATUT" ;;
        *)       printf "NOM" ;;
    esac
}

# --- CHARGEMENT DES SERVICES ---

update_list() {
    map_nodes=(); map_scripts=(); map_names=(); map_ports=(); map_alt_ports=()
    map_protos=(); map_slugs=(); map_captains=()

    for node_path in $(ls -d "$SWARM_DIR"/*/ 2>/dev/null); do
        node_id=$(basename "$node_path")

        swarm_file=$(ls "$node_path" 2>/dev/null | grep -E "^_MySwarm\..*\.html$" | head -n 1)
        machine_name=$( [[ -n "$swarm_file" ]] \
            && echo "$swarm_file" | cut -d'.' -f2 \
            || cat "$node_path/myIPFS.txt" 2>/dev/null | head -n 1 )
        [[ -z "$machine_name" ]] && machine_name="${node_id}"

        # Capitaine : lire depuis 12345.json, normaliser adresse+tag → adresse
        raw_cap=$(grep -oiP '"captain_?email"\s*:\s*"\K[^"]+' "$node_path/12345.json" 2>/dev/null \
                  || grep -oiP '"captain"\s*:\s*"\K[^"]+' "$node_path/12345.json" 2>/dev/null \
                  | head -n1)
        if [[ -n "$raw_cap" && "$raw_cap" == *@* ]]; then
            local_part="${raw_cap%%@*}"; domain="${raw_cap##*@}"
            captain="${local_part%%+*}@${domain}"
        else
            captain="${machine_name,,}"
        fi

        for s in "$node_path"/x_*.sh; do
            [ ! -f "$s" ] && continue
            svc_slug=$(basename "$s" | sed 's/x_//;s/\.sh//')

            port=$(grep -oP 'NATIVE_PORT="\K\d+' "$s" | head -n 1)
            alt_port=$(grep -oP 'ALT_PORT="\K\d+' "$s" | head -n 1)
            [[ -z "$port" ]] && port=$(grep -oP '(PORT|LPORT)="\K\d+' "$s" | head -n 1)
            [[ -z "$port" ]] && port=$(grep -oP 'tcp/\K\d+' "$s" | head -n 1)
            [[ -z "$port" ]] && port="????"

            map_nodes+=("$node_id")
            map_scripts+=("$s")
            map_names+=("${machine_name^^} - ${svc_slug^^}")
            map_ports+=("$port")
            map_alt_ports+=("${alt_port:-$port}")
            map_protos+=("/x/${svc_slug,,}-${node_id}")
            map_slugs+=("${svc_slug^^}")
            map_captains+=("$captain")
        done
    done
}

# --- ÉTAT DU SYSTÈME ---

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

# --- FILTRE + TRI ---

compute_display_indices() {
    local n=${#map_names[@]}
    local q="${search_query,,}"
    local prev_real="${display_indices[$cursor]:-0}"

    # Filtre
    local candidates=()
    for ((i=0; i<n; i++)); do
        if [[ -z "$q" ]]; then
            candidates+=($i)
        else
            local hay="${map_names[$i],,} ${map_ports[$i]} ${map_captains[$i],,}"
            [[ "$hay" == *"$q"* ]] && candidates+=($i)
        fi
    done

    # Tri
    case "$sort_mode" in
        port)
            local tmp
            tmp=$(for i in "${candidates[@]}"; do
                      printf '%05d %d\n' "${map_ports[$i]:-99999}" "$i"
                  done | sort -n | awk '{print $2}')
            display_indices=()
            while IFS= read -r idx; do [[ -n "$idx" ]] && display_indices+=("$idx"); done <<< "$tmp"
            ;;
        captain)
            local tmp
            tmp=$(for i in "${candidates[@]}"; do
                      printf '%s\t%d\n' "${map_captains[$i]}" "$i"
                  done | sort -t$'\t' -k1,1 | awk -F'\t' '{print $2}')
            display_indices=()
            while IFS= read -r idx; do [[ -n "$idx" ]] && display_indices+=("$idx"); done <<< "$tmp"
            ;;
        status)
            local grp0=() grp1=() grp2=()
            for i in "${candidates[@]}"; do
                local proto="${map_protos[$i]}"
                local pn="${map_ports[$i]}" pa="${map_alt_ports[$i]}"
                if echo "$active_p2p" | grep -qF "$proto"; then
                    grp0+=($i)
                elif echo "$all_listening" | grep -qE ":($pn|$pa) "; then
                    grp1+=($i)
                else
                    grp2+=($i)
                fi
            done
            display_indices=("${grp0[@]}" "${grp1[@]}" "${grp2[@]}")
            ;;
        *)
            display_indices=("${candidates[@]}")
            ;;
    esac

    # Garder le curseur sur le même élément réel si possible
    local new_cursor=0
    for j in "${!display_indices[@]}"; do
        [[ "${display_indices[$j]}" == "$prev_real" ]] && { new_cursor=$j; break; }
    done
    cursor=$new_cursor
}

# --- INTERFACE ---

draw_ui() {
    clear; tput civis

    # Barre de titre
    echo -e "${BG_BLUE}${FG_BLACK}  tunnel v2.1 · [↵]CONNECT [R]RESET [X]STOP [W]Web/SSH [I]IPNS [/]Chercher [S]Trier [Q]Quit  ${NC}"

    # Ligne d'état
    local total=${#map_names[@]}
    local shown=${#display_indices[@]}
    local cur_real="${display_indices[$cursor]:-0}"
    local cur_port="${map_ports[$cur_real]:-?}"
    local cur_alt="${map_alt_ports[$cur_real]:-?}"
    echo -e "LOCAL: ${CYAN}${LOCAL_ID: -22}${NC}  Port:${YELLOW}${cur_port}${NC}(alt:${cur_alt})  Tri:${MAGENTA}$(_sort_label)${NC}  ${CYAN}${shown}/${total}${NC} services"

    # Barre de recherche
    if $search_mode; then
        echo -e "${BOLD}/${NC} ${CYAN}${search_query}${YELLOW}▌${NC}"
    else
        [[ -n "$search_query" ]] \
            && echo -e "${BOLD}/${NC} ${CYAN}${search_query}${NC}  ${MAGENTA}(filtre actif — / pour modifier)${NC}" \
            || echo ""
    fi

    # Pré-calcul statuts et ports effectifs (indexé par indice réel)
    local -a tmp_dp tmp_st
    for i in "${!map_names[@]}"; do
        local pn="${map_ports[$i]}" pa="${map_alt_ports[$i]}" proto="${map_protos[$i]}"
        local aline dp st is_p2p=""
        aline=$(echo "$active_p2p" | grep -F "$proto" | head -n 1)
        dp="$pn"

        if [[ -n "$aline" ]]; then
            if echo "$aline" | grep -q "tcp/$pn"; then
                is_p2p="true"; dp="$pn"
            elif echo "$aline" | grep -q "tcp/$pa"; then
                is_p2p="true"; dp="$pa"
            fi
        fi

        if [[ "$is_p2p" == "true" ]]; then
            st="${GREEN}[  ACTIF ipfs  ]${NC}"
        else
            local lline
            lline=$(echo "$all_listening" | grep -E ":($pn|$pa) " | head -n 1)
            if [[ -n "$lline" ]]; then
                local lsrc
                lsrc=$(echo "$lline" | awk '{print $1}')
                dp=$(echo "$lline" | grep -oP ':\d+' | head -n 1 | cut -d':' -f2)
                st="${YELLOW}[ ACTIF $lsrc ]${NC}"
            else
                st="${RED}[  OFF  ]${NC}"
            fi
        fi
        tmp_dp[$i]="$dp"
        tmp_st[$i]="$st"
    done

    # map_disp_ports indexé par position d'affichage (utilisé par les handlers)
    map_disp_ports=()
    for disp_pos in "${!display_indices[@]}"; do
        map_disp_ports+=("${tmp_dp[${display_indices[$disp_pos]}]}")
    done

    # Rendu de la liste filtrée/triée
    for disp_pos in "${!display_indices[@]}"; do
        local i="${display_indices[$disp_pos]}"
        local dp="${tmp_dp[$i]}"
        local line_start line_end
        if [[ $disp_pos -eq $cursor ]]; then
            line_start="${BOLD}${YELLOW}> "; line_end="${NC}"
        else
            line_start="  "; line_end=""
        fi

        local name_part port_part cap_part node_short
        name_part=$(printf "%-25s" "${map_names[$i]:0:24}")
        port_part=$(printf "%-10s" "P:$dp")
        cap_part=$(printf "%-20s" "${map_captains[$i]:0:20}")
        node_short="${map_nodes[$i]: -8}"

        echo -e "${line_start}${name_part} ${tmp_st[$i]}  ${port_part} ${cap_part} ${node_short}${line_end}"
    done

    # Zone log 3 lignes
    echo ""
    local log_count=${#log_lines[@]}
    for ((l=0; l<LOG_MAX; l++)); do
        local idx=$((log_count - LOG_MAX + l))
        if [[ $idx -ge 0 ]]; then
            echo -e "  ${BOLD}│${NC} ${CYAN}${log_lines[$idx]}${NC}"
        else
            echo -e "  ${BOLD}│${NC}"
        fi
    done
}

# --- INITIALISATION ---
update_list
add_log "Prêt. $(date +%T)"
compute_display_indices

# --- BOUCLE PRINCIPALE ---
while $running; do
    fetch_system_status
    compute_display_indices
    draw_ui

    read -rsn1 -t $REFRESH_RATE key

    # --- MODE RECHERCHE ---
    if $search_mode; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 esc_seq
                if [[ -z "$esc_seq" ]]; then
                    # ESC pur : vider la recherche et quitter le mode
                    search_query=""; search_mode=false
                else
                    case "$esc_seq" in "[A") ((cursor--)) ;; "[B") ((cursor++)) ;; esac
                fi
                ;;
            $'\x7f'|$'\x08')
                [[ ${#search_query} -gt 0 ]] && search_query="${search_query:0:-1}"
                ;;
            $'\x0a'|$'\x0d')
                search_mode=false   # Entrée : quitter la recherche, conserver le filtre
                ;;
            *)
                if [[ "$key" =~ ^[[:print:]]$ ]]; then
                    search_query="${search_query}${key}"
                    cursor=0
                fi
                ;;
        esac

    # --- MODE NORMAL ---
    else
        # Récupérer l'indice réel pour les actions
        local_idx="${display_indices[$cursor]:-0}"

        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 key
                case "$key" in "[A") ((cursor--)) ;; "[B") ((cursor++)) ;; esac
                ;;

            $'\x0a'|$'\x0d') # CONNECT
                port="${map_ports[$local_idx]}"
                if echo "$active_p2p" | grep -qF "${map_protos[$local_idx]}"; then
                    add_log "Tunnel déjà actif sur P:${map_disp_ports[$cursor]:-$port}."
                else
                    add_log "Lancement ${map_names[$local_idx]}..."
                    draw_ui
                    bash "${map_scripts[$local_idx]}" >> "$LOG_FILE" 2>&1 &
                    sleep 1
                    add_log "Script lancé — attente réponse tunnel."
                fi
                ;;

            "r"|"R") # RESET
                add_log "Reset ${map_names[$local_idx]}..."
                draw_ui
                kill_service "${map_ports[$local_idx]}" "${map_protos[$local_idx]}"
                sleep 1
                bash "${map_scripts[$local_idx]}" >> "$LOG_FILE" 2>&1 &
                sleep 1
                add_log "Tunnel relancé sur P:${map_disp_ports[$cursor]}."
                ;;

            "x"|"X") # STOP
                add_log "Arrêt ${map_names[$local_idx]}..."
                draw_ui
                bash "${map_scripts[$local_idx]}" stop >> "$LOG_FILE" 2>&1
                kill_service "${map_ports[$local_idx]}" "${map_protos[$local_idx]}"
                add_log "Fermeture du tunnel ordonnée."
                ;;

            "w"|"W") # WEB / SSH
                port="${map_disp_ports[$cursor]:-${map_ports[$local_idx]}}"
                slug="${map_slugs[$local_idx]}"

                if [[ "$port" != "????" ]]; then
                    if [[ "$slug" == *"SSH"* ]]; then
                        ssh_remote_user=$(grep -oP 'REMOTE_USER="\K[^"]+' "${map_scripts[$local_idx]}" 2>/dev/null \
                                          || grep -oP '\w+(?=@localhost)' "${map_scripts[$local_idx]}" 2>/dev/null | tail -n1 \
                                          || echo "$USER")
                        local ssh_cmd="ssh -p ${port} ${ssh_remote_user}@127.0.0.1"
                        add_log "${ssh_cmd}"
                        draw_ui
                        if command -v gnome-terminal >/dev/null; then
                            nohup gnome-terminal -- bash -c "${ssh_cmd}; echo; echo '[fin — Entrée pour fermer]'; read" >/dev/null 2>&1 &
                        elif command -v xfce4-terminal >/dev/null; then
                            nohup xfce4-terminal -x bash -c "${ssh_cmd}; echo; echo '[fin — Entrée pour fermer]'; read" >/dev/null 2>&1 &
                        elif command -v terminator >/dev/null; then
                            nohup terminator -x bash -c "${ssh_cmd}; echo; echo '[fin — Entrée pour fermer]'; read" >/dev/null 2>&1 &
                        elif command -v konsole >/dev/null; then
                            nohup konsole -e bash -c "${ssh_cmd}; echo; echo '[fin — Entrée pour fermer]'; read" >/dev/null 2>&1 &
                        elif command -v tilix >/dev/null; then
                            nohup tilix -e bash -c "${ssh_cmd}; echo; echo '[fin — Entrée pour fermer]'; read" >/dev/null 2>&1 &
                        elif command -v x-terminal-emulator >/dev/null; then
                            nohup x-terminal-emulator -e bash -c "${ssh_cmd}; echo; echo '[fin — Entrée pour fermer]'; read" >/dev/null 2>&1 &
                        else
                            nohup xterm -e bash -c "${ssh_cmd}; echo; echo '[fin — Entrée pour fermer]'; read" >/dev/null 2>&1 &
                        fi
                    else
                        local web_proto web_suffix
                        case "$port" in
                            6333) web_proto="http";  web_suffix="/dashboard" ;;
                            3001) web_proto="https"; web_suffix="" ;;
                            3002) web_proto="http";  web_suffix="" ;;
                            8443) web_proto="https"; web_suffix="" ;;
                            443)  web_proto="https"; web_suffix="" ;;
                            *)    web_proto="http";  web_suffix="" ;;
                        esac
                        add_log "Ouverture ${web_proto}://127.0.0.1:${port}${web_suffix}"
                        draw_ui
                        xdg-open "${web_proto}://127.0.0.1:${port}${web_suffix}" >/dev/null 2>&1 \
                            || open "${web_proto}://127.0.0.1:${port}${web_suffix}" >/dev/null 2>&1 &
                    fi
                fi
                ;;

            "i"|"I") # IPNS
                node_id="${map_nodes[$local_idx]}"
                ipns_url="http://127.0.0.1:8080/ipns/${node_id}"
                add_log "IPNS → ${ipns_url}"
                draw_ui
                xdg-open "${ipns_url}" >/dev/null 2>&1 \
                    || open "${ipns_url}" >/dev/null 2>&1 &
                ;;

            "/") # Activer la recherche
                search_mode=true
                ;;

            "s"|"S") # Cycler le tri
                case "$sort_mode" in
                    name)    sort_mode="port" ;;
                    port)    sort_mode="captain" ;;
                    captain) sort_mode="status" ;;
                    *)       sort_mode="name" ;;
                esac
                add_log "Tri : $(_sort_label)"
                ;;

            "q"|"Q") running=false ;;
        esac
    fi

    # Bornes du curseur
    local disp_count=${#display_indices[@]}
    [[ $disp_count -gt 0 ]] || disp_count=1
    [[ $cursor -lt 0 ]] && cursor=$(( disp_count - 1 ))
    [[ $cursor -ge $disp_count ]] && cursor=0
done

tput cnorm; clear
