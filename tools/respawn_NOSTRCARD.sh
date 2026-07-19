#!/bin/bash
################################################################################
# Script: respawn_NOSTRCARD.sh
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
# Détecte et répare un MULTIPASS / ZenCard "legacy" — créé avant que
# tools/make_NOSTRCARD.sh, RUNTIME/VISA.new.sh et RUNTIME/NOSTRCARD.refresh.sh
# n'évoluent vers leur stockage actuel : nostr/$EMAIL/* complet, .multipass.json,
# DID (NOSTR kind 30800), liaison NODE (home.station), bio narrative BRO
# (identity/*.md), et éventuellement clé ATOM4LOVE (LOVE).
#
# Reprend TOUJOURS les mêmes clefs (NSEC/NPUB/HEX/G1PUBNOSTR) : ce script ne
# régénère jamais l'identité, il ne fait que compléter ce qui manque autour
# d'elle. Voir tools/respawn_nostrcard_lib.sh pour le détail des garanties
# de sécurité (vérification du DISCO avant toute écriture, jamais de
# régénération SSSS partielle, jamais de recréation destructrice de fichiers
# déjà présents).
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"
. "${MY_PATH}/respawn_nostrcard_lib.sh"

usage() {
cat <<'EOF'
Usage: respawn_NOSTRCARD.sh [OPTIONS] <EMAIL>
       respawn_NOSTRCARD.sh --scan-all

Détecte et répare un MULTIPASS/ZenCard legacy (créé avant l'évolution du
stockage nostr/email/*, .multipass.json, DID, home.station, bio BRO,
ATOM4LOVE). Les clefs existantes (NSEC/NPUB/HEX/G1PUBNOSTR) ne sont JAMAIS
régénérées : seuls les artefacts manquants autour d'elles sont recréés.

Arguments:
  <EMAIL>                Email du MULTIPASS à auditer/réparer.

Modes:
  --scan-all, -a         Audite TOUS les comptes MULTIPASS locaux et liste
                          ceux qui sont legacy (aucune modification).
  --check                Audite <EMAIL> uniquement (aucune modification).
                          Code de sortie : 0=conforme, 1=legacy.
  --dry-run               Affiche ce qui serait fait, sans rien écrire.

Options de récupération du DISCO (SALT/PEPPER) :
  --salt SALT             SALT d'origine, si .secret.disco ET .multipass.json
  --pepper PEPPER         sont tous les deux absents (compte très ancien).
                          Sans ces options dans ce cas, seule la réparation
                          Tier 1 (sans DISCO) est effectuée.

Options de contexte (si perdues, ex: GPS jamais enregistré) :
  --lang LANG             Code langue à défaut (2 lettres, défaut: fr).
  --lat LATITUDE          Latitude UMAP si GPS absent (défaut: GPS station).
  --lon LONGITUDE         Longitude UMAP si GPS absent.

Activation ATOM4LOVE (optionnelle, jamais automatique — nécessite les
données de naissance/conception que ce compte n'a jamais fournies) :
  --birth-datetime DT      Date/heure de naissance (ISO 8601).
  --birth-place PLACE
  --birth-lat LAT
  --birth-lon LON
  --birth-weight WEIGHT
  --conception-datetime DT
  --conception-place PLACE
  --polarity POLARITY

Portée de la réparation :
  --skip-zencard          Ne touche pas à la ZenCard (~/.zen/game/players/).
  --force                 Rafraîchit aussi le DID/profil même si le compte
                          est déjà jugé conforme.

⚠️  Si des fichiers ZenCard manquent réellement, VISA.new.sh est ré-invoqué
    et envoie INCONDITIONNELLEMENT un email "ZEN Card activated" au titulaire
    (aucune option pour le désactiver) — sans effet si la ZenCard est déjà
    complète (VISA.new.sh n'est alors pas appelé).

Autres :
  --yes, -y               Ne pas demander de confirmation avant réparation.
  -h, --help               Affiche cette aide et quitte.

Ce que ce script NE touche JAMAIS :
  - L'identité NOSTR (NSEC/NPUB/HEX) : toujours reprise depuis .secret.nostr.
  - Les fichiers d'état économique/coopératif vivant : U.SOCIETY,
    U.SOCIETY.end, .lastpayment, secret.june (ZenCard), G1PRIME — propriété
    exclusive de RUNTIME/NOSTRCARD.refresh.sh.
  - Tout fichier déjà présent et non vide (sauf le DID, rafraîchi à chaque
    passage : did_manager_nostr.sh update gère lui-même création/mise à jour).

Exemples:
  respawn_NOSTRCARD.sh --scan-all
  respawn_NOSTRCARD.sh --check john.doe@example.com
  respawn_NOSTRCARD.sh john.doe@example.com --dry-run
  respawn_NOSTRCARD.sh john.doe@example.com
  respawn_NOSTRCARD.sh old.account@example.com --salt "mots-diceware-origine" --pepper "xxxx"
EOF
exit 1
}

################################################################################
# PARSING DES OPTIONS
################################################################################
MODE_SCAN_ALL=0
MODE_CHECK_ONLY=0
RNC_DRY_RUN=0
CLI_SALT=""
CLI_PEPPER=""
RNC_LANG=""
RNC_LAT=""
RNC_LON=""
SKIP_ZENCARD=0
FORCE=0
ASSUME_YES=0
BIRTH_DATETIME=""
BIRTH_PLACE=""
BIRTH_LAT=""
BIRTH_LON=""
BIRTH_WEIGHT=""
CONCEPTION_DATETIME=""
CONCEPTION_PLACE=""
POLARITY=""
EMAIL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --scan-all|-a) MODE_SCAN_ALL=1; shift ;;
        --check) MODE_CHECK_ONLY=1; shift ;;
        --dry-run) RNC_DRY_RUN=1; shift ;;
        --salt) CLI_SALT="$2"; shift 2 ;;
        --pepper) CLI_PEPPER="$2"; shift 2 ;;
        --lang) RNC_LANG="$2"; shift 2 ;;
        --lat) RNC_LAT="$2"; shift 2 ;;
        --lon) RNC_LON="$2"; shift 2 ;;
        --skip-zencard) SKIP_ZENCARD=1; shift ;;
        --force) FORCE=1; shift ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        --birth-datetime) BIRTH_DATETIME="$2"; shift 2 ;;
        --birth-place) BIRTH_PLACE="$2"; shift 2 ;;
        --birth-lat) BIRTH_LAT="$2"; shift 2 ;;
        --birth-lon) BIRTH_LON="$2"; shift 2 ;;
        --birth-weight) BIRTH_WEIGHT="$2"; shift 2 ;;
        --conception-datetime) CONCEPTION_DATETIME="$2"; shift 2 ;;
        --conception-place) CONCEPTION_PLACE="$2"; shift 2 ;;
        --polarity) POLARITY="$2"; shift 2 ;;
        -*)
            rnc_die "Option inconnue : $1"
            usage
            ;;
        *)
            if [[ -z "${EMAIL}" ]]; then
                EMAIL="$1"
            else
                rnc_die "Argument inattendu : $1"
                usage
            fi
            shift
            ;;
    esac
done

export RNC_DRY_RUN RNC_LANG RNC_LAT RNC_LON

################################################################################
# MODE --scan-all
################################################################################
if [[ "${MODE_SCAN_ALL}" == "1" ]]; then
    rnc_scan_all
    exit 0
fi

################################################################################
# VALIDATION
################################################################################
if [[ -z "${EMAIL}" ]]; then
    rnc_die "EMAIL requis (ou utilisez --scan-all)"
    usage
fi
EMAIL="${EMAIL,,}"

if [[ ! ${EMAIL} =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    rnc_die "Format d'email invalide : ${EMAIL}"
    exit 1
fi

if [[ ! -d "${RNC_NOSTR_ROOT}/${EMAIL}" ]]; then
    rnc_die "Aucun MULTIPASS local pour ${EMAIL} (${RNC_NOSTR_ROOT}/${EMAIL} introuvable)"
    rnc_info "Pour créer un NOUVEAU MULTIPASS, utilisez tools/make_NOSTRCARD.sh"
    exit 1
fi

################################################################################
# AUDIT
################################################################################
rnc_audit_human "${EMAIL}"
AUDIT_RC=$?

if [[ "${MODE_CHECK_ONLY}" == "1" ]]; then
    exit ${AUDIT_RC}
fi

if [[ ${AUDIT_RC} -eq 0 && "${FORCE}" != "1" ]]; then
    rnc_ok "Rien à réparer pour ${EMAIL} (utilisez --force pour rafraîchir quand même le DID/profil)"
    exit 0
fi

################################################################################
# CONFIRMATION
################################################################################
if [[ "${ASSUME_YES}" != "1" && "${RNC_DRY_RUN}" != "1" ]]; then
    echo ""
    read -r -p "Réparer le MULTIPASS/ZenCard de ${EMAIL} maintenant ? [y/N] " REPLY
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
        rnc_info "Abandon (aucune modification effectuée)"
        exit 0
    fi
fi

################################################################################
# TIER 1 (toujours possible : ne dépend que de l'identité déjà connue)
################################################################################
rnc_repair_tier1 "${EMAIL}" || { rnc_die "Échec de la réparation Tier 1 pour ${EMAIL}"; exit 1; }

################################################################################
# TIER 2 (nécessite le DISCO) — seulement si des artefacts Tier 2 manquent
################################################################################
PARTIAL=0
if [[ ${#RNC_TIER2_MISSING[@]} -gt 0 || "${FORCE}" == "1" ]]; then
    if rnc_recover_disco "${EMAIL}" "${CLI_SALT}" "${CLI_PEPPER}"; then
        if rnc_verify_identity "${EMAIL}" "${RNC_SALT}" "${RNC_PEPPER}"; then
            rnc_repair_tier2 "${EMAIL}" "${RNC_SALT}" "${RNC_PEPPER}" || PARTIAL=1
        else
            rnc_die "DISCO récupéré (${RNC_DISCO_SOURCE}) mais ne correspond pas à l'identité existante — Tier 2 ignoré"
            PARTIAL=1
        fi
    else
        rnc_warn "Tier 2 ignoré (DISCO introuvable) — SSSS/portefeuilles jumeaux/QR resteront manquants"
        rnc_info "Relancez avec --salt/--pepper si vous disposez du DISCO d'origine"
        PARTIAL=1
    fi
else
    rnc_info "Tier 2 déjà complet — rien à faire"
fi

################################################################################
# ZENCARD
################################################################################
if [[ "${SKIP_ZENCARD}" != "1" ]]; then
    rnc_repair_zencard "${EMAIL}" || PARTIAL=1
else
    rnc_info "ZenCard ignorée (--skip-zencard)"
fi

################################################################################
# ATOM4LOVE (optionnel, seulement si données de naissance fournies)
################################################################################
if [[ -n "${BIRTH_DATETIME}" ]]; then
    if [[ "${RNC_DRY_RUN}" == "1" ]]; then
        rnc_info "[dry-run] activerait ATOM4LOVE pour ${EMAIL}"
    elif [[ -x "${MY_PATH}/atom4love_activate.sh" ]]; then
        echo -e "${RNC_CYAN}── Activation ATOM4LOVE ──${RNC_NC}"
        "${MY_PATH}/atom4love_activate.sh" "${EMAIL}" \
            "${BIRTH_DATETIME}" "${BIRTH_PLACE}" "${BIRTH_LAT}" "${BIRTH_LON}" "${BIRTH_WEIGHT}" \
            "${CONCEPTION_DATETIME}" "${CONCEPTION_PLACE}" "${POLARITY}" \
            && rnc_ok "ATOM4LOVE activé" \
            || rnc_warn "Échec d'activation ATOM4LOVE (non bloquant)"
    fi
fi

################################################################################
# RÉ-AUDIT FINAL
################################################################################
echo ""
echo -e "${RNC_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RNC_NC}"
echo -e "${RNC_CYAN}  Résultat final${RNC_NC}"
echo -e "${RNC_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RNC_NC}"

if [[ "${RNC_DRY_RUN}" == "1" ]]; then
    rnc_info "Mode --dry-run : aucune modification n'a été effectuée"
    exit 0
fi

rnc_audit_human "${EMAIL}"
FINAL_RC=$?

if [[ ${FINAL_RC} -eq 0 && "${PARTIAL}" == "0" ]]; then
    rnc_ok "${EMAIL} est maintenant conforme au stockage actuel"
    exit 0
elif [[ "${PARTIAL}" == "1" ]]; then
    rnc_warn "${EMAIL} partiellement réparé — voir les avertissements ci-dessus"
    exit 2
else
    rnc_warn "${EMAIL} reste incomplet malgré la réparation — vérifiez les logs ci-dessus"
    exit 1
fi
