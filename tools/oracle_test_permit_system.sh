#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 3.0 - Updated for 100% Dynamic System
# License: AGPL-3.0
################################################################################
# oracle_test_permit_system.sh
# Script de test complet pour le système de gestion des permis Oracle
#
# Ce script teste l'ensemble du workflow:
# 1. Initialisation des définitions de permis (NOSTR kind 30500)
# 2. Demande de permis (NOSTR kind 30501)
# 3. Attestations par des pairs (NOSTR kind 30502)
# 4. Vérification automatique et émission de credential (NOSTR kind 30503)
# 5. Récupération des credentials (W3C Verifiable Credentials)
# 6. Virement blockchain PERMIT (depuis UPLANETNAME.RnD)
# 7. Tests NOSTR (strfry query via nostr_get_events.sh)
# 8. Tests WoTx2 (professions auto-proclamées, progression automatique)
# 9. Tests authentification NIP-42
#
# ⚠️  NOTE: Tests couvrent à la fois les permits officiels et WoTx2
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Configuration
API_URL="${uSPOT:-http://localhost:54321}"
TEST_MODE="${TEST_MODE:-1}"
NOSTR_RELAY="${myRELAY:-ws://localhost:7777}"
STRFRY_DB="${STRFRY_DB:-/home/zen/.zen/strfry/strfry-db}"
TIMEOUT="${TIMEOUT:-30}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Compteurs de tests
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

################################################################################
# Fonctions utilitaires
################################################################################

# Fonction pour afficher un titre de section
section() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Fonction pour exécuter un test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}[TEST $TESTS_TOTAL] $test_name${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Fonction pour vérifier qu'une commande existe
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Fonction pour vérifier la disponibilité de l'API
check_api() {
    echo -e "${YELLOW}🔍 Checking API availability...${NC}"
    local response=$(curl -s -w "\n%{http_code}" --max-time 5 "${API_URL}/health" 2>/dev/null)
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ API available at ${API_URL}${NC}"
        return 0
    else
        echo -e "${RED}❌ API not available at ${API_URL} (HTTP ${http_code})${NC}"
        echo -e "${YELLOW}💡 Start the API first: cd UPassport && python3 54321.py${NC}"
        exit 1
    fi
}

# Fonction pour vérifier strfry et nostr_get_events.sh
check_nostr_tools() {
    echo -e "${YELLOW}🔍 Checking NOSTR tools...${NC}"
    
    # Check strfry
    if ! command -v strfry &> /dev/null; then
        echo -e "${YELLOW}⚠️  strfry not found (NOSTR tests will be skipped)${NC}"
        NOSTR_AVAILABLE=0
        return 1
    fi
    
    # Check nostr_get_events.sh
    if [ ! -f "${MY_PATH}/nostr_get_events.sh" ]; then
        echo -e "${YELLOW}⚠️  nostr_get_events.sh not found (NOSTR tests will be skipped)${NC}"
        NOSTR_AVAILABLE=0
        return 1
    fi
    
    echo -e "${GREEN}✅ NOSTR tools available${NC}"
    NOSTR_AVAILABLE=1
    return 0
}

# Fonction pour générer des données de test
get_captain_npub() {
    # Get CAPTAIN's npub from .secret.nostr file
    local captain_keyfile="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    
    if [[ ! -f "$captain_keyfile" ]]; then
        echo -e "${RED}❌ Captain keyfile not found: ${captain_keyfile}${NC}" >&2
        echo -e "${YELLOW}💡 Make sure CAPTAINEMAIL is set and the MULTIPASS exists${NC}" >&2
        return 1
    fi
    
    # Extract HEX from .secret.nostr file (format: NSEC=...; NPUB=...; HEX=...;)
    local hex=$(grep -o 'HEX=[^;]*' "$captain_keyfile" | cut -d'=' -f2 | tr -d ' ')
    
    if [[ -z "$hex" ]]; then
        echo -e "${RED}❌ Could not extract HEX from captain keyfile${NC}" >&2
        return 1
    fi
    
    echo "$hex"
}

get_captain_email() {
    # Return CAPTAIN's email
    if [[ -z "$CAPTAINEMAIL" ]]; then
        echo -e "${RED}❌ CAPTAINEMAIL is not set${NC}" >&2
        return 1
    fi
    echo "$CAPTAINEMAIL"
}

# Legacy functions for backward compatibility
generate_test_email() {
    get_captain_email || echo "test_$(date +%s)_${RANDOM}@copylaradio.com"
}

generate_test_npub() {
    get_captain_npub || echo "$(openssl rand -hex 32)"
}

authenticate_captain_nip42() {
    # Authenticate CAPTAIN via NIP-42 before running tests
    local captain_keyfile="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    
    if [[ ! -f "$captain_keyfile" ]]; then
        echo -e "${YELLOW}⚠️  Cannot authenticate: captain keyfile not found${NC}"
        return 1
    fi
    
    local relay_url="${NOSTR_RELAY}"
    
    # Build relay tag as required by NIP-42
    local relay_tag_json="[[\"relay\",\"${relay_url}\"]]"
    
    echo -e "${CYAN}🔐 Authenticating CAPTAIN via NIP-42...${NC}"
    echo -e "${BLUE}   Relay: ${relay_url}${NC}"
    echo -e "${BLUE}   Keyfile: ${captain_keyfile}${NC}"
    
    # Send NIP-42 authentication event (kind 22242)
    # Content is the relay URL, tag 'relay' is required
    python3 "${MY_PATH}/nostr_send_note.py" \
        --keyfile "$captain_keyfile" \
        --kind 22242 \
        --content "${relay_url}" \
        --relays "$relay_url" \
        --tags "$relay_tag_json" 2>&1 | head -20
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ NIP-42 authentication event sent${NC}"
        echo -e "${YELLOW}💡 Waiting 3 seconds for relay to process...${NC}"
        sleep 3
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to send NIP-42 authentication event${NC}"
        return 1
    fi
}

################################################################################
# Tests des définitions de permis
################################################################################

test_permit_definitions() {
    section "TEST 1: Récupération des définitions de permis"
    
    run_test "GET /api/permit/definitions" \
        "curl -s -f '${API_URL}/api/permit/definitions' | jq -e '.success == true'"
    
    if [ $? -eq 0 ]; then
        local response=$(curl -s "${API_URL}/api/permit/definitions")
        local count=$(echo "$response" | jq '.count // 0')
        
        if [ "$count" -gt 0 ]; then
            echo -e "${CYAN}📋 Définitions disponibles (${count}):${NC}"
            echo "$response" | jq -r '.definitions[] | "  • \(.id): \(.name) (min: \(.min_attestations) attestations)"'
        else
            echo -e "${YELLOW}⚠️  Aucune définition chargée (count: 0)${NC}"
            echo -e "${CYAN}💡 Les définitions sont chargées depuis permit_definitions.json au démarrage${NC}"
            echo -e "${CYAN}💡 Ou publiées via NOSTR events kind 30500${NC}"
        fi
    fi
}

################################################################################
# Tests de demande de permis
################################################################################

test_permit_request() {
    section "TEST 2: Demande de permis"
    
    # Authenticate CAPTAIN first
    authenticate_captain_nip42
    
    local test_email=$(generate_test_email)
    local test_npub=$(generate_test_npub)
    local permit_id="PERMIT_ORE_V1"
    
    echo -e "${CYAN}📧 Using CAPTAIN email: ${test_email}${NC}"
    echo -e "${CYAN}🔑 Using CAPTAIN npub: ${test_npub:0:16}...${NC}"
    local request_data=$(cat <<EOF
{
    "permit_definition_id": "${permit_id}",
    "applicant_npub": "${test_npub}",
    "statement": "Je demande le permis de vérificateur ORE. J'ai une expérience en audit environnemental.",
    "evidence": [
        "https://example.com/certificate1.pdf",
        "https://example.com/experience.pdf"
    ]
}
EOF
)
    
    echo -e "${YELLOW}📤 Envoi de la demande de permis...${NC}"
    local response=$(curl -s -X POST "${API_URL}/api/permit/request" \
        -H "Content-Type: application/json" \
        -d "$request_data")
    
    if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Demande de permis réussie${NC}"
        local request_id=$(echo "$response" | jq -r '.request_id')
        echo -e "${CYAN}🆔 Request ID: ${request_id}${NC}"
        
        # Sauvegarder pour les tests suivants
        echo "$request_id" > /tmp/test_permit_request_id
        echo "$test_npub" > /tmp/test_permit_npub
        
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ Échec de la demande de permis${NC}"
        echo "$response" | jq '.'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

################################################################################
# Tests des attestations
################################################################################

test_permit_attestations() {
    section "TEST 3: Attestations de permis"
    
    if [ ! -f /tmp/test_permit_request_id ]; then
        echo -e "${RED}❌ Pas de request_id de test disponible${NC}"
        return 1
    fi
    
    local request_id=$(cat /tmp/test_permit_request_id)
    local min_attestations=5  # Pour PERMIT_ORE_V1
    
    echo -e "${CYAN}🆔 Request ID: ${request_id}${NC}"
    echo -e "${YELLOW}📝 Ajout de ${min_attestations} attestations...${NC}"
    
    for i in $(seq 1 $min_attestations); do
        local attester_npub=$(generate_test_npub)
        
        local attestation_data=$(cat <<EOF
{
    "request_id": "${request_id}",
    "attester_npub": "${attester_npub}",
    "statement": "J'atteste que le demandeur possède les compétences requises pour le permis ORE V1. Attestation ${i}/${min_attestations}.",
    "attester_license_id": null
}
EOF
)
        
        echo -e "${BLUE}  [${i}/${min_attestations}] Attestation par ${attester_npub:0:16}...${NC}"
        
        local response=$(curl -s -X POST "${API_URL}/api/permit/attest" \
            -H "Content-Type: application/json" \
            -d "$attestation_data")
        
        if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
            local status=$(echo "$response" | jq -r '.status')
            local count=$(echo "$response" | jq -r '.attestations_count')
            echo -e "${GREEN}    ✅ Attestation ajoutée (${count}/${min_attestations}) - Status: ${status}${NC}"
            
            # Si c'est la dernière attestation, vérifier que le credential a été émis
            if [ "$i" -eq "$min_attestations" ]; then
                if [ "$status" = "validated" ]; then
                    echo -e "${GREEN}    🎉 CREDENTIAL ÉMIS AUTOMATIQUEMENT!${NC}"
                fi
            fi
        else
            echo -e "${RED}    ❌ Échec de l'attestation${NC}"
            echo "$response" | jq '.'
        fi
        
        sleep 1  # Petit délai entre les attestations
    done
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

################################################################################
# Tests de vérification du statut
################################################################################

test_permit_status() {
    section "TEST 4: Vérification du statut du permis"
    
    if [ ! -f /tmp/test_permit_request_id ]; then
        echo -e "${RED}❌ Pas de request_id de test disponible${NC}"
        return 1
    fi
    
    local request_id=$(cat /tmp/test_permit_request_id)
    
    echo -e "${YELLOW}🔍 Récupération du statut...${NC}"
    local response=$(curl -s "${API_URL}/api/permit/status/${request_id}")
    
    if echo "$response" | jq -e '.status' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Statut récupéré${NC}"
        echo ""
        echo -e "${CYAN}📊 Détails du permis:${NC}"
        echo "$response" | jq '.'
        
        local status=$(echo "$response" | jq -r '.status')
        local attestations_count=$(echo "$response" | jq -r '.attestations | length')
        
        echo ""
        echo -e "${CYAN}  Status: ${status}${NC}"
        echo -e "${CYAN}  Attestations: ${attestations_count}${NC}"
        
        if [ "$status" = "validated" ]; then
            echo -e "${GREEN}  🎉 Permis VALIDÉ et credential émis!${NC}"
        fi
        
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ Échec de récupération du statut${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

################################################################################
# Tests de listing des permis
################################################################################

test_permit_list() {
    section "TEST 5: Listing des permis"
    
    if [ ! -f /tmp/test_permit_npub ]; then
        echo -e "${YELLOW}⚠️  Pas de npub de test disponible, test du listing global${NC}"
    fi
    
    # Test 5.1: Liste de toutes les demandes
    run_test "GET /api/permit/list?type=requests" \
        "curl -s -f '${API_URL}/api/permit/list?type=requests' | jq -e '.success == true'"
    
    if [ $? -eq 0 ]; then
        echo -e "${CYAN}📋 Demandes de permis:${NC}"
        curl -s "${API_URL}/api/permit/list?type=requests" | jq -r '.results[] | "  • \(.request_id): \(.permit_definition_id) - \(.status)"' | head -5
    fi
    
    # Test 5.2: Liste de tous les credentials
    run_test "GET /api/permit/list?type=credentials" \
        "curl -s -f '${API_URL}/api/permit/list?type=credentials' | jq -e '.success == true'"
    
    if [ $? -eq 0 ]; then
        echo -e "${CYAN}🎫 Credentials émis:${NC}"
        curl -s "${API_URL}/api/permit/list?type=credentials" | jq -r '.results[] | "  • \(.credential_id): \(.permit_definition_id) - \(.status)"' | head -5
    fi
}

################################################################################
# Tests de récupération de credential
################################################################################

test_credential_retrieval() {
    section "TEST 6: Récupération d'un Verifiable Credential"
    
    echo -e "${YELLOW}🔍 Récupération de la liste des credentials...${NC}"
    local credentials=$(curl -s "${API_URL}/api/permit/list?type=credentials")
    local credential_id=$(echo "$credentials" | jq -r '.results[0].credential_id // empty')
    
    if [ -z "$credential_id" ]; then
        echo -e "${YELLOW}⚠️  Aucun credential disponible pour ce test${NC}"
        echo -e "${CYAN}💡 Créez d'abord un permis validé avec au moins 5 attestations${NC}"
        return 0
    fi
    
    echo -e "${CYAN}🆔 Credential ID: ${credential_id}${NC}"
    
    run_test "GET /api/permit/credential/${credential_id}" \
        "curl -s -f '${API_URL}/api/permit/credential/${credential_id}' | jq -e '.type | contains([\"VerifiableCredential\"])'"
    
    if [ $? -eq 0 ]; then
        echo -e "${CYAN}📜 Verifiable Credential (W3C format):${NC}"
        curl -s "${API_URL}/api/permit/credential/${credential_id}" | jq '.'
    fi
}

################################################################################
# Tests Web Interface and WoT Bootstrap
################################################################################

test_helper_scripts() {
    section "TEST 7: Oracle Web Interface & Bootstrap Scripts"
    
    # Test 7.1: Vérifier l'interface web oracle.html
    if [ -f "${MY_PATH}/../../UPassport/templates/oracle.html" ]; then
        echo -e "${GREEN}✅ oracle.html web interface exists${NC}"
        run_test "oracle.html is readable" \
            "[ -r '${MY_PATH}/../../UPassport/templates/oracle.html' ]"
    else
        echo -e "${RED}❌ oracle.html not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test 7.2: Vérifier l'interface web wotx2.html (WoTx2)
    if [ -f "${MY_PATH}/../../UPassport/templates/wotx2.html" ]; then
        echo -e "${GREEN}✅ wotx2.html web interface exists${NC}"
        run_test "wotx2.html is readable" \
            "[ -r '${MY_PATH}/../../UPassport/templates/wotx2.html' ]"
    else
        echo -e "${RED}❌ wotx2.html not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test 7.3: Vérifier le script de bootstrap WoT (officiels uniquement)
    if [ -f "${MY_PATH}/oracle.WoT_PERMIT.init.sh" ]; then
        echo -e "${GREEN}✅ oracle.WoT_PERMIT.init.sh exists${NC}"
        run_test "oracle.WoT_PERMIT.init.sh is executable" \
            "[ -x '${MY_PATH}/oracle.WoT_PERMIT.init.sh' ]"
        echo -e "${CYAN}💡 Note: This script is for OFFICIAL PERMITS only${NC}"
        echo -e "${CYAN}   WoTx2 professions do NOT require bootstrap${NC}"
    else
        echo -e "${RED}❌ oracle.WoT_PERMIT.init.sh not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test 7.4: Vérifier le script de gestion des permits
    if [ -f "${MY_PATH}/oracle_init_permit_definitions.sh" ]; then
        echo -e "${GREEN}✅ oracle_init_permit_definitions.sh exists${NC}"
        run_test "oracle_init_permit_definitions.sh is executable" \
            "[ -x '${MY_PATH}/oracle_init_permit_definitions.sh' ]"
    else
        echo -e "${RED}❌ oracle_init_permit_definitions.sh not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo -e "${CYAN}💡 Web interfaces: /oracle (officiels) and /wotx2 (auto-proclamés)${NC}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 4))
}

################################################################################
# Test du virement PERMIT
################################################################################

test_permit_virement() {
    section "TEST 8: PERMIT Payment (blockchain)"
    
    echo -e "${YELLOW}⚠️  This test requires:${NC}"
    echo -e "  1. A configured UPLANETNAME_RnD wallet"
    echo -e "  2. Available funds in RnD wallet"
    echo -e "  3. A created MULTIPASS for the recipient"
    echo ""
    
    read -p "Do you want to test PERMIT payment? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}⏭️  PERMIT payment test skipped${NC}"
        return 0
    fi
    
    read -p "Recipient email: " email
    if [ -z "$email" ]; then
        echo -e "${RED}❌ Email required${NC}"
        return 1
    fi
    
    read -p "Permit ID (e.g., PERMIT_WOT_DRAGON): " permit_id
    permit_id="${permit_id:-PERMIT_WOT_DRAGON}"
    
    read -p "Amount in Ẑen (default: 100): " montant
    montant="${montant:-100}"
    
    echo ""
    echo -e "${CYAN}🚀 Launching PERMIT payment...${NC}"
    
    if bash "${MY_PATH}/../UPLANET.official.sh" -p "$email" "$permit_id" -m "$montant"; then
        echo -e "${GREEN}✅ PERMIT payment successful${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ PERMIT payment failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

################################################################################
# Tests NOSTR - Vérification des événements publiés
################################################################################

test_nostr_events() {
    section "TEST 10: Événements NOSTR (strfry + nostr_get_events.sh)"
    
    if [ "$NOSTR_AVAILABLE" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  NOSTR tools not available, skipping NOSTR tests${NC}"
        return 0
    fi
    
    # Test 10.1: Vérifier les événements kind 30500 (Permit Definitions)
    echo -e "${CYAN}📡 Querying kind 30500 (Permit Definitions)...${NC}"
    local definitions=$(bash "${MY_PATH}/nostr_get_events.sh" --kind 30500 --limit 10)
    local def_count=$(echo "$definitions" | grep -c '"kind":30500' || echo "0")
    
    if [ "$def_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${def_count} permit definitions in strfry${NC}"
        echo "$definitions" | jq -r '.content' | head -5
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No permit definitions found in strfry${NC}"
        echo -e "${CYAN}💡 Run oracle.WoT_PERMIT.init.sh to initialize permits${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 10.2: Vérifier les événements kind 30501 (Permit Requests)
    echo -e "${CYAN}📡 Querying kind 30501 (Permit Requests)...${NC}"
    local requests=$(bash "${MY_PATH}/nostr_get_events.sh" --kind 30501 --limit 10)
    local req_count=$(echo "$requests" | grep -c '"kind":30501' || echo "0")
    
    if [ "$req_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${req_count} permit requests in strfry${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No permit requests found in strfry${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 10.3: Vérifier les événements kind 30502 (Attestations)
    echo -e "${CYAN}📡 Querying kind 30502 (Attestations)...${NC}"
    local attestations=$(bash "${MY_PATH}/nostr_get_events.sh" --kind 30502 --limit 10)
    local att_count=$(echo "$attestations" | grep -c '"kind":30502' || echo "0")
    
    if [ "$att_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${att_count} attestations in strfry${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No attestations found in strfry${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 10.4: Vérifier les événements kind 30503 (Credentials)
    echo -e "${CYAN}📡 Querying kind 30503 (Credentials)...${NC}"
    local credentials=$(bash "${MY_PATH}/nostr_get_events.sh" --kind 30503 --limit 10)
    local cred_count=$(echo "$credentials" | grep -c '"kind":30503' || echo "0")
    
    if [ "$cred_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${cred_count} credentials in strfry${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No credentials found in strfry${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 10.5: Tester la recherche par auteur
    if [ -f /tmp/test_permit_npub ]; then
        local test_npub=$(cat /tmp/test_permit_npub)
        echo -e "${CYAN}📡 Querying events by author ${test_npub:0:16}...${NC}"
        local author_events=$(bash "${MY_PATH}/nostr_get_events.sh" --kind 30501 --author "$test_npub" --limit 5)
        local author_count=$(echo "$author_events" | grep -c '"kind":' || echo "0")
        
        if [ "$author_count" -gt 0 ]; then
            echo -e "${GREEN}✅ Found ${author_count} events from test author${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${YELLOW}⚠️  No events found from test author${NC}"
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
    
    # Test 10.6: Vérifier les professions auto-proclamées (WoTx2)
    echo -e "${CYAN}📡 Querying WoTx2 auto-proclaimed professions (PERMIT_*_X*)...${NC}"
    local wotx2_defs=$(echo "$definitions" | jq -r 'select(.id | startswith("PERMIT_")) | .id' 2>/dev/null || echo "")
    local wotx2_count=$(echo "$wotx2_defs" | grep -c "PERMIT_" || echo "0")
    
    if [ "$wotx2_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${wotx2_count} WoTx2 auto-proclaimed profession(s)${NC}"
        echo "$wotx2_defs" | head -5 | while read -r permit_id; do
            local level=$(echo "$permit_id" | grep -oE '_X[0-9]+$' | sed 's/_X//')
            echo -e "${CYAN}   • ${permit_id} (Niveau X${level})${NC}"
        done
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No WoTx2 auto-proclaimed professions found${NC}"
        echo -e "${CYAN}💡 Create one via /wotx2 interface${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 10.7: Vérifier les événements NIP-42 (authentification)
    echo -e "${CYAN}📡 Querying kind 22242 (NIP-42 authentication events)...${NC}"
    local nip42_events=$(bash "${MY_PATH}/nostr_get_events.sh" --kind 22242 --limit 10 2>/dev/null)
    local nip42_count=$(echo "$nip42_events" | grep -c '"kind":22242' || echo "0")
    
    if [ "$nip42_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${nip42_count} NIP-42 authentication event(s)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No NIP-42 authentication events found${NC}"
        echo -e "${CYAN}💡 NIP-42 events are sent before API calls for permit creation${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

################################################################################
# Tests API NOSTR Fetch
################################################################################

test_api_nostr_fetch() {
    section "TEST 11: API NOSTR Fetch Routes"
    
    # Test 11.1: Fetch permit definitions from NOSTR
    run_test "GET /api/permit/nostr/fetch?type=definitions" \
        "curl -s -f '${API_URL}/api/permit/nostr/fetch?type=definitions' | jq -e '.success == true'"
    
    if [ $? -eq 0 ]; then
        local defs=$(curl -s "${API_URL}/api/permit/nostr/fetch?type=definitions")
        local count=$(echo "$defs" | jq '.count // 0')
        echo -e "${CYAN}📊 Found ${count} definitions via API${NC}"
    fi
    
    # Test 11.2: Fetch permit requests from NOSTR
    run_test "GET /api/permit/nostr/fetch?type=requests" \
        "curl -s -f '${API_URL}/api/permit/nostr/fetch?type=requests' | jq -e '.success == true'"
    
    if [ $? -eq 0 ]; then
        local reqs=$(curl -s "${API_URL}/api/permit/nostr/fetch?type=requests")
        local count=$(echo "$reqs" | jq '.count // 0')
        echo -e "${CYAN}📊 Found ${count} requests via API${NC}"
    fi
    
    # Test 11.3: Fetch credentials from NOSTR
    run_test "GET /api/permit/nostr/fetch?type=credentials" \
        "curl -s -f '${API_URL}/api/permit/nostr/fetch?type=credentials' | jq -e '.success == true'"
    
    if [ $? -eq 0 ]; then
        local creds=$(curl -s "${API_URL}/api/permit/nostr/fetch?type=credentials")
        local count=$(echo "$creds" | jq '.count // 0')
        echo -e "${CYAN}📊 Found ${count} credentials via API${NC}"
    fi
}

################################################################################
# Tests WoTx2 - Professions Auto-Proclamées
################################################################################

test_wotx2_system() {
    section "TEST 13: WoTx2 - Auto-Proclaimed Professions"
    
    echo -e "${CYAN}🧪 Testing WoTx2 system (100% dynamic)${NC}"
    echo ""
    
    # Test 13.1: Vérifier que les professions auto-proclamées existent
    echo -e "${YELLOW}Test 13.1: Check for WoTx2 auto-proclaimed professions${NC}"
    local definitions=$(curl -s "${API_URL}/api/permit/definitions")
    local wotx2_permits=$(echo "$definitions" | jq -r '.definitions[]? | select(.id | startswith("PERMIT_")) | .id' 2>/dev/null)
    local wotx2_count=$(echo "$wotx2_permits" | grep -c "PERMIT_" || echo "0")
    
    if [ "$wotx2_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${wotx2_count} WoTx2 profession(s)${NC}"
        echo "$wotx2_permits" | head -5 | while read -r permit_id; do
            local level=$(echo "$permit_id" | grep -oE '_X[0-9]+$' | sed 's/_X//')
            local name=$(echo "$definitions" | jq -r ".definitions[]? | select(.id == \"$permit_id\") | .name" 2>/dev/null)
            echo -e "${CYAN}   • ${permit_id} - ${name} (Niveau X${level})${NC}"
        done
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No WoTx2 professions found${NC}"
        echo -e "${CYAN}💡 Create one via /wotx2 interface${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 13.2: Vérifier la progression automatique (X1 → X2 → ...)
    echo ""
    echo -e "${YELLOW}Test 13.2: Check automatic progression (X1 → X2 → ...)${NC}"
    local progression_found=0
    
    for base_permit in $(echo "$wotx2_permits" | sed 's/_X[0-9]\+$//' | sort -u); do
        local levels=$(echo "$wotx2_permits" | grep "^${base_permit}_X" | sed 's/.*_X\([0-9]\+\)$/\1/' | sort -n)
        local level_count=$(echo "$levels" | wc -l)
        
        if [ "$level_count" -gt 1 ]; then
            echo -e "${GREEN}✅ Progression found for ${base_permit}:${NC}"
            echo "$levels" | while read -r level; do
                echo -e "${CYAN}   • Niveau X${level}${NC}"
            done
            progression_found=1
            break
        fi
    done
    
    if [ "$progression_found" -eq 1 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  No progression found (need at least X1 and X2)${NC}"
        echo -e "${CYAN}💡 Progression is automatic when X1 is validated${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 13.3: Vérifier les labels dynamiques
    echo ""
    echo -e "${YELLOW}Test 13.3: Check dynamic labels (Expert, Maître, etc.)${NC}"
    local labels_ok=0
    
    for permit_id in $(echo "$wotx2_permits" | head -10); do
        local level=$(echo "$permit_id" | grep -oE '_X[0-9]+$' | sed 's/_X//')
        local name=$(echo "$definitions" | jq -r ".definitions[]? | select(.id == \"$permit_id\") | .name" 2>/dev/null)
        
        if [[ $level -le 4 ]]; then
            if echo "$name" | grep -q "Niveau X${level}"; then
                labels_ok=1
            fi
        elif [[ $level -le 10 ]]; then
            if echo "$name" | grep -q "Expert"; then
                labels_ok=1
            fi
        elif [[ $level -le 50 ]]; then
            if echo "$name" | grep -q "Maître"; then
                labels_ok=1
            fi
        elif [[ $level -le 100 ]]; then
            if echo "$name" | grep -q "Grand Maître"; then
                labels_ok=1
            fi
        else
            if echo "$name" | grep -q "Maître Absolu"; then
                labels_ok=1
            fi
        fi
    done
    
    if [ "$labels_ok" -eq 1 ]; then
        echo -e "${GREEN}✅ Dynamic labels are correctly applied${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  Could not verify dynamic labels${NC}"
        echo -e "${CYAN}💡 Labels: X1-X4 (basic), X5-X10 (Expert), X11-X50 (Maître), etc.${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Test 13.4: Vérifier l'interface /wotx2
    echo ""
    echo -e "${YELLOW}Test 13.4: Check /wotx2 web interface${NC}"
    if curl -s -f "${API_URL}/wotx2" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ /wotx2 interface is accessible${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ /wotx2 interface not accessible${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo ""
    echo -e "${CYAN}💡 WoTx2 Summary:${NC}"
    echo -e "${CYAN}   • Auto-proclaimed professions: ${wotx2_count}${NC}"
    echo -e "${CYAN}   • Progression: Automatic (X1 → X2 → ... → X144 → ...)${NC}"
    echo -e "${CYAN}   • Bootstrap: NOT required (starts with 1 signature)${NC}"
    echo -e "${CYAN}   • Interface: ${API_URL}/wotx2${NC}"
}

################################################################################
# Test du système Oracle complet
################################################################################

test_oracle_system() {
    section "TEST 9: Oracle System (oracle_system.py)"
    
    # Vérifier que oracle_system.py existe
    if [ -f "${MY_PATH}/../../UPassport/oracle_system.py" ]; then
        echo -e "${GREEN}✅ oracle_system.py found${NC}"
        
        run_test "oracle_system.py syntax is correct" \
            "python3 -m py_compile '${MY_PATH}/../../UPassport/oracle_system.py'"
        
        # Test import
        run_test "oracle_system.py can be imported" \
            "python3 -c 'import sys; sys.path.insert(0, \"${MY_PATH}/../../UPassport\"); import oracle_system'"
    else
        echo -e "${RED}❌ oracle_system.py not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
}

show_summary() {
    section "TEST SUMMARY"
    
    echo -e "${CYAN}Tests executed: ${TESTS_TOTAL}${NC}"
    echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"
    echo ""
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo -e "${CYAN}Success rate: ${success_rate}%${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}⚠️  SOME TESTS FAILED${NC}"
        return 1
    fi
}

################################################################################
# Menu principal
################################################################################

show_menu() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         TEST DU SYSTÈME DE GESTION DES PERMIS ORACLE          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1. 🧪 Run ALL tests (automated)"
    echo "2. 📋 Test: Permit definitions"
    echo "3. 📝 Test: Permit request"
    echo "4. ✍️  Test: Attestations"
    echo "5. 📊 Test: Status verification"
    echo "6. 📑 Test: Permit listing"
    echo "7. 🎫 Test: Credential retrieval"
    echo "8. 🛠️  Test: Helper scripts"
    echo "9. 🔧 Test: Oracle system"
    echo "10. 📡 Test: NOSTR events (strfry)"
    echo "11. 🌐 Test: API NOSTR fetch"
    echo "12. 💰 Test: PERMIT payment"
    echo "13. 🚀 Test: WoTx2 (auto-proclaimed professions)"
    echo "14. 🚪 Exit"
    echo ""
    read -p "Choose an option (1-14): " choice
    
    case $choice in
        1)
            run_all_tests
            ;;
        2)
            test_permit_definitions
            ;;
        3)
            test_permit_request
            ;;
        4)
            test_permit_attestations
            ;;
        5)
            test_permit_status
            ;;
        6)
            test_permit_list
            ;;
        7)
            test_credential_retrieval
            ;;
        8)
            test_helper_scripts
            ;;
        9)
            test_oracle_system
            ;;
        10)
            test_nostr_events
            ;;
        11)
            test_api_nostr_fetch
            ;;
        12)
            test_permit_virement
            ;;
        13)
            test_wotx2_system
            ;;
        14)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            ;;
    esac
}

run_all_tests() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║               RUNNING ALL TESTS                                ║${NC}"
    echo -e "${MAGENTA}║         (Official Permits + WoTx2 Auto-Proclaimed)            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    test_permit_definitions
    test_permit_request
    test_permit_attestations
    test_permit_status
    test_permit_list
    test_credential_retrieval
    test_helper_scripts
    test_oracle_system
    test_nostr_events
    test_api_nostr_fetch
    test_wotx2_system
    
    # Test du virement PERMIT (optionnel)
    echo ""
    echo -e "${YELLOW}⚠️  PERMIT payment test requires blockchain configuration${NC}"
    test_permit_virement
    
    show_summary
}

################################################################################
# Point d'entrée principal
################################################################################

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    🧪 TEST SUITE - ORACLE PERMIT MANAGEMENT SYSTEM            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Vérifier les dépendances
    echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
    check_command "curl"
    check_command "jq"
    check_command "openssl"
    check_command "python3"
    echo -e "${GREEN}✅ All required dependencies are installed${NC}"
    echo ""
    
    # Vérifier l'API
    check_api
    echo ""
    
    # Vérifier les outils NOSTR
    check_nostr_tools
    echo ""
    
    # Si des arguments sont fournis, exécuter tous les tests
    if [ "$1" = "--all" ] || [ "$1" = "-a" ]; then
        run_all_tests
        exit $?
    fi
    
    # Sinon, afficher le menu
    while true; do
        show_menu
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Nettoyer les fichiers temporaires à la sortie
cleanup() {
    rm -f /tmp/test_permit_request_id
    rm -f /tmp/test_permit_npub
}

trap cleanup EXIT

# Exécuter le script principal
main "$@"



show_summary() {
    section "TEST SUMMARY"
    
    echo -e "${CYAN}Tests executed: ${TESTS_TOTAL}${NC}"
    echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"
    echo ""
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo -e "${CYAN}Success rate: ${success_rate}%${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}⚠️  SOME TESTS FAILED${NC}"
        return 1
    fi
}

################################################################################
# Menu principal
################################################################################

show_menu() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         TEST DU SYSTÈME DE GESTION DES PERMIS ORACLE          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1. 🧪 Run ALL tests (automated)"
    echo "2. 📋 Test: Permit definitions"
    echo "3. 📝 Test: Permit request"
    echo "4. ✍️  Test: Attestations"
    echo "5. 📊 Test: Status verification"
    echo "6. 📑 Test: Permit listing"
    echo "7. 🎫 Test: Credential retrieval"
    echo "8. 🛠️  Test: Helper scripts"
    echo "9. 🔧 Test: Oracle system"
    echo "10. 📡 Test: NOSTR events (strfry)"
    echo "11. 🌐 Test: API NOSTR fetch"
    echo "12. 💰 Test: PERMIT payment"
    echo "13. 🚀 Test: WoTx2 (auto-proclaimed professions)"
    echo "14. 🚪 Exit"
    echo ""
    read -p "Choose an option (1-14): " choice
    
    case $choice in
        1)
            run_all_tests
            ;;
        2)
            test_permit_definitions
            ;;
        3)
            test_permit_request
            ;;
        4)
            test_permit_attestations
            ;;
        5)
            test_permit_status
            ;;
        6)
            test_permit_list
            ;;
        7)
            test_credential_retrieval
            ;;
        8)
            test_helper_scripts
            ;;
        9)
            test_oracle_system
            ;;
        10)
            test_nostr_events
            ;;
        11)
            test_api_nostr_fetch
            ;;
        12)
            test_permit_virement
            ;;
        13)
            test_wotx2_system
            ;;
        14)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            ;;
    esac
}

run_all_tests() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║               RUNNING ALL TESTS                                ║${NC}"
    echo -e "${MAGENTA}║         (Official Permits + WoTx2 Auto-Proclaimed)            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    test_permit_definitions
    test_permit_request
    test_permit_attestations
    test_permit_status
    test_permit_list
    test_credential_retrieval
    test_helper_scripts
    test_oracle_system
    test_nostr_events
    test_api_nostr_fetch
    test_wotx2_system
    
    # Test du virement PERMIT (optionnel)
    echo ""
    echo -e "${YELLOW}⚠️  PERMIT payment test requires blockchain configuration${NC}"
    test_permit_virement
    
    show_summary
}

################################################################################
# Point d'entrée principal
################################################################################

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    🧪 TEST SUITE - ORACLE PERMIT MANAGEMENT SYSTEM            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Vérifier les dépendances
    echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
    check_command "curl"
    check_command "jq"
    check_command "openssl"
    check_command "python3"
    echo -e "${GREEN}✅ All required dependencies are installed${NC}"
    echo ""
    
    # Vérifier l'API
    check_api
    echo ""
    
    # Vérifier les outils NOSTR
    check_nostr_tools
    echo ""
    
    # Si des arguments sont fournis, exécuter tous les tests
    if [ "$1" = "--all" ] || [ "$1" = "-a" ]; then
        run_all_tests
        exit $?
    fi
    
    # Sinon, afficher le menu
    while true; do
        show_menu
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Nettoyer les fichiers temporaires à la sortie
cleanup() {
    rm -f /tmp/test_permit_request_id
    rm -f /tmp/test_permit_npub
}

trap cleanup EXIT

# Exécuter le script principal
main "$@"



show_summary() {
    section "TEST SUMMARY"
    
    echo -e "${CYAN}Tests executed: ${TESTS_TOTAL}${NC}"
    echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"
    echo ""
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo -e "${CYAN}Success rate: ${success_rate}%${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}⚠️  SOME TESTS FAILED${NC}"
        return 1
    fi
}

################################################################################
# Menu principal
################################################################################

show_menu() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         TEST DU SYSTÈME DE GESTION DES PERMIS ORACLE          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1. 🧪 Run ALL tests (automated)"
    echo "2. 📋 Test: Permit definitions"
    echo "3. 📝 Test: Permit request"
    echo "4. ✍️  Test: Attestations"
    echo "5. 📊 Test: Status verification"
    echo "6. 📑 Test: Permit listing"
    echo "7. 🎫 Test: Credential retrieval"
    echo "8. 🛠️  Test: Helper scripts"
    echo "9. 🔧 Test: Oracle system"
    echo "10. 📡 Test: NOSTR events (strfry)"
    echo "11. 🌐 Test: API NOSTR fetch"
    echo "12. 💰 Test: PERMIT payment"
    echo "13. 🚀 Test: WoTx2 (auto-proclaimed professions)"
    echo "14. 🚪 Exit"
    echo ""
    read -p "Choose an option (1-14): " choice
    
    case $choice in
        1)
            run_all_tests
            ;;
        2)
            test_permit_definitions
            ;;
        3)
            test_permit_request
            ;;
        4)
            test_permit_attestations
            ;;
        5)
            test_permit_status
            ;;
        6)
            test_permit_list
            ;;
        7)
            test_credential_retrieval
            ;;
        8)
            test_helper_scripts
            ;;
        9)
            test_oracle_system
            ;;
        10)
            test_nostr_events
            ;;
        11)
            test_api_nostr_fetch
            ;;
        12)
            test_permit_virement
            ;;
        13)
            test_wotx2_system
            ;;
        14)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            ;;
    esac
}

run_all_tests() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║               RUNNING ALL TESTS                                ║${NC}"
    echo -e "${MAGENTA}║         (Official Permits + WoTx2 Auto-Proclaimed)            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    test_permit_definitions
    test_permit_request
    test_permit_attestations
    test_permit_status
    test_permit_list
    test_credential_retrieval
    test_helper_scripts
    test_oracle_system
    test_nostr_events
    test_api_nostr_fetch
    test_wotx2_system
    
    # Test du virement PERMIT (optionnel)
    echo ""
    echo -e "${YELLOW}⚠️  PERMIT payment test requires blockchain configuration${NC}"
    test_permit_virement
    
    show_summary
}

################################################################################
# Point d'entrée principal
################################################################################

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    🧪 TEST SUITE - ORACLE PERMIT MANAGEMENT SYSTEM            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Vérifier les dépendances
    echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
    check_command "curl"
    check_command "jq"
    check_command "openssl"
    check_command "python3"
    echo -e "${GREEN}✅ All required dependencies are installed${NC}"
    echo ""
    
    # Vérifier l'API
    check_api
    echo ""
    
    # Vérifier les outils NOSTR
    check_nostr_tools
    echo ""
    
    # Si des arguments sont fournis, exécuter tous les tests
    if [ "$1" = "--all" ] || [ "$1" = "-a" ]; then
        run_all_tests
        exit $?
    fi
    
    # Sinon, afficher le menu
    while true; do
        show_menu
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Nettoyer les fichiers temporaires à la sortie
cleanup() {
    rm -f /tmp/test_permit_request_id
    rm -f /tmp/test_permit_npub
}

trap cleanup EXIT

# Exécuter le script principal
main "$@"
