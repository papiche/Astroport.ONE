# 🔐 Oracle System - Multi-Signature Permit Management

## Overview

The Oracle System is a decentralized permit/license management system based on the **Web of Trust (WoT)** model described in the [CopyLaRadio article](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#). It enables the issuance of **Verifiable Credentials** for competencies, licenses, and authorities within the UPlanet ecosystem.

## 🎯 Concept

The Oracle System transforms traditional licensing from centralized authorities to **peer-validated certification**:

- **Permit Request**: An applicant publicly requests a permit (e.g., "Driver's License", "ORE Verifier")
- **Peer Attestation**: Certified experts attest the applicant's competence (multi-signature validation)
- **Credential Issuance**: Once enough attestations are collected, a Verifiable Credential (VC) is issued
- **Authority Signature**: The final VC is signed by the UPlanet authority (UPLANETNAME.G1 key)

### 📝 MULTIPASS Creation

**Every participant must have a MULTIPASS created via `make_NOSTRCARD.sh`** before interacting with the Oracle System.

The `make_NOSTRCARD.sh` script:
- Generates NOSTR keypair (nsec/npub)
- Creates and publishes the DID on NOSTR (kind 30311)
- Stores credentials in `~/.zen/game/nostr/EMAIL/.secret.nostr`
- Publishes NOSTR profile with DID reference

### 🌱 "Block 0" - WoT Initialization

For a new permit type without existing holders, the system uses a **"Block 0" initialization process**:

**Principle:** For a permit requiring **N signatures**, you need **minimum N+1 MULTIPASS registered** on the station to initialize the certification group.

Each member attests all other members (except themselves), giving exactly **N attestations** per member.

**Examples:**
- **PERMIT_ORE_V1** (5 signatures) → minimum **6 registered MULTIPASS** (each receives 5 attestations)
- **PERMIT_DRIVER** (12 signatures) → minimum **13 registered MULTIPASS** (each receives 12 attestations)
- **PERMIT_WOT_DRAGON** (3 signatures) → minimum **4 registered MULTIPASS** (each receives 3 attestations)

This ensures each initial member can be attested by enough peers from the start. The "Block 0" creates a cross-attestation network where all initial members attest each other, establishing the foundation for the Web of Trust.

## 🏗️ Architecture

### Components

1. **oracle_system.py** - Core permit management system
2. **54321.py API routes** - REST API for permit operations
3. **Helper scripts** - CLI tools for users and attesters
4. **NOSTR events** - Decentralized event publishing (kinds 30500-30503)
5. **DID integration** - Verifiable Credentials attached to DIDs

### NOSTR Event Kinds

| Kind  | Name | Description | Signed by |
|-------|------|-------------|-----------|
| 30500 | Permit Definition | License type definition (e.g., "Driver's License") | `UPLANETNAME.G1` |
| 30501 | Permit Request | Application from a user | Applicant |
| 30502 | Permit Attestation | Expert signature/attestation | Attester |
| 30503 | Permit Credential | Final Verifiable Credential (VC) | `UPLANETNAME.G1` |

**📖 For detailed NOSTR event flow, see [ORACLE_NOSTR_FLOW.md](ORACLE_NOSTR_FLOW.md)**

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

### Web Interface: `/oracle`

The Oracle System provides a modern web interface for managing permits:

**Access:** `https://u.copylaradio.com/oracle` (or `http://127.0.0.1:54321/oracle` for local)

**Features:**
1. **View Available Permits (30500)**
   - Browse all permit types with their requirements
   - See holders of each permit type (30503 credentials)

2. **Connect with NOSTR (NIP-42)**
   - Authenticate using NOSTR extension (nos2x, Alby, etc.)
   - Seamless integration with your MULTIPASS

3. **Request/Renew Permits**
   - Submit permit requests (30501 events)
   - Track your application status
   - View attestation progress

4. **Attest Requests**
   - View pending requests that match your credentials
   - Submit attestations (30502 events) for requests you can validate
   - Track your attestation history

**Interface Tabs:**
- 📜 **Available Permits**: Browse and request permits
- 🎯 **My Permits**: View your issued credentials
- ⏳ **Pending Requests**: Validate requests from others (if you have required permits)
- ✍️ **My Attestations**: Track attestations you've provided

### Command-Line Interface

**Note**: The Oracle system is primarily accessed through the `/oracle` web interface. Legacy CLI scripts have been integrated into the web UI for better user experience.

### 0. Initialize Web of Trust (Bootstrap)

**For NEW permits that have no holders yet:**

```bash
cd Astroport.ONE/tools
./oracle.WoT_PERMIT.init.sh
```

This script creates the **"Block 0"** of a new permit's Web of Trust by establishing the initial certification group.

**Prerequisites:**
- All initial members must have a **MULTIPASS created via `make_NOSTRCARD.sh`**
- For N required signatures → minimum **N+1 MULTIPASS registered** on the station
- The CAPTAIN of the station launches the script

**📖 See [ORACLE_WOT_BOOTSTRAP.md](ORACLE_WOT_BOOTSTRAP.md) for detailed bootstrap process**

The script will:
1. List permits (30500) with no holders (no 30503 events)
2. Let you select a permit to initialize
3. Let you select MULTIPASS members to become initial holders
4. Create permit requests (30501) for each member
5. Create cross-attestations (30502) between all members
6. Wait for credentials (30503) to be issued by the Oracle

**Example:**
```bash
# Interactive mode (recommended)
./oracle.WoT_PERMIT.init.sh

# Direct mode
./oracle.WoT_PERMIT.init.sh PERMIT_ORE_V1 \
    alice@example.com \
    bob@example.com \
    carol@example.com \
    dave@example.com \
    eve@example.com \
    frank@example.com
```

**What happens during "Block 0" initialization:**
1. **Cross-attestation network**: Each of the 6 members attests the other 5
2. **Threshold reached**: All members receive exactly 5 attestations (the required number)
3. **Credentials issued**: UPLANETNAME.G1 signs the 30503 for each member
4. **WoT established**: The initial group can now attest new applicants

### 1. Initialize Permit Definitions

Permit definitions are loaded automatically when the system starts. They are defined in `templates/NOSTR/permit_definitions.json`.

To add a new permit type:
1. Edit `templates/NOSTR/permit_definitions.json`
2. Add your permit definition
3. Restart the API (54321.py) to load the new definition
4. Initialize the WoT for the new permit (see "0. Initialize Web of Trust")

### 2. Request a Permit

**Via Web Interface** (Recommended):
- Go to `https://u.copylaradio.com/oracle`
- Connect with NOSTR (NIP-42)
- Navigate to "Available Permits" tab
- Click "Request This Permit" on the desired permit
- Fill out the form and submit

**Via API**:
```bash
curl -X POST "${uSPOT}/api/permit/request" \
  -H "Content-Type: application/json" \
  -d '{
    "permit_definition_id": "PERMIT_ORE_V1",
    "applicant_email": "user@example.com",
    "statement": "I have 5 years experience in environmental assessment",
    "evidence": []
  }'
```

### 3. Attest a Permit

**Via Web Interface** (Recommended):
- Go to `/oracle`
- Connect with NOSTR
- Navigate to "Pending Requests" tab
- View requests that need your attestation
- Click "Attest This Request" and submit your attestation

**Via API**:
```bash
curl -X POST "${uSPOT}/api/permit/attest" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "a1b2c3d4",
    "attester_email": "expert@example.com",
    "statement": "I have personally verified their competence",
    "attester_license_id": null
  }'
```

### 4. Check Permit Status

**Via Web Interface**:
- Go to `/oracle` → "My Permits" tab to see your own permits
- Or check "Pending Requests" to see attestation progress

**Via API**:
```bash
curl "${uSPOT}/api/permit/status/REQUEST_ID" | jq
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

**Via Web Interface**:
- Browse all permits in "Available Permits" tab
- View your own permits in "My Permits" tab
- See pending attestations in "Pending Requests" tab

**Via API**:
```bash
# List all requests
curl "${uSPOT}/api/permit/list?type=requests" | jq

# List my requests
curl "${uSPOT}/api/permit/list?type=requests&npub=NPUB" | jq

# List all credentials
curl "${uSPOT}/api/permit/list?type=credentials" | jq

# List my credentials
curl "${uSPOT}/api/permit/list?type=credentials&npub=NPUB" | jq
```

### 6. Get Verifiable Credential

**Via Web Interface**:
- Go to "My Permits" tab
- Click "View Credential" on any issued permit

**Via API**:
```bash
curl "${uSPOT}/api/permit/credential/CREDENTIAL_ID" | jq
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

The Oracle System exposes REST API endpoints for permit management.

**📖 See [ORACLE_API_ROUTES.md](ORACLE_API_ROUTES.md) for complete API reference**

### Core Routes

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/permit/define` | POST | Create permit definition (admin) |
| `/api/permit/request` | POST | Submit permit request (NIP-42) |
| `/api/permit/attest` | POST | Add attestation (NIP-42) |
| `/api/permit/status/{id}` | GET | Get request status |
| `/api/permit/list` | GET | List requests/credentials |
| `/api/permit/credential/{id}` | GET | Get W3C credential |
| `/api/permit/definitions` | GET | List all permit types |

### NOSTR Integration Routes ⭐ NEW

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/permit/nostr/fetch` | GET | Fetch events from NOSTR relays (kind 30500-30503) |
| `/api/permit/issue/{id}` | POST | Trigger credential issuance (maintenance) |
| `/api/permit/expire/{id}` | POST | Mark request as expired (maintenance) |
| `/api/permit/revoke/{id}` | POST | Revoke credential (admin) |

**Tools used:**
- **`nostr_send_note.py`** - Publish events to NOSTR relays
- **NIP-42 authentication** - Secure API access
- **Local storage + NOSTR sync** - Hybrid data model

---

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
./oracle_init_permit_definitions.sh
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

## 🔄 Automated Maintenance

The Oracle System includes daily automated maintenance via `ORACLE.refresh.sh`:

**📖 See [ORACLE_MAINTENANCE.md](ORACLE_MAINTENANCE.md) for detailed documentation**

### Daily Tasks

1. **Process Pending Requests**
   - Check all requests with status `pending` or `attesting`
   - Verify attestation thresholds
   - Auto-issue credentials (30503) when threshold reached

2. **Expire Old Requests**
   - Mark requests older than 90 days as expired
   - Clean up abandoned applications

3. **Revoke Expired Credentials**
   - Check credential expiration dates
   - Mark expired credentials as inactive

4. **Generate Statistics**
   - Per-permit request and credential counts
   - Global statistics
   - JSON files in `~/.zen/tmp/${IPFSNODEID}/ORACLE/`

5. **Publish to NOSTR**
   - Daily report signed by `UPLANETNAME.G1`
   - Kind 1 event with global statistics

### Execution Schedule

The maintenance script runs daily as part of `UPLANET.refresh.sh`:

```bash
# UPLANET.refresh.sh
${MY_PATH}/ZEN.ECONOMY.sh
${MY_PATH}/ORACLE.refresh.sh    # ← Daily Oracle maintenance
${MY_PATH}/NOSTR.UMAP.refresh.sh
```

### Manual Execution

```bash
cd Astroport.ONE/RUNTIME
./ORACLE.refresh.sh
```

---

## 📚 Further Reading

- [CopyLaRadio Article](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#) - Philosophical foundation
- [ORACLE_WOT_BOOTSTRAP.md](ORACLE_WOT_BOOTSTRAP.md) - Web of Trust initialization process
- [ORACLE_NOSTR_FLOW.md](ORACLE_NOSTR_FLOW.md) - Detailed NOSTR event flow
- [ORACLE_NIP42_AUTH.md](ORACLE_NIP42_AUTH.md) - NOSTR authentication (NIP-42)
- [ORACLE_MAINTENANCE.md](ORACLE_MAINTENANCE.md) - Daily maintenance and automation
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

