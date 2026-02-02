#!/usr/bin/env python3
################################################################################
# ORE System - Consolidated Python Module
# Handles ORE verification, economic rewards, and DID management
# Author: UPlanet Development Team
# Version: 1.0
# License: AGPL-3.0
################################################################################

import json
import os
import sys
import random
import time
import hashlib
import subprocess
import glob
import re
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from enum import Enum

def canonicalize_json(data: Any) -> str:
    """
    Canonicalize JSON according to RFC 8785 (JCS - JSON Canonicalization Scheme).
    
    This ensures that the same JSON data always produces the same string representation,
    which is critical for cryptographic signatures. The output is:
    - Keys sorted lexicographically
    - No whitespace between tokens
    - No trailing commas
    - Consistent number formatting
    
    Args:
        data: Python object to serialize (dict, list, etc.)
    
    Returns:
        Canonical JSON string ready for signing
    
    Reference: https://datatracker.ietf.org/doc/html/rfc8785
    """
    return json.dumps(
        data,
        sort_keys=True,           # Lexicographic key ordering
        separators=(',', ':'),   # No whitespace (compact)
        ensure_ascii=False,      # Preserve Unicode
        allow_nan=False          # Reject NaN/Infinity (not in JSON spec)
    )

class ComplianceStatus(Enum):
    """Environmental compliance status."""
    COMPLIANT = "compliant"
    NON_COMPLIANT = "non_compliant"
    WARNING = "warning"
    PENDING = "pending"
    ERROR = "error"

class RewardType(Enum):
    """Types of economic rewards."""
    COMPLIANCE_BONUS = "compliance_bonus"
    ECOSYSTEM_SERVICE = "ecosystem_service"
    CARBON_CREDIT = "carbon_credit"
    BIODIVERSITY_PREMIUM = "biodiversity_premium"
    WATER_QUALITY_BONUS = "water_quality_bonus"

@dataclass
class EconomicReward:
    """Economic reward for environmental compliance."""
    reward_id: str
    umap_did: str
    reward_type: RewardType
    amount: float
    currency: str
    reason: str
    verification_date: datetime
    compliance_score: float
    evidence: List[Dict[str, Any]]

class OREVerificationSystem:
    """Handles ORE compliance verification using external data sources."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config if config else {}
        self.satellite_api_key = self.config.get("satellite_data", {}).get("copernicus_api_key", "mock_copernicus_key")
        self.iot_network_url = self.config.get("iot_sensors", {}).get("network_url", "mock_iot_url")

    def _fetch_satellite_data(self, lat: float, lon: float, obligation_type: str) -> Dict[str, Any]:
        """Simulates fetching satellite data for a given location and obligation type."""
        print(f"  🛰️  Fetching satellite data for ({lat}, {lon}) for {obligation_type}...")
        time.sleep(0.2)
        if "forest cover" in obligation_type.lower():
            return {"forest_cover_percentage": random.uniform(70.0, 95.0)}
        return {}

    def _fetch_iot_sensor_data(self, lat: float, lon: float, obligation_type: str) -> Dict[str, Any]:
        """Simulates fetching IoT sensor data for a given location and obligation type."""
        print(f"  📡 Fetching IoT sensor data for ({lat}, {lon}) for {obligation_type}...")
        time.sleep(0.2)
        if "pesticide" in obligation_type.lower():
            return {"pesticide_residues": random.uniform(0.0, 0.05)}
        if "water quality" in obligation_type.lower():
            return {"ph": random.uniform(6.0, 8.0), "turbidity": random.uniform(0.5, 2.0)}
        return {}

    def _perform_drone_survey(self, lat: float, lon: float, obligation_type: str) -> Dict[str, Any]:
        """Simulates performing a drone survey for a given location and obligation type."""
        print(f"  🚁 Performing drone survey for ({lat}, {lon}) for {obligation_type}...")
        time.sleep(0.2)
        if "biodiversity" in obligation_type.lower():
            return {"species_count": random.randint(5, 20), "habitat_quality": random.uniform(0.6, 0.9)}
        return {}

    def analyze_compliance(self, sensor_data: Dict[str, Any], 
                          obligations: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze sensor data against ORE obligations."""
        
        compliance_analysis = {
            "timestamp": datetime.utcnow().isoformat(),
            "obligations_checked": [],
            "compliance_status": "compliant",
            "violations": [],
            "warnings": []
        }
        
        for obligation in obligations:
            description = obligation.get("description", "N/A")
            metric = obligation.get("metric")
            target_value = obligation.get("targetValue")
            verification_method = obligation.get("verificationMethod")

            obligation_check = {
                "obligation": description,
                "status": "compliant",
                "evidence": [],
                "confidence": 1.0
            }
            
            is_compliant = True
            evidence_msg = []

            if "forest cover" in description.lower() and verification_method == "satellite_imagery":
                satellite_data = self._fetch_satellite_data(0.0, 0.0, description)
                current_cover = satellite_data.get("forest_cover_percentage", 0)
                if current_cover < target_value:
                    is_compliant = False
                    evidence_msg.append(f"Forest cover {current_cover:.2f}% below target {target_value}%")
                else:
                    evidence_msg.append(f"Forest cover {current_cover:.2f}% meets target {target_value}%")

            elif "pesticide use" in description.lower() and verification_method == "iot_sensors":
                iot_data = self._fetch_iot_sensor_data(0.0, 0.0, description)
                residues = iot_data.get("pesticide_residues", 0)
                if residues > 0.01:
                    is_compliant = False
                    evidence_msg.append(f"Pesticide residues detected: {residues:.2f}")
                else:
                    evidence_msg.append(f"No significant pesticide residues detected: {residues:.2f}")

            elif "biodiversity" in description.lower() and verification_method == "human_audit":
                drone_data = self._perform_drone_survey(0.0, 0.0, description)
                species_count = drone_data.get("species_count", 0)
                if species_count < 10:
                    is_compliant = False
                    evidence_msg.append(f"Biodiversity assessment shows low species count: {species_count}")
                else:
                    evidence_msg.append(f"Biodiversity assessment shows healthy species count: {species_count}")

            if not is_compliant:
                obligation_check["status"] = "violation"
                compliance_analysis["compliance_status"] = "non_compliant"
                compliance_analysis["violations"].append({
                    "obligation": description,
                    "evidence": ", ".join(evidence_msg),
                    "severity": "high"
                })
            else:
                obligation_check["evidence"].append(", ".join(evidence_msg))

            compliance_analysis["obligations_checked"].append(obligation_check)
        
        return compliance_analysis

    def verify_ore_compliance(self, did_document: Dict[str, Any], ore_credential: Dict[str, Any]) -> Tuple[bool, Dict[str, Any]]:
        """Verifies ORE compliance based on a DID Document and ORE Verifiable Credential."""
        print(f"--- Verifying ORE Compliance for DID: {did_document['id']} ---")
        
        obligations = ore_credential['credentialSubject']['ecologicalObligations']
        print(f"Obligations to verify: {obligations}")

        compliance_status = {}
        overall_compliant = True

        for obligation in obligations:
            description = obligation['description']
            target_value = obligation.get('targetValue')
            metric = obligation.get('metric')

            print(f"  - Checking: '{description}' (Target: {target_value} {metric if metric else ''})")

            is_compliant = random.choice([True, False])
            
            if not is_compliant:
                overall_compliant = False
                print(f"    ❌ Non-compliant: {description}")
            else:
                print(f"    ✅ Compliant: {description}")
            
            compliance_status[description] = is_compliant
            time.sleep(0.1)

        print(f"Overall ORE Compliance: {'✅ COMPLIANT' if overall_compliant else '❌ NON-COMPLIANT'}")
        return overall_compliant, compliance_status

class OREEconomicSystem:
    """Handles economic rewards for ORE compliance."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config if config else {}
        self.base_reward_rate = self.config.get("economic_system", {}).get("base_reward_rate", 10.0)
        self.carbon_credit_rate = self.config.get("economic_system", {}).get("carbon_credit_rate", 0.1)
        self.biodiversity_premium_rate = self.config.get("economic_system", {}).get("biodiversity_premium_rate", 5.0)
        self.uplanet_scic_did = self.config.get("guardian_authority", {}).get("uplanet_scic_did", "did:nostr:uplanetscic")

    def calculate_compliance_reward(self, did_document: Dict[str, Any], compliance_report: Dict[str, Any]) -> Dict[str, Any]:
        """Calculates economic rewards based on the compliance report."""
        print(f"\n--- Calculating ORE Rewards for DID: {did_document['id']} ---")
        
        total_zen_reward = 0.0
        total_carbon_credits = 0.0
        total_biodiversity_premiums = 0.0
        
        overall_status = compliance_report.get("compliance_status", "non_compliant")
        obligations_checked = compliance_report.get("obligations_checked", [])

        if overall_status == ComplianceStatus.COMPLIANT.value:
            total_zen_reward += self.base_reward_rate
            print(f"  ✅ Base compliance reward: +{self.base_reward_rate:.2f} Ẑen")

            for obligation_check in obligations_checked:
                obligation_desc = obligation_check.get("obligation", "")
                status = obligation_check.get("status", "non_compliant")

                if status == "compliant":
                    if "forest cover" in obligation_desc.lower():
                        carbon_credits = random.uniform(0.5, 2.0) * self.carbon_credit_rate
                        total_carbon_credits += carbon_credits
                        print(f"    🌳 Carbon credits for forest cover: +{carbon_credits:.2f}")
                    
                    if "biodiversity" in obligation_desc.lower():
                        biodiversity_premium = random.uniform(0.1, 0.5) * self.biodiversity_premium_rate
                        total_biodiversity_premiums += biodiversity_premium
                        print(f"    🦋 Biodiversity premium: +{biodiversity_premium:.2f} Ẑen")

                    if "water quality" in obligation_desc.lower():
                        water_bonus = random.uniform(0.1, 0.3) * self.base_reward_rate
                        total_zen_reward += water_bonus
                        print(f"    💧 Water quality bonus: +{water_bonus:.2f} Ẑen")

        elif overall_status == ComplianceStatus.WARNING.value:
            print("  ⚠️  Partial compliance or warnings. Reduced rewards.")
            total_zen_reward += self.base_reward_rate * 0.5
        else:
            print("  ❌ Non-compliant. No rewards issued.")

        print(f"Total Ẑen reward: {total_zen_reward:.2f} Ẑen")
        print(f"Total Carbon Credits: {total_carbon_credits:.2f}")
        print(f"Total Biodiversity Premiums: {total_biodiversity_premiums:.2f} Ẑen")

        return {
            "total_zen_reward": total_zen_reward,
            "total_carbon_credits": total_carbon_credits,
            "total_biodiversity_premiums": total_biodiversity_premiums,
            "reward_date": datetime.utcnow().isoformat(),
            "uplanet_scic_did": self.uplanet_scic_did
        }

    def distribute_rewards(self, did_document: Dict[str, Any], rewards: Dict[str, Any]) -> bool:
        """Simulates the distribution of rewards to the UMAP owner."""
        print(f"\n--- Distributing ORE Rewards for DID: {did_document['id']} ---")
        
        umap_owner_did = did_document.get("id")
        if not umap_owner_did:
            print("❌ UMAP DID not found in document. Cannot distribute rewards.")
            return False

        zen_amount = rewards.get("total_zen_reward", 0.0)
        carbon_credits = rewards.get("total_carbon_credits", 0.0)
        biodiversity_premiums = rewards.get("total_biodiversity_premiums", 0.0)

        if zen_amount > 0:
            print(f"  💰 Transferring {zen_amount:.2f} Ẑen to {umap_owner_did}...")
            time.sleep(0.5)
            print("  ✅ Ẑen transfer simulated.")
        
        if carbon_credits > 0:
            print(f"  🌿 Issuing {carbon_credits:.2f} Carbon Credits to {umap_owner_did}...")
            time.sleep(0.5)
            print("  ✅ Carbon Credits issuance simulated.")

        if biodiversity_premiums > 0:
            print(f"  🦋 Issuing {biodiversity_premiums:.2f} Biodiversity Premiums to {umap_owner_did}...")
            time.sleep(0.5)
            print("  ✅ Biodiversity Premiums issuance simulated.")

        print(f"Rewards distribution simulated for {umap_owner_did}.")
        return True

class OREUMAPDIDGenerator:
    """Generates DIDs for UMAP geographic cells."""
    
    def __init__(self, uplanet_name: str):
        self.uplanet_name = uplanet_name

    def generate_umap_did(self, lat: str, lon: str) -> Tuple[str, Dict[str, Any], str, str, str, str]:
        """Generates a DID for a UMAP geographic cell and its DID Document.
        
        Returns:
            did: The DID identifier (did:nostr:hex)
            did_document: The DID Document
            umap_nsec: Nostr secret key (nsec format)
            umap_npub: Nostr public key (npub format)
            umap_hex: Nostr public key (hex format)
            umap_g1pub: Duniter/Ğ1 public key (base58 format)
        """
        
        # Generate Nostr keys using existing UPlanet keygen
        umap_nsec_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}" -s'
        umap_nsec = subprocess.check_output(umap_nsec_cmd, shell=True, text=True).strip()

        umap_npub_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}"'
        umap_npub = subprocess.check_output(umap_npub_cmd, shell=True, text=True).strip()

        umap_hex_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/nostr2hex.py "{umap_npub}"'
        umap_hex = subprocess.check_output(umap_hex_cmd, shell=True, text=True).strip()

        # Generate Duniter/Ğ1 public key (base58 format) for blockchain transactions
        umap_g1pub_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t duniter "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}"'
        umap_g1pub_output = subprocess.check_output(umap_g1pub_cmd, shell=True, text=True).strip()
        # Extract the pub key from "pub: <key>" format
        umap_g1pub = umap_g1pub_output.split("pub: ")[-1].split("\n")[0] if "pub: " in umap_g1pub_output else umap_g1pub_output.split("\n")[0]

        # Create the DID (did:nostr method with HEX format)
        did = f"did:nostr:{umap_hex}"

        # Create a basic DID Document
        did_document = {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": did,
            "verificationMethod": [
                {
                    "id": f"{did}#key-1",
                    "type": "Ed25519VerificationKey2020",
                    "controller": did,
                    "publicKeyHex": umap_hex,
                    "publicKeyBase58": umap_g1pub
                }
            ],
            "authentication": [f"{did}#key-1"],
            "service": [
                {
                    "id": f"{did}#nostr-relay",
                    "type": "NostrRelay",
                    "serviceEndpoint": "wss://relay.copylaradio.com"
                },
                {
                    "id": f"{did}#duniter-blockchain",
                    "type": "DuniterBlockchain",
                    "serviceEndpoint": "https://g1.copylaradio.com"
                }
            ],
            "geographicContext": {
                "latitude": lat,
                "longitude": lon,
                "geohash": hashlib.sha256(f"{lat},{lon}".encode()).hexdigest()[:12]
            }
        }
        return did, did_document, umap_nsec, umap_npub, umap_hex, umap_g1pub

class OREBiodiversityTracker:
    """Tracks ALL inventory observations for UMAP diversity scoring.
    
    Tracks multiple inventory types to reflect the full diversity to conserve:
    - plant: Plants (PlantNet recognized)
    - insect: Insects
    - animal: Animals
    - object: Equipment and tools
    - place: Locations and places of interest
    - person: Key people/contacts for the UMAP
    
    This is used by plantnet.html to capture and store biodiversity data
    in the DID UMAP reference.
    """
    
    # Inventory types and their weights for diversity score calculation
    INVENTORY_TYPES = {
        "plant": {"weight": 2.0, "icon": "🌱", "name": "Plantes"},
        "insect": {"weight": 1.5, "icon": "🐛", "name": "Insectes"},
        "animal": {"weight": 1.5, "icon": "🦊", "name": "Animaux"},
        "object": {"weight": 1.0, "icon": "🔧", "name": "Équipements"},
        "place": {"weight": 1.0, "icon": "🏠", "name": "Lieux"},
        "person": {"weight": 0.5, "icon": "👤", "name": "Personnes"}
    }
    
    def __init__(self, umap_path: str):
        self.umap_path = umap_path
        self.biodiversity_file = os.path.join(umap_path, "ore_biodiversity.json")
        self._ensure_biodiversity_file()
    
    def _ensure_biodiversity_file(self):
        """Create biodiversity tracking file if it doesn't exist.
        
        The file structure now supports ALL inventory types from plantnet.html:
        - species: Plant species (backward compatible)
        - inventory: All inventory items by type (new)
        """
        if not os.path.exists(self.biodiversity_file):
            os.makedirs(self.umap_path, exist_ok=True)
            initial_data = {
                # Backward compatible plant species tracking
                "species": {},
                "total_observations": 0,
                "unique_species": 0,
                # New: Track ALL inventory types
                "inventory": {
                    "plant": {"items": {}, "count": 0},
                    "insect": {"items": {}, "count": 0},
                    "animal": {"items": {}, "count": 0},
                    "object": {"items": {}, "count": 0},
                    "place": {"items": {}, "count": 0},
                    "person": {"items": {}, "count": 0}
                },
                "diversity_score": 0.0,
                "last_updated": datetime.utcnow().isoformat(),
                "observers": {}
            }
            with open(self.biodiversity_file, 'w') as f:
                json.dump(initial_data, f, indent=2)
        else:
            # Migrate existing file to new structure if needed
            self._migrate_to_extended_structure()
    
    def _migrate_to_extended_structure(self):
        """Migrate existing biodiversity file to extended structure with all inventory types."""
        try:
            with open(self.biodiversity_file, 'r') as f:
                data = json.load(f)
            
            # Check if migration is needed
            if "inventory" not in data:
                # Initialize inventory structure
                data["inventory"] = {
                    "plant": {"items": {}, "count": 0},
                    "insect": {"items": {}, "count": 0},
                    "animal": {"items": {}, "count": 0},
                    "object": {"items": {}, "count": 0},
                    "place": {"items": {}, "count": 0},
                    "person": {"items": {}, "count": 0}
                }
                
                # Migrate existing plant species to inventory.plant
                for scientific_name, species_data in data.get("species", {}).items():
                    data["inventory"]["plant"]["items"][scientific_name] = {
                        "name": species_data.get("common_name", scientific_name),
                        "scientific_name": scientific_name,
                        "first_observed": species_data.get("first_observed"),
                        "observations": species_data.get("observations", []),
                        "observers": species_data.get("observers", [])
                    }
                    data["inventory"]["plant"]["count"] += 1
                
                data["diversity_score"] = self._calculate_diversity_score(data)
                
                with open(self.biodiversity_file, 'w') as f:
                    json.dump(data, f, indent=2)
                    
                print(f"✅ Migrated biodiversity file to extended structure")
        except Exception as e:
            print(f"⚠️ Migration warning: {e}")
    
    def add_inventory_observation(self, inventory_type: str, item_name: str,
                                   item_id: str, observer_pubkey: str,
                                   confidence: float = 1.0, image_url: str = "",
                                   nostr_event_id: str = "", scientific_name: str = "",
                                   description: str = "", location: str = "") -> Dict[str, Any]:
        """Add ANY inventory observation to the UMAP diversity record.
        
        This is the generic method for ALL inventory types captured by plantnet.html:
        - plant, insect, animal, object, place, person
        
        Args:
            inventory_type: Type of inventory (plant, insect, animal, object, place, person)
            item_name: Human-readable name of the item
            item_id: Unique identifier (scientific name for species, or generated ID)
            observer_pubkey: Nostr public key of the observer
            confidence: Recognition confidence (0-1)
            image_url: IPFS URL of the observation image
            nostr_event_id: Nostr event ID of the observation
            scientific_name: Scientific name (for species)
            description: Description of the item
            location: Location description
            
        Returns:
            dict with observation result and diversity score
        """
        # Validate inventory type
        if inventory_type not in self.INVENTORY_TYPES:
            inventory_type = "object"  # Default to object for unknown types
        
        with open(self.biodiversity_file, 'r') as f:
            data = json.load(f)
        
        # Ensure inventory structure exists (for backward compatibility)
        if "inventory" not in data:
            self._migrate_to_extended_structure()
            with open(self.biodiversity_file, 'r') as f:
                data = json.load(f)
        
        inv_type_data = data["inventory"].get(inventory_type, {"items": {}, "count": 0})
        
        is_new_item = item_id not in inv_type_data["items"]
        
        # Initialize item record if new
        if is_new_item:
            inv_type_data["items"][item_id] = {
                "name": item_name,
                "scientific_name": scientific_name if scientific_name else None,
                "description": description,
                "location": location,
                "first_observed": datetime.utcnow().isoformat(),
                "observations": [],
                "observers": []
            }
            inv_type_data["count"] += 1
        
        # Add observation
        observation = {
            "timestamp": datetime.utcnow().isoformat(),
            "observer": observer_pubkey,
            "confidence": confidence,
            "image_url": image_url,
            "nostr_event_id": nostr_event_id
        }
        inv_type_data["items"][item_id]["observations"].append(observation)
        
        # Track observer for this item
        if observer_pubkey not in inv_type_data["items"][item_id]["observers"]:
            inv_type_data["items"][item_id]["observers"].append(observer_pubkey)
        
        # Track global observer
        if observer_pubkey not in data["observers"]:
            data["observers"][observer_pubkey] = {
                "first_observation": datetime.utcnow().isoformat(),
                "observation_count": 0
            }
        data["observers"][observer_pubkey]["observation_count"] += 1
        data["observers"][observer_pubkey]["last_observation"] = datetime.utcnow().isoformat()
        
        # Update totals
        data["inventory"][inventory_type] = inv_type_data
        data["total_observations"] += 1
        
        # For backward compatibility with plant species
        if inventory_type == "plant" and scientific_name:
            if scientific_name not in data["species"]:
                data["species"][scientific_name] = {
                    "common_name": item_name,
                    "first_observed": datetime.utcnow().isoformat(),
                    "observations": [],
                    "observers": []
                }
                data["unique_species"] += 1
            data["species"][scientific_name]["observations"].append(observation)
            if observer_pubkey not in data["species"][scientific_name]["observers"]:
                data["species"][scientific_name]["observers"].append(observer_pubkey)
        
        data["last_updated"] = datetime.utcnow().isoformat()
        
        # Calculate diversity score
        diversity_score = self._calculate_diversity_score(data)
        data["diversity_score"] = diversity_score
        
        # Save updated data
        with open(self.biodiversity_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        return {
            "is_new_item": is_new_item,
            "inventory_type": inventory_type,
            "item_id": item_id,
            "item_name": item_name,
            "observation_count": len(inv_type_data["items"][item_id]["observations"]),
            "type_count": inv_type_data["count"],
            "total_observations": data["total_observations"],
            "diversity_score": diversity_score,
            "type_icon": self.INVENTORY_TYPES[inventory_type]["icon"]
        }
    
    def _calculate_diversity_score(self, data: Dict[str, Any]) -> float:
        """Calculate overall diversity score based on ALL inventory types.
        
        Considers:
        - Species/item count per type (weighted by type importance)
        - Total observations
        - Observer diversity
        - Type diversity (having items in multiple categories)
        """
        total_weighted_items = 0
        types_with_items = 0
        
        inventory = data.get("inventory", {})
        for inv_type, type_data in inventory.items():
            count = type_data.get("count", 0)
            if count > 0:
                types_with_items += 1
                weight = self.INVENTORY_TYPES.get(inv_type, {}).get("weight", 1.0)
                total_weighted_items += count * weight
        
        # Include legacy species count
        unique_species = data.get("unique_species", 0)
        total_observations = data.get("total_observations", 0)
        observer_count = len(data.get("observers", {}))
        
        # Score components (0-100 total)
        # Weighted items score (0-50 points)
        items_score = min(total_weighted_items * 1.5, 50)
        
        # Type diversity bonus (0-20 points) - reward having diverse inventory
        type_diversity_score = min(types_with_items * 4, 20)
        
        # Observation activity score (0-20 points)
        observation_score = min(total_observations * 0.3, 20)
        
        # Observer diversity score (0-10 points)
        observer_score = min(observer_count * 2, 10)
        
        total_score = items_score + type_diversity_score + observation_score + observer_score
        
        # Normalize to 0-1 scale
        return min(total_score / 100.0, 1.0)
    
    def get_diversity_summary(self) -> Dict[str, Any]:
        """Get complete diversity summary for this UMAP including ALL inventory types."""
        if not os.path.exists(self.biodiversity_file):
            return {
                "diversity_score": 0.0,
                "inventory_summary": {},
                "total_observations": 0
            }
        
        with open(self.biodiversity_file, 'r') as f:
            data = json.load(f)
        
        # Build inventory summary
        inventory_summary = {}
        for inv_type, type_config in self.INVENTORY_TYPES.items():
            type_data = data.get("inventory", {}).get(inv_type, {"items": {}, "count": 0})
            inventory_summary[inv_type] = {
                "icon": type_config["icon"],
                "name": type_config["name"],
                "count": type_data.get("count", 0),
                "items": list(type_data.get("items", {}).keys())[:10]  # Top 10 items
            }
        
        return {
            "diversity_score": self._calculate_diversity_score(data),
            "inventory_summary": inventory_summary,
            "unique_species": data.get("unique_species", 0),
            "total_observations": data.get("total_observations", 0),
            "observer_count": len(data.get("observers", {})),
            "last_updated": data.get("last_updated"),
            # Legacy compatibility
            "biodiversity_score": self._calculate_biodiversity_score(data),
            "top_species": self._get_top_species(data, limit=5)
        }
    
    def add_plant_observation(self, species_name: str, scientific_name: str, 
                             observer_pubkey: str, confidence: float,
                             image_url: str = "", nostr_event_id: str = "") -> Dict[str, Any]:
        """Add a plant observation to the UMAP biodiversity record.
        
        Returns:
            dict with 'is_new_species', 'observation_count', 'biodiversity_score'
        """
        with open(self.biodiversity_file, 'r') as f:
            data = json.load(f)
        
        is_new_species = scientific_name not in data["species"]
        
        # Initialize species record if new
        if is_new_species:
            data["species"][scientific_name] = {
                "common_name": species_name,
                "first_observed": datetime.utcnow().isoformat(),
                "observations": [],
                "observers": []
            }
            data["unique_species"] += 1
        
        # Add observation
        observation = {
            "timestamp": datetime.utcnow().isoformat(),
            "observer": observer_pubkey,
            "confidence": confidence,
            "image_url": image_url,
            "nostr_event_id": nostr_event_id
        }
        data["species"][scientific_name]["observations"].append(observation)
        
        # Track observer
        if observer_pubkey not in data["species"][scientific_name]["observers"]:
            data["species"][scientific_name]["observers"].append(observer_pubkey)
        
        if observer_pubkey not in data["observers"]:
            data["observers"][observer_pubkey] = {
                "first_observation": datetime.utcnow().isoformat(),
                "observation_count": 0
            }
        data["observers"][observer_pubkey]["observation_count"] += 1
        data["observers"][observer_pubkey]["last_observation"] = datetime.utcnow().isoformat()
        
        data["total_observations"] += 1
        data["last_updated"] = datetime.utcnow().isoformat()
        
        # Save updated data
        with open(self.biodiversity_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        # Calculate biodiversity score
        biodiversity_score = self._calculate_biodiversity_score(data)
        
        return {
            "is_new_species": is_new_species,
            "observation_count": len(data["species"][scientific_name]["observations"]),
            "total_species": data["unique_species"],
            "total_observations": data["total_observations"],
            "biodiversity_score": biodiversity_score,
            "scientific_name": scientific_name,
            "common_name": species_name
        }
    
    def _calculate_biodiversity_score(self, data: Dict[str, Any]) -> float:
        """Calculate biodiversity score based on species diversity and observations.
        
        Score factors:
        - Unique species count (weighted heavily)
        - Total observations (shows activity)
        - Observer diversity (multiple people observing)
        """
        unique_species = data["unique_species"]
        total_observations = data["total_observations"]
        observer_count = len(data["observers"])
        
        # Base score from species diversity (0-70 points)
        species_score = min(unique_species * 2, 70)
        
        # Observation activity score (0-20 points)
        observation_score = min(total_observations * 0.5, 20)
        
        # Observer diversity score (0-10 points)
        observer_score = min(observer_count * 2, 10)
        
        total_score = species_score + observation_score + observer_score
        
        # Normalize to 0-1 scale
        return min(total_score / 100.0, 1.0)
    
    def get_biodiversity_summary(self) -> Dict[str, Any]:
        """Get current biodiversity summary for this UMAP."""
        if not os.path.exists(self.biodiversity_file):
            return {
                "unique_species": 0,
                "total_observations": 0,
                "biodiversity_score": 0.0
            }
        
        with open(self.biodiversity_file, 'r') as f:
            data = json.load(f)
        
        return {
            "unique_species": data["unique_species"],
            "total_observations": data["total_observations"],
            "biodiversity_score": self._calculate_biodiversity_score(data),
            "top_species": self._get_top_species(data, limit=5),
            "recent_observations": self._get_recent_observations(data, limit=10)
        }
    
    def _get_top_species(self, data: Dict[str, Any], limit: int = 5) -> List[Dict[str, Any]]:
        """Get most frequently observed species."""
        species_list = []
        for scientific_name, species_data in data["species"].items():
            species_list.append({
                "scientific_name": scientific_name,
                "common_name": species_data["common_name"],
                "observation_count": len(species_data["observations"])
            })
        
        species_list.sort(key=lambda x: x["observation_count"], reverse=True)
        return species_list[:limit]
    
    def _get_recent_observations(self, data: Dict[str, Any], limit: int = 10) -> List[Dict[str, Any]]:
        """Get most recent observations across all species."""
        all_observations = []
        for scientific_name, species_data in data["species"].items():
            for obs in species_data["observations"]:
                all_observations.append({
                    "scientific_name": scientific_name,
                    "common_name": species_data["common_name"],
                    **obs
                })
        
        all_observations.sort(key=lambda x: x["timestamp"], reverse=True)
        return all_observations[:limit]
    
    def check_if_species_exists(self, scientific_name: str) -> Dict[str, Any]:
        """Check if a species has already been observed in this UMAP."""
        if not os.path.exists(self.biodiversity_file):
            return {"exists": False}
        
        with open(self.biodiversity_file, 'r') as f:
            data = json.load(f)
        
        if scientific_name in data["species"]:
            species_data = data["species"][scientific_name]
            return {
                "exists": True,
                "common_name": species_data["common_name"],
                "first_observed": species_data["first_observed"],
                "observation_count": len(species_data["observations"]),
                "observers": len(species_data["observers"])
            }
        
        return {"exists": False}
    
    def get_all_images(self) -> List[Dict[str, Any]]:
        """Get all plant observation images for this UMAP.
        
        Returns:
            List of image records with metadata (URL, timestamp, species, observer)
        """
        if not os.path.exists(self.biodiversity_file):
            return []
        
        with open(self.biodiversity_file, 'r') as f:
            data = json.load(f)
        
        images = []
        for scientific_name, species_data in data["species"].items():
            for obs in species_data["observations"]:
                if obs.get("image_url"):
                    images.append({
                        "image_url": obs["image_url"],
                        "timestamp": obs["timestamp"],
                        "scientific_name": scientific_name,
                        "common_name": species_data["common_name"],
                        "observer": obs["observer"],
                        "confidence": obs.get("confidence", 0.0),
                        "nostr_event_id": obs.get("nostr_event_id", "")
                    })
        
        # Sort by timestamp (most recent first)
        images.sort(key=lambda x: x["timestamp"], reverse=True)
        return images

class OREUMAPManager:
    """Manages ORE system integration for UMAP geographic cells."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config if config else {}
        self.ipfs_node_id = self.config.get("ipfs_node_id", "default_node")  # Astroport.ONE local relay address
        self.uplanet_g1_pub = self.config.get("uplanet_g1_pub", "default_pub")  # Use UPLANETG1PUB for Zen usage
        self.my_relay = self.config.get("my_relay", "wss://relay.copylaradio.com")
        self.my_ipfs = self.config.get("my_ipfs", "https://ipfs.copylaradio.com")
        self.vdo_ninja = self.config.get("vdo_ninja", "https://vdo.ninja")
        self.pic_profile = self.config.get("pic_profile", "")

    def search_multipass_in_swarm(self, lat: str, lon: str, umap_zone: str) -> bool:
        """Search for MULTIPASS users in UPlanet swarm (local + swarm nodes)."""
        print(f"🔍 Searching for MULTIPASS in UPlanet swarm for UMAP zone ({lat}, {lon})...")
        
        found_multipass = False
        multipass_count = 0
        
        # Search paths for MULTIPASS GPS files
        search_paths = [
            f"~/.zen/tmp/{self.ipfs_node_id}/TW/*@*/GPS",         # Local TW accounts
            "~/.zen/tmp/swarm/*/TW/*@*/GPS"                       # Swarm TW accounts
        ]
        
        for search_path in search_paths:
            # Expand tilde and glob patterns
            expanded_path = os.path.expanduser(search_path)
            
            for gps_file in glob.glob(expanded_path):
                if os.path.isfile(gps_file):
                    player_dir = os.path.dirname(gps_file)
                    player_name = os.path.basename(player_dir)
                    
                    # Extract GPS coordinates
                    try:
                        with open(gps_file, 'r') as f:
                            content = f.read()
                            lat_match = re.search(r'^LAT=([^;]+)', content, re.MULTILINE)
                            lon_match = re.search(r'^LON=([^;]+)', content, re.MULTILINE)
                            
                            if lat_match and lon_match:
                                player_lat = lat_match.group(1).strip()
                                player_lon = lon_match.group(1).strip()
                                
                                if player_lat and player_lon:
                                    # Test if this MULTIPASS is in the UMAP zone
                                    if self._is_message_in_umap_zone(player_lat, player_lon, lat, lon):
                                        found_multipass = True
                                        multipass_count += 1
                                        
                                        # Determine source type
                                        source_type = "unknown"
                                        if "/.zen/game/nostr/" in gps_file:
                                            source_type = "local_nostr"
                                        elif "/TW/" in gps_file:
                                            if "/swarm/" in gps_file:
                                                source_type = "swarm_tw"
                                            else:
                                                source_type = "local_tw"
                                        
                                        print(f"📍 Found MULTIPASS in UMAP zone: {player_name} ({player_lat}, {player_lon}) [source: {source_type}]")
                                        
                                        # Early exit if we found at least one (for performance)
                                        if multipass_count >= 1:
                                            break
                    except Exception as e:
                        print(f"⚠️  Error reading GPS file {gps_file}: {e}")
                        continue
            
            # Early exit if found
            if found_multipass:
                break
        
        if found_multipass:
            print(f"✅ Found {multipass_count} MULTIPASS user(s) in UMAP zone ({lat}, {lon})")
            return True
        else:
            print(f"ℹ️  No MULTIPASS users found in UMAP zone ({lat}, {lon})")
            return False

    def _is_message_in_umap_zone(self, message_lat: str, message_lon: str, umap_lat: str, umap_lon: str) -> bool:
        """Check if message coordinates are within UMAP zone (0.01° precision)."""
        try:
            msg_lat = float(message_lat)
            msg_lon = float(message_lon)
            umap_lat_f = float(umap_lat)
            umap_lon_f = float(umap_lon)
            
            # Calculate UMAP zone boundaries (0.01° precision)
            zone_lat_min = umap_lat_f
            zone_lat_max = umap_lat_f + 0.01
            zone_lon_min = umap_lon_f
            zone_lon_max = umap_lon_f + 0.01
            
            # Check if message coordinates are within UMAP zone
            lat_in_zone = zone_lat_min <= msg_lat <= zone_lat_max
            lon_in_zone = zone_lon_min <= msg_lon <= zone_lon_max
            
            return lat_in_zone and lon_in_zone
        except ValueError:
            return False

    def should_activate_ore_mode(self, lat: str, lon: str, umappath: str) -> bool:
        """Check if a UMAP should activate ORE mode based on criteria."""
        # Skip global UMAP (0.00, 0.00)
        if lat == "0.00" and lon == "0.00":
            return False
        
        # Check if ORE mode is already activated
        ore_activated_file = os.path.join(umappath, "ore_mode.activated")
        if os.path.exists(ore_activated_file):
            return False
        
        # Check if this UMAP has MULTIPASS with real GPS coordinates using optimized swarm search
        if self.search_multipass_in_swarm(lat, lon, "umap_zone"):
            print(f"✅ UMAP ({lat}, {lon}) qualifies for ORE mode - has geolocated MULTIPASS users in swarm")
            return True
        
        # Additional criteria: environmental zones (forests, protected areas, etc.)
        env_score = self._calculate_environmental_score(lat, lon)
        if env_score >= 0.7:
            print(f"✅ UMAP ({lat}, {lon}) qualifies for ORE mode - high environmental value (score: {env_score})")
            return True
        
        return False

    def _calculate_environmental_score(self, lat: str, lon: str) -> float:
        """Calculate environmental score for a UMAP based on PlantNet observations.
        
        Uses real PlantNet biodiversity data from NOSTR to calculate an environmental
        score that reflects the actual biodiversity value of the UMAP.
        
        Args:
            lat: Latitude of the UMAP
            lon: Longitude of the UMAP
            
        Returns:
            Environmental score between 0.0 and 1.0, based on:
            - Species diversity (unique species count)
            - Observation activity (total plant observations)
            - Observer participation (number of unique observers)
        """
        try:
            # Get biodiversity statistics from PlantNet observations on NOSTR
            biodiversity_stats = self._get_biodiversity_stats(lat, lon)
            
            # Base score: use compliance_score which is calculated from species and observations
            # compliance_score = min((species_count * 0.02) + (plants_count * 0.01), 1.0)
            base_score = biodiversity_stats.get("compliance_score", 0.0)
            
            # Additional bonus for observer diversity (encourages community participation)
            # Bonus: 0.05 points per observer (capped at 0.2 for 4+ observers)
            observer_count = biodiversity_stats.get("observer_count", 0)
            observer_bonus = min(observer_count * 0.05, 0.2)
            
            # Calculate final environmental score
            env_score = min(base_score + observer_bonus, 1.0)
            
            # Log score details for debugging
            species_count = biodiversity_stats.get("species_count", 0)
            plants_count = biodiversity_stats.get("plants_count", 0)
            
            if env_score > 0:
                print(f"📊 Environmental score for UMAP ({lat}, {lon}): {env_score:.2f}")
                print(f"   - Species: {species_count} (score: {species_count * 0.02:.2f})")
                print(f"   - Observations: {plants_count} (score: {plants_count * 0.01:.2f})")
                print(f"   - Observers: {observer_count} (bonus: +{observer_bonus:.2f})")
            
            return round(env_score, 2)
            
        except Exception as e:
            # If we can't get biodiversity stats, return 0.0 (no activation)
            print(f"⚠️  Error calculating environmental score for UMAP ({lat}, {lon}): {e}")
            return 0.0

    def activate_ore_mode(self, lat: str, lon: str, umappath: str, keyfile_path: str = None) -> bool:
        """Activate ORE mode for a UMAP.
        
        Args:
            lat: Latitude
            lon: Longitude
            umappath: Path to UMAP directory
            keyfile_path: Optional path to .secret.nostr file (not used, UMAP keys are generated)
        """
        print(f"🌱 Activating ORE mode for UMAP ({lat}, {lon})")
        
        try:
            # Ensure UMAP directory exists
            os.makedirs(umappath, exist_ok=True)
            
            # Create ORE mode marker
            ore_activated_file = os.path.join(umappath, "ore_mode.activated")
            with open(ore_activated_file, 'w') as f:
                f.write(datetime.utcnow().isoformat())
            
            # Generate UMAP DID and keys using existing infrastructure
            generator = OREUMAPDIDGenerator(self.uplanet_g1_pub)
            did, did_doc, nsec, npub, hex_key, g1pub = generator.generate_umap_did(lat, lon)
            
            if not did:
                print("❌ Failed to generate UMAP DID for ORE mode")
                return False
            
            print(f"🔑 UMAP Keys generated:")
            print(f"   NSEC: {nsec[:20]}...")
            print(f"   NPUB: {npub[:20]}...")
            print(f"   HEX: {hex_key[:20]}...")
            print(f"   G1PUB: {g1pub[:20]}...")
            
            # Create UMAP keyfile for Nostr publishing
            umap_keyfile = os.path.join(umappath, ".secret.nostr")
            with open(umap_keyfile, 'w') as f:
                f.write(f"NSEC={nsec}; NPUB={npub}; HEX={hex_key};")
            os.chmod(umap_keyfile, 0o600)  # Secure permissions
            print(f"✅ UMAP keyfile saved: {umap_keyfile}")
            
            # Store the G1 public key for blockchain transactions
            g1pub_file = os.path.join(umappath, "g1pub.key")
            with open(g1pub_file, 'w') as f:
                f.write(g1pub)
            print(f"✅ Duniter/Ğ1 public key saved: {g1pub}")
            
            # Create ORE contract if conditions are met
            if self._should_create_ore_contract(lat, lon, umappath):
                ore_contract_path = self._create_ore_contract(lat, lon, umappath)
                if ore_contract_path:
                    print(f"✅ ORE contract created: {ore_contract_path}")
                    
                    # Verify compliance and calculate rewards
                    compliance_score = self._verify_ore_compliance(lat, lon)
                    if compliance_score:
                        total_reward = self._calculate_ore_rewards(lat, lon, compliance_score)
                        print(f"💰 ORE rewards calculated: {total_reward} Ẑen")
                        
                        # Update UMAP DID with ORE information and publish to Nostr (kind 30800)
                        self._update_umap_did_with_ore(umappath, did, compliance_score, total_reward, lat, lon)
            
            # Publish ORE status to Nostr using UMAP's own keyfile
            self._publish_ore_status_to_nostr(lat, lon, umap_keyfile, did)
            
            # Create initial ORE verification meeting
            verification_title = f"ORE Environmental Verification - UMAP ({lat}, {lon})"
            verification_description = f"Initial environmental assessment and ORE contract verification for geographic cell ({lat}, {lon})"
            starts_timestamp = int(time.time())
            
            self._create_ore_verification_meeting(lat, lon, umap_keyfile, verification_title, verification_description, starts_timestamp)
            
            print(f"✅ ORE mode activated for UMAP ({lat}, {lon})")
            return True
            
        except Exception as e:
            print(f"❌ Error activating ORE mode: {e}")
            import traceback
            traceback.print_exc()
            return False

    def _should_create_ore_contract(self, lat: str, lon: str, umappath: str) -> bool:
        """Check if an ORE contract should be created for this UMAP."""
        # Check if contract already exists
        ore_contract_file = os.path.join(umappath, "ore_contract.json")
        if os.path.exists(ore_contract_file):
            return False
        
        # Check if this UMAP has environmental potential
        env_score = self._calculate_environmental_score(lat, lon)
        return env_score >= 0.5

    def _create_ore_contract(self, lat: str, lon: str, umappath: str) -> Optional[str]:
        """Create ORE contract for UMAP."""
        try:
            # Create ORE contract JSON file
            ore_contract_path = os.path.join(umappath, "ore_contract.json")
            
            # Create basic ORE contract structure
            contract_data = {
                "@context": ["https://www.w3.org/2018/credentials/v1", "https://u.copylaradio.com/contexts/ore/v1"],
                "type": ["VerifiableCredential", "EcologicalRealObligation"],
                "credentialSubject": {
                    "id": f"did:nostr:{self.uplanet_g1_pub[:8]}",
                    "oreContractId": f"ORE-{lat}-{lon}-{datetime.now().strftime('%Y%m%d')}",
                    "validUntil": "2122-12-31",
                    "geographicArea": {
                        "latitude": lat,
                        "longitude": lon,
                        "radiusKm": 0.05
                    },
                    "ecologicalObligations": [
                        {"description": "Maintain 80% forest cover", "metric": "percentage", "targetValue": 80, "verificationMethod": "satellite_imagery"},
                        {"description": "Prohibit pesticide use", "metric": "status", "targetValue": "none", "verificationMethod": "iot_sensors"},
                        {"description": "Protect local biodiversity", "metric": "status", "targetValue": "active", "verificationMethod": "human_audit"}
                    ],
                    "stewardshipProvider": {
                        "id": f"did:nostr:{self.uplanet_g1_pub[:8]}",
                        "name": "UPlanet Cooperative"
                    }
                },
                "issuer": f"did:nostr:{self.uplanet_g1_pub[:8]}",
                "issuanceDate": datetime.utcnow().isoformat(),
                "proof": {
                    "type": "NostrSignature2023",
                    "verificationMethod": f"did:nostr:{self.uplanet_g1_pub[:8]}#key-1",
                    "signature": "mock_signature_by_uplanet_coop"
                }
            }
            
            with open(ore_contract_path, 'w') as f:
                json.dump(contract_data, f, indent=2)
            
            return ore_contract_path
            
        except Exception as e:
            print(f"❌ Error creating ORE contract: {e}")
            return None

    def _verify_ore_compliance(self, lat: str, lon: str) -> Optional[float]:
        """Verify ORE compliance using consolidated Python script."""
        try:
            # Use the consolidated ORE system
            result = subprocess.run([
                "python3", "ore_system.py", "verify", lat, lon
            ], capture_output=True, text=True, cwd=os.path.dirname(__file__))
            
            if result.returncode == 0 and result.stdout:
                # Extract compliance score from result
                import re
                compliance_match = re.search(r'"compliance":\s*([0-9.]+)', result.stdout)
                if compliance_match:
                    return float(compliance_match.group(1))
            
            return 0.85  # Default compliance score
            
        except Exception as e:
            print(f"⚠️  Error verifying ORE compliance: {e}")
            return 0.85  # Default compliance score

    def _calculate_ore_rewards(self, lat: str, lon: str, compliance_score: float) -> Optional[float]:
        """Calculate ORE rewards using consolidated Python script."""
        try:
            # Use the consolidated ORE system
            result = subprocess.run([
                "python3", "ore_system.py", "reward", lat, lon
            ], capture_output=True, text=True, cwd=os.path.dirname(__file__))
            
            if result.returncode == 0 and result.stdout:
                # Extract total reward from result
                import re
                reward_match = re.search(r'"total_zen_reward":\s*([0-9.]+)', result.stdout)
                if reward_match:
                    return float(reward_match.group(1))
            
            return 15.5  # Default reward
            
        except Exception as e:
            print(f"⚠️  Error calculating ORE rewards: {e}")
            return 15.5  # Default reward

    def _update_umap_did_with_ore(self, umappath: str, umap_did: str, compliance_score: float, total_reward: float, lat: str = "", lon: str = "") -> None:
        """Update UMAP DID with ORE information and publish to Nostr (kind 30800).
        
        The biodiversity/diversity data (ore_biodiversity.json) is now attached to the DID document
        and published to Nostr instead of just storing in the filesystem.
        
        Now includes ALL inventory types captured by plantnet.html:
        - plant, insect, animal, object, place, person
        """
        try:
            # Get biodiversity data if it exists
            biodiversity_data = {}
            biodiversity_file = os.path.join(umappath, "ore_biodiversity.json")
            if os.path.exists(biodiversity_file):
                with open(biodiversity_file, 'r') as f:
                    biodiversity_data = json.load(f)
            
            # Build inventory summary from extended structure
            inventory_summary = {}
            inventory_data = biodiversity_data.get("inventory", {})
            for inv_type in ["plant", "insect", "animal", "object", "place", "person"]:
                type_data = inventory_data.get(inv_type, {"items": {}, "count": 0})
                if type_data.get("count", 0) > 0:
                    inventory_summary[inv_type] = {
                        "count": type_data.get("count", 0),
                        "items": list(type_data.get("items", {}).keys())[:20]  # Top 20 items per type
                    }
            
            # Calculate diversity score using extended method
            tracker = OREBiodiversityTracker(umappath)
            diversity_summary = tracker.get_diversity_summary()
            
            # Create ORE metadata with FULL diversity data attached
            ore_metadata = {
                "umap_did": umap_did,
                "coordinates": {"lat": lat, "lon": lon},
                "ore_mode_activated": datetime.utcnow().isoformat(),
                "compliance_score": compliance_score,
                "total_reward": total_reward,
                "guardian_authority": f"did:nostr:{self.uplanet_g1_pub[:8]}",
                "uplanet_integration": True,
                # Extended diversity data (replaces simple biodiversity)
                "diversity": {
                    "diversity_score": diversity_summary.get("diversity_score", 0.0),
                    "total_observations": biodiversity_data.get("total_observations", 0),
                    "observer_count": len(biodiversity_data.get("observers", {})),
                    "last_updated": biodiversity_data.get("last_updated", datetime.utcnow().isoformat()),
                    # Inventory by type (from plantnet.html)
                    "inventory_summary": inventory_summary
                },
                # Legacy: Keep biodiversity for backward compatibility
                "biodiversity": {
                    "unique_species": biodiversity_data.get("unique_species", 0),
                    "total_observations": biodiversity_data.get("total_observations", 0),
                    "species_list": list(biodiversity_data.get("species", {}).keys()),
                    "observer_count": len(biodiversity_data.get("observers", {})),
                    "last_updated": biodiversity_data.get("last_updated", datetime.utcnow().isoformat()),
                    "biodiversity_score": self._calculate_biodiversity_score_from_data(biodiversity_data)
                }
            }
            
            # Save local copy
            ore_metadata_file = os.path.join(umappath, "ore_metadata.json")
            with open(ore_metadata_file, 'w') as f:
                json.dump(ore_metadata, f, indent=2)
            
            print(f"✅ ORE metadata saved: {ore_metadata_file}")
            
            # Publish DID with biodiversity data to Nostr (kind 30800)
            if lat and lon:
                self._publish_umap_did_with_biodiversity(lat, lon, umap_did, ore_metadata, umappath)
            
        except Exception as e:
            print(f"❌ Error updating UMAP DID with ORE: {e}")
    
    def _calculate_biodiversity_score_from_data(self, data: Dict[str, Any]) -> float:
        """Calculate biodiversity score from biodiversity data."""
        unique_species = data.get("unique_species", 0)
        total_observations = data.get("total_observations", 0)
        observer_count = len(data.get("observers", {}))
        
        species_score = min(unique_species * 2, 70)
        observation_score = min(total_observations * 0.5, 20)
        observer_score = min(observer_count * 2, 10)
        
        return min((species_score + observation_score + observer_score) / 100.0, 1.0)
    
    def _publish_umap_did_with_biodiversity(self, lat: str, lon: str, umap_did: str, ore_metadata: Dict[str, Any], umappath: str) -> None:
        """Publish UMAP DID with biodiversity data to Nostr (kind 30800).
        
        This attaches ore_biodiversity.json content directly to the DID document
        following DID_IMPLEMENTATION.md specifications for UMAP DIDs.
        """
        try:
            # Generate UMAP keys
            umap_nsec_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}" -s'
            umap_nsec = subprocess.check_output(umap_nsec_cmd, shell=True, text=True).strip()
            
            umap_hex_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}" | xargs {os.path.expanduser("~")}/.zen/Astroport.ONE/tools/nostr2hex.py'
            umap_hex = subprocess.check_output(umap_hex_cmd, shell=True, text=True).strip()
            
            # Create temporary keyfile
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', suffix='.nostr', delete=False) as f:
                f.write(f"NSEC={umap_nsec};\n")
                keyfile_path = f.name
            
            # Create DID document with biodiversity data
            did_document = {
                "@context": ["https://www.w3.org/ns/did/v1", "https://uplanet.copylaradio.com/did/ore/v1"],
                "id": umap_did,
                "type": "UMAP",
                "geographicContext": {
                    "latitude": lat,
                    "longitude": lon,
                    "precision": "0.01"
                },
                "verificationMethod": [
                    {
                        "id": f"{umap_did}#key-1",
                        "type": "Ed25519VerificationKey2020",
                        "controller": umap_did,
                        "publicKeyHex": umap_hex
                    }
                ],
                "authentication": [f"{umap_did}#key-1"],
                "service": [
                    {
                        "id": f"{umap_did}#nostr-relay",
                        "type": "NostrRelay",
                        "serviceEndpoint": self.my_relay
                    }
                ],
                "metadata": {
                    "ore": ore_metadata,
                    "updated": datetime.utcnow().isoformat()
                }
            }
            
            # Prepare content and tags for kind 30800 (DID document - NIP-101)
            did_content = json.dumps(did_document, indent=2)
            
            # Build tags with extended diversity information
            tags = [
                ["d", "did"],  # Required for parameterized replaceable event
                ["g", f"{lat},{lon}"],
                ["t", "UMAP"],
                ["t", "DID"],
                ["t", "ORE"],
                ["t", "UPlanet"],
                ["t", "inventory"],  # Mark as having inventory data
                # Extended diversity score (from all inventory types)
                ["diversity_score", str(ore_metadata.get("diversity", {}).get("diversity_score", 0.0))],
                # Legacy biodiversity score for backward compatibility
                ["biodiversity_score", str(ore_metadata.get("biodiversity", {}).get("biodiversity_score", 0.0))],
                ["species_count", str(ore_metadata.get("biodiversity", {}).get("unique_species", 0))],
                ["compliance_score", str(ore_metadata.get("compliance_score", 0.0))],
                ["total_observations", str(ore_metadata.get("diversity", {}).get("total_observations", 0))]
            ]
            
            # Add inventory type counts as tags (from plantnet.html inventory types)
            inventory_summary = ore_metadata.get("diversity", {}).get("inventory_summary", {})
            for inv_type, inv_data in inventory_summary.items():
                count = inv_data.get("count", 0)
                if count > 0:
                    tags.append([f"inventory_{inv_type}", str(count)])
            
            tags_json = json.dumps(tags)
            
            # Path to nostr_send_note.py
            nostr_send_script = os.path.join(os.path.dirname(__file__), "nostr_send_note.py")
            
            print(f"📡 Publishing UMAP DID with biodiversity to Nostr (kind 30800) for ({lat}, {lon})")
            
            result = subprocess.run([
                "python3", nostr_send_script,
                "--keyfile", keyfile_path,
                "--content", did_content,
                "--kind", "30800",
                "--tags", tags_json,
                "--relays", self.my_relay,
                "--json"
            ], capture_output=True, text=True, timeout=60)
            
            # Clean up temporary keyfile
            os.unlink(keyfile_path)
            
            if result.returncode == 0:
                result_data = json.loads(result.stdout)
                if result_data.get("success"):
                    print(f"✅ UMAP DID with diversity data (kind 30800) published successfully")
                    print(f"   Event ID: {result_data.get('event_id')}")
                    print(f"   Diversity score: {ore_metadata.get('diversity', {}).get('diversity_score', 0.0):.2f}")
                    print(f"   Species count: {ore_metadata.get('biodiversity', {}).get('unique_species', 0)}")
                    inv_summary = ore_metadata.get('diversity', {}).get('inventory_summary', {})
                    for inv_type, inv_data in inv_summary.items():
                        if inv_data.get('count', 0) > 0:
                            print(f"   📦 {inv_type}: {inv_data.get('count', 0)} items")
                else:
                    print(f"⚠️  UMAP DID publication had issues: {result_data.get('errors', [])}")
            else:
                print(f"❌ Failed to publish UMAP DID: {result.stderr}")
                
        except Exception as e:
            print(f"❌ Error publishing UMAP DID with biodiversity: {e}")

    def _get_biodiversity_stats(self, lat: str, lon: str) -> Dict[str, Any]:
        """Get biodiversity statistics for a UMAP from NOSTR events.
        
        Queries NOSTR for plant observations (kind 1 with #plantnet and #UPlanet tags)
        to calculate real-time biodiversity statistics.
        
        Args:
            lat: Latitude
            lon: Longitude
            
        Returns:
            Dictionary with biodiversity statistics
        """
        try:
            umapKey = f"{lat},{lon}"
            print(f"🔍 Fetching biodiversity stats from NOSTR for UMAP {umapKey}")
            
            # Path to nostr_get_events.sh
            nostr_get_events_script = os.path.join(os.path.dirname(__file__), "nostr_get_events.sh")
            
            if not os.path.exists(nostr_get_events_script):
                print(f"⚠️  nostr_get_events.sh not found at {nostr_get_events_script}")
                return self._get_fallback_stats()
            
            # Query NOSTR for plant observations in this UMAP
            # Use nostr_get_events.sh with filters for PlantNet tags and geolocation
            # Filter by tags: plantnet AND UPlanet (comma-separated for OR logic in NOSTR)
            # Note: NOSTR #t filter with multiple values returns events with ANY of the tags
            # We still need to verify both tags are present in the result
            umapKey = f"{lat},{lon}"
            result = subprocess.run([
                nostr_get_events_script,
                "--kind", "1",
                "--tag-t", "plantnet,UPlanet",  # Filter by hashtags (OR logic in NOSTR)
                "--tag-g", umapKey,              # Filter by geolocation (UMAP coordinates)
                "--limit", "500"
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                print(f"⚠️  Error querying NOSTR: {result.stderr}")
                return self._get_fallback_stats()
            
            # Parse NOSTR events (one JSON per line)
            events = []
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    try:
                        event = json.loads(line)
                        events.append(event)
                    except json.JSONDecodeError:
                        continue
            
            # Filter events: must have BOTH #plantnet and #UPlanet tags
            # (NOSTR #t filter with multiple values returns events with ANY tag, so we verify both)
            umap_observations = []
            for event in events:
                # Extract all tag values
                tag_values = [tag[1] for tag in event.get('tags', []) if len(tag) > 1]
                
                # Verify event has BOTH plantnet and UPlanet tags
                if 'plantnet' not in tag_values or 'UPlanet' not in tag_values:
                    continue
                
                # Geolocation already filtered by nostr_get_events.sh --tag-g
                # But verify it matches the UMAP (0.01° precision)
                geo_tag = next((tag for tag in event.get('tags', []) if tag[0] == 'g'), None)
                if geo_tag and len(geo_tag) > 1:
                    coords = geo_tag[1].split(',')
                    if len(coords) == 2:
                        try:
                            event_lat = float(coords[0])
                            event_lon = float(coords[1])
                            # Check if in same UMAP (0.01° precision)
                            event_umap = f"{event_lat:.2f},{event_lon:.2f}"
                            if event_umap == umapKey:
                                umap_observations.append(event)
                        except ValueError:
                            continue
            
            print(f"📊 Found {len(umap_observations)} plant observations in UMAP {umapKey}")
            
            # Calculate statistics from NOSTR events
            unique_species = set()
            unique_observers = set()
            
            for event in umap_observations:
                # Extract observer pubkey
                unique_observers.add(event.get('pubkey'))
                
                # Try to extract species from content
                content = event.get('content', '')
                # Look for species in content (format: "Species: Scientific Name")
                species_match = re.search(r'(?:Species|Espèce)[:\s]+([^\n]+)', content, re.IGNORECASE)
                if species_match:
                    species_name = species_match.group(1).strip()
                    if species_name:
                        unique_species.add(species_name)
            
            plants_count = len(umap_observations)
            species_count = len(unique_species)
            observer_count = len(unique_observers)
            
            # Calculate compliance score based on biodiversity
            # Score = (unique_species * 0.02) + (total_observations * 0.01)
            # Capped at 1.0
            compliance_score = min(
                (species_count * 0.02) + (plants_count * 0.01),
                1.0
            )
            
            # Calculate reward potential
            # Base: 0.5 Ẑen per observation
            # Species bonus: 1.5 Ẑen per species
            # Observer bonus: 2.0 Ẑen per observer
            reward_potential = (
                (plants_count * 0.5) +
                (species_count * 1.5) +
                (observer_count * 2.0)
            )
            
            # Active contract multiplier (if exists)
            if compliance_score > 0.7:
                reward_potential *= 1.5
            
            stats = {
                "plants_count": plants_count,
                "species_count": species_count,
                "observer_count": observer_count,
                "compliance_score": round(compliance_score, 2),
                "reward_potential": round(reward_potential, 2)
            }
            
            print(f"✅ Biodiversity stats for UMAP {umapKey}: {stats}")
            return stats
            
        except subprocess.TimeoutExpired:
            print(f"⚠️  Timeout querying NOSTR for biodiversity stats")
            return self._get_fallback_stats()
        except Exception as e:
            print(f"⚠️  Error getting biodiversity stats from NOSTR: {e}")
            import traceback
            traceback.print_exc()
            return self._get_fallback_stats()
    
    def _get_fallback_stats(self) -> Dict[str, Any]:
        """Return fallback statistics when NOSTR query fails.
        
        Returns:
            Dictionary with zero statistics
        """
        return {
            "plants_count": 0,
            "species_count": 0,
            "observer_count": 0,
            "compliance_score": 0.0,
            "reward_potential": 0.0
        }
    
    def _publish_ore_status_to_nostr(self, lat: str, lon: str, keyfile_path: str, umap_did: str) -> None:
        """Publish ORE status to Nostr with ORE Meeting Space event (kind 30312).
        
        Args:
            lat: Latitude
            lon: Longitude
            keyfile_path: Path to .secret.nostr file for signing
            umap_did: DID of the UMAP
        """
        try:
            # Generate UMAP hex key for room name
            umap_npub_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}"'
            umap_npub = subprocess.check_output(umap_npub_cmd, shell=True, text=True).strip()
            umap_hex_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/nostr2hex.py "{umap_npub}"'
            umap_hex = subprocess.check_output(umap_hex_cmd, shell=True, text=True).strip()
            
            # Create ORE Meeting Space event (kind 30312 - Persistent Geographic Space)
            room_name = f"UMAP_ORE_{lat}_{lon}"
            room_description = "UPlanet ORE Environmental Space - Geographic cell with environmental obligations"
            vdo_room_url = f"{self.vdo_ninja}/?room={umap_hex[:8]}&effects&record"
            
            # Prepare event content
            ore_status_msg = f"""🌱 ORE Mode Activated - UMAP ({lat}, {lon})

📍 Geographic Cell: {lat}, {lon}
🆔 DID: {umap_did}
🎥 Meeting Room: {room_name}
🔗 VDO.ninja: {vdo_room_url}

Environmental obligations are now tracked via UPlanet ORE system.
Join the meeting space to collaborate on ecological verification.

#UPlanet #ORE #Environment #Biodiversity"""
            
            # Get biodiversity statistics for this UMAP
            biodiversity_stats = self._get_biodiversity_stats(lat, lon)
            
            # Prepare tags for kind 30312 (replaceable event with 'd' tag)
            # CRITICAL: Use canonical JSON (RFC 8785) for signature consistency
            tags_json = canonicalize_json([
                ["d", f"ore-space-{lat}-{lon}"],  # Unique identifier for replaceable event
                ["g", f"{lat},{lon}"],  # Geolocation tag
                ["t", "ORE"],
                ["t", "UPlanet"],
                ["t", "Environment"],
                ["room", room_name],
                ["vdo_url", vdo_room_url],
                ["did", umap_did],
                ["uplanet_authority", self.uplanet_g1_pub[:16]],
                ["plants", str(biodiversity_stats.get("plants_count", 0))],
                ["species", str(biodiversity_stats.get("species_count", 0))],
                ["observers", str(biodiversity_stats.get("observer_count", 0))],
                ["compliance_score", str(biodiversity_stats.get("compliance_score", 0.0))],
                ["ore_reward", str(biodiversity_stats.get("reward_potential", 0.0))]
            ])
            
            # Path to nostr_send_note.py
            nostr_send_script = os.path.join(os.path.dirname(__file__), "nostr_send_note.py")
            
            # Publish using nostr_send_note.py
            print(f"📡 Publishing ORE Meeting Space event (kind 30312) for UMAP ({lat}, {lon})")
            
            result = subprocess.run([
                "python3", nostr_send_script,
                "--keyfile", keyfile_path,
                "--content", ore_status_msg,
                "--kind", "30312",
                "--tags", tags_json,
                "--relays", self.my_relay,
                "--json"
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                result_data = json.loads(result.stdout)
                if result_data.get("success"):
                    print(f"✅ ORE Meeting Space event (kind 30312) published successfully")
                    print(f"   Event ID: {result_data.get('event_id')}")
                    print(f"   Published to: {result_data.get('relays_success')}/{result_data.get('relays_total')} relay(s)")
                else:
                    print(f"⚠️  ORE Meeting Space event publication had issues")
                    print(f"   Errors: {result_data.get('errors', [])}")
            else:
                print(f"❌ Failed to publish ORE Meeting Space event")
                print(f"   stderr: {result.stderr}")
            
        except subprocess.TimeoutExpired:
            print(f"❌ Timeout publishing ORE status to Nostr")
        except Exception as e:
            print(f"❌ Error publishing ORE status to Nostr: {e}")

    def _create_ore_verification_meeting(self, lat: str, lon: str, keyfile_path: str, meeting_title: str, meeting_description: str, starts_timestamp: int) -> Optional[str]:
        """Create ORE verification meeting event (kind 30313).
        
        Args:
            lat: Latitude
            lon: Longitude
            keyfile_path: Path to .secret.nostr file for signing
            meeting_title: Title of the meeting
            meeting_description: Description of the meeting
            starts_timestamp: Start time (Unix timestamp)
            
        Returns:
            Meeting event ID if successful, None otherwise
        """
        try:
            # Generate UMAP hex key for room reference
            umap_npub_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}"'
            umap_npub = subprocess.check_output(umap_npub_cmd, shell=True, text=True).strip()
            umap_hex_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/nostr2hex.py "{umap_npub}"'
            umap_hex = subprocess.check_output(umap_hex_cmd, shell=True, text=True).strip()
            
            # Create meeting event (kind 30313)
            meeting_id = f"ore-verification-{lat}-{lon}-{int(time.time())}"
            room_a_tag = f"30312:{umap_hex[:8]}:ore-space-{lat}-{lon}"
            
            # Format meeting content
            meeting_content = f"""{meeting_title}

{meeting_description}

📅 Scheduled: {datetime.fromtimestamp(starts_timestamp).strftime('%Y-%m-%d %H:%M:%S')} UTC
📍 Location: UMAP ({lat}, {lon})
🎥 Join via ORE Meeting Space (kind 30312)

This verification meeting is part of the UPlanet ORE system for ecological real obligations tracking.

#ORE #UPlanet #EnvironmentalVerification"""
            
            # Prepare tags for kind 30313
            # CRITICAL: Use canonical JSON (RFC 8785) for signature consistency
            tags_json = canonicalize_json([
                ["d", meeting_id],  # Unique identifier
                ["a", room_a_tag],  # Reference to meeting space (kind 30312)
                ["g", f"{lat},{lon}"],  # Geolocation
                ["t", "ORE"],
                ["t", "UPlanet"],
                ["t", "Verification"],
                ["title", meeting_title],
                ["start", str(starts_timestamp)],
                ["meeting_type", "environmental_verification"]
            ])
            
            # Path to nostr_send_note.py
            nostr_send_script = os.path.join(os.path.dirname(__file__), "nostr_send_note.py")
            
            # Publish using nostr_send_note.py
            print(f"📅 Creating ORE verification meeting event (kind 30313): {meeting_id}")
            
            result = subprocess.run([
                "python3", nostr_send_script,
                "--keyfile", keyfile_path,
                "--content", meeting_content,
                "--kind", "30313",
                "--tags", tags_json,
                "--relays", self.my_relay,
                "--json"
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                result_data = json.loads(result.stdout)
                if result_data.get("success"):
                    event_id = result_data.get("event_id")
                    print(f"✅ ORE verification meeting event (kind 30313) created successfully")
                    print(f"   Event ID: {event_id}")
                    print(f"   Meeting ID: {meeting_id}")
                    print(f"   Published to: {result_data.get('relays_success')}/{result_data.get('relays_total')} relay(s)")
                    return event_id
                else:
                    print(f"⚠️  ORE verification meeting publication had issues")
                    print(f"   Errors: {result_data.get('errors', [])}")
                    return None
            else:
                print(f"❌ Failed to create ORE verification meeting")
                print(f"   stderr: {result.stderr}")
                return None
            
        except subprocess.TimeoutExpired:
            print(f"❌ Timeout creating ORE verification meeting")
            return None
        except Exception as e:
            print(f"❌ Error creating ORE verification meeting: {e}")
            return None

def main():
    """Main function for ORE system operations."""
    if len(sys.argv) < 2:
        print("Usage: python3 ore_system.py <action> [options]")
        print("Actions:")
        print("  verify <lat> <lon>")
        print("  reward <lat> <lon>")
        print("  generate_did <lat> <lon>")
        print("  activate_ore <lat> <lon>  # UMAP keys generated dynamically")
        print("  check_ore <lat> <lon>")
        print("  add_plant <lat> <lon> <species_name> <scientific_name> <observer_pubkey> <confidence> [image_url] [event_id]")
        print("  check_plant <lat> <lon> <scientific_name>")
        print("  biodiversity_summary <lat> <lon>")
        sys.exit(1)
    
    action = sys.argv[1]
    
    # Handle plant observation actions (different parameter structure)
    if action == "add_plant":
        if len(sys.argv) < 7:
            print("Usage: python3 ore_system.py add_plant <lat> <lon> <species_name> <scientific_name> <observer_pubkey> <confidence> [image_url] [event_id]")
            sys.exit(1)
        
        lat = sys.argv[2]
        lon = sys.argv[3]
        species_name = sys.argv[4]
        scientific_name = sys.argv[5]
        observer_pubkey = sys.argv[6]
        confidence = float(sys.argv[7])
        image_url = sys.argv[8] if len(sys.argv) > 8 else ""
        event_id = sys.argv[9] if len(sys.argv) > 9 else ""
        
        # Calculate UMAP path
        ipfs_node_id = os.environ.get("IPFSNODEID", "default_node")
        rlat = lat.split('.')[0]
        rlon = lon.split('.')[0]
        slat = lat[:len(lat)-1]
        slon = lon[:len(lon)-1]
        umap_path = f"{os.path.expanduser('~')}/.zen/tmp/{ipfs_node_id}/UPLANET/__/_{rlat}_{rlon}/_{slat}_{slon}/_{lat}_{lon}"
        
        tracker = OREBiodiversityTracker(umap_path)
        result = tracker.add_plant_observation(species_name, scientific_name, observer_pubkey, confidence, image_url, event_id)
        print(json.dumps(result, indent=2))
        return
    
    elif action == "check_plant":
        if len(sys.argv) < 5:
            print("Usage: python3 ore_system.py check_plant <lat> <lon> <scientific_name>")
            sys.exit(1)
        
        lat = sys.argv[2]
        lon = sys.argv[3]
        scientific_name = sys.argv[4]
        
        # Calculate UMAP path
        ipfs_node_id = os.environ.get("IPFSNODEID", "default_node")
        rlat = lat.split('.')[0]
        rlon = lon.split('.')[0]
        slat = lat[:len(lat)-1]
        slon = lon[:len(lon)-1]
        umap_path = f"{os.path.expanduser('~')}/.zen/tmp/{ipfs_node_id}/UPLANET/__/_{rlat}_{rlon}/_{slat}_{slon}/_{lat}_{lon}"
        
        tracker = OREBiodiversityTracker(umap_path)
        result = tracker.check_if_species_exists(scientific_name)
        print(json.dumps(result, indent=2))
        return
    
    elif action == "biodiversity_summary":
        if len(sys.argv) < 4:
            print("Usage: python3 ore_system.py biodiversity_summary <lat> <lon>")
            sys.exit(1)
        
        lat = sys.argv[2]
        lon = sys.argv[3]
        
        # Calculate UMAP path
        ipfs_node_id = os.environ.get("IPFSNODEID", "default_node")
        rlat = lat.split('.')[0]
        rlon = lon.split('.')[0]
        slat = lat[:len(lat)-1]
        slon = lon[:len(lon)-1]
        umap_path = f"{os.path.expanduser('~')}/.zen/tmp/{ipfs_node_id}/UPLANET/__/_{rlat}_{rlon}/_{slat}_{slon}/_{lat}_{lon}"
        
        tracker = OREBiodiversityTracker(umap_path)
        result = tracker.get_biodiversity_summary()
        print(json.dumps(result, indent=2))
        return
    
    # Get all images for a UMAP
    if action == "get_images":
        if len(sys.argv) < 4:
            print("Usage: python3 ore_system.py get_images <lat> <lon>")
            sys.exit(1)
        
        lat = sys.argv[2]
        lon = sys.argv[3]
        umap_path = os.path.expanduser(f"~/.zen/game/nostr/UMAP_{lat}_{lon}")
        
        if not os.path.exists(umap_path):
            print(json.dumps({"error": "UMAP not found", "images": []}, indent=2))
            return
        
        tracker = OREBiodiversityTracker(umap_path)
        images = tracker.get_all_images()
        print(json.dumps({"images": images, "count": len(images)}, indent=2))
        return
    
    # Standard actions requiring lat/lon as 2nd and 3rd parameters
    if len(sys.argv) < 4:
        print("Usage: python3 ore_system.py <action> <lat> <lon> [options]")
        print("Actions: verify, reward, generate_did, activate_ore, check_ore")
        sys.exit(1)
    
    lat = sys.argv[2]
    lon = sys.argv[3]
    
    if action == "generate_did":
        # Use UPLANETNAME_G1 for Zen usage (Banque centrale G1/Ẑ)
        uplanet_name_g1 = os.environ.get("UPLANETNAME_G1", "UPlanetZen")
        generator = OREUMAPDIDGenerator(uplanet_name_g1)
        did, did_doc, nsec, npub, hex_key, g1pub = generator.generate_umap_did(lat, lon)
        print(f"DID: {did}")
        print(f"NSEC: {nsec}")
        print(f"NPUB: {npub}")
        print(f"HEX: {hex_key}")
        print(f"G1PUB: {g1pub}")
        print("DID Document:")
        print(json.dumps(did_doc, indent=2))
    
    elif action == "verify":
        # Example verification
        uplanet_name_g1 = os.environ.get("UPLANETNAME_G1", "UPlanetZen")
        generator = OREUMAPDIDGenerator(uplanet_name_g1)
        did, did_doc, _, _, _, _ = generator.generate_umap_did(lat, lon)
        
        # Mock ORE credential
        ore_credential = {
            "credentialSubject": {
                "ecologicalObligations": [
                    {"description": "Maintain 80% forest cover", "targetValue": 80, "metric": "%", "verificationMethod": "satellite_imagery"},
                    {"description": "No pesticide use", "targetValue": "none", "metric": "status", "verificationMethod": "iot_sensors"},
                    {"description": "Protect local biodiversity", "targetValue": "active", "metric": "status", "verificationMethod": "human_audit"}
                ]
            }
        }
        
        verifier = OREVerificationSystem()
        is_compliant, details = verifier.verify_ore_compliance(did_doc, ore_credential)
        print(f"Compliance: {is_compliant}")
        print(f"Details: {json.dumps(details, indent=2)}")
    
    elif action == "reward":
        # Example reward calculation
        uplanet_name_g1 = os.environ.get("UPLANETNAME_G1", "UPlanetZen")
        generator = OREUMAPDIDGenerator(uplanet_name_g1)
        did, did_doc, _, _, _, _ = generator.generate_umap_did(lat, lon)
        
        compliance_report = {
            "compliance_status": "compliant",
            "obligations_checked": [
                {"obligation": "Maintain 80% forest cover", "status": "compliant"},
                {"obligation": "No pesticide use", "status": "compliant"},
                {"obligation": "Protect local biodiversity", "status": "compliant"}
            ]
        }
        
        economic_system = OREEconomicSystem()
        rewards = economic_system.calculate_compliance_reward(did_doc, compliance_report)
        print(f"Rewards: {json.dumps(rewards, indent=2)}")
        economic_system.distribute_rewards(did_doc, rewards)
    
    elif action == "activate_ore":
        # Activate ORE mode for UMAP (UMAP keys are generated dynamically)
        if len(sys.argv) < 4:
            print("Usage: python3 ore_system.py activate_ore <lat> <lon> <umappath>")
            sys.exit(1)
        
        lat = sys.argv[2]
        lon = sys.argv[3]
        umappath = sys.argv[4] if len(sys.argv) > 4 else f"/tmp/umap_{lat}_{lon}"
        
        config = {
            "ipfs_node_id": os.environ.get("IPFSNODEID", "default_node"),  # Astroport.ONE local relay address
            "uplanet_g1_pub": os.environ.get("UPLANETNAME_G1", "default_pub"),  # Use UPLANETNAME_G1 for Zen usage (Banque centrale G1/Ẑ)
            "my_relay": os.environ.get("myRELAY", "wss://relay.copylaradio.com"),
            "my_ipfs": os.environ.get("myIPFS", "https://ipfs.copylaradio.com"),
            "vdo_ninja": os.environ.get("VDONINJA", "https://vdo.ninja"),
            "pic_profile": os.environ.get("PIC_PROFILE", "")
        }
        
        manager = OREUMAPManager(config)
        
        if manager.should_activate_ore_mode(lat, lon, umappath):
            success = manager.activate_ore_mode(lat, lon, umappath)
            print(f"ORE activation: {'✅ Success' if success else '❌ Failed'}")
        else:
            print("ℹ️  UMAP does not qualify for ORE mode")
    
    elif action == "check_ore":
        # Check if UMAP should activate ORE mode
        config = {
            "ipfs_node_id": os.environ.get("IPFSNODEID", "default_node"),  # Astroport.ONE local relay address
            "uplanet_g1_pub": os.environ.get("UPLANETNAME_G1", "default_pub"),  # Use UPLANETNAME_G1 for Zen usage (Banque centrale G1/Ẑ)
            "my_relay": os.environ.get("myRELAY", "wss://relay.copylaradio.com"),
            "my_ipfs": os.environ.get("myIPFS", "https://ipfs.copylaradio.com"),
            "vdo_ninja": os.environ.get("VDONINJA", "https://vdo.ninja"),
            "pic_profile": os.environ.get("PIC_PROFILE", "")
        }
        
        manager = OREUMAPManager(config)
        umappath = f"/tmp/umap_{lat}_{lon}"  # Mock path
        
        should_activate = manager.should_activate_ore_mode(lat, lon, umappath)
        print(f"Should activate ORE mode: {'✅ Yes' if should_activate else '❌ No'}")
        
        # Also check environmental score
        env_score = manager._calculate_environmental_score(lat, lon)
        print(f"Environmental score: {env_score:.2f}")
        
        # Check for MULTIPASS users
        has_multipass = manager.search_multipass_in_swarm(lat, lon, "umap_zone")
        print(f"Has MULTIPASS users: {'✅ Yes' if has_multipass else '❌ No'}")

if __name__ == "__main__":
    main()
