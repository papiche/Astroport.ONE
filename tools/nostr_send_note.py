#!/usr/bin/env python3
"""
Nostr Event Sender - Universal Tool for All Event Kinds

This script sends various types of events to NOSTR relays.
Uses synchronous WebSocket connections with multi-relay support.

SECURITY: Uses keyfile parameter instead of passing keys directly.

Usage:
    python nostr_send_note.py --keyfile <path_to_.secret.nostr> --content <message> [OPTIONS]
    python nostr_send_note.py --help

Examples:
    # Simple text note (kind 1)
    python nostr_send_note.py --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr --content "Hello world!"
    
    # Reply to event
    python nostr_send_note.py --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr --content "Reply" --tags '[["e","event_id"],["p","pubkey"]]'
    
    # Ephemeral message
    python nostr_send_note.py --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr --content "Temp msg" --ephemeral 3600
    
    # Long-form content (kind 30023)
    python nostr_send_note.py --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr --content "# Article" --kind 30023 --tags '[["d","article-id"],["title","My Article"]]'
    
    # Authentication event (kind 22242)
    python nostr_send_note.py --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr --content "auth-challenge" --kind 22242
    
    # Profile badge (kind 30008)
    python nostr_send_note.py --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr --content '{"name":"Badge"}' --kind 30008 --tags '[["d","badge-id"]]'
    
    # Multiple relays
    python nostr_send_note.py --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr --content "Multi-relay" --relays ws://127.0.0.1:7777,wss://relay.copylaradio.com

Keyfile format (.secret.nostr):
    NSEC=nsec1...; NPUB=npub1...; HEX=...;
"""

import sys
import json
import argparse
import time
import os
import websocket
from pynostr.event import Event, EventKind
from pynostr.key import PrivateKey

DEFAULT_RELAYS = ["ws://127.0.0.1:7777"]
CONNECT_TIMEOUT = 10
PUBLISH_TIMEOUT = 30

# Common event kinds reference
EVENT_KINDS = {
    0: "Profile Metadata",
    1: "Text Note",
    3: "Contacts",
    4: "Encrypted Direct Message",
    5: "Event Deletion",
    6: "Repost",
    7: "Reaction",
    40: "Channel Creation",
    41: "Channel Metadata",
    42: "Channel Message",
    43: "Channel Hide Message",
    44: "Channel Mute User",
    1984: "Reporting",
    9734: "Zap Request",
    9735: "Zap",
    10000: "Mute List",
    10001: "Pin List",
    10002: "Relay List Metadata",
    22242: "Client Authentication",
    23194: "Wallet Info",
    23195: "Wallet Request",
    23196: "Wallet Response",
    24133: "Nostr Connect",
    27235: "HTTP Auth",
    30000: "Categorized People List",
    30001: "Categorized Bookmark List",
    30008: "Profile Badges",
    30009: "Badge Definition",
    30017: "Create or update a stall",
    30018: "Create or update a product",
    30023: "Long-form Content",
    30024: "Draft Long-form Content",
    30078: "Application-specific Data",
    30311: "Live Event",  # NIP-53 - Official Nostr standard
    30312: "ORE Meeting Space (NIP-101 UPlanet)",
    30313: "ORE Verification Meeting (NIP-101 UPlanet)",
    30315: "User Statuses",
    30402: "Classified Listing",
    30403: "Draft Classified Listing",
    30500: "Oracle Permit Definition (NIP-101 UPlanet)",
    30501: "Oracle Permit Request (NIP-101 UPlanet)",
    30502: "Oracle Permit Attestation (NIP-101 UPlanet)",
    30503: "Oracle Verifiable Credential (NIP-101 UPlanet)",
    30800: "DID Document (NIP-101 UPlanet)",  # Changed from 30311 to avoid conflict
    31922: "Date-Based Calendar Event",
    31923: "Time-Based Calendar Event",
    31924: "Calendar",
    31925: "Calendar Event RSVP",
    31989: "Handler recommendation",
    31990: "Handler information",
    34550: "Community Definition"
}

def load_keyfile(keyfile_path: str) -> str:
    """
    Load NSEC key from .secret.nostr file
    
    Expected format: NSEC=nsec1...; NPUB=npub1...; HEX=...;
    
    Returns:
        str: NSEC key
    """
    try:
        if not os.path.exists(keyfile_path):
            raise FileNotFoundError(f"Keyfile not found: {keyfile_path}")
        
        with open(keyfile_path, 'r') as f:
            content = f.read().strip()
        
        # Parse the keyfile format
        for part in content.split(';'):
            part = part.strip()
            if part.startswith('NSEC='):
                nsec = part[5:].strip()
                if nsec.startswith('nsec1'):
                    return nsec
                raise ValueError(f"Invalid NSEC format in keyfile: {nsec[:15]}...")
        
        raise ValueError("No NSEC key found in keyfile")
        
    except Exception as e:
        print(f"❌ Error loading keyfile: {e}")
        raise

class NostrWebSocketClient:
    """Synchronous NOSTR WebSocket client"""
    
    def __init__(self, relay_url: str):
        self.relay_url = relay_url
        self.ws = None
        self.connected = False
        self.response_received = False
        self.response_data = None
        self.relay_name = relay_url.split('/')[-1] or relay_url
        
    def connect(self, timeout: int = CONNECT_TIMEOUT) -> bool:
        """Connect to the relay"""
        try:
            self.ws = websocket.create_connection(
                self.relay_url,
                timeout=timeout
            )
            self.connected = True
            return True
        except Exception as e:
            print(f"❌ Failed to connect to {self.relay_name}: {e}")
            return False
    
    def send_event(self, event_json: str) -> bool:
        """Send an event to the relay"""
        if not self.connected:
            return False
        
        try:
            self.ws.send(event_json)
            return True
        except Exception as e:
            print(f"❌ Failed to send event to {self.relay_name}: {e}")
            return False
    
    def wait_for_response(self, timeout: int = PUBLISH_TIMEOUT) -> bool:
        """Wait for OK response from relay"""
        if not self.connected:
            return False
        
        try:
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                try:
                    # Set a short timeout for receiving
                    self.ws.settimeout(1.0)
                    response = self.ws.recv()
                    
                    if response:
                        if '"OK"' in response or '"ok"' in response:
                            return True
                        elif '"CLOSED"' in response:
                            return False
                except websocket.WebSocketTimeoutException:
                    # Timeout on receive, continue waiting
                    continue
                except Exception as e:
                    break
            
            return False
            
        except Exception as e:
            return False
    
    def close(self):
        """Close the connection"""
        if self.ws:
            try:
                self.ws.close()
            except:
                pass
        self.connected = False

def send_nostr_event(keyfile_path: str, message: str, 
                     relay_urls: list = None,
                     tags: list = None,
                     ephemeral_duration: int = None,
                     kind: int = EventKind.TEXT_NOTE) -> dict:
    """
    Send a Nostr event to multiple relays (synchronous version).
    
    Args:
        keyfile_path: Path to .secret.nostr file
        message: Message content to send
        relay_urls: List of NOSTR relay URLs (default: DEFAULT_RELAYS)
        tags: Optional list of tags (e.g., [["e", "event_id"], ["p", "pubkey"]])
        ephemeral_duration: Optional duration in seconds for ephemeral messages
        kind: Event kind (default: 1 for text notes)
        
    Returns:
        dict: {"success": bool, "event_id": str, "relays_success": int, "relays_total": int}
    """
    clients = []
    result = {
        "success": False,
        "event_id": None,
        "relays_success": 0,
        "relays_total": 0,
        "errors": []
    }
    
    try:
        # Load key from keyfile
        sender_nsec = load_keyfile(keyfile_path)
        
        # Create private key object
        priv_key_obj = PrivateKey.from_nsec(sender_nsec)
        
        # Create the event
        if tags is None:
            tags = []
        
        # Add ephemeral tag if duration is specified
        if ephemeral_duration is not None:
            tags.append(["expiration", str(int(time.time()) + ephemeral_duration)])
        
        event = Event(
            kind=kind,
            content=message,
            tags=tags,
            pubkey=priv_key_obj.public_key.hex()
        )
        
        # Sign the event
        event.sign(priv_key_obj.hex())
        
        result["event_id"] = event.id
        
        # Prepare event JSON
        event_json = json.dumps(["EVENT", event.to_dict()])
        
        # Use default relays if none provided
        if relay_urls is None or len(relay_urls) == 0:
            relay_urls = DEFAULT_RELAYS
        
        result["relays_total"] = len(relay_urls)
        
        # Get kind name
        kind_name = EVENT_KINDS.get(kind, f"Custom Kind {kind}")
        
        print(f"\n📝 Event details:")
        print(f"   - ID: {event.id}")
        print(f"   - Kind: {kind} ({kind_name})")
        print(f"   - Content length: {len(message)} chars")
        if len(tags) > 0:
            print(f"   - Tags: {len(tags)} tag(s)")
        print(f"   - Sender pubkey: {event.pubkey[:16]}...")
        print(f"   - Target relays: {len(relay_urls)}")
        
        # Connect to all relays
        print(f"\n🔌 Connecting to {len(relay_urls)} relay(s)...")
        for relay_url in relay_urls:
            client = NostrWebSocketClient(relay_url)
            if client.connect():
                clients.append(client)
                print(f"   ✅ {client.relay_name}")
            else:
                result["errors"].append(f"Failed to connect to {relay_url}")
        
        if len(clients) == 0:
            print("\n❌ Failed to connect to any relay")
            return result
        
        print(f"\n✅ Connected to {len(clients)}/{len(relay_urls)} relay(s)")
        
        # Send to all connected relays
        print(f"\n📤 Publishing event...")
        for client in clients:
            if client.send_event(event_json):
                if client.wait_for_response():
                    result["relays_success"] += 1
                    print(f"   ✅ {client.relay_name}")
                else:
                    print(f"   ⚠️  {client.relay_name} (no confirmation)")
        
        result["success"] = result["relays_success"] > 0
        
        if result["success"]:
            print(f"\n✅ Event published successfully to {result['relays_success']}/{result['relays_total']} relay(s)!")
            print(f"   - Event ID: {event.id}")
        else:
            print(f"\n❌ Failed to publish event to any relay")
        
        return result

    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user.")
        result["errors"].append("Cancelled by user")
        return result
    except Exception as e:
        print(f"\n⚠️ Error: {type(e).__name__}: {str(e)}")
        result["errors"].append(str(e))
        import traceback
        traceback.print_exc()
        return result
    finally:
        for client in clients:
            client.close()

def main():
    parser = argparse.ArgumentParser(
        description="Send various types of events via NOSTR (synchronous, multi-relay)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    # Required arguments (unless --list-kinds is used)
    parser.add_argument("--keyfile", "-k",
                       help="Path to .secret.nostr file (format: NSEC=nsec1...; NPUB=npub1...; HEX=...;)")
    parser.add_argument("--content", "-c",
                       help="Event content to send")
    
    # Optional arguments
    parser.add_argument("--relays", "-r", 
                       help=f"Comma-separated relay URLs (default: {','.join(DEFAULT_RELAYS)})")
    parser.add_argument("--tags", "-t", default="[]",
                       help='Tags as JSON array (e.g., [["e","id"],["p","pubkey"],["t","hashtag"]])')
    parser.add_argument("--ephemeral", "-e", type=int, metavar="SECONDS",
                       help="Make message ephemeral with specified duration in seconds")
    parser.add_argument("--kind", type=int, default=1, metavar="KIND",
                       help="Event kind (default: 1). Common: 0=profile, 1=note, 7=reaction, 30023=article, 22242=auth")
    parser.add_argument("--list-kinds", action="store_true",
                       help="List all supported event kinds and exit")
    parser.add_argument("--json", action="store_true",
                       help="Output result as JSON")
    
    args = parser.parse_args()

    # List kinds if requested (doesn't require keyfile or content)
    if args.list_kinds:
        print("\n📋 Supported Nostr Event Kinds:\n")
        for kind_num in sorted(EVENT_KINDS.keys()):
            print(f"   {kind_num:5d} : {EVENT_KINDS[kind_num]}")
        sys.exit(0)

    # Validate required arguments
    if not args.keyfile:
        print("Error: --keyfile is required", file=sys.stderr)
        sys.exit(1)
    
    if not args.content:
        print("Error: --content is required", file=sys.stderr)
        sys.exit(1)
    
    # Validate keyfile
    if not os.path.exists(args.keyfile):
        print(f"Error: Keyfile not found: {args.keyfile}", file=sys.stderr)
        sys.exit(1)
    
    # Allow empty content for kind 3 (contacts) per NIP-02
    if not args.content.strip() and args.kind != 3:
        print("Error: Content cannot be empty", file=sys.stderr)
        sys.exit(1)
    
    # Parse relays
    relay_urls = None
    if args.relays:
        relay_urls = [r.strip() for r in args.relays.split(',') if r.strip()]
        if len(relay_urls) == 0:
            relay_urls = None
    
    # Parse tags
    try:
        tags = json.loads(args.tags)
        if not isinstance(tags, list):
            raise ValueError("Tags must be a JSON array")
    except Exception as e:
        print(f"Error: Invalid tags JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Send the event
    result = send_nostr_event(
        args.keyfile,
        args.content,
        relay_urls,
        tags,
        args.ephemeral,
        args.kind
    )
    
    # Output result
    if args.json:
        print(json.dumps(result, indent=2))
    
    sys.exit(0 if result["success"] else 1)

if __name__ == "__main__":
    main()
