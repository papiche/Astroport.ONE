#!/usr/bin/env python3
"""Convert Duniter v2 SS58 address to Duniter v1 base58 public key.

Usage:
    ss58_to_g1pubv1.py <ss58_address>     → v1 pubkey

Duniter G1 SS58 prefix: 4450
"""
import sys
import hashlib
import base58

def ss58_to_v1(ss58_addr: str) -> str:
    """Convert SS58 address back to Duniter v1 base58 pubkey."""
    data = base58.b58decode(ss58_addr)
    # 2-byte prefix for prefix >= 64
    # The payload is the 32-byte public key in raw format
    raw_pubkey = data[2:-2]  # strip prefix (2 bytes) and checksum (2 bytes)
    if len(raw_pubkey) != 32:
        raise ValueError(f"Invalid SS58 payload length: {len(raw_pubkey)} (expected 32)")
    return base58.b58encode(raw_pubkey).decode()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    try:
        print(ss58_to_v1(sys.argv[1]))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)