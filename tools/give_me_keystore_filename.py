#!/usr/bin/env python3
import sys, base64
print("key_"+base64.b32encode(sys.argv[1].encode()).decode().lower().replace("=",""))
