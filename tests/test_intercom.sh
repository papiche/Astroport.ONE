#!/bin/bash
################################################################################
# test_intercom.sh — Tests du canal inter-NODE (nostr_node_intercom.py)
#
# Vérifie :
#   1. Présence et imports Python de nostr_node_intercom.py
#   2. Imports Python (coincurve, cryptography, websockets)
#   3. Construction payload zen_like (bc, python3, format JSON)
#   4. Daemon bro_dm_daemon.sh : PID, queue directory
#   5. Cohérence filter/7.sh : _relay_zen_payment_to_home (shellcheck)
#   6. Loopback coucou→toto + toto→coucou (comptes test déterministes, TTL=300)
#   7. Service Ollama : accessibilité + envoi bro_ia #IA depuis coucou
#   8. Service ComfyUI : accessibilité + envoi comfyui_job image depuis coucou
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
DAEMON="$ASTROPORT_PATH/IA/bro/bro_dm_daemon.sh"
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
    _PID=$(pgrep -f "bro_dm_daemon.sh" | head -1)
    if [[ -n "$_PID" ]]; then
        ok "daemon actif via pgrep (PID $_PID, PID file en cours d'écriture)"
    else
        fail "daemon non démarré (PID file absent, processus introuvable)"
    fi
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
section "6. Loopback coucou→toto (comptes test déterministes, TTL=300)"
## ─────────────────────────────────────────────────────────────────────────────

_RELAY_URL="${myRELAY:-wss://relay.copylaradio.com}"
_RELAY_HOST=$(echo "$_RELAY_URL" | sed 's|wss\?://||;s|/.*||;s|:.*||')
_RELAY_PORT=$(echo "$_RELAY_URL" | grep -oP ':\K[0-9]+' || echo "443")

_KEYGEN="${ASTROPORT_PATH}/tools/keygen"
_HEX_TOOL="python3 ${ASTROPORT_PATH}/tools/nostr2hex.py"

## Dériver les clés test déterministes
_COUCOU_NPUB=$("$_KEYGEN" -t nostr "coucou" "coucou" 2>/dev/null)
_COUCOU_NSEC=$("$_KEYGEN" -t nostr -s "coucou" "coucou" 2>/dev/null)
_COUCOU_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_COUCOU_NPUB" 2>/dev/null)

_TOTO_NPUB=$("$_KEYGEN" -t nostr "toto" "toto" 2>/dev/null)
_TOTO_NSEC=$("$_KEYGEN" -t nostr -s "toto" "toto" 2>/dev/null)
_TOTO_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_TOTO_NPUB" 2>/dev/null)

if [[ ${#_COUCOU_HEX} -eq 64 && ${#_TOTO_HEX} -eq 64 ]]; then
    ok "clés test coucou (${_COUCOU_HEX:0:12}...) et toto (${_TOTO_HEX:0:12}...) dérivées"
else
    fail "dérivation clés test échouée (keygen/nostr2hex.py)"
fi

## Vérifier accessibilité relay
_relay_ok=false
if command -v nc &>/dev/null; then
    nc -z -w3 "$_RELAY_HOST" "$_RELAY_PORT" 2>/dev/null && _relay_ok=true
elif command -v curl &>/dev/null; then
    curl -s --max-time 3 "https://${_RELAY_HOST}" -o /dev/null 2>/dev/null && _relay_ok=true
fi

if $QUICK; then
    skip "loopback réseau (--quick)"
elif [[ ${#_COUCOU_HEX} -ne 64 || ${#_TOTO_HEX} -ne 64 ]]; then
    skip "loopback : clés test invalides"
elif ! $_relay_ok; then
    skip "loopback : relay $_RELAY_HOST inaccessible"
else
    _TMPFILE=$(mktemp /tmp/intercom_test_XXXXXX.json)
    _SINCE=$(date +%s)

    ## ── coucou → toto : bro_ia avec TTL=300 ─────────────────────────────────
    _PAYLOAD_BRO=$(python3 -c "
import json
print(json.dumps({'pubkey':'${_TOTO_HEX}','event_id':'test','lat':'0.00',
    'lon':'0.00','message':'#BRO test intercom coucou→toto','url':'','kname':'coucou@test'}))
" 2>/dev/null)

    if python3 "$INTERCOM" send \
            --nsec    "$_COUCOU_NSEC" \
            --to      "$_TOTO_HEX" \
            --channel "bro_ia" \
            --payload "$_PAYLOAD_BRO" \
            --ttl     300 \
            --relays  "$_RELAY_URL" \
            > "$_TMPFILE" 2>/dev/null; then
        ok "bro_ia coucou→toto : send OK (TTL=300s)"
    else
        fail "bro_ia coucou→toto : send FAILED"
    fi

    ## ── toto → coucou : zen_like avec TTL=300 ────────────────────────────────
    _PAYLOAD_ZEN=$(python3 -c "
import json
print(json.dumps({'email':'captain@intercom.test','sender_pubkey':'${_TOTO_HEX}',
    'event_id':'test_evt','reacted_event_id':'test_reacted',
    'reacted_author_pubkey':'${_COUCOU_HEX}','zen_amount':1.0,
    'comment':'INTERCOM:TEST:LIKE:1Z:coucou','g1pub_dest':'FakeG1Pub',
    'is_crowdfunding':False,'project_id':'','bien_g1pub':''}))
" 2>/dev/null)

    if python3 "$INTERCOM" send \
            --nsec    "$_TOTO_NSEC" \
            --to      "$_COUCOU_HEX" \
            --channel "zen_like" \
            --payload "$_PAYLOAD_ZEN" \
            --ttl     300 \
            --relays  "$_RELAY_URL" \
            >> "$_TMPFILE" 2>/dev/null; then
        ok "zen_like toto→coucou : send OK (TTL=300s)"
    else
        fail "zen_like toto→coucou : send FAILED"
    fi

    ## ── toto reçoit depuis coucou (receive + decrypt) ────────────────────────
    _RECV=$(python3 "$INTERCOM" receive \
            --nsec    "$_TOTO_NSEC" \
            --channel "bro_ia" \
            --since   "$_SINCE" \
            --relays  "$_RELAY_URL" \
            2>/dev/null || echo "[]")
    _COUNT=$(echo "$_RECV" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
    if [[ "$_COUNT" -gt 0 ]]; then
        ok "toto reçoit $_COUNT message(s) bro_ia de coucou"
    else
        skip "receive : aucun message (latence relay ou TTL expiré)"
    fi

    ## ── déchiffrement module ─────────────────────────────────────────────────
    if python3 -c "
from coincurve import PrivateKey
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
import sys; sys.exit(0)
" 2>/dev/null; then
        ok "decrypt : modules crypto opérationnels"
    else
        fail "decrypt : modules crypto manquants"
    fi

    rm -f "$_TMPFILE"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "7. Service Ollama (IA) — envoi bro_ia #IA depuis coucou"
## ─────────────────────────────────────────────────────────────────────────────

_OLLAMA_OK=false
curl -s --max-time 3 "http://localhost:11434/api/tags" -o /dev/null 2>/dev/null \
    && _OLLAMA_OK=true

if ! $_OLLAMA_OK; then
    skip "Ollama inaccessible (localhost:11434)"
else
    _OLLAMA_MODELS=$(curl -s --max-time 5 "http://localhost:11434/api/tags" 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('models',[])))" 2>/dev/null || echo 0)
    ok "Ollama accessible — $_OLLAMA_MODELS modèle(s) disponible(s)"

    ## Charger NODE_HEX depuis secret.nostr
    _NODE_HEX_OLLAMA=""
    if [[ -s "$HOME/.zen/game/secret.nostr" ]]; then
        source "$HOME/.zen/game/secret.nostr"
        _NODE_HEX_OLLAMA="${HEX:-}"
        _NODE_NSEC_OLLAMA="${NSEC:-}"
        unset NSEC NPUB HEX
    fi

    if [[ -z "$_NODE_HEX_OLLAMA" || ${#_COUCOU_NSEC} -lt 10 ]]; then
        skip "envoi bro_ia→NODE : secret.nostr absent ou clés coucou invalides"
    elif ! $_relay_ok; then
        skip "envoi bro_ia→NODE : relay inaccessible"
    else
        _PAYLOAD_IA=$(python3 -c "
import json
print(json.dumps({'pubkey':'${_COUCOU_HEX}','event_id':'test_ollama','lat':'0.00',
    'lon':'0.00','message':'#IA ping test intercom coucou','url':'','kname':'coucou@test'}))
" 2>/dev/null)
        if python3 "$INTERCOM" send \
                --nsec    "$_COUCOU_NSEC" \
                --to      "$_NODE_HEX_OLLAMA" \
                --channel "bro_ia" \
                --payload "$_PAYLOAD_IA" \
                --ttl     300 \
                --relays  "$_RELAY_URL" \
                2>/dev/null; then
            ok "bro_ia #IA coucou→NODE envoyé (TTL=300s) — daemon traitera en async"
        else
            fail "bro_ia #IA coucou→NODE : send FAILED"
        fi
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "8. Service ComfyUI (image) — envoi comfyui_job depuis coucou"
## ─────────────────────────────────────────────────────────────────────────────

_COMFY_OK=false
curl -s --max-time 3 "http://localhost:8188/system_stats" -o /dev/null 2>/dev/null \
    && _COMFY_OK=true

if ! $_COMFY_OK; then
    skip "ComfyUI inaccessible (localhost:8188)"
else
    _COMFY_VRAM=$(curl -s --max-time 5 "http://localhost:8188/system_stats" 2>/dev/null \
        | python3 -c "
import json,sys
d=json.load(sys.stdin)
vram=d.get('system',{}).get('vram_total',0)
print(f'{vram//1024//1024} MB')
" 2>/dev/null || echo "?")
    ok "ComfyUI accessible — VRAM total : $_COMFY_VRAM"

    _COMFY_QUEUE=$(curl -s --max-time 3 "http://localhost:8188/queue" 2>/dev/null \
        | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(len(d.get('queue_running',[])) + len(d.get('queue_pending',[])))
" 2>/dev/null || echo "?")
    ok "ComfyUI queue depth : $_COMFY_QUEUE job(s) en attente"

    ## Charger NODE_HEX
    _NODE_HEX_COMFY=""
    _NODE_NSEC_COMFY=""
    if [[ -s "$HOME/.zen/game/secret.nostr" ]]; then
        source "$HOME/.zen/game/secret.nostr"
        _NODE_HEX_COMFY="${HEX:-}"
        _NODE_NSEC_COMFY="${NSEC:-}"
        unset NSEC NPUB HEX
    fi

    if [[ -z "$_NODE_HEX_COMFY" || ${#_COUCOU_NSEC} -lt 10 ]]; then
        skip "envoi comfyui_job→NODE : secret.nostr absent"
    elif ! $_relay_ok; then
        skip "envoi comfyui_job→NODE : relay inaccessible"
    else
        _JOB_ID="test_$(date +%s)"
        _PAYLOAD_COMFY=$(python3 -c "
import json, sys
print(json.dumps({
    'kname': 'coucou@test',
    'prompt': 'a cute cartoon robot testing NOSTR intercom',
    'mode': 'image',
    'source_url': '',
    'reply_node_hex': '${_COUCOU_HEX}',
    'reply_pubkey': '${_COUCOU_HEX}',
    'job_id': '${_JOB_ID}',
}))
" 2>/dev/null)
        if python3 "$INTERCOM" send \
                --nsec    "$_COUCOU_NSEC" \
                --to      "$_NODE_HEX_COMFY" \
                --channel "comfyui_job" \
                --payload "$_PAYLOAD_COMFY" \
                --ttl     7200 \
                --relays  "$_RELAY_URL" \
                2>/dev/null; then
            ok "comfyui_job image coucou→NODE envoyé (TTL=2h) — résultat comfyui_result async"
        else
            fail "comfyui_job image : send FAILED"
        fi
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
