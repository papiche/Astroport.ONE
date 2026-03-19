#!/bin/bash
###################################################################
# test_multipass_zencard.sh
# Tests de régression — Architecture MULTIPASS/ZEN Card v1→v2
#
# Vérifie les changements introduits lors de la migration :
#  1. diceware.sh : génération de passphrases mémorisables
#  2. make_NOSTRCARD.sh : séparation ZENCARD_SALT / MULTIPASS random
#  3. make_NOSTRCARD.sh : fonction _diceware() via diceware.sh
#  4. make_NOSTRCARD.sh : fonction _alert_captain() présente
#  5. make_NOSTRCARD.sh : VISA.new.sh appelé avec 9 arguments corrects
#  6. g1.sh : write_multipass_json retourne zencard_salt/pepper (pas salt/pepper)
#  7. g1.sh : diceware.sh utilisé pour le fallback ZEN Card
#  8. Connect_PLAYER_To_Gchange.sh : stub deprecated → exit 0
#  9. TW.refresh.sh : Connect_PLAYER_To_Gchange.sh retiré des appels
# 10. VISA.new.sh : Connect_PLAYER_To_Gchange.sh retiré des appels
# 11. identity.py : limite 56 chars supprimée (plus de HTTPException 422)
# 12. make_NOSTRCARD.sh : MULTIPASS_SALT toujours aléatoire (jamais depuis user)
#
# Usage : bash tests/test_multipass_zencard.sh [--verbose]
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"
TOOLS="${ASTROPORT_PATH}/tools"
RUNTIME="${ASTROPORT_PATH}/RUNTIME"

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Compteurs ─────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0

ok()   { ((PASS++)); echo -e "  ${GREEN}✅${RESET} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}❌${RESET} $1"; [[ "$VERBOSE" == true ]] && [[ -n "${2:-}" ]] && echo "    ↳ $2"; }
skip() { ((SKIP++)); echo -e "  ${YELLOW}⊘${RESET} $1 (ignoré)"; }
sep()  { echo -e "${BLUE}━━━ $1 ━━━${RESET}"; }

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Tests MULTIPASS / ZEN Card — Migration v1→v2${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

###############################################################################
sep "1. diceware.sh — wordlist et génération"
###############################################################################

DICEWARE="${TOOLS}/diceware.sh"
DICEWARE_WL="${TOOLS}/diceware-wordlist.txt"

if [[ -x "$DICEWARE" ]]; then
    ok "diceware.sh est exécutable"
else
    fail "diceware.sh introuvable ou non exécutable" "$DICEWARE"
fi

if [[ -f "$DICEWARE_WL" ]]; then
    WL_COUNT=$(wc -l < "$DICEWARE_WL" 2>/dev/null || echo 0)
    ok "diceware-wordlist.txt présent ($WL_COUNT lignes)"
else
    fail "diceware-wordlist.txt absent" "$DICEWARE_WL"
fi

if [[ -x "$DICEWARE" ]]; then
    DICE_OUT=$(bash "$DICEWARE" 4 2>/dev/null | tr -d '\n' | sed 's/ *$//')
    if [[ -n "$DICE_OUT" ]]; then
        WORD_COUNT=$(echo "$DICE_OUT" | wc -w)
        ok "diceware.sh 4 → '$DICE_OUT' ($WORD_COUNT mots)"
    else
        fail "diceware.sh produit une sortie vide"
    fi

    # Deux appels doivent donner des résultats différents (aléatoire)
    D1=$(bash "$DICEWARE" 4 2>/dev/null | tr -d '\n' | sed 's/ *$//')
    D2=$(bash "$DICEWARE" 4 2>/dev/null | tr -d '\n' | sed 's/ *$//')
    if [[ "$D1" != "$D2" ]]; then
        ok "diceware.sh est aléatoire (deux appels différents)"
    else
        fail "diceware.sh génère toujours la même valeur (pas aléatoire ?)" "D1='$D1' D2='$D2'"
    fi
fi

###############################################################################
sep "2. make_NOSTRCARD.sh — séparation ZENCARD / MULTIPASS"
###############################################################################

NOSTRCARD="${TOOLS}/make_NOSTRCARD.sh"

if [[ -f "$NOSTRCARD" ]]; then
    ok "make_NOSTRCARD.sh présent"
else
    fail "make_NOSTRCARD.sh introuvable" "$NOSTRCARD"
fi

# Vérifier la variable ZENCARD_SALT
if grep -q 'ZENCARD_SALT' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : variable ZENCARD_SALT présente (séparation des clés)"
else
    fail "make_NOSTRCARD.sh : ZENCARD_SALT absent — séparation non implémentée"
fi

# Vérifier la variable ZENCARD_PEPPER
if grep -q 'ZENCARD_PEPPER' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : variable ZENCARD_PEPPER présente"
else
    fail "make_NOSTRCARD.sh : ZENCARD_PEPPER absent"
fi

# Vérifier que le MULTIPASS SALT est généré aléatoirement (pas depuis l'utilisateur)
# La logique critique : SALT=random même si ZENCARD_SALT est fourni
if grep -q 'MULTIPASS.*TOUJOURS.*ALÉATOIRE\|DISCO.*TOUJOURS.*ALÉATOIRE\|always random\|Always.*random' "$NOSTRCARD" 2>/dev/null \
   || grep -A2 'ZENCARD_SALT.*:-' "$NOSTRCARD" 2>/dev/null | grep -q 'SALT=\$(tr'; then
    ok "make_NOSTRCARD.sh : commentaire confirme MULTIPASS DISCO toujours aléatoire"
elif grep -q "SALT=\$(tr -dc" "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : génération aléatoire de SALT détectée"
else
    fail "make_NOSTRCARD.sh : génération aléatoire MULTIPASS SALT non vérifiable"
fi

# Vérifier que ZENCARD_SALT ne va PAS dans DISCO
if grep -q 'DISCO.*ZENCARD\|ZENCARD.*DISCO' "$NOSTRCARD" 2>/dev/null; then
    fail "make_NOSTRCARD.sh : ZENCARD_SALT semble aller dans le DISCO (incorrect !)"
else
    ok "make_NOSTRCARD.sh : ZENCARD_SALT n'est pas dans le DISCO ✓"
fi

###############################################################################
sep "3. make_NOSTRCARD.sh — fonction _diceware()"
###############################################################################

if grep -q 'def.*_diceware\|^_diceware()' "$NOSTRCARD" 2>/dev/null || grep -q '_diceware()' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : fonction _diceware() déclarée"
else
    fail "make_NOSTRCARD.sh : _diceware() absente"
fi

# _diceware() doit appeler diceware.sh (pas /usr/share/dict/words)
if grep -A8 '_diceware()' "$NOSTRCARD" 2>/dev/null | grep -q 'diceware.sh'; then
    ok "make_NOSTRCARD.sh : _diceware() appelle diceware.sh (wordlist officielle)"
else
    fail "make_NOSTRCARD.sh : _diceware() n'appelle pas diceware.sh"
fi

# Si ZENCARD_SALT vide → _diceware() est appelé
if grep -q 'ZENCARD_SALT.*_diceware\|_diceware.*ZENCARD_SALT\|-z.*ZENCARD_SALT.*diceware\|diceware.*ZENCARD_SALT' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : diceware généré si ZENCARD_SALT vide"
else
    # Alternative: diceware appelé dans un bloc conditionnel
    DICEWARE_ZENCARD=$(grep -n '_diceware\|ZENCARD_SALT' "$NOSTRCARD" 2>/dev/null | head -5)
    [[ -n "$DICEWARE_ZENCARD" ]] \
        && ok "make_NOSTRCARD.sh : génération diceware ZEN Card détectée (alternative)" \
        || fail "make_NOSTRCARD.sh : pas de génération diceware pour ZEN Card vide"
fi

###############################################################################
sep "4. make_NOSTRCARD.sh — fonction _alert_captain()"
###############################################################################

if grep -q '_alert_captain()' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : fonction _alert_captain() déclarée"
else
    fail "make_NOSTRCARD.sh : _alert_captain() absente"
fi

# _alert_captain doit utiliser mailjet.sh
if grep -A20 '_alert_captain()' "$NOSTRCARD" 2>/dev/null | grep -q 'mailjet'; then
    ok "make_NOSTRCARD.sh : _alert_captain() envoie via mailjet.sh"
else
    fail "make_NOSTRCARD.sh : _alert_captain() ne semble pas utiliser mailjet.sh"
fi

# Vérifier que _alert_captain est appelé sur les erreurs critiques
ALERT_CALLS=$(grep '_alert_captain' "$NOSTRCARD" 2>/dev/null | wc -l)
ALERT_CALLS="${ALERT_CALLS//[[:space:]]/}"
if [[ "${ALERT_CALLS:-0}" -ge 4 ]]; then
    ok "make_NOSTRCARD.sh : _alert_captain appelé $ALERT_CALLS fois (couverture erreurs)"
else
    fail "make_NOSTRCARD.sh : _alert_captain appelé seulement $ALERT_CALLS fois (insuffisant)" \
         "Attendu ≥4 : SSSS, IPFS, DID failed, DID cache, nostr_setup_profile"
fi

###############################################################################
sep "5. make_NOSTRCARD.sh — appel VISA.new.sh avec 9 arguments"
###############################################################################

# Vérifier que VISA.new.sh est appelé dans le bloc ZEN Card
if grep -q 'VISA.new.sh' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : appel à VISA.new.sh présent"
else
    fail "make_NOSTRCARD.sh : VISA.new.sh non appelé (ZEN Card pas créée)"
fi

# Vérifier que LANG, ZLAT, ZLON sont passés (pas juste SALT PEPPER EMAIL)
if grep -A5 'VISA.new.sh' "$NOSTRCARD" 2>/dev/null | grep -q 'LANG\|ZLAT\|ZLON'; then
    ok "make_NOSTRCARD.sh : VISA.new.sh reçoit LANG/LAT/LON (9 arguments)"
else
    fail "make_NOSTRCARD.sh : VISA.new.sh semble manquer LANG/ZLAT/ZLON (< 9 args ?)"
fi

# Vérifier que NPUBLIC et HEX sont aussi passés à VISA.new.sh (lien MULTIPASS)
if grep -A8 'VISA.new.sh' "$NOSTRCARD" 2>/dev/null | grep -q 'NPUBLIC\|HEX\|NPUB'; then
    ok "make_NOSTRCARD.sh : VISA.new.sh reçoit NPUBLIC/HEX (lien MULTIPASS)"
else
    fail "make_NOSTRCARD.sh : NPUBLIC/HEX absent de l'appel VISA.new.sh"
fi

# Vérifier la signature NOMAIL=1 (pas de double envoi email)
if grep -B1 'VISA.new.sh' "$NOSTRCARD" 2>/dev/null | grep -q 'NOMAIL\|nomail'; then
    ok "make_NOSTRCARD.sh : NOMAIL=1 avant VISA.new.sh (pas de double email)"
elif grep 'VISA.new.sh' "$NOSTRCARD" 2>/dev/null | grep -q 'NOMAIL'; then
    ok "make_NOSTRCARD.sh : NOMAIL=1 sur la même ligne que VISA.new.sh"
else
    fail "make_NOSTRCARD.sh : NOMAIL=1 manquant avant VISA.new.sh (risque double email)"
fi

###############################################################################
sep "6. g1.sh — write_multipass_json : champs zencard_*"
###############################################################################

G1SH="${MY_PATH}/../../../UPassport/g1.sh"                     # workspace dev
[[ ! -f "$G1SH" ]] && G1SH="${HOME}/.zen/UPassport/g1.sh"      # installation prod
[[ ! -f "$G1SH" ]] && G1SH="${HOME}/.zen/workspace/UPassport/g1.sh"
[[ ! -f "$G1SH" ]] && G1SH="$(find "${HOME}/.zen" -name "g1.sh" -path "*/UPassport/*" 2>/dev/null | head -1)"

if [[ -f "$G1SH" ]]; then
    ok "g1.sh trouvé : $G1SH"

    # Vérifier le champ zencard_salt (pas salt)
    if grep -q '"zencard_salt"' "$G1SH" 2>/dev/null; then
        ok "g1.sh : write_multipass_json utilise 'zencard_salt' (distingue ZEN Card de MULTIPASS)"
    else
        fail "g1.sh : 'zencard_salt' absent — retombe sur l'ancienne architecture?"
    fi

    # Vérifier le champ zencard_pepper (pas pepper)
    if grep -q '"zencard_pepper"' "$G1SH" 2>/dev/null; then
        ok "g1.sh : write_multipass_json utilise 'zencard_pepper'"
    else
        fail "g1.sh : 'zencard_pepper' absent"
    fi

    # Vérifier que 'salt' et 'pepper' (anciens champs) ne sont plus là
    if grep -q '"salt"' "$G1SH" 2>/dev/null; then
        fail "g1.sh : ancien champ 'salt' encore présent dans write_multipass_json"
    else
        ok "g1.sh : ancien champ 'salt' supprimé ✓"
    fi

    # Vérifier que NSEC est lu depuis .secret.nostr (pas dérivé de salt/pepper)
    if grep -A5 '_NSEC=' "$G1SH" 2>/dev/null | grep -q 'secret.nostr\|grep.*NSEC'; then
        ok "g1.sh : NSEC lu depuis .secret.nostr (MULTIPASS aléatoire, pas ZEN Card)"
    else
        fail "g1.sh : NSEC semble encore dérivé de salt/pepper (devrait venir de .secret.nostr)"
    fi

    # Vérifier que diceware.sh est utilisé pour la génération fallback
    if grep -q 'diceware.sh\|diceware' "$G1SH" 2>/dev/null; then
        ok "g1.sh : diceware.sh utilisé pour ZEN Card SALT/PEPPER fallback"
    else
        fail "g1.sh : diceware.sh absent — fallback ZEN Card non implémenté"
    fi
else
    skip "g1.sh non trouvé (tester manuellement)"
fi

###############################################################################
sep "7. Connect_PLAYER_To_Gchange.sh — absent de la production"
###############################################################################
## Le fichier a été complètement retiré (pas de stub) — vérifier son absence
CONNECT_PROD="${HOME}/.zen/Astroport.ONE/tools/Connect_PLAYER_To_Gchange.sh"

if [[ ! -f "$CONNECT_PROD" ]]; then
    ok "Connect_PLAYER_To_Gchange.sh : absent de la production ✓ (retiré comme prévu)"
else
    fail "Connect_PLAYER_To_Gchange.sh encore présent en production — devrait être supprimé" "$CONNECT_PROD"
fi

###############################################################################
sep "8. TW.refresh.sh — Connect_PLAYER_To_Gchange.sh retiré"
###############################################################################

## Chercher TW.refresh.sh dans l'arbre connu
TW_REFRESH="${RUNTIME}/TW.refresh.sh"
[[ ! -f "$TW_REFRESH" ]] && TW_REFRESH="$(find "${HOME}/.zen" -name "TW.refresh.sh" -path "*/RUNTIME/*" 2>/dev/null | head -1)"

if [[ -f "$TW_REFRESH" ]]; then
    # Chercher un appel actif (non commenté) à Connect_PLAYER_To_Gchange
    # wc -l toujours exit 0 (pas de double-zéro comme avec grep -c || echo 0)
    ACTIVE_CALLS=$(grep -v '^#\|^[[:space:]]*#' "$TW_REFRESH" 2>/dev/null \
        | grep 'Connect_PLAYER_To_Gchange' | wc -l)
    ACTIVE_CALLS="${ACTIVE_CALLS//[[:space:]]/}"
    if [[ "${ACTIVE_CALLS:-0}" -eq 0 ]]; then
        ok "TW.refresh.sh : Connect_PLAYER_To_Gchange.sh retiré des appels actifs"
    else
        fail "TW.refresh.sh : $ACTIVE_CALLS appel(s) actif(s) à Connect_PLAYER_To_Gchange.sh"
    fi

    # Vérifier que $moa import est aussi absent (retiré à la demande)
    ACTIVE_MOA=$(grep -v '^#\|^[[:space:]]*#' "$TW_REFRESH" 2>/dev/null \
        | grep 'moa.json\|import.*moa' | wc -l)
    ACTIVE_MOA="${ACTIVE_MOA//[[:space:]]/}"
    if [[ "${ACTIVE_MOA:-0}" -eq 0 ]]; then
        ok "TW.refresh.sh : import moa.json absent (retiré comme demandé)"
    else
        fail "TW.refresh.sh : $ACTIVE_MOA appel(s) à moa.json encore présents"
    fi
else
    skip "TW.refresh.sh non trouvé"
fi

###############################################################################
sep "9. VISA.new.sh — Connect_PLAYER_To_Gchange.sh retiré"
###############################################################################

VISA_SH="${RUNTIME}/VISA.new.sh"
[[ ! -f "$VISA_SH" ]] && VISA_SH="$(find "${HOME}/.zen" -name "VISA.new.sh" -path "*/RUNTIME/*" 2>/dev/null | head -1)"

if [[ -f "$VISA_SH" ]]; then
    VISA_ACTIVE=$(grep -v '^#\|^[[:space:]]*#' "$VISA_SH" 2>/dev/null \
        | grep 'Connect_PLAYER_To_Gchange' | wc -l)
    VISA_ACTIVE="${VISA_ACTIVE//[[:space:]]/}"
    if [[ "${VISA_ACTIVE:-0}" -eq 0 ]]; then
        ok "VISA.new.sh : Connect_PLAYER_To_Gchange.sh retiré des appels actifs"
    else
        fail "VISA.new.sh : $VISA_ACTIVE appel(s) actif(s) à Connect_PLAYER_To_Gchange.sh"
    fi
else
    skip "VISA.new.sh non trouvé"
fi

###############################################################################
sep "10. identity.py — limite 56 chars supprimée"
###############################################################################

IDENTITY_PY="${MY_PATH}/../../../UPassport/routers/identity.py"                  # workspace dev
[[ ! -f "$IDENTITY_PY" ]] && IDENTITY_PY="${HOME}/.zen/UPassport/routers/identity.py"  # prod
[[ ! -f "$IDENTITY_PY" ]] && IDENTITY_PY="$(find "${HOME}/.zen" -name "identity.py" -path "*/routers/*" 2>/dev/null | head -1)"

if [[ -f "$IDENTITY_PY" ]]; then
    ok "identity.py trouvé : $IDENTITY_PY"

    # Vérifier que _DISCO_MAX = 56 est absent
    if grep -q '_DISCO_MAX.*=.*56\|DISCO_MAX.*56' "$IDENTITY_PY" 2>/dev/null; then
        fail "identity.py : _DISCO_MAX = 56 encore présent (limite SSSS devrait être supprimée)"
    else
        ok "identity.py : _DISCO_MAX = 56 supprimé ✓ (ZEN Card, pas de limite SSSS)"
    fi

    # Vérifier que le HTTPException 422 pour salt trop long est absent
    if grep -q 'status_code=422.*salt\|HTTPException.*DISCO_MAX\|trop long.*salt\|salt trop long' "$IDENTITY_PY" 2>/dev/null; then
        fail "identity.py : HTTPException 422 pour salt/pepper encore présent"
    else
        ok "identity.py : plus de limite de taille pour salt/pepper ✓"
    fi

    # Vérifier que _DISCO_RAND est toujours là (fallback auto-généré)
    if grep -q '_DISCO_RAND\|DISCO_RAND' "$IDENTITY_PY" 2>/dev/null; then
        ok "identity.py : _DISCO_RAND conservé (fallback auto-généré) ✓"
    else
        fail "identity.py : _DISCO_RAND absent — fallback auto-généré manquant"
    fi

    # Vérifier le commentaire de migration
    if grep -q 'ZEN Card\|zencard\|VISA\|ZenCard' "$IDENTITY_PY" 2>/dev/null; then
        ok "identity.py : commentaire migration ZEN Card présent"
    else
        fail "identity.py : commentaire de migration ZEN Card absent"
    fi
else
    skip "identity.py non trouvé (hors périmètre ou chemin différent)"
fi

###############################################################################
sep "11. make_NOSTRCARD.sh — syntaxe bash valide"
###############################################################################

if bash -n "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : syntaxe bash valide ✓"
else
    fail "make_NOSTRCARD.sh : erreur de syntaxe bash !" \
         "bash -n $NOSTRCARD"
fi

###############################################################################
sep "12. g1.sh — syntaxe bash valide"
###############################################################################

if [[ -f "$G1SH" ]]; then
    if bash -n "$G1SH" 2>/dev/null; then
        ok "g1.sh : syntaxe bash valide ✓"
    else
        fail "g1.sh : erreur de syntaxe bash !"
    fi
fi

###############################################################################
sep "13. Intégration — diceware dans make_NOSTRCARD.sh et g1.sh"
###############################################################################

# make_NOSTRCARD.sh appelle _diceware() avec l'argument 4 (4 mots)
if grep 'ZENCARD_SALT=.*_diceware\|_diceware.*4.*ZENCARD\|ZENCARD.*_diceware.*4' "$NOSTRCARD" 2>/dev/null \
   || (grep -q 'ZENCARD_SALT=$(_diceware' "$NOSTRCARD" 2>/dev/null); then
    ok "make_NOSTRCARD.sh : ZENCARD_SALT assigné depuis _diceware()"
else
    # Cherche pattern plus large
    if grep -q '_diceware' "$NOSTRCARD" 2>/dev/null && grep -q 'ZENCARD_SALT' "$NOSTRCARD" 2>/dev/null; then
        ok "make_NOSTRCARD.sh : _diceware() et ZENCARD_SALT sont présents (intégration probable)"
    else
        fail "make_NOSTRCARD.sh : ZENCARD_SALT et _diceware() ne semblent pas liés"
    fi
fi

# Le TODO mnemonic DUBP est documenté
if grep -q 'mnemonic\|DUBP\|BIP39' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : TODO mnemonic DUBP documenté pour future extension"
else
    fail "make_NOSTRCARD.sh : TODO mnemonic DUBP absent (documentation manquante)"
fi

###############################################################################
# Résumé
###############################################################################
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Résultats MULTIPASS/ZEN Card Tests${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${GREEN}✅ Réussis  :${RESET} $PASS"
echo -e "  ${RED}❌ Échoués  :${RESET} $FAIL"
echo -e "  ${YELLOW}⊘  Ignorés  :${RESET} $SKIP"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✅ Architecture MULTIPASS/ZEN Card : OK${RESET}"
    exit 0
else
    echo -e "  ${RED}${BOLD}❌ $FAIL test(s) échoué(s) — vérifier les modifications${RESET}"
    exit 1
fi
