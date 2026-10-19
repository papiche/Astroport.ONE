#!/usr/bin/env python3
"""
geo_memory.py — met à jour la collection Qdrant `uplanet_geo` depuis NOSTR (rafraîchissement de 20h12).

Les publications GÉOLOCALISÉES qui ont reçu des likes entrent dans la mémoire du lieu, au périmètre de leur succès :
    ≥ 1 like → UMAP (case 0,01°)   ·   ≥ 3 likes → SECTOR (0,1°)   ·   ≥ 12 likes → REGION (1°)
(mêmes seuils que NOSTR.UMAP.refresh.sh, qui en fait les journaux de zone). Qdrant n'est qu'un INDEX : la vérité reste dans
NOSTR (évènements et réactions, répliqués entre stations) ; chaque station indexe ce que SON relais connaît — des espaces
relatifs à chaque relais, jamais une base globale. Rien n'est écrit sur le disque local (plus de short_memory.py).

Chaque passage :
  1. nouvelles candidates : publications dont une réaction « approuve » est arrivée ces N derniers jours ;
  2. recomptage des publications DÉJÀ indexées (30 jours) : leurs likes évoluent (niveau qui monte, ou qui redescend) ;
  3. pour chacune : géolocalisation (tags latitude/longitude, sinon « g » = « lat,lon »), likes DISTINCTS hors auteur →
     niveau → écriture (id = id de l'évènement : idempotent) ; plus aucun like ou évènement disparu → retirée de l'index.
Exclues : publications chiffrées, sans texte (messages vocaux : pas de contenu à chercher), contenant un secret.

  geo_memory.py refresh [--days 3] [--recount-days 30] [--dry-run]
  geo_memory.py stats
"""
import argparse   # AVANT memory_manager : le venv ~/.astro embarque un vieux argparse.py qui masque la stdlib
import fcntl
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import memory_manager as mm

STRFRY_DIR = os.path.expanduser("~/.zen/strfry")
APPROVE = {"+", "👍", "❤️", "❤", "♥️", "♥", "✅", "🤙"}   # réactions « approuve » de count_likes (NOSTR.UMAP.refresh.sh) + les cœurs sans sélecteur de variante
# (« +10 » = un paiement ẐEN en kind 7, PAS un like : jamais compté)
GEO_KINDS = (1, 1222, 1244)                              # notes, messages vocaux coracle (sans texte : écartés plus bas)
BATCH = 150


def _log(msg):
    print(f"[geo_memory] {msg}", file=sys.stderr)


def scan(flt: dict) -> list:
    """`strfry scan` sur le relais local. Lève si strfry échoue : « aucun résultat » ≠ « relais illisible »."""
    if not os.path.isfile(os.path.join(STRFRY_DIR, "strfry")):
        raise RuntimeError(f"strfry introuvable dans {STRFRY_DIR}")
    r = subprocess.run(["./strfry", "scan", json.dumps(flt)], cwd=STRFRY_DIR, capture_output=True, text=True, timeout=180)
    if r.returncode != 0:
        raise RuntimeError(f"strfry scan : {r.stderr.strip()[-200:]}")
    out = []
    for line in r.stdout.splitlines():
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def tag(ev: dict, name: str) -> str:
    return next((t[1] for t in ev.get("tags", []) if len(t) > 1 and t[0] == name), "")


def coords(ev: dict):
    """(lat, lon) d'une publication, ou None : tags latitude/longitude d'abord, sinon « g » = « lat,lon »."""
    lat, lon = tag(ev, "latitude"), tag(ev, "longitude")
    if not (lat and lon):
        g = tag(ev, "g")
        if "," in g:
            lat, lon = g.split(",", 1)
    try:
        la, lo = float(lat), float(lon)
    except (TypeError, ValueError):
        return None
    if not (-90 <= la <= 90 and -180 <= lo <= 180) or (la == 0.0 and lo == 0.0):
        return None            # (0,0) = l'UMAP « globale » des messages SANS position, pas un lieu
    return la, lo


def indexable(ev: dict):
    """(lat, lon) si la publication peut entrer dans l'index, sinon None (et la raison est dans reason())."""
    return coords(ev) if reason(ev) is None else None


def reason(ev: dict):
    """Pourquoi une publication géolocalisée n'est PAS indexable (None = elle l'est)."""
    if ev.get("kind") not in GEO_KINDS:
        return "genre"
    if any(len(t) > 1 and t[0] == "encrypted" and t[1] == "true" for t in ev.get("tags", [])):
        return "chiffrée"
    if not (ev.get("content") or "").strip():
        return "sans texte"
    if mm.unstorable_reason(ev["content"]):
        return "secret"
    return None


def likers(event_id: str, author: str) -> set:
    """Personnes DISTINCTES qui approuvent cette publication (hors son auteur : se liker soi-même ne compte pas)."""
    return {r["pubkey"] for r in scan({"kinds": [7], "#e": [event_id], "limit": 500})
            if r.get("content") in APPROVE and r.get("pubkey") != author}


def fetch(ids: list) -> dict:
    """{id: évènement} pour une liste d'ids (par lots)."""
    out = {}
    for i in range(0, len(ids), BATCH):
        for ev in scan({"ids": ids[i:i + BATCH], "kinds": list(GEO_KINDS)}):
            out[ev["id"]] = ev
    return out


def refresh(days: int = 3, recount_days: int = 30, dry: bool = False) -> dict:
    now = int(time.time())
    stats = {"candidates": 0, "geolocated": 0, "indexed": 0, "updated": 0, "unchanged": 0, "removed": 0,
             "skipped": {}, "levels": {"umap": 0, "sector": 0, "region": 0}}

    # 1) nouvelles candidates : réactions « approuve » récentes → publications visées
    liked = {}
    for r in scan({"kinds": [7], "since": now - days * 86400}):
        if r.get("content") in APPROVE:
            for t in r.get("tags", []):
                if len(t) > 1 and t[0] == "e":
                    liked[t[1]] = True
    # 2) déjà indexées : recomptage (leurs likes bougent)
    indexed = {p["event_id"]: p for p in mm.geo_indexed(now - recount_days * 86400)}
    ids = sorted(set(liked) | set(indexed))
    stats["candidates"] = len(ids)
    events = fetch(ids)

    gone = [i for i in indexed if i not in events]                    # évènement supprimé / disparu du relais
    if gone:
        stats["removed"] += len(gone)
        _log(f"{len(gone)} publication(s) indexée(s) ont disparu du relais : retirées de l'index")
        if not dry:
            mm.delete_geo_events(gone)

    to_remove = []
    for eid, ev in events.items():
        pos = coords(ev)
        if pos is None:
            continue                                                  # non géolocalisée : pas pour cet index
        stats["geolocated"] += 1
        why = reason(ev)
        if why:
            stats["skipped"][why] = stats["skipped"].get(why, 0) + 1
            if eid in indexed:
                to_remove.append(eid)
            continue
        n = len(likers(eid, ev.get("pubkey", "")))
        level = mm.geo_level(n)
        if level is None:
            if eid in indexed:
                to_remove.append(eid)                                 # plus aucun like : sort de l'index
            continue
        prev = indexed.get(eid)
        if prev and prev.get("likes") == n:
            stats["unchanged"] += 1
            stats["levels"][level] += 1
            continue
        stats["levels"][level] += 1
        stats["updated" if prev else "indexed"] += 1
        if dry:
            print(f"  {'~' if prev else '+'} [{level:6}] {n:3} like(s)  {pos[0]:.4f},{pos[1]:.4f}  {ev['content'][:90]!r}")
        elif not mm.upsert_geo_event(ev, pos[0], pos[1], n):
            _log(f"⚠️ publication {eid[:12]} non indexée (embedding ou Qdrant)")
            stats["updated" if prev else "indexed"] -= 1
    if to_remove:
        stats["removed"] += len(to_remove)
        if not dry:
            mm.delete_geo_events(to_remove)
    return stats


def main():
    p = argparse.ArgumentParser(description="Mémoire géolocalisée (uplanet_geo) depuis NOSTR")
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("refresh")
    r.add_argument("--days", type=int, default=3, help="réactions récentes qui désignent de nouvelles candidates")
    r.add_argument("--recount-days", type=int, default=30, help="publications indexées dont on recompte les likes")
    r.add_argument("--dry-run", action="store_true")
    sub.add_parser("stats")
    a = p.parse_args()

    if a.cmd == "stats":
        pts = mm.geo_indexed(0)
        by = {}
        for x in pts:
            by[x.get("level")] = by.get(x.get("level"), 0) + 1
        print(json.dumps({"indexed": len(pts), "by_level": by}))
        return
    if not mm._qdrant_available():
        sys.exit("ERROR: Qdrant injoignable — rien n'a été fait")
    os.makedirs(os.path.expanduser("~/.zen/flashmem"), exist_ok=True)
    lock = open(os.path.expanduser("~/.zen/flashmem/.geo_memory.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        _log("déjà en cours")
        return
    t0 = time.time()
    res = refresh(a.days, a.recount_days, dry=a.dry_run)
    res["seconds"] = round(time.time() - t0, 1)
    print(json.dumps(res, ensure_ascii=False))


if __name__ == "__main__":
    main()
