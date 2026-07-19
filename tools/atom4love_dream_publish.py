#!/usr/bin/env python3
"""
atom4love_dream_publish.py — Publie le dream_vector (kind 30079, d=dream_vector)
de la clé LOVE (.secret.love) déjà activée : tags taxonomisés de Réalité Choisie
(DR — setting/lifestyle/values/career/relation/method), vitesse d'alignement v
(âge+poids, cf. phi2x.compute_alignment_v), time-ratio CR:DR et texte libre CR/DR.

Ne dérive JAMAIS de nouvelle clé — .secret.love doit déjà exister (créée par
atom4love_publish.py via /atom4love/activate). Réutilise nostr_send_note.py
(même mécanisme de signature+publication que le kind 30078 ATOM4LOVE).

Event kind 30079 (30000-39999) : parameterized replaceable NIP-33 — republier
avec un nouveau created_at remplace automatiquement l'ancien (relay standard),
aucune logique de mise à jour spécifique n'est nécessaire ici.

Usage:
    atom4love_dream_publish.py EMAIL BIRTH_UNIX [WEIGHT_KG]
    Payload JSON sur stdin :
        {"dream_tags": ["setting:foret", ...], "ratio": "1:10",
         "cr": "...", "dr": "...", "notes": "..."}

Imprime en DERNIÈRE ligne de stdout un JSON — seule sortie parsée par les
appelants (atom4love_dream.sh, UPassport routers/identity.py).
"""
import sys
import os
import json

MY_PATH = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, MY_PATH)

import phi2x  # noqa: E402
from nostr_send_note import send_nostr_event  # noqa: E402
import uplanet_crypto  # noqa: E402


def _fail(error: str, extra: dict | None = None) -> None:
    payload = {"published": False, "error": error}
    if extra:
        payload.update(extra)
    print(json.dumps(payload))
    sys.exit(1)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: atom4love_dream_publish.py EMAIL BIRTH_UNIX [WEIGHT_KG]", file=sys.stderr)
        sys.exit(1)

    email = sys.argv[1]
    try:
        birth_unix = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else 0
        weight_kg = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else 3.5
    except ValueError as e:
        _fail("INVALID_PARAMETERS", {"detail": str(e)})
        return

    if not birth_unix:
        _fail("MISSING_BIRTH_UNIX")
        return

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

    dream_tags = [str(t).strip() for t in payload.get("dream_tags", []) if str(t).strip()]
    ratio = str(payload.get("ratio", "")).strip()
    cr = str(payload.get("cr", "")).strip()
    dr = str(payload.get("dr", "")).strip()
    notes = str(payload.get("notes", "")).strip()

    v = phi2x.compute_alignment_v(birth_unix, weight_kg)

    # Chiffré avec $UPLANETNAME (AES-256-CBC, même mécanisme que
    # cooperative_config.sh::coop_encrypt) — dream_tags restent en clair
    # dans les tags NOSTR (nécessaires au matching constellation), mais le
    # texte libre CR/DR est sensible et n'est lisible que par les stations
    # de la constellation.
    content = uplanet_crypto.encrypt(json.dumps({"cr": cr, "dr": dr, "notes": notes}))
    tags = [["d", "dream_vector"]]
    tags += [["t", tag] for tag in dream_tags]
    if ratio:
        tags.append(["ratio", ratio])
    tags.append(["v", f"{v:.4f}"])

    publish_result = send_nostr_event(love_keyfile, content, tags=tags, kind=30079, json_output=True)

    print(json.dumps({
        "published": bool(publish_result.get("success")),
        "email": email,
        "v": round(v, 4),
        "dream_tags": dream_tags,
        "ratio": ratio,
    }))


if __name__ == "__main__":
    main()
