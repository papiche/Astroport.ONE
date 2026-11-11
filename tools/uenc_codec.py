#!/usr/bin/env python3
"""
uenc_codec.py — Codec partagé pour le format de chiffrement UENC v2 (STREAM).

Format binaire (identique à astroportd, crates/astro-crypto/src/uenc/v2.rs) :

    en-tête de 14 octets : MAGIC(4="UENC") + VERSION(1=2) + ENC_TYPE(1) + CHUNK_LOG2(1) + PRÉFIXE DE NONCE(7)
    puis des blocs de 2^CHUNK_LOG2 octets de clair (64 Kio à l'écriture) chiffrés + TAG(16).

Chaque bloc est scellé avec : nonce = préfixe(7) + indice du bloc (u32 big-endian) + drapeau « dernier »(1 octet),
et l'en-tête complet de 14 octets en données associées (AAD). Le drapeau « dernier » interdit la troncature.
ENC_TYPE : 0x01 = AES-256-GCM (écriture), 0x02 = ChaCha20-Poly1305 (lecture seulement ici).

L'ancien format v1 (monolithique, IV de 12 octets) n'est PLUS lu ni écrit : la v1.0 d'astroportd l'a retiré.

Module unique remplaçant les implémentations dupliquées de
UPassport/routers/media_upload.py (_encrypt_aes256gcm) et du heredoc Python
inline de Astroport.ONE/IA/bro/bro_dm_daemon.sh (_handle_bro_image).

Usage CLI (pour appel depuis bash sans dépendance FastAPI) :
    uenc_codec.py encrypt <key_hex> < plain  > payload.uenc
    uenc_codec.py decrypt <key_hex> < payload.uenc > plain
Sortie sur stderr + exit code != 0 en cas d'erreur (clé invalide, magic
incorrect, tag d'authentification invalide).

Mode --key-stdin (clé jamais en argv, invisible dans /proc/<pid>/cmdline,
même convention que --nsec-stdin ailleurs dans ce dépôt) :
    { printf '%s\n' "$key_hex"; cat payload.uenc; } | uenc_codec.py decrypt --key-stdin > plain
La première ligne de stdin est la clé hex, le reste (binaire) est la donnée.
"""

import os
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM, ChaCha20Poly1305

UENC_MAGIC = b"UENC"
UENC_VERSION = 0x02
UENC_TYPE_AES256GCM = 0x01
UENC_TYPE_CHACHA20POLY1305 = 0x02
UENC_HEADER_LEN = 14      # MAGIC(4) + VERSION(1) + ENC_TYPE(1) + CHUNK_LOG2(1) + PRÉFIXE(7)
UENC_PREFIX_LEN = 7
UENC_TAG_LEN = 16
UENC_CHUNK_LOG2 = 16      # blocs de 64 Kio en écriture
_MIN_CHUNK_LOG2, _MAX_CHUNK_LOG2 = 12, 24


def _key_bytes(key_hex: str) -> bytes:
    key = bytes.fromhex(key_hex)
    if len(key) != 32:
        raise ValueError("La clef doit faire 32 octets (64 hex chars)")
    return key


def _nonce(prefix: bytes, index: int, last: bool) -> bytes:
    return prefix + index.to_bytes(4, "big") + (b"\x01" if last else b"\x00")


def encrypt_aes256gcm(data: bytes, key_hex: str) -> tuple[bytes, str]:
    """Chiffre `data` en UENC v2 (AES-256-GCM, blocs de 64 Kio). Retourne
    (payload_uenc, prefixe_hex) : le préfixe de nonce (7 octets) tient lieu d'« IV » informatif."""
    aead = AESGCM(_key_bytes(key_hex))
    prefix = os.urandom(UENC_PREFIX_LEN)
    header = UENC_MAGIC + bytes([UENC_VERSION, UENC_TYPE_AES256GCM, UENC_CHUNK_LOG2]) + prefix
    cs = 1 << UENC_CHUNK_LOG2
    # Au moins un bloc (éventuellement vide) ; le dernier porte le drapeau « last ».
    chunks = [data[o:o + cs] for o in range(0, len(data), cs)] or [b""]
    out = [header]
    for index, chunk in enumerate(chunks):
        out.append(aead.encrypt(_nonce(prefix, index, index == len(chunks) - 1), chunk, header))
    return b"".join(out), prefix.hex()


def decrypt_aes256gcm(payload: bytes, key_hex: str) -> bytes:
    """Déchiffre un payload UENC v2. Lève ValueError (magic/version/format invalide)
    ou cryptography.exceptions.InvalidTag (clé fausse / données altérées ou tronquées)."""
    if len(payload) < UENC_HEADER_LEN + UENC_TAG_LEN:
        raise ValueError("Payload UENC trop court")
    if payload[:4] != UENC_MAGIC:
        raise ValueError(f"Magic invalide: {payload[:4]!r} (attendu {UENC_MAGIC!r})")
    version, enc_type, chunk_log2 = payload[4], payload[5], payload[6]
    if version != UENC_VERSION:
        raise ValueError(f"Version UENC non supportée: {version} (seule la v2 est lue)")
    if not _MIN_CHUNK_LOG2 <= chunk_log2 <= _MAX_CHUNK_LOG2:
        raise ValueError(f"Taille de bloc UENC invalide: 2^{chunk_log2}")
    key = _key_bytes(key_hex)
    if enc_type == UENC_TYPE_AES256GCM:
        aead = AESGCM(key)
    elif enc_type == UENC_TYPE_CHACHA20POLY1305:
        aead = ChaCha20Poly1305(key)
    else:
        raise ValueError(f"Type de chiffrement non supporté: {enc_type}")
    header, prefix = payload[:UENC_HEADER_LEN], payload[7:UENC_HEADER_LEN]
    ct_chunk = (1 << chunk_log2) + UENC_TAG_LEN
    body = payload[UENC_HEADER_LEN:]
    chunks = [body[o:o + ct_chunk] for o in range(0, len(body), ct_chunk)]
    if not chunks or len(chunks[-1]) < UENC_TAG_LEN:
        raise ValueError("Payload UENC tronqué")
    return b"".join(
        aead.decrypt(_nonce(prefix, index, index == len(chunks) - 1), chunk, header)
        for index, chunk in enumerate(chunks)
    )


def _cli() -> int:
    args = sys.argv[1:]
    key_stdin = "--key-stdin" in args
    if key_stdin:
        args = [a for a in args if a != "--key-stdin"]

    if key_stdin:
        if len(args) != 1 or args[0] not in ("encrypt", "decrypt"):
            print("Usage: uenc_codec.py {encrypt|decrypt} --key-stdin   (key_hex + data on stdin: first line = key, rest = data)", file=sys.stderr)
            return 2
        mode = args[0]
        raw = sys.stdin.buffer.read()
        nl = raw.find(b"\n")
        if nl < 0:
            print("ERROR:uenc_codec:missing_key_line", file=sys.stderr)
            return 2
        key_hex = raw[:nl].decode().strip()
        data = raw[nl + 1:]
    else:
        if len(args) != 2 or args[0] not in ("encrypt", "decrypt"):
            print("Usage: uenc_codec.py {encrypt|decrypt} <key_hex>   (data on stdin, result on stdout)", file=sys.stderr)
            return 2
        mode, key_hex = args[0], args[1]
        data = sys.stdin.buffer.read()
    try:
        if mode == "encrypt":
            payload, _iv_hex = encrypt_aes256gcm(data, key_hex)
            sys.stdout.buffer.write(payload)
        else:
            plaintext = decrypt_aes256gcm(data, key_hex)
            sys.stdout.buffer.write(plaintext)
    except Exception as e:
        print(f"ERROR:uenc_codec:{type(e).__name__}:{e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(_cli())
