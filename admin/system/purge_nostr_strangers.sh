#!/bin/bash
# purge_nostr_strangers.sh - Gestionnaire de purge du relay Nostr
# Usage: ./purge_nostr_strangers.sh [--list | --clean | --dry-run | --help]

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

STRFRY_DIR="$HOME/.zen/strfry"
STRFRY_BIN="$STRFRY_DIR/strfry"
NOSTR_DATA_DIR="$HOME/.zen/game/nostr"
SWARM_DIR="$HOME/.zen/tmp/swarm"
NODE_REGISTRY="$STRFRY_DIR/.known_nodes"
TEMP_ALLOWED=$(mktemp)
TEMP_AUTHORS=$(mktemp)

# Kinds jamais supprimables par cet outil, quel que soit l'auteur.
# - 30852 (Ğ1-N²) : source unique NIP-101 (relay.writePolicy.plugin/protected_kinds.sh).
#   Ce ledger n'est remanié que par un processus dédié de clôture comptable/nettoyage
#   d'anciens changements d'état de compte — jamais par une purge générique de "stranger".
# - 30078/20078 : harmoniques ATOM4LOVE/ZICMAMA (atomic.html, atomic_projector.html).
#   Kind 30078 est déjà gardé en écriture par AUTHORIZED_APPS/a4l_proof
#   (cooperative_config.sh) ; 20078 est le beacon éphémère live event. Une
#   mauvaise classification (clé .secret.love, visiteur "nobody" live) ne doit
#   jamais entraîner leur suppression.
NIP101_PROTECTED_KINDS_FILE="$HOME/.zen/workspace/NIP-101/relay.writePolicy.plugin/protected_kinds.sh"
if [[ -s "$NIP101_PROTECTED_KINDS_FILE" ]]; then
    . "$NIP101_PROTECTED_KINDS_FILE"
else
    PROTECTED_KINDS=(30852)
fi
EXTRA_PROTECTED_KINDS=(30078 20078)
ALL_PROTECTED_KINDS=("${PROTECTED_KINDS[@]}" "${EXTRA_PROTECTED_KINDS[@]}")

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

get_all_authors() {
    cd "$STRFRY_DIR" || exit 1
    ./strfry scan '{"kinds":[0]}' 2>/dev/null | jq -r '.pubkey' | sort -u > "$TEMP_AUTHORS"
}

get_profile_name() {
    local hex="$1"
    cd "$STRFRY_DIR" && ./strfry scan "{\"kinds\":[0],\"authors\":[\"$hex\"],\"limit\":1}" 2>/dev/null | \
    jq -r '.content | fromjson | .name // .display_name // "Sans nom"' 2>/dev/null | head -1
}

get_event_volume() {
    local hex="$1"
    cd "$STRFRY_DIR" && ./strfry scan "{\"authors\":[\"$hex\"],\"limit\":1000}" 2>/dev/null | wc -l
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

get_node_label() {
    local hex="$1"
    grep -P "^${hex}\t" "$NODE_REGISTRY" 2>/dev/null | cut -f2 | head -1
}

# DID (kind 30800, d=did) le plus récent publié par cet auteur, content JSON parsé.
# Le DID est la source de vérité (cf. DID.manager.sh) : un event backfillé sur ce
# relay depuis une AUTRE station de la même constellation UPLANET est tout aussi
# valide qu'un DID local.
get_did_content() {
    local hex="$1"
    cd "$STRFRY_DIR" && ./strfry scan "{\"kinds\":[30800],\"authors\":[\"$hex\"],\"#d\":[\"did\"],\"limit\":1}" 2>/dev/null \
        | jq -r '.content' 2>/dev/null | jq -c '.' 2>/dev/null
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
has_valid_did_subscription() {
    local hex="$1"
    local did_json
    did_json=$(get_did_content "$hex")
    [[ -z "$did_json" || "$did_json" == "null" ]] && return 1

    local did_uplanet
    did_uplanet=$(echo "$did_json" | jq -r '.metadata.uplanet // empty' 2>/dev/null)
    [[ -z "$UPLANETG1PUB" || "$did_uplanet" != "$UPLANETG1PUB" ]] && return 1

    local status
    status=$(echo "$did_json" | jq -r '.metadata.contractStatus // empty' 2>/dev/null)
    case "$status" in
        ""|"new_user"|"account_deactivated") return 1 ;;
    esac

    local email uend now_s end_s
    email=$(echo "$did_json" | jq -r '.metadata.email // empty' 2>/dev/null)
    if [[ -n "$email" && -s "$HOME/.zen/game/nostr/${email}/U.SOCIETY.end" ]]; then
        uend=$(cat "$HOME/.zen/game/nostr/${email}/U.SOCIETY.end" 2>/dev/null)
        if [[ -n "$uend" ]]; then
            now_s=$(date +%s)
            end_s=$(date --date="$uend" +%s 2>/dev/null)
            [[ -n "$end_s" && "$now_s" -gt "$end_s" ]] && return 1
        fi
    fi
    return 0
}

# Kinds réellement publiés par cet auteur (liste triée unique)
get_author_kinds() {
    local hex="$1"
    cd "$STRFRY_DIR" && ./strfry scan "{\"authors\":[\"$hex\"]}" 2>/dev/null | jq -r '.kind' | sort -un
}

# Kinds de cet auteur MOINS les kinds protégés (Ğ1-N²/harmoniques) — c'est la
# SEULE liste de kinds jamais transmise à `strfry delete`, jamais "tous les
# événements de l'auteur" (cf. commentaire ALL_PROTECTED_KINDS en tête de fichier).
get_purgeable_kinds_csv() {
    local hex="$1"
    local k csv=()
    for k in $(get_author_kinds "$hex"); do
        local protected=false pk
        for pk in "${ALL_PROTECTED_KINDS[@]}"; do
            [[ "$k" == "$pk" ]] && protected=true && break
        done
        $protected || csv+=("$k")
    done
    local IFS=,
    echo "${csv[*]}"
}

get_protected_event_count() {
    local hex="$1"
    local IFS=,
    local kinds_csv="${ALL_PROTECTED_KINDS[*]}"
    cd "$STRFRY_DIR" && ./strfry scan "{\"authors\":[\"$hex\"],\"kinds\":[$kinds_csv]}" 2>/dev/null | wc -l
}

# Suppression sûre : ne supprime QUE les kinds non protégés de cet auteur.
# Si tous ses événements sont d'un kind protégé (Ğ1-N²/harmoniques), ne fait rien.
purge_author() {
    local hex="$1" label="$2"
    local kinds_csv=$(get_purgeable_kinds_csv "$hex")
    if [[ -z "$kinds_csv" ]]; then
        echo "⏭️  $label ($hex) : uniquement des événements protégés (Ğ1-N²/harmoniques) — ignoré."
        return
    fi
    cd "$STRFRY_DIR" && ./strfry delete --filter="{\"authors\": [\"$hex\"], \"kinds\": [$kinds_csv]}" 2>/dev/null
    local prot=$(get_protected_event_count "$hex")
    [[ "$prot" -gt 0 ]] && echo "   ℹ️  $prot événement(s) protégé(s) conservé(s) (Ğ1-N²/harmoniques)."
}

# 1. Collecte des données
get_authorized_keys
get_all_authors
update_node_registry

PURGE_CANDIDATES=()
while read -r author; do
    if ! grep -q "^$author$" "$TEMP_ALLOWED" && [[ "$author" != "$CAPTAIN_HEX" ]] && [[ "$author" != "$SELF_NODE_HEX" ]] \
        && ! has_valid_did_subscription "$author"; then
        NODE_LABEL=$(get_node_label "$author")
        VOL=$(get_event_volume "$author")
        if [[ -n "$NODE_LABEL" ]]; then
            PURGE_CANDIDATES+=("$author|$NODE_LABEL|$VOL|NODE")
        else
            NAME=$(get_profile_name "$author")
            PURGE_CANDIDATES+=("$author|$NAME|$VOL|PLAYER")
        fi
    fi
done < "$TEMP_AUTHORS"

# --- DISPATCHER ---
case "$1" in
    --list)
        printf "%-12s | %-20s | %-10s | %s\n" "PUBKEY" "NOM" "VOLUME" "STATUT"
        echo "----------------------------------------------------------------------------------"
        while read -r author; do
            NODE_LABEL=$(get_node_label "$author")
            VOL=$(get_event_volume "$author")
            if [[ "$author" == "$SELF_NODE_HEX" ]]; then
                NAME="$IPFSNODEID"; STATUS="🛰️  NODE (local)"
            elif grep -q "^$author$" "$TEMP_ALLOWED" && [[ -n "$NODE_LABEL" ]]; then
                NAME="$NODE_LABEL"; STATUS="🌐 NODE ACTIF"
            elif grep -q "^$author$" "$TEMP_ALLOWED"; then
                NAME=$(get_profile_name "$author"); STATUS="✅ AUTORISÉ"
            elif [[ "$author" == "$CAPTAIN_HEX" ]]; then
                NAME=$(get_profile_name "$author"); STATUS="👑 CAPITAINE"
            elif [[ -n "$NODE_LABEL" ]]; then
                NAME="$NODE_LABEL"; STATUS="🛰️  NODE DISPARU"
            elif has_valid_did_subscription "$author"; then
                NAME=$(get_profile_name "$author"); STATUS="📜 DID+ABONNEMENT VALIDE"
            else
                NAME=$(get_profile_name "$author"); STATUS="❌ À PURGER"
            fi
            printf "%-12s | %-20.20s | %-10s | %s\n" "${author:0:12}" "$NAME" "$VOL évéts" "$STATUS"
        done < "$TEMP_AUTHORS"
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
        echo "Kinds jamais supprimés, quel que soit l'auteur (${ALL_PROTECTED_KINDS[*]}) :"
        echo "  30852  Ğ1-N² (ledger LOVE) — remaniement réservé à un processus dédié de bilan comptable"
        echo "  30078  harmoniques ATOM4LOVE/ZICMAMA (atomic.html)"
        echo "  20078  beacon éphémère ZICMAMA (atomic_projector.html)"
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
        read -p "Entrez le numéro, 'all' pour tout purger, ou 'q' pour quitter : " choice

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

# Nettoyage
rm -f "$TEMP_ALLOWED" "$TEMP_AUTHORS"
