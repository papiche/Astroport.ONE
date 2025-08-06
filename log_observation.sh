#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# log_observation.sh
# Script d'observation des logs du système UPlanet
################################################################################

# Fonction d'aide
show_help() {
    echo "
🔍 LOG OBSERVATION - Système UPlanet
===================================

USAGE:
    ./log_observation.sh [OPTIONS]

OPTIONS:
    --help      Afficher cette aide
    --menu      Mode menu interactif pour choisir les logs
    (aucune)    Afficher tous les logs disponibles (défaut)

LOGS SURVEILLÉS:
    📡 Astroport Core:
        - journalctl astroport
        - ~/.zen/tmp/IA.log
        - ~/.zen/tmp/12345.log
        - ~/.zen/tmp/_12345.log

    🌐 NOSTR Relay:
        - journalctl strfry
        - ~/.zen/tmp/nostr_kind1_messages.log
        - ~/.zen/tmp/strfry.log
        - ~/.zen/tmp/nostr_likes.log
        - ~/.zen/tmp/nostpy.log

    🗝️  UPassport API:
        - journalctl upassport
        - ~/.zen/tmp/54321.log

EXEMPLES:
    ./log_observation.sh              # Tous les logs
    ./log_observation.sh --menu       # Menu interactif
    ./log_observation.sh --help       # Cette aide

NOTES:
    - Utilisez Ctrl+C pour arrêter l'observation
    - Les services systemd doivent être actifs pour journalctl
    - Les fichiers de logs sont créés automatiquement si nécessaire
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
    echo "🔍 VÉRIFICATION DES LOGS DISPONIBLES"
    echo "===================================="
    
    echo ""
    echo "📡 ASTROPORT CORE:"
    check_systemd_service "astroport" "Service Astroport"
    check_log_file "$HOME/.zen/tmp/IA.log" "Log IA"
    check_log_file "$HOME/.zen/tmp/12345.log" "Log 12345"
    check_log_file "$HOME/.zen/tmp/_12345.log" "Log _12345"
    
    echo ""
    echo "🌐 NOSTR RELAY:"
    check_systemd_service "strfry" "Service strfry"
    check_log_file "$HOME/.zen/tmp/nostr_kind1_messages.log" "Messages UPlanet"
    check_log_file "$HOME/.zen/tmp/strfry.log" "Log strfry"
    check_log_file "$HOME/.zen/tmp/nostr_likes.log" "Likes NOSTR"
    check_log_file "$HOME/.zen/tmp/nostpy.log" "Log nostpy"
    
    echo ""
    echo "🗝️  UPASSPORT API:"
    check_systemd_service "upassport" "Service UPassport"
    check_log_file "$HOME/.zen/tmp/54321.log" "Log UPassport API"
    
    echo ""
}

# Fonction pour démarrer l'observation d'un groupe de logs
start_astroport_logs() {
    echo "📡 Démarrage des logs Astroport..."
    
    if systemctl is-active --quiet astroport 2>/dev/null; then
journalctl -fu astroport &
    else
        echo "⚠️  Service astroport non actif"
    fi
    
    [[ -f "$HOME/.zen/tmp/IA.log" ]] && tail -f "$HOME/.zen/tmp/IA.log" &
    [[ -f "$HOME/.zen/tmp/12345.log" ]] && tail -f "$HOME/.zen/tmp/12345.log" &
    [[ -f "$HOME/.zen/tmp/_12345.log" ]] && tail -f "$HOME/.zen/tmp/_12345.log" &
}

start_nostr_logs() {
    echo "🌐 Démarrage des logs NOSTR..."
    
    if systemctl is-active --quiet strfry 2>/dev/null; then
journalctl -fu strfry &
    else
        echo "⚠️  Service strfry non actif"
    fi
    
    [[ -f "$HOME/.zen/tmp/nostr_kind1_messages.log" ]] && tail -f "$HOME/.zen/tmp/nostr_kind1_messages.log" &
    [[ -f "$HOME/.zen/tmp/strfry.log" ]] && tail -f "$HOME/.zen/tmp/strfry.log" &
    [[ -f "$HOME/.zen/tmp/nostr_likes.log" ]] && tail -f "$HOME/.zen/tmp/nostr_likes.log" &
    [[ -f "$HOME/.zen/tmp/nostpy.log" ]] && tail -f "$HOME/.zen/tmp/nostpy.log" &
}

start_upassport_logs() {
    echo "🗝️  Démarrage des logs UPassport..."
    
    if systemctl is-active --quiet upassport 2>/dev/null; then
journalctl -fu upassport &
    else
        echo "⚠️  Service upassport non actif"
    fi
    
    [[ -f "$HOME/.zen/tmp/54321.log" ]] && tail -f "$HOME/.zen/tmp/54321.log" &
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
    echo "🚀 DÉMARRAGE DE TOUS LES LOGS"
    echo "============================="
    
    stop_old_logging
    
    start_astroport_logs
    start_nostr_logs
    start_upassport_logs
    
    echo ""
    echo "📋 Observation active. Appuyez sur Ctrl+C pour arrêter."
    echo "📊 Processus lancés:"
    jobs
    
    # Attendre indéfiniment
    wait
}

# Menu interactif
show_menu() {
    while true; do
        echo ""
        echo "🔍 MENU D'OBSERVATION DES LOGS"
        echo "==============================="
        echo ""
        echo "1) 📊 Vérifier la disponibilité des logs"
        echo "2) 📡 Logs Astroport uniquement"
        echo "3) 🌐 Logs NOSTR uniquement"
        echo "4) 🗝️  Logs UPassport uniquement"
        echo "5) 🚀 Tous les logs"
        echo "6) 🛑 Arrêter l'observation"
        echo "7) ❌ Quitter"
        echo ""
        echo "Votre choix (1-7):"
        read -r choice
        
        case $choice in
            1)
                check_all_logs
                echo ""
                echo "Appuyez sur ENTER pour continuer..."
                read
                ;;
            2)
                stop_old_logging
                start_astroport_logs
                echo "📡 Observation Astroport active. Ctrl+C pour revenir au menu."
                wait
                ;;
            3)
                stop_old_logging
                start_nostr_logs
                echo "🌐 Observation NOSTR active. Ctrl+C pour revenir au menu."
                wait
                ;;
            4)
                stop_old_logging
                start_upassport_logs
                echo "🗝️  Observation UPassport active. Ctrl+C pour revenir au menu."
                wait
                ;;
            5)
                start_all_logs
                ;;
            6)
                stop_old_logging
                echo "🛑 Observation arrêtée."
                ;;
            7)
                stop_old_logging
                echo "👋 Au revoir!"
                exit 0
                ;;
            *)
                echo "❌ Choix invalide (1-7)"
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
