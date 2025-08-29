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
    nostr_balances=()
    nostr_pubkeys=()
    
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
        
        echo -e "${WHITE}Comptes NOSTR disponibles: ${CYAN}${#account_names[@]} comptes trouvés${NC}"
        echo ""
        
        # Charger tous les comptes avec leurs données
        for account_name in "${account_names[@]}"; do
            g1pub=$(cat ~/.zen/game/nostr/${account_name}/G1PUBNOSTR 2>/dev/null)
            if [[ -n "$g1pub" ]]; then
                # Get balance from cache (much faster than G1check.sh)
                balance=$(cat ~/.zen/tmp/coucou/${g1pub}.COINS 2>/dev/null)
                if [[ -z "$balance" || "$balance" == "null" ]]; then
                    balance="0"
                fi
                
                # Check if .secret.dunikey exists
                keyfile="$HOME/.zen/game/nostr/${account_name}/.secret.dunikey"
                if [[ -f "$keyfile" ]]; then
                    nostr_accounts+=("$account_name")
                    nostr_keys+=("$keyfile")
                    nostr_balances+=("$balance")
                    nostr_pubkeys+=("$g1pub")
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
    
    # Configuration de la pagination
    local accounts_per_page=20
    local total_accounts=${#nostr_accounts[@]}
    local total_pages=$(( (total_accounts + accounts_per_page - 1) / accounts_per_page ))
    local current_page=1
    local filtered_accounts=("${nostr_accounts[@]}")
    local filtered_keys=("${nostr_keys[@]}")
    local filtered_balances=("${nostr_balances[@]}")
    local filtered_pubkeys=("${nostr_pubkeys[@]}")
    
    # Fonction pour afficher les comptes de la page courante
    display_accounts_page() {
        local start_index=$(( (current_page - 1) * accounts_per_page ))
        local end_index=$(( start_index + accounts_per_page - 1 ))
        local display_count=${#filtered_accounts[@]}
        
        if [[ $end_index -ge $display_count ]]; then
            end_index=$(( display_count - 1 ))
        fi
        
        echo -e "${WHITE}Comptes NOSTR (page $current_page/$total_pages) - ${display_count} comptes${NC}"
        echo ""
        
        # Affichage en tableau compact
        printf "%-4s %-25s %-12s %-20s\n" "N°" "Email" "Balance" "Public Key"
        echo "──────────────────────────────────────────────────────────────────────────────"
        
        for ((i=start_index; i<=end_index && i<display_count; i++)); do
            local account_name="${filtered_accounts[$i]}"
            local balance="${filtered_balances[$i]}"
            local g1pub="${filtered_pubkeys[$i]}"
            
            local display_index=$((i + 1))
            local short_pubkey="${g1pub:0:20}..."
            local short_email="${account_name:0:24}"
            if [[ ${#account_name} -gt 24 ]]; then
                short_email="${account_name:0:21}..."
            fi
            
            printf "${BLUE}%-4s${NC} ${WHITE}%-25s${NC} ${GREEN}%-12s${NC} ${CYAN}%-20s${NC}\n" \
                   "$display_index" "$short_email" "$balance Ğ1" "$short_pubkey"
        done
        echo ""
    }
    
    # Fonction pour afficher les commandes de navigation
    show_navigation_commands() {
        echo -e "${YELLOW}Navigation:${NC}"
        if [[ $total_pages -gt 1 ]]; then
            echo -e "  ${WHITE}n${NC} - Page suivante  ${WHITE}p${NC} - Page précédente"
        fi
        echo -e "  ${WHITE}s${NC} - Rechercher  ${WHITE}r${NC} - Réinitialiser  ${WHITE}q${NC} - Quitter"
        echo ""
    }
    
    # Fonction de recherche
    search_accounts() {
        echo -e "${WHITE}Rechercher par:${NC}"
        echo "  1. Email (ex: user@domain.com)"
        echo "  2. Clé publique G1 (ex: ABC123...)"
        echo "  3. HEX (ex: 12D3KooW...)"
        echo "  4. Annuler"
        echo ""
        read -p "> " search_type
        
        case $search_type in
            1|2|3)
                echo -e "${WHITE}Terme de recherche:${NC}"
                read -p "> " search_term
                
                if [[ -n "$search_term" ]]; then
                    # Réinitialiser les listes filtrées
                    filtered_accounts=()
                    filtered_keys=()
                    filtered_balances=()
                    filtered_pubkeys=()
                    
                    # Recherche dans les comptes existants
                    for i in "${!nostr_accounts[@]}"; do
                        local account_name="${nostr_accounts[$i]}"
                        local g1pub="${nostr_pubkeys[$i]}"
                        local balance="${nostr_balances[$i]}"
                        local keyfile="${nostr_keys[$i]}"
                        
                        local match=false
                        case $search_type in
                            1) # Email - recherche dans le nom du compte
                                if [[ "$account_name" == *"$search_term"* ]]; then
                                    match=true
                                fi
                                ;;
                            2) # G1 Public Key - recherche dans NOSTRG1PUB
                                local nostr_g1pub_file="$HOME/.zen/game/nostr/${account_name}/NOSTRG1PUB"
                                if [[ -f "$nostr_g1pub_file" ]]; then
                                    local nostr_g1pub=$(cat "$nostr_g1pub_file" 2>/dev/null)
                                    if [[ "$nostr_g1pub" == *"$search_term"* ]]; then
                                        match=true
                                    fi
                                fi
                                ;;
                            3) # HEX - recherche dans le fichier HEX
                                local hex_file="$HOME/.zen/game/nostr/${account_name}/HEX"
                                if [[ -f "$hex_file" ]]; then
                                    local hex_value=$(cat "$hex_file" 2>/dev/null)
                                    if [[ "$hex_value" == *"$search_term"* ]]; then
                                        match=true
                                    fi
                                fi
                                ;;
                        esac
                        
                        if [[ "$match" == "true" ]]; then
                            filtered_accounts+=("$account_name")
                            filtered_keys+=("$keyfile")
                            filtered_balances+=("$balance")
                            filtered_pubkeys+=("$g1pub")
                        fi
                    done
                    
                    # Réinitialiser la pagination
                    current_page=1
                    total_pages=$(( (${#filtered_accounts[@]} + accounts_per_page - 1) / accounts_per_page ))
                    if [[ $total_pages -eq 0 ]]; then
                        total_pages=1
                    fi
                    
                    print_success "Recherche terminée: ${#filtered_accounts[@]} comptes trouvés"
                fi
                ;;
            4)
                return
                ;;
            *)
                print_error "Choix invalide"
                ;;
        esac
    }
    
    # Boucle principale de sélection
    while true; do
        clear
        print_section "SELECTION DU COMPTE NOSTR"
        
        if [[ ${#filtered_accounts[@]} -eq 0 ]]; then
            print_error "Aucun compte trouvé avec les critères de recherche."
            echo ""
            echo -e "${YELLOW}Options:${NC}"
            echo "  r - Réinitialiser la recherche"
            echo "  q - Quitter"
            echo ""
            read -p "> " choice
            
            case $choice in
                "r"|"R")
                    # Réinitialiser les filtres
                    filtered_accounts=("${nostr_accounts[@]}")
                    filtered_keys=("${nostr_keys[@]}")
                    filtered_balances=("${nostr_balances[@]}")
                    filtered_pubkeys=("${nostr_pubkeys[@]}")
                    current_page=1
                    total_pages=$(( (${#filtered_accounts[@]} + accounts_per_page - 1) / accounts_per_page ))
                    ;;
                "q"|"Q")
                    print_warning "Sélection annulée."
                    exit 0
                    ;;
                *)
                    print_error "Choix invalide"
                    sleep 1
                    ;;
            esac
            continue
        fi
        
        # Afficher les comptes de la page courante
        display_accounts_page
        
        # Afficher les commandes de navigation
        show_navigation_commands
        
        # Afficher les options de sélection
        echo -e "${WHITE}Entrez le numéro du compte ou une commande:${NC}"
        read -p "> " selection
        
        case $selection in
            "n"|"N")
                if [[ $current_page -lt $total_pages ]]; then
                    current_page=$((current_page + 1))
                else
                    print_warning "Vous êtes déjà à la dernière page."
                    sleep 1
                fi
                ;;
            "p"|"P")
                if [[ $current_page -gt 1 ]]; then
                    current_page=$((current_page - 1))
                else
                    print_warning "Vous êtes déjà à la première page."
                    sleep 1
                fi
                ;;
            "s"|"S")
                search_accounts
                ;;
            "r"|"R")
                # Réinitialiser les filtres
                filtered_accounts=("${nostr_accounts[@]}")
                filtered_keys=("${nostr_keys[@]}")
                filtered_balances=("${nostr_balances[@]}")
                filtered_pubkeys=("${nostr_pubkeys[@]}")
                current_page=1
                total_pages=$(( (${#filtered_accounts[@]} + accounts_per_page - 1) / accounts_per_page ))
                print_success "Recherche réinitialisée"
                sleep 1
                ;;
            "q"|"Q")
                print_warning "Sélection annulée."
                exit 0
                ;;
            *)
                # Vérifier si c'est un numéro de compte valide
                if [[ "$selection" =~ ^[0-9]+$ ]]; then
                    local selected_index=$((selection - 1))
                    if [[ $selected_index -ge 0 && $selected_index -lt ${#filtered_accounts[@]} ]]; then
                        selected_account="${filtered_accounts[$selected_index]}"
                        selected_keyfile="${filtered_keys[$selected_index]}"
                        selected_balance="${filtered_balances[$selected_index]}"
                        selected_pubkey="${filtered_pubkeys[$selected_index]}"
                        
                        echo ""
                        print_success "Compte sélectionné: $selected_account"
                        echo -e "${WHITE}Fichier de clé: ${CYAN}$selected_keyfile${NC}"
                        echo -e "${WHITE}Balance: ${GREEN}$selected_balance Ğ1${NC}"
                        echo -e "${WHITE}Clé publique: ${CYAN}${selected_pubkey:0:20}...${NC}"
                        return
                    else
                        print_error "Numéro de compte invalide. Veuillez entrer un nombre entre 1 et ${#filtered_accounts[@]}."
                        sleep 2
                    fi
                else
                    print_error "Entrée invalide. Veuillez entrer un numéro de compte ou une commande."
                    sleep 1
                fi
                ;;
        esac
    done
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
    
    # Get source balance from cache (much faster than G1check.sh)
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