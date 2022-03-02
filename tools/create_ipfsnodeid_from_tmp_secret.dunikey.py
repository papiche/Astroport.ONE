#!/usr/bin/env python3
# This Python script gets /tmp/secret.dunikey produce with  key_create_dunikey.py or from https://Cesium.app
# It create ED25519 ipfs (currently 0.7.0) Identity
#########################################################################
# sudo apt install protobuf-compiler
# pip3 install base58 google protobuf duniterpy
# wget https://github.com/libp2p/go-libp2p-core/raw/master/crypto/pb/crypto.proto
# protoc --python_out=. crypto.proto
#########################################################################

import re, base58, base64, crypto_pb2
import cryptography.hazmat.primitives.asymmetric.ed25519 as ed25519
from cryptography.hazmat.primitives import serialization

# TODO controls
# Capturing keys (from /tmp/secret.dunikey)

dunikey = "/tmp/secret.dunikey"
for line in open(dunikey, "r"):
    if re.search("pub", line):
        shared_key = line.replace('\n','').split(': ')[1]
    elif re.search("sec", line):
        secure_key = line.replace('\n','').split(': ')[1]

# Decoding keys
decoded_shared = base58.b58decode(shared_key)
decoded_secure = base58.b58decode(secure_key)
ipfs_shared = ed25519.Ed25519PublicKey.from_public_bytes(decoded_shared)
ipfs_secure = ed25519.Ed25519PrivateKey.from_private_bytes(decoded_secure[:32])
ipfs_shared_bytes = ipfs_shared.public_bytes(encoding=serialization.Encoding.Raw,
                                             format=serialization.PublicFormat.Raw)
ipfs_secure_bytes = ipfs_secure.private_bytes(encoding=serialization.Encoding.Raw,
                                              format=serialization.PrivateFormat.Raw,
                                              encryption_algorithm=serialization.NoEncryption())


# Formulating PeerID
ipfs_pid = base58.b58encode(b'\x00$\x08\x01\x12 ' + ipfs_shared_bytes)
PeerID = ipfs_pid.decode('ascii')
print('PeerID={};'.format(ipfs_pid.decode('ascii')))


# Serializing private key in IPFS-native mode, the private key contains public one
pkey = crypto_pb2.PrivateKey()
#pkey.Type = crypto_pb2.KeyType.Ed25519
pkey.Type = 1
pkey.Data = ipfs_secure_bytes + ipfs_shared_bytes
PrivKey = base64.b64encode(pkey.SerializeToString()).decode('ascii')
print('PrivKEY=' + base64.b64encode(pkey.SerializeToString()).decode('ascii'))

# jq '.Identity.PeerID="$PeerID"' ~/.ipfs/config
# jq '.Identity.PrivKey="$PrivKey"' ~/.ipfs/config
