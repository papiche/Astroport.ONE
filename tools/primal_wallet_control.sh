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
# It implements intrusion detection with automatic redirection to UPLANETNAME_INTRUSION.
# 
# INTRUSION PAIRING SYSTEM:
# - Each intrusive transaction gets a unique ID based on its date/time
# - Redirection transactions include this ID in their comment for precise pairing
# - This prevents double detection and enables accurate tracking of processed intrusions
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

# Function to generate Cesium wallet link
generate_cesium_link() {
    local pubkey="$1"
    echo "$CESIUMIPFS/#/app/wot/${pubkey}/"
}

# Function to extract and verify ZEN Card owner from transaction comment
get_zencard_owner() {
    local comment="$1"
    local tx_pubkey="$2"
    
    # Extract email from comment
    local email=$(echo "$comment" | grep -o '[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}' | head -n 1)
    
    # Verify ZEN Card exists and matches
    if [[ -n "$email" && -f "$HOME/.zen/game/players/${email}/.g1pub" ]]; then
        local zencard_g1pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
        [[ "$zencard_g1pub" == "$tx_pubkey" ]] && echo "$email"
    fi
}

# Function to display wallet information with Cesium links
display_wallet_info() {
    local title="$1"
    local pubkey="$2"
    local description="$3"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏦 $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Description: $description"
    echo "🔑 Public Key: $pubkey"
    echo "🔗 Cesium Link: $(generate_cesium_link "$pubkey")"
    echo ""
}

# Function to get primal source of a wallet
# This function creates and maintains permanent cache files in ~/.zen/tmp/coucou/
# Primal source never changes on blockchain, so cache is valid indefinitely
get_primal_source() {
    local wallet_pubkey="$1"
    local attempts=0
    local success=false
    local result=""
    local silent_mode="${2:-false}"  # Optional parameter for silent output

    # Ensure cache directory exists
    mkdir -p "$HOME/.zen/tmp/coucou"

    # Check if cache exists (primal source never changes, so cache is permanently valid)
    local cache_file="$HOME/.zen/tmp/coucou/${wallet_pubkey}.primal"
    if [[ -f "$cache_file" && -s "$cache_file" ]]; then
        local cached_primal=$(cat "$cache_file" 2>/dev/null)
        if [[ -n "$cached_primal" && "$cached_primal" != "null" ]]; then
            [[ "$silent_mode" != "true" ]] && echo "Using cached primal source for ${wallet_pubkey:0:8}"
            [[ "$silent_mode" != "true" ]] && echo "🔗 Cesium: $(generate_cesium_link "$wallet_pubkey")"
            echo "$cached_primal"
            return 0
        fi
    fi

    # No valid cache found, query blockchain
    [[ "$silent_mode" != "true" ]] && echo "Fetching primal source for ${wallet_pubkey:0:8} from blockchain..."
    
    while [[ $attempts -lt 3 && $success == false ]]; do
        BMAS_NODE=$(${MY_PATH}/duniter_getnode.sh BMAS | tail -n 1)
        if [[ ! -z $BMAS_NODE ]]; then
            [[ "$silent_mode" != "true" ]] && echo "Trying primal check with BMAS NODE: $BMAS_NODE (attempt $((attempts + 1)))"

            silkaj_output=$(silkaj --endpoint "$BMAS_NODE" --json money primal ${wallet_pubkey} 2>/dev/null)
            if echo "$silkaj_output" | jq empty 2>/dev/null; then
                result=$(echo "$silkaj_output" | jq -r '.primal_source_pubkey')
                if [[ ! -z ${result} && ${result} != "null" ]]; then
                    success=true
                    # Cache the result (permanently valid - primal never changes)
                    echo "$result" > "$cache_file"
                    chmod 644 "$cache_file"
                    [[ "$silent_mode" != "true" ]] && echo "✅ Primal source cached: $cache_file"
                    [[ "$silent_mode" != "true" ]] && echo "🔗 Cesium: $(generate_cesium_link "$wallet_pubkey")"
                    break
                fi
            else
                [[ "$silent_mode" != "true" ]] && echo "Warning: silkaj did not return valid JSON for $wallet_pubkey"
            fi
        fi

        attempts=$((attempts + 1))
        if [[ $attempts -lt 3 ]]; then
            sleep 2
        fi
    done

    if [[ "$success" == false ]]; then
        [[ "$silent_mode" != "true" ]] && echo "❌ Failed to fetch primal source for ${wallet_pubkey:0:8} after $attempts attempts"
        # Create empty cache file to indicate failure and avoid repeated queries
        touch "$cache_file"
    fi

    echo "$result"
}

# Utility function to ensure primal cache exists for a wallet
# Can be called by any script that needs primal information
ensure_primal_cache() {
    local wallet_pubkey="$1"
    local cache_file="$HOME/.zen/tmp/coucou/${wallet_pubkey}.primal"
    
    # If cache doesn't exist or is empty, fetch it
    if [[ ! -s "$cache_file" ]]; then
        get_primal_source "$wallet_pubkey" "true" > /dev/null
    fi
    
    # Return the cached value (may be empty if fetch failed)
    cat "$cache_file" 2>/dev/null
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
    
    echo "Creating UPLANETNAME_INTRUSION wallet..."
    
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
        echo "✅ UPLANETNAME_INTRUSION wallet created successfully"
        echo "🔑 Public key: ${pubkey:0:8}..."
        return 0
    else
        echo "❌ Failed to create UPLANETNAME_INTRUSION wallet"
        return 1
    fi
}

# Function to send redirection alert email
send_redirection_alert() {
    local player_email="$1"
    local wallet_pubkey="$2"
    local intrusion_sender_pubkey="$3"
    local intrusion_primal_pubkey="$4"
    local amount="$5"
    local master_primal="$6"
    local intrusion_count="$7"
    local intrusion_wallet_pubkey="$8"

    local template_file="${MY_PATH}/../templates/NOSTR/wallet_redirection.html"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -f "$template_file" ]]; then
        # Generate Cesium links
        local wallet_cesium_link=$(generate_cesium_link "$wallet_pubkey")
        local sender_cesium_link=$(generate_cesium_link "$intrusion_sender_pubkey")
        local primal_cesium_link=$(generate_cesium_link "$intrusion_primal_pubkey")
        local master_cesium_link=$(generate_cesium_link "$master_primal")
        local intrusion_cesium_link=$(generate_cesium_link "$intrusion_wallet_pubkey")
        local uplanet_g1_cesium_link=""
        
        # Get UPLANET G1 wallet info if available
        if [[ -n "$UPLANETNAME_G1" ]]; then
            uplanet_g1_cesium_link=$(generate_cesium_link "$UPLANETNAME_G1")
        fi

        # Replace placeholders in template
        sed -e "s/{PLAYER}/$player_email/g" \
            -e "s/{TIMESTAMP}/$timestamp/g" \
            -e "s/{WALLET_PUBKEY}/${wallet_pubkey:0:8}/g" \
            -e "s|{WALLET_CESIUM_LINK}|$wallet_cesium_link|g" \
            -e "s/{INTRUSION_SENDER_PUBKEY}/${intrusion_sender_pubkey:0:8}/g" \
            -e "s|{SENDER_CESIUM_LINK}|$sender_cesium_link|g" \
            -e "s/{INTRUSION_PRIMAL_PUBKEY}/${intrusion_primal_pubkey:0:8}/g" \
            -e "s|{PRIMAL_CESIUM_LINK}|$primal_cesium_link|g" \
            -e "s/{AMOUNT}/$amount/g" \
            -e "s/{MASTER_PRIMAL}/${master_primal:0:8}/g" \
            -e "s|{MASTER_CESIUM_LINK}|$master_cesium_link|g" \
            -e "s/{INTRUSION_COUNT}/$intrusion_count/g" \
            -e "s/{INTRUSION_WALLET_PUBKEY}/${intrusion_wallet_pubkey:0:8}/g" \
            -e "s|{INTRUSION_CESIUM_LINK}|$intrusion_cesium_link|g" \
            -e "s/{UPLANET_G1_PUBKEY}/${UPLANETNAME_G1:0:8}/g" \
            -e "s|{UPLANET_G1_CESIUM_LINK}|$uplanet_g1_cesium_link|g" \
            -e "s|{myIPFS}|$myIPFS|g" \
            "$template_file" > ~/.zen/tmp/primal_alert.html

        # Enhanced email title with more context
        local email_title="🚨 INTRUSION #${intrusion_count} - ${amount} Ğ1 redirigés vers UPLANETNAME_INTRUSION - ${wallet_pubkey:0:8}"
        
        # Send alert
        ${MY_PATH}/mailjet.sh "${player_email}" "$HOME/.zen/tmp/primal_alert.html" "$email_title"
        
        echo "📧 Enhanced alert email sent to $player_email with title: $email_title"
    else
        echo "Redirection template not found: $template_file"
        return 1
    fi
}


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

        # Count redirection transactions that match intrusion pattern
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

            # Look for outgoing transactions (negative amount) with intrusion redirection comments
            if [[ $(echo "$TXIAMOUNT < 0" | bc -l) -eq 1 ]]; then
                # Check if this is an intrusion redirection transaction (contains ID for pairing)
                if [[ "$COMMENT" == *"INTRUSION"* && "$COMMENT" == *"ID:"* ]]; then
                    local tx_id=$(echo "$COMMENT" | grep -o 'ID:[^:]*' | cut -d: -f2)
                    echo "Found existing intrusion redirection: ${TXIAMOUNT} G1 to ${TXIPUBKEY:0:8} (ID: ${tx_id})" >&2
                    intrusion_count=$((intrusion_count + 1))
                elif [[ "$COMMENT" == *"INTRUSION"* ]]; then
                    # Legacy intrusion without ID (for backward compatibility)
                    echo "Found legacy intrusion transaction: ${TXIAMOUNT} G1 to ${TXIPUBKEY:0:8} (${COMMENT})" >&2
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
        echo "🎖️ CAPTAIN DETECTED: Authorizing UPLANET sources as valid primal"
        
        # Display UPLANET system wallets for CAPTAIN
        echo ""
        echo "🌍 UPLANET SYSTEM WALLETS (CAPTAIN AUTHORIZED SOURCES):"
        echo "────────────────────────────────────────────────────────────────────────────"
        
        if [[ -n "$UPLANETG1PUB" ]]; then
            display_wallet_info "UPLANET MAIN WALLET" "$UPLANETG1PUB" "Main UPLANET wallet for locative services"
        fi
        
        if [[ -n "$UPLANETNAME_SOCIETY" ]]; then
            display_wallet_info "UPLANET SOCIETY WALLET" "$UPLANETNAME_SOCIETY" "Cooperative holders wallet"
        fi
        
        if [[ -n "$UPLANETNAME_G1" ]]; then
            display_wallet_info "UPLANET G1 DONATION WALLET" "$UPLANETNAME_G1" "Ğ1 donation wallet"
        fi
    fi

    # Display wallet information with Cesium links
    display_wallet_info "MONITORED WALLET" "$wallet_pubkey" "Player wallet under primal transaction control"
    display_wallet_info "MASTER PRIMAL SOURCE" "$master_primal" "Expected primal source for valid transactions"
    
    echo "🔍 Starting primal transaction analysis..."

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
    echo "Policy: ALL intrusions = REDIRECT to UPLANETNAME_INTRUSION (no refunds to avoid loops)"

    # Convert JSON to inline format for processing new transactions
    local inline_history_file=$(mktemp)
    cat "$temp_history_file" | jq -rc '.[]' > "$inline_history_file"

    local new_intrusions=0
    local incoming_tx_count=0

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

        # Count incoming transactions
        incoming_tx_count=$((incoming_tx_count + 1))

        # WoT Dragon Identification Exception: Allow 0.01 Ğ1 transactions ONLY as second transaction
        # This allows NODE wallet to receive WoT identification from Dragon captains
        local is_wot_identification=false
        if [[ $(echo "$TXIAMOUNT == 0.01" | bc -l) -eq 1 && $incoming_tx_count -eq 2 ]]; then
            is_wot_identification=true
            echo "# WoT Dragon Identification VALID: 0.01 Ğ1 from ${TXIPUBKEY:0:8} - SECOND TRANSACTION - AUTHORIZED"
            
            # Cache second transaction detection
            local cache_2nd_file="$HOME/.zen/tmp/coucou/${wallet_pubkey}.2nd"
            mkdir -p "$HOME/.zen/tmp/coucou"
            echo "${TXIPUBKEY}" > "$cache_2nd_file"
            echo "📝 Second transaction cached: $cache_2nd_file"
            
            # Extract and verify ZEN Card owner from transaction comment
            local comment=$(echo "$JSON" | jq -r '.comment // ""')
            local owner_email=$(get_zencard_owner "$comment" "$TXIPUBKEY")
            
            if [[ -n "$owner_email" ]]; then
                echo "✅ ZEN Card verified for ${owner_email}"
                "${MY_PATH}/../tools/did_manager_nostr.sh" update "$owner_email" "WOT_MEMBER" "0" "0" "$TXIPUBKEY"
            else
                echo "⚠️  No valid ZEN Card found, using captain email"
                "${MY_PATH}/../tools/did_manager_nostr.sh" update "$player_email" "WOT_MEMBER" "0" "0" "$TXIPUBKEY"
            fi

            continue  # Skip primal control for WoT identification transactions
        fi

        # Check primal transaction for incoming transaction
        echo "# RX from ${TXIPUBKEY:0:8}.... checking primal transaction..."
        echo "🔗 Sender Cesium: $(generate_cesium_link "$TXIPUBKEY")"
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
                # Create unique transaction ID for pairing (date-based ID for precise matching)
                local tx_id=$(echo "${TXIDATE}" | tr -d ':-' | tr ' ' '_')
                local intrusion_comment="UPLANET:${UPLANETG1PUB:0:8}:INTRUSION:${TXIPUBKEY:0:8}:ID:${tx_id}"
                
                # Check if this intrusion has already been processed by looking for the paired redirection
                local already_processed=false
                if [[ -s "$temp_history_file" ]]; then
                    # Look for existing redirection with same transaction ID
                    if jq -r '.[] | select(.amount < 0 and (.comment // "") | contains("ID:'${tx_id}'")) | .comment' "$temp_history_file" 2>/dev/null | grep -q "ID:${tx_id}"; then
                        already_processed=true
                        echo "INTRUSION ALREADY PROCESSED: Found paired redirection for transaction ID ${tx_id}"
                    fi
                fi
                
                if [[ "$already_processed" == false ]]; then
                    echo "PRIMAL WALLET INTRUSION ALERT for ${wallet_pubkey:0:8} from ${TXIPUBKEY:0:8} (primal: ${tx_primal:0:8})"
                    echo "🔗 Intrusion Source Cesium: $(generate_cesium_link "$tx_primal")"

                    # TOUTES LES INTRUSIONS: Redirection directe vers UPLANETNAME_INTRUSION (centralise la gestion)
                    local current_total=$((existing_intrusions + new_intrusions + 1))
                    echo "INTRUSION DETECTED ($current_total) - REDIRECTING TO UPLANETNAME_INTRUSION"
                    echo "💡 INFO: Versements Ğ1 doivent être faits vers UPLANETNAME_G1 uniquement"
                    echo "🆔 Transaction ID: ${tx_id} (for pairing verification)"
                    
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
                    
                    echo "🔗 INTRUSION Wallet Cesium: $(generate_cesium_link "$intrusion_pubkey")"
                    
                    # Rediriger les fonds vers UPLANETNAME_INTRUSION avec ID de transaction pour appairage
                    ${MY_PATH}/PAYforSURE.sh "${wallet_dunikey}" "${TXIAMOUNT}" "${intrusion_pubkey}" "${intrusion_comment}" 2>/dev/null
                    
                    if [[ $? -eq 0 ]]; then
                        echo "INTRUSION REDIRECTED: ${TXIAMOUNT} G1 sent to UPLANETNAME_INTRUSION (${intrusion_pubkey:0:8})"
                        echo "💰 Fonds intrusifs centralisés dans le portefeuille INTRUSION"
                        echo "🆔 Paired with transaction ID: ${tx_id}"
                        new_intrusions=$((new_intrusions + 1))
                        
                        # Send alert for redirection (always notify)
                        send_redirection_alert "${player_email}" "${wallet_pubkey}" "${TXIPUBKEY}" "${tx_primal}" "${TXIAMOUNT}" "${master_primal}" "$current_total" "${intrusion_pubkey}"
                    else
                        echo "ERROR: Failed to redirect intrusion to UPLANETNAME_INTRUSION"
                    fi
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

    # Final summary with affected wallets report
    local total_intrusions=$((existing_intrusions + new_intrusions))
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "📊 PRIMAL TRANSACTION CONTROL REPORT"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "👤 Player: $player_email"
    echo "📅 Analysis Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "🔢 Existing Intrusions: $existing_intrusions"
    echo "🆕 New Intrusions: $new_intrusions"
    echo "📊 Total Intrusions: $total_intrusions"
    echo ""
    
    if [[ $new_intrusions -gt 0 ]]; then
        echo "🚨 NEW INTRUSIONS DETECTED: $new_intrusions"
        echo "💡 INFO: All intrusions redirected to UPLANETNAME_INTRUSION"
        echo "💰 Intrusive funds recovered by UPlanet cooperative"
        echo "📧 Email alerts sent to ${player_email}"
        
        # Display INTRUSION wallet info if it exists
        local intrusion_dunikey="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
        if [[ -f "$intrusion_dunikey" ]]; then
            local intrusion_pubkey=$(cat "$intrusion_dunikey" | grep 'pub:' | cut -d ' ' -f 2 2>/dev/null)
            if [[ -n "$intrusion_pubkey" ]]; then
                echo ""
                display_wallet_info "INTRUSION WALLET" "$intrusion_pubkey" "Centralized wallet for all redirected intrusive funds"
            fi
        fi
    else
        echo "✅ NO NEW INTRUSIONS DETECTED"
        echo "🛡️ Wallet security maintained"
    fi
    
    echo "═══════════════════════════════════════════════════════════════════════════════"

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
