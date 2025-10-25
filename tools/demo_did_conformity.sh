#!/bin/bash

# demo_did_conformity.sh - Démonstration du script de test de conformité DID
# Montre comment utiliser test_did_conformity.sh avec différents scénarios

set -euo pipefail

# Configuration
MY_PATH="$(dirname "$0")"
SCRIPT_NAME="$(basename "$0")"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Démonstration du script de test de conformité DID W3C v1.1

OPTIONS:
    -h, --help              Afficher cette aide
    -u, --user EMAIL        Utilisateur spécifique à tester
    --all-users             Tester tous les utilisateurs
    --france-connect        Inclure les tests France Connect
    --json-output           Sortie en format JSON

EXAMPLES:
    $SCRIPT_NAME --user user@example.com
    $SCRIPT_NAME --all-users --france-connect
    $SCRIPT_NAME --json-output --user user@example.com

EOF
}

# Variables par défaut
USER_EMAIL=""
ALL_USERS=false
FRANCE_CONNECT=false
JSON_OUTPUT=false

# Parsing des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--user)
            USER_EMAIL="$2"
            shift 2
            ;;
        --all-users)
            ALL_USERS=true
            shift
            ;;
        --france-connect)
            FRANCE_CONNECT=true
            shift
            ;;
        --json-output)
            JSON_OUTPUT=true
            shift
            ;;
        -*)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
        *)
            log_error "Argument inattendu: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validation des paramètres
if [[ "$ALL_USERS" == "false" && -z "$USER_EMAIL" ]]; then
    log_error "Email utilisateur requis ou utilisez --all-users"
    show_help
    exit 1
fi

# Fonction de démonstration
demo_conformity_test() {
    log_info "=== Démonstration du Test de Conformité DID W3C v1.1 ==="
    echo ""
    
    # Test 1: Aide du script
    log_info "1. Affichage de l'aide du script de test:"
    echo ""
    "${MY_PATH}/test_did_conformity.sh" --help
    echo ""
    
    # Test 2: Test d'un utilisateur spécifique
    if [[ -n "$USER_EMAIL" ]]; then
        log_info "2. Test de conformité pour l'utilisateur: $USER_EMAIL"
        echo ""
        
        local test_cmd="${MY_PATH}/test_did_conformity.sh"
        if [[ "$FRANCE_CONNECT" == "true" ]]; then
            test_cmd="$test_cmd --france-connect"
        fi
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            test_cmd="$test_cmd --format json"
        fi
        test_cmd="$test_cmd $USER_EMAIL"
        
        echo "Commande exécutée: $test_cmd"
        echo ""
        
        if eval "$test_cmd"; then
            log_success "Test de conformité réussi pour $USER_EMAIL"
        else
            log_warning "Test de conformité échoué pour $USER_EMAIL (utilisateur probablement inexistant)"
        fi
        echo ""
    fi
    
    # Test 3: Test de tous les utilisateurs
    if [[ "$ALL_USERS" == "true" ]]; then
        log_info "3. Test de conformité pour tous les utilisateurs:"
        echo ""
        
        local test_cmd="${MY_PATH}/test_did_conformity.sh --check-all"
        if [[ "$FRANCE_CONNECT" == "true" ]]; then
            test_cmd="$test_cmd --france-connect"
        fi
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            test_cmd="$test_cmd --format json"
        fi
        
        echo "Commande exécutée: $test_cmd"
        echo ""
        
        if eval "$test_cmd"; then
            log_success "Tous les utilisateurs sont conformes"
        else
            log_warning "Certains utilisateurs ne sont pas conformes ou aucun utilisateur trouvé"
        fi
        echo ""
    fi
    
    # Test 4: Démonstration des options avancées
    log_info "4. Démonstration des options avancées:"
    echo ""
    
    log_info "   a) Test uniquement la source Nostr:"
    echo "      ${MY_PATH}/test_did_conformity.sh --nostr-only $USER_EMAIL"
    echo ""
    
    log_info "   b) Test uniquement la source IPFS:"
    echo "      ${MY_PATH}/test_did_conformity.sh --ipfs-only $USER_EMAIL"
    echo ""
    
    log_info "   c) Test uniquement le cache local:"
    echo "      ${MY_PATH}/test_did_conformity.sh --local-only $USER_EMAIL"
    echo ""
    
    log_info "   d) Test avec mode verbeux:"
    echo "      ${MY_PATH}/test_did_conformity.sh --verbose $USER_EMAIL"
    echo ""
    
    # Test 5: Intégration dans un pipeline
    log_info "5. Exemple d'intégration dans un pipeline:"
    echo ""
    
    cat << 'EOF'
#!/bin/bash
# Script de test automatisé pour l'écosystème UPlanet

echo "🔍 Test de conformité DID W3C v1.1..."

# Test de conformité DID
if ./test_did_conformity.sh --check-all --format json > did_test_results.json; then
    echo "✅ Tous les DIDs sont conformes"
else
    echo "❌ Certains DIDs ne sont pas conformes"
    cat did_test_results.json | jq '.errors'
    exit 1
fi

# Test spécifique France Connect
if ./test_did_conformity.sh --france-connect --check-all; then
    echo "✅ Conformité France Connect validée"
else
    echo "❌ Problèmes de conformité France Connect"
    exit 1
fi

echo "🎉 Tous les tests de conformité sont passés avec succès!"
EOF
    
    echo ""
    
    # Résumé
    log_info "=== Résumé de la Démonstration ==="
    echo ""
    log_success "Le script test_did_conformity.sh permet de:"
    echo "  - Vérifier la conformité W3C DID Core v1.1"
    echo "  - Tester la résolution DID (Nostr, IPFS, cache local)"
    echo "  - Valider les métadonnées UPlanet"
    echo "  - Vérifier la conformité France Connect"
    echo "  - Générer des rapports en format JSON"
    echo "  - Intégrer dans des pipelines de test automatisés"
    echo ""
    log_info "Pour plus d'informations, consultez DID_IMPLEMENTATION.md"
}

# Exécution
demo_conformity_test
