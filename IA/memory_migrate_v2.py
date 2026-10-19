#!/usr/bin/env python3
"""
memory_migrate_v2.py — migre les mémoires Qdrant vers le schéma v2 + bge-m3.

  python3 memory_migrate_v2.py            # à blanc : rapport, rien n'est modifié
  python3 memory_migrate_v2.py --apply    # sauvegarde JSON puis migration

Pour chaque collection `memory_*` et `uplanet_geo` dont la dimension ≠ VECTOR_SIZE :
  1. sauvegarde des payloads dans ~/.zen/flashmem/_migration_backups/ (hors ~/.zen/tmp,
     purgé chaque nuit par 20h12.process.sh) ;
  2. écarte les contenus secrets (memory_manager.unstorable_reason — ex. STORY_KEY_BACKUP) ;
  3. dédoublonne par contenu normalisé (on garde le plus récent) ;
  4. traduit slot → kind/source/visibility (memory_manager.SLOT_SCHEMA) ;
  5. supprime la collection, la recrée en bonne dimension, ré-embedde et réécrit.
Les autres collections (bro_intent_routing, knowledge, codebase…) ne sont pas touchées :
elles ont leur propre modèle d'embedding.
"""
import json
import os
import sys
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import memory_manager as mm

BACKUP_DIR = os.path.expanduser("~/.zen/flashmem/_migration_backups")


def _collections():
    r = mm._curl("GET", f"{mm.QDRANT_URL}/collections")
    return [c["name"] for c in r.get("result", {}).get("collections", [])]


def _dim(name):
    r = mm._curl("GET", f"{mm.QDRANT_URL}/collections/{name}")
    return ((r.get("result", {}).get("config", {}).get("params", {}).get("vectors", {}) or {})
            .get("size"))


def _scroll_all(name):
    pts, offset = [], None
    while True:
        body = {"limit": 250, "with_payload": True, "with_vector": False}
        if offset:
            body["offset"] = offset
        res = mm._curl("POST", f"{mm.QDRANT_URL}/collections/{name}/points/scroll", body).get("result", {})
        pts.extend(res.get("points", []))
        offset = res.get("next_page_offset")
        if not offset:
            return pts


def plan_memory(points):
    """→ (à garder [payload v2], écartés [(raison, extrait)], nb doublons)."""
    kept, dropped, by_hash = [], [], {}
    for p in points:
        pl = dict(p.get("payload", {}))
        content = (pl.get("content") or "").strip()
        if not content:
            dropped.append(("vide", ""))
            continue
        why = mm.unstorable_reason(content)
        if why:
            dropped.append((why, content[:60]))
            continue
        h = mm._content_hash(content)
        if h in by_hash and by_hash[h].get("timestamp", "") >= pl.get("timestamp", ""):
            continue
        slot = pl.get("slot")
        sch = mm.SLOT_SCHEMA.get(slot, {"kind": "fact", "source": "chat", "visibility": "private"})
        pl.update({"kind": pl.get("kind", sch["kind"]), "source": sch["source"] if pl.get("source") in (None, "nostr_rec") else pl["source"],
                   "visibility": pl.get("visibility", sch["visibility"]),
                   "confidence": pl.get("confidence", 1.0), "status": pl.get("status", "active"),
                   "embed_model": mm.EMBED_MODEL, "schema": mm.SCHEMA_VERSION, "content_hash": h})
        by_hash[h] = pl
    kept = list(by_hash.values())
    dups = len(points) - len(kept) - len(dropped)
    return kept, dropped, dups


def main():
    apply = "--apply" in sys.argv
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    todo = [c for c in _collections() if (c.startswith("memory_") or c == "uplanet_geo")]
    print(f"Modèle cible : {mm.EMBED_MODEL} ({mm.VECTOR_SIZE} d) — {'APPLICATION' if apply else 'à blanc'}")
    errors = 0
    for name in todo:
        dim = _dim(name)
        if dim == mm.VECTOR_SIZE:
            print(f"= {name}: déjà en {dim} d, ignorée")
            continue
        pts = _scroll_all(name)
        if name == "uplanet_geo":
            kept = [p.get("payload", {}) for p in pts if (p.get("payload", {}).get("content") or "").strip()]
            dropped, dups = [], 0
        else:
            kept, dropped, dups = plan_memory(pts)
        print(f"- {name} ({dim} d): {len(pts)} points → {len(kept)} gardés, "
              f"{dups} doublons, {len(dropped)} écartés")
        for why, ex in dropped:
            print(f"    ✗ {why}: {ex}")
        if not apply:
            continue
        with open(os.path.join(BACKUP_DIR, f"{name}.{stamp}.json"), "w", encoding="utf-8") as f:
            json.dump(pts, f, ensure_ascii=False)
        # Ré-embedder AVANT de supprimer : si Ollama est muet, on ne détruit rien.
        vecs = []
        for pl in kept:
            v = mm._embed(pl["content"])
            if not v:
                print(f"  ❌ embedding impossible ({name}) — collection laissée intacte")
                errors += 1
                vecs = None
                break
            vecs.append(v)
        if vecs is None:
            continue
        mm._curl("DELETE", f"{mm.QDRANT_URL}/collections/{name}")
        mm.ensure_collection(name)
        for i in range(0, len(kept), 50):
            batch = [{"id": mm._stable_id(pl.get("user_id", name), pl.get("content_hash") or mm._content_hash(pl["content"])),
                      "vector": vecs[i + j], "payload": pl} for j, pl in enumerate(kept[i:i + 50])]
            if not mm._curl("PUT", f"{mm.QDRANT_URL}/collections/{name}/points", {"points": batch}):
                errors += 1
        print(f"  ✔ {name}: {len(kept)} points réécrits en {mm.VECTOR_SIZE} d")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
