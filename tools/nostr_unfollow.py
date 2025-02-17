#!/bin/env python
import argparse
import time
from pynostr.key import PrivateKey
from pynostr.event import Event
from pynostr.relay_manager import RelayManager

def send_unfollow_event(nsec, npubs, relays):
    # Charger la clé privée depuis nsec
    sk = PrivateKey.from_nsec(nsec)

    # Créer un nouvel événement "follow" **sans** les npubs qu'on veut supprimer
    event = Event(
        content="",
        pubkey=sk.public_key.hex(),
        kind=3,  # Kind 3 : mise à jour des abonnements
        tags=[]  # Liste vide = suppression de tous les follows
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

    print(f"🚨 Unfollow effectué sur {', '.join(npubs)} via {', '.join(relays)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Envoyer un event 'unfollow' sur Nostr.")
    parser.add_argument("nsec", type=str, help="Clé privée Nostr (nsec)")
    parser.add_argument("npubs", type=str, nargs=1, help="Au moins un npub à ne plus suivre", metavar="npub")
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.copylaradio.com"],
                        help="URL du relay Nostr (peut être spécifié plusieurs fois)")

    args = parser.parse_args()

    send_unfollow_event(args.nsec, args.npubs, args.relay)
