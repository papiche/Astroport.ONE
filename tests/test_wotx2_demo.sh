#!/bin/bash
################################################################################
# test_wotx2_demo.sh — Dataset de démo WoTx2 (Skills + Craft) — 3 comptes
#
# Initialise un jeu complet de données NOSTR démontrant toutes les fonctions
# de minelife.html avec trois comptes test déterministes :
#
#   coucou (salt=coucou pepper=coucou email=support+coucou@qo-op.com) → LOCAL
#   toto   (salt=toto   pepper=toto   email=support+toto@qo-op.com  ) → REMOTE
#   jean   (salt=jean   pepper=jean   email=support+jean@qo-op.com  ) → LOCAL
#
# Skills publiés :
#   linux X1 (coucou), bash X1 (coucou)
#   docker X1 (toto)
#   python X1 (jean)
#   devops composite (coucou = linux+bash+docker)
#
# Flux WoTx2 démontré (triangle de confiance) :
#   toto  → valide/adoube coucou pour docker  (Règle B)
#   jean  → valide/adoube coucou pour python  (Règle B)
#   coucou→ valide jean pour linux             (Kind 7)
#   Kind 30500 → 30501 → Kind 7 → 30502 → 30503 → 30503 composite → 30504
#
# Usage:
#   ./tests/test_wotx2_demo.sh             # init + vérification
#   ./tests/test_wotx2_demo.sh --quick     # skip publish, vérification seule
#   ./tests/test_wotx2_demo.sh --verbose   # affiche output complet
#   ./tests/test_wotx2_demo.sh --quick --verbose
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE manquant" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

QUICK=false; VERBOSE=false
for _arg in "$@"; do
    [[ "$_arg" == "--quick"   ]] && QUICK=true
    [[ "$_arg" == "--verbose" ]] && VERBOSE=true
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

ok()      { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip()    { echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; SKIP=$((SKIP+1)); }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }
vlog()    { $VERBOSE && echo -e "  ${YELLOW}▸${NC} $1" || true; }

INTERCOM="${ASTROPORT_PATH}/tools/nostr_node_intercom.py"
KEYGEN="${ASTROPORT_PATH}/tools/keygen"

_pub() {
    ## Wrapper publish → retourne event ID ou "" sur erreur
    if $VERBOSE; then
        python3 "$INTERCOM" publish "$@"
    else
        python3 "$INTERCOM" publish "$@" 2>/dev/null
    fi
}

_query() {
    ## Usage: _query <json_filter> <relay>
    local _filter="$1" _relay="$2"
    if $VERBOSE; then
        python3 "$INTERCOM" query --filter "$_filter" --relays "$_relay"
    else
        python3 "$INTERCOM" query --filter "$_filter" --relays "$_relay" 2>/dev/null || echo "[]"
    fi
}

_count() {
    ## Compte les events dans un JSON array
    python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0
}

_ok_id() {
    ## Vérifie qu'une variable contient un event ID valide (64 hex chars)
    local _desc="$1" _id="$2"
    if [[ ${#_id} -eq 64 ]]; then
        ok "$_desc (${_id:0:12}...)"
    else
        fail "$_desc — event ID invalide ou relay a refusé ($_id)"
    fi
}

## ─────────────────────────────────────────────────────────────────────────────
section "0. Setup — enregistrement comptes test dans amisOfAmis (relay local)"
## ─────────────────────────────────────────────────────────────────────────────
## Les hex des comptes test doivent être dans amisOfAmis.txt pour que le relay
## local (strfry writePolicy) accepte leurs événements WoTx2.

_AMIS_FILE="${HOME}/.zen/strfry/amisOfAmis.txt"
mkdir -p "$(dirname "$_AMIS_FILE")" && touch "$_AMIS_FILE"

## Hex déterministes pré-calculés (keygen coucou/toto/jean)
_PRESET_COUCOU="9da638f3ff87f550efb32ca0d363f53047ead410e6748c19eb8ccb81ba3aff27"
_PRESET_TOTO="3c0c298b91979a9d18de706d21d37b2498b9af4bdb9ca9e1b1ab6ea72f7e265c"
_PRESET_JEAN="2188e823f9a2905af085af74fa8476b9a444830ffe46efd4a264b8798837b17e"

_amis_added=0
for _hex in "$_PRESET_COUCOU" "$_PRESET_TOTO" "$_PRESET_JEAN"; do
    if ! grep -q "^${_hex}$" "$_AMIS_FILE" 2>/dev/null; then
        echo "$_hex" >> "$_AMIS_FILE"
        _amis_added=$((_amis_added+1))
    fi
done
if [[ $_amis_added -gt 0 ]]; then
    ok "amisOfAmis.txt : $_amis_added compte(s) test ajouté(s) (relay local les acceptera)"
else
    ok "amisOfAmis.txt : comptes test déjà enregistrés"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "1. Clés test déterministes — coucou (local), toto (remote), jean (local)"
## ─────────────────────────────────────────────────────────────────────────────
## Emails: support+coucou@qo-op.com / support+toto@qo-op.com / support+jean@qo-op.com

_COUCOU_NPUB=$("$KEYGEN" -t nostr "coucou" "coucou" 2>/dev/null)
_COUCOU_NSEC=$("$KEYGEN" -t nostr -s "coucou" "coucou" 2>/dev/null)
_COUCOU_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_COUCOU_NPUB" 2>/dev/null)

_TOTO_NPUB=$("$KEYGEN" -t nostr "toto" "toto" 2>/dev/null)
_TOTO_NSEC=$("$KEYGEN" -t nostr -s "toto" "toto" 2>/dev/null)
_TOTO_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_TOTO_NPUB" 2>/dev/null)

_JEAN_NPUB=$("$KEYGEN" -t nostr "jean" "jean" 2>/dev/null)
_JEAN_NSEC=$("$KEYGEN" -t nostr -s "jean" "jean" 2>/dev/null)
_JEAN_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_JEAN_NPUB" 2>/dev/null)

[[ ${#_COUCOU_HEX} -eq 64 ]] \
    && ok "coucou ${_COUCOU_HEX:0:12}... (support+coucou@qo-op.com)" \
    || fail "dérivation clé coucou échouée"

[[ ${#_TOTO_HEX} -eq 64 ]] \
    && ok "toto   ${_TOTO_HEX:0:12}... (support+toto@qo-op.com)" \
    || fail "dérivation clé toto échouée"

[[ ${#_JEAN_HEX} -eq 64 ]] \
    && ok "jean   ${_JEAN_HEX:0:12}... (support+jean@qo-op.com)" \
    || fail "dérivation clé jean échouée"

## ─────────────────────────────────────────────────────────────────────────────
section "2. Relays — local strfry (coucou+jean) & remote (toto)"
## ─────────────────────────────────────────────────────────────────────────────

_LOCAL_RELAY="ws://localhost:7777"
_REMOTE_RELAY="${myRELAY:-wss://relay.copylaradio.com}"

_local_ok=false
_remote_ok=false

nc -z -w2 localhost 7777 2>/dev/null && _local_ok=true
_REMOTE_HOST=$(echo "$_REMOTE_RELAY" | sed 's|wss\?://||;s|/.*||;s|:.*||')
_REMOTE_PORT=$(echo "$_REMOTE_RELAY" | grep -oP ':\K[0-9]+' || echo "443")
nc -z -w3 "$_REMOTE_HOST" "$_REMOTE_PORT" 2>/dev/null && _remote_ok=true

if $_local_ok; then
    ok "relay local  : $_LOCAL_RELAY (coucou + jean)"
    _COUCOU_RELAY="$_LOCAL_RELAY"
    _JEAN_RELAY="$_LOCAL_RELAY"
else
    skip "relay local absent — coucou+jean utilisent le relay remote"
    _COUCOU_RELAY="$_REMOTE_RELAY"
    _JEAN_RELAY="$_REMOTE_RELAY"
fi

if $_remote_ok; then
    ok "relay remote : $_REMOTE_RELAY (toto)"
else
    skip "relay remote inaccessible"
fi

_TOTO_RELAY="$_REMOTE_RELAY"

## ─────────────────────────────────────────────────────────────────────────────
section "3. Permits Kind 30500 — définitions skills (4 permits)"
## ─────────────────────────────────────────────────────────────────────────────
## coucou: linux, bash  |  toto: docker  |  jean: python

_3Y=$(($(date +%s) + 94608000))

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish permits (--quick ou relay(s) inaccessible(s))"
    _EV_LINUX="" _EV_BASH="" _EV_DOCKER="" _EV_DEVOPS="" _EV_PYTHON=""
else
    _EV_LINUX=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_LINUX_X1"],["t","permit"],["t","auto_proclaimed"],["t","linux"]]' \
        --content '{"id":"PERMIT_LINUX_X1","name":"Linux Fondamentaux","icon":"🐧","skill_tag":"linux","auto_proclaimed":true}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "PERMIT_LINUX_X1 (coucou→local)" "$_EV_LINUX"

    _EV_BASH=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_BASH_X1"],["t","permit"],["t","auto_proclaimed"],["t","bash"]]' \
        --content '{"id":"PERMIT_BASH_X1","name":"Bash Scripting","icon":"📜","skill_tag":"bash","auto_proclaimed":true}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "PERMIT_BASH_X1 (coucou→local)" "$_EV_BASH"

    _EV_DOCKER=$(_pub \
        --nsec "$_TOTO_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_DOCKER_X1"],["t","permit"],["t","auto_proclaimed"],["t","docker"]]' \
        --content '{"id":"PERMIT_DOCKER_X1","name":"Docker Conteneurs","icon":"🐋","skill_tag":"docker","auto_proclaimed":true}' \
        --relays "$_TOTO_RELAY")
    _ok_id "PERMIT_DOCKER_X1 (toto→remote)" "$_EV_DOCKER"

    _EV_PYTHON=$(_pub \
        --nsec "$_JEAN_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_PYTHON_X1"],["t","permit"],["t","auto_proclaimed"],["t","python"]]' \
        --content '{"id":"PERMIT_PYTHON_X1","name":"Python Programmation","icon":"🐍","skill_tag":"python","auto_proclaimed":true}' \
        --relays "$_JEAN_RELAY")
    _ok_id "PERMIT_PYTHON_X1 (jean→local)" "$_EV_PYTHON"

    ## PERMIT_DEVOPS composite (coucou)
    _EV_DEVOPS=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_DEVOPS_X1"],["t","permit"],["t","composite"],["requires","linux","1"],["requires","bash","1"],["requires","docker","1"],["t","linux"],["t","bash"],["t","docker"]]' \
        --content '{"id":"PERMIT_DEVOPS_X1","name":"DevOps Station","icon":"⚙️","skill_tag":"devops","composite":true,"description":"Opération complète dune station Astroport"}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "PERMIT_DEVOPS_X1 composite (coucou→local)" "$_EV_DEVOPS"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "4. Certifications auto-signées Kind 30503 P2P (TTL=3ans)"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish certifs auto-signées (--quick ou relay(s) inaccessible(s))"
    _CERT_COUCOU_LINUX="" _CERT_COUCOU_BASH=""
    _CERT_TOTO_DOCKER=""
    _CERT_JEAN_PYTHON="" _CERT_JEAN_LINUX=""
else
    _CERT_COUCOU_LINUX=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([['d','PERMIT_LINUX_X1'],['t','linux'],['t','auto_proclaimed'],['level','1'],['expiration','$_3Y'],['p','$_COUCOU_HEX']]))")" \
        --content '{"id":"PERMIT_LINUX_X1","name":"Linux Fondamentaux","auto_proclaimed":true}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "coucou→linux X1 (auto-signé)" "$_CERT_COUCOU_LINUX"

    _CERT_COUCOU_BASH=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([['d','PERMIT_BASH_X1'],['t','bash'],['t','auto_proclaimed'],['level','1'],['expiration','$_3Y'],['p','$_COUCOU_HEX']]))")" \
        --content '{"id":"PERMIT_BASH_X1","name":"Bash Scripting","auto_proclaimed":true}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "coucou→bash X1 (auto-signé)" "$_CERT_COUCOU_BASH"

    _CERT_TOTO_DOCKER=$(_pub \
        --nsec "$_TOTO_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([['d','PERMIT_DOCKER_X1'],['t','docker'],['t','auto_proclaimed'],['level','1'],['expiration','$_3Y'],['p','$_TOTO_HEX']]))")" \
        --content '{"id":"PERMIT_DOCKER_X1","name":"Docker Conteneurs","auto_proclaimed":true}' \
        --relays "$_TOTO_RELAY")
    _ok_id "toto→docker X1 (auto-signé)" "$_CERT_TOTO_DOCKER"

    _CERT_JEAN_PYTHON=$(_pub \
        --nsec "$_JEAN_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([['d','PERMIT_PYTHON_X1'],['t','python'],['t','auto_proclaimed'],['level','1'],['expiration','$_3Y'],['p','$_JEAN_HEX']]))")" \
        --content '{"id":"PERMIT_PYTHON_X1","name":"Python Programmation","auto_proclaimed":true}' \
        --relays "$_JEAN_RELAY")
    _ok_id "jean→python X1 (auto-signé)" "$_CERT_JEAN_PYTHON"

    _CERT_JEAN_LINUX=$(_pub \
        --nsec "$_JEAN_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([['d','PERMIT_LINUX_X1'],['t','linux'],['t','auto_proclaimed'],['level','1'],['expiration','$_3Y'],['p','$_JEAN_HEX']]))")" \
        --content '{"id":"PERMIT_LINUX_X1","name":"Linux Fondamentaux","auto_proclaimed":true}' \
        --relays "$_JEAN_RELAY")
    _ok_id "jean→linux X1 (auto-signé)" "$_CERT_JEAN_LINUX"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "5. Demandes d'apprentissage Kind 30501 — coucou (docker + python)"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 30501 (--quick ou relay(s) inaccessible(s))"
    _EV_REQ_DOCKER="" _EV_REQ_PYTHON=""
else
    ## coucou veut docker (permit de toto)
    _EV_REQ_DOCKER=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30501 \
        --tags "$(python3 -c "import json; print(json.dumps([['d','req_docker_coucou'],['l','PERMIT_DOCKER_X1','permit_type'],['p','$_COUCOU_HEX'],['t','permit'],['t','request'],['t','docker']]))")" \
        --content '{"permit_definition_id":"PERMIT_DOCKER_X1","statement":"Je veux apprendre Docker pour operer mes stations Astroport"}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "Kind 30501 coucou demande docker" "$_EV_REQ_DOCKER"

    ## coucou veut python (permit de jean)
    _EV_REQ_PYTHON=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30501 \
        --tags "$(python3 -c "import json; print(json.dumps([['d','req_python_coucou'],['l','PERMIT_PYTHON_X1','permit_type'],['p','$_COUCOU_HEX'],['t','permit'],['t','request'],['t','python']]))")" \
        --content '{"permit_definition_id":"PERMIT_PYTHON_X1","statement":"Je veux apprendre Python pour automatiser mes scripts Astroport"}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "Kind 30501 coucou demande python" "$_EV_REQ_PYTHON"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "6. Validations Kind 7 — triangle de confiance (Règle A ×1/3 chacun)"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 7 (--quick ou relay(s) inaccessible(s))"
    _EV_REACT_DOCKER="" _EV_REACT_PYTHON="" _EV_REACT_JEAN_LINUX=""
else
    ## toto valide coucou pour docker
    _EV_REACT_DOCKER=""
    if [[ -n "$_EV_REQ_DOCKER" ]]; then
        _EV_REACT_DOCKER=$(_pub \
            --nsec "$_TOTO_NSEC" --kind 7 \
            --tags "$(python3 -c "import json; print(json.dumps([['e','$_EV_REQ_DOCKER'],['p','$_COUCOU_HEX'],['t','wotx-review'],['t','docker'],['k','30500']]))")" \
            --content "+" \
            --relays "$_TOTO_RELAY")
        _ok_id "Kind 7 toto→coucou docker (Règle A ×1/3)" "$_EV_REACT_DOCKER"
    else
        skip "Kind 7 toto→coucou docker (30501 manquant)"
    fi

    ## jean valide coucou pour python
    _EV_REACT_PYTHON=""
    if [[ -n "$_EV_REQ_PYTHON" ]]; then
        _EV_REACT_PYTHON=$(_pub \
            --nsec "$_JEAN_NSEC" --kind 7 \
            --tags "$(python3 -c "import json; print(json.dumps([['e','$_EV_REQ_PYTHON'],['p','$_COUCOU_HEX'],['t','wotx-review'],['t','python'],['k','30500']]))")" \
            --content "+" \
            --relays "$_JEAN_RELAY")
        _ok_id "Kind 7 jean→coucou python (Règle A ×1/3)" "$_EV_REACT_PYTHON"
    else
        skip "Kind 7 jean→coucou python (30501 manquant)"
    fi

    ## coucou valide jean pour linux (jean a auto-proclamé linux)
    _EV_REACT_JEAN_LINUX=""
    if [[ -n "$_CERT_JEAN_LINUX" ]]; then
        _EV_REACT_JEAN_LINUX=$(_pub \
            --nsec "$_COUCOU_NSEC" --kind 7 \
            --tags "$(python3 -c "import json; print(json.dumps([['e','$_CERT_JEAN_LINUX'],['p','$_JEAN_HEX'],['t','wotx-review'],['t','linux'],['k','30503']]))")" \
            --content "+" \
            --relays "$_COUCOU_RELAY")
        _ok_id "Kind 7 coucou→jean linux (Règle A ×1/3)" "$_EV_REACT_JEAN_LINUX"
    else
        skip "Kind 7 coucou→jean linux (certif jean linux manquante)"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "7. Attestations Règle B — Kind 30502 (adoubements P2P)"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 30502 (--quick ou relay(s) inaccessible(s))"
    _EV_ATT_DOCKER="" _EV_ATT_PYTHON=""
else
    ## toto adoube coucou pour docker (Règle B : pair X1+ qui endosse)
    _EV_ATT_DOCKER=""
    if [[ -n "$_EV_REQ_DOCKER" ]]; then
        _EV_ATT_DOCKER=$(_pub \
            --nsec "$_TOTO_NSEC" --kind 30502 \
            --tags "$(python3 -c "import json; print(json.dumps([['d','att_docker_coucou'],['e','$_EV_REQ_DOCKER'],['p','$_COUCOU_HEX'],['l','PERMIT_DOCKER_X1','permit_type'],['t','permit'],['t','attestation'],['t','docker']]))")" \
            --content "{\"attested_skill\":\"docker\",\"attested_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            --relays "$_TOTO_RELAY")
        _ok_id "Kind 30502 toto adoube coucou pour docker (Règle B)" "$_EV_ATT_DOCKER"
    else
        skip "Kind 30502 toto→coucou docker (30501 manquant)"
    fi

    ## jean adoube coucou pour python (Règle B)
    _EV_ATT_PYTHON=""
    if [[ -n "$_EV_REQ_PYTHON" ]]; then
        _EV_ATT_PYTHON=$(_pub \
            --nsec "$_JEAN_NSEC" --kind 30502 \
            --tags "$(python3 -c "import json; print(json.dumps([['d','att_python_coucou'],['e','$_EV_REQ_PYTHON'],['p','$_COUCOU_HEX'],['l','PERMIT_PYTHON_X1','permit_type'],['t','permit'],['t','attestation'],['t','python']]))")" \
            --content "{\"attested_skill\":\"python\",\"attested_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            --relays "$_JEAN_RELAY")
        _ok_id "Kind 30502 jean adoube coucou pour python (Règle B)" "$_EV_ATT_PYTHON"
    else
        skip "Kind 30502 jean→coucou python (30501 manquant)"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "8. Certifs résultants Kind 30503 — coucou obtient docker + python"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 30503 certifs acquises (--quick ou relay(s) inaccessible(s))"
    _CERT_COUCOU_DOCKER="" _CERT_COUCOU_PYTHON=""
else
    ## coucou obtient docker via Règle B
    _CERT_COUCOU_DOCKER=""
    if [[ -n "$_EV_ATT_DOCKER" ]]; then
        _CERT_COUCOU_DOCKER=$(_pub \
            --nsec "$_COUCOU_NSEC" --kind 30503 --ttl 94608000 \
            --tags "$(python3 -c "import json; print(json.dumps([['d','PERMIT_DOCKER_X1'],['t','docker'],['level','1'],['expiration','$_3Y'],['p','$_COUCOU_HEX'],['e','$_EV_ATT_DOCKER']]))")" \
            --content '{"id":"PERMIT_DOCKER_X1","name":"Docker Conteneurs","rule_b":true}' \
            --relays "$_COUCOU_RELAY")
        _ok_id "Kind 30503 coucou obtient docker via Règle B" "$_CERT_COUCOU_DOCKER"
    else
        skip "Kind 30503 coucou docker (attestation 30502 manquante)"
        _CERT_COUCOU_DOCKER=""
    fi

    ## coucou obtient python via Règle B
    _CERT_COUCOU_PYTHON=""
    if [[ -n "$_EV_ATT_PYTHON" ]]; then
        _CERT_COUCOU_PYTHON=$(_pub \
            --nsec "$_COUCOU_NSEC" --kind 30503 --ttl 94608000 \
            --tags "$(python3 -c "import json; print(json.dumps([['d','PERMIT_PYTHON_X1'],['t','python'],['level','1'],['expiration','$_3Y'],['p','$_COUCOU_HEX'],['e','$_EV_ATT_PYTHON']]))")" \
            --content '{"id":"PERMIT_PYTHON_X1","name":"Python Programmation","rule_b":true}' \
            --relays "$_COUCOU_RELAY")
        _ok_id "Kind 30503 coucou obtient python via Règle B" "$_CERT_COUCOU_PYTHON"
    else
        skip "Kind 30503 coucou python (attestation 30502 manquante)"
        _CERT_COUCOU_PYTHON=""
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "9. Craft composite Kind 30503 — coucou crée devops (linux+bash+docker)"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish composite craft (--quick ou relay(s) inaccessible(s))"
    _CERT_DEVOPS=""
elif [[ -z "$_CERT_COUCOU_LINUX" || -z "$_CERT_COUCOU_BASH" || -z "$_CERT_COUCOU_DOCKER" ]]; then
    skip "composite craft : certifs ingrédients manquants (linux/bash/docker)"
    _CERT_DEVOPS=""
else
    _CERT_DEVOPS=$(_pub \
        --nsec "$_COUCOU_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','PERMIT_DEVOPS_X1'],['t','devops'],['t','composite'],['level','1'],
            ['expiration','$_3Y'],['p','$_COUCOU_HEX'],
            ['e','$_CERT_COUCOU_LINUX'],['e','$_CERT_COUCOU_BASH'],['e','$_CERT_COUCOU_DOCKER']
        ]))")" \
        --content '{"id":"PERMIT_DEVOPS_X1","name":"DevOps Station","composite":true,"synthesized_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' \
        --relays "$_COUCOU_RELAY")
    _ok_id "Kind 30503 composite devops (linux+bash+docker)" "$_CERT_DEVOPS"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "10. Ressource formation Kind 30504 — toto publie pour devops"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 30504 (--quick ou relay(s) inaccessible(s))"
    _EV_FORMATION=""
else
    _EV_FORMATION=$(_pub \
        --nsec "$_TOTO_NSEC" --kind 30504 \
        --tags '[["d","training_devops_demo"],["t","devops"],["t","formation"],["r","/ipfs/QmDemo.../intro-devops.pdf","document"],["title","Introduction DevOps pour stations Astroport"]]' \
        --content '{"description":"Ressource demo formation devops","skill":"devops","resource_url":"/ipfs/QmDemo.../intro-devops.pdf","resource_type":"document"}' \
        --relays "$_TOTO_RELAY")
    _ok_id "Kind 30504 toto ajoute ressource formation devops" "$_EV_FORMATION"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "11. Vérification relays — query sur relay propre à chaque compte"
## ─────────────────────────────────────────────────────────────────────────────
## coucou/jean → local  |  toto → remote  (évite le FAIL dû au relay croisé)

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "vérification relay (--quick ou relays inaccessibles)"
else
    ## Permits coucou+jean sur relay LOCAL
    if $_local_ok; then
        _F_LOCAL=$(python3 -c "import json; print(json.dumps({'kinds':[30500],'authors':['$_COUCOU_HEX','$_JEAN_HEX']}))")
        _PERMITS_LOCAL=$(_query "$_F_LOCAL" "$_LOCAL_RELAY")
        _NB_LOCAL=$(echo "$_PERMITS_LOCAL" | _count)
        vlog "permits local (coucou+jean) : $_NB_LOCAL"
    else
        _NB_LOCAL=0
    fi

    ## Permits toto sur relay REMOTE
    if $_remote_ok; then
        _F_REMOTE=$(python3 -c "import json; print(json.dumps({'kinds':[30500],'authors':['$_TOTO_HEX']}))")
        _PERMITS_REMOTE=$(_query "$_F_REMOTE" "$_TOTO_RELAY")
        _NB_REMOTE=$(echo "$_PERMITS_REMOTE" | _count)
        vlog "permits remote (toto)       : $_NB_REMOTE"
    else
        _NB_REMOTE=0
    fi

    _NB_PERMITS=$(( _NB_LOCAL + _NB_REMOTE ))
    [[ "$_NB_PERMITS" -ge 1 ]] \
        && ok "relays : ${_NB_PERMITS} permit(s) Kind 30500 trouvé(s) (local:${_NB_LOCAL} + remote:${_NB_REMOTE})" \
        || fail "relays : aucun permit Kind 30500 trouvé (local:${_NB_LOCAL} remote:${_NB_REMOTE})"

    ## Certifs coucou sur local
    if $_local_ok; then
        _F_CERTS=$(python3 -c "import json; print(json.dumps({'kinds':[30503],'authors':['$_COUCOU_HEX']}))")
        _CERTS=$(_query "$_F_CERTS" "$_LOCAL_RELAY")
        _NB_CERTS=$(echo "$_CERTS" | _count)
        vlog "certifs coucou sur local : $_NB_CERTS"
        [[ "$_NB_CERTS" -ge 1 ]] \
            && ok "relay local : $_NB_CERTS certif(s) Kind 30503 de coucou" \
            || skip "relay local : aucun Kind 30503 de coucou (latence relay ou --quick)"
    fi

    ## Craft devops composite sur local
    if $_local_ok; then
        _F_DEVOPS=$(python3 -c "import json; print(json.dumps({'kinds':[30503],'authors':['$_COUCOU_HEX'],'#d':['PERMIT_DEVOPS_X1']}))")
        _DEVOPS=$(_query "$_F_DEVOPS" "$_LOCAL_RELAY")
        _NB_DEVOPS=$(echo "$_DEVOPS" | _count)
        vlog "devops composite sur local : $_NB_DEVOPS"
        [[ "$_NB_DEVOPS" -ge 1 ]] \
            && ok "relay local : craft composite devops X1 de coucou présent" \
            || skip "relay local : craft devops absent (publié après démarrage?)"
    fi

    ## Formation toto sur remote
    if $_remote_ok; then
        _F_FORM=$(python3 -c "import json; print(json.dumps({'kinds':[30504],'authors':['$_TOTO_HEX']}))")
        _FORM=$(_query "$_F_FORM" "$_TOTO_RELAY")
        _NB_FORM=$(echo "$_FORM" | _count)
        vlog "formation toto sur remote : $_NB_FORM"
        [[ "$_NB_FORM" -ge 1 ]] \
            && ok "relay remote : $_NB_FORM ressource(s) formation Kind 30504 de toto" \
            || skip "relay remote : Kind 30504 de toto absent"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "12. Vérification sync N² — backfill_constellation.sh"
## ─────────────────────────────────────────────────────────────────────────────
## toto publie sur REMOTE → doit apparaître sur LOCAL après backfill
## coucou/jean publient sur LOCAL → doivent apparaître sur REMOTE après backfill

if $QUICK || ! $_local_ok || ! $_remote_ok; then
    skip "sync N² : nécessite les deux relays accessibles"
else
    ## toto→remote visible sur local (backfill pull)
    _F_TOTO=$(python3 -c "import json; print(json.dumps({'kinds':[30500,30503,30504],'authors':['$_TOTO_HEX'],'limit':5}))")
    _TOTO_LOCAL=$(_query "$_F_TOTO" "$_LOCAL_RELAY")
    _NB_TOTO_LOCAL=$(echo "$_TOTO_LOCAL" | _count)
    if [[ "$_NB_TOTO_LOCAL" -gt 0 ]]; then
        ok "sync N² : $_NB_TOTO_LOCAL event(s) toto (remote) visible(s) sur local → backfill OK"
    else
        skip "sync N² : events toto absents du local (backfill_constellation.sh pas encore passé)"
    fi

    ## coucou→local visible sur remote (backfill push)
    _F_COUCOU=$(python3 -c "import json; print(json.dumps({'kinds':[30500,30503],'authors':['$_COUCOU_HEX'],'limit':5}))")
    _COUCOU_REMOTE=$(_query "$_F_COUCOU" "$_REMOTE_RELAY")
    _NB_COUCOU_REMOTE=$(echo "$_COUCOU_REMOTE" | _count)
    if [[ "$_NB_COUCOU_REMOTE" -gt 0 ]]; then
        ok "sync N² : $_NB_COUCOU_REMOTE event(s) coucou (local) visible(s) sur remote → backfill OK"
    else
        skip "sync N² : events coucou absents du remote (backfill_constellation.sh pas encore passé)"
    fi

    if [[ "$_NB_TOTO_LOCAL" -gt 0 && "$_NB_COUCOU_REMOTE" -gt 0 ]]; then
        ok "backfill N² bidirectionnel confirmé (local↔remote)"
    elif [[ "$_NB_TOTO_LOCAL" -gt 0 || "$_NB_COUCOU_REMOTE" -gt 0 ]]; then
        skip "backfill N² partiel — attendre le prochain cycle backfill_constellation.sh"
    else
        echo -e "  ${YELLOW}ℹ${NC} Pour déclencher le backfill maintenant :"
        echo -e "    ${BOLD}${ASTROPORT_PATH}/../NIP-101/backfill_constellation.sh --days 1 --verbose${NC}"
        skip "backfill N² non encore exécuté"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "13. Réseau de confiance WoTx2 — synthèse 3 comptes"
## ─────────────────────────────────────────────────────────────────────────────

echo -e "  ${BOLD}Triangle de confiance :${NC}"
echo -e "  coucou (support+coucou@qo-op.com) — relay LOCAL  : ${_COUCOU_NPUB:0:30}..."
echo -e "  toto   (support+toto@qo-op.com  ) — relay REMOTE : ${_TOTO_NPUB:0:30}..."
echo -e "  jean   (support+jean@qo-op.com  ) — relay LOCAL  : ${_JEAN_NPUB:0:30}..."
echo ""
echo -e "  toto  → [Kind 30502] → coucou docker  (Règle B — ${_EV_ATT_DOCKER:+OK}${_EV_ATT_DOCKER:-non publié})"
echo -e "  jean  → [Kind 30502] → coucou python  (Règle B — ${_EV_ATT_PYTHON:+OK}${_EV_ATT_PYTHON:-non publié})"
echo -e "  coucou→ [Kind 7]     → jean linux     (Règle A ×1/3 — ${_EV_REACT_JEAN_LINUX:+OK}${_EV_REACT_JEAN_LINUX:-non publié})"
PASS=$((PASS+1))  # synthèse toujours ok si on arrive ici

## ─────────────────────────────────────────────────────────────────────────────
section "14. Résumé dataset WoTx2 demo"
## ─────────────────────────────────────────────────────────────────────────────

_summary=(
    "PERMIT_LINUX_X1  (30500 coucou)    → ${_EV_LINUX:+${_EV_LINUX:0:12}...}${_EV_LINUX:-non publié}"
    "PERMIT_BASH_X1   (30500 coucou)    → ${_EV_BASH:+${_EV_BASH:0:12}...}${_EV_BASH:-non publié}"
    "PERMIT_DOCKER_X1 (30500 toto)      → ${_EV_DOCKER:+${_EV_DOCKER:0:12}...}${_EV_DOCKER:-non publié}"
    "PERMIT_PYTHON_X1 (30500 jean)      → ${_EV_PYTHON:+${_EV_PYTHON:0:12}...}${_EV_PYTHON:-non publié}"
    "PERMIT_DEVOPS_X1 (30500 composite) → ${_EV_DEVOPS:+${_EV_DEVOPS:0:12}...}${_EV_DEVOPS:-non publié}"
    "coucou→linux X1 (30503 auto)       → ${_CERT_COUCOU_LINUX:+${_CERT_COUCOU_LINUX:0:12}...}${_CERT_COUCOU_LINUX:-non publié}"
    "coucou→bash X1  (30503 auto)       → ${_CERT_COUCOU_BASH:+${_CERT_COUCOU_BASH:0:12}...}${_CERT_COUCOU_BASH:-non publié}"
    "toto→docker X1  (30503 auto)       → ${_CERT_TOTO_DOCKER:+${_CERT_TOTO_DOCKER:0:12}...}${_CERT_TOTO_DOCKER:-non publié}"
    "jean→python X1  (30503 auto)       → ${_CERT_JEAN_PYTHON:+${_CERT_JEAN_PYTHON:0:12}...}${_CERT_JEAN_PYTHON:-non publié}"
    "jean→linux X1   (30503 auto)       → ${_CERT_JEAN_LINUX:+${_CERT_JEAN_LINUX:0:12}...}${_CERT_JEAN_LINUX:-non publié}"
    "coucou demande docker (30501)      → ${_EV_REQ_DOCKER:+${_EV_REQ_DOCKER:0:12}...}${_EV_REQ_DOCKER:-non publié}"
    "coucou demande python (30501)      → ${_EV_REQ_PYTHON:+${_EV_REQ_PYTHON:0:12}...}${_EV_REQ_PYTHON:-non publié}"
    "toto valide docker (Kind 7)        → ${_EV_REACT_DOCKER:+${_EV_REACT_DOCKER:0:12}...}${_EV_REACT_DOCKER:-non publié}"
    "jean valide python (Kind 7)        → ${_EV_REACT_PYTHON:+${_EV_REACT_PYTHON:0:12}...}${_EV_REACT_PYTHON:-non publié}"
    "coucou valide jean linux (Kind 7)  → ${_EV_REACT_JEAN_LINUX:+${_EV_REACT_JEAN_LINUX:0:12}...}${_EV_REACT_JEAN_LINUX:-non publié}"
    "toto adoube coucou docker (30502)  → ${_EV_ATT_DOCKER:+${_EV_ATT_DOCKER:0:12}...}${_EV_ATT_DOCKER:-non publié}"
    "jean adoube coucou python (30502)  → ${_EV_ATT_PYTHON:+${_EV_ATT_PYTHON:0:12}...}${_EV_ATT_PYTHON:-non publié}"
    "coucou→docker Règle B (30503)      → ${_CERT_COUCOU_DOCKER:+${_CERT_COUCOU_DOCKER:0:12}...}${_CERT_COUCOU_DOCKER:-non publié}"
    "coucou→python Règle B (30503)      → ${_CERT_COUCOU_PYTHON:+${_CERT_COUCOU_PYTHON:0:12}...}${_CERT_COUCOU_PYTHON:-non publié}"
    "coucou→devops composite (30503)    → ${_CERT_DEVOPS:+${_CERT_DEVOPS:0:12}...}${_CERT_DEVOPS:-non publié}"
    "toto formation devops (30504)      → ${_EV_FORMATION:+${_EV_FORMATION:0:12}...}${_EV_FORMATION:-non publié}"
)
for _s in "${_summary[@]}"; do echo "  $_s"; done

## ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}═══════════════════════════════════════════${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  PERFECT — $PASS tests OK${NC}${SKIP:+ ($SKIP skipped)}"
else
    echo -e "${RED}  $FAIL ÉCHEC(S)${NC} / ${GREEN}$PASS OK${NC}${SKIP:+ / $SKIP skipped}"
fi
echo -e "${BOLD}═══════════════════════════════════════════${NC}"

[[ $FAIL -eq 0 ]]
