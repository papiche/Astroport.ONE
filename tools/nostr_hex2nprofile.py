#!/usr/bin/env python3

import sys
from bech32 import bech32_encode, convertbits

def hex_to_nprofile(hex_key):
    # Convert the hex key to bytes
    byte_key = bytes.fromhex(hex_key)

    # Convert bytes to 5-bit words
    five_bit_words = convertbits(byte_key, 8, 5)

    # Encode in Bech32 with 'npub' prefix
    nprofile = bech32_encode('npub', five_bit_words)

    return nprofile

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 nostr_hex2nprofile.py <hex_public_key>")
        sys.exit(1)

    hex_key = sys.argv[1]
    nprofile = hex_to_nprofile(hex_key)
    print(f"nostr:{nprofile}")
