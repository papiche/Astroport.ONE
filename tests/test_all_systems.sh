#!/bin/bash
###################################################################
# test_all_systems.sh
# Suite de tests complète UPlanet — tous les sous-systèmes
#
# Tiers :
#   STATIQUE  — analyse de code, sans infra live (défaut)
#     multipass, did, oracle, wotx2, ore, badge, g1tools,
#     primal, ss58, astrosystemctl, destroy
#   INTÉGRATION (--live) — relay NOSTR + IPFS requis
#     intercom, create
#   IA (--ai) — Ollama/ComfyUI requis
#     ollama, comfyui
#   SCÉNARIO (--demo) — crée des données réelles
#     knowledge, minelife, wotx2demo, umap, captain
#
# Usage: ./test_all_systems.sh [options] [--system NOM]
#
# Options:
#   --verbose        : affichage détaillé
#   --live           : inclut les tests d'intégration réseau
#   --ai             : inclut les tests Ollama/ComfyUI
#   --demo           : inclut les scénarios (crée des données réelles)
#   --system NOM     : un seul test (voir liste ci-dessous)
#
# Noms --system disponibles :
#   multipass, did, oracle, wotx2, ore, badge, g1tools, primal,
#   ss58, astrosystemctl, destroy, intercom, create,
#   ollama, comfyui, knowledge, minelife, wotx2demo, umap, captain
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE is missing !!" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Test configuration
VERBOSE=false
LIVE=false
AI=false
DEMO=false
TEST_SYSTEM=""
TEST_RESULTS_DIR="$HOME/.zen/tmp/tests"
mkdir -p "$TEST_RESULTS_DIR"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose) VERBOSE=true; shift ;;
        --live)    LIVE=true;    shift ;;
        --ai)      AI=true;      shift ;;
        --demo)    DEMO=true;    shift ;;
        --system)
            TEST_SYSTEM="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

# Verify prerequisites
verify_prerequisites() {
    log_info "Verifying prerequisites..."
    
    local missing=0
    
    # Check for CAPTAINEMAIL
    if [[ -z "${CAPTAINEMAIL:-}" ]]; then
        log_error "CAPTAINEMAIL not set"
        missing=1
    else
        log_success "CAPTAINEMAIL: $CAPTAINEMAIL"
    fi
    
    # Check for captain's secret file
    if [[ ! -f "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr" ]]; then
        log_error "Captain's secret file not found: ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
        missing=1
    else
        log_success "Captain's secret file found"
    fi
    
    # Check for UPLANETNAME_G1
    if [[ -z "${UPLANETNAME_G1:-}" ]]; then
        log_error "UPLANETNAME_G1 not set"
        missing=1
    else
        log_success "UPLANETNAME_G1: $UPLANETNAME_G1"
    fi
    
    # Check for IPFSNODEID
    if [[ -z "${IPFSNODEID:-}" ]]; then
        log_error "IPFSNODEID not set"
        missing=1
    else
        log_success "IPFSNODEID: $IPFSNODEID"
    fi
    
    # Check for required scripts
    local required_scripts=(
        "$ASTROPORT_PATH/tools/did_manager_nostr.sh"
        "$ASTROPORT_PATH/RUNTIME/ORACLE.refresh.sh"
        "$ASTROPORT_PATH/tools/ore_system.py"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_warning "Script not found: $script"
        else
            log_success "Script found: $(basename "$script")"
        fi
    done
    
    if [[ $missing -eq 1 ]]; then
        log_error "Prerequisites check failed"
        return 1
    fi
    
    log_success "All prerequisites verified"
    return 0
}

# Run test script (optional 3rd arg = extra flags passed to the script)
run_test_script() {
    local test_script="$1"
    local test_name="$2"
    local extra_args="${3:-}"

    if [[ ! -f "$test_script" ]]; then
        log_error "Test script not found: $test_script"
        return 1
    fi

    log_info "Running $test_name tests${extra_args:+ ($extra_args)}..."

    local result_file="$TEST_RESULTS_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).log"

    if [[ "$VERBOSE" == "true" ]]; then
        # shellcheck disable=SC2086
        bash "$test_script" $extra_args 2>&1 | tee "$result_file"
    else
        # shellcheck disable=SC2086
        bash "$test_script" $extra_args > "$result_file" 2>&1
    fi

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "$test_name passed"
        return 0
    else
        log_error "$test_name FAILED (exit $exit_code)"
        [[ "$VERBOSE" != "true" ]] && log_info "Log: $result_file"
        return 1
    fi
}

# Main execution
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  UPlanet Systems Test Suite"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Verify prerequisites
    if ! verify_prerequisites; then
        log_error "Prerequisites check failed. Please fix the issues above."
        exit 1
    fi
    
    echo ""
    log_info "Starting test suite..."
    echo ""
    
    # Run tests based on selection
    if [[ -z "$TEST_SYSTEM" ]]; then

        echo ""
        echo "── STATIQUE — analyse de code (sans infra) ──────────────"
        run_test_script "$MY_PATH/test_multipass_zencard.sh"  "MultipassZENCard"
        run_test_script "$MY_PATH/test_did_system.sh"         "DID"
        run_test_script "$MY_PATH/test_oracle_system.sh"      "Oracle"
        run_test_script "$MY_PATH/test_wotx2_system.sh"       "WoTx2"
        run_test_script "$MY_PATH/test_ore_system.sh"         "ORE"
        run_test_script "$MY_PATH/test_badge_system.sh"       "Badge"
        run_test_script "$MY_PATH/test_g1_tools.sh"           "G1Tools"
        run_test_script "$MY_PATH/test_primal_control.sh"     "PrimalControl"
        run_test_script "$MY_PATH/test_ss58_integration.sh"   "SS58Integration"
        run_test_script "$MY_PATH/test_astrosystemctl.sh"     "Astrosystemctl"
        run_test_script "$MY_PATH/test_destroy_restore.sh"    "DestroyRestore"  "--offline"

        if [[ "$LIVE" == "true" ]]; then
            echo ""
            echo "── INTÉGRATION — relay NOSTR + IPFS ─────────────────────"
            run_test_script "$MY_PATH/test_intercom.sh"       "Intercom"
            run_test_script "$MY_PATH/test_multipass_create.sh" "MultipassCreate"
        else
            echo ""
            log_warning "Tests d'intégration réseau ignorés (ajouter --live pour les activer)"
            log_warning "  intercom --quick : ./test_intercom.sh"
            log_warning "  create --quick   : ./test_multipass_create.sh"
        fi

        if [[ "$AI" == "true" ]]; then
            echo ""
            echo "── IA — Ollama / ComfyUI ─────────────────────────────────"
            run_test_script "$MY_PATH/test_ollama.sh"         "Ollama"
            run_test_script "$MY_PATH/test_comfyui.sh"        "ComfyUI"
        else
            log_warning "Tests IA ignorés (ajouter --ai pour les activer)"
        fi

        if [[ "$DEMO" == "true" ]]; then
            echo ""
            echo "── SCÉNARIOS — crée des données réelles ─────────────────"
            log_warning "Ces tests créent des données réelles sur votre UPlanet"
            run_test_script "$MY_PATH/test_knowledge_demo.sh" "KnowledgeDemo"
            run_test_script "$MY_PATH/test_minelife_captain.sh" "MineLife"
            run_test_script "$MY_PATH/test_wotx2_demo.sh"     "WoTx2Demo"
            run_test_script "$MY_PATH/test_umap_cities.sh"    "UmapCities"
            run_test_script "$MY_PATH/test_captain_validation.sh" "CaptainValidation"
        else
            echo ""
            log_warning "Scénarios ignorés (ajouter --demo pour les activer)"
            log_warning "  Scénarios disponibles : knowledge, minelife, wotx2demo, umap, captain"
        fi

    else
        # Run specific test
        case "$TEST_SYSTEM" in
            multipass)
                run_test_script "$MY_PATH/test_multipass_zencard.sh" "MultipassZENCard" ;;
            did)
                run_test_script "$MY_PATH/test_did_system.sh" "DID" ;;
            oracle)
                run_test_script "$MY_PATH/test_oracle_system.sh" "Oracle" ;;
            wotx2)
                run_test_script "$MY_PATH/test_wotx2_system.sh" "WoTx2" ;;
            ore)
                run_test_script "$MY_PATH/test_ore_system.sh" "ORE" ;;
            badge)
                run_test_script "$MY_PATH/test_badge_system.sh" "Badge" ;;
            g1tools)
                run_test_script "$MY_PATH/test_g1_tools.sh" "G1Tools" ;;
            primal)
                run_test_script "$MY_PATH/test_primal_control.sh" "PrimalControl" ;;
            ss58)
                run_test_script "$MY_PATH/test_ss58_integration.sh" "SS58Integration" ;;
            astrosystemctl)
                run_test_script "$MY_PATH/test_astrosystemctl.sh" "Astrosystemctl" ;;
            destroy)
                run_test_script "$MY_PATH/test_destroy_restore.sh" "DestroyRestore" ;;
            intercom)
                run_test_script "$MY_PATH/test_intercom.sh" "Intercom" ;;
            create)
                run_test_script "$MY_PATH/test_multipass_create.sh" "MultipassCreate" ;;
            ollama)
                run_test_script "$MY_PATH/test_ollama.sh" "Ollama" ;;
            comfyui)
                run_test_script "$MY_PATH/test_comfyui.sh" "ComfyUI" ;;
            knowledge)
                run_test_script "$MY_PATH/test_knowledge_demo.sh" "KnowledgeDemo" ;;
            minelife)
                run_test_script "$MY_PATH/test_minelife_captain.sh" "MineLife" ;;
            wotx2demo)
                run_test_script "$MY_PATH/test_wotx2_demo.sh" "WoTx2Demo" ;;
            umap)
                run_test_script "$MY_PATH/test_umap_cities.sh" "UmapCities" ;;
            captain)
                run_test_script "$MY_PATH/test_captain_validation.sh" "CaptainValidation" ;;
            *)
                log_error "Système inconnu : $TEST_SYSTEM"
                echo "Disponibles : multipass, did, oracle, wotx2, ore, badge, g1tools,"
                echo "             primal, ss58, astrosystemctl, destroy, intercom, create,"
                echo "             ollama, comfyui, knowledge, minelife, wotx2demo, umap, captain"
                exit 1
                ;;
        esac
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Test Results Summary"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"

