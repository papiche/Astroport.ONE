#!/usr/bin/env python3
# 2b04c72d7859fc7e4cfa3fc7b28be3f1eb06632a3bc39a81da267523afc95cda
# nostr:nprofile1qyw8wumn8ghj7un9d3shjtnrdac8jmrpwfskg6t09e3k7mf0qqszkpx894u9nlr7fnarl3aj303lr6cxvv4rhsu6s8dzvafr4ly4eksdgjmn9
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
