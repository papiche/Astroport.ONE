#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.1 - Optimized for speed, Prometheus & Dify.ai integration
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
    
    # UPassport API - fast port check
    local upassport_active="false"
    if ss -tln 2>/dev/null | grep -q ":54321 "; then
        upassport_active="true"
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
    
    # NOSTR relay — strfry ou rnostr (même port 7777)
    local strfry_active="false"
    local strfry_engine="strfry"
    local strfry_db_size="0"
    if ss -tln 2>/dev/null | grep -q ":7777 "; then
        strfry_active="true"
        ## Détecter si c'est rnostr (profil dev) ou strfry
        pgrep rnostr >/dev/null 2>&1 && strfry_engine="rnostr"
    fi
    if [[ -f "$HOME/.zen/strfry/strfry-db/data.mdb" ]]; then
        strfry_db_size=$(stat -c%s "$HOME/.zen/strfry/strfry-db/data.mdb" 2>/dev/null || echo "0")
    fi

    # G1Billet - fast process check
    local g1billet_active="false"
    if pgrep -f "G1BILLETS" >/dev/null 2>&1; then
        g1billet_active="true"
    fi

    # Prometheus node_exporter - metrics endpoint :9100
    local node_exporter_active="false"
    if ss -tln 2>/dev/null | grep -q ":9100 "; then
        node_exporter_active="true"
    elif systemctl is-active --quiet prometheus-node-exporter 2>/dev/null || \
         systemctl is-active --quiet node_exporter 2>/dev/null; then
        node_exporter_active="true"
    fi

    # Nginx Proxy Manager - Docker or port check
    local npm_active="false"
    local npm_ssl="false"
    if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Image}}' 2>/dev/null | grep -q 'nginx-proxy-manager'; then
        npm_active="true"
    elif ss -tln 2>/dev/null | grep -q ":81 "; then
        npm_active="true"
    fi
    if ss -tln 2>/dev/null | grep -q ":443 "; then
        npm_ssl="true"
    fi

    ## NextCloud AIO ports :
    ## 8443 = AIO admin setup (HTTPS, première config) ← PORT CORRECT
    ## 8002 = AIO dashboard (HTTP, post-setup)
    ## 8001 = Apache NextCloud app (proxied par NPM → cloud.DOMAIN)
    local nextcloud_aio_admin="false"   # port 8443 (setup initial)
    local nextcloud_aio_dash="false"    # port 8002 (dashboard)
    local nextcloud_cloud_active="false" # port 8001 (app Apache)
    ss -tln 2>/dev/null | grep -q ":8443 " && nextcloud_aio_admin="true"
    ss -tln 2>/dev/null | grep -q ":8002 " && nextcloud_aio_dash="true"
    ss -tln 2>/dev/null | grep -q ":8001 " && nextcloud_cloud_active="true"

    ## ── Helpers source-detection ─────────────────────────────────────────────
    ## Distingue un service LOCAL d'un port ouvert par tunnel SSH ou IPFS P2P.
    ## Protocole IPFS P2P : /x/${svc,,}-${node_id}  (cf. tunnel.sh:85)
    ## SSH tunnel          : processus 'ssh' écoute sur le port  (cf. ollama.me.sh:238)

    ## Retourne vrai si le port est écouté par un processus 'ssh' (tunnel SSH local).
    ## Utilise ss -tlnp (pas de dépendance lsof) — visible pour les processus de l'utilisateur courant.
    ## Format ss : ... users:(("ssh",pid=N,fd=M))
    _port_via_ssh() {
        local port="$1"
        ss -tlnp 2>/dev/null | grep ":${port} " | grep -q '"ssh"'
    }

    ## Snapshot unique ipfs p2p ls (évite N appels ipfs successifs)
    local _p2p_ls
    _p2p_ls=$(ipfs p2p ls 2>/dev/null || true)

    ## ── Profil ai-company : Stack IA Swarm ───────────────────────────────────
    ## Pour chaque service IA : déterminer la SOURCE (local / p2p_tunnel / ssh_tunnel / none)
    ## IMPORTANT : power_score et provider_ready n'utilisent que les services LOCAUX.

    ## ── Ollama (port 11434) ───────────────────────────────────────────────────
    local ollama_active="false"
    local ollama_source="none"

    if pgrep -x "ollama" >/dev/null 2>&1 || \
       pgrep -f "ollama serve" >/dev/null 2>&1 || \
       systemctl is-active --quiet ollama 2>/dev/null || \
       { command -v docker >/dev/null 2>&1 && \
         docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'ollama'; }; then
        ollama_active="true"; ollama_source="local"
    elif echo "$_p2p_ls" | grep -qi "/x/ollama"; then
        ollama_active="true"; ollama_source="p2p_tunnel"
    elif _port_via_ssh 11434; then
        ollama_active="true"; ollama_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":11434 "; then
        ollama_active="true"; ollama_source="unknown"
    fi

    ## Modèles Ollama : seulement si service LOCAL (ce sont NOS modèles à offrir au swarm)
    local ollama_models="[]"
    if [[ "$ollama_source" == "local" ]] && command -v ollama >/dev/null 2>&1; then
        ollama_models=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | \
            jq -R . | jq -s . 2>/dev/null || echo "[]")
    fi

    ## ── Qdrant (port 6333) ────────────────────────────────────────────────────
    local qdrant_active="false"
    local qdrant_source="none"

    if { command -v docker >/dev/null 2>&1 && \
         docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'qdrant'; } || \
       pgrep -f "qdrant" >/dev/null 2>&1; then
        qdrant_active="true"; qdrant_source="local"
    elif echo "$_p2p_ls" | grep -qi "/x/qdrant"; then
        qdrant_active="true"; qdrant_source="p2p_tunnel"
    elif _port_via_ssh 6333; then
        qdrant_active="true"; qdrant_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":6333 "; then
        qdrant_active="true"; qdrant_source="unknown"
    fi

    ## ── Dify.ai (port 8010) ───────────────────────────────────────────────────
    local dify_active="false"
    local dify_source="none"

    ## Dify utilise son propre docker-compose (dify/docker/) → containers : docker-api-1, docker-nginx-1
    ## Détection fiable : image langgenius/dify ou nom contenant "dify"
    if command -v docker >/dev/null 2>&1 && \
       docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -qi 'dify'; then
        dify_active="true"; dify_source="local"
    elif echo "$_p2p_ls" | grep -qi "/x/dify"; then
        dify_active="true"; dify_source="p2p_tunnel"
    elif _port_via_ssh 8010; then
        dify_active="true"; dify_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":8010 "; then
        dify_active="true"; dify_source="unknown"
    fi

    ## ── Open WebUI (port 8000) ────────────────────────────────────────────────
    local open_webui_active="false"
    local open_webui_source="none"

    if { command -v docker >/dev/null 2>&1 && \
         docker ps --format '{{.Names}}' 2>/dev/null | grep -qE 'ai-company-webui|open-webui'; } || \
       pgrep -f "open.webui" >/dev/null 2>&1 || \
       pgrep -f "open_webui" >/dev/null 2>&1; then
        open_webui_active="true"; open_webui_source="local"
    elif echo "$_p2p_ls" | grep -qiE "/x/open.webui|/x/webui"; then
        open_webui_active="true"; open_webui_source="p2p_tunnel"
    elif _port_via_ssh 8000; then
        open_webui_active="true"; open_webui_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":8000 "; then
        open_webui_active="true"; open_webui_source="unknown"
    fi

    ## ── MiroFish (port 5050) — Agent IA communautaire, nourri par feed_mirofish.sh ──
    local mirofish_active="false"
    local mirofish_source="none"

    if command -v docker >/dev/null 2>&1 && \
       docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'mirofish'; then
        mirofish_active="true"; mirofish_source="local"
    elif echo "$_p2p_ls" | grep -qi "/x/mirofish"; then
        mirofish_active="true"; mirofish_source="p2p_tunnel"
    elif _port_via_ssh 5050; then
        mirofish_active="true"; mirofish_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":5050 "; then
        mirofish_active="true"; mirofish_source="unknown"
    fi

    ## ── ComfyUI (port 8188) — Génération d'images ─────────────────────────────
    local comfyui_active="false"
    local comfyui_source="none"

    if pgrep -f "comfyui" >/dev/null 2>&1 || \
       pgrep -f "main\.py.*--listen" >/dev/null 2>&1 || \
       systemctl is-active --quiet comfyui 2>/dev/null || \
       { command -v docker >/dev/null 2>&1 && \
         docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'comfyui'; }; then
        comfyui_active="true"; comfyui_source="local"
    elif echo "$_p2p_ls" | grep -qi "/x/comfyui"; then
        comfyui_active="true"; comfyui_source="p2p_tunnel"
    elif _port_via_ssh 8188; then
        comfyui_active="true"; comfyui_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":8188 "; then
        comfyui_active="true"; comfyui_source="unknown"
    fi

    ## ── Orpheus TTS (port 5005) — Synthèse vocale ─────────────────────────────
    local orpheus_active="false"
    local orpheus_source="none"

    if command -v docker >/dev/null 2>&1 && \
       docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'orpheus'; then
        orpheus_active="true"; orpheus_source="local"
    elif echo "$_p2p_ls" | grep -qi "/x/orpheus"; then
        orpheus_active="true"; orpheus_source="p2p_tunnel"
    elif _port_via_ssh 5005; then
        orpheus_active="true"; orpheus_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":5005 "; then
        orpheus_active="true"; orpheus_source="unknown"
    fi

    ## ── Vane (port 3002) — Moteur de recherche IA (ex-Perplexica) ───────────
    local vane_active="false"
    local vane_source="none"

    if pgrep -f "vane" >/dev/null 2>&1 || \
       pgrep -f "perplexica" >/dev/null 2>&1 || \
       systemctl is-active --quiet vane 2>/dev/null || \
       { command -v docker >/dev/null 2>&1 && \
         docker ps --format '{{.Names}}' 2>/dev/null | grep -qE 'vane|perplexica'; }; then
        vane_active="true"; vane_source="local"
    elif echo "$_p2p_ls" | grep -qiE "/x/vane|/x/perplexica"; then
        vane_active="true"; vane_source="p2p_tunnel"
    elif _port_via_ssh 3002; then
        vane_active="true"; vane_source="ssh_tunnel"
    elif ss -tln 2>/dev/null | grep -q ":3002 "; then
        vane_active="true"; vane_source="unknown"
    fi

    ## ── Webtop KasmVNC (VDI) ──────────────────────────────────────────
    local webtop_active="false"
    command -v docker >/dev/null 2>&1 && \
        docker ps --format '{{.Image}}' 2>/dev/null | grep -q 'linuxserver/webtop' && webtop_active="true"
        
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
    "upassport": {
        "active": $upassport_active,
        "port": 54321
    },
    "nextcloud": {
        "active": $nextcloud_active,
        "container": "$nextcloud_container",
        "aio_admin": {
            "active": $nextcloud_aio_admin,
            "port": 8443,
            "note": "AIO admin setup (HTTPS, premiere config)"
        },
        "aio_dashboard": {
            "active": $nextcloud_aio_dash,
            "port": 8002,
            "note": "AIO dashboard (HTTP, post-setup)"
        },
        "cloud_apache": {
            "active": $nextcloud_cloud_active,
            "port": 8001,
            "note": "Apache NextCloud app (proxied par NPM cloud.DOMAIN)"
        }
    },
    "nostr_relay": {
        "active": $strfry_active,
        "engine": "$strfry_engine",
        "port": 7777,
        "db_size_bytes": $strfry_db_size
    },
    "npm": {
        "active": $npm_active,
        "ssl": $npm_ssl,
        "admin_port": 81
    },
    "g1billet": {
        "active": $g1billet_active
    },
    "node_exporter": {
        "active": $node_exporter_active,
        "port": 9100
    },
    "ai_company": {
        "ollama":     { "active": $ollama_active,     "source": "$ollama_source",     "port": 11434, "models": $ollama_models },
        "qdrant":     { "active": $qdrant_active,     "source": "$qdrant_source",     "port": 6333  },
        "dify":       { "active": $dify_active,       "source": "$dify_source",       "port": 8010  },
        "open_webui": { "active": $open_webui_active, "source": "$open_webui_source", "port": 8000  },
        "mirofish":   { "active": $mirofish_active,   "source": "$mirofish_source",   "port": 5050  },
        "comfyui":    { "active": $comfyui_active,    "source": "$comfyui_source",    "port": 8188  },
        "orpheus":    { "active": $orpheus_active,    "source": "$orpheus_source",    "port": 5005  },
        "vane":       { "active": $vane_active,       "source": "$vane_source",       "port": 3002  }
    },
    "webtop": {
        "active": $webtop_active,
        "port_http": 3000,
        "port_https": 3001
    },
    "ipfs_p2p_services": $p2p_services
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
    
    # NextCloud / BTRFS disk space
    local nextcloud_fs="unknown"
    if [[ -d "/nextcloud-data" ]] && df -h /nextcloud-data | tail -1 | grep -q .; then
        local nextcloud_available=$(df -h /nextcloud-data | tail -1 | awk '{print $4}')
        nextcloud_available_gb=$(echo "$nextcloud_available" | sed 's/G//' | sed 's/T/*1024/' | sed 's/,/\./' | bc 2>/dev/null || echo "0")
        ## Détecter le filesystem BTRFS (recommandé pour NextCloud + IPFS)
        nextcloud_fs=$(findmnt -no FSTYPE /nextcloud-data 2>/dev/null || stat -f -c %T /nextcloud-data 2>/dev/null || echo "unknown")
    fi
    
    # Calculate total available space — déduplique root et ipfs s'ils partagent le même device
    local _root_dev _ipfs_dev
    _root_dev=$(df / 2>/dev/null | tail -1 | awk '{print $1}')
    _ipfs_dev=$(df ~/.ipfs 2>/dev/null | tail -1 | awk '{print $1}')
    local total_available_gb
    if [[ "$_root_dev" == "$_ipfs_dev" ]]; then
        total_available_gb=$(echo "$root_available_gb + $nextcloud_available_gb" | bc 2>/dev/null || echo "$root_available_gb")
    else
        total_available_gb=$(echo "$root_available_gb + $ipfs_available_gb + $nextcloud_available_gb" | bc 2>/dev/null || echo "0")
    fi
    
    # Calculate slots (simplified calculation)
    local zencard_slots=0
    local nostr_slots=0

    if [[ $(echo "$nextcloud_available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        zencard_slots=$(echo "($nextcloud_available_gb) / 128" | bc 2>/dev/null || echo "0")
        [[ $(echo "$zencard_slots < 0" | bc 2>/dev/null) -eq 1 ]] && zencard_slots=0
    fi

    if [[ $(echo "$ipfs_available_gb > 0" | bc 2>/dev/null) -eq 1 ]]; then
        nostr_slots=$(echo "($ipfs_available_gb) / 10" | bc 2>/dev/null || echo "0")
        [[ $(echo "$nostr_slots < 0" | bc 2>/dev/null) -eq 1 ]] && nostr_slots=0
    fi

    ## ── Power-Score : GPS de calcul (GPU×4 + CPU×2 + RAM×0.5) ──────────────
    ## Tiers : 0-10 = Light (RPi) | 11-40 = Standard (PC) | 41+ = Brain-Node (GPU)
    ## IMPORTANT : calcul basé sur les ressources PHYSIQUES locales uniquement.
    local cpu_cores
    cpu_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo 1)
    local ram_total_gb
    ram_total_gb=$(awk '/MemTotal/ {printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0)
    local vram_gb=0
    local gpu_detected="false"
    if command -v nvidia-smi >/dev/null 2>&1; then
        local raw_vram
        raw_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
            | awk '{sum+=$1} END {printf "%.0f", sum/1024}')
        if [[ -n "$raw_vram" && "$raw_vram" -gt 0 ]]; then
            vram_gb=$raw_vram
            gpu_detected="true"
        fi
    fi
    local power_score
    power_score=$(echo "($vram_gb * 4) + ($cpu_cores * 2) + ($ram_total_gb / 2)" | bc 2>/dev/null) \
        || power_score=$(( vram_gb * 4 + cpu_cores * 2 + ram_total_gb / 2 ))
    [[ -z "$power_score" ]] && power_score=0

    ## ── crypto_score : vitesse scrypt via keygen -t duniter (RAM-hard) ──────────
    ## Cohérent avec test/BENCH_REFERENCE.md et picoport_bench.json de sound-spot.
    ## Priorité : picoport_bench.json (bench complet) > crypto_score.cache (bench rapide)
    ## TTL 24h — le keygen duniter prend 150 ms … 6 s selon l'architecture.
    local crypto_score=0
    local crypto_ms=0
    local _PICO_BENCH="$HOME/.zen/tmp/${IPFSNODEID}/picoport_bench.json"
    local _CRYPTO_CACHE="$HOME/.zen/tmp/${IPFSNODEID}/crypto_score.cache"
    local _cache_age_limit=86400  # 24 h

    if [[ -s "$_PICO_BENCH" ]] && \
       [[ $(( $(date +%s) - $(stat -c %Y "$_PICO_BENCH" 2>/dev/null || echo 0) )) -lt $_cache_age_limit ]]; then
        crypto_score=$(jq -r '.crypto_score // 0' "$_PICO_BENCH" 2>/dev/null || echo 0)
        crypto_ms=$(jq -r '.timings_ms.keygen_duniter // 0' "$_PICO_BENCH" 2>/dev/null || echo 0)
    elif [[ -s "$_CRYPTO_CACHE" ]] && \
         [[ $(( $(date +%s) - $(stat -c %Y "$_CRYPTO_CACHE" 2>/dev/null || echo 0) )) -lt $_cache_age_limit ]]; then
        read crypto_score crypto_ms < "$_CRYPTO_CACHE" 2>/dev/null
        crypto_score="${crypto_score:-0}"; crypto_ms="${crypto_ms:-0}"
    else
        local _keygen=""
        for _k in "$MY_PATH/keygen" "$HOME/.zen/Astroport.ONE/tools/keygen" \
                  "$HOME/.local/bin/keygen" "$(command -v keygen 2>/dev/null)"; do
            [[ -x "$_k" ]] && _keygen="$_k" && break
        done
        if [[ -n "$_keygen" ]]; then
            local _t0 _t1
            _t0=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null \
                  || echo $(( $(date +%s) * 1000 )))
            "$_keygen" -t duniter "heartbox.bench" "heartbox.bench" >/dev/null 2>&1
            _t1=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null \
                  || echo $(( $(date +%s) * 1000 )))
            crypto_ms=$(( _t1 - _t0 ))
            if   (( crypto_ms < 150  )); then crypto_score=10
            elif (( crypto_ms < 300  )); then crypto_score=8
            elif (( crypto_ms < 600  )); then crypto_score=6
            elif (( crypto_ms < 1200 )); then crypto_score=4
            elif (( crypto_ms < 2500 )); then crypto_score=2
            else                              crypto_score=1
            fi
            echo "$crypto_score $crypto_ms" > "$_CRYPTO_CACHE"
        fi
    fi

    ## provider_ready = vrai uniquement si des services IA LOCAUX tournent (pas des tunnels).
    ## Re-détection indépendante : get_fast_capacities() tourne dans un subshell séparé,
    ## les variables *_source de get_fast_service_status() ne sont pas accessibles ici.
    local has_local_ai="false"
    { pgrep -x "ollama" >/dev/null 2>&1 || \
      pgrep -f "ollama serve" >/dev/null 2>&1 || \
      systemctl is-active --quiet ollama 2>/dev/null || \
      { command -v docker >/dev/null 2>&1 && \
        docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -qiE 'ollama|qdrant|dify|open-webui|mirofish|comfyui|orpheus|vane|perplexica'; } || \
      pgrep -f "comfyui\|open.webui\|open_webui\|perplexica\|vane" >/dev/null 2>&1; \
    } && has_local_ai="true"
    local provider_ready="false"
    ## Score élevé (GPU dédié) : toujours provider, même sans service IA actif
    [[ ${power_score} -gt 40 ]] && provider_ready="true"
    ## Score standard + service IA local : peut aussi offrir ses ressources
    [[ ${power_score} -gt 10 && "$has_local_ai" == "true" ]] && provider_ready="true"

    ## storage_ready = vrai si le nœud peut héberger des données pour la constellation
    ## Seuil : ≥1 slot ZenCard (≥128 Go NextCloud) OU ≥10 slots NOSTR (≥100 Go IPFS)
    local storage_ready="false"
    [[ ${zencard_slots} -ge 1 || ${nostr_slots} -ge 10 ]] && storage_ready="true"

    cat << EOF
    "zencard_slots": $zencard_slots,
    "nostr_slots": $nostr_slots,
    "reserved_captain_slots": 8,
    "available_space_gb": $total_available_gb,
    "power_score": $power_score,
    "crypto_score": $crypto_score,
    "crypto_ms": $crypto_ms,
    "provider_ready": $provider_ready,
    "storage_ready": $storage_ready,
    "gpu": {
        "detected": $gpu_detected,
        "vram_gb": $vram_gb
    },
    "storage_details": {
        "nextcloud": {
            "available_gb": $nextcloud_available_gb,
            "mount_point": "/nextcloud-data",
            "filesystem": "$nextcloud_fs",
            "btrfs_recommended": $([ "$nextcloud_fs" = "btrfs" ] && echo "true" || echo "false"),
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
    
    # Get CPU info — RPi/ARM : "model name" absent, fallback device-tree → Model → lscpu
    local cpu_model=""
    if [[ -r /proc/device-tree/model ]]; then
        cpu_model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
    fi
    if [[ -z "$cpu_model" ]]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null)
    fi
    if [[ -z "$cpu_model" ]]; then
        cpu_model=$(grep -m1 "^Model" /proc/cpuinfo | cut -d':' -f2 | xargs 2>/dev/null)
    fi
    if [[ -z "$cpu_model" ]]; then
        cpu_model=$(lscpu 2>/dev/null | awk -F': +' '/Model name/{print $2; exit}')
    fi
    [[ -z "$cpu_model" ]] && cpu_model="Unknown"
    
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null)
    [[ -z "$cpu_cores" || "$cpu_cores" -eq 0 ]] && cpu_cores=1
    
    # CPU frequency — /sys/cpufreq fiable sur ARM et x86, fallbacks : /proc puis vcgencmd
    local cpu_freq=0
    local _khz
    _khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    if [[ -n "$_khz" && "$_khz" -gt 0 ]]; then
        cpu_freq=$(( _khz / 1000 ))
    else
        local _mhz
        _mhz=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null | cut -d'.' -f1)
        [[ -n "$_mhz" && "$_mhz" -gt 0 ]] && cpu_freq=$_mhz
    fi
    if [[ "$cpu_freq" -eq 0 ]] && command -v vcgencmd >/dev/null 2>&1; then
        local _hz
        _hz=$(vcgencmd measure_clock arm 2>/dev/null | cut -d'=' -f2)
        [[ -n "$_hz" && "$_hz" -gt 0 ]] && cpu_freq=$(( _hz / 1000000 ))
    fi
    
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | xargs | cut -d',' -f1)
    [[ -z "$load_avg" ]] && load_avg="0.00"

    local cpu_temp
    cpu_temp=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 | cut -d"'" -f1)
    [[ -z "$cpu_temp" ]] && cpu_temp=0

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
            "model": "$cpu_model",
            "cores": $cpu_cores,
            "frequency_mhz": $cpu_freq,
            "load_average": "$load_avg"
        },
        "memory": {
            "total_gb": $(awk '/MemTotal/{printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0),
            "used_gb": $(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.1f", (t-a)/1048576}' /proc/meminfo 2>/dev/null || echo 0),
            "usage_percent": $(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.0f", (t-a)*100/t}' /proc/meminfo 2>/dev/null || echo 0)
        },
        "storage": {
            "total": "$(df -h / | tail -1 | awk '{print $2}')",
            "used": "$(df -h / | tail -1 | awk '{print $3}')",
            "available": "$(df -h / | tail -1 | awk '{print $4}')",
            "usage_percent": "$(df -h / | tail -1 | awk '{print $5}')"
        },
        "cpu_temp": $cpu_temp,
        "gpu": $(if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d '\n' | sed 's/"/\\"/g' | sed 's/^/"/; s/$/"/'; else echo "null"; fi)
    },
    "caches": {
        "swarm": $(if [[ -d ~/.zen/tmp/swarm ]]; then echo "{\"size\": \"$(du -sh ~/.zen/tmp/swarm 2>/dev/null | cut -f1)\", \"nodes_count\": $(find ~/.zen/tmp/swarm -maxdepth 1 -type d -name "12D*" | wc -l), \"files_count\": $(find ~/.zen/tmp/swarm -type f | wc -l), \"status\": \"active\"}"; else echo "{\"status\": \"not_found\"}"; fi),
        "coucou": $(if [[ -d ~/.zen/tmp/coucou ]]; then echo "{\"size\": \"$(du -sh ~/.zen/tmp/coucou 2>/dev/null | cut -f1)\", \"total_files\": $(find ~/.zen/tmp/coucou -type f | wc -l), \"coins_files\": $(find ~/.zen/tmp/coucou -name "*.COINS" | wc -l), \"gchange_profiles\": $(find ~/.zen/tmp/coucou -name "*.gchange.json" | wc -l), \"cesium_profiles\": $(find ~/.zen/tmp/coucou -name "*.cesium.json" | wc -l), \"avatars\": $(find ~/.zen/tmp/coucou -name "*.avatar.png" | wc -l), \"status\": \"active\"}"; else echo "{\"status\": \"not_found\"}"; fi),
        "flashmem": $(if [[ -d ~/.zen/flashmem ]]; then echo "{\"size\": \"$(du -sh ~/.zen/flashmem 2>/dev/null | cut -f1)\", \"geokeys_count\": $(find ~/.zen/flashmem -maxdepth 1 -type d -name "k*" | wc -l), \"tiddlywikis_count\": $(find ~/.zen/flashmem -path "*/TWz/*" -type f | wc -l), \"uplanet_dirs\": $(find ~/.zen/flashmem -name "UPLANET" -type d | wc -l), \"status\": \"active\"}"; else echo "{\"status\": \"not_found\"}"; fi),
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
        echo "Usage: $0[export|update|cache] [--json]"
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