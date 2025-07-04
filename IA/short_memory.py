#!/usr/bin/env python3
import os
import sys
import json
from datetime import datetime

# Paramètres attendus : event_json, latitude, longitude
def main():
    if len(sys.argv) < 4:
        print("Usage: short_memory.py '<event_json>' <latitude> <longitude>")
        sys.exit(1)

    event_json = json.loads(sys.argv[1])
    latitude = sys.argv[2]
    longitude = sys.argv[3]

    event_id = event_json.get('event', {}).get('id', '')
    content = event_json.get('event', {}).get('content', '')
    pubkey = event_json.get('event', {}).get('pubkey', '')

    # Répertoire de stockage de la mémoire contextuelle
    MEMORY_DIR = os.path.expanduser("~/.zen/tmp/flashmem/uplanet_memory")
    os.makedirs(MEMORY_DIR, exist_ok=True)

    # Fichier de mémoire par coordonnées
    coord_key = f"{latitude}_{longitude}".replace(".", "_").replace("-", "m")
    memory_file = os.path.join(MEMORY_DIR, f"{coord_key}.json")

    # Charger la mémoire existante pour les coordonnées
    if os.path.isfile(memory_file):
        with open(memory_file, 'r') as f:
            memory = json.load(f)
    else:
        memory = {
            "latitude": latitude,
            "longitude": longitude,
            "messages": []
        }

    # Ajouter le nouveau message pour les coordonnées
    memory['messages'].append({
        "timestamp": datetime.utcnow().isoformat() + 'Z',
        "event_id": event_id,
        "pubkey": pubkey,
        "content": content
    })

    # Limiter à 50 derniers messages
    memory['messages'] = memory['messages'][-50:]

    # Sauvegarder la mémoire par coordonnées
    with open(memory_file, 'w') as f:
        json.dump(memory, f, indent=2)

    ### --- AJOUT : mémoire par pubkey --- ###

    # Répertoire spécifique pour les pubkeys
    PUBKEY_DIR = os.path.join(MEMORY_DIR, "pubkey")
    os.makedirs(PUBKEY_DIR, exist_ok=True)

    pubkey_file = os.path.join(PUBKEY_DIR, f"{pubkey}.json")

    # Charger la mémoire existante pour la pubkey
    if os.path.isfile(pubkey_file):
        with open(pubkey_file, 'r') as f:
            pub_memory = json.load(f)
    else:
        pub_memory = {
            "pubkey": pubkey,
            "messages": []
        }

    # Ajouter le message pour la pubkey
    pub_memory['messages'].append({
        "timestamp": datetime.utcnow().isoformat() + 'Z',
        "event_id": event_id,
        "latitude": latitude,
        "longitude": longitude,
        "content": content
    })

    # Limiter à 50 derniers messages
    pub_memory['messages'] = pub_memory['messages'][-50:]

    # Sauvegarder la mémoire par pubkey
    with open(pubkey_file, 'w') as f:
        json.dump(pub_memory, f, indent=2)

    print(f"Memory updated for coordinates: {latitude}, {longitude}")
    print(f"Memory updated for pubkey: {pubkey}")

if __name__ == "__main__":
    main()
