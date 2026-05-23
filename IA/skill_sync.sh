#!/bin/bash
########################################################################
# skill_sync.sh — Synchronisation inter-node des skills (arbre de connaissance)
#
# Protocole :
#   PUBLISH  → calcule le hash de chaque skill local et le publie sur
#               le relay NOSTR local (kind 30078, d="skill:{name}") avec
#               le contenu Markdown et le hash SHA256.
#
#   RECEIVE  → interroge le relay pour les kind 30078 des stations voisines
#               et compare les hashes. Si conflit (même skill, hashes différents,
#               modifications des deux côtés) → envoie un DM d'alerte via
#               nostr_node_intercom.py aux contributeurs concernés.
#
#   MERGE    → applique la version distante (last-write-wins par défaut)
#               sauf si conflit → laisse l'humain trancher.
#
# Appelé par 20h12.process.sh (quotidien) ou manuellement.
# Usage : skill_sync.sh [publish|receive|merge|status]
########################################################################

MY_PATH="$(dirname "$(realpath "$0")")"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

SKILLS_DIR="$HOME/.zen/tmp/flashmem/skills"
STRFRY="$HOME/.zen/strfry/strfry"
INTERCOM="$MY_PATH/../tools/nostr_node_intercom.py"
MEMORY_MGR="$MY_PATH/memory_manager.py"
CONFLICT_LOG="$HOME/.zen/tmp/flashmem/skill_conflicts.log"
SYNC_STATE="$HOME/.zen/tmp/flashmem/skill_sync_state.json"

mkdir -p "$SKILLS_DIR"

_log() { echo "[$(date '+%H:%M:%S')] [skill_sync] $*"; }

## ─── Helpers ──────────────────────────────────────────────────────────────

_skill_hash_local() {
    local skill="$1"
    python3 "$MEMORY_MGR" skill-hash --skill "$skill" 2>/dev/null
}

_skill_content_local() {
    local skill="$1"
    local safe="${skill,,}"
    safe="${safe// /_}"
    safe="${safe//\//_}"
    cat "$SKILLS_DIR/${safe:0:40}.md" 2>/dev/null
}

_list_local_skills() {
    [ -d "$SKILLS_DIR" ] || return
    for f in "$SKILLS_DIR"/*.md; do
        [ -f "$f" ] && basename "$f" .md
    done
}

## ─── PUBLISH : publier les skills locaux sur le relay ────────────────────

cmd_publish() {
    [ -x "$STRFRY" ] || { _log "strfry introuvable — skip publish"; return 1; }
    [ -n "${NODE_NSEC:-}" ] || { _log "NODE_NSEC absent — skip publish"; return 1; }

    local published=0
    while IFS= read -r skill; do
        [ -z "$skill" ] && continue
        local content
        content=$(_skill_content_local "$skill")
        [ -z "$content" ] && continue
        local hash
        hash=$(_skill_hash_local "$skill")
        local ts
        ts=$(date -u +%s)

        # Construire l'event kind 30078 (parameterized replaceable)
        local event_json
        event_json=$(python3 - <<PYEOF
import json, hashlib, time
skill = ${skill@Q}
content = ${content@Q}
h = ${hash@Q}
ts = $ts
tags = [["d", f"skill:{skill}"], ["hash", h], ["t", "skill_sync"]]
ev = {"kind": 30078, "created_at": ts, "tags": tags, "content": content}
print(json.dumps(ev))
PYEOF
)
        [ -z "$event_json" ] && continue

        # Signer et publier via strfry (input sur stdin)
        echo "$event_json" | \
            NOSTR_NSEC="$NODE_NSEC" python3 -c "
import sys, json, os
sys.path.insert(0, '$HOME/.astro/lib/python3.$(python3 -c 'import sys; print(sys.version_info.minor)')/site-packages')
try:
    from nostr.key import PrivateKey
    nsec = os.environ['NOSTR_NSEC']
    pk = PrivateKey.from_nsec(nsec)
    ev = json.load(sys.stdin)
    ev['pubkey'] = pk.public_key.hex()
    import hashlib
    serial = json.dumps([0, ev['pubkey'], ev['created_at'], ev['kind'], ev['tags'], ev['content']], separators=(',',':'))
    ev['id'] = hashlib.sha256(serial.encode()).hexdigest()
    ev['sig'] = pk.sign_message_hash(bytes.fromhex(ev['id'])).hex()
    print(json.dumps(ev))
except Exception as e:
    print(f'ERR {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null | (cd "$(dirname "$STRFRY")" && ./strfry import --exit-on-dup) 2>/dev/null

        # Aussi upsert dans Qdrant station_skills
        python3 "$MEMORY_MGR" upsert-skill \
            --skill "$skill" \
            --content "$content" \
            --node-id "${IPFSNODEID:-local}" 2>/dev/null

        _log "📤 Published skill: $skill (hash ${hash:0:8})"
        published=$((published + 1))
    done < <(_list_local_skills)

    _log "✅ $published skill(s) publiés"
}

## ─── RECEIVE : comparer les skills distants, détecter conflits ──────────

cmd_receive() {
    [ -x "$STRFRY" ] || { _log "strfry introuvable — skip receive"; return 1; }

    local conflicts=0
    local merged=0
    local state="{}"
    [ -f "$SYNC_STATE" ] && state=$(cat "$SYNC_STATE")

    # Scanner les kind 30078 avec tag t=skill_sync du relay local
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local ev
        ev="$line"

        local remote_skill remote_hash remote_content remote_pubkey remote_ts
        remote_pubkey=$(echo "$ev" | jq -r '.pubkey // ""' 2>/dev/null)
        remote_ts=$(echo "$ev" | jq -r '.created_at // 0' 2>/dev/null)
        remote_skill=$(echo "$ev" | jq -r '.tags[]? | select(.[0]=="d") | .[1]' 2>/dev/null | sed 's/^skill://')
        remote_hash=$(echo "$ev" | jq -r '.tags[]? | select(.[0]=="hash") | .[1]' 2>/dev/null)
        remote_content=$(echo "$ev" | jq -r '.content // ""' 2>/dev/null)

        [ -z "$remote_skill" ] || [ -z "$remote_hash" ] && continue
        # Ignorer nos propres publications
        [ "$remote_pubkey" = "${NODE_G1PUB:-}" ] && continue

        local local_hash
        local_hash=$(_skill_hash_local "$remote_skill")

        # Cas 1 : skill inconnu localement → importer
        if [ -z "$local_hash" ]; then
            _import_skill "$remote_skill" "$remote_content"
            _log "⬇️  Import nouveau skill: $remote_skill depuis $remote_pubkey"
            merged=$((merged + 1))
            continue
        fi

        # Cas 2 : même hash → synchronisé
        [ "$local_hash" = "$remote_hash" ] && continue

        # Cas 3 : hashes différents → conflit potentiel
        local local_mtime remote_mtime
        local_mtime=$(stat -c %Y "$SKILLS_DIR/${remote_skill}.md" 2>/dev/null || echo 0)
        remote_mtime="$remote_ts"

        # Si la version distante est plus récente : merge silencieux
        if [ "$remote_mtime" -gt "$local_mtime" ]; then
            _import_skill "$remote_skill" "$remote_content"
            _log "⬇️  Merge skill (distante plus récente): $remote_skill"
            merged=$((merged + 1))
        else
            # Conflit réel : les deux ont modifié, alerter
            _log "⚠️  CONFLIT skill: $remote_skill (local ${local_hash:0:8} ≠ remote ${remote_hash:0:8})"
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] CONFLIT $remote_skill local=${local_hash:0:8} remote=${remote_hash:0:8} pubkey=${remote_pubkey:0:12}" \
                >> "$CONFLICT_LOG"
            _notify_conflict "$remote_skill" "$remote_pubkey" "$local_hash" "$remote_hash"
            conflicts=$((conflicts + 1))
        fi

    done < <(cd "$(dirname "$STRFRY")" && \
        ./strfry scan '{"kinds":[30078],"#t":["skill_sync"]}' 2>/dev/null)

    _log "✅ Receive terminé: $merged merge(s), $conflicts conflit(s)"
    [ $conflicts -gt 0 ] && return 1
    return 0
}

_import_skill() {
    local skill="$1" content="$2"
    local safe="${skill,,}"
    safe="${safe// /_}"
    safe="${safe//\//_}"
    local path="$SKILLS_DIR/${safe:0:40}.md"
    printf '%s\n' "$content" > "$path"
    # Upsert dans Qdrant
    python3 "$MEMORY_MGR" upsert-skill \
        --skill "$skill" --content "$content" 2>/dev/null
}

_notify_conflict() {
    local skill="$1" remote_pubkey="$2" local_hash="$3" remote_hash="$4"
    [ -x "$INTERCOM" ] || return
    [ -z "${NODE_NSEC:-}" ] && return

    local msg
    msg="⚠️ Conflit de connaissance sur le skill '${skill}' entre votre station et la nôtre.
Hash local  : ${local_hash:0:12}
Hash distant: ${remote_hash:0:12}
Répondez avec 'keep local' ou 'keep remote' pour trancher, ou éditez manuellement."

    # Envoyer au propriétaire distant via inter-NODE DM
    NOSTR_NSEC="$NODE_NSEC" python3 "$INTERCOM" send \
        --to-pubkey "$remote_pubkey" \
        --channel "skill_conflict" \
        --payload "{\"skill\":\"$skill\",\"local_hash\":\"$local_hash\",\"remote_hash\":\"$remote_hash\"}" \
        2>/dev/null || true

    _log "📨 Alerte conflit envoyée à ${remote_pubkey:0:12} pour skill '$skill'"
}

## ─── STATUS ──────────────────────────────────────────────────────────────

cmd_status() {
    local count=0
    while IFS= read -r skill; do
        [ -z "$skill" ] && continue
        local h
        h=$(_skill_hash_local "$skill")
        printf "  %-30s %s\n" "$skill" "${h:0:16}"
        count=$((count + 1))
    done < <(_list_local_skills)
    echo "Total: $count skill(s)"
    if [ -f "$CONFLICT_LOG" ]; then
        local nc
        nc=$(wc -l < "$CONFLICT_LOG")
        echo "Conflits en attente: $nc"
    fi
}

## ─── Main ────────────────────────────────────────────────────────────────

case "${1:-publish}" in
    publish)  cmd_publish ;;
    receive)  cmd_receive ;;
    merge)    cmd_publish && cmd_receive ;;
    status)   cmd_status ;;
    *)
        echo "Usage: $0 [publish|receive|merge|status]" >&2
        exit 1
        ;;
esac
