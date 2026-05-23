#!/usr/bin/env python3
"""
memory_manager.py — Gestionnaire unifié de mémoire Qdrant pour UPlanet/Astroport

Architecture des collections :
  uplanet_geo       — mémoires de lieu (multi-utilisateurs, par coordonnée GPS)
  memory_{hex16}    — mémoires personnelles par slot (per-MULTIPASS)
  station_skills    — base de connaissance collective partagée par skill

Cycle ÉVEIL/RÊVE :
  Lorsqu'un slot ou une mémoire géo atteint REVE_THRESHOLD entrées,
  Ollama résume les anciennes en une entrée [RÊVE] compacte (compression lossy).
  Les REVE_KEEP entrées les plus récentes sont préservées telles quelles.
  Le résumé est ré-embedé et upserted dans Qdrant pour rester requêtable.

Partage inter-node des skills :
  skill_hash()     — hash SHA256 du fichier skill local (clé de conflit)
  skill_content()  — contenu brut du fichier skill

Usage bash :
  python3 memory_manager.py ensure-collections
  python3 memory_manager.py upsert-geo   --lat 43.6 --lon 1.4 --content "..." --pubkey hex
  python3 memory_manager.py upsert-slot  --user-id email --slot 0 --content "..."
  python3 memory_manager.py upsert-skill --skill devops --content "..." --npub hex
  python3 memory_manager.py reve         --user-id email --slot 0
  python3 memory_manager.py reve-geo     --lat 43.6 --lon 1.4
  python3 memory_manager.py skill-hash   --skill devops
  python3 memory_manager.py backup       --output /tmp/qdrant_backup.json
"""

import os, sys, hashlib, json, subprocess
from datetime import datetime

# ── Venv ~/.astro ──────────────────────────────────────────────────────────────
_venv = os.path.expanduser("~/.astro")
if os.path.exists(_venv):
    _pyv = f"python{sys.version_info.major}.{sys.version_info.minor}"
    _sp  = os.path.join(_venv, "lib", _pyv, "site-packages")
    if os.path.exists(_sp):
        sys.path.insert(0, _sp)

# ── Configuration (overridable via env) ──────────────────────────────────────
QDRANT_URL     = os.environ.get("QDRANT_URL",     "http://127.0.0.1:6333")
QDRANT_API_KEY = os.environ.get("QDRANT_API_KEY", "")
OLLAMA_URL     = os.environ.get("OLLAMA_URL",     "http://127.0.0.1:11434")
EMBED_MODEL    = "nomic-embed-text"
OLLAMA_MODEL   = os.environ.get("OLLAMA_MODEL",   "llama3.2")
VECTOR_SIZE    = 768

# Seuil de compression : ~2-3 mois d'activité quotidienne avant premier RÊVE
# Après RÊVE : [1 résumé] + [80 récents] = 81 → prochain RÊVE à 150 de nouveau
REVE_THRESHOLD = 150
REVE_KEEP      = 80

FLASHMEM_BASE  = os.path.expanduser("~/.zen/tmp/flashmem")
SKILLS_DIR     = os.path.join(FLASHMEM_BASE, "skills")
GEO_DIR        = os.path.join(FLASHMEM_BASE, "uplanet_memory")


# ─────────────────────────────── helpers ──────────────────────────────────────

def _user_hex(user_id: str) -> str:
    """Dérive les 16 premiers chars du HEX du MULTIPASS, ou MD5 de l'email."""
    hex_file = os.path.expanduser(f"~/.zen/game/nostr/{user_id}/HEX")
    if os.path.isfile(hex_file):
        with open(hex_file) as f:
            return f.read().strip()[:16]
    return hashlib.md5(user_id.encode()).hexdigest()[:16]


def _stable_id(*parts) -> int:
    """ID Qdrant stable (int 63-bit) basé sur les parties fournies."""
    h = hashlib.md5(":".join(str(p) for p in parts).encode()).hexdigest()[:15]
    return int(h, 16)


def _auth_headers() -> list:
    if QDRANT_API_KEY:
        return ["-H", f"api-key: {QDRANT_API_KEY}"]
    return []


def _curl(method: str, url: str, payload: dict = None) -> dict:
    """Appel HTTP via curl — évite la dépendance qdrant_client dans ce module."""
    cmd = ["curl", "-sf", "-X", method, url, "-H", "Content-Type: application/json"]
    cmd.extend(_auth_headers())
    if payload is not None:
        cmd += ["-d", json.dumps(payload)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if r.returncode != 0 or not r.stdout.strip():
            return {}
        return json.loads(r.stdout)
    except Exception:
        return {}


def _embed(text: str) -> list:
    r = _curl("POST", f"{OLLAMA_URL}/api/embeddings",
              {"model": EMBED_MODEL, "prompt": text})
    return r.get("embedding", [])


def _qdrant_available() -> bool:
    r = _curl("GET", f"{QDRANT_URL}/healthz")
    return bool(r)


# ──────────────────────────── collections ─────────────────────────────────────

def ensure_collection(name: str, size: int = VECTOR_SIZE):
    """Crée la collection si elle n'existe pas (idempotent)."""
    _curl("PUT", f"{QDRANT_URL}/collections/{name}",
          {"vectors": {"size": size, "distance": "Cosine"}})


def ensure_all_collections(user_ids: list = None):
    """Initialise les collections permanentes + celles des utilisateurs listés."""
    for name in ("uplanet_geo", "station_skills"):
        ensure_collection(name)
    if user_ids:
        for uid in user_ids:
            ensure_collection(f"memory_{_user_hex(uid)}")


# ──────────────────────────── geo memory ──────────────────────────────────────

def upsert_geo(lat: str, lon: str, content: str, pubkey: str = "",
               timestamp: str = None, event_id: str = "") -> bool:
    """Upsert un message géolocalisé dans la collection uplanet_geo."""
    if not content.strip():
        return False
    vec = _embed(content)
    if not vec:
        return False
    ts     = timestamp or datetime.utcnow().isoformat() + "Z"
    doc_id = _stable_id(lat, lon, ts, pubkey)
    ensure_collection("uplanet_geo")
    r = _curl("PUT", f"{QDRANT_URL}/collections/uplanet_geo/points", {
        "points": [{
            "id": doc_id,
            "vector": vec,
            "payload": {
                "latitude": lat, "longitude": lon,
                "coord_key": f"{lat}_{lon}",
                "pubkey": pubkey, "event_id": event_id,
                "content": content, "timestamp": ts,
            }
        }]
    })
    return bool(r)


def search_geo(lat: str, lon: str, query: str, limit: int = 5) -> list:
    """Recherche sémantique dans les mémoires d'une coordonnée."""
    vec = _embed(query)
    if not vec:
        return []
    r = _curl("POST", f"{QDRANT_URL}/collections/uplanet_geo/points/search", {
        "vector": vec,
        "limit": limit,
        "score_threshold": 0.3,
        "filter": {"must": [{"key": "coord_key",
                             "match": {"value": f"{lat}_{lon}"}}]},
    })
    return r.get("result", [])


# ──────────────────────────── user slot memory ────────────────────────────────

def upsert_user_slot(user_id: str, slot: int, content: str,
                     timestamp: str = None, event_id: str = "") -> bool:
    """Upsert une entrée dans la mémoire personnelle d'un MULTIPASS."""
    if not content.strip():
        return False
    vec = _embed(content)
    if not vec:
        return False
    cname  = f"memory_{_user_hex(user_id)}"
    ts     = timestamp or datetime.utcnow().isoformat() + "Z"
    doc_id = _stable_id(user_id, ts)
    ensure_collection(cname)
    r = _curl("PUT", f"{QDRANT_URL}/collections/{cname}/points", {
        "points": [{
            "id": doc_id,
            "vector": vec,
            "payload": {
                "user_id": user_id, "slot": slot,
                "content": content, "timestamp": ts,
                "event_id": event_id, "source": "nostr_rec",
            }
        }]
    })
    return bool(r)


def search_user_slot(user_id: str, query: str, slots: list = None,
                     limit: int = 5) -> list:
    """Recherche sémantique dans les slots mémoire d'un utilisateur."""
    vec = _embed(query)
    if not vec:
        return []
    cname = f"memory_{_user_hex(user_id)}"
    body: dict = {"vector": vec, "limit": limit, "score_threshold": 0.3,
                  "with_payload": True}
    if slots:
        body["filter"] = {"must": [{"key": "slot",
                                    "match": {"any": slots}}]}
    r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/search", body)
    return r.get("result", [])


# ──────────────────────────── station skills ──────────────────────────────────

def upsert_skill(skill: str, content: str, npub: str = "",
                 node_id: str = "") -> bool:
    """Upsert une entrée de skill dans la base collective station_skills."""
    if not content.strip():
        return False
    vec = _embed(f"{skill} {content}")
    if not vec:
        return False
    ensure_collection("station_skills")
    content_hash = hashlib.sha256(content.encode()).hexdigest()[:16]
    doc_id = _stable_id(skill, content[:80])
    r = _curl("PUT", f"{QDRANT_URL}/collections/station_skills/points", {
        "points": [{
            "id": doc_id,
            "vector": vec,
            "payload": {
                "skill": skill, "content": content,
                "content_hash": content_hash,
                "npub": npub, "node_id": node_id,
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        }]
    })
    return bool(r)


def skill_hash(skill: str) -> str:
    """Hash SHA256 du fichier skill local — clé de détection de conflit inter-node."""
    skill_safe = skill.lower().strip().replace(" ", "_").replace("/", "_")[:40]
    p = os.path.join(SKILLS_DIR, f"{skill_safe}.md")
    if not os.path.isfile(p):
        return ""
    with open(p, encoding="utf-8") as f:
        return hashlib.sha256(f.read().encode()).hexdigest()


def skill_content(skill: str) -> str:
    skill_safe = skill.lower().strip().replace(" ", "_").replace("/", "_")[:40]
    p = os.path.join(SKILLS_DIR, f"{skill_safe}.md")
    if not os.path.isfile(p):
        return ""
    with open(p, encoding="utf-8") as f:
        return f.read()


# ──────────────────── RÊVE : compression mémorielle ───────────────────────────

def _ollama_summarize(text: str, max_tokens: int = 200) -> str:
    """Résume un bloc de messages via Ollama — cœur du cycle RÊVE."""
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": (
            "Résume les échanges suivants en 2-3 phrases denses (en français). "
            "Garde les faits, décisions et compétences clés. Ignore les redondances.\n\n"
            f"{text}\n\n--- Résumé :"
        ),
        "stream": False,
        "options": {"num_predict": max_tokens, "temperature": 0.3},
    }
    r = _curl("POST", f"{OLLAMA_URL}/api/generate", payload)
    return r.get("response", "").strip()


def reve_compress_slot(user_id: str, slot: int,
                       slot_file: str = None) -> bool:
    """
    Déclenche la compression RÊVE pour un slot si >= REVE_THRESHOLD entrées.
    Résume les anciennes en [RÊVE] + conserve les REVE_KEEP plus récentes.
    Retourne True si compression effectuée.
    """
    if not slot_file:
        slot_file = os.path.expanduser(
            f"~/.zen/flashmem/{user_id}/slot{slot}.json")
    if not os.path.isfile(slot_file):
        return False

    with open(slot_file, encoding="utf-8") as f:
        data = json.load(f)

    msgs = data.get("messages", [])
    if len(msgs) < REVE_THRESHOLD:
        return False

    to_compress = msgs[:-REVE_KEEP]
    recent      = msgs[-REVE_KEEP:]

    block = "\n".join(
        f"[{m.get('timestamp', '')[:10]}] {m.get('content', '')}"
        for m in to_compress
    )
    summary = _ollama_summarize(block)
    if not summary:
        return False

    ts_now = datetime.utcnow().isoformat() + "Z"
    summary_entry: dict = {
        "timestamp": ts_now,
        "event_id":  f"reve:{hashlib.md5(summary.encode()).hexdigest()[:8]}",
        "content":   f"[RÊVE] {summary}",
        "source":    "reve_compression",
    }
    if to_compress and "latitude" in to_compress[-1]:
        summary_entry["latitude"]  = to_compress[-1]["latitude"]
        summary_entry["longitude"] = to_compress[-1]["longitude"]

    data["messages"] = [summary_entry] + recent
    with open(slot_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    upsert_user_slot(user_id, slot, summary_entry["content"], timestamp=ts_now)
    return True


def reve_compress_geo(lat: str, lon: str, geo_file: str = None) -> bool:
    """Déclenche la compression RÊVE pour la mémoire géo d'une coordonnée."""
    if not geo_file:
        coord_key = f"{lat}_{lon}".replace(".", "_").replace("-", "m")
        geo_file  = os.path.join(GEO_DIR, f"{coord_key}.json")
    if not os.path.isfile(geo_file):
        return False

    with open(geo_file, encoding="utf-8") as f:
        data = json.load(f)

    msgs = data.get("messages", [])
    if len(msgs) < REVE_THRESHOLD:
        return False

    to_compress = msgs[:-REVE_KEEP]
    recent      = msgs[-REVE_KEEP:]

    block = "\n".join(
        f"[{m.get('timestamp', '')[:10]}] {m.get('content', '')}"
        for m in to_compress
    )
    summary = _ollama_summarize(block)
    if not summary:
        return False

    ts_now = datetime.utcnow().isoformat() + "Z"
    summary_entry = {
        "timestamp": ts_now,
        "event_id":  f"reve:{hashlib.md5(summary.encode()).hexdigest()[:8]}",
        "pubkey":    "reve",
        "content":   f"[RÊVE] {summary}",
    }
    data["messages"] = [summary_entry] + recent
    with open(geo_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    upsert_geo(lat, lon, summary_entry["content"], timestamp=ts_now)
    return True


# ──────────────────────────── backup export ───────────────────────────────────

def backup_collections(output_path: str) -> bool:
    """
    Exporte toutes les collections Qdrant (payloads, sans vecteurs) en JSON.
    Prêt pour chiffrement SSSS + ipfs add + kind 30078.
    """
    r = _curl("GET", f"{QDRANT_URL}/collections")
    cols = [c["name"] for c in r.get("result", {}).get("collections", [])]
    if not cols:
        return False

    backup = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "qdrant_url": QDRANT_URL,
        "collections": {}
    }

    for col in cols:
        points: list = []
        offset = None
        while True:
            url  = f"{QDRANT_URL}/collections/{col}/points/scroll"
            body: dict = {"limit": 250, "with_payload": True, "with_vector": False}
            if offset:
                body["offset"] = offset
            resp   = _curl("POST", url, body)
            result = resp.get("result", {})
            batch  = result.get("points", [])
            points.extend(batch)
            offset = result.get("next_page_offset")
            if not offset:
                break
        backup["collections"][col] = points

    try:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(backup, f, ensure_ascii=False)
        return True
    except Exception:
        return False


# ──────────────────────────── restore ────────────────────────────────────────

def restore_collections(input_path: str,
                        collections_filter: list = None) -> dict:
    """
    Restaure les collections depuis un backup payload-only (sans vecteurs).
    Re-embedd chaque entrée via Ollama — indépendant du modèle utilisé lors du backup.
    Retourne un dict {collection: {"total": N, "restored": M}}.
    """
    with open(input_path, encoding="utf-8") as f:
        backup = json.load(f)

    stats: dict = {}
    for coll_name, points in backup.get("collections", {}).items():
        if collections_filter and coll_name not in collections_filter:
            continue
        ensure_collection(coll_name)
        ok = 0
        for point in points:
            payload = point.get("payload", {})
            content = payload.get("content", "")
            if not content:
                continue
            vec = _embed(content)
            if not vec:
                continue
            r = _curl("PUT", f"{QDRANT_URL}/collections/{coll_name}/points", {
                "points": [{"id": point["id"], "vector": vec, "payload": payload}]
            })
            if r:
                ok += 1
        stats[coll_name] = {"total": len(points), "restored": ok}
        print(f"  {coll_name}: {ok}/{len(points)} points restaurés",
              file=sys.stderr)
    return stats


# ──────────────────────────── CLI ─────────────────────────────────────────────

if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser(description="UPlanet Qdrant memory manager")
    sub = p.add_subparsers(dest="cmd")

    sub.add_parser("ensure-collections")

    pg = sub.add_parser("upsert-geo")
    pg.add_argument("--lat",      required=True)
    pg.add_argument("--lon",      required=True)
    pg.add_argument("--content",  required=True)
    pg.add_argument("--pubkey",   default="")
    pg.add_argument("--event-id", default="")

    ps = sub.add_parser("upsert-slot")
    ps.add_argument("--user-id",  required=True)
    ps.add_argument("--slot",     type=int, default=0)
    ps.add_argument("--content",  required=True)
    ps.add_argument("--event-id", default="")

    pk = sub.add_parser("upsert-skill")
    pk.add_argument("--skill",   required=True)
    pk.add_argument("--content", required=True)
    pk.add_argument("--npub",    default="")
    pk.add_argument("--node-id", default="")

    pr = sub.add_parser("reve")
    pr.add_argument("--user-id", required=True)
    pr.add_argument("--slot",    type=int, default=0)

    prg = sub.add_parser("reve-geo")
    prg.add_argument("--lat", required=True)
    prg.add_argument("--lon", required=True)

    psh = sub.add_parser("skill-hash")
    psh.add_argument("--skill", required=True)

    pbk = sub.add_parser("backup")
    pbk.add_argument("--output", required=True)

    prt = sub.add_parser("restore")
    prt.add_argument("--input",       required=True, help="Fichier backup JSON")
    prt.add_argument("--collections", nargs="*",     help="Filtrer sur ces collections")

    psr = sub.add_parser("search-geo")
    psr.add_argument("--lat",   required=True)
    psr.add_argument("--lon",   required=True)
    psr.add_argument("--query", required=True)
    psr.add_argument("--limit", type=int, default=5)

    psu = sub.add_parser("search-slot")
    psu.add_argument("--user-id", required=True)
    psu.add_argument("--query",   required=True)
    psu.add_argument("--slots",   nargs="*", type=int)
    psu.add_argument("--limit",   type=int, default=5)

    args = p.parse_args()

    if args.cmd == "ensure-collections":
        ensure_all_collections()
        print("OK")

    elif args.cmd == "upsert-geo":
        ok = upsert_geo(args.lat, args.lon, args.content, args.pubkey,
                        event_id=args.event_id)
        sys.exit(0 if ok else 1)

    elif args.cmd == "upsert-slot":
        ok = upsert_user_slot(args.user_id, args.slot, args.content,
                              event_id=args.event_id)
        sys.exit(0 if ok else 1)

    elif args.cmd == "upsert-skill":
        ok = upsert_skill(args.skill, args.content, args.npub,
                          getattr(args, "node_id", ""))
        sys.exit(0 if ok else 1)

    elif args.cmd == "reve":
        ok = reve_compress_slot(args.user_id, args.slot)
        print("RÊVE effectué" if ok else "seuil non atteint")

    elif args.cmd == "reve-geo":
        ok = reve_compress_geo(args.lat, args.lon)
        print("RÊVE effectué" if ok else "seuil non atteint")

    elif args.cmd == "skill-hash":
        print(skill_hash(args.skill))

    elif args.cmd == "backup":
        ok = backup_collections(args.output)
        sys.exit(0 if ok else 1)

    elif args.cmd == "restore":
        stats = restore_collections(args.input,
                                    collections_filter=args.collections)
        print(json.dumps(stats, indent=2))
        total   = sum(v["total"]    for v in stats.values())
        restored = sum(v["restored"] for v in stats.values())
        print(f"Restauration : {restored}/{total} points", file=sys.stderr)
        sys.exit(0 if restored > 0 else 1)

    elif args.cmd == "search-geo":
        results = search_geo(args.lat, args.lon, args.query, args.limit)
        print(json.dumps(results, ensure_ascii=False, indent=2))

    elif args.cmd == "search-slot":
        results = search_user_slot(args.user_id, args.query,
                                   args.slots, args.limit)
        print(json.dumps(results, ensure_ascii=False, indent=2))

    else:
        p.print_help()
