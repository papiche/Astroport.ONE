#!/usr/bin/env python3
"""
Nostr DID Document Reader (Kind 30311)

This script reads DID documents from NOSTR relays by querying kind 30311 events.

Usage:
    python nostr_read_did.py <npub> [relay_urls...]
    python nostr_read_did.py --help

Example:
    python nostr_read_did.py npub1xyz... ws://127.0.0.1:7777
    python nostr_read_did.py npub1xyz... ws://127.0.0.1:7777 wss://relay.copylaradio.com
"""

import sys
import json
import argparse
import time
import websocket
from pynostr.key import PublicKey

# Default relays (UPlanet ecosystem)
DEFAULT_RELAYS = [
    "ws://127.0.0.1:7777",           # Local Astroport relay
    "wss://relay.copylaradio.com"    # UPlanet ORIGIN relay
]

CONNECT_TIMEOUT = 10
READ_TIMEOUT = 30

# Kind 30311: Parameterized Replaceable Event for general-purpose JSON
# Using tag ["d", "did"] to identify DID documents
DID_EVENT_KIND = 30311
DID_TAG_IDENTIFIER = "did"

class NostrWebSocketReader:
    """Synchronous NOSTR WebSocket reader for DID documents"""
    
    def __init__(self, relay_url: str):
        self.relay_url = relay_url
        self.ws = None
        self.connected = False
        self.events = []
        
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
    
    def query_did(self, pubkey_hex: str, timeout: int = READ_TIMEOUT) -> dict:
        """
        Query for a DID document (kind 30311 with d=did tag)
        
        Args:
            pubkey_hex: Hex-encoded public key of the DID owner
            timeout: Timeout in seconds for waiting for response
            
        Returns:
            dict: DID event data or None if not found
        """
        if not self.connected:
            return None
        
        try:
            # Create REQ message to query for DID
            subscription_id = f"did_query_{int(time.time())}"
            req_message = json.dumps([
                "REQ",
                subscription_id,
                {
                    "kinds": [DID_EVENT_KIND],
                    "authors": [pubkey_hex],
                    "#d": [DID_TAG_IDENTIFIER],
                    "limit": 1
                }
            ])
            
            # Send the query
            self.ws.send(req_message)
            
            # Wait for response
            start_time = time.time()
            found_event = None
            
            while time.time() - start_time < timeout:
                try:
                    self.ws.settimeout(1.0)
                    response = self.ws.recv()
                    
                    if response:
                        data = json.loads(response)
                        
                        # Check message type
                        if isinstance(data, list) and len(data) > 0:
                            msg_type = data[0]
                            
                            if msg_type == "EVENT" and len(data) >= 3:
                                # Extract event data
                                event = data[2]
                                if event.get("kind") == DID_EVENT_KIND:
                                    found_event = event
                            
                            elif msg_type == "EOSE":
                                # End of stored events
                                break
                                
                except websocket.WebSocketTimeoutException:
                    continue
                except Exception as e:
                    print(f"⚠️ Error receiving: {e}", file=sys.stderr)
                    break
            
            # Close subscription
            close_message = json.dumps(["CLOSE", subscription_id])
            self.ws.send(close_message)
            
            return found_event
            
        except Exception as e:
            print(f"❌ Error querying relay: {e}", file=sys.stderr)
            return None
    
    def close(self):
        """Close the connection"""
        if self.ws:
            try:
                self.ws.close()
            except:
                pass
        self.connected = False

def read_did_from_nostr(npub: str, relay_urls: list = None, 
                         verbose: bool = False, output_file: str = None) -> tuple[bool, dict]:
    """
    Read a DID document from NOSTR relays.
    
    Args:
        npub: NPUB public key of the DID owner
        relay_urls: List of relay URLs (defaults to DEFAULT_RELAYS)
        verbose: Print verbose output
        output_file: Optional file path to save the DID document
        
    Returns:
        tuple: (found: bool, did_data: dict)
    """
    if relay_urls is None:
        relay_urls = DEFAULT_RELAYS
    
    try:
        # Convert npub to hex
        pub_key_obj = PublicKey.from_npub(npub)
        pubkey_hex = pub_key_obj.hex()
        
        if verbose:
            print(f"🔍 Searching for DID document...")
            print(f"   - NPUB: {npub}")
            print(f"   - Hex: {pubkey_hex}")
            print(f"   - Relays: {len(relay_urls)}")
        
        # Try each relay until we find the DID
        for relay_url in relay_urls:
            if verbose:
                print(f"\n📡 Querying relay: {relay_url}")
            
            reader = None
            try:
                reader = NostrWebSocketReader(relay_url)
                if not reader.connect():
                    continue
                
                # Query for DID
                event = reader.query_did(pubkey_hex)
                
                if event:
                    # Extract DID content
                    did_content = event.get("content", "")
                    event_id = event.get("id", "unknown")
                    created_at = event.get("created_at", 0)
                    
                    if verbose:
                        print(f"✅ DID found!")
                        print(f"   - Event ID: {event_id}")
                        print(f"   - Created at: {time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(created_at))}")
                        print(f"   - Content size: {len(did_content)} bytes")
                    
                    # Validate JSON
                    try:
                        did_obj = json.loads(did_content)
                        
                        # Save to file if requested
                        if output_file:
                            with open(output_file, 'w') as f:
                                json.dump(did_obj, f, indent=2)
                            if verbose:
                                print(f"💾 DID saved to: {output_file}")
                        
                        return True, {
                            "event_id": event_id,
                            "created_at": created_at,
                            "relay": relay_url,
                            "did": did_obj,
                            "content": did_content
                        }
                        
                    except json.JSONDecodeError as e:
                        if verbose:
                            print(f"⚠️ Invalid JSON in DID content: {e}")
                        continue
                
            except Exception as e:
                if verbose:
                    print(f"⚠️ Error with relay {relay_url}: {e}")
            finally:
                if reader:
                    reader.close()
        
        # Not found on any relay
        if verbose:
            print("\n❌ DID document not found on any relay")
        
        return False, None
        
    except KeyboardInterrupt:
        if verbose:
            print("\n🛑 Operation cancelled by user.")
        return False, None
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {str(e)}", file=sys.stderr)
        return False, None

def main():
    parser = argparse.ArgumentParser(
        description="Read DID documents from NOSTR relays (kind 30311 events)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("npub", help="NPUB public key of the DID owner")
    parser.add_argument("relay_urls", nargs="*", default=DEFAULT_RELAYS,
                       help=f"Relay URLs (default: {', '.join(DEFAULT_RELAYS)})")
    
    parser.add_argument("-o", "--output", help="Save DID document to file")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("-q", "--quiet", action="store_true", help="Quiet mode (only output DID)")
    parser.add_argument("--check-only", action="store_true", 
                       help="Only check if DID exists (exit code 0 if found, 1 if not)")
    
    args = parser.parse_args()

    # Validate NPUB format
    if not args.npub.startswith("npub1"):
        print("Error: Public key must be in NPUB format (npub1...)", file=sys.stderr)
        sys.exit(1)
    
    # Read the DID
    verbose = args.verbose and not args.quiet
    found, did_data = read_did_from_nostr(
        args.npub,
        args.relay_urls if args.relay_urls else DEFAULT_RELAYS,
        verbose=verbose,
        output_file=args.output
    )
    
    # Check-only mode
    if args.check_only:
        if found and verbose:
            print(f"✅ DID exists (Event ID: {did_data['event_id']})")
        sys.exit(0 if found else 1)
    
    # Output results
    if found:
        if args.quiet:
            # Only output the DID JSON
            print(did_data["content"])
        elif not verbose:
            # Default: pretty-print DID
            print(json.dumps(did_data["did"], indent=2))
        
        sys.exit(0)
    else:
        if not args.quiet:
            print("DID document not found", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

