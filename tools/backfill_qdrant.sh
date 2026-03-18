#!/bin/bash
############################################################ backfill_qdrant.sh
# Script pour rétro-indexer les événements existants de strfry vers Qdrant
# Auteur : Fred
# Date : 2026-03-14
# Mise à jour : 2026-03-18 — embed-worker remplacé par IA/embed.py + Ollama
########################################################################
# Prérequis :
#   - Qdrant accessible sur localhost:6333  (docker-compose rnostr stack)
#   - Ollama accessible sur localhost:11434  (local ou via IA/ollama.me.sh)
#   - python3 + pip install ollama requests
########################################################################

set -e  # Arrête le script en cas d'erreur

MY_PATH="$(dirname "$(realpath "$0")")"
EMBED_PY="$MY_PATH/../IA/embed.py"
OLLAMA_STARTER="$MY_PATH/../IA/ollama.me.sh"
PYTHON3="${HOME}/.astro/bin/python3"
command -v "$PYTHON3" &>/dev/null || PYTHON3="$(command -v python3 2>/dev/null || echo python3)"

echo "=== [1/6] Vérification des dépendances ==="

# Vérification des outils requis
for cmd in curl jq "$PYTHON3"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Erreur : $cmd n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
done

# Vérification de embed.py
if [ ! -f "$EMBED_PY" ]; then
    echo "Erreur : IA/embed.py introuvable ($EMBED_PY)"
    echo "  → Ce script doit être lancé depuis Astroport.ONE/tools/"
    exit 1
fi

# Vérification de l'accessibilité de Qdrant
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
if ! curl -sf "$QDRANT_URL/health" > /dev/null; then
    echo "Erreur : Qdrant n'est pas accessible sur $QDRANT_URL"
    echo "  → Lancez la stack : cd ~/.zen/rnostr && docker compose up -d"
    exit 1
fi

# Vérification / démarrage d'Ollama
if ! curl -sf --max-time 2 http://localhost:11434/api/tags > /dev/null 2>&1; then
    if [ -f "$OLLAMA_STARTER" ]; then
        echo "  🔌 Démarrage Ollama via ollama.me.sh..."
        bash "$OLLAMA_STARTER" &>/dev/null &
        echo -n "  Attente Ollama"
        for i in $(seq 1 20); do
            sleep 1; echo -n "."
            curl -sf --max-time 1 http://localhost:11434/api/tags > /dev/null 2>&1 && break
        done
        echo ""
    fi
    if ! curl -sf --max-time 2 http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "Erreur : Ollama non accessible. Lancez : bash IA/ollama.me.sh"
        exit 1
    fi
fi

# Vérification du modèle nomic-embed-text
echo "  Vérification du modèle nomic-embed-text..."
if ! $PYTHON3 "$EMBED_PY" --check > /dev/null 2>&1; then
    echo "  📥 Téléchargement de nomic-embed-text..."
    $PYTHON3 "$EMBED_PY" --pull 2>/dev/null || true
fi

echo "=== [2/6] Exportation des événements depuis strfry ==="

# Chemin vers la base strfry (à adapter)
STRFRY_DB="$HOME/.zen/game/nostr/strfry.db"
DUMP_FILE="/tmp/strfry_dump_backfill.jsonl"

# Vérification de l'existence de la base strfry
if [ ! -f "$STRFRY_DB" ]; then
    echo "Erreur : la base strfry n'existe pas à l'emplacement $STRFRY_DB"
    echo "  → Chemin configurable : STRFRY_DB=/chemin/vers/strfry.db $0"
    exit 1
fi

# Export des événements via strfry scan (format natif)
echo "Exportation des événements depuis $STRFRY_DB..."
if command -v strfry &>/dev/null; then
    strfry scan --since 0 2>/dev/null > "$DUMP_FILE" || true
fi

# Fallback sqlite3 si strfry non disponible
if [ ! -s "$DUMP_FILE" ] && command -v sqlite3 &>/dev/null; then
    echo "  (fallback sqlite3)"
    sqlite3 "$STRFRY_DB" \
        "SELECT json_object('id',id,'pubkey',pubkey,'created_at',created_at,\
'kind',kind,'content',content) FROM events;" \
        > "$DUMP_FILE" 2>/dev/null || true
fi

if [ ! -s "$DUMP_FILE" ]; then
    echo "Erreur : impossible d'exporter les événements (strfry scan et sqlite3 ont échoué)."
    exit 1
fi

TOTAL_EVENTS=$(wc -l < "$DUMP_FILE")
echo "Nombre total d'événements à indexer : $TOTAL_EVENTS"

if [ "$TOTAL_EVENTS" -eq 0 ]; then
    echo "Aucun événement à indexer. Arrêt du script."
    rm -f "$DUMP_FILE"
    exit 0
fi

echo "=== [3/6] Préparation de l'indexation via IA/embed.py ==="

COLLECTION="nostr_events"
PROCESSED=0
SUCCESS=0
FAILED=0

# Créer la collection Qdrant si elle n'existe pas
echo "Création/vérification de la collection '$COLLECTION' dans Qdrant..."
curl -sf -X PUT "$QDRANT_URL/collections/$COLLECTION" \
    -H "Content-Type: application/json" \
    -d '{"vectors":{"size":768,"distance":"Cosine"},"hnsw_config":{"m":16,"ef_construct":64},"optimizers_config":{"indexing_threshold":1000}}' \
    > /dev/null && echo "  ✓ Collection '$COLLECTION' prête."

echo "=== [4/6] Début de l'indexation ==="

# Indexation événement par événement via embed.py
# Chaque ligne du dump est un objet JSON {id, pubkey, created_at, kind, content}
while IFS= read -r line; do
    # Extraire les champs utiles
    EVENT_ID=$(echo "$line" | jq -r '.id // empty'      2>/dev/null)
    KIND=$(echo "$line"     | jq -r '.kind // 1'         2>/dev/null)
    PUBKEY=$(echo "$line"   | jq -r '.pubkey // empty'   2>/dev/null)
    CONTENT=$(echo "$line"  | jq -r '.content // empty'  2>/dev/null)

    [ -z "$EVENT_ID" ] && { FAILED=$((FAILED+1)); continue; }
    [ -z "$CONTENT"  ] && { PROCESSED=$((PROCESSED+1)); continue; }

    # Dériver un ID entier (Qdrant attend un int64) depuis les 8 premiers octets du hash
    POINT_ID=$(echo "$EVENT_ID" | $PYTHON3 -c \
        "import sys; h=sys.stdin.read().strip(); print(int(h[:15],16) % (2**31))" 2>/dev/null)
    [ -z "$POINT_ID" ] && POINT_ID=$((PROCESSED + 1))

    # Payload JSON (sans le contenu pour ne pas alourdir)
    PAYLOAD=$(jq -nc --arg id "$EVENT_ID" --arg pk "$PUBKEY" --argjson k "$KIND" \
        '{"event_id":$id,"pubkey":$pk,"kind":$k}' 2>/dev/null || echo '{}')

    # Indexation via embed.py
    if echo "$CONTENT" | QDRANT_URL="$QDRANT_URL" \
            $PYTHON3 "$EMBED_PY" \
            --index \
            --collection "$COLLECTION" \
            --id "$POINT_ID" \
            --payload "$PAYLOAD" \
            - > /dev/null 2>&1; then
        SUCCESS=$((SUCCESS+1))
    else
        FAILED=$((FAILED+1))
    fi

    PROCESSED=$((PROCESSED+1))

    # Affichage de la progression tous les 100 événements
    if [ $((PROCESSED % 100)) -eq 0 ]; then
        echo "  Progression : $PROCESSED/$TOTAL_EVENTS (OK:$SUCCESS, Erreurs:$FAILED)"
    fi
done < "$DUMP_FILE"

echo "=== [5/6] Nettoyage ==="
rm -f "$DUMP_FILE"

echo "=== [6/6] Résumé de l'indexation ==="
echo "Événements traités : $PROCESSED/$TOTAL_EVENTS"
echo "  ✓ Indexés avec succès : $SUCCESS"
echo "  ✗ Échecs              : $FAILED"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "⚠️  $FAILED événement(s) n'ont pas pu être indexés."
    echo "   Vérifiez qu'Ollama + nomic-embed-text sont disponibles : bash IA/ollama.me.sh"
    exit 1
else
    echo ""
    echo "✅ Rétro-indexation terminée avec succès dans Qdrant ($QDRANT_URL)"
    echo "   Collection : $COLLECTION  |  Points : $SUCCESS"
    exit 0
fi
