#!/usr/bin/env python3
"""
knowledge_index.py — Mémoire vectorielle des connaissances WoTx2

Indexe les documents de formation (.md, .pdf) liés aux skills WoTx2
dans Qdrant pour la recherche sémantique par BRO (#rec) et MineLife.

Sources :
  1. Relay NOSTR  — Kind 30504 (ressources formation) + Kind 30500 (r tags)
  2. uDRIVE local — ~/.zen/game/players/<G1PUB>/Documents/
  3. Répertoire libre — Nextcloud, dossier admin, etc.

Collection Qdrant : "knowledge"
Payload par point  :
  cid        — CID IPFS du fichier (ou "" pour fichiers locaux non publiés)
  title      — titre du document
  type       — document | cours | video | audio | image | lien
  skill      — skill principal (premier tag t non méta)
  skills     — liste de tous les skills associés
  author_hex — pubkey NOSTR hex de l'auteur
  event_id   — NOSTR event ID source (ou "")
  kind       — 30504 | 30500 | 0 (local)
  relay      — relay NOSTR source (ou "local")
  created_at — timestamp UNIX

Sortie --search : score<TAB>cid<TAB>author_hex<TAB>title<TAB>skill
(parseable par BRO et minelife.js)

Variables d'environnement :
  QDRANT_URL      http://127.0.0.1:6333
  QDRANT_API_KEY  (optionnel)
  OLLAMA_URL      http://localhost:11434
  EMBED_MODEL     nomic-embed-text
  IPFS_GATEWAY    http://localhost:8080
  NOSTR_RELAY     ws://localhost:7777
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
import io
import json
import time
import hashlib
import argparse
import subprocess
from pathlib import Path

try:
    import requests
except ImportError:
    import urllib.request
    import urllib.error

    class _FakeResp:
        def __init__(self, data, status):
            self._data = data
            self.status_code = status
            self.ok = 200 <= status < 300
            self.content = data
        def json(self): return json.loads(self._data)

    class _Session:
        def _call(self, method, url, **kw):
            data = json.dumps(kw.get("json", {})).encode() if kw.get("json") else b""
            hdrs = dict(self.headers) if hasattr(self, "headers") else {}
            hdrs.setdefault("Content-Type", "application/json")
            req = urllib.request.Request(url, data=data or None,
                                         headers=hdrs, method=method.upper())
            try:
                with urllib.request.urlopen(req, timeout=kw.get("timeout", 30)) as r:
                    body = r.read()
                    return _FakeResp(body, r.status)
            except urllib.error.HTTPError as e:
                return _FakeResp(b"{}", e.code)
            except Exception:
                return _FakeResp(b"{}", 0)
        def get(self, url, **kw):    return self._call("GET",    url, **kw)
        def post(self, url, **kw):   return self._call("POST",   url, **kw)
        def put(self, url, **kw):    return self._call("PUT",    url, **kw)
        def delete(self, url, **kw): return self._call("DELETE", url, **kw)
        def headers_update(self, h): self.headers = h
    _SessionCls = _Session
    requests = type("requests", (), {"Session": _SessionCls})()

# ── Configuration ─────────────────────────────────────────────────────────────
QDRANT_URL     = os.getenv("QDRANT_URL",     "http://127.0.0.1:6333")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
OLLAMA_URL     = os.getenv("OLLAMA_URL",     "http://localhost:11434")
EMBED_MODEL    = os.getenv("EMBED_MODEL",    "nomic-embed-text")
IPFS_GATEWAY   = os.getenv("IPFS_GATEWAY",   "http://localhost:8080")
NOSTR_RELAY    = os.getenv("NOSTR_RELAY",    "ws://localhost:7777")
COLLECTION     = "knowledge"
VECTOR_SIZE    = 768   # nomic-embed-text
MAX_CHARS      = 2000  # limite tokens nomic-embed-text (2048t)

# Tags méta exclus de la liste des skills
_META_T = frozenset({"permit", "auto_proclaimed", "composite", "formation",
                     "training", "attestation", "request"})

# ── Helpers Qdrant ────────────────────────────────────────────────────────────

def _session():
    s = requests.Session()
    if QDRANT_API_KEY:
        s.headers.update({"api-key": QDRANT_API_KEY})
    return s


def _path_to_uuid(key: str) -> str:
    h = hashlib.sha256(key.encode()).hexdigest()
    return f"{h[:8]}-{h[8:12]}-4{h[13:16]}-{h[16:20]}-{h[20:32]}"


def ensure_collection(session) -> bool:
    r = session.get(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=5)
    if r.ok:
        cnt = r.json().get("result", {}).get("points_count", 0)
        print(f"  [qdrant] collection '{COLLECTION}' — {cnt} points", file=sys.stderr)
        return True
    r = session.put(
        f"{QDRANT_URL}/collections/{COLLECTION}",
        json={
            "vectors": {"size": VECTOR_SIZE, "distance": "Cosine"},
            "optimizers_config": {"indexing_threshold": 50},
        },
        timeout=15,
    )
    if r.ok:
        print(f"  [qdrant] collection '{COLLECTION}' créée (dim={VECTOR_SIZE})", file=sys.stderr)
        return True
    print(f"  [ERROR] création collection : {r.json()}", file=sys.stderr)
    return False


def _upsert(session, point_id: str, vector: list, payload: dict) -> bool:
    r = session.put(
        f"{QDRANT_URL}/collections/{COLLECTION}/points",
        json={"points": [{"id": point_id, "vector": vector, "payload": payload}]},
        timeout=15,
    )
    return r.ok


# ── Embedding ─────────────────────────────────────────────────────────────────

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


# ── IPFS ──────────────────────────────────────────────────────────────────────

def ipfs_get(cid: str) -> bytes | None:
    cid = cid.strip().lstrip("/").removeprefix("ipfs/")
    url = f"{IPFS_GATEWAY}/ipfs/{cid}"
    try:
        r = requests.Session().get(url, timeout=30)
        if r.ok:
            return r.content
    except Exception as e:
        print(f"  [IPFS] {cid[:16]}… : {e}", file=sys.stderr)
    return None


def extract_text(data: bytes, filename: str) -> str:
    """Extrait le texte depuis .md (direct) ou .pdf (pdfplumber/PyPDF2)."""
    fname = filename.lower()
    if fname.endswith(".pdf"):
        try:
            import pdfplumber
            with pdfplumber.open(io.BytesIO(data)) as pdf:
                pages = [p.extract_text() or "" for p in pdf.pages[:8]]
                return "\n".join(pages)
        except ImportError:
            pass
        try:
            import PyPDF2  # noqa: N813
            reader = PyPDF2.PdfReader(io.BytesIO(data))
            return "\n".join(p.extract_text() or "" for p in reader.pages[:8])
        except ImportError:
            return f"[PDF: {filename} — pip install pdfplumber pour extraction]"
        except Exception as e:
            return f"[PDF erreur: {e}]"
    return data.decode("utf-8", errors="replace")


# ── NOSTR query via nostr_node_intercom.py ────────────────────────────────────

def _intercom_path(workspace: Path) -> Path:
    candidates = [
        workspace / "Astroport.ONE" / "tools" / "nostr_node_intercom.py",
        Path.home() / ".zen" / "Astroport.ONE" / "tools" / "nostr_node_intercom.py",
    ]
    for c in candidates:
        if c.exists():
            return c
    return candidates[0]


def fetch_nostr_events(relay: str, kinds: list[int], workspace: Path,
                       limit: int = 500) -> list[dict]:
    intercom = _intercom_path(workspace)
    if not intercom.exists():
        print(f"  [WARN] nostr_node_intercom.py introuvable : {intercom}", file=sys.stderr)
        return []
    filter_json = json.dumps({"kinds": kinds, "limit": limit})
    try:
        res = subprocess.run(
            [sys.executable, str(intercom), "query",
             "--filter", filter_json, "--relays", relay],
            capture_output=True, text=True, timeout=30,
        )
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout.strip())
    except subprocess.TimeoutExpired:
        print("  [WARN] timeout relay NOSTR", file=sys.stderr)
    except Exception as e:
        print(f"  [WARN] nostr query : {e}", file=sys.stderr)
    return []


# ── Parsers ────────────────────────────────────────────────────────────────────

def _tags_get(tags: list, key: str) -> list[list]:
    return [t for t in tags if t and t[0] == key]


def _tag_first(tags: list, key: str, default: str = "") -> str:
    for t in tags:
        if t and t[0] == key and len(t) > 1:
            return t[1]
    return default


def skills_from_tags(tags: list) -> list[str]:
    return [t[1] for t in tags if t and t[0] == "t" and len(t) > 1
            and t[1] not in _META_T]


def r_tags_ipfs(tags: list) -> list[tuple[str, str]]:
    """Retourne [(cid_or_url, type)] pour les tags r avec chemin IPFS."""
    result = []
    for t in tags:
        if not t or t[0] != "r" or len(t) < 2:
            continue
        url = t[1]
        rtype = t[2] if len(t) > 2 else "document"
        if "/ipfs/" in url or url.startswith("Qm") or url.startswith("bafy"):
            # Extraire le CID
            if "/ipfs/" in url:
                cid = url.split("/ipfs/")[-1].split("/")[0].split("?")[0]
            else:
                cid = url
            if cid:
                result.append((cid, rtype))
    return result


# ── Indexation NOSTR ──────────────────────────────────────────────────────────

def index_nostr(session, relay: str, workspace: Path):
    print(f"\n  → Fetch Kind 30504 + 30500 depuis {relay}...", file=sys.stderr)
    events = fetch_nostr_events(relay, [30504, 30500], workspace)
    if not events:
        print("  [WARN] aucun event récupéré (relay inaccessible?)", file=sys.stderr)
        return 0, 0

    ok_count = err_count = 0
    for ev in events:
        tags      = ev.get("tags", [])
        author    = ev.get("pubkey", "")
        kind      = ev.get("kind", 0)
        event_id  = ev.get("id", "")
        created   = ev.get("created_at", 0)

        # Titre depuis tags ou content JSON
        title = _tag_first(tags, "title")
        if not title:
            try:
                c = json.loads(ev.get("content", "{}"))
                title = c.get("name") or c.get("description") or c.get("title") or ""
            except Exception:
                pass

        skills = skills_from_tags(tags)
        primary_skill = skills[0] if skills else "unknown"

        for cid, rtype in r_tags_ipfs(tags):
            # Types non-textuels → on indexe juste les métadonnées (pas de téléchargement)
            if rtype in ("video", "audio", "image"):
                embed_text = (
                    f"Ressource {rtype} WoTx2 : {title or cid}\n"
                    f"Skill: {primary_skill}\nType: {rtype}"
                )
                text_for_embed = embed_text
            else:
                # Téléchargement et extraction du contenu
                print(f"    {cid[:20]}… [{rtype}] ...", end=" ", flush=True, file=sys.stderr)
                raw = ipfs_get(cid)
                if raw is None:
                    print("✗ (IPFS indisponible)", file=sys.stderr)
                    err_count += 1
                    continue
                filename = f"doc.{rtype}" if rtype != "cours" else "doc.md"
                text_for_embed = (
                    f"Skill: {primary_skill}\nTitre: {title}\nType: {rtype}\n\n"
                    + extract_text(raw, filename)
                )

            vector = get_embedding(session, text_for_embed)
            if vector is None:
                print("✗ (embed)", file=sys.stderr)
                err_count += 1
                continue

            point_id = _path_to_uuid(f"{event_id}:{cid}")
            payload = {
                "cid": cid, "title": title or cid[:20], "type": rtype,
                "skill": primary_skill, "skills": skills,
                "author_hex": author, "event_id": event_id,
                "kind": kind, "relay": relay, "created_at": created,
            }
            if _upsert(session, point_id, vector, payload):
                print("✓", file=sys.stderr)
                ok_count += 1
            else:
                print("✗ (upsert)", file=sys.stderr)
                err_count += 1

    print(f"\n  ✓ NOSTR: {ok_count} docs indexés, {err_count} erreurs", file=sys.stderr)
    return ok_count, err_count


# ── Indexation uDRIVE ─────────────────────────────────────────────────────────

def index_udrive(session, udrive_root: Path | None = None):
    """
    Indexe les .md et .pdf depuis les répertoires uDRIVE locaux.

    Structure attendue :
      ~/.zen/game/players/<G1PUB>/Documents/   (.md, .pdf)
      ~/.zen/game/players/<G1PUB>/Astroport/   (.md, .pdf)
    ou tout répertoire passé en argument.
    """
    roots = []
    if udrive_root:
        roots = [udrive_root]
    else:
        players_dir = Path.home() / ".zen" / "game" / "players"
        if players_dir.exists():
            for player_dir in players_dir.iterdir():
                for sub in ["Documents", "Astroport", "Formation", "Skills"]:
                    d = player_dir / sub
                    if d.is_dir():
                        roots.append(d)

    if not roots:
        print("  [INFO] Aucun répertoire uDRIVE trouvé", file=sys.stderr)
        return 0, 0

    ok_count = err_count = 0
    for root in roots:
        # Extraire G1PUB depuis le chemin (~/.zen/game/players/<G1PUB>/...)
        parts = root.parts
        author_label = ""
        if "players" in parts:
            idx = list(parts).index("players")
            if idx + 1 < len(parts):
                author_label = parts[idx + 1]  # G1PUB comme identifiant

        print(f"\n  → uDRIVE {root} ...", file=sys.stderr)
        for ext in ["md", "pdf"]:
            for fp in sorted(root.rglob(f"*.{ext}")):
                rel = str(fp.relative_to(root))
                print(f"    {rel} ...", end=" ", flush=True, file=sys.stderr)
                try:
                    raw = fp.read_bytes()
                except Exception:
                    print("✗ (lecture)", file=sys.stderr)
                    err_count += 1
                    continue

                text = extract_text(raw, fp.name)
                skill_guess = fp.parent.name.lower().replace("-", "_")
                title = fp.stem.replace("_", " ").replace("-", " ")

                embed_text = f"Titre: {title}\nSkill: {skill_guess}\n\n{text}"
                vector = get_embedding(session, embed_text)
                if vector is None:
                    print("✗ (embed)", file=sys.stderr)
                    err_count += 1
                    continue

                point_id = _path_to_uuid(str(fp))
                payload = {
                    "cid": "", "title": title, "type": ext,
                    "skill": skill_guess, "skills": [skill_guess],
                    "author_hex": author_label,
                    "event_id": "", "kind": 0, "relay": "local",
                    "created_at": int(fp.stat().st_mtime),
                    "local_path": str(fp),
                }
                if _upsert(session, point_id, vector, payload):
                    print("✓", file=sys.stderr)
                    ok_count += 1
                else:
                    print("✗ (upsert)", file=sys.stderr)
                    err_count += 1

    print(f"\n  ✓ uDRIVE: {ok_count} docs indexés, {err_count} erreurs", file=sys.stderr)
    return ok_count, err_count


# ── Indexation répertoire libre ───────────────────────────────────────────────

def index_directory(session, path: Path, author_hex: str = "", skill_hint: str = ""):
    """Indexe récursivement un répertoire de documents (.md, .pdf)."""
    if not path.exists():
        print(f"  [WARN] répertoire absent : {path}", file=sys.stderr)
        return 0, 0

    ok_count = err_count = 0
    print(f"\n  → Répertoire {path} ...", file=sys.stderr)
    for ext in ["md", "pdf"]:
        for fp in sorted(path.rglob(f"*.{ext}")):
            rel = str(fp.relative_to(path))
            print(f"    {rel} ...", end=" ", flush=True, file=sys.stderr)
            try:
                raw = fp.read_bytes()
            except Exception:
                print("✗ (lecture)", file=sys.stderr)
                err_count += 1
                continue

            text = extract_text(raw, fp.name)
            skill = skill_hint or fp.parent.name.lower().replace("-", "_") or "unknown"
            title = fp.stem.replace("_", " ").replace("-", " ")

            embed_text = f"Titre: {title}\nSkill: {skill}\n\n{text}"
            vector = get_embedding(session, embed_text)
            if vector is None:
                print("✗ (embed)", file=sys.stderr)
                err_count += 1
                continue

            point_id = _path_to_uuid(str(fp))
            payload = {
                "cid": "", "title": title, "type": ext,
                "skill": skill, "skills": [skill],
                "author_hex": author_hex,
                "event_id": "", "kind": 0, "relay": "local",
                "created_at": int(fp.stat().st_mtime),
                "local_path": str(fp),
            }
            if _upsert(session, point_id, vector, payload):
                print("✓", file=sys.stderr)
                ok_count += 1
            else:
                print("✗ (upsert)", file=sys.stderr)
                err_count += 1

    print(f"\n  ✓ Répertoire: {ok_count} docs indexés, {err_count} erreurs", file=sys.stderr)
    return ok_count, err_count


# ── Recherche ─────────────────────────────────────────────────────────────────

def do_search(session, query: str, skill_filter: str, limit: int) -> list[dict]:
    vector = get_embedding(session, query)
    if vector is None:
        return []
    body: dict = {
        "vector": vector, "limit": limit, "with_payload": True
    }
    if skill_filter:
        body["filter"] = {
            "should": [
                {"key": "skill",  "match": {"value": skill_filter}},
                {"key": "skills", "match": {"value": skill_filter}},
            ]
        }
    try:
        r = session.post(
            f"{QDRANT_URL}/collections/{COLLECTION}/points/search",
            json=body, timeout=10,
        )
        if r.ok:
            return r.json().get("result", [])
    except Exception as e:
        print(f"  [SEARCH] {e}", file=sys.stderr)
    return []


def do_stats(session):
    r = session.get(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=5)
    if r.ok:
        info = r.json().get("result", {})
        print(json.dumps({
            "collection":   COLLECTION,
            "points_count": info.get("points_count", 0),
            "status":       info.get("status", "?"),
            "vector_size":  VECTOR_SIZE,
            "embed_model":  EMBED_MODEL,
        }, indent=2))
    else:
        print(json.dumps({"error": "collection absente ou Qdrant indisponible"}))


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Mémoire vectorielle des connaissances WoTx2 (Qdrant + IPFS + NOSTR)"
    )
    ap.add_argument("--index-nostr",  action="store_true",
                    help="Indexer Kind 30504/30500 depuis relay NOSTR")
    ap.add_argument("--index-udrive", action="store_true",
                    help="Indexer les .md/.pdf depuis uDRIVE local")
    ap.add_argument("--index-dir",    type=str, default="",
                    help="Indexer un répertoire libre de documents")
    ap.add_argument("--reset",        action="store_true",
                    help="Supprimer et recréer la collection knowledge")
    ap.add_argument("--search",       type=str, default="",
                    help="Recherche sémantique")
    ap.add_argument("--skill",        type=str, default="",
                    help="Filtrer la recherche sur un skill")
    ap.add_argument("--limit",        type=int, default=10,
                    help="Nombre de résultats (défaut: 10)")
    ap.add_argument("--relay",        type=str,
                    default=os.getenv("NOSTR_RELAY", NOSTR_RELAY),
                    help=f"Relay NOSTR (défaut: {NOSTR_RELAY})")
    ap.add_argument("--author",       type=str, default="",
                    help="Pubkey hex de l'auteur (pour --index-dir)")
    ap.add_argument("--skill-hint",   type=str, default="",
                    help="Skill par défaut (pour --index-dir)")
    ap.add_argument("--workspace",    type=str,
                    default=os.getenv("CODEBASE_ROOT",
                                      str(Path.home() / "workspace" / "AAA")))
    ap.add_argument("--stats",        action="store_true",
                    help="Stats de la collection knowledge")
    args = ap.parse_args()

    session = _session()

    # Vérifier Qdrant
    try:
        r = session.get(f"{QDRANT_URL}/healthz", timeout=3)
        if not r.ok:
            raise ConnectionError()
    except Exception:
        print(f"[ERREUR] Qdrant non disponible sur {QDRANT_URL}", file=sys.stderr)
        sys.exit(1)

    if args.stats:
        do_stats(session)
        return

    if args.search:
        hits = do_search(session, args.search, args.skill, args.limit)
        for h in hits:
            pl = h.get("payload", {})
            score  = h.get("score", 0)
            cid    = pl.get("cid", "")
            author = pl.get("author_hex", "")
            title  = pl.get("title", "")
            skill  = pl.get("skill", "")
            lpath  = pl.get("local_path", "")
            ref    = f"/ipfs/{cid}" if cid else lpath
            print(f"{score:.4f}\t{ref}\t{author}\t{title}\t{skill}")
        return

    if args.reset:
        session.delete(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=10)
        print(f"  [reset] collection '{COLLECTION}' supprimée", file=sys.stderr)

    if not ensure_collection(session):
        sys.exit(1)

    workspace = Path(args.workspace).expanduser()
    total_ok = total_err = 0

    if args.index_nostr:
        ok, err = index_nostr(session, args.relay, workspace)
        total_ok += ok; total_err += err

    if args.index_udrive:
        ok, err = index_udrive(session)
        total_ok += ok; total_err += err

    if args.index_dir:
        ok, err = index_directory(
            session, Path(args.index_dir).expanduser(),
            author_hex=args.author, skill_hint=args.skill_hint
        )
        total_ok += ok; total_err += err

    if not (args.index_nostr or args.index_udrive or args.index_dir):
        ap.print_help()
        sys.exit(0)

    print(f"\n  TOTAL knowledge: {total_ok} docs indexés, {total_err} erreurs",
          file=sys.stderr)


if __name__ == "__main__":
    main()
