#!/usr/bin/env python3
"""
bro.nostr — Canal DM NOSTR self-to-self : chiffrement seal box, envoi/réception, déduplication des commandes entrantes.

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
from bro._shared import DM_TTL_DAYS, RELAYS, TOOLS_PATH, _owner_dir, _owner_g1_pubkey, _owner_hex, _owner_nsec

__all__ = ['_natools_encrypt', '_natools_decrypt', 'BRO_ORIGIN_TAG', 'send_dm_to_owner', 'PROCESSED_COMMAND_IDS_DIR', 'PROCESSED_COMMAND_IDS_MAX_AGE_SEC', '_claim_event_id', '_cleanup_old_command_markers', '_fetch_self_dms_since', '_decrypt_self_dm']



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

BRO_ORIGIN_TAG = ["client", "bro"]

def send_dm_to_owner(owner_email, message, ttl_days=DM_TTL_DAYS, ttl_seconds=None):
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
    extra_tags = [BRO_ORIGIN_TAG]
    if ttl_seconds is not None:
        # TTL court en secondes (messages éphémères "en cours") — NIP-40 direct
        import time as _t
        extra_tags.append(["expiration", str(int(_t.time()) + int(ttl_seconds))])
        cmd = ["python3", script, "--nsec-stdin", recipient_hex, message, RELAYS[0],
               "--extra-tags", json.dumps(extra_tags)]
    else:
        cmd = ["python3", script, "--nsec-stdin", recipient_hex, message, RELAYS[0],
               "--ttl-days", str(ttl_days), "--extra-tags", json.dumps(extra_tags)]
    if len(RELAYS) > 1:
        cmd += ["--extra-relays", ",".join(RELAYS[1:])]
    try:
        proc = subprocess.run(cmd, input=nsec + "\n", capture_output=True, text=True, timeout=20)
        return proc.returncode == 0
    except Exception as e:
        print(f"[BRO_WATCH] Erreur envoi DM à {owner_email} via {RELAYS} : {e}")
        return False

PROCESSED_COMMAND_IDS_DIR = os.path.expanduser("~/.zen/tmp/bro_command_dedup")

PROCESSED_COMMAND_IDS_MAX_AGE_SEC = 7 * 86400  # nettoyage des marqueurs > 7 jours

def _claim_event_id(owner_email, ev_id):
    """Réserve atomiquement le droit de traiter cet event pour ce
    propriétaire. Retourne True si CE processus a gagné la réservation
    (jamais traité avant), False si un autre l'a déjà pris."""
    os.makedirs(PROCESSED_COMMAND_IDS_DIR, exist_ok=True)
    marker = os.path.join(PROCESSED_COMMAND_IDS_DIR,
                           f"{hashlib.sha256(owner_email.encode()).hexdigest()[:16]}_{ev_id}")
    try:
        fd = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.close(fd)
        return True
    except FileExistsError:
        return False
    except Exception:
        # Dégradation gracieuse : en cas d'erreur imprévue, ne bloque jamais
        # le traitement (mieux vaut un risque de doublon qu'un silence total).
        return True

def _cleanup_old_command_markers():
    """Purge les marqueurs de dédup plus vieux que PROCESSED_COMMAND_IDS_MAX_AGE_SEC
    — best-effort, appelée en fin de process_incoming_commands (peu coûteux,
    le dossier reste petit à l'échelle d'une station)."""
    try:
        import time as _time
        cutoff = _time.time() - PROCESSED_COMMAND_IDS_MAX_AGE_SEC
        for name in os.listdir(PROCESSED_COMMAND_IDS_DIR):
            p = os.path.join(PROCESSED_COMMAND_IDS_DIR, name)
            try:
                if os.path.getmtime(p) < cutoff:
                    os.remove(p)
            except Exception:
                pass
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
