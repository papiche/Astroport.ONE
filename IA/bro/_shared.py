#!/usr/bin/env python3
"""
bro.shared — Constantes et primitives partagées (chemins owner, relais) — aucune dépendance vers les autres submodules bro.* (feuille du graphe d'imports).

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

__all__ = ['BRO_IA_PATH', 'TOOLS_PATH', 'NOSTR_DIR', 'DEFAULT_RELAY', 'DM_TTL_DAYS', '_owner_dir', '_owner_hex', '_owner_nsec', '_owner_g1_pubkey', '_load_relays', 'RELAYS', '_now_iso', 'COMMAND_INTERPRETATION_MODEL', 'BRO_WATCH_CORE_PATH']

# Chemin stable de bro_watch_core.py (le point d'entrée CLI, avec le dispatch
# des sous-commandes run-*-background) — à utiliser pour toute auto-
# réinvocation en sous-processus détaché DEPUIS un submodule bro.*, où
# `os.path.abspath(__file__)` pointerait à tort vers ce submodule lui-même
# (ex: bro/media.py) au lieu de bro_watch_core.py qui porte le "if __name__ ==
# '__main__':". Voir bro.media._run_scraper_now, bro.media._dispatch_media_background,
# bro.identity._dispatch_identity_update_check, bro.tools._tool_craft/_tool_badge.
BRO_WATCH_CORE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bro_watch_core.py"
)

BRO_IA_PATH = os.path.expanduser("~/.zen/Astroport.ONE/IA")

TOOLS_PATH = os.path.expanduser("~/.zen/Astroport.ONE/tools")

NOSTR_DIR = os.path.expanduser("~/.zen/game/nostr")

DEFAULT_RELAY = "wss://relay.copylaradio.com"

DM_TTL_DAYS = 7

def _owner_dir(owner_email):
    return os.path.join(NOSTR_DIR, owner_email)

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

def _now_iso():
    import datetime
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

COMMAND_INTERPRETATION_MODEL = "qwen2.5-coder:14b"
