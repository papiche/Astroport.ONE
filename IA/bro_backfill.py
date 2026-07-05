#!/usr/bin/env python3
"""
bro_backfill.py — Apprentissage historique de BRO.

Deux pipelines alimentés depuis les posts NOSTR du propriétaire :

  1. PERSONA (slot 14)  : filtre par engagement (≥ min_likes), passe chaque
     "greatest hit" par question.py pour en extraire un trait de style/expertise,
     et l'injecte dans memory_manager slot 14 (BRO_PERSONA_SLOT).

  2. RÉSEAU             : détecte les interlocuteurs fréquents (tags #p), récupère
     leur profil NOSTR (kind 0), génère une fiche IA, persiste en
     ~/.zen/flashmem/network/<handle>@nostr.json + collection Qdrant uplanet_network.

Ces deux bases enrichissent ensuite generate_suggestion() dans bro_watch_core.py
(via _recall_persona / _recall_network_profile) pour que BRO adapte ses suggestions
au style du propriétaire et au profil de chaque interlocuteur.

Usage :
    python3 bro_backfill.py <owner_email> [--min-likes 3] [--top-n 20] [--dry-run]
"""

import os
import sys
import json
import hashlib
import argparse
import subprocess

BRO_IA_PATH  = os.path.expanduser("~/.zen/Astroport.ONE/IA")
TOOLS_PATH   = os.path.expanduser("~/.zen/Astroport.ONE/tools")
NOSTR_DIR    = os.path.expanduser("~/.zen/game/nostr")
NETWORK_DIR  = os.path.expanduser("~/.zen/flashmem/network")

QDRANT_NETWORK_COLLECTION = "uplanet_network"
QDRANT_EMBED_MODEL        = "nomic-embed-text"
QDRANT_VECTOR_SIZE        = 768
QDRANT_HOST               = "localhost"
QDRANT_PORT               = 6333

BRO_PERSONA_SLOT = 14
DEFAULT_RELAY    = "wss://relay.copylaradio.com"


# ─── helpers ──────────────────────────────────────────────────────────────────

def _owner_hex(owner_email):
    try:
        with open(os.path.join(NOSTR_DIR, owner_email, "HEX")) as f:
            return f.read().strip()
    except Exception:
        return ""


def _load_relays():
    try:
        proc = subprocess.run(
            ["bash", "-c", f"source {TOOLS_PATH}/my.sh >/dev/null 2>&1; echo \"$myRELAY\""],
            capture_output=True, text=True, timeout=30,
        )
        local = proc.stdout.strip()
        return [local, DEFAULT_RELAY] if local and local != DEFAULT_RELAY else [DEFAULT_RELAY]
    except Exception:
        return [DEFAULT_RELAY]


def _question(prompt, dry_run=False):
    if dry_run:
        return f"[DRY-RUN] {prompt[:80]}…"
    try:
        result = subprocess.run(
            ["python3", f"{BRO_IA_PATH}/question.py", prompt],
            capture_output=True, text=True, timeout=60,
        )
        return result.stdout.strip()
    except Exception as e:
        return f"(question.py indisponible : {e})"


# ─── Qdrant ───────────────────────────────────────────────────────────────────

def _qdrant_client():
    import warnings
    from qdrant_client import QdrantClient
    env_file = os.path.expanduser("~/.zen/ai-company/.env")
    api_key = None
    try:
        with open(env_file) as f:
            for line in f:
                if line.startswith("QDRANT_API_KEY="):
                    api_key = line.strip().split("=", 1)[1]
    except Exception:
        pass
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return QdrantClient(
            url=f"http://{QDRANT_HOST}:{QDRANT_PORT}",
            api_key=api_key, check_compatibility=False,
        )


def _embed(text):
    import ollama
    return ollama.embeddings(model=QDRANT_EMBED_MODEL, prompt=text)["embedding"]


def _ensure_network_collection():
    from qdrant_client.models import Distance, VectorParams
    client = _qdrant_client()
    existing = [c.name for c in client.get_collections().collections]
    if QDRANT_NETWORK_COLLECTION not in existing:
        client.create_collection(
            collection_name=QDRANT_NETWORK_COLLECTION,
            vectors_config=VectorParams(size=QDRANT_VECTOR_SIZE, distance=Distance.COSINE),
        )


# ─── 1. Fetch own NOSTR posts + reaction counts ────────────────────────────

def _fetch_posts_with_reactions(owner_hex, relays, limit=200):
    """
    Récupère les kind 1 du propriétaire depuis les relays, puis compte les
    kind 7 (#e ciblant ces posts). Retourne (posts, {post_id: count}).
    """
    import asyncio
    import websockets

    async def _query_relay(relay):
        posts, reaction_counts = [], {}
        try:
            async with websockets.connect(relay, open_timeout=5) as ws:
                await ws.send(json.dumps(
                    ["REQ", "bf-posts", {"kinds": [1], "authors": [owner_hex], "limit": limit}]
                ))
                while True:
                    data = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
                    if data[0] == "EVENT":
                        posts.append(data[2])
                    elif data[0] == "EOSE":
                        break
                await ws.send(json.dumps(["CLOSE", "bf-posts"]))

                if posts:
                    # Compte les réactions par lots de 30
                    post_ids = [p["id"] for p in posts]
                    for i in range(0, len(post_ids), 30):
                        batch = post_ids[i:i + 30]
                        await ws.send(json.dumps(
                            ["REQ", "bf-reac", {"kinds": [7], "#e": batch, "limit": 1000}]
                        ))
                        while True:
                            data = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
                            if data[0] == "EVENT":
                                for tag in data[2].get("tags", []):
                                    if tag[0] == "e" and len(tag) > 1:
                                        reaction_counts[tag[1]] = reaction_counts.get(tag[1], 0) + 1
                                        break
                            elif data[0] == "EOSE":
                                break
                        await ws.send(json.dumps(["CLOSE", "bf-reac"]))
        except Exception as e:
            print(f"[BACKFILL] {relay} : {e}")
        return posts, reaction_counts

    async def _all():
        seen_ids, all_posts, all_reactions = set(), [], {}
        for relay in relays:
            p_list, r_map = await _query_relay(relay)
            for p in p_list:
                if p["id"] not in seen_ids:
                    seen_ids.add(p["id"])
                    all_posts.append(p)
            for pid, cnt in r_map.items():
                all_reactions[pid] = max(all_reactions.get(pid, 0), cnt)
        return all_posts, all_reactions

    return asyncio.run(_all())


# ─── 2. Interlocuteurs fréquents ──────────────────────────────────────────────

def _extract_interlocutors(posts, min_interactions=2):
    """Retourne {pubkey: count} pour les pubkeys mentionnés ≥ min_interactions fois."""
    counts = {}
    for post in posts:
        for tag in post.get("tags", []):
            if tag[0] == "p" and len(tag) > 1:
                counts[tag[1]] = counts.get(tag[1], 0) + 1
    return {pk: c for pk, c in counts.items() if c >= min_interactions}


def _fetch_nostr_profile(hex_pk, relays):
    """Retourne le dict de contenu kind 0 du pubkey, ou {}."""
    import asyncio
    import websockets

    async def _query(relay):
        try:
            async with websockets.connect(relay, open_timeout=5) as ws:
                await ws.send(json.dumps(
                    ["REQ", "bf-prof", {"kinds": [0], "authors": [hex_pk], "limit": 1}]
                ))
                while True:
                    data = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
                    if data[0] == "EVENT":
                        try:
                            return json.loads(data[2].get("content", "{}"))
                        except Exception:
                            return {}
                    elif data[0] == "EOSE":
                        return {}
        except Exception:
            return {}

    async def _all():
        for relay in relays:
            profile = await _query(relay)
            if profile:
                return profile
        return {}

    return asyncio.run(_all())


# ─── 3. Prompts IA ────────────────────────────────────────────────────────────

def _persona_prompt(post_content):
    return (
        "Voici un de mes messages :\n\n"
        f"« {post_content[:800]} »\n\n"
        "En une seule phrase directe (sans introduction), extrais l'opinion forte, "
        "l'expertise technique ou le trait de caractère qui ressort de ce message."
    )


def _fiche_prompt(handle, profile_json):
    return (
        f"Voici le profil NOSTR de @{handle} :\n\n"
        f"{profile_json[:500]}\n\n"
        "En 2 phrases directes (sans introduction), décris ses compétences principales, "
        "ses sujets de prédilection et son style de communication."
    )


# ─── 4. Persistance ──────────────────────────────────────────────────────────

def _persist_persona_trait(owner_email, trait, dry_run):
    if dry_run:
        print(f"  [DRY-RUN] slot 14 ← {trait[:80]}…")
        return
    try:
        from datetime import datetime
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.upsert_user_slot(
            owner_email, BRO_PERSONA_SLOT, trait,
            timestamp=datetime.utcnow().isoformat() + "Z",
        )
    except Exception as e:
        print(f"[BACKFILL] memory_manager indisponible : {e}")


def _persist_network_profile(handle, fiche, dry_run):
    safe = handle.replace("/", "_").replace("@", "_")
    path = os.path.join(NETWORK_DIR, f"{safe}@nostr.json")
    if dry_run:
        print(f"  [DRY-RUN] {path} ← {fiche[:80]}…")
        return

    os.makedirs(NETWORK_DIR, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"handle": handle, "platform": "nostr", "fiche": fiche}, f,
                  indent=2, ensure_ascii=False)

    try:
        from qdrant_client.models import PointStruct
        _ensure_network_collection()
        client = _qdrant_client()
        point_id = int(hashlib.sha256(f"{handle}@nostr".encode()).hexdigest()[:15], 16) % (2 ** 63)
        client.upsert(
            collection_name=QDRANT_NETWORK_COLLECTION,
            points=[PointStruct(
                id=point_id,
                vector=_embed(f"{handle} (nostr) : {fiche}"),
                payload={"handle": handle, "platform": "nostr", "fiche": fiche},
            )],
        )
        print(f"[BACKFILL] {handle}@nostr vectorisé dans Qdrant.")
    except Exception as e:
        print(f"[BACKFILL] Qdrant uplanet_network indisponible : {e}")


# ─── Main ─────────────────────────────────────────────────────────────────────

def run(owner_email, min_likes=3, top_n=20, dry_run=False):
    hex_pk = _owner_hex(owner_email)
    if not hex_pk:
        print(f"[BACKFILL] HEX introuvable pour {owner_email}")
        sys.exit(1)

    relays = _load_relays()
    print(f"[BACKFILL] {owner_email} ({hex_pk[:16]}…) — relays : {relays}")

    # 1. Posts + réactions
    print("[BACKFILL] Récupération des posts et réactions NOSTR…")
    posts, reaction_counts = _fetch_posts_with_reactions(hex_pk, relays)
    print(f"[BACKFILL] {len(posts)} post(s) trouvé(s).")

    # Classement par likes, filtrage
    ranked = sorted(posts, key=lambda p: reaction_counts.get(p["id"], 0), reverse=True)
    top_posts = [p for p in ranked if reaction_counts.get(p["id"], 0) >= min_likes][:top_n]
    print(f"[BACKFILL] {len(top_posts)} 'greatest hit(s)' (≥{min_likes} like(s)).")

    # 2. Pipeline PERSONA
    persona_count = 0
    for post in top_posts:
        content = post.get("content", "").strip()
        if len(content) < 30:
            continue
        likes = reaction_counts.get(post["id"], 0)
        print(f"[BACKFILL] Persona ← ({likes}❤) {content[:60]}…")
        trait = _question(_persona_prompt(content), dry_run)
        _persist_persona_trait(owner_email, trait, dry_run)
        persona_count += 1

    print(f"[BACKFILL] {persona_count} trait(s) injecté(s) → slot {BRO_PERSONA_SLOT}.")

    # 3. Pipeline RÉSEAU
    interlocutors = _extract_interlocutors(posts, min_interactions=2)
    print(f"[BACKFILL] {len(interlocutors)} interlocuteur(s) fréquent(s).")

    sorted_interlocutors = sorted(interlocutors.items(), key=lambda x: -x[1])[:15]
    for pk, count in sorted_interlocutors:
        profile = _fetch_nostr_profile(pk, relays)
        handle = (profile.get("name") or profile.get("display_name") or pk[:12]).strip()
        if not handle:
            continue
        print(f"[BACKFILL] Fiche @{handle} ({count} interactions)…")
        fiche = _question(_fiche_prompt(handle, json.dumps(profile, ensure_ascii=False)), dry_run)
        _persist_network_profile(handle, fiche, dry_run)

    print("[BACKFILL] Terminé.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="BRO Backfill — Greatest Hits (slot 14) + Réseau (uplanet_network)"
    )
    parser.add_argument("owner_email", help="Email MULTIPASS du propriétaire")
    parser.add_argument("--min-likes", type=int, default=3, help="Seuil de likes (défaut : 3)")
    parser.add_argument("--top-n", type=int, default=20, help="Nombre max de greatest hits (défaut : 20)")
    parser.add_argument("--dry-run", action="store_true", help="Simulation sans persistance")
    args = parser.parse_args()
    run(args.owner_email, min_likes=args.min_likes, top_n=args.top_n, dry_run=args.dry_run)
