#!/usr/bin/env python3
"""
PlantNet Recognition Script for UPlanet Nostr Relay
Processes plant recognition requests and sends responses via Nostr
"""

import sys
import os
import json
import requests
import base64
import time
from urllib.parse import urlparse
import subprocess
from dotenv import load_dotenv

# Add Astroport.ONE tools to path
sys.path.append('/home/fred/.zen/Astroport.ONE/tools')

# Load environment variables
load_dotenv('/home/fred/.zen/Astroport.ONE/.env')

def log_message(message):
    """Log message to UPlanet log file"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] PLANTNET: {message}\n"
    
    # Ensure log directory exists
    os.makedirs('/home/fred/.zen/tmp', exist_ok=True)
    
    with open('/home/fred/.zen/tmp/plantnet.log', 'a') as f:
        f.write(log_entry)
    
    print(log_entry.strip())

def download_image(image_url):
    """Download image from URL"""
    try:
        # Properly handle URLs with spaces and special characters
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()
        
        # Validate image size (max 10MB)
        if len(response.content) > 10 * 1024 * 1024:
            log_message("Image too large (max 10MB)")
            return None
            
        # Validate content type
        content_type = response.headers.get('content-type', '').lower()
        if not any(img_type in content_type for img_type in ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']):
            log_message(f"Invalid image type: {content_type}")
            return None
            
        log_message(f"Image downloaded successfully: {len(response.content)} bytes, type: {content_type}")
        return response.content
        
    except requests.exceptions.RequestException as e:
        log_message(f"Network error downloading image: {e}")
        return None
    except Exception as e:
        log_message(f"Unexpected error downloading image: {e}")
        return None

def call_plantnet_api(image_data):
    """Call PlantNet API for plant recognition"""
    try:
        # Get API key from environment
        api_key = os.getenv('PLANTNET_API_KEY')
        if not api_key:
            log_message("PLANTNET_API_KEY not found in environment variables")
            return None
        
        # Validate API key format (should be a string)
        if not isinstance(api_key, str) or len(api_key) < 10:
            log_message(f"Invalid PLANTNET_API_KEY format: {api_key}")
            return None
        
        log_message("Calling PlantNet API...")
        
        # PlantNet API endpoint
        api_url = "https://my-api.plantnet.org/v2/identify"
        
        # Prepare the request - use a safe filename without spaces or special characters
        files = {
            'images': ('plant_image.jpg', image_data, 'image/jpeg')
        }
        
        data = {
            'api-key': api_key,
            'modifiers': ['crops_fast', 'similar_images', 'plant_details', 'plant_net_id'],
            'plant-language': 'fr',
            'plant-details': 'common_names,url,description,image,gbif_id,inaturalist_id,plant_net_id,synonyms,edible_parts,watering',
            'plant-details-fields': 'common_names,url,description,image,gbif_id,inaturalist_id,plant_net_id,synonyms,edible_parts,watering'
        }
        
        # Make the API request
        response = requests.post(api_url, files=files, data=data, timeout=30)
        
        # Log response details for debugging
        log_message(f"PlantNet API response status: {response.status_code}")
        log_message(f"PlantNet API response headers: {dict(response.headers)}")
        
        if response.status_code != 200:
            log_message(f"PlantNet API HTTP error: {response.status_code}")
            try:
                error_content = response.json()
                log_message(f"PlantNet API error content: {error_content}")
            except:
                log_message(f"PlantNet API error text: {response.text}")
            return None
        
        response.raise_for_status()
        
        # Parse the response
        api_response = response.json()
        log_message(f"PlantNet API response received: {len(api_response.get('results', []))} results")
        
        # Check for API errors
        if 'error' in api_response:
            log_message(f"PlantNet API error: {api_response['error']}")
            return None
        
        # Transform the response to match our expected format
        if 'results' in api_response and api_response['results']:
            transformed_results = []
            for result in api_response['results']:
                if 'score' in result and 'species' in result:
                    transformed_result = {
                        'score': result['score'],
                        'species': {
                            'scientificNameWithoutAuthor': result['species'].get('scientificNameWithoutAuthor', 'Unknown'),
                            'commonNames': result['species'].get('commonNames', [])
                        }
                    }
                    transformed_results.append(transformed_result)
            
            return {'results': transformed_results}
        else:
            log_message("No results found in PlantNet API response")
            return {'results': []}
        
    except requests.exceptions.RequestException as e:
        log_message(f"PlantNet API request failed: {e}")
        return None
    except Exception as e:
        log_message(f"Error calling PlantNet API: {e}")
        return None

def format_plantnet_result(plant_info, latitude, longitude):
    """Format PlantNet result for display"""
    try:
        if plant_info and plant_info.get('results'):
            best_match = plant_info['results'][0]
            confidence = int(best_match['score'] * 100)
            scientific_name = best_match['species']['scientificNameWithoutAuthor']
            common_names = best_match['species'].get('commonNames', [])
            
            common_name_str = ""
            if common_names:
                common_name_str = f" ({', '.join(common_names[:2])})"
            
            # Determine confidence level
            if confidence >= 80:
                confidence_emoji = "🟢"
                confidence_text = "Très probable"
            elif confidence >= 60:
                confidence_emoji = "🟡"
                confidence_text = "Probable"
            else:
                confidence_emoji = "🟠"
                confidence_text = "Possible"
            
            result_content = f"""🌿 Reconnaissance de plante terminée !

📸 **Plante identifiée :** {scientific_name}{common_name_str}
{confidence_emoji} **Confiance :** {confidence}% ({confidence_text})
📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
            
            # Add additional results if available
            if len(plant_info['results']) > 1:
                result_content += "\n\n**Autres possibilités :**"
                for i, result in enumerate(plant_info['results'][1:4], 2):  # Show top 4
                    conf = int(result['score'] * 100)
                    name = result['species']['scientificNameWithoutAuthor']
                    common = result['species'].get('commonNames', [])
                    common_str = f" ({common[0]})" if common else ""
                    result_content += f"\n{i}. {name}{common_str} ({conf}%)"
            
            return result_content
        else:
            return f"""🌿 Reconnaissance de plante

❌ **Aucune correspondance trouvée**

La plante n'a pas pu être identifiée avec certitude. 

💡 **Conseils pour améliorer la reconnaissance :**
• Prenez une photo plus claire et nette
• Assurez-vous que la plante occupe la majeure partie de l'image
• Évitez les ombres et les reflets
• Photographiez les feuilles, fleurs ou fruits de près

📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
        
    except Exception as e:
        log_message(f"Error formatting PlantNet result: {e}")
        return f"❌ Erreur lors du formatage du résultat PlantNet: {e}"

def send_nostr_response(pubkey, event_id, plant_info, latitude, longitude):
    """Send PlantNet recognition response via Nostr"""
    try:
        # Load CAPTAIN credentials
        captain_email = os.environ.get('CAPTAINEMAIL', 'captain@uplanet.earth')
        captain_secret_file = f'/home/fred/.zen/game/nostr/{captain_email}/.secret.nostr'
        
        if not os.path.exists(captain_secret_file):
            log_message(f"CAPTAIN secret file not found: {captain_secret_file}")
            return False
        
        # Source the secret file
        with open(captain_secret_file, 'r') as f:
            secret_content = f.read()
        
        # Extract NSEC from secret file
        nsec = None
        for line in secret_content.split('\n'):
            if line.startswith('NSEC='):
                nsec = line.split('=', 1)[1].strip().strip('"')
                break
        
        if not nsec:
            log_message("NSEC not found in CAPTAIN secret file")
            return False
        
        # Convert NSEC to hex
        try:
            result = subprocess.run([
                '/home/fred/.zen/Astroport.ONE/tools/nostr2hex.py', nsec
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode != 0:
                log_message(f"Error converting NSEC to hex: {result.stderr}")
                return False
            
            npriv_hex = result.stdout.strip()
            
        except Exception as e:
            log_message(f"Error running nostr2hex.py: {e}")
            return False
        
        # Prepare response content
        if plant_info and plant_info.get('results'):
            best_match = plant_info['results'][0]
            confidence = int(best_match['score'] * 100)
            scientific_name = best_match['species']['scientificNameWithoutAuthor']
            common_names = best_match['species'].get('commonNames', [])
            
            common_name_str = ""
            if common_names:
                common_name_str = f" ({', '.join(common_names[:2])})"
            
            # Determine confidence level
            if confidence >= 80:
                confidence_emoji = "🟢"
                confidence_text = "Très probable"
            elif confidence >= 60:
                confidence_emoji = "🟡"
                confidence_text = "Probable"
            else:
                confidence_emoji = "🟠"
                confidence_text = "Possible"
            
            response_content = f"""🌿 Reconnaissance de plante terminée !

📸 **Plante identifiée :** {scientific_name}{common_name_str}
{confidence_emoji} **Confiance :** {confidence}% ({confidence_text})
📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
            
            # Add additional results if available
            if len(plant_info['results']) > 1:
                response_content += "\n\n**Autres possibilités :**"
                for i, result in enumerate(plant_info['results'][1:4], 2):  # Show top 4
                    conf = int(result['score'] * 100)
                    name = result['species']['scientificNameWithoutAuthor']
                    common = result['species'].get('commonNames', [])
                    common_str = f" ({common[0]})" if common else ""
                    response_content += f"\n{i}. {name}{common_str} ({conf}%)"
        else:
            response_content = f"""🌿 Reconnaissance de plante

❌ **Aucune correspondance trouvée**

La plante n'a pas pu être identifiée avec certitude. 

💡 **Conseils pour améliorer la reconnaissance :**
• Prenez une photo plus claire et nette
• Assurez-vous que la plante occupe la majeure partie de l'image
• Évitez les ombres et les reflets
• Photographiez les feuilles, fleurs ou fruits de près

📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
        
        # Send Nostr event
        try:
            result = subprocess.run([
                'nostpy-cli', 'send_event',
                '-privkey', npriv_hex,
                '-kind', '1',
                '-content', response_content,
                '-tags', json.dumps([
                    ['e', event_id],
                    ['p', pubkey],
                    ['t', 'PlantNet'],
                    ['g', f'{latitude},{longitude}']
                ]),
                '--relay', os.environ.get('myRELAY', 'ws://127.0.0.1:7777')
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                log_message(f"PlantNet response sent successfully: {result.stdout}")
                return True
            else:
                log_message(f"Error sending Nostr response: {result.stderr}")
                return False
                
        except Exception as e:
            log_message(f"Error running nostpy-cli: {e}")
            return False
            
    except Exception as e:
        log_message(f"Error in send_nostr_response: {e}")
        return False

def main():
    """Main function"""
    if len(sys.argv) < 7:
        log_message("Usage: plantnet_recognition.py <image_url> <latitude> <longitude> <user_id> <event_id> <pubkey>")
        sys.exit(1)
    
    image_url = sys.argv[1]
    latitude = float(sys.argv[2])
    longitude = float(sys.argv[3])
    user_id = sys.argv[4]
    event_id = sys.argv[5]
    pubkey = sys.argv[6]
    
    log_message(f"Starting PlantNet recognition for {user_id}")
    log_message(f"Image URL: {image_url}")
    log_message(f"Location: {latitude}, {longitude}")
    log_message(f"Event ID: {event_id}")
    
    # Download image
    log_message("Downloading image...")
    image_data = download_image(image_url)
    if not image_data:
        log_message("Failed to download image")
        # Return formatted error message instead of exiting with error
        error_result = f"""🌿 Reconnaissance de plante

❌ **Erreur de téléchargement d'image**

Impossible de télécharger l'image depuis l'URL fournie.

💡 **Causes possibles :**
• URL d'image invalide ou inaccessible
• Image corrompue ou dans un format non supporté
• Problème de connexion réseau
• Image trop grande (limite: 10MB)

📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
        print(error_result)
        sys.exit(0)
    
    log_message(f"Image downloaded successfully ({len(image_data)} bytes)")
    
    # Call PlantNet API
    log_message("Calling PlantNet API...")
    plant_info = call_plantnet_api(image_data)
    if not plant_info:
        log_message("PlantNet API call failed")
        # Instead of exiting, return a formatted error message
        error_result = f"""🌿 Reconnaissance de plante

❌ **Erreur de reconnaissance**

La reconnaissance de la plante a échoué. 

💡 **Causes possibles :**
• Image de mauvaise qualité ou corrompue
• Problème de connexion à l'API PlantNet
• Clé API PlantNet invalide ou expirée
• Image trop grande ou dans un format non supporté

📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
        print(error_result)
        # Exit with code 0 to avoid triggering error handling in UPlanet_IA_Responder.sh
        sys.exit(0)
    
    log_message(f"PlantNet API response: {json.dumps(plant_info, indent=2)}")
    
    # Format and return the result instead of sending via Nostr
    log_message("Formatting PlantNet result...")
    result = format_plantnet_result(plant_info, latitude, longitude)
    
    if result:
        log_message("PlantNet recognition completed successfully")
        print(result)  # Output the result to stdout
    else:
        log_message("Failed to format PlantNet result")
        sys.exit(1)

if __name__ == "__main__":
    main()
