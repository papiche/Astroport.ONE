#!/usr/bin/env python3
"""
codebase_index.py — Mémoire vectorielle du code source (Qdrant + embed_config.py : bge-m3).

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
  EMBED_MODEL     (défaut : embed_config.MODEL = bge-m3)
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
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "IA"))
import embed_config   # modèle d'embedding UNIQUE de la plateforme (bge-m3)
import code_chunker   # découpe en fonctions / classes / blocs
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
EMBED_MODEL  = os.getenv("EMBED_MODEL",  embed_config.MODEL)
IPFS_GATEWAY = os.getenv("IPFS_GATEWAY", "http://localhost:8080")
COLLECTION   = "codebase"
VECTOR_SIZE  = int(os.getenv("EMBED_DIM", embed_config.DIM))
MAX_CHARS    = 6000  # chars par fichier (≈ 2 000 tokens ; bge-m3 en accepte 8 000 — nomic plafonnait à 2 000 car.)

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

def _roots(workspace: Path) -> list:
    """Où chercher chaque répertoire d'INDEX_DIRS. Deux dispositions réelles :
      • dépôt de travail  ~/workspace/AAA/{Astroport.ONE,UPassport,UPlanet,NIP-101}  (frères)
      • station           ~/.zen/{Astroport.ONE,UPassport}  +  ~/.zen/workspace/{NIP-101,UPlanet}
    (les liens de ~/.zen pointent vers le dépôt de travail). Chaque répertoire est cherché dans l'ordre
    sous : la racine demandée, sa sous-dossier workspace/, ~/.zen, ~/.zen/workspace."""
    zen = Path.home() / ".zen"
    out, seen = [], set()
    for r in (workspace, workspace / "workspace", zen, zen / "workspace"):
        key = str(r)
        if key not in seen:
            seen.add(key)
            out.append(r)
    return out


def _resolve(workspace: Path, subdir: str):
    """(racine, chemin) du premier emplacement existant pour `subdir`, sinon (None, None)."""
    for root in _roots(workspace):
        if (root / subdir).exists():
            return root, root / subdir
    return None, None


def _session():
    try:
        s = requests.Session()
    except Exception:
        s = requests.Session()
    if QDRANT_API_KEY:
        s.headers.update({"api-key": QDRANT_API_KEY})
    return s


def get_embedding(session, text: str) -> list | None:
    """Un vecteur (requêtes de recherche)."""
    out = get_embeddings(session, [text])
    return out[0] if out else None


def get_embeddings(session, texts: list, retries: int = 2) -> list | None:
    """Vecteurs d'un LOT de textes en un seul appel Ollama (/api/embed accepte une liste) ; tout ou rien,
    avec reprises : un lot raté ne doit pas laisser un fichier à moitié indexé."""
    last = None
    try:                                         # GPU partagé avec ComfyUI : jamais de chargement sans place (gpu_headroom.py)
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "IA"))
        import gpu_headroom
        gpu_headroom.ensure(EMBED_MODEL, wait=300)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return None
    import ollama_metrics                        # mesure de chaque appel au GPU partagé
    for attempt in range(retries + 1):
        _t0 = ollama_metrics.start()
        try:
            r = session.post(
                f"{OLLAMA_URL}/api/embed",
                json={"model": EMBED_MODEL, "input": [t[:MAX_CHARS] for t in texts]},
                timeout=120,
            )
            ollama_metrics.record("embed", EMBED_MODEL, _t0, resp=r.json() if r.ok else None, ok=r.ok,
                                  error=None if r.ok else f"HTTP {r.status_code}", n_inputs=len(texts))
            if r.ok:
                embs = r.json().get("embeddings") or []
                if len(embs) == len(texts) and all(isinstance(e, list) and len(e) == VECTOR_SIZE for e in embs):
                    return embs
                last = f"réponse inattendue ({len(embs)} vecteurs pour {len(texts)} textes)"
            else:
                last = f"HTTP {r.status_code}"
        except Exception as e:
            last = str(e)
    print(f"  [EMBED] échec après {retries + 1} essais : {last}", file=sys.stderr)
    return None


def path_to_uuid(rel_path: str) -> str:
    h = hashlib.sha256(rel_path.encode()).hexdigest()
    return f"{h[:8]}-{h[8:12]}-4{h[13:16]}-{h[16:20]}-{h[20:32]}"


def _recreate_if_dim_differs(session, have_dim):
    """Collection d'INDEX (reconstructible en relançant ce script) : dimension ≠ modèle courant → on la
    supprime et on la recrée, en le disant, plutôt que de mélanger deux espaces vectoriels."""
    if have_dim and int(have_dim) != VECTOR_SIZE:
        print(f"  [qdrant] ❌ '{COLLECTION}' : {have_dim} d ≠ {VECTOR_SIZE} d ({EMBED_MODEL}) — recréée, tout sera ré-indexé",
              file=sys.stderr)
        session.delete(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=15)
        return True
    return False


def ensure_collection(session, reset: bool = False) -> bool:
    if reset:
        session.delete(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=10)
        print(f"  [reset] collection '{COLLECTION}' supprimée", file=sys.stderr)

    r = session.get(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=5)
    if r.ok and _recreate_if_dim_differs(session, ((r.json().get("result", {}).get("config", {}).get("params", {})
                                                    .get("vectors") or {}).get("size"))):
        r = session.get(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=5)   # 404 : sera recréée ci-dessous
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


def _is_vendored_or_minified(file_path: Path, content: str) -> bool:
    """Bibliothèques tierces embarquées (jspdf.umd.min.js, mermaid.min.js, nostr.bundle.js…) : jamais indexées —
    une ligne de 400 000 caractères n'a pas de « fonction » à retrouver et ferait échouer l'embedding."""
    name = file_path.name.lower()
    if ".min." in name or name.endswith(("-min.js", ".bundle.js", ".umd.js")):
        return True
    lines = content.split("\n")
    return len(content) > 20000 and (len(content) / max(1, len(lines))) > 300      # minifié : lignes énormes


def _chunk_id(rel_path: str, symbol: str, start: int) -> str:
    return path_to_uuid(f"{rel_path}#{symbol}#{start}")


def upsert_file(session, file_path: Path, rel_path: str, project: str):
    """Indexe UN fichier en morceaux (une fonction / classe / bloc chacun, cf. code_chunker.py).
    Retourne le nombre de morceaux écrits, None s'il n'y a rien à indexer (trivial / tiers), 0 en cas d'échec — auquel cas les anciens morceaux du fichier
    sont CONSERVÉS (on ne remplace qu'après avoir obtenu tous les vecteurs)."""
    try:
        content = file_path.read_text(errors="replace")
    except Exception:
        return 0
    ext = file_path.suffix.lstrip(".")
    if _is_vendored_or_minified(file_path, content):
        return None                              # bibliothèque tierce : du bruit pour la recherche, pas du code du projet
    chunks = code_chunker.chunk_file(content, ext)
    if not chunks:
        return None                              # fichier trivial (__init__.py vide…) : rien à indexer, pas une erreur
    texts = [f"{rel_path} — {c['symbol']} ({c['kind']})\n{c['text']}" for c in chunks]
    vectors = []
    for i in range(0, len(texts), 16):
        embs = get_embeddings(session, texts[i:i + 16])
        if embs is None:
            return 0
        vectors.extend(embs)

    mtime = int(file_path.stat().st_mtime)
    points = [{
        "id": _chunk_id(rel_path, c["symbol"], c["start_line"]),
        "vector": v,
        "payload": {
            "path": rel_path, "project": project, "ext": ext, "mtime": mtime,
            "symbol": c["symbol"], "kind": c["kind"],
            "start_line": c["start_line"], "end_line": c["end_line"],
            "text": c["text"], "preview": c["text"][:300],
        },
    } for c, v in zip(chunks, vectors)]

    # Remplacement : anciens morceaux du fichier supprimés, puis nouveaux écrits.
    d = session.post(f"{QDRANT_URL}/collections/{COLLECTION}/points/delete",
                     json={"filter": {"must": [{"key": "path", "match": {"value": rel_path}}]}}, timeout=30)
    if not d.ok:
        print(f"  [WARN] suppression des anciens morceaux de {rel_path} : HTTP {d.status_code}", file=sys.stderr)
    for i in range(0, len(points), 64):
        r = session.put(f"{QDRANT_URL}/collections/{COLLECTION}/points",
                        json={"points": points[i:i + 64]}, timeout=60)
        if not r.ok:
            print(f"  [ERROR] écriture de {rel_path} : HTTP {r.status_code}", file=sys.stderr)
            return 0
    return len(points)


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

    total, skipped, errors, chunks_total = 0, 0, 0, 0
    t0 = time.time()

    for subdir, exts in INDEX_DIRS:
        root, base = _resolve(workspace, subdir)
        if base is None:
            tried = ", ".join(str(r) for r in _roots(workspace))
            print(f"  [SKIP] {subdir} introuvable (cherché sous : {tried})", file=sys.stderr)
            continue
        project = subdir.split("/")[0]
        print(f"\n  → {subdir} ({', '.join(exts)})...", file=sys.stderr)

        for ext in exts:
            for fp in sorted(base.rglob(f"*.{ext}")):
                if any(s in fp.parts for s in SKIP_DIRS):
                    continue
                rel = str(fp.relative_to(root))      # chemin LOGIQUE (« UPlanet/earth/… »), identique sur toute disposition

                if incremental and existing.get(rel) == int(fp.stat().st_mtime):
                    skipped += 1
                    continue

                print(f"    {rel} ...", end=" ", flush=True, file=sys.stderr)
                n = upsert_file(session, fp, rel, project)
                if n is None:
                    print("— (rien à indexer)", file=sys.stderr)
                    skipped += 1
                elif n:
                    print(f"✓ ({n} morceaux)", file=sys.stderr)
                    total += 1
                    chunks_total += n
                else:
                    print("✗", file=sys.stderr)
                    errors += 1

    elapsed = time.time() - t0
    print(
        f"\n  ✓ {total} fichiers indexés ({chunks_total} morceaux), {skipped} skippés, {errors} erreurs — {elapsed:.1f}s",
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
            # Sortie : score<TAB>chemin<TAB>ligne<TAB>symbole — les deux premières colonnes comme avant (parsable par bash)
            print(f"{score:.4f}\t{path}\t{p.get('start_line', '')}\t{p.get('symbol', '')}")
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
