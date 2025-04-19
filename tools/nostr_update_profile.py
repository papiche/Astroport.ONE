#!/bin/env python
import sys
import json
import argparse
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey
from pynostr.filters import Filters

def fetch_latest_profile_event(relay_manager, public_key):
    relay_manager.run_sync()
    flt = Filters([{"kinds": [0], "authors": [public_key]}])
    events = relay_manager.query_sync(flt)
    if events:
        return sorted(events, key=lambda e: e.created_at)[-1]
    return None

def update_metadata(original_content, known_args):
    original_metadata = json.loads(original_content) if original_content else {}
    metadata = original_metadata.copy()

    fields = ['name', 'about', 'picture', 'banner', 'nip05', 'website']
    for field in fields:
        val = getattr(known_args, field)
        if val is not None:
            if val == "":
                metadata.pop(field, None)
            else:
                metadata[field] = val

    metadata["bot"] = False
    return metadata

def merge_tags(existing_tags, new_args, unknown_args):
    tag_map = {}

    # Convert existing 'i' tags into a map: key -> value
    for tag in existing_tags or []:
        if tag[0] == "i" and ":" in tag[1]:
            k, v = tag[1].split(":", 1)
            tag_map[k] = v

    # Champs standards
    for k in ['g1pub', 'github', 'twitter', 'mastodon', 'telegram',
              'ipfs_gw', 'ipns_vault', 'zencard', 'tw_feed']:
        val = getattr(new_args, k)
        if val is not None:
            if val == "":
                tag_map.pop(k, None)
            else:
                tag_map[k] = val

    # Champs dynamiques (arguments inconnus)
    for i in range(0, len(unknown_args), 2):
        key = unknown_args[i].lstrip("-")
        if i+1 < len(unknown_args):
            val = unknown_args[i+1]
            if val == "":
                tag_map.pop(key, None)
            else:
                tag_map[key] = val

    # Reconstruire la liste de tags
    return [["i", f"{k}:{v}", ""] for k, v in tag_map.items()]

def nostr_update_profile(args, unknown_args):
    relay_manager = RelayManager()
    for relay in args.relays:
        relay_manager.add_relay(relay)

    private_key = PrivateKey.from_nsec(args.private_key)
    public_key = private_key.public_key.hex()

    print("Fetching current profile metadata...")
    current_event = fetch_latest_profile_event(relay_manager, public_key)

    original_content = current_event.content if current_event else "{}"
    original_tags = current_event.tags if current_event else []

    updated_metadata = update_metadata(original_content, args)
    updated_tags = merge_tags(original_tags, args, unknown_args)

    metadata_event = Event(kind=0, content=json.dumps(updated_metadata), tags=updated_tags)
    metadata_event.sign(private_key.hex())
    print("Publishing updated metadata...")
    relay_manager.publish_event(metadata_event)

    if args.relays:
        relay_list = {relay: {"read": True, "write": True} for relay in args.relays}
        relay_tags = [["r", relay] for relay in args.relays]
        relay_event = Event(kind=10002, content=json.dumps(relay_list), tags=relay_tags)
        relay_event.sign(private_key.hex())
        print("Publishing updated relay list...")
        relay_manager.publish_event(relay_event)

    relay_manager.run_sync()
    relay_manager.close_connections()
    print("Profile update complete!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update Nostr profile metadata", allow_abbrev=False)
    parser.add_argument("private_key", help="Private key (nsec)")
    parser.add_argument("relays", nargs="+", help="List of relays")

    # Champs connus
    parser.add_argument("--name", help="Name")
    parser.add_argument("--about", help="About")
    parser.add_argument("--picture", help="Avatar URL")
    parser.add_argument("--banner", help="Banner URL")
    parser.add_argument("--nip05", help="NIP-05 identifier")
    parser.add_argument("--website", help="Website URL")
    parser.add_argument("--g1pub", help="G1 Pubkey")
    parser.add_argument("--github", help="GitHub username")
    parser.add_argument("--twitter", help="Twitter handle")
    parser.add_argument("--mastodon", help="Mastodon handle")
    parser.add_argument("--telegram", help="Telegram handle")
    parser.add_argument("--ipfs_gw", help="IPFS Gateway URL")
    parser.add_argument("--ipns_vault", help="NOSTR Card IPNS vault key")
    parser.add_argument("--zencard", help="ZenCard wallet address")
    parser.add_argument("--tw_feed", help="TW Feed IPNS key")

    args, unknown_args = parser.parse_known_args()
    nostr_update_profile(args, unknown_args)
