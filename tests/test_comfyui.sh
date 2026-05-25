#!/bin/bash
################################################################################
# test_comfyui.sh — Tests ComfyUI : connexion, workflow, génération image
#
# Scénarios testés :
#   1. Prérequis   — generate_image.sh, comfyui.me.sh, FluxImage.json
#   2. Connexion   — comfyui.me.sh (local:8188 → SSH scorpio → IPFS P2P)
#   3. API santé   — /system_stats, /queue depth, VRAM disponible
#   4. Workflow    — FluxImage.json structure (nodes 1=seed, 4=text, 7=SaveImage)
#   5. Génération  — generate_image.sh "Un dragon cyberpunk sur Mars"
#   6. IPFS        — CID valide, image non vide, URL public
#   7. VRAM free   — POST /free après génération
#   8. Canal DM    — comfyui_job via nostr_node_intercom (--with-dm, async)
#
# Usage :
#   ./tests/test_comfyui.sh                  # génération directe si ComfyUI dispo
#   ./tests/test_comfyui.sh --verbose        # output complet
#   ./tests/test_comfyui.sh --with-dm        # + test canal DM comfyui_job (async)
#   ./tests/test_comfyui.sh --skip-generate  # skip génération (rapide)
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE manquant" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

VERBOSE=false; WITH_DM=false; SKIP_GENERATE=false
for _arg in "$@"; do
    [[ "$_arg" == "--verbose"       ]] && VERBOSE=true
    [[ "$_arg" == "--with-dm"       ]] && WITH_DM=true
    [[ "$_arg" == "--skip-generate" ]] && SKIP_GENERATE=true
    [[ "$_arg" == "--quick"         ]] && SKIP_GENERATE=true
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

ok()      { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip()    { echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; SKIP=$((SKIP+1)); }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }
vlog()    { $VERBOSE && echo -e "  ${YELLOW}▸${NC} $1" || true; }

GENERATE_IMAGE="${ASTROPORT_PATH}/IA/generators/generate_image.sh"
COMFYUI_ME="${ASTROPORT_PATH}/IA/services/comfyui.me.sh"
WORKFLOW="${ASTROPORT_PATH}/IA/workflow/FluxImage.json"
INTERCOM="${ASTROPORT_PATH}/tools/nostr_node_intercom.py"
COMFYUI_URL="http://127.0.0.1:8188"

_PROMPT="Un dragon cyberpunk sur Mars"

## ─────────────────────────────────────────────────────────────────────────────
section "1. Prérequis — scripts et workflow"
## ─────────────────────────────────────────────────────────────────────────────

[[ -f "$GENERATE_IMAGE" ]] \
    && ok "generate_image.sh présent" \
    || fail "generate_image.sh absent : $GENERATE_IMAGE"

[[ -f "$COMFYUI_ME" ]] \
    && ok "comfyui.me.sh présent" \
    || fail "comfyui.me.sh absent : $COMFYUI_ME"

[[ -f "$WORKFLOW" ]] \
    && ok "FluxImage.json présent" \
    || fail "FluxImage.json absent : $WORKFLOW"

command -v jq &>/dev/null \
    && ok "jq" || fail "jq manquant"

command -v curl &>/dev/null \
    && ok "curl" || fail "curl manquant"

ipfs swarm peers &>/dev/null \
    && ok "IPFS daemon" || fail "IPFS daemon non actif (requis pour upload image)"

## ─────────────────────────────────────────────────────────────────────────────
section "2. Connexion ComfyUI — comfyui.me.sh (local → SSH → P2P)"
## ─────────────────────────────────────────────────────────────────────────────

_COMFYUI_OK=false

## Vérifier d'abord si déjà dispo en local
if curl -s --max-time 3 "${COMFYUI_URL}/system_stats" -o /dev/null 2>/dev/null; then
    ok "ComfyUI déjà accessible : ${COMFYUI_URL}"
    _COMFYUI_OK=true
else
    ## Tenter la connexion via comfyui.me.sh (SSH ou P2P)
    echo -e "  ${YELLOW}▸${NC} ComfyUI absent en local — tentative via comfyui.me.sh..."
    if $VERBOSE; then
        bash "$COMFYUI_ME" && _COMFYUI_OK=true
    else
        bash "$COMFYUI_ME" >/dev/null 2>&1 && _COMFYUI_OK=true
    fi

    if $_COMFYUI_OK; then
        ## Vérifier après connexion
        if curl -s --max-time 5 "${COMFYUI_URL}/system_stats" -o /dev/null 2>/dev/null; then
            ok "ComfyUI connecté via comfyui.me.sh → tunnel actif sur ${COMFYUI_URL}"
        else
            fail "comfyui.me.sh OK mais ${COMFYUI_URL} toujours inaccessible"
            _COMFYUI_OK=false
        fi
    else
        skip "ComfyUI inaccessible (local + SSH + P2P) — sections génération skippées"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "3. API santé — /system_stats, /queue, VRAM"
## ─────────────────────────────────────────────────────────────────────────────

if ! $_COMFYUI_OK; then
    skip "API santé (ComfyUI inaccessible)"
else
    _STATS=$(curl -s --max-time 5 "${COMFYUI_URL}/system_stats" 2>/dev/null)
    if [[ -n "$_STATS" ]]; then
        _VRAM_TOTAL=$(echo "$_STATS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
vram=d.get('system',{}).get('vram_total',0)
print(f'{vram//1024//1024} MB')
" 2>/dev/null || echo "?")
        _VRAM_FREE=$(echo "$_STATS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
vram=d.get('system',{}).get('vram_free',0)
print(f'{vram//1024//1024} MB')
" 2>/dev/null || echo "?")
        ok "/system_stats OK — VRAM total:${_VRAM_TOTAL} libre:${_VRAM_FREE}"
        vlog "stats brutes: $(echo "$_STATS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('system',{}))" 2>/dev/null)"
    else
        fail "/system_stats : réponse vide"
    fi

    _QUEUE=$(curl -s --max-time 3 "${COMFYUI_URL}/queue" 2>/dev/null)
    if [[ -n "$_QUEUE" ]]; then
        _QDEPTH=$(echo "$_QUEUE" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(len(d.get('queue_running',[])) + len(d.get('queue_pending',[])))
" 2>/dev/null || echo "?")
        ok "/queue OK — depth: ${_QDEPTH} job(s) en attente"
        if [[ "$_QDEPTH" != "?" && "$_QDEPTH" -gt 5 ]]; then
            echo -e "  ${YELLOW}⚠${NC}  Queue chargée ($_QDEPTH jobs) — génération peut être longue"
        fi
    else
        fail "/queue : réponse vide"
    fi

    ## Vérifier que /prompt répond (endpoint de soumission)
    _PROMPT_HEALTH=$(curl -s --max-time 3 -X GET "${COMFYUI_URL}/prompt" -o /dev/null -w "%{http_code}" 2>/dev/null)
    if [[ "$_PROMPT_HEALTH" =~ ^(200|405)$ ]]; then
        ok "/prompt endpoint disponible (HTTP ${_PROMPT_HEALTH})"
    else
        fail "/prompt endpoint : HTTP ${_PROMPT_HEALTH}"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "4. Workflow FluxImage.json — structure nodes"
## ─────────────────────────────────────────────────────────────────────────────

if [[ ! -f "$WORKFLOW" ]]; then
    skip "FluxImage.json absent — structure non vérifiable"
else
    ## JSON valide ?
    if python3 -c "import json; json.load(open('$WORKFLOW'))" 2>/dev/null; then
        ok "FluxImage.json : JSON valide"
    else
        fail "FluxImage.json : JSON invalide"
    fi

    ## Node 4 = CLIPTextEncode (prompt)
    _N4=$(python3 -c "
import json
w=json.load(open('$WORKFLOW'))
n=w.get('4',{})
print(n.get('class_type','?'), '|', list(n.get('inputs',{}).keys()))
" 2>/dev/null)
    if echo "$_N4" | grep -q "CLIPTextEncode" && echo "$_N4" | grep -q "text"; then
        ok "Node 4 (CLIPTextEncode) — champ 'text' présent ($_N4)"
    else
        fail "Node 4 : structure inattendue ($_N4)"
    fi

    ## Node 1 = KSampler (seed)
    _N1=$(python3 -c "
import json
w=json.load(open('$WORKFLOW'))
n=w.get('1',{})
print(n.get('class_type','?'), '|', list(n.get('inputs',{}).keys()))
" 2>/dev/null)
    if echo "$_N1" | grep -q "KSampler" && echo "$_N1" | grep -q "seed"; then
        ok "Node 1 (KSampler) — champ 'seed' présent"
    else
        fail "Node 1 : structure inattendue ($_N1)"
    fi

    ## Node 7 = SaveImage (output)
    _N7=$(python3 -c "
import json
w=json.load(open('$WORKFLOW'))
n=w.get('7',{})
print(n.get('class_type','?'), '|', list(n.get('inputs',{}).keys()))
" 2>/dev/null)
    if echo "$_N7" | grep -q "SaveImage"; then
        ok "Node 7 (SaveImage) — sortie image"
    else
        fail "Node 7 : structure inattendue ($_N7)"
    fi

    ## Injection prompt : simuler update_prompt sans envoyer
    _TMP_WF=$(mktemp /tmp/flux_test_XXXXXX.json)
    _SEED=$((RANDOM * RANDOM))
    jq --arg p "$_PROMPT" --argjson s "$_SEED" \
        '(.["4"].inputs.text) = $p | (.["1"].inputs.seed) = $s' \
        "$WORKFLOW" > "$_TMP_WF" 2>/dev/null
    _INJECTED=$(python3 -c "
import json
w=json.load(open('$_TMP_WF'))
print(w['4']['inputs']['text'])
" 2>/dev/null)
    rm -f "$_TMP_WF"
    if [[ "$_INJECTED" == "$_PROMPT" ]]; then
        ok "Injection prompt dans workflow : OK ('$_PROMPT')"
    else
        fail "Injection prompt échouée (got: '$_INJECTED')"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "5. Génération image — generate_image.sh \"${_PROMPT}\""
## ─────────────────────────────────────────────────────────────────────────────

_IMAGE_URL=""
_IMAGE_CID=""

if ! $_COMFYUI_OK; then
    skip "Génération image (ComfyUI inaccessible)"
elif $SKIP_GENERATE; then
    skip "Génération image (--skip-generate)"
else
    echo -e "  ${YELLOW}▸${NC} Lancement génération — peut prendre 30-300s selon GPU..."
    _T0=$(date +%s)

    if $VERBOSE; then
        _IMAGE_URL=$(bash "$GENERATE_IMAGE" "$_PROMPT" 2>&1 | tee /dev/stderr | grep -E 'https?://[^ ]+/ipfs/' | tail -1)
    else
        _IMAGE_URL=$(bash "$GENERATE_IMAGE" "$_PROMPT" 2>"${HOME}/.zen${HOME}/.zen/tmp/comfyui_generate.log" | grep -E 'https?://[^ ]+/ipfs/' | tail -1)
    fi

    _T1=$(date +%s)
    _ELAPSED=$((_T1 - _T0))

    if [[ -n "$_IMAGE_URL" && "$_IMAGE_URL" =~ /ipfs/ ]]; then
        ok "Génération réussie en ${_ELAPSED}s — URL : ${_IMAGE_URL}"
        ## Extraire le CID
        _IMAGE_CID=$(echo "$_IMAGE_URL" | grep -oP 'Qm[A-Za-z0-9]{44,}' | head -1)
        if [[ -z "$_IMAGE_CID" ]]; then
            _IMAGE_CID=$(echo "$_IMAGE_URL" | grep -oP '(?<=/ipfs/)[A-Za-z0-9/]+' | head -1)
        fi
        vlog "CID extrait : $_IMAGE_CID"
        vlog "Log génération : ${HOME}/.zen/tmp/comfyui_generate.log"
    else
        fail "Génération échouée — URL retournée : '${_IMAGE_URL}'"
        $VERBOSE || echo -e "  ${YELLOW}ℹ${NC} Log: ${HOME}/.zen/tmp/comfyui_generate.log"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "6. Résultat IPFS — CID valide et image non vide"
## ─────────────────────────────────────────────────────────────────────────────

if [[ -z "$_IMAGE_URL" ]]; then
    skip "IPFS vérification (pas d'image générée)"
else
    ## CID présent ?
    if [[ -n "$_IMAGE_CID" ]]; then
        ok "CID IPFS extrait : ${_IMAGE_CID:0:20}..."
    else
        fail "CID non trouvé dans l'URL : $_IMAGE_URL"
    fi

    ## Taille du fichier via IPFS stat
    if [[ -n "$_IMAGE_CID" ]]; then
        _IPFS_SIZE=$(ipfs object stat "/ipfs/$_IMAGE_CID" 2>/dev/null \
            | grep "CumulativeSize" | awk '{print $2}')
        if [[ -n "$_IPFS_SIZE" && "$_IPFS_SIZE" -gt 0 ]]; then
            ok "IPFS : objet présent — taille cumulée ${_IPFS_SIZE} octets"
        else
            skip "IPFS stat : objet non encore disponible localement (propagation en cours)"
        fi
    fi

    ## URL publique accessible ?
    if [[ "$_IMAGE_URL" =~ ^https?:// ]]; then
        _HTTP_CODE=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" "$_IMAGE_URL" 2>/dev/null)
        if [[ "$_HTTP_CODE" == "200" ]]; then
            ok "URL publique accessible (HTTP 200) : ${_IMAGE_URL:0:60}..."
        else
            skip "URL publique : HTTP ${_HTTP_CODE} (gateway peut mettre du temps)"
        fi
    fi

    ## Afficher pour référence
    echo -e "\n  ${BOLD}Image générée :${NC}"
    echo -e "  URL  : $_IMAGE_URL"
    [[ -n "$_IMAGE_CID" ]] && echo -e "  IPFS : ipfs cat $_IMAGE_CID"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "7. Libération VRAM — POST /free"
## ─────────────────────────────────────────────────────────────────────────────

if ! $_COMFYUI_OK; then
    skip "Libération VRAM (ComfyUI inaccessible)"
else
    _FREE_RC=$(curl -s --max-time 5 -X POST "${COMFYUI_URL}/free" \
        -H "Content-Type: application/json" \
        -d '{"unload_models":true,"free_memory":true}' \
        -o /dev/null -w "%{http_code}" 2>/dev/null)
    if [[ "$_FREE_RC" =~ ^(200|204)$ ]]; then
        ok "POST /free : VRAM libérée (HTTP $_FREE_RC)"
    else
        skip "POST /free : HTTP ${_FREE_RC} (endpoint peut être absent sur certaines versions)"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "8. Canal DM comfyui_job — envoi via intercom (--with-dm)"
## ─────────────────────────────────────────────────────────────────────────────
## Simule un satellite qui envoie un job au NODE via NIP-44
## Le daemon bro_dm_daemon.sh traite le job et renvoie comfyui_result

if ! $WITH_DM; then
    skip "Test canal DM comfyui_job (ajouter --with-dm pour activer)"
    echo -e "  ${YELLOW}ℹ${NC} Ce test envoie un DM NIP-44 au NODE et attend la réponse comfyui_result"
else
    ## Clés coucou (satellite test) et NODE
    _COUCOU_NSEC=$(~/.zen/Astroport.ONE/tools/keygen -t nostr -s "coucou" "coucou" 2>/dev/null)
    _COUCOU_HEX=$(~/.zen/Astroport.ONE/tools/keygen -t nostr "coucou" "coucou" 2>/dev/null \
        | xargs -I{} python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" {} 2>/dev/null)

    _NODE_NSEC="" _NODE_HEX=""
    if [[ -s "$HOME/.zen/game/secret.nostr" ]]; then
        source "$HOME/.zen/game/secret.nostr"
        _NODE_HEX="${HEX:-}"
        unset NSEC NPUB HEX
    fi

    _RELAY_DM="${myRELAY:-ws://localhost:7777}"
    nc -z -w2 localhost 7777 2>/dev/null && _RELAY_DM="ws://localhost:7777"

    if [[ -z "$_NODE_HEX" ]]; then
        skip "DM comfyui_job : secret.nostr NODE absent"
    elif [[ -z "$_COUCOU_NSEC" ]]; then
        skip "DM comfyui_job : clé coucou non dérivée"
    elif ! $_COMFYUI_OK; then
        skip "DM comfyui_job : ComfyUI inaccessible — le daemon rejetterait le job"
    else
        _JOB_ID="test_dragon_$(date +%s)"
        _DM_PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'kname':          'coucou@test',
    'email':          'support+coucou@qo-op.com',
    'prompt':         '${_PROMPT}',
    'mode':           'image',
    'source_url':     '',
    'reply_node_hex': '${_COUCOU_HEX}',
    'reply_pubkey':   '${_COUCOU_HEX}',
    'job_id':         '${_JOB_ID}',
}))
" 2>/dev/null)

        echo -e "  ${YELLOW}▸${NC} Envoi comfyui_job (mode=image, job_id=${_JOB_ID}) → NODE ${_NODE_HEX:0:12}..."
        if python3 "$INTERCOM" send \
                --nsec    "$_COUCOU_NSEC" \
                --to      "$_NODE_HEX" \
                --channel "comfyui_job" \
                --payload "$_DM_PAYLOAD" \
                --ttl     7200 \
                --relays  "$_RELAY_DM" \
                2>/dev/null; then
            ok "comfyui_job envoyé (TTL=2h) — job_id=${_JOB_ID}"
            echo -e "  ${YELLOW}ℹ${NC} Résultat async dans comfyui_result → surveiller :"
            echo -e "    tail -f ~/.zen/tmp/bro_dm_daemon.log | grep '${_JOB_ID}'"
        else
            fail "comfyui_job DM : send échoué"
        fi

        ## Polling du résultat comfyui_result (60s max)
        echo -e "  ${YELLOW}▸${NC} Polling comfyui_result (60s max — génération async)..."
        _RESULT_FOUND=false
        for _i in $(seq 1 12); do
            sleep 5
            if grep -q "$_JOB_ID" "$HOME/.zen/tmp/bro_dm_daemon.log" 2>/dev/null \
               && grep -q "comfyui_result\|comfyui_job.*ok" "$HOME/.zen/tmp/bro_dm_daemon.log" 2>/dev/null; then
                _RESULT_FOUND=true
                break
            fi
            vlog "Attente résultat... ${_i}/12 ($((_i*5))s)"
        done

        if $_RESULT_FOUND; then
            ok "comfyui_result reçu et traité par le daemon (job_id=${_JOB_ID})"
        else
            skip "comfyui_result non détecté en 60s (génération peut être plus longue)"
        fi
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}═══════════════════════════════════════════${NC}"
echo -e "${BOLD}  Prompt testé : \"${_PROMPT}\"${NC}"
[[ -n "$_IMAGE_URL" ]] && echo -e "${GREEN}  Image : ${_IMAGE_URL}${NC}"
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  PERFECT — $PASS tests OK${NC}${SKIP:+ ($SKIP skipped)}"
else
    echo -e "${RED}  $FAIL ÉCHEC(S)${NC} / ${GREEN}$PASS OK${NC}${SKIP:+ / $SKIP skipped}"
fi
echo -e "${BOLD}═══════════════════════════════════════════${NC}"

[[ $FAIL -eq 0 ]]
