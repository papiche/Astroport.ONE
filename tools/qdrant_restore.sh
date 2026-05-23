#!/bin/bash
# qdrant_restore.sh — Restaure Qdrant depuis le dernier backup chiffré (IPFS + kind 30078)
# Usage: ./qdrant_restore.sh
# Auteur: Fred (support@qo-op.com) — AGPL-3.0

MY_PATH="$(dirname "$(realpath "$0")")"
. "$MY_PATH/my.sh" 2>/dev/null || true

LOGFILE="${HOME}/.zen/tmp/IA.log"
mkdir -p "${HOME}/.zen/tmp"

_log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [qdrant_restore] $*" | tee -a "$LOGFILE"
}

# Variables essentielles
if [[ -z "$CAPTAINEMAIL" ]]; then
    _log "ERROR: CAPTAINEMAIL non défini (my.sh non sourcé ou station non initialisée)"
    exit 1
fi
if [[ -z "$IPFSNODEID" ]]; then
    _log "ERROR: IPFSNODEID non défini"
    exit 1
fi

DUNIKEY="${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/.secret.dunikey"
if [[ ! -f "$DUNIKEY" ]]; then
    _log "ERROR: clé dunikey introuvable: $DUNIKEY"
    exit 1
fi

RESTORE_TMP="$(mktemp -d /tmp/qdrant_restore_XXXXXX)"
trap 'rm -rf "$RESTORE_TMP"' EXIT

NODE_SHORT="${IPFSNODEID:0:12}"
D_TAG="qdrant-backup-${NODE_SHORT}"

_log "Recherche du dernier backup kind 30078 (d=$D_TAG)"

# Lire les events kind 30078 depuis strfry local
STRFRY_BIN="${HOME}/.zen/strfry/strfry"
STRFRY_DIR="$(dirname "$STRFRY_BIN")"

if [[ ! -x "$STRFRY_BIN" ]]; then
    _log "ERROR: strfry non trouvé à $STRFRY_BIN"
    exit 1
fi

CID="$(
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
# Trier par date décroissante et prendre le plus récent
events.sort(key=lambda x: x[0], reverse=True)
if events:
    print(events[0][1])
" 2>/dev/null
)"

if [[ -z "$CID" ]]; then
    _log "ERROR: aucun CID trouvé dans les events kind 30078 pour d=$D_TAG"
    exit 1
fi

_log "CID trouvé: $CID"

# Récupérer le fichier chiffré depuis IPFS
BACKUP_ENC="$RESTORE_TMP/backup.enc"
_log "Téléchargement IPFS /ipfs/$CID"
if ! ipfs get -o "$BACKUP_ENC" "/ipfs/$CID" 2>>"$LOGFILE"; then
    _log "ERROR: ipfs get /ipfs/$CID a échoué"
    exit 1
fi

if [[ ! -f "$BACKUP_ENC" ]]; then
    _log "ERROR: fichier chiffré absent après ipfs get"
    exit 1
fi

_log "Fichier chiffré récupéré ($(stat -c%s "$BACKUP_ENC") octets)"

# Déchiffrement natools.py
BACKUP_GZ="$RESTORE_TMP/backup.json.gz"
if ! python3 "$MY_PATH/natools.py" decrypt -f pubsec \
        -i "$BACKUP_ENC" \
        -k "$DUNIKEY" \
        -o "$BACKUP_GZ" 2>>"$LOGFILE"; then
    _log "ERROR: déchiffrement natools.py échoué"
    exit 1
fi

if [[ ! -f "$BACKUP_GZ" ]]; then
    _log "ERROR: fichier gz absent après déchiffrement"
    exit 1
fi

_log "Déchiffrement OK"

# Décompression
BACKUP_JSON="$RESTORE_TMP/backup.json"
if ! gunzip -c "$BACKUP_GZ" > "$BACKUP_JSON" 2>>"$LOGFILE"; then
    _log "ERROR: gunzip a échoué"
    exit 1
fi

if [[ ! -f "$BACKUP_JSON" ]] || [[ $(stat -c%s "$BACKUP_JSON" 2>/dev/null || echo 0) -le 10 ]]; then
    _log "ERROR: backup.json absent ou trop petit après décompression"
    exit 1
fi

_log "Décompression OK ($(stat -c%s "$BACKUP_JSON") octets)"

# Vérifier Qdrant disponible
if ! curl -sf http://127.0.0.1:6333/healthz >/dev/null 2>&1; then
    _log "ERROR: Qdrant non disponible sur port 6333"
    exit 1
fi

# Restauration via memory_manager.py
_log "Lancement de memory_manager.py restore --input $BACKUP_JSON"
RESTORE_OUTPUT="$(
    python3 "$MY_PATH/../IA/memory_manager.py" restore --input "$BACKUP_JSON" 2>&1
)"
RESTORE_EXIT=$?

if [[ $RESTORE_EXIT -ne 0 ]]; then
    # Détecter si la commande restore n'existe pas encore
    if echo "$RESTORE_OUTPUT" | grep -qiE "(invalid choice|unknown command|unrecognized|no such option|restore)"; then
        _log "WARN: memory_manager.py ne supporte pas encore la commande 'restore' — restauration manuelle requise"
        _log "INFO: Le fichier backup déchiffré est disponible ici: $BACKUP_JSON"
        _log "INFO: Commande à exécuter manuellement quand restore sera disponible:"
        _log "INFO:   python3 $MY_PATH/../IA/memory_manager.py restore --input $BACKUP_JSON"
        # Copier le JSON dans un emplacement persistant pour usage ultérieur
        PERSISTENT_BACKUP="${HOME}/.zen/tmp/qdrant_last_restore.json"
        cp "$BACKUP_JSON" "$PERSISTENT_BACKUP" 2>/dev/null \
            && _log "INFO: Backup JSON copié dans $PERSISTENT_BACKUP" \
            || _log "WARN: impossible de copier dans $PERSISTENT_BACKUP"
        exit 0
    else
        _log "ERROR: memory_manager.py restore a échoué (exit=$RESTORE_EXIT)"
        _log "ERROR: Sortie: $RESTORE_OUTPUT"
        exit 1
    fi
fi

_log "Restauration Qdrant terminée avec succès depuis CID=$CID"
_log "Sortie memory_manager: $RESTORE_OUTPUT"
