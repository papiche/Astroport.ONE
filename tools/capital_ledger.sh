#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
# capital_ledger.sh — Grand livre des apports en capital (multi-contributeurs)
#
# Stockage : sous-objet ".assets" du DID Node NOSTR (kind 30800, d=$IPFSNODEID,
# signé par la clé N² du node — voir node_did.sh), remplace l'ancien fichier
# purement local $HOME/.zen/game/capital_ledger.json : les apports en capital
# sont désormais vérifiables par le reste de la constellation (traçabilité
# CAPEX/ẑen — cf. mémo project_capex_node_did), pas seulement sur cette machine.
#
# $CAPITAL_LEDGER_FILE reste un chemin de VUE LOCALE (rafraîchie par
# capital_ledger_init() depuis le DID Node) — conservé pour compat avec les
# lectures directes en jq déjà en place (admin/dashboard.sh, UPLANET.official.sh),
# qui appellent toutes capital_ledger_init juste avant de lire le fichier.
#
# Un actif = { id, email, asset_type, label, value_zen, created_at, date,
#              depreciable, depreciation_weeks, amortized_zen,
#              last_depreciated_week, status }
#
# Verrouillage : porté par node_did_update() (flock par IPFSNODEID) pour toute
# lecture-modification-publication (contributions concurrentes + cron hebdo).
#
# À sourcer depuis UPLANET.official.sh / ZEN.ECONOMY.sh / admin/dashboard.sh :
#   . "${MY_PATH}/tools/capital_ledger.sh"   (ou chemin équivalent)
################################################################################

_CAPLEDGER_DIR="$(dirname "${BASH_SOURCE[0]}")"
_CAPLEDGER_DIR="$(cd "$_CAPLEDGER_DIR" && pwd)"
source "${_CAPLEDGER_DIR}/node_did.sh"

CAPITAL_LEDGER_FILE="$HOME/.zen/game/capital_ledger.json"
CAPITAL_LEDGER_DEDUP_WINDOW=300  # secondes — fenêtre anti double-soumission

## Rafraîchit la vue locale ($CAPITAL_LEDGER_FILE) depuis le DID Node.
## À appeler avant toute lecture directe en jq sur le fichier.
capital_ledger_init() {
    local content
    content=$(node_did_fetch "$IPFSNODEID")
    mkdir -p "$(dirname "$CAPITAL_LEDGER_FILE")" 2>/dev/null
    if [[ -n "$content" ]] && echo "$content" | jq -e '.assets' >/dev/null 2>&1; then
        echo "$content" > "$CAPITAL_LEDGER_FILE"
    else
        echo "$content" | jq -c '. + {assets: (.assets // [])}' 2>/dev/null > "$CAPITAL_LEDGER_FILE"
    fi
    [[ -s "$CAPITAL_LEDGER_FILE" ]] || echo '{"assets":[]}' > "$CAPITAL_LEDGER_FILE"
}

## Contenu fraîchement lu du DID Node, garanti avec une clé ".assets" (array).
_capital_ledger_content() {
    node_did_fetch "$IPFSNODEID" | jq -c '{assets: (.assets // [])}'
}

# capital_ledger_check_duplicate EMAIL ASSET_TYPE LABEL VALUE_ZEN
# Vérification rapide (pré-transfert) : affiche l'id d'un apport identique
# soumis il y a moins de CAPITAL_LEDGER_DEDUP_WINDOW secondes, sinon rien.
capital_ledger_check_duplicate() {
    local email="$1" asset_type="$2" label="$3" value_zen="$4"
    local now; now=$(date +%s)
    _capital_ledger_content | jq -r --arg e "$email" --arg t "$asset_type" --arg l "$label" \
          --argjson v "$value_zen" --argjson now "$now" --argjson win "$CAPITAL_LEDGER_DEDUP_WINDOW" '
        [.assets[] | select(.email==$e and .asset_type==$t and .label==$l
            and .value_zen==$v and ($now - .created_at) < $win)] | .[0].id // empty
    '
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

    local now; now=$(date +%s)
    local today; today=$(date +%Y-%m-%d)

    if [[ -n "$asset_id" ]]; then
        local exists
        exists=$(_capital_ledger_content | jq -r --arg id "$asset_id" '.assets[] | select(.id==$id) | .id')
        if [[ -z "$exists" ]]; then
            echo "ERREUR: asset_id '$asset_id' introuvable dans le ledger" >&2
            return 1
        fi

        if [[ "$force_mode" == "--force" ]]; then
            node_did_update "$IPFSNODEID" --arg id "$asset_id" --argjson value "$value_zen" --arg date "$today" '
                .assets = [(.assets // [])[] | if .id==$id then
                    (.value_zen=$value | .date=$date | .amortized_zen=0 | .last_depreciated_week="" | .status="active")
                else . end]
            ' >/dev/null || { echo "ERREUR: échec de publication du DID Node" >&2; return 1; }
        elif [[ "$force_mode" == "--add" ]]; then
            node_did_update "$IPFSNODEID" --arg id "$asset_id" --argjson add_value "$value_zen" '
                .assets = [(.assets // [])[] | if .id==$id then
                    (.value_zen=(.value_zen + $add_value) | .status="active")
                else . end]
            ' >/dev/null || { echo "ERREUR: échec de publication du DID Node" >&2; return 1; }
        fi

        echo "$asset_id"
        return 0
    fi

    local dup
    dup=$(capital_ledger_check_duplicate "$email" "$asset_type" "$label" "$value_zen")
    if [[ -n "$dup" ]]; then
        echo "ERREUR: apport identique déjà enregistré il y a moins de $((CAPITAL_LEDGER_DEDUP_WINDOW/60)) minutes (id=$dup)" >&2
        return 1
    fi

    local new_id
    new_id=$(echo -n "${email}:${asset_type}:${label}:${now}" | sha256sum | cut -c1-12)

    node_did_update "$IPFSNODEID" \
        --arg id "$new_id" --arg email "$email" --arg type "$asset_type" --arg label "$label" \
        --argjson value "$value_zen" --argjson dep "$depreciable" --argjson weeks "$depreciation_weeks" \
        --argjson now "$now" --arg date "$today" '
        .assets = ((.assets // []) + [{
            id: $id, email: $email, asset_type: $type, label: $label,
            value_zen: $value, created_at: $now, date: $date,
            depreciable: $dep, depreciation_weeks: $weeks,
            amortized_zen: 0, last_depreciated_week: "", status: "active"
        }])
    ' >/dev/null || { echo "ERREUR: échec de publication du DID Node" >&2; return 1; }

    echo "$new_id"
    return 0
}

# capital_ledger_total_for_email EMAIL → somme value_zen (Ẑen) de tous les actifs de cet email
capital_ledger_total_for_email() {
    local email="$1"
    _capital_ledger_content | jq -r --arg e "$email" '[.assets[] | select(.email==$e) | .value_zen] | add // 0'
}

# capital_ledger_pending_depreciation WEEK_KEY → JSON array des entrées à amortir cette semaine
capital_ledger_pending_depreciation() {
    local week_key="$1"
    _capital_ledger_content | jq -c --arg wk "$week_key" '
        [.assets[] | select(.depreciable==true and .status=="active" and .last_depreciated_week!=$wk)]
    '
}

# capital_ledger_mark_depreciated ID WEEK_KEY NEW_AMORTIZED_ZEN VALUE_ZEN
capital_ledger_mark_depreciated() {
    local id="$1" week_key="$2" new_amortized="$3" value_zen="$4"

    local status="active"
    if (( $(echo "$new_amortized >= $value_zen" | bc -l 2>/dev/null || echo 0) )); then
        status="fully_amortized"
    fi

    node_did_update "$IPFSNODEID" --arg id "$id" --arg wk "$week_key" --argjson amort "$new_amortized" --arg status "$status" '
        .assets = [(.assets // [])[] | if .id==$id then (.amortized_zen=$amort | .last_depreciated_week=$wk | .status=$status) else . end]
    ' >/dev/null
}
