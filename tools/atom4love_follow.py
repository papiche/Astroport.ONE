#!/usr/bin/env python3
"""
atom4love_follow.py — Met à jour la liste de contacts (kind 3, NIP-02) de la
clé LOVE (.secret.love) : ajoute/retire un pubkey suivi.

Interroge d'abord le relay local (strfry scan) pour récupérer le dernier
event kind 3 de la clé LOVE — source de vérité, aucun cache local qui
pourrait diverger du relay (même principe que nostr_follow.sh, la version
générique pour la clé NOSTR principale). Republie ensuite la liste complète
avec le pubkey ajouté/retiré, en chargeant le nsec depuis le keyfile
.secret.love plutôt que de le recevoir en argument — jamais de clé privée
en clair sur la ligne de commande (visible dans `ps`).

Usage:
    atom4love_follow.py EMAIL ACTION TARGET_HEX
    ACTION: add | remove
"""
import sys
import os
import json
import subprocess

MY_PATH = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, MY_PATH)

from nostr_send_note import send_nostr_event, load_keyfile  # noqa: E402


def _fail(error: str, extra: dict | None = None) -> None:
    payload = {"published": False, "error": error}
    if extra:
        payload.update(extra)
    print(json.dumps(payload))
    sys.exit(1)


def _strfry_scan(filter_json: str) -> list[dict]:
    strfry_dir = os.path.expanduser("~/.zen/strfry")
    strfry_bin = os.path.join(strfry_dir, "strfry")
    if not os.path.exists(strfry_bin):
        return []
    try:
        out = subprocess.run([strfry_bin, "scan", filter_json], cwd=strfry_dir,
                              capture_output=True, text=True, timeout=15, check=True)
    except Exception:
        return []
    events = []
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def main() -> None:
    if len(sys.argv) < 4:
        print("Usage: atom4love_follow.py EMAIL ACTION TARGET_HEX", file=sys.stderr)
        sys.exit(1)

    email = sys.argv[1]
    action = sys.argv[2].strip().lower()
    target_hex = sys.argv[3].strip().lower()

    if action not in ("add", "remove"):
        _fail("INVALID_ACTION")
        return
    if len(target_hex) != 64:
        _fail("INVALID_TARGET_HEX")
        return

    love_keyfile = os.path.expanduser(f"~/.zen/game/nostr/{email}/.secret.love")
    if not os.path.exists(love_keyfile):
        _fail("LOVE_KEY_NOT_FOUND")
        return

    try:
        nsec = load_keyfile(love_keyfile, silent=True)
    except Exception as e:
        _fail("KEYFILE_LOAD_FAILED", {"detail": str(e)})
        return

    from pynostr.key import PrivateKey
    source_hex = PrivateKey.from_nsec(nsec).public_key.hex()

    existing_events = _strfry_scan(json.dumps({"kinds": [3], "authors": [source_hex]}))
    existing_hexes: list[str] = []
    if existing_events:
        newest = max(existing_events, key=lambda e: e.get("created_at", 0))
        existing_hexes = [t[1] for t in newest.get("tags", [])
                           if len(t) >= 2 and t[0] == "p"]

    if action == "add":
        if target_hex not in existing_hexes:
            existing_hexes.append(target_hex)
    else:
        existing_hexes = [h for h in existing_hexes if h != target_hex]

    tags = [["p", h] for h in existing_hexes]
    publish_result = send_nostr_event(love_keyfile, "", tags=tags, kind=3, json_output=True)

    print(json.dumps({
        "published": bool(publish_result.get("success")),
        "email": email,
        "action": action,
        "target_hex": target_hex,
        "follow_count": len(existing_hexes),
    }))


if __name__ == "__main__":
    main()
