#!/bin/bash
################################################################################
# Script: oracle_init_permit_definitions.sh
# Description: Initialize permit definitions from JSON template
#
# This script loads permit definitions from the JSON template and creates
# them in the oracle system.
#
# Usage: ./oracle_init_permit_definitions.sh
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

DEFINITIONS_FILE="${MY_PATH}/../templates/NOSTR/permit_definitions.json"

echo -e "${CYAN}🎫 Initializing Permit Definitions${NC}"
echo -e "${BLUE}   Loading from: ${DEFINITIONS_FILE}${NC}"

if [[ ! -f "$DEFINITIONS_FILE" ]]; then
    echo -e "${RED}❌ Definitions file not found: ${DEFINITIONS_FILE}${NC}"
    exit 1
fi

# Read definitions and create them one by one
DEFINITIONS=$(jq -c '.definitions[]' "$DEFINITIONS_FILE")

COUNT=0
TOTAL=$(echo "$DEFINITIONS" | wc -l)

while IFS= read -r definition; do
    PERMIT_ID=$(echo "$definition" | jq -r '.id')
    PERMIT_NAME=$(echo "$definition" | jq -r '.name')
    MIN_ATTESTATIONS=$(echo "$definition" | jq -r '.min_attestations')
    REQUIRED_LICENSE=$(echo "$definition" | jq -r '.required_license')
    VALID_DAYS=$(echo "$definition" | jq -r '.valid_duration_days')
    
    echo -e "${CYAN}📋 Creating permit: ${PERMIT_ID} (${PERMIT_NAME})${NC}"
    
    # Create permit definition via API
    RESPONSE=$(curl -s -X POST "${uSPOT}/api/permit/define" \
        -H "Content-Type: application/json" \
        -d "$definition")
    
    if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
        COUNT=$((COUNT + 1))
        echo -e "${GREEN}✅ Created: ${PERMIT_ID}${NC}"
    else
        ERROR=$(echo "$RESPONSE" | jq -r '.detail // .message // "Unknown error"')
        if echo "$ERROR" | grep -q "already exists"; then
            echo -e "${YELLOW}⚠️  Already exists: ${PERMIT_ID}${NC}"
        else
            echo -e "${RED}❌ Failed: ${PERMIT_ID} - ${ERROR}${NC}"
        fi
    fi
done <<< "$DEFINITIONS"

echo -e "${GREEN}✅ Initialization complete: ${COUNT}/${TOTAL} permit definitions created${NC}"

