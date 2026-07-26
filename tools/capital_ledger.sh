#!/bin/bash
################################################################################
# capital_ledger.sh — Grand livre des apports en capital (multi-contributeurs)
#
# Fichier: ~/.zen/game/capital_ledger.json
# Un actif = { id, email, asset_type, label, value_zen, created_at, date,
#              depreciable, depreciation_weeks, amortized_zen,
#              last_depreciated_week, status }
#
# Verrouillage: flock sur capital_ledger.json.lock pour toute
# lecture-modification-écriture (contributions concurrentes + cron hebdo).
#
# À sourcer depuis UPLANET.official.sh / ZEN.ECONOMY.sh / admin/dashboard.sh :
#   . "${MY_PATH}/tools/capital_ledger.sh"   (ou chemin équivalent)
################################################################################

CAPITAL_LEDGER_FILE="$HOME/.zen/game/capital_ledger.json"
CAPITAL_LEDGER_LOCK="${CAPITAL_LEDGER_FILE}.lock"
CAPITAL_LEDGER_DEDUP_WINDOW=300  # secondes — fenêtre anti double-soumission

capital_ledger_init() {
    if [[ ! -s "$CAPITAL_LEDGER_FILE" ]]; then
        mkdir -p "$(dirname "$CAPITAL_LEDGER_FILE")"
        echo '{"assets":[]}' > "$CAPITAL_LEDGER_FILE"
    fi
}

# capital_ledger_check_duplicate EMAIL ASSET_TYPE LABEL VALUE_ZEN
# Vérification rapide (pré-transfert) : affiche l'id d'un apport identique
# soumis il y a moins de CAPITAL_LEDGER_DEDUP_WINDOW secondes, sinon rien.
capital_ledger_check_duplicate() {
    local email="$1" asset_type="$2" label="$3" value_zen="$4"
    capital_ledger_init
    local now; now=$(date +%s)
    jq -r --arg e "$email" --arg t "$asset_type" --arg l "$label" \
          --argjson v "$value_zen" --argjson now "$now" --argjson win "$CAPITAL_LEDGER_DEDUP_WINDOW" '
        [.assets[] | select(.email==$e and .asset_type==$t and .label==$l
            and .value_zen==$v and ($now - .created_at) < $win)] | .[0].id // empty
    ' "$CAPITAL_LEDGER_FILE"
}

# capital_ledger_add EMAIL ASSET_TYPE LABEL VALUE_ZEN DEPRECIABLE(true|false) DEPRECIATION_WEEKS [ASSET_ID] [FORCE_MODE]
# À appeler APRÈS un transfert réussi (jamais avant : on ne veut pas d'entrée
# fantôme si le virement échoue).
#
# Si ASSET_ID est fourni, l'entrée doit déjà exister et FORCE_MODE doit valoir
# "--force" (écrase value_zen, réinitialise l'amortissement à zéro et redémarre
# la date) ou "--add" (cumule VALUE_ZEN dans value_zen existant, conserve la
# date/l'amortissement déjà acquis, repasse en "active" si elle était épuisée).
# Sinon (pas d'ASSET_ID) : crée une nouvelle entrée, sauf doublon détecté dans
# la fenêtre CAPITAL_LEDGER_DEDUP_WINDOW.
#
# Affiche l'id créé/mis à jour sur stdout ; retour 1 + message sur stderr en cas d'erreur.
capital_ledger_add() {
    local email="$1" asset_type="$2" label="$3" value_zen="$4"
    local depreciable="$5" depreciation_weeks="${6:-0}" asset_id="${7:-}" force_mode="${8:-}"

    capital_ledger_init
    local now; now=$(date +%s)
    local today; today=$(date +%Y-%m-%d)

    exec 201>"$CAPITAL_LEDGER_LOCK"
    flock -x 201

    if [[ -n "$asset_id" ]]; then
        local exists
        exists=$(jq -r --arg id "$asset_id" '.assets[] | select(.id==$id) | .id' "$CAPITAL_LEDGER_FILE")
        if [[ -z "$exists" ]]; then
            echo "ERREUR: asset_id '$asset_id' introuvable dans le ledger" >&2
            flock -u 201
            return 1
        fi

        if [[ "$force_mode" == "--force" ]]; then
            jq --arg id "$asset_id" --argjson value "$value_zen" --arg date "$today" '
                .assets = [.assets[] | if .id==$id then
                    (.value_zen=$value | .date=$date | .amortized_zen=0 | .last_depreciated_week="" | .status="active")
                else . end]
            ' "$CAPITAL_LEDGER_FILE" > "${CAPITAL_LEDGER_FILE}.tmp" && mv "${CAPITAL_LEDGER_FILE}.tmp" "$CAPITAL_LEDGER_FILE"
        elif [[ "$force_mode" == "--add" ]]; then
            jq --arg id "$asset_id" --argjson add_value "$value_zen" '
                .assets = [.assets[] | if .id==$id then
                    (.value_zen=(.value_zen + $add_value) | .status="active")
                else . end]
            ' "$CAPITAL_LEDGER_FILE" > "${CAPITAL_LEDGER_FILE}.tmp" && mv "${CAPITAL_LEDGER_FILE}.tmp" "$CAPITAL_LEDGER_FILE"
        fi

        echo "$asset_id"
        flock -u 201
        return 0
    fi

    local dup
    dup=$(jq -r --arg e "$email" --arg t "$asset_type" --arg l "$label" \
             --argjson v "$value_zen" --argjson now "$now" --argjson win "$CAPITAL_LEDGER_DEDUP_WINDOW" '
        [.assets[] | select(.email==$e and .asset_type==$t and .label==$l
            and .value_zen==$v and ($now - .created_at) < $win)] | .[0].id // empty
    ' "$CAPITAL_LEDGER_FILE")

    if [[ -n "$dup" ]]; then
        echo "ERREUR: apport identique déjà enregistré il y a moins de $((CAPITAL_LEDGER_DEDUP_WINDOW/60)) minutes (id=$dup)" >&2
        flock -u 201
        return 1
    fi

    local new_id
    new_id=$(echo -n "${email}:${asset_type}:${label}:${now}" | sha256sum | cut -c1-12)

    jq --arg id "$new_id" --arg email "$email" --arg type "$asset_type" --arg label "$label" \
       --argjson value "$value_zen" --argjson dep "$depreciable" --argjson weeks "$depreciation_weeks" \
       --argjson now "$now" --arg date "$today" '
        .assets += [{
            id: $id, email: $email, asset_type: $type, label: $label,
            value_zen: $value, created_at: $now, date: $date,
            depreciable: $dep, depreciation_weeks: $weeks,
            amortized_zen: 0, last_depreciated_week: "", status: "active"
        }]
    ' "$CAPITAL_LEDGER_FILE" > "${CAPITAL_LEDGER_FILE}.tmp" && mv "${CAPITAL_LEDGER_FILE}.tmp" "$CAPITAL_LEDGER_FILE"

    echo "$new_id"
    flock -u 201
    return 0
}

# capital_ledger_total_for_email EMAIL → somme value_zen (Ẑen) de tous les actifs de cet email
capital_ledger_total_for_email() {
    local email="$1"
    capital_ledger_init
    jq -r --arg e "$email" '[.assets[] | select(.email==$e) | .value_zen] | add // 0' "$CAPITAL_LEDGER_FILE"
}

# capital_ledger_pending_depreciation WEEK_KEY → JSON array des entrées à amortir cette semaine
capital_ledger_pending_depreciation() {
    local week_key="$1"
    capital_ledger_init
    jq -c --arg wk "$week_key" '
        [.assets[] | select(.depreciable==true and .status=="active" and .last_depreciated_week!=$wk)]
    ' "$CAPITAL_LEDGER_FILE"
}

# capital_ledger_mark_depreciated ID WEEK_KEY NEW_AMORTIZED_ZEN VALUE_ZEN
capital_ledger_mark_depreciated() {
    local id="$1" week_key="$2" new_amortized="$3" value_zen="$4"

    exec 202>"$CAPITAL_LEDGER_LOCK"
    flock -x 202

    local status="active"
    if (( $(echo "$new_amortized >= $value_zen" | bc -l 2>/dev/null || echo 0) )); then
        status="fully_amortized"
    fi

    jq --arg id "$id" --arg wk "$week_key" --argjson amort "$new_amortized" --arg status "$status" '
        .assets = [.assets[] | if .id==$id then (.amortized_zen=$amort | .last_depreciated_week=$wk | .status=$status) else . end]
    ' "$CAPITAL_LEDGER_FILE" > "${CAPITAL_LEDGER_FILE}.tmp" && mv "${CAPITAL_LEDGER_FILE}.tmp" "$CAPITAL_LEDGER_FILE"

    flock -u 202
}
