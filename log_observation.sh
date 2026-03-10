#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# log_observation.sh
# Script d'observation des logs de l'écosystème UPlanet complet
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonction d'aide
show_help() {
    echo "
🔍 LOG OBSERVATION - Écosystème UPlanet Complet
================================================

USAGE:
    ./log_observation.sh [OPTIONS]

OPTIONS:
    --help      Afficher cette aide
    --menu      Mode menu interactif pour choisir les logs
    (aucune)    Afficher tous les logs disponibles (défaut)

LOGS SURVEILLÉS PAR CATÉGORIE:

📡 ASTROPORT CORE (Coordination):
    - journalctl astroport
    - ~/.zen/tmp/IA.log (Intelligence Artificielle)
    - ~/.zen/tmp/12345.log (API principale)
    - ~/.zen/tmp/_12345.log (API interne)
    - ~/.zen/tmp/cron.log (Tâches planifiées)

🌐 NOSTR RELAY & EVENTS (NIP-101):
    - journalctl strfry
    - ~/.zen/tmp/strfry.log (Relay core)
    - ~/.zen/tmp/nostr_kind1_messages.log (Messages kind 1)
    - ~/.zen/tmp/nostr_likes.log (Reactions kind 7)
    - ~/.zen/tmp/nostpy.log (Python NOSTR)
    - ~/.zen/tmp/nostr_publish.log (Publications)
    - ~/.zen/tmp/nostr_send_note.log (Envoi notes)

🗝️  UPASSPORT API (Port 54321):
    - journalctl upassport
    - ~/.zen/tmp/54321.log (API UPassport)
    - ~/.zen/tmp/upassport.log (Scan QR codes)

📹 NOSTRTUBE & MEDIA (Files & Videos):
    - ~/.zen/tmp/upload2ipfs.log (Uploads IPFS)
    - ~/.zen/tmp/ajouter_media.log (Ajout média)
    - ~/.zen/tmp/upload_*.json (Résultats)
    - ~/.zen/tmp/youtube_sync.log (Sync YouTube)
    - ~/.zen/tmp/process_youtube.log (Process YT)
    - ~/.zen/tmp/yt-dlp.log (Downloads)
    - ~/.zen/tmp/tmdb_scraper.log (TMDB metadata)
    - ~/.zen/tmp/scraper.log (Scraper général)
    - ~/.zen/tmp/nostr_video.log (Events kind 21/22)
    - ~/.zen/tmp/nostr_file.log (Events kind 1063)
    - ~/.zen/tmp/tube_manager.log (Admin NostrTube)

🎫 ORACLE SYSTEM (Permits - NIP-101):
    - ~/.zen/tmp/oracle.log (Système Oracle)
    - ~/.zen/tmp/permit_request.log (Demandes)
    - ~/.zen/tmp/permit_attestation.log (Attestations)
    - ~/.zen/tmp/permit_credential.log (Credentials)

🌿 ORE SYSTEM (Environmental - NIP-101):
    - ~/.zen/tmp/ore.log (Système ORE)
    - ~/.zen/tmp/ore_verification.log (Vérifications)
    - ~/.zen/tmp/ore_meeting.log (Meetings)

🗺️  UMAP & GEOGRAPHIC:
    - ~/.zen/tmp/umap.log (UMAPs geographic)
    - ~/.zen/tmp/geonostr.log (NOSTR géographique)
    - ~/.zen/tmp/sector.log (Secteurs)
    - ~/.zen/tmp/region.log (Régions)

🔗 CONSTELLATION SYNC (Backfill):
    - ~/.zen/tmp/constellation.log (Sync constellation)
    - ~/.zen/tmp/backfill.log (Backfill events)
    - ~/.zen/tmp/sync_stats.log (Stats sync)

💰 BLOCKCHAIN & ECONOMY (Ğ1 & ẐEN):
    - ~/.zen/tmp/duniter.log (Duniter blockchain)
    - ~/.zen/tmp/gcli.log (Client g1cli Duniter v2s)
    - ~/.zen/tmp/zen_payment.log (Paiements ẐEN)
    - ~/.zen/tmp/palpal.log (Terminal PalPay)
    - ~/.zen/tmp/COINS.log (Balance checks)

📦 IPFS & STORAGE:
    - journalctl ipfs
    - ~/.ipfs/logs/* (IPFS daemon)
    - ~/.zen/tmp/ipfs_add.log (Ajouts IPFS)
    - ~/.zen/tmp/ipfs_pin.log (Pinning)
    - ~/.zen/tmp/ipns_publish.log (Publications IPNS)

🔐 SECURITY & IDENTITY (DID):
    - ~/.zen/tmp/did.log (DID documents)
    - ~/.zen/tmp/multipass.log (MULTIPASS)
    - ~/.zen/tmp/ssss.log (Shamir keys)
    - ~/.zen/tmp/gpg.log (Cryptographie)
    - ~/.zen/tmp/auth.log (Authentification NIP-42)

🌐 WEB SERVICES:
    - journalctl nginx (si installé)
    - ~/.zen/tmp/http_access.log (Accès HTTP)
    - ~/.zen/tmp/websocket.log (WebSocket)

EXEMPLES:
    ./log_observation.sh              # Tous les logs
    ./log_observation.sh --menu       # Menu interactif
    ./log_observation.sh --help       # Cette aide

NOTES:
    - Utilisez Ctrl+C pour arrêter l'observation
    - Les services systemd doivent être actifs pour journalctl
    - Les fichiers de logs sont créés automatiquement si nécessaire
    - Logs avec préfixes colorés pour identification facile
"
}

# Fonction pour vérifier la présence d'un fichier de log
check_log_file() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        echo "✅ $description: $file"
        return 0
    else
        echo "❌ $description: $file (manquant)"
        return 1
    fi
}

# Fonction pour vérifier un service systemd
check_systemd_service() {
    local service="$1"
    local description="$2"
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "✅ $description: systemctl $service (actif)"
        return 0
    else
        echo "❌ $description: systemctl $service (inactif/manquant)"
        return 1
    fi
}

# Fonction pour vérifier tous les logs
check_all_logs() {
    echo -e "${CYAN}🔍 VÉRIFICATION DES LOGS DISPONIBLES${NC}"
    echo "===================================="
    
    echo ""
    echo -e "${BLUE}📡 ASTROPORT CORE:${NC}"
    check_systemd_service "astroport" "Service Astroport"
    check_log_file "$HOME/.zen/tmp/IA.log" "Log IA"
    check_log_file "$HOME/.zen/tmp/12345.log" "Log 12345 API"
    check_log_file "$HOME/.zen/tmp/_12345.log" "Log _12345 Internal"
    check_log_file "$HOME/.zen/tmp/cron.log" "Log Cron"
    
    echo ""
    echo -e "${BLUE}🌐 NOSTR RELAY & EVENTS:${NC}"
    check_systemd_service "strfry" "Service strfry"
    check_log_file "$HOME/.zen/tmp/strfry.log" "Log strfry core"
    check_log_file "$HOME/.zen/tmp/nostr_kind1_messages.log" "Messages kind 1"
    check_log_file "$HOME/.zen/tmp/nostr_likes.log" "Reactions kind 7"
    check_log_file "$HOME/.zen/tmp/nostpy.log" "Python NOSTR"
    check_log_file "$HOME/.zen/tmp/nostr_publish.log" "Publications"
    check_log_file "$HOME/.zen/tmp/nostr_send_note.log" "Envoi notes"
    
    echo ""
    echo -e "${BLUE}🗝️  UPASSPORT API:${NC}"
    check_systemd_service "upassport" "Service UPassport"
    check_log_file "$HOME/.zen/tmp/54321.log" "API UPassport"
    check_log_file "$HOME/.zen/tmp/upassport.log" "Scan QR codes"
    
    echo ""
    echo -e "${BLUE}📹 NOSTRTUBE & MEDIA:${NC}"
    check_log_file "$HOME/.zen/tmp/upload2ipfs.log" "Upload IPFS"
    check_log_file "$HOME/.zen/tmp/ajouter_media.log" "Ajout média"
    check_log_file "$HOME/.zen/tmp/youtube_sync.log" "Sync YouTube"
    check_log_file "$HOME/.zen/tmp/tmdb_scraper.log" "TMDB scraper"
    check_log_file "$HOME/.zen/tmp/nostr_video.log" "Events kind 21/22"
    check_log_file "$HOME/.zen/tmp/tube_manager.log" "Admin NostrTube"
    
    echo ""
    echo -e "${BLUE}🎫 ORACLE SYSTEM (NIP-101):${NC}"
    check_log_file "$HOME/.zen/tmp/oracle.log" "Oracle system"
    check_log_file "$HOME/.zen/tmp/permit_request.log" "Permit requests"
    check_log_file "$HOME/.zen/tmp/permit_attestation.log" "Attestations"
    
    echo ""
    echo -e "${BLUE}🌿 ORE SYSTEM (NIP-101):${NC}"
    check_log_file "$HOME/.zen/tmp/ore.log" "ORE system"
    check_log_file "$HOME/.zen/tmp/ore_verification.log" "Verifications"
    
    echo ""
    echo -e "${BLUE}🗺️  UMAP & GEOGRAPHIC:${NC}"
    check_log_file "$HOME/.zen/tmp/umap.log" "UMAP geographic"
    check_log_file "$HOME/.zen/tmp/geonostr.log" "NOSTR geo"
    
    echo ""
    echo -e "${BLUE}🔗 CONSTELLATION SYNC:${NC}"
    check_log_file "$HOME/.zen/tmp/constellation.log" "Constellation"
    check_log_file "$HOME/.zen/tmp/backfill.log" "Backfill"
    
    echo ""
    echo -e "${BLUE}💰 BLOCKCHAIN & ECONOMY:${NC}"
    check_log_file "$HOME/.zen/tmp/duniter.log" "Duniter"
    check_log_file "$HOME/.zen/tmp/zen_payment.log" "Paiements ẐEN"
    check_log_file "$HOME/.zen/tmp/COINS.log" "Balance checks"
    
    echo ""
    echo -e "${BLUE}📦 IPFS & STORAGE:${NC}"
    check_systemd_service "ipfs" "IPFS daemon"
    check_log_file "$HOME/.zen/tmp/ipfs_add.log" "IPFS add"
    check_log_file "$HOME/.zen/tmp/ipns_publish.log" "IPNS publish"
    
    echo ""
    echo -e "${BLUE}🔐 SECURITY & IDENTITY:${NC}"
    check_log_file "$HOME/.zen/tmp/did.log" "DID documents"
    check_log_file "$HOME/.zen/tmp/multipass.log" "MULTIPASS"
    check_log_file "$HOME/.zen/tmp/auth.log" "Auth NIP-42"
    
    echo ""
}

# Fonction pour démarrer l'observation d'un groupe de logs
start_astroport_logs() {
    echo -e "${BLUE}📡 Démarrage des logs Astroport...${NC}"
    
    if systemctl is-active --quiet astroport 2>/dev/null; then
        journalctl -fu astroport 2>/dev/null | sed 's/^/[ASTROPORT] /' &
    else
        echo -e "${YELLOW}⚠️  Service astroport non actif${NC}"
    fi
    
    [[ -f "$HOME/.zen/tmp/IA.log" ]] && tail -f "$HOME/.zen/tmp/IA.log" 2>/dev/null | sed 's/^/[IA] /' &
    [[ -f "$HOME/.zen/tmp/12345.log" ]] && tail -f "$HOME/.zen/tmp/12345.log" 2>/dev/null | sed 's/^/[API] /' &
    [[ -f "$HOME/.zen/tmp/_12345.log" ]] && tail -f "$HOME/.zen/tmp/_12345.log" 2>/dev/null | sed 's/^/[API-INT] /' &
    [[ -f "$HOME/.zen/tmp/cron.log" ]] && tail -f "$HOME/.zen/tmp/cron.log" 2>/dev/null | sed 's/^/[CRON] /' &
}

start_nostr_logs() {
    echo -e "${BLUE}🌐 Démarrage des logs NOSTR...${NC}"
    
    if systemctl is-active --quiet strfry 2>/dev/null; then
        journalctl -fu strfry 2>/dev/null | sed 's/^/[STRFRY] /' &
    else
        echo -e "${YELLOW}⚠️  Service strfry non actif${NC}"
    fi
    
    [[ -f "$HOME/.zen/tmp/strfry.log" ]] && tail -f "$HOME/.zen/tmp/strfry.log" 2>/dev/null | sed 's/^/[RELAY] /' &
    [[ -f "$HOME/.zen/tmp/nostr_kind1_messages.log" ]] && tail -f "$HOME/.zen/tmp/nostr_kind1_messages.log" 2>/dev/null | sed 's/^/[MSG-K1] /' &
    [[ -f "$HOME/.zen/tmp/nostr_likes.log" ]] && tail -f "$HOME/.zen/tmp/nostr_likes.log" 2>/dev/null | sed 's/^/[LIKES-K7] /' &
    [[ -f "$HOME/.zen/tmp/nostpy.log" ]] && tail -f "$HOME/.zen/tmp/nostpy.log" 2>/dev/null | sed 's/^/[NOSTPY] /' &
    [[ -f "$HOME/.zen/tmp/nostr_publish.log" ]] && tail -f "$HOME/.zen/tmp/nostr_publish.log" 2>/dev/null | sed 's/^/[PUBLISH] /' &
    [[ -f "$HOME/.zen/tmp/nostr_send_note.log" ]] && tail -f "$HOME/.zen/tmp/nostr_send_note.log" 2>/dev/null | sed 's/^/[SEND] /' &
}

start_upassport_logs() {
    echo -e "${BLUE}🗝️  Démarrage des logs UPassport...${NC}"
    
    if systemctl is-active --quiet upassport 2>/dev/null; then
        journalctl -fu upassport 2>/dev/null | sed 's/^/[UPASSPORT] /' &
    else
        echo -e "${YELLOW}⚠️  Service upassport non actif${NC}"
    fi
    
    [[ -f "$HOME/.zen/tmp/54321.log" ]] && tail -f "$HOME/.zen/tmp/54321.log" 2>/dev/null | sed 's/^/[API-54321] /' &
    [[ -f "$HOME/.zen/tmp/upassport.log" ]] && tail -f "$HOME/.zen/tmp/upassport.log" 2>/dev/null | sed 's/^/[QR-SCAN] /' &
}

start_media_logs() {
    echo -e "${BLUE}📹 Démarrage des logs NostrTube & Media...${NC}"
    
    [[ -f "$HOME/.zen/tmp/upload2ipfs.log" ]] && tail -f "$HOME/.zen/tmp/upload2ipfs.log" 2>/dev/null | sed 's/^/[UPLOAD] /' &
    [[ -f "$HOME/.zen/tmp/ajouter_media.log" ]] && tail -f "$HOME/.zen/tmp/ajouter_media.log" 2>/dev/null | sed 's/^/[MEDIA] /' &
    [[ -f "$HOME/.zen/tmp/youtube_sync.log" ]] && tail -f "$HOME/.zen/tmp/youtube_sync.log" 2>/dev/null | sed 's/^/[YT-SYNC] /' &
    [[ -f "$HOME/.zen/tmp/tmdb_scraper.log" ]] && tail -f "$HOME/.zen/tmp/tmdb_scraper.log" 2>/dev/null | sed 's/^/[TMDB] /' &
    [[ -f "$HOME/.zen/tmp/nostr_video.log" ]] && tail -f "$HOME/.zen/tmp/nostr_video.log" 2>/dev/null | sed 's/^/[VIDEO-K21/22] /' &
    [[ -f "$HOME/.zen/tmp/tube_manager.log" ]] && tail -f "$HOME/.zen/tmp/tube_manager.log" 2>/dev/null | sed 's/^/[TUBE-ADMIN] /' &
}

start_oracle_logs() {
    echo -e "${BLUE}🎫 Démarrage des logs Oracle System (NIP-101)...${NC}"
    
    [[ -f "$HOME/.zen/tmp/oracle.log" ]] && tail -f "$HOME/.zen/tmp/oracle.log" 2>/dev/null | sed 's/^/[ORACLE] /' &
    [[ -f "$HOME/.zen/tmp/permit_request.log" ]] && tail -f "$HOME/.zen/tmp/permit_request.log" 2>/dev/null | sed 's/^/[PERMIT-REQ] /' &
    [[ -f "$HOME/.zen/tmp/permit_attestation.log" ]] && tail -f "$HOME/.zen/tmp/permit_attestation.log" 2>/dev/null | sed 's/^/[ATTEST] /' &
}

start_ore_logs() {
    echo -e "${BLUE}🌿 Démarrage des logs ORE System (NIP-101)...${NC}"
    
    [[ -f "$HOME/.zen/tmp/ore.log" ]] && tail -f "$HOME/.zen/tmp/ore.log" 2>/dev/null | sed 's/^/[ORE] /' &
    [[ -f "$HOME/.zen/tmp/ore_verification.log" ]] && tail -f "$HOME/.zen/tmp/ore_verification.log" 2>/dev/null | sed 's/^/[ORE-VERIFY] /' &
}

start_geographic_logs() {
    echo -e "${BLUE}🗺️  Démarrage des logs UMAP & Geographic...${NC}"
    
    [[ -f "$HOME/.zen/tmp/umap.log" ]] && tail -f "$HOME/.zen/tmp/umap.log" 2>/dev/null | sed 's/^/[UMAP] /' &
    [[ -f "$HOME/.zen/tmp/geonostr.log" ]] && tail -f "$HOME/.zen/tmp/geonostr.log" 2>/dev/null | sed 's/^/[GEO-NOSTR] /' &
    [[ -f "$HOME/.zen/tmp/constellation.log" ]] && tail -f "$HOME/.zen/tmp/constellation.log" 2>/dev/null | sed 's/^/[CONSTELL] /' &
}

start_blockchain_logs() {
    echo -e "${BLUE}💰 Démarrage des logs Blockchain & Economy...${NC}"
    
    [[ -f "$HOME/.zen/tmp/duniter.log" ]] && tail -f "$HOME/.zen/tmp/duniter.log" 2>/dev/null | sed 's/^/[DUNITER] /' &
    [[ -f "$HOME/.zen/tmp/zen_payment.log" ]] && tail -f "$HOME/.zen/tmp/zen_payment.log" 2>/dev/null | sed 's/^/[ZEN-PAY] /' &
    [[ -f "$HOME/.zen/tmp/COINS.log" ]] && tail -f "$HOME/.zen/tmp/COINS.log" 2>/dev/null | sed 's/^/[COINS] /' &
}

start_ipfs_logs() {
    echo -e "${BLUE}📦 Démarrage des logs IPFS & Storage...${NC}"
    
    if systemctl is-active --quiet ipfs 2>/dev/null; then
        journalctl -fu ipfs 2>/dev/null | sed 's/^/[IPFS-DAEMON] /' &
    fi
    
    [[ -f "$HOME/.zen/tmp/ipfs_add.log" ]] && tail -f "$HOME/.zen/tmp/ipfs_add.log" 2>/dev/null | sed 's/^/[IPFS-ADD] /' &
    [[ -f "$HOME/.zen/tmp/ipns_publish.log" ]] && tail -f "$HOME/.zen/tmp/ipns_publish.log" 2>/dev/null | sed 's/^/[IPNS-PUB] /' &
}

start_security_logs() {
    echo -e "${BLUE}🔐 Démarrage des logs Security & Identity...${NC}"
    
    [[ -f "$HOME/.zen/tmp/did.log" ]] && tail -f "$HOME/.zen/tmp/did.log" 2>/dev/null | sed 's/^/[DID] /' &
    [[ -f "$HOME/.zen/tmp/multipass.log" ]] && tail -f "$HOME/.zen/tmp/multipass.log" 2>/dev/null | sed 's/^/[MULTIPASS] /' &
    [[ -f "$HOME/.zen/tmp/auth.log" ]] && tail -f "$HOME/.zen/tmp/auth.log" 2>/dev/null | sed 's/^/[AUTH-NIP42] /' &
}

# Fonction pour arrêter tous les processus de logs
stop_old_logging() {
    echo "🛑 Arrêt des anciens processus de logging..."
    killall tail 2>/dev/null
    killall journalctl 2>/dev/null
    sleep 1
}

# Fonction pour démarrer tous les logs
start_all_logs() {
    echo -e "${GREEN}🚀 DÉMARRAGE DE TOUS LES LOGS${NC}"
    echo "============================="
    
    stop_old_logging
    
    start_astroport_logs
    start_nostr_logs
    start_upassport_logs
    start_media_logs
    start_oracle_logs
    start_ore_logs
    start_geographic_logs
    start_blockchain_logs
    start_ipfs_logs
    start_security_logs
    
    echo ""
    echo -e "${GREEN}📋 Observation active. Appuyez sur Ctrl+C pour arrêter.${NC}"
    echo -e "${CYAN}📊 Processus lancés: $(jobs | wc -l)${NC}"
    echo ""
    echo -e "${YELLOW}💡 ASTUCE: Les messages sont préfixés par leur source${NC}"
    echo ""
    
    # Attendre indéfiniment
    wait
}

# Menu interactif
show_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}     🔍 MENU D'OBSERVATION DES LOGS UPLANET      ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 📊 Vérifier la disponibilité des logs"
        echo -e "  ${GREEN}2)${NC} 📡 Logs Astroport Core"
        echo -e "  ${GREEN}3)${NC} 🌐 Logs NOSTR Relay & Events"
        echo -e "  ${GREEN}4)${NC} 🗝️  Logs UPassport API"
        echo -e "  ${GREEN}5)${NC} 📹 Logs NostrTube & Media"
        echo -e "  ${GREEN}6)${NC} 🎫 Logs Oracle System (NIP-101)"
        echo -e "  ${GREEN}7)${NC} 🌿 Logs ORE System (NIP-101)"
        echo -e "  ${GREEN}8)${NC} 🗺️  Logs UMAP & Geographic"
        echo -e "  ${GREEN}9)${NC} 💰 Logs Blockchain & Economy"
        echo -e "  ${GREEN}10)${NC} 📦 Logs IPFS & Storage"
        echo -e "  ${GREEN}11)${NC} 🔐 Logs Security & Identity"
        echo -e "  ${GREEN}12)${NC} 🚀 ${YELLOW}TOUS LES LOGS${NC} (recommandé)"
        echo -e "  ${GREEN}13)${NC} 🛑 Arrêter l'observation"
        echo -e "  ${GREEN}0)${NC} ❌ Quitter"
        echo ""
        echo -e "${YELLOW}Votre choix (0-13):${NC} "
        read -r choice
        
        case $choice in
            1)
                check_all_logs
                echo ""
                echo -e "${YELLOW}Appuyez sur ENTER pour continuer...${NC}"
                read
                ;;
            2)
                clear
                stop_old_logging
                start_astroport_logs
                echo -e "${GREEN}📡 Observation Astroport active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            3)
                clear
                stop_old_logging
                start_nostr_logs
                echo -e "${GREEN}🌐 Observation NOSTR active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            4)
                clear
                stop_old_logging
                start_upassport_logs
                echo -e "${GREEN}🗝️  Observation UPassport active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            5)
                clear
                stop_old_logging
                start_media_logs
                echo -e "${GREEN}📹 Observation Media active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            6)
                clear
                stop_old_logging
                start_oracle_logs
                echo -e "${GREEN}🎫 Observation Oracle active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            7)
                clear
                stop_old_logging
                start_ore_logs
                echo -e "${GREEN}🌿 Observation ORE active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            8)
                clear
                stop_old_logging
                start_geographic_logs
                echo -e "${GREEN}🗺️  Observation Geographic active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            9)
                clear
                stop_old_logging
                start_blockchain_logs
                echo -e "${GREEN}💰 Observation Blockchain active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            10)
                clear
                stop_old_logging
                start_ipfs_logs
                echo -e "${GREEN}📦 Observation IPFS active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            11)
                clear
                stop_old_logging
                start_security_logs
                echo -e "${GREEN}🔐 Observation Security active. Ctrl+C pour revenir au menu.${NC}"
                wait
                ;;
            12)
                clear
                start_all_logs
                ;;
            13)
                stop_old_logging
                echo -e "${YELLOW}🛑 Observation arrêtée.${NC}"
                sleep 1
                ;;
            0)
                stop_old_logging
                echo -e "${GREEN}👋 Au revoir!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Choix invalide (0-13)${NC}"
                sleep 1
                ;;
        esac
    done
}

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
    "")
        # Mode par défaut : tous les logs
        start_all_logs
        ;;
    *)
        echo "❌ Option inconnue: $1"
        echo "Utilisez --help pour voir les options disponibles."
        exit 1
        ;;
esac
