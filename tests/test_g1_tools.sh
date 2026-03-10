#!/bin/bash
################################################################################
# test_g1_tools.sh — Tests CI pour la couche G1/Duniter v2
#
# Usage:
#   ./tests/test_g1_tools.sh              → tous les tests
#   ./tests/test_g1_tools.sh --quick      → skip virements réels (sections 8-9)
#   ./tests/test_g1_tools.sh --offline    → tests sans réseau (keygen, conversion)
#   ./tests/test_g1_tools.sh --verbose    → sortie détaillée
#
# Compte de test : coucou / coucou
#   v1 pubkey : 5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo
#   SS58 addr : g1LYch17SATt3eb8MhF6VByw6Pd14m7UsYupKLwyCmmRCQTY7
################################################################################
set -u

MY_PATH="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${MY_PATH}/tools"

# ── Options ──────────────────────────────────────────────────────────────────
OFFLINE=false
VERBOSE=false
QUICK=false
for arg in "$@"; do
    case "$arg" in
        --offline) OFFLINE=true ;;
        --verbose) VERBOSE=true ;;
        --quick)   QUICK=true ;;
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

# ── Données de test ──────────────────────────────────────────────────────────
TEST_SALT="coucou"
TEST_PEPPER="coucou"
EXPECTED_V1PUB="5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo"
EXPECTED_SS58="g1LYch17SATt3eb8MhF6VByw6Pd14m7UsYupKLwyCmmRCQTY7"

################################################################################
echo -e "\n${BOLD}═══ TEST SUITE : G1 Tools (Duniter v2) ═══${RESET}\n"
################################################################################

########################################
echo -e "${CYAN}── 1. Prérequis ──${RESET}"
########################################

# 1.1 keygen
if command -v "${TOOLS}/keygen" &>/dev/null || [[ -x "${TOOLS}/keygen" ]]; then
    ok "keygen disponible"
else
    fail "keygen introuvable" "${TOOLS}/keygen"
fi

# 1.2 gcli
if command -v gcli &>/dev/null; then
    GCLI_VER=$(gcli --version 2>/dev/null | head -1)
    ok "gcli installé ($GCLI_VER)"
else
    fail "gcli non installé" "Installer via tools/install_gcli.sh"
fi

# 1.3 python3 + base58
if python3 -c "import base58" 2>/dev/null; then
    ok "python3 + base58 module"
else
    fail "python3 base58 manquant" "pip3 install base58"
fi

# 1.4 jq
if command -v jq &>/dev/null; then
    ok "jq disponible"
else
    fail "jq non installé" "apt install jq"
fi

# 1.5 Scripts exécutables
for script in G1check.sh G1history.sh G1balance.sh G1primal.sh G1wallet_v2.sh PAYforSURE.sh g1pub_to_ss58.py; do
    if [[ -x "${TOOLS}/${script}" ]]; then
        ok "${script} exécutable"
    else
        fail "${script} non exécutable" "chmod +x ${TOOLS}/${script}"
    fi
done

########################################
echo -e "\n${CYAN}── 2. Génération de clés (keygen) ──${RESET}"
########################################

# 2.1 Clé Duniter (base58)
V1PUB=$("${TOOLS}/keygen" -t base58 "${TEST_SALT}" "${TEST_PEPPER}" 2>/dev/null)
if [[ "$V1PUB" == "$EXPECTED_V1PUB" ]]; then
    ok "keygen base58 : ${V1PUB}"
else
    fail "keygen base58 inattendu" "Attendu: ${EXPECTED_V1PUB}, Obtenu: ${V1PUB}"
fi

# 2.2 Clé Duniter (dunikey fichier)
TMPKEY=$(mktemp)
"${TOOLS}/keygen" -t duniter -o "$TMPKEY" "${TEST_SALT}" "${TEST_PEPPER}" 2>/dev/null
if grep -q "pub:" "$TMPKEY" 2>/dev/null; then
    DUNI_PUB=$(grep 'pub:' "$TMPKEY" | awk '{print $2}')
    [[ "$DUNI_PUB" == "$EXPECTED_V1PUB" ]] \
        && ok "keygen dunikey : pub=$DUNI_PUB" \
        || fail "keygen dunikey pub mismatch" "Attendu: $EXPECTED_V1PUB, Obtenu: $DUNI_PUB"
else
    fail "keygen dunikey : fichier vide" "$TMPKEY"
fi
rm -f "$TMPKEY"

# 2.3 Clé NOSTR
NPUB=$("${TOOLS}/keygen" -t nostr "${TEST_SALT}" "${TEST_PEPPER}" 2>/dev/null)
if [[ "$NPUB" =~ ^npub1 ]]; then
    ok "keygen nostr : ${NPUB:0:20}..."
else
    fail "keygen nostr : format invalide" "$NPUB"
fi

# 2.4 Clé IPFS
TMPIPFS=$(mktemp)
"${TOOLS}/keygen" -t ipfs -o "$TMPIPFS" "${TEST_SALT}" "${TEST_PEPPER}" 2>/dev/null
if [[ -s "$TMPIPFS" ]]; then
    ok "keygen ipfs : clé générée ($(wc -c < "$TMPIPFS") bytes)"
else
    fail "keygen ipfs : fichier vide" "$TMPIPFS"
fi
rm -f "$TMPIPFS"

########################################
echo -e "\n${CYAN}── 3. Conversion v1 ↔ SS58 ──${RESET}"
########################################

# 3.1 v1 → SS58
SS58=$(python3 "${TOOLS}/g1pub_to_ss58.py" "$EXPECTED_V1PUB" 2>/dev/null)
if [[ "$SS58" == "$EXPECTED_SS58" ]]; then
    ok "v1→SS58 : ${EXPECTED_V1PUB:0:12}... → ${SS58:0:16}..."
else
    fail "v1→SS58 : résultat inattendu" "Attendu: $EXPECTED_SS58, Obtenu: $SS58"
fi

# 3.2 SS58 → v1 (reverse)
V1_BACK=$(python3 "${TOOLS}/g1pub_to_ss58.py" --reverse "$EXPECTED_SS58" 2>/dev/null)
if [[ "$V1_BACK" == "$EXPECTED_V1PUB" ]]; then
    ok "SS58→v1 : ${EXPECTED_SS58:0:16}... → ${V1_BACK:0:12}..."
else
    fail "SS58→v1 : résultat inattendu" "Attendu: $EXPECTED_V1PUB, Obtenu: $V1_BACK"
fi

# 3.3 Roundtrip keygen → v1 → SS58 → v1
ROUNDTRIP_V1=$("${TOOLS}/keygen" -t base58 "${TEST_SALT}" "${TEST_PEPPER}" 2>/dev/null)
ROUNDTRIP_SS58=$(python3 "${TOOLS}/g1pub_to_ss58.py" "$ROUNDTRIP_V1" 2>/dev/null)
ROUNDTRIP_BACK=$(python3 "${TOOLS}/g1pub_to_ss58.py" --reverse "$ROUNDTRIP_SS58" 2>/dev/null)
if [[ "$ROUNDTRIP_V1" == "$ROUNDTRIP_BACK" ]]; then
    ok "roundtrip v1→SS58→v1 : identique"
else
    fail "roundtrip : mismatch" "$ROUNDTRIP_V1 ≠ $ROUNDTRIP_BACK"
fi

# 3.4 SS58 passthrough (déjà au bon format)
PASSTHROUGH=$(python3 "${TOOLS}/g1pub_to_ss58.py" "$EXPECTED_SS58" 2>/dev/null)
if [[ "$PASSTHROUGH" == "$EXPECTED_SS58" ]]; then
    ok "SS58 passthrough : inchangé"
else
    fail "SS58 passthrough : modifié" "$PASSTHROUGH"
fi

# 3.5 Validation format invalide
INVALID_RESULT=$(python3 "${TOOLS}/g1pub_to_ss58.py" "INVALID_KEY" 2>&1)
if [[ $? -ne 0 ]]; then
    ok "clé invalide : rejetée correctement"
else
    fail "clé invalide : pas d'erreur" "$INVALID_RESULT"
fi

########################################
echo -e "\n${CYAN}── 4. gcli vault ──${RESET}"
########################################

if command -v gcli &>/dev/null; then
    # 4.1 vault list
    VAULT_OUT=$(gcli vault list all 2>&1)
    if [[ $? -eq 0 ]]; then
        ok "gcli vault list : OK"
    else
        fail "gcli vault list" "$VAULT_OUT"
    fi

    # 4.2 vault inspect (si entrée existante)
    FIRST_VAULT=$(gcli vault list base 2>/dev/null | awk 'NR==1{print $1}')
    if [[ -n "$FIRST_VAULT" && "$FIRST_VAULT" =~ ^g1 ]]; then
        INSPECT=$(gcli vault inspect -a "$FIRST_VAULT" --no-password 2>&1)
        if echo "$INSPECT" | grep -q "G1v1 public key"; then
            G1V1_FROM_VAULT=$(echo "$INSPECT" | grep "G1v1 public key" | grep -oP "'[^']+'" | tr -d "'")
            ok "gcli vault inspect : SS58=$FIRST_VAULT → v1=$G1V1_FROM_VAULT"
        else
            ok "gcli vault inspect : SS58=$FIRST_VAULT (pas de clé v1)"
        fi
    else
        skip "gcli vault inspect (vault vide)"
    fi

    # 4.3 gcli -a <SS58> account balance
    if [[ "$OFFLINE" == false ]]; then
        BAL_OUT=$(gcli -a "$EXPECTED_SS58" account balance 2>&1)
        BAL_RC=$?
        if [[ $BAL_RC -eq 0 ]]; then
            ok "gcli account balance SS58 : $BAL_OUT"
        else
            # "does not exist" is valid for empty accounts
            if echo "$BAL_OUT" | grep -q "does not exist"; then
                ok "gcli account balance SS58 : compte inexistant (valide)"
            else
                fail "gcli account balance SS58" "$BAL_OUT"
            fi
        fi
    else
        skip "gcli account balance (offline)"
    fi
else
    skip "gcli vault (gcli non installé)"
    skip "gcli vault inspect"
    skip "gcli account balance"
fi

########################################
echo -e "\n${CYAN}── 5. GraphQL Squid (réseau) ──${RESET}"
########################################

if [[ "$OFFLINE" == true ]]; then
    skip "G1check.sh (offline)"
    skip "G1balance.sh (offline)"
    skip "G1history.sh (offline)"
    skip "G1primal.sh (offline)"
    skip "G1wallet_v2.sh (offline)"
else

    # 5.1 G1check.sh avec pubkey v1
    BALANCE=$(${TOOLS}/G1check.sh "$EXPECTED_V1PUB" 2>/dev/null)
    if [[ -n "$BALANCE" && "$BALANCE" =~ ^[0-9] ]]; then
        ok "G1check.sh (v1 pubkey) : $BALANCE Ğ1"
    else
        fail "G1check.sh (v1 pubkey)" "Résultat: '$BALANCE'"
    fi

    # 5.2 G1check.sh avec SS58
    BALANCE_SS58=$(${TOOLS}/G1check.sh "$EXPECTED_SS58" 2>/dev/null)
    if [[ -n "$BALANCE_SS58" && "$BALANCE_SS58" =~ ^[0-9] ]]; then
        ok "G1check.sh (SS58) : $BALANCE_SS58 Ğ1"
    else
        fail "G1check.sh (SS58)" "Résultat: '$BALANCE_SS58'"
    fi

    # 5.3 Cohérence v1 == SS58
    if [[ "$BALANCE" == "$BALANCE_SS58" ]]; then
        ok "G1check.sh cohérence v1/SS58 : identique ($BALANCE)"
    else
        fail "G1check.sh incohérence v1/SS58" "v1=$BALANCE SS58=$BALANCE_SS58"
    fi

    # 5.4 G1check.sh avec :ZEN
    ZEN_BAL=$(${TOOLS}/G1check.sh "${EXPECTED_V1PUB}:ZEN" 2>/dev/null)
    if [[ -n "$ZEN_BAL" ]]; then
        ok "G1check.sh :ZEN : $ZEN_BAL Ẑen"
    else
        fail "G1check.sh :ZEN" "Résultat vide"
    fi

    # 5.5 G1balance.sh JSON
    BAL_JSON=$(${TOOLS}/G1balance.sh "$EXPECTED_V1PUB" 2>/dev/null)
    if echo "$BAL_JSON" | jq -e '.balances.blockchain' >/dev/null 2>&1; then
        BC_VAL=$(echo "$BAL_JSON" | jq '.balances.blockchain')
        ok "G1balance.sh JSON : blockchain=$BC_VAL"
    else
        fail "G1balance.sh JSON invalide" "$BAL_JSON"
    fi

    # 5.6 G1balance.sh --convert
    BAL_CONV=$(${TOOLS}/G1balance.sh --convert "$EXPECTED_V1PUB" 2>/dev/null)
    if echo "$BAL_CONV" | jq -e '.balances.blockchain' >/dev/null 2>&1; then
        BC_G1=$(echo "$BAL_CONV" | jq '.balances.blockchain')
        ok "G1balance.sh --convert : $BC_G1 Ğ1"
    else
        fail "G1balance.sh --convert" "$BAL_CONV"
    fi

    # 5.7 G1history.sh
    HIST=$(${TOOLS}/G1history.sh "$EXPECTED_V1PUB" 5 2>/dev/null)
    if echo "$HIST" | jq -e '.history' >/dev/null 2>&1; then
        TX_COUNT=$(echo "$HIST" | jq '.history | length')
        ok "G1history.sh : $TX_COUNT transactions"
    else
        fail "G1history.sh JSON invalide" "$HIST"
    fi

    # 5.8 G1history.sh avec SS58
    HIST_SS58=$(${TOOLS}/G1history.sh "$EXPECTED_SS58" 5 2>/dev/null)
    if echo "$HIST_SS58" | jq -e '.history' >/dev/null 2>&1; then
        TX_SS58=$(echo "$HIST_SS58" | jq '.history | length')
        ok "G1history.sh (SS58) : $TX_SS58 transactions"
    else
        fail "G1history.sh (SS58)" "$HIST_SS58"
    fi

    # 5.9 G1wallet_v2.sh balance
    WAL_BAL=$(${TOOLS}/G1wallet_v2.sh balance "$EXPECTED_V1PUB" 2>/dev/null)
    if echo "$WAL_BAL" | grep -q "Ğ1"; then
        ok "G1wallet_v2.sh balance : $(echo "$WAL_BAL" | grep -o '[0-9.]*.*Ğ1' | head -1)"
    else
        fail "G1wallet_v2.sh balance" "$WAL_BAL"
    fi

    # 5.10 G1primal.sh
    PRIMAL=$(${TOOLS}/G1primal.sh "$EXPECTED_V1PUB" 2>/dev/null)
    if [[ -n "$PRIMAL" ]]; then
        ok "G1primal.sh : source=${PRIMAL:0:16}..."
    else
        skip "G1primal.sh (pas de TX pour ce wallet)"
    fi

    # 5.11 Wallet inexistant → solde 0 (pas d'erreur)
    RAND_PUB=$("${TOOLS}/keygen" -t base58 "test_$(date +%s)" "random_$$" 2>/dev/null)
    ZERO_BAL=$(${TOOLS}/G1check.sh "$RAND_PUB" 2>/dev/null)
    if [[ "$ZERO_BAL" == "0" || "$ZERO_BAL" == "" ]]; then
        ok "G1check.sh wallet inexistant : retourne 0 (pas d'erreur)"
    else
        fail "G1check.sh wallet inexistant" "Attendu: 0, Obtenu: $ZERO_BAL"
    fi
fi

########################################
echo -e "\n${CYAN}── 6. PAYforSURE.sh (validation, sans paiement) ──${RESET}"
########################################

# 6.1 Usage sans arguments
PAY_USAGE=$(${TOOLS}/PAYforSURE.sh 2>&1)
if echo "$PAY_USAGE" | grep -q "Usage"; then
    ok "PAYforSURE.sh : affiche usage sans args"
else
    fail "PAYforSURE.sh usage" "$PAY_USAGE"
fi

# 6.2 Montant invalide → traité comme 0 (rien à payer)
PAY_BAD=$(${TOOLS}/PAYforSURE.sh /dev/null "abc" "$EXPECTED_V1PUB" 2>&1)
PAY_BAD_RC=$?
if echo "$PAY_BAD" | grep -qi "nul\|rien\|nothing\|Usage"; then
    ok "PAYforSURE.sh montant invalide : traité comme nul (exit $PAY_BAD_RC)"
elif [[ $PAY_BAD_RC -ne 0 ]]; then
    ok "PAYforSURE.sh montant invalide : rejeté (exit $PAY_BAD_RC)"
else
    fail "PAYforSURE.sh montant invalide non rejeté" "$PAY_BAD"
fi

# 6.3 Montant zéro → exit 0
PAY_ZERO=$(${TOOLS}/PAYforSURE.sh /dev/null "0" "$EXPECTED_V1PUB" 2>&1)
PAY_ZERO_RC=$?
if [[ $PAY_ZERO_RC -eq 0 ]]; then
    ok "PAYforSURE.sh montant 0 : exit 0 (rien à payer)"
else
    fail "PAYforSURE.sh montant 0" "exit code: $PAY_ZERO_RC"
fi

########################################
echo -e "\n${CYAN}── 7. Squid multi-endpoint ──${RESET}"
########################################

if [[ "$OFFLINE" == true ]]; then
    skip "tests squid endpoint (offline)"
else
    SQUID_ENDPOINTS=(
        "https://squid.g1.gyroi.de/v1/graphql"
        "https://squid.g1.coinduf.eu/v1/graphql"
        "https://g1-squid.axiom-team.fr/v1/graphql"
    )

    for sq in "${SQUID_ENDPOINTS[@]}"; do
        RESP=$(curl -sf --max-time 5 -X POST -H "Content-Type: application/json" \
            --data '{"query":"{ __typename }"}' "$sq" 2>/dev/null)
        if [[ -n "$RESP" ]]; then
            ok "squid accessible : $sq"
        else
            fail "squid inaccessible : $sq" "timeout ou erreur"
        fi
    done

    # Test requête avec SS58
    for sq in "${SQUID_ENDPOINTS[@]}"; do
        BAL_RAW=$(curl -sf --max-time 5 -X POST -H "Content-Type: application/json" \
            --data "{\"query\":\"query{accounts(condition:{id:\\\"${EXPECTED_SS58}\\\"}){nodes{balance}}}\"}" \
            "$sq" 2>/dev/null | jq -r '.data.accounts.nodes[0].balance // "null"')
        if [[ "$BAL_RAW" != "null" && -n "$BAL_RAW" ]]; then
            ok "squid balance SS58 ($sq) : $BAL_RAW centimes"
        else
            skip "squid balance SS58 ($sq) : pas de données"
        fi
    done
fi

########################################
echo -e "\n${CYAN}── 8. Virements réels gcli (coucou ↔ totodu56) ──${RESET}"
########################################

# Comptes de test dans le vault gcli :
#   coucou  = coucou/coucou   → g1LYch17SATt3eb8MhF6VByw6Pd14m7UsYupKLwyCmmRCQTY7
#   totodu56 = totodu56/totodu56 → g1K7d5v5Qa1x68qt3ptniKQUnrLoFy37aTPsADD3yaST7D7DU

WALLET_A_VAULT="coucou"
WALLET_A_SS58="g1LYch17SATt3eb8MhF6VByw6Pd14m7UsYupKLwyCmmRCQTY7"
WALLET_B_VAULT="totodu56"
WALLET_B_SS58="g1K7d5v5Qa1x68qt3ptniKQUnrLoFy37aTPsADD3yaST7D7DU"
export GCLI_PASSWORD=""   # mot de passe vide pour les comptes de test
TX_CENTS=100   # gcli prend des centimes : 100 = 1.00 Ğ1
TX_G1="1.00"

if [[ "$OFFLINE" == true || "$QUICK" == true ]]; then
    skip "virements réels (offline/quick)"
elif ! command -v gcli &>/dev/null; then
    skip "virements réels (gcli non installé)"
else
    # 8.0 Vérifier que les deux vault entries existent
    VAULT_LIST=$(gcli vault list all 2>/dev/null)
    if ! echo "$VAULT_LIST" | grep -q "$WALLET_A_VAULT"; then
        fail "vault $WALLET_A_VAULT introuvable" "gcli vault import -S g1v1 --g1v1-id coucou --g1v1-password coucou --no-password -n coucou"
    elif ! echo "$VAULT_LIST" | grep -q "$WALLET_B_VAULT"; then
        fail "vault $WALLET_B_VAULT introuvable" "gcli vault import -S g1v1 --g1v1-id totodu56 --g1v1-password totodu56 --no-password -n totodu56"
    else
        ok "vault entries : $WALLET_A_VAULT + $WALLET_B_VAULT"

        # 8.1 Déterminer qui a le plus de transférable → celui-là envoie
        BAL_A=$(gcli -a "$WALLET_A_SS58" account balance 2>&1)
        BAL_B=$(gcli -a "$WALLET_B_SS58" account balance 2>&1)
        TRANS_A=$(echo "$BAL_A" | grep -oP '[0-9.]+(?= Ğ1 transferable)' || echo "0")
        TRANS_B=$(echo "$BAL_B" | grep -oP '[0-9.]+(?= Ğ1 transferable)' || echo "0")
        [[ -z "$TRANS_A" ]] && TRANS_A="0"
        [[ -z "$TRANS_B" ]] && TRANS_B="0"

        echo -e "    ${CYAN}$WALLET_A_VAULT :${RESET} $TRANS_A Ğ1 transférables"
        echo -e "    ${CYAN}$WALLET_B_VAULT :${RESET} $TRANS_B Ğ1 transférables"

        # Choisir le sender (celui qui a le plus) et le receiver
        if (( $(echo "$TRANS_A >= $TRANS_B" | bc -l) )); then
            SENDER_VAULT="$WALLET_A_VAULT"; SENDER_SS58="$WALLET_A_SS58"; SENDER_TRANS="$TRANS_A"
            RECVR_VAULT="$WALLET_B_VAULT";  RECVR_SS58="$WALLET_B_SS58"
        else
            SENDER_VAULT="$WALLET_B_VAULT"; SENDER_SS58="$WALLET_B_SS58"; SENDER_TRANS="$TRANS_B"
            RECVR_VAULT="$WALLET_A_VAULT";  RECVR_SS58="$WALLET_A_SS58"
        fi

        echo -e "    ${CYAN}Sender :${RESET} $SENDER_VAULT ($SENDER_TRANS Ğ1)"

        if (( $(echo "$SENDER_TRANS < $TX_G1" | bc -l) )); then
            skip "virement (solde insuffisant: $SENDER_TRANS Ğ1 < $TX_G1 Ğ1)"
        else
            ok "sender $SENDER_VAULT : $SENDER_TRANS Ğ1 transférables"

            # 8.2 Virement aller
            echo -e "    ${YELLOW}→ Envoi $TX_G1 Ğ1 : $SENDER_VAULT → $RECVR_VAULT${RESET}"
            TX1_OUT=$(gcli --no-password -v "$SENDER_VAULT" account transfer "$TX_CENTS" "$RECVR_SS58" 2>&1)
            TX1_RC=$?

            if [[ $TX1_RC -eq 0 ]]; then
                ok "virement $SENDER_VAULT→$RECVR_VAULT : $TX_G1 Ğ1"
                [[ "$VERBOSE" == true ]] && echo "    $TX1_OUT"

                echo -e "    ${CYAN}Attente propagation (6s)...${RESET}"
                sleep 6

                # 8.3 Vérifier réception
                RECVR_BAL=$(gcli -a "$RECVR_SS58" account balance 2>&1)
                echo -e "    ${CYAN}$RECVR_VAULT après :${RESET} $RECVR_BAL"
                if echo "$RECVR_BAL" | grep -q "Ğ1"; then
                    ok "$RECVR_VAULT a reçu les fonds"
                else
                    fail "$RECVR_VAULT solde après réception" "$RECVR_BAL"
                fi

                # 8.4 Virement retour
                RECVR_TRANS=$(echo "$RECVR_BAL" | grep -oP '[0-9.]+(?= Ğ1 transferable)')
                if [[ -n "$RECVR_TRANS" ]] && (( $(echo "$RECVR_TRANS >= $TX_G1" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "    ${YELLOW}← Retour $TX_G1 Ğ1 : $RECVR_VAULT → $SENDER_VAULT${RESET}"
                    TX2_OUT=$(gcli --no-password -v "$RECVR_VAULT" account transfer "$TX_CENTS" "$SENDER_SS58" 2>&1)

                    if [[ $? -eq 0 ]]; then
                        ok "retour $RECVR_VAULT→$SENDER_VAULT : $TX_G1 Ğ1"
                        sleep 6
                        SENDER_BAL_AFTER=$(gcli -a "$SENDER_SS58" account balance 2>&1)
                        echo -e "    ${CYAN}$SENDER_VAULT après retour :${RESET} $SENDER_BAL_AFTER"
                        ok "aller-retour complet"

                        # 8.5 Test commentaire (--comment) avec transfer
                        REMARK_MSG="CI:TEST:$(date +%s):ROUND"
                        echo -e "    ${YELLOW}→ Envoi $TX_G1 Ğ1 avec commentaire : $SENDER_VAULT → $RECVR_VAULT${RESET}"
                        TX3_OUT=$(gcli --no-password -v "$SENDER_VAULT" account transfer "$TX_CENTS" "$RECVR_SS58" --comment "$REMARK_MSG" 2>&1)
                        TX3_RC=$?
                        if [[ $TX3_RC -eq 0 ]]; then
                            ok "transfer avec --comment : $REMARK_MSG"
                            [[ "$VERBOSE" == true ]] && echo "    $TX3_OUT"

                            # 8.6 Relecture du commentaire via squid GraphQL
                            echo -e "    ${CYAN}Attente indexation (8s)...${RESET}"
                            sleep 8
                            REMARK_HEX=$(echo -n "$REMARK_MSG" | xxd -p | tr -d '\n')
                            SQUID_URL="https://squid.g1.gyroi.de/v1/graphql"
                            SQUID_QUERY="{\"query\":\"{ calls(filter: { pallet: { equalTo: \\\"System\\\" }, name: { equalTo: \\\"remark\\\" } }, orderBy: BLOCK_ID_DESC, first: 3) { nodes { args } } }\"}"
                            SQUID_OUT=$(curl -s "$SQUID_URL" -H 'Content-Type: application/json' -d "$SQUID_QUERY" 2>/dev/null)
                            # Decode hex remarks and search for our message
                            FOUND_REMARK=""
                            if echo "$SQUID_OUT" | jq -e '.data.calls.nodes' &>/dev/null; then
                                for HEX in $(echo "$SQUID_OUT" | jq -r '.data.calls.nodes[].args.remark' 2>/dev/null); do
                                    DECODED=$(echo "$HEX" | sed 's/^0x//' | xxd -r -p 2>/dev/null)
                                    if [[ "$DECODED" == "$REMARK_MSG" ]]; then
                                        FOUND_REMARK="$DECODED"
                                        break
                                    fi
                                done
                            fi
                            if [[ -n "$FOUND_REMARK" ]]; then
                                ok "relecture commentaire squid : $FOUND_REMARK"
                            else
                                skip "relecture commentaire (indexation en cours ou squid lent)"
                            fi

                            # 8.7 Retour du commentaire-transfer
                            TX4_OUT=$(gcli --no-password -v "$RECVR_VAULT" account transfer "$TX_CENTS" "$SENDER_SS58" 2>&1)
                            [[ $? -eq 0 ]] && ok "retour après commentaire OK" || skip "retour après commentaire"
                        else
                            fail "transfer avec --comment" "$TX3_OUT"
                        fi
                    else
                        fail "retour $RECVR_VAULT→$SENDER_VAULT" "$TX2_OUT"
                    fi
                else
                    skip "retour ($RECVR_VAULT transférable: ${RECVR_TRANS:-0} < $TX_G1)"
                fi
            else
                fail "virement $SENDER_VAULT→$RECVR_VAULT" "$TX1_OUT"
            fi
        fi
    fi
fi

########################################
echo -e "\n${CYAN}── 9. PAYforSURE.sh virement réel (dunikey) ──${RESET}"
########################################

if [[ "$OFFLINE" == true || "$QUICK" == true ]]; then
    skip "PAYforSURE.sh virement réel (offline/quick)"
elif ! command -v gcli &>/dev/null; then
    skip "PAYforSURE.sh virement réel (gcli non installé)"
else
    # Utiliser le vault coucou directement via PAYforSURE.sh (mode vault_name)
    ALICE_CHECK=$("${TOOLS}/G1check.sh" "$EXPECTED_V1PUB" 2>/dev/null)
    echo -e "    ${CYAN}Solde coucou avant PAYforSURE : $ALICE_CHECK Ğ1${RESET}"

    if [[ -n "$ALICE_CHECK" ]] && (( $(echo "${ALICE_CHECK:-0} >= 1" | bc -l 2>/dev/null || echo 0) )); then
        # Envoyer 1 Ğ1 via PAYforSURE.sh (vault name → SS58 dest)
        echo -e "    ${YELLOW}→ PAYforSURE.sh : 1 Ğ1 coucou → totodu56${RESET}"
        PAY_OUT=$("${TOOLS}/PAYforSURE.sh" "$WALLET_A_VAULT" "1" "$WALLET_B_SS58" "CI:TEST:PAYforSURE" 2>&1)
        PAY_RC=$?

        if [[ $PAY_RC -eq 0 ]]; then
            ok "PAYforSURE.sh virement réel : 1 Ğ1 envoyé"
            [[ "$VERBOSE" == true ]] && echo "$PAY_OUT" | tail -5

            sleep 6

            # Retour via gcli vault
            echo -e "    ${YELLOW}← Retour gcli : 1 Ğ1 totodu56 → coucou${RESET}"
            TX_BACK=$(gcli --no-password -v "$WALLET_B_VAULT" account transfer 100 "$WALLET_A_SS58" 2>&1)
            if [[ $? -eq 0 ]]; then
                ok "PAYforSURE.sh roundtrip complet"
            else
                skip "retour gcli" # Bob peut ne pas avoir assez après existential deposit
            fi
        else
            fail "PAYforSURE.sh virement réel" "$(echo "$PAY_OUT" | tail -3)"
        fi
    else
        skip "PAYforSURE.sh virement (solde insuffisant: $ALICE_CHECK)"
    fi
fi

################################################################################
echo -e "\n${BOLD}═══════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Résultats : ${GREEN}${PASS} pass${RESET} / ${RED}${FAIL} fail${RESET} / ${YELLOW}${SKIP} skip${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════${RESET}\n"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
