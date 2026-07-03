#!/usr/bin/env python3
"""
forum_watch.py — Surveillance quotidienne d'un forum Discourse (générique).

Réutilisable pour n'importe quel forum Discourse (forum.monnaie-libre.fr,
forum.duniter.org...) : appelle scraper_forum_discourse.py pour récupérer
les sujets récents (dernières 24h), puis transmet chaque sujet à
bro_watch_core.process_watch_digest() qui décide de la pertinence et
envoie un rapport de synthèse en DM NOSTR chiffré au propriétaire.

Ne publie plus de blog NOSTR (kind 30023) — remplacé par la surveillance
passive bro_watch (décision prise avec l'utilisateur).

Usage :
    python3 forum_watch.py --player EMAIL --cookie-file COOKIE \
        --forum-url https://forum.monnaie-libre.fr --seen-file SEEN.json
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import sys
import os
import json
import argparse
from urllib.parse import urlparse

sys.path.insert(0, os.path.expanduser("~/.zen/Astroport.ONE/IA"))
import bro_watch_core
import scraper_forum_discourse as discourse

MAX_SEEN = 500
WATCH_CHANNEL = "new_topics"


def load_seen(seen_file):
    try:
        with open(seen_file) as f:
            return set(json.load(f))
    except Exception:
        return set()


def save_seen(seen_file, seen):
    os.makedirs(os.path.dirname(seen_file), exist_ok=True)
    with open(seen_file, "w") as f:
        json.dump(list(seen)[-MAX_SEEN:], f)


def main():
    parser = argparse.ArgumentParser(description="Surveillance quotidienne d'un forum Discourse.")
    parser.add_argument("--player", required=True, help="Email MULTIPASS propriétaire")
    parser.add_argument("--cookie-file", required=True)
    parser.add_argument("--forum-url", required=True, help="URL de base du forum (ex: https://forum.monnaie-libre.fr)")
    parser.add_argument("--seen-file", required=True)
    parser.add_argument("--days", type=int, default=1, help="Nombre de jours à couvrir (défaut: 1)")
    args = parser.parse_args()

    owner_email = args.player
    base_url = args.forum_url.rstrip("/")
    account_id = urlparse(base_url).netloc  # ex: forum.monnaie-libre.fr

    # Traiter les commandes reçues par self-DM avant de générer le rapport du jour
    # (ex: "#watch forum.duniter.org off", "#ok" pour valider une suggestion en attente).
    bro_watch_core.process_incoming_commands(owner_email)

    bro_watch_core.ensure_watch_entry(owner_email, account_id, WATCH_CHANNEL, keywords=[])

    session = discourse.read_cookie_from_file(args.cookie_file, account_id)
    posts = discourse.get_today_posts(session, base_url, days_back=args.days)

    print(f"[FORUM] {len(posts)} sujet(s) récent(s) trouvé(s) sur {account_id}")

    seen = load_seen(args.seen_file)
    items = []
    for p in posts:
        key = p.get("url") or str(p.get("id"))
        if not key or key in seen:
            continue
        seen.add(key)
        title = p.get("title", "")
        content = p.get("content", "")
        items.append({
            "username": p.get("author") or "Inconnu",
            "text": f"{title} — {content}"[:1000],
            "url": p.get("url"),
        })

    bro_watch_core.process_watch_digest(
        owner_email, account_id, WATCH_CHANNEL, items,
        context_label=f"Forum {account_id} — nouveaux sujets",
    )

    save_seen(args.seen_file, seen)
    print(f"[FORUM] Terminé — {len(items)} nouveau(x) sujet(s) transmis à bro_watch_core.")


if __name__ == "__main__":
    main()
