#!/bin/bash
################################################################################
# Script: oracle_attest_license.sh
# Description: Attest a permit/license request as an expert
#
# This script allows certified experts to attest permit requests,
# contributing their signature to the multi-signature validation process.
#
# Usage: ./oracle_attest_license.sh EMAIL REQUEST_ID STATEMENT [LICENSE_ID]
#
# License: AGPL-3.0
# Author: UPlanet/Astroport.ONE Team (support@qo-op.com)
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Colors for display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

################################################################################
# Display help
################################################################################
show_help() {
    echo -e "${BLUE}oracle_attest_license.sh - Attest a Permit/License Request${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 EMAIL REQUEST_ID STATEMENT [LICENSE_ID]"
    echo ""
    echo "Arguments:"
    echo "  EMAIL       - Email address of the attester (MULTIPASS)"
    echo "  REQUEST_ID  - ID of the permit request to attest"
    echo "  STATEMENT   - Attestation statement (why you certify this person)"
    echo "  LICENSE_ID  - Optional: Your own license ID (if required by permit type)"
    echo ""
    echo "Example:"
    echo "  $0 expert@example.com a1b2c3d4 \"I have personally verified their competence\""
    echo "  $0 expert@example.com a1b2c3d4 \"Certified after 20 hours training\" credential_xyz"
    echo ""
    echo "Notes:"
    echo "  - You must be a certified expert to attest certain permit types"
    echo "  - Your attestation will be recorded on the blockchain via NOSTR"
    echo "  - False attestations can result in revocation of your own permits"
    echo ""
}

################################################################################
# Main function
################################################################################

if [[ "$#" -lt 3 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 1
fi

EMAIL="$1"
REQUEST_ID="$2"
STATEMENT="$3"
LICENSE_ID="${4:-}"

echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${NC}"
echo -e "${CYAN}🔐 Attesting Permit/License Request${NC}"
echo -e "${BLUE}   Attester: ${EMAIL}${NC}"
echo -e "${BLUE}   Request ID: ${REQUEST_ID}${NC}"
echo -e "${BLUE}   Statement: ${STATEMENT}${NC}"
[[ -n "$LICENSE_ID" ]] && echo -e "${BLUE}   Attester License: ${LICENSE_ID}${NC}"
echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${NC}"

# Get NOSTR keys for this email
NOSTR_DIR="$HOME/.zen/game/nostr/${EMAIL}"
if [[ ! -d "$NOSTR_DIR" ]]; then
    echo -e "${RED}❌ NOSTR directory not found for ${EMAIL}${NC}"
    echo -e "${YELLOW}💡 Create a MULTIPASS first with make_NOSTRCARD.sh${NC}"
    exit 1
fi

NPUB_FILE="${NOSTR_DIR}/NPUB"
if [[ ! -f "$NPUB_FILE" ]]; then
    echo -e "${RED}❌ NPUB file not found${NC}"
    exit 1
fi

NPUB=$(cat "$NPUB_FILE")
echo -e "${GREEN}✅ NOSTR key found: ${NPUB:0:16}...${NC}"

# Get request status first
echo -e "${CYAN}🔍 Checking request status...${NC}"
REQUEST_STATUS=$(curl -s "${uSPOT}/api/permit/status/${REQUEST_ID}")

if ! echo "$REQUEST_STATUS" | jq -e '.request_id' > /dev/null 2>&1; then
    echo -e "${RED}❌ Request not found: ${REQUEST_ID}${NC}"
    exit 1
fi

PERMIT_TYPE=$(echo "$REQUEST_STATUS" | jq -r '.permit_type')
APPLICANT_NPUB=$(echo "$REQUEST_STATUS" | jq -r '.applicant_npub')
CURRENT_STATUS=$(echo "$REQUEST_STATUS" | jq -r '.status')
ATTESTATIONS_COUNT=$(echo "$REQUEST_STATUS" | jq -r '.attestations_count')
REQUIRED_ATTESTATIONS=$(echo "$REQUEST_STATUS" | jq -r '.required_attestations')

echo -e "${CYAN}📋 Request Information:${NC}"
echo -e "${BLUE}   Permit Type: ${PERMIT_TYPE}${NC}"
echo -e "${BLUE}   Applicant: ${APPLICANT_NPUB:0:16}...${NC}"
echo -e "${BLUE}   Status: ${CURRENT_STATUS}${NC}"
echo -e "${BLUE}   Attestations: ${ATTESTATIONS_COUNT}/${REQUIRED_ATTESTATIONS}${NC}"

# Check if already attested
EXISTING_ATTESTATIONS=$(echo "$REQUEST_STATUS" | jq -r '.attestations[]?.attester_npub' 2>/dev/null)
if echo "$EXISTING_ATTESTATIONS" | grep -q "$NPUB"; then
    echo -e "${YELLOW}⚠️  You have already attested this request${NC}"
    exit 1
fi

# Confirm attestation
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: By attesting, you certify that:${NC}"
echo -e "${YELLOW}   1. You have personally verified the applicant's competence${NC}"
echo -e "${YELLOW}   2. You take responsibility for this certification${NC}"
echo -e "${YELLOW}   3. You accept the consequences if the attestation is false${NC}"
echo ""
read -p "$(echo -e ${CYAN}"Do you confirm this attestation? [yes/NO]: "${NC})" CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}⛔ Attestation cancelled${NC}"
    exit 0
fi

# Build attestation JSON
LICENSE_JSON="null"
if [[ -n "$LICENSE_ID" ]]; then
    LICENSE_JSON="\"${LICENSE_ID}\""
fi

ATTESTATION_JSON=$(cat <<EOF
{
    "request_id": "${REQUEST_ID}",
    "attester_npub": "${NPUB}",
    "statement": "${STATEMENT}",
    "attester_license_id": ${LICENSE_JSON}
}
EOF
)

# Submit attestation to API
echo -e "${CYAN}📡 Submitting attestation to UPassport API...${NC}"

RESPONSE=$(curl -s -X POST "${uSPOT}/api/permit/attest" \
    -H "Content-Type: application/json" \
    -d "${ATTESTATION_JSON}")

# Check response
if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    ATTESTATION_ID=$(echo "$RESPONSE" | jq -r '.attestation_id')
    NEW_STATUS=$(echo "$RESPONSE" | jq -r '.status')
    NEW_COUNT=$(echo "$RESPONSE" | jq -r '.attestations_count')
    
    echo -e "${GREEN}✅ Attestation submitted successfully!${NC}"
    echo -e "${CYAN}   Attestation ID: ${ATTESTATION_ID}${NC}"
    echo -e "${CYAN}   New Status: ${NEW_STATUS}${NC}"
    echo -e "${CYAN}   Attestations: ${NEW_COUNT}/${REQUIRED_ATTESTATIONS}${NC}"
    
    if [[ "$NEW_STATUS" == "validated" ]] || [[ "$NEW_STATUS" == "issued" ]]; then
        echo ""
        echo -e "${GREEN}🎉 PERMIT VALIDATED!${NC}"
        echo -e "${GREEN}   The permit has reached the required number of attestations${NC}"
        echo -e "${GREEN}   A Verifiable Credential has been issued automatically${NC}"
    else
        echo ""
        echo -e "${YELLOW}📋 Status: Waiting for more attestations (${NEW_COUNT}/${REQUIRED_ATTESTATIONS})${NC}"
    fi
    
    # Save attestation ID for reference
    echo "$ATTESTATION_ID" >> "${NOSTR_DIR}/attestations_given.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ${REQUEST_ID} | ${PERMIT_TYPE} | ${ATTESTATION_ID}" >> "${NOSTR_DIR}/attestations_history.log"
    
    exit 0
else
    ERROR=$(echo "$RESPONSE" | jq -r '.detail // .message // "Unknown error"')
    echo -e "${RED}❌ Failed to submit attestation: ${ERROR}${NC}"
    exit 1
fi

