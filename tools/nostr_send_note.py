#!/usr/bin/env python3
"""
Nostr Public Note Sender (Kind 1)

This script sends public notes (kind 1) to NOSTR relays.
Uses synchronous WebSocket connections.

Usage:
    python nostr_send_note.py <sender_nsec> <message> <relay_url> [tags_json]
    python nostr_send_note.py --help

Example:
    python nostr_send_note.py nsec1xyz... "Hello world!" wss://relay.copylaradio.com
    python nostr_send_note.py nsec1xyz... "Reply to event" wss://relay.copylaradio.com '[["e","event_id"],["p","pubkey"]]'
"""

import sys
import json
import argparse
import time
import websocket
from pynostr.event import Event, EventKind
from pynostr.key import PrivateKey

DEFAULT_RELAY = "ws://127.0.0.1:7777"
CONNECT_TIMEOUT = 10
PUBLISH_TIMEOUT = 30

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
            print("📤 Sending event to relay...")
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
                            print("✅ Note accepted by relay")
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

def send_public_note_sync(sender_nsec: str, message: str, 
                         relay_url: str = DEFAULT_RELAY,
                         tags: list = None) -> bool:
    """
    Send a public note (kind 1) to a NOSTR relay (synchronous version).
    
    Args:
        sender_nsec: NSEC private key of the sender
        message: Message content to send
        relay_url: NOSTR relay URL
        tags: Optional list of tags (e.g., [["e", "event_id"], ["p", "pubkey"]])
        
    Returns:
        bool: True if note was sent successfully, False otherwise
    """
    client = None
    try:
        # Create private key object
        priv_key_obj = PrivateKey.from_nsec(sender_nsec)
        
        # Create the event
        if tags is None:
            tags = []
        
        event = Event(
            kind=EventKind.TEXT_NOTE,
            content=message,
            tags=tags,
            pubkey=priv_key_obj.public_key.hex()
        )
        
        # Sign the event
        event.sign(priv_key_obj.hex())

        print(f"\n📝 Event details:")
        print(f"   - ID: {event.id}")
        print(f"   - Kind: {event.kind} (Public Note)")
        print(f"   - Content length: {len(message)} chars")
        print(f"   - Tags: {tags}")
        print(f"   - Sender: {event.pubkey}")

        # Create WebSocket client and connect
        client = NostrWebSocketClient(relay_url)
        if not client.connect():
            return False
        
        # Send the event
        event_json = json.dumps(["EVENT", event.to_dict()])
        if not client.send_event(event_json):
            return False
        
        # Wait for response
        success = client.wait_for_response()
        
        if success:
            print(f"\n✅ Note published successfully!")
            print(f"   - Event ID: {event.id}")
        else:
            print(f"\n❌ Failed to publish note")
        
        return success

    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user.")
        return False
    except Exception as e:
        print(f"\n⚠️ Error: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        if client:
            client.close()

def main():
    parser = argparse.ArgumentParser(
        description="Send public notes (kind 1) via NOSTR (synchronous)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("sender_nsec", help="NSEC private key of the sender")
    parser.add_argument("message", help="Note content to send")
    parser.add_argument("relay_url", nargs="?", default=DEFAULT_RELAY, 
                       help=f"Relay URL (default: {DEFAULT_RELAY})")
    parser.add_argument("tags_json", nargs="?", default="[]",
                       help='Tags as JSON array (e.g., [["e","id"],["p","pubkey"]])')
    
    args = parser.parse_args()

    # Validate inputs
    if not args.sender_nsec.startswith("nsec1"):
        print("Error: Sender key must be in NSEC format (nsec1...)", file=sys.stderr)
        sys.exit(1)
    
    if not args.message.strip():
        print("Error: Message cannot be empty", file=sys.stderr)
        sys.exit(1)
    
    # Parse tags
    try:
        tags = json.loads(args.tags_json)
        if not isinstance(tags, list):
            raise ValueError("Tags must be a JSON array")
    except Exception as e:
        print(f"Error: Invalid tags JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Send the note
    success = send_public_note_sync(
        args.sender_nsec,
        args.message,
        args.relay_url,
        tags
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

