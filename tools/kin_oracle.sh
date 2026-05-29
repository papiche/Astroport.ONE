#!/usr/bin/env bash
# tools/kin_oracle.sh — Bibliothèque Oracle Dreamspell / Kin Maya
# Sourcé par : admin/system/kin.verify.sh  RUNTIME/KIN.news.sh
# Ne pas exécuter directement.
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "Ce fichier est une bibliothèque : source $0" >&2; exit 1; }

# ─── GPS chiffrement (partagé avec did_manager_nostr.sh) ──────────────────────
_KOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${_KOR_DIR}/gps_crypt.sh" ]] && source "${_KOR_DIR}/gps_crypt.sh"

# ─── Maps communes (peuplées par le scan relay de chaque script appelant) ─────
declare -A email_gps=()     # email → "LAT=x; LON=y;"
declare -A email_nostrns=() # email → URL profil IPNS (#ipns-storage serviceEndpoint)

# ─── Tables Dreamspell ────────────────────────────────────────────────────────
declare -a _DS_SEALS=(Imix Ik Akbal Kan Chicchan Cimi Manik Lamat Muluc Oc
                      Chuen Eb Ben Ix Men Cib Caban Etznab Cauac Ahau)
declare -a _DS_COLORS=(Rouge Blanc Bleu Jaune Vert)
declare -a _DS_TONES=(Magnétique Lunaire Électrique "Auto-existante" Harmonique
                      Rythmique Résonnante Galactique Solaire Planétaire
                      Spectrale Cristal Cosmique)
declare -A _DS_COLOR_HEX=([Rouge]="#dc2626" [Blanc]="#6b7280" [Bleu]="#2563eb" [Jaune]="#d97706" [Vert]="#16a34a")
declare -A _DS_COLOR_BG=( [Rouge]="#fef2f2" [Blanc]="#f9fafb" [Bleu]="#eff6ff" [Jaune]="#fffbeb" [Vert]="#f0fdf4")
declare -A _DS_COLOR_EMO=([Rouge]="🔴" [Blanc]="⬜" [Bleu]="🔵" [Jaune]="🟡" [Vert]="🟢")
declare -a _DS_SEAL_EMO=(🐊 💨 🌙 🌱 🐍 ☠️ 🤚 ⭐ 🌊 🐕 🐒 🧑 🌿 🔮 🦅 🛡️ 🌍 ⚡ ⛈️ ☀️)

# ─── Arithmétique Kin ─────────────────────────────────────────────────────────
_kin_seal()  { echo $(( ($1-1) % 20 )); }
_kin_tone()  { echo $(( ($1-1) % 13 + 1 )); }
_kin_color() { echo $(( ($1-1) / 13 % 5 )); }

# Kin analogue : même tonalité, sceau décalé de ±10
# Formule CRT : inv(13,20)=17  inv(20,13)=2
_kin_analog() {
    local k=$1
    local s=$(( (k-1) % 20 ))
    local tm1=$(( (k-1) % 13 ))
    local s_ana=$(( (s + 10) % 20 ))
    local raw=$(( (s_ana * 221 + tm1 * 40) % 260 ))
    echo $(( raw + 1 ))
}

_kin_label() {
    local s t c
    s=$(_kin_seal "$1"); t=$(_kin_tone "$1"); c=$(_kin_color "$1")
    echo "Kin${1}(${_DS_COLORS[$c]} ${_DS_SEALS[$s]} T${t})"
}

# ─── HTML ─────────────────────────────────────────────────────────────────────

# Carte HTML colorée pour un Kin (une div par email).
# Lit email_nostrns[] si disponible pour ajouter un lien profil IPNS.
_kin_member_card() {
    local k=$1; shift
    local s t c
    s=$(_kin_seal "$k"); t=$(_kin_tone "$k"); c=$(_kin_color "$k")
    local color="${_DS_COLORS[$c]}" seal="${_DS_SEALS[$s]}" tone="${_DS_TONES[$((t-1))]}"
    local hex="${_DS_COLOR_HEX[$color]:-#6366f1}"
    local bg="${_DS_COLOR_BG[$color]:-#f5f3ff}"
    local emo="${_DS_COLOR_EMO[$color]:-🌀}"
    local seal_emo="${_DS_SEAL_EMO[$s]:-✦}"
    for _email in "$@"; do
        [[ -z "$_email" ]] && continue
        local _profile_url="${email_nostrns[$_email]:-}"
        printf '<div class="member" style="border-left-color:%s;background:%s">' "$hex" "$bg"
        printf '<div class="member-icon">%s</div>' "$seal_emo"
        printf '<div class="member-info">'
        printf '<div class="member-kin" style="color:%s">KIN %s</div>' "$hex" "$k"
        printf '<div class="member-name">%s %s %s</div>' "$emo" "$color" "$seal"
        printf '<div class="member-tone">Tonalité %s · T%s</div>' "$tone" "$t"
        printf '<div class="member-email">%s</div>' "$_email"
        if [[ -n "$_profile_url" ]]; then
            printf '<div class="member-link"><a href="%s" style="color:%s;font-size:.82rem;text-decoration:none">🌐 Profil UPlanet →</a></div>' \
                "$_profile_url" "$hex"
        fi
        printf '</div></div>\n'
    done
}

# Bloc "Se rencontrer" : salle visio déterministe + lien calendrier + mention WoTx2.
# Usage : _kin_meeting_block <kin1|"tone-N"> [kin2 ...]
_kin_meeting_block() {
    local _room_suffix
    if [[ "$1" == tone-* ]]; then
        _room_suffix="${1}"
    else
        _room_suffix=$(echo "$*" | tr ' ' '\n' | sort -n | tr '\n' '-' | sed 's/-$//')
    fi
    local _vdo_url="https://vdo.copylaradio.com/?room=kin-oracle-${_room_suffix}"
    local _cal_url="${myLIBRA}/ipns/copylaradio.com/calendars.html"
    printf '<div style="margin-top:1.2rem;padding:1rem 1.2rem;background:linear-gradient(135deg,#f5f3ff,#ede9fe);border-radius:10px;border:1px solid #c4b5fd;text-align:center">'
    printf '<div style="font-size:.78rem;color:#5b21b6;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:.7rem">🎥 Se rencontrer</div>'
    printf '<div style="display:flex;gap:.5rem;justify-content:center;flex-wrap:wrap;margin-bottom:.6rem">'
    printf '<a href="%s" style="display:inline-block;background:#7c3aed;color:#fff;padding:.4rem 1rem;border-radius:6px;text-decoration:none;font-size:.82rem;font-weight:600">🎥 Salle de visio</a>' \
        "$_vdo_url"
    printf '<a href="%s" style="display:inline-block;background:#4f46e5;color:#fff;padding:.4rem 1rem;border-radius:6px;text-decoration:none;font-size:.82rem;font-weight:600">📅 Prendre RDV</a>' \
        "$_cal_url"
    printf '</div>'
    printf '<div style="font-size:.72rem;color:#7c3aed;line-height:1.5">Votre rencontre peut générer des ressources de formation<br>et alimenter vos certifications <strong>WoTx2 MineLife</strong> 🌱</div>'
    printf '</div>\n'
}

# ─── GPS / proximité ──────────────────────────────────────────────────────────

# Distance Haversine en km entre deux points GPS.
_haversine_km() {
    awk -v lat1="$1" -v lon1="$2" -v lat2="$3" -v lon2="$4" 'BEGIN {
        pi = 3.14159265358979323846
        dlat = (lat2 - lat1) * pi / 180
        dlon = (lon2 - lon1) * pi / 180
        a = sin(dlat/2)^2 + cos(lat1*pi/180) * cos(lat2*pi/180) * sin(dlon/2)^2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        print 6371 * c
    }'
}

# Retourne 0 si l'email est dans le rayon GPS (ou si aucun filtre actif).
# Variables attendues par le script appelant : GPS_LAT GPS_LON GPS_RADIUS email_gps[]
_email_in_radius() {
    local _em="$1"
    [[ -z "${GPS_LAT:-}" ]] && return 0
    local _gps="${email_gps[$_em]:-}"
    if [[ -z "$_gps" ]]; then
        local _gps_file="${HOME}/.zen/game/nostr/${_em}/GPS"
        [[ -f "$_gps_file" ]] && _gps=$(cat "$_gps_file")
    fi
    [[ -z "$_gps" ]] && return 1
    local _lat _lon
    _lat=$(echo "$_gps" | grep -oP '(?<=LAT=)[^;]+' | tr -d ' ')
    _lon=$(echo "$_gps" | grep -oP '(?<=LON=)[^;]+' | tr -d ' ')
    [[ -z "$_lat" || -z "$_lon" ]] && return 1
    local _dist; _dist=$(_haversine_km "$GPS_LAT" "$GPS_LON" "$_lat" "$_lon")
    awk -v d="$_dist" -v r="$GPS_RADIUS" 'BEGIN { exit (d <= r) ? 0 : 1 }'
}
