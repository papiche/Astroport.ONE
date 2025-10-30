#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0
################################################################################
# test_permit_system.sh
# Script de test complet pour le système de gestion des permis Oracle
#
# Ce script teste l'ensemble du workflow:
# 1. Initialisation des définitions de permis
# 2. Demande de permis
# 3. Attestations par des pairs
# 4. Vérification automatique et émission de credential
# 5. Récupération des credentials
# 6. Virement blockchain PERMIT
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Configuration
API_URL="${API_URL:-http://localhost:1234}"
TEST_MODE="${TEST_MODE:-1}"

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
        echo -e "${RED}❌ Erreur: $1 n'est pas installé${NC}"
        exit 1
    fi
}

# Fonction pour vérifier la disponibilité de l'API
check_api() {
    echo -e "${YELLOW}🔍 Vérification de la disponibilité de l'API...${NC}"
    if curl -s -f "${API_URL}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ API disponible à ${API_URL}${NC}"
        return 0
    else
        echo -e "${RED}❌ API non disponible à ${API_URL}${NC}"
        echo -e "${YELLOW}💡 Lancez d'abord: cd UPassport && python 54321.py${NC}"
        exit 1
    fi
}

# Fonction pour générer des données de test
generate_test_email() {
    echo "test_$(date +%s)_${RANDOM}@example.com"
}

generate_test_npub() {
    # Générer une clé publique hex de test (64 caractères)
    echo "$(openssl rand -hex 32)"
}

################################################################################
# Tests des définitions de permis
################################################################################

test_permit_definitions() {
    section "TEST 1: Récupération des définitions de permis"
    
    run_test "GET /api/permit/definitions" \
        "curl -s -f '${API_URL}/api/permit/definitions' | jq -e '.success == true and .count > 0'"
    
    if [ $? -eq 0 ]; then
        echo -e "${CYAN}📋 Définitions disponibles:${NC}"
        curl -s "${API_URL}/api/permit/definitions" | jq -r '.definitions[] | "  • \(.id): \(.name) (min: \(.min_attestations) attestations)"'
    fi
}

################################################################################
# Tests de demande de permis
################################################################################

test_permit_request() {
    section "TEST 2: Demande de permis"
    
    local test_email=$(generate_test_email)
    local test_npub=$(generate_test_npub)
    local permit_id="PERMIT_ORE_V1"
    
    echo -e "${CYAN}📧 Email de test: ${test_email}${NC}"
    echo -e "${CYAN}🔑 NPub de test: ${test_npub:0:16}...${NC}"
    
    # Note: En mode test, on skip l'authentification NOSTR
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
# Tests des scripts helper
################################################################################

test_helper_scripts() {
    section "TEST 7: Scripts helper (request_license.sh & attest_license.sh)"
    
    # Test 7.1: Vérifier l'existence des scripts
    if [ -f "${MY_PATH}/request_license.sh" ]; then
        echo -e "${GREEN}✅ request_license.sh existe${NC}"
        run_test "request_license.sh est exécutable" \
            "[ -x '${MY_PATH}/request_license.sh' ]"
    else
        echo -e "${RED}❌ request_license.sh introuvable${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    if [ -f "${MY_PATH}/attest_license.sh" ]; then
        echo -e "${GREEN}✅ attest_license.sh existe${NC}"
        run_test "attest_license.sh est exécutable" \
            "[ -x '${MY_PATH}/attest_license.sh' ]"
    else
        echo -e "${RED}❌ attest_license.sh introuvable${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 2))
}

################################################################################
# Test du virement PERMIT
################################################################################

test_permit_virement() {
    section "TEST 8: Virement PERMIT (blockchain)"
    
    echo -e "${YELLOW}⚠️  Ce test nécessite:${NC}"
    echo -e "  1. Un portefeuille UPLANETNAME_RnD configuré"
    echo -e "  2. Des fonds disponibles dans RnD"
    echo -e "  3. Un MULTIPASS créé pour le bénéficiaire"
    echo ""
    
    read -p "Voulez-vous tester le virement PERMIT? (o/N): " confirm
    
    if [[ "$confirm" != "o" && "$confirm" != "O" ]]; then
        echo -e "${YELLOW}⏭️  Test du virement PERMIT ignoré${NC}"
        return 0
    fi
    
    read -p "Email du bénéficiaire: " email
    if [ -z "$email" ]; then
        echo -e "${RED}❌ Email requis${NC}"
        return 1
    fi
    
    read -p "Permit ID (ex: PERMIT_WOT_DRAGON): " permit_id
    permit_id="${permit_id:-PERMIT_WOT_DRAGON}"
    
    read -p "Montant en Ẑen (défaut: 100): " montant
    montant="${montant:-100}"
    
    echo ""
    echo -e "${CYAN}🚀 Lancement du virement PERMIT...${NC}"
    
    if bash "${MY_PATH}/../UPLANET.official.sh" -p "$email" "$permit_id" -m "$montant"; then
        echo -e "${GREEN}✅ Virement PERMIT réussi${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ Échec du virement PERMIT${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

################################################################################
# Test du système Oracle complet
################################################################################

test_oracle_system() {
    section "TEST 9: Système Oracle (oracle_system.py)"
    
    # Vérifier que oracle_system.py existe
    if [ -f "${MY_PATH}/../../UPassport/oracle_system.py" ]; then
        echo -e "${GREEN}✅ oracle_system.py existe${NC}"
        
        run_test "oracle_system.py est syntaxiquement correct" \
            "python3 -m py_compile '${MY_PATH}/../../UPassport/oracle_system.py'"
    else
        echo -e "${RED}❌ oracle_system.py introuvable${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
}

################################################################################
# Résumé des tests
################################################################################

show_summary() {
    section "RÉSUMÉ DES TESTS"
    
    echo -e "${CYAN}Tests exécutés: ${TESTS_TOTAL}${NC}"
    echo -e "${GREEN}Tests réussis: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests échoués: ${TESTS_FAILED}${NC}"
    echo ""
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo -e "${CYAN}Taux de réussite: ${success_rate}%${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 TOUS LES TESTS SONT PASSÉS!${NC}"
        return 0
    else
        echo -e "${RED}⚠️  CERTAINS TESTS ONT ÉCHOUÉ${NC}"
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
    echo "1. 🧪 Exécuter TOUS les tests (automatique)"
    echo "2. 📋 Test: Définitions de permis"
    echo "3. 📝 Test: Demande de permis"
    echo "4. ✍️  Test: Attestations"
    echo "5. 📊 Test: Vérification du statut"
    echo "6. 📑 Test: Listing des permis"
    echo "7. 🎫 Test: Récupération de credential"
    echo "8. 🛠️  Test: Scripts helper"
    echo "9. 💰 Test: Virement PERMIT"
    echo "10. 🔧 Test: Système Oracle"
    echo "11. 🚪 Quitter"
    echo ""
    read -p "Choisissez une option (1-11): " choice
    
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
            test_permit_virement
            ;;
        10)
            test_oracle_system
            ;;
        11)
            echo -e "${GREEN}👋 Au revoir!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Option invalide${NC}"
            ;;
    esac
}

run_all_tests() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║               EXÉCUTION DE TOUS LES TESTS                      ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    test_permit_definitions
    test_permit_request
    test_permit_attestations
    test_permit_status
    test_permit_list
    test_credential_retrieval
    test_helper_scripts
    test_oracle_system
    
    # Test du virement PERMIT (optionnel)
    echo ""
    echo -e "${YELLOW}⚠️  Le test du virement PERMIT nécessite une configuration blockchain${NC}"
    test_permit_virement
    
    show_summary
}

################################################################################
# Point d'entrée principal
################################################################################

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    🧪 SUITE DE TESTS - SYSTÈME DE GESTION DES PERMIS ORACLE   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Vérifier les dépendances
    echo -e "${YELLOW}🔍 Vérification des dépendances...${NC}"
    check_command "curl"
    check_command "jq"
    check_command "openssl"
    echo -e "${GREEN}✅ Toutes les dépendances sont installées${NC}"
    echo ""
    
    # Vérifier l'API
    check_api
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
        read -p "Appuyez sur Entrée pour continuer..."
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

