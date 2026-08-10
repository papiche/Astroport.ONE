#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
# node_did.sh — DID NOSTR par station (kind 30800, d-tag = $IPFSNODEID)
#
# Portée : PAR NODE (chaque IPFSNODEID a son propre événement), distincte de :
#   - cooperative_config.sh : portée globale essaim (d-tag fixe "cooperative-config",
#     signée par la clé uplanet.G1)
#   - did_manager_nostr.sh : portée par-joueur (d-tag fixe "did", signée par la clé
#     NOSTR de chaque MULTIPASS)
#
# Signataire : la clé Nostr N² propre au NODE (~/.zen/game/secret.nostr, protocole
# Y-Level SSH→IPFS→Ğ1→NOSTR) — PAS la clé du Capitaine. Le DID Node survit donc à
# un changement de Capitaine.
#
# Publication : local uniquement (relay ws://127.0.0.1:7777) — comme
# cooperative_config.sh, backfill_constellation.sh propage l'événement à toute la
# constellation. Lecture : local uniquement (le backfill a déjà répliqué les DID
# des autres stations sur le relay local).
#
# Contenu de l'événement (content = JSON) — structure partagée entre plusieurs
# consommateurs (armateur_registry.sh écrit/lit .armateur, capital_ledger.sh
# écrira/lira .assets) :
#   { "armateur": {"name","email","address","siret"}, "assets": [...] }
#
# Usage (sourcé) :
#   source node_did.sh
#   content_json=$(node_did_fetch "$IPFSNODEID")          # "{}" si absent
#   node_did_publish "$IPFSNODEID" "$updated_content_json"
#   node_did_update "$IPFSNODEID" '.armateur = {...}'      # lecture-fusion-publication atomique
################################################################################

_NODE_DID_DIR="$(dirname "${BASH_SOURCE[0]}")"
_NODE_DID_DIR="$(cd "$_NODE_DID_DIR" && pwd)"

[[ -z "$IPFSNODEID" ]] && source "${_NODE_DID_DIR}/my.sh" 2>/dev/null

NODE_DID_KIND=30800
NODE_DID_KEYFILE="${NODE_DID_KEYFILE:-$HOME/.zen/game/secret.nostr}"
NODE_DID_LOCAL_RELAY="${myLocalRELAY:-ws://127.0.0.1:7777}"
NODE_DID_CACHE_DIR="${NODE_DID_CACHE_DIR:-$HOME/.zen/tmp/node_did_cache}"

NODE_DID_VERBOSE=${NODE_DID_VERBOSE:-0}
_node_did_log() { [[ "$NODE_DID_VERBOSE" == "1" ]] && echo "[VERBOSE] $*" >&2; }

mkdir -p "$NODE_DID_CACHE_DIR" 2>/dev/null

## Usage: _node_did_ensure_node_key
## secret.nostr n'est créé qu'au premier cycle de _12345.sh (station déjà démarrée
## au moins une fois) — si un appelant (ex: captain.sh à l'onboarding, avant tout
## démarrage) a besoin de publier un DID Node plus tôt, on dérive la clé à froid
## ici, avec la même chaîne que _12345.sh:236-249 (secret.june → keygen -t nostr),
## elle-même retombant sur secret.june dérivé de la clé SSH si besoin (Ylevel.sh).
_node_did_ensure_node_key() {
    [[ -s "$NODE_DID_KEYFILE" ]] && grep -q 'NSEC=' "$NODE_DID_KEYFILE" 2>/dev/null && return 0

    if [[ ! -s "$HOME/.zen/game/secret.june" ]]; then
        if [[ -s "$HOME/.ssh/id_ed25519" ]] && [[ -x "${_NODE_DID_DIR}/keygen" ]]; then
            _node_did_log "_node_did_ensure_node_key: secret.june absent, dérivation depuis SSH (cf. Ylevel.sh)"
            local sshash secret1 secret2
            sshash=$(sha512sum "$HOME/.ssh/id_ed25519" | cut -d ' ' -f1)
            secret1="${sshash:0:64}"; secret2="${sshash:64:64}"
            echo "SALT=$secret1; PEPPER=$secret2" > "$HOME/.zen/game/secret.june"
            chmod 600 "$HOME/.zen/game/secret.june"
        else
            echo "[ERROR] Ni secret.nostr ni secret.june ni ~/.ssh/id_ed25519 disponibles — impossible de dériver la clé NODE" >&2
            return 1
        fi
    fi

    [[ -x "${_NODE_DID_DIR}/keygen" ]] || { echo "[ERROR] tools/keygen introuvable" >&2; return 1; }
    local salt pepper cred npub hex nsec
    source "$HOME/.zen/game/secret.june"
    salt="$SALT"; pepper="$PEPPER"
    cred=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
    printf '%s\n%s\n' "$salt" "$pepper" > "$cred"
    npub=$("${_NODE_DID_DIR}/keygen" -t nostr -i "$cred" 2>/dev/null)
    nsec=$("${_NODE_DID_DIR}/keygen" -t nostr -s -i "$cred" 2>/dev/null)
    rm -f "$cred"
    [[ -x "${_NODE_DID_DIR}/nostr2hex.py" ]] && hex=$(python3 "${_NODE_DID_DIR}/nostr2hex.py" "$npub" 2>/dev/null)
    if [[ -z "$npub" || -z "$nsec" ]]; then
        echo "[ERROR] Dérivation à froid de la clé NODE échouée" >&2
        return 1
    fi
    echo "NSEC=$nsec; NPUB=$npub; HEX=$hex" > "$NODE_DID_KEYFILE"
    chmod 600 "$NODE_DID_KEYFILE"
    _node_did_log "_node_did_ensure_node_key: secret.nostr créé à froid (HEX=$hex)"
}

## Usage: node_did_fetch <IPFSNODEID>
## Interroge le relay local (kind 30800, d=<IPFSNODEID>, sans filtre --author :
## le d-tag est déjà spécifique au node, l'auteur légitime est celui qui a signé
## avec la clé N² de CE node). Retombe sur le cache local si le relay est mort.
## Imprime toujours un JSON valide ("{}" si rien trouvé).
node_did_fetch() {
    local node_id="$1"
    [[ -z "$node_id" ]] && { echo "{}"; return 1; }
    local cache_file="${NODE_DID_CACHE_DIR}/${node_id}.json"

    if [[ -x "${_NODE_DID_DIR}/nostr_get_events.sh" ]] && nc -z 127.0.0.1 7777 2>/dev/null; then
        local result content
        result=$("${_NODE_DID_DIR}/nostr_get_events.sh" \
            --kind "$NODE_DID_KIND" --tag-d "$node_id" --limit 1 --output json 2>/dev/null)
        if echo "$result" | jq -e '.' >/dev/null 2>&1; then
            content=$(echo "$result" | jq -r 'if type == "array" then .[0].content else .content end // empty' 2>/dev/null)
            if [[ -n "$content" ]] && echo "$content" | jq -e '.' >/dev/null 2>&1; then
                _node_did_log "node_did_fetch: DID trouvé pour $node_id"
                echo "$content" > "$cache_file" 2>/dev/null
                echo "$content"
                return 0
            fi
        fi
        _node_did_log "node_did_fetch: rien sur le relay local pour $node_id"
    else
        _node_did_log "node_did_fetch: relay local inatteignable, repli sur cache"
    fi

    if [[ -s "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    echo "{}"
}

## Usage: node_did_publish <IPFSNODEID> <content_json>
## Publie/remplace l'événement kind 30800 (d=<IPFSNODEID>) sur le relay local,
## signé par la clé N² du NODE. backfill_constellation.sh propage à la constellation.
node_did_publish() {
    local node_id="$1" content_json="$2"
    [[ -z "$node_id" ]] && { echo "[ERROR] IPFSNODEID requis" >&2; return 1; }
    if ! echo "$content_json" | jq empty 2>/dev/null; then
        echo "[ERROR] JSON invalide" >&2; return 1
    fi
    _node_did_ensure_node_key || return 1
    local tags_json
    tags_json="[[\"d\", \"$node_id\"], [\"t\", \"node-did\"], [\"t\", \"uplanet\"]]"

    local result
    result=$(python3 "${_NODE_DID_DIR}/nostr_send_note.py" \
        --keyfile "$NODE_DID_KEYFILE" \
        --content "$content_json" \
        --tags "$tags_json" \
        --kind "$NODE_DID_KIND" \
        --relays "$NODE_DID_LOCAL_RELAY" \
        --json 2>&1)

    if [[ $? -eq 0 ]]; then
        echo "$content_json" > "${NODE_DID_CACHE_DIR}/${node_id}.json" 2>/dev/null
        _node_did_log "node_did_publish: OK pour $node_id"
        return 0
    fi
    echo "[ERROR] Échec publication DID Node ($node_id): $result" >&2
    return 1
}

## Usage: node_did_update <IPFSNODEID> [jq_args...] <jq_filter>
## Cycle atomique lecture-fraîche → application du filtre jq → publication.
## Tous les arguments entre node_id et le dernier (le filtre) sont passés à jq
## tels quels — typiquement des paires "--arg nom valeur" pour éviter toute
## interpolation shell dans le filtre (valeurs avec guillemets/caractères spéciaux).
## Verrouillé par node_id pour éviter les courses entre écrivains concurrents
## (ex: capital_ledger_add appelé en même temps que armateur_registry_set).
##   node_did_update "$IPFSNODEID" --arg name "$name" '.armateur.name = $name'
node_did_update() {
    local node_id="$1"; shift
    [[ $# -lt 1 ]] && { echo "[ERROR] filtre jq requis" >&2; return 1; }
    local jq_filter="${@: -1}"          # dernier argument = le filtre
    local jq_args=("${@:1:$#-1}")       # tout le reste = arguments jq (--arg ...)
    [[ -z "$node_id" || -z "$jq_filter" ]] && { echo "[ERROR] node_id et filtre jq requis" >&2; return 1; }
    local lock_file="${NODE_DID_CACHE_DIR}/${node_id}.lock"
    mkdir -p "$NODE_DID_CACHE_DIR" 2>/dev/null

    (
        flock -x 200 || { echo "[ERROR] Verrou DID Node indisponible ($node_id)" >&2; exit 1; }
        local current updated
        current=$(node_did_fetch "$node_id")
        updated=$(echo "$current" | jq -c "${jq_args[@]}" "$jq_filter" 2>/dev/null)
        if [[ -z "$updated" ]] || ! echo "$updated" | jq empty 2>/dev/null; then
            echo "[ERROR] Filtre jq invalide ou résultat non-JSON" >&2
            exit 1
        fi
        node_did_publish "$node_id" "$updated"
    ) 200>"$lock_file"
}
