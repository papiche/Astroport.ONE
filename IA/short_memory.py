#!/usr/bin/env python3
import os
import sys
import json
from datetime import datetime

# Paramètres attendus : event_json, latitude, longitude, slot, user_id
def main():
    if len(sys.argv) < 4:
        print("Usage: short_memory.py '<event_json>' <latitude> <longitude> [slot] [user_id]")
        sys.exit(1)

    event_json = json.loads(sys.argv[1])
    latitude = sys.argv[2]
    longitude = sys.argv[3]
    slot = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() and 0 <= int(sys.argv[4]) <= 12 else 0
    user_id = sys.argv[5] if len(sys.argv) > 5 else None

    event_id = event_json.get('event', {}).get('id', '')
    content = event_json.get('event', {}).get('content', '')
    pubkey = event_json.get('event', {}).get('pubkey', '')

    # Directory for contextual memory
    MEMORY_DIR = os.path.expanduser("~/.zen/tmp/flashmem/uplanet_memory")
    os.makedirs(MEMORY_DIR, exist_ok=True)

    # Coordinate-based memory (legacy)
    coord_key = f"{latitude}_{longitude}".replace(".", "_").replace("-", "m")
    memory_file = os.path.join(MEMORY_DIR, f"{coord_key}.json")
    if os.path.isfile(memory_file):
        with open(memory_file, 'r') as f:
            memory = json.load(f)
    else:
        memory = {
            "latitude": latitude,
            "longitude": longitude,
            "messages": []
        }
    memory['messages'].append({
        "timestamp": datetime.utcnow().isoformat() + 'Z',
        "event_id": event_id,
        "pubkey": pubkey,
        "content": content
    })
    memory['messages'] = memory['messages'][-50:]
    with open(memory_file, 'w') as f:
        json.dump(memory, f, indent=2)

    # --- Multi-user, multi-slot memory ---
    if user_id:
        USER_DIR = os.path.expanduser(f"~/.zen/tmp/flashmem/{user_id}")
        os.makedirs(USER_DIR, exist_ok=True)
        slot_file = os.path.join(USER_DIR, f"slot{slot}.json")
        if os.path.isfile(slot_file):
            with open(slot_file, 'r') as f:
                slot_mem = json.load(f)
        else:
            slot_mem = {
                "user_id": user_id,
                "slot": slot,
                "messages": []
            }
        slot_mem['messages'].append({
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "event_id": event_id,
            "latitude": latitude,
            "longitude": longitude,
            "content": content
        })
        slot_mem['messages'] = slot_mem['messages'][-50:]
        with open(slot_file, 'w') as f:
            json.dump(slot_mem, f, indent=2)
        print(f"Memory updated for user: {user_id}, slot: {slot}")
    else:
        print("No user_id provided, slot memory not updated.")

    print(f"Memory updated for coordinates: {latitude}, {longitude}")
    print(f"Memory updated for pubkey: {pubkey}")

if __name__ == "__main__":
    main()
