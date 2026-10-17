#!/usr/bin/env python3
"""
nostr_nip98_sign.py — signe un en-tête « Authorization: Nostr … » (NIP-98) pour un appel HTTP.

Usage : nostr_nip98_sign.py <MULTIPASS_EMAIL|chemin .secret.nostr> <METHODE> <URL>
Écrit sur stdout la VALEUR de l'en-tête (« Nostr <base64url> »). La clé (nsec) est lue dans
~/.zen/game/nostr/<email>/.secret.nostr, jamais passée en argument (invisible dans `ps`).
Exemple :
    AUTH=$(nostr_nip98_sign.py fred@qwantic.com DELETE "$URL") && curl -X DELETE -H "Authorization: $AUTH" "$URL"
"""
import base64
import hashlib
import json
import os
import re
import secrets
import sys
import time

_venv = os.path.expanduser("~/.astro/bin/python3")
if os.path.exists(_venv) and sys.executable != _venv:
    os.execv(_venv, [_venv] + sys.argv)

from coincurve import PrivateKey  # noqa: E402


def _bech32_decode(nsec: str) -> bytes:
    CH = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    hrp, _, data = nsec.lower().rpartition("1")
    vals = [CH.index(c) for c in data][:-6]
    acc, bits, out = 0, 0, []
    for v in vals:
        acc = (acc << 5) | v
        bits += 5
        while bits >= 8:
            bits -= 8
            out.append((acc >> bits) & 0xFF)
    return bytes(out)


def _load_sk(who: str) -> PrivateKey:
    path = who if os.path.isfile(who) else os.path.expanduser(f"~/.zen/game/nostr/{who}/.secret.nostr")
    txt = open(path, encoding="utf-8").read()
    m = re.search(r"NSEC=([^;\s]+)", txt)
    if not m:
        raise SystemExit(f"NSEC introuvable dans {path}")
    v = m.group(1)
    return PrivateKey(_bech32_decode(v) if v.startswith("nsec") else bytes.fromhex(v))


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    sk = _load_sk(sys.argv[1])
    pub = sk.public_key_xonly.format().hex()
    ts = int(time.time())
    tags = [["u", sys.argv[3]], ["method", sys.argv[2].upper()], ["nonce", secrets.token_hex(8)]]
    ser = json.dumps([0, pub, ts, 27235, tags, ""], separators=(",", ":"), ensure_ascii=False)
    ev = {"pubkey": pub, "created_at": ts, "kind": 27235, "tags": tags, "content": "",
          "id": hashlib.sha256(ser.encode()).hexdigest()}
    ev["sig"] = sk.sign_schnorr(bytes.fromhex(ev["id"])).hex()
    print("Nostr " + base64.urlsafe_b64encode(json.dumps(ev, ensure_ascii=False).encode()).decode().rstrip("="))


if __name__ == "__main__":
    main()
