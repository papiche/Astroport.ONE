#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# UPLANET.official.sh
# Script de gestion des virements officiels UPlanet
# 
# Gère deux types de virements :
# 1. LOCATAIRE : UPLANETNAME.G1 -> UPLANETNAME -> MULTIPASS (recharge de service)
# 2. SOCIÉTAIRE : UPLANETNAME.G1 -> UPLANETNAME.SOCIETY -> ZEN Card -> 3x1/3
#
# Format des références blockchain :
# - RENTAL : "UPLANET:${UPLANETG1PUB:0:8}:RENTAL:${email}"
# - CAPITAL : "UPLANET:${UPLANETG1PUB:0:8}:CAPITAL:${email}:${IPFSNODEID}"
# - SOCIETY : "UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email}:${type}:${IPFSNODEID}"
# - TREASURY: "UPLANET:${UPLANETG1PUB:0:8}:TREASURY:${email}:${type}:${IPFSNODEID}"
# - RnD     : "UPLANET:${UPLANETG1PUB:0:8}:RnD:${email}:${type}:${IPFSNODEID}"
# - ASSETS  : "UPLANET:${UPLANETG1PUB:0:8}:ASSETS:${email}:${type}:${IPFSNODEID}"
#
# L'IPFSNODEID identifie le nœud/machine à l'origine de la transaction
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
    echo "  -r, --recovery            Mode dépannage: récupération complète SOCIETY → 3x1/3"
    echo "  --recovery-3x13           Mode dépannage: récupération partielle ZEN Card → 3x1/3"
    echo "  -h, --help                Affiche cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 -l user@example.com -m 20                  # Recharge MULTIPASS locataire"
    echo "  $0 -s user@example.com -t satellite           # Parts sociales satellite"
    echo "  $0 -s user@example.com -t constellation       # Parts sociales constellation"
    echo "  $0 -i -m 500                                  # Apport capital infrastructure (500€)"
    echo "  $0 -r                                         # Mode dépannage SOCIETY → 3x1/3"
    echo "  $0 --recovery-3x13                            # Mode dépannage ZEN Card → 3x1/3"
    echo ""
    echo "Types de sociétaires:"
    echo "  satellite     : 50€/an (sans IA)"
    echo "  constellation : 540€/3ans (avec IA)"
    echo "  infrastructure: 500€ (apport capital machine, direct vers NODE)"
}

# Fonction pour vérifier qu'il n'y a pas de transactions en cours avant de commencer
check_no_pending_transactions() {
    local wallet_pubkey="$1"
    local max_wait="${PENDING_WAIT_TIMEOUT:-1800}"  # 30 minutes max pour attendre les pending
    local wait_time=0
    local interval="${VERIFICATION_INTERVAL:-60}"  # 60 secondes par défaut
    
    echo -e "${YELLOW}🔍 Vérification qu'il n'y a pas de transactions en cours: ${wallet_pubkey:0:8}...${NC}"
    
    while [[ $wait_time -lt $max_wait ]]; do
        local balance_json=$(silkaj --json money balance "$wallet_pubkey" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            # silkaj retourne les montants en centimes, il faut diviser par 100
            local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
            local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
            local blockchain_centimes=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
            
            # Valider les valeurs avant de les passer à bc
            [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
            [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
            [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
            
            local pending=$(echo "scale=2; $pending_centimes / 100" | bc -l)
            local total=$(echo "scale=2; $total_centimes / 100" | bc -l)
            local blockchain=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
            
            if [[ "$pending" == "0" || "$pending" == "null" || "$pending" == "0.00" ]]; then
                # Aucune transaction en cours
                echo -e "${GREEN}✅ Aucune transaction en cours - Solde stable: ${total} Ğ1${NC}"
                return 0
            else
                echo -e "${YELLOW}⏳ Transactions en cours... Pending: ${pending} Ğ1, Total: ${total} Ğ1 (attente: ${wait_time}s)${NC}"
            fi
        else
            echo -e "${YELLOW}⏳ Vérification en cours... Impossible de récupérer le solde (attente: ${wait_time}s)${NC}"
        fi
        
        sleep $interval
        wait_time=$((wait_time + interval))
    done
    
    echo -e "${RED}❌ Timeout: Des transactions sont encore en cours après ${max_wait} secondes${NC}"
    echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
    return 1
}

# Fonction pour vérifier le solde d'un portefeuille avec gestion du pending
check_balance() {
    local wallet_pubkey="$1"
    local max_wait="${BLOCKCHAIN_TIMEOUT:-2400}"  # 40 minutes max par défaut
    local wait_time=0
    local interval="${VERIFICATION_INTERVAL:-60}"  # 60 secondes par défaut
    
    echo -e "${YELLOW}🔍 Vérification du solde du portefeuille: ${wallet_pubkey:0:8}...${NC}"
    
    # Récupérer le solde initial (blockchain) pour calculer le solde attendu
    local initial_balance_json=$(silkaj --json money balance "$wallet_pubkey" 2>/dev/null)
    local initial_blockchain=0
    local initial_pending=0
    
    if [[ $? -eq 0 ]]; then
        # silkaj retourne les montants en centimes, il faut diviser par 100
        local initial_blockchain_centimes=$(echo "$initial_balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
        local initial_pending_centimes=$(echo "$initial_balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
        
        # Valider les valeurs avant de les passer à bc
        [[ -z "$initial_blockchain_centimes" || "$initial_blockchain_centimes" == "null" ]] && initial_blockchain_centimes="0"
        [[ -z "$initial_pending_centimes" || "$initial_pending_centimes" == "null" ]] && initial_pending_centimes="0"
        
        initial_blockchain=$(echo "scale=2; $initial_blockchain_centimes / 100" | bc -l)
        initial_pending=$(echo "scale=2; $initial_pending_centimes / 100" | bc -l)
        echo -e "${CYAN}📊 Solde initial - Blockchain: ${initial_blockchain} Ğ1, Pending: ${initial_pending} Ğ1${NC}"
    else
        echo -e "${RED}❌ Impossible de récupérer le solde initial${NC}"
        return 1
    fi
    
    while [[ $wait_time -lt $max_wait ]]; do
        local balance_json=$(silkaj --json money balance "$wallet_pubkey" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            # silkaj retourne les montants en centimes, il faut diviser par 100
            local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
            local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
            local blockchain_centimes=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
            
            # Valider les valeurs avant de les passer à bc
            [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
            [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
            [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
            
            local pending=$(echo "scale=2; $pending_centimes / 100" | bc -l)
            local total=$(echo "scale=2; $total_centimes / 100" | bc -l)
            local blockchain=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
            
            if [[ "$pending" == "0" || "$pending" == "null" || "$pending" == "0.00" ]]; then
                # Quand pending = 0, la transaction est confirmée
                # Le solde total devrait être stable
                echo -e "${GREEN}✅ Transaction confirmée - Solde: ${total} Ğ1${NC}"
                return 0
            else
                echo -e "${YELLOW}⏳ Transaction en cours... Pending: ${pending} Ğ1, Total: ${total} Ğ1 (attente: ${wait_time}s)${NC}"
            fi
        else
            echo -e "${YELLOW}⏳ Transaction en cours... Impossible de récupérer le solde (attente: ${wait_time}s)${NC}"
        fi
        
        sleep $interval
        wait_time=$((wait_time + interval))
    done
    
    echo -e "${RED}❌ Timeout: La transaction n'a pas été confirmée dans les 40 minutes${NC}"
    
    # Envoyer une alerte de timeout
    send_alert "BLOCKCHAIN_TIMEOUT" "$USER_EMAIL" "$TRANSACTION_TYPE" "$TRANSACTION_AMOUNT" "$CURRENT_STEP" "Transaction timeout after ${max_wait} seconds. Wallet: ${wallet_pubkey:0:8}..."
    
    return 1
}

# Fonction pour convertir Ẑen en Ğ1
# Taux standard : 1Ẑ = 0.1Ğ1 (ou 10Ẑ = 1Ğ1)
# Note : Cette fonction convertit pour les transactions blockchain
# L'historique déduit automatiquement 1Ğ1 de primo-transaction à la lecture
# Exemple : 50Ẑ à transférer = 5Ğ1 sur blockchain (sans 1Ğ1 primo qui est déjà déduit)
zen_to_g1() {
    local zen_amount="$1"
    
    # Valider que l'entrée est un nombre
    if [[ -z "$zen_amount" ]] || ! [[ "$zen_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "0"
        return 1
    fi
    
    echo "scale=2; $zen_amount / 10" | bc -l
}

# Note: Les mises à jour DID sont maintenant gérées directement par did_manager_nostr.sh
# qui publie sur Nostr et inclut automatiquement la création des fichiers U.SOCIETY pour les sociétaires

# Fonction pour envoyer une alerte par email au CAPTAINEMAIL
send_alert() {
    local alert_type="$1"
    local email="$2"
    local type="$3"
    local montant="$4"
    local step="$5"
    local error_details="$6"
    
    # Vérifier que CAPTAINEMAIL est défini
    if [[ -z "$CAPTAINEMAIL" ]]; then
        echo -e "${YELLOW}⚠️  CAPTAINEMAIL non défini, impossible d'envoyer l'alerte${NC}"
        return 1
    fi
    
    # Créer le fichier d'alerte HTML
    local alert_file="$HOME/.zen/tmp/uplanet_alert_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$alert_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>🚨 UPLANET Transaction Alert</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .alert { background-color: #ffebee; border-left: 5px solid #f44336; padding: 15px; margin: 10px 0; }
        .info { background-color: #e3f2fd; border-left: 5px solid #2196f3; padding: 15px; margin: 10px 0; }
        .details { background-color: #f5f5f5; padding: 10px; border-radius: 5px; font-family: monospace; }
        h1 { color: #f44336; }
        h2 { color: #1976d2; }
    </style>
</head>
<body>
    <h1>🚨 ALERTE TRANSACTION UPLANET</h1>
    
    <div class="alert">
        <h2>Échec de Transaction</h2>
        <p><strong>Type d'alerte:</strong> ${alert_type}</p>
        <p><strong>Date/Heure:</strong> $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
    </div>
    
    <div class="info">
        <h2>Détails de la Transaction</h2>
        <p><strong>Email utilisateur:</strong> ${email}</p>
        <p><strong>Type de virement:</strong> ${type}</p>
        <p><strong>Montant:</strong> ${montant} Ẑen ($(zen_to_g1 "$montant") Ğ1)</p>
        <p><strong>Étape échouée:</strong> ${step}</p>
    </div>
    
    <div class="details">
        <h2>Détails de l'Erreur</h2>
        <pre>${error_details}</pre>
    </div>
    
    <div class="info">
        <h2>Actions Recommandées</h2>
        <ul>
            <li>Vérifier la connectivité blockchain</li>
            <li>Contrôler les soldes des portefeuilles intermédiaires</li>
            <li>Reprendre manuellement la transaction si nécessaire</li>
            <li>Contacter l'utilisateur: ${email}</li>
        </ul>
    </div>
    
    <hr>
    <p><small>Alerte générée automatiquement par UPLANET.official.sh</small></p>
</body>
</html>
EOF
    
    # Envoyer l'alerte via mailjet.sh
    echo -e "${YELLOW}📧 Envoi d'alerte à ${CAPTAINEMAIL}...${NC}"
    if "${MY_PATH}/tools/mailjet.sh" "$CAPTAINEMAIL" "$alert_file" "🚨 UPLANET Transaction Failed - ${alert_type}"; then
        echo -e "${GREEN}✅ Alerte envoyée avec succès à ${CAPTAINEMAIL}${NC}"
        # Garder le fichier d'alerte pour les logs
        mkdir -p "$HOME/.zen/tmp/alerts/"
        mv "$alert_file" "$HOME/.zen/tmp/alerts/"
        return 0
    else
        echo -e "${RED}❌ Échec de l'envoi d'alerte à ${CAPTAINEMAIL}${NC}"
        return 1
    fi
}

# Fonction pour effectuer un transfert et vérifier sa confirmation
transfer_and_verify() {
    local dunikey_file="$1"
    local to_wallet="$2"
    local zen_amount="$3"
    local description="$4"
    local user_email="$5"
    local transaction_type="$6"
    local step_name="$7"
    
    # Convertir Ẑen en Ğ1 (1 Ẑen = 0.1 Ğ1)
    local g1_amount=$(zen_to_g1 "$zen_amount")
    
    echo -e "${BLUE}💰 Transfert: ${zen_amount} Ẑen (${g1_amount} Ğ1) vers ${to_wallet:0:8}${NC}"
    echo -e "${CYAN}📝 Description: ${description}${NC}"
    
    # Effectuer le transfert avec silkaj en utilisant le fichier dunikey
    local transfer_result
    if [[ -n "$dunikey_file" && -f "$dunikey_file" ]]; then
        transfer_result=$(silkaj --json --dunikey-file "$dunikey_file" money transfer -r "$to_wallet" -a "$g1_amount" --reference "$description" --yes 2>/dev/null)
    else
        echo -e "${RED}❌ Fichier dunikey manquant ou invalide: $dunikey_file${NC}"
        send_alert "DUNIKEY_ERROR" "$user_email" "$transaction_type" "$zen_amount" "$step_name" "Fichier dunikey manquant ou invalide: $dunikey_file"
        return 1
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Transfert initié avec succès${NC}"
        
        # Attendre la confirmation sur le wallet source
        local source_pubkey=$(cat "$dunikey_file" | grep 'pub:' | cut -d ' ' -f 2)
        if [[ -n "$source_pubkey" ]]; then
            # Définir les variables globales pour check_balance
            export USER_EMAIL="$user_email"
            export TRANSACTION_TYPE="$transaction_type"
            export TRANSACTION_AMOUNT="$zen_amount"
            export CURRENT_STEP="$step_name"
            
            if check_balance "$source_pubkey"; then
                return 0
            else
                return 1
            fi
        else
            echo -e "${RED}❌ Impossible de récupérer la clé publique depuis le fichier dunikey${NC}"
            send_alert "PUBKEY_ERROR" "$user_email" "$transaction_type" "$zen_amount" "$step_name" "Impossible de récupérer la clé publique depuis: $dunikey_file"
            return 1
        fi
    else
        echo -e "${RED}❌ Erreur lors du transfert${NC}"
        echo "$transfer_result"
        send_alert "TRANSFER_ERROR" "$user_email" "$transaction_type" "$zen_amount" "$step_name" "Erreur silkaj: $transfer_result"
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
    local montant_euros="${2:-${NCARD:-50}}"
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 50)${NC}"
        return 1
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}🏠 Traitement virement LOCATAIRE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1${NC}"
    
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
    
    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$g1_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Étape 1: UPLANETNAME.G1 -> UPLANETNAME
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME.G1 → UPLANETNAME${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$uplanet_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:RENTAL:${email}" "$email" "LOCATAIRE" "Étape 1: G1→UPLANET"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: UPLANETNAME -> MULTIPASS
    echo -e "${BLUE}📤 Étape 2: Transfert UPLANETNAME → MULTIPASS ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.dunikey" "$multipass_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:RENTAL:${email}" "$email" "LOCATAIRE" "Étape 2: UPLANET→MULTIPASS"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Virement locataire terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen (${montant_g1} Ğ1) transférés vers MULTIPASS ${email}"
    echo -e "  • Recharge de service hebdomadaire effectuée"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    
    # Mettre à jour le document DID avec les nouvelles capacités
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "LOCATAIRE" "$montant_euros" "$montant_g1"
    
    return 0
}

################################################################################
# Fonction pour apport capital infrastructure (pas de 3x1/3)
################################################################################
process_infrastructure() {
    local email="$1"
    local montant_euros="${2:-$(calculate_societaire_amount "infrastructure")}"
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 500)${NC}"
        return 1
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}⚙️ Traitement APPORT CAPITAL INFRASTRUCTURE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1 - DIRECT vers NODE${NC}"
    
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
    
    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$g1_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Étape 1: UPLANETNAME.G1 -> ZEN Card
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME.G1 → ZEN Card ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$zencard_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:CAPITAL:${email}:${IPFSNODEID}" "$email" "INFRASTRUCTURE" "Étape 1: G1→ZENCARD"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: ZEN Card -> NODE (DIRECT, pas de 3x1/3)
    echo -e "${BLUE}📤 Étape 2: Transfert ZEN Card → NODE (APPORT CAPITAL)${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$node_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:CAPITAL:${email}:${IPFSNODEID}" "$email" "INFRASTRUCTURE" "Étape 2: ZENCARD→NODE"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Apport capital infrastructure terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen (${montant_g1} Ğ1) transférés directement au NODE"
    echo -e "  • Apport au capital (non distribuable 3x1/3)"
    echo -e "  • Valorisation infrastructure/machine enregistrée"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    echo -e "  • ✅ Cohérence avec OpenCollective UPlanet Ẑen maintenue"
    
    # Mettre à jour le document DID avec le statut contributeur infrastructure
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "INFRASTRUCTURE" "$montant_euros" "$montant_g1"
    
    return 0
}

################################################################################
# Fonction principale pour virement sociétaire
################################################################################
process_societaire() {
    local email="$1"
    local type="$2"
    local montant_euros="${3:-$(calculate_societaire_amount "$type")}"
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 50 pour satellite, 540 pour constellation)${NC}"
        return 1
    fi
    
    # Cas spécial : apport capital infrastructure (pas de 3x1/3)
    if [[ "$type" == "infrastructure" ]]; then
        process_infrastructure "$email" "$montant_euros"
        return $?
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}👑 Traitement virement SOCIÉTAIRE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Type: ${type} - Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1${NC}"
    
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
    
    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$g1_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Étape 1: UPLANETNAME.G1 -> UPLANETNAME.SOCIETY
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME.G1 → UPLANETNAME.SOCIETY${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$society_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 1: G1→SOCIETY"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: UPLANETNAME.SOCIETY -> ZEN Card
    echo -e "${BLUE}📤 Étape 2: Transfert UPLANETNAME.SOCIETY → ZEN Card ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.SOCIETY.dunikey" "$zencard_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 2: SOCIETY→ZENCARD"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    # Étape 3: Répartition 3x1/3 depuis ZEN Card
    echo -e "${BLUE}📤 Étape 3: Répartition 3x1/3 depuis ZEN Card${NC}"
    
    # Calculer les montants de répartition (en Ẑen pour l'affichage, en Ğ1 pour les transferts)
    local montant_zen=$montant_euros
    local part_treasury_zen=$(echo "scale=2; $montant_zen / 3" | bc)
    local part_rnd_zen=$(echo "scale=2; $montant_zen / 3" | bc)
    local part_assets_zen=$(echo "scale=2; $montant_zen - $part_treasury_zen - $part_rnd_zen" | bc)
    
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
    echo -e "${CYAN}  📤 Treasury (1/3): ${part_treasury_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$treasury_pubkey" "$part_treasury_zen" "UPLANET:${UPLANETG1PUB:0:8}:TREASURY:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 3a: ZENCARD→TREASURY"; then
        echo -e "${RED}❌ Échec transfert Treasury${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution Treasury
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "TREASURY_CONTRIBUTION" "$part_treasury_zen" "$(zen_to_g1 "$part_treasury_zen")"
    
    # Transfert vers R&D (1/3)
    echo -e "${CYAN}  📤 R&D (1/3): ${part_rnd_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$rnd_pubkey" "$part_rnd_zen" "UPLANET:${UPLANETG1PUB:0:8}:RnD:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 3b: ZENCARD→RND"; then
        echo -e "${RED}❌ Échec transfert R&D${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution R&D
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "RND_CONTRIBUTION" "$part_rnd_zen" "$(zen_to_g1 "$part_rnd_zen")"
    
    # Transfert vers Assets (1/3)
    echo -e "${CYAN}  📤 Assets (1/3): ${part_assets_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$assets_pubkey" "$part_assets_zen" "UPLANET:${UPLANETG1PUB:0:8}:ASSETS:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 3c: ZENCARD→ASSETS"; then
        echo -e "${RED}❌ Échec transfert Assets${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution Assets
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "ASSETS_CONTRIBUTION" "$part_assets_zen" "$(zen_to_g1 "$part_assets_zen")"
    
    echo -e "${GREEN}🎉 Virement sociétaire terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen transférés vers ZEN Card ${email}"
    echo -e "  • Parts sociales attribuées (type: ${type})"
    echo -e "  • Répartition 3x1/3 effectuée:"
    echo -e "    - Treasury: ${part_treasury_zen} Ẑen"
    echo -e "    - R&D: ${part_rnd_zen} Ẑen"
    echo -e "    - Assets: ${part_assets_zen} Ẑen"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    
    # Mettre à jour le document DID avec le statut de sociétaire
    local contract_type="SOCIETAIRE_${type^^}"
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "$contract_type" "$montant_euros" "$montant_g1"
    
    # Validate France Connect compliance for ZEN Card holders (KYC verified)
    # Check if user has WoT verification (0.01Ğ1 transaction from Duniter forgeron)
    local wot_verified=false
    if [[ -f "$HOME/.zen/tmp/coucou/${zencard_pubkey}.2nd" ]]; then
        wot_verified=true
        echo -e "${GREEN}✅ WoT verification detected (KYC completed)${NC}"
    fi
    
    # Only validate France Connect for French users with KYC verification
    if [[ "$wot_verified" == "true" ]]; then
        local user_lang=$(cat "$HOME/.zen/game/nostr/${email}/LANG" 2>/dev/null || echo "fr")
        if [[ "$user_lang" == "fr" ]]; then
            echo -e "${CYAN}🇫🇷 Validating France Connect compliance for KYC-verified French user...${NC}"
            "${MY_PATH}/tools/did_manager_nostr.sh" validate-france-connect "$email"
        fi
    else
        echo -e "${YELLOW}⚠️  France Connect validation skipped - KYC verification required (WoT transaction)${NC}"
    fi
    
    return 0
}

################################################################################
# Fonction de dépannage pour récupération manuelle depuis SOCIETY
# Flux correct: SOCIETY → ZEN Card → 3x1/3 (TREASURY, RnD, ASSETS)
################################################################################
process_recovery() {
    echo -e "${YELLOW}🔧 MODE DÉPANNAGE - Récupération manuelle depuis SOCIETY${NC}"
    echo -e "${CYAN}📋 Flux: SOCIETY → ZEN Card → 3x1/3 (TREASURY, RnD, ASSETS)${NC}"
    echo ""
    
    # Vérifier que le portefeuille SOCIETY existe
    if [[ ! -f "$HOME/.zen/game/uplanet.SOCIETY.dunikey" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME.SOCIETY non trouvé${NC}"
        echo -e "${CYAN}💡 Fichier attendu: ~/.zen/game/uplanet.SOCIETY.dunikey${NC}"
        return 1
    fi
    
    # Récupérer la clé publique SOCIETY
    local society_pubkey=$(cat "$HOME/.zen/game/uplanet.SOCIETY.dunikey" | grep "pub:" | cut -d ' ' -f 2)
    if [[ -z "$society_pubkey" ]]; then
        echo -e "${RED}❌ Impossible de lire la clé publique SOCIETY${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔑 Wallet SOCIETY: ${society_pubkey:0:8}...${NC}"
    echo ""
    
    # Afficher le solde du wallet SOCIETY
    echo -e "${YELLOW}📊 Récupération du solde SOCIETY...${NC}"
    local balance_json=$(silkaj --json money balance "$society_pubkey" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Impossible de récupérer le solde du wallet SOCIETY${NC}"
        return 1
    fi
    
    # Extraire les montants (en centimes, convertir en Ğ1)
    local blockchain_centimes=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
    local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
    local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
    
    # Valider les valeurs
    [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
    [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
    [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
    
    local blockchain_g1=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
    local pending_g1=$(echo "scale=2; $pending_centimes / 100" | bc -l)
    local total_g1=$(echo "scale=2; $total_centimes / 100" | bc -l)
    
    # Convertir en Ẑen (1 Ğ1 = 10 Ẑen)
    local blockchain_zen=$(echo "scale=2; $blockchain_g1 * 10" | bc -l)
    local pending_zen=$(echo "scale=2; $pending_g1 * 10" | bc -l)
    local total_zen=$(echo "scale=2; $total_g1 * 10" | bc -l)
    
    echo -e "${GREEN}✅ Solde du wallet SOCIETY:${NC}"
    echo -e "  • Blockchain: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)"
    echo -e "  • Pending: ${pending_g1} Ğ1 (${pending_zen} Ẑen)"
    echo -e "  • Total: ${total_g1} Ğ1 (${total_zen} Ẑen)"
    echo ""
    
    # Vérifier qu'il y a des fonds disponibles
    if [[ $(echo "$blockchain_g1 <= 0" | bc -l) -eq 1 ]]; then
        echo -e "${YELLOW}⚠️  Aucun fonds disponible dans le wallet SOCIETY${NC}"
        return 0
    fi
    
    # Demander l'email du sociétaire
    read -p "Email du sociétaire: " email_ref
    if [[ -z "$email_ref" ]]; then
        echo -e "${RED}❌ Email requis${NC}"
        return 1
    fi
    
    # Récupérer la ZEN Card du sociétaire
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email_ref}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email_ref}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${GREEN}✅ ZEN Card trouvée (g1pub): ${zencard_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email_ref}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email_ref}/ existe${NC}"
        return 1
    fi
    
    # Vérifier les portefeuilles 3x1/3
    local treasury_pubkey=""
    local rnd_pubkey=""
    local assets_pubkey=""
    
    if [[ -f "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
        treasury_pubkey=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ Treasury trouvé: ${treasury_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Wallet TREASURY non trouvé: ~/.zen/game/uplanet.CASH.dunikey${NC}"
        return 1
    fi
    
    if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
        rnd_pubkey=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ R&D trouvé: ${rnd_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Wallet R&D non trouvé: ~/.zen/game/uplanet.RnD.dunikey${NC}"
        return 1
    fi
    
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ Assets trouvé: ${assets_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Wallet ASSETS non trouvé: ~/.zen/game/uplanet.ASSETS.dunikey${NC}"
        return 1
    fi
    
    echo ""
    
    # Demander le montant à transférer
    echo -e "${YELLOW}💰 Montant disponible dans SOCIETY: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)${NC}"
    read -p "Montant à transférer en Ẑen (ou 'max' pour tout transférer): " amount_input
    
    local zen_amount=""
    if [[ "$amount_input" == "max" ]]; then
        zen_amount="$blockchain_zen"
        echo -e "${CYAN}💸 Transfert de tout le solde disponible: ${zen_amount} Ẑen${NC}"
    else
        # Valider que c'est un nombre
        if [[ ! "$amount_input" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            echo -e "${RED}❌ Montant invalide (nombre ou 'max' requis)${NC}"
            return 1
        fi
        zen_amount="$amount_input"
        
        # Vérifier que le montant ne dépasse pas le solde
        if [[ $(echo "$zen_amount > $blockchain_zen" | bc -l) -eq 1 ]]; then
            echo -e "${RED}❌ Montant demandé (${zen_amount} Ẑen) supérieur au solde (${blockchain_zen} Ẑen)${NC}"
            return 1
        fi
    fi
    
    local g1_amount=$(zen_to_g1 "$zen_amount")
    
    # Demander le type pour la référence
    read -p "Type de sociétaire (satellite/constellation): " type_ref
    type_ref="${type_ref:-satellite}"
    
    # Calculer les montants 3x1/3
    local part_treasury_zen=$(echo "scale=2; $zen_amount / 3" | bc)
    local part_rnd_zen=$(echo "scale=2; $zen_amount / 3" | bc)
    local part_assets_zen=$(echo "scale=2; $zen_amount - $part_treasury_zen - $part_rnd_zen" | bc)
    
    echo ""
    echo -e "${YELLOW}📋 Récapitulatif de l'opération:${NC}"
    echo -e "  • Étape 1: SOCIETY → ZEN Card ${email_ref}: ${zen_amount} Ẑen (${g1_amount} Ğ1)"
    echo -e "  • Étape 2: ZEN Card → 3x1/3:"
    echo -e "    - Treasury: ${part_treasury_zen} Ẑen"
    echo -e "    - R&D: ${part_rnd_zen} Ẑen"
    echo -e "    - Assets: ${part_assets_zen} Ẑen"
    echo ""
    read -p "Confirmer le transfert? (oui/non): " confirm
    
    if [[ "$confirm" != "oui" ]]; then
        echo -e "${YELLOW}🚫 Transfert annulé${NC}"
        return 0
    fi
    
    # ÉTAPE 1: SOCIETY → ZEN Card
    echo ""
    echo -e "${BLUE}📤 Étape 1: Transfert SOCIETY → ZEN Card ${email_ref}${NC}"
    local reference_society="UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email_ref}:${type_ref}:${IPFSNODEID}"
    
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.SOCIETY.dunikey" "$zencard_pubkey" "$zen_amount" "$reference_society" "$email_ref" "RECOVERY_SOCIETY" "Recovery: SOCIETY→ZENCARD"; then
        echo -e "${RED}❌ Échec de l'étape 1 (SOCIETY → ZEN Card)${NC}"
        return 1
    fi
    
    # ÉTAPE 2: ZEN Card → 3x1/3
    echo -e "${BLUE}📤 Étape 2: Répartition 3x1/3 depuis ZEN Card${NC}"
    
    # Transfert vers Treasury (1/3)
    echo -e "${CYAN}  📤 Treasury (1/3): ${part_treasury_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$treasury_pubkey" "$part_treasury_zen" "UPLANET:${UPLANETG1PUB:0:8}:TREASURY:${email_ref}:${type_ref}:${IPFSNODEID}" "$email_ref" "RECOVERY_TREASURY" "Recovery: ZENCARD→TREASURY"; then
        echo -e "${RED}❌ Échec transfert Treasury${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution Treasury
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "TREASURY_CONTRIBUTION" "$part_treasury_zen" "$(zen_to_g1 "$part_treasury_zen")"
    
    # Transfert vers R&D (1/3)
    echo -e "${CYAN}  📤 R&D (1/3): ${part_rnd_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$rnd_pubkey" "$part_rnd_zen" "UPLANET:${UPLANETG1PUB:0:8}:RnD:${email_ref}:${type_ref}:${IPFSNODEID}" "$email_ref" "RECOVERY_RND" "Recovery: ZENCARD→RND"; then
        echo -e "${RED}❌ Échec transfert R&D${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution R&D
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "RND_CONTRIBUTION" "$part_rnd_zen" "$(zen_to_g1 "$part_rnd_zen")"
    
    # Transfert vers Assets (1/3)
    echo -e "${CYAN}  📤 Assets (1/3): ${part_assets_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$assets_pubkey" "$part_assets_zen" "UPLANET:${UPLANETG1PUB:0:8}:ASSETS:${email_ref}:${type_ref}:${IPFSNODEID}" "$email_ref" "RECOVERY_ASSETS" "Recovery: ZENCARD→ASSETS"; then
        echo -e "${RED}❌ Échec transfert Assets${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution Assets
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "ASSETS_CONTRIBUTION" "$part_assets_zen" "$(zen_to_g1 "$part_assets_zen")"
    
    echo ""
    echo -e "${GREEN}🎉 Transfert de récupération terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${zen_amount} Ẑen (${g1_amount} Ğ1) transférés de SOCIETY vers ZEN Card ${email_ref}"
    echo -e "  • Répartition 3x1/3 effectuée:"
    echo -e "    - Treasury: ${part_treasury_zen} Ẑen"
    echo -e "    - R&D: ${part_rnd_zen} Ẑen"
    echo -e "    - Assets: ${part_assets_zen} Ẑen"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    echo ""
    
    # Afficher le nouveau solde SOCIETY
    echo -e "${YELLOW}📊 Nouveau solde du wallet SOCIETY...${NC}"
    sleep 2
    local new_balance_json=$(silkaj --json money balance "$society_pubkey" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local new_blockchain_centimes=$(echo "$new_balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
        [[ -z "$new_blockchain_centimes" || "$new_blockchain_centimes" == "null" ]] && new_blockchain_centimes="0"
        local new_blockchain_g1=$(echo "scale=2; $new_blockchain_centimes / 100" | bc -l)
        local new_blockchain_zen=$(echo "scale=2; $new_blockchain_g1 * 10" | bc -l)
        echo -e "${GREEN}✅ Nouveau solde SOCIETY: ${new_blockchain_g1} Ğ1 (${new_blockchain_zen} Ẑen)${NC}"
    fi
    
    # Mettre à jour le document DID avec le statut de sociétaire
    local contract_type="SOCIETAIRE_${type_ref^^}"
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "$contract_type" "$zen_amount" "$g1_amount"
    
    return 0
}

################################################################################
# Fonction de dépannage pour refaire un transfert ZEN Card → 3x1/3
# Cas d'usage: la deuxième étape a échoué partiellement
################################################################################
process_recovery_3x13() {
    echo -e "${YELLOW}🔧 MODE DÉPANNAGE - Transfert ZEN Card → 3x1/3${NC}"
    echo -e "${CYAN}📋 Permet de refaire un transfert depuis la ZEN Card d'un player vers TREASURY/RnD/ASSETS${NC}"
    echo ""
    
    # Demander l'email du player
    read -p "Email du sociétaire: " email_ref
    if [[ -z "$email_ref" ]]; then
        echo -e "${RED}❌ Email requis${NC}"
        return 1
    fi
    
    # Récupérer la ZEN Card du player
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email_ref}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email_ref}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${YELLOW}⚠️  ZEN Card trouvée (g1pub uniquement): ${zencard_pubkey:0:8}...${NC}"
        echo -e "${YELLOW}⚠️  Le fichier secret.dunikey est nécessaire pour effectuer le transfert${NC}"
        return 1
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email_ref}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email_ref}/ existe${NC}"
        return 1
    fi
    
    # Afficher le solde de la ZEN Card
    echo ""
    echo -e "${YELLOW}📊 Récupération du solde de la ZEN Card...${NC}"
    local balance_json=$(silkaj --json money balance "$zencard_pubkey" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Impossible de récupérer le solde de la ZEN Card${NC}"
        return 1
    fi
    
    # Extraire les montants (en centimes, convertir en Ğ1)
    local blockchain_centimes=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
    local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
    local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
    
    # Valider les valeurs
    [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
    [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
    [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
    
    local blockchain_g1=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
    local pending_g1=$(echo "scale=2; $pending_centimes / 100" | bc -l)
    local total_g1=$(echo "scale=2; $total_centimes / 100" | bc -l)
    
    # Convertir en Ẑen (1 Ğ1 = 10 Ẑen)
    local blockchain_zen=$(echo "scale=2; $blockchain_g1 * 10" | bc -l)
    local pending_zen=$(echo "scale=2; $pending_g1 * 10" | bc -l)
    local total_zen=$(echo "scale=2; $total_g1 * 10" | bc -l)
    
    echo -e "${GREEN}✅ Solde de la ZEN Card ${email_ref}:${NC}"
    echo -e "  • Blockchain: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)"
    echo -e "  • Pending: ${pending_g1} Ğ1 (${pending_zen} Ẑen)"
    echo -e "  • Total: ${total_g1} Ğ1 (${total_zen} Ẑen)"
    echo ""
    
    # Vérifier qu'il y a des fonds disponibles
    if [[ $(echo "$blockchain_g1 <= 1.0" | bc -l) -eq 1 ]]; then
        echo -e "${YELLOW}⚠️  Solde insuffisant dans la ZEN Card (≤ 1Ğ1)${NC}"
        echo -e "${CYAN}💡 Il faut au moins > 1Ğ1 pour effectuer un transfert${NC}"
        return 0
    fi
    
    # Menu de sélection du wallet 3x1/3 destination
    echo -e "${BLUE}📋 Sélectionnez le portefeuille de destination:${NC}"
    echo "1. TREASURY (CASH)"
    echo "2. R&D"
    echo "3. ASSETS"
    echo "4. Annuler"
    echo ""
    read -p "Votre choix (1-4): " wallet_choice
    
    local dest_wallet=""
    local dest_name=""
    local dest_type=""
    local did_contribution_type=""
    
    case $wallet_choice in
        1)
            if [[ -f "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
                dest_wallet=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                dest_name="TREASURY"
                dest_type="TREASURY"
                did_contribution_type="TREASURY_CONTRIBUTION"
                echo -e "${GREEN}✅ Treasury: ${dest_wallet:0:8}...${NC}"
            else
                echo -e "${RED}❌ Wallet TREASURY non trouvé: ~/.zen/game/uplanet.CASH.dunikey${NC}"
                return 1
            fi
            ;;
        2)
            if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
                dest_wallet=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                dest_name="R&D"
                dest_type="RnD"
                did_contribution_type="RND_CONTRIBUTION"
                echo -e "${GREEN}✅ R&D: ${dest_wallet:0:8}...${NC}"
            else
                echo -e "${RED}❌ Wallet R&D non trouvé: ~/.zen/game/uplanet.RnD.dunikey${NC}"
                return 1
            fi
            ;;
        3)
            if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
                dest_wallet=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                dest_name="ASSETS"
                dest_type="ASSETS"
                did_contribution_type="ASSETS_CONTRIBUTION"
                echo -e "${GREEN}✅ Assets: ${dest_wallet:0:8}...${NC}"
            else
                echo -e "${RED}❌ Wallet ASSETS non trouvé: ~/.zen/game/uplanet.ASSETS.dunikey${NC}"
                return 1
            fi
            ;;
        4)
            echo -e "${YELLOW}🚫 Opération annulée${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}❌ Choix invalide${NC}"
            return 1
            ;;
    esac
    
    echo ""
    
    # Demander le montant à transférer
    echo -e "${YELLOW}💰 Montant disponible dans la ZEN Card: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)${NC}"
    read -p "Montant à transférer en Ẑen: " amount_input
    
    # Valider que c'est un nombre
    if [[ ! "$amount_input" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
        return 1
    fi
    
    local zen_amount="$amount_input"
    
    # Vérifier que le montant ne dépasse pas le solde disponible
    if [[ $(echo "$zen_amount > $blockchain_zen" | bc -l) -eq 1 ]]; then
        echo -e "${RED}❌ Montant demandé (${zen_amount} Ẑen) supérieur au solde (${blockchain_zen} Ẑen)${NC}"
        return 1
    fi
    
    local g1_amount=$(zen_to_g1 "$zen_amount")
    
    # Demander le type pour la référence
    read -p "Type de sociétaire (satellite/constellation): " type_ref
    type_ref="${type_ref:-satellite}"
    
    echo ""
    echo -e "${YELLOW}📋 Récapitulatif de l'opération:${NC}"
    echo -e "  • Source: ZEN Card ${email_ref} (${zencard_pubkey:0:8}...)"
    echo -e "  • Destination: ${dest_name} (${dest_wallet:0:8}...)"
    echo -e "  • Montant: ${zen_amount} Ẑen (${g1_amount} Ğ1)"
    echo ""
    read -p "Confirmer le transfert? (oui/non): " confirm
    
    if [[ "$confirm" != "oui" ]]; then
        echo -e "${YELLOW}🚫 Transfert annulé${NC}"
        return 0
    fi
    
    # Effectuer le transfert
    echo ""
    echo -e "${BLUE}🚀 Lancement du transfert ZEN Card → ${dest_name}...${NC}"
    
    local reference="UPLANET:${UPLANETG1PUB:0:8}:${dest_type}:${email_ref}:${type_ref}:${IPFSNODEID}"
    
    if transfer_and_verify "$zencard_dunikey" "$dest_wallet" "$zen_amount" "$reference" "$email_ref" "RECOVERY_3x13_${dest_type}" "Recovery 3x1/3: ZENCARD→${dest_name}"; then
        echo ""
        echo -e "${GREEN}🎉 Transfert de récupération 3x1/3 terminé avec succès!${NC}"
        echo -e "${CYAN}📊 Résumé:${NC}"
        echo -e "  • ${zen_amount} Ẑen (${g1_amount} Ğ1) transférés de ZEN Card vers ${dest_name}"
        echo -e "  • Transaction confirmée sur la blockchain"
        echo ""
        
        # Mettre à jour DID pour contribution
        "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "$did_contribution_type" "$zen_amount" "$g1_amount"
        
        # Afficher le nouveau solde de la ZEN Card
        echo -e "${YELLOW}📊 Nouveau solde de la ZEN Card...${NC}"
        sleep 2
        local new_balance_json=$(silkaj --json money balance "$zencard_pubkey" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            local new_blockchain_centimes=$(echo "$new_balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
            [[ -z "$new_blockchain_centimes" || "$new_blockchain_centimes" == "null" ]] && new_blockchain_centimes="0"
            local new_blockchain_g1=$(echo "scale=2; $new_blockchain_centimes / 100" | bc -l)
            local new_blockchain_zen=$(echo "scale=2; $new_blockchain_g1 * 10" | bc -l)
            echo -e "${GREEN}✅ Nouveau solde ZEN Card: ${new_blockchain_g1} Ğ1 (${new_blockchain_zen} Ẑen)${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Échec du transfert de récupération 3x1/3${NC}"
        return 1
    fi
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
    echo "5. 🔧 MODE DÉPANNAGE (récupération complète SOCIETY → 3x1/3)"
    echo "6. 🔧 MODE DÉPANNAGE (récupération partielle ZEN Card → 3x1/3)"
    echo "7. Quitter"
    echo ""
    read -p "Choisissez une option (1-7): " choice
    
    case $choice in
        1)
            read -p "Email du locataire: " email
            if [[ -n "$email" ]]; then
                read -p "Montant en Ẑen (défaut: ${NCARD:-50}): " montant
                montant="${montant:-${NCARD:-50}}"
                
                # Valider que le montant est un nombre
                if [[ "$montant" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    process_locataire "$email" "$montant"
                else
                    echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
                fi
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        2)
            read -p "Email du sociétaire: " email
            if [[ -n "$email" ]]; then
                read -p "Montant en Ẑen (défaut: ${ZENCARD_SATELLITE:-50}): " montant
                montant="${montant:-${ZENCARD_SATELLITE:-50}}"
                
                # Valider que le montant est un nombre
                if [[ "$montant" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    process_societaire "$email" "satellite" "$montant"
                else
                    echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
                fi
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        3)
            read -p "Email du sociétaire: " email
            if [[ -n "$email" ]]; then
                read -p "Montant en Ẑen (défaut: ${ZENCARD_CONSTELLATION:-540}): " montant
                montant="${montant:-${ZENCARD_CONSTELLATION:-540}}"
                
                # Valider que le montant est un nombre
                if [[ "$montant" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    process_societaire "$email" "constellation" "$montant"
                else
                    echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
                fi
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
            process_recovery
            ;;
        6)
            process_recovery_3x13
            ;;
        7)
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
        # Parse arguments
        local email=""
        local type="satellite"
        local montant=""
        local mode=""
        
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -l|--locataire)
                    mode="locataire"
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        email="$1"
                        shift
                    fi
                    ;;
                -s|--societaire)
                    mode="societaire"
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        email="$1"
                        shift
                    fi
                    ;;
                -i|--infrastructure)
                    mode="infrastructure"
                    shift
                    ;;
                -r|--recovery)
                    mode="recovery"
                    shift
                    ;;
                --recovery-3x13)
                    mode="recovery_3x13"
                    shift
                    ;;
                -t|--type)
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        type="$1"
                        shift
                    fi
                    ;;
                -m|--montant)
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        montant="$1"
                        shift
                    fi
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
        done
        
        # Execute based on mode
        case "$mode" in
            "locataire")
                if [[ -n "$email" ]]; then
                    process_locataire "$email" "$montant"
                else
                    echo -e "${RED}❌ Email requis pour l'option --locataire${NC}"
                    exit 1
                fi
                ;;
            "societaire")
                if [[ -n "$email" ]]; then
                    process_societaire "$email" "$type" "$montant"
                else
                    echo -e "${RED}❌ Email requis pour l'option --societaire${NC}"
                    exit 1
                fi
                ;;
            "infrastructure")
                if [[ -n "$CAPTAINEMAIL" ]]; then
                    local machine_value="${montant:-${MACHINE_VALUE_ZEN:-500}}"
                    echo -e "${CYAN}💰 Apport capital infrastructure: ${CAPTAINEMAIL} (${machine_value} Ẑen)${NC}"
                    process_infrastructure "$CAPTAINEMAIL" "$machine_value"
                else
                    echo -e "${RED}❌ CAPTAINEMAIL non défini dans l'environnement${NC}"
                    echo -e "${CYAN}💡 Configurez votre email de capitaine dans my.sh${NC}"
                    exit 1
                fi
                ;;
            "recovery")
                process_recovery
                ;;
            "recovery_3x13")
                process_recovery_3x13
                ;;
            *)
                echo -e "${RED}❌ Mode non spécifié${NC}"
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
