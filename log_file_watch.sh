#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# log_file_watch.sh
# Script de surveillance des logs du processus d'ajout de fichiers UPlanet
################################################################################

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'aide
show_help() {
    echo "
📁 FILE UPLOAD WATCH - Surveillance des ajouts de fichiers UPlanet
====================================================================

USAGE:
    ./log_file_watch.sh [OPTIONS]

OPTIONS:
    --help      Afficher cette aide
    --menu      Mode menu interactif pour choisir les logs
    --check     Vérifier la disponibilité des logs uniquement
    (aucune)    Afficher tous les logs disponibles (défaut)

LOGS SURVEILLÉS:
    📤 Upload & IPFS:
        - ~/.zen/tmp/upload2ipfs.log       (Uploads IPFS)
        - ~/.zen/tmp/ajouter_media.log     (Ajout média principal)
        - ~/.zen/tmp/upload_*.json         (Résultats uploads)
        
    🎬 YouTube Processing:
        - ~/.zen/tmp/youtube_sync.log      (Synchronisation)
        - ~/.zen/tmp/process_youtube.log   (Traitement vidéos)
        - ~/.zen/tmp/yt-dlp.log           (yt-dlp downloads)
        - ~/.zen/game/nostr/*/processed_youtube_videos (Historique)
        
    🎭 TMDB Metadata:
        - ~/.zen/tmp/tmdb_scraper.log     (Scraping TMDB)
        - ~/.zen/tmp/scraper.log          (Métadonnées films/séries)
        
    📡 NOSTR Events:
        - ~/.zen/tmp/nostr_publish.log    (Publications NOSTR)
        - ~/.zen/tmp/nostr_video.log      (Événements kind 21/22)
        - ~/.zen/tmp/nostr_file.log       (Événements kind 1063)
        - ~/.zen/tmp/nostr_send_note.log  (Envois d'événements)

EXEMPLES:
    ./log_file_watch.sh                # Tous les logs
    ./log_file_watch.sh --menu         # Menu interactif
    ./log_file_watch.sh --check        # Vérifier les logs
    ./log_file_watch.sh --help         # Cette aide

NOTES:
    - Utilisez Ctrl+C pour arrêter l'observation
    - Les fichiers de logs sont créés automatiquement lors des opérations
    - Certains logs peuvent être dans ~/.zen/tmp/IA.log
"
}

# Fonction pour vérifier la présence d'un fichier de log
check_log_file() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        local lines=$(wc -l < "$file" 2>/dev/null)
        echo -e "${GREEN}✅${NC} $description: $file (${size}, ${lines} lignes)"
        return 0
    else
        echo -e "${RED}❌${NC} $description: $file ${YELLOW}(manquant)${NC}"
        return 1
    fi
}

# Fonction pour vérifier les logs de pattern
check_log_pattern() {
    local pattern="$1"
    local description="$2"
    
    local files=$(ls $pattern 2>/dev/null | wc -l)
    if [[ $files -gt 0 ]]; then
        echo -e "${GREEN}✅${NC} $description: $pattern (${files} fichier(s))"
        return 0
    else
        echo -e "${RED}❌${NC} $description: $pattern ${YELLOW}(aucun fichier)${NC}"
        return 1
    fi
}

# Fonction pour vérifier tous les logs
check_all_logs() {
    echo -e "${BLUE}🔍 VÉRIFICATION DES LOGS DISPONIBLES${NC}"
    echo "===================================="
    
    echo ""
    echo -e "${BLUE}📤 UPLOAD & IPFS:${NC}"
    check_log_file "$HOME/.zen/tmp/upload2ipfs.log" "Upload IPFS"
    check_log_file "$HOME/.zen/tmp/ajouter_media.log" "Ajout média"
    check_log_pattern "$HOME/.zen/tmp/upload_*.json" "Résultats uploads"
    check_log_file "$HOME/.zen/tmp/54321.log" "UPassport API (uploads)"
    
    echo ""
    echo -e "${BLUE}🎬 YOUTUBE PROCESSING:${NC}"
    check_log_file "$HOME/.zen/tmp/youtube_sync.log" "Sync YouTube"
    check_log_file "$HOME/.zen/tmp/process_youtube.log" "Process YouTube"
    check_log_file "$HOME/.zen/tmp/yt-dlp.log" "yt-dlp downloads"
    check_log_file "$HOME/.zen/tmp/IA.log" "IA (contient YouTube)"
    
    echo ""
    echo -e "${BLUE}🎭 TMDB METADATA:${NC}"
    check_log_file "$HOME/.zen/tmp/tmdb_scraper.log" "Scraper TMDB"
    check_log_file "$HOME/.zen/tmp/scraper.log" "Scraper général"
    
    echo ""
    echo -e "${BLUE}📡 NOSTR EVENTS:${NC}"
    check_log_file "$HOME/.zen/tmp/nostr_publish.log" "Publications NOSTR"
    check_log_file "$HOME/.zen/tmp/nostr_video.log" "Vidéos (kind 21/22)"
    check_log_file "$HOME/.zen/tmp/nostr_file.log" "Fichiers (kind 1063)"
    check_log_file "$HOME/.zen/tmp/nostr_send_note.log" "Envoi événements"
    check_log_file "$HOME/.zen/tmp/nostpy.log" "NostrPy"
    
    echo ""
    echo -e "${BLUE}📊 STATISTIQUES:${NC}"
    
    # Compter les uploads récents (dernière heure)
    local recent_uploads=$(find "$HOME/.zen/tmp/" -name "upload_*.json" -mmin -60 2>/dev/null | wc -l)
    echo -e "  Uploads récents (1h): ${GREEN}${recent_uploads}${NC}"
    
    # Vérifier les vidéos traitées
    local processed_videos=$(find "$HOME/.zen/game/nostr/" -name ".processed_youtube_videos" -exec cat {} \; 2>/dev/null | wc -l)
    echo -e "  Vidéos YouTube traitées: ${GREEN}${processed_videos}${NC}"
    
    echo ""
}

# Fonction pour démarrer l'observation des logs d'upload
start_upload_logs() {
    echo -e "${BLUE}📤 Démarrage des logs Upload & IPFS...${NC}"
    
    # Créer les fichiers de log s'ils n'existent pas
    touch "$HOME/.zen/tmp/upload2ipfs.log" 2>/dev/null
    touch "$HOME/.zen/tmp/ajouter_media.log" 2>/dev/null
    
    [[ -f "$HOME/.zen/tmp/upload2ipfs.log" ]] && {
        echo "  → upload2ipfs.log"
        tail -f "$HOME/.zen/tmp/upload2ipfs.log" 2>/dev/null | sed 's/^/[UPLOAD] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/ajouter_media.log" ]] && {
        echo "  → ajouter_media.log"
        tail -f "$HOME/.zen/tmp/ajouter_media.log" 2>/dev/null | sed 's/^/[MEDIA] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/54321.log" ]] && {
        echo "  → 54321.log (UPassport)"
        tail -f "$HOME/.zen/tmp/54321.log" 2>/dev/null | grep -i "upload\|file\|ipfs" | sed 's/^/[API] /' &
    }
}

# Fonction pour démarrer l'observation des logs YouTube
start_youtube_logs() {
    echo -e "${BLUE}🎬 Démarrage des logs YouTube...${NC}"
    
    # Créer les fichiers de log s'ils n'existent pas
    touch "$HOME/.zen/tmp/youtube_sync.log" 2>/dev/null
    touch "$HOME/.zen/tmp/process_youtube.log" 2>/dev/null
    touch "$HOME/.zen/tmp/yt-dlp.log" 2>/dev/null
    
    [[ -f "$HOME/.zen/tmp/youtube_sync.log" ]] && {
        echo "  → youtube_sync.log"
        tail -f "$HOME/.zen/tmp/youtube_sync.log" 2>/dev/null | sed 's/^/[YT-SYNC] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/process_youtube.log" ]] && {
        echo "  → process_youtube.log"
        tail -f "$HOME/.zen/tmp/process_youtube.log" 2>/dev/null | sed 's/^/[YT-PROC] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/yt-dlp.log" ]] && {
        echo "  → yt-dlp.log"
        tail -f "$HOME/.zen/tmp/yt-dlp.log" 2>/dev/null | sed 's/^/[YT-DLP] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/IA.log" ]] && {
        echo "  → IA.log (filtré YouTube)"
        tail -f "$HOME/.zen/tmp/IA.log" 2>/dev/null | grep -i "youtube\|yt-dlp" | sed 's/^/[IA] /' &
    }
}

# Fonction pour démarrer l'observation des logs TMDB
start_tmdb_logs() {
    echo -e "${BLUE}🎭 Démarrage des logs TMDB...${NC}"
    
    # Créer les fichiers de log s'ils n'existent pas
    touch "$HOME/.zen/tmp/tmdb_scraper.log" 2>/dev/null
    touch "$HOME/.zen/tmp/scraper.log" 2>/dev/null
    
    [[ -f "$HOME/.zen/tmp/tmdb_scraper.log" ]] && {
        echo "  → tmdb_scraper.log"
        tail -f "$HOME/.zen/tmp/tmdb_scraper.log" 2>/dev/null | sed 's/^/[TMDB] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/scraper.log" ]] && {
        echo "  → scraper.log"
        tail -f "$HOME/.zen/tmp/scraper.log" 2>/dev/null | sed 's/^/[SCRAPER] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/IA.log" ]] && {
        echo "  → IA.log (filtré TMDB)"
        tail -f "$HOME/.zen/tmp/IA.log" 2>/dev/null | grep -i "tmdb\|film\|serie" | sed 's/^/[IA-TMDB] /' &
    }
}

# Fonction pour démarrer l'observation des logs NOSTR
start_nostr_logs() {
    echo -e "${BLUE}📡 Démarrage des logs NOSTR Events...${NC}"
    
    # Créer les fichiers de log s'ils n'existent pas
    touch "$HOME/.zen/tmp/nostr_publish.log" 2>/dev/null
    touch "$HOME/.zen/tmp/nostr_video.log" 2>/dev/null
    touch "$HOME/.zen/tmp/nostr_file.log" 2>/dev/null
    touch "$HOME/.zen/tmp/nostr_send_note.log" 2>/dev/null
    
    [[ -f "$HOME/.zen/tmp/nostr_publish.log" ]] && {
        echo "  → nostr_publish.log"
        tail -f "$HOME/.zen/tmp/nostr_publish.log" 2>/dev/null | sed 's/^/[PUBLISH] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/nostr_video.log" ]] && {
        echo "  → nostr_video.log (kind 21/22)"
        tail -f "$HOME/.zen/tmp/nostr_video.log" 2>/dev/null | sed 's/^/[VIDEO] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/nostr_file.log" ]] && {
        echo "  → nostr_file.log (kind 1063)"
        tail -f "$HOME/.zen/tmp/nostr_file.log" 2>/dev/null | sed 's/^/[FILE] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/nostr_send_note.log" ]] && {
        echo "  → nostr_send_note.log"
        tail -f "$HOME/.zen/tmp/nostr_send_note.log" 2>/dev/null | sed 's/^/[SEND] /' &
    }
    
    [[ -f "$HOME/.zen/tmp/nostpy.log" ]] && {
        echo "  → nostpy.log"
        tail -f "$HOME/.zen/tmp/nostpy.log" 2>/dev/null | grep -i "kind.*21\|kind.*22\|kind.*1063" | sed 's/^/[NOSTPY] /' &
    }
}

# Fonction pour arrêter tous les processus de logs
stop_all_watching() {
    echo -e "${YELLOW}🛑 Arrêt des processus de surveillance...${NC}"
    # Tuer tous les tail et grep enfants de ce script
    pkill -P $$ 2>/dev/null
    sleep 1
}

# Fonction pour démarrer tous les logs
start_all_logs() {
    echo -e "${GREEN}🚀 DÉMARRAGE DE TOUS LES LOGS (FILE UPLOAD)${NC}"
    echo "============================================="
    echo ""
    
    stop_all_watching
    
    start_upload_logs
    echo ""
    start_youtube_logs
    echo ""
    start_tmdb_logs
    echo ""
    start_nostr_logs
    
    echo ""
    echo -e "${GREEN}📋 Observation active. Appuyez sur Ctrl+C pour arrêter.${NC}"
    echo -e "${BLUE}📊 Processus lancés: $(jobs | wc -l)${NC}"
    echo ""
    echo -e "${YELLOW}💡 ASTUCE: Les messages sont préfixés par leur source${NC}"
    echo -e "   [UPLOAD]   = Upload IPFS"
    echo -e "   [YT-SYNC]  = Synchronisation YouTube"
    echo -e "   [TMDB]     = Scraping TMDB"
    echo -e "   [PUBLISH]  = Publication NOSTR"
    echo ""
    
    # Attendre indéfiniment
    wait
}

# Menu interactif
show_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║   📁 FILE UPLOAD WATCH - Menu Principal       ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 📊 Vérifier la disponibilité des logs"
        echo -e "  ${GREEN}2)${NC} 📤 Logs Upload & IPFS uniquement"
        echo -e "  ${GREEN}3)${NC} 🎬 Logs YouTube uniquement"
        echo -e "  ${GREEN}4)${NC} 🎭 Logs TMDB uniquement"
        echo -e "  ${GREEN}5)${NC} 📡 Logs NOSTR Events uniquement"
        echo -e "  ${GREEN}6)${NC} 🚀 Tous les logs (recommandé)"
        echo -e "  ${GREEN}7)${NC} 🛑 Arrêter l'observation"
        echo -e "  ${GREEN}8)${NC} ❌ Quitter"
        echo ""
        echo -e "${YELLOW}Votre choix (1-8):${NC} "
        read -r choice
        
        case $choice in
            1)
                clear
                check_all_logs
                echo ""
                echo -e "${YELLOW}Appuyez sur ENTER pour continuer...${NC}"
                read
                ;;
            2)
                clear
                stop_all_watching
                start_upload_logs
                echo ""
                echo -e "${GREEN}📤 Observation Upload active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            3)
                clear
                stop_all_watching
                start_youtube_logs
                echo ""
                echo -e "${GREEN}🎬 Observation YouTube active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            4)
                clear
                stop_all_watching
                start_tmdb_logs
                echo ""
                echo -e "${GREEN}🎭 Observation TMDB active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            5)
                clear
                stop_all_watching
                start_nostr_logs
                echo ""
                echo -e "${GREEN}📡 Observation NOSTR active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            6)
                clear
                start_all_logs
                ;;
            7)
                stop_all_watching
                echo -e "${YELLOW}🛑 Observation arrêtée.${NC}"
                sleep 1
                ;;
            8)
                stop_all_watching
                echo -e "${GREEN}👋 Au revoir!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Choix invalide (1-8)${NC}"
                sleep 1
                ;;
        esac
    done
}

# Gestion du signal Ctrl+C
trap 'echo ""; echo -e "${YELLOW}⚠️  Arrêt demandé...${NC}"; stop_all_watching; exit 0' INT TERM

# Point d'entrée principal
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --menu|-m)
        show_menu
        exit 0
        ;;
    --check|-c)
        check_all_logs
        exit 0
        ;;
    "")
        # Mode par défaut : tous les logs
        start_all_logs
        ;;
    *)
        echo -e "${RED}❌ Option inconnue: $1${NC}"
        echo "Utilisez --help pour voir les options disponibles."
        exit 1
        ;;
esac

