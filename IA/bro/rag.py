#!/usr/bin/env python3
"""
bro.rag — Correspondance sémantique et rappel mémoire (Qdrant + Ollama embeddings) : routage d'intention, mémoire épisodique, persona, profil réseau.

Extrait de bro_watch_core.py (split du monolithe, aucune logique modifiée).
"""

import os
import re
import sys
import json
import time
import hashlib
import tempfile
import subprocess

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # IA/
import bro_tools
from bro._shared import BRO_IA_PATH

__all__ = ['QDRANT_HOST', 'QDRANT_PORT', 'QDRANT_TOPICS_COLLECTION', 'QDRANT_EMBED_MODEL', 'QDRANT_VECTOR_SIZE', 'SEMANTIC_THRESHOLD', '_qdrant_client', '_qdrant_embed', '_cosine', '_topic_point_id', 'semantic_match', 'QDRANT_INTENT_COLLECTION', 'INTENT_MARGIN_THRESHOLD', 'INTENT_SHARED_NEGATIVES', '_intent_point_id', '_seed_intent_corpus', 'match_intent', 'BRO_MEMORY_SLOT', 'BRO_PERSONA_SLOT', 'PERSONA_RECALL_THRESHOLD', 'QDRANT_NETWORK_COLLECTION', 'NETWORK_RECALL_THRESHOLD', 'MEMORY_RECALL_THRESHOLD', '_memory_slot_file', '_recall_relevant_memories', '_remember_exchange', '_recall_persona', '_recall_network_profile', '_forget_memory']



QDRANT_HOST = "localhost"

QDRANT_PORT = 6333

QDRANT_TOPICS_COLLECTION = "bro_watch_topics"

QDRANT_EMBED_MODEL = "nomic-embed-text"

QDRANT_VECTOR_SIZE = 768

SEMANTIC_THRESHOLD = 0.70  # calibré empiriquement (nomic-embed-text a un plancher élevé ~0.5-0.6 même hors-sujet)

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
        warnings.simplefilter("ignore", UserWarning)
        return QdrantClient(url=f"http://{QDRANT_HOST}:{QDRANT_PORT}",
                             api_key=api_key, check_compatibility=False)

def _qdrant_embed(text):
    import ollama
    resp = ollama.embeddings(model=QDRANT_EMBED_MODEL, prompt=text)
    return resp["embedding"]

def _cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    return dot / (norm_a * norm_b) if norm_a and norm_b else 0.0

def _topic_point_id(owner_email, account, channel):
    h = hashlib.sha256(f"{owner_email}:{account}:{channel}".encode()).hexdigest()
    return int(h[:15], 16) % (2 ** 63)

def semantic_match(owner_email, account, channel, entry, text, threshold=SEMANTIC_THRESHOLD):
    """Similarité sémantique entre le texte et les mots-clés de l'entrée (Qdrant+Ollama).
    Dégradation gracieuse (retourne False) si Qdrant/Ollama indisponible."""
    keywords = list(entry.get("keywords", []) or []) + list(entry.get("learned_keywords", []) or [])
    topic_text = ", ".join(keywords)
    if not topic_text:
        return False
    try:
        from qdrant_client.models import Distance, VectorParams, PointStruct

        client = _qdrant_client()
        existing_collections = [c.name for c in client.get_collections().collections]
        if QDRANT_TOPICS_COLLECTION not in existing_collections:
            client.create_collection(
                collection_name=QDRANT_TOPICS_COLLECTION,
                vectors_config=VectorParams(size=QDRANT_VECTOR_SIZE, distance=Distance.COSINE),
            )

        point_id = _topic_point_id(owner_email, account, channel)
        topic_hash = hashlib.sha256(topic_text.encode()).hexdigest()

        existing = client.retrieve(collection_name=QDRANT_TOPICS_COLLECTION, ids=[point_id],
                                    with_payload=True, with_vectors=True)
        if existing and existing[0].payload.get("hash") == topic_hash:
            topic_vec = existing[0].vector
        else:
            topic_vec = _qdrant_embed(topic_text)
            client.upsert(
                collection_name=QDRANT_TOPICS_COLLECTION,
                points=[PointStruct(id=point_id, vector=topic_vec,
                                     payload={"owner": owner_email, "account": account,
                                              "channel": channel, "hash": topic_hash})]
            )

        text_vec = _qdrant_embed(text)
        score = _cosine(topic_vec, text_vec)
        if score >= threshold:
            print(f"[BRO_WATCH] Match sémantique ({score:.2f}) pour {owner_email} — {account}/{channel}")
            return True
        return False
    except Exception as e:
        print(f"[BRO_WATCH] Qdrant/Ollama indisponible pour matching sémantique : {e}")
        return False

QDRANT_INTENT_COLLECTION = "bro_intent_routing"

INTENT_MARGIN_THRESHOLD = 0.05

INTENT_SHARED_NEGATIVES = [
    "à quels outils as-tu accès ?",
    "que sais-tu faire ?",
    "quelles commandes puis-je utiliser ?",
    "désactive mastodon.social",
    "ajoute le mot-clé jardin sur le fil mastodon",
    "quels sont les derniers messages publié sur Mastodon ?",
    "il fait beau aujourd'hui",
    "bonjour, comment ça va ?",
    "montre-moi une vidéo de permaculture",
    "identifie cette plante sur la photo",
]

def _intent_point_id(kind, target, text):
    h = hashlib.sha256(f"{kind}:{target}:{text}".encode()).hexdigest()
    return int(h[:15], 16) % (2 ** 63)

def _seed_intent_corpus():
    """Peuple (idempotent) la collection Qdrant de routage d'intention avec
    les exemples positifs déclarés sur chaque bro_tools.Tool enregistré.
    Appelé paresseusement au premier match_intent() — pas de coût au
    chargement du module, dégradation silencieuse si Qdrant/Ollama
    indisponible."""
    from qdrant_client.models import Distance, VectorParams, PointStruct

    client = _qdrant_client()
    existing_collections = [c.name for c in client.get_collections().collections]
    if QDRANT_INTENT_COLLECTION not in existing_collections:
        client.create_collection(
            collection_name=QDRANT_INTENT_COLLECTION,
            vectors_config=VectorParams(size=QDRANT_VECTOR_SIZE, distance=Distance.COSINE),
        )

    points = []
    for target, ex in bro_tools.iter_examples():
        pid = _intent_point_id("positive", target, ex)
        existing = client.retrieve(collection_name=QDRANT_INTENT_COLLECTION, ids=[pid])
        if existing:
            continue
        points.append(PointStruct(id=pid, vector=_qdrant_embed(ex),
                                   payload={"label": "positive", "target": target, "text": ex}))
    for ex in INTENT_SHARED_NEGATIVES:
        pid = _intent_point_id("negative", "shared", ex)
        existing = client.retrieve(collection_name=QDRANT_INTENT_COLLECTION, ids=[pid])
        if existing:
            continue
        points.append(PointStruct(id=pid, vector=_qdrant_embed(ex),
                                   payload={"label": "negative", "target": "shared", "text": ex}))

    if points:
        client.upsert(collection_name=QDRANT_INTENT_COLLECTION, points=points)
        print(f"[BRO_WATCH] Corpus d'intention : {len(points)} nouvel(le)s exemple(s) indexé(s)")

def match_intent(text, margin_threshold=INTENT_MARGIN_THRESHOLD):
    """Route vers un tag système réel par marge sémantique (meilleur positif
    − meilleur négatif partagé) — voir le commentaire d'architecture ci-dessus
    pour la justification de la marge plutôt qu'un seuil absolu. Retourne
    (target, margin) ou None. Dégradation silencieuse si Qdrant/Ollama
    indisponible : ne doit jamais bloquer la réponse à l'utilisateur."""
    try:
        from qdrant_client.models import Filter, FieldCondition, MatchValue

        _seed_intent_corpus()
        client = _qdrant_client()
        text_vec = _qdrant_embed(text)

        pos_hits = client.query_points(
            collection_name=QDRANT_INTENT_COLLECTION, query=text_vec, limit=1,
            query_filter=Filter(must=[FieldCondition(key="label", match=MatchValue(value="positive"))]),
        ).points
        neg_hits = client.query_points(
            collection_name=QDRANT_INTENT_COLLECTION, query=text_vec, limit=1,
            query_filter=Filter(must=[FieldCondition(key="label", match=MatchValue(value="negative"))]),
        ).points
        if not pos_hits:
            return None
        best_pos = pos_hits[0]
        best_neg_score = neg_hits[0].score if neg_hits else 0.0
        margin = best_pos.score - best_neg_score
        if margin >= margin_threshold:
            return best_pos.payload["target"], margin
        return None
    except Exception as e:
        print(f"[BRO_WATCH] match_intent indisponible : {e}")
        return None

BRO_MEMORY_SLOT  = 13

BRO_PERSONA_SLOT = 14   # traits de style/expertise extraits par bro_backfill.py

PERSONA_RECALL_THRESHOLD = 0.65

QDRANT_NETWORK_COLLECTION = "uplanet_network"

NETWORK_RECALL_THRESHOLD = 0.60

MEMORY_RECALL_THRESHOLD = 0.72

def _memory_slot_file(owner_email):
    return os.path.expanduser(f"~/.zen/flashmem/{owner_email}/slot{BRO_MEMORY_SLOT}.json")

def _recall_relevant_memories(owner_email, text, limit=3):
    """Recherche sémantique dans la mémoire self-DM (Qdrant, memory_manager.py).
    Dégradation silencieuse (chaîne vide) si Qdrant/Ollama indisponible — ne
    doit jamais bloquer la réponse à l'utilisateur."""
    try:
        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        results = mm.search_user_slot(owner_email, text, slots=[BRO_MEMORY_SLOT], limit=limit,
                                       score_threshold=MEMORY_RECALL_THRESHOLD)
    except Exception:
        return ""
    facts = [r.get("payload", {}).get("content", "") for r in results]
    facts = [f for f in facts if f]
    return "\n".join(f"- {f}" for f in facts)

def _remember_exchange(owner_email, text, answer):
    """Persiste EN MÉMOIRE UNIQUEMENT le message du propriétaire (fait
    épisodique local + Qdrant sémantique — memory_manager.py, BRO_MEMORY_SLOT).
    Ne mémorise volontairement PAS la réponse de BRO : un incident réel
    (2026-07-03) a montré qu'une hallucination une fois répondue ("je ne
    peux pas reconnaître d'images") devient, rappelée comme "souvenir
    pertinent" au tour suivant, une fausse vérité que le LLM répète docilement
    — même quand le contexte réel (ex: description d'image fraîche) est
    présent dans le MÊME prompt juste après. Mémoriser uniquement ce que
    l'utilisateur a dit élimine cette boucle de rétroaction. Déclenche le
    cycle RÊVE (compression épisodique → sémantique) au-delà du seuil.
    Dégradation silencieuse : ne doit jamais faire échouer la réponse."""
    try:
        from datetime import datetime
        content = text
        ts = datetime.utcnow().isoformat() + "Z"

        slot_file = _memory_slot_file(owner_email)
        os.makedirs(os.path.dirname(slot_file), exist_ok=True)
        if os.path.isfile(slot_file):
            with open(slot_file, encoding="utf-8") as f:
                slot_mem = json.load(f)
        else:
            slot_mem = {"user_id": owner_email, "slot": BRO_MEMORY_SLOT, "messages": []}
        slot_mem["messages"].append({"timestamp": ts, "content": content})
        slot_mem["messages"] = slot_mem["messages"][-200:]
        with open(slot_file, "w", encoding="utf-8") as f:
            json.dump(slot_mem, f, indent=2, ensure_ascii=False)

        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.upsert_user_slot(owner_email, BRO_MEMORY_SLOT, content, timestamp=ts)
        if len(slot_mem["messages"]) >= 170:
            mm.reve_compress_slot(owner_email, BRO_MEMORY_SLOT, slot_file=slot_file)
    except Exception as e:
        print(f"[BRO_WATCH] Mémoire self-DM indisponible pour {owner_email} : {e}")

def _recall_persona(owner_email, query="style communication opinion expertise", limit=2):
    """Recherche sémantique dans les traits de persona du propriétaire (slot 14,
    alimenté par bro_backfill.py). Retourne une chaîne formatée ou '' si vide /
    Qdrant indisponible."""
    try:
        import sys as _sys
        _sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        results = mm.search_user_slot(owner_email, query, slots=[BRO_PERSONA_SLOT],
                                       limit=limit, score_threshold=PERSONA_RECALL_THRESHOLD)
        traits = [r.get("payload", {}).get("content", "") for r in results]
        traits = [t for t in traits if t]
        return " | ".join(traits)
    except Exception:
        return ""

def _recall_network_profile(username, limit=1):
    """Recherche sémantique dans les fiches interlocuteurs (collection Qdrant
    uplanet_network, alimentée par bro_backfill.py). Retourne la fiche texte
    ou '' si pas de match / Qdrant indisponible."""
    if not username:
        return ""
    clean = username.lstrip("@").split("@")[0]   # "alice" depuis "@alice@mastodon.social"
    try:
        client = _qdrant_client()
        vec = _qdrant_embed(clean)
        hits = client.query_points(
            collection_name=QDRANT_NETWORK_COLLECTION,
            query=vec,
            limit=limit,
            score_threshold=NETWORK_RECALL_THRESHOLD,
        ).points
        if hits:
            return hits[0].payload.get("fiche", "")
    except Exception:
        pass
    return ""

def _forget_memory(owner_email):
    """#oublie — efface la mémoire self-DM (fichier local + points Qdrant du
    slot dédié). Contrôle explicite de l'utilisateur sur sa propre mémoire,
    symétrique au #reset des slots société (bro_dm_daemon.sh)."""
    slot_file = _memory_slot_file(owner_email)
    try:
        if os.path.isfile(slot_file):
            os.remove(slot_file)
    except Exception:
        pass
    try:
        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.delete_user_slot(owner_email, BRO_MEMORY_SLOT)
    except Exception:
        pass
    return "🗑️ Mémoire de nos échanges effacée."
