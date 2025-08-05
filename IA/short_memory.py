#!/usr/bin/env python3
import os
import sys
import json
import re
from datetime import datetime

# Check if debug mode is enabled
DEBUG_MODE = os.environ.get('DEBUG', '0') == '1'
DEBUG_MODE = 1 ## TODO Remove

def debug_print(*args, **kwargs):
    """Print debug messages only if DEBUG mode is enabled"""
    if DEBUG_MODE:
        print(*args, **kwargs)

def clean_json_string(json_str):
    """Clean JSON string from common shell escaping issues"""
    # Remove any leading/trailing whitespace
    json_str = json_str.strip()
    
    # Handle common shell escaping issues
    # Replace escaped quotes that might be double-escaped
    json_str = re.sub(r'\\+"', '"', json_str)
    
    # Handle single quotes around the entire JSON
    if json_str.startswith("'") and json_str.endswith("'"):
        json_str = json_str[1:-1]
    
    # Handle double quotes around the entire JSON
    if json_str.startswith('"') and json_str.endswith('"'):
        json_str = json_str[1:-1]
    
    return json_str

def fix_common_json_issues(json_str):
    """Fix common JSON formatting issues"""
    # Fix missing commas between objects in arrays
    json_str = re.sub(r'}\s*{', '},{', json_str)
    
    # Fix missing quotes around property names
    json_str = re.sub(r'([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:', r'\1"\2":', json_str)
    
    # Fix single quotes to double quotes
    json_str = re.sub(r"'([^']*)'", r'"\1"', json_str)
    
    # Fix trailing commas
    json_str = re.sub(r',(\s*[}\]])', r'\1', json_str)
    
    return json_str

def parse_event_json(json_input):
    """Parse event JSON from string or file path"""
    debug_print(f"DEBUG: Attempting to parse JSON input (length: {len(json_input)})")
    debug_print(f"DEBUG: Input starts with: {repr(json_input[:50])}")
    debug_print(f"DEBUG: Input ends with: {repr(json_input[-50:])}")
    
    # First try to parse as direct JSON string
    try:
        cleaned_json = clean_json_string(json_input)
        debug_print(f"DEBUG: Cleaned JSON length: {len(cleaned_json)}")
        debug_print(f"DEBUG: Cleaned JSON starts with: {repr(cleaned_json[:50])}")
        return json.loads(cleaned_json)
    except json.JSONDecodeError as e:
        debug_print(f"DEBUG: Direct JSON parsing failed: {e}")
        
        # Try to fix common JSON issues
        try:
            fixed_json = fix_common_json_issues(cleaned_json)
            debug_print(f"DEBUG: Attempting to parse fixed JSON")
            return json.loads(fixed_json)
        except json.JSONDecodeError as e2:
            debug_print(f"DEBUG: Fixed JSON parsing also failed: {e2}")
        
        # If that fails, try to read from file
        if os.path.isfile(json_input):
            debug_print(f"DEBUG: Trying to read from file: {json_input}")
            try:
                with open(json_input, 'r', encoding='utf-8') as f:
                    file_content = f.read()
                    debug_print(f"DEBUG: File content length: {len(file_content)}")
                    return json.loads(file_content)
            except (json.JSONDecodeError, IOError) as e:
                raise Exception(f"Failed to parse JSON from file {json_input}: {e}")
        else:
            raise Exception(f"Input is neither valid JSON nor a file path: {json_input}")

# Paramètres attendus : event_json, latitude, longitude, slot, user_id
def main():
    if len(sys.argv) < 4:
        print("Usage: short_memory.py '<event_json>' <latitude> <longitude> [slot] [user_id]")
        print("       short_memory.py <json_file_path> <latitude> <longitude> [slot] [user_id]")
        sys.exit(1)

    # Clean and parse JSON with better error handling
    try:
        event_json = parse_event_json(sys.argv[1])
    except json.JSONDecodeError as e:
        print(f"JSON parsing error: {e}")
        print(f"Error at line {e.lineno}, column {e.colno}")
        print(f"Character position: {e.pos}")
        print(f"Input length: {len(sys.argv[1])}")
        print(f"Input preview: {sys.argv[1][:100]}...")
        if e.pos < len(sys.argv[1]):
            print(f"Input around error: {sys.argv[1][max(0, e.pos-50):e.pos+50]}")
        sys.exit(1)
    except Exception as e:
        print(f"Error parsing event JSON: {e}")
        sys.exit(1)

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
