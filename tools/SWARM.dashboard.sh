#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# SWARM.dashboard.sh
# Tableau de bord des abonnements et revenus SWARM
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"
################################################################################

# Vérifier le niveau Y
if [[ ! -s ~/.zen/game/id_ssh.pub ]]; then
    echo "❌ ACCÈS REFUSÉ : Niveau Y requis"
    exit 1
fi

clear
echo "🌐 TABLEAU DE BORD SWARM"
echo "========================="
echo "🏠 Node: ${IPFSNODEID}"
echo "👨‍✈️ Captain: ${CAPTAINEMAIL:-"N/A"}"
echo "📅 $(date)"
echo

# Fonction d'affichage des abonnements reçus
show_received_subscriptions() {
    echo "📨 ABONNEMENTS REÇUS (Revenus)"
    echo "==============================="
    
    local total_revenue_g1=0
    local active_count=0
    local expired_count=0
    
    if [[ ! -d ~/.zen/game/swarm_subscriptions ]]; then
        echo "ℹ️  Aucun abonnement reçu pour le moment"
        return
    fi
    
    for sub_file in ~/.zen/game/swarm_subscriptions/*.subscription; do
        [[ ! -f "$sub_file" ]] && continue
        
        source "$sub_file"
        
        local status_icon="✅"
        local status_color="\033[92m"
        local today=$(date -u +"%Y%m%d")
        
        if [[ "$EXPIRY" < "$today" ]] || [[ "$STATUS" != "ACTIVE" ]]; then
            status_icon="⏰"
            status_color="\033[91m"
            ((expired_count++))
        else
            ((active_count++))
            total_revenue_g1=$(echo "$total_revenue_g1 + $AMOUNT_G1" | bc -l)
        fi
        
        echo -e "${status_color}${status_icon} $SUBSCRIBER_NODEID\033[0m"
        echo -e "  ├─ 🔖 Service: $SERVICE_TYPE"
        echo -e "  ├─ 💰 Montant: $AMOUNT_G1 G1 ($AMOUNT_ZEN Ẑ)"
        echo -e "  ├─ ⏰ Expire: $(date -d "$EXPIRY" "+%d/%m/%Y" 2>/dev/null || echo "$EXPIRY")"
        echo -e "  └─ 📊 Statut: $STATUS"
        echo
    done
    
    echo "📊 RÉSUMÉ REVENUS:"
    echo "├─ ✅ Actifs: $active_count abonnements"
    echo "├─ ⏰ Expirés: $expired_count abonnements"
    echo "├─ 💰 Revenus mensuels: $total_revenue_g1 G1"
    echo "└─ 💎 Revenus en Ẑen: $(echo "$total_revenue_g1 * 10" | bc | cut -d '.' -f 1) Ẑ"
    echo
}

# Fonction d'affichage des abonnements émis
show_sent_subscriptions() {
    echo "📤 ABONNEMENTS ÉMIS (Dépenses)"
    echo "==============================="
    
    local total_expenses_g1=0
    local active_subs=0
    
    if [[ ! -f ~/.zen/game/subscriptions/history.txt ]]; then
        echo "ℹ️  Aucun abonnement émis pour le moment"
        return
    fi
    
    while IFS='|' read -r timestamp nodeid hostname service_type amount g1pub status; do
        [[ -z "$timestamp" ]] && continue
        
        local date_str=$(date -d "@$timestamp" "+%d/%m/%Y %H:%M" 2>/dev/null || echo "Date inconnue")
        local status_icon="✅"
        
        if [[ "$status" == "ACTIVE" ]]; then
            ((active_subs++))
            total_expenses_g1=$(echo "$total_expenses_g1 + ($amount / 10)" | bc -l)
        fi
        
        echo -e "$status_icon $hostname ($nodeid)"
        echo -e "  ├─ 🔖 Service: $service_type"
        echo -e "  ├─ 💸 Coût: $amount Ẑ ($(echo "scale=1; $amount/10" | bc) G1)"
        echo -e "  ├─ 📅 Souscrit: $date_str"
        echo -e "  └─ 🎯 G1PUB: ${g1pub:0:20}..."
        echo
    done < ~/.zen/game/subscriptions/history.txt
    
    echo "📊 RÉSUMÉ DÉPENSES:"
    echo "├─ 📤 Abonnements actifs: $active_subs"
    echo "├─ 💸 Dépenses mensuelles: $total_expenses_g1 G1"
    echo "└─ 💎 Dépenses en Ẑen: $(echo "$total_expenses_g1 * 10" | bc | cut -d '.' -f 1) Ẑ"
    echo
}

# Fonction d'affichage du bilan économique
show_economic_balance() {
    echo "💰 BILAN ÉCONOMIQUE"
    echo "==================="
    
    # Calculer les revenus des abonnements
    local monthly_revenue=0
    if [[ -d ~/.zen/game/swarm_subscriptions ]]; then
        for sub_file in ~/.zen/game/swarm_subscriptions/*.subscription; do
            [[ ! -f "$sub_file" ]] && continue
            source "$sub_file"
            
            local today=$(date -u +"%Y%m%d")
            if [[ "$EXPIRY" >= "$today" && "$STATUS" == "ACTIVE" ]]; then
                monthly_revenue=$(echo "$monthly_revenue + $AMOUNT_G1" | bc -l)
            fi
        done
    fi
    
    # Calculer les dépenses d'abonnements
    local monthly_expenses=0
    if [[ -f ~/.zen/game/subscriptions/history.txt ]]; then
        while IFS='|' read -r timestamp nodeid hostname service_type amount g1pub status; do
            [[ -z "$timestamp" || "$status" != "ACTIVE" ]] && continue
            monthly_expenses=$(echo "$monthly_expenses + ($amount / 10)" | bc -l)
        done < ~/.zen/game/subscriptions/history.txt
    fi
    
    # Récupérer la PAF et le bilan du JSON
    local json_file="$HOME/.zen/tmp/${IPFSNODEID}/12345.json"
    local paf=56
    local current_bilan=0
    if [[ -s $json_file ]]; then
        paf=$(jq -r '.PAF // 56' $json_file)
        current_bilan=$(jq -r '.BILAN // 0' $json_file)
    fi
    
    # Calculs
    local paf_monthly=$(echo "$paf" | bc)
    local net_swarm_income=$(echo "$monthly_revenue - $monthly_expenses" | bc -l)
    local total_monthly_income=$(echo "$net_swarm_income" | bc -l)
    
    # Déterminer le statut économique avec revenus SWARM
    local status_icon="🔴"
    local status_text="Déficitaire"
    local status_color="\033[91m"
    
    if [[ $(echo "$total_monthly_income >= $paf_monthly" | bc -l) -eq 1 ]]; then
        if [[ $(echo "$total_monthly_income >= ($paf_monthly * 3)" | bc -l) -eq 1 ]]; then
            status_icon="🌟"
            status_text="Excédentaire (UPlanet)"
            status_color="\033[92m"
        else
            status_icon="🟡"
            status_text="Rentable (Captain payé)"
            status_color="\033[93m"
        fi
    fi
    
    echo "📊 REVENUS MENSUELS:"
    echo "├─ 🌐 Abonnements SWARM reçus: $monthly_revenue G1"
    echo "├─ 📤 Abonnements SWARM émis: -$monthly_expenses G1"
    echo "└─ 💎 Net SWARM: $(printf "%.2f" $net_swarm_income) G1"
    echo
    echo "📊 BILAN GLOBAL:"
    echo "├─ 📊 PAF mensuelle: $paf_monthly G1"
    echo "├─ 💰 Bilan actuel: $current_bilan Ẑ"
    echo "├─ 🌐 Revenus SWARM nets: $(printf "%.2f" $total_monthly_income) G1"
    echo -e "└─ ${status_color}$status_icon Statut: $status_text\033[0m"
    echo
    
    # Projections
    if [[ $(echo "$total_monthly_income > 0" | bc -l) -eq 1 ]]; then
        local captain_share=0
        local uplanet_share=0
        
        if [[ $(echo "$total_monthly_income > $paf_monthly" | bc -l) -eq 1 ]]; then
            local surplus=$(echo "$total_monthly_income - $paf_monthly" | bc -l)
            
            if [[ $(echo "$surplus <= ($paf_monthly * 2)" | bc -l) -eq 1 ]]; then
                captain_share=$surplus
            else
                captain_share=$(echo "$paf_monthly * 2" | bc -l)
                uplanet_share=$(echo "$surplus - $captain_share" | bc -l)
            fi
        fi
        
        echo "🎯 PROJECTIONS (avec revenus SWARM):"
        echo "├─ ♥️ BOX (PAF): $paf_monthly G1"
        echo "├─ 👨‍✈️ Captain: $(printf "%.2f" $captain_share) G1"
        echo "└─ 🌍 UPlanet: $(printf "%.2f" $uplanet_share) G1"
    fi
}

# Fonction d'affichage des services disponibles
show_available_services() {
    echo "🛠️  SERVICES DISPONIBLES"
    echo "========================"
    
    local services_count=0
    
    for service_script in ~/.zen/tmp/${IPFSNODEID}/x_*.sh; do
        [[ ! -f "$service_script" ]] && continue
        
        local service_name=$(basename "$service_script")
        local service_type=${service_name#x_}
        service_type=${service_type%.sh}
        
        case $service_type in
            "ssh") echo "🔐 SSH Terminal distant" ;;
            "ollama") echo "🤖 Ollama IA (LLM)" ;;
            "comfyui") echo "🎨 ComfyUI (IA Images)" ;;
            "perplexica") echo "🔍 Perplexica (Recherche IA)" ;;
            "orpheus") echo "🎵 Orpheus (Text-to-Speech)" ;;
            *) echo "⚙️  $service_type" ;;
        esac
        ((services_count++))
    done
    
    [[ $services_count -eq 0 ]] && echo "ℹ️  Aucun service P2P actif"
    echo "📊 Total: $services_count services disponibles"
    echo
}

# Menu principal
while true; do
    show_received_subscriptions
    show_sent_subscriptions
    show_economic_balance
    show_available_services
    
    echo "🎛️  ACTIONS DISPONIBLES"
    echo "======================="
    echo "1) 🔄 Actualiser le tableau de bord"
    echo "2) 🌐 Découvrir les services SWARM"
    echo "3) ⏰ Vérifier les expirations"
    echo "4) 📋 Exporter le rapport"
    echo "5) 🚪 Quitter"
    echo
    
    read -p "Votre choix (1-5): " choice
    
    case $choice in
        1)
            clear
            echo "🔄 Actualisation..."
            ;;
        2)
            ${MY_PATH}/../RUNTIME/SWARM.services.sh
            clear
            ;;
        3)
            echo "⏰ Vérification des expirations..."
            [[ -x ~/.zen/game/swarm_check_expiry.sh ]] && ~/.zen/game/swarm_check_expiry.sh
            echo "Appuyez sur Entrée pour continuer..."
            read
            clear
            ;;
        4)
            local report_file="$HOME/.zen/tmp/swarm_report_$(date -u +%Y%m%d_%H%M%S).txt"
            {
                echo "RAPPORT SWARM - $(date)"
                echo "======================"
                show_received_subscriptions
                show_sent_subscriptions
                show_economic_balance
                show_available_services
            } > "$report_file"
            echo "📋 Rapport exporté vers: $report_file"
            echo "Appuyez sur Entrée pour continuer..."
            read
            clear
            ;;
        5)
            echo "👋 Au revoir !"
            exit 0
            ;;
        *)
            echo "❌ Choix invalide"
            sleep 2
            clear
            ;;
    esac
done 