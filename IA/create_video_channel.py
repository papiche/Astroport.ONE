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

async def fetch_nostr_events(relay_url: str = "ws://127.0.0.1:7777", limit: int = 100) -> List[Dict[str, Any]]:
    """
    Récupère les événements NOSTR depuis un relay
    """
    events = []
    
    try:
        async with websockets.connect(relay_url) as websocket:
            # Requête pour récupérer les événements avec tags YouTube
            filter_data = {
                "kinds": [1],  # Text notes
                "limit": limit,
                "#t": ["YouTubeDownload", "VideoChannel"]
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
                    
    except Exception as e:
        print(f"Erreur lors de la récupération des événements NOSTR: {e}")
    
    return events

def is_youtube_video_event(event: Dict[str, Any]) -> bool:
    """
    Vérifie si un événement NOSTR est une vidéo YouTube
    """
    tags = event.get('tags', [])
    
    # Vérifier les tags YouTube
    youtube_tags = ['YouTubeDownload', 'VideoChannel', 'uDRIVE', 'IPFS']
    has_youtube_tags = any(tag in [t[1] for t in tags if len(t) > 1] for tag in youtube_tags)
    
    # Vérifier le contenu pour des liens IPFS
    content = event.get('content', '')
    has_ipfs_links = 'ipfs://' in content or '/ipfs/' in content
    
    return has_youtube_tags and has_ipfs_links

def extract_video_info_from_nostr_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extrait les informations vidéo d'un événement NOSTR
    """
    content = event.get('content', '')
    tags = event.get('tags', [])
    
    # Extraire les liens IPFS et YouTube depuis les tags NOSTR
    ipfs_url = ""
    youtube_url = ""
    metadata_ipfs = ""
    thumbnail_ipfs = ""
    
    # Parser les tags NOSTR pour extraire les liens
    for tag in tags:
        if len(tag) >= 3 and tag[0] == 'r':
            url = tag[1]
            tag_type = tag[2] if len(tag) > 2 else ''
            
            if 'youtube.com' in url or 'youtu.be' in url:
                youtube_url = url
            elif '/ipfs/' in url or 'ipfs://' in url:
                if 'Video' in tag_type:
                    # Main video IPFS URL (priority)
                    ipfs_url = url
                elif 'Metadata' in tag_type:
                    metadata_ipfs = url
                elif 'Thumbnail' in tag_type:
                    thumbnail_ipfs = url
                elif 'Subtitle' in tag_type:
                    # Skip subtitles as they're no longer handled
                    continue
                elif not ipfs_url:
                    # Fallback: if no Video tag found, use any IPFS URL as main
                    ipfs_url = url
    
    # Fallback: Parser le contenu si les tags ne contiennent pas les infos
    if not ipfs_url:
        ipfs_match = re.search(r'🔗 IPFS: (https?://[^\s]+)', content)
        if ipfs_match:
            ipfs_url = ipfs_match.group(1)
    
    if not youtube_url:
        youtube_match = re.search(r'📺 YouTube: (https?://[^\s]+)', content)
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
    
    # Extraire le titre et l'uploader
    title_match = re.search(r'🎬 Nouvelle vidéo téléchargée: ([^par]+) par ([^\n]+)', content)
    title = title_match.group(1).strip() if title_match else "Titre inconnu"
    uploader = title_match.group(2).strip() if title_match else "Auteur inconnu"
    
    # Extraire les sous-titres
    subtitles = []
    subtitle_matches = re.findall(r'• ([a-z]{2}) \([a-z]+\): (https?://[^\s]+)', content)
    for lang, url in subtitle_matches:
        subtitles.append({
            "language": lang,
            "url": url,
            "format": "vtt" if "vtt" in url else "srt"
        })
    
    # Extraire les tags de chaîne
    channel_tags = [t[1] for t in tags if len(t) > 1 and t[1].startswith('Channel-')]
    if channel_tags:
        channel_name = channel_tags[0].replace('Channel-', '')
    elif uploader and uploader != "null":
        # Use uploader as channel name if no Channel tag found
        channel_name = uploader.replace(' ', '_').replace('-', '_')
    else:
        channel_name = "unknown"
    
    # Extraire les tags de sujet
    topic_tags = [t[1] for t in tags if len(t) > 1 and t[1].startswith('Topic-')]
    topic_keywords = [tag.replace('Topic-', '') for tag in topic_tags]
    
    return {
        'title': title,
        'uploader': uploader,
        'ipfs_url': ipfs_url,
        'youtube_url': youtube_url,  # Utilise youtube_url pour la cohérence
        'original_url': youtube_url,  # Alias pour compatibilité avec process_youtube.sh
        'metadata_ipfs': metadata_ipfs,
        'thumbnail_ipfs': thumbnail_ipfs,
        'subtitles': subtitles,
        'channel_name': channel_name,
        'topic_keywords': ','.join(topic_keywords),
        'nostr_event_id': event.get('id', ''),
        'nostr_pubkey': event.get('pubkey', ''),
        'message_id': event.get('id', ''),  # Alias pour compatibilité avec youtube.html
        'author_id': event.get('pubkey', ''),  # Alias pour compatibilité avec youtube.html
        'created_at': datetime.fromtimestamp(event.get('created_at', 0)).isoformat(),
        'download_date': datetime.fromtimestamp(event.get('created_at', 0)).isoformat(),  # Alias pour compatibilité
        'duration': 0,  # Pas disponible dans les événements NOSTR
        'file_size': 0,  # Pas disponible dans les événements NOSTR
        'technical_info': {
            'download_date': datetime.fromtimestamp(event.get('created_at', 0)).isoformat(),
            'file_size': 0
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
        'duration': message_data.get('duration', 0),
        'ipfs_url': message_data.get('ipfs_url', ''),
        'youtube_url': message_data.get('original_url', ''),  # Compatible avec process_youtube.sh
        'thumbnail_ipfs': message_data.get('thumbnail_ipfs', ''),
        'metadata_ipfs': message_data.get('metadata_ipfs', ''),
        'download_date': message_data.get('technical_info', {}).get('download_date', ''),
        'file_size': message_data.get('technical_info', {}).get('file_size', 0),
        'subtitles': message_data.get('subtitles', []),  # Ajout des sous-titres
        'message_id': message_data.get('message_id', ''),
        'author_id': message_data.get('author_id', ''),
        'nostr_event_id': message_data.get('nostr_event_id', ''),
        'nostr_pubkey': message_data.get('nostr_pubkey', '')
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
    
    return video_info

def is_incompatible_youtube_message(event: Dict[str, Any]) -> bool:
    """
    Détermine si un message YouTube est incompatible avec l'affichage youtube.html
    Un message est incompatible s'il manque des tags essentiels
    """
    tags = event.get('tags', [])
    
    # Vérifier si c'est un message YouTube
    youtube_tags = ['YouTubeDownload', 'VideoChannel', 'uDRIVE', 'IPFS']
    has_youtube_tags = any(tag in [t[1] for t in tags if len(t) > 1] for tag in youtube_tags)
    
    if not has_youtube_tags:
        return True  # Pas un message YouTube, incompatible
    
    # Vérifier la présence des tags essentiels
    has_video_url = False
    has_youtube_url = False
    has_channel_tag = False
    
    for tag in tags:
        if len(tag) >= 3 and tag[0] == 'r':
            url = tag[1]
            tag_type = tag[2] if len(tag) > 2 else ''
            
            if 'youtube.com' in url or 'youtu.be' in url:
                has_youtube_url = True
            elif '/ipfs/' in url or 'ipfs://' in url:
                # Accepter tout lien IPFS (Video, Metadata, Thumbnail)
                has_video_url = True
        elif len(tag) >= 2 and tag[0] == 't':
            tag_value = tag[1]
            if tag_value.startswith('Channel-'):
                has_channel_tag = True
    
    # Un message est incompatible s'il manque des tags essentiels
    return not (has_video_url and has_youtube_url and has_channel_tag)


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
        'playlist_url': f"ipfs://channel/{channel_name}",
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
    Récupère et traite les événements NOSTR pour créer des chaînes vidéo
    Filtre automatiquement les messages incompatibles et affiche les statistiques
    """
    events = await fetch_nostr_events(relay_url, limit)
    video_messages = []
    filtered_count = 0
    
    print(f"📊 Processing {len(events)} YouTube events...")
    
    for event in events:
        # Filtrer les messages incompatibles
        if is_incompatible_youtube_message(event):
            filtered_count += 1
            continue
            
        video_info = extract_video_info_from_nostr_event(event)
        video_messages.append(video_info)
    
    print(f"✅ {len(video_messages)} compatible messages")
    if filtered_count > 0:
        print(f"🔍 {filtered_count} incompatible messages filtered out")
    
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
