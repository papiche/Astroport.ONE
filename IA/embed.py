#!/usr/bin/env python3
"""
embed.py — Utilitaire d'embedding via Ollama (nomic-embed-text)

Utilise l'API Ollama locale (port 11434) ou distante (via tunnel SSH comme ollama.me.sh).
Peut stocker / rechercher dans Qdrant (port 6333).

Usage CLI :
  # Générer un embedding simple
  echo "mon texte" | python3 embed.py
  python3 embed.py "mon texte"

  # Indexer dans Qdrant
  python3 embed.py --index --collection code_assistant \\
                   --id 42 --payload '{"script":"foo.py"}' \\
                   "contenu à indexer"

  # Rechercher dans Qdrant
  python3 embed.py --search --collection code_assistant --top 5 "requête"

Usage comme module :
  from embed import get_embedding, qdrant_index, qdrant_search
"""
import argparse
import hashlib
import json
import os
import sys
import time

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
EMBED_MODEL = "nomic-embed-text"
QDRANT_URL  = os.environ.get("QDRANT_URL", "http://localhost:6333")

# ─────────────────────────────────────────────────────────────────────────────
# Import Ollama
# ─────────────────────────────────────────────────────────────────────────────
try:
    import ollama as _ollama
    _OLLAMA_OK = True
except ImportError:
    _OLLAMA_OK = False

try:
    import requests as _requests
    _REQUESTS_OK = True
except ImportError:
    _REQUESTS_OK = False


def _check_ollama() -> bool:
    """Vérifie qu'Ollama est accessible."""
    if not _OLLAMA_OK:
        return False
    try:
        _ollama.list()
        return True
    except Exception:
        return False


def _ensure_model(model: str = EMBED_MODEL):
    """S'assure que le modèle est disponible, le télécharge si nécessaire."""
    if not _OLLAMA_OK:
        return False
    try:
        models = _ollama.list()
        names = [m.get("name", m.get("model", "")) for m in models.get("models", [])]
        if any(model in n for n in names):
            return True
        # Modèle absent → pull
        print(f"  [embed] Téléchargement de {model} via Ollama...", file=sys.stderr)
        _ollama.pull(model)
        print(f"  [embed] {model} prêt.", file=sys.stderr)
        return True
    except Exception as e:
        print(f"  [embed] Erreur modèle: {e}", file=sys.stderr)
        return False


# ─────────────────────────────────────────────────────────────────────────────
# Embedding
# ─────────────────────────────────────────────────────────────────────────────
def get_embedding(text: str, model: str = EMBED_MODEL) -> list:
    """
    Génère un vecteur d'embedding pour le texte donné via Ollama.

    Args:
        text:  Texte à encoder (tronqué à 8000 chars pour nomic-embed-text)
        model: Modèle Ollama (défaut: nomic-embed-text)

    Returns:
        list: Vecteur de flottants (768 dims pour nomic-embed-text) ou []
    """
    if not _OLLAMA_OK:
        print("  [embed] ollama non installé — pip install ollama", file=sys.stderr)
        return []

    text = text.strip()[:8000]  # nomic-embed-text supporte jusqu'à 8192 tokens
    if not text:
        return []

    try:
        resp = _ollama.embeddings(model=model, prompt=text)
        return resp.get("embedding", [])
    except Exception as e:
        # Tenter de tirer le modèle si pas dispo
        if "not found" in str(e).lower() or "pull" in str(e).lower():
            if _ensure_model(model):
                try:
                    resp = _ollama.embeddings(model=model, prompt=text)
                    return resp.get("embedding", [])
                except Exception as e2:
                    print(f"  [embed] Erreur après pull: {e2}", file=sys.stderr)
        else:
            print(f"  [embed] Erreur embedding: {e}", file=sys.stderr)
        return []


# ─────────────────────────────────────────────────────────────────────────────
# Qdrant
# ─────────────────────────────────────────────────────────────────────────────
def qdrant_available() -> bool:
    """Retourne True si Qdrant est accessible."""
    if not _REQUESTS_OK:
        return False
    try:
        r = _requests.get(f"{QDRANT_URL}/health", timeout=1)
        return r.status_code == 200
    except Exception:
        return False


def qdrant_ensure_collection(collection: str, vector_size: int = 768) -> bool:
    """Crée la collection Qdrant si elle n'existe pas."""
    if not _REQUESTS_OK:
        return False
    try:
        r = _requests.get(f"{QDRANT_URL}/collections/{collection}", timeout=2)
        if r.status_code == 200:
            return True
        # Créer la collection
        payload = {"vectors": {"size": vector_size, "distance": "Cosine"}}
        r = _requests.put(
            f"{QDRANT_URL}/collections/{collection}",
            json=payload, timeout=5
        )
        return r.status_code in (200, 201)
    except Exception as e:
        print(f"  [embed/qdrant] Erreur création collection '{collection}': {e}",
              file=sys.stderr)
        return False


def qdrant_index(collection: str, point_id: int, text: str,
                 payload: dict = None, model: str = EMBED_MODEL,
                 language: str = None) -> bool:
    """
    Indexe un texte dans Qdrant après embedding.

    Args:
        collection: Nom de la collection Qdrant
        point_id:   Identifiant unique du point
        text:       Texte à embedder et indexer
        payload:    Métadonnées associées au point
        model:      Modèle d'embedding Ollama
        language:   Extension/langue du fichier (P4: filtre Qdrant par langue)
                    Ex: "py", "sh", "js"

    Returns:
        bool: True si succès
    """
    # P4 : ajouter la langue aux métadonnées pour filtrage futur
    if language and payload is not None:
        payload.setdefault("language", language)
    elif language:
        payload = {"language": language}
    if not _REQUESTS_OK:
        return False

    vector = get_embedding(text, model)
    if not vector:
        print(f"  [embed/qdrant] Embedding vide pour point {point_id}", file=sys.stderr)
        return False

    qdrant_ensure_collection(collection, len(vector))

    data = {
        "points": [{
            "id": point_id,
            "vector": vector,
            "payload": payload or {}
        }]
    }
    try:
        r = _requests.put(
            f"{QDRANT_URL}/collections/{collection}/points",
            json=data, timeout=10
        )
        return r.status_code in (200, 206)
    except Exception as e:
        print(f"  [embed/qdrant] Erreur indexation: {e}", file=sys.stderr)
        return False


def qdrant_search(collection: str, query: str, top: int = 5,
                  score_threshold: float = 0.65,
                  model: str = EMBED_MODEL,
                  filter_language: str = None) -> list:
    """
    Recherche sémantique dans une collection Qdrant.

    Args:
        collection:       Nom de la collection
        query:            Texte de la requête
        top:              Nombre max de résultats
        score_threshold:  Score minimum de similarité (0-1)
        model:            Modèle d'embedding Ollama
        filter_language:  P4 - Filtrer par langue (ex: "py", "sh")
                          None = pas de filtre

    Returns:
        list: [{"id": ..., "score": ..., "payload": {...}}, ...]
    """
    if not _REQUESTS_OK:
        return []

    vector = get_embedding(query, model)
    if not vector:
        return []

    qdrant_ensure_collection(collection, len(vector))

    payload_data = {
        "vector": vector,
        "limit":  top,
        "with_payload": True,
        "score_threshold": score_threshold
    }

    # P4 : filtre par langue si spécifié
    if filter_language:
        payload_data["filter"] = {
            "must": [{"key": "language", "match": {"value": filter_language}}]
        }
    try:
        r = _requests.post(
            f"{QDRANT_URL}/collections/{collection}/points/search",
            json=payload_data, timeout=10
        )
        if r.status_code == 200:
            return r.json().get("result", [])
    except Exception as e:
        print(f"  [embed/qdrant] Erreur recherche: {e}", file=sys.stderr)
    return []


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Embedding via Ollama (nomic-embed-text) + Qdrant optionnel"
    )
    parser.add_argument("text", nargs="?", default=None,
                        help="Texte à embedder (ou depuis stdin)")
    parser.add_argument("-m", "--model", default=EMBED_MODEL,
                        help=f"Modèle Ollama (défaut: {EMBED_MODEL})")

    # Qdrant
    parser.add_argument("--index", action="store_true",
                        help="Indexer dans Qdrant")
    parser.add_argument("--search", action="store_true",
                        help="Rechercher dans Qdrant")
    parser.add_argument("--collection", default="code_assistant",
                        help="Collection Qdrant (défaut: code_assistant)")
    parser.add_argument("--id", type=int, default=None,
                        help="ID du point Qdrant (pour --index)")
    parser.add_argument("--payload", type=str, default="{}",
                        help="JSON des métadonnées (pour --index)")
    parser.add_argument("--top", type=int, default=5,
                        help="Nombre résultats (pour --search)")
    parser.add_argument("--threshold", type=float, default=0.65,
                        help="Score minimum similarité (défaut: 0.65)")

    # Diag
    parser.add_argument("--check", action="store_true",
                        help="Vérifier que Ollama et le modèle sont disponibles")
    parser.add_argument("--pull", action="store_true",
                        help="Télécharger le modèle d'embedding si absent")

    args = parser.parse_args()

    # ── Diagnostic ──────────────────────────────────────────────────────────
    if args.check:
        ollama_ok = _check_ollama()
        qdrant_ok = qdrant_available()
        result = {
            "ollama": {
                "available": ollama_ok,
                "host": OLLAMA_HOST,
                "model": EMBED_MODEL
            },
            "qdrant": {
                "available": qdrant_ok,
                "url": QDRANT_URL
            }
        }
        print(json.dumps(result, indent=2))
        sys.exit(0 if ollama_ok else 1)

    if args.pull:
        ok = _ensure_model(args.model)
        print(json.dumps({"model": args.model, "ready": ok}))
        sys.exit(0 if ok else 1)

    # ── Lire le texte ────────────────────────────────────────────────────────
    if args.text:
        text = args.text
    elif not sys.stdin.isatty():
        text = sys.stdin.read().strip()
    else:
        print("Erreur : fournir un texte en argument ou via stdin.", file=sys.stderr)
        print("  Ex: echo 'mon texte' | embed.py", file=sys.stderr)
        sys.exit(1)

    # ── Mode recherche ───────────────────────────────────────────────────────
    if args.search:
        if not qdrant_available():
            print(json.dumps({"error": "Qdrant non disponible", "results": []}))
            sys.exit(1)
        results = qdrant_search(
            args.collection, text, args.top, args.threshold, args.model
        )
        print(json.dumps({"collection": args.collection, "results": results},
                         indent=2, ensure_ascii=False))
        return

    # ── Embedding ────────────────────────────────────────────────────────────
    vector = get_embedding(text, args.model)
    if not vector:
        print(json.dumps({"error": "Embedding échoué — Ollama disponible?"}))
        sys.exit(1)

    # ── Mode indexation ──────────────────────────────────────────────────────
    if args.index:
        if not qdrant_available():
            print(json.dumps({"error": "Qdrant non disponible"}))
            sys.exit(1)
        point_id = args.id or int(hashlib.sha256(text[:100].encode()).hexdigest(), 16) % (2**31)
        try:
            payload = json.loads(args.payload)
        except json.JSONDecodeError:
            payload = {"raw": args.payload}
        payload.setdefault("timestamp", time.time())
        payload.setdefault("text_preview", text[:200])

        ok = qdrant_index(args.collection, point_id, text, payload, args.model)
        print(json.dumps({
            "indexed": ok,
            "collection": args.collection,
            "id": point_id,
            "dims": len(vector)
        }))
        return

    # ── Sortie embedding simple ──────────────────────────────────────────────
    print(json.dumps({
        "model":     args.model,
        "dims":      len(vector),
        "embedding": vector
    }))


if __name__ == "__main__":
    main()
