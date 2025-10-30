# 🔐 Oracle System - Multi-Signature Permit Management

## Overview

The Oracle System is a decentralized permit/license management system based on the **Web of Trust (WoT)** model described in the [CopyLaRadio article](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#). It enables the issuance of **Verifiable Credentials** for competencies, licenses, and authorities within the UPlanet ecosystem.

## 🎯 Concept

The Oracle System transforms traditional licensing from centralized authorities to **peer-validated certification**:

- **Permit Request**: An applicant publicly requests a permit (e.g., "Driver's License", "ORE Verifier")
- **Peer Attestation**: Certified experts attest the applicant's competence (multi-signature validation)
- **Credential Issuance**: Once enough attestations are collected, a Verifiable Credential (VC) is issued
- **Authority Signature**: The final VC is signed by the UPlanet authority (UPLANETNAME.G1 key)

## 🏗️ Architecture

### Components

1. **oracle_system.py** - Core permit management system
2. **54321.py API routes** - REST API for permit operations
3. **Helper scripts** - CLI tools for users and attesters
4. **NOSTR events** - Decentralized event publishing (kinds 30500-30503)
5. **DID integration** - Verifiable Credentials attached to DIDs

### NOSTR Event Kinds

| Kind  | Name | Description |
|-------|------|-------------|
| 30500 | Permit Definition | License type definition (e.g., "Driver's License") |
| 30501 | Permit Request | Application from a user |
| 30502 | Permit Attestation | Expert signature/attestation |
| 30503 | Permit Credential | Final Verifiable Credential (VC) |

### Data Flow

```
1. REQUEST
   User → oracle_system.py → NOSTR (kind 30501)
   
2. ATTESTATION (multiple)
   Expert → oracle_system.py → NOSTR (kind 30502)
   
3. VALIDATION
   oracle_system.py → Check attestations → Auto-issue if threshold reached
   
4. CREDENTIAL
   oracle_system.py → Sign with UPLANETNAME.G1 → NOSTR (kind 30503) → DID update
   
5. REWARD (optional, for WoT Dragon)
   UPLANET.official.sh -p email PERMIT_ID → Blockchain payment
```

## 📋 Available Permit Types

See `templates/NOSTR/permit_definitions.json` for full definitions:

1. **PERMIT_ORE_V1** - ORE Environmental Verifier (5 attestations, 3 years validity)
2. **PERMIT_DRIVER** - Driver's License WoT Model (12 attestations, 15 years validity)
3. **PERMIT_WOT_DRAGON** - UPlanet Authority (3 attestations, unlimited validity)
4. **PERMIT_MEDICAL_FIRST_AID** - First Aid Provider (8 attestations, 2 years validity)
5. **PERMIT_BUILDING_ARTISAN** - Building Artisan (10 attestations, 5 years validity)
6. **PERMIT_EDUCATOR_COMPAGNON** - Compagnon Educator (12 attestations, unlimited)
7. **PERMIT_FOOD_PRODUCER** - Local Food Producer (6 attestations, 3 years validity)
8. **PERMIT_MEDIATOR** - Community Mediator (15 attestations, 5 years validity)

## 🚀 Usage

### 1. Initialize Permit Definitions

```bash
cd Astroport.ONE/tools
./init_permit_definitions.sh
```

This loads all permit types from the JSON template into the system.

### 2. Request a Permit (as Applicant)

```bash
./request_license.sh EMAIL PERMIT_ID STATEMENT [EVIDENCE...]
```

**Example:**
```bash
./request_license.sh user@example.com PERMIT_ORE_V1 \
    "I have 5 years experience in environmental assessment and forest management"
```

This will:
- Submit a permit request to the API
- Publish a NOSTR event (kind 30501)
- Return a `REQUEST_ID` for tracking

### 3. Attest a Permit (as Expert)

```bash
./attest_license.sh EMAIL REQUEST_ID STATEMENT [LICENSE_ID]
```

**Example:**
```bash
./attest_license.sh expert@example.com a1b2c3d4 \
    "I have personally verified their competence in ORE verification"
```

This will:
- Verify you have the required license (if needed)
- Submit an attestation with your signature
- Publish a NOSTR event (kind 30502)
- Auto-issue the credential if enough attestations are collected

### 4. Check Permit Status

```bash
curl https://u.copylaradio.com/api/permit/status/REQUEST_ID | jq
```

**Example response:**
```json
{
  "request_id": "a1b2c3d4",
  "permit_type": "ORE Environmental Verifier",
  "applicant_npub": "npub1...",
  "status": "attesting",
  "attestations_count": 3,
  "required_attestations": 5,
  "attestations": [
    {
      "attester_npub": "npub1...",
      "statement": "Verified competence",
      "created_at": "2025-10-30T12:00:00Z"
    }
  ]
}
```

### 5. List Permits

```bash
# List all requests
curl "https://u.copylaradio.com/api/permit/list?type=requests" | jq

# List my requests
curl "https://u.copylaradio.com/api/permit/list?type=requests&npub=NPUB" | jq

# List all credentials
curl "https://u.copylaradio.com/api/permit/list?type=credentials" | jq

# List my credentials
curl "https://u.copylaradio.com/api/permit/list?type=credentials&npub=NPUB" | jq
```

### 6. Get Verifiable Credential

```bash
curl https://u.copylaradio.com/api/permit/credential/CREDENTIAL_ID | jq
```

**Example W3C Verifiable Credential:**
```json
{
  "@context": [
    "https://www.w3.org/2018/credentials/v1",
    "https://w3id.org/security/v2",
    "https://qo-op.com/credentials/v1"
  ],
  "id": "urn:uuid:credential_xyz",
  "type": ["VerifiableCredential", "UPlanetLicense"],
  "issuer": "did:nostr:UPLANETNAME",
  "issuanceDate": "2025-10-30T12:00:00Z",
  "expirationDate": "2028-10-30T12:00:00Z",
  "credentialSubject": {
    "id": "did:nostr:user_hex",
    "license": "PERMIT_ORE_V1",
    "licenseName": "ORE Environmental Verifier",
    "attestationsCount": 5
  },
  "proof": {
    "type": "Ed25519Signature2020",
    "created": "2025-10-30T12:00:00Z",
    "verificationMethod": "did:nostr:UPLANETNAME#uplanet-authority",
    "proofValue": "..."
  }
}
```

### 7. Reward Permit Holders (Admin)

For special permits like WoT Dragon, you can issue a blockchain reward:

```bash
cd Astroport.ONE
./UPLANET.official.sh -p dragon@example.com PERMIT_WOT_DRAGON -m 100
```

This will:
- Transfer 100 Ẑen from UPLANETNAME_RnD to the permit holder
- Record the transaction on the Ğ1 blockchain
- Update the holder's DID document

## 🔐 Security Model

### Multi-Signature Validation

Each permit type requires **N attestations** from certified experts:
- **Driver's License**: 12 signatures from existing drivers
- **ORE Verifier**: 5 signatures from environmental experts
- **WoT Dragon**: 3 signatures from captains constelation accounts

### Attestation Requirements

Some permits require attesters to hold a specific permit themselves:
- To attest a **Driver's License**, you must have a **Driver's License**
- This creates a **self-validating chain of trust**

### Revocation

Permits can be revoked if:
- False attestations are discovered
- The holder violates permit conditions
- The permit expires (if validity period is set)

### Signature Chain

All permits are ultimately signed by the **UPLANETNAME.G1** key, providing a root of trust.

## 🌐 Integration with UPlanet Ecosystem

### DID Documents

When a permit is issued, it's automatically added to the holder's DID document:

```json
{
  "id": "did:nostr:user_hex",
  "verifiableCredential": [
    {
      "@context": "https://www.w3.org/2018/credentials/v1",
      "type": ["VerifiableCredential", "UPlanetLicense"],
      "credentialSubject": {
        "license": "PERMIT_ORE_V1"
      }
    }
  ]
}
```

### Blockchain Rewards

Permit holders can receive economic incentives via UPLANET.official.sh:
- **WoT Dragon**: 100 Ẑen reward for infrastructure authority
- **ORE Verifier**: Payment for verification services
- **Mediator**: Compensation for conflict resolution

### N1/N2 Network Integration

The permit system integrates with the N1/N2 social network:
- Attesters are typically found in your N1 (direct contacts) or N2 (friends of friends)
- Community mediation uses permits to validate mediators
- Insurance mutuals use permits to validate competencies

## 📊 Statistics

```bash
# Get all permit definitions
curl https://u.copylaradio.com/api/permit/definitions | jq

# Count active requests
curl "https://u.copylaradio.com/api/permit/list?type=requests" | jq '.count'

# Count issued credentials
curl "https://u.copylaradio.com/api/permit/list?type=credentials" | jq '.count'
```

## 🛠️ API Reference

### POST /api/permit/request

Submit a new permit request.

**Request:**
```json
{
  "permit_definition_id": "PERMIT_ORE_V1",
  "applicant_npub": "npub1...",
  "statement": "I have the required competence",
  "evidence": ["/ipfs/Qm..."]
}
```

**Response:**
```json
{
  "success": true,
  "request_id": "a1b2c3d4",
  "status": "pending",
  "permit_type": "PERMIT_ORE_V1"
}
```

### POST /api/permit/attest

Add an attestation to a permit request.

**Request:**
```json
{
  "request_id": "a1b2c3d4",
  "attester_npub": "npub1...",
  "statement": "I certify this person's competence",
  "attester_license_id": "credential_xyz"
}
```

**Response:**
```json
{
  "success": true,
  "attestation_id": "b2c3d4e5",
  "request_id": "a1b2c3d4",
  "status": "validated",
  "attestations_count": 5
}
```

### GET /api/permit/status/{request_id}

Get the status of a permit request.

### GET /api/permit/list?type={requests|credentials}&npub={NPUB}

List permits (optionally filtered by NOSTR pubkey).

### GET /api/permit/credential/{credential_id}

Get a W3C Verifiable Credential.

### GET /api/permit/definitions

List all available permit types.

## 🎓 Use Cases

### 1. Driver's License (from article)

As described in the [CopyLaRadio article](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#):

1. **Declaration**: I declare I want to learn to drive
2. **Training**: I learn with certified instructors
3. **Certification**: 12 certified drivers attest my competence
4. **Insurance**: The 12 attesters become my insurance mutual
5. **Revocation**: If I'm dangerous, attesters can revoke

### 2. ORE Environmental Verifier

1. **Request**: Environmental expert requests ORE Verifier permit
2. **Attestation**: 5 existing verifiers attest their competence
3. **Credential**: VC issued, added to DID
4. **Work**: They can now verify ORE contracts for UMAPs
5. **Payment**: They receive Ẑen rewards for verifications

### 3. WoT Dragon (UPlanet Authority)

1. **Request**: Trusted community member requests WoT Dragon
2. **Attestation**: 3 community members attest their trustworthiness
3. **Credential**: VC issued with special authority powers
4. **Reward**: 100 Ẑen blockchain payment from UPLANETNAME_G1
5. **Powers**: Can now manage infrastructure, issue permits, revoke credentials

## 🧪 Testing

### Test Suite

A comprehensive test suite is available to validate the entire permit system workflow:

```bash
cd Astroport.ONE/tools
./test_permit_system.sh
```

### Test Modes

#### 1. Interactive Mode (Menu)

Run without arguments to get an interactive menu:

```bash
./test_permit_system.sh
```

**Menu Options:**
```
1. 🧪 Exécuter TOUS les tests (automatique)
2. 📋 Test: Définitions de permis
3. 📝 Test: Demande de permis
4. ✍️  Test: Attestations
5. 📊 Test: Vérification du statut
6. 📑 Test: Listing des permis
7. 🎫 Test: Récupération de credential
8. 🛠️  Test: Scripts helper
9. 💰 Test: Virement PERMIT
10. 🔧 Test: Système Oracle
11. 🚪 Quitter
```

#### 2. Automated Mode (All Tests)

Run all tests automatically:

```bash
./test_permit_system.sh --all
```

This will execute all test scenarios sequentially and provide a comprehensive report.

### Test Scenarios

#### TEST 1: Permit Definitions (📋)

**Purpose:** Verify that permit definitions are properly loaded and accessible.

**What it tests:**
- API endpoint `/api/permit/definitions` is accessible
- All permit types are returned
- Each definition has required fields (id, name, min_attestations)

**Expected output:**
```
[TEST 1] GET /api/permit/definitions
✅ PASSED

📋 Définitions disponibles:
  • PERMIT_ORE_V1: ORE Environmental Verifier (min: 5 attestations)
  • PERMIT_DRIVER: Driver's License WoT Model (min: 12 attestations)
  • PERMIT_WOT_DRAGON: WoT Dragon (UPlanet Authority) (min: 3 attestations)
  ...
```

#### TEST 2: Permit Request (📝)

**Purpose:** Test the creation of a new permit request.

**What it tests:**
- User can submit a permit application
- Request is properly stored in the system
- NOSTR event (kind 30501) is published
- A unique `request_id` is generated

**Example request:**
```json
{
  "permit_definition_id": "PERMIT_ORE_V1",
  "applicant_npub": "test_npub_hex...",
  "statement": "Je demande le permis de vérificateur ORE. J'ai une expérience en audit environnemental.",
  "evidence": [
    "https://example.com/certificate1.pdf",
    "https://example.com/experience.pdf"
  ]
}
```

**Expected output:**
```
[TEST 2] Demande de permis
📧 Email de test: test_1698765432_12345@example.com
🔑 NPub de test: a1b2c3d4e5f6...
📤 Envoi de la demande de permis...
✅ Demande de permis réussie
🆔 Request ID: abc123def456
✅ PASSED
```

#### TEST 3: Attestations (✍️)

**Purpose:** Test the multi-signature attestation process.

**What it tests:**
- Multiple experts can attest a permit request
- Each attestation is properly recorded
- Attestation counter increments correctly
- Auto-issuance triggers when threshold is reached

**Process:**
1. Generate N expert keys (where N = min_attestations for the permit)
2. Each expert submits an attestation
3. System validates each attestation
4. After the Nth attestation, credential is automatically issued

**Example attestation:**
```json
{
  "request_id": "abc123def456",
  "attester_npub": "expert_npub_hex...",
  "statement": "J'atteste que le demandeur possède les compétences requises pour le permis ORE V1.",
  "attester_license_id": null
}
```

**Expected output:**
```
[TEST 3] Attestations de permis
🆔 Request ID: abc123def456
📝 Ajout de 5 attestations...
  [1/5] Attestation par a1b2c3d4e5f6...
    ✅ Attestation ajoutée (1/5) - Status: attesting
  [2/5] Attestation par b2c3d4e5f6a1...
    ✅ Attestation ajoutée (2/5) - Status: attesting
  ...
  [5/5] Attestation par e5f6a1b2c3d4...
    ✅ Attestation ajoutée (5/5) - Status: validated
    🎉 CREDENTIAL ÉMIS AUTOMATIQUEMENT!
✅ PASSED
```

#### TEST 4: Permit Status (📊)

**Purpose:** Verify status tracking and retrieval.

**What it tests:**
- Status endpoint returns correct information
- Attestation count is accurate
- Status changes from "pending" → "attesting" → "validated"

**Expected output:**
```
[TEST 4] Vérification du statut du permis
🔍 Récupération du statut...
✅ Statut récupéré

📊 Détails du permis:
{
  "request_id": "abc123def456",
  "permit_definition_id": "PERMIT_ORE_V1",
  "applicant_npub": "a1b2c3d4...",
  "status": "validated",
  "attestations": [
    {
      "attester_npub": "expert1...",
      "statement": "Verified competence",
      "created_at": "2025-10-30T12:34:56Z"
    },
    ...
  ]
}

  Status: validated
  Attestations: 5
  🎉 Permis VALIDÉ et credential émis!
✅ PASSED
```

#### TEST 5: Permit Listing (📑)

**Purpose:** Test the listing and filtering functionality.

**What it tests:**
- List all permit requests
- List all issued credentials
- Filter by npub (user-specific listing)

**Example queries:**
```bash
# All requests
GET /api/permit/list?type=requests

# User's requests
GET /api/permit/list?type=requests&npub=user_npub

# All credentials
GET /api/permit/list?type=credentials

# User's credentials
GET /api/permit/list?type=credentials&npub=user_npub
```

**Expected output:**
```
[TEST 5] GET /api/permit/list?type=requests
✅ PASSED

📋 Demandes de permis:
  • abc123: PERMIT_ORE_V1 - validated
  • def456: PERMIT_DRIVER - attesting
  • ghi789: PERMIT_WOT_DRAGON - pending

[TEST 6] GET /api/permit/list?type=credentials
✅ PASSED

🎫 Credentials émis:
  • cred_xyz123: PERMIT_ORE_V1 - active
  • cred_abc456: PERMIT_WOT_DRAGON - active
```

#### TEST 6: Verifiable Credential Retrieval (🎫)

**Purpose:** Validate W3C Verifiable Credential format.

**What it tests:**
- Credential endpoint returns proper VC format
- All required W3C fields are present
- Credential includes proper proof/signature

**Expected output:**
```
[TEST 6] GET /api/permit/credential/cred_xyz123
✅ PASSED

📜 Verifiable Credential (W3C format):
{
  "@context": [
    "https://www.w3.org/2018/credentials/v1",
    "https://w3id.org/security/v2",
    "https://qo-op.com/credentials/v1"
  ],
  "id": "urn:uuid:cred_xyz123",
  "type": ["VerifiableCredential", "UPlanetLicense"],
  "issuer": "did:nostr:UPLANETNAME",
  "issuanceDate": "2025-10-30T12:00:00Z",
  "expirationDate": "2028-10-30T12:00:00Z",
  "credentialSubject": {
    "id": "did:nostr:user_hex",
    "license": "PERMIT_ORE_V1",
    "licenseName": "ORE Environmental Verifier",
    "attestationsCount": 5,
    "status": "active"
  },
  "proof": {
    "type": "Ed25519Signature2020",
    "created": "2025-10-30T12:00:00Z",
    "verificationMethod": "did:nostr:UPLANETNAME#uplanet-authority",
    "proofValue": "z58DAdFfa9SkqZMVPxAQp..."
  }
}
```

#### TEST 7: Helper Scripts (🛠️)

**Purpose:** Verify CLI tools are functional.

**What it tests:**
- `request_license.sh` exists and is executable
- `attest_license.sh` exists and is executable
- Scripts have proper permissions

**Expected output:**
```
[TEST 7] Scripts helper
✅ request_license.sh existe
[TEST 8] request_license.sh est exécutable
✅ PASSED
✅ attest_license.sh existe
[TEST 9] attest_license.sh est exécutable
✅ PASSED
```

#### TEST 8: Blockchain PERMIT Transfer (💰)

**Purpose:** Test the economic reward mechanism.

**What it tests:**
- UPLANETNAME_RnD wallet exists and has funds
- MULTIPASS wallet exists for recipient
- Transfer executes successfully on Ğ1 blockchain
- Transaction is confirmed
- DID document is updated

**Prerequisites:**
- Configured UPLANETNAME_RnD wallet (`~/.zen/game/uplanet.RnD.dunikey`)
- Sufficient funds in RnD wallet
- MULTIPASS created for recipient (via `make_NOSTRCARD.sh`)

**Example command:**
```bash
./UPLANET.official.sh -p dragon@example.com PERMIT_WOT_DRAGON -m 100
```

**Expected output:**
```
[TEST 8] Virement PERMIT (blockchain)
⚠️  Ce test nécessite:
  1. Un portefeuille UPLANETNAME_RnD configuré
  2. Des fonds disponibles dans RnD
  3. Un MULTIPASS créé pour le bénéficiaire

Voulez-vous tester le virement PERMIT? (o/N): o
Email du bénéficiaire: dragon@example.com
Permit ID (ex: PERMIT_WOT_DRAGON): PERMIT_WOT_DRAGON
Montant en Ẑen (défaut: 100): 100

🚀 Lancement du virement PERMIT...
🎫 Traitement virement PERMIT pour: dragon@example.com
💰 Montant: 100 Ẑen = 10.00 Ğ1
🏛️ Type: PERMIT_WOT_DRAGON
✅ Portefeuille RnD trouvé: 8QmJ7Kb3...
🔍 Vérification préalable des transactions en cours...
✅ Aucune transaction en cours - Solde stable: 50.00 Ğ1
📤 Transfert UPLANETNAME_RnD → MULTIPASS (permit holder)
📝 Description: UPLANET:8QmJ7Kb3:PERMIT:PERMIT_WOT_DRAGON:dragon@example.com:a1b2c3d4:QmNodeID
✅ Transfert initié avec succès
⏳ Transaction en cours... Pending: 10.00 Ğ1, Total: 40.00 Ğ1 (attente: 60s)
✅ Transaction confirmée - Solde: 40.00 Ğ1
🎉 Virement PERMIT terminé avec succès!
📊 Résumé:
  • 100 Ẑen (10.00 Ğ1) transférés vers dragon@example.com
  • Permit: PERMIT_WOT_DRAGON
  • Credential: a1b2c3d4
  • Récompense pour WoT permit holder
  • Transaction confirmée sur la blockchain
📝 Mise à jour du DID...
✅ PASSED
```

#### TEST 9: Oracle System Module (🔧)

**Purpose:** Verify Python module integrity.

**What it tests:**
- `oracle_system.py` exists
- Module has no syntax errors
- Can be imported successfully

**Expected output:**
```
[TEST 9] Système Oracle (oracle_system.py)
✅ oracle_system.py existe
[TEST 10] oracle_system.py est syntaxiquement correct
✅ PASSED
```

### Test Summary

At the end of all tests, you'll see a comprehensive summary:

```
═══════════════════════════════════════════════════════════════════
  RÉSUMÉ DES TESTS
═══════════════════════════════════════════════════════════════════

Tests exécutés: 15
Tests réussis: 15
Tests échoués: 0

Taux de réussite: 100%

🎉 TOUS LES TESTS SONT PASSÉS!
```

### Prerequisites for Testing

Before running tests, ensure:

1. **API is running:**
```bash
cd UPassport
python 54321.py
```

2. **Dependencies installed:**
```bash
# Required tools
curl --version
jq --version
openssl version
python3 --version

# Python dependencies
pip install fastapi uvicorn pydantic nostr
```

3. **Permit definitions loaded:**
```bash
cd Astroport.ONE/tools
./init_permit_definitions.sh
```

4. **For blockchain tests (optional):**
```bash
# Configure RnD wallet
cd Astroport.ONE
./ZEN.COOPERATIVE.3x1-3.sh

# Create test MULTIPASS
./tools/make_NOSTRCARD.sh test@example.com
```

### Environment Variables

Configure the test environment:

```bash
# API URL (default: http://localhost:1234)
export API_URL="http://localhost:1234"

# Test mode (skip auth checks)
export TEST_MODE=1
```

### Continuous Integration

The test suite can be integrated into CI/CD pipelines:

```yaml
# .github/workflows/test.yml
name: Test Permit System

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y curl jq bc
          pip install -r UPassport/requirements.txt
      - name: Start API
        run: |
          cd UPassport
          python 54321.py &
          sleep 5
      - name: Run tests
        run: |
          cd Astroport.ONE/tools
          ./test_permit_system.sh --all
```

### Troubleshooting

**API not available:**
```
❌ API non disponible à http://localhost:1234
💡 Lancez d'abord: cd UPassport && python 54321.py
```
→ Start the FastAPI server first

**Missing dependencies:**
```
❌ Erreur: jq n'est pas installé
```
→ Install required tools: `sudo apt-get install curl jq bc openssl`

**Blockchain tests fail:**
```
❌ Portefeuille UPLANETNAME_RnD non configuré
💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs
```
→ Run wallet setup scripts first

**NOSTR authentication errors:**
```
❌ NOSTR authentication failed
```
→ Set `TEST_MODE=1` to skip auth in testing

## 📚 Further Reading

- [CopyLaRadio Article](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#) - Philosophical foundation
- [DID_IMPLEMENTATION.md](../DID_IMPLEMENTATION.md) - DID system overview
- [ORE_SYSTEM.md](./ORE_SYSTEM.md) - Environmental obligations system
- [W3C DID Core](https://www.w3.org/TR/did-core/) - DID standard
- [W3C Verifiable Credentials](https://www.w3.org/TR/vc-data-model/) - VC standard

## 🤝 Contributing

The Oracle System is part of the UPlanet/Astroport.ONE ecosystem. To contribute:

1. Understand the WoT model from the CopyLaRadio article
2. Propose new permit types via `permit_definitions.json`
3. Test the attestation flow with your community
4. Report issues and suggest improvements

## 📝 License

AGPL-3.0

## ✉️ Support

support@qo-op.com

