#!/usr/bin/env python3
"""
Nostr Cooperative Config DID Manager (Kind 30800)

Fetches and publishes cooperative configuration as a DID document
on NOSTR relays. Uses parameterized replaceable events (kind 30800)
with d-tag "cooperative-config".

Usage:
    python nostr_cooperative_did.py fetch --relay ws://127.0.0.1:7777 --pubkey <hex>
    python nostr_cooperative_did.py publish --keyfile ~/.zen/game/uplanet.G1.nostr --config '{"key": "value"}'

The configuration is stored encrypted with UPLANETNAME for security.
All machines in the IPFS swarm can access the same configuration.
"""

import sys
import json
import argparse
import time
import os
import hashlib
import base64
from pathlib import Path

try:
    import websocket
    from pynostr.event import Event
    from pynostr.key import PrivateKey
except ImportError:
    print("Required packages missing. Install with: pip install websocket-client pynostr")
    sys.exit(1)

# Configuration
COOP_CONFIG_KIND = 30800
COOP_CONFIG_D_TAG = "cooperative-config"
DEFAULT_RELAYS = [
    "ws://127.0.0.1:7777",
    "wss://relay.copylaradio.com"
]

CONNECT_TIMEOUT = 10
PUBLISH_TIMEOUT = 30
FETCH_TIMEOUT = 15


class NostrCooperativeConfig:
    """Manages cooperative configuration via NOSTR DID"""
    
    def __init__(self, relays=None):
        self.relays = relays or DEFAULT_RELAYS
    
    def load_keyfile(self, keyfile_path):
        """Load NSEC/NPUB/HEX from keyfile.
        Accepts format: NSEC=...; NPUB=...; HEX=... (one line or multiple lines).
        """
        keyfile = Path(keyfile_path).expanduser()
        if not keyfile.exists():
            raise FileNotFoundError(f"Keyfile not found: {keyfile}")
        
        content = keyfile.read_text().strip()
        keys = {}
        
        # Parse semicolon-separated format (NSEC=...; NPUB=...; HEX=...)
        for part in content.replace('\n', ' ').split(';'):
            part = part.strip()
            if '=' in part:
                key, value = part.split('=', 1)
                key = key.strip()
                value = value.strip().rstrip(';').strip()
                if key and value:
                    keys[key] = value
        
        return keys
    
    def fetch_config(self, pubkey, d_tag=COOP_CONFIG_D_TAG):
        """Fetch cooperative config from NOSTR relays"""
        
        # Create subscription filter
        subscription_filter = {
            "kinds": [COOP_CONFIG_KIND],
            "authors": [pubkey],
            "#d": [d_tag],
            "limit": 1
        }
        
        subscription_id = f"coop_config_{int(time.time())}"
        request = json.dumps(["REQ", subscription_id, subscription_filter])
        
        for relay_url in self.relays:
            try:
                print(f"🔍 Querying relay: {relay_url}", file=sys.stderr)
                
                ws = websocket.create_connection(relay_url, timeout=CONNECT_TIMEOUT)
                ws.send(request)
                
                start_time = time.time()
                events = []
                
                while time.time() - start_time < FETCH_TIMEOUT:
                    try:
                        ws.settimeout(2.0)
                        response = ws.recv()
                        
                        if response:
                            data = json.loads(response)
                            
                            if data[0] == "EVENT" and data[1] == subscription_id:
                                events.append(data[2])
                            elif data[0] == "EOSE":
                                # End of stored events
                                break
                            elif data[0] == "CLOSED":
                                break
                    except websocket.WebSocketTimeoutException:
                        continue
                    except Exception as e:
                        print(f"⚠️  Error receiving: {e}", file=sys.stderr)
                        break
                
                # Close subscription
                ws.send(json.dumps(["CLOSE", subscription_id]))
                ws.close()
                
                if events:
                    # Return the most recent event's content
                    events.sort(key=lambda x: x.get('created_at', 0), reverse=True)
                    content = events[0].get('content', '{}')
                    print(f"✅ Found config from relay", file=sys.stderr)
                    return content
                    
            except Exception as e:
                print(f"⚠️  Failed to query {relay_url}: {e}", file=sys.stderr)
                continue
        
        print("❌ No config found on any relay", file=sys.stderr)
        return "{}"
    
    def publish_config(self, keyfile_path, config_json, d_tag=COOP_CONFIG_D_TAG):
        """Publish cooperative config to NOSTR relays"""
        
        # Load keys
        keys = self.load_keyfile(keyfile_path)
        nsec = keys.get('NSEC', '')
        
        if not nsec:
            raise ValueError("NSEC not found in keyfile")
        
        # Parse private key
        if nsec.startswith('nsec'):
            private_key = PrivateKey.from_nsec(nsec)
        else:
            private_key = PrivateKey(bytes.fromhex(nsec))
        
        pubkey_hex = private_key.public_key.hex()
        
        # Validate JSON
        try:
            config_obj = json.loads(config_json)
            # Re-serialize to ensure valid JSON
            config_json = json.dumps(config_obj, separators=(',', ':'))
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON config: {e}")
        
        # Create event
        created_at = int(time.time())
        
        tags = [
            ["d", d_tag],
            ["t", "cooperative-config"],
            ["t", "uplanet"],
            ["t", "encrypted"]
        ]
        
        # Create and sign event
        event = Event(
            kind=COOP_CONFIG_KIND,
            content=config_json,
            tags=tags,
            created_at=created_at,
            pub_key=pubkey_hex
        )
        
        private_key.sign_event(event)
        
        # Serialize event
        event_json = json.dumps(["EVENT", event.to_dict()])
        
        # Publish to relays
        success_count = 0
        
        for relay_url in self.relays:
            try:
                print(f"📤 Publishing to: {relay_url}", file=sys.stderr)
                
                ws = websocket.create_connection(relay_url, timeout=CONNECT_TIMEOUT)
                ws.send(event_json)
                
                # Wait for OK response
                start_time = time.time()
                
                while time.time() - start_time < PUBLISH_TIMEOUT:
                    try:
                        ws.settimeout(2.0)
                        response = ws.recv()
                        
                        if response:
                            data = json.loads(response)
                            
                            if data[0] == "OK":
                                if data[2]:  # Success
                                    print(f"✅ Published to {relay_url}", file=sys.stderr)
                                    success_count += 1
                                else:
                                    print(f"⚠️  Rejected by {relay_url}: {data[3] if len(data) > 3 else 'unknown reason'}", file=sys.stderr)
                                break
                    except websocket.WebSocketTimeoutException:
                        continue
                    except Exception as e:
                        print(f"⚠️  Error receiving: {e}", file=sys.stderr)
                        break
                
                ws.close()
                
            except Exception as e:
                print(f"⚠️  Failed to publish to {relay_url}: {e}", file=sys.stderr)
                continue
        
        if success_count > 0:
            print(f"✅ Config published to {success_count} relay(s)", file=sys.stderr)
            return {
                "success": True,
                "event_id": event.id,
                "pubkey": pubkey_hex,
                "relays_success": success_count
            }
        else:
            print("❌ Failed to publish to any relay", file=sys.stderr)
            return {
                "success": False,
                "error": "Failed to publish to any relay"
            }


def main():
    parser = argparse.ArgumentParser(
        description="Nostr Cooperative Config DID Manager"
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Fetch command
    fetch_parser = subparsers.add_parser('fetch', help='Fetch config from NOSTR')
    fetch_parser.add_argument('--relay', action='append', help='Relay URL(s)')
    fetch_parser.add_argument('--pubkey', required=True, help='Public key (hex)')
    fetch_parser.add_argument('--d-tag', default=COOP_CONFIG_D_TAG, help='D-tag identifier')
    
    # Publish command
    publish_parser = subparsers.add_parser('publish', help='Publish config to NOSTR')
    publish_parser.add_argument('--keyfile', required=True, help='Path to NOSTR keyfile')
    publish_parser.add_argument('--config', required=True, help='JSON config to publish')
    publish_parser.add_argument('--relay', action='append', help='Relay URL(s)')
    publish_parser.add_argument('--d-tag', default=COOP_CONFIG_D_TAG, help='D-tag identifier')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Initialize manager
    relays = args.relay if args.relay else DEFAULT_RELAYS
    manager = NostrCooperativeConfig(relays)
    
    if args.command == 'fetch':
        result = manager.fetch_config(args.pubkey, args.d_tag)
        print(result)
        
    elif args.command == 'publish':
        try:
            result = manager.publish_config(args.keyfile, args.config, args.d_tag)
            print(json.dumps(result))
            sys.exit(0 if result.get('success') else 1)
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
            sys.exit(1)


if __name__ == "__main__":
    main()
