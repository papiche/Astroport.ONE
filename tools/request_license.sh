#!/bin/bash
################################################################################
# Script: request_license.sh
# Description: Request a permit/license from the Oracle System
#
# This script allows users to request a permit (license) that requires
# multiple attestations from experts to be validated.
#
# Usage: ./request_license.sh EMAIL PERMIT_ID STATEMENT [EVIDENCE...]
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
NC='\033[0m' # No Color

################################################################################
# Display help
################################################################################
show_help() {
    echo -e "${BLUE}request_license.sh - Request a Permit/License${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 EMAIL PERMIT_ID STATEMENT [EVIDENCE...]"
    echo ""
    echo "Arguments:"
    echo "  EMAIL       - Email address of the applicant (MULTIPASS)"
    echo "  PERMIT_ID   - ID of the permit definition (e.g., PERMIT_ORE_V1)"
    echo "  STATEMENT   - Applicant's statement explaining their competence"
    echo "  EVIDENCE    - Optional: Links to evidence (IPFS, URLs, etc.)"
    echo ""
    echo "Example:"
    echo "  $0 user@example.com PERMIT_ORE_V1 \"I have 5 years experience in forest management\""
    echo "  $0 user@example.com PERMIT_DRIVER \"I have completed driving school\" /ipfs/Qm..."
    echo ""
    echo "Available Permit Types:"
    echo "  PERMIT_ORE_V1          - ORE Verifier (Environmental Obligations)"
    echo "  PERMIT_DRIVER          - Driver's License (example from article)"
    echo "  PERMIT_WOT_DRAGON      - WoT Dragon (UPlanet authority)"
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
PERMIT_ID="$2"
STATEMENT="$3"
shift 3
EVIDENCE=("$@")

echo -e "${CYAN}🎫 Requesting Permit/License${NC}"
echo -e "${BLUE}   Email: ${EMAIL}${NC}"
echo -e "${BLUE}   Permit: ${PERMIT_ID}${NC}"
echo -e "${BLUE}   Statement: ${STATEMENT}${NC}"

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

# Build evidence array for JSON
EVIDENCE_JSON="[]"
if [[ ${#EVIDENCE[@]} -gt 0 ]]; then
    EVIDENCE_JSON=$(printf '%s\n' "${EVIDENCE[@]}" | jq -R . | jq -s .)
fi

# Build request JSON
REQUEST_JSON=$(cat <<EOF
{
    "permit_definition_id": "${PERMIT_ID}",
    "applicant_npub": "${NPUB}",
    "statement": "${STATEMENT}",
    "evidence": ${EVIDENCE_JSON}
}
EOF
)

# Submit request to API
echo -e "${CYAN}📡 Submitting request to UPassport API...${NC}"

RESPONSE=$(curl -s -X POST "${uSPOT}/api/permit/request" \
    -H "Content-Type: application/json" \
    -d "${REQUEST_JSON}")

# Check response
if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    REQUEST_ID=$(echo "$RESPONSE" | jq -r '.request_id')
    STATUS=$(echo "$RESPONSE" | jq -r '.status')
    
    echo -e "${GREEN}✅ Permit request submitted successfully!${NC}"
    echo -e "${CYAN}   Request ID: ${REQUEST_ID}${NC}"
    echo -e "${CYAN}   Status: ${STATUS}${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo -e "${YELLOW}   1. Share your request ID with experts who can attest${NC}"
    echo -e "${YELLOW}   2. Wait for attestations (check status with:${NC}"
    echo -e "${YELLOW}      curl ${uSPOT}/api/permit/status/${REQUEST_ID} | jq)${NC}"
    echo -e "${YELLOW}   3. Once validated, you will receive a Verifiable Credential${NC}"
    
    # Save request ID for reference
    echo "$REQUEST_ID" > "${NOSTR_DIR}/permit_request_${PERMIT_ID}.id"
    
    exit 0
else
    ERROR=$(echo "$RESPONSE" | jq -r '.detail // .message // "Unknown error"')
    echo -e "${RED}❌ Failed to submit request: ${ERROR}${NC}"
    exit 1
fi

