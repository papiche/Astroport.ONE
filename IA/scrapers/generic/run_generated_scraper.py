#!/usr/bin/env python3
"""
scrapers/generic/run_generated_scraper.py — Wrapper générique pour les scrapers
générés par arbor_scraper_forge.py.

Appelé depuis le shell wrapper scrapers/<domain>/<domain>.sh avec :
    python3 run_generated_scraper.py --player EMAIL --cookie-file FILE
                                     --domain DOMAIN --module MODULE_PATH

Responsabilités :
    1. Charger le module scraper généré (importlib.util)
    2. Appeler run(cookie_file, domain) → list[dict]
    3. Passer les items à bro_watch_core.process_watch_digest()

Codes de sortie — utilisés par bro/media.py::_run_scraper_background
pour la boucle de self-healing :
    0  — succès : run() a retourné des items, rapport envoyé
    1  — exception dans run() (cookie expiré, DOM cassé, réseau)
         → déclenche l'incrément du compteur d'échecs
    2  — run() a réussi mais retourné [] (0 item ce jour)
         → décompte comme potentiel signe d'obsolescence du scraper
    3  — erreur de configuration (module introuvable, cookie absent)
         → ne déclenche PAS le compteur (erreur d'environnement, pas du scraper)
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
import importlib.util

sys.path.insert(0, os.path.expanduser("~/.zen/Astroport.ONE/IA"))
import bro_watch_core


def _load_module(module_path):
    spec = importlib.util.spec_from_file_location("_scraper_generated", module_path)
    if spec is None:
        raise ImportError(f"Impossible de charger le module : {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description="Wrapper générique scrapers Arbor")
    parser.add_argument("--player", required=True, help="Email MULTIPASS du propriétaire")
    parser.add_argument("--cookie-file", required=True)
    parser.add_argument("--domain", required=True, help="Domaine cible (ex: mastodon.social)")
    parser.add_argument("--module", required=True, help="Chemin absolu vers scraper_generated.py")
    parser.add_argument("--channel", default="feed",
                        help="Canal pour process_watch_digest (défaut: feed)")
    args = parser.parse_args()

    owner_email = args.player
    cookie_file = args.cookie_file
    domain = args.domain
    channel = args.channel

    if not os.path.isfile(args.module):
        print(f"ERROR:module_not_found:{args.module}", file=sys.stderr)
        sys.exit(3)

    if not os.path.isfile(cookie_file):
        print(f"ERROR:cookie_not_found:{cookie_file}", file=sys.stderr)
        sys.exit(3)

    # Traiter les commandes BRO en attente avant d'envoyer le rapport
    bro_watch_core.process_incoming_commands(owner_email)

    # S'assurer que l'entrée de surveillance existe pour ce domaine/canal
    bro_watch_core.ensure_watch_entry(owner_email, domain, channel, keywords=[])

    # ── Appel du scraper généré ───────────────────────────────────────────
    try:
        module = _load_module(args.module)
        items = module.run(cookie_file, domain)
    except RuntimeError as e:
        error_msg = str(e)
        print(f"ERROR:{error_msg}", file=sys.stderr)
        # cookie_expired et network_error sont des pannes scraper → exit 1 (heal trigger)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR:exception:{type(e).__name__}:{e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(items, list):
        print(f"ERROR:invalid_return_type:{type(items).__name__}", file=sys.stderr)
        sys.exit(1)

    # Normaliser : s'assurer que chaque item a username, text, url
    normalized = []
    for it in items:
        if not isinstance(it, dict):
            continue
        username = str(it.get("username") or "").strip()
        text = str(it.get("text") or "").strip()
        url = it.get("url")
        if username and text:
            normalized.append({"username": username, "text": text, "url": url})

    count = len(normalized)
    print(f"[{domain}] {count} item(s) extrait(s)")

    # ── Traitement via bro_watch_core ────────────────────────────────────
    bro_watch_core.process_watch_digest(
        owner_email, domain, channel, normalized,
        context_label=f"{domain} — {channel}",
    )

    if count == 0:
        # Exit 2 : run() a réussi sans exception mais 0 item — peut être
        # légitime (jour calme) ou signe d'obsolescence du scraper.
        # bro/media.py::_run_scraper_background décide du seuil (3 cycles).
        print(f"[{domain}] 0 item retourné (exit 2 — comptabilisé par le moniteur de santé)")
        sys.exit(2)

    print(f"[{domain}] Terminé — {count} item(s) traité(s).")
    sys.exit(0)


if __name__ == "__main__":
    main()
