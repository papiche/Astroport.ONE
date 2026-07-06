#!/usr/bin/env python3
"""
bro.watch_store — Persistance de la config de surveillance (manifest cookie chiffré, republié en NOSTR kind 31903) et des logs de scraper.

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
from bro._shared import TOOLS_PATH, _load_relays, _owner_dir
from bro.nostr import _natools_decrypt, _natools_encrypt

__all__ = ['MANIFEST_FILENAME', 'MANIFEST_NOSTR_KIND', 'MANIFEST_NOSTR_DTAG', '_manifest_path', '_load_manifest', '_save_manifest', '_publish_manifest_to_nostr', 'store_log', 'get_log', 'is_scraper_enabled', 'set_scraper_enabled', 'load_watch_data', 'save_watch_data', 'load_watch_list', 'get_watch_entry', 'update_watch_entry', 'ensure_watch_entry']



MANIFEST_FILENAME = ".cookie_manifest.json"

MANIFEST_NOSTR_KIND = 31903

MANIFEST_NOSTR_DTAG = "cookies"

def _manifest_path(owner_email):
    return os.path.join(_owner_dir(owner_email), MANIFEST_FILENAME)

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

def is_scraper_enabled(owner_email, account):
    manifest = _load_manifest(owner_email)
    return manifest.get(account, {}).get("enabled", True)

def set_scraper_enabled(owner_email, account, enabled):
    manifest = _load_manifest(owner_email)
    manifest.setdefault(account, {})["enabled"] = bool(enabled)
    _save_manifest(owner_email, manifest)

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
