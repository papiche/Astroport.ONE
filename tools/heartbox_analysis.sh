#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0 - Optimized for speed and Prometheus integration
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# HEARTBOX ANALYSIS - Optimized analysis of the ♥️box UPlanet
# Fast service detection and Prometheus integration for system metrics
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Cache file for fast access
CACHE_FILE="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"
CACHE_TTL=300  # 5 minutes cache

#######################################################################
# Fast Prometheus metrics retrieval
#######################################################################
get_prometheus_metrics() {
    local prometheus_url="http://localhost:9090"
    local metrics=()
    
    # Try to get metrics from Prometheus if available
    if curl -s --max-time 2 "$prometheus_url/api/v1/query?query=up" >/dev/null 2>&1; then
        echo "📊 Using Prometheus metrics for system data" >&2
        
        # Get disk usage from Prometheus
        local disk_query="node_filesystem_avail_bytes{mountpoint=\"/\"}"
        local disk_available=$(curl -s --max-time 2 "$prometheus_url/api/v1/query?query=$disk_query" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
        if [[ "$disk_available" != "0" && "$disk_available" != "null" ]]; then
            local disk_available_gb=$(echo "scale=2; $disk_available / 1024 / 1024 / 1024" | bc 2>/dev/null)
            metrics+=("disk_available_gb:$disk_available_gb")
        fi
        
        # Get memory usage from Prometheus
        local mem_query="node_memory_MemAvailable_bytes"
        local mem_available=$(curl -s --max-time 2 "$prometheus_url/api/v1/query?query=$mem_query" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
        if [[ "$mem_available" != "0" && "$mem_available" != "null" ]]; then
            local mem_available_gb=$(echo "scale=2; $mem_available / 1024 / 1024 / 1024" | bc 2>/dev/null)
            metrics+=("mem_available_gb:$mem_available_gb")
        fi
        
        # Get CPU load from Prometheus
        local cpu_query="node_load1"
        local cpu_load=$(curl -s --max-time 2 "$prometheus_url/api/v1/query?query=$cpu_query" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
        if [[ "$cpu_load" != "0" && "$cpu_load" != "null" ]]; then
            metrics+=("cpu_load:$cpu_load")
        fi
    fi
    
    echo "${metrics[@]}"
}

#######################################################################
# Fast service status detection
#######################################################################
get_fast_service_status() {
    local services=()
    
    # IPFS - fast check
    local ipfs_active="false"
    local ipfs_peers="0"
    if pgrep ipfs >/dev/null 2>&1; then
        ipfs_active="true"
        # Fast peer count without timeout
        ipfs_peers=$(ipfs swarm peers 2>/dev/null | wc -l || echo "0")
    fi
    
    # Astroport - check 12345 process
    local astroport_active="false"
    if pgrep -f "12345" >/dev/null 2>&1; then
        astroport_active="true"
    fi
    
    # uSPOT - fast port check
    local uspot_active="false"
    if ss -tln 2>/dev/null | grep -q ":54321 "; then
        uspot_active="true"
    fi
    
    # NextCloud - fast Docker check
    local nextcloud_active="false"
    local nextcloud_container="null"
    if command -v docker >/dev/null 2>&1; then
        nextcloud_container=$(docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | head -1)
        if [[ -n "$nextcloud_container" ]]; then
            nextcloud_active="true"
        fi
    fi
    
    # NOSTR Relay - fast port check
    local nostr_relay_active="false"
    if ss -tln 2>/dev/null | grep -q ":7777 "; then
        nostr_relay_active="true"
    fi
    
    # G1Billet - fast process check
    local g1billet_active="false"
    if pgrep -f "G1BILLETS" >/dev/null 2>&1; then
        g1billet_active="true"
    fi
    
    # NextCloud ports
    local nextcloud_aio_active="false"
    local nextcloud_cloud_active="false"
    if ss -tln 2>/dev/null | grep -q ":8002 "; then
        nextcloud_aio_active="true"
    fi
    if ss -tln 2>/dev/null | grep -q ":8001 "; then
        nextcloud_cloud_active="true"
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
    
    cat << EOF
    "ipfs": {
        "active": $ipfs_active,
        "size": "$(du -sh ~/.ipfs 2>/dev/null | cut -f1 || echo "N/A")",
        "peers_connected": $ipfs_peers
    },
    "astroport": {
        "active": $astroport_active
    },
    "uspot": {
        "active": $uspot_active,
        "port": 54321
    },
    "nextcloud": {
        "active": $nextcloud_active,
        "container": "$nextcloud_container",
        "aio_https": {
            "active": $nextcloud_aio_active,
            "port": 8002
        },
        "cloud_http": {
            "active": $nextcloud_cloud_active,
            "port": 8001
        }
    },
    "nostr_relay": {
        "active": $nostr_relay_active,
        "port": 7777
    },
    "ipfs_p2p_services": $p2p_services,
    "g1billet": {
        "active": $g1billet_active
    }
EOF
}

#######################################################################
# Fast capacities calculation
#######################################################################
get_fast_capacities() {
    # Get disk space using df (faster than complex calculations)
    local root_available_gb=0
    local ipfs_available_gb=0
    local nextcloud_available_gb=0
    
    # Root disk space
    if df -h / | tail -1 | grep -q .; then
        local root_available=$(df -h / | tail -1 | awk '{print $4}')
        root_available_gb=$(echo "$root_available" | sed 's/G//' | sed 's/T/*1024/' | sed 's/,/\./' | bc 2>/dev/null || echo "0")
    fi
    
    # IPFS disk space
    if df -h ~/.ipfs | tail -1 | grep -q .; then
        local ipfs_available=$(df -h ~/.ipfs | tail -1 | awk '{print $4}')
        ipfs_available_gb=$(echo "$ipfs_available" | sed 's/G//' | sed 's/T/*1024/' | sed 's/,/\./' | bc 2>/dev/null || echo "0")
    fi
    
    # NextCloud disk space
    if [[ -d "/nextcloud-data" ]] && df -h /nextcloud-data | tail -1 | grep -q .; then
        local nextcloud_available=$(df -h /nextcloud-data | tail -1 | awk '{print $4}')
        nextcloud_available_gb=$(echo "$nextcloud_available" | sed 's/G//' | sed 's/T/*1024/' | sed 's/,/\./' | bc 2>/dev/null || echo "0")
    fi
    
    # Calculate total available space
    local total_available_gb=$(echo "$root_available_gb + $ipfs_available_gb + $nextcloud_available_gb" | bc 2>/dev/null || echo "0")
    
    # Calculate slots (simplified calculation)
    local zencard_slots=0
    local nostr_slots=0
    
    if [[ $(echo "$nextcloud_available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        zencard_slots=$(echo "($nextcloud_available_gb - 8*128) / 128" | bc 2>/dev/null || echo "0")
        [[ $(echo "$zencard_slots < 0" | bc 2>/dev/null) -eq 1 ]] && zencard_slots=0
    fi
    
    if [[ $(echo "$ipfs_available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        nostr_slots=$(echo "($ipfs_available_gb - 8*10) / 10" | bc 2>/dev/null || echo "0")
        [[ $(echo "$nostr_slots < 0" | bc 2>/dev/null) -eq 1 ]] && nostr_slots=0
    fi
    
    cat << EOF
    "zencard_slots": $zencard_slots,
    "nostr_slots": $nostr_slots,
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
# Fast JSON export with caching
#######################################################################
export_json() {
    local timestamp=$(date -Iseconds)
    local node_id="${IPFSNODEID:-unknown}"
    local captain=$(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo "unknown")
    local node_type="standard"
    local node_dir="$HOME/.zen/tmp/$node_id"
    
    # Determine node type
    if [[ -d "$node_dir" ]]; then
        if ls "$node_dir"/z_ssh* >/dev/null 2>&1; then
            node_type="z_level"
        elif ls "$node_dir"/y_ssh* >/dev/null 2>&1; then
            node_type="y_level"
        elif ls "$node_dir"/x_ssh* >/dev/null 2>&1; then
            node_type="x_level"
        fi
    fi

    local hostname=$(hostname -f)
    
    # Get Prometheus metrics if available
    local prometheus_metrics=$(get_prometheus_metrics)
    
    # Generate JSON
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
        "cpu": {
            "model": "$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "Unknown")",
            "cores": $(grep "processor" /proc/cpuinfo | wc -l 2>/dev/null || echo "0"),
            "frequency_mhz": $(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "0"),
            "load_average": "$(uptime | awk -F'load average:' '{ print $2 }' | xargs | cut -d',' -f1)"
        },
        "memory": {
            "total_gb": $(( $(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0") / 1024 / 1024 )),
            "used_gb": $(( ($(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0") - $(grep "MemAvailable" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")) / 1024 / 1024 )),
            "usage_percent": $(( ($(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0") - $(grep "MemAvailable" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")) * 100 / $(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "1") ))
        },
        "storage": {
            "total": "$(df -h / | tail -1 | awk '{print $2}')",
            "used": "$(df -h / | tail -1 | awk '{print $3}')",
            "available": "$(df -h / | tail -1 | awk '{print $4}')",
            "usage_percent": "$(df -h / | tail -1 | awk '{print $5}')"
        },
        "gpu": $(if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d '\n' | sed 's/"/\\"/g' | sed 's/^/"/; s/$/"/'; else echo "null"; fi)
    },
    "caches": {
        "swarm": $(if [[ -d ~/.zen/tmp/swarm ]]; then echo "{\"size\": \"$(du -sh ~/.zen/tmp/swarm 2>/dev/null | cut -f1)\", \"nodes_count\": $(find ~/.zen/tmp/swarm -maxdepth 1 -type d -name "12D*" | wc -l), \"files_count\": $(find ~/.zen/tmp/swarm -type f | wc -l), \"status\": \"active\"}"; else echo "{\"status\": \"not_found\"}"; fi),
        "coucou": $(if [[ -d ~/.zen/tmp/coucou ]]; then echo "{\"size\": \"$(du -sh ~/.zen/tmp/coucou 2>/dev/null | cut -f1)\", \"total_files\": $(find ~/.zen/tmp/coucou -type f | wc -l), \"coins_files\": $(find ~/.zen/tmp/coucou -name "*.COINS" | wc -l), \"gchange_profiles\": $(find ~/.zen/tmp/coucou -name "*.gchange.json" | wc -l), \"cesium_profiles\": $(find ~/.zen/tmp/coucou -name "*.cesium.json" | wc -l), \"avatars\": $(find ~/.zen/tmp/coucou -name "*.avatar.png" | wc -l), \"status\": \"active\"}"; else echo "{\"status\": \"not_found\"}"; fi),
        "flashmem": $(if [[ -d ~/.zen/tmp/flashmem ]]; then echo "{\"size\": \"$(du -sh ~/.zen/tmp/flashmem 2>/dev/null | cut -f1)\", \"geokeys_count\": $(find ~/.zen/tmp/flashmem -maxdepth 1 -type d -name "k*" | wc -l), \"tiddlywikis_count\": $(find ~/.zen/tmp/flashmem -path "*/TWz/*" -type f | wc -l), \"uplanet_dirs\": $(find ~/.zen/tmp/flashmem -name "UPLANET" -type d | wc -l), \"status\": \"active\"}"; else echo "{\"status\": \"not_found\"}"; fi),
        "global": {
            "total_size": "$(du -sh ~/.zen/tmp/ 2>/dev/null | cut -f1)",
            "total_files": $(find ~/.zen/tmp -type f | wc -l)
        }
    },
    "services": {
$(get_fast_service_status)
    },
    "capacities": {
$(get_fast_capacities)
    }
}
EOF
}

#######################################################################
# Cache management
#######################################################################
update_cache() {
    local cache_dir=$(dirname "$CACHE_FILE")
    mkdir -p "$cache_dir"
    
    # Generate fresh analysis
    local json_data=$(export_json)
    echo "$json_data" > "$CACHE_FILE"
    
    # Update 12345.json with fresh data
    if [[ -f "$HOME/.zen/tmp/${IPFSNODEID}/12345.json" ]]; then
        # Extract capacities and services from fresh analysis
        local capacities=$(echo "$json_data" | jq -r '.capacities' 2>/dev/null)
        local services=$(echo "$json_data" | jq -r '.services' 2>/dev/null)
        
        # Update existing 12345.json
        jq --argjson capacities "$capacities" --argjson services "$services" \
           '.capacities = $capacities | .services = $services' \
           "$HOME/.zen/tmp/${IPFSNODEID}/12345.json" > "$HOME/.zen/tmp/${IPFSNODEID}/12345.json.tmp" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            mv "$HOME/.zen/tmp/${IPFSNODEID}/12345.json.tmp" "$HOME/.zen/tmp/${IPFSNODEID}/12345.json"
        fi
    fi
    
    echo "✅ Cache updated: $CACHE_FILE"
}

#######################################################################
# Main execution
#######################################################################
case "${1:-export}" in
    "export")
        if [[ "$2" == "--json" ]]; then
            # Check if cache is fresh
            if [[ -f "$CACHE_FILE" ]]; then
                cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
                if [[ $cache_age -lt $CACHE_TTL ]]; then
                    echo "📊 Using cached analysis (age: ${cache_age}s)" >&2
                    cat "$CACHE_FILE"
                    exit 0
                fi
            fi
            
            # Generate fresh analysis
            echo "🔄 Generating fresh analysis..." >&2
            export_json
        else
            echo "Usage: $0 export --json"
            exit 1
        fi
        ;;
    "update")
        update_cache
        ;;
    "cache")
        if [[ -f "$CACHE_FILE" ]]; then
            cat "$CACHE_FILE"
        else
            echo "Cache not found. Run: $0 update"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 [export|update|cache] [--json]"
        echo ""
        echo "Commands:"
        echo "  export --json    - Export JSON analysis (uses cache if fresh)"
        echo "  update           - Update cache and 12345.json"
        echo "  cache            - Show cached analysis"
        echo ""
        echo "Cache TTL: ${CACHE_TTL}s"
        exit 1
        ;;
esac 