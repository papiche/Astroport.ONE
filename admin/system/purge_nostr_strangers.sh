#!/bin/bash
# purge_nostr_strangers.sh - Gestionnaire de purge du relay Nostr
# Usage: ./purge_nostr_strangers.sh [--list | --clean | --dry-run | --help]

STRFRY_DIR="$HOME/.zen/strfry"
STRFRY_BIN="$STRFRY_DIR/strfry"
NOSTR_DATA_DIR="$HOME/.zen/game/nostr"
SWARM_DIR="$HOME/.zen/tmp/swarm"
TEMP_ALLOWED=$(mktemp)
TEMP_AUTHORS=$(mktemp)

# Récupération HEX Capitaine pour protection
CURRENT_CAPTAIN=$(readlink -f ~/.zen/game/players/.current | rev | cut -d '/' -f 1 | rev)
CAPTAIN_HEX=$(cat "$HOME/.zen/game/nostr/${CURRENT_CAPTAIN}/HEX" 2>/dev/null 2>&1)

# --- FONCTIONS ---
get_authorized_keys() {
    find "$NOSTR_DATA_DIR" -name "HEX" -exec cat {} \; 2>/dev/null > "$TEMP_ALLOWED"
    find "$SWARM_DIR" -name "HEX" -exec cat {} \; 2>/dev/null >> "$TEMP_ALLOWED"
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

# 1. Collecte des données
get_authorized_keys
get_all_authors

PURGE_CANDIDATES=()
while read -r author; do
    if ! grep -q "^$author$" "$TEMP_ALLOWED" && [[ "$author" != "$CAPTAIN_HEX" ]]; then
        NAME=$(get_profile_name "$author")
        VOL=$(cd "$STRFRY_DIR" && ./strfry scan "{\"kinds\":[1],\"authors\":[\"$author\"],\"limit\":100}" 2>/dev/null | wc -l)
        PURGE_CANDIDATES+=("$author|$NAME|$VOL")
    fi
done < "$TEMP_AUTHORS"

# --- DISPATCHER ---
case "$1" in
    --list)
        printf "%-12s | %-20s | %-10s | %s\n" "PUBKEY" "NOM" "VOLUME" "STATUT"
        echo "----------------------------------------------------------------------------------"
        while read -r author; do
            NAME=$(get_profile_name "$author")
            VOL=$(cd "$STRFRY_DIR" && ./strfry scan "{\"kinds\":[1],\"authors\":[\"$author\"],\"limit\":100}" 2>/dev/null | wc -l)
            if grep -q "^$author$" "$TEMP_ALLOWED"; then STATUS="✅ AUTORISÉ"; 
            elif [[ "$author" == "$CAPTAIN_HEX" ]]; then STATUS="👑 CAPITAINE";
            else STATUS="❌ À PURGER"; fi
            printf "%-12s | %-20.20s | %-10s | %s\n" "${author:0:12}" "$NAME" "$VOL évéts" "$STATUS"
        done < "$TEMP_AUTHORS"
        ;;

    --dry-run)
        echo "🧪 Mode Dry-Run : comptes cibles :"
        for entry in "${PURGE_CANDIDATES[@]}"; do
            IFS='|' read -r hex name vol <<< "$entry"
            echo "   - $name ($hex) : $vol événements"
        done
        ;;

    --clean)
        echo "🔥 Mode CLEAN : Suppression automatique lancée..."
        for entry in "${PURGE_CANDIDATES[@]}"; do
            IFS='|' read -r hex name vol <<< "$entry"
            echo "🗑️  Purge de $name ($hex)..."
            cd "$STRFRY_DIR" && ./strfry delete --filter="{\"authors\": [\"$hex\"]}" 2>/dev/null
        done
        echo "✅ Opération terminée."
        ;;

    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo "  --list      Affiche l'état de tous les auteurs."
        echo "  --dry-run   Simulation."
        echo "  --clean     Purge TOUT le monde sans confirmation."
        ;;

    *)
        echo "--- Comptes candidats à la purge (${#PURGE_CANDIDATES[@]}) ---"
        for i in "${!PURGE_CANDIDATES[@]}"; do
            IFS='|' read -r hex name vol <<< "${PURGE_CANDIDATES[$i]}"
            echo "$((i+1))) $name (${hex:0:8}...) - $vol événements"
        done
        
        echo ""
        read -p "Entrez le numéro, 'all' pour tout purger, ou 'q' pour quitter : " choice
        
        if [[ "$choice" == "all" || "$choice" == "*" ]]; then
            echo "🔥 Suppression de TOUS les candidats..."
            for entry in "${PURGE_CANDIDATES[@]}"; do
                IFS='|' read -r hex name vol <<< "$entry"
                echo "🗑️  Purge de $name ($hex)..."
                cd "$STRFRY_DIR" && ./strfry delete --filter="{\"authors\": [\"$hex\"]}"
            done
            echo "✅ Purge complète."
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#PURGE_CANDIDATES[@]}" ]; then
            IFS='|' read -r hex name vol <<< "${PURGE_CANDIDATES[$((choice-1))]}"
            echo "🗑️  Suppression de $name ($hex)..."
            cd "$STRFRY_DIR" && ./strfry delete --filter="{\"authors\": [\"$hex\"]}"
            echo "✅ Fait."
        else
            echo "🛑 Annulé."
        fi
        ;;
esac

# Nettoyage
rm -f "$TEMP_ALLOWED" "$TEMP_AUTHORS"