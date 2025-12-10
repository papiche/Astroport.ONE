#!/usr/bin/env python3
"""
UPlanet Inventory Recognition System
Multi-type classification: plants, insects, animals, persons, objects, places
Generates identification and maintenance contracts for commons management
"""

import sys
import os
import json
import time
import argparse
import subprocess

# Activate ~/.astro virtual environment to access ollama module
venv_path = os.path.expanduser("~/.astro")
if os.path.exists(venv_path):
    python_version = f"python{sys.version_info.major}.{sys.version_info.minor}"
    site_packages = os.path.join(venv_path, "lib", python_version, "site-packages")
    if os.path.exists(site_packages):
        sys.path.insert(0, site_packages)

import ollama
import requests

# Detect home directory dynamically
HOME_DIR = os.path.expanduser("~")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Type definitions with icons and categories
INVENTORY_TYPES = {
    'plant': {
        'icon': '🌱',
        'name_fr': 'Plante',
        'name_en': 'Plant',
        'categories': ['tree', 'flower', 'shrub', 'grass', 'vegetable', 'fruit', 'herb', 'moss', 'fern'],
        'use_plantnet': True
    },
    'insect': {
        'icon': '🐛',
        'name_fr': 'Insecte',
        'name_en': 'Insect',
        'categories': ['bee', 'butterfly', 'beetle', 'ant', 'fly', 'mosquito', 'dragonfly', 'grasshopper', 'spider', 'worm']
    },
    'animal': {
        'icon': '🦊',
        'name_fr': 'Animal',
        'name_en': 'Animal',
        'categories': ['mammal', 'bird', 'reptile', 'amphibian', 'fish', 'wild', 'domestic', 'farm']
    },
    'person': {
        'icon': '👤',
        'name_fr': 'Personne',
        'name_en': 'Person',
        'categories': ['adult', 'child', 'group', 'worker', 'artist', 'farmer', 'craftsman']
    },
    'object': {
        'icon': '🔧',
        'name_fr': 'Objet',
        'name_en': 'Object',
        'categories': ['tool', 'furniture', 'vehicle', 'equipment', 'artwork', 'container', 'electronic', 'machine', 'building_material']
    },
    'place': {
        'icon': '🏠',
        'name_fr': 'Lieu',
        'name_en': 'Place',
        'categories': ['building', 'garden', 'field', 'forest', 'water', 'road', 'landmark', 'infrastructure']
    }
}

def log_message(message):
    """Log message to UPlanet log file"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] INVENTORY: {message}\n"
    
    log_dir = f'{HOME_DIR}/.zen/tmp'
    os.makedirs(log_dir, exist_ok=True)
    
    log_file = f'{HOME_DIR}/.zen/tmp/inventory.log'
    with open(log_file, 'a') as f:
        f.write(log_entry)
    
    print(log_entry.strip(), file=sys.stderr)

def ensure_ollama_connection():
    """Ensure Ollama connection is available"""
    import socket
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        result = sock.connect_ex(('127.0.0.1', 11434))
        sock.close()
        if result == 0:
            return True
    except:
        pass
    
    # Try to establish connection via ollama.me.sh
    ollama_script = os.path.join(SCRIPT_DIR, "ollama.me.sh")
    if os.path.exists(ollama_script):
        try:
            subprocess.run([ollama_script], capture_output=True, timeout=10)
            return True
        except:
            pass
    return False

def download_image(image_url):
    """Download image from URL"""
    try:
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()
        
        if len(response.content) > 10 * 1024 * 1024:
            log_message("Image too large (max 10MB)")
            return None
            
        log_message(f"Image downloaded: {len(response.content)} bytes")
        return response.content
        
    except Exception as e:
        log_message(f"Error downloading image: {e}")
        return None

def classify_image_type(image_path, force_type=None):
    """
    Classify image into one of the inventory types using AI vision
    
    Args:
        image_path: Path to the image file
        force_type: If specified, skip classification and use this type
    
    Returns:
        dict with 'type', 'category', 'confidence', 'description'
    """
    if force_type and force_type in INVENTORY_TYPES:
        log_message(f"Using forced type: {force_type}")
        return {
            'type': force_type,
            'category': None,
            'confidence': 1.0,
            'description': f"Type specified by user: {force_type}"
        }
    
    ensure_ollama_connection()
    
    classification_prompt = """Analyze this image and classify it into ONE of these categories:
- plant (any vegetation: tree, flower, grass, vegetable, fruit, herb, moss, fern)
- insect (bee, butterfly, beetle, ant, spider, worm, etc.)
- animal (mammal, bird, reptile, amphibian, fish)
- person (human being, adult, child, group of people)
- object (tool, furniture, vehicle, equipment, machine, container)
- place (building, garden, field, landscape, infrastructure)

Respond in JSON format ONLY:
{
    "type": "plant|insect|animal|person|object|place",
    "category": "specific subcategory",
    "confidence": 0.0-1.0,
    "description": "brief description in French"
}

IMPORTANT: Return ONLY valid JSON, no other text."""

    try:
        log_message("Classifying image type with AI...")
        response = ollama.chat(
            model="minicpm-v",
            messages=[{
                'role': 'user',
                'content': classification_prompt,
                'images': [image_path]
            }]
        )
        
        result_text = response['message']['content']
        log_message(f"Classification response: {result_text[:200]}")
        
        # Extract JSON from response
        try:
            # Try to find JSON in the response
            if '{' in result_text and '}' in result_text:
                json_start = result_text.find('{')
                json_end = result_text.rfind('}') + 1
                json_str = result_text[json_start:json_end]
                result = json.loads(json_str)
                
                # Validate type
                if result.get('type') not in INVENTORY_TYPES:
                    result['type'] = 'object'  # Default fallback
                
                return result
        except json.JSONDecodeError as e:
            log_message(f"JSON parse error: {e}")
        
        # Fallback: try to detect type from text
        result_lower = result_text.lower()
        for type_key in INVENTORY_TYPES:
            if type_key in result_lower:
                return {
                    'type': type_key,
                    'category': None,
                    'confidence': 0.5,
                    'description': result_text[:200]
                }
        
        # Default to object
        return {
            'type': 'object',
            'category': 'unknown',
            'confidence': 0.3,
            'description': result_text[:200]
        }
        
    except Exception as e:
        log_message(f"Classification error: {e}")
        return {
            'type': 'object',
            'category': 'unknown',
            'confidence': 0.0,
            'description': f"Classification failed: {str(e)}"
        }

def identify_item(image_path, item_type, classification):
    """
    Identify the specific item based on its type
    
    Args:
        image_path: Path to the image
        item_type: The classified type
        classification: Classification result dict
    
    Returns:
        dict with identification details
    """
    type_info = INVENTORY_TYPES.get(item_type, INVENTORY_TYPES['object'])
    
    # For plants, try PlantNet first
    if item_type == 'plant' and type_info.get('use_plantnet'):
        log_message("Attempting PlantNet identification for plant...")
        # PlantNet will be called separately by the caller if needed
        return {
            'use_plantnet': True,
            'type': item_type,
            'type_info': type_info
        }
    
    # For other types, use AI vision
    identify_prompt = f"""Identify this {type_info['name_en']} in the image.

Provide detailed identification in JSON format:
{{
    "name": "common name in French",
    "scientific_name": "scientific/technical name if applicable",
    "category": "subcategory from: {', '.join(type_info['categories'])}",
    "description": "detailed description in French (2-3 sentences)",
    "characteristics": ["key feature 1", "key feature 2", "key feature 3"],
    "condition": "excellent|good|fair|poor|unknown",
    "estimated_age": "if estimable",
    "notable_features": "any special or notable aspects"
}}

IMPORTANT: Return ONLY valid JSON."""

    try:
        log_message(f"Identifying {item_type} with AI...")
        response = ollama.chat(
            model="minicpm-v",
            messages=[{
                'role': 'user',
                'content': identify_prompt,
                'images': [image_path]
            }]
        )
        
        result_text = response['message']['content']
        log_message(f"Identification response: {result_text[:300]}")
        
        # Extract JSON
        if '{' in result_text and '}' in result_text:
            json_start = result_text.find('{')
            json_end = result_text.rfind('}') + 1
            json_str = result_text[json_start:json_end]
            result = json.loads(json_str)
            result['type'] = item_type
            result['type_info'] = type_info
            return result
        
        return {
            'type': item_type,
            'type_info': type_info,
            'name': 'Non identifié',
            'description': result_text[:300],
            'raw_response': result_text
        }
        
    except Exception as e:
        log_message(f"Identification error: {e}")
        return {
            'type': item_type,
            'type_info': type_info,
            'name': 'Erreur d\'identification',
            'error': str(e)
        }

def generate_maintenance_contract(identification, item_type, latitude, longitude):
    """
    Generate a maintenance/management contract for the identified item
    
    Args:
        identification: Identification result dict
        item_type: The item type
        latitude, longitude: Location coordinates
    
    Returns:
        dict with contract details in Markdown format
    """
    type_info = INVENTORY_TYPES.get(item_type, INVENTORY_TYPES['object'])
    item_name = identification.get('name', 'Élément non identifié')
    description = identification.get('description', '')
    category = identification.get('category', '')
    
    contract_prompt = f"""Génère un contrat de maintenance/gestion pour cet élément inventorié sur UPlanet :

**Type**: {type_info['name_fr']} ({type_info['icon']})
**Nom**: {item_name}
**Catégorie**: {category}
**Description**: {description}
**Localisation**: {latitude}, {longitude}

Crée un contrat structuré en Markdown avec les sections suivantes :

# {type_info['icon']} Contrat de gestion : {item_name}

## 📋 Description
(Description détaillée de l'élément)

## 🔧 Maintenance requise
(Liste des tâches de maintenance régulière avec fréquence)

## 🛠️ Réparation / Entretien
(Étapes pour réparer ou entretenir l'élément)

## 👥 Responsabilités
(Qui peut/doit s'en occuper)

## 💰 Estimation Ẑen
(Coût estimé en Ẑen pour chaque type d'intervention)

## ⚠️ Précautions
(Précautions à prendre, risques potentiels)

## 📅 Calendrier
(Calendrier d'entretien recommandé)

IMPORTANT: Génère un contrat réaliste et utile, adapté au type d'élément."""

    try:
        log_message("Generating maintenance contract with AI...")
        response = ollama.chat(
            model="gemma3:latest",
            messages=[
                {
                    'role': 'system',
                    'content': 'Tu es un expert en gestion des communs et maintenance. Génère des contrats de gestion clairs et pratiques en Markdown.'
                },
                {
                    'role': 'user',
                    'content': contract_prompt
                }
            ]
        )
        
        contract_content = response['message']['content']
        
        # Filter <think> tags if present
        while "<think>" in contract_content and "</think>" in contract_content:
            start = contract_content.find("<think>")
            end = contract_content.find("</think>") + len("</think>")
            contract_content = contract_content[:start] + contract_content[end:]
        
        log_message(f"Contract generated: {len(contract_content)} chars")
        
        return {
            'title': f"{type_info['icon']} Contrat: {item_name}",
            'content': contract_content.strip(),
            'item_name': item_name,
            'item_type': item_type,
            'category': category,
            'location': {'latitude': latitude, 'longitude': longitude},
            'generated_at': time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            'tags': ['contract', 'maintenance', item_type, 'UPlanet', 'communs']
        }
        
    except Exception as e:
        log_message(f"Contract generation error: {e}")
        return {
            'title': f"{type_info['icon']} Contrat: {item_name}",
            'content': f"# {type_info['icon']} Contrat de gestion : {item_name}\n\n⚠️ Erreur lors de la génération du contrat.\n\nVeuillez créer manuellement un contrat pour cet élément.",
            'error': str(e)
        }

def format_inventory_response(classification, identification, contract, image_url, latitude, longitude):
    """
    Format the complete inventory response
    
    Returns:
        dict with formatted response for Nostr publication
    """
    type_info = INVENTORY_TYPES.get(classification['type'], INVENTORY_TYPES['object'])
    item_name = identification.get('name', 'Non identifié')
    confidence = classification.get('confidence', 0)
    confidence_pct = int(confidence * 100)
    
    # Confidence indicator
    if confidence_pct >= 70:
        confidence_emoji = "🟢"
        confidence_text = "Très fiable"
    elif confidence_pct >= 50:
        confidence_emoji = "🟡"
        confidence_text = "Fiable"
    elif confidence_pct >= 30:
        confidence_emoji = "🟠"
        confidence_text = "Possible"
    else:
        confidence_emoji = "🔴"
        confidence_text = "Incertain"
    
    # Build response content
    content = f"""🔍 **Inventaire UPlanet**

{type_info['icon']} **Type**: {type_info['name_fr']}
🏷️ **Identification**: {item_name}
📁 **Catégorie**: {identification.get('category', 'Non spécifiée')}

{confidence_emoji} **Confiance**: {confidence_pct}% ({confidence_text})

📝 **Description**:
{identification.get('description', 'Aucune description disponible')}

📍 **Localisation**: {latitude}, {longitude}

━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 **Contrat de gestion disponible**
👍 Likez pour créditer des Ẑen et soutenir la gestion de ce commun !

#UPlanet #inventory #{classification['type']}"""

    return {
        'success': True,
        'content': content,
        'classification': classification,
        'identification': identification,
        'contract': contract,
        'type': classification['type'],
        'type_info': type_info,
        'location': {'latitude': latitude, 'longitude': longitude},
        'image_url': image_url,
        'timestamp': time.time(),
        'tags': [
            'UPlanet',
            'inventory',
            classification['type'],
            identification.get('category', 'unknown')
        ]
    }

def main():
    parser = argparse.ArgumentParser(description="UPlanet Inventory Recognition System")
    parser.add_argument("image_url", help="URL of the image to analyze")
    parser.add_argument("latitude", type=float, help="GPS latitude")
    parser.add_argument("longitude", type=float, help="GPS longitude")
    parser.add_argument("--type", dest="force_type", choices=list(INVENTORY_TYPES.keys()),
                        help="Force a specific type instead of auto-classification")
    parser.add_argument("--json", action="store_true", help="Output in JSON format")
    parser.add_argument("--contract", action="store_true", help="Generate maintenance contract")
    parser.add_argument("--pubkey", help="Observer's public key")
    parser.add_argument("--event-id", help="Original event ID")
    
    args = parser.parse_args()
    
    log_message(f"Starting inventory recognition: {args.image_url}")
    log_message(f"Location: {args.latitude}, {args.longitude}")
    log_message(f"Force type: {args.force_type}")
    
    # Download image
    image_data = download_image(args.image_url)
    if not image_data:
        error_result = {
            'success': False,
            'error': 'image_download_failed',
            'message': 'Impossible de télécharger l\'image'
        }
        if args.json:
            print(json.dumps(error_result, ensure_ascii=False, indent=2))
        else:
            print(f"❌ {error_result['message']}")
        sys.exit(1)
    
    # Save to temp file for Ollama
    import tempfile
    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
        tmp.write(image_data)
        temp_image_path = tmp.name
    
    try:
        # Step 1: Classify image type
        classification = classify_image_type(temp_image_path, args.force_type)
        log_message(f"Classification: {classification}")
        
        # Step 2: Check if we should use PlantNet for plants
        if classification['type'] == 'plant':
            # Call PlantNet for plant identification
            log_message("Delegating to PlantNet for plant identification...")
            plantnet_script = os.path.join(SCRIPT_DIR, "plantnet_recognition.py")
            
            if os.path.exists(plantnet_script):
                try:
                    result = subprocess.run([
                        sys.executable, plantnet_script,
                        args.image_url,
                        str(args.latitude),
                        str(args.longitude),
                        args.pubkey or "unknown",
                        args.event_id or "unknown",
                        args.pubkey or "unknown",
                        "--json"
                    ], capture_output=True, text=True, timeout=60)
                    
                    if result.returncode == 0 and result.stdout:
                        plantnet_result = json.loads(result.stdout)
                        
                        if plantnet_result.get('success'):
                            # Use PlantNet result
                            identification = {
                                'name': plantnet_result['best_match']['scientific_name'],
                                'common_names': plantnet_result['best_match'].get('common_names', []),
                                'category': 'plant',
                                'description': f"Plante identifiée par PlantNet avec {plantnet_result['best_match']['confidence_pct']}% de confiance",
                                'confidence': plantnet_result['best_match']['confidence'],
                                'source': 'PlantNet',
                                'wikipedia_url': plantnet_result['best_match'].get('wikipedia_url')
                            }
                            classification['confidence'] = plantnet_result['best_match']['confidence']
                        else:
                            # PlantNet failed, use AI fallback
                            identification = identify_item(temp_image_path, 'plant', classification)
                    else:
                        identification = identify_item(temp_image_path, 'plant', classification)
                except Exception as e:
                    log_message(f"PlantNet call failed: {e}")
                    identification = identify_item(temp_image_path, 'plant', classification)
            else:
                identification = identify_item(temp_image_path, 'plant', classification)
        else:
            # Step 2b: Identify non-plant items with AI
            identification = identify_item(temp_image_path, classification['type'], classification)
        
        log_message(f"Identification: {identification}")
        
        # Step 3: Generate maintenance contract if requested
        contract = None
        if args.contract:
            contract = generate_maintenance_contract(
                identification,
                classification['type'],
                args.latitude,
                args.longitude
            )
            log_message(f"Contract generated: {contract.get('title', 'Unknown')}")
        
        # Step 4: Format response
        response = format_inventory_response(
            classification,
            identification,
            contract,
            args.image_url,
            args.latitude,
            args.longitude
        )
        
        if args.json:
            print(json.dumps(response, ensure_ascii=False, indent=2))
        else:
            print(response['content'])
            if contract:
                print("\n" + "="*50)
                print("📄 CONTRAT DE GESTION")
                print("="*50)
                print(contract['content'])
        
    finally:
        # Cleanup temp file
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_message(f"Unhandled exception: {e}")
        print(json.dumps({
            'success': False,
            'error': 'unhandled_exception',
            'message': str(e)
        }, ensure_ascii=False))
        sys.exit(1)

