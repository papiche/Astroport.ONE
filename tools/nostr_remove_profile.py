#!/bin/env python
import sys
import argparse
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey

def send_deletion_request(relay_manager, private_key, event_id=None, pubkey=None):
    tags = []
    if event_id:
        tags.append(['e', event_id])
    if pubkey:
        tags.append(['p', pubkey])

    deletion_event = Event(kind=5, content="", tags=tags)
    deletion_event.sign(private_key.hex())
    relay_manager.publish_event(deletion_event)

def remove_nostr_profile(nsec, relays):
    private_key = PrivateKey.from_nsec(nsec)
    public_key = private_key.public_key.hex()

    relay_manager = RelayManager()
    for relay in relays:
        relay_manager.add_relay(relay)

    for relay in relays:
        print(f"Sending deletion requests to {relay}")

        # Delete relay list (kind 10002)
        send_deletion_request(relay_manager, private_key, event_id=public_key)

        # Delete all events
        send_deletion_request(relay_manager, private_key, pubkey=public_key)

    relay_manager.run_sync()
    print("Deletion requests sent to all specified relays.")
    relay_manager.close_connections()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove Nostr profile")
    parser.add_argument("nsec", help="Private key (nsec)")
    parser.add_argument("relays", nargs="+", help="List of relays")

    args = parser.parse_args()
    remove_nostr_profile(args.nsec, args.relays)
