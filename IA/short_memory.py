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

import fcntl
import hashlib
import json
import re
import subprocess
from datetime import datetime

# Importer le gestionnaire Qdrant unifié (même répertoire)
_MEMORY_MGR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory_manager.py")
_HAS_MEMORY_MGR = os.path.isfile(_MEMORY_MGR)

# Check if debug mode is enabled
DEBUG_MODE = os.environ.get('DEBUG', '0') == '1'

def debug_print(*args, **kwargs):
    """Print debug messages only if DEBUG mode is enabled"""
    if DEBUG_MODE:
        print(*args, **kwargs)

def strip_think_tags(s):
    """Remove <think>...</think> reasoning blocks emitted by DeepSeek/Gemma3 before JSON parsing."""
    return re.sub(r'<think>.*?</think>', '', s, flags=re.DOTALL).strip()

def clean_json_string(json_str):
    """Strip shell wrapping quotes and reasoning tags — no regex mangling of JSON content."""
    json_str = json_str.strip()
    # Strip <think>...</think> blocks from reasoning models (DeepSeek, Gemma3…)
    json_str = strip_think_tags(json_str)
    # Remove shell single-quote wrapping (bash: echo '...')
    if json_str.startswith("'") and json_str.endswith("'"):
        json_str = json_str[1:-1]
    # Remove outer double-quote wrapping only if the result is valid JSON
    if json_str.startswith('"') and json_str.endswith('"'):
        try:
            inner = json_str[1:-1]
            json.loads(inner)
            json_str = inner
        except (json.JSONDecodeError, ValueError):
            pass
    return json_str


def fix_common_json_issues(json_str):
    """Fix structural JSON issues — applied only after json.loads() has failed."""
    # Fix missing commas between adjacent objects in arrays
    json_str = re.sub(r'}\s*{', '},{', json_str)
    # Fix missing quotes around bare property names
    json_str = re.sub(r'([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:', r'\1"\2":', json_str)
    # Fix trailing commas before closing brackets
    json_str = re.sub(r',(\s*[}\]])', r'\1', json_str)
    # NOTE: single-quote → double-quote substitution intentionally removed:
    # it mangles content containing apostrophes (e.g. "l'utilisateur").
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

def _upsert_to_qdrant(user_id, content, timestamp, slot):
    """Délègue à memory_manager.py — gère slot + geo séparément, RÊVE inclus."""
    if not _HAS_MEMORY_MGR:
        return
    try:
        subprocess.run(
            [sys.executable, _MEMORY_MGR, "upsert-slot",
             "--user-id", user_id, "--slot", str(slot), "--content", content],
            capture_output=True, timeout=20
        )
    except Exception:
        pass


def _upsert_geo_to_qdrant(lat, lon, content, pubkey, timestamp, event_id=""):
    """Upsert la mémoire géo dans la collection uplanet_geo (séparée des slots)."""
    if not _HAS_MEMORY_MGR:
        return
    try:
        subprocess.run(
            [sys.executable, _MEMORY_MGR, "upsert-geo",
             "--lat", lat, "--lon", lon, "--content", content,
             "--pubkey", pubkey, "--event-id", event_id],
            capture_output=True, timeout=20
        )
    except Exception:
        pass


def _maybe_reve(user_id, slot, slot_file):
    """Déclenche le cycle RÊVE si le slot est plein (>= seuil dans memory_manager)."""
    if not _HAS_MEMORY_MGR:
        return
    try:
        subprocess.run(
            [sys.executable, _MEMORY_MGR, "reve",
             "--user-id", user_id, "--slot", str(slot)],
            capture_output=True, timeout=60
        )
    except Exception:
        pass


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
    with open(memory_file, 'a+') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        raw = f.read().strip()
        memory = json.loads(raw) if raw else {
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
        # Fenêtre glissante géo : 200 entrées (RÊVE prend le relais via Qdrant pour les anciennes)
        memory['messages'] = memory['messages'][-200:]
        f.seek(0)
        f.truncate()
        json.dump(memory, f, indent=2)

    # --- Multi-user, multi-slot memory ---
    if user_id:
        USER_DIR = os.path.expanduser(f"~/.zen/flashmem/{user_id}")
        os.makedirs(USER_DIR, exist_ok=True)
        slot_file = os.path.join(USER_DIR, f"slot{slot}.json")
        with open(slot_file, 'a+') as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            f.seek(0)
            raw = f.read().strip()
            slot_mem = json.loads(raw) if raw else {
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
            # Fenêtre glissante slot : 200 entrées — RÊVE compresse à 150 et garde 80 récentes
            slot_mem['messages'] = slot_mem['messages'][-200:]
            f.seek(0)
            f.truncate()
            json.dump(slot_mem, f, indent=2)
        ts_slot = slot_mem['messages'][-1]['timestamp']
        print(f"Memory updated for user: {user_id}, slot: {slot}")
        # Qdrant : slot personnel + geo séparés
        _upsert_to_qdrant(user_id, content, ts_slot, slot)
        _upsert_geo_to_qdrant(latitude, longitude, content, pubkey, ts_slot, event_id)
        # RÊVE : comprimer à partir de 170 entrées (REVE_THRESHOLD=150 dans memory_manager)
        if len(slot_mem['messages']) >= 170:
            _maybe_reve(user_id, slot, slot_file)
    else:
        # Pas d'user_id : géo seule dans uplanet_geo
        _upsert_geo_to_qdrant(latitude, longitude, content, pubkey,
                              datetime.utcnow().isoformat() + 'Z', event_id)
        print("No user_id provided, slot memory not updated.")

    print(f"Memory updated for coordinates: {latitude}, {longitude}")
    print(f"Memory updated for pubkey: {pubkey}")

if __name__ == "__main__":
    main()
