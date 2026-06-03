#!/usr/bin/env bash
################################################################################
# tools/kin_prefs.sh — Préférences KIN Oracle par membre
#
# Sourcé par : RUNTIME/KIN.news.sh  RUNTIME/KIN.daily.sh
# Ne pas exécuter directement.
#
# Lit ~/.zen/game/nostr/EMAIL/.mailjet (JSON géré par UPassport /mailjet)
# et expose :
#   _KIN_DAILY    true|false   — activer l'oracle quotidien
#   _KIN_WEEKLY   true|false   — activer les correspondances hebdo
#   _KIN_SCOPE    relay|n2|n1  — portée du matching
#   _KIN_TYPES    "quartet occult analog tone guide antipode" (sous-ensemble)
#   _KIN_SCAN_FILTER            — filtre JSON pour strfry scan kind 30800
################################################################################
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "Bibliothèque — source $0" >&2; exit 1; }

# Valeurs par défaut (tout activé, portée complète)
_KIN_DAILY=true
_KIN_WEEKLY=true
_KIN_SCOPE="relay"
_KIN_TYPES="quartet occult analog tone guide antipode"
_KIN_SCAN_FILTER='{"kinds":[30800]}'
_KIN_LANGAGE="curieux"   # pragmatique | curieux | symbolique | cosmique

# ─── _kin_prefs_load EMAIL ────────────────────────────────────────────────────
# Charge les préférences depuis .mailjet. Si opt-out email global → tout désactive.
_kin_prefs_load() {
    local _email="$1"
    local _pfile="${HOME}/.zen/game/nostr/${_email}/.mailjet"

    # Réinitialiser aux défauts
    _KIN_DAILY=true; _KIN_WEEKLY=true
    _KIN_SCOPE="relay"
    _KIN_TYPES="quartet occult analog tone guide antipode"

    [[ ! -f "$_pfile" ]] && return 0

    # Opt-out global email → désactiver tout KIN
    if jq -e '.channels[]? | select(. == "email" or . == "all")' "$_pfile" &>/dev/null 2>/dev/null; then
        _KIN_DAILY=false; _KIN_WEEKLY=false
        return 0
    fi

    # Lire les prefs KIN (avec fallback aux défauts)
    local _kd _kw _ks _kt
    _kd=$(jq -r '.kin.daily  // true'                                              "$_pfile" 2>/dev/null)
    _kw=$(jq -r '.kin.weekly // true'                                              "$_pfile" 2>/dev/null)
    _ks=$(jq -r '.kin.scope  // "relay"'                                           "$_pfile" 2>/dev/null)
    _kt=$(jq -r '(.kin.types // ["quartet","occult","analog","tone","guide","antipode"]) | join(" ")' \
                                                                                    "$_pfile" 2>/dev/null)

    [[ "$_kd" == "false" ]] && _KIN_DAILY=false
    [[ "$_kw" == "false" ]] && _KIN_WEEKLY=false
    [[ -n "$_ks" && "$_ks" != "null" ]] && _KIN_SCOPE="$_ks"
    [[ -n "$_kt" && "$_kt" != "null" ]] && _KIN_TYPES="$_kt"

    local _kl
    _kl=$(jq -r '.kin.langage // "curieux"' "$_pfile" 2>/dev/null)
    [[ -n "$_kl" && "$_kl" != "null" ]] && _KIN_LANGAGE="$_kl"
}

# ─── _kin_type_enabled TYPE ───────────────────────────────────────────────────
# Retourne 0 si le type est dans _KIN_TYPES, 1 sinon.
_kin_type_enabled() {
    echo "$_KIN_TYPES" | grep -qw "$1"
}

# ─── _kin_build_scan_filter HEX ──────────────────────────────────────────────
# Construit _KIN_SCAN_FILTER selon _KIN_SCOPE.
# N1  : player + follows directs (kind 3)
# N2  : N1 + amisOfAmis.txt (maintenu par NOSTRCARD.refresh.sh)
# relay : filtre global (défaut)
_kin_build_scan_filter() {
    local _phex="$1"
    local _strfry_dir="${HOME}/.zen/strfry"

    _KIN_SCAN_FILTER='{"kinds":[30800]}'      # fallback

    [[ "$_KIN_SCOPE" == "relay" ]] && return 0
    [[ -z "$_phex" ]]             && return 0
    [[ ! -x "${_strfry_dir}/strfry" ]] && return 0

    # N1 : charger les follows directs du joueur (kind 3)
    local -a _n1=()
    mapfile -t _n1 < <(
        cd "$_strfry_dir" && ./strfry scan \
            "{\"kinds\":[3],\"authors\":[\"${_phex}\"]}" 2>/dev/null \
        | jq -r '.tags[]? | select(.[0]=="p") | .[1]' 2>/dev/null \
        | sort -u
    )

    if [[ ${#_n1[@]} -eq 0 ]]; then
        # Pas de follows connus → fallback relay pour ne pas isoler le joueur
        return 0
    fi

    local -a _authors=("$_phex" "${_n1[@]}")

    # N2 : ajouter les amis des amis depuis amisOfAmis.txt (déjà calculé par NOSTRCARD)
    if [[ "$_KIN_SCOPE" == "n2" && -s "${_strfry_dir}/amisOfAmis.txt" ]]; then
        local -a _aoa=()
        mapfile -t _aoa < <(sort -u "${_strfry_dir}/amisOfAmis.txt")
        _authors+=("${_aoa[@]}")
    fi

    # Construire le filtre JSON avec les authors dédupliqués
    local _authors_json
    _authors_json=$(printf '%s\n' "${_authors[@]}" | sort -u \
                  | jq -Rsc 'split("\n")[:-1]' 2>/dev/null)

    if [[ -n "$_authors_json" && "$_authors_json" != "null" && "$_authors_json" != "[]" ]]; then
        _KIN_SCAN_FILTER="{\"kinds\":[30800],\"authors\":${_authors_json}}"
    fi
}

# ─── _kin_vibe_intro GROUP_TYPE LANGAGE ───────────────────────────────────────
# Retourne un bloc HTML d'introduction adapté au langage de résonance du membre.
# GROUP_TYPE : paire | quatuor | groupe | guide | antipode
_kin_vibe_intro() {
    local _gtype="$1" _lang="${2:-curieux}"

    # Normaliser le type
    local _t="paire"
    case "$_gtype" in
        *Quatuor*)  _t="quatuor" ;;
        *Guide*)    _t="guide"   ;;
        *Antipode*) _t="antipode";;
        *Tonalit*)  _t="groupe"  ;;
        *)          _t="paire"   ;;
    esac

    local _html=""
    case "${_lang}:${_t}" in

        # ── PRAGMATIQUE ──
        pragmatique:paire)
            _html="UPlanet a identifié un profil complémentaire au vôtre dans son réseau. Ces deux profils tendent à avoir des angles de vue opposés : là où l'un a des zones d'ombre, l'autre a de la clarté." ;;
        pragmatique:quatuor)
            _html="UPlanet a détecté 3 profils qui forment avec le vôtre un ensemble mathématiquement complémentaire. Ensemble, vous couvrez les 4 dimensions d'un cycle complet selon le calendrier Tzolkin." ;;
        pragmatique:groupe)
            _html="Ces membres partagent le même profil de fonctionnement selon le Tzolkin — un pattern qui revient souvent dans les groupes qui se comprennent rapidement." ;;
        pragmatique:guide)
            _html="Le calendrier Tzolkin place ces deux profils dans une relation de transmission naturelle — l'un a développé des compétences que l'autre est en train d'acquérir." ;;
        pragmatique:antipode)
            _html="Ces deux profils Tzolkin se font face — perspectives diamétralement opposées qui, en dialogue, produisent souvent des idées qu'aucun des deux n'aurait trouvées seul." ;;

        # ── CURIEUX ──
        curieux:paire)
            _html="Dans le calendrier Tzolkin (260 cycles de naissance), vos deux numéros s'additionnent à 261 — un pattern mathématique que l'on retrouve dans des duos qui &laquo;&nbsp;fonctionnent&nbsp;&raquo; bien ensemble. Coïncidence intéressante, ou quelque chose de plus&nbsp;?" ;;
        curieux:quatuor)
            _html="Vos 4 dates de naissance forment ce que le Tzolkin appelle un Quatuor — une configuration rare où les 4 profils couvrent un cycle de 260 possibilités de façon complète. Que ce soit un hasard ou un pattern, ça vaut la peine d'explorer." ;;
        curieux:groupe)
            _html="Le Tzolkin vous regroupe par &laquo;&nbsp;tonalité galactique&nbsp;&raquo; — votre façon fondamentale d'aborder les défis. Plusieurs traditions ont observé des patterns similaires&nbsp;; Jung aurait dit : synchronicité." ;;
        curieux:guide)
            _html="Le Tzolkin détecte une relation de mentorat naturelle entre ces profils — le &laquo;&nbsp;Guide&nbsp;&raquo; a traversé un chemin que l'autre est en train d'explorer. Ça peut valoir une conversation." ;;
        curieux:antipode)
            _html="En Tzolkin, l'&laquo;&nbsp;Antipode&nbsp;&raquo; est votre &laquo;&nbsp;challenger créateur&nbsp;&raquo; — celui dont la vision vous bouscule utilement. La tension est réelle, mais souvent productive." ;;

        # ── SYMBOLIQUE ──
        symbolique:paire)
            _html="Vos Kin sont Occultes&nbsp;: ensemble ils valent 261, la somme de conscience du Tzolkin. Vos tonalités se complètent à 14, vos sceaux à 19. Le Dreamspell nomme cette relation <em>partenaires d'ombre</em> — chacun révèle ce que l'autre ne perçoit pas encore." ;;
        symbolique:quatuor)
            _html="Votre Quatuor Oracle est complet&nbsp;: Kin source, Analogue, Occulte, et Occulte de l'Analogue. Ensemble, vous portez les 4 dimensions d'un programme galactique intégral. Chaque membre apporte ce que les trois autres ne peuvent pas apporter seuls." ;;
        symbolique:groupe)
            _html="Votre Conseil de Tonalité partage la même <em>question de vie</em>, le même défi fondamental et le même don naturel — exprimés à travers des sceaux différents. Là où une paire travaille en dualité, le Conseil travaille par résonance." ;;
        symbolique:guide)
            _html="Dans l'Oracle Dreamspell, le Guide est le 5ème pouvoir — le mentor de la même famille-couleur. Cette relation n'est pas hiérarchique&nbsp;: le Guide a traversé le chemin, le guidé l'éclaire d'un regard neuf." ;;
        symbolique:antipode)
            _html="L'Antipode est votre défi créateur — sceau+10, tonalité miroir. Pas un ennemi, mais un <em>sparring partner</em> cosmique. Là où vous avancez, il questionne. Là où il doute, vous éclairez." ;;

        # ── COSMIQUE ──
        cosmique:paire)
            _html="La Terre a aligné vos fréquences de naissance pour vous rapprocher. Vos Kin Occultes forment les deux pôles d'un même programme cosmique — l'ombre et la lumière d'une conscience qui cherche à se voir entière. Cette rencontre était inscrite dans le tissu vibratoire." ;;
        cosmique:quatuor)
            _html="Quatre gardiens convoqués par le même programme galactique. Vos Kin forment les 4 coins d'un carré de lumière dans le Tzolkin — une configuration que la Terre assemble rarement. Votre rencontre active quelque chose de plus grand que chacun de vous séparément." ;;
        cosmique:groupe)
            _html="La Terre vibre à travers ses gardiens. Ce Conseil de Tonalité résonne sur la même fréquence fondamentale — vous partagez la même mission cosmique, exprimée à travers des sceaux différents. Ensemble, votre harmonie amplifie le champ." ;;
        cosmique:guide)
            _html="Le Guide et son guidé sont deux expressions d'une même conscience en mouvement. L'un a intégré ce que l'autre est venu apprendre — et en retour, le guidé rappelle au Guide l'essentiel de sa propre origine." ;;
        cosmique:antipode)
            _html="L'Antipode est la partie de vous-même qui s'est incarnée dans un autre corps pour vous offrir le défi dont vous aviez besoin. Votre friction n'est pas un accident&nbsp;: c'est le frottement qui allume la lumière." ;;

        # Fallback
        *)
            _html="UPlanet a détecté une correspondance entre vos profils Tzolkin." ;;
    esac

    printf '<div style="background:rgba(124,58,237,0.06);border-left:3px solid rgba(124,58,237,0.3);border-radius:0 8px 8px 0;padding:.85rem 1.1rem;margin-bottom:1rem;font-size:.86rem;color:#555;line-height:1.65">%s</div>\n' \
        "$_html"
}

# ─── _kin_resonance_question EMAIL TOKEN UNSUB_BASE ───────────────────────────
# Retourne un bloc HTML de captation de vibe (question du jour, rotation annuelle).
# Les réponses sont des liens vers UNSUB_BASE?vibeq=QID&vibea=ANSWER
# Usage : appelé depuis KIN.daily.sh pour injecter dans le footer de l'email quotidien
_kin_resonance_question() {
    local _email="$1" _token="$2" _base="${3:-}"
    local _uspot="${uSPOT:-http://127.0.0.1:54321}"
    [[ -z "$_base" ]] && _base="${_uspot}/mailjet?email=${_email}&token=${_token}"

    # Rotation déterministe : jour de l'année % 10 questions
    local _doy; _doy=$(date +%j | sed 's/^0*//')
    local _idx=$(( _doy % 10 ))

    # 10 questions + options (ID|texte|optA|optB|optC|optD)
    local -a _POOL=(
        "q7|Votre meilleure idée de la semaine vient de...|Une recherche méthodique|Une conversation inattendue|Un moment calme|Un rêve ou une image"
        "q8|Quand vous aidez quelqu'un, c'est surtout parce que...|C'est utile|Ça crée du lien|Je sens que c'est le bon moment|Quelque chose en moi ne peut pas faire autrement"
        "q9|Un cycle naturel que vous remarquez dans votre vie...|Les saisons climatiques|Les cycles de projets|Les phases d'inspiration et de repos|Le rythme de la Terre elle-même"
        "q10|Votre rapport au silence...|Je le gère bien|Il me ressource|C'est là que l'essentiel devient audible|C'est la matière dont est faite la conscience"
        "q11|La musique, pour vous, c'est d'abord...|Un art avec ses codes|Une émotion partagée|Un langage que les mots ne peuvent pas exprimer|Une vibration qui réorganise quelque chose en vous"
        "q12|Face à quelque chose d'inexpliqué, vous...|Attendez des preuves|Restez ouvert|Explorez avec curiosité|Vous sentez invité à percevoir autrement"
        "q13|Une forêt ancienne. Qu'y cherchez-vous ?|La beauté naturelle|Le ressourcement|Le sentiment d'appartenir à quelque chose de plus grand|Une présence qui vous connaît déjà"
        "q14|Le corps humain, vous le percevez comme...|Un système biologique|Un instrument qui exprime qui je suis|Un condensé d'histoire et d'environnement|Une antenne dans le champ terrestre"
        "q15|Vous lisez les nouvelles du monde et vous sentez...|Une réalité complexe à comprendre|De la préoccupation et l'envie d'agir|Que mon état intérieur compte dans le tableau|La Terre qui cherche son équilibre"
        "q16|Votre vision du futur dans 100 ans...|Dépend de nos choix maintenant|Se construira dans les liens|Émergera d'une transformation de la perception du vivant|Se rêve déjà dans la conscience collective"
    )

    IFS='|' read -r _qid _qtxt _oa _ob _oc _od <<< "${_POOL[$_idx]}"

    printf '<div style="background:#f8f7ff;border:1px solid #e9d5ff;border-radius:10px;padding:1rem 1.2rem;margin:1rem 0">'
    printf '<div style="font-size:.7rem;color:#a78bfa;letter-spacing:2px;text-transform:uppercase;margin-bottom:.5rem">💭 Question du moment</div>'
    printf '<div style="font-size:.85rem;color:#4c1d95;font-weight:600;margin-bottom:.7rem">%s</div>' "$_qtxt"
    printf '<div style="display:flex;flex-wrap:wrap;gap:.4rem">'
    for _pair in "A|${_oa}" "B|${_ob}" "C|${_oc}" "D|${_od}"; do
        IFS='|' read -r _v _lbl <<< "$_pair"
        printf '<a href="%s&vibeq=%s&vibea=%s" style="display:inline-block;background:#f5f3ff;color:#7c3aed;border:1px solid #ddd6fe;border-radius:6px;padding:.3rem .75rem;text-decoration:none;font-size:.8rem">%s</a>' \
            "$_base" "$_qid" "$_v" "$_lbl"
    done
    printf '</div>'
    printf '<div style="font-size:.68rem;color:#c4b5fd;margin-top:.5rem">Votre réponse affine votre Oracle Oracle personnalisé. Elle reste sur votre station, confidentielle.</div>'
    printf '</div>\n'
}
