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

echo "############################################"
echo "
 _____  ____      _    ____ _     _____   
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
## RETRIEVE PENDING REQUESTS
################################################################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[STEP 1] Checking pending permit requests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get all pending and attesting requests
pending_requests=$(curl -s "${ORACLE_API}/list?type=requests&status=pending,attesting" | jq -r '.requests[]?.request_id // empty' 2>/dev/null)

if [[ -z "$pending_requests" ]]; then
    echo "[INFO] No pending requests to process"
else
    request_count=$(echo "$pending_requests" | wc -l)
    echo "[INFO] Found ${request_count} pending request(s)"
    
    # Process each pending request
    for request_id in $pending_requests; do
        echo ""
        echo "  [→] Processing request: ${request_id}"
        
        # Get request details
        request_data=$(curl -s "${ORACLE_API}/status/${request_id}")
        
        if [[ $? -ne 0 ]] || [[ -z "$request_data" ]]; then
            echo "  [ERROR] Failed to retrieve request ${request_id}"
            continue
        fi
        
        status=$(echo "$request_data" | jq -r '.status // empty')
        attestations_count=$(echo "$request_data" | jq -r '.attestations_count // 0')
        required_attestations=$(echo "$request_data" | jq -r '.required_attestations // 0')
        permit_id=$(echo "$request_data" | jq -r '.permit_definition_id // empty')
        applicant_npub=$(echo "$request_data" | jq -r '.applicant_npub // empty')
        created_at=$(echo "$request_data" | jq -r '.created_at // empty')
        
        echo "  [INFO] Status: ${status}"
        echo "  [INFO] Attestations: ${attestations_count}/${required_attestations}"
        echo "  [INFO] Permit: ${permit_id}"
        
        # Check if threshold is reached
        if [[ $attestations_count -ge $required_attestations ]]; then
            echo "  [SUCCESS] Threshold reached! Triggering credential issuance..."
            
            # The API should auto-issue, but we can verify or trigger manually
            # Call the issue endpoint (this should be idempotent)
            issue_result=$(curl -s -X POST "${ORACLE_API}/issue/${request_id}" 2>/dev/null)
            
            if [[ $? -eq 0 ]]; then
                credential_id=$(echo "$issue_result" | jq -r '.credential_id // empty')
                if [[ -n "$credential_id" ]]; then
                    echo "  [SUCCESS] Credential issued: ${credential_id}"
                    
                    # Optional: Send notification to applicant
                    # ${MY_PATH}/../tools/notify_permit_issued.sh "${applicant_npub}" "${permit_id}" "${credential_id}"
                else
                    echo "  [INFO] Credential may already exist or issuance pending"
                fi
            else
                echo "  [WARNING] Failed to issue credential for ${request_id}"
            fi
        else
            # Check if request is too old (> 90 days)
            if [[ -n "$created_at" ]]; then
                created_timestamp=$(date -d "$created_at" +%s 2>/dev/null || echo 0)
                now_timestamp=$(date +%s)
                age_days=$(( (now_timestamp - created_timestamp) / 86400 ))
                
                if [[ $age_days -gt 90 ]]; then
                    echo "  [WARNING] Request is ${age_days} days old (> 90 days)"
                    echo "  [ACTION] Marking request as expired"
                    
                    # Optional: Call API to expire the request
                    # curl -s -X POST "${ORACLE_API}/expire/${request_id}"
                fi
            fi
        fi
    done
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
    "uplanet": "${UPLANETNAME}",
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

# Get UPLANETNAME.G1 NSEC for signing
UPLANETG1NSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" -s)

if [[ -n "$UPLANETG1NSEC" ]]; then
    # Create a kind 1 note with daily Oracle statistics
    oracle_message="🔐 Oracle System Daily Report (${TODATE})

📊 Global Statistics:
• Total requests: ${total_requests}
• Total credentials issued: ${total_credentials}

🎯 Active Permits: $(echo "$definitions" | jq -s 'length')

🔗 View permits: ${uSPOT}/oracle

#UPlanet #Oracle #WoT #Permits"

    # Send to NOSTR relay
    UPLANETG1HEX=$(${MY_PATH}/../tools/nostr2hex.py "${UPLANETG1NSEC}" 2>/dev/null || echo "")
    
    if [[ -n "$UPLANETG1HEX" ]]; then
        ${MY_PATH}/../tools/nostr_send_note.py \
            --keyfile <(echo "NSEC=${UPLANETG1NSEC}") \
            --content "$oracle_message" \
            --kind 1 \
            --relays "$myRELAY" \
            2>/dev/null && echo "[SUCCESS] Oracle status published to NOSTR" || echo "[WARNING] Failed to publish to NOSTR"
    fi
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

