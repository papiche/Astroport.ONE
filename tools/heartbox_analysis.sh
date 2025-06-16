#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.1 - Ajout export JSON et aide
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# HEARTBOX ANALYSIS - Analyse complète de la ♥️box UPlanet
# Fonctions analytiques extraites de 20h12.process.sh pour une meilleure modularité
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

#######################################################################
# Fonction d'aide
#######################################################################
show_help() {
    cat << EOF
HEARTBOX ANALYSIS - Analyse complète de la ♥️box UPlanet
========================================================

UTILISATION:
    $0 [COMMANDE] [OPTIONS]

COMMANDES:
    save [phase]        Sauvegarde logs avec analyse complète (défaut)
                       Phase optionnelle: PREMIER_NETTOYAGE, EXECUTION_TERMINEE, etc.
    
    caches             Analyse des caches système uniquement
                       - Cache Swarm (nodes, services)
                       - Cache Coucou (profils Cesium/GChange)
                       - Cache FlashMem (géokeys, TiddlyWikis)
    
    hardware           Analyse matérielle uniquement
                       - CPU, GPU, RAM
                       - Stockage et capacités d'abonnement
                       - IPFS et NextCloud
    
    complete [file]    Analyse complète vers fichier spécifique
                       Par défaut: /tmp/heartbox_analysis_YYYYMMDD_HHMMSS.log
    
    export --json      Export de toutes les données au format JSON
                       Structure: caches, hardware, services, capacities
    
    --help            Affiche cette aide

EXEMPLES:
    $0                              # Sauvegarde avec analyse par défaut
    $0 save "MAINTENANCE"           # Sauvegarde avec phase personnalisée
    $0 caches                       # Analyse des caches seulement
    $0 hardware                     # Analyse matérielle seulement
    $0 complete /tmp/rapport.log    # Analyse complète vers fichier
    $0 export --json               # Export JSON vers stdout
    $0 export --json > data.json   # Export JSON vers fichier

SORTIE JSON:
    L'option 'export --json' génère une structure JSON complète avec:
    - timestamp: Date/heure de l'analyse
    - node_info: Informations sur le node (ID, capitaine, type)
    - system: Données système (CPU, RAM, disque)
    - caches: État des caches UPlanet
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
# Fonction pour mesurer la vitesse de lecture/écriture du disque
#######################################################################
measure_disk_speed() {
    local mount_point="$1"
    local device=$(df -P "$mount_point" | awk 'NR==2 {print $1}' 2>/dev/null)
    local read_speed_mbps="0"
    local write_speed_mbps="0"
    local temp_file="${mount_point}/.disk_test_$(date +%s%N)"
    local dd_test_size_mb="500" # Taille du fichier de test pour dd (en MB)

    echo "  Lancement du test de performance disque pour $mount_point (device: ${device:-N/A})..."

    # Test de lecture : Tente d'abord hdparm (nécessite sudo pour le périphérique brut), sinon utilise dd.
    if [[ -n "$device" && -e "$device" ]]; then
        # Tente d'utiliser hdparm. '|| true' évite que le script ne sorte si sudo échoue (ex: pas de mot de passe)
        local hdparm_output=$(sudo hdparm -tT "$device" 2>&1 || true)
        if echo "$hdparm_output" | grep -q "No such device or address\\|permission denied\\|Operation not permitted"; then
            echo "  Avertissement: Impossible d'accéder au périphérique $device avec hdparm (erreur de permission ou périphérique). Retour au test de lecture avec dd." >&2
            # Fallback vers dd si hdparm échoue
            if [[ -w "$mount_point" ]]; then
                # Crée un fichier temporaire pour le test de lecture dd
                dd if=/dev/zero of="$temp_file" bs=1M count="$dd_test_size_mb" status=none conv=fdatasync 2>/dev/null
                local dd_read_output=$(dd if="$temp_file" of=/dev/null bs=1M status=none iflag=direct 2>&1)
                read_speed_mbps=$(echo "$dd_read_output" | grep "copied" | grep -oP '\\d+\\.?\\d* \\w+/s' | awk '{print int($1)}' | tr -d '\n')
                local read_unit=$(echo "$dd_read_output" | grep "copied" | grep -oP '\\d+\\.?\\d* \\w+/s' | awk '{print $2}' | tr -d '\n')
                if [[ "$read_unit" == "GB/s" ]]; then read_speed_mbps=$(echo "$read_speed_mbps * 1024" | bc | awk '{print int($1)}'); fi
                rm -f "$temp_file" 2>/dev/null
            fi
        else
            # Extrait la vitesse de lecture tamponnée de hdparm
            local buffered_read_line=$(echo "$hdparm_output" | grep "buffered disk reads")
            if [[ -n "$buffered_read_line" ]]; then
                read_speed_mbps=$(echo "$buffered_read_line" | grep -oP '\\d+\\.?\\d* MB/sec' | awk '{print int($1)}' | tr -d '\n')
            fi
        fi
    elif [[ -d "$mount_point" && -w "$mount_point" ]]; then
        echo "  Avertissement: Le périphérique pour $mount_point n'a pas pu être déterminé. Réalisation du test de lecture avec dd à la place." >&2
        # Fallback direct vers dd si le chemin du périphérique n'est pas trouvé
        dd if=/dev/zero of="$temp_file" bs=1M count="$dd_test_size_mb" status=none conv=fdatasync 2>/dev/null
        local dd_read_output=$(dd if="$temp_file" of=/dev/null bs=1M status=none iflag=direct 2>&1)
        read_speed_mbps=$(echo "$dd_read_output" | grep "copied" | grep -oP '\\d+\\.?\\d* \\w+/s' | awk '{print int($1)}' | tr -d '\n')
        local read_unit=$(echo "$dd_read_output" | grep "copied" | grep -oP '\\d+\\.?\\d* \\w+/s' | awk '{print $2}' | tr -d '\n')
        if [[ "$read_unit" == "GB/s" ]]; then read_speed_mbps=$(echo "$read_speed_mbps * 1024" | bc | awk '{print int($1)}'); fi
        rm -f "$temp_file" 2>/dev/null
    else
        echo "  Erreur: Le point de montage '$mount_point' n'est pas accessible ou inscriptible pour le test de lecture. Vitesse de lecture: 0." >&2
    fi

    # Test d'écriture avec dd (toujours sur le système de fichiers)
    if [[ -d "$mount_point" && -w "$mount_point" ]]; then
        # Crée un fichier de test temporaire. 'conv=fdatasync' assure que les données sont physiquement écrites sur le disque.
        local dd_write_output=$(dd if=/dev/zero of="$temp_file" bs=1M count="$dd_test_size_mb" conv=fdatasync status=none 2>&1)
        if [[ -n "$dd_write_output" ]]; then
            local write_speed_line=$(echo "$dd_write_output" | grep "copied" | grep -oP '\\d+\\.?\\d* \\w+/s')
            if [[ -n "$write_speed_line" ]]; then
                local speed_value=$(echo "$write_speed_line" | awk '{print $1}')
                local speed_unit=$(echo "$write_speed_line" | awk '{print $2}')

                # Convertir en MB/s
                if [[ "$speed_unit" == "GB/s" ]]; then
                    write_speed_mbps=$(echo "$speed_value * 1024" | bc | awk '{print int($1)}')
                elif [[ "$speed_unit" == "kB/s" ]]; then
                    write_speed_mbps=$(echo "$speed_value / 1024" | bc | awk '{print int($1)}')
                else # Supposons MB/s
                    write_speed_mbps=$(echo "$speed_value" | awk '{print int($1)}')
                fi
            fi
        fi
        rm -f "$temp_file" 2>/dev/null
    else
        echo "  Erreur: Le point de montage '$mount_point' n'est pas inscriptible pour le test d'écriture. Vitesse d'écriture: 0." >&2
    fi

    echo "$read_speed_mbps $write_speed_mbps" # Retourne les valeurs séparées par un espace
}

# Get system info as JSON object
get_system_info_json() {
    local root_read_speed_mbps="$1"
    local root_write_speed_mbps="$2"
    local nextcloud_read_speed_mbps="$3"
    local nextcloud_write_speed_mbps="$4"

    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "Non détecté")
    local cpu_cores=$(grep "processor" /proc/cpuinfo | wc -l 2>/dev/null || echo "0")
    local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "0")
    local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | xargs | cut -d',' -f1)
    
    local mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local mem_used=$((mem_total - mem_available))
    local mem_total_gb=$((mem_total / 1024 / 1024))
    local mem_used_gb=$((mem_used / 1024 / 1024))
    local mem_usage_percent=$((mem_used * 100 / mem_total))
    
    local disk_info=$(df -h / | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}' | tr -d '\n')
    local disk_used=$(echo "$disk_info" | awk '{print $3}' | tr -d '\n')
    local disk_available=$(echo "$disk_info" | awk '{print $4}' | tr -d '\n')
    local disk_usage_percent=$(echo "$disk_info" | awk '{print $5}' | tr -d '\n')
    
    # GPU detection
    local gpu_info="null"
    if command -v nvidia-smi >/dev/null 2>&1; then
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d '\n')
        if [[ -n "$gpu_info" ]]; then
            gpu_info="\"$(json_escape "$gpu_info")\""
        else
            gpu_info="null"
        fi
    fi
    
    cat << EOF
    "cpu": {
        "model": "$(json_escape "$cpu_model")",
        "cores": $cpu_cores,
        "frequency_mhz": $cpu_freq,
        "load_average": "$cpu_load"
    },
    "memory": {
        "total_gb": $mem_total_gb,
        "used_gb": $mem_used_gb,
        "usage_percent": $mem_usage_percent
    },
    "storage": {
        "total": "$(json_escape "$disk_total")",
        "used": "$(json_escape "$disk_used")",
        "available": "$(json_escape "$disk_available")",
        "usage_percent": "$(json_escape "$disk_usage_percent")",
        "root_disk_read_mbps": $root_read_speed_mbps,
        "root_disk_write_mbps": $root_write_speed_mbps,
        "nextcloud_disk_read_mbps": $nextcloud_read_speed_mbps,
        "nextcloud_disk_write_mbps": $nextcloud_write_speed_mbps
    },
    "gpu": $gpu_info
EOF
}

# Get caches info as JSON
get_caches_info_json() {
    # Cache Swarm
    local swarm_data="null"
    if [[ -d ~/.zen/tmp/swarm ]]; then
        local swarm_size=$(du -sh ~/.zen/tmp/swarm 2>/dev/null | cut -f1 | tr -d '\n')
        local swarm_nodes=$(find ~/.zen/tmp/swarm -maxdepth 1 -type d -name "12D*" | wc -l)
        local swarm_files=$(find ~/.zen/tmp/swarm -type f | wc -l)
        
        swarm_data="{
            \"size\": \"$(json_escape "$swarm_size")\",
            \"nodes_count\": $swarm_nodes,
            \"files_count\": $swarm_files,
            \"status\": \"active\"
        }"
    else
        swarm_data="{\"status\": \"not_found\"}"
    fi
    
    # Cache Coucou
    local coucou_data="null"
    if [[ -d ~/.zen/tmp/coucou ]]; then
        local coucou_size=$(du -sh ~/.zen/tmp/coucou 2>/dev/null | cut -f1 | tr -d '\n')
        local coucou_files=$(find ~/.zen/tmp/coucou -type f | wc -l)
        local coins_files=$(find ~/.zen/tmp/coucou -name "*.COINS" | wc -l)
        local gchange_files=$(find ~/.zen/tmp/coucou -name "*.gchange.json" | wc -l)
        local cesium_files=$(find ~/.zen/tmp/coucou -name "*.cesium.json" | wc -l)
        local avatar_files=$(find ~/.zen/tmp/coucou -name "*.avatar.png" | wc -l)
        
        coucou_data="{
            \"size\": \"$(json_escape "$coucou_size")\",
            \"total_files\": $coucou_files,
            \"coins_files\": $coins_files,
            \"gchange_profiles\": $gchange_files,
            \"cesium_profiles\": $cesium_files,
            \"avatars\": $avatar_files,
            \"status\": \"active\"
        }"
    else
        coucou_data="{\"status\": \"not_found\"}"
    fi
    
    # Cache FlashMem
    local flashmem_data="null"
    if [[ -d ~/.zen/tmp/flashmem ]]; then
        local flashmem_size=$(du -sh ~/.zen/tmp/flashmem 2>/dev/null | cut -f1 | tr -d '\n')
        local geokeys_count=$(find ~/.zen/tmp/flashmem -maxdepth 1 -type d -name "k*" | wc -l)
        local tw_count=$(find ~/.zen/tmp/flashmem -path "*/TWz/*" -type f | wc -l)
        local uplanet_dirs=$(find ~/.zen/tmp/flashmem -name "UPLANET" -type d | wc -l)
        
        flashmem_data="{
            \"size\": \"$(json_escape "$flashmem_size")\",
            \"geokeys_count\": $geokeys_count,
            \"tiddlywikis_count\": $tw_count,
            \"uplanet_dirs\": $uplanet_dirs,
            \"status\": \"active\"
        }"
    else
        flashmem_data="{\"status\": \"not_found\"}"
    fi
    
    # Global cache stats
    local total_cache_size=$(du -sh ~/.zen/tmp/ 2>/dev/null | cut -f1 | tr -d '\n')
    local total_files=$(find ~/.zen/tmp -type f | wc -l)
    
    cat << EOF
    "swarm": $swarm_data,
    "coucou": $coucou_data,
    "flashmem": $flashmem_data,
    "global": {
        "total_size": "$(json_escape "$total_cache_size")",
        "total_files": $total_files
    }
EOF
}

# Get services status as JSON
get_services_status_json() {
    # IPFS
    local ipfs_status="false"
    local ipfs_size="null"
    local ipfs_peers="0"
    if pgrep ipfs >/dev/null; then
        ipfs_status="true"
        ipfs_size="\"$(du -sh ~/.ipfs 2>/dev/null | cut -f1 | tr -d '\n' || echo "N/A")\""
        ipfs_peers=$(ipfs swarm peers 2>/dev/null | wc -l || echo "0")
    fi
    
    # Astroport
    local astroport_status="false"
    if pgrep -f "12345" >/dev/null; then
        astroport_status="true"
    fi
    
    # uSPOT
    local uspot_status="false"
    if netstat -tln 2>/dev/null | grep -q ":54321 "; then
        uspot_status="true"
    fi
    
    # NextCloud
    local nextcloud_status="false"
    local nextcloud_containers="null"
    local nextcloud_aio_status="false"
    local nextcloud_cloud_status="false"
    if command -v docker >/dev/null 2>&1 && docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | grep -q nextcloud; then
        nextcloud_status="true"
        nextcloud_containers="\"$(docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | head -1 | tr -d '\n' || echo "unknown")\""
        
        # Check NextCloud AIO (port 8002)
        if netstat -tln 2>/dev/null | grep -q ":8002 "; then
            nextcloud_aio_status="true"
        fi
        
        # Check NextCloud Cloud (port 8001)
        if netstat -tln 2>/dev/null | grep -q ":8001 "; then
            nextcloud_cloud_status="true"
        fi
    fi
    
    # NOSTR Relay
    local nostr_relay_status="false"
    if netstat -tln 2>/dev/null | grep -q ":7777 "; then
        nostr_relay_status="true"
    fi
    
    # IPFS P2P Services
    local p2p_services="[]"
    if [[ -d ~/.zen/tmp/${IPFSNODEID} ]]; then
        local p2p_array=()
        for service in ~/.zen/tmp/${IPFSNODEID}/x_*.sh; do
            if [[ -f "$service" ]]; then
                local service_name=$(basename "$service")
                p2p_array+=("\"$service_name\"")
            fi
        done
        if [[ ${#p2p_array[@]} -gt 0 ]]; then
            p2p_services="[$(IFS=,; echo "${p2p_array[*]}")]"
        fi
    fi
    
    # G1Billet
    local g1billet_status="false"
    if pgrep -f "G1BILLETS" >/dev/null; then
        g1billet_status="true"
    fi
    
    cat << EOF
    "ipfs": {
        "active": $ipfs_status,
        "size": $ipfs_size,
        "peers_connected": $ipfs_peers
    },
    "astroport": {
        "active": $astroport_status
    },
    "uspot": {
        "active": $uspot_status,
        "port": 54321
    },
    "nextcloud": {
        "active": $nextcloud_status,
        "container": $nextcloud_containers,
        "aio_https": {
            "active": $nextcloud_aio_status,
            "port": 8002
        },
        "cloud_http": {
            "active": $nextcloud_cloud_status,
            "port": 8001
        }
    },
    "nostr_relay": {
        "active": $nostr_relay_status,
        "port": 7777
    },
    "ipfs_p2p_services": $p2p_services,
    "g1billet": {
        "active": $g1billet_status
    }
EOF
}

# Get capacities as JSON
get_capacities_json() {
    # Obtenir l'espace disponible pour NextCloud
    local nextcloud_available_gb=0
    if [[ -d "/nextcloud-data" ]]; then
        local nextcloud_info=$(df -h /nextcloud-data | tail -1)
        local nextcloud_available=$(echo "$nextcloud_info" | awk '{print $4}')
        nextcloud_available_gb=$(echo "$nextcloud_available" | sed 's/G//' | sed 's/T/*1024/' | sed 's/,/\./' | bc 2>/dev/null || echo "0")
    fi
    
    # Obtenir l'espace disponible pour IPFS
    local ipfs_info=$(df -h ~/.ipfs | tail -1)
    local ipfs_available=$(echo "$ipfs_info" | awk '{print $4}')
    local ipfs_available_gb=$(echo "$ipfs_available" | sed 's/G//' | sed 's/T/*1024/' | sed 's/,/\./' | bc 2>/dev/null || echo "0")
    
    # Obtenir l'espace disponible pour le disque principal
    local root_info=$(df -h / | tail -1)
    local root_available=$(echo "$root_info" | awk '{print $4}')
    local root_available_gb=$(echo "$root_available" | sed 's/G//' | sed 's/T/*1024/' | sed 's/,/\./' | bc 2>/dev/null || echo "0")
    
    # Calculer la capacité totale disponible
    local total_available_gb=$(echo "$nextcloud_available_gb + $ipfs_available_gb + $root_available_gb" | bc 2>/dev/null || echo "0")
    
    # Calculer les slots ZenCard basés sur l'espace NextCloud disponible
    local zencard_parts=0
    if [[ $(echo "$nextcloud_available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        zencard_parts=$(echo "($nextcloud_available_gb - 8*128) / 128" | bc 2>/dev/null || echo "0")
        [[ $(echo "$zencard_parts < 0" | bc 2>/dev/null) -eq 1 ]] && zencard_parts=0
    fi
    
    # Calculer les slots NOSTR basés sur l'espace IPFS disponible
    local nostr_parts=0
    if [[ $(echo "$ipfs_available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        nostr_parts=$(echo "($ipfs_available_gb - 8*10) / 10" | bc 2>/dev/null || echo "0")
        [[ $(echo "$nostr_parts < 0" | bc 2>/dev/null) -eq 1 ]] && nostr_parts=0
    fi
    
    cat << EOF
    "zencard_slots": $zencard_parts,
    "nostr_slots": $nostr_parts,
    "reserved_captain_slots": 8,
    "available_space_gb": $total_available_gb,
    "storage_details": {
        "nextcloud": {
            "available_gb": $nextcloud_available_gb,
            "mount_point": "/nextcloud-data",
            "status": "$(if [[ -d "/nextcloud-data" ]]; then echo "mounted"; else echo "not_mounted"; fi)"
        },
        "ipfs": {
            "available_gb": $ipfs_available_gb,
            "mount_point": "~/.ipfs"
        },
        "root": {
            "available_gb": $root_available_gb,
            "mount_point": "/"
        }
    }
EOF
}

#######################################################################
# Export JSON complet
#######################################################################
export_json() {
    local timestamp=$(date -Iseconds)
    local node_id="${IPFSNODEID:-unknown}"
    local captain=$(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo "unknown")
    local node_type="standard"
    if [[ -f ~/.zen/game/secret.dunikey ]]; then
        node_type="y_level"
    fi
    local hostname=$(hostname -f)
    
    # Réaliser les tests de disque et capturer les résultats
    local root_rw_speeds=$(measure_disk_speed "/")
    local root_read_speed=$(echo "$root_rw_speeds" | awk '{print $1}')
    local root_write_speed=$(echo "$root_rw_speeds" | awk '{print $2}')

    local nc_rw_speeds="0 0"
    if [[ -d "/nextcloud-data" ]]; then
        nc_rw_speeds=$(measure_disk_speed "/nextcloud-data")
    fi
    local nc_read_speed=$(echo "$nc_rw_speeds" | awk '{print $1}')
    local nc_write_speed=$(echo "$nc_rw_speeds" | awk '{print $2}')
    
    cat << EOF
{
    "timestamp": "$timestamp",
    "node_info": {
        "id": "$node_id",
        "captain": "$captain",
        "type": "$node_type",
        "hostname": "$hostname"
    },
    "system": {
$(get_system_info_json "$root_read_speed" "$root_write_speed" "$nc_read_speed" "$nc_write_speed")
    },
    "caches": {
$(get_caches_info_json)
    },
    "services": {
$(get_services_status_json)
    },
    "capacities": {
$(get_capacities_json)
    }
}
EOF
}

#######################################################################
# Fonction principale d'analyse et sauvegarde des logs
#######################################################################
save_logs_to_archive() {
    local archive_file="/tmp/20h12.log"
    local cleanup_phase="$1"
    
    echo "
#######################################################################
20H12 LOG ARCHIVE - Phase: $cleanup_phase - $(date)
#######################################################################" >> "$archive_file"

    # Logs système UPlanet
    echo "
=== LOGS SYSTEME UPLANET ===" >> "$archive_file"
    
    # Logs principaux
    local important_logs=(
        "~/.zen/tmp/12345.log"
        "~/.zen/tmp/_12345.log"
        "~/.zen/tmp/54321.log"
        "~/.zen/tmp/IA.log"
        "~/.zen/tmp/strfry.log"
        "~/.zen/tmp/uplanet_messages.log"
        "~/.zen/tmp/nostr_likes.log"
        "~/.zen/tmp/nostpy.log"
        "~/.zen/tmp/ipfs.swarm.peers"
    )
    
    for log_path in "${important_logs[@]}"; do
        expanded_path=$(eval echo "$log_path")
        if [[ -f "$expanded_path" ]]; then
            echo "
--- $expanded_path ($(stat -c%s "$expanded_path") bytes) ---" >> "$archive_file"
            # Garder seulement les 100 dernières lignes pour éviter un fichier trop gros
            tail -n 100 "$expanded_path" >> "$archive_file" 2>/dev/null
            echo "" >> "$archive_file"
        fi
    done
    
    # Logs d'erreurs et de debug
    echo "
=== LOGS D'ERREURS ===" >> "$archive_file"
    
    local error_logs=(
        "~/.zen/tmp/error.log"
        "~/.zen/tmp/debug.log"
        "~/.zen/tmp/crash.log"
        "~/.zen/tmp/git_pull.log"
        "~/.zen/tmp/youtube-dl.log"
    )
    
    for log_path in "${error_logs[@]}"; do
        expanded_path=$(eval echo "$log_path")
        if [[ -f "$expanded_path" ]]; then
            echo "
--- $expanded_path ($(stat -c%s "$expanded_path") bytes) ---" >> "$archive_file"
            tail -n 50 "$expanded_path" >> "$archive_file" 2>/dev/null
            echo "" >> "$archive_file"
        fi
    done
    
    # Statistiques sur les fichiers supprimés
    echo "
=== STATISTIQUES NETTOYAGE ===" >> "$archive_file"
    echo "Fichiers dans ~/.zen/tmp/ avant nettoyage:" >> "$archive_file"
    ls -la ~/.zen/tmp/ 2>/dev/null | head -20 >> "$archive_file"
    
    # Compter les fichiers
    local file_count=$(find ~/.zen/tmp/ -type f | wc -l)
    local total_size=$(du -sh ~/.zen/tmp/ 2>/dev/null | cut -f1)
    echo "Total: $file_count fichiers, taille: $total_size" >> "$archive_file"
    
    # Logs spécifiques à certains processus
    echo "
=== LOGS PROCESSUS SPECIFIQUES ===" >> "$archive_file"
    
    # Logs Zen Economy et Swarm
    if [[ -f ~/.zen/tmp/${IPFSNODEID}/swarm_subscriptions.json ]]; then
        echo "
--- Abonnements Swarm ---" >> "$archive_file"
        cat ~/.zen/tmp/${IPFSNODEID}/swarm_subscriptions.json >> "$archive_file" 2>/dev/null
    fi
    
    if [[ -f ~/.zen/tmp/${IPFSNODEID}/swarm_subscriptions_received.json ]]; then
        echo "
--- Abonnements Swarm Reçus ---" >> "$archive_file"
        cat ~/.zen/tmp/${IPFSNODEID}/swarm_subscriptions_received.json >> "$archive_file" 2>/dev/null
    fi
    
    # Logs de zones et secteurs
    local zone_files=($(ls ~/.zen/tmp/ZONE_* 2>/dev/null))
    if [[ ${#zone_files[@]} -gt 0 ]]; then
        echo "
--- ZONES UPlanet du jour ---" >> "$archive_file"
        for zone_file in "${zone_files[@]}"; do
            echo "Zone: $(basename "$zone_file")" >> "$archive_file"
        done
    fi

    # Appeler les analyses spécialisées
    analyze_system_caches >> "$archive_file"
    analyze_heartbox_hardware >> "$archive_file"
    
    echo "
=== FIN ARCHIVE PHASE $cleanup_phase - $(date) ===" >> "$archive_file"
    echo "" >> "$archive_file"
    
    echo "📝 Logs sauvegardés dans $archive_file (phase: $cleanup_phase)"
}

#######################################################################
# Analyse des caches système UPlanet
#######################################################################
analyze_system_caches() {
    echo "
#######################################################################
# ANALYSE DES CACHES SYSTÈME UPlanet
#######################################################################"
    echo "
=== ANALYSE DES CACHES SYSTÈME ==="
    
    # Cache Swarm (~/.zen/tmp/swarm) - Alimenté par _12345.sh
    echo "
--- CACHE SWARM (alimenté par _12345.sh) ---"
    if [[ -d ~/.zen/tmp/swarm ]]; then
        local swarm_size=$(du -sh ~/.zen/tmp/swarm 2>/dev/null | cut -f1)
        local swarm_nodes=$(find ~/.zen/tmp/swarm -maxdepth 1 -type d | wc -l)
        local swarm_files=$(find ~/.zen/tmp/swarm -type f | wc -l)
        
        echo "Taille totale: $swarm_size"
        echo "Nombre de nodes: $((swarm_nodes - 1))"
        echo "Nombre de fichiers: $swarm_files"
        
        # Lister les nodes actifs avec leurs timestamps
        echo "
Nodes actifs dans le swarm:"
        for node_dir in ~/.zen/tmp/swarm/12D*; do
            if [[ -d "$node_dir" ]]; then
                local node_id=$(basename "$node_dir")
                local moats_file="$node_dir/_MySwarm.moats"
                local json_file="$node_dir/12345.json"
                
                if [[ -f "$moats_file" ]]; then
                    local timestamp=$(cat "$moats_file")
                    echo "  $node_id: timestamp=$timestamp"
                fi
                
                if [[ -f "$json_file" ]]; then
                    local captain=$(jq -r '.captain' "$json_file" 2>/dev/null)
                    local hostname=$(jq -r '.hostname' "$json_file" 2>/dev/null)
                    local version=$(jq -r '.version' "$json_file" 2>/dev/null)
                    echo "    Captain: $captain, Host: $hostname, Version: $version"
                fi
            fi
        done
        
        # Services disponibles dans le swarm
        echo "
Services disponibles dans le swarm:"
        find ~/.zen/tmp/swarm -name "x_*.sh" -exec basename {} \; 2>/dev/null | sort | uniq -c
        
    else
        echo "Cache swarm non trouvé"
    fi
    
    # Cache Coucou (~/.zen/tmp/coucou) - Profils et portefeuilles
    echo "
--- CACHE COUCOU (profils Cesium/GChange) ---"
    if [[ -d ~/.zen/tmp/coucou ]]; then
        local coucou_size=$(du -sh ~/.zen/tmp/coucou 2>/dev/null | cut -f1)
        local coucou_files=$(find ~/.zen/tmp/coucou -type f | wc -l)
        local coins_files=$(find ~/.zen/tmp/coucou -name "*.COINS" | wc -l)
        local gchange_files=$(find ~/.zen/tmp/coucou -name "*.gchange.json" | wc -l)
        local cesium_files=$(find ~/.zen/tmp/coucou -name "*.cesium.json" | wc -l)
        local avatar_files=$(find ~/.zen/tmp/coucou -name "*.avatar.png" | wc -l)
        
        echo "Taille totale: $coucou_size"
        echo "Fichiers total: $coucou_files"
        echo "Fichiers COINS (soldes): $coins_files"
        echo "Profils GChange: $gchange_files"
        echo "Profils Cesium: $cesium_files"
        echo "Avatars: $avatar_files"
        
        # Analyser quelques profils récents
        echo "
Profils récents (dernières 24h):"
        find ~/.zen/tmp/coucou -name "*.gchange.json" -mtime -1 -exec basename {} .gchange.json \; 2>/dev/null | head -5
        
        # Soldes en cache
        echo "
Soldes en cache (exemples):"
        find ~/.zen/tmp/coucou -name "*.COINS" -mtime -1 2>/dev/null | head -5 | while read coins_file; do
            local g1pub=$(basename "$coins_file" .COINS)
            local balance=$(cat "$coins_file" 2>/dev/null)
            echo "  ${g1pub:0:20}...: $balance G1"
        done
        
    else
        echo "Cache coucou non trouvé"
    fi
    
    # Cache FlashMem (~/.zen/tmp/flashmem) - Géokeys
    echo "
--- CACHE FLASHMEM (géokeys - GEOKEYS_refresh.sh) ---"
    if [[ -d ~/.zen/tmp/flashmem ]]; then
        local flashmem_size=$(du -sh ~/.zen/tmp/flashmem 2>/dev/null | cut -f1)
        local geokeys_count=$(find ~/.zen/tmp/flashmem -maxdepth 1 -type d -name "k*" | wc -l)
        local tw_count=$(find ~/.zen/tmp/flashmem -path "*/TWz/*" -type f | wc -l)
        local uplanet_dirs=$(find ~/.zen/tmp/flashmem -name "UPLANET" -type d | wc -l)
        
        echo "Taille totale: $flashmem_size"
        echo "Géokeys cachées: $geokeys_count"
        echo "TiddlyWikis (TWz): $tw_count"
        echo "Répertoires UPlanet: $uplanet_dirs"
        
        # Analyser les géokeys par type
        echo "
Types de géokeys en cache:"
        for geo_type in UMAPS SECTORS REGIONS; do
            local count=$(find ~/.zen/tmp/flashmem -path "*UPLANET/$geo_type*" -type d | wc -l)
            echo "  $geo_type: $count"
        done
        
        # Géokeys récentes
        echo "
Géokeys récentes (dernières 6h):"
        find ~/.zen/tmp/flashmem -maxdepth 1 -type d -name "k*" -mmin -360 2>/dev/null | head -10 | while read geo_dir; do
            local geo_key=$(basename "$geo_dir")
            local size=$(du -sh "$geo_dir" 2>/dev/null | cut -f1)
            echo "  $geo_key: $size"
        done
        
        # Analyse des TiddlyWikis
        if [[ -d ~/.zen/tmp/flashmem/tw ]]; then
            local tw_total=$(find ~/.zen/tmp/flashmem/tw -name "*.html" | wc -l)
            echo "
TiddlyWikis individuels: $tw_total"
        fi
        
    else
        echo "Cache flashmem non trouvé"
    fi
    
    # Statistiques globales des caches
    echo "
--- STATISTIQUES GLOBALES DES CACHES ---"
    local total_cache_size=$(du -sh ~/.zen/tmp/ 2>/dev/null | cut -f1)
    local total_files=$(find ~/.zen/tmp -type f | wc -l)
    local cache_age_hours=$((($(date +%s) - $(stat -c %Y ~/.zen/tmp 2>/dev/null || echo 0)) / 3600))
    
    echo "Taille totale ~/.zen/tmp/: $total_cache_size"
    echo "Fichiers total: $total_files"
    echo "Âge du cache: ${cache_age_hours}h"
    
    # Processus actifs liés aux caches
    echo "
--- PROCESSUS ACTIFS (gestion des caches) ---"
    pgrep -af "_12345.sh\|COINScheck.sh\|GetGCAttributesFromG1PUB.sh\|GEOKEYS_refresh.sh" 2>/dev/null || echo "Aucun processus de cache actif"
}

#######################################################################
# Analyse complète du matériel ♥️BOX
#######################################################################
analyze_heartbox_hardware() {
    echo "
#######################################################################
# ANALYSE DE LA ♥️BOX (HEARTBOX) - MATÉRIEL ET CAPACITÉS
#######################################################################"
    echo "
=== ANALYSE DE LA ♥️BOX (HEARTBOX) ==="
    
    # Informations CPU
    echo "
--- PROCESSEUR (CPU) ---"
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        local cpu_cores=$(grep "processor" /proc/cpuinfo | wc -l)
        local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        local cpu_cache=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        
        echo "Modèle: $cpu_model"
        echo "Cœurs/Threads: $cpu_cores"
        echo "Fréquence: ${cpu_freq} MHz"
        echo "Cache: $cpu_cache"
        
        # Charge CPU
        local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | xargs)
        echo "Charge moyenne: $cpu_load"
    fi
    
    # Informations GPU
    echo "
--- PROCESSEUR GRAPHIQUE (GPU) ---"
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "GPU NVIDIA détecté:"
        nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | while IFS=',' read name memory_total memory_used gpu_util; do
            echo "  Modèle: $name"
            echo "  VRAM: ${memory_used}MB / ${memory_total}MB utilisée"
            echo "  Utilisation: ${gpu_util}%"
        done
    elif command -v lspci >/dev/null 2>&1; then
        local gpu_info=$(lspci | grep -i "vga\|3d\|display" | head -1)
        echo "GPU détecté: $gpu_info"
    else
        echo "Aucun GPU détecté ou outils non disponibles"
    fi
    
    # Mémoire RAM
    echo "
--- MÉMOIRE RAM ---"
    if [[ -f /proc/meminfo ]]; then
        local mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        local mem_used=$((mem_total - mem_available))
        local mem_total_gb=$((mem_total / 1024 / 1024))
        local mem_used_gb=$((mem_used / 1024 / 1024))
        local mem_usage_percent=$((mem_used * 100 / mem_total))
        
        echo "Total: ${mem_total_gb} GB"
        echo "Utilisée: ${mem_used_gb} GB (${mem_usage_percent}%)"
    fi
    
    # Analyse du stockage et capacités ♥️BOX
    echo "
--- STOCKAGE ET CAPACITÉS ♥️BOX ---"
    
    # Espace disque total et disponible
    local disk_info=$(df -h / | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_available=$(echo "$disk_info" | awk '{print $4}')
    local disk_usage_percent=$(echo "$disk_info" | awk '{print $5}')
    
    echo "Disque principal (/):"
    echo "  Total: $disk_total"
    echo "  Utilisé: $disk_used ($disk_usage_percent)"
    echo "  Disponible: $disk_available"
    
    # Conversion en GB pour calculs
    local available_gb=$(echo "$disk_available" | sed 's/G//' | sed 's/T/*1024/' | bc 2>/dev/null || echo "0")
    
    # Calculs des parts d'abonnement (en soustrayant 8 parts pour le capitaine)
    if [[ $(echo "$available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        local zencard_parts=$(echo "($available_gb - 8*128) / 128" | bc 2>/dev/null || echo "0")
        local nostr_parts=$(echo "($available_gb - 8*10) / 10" | bc 2>/dev/null || echo "0")
        
        # S'assurer que les parts ne sont pas négatives
        [[ $(echo "$zencard_parts < 0" | bc 2>/dev/null) -eq 1 ]] && zencard_parts=0
        [[ $(echo "$nostr_parts < 0" | bc 2>/dev/null) -eq 1 ]] && nostr_parts=0
        
        echo "
Capacité d'abonnements (après réserve capitaine):"
        echo "  ZenCards (128 GB/slot): $zencard_parts slots disponibles"
        echo "  NOSTR Cards (10 GB/slot): $nostr_parts slots disponibles"
        echo "  Réservé capitaine: 8 slots (1024 GB)"
    fi
    
    analyze_ipfs_storage
    analyze_nextcloud_docker
    
    # Tests de performances disque (Lecture/Écriture)
    echo "
--- TESTS PERFORMANCES DISQUE (LECTURE/ÉCRITURE) ---"
    local root_rw_speeds=$(measure_disk_speed "/")
    local root_read_speed=$(echo "$root_rw_speeds" | awk '{print $1}')
    local root_write_speed=$(echo "$root_rw_speeds" | awk '{print $2}')
    echo "  Disque principal (/): Lecture: ${root_read_speed} MB/s, Écriture: ${root_write_speed} MB/s"

    local nc_rw_speeds="0 0"
    if [[ -d "/nextcloud-data" ]]; then
        nc_rw_speeds=$(measure_disk_speed "/nextcloud-data")
        local nc_read_speed=$(echo "$nc_rw_speeds" | awk '{print $1}')
        local nc_write_speed=$(echo "$nc_rw_speeds" | awk '{print $2}')
        echo "  Données NextCloud (/nextcloud-data): Lecture: ${nc_read_speed} MB/s, Écriture: ${nc_write_speed} MB/s"
    else
        echo "  Données NextCloud (/nextcloud-data): Non monté ou non trouvé, tests ignorés."
    fi
    
    # Résumé des capacités ♥️BOX
    echo "
--- RÉSUMÉ CAPACITÉS ♥️BOX ---"
    echo "Type de node: $(if [[ -f ~/.zen/game/secret.dunikey ]]; then echo "Y Level (Node autonome)"; else echo "Standard (avec Capitaine)"; fi)"
    echo "Espace total: $disk_total"
    echo "Services actifs:"
    echo "  - IPFS: $(if pgrep ipfs >/dev/null; then echo "✅ Actif ($ipfs_size)"; else echo "❌ Inactif"; fi)"
    echo "  - NextCloud: $(if docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | grep -q nextcloud; then echo "✅ Actif"; else echo "❌ Inactif"; fi)"
    echo "  - Astroport: $(if pgrep -f "12345" >/dev/null; then echo "✅ Actif"; else echo "❌ Inactif"; fi)"
    echo "Potentiel d'abonnements: $zencard_parts ZenCards + $nostr_parts NOSTR Cards"
}

#######################################################################
# Analyse du stockage IPFS
#######################################################################
analyze_ipfs_storage() {
    echo "
--- STOCKAGE IPFS ---"
    if [[ -d ~/.ipfs ]]; then
        local ipfs_size=$(du -sh ~/.ipfs 2>/dev/null | cut -f1)
        echo "Taille ~/.ipfs: $ipfs_size"
        
        # Analyse de la configuration IPFS
        if [[ -f ~/.ipfs/config ]]; then
            echo "Configuration IPFS:"
            
            # Seuils de Garbage Collection
            local storage_max=$(jq -r '.Datastore.StorageMax // "10GB"' ~/.ipfs/config 2>/dev/null)
            local storage_gc_watermark=$(jq -r '.Datastore.StorageGCWatermark // 90' ~/.ipfs/config 2>/dev/null)
            local gc_period=$(jq -r '.Datastore.GCPeriod // "1h"' ~/.ipfs/config 2>/dev/null)
            
            echo "  StorageMax: $storage_max"
            echo "  GC Watermark: ${storage_gc_watermark}%"
            echo "  GC Period: $gc_period"
            
            # Calcul de proximité avec GC
            if [[ "$storage_max" =~ ([0-9]+)GB ]]; then
                local max_gb=${BASH_REMATCH[1]}
                local ipfs_gb=$(echo "$ipfs_size" | sed 's/G//' | sed 's/M/\/1024/' | bc 2>/dev/null || echo "0")
                local gc_threshold_gb=$(echo "$max_gb * $storage_gc_watermark / 100" | bc 2>/dev/null || echo "0")
                local gc_proximity_percent=$(echo "scale=1; $ipfs_gb * 100 / $gc_threshold_gb" | bc 2>/dev/null || echo "0")
                
                echo "  Proximité GC: ${gc_proximity_percent}% du seuil (${gc_threshold_gb}GB)"
                
                # Alerte si proche du GC
                if [[ $(echo "$gc_proximity_percent > 80" | bc 2>/dev/null) -eq 1 ]]; then
                    echo "  ⚠️  ALERTE: Proche du seuil de Garbage Collection!"
                fi
            fi
            
            # Swarm settings
            local swarm_peers=$(jq -r '.Swarm.ConnMgr.HighWater // 900' ~/.ipfs/config 2>/dev/null)
            echo "  Max peers Swarm: $swarm_peers"
        fi
        
        # Statistiques IPFS en direct si possible
        if command -v ipfs >/dev/null 2>&1 && pgrep ipfs >/dev/null; then
            local ipfs_stats=$(ipfs stats bw --interval 1s 2>/dev/null | head -1 || echo "Non disponible")
            echo "  Bande passante: $ipfs_stats"
            
            local ipfs_peers=$(ipfs swarm peers 2>/dev/null | wc -l || echo "0")
            echo "  Peers connectés: $ipfs_peers"
        fi
    else
        echo "Répertoire ~/.ipfs non trouvé"
    fi
}

#######################################################################
# Analyse NextCloud Docker
#######################################################################
analyze_nextcloud_docker() {
    echo "
--- NEXTCLOUD (CLOUD PERSONNEL) ---"
    
    # Vérifier si NextCloud est configuré via Docker
    local nextcloud_compose="$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/docker-compose.yml"
    if [[ -f "$nextcloud_compose" ]]; then
        echo "Configuration NextCloud détectée: $nextcloud_compose"
        
        # Vérifier les ports NextCloud spécifiques
        echo "
Vérification des ports NextCloud:"
        
        # Port 8002 - AIO Interface (HTTPS)
        if netstat -tln 2>/dev/null | grep -q ":8002 "; then
            echo "  ✅ Port 8002 (AIO HTTPS): OUVERT"
        else
            echo "  ❌ Port 8002 (AIO HTTPS): FERMÉ"
        fi
        
        # Port 8001 - Cloud Interface (HTTP)
        if netstat -tln 2>/dev/null | grep -q ":8001 "; then
            echo "  ✅ Port 8001 (Cloud HTTP): OUVERT"
        else
            echo "  ❌ Port 8001 (Cloud HTTP): FERMÉ"
        fi
        
        # Ports additionnels du docker-compose
        local additional_ports=("8008" "8443")
        for port in "${additional_ports[@]}"; do
            if netstat -tln 2>/dev/null | grep -q ":$port "; then
                echo "  ✅ Port $port: OUVERT"
            else
                echo "  ❌ Port $port: FERMÉ"
            fi
        done
        
        # Vérifier si les conteneurs NextCloud sont actifs
        if command -v docker >/dev/null 2>&1; then
            local nc_containers=$(docker ps --filter "name=nextcloud" --format "{{.Names}} ({{.Status}})" 2>/dev/null)
            if [[ -n "$nc_containers" ]]; then
                echo "
Conteneurs NextCloud actifs:"
                echo "$nc_containers"
            else
                echo "
❌ Aucun conteneur NextCloud actif"
            fi
            
            # Analyser le volume de données NextCloud
            local nc_datadir="/nextcloud-data"
            if [[ -d "$nc_datadir" ]]; then
                local nc_size=$(du -sh "$nc_datadir" 2>/dev/null | cut -f1)
                local nc_files=$(find "$nc_datadir" -type f 2>/dev/null | wc -l)
                echo "
Données NextCloud ($nc_datadir):"
                echo "  Taille: $nc_size"
                echo "  Fichiers: $nc_files"
                
                # Vérifier les logs récents
                local nc_log_dir="$nc_datadir/nextcloud.log"
                if [[ -f "$nc_log_dir" ]]; then
                    local nc_log_size=$(du -sh "$nc_log_dir" 2>/dev/null | cut -f1)
                    echo "  Log: $nc_log_size"
                fi
            else
                echo "Répertoire de données NextCloud non trouvé: $nc_datadir"
            fi
        else
            echo "Docker non disponible pour vérifier NextCloud"
        fi
    else
        echo "NextCloud non configuré (docker-compose.yml absent)"
    fi
}

#######################################################################
# Fonction pour analyse complète à la demande
#######################################################################
run_complete_analysis() {
    local output_file="${1:-/tmp/heartbox_analysis_$(date +%Y%m%d_%H%M%S).log}"
    
    echo "🔍 Lancement de l'analyse complète de la ♥️box..."
    echo "📊 Résultats sauvegardés dans: $output_file"
    
    {
        echo "ANALYSE COMPLÈTE ♥️BOX - $(date)"
        echo "========================================"
        analyze_system_caches
        analyze_heartbox_hardware
    } > "$output_file"
    
    echo "✅ Analyse terminée: $output_file"
}

#######################################################################
# Interface en ligne de commande
#######################################################################
case "${1:-save}" in
    "save")
        save_logs_to_archive "${2:-MANUAL}"
        ;;
    "caches")
        analyze_system_caches
        ;;
    "hardware") 
        analyze_heartbox_hardware
        ;;
    "complete")
        run_complete_analysis "$2"
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
        echo "Usage: $0 [save|caches|hardware|complete|export|--help] [params...]"
        echo ""
        echo "Commandes:"
        echo "  save [phase]         - Sauvegarde logs avec analyse (défaut)"
        echo "  caches              - Analyse des caches uniquement"
        echo "  hardware            - Analyse matérielle uniquement"
        echo "  complete [file]     - Analyse complète vers fichier"
        echo "  export --json       - Export JSON de toutes les données"
        echo "  --help              - Affiche l'aide complète"
        echo ""
        echo "Pour plus d'informations: $0 --help"
        ;;
esac 