#!/usr/bin/env python3
import os
import sys

# Activer l'environnement virtuel ~/.astro pour accéder au module ollama
venv_path = os.path.expanduser("~/.astro")
if os.path.exists(venv_path):
    python_version = f"python{sys.version_info.major}.{sys.version_info.minor}"
    site_packages = os.path.join(venv_path, "lib", python_version, "site-packages")
    if os.path.exists(site_packages):
        sys.path.insert(0, site_packages)

import hashlib
import json
import re
import subprocess
from datetime import datetime

# Check if debug mode is enabled
DEBUG_MODE = os.environ.get('DEBUG', '0') == '1'
DEBUG_MODE = '1'

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

def fix_json_control_characters(json_str):
    """Fix control characters in JSON that cause parsing errors"""
    import json
    
    try:
        # First, try to parse as-is to see if it's already valid
        json.loads(json_str)
        return json_str
    except json.JSONDecodeError:
        pass
    
    # If parsing fails, try to fix control characters
    # This is a more aggressive approach to handle malformed JSON
    try:
        # Use Python's json module to properly escape the string
        # We'll parse it as a Python dict first, then re-serialize
        import ast
        # Try to safely evaluate the JSON-like string as a Python literal
        parsed = ast.literal_eval(json_str)
        # Re-serialize with proper JSON formatting
        return json.dumps(parsed, ensure_ascii=False)
    except (ValueError, SyntaxError):
        pass
    
    # If all else fails, try manual character replacement
    # Replace common problematic control characters
    fixed = json_str
    # Replace newlines with escaped newlines
    fixed = fixed.replace('\n', '\\n')
    fixed = fixed.replace('\r', '\\r')
    fixed = fixed.replace('\t', '\\t')
    
    return fixed

def fix_json_content_newlines(json_str):
    """Specifically fix newlines in JSON content fields"""
    import json
    import re
    
    try:
        # Try to parse as-is first
        json.loads(json_str)
        return json_str
    except json.JSONDecodeError:
        pass
    
    # Look for content field and fix newlines within it
    # This regex looks for "content":"... and fixes newlines in the content
    pattern = r'("content"\s*:\s*")([^"]*(?:\\.[^"]*)*)(")'
    
    def fix_content_newlines(match):
        prefix = match.group(1)
        content = match.group(2)
        suffix = match.group(3)
        
        # Replace newlines with escaped newlines in content
        fixed_content = content.replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
        
        return prefix + fixed_content + suffix
    
    fixed_json = re.sub(pattern, fix_content_newlines, json_str)
    
    return fixed_json

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
        
        # Try to fix control characters
        try:
            control_fixed_json = fix_json_control_characters(cleaned_json)
            debug_print(f"DEBUG: Attempting to parse control-character-fixed JSON")
            return json.loads(control_fixed_json)
        except json.JSONDecodeError as e3:
            debug_print(f"DEBUG: Control character fix also failed: {e3}")
        
        # Try to fix content newlines specifically
        try:
            newline_fixed_json = fix_json_content_newlines(cleaned_json)
            debug_print(f"DEBUG: Attempting to parse newline-fixed JSON")
            return json.loads(newline_fixed_json)
        except json.JSONDecodeError as e4:
            debug_print(f"DEBUG: Newline fix also failed: {e4}")
        
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

def _upsert_to_qdrant(user_id, content, timestamp, slot):
    """Génère un embedding via Ollama et l'upserte dans Qdrant (collection memory_{user_hex}).
    Toutes les erreurs sont silencieuses — la fonctionnalité est optionnelle."""
    try:
        OLLAMA_URL = os.environ.get('OLLAMA_URL', 'http://127.0.0.1:11434')
        QDRANT_URL = os.environ.get('QDRANT_URL', 'http://127.0.0.1:6333')
        QDRANT_API_KEY = os.environ.get('QDRANT_API_KEY', '')

        # Dériver user_hex : lire ~/.zen/game/nostr/{user_id}/HEX (16 premiers chars)
        hex_file = os.path.expanduser(f"~/.zen/game/nostr/{user_id}/HEX")
        if os.path.isfile(hex_file):
            with open(hex_file, 'r') as f:
                user_hex = f.read().strip()[:16]
        else:
            user_hex = hashlib.md5(user_id.encode()).hexdigest()[:16]

        collection = f"memory_{user_hex}"

        # Préparer les headers d'auth Qdrant
        auth_headers = []
        if QDRANT_API_KEY:
            auth_headers = ["-H", f"api-key: {QDRANT_API_KEY}"]

        # Générer l'embedding via Ollama
        embed_payload = json.dumps({"model": "nomic-embed-text", "prompt": content})
        embed_result = subprocess.run(
            ["curl", "-sf", "-X", "POST",
             f"{OLLAMA_URL}/api/embeddings",
             "-H", "Content-Type: application/json",
             "-d", embed_payload],
            capture_output=True, text=True, timeout=15
        )
        if embed_result.returncode != 0 or not embed_result.stdout.strip():
            return  # Ollama non disponible — skip silencieux

        embed_data = json.loads(embed_result.stdout)
        vector = embed_data.get('embedding', [])
        if not vector:
            return  # Embedding vide — skip silencieux

        # Créer la collection si elle n'existe pas
        create_payload = json.dumps({"vectors": {"size": 768, "distance": "Cosine"}})
        create_cmd = ["curl", "-sf", "-X", "PUT",
                      f"{QDRANT_URL}/collections/{collection}",
                      "-H", "Content-Type: application/json",
                      "-d", create_payload]
        create_cmd.extend(auth_headers)
        subprocess.run(create_cmd, capture_output=True, timeout=15)

        # doc_id stable basé sur user_id + timestamp
        doc_id = int(hashlib.md5(f"{user_id}:{timestamp}".encode()).hexdigest()[:15], 16)

        # Upsert dans Qdrant
        upsert_payload = json.dumps({
            "points": [{
                "id": doc_id,
                "vector": vector,
                "payload": {
                    "user_id": user_id,
                    "slot": slot,
                    "content": content,
                    "timestamp": timestamp,
                    "source": "nostr_rec"
                }
            }]
        })
        upsert_cmd = ["curl", "-sf", "-X", "PUT",
                      f"{QDRANT_URL}/collections/{collection}/points",
                      "-H", "Content-Type: application/json",
                      "-d", upsert_payload]
        upsert_cmd.extend(auth_headers)
        subprocess.run(upsert_cmd, capture_output=True, timeout=15)

    except Exception:
        pass  # Skip silencieux — Qdrant/Ollama optionnel


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
    MEMORY_DIR = os.path.expanduser("~/.zen/flashmem/uplanet_memory")
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
        USER_DIR = os.path.expanduser(f"~/.zen/flashmem/{user_id}")
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
        _upsert_to_qdrant(user_id, content, slot_mem['messages'][-1]['timestamp'], slot)
    else:
        print("No user_id provided, slot memory not updated.")

    print(f"Memory updated for coordinates: {latitude}, {longitude}")
    print(f"Memory updated for pubkey: {pubkey}")

if __name__ == "__main__":
    main()
