# 🔐 UPlanet Oracle System - Complete Documentation

**Version**: 2.0  
**Date**: November 5, 2025  
**Status**: Consolidated Documentation  
**License**: AGPL-3.0

> **Note**: This document consolidates 7 previous Oracle documentation files into a single, comprehensive reference.

---

## 📖 Table of Contents

1. [Overview & Philosophy](#1-overview--philosophy)
2. [Core Concepts](#2-core-concepts)
3. [Architecture](#3-architecture)
4. [Authentication & Security](#4-authentication--security)
5. [NOSTR Events Flow](#5-nostr-events-flow)
6. [Cryptographic Details & Attestation](#6-cryptographic-details--attestation)
7. [Web of Trust Bootstrap](#7-web-of-trust-bootstrap)
8. [Available Permit Types](#8-available-permit-types)
9. [Usage](#9-usage)
10. [API Reference](#10-api-reference)
11. [Daily Maintenance](#11-daily-maintenance)
12. [Testing](#12-testing)
13. [Integration with UPlanet](#13-integration-with-uplanet)
14. [Troubleshooting](#14-troubleshooting)
15. [References](#15-references)
16. [FAQ](#16-faq)

---

## 1. Overview & Philosophy

### 1.1. What is the Oracle System?

The Oracle System is a decentralized permit/license management system based on the **Web of Trust (WoT)** model described in the [CopyLaRadio article](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#). It enables the issuance of **Verifiable Credentials** for competencies, licenses, and authorities within the UPlanet ecosystem.

### 1.2. Philosophy

The Oracle System transforms traditional licensing from centralized authorities to **peer-validated certification**:

- **Permit Request**: An applicant publicly requests a permit (e.g., "Driver's License", "ORE Verifier")
- **Peer Attestation**: Certified experts attest the applicant's competence (multi-signature validation)
- **Credential Issuance**: Once enough attestations are collected, a Verifiable Credential (VC) is issued
- **Authority Signature**: The final VC is signed by the UPlanet authority (UPLANETNAME.G1 key)

This creates a **self-regulating ecosystem** where competence is validated by those who already possess it, eliminating single points of failure and centralized control.

---

## 2. Core Concepts

### 2.1. Web of Trust Model

The Web of Trust (WoT) is a decentralized trust model where:

1. **Trust is transitive**: If A trusts B, and B trusts C, then A can trust C (to some degree)
2. **Trust is quantifiable**: Multiple attestations from different sources increase trust
3. **Trust is revocable**: If someone proves unworthy, their credentials can be revoked
4. **Trust is distributed**: No single authority controls the entire network

**In the Oracle System**:
- Trust starts with the Ğ1 blockchain WoT (Duniter certification)
- Extends to NOSTR-based DIDs (MULTIPASS)
- Further extends to specific competencies (Oracle permits)

### 2.2. Multi-Signature Validation

Each permit type requires **N attestations** from certified experts:

| Permit Type | Required Attestations | Validity Period |
|-------------|----------------------|-----------------|
| Driver's License | 12 | 15 years |
| ORE Verifier | 5 | 3 years |
| WoT Dragon | 3 | Unlimited |
| Medical First Aid | 8 | 2 years |
| Building Artisan | 10 | 5 years |
| Educator Compagnon | 12 | Unlimited |
| Food Producer | 6 | 3 years |
| Community Mediator | 15 | 5 years |

**Why multiple attestations?**
- Prevents single-person fraud
- Distributes responsibility
- Creates insurance mutual (attesters become guarantors)
- Increases trust through consensus

### 2.3. Verifiable Credentials

The Oracle System issues **W3C Verifiable Credentials**, which are:

- **Cryptographically signed**: Cannot be forged
- **Self-verifiable**: Anyone can verify authenticity
- **Machine-readable**: JSON-LD format
- **Decentralized**: Stored on NOSTR, not a central database
- **Portable**: Can be used across systems

**Example W3C VC**:
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
    "proofValue": "z58DAdFfa9..."
  }
}
```

### 2.4. MULTIPASS Creation

**Every participant must have a MULTIPASS created via `make_NOSTRCARD.sh`** before interacting with the Oracle System.

The `make_NOSTRCARD.sh` script:
- Generates NOSTR keypair (nsec/npub)
- Creates and publishes the DID on NOSTR (kind 0 with DID extension)
- Stores credentials in `~/.zen/game/nostr/EMAIL/.secret.nostr`
- Publishes NOSTR profile with DID reference

**DID Format**: `did:nostr:{hex_pubkey}`

**Note on NOSTR DID Storage**: The project uses NOSTR profile events (kind 0) with a custom DID field in the content JSON to store Decentralized Identifiers. This follows the NOSTR convention for extensible profile data.

> **🔗 For complete details on DID implementation**, see [`DID_IMPLEMENTATION.md`](../../DID_IMPLEMENTATION.md) which covers:
> - Full DID architecture and W3C compliance
> - MULTIPASS and ZEN Card creation
> - SSSS 3/2 secret sharing
> - Twin keys (G1, NOSTR, BTC, XMR)
> - Integration with France Connect

---

## 3. Architecture

### 3.1. Components

```
┌─────────────────────────────────────────────────────────────────┐
│                      ORACLE SYSTEM ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. WEB INTERFACE (/oracle)                                     │
│     └─> oracle.html (frontend)                                  │
│         ├─> Bootstrap 5 UI                                      │
│         ├─> Chart.js visualizations                             │
│         └─> NOSTR.bundle.js (NIP-42 auth)                      │
│                                                                  │
│  2. API BACKEND (54321.py)                                      │
│     └─> FastAPI application                                     │
│         ├─> 11 Oracle endpoints                                 │
│         ├─> NIP-42 authentication                               │
│         └─> NOSTR event publishing                              │
│                                                                  │
│  3. CORE SYSTEM (oracle_system.py)                              │
│     └─> Python module                                           │
│         ├─> PermitDefinition                                    │
│         ├─> PermitRequest                                       │
│         ├─> PermitAttestation                                   │
│         ├─> PermitCredential                                    │
│         └─> Credential issuance logic                           │
│                                                                  │
│  4. NOSTR RELAYS                                                 │
│     └─> Decentralized storage                                    │
│         ├─> Events: kinds 30500-30503                           │
│         ├─> Persistence layer                                    │
│         └─> Public verifiability                                │
│                                                                  │
│  5. MAINTENANCE (ORACLE.refresh.sh)                             │
│     └─> Daily automated tasks                                    │
│         ├─> Process pending requests                             │
│         ├─> Expire old requests                                  │
│         ├─> Revoke expired credentials                           │
│         └─> Generate statistics                                  │
│                                                                  │
│  6. BLOCKCHAIN INTEGRATION                                       │
│     └─> UPLANET.official.sh                                     │
│         ├─> Economic rewards (Ẑen)                              │
│         ├─> Ğ1 blockchain transactions                          │
│         └─> DID updates                                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2. Data Flow

```
1. REQUEST
   User → 54321.py → oracle_system.py → NOSTR (kind 30501)
   
2. ATTESTATION (multiple)
   Expert → 54321.py → oracle_system.py → NOSTR (kind 30502)
   
3. VALIDATION
   oracle_system.py → Check attestations → Auto-issue if threshold reached
   
4. CREDENTIAL
   oracle_system.py → Sign with UPLANETNAME.G1 → NOSTR (kind 30503) → DID update
   
5. REWARD (optional)
   UPLANET.official.sh -p email PERMIT_ID → Blockchain payment
```

### 3.3. Technology Stack

**Backend**:
- Python 3.8+
- FastAPI (async web framework)
- Pydantic (data validation)
- python-nostr (NOSTR protocol)

**Frontend**:
- HTML5 + Bootstrap 5
- Vanilla JavaScript (ES6+)
- Chart.js (visualizations)
- Leaflet.js (maps for ORE contracts)

**Blockchain**:
- Duniter/Ğ1 (Web of Trust foundation)
- Silkaj CLI (blockchain interactions)

**Storage**:
- NOSTR relays (decentralized event storage)
- Local filesystem (`~/.zen/tmp/`)

**Authentication**:
- NIP-42 (NOSTR authentication)
- Ed25519 signatures
- Schnorr signatures (secp256k1)

---

## 4. Authentication & Security


### 4.1. NOSTR Authentication (NIP-42)

The Oracle System uses **NIP-42 authentication** to secure all API interactions. Users must authenticate with their NOSTR private key before using the endpoints.

#### Authentication Flow

```
1. USER connects via NOSTR extension (nos2x, Alby, etc.)
   ↓
2. EXTENSION signs a challenge (kind 22242 event)
   ↓
3. API verifies signature with user's npub
   ↓
4. If valid → session established
   ↓
5. USER can now call authenticated endpoints
```

#### NIP-42 Event Structure

```json
{
  "kind": 22242,
  "created_at": 1730000000,
  "tags": [
    ["relay", "wss://relay.copylaradio.com"],
    ["challenge", "auth-1730000000"]
  ],
  "content": "",
  "pubkey": "<user_hex_pubkey>",
  "sig": "<schnorr_signature>"
}
```

### 4.2. Credential Structure

Each user's NOSTR credentials are stored in:

```
~/.zen/game/nostr/EMAIL/.secret.nostr
```

**File format**:
```bash
NSEC=nsec1...; NPUB=npub1...; HEX=<hex_public_key>;
```

**Security**:
- File permissions: `chmod 600` (read/write owner only)
- Never transmitted over network
- Only signatures are sent

### 4.3. Security Model

#### Multi-Signature Validation

Each permit type requires **N attestations** from certified experts:
- **Driver's License**: 12 signatures from existing drivers
- **ORE Verifier**: 5 signatures from environmental experts
- **WoT Dragon**: 3 signatures from community leaders

#### Attestation Requirements

Some permits require attesters to hold a specific permit themselves:
- To attest a **Driver's License**, you must have a **Driver's License**
- This creates a **self-validating chain of trust**

#### Revocation

Permits can be revoked if:
- False attestations are discovered
- The holder violates permit conditions
- The permit expires (if validity period is set)

#### Signature Chain

All permits are ultimately signed by the **UPLANETNAME.G1** key, providing a root of trust.

### 4.4. Protection Against Attacks

**Attack 1: False Attestation**
- **Defense**: Insurance mutual - attesters form a liability pool
- **Defense**: Revocation cascade - false attestation revokes dependent permits
- **Defense**: Economic penalty - attester loses own permit + Ẑen penalty
- **Defense**: Traceability - all NOSTR events are immutable

**Attack 2: Expert Collusion**
- **Defense**: High threshold (5-15 attestations depending on permit)
- **Defense**: Geographic diversity - experts from different regions
- **Defense**: Reputation tracking - attestation history on NOSTR
- **Defense**: Challenge period - 7-30 days for community contestation

**Attack 3: Identity Theft**
- **Defense**: Schnorr signatures - impossible to forge without NSEC
- **Defense**: NIP-42 challenge-response - proves key possession
- **Defense**: DID verification - traceable to Ğ1 WoT
- **Defense**: Hardware wallet support (future)

**Attack 4: Replay Attack**
- **Defense**: Timestamp in signature
- **Defense**: Unique request ID
- **Defense**: NOSTR event ID (hash of entire content)
- **Defense**: Reference tags (["e", ...], ["a", ...])

---

## 5. NOSTR Events Flow

### 5.1. Event Kinds (30500-30503)

The Oracle System uses four parameterized replaceable event kinds:

| Kind  | Name | Signed by | Description |
|-------|------|-----------|-------------|
| **30500** | Permit Definition | `UPLANETNAME.G1` | Definition of a permit type (rules, validity, etc.) |
| **30501** | Permit Request | Applicant | Application from a user |
| **30502** | Permit Attestation | Attester | Expert signature/attestation |
| **30503** | Permit Credential | `UPLANETNAME.G1` | Final Verifiable Credential (VC) |

### 5.2. Event Structure Details

#### Kind 30500: Permit Definition

**Purpose**: Define the rules for a permit type

**Published by**: UPLANETNAME.G1 (authority)

**Structure**:
```json
{
  "kind": 30500,
  "pubkey": "<UPLANETNAME.G1_HEX_PUBKEY>",
  "tags": [
    ["d", "PERMIT_ORE_V1"],
    ["name", "ORE Environmental Verifier"],
    ["min_attestations", "5"],
    ["valid_duration_days", "1095"],
    ["required_license", ""]
  ],
  "content": "{\"description\": \"...\", \"verification_method\": \"peer_attestation\"}",
  "created_at": 1730000000,
  "sig": "<signature_by_UPLANETNAME.G1>"
}
```

**Key tags**:
- `d`: Permit ID (deduplication key)
- `name`: Human-readable name
- `min_attestations`: Required number of attestations
- `valid_duration_days`: Credential validity period
- `required_license`: Permit required to attest (optional)

#### Kind 30501: Permit Request

**Purpose**: User requests a permit

**Published by**: Applicant (MULTIPASS holder)

**Structure**:
```json
{
  "kind": 30501,
  "pubkey": "<APPLICANT_HEX_PUBKEY>",
  "tags": [
    ["d", "<REQUEST_ID>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["status", "pending"]
  ],
  "content": "{\"statement\": \"I have 5 years experience...\", \"evidence\": []}",
  "created_at": 1730000000,
  "sig": "<signature_by_applicant>"
}
```

**Key tags**:
- `d`: Unique request ID
- `permit_id`: Type of permit requested
- `status`: `pending`, `attesting`, `validated`, or `expired`

#### Kind 30502: Permit Attestation

**Purpose**: Expert attests an applicant's competence

**Published by**: Attester (expert with valid credential)

**Structure**:
```json
{
  "kind": 30502,
  "pubkey": "<ATTESTER_HEX_PUBKEY>",
  "tags": [
    ["d", "<ATTESTATION_ID>"],
    ["e", "<REQUEST_EVENT_ID>", "", "root"],
    ["p", "<APPLICANT_HEX_PUBKEY>"],
    ["request_id", "<REQUEST_ID>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["attester_credential", "<ATTESTER_CREDENTIAL_ID>"]
  ],
  "content": "{\"statement\": \"I have personally verified their competence...\"}",
  "created_at": 1730000000,
  "sig": "<signature_by_attester>"
}
```

**Key tags**:
- `d`: Unique attestation ID
- `e`: Reference to request event
- `p`: Reference to applicant
- `attester_credential`: Proof that attester is qualified

#### Kind 30503: Permit Credential

**Purpose**: Final Verifiable Credential

**Published by**: UPLANETNAME.G1 (authority)

**Structure**:
```json
{
  "kind": 30503,
  "pubkey": "<UPLANETNAME.G1_HEX_PUBKEY>",
  "tags": [
    ["d", "<CREDENTIAL_ID>"],
    ["p", "<HOLDER_HEX_PUBKEY>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["request_id", "<REQUEST_ID>"],
    ["issued_at", "2025-10-30T12:00:00Z"],
    ["expires_at", "2028-10-30T12:00:00Z"],
    ["attestation_count", "5"],
    ["attesters", "<ATTESTER1>", "<ATTESTER2>", "..."]
  ],
  "content": "{W3C_VERIFIABLE_CREDENTIAL_JSON}",
  "created_at": 1730000000,
  "sig": "<signature_by_UPLANETNAME.G1>"
}
```

**Key tags**:
- `d`: Unique credential ID
- `p`: Credential holder
- `attesters`: List of all attesters
- Content: Full W3C VC

### 5.3. Parameterized Replaceable Events (NIP-33)

All Oracle events are **Parameterized Replaceable** (kinds 30000-39999):

- Tag `["d", ...]` makes each event unique
- Only the latest version is kept per `d` value
- Allows updates (e.g., status changes, revocations)

### 5.4. Complete Flow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    Authority UPlanet                          │
│                  (UPLANETNAME.G1)                            │
└────────┬─────────────────────────────────────────────┬───────┘
         │                                             │
         │ 1. Publish definition                      │ 4. Sign credential
         ▼                                             ▼
    ┌────────┐                                    ┌────────┐
    │ 30500  │                                    │ 30503  │
    │ Permit │                                    │  VC    │
    │  Def   │                                    │ Final  │
    └────────┘                                    └────────┘
         │                                             ▲
         │                                             │
         │ 2. Applicant submits                       │ 3. Attesters sign
         │    request                                  │
         ▼                                             │
    ┌────────┐          ┌────────┐  ┌────────┐  ┌────────┐
    │ 30501  │ ────────▶│ 30502  │  │ 30502  │  │ 30502  │
    │Request │          │(by B)  │  │(by C)  │  │(by D)  │
    │ (by A) │          └────────┘  └────────┘  └────────┘
    └────────┘                 │          │          │
         │                     └──────────┼──────────┘
         │                                │
         │                                ▼
         │                          ┌──────────┐
         │                          │  Oracle  │
         └─────────────────────────▶│ System   │
                                    │ (nightly)│
                                    └──────────┘
                                         │
                                         │ Verify threshold
                                         ▼
                                    ┌────────┐
                                    │ 30503  │
                                    │   VC   │
                                    │ signed │
                                    └────────┘
```

### 5.5. Verification Process

To verify a permit is valid:

1. **Find event 30503**
   - Filter: `kind: 30503`, `#p: <HOLDER_PUBKEY>`, `#permit_id: <PERMIT_ID>`

2. **Verify signature**
   - Signature must be valid from `UPLANETNAME.G1` pubkey

3. **Check expiration**
   - Compare `expires_at` tag with current date

4. **Check revocation status**
   - Look for updated event with `status: revoked`

5. **Verify attestations**
   - Each attester in `attesters` tag must have valid credential
   - Count must meet `min_attestations` requirement

---

## 6. Cryptographic Details & Attestation

### 6.1. Attestation Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      ATTESTATION WORKFLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ATTESTER (Expert)                                           │
│     └─> Web Interface (/oracle) or API                         │
│         ├─> Authenticate via NIP-42                            │
│         ├─> Build attestation JSON                              │
│         └─> POST /api/permit/attest                             │
│                                                                  │
│  2. API BACKEND (54321.py)                                      │
│     └─> Endpoint /api/permit/attest                             │
│         ├─> Validate NOSTR authentication                       │
│         ├─> Create PermitAttestation object                     │
│         └─> Call oracle_system.attest_permit()                 │
│                                                                  │
│  3. ORACLE SYSTEM (oracle_system.py)                            │
│     └─> OracleSystem.attest_permit()                            │
│         ├─> Verify request exists                               │
│         ├─> Verify attester has rights                          │
│         ├─> Generate cryptographic signature                    │
│         ├─> Create NOSTR event kind 30502                       │
│         ├─> Publish to NOSTR relays                             │
│         ├─> Check attestation threshold                         │
│         └─> [If threshold] → Issue Credential                   │
│                                                                  │
│  4. NOSTR RELAYS                                                 │
│     └─> Decentralized storage                                    │
│         ├─> Event kind 30502 (attestation)                      │
│         ├─> Ed25519 signature by attester                       │
│         └─> Verifiable by anyone                                │
│                                                                  │
│  5. CREDENTIAL ISSUANCE (if validated)                          │
│     └─> oracle_system.issue_credential()                        │
│         ├─> Create W3C Verifiable Credential                    │
│         ├─> Sign with UPLANETNAME.G1                            │
│         ├─> NOSTR event kind 30503                              │
│         ├─> Publish to relays                                    │
│         └─> Update holder DID                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2. Signature Types

The system uses **three levels of signatures**:

#### Level 1: Application-Level Signature

```python
# Attestation signature (SHA256)
signature = hashlib.sha256(
    f"{statement}:{attester_npub}:{timestamp}".encode()
).hexdigest()
```

**Purpose**: Unique identifier for the attestation

#### Level 2: NOSTR Event Signature (Schnorr)

```python
# Schnorr signature of the NOSTR event
event_signature = schnorr_sign(event_hash, attester_private_key)
```

**Purpose**: Prove the attester published the event

**Algorithm**: Schnorr signatures on secp256k1 curve

#### Level 3: Credential Signature (Ed25519)

```python
# Ed25519 signature by UPLANETNAME.G1
def _sign_credential(self, permit_request: PermitRequest) -> str:
    """
    Signs the credential with UPLANETNAME.G1 private key
    """
    # Load UPlanet private key
    uplanet_private_key = load_uplanet_g1_key()
    
    # Message to sign = hash of credential
    credential_data = {
        "permit_definition_id": permit_request.permit_definition_id,
        "holder_did": permit_request.applicant_did,
        "issued_at": datetime.now().isoformat(),
        "attestations": [a.attestation_id for a in permit_request.attestations]
    }
    
    message = json.dumps(credential_data, sort_keys=True).encode()
    message_hash = hashlib.sha256(message).digest()
    
    # Ed25519 signature
    signature = uplanet_private_key.sign(message_hash)
    
    # Encode as base58btc (multibase 'z' prefix)
    import base58
    proof_value = base58.b58encode(signature).decode('ascii')
    
    return f"z{proof_value}"  # Prefix 'z' = multibase base58btc
```

**Purpose**: Final authority certification

**Algorithm**: Ed25519 signatures (more secure than ECDSA)

### 6.3. Verification

```python
def verify_credential(credential: PermitCredential) -> bool:
    """
    Verify a complete Verifiable Credential
    """
    # 1. Verify UPlanet signature (Ed25519)
    credential_data = {
        "permit_definition_id": credential.permit_definition_id,
        "holder_did": credential.holder_did,
        "issued_at": credential.issued_at.isoformat(),
        "attestations": [a.attestation_id for a in credential.attestations]
    }
    
    message = json.dumps(credential_data, sort_keys=True).encode()
    message_hash = hashlib.sha256(message).digest()
    
    # Get UPlanet public key
    uplanet_public_key = get_uplanet_g1_public_key()
    
    # Decode signature (multibase 'z' format)
    proof_value = credential.proof["proofValue"]
    import base58
    signature_bytes = base58.b58decode(proof_value[1:])  # Skip 'z'
    
    # Verify Ed25519
    if not ed25519_verify(message_hash, signature_bytes, uplanet_public_key):
        return False
    
    # 2. Verify all attestations
    for attestation in credential.attestations:
        if not verify_attestation(attestation):
            return False
    
    # 3. Verify attestation threshold
    definition = get_permit_definition(credential.permit_definition_id)
    if len(credential.attestations) < definition.min_attestations:
        return False
    
    # 4. Check expiration
    if credential.expires_at and datetime.now() > credential.expires_at:
        return False
    
    return True  # ✅ Credential is valid
```

### 6.4. Chain of Trust

```
┌──────────────────────────────────────────────────────────────────┐
│                    CHAIN OF TRUST                                 │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  LEVEL 0: Ğ1 Web of Trust (Base)                                │
│     └─> Duniter certified members                                │
│         └─> 0.01Ğ1 transaction to MULTIPASS/ZEN Card            │
│             └─> Creates .2nd file (KYC WoT validation)          │
│                                                                   │
│  LEVEL 1: MULTIPASS (Decentralized Identity)                    │
│     └─> DID: did:nostr:{hex_pubkey}                             │
│         └─> Published on NOSTR (kind 0 with DID extension)      │
│             └─> Twin keys (G1, NOSTR, BTC, XMR)                 │
│                                                                   │
│  LEVEL 2: Expert Attestation                                     │
│     └─> Expert with valid permit attests                         │
│         └─> Schnorr signature (NOSTR)                           │
│             └─> Event kind 30502                                 │
│                 └─> Verifiable by all                            │
│                                                                   │
│  LEVEL 3: Multi-Signature (N experts)                           │
│     └─> Threshold reached (e.g., 5/5 attestations)              │
│         └─> Automatic validation                                 │
│             └─> Decentralized consensus                          │
│                                                                   │
│  LEVEL 4: UPlanet Authority Certification                        │
│     └─> UPLANETNAME.G1 signs Verifiable Credential              │
│         └─> Ed25519 signature                                    │
│             └─> Event kind 30503                                 │
│                 └─> W3C VC standard                              │
│                     └─> Added to holder DID                      │
│                                                                   │
│  LEVEL 5: DID Integration                                        │
│     └─> VC added to holder DID document                          │
│         └─> Published on NOSTR (kind 0 update)                  │
│             └─> Cryptographically verifiable                     │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```


---

## 7. Web of Trust Bootstrap

### 7.1. The "Chicken and Egg" Problem

When a new permit type is created (NOSTR event kind 30500), there are no initial holders. But to obtain a permit, you need attestations from existing holders. **How do you get the first holders if nobody can attest?**

### 7.2. "Block 0" Solution

The script `oracle.WoT_PERMIT.init.sh` resolves this by creating the **"Block 0"** through a process of **cross-attestation between initial members**.

**Key principle**: All initial members attest each other (except themselves), creating a mutual certification network.

### 7.3. Why N+1 Members for N Signatures?

For a permit requiring **N attestations**, you need **minimum N+1 members**.

#### Mathematical Explanation

Each member attests **all others** (except themselves):
- Total members: N+1
- Each member attests: (N+1) - 1 = **N others** ✅
- Each member receives: N attestations ✅

#### Concrete Example: PERMIT_ORE_V1 (5 attestations required)

**With 6 members (A, B, C, D, E, F)**:

| Member | Attests | Receives Attestations From |
|--------|---------|----------------------------|
| A | B,C,D,E,F | B,C,D,E,F (5) ✅ |
| B | A,C,D,E,F | A,C,D,E,F (5) ✅ |
| C | A,B,D,E,F | A,B,D,E,F (5) ✅ |
| D | A,B,C,E,F | A,B,C,E,F (5) ✅ |
| E | A,B,C,D,F | A,B,C,D,F (5) ✅ |
| F | A,B,C,D,E | A,B,C,D,E (5) ✅ |

**Total**: 6 × 5 = 30 cross-attestations

**With only 5 members?**
- Each member attests 4 others
- Each member receives only **4 attestations** ❌
- **INSUFFICIENT!** (need 5)

**This is why N+1 is the minimum**.

### 7.4. Bootstrap Process (6 Steps)

#### Step 1: Identify Un-Initialized Permits

```bash
./oracle.WoT_PERMIT.init.sh
```

Shows permits (kind 30500) with **no holders** (no kind 30503 events).

#### Step 2: Select Initial Members

The CAPTAIN selects N+1 MULTIPASS holders who will become initial holders.

**Requirements**:
- All must have MULTIPASS created via `make_NOSTRCARD.sh`
- Trusted community members
- Recognized expertise in permit domain

#### Step 3: Create Permit Requests (kind 30501)

For each member, create a request event:

```json
{
  "kind": 30501,
  "pubkey": "<MEMBER_PUBKEY>",
  "tags": [
    ["d", "<REQUEST_ID>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["status", "pending"]
  ],
  "content": "{\"statement\": \"Initial WoT member - Bootstrap attestation\"}",
  "sig": "<member_signature>"
}
```

#### Step 4: Cross-Attestation (kind 30502)

Each member attests **all others** (except themselves):

```
Alice attests → Bob, Carol, Dave, Eve, Frank
Bob attests → Alice, Carol, Dave, Eve, Frank
Carol attests → Alice, Bob, Dave, Eve, Frank
Dave attests → Alice, Bob, Carol, Eve, Frank
Eve attests → Alice, Bob, Carol, Dave, Frank
Frank attests → Alice, Bob, Carol, Dave, Eve
```

#### Step 5: Credential Issuance (kind 30503)

Once all members have N attestations, UPLANETNAME.G1 signs their credentials:

```json
{
  "kind": 30503,
  "pubkey": "<UPLANETNAME.G1_PUBKEY>",
  "tags": [
    ["d", "<CREDENTIAL_ID>"],
    ["p", "<ALICE_PUBKEY>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["attestation_count", "5"],
    ["attesters", "<BOB>", "<CAROL>", "<DAVE>", "<EVE>", "<FRANK>"]
  ],
  "content": "{W3C_VC}",
  "sig": "<uplanet_signature>"
}
```

#### Step 6: WoT Initialized ✅

The N+1 initial holders can now attest new applicants. The system is self-sustaining!

### 7.5. Script Usage

**Interactive mode** (recommended):
```bash
cd Astroport.ONE/tools
./oracle.WoT_PERMIT.init.sh
```

**Direct mode**:
```bash
./oracle.WoT_PERMIT.init.sh PERMIT_ORE_V1 \
    alice@example.com \
    bob@example.com \
    carol@example.com \
    dave@example.com \
    eve@example.com \
    frank@example.com
```

---

## 8. Available Permit Types

See `templates/NOSTR/permit_definitions.json` for full definitions:

1. **PERMIT_ORE_V1** - ORE Environmental Verifier
   - Required attestations: 5
   - Validity: 3 years
   - Purpose: Verify environmental obligations on UMAPs

2. **PERMIT_DRIVER** - Driver's License WoT Model
   - Required attestations: 12
   - Validity: 15 years
   - Purpose: Decentralized driving certification

3. **PERMIT_WOT_DRAGON** - UPlanet Authority
   - Required attestations: 3
   - Validity: Unlimited
   - Purpose: Infrastructure management, special powers

4. **PERMIT_MEDICAL_FIRST_AID** - First Aid Provider
   - Required attestations: 8
   - Validity: 2 years
   - Purpose: Emergency medical assistance

5. **PERMIT_BUILDING_ARTISAN** - Building Artisan
   - Required attestations: 10
   - Validity: 5 years
   - Purpose: Construction and renovation

6. **PERMIT_EDUCATOR_COMPAGNON** - Compagnon Educator
   - Required attestations: 12
   - Validity: Unlimited
   - Purpose: Teaching and mentoring

7. **PERMIT_FOOD_PRODUCER** - Local Food Producer
   - Required attestations: 6
   - Validity: 3 years
   - Purpose: Food production certification

8. **PERMIT_MEDIATOR** - Community Mediator
   - Required attestations: 15
   - Validity: 5 years
   - Purpose: Conflict resolution

---

## 9. Usage

### 9.1. Web Interface (/oracle)

**Access**: `https://u.copylaradio.com/oracle` (or `http://127.0.0.1:54321/oracle` for local)

⚠️ **Current Status**: The web interface is under active development. The HTML template (oracle.html) provides the UI structure, but full integration with the backend API is in progress.

**Implemented**:
- ✅ UI layout and styling
- ✅ NOSTR connection flow
- ✅ Chart.js visualizations

**In Development**:
- 🚧 Real-time data fetching from API
- 🚧 Permit request submission
- 🚧 Attestation submission
- 🚧 Credential verification

**For production use, interact directly with the API endpoints (see Section 10).**

**Interface Tabs**:
- 📜 **Available Permits**: Browse and request permits
- 🎯 **My Permits**: View your issued credentials
- ⏳ **Pending Requests**: Validate requests from others (if you have required permits)
- ✍️ **My Attestations**: Track attestations you've provided
- 🌱 **ORE Contracts**: View environmental obligations with map

### 9.2. API Usage Examples

#### Request a Permit

```bash
curl -X POST "${uSPOT}/api/permit/request" \
  -H "Content-Type: application/json" \
  -d '{
    "permit_definition_id": "PERMIT_ORE_V1",
    "applicant_npub": "npub1...",
    "statement": "I have 5 years experience in environmental assessment",
    "evidence": []
  }'
```

#### Attest a Request

```bash
curl -X POST "${uSPOT}/api/permit/attest" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "a1b2c3d4",
    "attester_npub": "npub1...",
    "statement": "I have personally verified their competence",
    "attester_license_id": null
  }'
```

#### Check Status

```bash
curl "${uSPOT}/api/permit/status/a1b2c3d4" | jq
```

#### Get Credential

```bash
curl "${uSPOT}/api/permit/credential/cred_xyz123" | jq
```

### 9.3. Workflow Examples

#### Example 1: ORE Environmental Verifier

1. **Alice requests** PERMIT_ORE_V1
2. **5 experts attest**: Bob, Carol, Dave, Eve, Frank
3. **Oracle validates**: 5 attestations ≥ 5 required
4. **Credential issued**: Signed by UPLANETNAME.G1
5. **Alice can now**: Verify ORE contracts and earn Ẑen

#### Example 2: Driver's License

1. **Charlie requests** PERMIT_DRIVER
2. **12 drivers attest**: Must have Driver's License themselves
3. **Oracle validates**: 12 attestations ≥ 12 required
4. **Insurance mutual formed**: 12 attesters become guarantors
5. **Charlie can drive**: Covered by mutual insurance

---

## 10. API Reference

### 10.1. Core Routes (CRUD)

#### POST /api/permit/request
Submit a new permit request (requires NIP-42)

**Body**:
```json
{
  "permit_definition_id": "PERMIT_ORE_V1",
  "applicant_npub": "npub1...",
  "statement": "My competence statement",
  "evidence": []
}
```

**Response**:
```json
{
  "success": true,
  "request_id": "a1b2c3d4",
  "status": "pending"
}
```

#### POST /api/permit/attest
Add attestation to a request (requires NIP-42)

**Body**:
```json
{
  "request_id": "a1b2c3d4",
  "attester_npub": "npub1...",
  "statement": "I certify this person",
  "attester_license_id": null
}
```

**Response**:
```json
{
  "success": true,
  "attestation_id": "b2c3d4e5",
  "status": "attesting",
  "attestations_count": 3
}
```

#### GET /api/permit/status/{request_id}
Get request status

**Response**:
```json
{
  "request_id": "a1b2c3d4",
  "permit_type": "ORE Environmental Verifier",
  "status": "attesting",
  "attestations_count": 3,
  "required_attestations": 5
}
```

#### GET /api/permit/list
List requests or credentials

**Query params**:
- `type`: "requests" or "credentials"
- `npub`: (optional) filter by user

**Examples**:
- `/api/permit/list?type=requests`
- `/api/permit/list?type=credentials&npub=npub1...`

#### GET /api/permit/credential/{credential_id}
Get W3C Verifiable Credential

Returns full W3C VC in JSON-LD format.

#### GET /api/permit/definitions
List all available permit types

### 10.2. NOSTR Integration Routes

#### GET /api/permit/nostr/fetch
Fetch events from NOSTR relays

**Query params**:
- `kind`: 30500, 30501, 30502, or 30503
- `npub`: (optional) filter by author

**Examples**:
- `/api/permit/nostr/fetch?kind=30500` (definitions)
- `/api/permit/nostr/fetch?kind=30501` (requests)
- `/api/permit/nostr/fetch?kind=30503&npub=npub1...` (my credentials)

### 10.3. Maintenance Routes (Admin)

#### POST /api/permit/issue/{request_id}
Manually trigger credential issuance (idempotent)

Used by `ORACLE.refresh.sh` for automatic issuance.

#### POST /api/permit/expire/{request_id}
Mark request as expired (> 90 days)

#### POST /api/permit/revoke/{credential_id}
Revoke a credential

**Query param**:
- `reason`: Revocation reason

### 10.4. Authentication

**Routes requiring NIP-42**:
- `POST /api/permit/request`
- `POST /api/permit/attest`

**Admin routes** (UPLANETNAME.G1 only):
- `POST /api/permit/define`
- `POST /api/permit/issue/{id}`
- `POST /api/permit/revoke/{id}`

**Public routes**:
- All GET endpoints

### 10.5. Route Summary Table

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/permit/define` | POST | Admin | Create permit definition |
| `/api/permit/request` | POST | NIP-42 | Submit request |
| `/api/permit/attest` | POST | NIP-42 | Add attestation |
| `/api/permit/status/{id}` | GET | - | Get status |
| `/api/permit/list` | GET | - | List permits |
| `/api/permit/credential/{id}` | GET | - | Get VC |
| `/api/permit/definitions` | GET | - | List definitions |
| `/api/permit/nostr/fetch` | GET | - | Fetch NOSTR events |
| `/api/permit/issue/{id}` | POST | Admin | Issue credential |
| `/api/permit/expire/{id}` | POST | Admin | Expire request |
| `/api/permit/revoke/{id}` | POST | Admin | Revoke credential |


---

## 11. Daily Maintenance

### 11.1. ORACLE.refresh.sh Overview

The script `ORACLE.refresh.sh` ensures daily automated maintenance of the Oracle System. It is executed daily by `UPLANET.refresh.sh`.

**Location**: `Astroport.ONE/RUNTIME/ORACLE.refresh.sh`

**Execution**: Daily via cron (called by UPLANET.refresh.sh)

### 11.2. Six Daily Tasks

1. **Process Pending Requests**
   - Fetch all requests with status `pending` or `attesting`
   - Check attestation count vs required threshold
   - Auto-issue credentials when threshold reached

2. **Expire Old Requests**
   - Identify requests > 90 days old
   - Mark as expired
   - Clean up abandoned applications

3. **Revoke Expired Credentials**
   - Check credential expiration dates
   - Mark expired credentials as inactive
   - Allow renewal via new request

4. **Generate Statistics**
   - Count requests per permit type
   - Count credentials per permit type
   - Create JSON files in `~/.zen/tmp/${IPFSNODEID}/ORACLE/`

5. **Publish to NOSTR**
   - Daily report signed by UPLANETNAME.G1
   - Kind 1 event with global statistics
   - Hashtags: #UPlanet #Oracle #WoT #Permits

6. **Cleanup**
   - Remove temporary files > 7 days
   - Maintain disk space

### 11.3. Configuration

**Environment variables**:
```bash
export uSPOT="http://127.0.0.1:54321"
export myRELAY="wss://relay.copylaradio.com"
export UPLANETNAME="EnfinLibre"
export IPFSNODEID="QmXXXXXXXXXXXXXXXXX"
```

**Customization**:
- Change expiration delay (default 90 days): Edit line with `age_days -gt 90`
- Change publication frequency: Add condition `if [[ $daily_issued -gt 0 ]]`

### 11.4. Statistics Generated

**Global stats** (`global_stats.json`):
```json
{
    "total_requests": 42,
    "total_credentials": 38,
    "last_updated": "2025-11-05T12:00:00Z",
    "uplanet": "EnfinLibre",
    "ipfs_node": "QmXXXXXXXXXXXXXXXXX"
}
```

**Per-permit stats** (`PERMIT_ORE_V1.json`):
```json
{
    "permit_id": "PERMIT_ORE_V1",
    "permit_name": "ORE Environmental Verifier",
    "requests_count": 12,
    "credentials_count": 10,
    "last_updated": "2025-11-05T12:00:00Z"
}
```

---

## 12. Testing

### 12.1. Test Suite Overview

A comprehensive test suite validates the entire permit system workflow.

**Script**: `Astroport.ONE/tools/test_permit_system.sh`

### 12.2. Test Modes

#### Interactive Mode
```bash
./test_permit_system.sh
```

Shows menu with 11 test options.

#### Automated Mode
```bash
./test_permit_system.sh --all
```

Runs all tests sequentially.

### 12.3. Test Scenarios

| # | Test | What it validates |
|---|------|-------------------|
| 1 | Permit Definitions | API returns permit types |
| 2 | Permit Request | Submit application successfully |
| 3 | Attestations | Multi-signature validation |
| 4 | Permit Status | Status tracking works |
| 5 | Permit Listing | List filtering works |
| 6 | Credential Retrieval | W3C VC format correct |
| 7 | Helper Scripts | CLI tools exist |
| 8 | Blockchain Transfer | PERMIT payment works |
| 9 | Oracle System | Python module loads |

### 12.4. Prerequisites

1. **API running**:
```bash
cd UPassport
python 54321.py
```

2. **Dependencies installed**:
```bash
curl --version
jq --version
python3 --version
pip install fastapi uvicorn pydantic nostr
```

3. **Permit definitions loaded** (automatic on API start)

4. **For blockchain tests** (optional):
```bash
# Configure RnD wallet
cd Astroport.ONE
./ZEN.COOPERATIVE.3x1-3.sh

# Create test MULTIPASS
./tools/make_NOSTRCARD.sh test@example.com
```

### 12.5. Troubleshooting Tests

**API not available**:
```
[ERROR] API non disponible à http://localhost:54321
```
→ Start the FastAPI server first

**Missing dependencies**:
```
[ERROR] jq n'est pas installé
```
→ Install: `sudo apt-get install curl jq bc openssl`

**Blockchain tests fail**:
```
[ERROR] Portefeuille UPLANETNAME_RnD non configuré
```
→ Run wallet setup scripts first

---

## 13. Integration with UPlanet

### 13.1. DID Documents

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

**DID Document Updates**: The Oracle System automatically updates the holder's DID document when credentials are issued. This integration ensures that permits are permanently linked to the user's decentralized identity.

> **🔗 For complete DID architecture**, see [`DID_IMPLEMENTATION.md`](../../DID_IMPLEMENTATION.md) which explains:
> - How DID documents are structured and published
> - NOSTR-native DID resolution (kind 30800)
> - Integration with Ğ1 blockchain and Web of Trust
> - SSSS 3/2 secret sharing for security
> - France Connect compliance for verified users

### 13.2. Blockchain Rewards

Permit holders can receive economic incentives via `UPLANET.official.sh`:

```bash
./UPLANET.official.sh -p dragon@example.com PERMIT_WOT_DRAGON -m 100
```

This:
- Transfers 100 Ẑen from UPLANETNAME_RnD to holder
- Records transaction on Ğ1 blockchain
- Updates holder's DID document

**Rewards by permit**:
- **WoT Dragon**: 100 Ẑen (infrastructure authority)
- **ORE Verifier**: Variable (per verification)
- **Mediator**: Variable (per conflict resolution)

### 13.3. N1/N2 Network Integration

The permit system integrates with N1/N2 social network:
- Attesters typically found in N1 (direct contacts) or N2 (friends of friends)
- Community mediation uses permits to validate mediators
- Insurance mutuals use permits to validate competencies

---

## 14. Troubleshooting

### 14.1. Common Errors

**Error: NOSTR keyfile not found**
```
[ERROR] NOSTR keyfile not found for: alice@example.com
```
**Solution**: Create MULTIPASS
```bash
cd Astroport.ONE/tools
./make_NOSTRCARD.sh alice@example.com
```

**Error: Failed to send NIP-42 authentication**
```
[ERROR] Failed to send NIP-42 authentication
```
**Solutions**:
1. Check relay is accessible: `curl -s wss://relay.copylaradio.com`
2. Verify nostr_send_note.py works: `python3 nostr_send_note.py --help`
3. Check keyfile permissions: `ls -la ~/.zen/game/nostr/*/. secret.nostr`

**Error: Cannot access Oracle API**
```
[ERROR] Cannot access Oracle API
```
**Solution**: Start the API
```bash
cd UPassport
python 54321.py
```

**Error: Credentials not issued automatically**
```
Request has 5 attestations but no credential
```
**Solutions**:
1. Wait for ORACLE.refresh.sh to run (daily)
2. Manually trigger: `curl -X POST ${uSPOT}/api/permit/issue/${request_id}`
3. Check logs: `tail -f ~/.zen/tmp/UPassport.log`

### 14.2. API Debugging

**Enable debug mode**:
```bash
export DEBUG=1
cd UPassport
python 54321.py
```

**Check NOSTR relay**:
```bash
# Test connection
websocat wss://relay.copylaradio.com

# Fetch events
./tools/nostr_get_events.sh --kind 30500
```

**Verify signatures**:
```bash
# Check UPLANETNAME.G1 key
cat ~/.zen/game/uplanet.G1.nostr

# Verify credential
curl ${uSPOT}/api/permit/credential/${cred_id} | jq '.proof'
```

### 14.3. Statistics Not Generated

**Problem**: No files in `~/.zen/tmp/${IPFSNODEID}/ORACLE/`

**Solutions**:
1. Check directory permissions:
```bash
mkdir -p ~/.zen/tmp/${IPFSNODEID}/ORACLE
chmod 755 ~/.zen/tmp/${IPFSNODEID}/ORACLE
```

2. Verify jq is installed:
```bash
sudo apt-get install jq
```

3. Run maintenance manually:
```bash
cd Astroport.ONE/RUNTIME
./ORACLE.refresh.sh
```

---

## 15. References

### 15.1. External Standards

- **W3C DID Core**: https://www.w3.org/TR/did-core/
- **W3C Verifiable Credentials**: https://www.w3.org/TR/vc-data-model/
- **Ed25519 Signature 2020**: https://w3c-ccg.github.io/lds-ed25519-2020/

### 15.2. NOSTR NIPs

- **NIP-01**: Basic Protocol - https://github.com/nostr-protocol/nips/blob/master/01.md
- **NIP-33**: Parameterized Replaceable Events - https://github.com/nostr-protocol/nips/blob/master/33.md
- **NIP-42**: Authentication - https://github.com/nostr-protocol/nips/blob/master/42.md

### 15.3. UPlanet Documentation

- **DID_IMPLEMENTATION.md**: Complete DID system architecture and implementation
- **ORACLE_TODO.md**: Task tracking and improvements
- **ORE_SYSTEM.md**: Environmental obligations system

### 15.4. Philosophy

- **CopyLaRadio Article**: Web of Trust model - https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148

### 15.5. Tools

- **nostr_send_note.py**: Publish events to NOSTR
- **make_NOSTRCARD.sh**: Create MULTIPASS identity
- **UPLANET.official.sh**: Blockchain rewards

---

## 16. FAQ

### 16.1. General Questions

**Q: What is the difference between a permit and a credential?**

A: A **permit** is a type of certification (e.g., "Driver's License"). A **credential** is the issued proof that someone holds that permit.

**Q: Can I have multiple permits?**

A: Yes! A user can hold multiple credentials for different permit types.

**Q: Do permits expire?**

A: Some do, some don't. Check the `valid_duration_days` field in the permit definition. For example:
- WoT Dragon: Unlimited
- ORE Verifier: 3 years
- Driver's License: 15 years

### 16.2. Technical Questions

**Q: What happens if an attester's credential is revoked?**

A: All credentials they attested become suspect and may be revoked as well (revocation cascade).

**Q: Can I attest myself?**

A: No. The system explicitly prevents self-attestation.

**Q: What if I lose my NOSTR keys?**

A: Your identity and all credentials are tied to your NOSTR keypair. **Backup your keyfile** (`~/.zen/game/nostr/EMAIL/.secret.nostr`) securely. If lost, you must create a new MULTIPASS and restart the permit request process.

**Q: Why does the web interface show fake data?**

A: The web interface (`/oracle`) is currently under development. Real-time API integration is in progress. Use the API endpoints directly for production.

### 16.3. Process Questions

**Q: How long does it take to get a permit?**

A: It depends on how quickly you receive attestations. Once you have enough attestations, credentials are issued automatically during the daily maintenance (ORACLE.refresh.sh).

**Q: Can I request a permit without a MULTIPASS?**

A: No. You must have a MULTIPASS created via `make_NOSTRCARD.sh` before requesting any permit.

**Q: What if nobody attests my request?**

A: After 90 days with insufficient attestations, the request expires. You can submit a new request.

**Q: Can I renew an expired permit?**

A: Yes. Submit a new permit request. Some of your previous attesters may attest again.

### 16.4. Bootstrap Questions

**Q: Who can initialize a new permit's WoT?**

A: Only the CAPTAIN of the station (admin with UPLANETNAME.G1 keys) can run the bootstrap script.

**Q: Can we add more members to an existing WoT?**

A: Yes. New members can request the permit and be attested by existing holders through the normal process.

**Q: What if we initialized with too few members?**

A: Run the bootstrap script again with additional members, or let them join via normal attestation.

---

## 📊 Statistics

**System Capabilities**:
- 8 default permit types
- Unlimited permit types (extensible)
- Multi-signature validation (3-15 attestations)
- W3C VC standard compliance
- NOSTR decentralized storage
- Daily automated maintenance
- Blockchain economic integration

**Components**:
- 1 core Python module (oracle_system.py)
- 1 API server (54321.py, 11 routes)
- 1 web interface (oracle.html)
- 1 maintenance script (ORACLE.refresh.sh)
- 1 bootstrap script (oracle.WoT_PERMIT.init.sh)
- 4 NOSTR event kinds (30500-30503)

---

## 🤝 Contributing

The Oracle System is part of the UPlanet/Astroport.ONE ecosystem. To contribute:

1. Understand the WoT model from the CopyLaRadio article
2. Propose new permit types via `permit_definitions.json`
3. Test the attestation flow with your community
4. Report issues and suggest improvements
5. Submit pull requests with documentation

---

## 📝 License

**AGPL-3.0**

The Oracle System is free and open-source software. You are free to use, modify, and distribute it under the terms of the AGPL-3.0 license.

---

## ✉️ Support

- **Email**: support@qo-op.com
- **Project**: UPlanet / Astroport.ONE
- **Repository**: (see project documentation)

---

## 📅 Document History

- **v1.0** (October 2025): Initial documentation split across 7 files
- **v2.0** (November 5, 2025): Consolidated into single comprehensive document
  - Fixed NIP-101 reference (corrected to kind 0 with DID extension)
  - Fixed base64/base58 signature encoding inconsistency
  - Unified MULTIPASS creation script references
  - Eliminated documentation redundancies
  - Improved "N+1 members" explanation
  - Clarified web interface development status

---

## 🎯 Quick Links

- **Section 1**: [Overview & Philosophy](#1-overview--philosophy)
- **Section 4**: [Authentication](#4-authentication--security)
- **Section 7**: [Bootstrap Process](#7-web-of-trust-bootstrap)
- **Section 9**: [Usage Guide](#9-usage)
- **Section 10**: [API Reference](#10-api-reference)
- **Section 14**: [Troubleshooting](#14-troubleshooting)
- **Section 16**: [FAQ](#16-faq)

---

**End of Oracle System Documentation**

**Last Updated**: November 5, 2025  
**Version**: 2.0  
**Maintained by**: UPlanet Development Team  
**Status**: Complete & Consolidated

