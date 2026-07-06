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
import sys
import json
import time
import hashlib
import tempfile
import subprocess

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bro_tools
import observability
import algorithm_planner as aplan
from prompt_safety import wrap_untrusted

from bro._shared import *
from bro.nostr import *
from bro.watch_store import *
from bro.rag import *
from bro.media import *
from bro.economy import *
from bro.identity import *
from bro.tools import *


DIGEST_PREFIX = "📋 Rapport quotidien BRO"

_PROGRESS_MARKER = "je vous enverrai le résultat"

_THINKING_MARKER = "je vous réponds dans un instant"

TTL_PROGRESS_SEC = 60  # Messages de progression — disparaissent au bout de 60s (NIP-40)

BOT_REPLY_MARKERS = ("📋", "✅", "🤔", "💬", "🔔")

_IA_CLEAN_RE = re.compile(
    r'#(?:bro|bot|image|video|vid[ée]o|music|musique|search|recherche'
    r'|plant(?:net|e)?|botanique|flora|insect(?:e)?|animal|person(?:ne)?'
    r'|objet?|place|lieu|inventory|inventaire|describe|d[ée]crire'
    r'|pierre|am[ée]lie)\b',
    re.IGNORECASE
)

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

def _timeline_always_alert_enabled(owner_email):
    """Préférence capitaine (fichier .mailjet, mêmes préférences que les
    autres notifications — cf. kin_prefs.sh) : le canal 'timeline' (fil
    d'actualité, ex: Mastodon /home) alerte-t-il sur TOUS les posts, comme
    'notifications', ou seulement sur ceux qui matchent des mots-clés ?
    True par défaut (décision du 2026-07-06) : le scraper récupère déjà le
    fil avec succès (incident réel constaté : 3 posts trouvés, 0 montrés
    faute de mots-clés configurés) — mieux vaut montrer ce qui a été
    récupéré, quitte à être plus bavard, que filtrer 100% en silence.
    Désactivable en ajoutant {"watch": {"timeline_always_alert": false}}
    dans .mailjet."""
    mailjet_path = os.path.join(_owner_dir(owner_email), ".mailjet")
    try:
        with open(mailjet_path, encoding="utf-8") as f:
            prefs = json.load(f)
    except Exception:
        return True
    return bool(prefs.get("watch", {}).get("timeline_always_alert", True))

def matches_keywords(entry, text, owner_email=None, account=None, channel=None):
    # Source où chaque item est par nature pertinent (ex: mention Mastodon) —
    # pas besoin de mots-clés, tout déclenche une suggestion.
    if entry.get("always_alert"):
        return True
    # Canal "timeline" : always_alert implicite par défaut (voir
    # _timeline_always_alert_enabled) — indépendant de ce qui est persisté
    # dans l'entrée elle-même, donc s'applique aussi aux entrées déjà
    # existantes créées avant cette décision (ex: keywords=[] historique).
    if channel == "timeline" and owner_email and _timeline_always_alert_enabled(owner_email):
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

def generate_suggestion(context_label, username, text, examples=None,
                         persona_context="", network_context=""):
    """Génère une suggestion de réponse.

    persona_context  : traits de style/expertise du propriétaire (slot 14, optionnel)
    network_context  : fiche de l'interlocuteur depuis uplanet_network (optionnel)
    """
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
    context_blocks = ""
    if persona_context:
        context_blocks += f"\n\n[MON STYLE / EXPERTISE] {persona_context}"
    if network_context:
        context_blocks += f"\n\n[PROFIL DE {username}] {network_context}"

    prompt = (
        f"Tu rédiges une réponse au nom du destinataire de ce message.\n"
        f"Message reçu sur {context_label}, écrit par {username} :\n\n"
        f"« {text} »"
        f"{context_blocks}"
        f"{examples_block}\n\n"
        "Propose une réponse brève et appropriée."
    )
    result = subprocess.run([
        "python3", f"{BRO_IA_PATH}/question.py", prompt
    ], capture_output=True, text=True)
    return result.stdout.strip() or "(BRO n'a pas pu générer de suggestion.)"

FEEDBACK_WINDOW_DAYS = 5

FEEDBACK_MATCH_THRESHOLD = 0.75

FEEDBACK_VERBATIM_THRESHOLD = 0.9

MAX_PENDING_FEEDBACK = 50

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
    # Contexte de persona calculé une fois pour tout le digest (invariant par propriétaire)
    persona_ctx = _recall_persona(owner_email)
    if persona_ctx:
        print(f"[BRO_WATCH] Persona rappelée pour {owner_email} : {persona_ctx[:80]}…")
    lines = []
    for it in relevant:
        # Contexte réseau par interlocuteur (Qdrant uplanet_network)
        network_ctx = _recall_network_profile(it.get("username", ""))
        suggestion = generate_suggestion(
            context_label, it.get("username", "?"), it.get("text", ""),
            examples=examples, persona_context=persona_ctx, network_context=network_ctx,
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

COMMAND_LAST_CHECK_KEY = "_bro_commands"  # section top-level du manifest (pas liée à un domaine)

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
        f"Message du propriétaire :\n{wrap_untrusted('owner_message', text)}\n\n"
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

_ACTION_SANITY_HINTS = {
    "toggle": ["actif", "active", "désactiv", "desactiv", "arrête", "arrete",
               "stop", "coupe", "relance", "reprend", "remet", "remets",
               "surveill", "veille", "suivre"],
    "set_keywords": ["mot-clé", "mot clé", "mots-clé", "mots clé", "keyword", "surveille"],
    "set_learn_from": ["apprend", "apprentissage", "apprends"],
    "confirm_suggestion": ["ok", "oui", "envoie", "valide", "d'accord", "daccord"],
    "correct_suggestion": ["plutôt", "plutot", "corrige", "préfère", "prefere", "à la place", "a la place"],
}

def _looks_like_question(lowered):
    """Heuristique légère (pas de LLM) : une question interrogative n'est
    JAMAIS une commande de configuration, même si elle contient un mot-clé
    de hint (cf. incident 2026-07-06 : "quelle chaine youtube je surveille ?"
    contient "surveill", hint valide pour 'toggle', mais c'est une question)."""
    stripped = lowered.strip()
    if stripped.endswith("?"):
        return True
    return any(
        stripped.startswith(m) or f" {m}" in stripped
        for m in ("quel ", "quelle ", "quels ", "quelles ", "combien ",
                   "est-ce que", "est ce que", "qui est-ce")
    )

def _sanity_check_action(text, action):
    kind = action.get("action")
    hints = _ACTION_SANITY_HINTS.get(kind)
    if not hints:
        return True  # pas de règle définie pour ce type d'action → on fait confiance
    lowered = text.lower()
    if not any(h in lowered for h in hints):
        return False
    # toggle/set_keywords/set_learn_from sont TOUJOURS des commandes impératives,
    # jamais la réponse à une question — un hint présent dans une phrase
    # interrogative est un faux positif lexical, pas une vraie commande.
    if kind in ("toggle", "set_keywords", "set_learn_from") and _looks_like_question(lowered):
        return False
    return True

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

def _trigger_arbor_tool_forge(owner_email, need_description):
    """Lance arbor_tool_forge.py --need DESCRIPTION --notify-captain en tâche
    détachée — forge un NOUVEL outil autonome, contrairement à
    _trigger_arbor_self_improve qui affine seulement le prompt
    d'interprétation existant. Peut prendre plusieurs minutes (plusieurs
    appels claude CLI, tests sandboxés). Ne merge jamais seul — voir la
    gouvernance actée dans arbor_tool_forge.py (branche isolée, revue
    humaine obligatoire)."""
    script = os.path.join(BRO_IA_PATH, "arbor_tool_forge.py")
    if not os.path.isfile(script):
        return "⚠️ arbor_tool_forge.py introuvable sur cette station."
    try:
        subprocess.Popen(
            ["python3", script, "--need", need_description, "--notify-captain"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        return f"⚠️ Échec du lancement de la forge d'outil : {e}"
    return (f"🔨 Forge d'un nouvel outil lancée pour : « {need_description} » (plusieurs minutes, "
            "plusieurs tentatives possibles). Si les tests passent, une branche isolée sera "
            "proposée et vous serez prévenu par message de la station — jamais mergée seule.")

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

_load_arbor_tools_into_registry()

def _bro_capabilities_description(owner_email):
    """Description ANCRÉE dans le code réel — jamais de commande/tag/outil
    inventé. Corrige un incident constaté (2026-07-03) : le prompt générique
    précédent poussait le LLM à halluciner des commandes slash inexistantes
    (/activate_source, etc.) faute de contexte réel sur ce que BRO sait
    vraiment faire."""
    lines = [
        "Je suis BRO, l'assistant IA personnel (clone numérique) du propriétaire de ce compte UPlanet.",
        "Je te réponds par NOSTR chiffré (canal self-DM).",
        "",
        "COMMENT ME PARLER :",
        "- Langage naturel direct, pas de syntaxe spéciale requise. Exemples réels : "
        "« désactive mastodon.social », « ajoute le mot-clé X sur le fil mastodon », "
        "« apprends mon style depuis @compte », « #ok » pour valider une suggestion, "
        "« non, dis plutôt : ... » pour la corriger.",
        "- Syntaxe #hashtag de secours si le langage naturel échoue : "
        "#watch DOMAINE on|off — #watch DOMAINE CANAL keywords mot1,mot2 — "
        "#watch DOMAINE CANAL learn_from @compte — #ok — #plutôt TEXTE.",
        "",
        "CE QUE JE SAIS RÉELLEMENT FAIRE (ne jamais inventer d'autre commande, tag ou outil) :",
        "Surveillance & mémoire :",
        "- Surveillance de sources web (Mastodon, forums Discourse, chaînes YouTube).",
        "- Mémoire de nos échanges précédents (rappelée automatiquement quand pertinente) — "
        "« #oublie » pour l'effacer.",
        "- « #rec #2 » / #mem #2 / #reset #2 ciblent un autre slot que le slot 0 par défaut.",
        "Images & génération :",
        *(f"- {entry['description']}" for entry in _MEDIA_TAG_HANDLERS),
        "Commandes :",
    ]
    # Commandes du registre bro_tools (help/mem/reset/rec/scraper...) — une
    # seule définition par outil, partagée avec l'exécution et le routage
    # sémantique : impossible que cette liste diverge de ce qui est réellement
    # exécutable (cf. incident du 2026-07-03). Niveau RÉEL (0-5, voir
    # bro_user_level.py) — PAS un simple booléen capitaine : un sociétaire
    # satellite (niveau 3, pas capitaine) doit voir #craft/#badge dans sa
    # propre liste de capacités, faute de quoi l'IA les cacherait à tort à
    # tous les non-capitaines.
    access_level = ACCESS_LEVEL_CAPITAINE if _is_captain(owner_email) else _owner_access_level(owner_email)
    for tool in bro_tools.all_tools():
        if tool.source == "static" and tool.advertise and tool.min_access <= access_level:
            lines.append(f"- {tool.description}")
    if _is_captain(owner_email):
        lines.append("- #arbor : lance l'auto-amélioration du prompt d'interprétation (réservé capitaine).")

    arbor_tools = [t for t in bro_tools.all_tools() if t.source == "arbor"]
    if arbor_tools:
        lines.append("")
        lines.append("OUTILS SUPPLÉMENTAIRES DISPONIBLES (pose directement ta question, utilisés automatiquement) :")
        for tool in arbor_tools:
            lines.append(f"- {tool.description}")

    lines.append("")
    lines.append("Si on te demande ce que tu sais faire, réponds à partir de CETTE liste uniquement. "
                 "Si une capacité n'y figure pas, dis clairement que tu ne l'as pas plutôt que d'improviser.")
    return "\n".join(lines)

def _handle_ia_responder_tags(owner_email, text, img_url=None):
    """Pont BRO ↔ UPlanet_IA_Responder.sh : reconnaît les #tags media/vision
    dans le canal self-DM. Chaque tag reconnu LANCE le traitement réel en
    tâche détachée (_dispatch_media_background) et retourne immédiatement un
    accusé de réception — voir sa docstring pour la raison structurelle.
    Retourne None (→ repli conversationnel gérant img_url en contexte) si
    aucun tag média n'est présent."""
    lowered = text.lower()
    clean = _IA_CLEAN_RE.sub("", text).strip()

    for entry in _MEDIA_TAG_HANDLERS:
        if entry.get("advertise_only"):
            continue
        if not re.search(entry["pattern"], lowered):
            continue
        if entry.get("disabled_message"):
            return entry["disabled_message"]
        if entry.get("requires_img") and not img_url:
            return entry["requires_img"]
        media_type, payload = entry["build"](text, clean, img_url)
        return _dispatch_media_background(media_type, owner_email, payload)

    # Pas de tag spécifique → repli vers _conversational_reply (avec img_url en contexte)
    return None

def _detect_system_tag(text):
    tool = bro_tools.find_by_tag(text)
    return tool.name if tool else None

_SKILL_TAG_RE = re.compile(r"#(rec|mem|mod|rm):([a-z0-9_-]*)", re.IGNORECASE)
_SKILL_TAG_TARGETS = {"rec": "rec_skill", "mem": "mem_skill",
                      "mod": "mod_skill", "rm": "rm_skill"}

def _detect_skill_tag(text):
    m = _SKILL_TAG_RE.search(text)
    if not m:
        return None
    return _SKILL_TAG_TARGETS[m.group(1).lower()]

def update_bro_capabilities(owner_email):
    """Enrichit _bro_commands.available_scrapers dans le manifest avec le catalogue
    des scrapers de la station, puis republie en kind 31903."""
    try:
        manifest = _load_manifest(owner_email)
        scrapers_catalog = [
            {"domain": s["domain"], "category": s["category"], "icon": s["icon"]}
            for s in list_station_scrapers()
        ]
        manifest.setdefault(COMMAND_LAST_CHECK_KEY, {})["available_scrapers"] = scrapers_catalog
        _save_manifest(owner_email, manifest)
        _publish_manifest_to_nostr(owner_email, manifest)
    except Exception as e:
        print(f"[BRO_WATCH] update_bro_capabilities failed for {owner_email}: {e}")

try:
    import bro_user_level
except Exception:
    bro_user_level = None

_register_system_tools()

def _execute_system_tag(target, owner_email, text):
    """Exécute une commande système reconnue par match_intent, via le
    registre bro_tools — jamais de réponse LLM inventée pour ces cas,
    contrairement à l'incident du 2026-07-03. Retourne None si la cible
    n'est pas enregistrée, pour repli honnête côté appelant plutôt qu'une
    exécution hasardeuse."""
    tool = bro_tools.get(target)
    if not tool:
        return None
    _t0 = time.monotonic()
    try:
        result = tool.handler(owner_email, text)
    except Exception:
        observability.log_event(owner_email, target, "system_tag",
                                 success=False, latency_ms=(time.monotonic() - _t0) * 1000)
        raise
    observability.log_event(owner_email, target, "system_tag",
                             success=bool(result), latency_ms=(time.monotonic() - _t0) * 1000)
    return result

_KNOWN_MEDIA_TAGS = {
    "image", "video", "vidéo", "music", "musique",
    "plant", "plantnet", "plante", "botanique", "flora",
    "inventory", "inventaire", "pierre", "amelie", "amélie",
    "describe", "décrire", "decrire",
}

_KNOWN_MISC_TAGS = {"watch", "oublie", "oubli", "forget", "ok", "oui", "plutot", "plutôt"} | {
    t.lstrip("#") for t in ARBOR_TRIGGERS
}

def _known_hashtags():
    """Ensemble de tous les #tags réellement gérés par le code — pour détecter
    les commandes inventées dans les réponses conversationnelles. Incident
    réel (2026-07-06) : invité à parler du fil d'actualité Mastodon (capacité
    non couverte), le LLM a inventé « #news », qui n'existe nulle part — un
    filet de sécurité par prompt seul (déjà en place) ne suffit pas à
    empêcher ce type d'hallucination avec ce modèle."""
    tags = set(_KNOWN_MISC_TAGS) | set(_KNOWN_MEDIA_TAGS)
    for tool in bro_tools.all_tools():
        tags.update(t.lower() for t in tool.tags)
    return tags

def _detect_hallucinated_tags(answer, known_tags):
    mentioned = {m.lower() for m in re.findall(r'#([a-zA-Zà-ÿ_][a-zA-Zà-ÿ0-9_:-]*)', answer)}
    mentioned = {m.split(":")[0] for m in mentioned}  # #rec:skill -> "rec" (variante connue)
    return mentioned - known_tags

def _conversational_reply(owner_email, text, img_url=None):
    """Réponse en langage naturel quand le message ne correspond à aucune
    commande de surveillance reconnue — pour que le canal self-DM avec BRO
    reste vivant même hors commande (BRO reste son clone numérique, jamais
    silencieux sans raison). Chaque repli ici est aussi un signal de "besoin
    non couvert" — journalisé pour l'analyse Arbor continue multi-utilisateurs."""
    _ensure_identity_templates(owner_email)
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
        "RÈGLE ABSOLUE : en écrivant cette réponse tu ne configures et n'exécutes RIEN, "
        "même si le message ressemble à une commande valide. Si l'utilisateur demande une "
        "action (apprendre depuis un compte, activer/désactiver une surveillance, "
        "mémoriser...), interdiction d'employer 'je commence', 'j'ai bien noté', 'je vais "
        "m'en occuper' ou toute formule qui prétend que c'est fait ou en cours — dis-lui "
        "EXACTEMENT quelle phrase envoyer pour que ce soit réellement exécuté.\n"
        "Mauvais exemple (INTERDIT) : « Je commence à apprendre du compte @x »\n"
        "Bon exemple : « Pour que j'apprenne vraiment de @x, écris : apprends mon style "
        "depuis @x »\n\n"
        f"Message de l'utilisateur :\n{wrap_untrusted('user_message', text)}\n"
        "Réponds brièvement (3-5 lignes max), en français, de façon chaleureuse et directe."
    )
    _t0 = time.monotonic()
    try:
        result = subprocess.run(
            ["python3", f"{BRO_IA_PATH}/question.py", prompt,
             "--user-id", owner_email, "--slot", str(BRO_MEMORY_SLOT),
             "--temperature", "0.4", "--max-tokens", "300", "--ctx", "8192"],
            capture_output=True, text=True, timeout=45,
        )
        answer = result.stdout.strip()
    except Exception:
        answer = ""
    observability.log_event(owner_email, "conversational_llm", "zero_shot_reply",
                             success=bool(answer), latency_ms=(time.monotonic() - _t0) * 1000)
    answer = answer or "Je n'ai pas bien compris — dites-moi par exemple « désactive mastodon.social »."

    # Garde-fou post-génération : le prompt interdit déjà d'inventer une
    # commande (voir _bro_capabilities_description), mais l'incident réel
    # ci-dessus montre que l'instruction seule ne suffit pas avec ce modèle —
    # une vérification factuelle après coup, pas seulement une consigne.
    hallucinated = _detect_hallucinated_tags(answer, _known_hashtags())
    if hallucinated:
        print(f"[BRO_WATCH] ⚠️ Commande(s) hallucinée(s) dans la réponse conversationnelle "
              f"pour {owner_email} : {sorted(hallucinated)} — remplacement par un repli honnête.")
        observability.log_event(owner_email, "conversational_llm", "hallucinated_tag",
                                 success=False, extra={"tags": sorted(hallucinated)})
        answer = ("Je ne sais pas encore faire précisément ce que tu demandes — envoie #help "
                  "pour voir la liste exacte de mes commandes réelles.")

    # Marqueur BOT_REPLY_MARKERS obligatoire (voir sa définition) : sans lui,
    # cette réponse serait relue comme un nouveau message au prochain cycle.
    if not answer.startswith(BOT_REPLY_MARKERS):
        answer = f"💬 {answer}"
    _log_tool_request(owner_email, text, answer)
    _remember_exchange(owner_email, text, answer)
    return answer

def classify_request_complexity(text):
    """Classification MINIMAL/ALGORITHM d'une requête en langage libre — un
    seul appel LLM fermé (--format-json), même pattern que
    interpret_command_with_context (subprocess vers question.py, modèle de
    classification partagé). MINIMAL : une réponse directe zero-shot suffit.
    ALGORITHM : la requête implique plusieurs actions distinctes et
    séquentielles (chercher PUIS résumer, comparer PUIS conclure...) qui
    bénéficient d'être découpées et tracées (voir algorithm_planner.py).
    Dégradation sûre : toute erreur (timeout, JSON invalide, modèle absent)
    retombe sur MINIMAL — ne jamais bloquer une réponse simple derrière une
    classification ratée."""
    prompt = (
        "Un utilisateur envoie ce message à un assistant IA personnel :\n"
        f"{wrap_untrusted('user_message', text)}\n\n"
        "Ce message nécessite-t-il PLUSIEURS actions distinctes et séquentielles "
        "(ex: rechercher une information PUIS la résumer, comparer plusieurs "
        "options PUIS conclure) ? Ou une réponse directe suffit-elle ?\n\n"
        "Réponds UNIQUEMENT en JSON, sans texte autour, avec exactement ces "
        'champs : {"mode": "MINIMAL"|"ALGORITHM", "steps": ["étape 1", "étape 2"]}\n'
        "Si mode=MINIMAL, steps doit être un tableau vide []. "
        "Si mode=ALGORITHM, liste 2 à 4 étapes courtes et concrètes, dans l'ordre "
        "d'exécution. Ne choisis ALGORITHM que si une vraie décomposition en "
        "étapes indépendantes apporte de la valeur — dans le doute, choisis MINIMAL."
    )
    try:
        result = subprocess.run([
            "python3", f"{BRO_IA_PATH}/question.py", prompt,
            "--temperature", "0.1", "--model", COMMAND_INTERPRETATION_MODEL,
            "--format-json",
        ], capture_output=True, text=True, timeout=30)
        data = json.loads(result.stdout.strip())
        mode = data.get("mode")
        steps = data.get("steps") or []
        if mode == "ALGORITHM" and isinstance(steps, list) and 2 <= len(steps) <= 6:
            return {"mode": "ALGORITHM", "steps": [str(s) for s in steps]}
    except Exception:
        pass
    return {"mode": "MINIMAL", "steps": []}

def _run_algorithm_step(step, plan, owner_email):
    """step_executor pour algorithm_planner.run_plan() : tente d'abord un
    outil Arbor enregistré (même détection sémantique que
    _try_registered_tools), sinon un appel LLM générique avec le contexte des
    étapes déjà terminées. Volontairement PAS les tags système (#mem/#reset/
    ...) : ils ont des effets de bord (reset mémoire, etc.) qui n'ont pas de
    sens comme étape d'un plan déclenché automatiquement par classification."""
    description = step["description"]
    match = match_tool(description)
    if match:
        module_name, _score = match
        # Contexte complet plutôt que la seule description de l'étape :
        # classify_request_complexity (décomposition LLM) ne répète pas
        # toujours dans chaque étape les entités déjà présentes dans la
        # requête initiale (ex: "Vérifie la météo à Lyon et Marseille" peut
        # devenir ["Météo ville 1", "Météo ville 2", "Compare"] sans que les
        # noms de ville réapparaissent) — l'outil (contrat run(query:str),
        # extraction heuristique dans son propre code) a besoin du même
        # niveau de contexte que le repli LLM ci-dessous, pas seulement du
        # texte de l'étape isolée.
        tool_query = (f"{plan['text']}\n\nÉtape à réaliser : {description}"
                      if plan.get("text") else description)
        result = _call_tool(module_name, tool_query, owner_email)
        if result:
            return True, result
    done_steps = [s for s in plan["steps"] if s["status"] == "done"]
    context_block = ""
    if done_steps:
        context_lines = "\n".join(f"- {s['description']} : {s['result']}" for s in done_steps)
        context_block = f"Contexte des étapes déjà réalisées :\n{context_lines}\n\n"
    prompt = (
        f"Requête initiale de l'utilisateur : {plan['text']}\n\n"
        f"{context_block}"
        f"Étape à réaliser maintenant : {description}\n\n"
        "Réponds de façon concise et factuelle, uniquement le résultat de cette étape."
    )
    try:
        result = subprocess.run(
            ["python3", f"{BRO_IA_PATH}/question.py", prompt,
             "--temperature", "0.3", "--max-tokens", "400", "--ctx", "8192"],
            capture_output=True, text=True, timeout=60,
        )
        answer = result.stdout.strip()
        return bool(answer), (answer or "Aucune réponse générée.")
    except Exception as e:
        return False, f"Erreur : {e}"

def _format_step_result(step):
    if step["status"] == "done":
        return f"- {step['description']} : {step['result']}"
    return f"- {step['description']} : (échec — {step['result']})"

def _synthesize_algorithm_answer(owner_email, plan):
    """Dernier appel LLM du plan : transforme les résultats bruts de chaque
    étape en une réponse unique adressée à l'utilisateur, plutôt que de lui
    exposer le détail interne du plan."""
    steps_summary = "\n".join(_format_step_result(s) for s in plan["steps"])
    prompt = (
        f"Demande initiale de l'utilisateur : {plan['text']}\n\n"
        f"Résultats des étapes réalisées :\n{steps_summary}\n\n"
        "Rédige une réponse finale synthétique (5-8 lignes max), en français, "
        "directement adressée à l'utilisateur — pas de méta-commentaire sur le "
        "fait d'avoir suivi un plan en plusieurs étapes."
    )
    try:
        result = subprocess.run(
            ["python3", f"{BRO_IA_PATH}/question.py", prompt,
             "--user-id", owner_email, "--slot", str(BRO_MEMORY_SLOT),
             "--temperature", "0.4", "--max-tokens", "400", "--ctx", "8192"],
            capture_output=True, text=True, timeout=45,
        )
        answer = result.stdout.strip()
    except Exception:
        answer = ""
    return answer or ("J'ai bien avancé sur ta demande mais je n'arrive pas à en faire une synthèse "
                       "claire — dis-moi si tu veux que je réessaie.")

def _run_algorithm_plan(owner_email, plan):
    """Exécute le plan (jusqu'à algorithm_planner.MAX_STEPS_PER_RUN étapes),
    synthétise la réponse finale si complet, ou renvoie un message de
    progression honnête sinon — la reprise est garantie au prochain passage
    de process_incoming_commands (voir _resume_pending_algorithm_plan), le
    plan restant "in_progress" sur disque entre-temps."""
    executor = lambda step, p: _run_algorithm_step(step, p, owner_email)
    _t0 = time.monotonic()
    complete = aplan.run_plan(plan, executor)
    if complete:
        answer = _synthesize_algorithm_answer(owner_email, plan)
        aplan.finalize_plan(plan, answer)
        success = all(s["status"] == "done" for s in plan["steps"])
        observability.log_event(owner_email, "algorithm_plan", plan["text"][:60],
                                 success=success, latency_ms=(time.monotonic() - _t0) * 1000)
        if not answer.startswith(BOT_REPLY_MARKERS):
            answer = f"💬 {answer}"
        return answer
    done = sum(1 for s in plan["steps"] if s["status"] != "pending")
    total = len(plan["steps"])
    return (f"📋 Je travaille encore sur ta demande ({done}/{total} étapes faites) — "
            "je vous enverrai le résultat dès que c'est prêt.")

def _resume_pending_algorithm_plan(owner_email):
    """Reprend le plan ALGORITHM le plus ancien encore inachevé pour ce
    propriétaire, s'il y en a un — appelé à chaque passage de
    process_incoming_commands (même point d'ancrage que
    check_proactive_alerts), donc y compris après un crash/redémarrage du
    process qui exécutait le plan en tâche détachée : le fichier plan sur
    disque est la seule source de vérité, jamais d'état en mémoire perdu."""
    plan = aplan.find_incomplete_plan(owner_email)
    if not plan:
        return
    answer = _run_algorithm_plan(owner_email, plan)
    send_dm_to_owner(owner_email, answer, ttl_days=1,
                      ttl_seconds=TTL_PROGRESS_SEC if _PROGRESS_MARKER in answer else None)

def _dispatch_conversational_reply(owner_email, text, img_url=None):
    """Lance _conversational_reply en tâche détachée — dernier repli restant
    qui pouvait bloquer process_incoming_commands (description d'image ~90s
    + génération LLM ~45s, jusqu'à ~135s cumulés). Même remède, pour la même
    raison, que le scraper/#craft/#badge/médias : un appel synchrone de
    plusieurs dizaines de secondes à plusieurs minutes a déjà causé une
    boucle de rejeu massive le 2026-07-03. _conversational_reply journalise/
    mémorise déjà l'échange elle-même (voir sa fin) — inchangée, seul le
    mode d'appel change."""
    try:
        payload = json.dumps({"text": text, "img_url": img_url or ""})
        subprocess.Popen(
            ["python3", os.path.abspath(__file__), "run-conversation-background", owner_email, payload],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        print(f"[BRO_WATCH] Échec du lancement de la réponse conversationnelle : {e}")
        return "🤔 Je n'ai pas pu traiter votre message, réessayez."
    return "🤔 Je réfléchis à votre message, je vous réponds dans un instant…"

def _run_conversation_background(owner_email, payload):
    """Exécute réellement la réponse (appelé en sous-processus détaché par
    _dispatch_conversational_reply) et notifie le résultat par DM. Classifie
    d'abord MINIMAL/ALGORITHM (voir classify_request_complexity) : le mode
    ALGORITHM crée un plan tracé et résilient (algorithm_planner.py) plutôt
    qu'une unique réponse zero-shot."""
    text = payload.get("text", "")
    img_url = payload.get("img_url") or None
    classification = classify_request_complexity(text)
    if classification["mode"] == "ALGORITHM":
        plan = aplan.new_plan(owner_email, text, classification["steps"])
        answer = _run_algorithm_plan(owner_email, plan)
        _log_tool_request(owner_email, text, answer)
        _remember_exchange(owner_email, text, answer)
    else:
        answer = _conversational_reply(owner_email, text, img_url)
    send_dm_to_owner(owner_email, answer, ttl_days=1,
                      ttl_seconds=TTL_PROGRESS_SEC if _PROGRESS_MARKER in answer else None)

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

    # "#arbor <description>" (besoin explicite après le tag, distinct de
    # "#arbor" seul ci-dessus) -> forge d'un NOUVEL outil, pas l'auto-
    # amélioration du prompt d'interprétation (mécanisme différent, voir
    # _trigger_arbor_tool_forge). Incident réel (2026-07-06) :
    # "#arbor ajouter la possibilité de..." tombait dans le vide, aucun des
    # deux mécanismes Arbor ne le reconnaissait, repli conversationnel
    # trompeur (l'IA a improvisé une commande #watch inexacte à la place).
    if lowered.startswith("#arbor "):
        if not _is_captain(owner_email):
            return "🔒 La forge d'outils est réservée au capitaine de la station."
        need_description = text.strip()[len("#arbor "):].strip()
        if not need_description:
            return ("🤔 Décris le besoin après #arbor, par exemple "
                     "« #arbor récupérer mon fil Mastodon à la demande ».")
        return _trigger_arbor_tool_forge(owner_email, need_description)

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
    # #rec:<skill>/#mem:<skill> testés EN PREMIER : syntaxe plus spécifique
    # que #rec/#mem simples, avec laquelle elle chevaucherait sinon (cf.
    # commentaire sur _detect_skill_tag).
    explicit_tag = _detect_skill_tag(text) or _detect_system_tag(text)
    # Incident réel (2026-07-06) : "#learn_from @qoop" (hashtag valide dans
    # l'esprit — cf. la syntaxe #watch DOMAINE CANAL learn_from @compte —
    # mais tapé sans le préfixe requis) n'a matché aucun tag exact, puis
    # match_intent() a "deviné" 'help' avec une marge de 0.06 (à peine
    # au-dessus du seuil 0.05, essentiellement du bruit) — mauvaise commande
    # exécutée avec confiance. match_intent() est calibré pour du LANGAGE
    # NATUREL sans hashtag ; un message qui COMMENCE PAR # est une tentative
    # de syntaxe explicite — s'il ne correspond à aucun tag exact, la bonne
    # réponse est "je ne reconnais pas ce tag" (repli #watch/#oublie puis
    # conversationnel honnête), jamais une devinette sémantique.
    looks_like_hashtag_attempt = text.strip().startswith("#")
    intent_target = explicit_tag or (
        None if looks_like_hashtag_attempt else (match_intent(text) or (None,))[0]
    )
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

    tool_result = _try_registered_tools(owner_email, text)
    if tool_result:
        if not tool_result.startswith(BOT_REPLY_MARKERS):
            tool_result = f"💬 {tool_result}"
        return tool_result

    return _dispatch_conversational_reply(owner_email, text, img_url)

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
    skipped_bot_origin = 0
    skipped_decrypt_fail = 0
    skipped_dedup = 0
    for ev in sorted(events, key=lambda e: e.get("created_at", 0)):
        # Filtre anti-boucle PRIMAIRE : tag structurel BRO_ORIGIN_TAG sur
        # l'event brut, avant tout déchiffrement — ne dépend pas du contenu,
        # ne peut pas confondre un vrai message utilisateur avec une réponse
        # de BRO (contrairement à un préfixe emoji, cf. incident du 2026-07-03
        # où des centaines de réponses ont été générées en boucle).
        if list(BRO_ORIGIN_TAG) in ev.get("tags", []):
            skipped_bot_origin += 1
            continue
        ev_id = ev.get("id")
        try:
            text = _decrypt_self_dm(owner_email, ev)
            if not text or text.strip().startswith(BOT_REPLY_MARKERS):
                skipped_decrypt_fail += 1
                continue  # échec de déchiffrement, ou repli pour events sans le tag (legacy)
            # Réservation ATOMIQUE juste avant l'exécution — voir
            # _claim_event_id pour l'incident réel qui a motivé ce mécanisme
            # (fichier marker O_EXCL, pas un JSON read-modify-write).
            if ev_id and not _claim_event_id(owner_email, ev_id):
                skipped_dedup += 1
                continue  # un autre passage a déjà réservé cet event
            reply = _handle_command_text(owner_email, text)
            if reply:
                handled += 1
                # Messages "en cours" (progression différée) : TTL court (NIP-40)
                # pour qu'ils disparaissent du UI dès que le résultat réel arrive.
                is_progress = _PROGRESS_MARKER in reply or _THINKING_MARKER in reply
                if send_dm_to_owner(owner_email, reply, ttl_days=1,
                                     ttl_seconds=TTL_PROGRESS_SEC if is_progress else None):
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

    manifest = _load_manifest(owner_email)
    manifest.setdefault(COMMAND_LAST_CHECK_KEY, {})["last_check"] = now_ts
    _save_manifest(owner_email, manifest)

    if handled:
        print(f"[BRO_WATCH] {handled} commande(s) traitée(s) pour {owner_email}.")
    elif events:
        # Visibilité totale sur un cycle "silencieux" — sans cette ligne, un
        # event reçu mais filtré (bot-echo, échec déchiffrement, doublon déjà
        # traité) est indiscernable d'un vrai bug (incident réel du
        # 2026-07-06 : un message resté sans réponse a nécessité une
        # investigation manuelle du code, faute de toute trace ici).
        print(f"[BRO_WATCH] {len(events)} event(s) reçu(s) pour {owner_email}, 0 traité "
              f"(bot_origin={skipped_bot_origin}, decrypt_fail={skipped_decrypt_fail}, "
              f"dedup={skipped_dedup})")

    _cleanup_old_command_markers()
    check_proactive_alerts(owner_email)
    _resume_pending_algorithm_plan(owner_email)

PROACTIVE_ALERTS_FILENAME = ".proactive_alerts.json"

PROACTIVE_ALERT_COOLDOWN_SEC = 86400  # 1 alerte max par jour et par type

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

def _load_active_goals(owner_email):
    """Objectifs actifs (non cochés) déclarés par le capitaine dans
    identity/.Objectifs.md — commentaires HTML retirés (même convention que
    question.py::load_identity, pour qu'un template vierge ne compte pas
    comme un objectif)."""
    path = os.path.join(_owner_dir(owner_email), "identity", ".Objectifs.md")
    if not os.path.isfile(path):
        return []
    try:
        with open(path, encoding="utf-8") as f:
            content = re.sub(r"<!--.*?-->", "", f.read(), flags=re.DOTALL)
    except Exception:
        return []
    goals = []
    for line in content.splitlines():
        match = re.match(r"^\s*-\s*\[\s*\]\s*(.+)$", line)
        if match:
            goals.append(match.group(1).strip())
    return goals

def _check_goal_drift(owner_email):
    """Détecteur : le premier objectif actif (identity/.Objectifs.md) sans
    aucune trace dans la mémoire récente (recherche sémantique Qdrant, slot
    self-DM) — signal qu'il a été déclaré puis oublié. Volontairement sans
    appel LLM supplémentaire : la recherche sémantique déjà utilisée par
    _conversational_reply suffit à détecter l'absence totale de lien, et
    reste déterministe (pas de jugement LLM à faire confirmer). Dégradation
    silencieuse si aucun objectif n'est déclaré ou si Qdrant est indisponible
    (_recall_relevant_memories renvoie alors "" — traité comme "rien trouvé",
    donc l'objectif serait signalé à tort ; acceptable car le cooldown de
    24h limite le bruit et le capitaine peut cocher/retirer l'objectif)."""
    for goal in _load_active_goals(owner_email):
        if not _recall_relevant_memories(owner_email, goal, limit=1):
            return (f"Tu avais noté cet objectif : « {goal} ». On n'en a pas reparlé "
                     "récemment — tu veux qu'on avance dessus ?")
    return None

PROACTIVE_ALERT_DETECTORS = {
    "low_g1_balance": _check_low_g1_balance,
    "goal_drift": _check_goal_drift,
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
            observability.log_event(owner_email, alert_type, "proactive_alert_check", success=False)
            continue
        if message:
            sent = send_dm_to_owner(owner_email, f"🔔 {message}", ttl_days=3)
            observability.log_event(owner_email, alert_type, "proactive_alert_sent", success=bool(sent))
            if sent:
                state[alert_type] = now
                fired.append(alert_type)
                print(f"[BRO_WATCH] Alerte proactive '{alert_type}' envoyée à {owner_email}")

    if fired:
        _save_proactive_alert_state(owner_email, state)
    return fired

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

    elif len(sys.argv) >= 4 and sys.argv[1] == "add-tool-examples":
        # Backfill des paraphrases de routage pour un outil déjà actif — ex :
        # python3 bro_watch_core.py add-tool-examples tool_meteo "quel temps fait-il à Lyon ?|météo à Marseille demain"
        # Séparateur '|' : les exemples peuvent contenir des espaces, jamais des '|'.
        module_name = sys.argv[2]
        examples = [e.strip() for e in sys.argv[3].split("|") if e.strip()]
        ok_, msg = add_tool_examples(module_name, examples)
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

    elif len(sys.argv) >= 2 and sys.argv[1] == "describe-tools":
        # Pont bash <-> registre bro_tools : permet à un autre canal (ex.
        # UPlanet_IA_Responder.sh) de générer son texte d'aide depuis la MÊME
        # source de vérité que le self-DM, plutôt que de maintenir sa propre
        # doc statique séparée (cause structurelle de la divergence du
        # 2026-07-03). EMAIL optionnel : sans lui, #arbor n'est pas listé
        # (statut capitaine non vérifiable hors contexte owner).
        email = sys.argv[2] if len(sys.argv) > 2 else ""
        print(_bro_capabilities_description(email))
        sys.exit(0)

    elif len(sys.argv) >= 6 and sys.argv[1] == "run-scraper-background":
        # Point d'entrée du sous-processus détaché lancé par _run_scraper_now —
        # jamais appelé directement par un humain.
        _, _, email, domain, script, cookie_file = sys.argv[:6]
        _run_scraper_background(email, domain, script, cookie_file)
        sys.exit(0)

    elif len(sys.argv) >= 4 and sys.argv[1] == "run-craft-background":
        # Point d'entrée du sous-processus détaché lancé par _tool_craft —
        # jamais appelé directement par un humain.
        _, _, email, url = sys.argv[:4]
        _run_craft_background(email, url)
        sys.exit(0)

    elif len(sys.argv) >= 4 and sys.argv[1] == "run-badge-background":
        # Point d'entrée du sous-processus détaché lancé par _tool_badge —
        # jamais appelé directement par un humain.
        _, _, email, skill = sys.argv[:4]
        _run_badge_background(email, skill)
        sys.exit(0)

    elif len(sys.argv) >= 5 and sys.argv[1] == "run-media-background":
        # Point d'entrée du sous-processus détaché lancé par
        # _dispatch_media_background (#image/#video/#music/#plant/#inventory/
        # #pierre/#amelie) — jamais appelé directement par un humain.
        _, _, media_type, email, payload_json = sys.argv[:5]
        _run_media_background(media_type, email, json.loads(payload_json))
        sys.exit(0)

    elif len(sys.argv) >= 4 and sys.argv[1] == "run-conversation-background":
        # Point d'entrée du sous-processus détaché lancé par
        # _dispatch_conversational_reply — jamais appelé directement par un humain.
        _, _, email, payload_json = sys.argv[:4]
        _run_conversation_background(email, json.loads(payload_json))
        sys.exit(0)

    elif len(sys.argv) >= 4 and sys.argv[1] == "run-identity-check-background":
        # Point d'entrée du sous-processus détaché lancé par
        # _dispatch_identity_update_check (#rec) — jamais appelé directement par un humain.
        _, _, email, content = sys.argv[:4]
        _check_and_update_identity(email, content)
        sys.exit(0)

    elif len(sys.argv) >= 5 and sys.argv[1] == "run-skill-notify-background":
        # Point d'entrée du sous-processus détaché lancé par
        # _notify_captain_skill_contribution (#rec:<skill>) — jamais appelé
        # directement par un humain.
        _, _, email, skill, content = sys.argv[:5]
        _run_skill_notify_background(email, skill, content)
        sys.exit(0)

    else:
        print("Usage:")
        print("  python3 bro_watch_core.py store-log EMAIL ACCOUNT LOGFILE")
        print("  python3 bro_watch_core.py is-enabled EMAIL ACCOUNT")
        print("  python3 bro_watch_core.py check-commands EMAIL")
        print("  python3 bro_watch_core.py get-channels EMAIL ACCOUNT")
        print("  python3 bro_watch_core.py activate-tool MODULE [DESCRIPTION]")
        print("  python3 bro_watch_core.py add-tool-examples MODULE \"ex1|ex2|ex3\"")
        print("  python3 bro_watch_core.py deactivate-tool MODULE")
        print("  python3 bro_watch_core.py list-tools")
        sys.exit(1)
