#!/usr/bin/env python3
"""
bro_user_level.py — Détermine le niveau d'accès BRO d'un expéditeur NOSTR.

Niveaux :
  0  anonyme      : aucun MULTIPASS local sur cette station
  1  locataire    : MULTIPASS hébergé (contract_status active_rental)
  2  atome        : locataire + profil atom4love valide (Kind 30078 d=atom4love)
  3  satellite    : sociétaire satellite (cooperative_member_satellite) — sans IA
  4  constellation: sociétaire constellation (cooperative_member_constellation) — avec IA
  5  capitaine    : accès complet (astroport_captain)

Usage : python3 bro_user_level.py <sender_hex> [relay_url]
Output : JSON sur stdout — {"level": N, "email": "...", "contract_status": "...", "atom4love": bool}

Atom4love cache : ~/.zen/tmp/bro_level/<sender_hex>.a4l (TTL 3600s)
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys, os as _os
_venv = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv) and _sys.executable != _venv:
    _os.execv(_venv, [_venv] + _sys.argv)
del _sys, _os

import sys
import os
import json
import time
import hashlib

HOME = os.path.expanduser("~")
NOSTR_DIR  = os.path.join(HOME, ".zen", "game", "nostr")
CACHE_DIR  = os.path.join(HOME, ".zen", "tmp", "bro_level")
A4L_TTL    = 3600   # 1h cache atom4love
LEVEL_TTL  = 300    # 5 min cache niveau global

# Correspondance contract_status → niveau de base
_CONTRACT_LEVEL = {
    "astroport_captain":                5,
    "cooperative_member_constellation": 4,
    "cooperative_member_satellite":     3,
    "active_rental":                    1,
}


# ── Résolution email ─────────────────────────────────────────────────────────

def resolve_email(sender_hex: str) -> str:
    """Cherche l'email associé au hex dans ~/.zen/game/nostr/*/HEX."""
    if not os.path.isdir(NOSTR_DIR):
        return ""
    for entry in os.scandir(NOSTR_DIR):
        if not entry.is_dir():
            continue
        hex_path = os.path.join(entry.path, "HEX")
        try:
            with open(hex_path) as f:
                if f.read().strip() == sender_hex:
                    return entry.name
        except OSError:
            continue
    return ""


# ── DID cache ────────────────────────────────────────────────────────────────

def get_contract_status(email: str) -> str:
    """Lit .metadata.contractStatus dans did.json.cache. Retourne '' si absent."""
    did_path = os.path.join(NOSTR_DIR, email, "did.json.cache")
    try:
        with open(did_path) as f:
            did = json.load(f)
        return did.get("metadata", {}).get("contractStatus", "") or ""
    except (OSError, json.JSONDecodeError):
        return ""


def is_society_active(email: str) -> bool:
    """Vérifie que U.SOCIETY.end n'est pas expiré (format YYYY-MM-DD)."""
    end_path = os.path.join(NOSTR_DIR, email, "U.SOCIETY.end")
    try:
        with open(end_path) as f:
            end_str = f.read().strip()
        if end_str == "9999-12-31":
            return True
        end_ts = time.mktime(time.strptime(end_str, "%Y-%m-%d"))
        return time.time() < end_ts
    except (OSError, ValueError):
        return True  # si pas de fichier expiry, on fait confiance au DID


# ── Atom4love via relay ───────────────────────────────────────────────────────

def _a4l_cache_path(sender_hex: str) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    return os.path.join(CACHE_DIR, f"{sender_hex}.a4l")


def _a4l_from_cache(sender_hex: str) -> tuple:
    """Retourne (found: bool, ts: float) depuis le cache disque, ou (None, 0) si expiré/absent."""
    p = _a4l_cache_path(sender_hex)
    try:
        age = time.time() - os.path.getmtime(p)
        if age > A4L_TTL:
            return None, 0
        with open(p) as f:
            data = json.load(f)
        return data.get("found", False), data.get("ts", 0)
    except (OSError, json.JSONDecodeError):
        return None, 0


def _a4l_write_cache(sender_hex: str, found: bool):
    p = _a4l_cache_path(sender_hex)
    try:
        with open(p, "w") as f:
            json.dump({"found": found, "ts": time.time()}, f)
    except OSError:
        pass


def _verify_a4l_proof(sender_hex: str, event: dict) -> bool:
    """Vérifie que l'event Kind 30078 contient un a4l_proof valide."""
    tags = event.get("tags", [])
    # Chercher le tag a4l_proof
    proof = next((t[1] for t in tags if len(t) >= 2 and t[0] == "a4l_proof"), None)
    if not proof:
        return False
    # sha256(pubkey + ':' + 'ATOM4LOVE_ALPHA') — sel standard (AUTHORIZED_APPS)
    expected = hashlib.sha256(f"{sender_hex}:ATOM4LOVE_ALPHA".encode()).hexdigest()
    return proof == expected


def check_atom4love(sender_hex: str, relay_url: str) -> bool:
    """
    Requête le relay pour Kind 30078 d=atom4love de sender_hex.
    Valide le a4l_proof. Met en cache le résultat.
    """
    cached, _ = _a4l_from_cache(sender_hex)
    if cached is not None:
        return cached

    found = False
    try:
        import websocket
        ws = websocket.create_connection(relay_url, timeout=8)
        sub_id = f"a4l_{sender_hex[:8]}"
        req = json.dumps(["REQ", sub_id, {
            "kinds": [30078],
            "authors": [sender_hex],
            "#d": ["atom4love"],
            "limit": 3,
        }])
        ws.send(req)
        deadline = time.time() + 8
        while time.time() < deadline:
            try:
                ws.settimeout(2.0)
                msg = ws.recv()
                data = json.loads(msg)
                if isinstance(data, list):
                    if data[0] == "EVENT" and len(data) >= 3:
                        ev = data[2]
                        if _verify_a4l_proof(sender_hex, ev):
                            found = True
                            break
                    elif data[0] == "EOSE":
                        break
            except websocket.WebSocketTimeoutException:
                break
            except Exception:
                break
        try:
            ws.send(json.dumps(["CLOSE", sub_id]))
            ws.close()
        except Exception:
            pass
    except Exception:
        # Relay indisponible → on ne pénalise pas l'utilisateur : retourner False sans cache
        return False

    _a4l_write_cache(sender_hex, found)
    return found


# ── Niveau global ─────────────────────────────────────────────────────────────

def _level_cache_path(sender_hex: str) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    return os.path.join(CACHE_DIR, f"{sender_hex}.level")


def _level_from_cache(sender_hex: str):
    p = _level_cache_path(sender_hex)
    try:
        age = time.time() - os.path.getmtime(p)
        if age > LEVEL_TTL:
            return None
        with open(p) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def _level_write_cache(sender_hex: str, result: dict):
    p = _level_cache_path(sender_hex)
    try:
        with open(p, "w") as f:
            json.dump(result, f)
    except OSError:
        pass


def get_user_level(sender_hex: str, relay_url: str) -> dict:
    """Retourne le niveau d'accès BRO complet pour sender_hex."""
    cached = _level_from_cache(sender_hex)
    if cached is not None:
        return cached

    email = resolve_email(sender_hex)
    if not email:
        result = {"level": 0, "email": "", "contract_status": "anonymous", "atom4love": False}
        _level_write_cache(sender_hex, result)
        return result

    contract_status = get_contract_status(email)

    # Niveau de base depuis le contrat
    base_level = 0
    for status, lvl in _CONTRACT_LEVEL.items():
        if contract_status == status:
            base_level = lvl
            break
    # Locataire minimal si email trouvé mais contract_status inconnu
    if base_level == 0 and email:
        base_level = 1

    # Vérifier expiration société
    if base_level in (3, 4) and not is_society_active(email):
        base_level = 1  # Subscription expirée → retour locataire

    # Atom4love : locataire → atome si Kind 30078 présent et valide
    atom4love = False
    if base_level == 1:
        atom4love = check_atom4love(sender_hex, relay_url)
        if atom4love:
            base_level = 2
    elif base_level >= 3:
        # Pour satellite/constellation, on note l'atom4love mais ça ne change pas le niveau
        atom4love = True  # Présumé : constellation implique le flux complet

    result = {
        "level": base_level,
        "email": email,
        "contract_status": contract_status,
        "atom4love": atom4love,
    }
    _level_write_cache(sender_hex, result)
    return result


# ── CLI ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print('{"level": 0, "error": "usage: bro_user_level.py <sender_hex> [relay_url]"}')
        sys.exit(1)

    sender_hex = sys.argv[1].strip().lower()
    relay_url  = sys.argv[2].strip() if len(sys.argv) >= 3 else "ws://127.0.0.1:7777"

    result = get_user_level(sender_hex, relay_url)
    print(json.dumps(result, ensure_ascii=False))
