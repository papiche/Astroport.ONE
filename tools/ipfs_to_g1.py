#!/usr/bin/env python3

import sys, base58

ID = sys.argv[1]
hexFmt = base58.b58decode(ID)
noTag = hexFmt[6:]
b58Key = base58.b58encode(noTag).decode()

print(b58Key)
