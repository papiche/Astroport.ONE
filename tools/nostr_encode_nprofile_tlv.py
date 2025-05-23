#!/usr/bin/env python3
import sys
from bech32 import bech32_encode, convertbits

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 nostr_encode_nprofile_tlv.py <hex_public_key> [relay1,relay2,...]", file=sys.stderr)
        sys.exit(1)

    hex_key = sys.argv[1]
    relays_str = sys.argv[2] if len(sys.argv) > 2 else ""
    
    relays_list = []
    if relays_str:
        relays_list = [r.strip() for r in relays_str.split(',') if r.strip()]

    # TLV encoding for nprofile
    tlvs = bytearray()

    # Pubkey TLV (type 0)
    try:
        pubkey_bytes = bytes.fromhex(hex_key)
        if len(pubkey_bytes) != 32:
            print(f"Error: Public key hex must be 32 bytes (64 hex chars), got {len(pubkey_bytes)} bytes.", file=sys.stderr)
            sys.exit(1)
    except ValueError:
        print(f"Error: Invalid hex public key '{hex_key}'.", file=sys.stderr)
        sys.exit(1)
        
    tlvs.append(0)  # type
    tlvs.append(len(pubkey_bytes))  # length
    tlvs.extend(pubkey_bytes) # value

    # Relay TLVs (type 1)
    # NIP-19 recommends clients to limit the number of relay URLs to three or less.
    # This script will encode all passed, but the calling bash script limits them.
    for r_url in relays_list:
        try:
            relay_bytes = r_url.encode('utf-8')
        except Exception as e:
            print(f"Error encoding relay URL '{r_url}': {e}", file=sys.stderr)
            continue 

        if len(relay_bytes) > 255: # Length byte is 1 byte
             print(f"Warning: Relay URL '{r_url}' is too long ({len(relay_bytes)} bytes), skipping.", file=sys.stderr)
             continue

        tlvs.append(1)  # type
        tlvs.append(len(relay_bytes))  # length
        tlvs.extend(relay_bytes) # value

    converted = convertbits(tlvs, 8, 5, True) # pad=True is important
    if converted is None:
        # This can happen if tlvs is empty, but pubkey TLV ensures it's not.
        print("Error: convertbits failed. Input data might be unsuitable.", file=sys.stderr)
        sys.exit(1)

    nprofile = bech32_encode('nprofile', converted)
    if nprofile is None:
        print("Error: bech32_encode failed.", file=sys.stderr)
        sys.exit(1)
        
    print(f"{nprofile}")

if __name__ == "__main__":
  main() 