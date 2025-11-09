#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# ORACLE.refresh.sh - Daily maintenance for Oracle Permit System
#
# This script runs daily to maintain the permit ecosystem:
# - Check pending permit requests (30501)
# - Validate attestation thresholds (30502)
# - Issue credentials when threshold is reached (30503)
# - Expire old requests
# - Revoke expired credentials
# - Update permit statistics
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

################################################################################
# Helper functions
################################################################################

generate_uplanet_g1_nostr_key() {
    # Generate NOSTR key for UPLANETNAME_G1 if it doesn't exist
    # Similar to oracle_init_permit_definitions.sh
    
    local keyfile="${HOME}/.zen/game/uplanet.G1.nostr"
    
    if [[ -f "$keyfile" ]]; then
        return 0  # Keyfile already exists
    fi
    
    if [[ -z "$UPLANETNAME" ]]; then
        echo "[ERROR] UPLANETNAME not set in environment"
        return 1
    fi
    
    echo "[INFO] Generating NOSTR key for UPLANETNAME_G1..."
    
    # Generate NOSTR keys using UPLANETNAME_G1 as SALT and PEPPER (like dunikey generation)
    local salt="${UPLANETNAME}.G1"
    local pepper="${UPLANETNAME}.G1"
    local keygen="${HOME}/.zen/Astroport.ONE/tools/keygen"
    local nostr2hex="${HOME}/.zen/Astroport.ONE/tools/nostr2hex.py"
    
    if [[ ! -f "$keygen" ]]; then
        echo "[ERROR] keygen tool not found at ${keygen}"
        return 1
    fi
    
    # Generate private key
    local npriv=$("$keygen" -t nostr "$salt" "$pepper" -s 2>/dev/null)
    if [[ -z "$npriv" ]]; then
        echo "[ERROR] Failed to generate NOSTR private key"
        return 1
    fi
    
    # Generate public key
    local npub=$("$keygen" -t nostr "$salt" "$pepper" 2>/dev/null)
    if [[ -z "$npub" ]]; then
        echo "[ERROR] Failed to generate NOSTR public key"
        return 1
    fi
    
    # Generate HEX from public key
    local hex=""
    if [[ -f "$nostr2hex" ]]; then
        hex=$("$nostr2hex" "$npub" 2>/dev/null)
    fi
    
    # Create keyfile in the same format as make_NOSTRCARD.sh
    mkdir -p "$(dirname "$keyfile")"
    cat > "$keyfile" <<EOF
NSEC=$npriv; NPUB=$npub; HEX=$hex;
EOF
    chmod 600 "$keyfile"
    
    echo "[SUCCESS] Generated NOSTR keyfile: $keyfile"
    return 0
}

################################################################################

echo "############################################"
echo "
 _____ ____      _    ____ _     _____   
|  _ \|  _ \    / \  / ___| |   | ____|  
| | | | |_) |  / _ \| |   | |   |  _|    
| |_| |  _ <  / ___ \ |___| |___| |___   
|_____|_| \_\/_/   \_\____|_____|_____|
                                          
     REFRESH - Daily Maintenance
"
echo "############################################"

[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

start=`date +%s`
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

################################################################################
## CHECK IF ORACLE API IS RUNNING
################################################################################
ORACLE_API="${uSPOT:-http://127.0.0.1:54321}/api/permit"

echo "[INFO] Checking Oracle API availability at ${ORACLE_API}"
if ! curl -s -f "${ORACLE_API}/definitions" >/dev/null 2>&1; then
    echo "[WARNING] Oracle API not available at ${ORACLE_API}"
    echo "[INFO] Skipping Oracle maintenance (API not running)"
    exit 0
fi

echo "[SUCCESS] Oracle API is available"

################################################################################
## RETRIEVE PENDING REQUESTS FROM NOSTR (30501) AND CHECK ATTESTATIONS (30502)
################################################################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[STEP 1] Checking permit requests from Nostr (WoTx2 system)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find nostr_get_events.sh script
NOSTR_SCRIPT="${HOME}/.zen/Astroport.ONE/tools/nostr_get_events.sh"

if [[ ! -f "$NOSTR_SCRIPT" ]]; then
    echo "[WARNING] nostr_get_events.sh not found at ${NOSTR_SCRIPT}"
    echo "[INFO] Cannot fetch events from Nostr relay"
    echo "[INFO] Skipping WoTx2 permit processing"
else
    # Fetch all permit requests (kind 30501) from Nostr
    echo "[INFO] Fetching permit requests (kind 30501) from Nostr relay..."
    requests_json=$("$NOSTR_SCRIPT" --kind 30501 2>/dev/null)
    
    if [[ -z "$requests_json" ]]; then
        echo "[INFO] No permit requests found in Nostr"
    else
        # Parse requests and check attestations
        request_count=$(echo "$requests_json" | jq -s 'length' 2>/dev/null || echo "0")
        echo "[INFO] Found ${request_count} permit request(s) in Nostr"
        
        # Process each request
        echo "$requests_json" | jq -c '.[]' 2>/dev/null | while read -r request_event; do
            request_id=$(echo "$request_event" | jq -r '.tags[]? | select(.[0]=="d") | .[1]' 2>/dev/null | head -1)
            permit_id=$(echo "$request_event" | jq -r '.tags[]? | select(.[0]=="l") | .[1]' 2>/dev/null | head -1)
            applicant_hex=$(echo "$request_event" | jq -r '.pubkey // empty' 2>/dev/null)
            created_at=$(echo "$request_event" | jq -r '.created_at // 0' 2>/dev/null)
            
            if [[ -z "$request_id" ]] || [[ -z "$permit_id" ]]; then
                continue
            fi
            
            echo ""
            echo "  [→] Processing request: ${request_id}"
            echo "  [INFO] Permit: ${permit_id}"
            echo "  [INFO] Applicant: ${applicant_hex:0:16}..."
            
            # Get permit definition to know required attestations
            definition_data=$(curl -s "${ORACLE_API}/definitions" | jq -r ".permits[]? | select(.id==\"${permit_id}\")" 2>/dev/null)
            
            if [[ -z "$definition_data" ]]; then
                echo "  [WARNING] Permit definition ${permit_id} not found"
                continue
            fi
            
            required_attestations=$(echo "$definition_data" | jq -r '.min_attestations // 1' 2>/dev/null)
            
            # Count attestations (kind 30502) for this request
            echo "  [INFO] Counting attestations (kind 30502) for request ${request_id}..."
            attestations_json=$("$NOSTR_SCRIPT" --kind 30502 2>/dev/null)
            
            attestations_count=0
            if [[ -n "$attestations_json" ]]; then
                # Count attestations that reference this request_id
                attestations_count=$(echo "$attestations_json" | jq -r --arg req_id "$request_id" '[.[] | select(.tags[]?[0]=="e" and .tags[]?[1]==$req_id)] | length' 2>/dev/null || echo "0")
            fi
            
            echo "  [INFO] Attestations: ${attestations_count}/${required_attestations}"
            
            # Check if credential already exists (kind 30503)
            existing_credential=$(echo "$("$NOSTR_SCRIPT" --kind 30503 2>/dev/null)" | jq -r --arg req_id "$request_id" '[.[] | select(.tags[]?[0]=="d" and .tags[]?[1]==$req_id)] | length' 2>/dev/null || echo "0")
            
            if [[ "$existing_credential" -gt 0 ]]; then
                echo "  [INFO] Credential already issued for this request"
                continue
            fi
            
            # Check if threshold is reached (WoTx2: 1, 2, 3, 4... signatures)
            if [[ $attestations_count -ge $required_attestations ]]; then
                echo "  [SUCCESS] Threshold reached (${attestations_count} >= ${required_attestations})! Issuing credential..."
                
                # Call API to issue credential (using request_id from Nostr event)
                # The API will read the request from Nostr and issue 30503
                issue_result=$(curl -s -X POST "${ORACLE_API}/issue/${request_id}" 2>/dev/null)
                
                if [[ $? -eq 0 ]]; then
                    credential_id=$(echo "$issue_result" | jq -r '.credential_id // empty' 2>/dev/null)
                    if [[ -n "$credential_id" ]]; then
                        echo "  [SUCCESS] Credential issued: ${credential_id}"
                        echo "  [INFO] WoTx2 system progressing: ${attestations_count} attestations collected"
                        
                        # Check if this is an auto-proclaimed profession (PERMIT_PROFESSION_*_X1, X2, X3...)
                        if [[ "$permit_id" =~ ^PERMIT_PROFESSION_.*_X([0-9]+)$ ]]; then
                            current_level="${BASH_REMATCH[1]}"
                            echo "  [INFO] Auto-proclaimed profession detected: Level X${current_level}"
                            
                            # Calculate next level (unlimited progression: X1→X2→X3→...→X144→...)
                            next_level=$((current_level + 1))
                            next_permit_id=$(echo "$permit_id" | sed "s/_X${current_level}$/_X${next_level}/")
                            echo "  [INFO] X${current_level} validated! Creating next level: ${next_permit_id}"
                            
                            # Get permit definition to extract name and description
                            # Remove level suffix from name and description
                            permit_name=$(echo "$definition_data" | jq -r '.name // empty' 2>/dev/null | sed 's/ (Niveau X[0-9]\+.*)$//')
                            permit_desc=$(echo "$definition_data" | jq -r '.description // empty' 2>/dev/null | sed 's/ - Niveau X[0-9]\+.*$//')
                            
                            # Determine level label
                            if [[ $next_level -le 4 ]]; then
                                level_label="Niveau X${next_level}"
                            elif [[ $next_level -le 10 ]]; then
                                level_label="Niveau X${next_level} (Expert)"
                            elif [[ $next_level -le 50 ]]; then
                                level_label="Niveau X${next_level} (Maître)"
                            elif [[ $next_level -le 100 ]]; then
                                level_label="Niveau X${next_level} (Grand Maître)"
                            else
                                level_label="Niveau X${next_level} (Maître Absolu)"
                            fi
                            
                            # Calculate requirements: next level needs (next_level) competencies and signatures
                            min_attestations=$next_level
                            
                            # Authenticate with NIP-42 before calling API
                            echo "  [INFO] Authenticating with NIP-42 (kind 22242)..."
                            UPLANET_G1_KEYFILE="${HOME}/.zen/game/uplanet.G1.nostr"
                            
                            if [[ ! -f "$UPLANET_G1_KEYFILE" ]]; then
                                if ! generate_uplanet_g1_nostr_key; then
                                    echo "  [ERROR] Failed to generate UPLANETNAME_G1 keyfile"
                                    continue
                                fi
                            fi
                            
                            # Load NPUB from keyfile
                            if [[ -f "$UPLANET_G1_KEYFILE" ]]; then
                                source "$UPLANET_G1_KEYFILE" 2>/dev/null
                                UPLANETNAME_G1_NPUB="$NPUB"
                            fi
                            
                            # Send NIP-42 authentication event
                            NOSTR_SEND_NOTE="${MY_PATH}/../tools/nostr_send_note.py"
                            if [[ -f "$NOSTR_SEND_NOTE" ]]; then
                                # Generate auth challenge
                                auth_challenge="oracle_refresh_$(date +%s)_${next_permit_id}"
                                
                                # Send NIP-42 auth event (kind 22242)
                                auth_result=$("$NOSTR_SEND_NOTE" \
                                    --keyfile "$UPLANET_G1_KEYFILE" \
                                    --content "$auth_challenge" \
                                    --kind 22242 \
                                    --relays "${myRELAY:-ws://127.0.0.1:7777}" \
                                    2>/dev/null)
                                
                                if echo "$auth_result" | grep -q "success"; then
                                    echo "  [SUCCESS] NIP-42 authentication sent"
                                    # Wait a moment for relay to process
                                    sleep 1
                                else
                                    echo "  [WARNING] NIP-42 authentication may have failed, continuing anyway"
                                fi
                            else
                                echo "  [WARNING] nostr_send_note.py not found, skipping NIP-42 auth"
                            fi
                            
                            # Create next level permit definition via API
                            # ORACLE_API = ${uSPOT}/api/permit, so we need base URL + /api/permit/define
                            ORACLE_BASE="${ORACLE_API%/api/permit}"
                            
                            # Build progression rules (always continue to next level)
                            next_next_level=$((next_level + 1))
                            
                            create_next_result=$(curl -s -X POST "${ORACLE_BASE}/api/permit/define" \
                                -H "Content-Type: application/json" \
                                -H "X-Nostr-Auth: ${UPLANETNAME_G1_NPUB:-}" \
                                -d "{
                                    \"permit\": {
                                        \"id\": \"${next_permit_id}\",
                                        \"name\": \"${permit_name} (${level_label})\",
                                        \"description\": \"${permit_desc} - ${level_label} nécessite ${min_attestations} compétences et ${min_attestations} signatures\",
                                        \"min_attestations\": ${min_attestations},
                                        \"required_license\": null,
                                        \"valid_duration_days\": 0,
                                        \"revocable\": true,
                                        \"verification_method\": \"peer_attestation\",
                                        \"metadata\": {
                                            \"category\": \"auto_proclaimed\",
                                            \"level\": \"X${next_level}\",
                                            \"auto_proclaimed\": true,
                                            \"evolving_system\": {
                                                \"type\": \"WoTx2_AutoProclaimed\",
                                                \"auto_progression\": true,
                                                \"progression_rules\": {
                                                    \"x${next_level}\": {
                                                        \"signatures\": ${min_attestations},
                                                        \"competencies\": ${min_attestations},
                                                        \"next_level\": \"X${next_next_level}\"
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    \"npub\": \"${UPLANETNAME_G1_NPUB:-}\"
                                }" 2>/dev/null)
                            
                            if echo "$create_next_result" | jq -e '.success' >/dev/null 2>&1; then
                                echo "  [SUCCESS] Created next level permit: ${next_permit_id} (${level_label})"
                            else
                                error_msg=$(echo "$create_next_result" | jq -r '.detail // .message // "Unknown error"' 2>/dev/null)
                                echo "  [WARNING] Failed to create X${next_level} permit: ${error_msg}"
                                echo "  [INFO] Permit may already exist or API authentication failed"
                            fi
                        fi
                        
                        # Delete the 30501 request from MULTIPASS directory after credential issuance
                        # Find applicant email from hex
                        applicant_email=""
                        if [[ -n "$applicant_hex" ]]; then
                            # Convert hex to npub if needed, or search for email
                            nostr_dir="${HOME}/.zen/game/nostr"
                            if [[ -d "$nostr_dir" ]]; then
                                for email_dir in "$nostr_dir"/*; do
                                    if [[ -d "$email_dir" ]]; then
                                        npub_file="${email_dir}/NPUB"
                                        if [[ -f "$npub_file" ]]; then
                                            stored_npub=$(cat "$npub_file" 2>/dev/null)
                                            # Check if hex matches (simplified - would need hex2npub conversion)
                                            # For now, search for 30501 events in MULTIPASS directories
                                            for event_file in "${email_dir}"/30501_*.json; do
                                                if [[ -f "$event_file" ]]; then
                                                    event_req_id=$(jq -r '.tags[]? | select(.[0]=="d") | .[1]' "$event_file" 2>/dev/null | head -1)
                                                    if [[ "$event_req_id" == "$request_id" ]]; then
                                                        applicant_email=$(basename "$email_dir")
                                                        echo "  [INFO] Found request in MULTIPASS directory: ${applicant_email}"
                                                        # Delete the 30501 request file
                                                        rm -f "$event_file"
                                                        echo "  [SUCCESS] Deleted 30501 request from ${applicant_email} directory"
                                                        break 2
                                                    fi
                                                fi
                                            done
                                        fi
                                    fi
                                done
                            fi
                        fi
                    else
                        echo "  [INFO] Credential issuance may be pending or already exists"
                    fi
                else
                    echo "  [WARNING] Failed to issue credential for ${request_id}"
                fi
            else
                echo "  [INFO] WoTx2 progressing: ${attestations_count}/${required_attestations} attestations (need $((required_attestations - attestations_count)) more)"
                
                # Check if request is too old (> 90 days)
                if [[ -n "$created_at" ]] && [[ "$created_at" != "0" ]]; then
                    created_timestamp=$created_at
                    now_timestamp=$(date +%s)
                    age_days=$(( (now_timestamp - created_timestamp) / 86400 ))
                    
                    if [[ $age_days -gt 90 ]]; then
                        echo "  [WARNING] Request is ${age_days} days old (> 90 days)"
                    fi
                fi
            fi
        done
    fi
fi

################################################################################
## CHECK EXPIRED CREDENTIALS
################################################################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[STEP 2] Checking expired credentials..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get all credentials
all_credentials=$(curl -s "${ORACLE_API}/list?type=credentials" | jq -r '.credentials[]? // empty' 2>/dev/null)

if [[ -z "$all_credentials" ]]; then
    echo "[INFO] No credentials to check"
else
    credential_count=$(echo "$all_credentials" | jq -s 'length')
    echo "[INFO] Checking ${credential_count} credential(s)"
    
    expired_count=0
    now_timestamp=$(date +%s)
    
    # Process each credential
    echo "$all_credentials" | jq -c '.' | while read -r credential; do
        credential_id=$(echo "$credential" | jq -r '.credential_id // empty')
        expires_at=$(echo "$credential" | jq -r '.expires_at // empty')
        status=$(echo "$credential" | jq -r '.status // "active"')
        
        if [[ -n "$expires_at" && "$expires_at" != "null" ]]; then
            expires_timestamp=$(date -d "$expires_at" +%s 2>/dev/null || echo 0)
            
            if [[ $expires_timestamp -lt $now_timestamp ]] && [[ "$status" == "active" ]]; then
                echo "  [WARNING] Credential ${credential_id} has expired"
                expired_count=$((expired_count + 1))
                
                # Optional: Call API to revoke/expire the credential
                # curl -s -X POST "${ORACLE_API}/revoke/${credential_id}" -d '{"reason":"expired"}'
            fi
        fi
    done
    
    if [[ $expired_count -gt 0 ]]; then
        echo "[INFO] Found ${expired_count} expired credential(s)"
    else
        echo "[SUCCESS] All credentials are valid"
    fi
fi

################################################################################
## GENERATE STATISTICS
################################################################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[STEP 3] Generating statistics..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ORACLE_STATS_DIR="$HOME/.zen/tmp/${IPFSNODEID}/ORACLE"
mkdir -p "${ORACLE_STATS_DIR}"

# Get permit definitions
definitions=$(curl -s "${ORACLE_API}/definitions" | jq -r '.permits[]? // empty' 2>/dev/null)

if [[ -n "$definitions" ]]; then
    echo "$definitions" | jq -c '.' | while read -r permit; do
        permit_id=$(echo "$permit" | jq -r '.id // empty')
        permit_name=$(echo "$permit" | jq -r '.name // empty')
        
        # Count requests and credentials for this permit
        requests_count=$(curl -s "${ORACLE_API}/list?type=requests&permit_id=${permit_id}" | jq '.count // 0' 2>/dev/null)
        credentials_count=$(curl -s "${ORACLE_API}/list?type=credentials&permit_id=${permit_id}" | jq '.count // 0' 2>/dev/null)
        
        echo "  [STAT] ${permit_name}: ${requests_count} requests, ${credentials_count} issued"
        
        # Save to file
        cat > "${ORACLE_STATS_DIR}/${permit_id}.json" <<EOF
{
    "permit_id": "${permit_id}",
    "permit_name": "${permit_name}",
    "requests_count": ${requests_count},
    "credentials_count": ${credentials_count},
    "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    done
fi

# Global statistics
total_requests=$(curl -s "${ORACLE_API}/list?type=requests" | jq '.count // 0' 2>/dev/null)
total_credentials=$(curl -s "${ORACLE_API}/list?type=credentials" | jq '.count // 0' 2>/dev/null)

cat > "${ORACLE_STATS_DIR}/global_stats.json" <<EOF
{
    "total_requests": ${total_requests},
    "total_credentials": ${total_credentials},
    "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "uplanet": "${UPLANETNAME_G1}",
    "ipfs_node": "${IPFSNODEID}"
}
EOF

echo "[SUCCESS] Statistics saved to ${ORACLE_STATS_DIR}"

################################################################################
## PUBLISH ORACLE STATUS TO NOSTR
################################################################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[STEP 4] Publishing Oracle status to NOSTR..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use UPLANETNAME_G1 keyfile for signing (standardized location)
UPLANET_G1_KEYFILE="${HOME}/.zen/game/uplanet.G1.nostr"

# Generate keyfile if it doesn't exist
if [[ ! -f "$UPLANET_G1_KEYFILE" ]]; then
    if ! generate_uplanet_g1_nostr_key; then
        echo "[ERROR] Failed to generate UPLANETNAME_G1 keyfile"
        echo "[INFO] Oracle status will not be published to NOSTR"
    fi
fi

if [[ -f "$UPLANET_G1_KEYFILE" ]]; then
    
    source "$UPLANET_G1_KEYFILE" && echo $HEX >> $HOME/.zen/game/nostr/ZSWARM/HEX
    # Create a kind 1 note with daily Oracle statistics    
    oracle_message="🔐 Oracle System Daily Report (${TODATE})

📊 Global Statistics:
• Total requests: ${total_requests}
• Total credentials issued: ${total_credentials}

🎯 Active Permits: $(echo "$definitions" | jq -s 'length')

🔗 View permits: ${uSPOT}/oracle

#UPlanet #Oracle #WoT #Permits"

    # Send to NOSTR relay using keyfile
    ${MY_PATH}/../tools/nostr_send_note.py \
        --keyfile "$UPLANET_G1_KEYFILE" \
        --content "$oracle_message" \
        --kind 1 \
        --relays "$myRELAY" \
        2>/dev/null && echo "[SUCCESS] Oracle status published to NOSTR" || echo "[WARNING] Failed to publish to NOSTR"
else
    echo "[WARNING] UPLANETNAME_G1 keyfile not found: $UPLANET_G1_KEYFILE"
    echo "[INFO] Run oracle_init_permit_definitions.sh to generate the keyfile"
fi

################################################################################
## CLEANUP
################################################################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[STEP 5] Cleanup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove old temporary files (> 7 days)
find ~/.zen/tmp -name "ORACLE_*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
echo "[SUCCESS] Cleanup completed"

################################################################################
## SUMMARY
################################################################################
end=`date +%s`
duration=$((end-start))

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            Oracle System Maintenance Complete                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Duration: ${duration}s"
echo "  Total Requests: ${total_requests}"
echo "  Total Credentials: ${total_credentials}"
echo "  Statistics: ${ORACLE_STATS_DIR}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[STEP 5] Cleanup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove old temporary files (> 7 days)
find ~/.zen/tmp -name "ORACLE_*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
echo "[SUCCESS] Cleanup completed"

################################################################################
## SUMMARY
################################################################################
end=`date +%s`
duration=$((end-start))

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            Oracle System Maintenance Complete                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Duration: ${duration}s"
echo "  Total Requests: ${total_requests}"
echo "  Total Credentials: ${total_credentials}"
echo "  Statistics: ${ORACLE_STATS_DIR}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0

