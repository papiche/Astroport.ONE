#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ KIN.news.sh
#~ Envoi hebdomadaire des correspondances Oracle Dreamspell (Kin Maya)
#~ Parcourt le relay local (kind 30800), détecte les quatuors, paires occultes,
#~ paires analogues et conseils de tonalité, envoie un email HTML à chaque membre.
#~ mailjet.sh gère automatiquement l'opt-out (.mailjet).
#~
#~ Usage: KIN.news.sh [--gps [lat lon] radius_km] [--force]
#~   --gps radius         : filtre par proximité de la station (rayon en km)
#~   --gps lat lon radius : filtre par proximité d'un point explicite
#~   --force              : ignore le marqueur hebdomadaire (renvoi)
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

. "${MY_PATH}/../tools/my.sh"

# Bibliothèque Oracle Dreamspell partagée (tables, HTML, GPS, haversine)
# shellcheck source=/dev/null
source "${MY_PATH}/../tools/kin_oracle.sh"
# Préférences KIN par membre (scope N1/N2/relay, types, daily/weekly)
# shellcheck source=/dev/null
source "${MY_PATH}/../tools/kin_prefs.sh"

# ─────────────────────────────────────────────────────────────────────────────
# GPS — variables de filtre (fonctions dans kin_oracle.sh)
# ─────────────────────────────────────────────────────────────────────────────
GPS_LAT=""
GPS_LON=""
GPS_RADIUS=""
FORCE=false
# En mode --player, seul ce joueur local reçoit ses correspondances Kin.
# Les autres membres du relay sont scannés pour trouver les groupes, mais
# aucun email ne leur est envoyé (leur machine s'en charge).
TARGET_PLAYER=""

# ─────────────────────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gps)
            # --gps radius_km           → station GPS comme centre
            # --gps lat lon radius_km   → centre explicite
            if [[ "${3:-}" =~ ^-?[0-9]+([.][0-9]+)?$ && "${4:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                GPS_LAT="${2:-}"; GPS_LON="${3:-}"; GPS_RADIUS="${4:-}"
                shift 4
            else
                GPS_RADIUS="${2:-}"
                shift 2
            fi
            ;;
        --player)
            TARGET_PLAYER="${2:-}"; shift 2 ;;
        --force)
            FORCE=true; shift ;;
        --help|-h)
            grep '^#~' "$0" | sed 's/^#~ \?//'
            exit 0 ;;
        *) shift ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Résolution du centre GPS
# --gps radius seul → utiliser ~/.zen/GPS de la station comme centre
# ─────────────────────────────────────────────────────────────────────────────
if [[ -n "$GPS_RADIUS" && -z "$GPS_LAT" ]]; then
    _station_gps=$(cat "${HOME}/.zen/GPS" 2>/dev/null)
    if [[ -z "$_station_gps" ]]; then
        echo "ERROR KIN.news: --gps radius fourni mais ~/.zen/GPS est absent" >&2
        exit 1
    fi
    GPS_LAT=$(echo "$_station_gps" | grep -oP '(?<=LAT=)[^;]+' | tr -d ' ')
    GPS_LON=$(echo "$_station_gps" | grep -oP '(?<=LON=)[^;]+' | tr -d ' ')
    if [[ -z "$GPS_LAT" || -z "$GPS_LON" ]]; then
        echo "ERROR KIN.news: Impossible de lire LAT/LON depuis ~/.zen/GPS" >&2
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Marqueur hebdomadaire (évite les doublons d'envoi)
# ─────────────────────────────────────────────────────────────────────────────
WEEK_KEY="$(date -u +%Y)W$(date -u +%V)"
_gps_tag=""
if [[ -n "$GPS_LAT" ]]; then
    _gps_tag="_gps$(echo "${GPS_LAT}_${GPS_LON}_${GPS_RADIUS}" | tr '.' 'p' | tr '-' 'n')"
fi
# Marqueur par joueur en mode --player, global sinon
if [[ -n "$TARGET_PLAYER" ]]; then
    MARKER_FILE="${HOME}/.zen/game/nostr/${TARGET_PLAYER}/.kin_news_${WEEK_KEY}"
else
    MARKER_FILE="${HOME}/.zen/game/.kin_news_${WEEK_KEY}${_gps_tag}"
fi

if [[ -f "$MARKER_FILE" && "$FORCE" != "true" ]]; then
    echo "INFO KIN.news: Correspondances Kin déjà envoyées semaine ${WEEK_KEY} pour ${TARGET_PLAYER:-tous}. --force pour relancer." >&2
    exit 0
fi

# ─── Préférences du joueur cible (scope, types, opt-out) ─────────────────────
if [[ -n "$TARGET_PLAYER" ]]; then
    _kin_prefs_load "$TARGET_PLAYER"
    if [[ "$_KIN_WEEKLY" != "true" ]]; then
        echo "INFO KIN.news: newsletter hebdo désactivée pour ${TARGET_PLAYER}." >&2
        touch "$MARKER_FILE"
        exit 0
    fi
    # Construire le filtre strfry selon la portée choisie
    _player_hex=$(cat "${HOME}/.zen/game/nostr/${TARGET_PLAYER}/HEX" 2>/dev/null)
    _kin_build_scan_filter "$_player_hex"
    echo "  🔭 Portée : ${_KIN_SCOPE} (filtre: $(echo "$_KIN_SCAN_FILTER" | cut -c1-60)…)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Vérifications dépendances
# ─────────────────────────────────────────────────────────────────────────────
STRFRY_DIR="${HOME}/.zen/strfry"
STRFRY_BIN="${STRFRY_DIR}/strfry"
MJ="${MY_PATH}/../tools/mailjet.sh"
TMPL_DIR="${MY_PATH}/../templates/KIN"

if [[ ! -x "$STRFRY_BIN" ]]; then
    echo "ERROR KIN.news: strfry non disponible — ${STRFRY_BIN}" >&2
    exit 1
fi

if [[ ! -x "$MJ" ]]; then
    echo "ERROR KIN.news: mailjet.sh introuvable — ${MJ}" >&2
    exit 1
fi

echo "========================================================================"
echo "🌀  KIN.news.sh — Correspondances Oracle Dreamspell — Semaine ${WEEK_KEY}"
if [[ -n "$GPS_LAT" ]]; then
    echo "    Filtre GPS : ${GPS_LAT} ${GPS_LON} (rayon ${GPS_RADIUS} km)"
fi
echo "========================================================================"

# ─────────────────────────────────────────────────────────────────────────────
# Collecte des profils Kin Maya et GPS depuis le relay local (kind 30800)
# ─────────────────────────────────────────────────────────────────────────────
WELCOME_TMPL="${TMPL_DIR}/kin_alpha_welcome.html"
WELCOME_DIR="${HOME}/.zen/game/.kin_welcomed"
mkdir -p "$WELCOME_DIR"

echo "  📡 Scan kind 30800..."
# Pré-scan DID pour peupler pubkey_email[] (requis par _scan_a4l_phi)
_scan_did_mapping 2>/dev/null
# Complète avec les clés LOVE locales pas encore liées au DID (comptes
# activés avant le lien verificationMethod #atom4love-key)
_scan_local_love_keys 2>/dev/null
declare -A kin_emails=()    # kin_number → "email1 email2 …"
declare -A email_zencard=() # emails avec ẐEN Card activée (.metadata.zencardWallet ou .g1pub local)
total_profiles=0

while IFS= read -r _evt; do
    [[ -z "$_evt" ]] && continue
    _cnt=$(echo "$_evt" | jq -r '.content // empty' 2>/dev/null)
    [[ -z "$_cnt" ]] && continue
    _email=$(echo "$_cnt" | jq -r '
        .metadata.email //
        (.alsoKnownAs // [] | map(select(startswith("mailto:"))) | first // "")
    ' 2>/dev/null | sed 's/^mailto://')
    _kin=$(echo "$_cnt" | jq -r '
        .metadata.badges // [] | map(select(.type == "MayaKin")) | first.kin // ""
    ' 2>/dev/null)
    [[ -z "$_email" || -z "$_kin" || "$_kin" == "null" ]] && continue
    [[ ! "$_kin" =~ ^[0-9]+$ || $_kin -lt 1 || $_kin -gt 260 ]] && continue
    # Marquer la ẐEN Card : zencardWallet dans le DID, ou fichier local .g1pub
    _zencard_pub=$(echo "$_cnt" | jq -r '.metadata.zencardWallet.g1pub // empty' 2>/dev/null)
    if [[ -n "$_zencard_pub" ]]; then
        email_zencard["$_email"]=1
    elif [[ -s "${HOME}/.zen/game/players/${_email}/.g1pub" ]]; then
        email_zencard["$_email"]=1
    fi
    # Extraire GPS depuis DID (chiffré ou texte clair) et remplir email_gps[]
    if command -v gps_parse_did_coords &>/dev/null; then
        eval "$(gps_parse_did_coords "$_cnt" 2>/dev/null)"
        if [[ -n "${GPS_LAT_PARSED:-}" && -n "${GPS_LON_PARSED:-}" ]]; then
            email_gps["$_email"]="LAT=${GPS_LAT_PARSED}; LON=${GPS_LON_PARSED};"
        fi
    fi
    # Extraire URL profil IPNS depuis serviceEndpoint #ipns-storage
    _ipns_url=$(echo "$_cnt" | jq -r '
        .service // [] | map(select(.id | endswith("#ipns-storage"))) | first.serviceEndpoint // ""
    ' 2>/dev/null)
    [[ -n "$_ipns_url" ]] && email_nostrns["$_email"]="$_ipns_url"
    # Filtre GPS si actif (utilise email_gps[] rempli juste au-dessus)
    _email_in_radius "$_email" || continue
    # Déduplique
    [[ "${kin_emails[$_kin]:-}" == *"${_email}"* ]] && continue
    kin_emails["$_kin"]+="${_email} "
    ((total_profiles++))
    # Envoi welcome alpha si premier contact (marqueur par email)
    # En mode --player, n'envoyer le welcome qu'au joueur ciblé (sa machine s'en charge)
    [[ -n "$TARGET_PLAYER" && "$_email" != "$TARGET_PLAYER" ]] && continue
    _wmark="${WELCOME_DIR}/$(echo "$_email" | md5sum | cut -c1-16)"
    if [[ ! -f "$_wmark" && -f "$WELCOME_TMPL" && -x "$MJ" ]]; then
        # Générer le welcome personnalisé
        _ws=$(( (_kin-1)/13+1 )); _wpos=$(( (_kin-1)%13+1 ))
        _wsi=$(( (_kin-1)%20 )); _wci=$(( (_kin-1)/13%5 ))
        _wseal="${_DS_SEALS[$_wsi]:-?}"; _wcolor="${_DS_COLORS[$_wci]:-?}"
        _wemo="${_DS_COLOR_EMO[$_wcolor]:-🌀}"
        _wocc=$(( 261-_kin )); _wana=$(_kin_analog "$_kin")
        _wguide=$(_kin_guide "$_kin"); _wanti=$(_kin_antipode "$_kin")
        _tmpwel=$(mktemp /tmp/kin_welcome_XXXXXX.html)
        _eoracle=$(mktemp /tmp/kin_wel_oracle_XXXXXX.html)
        for _pk in $_wguide $_wanti $_wana $_wocc; do
            _psi=$(( (_pk-1)%20 )); _pci=$(( (_pk-1)/13%5 ))
            _pseal="${_DS_SEALS[$_psi]:-?}"; _pcolor="${_DS_COLORS[$_pci]:-?}"
            _pemo="${_DS_COLOR_EMO[$_pcolor]:-}"
            printf '<div style="margin:.3rem 0;padding:.5rem .8rem;background:#f8f7ff;border-radius:8px;font-size:.82rem">Kin %d %s %s %s</div>\n' \
                "$_pk" "$_pemo" "$_pcolor" "$_pseal" >> "$_eoracle"
        done
        awk -v kn="$_kin" -v ks="$_wseal" -v kc="$_wcolor" -v ke="$_wemo" \
            -v dest="$_email" -v date="$(date -u '+%-d %B %Y' 2>/dev/null||date -u +%Y-%m-%d)" \
            -v efile="$_eoracle" \
        '/_ORACLE_ENTRIES_/ { while((getline l < efile)>0) print l; next }
         { gsub(/_KIN_NUM_/,kn); gsub(/_KIN_SEAL_/,ks); gsub(/_KIN_COLOR_/,kc)
           gsub(/_KIN_COLOR_EMO_/,ke); gsub(/_DEST_/,dest); gsub(/_DATE_/,date); print }' \
        "$WELCOME_TMPL" > "$_tmpwel"
        rm -f "$_eoracle"
        _wres=$("$MJ" "${_email}" "${_tmpwel}" "⚛ Bienvenue dans l'Alpha ATOM4LOVE — Kin ${_kin} ${_wemo} G1FabLab" 2>&1)
        rm -f "$_tmpwel"
        echo "$_wres" | grep -q "opt-out\|annule" || { touch "$_wmark"; echo "  🌟 Welcome → ${_email} (Kin ${_kin})"; }
    fi
done < <(cd "${STRFRY_DIR}" && ./strfry scan "${_KIN_SCAN_FILTER}" 2>/dev/null)

printf "  📊 %d profil(s) avec Kin Maya (%d Kin distincts)\n" \
       "$total_profiles" "${#kin_emails[@]}"

if [[ $total_profiles -lt 2 ]]; then
    echo "  ℹ️  Moins de 2 profils — aucune correspondance à envoyer"
    touch "$MARKER_FILE"
    exit 0
fi

# Enrichissement phi/omega (Kind 30078 ATOM4LOVE) — nécessaire pour _kin_member_card_rich
# pubkey_email[] déjà peuplé par _scan_did_mapping ci-dessus
_scan_a4l_phi 2>/dev/null
printf "  ⚛ phi_i chargés : %d\n" "${#email_phi[@]}"

# ─────────────────────────────────────────────────────────────────────────────
# Envoi d'un groupe oracle (non-interactif)
# Globals lus : _MATCH_GROUP_HTML  _MATCH_TONE_NUM  _MATCH_TONE_NAME
# ─────────────────────────────────────────────────────────────────────────────
_MATCH_GROUP_HTML=""
_MATCH_TONE_NUM=""
_MATCH_TONE_NAME=""

_send_group() {
    local group_type="$1"; shift
    local -a all_emails=("$@")
    [[ ${#all_emails[@]} -eq 0 ]] && return

    # Résoudre la clé de type une seule fois (utilisée en mode player ET batch)
    local _gtype_key=""
    case "$group_type" in
        *Quatuor*)  _gtype_key="quartet"  ;;
        *Occulte*)  _gtype_key="occult"   ;;
        *Analogue*) _gtype_key="analog"   ;;
        *Tonalit*)  _gtype_key="tone"     ;;
        *Guide*)    _gtype_key="guide"    ;;
        *Antipode*) _gtype_key="antipode" ;;
    esac

    # En mode --player : filtrer par type/portée et restreindre à ce joueur
    if [[ -n "${TARGET_PLAYER:-}" ]]; then
        if [[ -n "$_gtype_key" ]] && ! _kin_type_enabled "$_gtype_key"; then
            return
        fi
        local _in_group=false
        for _d in "${all_emails[@]}"; do
            [[ "$_d" == "$TARGET_PLAYER" ]] && _in_group=true && break
        done
        [[ "$_in_group" != "true" ]] && return
        all_emails=("$TARGET_PLAYER")
    fi

    # Intro adaptée au langage de résonance du joueur
    local _vibe_block=""
    if [[ -n "${TARGET_PLAYER:-}" ]]; then
        _vibe_block=$(_kin_vibe_intro "$group_type" "${_KIN_LANGAGE:-curieux}")
    fi

    local tmpl
    case "$group_type" in
        *Quatuor*)  tmpl="${TMPL_DIR}/kin_quartet.html" ;;
        *Occulte*)  tmpl="${TMPL_DIR}/kin_occult.html"  ;;
        *Analogue*) tmpl="${TMPL_DIR}/kin_analog.html"  ;;
        *Tonalité*) tmpl="${TMPL_DIR}/kin_council.html" ;;
        *)          tmpl="${TMPL_DIR}/kin_match.html"   ;;
    esac

    if [[ ! -f "$tmpl" ]]; then
        echo "    ⚠️  Template manquant : ${tmpl}" >&2
        return
    fi

    local tmpfile; tmpfile=$(mktemp /tmp/kin_news_XXXXXX.html)
    local entriesfile; entriesfile=$(mktemp /tmp/kin_entries_XXXXXX.html)
    printf '%s' "$_MATCH_GROUP_HTML" > "$entriesfile"

    local date_fr
    date_fr=$(LC_ALL=fr_FR.UTF-8 date -u '+%-d %B %Y' 2>/dev/null || date -u '+%Y-%m-%d')

    # Textes sémantiques pour kin_match.html (Guide / Antipode / fallback)
    local _group_desc="" _group_why="" _oracle_meaning=""
    case "$group_type" in
        *Guide*)
            _group_desc="Une relation de transmission naturelle — le Guide éclaire le chemin du Kin guidé dans la même famille-couleur."
            _group_why="Vos Kin appartiennent à la même famille-couleur et forment une relation Guide-Guidé dans le Tzolkin. Cette connexion est activée automatiquement par le calendrier galactique."
            _oracle_meaning="Le Guide est le Kin dominant de l'Oracle — il porte sagesse et direction. Le Guidé reçoit cette lumière et la transforme en action. Rencontrer votre Guide en chair amplifie votre programme galactique."
            ;;
        *Antipode*)
            _group_desc="Une tension créatrice — le Défi qui révèle la puissance cachée de chacun."
            _group_why="Vos Kin partagent la même tonalité galactique avec des sceaux opposés (sceau+10). L'Antipode est le grand Défi créateur du Tzolkin — une polarité qui transforme la tension en puissance."
            _oracle_meaning="L'Antipode révèle les zones d'apprentissage et de dépassement mutuel. Travailler ensemble transforme la friction en force collective. Le Tzolkin voit dans cette relation un catalyseur de croissance."
            ;;
        *)
            _group_desc="Une correspondance identifiée dans votre constellation Kin Maya."
            _group_why="Le calendrier Tzolkin a détecté une résonance entre vos programmes galactiques."
            _oracle_meaning="Les correspondances Oracle forment des toiles de résonance entre les êtres. Chaque Kin porte un programme cosmique unique — leur rencontre amplifie les deux champs."
            ;;
    esac

    # Substitution robuste via awk (gère les newlines dans _KIN_ENTRIES_)
    awk -v gtype="$group_type" \
        -v tnum="${_MATCH_TONE_NUM:-}" \
        -v tname="${_MATCH_TONE_NAME:-}" \
        -v datestr="$date_fr" \
        -v efile="$entriesfile" \
        -v vibe="$_vibe_block" \
        -v gdesc="$_group_desc" \
        -v gwhy="$_group_why" \
        -v gmeaning="$_oracle_meaning" \
    '
    /_KIN_ENTRIES_/ {
        while ((getline line < efile) > 0) print line
        next
    }
    /_VIBE_INTRO_/ {
        print vibe
        next
    }
    {
        gsub(/_GROUP_TYPE_/, gtype)
        gsub(/_GROUP_DESC_/, gdesc)
        gsub(/_GROUP_WHY_/, gwhy)
        gsub(/_ORACLE_MEANING_/, gmeaning)
        gsub(/_TONE_NUM_/, tnum)
        gsub(/_TONE_NAME_/, tname)
        gsub(/_DATE_/, datestr)
        print
    }
    ' "$tmpl" > "$tmpfile"

    rm -f "$entriesfile"

    # Sujet adapté au vibe du joueur (mode --player) ou générique (mode batch)
    local subject; subject=$(_kin_vibe_subject "$group_type" "${_KIN_LANGAGE:-curieux}")
    local sent=0 skipped=0
    for dest in "${all_emails[@]}"; do
        [[ -z "$dest" ]] && continue
        # En mode batch, vérifier les prefs /mailjet de chaque destinataire
        if [[ -z "${TARGET_PLAYER:-}" ]]; then
            _kin_prefs_load "$dest"
            if [[ "$_KIN_WEEKLY" != "true" ]]; then
                echo "    ⏭ Skip ${dest} — hebdo désactivé." >&2
                ((skipped++)); continue
            fi
            if [[ -n "$_gtype_key" ]] && ! _kin_type_enabled "$_gtype_key"; then
                echo "    ⏭ Skip ${dest} — type ${_gtype_key} désactivé." >&2
                ((skipped++)); continue
            fi
        fi
        local _result
        _result=$("$MJ" "${dest}" "${tmpfile}" "${subject}" 2>&1)
        if echo "$_result" | grep -q "opt-out\|annulé"; then
            echo "    ⛔ ${dest} — opt-out actif"
            ((skipped++))
        else
            echo "    📤 ${dest}"
            ((sent++))
        fi
    done
    rm -f "$tmpfile"
    printf "    → %d envoyé(s), %d opt-out\n" "$sent" "$skipped"
}

# ─────────────────────────────────────────────────────────────────────────────
# Détection et envoi des groupes oracle
# ─────────────────────────────────────────────────────────────────────────────
declare -A shown=()  # kins déjà traités
quartet_count=0 occult_count=0 analog_count=0 council_count=0 found_groups=0

# ── 1. QUATUORS COMPLETS {K, Ana(K), 261-K, 261-Ana(K)} ──────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ 💎 QUATUORS ORACLE COMPLETS"
echo "  └──────────────────────────────────────────────────────"

for kin in "${!kin_emails[@]}"; do
    ana=$(_kin_analog "$kin")
    occ=$(( 261 - kin ))
    occ_ana=$(( 261 - ana ))

    qmin=$kin
    for _q in $ana $occ $occ_ana; do (( _q < qmin )) && qmin=$_q; done
    [[ -n "${shown[$qmin]:-}" ]] && continue

    [[ -z "${kin_emails[$occ]:-}"     ]] && continue
    [[ -z "${kin_emails[$ana]:-}"     ]] && continue
    [[ -z "${kin_emails[$occ_ana]:-}" ]] && continue

    shown[$qmin]=1; shown[$kin]=1; shown[$ana]=1; shown[$occ]=1; shown[$occ_ana]=1
    ((quartet_count++)); ((found_groups++))

    printf "\n  💎 Quatuor #%d\n" "$quartet_count"
    _MATCH_GROUP_HTML=""
    declare -a _ems=()
    for _q in $kin $ana $occ $occ_ana; do
        printf "    %s : %s\n" "$(_kin_label "$_q")" "${kin_emails[$_q]}"
        declare -a _qemails=()
        read -ra _qemails <<< "${kin_emails[$_q]:-}"
        _MATCH_GROUP_HTML+=$(_kin_member_card_rich "$_q" "" "" "${_qemails[@]}")
        for _e in "${_qemails[@]}"; do [[ -n "$_e" ]] && _ems+=("$_e"); done
    done
    _MATCH_GROUP_HTML+=$(_kin_meeting_block $kin $ana $occ $occ_ana)
    _send_group "Quatuor Oracle" "${_ems[@]}"
done
[[ $quartet_count -eq 0 ]] && echo "  ℹ️  Aucun quatuor complet"

# ── 2. PAIRES OCCULTES K + K' = 261  (hors quatuors) ────────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ 🌙 PAIRES OCCULTES (K + K' = 261)"
echo "  └──────────────────────────────────────────────────────"

for kin in "${!kin_emails[@]}"; do
    occ=$(( 261 - kin ))
    (( occ <= kin )) && continue
    [[ -z "${kin_emails[$occ]:-}" ]] && continue
    pmin=$(( kin < occ ? kin : occ ))
    [[ -n "${shown[$pmin]:-}" ]] && continue

    shown[$pmin]=1; shown[$kin]=1; shown[$occ]=1
    ((occult_count++)); ((found_groups++))

    printf "\n  🌙 Paire occulte : %s ↔ %s\n" "$(_kin_label "$kin")" "$(_kin_label "$occ")"

    declare -a _k_ems _o_ems
    read -ra _k_ems <<< "${kin_emails[$kin]:-}"
    read -ra _o_ems <<< "${kin_emails[$occ]:-}"
    _MATCH_GROUP_HTML=$(_kin_member_card_rich "$kin" "" "" "${_k_ems[@]}")$(_kin_member_card_rich "$occ" "" "" "${_o_ems[@]}")
    _MATCH_GROUP_HTML+=$(_kin_meeting_block $kin $occ)
    _send_group "Paire Occulte" "${_k_ems[@]}" "${_o_ems[@]}"
done
[[ $occult_count -eq 0 ]] && echo "  ℹ️  Aucune paire occulte isolée"

# ── 3. PAIRES ANALOGUES (hors quatuors/occultes) ────────────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ 🌀 PAIRES ANALOGUES (même tonalité, sceaux ±10)"
echo "  └──────────────────────────────────────────────────────"

for kin in "${!kin_emails[@]}"; do
    ana=$(_kin_analog "$kin")
    (( ana <= kin )) && continue
    [[ -z "${kin_emails[$ana]:-}" ]] && continue
    pmin=$(( kin < ana ? kin : ana ))
    [[ -n "${shown[$pmin]:-}" ]] && continue

    shown[$pmin]=1; shown[$kin]=1; shown[$ana]=1
    ((analog_count++)); ((found_groups++))

    printf "\n  🌀 Paire analogue : %s ↔ %s\n" "$(_kin_label "$kin")" "$(_kin_label "$ana")"

    declare -a _k_ems _a_ems
    read -ra _k_ems <<< "${kin_emails[$kin]:-}"
    read -ra _a_ems <<< "${kin_emails[$ana]:-}"
    _MATCH_GROUP_HTML=$(_kin_member_card_rich "$kin" "" "" "${_k_ems[@]}")$(_kin_member_card_rich "$ana" "" "" "${_a_ems[@]}")
    _MATCH_GROUP_HTML+=$(_kin_meeting_block $kin $ana)
    _send_group "Paire Analogue" "${_k_ems[@]}" "${_a_ems[@]}"
done
[[ $analog_count -eq 0 ]] && echo "  ℹ️  Aucune paire analogue isolée"

# ── 4. CONSEILS DE TONALITÉ — ≥ 2 membres même tonalité ─────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ 🎵 CONSEILS DE TONALITÉ (même tonalité galactique)"
echo "  └──────────────────────────────────────────────────────"

declare -A tone_kins=()
for kin in "${!kin_emails[@]}"; do
    t=$(_kin_tone "$kin")
    tone_kins[$t]+="${kin} "
done

for (( t=1; t<=13; t++ )); do
    [[ -z "${tone_kins[$t]:-}" ]] && continue
    declare -a members=()
    read -ra members <<< "${tone_kins[$t]}"
    (( ${#members[@]} < 2 )) && continue

    tname="${_DS_TONES[$((t-1))]}"
    ((council_count++)); ((found_groups++))
    printf "\n  🎵 Tonalité %d — %s (%d membres)\n" "$t" "$tname" "${#members[@]}"

    _MATCH_GROUP_HTML=""
    _MATCH_TONE_NUM="$t"
    _MATCH_TONE_NAME="$tname"
    declare -a _ems=()
    for _k in "${members[@]}"; do
        printf "    %s : %s\n" "$(_kin_label "$_k")" "${kin_emails[$_k]}"
        declare -a _mem_ems=()
        read -ra _mem_ems <<< "${kin_emails[$_k]:-}"
        _MATCH_GROUP_HTML+=$(_kin_member_card_rich "$_k" "" "" "${_mem_ems[@]}")
        for _e in "${_mem_ems[@]}"; do [[ -n "$_e" ]] && _ems+=("$_e"); done
    done
    _MATCH_GROUP_HTML+=$(_kin_meeting_block "tone-${t}")
    _send_group "Conseil Tonalité ${t} — ${tname}" "${_ems[@]}"
done
[[ $council_count -eq 0 ]] && echo "  ℹ️  Aucun conseil (< 2 membres par tonalité)"

# ── 5. GUIDES — même famille-couleur, relation de mentorat ──────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ 🧭 PAIRES GUIDE (mentor + guidé, même famille-couleur)"
echo "  └──────────────────────────────────────────────────────"
guide_count=0
declare -A shown_guide=()
for kin in "${!kin_emails[@]}"; do
    guide=$(_kin_guide "$kin")
    [[ "$guide" -eq "$kin" ]] && continue   # T1,T6,T11 = guide de soi-même, skip
    [[ -z "${kin_emails[$guide]:-}" ]] && continue
    pmin=$(( kin < guide ? kin : guide ))
    [[ -n "${shown[$pmin]:-}" || -n "${shown_guide[$pmin]:-}" ]] && continue
    shown_guide[$pmin]=1
    ((guide_count++)); ((found_groups++))
    printf "\n  🧭 Guide : %s → %s\n" "$(_kin_label "$guide")" "$(_kin_label "$kin")"
    declare -a _g_ems _k_ems
    read -ra _g_ems <<< "${kin_emails[$guide]:-}"
    read -ra _k_ems <<< "${kin_emails[$kin]:-}"
    _MATCH_GROUP_HTML=$(_kin_member_card_rich "$guide" "" "" "${_g_ems[@]}")
    _MATCH_GROUP_HTML+=$(_kin_member_card_rich "$kin"  "" "" "${_k_ems[@]}")
    _MATCH_GROUP_HTML+=$(_kin_meeting_block $guide $kin)
    _send_group "Relation Guide — Kin ${guide} guide Kin ${kin}" "${_g_ems[@]}" "${_k_ems[@]}"
done
[[ $guide_count -eq 0 ]] && echo "  ℹ️  Aucune paire Guide isolée"

# ── 6. ANTIPODES — défi créateur (sceau+10, tonalité miroir) ────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ ⚡ PAIRES ANTIPODE (défi créateur — sceau+10, T miroir)"
echo "  └──────────────────────────────────────────────────────"
antipode_count=0
declare -A shown_anti=()
for kin in "${!kin_emails[@]}"; do
    anti=$(_kin_antipode "$kin")
    [[ "$anti" -eq "$kin" ]] && continue
    [[ -z "${kin_emails[$anti]:-}" ]] && continue
    pmin=$(( kin < anti ? kin : anti ))
    [[ -n "${shown[$pmin]:-}" || -n "${shown_guide[$pmin]:-}" || -n "${shown_anti[$pmin]:-}" ]] && continue
    shown_anti[$pmin]=1
    ((antipode_count++)); ((found_groups++))
    printf "\n  ⚡ Antipode : %s ↔ %s\n" "$(_kin_label "$kin")" "$(_kin_label "$anti")"
    declare -a _a_ems _b_ems
    read -ra _a_ems <<< "${kin_emails[$kin]:-}"
    read -ra _b_ems <<< "${kin_emails[$anti]:-}"
    _MATCH_GROUP_HTML=$(_kin_member_card_rich "$kin"  "" "" "${_a_ems[@]}")
    _MATCH_GROUP_HTML+=$(_kin_member_card_rich "$anti" "" "" "${_b_ems[@]}")
    _MATCH_GROUP_HTML+=$(_kin_meeting_block $kin $anti)
    _send_group "Paire Antipode — Defi Createur" "${_a_ems[@]}" "${_b_ems[@]}"
done
[[ $antipode_count -eq 0 ]] && echo "  ℹ️  Aucune paire Antipode isolée"

# ── 7. NŒUDS CYMATIQUES — même ventre d'onde planétaire (a5l), indépendant géo ──
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ 🌊 NŒUDS CYMATIQUES (même antinode d'onde terrestre)"
echo "  └──────────────────────────────────────────────────────"
# Un nœud cymatique regroupe des membres dont la naissance a eu lieu sur le
# même ventre d'onde planétaire |Ψ_i − Ψ_j| < 0.10, quelle que soit leur géographie.
# Requiert email_a5l[] peuplé par _scan_a4l_phi (via kin_oracle.sh).
cymatic_count=0
declare -A shown_cymatic=()
declare -a a5l_emails=()
for _email in "${!email_a5l[@]}"; do
    a5l_emails+=("$_email")
done

for (( _ia=0; _ia < ${#a5l_emails[@]}; _ia++ )); do
    _e1="${a5l_emails[$_ia]}"
    [[ -n "${shown_cymatic[$_e1]:-}" ]] && continue
    _psi1="${email_a5l[$_e1]}"
    declare -a _wave_group=("$_e1")
    for (( _ib=_ia+1; _ib < ${#a5l_emails[@]}; _ib++ )); do
        _e2="${a5l_emails[$_ib]}"
        [[ -n "${shown_cymatic[$_e2]:-}" ]] && continue
        _psi2="${email_a5l[$_e2]}"
        _delta=$(python3 -c "
import sys
diff = abs(float(sys.argv[1]) - float(sys.argv[2]))
print('yes' if diff < 0.10 else 'no')
" "$_psi1" "$_psi2" 2>/dev/null) || _delta="no"
        [[ "$_delta" == "yes" ]] && _wave_group+=("$_e2")
    done
    (( ${#_wave_group[@]} < 2 )) && continue

    # Vérifier que ce groupe n'est pas un simple swarm géographique déjà signalé
    # (on garde si au moins 2 membres dans des zones distinctes)
    _distinct_zones=0
    _zone_ref=""
    for _we in "${_wave_group[@]}"; do
        _wgps="${email_gps[$_we]:-}"
        _wlat=$(echo "$_wgps" | grep -oP '(?<=LAT=)[^;]+')
        _wlon=$(echo "$_wgps" | grep -oP '(?<=LON=)[^;]+')
        [[ -z "$_wlat" ]] && _distinct_zones=$((_distinct_zones+1)) && continue
        _wzone=$(python3 -c "import sys; print(round(float(sys.argv[1]))+round(float(sys.argv[2])))" \
            "$_wlat" "$_wlon" 2>/dev/null) || _wzone="?"
        [[ -z "$_zone_ref" ]] && _zone_ref="$_wzone"
        [[ "$_wzone" != "$_zone_ref" ]] && _distinct_zones=$((_distinct_zones+1))
    done
    (( _distinct_zones < 1 )) && continue  # tous dans la même zone → déjà couvert par swarm

    for _we in "${_wave_group[@]}"; do shown_cymatic[$_we]=1; done
    ((cymatic_count++)); ((found_groups++))

    _psi_pct=$(python3 -c "print(int(float('$_psi1')*100))" 2>/dev/null) || _psi_pct="?"
    printf "\n  🌊 Nœud Cymatique #%d — Ψ ≈ %s%% (%d membres)\n" \
        "$cymatic_count" "$_psi_pct" "${#_wave_group[@]}"
    for _we in "${_wave_group[@]}"; do
        printf "    %s (Ψ=%s%%)\n" "$_we" "$(python3 -c "print(int(float('${email_a5l[$_we]:-0}')*100))" 2>/dev/null)"
    done

    # En mode --player : filtrer
    if [[ -n "${TARGET_PLAYER:-}" ]]; then
        _in_wave=false
        for _we in "${_wave_group[@]}"; do [[ "$_we" == "$TARGET_PLAYER" ]] && _in_wave=true; done
        [[ "$_in_wave" != "true" ]] && continue
    fi
    if [[ -n "${TARGET_PLAYER:-}" ]]; then
        if ! _kin_type_enabled "cymatic" 2>/dev/null; then : ; fi
    fi

    # Construire le HTML de groupe
    _MATCH_GROUP_HTML=""
    declare -a _cymatic_ems=()
    for _we in "${_wave_group[@]}"; do
        local _wkin="${email_kin30078[$_we]:-${kin30078_from_30800[$_we]:-0}}"
        _MATCH_GROUP_HTML+=$(_kin_member_card_rich "${_wkin:-0}" "${email_phi[$_we]:-}" \
            "${email_omega[$_we]:-}" "$_we")
        _cymatic_ems+=("$_we")
    done

    # Email HTML dédié aux Nœuds Cymatiques
    declare -a _send_list=()
    [[ -n "${TARGET_PLAYER:-}" ]] && _send_list=("$TARGET_PLAYER") || _send_list=("${_cymatic_ems[@]}")
    for _dest in "${_send_list[@]}"; do
        [[ -z "$_dest" ]] && continue
        _tmp_cymatic=$(mktemp /tmp/kin_cymatic_XXXXXX.html)
        _psi_dest_pct=$(python3 -c "print(int(float('${email_a5l[$_dest]:-0}')*100))" 2>/dev/null) || _psi_dest_pct="?"
        cat << CYMAEOF > "$_tmp_cymatic"
<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>🌊 Nœud Cymatique — Même ventre d'onde que vous</title>
<style>
body{margin:0;background:#0f0e17;font-family:-apple-system,sans-serif}
.w{max-width:600px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden}
.ft{background:#f7f7fb;padding:1rem;text-align:center;font-size:.7rem;color:#9ca3af}
a{color:#0ea5e9}
</style></head><body><div class="w">
<div style="background:linear-gradient(135deg,#0c4a6e,#0ea5e9);padding:1.4rem;color:#fff">
  <div style="font-size:1.1rem;font-weight:700">🌊 Nœud Cymatique</div>
  <div style="font-size:.85rem;opacity:.9;margin-top:.3rem">
    Votre naissance a eu lieu sur le même <em>ventre d'onde planétaire</em> (Ψ = ${_psi_dest_pct}%)
    que ${#_cymatic_ems[@]} autre(s) explorateur(s) — quelle que soit leur position sur le globe.
  </div>
</div>
<div style="padding:1rem 1.2rem">
  <div style="background:#f0f9ff;border-radius:10px;padding:.9rem;margin-bottom:1rem;font-size:.83rem;color:#0369a1;border-left:3px solid #0ea5e9">
    <strong>🌍 Résonance sans frontières</strong><br>
    La Terre vibre comme un bol chantant. Ses 12 pôles icosaédriques émettent des ondes
    qui interfèrent en formant des <em>ventres</em> (amplitudes maximales) et des <em>nœuds</em>
    (amplitudes nulles). Vous êtes nés sur le même antinode : indépendamment de la distance
    géographique, votre champ vibratoire de naissance résonne à l'unisson.
  </div>
  ${_MATCH_GROUP_HTML}
  <div style="text-align:center;margin-top:1rem">
    <a href="https://u.copylaradio.com/apk/atom4love.apk"
       style="background:#0ea5e9;color:#fff;padding:.5rem 1.2rem;border-radius:8px;
              text-decoration:none;font-size:.85rem;font-weight:600">
      ⚛ Ouvrir ATOM4LOVE
    </a>
  </div>
</div>
<div class="ft">ATOM4LOVE Alpha · G1FabLab · UPlanet ORIGIN</div>
</div></body></html>
CYMAEOF
        if [[ -x "$MJ" ]]; then
            "$MJ" "$_dest" "$_tmp_cymatic" \
                "🌊 Nœud Cymatique — Votre onde planétaire résonne avec ${#_cymatic_ems[@]} explorateur(s)" 2>/dev/null && \
                printf "    📧 Nœud Cymatique → %s\n" "$_dest"
        fi
        rm -f "$_tmp_cymatic"
    done
done
[[ $cymatic_count -eq 0 ]] && echo "  ℹ️  Aucun nœud cymatique (a5l non encore renseigné — republier le certificat ATOM4LOVE)"

# ─────────────────────────────────────────────────────────────────────────────
# Bilan et marqueur
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================================================"
printf "  🔮 %d groupe(s) traité(s)\n" "$found_groups"
printf "     💎 Quatuors: %d  🌙 Occultes: %d  🌀 Analogues: %d  🎵 Conseils: %d\n" \
       "$quartet_count" "$occult_count" "$analog_count" "$council_count"
printf "     🧭 Guides: %d  ⚡ Antipodes: %d  🌊 Cymatiques: %d\n" "$guide_count" "$antipode_count" "$cymatic_count"
echo "========================================================================"

# ─── Publication hebdo des tâches G1FabLab sur NOSTR ─────────────────────
TASKS_SCRIPT="${MY_PATH}/KIN.tasks.sh"
[[ -x "$TASKS_SCRIPT" ]] && "$TASKS_SCRIPT" --publish 2>/dev/null || true

# ─── DÉTECTION DE SWARM GÉOGRAPHIQUE (Choeur des Nœuds) ─────────────────
# Grouper les membres par zone UMAP (0.1° ≈ 11km) et détecter les clusters
echo ""
echo "  ┌──────────────────────────────────────────────────────"
echo "  │ 🔊 ANALYSE DES SWARMS POTENTIELS (même zone UMAP)"
echo "  └──────────────────────────────────────────────────────"

declare -A zone_emails=()  # "LATZONE_LONZONE" → "email1 email2 ..."
declare -A zone_kins=()    # "LATZONE_LONZONE" → "kin1 kin2 ..."

# Regrouper par zone géographique (0.1° grid)
for _email in "${!email_gps[@]}"; do
    _gps="${email_gps[$_email]}"
    _el=$(echo "$_gps" | grep -oP '(?<=LAT=)[^;]+')
    _ol=$(echo "$_gps" | grep -oP '(?<=LON=)[^;]+')
    [[ -z "$_el" || -z "$_ol" ]] && continue
    _lzone=$(python3 -c "import sys; print(round(float(sys.argv[1])/0.1)*0.1)" "$_el" 2>/dev/null) || continue
    _ozone=$(python3 -c "import sys; print(round(float(sys.argv[1])/0.1)*0.1)" "$_ol" 2>/dev/null) || continue
    _zkey="${_lzone}_${_ozone}"
    zone_emails["$_zkey"]+="${_email} "
done

swarm_count=0
for _zkey in "${!zone_emails[@]}"; do
    IFS=' ' read -ra _zemails <<< "${zone_emails[$_zkey]}"
    # Filtre anti-spam : ne retenir que les membres ayant activé leur ẐEN Card
    declare -a _zc_emails=()
    for _ze in "${_zemails[@]}"; do
        [[ -n "${email_zencard[$_ze]:-}" ]] && _zc_emails+=("$_ze")
    done
    _zemails=("${_zc_emails[@]}")
    unset _zc_emails
    [[ ${#_zemails[@]} -lt 2 ]] && continue  # swarm = 2 personnes minimum

    ((swarm_count++))
    _latzone=$(echo "$_zkey" | cut -d'_' -f1)
    _lonzone=$(echo "$_zkey" | cut -d'_' -f2)

    # Calculer le score H moyen de la zone via compute_resonance_k(φ_i, φ_j) réels
    _h_sum=0; _h_count=0
    for _e1 in "${_zemails[@]}"; do
        for _e2 in "${_zemails[@]}"; do
            [[ "$_e1" == "$_e2" ]] && continue
            _phi_i="${email_phi[$_e1]:-}"; _phi_j="${email_phi[$_e2]:-}"
            [[ -z "$_phi_i" || -z "$_phi_j" ]] && continue
            _k=$(python3 -c "import math,sys; a,b=float(sys.argv[1]),float(sys.argv[2]); print('%.4f'%(1.0/(1.0+abs(math.sin(a-b)))))" \
                "$_phi_i" "$_phi_j" 2>/dev/null) || continue
            _h_sum=$(python3 -c "import sys; print(float(sys.argv[1])+float(sys.argv[2]))" \
                "$_h_sum" "$_k" 2>/dev/null) || continue
            ((_h_count++))
        done
    done
    _h_score="0.50"
    [[ $_h_count -gt 0 ]] && _h_score=$(python3 -c "import sys; print('%.2f'%(float(sys.argv[1])/int(sys.argv[2])))" \
        "$_h_sum" "$_h_count" 2>/dev/null) || true

    # Calculer le centre GPS approximatif et l'adresse a4l: (si Phi2X_Math disponible)
    _hex_addr="a4l:zone_${_latzone}_${_lonzone}"
    _gps_str="${_latzone}°N, ${_lonzone}°E"

    printf "  🔊 SWARM détecté : %s (%d atomes, H=%.2f)\n" "$_zkey" "${#_zemails[@]}" "$_h_score"

    # Construire le bloc HTML d'alerte swarm
    _swarm_html=$(cat << SWARMEOF
<div style="background:linear-gradient(135deg,#1e1b4b,#7c3aed);border-radius:12px;padding:1.2rem;margin:.8rem 0;color:#fff">
  <div style="font-size:1rem;font-weight:700;margin-bottom:.4rem">🔊 Voisins détectés — Chœur des Nœuds</div>
  <div style="font-size:.84rem;opacity:.9;margin-bottom:.8rem">
    <strong>${#_zemails[@]} membres ATOM4LOVE</strong> vivent dans votre zone (rayon 0.01° ≈ 1 km).<br>
    Score d'harmonie actuel : <strong>H = ${_h_score}</strong> — objectif : H ≥ 0.95.
  </div>
  <div style="background:rgba(255,255,255,.08);border-radius:8px;padding:.6rem .8rem;font-size:.78rem;margin-bottom:.8rem;border-left:3px solid rgba(255,255,255,.3)">
    <strong style="font-size:.8rem">💡 Pourquoi ces personnes ?</strong><br>
    UPlanet utilise uniquement votre <em>zone géographique</em> (précision 0.01°, ~1 km) pour détecter les membres physiquement proches. Ni votre poids de naissance ni votre polarité ne sont transmis. Ce signal vous invite à explorer si une proximité spatiale résonne avec une proximité de Kin Maya.
  </div>
  <div style="background:rgba(255,255,255,.12);border-radius:8px;padding:.7rem;font-size:.8rem;margin-bottom:.7rem">
    📍 <strong>Zone</strong> : ${_gps_str} · précision 0.01° ≈ 1 km<br>
    🔮 <strong>Adresse hexagonale</strong> : <code>${_hex_addr}</code><br>
    📅 <strong>Mission</strong> : Ce dimanche, activez vos radars LOCA. Vos téléphones commenceront à chanter ensemble. Déplacez-vous jusqu'à l'<strong>Accord Parfait</strong> (H ≥ 0.95).
  </div>
  <div style="font-size:.78rem;opacity:.8">
    Participants : $(IFS=', '; echo "${_zemails[*]}" | sed 's/\b\([a-z]\{1,4\}\)[a-z0-9.]*@/\1***@/g')
  </div>
</div>
SWARMEOF
)

    # Envoyer l'alerte à chaque membre du swarm (avec leur omega_bio si disponible)
    # En mode --player : uniquement au joueur ciblé
    for _semail in "${_zemails[@]}"; do
        [[ -z "$_semail" ]] && continue
        [[ -n "${TARGET_PLAYER:-}" && "$_semail" != "$TARGET_PLAYER" ]] && continue
        _tmpswarm=$(mktemp /tmp/kin_swarm_XXXXXX.html)
        cat << HTMLEOF > "$_tmpswarm"
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>🔊 Swarm détecté — Votre Choeur attend</title>
<style>body{margin:0;background:#0f0e17;font-family:-apple-system,sans-serif}.w{max-width:600px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden}
.ft{background:#f7f7fb;padding:1rem;text-align:center;font-size:.7rem;color:#9ca3af}a{color:#7c3aed}</style>
</head><body><div class="w">
${_swarm_html}
<div style="padding:1rem 1.5rem">
  <p style="font-size:.84rem;color:#374151">
    🎙️ <strong>Préparez votre instrument :</strong> si vous n'avez pas encore enregistré votre Mantra vocal dans ATOM4LOVE (PROFIL → 🎙️), faites-le avant le rassemblement. Votre voix sera automatiquement pitchée sur votre résonance <strong>${_h_score} Hz</strong>.
  </p>
  <div style="text-align:center;margin-top:1rem">
    <a href="https://u.copylaradio.com/apk/atom4love.apk"
       style="background:#7c3aed;color:#fff;padding:.5rem 1.2rem;border-radius:8px;text-decoration:none;font-size:.85rem;font-weight:600">
      📲 Ouvrir ATOM4LOVE
    </a>
  </div>
</div>
<div class="ft">ATOM4LOVE Alpha · G1FabLab · UPlanet ORIGIN<br>
</div></body></html>
HTMLEOF
        if [[ -x "$MJ" ]]; then
            "$MJ" "$_semail" "$_tmpswarm" \
                "🔊 Swarm détecté — ${#_zemails[@]} atomes dans votre zone, H=${_h_score}" 2>/dev/null && \
                printf "    📧 Alerte swarm → %s\n" "$_semail"
        fi
        rm -f "$_tmpswarm"
    done
done

[[ $swarm_count -eq 0 ]] && echo "  ℹ️  Aucun swarm géographique détecté cette semaine"

touch "$MARKER_FILE"
exit 0
