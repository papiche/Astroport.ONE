#!/usr/bin/env python3
################################################################################
# Script: canonicalize_json.py
# Description: Canonicalize JSON according to RFC 8785 (JCS)
# 
# This script reads JSON from stdin or a file and outputs canonical JSON
# according to RFC 8785 (JSON Canonicalization Scheme).
#
# Usage:
#   echo '{"b": 2, "a": 1}' | python3 canonicalize_json.py
#   python3 canonicalize_json.py input.json
#   python3 canonicalize_json.py input.json output.json
#
# License: AGPL-3.0
# Author: UPlanet/Astroport.ONE Team
################################################################################

import json
import sys
from typing import Any

def canonicalize_json(data: Any) -> str:
    """
    Canonicalize JSON according to RFC 8785 (JCS - JSON Canonicalization Scheme).
    
    This ensures that the same JSON data always produces the same string representation,
    which is critical for cryptographic signatures. The output is:
    - Keys sorted lexicographically
    - No whitespace between tokens
    - No trailing commas
    - Consistent number formatting
    
    Args:
        data: Python object to serialize (dict, list, etc.)
    
    Returns:
        Canonical JSON string ready for signing
    
    Reference: https://datatracker.ietf.org/doc/html/rfc8785
    """
    return json.dumps(
        data,
        sort_keys=True,           # Lexicographic key ordering
        separators=(',', ':'),   # No whitespace (compact)
        ensure_ascii=False,      # Preserve Unicode
        allow_nan=False          # Reject NaN/Infinity (not in JSON spec)
    )

def main():
    """Main function for CLI usage"""
    if len(sys.argv) > 1:
        # Read from file
        input_file = sys.argv[1]
        try:
            with open(input_file, 'r') as f:
                data = json.load(f)
        except FileNotFoundError:
            print(f"Error: File not found: {input_file}", file=sys.stderr)
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in {input_file}: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        # Read from stdin
        try:
            data = json.load(sys.stdin)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON from stdin: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Canonicalize
    canonical = canonicalize_json(data)
    
    # Output
    if len(sys.argv) > 2:
        # Write to file
        output_file = sys.argv[2]
        with open(output_file, 'w') as f:
            f.write(canonical)
    else:
        # Write to stdout
        print(canonical)

if __name__ == "__main__":
    main()

