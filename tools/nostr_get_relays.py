#!/usr/bin/env python3
"""
Nostr Get User Relays (Kind 10002)

This script fetches a user's preferred relays from NOSTR (kind 10002 event - NIP-65).
Uses synchronous WebSocket connections.

Usage:
    python nostr_get_relays.py <hex_pubkey> [query_relay]
    python nostr_get_relays.py --help

Example:
    python nostr_get_relays.py abc123... wss://relay.copylaradio.com

Output format (one relay per line):
    wss://relay1.com
    wss://relay2.com
"""

import sys
import json
import argparse
import time
import websocket

DEFAULT_RELAY = "wss://relay.copylaradio.com"
CONNECT_TIMEOUT = 10
QUERY_TIMEOUT = 15

class NostrRelayFetcher:
    """Fetch NOSTR relay list (kind 10002) for a user"""
    
    def __init__(self, relay_url: str):
        self.relay_url = relay_url
        self.ws = None
        self.connected = False
        self.relays = []
        self.event_received = False
        
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
            print(f"❌ Failed to connect to {self.relay_url}: {e}", file=sys.stderr)
            return False
    
    def fetch_relay_list(self, hex_pubkey: str, timeout: int = QUERY_TIMEOUT) -> list:
        """Fetch relay list for a given pubkey"""
        if not self.connected:
            return []
        
        try:
            # Create subscription filter for kind 10002 events
            subscription_id = f"relay-list-{int(time.time())}"
            req_message = json.dumps([
                "REQ",
                subscription_id,
                {
                    "authors": [hex_pubkey],
                    "kinds": [10002],
                    "limit": 1
                }
            ])
            
            # Send the REQ message
            self.ws.send(req_message)
            
            # Wait for response
            start_time = time.time()
            while time.time() - start_time < timeout:
                try:
                    self.ws.settimeout(1.0)
                    response = self.ws.recv()
                    
                    if response:
                        data = json.loads(response)
                        
                        # Check if it's an EVENT response
                        if data[0] == "EVENT" and data[1] == subscription_id:
                            event = data[2]
                            if event.get("kind") == 10002:
                                # Extract relays from tags
                                self.relays = self._extract_relays_from_event(event)
                                self.event_received = True
                                
                                # Close subscription
                                close_msg = json.dumps(["CLOSE", subscription_id])
                                self.ws.send(close_msg)
                                return self.relays
                        
                        # Check for EOSE (End Of Stored Events)
                        elif data[0] == "EOSE" and data[1] == subscription_id:
                            # No relay list found
                            close_msg = json.dumps(["CLOSE", subscription_id])
                            self.ws.send(close_msg)
                            return []
                            
                except websocket.WebSocketTimeoutException:
                    continue
                except json.JSONDecodeError:
                    continue
                except Exception as e:
                    print(f"⚠️ Error receiving data: {e}", file=sys.stderr)
                    break
            
            # Timeout reached
            return []
            
        except Exception as e:
            print(f"❌ Error fetching relay list: {e}", file=sys.stderr)
            return []
    
    def _extract_relays_from_event(self, event: dict) -> list:
        """Extract relay URLs from kind 10002 event"""
        relays = []
        
        # Extract from tags (NIP-65 format)
        tags = event.get("tags", [])
        for tag in tags:
            if len(tag) >= 2 and tag[0] == "r":
                relay_url = tag[1]
                # Optional: check for read/write marker in tag[2]
                # We'll accept all relays regardless of read/write status
                if relay_url not in relays:
                    relays.append(relay_url)
        
        # Also try to parse content as JSON (older format)
        if not relays:
            try:
                content = event.get("content", "")
                if content:
                    relay_dict = json.loads(content)
                    if isinstance(relay_dict, dict):
                        relays = list(relay_dict.keys())
            except:
                pass
        
        return relays
    
    def close(self):
        """Close the connection"""
        if self.ws:
            try:
                self.ws.close()
            except:
                pass
        self.connected = False

def get_user_relays(hex_pubkey: str, query_relay: str = DEFAULT_RELAY) -> list:
    """
    Get a user's preferred relays from NOSTR.
    
    Args:
        hex_pubkey: Hex public key of the user
        query_relay: Relay to query for the user's relay list
        
    Returns:
        list: List of relay URLs, or empty list if not found
    """
    fetcher = NostrRelayFetcher(query_relay)
    
    try:
        if not fetcher.connect():
            return []
        
        relays = fetcher.fetch_relay_list(hex_pubkey)
        return relays
        
    finally:
        fetcher.close()

def main():
    parser = argparse.ArgumentParser(
        description="Fetch user's preferred NOSTR relays (kind 10002)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("hex_pubkey", help="Hex public key of the user")
    parser.add_argument("query_relay", nargs="?", default=DEFAULT_RELAY,
                       help=f"Relay to query (default: {DEFAULT_RELAY})")
    parser.add_argument("--json", action="store_true",
                       help="Output as JSON array")
    parser.add_argument("--first", action="store_true",
                       help="Output only the first relay")
    
    args = parser.parse_args()

    # Validate hex pubkey
    if len(args.hex_pubkey) != 64:
        print("Error: Hex pubkey must be 64 characters", file=sys.stderr)
        sys.exit(1)

    # Fetch relays
    relays = get_user_relays(args.hex_pubkey, args.query_relay)
    
    if not relays:
        # No relays found - exit with code 1
        sys.exit(1)
    
    # Output results
    if args.json:
        print(json.dumps(relays))
    elif args.first:
        print(relays[0])
    else:
        for relay in relays:
            print(relay)
    
    sys.exit(0)

if __name__ == "__main__":
    main()

