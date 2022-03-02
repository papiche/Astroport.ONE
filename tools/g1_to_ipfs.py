#!/usr/bin/env python3
import sys, re, base58, base64, crypto_pb2
import cryptography.hazmat.primitives.asymmetric.ed25519 as ed25519
from cryptography.hazmat.primitives import serialization

shared_key = sys.argv[1]
decoded_shared = base58.b58decode(shared_key)
ipfs_shared = ed25519.Ed25519PublicKey.from_public_bytes(decoded_shared)

ipfs_shared_bytes = ipfs_shared.public_bytes(encoding=serialization.Encoding.Raw,
                                             format=serialization.PublicFormat.Raw)
ipfs_pid = base58.b58encode(b'\x00$\x08\x01\x12 ' + ipfs_shared_bytes)
print(format(ipfs_pid.decode('ascii')))
