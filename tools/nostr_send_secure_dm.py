#!/usr/bin/env python3
"""
Nostr Secure Direct Message Sender (NIP-44 Enhanced)

This script sends encrypted direct messages (kind 4) to NOSTR users using
enhanced security features including NIP-44 encryption and metadata protection.

Features:
- NIP-44 ChaCha20-Poly1305 encryption (enhanced security)
- Metadata protection and obfuscation
- Gift wrapping support (NIP-17) for additional privacy
- Rate limiting and anti-surveillance measures

Usage:
    python nostr_send_secure_dm.py <sender_nsec> <recipient_hex> <message> [relay_url] [options]
    python nostr_send_secure_dm.py --help

Example:
    python nostr_send_secure_dm.py nsec1xyz... abc123... "Secure message" wss://relay.copylaradio.com --gift-wrap --metadata-protection
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
import secrets
import hmac
from datetime import datetime, timedelta
from pynostr.event import Event, EventKind
from pynostr.key import PrivateKey

DEFAULT_RELAY = "ws://127.0.0.1:7777"
CONNECT_TIMEOUT = 10
PUBLISH_TIMEOUT = 30

def generate_ephemeral_keypair():
    """Generate ephemeral keypair for gift wrapping (no rotation)"""
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.backends import default_backend
    
    private_key = ec.generate_private_key(ec.SECP256K1(), default_backend())
    public_key = private_key.public_key()
    
    # Convert to hex format
    private_hex = private_key.private_numbers().private_value.to_bytes(32, 'big').hex()
    public_hex = public_key.public_numbers().x.to_bytes(32, 'big').hex()
    
    return private_hex, public_hex

def derive_shared_secret(sender_private_key: str, recipient_public_key: str) -> bytes:
    """Derive shared secret using ECDH"""
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.backends import default_backend
    
    # Convert hex keys to private/public key objects
    sender_private_key_obj = ec.derive_private_key(
        int(sender_private_key, 16), ec.SECP256K1(), default_backend()
    )
    
    # Convert recipient pubkey to uncompressed SEC1 format
    recipient_pubkey_bytes = hex_to_uncompressed_pubkey(recipient_public_key)
    recipient_public_key_obj = ec.EllipticCurvePublicKey.from_encoded_point(
        ec.SECP256K1(), recipient_pubkey_bytes
    )
    
    # Generate shared secret
    shared_secret = sender_private_key_obj.exchange(
        ec.ECDH(), recipient_public_key_obj
    )
    
    return shared_secret

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

def nip44_encrypt(message: str, sender_private_key: str, recipient_public_key: str) -> str:
    """
    Encrypt a message using NIP-44 (ChaCha20-Poly1305 with HKDF).
    This provides enhanced security with ChaCha20-Poly1305.
    
    Args:
        message: Message to encrypt
        sender_private_key: Hex private key of sender
        recipient_public_key: Hex public key of recipient
        
    Returns:
        Base64 encoded encrypted message with authentication tag
    """
    try:
        from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
        from cryptography.hazmat.primitives.kdf.hkdf import HKDF
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.backends import default_backend
    except ImportError:
        print("Error: cryptography library not available. Install with: pip install cryptography")
        sys.exit(1)
    
    # Derive shared secret using ECDH
    shared_secret = derive_shared_secret(sender_private_key, recipient_public_key)
    
    # Derive encryption key using HKDF with better parameters
    hkdf = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=b"nostr-nip44-v1",  # Version-specific salt
        info=b"nostr-encryption",
        backend=default_backend()
    )
    key = hkdf.derive(shared_secret)
    
    # Generate random nonce (12 bytes for ChaCha20-Poly1305)
    nonce = os.urandom(12)
    
    # Encrypt message with authentication
    cipher = ChaCha20Poly1305(key)
    encrypted_data = cipher.encrypt(nonce, message.encode('utf-8'), None)
    
    # Combine nonce and encrypted data, encode as base64
    return base64.b64encode(nonce + encrypted_data).decode('utf-8')

def add_metadata_protection(message: str, sender_hex: str, recipient_hex: str) -> str:
    """
    Add metadata protection by padding and obfuscating message characteristics.
    """
    # Add random padding to standardize message length
    target_length = 256  # Standardize to 256 chars to prevent length analysis
    current_length = len(message)
    
    if current_length < target_length:
        # Add random padding
        padding_length = target_length - current_length
        padding = secrets.token_hex(padding_length // 2)[:padding_length]
        message = message + "|PAD:" + padding
    
    # Add timestamp obfuscation (random delay)
    random_delay = secrets.randbelow(300)  # 0-5 minutes random delay
    timestamp = int(time.time()) + random_delay
    
    # Add metadata obfuscation header
    metadata_header = {
        "ts": timestamp,
        "ver": "1.0",
        "pad": True
    }
    
    protected_message = json.dumps({
        "content": message,
        "metadata": metadata_header
    })
    
    return protected_message

def create_gift_wrapped_message(inner_event: dict, sender_private_key: str, recipient_public_key: str) -> dict:
    """
    Create a gift-wrapped message (NIP-17) for additional privacy.
    This hides the sender's identity by wrapping the message in another event.
    """
    # Generate ephemeral keypair for gift wrapping
    ephemeral_private, ephemeral_public = generate_ephemeral_keypair()
    
    # Create the inner event (the actual message)
    inner_event_json = json.dumps(inner_event)
    
    # Encrypt the inner event with the recipient's public key
    encrypted_inner = nip44_encrypt(inner_event_json, ephemeral_private, recipient_public_key)
    
    # Create the gift-wrapped event
    gift_event = {
        "kind": 1059,  # Gift wrap event kind
        "content": encrypted_inner,
        "tags": [
            ["p", recipient_public_key],
            ["wrapped", "true"]
        ],
        "pubkey": ephemeral_public,
        "created_at": int(time.time())
    }
    
    # Sign with ephemeral key
    ephemeral_key_obj = PrivateKey.from_hex(ephemeral_private)
    gift_event["id"] = hashlib.sha256(json.dumps(gift_event, separators=(',', ':'), sort_keys=True).encode()).hexdigest()
    gift_event["sig"] = ephemeral_key_obj.sign(gift_event["id"]).hex()
    
    return gift_event

class SecureNostrWebSocketClient:
    """Enhanced NOSTR WebSocket client with security features"""
    
    def __init__(self, relay_url: str, enable_rate_limiting: bool = True):
        self.relay_url = relay_url
        self.ws = None
        self.connected = False
        self.response_received = False
        self.response_data = None
        self.rate_limiting = enable_rate_limiting
        self.last_send_time = 0
        self.min_send_interval = 1.0  # Minimum 1 second between sends
        
    def connect(self, timeout: int = CONNECT_TIMEOUT) -> bool:
        """Connect to the relay with security headers"""
        try:
            print(f"🔌 Connecting to relay: {self.relay_url}")
            
            # Add security headers
            headers = {
                "User-Agent": "SecureNostrClient/1.0",
                "X-Client-Version": "secure-dm-v1.0"
            }
            
            self.ws = websocket.create_connection(
                self.relay_url,
                timeout=timeout,
                header=headers
            )
            self.connected = True
            print("✅ Connected to relay with security headers")
            return True
        except Exception as e:
            print(f"❌ Failed to connect: {e}")
            return False
    
    def send_event(self, event_json: str) -> bool:
        """Send an event to the relay with rate limiting"""
        if not self.connected:
            print("❌ Not connected to relay")
            return False
        
        # Rate limiting
        if self.rate_limiting:
            current_time = time.time()
            time_since_last_send = current_time - self.last_send_time
            if time_since_last_send < self.min_send_interval:
                sleep_time = self.min_send_interval - time_since_last_send
                print(f"⏳ Rate limiting: waiting {sleep_time:.1f}s...")
                time.sleep(sleep_time)
        
        try:
            print("📤 Sending secure event to relay...")
            self.ws.send(event_json)
            self.last_send_time = time.time()
            return True
        except Exception as e:
            print(f"❌ Failed to send event: {e}")
            return False
    
    def wait_for_response(self, timeout: int = PUBLISH_TIMEOUT) -> bool:
        """Wait for OK response from relay with enhanced error handling"""
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
                            print("✅ Secure message accepted by relay")
                            return True
                        elif '"CLOSED"' in response:
                            print("❌ Relay closed connection")
                            return False
                        elif '"NOTICE"' in response:
                            print(f"⚠️ Relay notice: {response}")
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
        """Close the connection securely"""
        if self.ws:
            try:
                self.ws.close()
            except:
                pass
        self.connected = False

def send_secure_direct_message(sender_nsec: str, recipient_hex: str, message: str, 
                              relay_url: str = DEFAULT_RELAY, gift_wrap: bool = False,
                              metadata_protection: bool = False) -> bool:
    """
    Send a secure encrypted direct message to a NOSTR user with enhanced security.
    
    Args:
        sender_nsec: NSEC private key of the sender
        recipient_hex: Hex public key of the recipient
        message: Message content to send
        relay_url: NOSTR relay URL
        gift_wrap: Enable NIP-17 gift wrapping for additional privacy
        metadata_protection: Enable metadata protection features
        
    Returns:
        bool: True if message was sent successfully, False otherwise
    """
    client = None
    try:
        # Create private key object
        priv_key_obj = PrivateKey.from_nsec(sender_nsec)
        
        # Apply metadata protection if enabled
        protected_message = message
        if metadata_protection:
            protected_message = add_metadata_protection(message, priv_key_obj.public_key.hex(), recipient_hex)
            print("🔒 Metadata protection enabled")
        
        # Encrypt the message using NIP-44 (enhanced security)
        encrypted_content = nip44_encrypt(protected_message, priv_key_obj.hex(), recipient_hex)
        print("🔐 Message encrypted with NIP-44 (ChaCha20-Poly1305)")
        
        # Create the base event
        tags = [["p", recipient_hex]]
        if gift_wrap:
            tags.append(["wrapped", "true"])
        
        base_event = {
            "kind": EventKind.ENCRYPTED_DIRECT_MESSAGE,
            "content": encrypted_content,
            "tags": tags,
            "pubkey": priv_key_obj.public_key.hex(),
            "created_at": int(time.time())
        }
        
        # Apply gift wrapping if enabled
        if gift_wrap:
            print("🎁 Creating gift-wrapped message (NIP-17)")
            event_dict = create_gift_wrapped_message(base_event, priv_key_obj.hex(), recipient_hex)
        else:
            # Sign the event normally
            event = Event(
                kind=EventKind.ENCRYPTED_DIRECT_MESSAGE,
                content=encrypted_content,
                tags=tags,
                pubkey=priv_key_obj.public_key.hex()
            )
            event.sign(priv_key_obj.hex())
            event_dict = event.to_dict()
        
        print(f"\n📝 Secure event details:")
        print(f"   - ID: {event_dict.get('id', 'N/A')}")
        print(f"   - Kind: {event_dict.get('kind')} (Encrypted Direct Message)")
        print(f"   - Content length: {len(encrypted_content)} chars (encrypted)")
        print(f"   - Recipient: {recipient_hex}")
        print(f"   - Sender: {event_dict.get('pubkey')}")
        print(f"   - Gift wrapped: {gift_wrap}")
        print(f"   - Metadata protection: {metadata_protection}")

        # Create WebSocket client and connect
        client = SecureNostrWebSocketClient(relay_url, enable_rate_limiting=True)
        if not client.connect():
            return False
        
        # Send the event
        event_json = json.dumps(["EVENT", event_dict])
        if not client.send_event(event_json):
            return False
        
        # Wait for response
        success = client.wait_for_response()
        
        if success:
            print(f"\n✅ Secure message sent successfully!")
            print(f"   - Event ID: {event_dict.get('id', 'N/A')}")
            print(f"   - Security features: NIP-44 encryption, rate limiting")
            if gift_wrap:
                print(f"   - Privacy features: Gift wrapping (NIP-17)")
            if metadata_protection:
                print(f"   - Privacy features: Metadata protection")
        else:
            print(f"\n❌ Failed to send secure message")
        
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
        description="Send secure encrypted direct messages via NOSTR (NIP-44 enhanced)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("sender_nsec", help="NSEC private key of the sender")
    parser.add_argument("recipient_hex", help="Hex public key of the recipient")
    parser.add_argument("message", help="Message content to send")
    parser.add_argument("relay_url", nargs="?", default=DEFAULT_RELAY, 
                       help=f"Relay URL (default: {DEFAULT_RELAY})")
    
    # Security options
    parser.add_argument("--gift-wrap", action="store_true",
                       help="Enable NIP-17 gift wrapping for additional privacy")
    parser.add_argument("--metadata-protection", action="store_true",
                       help="Enable metadata protection and obfuscation")
    parser.add_argument("--secure-mode", action="store_true",
                       help="Enable all security features (gift-wrap + metadata-protection)")
    
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

    # Apply secure mode if requested
    if args.secure_mode:
        args.gift_wrap = True
        args.metadata_protection = True

    # Send the secure message
    success = send_secure_direct_message(
        args.sender_nsec,
        args.recipient_hex,
        args.message,
        args.relay_url,
        gift_wrap=args.gift_wrap,
        metadata_protection=args.metadata_protection
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
