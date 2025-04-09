#!/usr/bin/env python3
import argparse
import time
from pynostr.key import PrivateKey, PublicKey
from pynostr.event import Event
from pynostr.relay_manager import RelayManager

def convert_pubkey_to_hex(pubkey_str):
    """
    Detects if pubkey_str is npub or hex and converts it to hex.

    Args:
        pubkey_str (str): The public key string (npub or hex).

    Returns:
        str: The hex representation of the public key.
             Returns None if the input is not a valid npub or hex.
    """
    try:
        if pubkey_str.startswith("npub"):
            # Try to decode as npub
            pub_key = PublicKey.from_npub(pubkey_str)
            return pub_key.hex()
        elif len(pubkey_str) == 64 and all(c in '0123456789abcdefABCDEF' for c in pubkey_str):
            # Assume it's already hex if it's 64 chars and hex characters
            return pubkey_str.lower() # Ensure lowercase hex
        else:
            print(f"Warning: '{pubkey_str}' does not appear to be a valid npub or hex pubkey.")
            return None # Indicate invalid format
    except Exception as e:
        print(f"Warning: Error decoding pubkey '{pubkey_str}': {e}")
        return None

def send_follow_event(nsec, npub_or_hex_list, relays):
    """
    Sends a "follow" event to Nostr relays.

    Args:
        nsec (str): Private key in nsec format.
        npub_or_hex_list (list): List of npubs or hex pubkeys to follow.
        relays (list): List of relay URLs.
    """
    # Charger la clé privée depuis nsec
    sk = PrivateKey.from_nsec(nsec)

    hex_pubkeys_to_follow = []
    for pubkey_str in npub_or_hex_list:
        hex_pubkey = convert_pubkey_to_hex(pubkey_str)
        if hex_pubkey:
            hex_pubkeys_to_follow.append(hex_pubkey)

    if not hex_pubkeys_to_follow:
        print("Error: No valid pubkeys to follow found. Aborting.")
        return

    # Créer l'événement "follow" avec les hex pubkeys en tags
    tags = [["p", hex_pubkey] for hex_pubkey in hex_pubkeys_to_follow]
    event = Event(
        content="",
        pubkey=sk.public_key.hex(),
        kind=3,  # Kind 3 : liste de contacts (follow)
        tags=tags
    )

    # Signer l'événement
    sk.sign_event(event)

    # Envoyer à chaque relay
    relay_manager = RelayManager()
    for relay in relays:
        relay_manager.add_relay(relay)

    relay_manager.open_connections()
    time.sleep(1)  # Laisser le temps aux connexions de s'établir

    relay_manager.publish_event(event)
    time.sleep(1)  # Pause pour assurer la transmission

    relay_manager.close_connections()

    print(f"✅ Follow event sent to relays for pubkeys: {', '.join(hex_pubkeys_to_follow)} via {', '.join(relays)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Envoyer un event 'follow' sur Nostr.")
    parser.add_argument("nsec", type=str, help="Clé privée Nostr (nsec)")
    parser.add_argument("npub_or_hex", type=str, nargs='+', help="Npub ou clé publique hex à suivre (un ou plusieurs)", metavar="npub_or_hex")
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.copylaradio.com"],
                        help="URL du relay Nostr (peut être spécifié plusieurs fois)")

    args = parser.parse_args()

    send_follow_event(args.nsec, args.npub_or_hex, args.relay)
