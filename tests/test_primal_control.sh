#!/bin/bash
################################################################################
# test_primal_control.sh — Tests pour primal_wallet_control.sh
#
# Usage:
#   ./tests/test_primal_control.sh              → tous les tests
#   ./tests/test_primal_control.sh --offline    → tests sans réseau
#   ./tests/test_primal_control.sh --verbose    → sortie détaillée
#
# Vérifie :
#   - Conversion v1→SS58 des pubkeys
#   - Requête squid (historique, primal source)
#   - Détection CAPTAIN
#   - Validation primal conforme
#   - Contrôle complet sur wallet CAPTAIN
################################################################################
set -u

MY_PATH="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${MY_PATH}/tools"

# Source environment
[[ -f "${TOOLS}/my.sh" ]] && . "${TOOLS}/my.sh"

# ── Options ──────────────────────────────────────────────────────────────────
OFFLINE=false
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --offline) OFFLINE=true ;;
        --verbose) VERBOSE=true ;;
    esac
done

# ── Couleurs ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Compteurs ────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0

ok()   { ((PASS++)); echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}✗${RESET} $1"; [[ "$VERBOSE" == true ]] && echo "    $2"; }
skip() { ((SKIP++)); echo -e "  ${YELLOW}⊘${RESET} $1 (skipped)"; }

################################################################################
echo -e "\n${BOLD}═══ TEST SUITE : Primal Wallet Control ═══${RESET}\n"
################################################################################

########################################
echo -e "${CYAN}── 1. Prérequis ──${RESET}"
########################################

# 1.1 Script exécutable
if [[ -x "${TOOLS}/primal_wallet_control.sh" ]]; then
    ok "primal_wallet_control.sh exécutable"
else
    fail "primal_wallet_control.sh non exécutable" "chmod +x ${TOOLS}/primal_wallet_control.sh"
fi

# 1.2 g1pub_to_ss58.py
if [[ -x "${TOOLS}/g1pub_to_ss58.py" ]]; then
    ok "g1pub_to_ss58.py disponible"
else
    fail "g1pub_to_ss58.py introuvable" "${TOOLS}/g1pub_to_ss58.py"
fi

# 1.3 Variables environnement
if [[ -n "${CAPTAINEMAIL:-}" ]]; then
    ok "CAPTAINEMAIL : $CAPTAINEMAIL"
else
    fail "CAPTAINEMAIL non défini" "source tools/my.sh"
fi

if [[ -n "${CAPTAING1PUB:-}" ]]; then
    ok "CAPTAING1PUB : $CAPTAING1PUB"
else
    fail "CAPTAING1PUB non défini" ""
fi

if [[ -n "${UPLANETNAME_G1:-}" ]]; then
    ok "UPLANETNAME_G1 : $UPLANETNAME_G1"
else
    fail "UPLANETNAME_G1 non défini" ""
fi

# 1.4 Dunikey captain
CAPTAIN_DUNIKEY="$HOME/.zen/game/players/${CAPTAINEMAIL:-}/secret.dunikey"
if [[ -f "$CAPTAIN_DUNIKEY" ]]; then
    ok "Captain dunikey : $CAPTAIN_DUNIKEY"
else
    fail "Captain dunikey introuvable" "$CAPTAIN_DUNIKEY"
fi

########################################
echo -e "\n${CYAN}── 2. Conversion v1→SS58 ──${RESET}"
########################################

# 2.1 Conversion CAPTAING1PUB
if [[ -n "${CAPTAING1PUB:-}" ]]; then
    CAPTAIN_SS58=$(python3 "${TOOLS}/g1pub_to_ss58.py" "$CAPTAING1PUB" 2>/dev/null)
    if [[ "$CAPTAIN_SS58" =~ ^g1 ]]; then
        ok "CAPTAING1PUB → SS58 : ${CAPTAIN_SS58:0:20}..."
    else
        fail "CAPTAING1PUB → SS58 échoué" "$CAPTAIN_SS58"
    fi
else
    skip "Conversion CAPTAING1PUB (variable manquante)"
fi

# 2.2 Conversion UPLANETNAME_G1
if [[ -n "${UPLANETNAME_G1:-}" ]]; then
    UPLANET_SS58=$(python3 "${TOOLS}/g1pub_to_ss58.py" "$UPLANETNAME_G1" 2>/dev/null)
    if [[ "$UPLANET_SS58" =~ ^g1 ]]; then
        ok "UPLANETNAME_G1 → SS58 : ${UPLANET_SS58:0:20}..."
    else
        fail "UPLANETNAME_G1 → SS58 échoué" "$UPLANET_SS58"
    fi
else
    skip "Conversion UPLANETNAME_G1 (variable manquante)"
fi

# 2.3 SS58 passthrough (déjà au bon format)
if [[ -n "${CAPTAIN_SS58:-}" ]]; then
    PASSTHROUGH=$(python3 "${TOOLS}/g1pub_to_ss58.py" "$CAPTAIN_SS58" 2>/dev/null)
    if [[ "$PASSTHROUGH" == "$CAPTAIN_SS58" ]]; then
        ok "SS58 passthrough : inchangé"
    else
        fail "SS58 passthrough : modifié" "$PASSTHROUGH"
    fi
fi

########################################
echo -e "\n${CYAN}── 3. Usage et validation arguments ──${RESET}"
########################################

# 3.1 Usage sans arguments
USAGE_OUT=$(bash "${TOOLS}/primal_wallet_control.sh" 2>&1)
USAGE_RC=$?
if [[ $USAGE_RC -ne 0 ]] && echo "$USAGE_OUT" | grep -q "Usage"; then
    ok "sans arguments : affiche usage (exit $USAGE_RC)"
else
    fail "sans arguments : pas de message usage" "$USAGE_OUT"
fi

# 3.2 Dunikey inexistant
BAD_OUT=$(bash "${TOOLS}/primal_wallet_control.sh" "/nonexistent/path" "g1ABC" "g1XYZ" "test@test.com" 2>&1)
BAD_RC=$?
if [[ $BAD_RC -ne 0 ]]; then
    ok "dunikey inexistant : rejeté (exit $BAD_RC)"
else
    fail "dunikey inexistant : devrait échouer" "$BAD_OUT"
fi

########################################
echo -e "\n${CYAN}── 4. Requêtes squid (réseau) ──${RESET}"
########################################

if [[ "$OFFLINE" == true ]]; then
    skip "primal source squid (offline)"
    skip "historique squid (offline)"
    skip "contrôle complet (offline)"
else
    # 4.1 Test endpoint squid disponible
    SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"
    SQUID_TEST=$(curl -sf --max-time 5 -X POST -H "Content-Type: application/json" \
        --data '{"query":"{ __typename }"}' "$SQUID_URL" 2>/dev/null)
    if [[ -n "$SQUID_TEST" ]]; then
        ok "squid accessible : $SQUID_URL"
    else
        # Essayer fallback
        SQUID_URL="https://squid.g1.coinduf.eu/v1/graphql"
        SQUID_TEST=$(curl -sf --max-time 5 -X POST -H "Content-Type: application/json" \
            --data '{"query":"{ __typename }"}' "$SQUID_URL" 2>/dev/null)
        if [[ -n "$SQUID_TEST" ]]; then
            ok "squid fallback : $SQUID_URL"
        else
            fail "aucun squid accessible" ""
        fi
    fi

    # 4.2 Contrôle complet sur wallet CAPTAIN
    if [[ -f "$CAPTAIN_DUNIKEY" && -n "${CAPTAING1PUB:-}" && -n "${UPLANETNAME_G1:-}" && -n "${CAPTAINEMAIL:-}" ]]; then
        echo -e "  ${CYAN}Contrôle primal wallet CAPTAIN...${RESET}"
        PRIMAL_OUT=$(bash "${TOOLS}/primal_wallet_control.sh" \
            "$CAPTAIN_DUNIKEY" \
            "$CAPTAING1PUB" \
            "$UPLANETNAME_G1" \
            "$CAPTAINEMAIL" 2>&1)
        PRIMAL_RC=$?

        if [[ $PRIMAL_RC -eq 0 ]]; then
            ok "primal_wallet_control CAPTAIN : exit 0"
        else
            fail "primal_wallet_control CAPTAIN : exit $PRIMAL_RC" "$(echo "$PRIMAL_OUT" | grep -i 'erreur\|error' | head -3)"
        fi

        # Vérifier conversion v1→SS58 dans la sortie
        if echo "$PRIMAL_OUT" | grep -q "Conversion wallet v1"; then
            ok "conversion v1→SS58 effectuée dans le script"
        else
            if echo "$PRIMAL_OUT" | grep -q "WALLET SURVEILL"; then
                ok "script exécuté (SS58 déjà en cache ou format direct)"
            else
                fail "pas de trace de conversion ni d'exécution" ""
            fi
        fi

        # Vérifier détection CAPTAIN
        if echo "$PRIMAL_OUT" | grep -q "CAPTAIN"; then
            ok "CAPTAIN détecté"
        else
            fail "CAPTAIN non détecté" ""
        fi

        # Vérifier résultat : aucune intrusion
        if echo "$PRIMAL_OUT" | grep -q "Aucune nouvelle intrusion"; then
            ok "aucune intrusion détectée"
        else
            INTRUSIONS=$(echo "$PRIMAL_OUT" | grep -c "INTRUSION" || echo "?")
            fail "intrusions détectées" "$INTRUSIONS intrusions"
        fi

        [[ "$VERBOSE" == true ]] && echo "$PRIMAL_OUT"
    else
        skip "contrôle complet CAPTAIN (prérequis manquants)"
    fi
fi

################################################################################
echo -e "\n${BOLD}═══════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Résultats : ${GREEN}${PASS} pass${RESET} / ${RED}${FAIL} fail${RESET} / ${YELLOW}${SKIP} skip${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════${RESET}\n"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
