#!/bin/env python
import sys
import json
import argparse
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey

def nostr_setup_profile(args):
    # Initialize relay manager
    relay_manager = RelayManager()
    for relay in args.relays:
        relay_manager.add_relay(relay)

    # Create private_key / public_key from nsec
    private_key = PrivateKey.from_nsec(args.private_key)
    public_key = private_key.public_key.hex()

    # Create metadata JSON
    metadata = {
        "name": args.name,
        "about": args.about,
        "picture": args.avatar_url,
        "banner": args.banner_url,
        "nip05": args.nip05,
        "website": args.website,
        "bot": False
    }

    # Prepare tags for external identities
    tags = []
    if args.g1pub:
        tags.append(["i", f"g1pub:{args.g1pub}", ""])
    if args.github:
        tags.append(["i", f"github:{args.github}", ""])
    if args.twitter:
        tags.append(["i", f"twitter:{args.twitter}", ""])
    if args.mastodon:
        tags.append(["i", f"mastodon:{args.mastodon}", ""])
    if args.telegram:
        tags.append(["i", f"telegram:{args.telegram}", ""])

    # Add extra tag if provided
    if args.ipfs_gw:
        tags.append(["i", f"ipfs_gw:{args.ipfs_gw}", ""])
    if args.tw_feed:
        tags.append(["i", f"tw_feed:{args.tw_feed}", ""])

    # Create and publish PROFILE + metadata event
    metadata_event = Event(kind=0, content=json.dumps(metadata), tags=tags)
    metadata_event.sign(private_key.hex())
    print("Publishing metadata event...")
    relay_manager.publish_event(metadata_event)

    # Create and publish PREFERED relay list event
    relay_list = {relay: {"read": True, "write": True} for relay in args.relays}
    relay_event = Event(kind=10002, content=json.dumps(relay_list))
    relay_event.sign(private_key.hex())
    print("Publishing relay list event...")
    relay_manager.publish_event(relay_event)

    # Run the relay manager
    relay_manager.run_sync()

    print("Nostr profile setup complete!")
    print(f"Public Key: {public_key}")

    # Close connections
    relay_manager.close_connections()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Setup Nostr profile")
    parser.add_argument("private_key", help="Private key (nsec)")
    parser.add_argument("name", help="Name")
    parser.add_argument("g1pub", help="G1 Pubkey")
    parser.add_argument("about", help="About")
    parser.add_argument("avatar_url", help="Avatar URL")
    parser.add_argument("banner_url", help="Banner URL")
    parser.add_argument("nip05", help="NIP-05 identifier")
    parser.add_argument("website", help="Website URL")
    parser.add_argument("github", help="GitHub URL")
    parser.add_argument("twitter", help="Twitter URL")
    parser.add_argument("mastodon", help="Mastodon URL")
    parser.add_argument("telegram", help="Telegram URL")
    parser.add_argument("relays", nargs="+", help="List of relays")
    parser.add_argument("--ipfs_gw", help="IPFS Gateway URL", default=None)
    parser.add_argument("--tw_feed", help="TW Feed IPNS key", default=None)

    args = parser.parse_args()
    nostr_setup_profile(args)
