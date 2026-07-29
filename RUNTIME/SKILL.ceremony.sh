#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ SKILL.ceremony.sh
#~ Détection hebdomadaire de binômes "même savoir-faire" (Kind 30503, WoTx²)
#~ et proposition d'une cérémonie de démonstration filmée entre pairs.
#~
#~ Exemple : deux membres ont chacun déclaré le skill "boulanger" (x1 ou plus).
#~ Le script leur propose de se rencontrer, filmer leur partage de savoir-faire
#~ (four commun, pain, croissant, pain spécial…) et publier ensemble le résultat
#~ dans forge.html — soit un nouvel objet (Kind 30505), soit une recette
#~ (Kind 30500) enrichie de la vidéo, soit une montée de niveau du skill
#~ (['level', N] republié plus haut une fois la compétence attestée par un pair).
#~
#~ Notification : mailjet.sh --channel skillceremony gère TOUT (email toujours,
#~ + DM NIP-44 automatique si le destinataire a activé le canal NOSTR pour ce
#~ flux dans son profil .mailjet — flux_channels.skillceremony.nostr=true).
#~ Aucun envoi NOSTR réimplémenté ici : on s'appuie sur l'infra existante.
#~
#~ Usage: SKILL.ceremony.sh [--gps radius_km] [--force]
#~   --gps radius_km : ne notifie que les binômes distants d'au plus radius_km
#~                      l'un de l'autre (distance calculée entre les deux
#~                      membres du binôme, pas depuis un point fixe — sans
#~                      cette option, tous les binômes sont notifiés avec la
#~                      distance affichée à titre indicatif).
#~   --force          : ignore le marqueur hebdomadaire (renvoi)
#~   --dry-run        : détecte et affiche les binômes SANS envoyer d'email ni
#~                        marquer quoi que ce soit (marqueur semaine + log de
#~                        binômes notifiés inchangés) — à utiliser pour valider
#~                        la détection avant le premier envoi réel.
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

. "${MY_PATH}/../tools/my.sh"

# Bibliothèque Oracle partagée : _scan_did_mapping (pubkey→email via Kind 30800),
# _haversine_km, pubkey_email[] — même mécanisme que KIN.news.sh, pas de duplication.
# shellcheck source=/dev/null
source "${MY_PATH}/../tools/kin_oracle.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Arguments
# ─────────────────────────────────────────────────────────────────────────────
GPS_RADIUS=""
FORCE=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gps) GPS_RADIUS="${2:-}"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) shift ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Marqueur hebdomadaire (idempotence — un seul passage batch par semaine ISO)
# ─────────────────────────────────────────────────────────────────────────────
WEEK_KEY=$(date +%GW%V)
MARKER="${HOME}/.zen/game/.skill_ceremony_${WEEK_KEY}.done"
if [[ -f "$MARKER" && "$FORCE" != "true" ]]; then
    echo "SKILL.ceremony: déjà exécuté cette semaine (${WEEK_KEY}) — utiliser --force pour relancer."
    exit 0
fi

# Journal persistant des binômes déjà notifiés (évite de re-spammer chaque
# semaine tant que le niveau du skill n'a pas changé). Une ligne = clé unique
# "email1|email2|skilltag|level" (emails triés alphabétiquement).
NOTIFIED_LOG="${HOME}/.zen/game/.skill_ceremony_notified.log"
touch "$NOTIFIED_LOG"

STRFRY_DIR="${HOME}/.zen/strfry"
STRFRY_BIN="${STRFRY_DIR}/strfry"
if [[ ! -x "$STRFRY_BIN" ]]; then
    echo "SKILL.ceremony: strfry introuvable (${STRFRY_BIN}) — abandon." >&2
    exit 1
fi

echo "SKILL.ceremony: scan Kind 30503 (compétences WoTx²)…"

# ─────────────────────────────────────────────────────────────────────────────
# 1) pubkey → email (Kind 30800, DID) — même table que KIN.news.sh
# ─────────────────────────────────────────────────────────────────────────────
declare -A pubkey_email=()
_scan_did_mapping >/dev/null

# ─────────────────────────────────────────────────────────────────────────────
# 2) Regroupement des skills par tag normalisé (skill_tag → "pubkey level")
# Niveau extrait de la MÊME façon que forge.html::_canonicalSkillLevel() :
# tag explicite 'level' > content.level > suffixe ancré _X<n> du d-tag.
# Jamais de recherche de sous-chaîne libre "X2"/"X3".
# ─────────────────────────────────────────────────────────────────────────────
declare -A skill_members=() # skill_tag → "pubkey1:level1 pubkey2:level2 …"

while IFS= read -r evt; do
    [[ -z "$evt" ]] && continue
    pubkey=$(echo "$evt" | jq -r '.pubkey // empty')
    [[ -z "$pubkey" ]] && continue
    dtag=$(echo "$evt" | jq -r '(.tags[]? | select(.[0]=="d") | .[1]) // empty' | head -1)
    level_tag=$(echo "$evt" | jq -r '(.tags[]? | select(.[0]=="level") | .[1]) // empty' | head -1)
    content_level=$(echo "$evt" | jq -r '.content // "{}"' | jq -r '.level // empty' 2>/dev/null)
    skill_tag=$(echo "$evt" | jq -r '
        [.tags[]? | select(.[0]=="t") | .[1]
         | select(. != "permit" and . != "auto_proclaimed" and . != "composite" and . != "wotx2")]
        | first // empty')
    [[ -z "$skill_tag" ]] && continue

    level=""
    [[ -n "$level_tag" && "$level_tag" =~ ^[0-9]+$ ]] && level="$level_tag"
    [[ -z "$level" && -n "$content_level" && "$content_level" =~ ^[0-9]+$ ]] && level="$content_level"
    if [[ -z "$level" ]]; then
        [[ "$dtag" =~ _X([0-9]+)$ ]] && level="${BASH_REMATCH[1]}"
    fi
    [[ -z "$level" ]] && level=1

    skill_members["$skill_tag"]+="${pubkey}:${level} "
done < <(cd "$STRFRY_DIR" && ./strfry scan '{"kinds":[30503]}' 2>/dev/null)

echo "SKILL.ceremony: ${#skill_members[@]} skill(s) distinct(s) détecté(s) sur le relay."

# ─────────────────────────────────────────────────────────────────────────────
# 3) Pour chaque skill partagé par ≥2 emails distincts → proposer une cérémonie
# ─────────────────────────────────────────────────────────────────────────────
matched=0
skipped_logged=0
skipped_email=0

for skill_tag in "${!skill_members[@]}"; do
    # pubkey → email, dédoublonné (garde le niveau max déclaré par email)
    declare -A _email_level=()
    for entry in ${skill_members[$skill_tag]}; do
        pk="${entry%%:*}"; lvl="${entry##*:}"
        em="${pubkey_email[$pk]:-}"
        [[ -z "$em" ]] && continue
        cur="${_email_level[$em]:-0}"
        (( lvl > cur )) && _email_level["$em"]="$lvl"
    done

    emails=("${!_email_level[@]}")
    [[ ${#emails[@]} -lt 2 ]] && { unset _email_level; continue; }

    # Toutes les paires uniques
    for ((i=0; i<${#emails[@]}; i++)); do
        for ((j=i+1; j<${#emails[@]}; j++)); do
            em1="${emails[$i]}"; em2="${emails[$j]}"
            lvl1="${_email_level[$em1]}"; lvl2="${_email_level[$em2]}"
            pair_level=$(( lvl1 < lvl2 ? lvl1 : lvl2 )) # niveau min du binôme

            # Clé triée alphabétiquement — indépendante de l'ordre de découverte
            if [[ "$em1" < "$em2" ]]; then _a="$em1"; _b="$em2"; else _a="$em2"; _b="$em1"; fi
            pair_key="${_a}|${_b}|${skill_tag}|${pair_level}"
            if grep -qxF "$pair_key" "$NOTIFIED_LOG" 2>/dev/null; then
                # Ne sauter QUE cette paire — pas tout le groupe de skill (bug corrigé :
                # "continue 2" abandonnait aussi les autres paires valides du même skill).
                ((skipped_logged++)); continue
            fi

            # Distance GPS informative (jamais bloquante sauf --gps radius explicite)
            _dist=""
            _gps1=$(cat "${HOME}/.zen/game/nostr/${em1}/GPS" 2>/dev/null)
            _gps2=$(cat "${HOME}/.zen/game/nostr/${em2}/GPS" 2>/dev/null)
            if [[ -n "$_gps1" && -n "$_gps2" ]]; then
                _lat1=$(echo "$_gps1" | grep -oP '(?<=LAT=)[^;]+' | tr -d ' ')
                _lon1=$(echo "$_gps1" | grep -oP '(?<=LON=)[^;]+' | tr -d ' ')
                _lat2=$(echo "$_gps2" | grep -oP '(?<=LAT=)[^;]+' | tr -d ' ')
                _lon2=$(echo "$_gps2" | grep -oP '(?<=LON=)[^;]+' | tr -d ' ')
                if [[ -n "$_lat1" && -n "$_lon1" && -n "$_lat2" && -n "$_lon2" ]]; then
                    _dist=$(_haversine_km "$_lat1" "$_lon1" "$_lat2" "$_lon2")
                fi
            fi
            if [[ -n "$GPS_RADIUS" && -n "$_dist" ]]; then
                _within=$(awk -v d="$_dist" -v r="$GPS_RADIUS" 'BEGIN{print (d<=r)?1:0}')
                [[ "$_within" != "1" ]] && continue
            fi

            _dist_label="distance inconnue (GPS non renseigné)"
            [[ -n "$_dist" ]] && _dist_label=$(awk -v d="$_dist" 'BEGIN{printf "%.0f km", d}')

            _room_suffix=$(echo "$skill_tag $em1 $em2" | md5sum | cut -c1-10)
            _vdo_url="${VDONINJA:-https://vdo.copylaradio.com}/?room=skill_${_room_suffix}&effects&record"
            _cal_url="${myLIBRA}/ipns/copylaradio.com/calendars.html"
            _forge_url="${myLIBRA}/ipns/copylaradio.com/forge.html"

            for _dest in "$em1" "$em2"; do
                _other=$([[ "$_dest" == "$em1" ]] && echo "$em2" || echo "$em1")
                _tmpmail=$(mktemp)
                cat > "$_tmpmail" <<CEREMEOF
<div style="font-family:'Segoe UI',sans-serif;max-width:560px;margin:0 auto;color:#1a2e22">
<div style="background:linear-gradient(135deg,#059669,#10b981);padding:1.4rem;border-radius:12px 12px 0 0;color:#fff">
  <div style="font-size:1.1rem;font-weight:700">⚒️ Cérémonie de démonstration de savoir-faire</div>
  <div style="font-size:.85rem;opacity:.9;margin-top:.3rem">Skill partagé : <strong>${skill_tag}</strong> (niveau x${pair_level} minimum)</div>
</div>
<div style="padding:1.2rem;border:1px solid #d1fae5;border-top:none;border-radius:0 0 12px 12px">
  <p style="font-size:.9rem;line-height:1.6">
    Vous et <strong>${_other}</strong> avez tous les deux déclaré le savoir-faire
    <strong>${skill_tag}</strong> sur la constellation WoTx². C'est l'occasion de vous
    rencontrer, filmer un partage de pratique, et publier ensemble le résultat —
    une nouvelle recette, un objet, ou une montée de niveau du skill attestée par un pair.
  </p>
  <div style="font-size:.82rem;color:#065f46;margin:.6rem 0">📍 ${_dist_label}</div>
  <div style="display:flex;gap:.5rem;flex-wrap:wrap;margin-top:1rem">
    <a href="${_vdo_url}" style="display:inline-block;background:#059669;color:#fff;padding:.5rem 1.1rem;border-radius:8px;text-decoration:none;font-size:.85rem;font-weight:600">🎥 Visio maintenant</a>
    <a href="${_cal_url}" style="display:inline-block;background:#0ea5e9;color:#fff;padding:.5rem 1.1rem;border-radius:8px;text-decoration:none;font-size:.85rem;font-weight:600">📅 Planifier (Crafts collectifs)</a>
    <a href="${_forge_url}" style="display:inline-block;background:#8b5cf6;color:#fff;padding:.5rem 1.1rem;border-radius:8px;text-decoration:none;font-size:.85rem;font-weight:600">⚒️ Publier dans la Forge</a>
  </div>
</div>
</div>
CEREMEOF
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "  🧪 [DRY-RUN] enverrait à ${_dest} ↔ ${_other} (${skill_tag} x${pair_level}, ${_dist_label})"
                else
                    _result=$("${MY_PATH}/../tools/mailjet.sh" --channel skillceremony "${_dest}" "${_tmpmail}" \
                        "⚒️ Cérémonie de savoir-faire proposée : ${skill_tag}" 2>&1)
                    if echo "$_result" | grep -q "opt-out\|annulé"; then
                        echo "  ⛔ ${_dest} — opt-out actif"
                        ((skipped_email++))
                    else
                        echo "  📤 ${_dest} ↔ ${_other} (${skill_tag} x${pair_level})"
                    fi
                fi
                rm -f "$_tmpmail"
            done

            [[ "$DRY_RUN" != "true" ]] && echo "$pair_key" >> "$NOTIFIED_LOG"
            ((matched++))
        done
    done
    unset _email_level
done

[[ "$DRY_RUN" != "true" ]] && echo "$WEEK_KEY" > "$MARKER"
echo "SKILL.ceremony: terminé — ${matched} binôme(s) notifié(s), ${skipped_logged} déjà notifié(s) (log), ${skipped_email} opt-out."
