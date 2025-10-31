#!/usr/bin/env python3
################################################################################
# plantnet_ore_integration.py
# Integrates PlantNet plant recognition with ORE biodiversity tracking
# Author: UPlanet Development Team
# Version: 1.0
# License: AGPL-3.0
################################################################################

import json
import sys
import os
import subprocess
import re
from typing import Dict, Any, Optional

def extract_plantnet_info_from_json(plantnet_json: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Extract plant information from PlantNet JSON result.
    
    Args:
        plantnet_json: PlantNet JSON response from plantnet_recognition.py --json
    
    Returns:
        Dict with species info or None if parsing fails
    """
    try:
        if not plantnet_json.get('success'):
            print(f"PlantNet recognition was not successful: {plantnet_json.get('error')}", file=sys.stderr)
            return None
        
        best_match = plantnet_json.get('best_match', {})
        
        return {
            "species_name": best_match.get('common_names', ['Unknown'])[0] if best_match.get('common_names') else best_match.get('scientific_name', 'Unknown'),
            "scientific_name": best_match.get('scientific_name', 'Unknown'),
            "confidence": best_match.get('confidence', 0.0),
            "image_url": plantnet_json.get('image_url', ''),
            "common_names": best_match.get('common_names', []),
            "alternatives": plantnet_json.get('alternatives', []),
            "wikipedia_url": best_match.get('wikipedia_url', '')
        }
    except Exception as e:
        print(f"Error parsing PlantNet JSON: {e}", file=sys.stderr)
        return None

def extract_plantnet_info(plantnet_result: str) -> Optional[Dict[str, Any]]:
    """Extract plant information from PlantNet result message.
    
    Parses the PlantNet response to extract:
    - Species name (common name)
    - Scientific name
    - Confidence score
    - Image URL (if present)
    
    Returns None if parsing fails.
    """
    try:
        # Extract species name (first line after 🌿)
        species_match = re.search(r'🌿\s*\*\*([^*]+)\*\*', plantnet_result)
        if not species_match:
            return None
        species_name = species_match.group(1).strip()
        
        # Extract scientific name (italic line)
        scientific_match = re.search(r'_([^_]+)_', plantnet_result)
        if not scientific_match:
            return None
        scientific_name = scientific_match.group(1).strip()
        
        # Extract confidence score
        confidence_match = re.search(r'Confiance\s*:\s*(\d+(?:\.\d+)?)\s*%', plantnet_result)
        confidence = float(confidence_match.group(1)) / 100.0 if confidence_match else 0.0
        
        # Extract image URL
        image_match = re.search(r'https?://[^\s]+\.(jpg|jpeg|png|gif|webp)', plantnet_result, re.IGNORECASE)
        image_url = image_match.group(0) if image_match else ""
        
        return {
            "species_name": species_name,
            "scientific_name": scientific_name,
            "confidence": confidence,
            "image_url": image_url
        }
    except Exception as e:
        print(f"Error parsing PlantNet result: {e}", file=sys.stderr)
        return None

def record_plant_observation(lat: str, lon: str, species_name: str, 
                            scientific_name: str, observer_pubkey: str,
                            confidence: float, image_url: str = "", 
                            event_id: str = "") -> Dict[str, Any]:
    """Record a plant observation in the UMAP biodiversity system.
    
    Calls ore_system.py to:
    1. Check if the species already exists in this UMAP
    2. Add the observation to the biodiversity record
    3. Return information about the observation (new species, total species, etc.)
    """
    ore_system_path = os.path.join(os.path.dirname(__file__), "../tools/ore_system.py")
    
    try:
        # First, check if species already exists
        check_cmd = [
            "python3", ore_system_path, "check_plant", 
            lat, lon, scientific_name
        ]
        check_result = subprocess.run(check_cmd, capture_output=True, text=True)
        
        existing_info = {}
        if check_result.returncode == 0 and check_result.stdout:
            existing_info = json.loads(check_result.stdout)
        
        # Add the observation
        add_cmd = [
            "python3", ore_system_path, "add_plant",
            lat, lon, species_name, scientific_name, 
            observer_pubkey, str(confidence), image_url, event_id
        ]
        add_result = subprocess.run(add_cmd, capture_output=True, text=True)
        
        if add_result.returncode != 0:
            print(f"Error recording observation: {add_result.stderr}", file=sys.stderr)
            return {"success": False, "error": add_result.stderr}
        
        observation_info = json.loads(add_result.stdout)
        observation_info["already_observed"] = existing_info.get("exists", False)
        observation_info["success"] = True
        
        return observation_info
    
    except Exception as e:
        print(f"Error recording plant observation: {e}", file=sys.stderr)
        return {"success": False, "error": str(e)}

def format_ore_response(observation_info: Dict[str, Any]) -> str:
    """Format the ORE observation result as a user-friendly message.
    
    Creates a message that includes:
    - New species indicator (if first observation in UMAP)
    - Current biodiversity stats
    - ORE contribution information
    """
    if not observation_info.get("success"):
        return ""
    
    is_new = observation_info.get("is_new_species", False)
    total_species = observation_info.get("total_species", 0)
    total_obs = observation_info.get("total_observations", 0)
    biodiversity_score = observation_info.get("biodiversity_score", 0.0)
    species_name = observation_info.get("common_name", "")
    scientific_name = observation_info.get("scientific_name", "")
    
    # Build the message
    message = "\n\n---\n\n"
    message += "### 🌱 ORE Biodiversity Contribution\n\n"
    
    if is_new:
        message += f"🎉 **NEW SPECIES** for this UMAP! You discovered **{species_name}** (_${scientific_name}_)!\n\n"
    else:
        message += f"📝 **OBSERVATION RECORDED** for **{species_name}** (_${scientific_name}_)\n\n"
    
    message += f"📊 **UMAP Biodiversity Stats:**\n"
    message += f"- 🌿 Unique Species: **{total_species}**\n"
    message += f"- 📸 Total Observations: **{total_obs}**\n"
    message += f"- 🏆 Biodiversity Score: **{biodiversity_score:.2%}**\n\n"
    
    # ORE contribution info
    message += "💰 **ORE Ecological Contribution:**\n"
    message += "Your plant observation contributes to this UMAP's environmental obligations!\n"
    message += "Higher biodiversity scores unlock ORE rewards and ecosystem protection.\n\n"
    
    message += "#ORE #UPlanet #Biodiversity #FloraQuest #PlantNet"
    
    return message

def main():
    """Main function for PlantNet ORE integration.
    
    Usage: python3 plantnet_ore_integration.py <lat> <lon> <observer_pubkey> <event_id> <image_url>
    
    This version calls plantnet_recognition.py --json internally for structured data.
    """
    if len(sys.argv) < 6:
        print("Usage: python3 plantnet_ore_integration.py <lat> <lon> <observer_pubkey> <event_id> <image_url>", file=sys.stderr)
        sys.exit(1)
    
    lat = sys.argv[1]
    lon = sys.argv[2]
    observer_pubkey = sys.argv[3]
    event_id = sys.argv[4]
    image_url = sys.argv[5]
    
    # Call plantnet_recognition.py with --json flag for structured output
    plantnet_script = os.path.join(os.path.dirname(__file__), "plantnet_recognition.py")
    
    try:
        print(f"Calling PlantNet recognition with JSON output...", file=sys.stderr)
        result = subprocess.run(
            [
                "python3", plantnet_script,
                image_url, lat, lon,
                observer_pubkey, event_id, observer_pubkey,
                "--json"
            ],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode != 0:
            print(f"PlantNet recognition failed with exit code {result.returncode}", file=sys.stderr)
            print(f"stderr: {result.stderr}", file=sys.stderr)
            sys.exit(1)
        
        # Parse JSON response
        plantnet_json = json.loads(result.stdout)
        print(f"PlantNet JSON response: {json.dumps(plantnet_json, indent=2)}", file=sys.stderr)
        
        # Extract plant information from JSON
        plant_info = extract_plantnet_info_from_json(plantnet_json)
        if not plant_info:
            print("Error: Could not parse PlantNet JSON result", file=sys.stderr)
            sys.exit(1)
        
    except subprocess.TimeoutExpired:
        print("Error: PlantNet recognition timed out", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Could not parse PlantNet JSON response: {e}", file=sys.stderr)
        print(f"stdout: {result.stdout}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error calling PlantNet recognition: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Record the observation in ORE system
    observation_info = record_plant_observation(
        lat, lon,
        plant_info["species_name"],
        plant_info["scientific_name"],
        observer_pubkey,
        plant_info["confidence"],
        plant_info["image_url"],
        event_id
    )
    
    if not observation_info.get("success"):
        print(f"Error recording observation: {observation_info.get('error', 'Unknown error')}", file=sys.stderr)
        sys.exit(1)
    
    # Format and print the ORE response
    ore_message = format_ore_response(observation_info)
    print(ore_message)
    
    # Also output JSON for programmatic use (to stderr to not pollute main output)
    enhanced_info = {
        **observation_info,
        "plantnet_data": plant_info
    }
    print(f"\n<!-- ORE_DATA: {json.dumps(enhanced_info)} -->", file=sys.stderr)

if __name__ == "__main__":
    main()

