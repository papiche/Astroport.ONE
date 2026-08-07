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

# 1. Collecte des données
get_authorized_keys
get_all_authors
update_node_registry

PURGE_CANDIDATES=()
while read -r author; do
    if ! grep -q "^$author$" "$TEMP_ALLOWED" && [[ "$author" != "$CAPTAIN_HEX" ]] && [[ "$author" != "$SELF_NODE_HEX" ]]; then
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
            cd "$STRFRY_DIR" && ./strfry delete --filter="{\"authors\": [\"$hex\"]}" 2>/dev/null
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
        echo "  ❌ À PURGER         MULTIPASS inconnu"
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
                cd "$STRFRY_DIR" && ./strfry delete --filter="{\"authors\": [\"$hex\"]}"
            done
            echo "✅ Purge complète."
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#PURGE_CANDIDATES[@]}" ]; then
            IFS='|' read -r hex label vol category <<< "${PURGE_CANDIDATES[$((choice-1))]}"
            echo "🗑️  Suppression de $label ($hex)..."
            cd "$STRFRY_DIR" && ./strfry delete --filter="{\"authors\": [\"$hex\"]}"
            echo "✅ Fait."
        else
            echo "🛑 Annulé."
        fi
        ;;
esac

# Nettoyage
rm -f "$TEMP_ALLOWED" "$TEMP_AUTHORS"
