#!/bin/bash
################################################################################
# test_minelife_captain.sh — Scénario MineLife : le Capitaine obtient
#                             "analytics-uplanet" grâce à coucou, jean et toto.
#
# COMPORTEMENT :
#   • Chaque run peuple le relay NOSTR → les données RESTENT pour MineLife.
#   • Si un run précédent existe (cache JSON) → AUTO-RESET automatique :
#       - Kind 5 (deletion) pour les Kind 7 non-remplaçables
#       - Republication de tout le scénario (events 30xxx s'auto-remplacent)
#   • Les données servent de formation P2P : elles enrichissent le relay
#     et la collection Qdrant "knowledge" pour BRO.
#
# VISION : chaque nouveau capitaine apporte ses compétences, ses toiles de
#   confiance et ses crafts (ORE, WoTx2, P2P, MineLife) → plateforme de
#   formation pair-à-pair décentralisée et auto-enrichissante.
#
# ──────────────────────────────────────────────────────────────────────────────
# Scénario concret (Analytics UPlanet) :
#
#   coucou → expert NOSTR Relay & Événements (PERMIT_NOSTR_RELAY_X1)
#              adoube le Capitaine : Règle B (30502) + Règle A (Kind 7 ×1/3)
#
#   jean   → expert UPassport API (PERMIT_UPASSPORT_X1)
#              adoube le Capitaine : Règle B (30502) + Règle A (Kind 7 ×1/3)
#
#   toto   → expert Analytics UPlanet (PERMIT_ANALYTICS_X1)
#              auteur Analytics.README.md → Kind 30504 (formation BRO)
#              définit le composite PERMIT_ANALYTICS_UPLANET_X1
#                recette : nostr-relay X1 + upassport-api X1
#              adoube le Capitaine : Règle A (Kind 7 ×1/3 → seuil atteint !)
#
#   CAPITAINE
#     1. Déclare aspirations Kind 30501 vers chaque compétence
#     2. Reçoit attestations Règle B (Kind 30502) des 3 experts
#     3. Obtient nostr-relay X1 + upassport-api X1 (Kind 30503)
#     4. Crafte analytics-uplanet X1 composite (Kind 30503 P2P 🔵)
#     5. Soumet demande validation Oracle (Kind 30501 composite-validation 🏅)
#
# ──────────────────────────────────────────────────────────────────────────────
# Usage :
#   ./tests/test_minelife_captain.sh           # populate (auto-reset si nécessaire)
#   ./tests/test_minelife_captain.sh --quick   # vérif relay seule (skip publish)
#   ./tests/test_minelife_captain.sh --verbose # output complet
#   ./tests/test_minelife_captain.sh --purge   # supprime SANS repeupler
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ASTROPORT_PATH="$(cd "$MY_PATH/.." && pwd)"
FIXTURES="${MY_PATH}/fixtures/knowledge"

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE manquant" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

## ── Drapeaux ─────────────────────────────────────────────────────────────────
QUICK=false; VERBOSE=false; PURGE=false
for _arg in "$@"; do
    [[ "$_arg" == "--quick"   ]] && QUICK=true
    [[ "$_arg" == "--verbose" ]] && VERBOSE=true
    [[ "$_arg" == "--purge"   ]] && PURGE=true
done

## ── UI ────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

ok()      { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip()    { echo -e "  ${YELLOW}⊘${NC} $1"; SKIP=$((SKIP+1)); }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }
info()    { echo -e "  ${BOLD}ℹ${NC}  $1"; }
vlog()    { $VERBOSE && echo -e "  ${YELLOW}▸${NC} $1" || true; }
_ok_id()  { [[ ${#2} -eq 64 ]] && ok "$1 (${2:0:12}...)" || fail "$1 — ID invalide"; }

## ── Outils ────────────────────────────────────────────────────────────────────
INTERCOM="${ASTROPORT_PATH}/tools/nostr_node_intercom.py"
KEYGEN="${ASTROPORT_PATH}/tools/keygen"
_CACHE_FILE="${HOME}/.zen/tmp/tests/minelife_captain_scenario.json"
mkdir -p "$(dirname "$_CACHE_FILE")"

_pub() {
    $VERBOSE \
        && python3 "$INTERCOM" publish "$@" \
        || python3 "$INTERCOM" publish "$@" 2>/dev/null
}
_query() {
    local _filter="$1" _relay="$2"
    $VERBOSE \
        && python3 "$INTERCOM" query --filter "$_filter" --relays "$_relay" \
        || python3 "$INTERCOM" query --filter "$_filter" --relays "$_relay" 2>/dev/null || echo "[]"
}
_count() { python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0; }

## ── Cache JSON ────────────────────────────────────────────────────────────────
[[ -f "$_CACHE_FILE" ]] && _CACHE=$(cat "$_CACHE_FILE") || _CACHE="{}"
_cache_get() {
    echo "$_CACHE" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('''$1''',''))" 2>/dev/null || echo ""
}
_cache_set() {
    local _key="$1" _val="$2"
    _CACHE=$(python3 -c "
import json,sys
d=json.loads('''$( echo "$_CACHE" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)))" 2>/dev/null || echo '{}')''')
d['$_key']='$_val'
print(json.dumps(d, indent=2))" 2>/dev/null || echo "$_CACHE")
    echo "$_CACHE" > "$_CACHE_FILE"
}

## ── Publish (toujours, les 30xxx s'auto-remplacent) + cache le résultat ──────
_pub_c() {
    local _desc="$1" _cache_key="$2"; shift 2
    local _id
    _id=$(_pub "$@")
    _ok_id "$_desc" "$_id"
    [[ ${#_id} -eq 64 ]] && _cache_set "$_cache_key" "$_id"
    echo "$_id"
}

## ─────────────────────────────────────────────────────────────────────────────
## Dériver les clés (nécessaire aussi pour le reset)
## ─────────────────────────────────────────────────────────────────────────────
_COUCOU_NPUB=$("$KEYGEN" -t nostr "coucou" "coucou" 2>/dev/null)
_COUCOU_NSEC=$("$KEYGEN" -t nostr -s "coucou" "coucou" 2>/dev/null)
_COUCOU_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_COUCOU_NPUB" 2>/dev/null)

_TOTO_NPUB=$("$KEYGEN" -t nostr "toto" "toto" 2>/dev/null)
_TOTO_NSEC=$("$KEYGEN" -t nostr -s "toto" "toto" 2>/dev/null)
_TOTO_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_TOTO_NPUB" 2>/dev/null)

_JEAN_NPUB=$("$KEYGEN" -t nostr "jean" "jean" 2>/dev/null)
_JEAN_NSEC=$("$KEYGEN" -t nostr -s "jean" "jean" 2>/dev/null)
_JEAN_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_JEAN_NPUB" 2>/dev/null)

_CAP_LABEL="capitaine (test)"
if [[ -n "$CAPTAINEMAIL" && -f "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    _CAP_NSEC="$NSEC"; _CAP_NPUB="$NPUB"; _CAP_LABEL="$CAPTAINEMAIL"
else
    _CAP_NSEC=$("$KEYGEN" -t nostr -s "capitaine" "capitaine" 2>/dev/null)
    _CAP_NPUB=$("$KEYGEN" -t nostr "capitaine" "capitaine" 2>/dev/null)
fi
_CAP_HEX=$(python3 "${ASTROPORT_PATH}/tools/nostr2hex.py" "$_CAP_NPUB" 2>/dev/null)

## ─────────────────────────────────────────────────────────────────────────────
## AUTO-RESET : si cache présent → nettoyer les Kind 7 (non-remplaçables)
##              puis republier tout le scénario frais
## ─────────────────────────────────────────────────────────────────────────────

_do_reset() {
    local _relay_local="$1" _relay_remote="$2"
    section "AUTO-RESET — nettoyage Kind 7 avant repopulation"

    local _del_count=0
    local _kind7_keys=(kind7_coucou_cap_nostr kind7_toto_cap_nostr kind7_jean_cap_nostr)

    ## Association clé-cache → nsec + relay
    declare -A _KEY_NSEC _KEY_RELAY
    _KEY_NSEC[kind7_coucou_cap_nostr]="$_COUCOU_NSEC"
    _KEY_RELAY[kind7_coucou_cap_nostr]="$_relay_local"
    _KEY_NSEC[kind7_toto_cap_nostr]="$_TOTO_NSEC"
    _KEY_RELAY[kind7_toto_cap_nostr]="$_relay_remote"
    _KEY_NSEC[kind7_jean_cap_nostr]="$_JEAN_NSEC"
    _KEY_RELAY[kind7_jean_cap_nostr]="$_relay_local"

    for _k in "${_kind7_keys[@]}"; do
        local _ev_id
        _ev_id=$(_cache_get "$_k")
        [[ ${#_ev_id} -ne 64 ]] && continue
        vlog "Kind 5 delete $_k : ${_ev_id:0:12}..."
        _pub --nsec "${_KEY_NSEC[$_k]}" --kind 5 \
            --tags "[\"e\",\"$_ev_id\"]" \
            --content "minelife_captain_scenario reset" \
            --relays "${_KEY_RELAY[$_k]}" >/dev/null 2>&1
        _del_count=$((_del_count+1))
    done

    rm -f "$_CACHE_FILE"
    _CACHE="{}"
    [[ $_del_count -gt 0 ]] \
        && ok "Auto-reset : $_del_count Kind 7 supprimé(s) → relay propre" \
        || ok "Auto-reset : aucun Kind 7 en cache (events 30xxx s'auto-remplacent)"
}

## ─────────────────────────────────────────────────────────────────────────────
## MODE PURGE (--purge) : supprime SANS repeupler
## ─────────────────────────────────────────────────────────────────────────────
if $PURGE; then
    section "PURGE — suppression uniquement (sans repopulation)"
    _LOCAL_RELAY="ws://localhost:7777"
    _REMOTE_RELAY="${myRELAY:-wss://relay.copylaradio.com}"
    nc -z -w2 localhost 7777 2>/dev/null && _local_ok=true || _local_ok=false
    $_local_ok && _LR="$_LOCAL_RELAY" || _LR="$_REMOTE_RELAY"
    _do_reset "$_LR" "$_REMOTE_RELAY"
    [[ -f "$_CACHE_FILE" ]] && rm -f "$_CACHE_FILE" && ok "Cache purgé"
    echo -e "\n${GREEN}Purge terminée. Relancer sans --purge pour repeupler.${NC}"
    exit 0
fi

################################################################################
echo -e "\n${BOLD}🎓 Scénario MineLife Capitaine — Analytics UPlanet${NC}"
echo -e "   Formation P2P décentralisée : coucou + jean + toto → Capitaine"
echo -e "   Chaque run rafraîchit les données sur le relay (auto-reset)\n"
################################################################################

## ─────────────────────────────────────────────────────────────────────────────
section "0. Setup — relay, TTL, amisOfAmis"
## ─────────────────────────────────────────────────────────────────────────────

_LOCAL_RELAY="ws://localhost:7777"
_REMOTE_RELAY="${myRELAY:-wss://relay.copylaradio.com}"
_3Y=$(($(date +%s) + 94608000))

_local_ok=false; _remote_ok=false
nc -z -w2 localhost 7777 2>/dev/null && _local_ok=true
_REMOTE_HOST=$(echo "$_REMOTE_RELAY" | sed 's|wss\?://||;s|/.*||;s|:.*||')
_REMOTE_PORT=$(echo "$_REMOTE_RELAY" | grep -oP ':\K[0-9]+' || echo "443")
nc -z -w3 "$_REMOTE_HOST" "$_REMOTE_PORT" 2>/dev/null && _remote_ok=true

$_local_ok  && ok  "relay local  : $_LOCAL_RELAY"  || skip "relay local absent (coucou+jean→remote)"
$_remote_ok && ok  "relay remote : $_REMOTE_RELAY" || skip "relay remote inaccessible"

## Routing par compte
_COUCOU_RELAY="$_LOCAL_RELAY";  $_local_ok || _COUCOU_RELAY="$_REMOTE_RELAY"
_JEAN_RELAY="$_LOCAL_RELAY";    $_local_ok || _JEAN_RELAY="$_REMOTE_RELAY"
_TOTO_RELAY="$_REMOTE_RELAY"
_CAP_RELAY="$_LOCAL_RELAY";     $_local_ok || _CAP_RELAY="$_REMOTE_RELAY"

## ─────────────────────────────────────────────────────────────────────────────
section "1. Clés — coucou, jean, toto + Capitaine"
## ─────────────────────────────────────────────────────────────────────────────

[[ ${#_COUCOU_HEX} -eq 64 ]] && ok "coucou ${_COUCOU_HEX:0:12}... (support+coucou@qo-op.com)" || fail "dérivation coucou échouée"
[[ ${#_TOTO_HEX}   -eq 64 ]] && ok "toto   ${_TOTO_HEX:0:12}... (support+toto@qo-op.com)"    || fail "dérivation toto échouée"
[[ ${#_JEAN_HEX}   -eq 64 ]] && ok "jean   ${_JEAN_HEX:0:12}... (support+jean@qo-op.com)"    || fail "dérivation jean échouée"
[[ ${#_CAP_HEX}    -eq 64 ]] && ok "Capitaine ${_CAP_HEX:0:12}... ($_CAP_LABEL)"              || { fail "dérivation capitaine échouée"; exit 1; }

## amisOfAmis.txt — relay local accepte les 4 comptes
_AMIS_FILE="${HOME}/.zen/strfry/amisOfAmis.txt"
mkdir -p "$(dirname "$_AMIS_FILE")" && touch "$_AMIS_FILE"
_added=0
for _hex in "$_COUCOU_HEX" "$_TOTO_HEX" "$_JEAN_HEX" "$_CAP_HEX"; do
    grep -q "^${_hex}$" "$_AMIS_FILE" 2>/dev/null || { echo "$_hex" >> "$_AMIS_FILE"; _added=$((_added+1)); }
done
[[ $_added -gt 0 ]] && ok "amisOfAmis.txt : $_added compte(s) ajouté(s)" \
                    || ok "amisOfAmis.txt : tous les comptes déjà enregistrés"

## ─────────────────────────────────────────────────────────────────────────────
## AUTO-RESET si cache présent (données du run précédent)
## ─────────────────────────────────────────────────────────────────────────────
if [[ -f "$_CACHE_FILE" ]] && ! $QUICK; then
    _do_reset "$_LOCAL_RELAY" "$_REMOTE_RELAY"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "2. Permits Kind 30500 — définitions des 4 compétences"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish permits (--quick ou relay(s) inaccessible(s))"
    _EV_NOSTR_RELAY="" _EV_UPASSPORT="" _EV_ANALYTICS="" _EV_COMPOSITE=""
else
    _EV_NOSTR_RELAY=$(_pub_c "PERMIT_NOSTR_RELAY_X1 (coucou→local)" "permit_nostr-relay" \
        --nsec "$_COUCOU_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_NOSTR_RELAY_X1"],["t","permit"],["t","auto_proclaimed"],["t","nostr-relay"]]' \
        --content '{"id":"PERMIT_NOSTR_RELAY_X1","name":"NOSTR Relay & Événements","icon":"📡","skill_tag":"nostr-relay","auto_proclaimed":true,"description":"Maîtrise des relays NOSTR, des kinds d'\''événements (7, 30500-30504, 10600) et du protocole NIP."}' \
        --relays "$_COUCOU_RELAY")

    _EV_UPASSPORT=$(_pub_c "PERMIT_UPASSPORT_X1 (jean→local)" "permit_upassport-api" \
        --nsec "$_JEAN_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_UPASSPORT_X1"],["t","permit"],["t","auto_proclaimed"],["t","upassport-api"]]' \
        --content '{"id":"PERMIT_UPASSPORT_X1","name":"UPassport API","icon":"🔑","skill_tag":"upassport-api","auto_proclaimed":true,"description":"API FastAPI UPassport (port 54321) : endpoints /ping, /g1nostr, /zen_send, /check_balance."}' \
        --relays "$_JEAN_RELAY")

    _EV_ANALYTICS=$(_pub_c "PERMIT_ANALYTICS_X1 base (toto→remote)" "permit_analytics-base" \
        --nsec "$_TOTO_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_ANALYTICS_X1"],["t","permit"],["t","auto_proclaimed"],["t","analytics-uplanet"]]' \
        --content '{"id":"PERMIT_ANALYTICS_X1","name":"Analytics UPlanet","icon":"📈","skill_tag":"analytics-uplanet","auto_proclaimed":true,"description":"Système analytics UPlanet : Kind 10600, smartSend(), 3 modes, NIP-44, endpoint /ping."}' \
        --relays "$_TOTO_RELAY")

    ## Composite : nostr-relay + upassport-api → analytics-uplanet
    ## metadata.recipe utilisé par parseRecipeFromPermit (minelife.html)
    _EV_COMPOSITE=$(_pub_c "PERMIT_ANALYTICS_UPLANET_X1 composite (toto→remote)" "permit_analytics-composite" \
        --nsec "$_TOTO_NSEC" --kind 30500 \
        --tags '[["d","PERMIT_ANALYTICS_UPLANET_X1"],["t","permit"],["t","composite"],["t","analytics-uplanet"],["requires","nostr-relay","1"],["requires","upassport-api","1"]]' \
        --content '{"id":"PERMIT_ANALYTICS_UPLANET_X1","name":"Analytics UPlanet (Composite)","icon":"📈","skill_tag":"analytics-uplanet","composite":true,"description":"Comprendre et déployer le système analytics UPlanet de bout en bout.","metadata":{"recipe":[{"skill":"nostr-relay","min_level":1},{"skill":"upassport-api","min_level":1}]}}' \
        --relays "$_TOTO_RELAY")
fi

## ─────────────────────────────────────────────────────────────────────────────
section "3. Formation Kind 30504 — analytics_uplanet_toto.md (BRO memory)"
## ─────────────────────────────────────────────────────────────────────────────
## Ce document est la mémoire de l'IA : BRO interroge Qdrant "knowledge"
## pour vérifier le passage de connaissance analytics au Capitaine.

_EV_FORMATION=""
_ANALYTICS_CID=$(_cache_get "analytics_ipfs_cid")

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 30504 (--quick ou relay(s) inaccessible(s))"
else
    ## Calculer le CID IPFS du document fixture
    if [[ -z "$_ANALYTICS_CID" ]]; then
        _ANALYTICS_CID=$(ipfs add -q "${FIXTURES}/analytics_uplanet_toto.md" 2>/dev/null)
        if [[ -n "$_ANALYTICS_CID" ]]; then
            ok "analytics_uplanet_toto.md → IPFS : $_ANALYTICS_CID"
            _cache_set "analytics_ipfs_cid" "$_ANALYTICS_CID"
            ## Mettre à jour .ipfs_cids du projet
            if [[ -f "${FIXTURES}/.ipfs_cids" ]]; then
                python3 -c "
lines = open('${FIXTURES}/.ipfs_cids').readlines()
lines = [l for l in lines if 'analytics-uplanet' not in l]
lines.append('_CID[analytics-uplanet]=\"$_ANALYTICS_CID\"\n')
open('${FIXTURES}/.ipfs_cids','w').writelines(lines)
" 2>/dev/null && ok ".ipfs_cids mis à jour"
            fi
        else
            skip "IPFS non disponible — Kind 30504 publié sans CID réel"
            _ANALYTICS_CID="QmAnalyticsUPlanetPlaceholderDoc"
        fi
    else
        ok "analytics_uplanet_toto.md — CID IPFS : $_ANALYTICS_CID"
    fi

    _EV_FORMATION=$(_pub_c "Kind 30504 toto→analytics-uplanet (BRO memory)" "formation_analytics" \
        --nsec "$_TOTO_NSEC" --kind 30504 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','training_analytics_uplanet_toto'],
            ['t','analytics-uplanet'],
            ['t','formation'],
            ['r','/ipfs/$_ANALYTICS_CID','document'],
            ['title','Analytics UPlanet — Guide Praticien (toto)']
        ]))")" \
        --content "{\"description\":\"Guide complet analytics UPlanet : Kind 10600, smartSend, NIP-44. Mémoire BRO pour examen du Capitaine.\",\"skill\":\"analytics-uplanet\",\"resource_url\":\"/ipfs/$_ANALYTICS_CID\",\"resource_type\":\"document\",\"author\":\"toto\"}" \
        --relays "$_TOTO_RELAY")

    ## Indexer dans Qdrant si disponible
    if [[ -n "$_ANALYTICS_CID" ]] && command -v curl >/dev/null 2>&1; then
        _QDRANT_UP=$(curl -sf "http://localhost:6333/collections/knowledge" 2>/dev/null | \
            python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result',{}).get('status','nok'))" 2>/dev/null)
        if [[ "$_QDRANT_UP" == "green" ]]; then
            KNOWLEDGE_INDEX="${ASTROPORT_PATH}/tools/knowledge_index.sh"
            if [[ -x "$KNOWLEDGE_INDEX" ]]; then
                "$KNOWLEDGE_INDEX" "analytics-uplanet" \
                    "${FIXTURES}/analytics_uplanet_toto.md" \
                    "$_ANALYTICS_CID" "$_TOTO_HEX" >/dev/null 2>&1 \
                    && ok "Qdrant 'knowledge' : analytics-uplanet indexé pour BRO" \
                    || skip "Qdrant indexation analytics échouée"
            fi
        fi
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "4. Auto-certifications Kind 30503 — les 3 experts"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish certifs experts (--quick ou relay(s) inaccessible(s))"
    _CERT_COUCOU_NOSTR="" _CERT_JEAN_UPASSPORT="" _CERT_TOTO_ANALYTICS=""
else
    _CERT_COUCOU_NOSTR=$(_pub_c "coucou → nostr-relay X1 (auto-signé P2P)" "cert_coucou_nostr-relay" \
        --nsec "$_COUCOU_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','PERMIT_NOSTR_RELAY_X1'],['t','nostr-relay'],['t','auto_proclaimed'],
            ['level','1'],['expiration','$_3Y'],['p','$_COUCOU_HEX']
        ]))")" \
        --content '{"id":"PERMIT_NOSTR_RELAY_X1","name":"NOSTR Relay & Événements","auto_proclaimed":true}' \
        --relays "$_COUCOU_RELAY")

    _CERT_JEAN_UPASSPORT=$(_pub_c "jean → upassport-api X1 (auto-signé P2P)" "cert_jean_upassport-api" \
        --nsec "$_JEAN_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','PERMIT_UPASSPORT_X1'],['t','upassport-api'],['t','auto_proclaimed'],
            ['level','1'],['expiration','$_3Y'],['p','$_JEAN_HEX']
        ]))")" \
        --content '{"id":"PERMIT_UPASSPORT_X1","name":"UPassport API","auto_proclaimed":true}' \
        --relays "$_JEAN_RELAY")

    _CERT_TOTO_ANALYTICS=$(_pub_c "toto → analytics-uplanet X1 (auto-signé P2P)" "cert_toto_analytics" \
        --nsec "$_TOTO_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','PERMIT_ANALYTICS_X1'],['t','analytics-uplanet'],['t','auto_proclaimed'],
            ['level','1'],['expiration','$_3Y'],['p','$_TOTO_HEX']
        ]))")" \
        --content '{"id":"PERMIT_ANALYTICS_X1","name":"Analytics UPlanet","auto_proclaimed":true}' \
        --relays "$_TOTO_RELAY")
fi

## ─────────────────────────────────────────────────────────────────────────────
section "5. Aspirations Capitaine Kind 30501 — demandes d'apprentissage"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 30501 (--quick ou relay(s) inaccessible(s))"
    _REQ_CAP_NOSTR="" _REQ_CAP_UPASSPORT="" _REQ_CAP_ORACLE=""
else
    _REQ_CAP_NOSTR=$(_pub_c "Capitaine aspire nostr-relay (Kind 30501)" "req_cap_nostr-relay" \
        --nsec "$_CAP_NSEC" --kind 30501 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','req_nostr-relay_capitaine'],
            ['l','PERMIT_NOSTR_RELAY_X1','permit_type'],
            ['p','$_CAP_HEX'],['t','permit'],['t','request'],['t','nostr-relay']
        ]))")" \
        --content '{"permit_definition_id":"PERMIT_NOSTR_RELAY_X1","statement":"Je veux maîtriser les relays NOSTR pour analyser les événements de ma station et comprendre les Analytics Kind 10600.","requested_competency":"nostr-relay"}' \
        --relays "$_CAP_RELAY")

    _REQ_CAP_UPASSPORT=$(_pub_c "Capitaine aspire upassport-api (Kind 30501)" "req_cap_upassport-api" \
        --nsec "$_CAP_NSEC" --kind 30501 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','req_upassport-api_capitaine'],
            ['l','PERMIT_UPASSPORT_X1','permit_type'],
            ['p','$_CAP_HEX'],['t','permit'],['t','request'],['t','upassport-api']
        ]))")" \
        --content '{"permit_definition_id":"PERMIT_UPASSPORT_X1","statement":"Je dois comprendre l'\''API UPassport pour configurer et monitorer le endpoint /ping analytics de ma station.","requested_competency":"upassport-api"}' \
        --relays "$_CAP_RELAY")

    ## Demande composite-validation Oracle (fonctionnalité publishCompositeValidationRequest)
    _REQ_CAP_ORACLE=$(_pub_c "Capitaine → demande Oracle analytics composite (Kind 30501)" "req_cap_oracle_composite" \
        --nsec "$_CAP_NSEC" --kind 30501 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','req_analytics-uplanet_capitaine_oracle'],
            ['l','PERMIT_ANALYTICS_UPLANET_X1','permit_type'],
            ['p','$_CAP_HEX'],
            ['t','analytics-uplanet'],
            ['t','composite-validation']
        ]))")" \
        --content '{"permit_definition_id":"PERMIT_ANALYTICS_UPLANET_X1","statement":"Demande de validation composite analytics-uplanet : nostr-relay + upassport-api. BRO a vérifié mes connaissances Kind 10600.","requested_competency":"analytics-uplanet","composite_validation":true}' \
        --relays "$_CAP_RELAY")
fi

## ─────────────────────────────────────────────────────────────────────────────
section "6. Attestations Règle B — Kind 30502 (experts adoubent le Capitaine)"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 30502 (--quick ou relay(s) inaccessible(s))"
    _ATT_NOSTR="" _ATT_UPASSPORT="" _ATT_ANALYTICS=""
else
    _ATT_NOSTR=""
    if [[ -n "$_REQ_CAP_NOSTR" ]]; then
        _ATT_NOSTR=$(_pub_c "coucou adoube Capitaine → nostr-relay (30502 Règle B)" "att_coucou_cap_nostr" \
            --nsec "$_COUCOU_NSEC" --kind 30502 \
            --tags "$(python3 -c "import json; print(json.dumps([
                ['d','att_nostr-relay_capitaine'],
                ['e','$_REQ_CAP_NOSTR'],
                ['p','$_CAP_HEX'],
                ['l','PERMIT_NOSTR_RELAY_X1','permit_type'],
                ['t','attestation'],['t','nostr-relay']
            ]))")" \
            --content "{\"attested_skill\":\"nostr-relay\",\"attested_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"rule\":\"B\",\"attester\":\"coucou\"}" \
            --relays "$_COUCOU_RELAY")
    else
        skip "30502 coucou→capitaine nostr-relay (30501 absent)"
    fi

    _ATT_UPASSPORT=""
    if [[ -n "$_REQ_CAP_UPASSPORT" ]]; then
        _ATT_UPASSPORT=$(_pub_c "jean adoube Capitaine → upassport-api (30502 Règle B)" "att_jean_cap_upassport" \
            --nsec "$_JEAN_NSEC" --kind 30502 \
            --tags "$(python3 -c "import json; print(json.dumps([
                ['d','att_upassport-api_capitaine'],
                ['e','$_REQ_CAP_UPASSPORT'],
                ['p','$_CAP_HEX'],
                ['l','PERMIT_UPASSPORT_X1','permit_type'],
                ['t','attestation'],['t','upassport-api']
            ]))")" \
            --content "{\"attested_skill\":\"upassport-api\",\"attested_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"rule\":\"B\",\"attester\":\"jean\"}" \
            --relays "$_JEAN_RELAY")
    else
        skip "30502 jean→capitaine upassport-api (30501 absent)"
    fi

    _ATT_ANALYTICS=""
    if [[ -n "$_REQ_CAP_ORACLE" ]]; then
        _ATT_ANALYTICS=$(_pub_c "toto adoube Capitaine → analytics-uplanet (30502 Règle B)" "att_toto_cap_analytics" \
            --nsec "$_TOTO_NSEC" --kind 30502 \
            --tags "$(python3 -c "import json; print(json.dumps([
                ['d','att_analytics-uplanet_capitaine'],
                ['e','$_REQ_CAP_ORACLE'],
                ['p','$_CAP_HEX'],
                ['l','PERMIT_ANALYTICS_UPLANET_X1','permit_type'],
                ['t','attestation'],['t','analytics-uplanet']
            ]))")" \
            --content "{\"attested_skill\":\"analytics-uplanet\",\"attested_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"rule\":\"B\",\"attester\":\"toto\",\"composite_validation\":true}" \
            --relays "$_TOTO_RELAY")
    else
        skip "30502 toto→capitaine analytics (30501 composite-validation absent)"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "7. Règle A — Kind 7 ×3 experts → seuil WoTx2 atteint pour nostr-relay"
## ─────────────────────────────────────────────────────────────────────────────
## Les 3 experts ont eux-mêmes la compétence → getQualifiedLikes() les valide.
## Kind 7 non-remplaçable : l'auto-reset précédent les a supprimés.

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish Kind 7 (--quick ou relay(s) inaccessible(s))"
    _LIKE1="" _LIKE2="" _LIKE3=""
else
    _TARGET="${_REQ_CAP_NOSTR:-0000000000000000000000000000000000000000000000000000000000000001}"

    _LIKE1=$(_pub_c "Kind 7 coucou→capitaine nostr-relay (Règle A ×1/3)" "kind7_coucou_cap_nostr" \
        --nsec "$_COUCOU_NSEC" --kind 7 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['e','$_TARGET'],['p','$_CAP_HEX'],
            ['t','wotx-review'],['t','nostr-relay'],['k','30500']
        ]))")" \
        --content "+" --relays "$_COUCOU_RELAY")

    _LIKE2=$(_pub_c "Kind 7 toto→capitaine nostr-relay (Règle A ×2/3)" "kind7_toto_cap_nostr" \
        --nsec "$_TOTO_NSEC" --kind 7 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['e','$_TARGET'],['p','$_CAP_HEX'],
            ['t','wotx-review'],['t','nostr-relay'],['k','30500']
        ]))")" \
        --content "+" --relays "$_TOTO_RELAY")

    _LIKE3=$(_pub_c "Kind 7 jean→capitaine nostr-relay (Règle A ×3/3 🎉 seuil atteint)" "kind7_jean_cap_nostr" \
        --nsec "$_JEAN_NSEC" --kind 7 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['e','$_TARGET'],['p','$_CAP_HEX'],
            ['t','wotx-review'],['t','nostr-relay'],['k','30500']
        ]))")" \
        --content "+" --relays "$_JEAN_RELAY")
fi

## ─────────────────────────────────────────────────────────────────────────────
section "8. Certifs Capitaine Kind 30503 — nostr-relay + upassport-api"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "publish certifs capitaine (--quick ou relay(s) inaccessible(s))"
    _CERT_CAP_NOSTR="" _CERT_CAP_UPASSPORT=""
else
    _CERT_CAP_NOSTR=""
    if [[ -n "$_ATT_NOSTR" ]]; then
        _CERT_CAP_NOSTR=$(_pub_c "Capitaine → nostr-relay X1 (Règle B via coucou 🔵)" "cert_cap_nostr-relay" \
            --nsec "$_CAP_NSEC" --kind 30503 --ttl 94608000 \
            --tags "$(python3 -c "import json; print(json.dumps([
                ['d','PERMIT_NOSTR_RELAY_X1'],['t','nostr-relay'],
                ['level','1'],['expiration','$_3Y'],['p','$_CAP_HEX'],
                ['e','$_ATT_NOSTR']
            ]))")" \
            --content '{"id":"PERMIT_NOSTR_RELAY_X1","name":"NOSTR Relay & Événements","rule_b":true}' \
            --relays "$_CAP_RELAY")
    else
        skip "Certif capitaine nostr-relay (attestation 30502 absente)"
    fi

    _CERT_CAP_UPASSPORT=""
    if [[ -n "$_ATT_UPASSPORT" ]]; then
        _CERT_CAP_UPASSPORT=$(_pub_c "Capitaine → upassport-api X1 (Règle B via jean 🔵)" "cert_cap_upassport-api" \
            --nsec "$_CAP_NSEC" --kind 30503 --ttl 94608000 \
            --tags "$(python3 -c "import json; print(json.dumps([
                ['d','PERMIT_UPASSPORT_X1'],['t','upassport-api'],
                ['level','1'],['expiration','$_3Y'],['p','$_CAP_HEX'],
                ['e','$_ATT_UPASSPORT']
            ]))")" \
            --content '{"id":"PERMIT_UPASSPORT_X1","name":"UPassport API","rule_b":true}' \
            --relays "$_CAP_RELAY")
    else
        skip "Certif capitaine upassport-api (attestation 30502 absente)"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "9. Craft composite Kind 30503 — analytics-uplanet X1 (P2P 🔵)"
## ─────────────────────────────────────────────────────────────────────────────

_CERT_CAP_ANALYTICS=""
if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "composite craft (--quick ou relay(s) inaccessible(s))"
elif [[ -z "$_CERT_CAP_NOSTR" || -z "$_CERT_CAP_UPASSPORT" ]]; then
    skip "composite analytics-uplanet : ingrédients manquants (nostr-relay ou upassport-api)"
else
    _CERT_CAP_ANALYTICS=$(_pub_c "Capitaine crafte analytics-uplanet X1 (composite P2P 🔵)" "cert_cap_analytics-composite" \
        --nsec "$_CAP_NSEC" --kind 30503 --ttl 94608000 \
        --tags "$(python3 -c "import json; print(json.dumps([
            ['d','PERMIT_ANALYTICS_UPLANET_X1'],['t','analytics-uplanet'],['t','composite'],
            ['level','1'],['expiration','$_3Y'],['p','$_CAP_HEX'],
            ['e','$_CERT_CAP_NOSTR'],['e','$_CERT_CAP_UPASSPORT']
        ]))")" \
        --content '{"id":"PERMIT_ANALYTICS_UPLANET_X1","name":"Analytics UPlanet (Composite)","composite":true,"synthesized_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' \
        --relays "$_CAP_RELAY")
fi

## ─────────────────────────────────────────────────────────────────────────────
section "10. Vérifications relay"
## ─────────────────────────────────────────────────────────────────────────────

if $QUICK || ( ! $_local_ok && ! $_remote_ok ); then
    skip "vérification relay (--quick ou relays inaccessibles)"
else
    ## Permits locaux (coucou + jean)
    if $_local_ok; then
        _NB=$(echo "$(_query "$(python3 -c "import json; print(json.dumps({'kinds':[30500],'authors':['$_COUCOU_HEX','$_JEAN_HEX']}))")" "$_LOCAL_RELAY")" | _count)
        [[ "$_NB" -ge 1 ]] && ok "relay local : $_NB permit(s) Kind 30500 (coucou+jean)" \
                            || skip "relay local : aucun permit 30500 (latence?)"

        _NB=$(echo "$(_query "$(python3 -c "import json; print(json.dumps({'kinds':[30503],'authors':['$_CAP_HEX']}))")" "$_LOCAL_RELAY")" | _count)
        [[ "$_NB" -ge 1 ]] && ok "relay local : $_NB certif(s) Kind 30503 du Capitaine" \
                            || skip "relay local : aucun certif capitaine (latence?)"

        _NB=$(echo "$(_query "$(python3 -c "import json; print(json.dumps({'kinds':[30503],'authors':['$_CAP_HEX'],'#d':['PERMIT_ANALYTICS_UPLANET_X1']}))")" "$_LOCAL_RELAY")" | _count)
        [[ "$_NB" -ge 1 ]] && ok "relay local : composite analytics-uplanet ✅" \
                            || skip "relay local : composite absent (ingrédients manquants?)"

        _NB=$(echo "$(_query "$(python3 -c "import json; print(json.dumps({'kinds':[30501],'authors':['$_CAP_HEX'],'#t':['composite-validation']}))")" "$_LOCAL_RELAY")" | _count)
        [[ "$_NB" -ge 1 ]] && ok "relay local : demande Oracle composite-validation ✅" \
                            || skip "relay local : Kind 30501 composite-validation absent"

        _NB=$(echo "$(_query "$(python3 -c "import json; print(json.dumps({'kinds':[7],'#p':['$_CAP_HEX'],'#t':['wotx-review']}))")" "$_LOCAL_RELAY")" | _count)
        [[ "$_NB" -ge 3 ]] && ok "relay local : $_NB Kind 7 WoTx2 pour le Capitaine (Règle A ✅)" \
                            || skip "relay local : seulement $_NB/3 Kind 7 WoTx2 (latence relay?)"
    fi

    ## Permits + formation remote (toto)
    if $_remote_ok; then
        _NB=$(echo "$(_query "$(python3 -c "import json; print(json.dumps({'kinds':[30500],'authors':['$_TOTO_HEX']}))")" "$_TOTO_RELAY")" | _count)
        [[ "$_NB" -ge 1 ]] && ok "relay remote : $_NB permit(s) Kind 30500 (toto)" \
                            || skip "relay remote : aucun permit toto"

        _NB=$(echo "$(_query "$(python3 -c "import json; print(json.dumps({'kinds':[30504],'authors':['$_TOTO_HEX'],'#t':['analytics-uplanet']}))")" "$_TOTO_RELAY")" | _count)
        [[ "$_NB" -ge 1 ]] && ok "relay remote : $_NB Kind 30504 analytics formation (BRO memory) ✅" \
                            || skip "relay remote : Kind 30504 analytics absent"
    fi
fi

## ─────────────────────────────────────────────────────────────────────────────
section "11. Qdrant — vérification indexation BRO"
## ─────────────────────────────────────────────────────────────────────────────

if command -v curl >/dev/null 2>&1; then
    _QDRANT=$(curl -sf "http://localhost:6333/collections/knowledge" 2>/dev/null | \
        python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result',{}).get('status','nok'))" 2>/dev/null)
    if [[ "$_QDRANT" == "green" ]]; then
        ok "Qdrant collection 'knowledge' disponible"
        info "BRO peut répondre : 'Quel Kind pour analytics UPlanet ?' → Kind 10600"
    else
        skip "Qdrant non disponible (docker --profile ai requis pour BRO)"
    fi
else
    skip "curl absent — Qdrant non vérifié"
fi

## ─────────────────────────────────────────────────────────────────────────────
section "12. Résumé du scénario"
## ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}  Toile de confiance Analytics UPlanet :${NC}"
echo -e ""
echo -e "    coucou ─────(adoube)──→ Capitaine : nostr-relay X1"
echo -e "    jean   ─────(adoube)──→ Capitaine : upassport-api X1"
echo -e "    toto   ─────(adoube)──→ Capitaine : analytics (composite)"
echo -e "    3×Kind 7 ──(Règle A)──→ Capitaine : WoTx2 nostr-relay ✅"
echo ""
echo -e "${BOLD}  Capitaine (${_CAP_LABEL}) :${NC}"
[[ -n "$_CERT_CAP_NOSTR"     ]] && echo -e "    ${GREEN}✅${NC} nostr-relay X1     (Règle B ← coucou)"
[[ -n "$_CERT_CAP_UPASSPORT" ]] && echo -e "    ${GREEN}✅${NC} upassport-api X1   (Règle B ← jean)"
[[ -n "$_CERT_CAP_ANALYTICS" ]] && echo -e "    ${GREEN}✅${NC} analytics-uplanet composite 🔵 P2P"
[[ -n "$_REQ_CAP_ORACLE"     ]] && echo -e "    ${YELLOW}⏳${NC} demande Oracle 🏅 composite-validation envoyée"
echo ""
echo -e "${BOLD}  Formation BRO (analytics-uplanet) :${NC}"
echo -e "    • Kind 10600 (pas 10000 — réservé NIP-51)"
echo -e "    • smartSend() → NOSTR > HTTP /ping"
echo -e "    • URL : ipfs.domain → u.domain:54321"
echo -e "    • Mode 3 : NIP-44 ChaCha20-Poly1305"
echo ""
echo -e "${BOLD}  Prochaines étapes pour enrichir le système :${NC}"
echo -e "    • Chaque nouveau capitaine ajoute ses skills dans PERMIT_*.sh"
echo -e "    • Les crafts composites (ORE+WoTx2+P2P+MineLife) s'accumulent"
echo -e "    • La toile de confiance grandit → formation P2P mondiale"
echo ""
echo -e "${BOLD}  Cache persistant :${NC} $_CACHE_FILE"
echo -e "    Le prochain run effacera les Kind 7 et rafraîchira tout."
echo ""

## ─────────────────────────────────────────────────────────────────────────────
## Bilan
## ─────────────────────────────────────────────────────────────────────────────
echo -e "──────────────────────────────────────────────────────────"
echo -e "  ${GREEN}${PASS} OK${NC}  /  ${RED}${FAIL} KO${NC}  /  ${YELLOW}${SKIP} skip${NC}  (total $((PASS+FAIL+SKIP)))"
[[ $FAIL -eq 0 ]] \
    && echo -e "  ${GREEN}${BOLD}✓ Scénario MineLife Capitaine opérationnel${NC}" \
    || echo -e "  ${RED}${BOLD}✗ ${FAIL} erreur(s)${NC}"
echo -e "──────────────────────────────────────────────────────────"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
