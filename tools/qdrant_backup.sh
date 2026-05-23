#!/bin/bash
# qdrant_backup.sh — Backup Qdrant local, chiffré G1, publié IPFS + kind 30078 NOSTR
# Usage: ./qdrant_backup.sh
# Auteur: Fred (support@qo-op.com) — AGPL-3.0

MY_PATH="$(dirname "$(realpath "$0")")"
. "$MY_PATH/my.sh" 2>/dev/null || true

LOGFILE="${HOME}/.zen/tmp/IA.log"
mkdir -p "${HOME}/.zen/tmp"

_log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [qdrant_backup] $*" | tee -a "$LOGFILE"
}

# Vérifier Qdrant disponible
if ! curl -sf http://127.0.0.1:6333/healthz >/dev/null 2>&1; then
    exit 0
fi

# Variables essentielles
if [[ -z "$CAPTAING1PUB" ]]; then
    _log "ERROR: CAPTAING1PUB non défini (my.sh non sourcé ou station non initialisée)"
    exit 1
fi
if [[ -z "$CAPTAINEMAIL" ]]; then
    _log "ERROR: CAPTAINEMAIL non défini"
    exit 1
fi

BACKUP_TMP="$(mktemp -d /tmp/qdrant_backup_XXXXXX)"
trap 'rm -rf "$BACKUP_TMP"' EXIT

DATE_TAG="$(date -u +%Y%m%d)"
ENC_FILE="$BACKUP_TMP/qdrant_backup_${DATE_TAG}.enc"
EXPORT_JSON="$BACKUP_TMP/qdrant_export.json"
EXPORT_GZ="$BACKUP_TMP/qdrant_export.json.gz"

_log "Démarrage backup Qdrant → $BACKUP_TMP"

# Appel memory_manager.py backup
if ! python3 "$MY_PATH/../IA/memory_manager.py" backup --output "$EXPORT_JSON" 2>>"$LOGFILE"; then
    _log "ERROR: memory_manager.py backup a échoué"
    exit 1
fi

# Vérifier que le JSON fait > 10 octets
if [[ ! -f "$EXPORT_JSON" ]] || [[ $(stat -c%s "$EXPORT_JSON" 2>/dev/null || echo 0) -le 10 ]]; then
    _log "ERROR: export JSON absent ou trop petit (< 10 octets)"
    exit 1
fi

_log "Export JSON OK ($(stat -c%s "$EXPORT_JSON") octets)"

# Gzip
if ! gzip -9 "$EXPORT_JSON"; then
    _log "ERROR: gzip a échoué"
    exit 1
fi

if [[ ! -f "$EXPORT_GZ" ]]; then
    _log "ERROR: fichier gz introuvable après compression"
    exit 1
fi

# Chiffrement natools.py
if ! python3 "$MY_PATH/natools.py" encrypt -p "$CAPTAING1PUB" -i "$EXPORT_GZ" -o "$ENC_FILE" 2>>"$LOGFILE"; then
    _log "ERROR: chiffrement natools.py échoué"
    exit 1
fi

_log "Chiffrement OK → $ENC_FILE"

# Ajout IPFS
CID="$(ipfs add -q "$ENC_FILE" 2>>"$LOGFILE")"
if [[ -z "$CID" ]]; then
    _log "ERROR: ipfs add a échoué ou CID vide"
    exit 1
fi

_log "IPFS add OK → CID=$CID"

# Publication kind 30078 NOSTR
NODE_SHORT="${IPFSNODEID:0:12}"
D_TAG="qdrant-backup-${NODE_SHORT}"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CONTENT="{\"cid\":\"${CID}\",\"date\":\"${NOW_ISO}\",\"node\":\"${IPFSNODEID}\",\"domain\":\"${myDOMAIN}\"}"

NOSTR_INTERCOM="$MY_PATH/nostr_node_intercom.py"
if [[ -x "$NOSTR_INTERCOM" ]] || [[ -f "$NOSTR_INTERCOM" ]]; then
    python3 "$NOSTR_INTERCOM" publish \
        --kind 30078 \
        --tags "[[\"d\",\"${D_TAG}\"],[\"t\",\"qdrant_backup\"],[\"x\",\"${CID}\"]]" \
        --content "$CONTENT" 2>>"$LOGFILE" \
    && _log "Kind 30078 publié (d=$D_TAG, cid=$CID)" \
    || _log "WARN: publication NOSTR kind 30078 échouée (non fatale)"
else
    _log "WARN: nostr_node_intercom.py non trouvé — publication NOSTR skippée"
fi

# Garder seulement les 3 derniers backups IPFS (unpin les anciens via kind 30078)
STRFRY_BIN="${HOME}/.zen/strfry/strfry"
STRFRY_DIR="$(dirname "$STRFRY_BIN")"

if [[ -x "$STRFRY_BIN" ]]; then
    OLD_CIDS="$(
        cd "$STRFRY_DIR" && \
        ./strfry scan '{"kinds":[30078],"#d":["'"$D_TAG"'"]}' 2>/dev/null \
        | python3 -c "
import sys, json
events = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
        created = ev.get('created_at', 0)
        content_raw = ev.get('content', '{}')
        try:
            c = json.loads(content_raw)
            cid = c.get('cid', '')
        except Exception:
            cid = ''
        if cid:
            events.append((created, cid))
    except Exception:
        pass
events.sort(key=lambda x: x[0], reverse=True)
# Afficher les CID à partir du 4ème (index 3+)
for _, cid in events[3:]:
    print(cid)
" 2>/dev/null
    )"

    if [[ -n "$OLD_CIDS" ]]; then
        while IFS= read -r old_cid; do
            [[ -z "$old_cid" ]] && continue
            ipfs pin rm "/ipfs/$old_cid" 2>>"$LOGFILE" \
                && _log "Unpin ancien backup IPFS: $old_cid" \
                || _log "WARN: unpin /ipfs/$old_cid échoué (peut-être déjà absent)"
        done <<< "$OLD_CIDS"
    fi
else
    _log "WARN: strfry non trouvé à $STRFRY_BIN — nettoyage anciens backups skippé"
fi

_log "Backup Qdrant terminé avec succès. CID=$CID"
