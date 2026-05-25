#!/usr/bin/env python3
"""
skill_qdrant.py — Mémoire vectorielle du NODE pour les ressources WoTx2

Collection Qdrant : wotx2_resources
  - Indexe les Kind 30500 (permit definitions) et Kind 30504 (training resources)
  - Requête sémantique : "devops" → ressources pertinentes pour le skill

Usage depuis bash :
  python3 skill_qdrant.py search --skill devops --question "comment configurer nginx"
  python3 skill_qdrant.py index  --event '{"kind":30504,"tags":[...],"content":"..."}'
  python3 skill_qdrant.py index-all   # indexe tous les événements du relay local
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os


import os
import sys
import json
import hashlib

# ── Venv ~/.astro ─────────────────────────────────────────────────────────────
venv_path = os.path.expanduser("~/.astro")
if os.path.exists(venv_path):
    python_version = f"python{sys.version_info.major}.{sys.version_info.minor}"
    site_packages = os.path.join(venv_path, "lib", python_version, "site-packages")
    if os.path.exists(site_packages):
        sys.path.insert(0, site_packages)

QDRANT_HOST = "localhost"
QDRANT_PORT = 6333
COLLECTION  = "wotx2_resources"
EMBED_MODEL = "nomic-embed-text"  # Ollama embedding model
VECTOR_SIZE = 768                 # nomic-embed-text output size
TOP_K       = 5


def _client():
    from qdrant_client import QdrantClient
    return QdrantClient(host=QDRANT_HOST, port=QDRANT_PORT)


def _embed(text: str) -> list:
    """Génère un embedding via Ollama (nomic-embed-text)."""
    import ollama
    resp = ollama.embeddings(model=EMBED_MODEL, prompt=text)
    return resp["embedding"]


def _ensure_collection():
    """Crée la collection Qdrant si elle n'existe pas."""
    from qdrant_client.models import Distance, VectorParams
    client = _client()
    existing = [c.name for c in client.get_collections().collections]
    if COLLECTION not in existing:
        client.create_collection(
            collection_name=COLLECTION,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
        )
        print(f"[skill_qdrant] Collection '{COLLECTION}' créée.", file=sys.stderr)


def _event_to_doc(event: dict) -> dict | None:
    """Convertit un event NOSTR (30500/30504) en document Qdrant."""
    kind = event.get("kind", 0)
    tags = event.get("tags", [])
    content_raw = event.get("content", "")
    pubkey = event.get("pubkey", "")

    # Extraire les tags utiles
    def tag_val(name, idx=1):
        for t in tags:
            if t and t[0] == name and len(t) > idx:
                return t[idx]
        return ""

    def tag_vals(name, idx=1):
        return [t[idx] for t in tags if t and t[0] == name and len(t) > idx]

    d_tag   = tag_val("d")
    t_tags  = tag_vals("t")
    r_tags  = tag_vals("r")  # URLs ressources

    # Contenu JSON optionnel
    content = {}
    try:
        content = json.loads(content_raw) if content_raw else {}
    except Exception:
        content = {"raw": content_raw}

    # Texte à embedder = nom + description + skill tags + URL
    skill_list = [t for t in t_tags if t not in ("permit", "auto_proclaimed", "composite")]
    text_parts = []
    if d_tag:
        text_parts.append(d_tag.replace("_", " ").replace("-", " "))
    if content.get("name"):
        text_parts.append(content["name"])
    if content.get("description"):
        text_parts.append(content["description"])
    text_parts.extend(skill_list)
    text_parts.extend(r_tags)

    if not text_parts:
        return None

    embed_text = " ".join(text_parts)

    # ID stable basé sur l'event id ou d-tag+pubkey
    event_id = event.get("id") or hashlib.sha256(
        f"{pubkey}:{d_tag}:{kind}".encode()
    ).hexdigest()
    # Qdrant needs unsigned int ID — use first 15 hex chars as int
    point_id = int(event_id[:15], 16) % (2**63)

    return {
        "id":    point_id,
        "text":  embed_text,
        "payload": {
            "event_id":  event_id,
            "kind":      kind,
            "d_tag":     d_tag,
            "skills":    skill_list,
            "resources": r_tags,
            "name":      content.get("name", d_tag),
            "description": content.get("description", ""),
            "pubkey":    pubkey,
            "icon":      content.get("icon", ""),
        }
    }


def index_event(event: dict) -> bool:
    """Indexe un événement Kind 30500/30504 dans Qdrant. Retourne True si OK."""
    from qdrant_client.models import PointStruct
    try:
        _ensure_collection()
        doc = _event_to_doc(event)
        if not doc:
            return False
        vec = _embed(doc["text"])
        client = _client()
        client.upsert(
            collection_name=COLLECTION,
            points=[PointStruct(id=doc["id"], vector=vec, payload=doc["payload"])]
        )
        return True
    except Exception as e:
        print(f"[skill_qdrant] Erreur indexation: {e}", file=sys.stderr)
        return False


def search_resources(skill: str, question: str = "", limit: int = TOP_K) -> list:
    """
    Recherche sémantique dans Qdrant.
    Retourne une liste de dicts {name, description, skills, resources}.
    """
    try:
        _ensure_collection()
        query = f"{skill} {question}".strip()
        vec = _embed(query)
        client = _client()
        hits = client.search(
            collection_name=COLLECTION,
            query_vector=vec,
            limit=limit,
            score_threshold=0.3,
        )
        results = []
        for h in hits:
            p = h.payload
            results.append({
                "name":        p.get("name", ""),
                "description": p.get("description", ""),
                "skills":      p.get("skills", []),
                "resources":   p.get("resources", []),
                "score":       round(h.score, 3),
                "kind":        p.get("kind", 0),
            })
        return results
    except Exception as e:
        print(f"[skill_qdrant] Erreur recherche: {e}", file=sys.stderr)
        return []


def build_qdrant_context(skill: str, question: str = "") -> str:
    """Retourne un bloc de contexte formaté depuis Qdrant pour injection dans le prompt."""
    results = search_resources(skill, question)
    if not results:
        return ""
    lines = [f"🗄️ Ressources disponibles pour '{skill}' (base NODE) :"]
    for r in results:
        name = r["name"] or skill
        desc = r["description"]
        urls = r["resources"]
        line = f"  • {name}"
        if desc:
            line += f" — {desc[:100]}"
        if urls:
            line += f"\n    🔗 {', '.join(urls[:3])}"
        lines.append(line)
    return "\n".join(lines)


def index_all_from_relay(strfry_path: str = None) -> int:
    """Indexe tous les Kind 30500/30504 du relay local strfry."""
    import subprocess
    strfry = strfry_path or os.path.expanduser("~/.zen/strfry/strfry")
    if not os.path.exists(strfry):
        print(f"[skill_qdrant] strfry non trouvé : {strfry}", file=sys.stderr)
        return 0

    count = 0
    for kind in [30500, 30504]:
        try:
            result = subprocess.run(
                [strfry, "scan", json.dumps({"kinds": [kind]})],
                cwd=os.path.dirname(strfry),
                capture_output=True, text=True, timeout=30
            )
            for line in result.stdout.splitlines():
                try:
                    ev = json.loads(line)
                    if index_event(ev):
                        count += 1
                except Exception:
                    pass
        except Exception as e:
            print(f"[skill_qdrant] Erreur scan kind {kind}: {e}", file=sys.stderr)
    return count


# ── CLI ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd")

    s = sub.add_parser("search")
    s.add_argument("--skill",    required=True)
    s.add_argument("--question", default="")
    s.add_argument("--limit",    type=int, default=TOP_K)
    s.add_argument("--context",  action="store_true", help="Format context string")

    ix = sub.add_parser("index")
    ix.add_argument("--event", required=True, help="Event JSON string")

    sub.add_parser("index-all")

    args = parser.parse_args()

    if args.cmd == "search":
        if args.context:
            print(build_qdrant_context(args.skill, args.question))
        else:
            results = search_resources(args.skill, args.question, args.limit)
            print(json.dumps(results, ensure_ascii=False, indent=2))

    elif args.cmd == "index":
        ev = json.loads(args.event)
        ok = index_event(ev)
        sys.exit(0 if ok else 1)

    elif args.cmd == "index-all":
        n = index_all_from_relay()
        print(f"[skill_qdrant] {n} événements indexés.")
