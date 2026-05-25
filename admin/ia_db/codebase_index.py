#!/usr/bin/env python3
"""
codebase_index.py — Mémoire vectorielle du code source (Qdrant + nomic-embed-text).

Modes :
  --index        Indexer / réindexer les fichiers du codebase
  --incremental  Réindexer seulement les fichiers modifiés (mtime)
  --search TEXT  Recherche sémantique (output: score<TAB>path, un par ligne)
  --snapshot     Créer un snapshot Qdrant et le publier sur IPFS
  --restore CID  Restaurer depuis un snapshot IPFS (via gateway locale)
  --reset        Supprimer et recréer la collection avant indexation
  --stats        Afficher les statistiques de la collection

Variables d'environnement :
  QDRANT_URL      http://127.0.0.1:6333
  QDRANT_API_KEY  (optionnel — clé API Qdrant si configurée)
  OLLAMA_URL      http://localhost:11434
  EMBED_MODEL     nomic-embed-text
  IPFS_GATEWAY    http://localhost:8080
  CODEBASE_ROOT   ~/workspace/AAA
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
import time
import hashlib
import argparse
import subprocess
from pathlib import Path

try:
    import requests
except ImportError:
    # Fallback urllib (toujours disponible)
    import urllib.request
    import urllib.error

    class _FakeResp:
        def __init__(self, data, status):
            self._data = data
            self.status_code = status
        def ok(self): return 200 <= self.status_code < 300
        def json(self): return json.loads(self._data)

    class _Session:
        def _call(self, method, url, **kw):
            data = json.dumps(kw.get("json", kw.get("data", {}))).encode()
            headers = {"Content-Type": "application/json"}
            req = urllib.request.Request(url, data=data, headers=headers, method=method.upper())
            try:
                with urllib.request.urlopen(req, timeout=kw.get("timeout", 30)) as r:
                    body = r.read()
                    return type("R", (), {"ok": True, "status_code": r.status, "json": lambda: json.loads(body), "_data": body})()
            except urllib.error.HTTPError as e:
                return type("R", (), {"ok": False, "status_code": e.code, "json": lambda: {}, "_data": b""})()
            except Exception:
                return type("R", (), {"ok": False, "status_code": 0, "json": lambda: {}, "_data": b""})()
        def get(self, url, **kw):  return self._call("GET",    url, **kw)
        def post(self, url, **kw): return self._call("POST",   url, **kw)
        def put(self, url, **kw):  return self._call("PUT",    url, **kw)
        def delete(self, url, **kw): return self._call("DELETE", url, **kw)

    requests = type("requests", (), {"Session": _Session})()

# ── Configuration ─────────────────────────────────────────────────────────────
QDRANT_URL     = os.getenv("QDRANT_URL",     "http://127.0.0.1:6333")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
OLLAMA_URL     = os.getenv("OLLAMA_URL",     "http://localhost:11434")
EMBED_MODEL  = os.getenv("EMBED_MODEL",  "nomic-embed-text")
IPFS_GATEWAY = os.getenv("IPFS_GATEWAY", "http://localhost:8080")
COLLECTION   = "codebase"
VECTOR_SIZE  = 768   # nomic-embed-text:latest (matryoshka 768-dim)
MAX_CHARS    = 2000  # chars par fichier — limite tokens nomic-embed-text (2048t)

WORKSPACE_DEFAULT = str(Path.home() / "workspace" / "AAA")

# Répertoires à indexer (relatifs à CODEBASE_ROOT) et extensions cibles
INDEX_DIRS = [
    ("Astroport.ONE",                         ["sh", "py", "html", "js"]),
    ("UPlanet/earth",                         ["html", "js", "css"]),
    ("UPassport",                             ["py"]),
    ("NIP-101/relay.writePolicy.plugin",      ["sh"]),
]

SKIP_DIRS = frozenset({
    "dist", "build", "__pycache__", "node_modules", ".git",
    ".venv", "venv", "env", "_DOCKER", "docker", ".cache",
})

# ── Helpers ───────────────────────────────────────────────────────────────────

def _session():
    try:
        s = requests.Session()
    except Exception:
        s = requests.Session()
    if QDRANT_API_KEY:
        s.headers.update({"api-key": QDRANT_API_KEY})
    return s


def get_embedding(session, text: str) -> list | None:
    try:
        r = session.post(
            f"{OLLAMA_URL}/api/embed",
            json={"model": EMBED_MODEL, "input": text[:MAX_CHARS]},
            timeout=30,
        )
        if r.ok:
            data = r.json()
            emb = data.get("embeddings") or data.get("embedding")
            if emb:
                return emb[0] if isinstance(emb[0], list) else emb
    except Exception as e:
        print(f"  [EMBED] {e}", file=sys.stderr)
    return None


def path_to_uuid(rel_path: str) -> str:
    h = hashlib.sha256(rel_path.encode()).hexdigest()
    return f"{h[:8]}-{h[8:12]}-4{h[13:16]}-{h[16:20]}-{h[20:32]}"


def ensure_collection(session, reset: bool = False) -> bool:
    if reset:
        session.delete(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=10)
        print(f"  [reset] collection '{COLLECTION}' supprimée", file=sys.stderr)

    r = session.get(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=5)
    if r.ok:
        info = r.json().get("result", {})
        cnt  = info.get("points_count", 0)
        print(f"  [qdrant] collection '{COLLECTION}' — {cnt} points", file=sys.stderr)
        return True

    r = session.put(
        f"{QDRANT_URL}/collections/{COLLECTION}",
        json={
            "vectors": {"size": VECTOR_SIZE, "distance": "Cosine"},
            "optimizers_config": {"indexing_threshold": 200},
            "hnsw_config": {"m": 16, "ef_construct": 100},
        },
        timeout=15,
    )
    if r.ok:
        print(f"  [qdrant] collection '{COLLECTION}' créée (dim={VECTOR_SIZE}, Cosine)", file=sys.stderr)
        return True
    print(f"  [ERROR] création collection : {r.json()}", file=sys.stderr)
    return False


def upsert_file(session, file_path: Path, rel_path: str, project: str) -> bool:
    try:
        content = file_path.read_text(errors="replace")
    except Exception:
        return False

    text   = f"Fichier: {rel_path}\nProjet: {project}\n\n{content[:MAX_CHARS]}"
    vector = get_embedding(session, text)
    if vector is None:
        return False

    mtime   = int(file_path.stat().st_mtime)
    size    = file_path.stat().st_size
    payload = {
        "path":    rel_path,
        "project": project,
        "ext":     file_path.suffix.lstrip("."),
        "mtime":   mtime,
        "size":    size,
        "preview": content[:300],
    }

    r = session.put(
        f"{QDRANT_URL}/collections/{COLLECTION}/points",
        json={"points": [{"id": path_to_uuid(rel_path), "vector": vector, "payload": payload}]},
        timeout=15,
    )
    return bool(r.ok)


def load_existing_mtimes(session) -> dict:
    """Charger les mtimes existants pour la mise à jour incrémentale."""
    existing = {}
    offset   = None
    while True:
        body = {"limit": 1000, "with_payload": ["path", "mtime"]}
        if offset:
            body["offset"] = offset
        try:
            r = session.post(
                f"{QDRANT_URL}/collections/{COLLECTION}/points/scroll",
                json=body, timeout=30,
            )
            if not r.ok:
                break
            result = r.json().get("result", {})
            for pt in result.get("points", []):
                pl = pt.get("payload", {})
                existing[pl.get("path", "")] = pl.get("mtime", 0)
            offset = result.get("next_page_offset")
            if not offset:
                break
        except Exception:
            break
    return existing


# ── Modes principaux ──────────────────────────────────────────────────────────

def do_index(session, workspace: Path, incremental: bool, reset: bool):
    if not ensure_collection(session, reset):
        sys.exit(1)

    existing = load_existing_mtimes(session) if incremental else {}

    total, skipped, errors = 0, 0, 0
    t0 = time.time()

    for subdir, exts in INDEX_DIRS:
        base = workspace / subdir
        if not base.exists():
            print(f"  [SKIP] {subdir} absent", file=sys.stderr)
            continue
        project = subdir.split("/")[0]
        print(f"\n  → {subdir} ({', '.join(exts)})...", file=sys.stderr)

        for ext in exts:
            for fp in sorted(base.rglob(f"*.{ext}")):
                if any(s in fp.parts for s in SKIP_DIRS):
                    continue
                rel = str(fp.relative_to(workspace))

                if incremental and existing.get(rel) == int(fp.stat().st_mtime):
                    skipped += 1
                    continue

                print(f"    {rel} ...", end=" ", flush=True, file=sys.stderr)
                if upsert_file(session, fp, rel, project):
                    print("✓", file=sys.stderr)
                    total += 1
                else:
                    print("✗", file=sys.stderr)
                    errors += 1

    elapsed = time.time() - t0
    print(
        f"\n  ✓ {total} fichiers indexés, {skipped} skippés, {errors} erreurs — {elapsed:.1f}s",
        file=sys.stderr,
    )


def do_search(session, query: str, limit: int, workspace: Path) -> list[dict]:
    vector = get_embedding(session, query)
    if vector is None:
        return []
    try:
        r = session.post(
            f"{QDRANT_URL}/collections/{COLLECTION}/points/search",
            json={"vector": vector, "limit": limit, "with_payload": True},
            timeout=10,
        )
        if r.ok:
            return r.json().get("result", [])
    except Exception as e:
        print(f"  [SEARCH] {e}", file=sys.stderr)
    return []


def do_snapshot_ipfs(session) -> str | None:
    """Créer un snapshot Qdrant et le publier sur IPFS."""
    print("  Création du snapshot...", file=sys.stderr)
    r = session.post(f"{QDRANT_URL}/collections/{COLLECTION}/snapshots", timeout=120)
    if not r.ok:
        print(f"  [ERROR] snapshot : {r.json()}", file=sys.stderr)
        return None

    snap_name = r.json().get("result", {}).get("name", "")
    if not snap_name:
        print("  [ERROR] nom de snapshot manquant", file=sys.stderr)
        return None

    # Télécharger le snapshot
    snap_path = f"/tmp/qdrant_{COLLECTION}.snapshot"
    print(f"  Téléchargement '{snap_name}'...", file=sys.stderr)
    r2 = session.get(
        f"{QDRANT_URL}/collections/{COLLECTION}/snapshots/{snap_name}",
        timeout=300,
    )
    if not r2.ok:
        print("  [ERROR] téléchargement snapshot", file=sys.stderr)
        return None

    with open(snap_path, "wb") as f:
        f.write(r2._data if hasattr(r2, "_data") else r2.content)

    # Publier sur IPFS
    print(f"  Publication IPFS de {snap_path}...", file=sys.stderr)
    res = subprocess.run(["ipfs", "add", "-q", snap_path], capture_output=True, text=True)
    if res.returncode != 0:
        print(f"  [ERROR] ipfs add : {res.stderr}", file=sys.stderr)
        return None

    cid = res.stdout.strip()
    print(f"  Snapshot IPFS : {cid}", file=sys.stderr)

    # Supprimer le snapshot Qdrant local
    session.delete(f"{QDRANT_URL}/collections/{COLLECTION}/snapshots/{snap_name}", timeout=10)
    return cid


def do_restore_ipfs(session, cid: str) -> bool:
    """Restaurer un snapshot depuis IPFS via la gateway locale."""
    gateway_url = f"{IPFS_GATEWAY}/ipfs/{cid}"
    print(f"  Restauration depuis {gateway_url}...", file=sys.stderr)

    # Qdrant peut récupérer le snapshot directement via URL
    r = session.post(
        f"{QDRANT_URL}/collections/{COLLECTION}/snapshots/recover",
        json={"location": gateway_url, "priority": "snapshot"},
        timeout=300,
    )
    if r.ok:
        print("  Restauration réussie.", file=sys.stderr)
        return True
    print(f"  [ERROR] restauration : {r.json()}", file=sys.stderr)
    return False


def do_stats(session):
    r = session.get(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=5)
    if r.ok:
        info = r.json().get("result", {})
        print(json.dumps({
            "collection":    COLLECTION,
            "points_count":  info.get("points_count", 0),
            "vectors_count": info.get("vectors_count", 0),
            "status":        info.get("status", "?"),
            "vector_size":   VECTOR_SIZE,
            "embed_model":   EMBED_MODEL,
        }, indent=2))
    else:
        print(json.dumps({"error": "collection absente ou Qdrant indisponible"}))


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Mémoire vectorielle du codebase UPlanet/Astroport (Qdrant + Ollama)"
    )
    ap.add_argument("--index",       action="store_true",  help="Indexer le codebase")
    ap.add_argument("--incremental", action="store_true",  help="Réindexer seulement les modifiés")
    ap.add_argument("--reset",       action="store_true",  help="Recréer la collection")
    ap.add_argument("--search",      type=str, default="", help="Recherche sémantique")
    ap.add_argument("--limit",       type=int, default=10, help="Nombre de résultats (défaut: 10)")
    ap.add_argument("--snapshot",    action="store_true",  help="Snapshot → IPFS")
    ap.add_argument("--restore",     type=str, default="", help="Restaurer depuis CID IPFS")
    ap.add_argument("--stats",       action="store_true",  help="Statistiques de la collection")
    ap.add_argument("--workspace",   type=str,
                    default=os.getenv("CODEBASE_ROOT", WORKSPACE_DEFAULT))
    args = ap.parse_args()

    workspace = Path(args.workspace).expanduser()
    session   = _session()

    # Vérifier Qdrant (/healthz — /health n'existe pas dans Qdrant ≥1.13)
    try:
        r = session.get(f"{QDRANT_URL}/healthz", timeout=3)
        if not r.ok:
            raise ConnectionError()
    except Exception:
        print(f"[ERREUR] Qdrant non disponible sur {QDRANT_URL}", file=sys.stderr)
        sys.exit(1)

    # Stats
    if args.stats:
        do_stats(session)
        return

    # Snapshot → IPFS
    if args.snapshot:
        cid = do_snapshot_ipfs(session)
        if cid:
            print(cid)  # stdout : le CID pour usage shell
        sys.exit(0 if cid else 1)

    # Restore depuis IPFS
    if args.restore:
        ok = do_restore_ipfs(session, args.restore)
        sys.exit(0 if ok else 1)

    # Recherche sémantique
    if args.search:
        # Vérifier Ollama
        try:
            session.get(f"{OLLAMA_URL}/api/tags", timeout=3)
        except Exception:
            print(f"[ERREUR] Ollama non disponible sur {OLLAMA_URL}", file=sys.stderr)
            sys.exit(1)

        hits = do_search(session, args.search, args.limit, workspace)
        for hit in hits:
            p     = hit.get("payload", {})
            score = hit.get("score", 0.0)
            path  = p.get("path", "")
            # Output: score<TAB>path — parsable par bash
            print(f"{score:.4f}\t{path}")
        return

    # Indexation
    if args.index or args.incremental:
        # Vérifier Ollama + modèle
        try:
            r = session.get(f"{OLLAMA_URL}/api/tags", timeout=5)
            models = [m.get("name", "") for m in r.json().get("models", [])]
            if not any(EMBED_MODEL.split(":")[0] in m for m in models):
                print(
                    f"[ERREUR] Modèle '{EMBED_MODEL}' absent. Lancer : ollama pull {EMBED_MODEL}",
                    file=sys.stderr,
                )
                sys.exit(1)
        except Exception:
            print(f"[ERREUR] Ollama non disponible sur {OLLAMA_URL}", file=sys.stderr)
            sys.exit(1)

        do_index(session, workspace, incremental=args.incremental, reset=args.reset)
        return

    ap.print_help()


if __name__ == "__main__":
    main()
