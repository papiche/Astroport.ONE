#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ primal_wallet_control.sh
#~ Generic primal transaction control for wallet monitoring
################################################################################
# This script monitors wallet transactions and controls that incoming
# transactions come from wallets with the same primal source.
# It implements intrusion detection with automatic redirection to UPLANETNAME.INTRUSION.
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

# Function to get primal source of a wallet
get_primal_source() {
    local wallet_pubkey="$1"
    local attempts=0
    local success=false
    local result=""

    # Check if cache exists (primal source never changes, so cache is permanently valid)
    local cache_file="$HOME/.zen/tmp/coucou/${wallet_pubkey}.primal"
    if [[ -f "$cache_file" ]]; then
        local cached_primal=$(cat "$cache_file" 2>/dev/null)
        if [[ -n "$cached_primal" && "$cached_primal" != "null" ]]; then
            echo "Using cached primal source for ${wallet_pubkey:0:8}"
            echo "$cached_primal"
            return 0
        fi
    fi

    while [[ $attempts -lt 3 && $success == false ]]; do
        BMAS_NODE=$(${MY_PATH}/duniter_getnode.sh BMAS | tail -n 1)
        if [[ ! -z $BMAS_NODE ]]; then
            echo "Trying primal check with BMAS NODE: $BMAS_NODE (attempt $((attempts + 1)))"

            silkaj_output=$(silkaj --endpoint "$BMAS_NODE" --json money primal ${wallet_pubkey} 2>/dev/null)
            if echo "$silkaj_output" | jq empty 2>/dev/null; then
                result=$(echo "$silkaj_output" | jq -r '.primal_source_pubkey')
                if [[ ! -z ${result} && ${result} != "null" ]]; then
                    success=true
                    # Cache the result (permanently valid)
                    mkdir -p "$HOME/.zen/tmp/coucou"
                    echo "$result" > "$cache_file"
                    break
                fi
            else
                echo "Warning: silkaj did not return valid JSON for $wallet_pubkey"
            fi
        fi

        attempts=$((attempts + 1))
        if [[ $attempts -lt 3 ]]; then
            sleep 2
        fi
    done

    echo "$result"
}

# Function to get wallet transaction history
get_wallet_history() {
    local wallet_pubkey="$1"
    local output_file="$2"
    local attempts=0
    local success=false

    # Check if cache exists and is recent (less than 30 minutes old)
    local cache_file="$HOME/.zen/tmp/coucou/${wallet_pubkey}.history"
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 1800 ]]; then  # 30 minutes = 1800 seconds
            if [[ -s "$cache_file" ]]; then
                echo "Using cached transaction history for ${wallet_pubkey:0:8}"
                cp "$cache_file" "$output_file"
                return 0
            fi
        fi
    fi

    while [[ $attempts -lt 3 && $success == false ]]; do
        BMAS_NODE=$(cat ~/.zen/tmp/current.duniter.bmas 2>/dev/null)
        if [[ ! -z $BMAS_NODE ]]; then
            echo "Trying history with BMAS NODE: $BMAS_NODE (attempt $((attempts + 1)))"

            # Get the full JSON response and extract history array
            ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
            silkaj --endpoint "$BMAS_NODE" --json money history ${wallet_pubkey} 2>/dev/null > ${output_file}.full

            if [[ -s ${output_file}.full ]]; then
                # Extract and transform the history to the expected format
                jq -r '.history[] | {
                    date: .Date,
                    pubkey: (.["Issuers/Recipients"] | split(":")[0]),
                    amount: (.["Amounts Ğ1"] | tonumber),
                    comment: (.Reference // "")
                }' ${output_file}.full | jq -s '.' > ${output_file}

                if [[ -s ${output_file} ]]; then
                    success=true
                    # Cache the result
                    mkdir -p "$HOME/.zen/tmp/coucou"
                    cp "$output_file" "$cache_file"
                    rm -f ${output_file}.full
                    break
                else
                    echo "Warning: No valid transaction history extracted from silkaj response"
                fi
            fi
            rm -f ${output_file}.full
        fi

        attempts=$((attempts + 1))
        if [[ $attempts -lt 3 ]]; then
            BMAS_NODE=$(${MY_PATH}/duniter_getnode.sh BMAS | tail -n 1)
        fi
    done

    return $([[ $success == true ]])
}

# Function to create INTRUSION wallet if it doesn't exist
create_intrusion_wallet() {
    local intrusion_dunikey="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
    
    # Check if wallet already exists
    if [[ -f "$intrusion_dunikey" ]]; then
        return 0  # Wallet already exists
    fi
    
    echo "Creating UPLANETNAME.INTRUSION wallet..."
    
    # Create directory if it doesn't exist
    local wallet_dir=$(dirname "$intrusion_dunikey")
    [[ ! -d "$wallet_dir" ]] && mkdir -p "$wallet_dir"
    
    # Create wallet using keygen (same pattern as UPLANET.init.sh)
    if [[ -x "${MY_PATH}/keygen" ]]; then
        "${MY_PATH}/keygen" -t duniter -o "$intrusion_dunikey" "${UPLANETNAME}.INTRUSION" "${UPLANETNAME}.INTRUSION"
    else
        echo "ERROR: keygen tool not found at ${MY_PATH}/keygen"
        return 1
    fi
    
    # Set proper permissions
    chmod 600 "$intrusion_dunikey" 2>/dev/null
    
    if [[ -f "$intrusion_dunikey" ]]; then
        local pubkey=$(cat "$intrusion_dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
        echo "✅ UPLANETNAME.INTRUSION wallet created successfully"
        echo "🔑 Public key: ${pubkey:0:8}..."
        return 0
    else
        echo "❌ Failed to create UPLANETNAME.INTRUSION wallet"
        return 1
    fi
}

# Function to send alert email
send_alert_email() {
    local player_email="$1"
    local wallet_pubkey="$2"
    local intrusion_pubkey="$3"
    local amount="$4"
    local master_primal="$5"
    local intrusion_count="$6"
    local alert_type="$7"

    local template_file=""
    case "$alert_type" in
        "intrusion")
            template_file="${MY_PATH}/../templates/NOSTR/wallet_alert.html"
            ;;
        "redirection")
            template_file="${MY_PATH}/../templates/NOSTR/wallet_redirection.html"
            ;;
        *)
            echo "Unknown alert type: $alert_type (supported: intrusion, redirection)"
            return 1
            ;;
    esac

    if [[ -f "$template_file" ]]; then
        # Replace placeholders in template
        sed -e "s/{PLAYER}/$player_email/g" \
            -e "s/{WALLET_PUBKEY}/${wallet_pubkey:0:8}/g" \
            -e "s/{INTRUSION_PUBKEY}/${intrusion_pubkey:0:8}/g" \
            -e "s/{AMOUNT}/$amount/g" \
            -e "s/{MASTER_PRIMAL}/${master_primal:0:8}/g" \
            -e "s/{INTRUSION_COUNT}/$intrusion_count/g" \
            -e "s|{myIPFS}|$myIPFS|g" \
            "$template_file" > ~/.zen/tmp/primal_alert.html

        # Send alert
        ${MY_PATH}/mailjet.sh "${player_email}" ~/.zen/tmp/primal_alert.html "PRIMAL WALLET ${alert_type^^} ALERT"
    else
        echo "Alert template not found: $template_file"
        return 1
    fi
}

# Note: All intrusions are redirected to UPLANETNAME.INTRUSION to centralize intrusion management
# No refunds to sender to prevent potential transaction loops

# Function to count existing intrusions from transaction history
count_existing_intrusions() {
    local wallet_pubkey="$1"
    local master_primal="$2"
    local temp_history_file="$3"

    local intrusion_count=0

    if [[ -s "$temp_history_file" ]]; then
        # Convert JSON to inline format for processing
        local inline_history_file=$(mktemp)
        cat "$temp_history_file" | jq -rc '.[]' > "$inline_history_file"

        # Count refund transactions that match intrusion pattern
        while read LINE; do
            [[ -z "$LINE" ]] && continue

            local JSON="$LINE"
            local TXIDATE=$(echo "$JSON" | jq -r '.date')
            local TXIPUBKEY=$(echo "$JSON" | jq -r '.pubkey')
            local TXIAMOUNT=$(echo "$JSON" | jq -r '.amount')
            local COMMENT=$(echo "$JSON" | jq -r '.comment // ""')

            # Skip transactions with invalid or empty data
            if [[ -z "$TXIPUBKEY" || "$TXIPUBKEY" == "null" || -z "$TXIAMOUNT" || "$TXIAMOUNT" == "null" ]]; then
                continue
            fi

            # Look for outgoing transactions (negative amount) with intrusion comments
            if [[ $(echo "$TXIAMOUNT < 0" | bc -l) -eq 1 ]]; then
                # Check if this is an intrusion-related transaction (refund or redirect)
                if [[ "$COMMENT" == *"INTRUSION"* ]]; then
                    echo "Found existing intrusion transaction: ${TXIAMOUNT} G1 to ${TXIPUBKEY:0:8} (${COMMENT})" >&2
                    intrusion_count=$((intrusion_count + 1))
                fi
            fi
        done < "$inline_history_file"

        rm -f "$inline_history_file"
    fi

    echo "$intrusion_count"
}

# Main function to control primal transactions
control_primal_transactions() {
    local wallet_dunikey="$1"      # Path to wallet dunikey file
    local wallet_pubkey="$2"       # Wallet public key
    local master_primal="$3"       # Expected master primal source
    local player_email="$4"        # Player email for alerts

    [[ -z "$wallet_dunikey" || -z "$wallet_pubkey" || -z "$master_primal" || -z "$player_email" ]] && {
        echo "ERROR: Missing required parameters"
        echo "Usage: control_primal_transactions <wallet_dunikey> <wallet_pubkey> <master_primal> <player_email>"
        return 1
    }

    [[ ! -f "$wallet_dunikey" ]] && {
        echo "ERROR: Wallet dunikey file not found: $wallet_dunikey"
        return 1
    }

    # Check if player is CAPTAIN - authorize UPLANET sources as valid primal
    local is_captain=false
    if [[ "$player_email" == "$CAPTAINEMAIL" ]]; then
        is_captain=true
        echo "CAPTAIN DETECTED: Authorizing UPLANET sources as valid primal"
    fi

    echo "Checking primal transactions for wallet ${wallet_pubkey:0:8}"
    echo "Master primal: ${master_primal:0:8}"

    # Get wallet transaction history first
    local temp_history_file=$(mktemp)
    get_wallet_history "${wallet_pubkey}" "$temp_history_file"

    if [[ ! -s "$temp_history_file" ]]; then
        echo "NO TRANSACTION HISTORY FOR WALLET ${wallet_pubkey:0:8}"
        rm -f "$temp_history_file"
        return 0
    fi

    # Count existing intrusions from transaction history (no cache dependency)
    local existing_intrusions=$(count_existing_intrusions "${wallet_pubkey}" "${master_primal}" "$temp_history_file")
    echo "Existing intrusions detected from history: $existing_intrusions"
    echo "Policy: ALL intrusions = REDIRECT to UPLANETNAME.INTRUSION (no refunds to avoid loops)"

    # Convert JSON to inline format for processing new transactions
    local inline_history_file=$(mktemp)
    cat "$temp_history_file" | jq -rc '.[]' > "$inline_history_file"

    local new_intrusions=0

    # Process each transaction for new intrusions
    while read LINE; do
        [[ -z "$LINE" ]] && continue

        local JSON="$LINE"
        local TXIDATE=$(echo "$JSON" | jq -r '.date')
        local TXIPUBKEY=$(echo "$JSON" | jq -r '.pubkey')
        local TXIAMOUNT=$(echo "$JSON" | jq -r '.amount')

        # Skip transactions with invalid or empty data
        if [[ -z "$TXIPUBKEY" || "$TXIPUBKEY" == "null" || -z "$TXIAMOUNT" || "$TXIAMOUNT" == "null" ]]; then
            echo "Skipping transaction with invalid data: pubkey='$TXIPUBKEY', amount='$TXIAMOUNT'"
            continue
        fi

        # Skip outgoing transactions (refunds)
        [[ $(echo "$TXIAMOUNT < 0" | bc -l) -eq 1 ]] && continue

        # Check primal transaction for incoming transaction
        echo "# RX from ${TXIPUBKEY:0:8}.... checking primal transaction..."
        local tx_primal=$(get_primal_source "${TXIPUBKEY}")

        if [[ -n "$tx_primal" && "$tx_primal" != "null" ]]; then
            # For CAPTAIN: also authorize UPLANET sources as valid primal (unified architecture)
            local is_valid_primal=false
            if [[ "$is_captain" == true ]]; then
                # CAPTAIN can receive from master_primal (UPLANETNAME_G1) and other UPLANET wallets with same primal
                # Since all wallets are now initialized from UPLANETNAME_G1, check if tx_primal matches the unified source
                if [[ "$master_primal" == "$tx_primal" || "$tx_primal" == "$UPLANETG1PUB" || "$tx_primal" == "$UPLANETNAME_SOCIETY" ]]; then
                    is_valid_primal=true
                fi
            else
                # Regular players: only master_primal (UPLANETNAME_G1) is valid
                if [[ "$master_primal" == "$tx_primal" ]]; then
                    is_valid_primal=true
                fi
            fi

            # Verify if transaction is from a valid wallet with same primal
            if [[ "$is_valid_primal" == false ]]; then
                echo "PRIMAL WALLET INTRUSION ALERT for ${wallet_pubkey:0:8} from ${TXIPUBKEY:0:8} (primal: ${tx_primal:0:8})"

                # TOUTES LES INTRUSIONS: Redirection directe vers UPLANETNAME.INTRUSION (centralise la gestion)
                local current_total=$((existing_intrusions + new_intrusions + 1))
                echo "INTRUSION DETECTED ($current_total) - REDIRECTING TO UPLANETNAME.INTRUSION"
                echo "💡 INFO: Versements Ğ1 doivent être faits vers UPLANETNAME_G1 uniquement"
                
                # Ensure INTRUSION wallet exists, create if necessary
                if ! create_intrusion_wallet; then
                    echo "ERROR: Cannot create INTRUSION wallet, aborting intrusion handling"
                    continue
                fi
                
                # Get INTRUSION wallet public key
                local intrusion_pubkey=$(cat "$HOME/.zen/game/uplanet.INTRUSION.dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
                
                if [[ -z "$intrusion_pubkey" ]]; then
                    echo "ERROR: Cannot extract public key from INTRUSION wallet"
                    continue
                fi
                
                # Rediriger les fonds vers UPLANETNAME.INTRUSION
                ${MY_PATH}/PAYforSURE.sh "${wallet_dunikey}" "${TXIAMOUNT}" "${intrusion_pubkey}" "INTRUSION:REDIRECT:UPLANETNAME.INTRUSION:${TXIPUBKEY:0:8}" 2>/dev/null
                
                if [[ $? -eq 0 ]]; then
                    echo "INTRUSION REDIRECTED: ${TXIAMOUNT} G1 sent to UPLANETNAME.INTRUSION (${intrusion_pubkey:0:8})"
                    echo "💰 Fonds intrusifs centralisés dans le portefeuille INTRUSION"
                    new_intrusions=$((new_intrusions + 1))
                    
                    # Send alert for redirection (always notify)
                    send_alert_email "${player_email}" "${wallet_pubkey}" "${TXIPUBKEY}" "${TXIAMOUNT}" "${master_primal}" "$current_total" "redirection"
                else
                    echo "ERROR: Failed to redirect intrusion to UPLANETNAME.INTRUSION"
                fi
            else
                if [[ "$is_captain" == true ]]; then
                    echo "GOOD PRIMAL WALLET TX by ${tx_primal:0:8} (CAPTAIN authorized source)"
                else
                    echo "GOOD PRIMAL WALLET TX by ${tx_primal:0:8}"
                fi
            fi
        else
            echo "WARNING: Could not determine primal source for ${TXIPUBKEY:0:8}"
        fi
    done < "$inline_history_file"

    # Final summary
    local total_intrusions=$((existing_intrusions + new_intrusions))
    if [[ $new_intrusions -gt 0 ]]; then
        echo "NEW INTRUSIONS DETECTED: $new_intrusions (Total: $total_intrusions)"
        echo "💡 INFO: Toutes les intrusions redirigées vers UPLANETNAME.INTRUSION"
        echo "💰 Fonds intrusifs récupérés par la coopérative UPlanet"
        echo "📧 Alertes email envoyées à ${player_email}"
    else
        echo "NO NEW INTRUSIONS DETECTED (Total: $total_intrusions)"
    fi

    # Cleanup
    rm -f "$temp_history_file" "$inline_history_file"
    return 0    
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script called directly
    if [[ $# -lt 4 ]]; then
        echo "Usage: $0 <wallet_dunikey> <wallet_pubkey> <master_primal> <player_email>"
        echo ""
        echo "Parameters:"
        echo "  wallet_dunikey      Path to wallet dunikey file"
        echo "  wallet_pubkey       Wallet public key"
        echo "  master_primal       Expected master primal source"
        echo "  player_email        Player email for alerts"
        echo ""
        echo "Example:"
        echo "  $0 ~/.zen/game/players/player/secret.dunikey \\"
        echo "      5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo \\"
        echo "      AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z \\"
        echo "      player@example.com"
        exit 1
    fi

    control_primal_transactions "$@"
fi
