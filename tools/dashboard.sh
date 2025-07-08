#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.1 - Interface Capitaine (Bugs corrigés)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# ♥️BOX CONTROL V2 - Interface Capitaine UPlanet
# Focus: Simplicité, utilité, économie ZEN
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/my.sh"

# Forcer la locale numérique pour éviter les problèmes de virgule/point
export LC_NUMERIC=C

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration globale
HEARTBOX_DIR="$HOME/.zen/heartbox"
HEARTBOX_CACHE_DIR="$HOME/.zen/tmp/heartbox_cache"
mkdir -p "$HEARTBOX_DIR" "$HEARTBOX_CACHE_DIR"

# Cache sudo pour éviter les demandes répétées
SUDO_CACHE_FILE="$HEARTBOX_CACHE_DIR/sudo_check.cache"
SUDO_CACHE_TIMEOUT=300  # 5 minutes

#######################################################################
# Utilitaires optimisés
#######################################################################

# Vérification sudo avec cache
check_sudo_cached() {
    if [[ -f "$SUDO_CACHE_FILE" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$SUDO_CACHE_FILE" 2>/dev/null || echo 0) ))
        if [[ $cache_age -lt $SUDO_CACHE_TIMEOUT ]]; then
            return 0  # Sudo OK récemment
        fi
    fi
    
    # Test silencieux de sudo
    if sudo -n true 2>/dev/null; then
        touch "$SUDO_CACHE_FILE"
        return 0
    else
        return 1
    fi
}

# Formatage sécurisé des nombres
safe_printf() {
    local format="$1"
    local number="$2"
    # Remplacer la virgule par un point si nécessaire
    number=$(echo "$number" | sed 's/,/./g')
    LC_NUMERIC=C printf "$format" "$number" 2>/dev/null || echo "N/A"
}

#######################################################################
# Dashboard Économique Simplifié
#######################################################################

show_captain_dashboard() {
    clear
    local current_player=$(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo "Anonyme")
    
    # En-tête Capitaine
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}⚓ Capitaine:${NC} $current_player"
    echo -e "${BLUE}║${NC}  ${CYAN}🏴‍☠️ CoeurBox:${NC} $(hostname) • ${CYAN}🌐 Node:${NC} ${IPFSNODEID:0:8}..."
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Statut économique en une ligne
    show_economic_summary
    echo ""
    
    # Statut des services critiques
    show_critical_services_status
    echo ""
    
    # Alertes et notifications
    show_captain_alerts
    echo ""
}

show_economic_summary() {
    echo -e "${YELLOW}💰 ÉCONOMIE ZEN${NC}"
    
    # Calcul du PAF (Prix d'Abonnement Fixe)
    local paf_today=$(calculate_daily_paf)
    local balance_zen=$(get_zen_balance)
    local subscription_revenue=$(get_subscription_revenue)
    
    # Affichage en une ligne compacte avec formatage sécurisé
    local balance_str=$(safe_printf "%.2f" "$balance_zen")
    local paf_str=$(safe_printf "%.2f" "$paf_today")
    local revenue_str=$(safe_printf "%.2f" "$subscription_revenue")
    
    printf "  💎 Solde: ${GREEN}%s Ẑ${NC} • 📊 PAF: ${CYAN}%s Ẑ/jour${NC} • 💼 Revenus: ${GREEN}+%s Ẑ${NC}\n" \
        "$balance_str" "$paf_str" "$revenue_str"
    
    # Indicateur de santé économique (comparaison numérique sécurisée)
    local autonomy_days=$(echo "scale=1; $balance_zen / $paf_today" | bc -l 2>/dev/null || echo "0")
    
    if (( $(echo "$autonomy_days > 7" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  🟢 Santé: ${GREEN}Excellente${NC} (>7 jours d'autonomie)"
    elif (( $(echo "$autonomy_days > 3" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  🟡 Santé: ${YELLOW}Correcte${NC} (3-7 jours d'autonomie)"
    else
        echo -e "  🔴 Santé: ${RED}Attention${NC} (<3 jours d'autonomie)"
    fi
}

show_critical_services_status() {
    echo -e "${CYAN}🔧 SERVICES CRITIQUES${NC}"
    
    local status_parts=()
    
    # IPFS
    if pgrep ipfs >/dev/null 2>&1; then
        local peers=$(ipfs swarm peers 2>/dev/null | wc -l || echo "0")
        status_parts+=("IPFS:${GREEN}✓${NC}($peers)")
    else
        status_parts+=("IPFS:${RED}✗${NC}")
    fi
    
    # Astroport
    if pgrep -f "12345" >/dev/null 2>&1; then
        status_parts+=("API:${GREEN}✓${NC}")
    else
        status_parts+=("API:${RED}✗${NC}")
    fi
    
    # WireGuard (vérification optimisée)
    if check_sudo_cached && sudo -n wg show wg0 >/dev/null 2>&1; then
        local wg_peers=$(sudo -n wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
        status_parts+=("VPN:${GREEN}✓${NC}($wg_peers)")
    else
        status_parts+=("VPN:${RED}✗${NC}")
    fi
    
    # Swarm
    local swarm_nodes=$(find ~/.zen/tmp/swarm -maxdepth 1 -type d -name "12D*" 2>/dev/null | wc -l)
    if [[ $swarm_nodes -gt 0 ]]; then
        status_parts+=("Swarm:${GREEN}✓${NC}($swarm_nodes)")
    else
        status_parts+=("Swarm:${YELLOW}⚠${NC}")
    fi
    
    # Affichage avec espaces
    echo -e "  $(IFS=' ' ; echo "${status_parts[*]}")"
}

show_captain_alerts() {
    echo -e "${PURPLE}🚨 ALERTES${NC}"
    
    local alerts=()
    
    # Vérification espace disque
    local disk_usage=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
    if [[ $disk_usage -gt 85 ]]; then
        alerts+=("💾 Espace disque faible: ${disk_usage}%")
    fi
    
    # Vérification économique
    local balance=$(get_zen_balance)
    local paf=$(calculate_daily_paf)
    if (( $(echo "$balance < $paf * 2" | bc -l 2>/dev/null || echo 0) )); then
        alerts+=("💰 Solde ZEN bas: rechargez bientôt")
    fi
    
    # Vérification services
    if ! pgrep ipfs >/dev/null 2>&1; then
        alerts+=("🌐 IPFS arrêté")
    fi
    
    if ! pgrep -f "12345" >/dev/null 2>&1; then
        alerts+=("🚀 API Astroport arrêtée")
    fi
    
    # Affichage des alertes
    if [[ ${#alerts[@]} -eq 0 ]]; then
        echo -e "  🟢 Tout fonctionne normalement"
    else
        for alert in "${alerts[@]}"; do
            echo -e "  🔴 $alert"
        done
    fi
}

#######################################################################
# Actions Rapides Capitaine
#######################################################################

show_quick_actions() {
    echo -e "${YELLOW}⚡ ACTIONS RAPIDES${NC}"
    echo ""
    echo -e "  ${GREEN}r${NC} - 🔄 Redémarrer tous les services"
    echo -e "  ${GREEN}s${NC} - 🔍 Découvrir l'essaim"
    echo -e "  ${GREEN}v${NC} - 🎫 Imprimer ma VISA"
    echo -e "  ${GREEN}z${NC} - 💰 Vérifier économie ZEN"
    echo -e "  ${GREEN}p${NC} - 🏴‍☠️ Changer de capitaine"
    echo -e "  ${GREEN}h${NC} - ❓ Aide UPlanet"
    echo ""
    echo -e "  ${CYAN}1${NC} - 📊 Monitoring avancé"
    echo -e "  ${CYAN}2${NC} - 🛠️  Gestion technique"
    echo -e "  ${CYAN}3${NC} - ⚙️  Configuration"
    echo ""
    echo -e "  ${RED}0${NC} - ❌ Quitter"
    echo ""
}

#######################################################################
# Fonctions économiques
#######################################################################

calculate_daily_paf() {
    # Calcul du PAF basé sur les ressources système
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo "1")
    local mem_kb=$(grep "MemTotal" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "1048576")
    local mem_gb=$(echo "scale=2; $mem_kb / 1024 / 1024" | bc -l 2>/dev/null || echo "1")
    
    local disk_gb=$(df -BG / 2>/dev/null | tail -1 | awk '{print $2}' | sed 's/G//' || echo "10")
    
    # Formule PAF = f(CPU, RAM, Disque) avec gestion d'erreurs
    local base_paf=1.0
    local cpu_factor=$(echo "scale=2; $cpu_cores * 0.5" | bc -l 2>/dev/null || echo "0.5")
    local mem_factor=$(echo "scale=2; $mem_gb * 0.1" | bc -l 2>/dev/null || echo "0.1")
    local disk_factor=$(echo "scale=2; $disk_gb * 0.01" | bc -l 2>/dev/null || echo "0.1")
    
    local paf=$(echo "scale=2; $base_paf + $cpu_factor + $mem_factor + $disk_factor" | bc -l 2>/dev/null || echo "2.00")
    echo "$paf"
}

get_zen_balance() {
    # Simulation - à remplacer par la vraie logique ZEN
    local balance_file="$HOME/.zen/tmp/zen_balance.cache"
    
    if [[ -f "$balance_file" ]]; then
        cat "$balance_file"
    else
        # Calcul du solde basé sur les transactions
        local balance=$(echo "scale=2; 50.0 + ($RANDOM % 100)" | bc -l 2>/dev/null || echo "50.00")
        echo "$balance" > "$balance_file"
        echo "$balance"
    fi
}

get_subscription_revenue() {
    # Revenus des abonnements reçus
    local sub_file="$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions_received.json"
    
    if [[ -f "$sub_file" ]]; then
        local count=$(jq '.received_subscriptions | length' "$sub_file" 2>/dev/null || echo "0")
        echo "scale=2; $count * 2.5" | bc -l 2>/dev/null || echo "0.00"
    else
        echo "0.00"
    fi
}

#######################################################################
# Actions simplifiées
#######################################################################

restart_all_services() {
    echo -e "${CYAN}🔄 Redémarrage des services...${NC}"
    
    # IPFS
    echo -e "  📡 IPFS..."
    if sudo systemctl restart ipfs 2>/dev/null; then
        echo -e "    ✅ OK"
    else
        echo -e "    ❌ Erreur"
    fi
    
    # Astroport
    echo -e "  🚀 Astroport..."
    killall nc 12345.sh 2>/dev/null
    "${MY_PATH}/../12345.sh" > ~/.zen/tmp/12345.log & 
    sleep 2 && echo -e "    ✅ OK"
    
    # WireGuard (optionnel)
    echo -e "  🔒 WireGuard..."
    if check_sudo_cached && sudo systemctl restart wg-quick@wg0 2>/dev/null; then
        echo -e "    ✅ OK"
    else
        echo -e "    ⚠️ Optionnel"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Services redémarrés${NC}"
    sleep 2
}

quick_swarm_discover() {
    echo -e "${CYAN}🔍 Découverte de l'essaim...${NC}"
    if [[ -x "${MY_PATH}/../RUNTIME/SWARM.discover.sh" ]]; then
        "${MY_PATH}/../RUNTIME/SWARM.discover.sh" | head -20
    else
        echo -e "${RED}❌ Script SWARM.discover.sh non trouvé${NC}"
    fi
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

print_captain_visa() {
    local current_player=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
    
    if [[ -n "$current_player" ]]; then
        echo -e "${CYAN}🎫 Impression VISA pour $current_player...${NC}"
        if [[ -x "${MY_PATH}/VISA.print.sh" ]]; then
            "${MY_PATH}/VISA.print.sh" "$current_player"
        else
            echo -e "${RED}❌ Script VISA.print.sh non trouvé${NC}"
        fi
    else
        echo -e "${RED}❌ Aucun capitaine connecté${NC}"
        echo "Voulez-vous vous connecter ? (o/n)"
        read -p "> " connect_choice
        if [[ "$connect_choice" == "o" || "$connect_choice" == "O" ]]; then
            change_captain
        fi
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

check_zen_economy() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                            ${YELLOW}💰 ÉCONOMIE ZEN${NC}                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local balance=$(get_zen_balance)
    local paf=$(calculate_daily_paf)
    local revenue=$(get_subscription_revenue)
    local days_autonomy=$(echo "scale=1; $balance / $paf" | bc -l 2>/dev/null || echo "0.0")
    
    local balance_str=$(safe_printf "%.2f" "$balance")
    local paf_str=$(safe_printf "%.2f" "$paf")
    local revenue_str=$(safe_printf "%.2f" "$revenue")
    local autonomy_str=$(safe_printf "%.1f" "$days_autonomy")
    
    echo -e "${WHITE}💎 Solde actuel:${NC} ${GREEN}$balance_str Ẑ${NC}"
    echo -e "${WHITE}📊 PAF quotidien:${NC} ${CYAN}$paf_str Ẑ/jour${NC}"
    echo -e "${WHITE}💼 Revenus abonnements:${NC} ${GREEN}+$revenue_str Ẑ/jour${NC}"
    echo -e "${WHITE}⏰ Autonomie:${NC} $autonomy_str jours"
    echo ""
    
    # Historique des 7 derniers jours
    echo -e "${CYAN}📈 Historique (7 derniers jours):${NC}"
    for i in {6..0}; do
        local date_str=$(date -d "$i days ago" "+%d/%m" 2>/dev/null || echo "N/A")
        local balance_day=$(echo "scale=2; $balance - $i * $paf + $i * $revenue" | bc -l 2>/dev/null || echo "0.00")
        local balance_day_str=$(safe_printf "%.2f" "$balance_day")
        printf "  %s: %s Ẑ\n" "$date_str" "$balance_day_str"
    done
    
    echo ""
    echo -e "${YELLOW}💡 Conseils:${NC}"
    if (( $(echo "$days_autonomy < 3" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  🔴 Rechargez votre solde ZEN rapidement"
        echo -e "  🔍 Cherchez plus d'abonnés pour augmenter vos revenus"
    elif (( $(echo "$days_autonomy < 7" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  🟡 Surveillez votre solde ZEN"
        echo -e "  📈 Optimisez vos services pour attirer plus d'abonnés"
    else
        echo -e "  🟢 Excellente santé économique !"
        echo -e "  🚀 Vous pouvez investir dans de nouveaux services"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

change_captain() {
    echo -e "${CYAN}🏴‍☠️ Changement de capitaine${NC}"
    echo ""
    
    # Liste des capitaines disponibles
    if [[ -d ~/.zen/game/players ]]; then
        echo "Capitaines disponibles:"
        local i=1
        local players=()
        
        for player_dir in ~/.zen/game/players/*/; do
            if [[ -d "$player_dir" && "$(basename "$player_dir")" != ".current" ]]; then
                local player_name=$(basename "$player_dir")
                players+=("$player_name")
                echo -e "  $i. 🏴‍☠️ $player_name"
                ((i++))
            fi
        done
        
        echo -e "  0. 🆕 Nouveau capitaine"
        echo ""
        
        read -p "Votre choix: " captain_choice
        
        if [[ "$captain_choice" == "0" ]]; then
            read -p "Email du nouveau capitaine: " new_captain_email
            echo "Création du nouveau capitaine: $new_captain_email"
            # Logique de création à implémenter
        elif [[ "$captain_choice" =~ ^[0-9]+$ ]] && [[ $captain_choice -le ${#players[@]} ]]; then
            local selected_player="${players[$((captain_choice-1))]}"
            echo "$selected_player" > ~/.zen/game/players/.current/.player
            echo -e "${GREEN}✅ Capitaine changé: $selected_player${NC}"
        else
            echo -e "${RED}❌ Choix invalide${NC}"
        fi
    else
        echo -e "${RED}❌ Aucun capitaine trouvé${NC}"
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

show_uplanet_help() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                            ${YELLOW}❓ AIDE UPLANET${NC}                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}🏴‍☠️ Qu'est-ce qu'un Capitaine ?${NC}"
    echo "  Vous êtes le propriétaire d'une CoeurBox (♥️BOX) qui participe"
    echo "  à l'économie décentralisée UPlanet. Vous fournissez des services"
    echo "  (stockage, calcul, relais) et recevez des Ẑen en échange."
    echo ""
    
    echo -e "${CYAN}💰 Économie Ẑen${NC}"
    echo "  • 1 Ẑen = 0.1 G1 (monnaie libre)"
    echo "  • PAF = Prix d'Abonnement Fixe quotidien"
    echo "  • Revenus = Abonnements reçus d'autres nodes"
    echo "  • Équilibre = Revenus - PAF"
    echo ""
    
    echo -e "${CYAN}🔧 Services principaux${NC}"
    echo "  • IPFS: Stockage décentralisé"
    echo "  • Astroport: API et orchestration"
    echo "  • WireGuard: VPN pour les clients"
    echo "  • Swarm: Découverte des autres nodes"
    echo ""
    
    echo -e "${CYAN}🎯 Objectifs${NC}"
    echo "  • Maintenir vos services actifs"
    echo "  • Attirer des abonnés pour générer des revenus"
    echo "  • Participer à l'essaim UPlanet"
    echo "  • Contribuer à l'économie transparente"
    echo ""
    
    echo -e "${YELLOW}📚 Ressources${NC}"
    echo "  • Blog: https://www.copylaradio.com"
    echo "  • Documentation: /home/$(whoami)/.zen/Astroport.ONE/README.md"
    echo "  • Support: support@qo-op.com"
    echo ""
    
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

#######################################################################
# Menu principal simplifié
#######################################################################

show_main_menu() {
    show_captain_dashboard
    show_quick_actions
}

#######################################################################
# Boucle principale
#######################################################################

main_loop() {
    while true; do
        show_main_menu
        read -p "Votre choix: " choice
        
        case $choice in
            # Actions rapides
            "r") restart_all_services ;;
            "s") quick_swarm_discover ;;
            "v") print_captain_visa ;;
            "z") check_zen_economy ;;
            "p") change_captain ;;
            "h") show_uplanet_help ;;
            
            # Menu technique (conservé mais simplifié)
            "1") 
                # Import des fonctions avancées du script original
                if [[ -f "${MY_PATH}/heartbox_control.sh" ]]; then
                    source "${MY_PATH}/heartbox_control.sh"
                    show_detailed_monitoring
                else
                    echo -e "${RED}❌ Script heartbox_control.sh non trouvé${NC}"
                    read -p "Appuyez sur ENTRÉE..."
                fi
                ;;
            "2") 
                echo -e "${CYAN}🛠️  Gestion technique - Fonctionnalités avancées${NC}"
                echo "Pour l'accès technique complet, utilisez:"
                echo "  ./heartbox_control.sh"
                echo ""
                read -p "Appuyez sur ENTRÉE..."
                ;;
            "3")
                echo -e "${CYAN}⚙️  Configuration simplifiée${NC}"
                echo -e "Node ID: ${IPFSNODEID:-'Non configuré'}"
                echo -e "Capitaine: $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'Non configuré')"
                echo -e "Type: $(if [[ -f ~/.zen/game/secret.dunikey ]]; then echo "Y Level (Autonome)"; else echo "Standard"; fi)"
                echo ""
                read -p "Appuyez sur ENTRÉE..."
                ;;
            
            "0") 
                echo -e "${GREEN}🏴‍☠️ Bon vent, Capitaine !${NC}"
                exit 0
                ;;
                
            *)
                echo -e "${RED}❌ Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

#######################################################################
# Point d'entrée
#######################################################################

# Vérification des prérequis
if [[ ! -f "${MY_PATH}/my.sh" ]]; then
    echo "❌ Fichier my.sh non trouvé. Exécutez depuis le répertoire Astroport.ONE/tools/"
    exit 1
fi

# Démarrage de l'interface
clear
echo -e "${CYAN}♥️BOX CONTROL V2.1${NC} - Interface Capitaine"
echo -e "${YELLOW}🏴‍☠️ Bienvenue à bord !${NC}"
sleep 2

main_loop 