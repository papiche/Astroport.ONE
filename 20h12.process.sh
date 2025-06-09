#!/bin/bash
########################################################################
# Script 20H12 - Système de maintenance et gestion pour Astroport.ONE
#
# Description:
# Ce script effectue une série de tâches de maintenance pour un nœud Astroport.ONE,
# incluant la gestion des services IPFS, la mise à jour des composants logiciels,
# le rafraîchissement des données du réseau, et le monitoring du système.
#
# Fonctionnalités principales:
# - Vérification et gestion du démon IPFS
# - Mise à jour des dépôts Git (G1BILLET, UPassport, NIP-101, Astroport)
# - Maintenance du réseau P2P et des connexions SSH (DRAGON WOT)
# - Rafraîchissement des données UPlanet et Nostr
# - Gestion des services système via systemd
# - Journalisation et reporting par email
#
# Conçu pour s'exécuter régulièrement (par exemple via cron) avec des modes
# de fonctionnement différents selon l'environnement (LAN/public).
########################################################################
# Version: 1.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi

. "${MY_PATH}/tools/my.sh"
start=`date +%s`
echo "20H12 (♥‿‿♥) $(hostname -f) $(date)"
espeak "Ding" > /dev/null 2>&1

echo "PATH=$PATH"

#######################################################################
# Fonction pour sauvegarder les logs importants avant suppression
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
        "~/.zen/tmp/DRAGON.log"
        "~/.zen/tmp/BLOOM.log"
        "~/.zen/tmp/PLAYER.refresh.log"
        "~/.zen/tmp/UPLANET.refresh.log"
        "~/.zen/tmp/NODE.refresh.log"
        "~/.zen/tmp/NOSTRCARD.refresh.log"
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
--- Zones UPlanet du jour ---" >> "$archive_file"
        for zone_file in "${zone_files[@]}"; do
            echo "Zone: $(basename "$zone_file")" >> "$archive_file"
        done
    fi
    
    #######################################################################
    # ANALYSE DES CACHES SYSTÈME UPlanet
    #######################################################################
    echo "
=== ANALYSE DES CACHES SYSTÈME ===" >> "$archive_file"
    
    # Cache Swarm (~/.zen/tmp/swarm) - Alimenté par _12345.sh
    echo "
--- CACHE SWARM (alimenté par _12345.sh) ---" >> "$archive_file"
    if [[ -d ~/.zen/tmp/swarm ]]; then
        local swarm_size=$(du -sh ~/.zen/tmp/swarm 2>/dev/null | cut -f1)
        local swarm_nodes=$(find ~/.zen/tmp/swarm -maxdepth 1 -type d | wc -l)
        local swarm_files=$(find ~/.zen/tmp/swarm -type f | wc -l)
        
        echo "Taille totale: $swarm_size" >> "$archive_file"
        echo "Nombre de nodes: $((swarm_nodes - 1))" >> "$archive_file"
        echo "Nombre de fichiers: $swarm_files" >> "$archive_file"
        
        # Lister les nodes actifs avec leurs timestamps
        echo "
Nodes actifs dans le swarm:" >> "$archive_file"
        for node_dir in ~/.zen/tmp/swarm/12D*; do
            if [[ -d "$node_dir" ]]; then
                local node_id=$(basename "$node_dir")
                local moats_file="$node_dir/_MySwarm.moats"
                local json_file="$node_dir/12345.json"
                
                if [[ -f "$moats_file" ]]; then
                    local timestamp=$(cat "$moats_file")
                    echo "  $node_id: timestamp=$timestamp" >> "$archive_file"
                fi
                
                if [[ -f "$json_file" ]]; then
                    local captain=$(jq -r '.captain' "$json_file" 2>/dev/null)
                    local hostname=$(jq -r '.hostname' "$json_file" 2>/dev/null)
                    local version=$(jq -r '.version' "$json_file" 2>/dev/null)
                    echo "    Captain: $captain, Host: $hostname, Version: $version" >> "$archive_file"
                fi
            fi
        done
        
        # Services disponibles dans le swarm
        echo "
Services disponibles dans le swarm:" >> "$archive_file"
        find ~/.zen/tmp/swarm -name "x_*.sh" -exec basename {} \; 2>/dev/null | sort | uniq -c >> "$archive_file"
        
    else
        echo "Cache swarm non trouvé" >> "$archive_file"
    fi
    
    # Cache Coucou (~/.zen/tmp/coucou) - Profils et portefeuilles
    echo "
--- CACHE COUCOU (profils Cesium/GChange) ---" >> "$archive_file"
    if [[ -d ~/.zen/tmp/coucou ]]; then
        local coucou_size=$(du -sh ~/.zen/tmp/coucou 2>/dev/null | cut -f1)
        local coucou_files=$(find ~/.zen/tmp/coucou -type f | wc -l)
        local coins_files=$(find ~/.zen/tmp/coucou -name "*.COINS" | wc -l)
        local gchange_files=$(find ~/.zen/tmp/coucou -name "*.gchange.json" | wc -l)
        local cesium_files=$(find ~/.zen/tmp/coucou -name "*.cesium.json" | wc -l)
        local avatar_files=$(find ~/.zen/tmp/coucou -name "*.avatar.png" | wc -l)
        
        echo "Taille totale: $coucou_size" >> "$archive_file"
        echo "Fichiers total: $coucou_files" >> "$archive_file"
        echo "Fichiers COINS (soldes): $coins_files" >> "$archive_file"
        echo "Profils GChange: $gchange_files" >> "$archive_file"
        echo "Profils Cesium: $cesium_files" >> "$archive_file"
        echo "Avatars: $avatar_files" >> "$archive_file"
        
        # Analyser quelques profils récents
        echo "
Profils récents (dernières 24h):" >> "$archive_file"
        find ~/.zen/tmp/coucou -name "*.gchange.json" -mtime -1 -exec basename {} .gchange.json \; 2>/dev/null | head -5 >> "$archive_file"
        
        # Soldes en cache
        echo "
Soldes en cache (exemples):" >> "$archive_file"
        find ~/.zen/tmp/coucou -name "*.COINS" -mtime -1 2>/dev/null | head -5 | while read coins_file; do
            local g1pub=$(basename "$coins_file" .COINS)
            local balance=$(cat "$coins_file" 2>/dev/null)
            echo "  ${g1pub:0:20}...: $balance G1" >> "$archive_file"
        done
        
    else
        echo "Cache coucou non trouvé" >> "$archive_file"
    fi
    
    # Cache FlashMem (~/.zen/tmp/flashmem) - Géokeys
    echo "
--- CACHE FLASHMEM (géokeys - GEOKEYS_refresh.sh) ---" >> "$archive_file"
    if [[ -d ~/.zen/tmp/flashmem ]]; then
        local flashmem_size=$(du -sh ~/.zen/tmp/flashmem 2>/dev/null | cut -f1)
        local geokeys_count=$(find ~/.zen/tmp/flashmem -maxdepth 1 -type d -name "k*" | wc -l)
        local tw_count=$(find ~/.zen/tmp/flashmem -path "*/TWz/*" -type f | wc -l)
        local uplanet_dirs=$(find ~/.zen/tmp/flashmem -name "UPLANET" -type d | wc -l)
        
        echo "Taille totale: $flashmem_size" >> "$archive_file"
        echo "Géokeys cachées: $geokeys_count" >> "$archive_file"
        echo "TiddlyWikis (TWz): $tw_count" >> "$archive_file"
        echo "Répertoires UPlanet: $uplanet_dirs" >> "$archive_file"
        
        # Analyser les géokeys par type
        echo "
Types de géokeys en cache:" >> "$archive_file"
        for geo_type in UMAPS SECTORS REGIONS; do
            local count=$(find ~/.zen/tmp/flashmem -path "*UPLANET/$geo_type*" -type d | wc -l)
            echo "  $geo_type: $count" >> "$archive_file"
        done
        
        # Géokeys récentes
        echo "
Géokeys récentes (dernières 6h):" >> "$archive_file"
        find ~/.zen/tmp/flashmem -maxdepth 1 -type d -name "k*" -mmin -360 2>/dev/null | head -10 | while read geo_dir; do
            local geo_key=$(basename "$geo_dir")
            local size=$(du -sh "$geo_dir" 2>/dev/null | cut -f1)
            echo "  $geo_key: $size" >> "$archive_file"
        done
        
        # Analyse des TiddlyWikis
        if [[ -d ~/.zen/tmp/flashmem/tw ]]; then
            local tw_total=$(find ~/.zen/tmp/flashmem/tw -name "*.html" | wc -l)
            echo "
TiddlyWikis individuels: $tw_total" >> "$archive_file"
        fi
        
    else
        echo "Cache flashmem non trouvé" >> "$archive_file"
    fi
    
    # Statistiques globales des caches
    echo "
--- STATISTIQUES GLOBALES DES CACHES ---" >> "$archive_file"
    local total_cache_size=$(du -sh ~/.zen/tmp/ 2>/dev/null | cut -f1)
    local total_files=$(find ~/.zen/tmp -type f | wc -l)
    local cache_age_hours=$((($(date +%s) - $(stat -c %Y ~/.zen/tmp 2>/dev/null || echo 0)) / 3600))
    
    echo "Taille totale ~/.zen/tmp/: $total_cache_size" >> "$archive_file"
    echo "Fichiers total: $total_files" >> "$archive_file"
    echo "Âge du cache: ${cache_age_hours}h" >> "$archive_file"
    
    # Processus actifs liés aux caches
    echo "
--- PROCESSUS ACTIFS (gestion des caches) ---" >> "$archive_file"
    pgrep -af "_12345.sh\|COINScheck.sh\|GetGCAttributesFromG1PUB.sh\|GEOKEYS_refresh.sh" 2>/dev/null >> "$archive_file" || echo "Aucun processus de cache actif" >> "$archive_file"
    
    #######################################################################
    # ANALYSE DE LA ♥️BOX (HEARTBOX) - MATÉRIEL ET CAPACITÉS
    #######################################################################
    echo "
=== ANALYSE DE LA ♥️BOX (HEARTBOX) ===" >> "$archive_file"
    
    # Informations CPU
    echo "
--- PROCESSEUR (CPU) ---" >> "$archive_file"
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        local cpu_cores=$(grep "processor" /proc/cpuinfo | wc -l)
        local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        local cpu_cache=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        
        echo "Modèle: $cpu_model" >> "$archive_file"
        echo "Cœurs/Threads: $cpu_cores" >> "$archive_file"
        echo "Fréquence: ${cpu_freq} MHz" >> "$archive_file"
        echo "Cache: $cpu_cache" >> "$archive_file"
        
        # Charge CPU
        local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | xargs)
        echo "Charge moyenne: $cpu_load" >> "$archive_file"
    fi
    
    # Informations GPU
    echo "
--- PROCESSEUR GRAPHIQUE (GPU) ---" >> "$archive_file"
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "GPU NVIDIA détecté:" >> "$archive_file"
        nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | while IFS=',' read name memory_total memory_used gpu_util; do
            echo "  Modèle: $name" >> "$archive_file"
            echo "  VRAM: ${memory_used}MB / ${memory_total}MB utilisée" >> "$archive_file"
            echo "  Utilisation: ${gpu_util}%" >> "$archive_file"
        done
    elif command -v lspci >/dev/null 2>&1; then
        local gpu_info=$(lspci | grep -i "vga\|3d\|display" | head -1)
        echo "GPU détecté: $gpu_info" >> "$archive_file"
    else
        echo "Aucun GPU détecté ou outils non disponibles" >> "$archive_file"
    fi
    
    # Mémoire RAM
    echo "
--- MÉMOIRE RAM ---" >> "$archive_file"
    if [[ -f /proc/meminfo ]]; then
        local mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        local mem_used=$((mem_total - mem_available))
        local mem_total_gb=$((mem_total / 1024 / 1024))
        local mem_used_gb=$((mem_used / 1024 / 1024))
        local mem_usage_percent=$((mem_used * 100 / mem_total))
        
        echo "Total: ${mem_total_gb} GB" >> "$archive_file"
        echo "Utilisée: ${mem_used_gb} GB (${mem_usage_percent}%)" >> "$archive_file"
    fi
    
    # Analyse du stockage et capacités ♥️BOX
    echo "
--- STOCKAGE ET CAPACITÉS ♥️BOX ---" >> "$archive_file"
    
    # Espace disque total et disponible
    local disk_info=$(df -h / | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_available=$(echo "$disk_info" | awk '{print $4}')
    local disk_usage_percent=$(echo "$disk_info" | awk '{print $5}')
    
    echo "Disque principal (/):" >> "$archive_file"
    echo "  Total: $disk_total" >> "$archive_file"
    echo "  Utilisé: $disk_used ($disk_usage_percent)" >> "$archive_file"
    echo "  Disponible: $disk_available" >> "$archive_file"
    
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
Capacité d'abonnements (après réserve capitaine):" >> "$archive_file"
        echo "  ZenCards (128 GB/slot): $zencard_parts slots disponibles" >> "$archive_file"
        echo "  NOSTR Cards (10 GB/slot): $nostr_parts slots disponibles" >> "$archive_file"
        echo "  Réservé capitaine: 8 slots (1024 GB)" >> "$archive_file"
    fi
    
    # Analyse IPFS
    echo "
--- STOCKAGE IPFS ---" >> "$archive_file"
    if [[ -d ~/.ipfs ]]; then
        local ipfs_size=$(du -sh ~/.ipfs 2>/dev/null | cut -f1)
        echo "Taille ~/.ipfs: $ipfs_size" >> "$archive_file"
        
        # Analyse de la configuration IPFS
        if [[ -f ~/.ipfs/config ]]; then
            echo "Configuration IPFS:" >> "$archive_file"
            
            # Seuils de Garbage Collection
            local storage_max=$(jq -r '.Datastore.StorageMax // "10GB"' ~/.ipfs/config 2>/dev/null)
            local storage_gc_watermark=$(jq -r '.Datastore.StorageGCWatermark // 90' ~/.ipfs/config 2>/dev/null)
            local gc_period=$(jq -r '.Datastore.GCPeriod // "1h"' ~/.ipfs/config 2>/dev/null)
            
            echo "  StorageMax: $storage_max" >> "$archive_file"
            echo "  GC Watermark: ${storage_gc_watermark}%" >> "$archive_file"
            echo "  GC Period: $gc_period" >> "$archive_file"
            
            # Calcul de proximité avec GC
            if [[ "$storage_max" =~ ([0-9]+)GB ]]; then
                local max_gb=${BASH_REMATCH[1]}
                local ipfs_gb=$(echo "$ipfs_size" | sed 's/G//' | sed 's/M/\/1024/' | bc 2>/dev/null || echo "0")
                local gc_threshold_gb=$(echo "$max_gb * $storage_gc_watermark / 100" | bc 2>/dev/null || echo "0")
                local gc_proximity_percent=$(echo "scale=1; $ipfs_gb * 100 / $gc_threshold_gb" | bc 2>/dev/null || echo "0")
                
                echo "  Proximité GC: ${gc_proximity_percent}% du seuil (${gc_threshold_gb}GB)" >> "$archive_file"
                
                # Alerte si proche du GC
                if [[ $(echo "$gc_proximity_percent > 80" | bc 2>/dev/null) -eq 1 ]]; then
                    echo "  ⚠️  ALERTE: Proche du seuil de Garbage Collection!" >> "$archive_file"
                fi
            fi
            
            # Swarm settings
            local swarm_peers=$(jq -r '.Swarm.ConnMgr.HighWater // 900' ~/.ipfs/config 2>/dev/null)
            echo "  Max peers Swarm: $swarm_peers" >> "$archive_file"
        fi
        
        # Statistiques IPFS en direct si possible
        if command -v ipfs >/dev/null 2>&1 && pgrep ipfs >/dev/null; then
            local ipfs_stats=$(ipfs stats bw --interval 1s 2>/dev/null | head -1 || echo "Non disponible")
            echo "  Bande passante: $ipfs_stats" >> "$archive_file"
            
            local ipfs_peers=$(ipfs swarm peers 2>/dev/null | wc -l || echo "0")
            echo "  Peers connectés: $ipfs_peers" >> "$archive_file"
        fi
    else
        echo "Répertoire ~/.ipfs non trouvé" >> "$archive_file"
    fi
    
    # Analyse NextCloud (si Docker disponible)
    echo "
--- NEXTCLOUD (CLOUD PERSONNEL) ---" >> "$archive_file"
    
    # Vérifier si NextCloud est configuré via Docker
    local nextcloud_compose="$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/docker-compose.yml"
    if [[ -f "$nextcloud_compose" ]]; then
        echo "Configuration NextCloud détectée: $nextcloud_compose" >> "$archive_file"
        
        # Vérifier les ports NextCloud spécifiques
        echo "
Vérification des ports NextCloud:" >> "$archive_file"
        
        # Port 8002 - AIO Interface (HTTPS)
        if netstat -tln 2>/dev/null | grep -q ":8002 "; then
            echo "  ✅ Port 8002 (AIO HTTPS): OUVERT" >> "$archive_file"
        else
            echo "  ❌ Port 8002 (AIO HTTPS): FERMÉ" >> "$archive_file"
        fi
        
        # Port 8001 - Cloud Interface (HTTP)
        if netstat -tln 2>/dev/null | grep -q ":8001 "; then
            echo "  ✅ Port 8001 (Cloud HTTP): OUVERT" >> "$archive_file"
        else
            echo "  ❌ Port 8001 (Cloud HTTP): FERMÉ" >> "$archive_file"
        fi
        
        # Ports additionnels du docker-compose
        local additional_ports=("8008" "8443")
        for port in "${additional_ports[@]}"; do
            if netstat -tln 2>/dev/null | grep -q ":$port "; then
                echo "  ✅ Port $port: OUVERT" >> "$archive_file"
            else
                echo "  ❌ Port $port: FERMÉ" >> "$archive_file"
            fi
        done
        
        # Vérifier si les conteneurs NextCloud sont actifs
        if command -v docker >/dev/null 2>&1; then
            local nc_containers=$(docker ps --filter "name=nextcloud" --format "{{.Names}} ({{.Status}})" 2>/dev/null)
            if [[ -n "$nc_containers" ]]; then
                echo "
Conteneurs NextCloud actifs:" >> "$archive_file"
                echo "$nc_containers" >> "$archive_file"
            else
                echo "
❌ Aucun conteneur NextCloud actif" >> "$archive_file"
            fi
            
            # Analyser le volume de données NextCloud
            local nc_datadir="/nextcloud-data"
            if [[ -d "$nc_datadir" ]]; then
                local nc_size=$(du -sh "$nc_datadir" 2>/dev/null | cut -f1)
                local nc_files=$(find "$nc_datadir" -type f 2>/dev/null | wc -l)
                echo "
Données NextCloud ($nc_datadir):" >> "$archive_file"
                echo "  Taille: $nc_size" >> "$archive_file"
                echo "  Fichiers: $nc_files" >> "$archive_file"
                
                # Vérifier les logs récents
                local nc_log_dir="$nc_datadir/nextcloud.log"
                if [[ -f "$nc_log_dir" ]]; then
                    local nc_log_size=$(du -sh "$nc_log_dir" 2>/dev/null | cut -f1)
                    echo "  Log: $nc_log_size" >> "$archive_file"
                fi
            else
                echo "Répertoire de données NextCloud non trouvé: $nc_datadir" >> "$archive_file"
            fi
        else
            echo "Docker non disponible pour vérifier NextCloud" >> "$archive_file"
        fi
    else
        echo "NextCloud non configuré (docker-compose.yml absent)" >> "$archive_file"
    fi
    
    # Résumé des capacités ♥️BOX
    echo "
--- RÉSUMÉ CAPACITÉS ♥️BOX ---" >> "$archive_file"
    echo "Type de node: $(if [[ -f ~/.zen/game/secret.dunikey ]]; then echo "Y Level (Node autonome)"; else echo "Standard (avec Capitaine)"; fi)" >> "$archive_file"
    echo "Espace total: $disk_total" >> "$archive_file"
    echo "Services actifs:" >> "$archive_file"
    echo "  - IPFS: $(if pgrep ipfs >/dev/null; then echo "✅ Actif ($ipfs_size)"; else echo "❌ Inactif"; fi)" >> "$archive_file"
    echo "  - NextCloud: $(if docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | grep -q nextcloud; then echo "✅ Actif"; else echo "❌ Inactif"; fi)" >> "$archive_file"
    echo "  - Astroport: $(if pgrep -f "12345" >/dev/null; then echo "✅ Actif"; else echo "❌ Inactif"; fi)" >> "$archive_file"
    echo "Potentiel d'abonnements: $zencard_parts ZenCards + $nostr_parts NOSTR Cards" >> "$archive_file"
    
    echo "
=== FIN ARCHIVE PHASE $cleanup_phase - $(date) ===" >> "$archive_file"
    echo "" >> "$archive_file"
    
    echo "📝 Logs sauvegardés dans $archive_file (phase: $cleanup_phase)"
}

########################################################################
## IPFS DAEMON STATUS
LOWMODE=$(sudo systemctl status ipfs | grep "preset: disabled") ## IPFS DISABLED - START ONLY FOR SYNC -
[[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]] && LOWMODE="NO 5001" ## IPFS IS STOPPED
[[ ! $isLAN || ${zipit} != "" ]] && LOWMODE="" ## LOWMODE ONLY FOR LAN STATION

########################################################################
## CHECK IF IPFS NODE IS RESPONDING (ipfs name resolve ?)
########################################################################
ipfs --timeout=30s swarm peers 2>/dev/null > ~/.zen/tmp/ipfs.swarm.peers
[[ ! -s ~/.zen/tmp/ipfs.swarm.peers || $? != 0 ]] \
    && echo "---- SWARM COMMUNICATION BROKEN / RESTARTING IPFS DAEMON ----" \
    && sudo systemctl restart ipfs \
    && sleep 60

floop=0
while [[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]]; do
    sleep 10
    ((floop++)) && [ $floop -gt 36 ] \
        && echo "ERROR. IPFS daemon not restarting" \
        && ${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "IPFS RESTART ERROR 20H12" \
        && exit 1
done

########################################################################
# show ZONE.sh cache of the day
echo "TODAY UPlanet landings"
ls ~/.zen/tmp/ZONE_* 2>/dev/null

########################################################################
## SAUVEGARDER LES LOGS AVANT PREMIER NETTOYAGE
echo "📝 Sauvegarde des logs avant premier nettoyage..."
save_logs_to_archive "PREMIER_NETTOYAGE"

## REMOVE TMP BUT KEEP swarm, flashmem and coucou
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
mv ~/.zen/tmp/flashmem ~/.zen/flashmem
rm -Rf ~/.zen/tmp/*
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou
mv ~/.zen/flashmem ~/.zen/tmp/flashmem

## STOPPING ASTROPORT
sudo systemctl stop astroport

########################################################################
## UPDATE G1BILLET code
[[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] \
&& cd ~/.zen/G1BILLET/ && git pull \
&& rm -Rf ~/.zen/G1BILLET/tmp/*

## UPDATE UPassport
[[ -s ~/.zen/UPassport/54321.py ]] \
&& cd ~/.zen/UPassport && git pull

## UPDATE NIP-101
[[ -d ~/.zen/workspace/NIP-101 ]] \
&& cd ~/.zen/workspace/NIP-101 && git pull
## TODO LOG ROTATE

########################################################################
## UPDATE Astroport.ONE code
cd ${MY_PATH}/
git pull

########################################################################
## Updating yt-dlp
${MY_PATH}/youtube-dl.sh
yt-dlp -U

########################################################################
## DRAGON SSH WOT
echo "DRAGONS SHIELD OFF"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh off

########################################################################
## PING BOOSTRAP & SWARM NODES
${MY_PATH}/ping_bootstrap.sh > /dev/null 2>&1

################## NOSTR Cards (Notes and Other Stuff Transmitted by Relays)
${MY_PATH}/RUNTIME/NOSTRCARD.refresh.sh

########################################################################
if [[ ${UPLANETG1PUB} == "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z" ]]; then
    #################### UPLANET ORIGIN : PRIVATE SWARM BLOOM #########
    ${MY_PATH}/RUNTIME/BLOOM.Me.sh
else
    # UPlanet Zen MULTIPASS/ZenCard TW mode
    #####################################
    ${MY_PATH}/RUNTIME/PLAYER.refresh.sh
    #####################################
    [[ -s ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt ]] \
        && rm ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt
fi
######################################################### UPLANET ######
#####################################
# UPLANET : GeoKeys UMAP / SECTOR / REGION ...
#####################################
${MY_PATH}/RUNTIME/UPLANET.refresh.sh
#####################################
#####################################

########################################################################
## SAUVEGARDER LES LOGS AVANT DEUXIEME NETTOYAGE
echo "📝 Sauvegarde des logs avant deuxième nettoyage..."
save_logs_to_archive "DEUXIEME_NETTOYAGE"

## REMOVE TMP BUT KEEP swarm, flashmem ${IPFSNODEID} and coucou
mv ~/.zen/tmp/${IPFSNODEID} ~/.zen/${IPFSNODEID}
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
mv ~/.zen/tmp/flashmem ~/.zen/flashmem
rm -Rf ~/.zen/tmp/*
mv ~/.zen/${IPFSNODEID} ~/.zen/tmp/${IPFSNODEID}
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou
mv ~/.zen/flashmem ~/.zen/tmp/flashmem

########################################################################
################################# updating ipfs bootstrap
espeak "bootstrap refresh" > /dev/null 2>&1
ipfs bootstrap rm --all > /dev/null 2>&1
for bootnode in $(cat ${STRAPFILE} | grep -Ev "#") # remove comments
do
    ipfsnodeid=${bootnode##*/}
    ipfs bootstrap add $bootnode
done


########################################################################
echo "IPFS DAEMON LEVEL"
######### IPFS DAMEON NOT RUNNING ALL DAY
## IF IPFS DAEMON DISABLED : WAIT 1H & STOP IT
[[ $LOWMODE != "" ]] \
    && echo "STOP IPFS $LOWMODE" \
    && sleep 3600 \
    && sudo systemctl stop ipfs \
    && exit 0

echo "HIGH. RESTART IPFS"
sleep 60
sudo systemctl restart ipfs

#################################
### DRAGON WOT : SSH P2P RING OPENING
#################################
sleep 30
echo "DRAGONS SHIELD ON"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh

## RESTART ASTROPORT
# espeak "Restarting Astroport Services" > /dev/null 2>&1
## CLOSING API PORT
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) > /dev/null 2>&1
## KILL ALL REMAINING nc
killall nc 12345.sh > /dev/null 2>&1

## SYSTEMD OR NOT SYSTEMD
if [[ ! -f /etc/systemd/system/astroport.service ]]; then
    ${MY_PATH}/12345.sh > ~/.zen/tmp/12345.log &
    PID=$!
    echo $PID > ~/.zen/.pid
else
    sudo systemctl restart astroport
    [[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] && sudo systemctl restart g1billet
    echo "Astroport processes systemd restart"

fi
#####################################
# Node refreshing
#####################################
${MY_PATH}/RUNTIME/NODE.refresh.sh
#####################################
########################################################################
end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))

# Ajouter un résumé final au log
echo "
#######################################################################
20H12 EXECUTION TERMINÉE - $(date)
#######################################################################
DURÉE: ${hours}h ${minutes}m ${seconds}s ($dur secondes)
HOSTNAME: $(hostname -f)
IPFS NODE: ${IPFSNODEID}
UPLANET: ${UPLANETG1PUB}
STATUS: SUCCESS
#######################################################################" >> /tmp/20h12.log

echo "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "20H12 (♥‿‿♥) Execution time was $dur seconds."

## MAIL LOG : support@qo-op.com ##
${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "$(cat ~/.zen/GPS 2>/dev/null) 20H12 : $(cat ~/.zen/game/players/.current/.player 2>/dev/null)"

espeak "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1

exit 0
