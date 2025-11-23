#!/bin/bash
###################################################################
# test_all_systems.sh
# Comprehensive test suite for UPlanet systems
#
# Tests:
# - DID System (DID Implementation)
# - Oracle System (Official Permits)
# - WoTx2 System (Auto-Proclaimed Masteries)
# - ORE System (Environmental Contracts)
# - Badge System (NIP-58 Badges)
#
# Usage: ./test_all_systems.sh [--verbose] [--system SYSTEM_NAME]
#
# Options:
#   --verbose: Show detailed output
#   --system: Test only specific system (did|oracle|wotx2|ore|badge)
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE is missing !!" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Test configuration
VERBOSE=false
TEST_SYSTEM=""
TEST_RESULTS_DIR="$HOME/.zen/tmp/tests"
mkdir -p "$TEST_RESULTS_DIR"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
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

# Run test script
run_test_script() {
    local test_script="$1"
    local test_name="$2"
    
    if [[ ! -f "$test_script" ]]; then
        log_error "Test script not found: $test_script"
        return 1
    fi
    
    log_info "Running $test_name tests..."
    
    local result_file="$TEST_RESULTS_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).log"
    
    if [[ "$VERBOSE" == "true" ]]; then
        bash "$test_script" 2>&1 | tee "$result_file"
    else
        bash "$test_script" > "$result_file" 2>&1
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$test_name tests passed"
        return 0
    else
        log_error "$test_name tests failed (exit code: $exit_code)"
        if [[ "$VERBOSE" != "true" ]]; then
            log_info "See log: $result_file"
        fi
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
        # Run all tests
        run_test_script "$MY_PATH/test_did_system.sh" "DID"
        run_test_script "$MY_PATH/test_oracle_system.sh" "Oracle"
        run_test_script "$MY_PATH/test_wotx2_system.sh" "WoTx2"
        run_test_script "$MY_PATH/test_ore_system.sh" "ORE"
        run_test_script "$MY_PATH/test_badge_system.sh" "Badge"
        
        # Run captain validation test (creates real data)
        echo ""
        log_info "═══════════════════════════════════════════════════════════"
        log_info "  Captain Validation Test (Creates Real Data)"
        log_info "═══════════════════════════════════════════════════════════"
        echo ""
        log_warning "The captain validation test creates REAL data on your UPlanet"
        log_warning "Run it separately with: ./test_captain_validation.sh"
        echo ""
    else
        # Run specific test
        case "$TEST_SYSTEM" in
            did)
                run_test_script "$MY_PATH/test_did_system.sh" "DID"
                ;;
            oracle)
                run_test_script "$MY_PATH/test_oracle_system.sh" "Oracle"
                ;;
            wotx2)
                run_test_script "$MY_PATH/test_wotx2_system.sh" "WoTx2"
                ;;
            ore)
                run_test_script "$MY_PATH/test_ore_system.sh" "ORE"
                ;;
            badge)
                run_test_script "$MY_PATH/test_badge_system.sh" "Badge"
                ;;
            captain)
                run_test_script "$MY_PATH/test_captain_validation.sh" "Captain Validation"
                ;;
            *)
                log_error "Unknown system: $TEST_SYSTEM"
                echo "Available systems: did, oracle, wotx2, ore, badge, captain"
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

