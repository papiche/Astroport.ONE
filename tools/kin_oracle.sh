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

# ─── Alchimie des Éléments (ci 0-4 → élément, couleur, archétype 5×5) ───────
declare -a _DS_ELEMENTS=('🔥 Feu' '🌬️ Air' '🌊 Eau' '🪨 Terre' '✨ Éther')
declare -A _DS_ELEMENT_HEX=([feu]='#ef4444' [air]='#94a3b8' [eau]='#3b82f6' [terre]='#eab308' [ether]='#10b981')
declare -A _DS_ELEMENT_KEYS=([0]='feu' [1]='air' [2]='eau' [3]='terre' [4]='ether')
# Matrice 5×5 : ligne=ciConception, colonne=ciBirth (index = ciC*5 + ciB)
declare -a _DS_ARCHETYPES=(
    'La Supernova'             'La Tempête Ignée'       'Le Geyser Quantique'    'Le Forgeron des Mondes'   'La Flamme Éternelle'
    'La Comète Libre'          'Le Tourbillon Mental'   'Le Cyclone Émotionnel'  "L'Architecte Céleste"     'Le Murmure Stellaire'
    "L'Évaporation Créatrice"  'La Vague de Conscience' "L'Océan Primordial"     "L'Oasis Vivante"          'La Source Infinie'
    'Le Volcan Endormi'        'Le Désert Chantant'     'La Vallée Fertile'      'Le Cristal Ancré'         'La Montagne Sacrée'
    "L'Aurore Boréale"         'Le Tisserand Cosmique'  'La Pluie de Lumière'    'Le Jardin des Possibles'  'La Singularité Pure'
)

# ci (0-4) depuis un numéro KIN
_kin_element_idx()  { echo $(( ($1-1)/13 % 5 )); }
_kin_element_name() { echo "${_DS_ELEMENTS[$(_kin_element_idx "$1")]}"; }
_kin_element_hex()  {
    local _k="${_DS_ELEMENT_KEYS[$(_kin_element_idx "$1")]}"; echo "${_DS_ELEMENT_HEX[$_k]:-#6366f1}"
}

# Badge HTML alchimique : naissance seul, ou duo conception→naissance avec archétype.
_kin_alch_badge() {
    local k_birth="$1" k_conc="${2:-}"
    local ci_b; ci_b=$(_kin_element_idx "$k_birth")
    local ename_b="${_DS_ELEMENTS[$ci_b]}"
    local ekey_b="${_DS_ELEMENT_KEYS[$ci_b]}"
    local ehex_b="${_DS_ELEMENT_HEX[$ekey_b]:-#6366f1}"
    if [[ -z "$k_conc" || "$k_conc" == "0" ]]; then
        printf '<span style="font-size:.75rem;color:%s;background:%s22;border:1px solid %s44;border-radius:4px;padding:1px 5px">%s</span>' \
            "$ehex_b" "$ehex_b" "$ehex_b" "$ename_b"
        return
    fi
    local ci_c; ci_c=$(_kin_element_idx "$k_conc")
    local ename_c="${_DS_ELEMENTS[$ci_c]}"
    local ekey_c="${_DS_ELEMENT_KEYS[$ci_c]}"
    local ehex_c="${_DS_ELEMENT_HEX[$ekey_c]:-#6366f1}"
    local arch_idx=$(( ci_c * 5 + ci_b ))
    local archetype="${_DS_ARCHETYPES[$arch_idx]}"
    local sing_badge=""
    [[ "$ci_c" -eq "$ci_b" ]] && sing_badge=' <span style="color:#10b981;font-size:.7rem">✨ Singularité</span>'
    printf '<span style="font-size:.75rem;border-radius:4px;padding:1px 5px"><span style="color:%s">%s</span> → <span style="color:%s">%s</span>%s</span>' \
        "$ehex_c" "$ename_c" "$ehex_b" "$ename_b" "$sing_badge"
    printf '<div style="font-size:.72rem;color:#aaa;font-style:italic;margin-top:1px">%s</div>' "$archetype"
}

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
        local _kb="${email_kin30078[$_email]:-$k}"
        local _kc="${email_kin_conception[$_email]:-}"
        printf '<div style="margin-top:.3rem">'
        _kin_alch_badge "$_kb" "$_kc"
        printf '</div>'
        printf '</div></div>\n'
    done
}

# Bloc "Se rencontrer" : salle visio déterministe + lien calendrier + mention WoTx2.
# Usage : _kin_meeting_block <kin1|"tone-N"> [kin2 ...]
_kin_meeting_block() {
    local _room_suffix
    if [[ "$1" == tone-* ]]; then
        _room_suffix="${1//-/_}"
    else
        _room_suffix=$(echo "$*" | tr ' ' '\n' | sort -n | tr '\n' '_' | sed 's/_$//')
    fi
    local _vdo_url="https://vdo.copylaradio.com/?room=kin_oracle_${_room_suffix}"
    local _cal_url="${myLIBRA}/ipns/copylaradio.com/calendars.html"

    # Prochain Kin synchrone : jour où le Kin du jour coïncide avec l'un des membres
    local _tkin; _tkin=$(_today_kin)
    local _best_days=260
    for _mk in "$@"; do
        [[ "$_mk" == tone-* || ! "$_mk" =~ ^[0-9]+$ ]] && continue
        local _diff=$(( (_mk - _tkin + 260) % 260 ))
        (( _diff < _best_days )) && _best_days=$_diff
    done
    local _sync_label
    if [[ $_best_days -eq 0 ]]; then
        _sync_label="Aujourd'hui — Kin synchrone actif !"
    else
        local _sdate
        _sdate=$(LC_ALL=fr_FR.UTF-8 date -d "+${_best_days} days" '+%-d %B %Y' 2>/dev/null \
               || date -d "+${_best_days} days" '+%Y-%m-%d')
        _sync_label="${_sdate} — dans ${_best_days} jour$([[ $_best_days -gt 1 ]] && echo s)"
    fi

    printf '<div style="margin-top:1.2rem;padding:1rem 1.2rem;background:linear-gradient(135deg,#f5f3ff,#ede9fe);border-radius:10px;border:1px solid #c4b5fd">'
    printf '<div style="font-size:.8rem;color:#5b21b6;font-weight:700;margin-bottom:.4rem">🗓 Moment idéal pour se retrouver</div>'
    printf '<div style="font-size:.85rem;color:#4c1d95;margin-bottom:.7rem;font-weight:600">%s</div>' "$_sync_label"
    printf $'<div style="font-size:.78rem;color:#6b7280;margin-bottom:.6rem;line-height:1.5">Ce jour-là, le Kin du calendrier Tzolkin coïncide avec celui d\'un membre de votre groupe — selon ATOM4LOVE, la synchronisation sera maximale.</div>'
    printf '<div style="display:flex;gap:.5rem;flex-wrap:wrap">'
    printf '<a href="%s" style="display:inline-block;background:#7c3aed;color:#fff;padding:.4rem 1rem;border-radius:6px;text-decoration:none;font-size:.82rem;font-weight:600">🎥 Visio maintenant</a>' \
        "$_vdo_url"
    printf '<a href="%s" style="display:inline-block;background:#4f46e5;color:#fff;padding:.4rem 1rem;border-radius:6px;text-decoration:none;font-size:.82rem;font-weight:600">📅 Planifier</a>' \
        "$_cal_url"
    printf '</div>'
    printf '</div>\n'
}

# ─── CRT : sceau + tonalité → Kin (Chinese Remainder Theorem) ───────────────
# s0=0-19 (sceau), t0=0-12 (tonalité) → Kin 1-260
# Vérifié : _seal_tone_to_kin 0 0 = 1 (Imix Magnétique), _seal_tone_to_kin 10 12 = 91
_seal_tone_to_kin() {
    local s0=$1 t0=$2
    local n=$(( (( (t0 - s0 % 13) * 2 ) % 13 + 13) % 13 ))
    echo $(( s0 + 20 * n + 1 ))
}

# ─── Guide (5ème pouvoir — mentor de la famille-couleur) ─────────────────────
# Même famille-couleur (seal % 4), position = (T-1)%5 dans la famille
# T1,T6,T11 → guide=soi | T2,T7,T12 → pos1 | T3,T8,T13 → pos2 | T4,T9 → pos3 | T5,T10 → pos4
_kin_guide() {
    local k=$1
    local s0=$(( (k-1) % 20 ))
    local t0=$(( (k-1) % 13 ))
    local T=$(( t0 + 1 ))
    local guide_pos=$(( (T-1) % 5 ))
    local fam=$(( s0 % 4 ))
    local guide_s=$(( fam + guide_pos * 4 ))
    _seal_tone_to_kin "$guide_s" "$t0"
}

# ─── Antipode (4ème pouvoir — défi créateur) ─────────────────────────────────
# Sceau +10 mod 20, tonalité miroir 14-T
_kin_antipode() {
    local k=$1
    local s0=$(( (k-1) % 20 ))
    local t0=$(( (k-1) % 13 ))
    local anti_s=$(( (s0 + 10) % 20 ))
    local anti_t0=$(( 12 - t0 ))
    _seal_tone_to_kin "$anti_s" "$anti_t0"
}

# ─── Vague-sort / Wavespell (cycle de 13 Kins) ───────────────────────────────
# Retourne "num_vague:position:kin_graine"
_kin_wavespell() {
    local k=$1
    local ws=$(( (k-1) / 13 + 1 ))
    local pos=$(( (k-1) % 13 + 1 ))
    local seed=$(( (ws-1) * 13 + 1 ))
    echo "${ws}:${pos}:${seed}"
}

# ─── Kin du jour (Tzolkin epoch : 26 juillet 1987 = Kin 1) ──────────────────
# Date de référence Dreamspell : 1987-07-26 = Kin 1
_today_kin() {
    local epoch_days today_days delta
    epoch_days=$(awk 'BEGIN{
        y=1987; m=7; d=26
        if(m<3){y--;m+=12}
        A=int(y/100); B=2-A+int(A/4)
        printf "%d", int(365.25*(y+4716))+int(30.6001*(m+1))+d+B-1524
    }')
    today_days=$(awk 'BEGIN{
        cmd="date -u +%Y-%m-%d"; cmd | getline dt; close(cmd)
        split(dt,a,"-"); y=a[1]+0; m=a[2]+0; d=a[3]+0
        if(m<3){y--;m+=12}
        A=int(y/100); B=2-A+int(A/4)
        printf "%d", int(365.25*(y+4716))+int(30.6001*(m+1))+d+B-1524
    }')
    local delta=$(( today_days - epoch_days ))
    echo $(( (delta % 260 + 260) % 260 + 1 ))
}

# ─── Résonance phi : k = 1/(1+|sin(Δφ)|) — formule ATOM4LOVE ────────────────
# 0.5 = minimum  |  1.0 = singularité optique (résonnance parfaite)
_phi_resonance_k() {
    awk -v pa="$1" -v pb="$2" 'BEGIN {
        d = pa - pb; if (d < 0) d = -d
        s = sin(d); if (s < 0) s = -s
        printf "%.4f\n", 1.0 / (1.0 + s)
    }'
}

# ─── Tableaux globaux enrichis A4L ──────────────────────────────────────────
declare -A email_phi=()      # email → personal_phase φ_i
declare -A email_omega=()    # email → omega_bio ω
declare -A email_sex=()      # email → biological_sex (0=Φ 1=Octave)
declare -A email_kin30078=() # email → kin_num depuis Kind 30078
declare -A email_inst=()     # email → inst_id (0=synth 1=voix)
declare -A pubkey_email=()   # hex pubkey → email (rempli par scan DID)
declare -A email_hexagons=() # email → "a4l:P02H... a4l:P02 …" (Spacememory)
declare -A email_k_sum=()    # email → somme des k Atom4Peace reçus
declare -A email_k_count=()  # email → nombre de résonances live
declare -A email_resonance_graph=() # email → "email1:k1 email2:k2 …" (graphe pairs)
declare -A email_kin_conception=()  # email → kin_conception depuis Kind 30078
declare -A email_archetype=()       # email → archétype alchimique (texte)

# ─── Scan DID (kind 30800) : peupler pubkey_email[], email_phi[], email_nostrns[] ──
_scan_did_mapping() {
    local strfry_dir="${HOME}/.zen/strfry"
    local strfry_bin="${strfry_dir}/strfry"
    [[ ! -x "$strfry_bin" ]] && return 1
    local count=0
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local pubkey content _email _ipns
        pubkey=$(echo "$evt" | jq -r '.pubkey // empty' 2>/dev/null)
        content=$(echo "$evt" | jq -r '.content // empty' 2>/dev/null)
        [[ -z "$pubkey" || -z "$content" ]] && continue
        _email=$(echo "$content" | jq -r '
            .metadata.email //
            (.alsoKnownAs // [] | map(select(startswith("mailto:"))) | first // "")
        ' 2>/dev/null | sed 's/^mailto://')
        [[ -z "$_email" || "$_email" == "null" ]] && continue
        pubkey_email["$pubkey"]="$_email"
        _ipns=$(echo "$content" | jq -r '
            .service // [] | map(select(.id | endswith("#ipns-storage"))) | first.serviceEndpoint // ""
        ' 2>/dev/null)
        [[ -n "$_ipns" ]] && email_nostrns["$_email"]="$_ipns"
        ((count++))
    done < <(cd "$strfry_dir" && ./strfry scan '{"kinds":[30800]}' 2>/dev/null)
    echo "$count"
}

# ─── Scan Kind 30078 (certificat A4L) : extraire φ_i et ω_bio ───────────────
_scan_a4l_phi() {
    # Scan Kind 30078 d=atom4love — extrait tous les champs ATOM4LOVE
    # Champs v1 : personal_phase, omega_bio
    # Champs v2 : + biological_sex, kin_num, inst_id (app v2+)
    local strfry_dir="${HOME}/.zen/strfry"
    [[ ! -x "${strfry_dir}/strfry" ]] && echo 0 && return 1
    local count=0
    local PHI2X="${MY_PATH}/phi2x.py"
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local pubkey content phi omega sex kin_n inst proof kin_conc arch_val
        pubkey=$(echo "$evt" | jq -r '.pubkey // empty' 2>/dev/null)
        content=$(echo "$evt" | jq -r '.content // empty' 2>/dev/null)
        [[ -z "$pubkey" ]] && continue
        phi=$(echo "$content"      | jq -r '.personal_phase    // empty' 2>/dev/null)
        omega=$(echo "$content"    | jq -r '.omega_bio         // empty' 2>/dev/null)
        sex=$(echo "$content"      | jq -r '.biological_sex    // empty' 2>/dev/null)
        kin_n=$(echo "$content"    | jq -r '.kin_num           // empty' 2>/dev/null)
        inst=$(echo "$content"     | jq -r '.inst_id           // "0"'   2>/dev/null)
        kin_conc=$(echo "$content" | jq -r '.kin_conception    // empty' 2>/dev/null)
        arch_val=$(echo "$content" | jq -r '.archetype         // empty' 2>/dev/null)
        [[ -z "$phi" ]] && continue
        # Vérification a4l_proof (optionnelle, utilise phi2x.py si disponible)
        if [[ -x "$PHI2X" ]]; then
            proof=$(echo "$evt" | jq -r '.tags//[]|map(select(.[0]=="a4l_proof"))|first[1]//"" ' 2>/dev/null)
            if [[ -n "$proof" ]]; then
                _valid=$(python3 -c "
import hashlib, sys
pubkey='$pubkey'; proof='$proof'; salt='ATOM4LOVE_v1'
expected=hashlib.sha256((pubkey+':'+salt).encode()).hexdigest()
print('ok' if expected==proof else 'fail')
" 2>/dev/null)
                [[ "$_valid" != "ok" ]] && continue  # Ignorer les certifs invalides
            fi
        fi
        local _email="${pubkey_email[$pubkey]:-}"
        [[ -z "$_email" ]] && continue
        email_phi["$_email"]="$phi"
        [[ -n "$omega"    ]] && email_omega["$_email"]="$omega"
        [[ -n "$sex"      ]] && email_sex["$_email"]="$sex"
        [[ -n "$kin_n"    ]] && email_kin30078["$_email"]="$kin_n"
        email_inst["$_email"]="${inst:-0}"
        [[ -n "$kin_conc" ]] && email_kin_conception["$_email"]="$kin_conc"
        [[ -n "$arch_val" ]] && email_archetype["$_email"]="$arch_val"
        ((count++))
    done < <(cd "$strfry_dir" && ./strfry scan '{"kinds":[30078],"#d":["atom4love"]}' 2>/dev/null)
    echo "$count"
}

# ─── Scan Kind 1 Spacememory : hexagones fréquentés ─────────────────────────
_scan_spacememory_hexagons() {
    local strfry_dir="${HOME}/.zen/strfry"
    [[ ! -x "${strfry_dir}/strfry" ]] && echo 0 && return 1
    local count=0
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local pubkey hex_tags
        pubkey=$(echo "$evt" | jq -r '.pubkey // empty' 2>/dev/null)
        [[ -z "$pubkey" ]] && continue
        local _email="${pubkey_email[$pubkey]:-}"
        [[ -z "$_email" ]] && continue
        hex_tags=$(echo "$evt" | jq -r '
            .tags // [] | map(select(.[0]=="l" and (.[1]//""|startswith("a4l:")))) | .[].1
        ' 2>/dev/null | tr '\n' ' ')
        [[ -z "$hex_tags" ]] && continue
        email_hexagons["$_email"]+=" $hex_tags"
        ((count++))
    done < <(cd "$strfry_dir" && ./strfry scan '{"kinds":[1],"#t":["atom4love"]}' 2>/dev/null)
    echo "$count"
}

# ─── Scan Kind 7 ATOM4LOVE : résonances — tag "#t"="a4l-resonance" ───────────
# content "+k" avec k ∈ [0.5, 1.0] — jamais ambigu avec paiements ẐEN (+N, N>1)
# Tag distinctif ["t","a4l-resonance"] ajouté depuis app v2 pour éviter toute
# confusion avec les Kind 7 de paiement ẐEN (["t","atom4love"] seul).
_scan_atom4peace_resonances() {
    local strfry_dir="${HOME}/.zen/strfry"
    [[ ! -x "${strfry_dir}/strfry" ]] && echo 0 && return 1
    local count=0
    while IFS= read -r evt; do
        [[ -z "$evt" ]] && continue
        local pubkey content k_val target_pubkey
        pubkey=$(echo "$evt"        | jq -r '.pubkey // empty' 2>/dev/null)
        content=$(echo "$evt"       | jq -r '.content // empty' 2>/dev/null)
        target_pubkey=$(echo "$evt" | jq -r '.tags//[]|map(select(.[0]=="p"))|first[1]//"" ' 2>/dev/null)
        [[ -z "$pubkey" ]] && continue
        # Filtre : k ∈ [0.5, 1.0] (distingue des paiements ẐEN > 1)
        k_val=$(echo "$content" | grep -oP '[0-9]+\.[0-9]+' | head -1)
        [[ -z "$k_val" ]] && continue
        _kf=$(awk -v k="$k_val" 'BEGIN{print (k>=0.45 && k<=1.0) ? "ok" : "skip"}')
        [[ "$_kf" != "ok" ]] && continue
        local _email="${pubkey_email[$pubkey]:-}"
        [[ -z "$_email" ]] && continue
        # Accumuler (somme + count pour moyenne k)
        email_k_sum["$_email"]=$(awk -v a="${email_k_sum[$_email]:-0}" -v b="$k_val" \
            'BEGIN{printf "%.4f",a+b}')
        email_k_count["$_email"]=$(( ${email_k_count[$_email]:-0} + 1 ))
        # Graphe de résonance : email_source → "email_cible:k ..."
        if [[ -n "$target_pubkey" ]]; then
            local _target_email="${pubkey_email[$target_pubkey]:-}"
            if [[ -n "$_target_email" ]]; then
                email_resonance_graph["$_email"]+="${_target_email}:${k_val} "
                # Symétrique (k est réciproque)
                email_resonance_graph["$_target_email"]+="${_email}:${k_val} "
            fi
        fi
        ((count++))
    done < <(cd "$strfry_dir" && ./strfry scan \
        '{"kinds":[7],"#t":["a4l-resonance"]}' 2>/dev/null)
    # Note : 7.sh (NIP-101 relay) traite les Kind 7 content "+N" (N entier) comme
    # paiements ẐEN. Nos résonances "+k" (k décimal < 1.0) ne déclenchent jamais
    # un paiement — la distinction est naturelle et ne nécessite pas de filtrage relay.
    echo "$count"
}

# ─── Hexagones partagés entre deux membres ───────────────────────────────────
_hexagon_shared_count() {
    local ea="$1" eb="$2"
    local ha="${email_hexagons[$ea]:-}" hb="${email_hexagons[$eb]:-}"
    [[ -z "$ha" || -z "$hb" ]] && echo 0 && return
    local shared=0
    for hex in $ha; do
        [[ "$hb" == *"$hex"* ]] && ((shared++))
    done
    echo "$shared"
}

# ─── Carte membre enrichie (phi, omega, hexagones, score) ───────────────────
_kin_member_card_rich() {
    local k="$1" phi="${2:-}" omega="${3:-}"; shift 3
    local s t c
    s=$(_kin_seal "$k"); t=$(_kin_tone "$k"); c=$(_kin_color "$k")
    local color="${_DS_COLORS[$c]}" seal="${_DS_SEALS[$s]}" tone="${_DS_TONES[$((t-1))]}"
    local hex="${_DS_COLOR_HEX[$color]:-#6366f1}"
    local bg="${_DS_COLOR_BG[$color]:-#f5f3ff}"
    local emo="${_DS_COLOR_EMO[$color]:-🌀}"
    local seal_emo="${_DS_SEAL_EMO[$s]:-✦}"
    for _email in "$@"; do
        [[ -z "$_email" ]] && continue
        local _phi="${email_phi[$_email]:-$phi}"
        local _omega="${email_omega[$_email]:-$omega}"
        local _ksum="${email_k_sum[$_email]:-}"
        local _kcnt="${email_k_count[$_email]:-0}"
        local _avg_k=""
        [[ -n "$_ksum" && "$_kcnt" -gt 0 ]] && \
            _avg_k=$(awk -v s="$_ksum" -v n="$_kcnt" 'BEGIN{printf "%.3f",s/n}')
        local _hexcnt=$(echo "${email_hexagons[$_email]:-}" | wc -w)
        local _profile_url="${email_nostrns[$_email]:-}"
        printf '<div class="member" style="border-left:4px solid %s;background:%s;border-radius:10px;padding:.8rem 1rem;margin:.4rem 0">' "$hex" "$bg"
        printf '<div style="display:flex;align-items:center;gap:.8rem">'
        printf '<div style="font-size:1.8rem">%s</div>' "$seal_emo"
        printf '<div style="flex:1">'
        printf '<div style="font-weight:700;color:%s">KIN %s — %s %s</div>' "$hex" "$k" "$emo" "$seal"
        printf '<div style="font-size:.85rem;color:#555">T%s %s</div>' "$t" "$tone"
        printf '<div style="font-size:.82rem;color:#444;margin-top:.2rem">%s</div>' "$_email"
        if [[ -n "$_phi" ]]; then
            printf '<div style="font-size:.78rem;color:%s;margin-top:.2rem">⚛ φ_i = %s  |  ω = %s Hz</div>' "$hex" "$_phi" "$_omega"
        fi
        if [[ "$_kcnt" -gt 0 ]]; then
            printf '<div style="font-size:.75rem;color:#7c3aed">🎯 k moyen = %s (%s résonances live)</div>' "$_avg_k" "$_kcnt"
        fi
        if [[ "$_hexcnt" -gt 0 ]]; then
            printf '<div style="font-size:.75rem;color:#059669">⬡ %s nœuds hexagonaux explorés</div>' "$_hexcnt"
        fi
        local _kb="${email_kin30078[$_email]:-$k}"
        local _kc="${email_kin_conception[$_email]:-}"
        local _arch="${email_archetype[$_email]:-}"
        if [[ -n "$_kb" ]]; then
            local _ci_b; _ci_b=$(_kin_element_idx "$_kb")
            local _en_b="${_DS_ELEMENTS[$_ci_b]}"
            local _ek_b="${_DS_ELEMENT_KEYS[$_ci_b]}"
            local _eh_b="${_DS_ELEMENT_HEX[$_ek_b]:-#6366f1}"
            if [[ -n "$_kc" ]]; then
                local _ci_c; _ci_c=$(_kin_element_idx "$_kc")
                local _en_c="${_DS_ELEMENTS[$_ci_c]}"
                local _ek_c="${_DS_ELEMENT_KEYS[$_ci_c]}"
                local _eh_c="${_DS_ELEMENT_HEX[$_ek_c]:-#6366f1}"
                local _arch_idx=$(( _ci_c * 5 + _ci_b ))
                local _displayed_arch="${_arch:-${_DS_ARCHETYPES[$_arch_idx]}}"
                printf '<div style="font-size:.78rem;margin-top:.4rem;padding:.3rem .5rem;background:#ffffff22;border-radius:6px;border:1px solid #ffffff11">'
                printf '🧬 <span style="color:%s">%s</span> → <span style="color:%s">%s</span>' \
                    "$_eh_c" "$_en_c" "$_eh_b" "$_en_b"
                [[ "$_ci_c" -eq "$_ci_b" ]] && printf ' <span style="color:#10b981">✨</span>'
                printf '<br><span style="font-size:.72rem;color:#aaa;font-style:italic">%s</span>' "$_displayed_arch"
                printf '</div>'
            else
                printf '<div style="font-size:.78rem;margin-top:.3rem">🧬 <span style="color:%s">%s</span></div>' \
                    "$_eh_b" "$_en_b"
            fi
        fi
        if [[ -n "$_profile_url" ]]; then
            printf '<div style="margin-top:.3rem"><a href="%s" style="color:%s;font-size:.8rem">🌐 Profil UPlanet →</a></div>' "$_profile_url" "$hex"
        fi
        printf '</div></div></div>\n'
    done
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
