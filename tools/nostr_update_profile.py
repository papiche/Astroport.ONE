#!/usr/bin/env python3
import sys
import json
import argparse
import asyncio
import websockets
import time
import hashlib
from typing import Optional, Dict, Any
import os
from pathlib import Path

# Importer les fonctions de conversion depuis le script existant
sys.path.append(str(Path(__file__).parent))
try:
    from nostr_nsec2npub2hex import nsec_to_hex, hex_to_npub, nsec_to_npub
    HAS_CONVERSION_TOOLS = True
except ImportError:
    HAS_CONVERSION_TOOLS = False

try:
    import secp256k1
    HAS_SECP256K1 = True
except ImportError:
    HAS_SECP256K1 = False

def sign_event(event_dict: dict, private_key_hex: str) -> dict:
    """Signer un événement NOSTR avec une clé privée en utilisant pynostr"""
    try:
        # Utiliser pynostr comme dans nostr_setup_profile.py
        from pynostr.event import Event
        from pynostr.key import PrivateKey
        
        # Créer un objet Event avec pynostr
        event = Event(
            kind=event_dict["kind"],
            content=event_dict["content"],
            tags=event_dict["tags"],
            pubkey=event_dict["pubkey"],
            created_at=event_dict["created_at"]
        )
        
        # Signer avec pynostr (comme dans nostr_setup_profile.py)
        event.sign(private_key_hex)
        
        # Retourner le dictionnaire avec l'ID et la signature
        return {
            "id": event.id,
            "pubkey": event.pubkey,
            "created_at": event.created_at,
            "kind": event.kind,
            "tags": event.tags,
            "content": event.content,
            "sig": event.sig
        }
        
    except Exception as e:
        print(f"❌ Erreur lors de la signature avec pynostr: {e}")
        # Fallback : retourner l'événement non signé
        return event_dict

def convert_private_key(private_key_input: str) -> tuple[str, str]:
    """Convert private key (nsec or hex) and return (hex_privkey, hex_pubkey)"""
    
    if private_key_input.startswith('nsec1'):
        # It's a nsec, convert it
        if not HAS_CONVERSION_TOOLS:
            raise ValueError("❌ bech32 conversion module not available. Cannot process nsec.")
        
        hex_privkey = nsec_to_hex(private_key_input)
        if not hex_privkey:
            raise ValueError("❌ Error converting nsec to hex")
        
        print(f"✅ nsec converted to hex")
        
        # Try to get public key using multiple methods
        hex_pubkey = None
        
        # Method 1: Try nsec_to_npub conversion
        try:
            npub = nsec_to_npub(private_key_input)
            if npub:
                # Convert npub to hex
                from bech32 import bech32_decode, convertbits
                hrp, data = bech32_decode(npub)
                if hrp == 'npub' and data:
                    hex_pubkey = bytes(convertbits(data, 5, 8, False)).hex()
                    print(f"✅ Public key derived via nsec_to_npub: {hex_pubkey}")
        except Exception as e:
            print(f"⚠️ nsec_to_npub failed: {e}, trying other methods...")
        
        # Method 2: Try to extract from user files
        if not hex_pubkey:
            hex_pubkey = extract_pubkey_from_nsec_file(hex_privkey)
            if hex_pubkey:
                print(f"🔑 Public key found in user files")
        
        # Method 3: Try secp256k1 derivation
        if not hex_pubkey and HAS_SECP256K1:
            try:
                private_key = secp256k1.PrivateKey(bytes.fromhex(hex_privkey))
                public_key = private_key.pubkey.serialize(compressed=False)[1:]  # Remove 0x04 prefix
                hex_pubkey = public_key.hex()
                print(f"✅ Public key derived with secp256k1")
            except Exception as e:
                print(f"⚠️ secp256k1 derivation failed: {e}")
        
        if not hex_pubkey:
            raise ValueError("❌ Cannot derive public key (all methods failed)")
        
        return hex_privkey, hex_pubkey
        
    else:
        # Assume it's already in hex
        hex_privkey = private_key_input
        
        # First try to extract from user files
        hex_pubkey = extract_pubkey_from_nsec_file(hex_privkey)
        if hex_pubkey:
            print(f"🔑 Public key found in user files")
            return hex_privkey, hex_pubkey
        
        # Otherwise use secp256k1 to derive
        if HAS_SECP256K1:
            private_key = secp256k1.PrivateKey(bytes.fromhex(hex_privkey))
            public_key = private_key.pubkey.serialize(compressed=False)[1:]  # Remove 0x04 prefix
            hex_pubkey = public_key.hex()
            print(f"✅ Public key derived with secp256k1")
            return hex_privkey, hex_pubkey
        else:
            raise ValueError("❌ secp256k1 not available and public key not found in files")

def read_secret_nostr_file(secret_file_path: Path) -> Optional[Dict[str, str]]:
    """Read .secret.nostr file and extract NSEC, NPUB, HEX"""
    try:
        if not secret_file_path.exists():
            return None
        
        with open(secret_file_path, 'r') as f:
            content = f.read().strip()
        
        # Parse format: NSEC=...; NPUB=...; HEX=...
        result = {}
        for line in content.split(';'):
            line = line.strip()
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip()
                result[key] = value
        
        if 'NSEC' in result:
            return result
        return None
    except Exception as e:
        print(f"⚠️ Error reading .secret.nostr: {e}")
        return None

def find_secret_nostr_file(email_or_path: str) -> Optional[Path]:
    """Find .secret.nostr file from email or path"""
    # If it's a path to .secret.nostr file
    if email_or_path.endswith('.secret.nostr'):
        path = Path(email_or_path)
        if path.exists():
            return path
        # Try as relative path
        path = Path(email_or_path).expanduser()
        if path.exists():
            return path
    
    # If it's a directory path, look for .secret.nostr inside
    if '@' not in email_or_path and Path(email_or_path).is_dir():
        secret_file = Path(email_or_path) / ".secret.nostr"
        if secret_file.exists():
            return secret_file
    
    # If it looks like an email, search in ~/.zen/game/nostr/
    if '@' in email_or_path:
        secret_file = Path.home() / ".zen" / "game" / "nostr" / email_or_path / ".secret.nostr"
        if secret_file.exists():
            return secret_file
    
    return None

def extract_pubkey_from_nsec_file(private_key_hex: str) -> Optional[str]:
    """Extract public key (HEX) from user files by matching private key HEX"""
    # Search in all user directories
    nostr_base = Path.home() / ".zen" / "game" / "nostr"
    
    if not nostr_base.exists():
        return None
    
    for user_dir in nostr_base.iterdir():
        if user_dir.is_dir() and '@' in user_dir.name:
            secret_file = user_dir / ".secret.nostr"
            if secret_file.exists():
                try:
                    secret_data = read_secret_nostr_file(secret_file)
                    if secret_data:
                        # Get NSEC from file and convert to hex to match
                        nsec_val = secret_data.get('NSEC', '')
                        if nsec_val and nsec_val.startswith('nsec1'):
                            # Convert NSEC to hex to compare with private_key_hex
                            if HAS_CONVERSION_TOOLS:
                                try:
                                    nsec_hex = nsec_to_hex(nsec_val)
                                    if nsec_hex and nsec_hex.lower() == private_key_hex.lower():
                                        # Return HEX (public key) from .secret.nostr
                                        hex_val = secret_data.get('HEX', '')
                                        if hex_val:
                                            return hex_val
                                        # Or from separate HEX file
                                        hex_file = user_dir / "HEX"
                                        if hex_file.exists():
                                            with open(hex_file, 'r') as f:
                                                return f.read().strip()
                                except Exception:
                                    pass
                except Exception:
                    continue
    
    return None

async def fetch_current_profile(relay_url: str, pubkey: str) -> Optional[Dict[str, Any]]:
    """Récupérer le profil actuel depuis strfry via WebSocket"""
    try:
        async with websockets.connect(relay_url, timeout=10) as websocket:
            # Créer une requête pour récupérer le profil (kind 0)
            subscription_id = f"profile_fetch_{int(time.time())}"
            request = [
                "REQ",
                subscription_id,
                {
                    "kinds": [0],
                    "authors": [pubkey],
                    "limit": 1
                }
            ]
            
            await websocket.send(json.dumps(request))
            
            profile_event = None
            timeout_counter = 0
            
            while timeout_counter < 50:  # 5 secondes max
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=0.1)
                    data = json.loads(response)
                    
                    if data[0] == "EVENT" and len(data) >= 3:
                        event = data[2]
                        if event.get("kind") == 0 and event.get("pubkey") == pubkey:
                            profile_event = event
                            print(f"✅ Profil existant trouvé: {event.get('id', 'N/A')}")
                            break
                    elif data[0] == "EOSE":
                        # Fin des événements
                        break
                        
                except asyncio.TimeoutError:
                    timeout_counter += 1
                    continue
            
            # Fermer la subscription
            await websocket.send(json.dumps(["CLOSE", subscription_id]))
            
            return profile_event
            
    except Exception as e:
        print(f"Erreur lors de la récupération du profil: {e}")
        return None

async def publish_event(relay_url: str, event: dict) -> bool:
    """Publier un événement sur strfry via WebSocket"""
    try:
        async with websockets.connect(relay_url, timeout=10) as websocket:
            # Publier l'événement
            publish_msg = ["EVENT", event]
            await websocket.send(json.dumps(publish_msg))
            
            # Attendre la confirmation
            timeout_counter = 0
            while timeout_counter < 30:  # 3 secondes max
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=0.1)
                    data = json.loads(response)
                    
                    if data[0] == "OK":
                        if data[2]:  # Success
                            print(f"✅ Événement publié avec succès: {data[1]}")
                            return True
                        else:
                            print(f"❌ Erreur lors de la publication: {data[3] if len(data) > 3 else 'Unknown error'}")
                            return False
                            
                except asyncio.TimeoutError:
                    timeout_counter += 1
                    continue
            
            print("⚠️ Timeout lors de la publication, mais l'événement a peut-être été accepté")
            return True  # On assume que ça a marché
            
    except Exception as e:
        print(f"❌ Erreur lors de la publication: {e}")
        return False

def merge_profile_data(existing_event: Optional[dict], new_args: argparse.Namespace, unknown_args: list) -> dict:
    """Merger les données de profil existantes avec les nouvelles"""
    # Récupérer les métadonnées existantes
    if existing_event:
        try:
            existing_metadata = json.loads(existing_event.get("content", "{}"))
            existing_tags = existing_event.get("tags", [])
        except json.JSONDecodeError:
            existing_metadata = {}
            existing_tags = []
    else:
        existing_metadata = {}
        existing_tags = []
    
    # Créer les nouvelles métadonnées en mergant
    metadata = existing_metadata.copy()
    
    # Mettre à jour avec les nouveaux champs fournis
    fields = ['name', 'about', 'picture', 'banner', 'nip05', 'website']
    for field in fields:
        val = getattr(new_args, field, None)
        if val is not None:
            if val == "":
                metadata.pop(field, None)  # Supprimer le champ si vide
            else:
                metadata[field] = val

    metadata["bot"] = False

    # Gérer les tags 'i' (identités externes)
    tag_map = {}

    # Récupérer les tags existants
    for tag in existing_tags:
        if len(tag) >= 2 and tag[0] == "i" and ":" in tag[1]:
            key, value = tag[1].split(":", 1)
            tag_map[key] = value
    
    # Mettre à jour avec les nouveaux tags
    tag_fields = ['g1pub', 'github', 'twitter', 'mastodon', 'telegram',
                  'ipfs_gw', 'ipns_vault', 'zencard', 'email', 'tw_feed']
    
    for field in tag_fields:
        val = getattr(new_args, field, None)
        if val is not None:
            if val == "":
                tag_map.pop(field, None)  # Supprimer si vide
            else:
                tag_map[field] = val

    # Ajouter les champs dynamiques depuis unknown_args
    for i in range(0, len(unknown_args), 2):
        if i + 1 < len(unknown_args):
            key = unknown_args[i].lstrip("-")
            val = unknown_args[i + 1]
            if val == "":
                tag_map.pop(key, None)
            else:
                tag_map[key] = val

    # Reconstruire les tags
    new_tags = [["i", f"{k}:{v}", ""] for k, v in tag_map.items()]
    
    # Ajouter d'autres tags existants qui ne sont pas de type 'i'
    for tag in existing_tags:
        if len(tag) >= 1 and tag[0] != "i":
            new_tags.append(tag)
    
    return metadata, new_tags

async def update_nostr_profile(private_key_input: str, relays: list, args: argparse.Namespace, unknown_args: list):
    """Mettre à jour le profil NOSTR en préservant les données existantes"""
    try:
        # Convertir la clé privée et obtenir la clé publique
        print(f"🔐 Traitement de la clé privée...")
        hex_privkey, hex_pubkey = convert_private_key(private_key_input)
        
        print(f"🔑 Clé publique: {hex_pubkey}")
        
        # Utiliser le premier relai pour récupérer le profil existant
        relay_url = relays[0] if relays else "ws://127.0.0.1:7777"
        print(f"📡 Connexion au relai: {relay_url}")
        
        # Récupérer le profil existant
        print("📥 Récupération du profil existant...")
        existing_event = await fetch_current_profile(relay_url, hex_pubkey)
        
        if existing_event:
            print(f"✅ Profil existant trouvé, mise à jour...")
        else:
            print("ℹ️ Aucun profil existant, création d'un nouveau profil...")
        
        # Merger les données
        metadata, tags = merge_profile_data(existing_event, args, unknown_args)
        
        # Créer le nouvel événement
        new_event = {
            "pubkey": hex_pubkey,
            "created_at": int(time.time()),
            "kind": 0,
            "tags": tags,
            "content": json.dumps(metadata, ensure_ascii=False)
        }
        
        # Signer l'événement
        signed_event = sign_event(new_event, hex_privkey)
        
        print(f"📤 Publication du profil mis à jour...")
        print(f"   Métadonnées: {len(metadata)} champs")
        print(f"   Tags: {len(tags)} tags")
        
        # Publier sur tous les relais
        success_count = 0
        for relay in relays:
            print(f"   📡 Publication sur {relay}...")
            if await publish_event(relay, signed_event):
                success_count += 1
        
        if success_count > 0:
            print(f"✅ Profil mis à jour avec succès sur {success_count}/{len(relays)} relais")
            return True
        else:
            print("❌ Échec de la publication sur tous les relais")
            return False
            
    except Exception as e:
        print(f"❌ Erreur lors de la mise à jour du profil: {e}")
        return False

async def main():
    parser = argparse.ArgumentParser(
        description="Update Nostr profile metadata (preserves existing data)",
        allow_abbrev=False,
        epilog="""
Examples:
  # Using email (searches ~/.zen/game/nostr/EMAIL/.secret.nostr)
  %(prog)s user@example.com wss://relay.example.com --name "My Name"
  
  # Using path to .secret.nostr file
  %(prog)s ~/.zen/game/nostr/user@example.com/.secret.nostr wss://relay.example.com --name "My Name"
  
  # Using NSEC directly (backward compatibility)
  %(prog)s nsec1... wss://relay.example.com --name "My Name"
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "private_key_or_email",
        help="Private key (nsec1... or hex), email address, or path to .secret.nostr file"
    )
    parser.add_argument("relays", nargs="+", help="List of relays")

    # Known fields
    parser.add_argument("--name", help="Name")
    parser.add_argument("--about", help="About")
    parser.add_argument("--picture", help="Avatar URL")
    parser.add_argument("--banner", help="Banner URL")
    parser.add_argument("--nip05", help="NIP-05 identifier")
    parser.add_argument("--website", help="Website URL")
    parser.add_argument("--g1pub", help="G1 Pubkey")
    parser.add_argument("--github", help="GitHub username")
    parser.add_argument("--twitter", help="Twitter handle")
    parser.add_argument("--mastodon", help="Mastodon handle")
    parser.add_argument("--telegram", help="Telegram handle")
    parser.add_argument("--ipfs_gw", help="IPFS Gateway URL")
    parser.add_argument("--ipns_vault", help="NOSTR Card IPNS vault key")
    parser.add_argument("--zencard", help="ZenCard wallet address")
    parser.add_argument("--email", help="Email address")
    parser.add_argument("--tw_feed", help="TW Feed IPNS key")

    args, unknown_args = parser.parse_known_args()
    
    # Try to find .secret.nostr file if it looks like email or path
    private_key = args.private_key_or_email
    
    # Check if it's an email or path to .secret.nostr
    secret_file_path = find_secret_nostr_file(args.private_key_or_email)
    if secret_file_path:
        print(f"📁 Found .secret.nostr file: {secret_file_path}")
        secret_data = read_secret_nostr_file(secret_file_path)
        if secret_data and 'NSEC' in secret_data:
            private_key = secret_data['NSEC']
            print(f"✅ Using NSEC from .secret.nostr file")
        else:
            print(f"⚠️ No NSEC found in .secret.nostr, using provided value as-is")
    
    success = await update_nostr_profile(private_key, args.relays, args, unknown_args)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
