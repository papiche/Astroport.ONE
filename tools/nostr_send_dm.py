#!/usr/bin/env python3
"""
Nostr Direct Message Sender (Synchronous Version)

This script sends encrypted direct messages (kind 4) to NOSTR users.
It uses NIP-04 encryption for secure communication.
Uses synchronous WebSocket connections to avoid event loop issues.

Usage:
    python nostr_send_dm.py <sender_nsec> <recipient_hex> <message> [relay_url]
    python nostr_send_dm.py --help

Example:
    python nostr_send_dm.py nsec1xyz... abc123... "Hello, this is a secret message" wss://relay.copylaradio.com
"""

import sys
import json
import argparse
import time
import base64
import os
import hashlib
import websocket
import threading
from pynostr.event import Event, EventKind
from pynostr.key import PrivateKey

DEFAULT_RELAY = "ws://127.0.0.1:7777"
CONNECT_TIMEOUT = 10
PUBLISH_TIMEOUT = 30

def hex_to_uncompressed_pubkey(pubkey_hex: str) -> bytes:
    """Convert a 32-byte hex pubkey to uncompressed SEC1 format (0x04 + X + Y, 65 bytes)"""
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.backends import default_backend
    if len(pubkey_hex) != 64:
        raise ValueError("Invalid pubkey hex length")
    x = int(pubkey_hex, 16)
    # secp256k1: y^2 = x^3 + 7 mod p
    # Find y such that y^2 = x^3 + 7 mod p, and y is even (BIP340 convention)
    curve = ec.SECP256K1()
    # Get the prime field order
    p = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
    y_square = (pow(x, 3, p) + 7) % p
    y = pow(y_square, (p + 1) // 4, p)
    if y % 2 != 0:
        y = p - y
    x_bytes = x.to_bytes(32, 'big')
    y_bytes = y.to_bytes(32, 'big')
    return b'\x04' + x_bytes + y_bytes

def nip04_encrypt(message: str, sender_private_key: str, recipient_public_key: str) -> str:
    """
    Encrypt a message using NIP-04 (AES-256-CBC with shared secret).
    
    Args:
        message: Message to encrypt
        sender_private_key: Hex private key of sender
        recipient_public_key: Hex public key of recipient
        
    Returns:
        Base64 encoded encrypted message
    """
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        from cryptography.hazmat.primitives import padding
        from cryptography.hazmat.backends import default_backend
        from cryptography.hazmat.primitives.kdf.hkdf import HKDF
        from cryptography.hazmat.primitives import hashes
    except ImportError:
        print("Error: cryptography library not available. Install with: pip install cryptography")
        sys.exit(1)
    
    # Convert hex keys to bytes
    sender_privkey_bytes = bytes.fromhex(sender_private_key)
    # Convert recipient pubkey to uncompressed SEC1 format
    recipient_pubkey_bytes = hex_to_uncompressed_pubkey(recipient_public_key)
    
    # Generate shared secret using ECDH
    try:
        from cryptography.hazmat.primitives.asymmetric import ec
        sender_private_key_obj = ec.derive_private_key(
            int(sender_private_key, 16), ec.SECP256K1(), default_backend()
        )
        recipient_public_key_obj = ec.EllipticCurvePublicKey.from_encoded_point(
            ec.SECP256K1(), recipient_pubkey_bytes
        )
        shared_secret = sender_private_key_obj.exchange(
            ec.ECDH(), recipient_public_key_obj
        )
    except Exception as e:
        print(f"Error generating shared secret: {e}")
        sys.exit(1)
    
    # Derive encryption key using HKDF
    hkdf = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=None,
        info=b"nostr",
        backend=default_backend()
    )
    key = hkdf.derive(shared_secret)
    
    # Generate random IV
    iv = os.urandom(16)
    
    # Encrypt message
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    
    # Pad message
    padder = padding.PKCS7(128).padder()
    padded_data = padder.update(message.encode('utf-8')) + padder.finalize()
    
    # Encrypt
    encrypted_data = encryptor.update(padded_data) + encryptor.finalize()
    
    # Combine IV and encrypted data, encode as base64
    return base64.b64encode(iv + encrypted_data).decode('utf-8')

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
                            print("✅ Message accepted by relay")
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

def send_direct_message_sync(sender_nsec: str, recipient_hex: str, message: str, 
                           relay_url: str = DEFAULT_RELAY) -> bool:
    """
    Send an encrypted direct message to a NOSTR user (synchronous version).
    
    Args:
        sender_nsec: NSEC private key of the sender
        recipient_hex: Hex public key of the recipient
        message: Message content to send
        relay_url: NOSTR relay URL
        
    Returns:
        bool: True if message was sent successfully, False otherwise
    """
    client = None
    try:
        # Create private key object
        priv_key_obj = PrivateKey.from_nsec(sender_nsec)
        
        # Encrypt the message using NIP-04
        encrypted_content = nip04_encrypt(message, priv_key_obj.hex(), recipient_hex)
        
        # Create the event
        tags = [["p", recipient_hex]]
        event = Event(
            kind=EventKind.ENCRYPTED_DIRECT_MESSAGE,
            content=encrypted_content,
            tags=tags,
            pubkey=priv_key_obj.public_key.hex()
        )
        
        # Sign the event
        event.sign(priv_key_obj.hex())

        print(f"\n📝 Event details:")
        print(f"   - ID: {event.id}")
        print(f"   - Kind: {event.kind} (Encrypted Direct Message)")
        print(f"   - Content length: {len(encrypted_content)} chars (encrypted)")
        print(f"   - Recipient: {recipient_hex}")
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
            print(f"\n✅ Message sent successfully!")
            print(f"   - Event ID: {event.id}")
        else:
            print(f"\n❌ Failed to send message")
        
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
        description="Send encrypted direct messages via NOSTR (synchronous)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("sender_nsec", help="NSEC private key of the sender")
    parser.add_argument("recipient_hex", help="Hex public key of the recipient")
    parser.add_argument("message", help="Message content to send")
    parser.add_argument("relay_url", nargs="?", default=DEFAULT_RELAY, 
                       help=f"Relay URL (default: {DEFAULT_RELAY})")
    
    args = parser.parse_args()

    # Validate inputs
    if not args.sender_nsec.startswith("nsec1"):
        print("Error: Sender key must be in NSEC format (nsec1...)", file=sys.stderr)
        sys.exit(1)
    
    if len(args.recipient_hex) != 64:
        print("Error: Recipient key must be 64-character hex string", file=sys.stderr)
        sys.exit(1)
    
    if not args.message.strip():
        print("Error: Message cannot be empty", file=sys.stderr)
        sys.exit(1)

    # Send the message
    success = send_direct_message_sync(
        args.sender_nsec,
        args.recipient_hex,
        args.message,
        args.relay_url
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 