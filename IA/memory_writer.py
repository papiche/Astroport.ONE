#!/usr/bin/env python3
"""
memory_writer.py — BRO écrit sa mémoire À LA PLACE de l'utilisateur.

Personne ne tape #rec : la mémoire doit se construire seule. Ce module reçoit des
textes bruts (un échange avec BRO, des posts publics, des messages à LOVE…) et en
tire des SOUVENIRS ATOMIQUES, sans doublon ni contradiction :

  texte brut ──▶ file d'attente ──▶ extraction (1 appel IA, JSON) ──▶ pour chaque fait :
       voisins proches dans Qdrant ? ─ non ─▶ AJOUTER
                                      └ oui ─▶ ≥ 0,92 : ignorer ;  sinon l'IA tranche :
                                               AJOUTER · REMPLACER (l'ancien passe en
                                               « superseded », jamais détruit) · SUPPRIMER · IGNORER

Principes :
  • consentement PAR SOURCE, stocké dans NOSTR (kind 31903 d=memory_sources, chiffré pour soi — pas de fichier local) : rien n'est lu
    sur une source que la personne n'a pas cochée (le chat avec BRO est actif par défaut) ;
  • tout souvenir naît « private » ; seul le canal LOVE (messages confiés à l'agent de
    rencontre) naît « love » — et l'utilisateur peut tout rétrograder dans « Ce que BRO sait de moi » ;
  • jamais de secret (memory_manager.unstorable_reason) ;
  • jamais bloquant : la file est vidée par un process détaché (setsid), Ollama muet → on réessaie ;
  • rien n'est avalé en silence : chaque décision est journalisée sur stderr.

CLI :
  memory_writer.py enqueue EMAIL --source chat --text "..."
  memory_writer.py drain EMAIL [--dry-run] [-v]
  memory_writer.py consent EMAIL [--set SOURCE=on|off ...]
  memory_writer.py test EMAIL --text "..."        # extraction + décisions, sans rien écrire
"""
import argparse   # AVANT memory_manager : le venv ~/.astro embarque un vieux argparse.py
                  # (sans `required=`) qui masquerait celui de la bibliothèque standard
import fcntl
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
import memory_manager as mm
from prompt_safety import wrap_untrusted

# ── Réglages ────────────────────────────────────────────────────────────────
WRITER_MODEL     = os.environ.get("MEMORY_WRITER_MODEL", "gemma3:12b")
NEIGHBOR_MIN     = 0.55    # voisin « du même sujet » (bge-m3 : hors-sujet ≤ 0,55)
DUPLICATE_MIN    = 0.92    # quasi identique : on n'appelle même pas l'IA
MAX_FACTS        = 6       # faits retenus par lot
BATCH_MESSAGES   = 8       # messages regroupés dans un seul appel d'extraction
MAX_MSG_CHARS    = 700
QUEUE_MAX        = 500     # au-delà : les plus anciens sont abandonnés (et signalés)
MIN_CHARS        = 15
FORGET_MIN       = 0.50    # un souvenir n'est candidat à l'oubli que s'il ressemble à la demande
FORGET_BAND      = 0.15    # …et s'il est dans cet écart du plus proche
FORGET_MAX       = 3       # au-delà, la demande est jugée trop vague : rien n'est effacé
# Confiance minimale pour écrire : un souvenir faux coûte plus cher qu'un oubli. Ce que la personne dit elle-même
# à BRO passe dès 0,6 ; ce qui est DÉDUIT de textes passifs (publications, agenda, photos…) exige 0,7.
MIN_CONFIDENCE   = {"chat": 0.6}
MIN_CONFIDENCE_DEFAULT = 0.7

# Sources connues → (libellé affiché, activée par défaut, visibilité des souvenirs créés)
SOURCES = {
    "chat":         ("Mes échanges avec BRO",                    True,  "private"),
    "love_dm":      ("Mes messages privés à LOVE (rencontres)",  False, "love"),
    "nostr_public": ("Mes publications NOSTR (notes, articles)", False, "private"),
    "mastodon":     ("Mes posts Mastodon",                       False, "private"),
    "photo":        ("Mes photos choisies dans FaceCloud", False, "private"),
    "agenda":       ("Mon agenda",                               False, "private"),
    "contact":      ("Mes contacts",                             False, "private"),
}
KINDS = ("fact", "episode", "trait", "person")
# Sources SUSPENDUES (décision de Fred, 2026-10-19 : « on attend avant de terminer l'indexation des messages de la clef
# LOVE ; on se concentre d'abord sur BRO et ARBOR »). Une source en pause n'apprend RIEN, même cochée, même forcée ;
# la réactiver : MEMORY_ENABLE_LOVE_DM=1 (et BRO_LEARN_LOVE_DM=1 pour le démon de messages privés).
def paused_sources():
    return {s for s, env in (("love_dm", "MEMORY_ENABLE_LOVE_DM"),) if os.environ.get(env) != "1"}
# Le modèle recopie parfois son propre raisonnement comme s'il s'agissait d'un souvenir.
# Remplissage que le modèle tire parfois d'un simple bonjour (« Utilise l'expression … », « Salue ses lecteurs »).
_FILLER_RE = re.compile(r"(?i)^\s*(?:utilise|emploie|dit|écrit|salue|souhaite|publie)\b.{0,40}\b(?:expression|formule|bonjour|salut|bonne journée|slogan)\b")
# Allégation d'un TIERS rapportée par la personne (rumeur, accusation) : jamais un fait la concernant. La consigne seule
# ne suffit pas (le modèle l'ignorait 2 fois sur 3 à l'évaluation) ; « dit que » n'est volontairement PAS ici : un
# médecin, un proche qui dit quelque chose peut être une information utile.
_HEARSAY_RE = re.compile(r"(?i)\b(?:affirme|prétend|soutient|accuse|insinue|rumeur|il paraît)\b")
_META_RE = re.compile(r"(?i)\b(déjà (?:connu|connue|enregistré)|aucune? (?:information|souvenir)|"
                      r"n'?a pas (?:été )?(?:mentionn|précis))")


_PY = os.path.expanduser("~/.astro/bin/python3")
if not os.path.exists(_PY):
    _PY = sys.executable


def _user_dir(email):
    return os.path.expanduser(f"~/.zen/game/nostr/{email}")


def _state_dir(email):
    """Hors ~/.zen/tmp (purgé chaque nuit par 20h12.process.sh)."""
    d = os.path.expanduser(f"~/.zen/flashmem/{email}")
    os.makedirs(d, mode=0o700, exist_ok=True)
    return d


def _log(msg):
    print(f"[memory_writer] {msg}", file=sys.stderr)


# ── Consentement par source : dans NOSTR, pas sur le disque ─────────────────
# Les choix de la personne vivent dans UN événement kind 31903 — le kind des paramètres
# applicatifs du MULTIPASS, un d-tag par usage (`cookies`, `memory_sources`…) : on ne crée pas
# un kind par fonctionnalité. Il coexiste avec `d=cookies` sans le remplacer. Tout lecteur
# de 31903 DOIT donc filtrer sur #d (nostr_admin.html, routers/mailjet.py, dashboard.COOKIE.manager.sh
# le font). Signé par la clé de son MULTIPASS et chiffré NIP-44 pour elle seule — savoir qu'elle a
# coché « mes messages à LOVE » est déjà une donnée intime. Il suit le MULTIPASS sur toute
# la constellation (même sync que les autres coffres) ; aucun fichier local à perdre ou à
# désynchroniser. Le NSEC n'est lu que dans ce process court, jamais dans UPassport.
KIND_PREFS = 31903   # kind des PARAMÈTRES APPLICATIFS du MULTIPASS (un d-tag par usage : cookies, memory_sources…)
D_PREFS    = "memory_sources"
PREFS_RELAYS = ["ws://127.0.0.1:7777", "wss://relay.copylaradio.com"]
_CONSENT_TTL = 60        # secondes, mémoire du process seulement (jamais sur disque)
_consent_cache = {}


def _defaults():
    return {s: v[1] for s, v in SOURCES.items()}


def _keys(email):
    """Clés du MULTIPASS, ou None si ce compte n'a pas de .secret.nostr sur cette station."""
    import nostr_sdk
    try:
        raw = open(os.path.join(_user_dir(email), ".secret.nostr"), encoding="utf-8").read()
    except FileNotFoundError:
        return None
    m = re.search(r"NSEC=([^;\s]+)", raw)
    return nostr_sdk.Keys.parse(m.group(1)) if m else None


def _fetch_prefs(keys, timeout=6):
    """Dernier événement de préférences (déchiffré) ou None s'il n'en existe pas encore.
    Lève RuntimeError si AUCUN relais n'a répondu : « je ne sais pas » ≠ « pas de choix »."""
    import nostr_sdk
    from websockets.sync.client import connect
    best, answered = None, 0
    for relay in PREFS_RELAYS:
        try:
            with connect(relay, open_timeout=timeout, close_timeout=3) as ws:
                ws.send(json.dumps(["REQ", "msrc", {"kinds": [KIND_PREFS], "limit": 1,
                                                    "authors": [keys.public_key().to_hex()],
                                                    "#d": [D_PREFS]}]))
                deadline = time.time() + timeout
                while time.time() < deadline:
                    msg = json.loads(ws.recv(timeout=timeout))
                    if msg[0] == "EVENT":
                        if not best or msg[2]["created_at"] > best["created_at"]:
                            best = msg[2]
                    elif msg[0] == "EOSE":
                        break
                answered += 1
        except Exception as e:
            _log(f"⚠️ relais {relay} injoignable pour les préférences : {e}")
    if not answered:
        raise RuntimeError("aucun relais NOSTR n'a répondu")
    if not best:
        return None
    clear = nostr_sdk.nip44_decrypt(keys.secret_key(), keys.public_key(), best["content"])
    return json.loads(clear)


def consent(email, fresh=False):
    """{source: bool}. Défauts (chat seul) si la personne n'a encore rien choisi ; défauts
    AUSSI, bruyamment, si NOSTR est injoignable — jamais une source plus ouverte que le défaut."""
    hit = _consent_cache.get(email)
    if hit and not fresh and time.time() - hit[0] < _CONSENT_TTL:
        return dict(hit[1])
    out = _defaults()
    try:
        keys = _keys(email)
        if keys is None:
            return out                      # pas un MULTIPASS de cette station
        prefs = _fetch_prefs(keys)
        if prefs:
            out.update({k: bool(v) for k, v in (prefs.get("sources") or {}).items() if k in SOURCES})
        _consent_cache[email] = (time.time(), out)
    except Exception as e:
        _log(f"⚠️ préférences de mémoire illisibles pour {email} ({e}) — valeurs par défaut, rien d'élargi")
    return dict(out)


def set_consent(email, source, enabled):
    """Coche / décoche une source : publie un nouvel événement 31903 d=memory_sources (remplaçable)."""
    if source not in SOURCES:
        raise ValueError(f"source inconnue : {source}")
    import nostr_sdk
    from websockets.sync.client import connect
    keys = _keys(email)
    if keys is None:
        raise ValueError(f"{email} n'a pas de MULTIPASS sur cette station")
    # Relecture OBLIGATOIRE avant d'écrire : si NOSTR est injoignable, _fetch_prefs lève et on
    # n'écrase rien (retomber sur les défauts puis publier effacerait les autres choix).
    prev = _fetch_prefs(keys)
    cur = _defaults()
    if prev:
        cur.update({k: bool(v) for k, v in (prev.get("sources") or {}).items() if k in SOURCES})
        if int(time.time()) <= int(prev.get("updated_at", 0)):
            time.sleep(1.1)          # created_at est à la seconde : le plus récent doit l'emporter
    cur[source] = bool(enabled)
    content = nostr_sdk.nip44_encrypt(keys.secret_key(), keys.public_key(), json.dumps(
        {"v": 1, "sources": cur, "updated_at": int(time.time())}), nostr_sdk.Nip44Version.V2)
    ev = nostr_sdk.EventBuilder(nostr_sdk.Kind(KIND_PREFS), content).tags(
        [nostr_sdk.Tag.parse(["d", D_PREFS]), nostr_sdk.Tag.parse(["t", D_PREFS])]).finalize(keys)
    raw, accepted = json.loads(ev.as_json()), []
    for relay in PREFS_RELAYS:
        try:
            with connect(relay, open_timeout=10, close_timeout=3) as ws:
                ws.send(json.dumps(["EVENT", raw]))
                deadline = time.time() + 10
                while time.time() < deadline:
                    msg = json.loads(ws.recv(timeout=10))
                    if msg[0] == "OK":
                        if msg[2]:
                            accepted.append(relay)
                        else:
                            _log(f"⚠️ {relay} a refusé les préférences : {msg[3] if len(msg) > 3 else ''}")
                        break
        except Exception as e:
            _log(f"⚠️ {relay} injoignable : {e}")
    if not accepted:
        raise RuntimeError("aucun relais NOSTR n'a accepté l'enregistrement")
    _consent_cache[email] = (time.time(), dict(cur))
    return cur


# ── Filtre : ce qui mérite d'être lu ────────────────────────────────────────
_CMD_RE = re.compile(r"^\s*(?:#\w+[:\w]*\s*)+")


def clean_text(text):
    """Texte sans balises-commandes (#BRO, #rec…) en tête."""
    return _CMD_RE.sub("", text or "").strip()


def worth_reading(text):
    t = clean_text(text)
    if len(t) < MIN_CHARS:
        return False
    if mm.unstorable_reason(t):
        return False
    if t.startswith("{") and t.endswith("}"):      # message machine JSON
        return False
    return True


# ── File d'attente ──────────────────────────────────────────────────────────
def _queue_path(email):
    return os.path.join(_state_dir(email), ".memory_queue.jsonl")


def enqueue(email, text, source="chat", force=False, meta=None):
    """Met un texte en file. Retourne False si refusé (source non cochée, trop court,
    secret…). `force` : geste explicite de l'utilisateur (ex. bouton « Régénérer »)."""
    if source not in SOURCES:
        _log(f"source inconnue ignorée : {source}")
        return False
    if source in paused_sources():
        return False                         # suspendue : rien n'est mis en file (ni consentement, ni force n'y changent rien)
    if not force and not consent(email).get(source):
        return False
    if not worth_reading(text):
        return False
    item = {"t": datetime.utcnow().isoformat() + "Z", "source": source,
            "text": clean_text(text)[:MAX_MSG_CHARS * 3]}
    if force:
        item["force"] = True        # geste explicite : survit au filtre de consentement du vidage
    if meta:
        item["meta"] = meta
    with open(_queue_path(email), "a", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(json.dumps(item, ensure_ascii=False) + "\n")
    os.chmod(_queue_path(email), 0o600)
    return True


def kick(email):
    """Lance le vidage de la file dans un process AUTONOME (setsid) — jamais en
    sous-shell : un job long attaché à un script appelant bloquerait les `pgrep -f`
    de _12345.sh. Déjà en cours ⇒ flock refuse, et le process en cours reverra la file."""
    log = os.path.join(_state_dir(email), "memory_writer.log")
    try:
        with open(log, "a") as lf:
            subprocess.Popen([_PY, os.path.abspath(__file__), "drain", email],
                             stdout=lf, stderr=lf, stdin=subprocess.DEVNULL,
                             start_new_session=True, close_fds=True)
        return True
    except Exception as e:
        _log(f"❌ lancement du vidage impossible pour {email} : {e}")
        return False


def ingest(email, texts, source="chat", force=False):
    """Raccourci appelant : met en file puis déclenche le vidage. → nombre accepté."""
    n = sum(1 for t in texts if enqueue(email, t, source, force=force))
    if n:
        kick(email)
    return n


# ── Extraction ──────────────────────────────────────────────────────────────
def _ask(prompt):
    from question import answer_question
    import ollama_metrics
    with ollama_metrics.source("memory_writer"):
        raw = answer_question(prompt, model_name=WRITER_MODEL, temperature=0.1, format_json=True)
    if not raw:
        raise RuntimeError("le modèle n'a rien répondu (Ollama injoignable ?)")
    return json.loads(raw.strip())


_JOURS = ("lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche")


def _calendar(now):
    """Les 14 prochains jours AVEC leur jour de semaine, calculés ici : un LLM se trompe
    d'un jour sur « jeudi prochain » (constaté : le 23 octobre pris pour un jeudi)."""
    from datetime import timedelta
    d0 = datetime.strptime(now[:10], "%Y-%m-%d")
    lines = [f"{_JOURS[(d0 + timedelta(days=i)).weekday()]} {(d0 + timedelta(days=i)).strftime('%Y-%m-%d')}"
             + (" (aujourd'hui)" if i == 0 else "") for i in range(15)]
    return "; ".join(lines)


def _messages_prompt(now, source, block):
    return (
        f"Date du jour : {now}. Calendrier : {_calendar(now)}. Origine : {SOURCES[source][0]}.\n"
        "Voici des messages écrits PAR une personne (« je » = cette personne) :\n"
        f"{wrap_untrusted('messages', block)}\n\n"
        "Extrais UNIQUEMENT ce qui mérite d'être retenu durablement sur cette personne : "
        "faits (santé, allergies, habitudes), préférences, proches (prénom + lien), projets, "
        "événements datés, projets et besoins en cours (« cherche une nounou le mercredi »), centres d'intérêt, façon de s'exprimer.\n"
        "N'extrais PAS : questions, demandes ponctuelles (météo, traduction…), politesses, salutations, slogans, "
        "expressions toutes faites (« gm », « que la force soit avec vous »), commentaires sur la façon dont la personne écrit, "
        "ce que la personne RAPPORTE d'autres gens (rumeurs, accusations, opinions d'un voisin) et toute affirmation dont elle doute "
        "(« je ne sais pas si c'est vrai »), "
        "contenu général sans lien avec la personne, ni aucun mot de passe ou clé.\n"
        "Chaque souvenir est UNE phrase courte, qui se comprend SEULE : jamais de pronom sans "
        "son nom (« Camille, sa fille, adore dessiner », pas « Elle adore dessiner »). "
        "3e personne, sans le prénom de la personne elle-même ET sans « il » ni « elle » pour elle (son genre "
        "n'est pas connu) : forme sans sujet (« Est allergique aux noix », « Prépare une conférence ») ou "
        "« Sa fille Camille… », « Son frère Antoine… ». "
        "Convertis les dates relatives en dates absolues quand c'est certain. N'invente rien. "
        "N'écris jamais de commentaire sur la mémoire elle-même (« déjà connu »…).\n"
        "kind : fact | episode (événement daté) | trait (goût, style, opinion) | person (un proche).\n"
        "Si la personne demande d'OUBLIER ou d'effacer quelque chose, ne l'écris pas dans facts : "
        "mets sa description dans forget (ex. « sa fille Camille »).\n"
        "Si la personne CORRIGE une information (« non, ce n'est pas X, c'est Y »), extrais la version corrigée "
        "avec une confiance de 0.95 et mets l'ancienne version dans forget.\n"
        'Réponds en JSON : {"facts": [{"text": "...", "kind": "fact", "confidence": 0.9}], '
        '"forget": ["..."]} (listes vides si rien).'
    )


# Sources dont le texte est un RÉSUMÉ AUTOMATIQUE (pas des phrases écrites par la personne) : un prompt dédié.
# Le prompt « messages de la personne » appliqué à des résumés de photos fabriquait de faux souvenirs
# (« Elle a pris des photos », des coordonnées érigées en faits, le propriétaire « reconnu » comme un tiers).
_DERIVED = {"photo"}


def _photo_prompt(now, block):
    return (
        f"Date du jour : {now}.\n"
        "Voici des résumés AUTOMATIQUES d'événements tirés de la photothèque de la personne (elle en est la "
        "propriétaire ; elle n'est pas forcément l'une des « personnes reconnues »).\n"
        f"{wrap_untrusted('evenements_photo', block)}\n\n"
        "Pour CHAQUE événement, écris UNE phrase impersonnelle et factuelle qui commence par sa date "
        "(AAAA-MM-JJ) : ce qui s'y passe en quelques mots tirés des scènes, avec qui (les personnes reconnues), "
        "et le lieu UNIQUEMENT en coordonnées approximatives entre parenthèses si elles sont données "
        "(sinon n'écris RIEN sur le lieu, pas même « lieu inconnu » ni « coordonnées non disponibles »).\n"
        "Règles : n'invente ni lieu, ni prénom, ni lien de parenté ; n'écris JAMAIS « il » ni « elle » pour la "
        "propriétaire ; ne dis pas qu'une personne est « reconnue » ; aucun souvenir autre que ces événements ; "
        "une phrase par événement, pas de fait séparé pour les coordonnées.\n"
        'Réponds en JSON : {"facts": [{"text": "2025-07-02 : repas à table avec Emma, Tim et Mamiche", '
        '"kind": "episode", "confidence": 0.7}]}'
    )


_DATE_RE = re.compile(r"\b\d{4}-\d{2}-\d{2}\b")
_GENDERED_OWNER_RE = re.compile(r"(?i)^\s*(il|elle)\s")


def extract_facts(texts, source, now=None):
    """Messages bruts → ([{text, kind, confidence}] (≤ MAX_FACTS), [à oublier])."""
    now = now or datetime.utcnow().strftime("%Y-%m-%d")
    block = "\n".join(f"- {t[:MAX_MSG_CHARS]}" for t in texts)
    if source in _DERIVED:
        prompt = _photo_prompt(now, block)
    else:
        prompt = _messages_prompt(now, source, block)
    data = _ask(prompt)
    out = []
    for f in (data.get("facts") or [])[:MAX_FACTS]:
        t = str(f.get("text", "")).strip()
        if len(t) < 8 or mm.unstorable_reason(t):
            continue
        kind = f.get("kind") if f.get("kind") in KINDS else "fact"
        try:
            conf = max(0.0, min(1.0, float(f.get("confidence", 0.8))))
        except (TypeError, ValueError):
            conf = 0.8
        if _META_RE.search(t) or _FILLER_RE.search(t):
            continue
        if _HEARSAY_RE.search(t):
            _log(f"⚠️ allégation d'un tiers écartée : {t[:80]}")
            continue
        floor = MIN_CONFIDENCE.get(source, MIN_CONFIDENCE_DEFAULT)
        if conf < floor and source not in _DERIVED:
            _log(f"⚠️ trop incertain ({conf:.2f} < {floor}) [{source}] : {t[:80]}")
            continue
        if source in _DERIVED:
            # Résumés automatiques : un événement DATÉ, jamais un fait isolé, jamais de genre deviné.
            if not _DATE_RE.search(t) or _GENDERED_OWNER_RE.match(t) or "reconnu" in t.lower():
                _log(f"⚠️ sortie écartée ({source}) : {t[:80]}")
                continue
            kind, conf = "episode", min(conf, 0.7)
        out.append({"text": t, "kind": kind, "confidence": conf})
    forget = [str(x).strip() for x in (data.get("forget") or []) if str(x).strip()][:5]
    return out, forget


# ── Décision : ajouter / remplacer / supprimer / ignorer ────────────────────
def decide(email, fact, source="chat"):
    """→ {"op": ADD|UPDATE|DELETE|NOOP, "target": point_id|None, "text": str}."""
    if source != "chat" and mm.forgotten_match(email, fact["text"]):
        # La personne a fait OUBLIER ce sujet : une source passive (publications relues, agenda…) ne le ressuscite pas.
        _log(f"⛔ déjà oublié par la personne [{source}] : {fact['text'][:80]}")
        return {"op": "NOOP", "target": None, "text": fact["text"]}
    near = mm.search_user_slot(email, fact["text"], limit=3, score_threshold=NEIGHBOR_MIN)
    if not near:
        return {"op": "ADD", "target": None, "text": fact["text"]}
    if near[0].get("score", 0) >= DUPLICATE_MIN:
        return {"op": "NOOP", "target": near[0]["id"], "text": fact["text"]}
    if source in _DERIVED:
        # Deux sorties photo voisines sont deux événements distincts : jamais de REMPLACEMENT de
        # l'un par l'autre (un souvenir daté ne se contredit pas), donc pas d'appel IA non plus.
        return {"op": "ADD", "target": None, "text": fact["text"]}
    listing = "\n".join(f"[{i}] {h['payload'].get('content', '')}" for i, h in enumerate(near))
    prompt = (
        "Souvenirs DÉJÀ connus sur la personne :\n"
        f"{wrap_untrusted('souvenirs_connus', listing)}\n\n"
        f"Nouvelle information : « {fact['text']} »\n\n"
        "Choisis UNE action :\n"
        "- ADD : information nouvelle, qui ne contredit ni ne répète aucun souvenir\n"
        "- UPDATE : remplace le souvenir [target] (contradiction, mise à jour, précision) ; "
        "« text » = formulation finale fusionnée\n"
        "- DELETE : la personne demande d'oublier le souvenir [target]\n"
        "- NOOP : déjà connu\n"
        'Réponds en JSON : {"op": "ADD|UPDATE|DELETE|NOOP", "target": <numéro ou null>, "text": "..."}'
    )
    try:
        d = _ask(prompt)
    except Exception as e:
        _log(f"⚠️ décision impossible ({e}) — ajout simple")
        return {"op": "ADD", "target": None, "text": fact["text"]}
    op = str(d.get("op", "ADD")).upper()
    tgt = d.get("target")
    point = near[tgt]["id"] if isinstance(tgt, int) and 0 <= tgt < len(near) else None
    if op in ("UPDATE", "DELETE") and point is None:
        op = "ADD"
    if op not in ("ADD", "UPDATE", "DELETE", "NOOP"):
        op = "ADD"
    if op in ("UPDATE", "DELETE") and source != "chat":
        tgt_pl = next((h["payload"] for h in near if h["id"] == point), {})
        if mm.is_pinned(tgt_pl):
            # Écrit ou corrigé par la personne : seule SA parole (chat) peut le changer, pas une source passive.
            _log(f"🔒 souvenir écrit/corrigé par la personne, conservé [{source}] : {tgt_pl.get('content', '')[:80]}")
            return {"op": "NOOP", "target": point, "text": fact["text"]}
    return {"op": op, "target": point, "text": (d.get("text") or fact["text"]).strip()}


def forget(email, description, dry=False):
    # (appelé seulement pour le canal « chat » — cf. process_batch)
    """« Oublie ce que je t'ai dit sur … » : retrouve les souvenirs visés et les marque
    `deleted` (l'IA choisit parmi les voisins — jamais une suppression à l'aveugle)."""
    near = mm.search_user_slot(email, description, limit=5, score_threshold=FORGET_MIN)
    if near:
        top = near[0].get("score", 0)
        near = [h for h in near if h.get("score", 0) >= top - FORGET_BAND]   # seulement le groupe de tête : le LLM ne voit pas le reste
    if not near:
        _log(f"∅ oubli demandé « {description} » : aucun souvenir correspondant")
        return 0
    listing = "\n".join(f"[{i}] {h['payload'].get('content', '')}" for i, h in enumerate(near))
    d = _ask("Souvenirs connus :\n" + wrap_untrusted("souvenirs", listing) +
             f"\n\nLa personne demande d'oublier : « {description} ».\n"
             "Quels numéros concernent cette demande ? Prends tout le SUJET visé (la personne ou la "
             "chose en entier, y compris ses détails comme ses goûts), mais rien d'autre ; aucun si doute.\n"
             'Réponds en JSON : {"delete": [numéros]}')
    chosen = sorted({i for i in (d.get("delete") or []) if isinstance(i, int) and 0 <= i < len(near)})
    if len(chosen) > FORGET_MAX:
        # Effacer est irréversible : une demande qui en viserait autant est trop vague, on n'en fait RIEN et on le dit.
        _log(f"⚠️ oubli « {description} » : {len(chosen)} souvenirs visés (> {FORGET_MAX}), demande trop vague — rien effacé")
        return 0
    ids = [near[i]["id"] for i in chosen]
    for i in chosen:
        _log(("(à blanc) " if dry else "") + f"OUBLI  {near[i]['payload'].get('content', '')[:90]}")
    if ids and not dry:
        mm.forget_points(email, ids)        # texte effacé + pierre tombale (cf. memory_manager.delete_memory)
    return len(ids)


def apply(email, fact, decision, source, dry=False):
    vis = SOURCES[source][2]
    op, tgt, text = decision["op"], decision["target"], decision["text"]
    tag = f"{op:6} {fact['kind']:7} {text[:90]}"
    if dry or op == "NOOP":
        _log(("(à blanc) " if dry else "") + tag)
        return op
    if op == "DELETE":
        # Pierre tombale seulement si c'est la PERSONNE qui le demande (chat) ; une source passive ne fait que retirer.
        ok = (mm.forget_points(email, [tgt]) if source == "chat"
              else mm.set_memory_fields(email, [tgt], {"status": "deleted"}))
    else:
        extra = {}
        if source == "love_dm":
            # L'espace d'information est RELATIF à la clé LOVE de ce compte (jamais une base globale).
            try:
                with open(os.path.join(_user_dir(email), "HEX_LOVE"), encoding="utf-8") as f:
                    extra["love_key"] = f.read().strip()
            except OSError:
                pass
        ok = mm.upsert_memory(email, text, kind=fact["kind"], source=source, visibility=vis,
                              confidence=fact["confidence"], extra=extra or None, auto=True)
        if ok and op == "UPDATE":
            mm.set_memory_fields(email, [tgt], {"status": "superseded"})
    _log(("✔ " if ok else "✗ ") + tag)
    return op if ok else "ERROR"


def process_batch(email, items, dry=False):
    """Un lot de messages d'UNE même source → souvenirs écrits. Lève si l'IA est muette."""
    source = items[0]["source"]
    facts, to_forget = extract_facts([i["text"] for i in items], source, now=items[-1]["t"][:10])
    ops = {}
    if to_forget and source != "chat":
        _log(f"⚠️ demande d'oubli ignorée [{source}] : seule la personne, dans son échange avec BRO, peut faire oublier")
        to_forget = []
    for desc in to_forget:
        n = forget(email, desc, dry=dry)
        if n:
            ops["FORGET"] = ops.get("FORGET", 0) + n
    for f in facts:
        r = apply(email, f, decide(email, f, source), source, dry=dry)
        ops[r] = ops.get(r, 0) + 1
    if not facts and not to_forget:
        _log(f"∅ rien à retenir dans {len(items)} message(s) [{source}]")
    return ops


# ── Vidage de la file ───────────────────────────────────────────────────────
def drain(email, dry=False):
    qpath = _queue_path(email)
    lock = open(os.path.join(_state_dir(email), ".memory_drain.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        _log("déjà en cours — le process actif reverra la file")
        return {"busy": True}
    total = {}
    while True:
        try:
            with open(qpath, encoding="utf-8") as f:
                fcntl.flock(f, fcntl.LOCK_EX)
                lines = [l for l in f.read().splitlines() if l.strip()]
                if not dry:
                    open(qpath, "w").close()          # vidée sous le même verrou : pas de perte
        except FileNotFoundError:
            break
        if not lines:
            break
        items = []
        for l in lines:
            try:
                items.append(json.loads(l))
            except Exception:
                _log(f"ligne illisible ignorée : {l[:60]}")
        consents = consent(email)
        paused = paused_sources()
        items = [i for i in items if i.get("source") not in paused and (i.get("force") or consents.get(i.get("source")))]
        if len(items) > QUEUE_MAX:
            _log(f"⚠️ file trop longue ({len(items)}) : {len(items) - QUEUE_MAX} plus anciens abandonnés")
            items = items[-QUEUE_MAX:]
        failed = []
        i = 0
        while i < len(items):
            src = items[i]["source"]
            batch = [items[i]]
            while (i + len(batch) < len(items) and items[i + len(batch)]["source"] == src
                   and len(batch) < BATCH_MESSAGES):
                batch.append(items[i + len(batch)])
            try:
                for k, v in process_batch(email, batch, dry=dry).items():
                    total[k] = total.get(k, 0) + v
            except Exception as e:
                _log(f"⚠️ lot de {len(batch)} message(s) [{src}] reporté : {e}")
                failed.extend(batch)
            i += len(batch)
        if failed and not dry:
            with open(qpath, "a", encoding="utf-8") as f:
                fcntl.flock(f, fcntl.LOCK_EX)
                for it in failed:
                    f.write(json.dumps(it, ensure_ascii=False) + "\n")
            break          # IA muette : on s'arrête, la prochaine passe réessaiera
        if dry:
            break
    return total


# ── État pour l'interface (Mon compte) ──────────────────────────────────────
def queue_size(email):
    try:
        with open(_queue_path(email), encoding="utf-8") as f:
            return sum(1 for l in f if l.strip())
    except FileNotFoundError:
        return 0


def sources_status(email):
    """[{source, label, enabled, default, memories, visibility}] + messages en attente."""
    c = consent(email)
    try:
        by_source = mm.memory_overview(email)["by_source"]
    except Exception as e:
        _log(f"⚠️ décompte indisponible : {e}")
        by_source = {}
    paused = paused_sources()
    rows = [{"source": s, "label": lab, "enabled": c[s] and s not in paused, "default": dflt,
             "memories": by_source.get(s, 0), "visibility": vis, "paused": s in paused}
            for s, (lab, dflt, vis) in SOURCES.items()]
    return {"sources": rows, "queue": queue_size(email),
            "other": {k: v for k, v in by_source.items() if k not in SOURCES}}


# ── CLI ─────────────────────────────────────────────────────────────────────
def _main():
    p = argparse.ArgumentParser(description="Mémoire écrite par BRO")
    sub = p.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("enqueue"); e.add_argument("email"); e.add_argument("--source", default="chat")
    e.add_argument("--text", required=True); e.add_argument("--force", action="store_true")
    d = sub.add_parser("drain"); d.add_argument("email"); d.add_argument("--dry-run", action="store_true")
    c = sub.add_parser("consent"); c.add_argument("email"); c.add_argument("--set", nargs="*", default=[])
    st = sub.add_parser("sources"); st.add_argument("email")
    t = sub.add_parser("test"); t.add_argument("email"); t.add_argument("--text", required=True)
    t.add_argument("--source", default="chat")
    a = p.parse_args()

    if a.cmd == "enqueue":
        ok = enqueue(a.email, a.text, a.source, force=a.force)
        if ok:
            kick(a.email)
        # Un refus normal (source non cochée, trop court, secret) n'est PAS une erreur : code 0.
        # Les vraies erreurs (NOSTR, Qdrant…) lèvent et sortent en code ≠ 0 avec leur trace.
        print("en file" if ok else "refusé (source non cochée, trop court ou secret)")
    elif a.cmd == "drain":
        print(json.dumps(drain(a.email, dry=a.dry_run)))
    elif a.cmd == "consent":
        for kv in a.set:
            s, _, v = kv.partition("=")
            set_consent(a.email, s, v.lower() in ("on", "1", "true", "oui"))
        print(json.dumps(consent(a.email), ensure_ascii=False, indent=1))
    elif a.cmd == "sources":
        print(json.dumps(sources_status(a.email), ensure_ascii=False))
    elif a.cmd == "test":
        item = {"t": datetime.utcnow().isoformat() + "Z", "source": a.source, "text": clean_text(a.text)}
        print(json.dumps(process_batch(a.email, [item], dry=True)))


if __name__ == "__main__":
    _main()
