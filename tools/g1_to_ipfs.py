#!/usr/bin/env python3
"""Convert Duniter v1/v2 public key to IPNS key.

Usage:
    g1_to_ipfs.py <pubkey_or_ss58>  → IPNS key
"""
import sys
import base58
import hashlib
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization

# Duniter SS58 prefix
SS58_PREFIX = 4450

def is_ss58(address: str) -> bool:
    """Check if the address is in SS58 format (starts with 'g1')."""
    return address.startswith('g1') and len(address) > 44

def ss58_to_raw(ss58_addr: str) -> bytes:
    """Convert SS58 address to raw 32-byte public key."""
    data = base58.b58decode(ss58_addr)
    # Strip prefix (2 bytes) and checksum (2 bytes)
    raw = data[2:-2]
    if len(raw) != 32:
        raise ValueError(f"Invalid SS58 payload length: {len(raw)} (expected 32)")
    return raw

def v1_to_raw(v1_pub: str) -> bytes:
    """Convert Duniter v1 base58 pubkey to raw 32-byte public key."""
    raw = base58.b58decode(v1_pub)
    if len(raw) != 32:
        raise ValueError(f"Invalid v1 pubkey length: {len(raw)} (expected 32)")
    return raw

def raw_to_ipns(raw_pub: bytes) -> str:
    """Convert raw 32-byte Ed25519 public key to IPNS key."""
    # IPNS prefix: \x00$\x08\x01\x12 (multibase identity multicodec for Ed25519)
    ipns_prefix = b'\x00$\x08\x01\x12 '
    ipns_key = base58.b58encode(ipns_prefix + raw_pub)
    return ipns_key.decode('ascii')

def duniter_to_ipns(pubkey: str) -> str:
    """Convert Duniter v1 or v2 public key to IPNS key."""
    if is_ss58(pubkey):
        raw = ss58_to_raw(pubkey)
    else:
        raw = v1_to_raw(pubkey)
    return raw_to_ipns(raw)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    try:
        ipns_key = duniter_to_ipns(sys.argv[1])
        print(ipns_key)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)