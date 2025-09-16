#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# UPLANET.official.sh
# Script de gestion des virements officiels UPlanet
# 
# Gère deux types de virements :
# 1. LOCATAIRE : UPLANETNAME.G1 -> UPLANETNAME -> MULTIPASS (recharge de service)
# 2. SOCIÉTAIRE : UPLANETNAME.G1 -> UPLANETNAME.SOCIETY -> ZEN Card -> 3x1/3
#
# Conformité : Respecte la Constitution de l'Écosystème UPlanet ẐEN
# Sécurité : Vérification des transactions pending entre chaque transfert
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

# Configuration des montants (définis dans my.sh et .env)
# Les valeurs par défaut sont définies dans my.sh (NCARD, etc.)
# Un fichier .env peut être créé à partir de env.template pour personnaliser

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Fonctions utilitaires
################################################################################

# Fonction pour afficher l'aide
show_help() {
    echo -e "${BLUE}UPLANET.official.sh - Gestion des virements officiels UPlanet${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -l, --locataire EMAIL     Virement pour locataire (recharge MULTIPASS)"
    echo "  -s, --societaire EMAIL    Virement pour sociétaire (parts sociales)"
    echo "  -t, --type TYPE           Type de sociétaire: satellite|constellation|infrastructure"
    echo "  -i, --infrastructure      Apport capital infrastructure (CAPTAIN → NODE)"
    echo "  -m, --montant MONTANT     Montant en euros (optionnel, auto-calculé par défaut)"
    echo "  -h, --help                Affiche cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 -l user@example.com -m 20                  # Recharge MULTIPASS locataire"
    echo "  $0 -s user@example.com -t satellite           # Parts sociales satellite"
    echo "  $0 -s user@example.com -t constellation       # Parts sociales constellation"
    echo "  $0 -i -m 500                               # Apport capital infrastructure (500€)"
    echo ""
    echo "Types de sociétaires:"
    echo "  satellite     : 50€/an (sans IA)"
    echo "  constellation : 540€/3ans (avec IA)"
    echo "  infrastructure: 500€ (apport capital machine, direct vers NODE)"
}

# Fonction pour vérifier le solde d'un portefeuille avec gestion du pending
check_balance() {
    local wallet_pubkey="$1"
    local max_wait="${BLOCKCHAIN_TIMEOUT:-1200}"  # 20 minutes max par défaut
    local wait_time=0
    local interval="${VERIFICATION_INTERVAL:-60}"  # 60 secondes par défaut
    
    echo -e "${YELLOW}🔍 Vérification du solde du portefeuille: ${wallet_pubkey:0:8}...${NC}"
    
    # Récupérer le solde initial (blockchain) pour calculer le solde attendu
    local initial_balance_json=$(silkaj --json money balance "$wallet_pubkey" 2>/dev/null)
    local initial_blockchain=0
    local initial_pending=0
    
    if [[ $? -eq 0 ]]; then
        initial_blockchain=$(echo "$initial_balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
        initial_pending=$(echo "$initial_balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
        echo -e "${CYAN}📊 Solde initial - Blockchain: ${initial_blockchain} Ğ1, Pending: ${initial_pending} Ğ1${NC}"
    else
        echo -e "${RED}❌ Impossible de récupérer le solde initial${NC}"
        return 1
    fi
    
    while [[ $wait_time -lt $max_wait ]]; do
        local balance_json=$(silkaj --json money balance "$wallet_pubkey" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            local pending=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
            local total=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
            local blockchain=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
            
            if [[ "$pending" == "0" || "$pending" == "null" ]]; then
                # Calculer le solde attendu : blockchain initial - pending initial
                local expected_balance=$(echo "scale=2; $initial_blockchain - $initial_pending" | bc -l)
                local tolerance=0.01  # Tolérance de 0.01 Ğ1 pour les arrondis
                
                if (( $(echo "scale=2; $total >= ($expected_balance - $tolerance)" | bc -l) )) && \
                   (( $(echo "scale=2; $total <= ($expected_balance + $tolerance)" | bc -l) )); then
                    echo -e "${GREEN}✅ Transaction confirmée - Solde: ${total} Ğ1 (${expected_balance} Ğ1 attendus)${NC}"
                    return 0
                else
                    echo -e "${YELLOW}⏳ Transaction en cours... Solde: ${total} Ğ1, Attendu: ${expected_balance} Ğ1 (attente: ${wait_time}s)${NC}"
                fi
            else
                echo -e "${YELLOW}⏳ Transaction en cours... Pending: ${pending} Ğ1, Total: ${total} Ğ1 (attente: ${wait_time}s)${NC}"
            fi
        else
            echo -e "${YELLOW}⏳ Transaction en cours... Impossible de récupérer le solde (attente: ${wait_time}s)${NC}"
        fi
        
        sleep $interval
        wait_time=$((wait_time + interval))
    done
    
    echo -e "${RED}❌ Timeout: La transaction n'a pas été confirmée dans les 20 minutes${NC}"
    return 1
}

# Fonction pour effectuer un transfert et vérifier sa confirmation
transfer_and_verify() {
    local dunikey_file="$1"
    local to_wallet="$2"
    local amount="$3"
    local description="$4"
    
    echo -e "${BLUE}💰 Transfert: ${amount} Ğ1 vers ${to_wallet:0:8}${NC}"
    echo -e "${CYAN}📝 Description: ${description}${NC}"
    
    # Effectuer le transfert avec silkaj en utilisant le fichier dunikey
    local transfer_result
    if [[ -n "$dunikey_file" && -f "$dunikey_file" ]]; then
        transfer_result=$(silkaj --json --dunikey-file "$dunikey_file" money transfer -r "$to_wallet" -a "$amount" --reference "$description" --yes 2>/dev/null)
    else
        echo -e "${RED}❌ Fichier dunikey manquant ou invalide: $dunikey_file${NC}"
        return 1
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Transfert initié avec succès${NC}"
        
        # Attendre la confirmation sur le wallet source
        local source_pubkey=$(cat "$dunikey_file" | grep 'pub:' | cut -d ' ' -f 2)
        if [[ -n "$source_pubkey" ]]; then
            if check_balance "$source_pubkey"; then
                return 0
            else
                return 1
            fi
        else
            echo -e "${RED}❌ Impossible de récupérer la clé publique depuis le fichier dunikey${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Erreur lors du transfert${NC}"
        echo "$transfer_result"
        return 1
    fi
}

# Fonction pour calculer le montant en Ẑen basé sur le type de sociétaire
calculate_societaire_amount() {
    local type="$1"
    
    case "$type" in
        "satellite")
            echo "${ZENCARD_SATELLITE:-50}"  # 50€ = 50 Ẑen (valeur par défaut)
            ;;
        "constellation")
            echo "${ZENCARD_CONSTELLATION:-540}" # 540€ = 540 Ẑen (valeur par défaut)
            ;;
        "infrastructure")
            echo "${MACHINE_VALUE_ZEN:-500}" # 500€ = 500 Ẑen (apport capital machine)
            ;;
        *)
            echo "0"
            ;;
    esac
}

################################################################################
# Fonction principale pour virement locataire
################################################################################
process_locataire() {
    local email="$1"
    local montant_euros="${2:-$NCARD}}"
    
    echo -e "${BLUE}🏠 Traitement virement LOCATAIRE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros}€ (${montant_euros} Ẑen)${NC}"
    
    # Vérifier que les portefeuilles existent
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME.G1 non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME.G1 pour configurer"
        return 1
    fi
    
    if [[ ! -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME pour configurer"
        return 1
    fi
    
    # Récupérer les clés publiques
    local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
    local uplanet_pubkey=$(cat "$HOME/.zen/tmp/UPLANETG1PUB")
    local multipass_pubkey=$(cat ~/.zen/game/nostr/${email}/G1PUBNOSTR)
    
    echo -e "${YELLOW}🔑 Portefeuilles identifiés:${NC}"
    echo -e "  UPLANETNAME.G1: ${g1_pubkey:0:8}..."
    echo -e "  UPLANETNAME: ${uplanet_pubkey:0:8}..."
    echo -e "  MULTIPASS ${email}: ${multipass_pubkey:0:8}..."
    
    # Étape 1: UPLANETNAME.G1 -> UPLANETNAME
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME.G1 → UPLANETNAME${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$uplanet_pubkey" "$montant_euros" "Recharge locataire ${email}"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: UPLANETNAME -> MULTIPASS
    echo -e "${BLUE}📤 Étape 2: Transfert UPLANETNAME → MULTIPASS ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.dunikey" "$multipass_pubkey" "$montant_euros" "Recharge MULTIPASS locataire"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Virement locataire terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen transférés vers MULTIPASS ${email}"
    echo -e "  • Recharge de service hebdomadaire effectuée"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    
    return 0
}

################################################################################
# Fonction pour apport capital infrastructure (pas de 3x1/3)
################################################################################
process_infrastructure() {
    local email="$1"
    local montant_euros="${2:-$(calculate_societaire_amount "infrastructure")}"
    
    echo -e "${BLUE}⚙️ Traitement APPORT CAPITAL INFRASTRUCTURE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros}€ (${montant_euros} Ẑen) - DIRECT vers NODE${NC}"
    
    # Vérifier que les portefeuilles existent
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME.G1 non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME.G1 pour configurer"
        return 1
    fi
    
    # Récupérer les clés publiques
    local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
    
    # Récupérer la clé ZEN Card du capitaine
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${GREEN}✅ ZEN Card trouvée (g1pub): ${zencard_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email}/ existe${NC}"
        return 1
    fi
    
    # Récupérer la clé NODE
    local node_pubkey=""
    if [[ -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
        node_pubkey=$(cat "$HOME/.zen/game/secret.NODE.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ NODE trouvé: ${node_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Portefeuille NODE non trouvé: ~/.zen/game/secret.NODE.dunikey${NC}"
        echo -e "${CYAN}💡 Exécutez UPLANET.init.sh pour créer le portefeuille NODE${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔑 Portefeuilles identifiés:${NC}"
    echo -e "  UPLANETNAME.G1: ${g1_pubkey:0:8}..."
    echo -e "  ZEN Card ${email}: ${zencard_pubkey:0:8}..."
    echo -e "  NODE (Armateur): ${node_pubkey:0:8}..."
    
    # Étape 1: UPLANETNAME.G1 -> ZEN Card
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME.G1 → ZEN Card ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$zencard_pubkey" "$montant_euros" "Apport capital infrastructure ${email}"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: ZEN Card -> NODE (DIRECT, pas de 3x1/3)
    echo -e "${BLUE}📤 Étape 2: Transfert ZEN Card → NODE (APPORT CAPITAL)${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$node_pubkey" "$montant_euros" "Apport capital machine infrastructure"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Apport capital infrastructure terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen transférés directement au NODE"
    echo -e "  • Apport au capital (non distribuable 3x1/3)"
    echo -e "  • Valorisation infrastructure/machine enregistrée"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    echo -e "  • ✅ Cohérence avec OpenCollective UPlanet Ẑen maintenue"
    
    return 0
}

################################################################################
# Fonction principale pour virement sociétaire
################################################################################
process_societaire() {
    local email="$1"
    local type="$2"
    local montant_euros="${3:-$(calculate_societaire_amount "$type")}"
    
    # Cas spécial : apport capital infrastructure (pas de 3x1/3)
    if [[ "$type" == "infrastructure" ]]; then
        process_infrastructure "$email" "$montant_euros"
        return $?
    fi
    
    echo -e "${BLUE}👑 Traitement virement SOCIÉTAIRE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Type: ${type} - Montant: ${montant_euros}€ (${montant_euros} Ẑen)${NC}"
    
    # Vérifier que les portefeuilles existent
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME.G1 non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME.G1 pour configurer"
        return 1
    fi
    
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME.SOCIETY non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME.SOCIETY pour configurer"
        return 1
    fi
    
    # Récupérer les clés publiques
    local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
    local society_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_SOCIETY")
    
    # Récupérer la clé ZEN Card du sociétaire depuis son dossier player
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${GREEN}✅ ZEN Card trouvée (g1pub): ${zencard_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email}/ existe${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔑 Portefeuilles identifiés:${NC}"
    echo -e "  UPLANETNAME.G1: ${g1_pubkey:0:8}..."
    echo -e "  UPLANETNAME.SOCIETY: ${society_pubkey:0:8}..."
    echo -e "  ZEN Card ${email}: ${zencard_pubkey:0:8}..."
    
    # Étape 1: UPLANETNAME.G1 -> UPLANETNAME.SOCIETY
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME.G1 → UPLANETNAME.SOCIETY${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$society_pubkey" "$montant_euros" "Parts sociales ${email} ${type}"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: UPLANETNAME.SOCIETY -> ZEN Card
    echo -e "${BLUE}📤 Étape 2: Transfert UPLANETNAME.SOCIETY → ZEN Card ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.SOCIETY.dunikey" "$zencard_pubkey" "$montant_euros" "Attribution parts sociales ${type}"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    # Étape 3: Répartition 3x1/3 depuis ZEN Card
    echo -e "${BLUE}📤 Étape 3: Répartition 3x1/3 depuis ZEN Card${NC}"
    
    # Calculer les montants de répartition
    local montant_zen=$montant_euros
    local part_treasury=$(echo "scale=2; $montant_zen / 3" | bc)
    local part_rnd=$(echo "scale=2; $montant_zen / 3" | bc)
    local part_assets=$(echo "scale=2; $montant_zen - $part_treasury - $part_rnd" | bc)
    
    # Utiliser les mêmes portefeuilles que ZEN.COOPERATIVE.3x1-3.sh
    local treasury_pubkey=""
    local rnd_pubkey=""
    local assets_pubkey=""
    
    # Treasury (CASH)
    if [[ -f "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
        treasury_pubkey=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ Treasury trouvé: ${treasury_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Portefeuille Treasury non trouvé: ~/.zen/game/uplanet.CASH.dunikey${NC}"
        echo -e "${CYAN}💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs${NC}"
        return 1
    fi
    
    # R&D
    if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
        rnd_pubkey=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ R&D trouvé: ${rnd_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Portefeuille R&D non trouvé: ~/.zen/game/uplanet.RnD.dunikey${NC}"
        echo -e "${CYAN}💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs${NC}"
        return 1
    fi
    
    # Assets
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ Assets trouvé: ${assets_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Portefeuille Assets non trouvé: ~/.zen/game/uplanet.ASSETS.dunikey${NC}"
        echo -e "${CYAN}💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs${NC}"
        return 1
    fi
    
    # Transfert vers Treasury (1/3)
    echo -e "${CYAN}  📤 Treasury (1/3): ${part_treasury} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$treasury_pubkey" "$part_treasury" "Allocation Treasury sociétaire ${type}"; then
        echo -e "${RED}❌ Échec transfert Treasury${NC}"
        return 1
    fi
    
    # Transfert vers R&D (1/3)
    echo -e "${CYAN}  📤 R&D (1/3): ${part_rnd} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$rnd_pubkey" "$part_rnd" "Allocation R&D sociétaire ${type}"; then
        echo -e "${RED}❌ Échec transfert R&D${NC}"
        return 1
    fi
    
    # Transfert vers Assets (1/3)
    echo -e "${CYAN}  📤 Assets (1/3): ${part_assets} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$assets_pubkey" "$part_assets" "Allocation Assets sociétaire ${type}"; then
        echo -e "${RED}❌ Échec transfert Assets${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Virement sociétaire terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen transférés vers ZEN Card ${email}"
    echo -e "  • Parts sociales attribuées (type: ${type})"
    echo -e "  • Répartition 3x1/3 effectuée:"
    echo -e "    - Treasury: ${part_treasury} Ẑen"
    echo -e "    - R&D: ${part_rnd} Ẑen"
    echo -e "    - Assets: ${part_assets} Ẑen"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    
    return 0
}

################################################################################
# Menu interactif
################################################################################
show_menu() {
    echo -e "${BLUE}🏛️  UPLANET.official.sh - Menu de gestion des virements${NC}"
    echo ""
    echo "1. Virement LOCATAIRE (recharge MULTIPASS)"
    echo "2. Virement SOCIÉTAIRE Satellite (50€/an)"
    echo "3. Virement SOCIÉTAIRE Constellation (540€/3ans)"
    echo "4. Apport CAPITAL INFRASTRUCTURE (CAPTAIN → NODE)"
    echo "5. Quitter"
    echo ""
    read -p "Choisissez une option (1-5): " choice
    
    case $choice in
        1)
            read -p "Email du locataire: " email
            if [[ -n "$email" ]]; then
                process_locataire "$email"
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        2)
            read -p "Email du sociétaire: " email
            if [[ -n "$email" ]]; then
                process_societaire "$email" "satellite"
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        3)
            read -p "Email du sociétaire: " email
            if [[ -n "$email" ]]; then
                process_societaire "$email" "constellation"
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        4)
            if [[ -n "$CAPTAINEMAIL" ]]; then
                # Vérifier si MACHINE_VALUE_ZEN est définie, sinon la demander
                local machine_value="${MACHINE_VALUE_ZEN}"
                if [[ -z "$machine_value" ]]; then
                    read -p "Valeur de la machine en Ẑen (défaut: 500): " machine_value
                    machine_value="${machine_value:-500}"
                fi
                echo -e "${CYAN}💰 Apport capital pour: ${CAPTAINEMAIL} (${machine_value} Ẑen)${NC}"
                process_infrastructure "$CAPTAINEMAIL" "$machine_value"
            else
                echo -e "${RED}❌ CAPTAINEMAIL non défini dans l'environnement${NC}"
                echo -e "${CYAN}💡 Configurez votre email de capitaine dans my.sh${NC}"
            fi
            ;;
        5)
            echo -e "${GREEN}👋 Au revoir!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Option invalide${NC}"
            ;;
    esac
}

################################################################################
# Point d'entrée principal
################################################################################
main() {
    # Vérifier que silkaj est disponible
    if ! command -v silkaj &> /dev/null; then
        echo -e "${RED}❌ Erreur: silkaj n'est pas installé ou n'est pas dans le PATH${NC}"
        exit 1
    fi
    
    # Vérifier que jq est disponible
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ Erreur: jq n'est pas installé ou n'est pas dans le PATH${NC}"
        exit 1
    fi
    
    # Vérifier que bc est disponible
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}❌ Erreur: bc n'est pas installé ou n'est pas dans le PATH${NC}"
        exit 1
    fi
    
    # Traitement des arguments en ligne de commande
    if [[ $# -gt 0 ]]; then
        case "$1" in
            -l|--locataire)
                if [[ -n "$2" ]]; then
                    process_locataire "$2" "$3"
                else
                    echo -e "${RED}❌ Email requis pour l'option --locataire${NC}"
                    exit 1
                fi
                ;;
            -s|--societaire)
                if [[ -n "$2" ]]; then
                    local type="${4:-satellite}"
                    process_societaire "$2" "$type" "$3"
                else
                    echo -e "${RED}❌ Email requis pour l'option --societaire${NC}"
                    exit 1
                fi
                ;;
            -i|--infrastructure)
                if [[ -n "$CAPTAINEMAIL" ]]; then
                    local machine_value="${MACHINE_VALUE_ZEN:-500}"
                    echo -e "${CYAN}💰 Apport capital infrastructure: ${CAPTAINEMAIL} (${machine_value} Ẑen)${NC}"
                    process_infrastructure "$CAPTAINEMAIL" "$machine_value"
                else
                    echo -e "${RED}❌ CAPTAINEMAIL non défini dans l'environnement${NC}"
                    echo -e "${CYAN}💡 Configurez votre email de capitaine dans my.sh${NC}"
                    exit 1
                fi
                ;;
            -t|--type)
                echo -e "${YELLOW}⚠️  L'option --type doit être utilisée avec --societaire${NC}"
                exit 1
                ;;
            -m|--montant)
                echo -e "${YELLOW}⚠️  L'option --montant doit être utilisée avec --locataire ou --societaire${NC}"
                exit 1
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Option inconnue: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    else
        # Mode interactif
        show_menu
    fi
}

# Exécuter le script principal
main "$@"
