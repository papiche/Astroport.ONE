#!/usr/bin/env python3
"""peerid2ipns.py — PeerID (12D3Koo…, sortie de `keygen -t ipfs`) → nom IPNS (k51…, base36).

Même clé publique, deux encodages : le PeerID est le multihash en base58, le nom IPNS est le
CIDv1 (codec libp2p-key 0x72) de ce multihash en base36. Sans démon IPFS ni dépendance.

    peerid2ipns.py 12D3KooW…      →  k51qzi5uqu5d…
Code 1 (ERROR:peerid2ipns sur stderr) si l'entrée n'est pas un PeerID valide.
"""
import sys

_B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
_B36 = "0123456789abcdefghijklmnopqrstuvwxyz"


def b58decode(s: str) -> bytes:
    n = 0
    for c in s:
        i = _B58.find(c)
        if i < 0:
            raise ValueError(f"caractère base58 invalide : {c!r}")
        n = n * 58 + i
    raw = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return b"\x00" * (len(s) - len(s.lstrip("1"))) + raw


def peerid_to_ipns(peer_id: str) -> str:
    mh = b58decode(peer_id.strip())
    # multihash : <code><len><digest> — identity (0x00) d'une clé ed25519 (36 octets) ou sha256 (0x12, 32)
    if len(mh) < 3 or mh[1] != len(mh) - 2:
        raise ValueError("multihash invalide")
    cid = b"\x01\x72" + mh                     # CIDv1, libp2p-key
    n = int.from_bytes(cid, "big")
    out = ""
    while n:
        n, r = divmod(n, 36)
        out = _B36[r] + out
    return "k" + out


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: peerid2ipns.py <PeerID>", file=sys.stderr)
        sys.exit(1)
    try:
        print(peerid_to_ipns(sys.argv[1]))
    except ValueError as exc:
        print(f"ERROR:peerid2ipns {exc}", file=sys.stderr)
        sys.exit(1)
