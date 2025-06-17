#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0 - Version Prometheus
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# HEARTBOX ANALYSIS - Analyse complète de la ♥️box UPlanet via Prometheus
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Configuration Prometheus
PROMETHEUS_URL="http://localhost:9090"
PROMETHEUS_API="/api/v1"

#######################################################################
# Fonction d'aide
#######################################################################
show_help() {
    cat << EOF
HEARTBOX ANALYSIS - Analyse complète de la ♥️box UPlanet via Prometheus
========================================================

UTILISATION:
    $0 [COMMANDE] [OPTIONS]

COMMANDES:
    analyze            Analyse complète via Prometheus (défaut)
    export --json     Export de toutes les données au format JSON
    --help            Affiche cette aide

EXEMPLES:
    $0                              # Analyse complète par défaut
    $0 export --json               # Export JSON vers stdout
    $0 export --json > data.json   # Export JSON vers fichier

SORTIE JSON:
    L'option 'export --json' génère une structure JSON complète avec:
    - timestamp: Date/heure de l'analyse
    - node_info: Informations sur le node (ID, capitaine, type)
    - system: Données système (CPU, RAM, disque)
    - services: État des services (IPFS, Astroport, NextCloud)
    - capacities: Capacités d'abonnement calculées

LICENCE: AGPL-3.0
AUTEUR: Fred (support@qo-op.com)
EOF
}

#######################################################################
# Fonctions utilitaires pour JSON
#######################################################################

# Escape JSON strings et nettoyer les caractères de fin de ligne
json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r' | xargs
}

#######################################################################
# Fonctions d'accès à l'API Prometheus
#######################################################################

# Fonction pour interroger l'API Prometheus
query_prometheus() {
    local query="$1"
    local result=$(curl -s "${PROMETHEUS_URL}${PROMETHEUS_API}/query" --data-urlencode "query=${query}")
    echo "$result"
}

# Fonction pour obtenir une métrique instantanée
get_instant_metric() {
    local query="$1"
    local result=$(query_prometheus "$query")
    echo "$result" | jq -r '.data.result[0].value[1] // "0"'
}

# Fonction pour obtenir une métrique avec des labels
get_metric_with_labels() {
    local query="$1"
    local result=$(query_prometheus "$query")
    echo "$result" | jq -r '.data.result[] | {metric: .metric, value: .value[1]}'
}

#######################################################################
# Fonctions d'analyse des métriques
#######################################################################

# Analyse des métriques système
analyze_system_metrics() {
    echo "Analyse des métriques système via Prometheus..."
    
    # CPU
    local cpu_usage=$(get_instant_metric '100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)')
    local cpu_cores=$(get_instant_metric 'count(node_cpu_seconds_total{mode="idle"})')
    
    # Mémoire
    local mem_total=$(get_instant_metric 'node_memory_MemTotal_bytes')
    local mem_available=$(get_instant_metric 'node_memory_MemAvailable_bytes')
    local mem_used=$((mem_total - mem_available))
    local mem_usage_percent=$(echo "scale=2; ($mem_used * 100) / $mem_total" | bc)
    
    # Disque
    local disk_total=$(get_instant_metric 'node_filesystem_size_bytes{mountpoint="/"}')
    local disk_free=$(get_instant_metric 'node_filesystem_free_bytes{mountpoint="/"}')
    local disk_used=$((disk_total - disk_free))
    local disk_usage_percent=$(echo "scale=2; ($disk_used * 100) / $disk_total" | bc)
    
    # Performance disque
    local disk_read_speed=$(get_instant_metric 'rate(node_disk_read_bytes_total[5m])')
    local disk_write_speed=$(get_instant_metric 'rate(node_disk_written_bytes_total[5m])')
    
    # Afficher les résultats
    echo "
=== MÉTRIQUES SYSTÈME ==="
    echo "CPU:"
    echo "  Utilisation: ${cpu_usage}%"
    echo "  Cœurs: $cpu_cores"
    
    echo "
Mémoire:"
    echo "  Total: $(echo "scale=2; $mem_total/1024/1024/1024" | bc) GB"
    echo "  Utilisée: $(echo "scale=2; $mem_used/1024/1024/1024" | bc) GB"
    echo "  Utilisation: ${mem_usage_percent}%"
    
    echo "
Disque:"
    echo "  Total: $(echo "scale=2; $disk_total/1024/1024/1024" | bc) GB"
    echo "  Utilisé: $(echo "scale=2; $disk_used/1024/1024/1024" | bc) GB"
    echo "  Utilisation: ${disk_usage_percent}%"
    echo "  Vitesse lecture: $(echo "scale=2; $disk_read_speed/1024/1024" | bc) MB/s"
    echo "  Vitesse écriture: $(echo "scale=2; $disk_write_speed/1024/1024" | bc) MB/s"
}

# Analyse des services
analyze_services() {
    echo "
=== ÉTAT DES SERVICES ==="
    
    # IPFS
    local ipfs_up=$(get_instant_metric 'up{job="ipfs"}')
    local ipfs_peers=$(get_instant_metric 'ipfs_peers_total')
    local ipfs_repo_size=$(get_instant_metric 'ipfs_repo_size_bytes')
    
    echo "IPFS:"
    echo "  État: $(if [ "$ipfs_up" = "1" ]; then echo "✅ Actif"; else echo "❌ Inactif"; fi)"
    echo "  Peers: $ipfs_peers"
    echo "  Taille repo: $(echo "scale=2; $ipfs_repo_size/1024/1024/1024" | bc) GB"
    
    # NextCloud
    local nextcloud_up=$(get_instant_metric 'up{job="nextcloud"}')
    local nextcloud_users=$(get_instant_metric 'nextcloud_users_total')
    
    echo "
NextCloud:"
    echo "  État: $(if [ "$nextcloud_up" = "1" ]; then echo "✅ Actif"; else echo "❌ Inactif"; fi)"
    echo "  Utilisateurs: $nextcloud_users"
    
    # Astroport
    local astroport_up=$(get_instant_metric 'up{job="astroport"}')
    
    echo "
Astroport:"
    echo "  État: $(if [ "$astroport_up" = "1" ]; then echo "✅ Actif"; else echo "❌ Inactif"; fi)"
}

# Analyse des capacités
analyze_capacities() {
    echo "
=== CAPACITÉS D'ABONNEMENT ==="
    
    # Espace disponible pour NextCloud
    local nextcloud_available=$(get_instant_metric 'node_filesystem_free_bytes{mountpoint="/nextcloud-data"}')
    local nextcloud_available_gb=$(echo "scale=2; $nextcloud_available/1024/1024/1024" | bc)
    
    # Espace disponible pour IPFS
    local ipfs_available=$(get_instant_metric 'node_filesystem_free_bytes{mountpoint="/"}')
    local ipfs_available_gb=$(echo "scale=2; $ipfs_available/1024/1024/1024" | bc)
    
    # Calcul des slots
    local zencard_parts=$(echo "scale=0; ($nextcloud_available_gb - 8*128) / 128" | bc)
    local nostr_parts=$(echo "scale=0; ($ipfs_available_gb - 8*10) / 10" | bc)
    
    # S'assurer que les parts ne sont pas négatives
    [ $(echo "$zencard_parts < 0" | bc) -eq 1 ] && zencard_parts=0
    [ $(echo "$nostr_parts < 0" | bc) -eq 1 ] && nostr_parts=0
    
    echo "Capacité d'abonnements (après réserve capitaine):"
    echo "  ZenCards (128 GB/slot): $zencard_parts slots disponibles"
    echo "  NOSTR Cards (10 GB/slot): $nostr_parts slots disponibles"
    echo "  Réservé capitaine: 8 slots (1024 GB)"
}

#######################################################################
# Export JSON
#######################################################################
export_json() {
    local timestamp=$(date -Iseconds)
    local node_id="${IPFSNODEID:-unknown}"
    local captain=$(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo "unknown")
    local node_type="standard"
    if [[ -f ~/.zen/game/secret.dunikey ]]; then
        node_type="y_level"
    fi
    
    # Récupérer les métriques système
    local cpu_usage=$(get_instant_metric '100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)')
    local cpu_cores=$(get_instant_metric 'count(node_cpu_seconds_total{mode="idle"})')
    local mem_total=$(get_instant_metric 'node_memory_MemTotal_bytes')
    local mem_available=$(get_instant_metric 'node_memory_MemAvailable_bytes')
    local disk_total=$(get_instant_metric 'node_filesystem_size_bytes{mountpoint="/"}')
    local disk_free=$(get_instant_metric 'node_filesystem_free_bytes{mountpoint="/"}')
    
    # Récupérer les métriques des services
    local ipfs_up=$(get_instant_metric 'up{job="ipfs"}')
    local ipfs_peers=$(get_instant_metric 'ipfs_peers_total')
    local nextcloud_up=$(get_instant_metric 'up{job="nextcloud"}')
    local astroport_up=$(get_instant_metric 'up{job="astroport"}')
    
    cat << EOF
{
    "timestamp": "$timestamp",
    "node_info": {
        "id": "$node_id",
        "captain": "$captain",
        "type": "$node_type"
    },
    "system": {
        "cpu": {
            "usage_percent": $cpu_usage,
            "cores": $cpu_cores
        },
        "memory": {
            "total_bytes": $mem_total,
            "available_bytes": $mem_available
        },
        "storage": {
            "total_bytes": $disk_total,
            "free_bytes": $disk_free
        }
    },
    "services": {
        "ipfs": {
            "active": $(if [ "$ipfs_up" = "1" ]; then echo "true"; else echo "false"; fi),
            "peers": $ipfs_peers
        },
        "nextcloud": {
            "active": $(if [ "$nextcloud_up" = "1" ]; then echo "true"; else echo "false"; fi)
        },
        "astroport": {
            "active": $(if [ "$astroport_up" = "1" ]; then echo "true"; else echo "false"; fi)
        }
    }
}
EOF
}

#######################################################################
# Interface en ligne de commande
#######################################################################
case "${1:-analyze}" in
    "analyze")
        analyze_system_metrics
        analyze_services
        analyze_capacities
        ;;
    "export")
        if [[ "$2" == "--json" ]]; then
            export_json
        else
            echo "Usage: $0 export --json"
            echo "Export toutes les données au format JSON"
            exit 1
        fi
        ;;
    "--help"|"help")
        show_help
        ;;
    *)
        echo "Usage: $0 [analyze|export|--help] [params...]"
        echo ""
        echo "Commandes:"
        echo "  analyze            - Analyse complète via Prometheus (défaut)"
        echo "  export --json     - Export JSON de toutes les données"
        echo "  --help            - Affiche l'aide complète"
        echo ""
        echo "Pour plus d'informations: $0 --help"
        ;;
esac 