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
# Tout message sortant de BRO (rapports, confirmations de commande, réponses
# conversationnelles libres) commence par un de ces marqueurs — sert à les
# ignorer en écoutant les commandes entrantes, sinon un message de BRO serait
# relu comme une nouvelle question et générerait une réponse à sa propre
# réponse, indéfiniment (boucle confirmée en production : des centaines de
# messages générés en quelques minutes). 💬 = réponse conversationnelle libre
# (_conversational_reply) — initialement absent d'ici, c'est la cause de
# cette boucle : à ne JAMAIS retirer sans un mécanisme de remplacement.
BOT_REPLY_MARKERS = ("📋", "✅", "🤔", "💬", "🔔")

# ─── Pont BRO ↔ UPlanet_IA_Responder.sh ───────────────────────────────────────
# Regex pour extraire les URLs d'image depuis les messages BRO (self-DM).
# Doit matcher /uploads/xxx.jpg (UPassport local) et les URLs IPFS avec extension.
_IA_IMG_URL_RE = re.compile(
    r'https?://[^\s#"\'<>]+\.(?:jpg|jpeg|png|gif|webp)(?:[?][^\s#]*)?',
    re.IGNORECASE
)
# Tags à nettoyer du prompt avant d'appeler un générateur
_IA_CLEAN_RE = re.compile(
    r'#(?:bro|bot|image|video|vid[ée]o|music(?:ue)?|search|recherche'
    r'|plant(?:net|e)?|botanique|flora|insect(?:e)?|animal|person(?:ne)?'
    r'|objet?|place|lieu|inventory|inventaire|describe|d[ée]crire'
    r'|pierre|am[ée]lie)\b',
    re.IGNORECASE
)

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


# Tag NOSTR (pas le contenu du message) marquant tout event self-DM émis par
# BRO — signal structurel, pas de collision possible avec un texte utilisateur
# légitime (contrairement à un préfixe emoji dans le contenu, cf.
# BOT_REPLY_MARKERS : un vrai message commençant par "✅" serait alors, à tort,
# traité comme une réponse de BRO). Source de vérité pour le filtrage anti-
# boucle dans _fetch_self_dms_since ; BOT_REPLY_MARKERS reste un repli pour
# les events publiés avant ce changement ou par un chemin qui l'omettrait.
BRO_ORIGIN_TAG = ["client", "bro"]


def send_dm_to_owner(owner_email, message, ttl_days=DM_TTL_DAYS):
    """Publie un DM NOSTR chiffré 'à soi-même' : signé et adressé par la
    propre clé MULTIPASS du propriétaire (jamais la clé NODE de la station).
    Le message apparaît comme une note personnelle chiffrée dans son propre
    historique NOSTR, déchiffrable uniquement par lui. Marqué BRO_ORIGIN_TAG
    (tag NOSTR, pas le texte) pour que BRO reconnaisse ses propres envois."""
    nsec = _owner_nsec(owner_email)
    recipient_hex = _owner_hex(owner_email)
    if not nsec or not recipient_hex:
        print(f"[BRO_WATCH] DM impossible pour {owner_email} : nsec ou HEX manquant.")
        return False
    script = os.path.join(TOOLS_PATH, "nostr_send_secure_dm.py")
    # Un SEUL event signé, republié tel quel (même id) vers TOUS les relais
    # via --extra-relays — jamais une resignature par relais (qui produirait
    # des events distincts pour le même contenu, bug constaté en prod le
    # 2026-07-03 : chaque réponse affichée deux fois). Publier vers un seul
    # relais choisi arbitrairement est tout aussi cassé dans l'autre sens :
    # atomic_chat.html se connecte au relais LOCAL (ws://127.0.0.1:7777) en
    # dev mais au relais public en production — un choix fixe rate l'un des
    # deux cas (régression constatée le même jour, corrigée dans la foulée).
    cmd = ["python3", script, "--nsec-stdin", recipient_hex, message, RELAYS[0],
           "--ttl-days", str(ttl_days), "--extra-tags", json.dumps([BRO_ORIGIN_TAG])]
    if len(RELAYS) > 1:
        cmd += ["--extra-relays", ",".join(RELAYS[1:])]
    try:
        proc = subprocess.run(cmd, input=nsec + "\n", capture_output=True, text=True, timeout=20)
        return proc.returncode == 0
    except Exception as e:
        print(f"[BRO_WATCH] Erreur envoi DM à {owner_email} via {RELAYS} : {e}")
        return False


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


# ── Routage d'intention vers les tags système réels (corpus Qdrant) ────────
# Source de vérité : docs/how-to/BRO_HELP_COMMANDS.md — les tags media/vision
# (#image #video #music #plant #inventory #pierre #amelie) sont un système
# séparé déjà géré en amont par _handle_ia_responder_tags (regex déterministe
# sur le hashtag exact) ; ce corpus couvre le reste, qui n'a AUCUNE couverture
# dans le canal self-DM (bro_watch_core.py) — incident réel (2026-07-03) :
# "#reset" a répondu à côté du sujet, "#help" a halluciné une confirmation
# de reset, faute de reconnaître ces commandes.
#
# Comparer le texte à UNE SEULE phrase de description par cible (comme
# match_tool le fait pour les outils Arbor) s'est avéré insuffisant pour
# séparer des intentions proches ("météo à Lyon" vs "messages Mastodon"
# scoraient à 0.007 d'écart, cf. bro_conversation_eval — aucun seuil fixe
# n'est robuste sur un tel écart). Une collection Qdrant à PLUSIEURS exemples
# positifs par cible aggrave même le problème (le max sur K exemples élève
# aussi les faux positifs). Le score qui sépare proprement les deux groupes
# sur les données testées est la MARGE : meilleur score positif − meilleur
# score négatif, avec des négatifs génériques partagés entre toutes les
# cibles (questions méta + cas de veille déjà identifiés comme pièges).
QDRANT_INTENT_COLLECTION = "bro_intent_routing"
INTENT_MARGIN_THRESHOLD = 0.05

# Négatifs partagés — jamais liés à une cible précise, servent à repousser
# TOUTES les cibles (tags système ET outils Arbor). Alimentés par les
# incidents réels constatés en production.
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

# Tags système réels (docs/how-to/BRO_HELP_COMMANDS.md) avec quelques
# formulations positives représentatives, y compris les formulations EXACTES
# suggérées par la doc pour "help" ("help", "aide", "commandes BRO",
# "quelles sont les commandes"). "craft"/"badge" nécessitent un niveau
# d'accès (atom4love / satellite ẐEN) que ce canal ne vérifie pas encore —
# _execute_system_tag répond honnêtement plutôt que d'exécuter à tort.
SYSTEM_TAG_CORPUS = {
    "help": ["help", "aide", "commandes BRO", "quelles sont les commandes",
             "que peux-tu faire ?", "liste tes commandes"],
    "mem": ["montre-moi mes souvenirs", "qu'est-ce que tu as retenu de moi ?",
            "rappelle-moi ce qu'on s'est dit", "voir toutes mes mémoires", "#mem"],
    "reset": ["oublie tout ce qu'on s'est dit", "efface toutes mes mémoires", "#reset"],
    "rec": ["retiens que j'aime le jardinage", "mémorise ça pour plus tard", "note ça",
            "#rec", "#rec j'adore le compost et les légumes anciens"],
    "craft": ["décompose ce tutoriel en recette", "transforme ce lien en étapes", "#craft"],
    "badge": ["génère un badge pour cette compétence", "crée mon badge de compétence", "#badge"],
    "scraper": ["lance le scraper mastodon maintenant", "exécute la surveillance mastodon.social",
                "relance la synchro de mon cookie", "vérifie mes mentions tout de suite", "#scraper"],
}


def _intent_point_id(kind, target, text):
    h = hashlib.sha256(f"{kind}:{target}:{text}".encode()).hexdigest()
    return int(h[:15], 16) % (2 ** 63)


def _seed_intent_corpus():
    """Peuple (idempotent) la collection Qdrant de routage d'intention avec
    le corpus figé ci-dessus. Appelé paresseusement au premier match_intent()
    — pas de coût au chargement du module, dégradation silencieuse si
    Qdrant/Ollama indisponible."""
    from qdrant_client.models import Distance, VectorParams, PointStruct

    client = _qdrant_client()
    existing_collections = [c.name for c in client.get_collections().collections]
    if QDRANT_INTENT_COLLECTION not in existing_collections:
        client.create_collection(
            collection_name=QDRANT_INTENT_COLLECTION,
            vectors_config=VectorParams(size=QDRANT_VECTOR_SIZE, distance=Distance.COSINE),
        )

    points = []
    for target, examples in SYSTEM_TAG_CORPUS.items():
        for ex in examples:
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

# Déduplication par event ID — filet de sécurité INDÉPENDANT du timestamp
# last_check. Incident réel (2026-07-03) : chaque message traité deux fois
# malgré le flock de bro_dm_daemon.sh (qui ne protège que contre le
# chevauchement temporel, pas contre deux détections séquentielles du même
# event — ex: le même self-DM vu sur deux relais avec quelques secondes
# d'écart). Le since_ts seul est fragile : le created_at NOSTR n'a qu'une
# granularité à la seconde, donc un event dont created_at == nouveau
# last_check reste retrouvé par un fetch "since" suivant (borne inclusive).
# L'ID d'un event est stable et unique — le filtrer élimine la classe
# entière de bugs de resynchronisation/multi-relais, quelle qu'en soit la
# cause exacte.
PROCESSED_COMMAND_IDS_FILENAME = ".processed_command_ids.json"
PROCESSED_COMMAND_IDS_MAX = 500


def _load_processed_command_ids(owner_email):
    path = os.path.join(_owner_dir(owner_email), PROCESSED_COMMAND_IDS_FILENAME)
    try:
        with open(path) as f:
            return list(json.load(f))
    except Exception:
        return []


def _save_processed_command_ids(owner_email, ids):
    path = os.path.join(_owner_dir(owner_email), PROCESSED_COMMAND_IDS_FILENAME)
    try:
        with open(path, "w") as f:
            json.dump(ids[-PROCESSED_COMMAND_IDS_MAX:], f)
    except Exception:
        pass


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
            "--format-json",
        ], capture_output=True, text=True, timeout=60)
    except Exception:
        return None

    # --format-json contraint Ollama à ne produire QUE du JSON valide — parse
    # direct en priorité ; la regex ne sert plus que de repli pour un modèle
    # qui ignorerait la contrainte ou une sortie stdout parasite (log, etc.).
    try:
        return json.loads(result.stdout.strip())
    except Exception:
        pass
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

    # #oublie / #oubli → efface la mémoire des échanges self-DM (voir BRO_MEMORY_SLOT)
    if lowered in ("#oublie", "#oubli", "#forget"):
        return _forget_memory(owner_email)

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


# ── Mémoire épisodique/sémantique du canal self-DM — voir memory_manager.py ──
# Réutilise l'infra Qdrant + cycle RÊVE déjà en production (flux NOSTR.UMAP,
# slots 0-12 des sociétaires) plutôt qu'un nouveau système : slot dédié hors
# de cette plage pour ne jamais mélanger avec la mémoire "société".
BRO_MEMORY_SLOT = 13

# Calibré empiriquement (2026-07-03, nomic-embed-text) : sur un corpus de test
# à 2 souvenirs, les vrais rappels scorent ≥0.777 et les faux positifs (sujet
# différent, parfois avec un mot en commun type nom de ville) plafonnent à
# 0.679 — même écart déjà observé sur TOOL_MATCH_THRESHOLD. À recalibrer si le
# volume réel de mémoire par utilisateur change sensiblement ce comportement.
MEMORY_RECALL_THRESHOLD = 0.72


# ── Registre des outils Arbor activés — voir arbor_tool_forge.py ────────────
# État RUNTIME (pas versionné dans le dépôt, cohérent avec la convention
# ~/.zen/ = données runtime, dépôt = code). Séparé volontairement du code des
# outils eux-mêmes (IA/tools_generated/*.py, ajoutés par des branches Arbor) :
# l'activation reste une décision explicite du capitaine, jamais automatique
# à la fusion d'une branche.
ACTIVE_TOOLS_FILE = os.path.expanduser("~/.zen/flashmem/bro_active_tools.json")
TOOLS_GENERATED_DIR = os.path.join(BRO_IA_PATH, "tools_generated")


def list_active_tools():
    try:
        with open(ACTIVE_TOOLS_FILE, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _extract_tool_docstring(module_name):
    """Repli d'auto-description : premier PARAGRAPHE du docstring du module
    (jusqu'à la première ligne vide), si le capitaine n'a pas fourni de
    description explicite à l'activation. Une seule ligne tronquerait des
    phrases écrites sur plusieurs lignes (cas courant du code généré)."""
    tool_path = os.path.join(TOOLS_GENERATED_DIR, f"{module_name}.py")
    try:
        with open(tool_path, encoding="utf-8") as f:
            content = f.read()
        match = re.match(r'^\s*"""(.*?)(?:\n\n|""")', content, re.DOTALL)
        if match:
            paragraph = " ".join(line.strip() for line in match.group(1).strip().splitlines())
            return re.sub(r"\s+", " ", paragraph).strip()
    except Exception:
        pass
    return module_name


def activate_tool(module_name, description=None):
    tool_path = os.path.join(TOOLS_GENERATED_DIR, f"{module_name}.py")
    if not os.path.isfile(tool_path):
        return False, f"Fichier introuvable : {tool_path} — la branche a-t-elle été mergée ?"
    tools = list_active_tools()
    tools[module_name] = {
        "description": description or _extract_tool_docstring(module_name),
        "activated_at": _now_iso(),
    }
    os.makedirs(os.path.dirname(ACTIVE_TOOLS_FILE), exist_ok=True)
    with open(ACTIVE_TOOLS_FILE, "w", encoding="utf-8") as f:
        json.dump(tools, f, ensure_ascii=False, indent=2)
    return True, f"Outil '{module_name}' activé : {tools[module_name]['description']}"


def deactivate_tool(module_name):
    tools = list_active_tools()
    if module_name not in tools:
        return False, f"'{module_name}' n'est pas actif."
    del tools[module_name]
    with open(ACTIVE_TOOLS_FILE, "w", encoding="utf-8") as f:
        json.dump(tools, f, ensure_ascii=False, indent=2)
    return True, f"Outil '{module_name}' désactivé."


def _call_tool(module_name, query):
    """Charge et exécute un outil généré (contrat : def run(query: str) -> str).
    Échoue silencieusement (None) — l'appelant retombe alors sur la conversation
    normale plutôt que de planter le canal self-DM pour un outil défaillant."""
    tool_path = os.path.join(TOOLS_GENERATED_DIR, f"{module_name}.py")
    if not os.path.isfile(tool_path):
        return None
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(module_name, tool_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.run(query)
    except Exception as e:
        print(f"[BRO_WATCH] Appel outil '{module_name}' échoué : {e}")
        return None


# Calibré empiriquement via bro_conversation_eval.py (dans le même esprit que
# SEMANTIC_THRESHOLD) : vrais positifs à 0.64-0.70 ("météo à Lyon"), faux
# positifs à 0.58-0.62 ("il fait beau aujourd'hui", plainte météo sans
# demande) — 0.63 sépare proprement les deux sur le jeu de test actuel.
TOOL_MATCH_THRESHOLD = 0.63


# Questions méta sur les capacités de BRO — jamais routées vers un outil,
# toujours vers _conversational_reply (qui a déjà la liste réelle des outils
# dans son prompt). Trouvé en test réel : "à quels outils as-tu accès ?"
# matchait l'outil météo à 0.67 (le mot "outils" recoupe la description de
# n'importe quel outil) — séparation trop faible pour se fier au seul score
# sémantique sur ce type de question.
_META_CAPABILITY_PHRASES = (
    "que sais-tu faire", "qu'est-ce que tu sais faire", "à quels outils",
    "a quels outils", "quelles sont tes capacités", "que peux-tu faire",
    "tes fonctionnalités", "c'est quoi tes commandes", "quelles commandes",
    # Questions temporelles — ne jamais router vers un outil (ex: tool_meteo)
    "quelle heure", "il est quelle heure", "quelle heure est-il",
    "quelle heure est il", "l'heure", "donne moi l'heure", "what time",
)


def match_tool(text):
    """Détermine quel outil actif correspond sémantiquement à la requête,
    SANS l'exécuter — séparé de _try_registered_tools pour permettre de
    tester le ROUTAGE seul (déterministe, pas d'appel réseau à une API
    tierce). Retourne (module_name, score) ou None."""
    lowered = text.strip().lower()
    if any(phrase in lowered for phrase in _META_CAPABILITY_PHRASES):
        return None
    tools = list_active_tools()
    if not tools:
        return None
    try:
        text_vec = _qdrant_embed(text)
    except Exception:
        return None
    best_module, best_score = None, 0.0
    for module_name, info in tools.items():
        try:
            score = _cosine(text_vec, _qdrant_embed(info.get("description", module_name)))
        except Exception:
            continue
        if score > best_score:
            best_module, best_score = module_name, score
    if best_module and best_score >= TOOL_MATCH_THRESHOLD:
        return best_module, best_score
    return None


def _try_registered_tools(text):
    """Route vers un outil activé si sa description matche sémantiquement la
    requête. Retourne None (repli conversation normale) si aucun outil ne
    matche, ou si l'outil matché échoue à répondre."""
    match = match_tool(text)
    if not match:
        return None
    best_module, best_score = match
    result = _call_tool(best_module, text)
    if result:
        print(f"[BRO_WATCH] Requête routée vers l'outil '{best_module}' (score {best_score:.2f})")
        return result
    return None


def _bro_capabilities_description(owner_email):
    """Description ANCRÉE dans le code réel — jamais de commande/tag/outil
    inventé. Corrige un incident constaté (2026-07-03) : le prompt générique
    précédent poussait le LLM à halluciner des commandes slash inexistantes
    (/activate_source, etc.) faute de contexte réel sur ce que BRO sait
    vraiment faire."""
    lines = [
        "Tu es BRO, l'assistant IA personnel (clone numérique) du propriétaire de ce compte UPlanet.",
        "Il te parle en messages privés NOSTR chiffrés (canal self-DM).",
        "",
        "CE QUE TU SAIS RÉELLEMENT FAIRE (ne jamais inventer d'autre commande, tag ou outil) :",
        "- Langage naturel direct, pas de syntaxe spéciale requise. Exemples réels : "
        "« désactive mastodon.social », « ajoute le mot-clé X sur le fil mastodon », "
        "« apprends mon style depuis @compte », « #ok » pour valider une suggestion, "
        "« non, dis plutôt : ... » pour la corriger.",
        "- Syntaxe #hashtag de secours si le langage naturel échoue : "
        "#watch DOMAINE on|off — #watch DOMAINE CANAL keywords mot1,mot2 — "
        "#watch DOMAINE CANAL learn_from @compte — #ok — #plutôt TEXTE.",
        "- Surveillance de sources web (Mastodon, forums Discourse, chaînes YouTube).",
        "- Mémoire de vos échanges précédents (rappelée automatiquement quand pertinent) — "
        "« #oublie » pour l'effacer.",
        "- Notes explicites : « #rec TEXTE » pour mémoriser un fait précis, "
        "« #mem » pour voir vos notes, « #reset » pour les effacer (« #rec #2 » / #mem #2 / #reset #2 "
        "pour un autre slot que le slot 0 par défaut).",
        "- « #help » ou « aide » affiche cette même liste.",
        "- « lance le scraper DOMAINE » (ou « #scraper DOMAINE ») exécute immédiatement la surveillance "
        "d'une source dont vous avez déjà déposé le cookie, au lieu d'attendre le cycle quotidien.",
        "- Reconnaissance d'image : envoie une image (URL .jpg/.png/etc.) — "
        "BRO la décrit automatiquement. Tags spéciaux : "
        "#plant (botanique PlantNet), #inventory (inventaire).",
        "- Génération de contenu : #image PROMPT (image ComfyUI), "
        "#video PROMPT (vidéo), #music PROMPT (musique).",
    ]
    if _is_captain(owner_email):
        lines.append("- #arbor : lance l'auto-amélioration du prompt d'interprétation (réservé capitaine).")

    tools = list_active_tools()
    if tools:
        lines.append("")
        lines.append("OUTILS SUPPLÉMENTAIRES DISPONIBLES (pose directement ta question, utilisés automatiquement) :")
        for info in tools.values():
            lines.append(f"- {info.get('description', '?')}")

    lines.append("")
    lines.append("Si on te demande ce que tu sais faire, réponds à partir de CETTE liste uniquement. "
                 "Si une capacité n'y figure pas, dis clairement que tu ne l'as pas plutôt que d'improviser.")
    return "\n".join(lines)


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


def _extract_image_url(text):
    """Extrait la première URL d'image avec extension depuis un message BRO."""
    m = _IA_IMG_URL_RE.search(text)
    return m.group(0) if m else None


def _describe_image_url(image_url):
    """Appelle describe_image.py via le venv ~/.astro/.
    Retourne la description textuelle ou '' si Ollama indisponible."""
    script = os.path.join(BRO_IA_PATH, "describe_image.py")
    if not os.path.isfile(script):
        return ""
    venv_py = os.path.expanduser("~/.astro/bin/python3")
    py = venv_py if os.path.isfile(venv_py) else "python3"
    try:
        result = subprocess.run(
            [py, script, image_url, "--json"],
            capture_output=True, text=True, timeout=90,
        )
        data = json.loads(result.stdout.strip())
        return data.get("description", "")
    except Exception:
        return ""


def _call_generator(script_name, prompt):
    """Appelle generators/<script_name> avec le prompt.
    Retourne l'URL produite (stdout) ou None si ComfyUI indisponible."""
    script = os.path.join(BRO_IA_PATH, "generators", script_name)
    if not os.path.isfile(script):
        return None
    try:
        result = subprocess.run(
            ["bash", script, prompt],
            capture_output=True, text=True, timeout=300,
        )
        url = result.stdout.strip()
        return url if url.startswith("http") else None
    except Exception:
        return None


def _handle_ia_responder_tags(owner_email, text, img_url=None):
    """Pont BRO ↔ UPlanet_IA_Responder.sh : reconnaît les #tags media/vision
    dans le canal self-DM et délègue aux générateurs/reconnaisseurs Python/bash.
    Retourne la réponse ou None (→ repli conversationnel gérant img_url en contexte)."""
    lowered = text.lower()
    clean = _IA_CLEAN_RE.sub("", text).strip()

    # ── Génération d'image (ComfyUI) ──────────────────────────────────────
    if re.search(r'#image\b', lowered):
        url = _call_generator("generate_image.sh", clean or "abstract artwork")
        if url:
            return f"🖼️ Image générée :\n{url}"
        return "⚠️ Génération d'image indisponible (ComfyUI non accessible — demandez à la constellation)."

    # ── Génération de vidéo ────────────────────────────────────────────────
    if re.search(r'#vid[ée]o\b', lowered):
        url = _call_generator("generate_video.sh", clean or "abstract motion")
        if url:
            return f"🎬 Vidéo générée :\n{url}"
        return "⚠️ Génération vidéo indisponible (ComfyUI non accessible)."

    # ── Génération de musique ──────────────────────────────────────────────
    if re.search(r'#music(?:ue)?\b', lowered):
        url = _call_generator("generate_music.sh", clean or "ambient music")
        if url:
            return f"🎵 Musique générée :\n{url}"
        return "⚠️ Génération musicale indisponible sur cette station."

    # ── Reconnaissance botanique (PlantNet) ────────────────────────────────
    if re.search(r'#(?:plant(?:net|e)?|botanique|flora)\b', lowered):
        if not img_url:
            return "🌿 Envoie une photo de plante avec #plant pour l'identification botanique."
        script = os.path.join(BRO_IA_PATH, "plantnet_recognition.py")
        if not os.path.isfile(script):
            return "⚠️ PlantNet non installé sur cette station."
        venv_py = os.path.expanduser("~/.astro/bin/python3")
        py = venv_py if os.path.isfile(venv_py) else "python3"
        try:
            result = subprocess.run([py, script, img_url], capture_output=True, text=True, timeout=60)
            out = result.stdout.strip()
            return out or "⚠️ PlantNet n'a pas identifié de plante sur cette image."
        except Exception:
            return "⚠️ Service PlantNet indisponible."

    # ── Inventaire automatique ─────────────────────────────────────────────
    if re.search(r'#(?:inventory|inventaire)\b', lowered):
        if not img_url:
            return "📦 Envoie une photo avec #inventory pour l'inventaire automatique."
        script = os.path.join(BRO_IA_PATH, "inventory_recognition.py")
        if not os.path.isfile(script):
            return "⚠️ Inventaire non disponible sur cette station."
        venv_py = os.path.expanduser("~/.astro/bin/python3")
        py = venv_py if os.path.isfile(venv_py) else "python3"
        try:
            result = subprocess.run([py, script, img_url], capture_output=True, text=True, timeout=60)
            out = result.stdout.strip()
            return out or "⚠️ Inventaire vide ou non reconnu."
        except Exception:
            return "⚠️ Service inventaire indisponible."

    # ── Synthèse vocale (#pierre / #amelie) ───────────────────────────────
    if re.search(r'#(?:pierre|am[ée]lie)\b', lowered):
        voice = "amelie" if re.search(r'#am[ée]lie\b', lowered) else "pierre"
        # Texte épuré de tous les tags commandes pour la question et pour le TTS
        clean_question = re.sub(
            r'#(?:bro|bot|pierre|am[ée]lie)\b', '', text, flags=re.IGNORECASE
        ).strip()
        if clean_question:
            text_reply = _conversational_reply(owner_email, clean_question, img_url)
            text_for_tts = re.sub(r'^[💬📋✅🤔🔔]\s*', '', text_reply).strip()
        else:
            text_for_tts = "BRO à votre service."
            text_reply = f"💬 {text_for_tts}"
        speech_script = os.path.join(BRO_IA_PATH, "generators", "generate_speech.sh")
        audio_url = ""
        if os.path.isfile(speech_script):
            try:
                result = subprocess.run(
                    ["bash", speech_script, text_for_tts, voice],
                    capture_output=True, text=True, timeout=120,
                )
                audio_url = result.stdout.strip()
            except Exception as exc:
                print(f"[BRO_WATCH] TTS échoué ({voice}) : {exc}")
        if audio_url:
            return f"{text_reply}\n\n🔊 Audio ({voice}) : {audio_url}"
        return text_reply

    # Pas de tag spécifique → repli vers _conversational_reply (avec img_url en contexte)
    return None


def _slots_from_text(text):
    """Détecte les tags #1..#12 dans le texte (cohérent avec bro_dm_daemon.sh
    et UPlanet_IA_Responder.sh) — retourne la liste des slots visés, ou [0]
    (personnel) par défaut si aucun n'est mentionné."""
    slots = [i for i in range(1, 13) if re.search(rf"#{i}\b", text)]
    return slots or [0]


def _generic_slot_file(owner_email, slot):
    return os.path.expanduser(f"~/.zen/flashmem/{owner_email}/slot{slot}.json")


def _persist_slot_content(owner_email, slot, content):
    """#rec — mémorise EXPLICITEMENT une note dans le slot demandé (0-12,
    système documenté dans BRO_HELP_COMMANDS.md), distinct du rappel
    automatique de conversation (BRO_MEMORY_SLOT). Même mécanique que
    _remember_exchange : fichier local (lu par question.py --slot) + Qdrant
    (memory_manager.py, pour la recherche sémantique)."""
    try:
        from datetime import datetime
        ts = datetime.utcnow().isoformat() + "Z"
        slot_file = _generic_slot_file(owner_email, slot)
        os.makedirs(os.path.dirname(slot_file), exist_ok=True)
        if os.path.isfile(slot_file):
            with open(slot_file, encoding="utf-8") as f:
                slot_mem = json.load(f)
        else:
            slot_mem = {"user_id": owner_email, "slot": slot, "messages": []}
        slot_mem["messages"].append({"timestamp": ts, "content": content})
        slot_mem["messages"] = slot_mem["messages"][-200:]
        with open(slot_file, "w", encoding="utf-8") as f:
            json.dump(slot_mem, f, indent=2, ensure_ascii=False)

        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.upsert_user_slot(owner_email, slot, content, timestamp=ts)
        if len(slot_mem["messages"]) >= 170:
            mm.reve_compress_slot(owner_email, slot, slot_file=slot_file)
        return True
    except Exception as e:
        print(f"[BRO_WATCH] #rec indisponible pour {owner_email} slot {slot} : {e}")
        return False


def _format_slot_summary(owner_email, slot, limit=5):
    slot_file = _generic_slot_file(owner_email, slot)
    try:
        with open(slot_file, encoding="utf-8") as f:
            messages = json.load(f).get("messages", [])
    except Exception:
        return None
    if not messages:
        return None
    lines = [f"- {m.get('content', '')}" for m in messages[-limit:]]
    return "\n".join(lines)


def _clear_slot(owner_email, slot):
    slot_file = _generic_slot_file(owner_email, slot)
    try:
        if os.path.isfile(slot_file):
            os.remove(slot_file)
    except Exception:
        pass
    try:
        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.delete_user_slot(owner_email, slot)
    except Exception:
        pass


# Détection déterministe du tag explicite — prioritaire sur le routage
# sémantique (match_intent). Nécessaire pour #rec : le contenu variable après
# le tag ("#rec j'adore le compost" vs "#rec je pars en vacances le 12
# juillet") pollue l'embedding de la phrase entière et fait rater le match
# sémantique, alors que le tag lui-même est un marqueur non ambigu — pas
# besoin d'IA pour le reconnaître (même logique que _handle_hashtag_command
# et _handle_ia_responder_tags, tags déterministes ailleurs dans ce fichier).
_SYSTEM_TAG_RE = re.compile(r"#(mem|reset|rec|help|craft|badge|scraper)\b", re.IGNORECASE)


def _detect_system_tag(text):
    m = _SYSTEM_TAG_RE.search(text)
    return m.group(1).lower() if m else None


SCRAPER_RUN_TIMEOUT_SEC = 180


def _cookie_file_path(owner_email, domain):
    return os.path.join(_owner_dir(owner_email), f".{domain}.cookie")


def _find_scraper_script(domain):
    """Même résolution que NOSTRCARD.refresh.sh : IA/scrapers/*/DOMAIN.sh en
    priorité, repli sur IA/DOMAIN.sh (legacy)."""
    scrapers_dir = os.path.join(BRO_IA_PATH, "scrapers")
    try:
        for sub in sorted(os.listdir(scrapers_dir)):
            candidate = os.path.join(scrapers_dir, sub, f"{domain}.sh")
            if os.path.isfile(candidate):
                return candidate
    except Exception:
        pass
    legacy = os.path.join(BRO_IA_PATH, f"{domain}.sh")
    return legacy if os.path.isfile(legacy) else None


def _available_scraper_domains(owner_email):
    """Domaines pour lesquels le propriétaire a déposé un cookie ET dont le
    fichier cookie en clair existe encore localement (condition réelle
    d'exécution, pas seulement la présence dans le manifest)."""
    manifest = _load_manifest(owner_email)
    return [d for d in manifest if os.path.isfile(_cookie_file_path(owner_email, d))]


def _extract_scraper_domain(owner_email, text):
    """Cherche lequel des domaines déjà déposés (cookie réel présent) est
    mentionné dans le texte — match sur le domaine complet ou son premier
    label (ex: 'mastodon' matche 'mastodon.social')."""
    lowered = text.lower()
    for domain in _available_scraper_domains(owner_email):
        if domain.lower() in lowered or domain.split(".")[0].lower() in lowered:
            return domain
    return None


def _run_scraper_now(owner_email, domain):
    """Exécute un scraper à la demande du capitaine (hors cycle cron
    quotidien — ignore volontairement le fichier .done journalier, une
    demande explicite doit toujours s'exécuter) et renvoie un résumé
    exploitable directement en réponse DM, plutôt que de faire attendre le
    prochain passage de NOSTRCARD.refresh.sh."""
    if not is_scraper_enabled(owner_email, domain):
        return f"🔒 Le scraper {domain} est désactivé (voir /mailjet pour le réactiver)."
    cookie_file = _cookie_file_path(owner_email, domain)
    if not os.path.isfile(cookie_file):
        return f"🍪 Aucun cookie déposé pour {domain} — déposez-en un sur /cookie."
    script = _find_scraper_script(domain)
    if not script:
        return f"⚠️ Aucun scraper disponible pour {domain} sur cette station."

    log_path = os.path.expanduser(f"~/.zen/tmp/{domain}_sync_{owner_email}.log")
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    try:
        result = subprocess.run(
            ["bash", script, owner_email, cookie_file],
            capture_output=True, text=True, timeout=SCRAPER_RUN_TIMEOUT_SEC,
        )
        output = (result.stdout or "") + (result.stderr or "")
    except subprocess.TimeoutExpired:
        return f"⏱️ Le scraper {domain} n'a pas terminé sous {SCRAPER_RUN_TIMEOUT_SEC}s — réessayez plus tard."
    except Exception as e:
        return f"⚠️ Échec du lancement du scraper {domain} : {e}"

    try:
        with open(log_path, "w", encoding="utf-8") as f:
            f.write(output)
        store_log(owner_email, domain, output)
    except Exception:
        pass

    # Dernière ligne informative du log (les scrapers impriment un résumé
    # type "Terminé — N nouvelle(s) mention(s)…") plutôt que tout le log brut.
    summary_lines = [l for l in output.strip().splitlines() if l.strip()]
    summary = summary_lines[-1] if summary_lines else "(aucune sortie)"
    if result.returncode == 0:
        return f"✅ Scraper {domain} exécuté :\n{summary}"
    return f"⚠️ Scraper {domain} terminé avec une erreur (code {result.returncode}) :\n{summary}"


def _execute_system_tag(target, owner_email, text):
    """Exécute une commande système reconnue par match_intent (voir
    SYSTEM_TAG_CORPUS) — jamais de réponse LLM inventée pour ces cas,
    contrairement à l'incident du 2026-07-03. Retourne None si la cible
    n'a pas (encore) d'implémentation réelle sur ce canal, pour repli
    honnête côté appelant plutôt qu'une exécution hasardeuse."""
    if target == "help":
        lines = _bro_capabilities_description(owner_email).split("\n")
        lines.append("")
        lines.append("Voir aussi : #mem (souvenirs), #reset (les effacer), #rec <texte> (en noter un).")
        return "\n".join(lines)

    if target == "mem":
        slots = _slots_from_text(text)
        parts = []
        for slot in slots:
            summary = _format_slot_summary(owner_email, slot)
            parts.append(f"Slot {slot} :\n{summary}" if summary else f"Slot {slot} : (vide)")
        return "🧠 " + "\n\n".join(parts)

    if target == "reset":
        slots = _slots_from_text(text)
        for slot in slots:
            _clear_slot(owner_email, slot)
        slots_str = ", ".join(str(s) for s in slots)
        return f"🗑️ Mémoire effacée (slot{'s' if len(slots) > 1 else ''} {slots_str})."

    if target == "rec":
        slots = _slots_from_text(text)
        # Texte à mémoriser : le message débarrassé des tags #rec/#N eux-mêmes.
        content = re.sub(r"#rec\b", "", text, flags=re.IGNORECASE)
        content = re.sub(r"#\d{1,2}\b", "", content).strip()
        if not content:
            return "🤔 Dites-moi quoi mémoriser, par exemple « #rec j'aime le jardinage »."
        ok = all(_persist_slot_content(owner_email, slot, content) for slot in slots)
        slots_str = ", ".join(str(s) for s in slots)
        return f"✅ Noté dans le slot{'s' if len(slots) > 1 else ''} {slots_str}." if ok else \
            "⚠️ Échec de la mémorisation (Qdrant indisponible ?)."

    if target == "scraper":
        domain = _extract_scraper_domain(owner_email, text)
        if domain:
            return _run_scraper_now(owner_email, domain)
        available = _available_scraper_domains(owner_email)
        if not available:
            return "🍪 Aucun cookie déposé pour l'instant — déposez-en un sur /cookie pour activer un scraper."
        return "🤔 Quel domaine ? " + ", ".join(available)

    if target in ("craft", "badge"):
        return (f"🔒 #{target} nécessite un profil/niveau d'accès non encore vérifiable sur ce canal self-DM — "
                "utilisez ce tag en DM classique adressé à BRO (#BRO) plutôt qu'en self-DM.")

    return None


def _conversational_reply(owner_email, text, img_url=None):
    """Réponse en langage naturel quand le message ne correspond à aucune
    commande de surveillance reconnue — pour que le canal self-DM avec BRO
    reste vivant même hors commande (BRO reste son clone numérique, jamais
    silencieux sans raison). Chaque repli ici est aussi un signal de "besoin
    non couvert" — journalisé pour l'analyse Arbor continue multi-utilisateurs."""
    context_summary = _watch_context_summary(owner_email)
    memory_context = _recall_relevant_memories(owner_email, text)
    memory_block = f"Souvenirs pertinents de vos échanges précédents :\n{memory_context}\n\n" if memory_context else ""

    # Si une URL image est présente, décrire l'image et l'injecter dans le prompt
    img_desc = _describe_image_url(img_url) if img_url else ""
    image_block = f"[Image reçue — description visuelle IA] : {img_desc}\n\n" if img_desc else ""

    prompt = (
        f"{_bro_capabilities_description(owner_email)}\n\n"
        f"Sources actuellement configurées :\n{context_summary or '(aucune pour le moment)'}\n\n"
        f"{memory_block}"
        f"{image_block}"
        "Réponds brièvement (3-5 lignes max), en français, de façon chaleureuse et directe, à son "
        f"message : « {text} »"
    )
    try:
        result = subprocess.run(
            ["python3", f"{BRO_IA_PATH}/question.py", prompt,
             "--temperature", "0.4", "--max-tokens", "300", "--ctx", "8192"],
            capture_output=True, text=True, timeout=45,
        )
        answer = result.stdout.strip()
    except Exception:
        answer = ""
    answer = answer or "Je n'ai pas bien compris — dites-moi par exemple « désactive mastodon.social »."
    # Marqueur BOT_REPLY_MARKERS obligatoire (voir sa définition) : sans lui,
    # cette réponse serait relue comme un nouveau message au prochain cycle.
    if not answer.startswith(BOT_REPLY_MARKERS):
        answer = f"💬 {answer}"
    _log_tool_request(owner_email, text, answer)
    _remember_exchange(owner_email, text, answer)
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

    # Extraire l'URL image une seule fois (partagée entre les handlers)
    img_url = _extract_image_url(text)

    # Tags media/vision de UPlanet_IA_Responder.sh (#image, #video, #music, #plant…)
    ia_reply = _handle_ia_responder_tags(owner_email, text, img_url)
    if ia_reply:
        if not ia_reply.startswith(BOT_REPLY_MARKERS):
            ia_reply = f"💬 {ia_reply}"
        _log_tool_request(owner_email, text, ia_reply)
        _remember_exchange(owner_email, text, ia_reply)
        return ia_reply

    # Tags système de docs/how-to/BRO_HELP_COMMANDS.md (#mem, #reset, #rec,
    # #help, #craft, #badge) — hashtag exact détecté en déterministe, langage
    # naturel équivalent reconnu via corpus Qdrant (match_intent). Jamais de
    # réponse LLM inventée pour ces cas (incident du 2026-07-03).
    explicit_tag = _detect_system_tag(text)
    intent_target = explicit_tag or (match_intent(text) or (None,))[0]
    if intent_target:
        sys_reply = _execute_system_tag(intent_target, owner_email, text)
        if sys_reply:
            if not sys_reply.startswith(BOT_REPLY_MARKERS):
                sys_reply = f"💬 {sys_reply}"
            _log_tool_request(owner_email, text, sys_reply)
            _remember_exchange(owner_email, text, sys_reply)
            return sys_reply

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

    tool_result = _try_registered_tools(text)
    if tool_result:
        if not tool_result.startswith(BOT_REPLY_MARKERS):
            tool_result = f"💬 {tool_result}"
        return tool_result

    return _conversational_reply(owner_email, text, img_url)


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

    processed_ids = _load_processed_command_ids(owner_email)
    processed_set = set(processed_ids)
    new_ids = []

    handled = 0
    for ev in sorted(events, key=lambda e: e.get("created_at", 0)):
        # Filtre anti-boucle PRIMAIRE : tag structurel BRO_ORIGIN_TAG sur
        # l'event brut, avant tout déchiffrement — ne dépend pas du contenu,
        # ne peut pas confondre un vrai message utilisateur avec une réponse
        # de BRO (contrairement à un préfixe emoji, cf. incident du 2026-07-03
        # où des centaines de réponses ont été générées en boucle).
        if list(BRO_ORIGIN_TAG) in ev.get("tags", []):
            continue
        ev_id = ev.get("id")
        if ev_id and ev_id in processed_set:
            continue  # déjà traité — voir PROCESSED_COMMAND_IDS_* ci-dessus
        try:
            text = _decrypt_self_dm(owner_email, ev)
            if not text or text.strip().startswith(BOT_REPLY_MARKERS):
                continue  # échec de déchiffrement, ou repli pour events sans le tag (legacy)
            # Marqué "vu" avant l'exécution : même si _handle_command_text
            # échoue ensuite, cette commande précise ne doit plus jamais être
            # rejouée — sinon une commande qui a RÉUSSI une première fois
            # (détectée en double via un autre relais/canal quelques
            # secondes plus tard) serait exécutée deux fois.
            if ev_id:
                processed_set.add(ev_id)
                new_ids.append(ev_id)
            reply = _handle_command_text(owner_email, text)
            if reply:
                handled += 1
                if send_dm_to_owner(owner_email, reply, ttl_days=1):
                    print(f"[BRO_WATCH] Commande traitée pour {owner_email} : {text[:60]!r}")
                else:
                    print(f"[BRO_WATCH] ⚠️ Envoi de la réponse échoué pour {owner_email} "
                          f"(commande : {text[:60]!r}) — la commande reste marquée traitée.")
        except Exception as e:
            # Une commande qui plante (ex: description d'image indisponible)
            # ne doit JAMAIS empêcher la mise à jour de last_check ci-dessous
            # ni le traitement des autres commandes du lot — sinon le même
            # message est re-fetché et re-traité en boucle à chaque cycle
            # (incident réel du 2026-07-03 : "salut que puis-je te demander ?"
            # traité 3 fois en 2 minutes après l'échec d'une autre commande).
            print(f"[BRO_WATCH] Commande en erreur pour {owner_email} ({ev.get('id', '?')[:12]}…) : {e}")

    if new_ids:
        _save_processed_command_ids(owner_email, processed_ids + new_ids)

    manifest = _load_manifest(owner_email)
    manifest.setdefault(COMMAND_LAST_CHECK_KEY, {})["last_check"] = now_ts
    _save_manifest(owner_email, manifest)

    if handled:
        print(f"[BRO_WATCH] {handled} commande(s) traitée(s) pour {owner_email}.")

    check_proactive_alerts(owner_email)


# ── Agentivité proactive : BRO initie la conversation sans sollicitation ──
# préalable quand un détecteur d'anomalie se déclenche (ex: solde bas).
# Chaque type d'alerte est rate-limité indépendamment pour ne jamais spammer
# le propriétaire pour la même anomalie persistante (1x/PROACTIVE_ALERT_COOLDOWN_SEC).

PROACTIVE_ALERTS_FILENAME = ".proactive_alerts.json"
PROACTIVE_ALERT_COOLDOWN_SEC = 86400  # 1 alerte max par jour et par type
LOW_G1_BALANCE_THRESHOLD_CENTIMES = 100  # 1 G1 = 10 Ẑen (mode ORIGIN) ou 1€ (mode ZEN)


def _load_proactive_alert_state(owner_email):
    path = os.path.join(_owner_dir(owner_email), PROACTIVE_ALERTS_FILENAME)
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}


def _save_proactive_alert_state(owner_email, state):
    path = os.path.join(_owner_dir(owner_email), PROACTIVE_ALERTS_FILENAME)
    try:
        with open(path, "w") as f:
            json.dump(state, f)
    except Exception:
        pass


def _check_low_g1_balance(owner_email):
    """Détecteur : solde Ğ1 transférable sous LOW_G1_BALANCE_THRESHOLD_CENTIMES.
    Retourne un message d'alerte, ou None si le solde est correct ou la
    requête RPC/squid indisponible (dégradation gracieuse — jamais d'alerte
    sur une donnée non fiable)."""
    g1_pubkey = _owner_g1_pubkey(owner_email)
    if not g1_pubkey:
        return None
    script = os.path.join(TOOLS_PATH, "G1wallet_v2.sh")
    try:
        result = subprocess.run(
            ["bash", script, "balance", g1_pubkey, "--json"],
            capture_output=True, text=True, timeout=20,
        )
    except Exception:
        return None
    match = re.search(r"\{.*\}", result.stdout, re.DOTALL)
    if not match:
        return None
    try:
        data = json.loads(match.group(0))
    except Exception:
        return None
    if not data.get("rpc_ok"):
        return None  # source non fiable — ne jamais alerter sur une donnée douteuse
    transferable = data.get("rpc_transferable", 0)
    if transferable < LOW_G1_BALANCE_THRESHOLD_CENTIMES:
        return (f"Votre solde Ğ1 est bas : {transferable / 100:.2f} G1 restants "
                f"({transferable / 10:.1f} Ẑen). Pensez à réapprovisionner votre compte.")
    return None


# Détecteurs actifs — chacun : owner_email -> message d'alerte | None.
# Ajouter un nouveau détecteur = ajouter une entrée ici, rien d'autre à câbler.
PROACTIVE_ALERT_DETECTORS = {
    "low_g1_balance": _check_low_g1_balance,
}


def check_proactive_alerts(owner_email):
    """Point d'entrée agentivité proactive — appelé à chaque passage de
    process_incoming_commands (temps réel + cycle quotidien). BRO initie la
    conversation sans attendre d'être sollicité si un détecteur se déclenche.
    Retourne la liste des types d'alerte effectivement envoyés."""
    import time as _time
    now = int(_time.time())
    state = _load_proactive_alert_state(owner_email)
    fired = []

    for alert_type, detector in PROACTIVE_ALERT_DETECTORS.items():
        last_sent = state.get(alert_type, 0)
        if now - last_sent < PROACTIVE_ALERT_COOLDOWN_SEC:
            continue
        try:
            message = detector(owner_email)
        except Exception as e:
            print(f"[BRO_WATCH] Détecteur proactif '{alert_type}' a échoué pour {owner_email} : {e}")
            continue
        if message:
            if send_dm_to_owner(owner_email, f"🔔 {message}", ttl_days=3):
                state[alert_type] = now
                fired.append(alert_type)
                print(f"[BRO_WATCH] Alerte proactive '{alert_type}' envoyée à {owner_email}")

    if fired:
        _save_proactive_alert_state(owner_email, state)
    return fired


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

    elif len(sys.argv) >= 3 and sys.argv[1] == "activate-tool":
        # Étape manuelle du capitaine après avoir mergé une branche Arbor
        # (arbor_tool_forge.py) : le fichier IA/tools_generated/MODULE.py
        # doit déjà exister sur master. Description optionnelle — sinon
        # reprise depuis le docstring du module.
        module_name = sys.argv[2]
        description = " ".join(sys.argv[3:]) if len(sys.argv) > 3 else None
        ok_, msg = activate_tool(module_name, description)
        print(msg)
        sys.exit(0 if ok_ else 1)

    elif len(sys.argv) >= 3 and sys.argv[1] == "deactivate-tool":
        ok_, msg = deactivate_tool(sys.argv[2])
        print(msg)
        sys.exit(0 if ok_ else 1)

    elif len(sys.argv) >= 2 and sys.argv[1] == "list-tools":
        tools = list_active_tools()
        if not tools:
            print("Aucun outil actif.")
        for name, info in tools.items():
            print(f"{name}: {info.get('description', '?')} (activé {info.get('activated_at', '?')})")
        sys.exit(0)

    else:
        print("Usage:")
        print("  python3 bro_watch_core.py store-log EMAIL ACCOUNT LOGFILE")
        print("  python3 bro_watch_core.py is-enabled EMAIL ACCOUNT")
        print("  python3 bro_watch_core.py check-commands EMAIL")
        print("  python3 bro_watch_core.py get-channels EMAIL ACCOUNT")
        print("  python3 bro_watch_core.py activate-tool MODULE [DESCRIPTION]")
        print("  python3 bro_watch_core.py deactivate-tool MODULE")
        print("  python3 bro_watch_core.py list-tools")
        sys.exit(1)
