#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# UPLANET.destroy.sh
# ⚠️  SCRIPT DESTRUCTEUR - VIDE TOUS LES PORTEFEUILLES UPLANET ⚠️
#
# Ce script transfère TOUS les fonds des portefeuilles UPlanet vers une 
# clé publique de destination spécifiée par l'utilisateur.
#
# PORTEFEUILLES VIDÉS :
# - Portefeuilles coopératifs (UPLANETNAME, SOCIETY, CASH, RND, ASSETS, etc.)
# - Portefeuille NODE (Armateur)
# - TOUS les portefeuilles MULTIPASS (NOSTR)
# - TOUTES les ZEN Cards (PLAYERS) - y compris celle du capitaine
#
# ⚠️  ATTENTION : CE SCRIPT DÉTRUIT LA COMPTABILITÉ UPLANET ⚠️
# ⚠️  UTILISATION UNIQUEMENT EN CAS DE FERMETURE DÉFINITIVE ⚠️
#
# Usage: ./UPLANET.destroy.sh [--force]
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
MIN_BALANCE="0.01"  # Solde minimum pour considérer un portefeuille non vide
DRY_RUN=true        # Par défaut en mode simulation
FORCE=false
DESTINATION_PUBKEY=""

# Compteurs globaux
TOTAL_WALLETS=0
TOTAL_AMOUNT="0"
SUCCESS_COUNT=0
FAILURE_COUNT=0
MIGRATION_NOTIFICATIONS_SENT=0
MIGRATION_NOTIFICATIONS_FAILED=0

# Portefeuilles coopératifs (basés sur UPLANET.init.sh)
declare -A COOPERATIVE_WALLETS=(
    ["UPLANETNAME"]="$HOME/.zen/game/uplanet.dunikey"
    ["UPLANETNAME_G1"]="$HOME/.zen/game/uplanet.G1.dunikey"
    ["UPLANETNAME_SOCIETY"]="$HOME/.zen/game/uplanet.SOCIETY.dunikey"
    ["UPLANETNAME_CASH"]="$HOME/.zen/game/uplanet.CASH.dunikey"
    ["UPLANETNAME_RND"]="$HOME/.zen/game/uplanet.RnD.dunikey"
    ["UPLANETNAME_ASSETS"]="$HOME/.zen/game/uplanet.ASSETS.dunikey"
    ["UPLANETNAME_IMPOT"]="$HOME/.zen/game/uplanet.IMPOT.dunikey"
    ["UPLANETNAME.CAPTAIN"]="$HOME/.zen/game/uplanet.captain.dunikey"
    ["UPLANETNAME_INTRUSION"]="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
)

# Portefeuilles NODE et CAPTAIN
declare -A NODE_CAPTAIN_WALLETS=(
    ["NODE"]="$HOME/.zen/game/secret.NODE.dunikey"
)

################################################################################
# Fonctions utilitaires
################################################################################

# Fonction pour afficher l'aide
show_help() {
    echo -e "${RED}${BOLD}⚠️  UPLANET.destroy.sh - SCRIPT DESTRUCTEUR ⚠️${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}ATTENTION : CE SCRIPT VIDE TOUS LES PORTEFEUILLES UPLANET${NC}"
    echo -e "${RED}Il transfère TOUS les fonds vers une clé publique de destination${NC}"
    echo -e "${RED}Cette opération est IRRÉVERSIBLE et DÉTRUIT la comptabilité UPlanet${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --force       Effectuer les vraies transactions (par défaut: simulation)"
    echo "  -h, --help    Affiche cette aide"
    echo ""
    echo -e "${YELLOW}Portefeuilles concernés :${NC}"
    echo "  • Portefeuilles coopératifs (UPLANETNAME, SOCIETY, CASH, RND, ASSETS, etc.)"
    echo "  • Portefeuille NODE (Armateur)"
    echo "  • TOUS les portefeuilles MULTIPASS (NOSTR)"
    echo "  • TOUTES les ZEN Cards (PLAYERS) - y compris celle du capitaine"
    echo ""
    echo -e "${RED}${BOLD}⚠️  UTILISATION UNIQUEMENT EN CAS DE FERMETURE DÉFINITIVE ⚠️${NC}"
}

# Fonction pour obtenir le solde d'un portefeuille
get_wallet_balance() {
    local pubkey="$1"
    
    # Utiliser G1check.sh pour obtenir le solde
    local balance_result=$("${MY_PATH}/tools/G1check.sh" "$pubkey" 2>/dev/null)
    
    # Extraire le solde du résultat
    local balance=$(echo "$balance_result" | grep -E '^[0-9]+\.?[0-9]*$' | head -1)
    
    if [[ -z "$balance" ]]; then
        echo "0"
    else
        echo "$balance"
    fi
}

# Fonction pour obtenir la clé publique depuis un fichier dunikey
get_wallet_public_key() {
    local dunikey_file="$1"
    
    if [[ -f "$dunikey_file" ]]; then
        local pubkey=$(cat "$dunikey_file" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        echo "$pubkey"
    else
        echo ""
    fi
}

# Fonction pour vider un portefeuille
empty_wallet() {
    local wallet_name="$1"
    local dunikey_file="$2"
    local pubkey="$3"
    local balance="$4"
    
    echo -e "\n${CYAN}💸 VIDAGE DE $wallet_name${NC}"
    echo -e "${YELLOW}================================${NC}"
    echo -e "${BLUE}Portefeuille:${NC} $wallet_name"
    echo -e "${BLUE}Clé publique:${NC} ${CYAN}${pubkey:0:8}...${NC}"
    echo -e "${BLUE}Solde actuel:${NC} ${YELLOW}$balance Ğ1${NC}"
    echo -e "${BLUE}Destination:${NC} ${CYAN}${DESTINATION_PUBKEY:0:8}...${NC}"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 SIMULATION: Transfert de $balance Ğ1 vers la destination${NC}"
        ((SUCCESS_COUNT++))
        TOTAL_AMOUNT=$(echo "scale=2; $TOTAL_AMOUNT + $balance" | bc -l)
        return 0
    fi
    
    # Sur Ğ1 (Duniter), il n'y a pas de frais de transaction
    # On peut transférer la totalité du solde
    local transfer_amount="$balance"
    
    # Effectuer le transfert avec PAYforSURE.sh
    echo -e "${YELLOW}Transfert de $transfer_amount Ğ1...${NC}"
    
    # PAYforSURE.sh parameters: <keyfile> <amount> <g1pub> [comment] [moats]
    local comment="UPLANET:DESTROY:$wallet_name"
    local moats=$(date -u +"%Y%m%d%H%M%S%4N")
    
    if "${MY_PATH}/tools/PAYforSURE.sh" "$dunikey_file" "$transfer_amount" "$DESTINATION_PUBKEY" "$comment" "$moats" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Transfert réussi: $transfer_amount Ğ1${NC}"
        ((SUCCESS_COUNT++))
        TOTAL_AMOUNT=$(echo "scale=2; $TOTAL_AMOUNT + $transfer_amount" | bc -l)
        
        # Envoyer une alerte au CAPTAINEMAIL
        if [[ -n "$CAPTAINEMAIL" ]]; then
            send_destruction_alert "$wallet_name" "$transfer_amount" "SUCCESS"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Échec du transfert${NC}"
        echo "PAYforSURE.sh failed for $wallet_name"
        ((FAILURE_COUNT++))
        
        # Envoyer une alerte d'échec au CAPTAINEMAIL
        if [[ -n "$CAPTAINEMAIL" ]]; then
            send_destruction_alert "$wallet_name" "$transfer_amount" "FAILURE" "PAYforSURE.sh transfer failed"
        fi
        
        return 1
    fi
}

# Fonction pour envoyer une notification de migration MULTIPASS
send_multipass_migration_notification() {
    local email="$1"
    local pubkey="$2"
    local amount="$3"
    local status="$4"
    
    # Vérifier que l'email est valide
    if [[ -z "$email" || ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        echo -e "${YELLOW}⚠️  Email invalide pour la notification: $email${NC}"
        return 1
    fi
    
    # Générer un ID de migration unique
    local migration_id="UPLANET-$(date +%Y%m%d)-$(echo "$email" | md5sum | cut -c1-8)"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S UTC')
    local migration_date=$(date '+%Y-%m-%d')
    
    # Créer le fichier de notification HTML basé sur le template
    local notification_file="$HOME/.zen/tmp/multipass_migration_${email//[@.]/_}_$(date +%Y%m%d_%H%M%S).html"
    
    # Copier le template et remplacer les variables
    cp "${MY_PATH}/templates/MULTIPASS/migration_notification.html" "$notification_file"
    
    # Remplacer les variables dans le template [[memory:7094165]]
    sed -i "s/_EMAIL_/$email/g" "$notification_file"
    sed -i "s/_PUBKEY_/${pubkey:0:8}...${pubkey: -8}/g" "$notification_file"
    sed -i "s/_AMOUNT_/$amount/g" "$notification_file"
    sed -i "s/_MIGRATION_DATE_/$migration_date/g" "$notification_file"
    sed -i "s/_MIGRATION_ID_/$migration_id/g" "$notification_file"
    sed -i "s/_TIMESTAMP_/$timestamp/g" "$notification_file"
    sed -i "s/_SUPPORT_EMAIL_/${CAPTAINEMAIL:-support@qo-op.com}/g" "$notification_file"
    sed -i "s/_COMMUNITY_LINK_/https:\/\/forum.monnaie-libre.fr/g" "$notification_file"
    
    # Ajouter le secret UPLANET pour la récupération des GeoKeys
    local uplanet_secret="${UPLANETNAME:-EnfinLibre}"
    sed -i "s/_UPLANET_SECRET_/$uplanet_secret/g" "$notification_file"
    
    # Envoyer la notification via mailjet.sh
    local subject="🚀 UPlanet Migration - Your MULTIPASS Wallet Transition"
    if [[ "$status" == "SUCCESS" ]]; then
        subject="🚀 UPlanet Migration - Successful Transfer ($amount Ğ1)"
    else
        subject="⚠️ UPlanet Migration - Transfer Issue ($email)"
    fi
    
    echo -e "${CYAN}📧 Sending migration notification to: $email${NC}"
    
    if "${MY_PATH}/tools/mailjet.sh" "$email" "$notification_file" "$subject" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Migration notification sent successfully${NC}"
        ((MIGRATION_NOTIFICATIONS_SENT++))
        
        # Garder le fichier de notification pour les logs
        mkdir -p "$HOME/.zen/tmp/migration_notifications/"
        mv "$notification_file" "$HOME/.zen/tmp/migration_notifications/" 2>/dev/null
        
        return 0
    else
        echo -e "${RED}❌ Failed to send migration notification${NC}"
        ((MIGRATION_NOTIFICATIONS_FAILED++))
        
        # Garder le fichier même en cas d'échec pour debug
        mkdir -p "$HOME/.zen/tmp/migration_notifications/failed/"
        mv "$notification_file" "$HOME/.zen/tmp/migration_notifications/failed/" 2>/dev/null
        
        return 1
    fi
}

# Fonction pour envoyer une alerte de destruction
send_destruction_alert() {
    local wallet_name="$1"
    local amount="$2"
    local status="$3"
    local error_details="$4"
    
    # Vérifier que CAPTAINEMAIL est défini
    if [[ -z "$CAPTAINEMAIL" ]]; then
        return 1
    fi
    
    # Créer le fichier d'alerte HTML
    local alert_file="$HOME/.zen/tmp/uplanet_destroy_alert_$(date +%Y%m%d_%H%M%S).html"
    
    local status_color="#f44336"  # Rouge par défaut
    local status_icon="❌"
    if [[ "$status" == "SUCCESS" ]]; then
        status_color="#ff9800"  # Orange pour destruction réussie
        status_icon="💸"
    fi
    
    cat > "$alert_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>🚨 UPLANET Destruction Alert</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .alert { background-color: #ffebee; border-left: 5px solid $status_color; padding: 15px; margin: 10px 0; }
        .warning { background-color: #fff3e0; border-left: 5px solid #ff9800; padding: 15px; margin: 10px 0; }
        .details { background-color: #f5f5f5; padding: 10px; border-radius: 5px; font-family: monospace; }
        h1 { color: $status_color; }
        h2 { color: #1976d2; }
    </style>
</head>
<body>
    <h1>🚨 ALERTE DESTRUCTION UPLANET</h1>
    
    <div class="alert">
        <h2>$status_icon Vidage de Portefeuille</h2>
        <p><strong>Statut:</strong> $status</p>
        <p><strong>Date/Heure:</strong> $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
    </div>
    
    <div class="warning">
        <h2>Détails de l'Opération</h2>
        <p><strong>Portefeuille vidé:</strong> $wallet_name</p>
        <p><strong>Montant transféré:</strong> $amount Ğ1</p>
        <p><strong>Destination:</strong> ${DESTINATION_PUBKEY:0:8}...</p>
    </div>
EOF

    if [[ -n "$error_details" ]]; then
        cat >> "$alert_file" << EOF
    
    <div class="details">
        <h2>Détails de l'Erreur</h2>
        <pre>$error_details</pre>
    </div>
EOF
    fi

    cat >> "$alert_file" << EOF
    
    <div class="warning">
        <h2>⚠️ ATTENTION</h2>
        <p>Cette opération fait partie de la <strong>DESTRUCTION COMPLÈTE</strong> de la comptabilité UPlanet.</p>
        <p>Tous les fonds sont transférés vers: <strong>${DESTINATION_PUBKEY}</strong></p>
    </div>
    
    <hr>
    <p><small>Alerte générée automatiquement par UPLANET.destroy.sh</small></p>
</body>
</html>
EOF
    
    # Envoyer l'alerte via mailjet.sh
    "${MY_PATH}/tools/mailjet.sh" "$CAPTAINEMAIL" "$alert_file" "🚨 UPLANET Destruction - $wallet_name ($status)" >/dev/null 2>&1
    
    # Garder le fichier d'alerte pour les logs
    mkdir -p "$HOME/.zen/tmp/alerts/"
    mv "$alert_file" "$HOME/.zen/tmp/alerts/" 2>/dev/null
}

# Fonction pour scanner et vider les portefeuilles coopératifs
destroy_cooperative_wallets() {
    echo -e "\n${RED}${BOLD}💀 DESTRUCTION DES PORTEFEUILLES COOPÉRATIFS${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    
    local wallets_found=0
    
    for wallet_name in "${!COOPERATIVE_WALLETS[@]}"; do
        local dunikey_file="${COOPERATIVE_WALLETS[$wallet_name]}"
        
        if [[ -f "$dunikey_file" ]]; then
            local pubkey=$(get_wallet_public_key "$dunikey_file")
            if [[ -n "$pubkey" ]]; then
                local balance=$(get_wallet_balance "$pubkey")
                
                if (( $(echo "$balance > $MIN_BALANCE" | bc -l) )); then
                    ((wallets_found++))
                    ((TOTAL_WALLETS++))
                    empty_wallet "$wallet_name" "$dunikey_file" "$pubkey" "$balance"
                    
                    # Pause entre les transactions
                    if [[ "$DRY_RUN" != true ]]; then
                        sleep 2
                    fi
                else
                    echo -e "${BLUE}ℹ️  $wallet_name: Vide ($balance Ğ1)${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  $wallet_name: Clé publique invalide${NC}"
            fi
        else
            echo -e "${BLUE}ℹ️  $wallet_name: Fichier non trouvé${NC}"
        fi
    done
    
    echo -e "\n${CYAN}📊 Portefeuilles coopératifs traités: $wallets_found${NC}"
}

# Fonction pour scanner et vider le portefeuille NODE
destroy_node_wallet() {
    echo -e "\n${RED}${BOLD}💀 DESTRUCTION DU PORTEFEUILLE NODE${NC}"
    echo -e "${YELLOW}===================================${NC}"
    
    local wallets_found=0
    
    # NODE wallet (Armateur)
    local node_dunikey="${NODE_CAPTAIN_WALLETS["NODE"]}"
    if [[ -f "$node_dunikey" ]]; then
        local pubkey=$(get_wallet_public_key "$node_dunikey")
        if [[ -n "$pubkey" ]]; then
            local balance=$(get_wallet_balance "$pubkey")
            
            if (( $(echo "$balance > $MIN_BALANCE" | bc -l) )); then
                ((wallets_found++))
                ((TOTAL_WALLETS++))
                empty_wallet "NODE" "$node_dunikey" "$pubkey" "$balance"
                
                if [[ "$DRY_RUN" != true ]]; then
                    sleep 2
                fi
            else
                echo -e "${BLUE}ℹ️  NODE: Vide ($balance Ğ1)${NC}"
            fi
        fi
    else
        echo -e "${BLUE}ℹ️  NODE: Non trouvé (normal pour les nœuds non-Y-level)${NC}"
    fi
    
    echo -e "\n${CYAN}📊 Portefeuille NODE traité: $wallets_found${NC}"
}

# Fonction pour scanner et vider tous les portefeuilles MULTIPASS
destroy_multipass_wallets() {
    echo -e "\n${RED}${BOLD}💀 DESTRUCTION DES PORTEFEUILLES MULTIPASS${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    local wallets_found=0
    local nostr_dir="$HOME/.zen/game/nostr"
    
    if [[ -d "$nostr_dir" ]]; then
        # Scanner tous les dossiers d'emails dans nostr/
        for email_dir in "$nostr_dir"/*@*.*; do
            if [[ -d "$email_dir" ]]; then
                local email=$(basename "$email_dir")
                local secret_dunikey="$email_dir/.secret.dunikey"
                
                if [[ -f "$secret_dunikey" ]]; then
                    local pubkey=$(get_wallet_public_key "$secret_dunikey")
                    if [[ -n "$pubkey" ]]; then
                        local balance=$(get_wallet_balance "$pubkey")
                        
                        if (( $(echo "$balance > $MIN_BALANCE" | bc -l) )); then
                            ((wallets_found++))
                            ((TOTAL_WALLETS++))
                            
                            # Vider le portefeuille
                            if empty_wallet "MULTIPASS_$email" "$secret_dunikey" "$pubkey" "$balance"; then
                                # Envoyer la notification de migration à l'utilisateur
                                send_multipass_migration_notification "$email" "$pubkey" "$balance" "SUCCESS"
                            else
                                # Envoyer la notification d'échec
                                send_multipass_migration_notification "$email" "$pubkey" "$balance" "FAILURE"
                            fi
                            
                            if [[ "$DRY_RUN" != true ]]; then
                                sleep 2
                            fi
                        else
                            echo -e "${BLUE}ℹ️  MULTIPASS $email: Vide ($balance Ğ1)${NC}"
                            
                            # Même pour les portefeuilles vides, envoyer une notification de migration
                            if [[ "$DRY_RUN" != true ]]; then
                                send_multipass_migration_notification "$email" "$pubkey" "$balance" "SUCCESS"
                            fi
                        fi
                    fi
                fi
            fi
        done
    else
        echo -e "${BLUE}ℹ️  Dossier NOSTR non trouvé${NC}"
    fi
    
    echo -e "\n${CYAN}📊 Portefeuilles MULTIPASS traités: $wallets_found${NC}"
}

# Fonction pour scanner et vider toutes les ZEN Cards
destroy_zencard_wallets() {
    echo -e "\n${RED}${BOLD}💀 DESTRUCTION DES ZEN CARDS${NC}"
    echo -e "${YELLOW}=============================${NC}"
    
    local wallets_found=0
    local players_dir="$HOME/.zen/game/players"
    
    if [[ -d "$players_dir" ]]; then
        # Scanner tous les dossiers d'emails dans players/
        for email_dir in "$players_dir"/*@*.*; do
            if [[ -d "$email_dir" ]]; then
                local email=$(basename "$email_dir")
                local secret_dunikey="$email_dir/secret.dunikey"
                
                if [[ -f "$secret_dunikey" ]]; then
                    local pubkey=$(get_wallet_public_key "$secret_dunikey")
                    if [[ -n "$pubkey" ]]; then
                        local balance=$(get_wallet_balance "$pubkey")
                        
                        if (( $(echo "$balance > $MIN_BALANCE" | bc -l) )); then
                            ((wallets_found++))
                            ((TOTAL_WALLETS++))
                            empty_wallet "ZENCARD_$email" "$secret_dunikey" "$pubkey" "$balance"
                            
                            if [[ "$DRY_RUN" != true ]]; then
                                sleep 2
                            fi
                        else
                            echo -e "${BLUE}ℹ️  ZEN Card $email: Vide ($balance Ğ1)${NC}"
                        fi
                    fi
                fi
            fi
        done
    else
        echo -e "${BLUE}ℹ️  Dossier PLAYERS non trouvé${NC}"
    fi
    
    echo -e "\n${CYAN}📊 ZEN Cards traitées: $wallets_found${NC}"
}

# Fonction pour valider la clé publique de destination
validate_destination_pubkey() {
    local pubkey="$1"
    
    # Vérifier le format de base (44 caractères, base58)
    if [[ ! "$pubkey" =~ ^[1-9A-HJ-NP-Za-km-z]{44}$ ]]; then
        echo -e "${RED}❌ Format de clé publique invalide${NC}"
        echo -e "${YELLOW}Format attendu: 44 caractères en base58${NC}"
        return 1
    fi
    
    # Vérifier que la clé publique existe sur la blockchain
    echo -e "${YELLOW}Vérification de l'existence de la clé publique...${NC}"
    local balance=$(get_wallet_balance "$pubkey")
    
    if [[ "$balance" == "0" ]]; then
        echo -e "${YELLOW}⚠️  La clé publique n'a pas encore de transactions sur la blockchain${NC}"
        echo -e "${YELLOW}Cela peut être normal pour une nouvelle clé${NC}"
        
        if [[ "$FORCE" != true ]]; then
            read -p "Continuer avec cette clé publique ? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                return 1
            fi
        fi
    else
        echo -e "${GREEN}✅ Clé publique valide (solde actuel: $balance Ğ1)${NC}"
    fi
    
    return 0
}

# Fonction de confirmation de sécurité
security_confirmation() {
    echo -e "\n${RED}${BOLD}⚠️  CONFIRMATION DE SÉCURITÉ REQUISE ⚠️${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    echo -e "${WHITE}${BOLD}VOUS ÊTES SUR LE POINT DE DÉTRUIRE LA COMPTABILITÉ UPLANET${NC}"
    echo -e "${RED}Cette opération va transférer TOUS les fonds vers:${NC}"
    echo -e "${CYAN}${BOLD}$DESTINATION_PUBKEY${NC}"
    echo ""
    echo -e "${YELLOW}Portefeuilles qui seront vidés:${NC}"
    echo -e "  • Portefeuilles coopératifs (UPLANETNAME, SOCIETY, CASH, RND, ASSETS, etc.)"
    echo -e "  • Portefeuille NODE (Armateur)"
    echo -e "  • TOUS les portefeuilles MULTIPASS"
    echo -e "  • TOUTES les ZEN Cards (y compris celle du capitaine)"
    echo ""
    echo -e "${RED}${BOLD}CETTE OPÉRATION EST IRRÉVERSIBLE !${NC}"
    echo ""
    
    if [[ "$FORCE" == true ]]; then
        echo -e "${YELLOW}Mode --force activé, confirmations ignorées${NC}"
        return 0
    fi
    
    # Première confirmation
    echo -e "${WHITE}${BOLD}Première confirmation:${NC}"
    read -p "Tapez 'DESTROY' pour confirmer la destruction: " confirm1
    
    if [[ "$confirm1" != "DESTROY" ]]; then
        echo -e "${GREEN}Opération annulée.${NC}"
        exit 0
    fi
    
    # Deuxième confirmation
    echo -e "\n${WHITE}${BOLD}Deuxième confirmation:${NC}"
    echo -e "${RED}Confirmez la clé publique de destination:${NC}"
    read -p "Retapez la clé publique complète: " confirm2
    
    if [[ "$confirm2" != "$DESTINATION_PUBKEY" ]]; then
        echo -e "${RED}❌ Clé publique incorrecte. Opération annulée.${NC}"
        exit 1
    fi
    
    # Troisième confirmation
    echo -e "\n${WHITE}${BOLD}Confirmation finale:${NC}"
    echo -e "${RED}Êtes-vous ABSOLUMENT CERTAIN de vouloir détruire la comptabilité UPlanet ?${NC}"
    read -p "Tapez 'YES I AM SURE' pour procéder: " confirm3
    
    if [[ "$confirm3" != "YES I AM SURE" ]]; then
        echo -e "${GREEN}Opération annulée.${NC}"
        exit 0
    fi
    
    echo -e "\n${RED}${BOLD}🚨 DESTRUCTION CONFIRMÉE - DÉBUT DES OPÉRATIONS 🚨${NC}"
    sleep 3
}

# Fonction principale
main() {
    echo -e "${RED}${BOLD}💀 UPLANET.DESTROY.SH - DESTRUCTEUR DE COMPTABILITÉ 💀${NC}"
    echo -e "${YELLOW}======================================================${NC}"
    echo -e "${WHITE}${BOLD}⚠️  SCRIPT EXTRÊMEMENT DANGEREUX ⚠️${NC}"
    echo -e "${RED}Ce script vide TOUS les portefeuilles UPlanet vers une destination${NC}"
    echo ""
    
    # Traitement des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                DRY_RUN=false
                FORCE=true
                shift
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
    
    # Vérifier les outils requis
    if ! command -v silkaj &> /dev/null; then
        echo -e "${RED}❌ Erreur: silkaj n'est pas installé${NC}"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}❌ Erreur: bc n'est pas installé${NC}"
        exit 1
    fi
    
    # Afficher le mode actuel
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 MODE SIMULATION ACTIVÉ (par défaut)${NC}"
        echo -e "${CYAN}Pour effectuer les vraies transactions, utilisez: --force${NC}"
        DESTINATION_PUBKEY="SIMULATION_MODE"
    else
        echo -e "${RED}${BOLD}⚠️  MODE DESTRUCTION RÉEL ACTIVÉ ⚠️${NC}"
        echo -e "${CYAN}🎯 DESTINATION DES FONDS${NC}"
        echo -e "${YELLOW}========================${NC}"
        echo -e "${WHITE}Entrez la clé publique de destination (44 caractères):${NC}"
        read -p "Clé publique: " DESTINATION_PUBKEY
        
        if [[ -z "$DESTINATION_PUBKEY" ]]; then
            echo -e "${RED}❌ Clé publique requise${NC}"
            exit 1
        fi
        
        # Valider la clé publique
        if ! validate_destination_pubkey "$DESTINATION_PUBKEY"; then
            exit 1
        fi
        
        # Confirmation de sécurité
        security_confirmation
    fi
    
    # Initialiser les compteurs
    TOTAL_WALLETS=0
    TOTAL_AMOUNT="0"
    SUCCESS_COUNT=0
    FAILURE_COUNT=0
    MIGRATION_NOTIFICATIONS_SENT=0
    MIGRATION_NOTIFICATIONS_FAILED=0
    
    # Détruire tous les portefeuilles
    destroy_cooperative_wallets
    destroy_node_wallet
    destroy_multipass_wallets
    destroy_zencard_wallets
    
    # Résumé final
    echo -e "\n${RED}${BOLD}💀 RÉSUMÉ DE LA DESTRUCTION 💀${NC}"
    echo -e "${YELLOW}================================${NC}"
    echo -e "${BLUE}Portefeuilles traités:${NC} ${CYAN}$TOTAL_WALLETS${NC}"
    echo -e "${BLUE}Transferts réussis:${NC} ${GREEN}$SUCCESS_COUNT${NC}"
    echo -e "${BLUE}Transferts échoués:${NC} ${RED}$FAILURE_COUNT${NC}"
    echo -e "${BLUE}Montant total transféré:${NC} ${YELLOW}$TOTAL_AMOUNT Ğ1${NC}"
    echo -e "${BLUE}Notifications de migration envoyées:${NC} ${GREEN}$MIGRATION_NOTIFICATIONS_SENT${NC}"
    echo -e "${BLUE}Notifications de migration échouées:${NC} ${RED}$MIGRATION_NOTIFICATIONS_FAILED${NC}"
    
    if [[ "$DRY_RUN" != true ]]; then
        echo -e "${BLUE}Destination:${NC} ${CYAN}$DESTINATION_PUBKEY${NC}"
    fi
    
    if [[ $FAILURE_COUNT -eq 0 && $SUCCESS_COUNT -gt 0 ]]; then
        echo -e "\n${RED}${BOLD}💀 DESTRUCTION COMPLÈTE RÉUSSIE 💀${NC}"
        echo -e "${RED}La comptabilité UPlanet a été entièrement détruite${NC}"
        echo -e "${RED}Tous les fonds ont été transférés vers la destination${NC}"
    elif [[ $FAILURE_COUNT -gt 0 ]]; then
        echo -e "\n${YELLOW}⚠️  DESTRUCTION PARTIELLE${NC}"
        echo -e "${YELLOW}Certains transferts ont échoué, vérifiez les erreurs ci-dessus${NC}"
    else
        echo -e "\n${BLUE}ℹ️  Aucun portefeuille avec des fonds trouvé${NC}"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "\n${YELLOW}🔍 SIMULATION TERMINÉE - Aucune transaction réelle effectuée${NC}"
    fi
}

# Vérifier si l'aide est demandée
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Exécuter la fonction principale
main "$@"
