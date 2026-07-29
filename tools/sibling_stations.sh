#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
#~ sibling_stations.sh
#~ Détecte les autres stations de la constellation appartenant au même
#~ Capitaine, via la convention d'adressage email+alias@domaine (RFC 5233) :
#~   base@domaine, base+node1@domaine, base+node2@domaine ...
#~ envoient tous leurs ẐEN à la même boîte mail (base@domaine) — le MULTIPASS
#~ dérivé de chaque adresse reste distinct (clef différente par nœud), mais
#~ elles appartiennent au même humain. La station tenant l'adresse SANS "+"
#~ est la station "maîtresse" : c'est là que la facture consolidée se compose
#~ (oc_admin.html / ZEN.INVOICE.sh).
#
# Source : ~/.zen/tmp/swarm/*/12345.json (champ "captain", cf. _12345.sh:857)
#          — données déjà diffusées par chaque station de la constellation,
#          aucune requête réseau supplémentaire nécessaire.
#
# Usage :
#   sibling_stations.sh base_email <email>        → email sans le "+alias"
#   sibling_stations.sh is_master [<email>]        → "true"/"false"
#   sibling_stations.sh list [<email>]             → une ligne par station sœur
#                                                      trouvée : "<IPFSNODEID>:<captain_email>"
#                                                      (inclut la station locale si concernée)
################################################################################

sibling_base_email() {
    local email="$1"
    local local_part="${email%%@*}" domain="${email#*@}"
    local base_local="${local_part%%+*}"
    echo "${base_local}@${domain}"
}

sibling_is_master() {
    local email="${1:-$CAPTAINEMAIL}"
    [[ "$email" == "$(sibling_base_email "$email")" ]] && echo "true" || echo "false"
}

## Liste "<IPFSNODEID>:<captain_email>" pour chaque station (locale incluse)
## dont le VRAI captain (lu dans son propre 12345.json, jamais supposé) partage
## la même base email que $1 (ou $CAPTAINEMAIL). Scan uniforme local + swarm :
## la station locale publie aussi son 12345.json sous ~/.zen/tmp/$IPFSNODEID/
## (cf. _12345.sh:857), donc pas de cas particulier à coder pour elle.
sibling_stations_list() {
    local my_email="${1:-$CAPTAINEMAIL}"
    [[ -z "$my_email" ]] && return 1
    local base
    base=$(sibling_base_email "$my_email")

    _matches_base() {
        local candidate="$1"
        [[ -z "$candidate" ]] && return 1
        [[ "$(sibling_base_email "$candidate")" == "$base" ]]
    }

    local f node_id captain
    for f in "$HOME"/.zen/tmp/"$IPFSNODEID"/12345.json "$HOME"/.zen/tmp/swarm/*/12345.json; do
        [[ -s "$f" ]] || continue
        node_id=$(basename "$(dirname "$f")")
        captain=$(jq -r '.captain // empty' "$f" 2>/dev/null)
        _matches_base "$captain" && echo "${node_id}:${captain}"
    done | sort -u
}

################################################################################
## CLI directe (si exécuté, pas sourcé)
################################################################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ## Un appelant qui sourcerait ce fichier après my.sh a déjà $IPFSNODEID/$CAPTAINEMAIL
    ## en environnement — mais un appel CLI direct (ex. routers/finance.py::/api/oc_admin/dues
    ## via subprocess) n'a jamais sourcé my.sh : sans ça, $IPFSNODEID est vide et
    ## sibling_stations_list ne trouve jamais la station locale elle-même (silencieusement).
    if [[ -z "${IPFSNODEID:-}" ]]; then
        MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        . "${MY_PATH}/my.sh" 2>/dev/null || true
    fi
    case "${1:-}" in
        base_email) shift; sibling_base_email "$1" ;;
        is_master)  shift; sibling_is_master "$1" ;;
        list)       shift; sibling_stations_list "$1" ;;
        *) echo "Usage: $0 {base_email <email>|is_master [<email>]|list [<email>]}" >&2; exit 1 ;;
    esac
fi
