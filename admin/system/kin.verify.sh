#!/bin/bash
umask 077
################################################################################
# admin/system/kin.verify.sh
#
# Audit et correction des données DID + Kin Maya pour tous les MULTIPASS.
#
# Pour chaque MULTIPASS local (~/.zen/game/nostr/<email>/) :
#   - Présence des fichiers essentiels créés par make_NOSTRCARD.sh
#   - Cohérence des clés (HEX / NPUB / G1PUBNOSTR) entre fichiers et .secret.nostr
#   - Conformité du DID (did.json.cache) : id, champs obligatoires, JSON valide
#   - Badge MayaKin dans .metadata.badges[] si BIRTHDATE présent
#   - Cohérence Kin recalculé vs valeur dans le DID
#   - Distinction .BIRTHDATE (naissance) vs .account_created (facturation — ne pas confondre)
#   - ZUMAP / GPS présents et non nuls
#
# Pour le swarm (lecture seule via relay local kind 30800) :
#   - Compte des DID publiés avec/sans badge MayaKin
#
# Corrections possibles (--fix, local uniquement) :
#   - DID manquant ou invalide → did_manager_nostr.sh update
#   - Badge MayaKin absent alors que BIRTHDATE est présent → même commande
#   - Kin incohérent entre DID et recalcul → mise à jour DID
#
# Usage :
#   ./kin.verify.sh                       # Audit seul (rapport)
#   ./kin.verify.sh --fix                 # Audit + corrections automatiques
#   ./kin.verify.sh --email alice@ex.com  # Cibler un seul MULTIPASS
#   ./kin.verify.sh --swarm               # Inclure l'audit relay (lecture seule)
#   ./kin.verify.sh --fix --email ...     # Corriger un MULTIPASS précis
#   ./kin.verify.sh --match               # Correspondances oracle Dreamspell + mailjet
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
FIX=false
SWARM=false
MATCH=false
TARGET_EMAIL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)    FIX=true ;;
        --swarm)  SWARM=true ;;
        --match)  MATCH=true ;;
        --email)  TARGET_EMAIL="$2"; shift ;;
        -h|--help)
            awk '/^MY_PATH=/{exit} /^#[^!]/{sub(/^# ?/,""); print}' "$0"
            exit 0
            ;;
        *)
            echo "Option inconnue : $1  (--fix | --swarm | --match | --email <email> | --help)" >&2
            exit 1
            ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Charger kin.sh pour le recalcul Kin Maya
# ---------------------------------------------------------------------------
KIN_SH="${MY_PATH}/../../tools/kin.sh"
if [[ ! -f "$KIN_SH" ]]; then
    echo "❌ kin.sh introuvable : ${KIN_SH}" >&2
    exit 1
fi
source "$KIN_SH"

# Bibliothèque Oracle Dreamspell partagée (tables, HTML, GPS, haversine)
KIN_ORACLE_SH="${MY_PATH}/../../tools/kin_oracle.sh"
if [[ ! -f "$KIN_ORACLE_SH" ]]; then
    echo "❌ kin_oracle.sh introuvable : ${KIN_ORACLE_SH}" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$KIN_ORACLE_SH"

DID_MANAGER="${MY_PATH}/../../tools/did_manager_nostr.sh"

# ---------------------------------------------------------------------------
# Compteurs globaux
# ---------------------------------------------------------------------------
TOTAL=0
TOTAL_OK=0
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_FIXED=0
declare -a REPORT_ERRORS=()
declare -a REPORT_FIXES=()

# ---------------------------------------------------------------------------
# _ok / _warn / _err / _fix / _ask / _pause — helpers
# ---------------------------------------------------------------------------
_ok()   { echo "    ✅ $*"; }
_warn() { echo "    ⚠️  $*"; ((TOTAL_WARNINGS++)); }
_err()  { echo "    ❌ $*"; ((TOTAL_ERRORS++)); REPORT_ERRORS+=("${_CURRENT_EMAIL}: $*"); }
_info() { echo "    ℹ️  $*"; }
_fix()  { echo "    🔧 $*"; ((TOTAL_FIXED++)); REPORT_FIXES+=("${_CURRENT_EMAIL}: $*"); }

# Lire depuis /dev/tty (résiste aux redirections stdin de la boucle find)
_ask() {
    local _prompt="$1" _default="$2" _var="$3"
    local _hint=""
    [[ -n "$_default" ]] && _hint=" [${_default}]"
    printf "    %s%s : " "$_prompt" "$_hint" > /dev/tty
    local _input
    read -r _input < /dev/tty
    # Utiliser la valeur par défaut si saisie vide
    [[ -z "$_input" && -n "$_default" ]] && _input="$_default"
    printf -v "$_var" '%s' "$_input"
}

# Pause entre profils : [Entrée]=continuer  q=quitter
# Retourne 1 si l'utilisateur tape 'q'
_pause() {
    printf "\n  ── [Entrée] profil suivant  |  [q] quitter ──\n" > /dev/tty
    local _k
    read -r -s -n1 _k < /dev/tty
    echo > /dev/tty
    [[ "$_k" == "q" || "$_k" == "Q" ]] && return 1
    return 0
}

# ---------------------------------------------------------------------------
# _propose_mailjet_group <type_groupe> <email1> [email2 ...]
# Globals lus : _MATCH_GROUP_HTML  _MATCH_TONE_NUM  _MATCH_TONE_NAME
# ---------------------------------------------------------------------------
_MATCH_GROUP_HTML=""
_MATCH_TONE_NUM=""
_MATCH_TONE_NAME=""

_propose_mailjet_group() {
    local group_type="$1"; shift
    local -a all_emails=("$@")
    [[ ${#all_emails[@]} -eq 0 ]] && return

    printf "\n    📧 Notifier ce groupe (%d membre(s)) ?\n" "${#all_emails[@]}"
    printf "       %s\n" "${all_emails[@]}"

    local _answer
    _ask "    Envoyer ? [o/N]" "N" _answer
    [[ "${_answer,,}" != "o" && "${_answer,,}" != "oui" ]] && return

    local _mj="${MY_PATH}/../../tools/mailjet.sh"
    if [[ ! -x "$_mj" ]]; then
        echo "    ⚠️  mailjet.sh introuvable : $_mj"
        return
    fi

    local _tmpl_dir="${MY_PATH}/../../templates/KIN"
    local _tmpl
    case "$group_type" in
        *Quatuor*)  _tmpl="${_tmpl_dir}/kin_quartet.html" ;;
        *Occulte*)  _tmpl="${_tmpl_dir}/kin_occult.html"  ;;
        *Analogue*) _tmpl="${_tmpl_dir}/kin_analog.html"  ;;
        *Tonalité*) _tmpl="${_tmpl_dir}/kin_council.html" ;;
        *)          _tmpl="${_tmpl_dir}/kin_match.html"   ;;
    esac
    local _tmpfile
    _tmpfile=$(mktemp /tmp/kin_match_XXXXXX.html)

    local _date
    _date=$(LC_ALL=fr_FR.UTF-8 date -u '+%-d %B %Y' 2>/dev/null || date -u '+%Y-%m-%d')

    if [[ -f "$_tmpl" ]]; then
        local _entriesfile
        _entriesfile=$(mktemp /tmp/kin_entries_XXXXXX.html)
        printf '%s' "$_MATCH_GROUP_HTML" > "$_entriesfile"
        awk -v gtype="$group_type" \
            -v tnum="${_MATCH_TONE_NUM:-}" \
            -v tname="${_MATCH_TONE_NAME:-}" \
            -v datestr="$_date" \
            -v efile="$_entriesfile" \
            '/_KIN_ENTRIES_/ { while ((getline line < efile) > 0) print line; next }
             { gsub(/_GROUP_TYPE_/, gtype); gsub(/_TONE_NUM_/, tnum);
               gsub(/_TONE_NAME_/, tname); gsub(/_DATE_/, datestr); print }' \
            "$_tmpl" > "$_tmpfile"
        rm -f "$_entriesfile"
    else
        # Fallback minimaliste si le template est absent
        {
            printf '<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
            printf '<body style="font-family:sans-serif;background:#0f0e17;padding:20px">'
            printf '<div style="max-width:600px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden">'
            printf '<div style="background:linear-gradient(135deg,#1e1b4b,#4c1d95);color:#fff;padding:2rem;text-align:center">'
            printf '<div style="font-size:2.5rem">🌀</div><h2 style="margin:.5rem 0">%s</h2></div>' "$group_type"
            printf '<div style="padding:1.5rem">%s</div>' "$_MATCH_GROUP_HTML"
            printf '<div style="background:#f7f7fb;padding:1rem;text-align:center;font-size:.78rem;color:#9ca3af">'
            printf 'Calendrier Dreamspell · Toile de Kin Oracle · UPlanet</div></div></body></html>'
        } > "$_tmpfile"
    fi

    local _subject="🌀 Kin Maya — ${group_type}"
    for _dest in "${all_emails[@]}"; do
        [[ -z "$_dest" ]] && continue
        echo "    📤 Envoi à ${_dest}…"
        "$_mj" "${_dest}" "${_tmpfile}" "${_subject}" 2>&1 | tail -3
    done
    sleep 1
    rm -f "$_tmpfile"
}

# ---------------------------------------------------------------------------
# verify_multipass <email>
# ---------------------------------------------------------------------------
verify_multipass() {
    local email="$1"
    local dir="${HOME}/.zen/game/nostr/${email}"
    _CURRENT_EMAIL="$email"
    local local_errors_before=$TOTAL_ERRORS

    echo ""
    echo "  ┌─────────────────────────────────────────────────────────"
    echo "  │ 📋 ${email}"
    echo "  └─────────────────────────────────────────────────────────"

    # -- 1. Répertoire --------------------------------------------------------
    if [[ ! -d "$dir" ]]; then
        _err "Répertoire absent : $dir"
        ((TOTAL++))
        return
    fi

    # -- 2. Fichiers essentiels (publics) ------------------------------------
    local -a essential_pub=(G1PUBNOSTR HEX NPUB NOSTRNS LANG ZUMAP)
    for f in "${essential_pub[@]}"; do
        if [[ ! -s "${dir}/${f}" ]]; then
            _err "Fichier manquant/vide : ${f}"
        else
            local _val
            _val=$(head -c 64 "${dir}/${f}")
            _ok "${f} = ${_val}"
        fi
    done

    # -- 3. Fichiers cachés obligatoires ------------------------------------
    local -a essential_hidden=(.secret.nostr .secret.disco .ssss.player.key)
    for f in "${essential_hidden[@]}"; do
        if [[ ! -s "${dir}/${f}" ]]; then
            _warn "Fichier caché manquant : ${f}"
        else
            _ok "${f} [présent]"
        fi
    done

    # -- 4. Cohérence HEX : fichier vs .secret.nostr ------------------------
    local hex_file npub_file hex_secret npub_secret
    hex_file=$(cat "${dir}/HEX" 2>/dev/null | tr -d '[:space:]')
    npub_file=$(cat "${dir}/NPUB" 2>/dev/null | tr -d '[:space:]')
    hex_secret=$(grep -oP 'HEX=\K[^;]+' "${dir}/.secret.nostr" 2>/dev/null | tr -d '[:space:]')
    npub_secret=$(grep -oP 'NPUB=\K[^;]+' "${dir}/.secret.nostr" 2>/dev/null | tr -d '[:space:]')

    if [[ -n "$hex_file" && -n "$hex_secret" ]]; then
        if [[ "$hex_file" == "$hex_secret" ]]; then
            _ok "Cohérence HEX OK"
        else
            _err "HEX incohérent : fichier=${hex_file:0:12}… ≠ .secret.nostr=${hex_secret:0:12}…"
        fi
    fi

    if [[ -n "$npub_file" && -n "$npub_secret" ]]; then
        if [[ "$npub_file" == "$npub_secret" ]]; then
            _ok "Cohérence NPUB OK"
        else
            _err "NPUB incohérent : fichier ≠ .secret.nostr"
        fi
    fi

    # -- 5. DID cache ---------------------------------------------------------
    local did_cache="${dir}/did.json.cache"
    local did_present=false

    if [[ ! -s "$did_cache" ]]; then
        _err "DID cache absent : did.json.cache"
        if [[ "$FIX" == "true" && -x "$DID_MANAGER" ]]; then
            echo "    🔧 Régénération DID..."
            local _dm_out
            _dm_out=$("$DID_MANAGER" update "${email}" MULTIPASS 0 0 2>&1)
            if [[ $? -eq 0 ]]; then
                _fix "DID régénéré (update MULTIPASS)"
                did_present=true
            else
                echo "$_dm_out" >&2
                _err "Échec régénération DID — voir sortie ci-dessus"
            fi
        fi
    else
        did_present=true
    fi

    if [[ "$did_present" == "true" && -s "$did_cache" ]]; then

        # 5a. JSON valide ?
        if ! jq empty "$did_cache" 2>/dev/null; then
            _err "DID cache JSON invalide"
        else
            _ok "DID cache JSON valide"

            # 5b. Champs W3C obligatoires
            for field in id verificationMethod; do
                if ! jq -e ".$field" "$did_cache" >/dev/null 2>&1; then
                    _err "Champ DID manquant : .${field}"
                fi
            done

            # 5c. Cohérence did:nostr:<hex> vs fichier HEX
            local did_hex
            did_hex=$(jq -r '.id // empty' "$did_cache" 2>/dev/null | sed 's/^did:nostr://')
            if [[ -n "$did_hex" && -n "$hex_file" ]]; then
                if [[ "$did_hex" == "$hex_file" ]]; then
                    _ok "DID .id cohérent avec HEX"
                else
                    _err "DID .id incohérent : did_hex=${did_hex:0:12}… ≠ HEX=${hex_file:0:12}…"
                fi
            fi

            # 5d. Badge MayaKin (uniquement si profil LOVE activé — .secret.love présent)
            local birthdate love_active=false
            [[ -f "${dir}/.secret.love" ]] && love_active=true
            birthdate=$(cat "${dir}/.BIRTHDATE" 2>/dev/null | tr -d '[:space:]')

            if [[ "$love_active" != "true" ]]; then
                _info "Profil LOVE non activé (.secret.love absent) — Kin Maya ignoré"
            elif [[ -n "$birthdate" ]]; then
                _info "BIRTHDATE (naissance) : ${birthdate}"

                # Valider format date
                if [[ ! "$birthdate" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    _err "BIRTHDATE format invalide (attendu YYYY-MM-DD) : '${birthdate}'"
                else
                    local kin_badge
                    kin_badge=$(jq -r '
                        .metadata.badges // []
                        | map(select(.type == "MayaKin"))
                        | first // empty
                    ' "$did_cache" 2>/dev/null)

                    if [[ -z "$kin_badge" || "$kin_badge" == "null" ]]; then
                        _err "Badge MayaKin absent dans .metadata.badges[] (BIRTHDATE=${birthdate})"

                        if [[ "$FIX" == "true" && -x "$DID_MANAGER" ]]; then
                            echo "    🔧 Mise à jour DID pour inclure badge Kin Maya..."
                            local _dm_out
                            _dm_out=$("$DID_MANAGER" update "${email}" MULTIPASS 0 0 2>&1)
                            if [[ $? -eq 0 ]]; then
                                # Re-vérification après correction
                                kin_badge=$(jq -r '
                                    .metadata.badges // []
                                    | map(select(.type == "MayaKin"))
                                    | first // empty
                                ' "$did_cache" 2>/dev/null)
                                if [[ -n "$kin_badge" && "$kin_badge" != "null" ]]; then
                                    local kin_added
                                    kin_added=$(echo "$kin_badge" | jq -r '.kin')
                                    _fix "Badge MayaKin ajouté : Kin ${kin_added}"
                                else
                                    _err "Badge MayaKin toujours absent après correction"
                                fi
                            else
                                echo "$_dm_out" >&2
                                _err "Échec did_manager_nostr.sh lors de la correction Kin — voir sortie ci-dessus"
                            fi
                        fi

                    else
                        local kin_in_did
                        kin_in_did=$(echo "$kin_badge" | jq -r '.kin // 0')

                        # Recalcul indépendant pour vérification
                        local kin_computed_json kin_computed
                        kin_computed_json=$(maya_kin_json "$birthdate" 2>/dev/null)
                        kin_computed=$(echo "$kin_computed_json" | jq -r '.kin // 0' 2>/dev/null)

                        if [[ "$kin_in_did" == "$kin_computed" ]]; then
                            local glyph tone color
                            glyph=$(echo "$kin_badge" | jq -r '.glyph')
                            tone=$(echo "$kin_badge" | jq -r '.tone')
                            color=$(echo "$kin_badge" | jq -r '.color')
                            _ok "Kin Maya cohérent : Kin ${kin_in_did} — ${color} ${glyph}, Tonalité ${tone}"
                        else
                            _err "Kin incohérent : DID=${kin_in_did} ≠ recalculé=${kin_computed} (BIRTHDATE=${birthdate})"

                            if [[ "$FIX" == "true" && -x "$DID_MANAGER" ]]; then
                                echo "    🔧 Correction Kin : régénération DID..."
                                local _dm_out
                                _dm_out=$("$DID_MANAGER" update "${email}" MULTIPASS 0 0 2>&1)
                                if [[ $? -eq 0 ]]; then
                                    _fix "Kin corrigé dans DID (${kin_in_did} → ${kin_computed})"
                                else
                                    echo "$_dm_out" >&2
                                    _err "Échec correction Kin dans DID — voir sortie ci-dessus"
                                fi
                            fi
                        fi
                    fi
                fi

            else
                # BIRTHDATE absent — toujours demander (lecture /dev/tty, résiste aux boucles)
                echo ""
                local _bd_hint
                # Proposer la date contenue dans .birth_datetime si disponible
                _bd_hint=$(cat "${dir}/.birth_datetime" 2>/dev/null | grep -oP '^\d{4}-\d{2}-\d{2}' | head -1)
                local birthdate_input
                _ask "🌀 Date de naissance (YYYY-MM-DD, vide=ignorer)" "${_bd_hint}" birthdate_input
                if [[ "$birthdate_input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    echo "$birthdate_input" > "${dir}/.BIRTHDATE"
                    _fix "BIRTHDATE ajouté : ${birthdate_input}"
                    if [[ -x "$DID_MANAGER" ]]; then
                        echo "    🔧 Mise à jour DID avec Kin Maya..."
                        local _dm_out
                        _dm_out=$("$DID_MANAGER" update "${email}" MULTIPASS 0 0 2>&1)
                        if [[ $? -eq 0 ]]; then
                            local kin_new
                            kin_new=$(jq -r '
                                .metadata.badges // []
                                | map(select(.type == "MayaKin"))
                                | first.kin // "?"
                            ' "${did_cache}" 2>/dev/null)
                            _fix "Badge MayaKin ajouté dans DID : Kin ${kin_new}"
                        else
                            echo "$_dm_out" >&2
                            _err "Échec mise à jour DID après ajout BIRTHDATE"
                        fi
                    fi
                else
                    _info "BIRTHDATE ignoré"
                fi
            fi

            # 5e. Surveillance confusion BIRTHDATE vs .account_created (facturation)
            local billing_date
            billing_date=$(cat "${dir}/.account_created" 2>/dev/null | tr -d '[:space:]')
            if [[ -n "$birthdate" && -n "$billing_date" && "$birthdate" == "$billing_date" ]]; then
                _warn "BIRTHDATE == .account_created : possible confusion date de naissance / date d'inscription (facturation)"
            elif [[ -n "$billing_date" ]]; then
                _ok ".account_created (facturation) = ${billing_date} — distinct de BIRTHDATE"
            fi
        fi
    fi

    # -- 6. GPS / ZUMAP -------------------------------------------------------
    local zumap gps
    zumap=$(cat "${dir}/ZUMAP" 2>/dev/null | tr -d '[:space:]')
    gps=$(cat "${dir}/GPS" 2>/dev/null)

    # Restauration GPS depuis DID chiffré (utile pour stations distantes importées)
    if [[ -z "$gps" && "$did_present" == "true" && -s "$did_cache" ]]; then
        local _gps_enc
        _gps_enc=$(jq -r '.metadata.coordinates.encrypted // empty' "$did_cache" 2>/dev/null)
        if [[ -n "$_gps_enc" ]] && command -v gps_decrypt &>/dev/null; then
            local _gps_dec
            _gps_dec=$(gps_decrypt "$_gps_enc" 2>/dev/null)
            if [[ -n "$_gps_dec" ]]; then
                echo "$_gps_dec" > "${dir}/GPS"
                gps="$_gps_dec"
                local _rlat _rlon
                _rlat=$(echo "$_gps_dec" | grep -oP '(?<=LAT=)[^;]+' | tr -d ' ')
                _rlon=$(echo "$_gps_dec" | grep -oP '(?<=LON=)[^;]+' | tr -d ' ')
                if [[ -n "$_rlat" && -n "$_rlon" ]]; then
                    printf "_%s_%s" "$_rlat" "$_rlon" > "${dir}/ZUMAP"
                    zumap="_${_rlat}_${_rlon}"
                fi
                _fix "GPS restauré depuis DID chiffré : ${_gps_dec}"
            fi
        fi
    fi

    if [[ -z "$zumap" || "$zumap" == "_0_0" || "$zumap" == "__" ]]; then
        _warn "ZUMAP absent ou nul : '${zumap}'"
        echo ""
        # Proposer les coordonnées de la station comme défaut
        local _def_lat _def_lon
        _def_lat=$(grep -oP 'LAT=\K[^;]+' ~/.zen/GPS 2>/dev/null | tr -d '[:space:]')
        _def_lon=$(grep -oP 'LON=\K[^;]+' ~/.zen/GPS 2>/dev/null | tr -d '[:space:]')
        local lat_input lon_input
        _ask "📍 Latitude  (ex: 48.85, vide=ignorer)" "${_def_lat}" lat_input
        if [[ -n "$lat_input" && "$lat_input" != "ignorer" ]]; then
            _ask "📍 Longitude (ex: 2.35)" "${_def_lon}" lon_input
            if [[ -n "$lon_input" ]]; then
                local lat_coord lon_coord
                lat_coord=$(awk -v v="$lat_input" 'BEGIN{printf "%.2f", v+0}' 2>/dev/null || echo "$lat_input")
                lon_coord=$(awk -v v="$lon_input" 'BEGIN{printf "%.2f", v+0}' 2>/dev/null || echo "$lon_input")
                printf "_%s_%s" "$lat_coord" "$lon_coord" > "${dir}/ZUMAP"
                printf "LAT=%s; LON=%s;" "$lat_coord" "$lon_coord" > "${dir}/GPS"
                _fix "ZUMAP/GPS ajoutés : LAT=${lat_coord}, LON=${lon_coord}"
            fi
        else
            _info "GPS ignoré"
        fi
    else
        _ok "ZUMAP : ${zumap}"
    fi

    if [[ -z "$gps" ]]; then
        _warn "GPS absent"
    else
        _ok "GPS : ${gps}"
    fi

    # -- 7. home.station (auto-régénéré si absent) ----------------------------
    if [[ ! -s "${dir}/home.station" ]]; then
        _warn "home.station absent"
        if [[ "$FIX" == "true" ]]; then
            local _node_hex=""
            [[ -s ~/.zen/game/secret.nostr ]] \
                && _node_hex=$(grep -oP 'HEX=\K[^;]+' ~/.zen/game/secret.nostr 2>/dev/null | tr -d '[:space:]')
            echo "${IPFSNODEID}:${_node_hex}" > "${dir}/home.station"
            chmod 644 "${dir}/home.station"
            _fix "home.station régénéré : ${IPFSNODEID:0:20}…"
        fi
    else
        _ok "home.station : $(head -c 60 "${dir}/home.station")"
    fi

    # -- 8. uDRIVE ------------------------------------------------------------
    if [[ ! -d "${dir}/APP/uDRIVE" ]]; then
        _warn "uDRIVE absent : APP/uDRIVE/"
    else
        _ok "uDRIVE : APP/uDRIVE/ présent"
    fi

    # -- Résumé MULTIPASS -----------------------------------------------------
    local mp_errors=$(( TOTAL_ERRORS - local_errors_before ))
    echo ""
    if [[ $mp_errors -eq 0 ]]; then
        _ok "RÉSULTAT : conforme"
        ((TOTAL_OK++))
    else
        echo "    ❌ RÉSULTAT : ${mp_errors} erreur(s) détectée(s)"
    fi

    ((TOTAL++))
}

# ---------------------------------------------------------------------------
# audit_swarm — lecture seule via relay local (kind 30800)
# ---------------------------------------------------------------------------
audit_swarm() {
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "🌐  AUDIT SWARM — Relay local kind 30800 (lecture seule)"
    echo "══════════════════════════════════════════════════════════"

    local strfry_dir="${HOME}/.zen/strfry"
    local strfry_bin="${strfry_dir}/strfry"

    if [[ ! -x "$strfry_bin" ]]; then
        echo "  ⚠️  strfry non disponible : ${strfry_bin}"
        echo "  ℹ️  Audit swarm limité (relay non interrogeable localement)"
        local swarm_dir="${HOME}/.zen/tmp/swarm"
        if [[ -d "$swarm_dir" ]]; then
            local n
            n=$(find "${swarm_dir}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
            echo "  ℹ️  Stations swarm détectées : ${n}"
        fi
        return
    fi

    # Ordre des 20 sceaux et des 5 couleurs (Dreamspell)
    local -a SEALS=(Imix Ik Akbal Kan Chicchan Cimi Manik Lamat Muluc Oc
                    Chuen Eb Ben Ix Men Cib Caban Etznab Cauac Ahau)
    local -a COLORS=(Rouge Blanc Bleu Jaune Vert)
    local -A COLOR_ICO=([Rouge]="🔴" [Blanc]="⚪" [Bleu]="🔵" [Jaune]="🟡" [Vert]="🟢")
    local -A TONE_SHORT=(
        [Magnétique]="T1" [Lunaire]="T2" [Électrique]="T3" [Auto-existante]="T4"
        [Harmonique]="T5" [Rythmique]="T6" [Résonnante]="T7" [Galactique]="T8"
        [Solaire]="T9" [Planétaire]="T10" [Spectrale]="T11" [Cristal]="T12" [Cosmique]="T13"
    )

    echo "  📡 Scan kind 30800 dans relay local..."

    local count=0 with_kin=0 without_kin=0 invalid_json=0
    # Tableaux associatifs : clé = "Couleur|Sceau"  valeur = liste "email(Kin,Tone) ..."
    declare -A groups=()
    declare -a no_kin_list=()

    while IFS= read -r event_line; do
        [[ -z "$event_line" ]] && continue
        ((count++))

        local content did_json
        content=$(echo "$event_line" | jq -r '.content // empty' 2>/dev/null)
        if [[ -z "$content" ]]; then ((invalid_json++)); continue; fi
        did_json=$(echo "$content" | jq . 2>/dev/null)
        if [[ -z "$did_json" ]]; then ((invalid_json++)); continue; fi

        local sw_email
        sw_email=$(echo "$did_json" | jq -r '
            .metadata.email // (.alsoKnownAs // [] | map(select(startswith("mailto:"))) | first // "?")
        ' 2>/dev/null | sed 's/^mailto://')

        local kin_obj
        kin_obj=$(echo "$did_json" | jq -c '
            .metadata.badges // []
            | map(select(.type == "MayaKin")) | first // empty
        ' 2>/dev/null)

        if [[ -n "$kin_obj" && "$kin_obj" != "null" && "$kin_obj" != "empty" ]]; then
            ((with_kin++))
            local sw_kin sw_glyph sw_color sw_tone
            sw_kin=$(echo "$kin_obj"   | jq -r '.kin   // "?"')
            sw_glyph=$(echo "$kin_obj" | jq -r '.glyph // "?"')
            sw_color=$(echo "$kin_obj" | jq -r '.color // "?"')
            sw_tone=$(echo "$kin_obj"  | jq -r '.tone  // ""')
            local _tshort="${TONE_SHORT[$sw_tone]:-$sw_tone}"
            local _key="${sw_color}|${sw_glyph}"
            local _entry="${sw_email}(${sw_kin},${_tshort})"
            groups["$_key"]+="${_entry} "
        else
            ((without_kin++))
            no_kin_list+=("${sw_email}")
        fi

    done < <(cd "${strfry_dir}" && ./strfry scan '{"kinds":[30800]}' 2>/dev/null)

    # --------------- Affichage groupé ----------------------------------------
    echo ""
    printf "  📊 %d DID  |  🌀 %d avec Kin Maya  |  ❓ %d sans Kin Maya\n" \
           "$count" "$with_kin" "$without_kin"
    [[ $invalid_json -gt 0 ]] && echo "  ⚠️  JSON invalide : ${invalid_json}"

    echo ""
    for color in "${COLORS[@]}"; do
        local ico="${COLOR_ICO[$color]}"
        # Compter les membres de cette couleur
        local color_count=0
        local color_block=""
        for seal in "${SEALS[@]}"; do
            local _key="${color}|${seal}"
            [[ -z "${groups[$_key]:-}" ]] && continue
            local members="${groups[$_key]}"
            local nb
            nb=$(echo "$members" | wc -w)
            ((color_count += nb))
            color_block+="    ${seal} : ${members}\n"
        done
        [[ $color_count -eq 0 ]] && continue
        echo "  ${ico} ${color} — ${color_count} membre(s)"
        printf "%b" "$color_block"
        echo ""
    done

    if [[ ${#no_kin_list[@]} -gt 0 ]]; then
        echo "  ❓ Sans Kin Maya — ${#no_kin_list[@]} membre(s)"
        printf "    %s\n" "${no_kin_list[@]}"
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# match_mode — Correspondances Oracle Dreamspell (occult, analogue, quatuor, tonalité)
# ---------------------------------------------------------------------------
match_mode() {
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "🔮  MATCH MODE — Correspondances Oracle Dreamspell"
    echo "══════════════════════════════════════════════════════════"

    local strfry_dir="${HOME}/.zen/strfry"
    local strfry_bin="${strfry_dir}/strfry"

    if [[ ! -x "$strfry_bin" ]]; then
        echo "  ⚠️  strfry non disponible — impossible d'analyser les correspondances"
        return
    fi

    # ── Collecte des profils Kin depuis le relay ──────────────────────────
    declare -A kin_emails=()    # kin_number → "email1 email2 …"

    echo "  📡 Collecte des profils Kin Maya depuis relay local..."
    local total_profiles=0

    while IFS= read -r _evt; do
        [[ -z "$_evt" ]] && continue
        local _cnt _email _kin
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
        # Éviter les doublons d'email pour le même kin
        [[ "${kin_emails[$_kin]:-}" == *"${_email}"* ]] && continue
        kin_emails["$_kin"]+="${_email} "
        ((total_profiles++))
        # Extraire GPS depuis DID (chiffré puis texte clair en fallback)
        if command -v gps_parse_did_coords &>/dev/null; then
            eval "$(gps_parse_did_coords "$_cnt" 2>/dev/null)"
            if [[ -n "${GPS_LAT_PARSED:-}" && -n "${GPS_LON_PARSED:-}" ]]; then
                email_gps["$_email"]="LAT=${GPS_LAT_PARSED}; LON=${GPS_LON_PARSED};"
            fi
        fi
        # Extraire URL profil IPNS depuis serviceEndpoint #ipns-storage
        local _ipns_url
        _ipns_url=$(echo "$_cnt" | jq -r '
            .service // [] | map(select(.id | endswith("#ipns-storage"))) | first.serviceEndpoint // ""
        ' 2>/dev/null)
        [[ -n "$_ipns_url" ]] && email_nostrns["$_email"]="$_ipns_url"
    done < <(cd "${strfry_dir}" && ./strfry scan '{"kinds":[30800]}' 2>/dev/null)

    printf "  📊 %d profil(s) avec Kin Maya analysés (%d Kin distincts)\n" \
           "$total_profiles" "${#kin_emails[@]}"

    if [[ $total_profiles -lt 2 ]]; then
        echo "  ℹ️  Moins de 2 profils — aucune correspondance possible"
        return
    fi

    local found_groups=0 quartet_count=0 occult_count=0 analog_count=0 council_count=0
    declare -A shown=()   # kins déjà traités (évite les doublons inter-sections)

    # ── Helper : build HTML <ul> pour un ensemble de kins ────────────────
    _match_html() {
        local _h="<ul>"
        for _k in "$@"; do
            local _lbl; _lbl=$(_kin_label "$_k")
            for _e in ${kin_emails[$_k]:-}; do
                [[ -n "$_e" ]] && _h+="<li><strong>${_lbl}</strong> — ${_e}</li>"
            done
        done
        _h+="</ul>"
        echo "$_h"
    }

    # ── Helper : liste plate des emails pour un ensemble de kins ─────────
    _match_emails() {
        local -a _arr=()
        for _k in "$@"; do
            for _e in ${kin_emails[$_k]:-}; do
                [[ -n "$_e" ]] && _arr+=("$_e")
            done
        done
        echo "${_arr[@]}"
    }

    # =========================================================================
    # 1. QUATUORS COMPLETS {K, K_ana, 261-K, 261-K_ana}
    # =========================================================================
    echo ""
    echo "  ┌──────────────────────────────────────────────────────"
    echo "  │ 💎 QUATUORS ORACLE COMPLETS"
    echo "  └──────────────────────────────────────────────────────"

    for kin in "${!kin_emails[@]}"; do
        local ana; ana=$(_kin_analog "$kin")
        local occ=$(( 261 - kin ))
        local occ_ana=$(( 261 - ana ))

        # Clé de déduplication : minimum des 4
        local qmin=$kin
        for _q in $ana $occ $occ_ana; do (( _q < qmin )) && qmin=$_q; done
        [[ -n "${shown[$qmin]:-}" ]] && continue

        # Vérifier que les 4 sont présents
        [[ -z "${kin_emails[$occ]:-}"     ]] && continue
        [[ -z "${kin_emails[$ana]:-}"     ]] && continue
        [[ -z "${kin_emails[$occ_ana]:-}" ]] && continue

        shown[$qmin]=1; shown[$kin]=1; shown[$ana]=1; shown[$occ]=1; shown[$occ_ana]=1
        ((quartet_count++)); ((found_groups++))

        echo ""
        printf "  💎 Quatuor #%d\n" "$quartet_count"
        _MATCH_GROUP_HTML=""
        local -a _ems=()
        for _q in $kin $ana $occ $occ_ana; do
            printf "    %s : %s\n" "$(_kin_label "$_q")" "${kin_emails[$_q]}"
            local -a _qemails=()
            read -ra _qemails <<< "${kin_emails[$_q]:-}"
            _MATCH_GROUP_HTML+=$(_kin_member_card "$_q" "${_qemails[@]}")
            for _e in "${_qemails[@]}"; do [[ -n "$_e" ]] && _ems+=("$_e"); done
        done
        _MATCH_GROUP_HTML+=$(_kin_meeting_block $kin $ana $occ $occ_ana)
        _propose_mailjet_group "Quatuor Oracle" "${_ems[@]}"
    done
    [[ $quartet_count -eq 0 ]] && echo "  ℹ️  Aucun quatuor complet dans le swarm"

    # =========================================================================
    # 2. PAIRES OCCULTES K + K' = 261  (hors quatuors)
    # =========================================================================
    echo ""
    echo "  ┌──────────────────────────────────────────────────────"
    echo "  │ 🌙 PAIRES OCCULTES (K + K' = 261)"
    echo "  └──────────────────────────────────────────────────────"

    for kin in "${!kin_emails[@]}"; do
        local occ=$(( 261 - kin ))
        (( occ <= kin )) && continue
        [[ -z "${kin_emails[$occ]:-}" ]] && continue
        local pmin=$(( kin < occ ? kin : occ ))
        [[ -n "${shown[$pmin]:-}" ]] && continue

        shown[$pmin]=1; shown[$kin]=1; shown[$occ]=1
        ((occult_count++)); ((found_groups++))

        local lk; lk=$(_kin_label "$kin")
        local lo; lo=$(_kin_label "$occ")
        echo ""
        printf "  🌙 Paire occulte : %s ↔ %s\n" "$lk" "$lo"
        printf "    %s : %s\n" "$lk" "${kin_emails[$kin]}"
        printf "    %s : %s\n" "$lo" "${kin_emails[$occ]}"

        local -a _k_ems _o_ems
        read -ra _k_ems <<< "${kin_emails[$kin]:-}"
        read -ra _o_ems <<< "${kin_emails[$occ]:-}"
        _MATCH_GROUP_HTML=$(_kin_member_card "$kin" "${_k_ems[@]}")$(_kin_member_card "$occ" "${_o_ems[@]}")
        _MATCH_GROUP_HTML+=$(_kin_meeting_block $kin $occ)
        local -a _ems=("${_k_ems[@]}" "${_o_ems[@]}")
        _propose_mailjet_group "Paire Occulte" "${_ems[@]}"
    done
    [[ $occult_count -eq 0 ]] && echo "  ℹ️  Aucune paire occulte isolée"

    # =========================================================================
    # 3. PAIRES ANALOGUES même tonalité, sceaux ±10  (hors quartets/occultes)
    # =========================================================================
    echo ""
    echo "  ┌──────────────────────────────────────────────────────"
    echo "  │ 🌀 PAIRES ANALOGUES (même tonalité, sceaux ±10)"
    echo "  └──────────────────────────────────────────────────────"

    for kin in "${!kin_emails[@]}"; do
        local ana; ana=$(_kin_analog "$kin")
        (( ana <= kin )) && continue
        [[ -z "${kin_emails[$ana]:-}" ]] && continue
        local pmin=$(( kin < ana ? kin : ana ))
        [[ -n "${shown[$pmin]:-}" ]] && continue

        shown[$pmin]=1; shown[$kin]=1; shown[$ana]=1
        ((analog_count++)); ((found_groups++))

        local lk; lk=$(_kin_label "$kin")
        local la; la=$(_kin_label "$ana")
        echo ""
        printf "  🌀 Paire analogue : %s ↔ %s\n" "$lk" "$la"
        printf "    %s : %s\n" "$lk" "${kin_emails[$kin]}"
        printf "    %s : %s\n" "$la" "${kin_emails[$ana]}"

        local -a _k_ems _a_ems
        read -ra _k_ems <<< "${kin_emails[$kin]:-}"
        read -ra _a_ems <<< "${kin_emails[$ana]:-}"
        _MATCH_GROUP_HTML=$(_kin_member_card "$kin" "${_k_ems[@]}")$(_kin_member_card "$ana" "${_a_ems[@]}")
        _MATCH_GROUP_HTML+=$(_kin_meeting_block $kin $ana)
        local -a _ems=("${_k_ems[@]}" "${_a_ems[@]}")
        _propose_mailjet_group "Paire Analogue" "${_ems[@]}"
    done
    [[ $analog_count -eq 0 ]] && echo "  ℹ️  Aucune paire analogue isolée"

    # =========================================================================
    # 4. CONSEILS DE TONALITÉ — ≥ 2 membres partageant la même tonalité
    # =========================================================================
    echo ""
    echo "  ┌──────────────────────────────────────────────────────"
    echo "  │ 🎵 CONSEILS DE TONALITÉ (même tonalité galactique)"
    echo "  └──────────────────────────────────────────────────────"

    declare -A tone_kins=()   # tone → "kin1 kin2 …"
    for kin in "${!kin_emails[@]}"; do
        local t; t=$(_kin_tone "$kin")
        tone_kins[$t]+="${kin} "
    done

    for ((t=1; t<=13; t++)); do
        [[ -z "${tone_kins[$t]:-}" ]] && continue
        local -a members=()
        read -ra members <<< "${tone_kins[$t]}"
        (( ${#members[@]} < 2 )) && continue

        local tname="${_DS_TONES[$((t-1))]}"
        ((council_count++)); ((found_groups++))
        echo ""
        printf "  🎵 Tonalité %d — %s (%d membres)\n" "$t" "$tname" "${#members[@]}"

        _MATCH_GROUP_HTML=""
        _MATCH_TONE_NUM="$t"
        _MATCH_TONE_NAME="$tname"
        local -a _ems=()
        for _k in "${members[@]}"; do
            printf "    %s : %s\n" "$(_kin_label "$_k")" "${kin_emails[$_k]}"
            local -a _mem_ems=()
            read -ra _mem_ems <<< "${kin_emails[$_k]:-}"
            _MATCH_GROUP_HTML+=$(_kin_member_card "$_k" "${_mem_ems[@]}")
            for _e in "${_mem_ems[@]}"; do [[ -n "$_e" ]] && _ems+=("$_e"); done
        done
        _MATCH_GROUP_HTML+=$(_kin_meeting_block "tone-${t}")
        _propose_mailjet_group "Conseil Tonalité ${t} — ${tname}" "${_ems[@]}"
    done
    [[ $council_count -eq 0 ]] && echo "  ℹ️  Aucun conseil (< 2 membres par tonalité)"

    # ── Bilan ────────────────────────────────────────────────────────────
    echo ""
    echo "══════════════════════════════════════════════════════════"
    printf "  🔮 %d groupe(s) de correspondance oracle trouvé(s)\n" "$found_groups"
    printf "     💎 Quatuors: %d  🌙 Occultes: %d  🌀 Analogues: %d  🎵 Conseils: %d\n" \
           "$quartet_count" "$occult_count" "$analog_count" "$council_count"
    echo "══════════════════════════════════════════════════════════"
}

# ---------------------------------------------------------------------------
# Rapport final
# ---------------------------------------------------------------------------
print_report() {
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "📊  RAPPORT FINAL — $(date -u '+%Y-%m-%d %H:%M UTC')"
    echo "══════════════════════════════════════════════════════════"
    printf "  MULTIPASS vérifiés   : %d\n"  "$TOTAL"
    printf "  Conformes            : %d\n"  "$TOTAL_OK"
    printf "  Erreurs              : %d\n"  "$TOTAL_ERRORS"
    printf "  Avertissements       : %d\n"  "$TOTAL_WARNINGS"
    [[ "$FIX" == "true" ]] && printf "  Corrections          : %d\n" "$TOTAL_FIXED"

    if [[ ${#REPORT_ERRORS[@]} -gt 0 ]]; then
        echo ""
        echo "  Erreurs détectées :"
        for e in "${REPORT_ERRORS[@]}"; do
            echo "    ❌ ${e}"
        done
    fi

    if [[ ${#REPORT_FIXES[@]} -gt 0 ]]; then
        echo ""
        echo "  Corrections appliquées :"
        for f in "${REPORT_FIXES[@]}"; do
            echo "    🔧 ${f}"
        done
    fi

    echo ""
    if [[ $TOTAL_ERRORS -eq 0 && $TOTAL_WARNINGS -eq 0 ]]; then
        echo "  ✅ Tous les MULTIPASS sont conformes."
    elif [[ $TOTAL_ERRORS -gt 0 && "$FIX" != "true" ]]; then
        echo "  ℹ️  Relancez avec --fix pour tenter les corrections automatiques."
        echo "      ${MY_PATH}/kin.verify.sh --fix"
    fi
    echo "══════════════════════════════════════════════════════════"
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
echo "══════════════════════════════════════════════════════════"
echo "🔍  kin.verify.sh — Audit DID + Kin Maya MULTIPASS"
echo "    Station  : ${IPFSNODEID:0:16}…"
echo "    Mode     : $( [[ "$FIX" == "true" ]] && echo 'AUDIT + FIX' || echo 'AUDIT seul (--fix pour corriger)' )"
echo "    Swarm    : $( [[ "$SWARM" == "true" ]] && echo 'oui (relay kind 30800)' || echo 'non (--swarm pour activer)' )"
echo "    Match    : $( [[ "$MATCH" == "true" ]] && echo 'oui (correspondances oracle + mailjet)' || echo 'non (--match pour activer)' )"
[[ -n "$TARGET_EMAIL" ]] && echo "    Cible    : ${TARGET_EMAIL}"
echo "══════════════════════════════════════════════════════════"

NOSTR_DIR="${HOME}/.zen/game/nostr"

# Collecter la liste des emails locaux dans un tableau (évite la redirection stdin)
declare -a EMAIL_LIST=()
if [[ -n "$TARGET_EMAIL" ]]; then
    EMAIL_LIST=("$TARGET_EMAIL")
else
    if [[ ! -d "$NOSTR_DIR" ]]; then
        echo "❌ Répertoire NOSTR absent : ${NOSTR_DIR}" >&2
        exit 1
    fi
    while IFS= read -r -d '' email_dir; do
        local_email=$(basename "$email_dir")
        [[ "$local_email" != *@* ]] && continue
        EMAIL_LIST+=("$local_email")
    done < <(find "${NOSTR_DIR}" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)
fi

# Boucle sans redirection stdin — les read /dev/tty fonctionnent
_ABORT=false
for _email in "${EMAIL_LIST[@]}"; do
    verify_multipass "$_email"
    # Pause entre profils (sauf le dernier)
    if [[ "$_email" != "${EMAIL_LIST[-1]}" || "$SWARM" == "true" || "$FIX" == "true" ]]; then
        _pause || { _ABORT=true; break; }
    fi
done

[[ "$_ABORT" != "true" ]] && audit_swarm

[[ "$MATCH" == "true" && "$_ABORT" != "true" ]] && match_mode

print_report

# Code de sortie : 0 si pas d'erreurs, 1 sinon
[[ $TOTAL_ERRORS -eq 0 ]]
