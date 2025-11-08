# 🔐 UPlanet Oracle System - Complete Documentation

**Version**: 2.1  
**Date**: December 2025  
**Status**: Updated with WoTx2 System  
**License**: AGPL-3.0

> **Note**: This document consolidates 7 previous Oracle documentation files into a single, comprehensive reference.  
> **Update v2.1**: Added WoTx2 evolving permits system and decentralized architecture.

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

### 2.1.1. WoTx2: Evolving Web of Trust

**WoTx2** is an advanced permit system where competencies can be **discovered and expanded** through attestations:

- **Traditional WoT**: Fixed competencies defined at permit creation
- **WoTx2**: Competencies can be revealed during attestations, expanding the permit's scope
- **Virtuous Circle**: Students become instructors, discovering new talents through the attestation process

**Example**: PERMIT_DE_NAGER (Swimming Instructor)
- Base competencies: Swimming instruction, Water safety, Rescue techniques
- Revealed competencies: Synchronized swimming, Open water rescue, Aqua-fitness (discovered during attestations)
- The more competencies, the more attestations required (2 + number of competencies)

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
│  1. WEB INTERFACES                                              │
│     ├─> /oracle (oracle.html) - General permit management      │
│     └─> /wotx2 (wotx2.html) - WoTx2 evolving permits            │
│         ├─> Bootstrap 5 UI                                      │
│         ├─> Direct NOSTR event creation (30501/30502)           │
│         └─> NOSTR.bundle.js (client-side signing)               │
│                                                                  │
│  2. API BACKEND (54321.py)                                      │
│     └─> FastAPI application                                     │
│         ├─> Permit definitions (30500) - UPLANETNAME.G1 only    │
│         ├─> Credential issuance (30503) - UPLANETNAME.G1 only  │
│         └─> Data initialization for frontend                    │
│         ⚠️  Requests (30501) & Attestations (30502) are        │
│            created directly by MULTIPASS via Nostr (not API)     │
│                                                                  │
│  3. CORE SYSTEM (oracle_system.py)                              │
│     └─> Python module                                               │
│         ├─> PermitDefinition                                    │
│         ├─> PermitCredential                                    │
│         └─> Credential issuance logic                           │
│                                                                  │
│  4. NOSTR RELAYS                                                 │
│     └─> Decentralized storage                                    │
│         ├─> Events: kinds 30500-30503                          │
│         ├─> 30500/30503: Published by UPLANETNAME.G1           │
│         ├─> 30501/30502: Published by MULTIPASS users           │
│         └─> Public verifiability                                │
│                                                                  │
│  5. MAINTENANCE (ORACLE.refresh.sh)                             │
│     └─> Daily automated tasks                                    │
│         ├─> Process pending requests (from Nostr)               │
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

**Decentralized Architecture** (v2.1):

```
1. PERMIT DEFINITION (30500)
   UPLANETNAME.G1 → API (/api/permit/define) → oracle_system.py → NOSTR (kind 30500)
   
2. REQUEST (30501) - DECENTRALIZED
   User → wotx2.html → window.nostr.signEvent() → NOSTR (kind 30501)
   ⚠️  No API call - direct Nostr event creation
   
3. ATTESTATION (30502) - DECENTRALIZED
   Expert → wotx2.html → window.nostr.signEvent() → NOSTR (kind 30502)
   ⚠️  No API call - direct Nostr event creation
   
4. VALIDATION
   ORACLE.refresh.sh → Fetch from Nostr → Check attestations → Auto-issue if threshold
   
5. CREDENTIAL (30503)
   ORACLE.refresh.sh → API (/api/permit/issue) → Sign with UPLANETNAME.G1 → NOSTR (kind 30503) → DID update
   
6. REWARD (optional)
   UPLANET.official.sh -p email PERMIT_ID → Blockchain payment
```

**Key Change**: Events 30501 and 30502 are now created **directly by MULTIPASS users** via Nostr, not through the API. This makes the system fully decentralized.

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
| **30501** | Permit Request | Applicant (MULTIPASS) | Application from a user - **Created directly via Nostr** |
| **30502** | Permit Attestation | Attester (MULTIPASS) | Expert signature/attestation - **Created directly via Nostr** |
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

**Published by**: Applicant (MULTIPASS holder) - **Directly via Nostr, not through API**

**Note**: Since v2.1, requests are created directly by users in `wotx2.html` using `window.nostr.signEvent()`. The API no longer handles 30501 events.

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

**Published by**: Attester (expert with valid credential) - **Directly via Nostr, not through API**

**Note**: Since v2.1, attestations are created directly by users in `wotx2.html` using `window.nostr.signEvent()`. The API no longer handles 30502 events.

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
    
    # CRITICAL: Canonicalize JSON before signing (RFC 8785)
    message = canonicalize_json(credential_data).encode()
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

### 6.2.1. JSON Canonicalization (RFC 8785)

**CRITICAL**: All JSON content in NOSTR events must be canonicalized before signing to ensure signature consistency.

#### Why Canonicalization is Required

When signing NOSTR events whose `content` field contains JSON, the same logical data must always produce the same string representation. Without canonicalization:

- Different key ordering produces different hashes
- Whitespace variations break signature verification
- Floating-point formatting differences cause mismatches
- **Result**: Signatures fail verification even with valid data

#### Implementation (RFC 8785 - JCS)

The Oracle System implements **JSON Canonicalization Scheme (JCS)** as specified in [RFC 8785](https://datatracker.ietf.org/doc/html/rfc8785):

```python
def canonicalize_json(data: Any) -> str:
    """
    Canonicalize JSON according to RFC 8785 (JCS - JSON Canonicalization Scheme).
    
    This ensures that the same JSON data always produces the same string representation,
    which is critical for cryptographic signatures.
    """
    return json.dumps(
        data,
        sort_keys=True,           # Lexicographic key ordering
        separators=(',', ':'),   # No whitespace (compact)
        ensure_ascii=False,      # Preserve Unicode
        allow_nan=False          # Reject NaN/Infinity (not in JSON spec)
    )
```

#### Canonicalization Rules

1. **Key Ordering**: All object keys sorted lexicographically (UTF-8 byte order)
2. **Whitespace**: No spaces between tokens (`separators=(',', ':')`)
3. **Numbers**: Standard JSON number format (no leading zeros, no trailing zeros)
4. **Unicode**: Preserved as-is (no ASCII escaping)
5. **Special Values**: `NaN`, `Infinity` rejected (not valid JSON)

#### Usage in Oracle System

All NOSTR event content is canonicalized:

- **Kind 30500** (Permit Definition): `canonicalize_json(asdict(definition))`
- **Kind 30501** (Permit Request): `canonicalize_json({...})`
- **Kind 30502** (Permit Attestation): `canonicalize_json({...})`
- **Kind 30503** (Permit Credential): `canonicalize_json({...})` (especially critical for W3C VCs)
- **Credential Signing**: `canonicalize_json(credential_data)` before hashing

#### Example: Before vs After Canonicalization

**Before** (non-canonical):
```json
{
  "request_id": "abc123",
  "status": "pending",
  "applicant_did": "did:nostr:xyz"
}
```

**After** (canonical):
```json
{"applicant_did":"did:nostr:xyz","request_id":"abc123","status":"pending"}
```

**Note**: The canonical form has:
- Keys sorted: `applicant_did` < `request_id` < `status`
- No whitespace
- Consistent formatting

#### NIP-101 Recommendation

For NOSTR events containing Verifiable Credentials (kinds 30503), the NIP-101 specification should mandate RFC 8785 canonicalization to ensure:

- Cross-platform signature compatibility
- Verifiable Credential standard compliance (W3C VC)
- Deterministic event IDs
- Reliable signature verification

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
    
    # CRITICAL: Canonicalize JSON before verification (RFC 8785)
    message = canonicalize_json(credential_data).encode()
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

### 7.3. Bootstrap Requirements

#### Standard Permits: N+1 Members for N Attestations

For a permit requiring **N attestations**, you need **minimum N+1 members**.

**Mathematical Explanation**:
- Total members: N+1
- Each member attests: (N+1) - 1 = **N others** ✅
- Each member receives: N attestations ✅

#### WoTx2 Permits: Special Bootstrap (2 Attestations)

**WoTx2 permits** (like PERMIT_DE_NAGER) use a simplified bootstrap:
- **Bootstrap phase**: Only **2 attestations** required for the first cycle
- **Normal phase**: After first holders exist, reverts to standard requirement (e.g., 6+ attestations)
- **Rationale**: Allows easier initial setup while maintaining security after bootstrap

**Example**: PERMIT_DE_NAGER
- Normal requirement: 6 attestations
- Bootstrap requirement: 2 attestations (for first kind 30501/30502 cycle)
- After bootstrap: Returns to 6 attestations for new applicants

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

### 8.1. Standard Permits

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

### 8.2. WoTx2 Evolving Permits

9. **PERMIT_DE_NAGER** - Swimming Instructor (WoTx2)
   - Required attestations: 6 (normal), 2 (bootstrap)
   - Validity: 3 years
   - Purpose: Swimming instruction and water safety
   - **Special**: Competencies can be discovered during attestations
   - **Bootstrap**: Only 2 attestations needed for initial "Block 0"
   - **Interface**: `/wotx2` - Create and manage WoTx2 permits

**Creating New WoTx2 Permits**: Users can create new professional permits via the `/wotx2` interface. The system automatically calculates `min_attestations` based on the number of competencies (2 + number of competencies).

---

## 9. Usage

### 9.1. Web Interfaces

#### /oracle - General Permit Management

**Access**: `https://u.copylaradio.com/oracle` (or `http://127.0.0.1:54321/oracle` for local)

⚠️ **Current Status**: The web interface is under active development. The HTML template (oracle.html) provides the UI structure, but full integration with the backend API is in progress.

**Interface Tabs**:
- 📜 **Available Permits**: Browse and request permits
- 🎯 **My Permits**: View your issued credentials
- ⏳ **Pending Requests**: Validate requests from others (if you have required permits)
- ✍️ **My Attestations**: Track attestations you've provided
- 🌱 **ORE Contracts**: View environmental obligations with map

#### /wotx2 - WoTx2 Evolving Permits Interface

**Access**: `https://u.copylaradio.com/wotx2` (or `http://127.0.0.1:54321/wotx2` for local)

**Features**:
- ✅ **Create New Permits**: Form to create new WoTx2 professional permits (kind 30500)
- ✅ **Direct Nostr Integration**: Create requests (30501) and attestations (30502) directly via Nostr
- ✅ **Permit Selector**: Choose from all available permits
- ✅ **Bootstrap Support**: Initialize new permits with 2+ emails
- ✅ **Real-time Data**: Loads requests and credentials directly from Nostr relays
- ✅ **Competency Discovery**: Reveal new competencies during attestations

**Workflow**:
1. Select or create a permit
2. Create request (30501) - signed directly by your MULTIPASS
3. Others attest (30502) - signed directly by their MULTIPASS
4. ORACLE.refresh.sh issues credential (30503) when threshold reached

**Note**: This interface is **fully decentralized** - no API calls for 30501/30502 events.

### 9.2. Creating Permits and Events

#### Create a Permit Definition (30500) - API

```bash
curl -X POST "${uSPOT}/api/permit/define" \
  -H "Content-Type: application/json" \
  -d '{
    "permit": {
      "id": "PERMIT_EXAMPLE",
      "name": "Example Permit",
      "description": "Description here",
      "min_attestations": 5,
      "valid_duration_days": 1095,
      "metadata": {"category": "general"}
    },
    "npub": "npub1...",
    "bootstrap_emails": ["email1@example.com", "email2@example.com"]
  }'
```

**Note**: Requires NIP-42 authentication. Creates kind 30500 event signed by UPLANETNAME.G1.

#### Create a Permit Request (30501) - Direct Nostr

**Via wotx2.html interface** (recommended):
1. Connect MULTIPASS
2. Select permit
3. Click "Create Request"
4. Fill form and submit
5. Event 30501 is created and published directly to your Nostr relays

**Manual (JavaScript)**:
```javascript
const event = {
  kind: 30501,
  content: JSON.stringify({
    request_id: "...",
    permit_definition_id: "PERMIT_ORE_V1",
    statement: "My competence statement",
    evidence: []
  }),
  tags: [["d", "request_id"], ["l", "PERMIT_ORE_V1", "permit_type"]],
  created_at: Math.floor(Date.now() / 1000)
};
const signedEvent = await window.nostr.signEvent(event);
// Publish to relays
```

#### Create an Attestation (30502) - Direct Nostr

**Via wotx2.html interface** (recommended):
1. View pending requests
2. Click "Attest this request"
3. Fill attestation form
4. Event 30502 is created and published directly to your Nostr relays

**Manual (JavaScript)**:
```javascript
const event = {
  kind: 30502,
  content: JSON.stringify({
    attestation_id: "...",
    request_id: "request_id",
    statement: "I certify this person",
    signature: "..."
  }),
  tags: [["d", "attestation_id"], ["e", "request_id"]],
  created_at: Math.floor(Date.now() / 1000)
};
const signedEvent = await window.nostr.signEvent(event);
// Publish to relays
```

#### Check Status (from Nostr)

```bash
# Fetch request from Nostr
curl "${uSPOT}/api/permit/nostr/fetch?kind=30501&npub=<applicant_npub>" | jq
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

### 10.1. Core Routes

#### POST /api/permit/define
Create a new permit definition (requires NIP-42, creates kind 30500)

**Body**:
```json
{
  "permit": {
    "id": "PERMIT_EXAMPLE",
    "name": "Example Permit",
    "description": "Description",
    "min_attestations": 5,
    "valid_duration_days": 1095,
    "metadata": {"category": "general", "competencies": [...]}
  },
  "npub": "npub1...",
  "bootstrap_emails": ["email1@example.com", "email2@example.com"]
}
```

**Response**:
```json
{
  "success": true,
  "definition_id": "PERMIT_EXAMPLE",
  "min_attestations": 5,
  "bootstrap_initiated": true
}
```

**Note**: Creates kind 30500 event signed by UPLANETNAME.G1. Optionally triggers bootstrap initialization.

#### ⚠️ POST /api/permit/request - REMOVED (v2.1)
**This route is no longer available**. Permit requests (30501) must be created directly by MULTIPASS users via Nostr in `wotx2.html` or using `window.nostr.signEvent()`.

#### ⚠️ POST /api/permit/attest - REMOVED (v2.1)
**This route is no longer available**. Permit attestations (30502) must be created directly by MULTIPASS users via Nostr in `wotx2.html` or using `window.nostr.signEvent()`.

#### ⚠️ GET /api/permit/status/{request_id} - REMOVED (v2.1)
**This route is no longer available**. Permit requests (30501) are now stored in Nostr. Use `/api/permit/nostr/fetch?kind=30501` to fetch requests from Nostr.

#### ⚠️ GET /api/permit/list - REMOVED (v2.1)
**This route is no longer available**. Permit requests (30501) are now stored in Nostr. Use `/api/permit/nostr/fetch?kind=30501` or `/api/permit/nostr/fetch?kind=30503` to fetch from Nostr.

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

**Note**: Since v2.1, this endpoint reads the request from Nostr (kind 30501) before issuing the credential. The request must be validated (have enough attestations from kind 30502 events).

#### ⚠️ POST /api/permit/expire/{request_id} - REMOVED (v2.1)
**This route is no longer available**. Permit requests (30501) are now stored in Nostr. Expiration is handled by ORACLE.refresh.sh which reads from Nostr.

#### POST /api/permit/revoke/{credential_id}
Revoke a credential

**Query param**:
- `reason`: Revocation reason

### 10.4. Authentication

**Routes requiring NIP-42**:
- `POST /api/permit/define` (any authenticated user can create permits)

**Admin routes** (UPLANETNAME.G1 only):
- `POST /api/permit/issue/{id}` (credential issuance)
- `POST /api/permit/revoke/{id}` (credential revocation)

**Public routes**:
- All GET endpoints

**Decentralized (no API)**:
- `30501` (Permit Request) - Created directly by MULTIPASS via Nostr
- `30502` (Permit Attestation) - Created directly by MULTIPASS via Nostr

### 10.5. Route Summary Table

| Endpoint | Method | Auth | Purpose | Notes |
|----------|--------|------|---------|-------|
| `/api/permit/define` | POST | NIP-42 | Create permit definition | Creates 30500 |
| `/api/permit/request` | ~~POST~~ | ~~NIP-42~~ | ~~Submit request~~ | **REMOVED v2.1** - Use Nostr directly |
| `/api/permit/attest` | ~~POST~~ | ~~NIP-42~~ | ~~Add attestation~~ | **REMOVED v2.1** - Use Nostr directly |
| `/api/permit/status/{id}` | ~~GET~~ | ~~-~~ | ~~Get status~~ | **REMOVED v2.1** - Use `/api/permit/nostr/fetch` |
| `/api/permit/list` | ~~GET~~ | ~~-~~ | ~~List permits~~ | **REMOVED v2.1** - Use `/api/permit/nostr/fetch` |
| `/api/permit/credential/{id}` | GET | - | Get VC | Reads from Nostr |
| `/api/permit/definitions` | GET | - | List definitions | Reads from Nostr |
| `/api/permit/nostr/fetch` | GET | - | Fetch NOSTR events | Direct Nostr query |
| `/api/permit/issue/{id}` | POST | Admin | Issue credential | Creates 30503 |
| `/api/permit/expire/{id}` | ~~POST~~ | ~~Admin~~ | ~~Expire request~~ | **REMOVED v2.1** - Handled by ORACLE.refresh.sh |
| `/api/permit/revoke/{id}` | POST | Admin | Revoke credential | Maintenance |

**Web Interfaces**:
- `/oracle` - General permit management (development)
- `/wotx2` - WoTx2 evolving permits (production-ready)


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

**Q: How do I create a permit request?**

A: Use the `/wotx2` interface. Connect your MULTIPASS, select a permit, and click "Create Request". The request (30501) is created directly via Nostr - no API call needed.

**Q: How do I attest someone's request?**

A: Use the `/wotx2` interface. View pending requests and click "Attest this request". The attestation (30502) is created directly via Nostr - no API call needed.

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

**Q: What's the difference between standard permits and WoTx2 permits?**

A: 
- **Standard permits**: Fixed competencies defined at creation
- **WoTx2 permits**: Competencies can be discovered and expanded during attestations. Bootstrap requires only 2 attestations (vs N+1 for standard permits).

**Q: Can I create my own professional permit?**

A: Yes! Use the `/wotx2` interface, click "NEW - Créer une Profession", fill the form with competencies and responsibilities. The system automatically calculates `min_attestations` based on the number of competencies.

---

## 📊 Statistics

**System Capabilities**:
- 8+ default permit types (standard + WoTx2)
- Unlimited permit types (extensible via `/wotx2`)
- Multi-signature validation (2-15 attestations)
- W3C VC standard compliance
- Fully decentralized (30501/30502 via Nostr)
- NOSTR decentralized storage
- Daily automated maintenance
- Blockchain economic integration

**Components**:
- 1 core Python module (oracle_system.py)
- 1 API server (54321.py, simplified routes)
- 2 web interfaces (oracle.html, wotx2.html)
- 1 maintenance script (ORACLE.refresh.sh)
- 1 bootstrap script (oracle.WoT_PERMIT.init.sh)
- 4 NOSTR event kinds (30500-30503)
- Client-side Nostr integration (wotx2.html)

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
- **v2.1** (December 2025): Added WoTx2 system and decentralized architecture
  - Documented WoTx2 evolving permits system
  - Updated architecture to reflect decentralized 30501/30502 creation
  - Added `/wotx2` interface documentation
  - Documented special bootstrap for WoTx2 permits (2 attestations)
  - Removed deprecated API routes (/api/permit/request, /api/permit/attest)
  - Clarified that API only handles 30500 and 30503

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

**Last Updated**: December 2025  
**Version**: 2.1  
**Maintained by**: UPlanet Development Team  
**Status**: Complete & Updated with WoTx2

