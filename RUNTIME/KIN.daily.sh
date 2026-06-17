#!/bin/bash
################################################################################
# RUNTIME/KIN.daily.sh — Newsletter Oracle Kin Maya QUOTIDIENNE
#
# Génère un email HTML personnalisé par membre :
#   - Kin du jour + Vague-sort + progression
#   - Anniversaire Kin (template kin_birthday.html)
#   - 5 Pouvoirs Oracle complets (Guide, Antipode, Analogue, Occulte, Soi)
#   - Résonances phi (données Kind 30078 ATOM4LOVE)
#   - Nœuds hexagonaux partagés (Kind 1 Spacememory)
#   - Gamification : achievements, défis, score, stats
#
# Usage: ./KIN.daily.sh [--force] [--dry-run] [--email X]
# Déclenché depuis ZEN.ECONOMY.sh (quotidien, après KIN.news.sh hebdo)
################################################################################
MY_PATH="$(dirname "$0")"; MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/../tools/my.sh"
source "${MY_PATH}/../tools/kin_oracle.sh"
# KIN_TONE_KEYS (Action|Pouvoir|Essence pour chaque tonalité) défini dans kin.sh
source "${MY_PATH}/../tools/kin.sh"
# Préférences KIN par membre (scope, opt-out daily/weekly)
source "${MY_PATH}/../tools/kin_prefs.sh"

FORCE=false; DRY_RUN=false; TARGET_EMAIL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   FORCE=true ;;
        --dry-run) DRY_RUN=true ;;
        --email)   TARGET_EMAIL="$2"; shift ;;
        -h|--help) grep '^#' "$0" | head -20 | sed 's/^# \?//'; exit 0 ;;
    esac; shift
done

DAY_KEY="$(date -u +%Y-%m-%d)"
# Marqueur par joueur quand --email est fourni, global sinon
if [[ -n "$TARGET_EMAIL" ]]; then
    MARKER="${HOME}/.zen/game/nostr/${TARGET_EMAIL}/.kin_daily_${DAY_KEY}"
else
    MARKER="${HOME}/.zen/game/.kin_daily_${DAY_KEY}"
fi
if [[ -f "$MARKER" && "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
    echo "INFO KIN.daily: deja envoye le ${DAY_KEY} pour ${TARGET_EMAIL:-tous}. --force pour relancer." >&2; exit 0
fi

# Préférences du joueur cible : respecter son opt-out oracle quotidien
if [[ -n "$TARGET_EMAIL" && "$DRY_RUN" != "true" ]]; then
    _kin_prefs_load "$TARGET_EMAIL"
    if [[ "$_KIN_DAILY" != "true" ]]; then
        echo "INFO KIN.daily: oracle quotidien désactivé pour ${TARGET_EMAIL}." >&2
        touch "$MARKER"
        exit 0
    fi
fi

STRFRY_DIR="${HOME}/.zen/strfry"
MJ="${MY_PATH}/../tools/mailjet.sh"
TMPL="${MY_PATH}/../templates/KIN/kin_daily.html"
TMPL_BD="${MY_PATH}/../templates/KIN/kin_birthday.html"
[[ ! -x "${STRFRY_DIR}/strfry" ]] && echo "ERROR: strfry absent" >&2 && exit 1
[[ ! -f "$TMPL" ]] && echo "ERROR: template kin_daily.html absent" >&2 && exit 1

echo "========================================================================"
echo "☀️  KIN.daily.sh — ${DAY_KEY}"
echo "========================================================================"

# ─── Collecte des données A4L (kind 30800, 30078, 1, 7) ──────────────────────
echo "  📡 Scan DID + A4L + Spacememory + Atom4Peace..."
_scan_did_mapping      2>/dev/null; echo "    → DID mappes : ${#pubkey_email[@]}"
_scan_a4l_phi          2>/dev/null; echo "    → phi_i charges : ${#email_phi[@]}"
_scan_spacememory_hexagons 2>/dev/null; echo "    → Spacememory : ${#email_hexagons[@]}"
_scan_atom4peace_resonances 2>/dev/null; echo "    → Resonances live : ${#email_k_sum[@]}"

# ─── Kin Maya depuis kind 30800 ───────────────────────────────────────────────
declare -A kin_emails=() email_kin=()
total_profiles=0
while IFS= read -r evt; do
    [[ -z "$evt" ]] && continue
    _cnt=$(echo "$evt" | jq -r '.content // empty' 2>/dev/null)
    [[ -z "$_cnt" ]] && continue
    _e=$(echo "$_cnt" | jq -r '.metadata.email // (.alsoKnownAs//[]|map(select(startswith("mailto:")))|first//"")' 2>/dev/null | sed 's/^mailto://')
    _k=$(echo "$_cnt" | jq -r '.metadata.badges//[]|map(select(.type=="MayaKin"))|first.kin//""' 2>/dev/null)
    [[ -z "$_e" || -z "$_k" || "$_k" == "null" ]] && continue
    [[ ! "$_k" =~ ^[0-9]+$ || $_k -lt 1 || $_k -gt 260 ]] && continue
    [[ "${kin_emails[$_k]:-}" == *"${_e}"* ]] && continue
    kin_emails["$_k"]+="${_e} "; email_kin["$_e"]="$_k"; ((total_profiles++))
done < <(cd "${STRFRY_DIR}" && ./strfry scan '{"kinds":[30800]}' 2>/dev/null)
printf "  📊 %d profils Kin Maya\n" "$total_profiles"
[[ $total_profiles -lt 1 ]] && echo "  ℹ️  Aucun profil — arret" && exit 0

# ─── Kin du jour ─────────────────────────────────────────────────────────────
TODAY_KIN=$(_today_kin)
TK_SI=$(( (TODAY_KIN-1)%20 )); TK_TI=$(( (TODAY_KIN-1)%13 )); TK_CI=$(( (TODAY_KIN-1)/13%5 ))
TODAY_SEAL="${_DS_SEALS[$TK_SI]}" TODAY_TONE="${_DS_TONES[$TK_TI]}" TODAY_COLOR="${_DS_COLORS[$TK_CI]}"
TODAY_EMO="${_DS_COLOR_EMO[$TODAY_COLOR]:-🌀}" TODAY_HEX="${_DS_COLOR_HEX[$TODAY_COLOR]:-#6366f1}"
IFS='|' read -r TODAY_ACTION TODAY_POWER TODAY_ESSENCE <<< "${KIN_TONE_KEYS[$TK_TI]}"
IFS=':' read -r TODAY_WS_NUM TODAY_WS_POS TODAY_WS_SEED <<< "$(_kin_wavespell "$TODAY_KIN")"
DATE_FR=$(LC_ALL=fr_FR.UTF-8 date -u '+%-d %B %Y' 2>/dev/null || date -u +%Y-%m-%d)

printf "  ☀️  Kin %d — %s %s %s  (Vague-sort %d, Jour %d/13)\n" \
    "$TODAY_KIN" "$TODAY_EMO" "$TODAY_COLOR" "$TODAY_SEAL" "$TODAY_WS_NUM" "$TODAY_WS_POS"

# ─── Sélection destinataires ──────────────────────────────────────────────────
if [[ -n "$TARGET_EMAIL" ]]; then
    RECIPIENTS=("$TARGET_EMAIL")
else
    mapfile -t RECIPIENTS < <(printf '%s\n' "${!email_kin[@]}" | sort)
fi

sent_total=0; skipped_total=0

# ─── Helper : bloc power Oracle ───────────────────────────────────────────────
_oracle_card() {
    local icon="$1" label="$2" p_kin="$3" mates="$4" my_kin="$5" my_phi="$6"
    local si=$(( (p_kin-1)%20 )) ti=$(( (p_kin-1)%13 )) ci=$(( (p_kin-1)/13%5 ))
    local seal="${_DS_SEALS[$si]}" tone="${_DS_TONES[$ti]}" color="${_DS_COLORS[$ci]}"
    local phex="${_DS_COLOR_HEX[$color]:-#6366f1}" pbg="${_DS_COLOR_BG[$color]:-#f5f3ff}"
    local pemo="${_DS_COLOR_EMO[$color]:-}"
    printf '<div class="oracle-card" style="background:%s;border-color:%s">' "$pbg" "$phex"
    printf '<strong style="color:%s">%s %s</strong> — Kin %d %s %s %s T%d %s<br>' \
        "$phex" "$icon" "$label" "$p_kin" "$pemo" "$color" "$seal" "$((ti+1))" "$tone"
    local _found=false
    for _m in $mates; do
        local _mk="${email_phi[$_m]:-}"; local _k_str=""
        if [[ -n "$my_phi" && -n "$_mk" ]]; then
            _k_str=$(printf " (φ k=%s)" "$(_phi_resonance_k "$my_phi" "$_mk")")
        fi
        printf '<span class="oracle-mate">→ %s%s</span>' "$_m" "$_k_str"
        _found=true
    done
    if [[ "$_found" == "true" ]]; then
        local vdo="${myLIBRA:-https://vdo.copylaradio.com}/?room=kin_oracle_${my_kin}_${p_kin}"
        printf '<br><a href="%s" style="display:inline-block;background:%s;color:#fff;padding:.25rem .7rem;border-radius:6px;text-decoration:none;font-size:.78rem;margin-top:.3rem">🎥 Rencontrer</a>' "$vdo" "$phex"
    else
        printf '<span style="color:#9ca3af;font-size:.8rem">Pas encore dans le reseau</span>'
    fi
    printf '</div>\n'
}

# ─── Boucle par destinataire ──────────────────────────────────────────────────
for DEST in "${RECIPIENTS[@]}"; do
    [[ -z "$DEST" ]] && continue
    MY_KIN="${email_kin[$DEST]:-}"; [[ -z "$MY_KIN" ]] && continue
    # Charger les préférences /mailjet propres à ce joueur
    _kin_prefs_load "$DEST"
    if [[ "$_KIN_DAILY" != "true" ]]; then
        echo "  ⏭ Skip ${DEST} — oracle quotidien désactivé." >&2
        continue
    fi

    MK_SI=$(( (MY_KIN-1)%20 )); MK_TI=$(( (MY_KIN-1)%13 )); MK_CI=$(( (MY_KIN-1)/13%5 ))
    MY_SEAL="${_DS_SEALS[$MK_SI]}" MY_TONE="${_DS_TONES[$MK_TI]}" MY_COLOR="${_DS_COLORS[$MK_CI]}"
    MY_HEX="${_DS_COLOR_HEX[$MY_COLOR]:-#6366f1}" MY_BG="${_DS_COLOR_BG[$MY_COLOR]:-#f5f3ff}"
    MY_COLOR_EMO="${_DS_COLOR_EMO[$MY_COLOR]:-🌀}" MY_SEAL_EMO="${_DS_SEAL_EMO[$MK_SI]:-✦}"
    IFS='|' read -r MY_ACTION MY_POWER MY_ESSENCE <<< "${KIN_TONE_KEYS[$MK_TI]}"
    IFS=':' read -r MY_WS_NUM MY_WS_POS MY_WS_SEED <<< "$(_kin_wavespell "$MY_KIN")"
    MY_PHI="${email_phi[$DEST]:-}" MY_OMEGA="${email_omega[$DEST]:-}"
    MY_KCNT="${email_k_count[$DEST]:-0}" MY_KSUM="${email_k_sum[$DEST]:-0}"
    MY_HEXCNT=$(echo "${email_hexagons[$DEST]:-}" | wc -w)
    MY_AVG_K=""; [[ "$MY_KCNT" -gt 0 ]] && \
        MY_AVG_K=$(awk -v s="$MY_KSUM" -v n="$MY_KCNT" 'BEGIN{printf "%.3f",s/n}')

    # 5 pouvoirs
    MY_GUIDE=$(_kin_guide "$MY_KIN"); MY_ANTI=$(_kin_antipode "$MY_KIN")
    MY_ANALOG=$(_kin_analog "$MY_KIN"); MY_OCCULT=$(( 261 - MY_KIN ))

    # Partenaires dans le réseau
    GUIDE_M=""; ANTI_M=""; ANALOG_M=""; OCCULT_M=""
    for _e in ${kin_emails[$MY_GUIDE]:-};  do [[ "$_e" != "$DEST" ]] && GUIDE_M+="${_e} "; done
    for _e in ${kin_emails[$MY_ANTI]:-};   do [[ "$_e" != "$DEST" ]] && ANTI_M+="${_e} "; done
    for _e in ${kin_emails[$MY_ANALOG]:-}; do [[ "$_e" != "$DEST" ]] && ANALOG_M+="${_e} "; done
    for _e in ${kin_emails[$MY_OCCULT]:-}; do [[ "$_e" != "$DEST" ]] && OCCULT_M+="${_e} "; done

    IS_BIRTHDAY=false; [[ "$MY_KIN" -eq "$TODAY_KIN" ]] && IS_BIRTHDAY=true

    # ── Gamification ─────────────────────────────────────────────────────────
    SCORE=0; ACH_HTML=""; CH_HTML=""
    [[ "$IS_BIRTHDAY" == "true" ]] && ((SCORE+=50)) && \
        ACH_HTML+='<div class="ach">✅ +50 pts — Anniversaire Kin ! Jour de naissance cosmique.</div>'
    [[ -n "$GUIDE_M" ]] && ((SCORE+=20)) && \
        ACH_HTML+="<div class=\"ach\">✅ +20 pts — Votre Guide est dans le reseau.</div>"
    [[ -n "$ANTI_M" ]] && ((SCORE+=15)) && \
        ACH_HTML+="<div class=\"ach\">✅ +15 pts — Votre Antipode est present !</div>"
    [[ "$MY_HEXCNT" -gt 10 ]] && ((SCORE+=30)) && \
        ACH_HTML+="<div class=\"ach\">✅ +30 pts — Explorateur Hexagonal (${MY_HEXCNT} noeuds)</div>"
    [[ "$MY_KCNT" -gt 5 ]] && ((SCORE+=25)) && \
        ACH_HTML+="<div class=\"ach\">✅ +25 pts — Resonateur actif (${MY_KCNT} resonances)</div>"
    [[ "$MY_WS_POS" -eq 1 ]] && ((SCORE+=10)) && \
        ACH_HTML+='<div class="ach">✅ +10 pts — Premier jour de votre Vague-sort !</div>'

    [[ "$MY_HEXCNT" -lt 5 ]] && \
        CH_HTML+='<div class="challenge">💡 Deposez une pensee dans un nouveau noeud hexagonal</div>'
    [[ -n "$GUIDE_M" ]] && \
        CH_HTML+="<div class=\"challenge\">💡 Alignez-vous avec votre Guide — meme Vague-sort</div>"
    [[ -z "$CH_HTML" ]] && \
        CH_HTML+='<div class="challenge">💡 Explorez un nouveau noeud et deposez une pensee</div>'

    GAME_SEC=""
    if [[ -n "$ACH_HTML" || -n "$CH_HTML" ]]; then
        GAME_SEC="<div class=\"section\"><div class=\"section-title\">🎮 Aujourd'hui</div>"
        GAME_SEC+="${ACH_HTML}${CH_HTML}</div>"
    fi

    # ── Oracle entries ────────────────────────────────────────────────────────
    ORACLE_HTML=""
    ORACLE_HTML+=$(_oracle_card "🧭" "Guide (mentor)"    "$MY_GUIDE"  "$GUIDE_M"  "$MY_KIN" "$MY_PHI")
    ORACLE_HTML+=$(_oracle_card "⚡" "Antipode (defi)"   "$MY_ANTI"   "$ANTI_M"   "$MY_KIN" "$MY_PHI")
    ORACLE_HTML+=$(_oracle_card "🌀" "Analogue (soutien)" "$MY_ANALOG" "$ANALOG_M" "$MY_KIN" "$MY_PHI")
    ORACLE_HTML+=$(_oracle_card "🌙" "Occulte (cache)"   "$MY_OCCULT" "$OCCULT_M" "$MY_KIN" "$MY_PHI")

    # ── Phi section ───────────────────────────────────────────────────────────
    PHI_SEC=""
    if [[ -n "$MY_PHI" ]]; then
        declare -A _ps=()
        for _oe in "${!email_kin[@]}"; do
            [[ "$_oe" == "$DEST" ]] && continue
            _op="${email_phi[$_oe]:-}"; [[ -z "$_op" ]] && continue
            _ps["$_oe"]=$(_phi_resonance_k "$MY_PHI" "$_op")
        done
        _phi_rows=""
        while IFS=' ' read -r _k _e; do
            [[ -z "$_e" ]] && continue
            _pct=$(awk -v k="$_k" 'BEGIN{printf "%d",k*100}')
            _pk="${email_kin[$_e]:-?}"
            _vdo="${myLIBRA:-https://vdo.copylaradio.com}/?room=kin_phi_${MY_KIN}_${_pk}"
            _hsc=$(_hexagon_shared_count "$DEST" "$_e")
            _hsc_txt=""; [[ "$_hsc" -gt 0 ]] && \
                _hsc_txt="<br><small style=\"color:#059669\">⬡ ${_hsc} noeuds hexagonaux partages</small>"
            _phi_rows+="<div class=\"match-card\"><strong>${_e}</strong> — Kin ${_pk}<br>"
            _phi_rows+="<div class=\"phi-bar\"><div class=\"phi-fill\" style=\"width:${_pct}%\"></div></div>"
            _phi_rows+="k = <strong>${_k}</strong> (${_pct}%)${_hsc_txt}<br>"
            _phi_rows+="<a href=\"${_vdo}\" style=\"display:inline-block;background:${MY_HEX};color:#fff;padding:.25rem .7rem;border-radius:6px;text-decoration:none;font-size:.78rem;margin-top:.3rem\">🎥 Se rencontrer</a></div>"
        done < <(for _e in "${!_ps[@]}"; do printf '%s %s\n' "${_ps[$_e]}" "$_e"; done | sort -rn | head -3)
        unset _ps
        if [[ -n "$_phi_rows" ]]; then
            PHI_SEC="<div class=\"section\"><div class=\"section-title\">⚛ Meilleures Resonances φ du Jour</div>"
            PHI_SEC+="${_phi_rows}</div>"
        fi
    fi

    # ── Hex section ───────────────────────────────────────────────────────────
    HEX_SEC=""
    if [[ -n "${email_hexagons[$DEST]:-}" ]]; then
        _hex_rows=""
        declare -A _hs=()
        for _oe in "${!email_kin[@]}"; do
            [[ "$_oe" == "$DEST" ]] && continue
            _sc=$(_hexagon_shared_count "$DEST" "$_oe"); [[ "$_sc" -gt 0 ]] && _hs["$_oe"]="$_sc"
        done
        while IFS=' ' read -r _sc _e; do
            [[ -z "$_e" ]] && continue
            _ek="${email_kin[$_e]:-?}"
            _hex_rows+="<div style=\"margin:.3rem 0;padding:.5rem .8rem;background:#f0fdf4;border-radius:8px;font-size:.84rem\">"
            _hex_rows+="${_e} — Kin ${_ek} · <strong>${_sc} noeud(s) partage(s)</strong></div>"
        done < <(for _e in "${!_hs[@]}"; do printf '%s %s\n' "${_hs[$_e]}" "$_e"; done | sort -rn | head -3)
        unset _hs
        if [[ -n "$_hex_rows" ]]; then
            HEX_SEC="<div class=\"section\"><div class=\"section-title\">⬡ Espaces Hexagonaux Partages</div>"
            HEX_SEC+="<small style=\"color:#6b7280\">Ces membres ont explore les memes noeuds Spacememory que vous.</small><br>"
            HEX_SEC+="${_hex_rows}</div>"
        fi
    fi

    # ── Stats ─────────────────────────────────────────────────────────────────
    STATS_HTML=""
    STATS_HTML+="<div class=\"stat-card\" style=\"background:#f0fdf4\"><strong>${MY_HEXCNT}</strong><small>Noeuds explores</small></div>"
    STATS_HTML+="<div class=\"stat-card\" style=\"background:#fdf4ff\"><strong>${MY_KCNT}</strong><small>Resonances live</small></div>"
    [[ -n "$MY_AVG_K" ]] && \
        STATS_HTML+="<div class=\"stat-card\" style=\"background:#eff6ff\"><strong>${MY_AVG_K}</strong><small>k moyen</small></div>"
    [[ -n "$MY_PHI" ]] && \
        STATS_HTML+="<div class=\"stat-card\" style=\"background:#fff7ed\"><strong>${MY_PHI}</strong><small>Phase φ_i</small></div>"

    # ── Vague-sort progress bar ───────────────────────────────────────────────
    WAVE_HTML=""
    for (( pd=1; pd<=13; pd++ )); do
        if (( pd < TODAY_WS_POS )); then WAVE_HTML+="<div class=\"wd past\">${pd}</div>"
        elif (( pd == TODAY_WS_POS )); then WAVE_HTML+="<div class=\"wd today\">${pd}</div>"
        else WAVE_HTML+="<div class=\"wd\">${pd}</div>"
        fi
    done

    # ── phi line ─────────────────────────────────────────────────────────────
    PHI_LINE=""
    [[ -n "$MY_PHI" ]] && PHI_LINE="⚛ φ_i = ${MY_PHI}  |  ω = ${MY_OMEGA} Hz"

    # ── Birthday banner ───────────────────────────────────────────────────────
    BDAY_BANNER=""
    [[ "$IS_BIRTHDAY" == "true" ]] && \
        BDAY_BANNER='<div class="birthday-banner">🎂 ANNIVERSAIRE KIN — Jour de puissance cosmique !</div>'

    # ── Injection dans le template via awk ─────────────────────────────────
    TMPL_USED="$TMPL"
    [[ "$IS_BIRTHDAY" == "true" && -f "$TMPL_BD" ]] && TMPL_USED="$TMPL_BD"

    # Question de captation de vibe (rotation quotidienne)
    _UNSUB_BASE="${uSPOT:-http://127.0.0.1:54321}/mailjet?email=${DEST}&token=$(printf '%s:%s' "$DEST" "$(cat "${HOME}/.zen/tmp/UPLANETNAME" 2>/dev/null || echo '')" | sha256sum | cut -c1-16)"
    RESONANCE_HTML=$(_kin_resonance_question "$DEST" "" "$_UNSUB_BASE")

    _entries_oracle=$(mktemp /tmp/kin_oracle_XXXXXX.html)
    _entries_game=$(mktemp /tmp/kin_game_XXXXXX.html)
    _entries_phi=$(mktemp /tmp/kin_phi_XXXXXX.html)
    _entries_hex=$(mktemp /tmp/kin_hex_XXXXXX.html)
    _entries_stats=$(mktemp /tmp/kin_stats_XXXXXX.html)
    _entries_rq=$(mktemp /tmp/kin_rq_XXXXXX.html)
    printf '%s' "$ORACLE_HTML"    > "$_entries_oracle"
    printf '%s' "$GAME_SEC"       > "$_entries_game"
    printf '%s' "$PHI_SEC"        > "$_entries_phi"
    printf '%s' "$HEX_SEC"        > "$_entries_hex"
    printf '%s' "$STATS_HTML"     > "$_entries_stats"
    printf '%s' "$RESONANCE_HTML" > "$_entries_rq"

    _out=$(mktemp /tmp/kin_daily_out_XXXXXX.html)

    awk \
        -v kn="$MY_KIN"        -v ks="$MY_SEAL"      -v kc="$MY_COLOR"     \
        -v kt="$MY_TONE"       -v khex="$MY_HEX"      -v kbg="$MY_BG"       \
        -v kemo="$MY_COLOR_EMO" -v ksemo="$MY_SEAL_EMO" -v ktnum="$((MK_TI+1))" \
        -v kpower="$MY_POWER"  -v kaction="$MY_ACTION" -v kessence="$MY_ESSENCE" \
        -v today_kn="$TODAY_KIN" -v today_ks="$TODAY_SEAL" -v today_kc="$TODAY_COLOR" \
        -v today_kt="$TODAY_TONE" -v today_emo="$TODAY_EMO" \
        -v today_power="$TODAY_POWER" -v today_action="$TODAY_ACTION" \
        -v today_ws="$TODAY_WS_NUM" -v today_wpos="$TODAY_WS_POS" \
        -v my_ws="$MY_WS_NUM" -v my_wpos="$MY_WS_POS" \
        -v date="$DATE_FR"     -v dest="$DEST"         -v score="$SCORE"      \
        -v phi_line="$PHI_LINE" -v bday_banner="$BDAY_BANNER" \
        -v omega_bio="${MY_OMEGA:-429.62}" \
        -v f_oracle="$_entries_oracle" -v f_game="$_entries_game" \
        -v f_phi="$_entries_phi"       -v f_hex="$_entries_hex"  \
        -v f_stats="$_entries_stats"   -v f_wave="$WAVE_HTML"    \
        -v f_rq="$_entries_rq" \
    '
    /_ORACLE_ENTRIES_/      { while((getline l < f_oracle)>0) print l; next }
    /_GAME_SECTION_/        { while((getline l < f_game)>0)   print l; next }
    /_PHI_SECTION_/         { while((getline l < f_phi)>0)    print l; next }
    /_HEX_SECTION_/         { while((getline l < f_hex)>0)    print l; next }
    /_STATS_CARDS_/         { while((getline l < f_stats)>0)  print l; next }
    /_RESONANCE_QUESTION_/  { while((getline l < f_rq)>0)     print l; next }
    /_WAVE_PROGRESS_/       { gsub(/_WAVE_PROGRESS_/, f_wave) }
    {
        gsub(/_KIN_NUM_/,       kn);   gsub(/_KIN_SEAL_/,       ks)
        gsub(/_KIN_COLOR_/,     kc);   gsub(/_KIN_TONE_/,       kt)
        gsub(/_KIN_HEX_COLOR_/, khex); gsub(/_KIN_BG_COLOR_/,   kbg)
        gsub(/_KIN_COLOR_EMO_/, kemo); gsub(/_KIN_SEAL_EMO_/,   ksemo)
        gsub(/_KIN_TONE_NUM_/,  ktnum); gsub(/_KIN_POWER_/,     kpower)
        gsub(/_KIN_ACTION_/,    kaction); gsub(/_KIN_ESSENCE_/,  kessence)
        gsub(/_TODAY_KIN_NUM_/, today_kn); gsub(/_TODAY_KIN_SEAL_/, today_ks)
        gsub(/_TODAY_KIN_COLOR_/, today_kc); gsub(/_TODAY_KIN_TONE_/, today_kt)
        gsub(/_TODAY_KIN_EMO_/, today_emo)
        gsub(/_TODAY_KIN_POWER_/, today_power); gsub(/_TODAY_KIN_ACTION_/, today_action)
        gsub(/_TODAY_WS_NUM_/,  today_ws); gsub(/_TODAY_WS_POS_/, today_wpos)
        gsub(/_MY_WS_NUM_/,     my_ws);   gsub(/_MY_WS_POS_/,    my_wpos)
        gsub(/_DATE_/,          date);    gsub(/_DEST_/,          dest)
        gsub(/_SCORE_/,         score);   gsub(/_PHI_LINE_/,      phi_line)
        gsub(/_BIRTHDAY_BANNER_/, bday_banner)
        gsub(/_OMEGA_BIO_/,     omega_bio)
        gsub(/_SWARM_ALERT_/,   "")
        gsub(/_VDO_URL_/, "https://vdo.copylaradio.com/?room=kin_birthday_" kn)
        print
    }' "$TMPL_USED" > "$_out"

    rm -f "$_entries_oracle" "$_entries_game" "$_entries_phi" "$_entries_hex" "$_entries_stats" "$_entries_rq"

    if [[ "$IS_BIRTHDAY" == "true" ]]; then
        SUBJECT=$(_kin_vibe_subject "birthday" "${_KIN_LANGAGE:-curieux}" "$MY_KIN" "$MY_SEAL" "$MY_COLOR_EMO" "$TODAY_SEAL" "$SCORE")
    else
        SUBJECT=$(_kin_vibe_subject "daily" "${_KIN_LANGAGE:-curieux}" "$MY_KIN" "$MY_SEAL" "$MY_COLOR_EMO" "$TODAY_SEAL" "$SCORE")
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] ${DEST}  Kin ${MY_KIN} guide=${MY_GUIDE} anti=${MY_ANTI} score=${SCORE}"
    elif [[ -x "$MJ" ]]; then
        _res=$("$MJ" "${DEST}" "${_out}" "${SUBJECT}" 2>&1)
        if echo "$_res" | grep -q "opt-out\|annule"; then
            echo "  ⛔ ${DEST}"; ((skipped_total++))
        else
            echo "  📤 → ${DEST} (Kin ${MY_KIN}, +${SCORE} pts)"; ((sent_total++))
        fi
    fi
    rm -f "$_out"
done

# ─── Bilan ────────────────────────────────────────────────────────────────────
echo "========================================================================"
printf "  ☀️  Kin %d %s — Vague-sort %d Jour %d/13\n" \
    "$TODAY_KIN" "$TODAY_SEAL" "$TODAY_WS_NUM" "$TODAY_WS_POS"
printf "  📊 %d envoye(s)  %d opt-out  %d profils\n" \
    "$sent_total" "$skipped_total" "${#RECIPIENTS[@]}"
echo "========================================================================"

[[ "$DRY_RUN" != "true" ]] && touch "$MARKER"
exit 0
