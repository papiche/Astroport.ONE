#!/usr/bin/env python3
"""
Nostr Key Converter Tool

This script converts Nostr keys between different formats:
- NSEC (bech32 encoded private key) to hex private key
- NSEC to NPUB (bech32 encoded public key)
- Hex public key to NPUB

Usage:
    python nostr_nsec2npub2hex.py <nsec>
    python nostr_nsec2npub2hex.py --help

Example:
    python nostr_nsec2npub2hex.py nsec1xyz...
"""

import sys
import argparse
from bech32 import bech32_decode, bech32_encode, convertbits

def nsec_to_hex(nsec):
    """
    Convert a Nostr private key from NSEC (bech32) format to hex format.
    
    Args:
        nsec (str): The NSEC private key in bech32 format
        
    Returns:
        str: The hex-encoded private key, or None if invalid
    """
    hrp, data = bech32_decode(nsec)
    if hrp != 'nsec' or not data:
        return None
    decoded = convertbits(data, 5, 8, False)
    if not decoded or len(decoded) != 32:
        return None
    return bytes(decoded).hex()

def hex_to_npub(hex_pubkey):
    """
    Convert a hex public key to NPUB (bech32) format.
    
    Args:
        hex_pubkey (str): The public key in hex format
        
    Returns:
        str: The NPUB public key in bech32 format, or None if invalid
    """
    if not hex_pubkey or len(hex_pubkey) != 64:
        return None
    data = convertbits(bytes.fromhex(hex_pubkey), 8, 5)
    return bech32_encode("npub", data)

def nsec_to_npub(nsec):
    """
    Convert a NSEC private key to NPUB public key.
    Uses secp256k1 for key derivation if available, falls back to ecdsa.
    
    Args:
        nsec (str): The NSEC private key in bech32 format
        
    Returns:
        str: The NPUB public key in bech32 format, or None if invalid
    """
    hex_privkey = nsec_to_hex(nsec)
    if not hex_privkey:
        return None

    # Try to use secp256k1 for better performance and security
    try:
        import secp256k1
        privkey = secp256k1.PrivateKey(bytes.fromhex(hex_privkey))
        hex_pubkey = privkey.pubkey.serialize()[1:].hex()  # Skip 0x04 prefix
        return hex_to_npub(hex_pubkey)
    except ImportError:
        # Fallback to ecdsa if secp256k1 is not available
        import hashlib
        from ecdsa import SigningKey, SECP256k1
        sk = SigningKey.from_string(bytes.fromhex(hex_privkey), curve=SECP256k1)
        hex_pubkey = sk.get_verifying_key().to_string().hex()
        return hex_to_npub(hex_pubkey)

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(
        description="Convert Nostr keys between different formats",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("nsec", nargs="?", help="NSEC private key to convert")
    args = parser.parse_args()

    # If no arguments provided, show help
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    nsec = args.nsec

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

    # Output the hex public key
    print(f"{hex_pubkey}")

if __name__ == "__main__":
    main()
