#!/usr/bin/env python3

import argparse
import base64
import base58
import os

def ssh_to_g1(ssh_key):
    key_part = ssh_key.split()[1]
    decoded = base64.b64decode(key_part)
    ed25519_key = decoded[-32:]
    return base58.b58encode(ed25519_key).decode()

def g1_to_ipns(g1_key):
    decoded_g1 = base58.b58decode(g1_key)
    ipns_key = b'\x00$\x08\x01\x12 ' + decoded_g1
    return base58.b58encode(ipns_key).decode()

def main():
    parser = argparse.ArgumentParser(description="Convertir une clé publique SSH en clé publique G1 ou IPNS.")
    parser.add_argument("ssh_key", nargs="?", help="La clé publique SSH à convertir.")
    parser.add_argument("-t", "--type", choices=['g1', 'ipns'], default='ipns',
                        help="Le type de sortie : 'g1' ou 'ipns' (par défaut : 'ipns').")

    args = parser.parse_args()

    if args.ssh_key is None:
        default_key_path = os.path.expanduser("~/.ssh/id_ed25519.pub")
        if os.path.exists(default_key_path):
            with open(default_key_path, 'r') as f:
                args.ssh_key = f.read().strip()
        else:
            print("Erreur : Aucune clé SSH fournie et ~/.ssh/id_ed25519.pub n'existe pas.")
            return

    g1_key = ssh_to_g1(args.ssh_key)

    if args.type == 'g1':
        print(g1_key)
    else:
        ipns_key = g1_to_ipns(g1_key)
        print(ipns_key)

if __name__ == "__main__":
    main()
