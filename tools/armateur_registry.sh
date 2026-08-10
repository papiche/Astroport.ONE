#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
#~ armateur_registry.sh
#~ Identité Armateur d'une station, indexée par IPFSNODEID — chaque nœud de la
#~ constellation a son propre Armateur (hébergeur physique), potentiellement
#~ distinct du Capitaine qui l'administre.
#
# Stockage : sous-objet ".armateur" du DID Node NOSTR (kind 30800, d=$IPFSNODEID,
# signé par la clé N² du node — voir node_did.sh). Publié sur le relay local,
# propagé à la constellation par backfill_constellation.sh : n'importe quelle
# station peut donc vérifier l'identité Armateur d'un node distant, contrairement
# à l'ancien fichier local $HOME/.zen/game/.armateur_registry.json (retiré).
#
# Un Capitaine qui héberge plusieurs stations sur son propre hub (cf. facture
# consolidée : "Hub Sagittarius" + plusieurs nœuds 2xPAF) publie ainsi l'identité
# de facturation de CHAQUE IPFSNODEID qu'il héberge sur le DID de CE node — pas
# une seule fois globalement. ZEN.INVOICE.sh résout le payee ligne par ligne via
# ce registre, avec repli sur ARMATEUR_EMAIL de la station locale si un nœud n'y
# figure pas encore (cas simple : je m'auto-héberge).
#
# Usage :
#   armateur_registry.sh get <IPFSNODEID> [email|name|address|siret]   # défaut: JSON complet
#   armateur_registry.sh set <IPFSNODEID> <name> <email> <address> <siret>
#   armateur_registry.sh list                                          # nodes connus en cache local
################################################################################

_ARMATEUR_DIR="$(dirname "${BASH_SOURCE[0]}")"
_ARMATEUR_DIR="$(cd "$_ARMATEUR_DIR" && pwd)"
source "${_ARMATEUR_DIR}/node_did.sh"

## Usage: armateur_registry_get <IPFSNODEID> [field]
## Sans "field" : imprime l'objet JSON complet ("{}" si nœud inconnu/DID absent).
## Avec "field" (name|email|address|siret) : imprime uniquement cette valeur (vide si absente).
armateur_registry_get() {
    local node_id="$1" field="${2:-}"
    [[ -z "$node_id" ]] && { echo "{}"; return 1; }
    local content
    content=$(node_did_fetch "$node_id")
    if [[ -z "$field" ]]; then
        echo "$content" | jq -c '.armateur // {}' 2>/dev/null
    else
        echo "$content" | jq -r --arg f "$field" '.armateur[$f] // empty' 2>/dev/null
    fi
}

## Usage: armateur_registry_set <IPFSNODEID> <name> <email> <address> <siret>
## Publie (ou met à jour) l'identité Armateur sur le DID Node — ne modifie que
## le sous-objet ".armateur", préserve le reste (ex: ".assets" du capital_ledger).
armateur_registry_set() {
    local node_id="$1" name="$2" email="$3" address="${4:-}" siret="${5:-}"
    [[ -z "$node_id" || -z "$email" ]] && { echo "[ERROR] IPFSNODEID et email requis" >&2; return 1; }
    node_did_update "$node_id" \
        --arg name "$name" --arg email "$email" --arg address "$address" --arg siret "$siret" \
        '.armateur = {name:$name, email:$email, address:$address, siret:$siret}'
}

## Usage: armateur_registry_list
## Liste les nodes présents dans le CACHE LOCAL (dernières lectures/écritures via
## node_did_fetch/publish) — pas une requête exhaustive au relay. Suffisant pour
## un usage CLI/diagnostic ; pour un besoin exhaustif, interroger le relay
## directement (nostr_get_events.sh --kind 30800).
armateur_registry_list() {
    local f
    for f in "${NODE_DID_CACHE_DIR}"/*.json; do
        [[ -f "$f" ]] || continue
        local node_id name email
        node_id=$(basename "$f" .json)
        name=$(jq -r '.armateur.name // "?"' "$f" 2>/dev/null)
        email=$(jq -r '.armateur.email // empty' "$f" 2>/dev/null)
        [[ -n "$email" ]] && echo "$node_id : $name <$email>"
    done
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
