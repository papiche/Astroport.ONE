#!/bin/bash
###################################################################
# test_multipass_zencard.sh
# Tests de régression — Architecture MULTIPASS/ZEN Card
#
# Vérifie :
#  1. diceware.sh : génération de passphrases mémorisables
#  2. make_NOSTRCARD.sh : variables SALT/PEPPER, génération aléatoire
#  3. make_NOSTRCARD.sh : fonction _diceware() via diceware.sh
#  4. make_NOSTRCARD.sh : fonction _alert_captain() présente
#  5. make_NOSTRCARD.sh : contrôle NOMAIL avant envoi email
#  6. g1.sh (UPassport) : champs JSON "salt"/"pepper" (nommage réel)
#  7. Connect_PLAYER_To_Gchange.sh : absent de la production
#  8. TW.refresh.sh : Connect_PLAYER_To_Gchange.sh retiré des appels
#  9. VISA.new.sh : Connect_PLAYER_To_Gchange.sh retiré des appels
# 10. identity.py : _DISCO_RAND présent, pas de limite SSSS dans identity
# 11. Syntaxe bash valide
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
echo -e "${BOLD}  Tests MULTIPASS / ZEN Card${RESET}"
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

    D1=$(bash "$DICEWARE" 4 2>/dev/null | tr -d '\n' | sed 's/ *$//')
    D2=$(bash "$DICEWARE" 4 2>/dev/null | tr -d '\n' | sed 's/ *$//')
    if [[ "$D1" != "$D2" ]]; then
        ok "diceware.sh est aléatoire (deux appels différents)"
    else
        fail "diceware.sh génère toujours la même valeur" "D1='$D1' D2='$D2'"
    fi
fi

###############################################################################
sep "2. make_NOSTRCARD.sh — variables SALT/PEPPER et génération"
###############################################################################

NOSTRCARD="${TOOLS}/make_NOSTRCARD.sh"

if [[ -f "$NOSTRCARD" ]]; then
    ok "make_NOSTRCARD.sh présent"
else
    fail "make_NOSTRCARD.sh introuvable" "$NOSTRCARD"
fi

# SALT et PEPPER sont les variables réelles (args $5 et $6)
if grep -q '^SALT="\$5"' "$NOSTRCARD" 2>/dev/null \
   || grep -q "^SALT=.*\$5" "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : SALT reçu comme paramètre \$5"
else
    fail "make_NOSTRCARD.sh : SALT=\$5 non trouvé"
fi

if grep -q '^PEPPER="\$6"' "$NOSTRCARD" 2>/dev/null \
   || grep -q "^PEPPER=.*\$6" "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : PEPPER reçu comme paramètre \$6"
else
    fail "make_NOSTRCARD.sh : PEPPER=\$6 non trouvé"
fi

# Génération aléatoire via tr -dc quand SALT/PEPPER absents ou trop longs
if grep -q "SALT=\$(tr -dc" "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : SALT généré aléatoirement via tr -dc"
else
    fail "make_NOSTRCARD.sh : génération aléatoire SALT non détectée"
fi

if grep -q "PEPPER=\$(tr -dc" "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : PEPPER généré aléatoirement via tr -dc"
else
    fail "make_NOSTRCARD.sh : génération aléatoire PEPPER non détectée"
fi

# _DISCO_MAX contrôle la limite de longueur SALT/PEPPER
if grep -q '_DISCO_MAX' "$NOSTRCARD" 2>/dev/null; then
    DISCO_MAX_VAL=$(grep '_DISCO_MAX=' "$NOSTRCARD" 2>/dev/null | grep -oP '\d+' | head -1)
    ok "make_NOSTRCARD.sh : _DISCO_MAX défini (${DISCO_MAX_VAL} chars)"
else
    fail "make_NOSTRCARD.sh : _DISCO_MAX absent"
fi

# DISCO = /?salt=SALT&nostr=PEPPER
if grep -q 'DISCO=.*salt=.*nostr=' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : format DISCO /?salt=SALT&nostr=PEPPER confirmé"
else
    fail "make_NOSTRCARD.sh : format DISCO incorrect"
fi

###############################################################################
sep "3. make_NOSTRCARD.sh — fonction _diceware()"
###############################################################################

if grep -q '_diceware()' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : fonction _diceware() déclarée"
else
    fail "make_NOSTRCARD.sh : _diceware() absente"
fi

# _diceware() doit appeler diceware.sh
if grep -A8 '_diceware()' "$NOSTRCARD" 2>/dev/null | grep -q 'diceware.sh'; then
    ok "make_NOSTRCARD.sh : _diceware() appelle diceware.sh (wordlist officielle)"
else
    fail "make_NOSTRCARD.sh : _diceware() n'appelle pas diceware.sh"
fi

# _DISCO_RAND définit la longueur du SALT/PEPPER aléatoire
if grep -q '_DISCO_RAND' "$NOSTRCARD" 2>/dev/null; then
    DISCO_RAND_VAL=$(grep '_DISCO_RAND' "$NOSTRCARD" 2>/dev/null | grep -oP '\d+' | head -1)
    ok "make_NOSTRCARD.sh : _DISCO_RAND défini ($DISCO_RAND_VAL chars auto-générés)"
else
    fail "make_NOSTRCARD.sh : _DISCO_RAND absent"
fi

###############################################################################
sep "4. make_NOSTRCARD.sh — fonction _alert_captain()"
###############################################################################

if grep -q '_alert_captain()' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : fonction _alert_captain() déclarée"
else
    fail "make_NOSTRCARD.sh : _alert_captain() absente"
fi

if grep -A20 '_alert_captain()' "$NOSTRCARD" 2>/dev/null | grep -q 'mailjet'; then
    ok "make_NOSTRCARD.sh : _alert_captain() envoie via mailjet.sh"
else
    fail "make_NOSTRCARD.sh : _alert_captain() ne semble pas utiliser mailjet.sh"
fi

ALERT_CALLS=$(grep -c '_alert_captain' "$NOSTRCARD" 2>/dev/null || echo 0)
ALERT_CALLS="${ALERT_CALLS//[[:space:]]/}"
if [[ "${ALERT_CALLS:-0}" -ge 4 ]]; then
    ok "make_NOSTRCARD.sh : _alert_captain appelé $ALERT_CALLS fois (couverture erreurs)"
else
    fail "make_NOSTRCARD.sh : _alert_captain appelé seulement $ALERT_CALLS fois (attendu ≥4)"
fi

###############################################################################
sep "5. make_NOSTRCARD.sh — contrôle NOMAIL avant envoi email"
###############################################################################

# Le script vérifie NOMAIL avant d'envoyer l'email du MULTIPASS
# Si NOMAIL est défini par l'appelant, l'email n'est pas envoyé
if grep -q 'NOMAIL' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : variable NOMAIL reconnue (anti double-email)"
else
    fail "make_NOSTRCARD.sh : NOMAIL absent — risque de double envoi email"
fi

if grep -q '\-z.*NOMAIL\|NOMAIL.*-z\|"${NOMAIL}"' "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : NOMAIL testé avant envoi email ✓"
else
    fail "make_NOSTRCARD.sh : vérification NOMAIL non trouvée"
fi

# VISA.new.sh est mentionné en commentaire (architecture cible)
# mais n'est pas encore appelé directement depuis make_NOSTRCARD.sh
if grep -q 'VISA.new.sh' "$NOSTRCARD" 2>/dev/null; then
    VISA_ACTIVE=$(grep -v '^[[:space:]]*#' "$NOSTRCARD" 2>/dev/null \
                  | grep -c 'VISA.new.sh')
    VISA_ACTIVE="${VISA_ACTIVE//[[:space:]]/}"
    if [[ "${VISA_ACTIVE:-0}" -eq 0 ]]; then
        ok "make_NOSTRCARD.sh : VISA.new.sh documenté en commentaire (appel futur)"
    else
        ok "make_NOSTRCARD.sh : VISA.new.sh appelé directement ($VISA_ACTIVE appel(s))"
    fi
else
    skip "make_NOSTRCARD.sh : VISA.new.sh non mentionné"
fi

###############################################################################
sep "6. g1.sh (UPassport) — champs JSON salt/pepper"
###############################################################################

# Chemin : depuis tests/ → ../../ → AAA/ → UPassport/
G1SH="${ASTROPORT_PATH}/../UPassport/g1.sh"
[[ ! -f "$G1SH" ]] && G1SH="${HOME}/.zen/UPassport/g1.sh"
[[ ! -f "$G1SH" ]] && G1SH="$(find "${HOME}/.zen" "${HOME}/workspace" \
    -name "g1.sh" -path "*/UPassport/*" 2>/dev/null | head -1)"

if [[ -f "$G1SH" ]]; then
    ok "g1.sh trouvé : $G1SH"

    # Champs réels : "salt" et "pepper" (pas zencard_salt/pepper)
    if grep -q '"salt"' "$G1SH" 2>/dev/null || grep -q '"${SALT}"' "$G1SH" 2>/dev/null; then
        ok "g1.sh : champ 'salt' présent dans la construction JSON ✓"
    else
        fail "g1.sh : champ 'salt' absent du JSON"
    fi

    if grep -q '"pepper"' "$G1SH" 2>/dev/null || grep -q '"${PEPPER}"' "$G1SH" 2>/dev/null; then
        ok "g1.sh : champ 'pepper' présent dans la construction JSON ✓"
    else
        fail "g1.sh : champ 'pepper' absent du JSON"
    fi

    # NSEC est lu depuis .secret.nostr
    if grep -q 'secret.nostr\|\.secret\.nostr' "$G1SH" 2>/dev/null; then
        ok "g1.sh : NSEC lu depuis .secret.nostr ✓"
    else
        fail "g1.sh : source de NSEC non identifiée"
    fi
else
    skip "g1.sh non trouvé (tester manuellement)"
fi

###############################################################################
sep "7. Connect_PLAYER_To_Gchange.sh — absent de la production"
###############################################################################

CONNECT_PROD="${HOME}/.zen/Astroport.ONE/tools/Connect_PLAYER_To_Gchange.sh"

if [[ ! -f "$CONNECT_PROD" ]]; then
    ok "Connect_PLAYER_To_Gchange.sh : absent de la production ✓ (retiré)"
else
    fail "Connect_PLAYER_To_Gchange.sh encore présent en production" "$CONNECT_PROD"
fi

###############################################################################
sep "8. TW.refresh.sh — Connect_PLAYER_To_Gchange.sh retiré"
###############################################################################

TW_REFRESH="${RUNTIME}/TW.refresh.sh"
[[ ! -f "$TW_REFRESH" ]] && TW_REFRESH="$(find "${HOME}/.zen" \
    -name "TW.refresh.sh" -path "*/RUNTIME/*" 2>/dev/null | head -1)"

if [[ -f "$TW_REFRESH" ]]; then
    ACTIVE_CALLS=$(grep -v '^[[:space:]]*#' "$TW_REFRESH" 2>/dev/null \
        | grep -c 'Connect_PLAYER_To_Gchange')
    ACTIVE_CALLS="${ACTIVE_CALLS//[[:space:]]/}"
    if [[ "${ACTIVE_CALLS:-0}" -eq 0 ]]; then
        ok "TW.refresh.sh : Connect_PLAYER_To_Gchange.sh retiré des appels actifs"
    else
        fail "TW.refresh.sh : $ACTIVE_CALLS appel(s) actif(s) à Connect_PLAYER_To_Gchange.sh"
    fi

    ACTIVE_MOA=$(grep -v '^[[:space:]]*#' "$TW_REFRESH" 2>/dev/null \
        | grep -c 'moa.json\|import.*moa')
    ACTIVE_MOA="${ACTIVE_MOA//[[:space:]]/}"
    if [[ "${ACTIVE_MOA:-0}" -eq 0 ]]; then
        ok "TW.refresh.sh : import moa.json absent ✓"
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
[[ ! -f "$VISA_SH" ]] && VISA_SH="$(find "${HOME}/.zen" \
    -name "VISA.new.sh" -path "*/RUNTIME/*" 2>/dev/null | head -1)"

if [[ -f "$VISA_SH" ]]; then
    VISA_ACTIVE=$(grep -v '^[[:space:]]*#' "$VISA_SH" 2>/dev/null \
        | grep -c 'Connect_PLAYER_To_Gchange' || echo 0)
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
sep "10. identity.py — architecture DISCO (UPassport)"
###############################################################################

IDENTITY_PY="${ASTROPORT_PATH}/../UPassport/routers/identity.py"
[[ ! -f "$IDENTITY_PY" ]] && IDENTITY_PY="${HOME}/.zen/UPassport/routers/identity.py"
[[ ! -f "$IDENTITY_PY" ]] && IDENTITY_PY="$(find "${HOME}/.zen" "${HOME}/workspace" \
    -name "identity.py" -path "*/routers/*" 2>/dev/null | head -1)"

if [[ -f "$IDENTITY_PY" ]]; then
    ok "identity.py trouvé : $IDENTITY_PY"

    # _DISCO_RAND définit la longueur auto-générée si salt/pepper absents
    if grep -q '_DISCO_RAND\|DISCO_RAND' "$IDENTITY_PY" 2>/dev/null; then
        DISCO_RAND=$(grep -oP '_DISCO_RAND\s*=\s*\K\d+' "$IDENTITY_PY" 2>/dev/null | head -1)
        ok "identity.py : _DISCO_RAND = ${DISCO_RAND:-?} (fallback auto-généré) ✓"
    else
        fail "identity.py : _DISCO_RAND absent — fallback auto-généré manquant"
    fi

    # _DISCO_MAX (limite longueur SSSS) doit être dans make_NOSTRCARD.sh, pas ici
    if grep -q '_DISCO_MAX' "$IDENTITY_PY" 2>/dev/null; then
        fail "identity.py : _DISCO_MAX présent ici (devrait être dans make_NOSTRCARD.sh)"
    else
        ok "identity.py : _DISCO_MAX absent ✓ (appartient à make_NOSTRCARD.sh)"
    fi

    # Pas de HTTPException 422 pour salt/pepper trop longs dans identity.py
    if grep -q 'status_code=422.*salt\|HTTPException.*DISCO_MAX\|salt trop long' \
       "$IDENTITY_PY" 2>/dev/null; then
        fail "identity.py : HTTPException 422 pour salt/pepper encore présent"
    else
        ok "identity.py : pas de limite SSSS (422) sur salt/pepper ✓"
    fi

    # Commentaire documentant le rôle ZEN Card de salt/pepper
    if grep -q 'ZEN.Card\|zencard\|VISA\|ZenCard\|ZEN Card' "$IDENTITY_PY" 2>/dev/null; then
        ok "identity.py : rôle ZEN Card de salt/pepper documenté"
    else
        fail "identity.py : documentation ZEN Card manquante"
    fi
else
    skip "identity.py non trouvé (hors périmètre ou chemin différent)"
fi

###############################################################################
sep "11. Syntaxe bash valide"
###############################################################################

if bash -n "$NOSTRCARD" 2>/dev/null; then
    ok "make_NOSTRCARD.sh : syntaxe bash valide ✓"
else
    fail "make_NOSTRCARD.sh : erreur de syntaxe bash !" "bash -n $NOSTRCARD"
fi

if [[ -f "$G1SH" ]]; then
    if bash -n "$G1SH" 2>/dev/null; then
        ok "g1.sh : syntaxe bash valide ✓"
    else
        fail "g1.sh : erreur de syntaxe bash !"
    fi
fi

if [[ -f "$TW_REFRESH" ]]; then
    if bash -n "$TW_REFRESH" 2>/dev/null; then
        ok "TW.refresh.sh : syntaxe bash valide ✓"
    else
        fail "TW.refresh.sh : erreur de syntaxe bash !"
    fi
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
