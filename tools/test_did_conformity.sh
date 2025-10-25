#!/bin/bash

# test_did_conformity.sh - Script de test de conformité DID W3C v1.1
# Vérifie la conformité des documents DID avec les standards W3C v1.1
# et la compatibilité France Connect

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
Usage: $SCRIPT_NAME [OPTIONS] EMAIL

Test de conformité DID W3C v1.1 pour un utilisateur UPlanet

OPTIONS:
    -h, --help              Afficher cette aide
    -v, --verbose           Mode verbeux
    -f, --format FORMAT     Format de sortie (json|text) [default: text]
    -c, --check-all         Vérifier tous les utilisateurs
    --france-connect        Vérifier spécifiquement la conformité France Connect
    --nostr-only            Vérifier uniquement la source Nostr
    --ipfs-only             Vérifier uniquement la source IPFS
    --local-only             Vérifier uniquement le cache local

EXAMPLES:
    $SCRIPT_NAME user@example.com
    $SCRIPT_NAME --france-connect user@example.com
    $SCRIPT_NAME --check-all --format json
    $SCRIPT_NAME --nostr-only user@example.com

EOF
}

# Variables par défaut
VERBOSE=false
FORMAT="text"
CHECK_ALL=false
FRANCE_CONNECT=false
NOSTR_ONLY=false
IPFS_ONLY=false
LOCAL_ONLY=false
EMAIL=""

# Parsing des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -c|--check-all)
            CHECK_ALL=true
            shift
            ;;
        --france-connect)
            FRANCE_CONNECT=true
            shift
            ;;
        --nostr-only)
            NOSTR_ONLY=true
            shift
            ;;
        --ipfs-only)
            IPFS_ONLY=true
            shift
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        -*)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$EMAIL" ]]; then
                EMAIL="$1"
            else
                log_error "Trop d'arguments: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validation des paramètres
if [[ "$CHECK_ALL" == "false" && -z "$EMAIL" ]]; then
    log_error "Email requis ou utilisez --check-all"
    show_help
    exit 1
fi

if [[ "$FORMAT" != "json" && "$FORMAT" != "text" ]]; then
    log_error "Format invalide: $FORMAT (utilisez json ou text)"
    exit 1
fi

# Fonction de vérification de la structure JSON
check_json_structure() {
    local did_file="$1"
    local errors=()
    
    if [[ ! -f "$did_file" ]]; then
        echo "FILE_NOT_FOUND"
        return 1
    fi
    
    # Vérification de la validité JSON
    if ! jq empty "$did_file" 2>/dev/null; then
        echo "INVALID_JSON"
        return 1
    fi
    
    # Vérification des champs obligatoires W3C DID Core v1.1
    local required_fields=("@context" "id" "verificationMethod" "authentication" "assertionMethod" "keyAgreement")
    
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$did_file" >/dev/null 2>&1; then
            errors+=("MISSING_FIELD:$field")
        fi
    done
    
    # Vérification du contexte W3C
    if ! jq -e '.["@context"] | contains(["https://w3id.org/did/v1"])' "$did_file" >/dev/null 2>&1; then
        errors+=("INVALID_CONTEXT")
    fi
    
    # Vérification de l'ID DID
    if ! jq -e '.id | test("^did:nostr:[a-f0-9]{64}$")' "$did_file" >/dev/null 2>&1; then
        errors+=("INVALID_DID_ID")
    fi
    
    # Vérification des méthodes de vérification
    local vm_count=$(jq '.verificationMethod | length' "$did_file")
    if [[ "$vm_count" -lt 1 ]]; then
        errors+=("NO_VERIFICATION_METHODS")
    fi
    
    # Vérification de la cohérence des IDs
    local did_id=$(jq -r '.id' "$did_file")
    for i in $(seq 0 $((vm_count-1))); do
        local vm_id=$(jq -r ".verificationMethod[$i].id" "$did_file")
        if [[ ! "$vm_id" =~ ^$did_id# ]]; then
            errors+=("INVALID_VERIFICATION_METHOD_ID:$vm_id")
        fi
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi
    
    echo "VALID"
    return 0
}

# Fonction de vérification France Connect
check_france_connect_compliance() {
    local did_file="$1"
    local errors=()
    
    # Vérification de la section France Connect
    if ! jq -e '.metadata.franceConnect' "$did_file" >/dev/null 2>&1; then
        errors+=("MISSING_FRANCE_CONNECT_METADATA")
        return 1
    fi
    
    # Vérification des champs obligatoires France Connect
    local fc_fields=("compliance" "identityProvider" "verificationLevel" "kycStatus" "wotVerification")
    
    for field in "${fc_fields[@]}"; do
        if ! jq -e ".metadata.franceConnect.$field" "$did_file" >/dev/null 2>&1; then
            errors+=("MISSING_FC_FIELD:$field")
        fi
    done
    
    # Vérification du niveau de conformité
    local compliance=$(jq -r '.metadata.franceConnect.compliance' "$did_file")
    if [[ "$compliance" != "enabled" && "$compliance" != "disabled" ]]; then
        errors+=("INVALID_FC_COMPLIANCE:$compliance")
    fi
    
    # Vérification du statut KYC
    local kyc_status=$(jq -r '.metadata.franceConnect.kycStatus' "$did_file")
    if [[ "$kyc_status" != "verified" && "$kyc_status" != "pending" ]]; then
        errors+=("INVALID_FC_KYC_STATUS:$kyc_status")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi
    
    echo "FRANCE_CONNECT_COMPLIANT"
    return 0
}

# Fonction de vérification de la résolution
check_did_resolution() {
    local email="$1"
    local did_file="$2"
    local errors=()
    
    # Vérification du cache local
    if [[ "$LOCAL_ONLY" == "false" && "$NOSTR_ONLY" == "false" && "$IPFS_ONLY" == "false" ]]; then
        if [[ -f "$did_file" ]]; then
            log_success "Cache local trouvé: $did_file"
        else
            errors+=("LOCAL_CACHE_NOT_FOUND")
        fi
    fi
    
    # Vérification de la source Nostr
    if [[ "$NOSTR_ONLY" == "false" && "$IPFS_ONLY" == "false" && "$LOCAL_ONLY" == "false" ]]; then
        if [[ -f "${MY_PATH}/nostr_did_client.py" ]]; then
            if python3 "${MY_PATH}/nostr_did_client.py" fetch "$email" >/dev/null 2>&1; then
                log_success "Source Nostr accessible"
            else
                errors+=("NOSTR_SOURCE_UNAVAILABLE")
            fi
        else
            errors+=("NOSTR_CLIENT_NOT_FOUND")
        fi
    fi
    
    # Vérification de la source IPFS
    if [[ "$IPFS_ONLY" == "false" && "$NOSTR_ONLY" == "false" && "$LOCAL_ONLY" == "false" ]]; then
        # Vérification de la disponibilité IPFS
        if command -v ipfs >/dev/null 2>&1; then
            log_success "Client IPFS disponible"
        else
            errors+=("IPFS_CLIENT_NOT_FOUND")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi
    
    echo "RESOLUTION_OK"
    return 0
}

# Fonction de vérification des métadonnées UPlanet
check_uplanet_metadata() {
    local did_file="$1"
    local errors=()
    
    # Vérification des métadonnées UPlanet
    if ! jq -e '.metadata' "$did_file" >/dev/null 2>&1; then
        errors+=("MISSING_UPLANET_METADATA")
        return 1
    fi
    
    # Vérification des champs obligatoires UPlanet
    local up_fields=("email" "created" "updated" "version" "contractStatus")
    
    for field in "${up_fields[@]}"; do
        if ! jq -e ".metadata.$field" "$did_file" >/dev/null 2>&1; then
            errors+=("MISSING_UP_FIELD:$field")
        fi
    done
    
    # Vérification des services UPlanet
    local services=$(jq '.service | length' "$did_file")
    if [[ "$services" -lt 3 ]]; then
        errors+=("INSUFFICIENT_UPLANET_SERVICES")
    fi
    
    # Vérification des clés jumelles
    local vm_count=$(jq '.verificationMethod | length' "$did_file")
    if [[ "$vm_count" -lt 3 ]]; then
        errors+=("INSUFFICIENT_TWIN_KEYS")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi
    
    echo "UPLANET_METADATA_OK"
    return 0
}

# Fonction principale de test
test_did_conformity() {
    local email="$1"
    local did_file="${HOME}/.zen/game/nostr/${email}/did.json.cache"
    local results=()
    local errors=()
    
    log_info "Test de conformité DID pour: $email"
    
    # Vérification de l'existence du fichier
    if [[ ! -f "$did_file" ]]; then
        log_error "DID non trouvé: $did_file"
        return 1
    fi
    
    # Test de la structure JSON et conformité W3C
    log_info "Vérification de la structure JSON et conformité W3C v1.1..."
    local json_result=$(check_json_structure "$did_file")
    if [[ "$json_result" == "VALID" ]]; then
        log_success "Structure JSON valide et conforme W3C v1.1"
        results+=("json_structure:VALID")
    else
        log_error "Erreurs de structure JSON: $json_result"
        results+=("json_structure:ERROR:$json_result")
        errors+=("JSON_STRUCTURE_ERROR")
    fi
    
    # Test de la résolution DID
    log_info "Vérification de la résolution DID..."
    local resolution_result=$(check_did_resolution "$email" "$did_file")
    if [[ "$resolution_result" == "RESOLUTION_OK" ]]; then
        log_success "Résolution DID fonctionnelle"
        results+=("did_resolution:OK")
    else
        log_warning "Problèmes de résolution: $resolution_result"
        results+=("did_resolution:WARNING:$resolution_result")
    fi
    
    # Test des métadonnées UPlanet
    log_info "Vérification des métadonnées UPlanet..."
    local metadata_result=$(check_uplanet_metadata "$did_file")
    if [[ "$metadata_result" == "UPLANET_METADATA_OK" ]]; then
        log_success "Métadonnées UPlanet complètes"
        results+=("uplanet_metadata:OK")
    else
        log_warning "Métadonnées UPlanet incomplètes: $metadata_result"
        results+=("uplanet_metadata:WARNING:$metadata_result")
    fi
    
    # Test France Connect si demandé
    if [[ "$FRANCE_CONNECT" == "true" ]]; then
        log_info "Vérification de la conformité France Connect..."
        local fc_result=$(check_france_connect_compliance "$did_file")
        if [[ "$fc_result" == "FRANCE_CONNECT_COMPLIANT" ]]; then
            log_success "Conformité France Connect validée"
            results+=("france_connect:COMPLIANT")
        else
            log_warning "Problèmes de conformité France Connect: $fc_result"
            results+=("france_connect:WARNING:$fc_result")
        fi
    fi
    
    # Affichage des résultats
    if [[ "$FORMAT" == "json" ]]; then
        echo "{"
        echo "  \"email\": \"$email\","
        echo "  \"did_file\": \"$did_file\","
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"results\": ["
        for i in "${!results[@]}"; do
            echo -n "    \"${results[$i]}\""
            if [[ $i -lt $((${#results[@]}-1)) ]]; then
                echo ","
            else
                echo ""
            fi
        done
        echo "  ],"
        echo "  \"errors\": ["
        for i in "${!errors[@]}"; do
            echo -n "    \"${errors[$i]}\""
            if [[ $i -lt $((${#errors[@]}-1)) ]]; then
                echo ","
            else
                echo ""
            fi
        done
        echo "  ]"
        echo "}"
    else
        echo ""
        log_info "Résumé des tests:"
        for result in "${results[@]}"; do
            echo "  - $result"
        done
        
        if [[ ${#errors[@]} -gt 0 ]]; then
            echo ""
            log_warning "Erreurs détectées:"
            for error in "${errors[@]}"; do
                echo "  - $error"
            done
        fi
    fi
    
    # Code de sortie
    if [[ ${#errors[@]} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Fonction pour vérifier tous les utilisateurs
check_all_users() {
    local users_dir="${HOME}/.zen/game/nostr"
    local total=0
    local passed=0
    local failed=0
    
    log_info "Vérification de tous les utilisateurs..."
    
    if [[ ! -d "$users_dir" ]]; then
        log_error "Répertoire utilisateurs non trouvé: $users_dir"
        return 1
    fi
    
    for user_dir in "$users_dir"/*; do
        if [[ -d "$user_dir" ]]; then
            local email=$(basename "$user_dir")
            local did_file="$user_dir/did.json.cache"
            
            if [[ -f "$did_file" ]]; then
                total=$((total + 1))
                log_info "Test de: $email"
                
                if test_did_conformity "$email"; then
                    passed=$((passed + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        fi
    done
    
    echo ""
    log_info "Résumé global:"
    echo "  Total: $total"
    echo "  Réussis: $passed"
    echo "  Échoués: $failed"
    
    if [[ $failed -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Fonction principale
main() {
    if [[ "$CHECK_ALL" == "true" ]]; then
        check_all_users
    else
        test_did_conformity "$EMAIL"
    fi
}

# Exécution
main "$@"
