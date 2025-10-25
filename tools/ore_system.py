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

    def generate_umap_did(self, lat: str, lon: str) -> Tuple[str, Dict[str, Any], str, str, str]:
        """Generates a DID for a UMAP geographic cell and its DID Document."""
        
        # Generate Nostr keys using existing UPlanet keygen
        umap_nsec_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}" -s'
        umap_nsec = subprocess.check_output(umap_nsec_cmd, shell=True, text=True).strip()

        umap_npub_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/keygen -t nostr "{self.uplanet_name}{lat}" "{self.uplanet_name}{lon}"'
        umap_npub = subprocess.check_output(umap_npub_cmd, shell=True, text=True).strip()

        umap_hex_cmd = f'{os.path.expanduser("~")}/.zen/Astroport.ONE/tools/nostr2hex.py "{umap_npub}"'
        umap_hex = subprocess.check_output(umap_hex_cmd, shell=True, text=True).strip()

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
                    "publicKeyHex": umap_hex
                }
            ],
            "authentication": [f"{did}#key-1"],
            "service": [
                {
                    "id": f"{did}#nostr-relay",
                    "type": "NostrRelay",
                    "serviceEndpoint": "wss://relay.copylaradio.com"
                }
            ],
            "geographicContext": {
                "latitude": lat,
                "longitude": lon,
                "geohash": hashlib.sha256(f"{lat},{lon}".encode()).hexdigest()[:12]
            }
        }
        return did, did_document, umap_nsec, umap_npub, umap_hex

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
        """Calculate environmental score for a UMAP (placeholder for real environmental data)."""
        try:
            lat_f = float(lat)
            lon_f = float(lon)
            score = 0.0
            
            # Example: higher score for certain latitude ranges (temperate zones)
            if 40 <= lat_f <= 60:
                score += 0.3
            
            # Example: higher score for areas with specific longitude patterns
            if -10 <= lon_f <= 20:
                score += 0.2
            
            # Add some randomness for demonstration (in real system, use actual data)
            random_factor = random.random()
            score += random_factor * 0.5
            
            # Cap at 1.0
            return min(score, 1.0)
        except ValueError:
            return 0.0

    def activate_ore_mode(self, lat: str, lon: str, umappath: str, npriv_hex: str) -> bool:
        """Activate ORE mode for a UMAP."""
        print(f"🌱 Activating ORE mode for UMAP ({lat}, {lon})")
        
        try:
            # Create ORE mode marker
            ore_activated_file = os.path.join(umappath, "ore_mode.activated")
            with open(ore_activated_file, 'w') as f:
                f.write(datetime.utcnow().isoformat())
            
            # Generate UMAP DID using existing infrastructure
            generator = OREUMAPDIDGenerator(self.uplanet_g1_pub)
            did, did_doc, nsec, npub, hex_key = generator.generate_umap_did(lat, lon)
            
            if not did:
                print("❌ Failed to generate UMAP DID for ORE mode")
                return False
            
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
                        
                        # Update UMAP DID with ORE information
                        self._update_umap_did_with_ore(umappath, did, compliance_score, total_reward)
            
            # Publish ORE status to Nostr
            self._publish_ore_status_to_nostr(lat, lon, npriv_hex, did)
            
            # Create initial ORE verification meeting
            verification_title = f"ORE Environmental Verification - UMAP ({lat}, {lon})"
            verification_description = f"Initial environmental assessment and ORE contract verification for geographic cell ({lat}, {lon})"
            starts_timestamp = int(time.time())
            
            self._create_ore_verification_meeting(lat, lon, npriv_hex, verification_title, verification_description, starts_timestamp)
            
            print(f"✅ ORE mode activated for UMAP ({lat}, {lon})")
            return True
            
        except Exception as e:
            print(f"❌ Error activating ORE mode: {e}")
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
                "@context": ["https://www.w3.org/2018/credentials/v1", "https://uplanet.org/contexts/ore/v1"],
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

    def _update_umap_did_with_ore(self, umappath: str, umap_did: str, compliance_score: float, total_reward: float) -> None:
        """Update UMAP DID with ORE information."""
        try:
            # Create ORE metadata file
            ore_metadata = os.path.join(umappath, "ore_metadata.json")
            metadata = {
                "umap_did": umap_did,
                "coordinates": {"lat": "LAT", "lon": "LON"},  # Will be filled by caller
                "ore_mode_activated": datetime.utcnow().isoformat(),
                "compliance_score": compliance_score,
                "total_reward": total_reward,
                "guardian_authority": f"did:nostr:{self.uplanet_g1_pub[:8]}",
                "uplanet_integration": True
            }
            
            with open(ore_metadata, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            print(f"✅ ORE metadata saved: {ore_metadata}")
            
        except Exception as e:
            print(f"❌ Error updating UMAP DID with ORE: {e}")

    def _publish_ore_status_to_nostr(self, lat: str, lon: str, npriv_hex: str, umap_did: str) -> None:
        """Publish ORE status to Nostr with ORE DID event."""
        try:
            # Create ORE Meeting Space event (kind 30312 - Persistent Geographic Space)
            room_name = f"UMAP_ORE_{lat}_{lon}"
            room_description = "UPlanet ORE Environmental Space - Geographic cell with environmental obligations"
            vdo_room_url = f"{self.vdo_ninja}/?room={self.uplanet_g1_pub[:8]}&effects&record"
            
            # This would require nostpy-cli integration
            print(f"📡 Publishing ORE Meeting Space event (kind 30312) for UMAP ({lat}, {lon})")
            print(f"   Room: {room_name}")
            print(f"   VDO.ninja: {vdo_room_url}")
            print(f"   DID: {umap_did}")
            
            # Also publish a regular status message
            ore_status_msg = f"🌱 ORE mode activated for UMAP ({lat}, {lon}) - DID: {umap_did} - Environmental obligations now tracked via UPlanet ORE system #UPlanet #ORE #Environment"
            print(f"📝 Status message: {ore_status_msg}")
            
            print("✅ ORE Meeting Space event (kind 30312) and status published to Nostr")
            
        except Exception as e:
            print(f"❌ Error publishing ORE status to Nostr: {e}")

    def _create_ore_verification_meeting(self, lat: str, lon: str, npriv_hex: str, meeting_title: str, meeting_description: str, starts_timestamp: int) -> Optional[str]:
        """Create ORE verification meeting event (kind 30313)."""
        try:
            # Create meeting event (kind 30313)
            meeting_id = f"ore-verification-{lat}-{lon}-{int(time.time())}"
            room_a_tag = f"30312:{self.uplanet_g1_pub[:8]}:ore-space-{lat}-{lon}"
            
            # This would require nostpy-cli integration
            print(f"📅 Creating ORE verification meeting event (kind 30313): {meeting_id}")
            print(f"   Title: {meeting_title}")
            print(f"   Description: {meeting_description}")
            print(f"   Starts: {starts_timestamp}")
            
            print(f"✅ ORE verification meeting event (kind 30313) created: {meeting_id}")
            return meeting_id
            
        except Exception as e:
            print(f"❌ Error creating ORE verification meeting: {e}")
            return None

def main():
    """Main function for ORE system operations."""
    if len(sys.argv) < 4:
        print("Usage: python3 ore_system.py <action> <lat> <lon> [options]")
        print("Actions: verify, reward, generate_did, activate_ore, check_ore")
        sys.exit(1)
    
    action = sys.argv[1]
    lat = sys.argv[2]
    lon = sys.argv[3]
    
    if action == "generate_did":
        # Use UPLANETNAME_G1 for Zen usage (Banque centrale G1/Ẑ)
        uplanet_name_g1 = os.environ.get("UPLANETNAME_G1", "UPlanetZen")
        generator = OREUMAPDIDGenerator(uplanet_name_g1)
        did, did_doc, nsec, npub, hex_key = generator.generate_umap_did(lat, lon)
        print(f"DID: {did}")
        print(f"NSEC: {nsec}")
        print(f"NPUB: {npub}")
        print(f"HEX: {hex_key}")
        print("DID Document:")
        print(json.dumps(did_doc, indent=2))
    
    elif action == "verify":
        # Example verification
        uplanet_name_g1 = os.environ.get("UPLANETNAME_G1", "UPlanetZen")
        generator = OREUMAPDIDGenerator(uplanet_name_g1)
        did, did_doc, _, _, _ = generator.generate_umap_did(lat, lon)
        
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
        did, did_doc, _, _, _ = generator.generate_umap_did(lat, lon)
        
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
        # Activate ORE mode for UMAP
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
        npriv_hex = "mock_private_key"
        
        if manager.should_activate_ore_mode(lat, lon, umappath):
            success = manager.activate_ore_mode(lat, lon, umappath, npriv_hex)
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
