#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_PAY.sh - Enhanced NOSTR Payment Script
#
# This script allows NOSTR payments using a private key (.secret.dunikey),
# amount, destination public key, and comment. If no parameters are provided,
# it lists all available accounts and launches an interactive assistant.
#
# Usage: ./nostr_PAY.sh [keyfile] [amount] [dest_pubkey] [comment]
# If no parameters are provided, the script will prompt the user to select
# an account and enter payment details interactively.
# -----------------------------------------------------------------------------

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Fonction d'affichage améliorée
print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    printf "║%*s║\n" $((78)) ""
    printf "║%*s%s%*s║\n" $(((78-${#1})/2)) "" "$1" $(((78-${#1})/2)) ""
    printf "║%*s║\n" $((78)) ""
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "│ %-76s │\n" "$1"
    echo "└──────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_balance() {
    local balance="$1"
    local pubkey="$2"
    echo -e "  ${WHITE}💰 Balance: ${GREEN}$balance Ğ1${NC}"
    echo -e "  ${WHITE}🔑 Public Key: ${CYAN}${pubkey:0:20}...${NC}"
}

# Function to display usage information
usage() {
    print_header "NOSTR PAYMENT ASSISTANT"
    echo -e "${WHITE}Usage: $ME [keyfile] [amount] [dest_pubkey] [comment]${NC}"
    echo ""
    echo -e "${CYAN}Parameters:${NC}"
    echo "  keyfile     - Path to the .secret.dunikey file"
    echo "  amount      - Amount to transfer (in G1)"
    echo "  dest_pubkey - Destination public key"
    echo "  comment     - Optional comment for the transaction"
    echo ""
    echo -e "${YELLOW}If no parameters are provided, the script will launch an interactive assistant.${NC}"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  $ME                                    # Interactive mode"
    echo "  $ME ~/.zen/game/nostr/user@domain/.secret.dunikey 10.5 ABC123... 'Payment for services'"
    echo "  $ME ~/.zen/game/nostr/user@domain/.secret.dunikey 5.0 ABC123..."
    exit 1
}

# Function to list available NOSTR accounts and prompt user to select one
select_nostr_account() {
    print_section "SELECTION DU COMPTE NOSTR"
    
    # Find all NOSTR accounts with G1PUBNOSTR files (much faster than finding .secret.dunikey)
    nostr_accounts=()
    nostr_keys=()
    
    if [[ -d ~/.zen/game/nostr ]]; then
        # Use the same approach as nostr_DESTROY_TW.sh - find accounts with G1PUBNOSTR files
        account_names=($(ls ~/.zen/game/nostr/*@*.*/G1PUBNOSTR 2>/dev/null | rev | cut -d '/' -f 2 | rev))
        
        if [[ ${#account_names[@]} -eq 0 ]]; then
            print_error "Aucun compte NOSTR trouvé."
            echo ""
            echo -e "${YELLOW}Pour créer un compte NOSTR:${NC}"
            echo "  1. Utilisez l'interface web: http://127.0.0.1:54321/g1"
            echo "  2. Ou lancez: ./command.sh"
            echo ""
            exit 1
        fi
        
        echo -e "${WHITE}Comptes NOSTR disponibles:${NC}"
        echo ""
        
        for account_name in "${account_names[@]}"; do
            g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
            if [[ -n "$g1pub" ]]; then
                # Get balance from cache (much faster than COINScheck.sh)
                balance=$(cat ~/.zen/tmp/coucou/${g1pub}.COINS 2>/dev/null)
                if [[ -z "$balance" || "$balance" == "null" ]]; then
                    balance="0"
                fi
                
                # Check if .secret.dunikey exists
                keyfile="$HOME/.zen/game/nostr/${account_name}/.secret.dunikey"
                if [[ -f "$keyfile" ]]; then
                    nostr_accounts+=("$account_name")
                    nostr_keys+=("$keyfile")
                    
                    local index=${#nostr_accounts[@]}
                    echo -e "${BLUE}${index})${NC} ${WHITE}$account_name${NC}"
                    print_balance "$balance" "$g1pub"
                    echo -e "  ${WHITE}📁 Key File: ${CYAN}$keyfile${NC}"
                    echo ""
                fi
            fi
        done
    fi
    
    if [[ ${#nostr_accounts[@]} -eq 0 ]]; then
        print_error "Aucun compte NOSTR trouvé avec des fichiers .secret.dunikey."
        echo ""
        echo -e "${YELLOW}Assurez-vous d'avoir des comptes NOSTR configurés dans ~/.zen/game/nostr/${NC}"
        exit 1
    fi
    
    # Prompt user to select account
    while true; do
        echo -e "${WHITE}Entrez le numéro correspondant au compte:${NC} "
        read -p "> " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#nostr_accounts[@]} ]; then
            break
        else
            print_error "Sélection invalide. Veuillez entrer un nombre entre 1 et ${#nostr_accounts[@]}."
        fi
    done
    
    selected_index=$((selection - 1))
    selected_account="${nostr_accounts[$selected_index]}"
    selected_keyfile="${nostr_keys[$selected_index]}"
    
    echo ""
    print_success "Compte sélectionné: $selected_account"
    echo -e "${WHITE}Fichier de clé: ${CYAN}$selected_keyfile${NC}"
}

# Function to get payment details interactively
get_payment_details() {
    print_section "DÉTAILS DU PAIEMENT"
    
    # Get amount
    while true; do
        echo -e "${WHITE}Montant à transférer (en Ğ1):${NC}"
        read -p "> " amount
        
        if [[ -n "$amount" ]] && [[ $amount =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            # Check if amount is greater than 0
            if (( $(echo "$amount > 0" | bc -l) )); then
                break
            else
                print_error "Le montant doit être supérieur à 0."
            fi
        else
            print_error "Veuillez entrer un montant valide (ex: 10.5)"
        fi
    done
    
    echo ""
    
    # Get destination public key
    while true; do
        echo -e "${WHITE}Clé publique de destination:${NC}"
        read -p "> " dest_pubkey
        
        if [[ -n "$dest_pubkey" ]]; then
            # Test the public key with g1_to_ipfs.py
            if ${MY_PATH}/g1_to_ipfs.py "$dest_pubkey" >/dev/null 2>&1; then
                break
            else
                print_error "Veuillez entrer une clé publique G1 valide"
            fi
        else
            print_error "Veuillez entrer une clé publique valide"
        fi
    done
    
    echo ""
    
    # Get optional comment
    echo -e "${WHITE}Commentaire (optionnel):${NC}"
    read -p "> " comment
}

# Function to validate parameters
validate_parameters() {
    local keyfile="$1"
    local amount="$2"
    local dest_pubkey="$3"
    
    # Validate keyfile
    if [[ ! -f "$keyfile" ]]; then
        print_error "Fichier de clé '$keyfile' non trouvé"
        exit 1
    fi
    
    # Validate amount
    if [[ -z "$amount" ]] || ! [[ $amount =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        print_error "Montant invalide '$amount'"
        exit 1
    fi
    
    # Check if amount is greater than 0
    if (( $(echo "$amount <= 0" | bc -l) )); then
        print_error "Le montant doit être supérieur à 0"
        exit 1
    fi
    
    # Validate destination public key using g1_to_ipfs.py
    if [[ -z "$dest_pubkey" ]]; then
        print_error "Clé publique de destination vide"
        exit 1
    fi
    
    # Test the public key with g1_to_ipfs.py
    if ! ${MY_PATH}/g1_to_ipfs.py "$dest_pubkey" >/dev/null 2>&1; then
        print_error "Clé publique G1 invalide '$dest_pubkey'"
        exit 1
    fi
}

# Function to display payment summary and confirm
confirm_payment() {
    local keyfile="$1"
    local amount="$2"
    local dest_pubkey="$3"
    local comment="$4"
    
    # Get source public key
    source_pubkey=$(grep "pub:" "$keyfile" | cut -d ' ' -f 2 2>/dev/null)
    
    # Get source balance from cache (much faster than COINScheck.sh)
    source_balance=$(cat ~/.zen/tmp/coucou/${source_pubkey}.COINS 2>/dev/null)
    if [[ -z "$source_balance" || "$source_balance" == "null" ]]; then
        source_balance="0"
    fi
    
    # Get destination balance from cache
    dest_balance=$(cat ~/.zen/tmp/coucou/${dest_pubkey}.COINS 2>/dev/null)
    if [[ -z "$dest_balance" || "$dest_balance" == "null" ]]; then
        dest_balance="0"
    fi
    
    print_section "RÉSUMÉ DU PAIEMENT"
    
    echo -e "${WHITE}De:${NC}"
    print_balance "$source_balance" "$source_pubkey"
    echo ""
    
    echo -e "${WHITE}Vers:${NC}"
    print_balance "$dest_balance" "$dest_pubkey"
    echo ""
    
    echo -e "${WHITE}Montant: ${GREEN}$amount Ğ1${NC}"
    if [[ -n "$comment" ]]; then
        echo -e "${WHITE}Commentaire: ${CYAN}$comment${NC}"
    fi
    echo ""
    
    # Check if sufficient balance
    if (( $(echo "$source_balance < $amount" | bc -l) )); then
        print_error "Solde insuffisant. Disponible: $source_balance Ğ1, Requis: $amount Ğ1"
        echo ""
        echo -e "${YELLOW}Suggestions:${NC}"
        echo "  • Vérifiez votre solde avec: ./command.sh"
        echo "  • Attendez la synchronisation des données"
        echo "  • Contactez le support si le problème persiste"
        exit 1
    fi
    
    # Calculate new balances
    new_source_balance=$(echo "$source_balance - $amount" | bc -l)
    new_dest_balance=$(echo "$dest_balance + $amount" | bc -l)
    
    echo -e "${WHITE}Nouveaux soldes après transaction:${NC}"
    echo -e "  ${WHITE}Votre compte: ${GREEN}$new_source_balance Ğ1${NC}"
    echo -e "  ${WHITE}Compte destinataire: ${GREEN}$new_dest_balance Ğ1${NC}"
    echo ""
    
    while true; do
        echo -e "${WHITE}Confirmer le paiement ? (oui/non):${NC}"
        read -p "> " confirm
        
        case "$confirm" in
            "oui"|"o"|"y"|"yes"|"OUI"|"O"|"Y"|"YES")
                break
                ;;
            "non"|"n"|"no"|"NON"|"N"|"NO")
                print_warning "Paiement annulé."
                exit 0
                ;;
            *)
                print_error "Veuillez répondre 'oui' ou 'non'"
                ;;
        esac
    done
}

# Main script logic
main() {
    # Check if parameters are provided
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        print_header "ASSISTANT DE PAIEMENT NOSTR"
        echo -e "${CYAN}Mode interactif - Sélectionnez votre compte et entrez les détails du paiement${NC}"
        echo ""
        
        # Select account
        select_nostr_account
        
        # Get payment details
        get_payment_details
        
        # Set variables for payment
        keyfile="$selected_keyfile"
        amount="$amount"
        dest_pubkey="$dest_pubkey"
        comment="$comment"
        
    elif [[ $# -eq 3 ]]; then
        # Parameters provided: keyfile, amount, dest_pubkey
        keyfile="$1"
        amount="$2"
        dest_pubkey="$3"
        comment=""
        
    elif [[ $# -eq 4 ]]; then
        # Parameters provided: keyfile, amount, dest_pubkey, comment
        keyfile="$1"
        amount="$2"
        dest_pubkey="$3"
        comment="$4"
        
    else
        usage
    fi
    
    # Validate parameters
    validate_parameters "$keyfile" "$amount" "$dest_pubkey"
    
    # Confirm payment
    confirm_payment "$keyfile" "$amount" "$dest_pubkey" "$comment"
    
    # Execute payment using PAYforSURE.sh
    print_section "EXÉCUTION DU PAIEMENT"
    echo -e "${WHITE}Exécution du paiement en cours...${NC}"
    echo ""
    
    if ${MY_PATH}/PAYforSURE.sh "$keyfile" "$amount" "$dest_pubkey" "$comment"; then
        echo ""
        print_success "Paiement réussi !"
        echo -e "${WHITE}Transaction effectuée avec succès.${NC}"
        echo ""
        echo -e "${CYAN}Détails de la transaction:${NC}"
        echo -e "  ${WHITE}Montant: ${GREEN}$amount Ğ1${NC}"
        echo -e "  ${WHITE}Destinataire: ${CYAN}${dest_pubkey:0:20}...${NC}"
        if [[ -n "$comment" ]]; then
            echo -e "  ${WHITE}Commentaire: ${CYAN}$comment${NC}"
        fi
        echo ""
        echo -e "${GREEN}✅ Votre paiement a été traité avec succès !${NC}"
    else
        echo ""
        print_error "Paiement échoué !"
        echo -e "${WHITE}Veuillez vérifier les messages d'erreur ci-dessus et réessayer.${NC}"
        echo ""
        echo -e "${YELLOW}Suggestions de dépannage:${NC}"
        echo "  • Vérifiez votre connexion Internet"
        echo "  • Assurez-vous que votre clé privée est valide"
        echo "  • Vérifiez que le destinataire existe"
        echo "  • Contactez le support si le problème persiste"
        exit 1
    fi
}

# Run main function with all arguments
main "$@" 