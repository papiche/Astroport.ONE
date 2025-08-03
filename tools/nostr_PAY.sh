#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_PAY.sh
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

# Function to display usage information
usage() {
    echo "Usage: $ME [keyfile] [amount] [dest_pubkey] [comment]"
    echo ""
    echo "Parameters:"
    echo "  keyfile     - Path to the .secret.dunikey file"
    echo "  amount      - Amount to transfer (in G1)"
    echo "  dest_pubkey - Destination public key"
    echo "  comment     - Optional comment for the transaction"
    echo ""
    echo "If no parameters are provided, the script will launch an interactive assistant."
    exit 1
}

# Function to list available NOSTR accounts and prompt user to select one
select_nostr_account() {
    echo "Available NOSTR accounts:"
    echo "========================="
    
    # Find all .secret.dunikey files in NOSTR directories
    nostr_accounts=()
    nostr_keys=()
    
    if [[ -d ~/.zen/game/nostr ]]; then
        while IFS= read -r -d '' keyfile; do
            if [[ -f "$keyfile" ]]; then
                # Extract account name from path
                account_path=$(dirname "$keyfile")
                account_name=$(basename "$account_path")
                
                # Get public key from dunikey file
                pubkey=$(grep "pub:" "$keyfile" | cut -d ' ' -f 2 2>/dev/null)
                
                if [[ -n "$pubkey" ]]; then
                    # Get balance
                    balance=$(${MY_PATH}/COINScheck.sh "$pubkey" 2>/dev/null | tail -n 1)
                    if [[ -z "$balance" || "$balance" == "null" ]]; then
                        balance="0"
                    fi
                    
                    nostr_accounts+=("$account_name")
                    nostr_keys+=("$keyfile")
                    
                    echo "${#nostr_accounts[@]}) $account_name"
                    echo "   Public Key: $pubkey"
                    echo "   Balance: $balance Ğ1"
                    echo "   Key File: $keyfile"
                    echo ""
                fi
            fi
        done < <(find ~/.zen/game/nostr -name ".secret.dunikey" -print0 2>/dev/null)
    fi
    
    if [[ ${#nostr_accounts[@]} -eq 0 ]]; then
        echo "No NOSTR accounts found with .secret.dunikey files."
        echo "Please ensure you have NOSTR accounts set up in ~/.zen/game/nostr/"
        exit 1
    fi
    
    # Prompt user to select account
    read -p "Select the number corresponding to the account: " selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#nostr_accounts[@]} ]; then
        echo "Invalid selection."
        exit 1
    fi
    
    selected_index=$((selection - 1))
    selected_account="${nostr_accounts[$selected_index]}"
    selected_keyfile="${nostr_keys[$selected_index]}"
    
    echo "Selected account: $selected_account"
    echo "Key file: $selected_keyfile"
}

# Function to get payment details interactively
get_payment_details() {
    echo ""
    echo "Payment Details"
    echo "==============="
    
    # Get amount
    while true; do
        read -p "Enter amount to transfer (in G1): " amount
        if [[ -n "$amount" ]] && [[ $amount =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            break
        else
            echo "Please enter a valid amount (e.g., 10.5)"
        fi
    done
    
    # Get destination public key
    while true; do
        read -p "Enter destination public key: " dest_pubkey
        if [[ -n "$dest_pubkey" ]] && [[ ${#dest_pubkey} -eq 43 ]]; then
            break
        else
            echo "Please enter a valid public key (43 characters)"
        fi
    done
    
    # Get optional comment
    read -p "Enter comment (optional): " comment
}

# Function to validate parameters
validate_parameters() {
    local keyfile="$1"
    local amount="$2"
    local dest_pubkey="$3"
    
    # Validate keyfile
    if [[ ! -f "$keyfile" ]]; then
        echo "ERROR: Key file '$keyfile' not found"
        exit 1
    fi
    
    # Validate amount
    if [[ -z "$amount" ]] || ! [[ $amount =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "ERROR: Invalid amount '$amount'"
        exit 1
    fi
    
    # Validate destination public key
    if [[ -z "$dest_pubkey" ]] || [[ ${#dest_pubkey} -ne 43 ]]; then
        echo "ERROR: Invalid destination public key '$dest_pubkey'"
        exit 1
    fi
    
    # Check if amount is greater than 0
    if (( $(echo "$amount <= 0" | bc -l) )); then
        echo "ERROR: Amount must be greater than 0"
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
    
    # Get source balance
    source_balance=$(${MY_PATH}/COINScheck.sh "$source_pubkey" 2>/dev/null | tail -n 1)
    if [[ -z "$source_balance" || "$source_balance" == "null" ]]; then
        source_balance="0"
    fi
    
    # Get destination balance
    dest_balance=$(${MY_PATH}/COINScheck.sh "$dest_pubkey" 2>/dev/null | tail -n 1)
    if [[ -z "$dest_balance" || "$dest_balance" == "null" ]]; then
        dest_balance="0"
    fi
    
    echo ""
    echo "Payment Summary"
    echo "==============="
    echo "From: $source_pubkey"
    echo "      Balance: $source_balance Ğ1"
    echo "To:   $dest_pubkey"
    echo "      Balance: $dest_balance Ğ1"
    echo "Amount: $amount Ğ1"
    if [[ -n "$comment" ]]; then
        echo "Comment: $comment"
    fi
    echo ""
    
    # Check if sufficient balance
    if (( $(echo "$source_balance < $amount" | bc -l) )); then
        echo "ERROR: Insufficient balance. Available: $source_balance Ğ1, Required: $amount Ğ1"
        exit 1
    fi
    
    read -p "Confirm payment? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Payment cancelled."
        exit 0
    fi
}

# Main script logic
main() {
    # Check if parameters are provided
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        echo "NOSTR Payment Assistant"
        echo "======================"
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
    echo ""
    echo "Executing payment..."
    echo "==================="
    
    if ${MY_PATH}/PAYforSURE.sh "$keyfile" "$amount" "$dest_pubkey" "$comment"; then
        echo ""
        echo "✅ Payment successful!"
        echo "Transaction completed successfully."
    else
        echo ""
        echo "❌ Payment failed!"
        echo "Please check the error messages above and try again."
        exit 1
    fi
}

# Run main function with all arguments
main "$@" 