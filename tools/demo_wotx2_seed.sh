#!/usr/bin/env bash
# demo_wotx2_seed.sh — Graine de données WoTx2 pour les comptes demo (toto/coucou/jean)
#
# Pré-requis : install.sh doit avoir été exécuté — les clés sont dans ~/.zen/demo/*.keys
#
# Publie pour chaque persona :
#   - Kind 30503 : compétences (skills)
#   - Kind 30505 : objets (4 régimes de quantité couverts)
#   - Kind 30500 : crafts collectifs (min_operators > 1)
#   - Kind 1505  : quelques transactions pour initialiser l'historique
#
# Scénarios couverts :
#   A. Sound-spot festival  → RPi(durability) + câbles(discrete) + enceinte(durability)
#   B. Communs / cabane     → Cabane-33(capacity) + outillage(discrete)
#   C. Savoir partagé       → Guide sound-spot(infinite) + Guide menuiserie(infinite)
#   D. Craft multi-op       → "Installation Sound-Spot" (min_operators=2 toto+jean)
#
# Usage : demo_wotx2_seed.sh [--relay ws://127.0.0.1:7777] [--dry-run]
# Author: Fred (support@qo-op.com) — AGPL-3.0

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "${MY_PATH}" && pwd)"

. "${MY_PATH}/my.sh"

##########################################################################
## Options
##########################################################################
_RELAY="${NOSTR_RELAY_WS:-ws://127.0.0.1:7777}"
_DRY_RUN=0

for _arg in "$@"; do
    case "$_arg" in
        --relay=*)   _RELAY="${_arg#*=}" ;;
        --relay)     shift; _RELAY="${1:-$_RELAY}" ;;
        --dry-run)   _DRY_RUN=1 ;;
    esac
done

_PY="${HOME}/.astro/bin/python3"
[[ ! -x "$_PY" ]] && _PY="python3"

_INTERCOM="${MY_PATH}/nostr_node_intercom.py"
_DEMO_DIR="$HOME/.zen/demo"

if [[ ! -d "$_DEMO_DIR" ]]; then
    echo "ERROR: répertoire $_DEMO_DIR introuvable." >&2
    echo "       Exécutez d'abord install.sh pour créer les comptes demo." >&2
    exit 1
fi

##########################################################################
## Helpers
##########################################################################
_pub() {
    # _pub NSEC KIND CONTENT TAGS
    local _nsec="$1" _kind="$2" _content="$3" _tags="$4"
    if (( _DRY_RUN )); then
        echo "[DRY] kind=${_kind} content=${_content:0:60}…"
        return 0
    fi
    "$_PY" "$_INTERCOM" publish \
        --nsec "$_nsec" \
        --kind "$_kind" \
        --content "$_content" \
        --tags "$_tags" \
        --relays "$_RELAY" 2>/dev/null
}

_load_keys() {
    # _load_keys NAME → sets _NSEC _NPUB _EMAIL
    local _f="${_DEMO_DIR}/${1}.keys"
    if [[ ! -s "$_f" ]]; then
        echo "  ⚠️  Clés manquantes pour $1 (${_f}) — ignoré" >&2
        return 1
    fi
    _NSEC=$(grep "^NSEC=" "$_f" | cut -d= -f2)
    _NPUB=$(grep "^NPUB=" "$_f" | cut -d= -f2)
    _EMAIL=$(grep "^EMAIL=" "$_f" | cut -d= -f2)
}

_slug() {
    # Normalise un titre en slug pour le d-tag
    echo "$1" | tr '[:upper:]' '[:lower:]' \
        | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
        | sed 's/[^a-z0-9]/-/g;s/-\+/-/g;s/^-//;s/-$//'
}

##########################################################################
## Banner
##########################################################################
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🌱 GRAINE WoTx2 — toto/coucou/jean/marie/ali/sophie        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Relay : ${_RELAY:0:52}$(printf '%*s' $((52-${#_RELAY})) '')  ║"
(( _DRY_RUN )) && echo "║  MODE : DRY-RUN (aucune publication)                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

##########################################################################
## 1. Charger les clés
##########################################################################
declare -A NSEC NPUB EMAIL
for _name in toto coucou jean marie ali sophie; do
    if _load_keys "$_name"; then
        NSEC[$_name]="$_NSEC"
        NPUB[$_name]="$_NPUB"
        EMAIL[$_name]="$_EMAIL"
        echo "  ✅ $_name — ${EMAIL[$_name]}"
    else
        echo "  ⚠️  $_name — clés absentes (optionnel, sera ignoré)"
    fi
done
echo ""

##########################################################################
## 2. SKILLS (Kind 30503)
## toto   : linux x1, bash x1, sound-spot x1
## coucou : docker x1, linux x1, nostr x1
## jean   : astroport x1, ipfs x1, nostr x1, git x1
##########################################################################
echo "── Skills (Kind 30503) ──────────────────────────────────────"

declare -A SKILLS=(
    ["toto"]="linux:1:🐧:Administration système Linux|bash:1:🔧:Scripting bash|sound-spot:1:🔊:Setup et configuration sound-spot RPi"
    ["coucou"]="docker:1:🐳:Orchestration de conteneurs|linux:1:🐧:Administration système|nostr:1:⚡:Protocole NOSTR et relays"
    ["jean"]="astroport:1:⚓:Station décentralisée Astroport|ipfs:1:📦:Stockage IPFS et IPNS|nostr:1:⚡:Relays et events NOSTR|git:1:🌿:Versioning Git|mecanique-velo:1:🔧:Entretien et réparation vélos et trottinettes"
)

for _name in toto coucou jean; do
    [[ -z "${NSEC[$_name]:-}" ]] && continue
    IFS='|' read -ra _skill_list <<< "${SKILLS[$_name]}"
    for _entry in "${_skill_list[@]}"; do
        IFS=':' read -r _sk _lv _ic _desc <<< "$_entry"
        _sk_norm=$(echo "$_sk" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
        _permit="PERMIT_$(echo "$_sk_norm" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_X${_lv}"
        _content="{\"skill\":\"${_sk_norm}\",\"level\":${_lv},\"icon\":\"${_ic}\",\"description\":\"${_desc}\",\"auto_proclaimed\":true}"
        _tags="[[\"d\",\"${_permit}\"],[\"l\",\"${_permit}\",\"permit_type\"],[\"level\",\"${_lv}\"],[\"t\",\"${_sk_norm}\"],[\"t\",\"auto_proclaimed\"],[\"summary\",\"${_desc}\"]]"
        _id=$(_pub "${NSEC[$_name]}" 30503 "$_content" "$_tags")
        [[ -n "$_id" ]] && echo "  ✅ ${_name} :: ${_sk_norm} x${_lv} → ${_id:0:16}…" \
                        || echo "  ⚠️  ${_name} :: ${_sk_norm} — publication échouée"
    done
done
echo ""

##########################################################################
## 3. OBJETS (Kind 30505) — 4 régimes + 2 scénarios
##
## Scénario A — Sound-spot festival (toto)
##   a1. RPi Zero 2W       → durability  / portable  / rep=7
##   a2. Câbles XLR 5m ×4  → discrete    / portable  / rep=3
##   a3. Enceinte JBL       → durability  / portable  / rep=5
##
## Scénario B — Communs / Cabane (jean)
##   b1. Cabane-33          → capacity   / fixed     / rep=9 / min_op=2
##   b2. Scie circulaire    → durability / portable  / rep=6
##   b3. Visserie bois 5mm  → discrete   / portable  / rep=1
##
## Scénario C — Savoir partagé (coucou + jean)
##   c1. Guide sound-spot   → infinite   / fixed     / rep=10
##   c2. Guide menuiserie   → infinite   / fixed     / rep=10
##########################################################################
echo "── Objets (Kind 30505) ──────────────────────────────────────"

_publish_object() {
    # args : OWNER TITLE TYPE QT QTY UNIT MOBILITY REP MIN_OP DESC [GEO] [DOMAIN]
    local _owner="$1" _title="$2" _type="$3" _qt="$4" _qty="$5"
    local _unit="$6" _mob="$7" _rep="$8" _minop="$9" _desc="${10}" _geo="${11:-}" _domain="${12:-}"
    [[ -z "${NSEC[$_owner]:-}" ]] && return

    local _dtag; _dtag="$(_slug "$_title")-$$"
    local _title_e; _title_e=$(echo "$_title" | sed 's/"/\\"/g')
    local _unit_e;  _unit_e=$(echo "$_unit"   | sed 's/"/\\"/g')
    local _desc_e;  _desc_e=$(echo "$_desc"   | sed 's/"/\\"/g')
    local _now; _now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    local _tags="[[\"d\",\"${_dtag}\"],[\"title\",\"${_title_e}\"],[\"t\",\"${_type}\"],[\"t\",\"${_mob}\"],[\"t\",\"${_qt}\"],[\"quantity\",\"${_qty}\"],[\"quantity_unit\",\"${_unit_e}\"],[\"durability\",\"100\"],[\"repairability\",\"${_rep}\"]"
    (( _minop > 1 )) && _tags="${_tags},[\"min_operators\",\"${_minop}\"]"
    [[ -n "$_geo" ]]    && _tags="${_tags},[\"geo\",\"${_geo}\"]"
    [[ -n "$_domain" ]] && _tags="${_tags},[\"t\",\"${_domain}\"]"
    _tags="${_tags}]"

    local _content="{\"title\":\"${_title_e}\",\"type\":\"${_type}\",\"quantity_type\":\"${_qt}\",\"quantity\":${_qty},\"quantity_unit\":\"${_unit_e}\",\"mobility\":\"${_mob}\",\"repairability\":${_rep},\"min_operators\":${_minop},\"durability\":100,\"condition\":\"new\",\"description\":\"${_desc_e}\",\"created_at\":\"${_now}\"}"
    [[ -n "$_geo" ]] && _content="${_content%\}},\"geo\":\"${_geo}\"}"

    local _id; _id=$(_pub "${NSEC[$_owner]}" 30505 "$_content" "$_tags")
    if [[ -n "$_id" ]]; then
        echo "  ✅ ${_owner} :: ${_title} [${_qt}] → d=${_dtag:0:20}… id=${_id:0:16}…"
        # Sauvegarder le dtag pour l'historique (Kind 1505) ci-dessous
        echo "$_dtag" >> "${_DEMO_DIR}/${_owner}_dtags.tmp"
        echo "${_id}:${_dtag}:${_title}" >> "${_DEMO_DIR}/demo_objects.index"
    else
        echo "  ⚠️  ${_owner} :: ${_title} — publication échouée"
    fi
}

# Nettoyage index temporaires
rm -f "${_DEMO_DIR}"/*_dtags.tmp "${_DEMO_DIR}/demo_objects.index"

# Scénario A — sound-spot (toto)
_publish_object toto "RPi Zero 2W sound-spot" object durability 1 "pièce" portable 7 1 "Raspberry Pi Zero 2W configuré comme nœud sound-spot WiFi"
_publish_object toto "Câbles XLR 5m" material discrete 4 "pièce" portable 3 1 "Câbles XLR mâle-femelle pour liaisons audio scène"
_publish_object toto "Enceinte JBL EON615" tool durability 1 "pièce" portable 5 1 "Enceinte amplifiée 15 pouces pour diffusion festival"

# Scénario B — cabane / communs (jean)
_publish_object jean "Cabane-33" place capacity 8 "places" fixed 9 2 "Cabane en bois 8 couchages — bien commun géré en WoTx2" "44,0"
_publish_object jean "Scie circulaire Makita" tool durability 1 "pièce" portable 6 1 "Scie circulaire 165mm pour chantiers bois"
_publish_object jean "Visserie bois 5mm×60" material discrete 200 "pièces" portable 1 1 "Vis à bois tête fraisée inox — consommable chantier"

# Scénario C — savoir partagé
_publish_object coucou "Guide sound-spot" document infinite 1 "doc" fixed 10 1 "Documentation complète d'installation et configuration d'un nœud sound-spot RPi"
_publish_object jean "Guide menuiserie cabane" document infinite 1 "doc" fixed 10 1 "Plans et protocoles de construction d'une cabane bois 8 places"

# Scénario D — Habitat passif (jean)
_publish_object jean \
    "Dôme Rocket 4.1" place capacity 2 "personnes" fixed 9 3 \
    "Dôme ovoïde 4.9m², coque draps/ciment, isolation liège 15cm, ESP32 Meshtastic, budget ~780€" \
    "44,0" "habitat"
_publish_object jean \
    "Kit ESP32 Meshtastic" tool durability 1 "kit" portable 6 1 \
    "ESP32 + LoRa pour domotique autonome, portée 2-5km sans internet" \
    "" "numérique"

# Scénario E — Circuit court alimentaire (toto)
_publish_object toto \
    "Jardin partagé 30m²" place capacity 6 "parcelles" fixed 8 2 \
    "Espace maraîcher partagé — 6 parcelles de 5m² en rotation" \
    "" "culture"
_publish_object toto \
    "Semences tomates cerises" material discrete 50 "graines" portable 0 1 \
    "Semences paysannes non hybrides, variété Cerise Rouge" \
    "" "culture"
_publish_object toto \
    "Marmite norvégienne" tool durability 1 "pièce" portable 8 1 \
    "Cuiseur lent isolant : marmite dans glacière, économise 80% d'énergie" \
    "" "cuisine"

# Scénario F — Transport (jean)
_publish_object jean \
    "Voiture partagée 5 places" tool capacity 5 "places" portable 6 1 \
    "Citroën Ami électrique — 5 places, usage partagé sur réservation" \
    "" "transport"
# Ajouter le tag skill_required manuellement dans les tags étendus
# (note: _publish_object ne supporte pas encore skill_required nativement)
_publish_object jean \
    "Vélo cargo électrique" tool durability 1 "pièce" portable 7 1 \
    "Vélo cargo longtail — livraisons AMAP et covoiturage doux" \
    "" "transport"
_publish_object jean \
    "Remorque vélo" tool durability 1 "pièce" portable 8 1 \
    "Remorque vélo 80L pour courses AMAP et chantiers légers" \
    "" "transport"

echo ""

##########################################################################
## 4. CRAFTS collectifs (Kind 30500)
## Craft 1 : Installation Sound-Spot Festival (min_op=2, toto+jean)
## Craft 2 : Entretien Cabane-33 mensuel   (min_op=2, jean+coucou)
##########################################################################
echo "── Crafts collectifs (Kind 30500) ───────────────────────────"

_publish_craft() {
    local _owner="$1" _title="$2" _minop="$3" _skills="$4" _time="$5" _desc="$6"
    [[ -z "${NSEC[$_owner]:-}" ]] && return

    local _dtag; _dtag="craft-$(_slug "$_title")"
    local _title_e; _title_e=$(echo "$_title" | sed 's/"/\\"/g')
    local _desc_e;  _desc_e=$(echo "$_desc"   | sed 's/"/\\"/g')

    # Tags : d, title, t (craft), min_operators, estimated_time, skill tags
    local _tags="[[\"d\",\"${_dtag}\"],[\"title\",\"${_title_e}\"],[\"t\",\"craft\"],[\"min_operators\",\"${_minop}\"],[\"estimated_time\",\"${_time}\"]"
    IFS=',' read -ra _sk_list <<< "$_skills"
    for _sk in "${_sk_list[@]}"; do
        _tags="${_tags},[\"t\",\"${_sk}\"]"
    done
    _tags="${_tags}]"

    local _content="{\"title\":\"${_title_e}\",\"description\":\"${_desc_e}\",\"min_operators\":${_minop},\"estimated_time\":\"${_time}\",\"skills\":[$(echo "$_skills" | sed 's/,/","/g;s/^/"/;s/$/"/')] }"

    local _id; _id=$(_pub "${NSEC[$_owner]}" 30500 "$_content" "$_tags")
    [[ -n "$_id" ]] && echo "  ✅ ${_owner} :: ${_title} (${_minop} op.) → ${_id:0:16}…" \
                    || echo "  ⚠️  ${_owner} :: ${_title} — publication échouée"
}

_publish_craft toto \
    "Installation Sound-Spot Festival" 2 \
    "linux,sound-spot,bash" "4h" \
    "Déploiement complet d'un nœud sound-spot RPi Zero 2W : flash SD, config réseau WiFi AP, Snapcast, Icecast, intégration NOSTR"

_publish_craft jean \
    "Entretien mensuel Cabane-33" 2 \
    "astroport,linux" "3h" \
    "Maintenance mensuelle collective : inspection structure, nettoyage, vérification équipements, mise à jour inventaire NOSTR"

_publish_craft coucou \
    "Session formation NOSTR+WoTx2" 2 \
    "nostr,docker,linux" "2h" \
    "Atelier peer-to-peer : installation relay, création MULTIPASS, publication skills et objets, attestations croisées"

_publish_craft jean \
    "Construction Dôme Rocket 4.1" 3 \
    "linux,bash,construction" "10 jours" \
    "Chantier collectif : terrassement, muret pierres, coque draps/ciment, isolation liège, domotique ESP32"

_publish_craft toto \
    "Distribution AMAP hebdomadaire" 2 \
    "linux" "2h" \
    "Répartition et livraison des paniers légumes entre les membres de l'AMAP"

_publish_craft jean \
    "Covoiturage livraison AMAP" 2 \
    "linux,permis-conduire-vehicule" "2h" \
    "Tournée hebdomadaire de distribution des paniers AMAP en covoiturage"

echo ""

##########################################################################
## 4b. FRICTION DÉMO (Kind 1984) — coucou → jean (voiture partagée)
##########################################################################
echo "── Friction démo (Kind 1984) ─────────────────────────────────"

if [[ -n "${NSEC[coucou]:-}" && -n "${NPUB[jean]:-}" ]]; then
    _friction_content="Friction déclarée : utilisation voiture partagée sans permis x2 validé. Demande de médiation N1."
    _friction_tags="[[\"report-type\",\"friction\"],[\"p\",\"${NPUB[jean]}\"],[\"t\",\"transport\"],[\"skill\",\"permis-conduire-vehicule\"],[\"reason\",\"Permis x2 requis non atteint pour voiture électrique\"]]"
    _fid=$(_pub "${NSEC[coucou]}" 1984 "$_friction_content" "$_friction_tags")
    [[ -n "$_fid" ]] && echo "  ✅ coucou → friction déclarée contre jean → event_id=${_fid:0:16}…" \
                     || echo "  ⚠️  coucou → publication friction échouée"
else
    echo "  ⚠️  Clés coucou ou NPUB jean manquantes — friction non publiée"
fi

echo ""

##########################################################################
## 5. HISTORIQUE (Kind 1505) — quelques deltas pour animer les objets
##    On lit les dtags depuis l'index créé à l'étape 3
##########################################################################
echo "── Historique transactions (Kind 1505) ──────────────────────"

if [[ -s "${_DEMO_DIR}/demo_objects.index" ]]; then
    while IFS=':' read -r _eid _dtag _otitle; do
        # Identifier le propriétaire depuis son tmp file
        _owner=""
        for _n in toto coucou jean; do
            if [[ -s "${_DEMO_DIR}/${_n}_dtags.tmp" ]] && grep -q "^${_dtag}$" "${_DEMO_DIR}/${_n}_dtags.tmp" 2>/dev/null; then
                _owner="$_n"; break
            fi
        done
        [[ -z "$_owner" ]] && continue

        # Type de transaction selon le type d'objet (heuristique sur le titre)
        case "$_otitle" in
            *RPi*|*Enceinte*)
                # durability : usage simulé (−3 durability)
                _txtype="use" _dqty=0 _ddur=-3 _reason="Première mise en service test"
                ;;
            *Câbles*|*Visserie*)
                # discrete : consommation (−1 qty)
                _txtype="consumption" _dqty=-1 _ddur=0 _reason="Câbles utilisés lors du setup scène"
                ;;
            *Cabane*)
                # capacity : session d'occupation (−5 durability)
                _txtype="use" _dqty=0 _ddur=-5 _reason="Week-end chantier bois — 6 personnes, 2 jours"
                ;;
            *Guide*|*savoir*)
                # infinite : consultation (delta 0, note de lecture)
                _txtype="use" _dqty=0 _ddur=0 _reason="Documentation consultée lors de l'atelier formation"
                ;;
            *Scie*)
                # durability : maintenance (+10 durability)
                _txtype="maintenance" _dqty=0 _ddur=10 _reason="Affûtage lame + nettoyage complet"
                ;;
            *)
                continue
                ;;
        esac

        local _now; _now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        _tx_content="{\"type\":\"${_txtype}\",\"delta_quantity\":${_dqty},\"delta_durability\":${_ddur},\"reason\":\"${_reason}\",\"operators\":[\"${NPUB[$_owner]}\"],\"recorded_at\":\"${_now}\"}"
        _tx_tags="[[\"d\",\"${_dtag}\"],[\"e\",\"${_eid}\"],[\"t\",\"${_txtype}\"],[\"delta_quantity\",\"${_dqty}\"],[\"delta_durability\",\"${_ddur}\"]]"

        _tid=$(_pub "${NSEC[$_owner]}" 1505 "$_tx_content" "$_tx_tags")
        [[ -n "$_tid" ]] && echo "  ✅ ${_owner} :: ${_otitle:0:30} [${_txtype}] → ${_tid:0:16}…" \
                         || echo "  ⚠️  ${_owner} :: ${_otitle:0:30} — tx échouée"
    done < "${_DEMO_DIR}/demo_objects.index"
else
    echo "  ⚠️  Aucun objet indexé — étape 3 non exécutée ou relay indisponible"
fi

echo ""

##########################################################################
## 6. ATTESTATIONS CROISÉES (Kind 30503 peer → Règle B WoTx2)
##    jean atteste linux x1 pour toto (pair niveau x1+)
##    toto atteste nostr x1 pour coucou
##########################################################################
echo "── Attestations croisées (Kind 30503 peer) ──────────────────"

_attest() {
    # _attest ATTESTOR TARGET_NPUB SKILL LEVEL
    local _attor="$1" _target_pub="$2" _sk="$3" _lv="$4"
    [[ -z "${NSEC[$_attor]:-}" ]] && return
    local _sk_norm; _sk_norm=$(echo "$_sk" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    local _permit="PERMIT_$(echo "$_sk_norm" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_X${_lv}"
    local _content="{\"skill\":\"${_sk_norm}\",\"level\":${_lv},\"attested_for\":\"${_target_pub}\",\"auto_proclaimed\":false}"
    local _tags="[[\"d\",\"${_permit}\"],[\"l\",\"${_permit}\",\"permit_type\"],[\"level\",\"${_lv}\"],[\"t\",\"${_sk_norm}\"],[\"p\",\"${_target_pub}\"]]"
    local _id; _id=$(_pub "${NSEC[$_attor]}" 30503 "$_content" "$_tags")
    [[ -n "$_id" ]] && echo "  ✅ ${_attor} → ${_sk_norm} x${_lv} pour ${_target_pub:0:16}… → ${_id:0:16}…" \
                    || echo "  ⚠️  ${_attor} → attestation ${_sk_norm} échouée"
}

[[ -n "${NPUB[toto]:-}"   ]] && _attest jean   "${NPUB[toto]}"   linux  1
[[ -n "${NPUB[coucou]:-}" ]] && _attest toto   "${NPUB[coucou]}" nostr  1
[[ -n "${NPUB[jean]:-}"   ]] && _attest coucou "${NPUB[jean]}"   docker 1

echo ""

##########################################################################
## 8. PERSONAS ÉLARGIS — marie / ali / sophie
##    Objectif : couvrir les domaines Nature, Culture, Santé
##    et montrer des attestations croisées inter-domaines
##########################################################################
echo "── Personas élargis (Kind 30503/30505/30500) ───────────────"

declare -A SKILLS_EXT=(
    ["marie"]="permaculture:1:🌱:Conception de jardins en permaculture|apiculture:1:🐝:Gestion de ruches et récolte de miel|semences:1:🌻:Sélection et conservation des semences|maraichage:1:🥕:Production maraîchère bio"
    ["ali"]="musique:1:🎵:Composition et arrangement musical|chant:1:🎤:Techniques vocales et direction de chœur|son:1:🎚️:Prise de son et mixage|sound-spot:1:🔊:Configuration audio embarquée RPi"
    ["sophie"]="phytotherapie:1:🌿:Médecine par les plantes et tisanes|premiers-secours:1:🩺:Gestes de secourisme (PSC1)|yoga:1:🧘:Enseignement yoga et respiration|nutrition:1:🥦:Alimentation consciente et équilibrée"
)

for _name in marie ali sophie; do
    [[ -z "${NSEC[$_name]:-}" ]] && _load_keys "$_name" && { NSEC[$_name]="$_NSEC"; NPUB[$_name]="$_NPUB"; EMAIL[$_name]="$_EMAIL"; }
    [[ -z "${NSEC[$_name]:-}" ]] && { echo "  ❌ $_name — clés absentes (créez ${_DEMO_DIR}/${_name}.keys)"; continue; }
    echo "  ✅ $_name — ${EMAIL[$_name]:-inconnu}"
    IFS='|' read -ra _skill_list <<< "${SKILLS_EXT[$_name]}"
    for _entry in "${_skill_list[@]}"; do
        IFS=':' read -r _sk _lv _ic _desc <<< "$_entry"
        _sk_norm=$(echo "$_sk" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
        _permit="PERMIT_$(echo "$_sk_norm" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_X${_lv}"
        _content="{\"skill\":\"${_sk_norm}\",\"level\":${_lv},\"icon\":\"${_ic}\",\"description\":\"${_desc}\",\"auto_proclaimed\":true}"
        _tags="[[\"d\",\"${_permit}\"],[\"l\",\"${_permit}\",\"permit_type\"],[\"level\",\"${_lv}\"],[\"t\",\"${_sk_norm}\"],[\"t\",\"auto_proclaimed\"],[\"summary\",\"${_desc}\"]]"
        _id=$(_pub "${NSEC[$_name]}" 30503 "$_content" "$_tags")
        [[ -n "$_id" ]] && echo "    ✅ ${_sk_norm} x${_lv} → ${_id:0:16}…" || echo "    ⚠️  ${_sk_norm} — publication échouée"
    done
done
echo ""

# Objets des nouveaux personas
echo "── Objets élargis (Kind 30505) ──────────────────────────────"

# Marie — ruche (durability) + parcelle de semences (capacity) + guide permaculture (infinite)
if [[ -n "${NSEC[marie]:-}" ]]; then
    _pub "${NSEC[marie]}" 30505 \
        '{"title":"Ruche Warré #1","description":"Ruche Warré en bois de châtaignier, en service","quantity_type":"durability","quantity":1,"quantity_unit":"ruche","durability":85,"repairability":8,"mobility":"fixed","min_operators":1}' \
        '[[\"d\",\"ruche-warre-marie\"],[\"title\",\"Ruche Warré #1\"],[\"t\",\"nature\"],[\"t\",\"apiculture\"],[\"quantity_type\",\"durability\"],[\"quantity\",\"1\"],[\"durability\",\"85\"],[\"repairability\",\"8\"]]' && echo "  ✅ marie :: ruche-warre"
    _pub "${NSEC[marie]}" 30505 \
        '{"title":"Jardin de semences (6 parcelles)","description":"Parcelles dédiées à la sélection et multiplication des semences paysannes","quantity_type":"capacity","quantity":6,"quantity_unit":"parcelle","durability":90,"repairability":9,"mobility":"fixed","min_operators":1}' \
        '[[\"d\",\"jardin-semences-marie\"],[\"title\",\"Jardin de semences\"],[\"t\",\"nature\"],[\"t\",\"agriculture\"],[\"quantity_type\",\"capacity\"],[\"quantity\",\"6\"],[\"durability\",\"90\"],[\"repairability\",\"9\"]]' && echo "  ✅ marie :: jardin-semences"
    _pub "${NSEC[marie]}" 30505 \
        '{"title":"Guide Permaculture Zonale","description":"Guide pratique de conception par zones (0-5) et secteurs, librement réutilisable","quantity_type":"infinite","quantity":0,"quantity_unit":"guide","durability":100,"repairability":10,"mobility":"virtual","min_operators":1}' \
        '[[\"d\",\"guide-permaculture-marie\"],[\"title\",\"Guide Permaculture Zonale\"],[\"t\",\"nature\"],[\"t\",\"infinite\"],[\"quantity_type\",\"infinite\"]]' && echo "  ✅ marie :: guide-permaculture"
fi

# Ali — table de mixage (durability) + studio mobile (capacity)
if [[ -n "${NSEC[ali]:-}" ]]; then
    _pub "${NSEC[ali]}" 30505 \
        '{"title":"Table de mixage Behringer","description":"Mixette 12 canaux avec effets intégrés, pour événements ou ateliers","quantity_type":"durability","quantity":1,"quantity_unit":"table","durability":78,"repairability":5,"mobility":"portable","min_operators":1}' \
        '[[\"d\",\"table-mixage-ali\"],[\"title\",\"Table de mixage Behringer\"],[\"t\",\"culture\"],[\"t\",\"musique\"],[\"quantity_type\",\"durability\"],[\"quantity\",\"1\"],[\"durability\",\"78\"],[\"repairability\",\"5\"]]' && echo "  ✅ ali :: table-mixage"
    _pub "${NSEC[ali]}" 30505 \
        '{"title":"Studio mobile (3 postes DAW)","description":"3 postes DAW laptops + interfaces audio + micros — studio nomade pour ateliers","quantity_type":"capacity","quantity":3,"quantity_unit":"poste","durability":82,"repairability":6,"mobility":"portable","min_operators":1}' \
        '[[\"d\",\"studio-mobile-ali\"],[\"title\",\"Studio mobile\"],[\"t\",\"culture\"],[\"t\",\"son\"],[\"quantity_type\",\"capacity\"],[\"quantity\",\"3\"],[\"durability\",\"82\"],[\"repairability\",\"6\"]]' && echo "  ✅ ali :: studio-mobile"
fi

# Sophie — herbier communautaire (durability) + stock tisanes (discrete)
if [[ -n "${NSEC[sophie]:-}" ]]; then
    _pub "${NSEC[sophie]}" 30505 \
        '{"title":"Herbier communautaire","description":"Collection de 80 plantes séchées et étiquetées, consultable librement","quantity_type":"durability","quantity":1,"quantity_unit":"herbier","durability":95,"repairability":10,"mobility":"portable","min_operators":1}' \
        '[[\"d\",\"herbier-sophie\"],[\"title\",\"Herbier communautaire\"],[\"t\",\"sante\"],[\"t\",\"phytotherapie\"],[\"quantity_type\",\"durability\"],[\"quantity\",\"1\"],[\"durability\",\"95\"],[\"repairability\",\"10\"]]' && echo "  ✅ sophie :: herbier"
    _pub "${NSEC[sophie]}" 30505 \
        '{"title":"Stock tisanes médicinales (×50 doses)","description":"50 sachets de mélanges tisanes maison : digestion, sommeil, immunité","quantity_type":"discrete","quantity":50,"quantity_unit":"sachet","durability":100,"repairability":0,"mobility":"portable","min_operators":1}' \
        '[[\"d\",\"tisanes-sophie\"],[\"title\",\"Stock tisanes médicinales\"],[\"t\",\"sante\"],[\"t\",\"phytotherapie\"],[\"quantity_type\",\"discrete\"],[\"quantity\",\"50\"]]' && echo "  ✅ sophie :: tisanes"
fi
echo ""

# Crafts collectifs des nouveaux personas
echo "── Crafts élargis (Kind 30500) ──────────────────────────────"

# Atelier permaculture (marie + 1 op, 3h)
if [[ -n "${NSEC[marie]:-}" ]]; then
    _pub "${NSEC[marie]}" 30500 \
        '{"title":"Atelier permaculture et semences","description":"Initiation à la conception de jardin en permaculture + sélection de semences paysannes. Matériel fourni.","duration_hours":3,"min_operators":2,"max_operators":8,"skill_required":"permaculture:x1","output":"plans de jardin + semences offertes","reparation_zen":0}' \
        '[[\"d\",\"atelier-permaculture-marie\"],[\"title\",\"Atelier permaculture et semences\"],[\"t\",\"nature\"],[\"t\",\"agriculture\"],[\"min_operators\",\"2\"],[\"max_operators\",\"8\"],[\"duration\",\"3h\"],[\"skill\",\"permaculture:x1\"]]' && echo "  ✅ marie :: atelier-permaculture"
fi

# Atelier prise de son (ali + toto, 2h, nécessite sound-spot)
if [[ -n "${NSEC[ali]:-}" && -n "${NSEC[toto]:-}" ]]; then
    _pub "${NSEC[ali]}" 30500 \
        '{"title":"Atelier prise de son sound-spot","description":"Enregistrement et mixage sur sound-spot RPi — initiation conjointe son live et électronique. Ali (son) + Toto (RPi/Linux).","duration_hours":2,"min_operators":2,"max_operators":6,"skill_required":"son:x1","output":"session enregistrée + mixage partagé","reparation_zen":0}' \
        '[[\"d\",\"atelier-son-sound-spot\"],[\"title\",\"Atelier prise de son sound-spot\"],[\"t\",\"culture\"],[\"t\",\"numerique\"],[\"min_operators\",\"2\"],[\"max_operators\",\"6\"],[\"duration\",\"2h\"],[\"skill\",\"son:x1\"]]' && echo "  ✅ ali :: atelier-son-sound-spot"
fi

# Atelier santé plantes (sophie + marie, 2h)
if [[ -n "${NSEC[sophie]:-}" && -n "${NSEC[marie]:-}" ]]; then
    _pub "${NSEC[sophie]}" 30500 \
        '{"title":"Atelier phytothérapie et plantes du jardin","description":"Identifier, récolter et transformer les plantes médicinales du jardin en tisanes et onguents. Sophie (phyto) + Marie (jardin).","duration_hours":2,"min_operators":2,"max_operators":10,"skill_required":"phytotherapie:x1","output":"sachets tisanes personnalisés + fiches plantes","reparation_zen":0}' \
        '[[\"d\",\"atelier-phyto-jardin\"],[\"title\",\"Atelier phytothérapie et plantes du jardin\"],[\"t\",\"sante\"],[\"t\",\"nature\"],[\"min_operators\",\"2\"],[\"max_operators\",\"10\"],[\"duration\",\"2h\"],[\"skill\",\"phytotherapie:x1\"]]' && echo "  ✅ sophie :: atelier-phyto-jardin"
fi
echo ""

# Attestations inter-domaines
echo "── Attestations croisées élargies ───────────────────────────"
# toto atteste sound-spot pour ali (domaine culture ← numérique)
[[ -n "${NPUB[ali]:-}" ]]    && _attest toto  "${NPUB[ali]}"    sound-spot  1
# jean atteste git pour marie (gestion des guides en open source)
[[ -n "${NPUB[marie]:-}" ]]  && _attest jean  "${NPUB[marie]}"  git         1
# sophie atteste nutrition pour coucou (pratique alimentaire consciente)
[[ -n "${NPUB[coucou]:-}" ]] && _attest sophie "${NPUB[coucou]}" nutrition  1
# marie atteste permaculture pour jean (jardin autour de la cabane)
[[ -n "${NPUB[jean]:-}" ]]   && _attest marie "${NPUB[jean]}"   permaculture 1
echo ""

##########################################################################
## Nettoyage temporaires
##########################################################################
rm -f "${_DEMO_DIR}"/*_dtags.tmp

##########################################################################
## Résumé final
##########################################################################
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Graine WoTx2 terminée                                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Personas : toto / coucou / jean / marie / ali / sophie      ║"
echo "║  Publiés :                                                   ║"
echo "║   • Kind 30503 — 22+ skills (6 domaines couverts)           ║"
echo "║   • Kind 30505 — 23+ objets (durability/discrete/capacity/∞) ║"
echo "║   • Kind 30500 — 10+ crafts collectifs (multi-domaines)     ║"
echo "║   • Kind 1505  — transactions initiales                     ║"
echo "║   • Kind 1984  — friction démo coucou→jean (transport)      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Domaines couverts :                                         ║"
echo "║   💻 Numérique (toto/coucou/jean/ali)                        ║"
echo "║   🌿 Nature / Agriculture (marie/jean)                       ║"
echo "║   🎵 Culture (ali/toto)                                      ║"
echo "║   🌸 Santé (sophie/marie)                                    ║"
echo "║   🔧 Artisanat (jean)                                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Interfaces de démo :                                        ║"
echo "║   • /earth/skills.html    → nuage + filtre domaine          ║"
echo "║   • /earth/objects.html   → inventaire objets               ║"
echo "║   • /earth/calendars.html → onglet Crafts collectifs        ║"
echo "║   • /earth/minelife.html  → dashboard complet               ║"
echo "║   • /earth/h2g2.html     → vitrine H2G2 par domaine        ║"
echo "║   • /earth/justice.html  → médiation frictions              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Index des objets créés : ${_DEMO_DIR}/demo_objects.index"
echo ""
