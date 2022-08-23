#!/usr/bin/env python3

import base64, base58, sys, string, random
from natools import get_privkey, box_decrypt, box_encrypt, fmt

def getargv(arg:str, default:str="", n:int=1, args:list=sys.argv) -> str:
	if arg in args and len(args) > args.index(arg)+n:
		return args[args.index(arg)+n]
	else:
		return default

cmd = sys.argv[1]

dunikey = getargv("-k", "private.dunikey")
msg = getargv("-m", "test")
pubkey = getargv("-p")

def decrypt(msg):
    msg64 = base64.b64decode(msg)
    return box_decrypt(msg64, get_privkey(dunikey, "pubsec"), pubkey).decode()

def encrypt(msg):
    return fmt["64"](box_encrypt(msg.encode(), get_privkey(dunikey, "pubsec"), pubkey)).decode()

if cmd == 'decrypt':
    clear = decrypt(msg)
    print(clear)
elif cmd == 'encrypt':
    clear = encrypt(msg)
    print(clear)

