#!/bin/bash

# ============================================
# Script amélioré pour récupérer les adresses IPv6
# Version: 2.0
# ============================================

# Configuration
DEBUG=false
SHOW_ALL=false
PREFER_STATIC=true
TIMEOUT=2

# Fonction pour afficher l'aide
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -a, --all          Afficher toutes les adresses IPv6 disponibles
  -s, --single       Afficher seulement la meilleure adresse (par défaut)
  -d, --debug        Activer le mode debug
  -i, --interface    Spécifier une interface réseau
  -p, --ping         Tester la connectivité des adresses
  -h, --help         Afficher cette aide
  --json             Sortie au format JSON
  --csv              Sortie au format CSV

Exemples:
  $(basename "$0")              # Afficher la meilleure IPv6
  $(basename "$0") -a           # Afficher toutes les IPv6
  $(basename "$0") -i eth0      # Vérifier l'interface eth0
  $(basename "$0") -p           # Tester la connectivité
EOF
}

# Fonction de logging
log() {
    if [ "$DEBUG" = true ] || [ "$1" = "ERROR" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2" >&2
    fi
}

# Fonction pour tester la connectivité IPv6
test_ipv6_connectivity() {
    local ip="$1"
    # Tester avec ping (si disponible)
    if command -v ping6 &> /dev/null; then
        if ping6 -c 1 -w "$TIMEOUT" "$ip" &> /dev/null; then
            return 0
        fi
    elif command -v ping &> /dev/null; then
        if ping -6 -c 1 -w "$TIMEOUT" "$ip" &> /dev/null; then
            return 0
        fi
    fi
    return 1
}

# Fonction pour déterminer si une IP est statique ou dynamique
get_ip_type() {
    local ip="$1"
    local interface="$2"
    
    # Vérifier via ip -6 addr show
    if ip -6 addr show dev "$interface" | grep -q "$ip.*[Dd]ynamic"; then
        echo "dynamic"
    elif ip -6 addr show dev "$interface" | grep -q "$ip.*[Pp]ermanent"; then
        echo "static"
    else
        echo "unknown"
    fi
}

# Fonction pour obtenir les infos de l'interface
get_interface_info() {
    local interface="$1"
    local info=""
    
    # État de l'interface
    if ip link show dev "$interface" | grep -q "state UP"; then
        info+="UP,"
    else
        info+="DOWN,"
    fi
    
    # MAC address
    local mac=$(ip link show dev "$interface" | awk '/link\/ether/ {print $2}')
    info+="MAC:$mac,"
    
    # MTU
    local mtu=$(ip link show dev "$interface" | awk '/mtu/ {print $5}')
    info+="MTU:$mtu"
    
    echo "$info"
}

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            SHOW_ALL=true
            shift
            ;;
        -s|--single)
            SHOW_ALL=false
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -i|--interface)
            CUSTOM_INTERFACE="$2"
            shift 2
            ;;
        -p|--ping)
            DO_PING_TEST=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --csv)
            OUTPUT_FORMAT="csv"
            shift
            ;;
        *)
            echo "Option inconnue: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

log "INFO" "Démarrage du script IPv6"

# Détection de l'interface réseau
if [ -n "$CUSTOM_INTERFACE" ]; then
    MAIN_INTERFACE="$CUSTOM_INTERFACE"
    log "INFO" "Interface spécifiée: $MAIN_INTERFACE"
else
    # Détection automatique améliorée
    MAIN_INTERFACE=$(ip -o link show | awk -F': ' '
        $0 !~ /lo|vir|wl|docker|tun|veth|br-|lxc|gre|sit|erspan|gretap|DOWN/ {
            if ($2 ~ /^en/ || $2 ~ /^eth/) {
                print $2;
                exit;
            }
        }
    ')
    
    # Fallback si pas trouvé
    if [ -z "$MAIN_INTERFACE" ]; then
        MAIN_INTERFACE=$(ip -o link show | awk -F': ' '
            $0 !~ /lo|vir|wl|docker|tun|veth|br-|lxc|gre|sit|erspan|gretap|DOWN/ {
                print $2;
                exit;
            }
        ')
    fi
fi

if [ -z "$MAIN_INTERFACE" ]; then
    echo "ERREUR: Aucune interface réseau principale trouvée." >&2
    log "ERROR" "Interface réseau non trouvée"
    exit 1
fi

log "INFO" "Interface détectée: $MAIN_INTERFACE"

# Vérifier que l'interface est UP
if ! ip link show dev "$MAIN_INTERFACE" | grep -q "state UP"; then
    echo "ATTENTION: L'interface $MAIN_INTERFACE n'est pas UP" >&2
    log "WARNING" "Interface $MAIN_INTERFACE est DOWN"
fi

# Récupérer toutes les adresses IPv6 globales
IPV6_ADDRESSES=()
while IFS= read -r line; do
    if [ -n "$line" ]; then
        IPV6_ADDRESSES+=("$line")
    fi
done < <(ip -6 addr show dev "$MAIN_INTERFACE" scope global | \
         awk '/inet6/ {print $2}' | \
         grep -v "^fd" | grep -v "^fc" | grep -v "::1/" | \
         sed 's/\/[0-9]*//')

if [ ${#IPV6_ADDRESSES[@]} -eq 0 ]; then
    echo "ERREUR: Aucune adresse IPv6 globale trouvée sur $MAIN_INTERFACE" >&2
    log "ERROR" "Pas d'adresse IPv6 globale sur $MAIN_INTERFACE"
    exit 1
fi

log "INFO" "${#IPV6_ADDRESSES[@]} adresse(s) IPv6 trouvée(s)"

# Fonction d'affichage selon le format
display_output() {
    local addresses=("$@")
    
    case "$OUTPUT_FORMAT" in
        "json")
            echo "["
            for ((i=0; i<${#addresses[@]}; i++)); do
                ip="${addresses[$i]}"
                ip_type=$(get_ip_type "$ip" "$MAIN_INTERFACE")
                reachable="false"
                if [ "$DO_PING_TEST" = true ]; then
                    if test_ipv6_connectivity "$ip"; then
                        reachable="true"
                    fi
                fi
                
                echo -n "  {\"address\": \"$ip\", \"type\": \"$ip_type\", \"reachable\": $reachable}"
                if [ $i -lt $((${#addresses[@]} - 1)) ]; then
                    echo ","
                else
                    echo ""
                fi
            done
            echo "]"
            ;;
        "csv")
            echo "address,type,reachable,interface"
            for ip in "${addresses[@]}"; do
                ip_type=$(get_ip_type "$ip" "$MAIN_INTERFACE")
                reachable="no"
                if [ "$DO_PING_TEST" = true ]; then
                    if test_ipv6_connectivity "$ip"; then
                        reachable="yes"
                    fi
                fi
                echo "$ip,$ip_type,$reachable,$MAIN_INTERFACE"
            done
            ;;
        *)
            # Format par défaut
            echo "==========================================="
            echo "Interface: $MAIN_INTERFACE ($(get_interface_info "$MAIN_INTERFACE"))"
            echo "Adresses IPv6 globales trouvées: ${#addresses[@]}"
            echo "==========================================="
            
            for ip in "${addresses[@]}"; do
                ip_type=$(get_ip_type "$ip" "$MAIN_INTERFACE")
                marker=""
                
                # Marquage spécial pour la première adresse (recommandée pour DNS)
                if [ "$ip" = "${addresses[0]}" ]; then
                    marker=" ← recommandée pour AAAA"
                fi
                
                # Test de ping si demandé
                ping_info=""
                if [ "$DO_PING_TEST" = true ]; then
                    if test_ipv6_connectivity "$ip"; then
                        ping_info="✓ accessible"
                    else
                        ping_info="✗ inaccessible"
                    fi
                fi
                
                printf "%-40s %-10s %-15s %s\n" "$ip" "[$ip_type]" "$ping_info" "$marker"
            done
            
            echo "==========================================="
            if [ "$SHOW_ALL" = false ]; then
                echo "Pour le DNS AAAA, utilisez: ${addresses[0]}"
            fi
            ;;
    esac
}

# Afficher les résultats
if [ "$SHOW_ALL" = true ]; then
    display_output "${IPV6_ADDRESSES[@]}"
else
    # Afficher seulement la première (meilleure) adresse
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{\"address\": \"${IPV6_ADDRESSES[0]}\", \"interface\": \"$MAIN_INTERFACE\"}"
    elif [ "$OUTPUT_FORMAT" = "csv" ]; then
        echo "address,interface"
        echo "${IPV6_ADDRESSES[0]},$MAIN_INTERFACE"
    else
        echo "${IPV6_ADDRESSES[0]}"
    fi
fi

log "INFO" "Script terminé avec succès"
exit 0