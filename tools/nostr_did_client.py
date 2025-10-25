#!/usr/bin/env python3
"""
Nostr DID Client - Unified DID Document Manager

This script provides a unified interface for reading, fetching, and managing
DID documents from NOSTR relays (kind 30311 events).

It combines the functionality of:
- DID document reading and fetching
- Unified interface for all DID operations

Usage:
    # Read mode
    python nostr_did_client.py read <npub> [relay_urls...]
    python nostr_did_client.py read npub1xyz... ws://127.0.0.1:7777
    
    # Fetch mode
    python nostr_did_client.py fetch --author <npub> --relay <relay_url>
    python nostr_did_client.py fetch --author npub1xyz... --relay ws://127.0.0.1:7777
    
    # Check mode (for scripts)
    python nostr_did_client.py check <npub> [relay_urls...]
    
    # List mode (find all DIDs for an author)
    python nostr_did_client.py list --author <npub> --relay <relay_url>

Examples:
    # Read DID with verbose output
    python nostr_did_client.py read npub1xyz... -v
    
    # Fetch DID for G1society.sh (quiet mode)
    python nostr_did_client.py fetch --author npub1xyz... --relay ws://127.0.0.1:7777 -q
    
    # Check if DID exists (exit code 0/1)
    python nostr_did_client.py check npub1xyz...
    
    # List all DIDs for an author
    python nostr_did_client.py list --author npub1xyz... --relay ws://127.0.0.1:7777
"""

import sys
import json
import argparse
import time
import websocket
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple

# Default relays (UPlanet ecosystem)
DEFAULT_RELAYS = [
    "ws://127.0.0.1:7777",           # Local Astroport relay
    "wss://relay.copylaradio.com"    # UPlanet ORIGIN relay
]

CONNECT_TIMEOUT = 5
READ_TIMEOUT = 10

# Kind 30311: Parameterized Replaceable Event for general-purpose JSON
# Using tag ["d", "did"] to identify DID documents
DID_EVENT_KIND = 30311
DID_TAG_IDENTIFIER = "did"

class NostrWebSocketClient:
    """Unified NOSTR WebSocket client for DID document operations"""
    
    def __init__(self, relay_url: str):
        self.relay_url = relay_url
        self.ws = None
        self.connected = False
        
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
    
    def query_did(self, pubkey_hex: str, timeout: int = READ_TIMEOUT) -> Optional[Dict[str, Any]]:
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
    
    def fetch_events(self, author_pubkey: str, kind: int, timeout: int = READ_TIMEOUT) -> List[Dict[str, Any]]:
        """Fetch all events from the relay for an author and kind"""
        if not self.connected:
            return []
        
        try:
            # Create REQ message
            req_message = [
                "REQ",
                f"fetch_did_{int(time.time())}",
                {
                    "authors": [author_pubkey],
                    "kinds": [kind],
                    "#d": [DID_TAG_IDENTIFIER]  # Filter for DID documents
                }
            ]
            
            self.ws.send(json.dumps(req_message))
            
            # Collect events
            events = []
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                try:
                    self.ws.settimeout(1.0)
                    response = self.ws.recv()
                    
                    if response:
                        try:
                            data = json.loads(response)
                            if data[0] == "EVENT":
                                events.append(data[2])  # Event data
                            elif data[0] == "EOSE":
                                break
                        except (json.JSONDecodeError, IndexError, KeyError):
                            continue
                            
                except websocket.WebSocketTimeoutException:
                    continue
                except Exception as e:
                    print(f"⚠️ Error receiving: {e}", file=sys.stderr)
                    break
            
            return events
            
        except Exception as e:
            print(f"❌ Error fetching events: {e}", file=sys.stderr)
            return []
    
    def close(self):
        """Close the connection"""
        if self.ws:
            try:
                self.ws.close()
            except:
                pass
        self.connected = False

def validate_did_nostr_structure(did_obj: Dict[str, Any]) -> bool:
    """
    Validate that the DID document follows DID Nostr specification.
    
    Args:
        did_obj: Parsed DID document
        
    Returns:
        bool: True if valid DID Nostr structure, False otherwise
    """
    try:
        # Check required fields for DID Nostr
        required_fields = ["id", "type", "verificationMethod"]
        
        for field in required_fields:
            if field not in did_obj:
                return False
        
        # Check DID ID format (did:nostr:hex_pubkey)
        did_id = did_obj.get("id", "")
        if not did_id.startswith("did:nostr:"):
            return False
        
        # Check type field
        if did_obj.get("type") != "DIDNostr":
            return False
        
        # Check verification method structure
        verification_methods = did_obj.get("verificationMethod", [])
        if not verification_methods or not isinstance(verification_methods, list):
            return False
        
        # Check at least one Multikey verification method
        has_multikey = False
        for vm in verification_methods:
            if vm.get("type") == "Multikey" and "publicKeyMultibase" in vm:
                has_multikey = True
                break
        
        return has_multikey
        
    except Exception:
        return False

def npub_to_hex(npub: str) -> Optional[str]:
    """Convert NPUB to hex using nostr2hex.py if available, fallback to bech32"""
    try:
        # Try nostr2hex.py first
        nostr2hex_script = Path(__file__).parent / "nostr2hex.py"
        if nostr2hex_script.exists():
            import subprocess
            result = subprocess.run([
                sys.executable, 
                str(nostr2hex_script), 
                npub
            ], capture_output=True, text=True, check=True)
            hex_result = result.stdout.strip()
            if hex_result and len(hex_result) == 64:  # Valid hex length
                return hex_result
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    # Fallback to bech32
    try:
        from bech32 import bech32_decode, convertbits
        hrp, data = bech32_decode(npub)
        if hrp != 'npub' or not data:
            return None
        hex_result = bytes(convertbits(data, 5, 8, False)).hex()
        if len(hex_result) == 64:  # Valid hex length
            return hex_result
        return None
    except ImportError:
        print("❌ Error: bech32 library not available", file=sys.stderr)
        return None
    except Exception as e:
        print(f"❌ Error converting npub to hex: {e}", file=sys.stderr)
        return None

def read_did_from_nostr(npub: str, relay_urls: List[str] = None, 
                       verbose: bool = False, output_file: str = None) -> Tuple[bool, Optional[Dict[str, Any]]]:
    """
    Read a DID document from NOSTR relays (read mode).
    
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
        pubkey_hex = npub_to_hex(npub)
        if not pubkey_hex:
            print("❌ Error: Invalid NPUB format", file=sys.stderr)
            return False, None
        
        if verbose:
            print(f"🔍 Searching for DID document...")
            print(f"   - NPUB: {npub}")
            print(f"   - Hex: {pubkey_hex}")
            print(f"   - Relays: {len(relay_urls)}")
        
        # Try each relay until we find the DID
        for relay_url in relay_urls:
            if verbose:
                print(f"\n📡 Querying relay: {relay_url}")
            
            client = None
            try:
                client = NostrWebSocketClient(relay_url)
                if not client.connect():
                    continue
                
                # Query for DID
                event = client.query_did(pubkey_hex)
                
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
                if client:
                    client.close()
        
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

def fetch_did_from_nostr(author_pubkey: str, relay_url: str, kind: int = DID_EVENT_KIND) -> str:
    """
    Fetch DID document from NOSTR relay (fetch mode for G1society.sh).
    
    Args:
        author_pubkey: NPUB of the DID owner
        relay_url: Relay URL to query
        kind: Event kind (default: 30311 for DID documents)
        
    Returns:
        str: JSON string of the DID document, or empty string if not found
    """
    client = None
    try:
        client = NostrWebSocketClient(relay_url)
        if not client.connect():
            return ""
        
        events = client.fetch_events(author_pubkey, kind)
        
        if not events:
            return ""
        
        # Find the most recent DID document (highest created_at)
        latest_event = max(events, key=lambda x: x.get('created_at', 0))
        
        # Parse the content
        content = latest_event.get('content', '')
        if not content:
            return ""
        
        # Validate JSON and DID structure
        try:
            did_obj = json.loads(content)
            
            # Validate DID Nostr structure
            if not validate_did_nostr_structure(did_obj):
                return ""
            
            return json.dumps(did_obj, indent=2)
        except json.JSONDecodeError:
            return ""
            
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return ""
    finally:
        if client:
            client.close()

def list_dids_from_nostr(author_pubkey: str, relay_url: str, kind: int = DID_EVENT_KIND) -> List[Dict[str, Any]]:
    """
    List all DID documents for an author from a relay.
    
    Args:
        author_pubkey: NPUB of the DID owner
        relay_url: Relay URL to query
        kind: Event kind (default: 30311 for DID documents)
        
    Returns:
        list: List of DID documents
    """
    client = None
    try:
        client = NostrWebSocketClient(relay_url)
        if not client.connect():
            return []
        
        events = client.fetch_events(author_pubkey, kind)
        
        dids = []
        for event in events:
            content = event.get('content', '')
            if not content:
                continue
            
            try:
                did_obj = json.loads(content)
                if validate_did_nostr_structure(did_obj):
                    dids.append({
                        "event_id": event.get('id', 'unknown'),
                        "created_at": event.get('created_at', 0),
                        "did": did_obj
                    })
            except json.JSONDecodeError:
                continue
        
        # Sort by created_at (newest first)
        dids.sort(key=lambda x: x.get('created_at', 0), reverse=True)
        return dids
        
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return []
    finally:
        if client:
            client.close()

def main():
    parser = argparse.ArgumentParser(
        description="Unified NOSTR DID Client - Read, fetch, and manage DID documents",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Read command
    read_parser = subparsers.add_parser('read', help='Read DID document')
    read_parser.add_argument("npub", help="NPUB public key of the DID owner")
    read_parser.add_argument("relay_urls", nargs="*", default=DEFAULT_RELAYS,
                           help=f"Relay URLs (default: {', '.join(DEFAULT_RELAYS)})")
    read_parser.add_argument("-o", "--output", help="Save DID document to file")
    read_parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    read_parser.add_argument("-q", "--quiet", action="store_true", help="Quiet mode (only output DID)")
    read_parser.add_argument("--check-only", action="store_true", 
                           help="Only check if DID exists (exit code 0 if found, 1 if not)")
    
    # Fetch command
    fetch_parser = subparsers.add_parser('fetch', help='Fetch DID document')
    fetch_parser.add_argument("--author", required=True, help="NPUB of the DID owner")
    fetch_parser.add_argument("--relay", required=True, help="Relay URL to query")
    fetch_parser.add_argument("--kind", type=int, default=DID_EVENT_KIND, help=f"Event kind (default: {DID_EVENT_KIND})")
    fetch_parser.add_argument("-q", "--quiet", action="store_true", help="Quiet mode (no stderr output)")
    
    # Check command (for scripts)
    check_parser = subparsers.add_parser('check', help='Check if DID exists (for scripts)')
    check_parser.add_argument("npub", help="NPUB public key of the DID owner")
    check_parser.add_argument("relay_urls", nargs="*", default=DEFAULT_RELAYS,
                            help=f"Relay URLs (default: {', '.join(DEFAULT_RELAYS)})")
    check_parser.add_argument("-q", "--quiet", action="store_true", help="Quiet mode")
    
    # List command (find all DIDs)
    list_parser = subparsers.add_parser('list', help='List all DIDs for an author')
    list_parser.add_argument("--author", required=True, help="NPUB of the DID owner")
    list_parser.add_argument("--relay", required=True, help="Relay URL to query")
    list_parser.add_argument("--kind", type=int, default=DID_EVENT_KIND, help=f"Event kind (default: {DID_EVENT_KIND})")
    list_parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Redirect stderr to /dev/null for quiet mode
    if hasattr(args, 'quiet') and args.quiet:
        sys.stderr = open('/dev/null', 'w')
    
    # Validate NPUB format for commands that need it
    if hasattr(args, 'npub') and args.npub and not args.npub.startswith("npub1"):
        print("Error: Public key must be in NPUB format (npub1...)", file=sys.stderr)
        sys.exit(1)
    
    if hasattr(args, 'author') and args.author and not args.author.startswith("npub1"):
        print("Error: Author key must be in NPUB format (npub1...)", file=sys.stderr)
        sys.exit(1)
    
    # Execute commands
    if args.command == 'read':
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
    
    elif args.command == 'fetch':
        did_content = fetch_did_from_nostr(args.author, args.relay, args.kind)
        
        if did_content:
            print(did_content)
            sys.exit(0)
        else:
            print("null")
            sys.exit(1)
    
    elif args.command == 'check':
        verbose = not args.quiet
        found, _ = read_did_from_nostr(
            args.npub,
            args.relay_urls if args.relay_urls else DEFAULT_RELAYS,
            verbose=verbose
        )
        sys.exit(0 if found else 1)
    
    elif args.command == 'list':
        dids = list_dids_from_nostr(args.author, args.relay, args.kind)
        
        if args.verbose:
            print(f"Found {len(dids)} DID document(s)")
            for i, did_info in enumerate(dids, 1):
                print(f"\n{i}. Event ID: {did_info['event_id']}")
                print(f"   Created: {time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(did_info['created_at']))}")
                print(f"   DID ID: {did_info['did'].get('id', 'unknown')}")
        else:
            # Output as JSON array
            print(json.dumps(dids, indent=2))
        
        sys.exit(0 if dids else 1)

if __name__ == "__main__":
    main()
