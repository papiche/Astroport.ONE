#!/usr/bin/env python3
"""Canal de communication inter-NODE via DMs NIP-44 (kind 4).

Chaque message porte un champ `channel` qui identifie le sous-protocole,
permettant à un NODE de router les messages sans ambiguïté :

  udrive      — sync de fichier uDRIVE depuis une station visiteur
  vocals      — publication kind 1222/1244 (vocal) via home station
  webcam      — publication kind 21/22 (vidéo) via home station
  bro_ia      — commande BRO relayée depuis station visiteur
  zen_like    — paiement ZEN/G1 relayé depuis station visiteur
  comfyui_job    — job vidéo délégué à un Brain GPU
  comfyui_result — résultat renvoyé par le Brain au satellite

Chiffrement : NIP-44 (ChaCha20-Poly1305 + HKDF-SHA256) pour l'envoi.
Déchiffrement : NIP-44 avec fallback NIP-04 (AES-256-CBC) pour la rétrocompatibilité.

Dépendances : coincurve, cryptography, bech32, websocket-client
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import sys
import json
import argparse
import hashlib
import hmac
import ssl
import threading
import time
import base64
import os
import struct
import math


# ── Clés NOSTR ────────────────────────────────────────────────────────────────

def _nsec_to_hex(nsec: str) -> str:
    """Convertit un nsec bech32 en hex brut de la clé privée."""
    import bech32 as b32m
    hrp, data = b32m.bech32_decode(nsec)
    if hrp != "nsec" or data is None:
        raise ValueError(f"NSEC invalide : {nsec[:12]}…")
    raw = bytes(b32m.convertbits(data, 5, 8, False))
    return raw.hex()


def _priv_to_pub_hex(priv_hex: str) -> str:
    """Retourne la pubkey NOSTR (x-only, 32 octets en hex) depuis priv_hex."""
    import coincurve
    priv = coincurve.PrivateKey(bytes.fromhex(priv_hex))
    return priv.public_key.format(compressed=True)[1:].hex()


# ── Crypto ECDH ───────────────────────────────────────────────────────────────

def _derive_shared_secret(priv_hex: str, pub_hex: str) -> bytes:
    """Retourne la coordonnée X du point ECDH secp256k1 (32 octets)."""
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.backends import default_backend
    p = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
    x = int(pub_hex, 16)
    y_sq = (pow(x, 3, p) + 7) % p
    y = pow(y_sq, (p + 1) // 4, p)
    if y % 2 != 0:
        y = p - y
    pub_bytes = b'\x04' + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')
    priv_obj = ec.derive_private_key(int(priv_hex, 16), ec.SECP256K1(), default_backend())
    pub_obj = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256K1(), pub_bytes)
    return priv_obj.exchange(ec.ECDH(), pub_obj)


# ── NIP-44 v2 ────────────────────────────────────────────────────────────────
# Standard NIP-44 v2 : ECDH secp256k1 → HKDF("nip44-v2") → ChaCha20 + HMAC-SHA256
# Version byte 0x02, nonce 32 bytes, power-of-2 padding, MAC sur nonce+ct.
# Rétrocompatibilité : déchiffrement du vieux format (ChaCha20Poly1305, nonce 12 bytes).

def _nip44_v2_hkdf(ikm: bytes, length: int, salt, info: bytes) -> bytes:
    from cryptography.hazmat.primitives.kdf.hkdf import HKDF
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.backends import default_backend
    return HKDF(
        algorithm=hashes.SHA256(), length=length,
        salt=salt, info=info, backend=default_backend(),
    ).derive(ikm)


def _nip44_v2_conv_key(priv_hex: str, pub_hex: str) -> bytes:
    """Conversation key NIP-44 v2 : ECDH x-coordinate + HKDF(salt=None, info='nip44-v2')."""
    return _nip44_v2_hkdf(_derive_shared_secret(priv_hex, pub_hex), 32, None, b"nip44-v2")


def _nip44_v2_chacha20(key: bytes, nonce_12: bytes, data: bytes) -> bytes:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms
    from cryptography.hazmat.backends import default_backend
    # Python cryptography: nonce = 4-byte counter(LE=0) + 12-byte nonce
    cipher = Cipher(algorithms.ChaCha20(key, b'\x00\x00\x00\x00' + nonce_12),
                    mode=None, backend=default_backend())
    enc = cipher.encryptor()
    return enc.update(data) + enc.finalize()


def _nip44_v2_hmac(key: bytes, msg: bytes) -> bytes:
    import hmac as _h
    return _h.new(key, msg, hashlib.sha256).digest()


def _nip44_v2_pad_len(n: int) -> int:
    if n <= 32:
        return 32
    nextpow = 1 << (math.floor(math.log2(n - 1)) + 1)
    chunk = 32 if nextpow <= 256 else nextpow // 8
    return chunk * ((n - 1) // chunk + 1)


def _nip44_encrypt(plaintext: str, sender_priv_hex: str, recipient_pub_hex: str) -> str:
    """NIP-44 v2 encryption — version byte 0x02, compatible with all standard extensions."""
    conv_key = _nip44_v2_conv_key(sender_priv_hex, recipient_pub_hex)
    nonce    = os.urandom(32)
    utf8     = plaintext.encode('utf-8')
    pad_len  = _nip44_v2_pad_len(len(utf8))
    padded   = struct.pack('>H', len(utf8)) + utf8 + b'\x00' * (pad_len - len(utf8))
    keys     = _nip44_v2_hkdf(conv_key, 76, nonce, b"nip44-v2")
    ct       = _nip44_v2_chacha20(keys[0:32], keys[32:44], padded)
    mac      = _nip44_v2_hmac(keys[44:76], nonce + ct)
    return base64.b64encode(b'\x02' + nonce + ct + mac).decode('utf-8')


def _nip44_decrypt(ciphertext_b64: str, recipient_priv_hex: str, sender_pub_hex: str) -> str:
    """NIP-44 v2 decryption avec fallback vers l'ancien format custom."""
    import hmac as _h
    data = base64.b64decode(ciphertext_b64)
    # ── NIP-44 v2 (version byte = 0x02) ──
    if len(data) >= 99 and data[0] == 2:
        conv_key = _nip44_v2_conv_key(recipient_priv_hex, sender_pub_hex)
        nonce, ct, mac = data[1:33], data[33:-32], data[-32:]
        keys = _nip44_v2_hkdf(conv_key, 76, nonce, b"nip44-v2")
        if not _h.compare_digest(mac, _nip44_v2_hmac(keys[44:76], nonce + ct)):
            raise ValueError("NIP-44 v2 MAC invalide")
        padded  = _nip44_v2_chacha20(keys[0:32], keys[32:44], ct)
        msg_len = struct.unpack('>H', padded[0:2])[0]
        return padded[2:2 + msg_len].decode('utf-8')
    # ── Ancien format (ChaCha20Poly1305, nonce 12 bytes — rétrocompatibilité) ──
    if len(data) >= 13:
        from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
        shared = _derive_shared_secret(recipient_priv_hex, sender_pub_hex)
        key = _nip44_v2_hkdf(shared, 32, b"nostr-nip44-v1", b"nostr-encryption")
        return ChaCha20Poly1305(key).decrypt(data[:12], data[12:], None).decode('utf-8')
    raise ValueError(f"NIP-44 payload invalide (len={len(data)}, v={data[0] if data else '?'})")


# ── NIP-04 (fallback déchiffrement) ──────────────────────────────────────────

def _nip04_decrypt(ciphertext: str, recipient_priv_hex: str, sender_pub_hex: str) -> str:
    """AES-256-CBC déchiffrement NIP-04 : base64(ct)?iv=base64(iv)."""
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    if '?iv=' not in ciphertext:
        raise ValueError("Format NIP-04 invalide")
    ct_b64, iv_b64 = ciphertext.split('?iv=', 1)
    ct = base64.b64decode(ct_b64)
    iv = base64.b64decode(iv_b64)
    key = _derive_shared_secret(recipient_priv_hex, sender_pub_hex)
    cipher = Cipher(algorithms.AES(key[:32]), modes.CBC(iv))
    dec = cipher.decryptor()
    padded = dec.update(ct) + dec.finalize()
    pad_len = padded[-1]
    return padded[:-pad_len].decode('utf-8')


def _decrypt_content(content: str, recipient_priv_hex: str, sender_pub_hex: str) -> str:
    """NIP-44 v2 → ancien NIP-44 custom → NIP-04."""
    if '?iv=' in content:
        return _nip04_decrypt(content, recipient_priv_hex, sender_pub_hex)
    return _nip44_decrypt(content, recipient_priv_hex, sender_pub_hex)


# ── Événement NOSTR (kind 4, Schnorr BIP-340) ────────────────────────────────

def _make_event(priv_hex: str, pub_hex: str, content: str, tags: list,
                kind: int = 4, ttl: int = 0) -> dict:
    import coincurve
    created_at = int(time.time())
    all_tags = list(tags)
    if ttl > 0:
        all_tags.append(["expiration", str(created_at + ttl)])
    serialized = json.dumps(
        [0, pub_hex, created_at, kind, all_tags, content],
        separators=(',', ':'), ensure_ascii=False,
    )
    event_id = hashlib.sha256(serialized.encode('utf-8')).hexdigest()
    priv = coincurve.PrivateKey(bytes.fromhex(priv_hex))
    sig = priv.sign_schnorr(bytes.fromhex(event_id)).hex()
    return {
        "id":         event_id,
        "pubkey":     pub_hex,
        "created_at": created_at,
        "kind":       kind,
        "tags":       all_tags,
        "content":    content,
        "sig":        sig,
    }


# ── WebSocket helper ──────────────────────────────────────────────────────────

def _connect(url: str, on_open, on_message, timeout: int = 12):
    """Ouvre un WebSocket sync (websocket-client), appelle les callbacks."""
    try:
        import websocket as ws_mod
    except ImportError:
        print("ERROR: websocket-client non installé (pip install websocket-client)",
              file=sys.stderr)
        sys.exit(1)

    done = threading.Event()

    def _on_open(ws):    on_open(ws)
    def _on_msg(ws, m):  on_message(ws, m)
    def _on_close(ws, *_): done.set()
    def _on_err(ws, _):  done.set()

    sslopt = {"cert_reqs": ssl.CERT_NONE} if url.startswith("wss://") else {}
    ws = ws_mod.WebSocketApp(url,
                             on_open=_on_open, on_message=_on_msg,
                             on_close=_on_close, on_error=_on_err)
    t = threading.Thread(target=ws.run_forever, kwargs={"sslopt": sslopt}, daemon=True)
    t.start()
    done.wait(timeout=timeout)
    try:
        ws.close()
    except Exception:
        pass


# ── send ──────────────────────────────────────────────────────────────────────

def cmd_send(args):
    priv_hex = _nsec_to_hex(args.nsec)
    pub_hex = _priv_to_pub_hex(priv_hex)

    try:
        payload_data = json.loads(args.payload)
    except json.JSONDecodeError as exc:
        print(f"ERROR: --payload n'est pas du JSON valide : {exc}", file=sys.stderr)
        sys.exit(1)

    envelope = {"channel": args.channel, "payload": payload_data}
    try:
        encrypted = _nip44_encrypt(json.dumps(envelope), priv_hex, args.to)
    except Exception as exc:
        print(f"ERROR: chiffrement NIP-44 échoué : {exc}", file=sys.stderr)
        sys.exit(1)

    event_dict = _make_event(priv_hex, pub_hex, encrypted, [["p", args.to]],
                            ttl=getattr(args, 'ttl', 86400))

    errors = []
    for relay_url in args.relays:
        sent = threading.Event()

        def on_open(ws, _d=event_dict):
            ws.send(json.dumps(["EVENT", _d]))

        def on_message(ws, msg, _done=sent):
            try:
                data = json.loads(msg)
                if data[0] in ("OK", "NOTICE"):
                    _done.set()
                    ws.close()
            except Exception:
                pass

        _connect(relay_url, on_open, on_message, timeout=10)
        if not sent.is_set():
            errors.append(relay_url)

    if errors:
        print(f"WARN: aucun OK reçu de {errors}", file=sys.stderr)
        if len(errors) == len(args.relays):
            sys.exit(1)
    print(f"Sent [{args.channel}] to={args.to[:12]}... payload={list(payload_data.keys())}")


# ── receive ───────────────────────────────────────────────────────────────────

def cmd_receive(args):
    priv_hex = _nsec_to_hex(args.nsec)
    pub_hex = _priv_to_pub_hex(priv_hex)

    sub_filter: dict = {"kinds": [4], "#p": [pub_hex]}
    if args.since:
        sub_filter["since"] = int(args.since)

    all_events: list = []

    for relay_url in args.relays:
        collected: list = []

        def on_open(ws, _f=sub_filter):
            ws.send(json.dumps(["REQ", "intercom_recv", _f]))

        def on_message(ws, msg, _col=collected):
            try:
                data = json.loads(msg)
                if data[0] == "EVENT" and len(data) >= 3:
                    _col.append(data[2])
                elif data[0] == "EOSE":
                    ws.close()
            except Exception:
                pass

        _connect(relay_url, on_open, on_message, timeout=12)
        all_events.extend(collected)

    results = []
    seen_ids: set = set()
    for ev in all_events:
        eid = ev.get("id", "")
        if eid in seen_ids:
            continue
        seen_ids.add(eid)
        sender_hex = ev.get("pubkey", "")
        try:
            decrypted = _decrypt_content(ev["content"], priv_hex, sender_hex)
            try:
                envelope = json.loads(decrypted)
            except (json.JSONDecodeError, ValueError):
                envelope = {"channel": "plain", "payload": {"text": decrypted}}
        except Exception:
            continue

        channel = envelope.get("channel", "")
        if args.channel and channel != args.channel:
            continue

        results.append({
            "channel":    channel,
            "payload":    envelope.get("payload", {}),
            "event_id":   eid,
            "sender":     sender_hex,
            "created_at": ev.get("created_at", 0),
        })

    print(json.dumps(results))


# ── send-udrive (raccourci bash) ──────────────────────────────────────────────

def cmd_send_udrive(args):
    args.channel = "udrive"
    args.payload = json.dumps({
        "email":    args.email,
        "cid":      args.cid,
        "filename": args.filename,
        "filetype": args.filetype,
    })
    cmd_send(args)


# ── publish (event non chiffré, any kind) ────────────────────────────────────

def cmd_publish(args):
    """Signe et publie un event NOSTR non chiffré (any kind). Retourne l'event ID."""
    priv_hex = _nsec_to_hex(args.nsec)
    pub_hex = _priv_to_pub_hex(priv_hex)
    try:
        tags = json.loads(args.tags)
    except json.JSONDecodeError as exc:
        print(f"ERROR: --tags n'est pas du JSON valide : {exc}", file=sys.stderr)
        sys.exit(1)
    event_dict = _make_event(priv_hex, pub_hex, args.content or "",
                             tags, kind=args.kind, ttl=args.ttl)
    errors = []
    for relay_url in args.relays:
        sent = threading.Event()
        def on_open(ws, _d=event_dict):
            ws.send(json.dumps(["EVENT", _d]))
        def on_message(ws, msg, _done=sent):
            try:
                data = json.loads(msg)
                if data[0] in ("OK", "NOTICE"):
                    _done.set()
                    ws.close()
            except Exception:
                pass
        _connect(relay_url, on_open, on_message, timeout=10)
        if not sent.is_set():
            errors.append(relay_url)
    if errors:
        print(f"WARN: aucun OK reçu de {errors}", file=sys.stderr)
        if len(errors) == len(args.relays):
            sys.exit(1)
    print(event_dict["id"])


# ── verify (signature Schnorr d'un event NOSTR) ──────────────────────────────

def cmd_verify(_args):
    """Vérifie l'ID et la signature Schnorr d'un event NOSTR depuis stdin. Exit 0=valide, 1=invalide."""
    import coincurve
    try:
        ev = json.load(sys.stdin)
        if "event" in ev:
            ev = ev["event"]
        pub_hex  = ev.get("pubkey", "")
        sig_hex  = ev.get("sig", "")
        event_id = ev.get("id", "")
        serialized = json.dumps(
            [0, ev["pubkey"], ev["created_at"], ev["kind"], ev["tags"], ev["content"]],
            separators=(',', ':'), ensure_ascii=False,
        )
        computed_id = hashlib.sha256(serialized.encode('utf-8')).hexdigest()
        if computed_id != event_id:
            sys.exit(1)
        pub = coincurve.PublicKeyXOnly(bytes.fromhex(pub_hex))
        if not pub.verify(bytes.fromhex(sig_hex), bytes.fromhex(event_id)):
            sys.exit(1)
    except Exception:
        sys.exit(1)


# ── query (REQ filtre arbitraire) ────────────────────────────────────────────

def cmd_query(args):
    """Interroge le relay avec un filtre REQ arbitraire. Retourne les events JSON."""
    try:
        filt = json.loads(args.filter)
    except json.JSONDecodeError as exc:
        print(f"ERROR: --filter invalide : {exc}", file=sys.stderr)
        sys.exit(1)
    all_events: list = []
    for relay_url in args.relays:
        collected: list = []
        def on_open(ws, _f=filt):
            ws.send(json.dumps(["REQ", "wotx2_query", _f]))
        def on_message(ws, msg, _col=collected):
            try:
                data = json.loads(msg)
                if data[0] == "EVENT" and len(data) >= 3:
                    _col.append(data[2])
                elif data[0] == "EOSE":
                    ws.close()
            except Exception:
                pass
        _connect(relay_url, on_open, on_message, timeout=12)
        all_events.extend(collected)
    seen: set = set()
    results: list = []
    for ev in all_events:
        eid = ev.get("id", "")
        if eid not in seen:
            seen.add(eid)
            results.append(ev)
    print(json.dumps(results))


# ── decrypt (event kind 4 depuis stdin) ───────────────────────────────────────

def cmd_decrypt(args):
    nsec = args.nsec or os.environ.get('NOSTR_NSEC', '')
    priv_hex = _nsec_to_hex(nsec)
    try:
        ev = json.load(sys.stdin)
        if "event" in ev:
            ev = ev["event"]
        sender_hex = ev.get("pubkey", "")
        raw_content = ev.get("content", "")
        enc = "nip04" if "?iv=" in raw_content else "nip44"
        decrypted = _decrypt_content(raw_content, priv_hex, sender_hex)
        try:
            envelope = json.loads(decrypted)
        except (json.JSONDecodeError, ValueError):
            envelope = {"channel": "plain", "payload": {"text": decrypted}}
        print(json.dumps({
            "channel":  envelope.get("channel", "plain"),
            "payload":  envelope.get("payload", {}),
            "sender":   sender_hex,
            "event_id": ev.get("id", ""),
            "enc":      enc,
        }))
    except Exception:
        sys.exit(1)


# ── main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Canal de communication inter-NODE via DMs NOSTR NIP-44 (fallback NIP-04)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_send = sub.add_parser("send", help="Envoyer un message à un NODE distant")
    p_send.add_argument("--nsec",       default=None)
    p_send.add_argument("--nsec-stdin", action="store_true",
                        help="Lire le NSEC depuis la première ligne de stdin")
    p_send.add_argument("--to",      required=True, help="HEX pubkey du NODE destinataire")
    p_send.add_argument("--channel", required=True)
    p_send.add_argument("--payload", required=True, help="Contenu JSON du message")
    p_send.add_argument("--relays",  nargs="+", required=True)
    p_send.add_argument("--ttl",     type=int, default=86400,
                        help="Durée de vie en secondes (NIP-40, 0=permanent, défaut 86400=24h)")

    p_udrive = sub.add_parser("send-udrive", help="Envoyer une demande de sync uDRIVE")
    p_udrive.add_argument("--nsec",       default=None)
    p_udrive.add_argument("--nsec-stdin", action="store_true",
                          help="Lire le NSEC depuis la première ligne de stdin")
    p_udrive.add_argument("--to",       required=True)
    p_udrive.add_argument("--email",    required=True)
    p_udrive.add_argument("--cid",      required=True)
    p_udrive.add_argument("--filename", required=True)
    p_udrive.add_argument("--filetype", default="file",
                          choices=["image", "video", "audio", "document", "file"])
    p_udrive.add_argument("--relays",   nargs="+", required=True)
    p_udrive.add_argument("--ttl",      type=int, default=86400,
                          help="Durée de vie en secondes (NIP-40, 0=permanent, défaut 86400=24h)")

    p_recv = sub.add_parser("receive", help="Recevoir les messages en attente")
    p_recv.add_argument("--nsec",       default=None)
    p_recv.add_argument("--nsec-stdin", action="store_true",
                        help="Lire le NSEC depuis la première ligne de stdin")
    p_recv.add_argument("--channel", default=None)
    p_recv.add_argument("--since",   default=None)
    p_recv.add_argument("--relays",  nargs="+", required=True)

    p_dec = sub.add_parser("decrypt", help="Déchiffrer un event kind 4 depuis stdin")
    p_dec.add_argument("--nsec", default=None)
    # --nsec-stdin absent ici : decrypt lit déjà le JSON depuis stdin
    # Fallback : variable d'environnement NOSTR_NSEC (invisible dans ps aux)

    p_pub = sub.add_parser("publish", help="Publier un event NOSTR non chiffré (any kind)")
    p_pub.add_argument("--nsec",       default=None)
    p_pub.add_argument("--nsec-stdin", action="store_true",
                       help="Lire le NSEC depuis la première ligne de stdin")
    p_pub.add_argument("--kind",    type=int, required=True, help="NOSTR kind (ex: 30500, 30503)")
    p_pub.add_argument("--tags",    required=True, help='JSON array de tags ex: [["d","ID"],["t","skill"]]')
    p_pub.add_argument("--content", default="", help="Contenu de l'event (JSON string)")
    p_pub.add_argument("--ttl",     type=int, default=0,
                        help="Durée de vie en secondes (NIP-40, 0=permanent)")
    p_pub.add_argument("--relays",  nargs="+", required=True)

    p_qry = sub.add_parser("query", help="Interroger le relay (filtre REQ arbitraire)")
    p_qry.add_argument("--filter",  required=True,
                        help='Filtre REQ JSON ex: {"kinds":[30500],"authors":["hex..."]}')
    p_qry.add_argument("--relays",  nargs="+", required=True)

    sub.add_parser("verify", help="Vérifie la signature Schnorr d'un event NOSTR (stdin JSON)")

    args = parser.parse_args()

    # Résolution NSEC pour les sous-commandes qui en ont besoin
    # (send, send-udrive, receive, publish supportent --nsec-stdin ;
    #  decrypt : --nsec requis car stdin est déjà occupé par le JSON ;
    #  query, verify : pas de NSEC)
    if getattr(args, "nsec_stdin", False):
        args.nsec = sys.stdin.readline().strip()
    elif args.cmd not in ("query", "decrypt", "verify") and not getattr(args, "nsec", None):
        parser.error("--nsec ou --nsec-stdin requis")

    {
        "send":        cmd_send,
        "send-udrive": cmd_send_udrive,
        "decrypt":     cmd_decrypt,
        "receive":     cmd_receive,
        "publish":     cmd_publish,
        "query":       cmd_query,
        "verify":      cmd_verify,
    }[args.cmd](args)
