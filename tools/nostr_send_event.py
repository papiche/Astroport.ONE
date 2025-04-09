#!/usr/bin/env python3
import sys
import json
import argparse
import time
import asyncio  # Import asyncio
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey

async def send_nostr_event(private_key, kind, content, relays, timeout, tags, connect_timeout):  # Make function async
    try:
        print("🔌 Initializing relay manager...")
        relay_manager = RelayManager()

        # Add relays with verbose output
        print("🏗️ Adding relays:")
        for relay in relays:
            print(f"   - {relay}")
            relay_manager.add_relay(relay)

        # Open connections with timeout control
        print(f"\n⏳ Opening connections (timeout: {connect_timeout}s)...")
        connection_start = time.time()
        relay_manager.open_connections()

        # Wait for connections to establish asynchronously
        connected = False
        while time.time() - connection_start < connect_timeout:
            connected_relays = [url for url, r in relay_manager.relays.items() if r.connected]
            if connected_relays:
                print(f"\n✅ Connected to {len(connected_relays)}/{len(relays)} relays:")
                for url in connected_relays:
                    print(f"   - {url}")
                connected = True
                break
            await asyncio.sleep(0.1)  # Use asyncio.sleep for non-blocking delay
            print(".", end="", flush=True)

        if not connected:
            print(f"\n❌ Failed to connect to any relay within {connect_timeout} seconds")
            relay_manager.close_connections()
            return False

        # Create and sign event
        private_key = PrivateKey.from_nsec(private_key)

        event_tags = []
        for tag in tags:
            key, value = tag.split(":", 1)
            event_tags.append([key, value])

        event = Event(kind=kind, content=content, tags=event_tags)
        private_key.sign_event(event)

        print("\n📝 Event details:")
        print(f"   - ID: {event.id}")
        print(f"   - Kind: {kind}")
        print(f"   - Content: {content[:50]}... ({len(content)} chars)")
        print(f"   - Tags: {event.tags}")
        print(f"   - Pubkey: {event.pubkey}")

        # Publish event
        print(f"\n📤 Publishing to {len(connected_relays)} relays...")
        relay_manager.publish_event(event)

        # Wait for responses with timeout asynchronously
        print(f"\n⏳ Waiting for responses (timeout: {timeout}s)...")
        publish_start = time.time()
        responses_received = 0
        last_print = time.time()

        while time.time() - publish_start < timeout:
            # relay_manager.run_sync() # No longer needed in non-blocking context - remove this line

            # Instead of run_sync, periodically check for responses and run relay_manager.run()
            relay_manager.run()  # Let relay manager process network events in the background

            # Print status periodically
            if time.time() - last_print > 1:
                responses = sum(1 for r in relay_manager.relays.values() if r.response_received)
                print(f"   - Responses: {responses}/{len(connected_relays)}", end="\r")
                last_print = time.time()

            if event.id in relay_manager.sent_events:
                responses_received = sum(1 for r in relay_manager.relays.values() if r.response_received)
                break
            await asyncio.sleep(0.1) # Use asyncio.sleep for non-blocking delay

        relay_manager.close_connections()

        if responses_received > 0:
            print(f"\n✅ Success! Event published to {responses_received} relays")
            print(f"   - Event ID: {event.id}")
            return True
        else:
            print("\n❌ Failed to receive any response from relays")
            return False

    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user")
        if 'relay_manager' in locals():
            relay_manager.close_connections()
        return False
    except Exception as e:
        print(f"\n⚠️ Error: {type(e).__name__}: {str(e)}")
        if 'relay_manager' in locals():
            relay_manager.close_connections()
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Send a Nostr event")
    parser.add_argument("private_key", help="Private key (nsec)")
    parser.add_argument("kind", type=int, help="Event kind")
    parser.add_argument("content", help="Event content")
    parser.add_argument("--relay", type=str, action="append", default=[
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.copylaradio.com"
    ], help="Relay URL (can be used multiple times)")
    parser.add_argument("--timeout", type=int, default=30, help="Max wait time for event confirmation (seconds)")
    parser.add_argument("--connect-timeout", type=int, default=10, help="Max wait time for relay connections (seconds)")
    parser.add_argument("--tags", type=str, action="append", default=[], help="Event tags (format: 'type:value')")

    args = parser.parse_args()

    success = asyncio.run(send_nostr_event( # Run the async function using asyncio.run
        args.private_key,
        args.kind,
        args.content,
        args.relay,
        args.timeout,
        args.tags,
        args.connect_timeout
    ))

    sys.exit(0 if success else 1)
