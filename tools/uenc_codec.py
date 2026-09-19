#!/usr/bin/env python3
"""
uenc_codec.py — Codec partagé pour le format de chiffrement UENC (AES-256-GCM).

Format binaire : MAGIC(4="UENC") + VERSION(1) + ENC_TYPE(1) + IV(12) + CIPHERTEXT+TAG

Module unique remplaçant les implémentations dupliquées de
UPassport/routers/media_upload.py (_encrypt_aes256gcm) et du heredoc Python
inline de Astroport.ONE/IA/bro/bro_dm_daemon.sh (_handle_bro_image).

Usage CLI (pour appel depuis bash sans dépendance FastAPI) :
    uenc_codec.py encrypt <key_hex> < plain  > payload.uenc
    uenc_codec.py decrypt <key_hex> < payload.uenc > plain
Sortie sur stderr + exit code != 0 en cas d'erreur (clé invalide, magic
incorrect, tag d'authentification invalide).
"""

import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

UENC_MAGIC = b"UENC"
UENC_VERSION = 0x01
UENC_TYPE_AES256GCM = 0x01
UENC_HEADER_LEN = 6   # MAGIC(4) + VERSION(1) + ENC_TYPE(1)
UENC_IV_LEN = 12


def _key_bytes(key_hex: str) -> bytes:
    key = bytes.fromhex(key_hex)
    if len(key) != 32:
        raise ValueError("La clef doit faire 32 octets (64 hex chars)")
    return key


def encrypt_aes256gcm(data: bytes, key_hex: str) -> tuple[bytes, str]:
    """Chiffre `data` avec AES-256-GCM. Retourne (payload_uenc, iv_hex)."""
    import os

    key = _key_bytes(key_hex)
    iv = os.urandom(UENC_IV_LEN)
    ciphertext = AESGCM(key).encrypt(iv, data, None)  # ciphertext + 16 bytes tag
    payload = UENC_MAGIC + bytes([UENC_VERSION, UENC_TYPE_AES256GCM]) + iv + ciphertext
    return payload, iv.hex()


def decrypt_aes256gcm(payload: bytes, key_hex: str) -> bytes:
    """Déchiffre un payload UENC. Lève ValueError (magic/version invalide)
    ou cryptography.exceptions.InvalidTag (clé fausse / données altérées)."""
    if len(payload) < UENC_HEADER_LEN + UENC_IV_LEN:
        raise ValueError("Payload UENC trop court")
    if payload[:4] != UENC_MAGIC:
        raise ValueError(f"Magic invalide: {payload[:4]!r} (attendu {UENC_MAGIC!r})")
    version, enc_type = payload[4], payload[5]
    if version != UENC_VERSION:
        raise ValueError(f"Version UENC non supportée: {version}")
    if enc_type != UENC_TYPE_AES256GCM:
        raise ValueError(f"Type de chiffrement non supporté: {enc_type}")
    iv = payload[UENC_HEADER_LEN:UENC_HEADER_LEN + UENC_IV_LEN]
    ciphertext = payload[UENC_HEADER_LEN + UENC_IV_LEN:]
    key = _key_bytes(key_hex)
    return AESGCM(key).decrypt(iv, ciphertext, None)


def _cli() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in ("encrypt", "decrypt"):
        print("Usage: uenc_codec.py {encrypt|decrypt} <key_hex>   (data on stdin, result on stdout)", file=sys.stderr)
        return 2
    mode, key_hex = sys.argv[1], sys.argv[2]
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
