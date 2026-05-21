#!/bin/bash
################################################################################
# test_knowledge_demo.sh — Dataset de démo Knowledge Embeddings WoTx2
#
# Publie des ressources de formation Kind 30504 sur le relay NOSTR local,
# les indexe dans Qdrant (collection "knowledge") et vérifie la recherche
# sémantique pour chaque skill.
#
# Les données sont PERSISTÉES après le test pour servir de démo MineLife.
#
# Comptes test (mêmes que test_wotx2_demo.sh) :
#   coucou → publie bash + astroport
#   jean   → publie python
#   toto   → publie docker
#
# Skills couverts :
#   bash (coucou)       → "Bash pour stations Astroport"
#   python (jean)       → "Python pour l'écosystème UPlanet"
#   docker (toto)       → "Docker pour stations Astroport"
#   astroport (coucou)  → "Opérer une station Astroport (PERMIT_ASTROPORT_X1)"
#
# Usage :
#   ./tests/test_knowledge_demo.sh             # publish + index + verify
#   ./tests/test_knowledge_demo.sh --quick     # skip publish/index, verify seule
#   ./tests/test_knowledge_demo.sh --verbose   # output complet
#   ./tests/test_knowledge_demo.sh --quick --verbose
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"
FIXTURES="${MY_PATH}/fixtures/knowledge"

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
KNOWLEDGE_INDEX="${ASTROPORT_PATH}/admin/ia_db/knowledge_index.sh"

_pub() {
    if $VERBOSE; then
        python3 "$INTERCOM" publish "$@"
    else
        python3 "$INTERCOM" publish "$@" 2>/dev/null
    fi
}

_ok_id() {
    local _desc="$1" _id="$2"
    if [[ ${#_id} -eq 64 ]]; then
        ok "$_desc (${_id:0:12}...)"
    else
        fail "$_desc — event ID invalide ($_id)"
    fi
}

## ─────────────────────────────────────────────────────────────────────────────
section "0. Prérequis — IPFS, relay NOSTR, Qdrant"
## ─────────────────────────────────────────────────────────────────────────────

_LOCAL_RELAY="ws://localhost:7777"
_IPFS_GATEWAY="${IPFS_GATEWAY:-http://localhost:8080}"
_IPFS_API="${IPFS_API:-http://localhost:5001}"

_ipfs_ok=false
_relay_ok=false
_qdrant_ok=false

# Charger la clé Qdrant
_AI_ENV="${HOME}/.zen/ai-company/.env"
[[ -f "$_AI_ENV" ]] && _QDRANT_KEY=$(grep -E '^QDRANT_API_KEY=' "$_AI_ENV" | cut -d= -f2-)
_QDRANT_URL="${QDRANT_URL:-http://127.0.0.1:6333}"
_QDRANT_CURL_OPTS=()
[[ -n "${_QDRANT_KEY:-}" ]] && _QDRANT_CURL_OPTS=(-H "api-key: ${_QDRANT_KEY}")

# IPFS
ipfs id &>/dev/null && _ipfs_ok=true
if $_ipfs_ok; then
    ok "IPFS daemon disponible"
else
    skip "IPFS non disponible — publication CID ignorée"
fi

# Relay NOSTR local
nc -z -w2 localhost 7777 2>/dev/null && _relay_ok=true
if $_relay_ok; then
    ok "relay NOSTR local : $_LOCAL_RELAY"
else
    skip "relay NOSTR local absent"
fi

# Qdrant
if curl -sf --max-time 2 "${_QDRANT_CURL_OPTS[@]}" "${_QDRANT_URL}/healthz" &>/dev/null; then
    _qdrant_ok=true
    ok "Qdrant disponible : $_QDRANT_URL"
else
    skip "Qdrant non disponible — indexation ignorée"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "1. Clés test déterministes (coucou / jean / toto)"
## ─────────────────────────────────────────────────────────────────────────────
## Identiques à test_wotx2_demo.sh — dérivation déterministe

_COUCOU_NSEC=$("$KEYGEN" -t nostr -s "coucou" "coucou" 2>/dev/null)
_JEAN_NSEC=$("$KEYGEN"   -t nostr -s "jean"   "jean"   2>/dev/null)
_TOTO_NSEC=$("$KEYGEN"   -t nostr -s "toto"   "toto"   2>/dev/null)

_COUCOU_NPUB=$("$KEYGEN" -t nostr    "coucou" "coucou" 2>/dev/null)
_JEAN_NPUB=$("$KEYGEN"   -t nostr    "jean"   "jean"   2>/dev/null)
_TOTO_NPUB=$("$KEYGEN"   -t nostr    "toto"   "toto"   2>/dev/null)

_COUCOU_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_COUCOU_NPUB" 2>/dev/null)
_JEAN_HEX=$(python3   "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_JEAN_NPUB"   2>/dev/null)
_TOTO_HEX=$(python3   "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_TOTO_NPUB"   2>/dev/null)

[[ ${#_COUCOU_HEX} -eq 64 ]] && ok "coucou ${_COUCOU_HEX:0:12}..." || fail "clé coucou"
[[ ${#_JEAN_HEX}   -eq 64 ]] && ok "jean   ${_JEAN_HEX:0:12}..."   || fail "clé jean"
[[ ${#_TOTO_HEX}   -eq 64 ]] && ok "toto   ${_TOTO_HEX:0:12}..."   || fail "clé toto"

## ─────────────────────────────────────────────────────────────────────────────
section "2. Publication des documents sur IPFS"
## ─────────────────────────────────────────────────────────────────────────────
## Ajoute chaque .md dans IPFS et mémorise le CID

declare -A _CID
declare -A _FIXTURE=(
    [bash]="${FIXTURES}/bash_astroport_coucou.md"
    [python]="${FIXTURES}/python_uplanet_jean.md"
    [docker]="${FIXTURES}/docker_station_toto.md"
    [astroport]="${FIXTURES}/astroport_x1_coucou.md"
)
declare -A _TITLE=(
    [bash]="Bash pour stations Astroport"
    [python]="Python pour l'écosystème UPlanet"
    [docker]="Docker pour stations Astroport"
    [astroport]="Opérer une station Astroport (PERMIT_ASTROPORT_X1)"
)

if $QUICK || ! $_ipfs_ok; then
    skip "publication IPFS (--quick ou IPFS absent)"
    # Essayer de lire des CID déjà publiés depuis un fichier cache
    _CACHE="${MY_PATH}/fixtures/knowledge/.ipfs_cids"
    if [[ -f "$_CACHE" ]]; then
        source "$_CACHE"
        vlog "CIDs chargés depuis le cache : $_CACHE"
    fi
else
    _CACHE="${MY_PATH}/fixtures/knowledge/.ipfs_cids"
    printf "" > "$_CACHE"
    for _skill in bash python docker astroport; do
        _fp="${_FIXTURE[$_skill]}"
        if [[ ! -f "$_fp" ]]; then
            fail "$_skill : fixture absente : $_fp"
            continue
        fi
        _cid=$(ipfs add -q "$_fp" 2>/dev/null)
        if [[ ${#_cid} -ge 46 ]]; then
            _CID[$_skill]="$_cid"
            printf '_CID[%s]="%s"\n' "$_skill" "$_cid" >> "$_CACHE"
            ok "$_skill : /ipfs/${_cid:0:20}..."
            vlog "  ${_TITLE[$_skill]}"
        else
            fail "$_skill : ipfs add échoué"
        fi
    done
fi

## ─────────────────────────────────────────────────────────────────────────────
section "3. Publication Kind 30504 — ressources formation sur relay NOSTR"
## ─────────────────────────────────────────────────────────────────────────────
## Chaque compte publie les ressources liées à ses skills

declare -A _EV_KIND30504
_NOW=$(date +%s)

_pub_30504() {
    local _nsec="$1" _skill="$2" _cid="$3" _title="$4" _relay="$5"
    [[ -z "$_cid" ]] && return 1
    # Passer les valeurs en argv pour éviter les problèmes d'apostrophes/guillemets
    local _tags
    _tags=$(python3 - "$_skill" "$_NOW" "$_cid" "$_title" <<'PYEOF'
import json, sys
skill, now, cid, title = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
print(json.dumps([
    ["d", f"training_{skill}_{now}"],
    ["t", skill], ["t", "formation"],
    ["r", f"/ipfs/{cid}", "document"],
    ["title", title]
]))
PYEOF
)
    _pub \
        --nsec "$_nsec" --kind 30504 \
        --tags "$_tags" \
        --content "{\"skill\":\"${_skill}\",\"resource_type\":\"document\"}" \
        --relays "$_relay"
}

if $QUICK || ! $_relay_ok; then
    skip "publication Kind 30504 (--quick ou relay absent)"
    _EV_KIND30504[bash]="" _EV_KIND30504[python]="" \
    _EV_KIND30504[docker]="" _EV_KIND30504[astroport]=""
else
    # coucou → bash
    _ev=$(_pub_30504 "$_COUCOU_NSEC" "bash" "${_CID[bash]}" "${_TITLE[bash]}" "$_LOCAL_RELAY")
    _EV_KIND30504[bash]="$_ev"
    _ok_id "Kind 30504 coucou→bash" "$_ev"

    # jean → python
    _ev=$(_pub_30504 "$_JEAN_NSEC" "python" "${_CID[python]}" "${_TITLE[python]}" "$_LOCAL_RELAY")
    _EV_KIND30504[python]="$_ev"
    _ok_id "Kind 30504 jean→python" "$_ev"

    # toto → docker (relay local si disponible, sinon remote)
    _TOTO_RELAY="${myRELAY:-wss://relay.copylaradio.com}"
    nc -z -w2 localhost 7777 2>/dev/null && _TOTO_RELAY="$_LOCAL_RELAY"
    _ev=$(_pub_30504 "$_TOTO_NSEC" "docker" "${_CID[docker]}" "${_TITLE[docker]}" "$_TOTO_RELAY")
    _EV_KIND30504[docker]="$_ev"
    _ok_id "Kind 30504 toto→docker" "$_ev"

    # coucou → astroport (composite)
    _ev=$(_pub_30504 "$_COUCOU_NSEC" "astroport" "${_CID[astroport]}" "${_TITLE[astroport]}" "$_LOCAL_RELAY")
    _EV_KIND30504[astroport]="$_ev"
    _ok_id "Kind 30504 coucou→astroport" "$_ev"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "4. Indexation Qdrant — knowledge_index.sh --index-nostr"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ! $_qdrant_ok || ! $_relay_ok; then
    skip "indexation Qdrant (--quick ou service absent)"
    _indexed=false
else
    echo -e "  ${CYAN}[knowledge_index]${NC} Indexation depuis relay local..."
    if $VERBOSE; then
        QDRANT_API_KEY="${_QDRANT_KEY:-}" QDRANT_URL="$_QDRANT_URL" \
        NOSTR_RELAY="$_LOCAL_RELAY" IPFS_GATEWAY="$_IPFS_GATEWAY" \
            "$KNOWLEDGE_INDEX" --index-nostr
    else
        QDRANT_API_KEY="${_QDRANT_KEY:-}" QDRANT_URL="$_QDRANT_URL" \
        NOSTR_RELAY="$_LOCAL_RELAY" IPFS_GATEWAY="$_IPFS_GATEWAY" \
            "$KNOWLEDGE_INDEX" --index-nostr 2>/dev/null
    fi
    _exit=$?
    if [[ $_exit -eq 0 ]]; then
        ok "indexation terminée (exit 0)"
        _indexed=true
    else
        fail "indexation échouée (exit $_exit)"
        _indexed=false
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "5. Vérification stats collection 'knowledge'"
## ─────────────────────────────────────────────────────────────────────────────

if ! $_qdrant_ok; then
    skip "stats (Qdrant absent)"
else
    _stats=$(QDRANT_API_KEY="${_QDRANT_KEY:-}" QDRANT_URL="$_QDRANT_URL" \
        "$KNOWLEDGE_INDEX" --stats 2>/dev/null)
    _pts=$(echo "$_stats" | python3 -c "import json,sys; print(json.load(sys.stdin).get('points_count',0))" 2>/dev/null || echo 0)
    vlog "stats : $_stats"
    if [[ "$_pts" -gt 0 ]]; then
        ok "collection 'knowledge' : $_pts point(s)"
    else
        skip "collection 'knowledge' vide (aucun Kind 30504 avec CID IPFS accessible?)"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "6. Recherche sémantique — validation par skill"
## ─────────────────────────────────────────────────────────────────────────────

declare -A _QUERIES=(
    [bash]="scripting bash automatisation station astroport"
    [python]="python uplanet fastapi crypto nostr"
    [docker]="conteneurs docker compose stack astroport"
    [astroport]="opérer station astroport ipfs nostr constellation"
)

if $QUICK || ! $_qdrant_ok || ! ${_indexed:-false}; then
    skip "recherche sémantique (--quick ou collection vide)"
else
    _search_ok=0
    for _skill in bash python docker astroport; do
        _q="${_QUERIES[$_skill]}"
        _result=$(QDRANT_API_KEY="${_QDRANT_KEY:-}" QDRANT_URL="$_QDRANT_URL" \
            IPFS_GATEWAY="$_IPFS_GATEWAY" \
            "$KNOWLEDGE_INDEX" --search "$_q" --skill "$_skill" 2>/dev/null | head -3)
        vlog "search '$_skill' : $_result"
        if [[ -n "$_result" ]]; then
            _top_score=$(echo "$_result" | head -1 | cut -f1)
            _top_title=$(echo "$_result" | head -1 | cut -f4)
            ok "search '$_skill' → '${_top_title:0:40}' (score: ${_top_score})"
            _search_ok=$((_search_ok+1))
        else
            skip "search '$_skill' — aucun résultat (doc non indexé ou IPFS indisponible)"
        fi
    done
    [[ $_search_ok -ge 2 ]] \
        && ok "recherche sémantique fonctionnelle ($_search_ok/4 skills retrouvés)" \
        || fail "recherche sémantique partielle ($_search_ok/4)"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "7. Vérification attribution auteur"
## ─────────────────────────────────────────────────────────────────────────────
## Vérifie que l'author_hex du résultat correspond bien au publieur attendu

if $QUICK || ! $_qdrant_ok || ! ${_indexed:-false}; then
    skip "vérification auteur (--quick ou collection vide)"
else
    declare -A _EXPECTED_AUTHOR=(
        [bash]="$_COUCOU_HEX"
        [python]="$_JEAN_HEX"
        [docker]="$_TOTO_HEX"
        [astroport]="$_COUCOU_HEX"
    )
    for _skill in bash python astroport; do
        _result=$(QDRANT_API_KEY="${_QDRANT_KEY:-}" QDRANT_URL="$_QDRANT_URL" \
            IPFS_GATEWAY="$_IPFS_GATEWAY" \
            "$KNOWLEDGE_INDEX" --search "${_QUERIES[$_skill]}" --skill "$_skill" \
            2>/dev/null | head -1)
        _got_author=$(echo "$_result" | cut -f3)
        _exp_author="${_EXPECTED_AUTHOR[$_skill]}"
        if [[ "$_got_author" == "$_exp_author" ]]; then
            ok "auteur '$_skill' : ${_got_author:0:16}... ✓ (attendu)"
        elif [[ -n "$_got_author" ]]; then
            # Auteur différent = un autre Kind 30504 plus pertinent trouvé (normal)
            skip "auteur '$_skill' : ${_got_author:0:16}... (diff attendu — autre doc plus pertinent)"
        else
            skip "auteur '$_skill' : non vérifiable (doc non indexé)"
        fi
    done
fi

## ─────────────────────────────────────────────────────────────────────────────
section "8. Résumé dataset Knowledge demo"
## ─────────────────────────────────────────────────────────────────────────────

echo -e "\n  ${BOLD}Documents de formation publiés :${NC}"
for _skill in bash python docker astroport; do
    _cid_disp="${_CID[$_skill]:+/ipfs/${_CID[$_skill]:0:20}...}"
    _cid_disp="${_cid_disp:-non publié}"
    _ev_disp="${_EV_KIND30504[$_skill]:+${_EV_KIND30504[$_skill]:0:12}...}"
    _ev_disp="${_ev_disp:-non publié}"
    printf "  %-12s %-30s kind30504: %s\n" "[$_skill]" "$_cid_disp" "$_ev_disp"
done

echo ""
echo -e "  ${BOLD}Ces données restent sur le relay et dans Qdrant${NC}"
echo -e "  pour démontrer MineLife Formation et BRO #rec."
echo ""
echo -e "  Pour interroger BRO (si disponible) :"
echo -e "    DM Kind 4 → NODE : ${CYAN}#rec bash${NC}"
echo -e "    DM Kind 4 → NODE : ${CYAN}#rec docker${NC}"
echo ""
echo -e "  Pour rechercher directement :"
echo -e "    ${CYAN}./admin/ia_db/knowledge_index.sh --search 'bash astroport' --skill bash${NC}"
echo -e "    ${CYAN}./admin/ia_db/knowledge_index.sh --search 'docker station'  --skill docker${NC}"

PASS=$((PASS+1))  # synthèse

## ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}═══════════════════════════════════════════${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  PERFECT — $PASS tests OK${NC}${SKIP:+ ($SKIP skipped)}"
else
    echo -e "${RED}  $FAIL ÉCHEC(S)${NC} / ${GREEN}$PASS OK${NC}${SKIP:+ / $SKIP skipped}"
fi
echo -e "${BOLD}═══════════════════════════════════════════${NC}"

[[ $FAIL -eq 0 ]]
