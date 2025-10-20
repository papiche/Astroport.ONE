#!/usr/bin/env python3
"""
Nostr DID Document Publisher (Kind 30311)

This script publishes DID documents as parameterized replaceable events (kind 30311)
to NOSTR relays. Each new version automatically replaces the previous one.

Usage:
    python nostr_publish_did.py <sender_nsec> <did_json_file> [relay_urls...]
    python nostr_publish_did.py --help

Example:
    python nostr_publish_did.py nsec1xyz... ~/.zen/game/nostr/user@example.com/did.json ws://127.0.0.1:7777
    python nostr_publish_did.py nsec1xyz... did.json ws://127.0.0.1:7777 wss://relay.copylaradio.com
"""

import sys
import json
import argparse
import time
import websocket
from pathlib import Path
from pynostr.event import Event
from pynostr.key import PrivateKey

# Default relays (UPlanet ecosystem)
DEFAULT_RELAYS = [
    "ws://127.0.0.1:7777",           # Local Astroport relay
    "wss://relay.copylaradio.com"    # UPlanet ORIGIN relay
]

CONNECT_TIMEOUT = 10
PUBLISH_TIMEOUT = 30

# Kind 30311: Parameterized Replaceable Event for general-purpose JSON
# Using tag ["d", "did"] to identify DID documents
DID_EVENT_KIND = 30311
DID_TAG_IDENTIFIER = "did"

class NostrWebSocketClient:
    """Synchronous NOSTR WebSocket client"""
    
    def __init__(self, relay_url: str):
        self.relay_url = relay_url
        self.ws = None
        self.connected = False
        self.response_received = False
        self.response_data = None
        
    def connect(self, timeout: int = CONNECT_TIMEOUT) -> bool:
        """Connect to the relay"""
        try:
            print(f"🔌 Connecting to relay: {self.relay_url}")
            self.ws = websocket.create_connection(
                self.relay_url,
                timeout=timeout
            )
            self.connected = True
            print("✅ Connected to relay")
            return True
        except Exception as e:
            print(f"❌ Failed to connect: {e}")
            return False
    
    def send_event(self, event_json: str) -> bool:
        """Send an event to the relay"""
        if not self.connected:
            print("❌ Not connected to relay")
            return False
        
        try:
            print("📤 Sending DID event to relay...")
            self.ws.send(event_json)
            return True
        except Exception as e:
            print(f"❌ Failed to send event: {e}")
            return False
    
    def wait_for_response(self, timeout: int = PUBLISH_TIMEOUT) -> bool:
        """Wait for OK response from relay"""
        if not self.connected:
            return False
        
        try:
            print(f"⏳ Waiting for response (timeout: {timeout}s)...")
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                try:
                    # Set a short timeout for receiving
                    self.ws.settimeout(1.0)
                    response = self.ws.recv()
                    
                    if response:
                        print(f"📨 Received: {response}")
                        if '"OK"' in response:
                            print("✅ DID accepted by relay")
                            return True
                        elif '"CLOSED"' in response:
                            print("❌ Relay closed connection")
                            return False
                except websocket.WebSocketTimeoutException:
                    # Timeout on receive, continue waiting
                    continue
                except Exception as e:
                    print(f"⚠️ Error receiving: {e}")
                    break
            
            print("❌ No OK response received within timeout")
            return False
            
        except Exception as e:
            print(f"❌ Error waiting for response: {e}")
            return False
    
    def close(self):
        """Close the connection"""
        if self.ws:
            try:
                self.ws.close()
            except:
                pass
        self.connected = False

def validate_did_json(did_content: str) -> bool:
    """
    Validate that the DID document is valid JSON and contains required fields
    
    Args:
        did_content: JSON string of the DID document
        
    Returns:
        bool: True if valid, False otherwise
    """
    try:
        did_obj = json.loads(did_content)
        
        # Check required DID fields according to W3C DID spec
        required_fields = ["id", "verificationMethod"]
        
        for field in required_fields:
            if field not in did_obj:
                print(f"❌ Missing required field: {field}")
                return False
        
        print("✅ DID document structure valid")
        return True
        
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON: {e}")
        return False

def publish_did_to_nostr(sender_nsec: str, did_json_path: str, 
                          relay_urls: list = None) -> tuple[bool, str]:
    """
    Publish a DID document (kind 30311) to NOSTR relays.
    
    Args:
        sender_nsec: NSEC private key of the DID owner
        did_json_path: Path to the DID JSON document
        relay_urls: List of relay URLs (defaults to DEFAULT_RELAYS)
        
    Returns:
        tuple: (success: bool, event_id: str)
    """
    if relay_urls is None:
        relay_urls = DEFAULT_RELAYS
    
    try:
        # Read DID document
        did_path = Path(did_json_path)
        if not did_path.exists():
            print(f"❌ DID file not found: {did_json_path}")
            return False, ""
        
        with open(did_path, 'r') as f:
            did_content = f.read().strip()
        
        # Validate DID
        if not validate_did_json(did_content):
            return False, ""
        
        # Minify JSON for efficient storage
        did_content = json.dumps(json.loads(did_content), separators=(',', ':'))
        
        # Create private key object
        priv_key_obj = PrivateKey.from_nsec(sender_nsec)
        pubkey_hex = priv_key_obj.public_key.hex()
        
        # Extract DID ID for display
        did_obj = json.loads(did_content)
        did_id = did_obj.get("id", "unknown")
        
        # Extract email from DID metadata for additional context
        email = did_obj.get("metadata", {}).get("email", "")
        
        # Create tags for the event (DID Nostr spec compliant)
        tags = [
            ["d", DID_TAG_IDENTIFIER],           # Identifier tag (makes it replaceable)
            ["t", "uplanet"],                     # UPlanet ecosystem tag
            ["t", "did-document"],                # Type tag
            ["published_at", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())],
            ["schema", "https://www.w3.org/TR/did-core/"]
        ]
        
        # Add email tag if available
        if email:
            tags.append(["email", email])
        
        # Create the event (kind 30311 = Parameterized Replaceable Event)
        event = Event(
            kind=DID_EVENT_KIND,
            content=did_content,
            tags=tags,
            pubkey=pubkey_hex
        )
        
        # Sign the event
        event.sign(priv_key_obj.hex())

        print(f"\n📝 DID Event details:")
        print(f"   - Event ID: {event.id}")
        print(f"   - Kind: {event.kind} (Parameterized Replaceable)")
        print(f"   - DID ID: {did_id}")
        print(f"   - Content size: {len(did_content)} bytes")
        print(f"   - Tags: {len(tags)} tags")
        print(f"   - Owner pubkey: {pubkey_hex[:16]}...")
        print(f"   - Target relays: {len(relay_urls)}")

        # Publish to all relays
        success_count = 0
        failed_relays = []
        
        for relay_url in relay_urls:
            print(f"\n📡 Publishing to: {relay_url}")
            client = None
            try:
                client = NostrWebSocketClient(relay_url)
                if not client.connect():
                    failed_relays.append(relay_url)
                    continue
                
                # Send the event
                event_json = json.dumps(["EVENT", event.to_dict()])
                if not client.send_event(event_json):
                    failed_relays.append(relay_url)
                    continue
                
                # Wait for response
                if client.wait_for_response():
                    success_count += 1
                    print(f"✅ Successfully published to {relay_url}")
                else:
                    failed_relays.append(relay_url)
                    print(f"❌ Failed to get confirmation from {relay_url}")
                
            except Exception as e:
                print(f"❌ Error with relay {relay_url}: {e}")
                failed_relays.append(relay_url)
            finally:
                if client:
                    client.close()
        
        # Summary
        print(f"\n{'='*60}")
        print(f"📊 Publication Summary:")
        print(f"   - Total relays: {len(relay_urls)}")
        print(f"   - Successful: {success_count}")
        print(f"   - Failed: {len(failed_relays)}")
        
        if failed_relays:
            print(f"   - Failed relays: {', '.join(failed_relays)}")
        
        if success_count > 0:
            print(f"\n✅ DID published successfully to {success_count}/{len(relay_urls)} relay(s)")
            print(f"   - Event ID: {event.id}")
            print(f"   - DID ID: {did_id}")
            print(f"   - Replaceable: Yes (kind {DID_EVENT_KIND} with d-tag)")
            return True, event.id
        else:
            print(f"\n❌ Failed to publish DID to any relay")
            return False, ""

    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user.")
        return False, ""
    except Exception as e:
        print(f"\n⚠️ Error: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        return False, ""

def main():
    parser = argparse.ArgumentParser(
        description="Publish DID documents via NOSTR as kind 30311 events",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("sender_nsec", help="NSEC private key of the DID owner")
    parser.add_argument("did_json_file", help="Path to DID JSON document")
    parser.add_argument("relay_urls", nargs="*", default=DEFAULT_RELAYS,
                       help=f"Relay URLs (default: {', '.join(DEFAULT_RELAYS)})")
    
    parser.add_argument("--validate-only", action="store_true",
                       help="Only validate the DID document without publishing")
    
    args = parser.parse_args()

    # Validate inputs
    if not args.sender_nsec.startswith("nsec1"):
        print("Error: Sender key must be in NSEC format (nsec1...)", file=sys.stderr)
        sys.exit(1)
    
    # Check if file exists
    if not Path(args.did_json_file).exists():
        print(f"Error: DID file not found: {args.did_json_file}", file=sys.stderr)
        sys.exit(1)
    
    # Validate only mode
    if args.validate_only:
        with open(args.did_json_file, 'r') as f:
            did_content = f.read()
        success = validate_did_json(did_content)
        sys.exit(0 if success else 1)
    
    # Publish the DID
    success, event_id = publish_did_to_nostr(
        args.sender_nsec,
        args.did_json_file,
        args.relay_urls if args.relay_urls else DEFAULT_RELAYS
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

