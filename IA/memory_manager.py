#!/usr/bin/env python3
"""
memory_manager.py — Gestionnaire unifié de mémoire Qdrant pour UPlanet/Astroport

Architecture des collections :
  uplanet_geo       — publications géolocalisées appréciées (1/3/12 likes = UMAP/SECTOR/REGION), index de NOSTR
  memory_{hex16}    — mémoires personnelles par slot (per-MULTIPASS) — MUSE/LOVE
                       (#love_rec) y a son propre slot (LOVE_MEMORY_SLOT=15,
                       cf. bro/rag.py BRO_MEMORY_SLOT=13/BRO_PERSONA_SLOT=14) :
                       une seule mémoire par utilisateur, jamais d'identité
                       parallèle — un souvenir de rencontre reste privé (jamais
                       publié sur NOSTR) et n'est retrouvable qu'en filtrant ce
                       slot, mais partage le même espace de stockage que le reste.
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
  python3 memory_manager.py upsert-slot  --user-id email --slot 0 --content "..."
  python3 memory_manager.py upsert-love  --user-id email --content "..."
  python3 memory_manager.py search-love  --user-id email --query "café le matin"
  python3 memory_manager.py resonance-love --user-a email1 --user-b email2
  python3 memory_manager.py upsert-skill --skill devops --content "..." --npub hex
  python3 memory_manager.py reve         --user-id email --slot 0
  python3 memory_manager.py delete-slot  --user-id email --slot 0
  python3 memory_manager.py count-slot   --user-id email --slot 0
  python3 memory_manager.py slot-counts  --user-id email --slots 0 13 14 15
  python3 memory_manager.py search-geo   --lat 43.6 --lon 1.4 --query "marché bio"
  python3 memory_manager.py skill-hash   --skill devops
  python3 memory_manager.py backup       --output /tmp/qdrant_backup.json
"""

import os, sys, hashlib, json
import urllib.request
import urllib.error
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import observability

# ── Venv ~/.astro ──────────────────────────────────────────────────────────────
_venv = os.path.expanduser("~/.astro")
if os.path.exists(_venv):
    _pyv = f"python{sys.version_info.major}.{sys.version_info.minor}"
    _sp  = os.path.join(_venv, "lib", _pyv, "site-packages")
    if os.path.exists(_sp):
        sys.path.insert(0, _sp)

def _load_qdrant_api_key() -> str:
    """Env var en priorité, sinon ~/.zen/ai-company/.env (même repli que
    bro_watch_core.py::_qdrant_client — Qdrant refuse toute requête sans clé
    dès que la stack IA a été installée avec authentification)."""
    key = os.environ.get("QDRANT_API_KEY", "")
    if key:
        return key
    env_file = os.path.expanduser("~/.zen/ai-company/.env")
    try:
        with open(env_file) as f:
            for line in f:
                if line.startswith("QDRANT_API_KEY="):
                    return line.strip().split("=", 1)[1]
    except Exception:
        pass
    return ""


# ── Configuration (overridable via env) ──────────────────────────────────────
QDRANT_URL     = os.environ.get("QDRANT_URL",     "http://127.0.0.1:6333")
QDRANT_API_KEY = _load_qdrant_api_key()
OLLAMA_URL     = os.environ.get("OLLAMA_URL",     "http://127.0.0.1:11434")
OLLAMA_MODEL   = os.environ.get("OLLAMA_MODEL",       "llama3.2")

# ── Embeddings : config UNIQUE de la plateforme (embed_config.py, bge-m3 — mesures documentées là) ──────
# MEMORY_EMBED_* / MEMORY_*_THRESHOLD restent acceptés (surcharge propre à la mémoire).
import embed_config as _ec
EMBED_MODEL    = os.environ.get("MEMORY_EMBED_MODEL", _ec.MODEL)
VECTOR_SIZE    = int(os.environ.get("MEMORY_EMBED_DIM", _ec.DIM))
RECALL_THRESHOLD = float(os.environ.get("MEMORY_RECALL_THRESHOLD", _ec.threshold("recall")))
LOVE_RESONANCE_THRESHOLD = float(os.environ.get("MEMORY_LOVE_THRESHOLD", RECALL_THRESHOLD + 0.05))
SCHEMA_VERSION = 2

# Seuil de compression : ~2-3 mois d'activité quotidienne avant premier RÊVE
# Après RÊVE : [1 résumé] + [80 récents] = 81 → prochain RÊVE à 150 de nouveau
REVE_THRESHOLD = 150
REVE_KEEP      = 80

FLASHMEM_BASE  = os.path.expanduser("~/.zen/flashmem")
SKILLS_DIR     = os.path.join(FLASHMEM_BASE, "skills")


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


def _season(timestamp: str) -> str:
    """Saison (hémisphère nord, français) dérivée du mois ISO — permet de
    filtrer les mémoires par saison (ex: distinguer une habitude hivernale
    d'une habitude estivale) sans recalcul a posteriori sur le timestamp brut,
    qui n'était jusqu'ici jamais exploité comme filtre de recherche."""
    try:
        month = int(timestamp[5:7])
    except (ValueError, TypeError, IndexError):
        return ""
    if month in (12, 1, 2):
        return "hiver"
    if month in (3, 4, 5):
        return "printemps"
    if month in (6, 7, 8):
        return "ete"
    return "automne"


def _auth_headers() -> dict:
    if QDRANT_API_KEY:
        return {"api-key": QDRANT_API_KEY}
    return {}


def _curl(method: str, url: str, payload: dict = None, quiet: tuple = ()) -> dict:
    """Appel HTTP via urllib.request (stdlib) — plus de subprocess curl
    (2026-07-06) : évitait la dépendance qdrant_client, mais forker/exec un
    binaire externe à chaque appel (Qdrant ET Ollama, potentiellement
    plusieurs fois par message) est plus lourd et moins fiable qu'un appel
    HTTP natif Python (gestion des timeouts/erreurs sans parsing de code
    retour + stderr). Même pattern que admin/ia_db/codebase_index.py.

    Échec BRUYANT sur stderr (toute panne — Qdrant down, Ollama down, auth
    invalide, timeout — remonte jusqu'à upsert_geo/upsert_user_slot puis
    l'appelant avec un détail exploitable dans les logs, jamais avalée
    en silence)."""
    headers = {"Content-Type": "application/json"}
    headers.update(_auth_headers())
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method.upper())
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read()
            return json.loads(body) if body.strip() else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")[:200]
        if e.code not in quiet:       # `quiet` : un code ATTENDU (404 = « la collection n'existe pas encore »), pas une panne
            print(f"[memory_manager] ⚠️ Échec {method} {url} (HTTP {e.code}) : {detail or '(pas de corps)'}",
                  file=sys.stderr)
        return {}
    except urllib.error.URLError as e:
        print(f"[memory_manager] ⚠️ Échec {method} {url} : {e.reason}", file=sys.stderr)
        return {}
    except Exception as e:
        print(f"[memory_manager] ⚠️ Échec {method} {url} : {e}", file=sys.stderr)
        return {}


def _gpu_ensure(model: str):
    """La 3090 est partagée avec ComfyUI : lève GpuBusy (RuntimeError) s'il n'y a pas la place de charger `model`.
    Voie rapide : modèle déjà chargé = un GET de quelques ms."""
    import gpu_headroom
    gpu_headroom.ensure(model)


def _embed(text: str) -> list:
    """Vecteur de `text` (/api/embed, l'ancien /api/embeddings est déprécié).
    bge-m3 n'exige aucun préfixe de tâche. Vecteur de mauvaise dimension → [] +
    erreur bruyante : jamais d'upsert qui corromprait silencieusement une collection."""
    try:
        _gpu_ensure(EMBED_MODEL)
    except RuntimeError as e:
        print(f"[memory_manager] ⛔ embedding refusé : {e}", file=sys.stderr)
        return []
    import ollama_metrics
    _t0 = ollama_metrics.start()
    r = _curl("POST", f"{OLLAMA_URL}/api/embed", {"model": EMBED_MODEL, "input": text})
    ollama_metrics.record("embed", EMBED_MODEL, _t0, resp=r, ok=bool(r.get("embeddings")), n_inputs=1)
    vecs = r.get("embeddings") or []
    vec = vecs[0] if vecs else r.get("embedding", [])
    if vec and len(vec) != VECTOR_SIZE:
        print(f"[memory_manager] ❌ {EMBED_MODEL} renvoie {len(vec)} dimensions, "
              f"{VECTOR_SIZE} attendues (MEMORY_EMBED_DIM) — vecteur refusé.", file=sys.stderr)
        return []
    return vec


# ── Contenus qui ne doivent JAMAIS entrer dans la mémoire sémantique ─────────
# Une mémoire est relue dans le prompt du LLM (et envoyée à un fournisseur tiers
# si l'utilisateur a configuré sa propre clé Anthropic/Gemini). Constaté le
# 2026-10-19 : des STORY_KEY_BACKUP (clé AES en clair) y avaient été stockés,
# parce que tout self-DM était mémorisé tel quel.
import re as _re
_UNSTORABLE_PREFIXES = ("STORY_KEY_BACKUP:",)
_UNSTORABLE_PATTERNS = (
    (_re.compile(r'"key_hex"\s*:'),                        "clé de chiffrement (key_hex)"),
    (_re.compile(r'nsec1[0-9a-z]{20,}'),                   "clé privée NOSTR (nsec)"),
    (_re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),   "clé privée PEM"),
    (_re.compile(r'(?i)\b(?:mot de passe|mdp|password|passphrase|secret|token|api[_ -]?key|code (?:pin|secret|d.acc[eè]s)|pin)\b'
                 r'(?:\s+[\w\'’-]+){0,4}?\s*(?:est|is|c.est|:|=)\s*\S{4,}'),          "secret déclaré (mot de passe, token…)"),
    (_re.compile(r'\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){3,7}(?:[ ]?[A-Z0-9]{1,4})?\b'), "IBAN"),
    (_re.compile(r'\b(?:\d[ -]?){15}\d\b'),                "numéro de carte bancaire"),
    (_re.compile(r'\b[12][ ]?\d{2}[ ]?(?:0[1-9]|1[0-2])[ ]?\d{2}[ ]?\d{3}[ ]?\d{3}(?:[ ]?\d{2})?\b'), "numéro de sécurité sociale"),
    (_re.compile(r'\b(?:sk|pk|ghp|xox[bp])[-_][A-Za-z0-9_-]{16,}'), "clé d'API"),
)


def unstorable_reason(content: str) -> str:
    """Raison pour laquelle `content` est refusé en mémoire ('' = stockable)."""
    head = (content or "").lstrip()
    for p in _UNSTORABLE_PREFIXES:
        if head.startswith(p):
            return f"message machine « {p} »"
    for rx, why in _UNSTORABLE_PATTERNS:
        if rx.search(content or ""):
            return why
    return ""


def _qdrant_available() -> bool:
    """Qdrant répond ET accepte notre clé. (Pas /healthz : il répond du texte brut, pas du JSON — _curl le prenait
    toujours pour une panne.)"""
    return "result" in _curl("GET", f"{QDRANT_URL}/collections")


# ──────────────────────────── collections ─────────────────────────────────────

def ensure_collection(name: str, size: int = VECTOR_SIZE):
    """Crée la collection si elle n'existe pas (idempotent).

    Vérifie d'abord son existence (GET) plutôt que de foncer sur un PUT à
    chaque appel : Qdrant répond HTTP 409 sur un PUT "create" d'une collection
    déjà là, que _curl logue bruyamment sur stderr par design (jamais avaler
    une vraie panne en silence) — dans le cas ultra-majoritaire (collection
    déjà créée depuis longtemps), ce 409 n'est qu'un faux positif qui pollue
    les logs à CHAQUE upsert/search, sans jamais rien signaler d'utile."""
    existing = _curl("GET", f"{QDRANT_URL}/collections/{name}", quiet=(404,))
    if existing.get("result"):
        # Garde-fou dimension : deux modèles de même taille se mélangeraient sans erreur ;
        # une taille différente fait échouer Qdrant à chaque upsert avec un message obscur.
        have = (existing["result"].get("config", {}).get("params", {})
                .get("vectors", {}) or {}).get("size")
        if have and have != size:
            raise RuntimeError(
                f"collection {name} : vecteurs de {have} dimensions, {size} attendues "
                f"({EMBED_MODEL}) — migrer avec memory_migrate_v2.py, ne rien mélanger.")
        return
    _curl("PUT", f"{QDRANT_URL}/collections/{name}",
          {"vectors": {"size": size, "distance": "Cosine"}})


def ensure_all_collections(user_ids: list = None):
    """Initialise les collections permanentes + celles des utilisateurs listés."""
    for name in ("uplanet_geo", "station_skills"):
        ensure_collection(name)
    if user_ids:
        for uid in user_ids:
            ensure_collection(f"memory_{_user_hex(uid)}")


# ──────────────────────────── mémoire géolocalisée (UMAP) ─────────────────────
# `uplanet_geo` = INDEX de recherche des publications géolocalisées APPRÉCIÉES, reconstruit depuis NOSTR (la source de
# vérité : les évènements et leurs réactions, qui voyagent entre stations) — jamais depuis un fichier local. Chaque station
# indexe ce que son relais connaît : aucune base globale, des espaces relatifs à chaque relais / station (stockage p2p).
# Le NIVEAU d'une publication suit ses likes (mêmes seuils que NOSTR.UMAP.refresh.sh) :
#   ≥ 1 like → UMAP (case 0,01°) · ≥ 3 → SECTOR (0,1°) · ≥ 12 → REGION (1°)
# Alimenté par geo_memory.py (rafraîchissement de 20h12). Lecture : search_geo(lat, lon, question).
GEO_COLLECTION = "uplanet_geo"
GEO_LIKES = (("region", 12), ("sector", 3), ("umap", 1))        # du plus haut au plus bas


def geo_level(likes: int):
    """Niveau atteint par `likes` approbations (None si aucune)."""
    for level, need in GEO_LIKES:
        if likes >= need:
            return level
    return None


def geo_keys(lat: float, lon: float) -> dict:
    """Clés de case contenant (lat, lon), coin sud-ouest comme les UMAP : UMAP 0,01°, SECTOR 0,1°, REGION 1°."""
    import math
    cell = lambda v, step: math.floor(round(v / step, 6)) * step
    return {"umap": f"{cell(lat, 0.01):.2f}_{cell(lon, 0.01):.2f}",
            "sector": f"{cell(lat, 0.1):.1f}_{cell(lon, 0.1):.1f}",
            "region": f"{int(math.floor(lat))}_{int(math.floor(lon))}"}


def upsert_geo_event(event: dict, lat: float, lon: float, likes: int) -> bool:
    """Indexe (ou met à jour) UNE publication géolocalisée. Identifiant = celui de l'évènement NOSTR : relire la même
    publication met son nombre de likes et son niveau à jour, sans doublon. Refuse (et le dit) un contenu secret."""
    content = (event.get("content") or "").strip()
    level = geo_level(likes)
    if not content or level is None:
        return False
    why = unstorable_reason(content)
    if why:
        print(f"[memory_manager] 🚫 publication {event.get('id', '')[:12]} non indexée : {why}", file=sys.stderr)
        return False
    vec = _embed(content[:3000])
    if not vec:
        return False
    ensure_collection(GEO_COLLECTION)
    ts = datetime.utcfromtimestamp(int(event.get("created_at", 0))).isoformat() + "Z"
    payload = {"event_id": event["id"], "pubkey": event.get("pubkey", ""), "kind": event.get("kind", 1),
               "content": content[:3000], "latitude": lat, "longitude": lon, **{f"{k}_key": v for k, v in geo_keys(lat, lon).items()},
               "level": level, "likes": likes, "created_at": int(event.get("created_at", 0)), "timestamp": ts,
               "season": _season(ts), "importance": likes, "embed_model": EMBED_MODEL, "schema": SCHEMA_VERSION, "source": "nostr"}
    r = _curl("PUT", f"{QDRANT_URL}/collections/{GEO_COLLECTION}/points",
              {"points": [{"id": int(event["id"][:15], 16), "vector": vec, "payload": payload}]})
    return bool(r)


def delete_geo_events(event_ids: list) -> bool:
    ids = [int(e[:15], 16) for e in event_ids]
    return _delete_points(GEO_COLLECTION, ids) if ids else True


def geo_indexed(since_ts: int = 0) -> list:
    """Publications déjà indexées depuis `since_ts` : [{id, event_id, likes, level, created_at}] (pour recompter leurs likes)."""
    out, offset = [], None
    while True:
        body = {"limit": 500, "with_payload": ["event_id", "likes", "level", "created_at"], "with_vector": False,
                "filter": {"must": [{"key": "created_at", "range": {"gte": since_ts}}]}}
        if offset:
            body["offset"] = offset
        r = _curl("POST", f"{QDRANT_URL}/collections/{GEO_COLLECTION}/points/scroll", body, quiet=(404,)).get("result", {})   # 404 = index pas encore créé : normal
        out += [dict(p.get("payload", {}), id=p["id"]) for p in r.get("points", [])]
        offset = r.get("next_page_offset")
        if not offset:
            return out


def search_geo(lat, lon, query: str, limit: int = 5, season: str = None) -> list:
    """Publications appréciées PERTINENTES pour la position (lat, lon) : celles de MA case UMAP (≥ 1 like), celles de mon
    SECTOR qui ont atteint ≥ 3 likes, celles de ma REGION qui ont atteint ≥ 12 likes — le niveau d'une publication est le
    périmètre sur lequel elle compte. Classées par sens (score ≥ RECALL_THRESHOLD)."""
    try:
        k = geo_keys(float(lat), float(lon))
    except (TypeError, ValueError):
        return []
    vec = _embed(query)
    if not vec:
        return []
    ensure_collection(GEO_COLLECTION)
    flt = {"should": [
        {"must": [{"key": "umap_key", "match": {"value": k["umap"]}}]},
        {"must": [{"key": "sector_key", "match": {"value": k["sector"]}}, {"key": "level", "match": {"any": ["sector", "region"]}}]},
        {"must": [{"key": "region_key", "match": {"value": k["region"]}}, {"key": "level", "match": {"value": "region"}}]},
    ]}
    if season:
        flt["must"] = [{"key": "season", "match": {"value": season}}]
    r = _curl("POST", f"{QDRANT_URL}/collections/{GEO_COLLECTION}/points/search",
              {"vector": vec, "limit": limit, "score_threshold": RECALL_THRESHOLD, "with_payload": True, "filter": flt})
    return r.get("result", [])


# ──────────────────────────── user slot memory ────────────────────────────────

# ── Schéma v2 : UNE mémoire par MULTIPASS, des champs plutôt que des tiroirs ──
#   kind        fact (« allergique aux noix ») · episode (« a vu X mardi ») ·
#               trait (style, opinions, centres d'intérêt) · person (un proche)
#   source      chat · rec · mastodon · nostr_public · nostr_dm · photo · agenda · contact · reve
#   visibility  private (défaut) · love (cité à une rencontre — décision de l'utilisateur) · public
#   confidence  0..1 (1 = dit explicitement par la personne)
#   status      active · superseded (remplacé par un fait plus récent) · deleted
# Les numéros de slot restent acceptés par tous les appelants historiques : ils sont
# traduits ici (SLOT_SCHEMA) et conservés dans le payload (`slot`) pour compatibilité.
SLOT_SCHEMA = {
    0:  {"kind": "fact",    "source": "rec",  "visibility": "private"},  # #rec
    13: {"kind": "episode", "source": "chat", "visibility": "private"},  # échanges avec BRO
    14: {"kind": "trait",   "source": "chat", "visibility": "private"},  # persona / style
    15: {"kind": "episode", "source": "nostr_dm", "visibility": "love"},  # LOVE (messagerie privée)
}
_NOT_ACTIVE = [{"key": "status", "match": {"any": ["superseded", "deleted"]}}]


def _slot_must(slot: int) -> list:
    """Conditions Qdrant équivalentes à l'ancien « slot N » (les souvenirs v2 n'ont plus de
    champ `slot`) : 0 = #rec · 13 = échanges (source chat) · 14 = traits · 15 = LOVE."""
    return {0:  [{"key": "source",     "match": {"value": "rec"}}],
            13: [{"key": "source",     "match": {"value": "chat"}}],
            14: [{"key": "kind",       "match": {"value": "trait"}}],
            15: [{"key": "visibility", "match": {"value": "love"}}]
            }.get(slot, [{"key": "slot", "match": {"value": slot}}])


def _content_hash(content: str) -> str:
    return hashlib.sha256(" ".join(content.split()).lower().encode()).hexdigest()[:16]


def is_pinned(payload: dict) -> bool:
    """Souvenir ÉCRIT ou CORRIGÉ par la personne (écran Mon compte, #rec) : une extraction automatique ne le
    remplace ni ne le supprime — sa parole l'emporte sur ce que BRO a cru comprendre."""
    return (payload.get("origin") == "user" or bool(payload.get("edited"))
            or payload.get("source") in ("manual", "rec"))


def upsert_memory(user_id: str, content: str, kind: str = "fact", source: str = "chat",
                  visibility: str = "private", confidence: float = 1.0,
                  slot: int = None, timestamp: str = None, event_id: str = "",
                  importance: int = 1, extra: dict = None, auto: bool = False) -> bool:
    """Écrit UN souvenir (schéma v2). Idempotent : l'identifiant dérive de
    (utilisateur, contenu normalisé) — réécrire le même souvenir (ex. relire les
    mêmes posts Mastodon) met à jour le point au lieu d'en ajouter un doublon.
    Refuse (et le dit sur stderr) tout contenu secret, cf. unstorable_reason.

    `auto=True` : écriture par l'APPRENTISSAGE automatique (jamais un geste de la personne). Elle respecte alors
    les choix déjà faits : un souvenir que la personne a OUBLIÉ n'est pas ressuscité, un souvenir qu'elle a écrit
    ou corrigé n'est pas écrasé, la visibilité qu'elle a choisie est conservée. Seul le canal « chat » (ce que la
    personne dit elle-même à BRO, maintenant) peut revenir sur un oubli ; les sources passives (publications relues,
    agenda, contacts…) ne le peuvent pas."""
    if not content or not content.strip():
        return False
    why = unstorable_reason(content)
    if why:
        print(f"[memory_manager] 🚫 souvenir refusé pour {user_id} : {why}", file=sys.stderr)
        return False
    vec = _embed(content)
    if not vec:
        return False
    cname = f"memory_{_user_hex(user_id)}"
    ts    = timestamp or datetime.utcnow().isoformat() + "Z"
    chash = _content_hash(content)
    payload = {
        "user_id": user_id, "content": content, "timestamp": ts,
        "event_id": event_id, "season": _season(ts), "importance": importance,
        "kind": kind, "source": source, "visibility": visibility,
        "confidence": confidence, "status": "active",
        "embed_model": EMBED_MODEL, "schema": SCHEMA_VERSION, "content_hash": chash,
        "origin": "auto" if auto else "user",
    }
    if slot is not None:
        payload["slot"] = slot
    if extra:
        payload.update(extra)
    ensure_collection(cname)
    pid = _stable_id(user_id, chash)
    if auto:
        prev = get_memory(user_id, pid).get("payload") or {}
        if prev.get("status") == "deleted" and prev.get("deleted_by") == "user" and source != "chat":
            print(f"[memory_manager] ⛔ « {content[:60]} » : oublié par la personne, non réécrit", file=sys.stderr)
            return False
        if prev.get("status", "active") == "active" and prev:
            if is_pinned(prev):
                return True                      # déjà là, écrit/corrigé par la personne : intact
            payload["visibility"] = prev.get("visibility", payload["visibility"])   # son choix (ex. 💞) survit à la relecture
    r = _curl("PUT", f"{QDRANT_URL}/collections/{cname}/points", {
        "points": [{"id": pid, "vector": vec, "payload": payload}]
    })
    return bool(r)


def upsert_user_slot(user_id: str, slot: int, content: str,
                     timestamp: str = None, event_id: str = "",
                     importance: int = 1, source: str = None) -> bool:
    """Compatibilité : écrit un souvenir identifié par son ancien numéro de slot
    (0 = #rec, 13 = échanges, 14 = persona, 15 = LOVE), traduit en schéma v2.
    importance : nombre de messages condensés pour un résumé RÊVE."""
    sch = SLOT_SCHEMA.get(slot, {"kind": "fact", "source": "chat", "visibility": "private"})
    return upsert_memory(user_id, content, kind=sch["kind"], source=source or sch["source"],
                         visibility=sch["visibility"], slot=slot, timestamp=timestamp,
                         event_id=event_id, importance=importance)


def _delete_points(collection: str, ids: list) -> bool:
    """Supprime des points Qdrant par ID exact (pas par filtre) — utilisé pour
    purger les vecteurs individuels remplacés par un résumé RÊVE. Best-effort :
    un échec laisse simplement des points orphelins (état déjà tolérable
    aujourd'hui), jamais bloquant pour l'appelant."""
    if not ids:
        return True
    r = _curl("POST", f"{QDRANT_URL}/collections/{collection}/points/delete", {
        "points": ids
    })
    return bool(r)


def delete_user_slot(user_id: str, slot: int) -> bool:
    """Supprime tous les points Qdrant d'un slot donné (les autres slots du
    même utilisateur, dans la même collection memory_{hex}, ne sont pas
    affectés — filtrage strict par le champ payload 'slot')."""
    cname = f"memory_{_user_hex(user_id)}"
    r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/delete", {
        "filter": {"must": _slot_must(slot)}
    })
    return bool(r)


def search_user_slot(user_id: str, query: str, slots: list = None,
                     limit: int = 5, score_threshold: float = None,
                     season: str = None, kinds: list = None,
                     visibility: str = None) -> list:
    """Recherche sémantique dans la mémoire d'un utilisateur (souvenirs actifs
    seulement). Filtrable par saison, par type (`kinds`) ou par visibilité ; `slots`
    reste accepté pour les appelants historiques. score_threshold par défaut =
    RECALL_THRESHOLD du modèle d'embedding (l'ancien 0,3 laissait tout passer)."""
    if score_threshold is None:
        score_threshold = RECALL_THRESHOLD
    vec = _embed(query)
    if not vec:
        return []
    cname = f"memory_{_user_hex(user_id)}"
    ensure_collection(cname)       # compte neuf : pas de 404 bruyant, et contrôle de dimension
    body: dict = {"vector": vec, "limit": limit, "score_threshold": score_threshold,
                  "with_payload": True}
    filters = []
    if slots:
        filters.append({"key": "slot", "match": {"any": slots}})
    if season:
        filters.append({"key": "season", "match": {"value": season}})
    if kinds:
        filters.append({"key": "kind", "match": {"any": kinds}})
    if visibility:
        filters.append({"key": "visibility", "match": {"value": visibility}})
    flt: dict = {"must_not": _NOT_ACTIVE}
    if filters:
        flt["must"] = filters
    body["filter"] = flt
    r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/search", body)
    return _age_rank(r.get("result", []))


EPISODE_DECAY = float(os.environ.get("MEMORY_EPISODE_DECAY", "0.08"))   # malus de score atteint à 1 an


def _age_rank(hits: list, now: datetime = None) -> list:
    """Un ÉVÈNEMENT vieillit, un fait ou un goût non : le score d'un épisode (hors photos, datées par nature et
    cherchées pour leur date) perd jusqu'à EPISODE_DECAY au bout d'un an. Ce n'est qu'un CLASSEMENT — aucun souvenir
    n'est exclu pour son âge, il passe simplement après un fait aussi pertinent."""
    now = now or datetime.utcnow()
    for h in hits:
        pl = h.get("payload", {})
        if pl.get("kind") != "episode" or pl.get("source") == "photo":
            continue
        try:
            age = (now - datetime.fromisoformat(pl.get("timestamp", "").rstrip("Z"))).days
        except ValueError:
            continue
        h["score"] = h.get("score", 0) - EPISODE_DECAY * max(0.0, min(1.0, age / 365))
    return sorted(hits, key=lambda h: h.get("score", 0), reverse=True)


def list_memories(user_id: str, kinds: list = None, source: str = None,
                  include_inactive: bool = False, limit: int = 1000) -> list:
    """Tous les souvenirs d'un utilisateur, récents d'abord — alimente l'écran
    « Ce que BRO sait de moi ». Les vecteurs ne sont jamais renvoyés."""
    cname = f"memory_{_user_hex(user_id)}"
    ensure_collection(cname)
    must = []
    if kinds:
        must.append({"key": "kind", "match": {"any": kinds}})
    if source:
        must.append({"key": "source", "match": {"value": source}})
    flt: dict = {}
    if must:
        flt["must"] = must
    if not include_inactive:
        flt["must_not"] = _NOT_ACTIVE
    points: list = []
    offset = None
    while len(points) < limit:
        body: dict = {"limit": 250, "with_payload": True, "with_vector": False}
        if flt:
            body["filter"] = flt
        if offset:
            body["offset"] = offset
        r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/scroll", body)
        res = r.get("result", {})
        points.extend(res.get("points", []))
        offset = res.get("next_page_offset")
        if not offset:
            break
    points.sort(key=lambda p: p.get("payload", {}).get("timestamp", ""), reverse=True)
    return points[:limit]


def set_memory_fields(user_id: str, point_ids: list, fields: dict) -> bool:
    """Modifie des champs de souvenirs précis (visibility, status, confidence…) —
    c'est ce qu'utilise l'utilisateur pour passer un souvenir en « love » ou
    « privé strict », ou le marquer supprimé."""
    if not point_ids:
        return True
    cname = f"memory_{_user_hex(user_id)}"
    r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/payload",
              {"payload": fields, "points": point_ids})
    return bool(r)


def memory_overview(user_id: str) -> dict:
    """Compteurs des souvenirs ACTIFS : total + par type, source, visibilité. Un seul
    passage de scroll sans vecteurs (volume modeste par construction)."""
    out = {"total": 0, "by_kind": {}, "by_source": {}, "by_visibility": {}}
    for p in list_memories(user_id, limit=100000):
        pl = p.get("payload", {})
        out["total"] += 1
        for field, key in (("kind", "by_kind"), ("source", "by_source"), ("visibility", "by_visibility")):
            v = pl.get(field) or "?"
            out[key][v] = out[key].get(v, 0) + 1
    return out


def get_memory(user_id: str, point_id: int) -> dict:
    cname = f"memory_{_user_hex(user_id)}"
    r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points",
              {"ids": [point_id], "with_payload": True, "with_vector": False})
    res = r.get("result") or []
    return res[0] if isinstance(res, list) and res else {}


def update_memory(user_id: str, point_id: int, content: str = None, kind: str = None,
                  visibility: str = None) -> int:
    """Corrige un souvenir. Le texte change ⇒ l'identifiant (dérivé du contenu) et le vecteur
    aussi : on réécrit un nouveau point (confidence=1, « corrigé par l'utilisateur ») puis on
    supprime l'ancien. Sinon simple mise à jour de champs. Retourne l'id courant, 0 si échec."""
    cur = get_memory(user_id, point_id)
    if not cur:
        return 0
    pl = cur.get("payload", {})
    if content is not None and " ".join(content.split()) != " ".join(pl.get("content", "").split()):
        ok = upsert_memory(user_id, content, kind=kind or pl.get("kind", "fact"),
                           source=pl.get("source", "chat"),
                           visibility=visibility or pl.get("visibility", "private"),
                           confidence=1.0, timestamp=pl.get("timestamp"),
                           extra={"edited": True})
        if not ok:
            return 0
        new_id = _stable_id(user_id, _content_hash(content))
        if new_id != point_id:
            _delete_points(f"memory_{_user_hex(user_id)}", [point_id])
        return new_id
    fields = {k: v for k, v in (("kind", kind), ("visibility", visibility)) if v}
    if fields:
        fields["confidence"] = 1.0
        if not set_memory_fields(user_id, [point_id], fields):
            return 0
    return point_id


def delete_where(user_id: str, must: list) -> bool:
    """Supprime tous les souvenirs d'un utilisateur qui satisfont les conditions Qdrant `must`."""
    cname = f"memory_{_user_hex(user_id)}"
    return bool(_curl("POST", f"{QDRANT_URL}/collections/{cname}/points/delete",
                      {"filter": {"must": must}}))


def delete_by_source(user_id: str, source: str) -> bool:
    """#oublie : efface ce que BRO a appris d'UNE source (ex. « chat »)."""
    return delete_where(user_id, [{"key": "source", "match": {"value": source}}])


def delete_all_memories(user_id: str) -> bool:
    """#reset : efface TOUTE la mémoire du compte (collection recréée vide, même dimension)."""
    cname = f"memory_{_user_hex(user_id)}"
    _curl("DELETE", f"{QDRANT_URL}/collections/{cname}")
    try:
        ensure_collection(cname)
    except Exception as e:
        print(f"[memory_manager] ⚠️ recréation de {cname} : {e}", file=sys.stderr)
        return False
    return True


def delete_memory(user_id: str, point_ids: list) -> bool:
    """« Oublier » des souvenirs précis (droit à l'oubli). Le TEXTE est effacé pour de bon ; il reste une pierre
    tombale (vecteur + empreinte, sans contenu) pour que l'apprentissage automatique ne ré-extrait pas, quelques jours
    plus tard, ce que la personne vient de faire oublier — sans elle, la suppression ne tenait que jusqu'au message suivant."""
    return forget_points(user_id, point_ids)


def forget_points(user_id: str, point_ids: list) -> bool:
    if not point_ids:
        return True
    return set_memory_fields(user_id, point_ids, {
        "status": "deleted", "deleted_by": "user", "content": "",
        "deleted_at": datetime.utcnow().isoformat() + "Z"})


TOMBSTONE_MIN = float(os.environ.get("MEMORY_TOMBSTONE_MIN", "0.85"))   # même sens, reformulé


def forgotten_match(user_id: str, text: str, threshold: float = None) -> dict:
    """Pierre tombale proche de `text` (la personne a fait oublier ce SUJET), sinon {}."""
    vec = _embed(text)
    if not vec:
        return {}
    cname = f"memory_{_user_hex(user_id)}"
    ensure_collection(cname)
    r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/search", {
        "vector": vec, "limit": 1, "with_payload": False,
        "score_threshold": TOMBSTONE_MIN if threshold is None else threshold,
        "filter": {"must": [{"key": "status", "match": {"value": "deleted"}},
                            {"key": "deleted_by", "match": {"value": "user"}}]}})
    res = r.get("result") or []
    return res[0] if res else {}


def recent_user_slot(user_id: str, slot: int = 0, limit: int = 5) -> list:
    """Retourne les `limit` entrées les plus récentes d'un slot, triées par
    timestamp décroissant — pour "voici ce que tu m'as dit récemment" (#mem),
    par opposition à search_user_slot qui cherche par pertinence sémantique à
    une question. Volume modeste par construction (RÊVE compresse au-delà de
    REVE_THRESHOLD), le tri client-side après un scroll complet reste cher."""
    cname = f"memory_{_user_hex(user_id)}"
    points: list = []
    offset = None
    while True:
        body: dict = {"limit": 250, "with_payload": True, "with_vector": False,
                      "filter": {"must": _slot_must(slot), "must_not": _NOT_ACTIVE}}
        if offset:
            body["offset"] = offset
        r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/scroll", body)
        result = r.get("result", {})
        points.extend(result.get("points", []))
        offset = result.get("next_page_offset")
        if not offset:
            break
    points.sort(key=lambda p: p.get("payload", {}).get("timestamp", ""), reverse=True)
    return points[:limit]


def count_user_slot(user_id: str, slot: int) -> int:
    """Nombre de points Qdrant d'un slot — pas de recherche sémantique
    nécessaire (contrairement à search_user_slot), utilisé pour l'affichage
    admin/self-service de l'état des mémoires (UPassport services/memory_status.py)."""
    cname = f"memory_{_user_hex(user_id)}"
    r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/count", {
        "filter": {"must": _slot_must(slot), "must_not": _NOT_ACTIVE},
        "exact": True,
    })
    return int(r.get("result", {}).get("count", 0))


def slot_counts(user_id: str, slots: list) -> dict:
    """Compte les points Qdrant de plusieurs slots en un seul appel pratique
    (clés en chaînes pour rester directement sérialisable en JSON)."""
    return {str(s): count_user_slot(user_id, s) for s in slots}


# ──────────────────────────── love memory (MUSE) ───────────────────────────────
# Mémoire du canal "love" de BRO (alias MUSE, facilitation de rencontres) —
# FUSIONNÉE avec la mémoire personnelle unifiée (memory_{hex16}, LifeOS) :
# aucune collection séparée, aucune identité parallèle. Un souvenir de
# rencontre (#love_rec) est un souvenir personnel comme un autre, simplement
# rangé dans son propre slot pour rester filtrable et jamais mélangé
# accidentellement à la mémoire "classique" (#rec) dans une recherche.
LOVE_MEMORY_SLOT = 15  # registre des slots réservés : cf. bro/rag.py BRO_MEMORY_SLOT=13, BRO_PERSONA_SLOT=14

def upsert_love_mem(user_id: str, content: str,
                    timestamp: str = None, event_id: str = "") -> bool:
    """Upsert un souvenir LOVE (préférence mémorisée via #love_rec) — slot
    dédié de la mémoire personnelle unifiée memory_{hex16}."""
    return upsert_user_slot(user_id, LOVE_MEMORY_SLOT, content,
                            timestamp=timestamp, event_id=event_id)


def search_love_mem(user_id: str, query: str, limit: int = 5,
                    score_threshold: float = None) -> list:
    """Recherche sémantique dans les souvenirs LOVE d'un utilisateur (visibility=love)
    — utilisé pour bâtir un contexte pertinent (et non plus seulement récent) à
    chaque question posée à MUSE."""
    return search_user_slot(user_id, query, visibility="love",
                            limit=limit, score_threshold=score_threshold)


def delete_love_mem(user_id: str) -> bool:
    """Supprime tous les souvenirs du slot LOVE (miroir de #love_reset) — les
    autres slots (mémoire classique, persona...) du même utilisateur ne sont
    pas affectés."""
    return delete_user_slot(user_id, LOVE_MEMORY_SLOT)


def love_resonance(user_id_a: str, user_id_b: str,
                   sample: int = 15, score_threshold: float = None,
                   top_k: int = 3) -> list:
    """Associations poétiques entre deux utilisateurs LOVE : cherche, pour un
    échantillon de souvenirs LOVE de A, le souvenir LOVE de B le plus proche
    sémantiquement (ex: 'aime l'odeur du café' ↔ 'lit des poèmes de Rimbaud'
    au petit matin). Retourne jusqu'à top_k paires {content_a, content_b,
    score}, triées par score décroissant — alimente le matching (_handle_love_match)
    et la génération d'intros (_handle_love_intro). Filtre explicitement sur
    LOVE_MEMORY_SLOT des deux côtés : memory_{hex16} contient aussi d'autres
    slots (mémoire classique, persona...) qui ne doivent jamais entrer dans
    cette comparaison.

    Espaces RELATIFS à chaque clé : la synchro N² ne constitue aucune base globale. Cette comparaison ne
    lit donc que les mémoires de DEUX comptes hébergés sur CETTE station ; un candidat distant n'est
    jamais comparé par ses souvenirs (sa mémoire reste chez lui), seulement par ses tags publics
    (search_dream_matches)."""
    if score_threshold is None:
        score_threshold = LOVE_RESONANCE_THRESHOLD
    cname_a = f"memory_{_user_hex(user_id_a)}"
    cname_b = f"memory_{_user_hex(user_id_b)}"
    # Seuls les souvenirs que leur auteur a marqués « love » (jamais le privé) et encore actifs.
    slot_filter = {"must": [{"key": "visibility", "match": {"value": "love"}}],
                   "must_not": _NOT_ACTIVE}
    scrolled = _curl("POST", f"{QDRANT_URL}/collections/{cname_a}/points/scroll", {
        "limit": 250, "with_payload": True, "with_vector": True,
        "filter": slot_filter,
    })
    points = scrolled.get("result", {}).get("points", [])
    if not points:
        return []
    # Les plus récents, pas « les 15 premiers renvoyés par le scroll » (ordre arbitraire).
    points.sort(key=lambda p: p.get("payload", {}).get("timestamp", ""), reverse=True)
    points = points[:sample]

    pairs = []
    for pt in points:
        vec = pt.get("vector")
        content_a = pt.get("payload", {}).get("content", "")
        if not vec or not content_a:
            continue
        r = _curl("POST", f"{QDRANT_URL}/collections/{cname_b}/points/search", {
            "vector": vec, "limit": 1, "score_threshold": score_threshold,
            "with_payload": True, "filter": slot_filter,
        })
        hits = r.get("result", [])
        if hits:
            pairs.append({
                "content_a": content_a,
                "content_b": hits[0].get("payload", {}).get("content", ""),
                "score": hits[0].get("score", 0),
            })

    pairs.sort(key=lambda p: -p["score"])
    return pairs[:top_k]


# ──────────────────────────── love dream matching (kNN) ────────────────────────
# Collection PARTAGÉE (contrairement à memory_{hex}) : un point par pubkey LOVE
# de la constellation. Remplace la boucle Python O(N) (phi2x.compute_dream_divergence
# appelé par candidat distant, cf. love_handler.sh::_handle_love_match) par une
# recherche kNN native Qdrant. Vecteur BINAIRE par tag (pas un embedding
# sémantique nomic-embed-text comme le reste du fichier) : chaque dream_tag
# active une dimension stable (hash(tag) % taille), donc la similarité cosinus
# entre deux profils reflète l'overlap EXACT des tags — même famille de
# résultats que l'ancienne divergence de Jaccard (compute_dream_divergence),
# pas une proximité sémantique. Aucun appel Ollama ici : construction du
# vecteur = simple hash, gratuite et déterministe.
LOVE_DREAM_COLLECTION  = "love_dream_vectors"
LOVE_DREAM_VECTOR_SIZE = 768  # indépendant de VECTOR_SIZE (pas un embedding)


def _tag_vector(tags: list, size: int = LOVE_DREAM_VECTOR_SIZE) -> list:
    """Vecteur binaire creux : une dimension par tag (hash MD5 stable), 0 ailleurs."""
    vec = [0.0] * size
    for tag in (tags or []):
        idx = int(hashlib.md5(str(tag).encode()).hexdigest(), 16) % size
        vec[idx] = 1.0
    return vec


def upsert_dream_vectors_bulk(entries: list) -> int:
    """Upsert en UN SEUL appel HTTP les vecteurs binaires de plusieurs pubkeys.
    entries: [{"pubkey": hex, "dream_tags": [...], "email": ""}, ...] (email
    optionnel, utile seulement pour du debug/affichage). Ignore les entrées
    sans dream_tags. Retourne le nombre de points effectivement upsertés."""
    points = []
    for e in entries or []:
        pubkey = e.get("pubkey", "")
        tags = e.get("dream_tags") or []
        if not pubkey or not tags:
            continue
        points.append({
            "id": _stable_id(pubkey),
            "vector": _tag_vector(tags),
            "payload": {
                "pubkey": pubkey, "dream_tags": tags,
                "email": e.get("email", ""),
                "timestamp": datetime.utcnow().isoformat() + "Z",
            },
        })
    if not points:
        return 0
    ensure_collection(LOVE_DREAM_COLLECTION, size=LOVE_DREAM_VECTOR_SIZE)
    r = _curl("PUT", f"{QDRANT_URL}/collections/{LOVE_DREAM_COLLECTION}/points",
              {"points": points})
    return len(points) if r else 0


def search_dream_matches(dream_tags: list, exclude_pubkey: str = "",
                         limit: int = 20, score_threshold: float = 0.1) -> list:
    """kNN natif Qdrant sur l'overlap des dream_tags. Retourne
    [{pubkey, dream_tags, score}, ...] triés par score décroissant — score =
    similarité cosinus des vecteurs binaires (coefficient d'Ochiai : proche de
    Jaccard mais pas identique, même famille de résultats)."""
    if not dream_tags:
        return []
    vec = _tag_vector(dream_tags)
    ensure_collection(LOVE_DREAM_COLLECTION, size=LOVE_DREAM_VECTOR_SIZE)
    body = {"vector": vec, "limit": limit, "score_threshold": score_threshold,
            "with_payload": True}
    if exclude_pubkey:
        body["filter"] = {"must_not": [{"key": "pubkey", "match": {"value": exclude_pubkey}}]}
    r = _curl("POST", f"{QDRANT_URL}/collections/{LOVE_DREAM_COLLECTION}/points/search", body)
    return [{"pubkey": h.get("payload", {}).get("pubkey", ""),
             "dream_tags": h.get("payload", {}).get("dream_tags", []),
             "score": h.get("score", 0)} for h in r.get("result", [])]


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

def _ollama_summarize(text: str, activity: str = "", max_tokens: int = 200) -> str:
    """Résume un bloc de messages via Ollama — cœur du cycle RÊVE. `activity`
    (digest structuré de observability.py, voir reve_compress_slot) permet au
    résumé de couvrir aussi CE QUE BRO A FAIT pendant cette période (outils
    invoqués, succès/échecs) — pas seulement ce qui a été dit."""
    activity_section = (
        f"\n\nActions techniques effectuées par BRO pendant cette période :\n{activity}"
        if activity else ""
    )
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": (
            "Résume les échanges suivants en 2-3 phrases denses (en français). "
            "Garde les faits, décisions et compétences clés. Ignore les redondances. "
            "Si des actions techniques sont listées, mentionne brièvement ce qui a été "
            "tenté et si ça a fonctionné.\n\n"
            f"{text}{activity_section}\n\n--- Résumé :"
        ),
        "stream": False,
        "options": {"num_predict": max_tokens, "temperature": 0.3},
    }
    try:
        _gpu_ensure(OLLAMA_MODEL)
    except RuntimeError as e:
        print(f"[memory_manager] ⛔ résumé RÊVE reporté : {e}", file=sys.stderr)
        return ""
    import ollama_metrics
    _t0 = ollama_metrics.start()
    r = _curl("POST", f"{OLLAMA_URL}/api/generate", payload)
    ollama_metrics.record("generate", OLLAMA_MODEL, _t0, resp=r, ok=bool(r.get("response")))
    return r.get("response", "").strip()


def reve_compress_slot(user_id: str, slot: int = 0) -> bool:
    """
    Déclenche la compression RÊVE pour un slot si >= REVE_THRESHOLD entrées.
    Résume les anciennes en [RÊVE] + conserve les REVE_KEEP plus récentes.
    Retourne True si compression effectuée.

    Simplification 2026-10 : scrolle Qdrant directement (seule source de
    vérité désormais — plus de fichier ~/.zen/flashmem/{user_id}/slot{N}.json
    local à lire/purger). Élimine la logique "qdrant_synced"/rattrapage
    anti-perte de l'ancienne version : il n'existe plus de seconde copie qui
    pourrait diverger de Qdrant, donc plus rien à rattraper avant de purger.
    """
    cname = f"memory_{_user_hex(user_id)}"
    points: list = []
    offset = None
    while True:
        body: dict = {"limit": 250, "with_payload": True, "with_vector": False,
                      "filter": {"must": _slot_must(slot), "must_not": _NOT_ACTIVE}}
        if offset:
            body["offset"] = offset
        r = _curl("POST", f"{QDRANT_URL}/collections/{cname}/points/scroll", body)
        result = r.get("result", {})
        points.extend(result.get("points", []))
        offset = result.get("next_page_offset")
        if not offset:
            break

    if len(points) < REVE_THRESHOLD:
        return False

    points.sort(key=lambda p: p.get("payload", {}).get("timestamp", ""))
    to_compress = points[:-REVE_KEEP]

    block = "\n".join(
        f"[{p.get('payload', {}).get('timestamp', '')[:10]}] {p.get('payload', {}).get('content', '')}"
        for p in to_compress
    )
    activity_block = observability.digest(
        user_id,
        since_ts=to_compress[0].get("payload", {}).get("timestamp") if to_compress else None,
        until_ts=to_compress[-1].get("payload", {}).get("timestamp") if to_compress else None,
    )
    summary = _ollama_summarize(block, activity_block)
    if not summary:
        return False

    # Le résumé porte la date du DERNIER souvenir qu'il remplace, pas « maintenant » :
    # sinon il passerait pour le souvenir le plus récent (#mem, tri, prochaine compression).
    ts_summary = to_compress[-1].get("payload", {}).get("timestamp") or datetime.utcnow().isoformat() + "Z"
    upsert_user_slot(user_id, slot, f"[RÊVE] {summary}", timestamp=ts_summary,
                     importance=len(to_compress), source="reve")

    # Purge des points individuels remplacés par le résumé ci-dessus — sans
    # ça, ils restent orphelins dans Qdrant pour toujours.
    old_ids = [p["id"] for p in to_compress]
    if not _delete_points(cname, old_ids):
        print(f"[memory_manager] ⚠️ RÊVE : {len(old_ids)} vecteur(s) compressé(s) "
              f"non purgés de Qdrant pour {user_id}/slot{slot} (orphelins, sans impact "
              f"fonctionnel — nettoyage différé).")
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

    ps = sub.add_parser("upsert-slot")
    ps.add_argument("--user-id",    required=True)
    ps.add_argument("--slot",       type=int, default=0)
    ps.add_argument("--content",    required=True)
    ps.add_argument("--event-id",   default="")
    ps.add_argument("--importance", type=int, default=1)

    pk = sub.add_parser("upsert-skill")
    pk.add_argument("--skill",   required=True)
    pk.add_argument("--content", required=True)
    pk.add_argument("--npub",    default="")
    pk.add_argument("--node-id", default="")

    pd = sub.add_parser("delete-slot")
    pd.add_argument("--user-id", required=True)
    pd.add_argument("--slot",    type=int, required=True)

    prs = sub.add_parser("recent-slot")
    prs.add_argument("--user-id", required=True)
    prs.add_argument("--slot",    type=int, default=0)
    prs.add_argument("--limit",   type=int, default=5)

    pcs = sub.add_parser("count-slot")
    pcs.add_argument("--user-id", required=True)
    pcs.add_argument("--slot",    type=int, required=True)

    psc = sub.add_parser("slot-counts")
    psc.add_argument("--user-id", required=True)
    psc.add_argument("--slots",   nargs="+", type=int, required=True)

    pl = sub.add_parser("upsert-love")
    pl.add_argument("--user-id",  required=True)
    pl.add_argument("--content",  required=True)
    pl.add_argument("--event-id", default="")

    psl = sub.add_parser("search-love")
    psl.add_argument("--user-id", required=True)
    psl.add_argument("--query",   required=True)
    psl.add_argument("--limit",   type=int, default=5)

    pdl = sub.add_parser("delete-love")
    pdl.add_argument("--user-id", required=True)

    prl = sub.add_parser("resonance-love")
    prl.add_argument("--user-a", required=True)
    prl.add_argument("--user-b", required=True)
    prl.add_argument("--top-k",  type=int, default=3)

    pub = sub.add_parser("upsert-dream-bulk")
    pub.add_argument("--input", default="-",
                     help="Fichier JSON (array d'entries {pubkey,dream_tags,email}) ou '-' pour stdin")

    pdm = sub.add_parser("dream-match")
    pdm.add_argument("--tags",            nargs="+", required=True)
    pdm.add_argument("--exclude-pubkey",  default="")
    pdm.add_argument("--limit",           type=int,   default=20)
    pdm.add_argument("--score-threshold", type=float, default=0.1)

    pr = sub.add_parser("reve")
    pr.add_argument("--user-id", required=True)
    pr.add_argument("--slot",    type=int, default=0)

    psh = sub.add_parser("skill-hash")
    psh.add_argument("--skill", required=True)

    pbk = sub.add_parser("backup")
    pbk.add_argument("--output", required=True)

    prt = sub.add_parser("restore")
    prt.add_argument("--input",       required=True, help="Fichier backup JSON")
    prt.add_argument("--collections", nargs="*",     help="Filtrer sur ces collections")

    psr = sub.add_parser("search-geo")
    psr.add_argument("--lat",    required=True)
    psr.add_argument("--lon",    required=True)
    psr.add_argument("--query",  required=True)
    psr.add_argument("--limit",  type=int, default=5)
    psr.add_argument("--season", choices=["hiver", "printemps", "ete", "automne"], default=None)

    pov = sub.add_parser("memory-overview")
    pov.add_argument("--user-id", required=True)

    psf = sub.add_parser("set-fields")
    psf.add_argument("--user-id", required=True)
    psf.add_argument("--ids", nargs="+", type=int, required=True)
    psf.add_argument("--fields", required=True, help="JSON {champ: valeur}")

    pum = sub.add_parser("upsert-memory")
    pum.add_argument("--user-id", required=True)
    pum.add_argument("--content", required=True)
    pum.add_argument("--kind", default="fact")
    pum.add_argument("--source", default="manual")
    pum.add_argument("--visibility", default="private")

    pup = sub.add_parser("update-memory")
    pup.add_argument("--user-id", required=True)
    pup.add_argument("--id", type=int, required=True)
    pup.add_argument("--content", default=None)
    pup.add_argument("--kind", default=None)
    pup.add_argument("--visibility", default=None)

    pds = sub.add_parser("delete-source")
    pds.add_argument("--user-id", required=True)
    pds.add_argument("--source", required=True)

    pda = sub.add_parser("delete-all")
    pda.add_argument("--user-id", required=True)

    plm = sub.add_parser("list-memories")
    plm.add_argument("--user-id", required=True)
    plm.add_argument("--kinds",   nargs="*")
    plm.add_argument("--source",  default=None)
    plm.add_argument("--all",     action="store_true", help="inclut remplacés/supprimés")

    pdm2 = sub.add_parser("delete-memory")
    pdm2.add_argument("--user-id", required=True)
    pdm2.add_argument("--ids",     nargs="+", type=int, required=True)

    psu = sub.add_parser("search-slot")
    psu.add_argument("--user-id", required=True)
    psu.add_argument("--query",   required=True)
    psu.add_argument("--slots",   nargs="*", type=int)
    psu.add_argument("--limit",   type=int, default=5)
    psu.add_argument("--season",  choices=["hiver", "printemps", "ete", "automne"], default=None)

    args = p.parse_args()

    if args.cmd == "ensure-collections":
        ensure_all_collections()
        print("OK")

    elif args.cmd == "upsert-slot":
        ok = upsert_user_slot(args.user_id, args.slot, args.content,
                              event_id=args.event_id, importance=args.importance)
        sys.exit(0 if ok else 1)

    elif args.cmd == "upsert-skill":
        ok = upsert_skill(args.skill, args.content, args.npub,
                          getattr(args, "node_id", ""))
        sys.exit(0 if ok else 1)

    elif args.cmd == "delete-slot":
        ok = delete_user_slot(args.user_id, args.slot)
        sys.exit(0 if ok else 1)

    elif args.cmd == "recent-slot":
        results = recent_user_slot(args.user_id, args.slot, args.limit)
        print(json.dumps(results, ensure_ascii=False))

    elif args.cmd == "count-slot":
        print(count_user_slot(args.user_id, args.slot))

    elif args.cmd == "slot-counts":
        print(json.dumps(slot_counts(args.user_id, args.slots)))

    elif args.cmd == "upsert-love":
        ok = upsert_love_mem(args.user_id, args.content, event_id=args.event_id)
        sys.exit(0 if ok else 1)

    elif args.cmd == "search-love":
        results = search_love_mem(args.user_id, args.query, args.limit)
        print(json.dumps(results, ensure_ascii=False, indent=2))

    elif args.cmd == "delete-love":
        ok = delete_love_mem(args.user_id)
        sys.exit(0 if ok else 1)

    elif args.cmd == "resonance-love":
        results = love_resonance(args.user_a, args.user_b, top_k=args.top_k)
        print(json.dumps(results, ensure_ascii=False, indent=2))

    elif args.cmd == "upsert-dream-bulk":
        raw = sys.stdin.read() if args.input == "-" else open(args.input).read()
        entries = json.loads(raw) if raw.strip() else []
        print(upsert_dream_vectors_bulk(entries))

    elif args.cmd == "dream-match":
        results = search_dream_matches(args.tags, exclude_pubkey=args.exclude_pubkey,
                                       limit=args.limit, score_threshold=args.score_threshold)
        print(json.dumps(results, ensure_ascii=False))

    elif args.cmd == "reve":
        ok = reve_compress_slot(args.user_id, args.slot)
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
        results = search_geo(args.lat, args.lon, args.query, args.limit,
                             season=args.season)
        print(json.dumps(results, ensure_ascii=False, indent=2))

    elif args.cmd == "memory-overview":
        print(json.dumps(memory_overview(args.user_id)))

    elif args.cmd == "set-fields":
        sys.exit(0 if set_memory_fields(args.user_id, args.ids, json.loads(args.fields)) else 1)

    elif args.cmd == "upsert-memory":
        ok = upsert_memory(args.user_id, args.content, kind=args.kind, source=args.source,
                           visibility=args.visibility)
        print(_stable_id(args.user_id, _content_hash(args.content)) if ok else 0)
        sys.exit(0 if ok else 1)

    elif args.cmd == "update-memory":
        nid = update_memory(args.user_id, args.id, args.content, args.kind, args.visibility)
        print(nid)
        sys.exit(0 if nid else 1)

    elif args.cmd == "delete-source":
        sys.exit(0 if delete_by_source(args.user_id, args.source) else 1)

    elif args.cmd == "delete-all":
        sys.exit(0 if delete_all_memories(args.user_id) else 1)

    elif args.cmd == "list-memories":
        print(json.dumps(list_memories(args.user_id, kinds=args.kinds, source=args.source,
                                       include_inactive=args.all), ensure_ascii=False))

    elif args.cmd == "delete-memory":
        sys.exit(0 if delete_memory(args.user_id, args.ids) else 1)

    elif args.cmd == "search-slot":
        results = search_user_slot(args.user_id, args.query,
                                   args.slots, args.limit, season=args.season)
        print(json.dumps(results, ensure_ascii=False, indent=2))

    else:
        p.print_help()
