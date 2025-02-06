#!/usr/bin/env python3
import sys
from bech32 import bech32_decode, convertbits

def npub_to_hex(npub):
    hrp, data = bech32_decode(npub)
    if hrp != "npub" or data is None:
        raise ValueError("Invalid npub key")
    return bytes(convertbits(data, 5, 8, False)).hex()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: ./nostr2hex.py <npub1_key>")
        sys.exit(1)
    
    npub = sys.argv[1]
    try:
        hex_key = npub_to_hex(npub)
        print(hex_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

