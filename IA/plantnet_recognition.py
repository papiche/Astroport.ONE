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
from PIL import Image
import io

# Detect home directory dynamically
HOME_DIR = os.path.expanduser("~")

# Add Astroport.ONE tools to path
sys.path.append(f'{HOME_DIR}/.zen/Astroport.ONE/tools')

# Load environment variables
load_dotenv(f'{HOME_DIR}/.zen/Astroport.ONE/.env')

def log_message(message):
    """Log message to UPlanet log file"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] PLANTNET: {message}\n"
    
    # Ensure log directory exists
    log_dir = f'{HOME_DIR}/.zen/tmp'
    os.makedirs(log_dir, exist_ok=True)
    
    log_file = f'{HOME_DIR}/.zen/tmp/plantnet.log'
    with open(log_file, 'a') as f:
        f.write(log_entry)
    
    # Print to stderr instead of stdout to avoid polluting the result
    print(log_entry.strip(), file=sys.stderr)

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
        
        log_message(f"Using PlantNet API key: {api_key[:6]}...{api_key[-4:]}")
        
        # Convert image to JPEG if it's in WEBP or other unsupported format
        # PlantNet only accepts JPEG and PNG
        try:
            # Try to load the image with PIL
            img = Image.open(io.BytesIO(image_data))
            
            # Get the format
            img_format = img.format
            log_message(f"Original image format: {img_format}")
            
            # If not JPEG or PNG, convert to JPEG
            if img_format not in ['JPEG', 'PNG']:
                log_message(f"Converting {img_format} to JPEG for PlantNet compatibility...")
                
                # Convert RGBA to RGB if necessary (for PNG with transparency)
                if img.mode in ('RGBA', 'LA', 'P'):
                    # Create a white background
                    background = Image.new('RGB', img.size, (255, 255, 255))
                    if img.mode == 'P':
                        img = img.convert('RGBA')
                    background.paste(img, mask=img.split()[-1] if img.mode in ('RGBA', 'LA') else None)
                    img = background
                elif img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Save as JPEG in memory
                img_byte_arr = io.BytesIO()
                img.save(img_byte_arr, format='JPEG', quality=95)
                image_data = img_byte_arr.getvalue()
                
                log_message(f"Image converted to JPEG: {len(image_data)} bytes")
            else:
                log_message(f"Image format {img_format} is already supported by PlantNet")
                
        except Exception as e:
            log_message(f"Warning: Could not convert image format: {e}. Trying original format...")
        
        # PlantNet API endpoint - include API key in URL as per documentation
        api_url = f"https://my-api.plantnet.org/v2/identify/all?api-key={api_key}"
        
        log_message(f"Calling PlantNet API endpoint: {api_url[:60]}...")
        
        # Prepare the request - use JPEG as mime type after conversion
        files = {
            'images': ('plant_image.jpg', image_data, 'image/jpeg')
        }
        
        # Optional parameters for better results
        params = {
            'include-related-images': 'true',
            'no-reject': 'false',
            'lang': 'fr'
        }
        
        # Make the API request
        response = requests.post(api_url, files=files, params=params, timeout=30)
        
        # Log response details for debugging
        log_message(f"PlantNet API response status: {response.status_code}")
        log_message(f"PlantNet API response headers: {dict(response.headers)}")
        
        if response.status_code != 200:
            log_message(f"PlantNet API HTTP error: {response.status_code}")
            try:
                error_content = response.json()
                log_message(f"PlantNet API error content: {error_content}")
            except:
                error_text = response.text[:500]  # Limit error text length
                log_message(f"PlantNet API error text: {error_text}")
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

def format_plantnet_result(plant_info, latitude, longitude, image_url=None):
    """Format PlantNet result for display"""
    try:
        if plant_info and plant_info.get('results'):
            best_match = plant_info['results'][0]
            confidence = int(best_match['score'] * 100)
            scientific_name = best_match['species']['scientificNameWithoutAuthor']
            common_names = best_match['species'].get('commonNames', [])
            
            # Format common names
            common_name_str = ""
            if common_names:
                # Show up to 3 common names
                names_to_show = common_names[:3]
                common_name_str = f"\n🏷️  **Noms communs :** {', '.join(names_to_show)}"
            
            # Determine confidence level with more precise categories
            if confidence >= 70:
                confidence_emoji = "🟢"
                confidence_text = "Très probable"
            elif confidence >= 50:
                confidence_emoji = "🟡"
                confidence_text = "Probable"
            elif confidence >= 30:
                confidence_emoji = "🟠"
                confidence_text = "Possible"
            else:
                confidence_emoji = "🔴"
                confidence_text = "Incertain"
            
            # Generate Wikipedia link (use scientific name with spaces replaced by underscores)
            wikipedia_name = scientific_name.replace(' ', '_')
            wikipedia_url = f"https://fr.wikipedia.org/wiki/{wikipedia_name}"
            
            result_content = f"""🌿 **Reconnaissance de plante**

✅ **Identification réussie !**

🔬 **Nom scientifique :** *{scientific_name}*{common_name_str}

{confidence_emoji} **Confiance :** {confidence}% ({confidence_text})
📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

📖 **En savoir plus :** [Wikipedia]({wikipedia_url})
"""
            
            # Add additional results if available (show top 5 alternatives)
            if len(plant_info['results']) > 1:
                result_content += "\n**🔎 Autres possibilités :**\n"
                for i, result in enumerate(plant_info['results'][1:5], 2):  # Show top 5 (excluding first)
                    conf = int(result['score'] * 100)
                    name = result['species']['scientificNameWithoutAuthor']
                    common = result['species'].get('commonNames', [])
                    
                    # Format alternative entry
                    if common:
                        common_str = f" ({common[0]})"
                    else:
                        common_str = ""
                    
                    # Add confidence bar
                    bar_length = max(1, conf // 10)  # 10% = 1 bar
                    bar = "▓" * bar_length + "░" * (10 - bar_length)
                    
                    result_content += f"\n{i}. *{name}*{common_str}\n   {bar} {conf}%"
            
            result_content += """

---
🔬 **Source :** [PlantNet API](https://plantnet.org)
💡 **Astuce :** Plus la confiance est élevée, plus l'identification est fiable

#PlantNet #botanique #nature"""
            
            # Add image URL if provided
            if image_url:
                result_content += f"\n\n📸 **Image :** {image_url}"
            
            return result_content
        else:
            result_content = f"""🌿 **Reconnaissance de plante**

❌ **Aucune correspondance trouvée**

La plante n'a pas pu être identifiée avec certitude dans la base de données PlantNet.

💡 **Conseils pour améliorer la reconnaissance :**
• 📸 Prenez une photo plus claire et nette
• 🌱 Assurez-vous que la plante occupe la majeure partie de l'image
• ☀️ Évitez les ombres portées et les reflets
• 🍃 Photographiez les détails : feuilles, fleurs, fruits ou écorce
• 🔍 Prenez plusieurs angles si possible

📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

---
🔬 **Source :** [PlantNet API](https://plantnet.org)
💾 **Base de données :** Plus de 40 000 espèces référencées

#PlantNet #botanique #nature"""
            
            # Add image URL if provided
            if image_url:
                result_content += f"\n\n📸 **Image :** {image_url}"
            
            return result_content
        
    except Exception as e:
        log_message(f"Error formatting PlantNet result: {e}")
        return f"❌ Erreur lors du formatage du résultat PlantNet: {e}"

def main():
    """Main function"""
    if len(sys.argv) < 7:
        log_message("Usage: plantnet_recognition.py <image_url> <latitude> <longitude> <user_id> <event_id> <pubkey>")
        print("❌ Erreur: paramètres manquants pour la reconnaissance PlantNet")
        sys.exit(0)
    
    image_url = sys.argv[1]
    
    # Safe float conversion with error handling
    try:
        latitude = float(sys.argv[2])
        longitude = float(sys.argv[3])
    except (ValueError, IndexError) as e:
        log_message(f"Error parsing coordinates: {e}")
        latitude = 0.0
        longitude = 0.0
    
    user_id = sys.argv[4]
    # event_id and pubkey are not used in current implementation
    # (UPlanet_IA_Responder.sh handles Nostr response sending)
    
    log_message(f"Starting PlantNet recognition for {user_id}")
    log_message(f"Image URL: {image_url}")
    log_message(f"Location: {latitude}, {longitude}")
    
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
    result = format_plantnet_result(plant_info, latitude, longitude, image_url)
    
    if result:
        log_message("PlantNet recognition completed successfully")
        print(result)  # Output the result to stdout
        sys.exit(0)  # Explicit success exit
    else:
        log_message("Failed to format PlantNet result")
        error_result = f"""🌿 Reconnaissance de plante

❌ **Erreur de formatage**

Une erreur s'est produite lors du formatage du résultat.

📍 **Localisation :** {latitude:.4f}, {longitude:.4f}

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
        print(error_result)
        sys.exit(0)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_message(f"Unhandled exception in main: {e}")
        error_result = f"""🌿 Reconnaissance de plante

❌ **Erreur inattendue**

Une erreur inattendue s'est produite: {str(e)}

💡 **Veuillez réessayer ou contacter l'administrateur**

🔬 **Source :** PlantNet API
🌐 **Powered by :** [PlantNet.org](https://plantnet.org)

#PlantNet"""
        print(error_result)
        sys.exit(0)  # Exit with 0 even on error to avoid triggering error handling
