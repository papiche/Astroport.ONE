#!/usr/bin/env python3
"""
embed.py — Utilitaire d'embedding via Ollama (nomic-embed-text) + Qdrant (Stack AI)

Optimisé pour ZEN[0] : 
- Détection auto de la clé API dans ~/.zen/ai-company/.env
- Support du filtrage par langage (--language)
- Inférence unique (pas de double appel Ollama)
"""
import argparse
import hashlib
import json
import os
import sys
import time

# ─────────────────────────────────────────────────────────────────────────────
# Configuration & Secrets
# ─────────────────────────────────────────────────────────────────────────────
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
EMBED_MODEL = "nomic-embed-text"
QDRANT_URL  = os.environ.get("QDRANT_URL", "http://localhost:6333")

# Auto-détection de la clé API Qdrant
QDRANT_API_KEY = os.environ.get("QDRANT_API_KEY")
AI_ENV = os.path.expanduser("~/.zen/ai-company/.env")

if not QDRANT_API_KEY and os.path.exists(AI_ENV):
    try:
        with open(AI_ENV, "r") as f:
            for line in f:
                if "QDRANT_API_KEY=" in line:
                    QDRANT_API_KEY = line.split("=", 1)[1].strip().strip('"').strip("'")
    except Exception:
        pass

def _qdrant_headers():
    headers = {"Content-Type": "application/json"}
    if QDRANT_API_KEY:
        headers["api-key"] = QDRANT_API_KEY
    return headers

# ─────────────────────────────────────────────────────────────────────────────
# Imports conditionnels
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

# ─────────────────────────────────────────────────────────────────────────────
# Fonctions de base
# ─────────────────────────────────────────────────────────────────────────────

def _ensure_model(model: str = EMBED_MODEL):
    if not _OLLAMA_OK: return False
    try:
        models = _ollama.list()
        names = [m.get("name", m.get("model", "")) for m in models.get("models", [])]
        if any(model in n for n in names): return True
        _ollama.pull(model)
        return True
    except Exception: return False

def get_embedding(text: str, model: str = EMBED_MODEL) -> list:
    if not _OLLAMA_OK:
        print("  [embed] ollama non installé — pip install ollama", file=sys.stderr)
        return []
    text = text.strip()[:8000]
    if not text: return []
    try:
        resp = _ollama.embeddings(model=model, prompt=text)
        return resp.get("embedding", [])
    except Exception as e:
        if "not found" in str(e).lower() and _ensure_model(model):
            try:
                resp = _ollama.embeddings(model=model, prompt=text)
                return resp.get("embedding", [])
            except: pass
        return []

# ─────────────────────────────────────────────────────────────────────────────
# Qdrant Logic
# ─────────────────────────────────────────────────────────────────────────────

def qdrant_available() -> bool:
    if not _REQUESTS_OK: return False
    try:
        r = _requests.get(f"{QDRANT_URL}/health", headers=_qdrant_headers(), timeout=1)
        return r.status_code == 200
    except Exception: return False

def qdrant_ensure_collection(collection: str, vector_size: int = 768) -> bool:
    if not _REQUESTS_OK: return False
    headers = _qdrant_headers()
    try:
        r = _requests.get(f"{QDRANT_URL}/collections/{collection}", headers=headers, timeout=2)
        if r.status_code == 200: return True
        payload = {"vectors": {"size": vector_size, "distance": "Cosine"}}
        r = _requests.put(f"{QDRANT_URL}/collections/{collection}", json=payload, headers=headers, timeout=5)
        return r.status_code in (200, 201)
    except Exception: return False

def qdrant_index(collection: str, point_id: int, text: str,
                 payload: dict = None, model: str = EMBED_MODEL,
                 language: str = None, vector: list = None) -> bool:
    """Indexation avec support optionnel d'un vecteur déjà calculé."""
    if not _REQUESTS_OK: return False
    
    # Utiliser le vecteur fourni ou le calculer
    v = vector if vector else get_embedding(text, model)
    if not v: return False

    qdrant_ensure_collection(collection, len(v))
    
    if language:
        payload = payload or {}
        payload["language"] = language

    data = {"points": [{"id": point_id, "vector": v, "payload": payload or {}}]}
    try:
        r = _requests.put(f"{QDRANT_URL}/collections/{collection}/points", 
                          json=data, headers=_qdrant_headers(), timeout=10)
        return r.status_code in (200, 206)
    except Exception: return False

def qdrant_search(collection: str, query: str, top: int = 5,
                  score_threshold: float = 0.65,
                  model: str = EMBED_MODEL,
                  filter_language: str = None) -> list:
    if not _REQUESTS_OK: return []
    v = get_embedding(query, model)
    if not v: return []

    qdrant_ensure_collection(collection, len(v))
    payload_data = {"vector": v, "limit": top, "with_payload": True, "score_threshold": score_threshold}

    if filter_language:
        payload_data["filter"] = {"must": [{"key": "language", "match": {"value": filter_language}}]}
    
    try:
        r = _requests.post(f"{QDRANT_URL}/collections/{collection}/points/search", 
                           json=payload_data, headers=_qdrant_headers(), timeout=10)
        if r.status_code == 200: return r.json().get("result", [])
    except Exception: pass
    return []

# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Embedding via Ollama + Qdrant")
    parser.add_argument("text", nargs="?", default=None, help="Texte ou stdin")
    parser.add_argument("-m", "--model", default=EMBED_MODEL)
    parser.add_argument("--index", action="store_true", help="Indexer dans Qdrant")
    parser.add_argument("--search", action="store_true", help="Rechercher dans Qdrant")
    parser.add_argument("--collection", default="code_assistant")
    parser.add_argument("--language", help="Filtrer ou tagger par langage (ex: py, js)")
    parser.add_argument("--id", type=int, help="ID unique (optionnel)")
    parser.add_argument("--payload", default="{}", help="JSON des métadonnées")
    parser.add_argument("--top", type=int, default=5)
    parser.add_argument("--threshold", type=float, default=0.65)
    parser.add_argument("--check", action="store_true", help="Diagnostic")
    parser.add_argument("--pull", action="store_true", help="Forcer pull modèle")

    args = parser.parse_args()

    if args.check:
        print(json.dumps({
            "ollama": {"available": _ollama.list() if _OLLAMA_OK else False, "host": OLLAMA_HOST},
            "qdrant": {"available": qdrant_available(), "url": QDRANT_URL, "secured": QDRANT_API_KEY is not None}
        }, indent=2))
        return

    if args.pull:
        print(json.dumps({"model": args.model, "ready": _ensure_model(args.model)}))
        return

    # Lecture du texte
    text = args.text or (not sys.stdin.isatty() and sys.stdin.read().strip())
    if not text:
        print("Erreur : Texte requis.", file=sys.stderr); sys.exit(1)

    # ── MODE RECHERCHE ──
    if args.search:
        results = qdrant_search(args.collection, text, args.top, args.threshold, args.model, args.language)
        print(json.dumps({"collection": args.collection, "results": results}, indent=2, ensure_ascii=False))
        return

    # ── CALCUL EMBEDDING (Unique pour index ou simple sortie) ──
    vector = get_embedding(text, args.model)
    if not vector:
        print(json.dumps({"error": "Embedding échoué"})); sys.exit(1)

    # ── MODE INDEXATION ──
    if args.index:
        point_id = args.id or int(hashlib.sha256(text[:100].encode()).hexdigest(), 16) % (2**31)
        try: payload = json.loads(args.payload)
        except: payload = {"raw": args.payload}
        
        payload.update({"timestamp": time.time(), "text_preview": text[:200]})
        
        # On passe le vecteur déjà calculé pour éviter le double appel Ollama
        ok = qdrant_index(args.collection, point_id, text, payload, args.model, args.language, vector=vector)
        print(json.dumps({"indexed": ok, "collection": args.collection, "id": point_id, "dims": len(vector)}))
        return

    # ── MODE SIMPLE SORTIE ──
    print(json.dumps({"model": args.model, "dims": len(vector), "embedding": vector}))

if __name__ == "__main__":
    main()