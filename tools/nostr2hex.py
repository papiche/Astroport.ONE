#!/usr/bin/env python3
import sys
from bech32 import bech32_decode, convertbits

def nostr_to_hex(nostr_key):
    hrp, data = bech32_decode(nostr_key)
    if hrp not in ["npub", "nsec"] or data is None:
        raise ValueError("Invalid nostr key - must be npub or nsec")
    return bytes(convertbits(data, 5, 8, False)).hex()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: ./nostr2hex.py <npub1_or_nsec1_key>")
        sys.exit(1)

    nostr_key = sys.argv[1]
    try:
        hex_key = nostr_to_hex(nostr_key)
        print(hex_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
