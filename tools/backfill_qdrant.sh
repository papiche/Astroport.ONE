#!/bin/bash
############################################################ backfill_qdrant.sh
# Script pour rétro-indexer les événements existants de strfry vers Qdrant
# Auteur : Fred
# Date : 2026-03-14
########################################################################

set -e  # Arrête le script en cas d'erreur

echo "=== [1/6] Vérification des dépendances ==="

# Vérification des outils requis
for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Erreur : $cmd n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
done

# Vérification de l'accessibilité de Qdrant et embed-worker
QDRANT_URL="http://localhost:6333"
EMBED_WORKER_URL="http://localhost:8000/index_batch"  # À adapter selon ton API embed-worker réelle

if ! curl -s "$QDRANT_URL" > /dev/null; then
    echo "Erreur : Qdrant n'est pas accessible sur $QDRANT_URL"
    exit 1
fi

if ! curl -s "$EMBED_WORKER_URL" > /dev/null; then
    echo "Erreur : embed-worker n'est pas accessible sur $EMBED_WORKER_URL"
    exit 1
fi

echo "=== [2/6] Exportation des événements depuis strfry ==="

# Chemin vers la base strfry (à adapter)
STRFRY_DB="$HOME/.zen/game/nostr/strfry.db"
DUMP_FILE="/tmp/strfry_dump.jsonl"

# Vérification de l'existence de la base strfry
if [ ! -f "$STRFRY_DB" ]; then
    echo "Erreur : la base strfry n'existe pas à l'emplacement $STRFRY_DB"
    exit 1
fi

# Export des événements (exemple avec sqlite3, à adapter selon le format réel de strfry)
echo "Exportation des événements depuis $STRFRY_DB..."
if ! sqlite3 "$STRFRY_DB" "SELECT json_object('id', id, 'pubkey', pubkey, 'created_at', created_at, 'kind', kind, 'tags', json_array(tags), 'content', content) FROM events;" > "$DUMP_FILE"; then
    echo "Erreur : échec de l'export des événements depuis strfry."
    exit 1
fi

TOTAL_EVENTS=$(wc -l < "$DUMP_FILE")
echo "Nombre total d'événements à indexer : $TOTAL_EVENTS"

if [ "$TOTAL_EVENTS" -eq 0 ]; then
    echo "Aucun événement à indexer. Arrêt du script."
    rm "$DUMP_FILE"
    exit 0
fi

echo "=== [3/6] Préparation de l'indexation par lots ==="

BATCH_SIZE=500
BATCH_FILE="/tmp/batch.json"
PROCESSED=0
SUCCESS=0
FAILED=0

# Fonction pour envoyer un batch à embed-worker
send_batch() {
    local batch_data="$1"
    if [ -z "$batch_data" ]; then
        return 0
    fi

    if curl -X POST -H "Content-Type: application/json" --data "@$BATCH_FILE" "$EMBED_WORKER_URL" > /dev/null; then
        echo "Batch envoyé avec succès ($BATCH_SIZE événements)."
        SUCCESS=$((SUCCESS + BATCH_SIZE))
    else
        echo "Erreur : échec de l'envoi du batch."
        FAILED=$((FAILED + BATCH_SIZE))
    fi
    rm -f "$BATCH_FILE"
}

echo "=== [4/6] Début de l'indexation ==="

# Initialisation du batch
batch_data="["
count=0

while IFS= read -r line; do
    # Construction du batch au format JSON
    if [ "$count" -gt 0 ]; then
        batch_data="$batch_data,"
    fi
    batch_data="$batch_data{\"event\": $line, \"action\": \"index\"}"
    count=$((count + 1))

    # Envoi du batch quand la taille est atteinte
    if [ "$count" -eq "$BATCH_SIZE" ]; then
        batch_data="$batch_data]"
        echo "$batch_data" > "$BATCH_FILE"
        send_batch "$batch_data"
        PROCESSED=$((PROCESSED + BATCH_SIZE))
        echo "Progression : $PROCESSED/$TOTAL_EVENTS événements traités."
        batch_data="["
        count=0
    fi
done < "$DUMP_FILE"

# Envoi du dernier batch s'il n'est pas vide
if [ "$count" -gt 0 ]; then
    batch_data="$batch_data]"
    echo "$batch_data" > "$BATCH_FILE"
    send_batch "$batch_data"
    PROCESSED=$((PROCESSED + count))
    echo "Progression : $PROCESSED/$TOTAL_EVENTS événements traités."
fi

echo "=== [5/6] Nettoyage ==="
rm -f "$DUMP_FILE"

echo "=== [6/6] Résumé de l'indexation ==="
echo "Événements traités : $PROCESSED/$TOTAL_EVENTS"
echo "Batchs réussis : $((SUCCESS / BATCH_SIZE))"
echo "Échecs : $((FAILED / BATCH_SIZE))"

if [ "$FAILED" -gt 0 ]; then
    echo "Attention : $FAILED événements n'ont pas pu être indexés."
    exit 1
else
    echo "Rétro-indexation terminée avec succès !"
    exit 0
fi
