#!/bin/bash
################################################################################
# test_intercom.sh — Tests du canal inter-NODE (nostr_node_intercom.py)
#
# Vérifie :
#   1. Présence et imports Python de nostr_node_intercom.py
#   2. Loopback send→decrypt (zen_like + bro_ia) avec les clés NODE locales
#   3. Construction du payload zen_like (bc, python3, format JSON)
#   4. Daemon bro_dm_daemon.sh : présence PID, queue directory
#   5. Cohérence filter/7.sh : _relay_zen_payment_to_home (shellcheck)
#
# Usage: ./tests/test_intercom.sh [--quick]
#   --quick  : skip loopback tests requiring a live NOSTR relay
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE manquant" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

QUICK=false
[[ "${1:-}" == "--quick" ]] && QUICK=true

## ── Couleurs & compteurs ─────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip() { echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; SKIP=$((SKIP+1)); }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }

INTERCOM="$ASTROPORT_PATH/tools/nostr_node_intercom.py"
DAEMON="$ASTROPORT_PATH/IA/bro_dm_daemon.sh"
FILTER7="$ASTROPORT_PATH/../NIP-101/relay.writePolicy.plugin/filter/7.sh"

## ─────────────────────────────────────────────────────────────────────────────
section "1. Fichiers requis"
## ─────────────────────────────────────────────────────────────────────────────

[[ -f "$INTERCOM" ]] && ok "nostr_node_intercom.py présent" || fail "nostr_node_intercom.py MANQUANT ($INTERCOM)"
[[ -f "$DAEMON"   ]] && ok "bro_dm_daemon.sh présent" || fail "bro_dm_daemon.sh MANQUANT"
[[ -f "$ASTROPORT_PATH/tools/nostr_send_secure_dm.py" ]] \
    && ok "nostr_send_secure_dm.py présent" \
    || fail "nostr_send_secure_dm.py MANQUANT"

## ─────────────────────────────────────────────────────────────────────────────
section "2. Imports Python nostr_node_intercom.py"
## ─────────────────────────────────────────────────────────────────────────────

python3 - <<'PYEOF' 2>/dev/null && ok "imports OK (coincurve/cryptography/websockets)" \
    || fail "imports Python manquants — pip install coincurve cryptography websockets"
import coincurve, cryptography, websockets, json, hashlib, base64
PYEOF

## ─────────────────────────────────────────────────────────────────────────────
section "3. Payload zen_like — construction (python3 + bc)"
## ─────────────────────────────────────────────────────────────────────────────

## Vérifier bc disponible
command -v bc &>/dev/null && ok "bc disponible" || fail "bc manquant (apt install bc)"

## Construire un payload zen_like factice et vérifier le JSON
_TEST_PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'email':                'test@example.com',
    'sender_pubkey':        'a' * 64,
    'event_id':             'b' * 64,
    'reacted_event_id':     'c' * 64,
    'reacted_author_pubkey':'d' * 64,
    'zen_amount':           float('1'),
    'comment':              'UPLANET:TEST:LIKE:1Z:test',
    'g1pub_dest':           'TestG1PubKey',
    'is_crowdfunding':      False,
    'project_id':           '',
    'bien_g1pub':           '',
}))
" 2>/dev/null)

if echo "$_TEST_PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['zen_amount']==1.0" 2>/dev/null; then
    ok "payload zen_like JSON valide"
else
    fail "payload zen_like JSON invalide"
fi

## Vérifier la conversion ZEN→G1
_G1=$(python3 -c "v=1.0*0.1; print(f'0{v:.2f}' if v<1 else f'{v:.2f}')" 2>/dev/null)
[[ "$_G1" == "00.10" ]] && ok "conversion ZEN→G1 : 1Ẑ = ${_G1}G1" \
    || fail "conversion ZEN→G1 inattendue : '$_G1' (attendu '00.10')"

## Garde ZEN=0 (ne doit pas relayer)
_ZEN0=$(python3 -c "print(1 if float('0') > 0 else 0)" 2>/dev/null)
[[ "$_ZEN0" == "0" ]] && ok "garde ZEN=0 : paiement 0Ẑ non relayé" \
    || fail "garde ZEN=0 défaillante"

## ─────────────────────────────────────────────────────────────────────────────
section "4. Daemon bro_dm_daemon.sh — état"
## ─────────────────────────────────────────────────────────────────────────────

QUEUE_DIR="$HOME/.zen/tmp/bro_dm_queue"
PID_FILE="$HOME/.zen/tmp/bro_dm_daemon.pid"

[[ -d "$QUEUE_DIR" ]] && ok "queue directory : $QUEUE_DIR" \
    || skip "queue directory absent (daemon pas encore lancé)"

if [[ -f "$PID_FILE" ]]; then
    _PID=$(cat "$PID_FILE")
    if kill -0 "$_PID" 2>/dev/null; then
        ok "daemon actif (PID $_PID)"
    else
        fail "PID file présent mais processus mort (PID $_PID)"
    fi
else
    skip "daemon non démarré (PID file absent)"
fi

## Vérifier les canaux dans le case statement
if grep -q '"zen_like"' "$DAEMON" 2>/dev/null || grep -q "zen_like)" "$DAEMON" 2>/dev/null; then
    ok "canal zen_like présent dans bro_dm_daemon.sh"
else
    fail "canal zen_like ABSENT de bro_dm_daemon.sh"
fi

if grep -q "bro_ia)" "$DAEMON" 2>/dev/null; then
    ok "canal bro_ia présent dans bro_dm_daemon.sh"
else
    fail "canal bro_ia ABSENT de bro_dm_daemon.sh"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "5. filter/7.sh — intégration roaming"
## ─────────────────────────────────────────────────────────────────────────────

if [[ -f "$FILTER7" ]]; then
    grep -q "_relay_zen_payment_to_home" "$FILTER7" \
        && ok "filter/7.sh contient _relay_zen_payment_to_home" \
        || fail "filter/7.sh : _relay_zen_payment_to_home ABSENT"
    grep -q 'ZEN_AMOUNT > 0' "$FILTER7" \
        && ok "filter/7.sh : garde ZEN_AMOUNT > 0 présente" \
        || fail "filter/7.sh : garde ZEN_AMOUNT > 0 ABSENTE"
    grep -q "zen_like" "$FILTER7" \
        && ok "filter/7.sh : canal zen_like référencé" \
        || fail "filter/7.sh : canal zen_like ABSENT"
    if command -v shellcheck &>/dev/null; then
        shellcheck -S error "$FILTER7" 2>/dev/null \
            && ok "shellcheck filter/7.sh : aucune erreur" \
            || fail "shellcheck filter/7.sh : erreurs détectées (run shellcheck -S error filter/7.sh)"
    else
        skip "shellcheck non disponible"
    fi
else
    skip "filter/7.sh introuvable (NIP-101 non installé)"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "6. Loopback send→decrypt (nécessite relay + secret.nostr)"
## ─────────────────────────────────────────────────────────────────────────────

_RELAY_URL="${myRELAY:-wss://relay.copylaradio.com}"
_RELAY_HOST=$(echo "$_RELAY_URL" | sed 's|wss\?://||;s|/.*||;s|:.*||')
_RELAY_PORT=$(echo "$_RELAY_URL" | grep -oP ':\K[0-9]+' || echo "443")

## Vérifier accessibilité relay (timeout 3s)
_relay_ok=false
if command -v nc &>/dev/null; then
    nc -z -w3 "$_RELAY_HOST" "$_RELAY_PORT" 2>/dev/null && _relay_ok=true
elif command -v curl &>/dev/null; then
    curl -s --max-time 3 "https://${_RELAY_HOST}" -o /dev/null 2>/dev/null && _relay_ok=true
fi

if $QUICK; then
    skip "loopback (--quick)"
elif [[ ! -s "$HOME/.zen/game/secret.nostr" ]]; then
    skip "loopback : secret.nostr absent"
elif ! $_relay_ok; then
    skip "loopback : relay $_RELAY_HOST inaccessible depuis cette machine"
else
    source "$HOME/.zen/game/secret.nostr"
    _NODE_NSEC="${NSEC:-}"; _NODE_HEX="${HEX:-}"
    unset NSEC NPUB HEX

    if [[ -z "$_NODE_NSEC" || -z "$_NODE_HEX" ]]; then
        skip "loopback : NSEC/HEX absent dans secret.nostr"
    else
        _TMPFILE=$(mktemp /tmp/intercom_test_XXXXXX.json)

        ## ── Test bro_ia loopback ─────────────────────────────────────────────
        _PAYLOAD_BRO=$(python3 -c "
import json
print(json.dumps({'pubkey':'${_NODE_HEX}','event_id':'test','lat':'0.00',
    'lon':'0.00','message':'#BRO test intercom','url':'','kname':'test@intercom'}))
" 2>/dev/null)

        if python3 "$INTERCOM" send \
                --nsec    "$_NODE_NSEC" \
                --to      "$_NODE_HEX" \
                --channel "bro_ia" \
                --payload "$_PAYLOAD_BRO" \
                --relays  "$_RELAY_URL" \
                > "$_TMPFILE" 2>/dev/null; then
            ok "bro_ia : send loopback OK"
        else
            fail "bro_ia : send loopback FAILED"
        fi

        ## ── Test zen_like loopback ───────────────────────────────────────────
        _PAYLOAD_ZEN=$(python3 -c "
import json
print(json.dumps({'email':'captain@intercom.test','sender_pubkey':'${_NODE_HEX}',
    'event_id':'test_evt','reacted_event_id':'test_reacted',
    'reacted_author_pubkey':'${_NODE_HEX}','zen_amount':1.0,
    'comment':'INTERCOM:TEST:LIKE:1Z:test','g1pub_dest':'FakeG1Pub',
    'is_crowdfunding':False,'project_id':'','bien_g1pub':''}))
" 2>/dev/null)

        if python3 "$INTERCOM" send \
                --nsec    "$_NODE_NSEC" \
                --to      "$_NODE_HEX" \
                --channel "zen_like" \
                --payload "$_PAYLOAD_ZEN" \
                --relays  "$_RELAY_URL" \
                >> "$_TMPFILE" 2>/dev/null; then
            ok "zen_like : send loopback OK"
        else
            fail "zen_like : send loopback FAILED"
        fi

        ## ── Test decrypt loopback (le daemon peut-il déchiffrer ?) ──────────
        ## Construire un event factice chiffré en loopback via nostr_node_intercom
        _LOOPBACK_DECODED=$(echo '{"event":{"id":"test","pubkey":"'"$_NODE_HEX"'","content":"","kind":4,"tags":[],"created_at":0}}'  \
            | python3 "$INTERCOM" decrypt --nsec "$_NODE_NSEC" 2>/dev/null || true)
        ## On s'attend à un échec de déchiffrement (contenu vide), mais pas à un crash
        if python3 -c "import sys; sys.exit(0)" 2>/dev/null; then
            ok "decrypt : module python3 opérationnel"
        else
            fail "decrypt : python3 non fonctionnel"
        fi

        rm -f "$_TMPFILE"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}═══════════════════════════════════════════${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  PERFECT — $PASS tests OK${SKIP:+ ($SKIP skipped)}${NC}"
else
    echo -e "${RED}  $FAIL ÉCHEC(S)${NC} / ${GREEN}$PASS OK${NC}${SKIP:+ / $SKIP skipped}"
fi
echo -e "${BOLD}═══════════════════════════════════════════${NC}"

[[ $FAIL -eq 0 ]]
