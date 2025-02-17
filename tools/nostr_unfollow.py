#!/bin/env python
import argparse
import time
import json
from pynostr.key import PrivateKey
from pynostr.event import Event
from pynostr.relay_manager import RelayManager

def get_current_follows(nsec, relays):
    """Récupère la liste actuelle des follows (Kind 3)"""
    sk = PrivateKey.from_nsec(nsec)
    pubkey = sk.public_key.hex()

    relay_manager = RelayManager()
    for relay in relays:
        relay_manager.add_relay(relay)

    relay_manager.open_connections()
    time.sleep(1)  # Laisser le temps aux connexions de s'établir

    follows = set()
    events = relay_manager.query(filters=[{"kinds": [3], "authors": [pubkey]}])

    if events:
        latest_event = sorted(events, key=lambda e: e["created_at"], reverse=True)[0]
        for tag in latest_event.get("tags", []):
            if tag[0] == "p":
                follows.add(tag[1])  # Ajouter chaque npub suivi

    relay_manager.close_connections()
    return follows

def send_unfollow_event(nsec, npub_to_unfollow, relays):
    """Envoie un nouvel événement Kind 3 en supprimant un follow spécifique"""
    sk = PrivateKey.from_nsec(nsec)

    # Récupérer la liste actuelle des follows
    current_follows = get_current_follows(nsec, relays)
    if npub_to_unfollow not in current_follows:
        print(f"ℹ️ Vous ne suivez pas {npub_to_unfollow}. Rien à changer.")
        return

    # Créer une nouvelle liste sans le npub à unfollow
    updated_follows = list(current_follows - {npub_to_unfollow})

    # Créer l'événement Kind 3 mis à jour
    event = Event(
        content="",
        pubkey=sk.public_key.hex(),
        kind=3,
        tags=[["p", npub] for npub in updated_follows]
    )

    # Signer et envoyer l'événement
    sk.sign_event(event)

    relay_manager = RelayManager()
    for relay in relays:
        relay_manager.add_relay(relay)

    relay_manager.open_connections()
    time.sleep(1)

    relay_manager.publish_event(event)
    time.sleep(1)

    relay_manager.close_connections()

    print(f"✅ Unfollow de {npub_to_unfollow} réussi !")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Arrêter de suivre un npub sur Nostr.")
    parser.add_argument("nsec", type=str, help="Clé privée Nostr (nsec)")
    parser.add_argument("npub", type=str, help="npub à ne plus suivre")
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.copylaradio.com"],
                        help="URL du relay Nostr (peut être spécifié plusieurs fois)")

    args = parser.parse_args()

    send_unfollow_event(args.nsec, args.npub, args.relay)
