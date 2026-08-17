#!/bin/bash
# purge_nostr_strangers.sh - Gestionnaire de purge du relay Nostr
# Usage: ./purge_nostr_strangers.sh [--list | --list-json | --clean | --dry-run | --help]
#
# PERFORMANCE : toutes les données (profils, volumes, kinds par auteur, DID) sont
# récupérées via un nombre FIXE de scans `strfry scan` (un par type de donnée),
# jamais un scan par auteur — sur un relay à quelques centaines/milliers
# d'auteurs, un scan par auteur (× plusieurs par auteur) domine le temps
# d'exécution par le seul coût de fork/exec de `strfry`+`jq`. Le reste du script
# ne fait que des lookups en mémoire (tableaux associatifs bash).

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

STRFRY_DIR="$HOME/.zen/strfry"
STRFRY_BIN="$STRFRY_DIR/strfry"
NOSTR_DATA_DIR="$HOME/.zen/game/nostr"
SWARM_DIR="$HOME/.zen/tmp/swarm"
NODE_REGISTRY="$STRFRY_DIR/.known_nodes"
TEMP_ALLOWED=$(mktemp)
PROFILE_TSV=$(mktemp)
DID_TSV=$(mktemp)
EVENTS_TSV=$(mktemp)
trap 'rm -f "$TEMP_ALLOWED" "$PROFILE_TSV" "$DID_TSV" "$EVENTS_TSV"' EXIT

# Kinds jamais supprimables par cet outil, quel que soit l'auteur, quel que
# soit le tag de l'événement :
# - 30852 (Ğ1-N²) : source unique NIP-101 (relay.writePolicy.plugin/protected_kinds.sh).
#   Ce ledger n'est remanié que par un processus dédié de clôture comptable/nettoyage
#   d'anciens changements d'état de compte — jamais par une purge générique de "stranger".
# - 20078 : beacon éphémère ZICMAMA (atomic_projector.html), kind dédié à cet
#   unique usage (aucun autre client Nostr connu ne le réutilise).
NIP101_PROTECTED_KINDS_FILE="$HOME/.zen/workspace/NIP-101/relay.writePolicy.plugin/protected_kinds.sh"
if [[ -s "$NIP101_PROTECTED_KINDS_FILE" ]]; then
    . "$NIP101_PROTECTED_KINDS_FILE"
else
    PROTECTED_KINDS=(30852)
fi
ALWAYS_PROTECTED_KINDS=("${PROTECTED_KINDS[@]}" 20078)

# 30078 est le kind GÉNÉRIQUE NIP-78 ("application-specific data"), partagé par
# de nombreux clients/apps Nostr sans rapport avec UPlanet — le protéger par
# kind entier empêcherait à tort de nettoyer des "événements techniques"
# d'auteurs inconnus qui n'ont rien à voir avec ATOM4LOVE/ZICMAMA. On ne
# protège donc que les événements 30078 qui portent la signature ATOM4LOVE/
# ZICMAMA (tag d ou t = atom4love/zicmama_demo — cf. atomic.html d=atom4love,
# atomic_projector.html #t=zicmama_demo) ; tout le reste redevient purgeable.
# Cf. is_protected_event() plus bas — c'est la SEULE fonction qui doit changer
# si de nouveaux tags harmoniques apparaissent.

# Récupération HEX Capitaine pour protection
CURRENT_CAPTAIN=$(readlink -f ~/.zen/game/players/.current | rev | cut -d '/' -f 1 | rev)
CAPTAIN_HEX=$(cat "$HOME/.zen/game/nostr/${CURRENT_CAPTAIN}/HEX" 2>/dev/null 2>&1)

# HEX du NODE local : identité NOSTR propre à la station (secret.nostr / _12345.sh),
# distincte du Capitaine et des MULTIPASS. Ne doit jamais être purgée.
SELF_NODE_HEX=$(cat "$HOME/.zen/tmp/${IPFSNODEID}/HEX" 2>/dev/null)

# --- FONCTIONS ---
get_authorized_keys() {
    find "$NOSTR_DATA_DIR" -name "HEX" -exec cat {} \; 2>/dev/null > "$TEMP_ALLOWED"
    find "$SWARM_DIR" -name "HEX" -exec cat {} \; 2>/dev/null >> "$TEMP_ALLOWED"
    # HEX_LOVE : identité ATOM4LOVE/Ğ1-N² (.secret.love), DISTINCTE du MULTIPASS
    # HEX du même email — cf. NIP-101 filter/common.sh::get_love_email(). Doit
    # être traitée comme autorisée au même titre que le MULTIPASS qui l'héberge.
    find "$NOSTR_DATA_DIR" -name "HEX_LOVE" -exec cat {} \; 2>/dev/null >> "$TEMP_ALLOWED"
    [[ -n "$SELF_NODE_HEX" ]] && echo "$SELF_NODE_HEX" >> "$TEMP_ALLOWED"
    sort -u "$TEMP_ALLOWED" -o "$TEMP_ALLOWED"
}

# Historise les HEX des NODEs actuellement visibles (soi-même + swarm) afin de
# pouvoir reconnaître un NODE disparu même après nettoyage de son dossier swarm
# (NODE.refresh.sh purge ~/.zen/tmp/swarm/<IPFSNODEID>/ après 48h hors-ligne,
#  ce qui efface toute trace locale de sa correspondance HEX <-> IPFSNODEID).
update_node_registry() {
    touch "$NODE_REGISTRY"
    {
        [[ -n "$SELF_NODE_HEX" ]] && printf "%s\t%s (local)\n" "$SELF_NODE_HEX" "$IPFSNODEID"
        for f in "$SWARM_DIR"/*/HEX; do
            [[ -s "$f" ]] || continue
            nid=$(basename "$(dirname "$f")")
            printf "%s\t%s\n" "$(cat "$f")" "$nid"
        done
    } >> "$NODE_REGISTRY"
    # Dédoublonnage : on garde le premier label connu pour chaque HEX
    awk -F'\t' '!seen[$1]++' "$NODE_REGISTRY" > "${NODE_REGISTRY}.tmp" && mv "${NODE_REGISTRY}.tmp" "$NODE_REGISTRY"
}

# Protège un compte qui a un DID valide ET un abonnement coopératif actif, DANS
# LA MÊME CONSTELLATION UPLANET (comparaison metadata.uplanet == $UPLANETG1PUB) :
# - contractStatus doit être un statut réellement actif (ni vide, ni "new_user"
#   [gabarit non finalisé], ni "account_deactivated").
# - Si le fichier local U.SOCIETY.end de cet email est accessible (compte réellement
#   hébergé par CETTE station) et est expiré, la protection ne s'applique pas :
#   contractStatus seul ne périme jamais automatiquement (cf. did_manager_nostr.sh),
#   c'est U.SOCIETY.end qui porte la validité temporelle réelle. Ce fichier n'est
#   pas accessible pour un membre d'une AUTRE station de la constellation (donnée
#   privée, non publiée dans le swarm) : on fait alors confiance au DID Nostr,
#   conformément au modèle "Nostr = source de vérité".
# Lit DID_MAP (rempli une seule fois en amont via un scan groupé, cf. plus bas).
has_valid_did_subscription() {
    local hex="$1"
    local b64="${DID_MAP[$hex]:-}"
    [[ -z "$b64" ]] && return 1
    local raw
    raw=$(printf '%s' "$b64" | base64 -d 2>/dev/null)
    [[ -z "$raw" ]] && return 1

    local uplanet status email
    IFS=$'\t' read -r uplanet status email < <(printf '%s' "$raw" | \
        jq -r '[(.metadata.uplanet // ""), (.metadata.contractStatus // ""), (.metadata.email // "")] | @tsv' 2>/dev/null)

    [[ -z "$UPLANETG1PUB" || "$uplanet" != "$UPLANETG1PUB" ]] && return 1
    case "$status" in
        ""|"new_user"|"account_deactivated") return 1 ;;
    esac

    if [[ -n "$email" && -s "$HOME/.zen/game/nostr/${email}/U.SOCIETY.end" ]]; then
        local uend now_s end_s
        uend=$(cat "$HOME/.zen/game/nostr/${email}/U.SOCIETY.end" 2>/dev/null)
        if [[ -n "$uend" ]]; then
            now_s=$(date +%s)
            end_s=$(date --date="$uend" +%s 2>/dev/null)
            [[ -n "$end_s" && "$now_s" -gt "$end_s" ]] && return 1
        fi
    fi
    return 0
}

# Décide si UN événement (pas un auteur, pas un kind entier) doit être conservé
# quoi qu'il arrive. Seule fonction à modifier si de nouveaux kinds/tags
# protégés apparaissent — utilisée à la fois par l'agrégation en masse et par
# le filet de sécurité de purge_author().
is_protected_event() {
    local kind="$1" dtag="$2" harmonic="$3" pk
    for pk in "${ALWAYS_PROTECTED_KINDS[@]}"; do
        [[ "$kind" == "$pk" ]] && return 0
    done
    if [[ "$kind" == "30078" ]]; then
        case "$dtag" in atom4love|zicmama_demo) return 0 ;; esac
        [[ "$harmonic" == "1" ]] && return 0
    fi
    return 1
}

# jq réutilisé pour extraire (kind, id, tag d, marqueur harmonique t) d'un event.
JQ_EVENT_TAG_FIELDS='.kind, .id, ((.tags[]? | select(.[0]=="d") | .[1]) // ""), (if ([.tags[]? | select(.[0]=="t" and (.[1]=="zicmama_demo" or .[1]=="atom4love"))] | length) > 0 then "1" else "0" end)'

# Suppression sûre : ne supprime QUE les événements non protégés de cet auteur,
# par id explicite (jamais par kind entier — un même kind 30078 peut mélanger
# du harmonique protégé et du technique purgeable pour un même auteur).
purge_author() {
    local hex="$1" label="$2"
    local ids="${AUTHOR_PURGEABLE_IDS[$hex]:-}"
    local prot="${AUTHOR_PROTECTED_COUNT[$hex]:-0}"

    # Filet de sécurité : cet auteur vient forcément de la liste des profils
    # (kind 0), donc le scan groupé doit avoir trouvé AU MOINS un événement
    # pour lui. S'il n'a rien trouvé du tout (ni purgeable, ni protégé), on
    # re-scanne cet auteur seul avant de conclure à "rien à purger" — évite de
    # protéger par erreur suite à un aléa du scan groupé plutôt qu'à une
    # authentique absence d'événements purgeables.
    if [[ -z "$ids" && "$prot" -eq 0 ]]; then
        local resync kind id dtag harmonic
        resync=$(cd "$STRFRY_DIR" && ./strfry scan "{\"authors\":[\"$hex\"]}" 2>/dev/null | jq -r "[${JQ_EVENT_TAG_FIELDS}] | @tsv" 2>/dev/null)
        while IFS=$'\t' read -r kind id dtag harmonic; do
            [[ -z "$id" ]] && continue
            if is_protected_event "$kind" "$dtag" "$harmonic"; then
                prot=$((prot + 1))
            else
                ids+="$id "
            fi
        done <<< "$resync"
    fi

    if [[ -z "$ids" ]]; then
        echo "⏭️  $label ($hex) : uniquement des événements protégés (Ğ1-N²/harmoniques) — ignoré."
        return
    fi

    local ids_json
    ids_json=$(printf '%s\n' $ids | jq -R -s -c 'split("\n") | map(select(length>0))')
    cd "$STRFRY_DIR" && ./strfry delete --filter="{\"ids\": ${ids_json}}" 2>/dev/null
    [[ "$prot" -gt 0 ]] && echo "   ℹ️  $prot événement(s) protégé(s) conservé(s) (Ğ1-N²/harmoniques)."
}

# 1. Collecte des données — un nombre FIXE de scans strfry, jamais un par auteur
get_authorized_keys
update_node_registry

cd "$STRFRY_DIR" || exit 1

# Profils (kind 0) : source de la liste des auteurs + leur nom affichable
./strfry scan '{"kinds":[0]}' 2>/dev/null | \
    jq -r '[.pubkey, (try (.content | fromjson | (.name // .display_name // "Sans nom")) catch "Sans nom")] | @tsv' \
    > "$PROFILE_TSV" 2>/dev/null

declare -A PROFILE_MAP
AUTHORS=()
while IFS=$'\t' read -r pk name; do
    [[ -z "$pk" ]] && continue
    [[ -z "${PROFILE_MAP[$pk]:-}" ]] && AUTHORS+=("$pk")
    PROFILE_MAP["$pk"]="$name"
done < "$PROFILE_TSV"

# DID (kind 30800, d=did) : contenu complet en base64 (décodé à la demande, pour
# les seuls auteurs qui en ont besoin — cf. has_valid_did_subscription)
./strfry scan '{"kinds":[30800],"#d":["did"]}' 2>/dev/null | \
    jq -r '[.pubkey, (.content | @base64)] | @tsv' > "$DID_TSV" 2>/dev/null

declare -A DID_MAP
while IFS=$'\t' read -r pk b64; do
    [[ -z "$pk" ]] && continue
    DID_MAP["$pk"]="$b64"
done < "$DID_TSV"

# Volume + classification protégé/purgeable par événement, pour les seuls
# auteurs ci-dessus (kind:0 holders) — un unique scan filtré par la liste
# d'auteurs, pas un scan par auteur.
declare -A VOL_MAP AUTHOR_PURGEABLE_IDS AUTHOR_PROTECTED_COUNT
if [[ "${#AUTHORS[@]}" -gt 0 ]]; then
    AUTHORS_JSON=$(printf '%s\n' "${AUTHORS[@]}" | jq -R -s -c 'split("\n") | map(select(length>0))')
    ./strfry scan "{\"authors\": ${AUTHORS_JSON}}" 2>/dev/null | \
        jq -r "[.pubkey, ${JQ_EVENT_TAG_FIELDS}] | @tsv" > "$EVENTS_TSV" 2>/dev/null

    while IFS=$'\t' read -r pk kind id dtag harmonic; do
        [[ -z "$pk" ]] && continue
        VOL_MAP["$pk"]=$(( ${VOL_MAP[$pk]:-0} + 1 ))
        if is_protected_event "$kind" "$dtag" "$harmonic"; then
            AUTHOR_PROTECTED_COUNT["$pk"]=$(( ${AUTHOR_PROTECTED_COUNT[$pk]:-0} + 1 ))
        else
            AUTHOR_PURGEABLE_IDS["$pk"]+="$id "
        fi
    done < "$EVENTS_TSV"
fi

declare -A ALLOWED_SET
while read -r h; do
    [[ -n "$h" ]] && ALLOWED_SET["$h"]=1
done < "$TEMP_ALLOWED"

declare -A NODE_MAP
while IFS=$'\t' read -r h label; do
    [[ -n "$h" ]] && NODE_MAP["$h"]="$label"
done < "$NODE_REGISTRY"

# 2. Classification — un seul passage, tout en mémoire
declare -A AUTHOR_STATUS AUTHOR_DISPLAY_NAME
PURGE_CANDIDATES=()
for author in "${AUTHORS[@]}"; do
    NODE_LABEL="${NODE_MAP[$author]:-}"
    VOL="${VOL_MAP[$author]:-0}"
    NAME="${PROFILE_MAP[$author]:-Sans nom}"

    if [[ "$author" == "$SELF_NODE_HEX" ]]; then
        AUTHOR_DISPLAY_NAME[$author]="$IPFSNODEID"; AUTHOR_STATUS[$author]="🛰️  NODE (local)"
    elif [[ -n "${ALLOWED_SET[$author]:-}" && -n "$NODE_LABEL" ]]; then
        AUTHOR_DISPLAY_NAME[$author]="$NODE_LABEL"; AUTHOR_STATUS[$author]="🌐 NODE ACTIF"
    elif [[ -n "${ALLOWED_SET[$author]:-}" ]]; then
        AUTHOR_DISPLAY_NAME[$author]="$NAME"; AUTHOR_STATUS[$author]="✅ AUTORISÉ"
    elif [[ "$author" == "$CAPTAIN_HEX" ]]; then
        AUTHOR_DISPLAY_NAME[$author]="$NAME"; AUTHOR_STATUS[$author]="👑 CAPITAINE"
    elif [[ -n "$NODE_LABEL" ]]; then
        AUTHOR_DISPLAY_NAME[$author]="$NODE_LABEL"; AUTHOR_STATUS[$author]="🛰️  NODE DISPARU"
        PURGE_CANDIDATES+=("$author|$NODE_LABEL|$VOL|NODE")
    elif has_valid_did_subscription "$author"; then
        AUTHOR_DISPLAY_NAME[$author]="$NAME"; AUTHOR_STATUS[$author]="📜 DID+ABONNEMENT VALIDE"
    else
        AUTHOR_DISPLAY_NAME[$author]="$NAME"; AUTHOR_STATUS[$author]="❌ À PURGER"
        PURGE_CANDIDATES+=("$author|$NAME|$VOL|PLAYER")
    fi
done

# --- DISPATCHER ---
case "$1" in
    --list)
        printf "%-12s | %-20s | %-10s | %s\n" "PUBKEY" "NOM" "VOLUME" "STATUT"
        echo "----------------------------------------------------------------------------------"
        for author in "${AUTHORS[@]}"; do
            printf "%-12s | %-20.20s | %-10s | %s\n" "${author:0:12}" "${AUTHOR_DISPLAY_NAME[$author]}" \
                "${VOL_MAP[$author]:-0} évéts" "${AUTHOR_STATUS[$author]}"
        done
        ;;

    --list-json)
        # Sortie machine-readable — même schéma de classification que --list,
        # avec un booléen purge_candidate par ligne (cf. PURGE_CANDIDATES) pour
        # que l'appelant (nostr_admin.html, via UPassport) n'ait pas à reparser
        # les emojis de AUTHOR_STATUS. Convention jq -cn par ligne + jq -s .
        # (cf. oc2uplanet.sh::_sync_rows) plutôt qu'une construction O(n²).
        for author in "${AUTHORS[@]}"; do
            is_candidate=false
            for c in "${PURGE_CANDIDATES[@]}"; do
                [[ "${c%%|*}" == "$author" ]] && is_candidate=true && break
            done
            jq -cn --arg hex "$author" --arg name "${AUTHOR_DISPLAY_NAME[$author]}" \
                --arg status "${AUTHOR_STATUS[$author]}" --argjson vol "${VOL_MAP[$author]:-0}" \
                --argjson candidate "$is_candidate" \
                '{hex:$hex, name:$name, status:$status, volume:$vol, purge_candidate:$candidate}'
        done | jq -s '{authors: ., candidate_count: (map(select(.purge_candidate)) | length)}'
        ;;

    --dry-run)
        echo "🧪 Mode Dry-Run : comptes cibles :"
        for entry in "${PURGE_CANDIDATES[@]}"; do
            IFS='|' read -r hex label vol category <<< "$entry"
            if [[ "$category" == "NODE" ]]; then
                echo "   - 🛰️  NODE disparu : $label ($hex) : $vol événements"
            else
                echo "   - $label ($hex) : $vol événements"
            fi
        done
        ;;

    --clean)
        echo "🔥 Mode CLEAN : Suppression automatique lancée..."
        for entry in "${PURGE_CANDIDATES[@]}"; do
            IFS='|' read -r hex label vol category <<< "$entry"
            [[ "$category" == "NODE" ]] && echo "🗑️  Purge du NODE disparu $label ($hex)..." || echo "🗑️  Purge de $label ($hex)..."
            purge_author "$hex" "$label"
        done
        echo "✅ Opération terminée."
        ;;

    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo "  --list      Affiche l'état de tous les auteurs (MULTIPASS et NODEs)."
        echo "  --list-json Idem --list, en JSON (authors[], candidate_count) — usage web/admin."
        echo "  --dry-run   Simulation."
        echo "  --clean     Purge TOUT le monde sans confirmation."
        echo ""
        echo "Statuts (--list) :"
        echo "  🛰️  NODE (local)    identité NOSTR de cette station (protégée)"
        echo "  🌐 NODE ACTIF       autre station de la constellation, toujours vue dans le swarm"
        echo "  🛰️  NODE DISPARU    ancienne station, absente du swarm depuis >48h (candidate purge)"
        echo "  ✅ AUTORISÉ         MULTIPASS connu (local ou swarm)"
        echo "  👑 CAPITAINE        MULTIPASS du capitaine (protégé)"
        echo "  📜 DID+ABONNEMENT VALIDE  DID (kind 30800) de la même constellation UPLANET"
        echo "                            avec un abonnement coopératif actif (protégé)"
        echo "  ❌ À PURGER         MULTIPASS inconnu"
        echo ""
        echo "Événements jamais supprimés, quel que soit l'auteur :"
        echo "  kind ${ALWAYS_PROTECTED_KINDS[*]}  toujours protégés (Ğ1-N² / beacon ZICMAMA)"
        echo "  kind 30078 avec tag d/t = atom4love ou zicmama_demo  (harmoniques ATOM4LOVE/ZICMAMA)"
        echo "  → les AUTRES événements kind 30078 (usage générique NIP-78 par d'autres clients"
        echo "    Nostr) restent purgeables normalement."
        ;;

    *)
        echo "--- Comptes candidats à la purge (${#PURGE_CANDIDATES[@]}) ---"
        for i in "${!PURGE_CANDIDATES[@]}"; do
            IFS='|' read -r hex label vol category <<< "${PURGE_CANDIDATES[$i]}"
            if [[ "$category" == "NODE" ]]; then
                echo "$((i+1))) 🛰️  NODE $label (${hex:0:8}...) - $vol événements"
            else
                echo "$((i+1))) $label (${hex:0:8}...) - $vol événements"
            fi
        done

        echo ""
        read -r -p "Entrez le numéro, 'all' pour tout purger, ou 'q' pour quitter : " choice

        if [[ "$choice" == "all" || "$choice" == "*" ]]; then
            echo "🔥 Suppression de TOUS les candidats..."
            for entry in "${PURGE_CANDIDATES[@]}"; do
                IFS='|' read -r hex label vol category <<< "$entry"
                echo "🗑️  Purge de $label ($hex)..."
                purge_author "$hex" "$label"
            done
            echo "✅ Purge complète."
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#PURGE_CANDIDATES[@]}" ]; then
            IFS='|' read -r hex label vol category <<< "${PURGE_CANDIDATES[$((choice-1))]}"
            echo "🗑️  Suppression de $label ($hex)..."
            purge_author "$hex" "$label"
            echo "✅ Fait."
        else
            echo "🛑 Annulé."
        fi
        ;;
esac
