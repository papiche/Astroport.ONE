#!/usr/bin/env python3
"""Convert Duniter v1 base58 public key to Duniter v2 SS58 address (and vice versa).

Usage:
    g1pub_to_ss58.py <v1_pubkey>          → SS58 address
    g1pub_to_ss58.py --reverse <ss58>     → v1 pubkey
    g1pub_to_ss58.py --check <address>    → auto-detect and show both formats

Duniter G1 SS58 prefix: 4450
"""
import sys
import hashlib
import base58

SS58_PREFIX = 4450

def v1_to_ss58(v1_pub: str) -> str:
    """Convert Duniter v1 base58 pubkey to SS58 address."""
    raw = base58.b58decode(v1_pub)
    if len(raw) != 32:
        raise ValueError(f"Invalid v1 pubkey length: {len(raw)} (expected 32)")
    first = ((SS58_PREFIX & 0xFC) >> 2) | 0x40
    second = (SS58_PREFIX >> 8) | ((SS58_PREFIX & 0x03) << 6)
    payload = bytes([first, second]) + raw
    checksum = hashlib.blake2b(b'SS58PRE' + payload, digest_size=64).digest()[:2]
    return base58.b58encode(payload + checksum).decode()

def ss58_to_v1(ss58_addr: str) -> str:
    """Convert SS58 address back to Duniter v1 base58 pubkey."""
    data = base58.b58decode(ss58_addr)
    # 2-byte prefix for prefix >= 64
    raw = data[2:-2]  # strip prefix (2 bytes) and checksum (2 bytes)
    if len(raw) != 32:
        raise ValueError(f"Invalid SS58 payload length: {len(raw)} (expected 32)")
    return base58.b58encode(raw).decode()

def is_ss58(address: str) -> bool:
    """Check if address looks like SS58 (starts with g1)."""
    return address.startswith('g1') and len(address) > 44

def ensure_ss58(address: str) -> str:
    """Convert to SS58 if v1 format, pass through if already SS58."""
    if is_ss58(address):
        return address
    return v1_to_ss58(address)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] == '--reverse' and len(sys.argv) >= 3:
        print(ss58_to_v1(sys.argv[2]))
    elif sys.argv[1] == '--check' and len(sys.argv) >= 3:
        addr = sys.argv[2]
        if is_ss58(addr):
            v1 = ss58_to_v1(addr)
            print(f"SS58: {addr}")
            print(f"V1:   {v1}")
        else:
            ss58 = v1_to_ss58(addr)
            print(f"V1:   {addr}")
            print(f"SS58: {ss58}")
    else:
        print(ensure_ss58(sys.argv[1]))
