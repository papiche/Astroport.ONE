#!/bin/bash
################################################################################
# respawn_nostrcard_lib.sh
#
# Bibliothèque de fonctions pour tools/respawn_NOSTRCARD.sh — NE PAS exécuter
# directement, uniquement destinée à être sourcée.
#
# Contexte : certains MULTIPASS / ZenCard ont été créés avant que
# make_NOSTRCARD.sh, RUNTIME/VISA.new.sh et RUNTIME/NOSTRCARD.refresh.sh
# n'évoluent vers leur stockage actuel (nostr/$EMAIL/*, .multipass.json, DID
# kind 30800, home.station NODE, bio BRO, clé LOVE ATOM4LOVE...). Ces comptes
# "legacy" ne possèdent que le strict socle historique : .secret.nostr
# (NSEC/NPUB/HEX) et G1PUBNOSTR. Tout le reste peut manquer.
#
# Principe de réparation (jamais de recréation destructrice) :
#   - JAMAIS écraser un fichier déjà présent et non vide (sauf DID, cf ci-
#     dessous, et sauf --force explicite documenté par fonction)
#   - JAMAIS régénérer l'identité NOSTR (NSEC/NPUB/HEX) : elle est reprise
#     telle quelle depuis .secret.nostr, qui fait foi
#   - Le DID (kind 30800) est particulier : did_manager_nostr.sh update gère
#     déjà lui-même le cas création/mise à jour de façon idempotente (cf.
#     make_NOSTRCARD.sh qui l'appelle systématiquement à la création ET à la
#     mise à jour) — on l'appelle donc TOUJOURS sans condition, y compris
#     pour rafraîchir un DID déjà existant mais obsolète.
#   - Tier 1 : réparable sans le DISCO (SALT/PEPPER) — identité déjà connue
#     + environnement courant de la station (my.sh) suffisent.
#   - Tier 2 : nécessite le DISCO reconstitué (.secret.disco > .multipass.json
#     > --salt/--pepper fournis à la main). Avant toute écriture, on
#     RE-DÉRIVE le NPUB/HEX et le G1PUB depuis ce SALT/PEPPER et on vérifie
#     qu'ils correspondent bien à l'identité déjà enregistrée — un DISCO
#     erroné ne doit JAMAIS pouvoir introduire une clé différente.
#   - Jamais toucher aux fichiers d'état économique/coopératif vivant
#     (U.SOCIETY, .lastpayment, secret.june, G1PRIME...) : hors périmètre,
#     propriété exclusive de RUNTIME/NOSTRCARD.refresh.sh.
#   - "Niveau économique" (UPLANETNAME_G1 / libellé ORIGIN vs ẐEN) : recopié
#     depuis une trace déjà existante du compte (.multipass.json partiel,
#     .nostr.zine.html, .ZENCard.html) plutôt que depuis la valeur COURANTE
#     de la station, afin de ne jamais réécrire l'historique d'un compte
#     avec un niveau économique qui n'était pas le sien à l'origine.
################################################################################

RNC_LIB_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RNC_HELPER="${RNC_LIB_PATH}/respawn_nostrcard_helper.py"
RNC_NOSTR_ROOT="${HOME}/.zen/game/nostr"
RNC_PLAYERS_ROOT="${HOME}/.zen/game/players"

# Couleurs (mêmes conventions que did_manager_nostr.sh / nostr_RESTORE_TW.sh)
RNC_RED='\033[0;31m'
RNC_GREEN='\033[0;32m'
RNC_YELLOW='\033[1;33m'
RNC_CYAN='\033[0;36m'
RNC_NC='\033[0m'

rnc_die() { echo -e "${RNC_RED}❌ $*${RNC_NC}" >&2; }
rnc_warn() { echo -e "${RNC_YELLOW}⚠️  $*${RNC_NC}"; }
rnc_ok() { echo -e "${RNC_GREEN}✅ $*${RNC_NC}"; }
rnc_info() { echo -e "${RNC_CYAN}ℹ️  $*${RNC_NC}"; }

################################################################################
# AUDIT
################################################################################

# rnc_audit EMAIL : imprime le rapport JSON brut (usage --check / --scan-all)
rnc_audit_json() {
    local EMAIL="$1"
    python3 "${RNC_HELPER}" audit "${EMAIL}"
}

# rnc_audit_human EMAIL : affiche un rapport lisible + renseigne les globales
# RNC_TIER1_MISSING[], RNC_TIER2_MISSING[], RNC_ZENCARD_MISSING[],
# RNC_IS_MULTIPASS, RNC_ZENCARD_EXISTS, RNC_LEGACY (0/1)
rnc_audit_human() {
    local EMAIL="$1"
    local REPORT
    REPORT="$(rnc_audit_json "${EMAIL}")" || true

    RNC_IS_MULTIPASS=$(echo "${REPORT}" | jq -r '.is_multipass // false')
    RNC_ZENCARD_EXISTS=$(echo "${REPORT}" | jq -r '.zencard_exists // false')
    RNC_LEGACY=$(echo "${REPORT}" | jq -r '.legacy // false')
    mapfile -t RNC_TIER1_MISSING < <(echo "${REPORT}" | jq -r '.tier1_missing[]?')
    mapfile -t RNC_TIER2_MISSING < <(echo "${REPORT}" | jq -r '.tier2_missing[]?')
    mapfile -t RNC_INFO_MISSING < <(echo "${REPORT}" | jq -r '.info_only_missing[]?')
    mapfile -t RNC_ZENCARD_MISSING < <(echo "${REPORT}" | jq -r '.zencard_missing[]?')

    echo -e "${RNC_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RNC_NC}"
    echo -e "${RNC_CYAN}  Audit MULTIPASS : ${EMAIL}${RNC_NC}"
    echo -e "${RNC_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RNC_NC}"

    if [[ "${RNC_IS_MULTIPASS}" != "true" ]]; then
        local ERR
        ERR=$(echo "${REPORT}" | jq -r '.error // "UNKNOWN"')
        rnc_die "Pas de MULTIPASS exploitable pour ${EMAIL} (${ERR})"
        return 1
    fi

    if [[ ${#RNC_TIER1_MISSING[@]} -eq 0 ]]; then
        rnc_ok "Tier 1 (sans DISCO) : complet"
    else
        rnc_warn "Tier 1 (sans DISCO) — manquants : ${RNC_TIER1_MISSING[*]}"
    fi

    if [[ ${#RNC_TIER2_MISSING[@]} -eq 0 ]]; then
        rnc_ok "Tier 2 (nécessite DISCO) : complet"
    else
        rnc_warn "Tier 2 (nécessite DISCO) — manquants : ${RNC_TIER2_MISSING[*]}"
    fi

    if [[ ${#RNC_INFO_MISSING[@]} -gt 0 ]]; then
        rnc_info "ATOM4LOVE non activé (${RNC_INFO_MISSING[*]}) — nécessite des données de naissance, non auto-réparable"
    fi

    if [[ "${RNC_ZENCARD_EXISTS}" == "true" ]]; then
        if [[ ${#RNC_ZENCARD_MISSING[@]} -eq 0 ]]; then
            rnc_ok "ZenCard : complète"
        else
            rnc_warn "ZenCard — manquants : ${RNC_ZENCARD_MISSING[*]}"
        fi
    else
        rnc_info "Pas de ZenCard pour ce MULTIPASS (normal si jamais activée)"
    fi

    if [[ "${RNC_LEGACY}" == "true" ]]; then
        rnc_warn "STATUT : compte LEGACY — réparation recommandée"
        return 1
    else
        rnc_ok "STATUT : compte conforme au stockage actuel"
        return 0
    fi
}

# rnc_scan_all : audit de tous les comptes locaux, affichage synthétique
rnc_scan_all() {
    local REPORT
    REPORT="$(python3 "${RNC_HELPER}" scan-all)"
    local TOTAL LEGACY_COUNT
    TOTAL=$(echo "${REPORT}" | jq -r '.total')
    LEGACY_COUNT=$(echo "${REPORT}" | jq -r '.legacy_count')

    echo -e "${RNC_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RNC_NC}"
    echo -e "${RNC_CYAN}  Scan de tous les comptes MULTIPASS locaux${RNC_NC}"
    echo -e "${RNC_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RNC_NC}"
    echo -e "  Comptes analysés : ${TOTAL}"
    echo -e "  Comptes legacy   : ${LEGACY_COUNT}"
    echo ""

    if [[ "${LEGACY_COUNT}" -gt 0 ]]; then
        echo -e "${RNC_YELLOW}Comptes legacy détectés :${RNC_NC}"
        echo "${REPORT}" | jq -r '.legacy_emails[]' | while read -r em; do
            local T1 T2 ZC
            T1=$(echo "${REPORT}" | jq -r --arg e "$em" '.accounts[] | select(.email==$e) | (.tier1_missing | length)')
            T2=$(echo "${REPORT}" | jq -r --arg e "$em" '.accounts[] | select(.email==$e) | (.tier2_missing | length)')
            ZC=$(echo "${REPORT}" | jq -r --arg e "$em" '.accounts[] | select(.email==$e) | (.zencard_missing | length)')
            echo -e "  ${RNC_YELLOW}•${RNC_NC} ${em}  (tier1:${T1} tier2:${T2} zencard:${ZC})"
        done
        echo ""
        echo -e "${RNC_CYAN}Réparer un compte :${RNC_NC} respawn_NOSTRCARD.sh <email>"
    else
        rnc_ok "Aucun compte legacy — tous conformes au stockage actuel"
    fi
}

################################################################################
# RÉCUPÉRATION DU DISCO (SALT/PEPPER) + VÉRIFICATION DE SÉCURITÉ
################################################################################

# rnc_recover_disco EMAIL [CLI_SALT] [CLI_PEPPER]
# Renseigne RNC_SALT / RNC_PEPPER / RNC_DISCO_SOURCE. Retourne 1 si introuvable.
rnc_recover_disco() {
    local EMAIL="$1" CLI_SALT="$2" CLI_PEPPER="$3"
    local ARGS=(recover-disco "${EMAIL}")
    [[ -n "${CLI_SALT}" && -n "${CLI_PEPPER}" ]] && ARGS+=(--salt "${CLI_SALT}" --pepper "${CLI_PEPPER}")

    local RESULT
    RESULT="$(python3 "${RNC_HELPER}" "${ARGS[@]}" 2>/dev/null)"
    local RC=$?
    RNC_SALT=$(echo "${RESULT}" | jq -r '.salt // empty')
    RNC_PEPPER=$(echo "${RESULT}" | jq -r '.pepper // empty')
    RNC_DISCO_SOURCE=$(echo "${RESULT}" | jq -r '.source // empty')

    if [[ ${RC} -ne 0 || -z "${RNC_SALT}" || -z "${RNC_PEPPER}" ]]; then
        rnc_die "DISCO introuvable pour ${EMAIL} (.secret.disco et .multipass.json absents)"
        rnc_info "Si vous disposez du SALT/PEPPER d'origine (sauvegarde papier, email), relancez avec --salt/--pepper"
        return 1
    fi
    rnc_info "DISCO récupéré depuis : ${RNC_DISCO_SOURCE}"
    return 0
}

# rnc_verify_identity EMAIL SALT PEPPER : re-dérive NPUB/HEX et compare à
# l'identité déjà enregistrée. Retourne 1 et refuse toute suite en cas de
# désaccord (protection contre un DISCO faux/corrompu).
rnc_verify_identity() {
    local EMAIL="$1" SALT="$2" PEPPER="$3"
    local RESULT
    RESULT="$(python3 "${RNC_HELPER}" verify-identity "${EMAIL}" --salt "${SALT}" --pepper "${PEPPER}" 2>/dev/null)"
    local RC=$?
    if [[ ${RC} -ne 0 ]]; then
        local EXISTING_HEX DERIVED_HEX
        EXISTING_HEX=$(echo "${RESULT}" | jq -r '.existing_hex // "?"')
        DERIVED_HEX=$(echo "${RESULT}" | jq -r '.derived_hex // "?"')
        rnc_die "SALT/PEPPER NE CORRESPONDENT PAS à l'identité existante de ${EMAIL}"
        rnc_die "  HEX existant : ${EXISTING_HEX}"
        rnc_die "  HEX dérivé   : ${DERIVED_HEX}"
        rnc_die "Abandon — un DISCO incorrect ne doit jamais être utilisé (créerait une identité différente)"
        return 1
    fi
    rnc_ok "Identité vérifiée : le DISCO reproduit bien le NPUB/HEX existant"
    return 0
}

# rnc_verify_duniter_pub SALT PEPPER EXISTING_PUB [SUFFIX] : re-dérive une
# clé Duniter (v1) depuis SALT/PEPPER(+SUFFIX optionnel), la convertit en
# SS58, et vérifie qu'elle correspond bien à EXISTING_PUB (SS58). Utilisé
# pour G1PUBNOSTR (SUFFIX="_<UPLANET_SALT>") et pour le G1PUB de ZenCard
# (pas de suffixe).
rnc_verify_duniter_pub() {
    local SALT="$1" PEPPER="$2" EXISTING_PUB="$3" SUFFIX="$4"
    local CRED
    CRED=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
    chmod 600 "${CRED}"
    printf '%s\n%s\n' "${SALT}" "${PEPPER}${SUFFIX}" > "${CRED}"
    local DERIVED_V1 DERIVED_SS58
    DERIVED_V1=$("${RNC_LIB_PATH}/keygen" -t duniter -i "${CRED}" 2>/dev/null)
    rm -f "${CRED}"
    [[ -z "${DERIVED_V1}" ]] && { rnc_die "Échec de dérivation Duniter (keygen)"; return 1; }
    DERIVED_SS58="${DERIVED_V1}"
    if [[ -x "${RNC_LIB_PATH}/g1pub_to_ss58.py" ]]; then
        local CONVERTED
        CONVERTED=$(python3 "${RNC_LIB_PATH}/g1pub_to_ss58.py" "${DERIVED_V1}" 2>/dev/null)
        [[ -n "${CONVERTED}" ]] && DERIVED_SS58="${CONVERTED}"
    fi
    if [[ "${DERIVED_SS58}" != "${EXISTING_PUB}" && "${DERIVED_V1}" != "${EXISTING_PUB}" ]]; then
        rnc_die "La clé Duniter re-dérivée (${DERIVED_SS58:0:16}...) ne correspond PAS à la clé existante (${EXISTING_PUB:0:16}...)"
        return 1
    fi
    return 0
}

# rnc_recover_econ_level EMAIL : renseigne RNC_UPLANETNAME_G1 / RNC_ECON_SOURCE
rnc_recover_econ_level() {
    local EMAIL="$1"
    local RESULT
    RESULT="$(python3 "${RNC_HELPER}" recover-econ-level "${EMAIL}" 2>/dev/null)"
    RNC_UPLANETNAME_G1=$(echo "${RESULT}" | jq -r '.uplanetname_g1 // empty')
    RNC_ECON_SOURCE=$(echo "${RESULT}" | jq -r '.source // "none"')

    if [[ -n "${RNC_UPLANETNAME_G1}" ]]; then
        rnc_info "Niveau économique recopié depuis ${RNC_ECON_SOURCE} : uplanetname_g1=${RNC_UPLANETNAME_G1}"
    else
        RNC_UPLANETNAME_G1="${UPLANETNAME_G1}"
        rnc_warn "Niveau économique d'origine introuvable — utilisation de la valeur COURANTE de la station (UPLANETNAME_G1=${UPLANETNAME_G1})"
        rnc_warn "Vérifiez qu'elle correspond bien au niveau économique d'origine de ce compte avant tout envoi au titulaire"
    fi
}

################################################################################
# TIER 1 — réparable SANS le DISCO
################################################################################

rnc_repair_tier1() {
    local EMAIL="$1"
    local NDIR="${RNC_NOSTR_ROOT}/${EMAIL}"
    local DRY="${RNC_DRY_RUN:-0}"

    [[ ! -s "${NDIR}/.secret.nostr" ]] && { rnc_die "Pas d'identité NOSTR pour ${EMAIL} — abandon"; return 1; }
    source "${NDIR}/.secret.nostr"   # NSEC / NPUB / HEX
    [[ -z "${HEX}" || -z "${NPUB}" ]] && { rnc_die ".secret.nostr illisible pour ${EMAIL}"; return 1; }

    echo -e "${RNC_CYAN}── Réparation Tier 1 (identité + métadonnées, sans DISCO) ──${RNC_NC}"

    # HEX / NPUB : simple recopie depuis l'identité déjà connue
    if [[ ! -s "${NDIR}/HEX" ]]; then
        [[ "${DRY}" == "1" ]] && rnc_info "[dry-run] créerait HEX" || { echo "${HEX}" > "${NDIR}/HEX"; rnc_ok "HEX recréé"; }
    fi
    if [[ ! -s "${NDIR}/NPUB" ]]; then
        [[ "${DRY}" == "1" ]] && rnc_info "[dry-run] créerait NPUB" || { echo "${NPUB}" > "${NDIR}/NPUB"; rnc_ok "NPUB recréé"; }
    fi

    # LANG
    if [[ ! -s "${NDIR}/LANG" ]]; then
        [[ "${DRY}" == "1" ]] && rnc_info "[dry-run] créerait LANG=${RNC_LANG:-fr}" \
            || { echo "${RNC_LANG:-fr}" > "${NDIR}/LANG"; rnc_ok "LANG recréé (${RNC_LANG:-fr})"; }
    fi

    # .pass — PIN court, réutilisé partout ensuite (ZenCard, PASS "0000"...)
    if [[ ! -s "${NDIR}/.pass" ]]; then
        if [[ "${DRY}" == "1" ]]; then
            rnc_info "[dry-run] créerait .pass"
        else
            local PASS
            PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-5)
            echo "${PASS}" > "${NDIR}/.pass"
            chmod 600 "${NDIR}/.pass"
            rnc_ok ".pass recréé (PIN=${PASS})"
        fi
    fi

    # home.station — identité NOSTR du NODE (station hôte)
    if [[ ! -s "${NDIR}/home.station" ]]; then
        if [[ "${DRY}" == "1" ]]; then
            rnc_info "[dry-run] créerait home.station"
        else
            local NODE_NOSTR_HEX=""
            [[ -s "${HOME}/.zen/game/secret.nostr" ]] \
                && NODE_NOSTR_HEX=$(sed 's/.*HEX=\([^;]*\).*/\1/' "${HOME}/.zen/game/secret.nostr" 2>/dev/null)
            echo "${IPFSNODEID}:${NODE_NOSTR_HEX}" > "${NDIR}/home.station"
            chmod 644 "${NDIR}/home.station"
            rnc_ok "home.station recréé (NODE=${IPFSNODEID:0:8}...)"
        fi
    fi

    # TODATE / ZUMAP / GPS
    if [[ ! -s "${NDIR}/GPS" ]]; then
        if [[ "${DRY}" == "1" ]]; then
            rnc_info "[dry-run] créerait GPS/ZUMAP (LAT/LON)"
        else
            local ZLAT="${RNC_LAT:-}" ZLON="${RNC_LON:-}"
            if [[ -z "${ZLAT}" || -z "${ZLON}" ]] && [[ -s "${HOME}/.zen/GPS" ]]; then
                source "${HOME}/.zen/GPS"
                ZLAT="${LAT}"; ZLON="${LON}"
            fi
            ZLAT="${ZLAT:-0.00}"; ZLON="${ZLON:-0.00}"
            echo "LAT=${ZLAT}; LON=${ZLON};" > "${NDIR}/GPS"
            rnc_warn "GPS recréé avec LAT=${ZLAT} LON=${ZLON} (géolocalisation d'origine perdue — passez --lat/--lon pour la restaurer)"
        fi
    fi
    if [[ ! -s "${NDIR}/ZUMAP" ]] && [[ -s "${NDIR}/GPS" ]]; then
        if [[ "${DRY}" == "1" ]]; then
            rnc_info "[dry-run] créerait ZUMAP"
        else
            source "${NDIR}/GPS"
            echo "_${LAT}_${LON}" > "${NDIR}/ZUMAP"
            rnc_ok "ZUMAP recréé"
        fi
    fi
    if [[ ! -s "${NDIR}/TODATE" ]]; then
        [[ "${DRY}" == "1" ]] && rnc_info "[dry-run] créerait TODATE" \
            || { echo "${TODATE:-$(date -u +%Y%m%d%H%M%S)}" > "${NDIR}/TODATE"; rnc_ok "TODATE recréé"; }
    fi

    # Bio narrative BRO (identity/*.md) — jamais écrasée si déjà présente
    mkdir -p "${NDIR}/identity/"
    if [[ "${DRY}" != "1" ]]; then
        [[ ! -f "${NDIR}/identity/.Core.md" ]] && cat > "${NDIR}/identity/.Core.md" <<'EOFCORE'
<!--
  Qui es-tu ? Ton métier, ta mission, ce qui te définit.
  Écris librement en dessous de ce commentaire — BRO le lira à chaque réponse.
-->
EOFCORE
        [[ ! -f "${NDIR}/identity/.Style.md" ]] && cat > "${NDIR}/identity/.Style.md" <<'EOFSTYLE'
<!--
  Ton ton : tutoiement ou vouvoiement, concis ou verbeux, emojis préférés,
  expressions à éviter ou à privilégier.
-->
EOFSTYLE
        [[ ! -f "${NDIR}/identity/.Rules.md" ]] && cat > "${NDIR}/identity/.Rules.md" <<'EOFRULES'
<!--
  Ce que BRO ne doit jamais faire ou dire en ton nom.
-->
EOFRULES
        [[ ! -f "${NDIR}/identity/.Preferences.md" ]] && cat > "${NDIR}/identity/.Preferences.md" <<'EOFPREFS'
<!--
  Tes préférences et contraintes personnelles (santé, alimentation,
  centres d'intérêt...). BRO peut proposer d'y ajouter une ligne quand
  tu lui confies une information durable via #rec.
-->
EOFPREFS
        [[ ! -f "${NDIR}/identity/.Objectifs.md" ]] && cat > "${NDIR}/identity/.Objectifs.md" <<'EOFGOALS'
<!--
  Tes objectifs en cours, un par ligne, au format checkbox :
    - [ ] Avancer sur DevOps
    - [x] Objectif déjà atteint (ignoré par BRO)
  BRO relance ponctuellement sur un objectif non coché resté sans lien
  avec la conversation récente (détecteur proactif 'goal_drift').
-->
EOFGOALS
        rnc_ok "Bio BRO (identity/*.md) vérifiée/complétée"
    else
        rnc_info "[dry-run] compléterait identity/*.md (scaffold BRO, sans écraser l'existant)"
    fi

    # uDRIVE
    if [[ ! -s "${NDIR}/APP/uDRIVE/index.html" ]]; then
        if [[ "${DRY}" == "1" ]]; then
            rnc_info "[dry-run] créerait APP/uDRIVE/"
        else
            local YOUSER
            YOUSER=$("${RNC_LIB_PATH}/clyuseryomail.sh" "${EMAIL}")
            mkdir -p "${NDIR}/APP/uDRIVE/Documents"
            [[ -s "${HOME}/.zen/workspace/UPlanet/UPlanet_Enter_Help.md" ]] \
                && cp "${HOME}/.zen/workspace/UPlanet/UPlanet_Enter_Help.md" \
                      "${NDIR}/APP/uDRIVE/Documents/README.${YOUSER}.md" 2>/dev/null
            (
                cd "${NDIR}/APP/uDRIVE/" || exit 1
                [[ ! -L generate_ipfs_structure.sh ]] \
                    && ln -sf "${RNC_LIB_PATH}/generate_ipfs_structure.sh" ./generate_ipfs_structure.sh
                local UDRIVE
                UDRIVE=$(./generate_ipfs_structure.sh . 2>/dev/null)
                echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/${UDRIVE}\"></head></html>" > index.html
            )
            rnc_ok "APP/uDRIVE recréé"
        fi
    fi

    # DID (kind 30800) — TOUJOURS rafraîchi (create-or-update idempotent)
    if [[ "${DRY}" == "1" ]]; then
        rnc_info "[dry-run] appellerait did_manager_nostr.sh update ${EMAIL}"
    elif [[ -x "${RNC_LIB_PATH}/did_manager_nostr.sh" ]]; then
        if "${RNC_LIB_PATH}/did_manager_nostr.sh" update "${EMAIL}" "MULTIPASS" "0" "0" >/dev/null 2>&1; then
            rnc_ok "DID (kind 30800) créé/rafraîchi"
        else
            rnc_warn "did_manager_nostr.sh a échoué pour ${EMAIL} (non bloquant)"
        fi
    else
        rnc_warn "did_manager_nostr.sh introuvable — DID non rafraîchi"
    fi

    return 0
}

################################################################################
# TIER 2 — nécessite le DISCO (SALT/PEPPER)
################################################################################

rnc_repair_tier2() {
    local EMAIL="$1" SALT="$2" PEPPER="$3"
    local NDIR="${RNC_NOSTR_ROOT}/${EMAIL}"
    local DRY="${RNC_DRY_RUN:-0}"

    source "${NDIR}/.secret.nostr"
    local G1PUBNOSTR
    G1PUBNOSTR=$(cat "${NDIR}/G1PUBNOSTR" 2>/dev/null)
    [[ -z "${G1PUBNOSTR}" ]] && { rnc_die "G1PUBNOSTR manquant pour ${EMAIL} — impossible de continuer le Tier 2"; return 1; }

    # Vérification de sécurité : le G1PUBNOSTR re-dérivé depuis SALT/PEPPER
    # (+ suffixe UPLANET) doit correspondre à l'existant, sans quoi tout
    # chiffrement SSSS/QR ci-dessous utiliserait une mauvaise clé.
    local UPLANET_SALT
    UPLANET_SALT=$(echo -n "${UPLANETNAME}" | sha256sum | cut -c1-16)
    if ! rnc_verify_duniter_pub "${SALT}" "${PEPPER}" "${G1PUBNOSTR}" "_${UPLANET_SALT}"; then
        rnc_die "Abandon du Tier 2 — le portefeuille NOSTR (G1PUBNOSTR) ne correspond pas au DISCO fourni"
        return 1
    fi
    rnc_ok "G1PUBNOSTR vérifié (le DISCO reproduit bien le portefeuille existant)"

    echo -e "${RNC_CYAN}── Réparation Tier 2 (SSSS/portefeuilles jumeaux/QR, DISCO requis) ──${RNC_NC}"

    local DISCO="/?salt=${SALT}&nostr=${PEPPER}"

    # .secret.disco
    if [[ ! -s "${NDIR}/.secret.disco" ]]; then
        [[ "${DRY}" == "1" ]] && rnc_info "[dry-run] créerait .secret.disco" \
            || { echo "${DISCO}" > "${NDIR}/.secret.disco"; chmod 600 "${NDIR}/.secret.disco"; rnc_ok ".secret.disco recréé"; }
    fi

    # SSSS shares (head/mid/tail + clé QR terminal) — TOUT ou RIEN : si un
    # seul morceau existe déjà, on ne touche à rien (ne jamais mélanger un
    # nouveau split avec un ancien split du même DISCO).
    if [[ ! -s "${NDIR}/.ssss.head.player.enc" && ! -s "${NDIR}/.ssss.mid.captain.enc" \
          && ! -s "${NDIR}/ssss.tail.uplanet.enc" && ! -s "${NDIR}/.ssss.player.key" ]]; then
        if [[ "${DRY}" == "1" ]]; then
            rnc_info "[dry-run] régénérerait les parts SSSS (head/mid/tail)"
        else
            local TMPD
            TMPD=$(mktemp -d)
            echo "${DISCO}" | ssss-split -t 2 -n 3 -q > "${TMPD}/ssss"
            local HEAD MIDDLE TAIL
            HEAD=$(sed -n '1p' "${TMPD}/ssss")
            MIDDLE=$(sed -n '2p' "${TMPD}/ssss")
            TAIL=$(sed -n '3p' "${TMPD}/ssss")

            local MID_ENC_KEY="${CAPTAING1PUB:-$UPLANETG1PUB}"
            if [[ -z "${MID_ENC_KEY}" ]]; then
                rnc_die "CAPTAING1PUB/UPLANETG1PUB absents — impossible de chiffrer la part SSSS 'mid'"
                rm -rf "${TMPD}"
            else
                echo "${HEAD}" > "${TMPD}/head"
                echo "${MIDDLE}" > "${TMPD}/mid"
                echo "${TAIL}" > "${TMPD}/tail"
                "${RNC_LIB_PATH}/natools.py" encrypt -p "${G1PUBNOSTR}" -i "${TMPD}/head" -o "${NDIR}/.ssss.head.player.enc" >/dev/null
                "${RNC_LIB_PATH}/natools.py" encrypt -p "${MID_ENC_KEY}" -i "${TMPD}/mid" -o "${NDIR}/.ssss.mid.captain.enc" >/dev/null
                "${RNC_LIB_PATH}/natools.py" encrypt -p "${UPLANETG1PUB}" -i "${TMPD}/tail" -o "${NDIR}/ssss.tail.uplanet.enc" >/dev/null

                # Clé QR terminal "M-<base58(head:NOSTRNS)>" — a besoin de NOSTRNS ;
                # régénérée juste après si NOSTRNS est lui aussi absent (cf. plus bas).
                RNC_TIER2_PENDING_SSSS_HEAD="${HEAD}"
                rm -rf "${TMPD}"
                rnc_ok "Parts SSSS (head/mid/tail) recréées"
            fi
        fi
    fi

    # NOSTRNS (clé IPNS personnelle du coffre MULTIPASS)
    if [[ ! -s "${NDIR}/NOSTRNS" ]]; then
        if [[ "${DRY}" == "1" ]]; then
            rnc_info "[dry-run] créerait NOSTRNS (clé IPNS ${G1PUBNOSTR}:NOSTR)"
        else
            local CRED
            CRED=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
            printf '%s\n%s\n' "${SALT}" "${PEPPER}_${UPLANET_SALT}" > "${CRED}"
            local IPNSKEY
            IPNSKEY=$(mktemp)
            "${RNC_LIB_PATH}/keygen" -t ipfs -o "${IPNSKEY}" -i "${CRED}"
            rm -f "${CRED}"
            ipfs key rm "${G1PUBNOSTR}:NOSTR" >/dev/null 2>&1
            local NOSTRNS
            NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext "${IPNSKEY}" 2>/dev/null)
            rm -f "${IPNSKEY}"
            if [[ -n "${NOSTRNS}" ]]; then
                echo "/ipns/${NOSTRNS}" > "${NDIR}/NOSTRNS"
                rnc_ok "NOSTRNS recréé (/ipns/${NOSTRNS})"
            else
                rnc_warn "Échec de création de la clé IPNS NOSTRNS"
            fi
        fi
    fi

    # Clé QR terminal SSSS — nécessite le head SSSS + NOSTRNS
    if [[ ! -s "${NDIR}/.ssss.player.key" ]] && [[ -s "${NDIR}/NOSTRNS" ]] && [[ "${DRY}" != "1" ]]; then
        local NOSTRNS_VAL SSSS_HEAD SSSS_HEAD_B58
        NOSTRNS_VAL=$(sed 's~/ipns/~~' "${NDIR}/NOSTRNS")
        SSSS_HEAD="${RNC_TIER2_PENDING_SSSS_HEAD:-}"
        if [[ -z "${SSSS_HEAD}" && -s "${NDIR}/.ssss.head.player.enc" ]]; then
            # Le head existait déjà mais pas la clé QR terminal : on ne peut
            # pas déchiffrer .ssss.head.player.enc sans la clé privée du
            # joueur (chiffré avec G1PUBNOSTR) — non réparable ici.
            rnc_warn ".ssss.player.key manquant mais .ssss.head.player.enc déjà chiffré — non récupérable automatiquement (nécessite la clé privée du joueur)"
        elif [[ -n "${SSSS_HEAD}" ]]; then
            SSSS_HEAD_B58=$("${RNC_LIB_PATH}/Mbase58.py" encode "${SSSS_HEAD}:${NOSTRNS_VAL}")
            echo "M-${SSSS_HEAD_B58}" > "${NDIR}/.ssss.player.key"
            rnc_ok ".ssss.player.key recréé"
        fi
    fi

    # BITCOIN / MONERO (portefeuilles jumeaux, même dérivation que G1PUBNOSTR)
    if [[ ! -s "${NDIR}/BITCOIN" || ! -s "${NDIR}/MONERO" ]] && [[ "${DRY}" != "1" ]]; then
        local CRED
        CRED=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
        printf '%s\n%s\n' "${SALT}" "${PEPPER}_${UPLANET_SALT}" > "${CRED}"
        if [[ ! -s "${NDIR}/BITCOIN" ]]; then
            local BTC
            BTC=$("${RNC_LIB_PATH}/keygen" -t bitcoin -i "${CRED}" 2>/dev/null | tail -n 1 | rev | cut -f 1 -d ' ' | rev)
            [[ -n "${BTC}" ]] && { echo "${BTC}" > "${NDIR}/BITCOIN"; rnc_ok "BITCOIN recréé"; }
        fi
        if [[ ! -s "${NDIR}/MONERO" ]]; then
            local XMR
            XMR=$("${RNC_LIB_PATH}/keygen" -t monero -i "${CRED}" 2>/dev/null | tail -n 1 | rev | cut -f 1 -d ' ' | rev)
            [[ -n "${XMR}" ]] && { echo "${XMR}" > "${NDIR}/MONERO"; rnc_ok "MONERO recréé"; }
        fi
        rm -f "${CRED}"
    fi

    # Niveau économique (pour .multipass.json et le zine ci-dessous)
    rnc_recover_econ_level "${EMAIL}"

    # .multipass.json — utile aux clients API (UPassport /g1nostr)
    if [[ ! -s "${NDIR}/.multipass.json" ]] && [[ "${DRY}" != "1" ]]; then
        local PASS SSSS_QR_CONTENT NOSTRNS_VAL2 ZLAT ZLON
        PASS=$(cat "${NDIR}/.pass" 2>/dev/null)
        SSSS_QR_CONTENT=$(cat "${NDIR}/.ssss.player.key" 2>/dev/null)
        NOSTRNS_VAL2=$(cat "${NDIR}/NOSTRNS" 2>/dev/null | sed 's~/ipns/~~')
        if [[ -s "${NDIR}/GPS" ]]; then source "${NDIR}/GPS"; ZLAT="${LAT}"; ZLON="${LON}"; fi
        cat > "${NDIR}/.multipass.json" <<EOFJSON
{
  "g1pub": "${G1PUBNOSTR}",
  "nsec": "${NSEC}",
  "npub": "${NPUB}",
  "hex": "${HEX}",
  "pass": "${PASS}",
  "ssss": "${SSSS_QR_CONTENT}",
  "nostrns": "${NOSTRNS_VAL2}",
  "salt": "${SALT}",
  "pepper": "${PEPPER}",
  "email": "${EMAIL}",
  "lat": "${ZLAT:-0.00}",
  "lon": "${ZLON:-0.00}",
  "uplanetname_g1": "${RNC_UPLANETNAME_G1}"
}
EOFJSON
        rnc_ok ".multipass.json recréé (niveau économique : ${RNC_UPLANETNAME_G1})"
    fi

    # QR codes (uSPOT / IPNS vault / SSSS / MULTIPASS / PROFILE)
    if [[ "${DRY}" != "1" ]]; then
        if [[ ! -s "${NDIR}/uSPOT.QR.png" ]] && command -v amzqr >/dev/null 2>&1; then
            amzqr "${uSPOT}/scan" -l H -p "${RNC_LIB_PATH}/../templates/img/cloud_border.png" \
                -c -n uSPOT.QR.png -d "${NDIR}/" &>/dev/null \
                && rnc_ok "uSPOT.QR.png recréé"
        fi
        if [[ ! -s "${NDIR}/IPNS.QR.png" ]] && [[ -s "${NDIR}/NOSTRNS" ]] && command -v amzqr >/dev/null 2>&1; then
            local NOSTRNS_VAL3
            NOSTRNS_VAL3=$(cat "${NDIR}/NOSTRNS" | sed 's~/ipns/~~')
            amzqr "${myLIBRA}/ipns/${NOSTRNS_VAL3}/${EMAIL}/APP/uDRIVE" -l H -p "${RNC_LIB_PATH}/../templates/img/no_stripfs.png" \
                -c -n IPNS.QR.png -d "${NDIR}/" &>/dev/null \
                && rnc_ok "IPNS.QR.png recréé"
        fi
        if [[ ! -s "${NDIR}/._SSSSQR.png" ]] && [[ -s "${NDIR}/.ssss.player.key" ]] && command -v amzqr >/dev/null 2>&1; then
            amzqr "$(cat "${NDIR}/.ssss.player.key")" -l H -p "${RNC_LIB_PATH}/../templates/img/key.png" \
                -c -n ._SSSSQR.png -d "${NDIR}/" &>/dev/null \
                && rnc_ok "._SSSSQR.png recréé"
        fi
        if [[ ! -s "${NDIR}/MULTIPASS.QR.png" ]] && command -v amzqr >/dev/null 2>&1; then
            local FDQR="${RNC_LIB_PATH}/../templates/img/nature_cloud_face.png"
            [[ -s "${NDIR}/picture.png" ]] && FDQR="${NDIR}/picture.png"
            amzqr "${G1PUBNOSTR}:ZEN" -l H -p "${FDQR}" -c -n MULTIPASS.QR.o.png -d "${NDIR}/" &>/dev/null
            [[ -s "${NDIR}/MULTIPASS.QR.o.png" ]] \
                && convert "${NDIR}/MULTIPASS.QR.o.png" -bordercolor white -border 90x90 "${NDIR}/MULTIPASS.QR.png" \
                && rnc_ok "MULTIPASS.QR.png recréé"
        fi
        if [[ ! -s "${NDIR}/MULTIPASS.QR.png.cid" ]] && [[ -s "${NDIR}/MULTIPASS.QR.png" ]]; then
            local CID
            CID="$(ipfs --timeout 30s add -wq "${NDIR}/MULTIPASS.QR.png" 2>/dev/null | tail -n 1)/MULTIPASS.QR.png"
            [[ -n "${CID}" ]] && { echo "${CID}" > "${NDIR}/MULTIPASS.QR.png.cid"; rnc_ok "MULTIPASS.QR.png.cid recréé"; }
        fi
        if [[ ! -s "${NDIR}/PROFILE.QR.png" ]] && command -v amzqr >/dev/null 2>&1; then
            amzqr "${myLIBRA}/ipns/copylaradio.com/nostr_profile_viewer.html?hex=${HEX}" -l H -p "${RNC_LIB_PATH}/../images/lamanostr.png" \
                -c -n PROFILE.QR.png -d "${NDIR}/" &>/dev/null \
                && rnc_ok "PROFILE.QR.png recréé"
        fi
    else
        rnc_info "[dry-run] régénérerait les QR codes manquants (uSPOT/IPNS/SSSS/MULTIPASS/PROFILE)"
    fi

    return 0
}

################################################################################
# ZENCARD — ré-invocation de VISA.new.sh (déjà conçu pour être rejoué sans
# risque : fusion TW intégrée, pas de garde bloquante sur l'existant)
################################################################################

rnc_repair_zencard() {
    local EMAIL="$1"
    local ZDIR="${RNC_PLAYERS_ROOT}/${EMAIL}"
    local NDIR="${RNC_NOSTR_ROOT}/${EMAIL}"
    local DRY="${RNC_DRY_RUN:-0}"

    if [[ ! -d "${ZDIR}" ]]; then
        rnc_info "Pas de ZenCard pour ${EMAIL} (MULTIPASS seul) — rien à réparer"
        return 0
    fi

    if [[ ! -s "${ZDIR}/secret.june" || ! -s "${ZDIR}/.g1pub" ]]; then
        rnc_die "ZenCard de ${EMAIL} sans base récupérable (secret.june/.g1pub manquant(s)) — réparation manuelle requise"
        return 1
    fi

    # Ne JAMAIS ré-invoquer VISA.new.sh si la ZenCard est déjà complète :
    # VISA.new.sh envoie inconditionnellement un email "ZEN Card activated"
    # (RUNTIME/VISA.new.sh:716) et régénère cartes/QR — un bruit inutile et
    # perturbant pour l'utilisateur si rien ne manquait réellement.
    if [[ ${#RNC_ZENCARD_MISSING[@]} -eq 0 && "${FORCE:-0}" != "1" ]]; then
        rnc_ok "ZenCard déjà complète pour ${EMAIL} — VISA.new.sh non ré-invoqué"
        return 0
    fi

    echo -e "${RNC_CYAN}── Réparation ZenCard (ré-invocation de VISA.new.sh) ──${RNC_NC}"

    source "${ZDIR}/secret.june"   # SALT / PEPPER propres à la ZenCard (indépendants du DISCO MULTIPASS)
    local ZC_SALT="${SALT}" ZC_PEPPER="${PEPPER}"
    [[ -z "${ZC_SALT}" || -z "${ZC_PEPPER}" ]] && { rnc_die "secret.june illisible pour ${EMAIL}"; return 1; }

    local EXISTING_G1PUB
    EXISTING_G1PUB=$(cat "${ZDIR}/.g1pub" 2>/dev/null)
    if ! rnc_verify_duniter_pub "${ZC_SALT}" "${ZC_PEPPER}" "${EXISTING_G1PUB}" ""; then
        rnc_die "Abandon de la réparation ZenCard — le portefeuille G1 ne correspond pas à secret.june"
        return 1
    fi
    rnc_ok "G1PUB ZenCard vérifié (secret.june reproduit bien le portefeuille existant)"

    if [[ "${DRY}" == "1" ]]; then
        rnc_info "[dry-run] appellerait VISA.new.sh pour compléter la ZenCard de ${EMAIL}"
        return 0
    fi

    rnc_warn "VISA.new.sh envoie inconditionnellement un email \"ZEN Card activated\" à ${EMAIL} (RUNTIME/VISA.new.sh:716) — pas d'option pour le désactiver"

    local LG="fr" NPUB="" HEX="" LAT="0.00" LON="0.00"
    [[ -s "${NDIR}/LANG" ]] && LG=$(cat "${NDIR}/LANG")
    [[ -s "${NDIR}/NPUB" ]] && NPUB=$(cat "${NDIR}/NPUB")
    [[ -s "${NDIR}/HEX" ]] && HEX=$(cat "${NDIR}/HEX")
    [[ -s "${NDIR}/GPS" ]] && source "${NDIR}/GPS"

    if "${RNC_LIB_PATH}/../RUNTIME/VISA.new.sh" \
        "${ZC_SALT}" "${ZC_PEPPER}" "${EMAIL}" "UPlanet" "${LG}" "${LAT}" "${LON}" "${NPUB}" "${HEX}"; then
        rnc_ok "ZenCard complétée pour ${EMAIL}"
        return 0
    else
        rnc_die "VISA.new.sh a échoué pour ${EMAIL}"
        return 1
    fi
}
