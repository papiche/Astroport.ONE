#!/usr/bin/env python3

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import sys
from bech32 import bech32_decode, convertbits

def nostr_to_hex(nostr_key):
    try:
        hrp, data = bech32_decode(nostr_key)
        if hrp not in ["npub", "nsec"] or data is None:
            raise ValueError("Invalid nostr key - must be npub or nsec")
        return bytes(convertbits(data, 5, 8, False)).hex()
    except Exception as e:
        raise ValueError(f"Invalid nostr key format: {e}")

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
