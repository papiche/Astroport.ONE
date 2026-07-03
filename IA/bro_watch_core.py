#!/usr/bin/env python3
"""
bro_watch_core — Logique partagée de surveillance passive multi-source, multi-tenant.

Utilisée par tout connecteur BRO (scrapers cookie : Mastodon, forums
Discourse...) qui a besoin de : détecter si un message mérite l'attention de
son propriétaire (mots-clés manuels, appris, ou correspondance sémantique
Qdrant), générer une suggestion de réponse via question.py, et notifier ce
propriétaire en DM NOSTR chiffré (TTL NIP-40).

Multi-tenant : chaque sociétaire MULTIPASS a sa propre config de surveillance,
identifiée par son email. Stockage unifié avec le système de cookies
(UPassport/services/cookie_store.py) — même fichier manifest, même event
NOSTR, chacun y écrivant sa part :

  ~/.zen/game/nostr/EMAIL/.cookie_manifest.json
  {
    "mastodon.social": {
      "cid": "Qm...",            # cookie chiffré (écrit par cookie_store.py)
      "uploaded_at": "...",
      "size": 919,
      "enabled": true,           # scraper actif/inactif (bro_watch_core.py)
      "params": {"channels": [...]},   # config surveillance (bro_watch_core.py)
      "log_cid": "Qm..."         # dernier log d'exécution, chiffré sur IPFS
    }
  }

Le manifest entier est republié en NOSTR kind 31903 (NIP-101 "Cookie Vault",
d=cookies) à chaque écriture — un seul event remplaçable par utilisateur,
couvrant cookies + paramètres + logs pour tous ses domaines. Seul le contenu
des cookies et des logs est chiffré (scellé avec la clé publique G1 du
propriétaire, via tools/natools.py) ; le manifest lui-même (métadonnées,
CID, paramètres de mots-clés) est publié en clair, comme les CID l'étaient
déjà avant cette évolution.

Convention de clé dans params.channels (une entrée par sous-canal surveillé) :
  - "channel"  : sous-canal au sein du domaine (ex: "notifications"/"timeline"
                 pour les scrapers cookie)
  - "keywords" : mots-clés manuels déclenchant une alerte
  - "learn_from"      : pseudo/auteur dont les messages alimentent
                         "learned_keywords" au lieu d'un déclenchement
  - "learned_keywords": mots-clés déduits automatiquement
  - "learn_messages"  : fenêtre glissante des derniers messages appris (20 max)
  - "always_alert"    : ignore les mots-clés, alerte sur chaque item (ex: mention)
"""

import os
import re
import json
import hashlib
import tempfile
import subprocess

BRO_IA_PATH = os.path.expanduser("~/.zen/Astroport.ONE/IA")
TOOLS_PATH = os.path.expanduser("~/.zen/Astroport.ONE/tools")
NOSTR_DIR = os.path.expanduser("~/.zen/game/nostr")
DEFAULT_RELAY = "wss://relay.copylaradio.com"
DM_TTL_DAYS = 7
MANIFEST_FILENAME = ".cookie_manifest.json"
MANIFEST_NOSTR_KIND = 31903
MANIFEST_NOSTR_DTAG = "cookies"
DIGEST_PREFIX = "📋 Rapport quotidien BRO"
# Tout message sortant de BRO (rapports ET confirmations de commande) commence
# par un de ces marqueurs — sert à les ignorer en écoutant les commandes
# entrantes, sinon une confirmation ("✅ Surveillance désactivée") serait elle-
# même réinterprétée comme une nouvelle commande au cycle suivant.
BOT_REPLY_MARKERS = ("📋", "✅", "🤔")

# ── Correspondance sémantique (Qdrant + Ollama) ─────────────────────────
QDRANT_HOST = "localhost"
QDRANT_PORT = 6333
QDRANT_TOPICS_COLLECTION = "bro_watch_topics"
QDRANT_EMBED_MODEL = "nomic-embed-text"
QDRANT_VECTOR_SIZE = 768
SEMANTIC_THRESHOLD = 0.70  # calibré empiriquement (nomic-embed-text a un plancher élevé ~0.5-0.6 même hors-sujet)


# ── Emplacements par propriétaire (email MULTIPASS) ─────────────────────

def _owner_dir(owner_email):
    return os.path.join(NOSTR_DIR, owner_email)


def _manifest_path(owner_email):
    return os.path.join(_owner_dir(owner_email), MANIFEST_FILENAME)


def _owner_hex(owner_email):
    try:
        with open(os.path.join(_owner_dir(owner_email), "HEX")) as f:
            return f.read().strip()
    except Exception:
        return ""


def _owner_nsec(owner_email):
    secret_file = os.path.join(_owner_dir(owner_email), ".secret.nostr")
    try:
        with open(secret_file) as f:
            content = f.read()
        for part in content.replace("\n", ";").split(";"):
            part = part.strip()
            if part.startswith("NSEC="):
                return part.split("=", 1)[1].strip("\"'")
    except Exception:
        pass
    return ""


def _owner_g1_pubkey(owner_email):
    """Clé publique G1 (pour chiffrement natools.py seal box), depuis .secret.dunikey."""
    for name in (".secret.dunikey", "secret.dunikey"):
        p = os.path.join(_owner_dir(owner_email), name)
        if os.path.isfile(p):
            with open(p) as f:
                for line in f:
                    if line.startswith("pub:"):
                        return line.split(":", 1)[1].strip()
    return None


# ── Manifest cookie (partagé avec cookie_store.py) ──────────────────────

def _load_manifest(owner_email):
    try:
        with open(_manifest_path(owner_email)) as f:
            return json.load(f)
    except Exception:
        return {}


def _save_manifest(owner_email, manifest):
    path = _manifest_path(owner_email)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    os.chmod(path, 0o600)
    _publish_manifest_to_nostr(owner_email, manifest)


def _publish_manifest_to_nostr(owner_email, manifest):
    """Republie le manifest complet (kind 31903, d=cookies) — fire-and-forget,
    identique au mécanisme de UPassport/services/cookie_store.py."""
    nsec_file = os.path.join(_owner_dir(owner_email), ".secret.nostr")
    if not os.path.isfile(nsec_file):
        return
    script = os.path.join(TOOLS_PATH, "nostr_send_note.py")
    try:
        subprocess.run([
            "python3", script,
            "--keyfile", nsec_file,
            "--content", json.dumps(manifest, ensure_ascii=False),
            "--tags", json.dumps([["d", MANIFEST_NOSTR_DTAG], ["t", "cookies"], ["t", "uplanet"]]),
            "--kind", str(MANIFEST_NOSTR_KIND),
            "--relays", ",".join(_load_relays()),
        ], capture_output=True, text=True, timeout=15)
    except Exception as e:
        print(f"[BRO_WATCH] Publication manifest cookie échouée pour {owner_email} : {e}")


# ── Chiffrement seal box (natools.py + clé G1) — mêmes primitives que
#    cookie_store.py, réutilisées ici pour les logs d'exécution ────────

def _natools_encrypt(owner_email, content_bytes):
    pubkey = _owner_g1_pubkey(owner_email)
    if not pubkey:
        return None
    with tempfile.TemporaryDirectory() as tmp:
        plain = os.path.join(tmp, "data.txt")
        enc = os.path.join(tmp, "data.enc")
        with open(plain, "wb") as f:
            f.write(content_bytes)
        try:
            proc = subprocess.run(
                ["python3", os.path.join(TOOLS_PATH, "natools.py"), "encrypt",
                 "-p", pubkey, "-i", plain, "-o", enc],
                capture_output=True, text=True, timeout=15
            )
        except Exception:
            return None
        if proc.returncode != 0 or not os.path.isfile(enc):
            return None
        try:
            result = subprocess.run(["ipfs", "add", "-q", enc],
                                     capture_output=True, text=True, timeout=30)
        except Exception:
            return None
        return result.stdout.strip() or None


def _natools_decrypt(owner_email, cid):
    dunikey = None
    for name in (".secret.dunikey", "secret.dunikey"):
        p = os.path.join(_owner_dir(owner_email), name)
        if os.path.isfile(p):
            dunikey = p
            break
    if not dunikey:
        return None
    with tempfile.TemporaryDirectory() as tmp:
        enc = os.path.join(tmp, "data.enc")
        plain = os.path.join(tmp, "data.txt")
        try:
            subprocess.run(["ipfs", "get", "-o", enc, f"/ipfs/{cid}"],
                            capture_output=True, text=True, timeout=30)
        except Exception:
            return None
        if not os.path.isfile(enc):
            return None
        try:
            proc = subprocess.run(
                ["python3", os.path.join(TOOLS_PATH, "natools.py"), "decrypt",
                 "-f", "pubsec", "-k", dunikey, "-i", enc, "-o", plain],
                capture_output=True, text=True, timeout=15
            )
        except Exception:
            return None
        if proc.returncode != 0 or not os.path.isfile(plain):
            return None
        with open(plain, "rb") as f:
            return f.read()


def store_log(owner_email, account, log_text):
    """Chiffre le log d'exécution et le pin sur IPFS, met à jour le manifest
    (log_cid). Dégradation gracieuse si pas de clé G1 / IPFS indisponible —
    le fichier log en clair (déjà écrit par l'appelant) reste la référence."""
    cid = _natools_encrypt(owner_email, log_text.encode("utf-8"))
    if not cid:
        return None
    manifest = _load_manifest(owner_email)
    manifest.setdefault(account, {})["log_cid"] = cid
    _save_manifest(owner_email, manifest)
    return cid


def get_log(owner_email, account):
    """Déchiffre le dernier log stocké sur IPFS pour ce domaine, si disponible."""
    manifest = _load_manifest(owner_email)
    cid = manifest.get(account, {}).get("log_cid")
    if not cid:
        return None
    content = _natools_decrypt(owner_email, cid)
    return content.decode("utf-8", errors="replace") if content else None


# ── Activation/désactivation d'un scraper ───────────────────────────────

def is_scraper_enabled(owner_email, account):
    manifest = _load_manifest(owner_email)
    return manifest.get(account, {}).get("enabled", True)


def set_scraper_enabled(owner_email, account, enabled):
    manifest = _load_manifest(owner_email)
    manifest.setdefault(account, {})["enabled"] = bool(enabled)
    _save_manifest(owner_email, manifest)


# ── Config de surveillance (params, par domaine) ────────────────────────

def load_watch_data(owner_email, account):
    manifest = _load_manifest(owner_email)
    return manifest.get(account, {}).get("params", {"channels": []})


def save_watch_data(owner_email, account, data):
    manifest = _load_manifest(owner_email)
    manifest.setdefault(account, {})["params"] = data
    _save_manifest(owner_email, manifest)


def load_watch_list(owner_email, account):
    return load_watch_data(owner_email, account).get("channels", [])


def get_watch_entry(owner_email, account, channel):
    return next(
        (w for w in load_watch_list(owner_email, account) if w.get("channel") == channel),
        None
    )


def update_watch_entry(owner_email, account, channel, **fields):
    data = load_watch_data(owner_email, account)
    data.setdefault("channels", [])
    for c in data["channels"]:
        if c.get("channel") == channel:
            c.update(fields)
            break
    save_watch_data(owner_email, account, data)


def ensure_watch_entry(owner_email, account, channel, **defaults):
    """Crée l'entrée si absente (onboarding sans étape manuelle). Ne touche
    jamais une entrée existante — le propriétaire reste maître de sa config."""
    if get_watch_entry(owner_email, account, channel) is not None:
        return
    data = load_watch_data(owner_email, account)
    data.setdefault("channels", [])
    entry = {"channel": channel, "keywords": []}
    entry.update(defaults)
    data["channels"].append(entry)
    save_watch_data(owner_email, account, data)
    print(f"[BRO_WATCH] Source auto-enregistrée pour {owner_email} : {account}/{channel} ({defaults})")


# ── Envoi des DM ("note à soi-même" — signé et adressé par la propre clé
#    MULTIPASS du destinataire, jamais la clé NODE de la station) ────────

def _load_relays():
    relays = [DEFAULT_RELAY]
    try:
        proc = subprocess.run(
            ["bash", "-c", f"source {TOOLS_PATH}/my.sh >/dev/null 2>&1; echo \"$myRELAY\""],
            capture_output=True, text=True, timeout=30
        )
        local_relay = proc.stdout.strip()
        if local_relay and local_relay not in relays:
            relays.append(local_relay)
    except Exception:
        pass
    return relays


RELAYS = _load_relays()


def send_dm_to_owner(owner_email, message, ttl_days=DM_TTL_DAYS):
    """Publie un DM NOSTR chiffré 'à soi-même' : signé et adressé par la
    propre clé MULTIPASS du propriétaire (jamais la clé NODE de la station).
    Le message apparaît comme une note personnelle chiffrée dans son propre
    historique NOSTR, déchiffrable uniquement par lui."""
    nsec = _owner_nsec(owner_email)
    recipient_hex = _owner_hex(owner_email)
    if not nsec or not recipient_hex:
        print(f"[BRO_WATCH] DM impossible pour {owner_email} : nsec ou HEX manquant.")
        return False
    script = os.path.join(TOOLS_PATH, "nostr_send_secure_dm.py")
    sent = False
    for relay in RELAYS:
        try:
            proc = subprocess.run(
                ["python3", script, "--nsec-stdin", recipient_hex, message, relay,
                 "--ttl-days", str(ttl_days)],
                input=nsec + "\n", capture_output=True, text=True, timeout=15
            )
            if proc.returncode == 0:
                sent = True
        except Exception as e:
            print(f"[BRO_WATCH] Erreur envoi DM à {owner_email} via {relay} : {e}")
    return sent


# ── Apprentissage / correspondance mots-clés ────────────────────────────

def learn_from_message(owner_email, entry, account, channel, text):
    """Accumule un message de la personne 'learn_from' et régénère les
    mots-clés appris via question.py. Persiste directement dans le manifest."""
    messages = entry.get("learn_messages", [])
    messages.append(text)
    messages = messages[-20:]

    prompt = (
        "Voici les derniers messages écrits par une personne :\n\n"
        + "\n".join(f"- {m}" for m in messages)
        + "\n\nExtrait 5 à 10 mots-clés ou thèmes qui reviennent, en français, "
          "sous forme de liste séparée par des virgules, sans phrase d'introduction, sans numérotation."
    )
    result = subprocess.run([
        "python3", f"{BRO_IA_PATH}/question.py", prompt
    ], capture_output=True, text=True)
    raw = result.stdout.strip()
    learned = sorted({k.strip().lower() for k in raw.replace("\n", ",").split(",") if k.strip()})

    print(f"[BRO_WATCH] Mots-clés appris pour {owner_email} — {account}/{channel} : {learned}")
    update_watch_entry(owner_email, account, channel, learn_messages=messages, learned_keywords=learned)
    return learned


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


def matches_keywords(entry, text, owner_email=None, account=None, channel=None):
    # Source où chaque item est par nature pertinent (ex: mention Mastodon) —
    # pas besoin de mots-clés, tout déclenche une suggestion.
    if entry.get("always_alert"):
        return True
    keywords = list(entry.get("keywords", []) or []) + list(entry.get("learned_keywords", []) or [])
    # Liste vide (mots-clés pas encore appris/configurés) → ne jamais alerter par défaut.
    if not keywords:
        return False
    lowered = text.lower()
    if any(k.lower() in lowered for k in keywords if k):
        return True
    # Repli sémantique : capte les messages sur le même sujet sans le mot exact.
    if owner_email and account and channel:
        return semantic_match(owner_email, account, channel, entry, text)
    return False


def generate_suggestion(context_label, username, text, examples=None):
    examples_block = ""
    if examples:
        examples_block = (
            "\n\nExemples de réponses déjà postées par le propriétaire par le passé "
            "(imite ce ton et ce style) :\n"
            + "\n".join(
                f"- Message reçu : « {e['original_text'][:150]} » "
                f"→ Réponse postée : « {e['actual_text'][:200]} »"
                for e in examples
            )
        )
    prompt = (
        f"Voici un message reçu sur {context_label}, "
        f"écrit par {username} :\n\n« {text} »"
        f"{examples_block}\n\n"
        "Propose une réponse brève et appropriée que le destinataire pourrait envoyer."
    )
    result = subprocess.run([
        "python3", f"{BRO_IA_PATH}/question.py", prompt
    ], capture_output=True, text=True)
    return result.stdout.strip() or "(BRO n'a pas pu générer de suggestion.)"


# ── Boucle de rétroaction : apprendre de ce que le propriétaire poste
#    réellement en réponse aux suggestions, pour progresser vers l'auto-réponse

FEEDBACK_WINDOW_DAYS = 5
FEEDBACK_MATCH_THRESHOLD = 0.75
FEEDBACK_VERBATIM_THRESHOLD = 0.9
MAX_PENDING_FEEDBACK = 50


def _now_iso():
    import datetime
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _record_pending_suggestion(owner_email, account, channel, item, suggestion):
    data = load_watch_data(owner_email, account)
    pending = data.setdefault("pending_feedback", [])
    pending.append({
        "channel": channel,
        "url": item.get("url"),
        "original_text": item.get("text", "")[:500],
        "original_username": item.get("username", ""),
        "suggestion": suggestion,
        "created_at": _now_iso(),
        "resolved": False,
    })
    data["pending_feedback"] = pending[-MAX_PENDING_FEEDBACK:]
    save_watch_data(owner_email, account, data)


def resolve_pending_feedback(owner_email, account, own_posts):
    """Compare les suggestions en attente aux posts réels du propriétaire
    (own_posts : liste de dicts {"text": str, "url": str (optionnel)}).
    Marque chaque suggestion "used" (postée telle quelle), "used_modified"
    (postée avec des changements) ou "ignored" (fenêtre expirée sans écho).
    Dégradation gracieuse si Qdrant/Ollama indisponible (ne résout rien)."""
    import datetime
    data = load_watch_data(owner_email, account)
    pending = data.get("pending_feedback", [])
    if not pending or not own_posts:
        return

    now = datetime.datetime.now(datetime.timezone.utc)
    changed = False
    for p in pending:
        if p.get("resolved"):
            continue
        try:
            created = datetime.datetime.fromisoformat(p["created_at"])
        except Exception:
            created = now
        age_days = (now - created).total_seconds() / 86400

        best_score, best_post = 0.0, None
        try:
            suggestion_vec = _qdrant_embed(p["suggestion"])
            for post in own_posts:
                score = _cosine(suggestion_vec, _qdrant_embed(post.get("text", "")))
                if score > best_score:
                    best_score, best_post = score, post
        except Exception as e:
            print(f"[BRO_WATCH] Rétroaction : Qdrant/Ollama indisponible ({e})")

        if best_post and best_score >= FEEDBACK_MATCH_THRESHOLD:
            p["resolved"] = True
            p["outcome"] = "used" if best_score >= FEEDBACK_VERBATIM_THRESHOLD else "used_modified"
            p["actual_text"] = best_post.get("text", "")[:500]
            p["match_score"] = round(best_score, 3)
            changed = True
            print(f"[BRO_WATCH] Rétroaction {owner_email}/{account} : suggestion {p['outcome']} "
                  f"(score {p['match_score']})")
        elif age_days > FEEDBACK_WINDOW_DAYS:
            p["resolved"] = True
            p["outcome"] = "ignored"
            changed = True

    if changed:
        data["pending_feedback"] = pending[-MAX_PENDING_FEEDBACK:]
        save_watch_data(owner_email, account, data)


def get_good_examples(owner_email, account, limit=3):
    """Dernières suggestions effectivement utilisées (verbatim ou modifiées),
    pour enrichir le prompt de generate_suggestion (few-shot de style)."""
    data = load_watch_data(owner_email, account)
    used = [p for p in data.get("pending_feedback", [])
            if p.get("outcome") in ("used", "used_modified") and p.get("actual_text")]
    return used[-limit:]


def process_watch_digest(owner_email, account, channel, items, context_label=None, own_posts=None):
    """
    Point d'entrée pour les scrapers cookie à cycle quotidien (Mastodon,
    forums Discourse...). Génère une suggestion PAR item pertinent, envoie
    un DM récapitulatif au propriétaire, et enregistre chaque suggestion
    pour la boucle de rétroaction (résolue au prochain appel via own_posts).

    Les items écrits par la personne "learn_from" (si configurée) alimentent
    l'apprentissage des mots-clés au lieu de compter comme "pertinents".

    items     : liste de dicts {"username": str, "text": str, "url": str (optionnel)}
    own_posts : liste de dicts {"text": str, "url": str (optionnel)} — posts
                récents du propriétaire, pour résoudre les suggestions en
                attente d'un appel précédent (optionnel).
    Retourne True si un watch_entry existait pour (owner_email, account, channel), False sinon.
    """
    entry = get_watch_entry(owner_email, account, channel)
    if entry is None:
        return False

    if own_posts:
        resolve_pending_feedback(owner_email, account, own_posts)
        entry = get_watch_entry(owner_email, account, channel)  # recharge pending_feedback

    context_label = context_label or f"{account}/{channel}"
    learn_from = (entry.get("learn_from") or "").lstrip("@").lower()

    relevant = []
    for it in items:
        username = it.get("username", "")
        text = it.get("text", "")
        if learn_from and username.lstrip("@").lower() == learn_from:
            learn_from_message(owner_email, entry, account, channel, text)
            entry = get_watch_entry(owner_email, account, channel)  # recharge learned_keywords
            continue
        if matches_keywords(entry, text, owner_email=owner_email, account=account, channel=channel):
            relevant.append(it)

    if not relevant:
        print(f"[BRO_WATCH] {owner_email} — {context_label} : rien de pertinent aujourd'hui "
              f"({len(items)} item(s) vu(s)).")
        return True

    examples = get_good_examples(owner_email, account)
    lines = []
    for it in relevant:
        suggestion = generate_suggestion(
            context_label, it.get("username", "?"), it.get("text", ""), examples=examples
        )
        _record_pending_suggestion(owner_email, account, channel, it, suggestion)
        line = f"- {it.get('username', '?')} : « {it.get('text', '')[:300]} »"
        if it.get("url"):
            line += f"\n  🔗 {it['url']}"
        line += f"\n  💬 Suggestion : {suggestion}"
        lines.append(line)

    dm_text = (
        f"{DIGEST_PREFIX} — {context_label}\n"
        f"{len(relevant)} message(s) à examiner sur {len(items)} vu(s)\n\n"
        + "\n\n".join(lines)
    )
    if send_dm_to_owner(owner_email, dm_text):
        print(f"[BRO_WATCH] Rapport quotidien envoyé à {owner_email} ({len(relevant)} item(s)).")
    else:
        print(f"[BRO_WATCH] Échec envoi rapport quotidien à {owner_email}.")
    return True


# ── Commandes entrantes : le propriétaire répond à BRO dans son propre canal
#    NOSTR self-DM (BRO est son clone numérique — pas une identité séparée).
#    L'identité NODE de la station n'intervient pas ici (réservée au relais
#    inter-stations en cas de roaming) ; on lit et on répond avec la clé du
#    propriétaire lui-même, comme pour l'émission des rapports.

COMMAND_LAST_CHECK_KEY = "_bro_commands"  # section top-level du manifest (pas liée à un domaine)


def _fetch_self_dms_since(owner_email, since_ts):
    """Récupère les events kind 4 self-DM (author == #p == propre clé) publiés
    après since_ts, sur tous les relais connus. Dégradation gracieuse (liste
    vide) si aucun relay n'est joignable."""
    import asyncio
    import websockets

    hex_pk = _owner_hex(owner_email)
    if not hex_pk:
        return []

    async def _query_relay(relay):
        events = []
        try:
            async with websockets.connect(relay, open_timeout=5) as ws:
                req = ["REQ", "brocmd", {"kinds": [4], "authors": [hex_pk], "#p": [hex_pk],
                                          "since": since_ts, "limit": 50}]
                await ws.send(json.dumps(req))
                while True:
                    msg = await asyncio.wait_for(ws.recv(), timeout=5)
                    data = json.loads(msg)
                    if data[0] == "EVENT":
                        events.append(data[2])
                    elif data[0] == "EOSE":
                        break
        except Exception:
            pass
        return events

    async def _query_all():
        seen, merged = set(), []
        for relay in RELAYS:
            for ev in await _query_relay(relay):
                if ev["id"] not in seen:
                    seen.add(ev["id"])
                    merged.append(ev)
        return merged

    return asyncio.run(_query_all())


def _decrypt_self_dm(owner_email, event):
    nsec = _owner_nsec(owner_email)
    if not nsec:
        return None
    script = os.path.join(TOOLS_PATH, "nostr_node_intercom.py")
    try:
        proc = subprocess.run(
            ["python3", script, "decrypt"],
            input=json.dumps(event), capture_output=True, text=True, timeout=15,
            env={**os.environ, "NOSTR_NSEC": nsec},
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            return None
        envelope = json.loads(proc.stdout)
        return envelope.get("payload", {}).get("text")
    except Exception:
        return None


def _all_accounts(owner_email):
    return [k for k in _load_manifest(owner_email) if not k.startswith("_")]


def _find_most_recent_pending(owner_email):
    """Cherche, tous domaines confondus, la suggestion en attente la plus
    récente (non résolue). Retourne (account, entry) ou (None, None)."""
    best_account, best_entry, best_date = None, None, None
    import datetime
    for account in _all_accounts(owner_email):
        for p in load_watch_data(owner_email, account).get("pending_feedback", []):
            if p.get("resolved"):
                continue
            try:
                created = datetime.datetime.fromisoformat(p["created_at"])
            except Exception:
                continue
            if best_date is None or created > best_date:
                best_account, best_entry, best_date = account, p, created
    return best_account, best_entry


def _resolve_most_recent_pending(owner_email, outcome, actual_text):
    account, entry = _find_most_recent_pending(owner_email)
    if entry is None:
        return False
    data = load_watch_data(owner_email, account)
    for p in data.get("pending_feedback", []):
        if p is entry or (p.get("url") == entry.get("url") and p.get("created_at") == entry.get("created_at")):
            p["resolved"] = True
            p["outcome"] = outcome
            p["actual_text"] = actual_text
            break
    save_watch_data(owner_email, account, data)
    return True


# Libellés humains pour aider le LLM à faire le lien entre le vocabulaire
# naturel de l'utilisateur ("le fil", "les mentions"...) et le nom technique
# exact du canal à utiliser dans l'action JSON.
CHANNEL_ALIASES = {
    "notifications": "notifications / mentions reçues",
    "timeline": "fil d'actualité / posts suivis",
    "new_topics": "nouveaux sujets du forum",
}


def format_context_entries(entries):
    """Formate une liste plate d'entrées {account, channel, keywords, ...} en
    texte de contexte pour le prompt d'interprétation. Pure (aucun accès
    disque) — réutilisée par _watch_context_summary (données live) et le
    harnais d'évaluation (contexte figé, voir IA/tests/bro_watch_command_eval.json)."""
    lines = []
    for ch in entries:
        account = ch.get("account", "?")
        channel = ch.get("channel", "?")
        channel_label = CHANNEL_ALIASES.get(channel, channel)
        learn_from = ch.get("learn_from")
        keywords = ch.get("keywords", [])
        if learn_from:
            state = f"apprend depuis @{learn_from}"
        elif keywords:
            state = f"mots-clés actuels : {', '.join(keywords)}"
        elif ch.get("always_alert"):
            state = "alerte sur tout (mentions)"
        else:
            state = "pas encore configuré"
        lines.append(f'- domaine="{account}" canal="{channel}" ({channel_label}) — {state}')
    return "\n".join(lines) if lines else "(aucune source surveillée pour l'instant)"


def _watch_context_summary(owner_email):
    """Décrit les sources surveillées RÉELLES du propriétaire (pour donner du
    contexte au LLM d'interprétation)."""
    entries = []
    for account in _all_accounts(owner_email):
        for ch in load_watch_list(owner_email, account):
            entries.append({**ch, "account": account})
    return format_context_entries(entries)


def _build_interpretation_prompt(text, context_summary, pending_line=""):
    """Construit le prompt d'interprétation — isolé de l'accès disque/réseau
    pour rester testable avec un contexte fixe (voir IA/tests/eval_command_interpretation.py)."""
    return (
        "Tu interprètes un message envoyé par le propriétaire à BRO, son assistant IA "
        "personnel qui surveille des comptes web pour son compte.\n\n"
        f"Sources actuellement surveillées (utilise EXACTEMENT les valeurs domaine=\"...\" "
        f"et canal=\"...\" ci-dessous dans ta réponse, jamais leur libellé entre parenthèses) "
        f":\n{context_summary}"
        f"{pending_line}\n\n"
        f"Message du propriétaire : « {text} »\n\n"
        "Réponds STRICTEMENT avec un seul objet JSON (aucun texte autour), au format "
        "correspondant à l'intention détectée, parmi :\n"
        '{"action": "set_keywords", "domain": "...", "channel": "...", "keywords": ["..."]}\n'
        '{"action": "set_learn_from", "domain": "...", "channel": "...", "handle": "..."}\n'
        '{"action": "toggle", "domain": "...", "enabled": true}\n'
        '{"action": "confirm_suggestion"}\n'
        '{"action": "correct_suggestion", "text": "..."}\n'
        '{"action": "none"}\n'
        "Utilise \"none\" si le message ne correspond à aucune de ces actions, ou si le "
        "domaine/canal visé n'est pas identifiable avec certitude parmi les sources listées."
    )


COMMAND_INTERPRETATION_MODEL = "qwen2.5-coder:14b"


def interpret_command_with_context(text, context_summary, pending_line="", model=None):
    """Interprétation pure (sans accès disque/réseau côté contexte) — appelle
    question.py avec un prompt donné et parse le JSON retourné. Réutilisée par
    _interpret_natural_command (données live) et le harnais d'évaluation
    (contexte figé, reproductible, comparaison inter-modèles)."""
    prompt = _build_interpretation_prompt(text, context_summary, pending_line)
    try:
        result = subprocess.run([
            "python3", f"{BRO_IA_PATH}/question.py", prompt,
            "--temperature", "0.1", "--model", model or COMMAND_INTERPRETATION_MODEL,
        ], capture_output=True, text=True, timeout=60)
    except Exception:
        return None

    match = re.search(r"\{.*\}", result.stdout, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except Exception:
        return None


def _interpret_natural_command(owner_email, text):
    """Fait interpréter un message en langage naturel par Ollama (question.py),
    avec le contexte réel des sources surveillées du propriétaire. Retourne un
    dict d'action structuré, ou None si non interprétable/non pertinent."""
    account, entry = _find_most_recent_pending(owner_email)
    pending_line = ""
    if entry:
        pending_line = (
            f"\nSuggestion la plus récente en attente de validation ({account}) : "
            f"« {entry.get('suggestion', '')} » — proposée en réponse à : "
            f"« {entry.get('original_text', '')[:150]} »"
        )
    return interpret_command_with_context(text, _watch_context_summary(owner_email), pending_line)


# Garde-fou contre les hallucinations du LLM d'interprétation : une action
# n'est exécutée que si le message contient au moins un indice lexical
# cohérent avec le type d'action détecté (un petit modèle local se trompe
# parfois de catégorie tout en produisant un JSON syntaxiquement valide).
_ACTION_SANITY_HINTS = {
    "toggle": ["actif", "active", "désactiv", "desactiv", "arrête", "arrete",
               "stop", "coupe", "relance", "reprend", "remet", "remets",
               "surveill", "veille", "suivre"],
    "set_keywords": ["mot-clé", "mot clé", "mots-clé", "mots clé", "keyword", "surveille"],
    "set_learn_from": ["apprend", "apprentissage", "apprends"],
    "confirm_suggestion": ["ok", "oui", "envoie", "valide", "d'accord", "daccord"],
    "correct_suggestion": ["plutôt", "plutot", "corrige", "préfère", "prefere", "à la place", "a la place"],
}


def _sanity_check_action(text, action):
    hints = _ACTION_SANITY_HINTS.get(action.get("action"))
    if not hints:
        return True  # pas de règle définie pour ce type d'action → on fait confiance
    lowered = text.lower()
    return any(h in lowered for h in hints)


def _execute_interpreted_action(owner_email, action):
    """Exécute une action structurée (issue de _interpret_natural_command).
    Retourne le message de confirmation, ou None si l'action est invalide."""
    kind = action.get("action")
    try:
        if kind == "set_keywords":
            domain, channel = action["domain"], action["channel"]
            keywords = [k.strip() for k in action.get("keywords", []) if k and k.strip()]
            update_watch_entry(owner_email, domain, channel, keywords=keywords)
            return f"✅ Mots-clés mis à jour pour {domain}/{channel} : {', '.join(keywords) or '(aucun)'}"

        if kind == "set_learn_from":
            domain, channel = action["domain"], action["channel"]
            handle = action.get("handle", "").lstrip("@")
            if not handle:
                return None
            update_watch_entry(owner_email, domain, channel, learn_from=handle,
                                learned_keywords=[], learn_messages=[])
            return f"✅ {domain}/{channel} apprendra désormais depuis @{handle}."

        if kind == "toggle":
            domain = action["domain"]
            enabled = bool(action.get("enabled"))
            set_scraper_enabled(owner_email, domain, enabled)
            return f"✅ Surveillance {domain} : {'activée' if enabled else 'désactivée'}."

        if kind == "confirm_suggestion":
            if _resolve_most_recent_pending(owner_email, "used", None):
                return "✅ Suggestion validée — merci, ça enrichit mes exemples de style."
            return "🤔 Aucune suggestion en attente à valider."

        if kind == "correct_suggestion":
            actual = (action.get("text") or "").strip()
            if actual and _resolve_most_recent_pending(owner_email, "used_modified", actual):
                return "✅ Noté — je retiens cette version pour mieux coller à votre style."
            return "🤔 Aucune suggestion en attente à corriger."
    except (KeyError, TypeError):
        return None
    return None


def _handle_hashtag_command(owner_email, text):
    """Filet de sécurité déterministe (syntaxe #commande) — utilisé si
    l'interprétation en langage naturel échoue ou est indisponible."""
    stripped = text.strip()
    lowered = stripped.lower()

    # #ok → confirme la suggestion la plus récente telle quelle
    if lowered in ("#ok", "#oui", "#envoie", "#envoie ça", "#envoie ca"):
        if _resolve_most_recent_pending(owner_email, "used", None):
            return "✅ Suggestion validée — merci, ça enrichit mes exemples de style."
        return "🤔 Aucune suggestion en attente à valider."

    # #plutot TEXTE / #plutôt TEXTE → corrige la suggestion la plus récente
    m = re.match(r"^#plut[oô]t[:\s]+(.+)$", stripped, re.IGNORECASE | re.DOTALL)
    if m:
        actual = m.group(1).strip()
        if _resolve_most_recent_pending(owner_email, "used_modified", actual):
            return "✅ Noté — je retiens cette version pour mieux coller à votre style."
        return "🤔 Aucune suggestion en attente à corriger."

    # #watch DOMAINE on|off
    m = re.match(r"^#watch\s+(\S+)\s+(on|off)\s*$", stripped, re.IGNORECASE)
    if m:
        domain, state = m.group(1), m.group(2).lower()
        set_scraper_enabled(owner_email, domain, state == "on")
        return f"✅ Surveillance {domain} : {'activée' if state == 'on' else 'désactivée'}."

    # #watch DOMAINE CANAL keywords a, b, c
    m = re.match(r"^#watch\s+(\S+)\s+(\S+)\s+keywords?[:\s]+(.+)$", stripped, re.IGNORECASE | re.DOTALL)
    if m:
        domain, channel, kw_raw = m.group(1), m.group(2), m.group(3)
        keywords = [k.strip() for k in kw_raw.split(",") if k.strip()]
        update_watch_entry(owner_email, domain, channel, keywords=keywords)
        return f"✅ Mots-clés mis à jour pour {domain}/{channel} : {', '.join(keywords)}"

    # #watch DOMAINE CANAL learn_from @compte
    m = re.match(r"^#watch\s+(\S+)\s+(\S+)\s+learn_from[:\s]+(\S+)\s*$", stripped, re.IGNORECASE)
    if m:
        domain, channel, handle = m.group(1), m.group(2), m.group(3).lstrip("@")
        update_watch_entry(owner_email, domain, channel, learn_from=handle,
                            learned_keywords=[], learn_messages=[])
        return f"✅ {domain}/{channel} apprendra désormais depuis @{handle}."

    return None


## Déclencheur d'auto-amélioration — réservé au capitaine, jamais automatique.
## Portée : uniquement le prompt/modèle d'interprétation des commandes
## (arbor_self_improve.py), jamais le reste du code. Ne merge jamais seul —
## voir _notify_captain_arbor dans arbor_self_improve.py.
ARBOR_TRIGGERS = ("#arbor", "#ameliore-toi", "#améliore-toi", "#improve")


def _is_captain(owner_email):
    """Compare par HEX plutôt que par email brut : bro_resolve_email (bash)
    peut retourner un alias non-canonique (ex: CAPTAIN/) pour le même hex
    plutôt que l'email réel — la comparaison de chaînes serait alors fausse
    même quand l'appelant est bien le capitaine."""
    captain_email = os.environ.get("CAPTAINEMAIL", "").strip()
    if not captain_email:
        return False
    if owner_email.strip().lower() == captain_email.strip().lower():
        return True
    owner_hex = _owner_hex(owner_email)
    return bool(owner_hex) and owner_hex == _owner_hex(captain_email)


def _trigger_arbor_self_improve(owner_email):
    """Lance arbor_self_improve.py --apply en tâche détachée (peut prendre
    plusieurs minutes, plusieurs appels Ollama) — ne bloque pas le traitement
    du message courant. Le script notifie lui-même le capitaine par DM NODE
    si une hypothèse validée est prête à être relue (jamais mergée seule)."""
    script = os.path.join(BRO_IA_PATH, "tests", "arbor_self_improve.py")
    if not os.path.isfile(script):
        return "⚠️ arbor_self_improve.py introuvable sur cette station."
    try:
        subprocess.Popen(
            ["python3", script, "--apply", "--notify-captain"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        return f"⚠️ Échec du lancement de l'auto-amélioration : {e}"
    return ("🔧 Auto-amélioration du prompt d'interprétation lancée (quelques minutes). "
            "Si une piste validée dev+held-out est trouvée, une branche isolée sera proposée "
            "et vous serez prévenu par message de la station.")


# Corpus partagé (tous propriétaires confondus) des demandes que BRO n'a pas
# su satisfaire par une commande reconnue — mine par arbor_self_improve.py
# --mine-requests pour détecter des patterns récurrents et proposer au
# capitaine de nouveaux outils Web2 à déléguer (jamais d'auto-implémentation,
# seulement détection + notification — voir la gouvernance actée).
TOOL_REQUESTS_LOG = os.path.expanduser("~/.zen/flashmem/bro_tool_requests.jsonl")


def _log_tool_request(owner_email, text, reply):
    import time as _time
    entry = {"ts": int(_time.time()), "owner": owner_email, "text": text, "reply": reply}
    try:
        os.makedirs(os.path.dirname(TOOL_REQUESTS_LOG), exist_ok=True)
        with open(TOOL_REQUESTS_LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        pass


def _conversational_reply(owner_email, text):
    """Réponse en langage naturel quand le message ne correspond à aucune
    commande de surveillance reconnue — pour que le canal self-DM avec BRO
    reste vivant même hors commande (BRO reste son clone numérique, jamais
    silencieux sans raison). Chaque repli ici est aussi un signal de "besoin
    non couvert" — journalisé pour l'analyse Arbor continue multi-utilisateurs."""
    context_summary = _watch_context_summary(owner_email)
    prompt = (
        "Tu es BRO, l'assistant IA personnel (clone numérique) du propriétaire de ce compte UPlanet. "
        "Il te parle en messages privés NOSTR chiffrés (canal self-DM). Tu gères la surveillance de "
        "ses sources web (Mastodon, forums) : activer/désactiver, mots-clés, apprentissage de style, "
        "validation/correction de suggestions de réponse.\n\n"
        f"Sources actuellement configurées :\n{context_summary or '(aucune pour le moment)'}\n\n"
        "Réponds brièvement (3-5 lignes max), en français, de façon chaleureuse et directe, à son "
        f"message : « {text} »\n"
        "Si sa question porte sur tes capacités, mentionne : activer/désactiver une source, "
        "définir des mots-clés, apprendre son style depuis un compte, valider/corriger tes suggestions."
    )
    try:
        result = subprocess.run(
            ["python3", f"{BRO_IA_PATH}/question.py", prompt, "--temperature", "0.4", "--max-tokens", "300"],
            capture_output=True, text=True, timeout=45,
        )
        answer = result.stdout.strip()
    except Exception:
        answer = ""
    answer = answer or "🤔 Je n'ai pas bien compris — dites-moi par exemple « désactive mastodon.social »."
    _log_tool_request(owner_email, text, answer)
    return answer


def _handle_command_text(owner_email, text):
    """Parse un message reçu en self-DM. Essaie d'abord l'interprétation en
    langage naturel (conversation fluide), puis retombe sur la syntaxe
    #commande si l'IA ne reconnaît rien, puis sur une réponse conversationnelle
    générale — le canal self-DM avec BRO ne reste jamais sans réponse.
    Retourne toujours un message à renvoyer au propriétaire."""
    lowered = text.strip().lower()
    if lowered in ARBOR_TRIGGERS:
        if _is_captain(owner_email):
            return _trigger_arbor_self_improve(owner_email)
        return "🔒 L'auto-amélioration est réservée au capitaine de la station."

    action = _interpret_natural_command(owner_email, text)
    if action and action.get("action") not in (None, "none"):
        if _sanity_check_action(text, action):
            reply = _execute_interpreted_action(owner_email, action)
            if reply:
                return reply
        else:
            print(f"[BRO_WATCH] Action {action.get('action')!r} rejetée (incohérente avec le texte) : {text[:60]!r}")

    reply = _handle_hashtag_command(owner_email, text)
    if reply:
        return reply

    return _conversational_reply(owner_email, text)


def process_incoming_commands(owner_email):
    """Point d'entrée à appeler régulièrement (ex: avant chaque cycle de
    scraper) : lit les self-DM reçus depuis le dernier passage, exécute les
    commandes reconnues, répond en self-DM pour confirmer. Ignore ses propres
    messages (rapports et confirmations, voir BOT_REPLY_MARKERS) pour ne
    jamais se répondre à lui-même."""
    manifest = _load_manifest(owner_email)
    last_check = manifest.get(COMMAND_LAST_CHECK_KEY, {}).get("last_check", 0)

    import time as _time
    now_ts = int(_time.time())

    try:
        events = _fetch_self_dms_since(owner_email, last_check)
    except Exception as e:
        print(f"[BRO_WATCH] Écoute des commandes indisponible pour {owner_email} : {e}")
        return

    handled = 0
    for ev in sorted(events, key=lambda e: e.get("created_at", 0)):
        text = _decrypt_self_dm(owner_email, ev)
        if not text or text.strip().startswith(BOT_REPLY_MARKERS):
            continue  # échec de déchiffrement ou c'est un de nos propres messages
        reply = _handle_command_text(owner_email, text)
        if reply:
            handled += 1
            send_dm_to_owner(owner_email, reply, ttl_days=1)
            print(f"[BRO_WATCH] Commande traitée pour {owner_email} : {text[:60]!r}")

    manifest = _load_manifest(owner_email)
    manifest.setdefault(COMMAND_LAST_CHECK_KEY, {})["last_check"] = now_ts
    _save_manifest(owner_email, manifest)

    if handled:
        print(f"[BRO_WATCH] {handled} commande(s) traitée(s) pour {owner_email}.")


# ── CLI (pour appel depuis bash — NOSTRCARD.refresh.sh) ─────────────────

if __name__ == "__main__":
    import sys

    if len(sys.argv) >= 5 and sys.argv[1] == "store-log":
        _, _, email, account, logfile = sys.argv[:5]
        try:
            with open(logfile, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except Exception as e:
            print(f"[BRO_WATCH] Lecture log échouée : {e}")
            sys.exit(1)
        cid = store_log(email, account, text)
        print(cid or "(chiffrement/IPFS indisponible — log conservé en clair sur disque uniquement)")
        sys.exit(0 if cid else 1)

    elif len(sys.argv) >= 4 and sys.argv[1] == "is-enabled":
        _, _, email, account = sys.argv[:4]
        print("true" if is_scraper_enabled(email, account) else "false")
        sys.exit(0)

    elif len(sys.argv) >= 3 and sys.argv[1] == "check-commands":
        _, _, email = sys.argv[:3]
        process_incoming_commands(email)
        sys.exit(0)

    elif len(sys.argv) >= 4 and sys.argv[1] == "get-channels":
        # Liste de chaînes YouTube (ou équivalent) suivies, une par ligne —
        # stockées dans le manifest cookie (sous-canal "channel_watch",
        # champ watched_channels), donc sauvegardées automatiquement en
        # NOSTR comme le reste du manifest. Consommé par youtube.com.sh.
        _, _, email, account = sys.argv[:4]
        entry = get_watch_entry(email, account, "channel_watch") or {}
        for url in entry.get("watched_channels", []) or []:
            print(url)
        sys.exit(0)

    else:
        print("Usage:")
        print("  python3 bro_watch_core.py store-log EMAIL ACCOUNT LOGFILE")
        print("  python3 bro_watch_core.py is-enabled EMAIL ACCOUNT")
        print("  python3 bro_watch_core.py check-commands EMAIL")
        print("  python3 bro_watch_core.py get-channels EMAIL ACCOUNT")
        sys.exit(1)
