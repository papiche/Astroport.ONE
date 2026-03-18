#!/bin/bash
########################################################################
# run_tests.sh — Lancer tous les tests code_assistant + cpscript
# Usage : bash Astroport.ONE/tests/run_tests.sh [--fast]
#
# --fast : ignore les tests nécessitant Ollama
########################################################################
MY_PATH=$(dirname "$(realpath "$0")")
TOTAL_PASS=0; TOTAL_FAIL=0

# Assurer que ~/.astro/bin (Python avec base58/duniterpy) est en tête de PATH
export PATH="$HOME/.astro/bin:$PATH"

run_suite() {
    local script="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$script"
    local exit_code=$?
    return $exit_code
}

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🧪 Tests code_assistant Suite                          ║"
echo "╚══════════════════════════════════════════════════════════╝"

FAILED_SUITES=()

for test_script in "$MY_PATH"/test_*.sh; do
    [ -f "$test_script" ] || continue
    if run_suite "$test_script"; then
        echo "  → Suite OK: $(basename "$test_script")"
    else
        echo "  → Suite ÉCHOUÉE: $(basename "$test_script")"
        FAILED_SUITES+=("$(basename "$test_script")")
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${#FAILED_SUITES[@]} -eq 0 ]; then
    echo "✅ Tous les tests sont passés"
    exit 0
else
    echo "❌ Suites échouées : ${FAILED_SUITES[*]}"
    exit 1
fi
