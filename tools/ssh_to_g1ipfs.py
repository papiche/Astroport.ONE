#!/usr/bin/env python3

import argparse
import base64
import base58

def ssh_to_g1(ssh_key):
    # Extraire la partie clé (après "ssh-ed25519 ")
    key_part = ssh_key.split()[1]
    # Décoder de base64
    decoded = base64.b64decode(key_part)
    # La clé ED25519 est les 32 derniers octets
    ed25519_key = decoded[-32:]
    # Encoder en base58 pour obtenir la clé G1
    return base58.b58encode(ed25519_key).decode()

def g1_to_ipns(g1_key):
    decoded_g1 = base58.b58decode(g1_key)
    ipns_key = b'\x00$\x08\x01\x12 ' + decoded_g1
    return base58.b58encode(ipns_key).decode()

def main():
    parser = argparse.ArgumentParser(description="Convertir une clé publique SSH en clé publique G1 ou IPNS.")
    parser.add_argument("ssh_key", help="La clé publique SSH à convertir.")
    parser.add_argument("-t", "--type", choices=['g1', 'ipns'], default='ipns',
                        help="Le type de sortie : 'g1' ou 'ipns' (par défaut : 'ipns').")

    args = parser.parse_args()

    # Conversion de la clé SSH en G1
    g1_key = ssh_to_g1(args.ssh_key)

    if args.type == 'g1':
        print(g1_key)
    else:
        # Conversion de G1 en IPNS
        ipns_key = g1_to_ipns(g1_key)
        print(ipns_key)

if __name__ == "__main__":
    main()
