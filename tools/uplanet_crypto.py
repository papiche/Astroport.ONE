#!/usr/bin/env python3
"""
uplanet_crypto.py — Chiffrement symétrique partagé par la constellation
(AES-256-CBC, clé = SHA256($UPLANETNAME)), bit-compatible avec
cooperative_config.sh::coop_encrypt/coop_decrypt (même appel openssl, même
format "iv_hex:base64") — pour que les deux implémentations (bash/python)
ne divergent jamais, aucune primitive AES n'est réimplémentée ici : on
délègue à openssl comme le fait déjà la version bash.

Utilisé pour chiffrer/déchiffrer le contenu ATOM4LOVE sensible (love-profile
bio/interests, dream_vector cr/dr/notes) publié sur NOSTR (kind 30078/30079)
— lisible uniquement par les stations qui partagent $UPLANETNAME (la
constellation), jamais par un relai ou observateur extérieur.
"""
import os
import re
import hashlib
import subprocess

_ENCRYPTED_RE = re.compile(r"^[0-9a-f]{32}:[A-Za-z0-9+/]+=*$")


def get_uplanetname() -> str:
    """Identique à UPlanetSharedSecret() (tools/my.sh) et
    _get_uplanetname() (UPassport/routers/nostr.py) : $UPLANETNAME si déjà
    dans l'environnement, sinon dernière ligne de ~/.ipfs/swarm.key."""
    env_val = os.environ.get("UPLANETNAME", "").strip()
    if env_val:
        return env_val
    swarm_key = os.path.expanduser("~/.ipfs/swarm.key")
    try:
        with open(swarm_key) as f:
            lines = f.readlines()
        if lines:
            return lines[-1].strip()
    except OSError:
        pass
    return "0" * 64


def _derive_key(uplanetname: str) -> str:
    return hashlib.sha256(uplanetname.encode()).hexdigest()


def encrypt(plaintext: str, uplanetname: str = None) -> str:
    """Retourne 'iv:base64(...)' — identique à coop_encrypt (cooperative_config.sh)."""
    if not plaintext:
        return ""
    key = _derive_key(uplanetname or get_uplanetname())
    iv = os.urandom(16).hex()
    result = subprocess.run(
        ["openssl", "enc", "-aes-256-cbc", "-pbkdf2", "-a", "-A",
         "-K", key, "-iv", iv],
        input=plaintext.encode(), capture_output=True, check=True,
    )
    return f"{iv}:{result.stdout.decode().strip()}"


def decrypt(token: str, uplanetname: str = None) -> str:
    """Déchiffre 'iv:base64(...)' — identique à coop_decrypt. Lève sur échec
    (mauvais UPLANETNAME, format invalide, données corrompues)."""
    iv, sep, encrypted = token.partition(":")
    if not sep or not iv or not encrypted:
        raise ValueError("Invalid encrypted data format (expected iv:encrypted)")
    key = _derive_key(uplanetname or get_uplanetname())
    result = subprocess.run(
        ["openssl", "enc", "-aes-256-cbc", "-pbkdf2", "-d", "-a", "-A",
         "-K", key, "-iv", iv],
        input=encrypted.encode(), capture_output=True, check=True,
    )
    return result.stdout.decode()


def is_encrypted(value: str) -> bool:
    return bool(_ENCRYPTED_RE.match(value or ""))


def decrypt_or_passthrough(value: str, uplanetname: str = None) -> str:
    """Déchiffre si le format 'iv:base64' est reconnu, sinon renvoie la
    valeur telle quelle — compatibilité ascendante avec les events déjà
    publiés en clair avant l'activation du chiffrement."""
    if not value:
        return value
    if not is_encrypted(value):
        return value
    try:
        return decrypt(value, uplanetname)
    except (subprocess.CalledProcessError, ValueError, OSError):
        return value


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3 or sys.argv[1] not in ("encrypt", "decrypt"):
        print("Usage: uplanet_crypto.py encrypt|decrypt VALUE", file=sys.stderr)
        sys.exit(1)
    if sys.argv[1] == "encrypt":
        print(encrypt(sys.argv[2]))
    else:
        print(decrypt_or_passthrough(sys.argv[2]))
