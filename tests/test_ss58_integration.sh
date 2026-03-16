#!/bin/bash
################################################################################
# test_ss58_integration.sh
# Tests d'intégration SS58 pour les scripts modifiés :
#   - PAYforSURE.sh      : validation DRAIN / montant spécial
#   - primal_wallet_control.sh : get_intrusion_pubkey() → SS58
#   - g1pub_to_ss58.py   : round-trip v1 ↔ SS58
#   - natools.py         : normalize_pubkey (v1.3.2+)
#   - make_NOSTRCARD.sh  : stockage SS58 G1PUBNOSTR
#   - VISA.new.sh        : stockage SS58 G1PUB (.g1pub)
#
# Usage : bash tests/test_ss58_integration.sh [--verbose]
################################################################################
# Pas de set -euo pipefail : les tests gèrent eux-mêmes les erreurs
MY_PATH="$(cd "$(dirname "$0")" && pwd)"
TOOLS="${MY_PATH}/../tools"
TOOLS="$(cd "${TOOLS}" && pwd)"

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

# ── Détection du bon Python (duniterpy installé dans ~/.astro) ─────────────────
PYTHON="python3"
for _py in "$HOME/.astro/bin/python" "$HOME/.astro/bin/python3" \
           "/usr/local/bin/python3" "python3"; do
    if [[ -x "${_py}" ]] && "${_py}" -c "import duniterpy" 2>/dev/null; then
        PYTHON="${_py}"
        break
    fi
done
echo "  🐍 Python utilisé : $PYTHON"

# ── Compteurs ─────────────────────────────────────────────────────────────────
PASS=0; FAIL=0

ok()  { PASS=$(( PASS+1 )); echo "  ✅ $*"; }
ko()  { FAIL=$(( FAIL+1 )); echo "  ❌ $*" >&2; }
sep() { echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
sep2(){ echo "═══════════════════════════════════════════════════════════════"; }

# ── Clés de test (salt=coucou, pepper=coucou) ─────────────────────────────────
KEYGEN="${TOOLS}/keygen"
MOATS_TEST=$(date -u +"%Y%m%d%H%M%S%4N")
TMPDIR_TEST=$(mktemp -d /tmp/test_ss58_XXXXXX)
trap "rm -rf '$TMPDIR_TEST'" EXIT

# ── Scripts à tester ──────────────────────────────────────────────────────────
PAYTEST="${TOOLS}/PAYforSURE.sh"
PRIMAL_CTRL="${TOOLS}/primal_wallet_control.sh"
NOSTRCARD="${TOOLS}/make_NOSTRCARD.sh"
VISA="${MY_PATH}/../RUNTIME/VISA.new.sh"
NATOOLS="${TOOLS}/natools.py"

# ─────────────────────────────────────────────────────────────────────────────
echo
sep
echo "  TESTS SS58 INTÉGRATION — $(date '+%Y-%m-%d %H:%M:%S')"
sep

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  1. Prérequis"
sep

for cmd in $PYTHON bc jq; do
    if command -v "$cmd" &>/dev/null || [[ -x "$cmd" ]]; then
        ok "Commande disponible : $cmd"
    else
        ko "Commande manquante : $cmd (certains tests ignorés)"
    fi
done

if [[ -x "${TOOLS}/g1pub_to_ss58.py" ]]; then
    ok "g1pub_to_ss58.py trouvé"
else
    ko "g1pub_to_ss58.py introuvable — tests de conversion impossibles"
fi

# Génération de la clé v1 de test via Python/duniterpy (plus fiable que keygen)
TEST_V1_PUB=$($PYTHON -c "
import sys; sys.path.insert(0,'${TOOLS}')
import duniterpy.key
sk = duniterpy.key.SigningKey.from_credentials('coucou','coucou')
print(sk.pubkey)
" 2>/dev/null)

if [[ -n "$TEST_V1_PUB" ]]; then
    ok "Clé v1 générée via duniterpy : ${TEST_V1_PUB:0:12}…"
    # Créer aussi un dunikey pour les tests CLI
    if [[ -x "$KEYGEN" ]]; then
        "$KEYGEN" -t duniter -o "$TMPDIR_TEST/test.dunikey" "coucou" "coucou" 2>/dev/null || true
    fi
else
    ko "Génération clé v1 échouée — utilisation d'une clé figée"
    TEST_V1_PUB="5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  2. g1pub_to_ss58.py — conversions v1 ↔ SS58"
sep

if [[ -x "${TOOLS}/g1pub_to_ss58.py" && -n "${TEST_V1_PUB:-}" ]]; then

    TEST_SS58=$($PYTHON "${TOOLS}/g1pub_to_ss58.py" "$TEST_V1_PUB" 2>/dev/null)
    if [[ -n "$TEST_SS58" && "${TEST_SS58:0:2}" == "g1" ]]; then
        ok "v1 → SS58 : ${TEST_V1_PUB:0:12}… → ${TEST_SS58:0:12}…"
    else
        ko "v1 → SS58 échoué (résultat: '${TEST_SS58}')"
    fi

    ROUNDTRIP=$($PYTHON "${TOOLS}/g1pub_to_ss58.py" --reverse "$TEST_SS58" 2>/dev/null)
    if [[ "$ROUNDTRIP" == "$TEST_V1_PUB" ]]; then
        ok "SS58 → v1 round-trip : ✓ résultat identique"
    else
        ko "SS58 → v1 round-trip échoué : attendu=$TEST_V1_PUB, obtenu=$ROUNDTRIP"
    fi

    # Vérifier que l'idempotence est gérée (SS58 en entrée → SS58 inchangé via ensure_ss58)
    SS58_AGAIN=$($PYTHON -c "
import sys; sys.path.insert(0, '${TOOLS}')
from g1pub_to_ss58 import ensure_ss58
print(ensure_ss58('${TEST_SS58}'))
" 2>/dev/null)
    if [[ "$SS58_AGAIN" == "$TEST_SS58" ]]; then
        ok "ensure_ss58(SS58) idempotent ✓"
    else
        ko "ensure_ss58(SS58) non-idempotent : $SS58_AGAIN"
    fi

else
    ko "Test conversion ignoré (g1pub_to_ss58.py ou clé manquante)"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  3. natools.py — normalize_pubkey via module"
sep

if [[ -f "$NATOOLS" ]]; then

    # Test normalize_pubkey(v1) → v1
    NORM_V1=$($PYTHON -c "
import sys; sys.path.insert(0,'${TOOLS}')
import importlib.util
spec = importlib.util.spec_from_file_location('natools','${NATOOLS}')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.normalize_pubkey('${TEST_V1_PUB}'))
" 2>/dev/null)
    if [[ "$NORM_V1" == "$TEST_V1_PUB" ]]; then
        ok "normalize_pubkey(v1) → v1 inchangé ✓"
    else
        ko "normalize_pubkey(v1) a modifié la clé : $NORM_V1"
    fi

    # Test normalize_pubkey(SS58) → v1
    if [[ -n "${TEST_SS58:-}" ]]; then
        NORM_SS58=$($PYTHON -c "
import sys; sys.path.insert(0,'${TOOLS}')
import importlib.util
spec = importlib.util.spec_from_file_location('natools','${NATOOLS}')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.normalize_pubkey('${TEST_SS58}'))
" 2>/dev/null)
        if [[ "$NORM_SS58" == "$TEST_V1_PUB" ]]; then
            ok "normalize_pubkey(SS58) → v1 correct ✓"
        else
            ko "normalize_pubkey(SS58) échoué : attendu=$TEST_V1_PUB, obtenu=$NORM_SS58"
        fi
    fi
else
    ko "natools.py introuvable : $NATOOLS"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  4. PAYforSURE.sh — validation montant DRAIN (sans blockchain)"
sep

if [[ -x "$PAYTEST" ]]; then

    # Test : DRAIN pas bloqué par bc (ancienne version bloquait)
    if grep -q '"DRAIN"' "$PAYTEST" && \
       grep -q 'AMOUNT.*!=.*"ALL".*&&.*AMOUNT.*!=.*"DRAIN"' "$PAYTEST"; then
        ok "PAYforSURE.sh : garde bc conditionnelle pour DRAIN/ALL présente ✓"
    else
        ko "PAYforSURE.sh : garde bc manquante pour DRAIN/ALL"
    fi

    # Test : regex de validation accepte DRAIN
    if grep -q 'DRAIN\$' "$PAYTEST"; then
        ok "PAYforSURE.sh : DRAIN accepté dans la regex de validation montant ✓"
    else
        ko "PAYforSURE.sh : DRAIN absent de la regex de validation"
    fi

    # Test : solde nul bypasse pour DRAIN
    if grep -q 'AMOUNT.*!=.*"DRAIN"' "$PAYTEST"; then
        ok "PAYforSURE.sh : bypass solde nul pour DRAIN présent ✓"
    else
        ko "PAYforSURE.sh : bypass solde nul pour DRAIN manquant"
    fi

    # Test : DRAIN utilise total_balance (pas transferable_balance)
    if grep -A10 '"DRAIN"' "$PAYTEST" | grep -q 'total_balance'; then
        ok "PAYforSURE.sh : DRAIN utilise total_balance (existential deposit inclus) ✓"
    else
        ko "PAYforSURE.sh : DRAIN ne semble pas utiliser total_balance"
    fi

else
    ko "PAYforSURE.sh introuvable ou non exécutable : $PAYTEST"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  5. primal_wallet_control.sh — get_intrusion_pubkey() SS58"
sep

if [[ -x "$PRIMAL_CTRL" ]]; then

    # Vérifier que get_intrusion_pubkey convertit en SS58
    if grep -A15 'get_intrusion_pubkey()' "$PRIMAL_CTRL" | grep -q 'g1pub_to_ss58'; then
        ok "get_intrusion_pubkey() inclut la conversion SS58 ✓"
    else
        ko "get_intrusion_pubkey() ne semble pas convertir en SS58"
    fi

    # Vérifier que DRAIN est géré dans primal_wallet_control
    if grep -q '"DRAIN"' "$PRIMAL_CTRL"; then
        ok "primal_wallet_control.sh : commande DRAIN présente ✓"
    else
        ko "primal_wallet_control.sh : commande DRAIN absente"
    fi

    # Vérifier la logique de DRAIN (PAYforSURE + DRAIN)
    if grep -q 'PAYforSURE' "$PRIMAL_CTRL" && grep -q 'DRAIN' "$PRIMAL_CTRL"; then
        ok "primal_wallet_control.sh : appel PAYforSURE DRAIN détecté ✓"
    else
        ko "primal_wallet_control.sh : PAYforSURE DRAIN absent"
    fi

else
    ko "primal_wallet_control.sh introuvable ou non exécutable : $PRIMAL_CTRL"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  6. make_NOSTRCARD.sh — stockage SS58 G1PUBNOSTR"
sep

if [[ -f "$NOSTRCARD" ]]; then

    if grep -q 'G1PUBNOSTR_V1' "$NOSTRCARD"; then
        ok "make_NOSTRCARD.sh : variable G1PUBNOSTR_V1 séparée (Cesium+) ✓"
    else
        ko "make_NOSTRCARD.sh : G1PUBNOSTR_V1 absent"
    fi

    if grep -q 'g1pub_to_ss58' "$NOSTRCARD" && grep -q 'G1PUBNOSTR' "$NOSTRCARD"; then
        ok "make_NOSTRCARD.sh : conversion SS58 de G1PUBNOSTR présente ✓"
    else
        ko "make_NOSTRCARD.sh : conversion SS58 de G1PUBNOSTR absente"
    fi

    # Cesium+ utilise encore V1
    COUNT_V1=$(grep -c 'G1PUBNOSTR_V1' "$NOSTRCARD" 2>/dev/null || echo 0)
    [[ "$COUNT_V1" -ge 2 ]] \
        && ok "make_NOSTRCARD.sh : Cesium+ API utilise G1PUBNOSTR_V1 ($COUNT_V1 occurrences) ✓" \
        || ko "make_NOSTRCARD.sh : G1PUBNOSTR_V1 insuffisamment utilisé ($COUNT_V1)"

    # natools utilise G1PUBNOSTR (SS58) directement
    if grep 'natools.*encrypt' "$NOSTRCARD" | grep -q '"$G1PUBNOSTR"'; then
        ok "make_NOSTRCARD.sh : natools.py encrypt reçoit G1PUBNOSTR (SS58) ✓"
    else
        ko "make_NOSTRCARD.sh : natools.py encrypt n'utilise pas G1PUBNOSTR (SS58)"
    fi

else
    ko "make_NOSTRCARD.sh introuvable : $NOSTRCARD"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  7. VISA.new.sh — stockage SS58 G1PUB (.g1pub)"
sep

if [[ -f "$VISA" ]]; then

    if grep -q 'G1PUB_V1' "$VISA"; then
        ok "VISA.new.sh : variable G1PUB_V1 séparée présente ✓"
    else
        ko "VISA.new.sh : G1PUB_V1 absent"
    fi

    if grep -q 'g1pub_to_ss58' "$VISA"; then
        ok "VISA.new.sh : conversion SS58 de G1PUB présente ✓"
    else
        ko "VISA.new.sh : conversion SS58 de G1PUB absente"
    fi

    # .g1pub doit contenir SS58 (commentaire ou contexte)
    if grep '\.g1pub' "$VISA" | grep -q 'SS58\|G1PUB'; then
        ok "VISA.new.sh : .g1pub stocké avec G1PUB (SS58) ✓"
    else
        ko "VISA.new.sh : .g1pub pas clairement en SS58"
    fi

else
    ko "VISA.new.sh introuvable : $VISA"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  8. natools.py — version et normalize_pubkey dans le code"
sep

if [[ -f "$NATOOLS" ]]; then

    VERSION=$(grep '__version__' "$NATOOLS" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if $PYTHON -c "
v = '$VERSION'.split('.')
assert int(v[0]) > 1 or (int(v[0]) == 1 and int(v[1]) > 3) or \
       (int(v[0]) == 1 and int(v[1]) == 3 and int(v[2]) >= 2), 'Version trop ancienne'
" 2>/dev/null; then
        ok "natools.py version $VERSION >= 1.3.2 ✓"
    else
        ko "natools.py version $VERSION < 1.3.2 (normalize_pubkey peut être absent)"
    fi

    if grep -q 'def normalize_pubkey' "$NATOOLS"; then
        ok "natools.py : fonction normalize_pubkey() présente ✓"
    else
        ko "natools.py : normalize_pubkey() absente"
    fi

    for fn in encrypt box_encrypt box_decrypt verify; do
        if grep -A3 "def $fn" "$NATOOLS" | grep -q 'normalize_pubkey'; then
            ok "natools.py : $fn() appelle normalize_pubkey() ✓"
        else
            ko "natools.py : $fn() n'appelle pas normalize_pubkey()"
        fi
    done

    # Test: normalize dans le __main__ (avant la validation de longueur)
    if grep -A3 'if pubkey:' "$NATOOLS" | grep -q 'normalize_pubkey'; then
        ok "natools.py : normalize_pubkey() dans __main__ (avant validation longueur) ✓"
    else
        ko "natools.py : normalize_pubkey() absent du __main__"
    fi
else
    ko "natools.py introuvable : $NATOOLS"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep
echo "  9. Test de chiffrement CLI natools.py (si duniterpy disponible)"
sep

if $PYTHON -c "import duniterpy" 2>/dev/null && \
   $PYTHON -c "import libnacl" 2>/dev/null && \
   [[ -n "${TEST_V1_PUB:-}" && -n "${TEST_SS58:-}" ]]; then

    PLAIN_FILE="$TMPDIR_TEST/plain.txt"
    ENC_V1="$TMPDIR_TEST/enc_v1.bin"
    ENC_SS58="$TMPDIR_TEST/enc_ss58.bin"

    echo -n "Test UPlanet SS58 2026" > "$PLAIN_FILE"

    # Chiffrement avec clé v1
    $PYTHON "$NATOOLS" encrypt -p "$TEST_V1_PUB" -i "$PLAIN_FILE" -o "$ENC_V1" 2>/dev/null
    if [[ -s "$ENC_V1" ]]; then
        ok "natools encrypt (v1 pubkey) → fichier chiffré créé ✓"
    else
        ko "natools encrypt (v1 pubkey) → fichier vide ou erreur"
    fi

    # Chiffrement avec clé SS58 (test de normalize_pubkey dans __main__)
    $PYTHON "$NATOOLS" encrypt -p "$TEST_SS58" -i "$PLAIN_FILE" -o "$ENC_SS58" 2>/dev/null
    if [[ -s "$ENC_SS58" ]]; then
        ok "natools encrypt (SS58 pubkey) → fichier chiffré créé ✓"
    else
        ko "natools encrypt (SS58 pubkey) → fichier vide ou erreur (normalize_pubkey CLI ?)"
    fi

    # Déchiffrement du fichier chiffré avec SS58 via clé privée
    if [[ -x "$KEYGEN" && -s "$ENC_SS58" && -f "$TMPDIR_TEST/test.dunikey" ]]; then
        DEC_FILE="$TMPDIR_TEST/dec.txt"
        $PYTHON "$NATOOLS" decrypt -f pubsec -k "$TMPDIR_TEST/test.dunikey" \
            -i "$ENC_SS58" -o "$DEC_FILE" 2>/dev/null
        if [[ -s "$DEC_FILE" ]]; then
            DEC_CONTENT=$(cat "$DEC_FILE")
            if [[ "$DEC_CONTENT" == "Test UPlanet SS58 2026" ]]; then
                ok "natools encrypt(SS58) + decrypt(dunikey) → message original ✓"
            else
                ko "natools encrypt(SS58) + decrypt : contenu incorrect : '$DEC_CONTENT'"
            fi
        else
            ko "natools decrypt (SS58 enc) → fichier vide"
        fi
    fi
else
    echo "  ⚠️  duniterpy/libnacl absent ou clés manquantes — test CLI ignoré"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep2
echo
echo "  Résultat final : $PASS test(s) réussi(s), $FAIL échec(s)"
echo
sep2

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
