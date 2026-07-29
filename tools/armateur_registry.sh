#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
#~ armateur_registry.sh
#~ Registre des identités Armateur, indexé par IPFSNODEID (clé canonique d'une
#~ station physique) — chaque nœud de la constellation a son propre Armateur
#~ (hébergeur physique), potentiellement distinct du Capitaine qui l'administre.
#
# Un Capitaine qui héberge plusieurs stations sur son propre hub (cf. facture
# consolidée : "Hub Sagittarius" + plusieurs nœuds 2xPAF) enregistre ici
# l'identité de facturation de CHAQUE IPFSNODEID qu'il héberge, pas une seule
# fois globalement — ZEN.INVOICE.sh résout le payee ligne par ligne via ce
# registre, avec repli sur ARMATEUR_EMAIL de la station locale si un nœud n'y
# figure pas encore (cas simple : je m'auto-héberge).
#
# Stockage : $HOME/.zen/game/.armateur_registry.json
#   { "<IPFSNODEID>": {"name":"...", "email":"...", "address":"...", "siret":"..."}, ... }
#
# Usage :
#   armateur_registry.sh get <IPFSNODEID> [email|name|address|siret]   # défaut: JSON complet
#   armateur_registry.sh set <IPFSNODEID> <name> <email> <address> <siret>
#   armateur_registry.sh list
################################################################################

ARMATEUR_REGISTRY_FILE="${ARMATEUR_REGISTRY_FILE:-$HOME/.zen/game/.armateur_registry.json}"

_armateur_registry_ensure() {
    [[ -s "$ARMATEUR_REGISTRY_FILE" ]] || echo '{}' > "$ARMATEUR_REGISTRY_FILE"
}

## Usage: armateur_registry_get <IPFSNODEID> [field]
## Sans "field" : imprime l'objet JSON complet ("{}" si nœud inconnu).
## Avec "field" (name|email|address|siret) : imprime uniquement cette valeur (vide si absente).
armateur_registry_get() {
    local node_id="$1" field="${2:-}"
    _armateur_registry_ensure
    if [[ -z "$field" ]]; then
        jq -c --arg n "$node_id" '.[$n] // {}' "$ARMATEUR_REGISTRY_FILE" 2>/dev/null
    else
        jq -r --arg n "$node_id" --arg f "$field" '.[$n][$f] // empty' "$ARMATEUR_REGISTRY_FILE" 2>/dev/null
    fi
}

## Usage: armateur_registry_set <IPFSNODEID> <name> <email> <address> <siret>
armateur_registry_set() {
    local node_id="$1" name="$2" email="$3" address="${4:-}" siret="${5:-}"
    [[ -z "$node_id" || -z "$email" ]] && { echo "[ERROR] IPFSNODEID et email requis" >&2; return 1; }
    _armateur_registry_ensure
    local tmp
    tmp=$(mktemp)
    jq --arg n "$node_id" --arg name "$name" --arg email "$email" \
       --arg address "$address" --arg siret "$siret" \
       '.[$n] = {name:$name, email:$email, address:$address, siret:$siret}' \
       "$ARMATEUR_REGISTRY_FILE" > "$tmp" && mv "$tmp" "$ARMATEUR_REGISTRY_FILE"
    chmod 600 "$ARMATEUR_REGISTRY_FILE"
}

armateur_registry_list() {
    _armateur_registry_ensure
    jq -r 'to_entries[] | "\(.key) : \(.value.name // "?") <\(.value.email // "?")>"' "$ARMATEUR_REGISTRY_FILE" 2>/dev/null
}

################################################################################
## CLI directe (si exécuté, pas sourcé)
################################################################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        get)  shift; armateur_registry_get "$@" ;;
        set)  shift; armateur_registry_set "$@" ;;
        list) armateur_registry_list ;;
        *) echo "Usage: $0 {get <IPFSNODEID> [field]|set <IPFSNODEID> <name> <email> <address> <siret>|list}" >&2; exit 1 ;;
    esac
fi
