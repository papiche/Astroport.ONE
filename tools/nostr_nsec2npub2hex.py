#!/usr/bin/env python3
import sys
from bech32 import bech32_decode, bech32_encode, convertbits

def nsec_to_hex(nsec):
    """Convert nsec to hex private key"""
    hrp, data = bech32_decode(nsec)
    if hrp != 'nsec' or not data:
        return None
    decoded = convertbits(data, 5, 8, False)
    if not decoded or len(decoded) != 32:
        return None
    return bytes(decoded).hex()

def hex_to_npub(hex_pubkey):
    """Convert hex public key to npub"""
    if not hex_pubkey or len(hex_pubkey) != 64:
        return None
    data = convertbits(bytes.fromhex(hex_pubkey), 8, 5)
    return bech32_encode("npub", data)

def nsec_to_npub(nsec):
    """Convert nsec to npub"""
    hex_privkey = nsec_to_hex(nsec)
    if not hex_privkey:
        return None

    # Derive public key from private key (secp256k1)
    try:
        import secp256k1
        privkey = secp256k1.PrivateKey(bytes.fromhex(hex_privkey))
        hex_pubkey = privkey.pubkey.serialize()[1:].hex()  # Skip 0x04 prefix
        return hex_to_npub(hex_pubkey)
    except ImportError:
        # Fallback if secp256k1 not available (less secure)
        import hashlib
        from ecdsa import SigningKey, SECP256k1
        sk = SigningKey.from_string(bytes.fromhex(hex_privkey), curve=SECP256k1)
        hex_pubkey = sk.get_verifying_key().to_string().hex()
        return hex_to_npub(hex_pubkey)

def main():
    if len(sys.argv) != 2:
        print("Usage: nostr_nsec2npub2hex.py <nsec>")
        sys.exit(1)

    nsec = sys.argv[1]

    # Get hex private key
    hex_privkey = nsec_to_hex(nsec)
    if not hex_privkey:
        print("Error: Invalid NSEC format", file=sys.stderr)
        sys.exit(1)

    # Get npub
    npub = nsec_to_npub(nsec)
    if not npub:
        print("Error: Failed to derive NPUB", file=sys.stderr)
        sys.exit(1)

    # Get hex public key (from npub)
    hrp, data = bech32_decode(npub)
    if hrp != 'npub' or not data:
        print("Error: Invalid NPUB derived", file=sys.stderr)
        sys.exit(1)
    hex_pubkey = bytes(convertbits(data, 5, 8, False)).hex()

    # ~ print(f"NSEC: {nsec}")
    # ~ print(f"NPUB: {npub}")
    # ~ print(f"HEX (private): {hex_privkey}")
    print(f"{hex_pubkey}")

if __name__ == "__main__":
    main()
