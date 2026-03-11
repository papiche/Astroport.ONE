#!/bin/bash
################################################################################
# test.sh — Point d'entrée des tests Astroport.ONE
#
# Usage:
#   ./test.sh              → Menu interactif
#   ./test.sh quick        → Tests rapides (prérequis station)
#   ./test.sh g1           → Tests couche G1/Duniter v2
#   ./test.sh primal       → Tests contrôle primal wallets
#   ./test.sh systems      → Tests systèmes UPlanet (DID, Oracle, ORE...)
#   ./test.sh all          → Tout lancer
################################################################################
MY_PATH="$(cd "$(dirname "$0")" && pwd)"
. "${MY_PATH}/tools/my.sh"

# ── Couleurs ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

PASS=0; FAIL=0; RC=0

ok()   { ((PASS++)); echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); RC=1; echo -e "  ${RED}✗${RESET} $1"; }

# ══════════════════════════════════════════════════════════════════════════════
# Tests rapides : vérification des prérequis station
# ══════════════════════════════════════════════════════════════════════════════
run_quick() {
    echo -e "\n${BOLD}═══ Tests rapides : prérequis station ═══${RESET}\n"

    echo -e "${CYAN}── Outils ──${RESET}"
    command -v tiddlywiki &>/dev/null && ok "TiddlyWiki" || fail "TiddlyWiki"
    command -v gcli &>/dev/null && ok "gcli ($(gcli --version 2>/dev/null | head -1))" || fail "gcli"
    [[ -x "${MY_PATH}/tools/keygen" ]] && ok "keygen" || fail "keygen"
    command -v jq &>/dev/null && ok "jq" || fail "jq"
    command -v amzqr &>/dev/null && ok "amzqr" || fail "amzqr"
    python3 -c "import base58" 2>/dev/null && ok "python3 base58" || fail "python3 base58"

    echo -e "\n${CYAN}── Services ──${RESET}"
    ipfs swarm peers &>/dev/null && ok "IPFS daemon" || fail "IPFS daemon"
    [[ -f /usr/local/bin/node_exporter ]] && ok "Prometheus node_exporter" || echo -e "  ${YELLOW}⊘${RESET} node_exporter (optionnel)"

    echo -e "\n${CYAN}── Crypto ──${RESET}"
    KOUT=$("${MY_PATH}/tools/keygen" "coucou" "coucou" 2>/dev/null)
    [[ "$KOUT" == "5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo" ]] \
        && ok "keygen deterministic" || fail "keygen deterministic ($KOUT)"

    echo -e "\n${CYAN}── Blockchain ──${RESET}"
    BAL=$("${MY_PATH}/tools/G1check.sh" "${CAPTAING1PUB}" 2>/dev/null)
    [[ -n "$BAL" && "$BAL" =~ ^[0-9] ]] \
        && ok "G1check GraphQL : ${BAL} G1" || fail "G1check GraphQL"

    echo -e "\n${CYAN}── Environnement ──${RESET}"
    [[ -n "${CAPTAINEMAIL:-}" ]] && ok "CAPTAINEMAIL : $CAPTAINEMAIL" || fail "CAPTAINEMAIL"
    [[ -n "${CAPTAING1PUB:-}" ]] && ok "CAPTAING1PUB" || fail "CAPTAING1PUB"
    [[ -n "${UPLANETNAME_G1:-}" ]] && ok "UPLANETNAME_G1" || fail "UPLANETNAME_G1"
    [[ -n "${IPFSNODEID:-}" ]] && ok "IPFSNODEID : $IPFSNODEID" || fail "IPFSNODEID"
}

# ══════════════════════════════════════════════════════════════════════════════
# Lancer un test du dossier tests/
# ══════════════════════════════════════════════════════════════════════════════
run_test_script() {
    local script="$1" name="$2"
    shift 2
    echo -e "\n${BOLD}═══ $name ═══${RESET}"
    if [[ -x "$script" ]]; then
        bash "$script" "$@"
        return $?
    else
        echo -e "  ${RED}✗${RESET} $script introuvable"
        return 1
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Menu interactif
# ══════════════════════════════════════════════════════════════════════════════
show_menu() {
    echo -e "\n${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Astroport.ONE — Test Suite         ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}\n"
    echo "  1) quick     Tests rapides (prerequis station)"
    echo "  2) g1        Couche G1/Duniter v2 (keygen, squid, gcli, PAYforSURE)"
    echo "  3) primal    Controle primal wallets (v1->SS58, squid, intrusion)"
    echo "  4) systems   Systemes UPlanet (DID, Oracle, WoTx2, ORE, Badge)"
    echo "  5) all       Tout lancer"
    echo "  0) quit      Quitter"
    echo ""
    echo -n "  Choix [1-5, 0] : "
}

# ══════════════════════════════════════════════════════════════════════════════
# Rapport final
# ══════════════════════════════════════════════════════════════════════════════
report() {
    # Pour run_quick, afficher le rapport intégré (PASS/FAIL sont remplis)
    # Pour les sous-scripts, le rapport est déjà affiché par le script lui-même
    if [[ $PASS -gt 0 || $FAIL -gt 0 ]]; then
        echo -e "\n${BOLD}═══════════════════════════════════════════${RESET}"
        if [[ $FAIL -eq 0 ]]; then
            echo -e "${GREEN}  PERFECT — $PASS tests OK${RESET}"
        else
            echo -e "${RED}  $FAIL ECHEC(S)${RESET} / ${GREEN}$PASS OK${RESET}"
        fi
        echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
CHOICE="${1:-}"

if [[ -z "$CHOICE" ]]; then
    # Mode interactif
    show_menu
    read -r CHOICE
fi

case "$CHOICE" in
    1|quick)
        run_quick
        ;;
    2|g1)
        run_test_script "${MY_PATH}/tests/test_g1_tools.sh" "G1 Tools (Duniter v2)" "${@:2}" || RC=1
        ;;
    3|primal)
        run_test_script "${MY_PATH}/tests/test_primal_control.sh" "Primal Wallet Control" "${@:2}" || RC=1
        ;;
    4|systems)
        run_test_script "${MY_PATH}/tests/test_all_systems.sh" "UPlanet Systems" "${@:2}" || RC=1
        ;;
    5|all)
        run_quick
        run_test_script "${MY_PATH}/tests/test_g1_tools.sh" "G1 Tools (Duniter v2)" --quick || RC=1
        run_test_script "${MY_PATH}/tests/test_primal_control.sh" "Primal Wallet Control" || RC=1
        run_test_script "${MY_PATH}/tests/test_all_systems.sh" "UPlanet Systems" || RC=1
        ;;
    0|quit|q)
        echo "Bye."
        exit 0
        ;;
    *)
        echo "Choix invalide : $CHOICE"
        echo "Usage: $0 [quick|g1|primal|systems|all]"
        exit 1
        ;;
esac

report
exit $RC
