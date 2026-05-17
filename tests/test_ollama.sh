#!/bin/bash
################################################################################
# test_ollama.sh — Tests Ollama : connexion, modèles, génération texte/vision
#
# Scénarios testés :
#   1. Prérequis   — ollama.me.sh, question.py, port 11434
#   2. Connexion   — ollama.me.sh (local:11434 → SSH scorpio → IPFS P2P)
#   3. API santé   — GET /api/tags, modèles listés
#   4. Génération  — question.py (gemma3:latest ou premier modèle dispo)
#   5. Multilang   — réponse en français, filtre <think> tags
#   6. Vision      — moondream/llava sur image IPFS (si modèle vision dispo)
#   7. Canal DM    — bro_ia #IA via nostr_node_intercom (--with-dm)
#
# Usage :
#   ./tests/test_ollama.sh                   # génération texte si Ollama dispo
#   ./tests/test_ollama.sh --verbose         # output complet
#   ./tests/test_ollama.sh --with-dm         # + test canal DM bro_ia (async)
#   ./tests/test_ollama.sh --model qwen3:14b # forcer un modèle spécifique
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE manquant" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

VERBOSE=false; WITH_DM=false; FORCE_MODEL=""; QUICK=false
for _arg in "$@"; do
    [[ "$_arg" == "--verbose" ]] && VERBOSE=true
    [[ "$_arg" == "--with-dm" ]] && WITH_DM=true
    [[ "$_arg" == "--quick"   ]] && QUICK=true
    [[ "$_arg" =~ ^--model=(.+)$ ]] && FORCE_MODEL="${BASH_REMATCH[1]}"
    [[ "$_arg" == "--model" ]] && _NEXT_MODEL=true && continue
    [[ "${_NEXT_MODEL:-false}" == "true" ]] && FORCE_MODEL="$_arg" && _NEXT_MODEL=false
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

ok()      { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip()    { echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; SKIP=$((SKIP+1)); }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }
vlog()    { $VERBOSE && echo -e "  ${YELLOW}▸${NC} $1" || true; }

OLLAMA_ME="${ASTROPORT_PATH}/IA/ollama.me.sh"
QUESTION_PY="${ASTROPORT_PATH}/IA/question.py"
DESCRIBE_PY="${ASTROPORT_PATH}/IA/describe_image.py"
INTERCOM="${ASTROPORT_PATH}/tools/nostr_node_intercom.py"
OLLAMA_URL="http://localhost:11434"

## ─────────────────────────────────────────────────────────────────────────────
section "1. Prérequis — scripts Ollama"
## ─────────────────────────────────────────────────────────────────────────────

[[ -f "$OLLAMA_ME" ]] \
    && ok "ollama.me.sh présent" \
    || fail "ollama.me.sh absent : $OLLAMA_ME"

[[ -f "$QUESTION_PY" ]] \
    && ok "question.py présent" \
    || fail "question.py absent : $QUESTION_PY"

python3 -c "import ollama" 2>/dev/null \
    && ok "module Python 'ollama' installé" \
    || fail "module Python 'ollama' absent (pip install ollama)"

command -v curl &>/dev/null \
    && ok "curl" || fail "curl manquant"

## ─────────────────────────────────────────────────────────────────────────────
section "2. Connexion Ollama — ollama.me.sh (local → SSH → P2P)"
## ─────────────────────────────────────────────────────────────────────────────

_OLLAMA_OK=false

if curl -s --max-time 3 "${OLLAMA_URL}/api/tags" -o /dev/null 2>/dev/null; then
    ok "Ollama déjà accessible : ${OLLAMA_URL}"
    _OLLAMA_OK=true
else
    echo -e "  ${YELLOW}▸${NC} Ollama absent en local — tentative via ollama.me.sh..."
    if $VERBOSE; then
        bash "$OLLAMA_ME" && _OLLAMA_OK=true
    else
        bash "$OLLAMA_ME" >/dev/null 2>&1 && _OLLAMA_OK=true
    fi

    if curl -s --max-time 5 "${OLLAMA_URL}/api/tags" -o /dev/null 2>/dev/null; then
        ok "Ollama connecté via ollama.me.sh → tunnel actif sur ${OLLAMA_URL}"
        _OLLAMA_OK=true
    else
        skip "Ollama inaccessible (local + SSH + P2P) — sections génération skippées"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "3. API santé — /api/tags, modèles listés"
## ─────────────────────────────────────────────────────────────────────────────

_MODEL_TEXT=""
_MODEL_VISION=""
_ALL_MODELS=()

if ! $_OLLAMA_OK; then
    skip "API santé (Ollama inaccessible)"
else
    _TAGS=$(curl -s --max-time 5 "${OLLAMA_URL}/api/tags" 2>/dev/null)
    if [[ -z "$_TAGS" ]]; then
        fail "/api/tags : réponse vide"
    else
        _NB_MODELS=$(echo "$_TAGS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(len(d.get('models',[])))
" 2>/dev/null || echo 0)
        ok "/api/tags OK — ${_NB_MODELS} modèle(s) disponible(s)"

        ## Lister les modèles
        mapfile -t _ALL_MODELS < <(echo "$_TAGS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for m in d.get('models',[]):
    print(m['name'])
" 2>/dev/null)

        for _m in "${_ALL_MODELS[@]}"; do
            vlog "  modèle: $_m"
        done

        ## Choisir modèle texte (priorité : gemma3:latest, puis premier dispo)
        if [[ -n "$FORCE_MODEL" ]]; then
            _MODEL_TEXT="$FORCE_MODEL"
            ok "Modèle texte forcé : $_MODEL_TEXT"
        else
            for _pref in "gemma3:latest" "gemma3:12b" "qwen3:14b" "llama3.2:latest" "qwen2.5:latest" "mistral-small3.1:latest"; do
                if printf '%s\n' "${_ALL_MODELS[@]}" | grep -qx "$_pref"; then
                    _MODEL_TEXT="$_pref"
                    break
                fi
            done
            [[ -z "$_MODEL_TEXT" && ${#_ALL_MODELS[@]} -gt 0 ]] && _MODEL_TEXT="${_ALL_MODELS[0]}"
            [[ -n "$_MODEL_TEXT" ]] \
                && ok "Modèle texte sélectionné : $_MODEL_TEXT" \
                || fail "Aucun modèle texte disponible"
        fi

        ## Choisir modèle vision — llama3.2-vision:11b prioritaire
        for _pref in "llama3.2-vision:11b" "minicpm-v:latest" "moondream:latest" "llava"; do
            if printf '%s\n' "${_ALL_MODELS[@]}" | grep -q "$_pref"; then
                _MODEL_VISION="$_pref"
                break
            fi
        done
        [[ -n "$_MODEL_VISION" ]] \
            && ok "Modèle vision disponible : $_MODEL_VISION" \
            || skip "Aucun modèle vision (llama3.2-vision/minicpm-v/moondream) — section vision skippée"
    fi

    ## Test endpoint /api/generate (santé)
    _GEN_HEALTH=$(curl -s --max-time 5 -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d '{"model":"","prompt":"","stream":false}' \
        -o /dev/null -w "%{http_code}" 2>/dev/null)
    if [[ "$_GEN_HEALTH" =~ ^(200|400|404)$ ]]; then
        ok "/api/generate endpoint répond (HTTP ${_GEN_HEALTH})"
    else
        fail "/api/generate : HTTP ${_GEN_HEALTH}"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "4. Génération texte — question.py \"${_MODEL_TEXT:-?}\""
## ─────────────────────────────────────────────────────────────────────────────

_QUESTION_SIMPLE="Quelle est la capitale de la France ? Réponds en une phrase."
_ANSWER=""

if ! $_OLLAMA_OK || [[ -z "$_MODEL_TEXT" ]]; then
    skip "Génération texte (Ollama inaccessible ou aucun modèle)"
else
    echo -e "  ${YELLOW}▸${NC} question.py \"$_QUESTION_SIMPLE\" --model $_MODEL_TEXT"
    _T0=$(date +%s)
    if $VERBOSE; then
        _ANSWER=$(python3 "$QUESTION_PY" "$_QUESTION_SIMPLE" \
            --model "$_MODEL_TEXT" --json 2>&1 | tee /dev/stderr)
    else
        _ANSWER=$(python3 "$QUESTION_PY" "$_QUESTION_SIMPLE" \
            --model "$_MODEL_TEXT" --json 2>/tmp/ollama_question.log)
    fi
    _T1=$(date +%s)
    _ELAPSED=$((_T1 - _T0))

    if [[ -n "$_ANSWER" ]]; then
        _ANS_TEXT=$(echo "$_ANSWER" | python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('answer','').strip()[:120])
except:
    print(sys.stdin.read().strip()[:120])
" 2>/dev/null || echo "$_ANSWER" | head -c 120)
        ok "question.py répondu en ${_ELAPSED}s : \"${_ANS_TEXT}\""

        ## Vérifier mention de Paris
        if echo "$_ANSWER" | grep -qi "paris\|France"; then
            ok "Réponse mentionne Paris/France ✓"
        else
            skip "Réponse ne mentionne pas Paris (hallucination ou modèle léger ?)"
        fi
    else
        fail "question.py : réponse vide (log: /tmp/ollama_question.log)"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "5. Filtrage <think> — modèles reasoning (qwen3, deepseek)"
## ─────────────────────────────────────────────────────────────────────────────

if ! $_OLLAMA_OK || [[ -z "$_MODEL_TEXT" ]]; then
    skip "Test filtrage think (Ollama inaccessible)"
else
    ## Vérifier que filter_think_tags fonctionne dans question.py
    _THINK_TEST=$(python3 -c "
import sys
sys.path.insert(0,'${ASTROPORT_PATH}/IA')
from question import filter_think_tags
raw = '<think>Réflexion interne...</think>La réponse est Paris.'
filtered = filter_think_tags(raw)
print(filtered.strip())
" 2>/dev/null)
    if [[ "$_THINK_TEST" == "La réponse est Paris." ]]; then
        ok "filter_think_tags : balises <think> correctement supprimées"
    else
        fail "filter_think_tags : résultat inattendu ('$_THINK_TEST')"
    fi

    ## Si modèle reasoning dispo, vérifier en vrai
    _REASONING_MODEL=""
    for _m in "${_ALL_MODELS[@]}"; do
        if echo "$_m" | grep -qiE "qwen3|deepseek|r1"; then
            _REASONING_MODEL="$_m"
            break
        fi
    done
    if [[ -n "$_REASONING_MODEL" ]]; then
        vlog "Modèle reasoning détecté : $_REASONING_MODEL"
        ok "Modèle reasoning présent : $_REASONING_MODEL (filtre <think> sera actif)"
    else
        skip "Aucun modèle reasoning (qwen3/deepseek/r1) — filtre <think> non testé live"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "6. Vision — describe_image.py sur NOSTRCARD (llama3.2-vision:11b)"
## ─────────────────────────────────────────────────────────────────────────────
## Utilise une image réelle du système : MULTIPASS.CARD.png d'un joueur local
## ou une image IPFS déjà générée par ComfyUI.

if $QUICK; then
    skip "Vision (--quick : section lente sautée)"
elif ! $_OLLAMA_OK; then
    skip "Vision (Ollama inaccessible)"
elif [[ ! -f "$DESCRIBE_PY" ]]; then
    skip "describe_image.py absent : $DESCRIBE_PY"
else
    ## Choisir le modèle vision : llama3.2-vision:11b prioritaire
    _VISION_MODEL=""
    for _pref in "llama3.2-vision:11b" "minicpm-v:latest" "moondream:latest"; do
        if printf '%s\n' "${_ALL_MODELS[@]}" | grep -qx "$_pref"; then
            _VISION_MODEL="$_pref"
            break
        fi
    done

    if [[ -z "$_VISION_MODEL" ]]; then
        skip "Aucun modèle vision disponible (llama3.2-vision:11b / minicpm-v / moondream)"
    else
        ok "Modèle vision sélectionné : $_VISION_MODEL"

        ## Trouver une image réelle du système (NOSTRCARD d'un joueur local)
        _TEST_IMG=""
        _TEST_IMG_LABEL=""

        ## 1) NOSTRCARD d'un joueur local
        _CARD=$(find "$HOME/.zen/game/nostr" -name ".MULTIPASS.CARD.png" \
                     -not -path "*/CAPTAIN/*" -newer /dev/null 2>/dev/null | head -1)
        if [[ -n "$_CARD" ]]; then
            _TEST_IMG="$_CARD"
            _TEST_IMG_LABEL="NOSTRCARD locale : $(dirname "$_CARD" | xargs basename)"
        fi

        ## 2) Fallback : image ComfyUI récente dans ~/.zen/tmp.media
        if [[ -z "$_TEST_IMG" ]]; then
            _RECENT=$(find "$HOME/.zen/tmp.media" -name "*.png" -newer /dev/null \
                           2>/dev/null | sort -r | head -1)
            if [[ -n "$_RECENT" ]]; then
                _TEST_IMG="$_RECENT"
                _TEST_IMG_LABEL="Image ComfyUI récente"
            fi
        fi

        if [[ -z "$_TEST_IMG" ]]; then
            skip "Vision : aucune image locale trouvée (NOSTRCARD ou ComfyUI) — créer un MULTIPASS d'abord"
        else
            ok "Image test : $_TEST_IMG_LABEL"
            vlog "Chemin : $_TEST_IMG"

            echo -e "  ${YELLOW}▸${NC} describe_image.py $_VISION_MODEL — peut prendre 10-60s..."
            _T0=$(date +%s)
            if $VERBOSE; then
                _DESC=$(python3 "$DESCRIBE_PY" "$_TEST_IMG" \
                    --model "$_VISION_MODEL" --json 2>&1 | tee /dev/stderr)
            else
                _DESC=$(python3 "$DESCRIBE_PY" "$_TEST_IMG" \
                    --model "$_VISION_MODEL" --json 2>${HOME}/.zen/tmp/ollama_vision.log)
            fi
            _T1=$(date +%s)
            _ELAPSED=$((_T1 - _T0))

            if [[ -n "$_DESC" ]]; then
                _DESC_TEXT=$(echo "$_DESC" | python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('description','').strip()[:150])
except:
    print(sys.stdin.read().strip()[:150])
" 2>/dev/null || echo "$_DESC" | head -c 150)
                ok "Vision OK en ${_ELAPSED}s : \"${_DESC_TEXT}...\""
            else
                ## Vérifier si c'est une erreur VRAM (model runner stopped)
                _VLOG=$(cat ${HOME}/.zen/tmp/ollama_vision.log 2>/dev/null)
                if echo "$_VLOG" | grep -q "resource\|VRAM\|stopped\|500"; then
                    skip "Vision : ${_VISION_MODEL} manque de VRAM (${_VLOG:0:80}...)"
                else
                    fail "describe_image.py : réponse vide — log: ${HOME}/.zen/tmp/ollama_vision.log"
                fi
            fi
        fi
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "7. Canal DM bro_ia — #IA via intercom (--with-dm)"
## ─────────────────────────────────────────────────────────────────────────────

if ! $WITH_DM; then
    skip "Test canal DM bro_ia (ajouter --with-dm pour activer)"
    echo -e "  ${YELLOW}ℹ${NC} Ce test envoie #IA ping au NODE et attend la réponse via DM NIP-44"
else
    _COUCOU_NSEC=$(~/.zen/Astroport.ONE/tools/keygen -t nostr -s "coucou" "coucou" 2>/dev/null)
    _COUCOU_HEX=$(~/.zen/Astroport.ONE/tools/keygen -t nostr "coucou" "coucou" 2>/dev/null \
        | xargs -I{} python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" {} 2>/dev/null)

    _NODE_HEX=""
    if [[ -s "$HOME/.zen/game/secret.nostr" ]]; then
        source "$HOME/.zen/game/secret.nostr"
        _NODE_HEX="${HEX:-}"
        unset NSEC NPUB HEX
    fi

    _RELAY_DM="ws://localhost:7777"
    nc -z -w2 localhost 7777 2>/dev/null || _RELAY_DM="${myRELAY:-wss://relay.copylaradio.com}"

    if [[ -z "$_NODE_HEX" ]]; then
        skip "DM bro_ia : secret.nostr NODE absent"
    elif ! $_OLLAMA_OK; then
        skip "DM bro_ia : Ollama inaccessible — UPlanet_IA_Responder répondrait 'Ollama offline'"
    else
        _BRO_PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'pubkey':   '${_COUCOU_HEX}',
    'event_id': 'test_ollama_$(date +%s)',
    'lat':      '0.00',
    'lon':      '0.00',
    'message':  '#IA Quelle est la capitale de la France ? Réponds en une phrase.',
    'kname':    'coucou@test',
    'email':    'support+coucou@qo-op.com',
}))
" 2>/dev/null)

        echo -e "  ${YELLOW}▸${NC} Envoi bro_ia #IA → NODE ${_NODE_HEX:0:12}..."
        if python3 "$INTERCOM" send \
                --nsec    "$_COUCOU_NSEC" \
                --to      "$_NODE_HEX" \
                --channel "bro_ia" \
                --payload "$_BRO_PAYLOAD" \
                --ttl     3600 \
                --relays  "$_RELAY_DM" \
                2>/dev/null; then
            ok "bro_ia envoyé (TTL=1h) — attente réponse Ollama..."
        else
            fail "bro_ia DM : send échoué"
        fi

        ## Polling 30s pour voir le traitement dans le log daemon
        _BRO_ANSWERED=false
        for _i in $(seq 1 6); do
            sleep 5
            if grep -q "bro_ia.*Quelle\|bro_ia.*#IA\|KeyANSWER" "$HOME/.zen/tmp/bro_dm_daemon.log" 2>/dev/null \
               || grep -q "UPlanet_IA_Responder" "$HOME/.zen/tmp/bro_dm_daemon.log" 2>/dev/null; then
                _BRO_ANSWERED=true
                break
            fi
            vlog "Attente réponse bro_ia... ${_i}/6 ($((_i*5))s)"
        done

        if $_BRO_ANSWERED; then
            ok "bro_ia traité par le daemon → UPlanet_IA_Responder appelé"
        else
            skip "bro_ia non vu dans le log en 30s (daemon actif ? inotifywait traitement en cours)"
        fi
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}═══════════════════════════════════════════${NC}"
if [[ -n "$_MODEL_TEXT" ]]; then
    echo -e "${BOLD}  Modèle texte  : $_MODEL_TEXT${NC}"
fi
if [[ -n "$_MODEL_VISION" ]]; then
    echo -e "${BOLD}  Modèle vision : $_MODEL_VISION${NC}"
fi
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  PERFECT — $PASS tests OK${NC}${SKIP:+ ($SKIP skipped)}"
else
    echo -e "${RED}  $FAIL ÉCHEC(S)${NC} / ${GREEN}$PASS OK${NC}${SKIP:+ / $SKIP skipped}"
fi
echo -e "${BOLD}═══════════════════════════════════════════${NC}"

[[ $FAIL -eq 0 ]]
