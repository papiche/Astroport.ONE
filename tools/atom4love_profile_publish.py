#!/usr/bin/env python3
"""
atom4love_profile_publish.py — Publie le profil de rencontre (kind 30078,
d=love-profile) de la clé LOVE (.secret.love) déjà activée : bio, âge,
intérêts, photo, et visibilité publique pour le matching (#love_match, BRO).

Ne dérive JAMAIS de nouvelle clé — .secret.love doit déjà exister (créée par
atom4love_publish.py via /atom4love/activate). Réutilise nostr_send_note.py
(même mécanisme de signature+publication que le kind 30079 dream_vector).

Fusionne avec le profil local ~/.zen/flashmem/<email>/love/profile.json
(même sémantique que love_handler.sh::_love_save_profile : merge, pas
remplacement) puis republie sur NOSTR — c'est ce qui manquait jusqu'ici :
le profil édité (chat BRO ou web) restait local, jamais visible hors station.

Event kind 30078 (30000-39999) : parameterized replaceable NIP-33 — republier
avec un nouveau created_at remplace automatiquement l'ancien (relay standard).

Usage:
    atom4love_profile_publish.py EMAIL
    Payload JSON sur stdin :
        {"age": 28, "bio": "...", "interests": ["nature", "musique"], "public": true,
         "photo": "https://ipfs.../QmXXX.jpg"}

Imprime en DERNIÈRE ligne de stdout un JSON — seule sortie parsée par les
appelants (atom4love_profile.sh, UPassport routers/identity.py, love_handler.sh).
"""
import sys
import os
import json

MY_PATH = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, MY_PATH)

from nostr_send_note import send_nostr_event  # noqa: E402
import uplanet_crypto  # noqa: E402


def _fail(error: str, extra: dict | None = None) -> None:
    payload = {"published": False, "error": error}
    if extra:
        payload.update(extra)
    print(json.dumps(payload))
    sys.exit(1)


def _profile_path(email: str) -> str:
    return os.path.expanduser(f"~/.zen/flashmem/{email}/love/profile.json")


def _load_existing_profile(email: str) -> dict:
    path = _profile_path(email)
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def _save_profile(email: str, profile: dict) -> None:
    path = _profile_path(email)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(profile, f, ensure_ascii=False)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: atom4love_profile_publish.py EMAIL", file=sys.stderr)
        sys.exit(1)

    email = sys.argv[1]

    love_keyfile = os.path.expanduser(f"~/.zen/game/nostr/{email}/.secret.love")
    if not os.path.exists(love_keyfile):
        _fail("LOVE_KEY_NOT_FOUND")
        return

    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError as e:
        _fail("INVALID_PAYLOAD", {"detail": str(e)})
        return

    new_fields = {}
    if "age" in payload:
        try:
            new_fields["age"] = int(payload["age"])
        except (TypeError, ValueError):
            _fail("INVALID_AGE")
            return
    if "bio" in payload:
        new_fields["bio"] = str(payload["bio"]).strip()[:500]
    if "interests" in payload:
        interests = payload["interests"]
        if not isinstance(interests, list):
            _fail("INVALID_INTERESTS")
            return
        new_fields["interests"] = [str(i).strip() for i in interests if str(i).strip()][:20]
    if "public" in payload:
        new_fields["public"] = bool(payload["public"])
    if "photo" in payload:
        new_fields["photo"] = str(payload["photo"]).strip()[:500]

    # Merge non destructif — cohérent avec _love_save_profile (love_handler.sh)
    profile = _load_existing_profile(email)
    profile.update(new_fields)
    _save_profile(email, profile)

    # Chiffré avec $UPLANETNAME (AES-256-CBC, même mécanisme que
    # cooperative_config.sh::coop_encrypt) — lisible uniquement par les
    # stations de la constellation, jamais en clair sur les relais NOSTR.
    content = uplanet_crypto.encrypt(json.dumps({
        "age": profile.get("age", 0),
        "bio": profile.get("bio", ""),
        "interests": profile.get("interests", []),
        "public": bool(profile.get("public", False)),
        "photo": profile.get("photo", ""),
    }))
    tags = [["d", "love-profile"], ["t", "love"]]

    publish_result = send_nostr_event(love_keyfile, content, tags=tags, kind=30078, json_output=True)

    print(json.dumps({
        "published": bool(publish_result.get("success")),
        "email": email,
        "profile": profile,
    }))


if __name__ == "__main__":
    main()
