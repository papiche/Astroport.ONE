#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 3.0 - Dashboard Économique UPlanet
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# DASHBOARD ÉCONOMIQUE UPLANET - Interface Capitaine
# Focus: Vue d'ensemble économique, statut services, actions rapides
# Évite les redondances avec captain.sh (embarquement) et zen.sh (transactions)
################################################################################
MY_PATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SCRIPT_DIR=$MY_PATH
TOOLS_PATH="${MY_PATH}/../tools"

# Source my.sh
[[ -s "${TOOLS_PATH}/my.sh" ]] \
    && source "${TOOLS_PATH}/my.sh"

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
CACHE_DIR="$HOME/.zen/tmp/coucou"
mkdir -p "$CACHE_DIR"

# Cache sudo pour éviter les demandes répétées
SUDO_CACHE_FILE="$HOME/.zen/tmp/sudo_check.cache"
SUDO_CACHE_TIMEOUT=300  # 5 minutes

#######################################################################
# Fonctions utilitaires communes (réutilisées de zen.sh)
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

# Fonction pour obtenir le solde d'un portefeuille depuis le cache (réutilisée de zen.sh)
get_wallet_balance() {
    local pubkey="$1"
    local auto_refresh="${2:-false}"
    
    # Refresh cache if requested and pubkey is valid
    if [[ "$auto_refresh" == "true" ]] && [[ -n "$pubkey" ]]; then
        ${TOOLS_PATH}/G1check.sh "$pubkey" >/dev/null 2>&1
    fi
    
    # Get balance from cache
    local balance=$(cat "$CACHE_DIR/${pubkey}.COINS" 2>/dev/null)
    if [[ -z "$balance" || "$balance" == "null" ]]; then
        echo "0"
    else
        echo "$balance"
    fi
}

# Fonction pour calculer les Ẑen (réutilisée de zen.sh)
calculate_zen_balance() {
    local g1_balance="$1"
    
    if (( $(echo "$g1_balance > 1" | bc -l 2>/dev/null || echo 0) )); then
        echo "scale=1; ($g1_balance - 1) * 10" | bc -l 2>/dev/null
    else
        echo "0"
    fi
}

# Fonction pour récupérer les données de revenu depuis G1revenue.sh
get_revenue_data() {
    local revenue_json=$(${TOOLS_PATH}/G1revenue.sh 2>/dev/null)
    
    if [[ -n "$revenue_json" ]] && echo "$revenue_json" | jq empty 2>/dev/null; then
        echo "$revenue_json"
        return 0
    else
        echo '{"total_revenue_zen": 0, "total_revenue_g1": 0, "total_transactions": 0}'
        return 1
    fi
}

# Fonction pour récupérer les données de capital social depuis G1society.sh
get_society_data() {
    local society_json=$(${TOOLS_PATH}/G1society.sh 2>/dev/null)
    
    if [[ -n "$society_json" ]] && echo "$society_json" | jq empty 2>/dev/null; then
        echo "$society_json"
        return 0
    else
        echo '{"total_outgoing_zen": 0, "total_outgoing_g1": 0, "total_transfers": 0}'
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
# Dashboard Économique UPlanet
#######################################################################

show_captain_dashboard() {
    clear
    local current_player=$(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo "Non connecté")
    
    # En-tête Capitaine
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}⚓ Capitaine:${NC} $current_player"
    echo -e "${BLUE}║${NC}  ${CYAN}🏴‍☠️ CoeurBox:${NC} $(hostname) • ${CYAN}🌐 Node:${NC} ${IPFSNODEID:0:8}..."
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Statut économique UPlanet
    show_uplanet_economic_status
    echo ""
    
    # Statut des services critiques
    show_critical_services_status
    echo ""
    
    # Alertes et notifications
    show_captain_alerts
    echo ""
}

show_uplanet_economic_status() {
    echo -e "${YELLOW}💰 ÉCONOMIE UPLANET${NC}"
    
    # Récupérer le capitaine actuel
    local current_captain=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
    if [[ -z "$current_captain" ]]; then
        echo -e "  ❌ ${RED}Aucun capitaine connecté${NC}"
        echo -e "  💡 Utilisez 'c' pour vous connecter ou 'n' pour créer un compte"
        return
    fi
    
    # Solde du capitaine (ZEN Card)
    local captain_g1pub=$(cat ~/.zen/game/players/$current_captain/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
    if [[ -n "$captain_g1pub" ]]; then
        local captain_balance=$(get_wallet_balance "$captain_g1pub")
        local captain_zen=$(calculate_zen_balance "$captain_balance")
        
        local balance_str=$(safe_printf "%.2f" "$captain_balance")
        local zen_str=$(safe_printf "%.0f" "$captain_zen")
        
        echo -e "  💎 Capitaine: ${GREEN}$balance_str Ğ1${NC} (${CYAN}$zen_str Ẑen${NC})"
    fi
    
    # Solde MULTIPASS du capitaine (si différent)
    if [[ -d ~/.zen/game/nostr/$current_captain ]]; then
        local multipass_g1pub=$(cat ~/.zen/game/nostr/$current_captain/G1PUBNOSTR 2>/dev/null)
        if [[ -n "$multipass_g1pub" ]] && [[ "$multipass_g1pub" != "$captain_g1pub" ]]; then
            local multipass_balance=$(get_wallet_balance "$multipass_g1pub")
            local multipass_zen=$(calculate_zen_balance "$multipass_balance")
            
            local mp_balance_str=$(safe_printf "%.2f" "$multipass_balance")
            local mp_zen_str=$(safe_printf "%.0f" "$multipass_zen")
            
            echo -e "  👥 MULTIPASS: ${GREEN}$mp_balance_str Ğ1${NC} (${CYAN}$mp_zen_str Ẑen${NC})"
        fi
    fi
    
    # Portefeuilles système UPlanet
    show_system_wallets_summary
    
    # Statistiques utilisateurs
    show_user_statistics
}

show_system_wallets_summary() {
    echo ""
    echo -e "${CYAN}🏛️  PORTEFEUILLES SYSTÈME UPLANET:${NC}"
    
    # UPLANETNAME_G1 (Réserve Ğ1)
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1" 2>/dev/null)
        if [[ -n "$g1_pubkey" ]]; then
            local g1_balance=$(get_wallet_balance "$g1_pubkey")
            local g1_str=$(safe_printf "%.2f" "$g1_balance")
            echo -e "  🏛️  UPLANETNAME_G1: ${YELLOW}$g1_str Ğ1${NC} (Réserve)"
        fi
    fi
    
    # UPLANETG1PUB (Services & Cash-Flow) - Utilise G1revenue.sh pour l'historique
    if [[ -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        local services_pubkey=$(cat "$HOME/.zen/tmp/UPLANETG1PUB" 2>/dev/null)
        if [[ -n "$services_pubkey" ]]; then
            local services_balance=$(get_wallet_balance "$services_pubkey")
            local services_str=$(safe_printf "%.2f" "$services_balance")
            
            # Récupérer les données de revenu depuis G1revenue.sh (historique analysé)
            local revenue_data=$(get_revenue_data)
            if echo "$revenue_data" | jq empty 2>/dev/null && [[ "$(echo "$revenue_data" | jq -r '.total_revenue_zen // 0')" != "0" ]]; then
                local revenue_zen=$(echo "$revenue_data" | jq -r '.total_revenue_zen // 0' 2>/dev/null)
                local revenue_txcount=$(echo "$revenue_data" | jq -r '.total_transactions // 0' 2>/dev/null)
                local zen_str=$(safe_printf "%.0f" "$revenue_zen")
                echo -e "  💼 UPLANETG1PUB: ${YELLOW}$services_str Ğ1${NC} (CA: ${CYAN}$zen_str Ẑen${NC}, ${WHITE}$revenue_txcount${NC} ventes)"
            else
                local services_zen=$(calculate_zen_balance "$services_balance")
                local zen_str=$(safe_printf "%.0f" "$services_zen")
                echo -e "  💼 UPLANETG1PUB: ${YELLOW}$services_str Ğ1${NC} (${CYAN}$zen_str Ẑen${NC})"
            fi
        fi
    fi
    
    # UPLANETNAME_SOCIETY (Capital Social) - Utilise G1society.sh pour l'historique
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" ]]; then
        local society_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" 2>/dev/null)
        if [[ -n "$society_pubkey" ]]; then
            local society_balance=$(get_wallet_balance "$society_pubkey")
            local society_str=$(safe_printf "%.2f" "$society_balance")
            
            # Récupérer les données de capital social depuis G1society.sh (historique analysé)
            local society_data=$(get_society_data)
            if echo "$society_data" | jq empty 2>/dev/null && [[ "$(echo "$society_data" | jq -r '.total_outgoing_zen // 0')" != "0" ]]; then
                local society_zen=$(echo "$society_data" | jq -r '.total_outgoing_zen // 0' 2>/dev/null)
                local society_txcount=$(echo "$society_data" | jq -r '.total_transfers // 0' 2>/dev/null)
                local zen_str=$(safe_printf "%.0f" "$society_zen")
                echo -e "  ⭐ UPLANETNAME_SOCIETY: ${YELLOW}$society_str Ğ1${NC} (Parts: ${CYAN}$zen_str Ẑen${NC}, ${WHITE}$society_txcount${NC} sociétaires)"
            else
                local society_zen=$(calculate_zen_balance "$society_balance")
                local zen_str=$(safe_printf "%.0f" "$society_zen")
                echo -e "  ⭐ UPLANETNAME_SOCIETY: ${YELLOW}$society_str Ğ1${NC} (${CYAN}$zen_str Ẑen${NC})"
            fi
        fi
    fi
    
    # UPLANETNAME_CAPITAL (Immobilisations - Compte 21 - Valeur Brute)
    if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
        local capital_pubkey=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        if [[ -n "$capital_pubkey" ]]; then
            local capital_balance=$(get_wallet_balance "$capital_pubkey")
            local capital_zen=$(calculate_zen_balance "$capital_balance")
            local capital_str=$(safe_printf "%.2f" "$capital_balance")
            local zen_str=$(safe_printf "%.0f" "$capital_zen")
            
            # Get AMORTISSEMENT balance for VNC calculation
            local amort_zen=0
            if [[ -f "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" ]]; then
                local amort_pubkey=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
                if [[ -n "$amort_pubkey" ]]; then
                    local amort_balance=$(get_wallet_balance "$amort_pubkey")
                    amort_zen=$(calculate_zen_balance "$amort_balance")
                fi
            fi
            
            # Calculate Valeur Nette Comptable (VNC = CAPITAL - AMORTISSEMENT)
            local machine_value=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            if [[ -n "$machine_value" && "$machine_value" != "0" ]]; then
                local vnc=$(echo "scale=0; $capital_zen" | bc -l 2>/dev/null || echo "0")
                local depreciation_pct=$(echo "scale=0; $amort_zen * 100 / $machine_value" | bc -l 2>/dev/null || echo "0")
                echo -e "  🏭 CAPITAL (Compte 21): ${WHITE}$capital_str Ğ1${NC} (VNC: ${CYAN}$vnc Ẑen${NC}) [Brut: ${machine_value}Ẑ]"
            else
                echo -e "  🏭 CAPITAL (Compte 21): ${WHITE}$capital_str Ğ1${NC} (${CYAN}$zen_str Ẑen${NC})"
            fi
        fi
    fi
    
    # UPLANETNAME_AMORTISSEMENT (Amortissements - Compte 28 - Valeur Consommée)
    if [[ -f "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" ]]; then
        local amort_pubkey=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        if [[ -n "$amort_pubkey" ]]; then
            local amort_balance=$(get_wallet_balance "$amort_pubkey")
            local amort_zen=$(calculate_zen_balance "$amort_balance")
            local amort_str=$(safe_printf "%.2f" "$amort_balance")
            local zen_str=$(safe_printf "%.0f" "$amort_zen")
            
            local machine_value=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            if [[ -n "$machine_value" && "$machine_value" != "0" ]]; then
                local depreciation_pct=$(echo "scale=0; $amort_zen * 100 / $machine_value" | bc -l 2>/dev/null || echo "0")
                echo -e "  📉 AMORTISSEMENT (Compte 28): ${WHITE}$amort_str Ğ1${NC} (${RED}$zen_str Ẑen${NC}) [${depreciation_pct}% amorti]"
            else
                echo -e "  📉 AMORTISSEMENT (Compte 28): ${WHITE}$amort_str Ğ1${NC} (${RED}$zen_str Ẑen${NC})"
            fi
        fi
    fi
    
    # UPLANETNAME_INTRUSION (Fonds d'intrusions détectées)
    if [[ -f "$HOME/.zen/game/uplanet.INTRUSION.dunikey" ]]; then
        local intrusion_pubkey=$(cat "$HOME/.zen/game/uplanet.INTRUSION.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        if [[ -n "$intrusion_pubkey" ]]; then
            local intrusion_balance=$(get_wallet_balance "$intrusion_pubkey")
            local intrusion_zen=$(calculate_zen_balance "$intrusion_balance")
            local intrusion_str=$(safe_printf "%.2f" "$intrusion_balance")
            local zen_str=$(safe_printf "%.0f" "$intrusion_zen")
            
            # Highlight if there are intrusion funds
            if (( $(echo "$intrusion_balance > 1" | bc -l 2>/dev/null || echo 0) )); then
                echo -e "  🚨 UPLANETNAME_INTRUSION: ${RED}$intrusion_str Ğ1${NC} (${CYAN}$zen_str Ẑen${NC}) ${YELLOW}⚠️${NC}"
            else
                echo -e "  🛡️  UPLANETNAME_INTRUSION: ${GREEN}$intrusion_str Ğ1${NC} (${CYAN}$zen_str Ẑen${NC})"
            fi
        fi
    else
        echo -e "  🚨 UPLANETNAME_INTRUSION: ${RED}Non initialisé${NC} ${YELLOW}⚠️${NC}"
    fi
}

show_user_statistics() {
    echo ""
    echo -e "${CYAN}👥 STATISTIQUES UTILISATEURS:${NC}"
    
    # Compter les MULTIPASS
    local multipass_count=$(ls ~/.zen/game/nostr 2>/dev/null | grep "@" | wc -l)
    echo -e "  👥 MULTIPASS: ${WHITE}$multipass_count${NC} compte(s)"
    
    # Compter les ZEN Cards
    local zencard_count=$(ls ~/.zen/game/players 2>/dev/null | grep "@" | wc -l)
    echo -e "  🎫 ZEN Cards: ${WHITE}$zencard_count${NC} carte(s)"
    
    # Compter les sociétaires
    local societaire_count=0
    for player_dir in ~/.zen/game/players/*@*.*/; do
        if [[ -d "$player_dir" ]]; then
            if [[ -s "${player_dir}U.SOCIETY" ]] || [[ "$(basename "$player_dir")" == "$(cat ~/.zen/game/players/.current/.player 2>/dev/null)" ]]; then
                ((societaire_count++))
            fi
        fi
    done
    echo -e "  ⭐ Sociétaires: ${GREEN}$societaire_count${NC} membre(s)"
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
    
    # uSPOT/uPassport
    if ss -tlnp 2>/dev/null | grep -q ":54321 "; then
        status_parts+=("uSPOT:${GREEN}✓${NC}")
    else
        status_parts+=("uSPOT:${YELLOW}⚠${NC}")
    fi
    
    # NOSTR Relay
    if ss -tlnp 2>/dev/null | grep -q ":7777 "; then
        status_parts+=("NOSTR:${GREEN}✓${NC}")
    else
        status_parts+=("NOSTR:${YELLOW}⚠${NC}")
    fi
    
    # WireGuard (vérification optimisée)
    if check_sudo_cached && sudo -n wg show wg0 >/dev/null 2>&1; then
        local wg_peers=$(sudo -n wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
        status_parts+=("VPN:${GREEN}✓${NC}($wg_peers)")
    else
        status_parts+=("VPN:${YELLOW}⚠${NC}")
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
    
    # Vérification capitaine connecté
    local current_captain=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
    if [[ -z "$current_captain" ]]; then
        alerts+=("👤 Aucun capitaine connecté")
    fi
    
    # Vérification services critiques
    if ! pgrep ipfs >/dev/null 2>&1; then
        alerts+=("🌐 IPFS arrêté")
    fi
    
    if ! pgrep -f "12345" >/dev/null 2>&1; then
        alerts+=("🚀 API Astroport arrêtée")
    fi
    
    # Vérification portefeuilles système
    if [[ ! -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        alerts+=("💰 Portefeuille UPLANETG1PUB non configuré")
    fi
    
    # Vérification portefeuille INTRUSION
    if [[ ! -f "$HOME/.zen/game/uplanet.INTRUSION.dunikey" ]]; then
        alerts+=("🚨 Portefeuille INTRUSION non initialisé")
    else
        local intrusion_pubkey=$(cat "$HOME/.zen/game/uplanet.INTRUSION.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        if [[ -n "$intrusion_pubkey" ]]; then
            local intrusion_balance=$(get_wallet_balance "$intrusion_pubkey")
            if (( $(echo "$intrusion_balance > 1" | bc -l 2>/dev/null || echo 0) )); then
                local intrusion_str=$(safe_printf "%.2f" "$intrusion_balance")
                alerts+=("🚨 Intrusions détectées: ${intrusion_str} Ğ1 collectés")
            fi
        fi
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
    echo -e "  ${GREEN}o${NC} - 🏛️  Virements officiels (UPLANET.official.sh)"
    echo -e "  ${GREEN}z${NC} - 💰 Analyse économique (zen.sh)"
    echo -e "  ${GREEN}c${NC} - 🏴‍☠️ Changer de capitaine"
    echo -e "  ${GREEN}n${NC} - 🆕 Nouvel embarquement (captain.sh)"
    echo -e "  ${GREEN}u${NC} - 🚀 Assistant UPlanet ẐEN (uplanet_onboarding.sh)"
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
    "${TOOLS_PATH}/../12345.sh" > ~/.zen/tmp/12345.log & 
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
    if [[ -x "${TOOLS_PATH}/../RUNTIME/SWARM.discover.sh" ]]; then
        "${TOOLS_PATH}/../RUNTIME/SWARM.discover.sh" | head -20
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
        if [[ -x "${TOOLS_PATH}/VISA.print.sh" ]]; then
            "${TOOLS_PATH}/VISA.print.sh" "$current_player"
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

launch_uplanet_official() {
    echo -e "${CYAN}🏛️  Lancement des virements officiels UPLANET.official.sh...${NC}"
    echo ""
    if [[ -x "${TOOLS_PATH}/../UPLANET.official.sh" ]]; then
        "${TOOLS_PATH}/../UPLANET.official.sh"
    else
        echo -e "${RED}❌ Script UPLANET.official.sh non trouvé${NC}"
        read -p "Appuyez sur ENTRÉE pour continuer..."
    fi
}

launch_zen_manager() {
    echo -e "${CYAN}💰 Lancement de l'analyse économique zen.sh...${NC}"
    echo ""
    if [[ -x "${TOOLS_PATH}/zen.sh" ]]; then
        "${TOOLS_PATH}/zen.sh"
    else
        echo -e "${RED}❌ Script zen.sh non trouvé${NC}"
        read -p "Appuyez sur ENTRÉE pour continuer..."
    fi
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
        
        echo -e "  0. 🆕 Nouveau capitaine (captain.sh)"
        echo ""
        
        read -p "Votre choix: " captain_choice
        
        if [[ "$captain_choice" == "0" ]]; then
            echo -e "${CYAN}🆕 Lancement de captain.sh pour nouvel embarquement...${NC}"
            if [[ -x "${TOOLS_PATH}/../captain.sh" ]]; then
                "${TOOLS_PATH}/../captain.sh"
            else
                echo -e "${RED}❌ Script captain.sh non trouvé${NC}"
            fi
        elif [[ "$captain_choice" =~ ^[0-9]+$ ]] && [[ $captain_choice -le ${#players[@]} ]]; then
            local selected_player="${players[$((captain_choice-1))]}"
            echo "$selected_player" > ~/.zen/game/players/.current/.player
            echo -e "${GREEN}✅ Capitaine changé: $selected_player${NC}"
        else
            echo -e "${RED}❌ Choix invalide${NC}"
        fi
    else
        echo -e "${RED}❌ Aucun capitaine trouvé${NC}"
        echo -e "${CYAN}💡 Lancement de captain.sh pour premier embarquement...${NC}"
        if [[ -x "${TOOLS_PATH}/../captain.sh" ]]; then
            "${TOOLS_PATH}/../captain.sh"
        else
            echo -e "${RED}❌ Script captain.sh non trouvé${NC}"
        fi
    fi
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
}

launch_captain_onboarding() {
    echo -e "${CYAN}🆕 Lancement de captain.sh pour nouvel embarquement...${NC}"
    echo ""
    if [[ -x "${TOOLS_PATH}/../captain.sh" ]]; then
        "${TOOLS_PATH}/../captain.sh"
    else
        echo -e "${RED}❌ Script captain.sh non trouvé${NC}"
        read -p "Appuyez sur ENTRÉE pour continuer..."
    fi
}

launch_uplanet_onboarding() {
    echo -e "${CYAN}🚀 Lancement de l'assistant d'embarquement UPlanet ẐEN...${NC}"
    echo ""
    if [[ -x "${TOOLS_PATH}/../uplanet_onboarding.sh" ]]; then
        "${TOOLS_PATH}/../uplanet_onboarding.sh"
    else
        echo -e "${RED}❌ Script uplanet_onboarding.sh non trouvé${NC}"
        read -p "Appuyez sur ENTRÉE pour continuer..."
    fi
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
    
    echo -e "${CYAN}💰 Économie UPlanet${NC}"
    echo "  • 1 Ẑen = 0.1 G1 (monnaie libre)"
    echo "  • MULTIPASS: Compte social NOSTR"
    echo "  • ZEN Card: Identité économique"
    echo "  • Sociétaire: Membre de la coopérative"
    echo ""
    
    echo -e "${CYAN}🔧 Services principaux${NC}"
    echo "  • IPFS: Stockage décentralisé"
    echo "  • Astroport: API et orchestration"
    echo "  • uSPOT/uPassport: Services locaux"
    echo "  • NOSTR Relay: Réseau social"
    echo "  • WireGuard: VPN pour les clients"
    echo ""
    
    echo -e "${CYAN}🎯 Scripts spécialisés${NC}"
    echo "  • dashboard.sh: Vue d'ensemble (ce script)"
    echo "  • captain.sh: Embarquement nouveaux utilisateurs"
    echo "  • UPLANET.official.sh: Virements officiels automatisés"
    echo "  • zen.sh: Analyse économique et transactions manuelles"
    echo "  • command.sh: Interface principale complète"
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
            "o") launch_uplanet_official ;;
            "z") launch_zen_manager ;;
            "c") change_captain ;;
            "n") launch_captain_onboarding ;;
            "u") launch_uplanet_onboarding ;;
            "h") show_uplanet_help ;;
            
            # Menu technique (conservé mais simplifié)
            "1") 
                # Import des fonctions avancées du script original
                if [[ -f "${TOOLS_PATH}/../admin/monitor/heartbox_control.sh" ]]; then
                    source "${TOOLS_PATH}/../admin/monitor/heartbox_control.sh"
                    show_detailed_monitoring
                else
                    echo -e "${RED}❌ Script heartbox_control.sh non trouvé${NC}"
                    read -p "Appuyez sur ENTRÉE..."
                fi
                ;;
            "2") 
                echo -e "${CYAN}🛠️  Gestion technique - Fonctionnalités avancées${NC}"
                echo "Pour l'accès technique complet, utilisez:"
                echo "  ./admin/monitor/heartbox_control.sh"
                echo ""
                read -p "Appuyez sur ENTRÉE..."
                ;;
            "3")
                echo -e "${CYAN}⚙️  Configuration simplifiée${NC}"
                echo -e "Node ID: ${IPFSNODEID:-'Non configuré'}"
                echo -e "Capitaine: $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'Non configuré')"
                echo -e "Type: $(if [[ -f ~/.zen/game/secret.NODE.dunikey ]]; then echo "Y Level (Autonome)"; else echo "Standard"; fi)"
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
if [[ ! -f "${TOOLS_PATH}/my.sh" ]]; then
    echo "❌ Fichier my.sh non trouvé. Exécutez depuis le répertoire Astroport.ONE/tools/"
    exit 1
fi

# Démarrage de l'interface
clear
echo -e "${CYAN}DASHBOARD ÉCONOMIQUE UPLANET v3.0${NC}"
echo -e "${YELLOW}🏴‍☠️ Bienvenue à bord !${NC}"
sleep 2

main_loop 