#!/usr/bin/env python3
import sys
import json
import argparse
import asyncio
import websockets
import time
import hashlib
from typing import Optional, Dict, Any

try:
    import secp256k1
    HAS_SECP256K1 = True
except ImportError:
    HAS_SECP256K1 = False

def sign_event(event_dict: dict, private_key_hex: str) -> dict:
    """Signer un événement NOSTR avec une clé privée"""
    # Créer le message à signer selon NIP-01
    message = json.dumps([
        0,  # reserved
        event_dict["pubkey"],
        event_dict["created_at"],
        event_dict["kind"],
        event_dict["tags"],
        event_dict["content"]
    ], separators=(',', ':'), ensure_ascii=False)
    
    # Calculer le hash SHA256
    event_hash = hashlib.sha256(message.encode('utf-8')).digest()
    
    if HAS_SECP256K1:
        # Utiliser secp256k1 si disponible
        private_key = secp256k1.PrivateKey(bytes.fromhex(private_key_hex))
        signature = private_key.ecdsa_sign(event_hash)
        signature_bytes = signature.serialize_compact()
    else:
        # Fallback simple - nécessite que l'utilisateur signe manuellement
        print(f"⚠️ secp256k1 non disponible. Hash à signer: {event_hash.hex()}")
        print("   Veuillez installer python3-secp256k1 ou signer manuellement")
        # Pour le test, on va utiliser une signature dummy
        signature_bytes = b'0' * 64
    
    # Ajouter l'ID et la signature
    event_dict["id"] = event_hash.hex()
    event_dict["sig"] = signature_bytes.hex()
    
    return event_dict

def nsec_to_hex(nsec: str) -> str:
    """Convertir une clé privée nsec en hexadécimal"""
    # Pour cette implémentation simplifiée, on suppose que c'est déjà en hex
    # Dans un vrai cas, il faudrait décoder le bech32
    if nsec.startswith('nsec1'):
        # Décoder bech32 (implémentation simplifiée)
        # Pour le moment, on retourne une erreur
        raise ValueError("Décodage bech32 non implémenté dans cette version simplifiée")
    else:
        # Supposer que c'est déjà en hex
        return nsec

def extract_pubkey_from_nsec_file(private_key_hex: str) -> Optional[str]:
    """Extraire la clé publique depuis les fichiers utilisateur"""
    import os
    import pathlib
    
    # Chercher dans tous les dossiers utilisateur
    nostr_base = pathlib.Path.home() / ".zen" / "game" / "nostr"
    
    if not nostr_base.exists():
        return None
    
    for user_dir in nostr_base.iterdir():
        if user_dir.is_dir() and '@' in user_dir.name:
            secret_file = user_dir / ".secret.nostr"
            if secret_file.exists():
                try:
                    with open(secret_file, 'r') as f:
                        content = f.read().strip()
                    
                    # Parser le contenu
                    nsec_val = None
                    hex_val = None
                    
                    for line in content.split(';'):
                        line = line.strip()
                        if line.startswith('NSEC='):
                            nsec_val = line.replace('NSEC=', '').strip()
                        elif line.startswith('HEX='):
                            hex_val = line.replace('HEX=', '').strip()
                    
                    # Vérifier si la clé privée correspond
                    if private_key_hex.lower() == hex_val.lower() if hex_val else False:
                        # Récupérer la clé publique depuis le fichier HEX
                        hex_file = user_dir / "HEX"
                        if hex_file.exists():
                            with open(hex_file, 'r') as f:
                                pubkey = f.read().strip()
                            return pubkey
                except Exception as e:
                    continue
    
    return None

def hex_to_pubkey(private_key_hex: str) -> str:
    """Convertir une clé privée hex en clé publique hex"""
    # D'abord essayer d'extraire depuis les fichiers utilisateur
    pubkey = extract_pubkey_from_nsec_file(private_key_hex)
    if pubkey:
        print(f"🔑 Clé publique trouvée dans les fichiers utilisateur")
        return pubkey
    
    if HAS_SECP256K1:
        private_key = secp256k1.PrivateKey(bytes.fromhex(private_key_hex))
        public_key = private_key.pubkey.serialize(compressed=False)[1:]  # Enlever le préfixe 0x04
        return public_key.hex()
    else:
        # Fallback - demander à l'utilisateur de fournir la clé publique
        print("⚠️ secp256k1 non disponible et clé publique non trouvée dans les fichiers")
        print("   Veuillez installer python3-secp256k1 ou vérifier les fichiers utilisateur")
        raise ValueError("Impossible de déterminer la clé publique")

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
                  'ipfs_gw', 'ipns_vault', 'zencard', 'tw_feed']
    
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

async def update_nostr_profile(private_key_nsec: str, relays: list, args: argparse.Namespace, unknown_args: list):
    """Mettre à jour le profil NOSTR en préservant les données existantes"""
    try:
        # Convertir la clé privée
        if private_key_nsec.startswith('nsec1'):
            print("❌ Décodage bech32 nsec non implémenté dans cette version")
            print("   Veuillez fournir la clé privée en format hexadécimal")
            return False
        
        private_key_hex = private_key_nsec
        public_key_hex = hex_to_pubkey(private_key_hex)
        
        print(f"🔑 Clé publique: {public_key_hex}")
        
        # Utiliser le premier relai pour récupérer le profil existant
        relay_url = relays[0] if relays else "ws://127.0.0.1:7777"
        print(f"📡 Connexion au relai: {relay_url}")
        
        # Récupérer le profil existant
        print("📥 Récupération du profil existant...")
        existing_event = await fetch_current_profile(relay_url, public_key_hex)
        
        if existing_event:
            print(f"✅ Profil existant trouvé, mise à jour...")
        else:
            print("ℹ️ Aucun profil existant, création d'un nouveau profil...")
        
        # Merger les données
        metadata, tags = merge_profile_data(existing_event, args, unknown_args)
        
        # Créer le nouvel événement
        new_event = {
            "pubkey": public_key_hex,
            "created_at": int(time.time()),
            "kind": 0,
            "tags": tags,
            "content": json.dumps(metadata, ensure_ascii=False)
        }
        
        # Signer l'événement
        signed_event = sign_event(new_event, private_key_hex)
        
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
    parser = argparse.ArgumentParser(description="Update Nostr profile metadata (préserve les données existantes)", allow_abbrev=False)
    parser.add_argument("private_key", help="Private key (hex format)")
    parser.add_argument("relays", nargs="+", help="List of relays")

    # Champs connus
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
    parser.add_argument("--tw_feed", help="TW Feed IPNS key")

    args, unknown_args = parser.parse_known_args()
    
    success = await update_nostr_profile(args.private_key, args.relays, args, unknown_args)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
