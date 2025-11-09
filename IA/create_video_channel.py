#!/usr/bin/env python3
"""
Script pour créer des chaînes vidéo à partir des messages NOSTR
Utilise les tags et métadonnées pour grouper les vidéos par chaîne
Peut récupérer des événements NOSTR directement depuis un relay
"""

import json
import sys
import argparse
import asyncio
import websockets
import base64
import hashlib
import hmac
import subprocess
import os
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import re

# Cache for author_id -> email lookups to avoid repeated NOSTR queries
_EMAIL_CACHE = {}

async def fetch_author_email_from_nostr(author_id: str, relay_url: str = "ws://127.0.0.1:7777", timeout: int = 5) -> Optional[str]:
    """
    Récupère l'email de l'auteur depuis son profil NOSTR (kind 0) ou DID (kind 30800)
    Cherche dans:
    1. Tags 'i' avec préfixe 'email:' dans le profil (kind 0)
    2. Champ 'nip05' du profil (kind 0) si format email
    3. DID document (kind 30800) si disponible
    """
    if not author_id or len(author_id) != 64:
        return None
    
    # Check cache first
    if author_id in _EMAIL_CACHE:
        return _EMAIL_CACHE[author_id]
    
    try:
        async with websockets.connect(relay_url, timeout=timeout) as websocket:
            # First, try to fetch profile (kind 0)
            profile_filter = {
                "kinds": [0],
                "authors": [author_id],
                "limit": 1
            }
            
            request = ["REQ", f"profile_{author_id[:8]}", profile_filter]
            await websocket.send(json.dumps(request))
            
            # Wait for profile event
            profile_event = None
            async for message in websocket:
                try:
                    data = json.loads(message)
                    if data[0] == "EVENT":
                        profile_event = data[2]
                        break
                    elif data[0] == "EOSE":
                        break
                except (json.JSONDecodeError, IndexError, KeyError):
                    continue
            
            # Extract email from profile (kind 0)
            if profile_event:
                # Parse profile content
                try:
                    profile_content = json.loads(profile_event.get('content', '{}'))
                    # Check nip05 field (may contain email format)
                    nip05 = profile_content.get('nip05', '')
                    if '@' in nip05 and '.' in nip05:
                        # nip05 format: name@domain.com
                        email = nip05
                        _EMAIL_CACHE[author_id] = email
                        return email
                except (json.JSONDecodeError, KeyError):
                    pass
                
                # Check tags for 'i' tag with 'email:' prefix
                tags = profile_event.get('tags', [])
                for tag in tags:
                    if len(tag) >= 2 and tag[0] == 'i':
                        tag_value = tag[1]
                        if tag_value.startswith('email:'):
                            email = tag_value[6:]  # Remove 'email:' prefix
                            if '@' in email:
                                _EMAIL_CACHE[author_id] = email
                                return email
            
            # If profile didn't have email, try DID (kind 30800)
            did_filter = {
                "kinds": [30800],  # NIP-101 DID events
                "authors": [author_id],
                "limit": 1
            }
            
            request = ["REQ", f"did_{author_id[:8]}", did_filter]
            await websocket.send(json.dumps(request))
            
            # Wait for DID event
            async for message in websocket:
                try:
                    data = json.loads(message)
                    if data[0] == "EVENT":
                        did_event = data[2]
                        # Parse DID content
                        try:
                            did_content = json.loads(did_event.get('content', '{}'))
                            # Extract email from DID metadata or id
                            did_id = did_content.get('id', '')
                            if did_id.startswith('did:nostr:'):
                                # DID format: did:nostr:{hex_pubkey}
                                # Try to extract from metadata or other fields
                                metadata = did_content.get('metadata', {})
                                # Check various possible email fields in DID
                                email = metadata.get('email') or metadata.get('contactEmail') or metadata.get('youser')
                                if email and '@' in email:
                                    _EMAIL_CACHE[author_id] = email
                                    return email
                        except (json.JSONDecodeError, KeyError):
                            pass
                        break
                    elif data[0] == "EOSE":
                        break
                except (json.JSONDecodeError, IndexError, KeyError):
                    continue
                    
    except (websockets.exceptions.WebSocketException, asyncio.TimeoutError, OSError) as e:
        # Silently fail - will fallback to directory lookup
        pass
    except Exception as e:
        # Log unexpected errors but don't fail
        print(f"Warning: Error fetching email from NOSTR for {author_id[:8]}...: {e}", file=sys.stderr)
    
    # Cache None result to avoid repeated queries
    _EMAIL_CACHE[author_id] = None
    return None

async def fetch_nostr_events(relay_url: str = "ws://127.0.0.1:7777", limit: int = 100, timeout: int = 10) -> List[Dict[str, Any]]:
    """
    Récupère les événements NOSTR depuis un relay avec timeout
    """
    events = []
    
    async def _fetch_events():
        async with websockets.connect(relay_url) as websocket:
            # Requête pour récupérer uniquement les événements NIP-71 (kind: 21, 22)
            # According to UPlanet_FILE_CONTRACT.md, videos use tag "t" with prefix "Channel-"
            # We don't filter by #t to avoid excluding valid videos published via /webcam
            filter_data = {
                "kinds": [21, 22],  # NIP-71 Video Events uniquement (normal + shorts)
                "limit": limit
                # No #t filter - fetch ALL kind 21/22 events (filtering happens in is_youtube_video_event)
            }
            
            request = ["REQ", "youtube_videos", filter_data]
            await websocket.send(json.dumps(request))
            
            # Écouter les réponses
            async for message in websocket:
                try:
                    data = json.loads(message)
                    if data[0] == "EVENT":
                        event = data[2]
                        # Vérifier si c'est un événement de vidéo YouTube
                        if is_youtube_video_event(event):
                            events.append(event)
                    elif data[0] == "EOSE":
                        break
                except (json.JSONDecodeError, IndexError, KeyError):
                    continue
    
    try:
        # Add timeout to prevent hanging (compatible with Python < 3.11)
        await asyncio.wait_for(_fetch_events(), timeout=timeout)
    except asyncio.TimeoutError:
        print(f"Timeout lors de la récupération des événements NOSTR depuis {relay_url}")
    except Exception as e:
        print(f"Erreur lors de la récupération des événements NOSTR: {e}")
    
    return events

def is_youtube_video_event(event: Dict[str, Any]) -> bool:
    """
    Vérifie si un événement NOSTR est une vidéo NIP-71 (kind 21 ou 22)
    Accepte TOUTES les vidéos kind 21/22, indépendamment de leur conformité au contrat
    Permet à youtube.html d'afficher toutes les vidéos avec indication de provenance et conformité
    """
    kind = event.get('kind', 1)
    
    # Accepter uniquement les événements NIP-71 (kind: 21 ou 22)
    # On accepte toutes les vidéos, même si elles ne respectent pas strictement UPlanet_FILE_CONTRACT.md
    # La conformité sera vérifiée et affichée par youtube.html
    return kind in [21, 22]

def extract_video_info_from_nostr_event(event: Dict[str, Any], relay_url: str = "ws://127.0.0.1:7777") -> Dict[str, Any]:
    """
    Extrait les informations vidéo d'un événement NOSTR NIP-71
    Supporte uniquement les événements kind: 21 et 22 (NIP-71)
    """
    content = event.get('content', '')
    tags = event.get('tags', [])
    kind = event.get('kind', 21)  # Default to NIP-71
    
    # Extraire les liens IPFS et YouTube depuis les tags NIP-71
    ipfs_url = ""
    youtube_url = ""
    metadata_ipfs = ""
    thumbnail_ipfs = ""
    gifanim_ipfs = ""  # NEW: Animated GIF for video preview on hover
    info_cid = ""      # NEW: info.json CID for metadata reuse
    file_hash = ""     # NEW: File hash for provenance tracking
    upload_chain = ""  # NEW: Upload chain for provenance tracking (comma-separated pubkeys)
    source_type = "webcam"   # NEW: Source type (film, serie, youtube, webcam) - default: webcam
    source_type_explicit = False  # Track if source_type was explicitly set from ["i", "source:*"] tag
    
    # Parse tags for standard NIP-71 fields first
    for tag in tags:
        if len(tag) >= 2:
            tag_type = tag[0]
            tag_value = tag[1]
            
            if tag_type == 'url':
                if 'youtube.com' in tag_value or 'youtu.be' in tag_value:
                    youtube_url = tag_value
                elif '/ipfs/' in tag_value or 'ipfs://' in tag_value:
                    # Normalize IPFS URL format to /ipfs/{CID}/{filename} (UPlanet_FILE_CONTRACT.md)
                    if tag_value.startswith('ipfs://'):
                        tag_value = tag_value.replace('ipfs://', '/ipfs/')
                    ipfs_url = tag_value
            elif tag_type == 'image' and not thumbnail_ipfs:
                # Standard NIP-71 image tag for thumbnails
                thumbnail_ipfs = tag_value
            elif tag_type == 'thumbnail_ipfs' and not thumbnail_ipfs:
                # Direct CID for thumbnail (NEW: from webcam endpoint)
                thumbnail_ipfs = tag_value if not tag_value.startswith('/ipfs/') else tag_value.split('/ipfs/')[-1]
            elif tag_type == 'gifanim_ipfs':
                # NEW: Animated GIF CID for video preview
                gifanim_ipfs = tag_value if not tag_value.startswith('/ipfs/') else tag_value.split('/ipfs/')[-1]
            elif tag_type == 'info':
                # NEW: info.json CID for complete metadata
                info_cid = tag_value
            elif tag_type == 'x':
                # NEW: File hash for provenance/deduplication
                file_hash = tag_value
            elif tag_type == 'upload_chain':
                # NEW: Upload chain for provenance tracking
                upload_chain = tag_value
            elif tag_type == 'i' and tag_value.startswith('source:'):
                # Source type tag (source:film, source:serie, source:youtube, source:webcam)
                # This has PRIORITY - don't override with topic tags
                source_type = tag_value.replace('source:', '')
                source_type_explicit = True  # Mark as explicitly set
            elif tag_type == 'm' and 'video' in tag_value:
                # Media type confirmed as video
                pass
            elif tag_type == 'size' and tag_value.isdigit():
                # File size from NIP-71
                pass
            elif tag_type == 'duration' and tag_value.isdigit():
                # Duration from NIP-71
                pass
            elif tag_type == 'dim':
                dimensions = tag_value
    
    # Parse imeta tags (NIP-71 format) as fallback
    for tag in tags:
        if len(tag) >= 2:
            tag_type = tag[0]
            tag_value = tag[1]
            
            if tag_type == 'imeta':
                # Parse imeta properties
                for prop in tag[1:]:
                    if prop.startswith('dim '):
                        dimensions = prop[4:]
                    elif prop.startswith('url ') and not ipfs_url:
                        ipfs_url = prop[4:]
                    elif prop.startswith('x '):
                        file_hash = prop[2:]
                    elif prop.startswith('m '):
                        media_type = prop[2:]
                    elif prop.startswith('image ') and not thumbnail_ipfs:
                        thumbnail_ipfs = prop[6:]
                    elif prop.startswith('gifanim ') and not gifanim_ipfs:
                        # NEW: Extract gifanim from imeta tag
                        gifanim_ipfs = prop[8:]
                    elif prop.startswith('fallback '):
                        fallback_url = prop[9:]
                    elif prop.startswith('service '):
                        service_type = prop[8:]
            elif tag_type == 'r':
                # Reference tag - check if it's a thumbnail
                if len(tag) >= 3 and tag[2] == 'Thumbnail' and not thumbnail_ipfs:
                    thumbnail_ipfs = tag_value
    
    # Fallback: Parser le contenu si les tags ne contiennent pas les infos
    if not ipfs_url:
        ipfs_match = re.search(r'🔗 IPFS: (https?://[^\s]+)', content)
        if ipfs_match:
            ipfs_url = ipfs_match.group(1)
    
    if not youtube_url:
        # Try to extract from content with emoji prefix
        youtube_match = re.search(r'📺 YouTube: (https?://[^\s]+)', content)
        if youtube_match:
            youtube_url = youtube_match.group(1)
        else:
            # Try to extract any YouTube URL from content
            youtube_match = re.search(r'(https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[\w-]+)', content)
            if youtube_match:
                youtube_url = youtube_match.group(1)
    
    if not metadata_ipfs:
        metadata_match = re.search(r'📋 Métadonnées: (https?://[^\s]+)', content)
        if metadata_match:
            metadata_ipfs = metadata_match.group(1)
    
    if not thumbnail_ipfs:
        thumbnail_match = re.search(r'🖼️ Miniature: (https?://[^\s]+)', content)
        if thumbnail_match:
            thumbnail_ipfs = thumbnail_match.group(1)
    
    # Extraire le titre et l'uploader depuis les tags NIP-71 d'abord
    title = ""
    uploader = ""
    
    # Priorité 1: Extraire depuis les tags NIP-71 (plus fiable)
    for tag in tags:
        if len(tag) >= 2:
            tag_type = tag[0]
            tag_value = tag[1]
            
            if tag_type == 'title' and not title:
                title = tag_value
            elif tag_type == 'uploader' and not uploader:
                uploader = tag_value
    
    # Priorité 2: Fallback - Parser le contenu si les tags sont vides
    if not title or not uploader:
        title_match = re.search(r'🎬 Nouvelle vidéo téléchargée: ([^par]+) par ([^\n]+)', content)
        if title_match:
            if not title:
                title = title_match.group(1).strip()
            if not uploader:
                uploader = title_match.group(2).strip()
    
    # Priorité 3: Extraire depuis le format webcam si toujours vide
    if not title:
        webcam_title_match = re.search(r'🎬 ([^\n]+)', content)
        if webcam_title_match:
            title = webcam_title_match.group(1).strip()
    
    # Valeurs par défaut si toujours vides
    if not title:
        title = "Titre inconnu"
    if not uploader:
        # Try to extract from channel name (tag "t" with "Channel-" prefix)
        # Look for tags of type "t" (topic tags) that start with "Channel-"
        channel_tags = [t[1] for t in tags if len(t) > 1 and t[0] == 't' and t[1].startswith('Channel-')]
        if not channel_tags:
            # Fallback: look for any tag with "Channel-" prefix (for backward compatibility)
            channel_tags = [t[1] for t in tags if len(t) > 1 and t[1].startswith('Channel-')]
        if channel_tags:
            # Convert Channel-email_com to email@com format
            channel_name = channel_tags[0].replace('Channel-', '')
            # Replace first _ with @, then remaining _ with .
            parts = channel_name.split('_', 1)
            if len(parts) == 2:
                uploader = f"{parts[0]}@{parts[1].replace('_', '.')}"
            else:
                uploader = channel_name.replace('_', '@', 1).replace('_', '.')
        else:
            # Try to get uploader from author_id (pubkey) via NOSTR profile/DID
            # Email should already be in cache from batch pre-fetch in fetch_and_process_nostr_events
            author_id = event.get('pubkey', '')
            if author_id:
                # Check cache first (populated by batch pre-fetch)
                if author_id in _EMAIL_CACHE:
                    email_from_nostr = _EMAIL_CACHE[author_id]
                    if email_from_nostr:
                        uploader = email_from_nostr
                
                # Fallback: Try to find user email from pubkey in local directories
                if not uploader:
                    import os
                    nostr_base = os.path.expanduser('~/.zen/game/nostr')
                    if os.path.isdir(nostr_base):
                        for email_dir in os.listdir(nostr_base):
                            email_path = os.path.join(nostr_base, email_dir)
                            if os.path.isdir(email_path):
                                # Check if this directory has the matching pubkey
                                hex_file = os.path.join(email_path, 'HEX')
                                npub_file = os.path.join(email_path, 'NPUB')
                                if os.path.isfile(hex_file):
                                    try:
                                        with open(hex_file, 'r') as f:
                                            hex_key = f.read().strip()
                                            if hex_key == author_id:
                                                uploader = email_dir
                                                break
                                    except (IOError, OSError):
                                        continue
                                elif os.path.isfile(npub_file):
                                    # Would need to convert npub to hex, skip for now
                                    pass
            # Final fallback if uploader still not found
            if not uploader:
                uploader = "Auteur inconnu"
    
    # Extraire les sous-titres
    subtitles = []
    subtitle_matches = re.findall(r'• ([a-z]{2}) \([a-z]+\): (https?://[^\s]+)', content)
    for lang, url in subtitle_matches:
        subtitles.append({
            "language": lang,
            "url": url,
            "format": "vtt" if "vtt" in url else "srt"
        })
    
    # Extraire les tags de chaîne (tag "t" with "Channel-" prefix)
    channel_tags = [t[1] for t in tags if len(t) > 1 and t[0] == 't' and t[1].startswith('Channel-')]
    if not channel_tags:
        # Fallback: look for any tag with "Channel-" prefix
        channel_tags = [t[1] for t in tags if len(t) > 1 and t[1].startswith('Channel-')]
    if channel_tags:
        channel_name = channel_tags[0].replace('Channel-', '')
    elif uploader and uploader != "null" and uploader != "Auteur inconnu":
        # Use uploader as channel name if no Channel tag found
        channel_name = uploader.replace(' ', '_').replace('-', '_').replace('@', '_').replace('.', '_')
    else:
        channel_name = "unknown"
    
    # Extraire les tags de sujet
    topic_tags = [t[1] for t in tags if len(t) > 1 and t[1].startswith('Topic-')]
    topic_keywords = [tag.replace('Topic-', '') for tag in topic_tags]
    
    # Extraire la durée et la taille de fichier depuis les tags NIP-71
    duration = 0
    file_size = 0
    dimensions = ""
    
    # Extraire les coordonnées géographiques depuis les tags NOSTR
    latitude = None
    longitude = None
    
    # Extraire les métadonnées NIP-71 uniquement
    for tag in tags:
        if len(tag) >= 2:
            tag_type = tag[0]
            tag_value = tag[1]
            
            if tag_type == 'duration':
                try:
                    duration = int(tag_value)
                except ValueError:
                    duration = 0
            elif tag_type == 'size':
                try:
                    file_size = int(tag_value)
                except ValueError:
                    file_size = 0
            elif tag_type == 'dim':
                dimensions = tag_value
            elif tag_type == 'g':
                # Geohash tag format: "lat,lon"
                try:
                    coords = tag_value.split(',')
                    if len(coords) == 2:
                        latitude = float(coords[0].strip())
                        longitude = float(coords[1].strip())
                except (ValueError, IndexError):
                    pass
            elif tag_type == 'latitude':
                # Separate latitude tag
                try:
                    latitude = float(tag_value)
                except ValueError:
                    pass
            elif tag_type == 'longitude':
                # Separate longitude tag
                try:
                    longitude = float(tag_value)
                except ValueError:
                    pass
            elif tag_type == 'location':
                # Human-readable location tag format: "lat,lon"
                if latitude is None or longitude is None:  # Only use if not already set
                    try:
                        coords = tag_value.split(',')
                        if len(coords) == 2:
                            latitude = float(coords[0].strip())
                            longitude = float(coords[1].strip())
                    except (ValueError, IndexError):
                        pass
    
    # Extract content (comment/description from event)
    # According to NIP-71, the content field contains a summary or description of the video
    content = event.get('content', '').strip()
    
    # Determine source type from tags (source:film, source:serie, source:youtube, source:webcam)
    # The tag ["i", "source:*"] has PRIORITY - if present, use it and don't override
    # Only use topic tags as fallback if source_type was NOT explicitly set
    if not source_type_explicit and source_type == "webcam":  # Only check if still at default value (no explicit source: tag found)
        # Check topic tags for provenance (fallback only)
        topic_tags = [t[1] for t in tags if len(t) > 1 and t[0] == 't']
        if 'YouTubeDownload' in topic_tags:
            source_type = 'youtube'
        # Keep 'webcam' as default - don't override based on youtube_url presence
    
    # Detect provenance from topic tags
    provenance_tags = [t[1] for t in tags if len(t) > 1 and t[0] == 't']
    provenance = 'unknown'
    if 'YouTubeDownload' in provenance_tags:
        provenance = 'youtube_download'
    elif 'VideoChannel' in provenance_tags:
        provenance = 'video_channel'
    elif source_type == 'youtube':
        provenance = 'youtube'
    elif source_type == 'webcam':
        provenance = 'webcam'
    
    # Check compliance with UPlanet_FILE_CONTRACT.md (as per TUBE.manager.sh)
    # Required: Channel tag (t with "Channel-" prefix), gifanim_ipfs, thumbnail_ipfs, info
    # Also check: x (file hash), upload_chain, dimensions, duration
    has_channel_tag = bool(channel_tags and len(channel_tags) > 0)
    compliance = {
        'has_channel_tag': has_channel_tag,  # Required by TUBE.manager.sh
        'has_file_hash': bool(file_hash),
        'has_info_cid': bool(info_cid),  # Required by TUBE.manager.sh
        'has_thumbnail': bool(thumbnail_ipfs),  # Required by TUBE.manager.sh
        'has_gifanim': bool(gifanim_ipfs),  # Required by TUBE.manager.sh
        'has_upload_chain': bool(upload_chain),
        'has_dimensions': bool(dimensions),
        'has_duration': bool(duration and duration > 0)
    }
    compliance_score = sum(compliance.values())
    compliance_total = len(compliance)
    compliance_percent = int((compliance_score / compliance_total) * 100) if compliance_total > 0 else 0
    
    # Determine compliance level (as per TUBE.manager.sh logic)
    # Compliant: has channel tag + all required metadata (gifanim, thumbnail, info)
    required_fields = ['has_channel_tag', 'has_gifanim', 'has_thumbnail', 'has_info_cid']
    has_all_required = all(compliance.get(field, False) for field in required_fields)
    
    if has_all_required and compliance_percent >= 80:
        compliance_level = 'compliant'
    elif compliance_percent >= 50:
        compliance_level = 'partial'
    else:
        compliance_level = 'non-compliant'
    
    is_compliant = compliance_level == 'compliant'
    
    # Parse upload_chain to extract list of uploaders (copieurs)
    upload_chain_list = []
    if upload_chain:
        try:
            import json
            # Try to parse as JSON array first (new format)
            if upload_chain.strip().startswith('['):
                chain_array = json.loads(upload_chain)
                for entry in chain_array:
                    if isinstance(entry, dict):
                        pubkey = entry.get('pubkey', '')
                        timestamp = entry.get('timestamp')
                    else:
                        pubkey = str(entry)
                        timestamp = None
                    if pubkey and len(pubkey) == 64:
                        # Try to get email from cache or directory lookup
                        email = None
                        if pubkey in _EMAIL_CACHE:
                            email = _EMAIL_CACHE[pubkey]
                        else:
                            # Try directory lookup
                            import os
                            nostr_base = os.path.expanduser('~/.zen/game/nostr')
                            if os.path.isdir(nostr_base):
                                for email_dir in os.listdir(nostr_base):
                                    email_path = os.path.join(nostr_base, email_dir)
                                    if os.path.isdir(email_path):
                                        hex_file = os.path.join(email_path, 'HEX')
                                        if os.path.isfile(hex_file):
                                            try:
                                                with open(hex_file, 'r') as f:
                                                    hex_key = f.read().strip()
                                                    if hex_key == pubkey:
                                                        email = email_dir
                                                        _EMAIL_CACHE[pubkey] = email
                                                        break
                                            except (IOError, OSError):
                                                continue
                        upload_chain_list.append({
                            'pubkey': pubkey,
                            'email': email or f"{pubkey[:8]}...",
                            'timestamp': timestamp
                        })
            else:
                # Parse as comma-separated string (old format)
                pubkeys = [p.strip() for p in upload_chain.split(',') if p.strip() and len(p.strip()) == 64]
                for pubkey in pubkeys:
                    email = None
                    if pubkey in _EMAIL_CACHE:
                        email = _EMAIL_CACHE[pubkey]
                    else:
                        # Try directory lookup
                        import os
                        nostr_base = os.path.expanduser('~/.zen/game/nostr')
                        if os.path.isdir(nostr_base):
                            for email_dir in os.listdir(nostr_base):
                                email_path = os.path.join(nostr_base, email_dir)
                                if os.path.isdir(email_path):
                                    hex_file = os.path.join(email_path, 'HEX')
                                    if os.path.isfile(hex_file):
                                        try:
                                            with open(hex_file, 'r') as f:
                                                hex_key = f.read().strip()
                                                if hex_key == pubkey:
                                                    email = email_dir
                                                    _EMAIL_CACHE[pubkey] = email
                                                    break
                                        except (IOError, OSError):
                                            continue
                    upload_chain_list.append({
                        'pubkey': pubkey,
                        'email': email or f"{pubkey[:8]}...",
                        'timestamp': None
                    })
        except (json.JSONDecodeError, ValueError, AttributeError):
            # If parsing fails, keep upload_chain as string
            pass
    
    return {
        'title': title,
        'uploader': uploader,
        'content': content,  # Comment/description from the event (NIP-71)
        'ipfs_url': ipfs_url,
        'youtube_url': youtube_url,  # Utilise youtube_url pour la cohérence
        'original_url': youtube_url,  # Alias pour compatibilité avec process_youtube.sh
        'metadata_ipfs': metadata_ipfs,
        'thumbnail_ipfs': thumbnail_ipfs,
        'gifanim_ipfs': gifanim_ipfs,  # NEW: Animated GIF CID for hover preview
        'info_cid': info_cid,  # NEW: info.json CID for metadata reuse
        'file_hash': file_hash,  # NEW: File hash for provenance tracking
        'upload_chain': upload_chain,  # NEW: Upload chain for provenance (comma-separated pubkeys)
        'upload_chain_list': upload_chain_list,  # NEW: Parsed upload chain list (copieurs)
        'source_type': source_type,  # NEW: Source type (film, serie, youtube, webcam)
        'provenance': provenance,  # NEW: Provenance detected from tags (youtube_download, video_channel, webcam, etc.)
        'compliance': compliance,  # NEW: Compliance check with UPlanet_FILE_CONTRACT.md
        'compliance_score': compliance_score,  # NEW: Number of compliant fields
        'compliance_percent': compliance_percent,  # NEW: Percentage of compliance
        'compliance_level': compliance_level,  # NEW: Compliance level (compliant, partial, non-compliant)
        'is_compliant': is_compliant,  # NEW: Boolean indicating if video is compliant (>=80%)
        'subtitles': subtitles,
        'channel_name': channel_name,
        'topic_keywords': ','.join(topic_keywords),
        'message_id': event.get('id', ''),
        'author_id': event.get('pubkey', ''),
        'created_at': datetime.fromtimestamp(event.get('created_at', 0)).isoformat(),
        'download_date': datetime.fromtimestamp(event.get('created_at', 0)).isoformat(),  # Alias pour compatibilité
        'duration': duration,  # Extrait depuis les tags NOSTR
        'file_size': file_size,  # Extrait depuis les tags NOSTR
        'dimensions': dimensions,  # Nouvelles dimensions NIP-71
        'latitude': latitude,  # Latitude extraite depuis les tags NOSTR
        'longitude': longitude,  # Longitude extraite depuis les tags NOSTR
        'event_kind': kind,  # Type d'événement (21 ou 22)
        'technical_info': {
            'download_date': datetime.fromtimestamp(event.get('created_at', 0)).isoformat(),
            'file_size': file_size,
            'dimensions': dimensions,
            'info_cid': info_cid,  # NEW: info.json CID
            'file_hash': file_hash,  # NEW: File hash
            'upload_chain': upload_chain  # NEW: Upload chain for provenance
        }
    }

def parse_nostr_message(message_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Parse un message NOSTR pour extraire les informations de vidéo
    """
    # Extraire les informations de base
    video_info = {
        'title': message_data.get('title', ''),
        'uploader': message_data.get('uploader', ''),
        'content': message_data.get('content', ''),  # Comment/description from event (NIP-71)
        'duration': message_data.get('duration', 0),
        'ipfs_url': message_data.get('ipfs_url', ''),
        'youtube_url': message_data.get('original_url', ''),  # Compatible avec process_youtube.sh
        'thumbnail_ipfs': message_data.get('thumbnail_ipfs', ''),
        'gifanim_ipfs': message_data.get('gifanim_ipfs', ''),  # NEW: Animated GIF CID
        'info_cid': message_data.get('info_cid', ''),  # NEW: info.json CID
        'file_hash': message_data.get('file_hash', ''),  # NEW: File hash
        'upload_chain': message_data.get('upload_chain', ''),  # NEW: Upload chain
        'metadata_ipfs': message_data.get('metadata_ipfs', ''),
        'download_date': message_data.get('technical_info', {}).get('download_date', ''),
        'file_size': message_data.get('technical_info', {}).get('file_size', 0),
        'subtitles': message_data.get('subtitles', []),  # Ajout des sous-titres
        'message_id': message_data.get('message_id', ''),
        'author_id': message_data.get('author_id', ''),
        'latitude': message_data.get('latitude'),  # Coordonnées GPS
        'longitude': message_data.get('longitude')  # Coordonnées GPS
    }
    
    # Extraire les informations de chaîne
    channel_info = message_data.get('channel_info', {})
    video_info['channel_name'] = channel_info.get('name', '')
    video_info['channel_display_name'] = channel_info.get('display_name', '')
    
    # Fallback: if no channel_info, use uploader as channel name
    if not video_info['channel_name'] and video_info.get('uploader'):
        video_info['channel_name'] = video_info['uploader'].replace(' ', '_').replace('-', '_')
    
    # Extraire les informations de contenu
    content_info = message_data.get('content_info', {})
    video_info['description'] = content_info.get('description', '')
    video_info['ai_analysis'] = content_info.get('ai_analysis', '')
    video_info['topic_keywords'] = content_info.get('topic_keywords', '')
    video_info['duration_category'] = content_info.get('duration_category', '')
    
    # Ajouter les nouvelles métadonnées NIP-71
    video_info['dimensions'] = message_data.get('dimensions', '')
    video_info['event_kind'] = message_data.get('event_kind', 1)
    
    return video_info

def is_incompatible_youtube_message(event: Dict[str, Any]) -> bool:
    """
    Détermine si un message YouTube NIP-71 est incompatible avec l'affichage youtube.html
    Un message est incompatible s'il manque des tags essentiels NIP-71
    Supporte uniquement les événements kind: 21 et 22 (NIP-71)
    """
    tags = event.get('tags', [])
    kind = event.get('kind', 21)
    
    # Accepter uniquement les événements NIP-71 (kind: 21 ou 22)
    if kind not in [21, 22]:
        return True  # Incompatible si ce n'est pas NIP-71
    
    # Vérifier les tags NIP-71 essentiels
    has_video_url = False
    has_media_type = False
    
    for tag in tags:
        if len(tag) >= 2:
            tag_type = tag[0]
            tag_value = tag[1]
            
            if tag_type == 'url' and ('ipfs' in tag_value or 'youtube' in tag_value):
                has_video_url = True
            elif tag_type == 'm' and 'video' in tag_value:
                has_media_type = True
    
    return not (has_video_url and has_media_type)


def create_channel_playlist(videos: List[Dict[str, Any]], channel_name: str) -> Dict[str, Any]:
    """
    Créer une playlist de chaîne à partir d'une liste de vidéos
    """
    # Validate and filter videos
    valid_videos = []
    for video in videos:
        if video.get('title') and video.get('ipfs_url'):
            valid_videos.append(video)
    
    videos = valid_videos
    
    # Trier les vidéos par date de téléchargement
    videos.sort(key=lambda x: x.get('download_date', ''), reverse=True)
    
    # Calculer les statistiques de la chaîne
    total_duration = sum(int(v.get('duration', 0)) for v in videos)
    total_size = sum(int(v.get('file_size', 0)) for v in videos)
    
    # Extraire les mots-clés communs
    all_keywords = []
    for video in videos:
        keywords = video.get('topic_keywords', '').split(',')
        all_keywords.extend([k.strip() for k in keywords if k.strip()])
    
    # Compter les mots-clés
    from collections import Counter
    keyword_counts = Counter(all_keywords)
    common_keywords = [kw for kw, count in keyword_counts.most_common(10) if count > 1]
    
    channel_playlist = {
        'channel_info': {
            'name': channel_name,
            'display_name': videos[0].get('channel_display_name', '') if videos else '',
            'type': 'youtube',
            'created_date': datetime.now().isoformat(),
            'video_count': len(videos),
            'total_duration_seconds': total_duration,
            'total_duration_formatted': f"{total_duration // 3600}h {(total_duration % 3600) // 60}m",
            'total_size_bytes': total_size,
            'total_size_formatted': f"{total_size / (1024*1024*1024):.2f} GB",
            'common_keywords': common_keywords
        },
        'videos': videos,
        'playlist_url': f"/youtube?html=1&channel={channel_name}",  # URL to view this channel
        'export_formats': {
            'm3u': f"#EXTM3U\n#EXTINF:-1,{channel_name}\n" + "\n".join([v['ipfs_url'] for v in videos]),
            'json': json.dumps(videos, indent=2),
            'csv': "title,uploader,duration,ipfs_url,youtube_url\n" + 
                   "\n".join([f'"{v["title"]}","{v["uploader"]}",{v["duration"]},"{v["ipfs_url"]}","{v["youtube_url"]}"' for v in videos])
        }
    }
    
    return channel_playlist

async def fetch_and_process_nostr_events(relay_url: str = "ws://127.0.0.1:7777", limit: int = 100) -> List[Dict[str, Any]]:
    """
    Récupère et traite les événements NOSTR NIP-71 pour créer des chaînes vidéo
    Filtre automatiquement les messages incompatibles et affiche les statistiques
    Ne traite que les événements kind: 21 et 22 (NIP-71)
    """
    events = await fetch_nostr_events(relay_url, limit)
    video_messages = []
    
    # Pre-fetch emails for all unique authors in batch (more efficient)
    unique_authors = set()
    for event in events:
        if not is_incompatible_youtube_message(event):
            author_id = event.get('pubkey', '')
            if author_id and author_id not in _EMAIL_CACHE:
                unique_authors.add(author_id)
    
    # Fetch emails in parallel for better performance
    if unique_authors:
        tasks = [fetch_author_email_from_nostr(author_id, relay_url, timeout=3) for author_id in unique_authors]
        await asyncio.gather(*tasks, return_exceptions=True)
    
    for event in events:
        # Filtrer les messages incompatibles
        if is_incompatible_youtube_message(event):
            continue
            
        video_info = extract_video_info_from_nostr_event(event, relay_url)
        video_messages.append(video_info)
    
    return video_messages

def main():
    parser = argparse.ArgumentParser(description="Créer des chaînes vidéo à partir des messages NOSTR")
    parser.add_argument("--input", "-i", help="Fichier JSON contenant les messages NOSTR")
    parser.add_argument("--channel", "-c", help="Nom de la chaîne à créer")
    parser.add_argument("--output", "-o", help="Fichier de sortie pour la playlist")
    parser.add_argument("--format", "-f", choices=['json', 'm3u', 'csv'], default='json', help="Format de sortie")
    parser.add_argument("--relay", "-r", default="ws://127.0.0.1:7777", help="URL du relay NOSTR")
    parser.add_argument("--limit", "-l", type=int, default=100, help="Nombre maximum d'événements à récupérer")
    parser.add_argument("--fetch-nostr", action="store_true", help="Récupérer les événements depuis NOSTR au lieu d'un fichier")
    
    args = parser.parse_args()
    
    # Charger les données d'entrée
    if args.fetch_nostr:
        # Récupérer depuis NOSTR
        messages = asyncio.run(fetch_and_process_nostr_events(args.relay, args.limit))
    elif args.input:
        with open(args.input, 'r') as f:
            messages = json.load(f)
    else:
        # Lire depuis stdin
        messages = json.load(sys.stdin)
    
    # Grouper les vidéos par chaîne
    channels = {}
    for message in messages:
        video_info = parse_nostr_message(message)
        channel_name = video_info.get('channel_name', 'unknown')
        
        if channel_name not in channels:
            channels[channel_name] = []
        
        channels[channel_name].append(video_info)
    
    # Créer les playlists de chaînes
    channel_playlists = {}
    for channel_name, videos in channels.items():
        channel_playlists[channel_name] = create_channel_playlist(videos, channel_name)
    
    # Afficher la sortie
    if args.channel and args.channel in channel_playlists:
        playlist = channel_playlists[args.channel]
        
        if args.format == 'json':
            output = json.dumps(playlist, indent=2, ensure_ascii=False)
        elif args.format == 'm3u':
            output = playlist['export_formats']['m3u']
        elif args.format == 'csv':
            output = playlist['export_formats']['csv']
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output)
        else:
            print(output)
    else:
        # Afficher toutes les chaînes disponibles
        print("Chaînes disponibles:")
        for channel_name, playlist in channel_playlists.items():
            print(f"- {channel_name}: {playlist['channel_info']['video_count']} vidéos")

if __name__ == "__main__":
    main()
