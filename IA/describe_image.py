#!/usr/bin/env python3

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import os
import sys

# Activate ~/.astro virtual environment to access ollama module
venv_path = os.path.expanduser("~/.astro")
if os.path.exists(venv_path):
    # Add venv site-packages to sys.path
    python_version = f"python{sys.version_info.major}.{sys.version_info.minor}"
    site_packages = os.path.join(venv_path, "lib", python_version, "site-packages")
    if os.path.exists(site_packages):
        sys.path.insert(0, site_packages)

import requests
import ollama
import argparse
import json
import subprocess
import socket

HOME_DIR = os.path.expanduser("~")


def _ipfs_url(cid):
    """Construit une URL IPFS propre depuis le CID, sans double /ipfs/."""
    gateway = os.getenv('myLIBRA', 'https://ipfs.copylaradio.com').rstrip('/')
    # Retirer un éventuel suffixe /ipfs déjà présent dans la variable d'env
    if gateway.endswith('/ipfs'):
        gateway = gateway[:-5]
    return f"{gateway}/ipfs/{cid}"


def _deduplicate_sentences(text):
    """Supprime les phrases dupliquées consécutives ou répétées dans le texte."""
    import re
    # Découpe sur . ! ? avec préservation du séparateur
    parts = re.split(r'(?<=[.!?])\s+', text.strip())
    seen = []
    result = []
    for part in parts:
        # Normaliser pour comparaison (minuscules, sans ponctuation finale)
        key = re.sub(r'[.!?\s]+$', '', part.lower().strip())
        if key and key not in seen:
            seen.append(key)
            result.append(part)
    return ' '.join(result)


def publish_kind1(description, image_source, email=None):
    """Publie la description en kind 1 NOSTR avec l'image attachée via IPFS."""
    if not email:
        email = os.getenv('CAPTAINEMAIL', '')
    if not email:
        env_file = os.path.join(HOME_DIR, '.zen', 'Astroport.ONE', '.env')
        if os.path.exists(env_file):
            with open(env_file) as f:
                for line in f:
                    if line.startswith('CAPTAINEMAIL='):
                        email = line.split('=', 1)[1].strip().strip('"\'')
                        break
    if not email:
        print("publish: CAPTAINEMAIL introuvable — utilise --publish EMAIL")
        return None

    keyfile = os.path.join(HOME_DIR, '.zen', 'game', 'nostr', email, '.secret.nostr')
    if not os.path.exists(keyfile):
        print(f"publish: keyfile introuvable : {keyfile}")
        return None

    ipfs_url = None
    if not image_source.startswith('http://') and not image_source.startswith('https://'):
        try:
            r = subprocess.run(['ipfs', 'add', '--quiet', '--pin=false', image_source],
                               capture_output=True, text=True, timeout=30)
            cid = r.stdout.strip().split()[-1] if r.returncode == 0 else None
            if cid:
                ipfs_url = _ipfs_url(cid)
        except Exception as e:
            print(f"publish: ipfs add échoué : {e}")
    else:
        ipfs_url = image_source

    content = f"👁️ {description}"
    tags = [["t", "vision"], ["t", "ollama"]]
    if ipfs_url:
        content += f"\n\n📸 {ipfs_url}"
        tags.append(["r", ipfs_url])

    script = os.path.join(HOME_DIR, '.zen', 'Astroport.ONE', 'tools', 'nostr_send_note.py')
    if not os.path.exists(script):
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              '..', 'tools', 'nostr_send_note.py')
    relay = os.getenv('NOSTR_RELAY_WS', 'ws://127.0.0.1:7777')

    try:
        r = subprocess.run(
            [sys.executable, script,
             '--keyfile', keyfile,
             '--content', content,
             '--kind', '1',
             '--tags', json.dumps(tags),
             '--relays', relay,
             '--json'],
            capture_output=True, text=True, timeout=60
        )
        if r.returncode == 0:
            pub = json.loads(r.stdout)
            pub['_content'] = content  # contenu réel publié
            return pub
        else:
            print(f"publish: échec nostr_send_note : {r.stderr[:200]}")
            return None
    except Exception as e:
        print(f"publish: exception : {e}")
        return None

def check_ollama_port(port=11434):
    """
    Check if the Ollama port is open locally.
    """
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        result = sock.connect_ex(('127.0.0.1', port))
        sock.close()
        return result == 0
    except Exception:
        return False

def ensure_ollama_connection(output_json=False):
    """
    Ensure that Ollama connection is available by checking the port
    and calling ollama.me.sh if needed.
    """
    if check_ollama_port():
        if not output_json:
            print("Ollama port 11434 is already open.")
        return True
    
    if not output_json:
        print("Ollama port not open. Attempting to establish tunnel via ollama.me.sh...")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ollama_script = os.path.join(script_dir, "ollama.me.sh")
    
    if not os.path.exists(ollama_script):
        if not output_json:
            print(f"Warning: ollama.me.sh not found at {ollama_script}")
        return False
    
    try:
        result = subprocess.run([ollama_script], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            if not output_json:
                print("Ollama tunnel established successfully.")
            return True
        else:
            if not output_json:
                print(f"Failed to establish Ollama tunnel: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        if not output_json:
            print("Timeout while establishing Ollama tunnel.")
        return False
    except Exception as e:
        if not output_json:
            print(f"Error while calling ollama.me.sh: {e}")
        return False

def describe_image_from_ipfs(image_source, ollama_model="llama3.2-vision:11b", output_json=False, custom_prompt=None):
    """
    Describes an image using Ollama. Sends image bytes directly to avoid 
    remote filesystem path resolution issues.
    """
    if not ensure_ollama_connection(output_json):
        if not output_json:
            print("Warning: Could not establish Ollama connection. Attempting anyway...")
    
    try:
        image_bytes = None
        
        # Determine if image_source is a URL or a local file
        if image_source.startswith('http://') or image_source.startswith('https://'):
            if not output_json:
                print(f"Downloading image from IPFS URL: {image_source}")
            response = requests.get(image_source, timeout=15)
            response.raise_for_status()
            image_bytes = response.content
            if not output_json:
                print(f"Image downloaded successfully ({len(image_bytes)} bytes).")
        else:
            # Use local file path directly
            if not os.path.exists(image_source):
                if not output_json:
                    print(f"Error: Local file not found: {image_source}")
                return None
            
            with open(image_source, 'rb') as f:
                image_bytes = f.read()
            if not output_json:
                print(f"Read local image file ({len(image_bytes)} bytes).")

        prompt = custom_prompt if custom_prompt else (
            "Décris cette image en 3 à 5 phrases concises et factuelles. "
            "Identifie les éléments principaux visibles (plantes, animaux, personnes, objets, paysage, couleurs). "
            "Chaque phrase doit apporter une information nouvelle. Ne répète pas les mêmes informations."
        )

        if not output_json:
            print(f"Sending image data to remote Ollama model '{ollama_model}'...")

        def _ollama_chat():
            return ollama.chat(
                model=ollama_model,
                messages=[{'role': 'user', 'content': prompt, 'images': [image_bytes]}],
                options={'repeat_penalty': 1.4, 'num_predict': 600, 'temperature': 0.3}
            )

        # Retry once if connection is reset (tunnel may have dropped)
        try:
            ai_response = _ollama_chat()
        except Exception as e:
            if "104" in str(e) or "Connection reset" in str(e) or "Connection refused" in str(e):
                if not output_json:
                    print("Connection lost. Re-establishing tunnel via ollama.me.sh...")
                script_dir = os.path.dirname(os.path.abspath(__file__))
                ollama_script = os.path.join(script_dir, "services", "ollama.me.sh")
                if os.path.exists(ollama_script):
                    subprocess.run([ollama_script], capture_output=True, text=True, timeout=15)
                if not output_json:
                    print("Retrying...")
                ai_response = _ollama_chat()
            else:
                raise

        description = _deduplicate_sentences(ai_response['message']['content'])
        if not output_json:
            print("Ollama description received.")

        if output_json:
            result = {"description": description}
            return json.dumps(result)
        else:
            return description

    except requests.exceptions.RequestException as e:
        if output_json:
            return json.dumps({"error": f"Error downloading image: {e}"})
        print(f"Error downloading image from IPFS: {e}")
        return None
    except ConnectionError as e:
        if output_json:
            return json.dumps({"error": f"Ollama connection error: {e}"})
        print(f"Error connecting to Ollama: {e}")
        return None
    except Exception as e:
        if output_json:
            return json.dumps({"error": f"Unexpected error: {e}"})
        print(f"An unexpected error occurred: {e}")
        return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Describe an image from an IPFS URL or local file using Ollama.")
    parser.add_argument("image_source", help="Either an IPFS URL (http://...) or a local file path.")
    parser.add_argument("-m", "--model", dest="ollama_model_name", default="llama3.2-vision:11b", help="The name of the Ollama model to use (default: llama3.2-vision:11b).")
    parser.add_argument("--json", action="store_true", help="Output description in JSON format.")
    parser.add_argument("-p", "--prompt", dest="custom_prompt", default=None, help="Custom prompt to send to the AI (default: 'Décris précisément cette image...').")
    parser.add_argument("--publish", dest="publish_email", nargs="?", const="__captainemail__",
                        metavar="EMAIL",
                        help="Publier la description en kind 1 NOSTR (email du MULTIPASS, défaut: CAPTAINEMAIL)")

    args = parser.parse_args()

    description_output = describe_image_from_ipfs(args.image_source, args.ollama_model_name, args.json, args.custom_prompt)

    if description_output:
        if args.json:
            print(description_output)
        else:
            print("\nImage Description from Ollama:")
            print(description_output)

        if args.publish_email is not None:
            raw_desc = description_output
            if args.json:
                try:
                    raw_desc = json.loads(description_output).get("description", description_output)
                except Exception:
                    pass
            pub_email = None if args.publish_email == "__captainemail__" else args.publish_email
            pub = publish_kind1(raw_desc, args.image_source, pub_email)
            if pub:
                if args.json:
                    print(json.dumps(pub.get('event', pub), ensure_ascii=False))
                else:
                    print(f"\n✅ Publié kind 1 → {pub.get('event_id', '?')}")
                    print(pub.get('_content', ''))
            else:
                if args.json:
                    print(json.dumps({"publish_error": "échec publication NOSTR"}))
                else:
                    print("\n⚠️  Publication NOSTR échouée.")
    else:
        if args.json:
            print(json.dumps({"error": "Failed to get image description"}))
        else:
            print("\nFailed to get image description.")