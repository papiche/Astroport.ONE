#!/usr/bin/env python3
"""
bro.rag — Correspondance sémantique et rappel mémoire (Qdrant + Ollama embeddings) : routage d'intention, mémoire épisodique, persona, profil réseau.

Extrait de bro_watch_core.py (split du monolithe, aucune logique modifiée).
"""

import os
import re
import sys
import time
import hashlib
import tempfile
import subprocess

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # IA/
import bro_tools
from bro._shared import BRO_IA_PATH

__all__ = ['QDRANT_HOST', 'QDRANT_PORT', 'QDRANT_TOPICS_COLLECTION', 'QDRANT_EMBED_MODEL', 'QDRANT_VECTOR_SIZE', 'SEMANTIC_THRESHOLD', '_qdrant_client', '_qdrant_embed', '_cosine', '_topic_point_id', 'semantic_match', 'QDRANT_INTENT_COLLECTION', 'INTENT_MARGIN_THRESHOLD', 'INTENT_SHARED_NEGATIVES', '_intent_point_id', '_seed_intent_corpus', 'match_intent', 'BRO_MEMORY_SLOT', 'BRO_PERSONA_SLOT', 'PERSONA_RECALL_THRESHOLD', 'QDRANT_NETWORK_COLLECTION', 'NETWORK_RECALL_THRESHOLD', 'MEMORY_RECALL_THRESHOLD', '_recall_relevant_memories', '_remember_exchange', '_recall_persona', '_recall_network_profile', '_forget_memory']



QDRANT_HOST = "localhost"

QDRANT_PORT = 6333

QDRANT_TOPICS_COLLECTION = "bro_watch_topics"

import embed_config   # modèle + seuils UNIQUES de la plateforme (bge-m3, mesurés — voir embed_config.py)

QDRANT_EMBED_MODEL = embed_config.MODEL

QDRANT_VECTOR_SIZE = embed_config.DIM

# Seuil rubrique de veille (texte d'un post ↔ mots-clés). L'ancien 0,70 (calibré pour nomic) ne retrouvait
# que 4 posts pertinents sur 15 ; bge-m3 à 0,46 en retrouve 14 sur 15 (2 faux positifs sur 20).
SEMANTIC_THRESHOLD = embed_config.threshold("topic")

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
    """Vecteur du texte (embed_config.embed) — lève une erreur claire plutôt qu'un vecteur vide ou de
    mauvaise dimension (qui corromprait une collection ou donnerait un faux « aucun résultat »)."""
    return embed_config.embed(text)

def _ensure_derived_collection(client, name):
    """Crée la collection ; si elle existe avec une AUTRE dimension (changement de modèle d'embedding), la
    RECRÉE — réservé aux collections reconstructibles (routage d'intention, rubriques de veille), jamais à
    la mémoire de l'utilisateur."""
    from qdrant_client.models import Distance, VectorParams
    if name in [c.name for c in client.get_collections().collections]:
        have = client.get_collection(name).config.params.vectors.size
        if have == QDRANT_VECTOR_SIZE:
            return
        print(f"[BRO_WATCH] collection {name} : {have} d ≠ {QDRANT_VECTOR_SIZE} d ({QDRANT_EMBED_MODEL}) — recréée (reconstructible)")
        client.delete_collection(name)
    client.create_collection(collection_name=name,
                             vectors_config=VectorParams(size=QDRANT_VECTOR_SIZE, distance=Distance.COSINE))

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
        from qdrant_client.models import PointStruct

        client = _qdrant_client()
        _ensure_derived_collection(client, QDRANT_TOPICS_COLLECTION)

        point_id = _topic_point_id(owner_email, account, channel)
        topic_hash = hashlib.sha256(f"{QDRANT_EMBED_MODEL}:{topic_text}".encode()).hexdigest()

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

# Marge de routage (meilleur positif − meilleur négatif partagé). Mesuré sur 30 paraphrases + 30 phrases
# courantes (dont des faux amis : « retiens la porte », « mes souvenirs d'enfance »…) : nomic au seuil
# historique 0,05 = 13 commandes reconnues et 9 faux positifs ; bge-m3 à 0,13 = 21 reconnues, 3 faux positifs.
# Les #tags explicites restent la voie fiable ; ceci n'est que le repli en langage naturel.
INTENT_MARGIN_THRESHOLD = embed_config.threshold("intent_margin")

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
    from qdrant_client.models import PointStruct

    client = _qdrant_client()
    _ensure_derived_collection(client, QDRANT_INTENT_COLLECTION)

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

# Slot 15 = LOVE_MEMORY_SLOT (memory_manager.py) — souvenirs MUSE/LOVE
# (#love_rec), fusionnés dans cette même mémoire personnelle memory_{hex16}
# plutôt qu'une collection dédiée, mais toujours filtrables séparément.

PERSONA_RECALL_THRESHOLD = embed_config.threshold("recall")   # inutilisé : memory_manager applique RECALL_THRESHOLD

QDRANT_NETWORK_COLLECTION = "uplanet_network"

NETWORK_RECALL_THRESHOLD = embed_config.threshold("doc")

MEMORY_RECALL_THRESHOLD = embed_config.threshold("recall")   # inutilisé : memory_manager applique RECALL_THRESHOLD

def _recall_relevant_memories(owner_email, text, limit=3):
    """Souvenirs actifs du compte proches de `text` (Qdrant, memory_manager.py) : faits,
    épisodes, proches — pas les traits de style, servis à part par _recall_persona. Seuil =
    RECALL_THRESHOLD du modèle d'embedding (bge-m3). Dégradation silencieuse (chaîne vide)
    si Qdrant/Ollama indisponible — ne doit jamais bloquer la réponse à l'utilisateur."""
    try:
        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        results = mm.search_user_slot(owner_email, text, limit=limit,
                                       kinds=["fact", "episode", "person"])
    except Exception:
        return ""
    facts = [r.get("payload", {}).get("content", "") for r in results]
    facts = [f for f in facts if f]
    return "\n".join(f"- {f}" for f in facts)

def _remember_exchange(owner_email, text, answer):
    """Met le message du propriétaire en file d'apprentissage (memory_writer.py) : un
    process détaché en tire des souvenirs atomiques (faits, proches, projets), sans doublon
    ni contradiction — plus de message brut stocké tel quel (un 'bonjour' ou un message
    machine n'est pas un souvenir ; un STORY_KEY_BACKUP y avait fini avec sa clé AES).
    Ne mémorise volontairement PAS la réponse de BRO : un incident réel (2026-07-03) a
    montré qu'une hallucination mémorisée devient un « souvenir » que le LLM répète.
    Source « chat » : cochée par défaut, décochable dans Mon compte. Jamais bloquant."""
    try:
        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_writer as mw
        mw.ingest(owner_email, [text], source="chat")
    except Exception as e:
        print(f"[BRO_WATCH] Apprentissage mémoire indisponible pour {owner_email} : {e}")

def _recall_persona(owner_email, query="style communication opinion expertise", limit=2):
    """Traits de style / d'expertise du propriétaire (souvenirs de type « trait »).
    Retourne une chaîne formatée ou '' si vide / Qdrant indisponible."""
    try:
        import sys as _sys
        _sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        results = mm.search_user_slot(owner_email, query, kinds=["trait"], limit=limit)
        traits = [r.get("payload", {}).get("content", "") for r in results]
        traits = [t for t in traits if t]
        return " | ".join(traits)
    except Exception:
        return ""

def _recall_network_profile(username, limit=1):
    """Fiche d'un interlocuteur (collection Qdrant uplanet_network, alimentée par bro_backfill.py).
    EXACT d'abord : le point a pour identifiant sha256("<pseudo>@nostr") (bro_backfill) — aucune
    approximation quand le pseudo est connu. Repli sémantique seulement ensuite (la requête est mise au
    même format que ce qui est stocké : « pseudo (nostr) »). '' si rien / Qdrant indisponible."""
    if not username:
        return ""
    clean = username.lstrip("@").split("@")[0]   # "alice" depuis "@alice@mastodon.social"
    try:
        client = _qdrant_client()
        point_id = int(hashlib.sha256(f"{clean}@nostr".encode()).hexdigest()[:15], 16) % (2 ** 63)
        found = client.retrieve(collection_name=QDRANT_NETWORK_COLLECTION, ids=[point_id], with_payload=True)
        if found:
            return found[0].payload.get("fiche", "")
        hits = client.query_points(
            collection_name=QDRANT_NETWORK_COLLECTION,
            query=_qdrant_embed(f"{clean} (nostr)"),
            limit=limit,
            score_threshold=NETWORK_RECALL_THRESHOLD,
        ).points
        if hits:
            return hits[0].payload.get("fiche", "")
    except Exception:
        pass
    return ""

def _forget_memory(owner_email):
    """#oublie — efface ce que BRO a appris de ses échanges (souvenirs de source « chat » ;
    le reste — posts, photos, LOVE — s'efface depuis « Ce que BRO sait de moi »)."""
    try:
        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.delete_by_source(owner_email, "chat")
    except Exception:
        pass
    return "🗑️ Mémoire de nos échanges effacée."
