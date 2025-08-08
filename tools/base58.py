#!/usr/bin/env python3
"""
Base58 encoding/decoding utility for Astroport.ONE
Usage: base58.py encode <hex_string> or base58.py decode <base58_string>
"""

import binascii
import sys

# Base58 alphabet
BASE58_ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

def b58encode(hex_str):
    """Encode a hex string to Base58"""
    # Handle SSSS format (1-<hex>:<suffix>)
    if hex_str.startswith('1-') and ':' in hex_str:
        ssss_part = hex_str.split(':')[0]  # "1-<hex>"
        suffix = ':' + hex_str.split(':', 1)[1]
        hex_part = ssss_part[2:]  # Remove "1-" prefix
    elif ':' in hex_str:
        hex_part = hex_str.split(':')[0]
        suffix = ':' + hex_str.split(':', 1)[1]
    else:
        hex_part = hex_str
        suffix = ''

    # Ensure the hex string has even length
    if len(hex_part) % 2 != 0:
        hex_part = '0' + hex_part

    # Convert hex string to bytes
    try:
        byte_data = binascii.unhexlify(hex_part)
    except binascii.Error:
        raise ValueError(f"Invalid hex string: {hex_part}")

    # Convert bytes to Base58
    n = int.from_bytes(byte_data, 'big')
    base58_str = ''
    while n > 0:
        n, remainder = divmod(n, 58)
        base58_str = BASE58_ALPHABET[remainder] + base58_str

    # Add leading '1's for each leading zero byte
    leading_zeros = len(byte_data) - len(byte_data.lstrip(b'\x00'))
    result = BASE58_ALPHABET[0] * leading_zeros + base58_str
    
    return result + suffix

def b58decode(base58_str):
    """Decode a Base58 string to hex"""
    # Extract only the base58 part from the string if it contains ':'
    if ':' in base58_str:
        base58_part = base58_str.split(':')[0]
        suffix = ':' + base58_str.split(':', 1)[1]
    else:
        base58_part = base58_str
        suffix = ''

    # Validate base58 string
    for char in base58_part:
        if char not in BASE58_ALPHABET:
            raise ValueError(f"Invalid Base58 character: {char}")

    n = 0
    for char in base58_part:
        n = n * 58 + BASE58_ALPHABET.index(char)

    # Convert the number to bytes
    if n == 0:
        byte_data = b''
    else:
        byte_data = n.to_bytes((n.bit_length() + 7) // 8, 'big')

    # Add leading zeros
    leading_zeros = len(base58_part) - len(base58_part.lstrip(BASE58_ALPHABET[0]))
    result_bytes = b'\x00' * leading_zeros + byte_data
    
    # Convert to hex string
    hex_result = binascii.hexlify(result_bytes).decode('utf-8')
    
    # Check if this was originally a SSSS format (1-<hex>)
    # We can't know for sure, but we can check if the suffix contains k51qzi (IPNS format)
    if suffix and 'k51qzi' in suffix:
        # This was likely a SSSS format, so add back the "1-" prefix
        return "1-" + hex_result + suffix
    
    return hex_result + suffix

def main():
    if len(sys.argv) != 3:
        print("Usage: base58.py encode <hex_string>")
        print("   or: base58.py decode <base58_string>")
        sys.exit(1)

    command = sys.argv[1].lower()
    input_str = sys.argv[2]

    try:
        if command == 'encode':
            result = b58encode(input_str)
            print(result)
        elif command == 'decode':
            result = b58decode(input_str)
            print(result)
        else:
            print("Error: Command must be 'encode' or 'decode'")
            sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
