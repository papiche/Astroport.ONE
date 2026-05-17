#!/bin/bash
################################################################################
# test_multipass_create.sh — Chaîne complète MULTIPASS (keygen → NOSTR → ẐEN)
#
# Teste la création et la vérification des MULTIPASS pour les trois comptes
# déterministes de test (UPlanet ORIGIN uniquement) :
#
#   coucou (salt=coucou  pepper=coucou  email=support+coucou@qo-op.com)
#   toto   (salt=toto    pepper=toto    email=support+toto@qo-op.com  )
#   jean   (salt=jean    pepper=jean    email=support+jean@qo-op.com  )
#
# ⚠️  UPlanet ORIGIN uniquement (1 Ẑen = 0.1 G1).
#    Ces comptes ne doivent PAS exister en production UPlanet ẐEN.
#
# Flags disponibles :
#   --create    → lance make_NOSTRCARD.sh si le MULTIPASS n'existe pas
#               (email envoyé à support+X@qo-op.com — alias réel sur boîte support)
#   --no-email  → supprime l'envoi email (NOMAIL=1) pendant la création
#   --with-zen  → crédite 1 Ẑen via UPLANET.official.sh (nécessite G1 sur UPLANETNAME_G1)
#               NB : UPLANETNAME_G1 = banque centrale G1, UPLANETG1PUB = compteur ẐEN (usage)
#   --verbose   → affiche les outputs complets
#   --quick     → uniquement les tests sans réseau (clés + fichiers)
#
# Usage :
#   ./tests/test_multipass_create.sh                          # vérifie les MULTIPASS existants
#   ./tests/test_multipass_create.sh --create                 # crée + envoie email
#   ./tests/test_multipass_create.sh --create --no-email      # crée sans email
#   ./tests/test_multipass_create.sh --create --with-zen --verbose
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE manquant" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

CREATE=false; WITH_ZEN=false; VERBOSE=false; QUICK=false; NOMAIL=false
for _arg in "$@"; do
    [[ "$_arg" == "--create"   ]] && CREATE=true
    [[ "$_arg" == "--with-zen" ]] && WITH_ZEN=true
    [[ "$_arg" == "--verbose"  ]] && VERBOSE=true
    [[ "$_arg" == "--quick"    ]] && QUICK=true
    [[ "$_arg" == "--no-email" ]] && NOMAIL=true  ## par défaut les emails sont envoyés
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

ok()      { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip()    { echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; SKIP=$((SKIP+1)); }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }
vlog()    { $VERBOSE && echo -e "  ${YELLOW}▸${NC} $1" || true; }

KEYGEN="${ASTROPORT_PATH}/tools/keygen"
MAKE_NOSTRCARD="${ASTROPORT_PATH}/tools/make_NOSTRCARD.sh"
UPLANET_OFFICIAL="${ASTROPORT_PATH}/UPLANET.official.sh"
INTERCOM="${ASTROPORT_PATH}/tools/nostr_node_intercom.py"
NOSTR_DIR="${HOME}/.zen/game/nostr"

## ─────────────────────────────────────────────────────────────────────────────
section "1. Prérequis — outils et environnement UPlanet ORIGIN"
## ─────────────────────────────────────────────────────────────────────────────

[[ -x "$KEYGEN" ]] \
    && ok "keygen présent" || fail "keygen absent : ${KEYGEN}"

[[ -f "$MAKE_NOSTRCARD" ]] \
    && ok "make_NOSTRCARD.sh présent" || fail "make_NOSTRCARD.sh absent"

[[ -f "$INTERCOM" ]] \
    && ok "nostr_node_intercom.py présent" || fail "nostr_node_intercom.py absent"

command -v jq &>/dev/null \
    && ok "jq" || fail "jq manquant"

command -v ssss-split &>/dev/null \
    && ok "ssss (SSSS split/combine)" || fail "ssss manquant (apt install ssss)"

## Vérification mode ORIGIN (protection contre exécution en prod ẐEN)
if [[ -n "${UPLANETNAME_G1:-}" ]]; then
    ok "UPLANETNAME_G1 défini : ${UPLANETNAME_G1:0:20}..."
else
    skip "UPLANETNAME_G1 absent — UPLANET.official.sh ne pourra pas créditer de ẐEN"
fi

## Avertissement ORIGIN
echo -e "  ${YELLOW}ℹ${NC}  Ces comptes sont réservés à UPlanet ORIGIN (1 Ẑen = 0.1 G1)."
echo -e "  ${YELLOW}ℹ${NC}  Ne PAS utiliser en production UPlanet ẐEN."

## ─────────────────────────────────────────────────────────────────────────────
section "2. Dérivation clés déterministes — keygen (G1 + NOSTR + IPFS)"
## ─────────────────────────────────────────────────────────────────────────────

declare -A _EMAILS=( [coucou]="support+coucou@qo-op.com" [toto]="support+toto@qo-op.com" [jean]="support+jean@qo-op.com" )
declare -A _G1PUB _NPUB _NSEC _HEX

for _name in coucou toto jean; do
    _G1PUB[$_name]=$("$KEYGEN" "$_name" "$_name" 2>/dev/null)
    _NPUB[$_name]=$("$KEYGEN" -t nostr "$_name" "$_name" 2>/dev/null)
    _NSEC[$_name]=$("$KEYGEN" -t nostr -s "$_name" "$_name" 2>/dev/null)
    _HEX[$_name]=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "${_NPUB[$_name]}" 2>/dev/null)

    if [[ ${#_G1PUB[$_name]} -gt 40 && ${#_HEX[$_name]} -eq 64 ]]; then
        ok "$_name : G1=${_G1PUB[$_name]:0:12}... NOSTR=${_HEX[$_name]:0:12}..."
        vlog "  email : ${_EMAILS[$_name]}"
        vlog "  npub  : ${_NPUB[$_name]}"
    else
        fail "$_name : dérivation clé échouée (G1=${_G1PUB[$_name]:0:8} hex=${_HEX[$_name]:0:8})"
    fi
done

## ─────────────────────────────────────────────────────────────────────────────
section "3. SSSS round-trip — vérification crypto DISCO"
## ─────────────────────────────────────────────────────────────────────────────
## DISCO = "/?salt=SALT&nostr=PEPPER" — doit survivre à un split/combine ssss
## NB : ssss-combine écrit sur /dev/tty directement (feature sécu), on vérifie RC

for _name in coucou toto jean; do
    _DISCO="/?salt=${_name}&nostr=${_name}"

    ## ssss-split : doit produire 3 shares
    _SPLIT=$(echo "$_DISCO" | ssss-split -t 2 -n 3 -q 2>/dev/null)
    _NB_SHARES=$(echo "$_SPLIT" | grep -c '^[123]-' 2>/dev/null || echo 0)

    if [[ "$_NB_SHARES" -ne 3 ]]; then
        fail "$_name SSSS split : $_NB_SHARES shares (attendu 3)"
        continue
    fi

    ## ssss-combine : RC=0 = reconstruction réussie (output sur /dev/tty, non capturable)
    _SHARES=$(echo "$_SPLIT" | head -2)
    echo "$_SHARES" | ssss-combine -t 2 -q >/dev/null 2>/dev/null
    if [[ $? -eq 0 ]]; then
        ok "$_name DISCO SSSS round-trip (split 3 shares, combine 2/3 → RC=0)"
    else
        fail "$_name SSSS combine échoué (RC non nul)"
    fi
done

## ─────────────────────────────────────────────────────────────────────────────
section "4. Fichiers MULTIPASS — présence dans ~/.zen/game/nostr/"
## ─────────────────────────────────────────────────────────────────────────────

declare -A _MP_EXISTS
for _name in coucou toto jean; do
    _email="${_EMAILS[$_name]}"
    _mp_dir="${NOSTR_DIR}/${_email}"
    _MP_EXISTS[$_name]=false

    if [[ -d "$_mp_dir" ]]; then
        _MP_EXISTS[$_name]=true
        ok "$_name MULTIPASS dir : $_mp_dir"

        ## Vérification fichiers essentiels
        for _f in .multipass.json .secret.nostr .secret.dunikey .ssss.head.player.enc; do
            if [[ -f "${_mp_dir}/${_f}" ]]; then
                vlog "$_name : ${_f} présent"
            else
                fail "$_name : ${_f} absent dans $_mp_dir"
            fi
        done

        ## Vérification cohérence .multipass.json
        if [[ -f "${_mp_dir}/.multipass.json" ]]; then
            _mp_npub=$(jq -r '.npub' "${_mp_dir}/.multipass.json" 2>/dev/null)
            _mp_hex=$(jq -r '.hex' "${_mp_dir}/.multipass.json" 2>/dev/null)
            _mp_email=$(jq -r '.email' "${_mp_dir}/.multipass.json" 2>/dev/null)

            if [[ "$_mp_npub" == "${_NPUB[$_name]}" ]]; then
                ok "$_name : npub .multipass.json correspond à keygen ✓"
            else
                fail "$_name : npub mismatch (json=$_mp_npub, keygen=${_NPUB[$_name]})"
            fi

            if [[ "$_mp_email" == "$_email" ]]; then
                ok "$_name : email .multipass.json correct ($_email)"
            else
                fail "$_name : email mismatch (json=$_mp_email, attendu=$_email)"
            fi
        fi
    else
        if $CREATE; then
            if $NOMAIL; then
                echo -e "  ${YELLOW}▸${NC} MULTIPASS $_name absent → création (NOMAIL=1)..."
                _mk_env="NOMAIL=1"
            else
                echo -e "  ${YELLOW}▸${NC} MULTIPASS $_name absent → création (email → $_email)..."
                _mk_env=""
            fi
            _mk_cmd=(bash "$MAKE_NOSTRCARD" "$_email" "fr" "0.0" "0.0" "$_name" "$_name")
            if $NOMAIL; then
                _mk_cmd=(env NOMAIL=1 "${_mk_cmd[@]}")
            fi
            if $VERBOSE; then
                "${_mk_cmd[@]}"
            else
                "${_mk_cmd[@]}" > /tmp/mknostr_${_name}.log 2>&1
            fi
            if [[ -d "$_mp_dir" ]]; then
                ok "$_name MULTIPASS créé : $_mp_dir"
                _MP_EXISTS[$_name]=true
            else
                fail "$_name MULTIPASS création échouée (voir /tmp/mknostr_${_name}.log)"
            fi
        else
            skip "$_name MULTIPASS absent (ajouter --create pour le générer)"
        fi
    fi
done

## ─────────────────────────────────────────────────────────────────────────────
section "5. Profil NOSTR Kind 0 — publication et query relay"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK; then
    skip "vérification relay Kind 0 (--quick)"
else
    _LOCAL_OK=false
    nc -z -w2 localhost 7777 2>/dev/null && _LOCAL_OK=true

    _RELAY="wss://relay.copylaradio.com"
    $_LOCAL_OK && _RELAY="ws://localhost:7777"

    for _name in coucou toto jean; do
        if [[ "${_MP_EXISTS[$_name]}" == "true" ]]; then
            _email="${_EMAILS[$_name]}"
            _mp_dir="${NOSTR_DIR}/${_email}"

            ## Lire npub depuis .multipass.json
            _mp_npub=$(jq -r '.npub' "${_mp_dir}/.multipass.json" 2>/dev/null)
            _mp_hex=$(jq -r '.hex' "${_mp_dir}/.multipass.json" 2>/dev/null)

            if [[ ${#_mp_hex} -eq 64 ]]; then
                ## Query Kind 0
                _FILTER=$(python3 -c "import json; print(json.dumps({'kinds':[0],'authors':['$_mp_hex'],'limit':1}))")
                _RESULT=$(python3 "$INTERCOM" query \
                    --filter "$_FILTER" \
                    --relays "$_RELAY" 2>/dev/null || echo "[]")
                _NB=$(echo "$_RESULT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

                if [[ "$_NB" -ge 1 ]]; then
                    _UNAME=$(echo "$_RESULT" | python3 -c "
import json,sys
evs=json.load(sys.stdin)
if evs:
    c=json.loads(evs[0].get('content','{}'))
    print(c.get('name','?'))
else:
    print('?')
" 2>/dev/null)
                    ok "$_name Kind 0 sur relay (name=$_UNAME)"
                else
                    skip "$_name Kind 0 absent du relay (pas encore publié ou latence)"
                fi
            else
                skip "$_name : hex invalide, skip query Kind 0"
            fi
        else
            skip "$_name Kind 0 : MULTIPASS absent"
        fi
    done
fi

## ─────────────────────────────────────────────────────────────────────────────
section "6. Solde G1 — vérification balance MULTIPASS (GraphQL squid)"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK; then
    skip "vérification solde G1 (--quick)"
else
    for _name in coucou toto jean; do
        _G1="${_G1PUB[$_name]}"
        if [[ -n "$_G1" ]]; then
            _BAL=$("${ASTROPORT_PATH}/tools/G1check.sh" "$_G1" 2>/dev/null || echo "")
            if [[ -n "$_BAL" && "$_BAL" =~ ^[0-9] ]]; then
                ok "$_name G1 solde : ${_BAL} G1 (${_G1:0:12}...)"
            else
                skip "$_name solde G1 : squid inaccessible ou compte vide ($_BAL)"
            fi
        else
            skip "$_name : G1pub non dérivé"
        fi
    done
fi

## ─────────────────────────────────────────────────────────────────────────────
section "7. UPLANET.official.sh — crédit ẐEN sur MULTIPASS (--with-zen)"
## ─────────────────────────────────────────────────────────────────────────────
## Mode UPlanet ORIGIN : 1 Ẑen = 0.1 G1
## UPLANETNAME_G1  = banque centrale G1 (source des virements)
## UPLANETG1PUB    = compteur ẐEN (usage tokens) — wallet différent

if ! $WITH_ZEN; then
    skip "crédit ẐEN non demandé (ajouter --with-zen pour créditer 1 Ẑen sur chaque compte)"
    echo -e "  ${YELLOW}ℹ${NC}  Commande manuelle :"
    for _name in coucou toto jean; do
        echo -e "    ${BOLD}${UPLANET_OFFICIAL} -l ${_EMAILS[$_name]} -m 1${NC}"
    done
elif [[ ! -f "$UPLANET_OFFICIAL" ]]; then
    fail "UPLANET.official.sh absent : $UPLANET_OFFICIAL"
elif [[ -z "${UPLANETNAME_G1:-}" ]]; then
    skip "UPLANETNAME_G1 non défini — impossible de créditer des ẐEN"
else
    ## Vérifier le solde UPLANETNAME_G1 avant de commencer
    _BANKER_BAL=$("${ASTROPORT_PATH}/tools/G1check.sh" "$UPLANETNAME_G1" 2>/dev/null || echo "0")
    vlog "Solde UPLANETNAME_G1 : ${_BANKER_BAL} G1"

    if ! [[ "$_BANKER_BAL" =~ ^[0-9] ]] || (( $(echo "$_BANKER_BAL < 0.3" | bc -l 2>/dev/null || echo 1) )); then
        skip "UPLANETNAME_G1 solde insuffisant (${_BANKER_BAL} G1) — besoin de 0.1 G1 × 3 comptes"
    else
        for _name in coucou toto jean; do
            _email="${_EMAILS[$_name]}"
            if [[ "${_MP_EXISTS[$_name]}" != "true" ]]; then
                skip "crédit ẐEN $_name : MULTIPASS absent (--create d'abord)"
                continue
            fi
            echo -e "  ${YELLOW}▸${NC} Crédit 1 Ẑen → $_email (UPlanet ORIGIN)..."
            if $VERBOSE; then
                bash "$UPLANET_OFFICIAL" -l "$_email" -m 1
                _RC=$?
            else
                bash "$UPLANET_OFFICIAL" -l "$_email" -m 1 \
                    > /tmp/uplanet_${_name}.log 2>&1
                _RC=$?
            fi
            if [[ $_RC -eq 0 ]]; then
                ok "Crédit 1 Ẑen → $_email (UPlanet ORIGIN)"
            else
                fail "Crédit ẐEN échoué pour $_email (RC=$_RC — voir /tmp/uplanet_${_name}.log)"
            fi
        done
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "8. DID NOSTR — format did:nostr:HEX"
## ─────────────────────────────────────────────────────────────────────────────

for _name in coucou toto jean; do
    _email="${_EMAILS[$_name]}"
    _mp_dir="${NOSTR_DIR}/${_email}"

    if [[ "${_MP_EXISTS[$_name]}" == "true" && -f "${_mp_dir}/.multipass.json" ]]; then
        _mp_hex=$(jq -r '.hex' "${_mp_dir}/.multipass.json" 2>/dev/null)
        if [[ ${#_mp_hex} -eq 64 ]]; then
            _DID="did:nostr:${_mp_hex}"
            ok "$_name DID : ${_DID:0:30}..."
            vlog "  DID complet : $_DID"
        else
            fail "$_name DID : hex invalide ($_mp_hex)"
        fi
    else
        skip "$_name DID : MULTIPASS absent"
    fi
done

## ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}═══════════════════════════════════════════${NC}"

## Récap des MULTIPASS
echo -e "${BOLD}  Récap MULTIPASS :${NC}"
for _name in coucou toto jean; do
    _st="${_MP_EXISTS[$_name]}"
    _icon="$([[ $_st == true ]] && echo "${GREEN}✓${NC}" || echo "${YELLOW}⊘${NC}")"
    echo -e "  $_icon $_name — ${_EMAILS[$_name]}"
done
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  PERFECT — $PASS tests OK${NC}${SKIP:+ ($SKIP skipped)}"
else
    echo -e "${RED}  $FAIL ÉCHEC(S)${NC} / ${GREEN}$PASS OK${NC}${SKIP:+ / $SKIP skipped}"
fi
echo -e "${BOLD}═══════════════════════════════════════════${NC}"

[[ $FAIL -eq 0 ]]
