# 🔐 Oracle System - Attestation Flow & NOSTR Events

> **⚠️ NOTE**: This document provides technical implementation details of the attestation process.
> While it references CLI scripts for illustration, the **current workflow uses the `/oracle` web interface**
> with NIP-42 authentication. The underlying cryptographic process remains identical.
>
> **For usage instructions**: See [ORACLE_SYSTEM.md](ORACLE_SYSTEM.md)

## Vue d'ensemble

Le processus d'attestation dans le système Oracle est un mécanisme de **validation multi-signature décentralisé** basé sur NOSTR. Ce document détaille le flux cryptographique complet, de la soumission d'une attestation à sa publication sur les relais NOSTR.

## 📋 Table des Matières

1. [Architecture de l'Attestation](#architecture-de-lattestation)
2. [Flux Cryptographique](#flux-cryptographique)
3. [Événements NOSTR](#événements-nostr)
4. [Signatures et Vérification](#signatures-et-vérification)
5. [Chaîne de Confiance](#chaîne-de-confiance)
6. [Sécurité et Révocation](#sécurité-et-révocation)

---

## Architecture de l'Attestation

### Composants

```
┌─────────────────────────────────────────────────────────────────┐
│                      ATTESTATION WORKFLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ATTESTER (Expert)                                           │
│     └─> attest_license.sh                                       │
│         ├─> Récupère NOSTR keys (NPUB/NSEC)                    │
│         ├─> Construit attestation JSON                          │
│         └─> POST /api/permit/attest                             │
│                                                                  │
│  2. API BACKEND (54321.py)                                      │
│     └─> Endpoint /api/permit/attest                             │
│         ├─> Valide NOSTR authentication                         │
│         ├─> Crée PermitAttestation object                       │
│         └─> Appelle oracle_system.attest_permit()              │
│                                                                  │
│  3. ORACLE SYSTEM (oracle_system.py)                            │
│     └─> OracleSystem.attest_permit()                            │
│         ├─> Vérifie le request existe                           │
│         ├─> Vérifie l'attesteur a les droits                   │
│         ├─> Génère signature cryptographique                    │
│         ├─> Crée événement NOSTR kind 30502                     │
│         ├─> Publie sur relais NOSTR                             │
│         ├─> Vérifie seuil d'attestations                        │
│         └─> [Si seuil atteint] → Issue Credential               │
│                                                                  │
│  4. NOSTR RELAYS                                                 │
│     └─> Stockage décentralisé                                    │
│         ├─> Événement kind 30502 (attestation)                  │
│         ├─> Signature Ed25519 de l'attesteur                    │
│         └─> Vérifiable par tous                                  │
│                                                                  │
│  5. CREDENTIAL ISSUANCE (si validé)                             │
│     └─> oracle_system.issue_credential()                        │
│         ├─> Crée W3C Verifiable Credential                      │
│         ├─> Signature par UPLANETNAME.G1                        │
│         ├─> Événement NOSTR kind 30503                          │
│         ├─> Publication sur relais                               │
│         └─> Mise à jour DID holder                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Flux Cryptographique

### Étape 1: Récupération des Clés NOSTR

```bash
# attest_license.sh (lignes 76-91)
NOSTR_DIR="$HOME/.zen/game/nostr/${EMAIL}"
NPUB_FILE="${NOSTR_DIR}/NPUB"
NPUB=$(cat "$NPUB_FILE")
```

**Clés impliquées:**
- **NPUB** (clé publique NOSTR, format bech32): `npub1...`
- **HEX** (clé publique hex): Utilisée pour le DID `did:nostr:{HEX}`
- **NSEC** (clé privée NOSTR, format bech32): Stockée dans `.secret.nostr` (600 perms)

**Remarque:** À ce stade, le script ne charge pas NSEC car la signature se fait côté serveur après authentification.

### Étape 2: Construction de l'Attestation JSON

```bash
# attest_license.sh (lignes 141-149)
ATTESTATION_JSON=$(cat <<EOF
{
    "request_id": "${REQUEST_ID}",
    "attester_npub": "${NPUB}",
    "statement": "${STATEMENT}",
    "attester_license_id": ${LICENSE_JSON}
}
EOF
)
```

**Champs:**
- `request_id`: Identifiant unique de la demande de permis
- `attester_npub`: Clé publique NOSTR de l'expert (format npub)
- `statement`: Déclaration d'attestation ("J'atteste que...")
- `attester_license_id`: (Optionnel) Credential ID de l'expert si requis

### Étape 3: Authentification NOSTR (API Backend)

```python
# 54321.py - Endpoint /api/permit/attest
async def attest_permit(request: PermitAttestationRequest):
    # Vérification NOSTR authentication
    if not await verify_nostr_auth(request.attester_npub):
        raise HTTPException(status_code=401, detail="NOSTR authentication failed")
```

**Processus d'authentification:**
1. **Challenge-Response**: Le client doit prouver qu'il possède la clé privée NSEC
2. **Signature NOSTR**: Signe un challenge avec NSEC (via NIP-42 ou mécanisme similaire)
3. **Vérification**: Le serveur vérifie la signature avec NPUB

**Format du challenge (NIP-42):**
```json
{
  "kind": 22242,
  "content": "authenticate",
  "created_at": 1730000000,
  "tags": [
    ["challenge", "random_challenge_string"],
    ["relay", "wss://relay.example.com"]
  ]
}
```

### Étape 4: Génération de la Signature d'Attestation

```python
# 54321.py (lignes ~XXX)
signature = hashlib.sha256(
    f"{request.statement}:{request.attester_npub}:{time.time()}".encode()
).hexdigest()

attestation = PermitAttestation(
    attestation_id=attestation_id,
    request_id=request.request_id,
    attester_did=f"did:nostr:{request.attester_npub}",
    attester_npub=request.attester_npub,
    attester_license_id=request.attester_license_id,
    statement=request.statement,
    signature=signature,  # ← Signature cryptographique
    created_at=datetime.now(),
    nostr_event_id=None  # Sera rempli après publication NOSTR
)
```

**Composants de la signature:**
- **Input**: `statement + attester_npub + timestamp`
- **Algorithme**: SHA256 (pour l'instant, devrait être Ed25519 pour production)
- **Output**: Hash hexadécimal (64 caractères)

**⚠️ Note de Sécurité:** 
Dans une implémentation production, cette signature devrait être:
```python
# Signature Ed25519 (recommandée)
from cryptography.hazmat.primitives.asymmetric import ed25519

message = f"{statement}:{attester_npub}:{timestamp}".encode()
signature = private_key.sign(message)
signature_hex = signature.hex()
```

### Étape 5: Création de l'Événement NOSTR (Kind 30502)

```python
# oracle_system.py - OracleSystem.attest_permit()
def attest_permit(self, attestation: PermitAttestation) -> bool:
    # ... validations ...
    
    # Publier l'attestation sur NOSTR (kind 30502)
    nostr_event_id = self._publish_attestation_to_nostr(attestation)
    attestation.nostr_event_id = nostr_event_id
```

**Structure de l'événement NOSTR kind 30502:**
```json
{
  "kind": 30502,
  "created_at": 1730000000,
  "content": "J'atteste que le demandeur possède les compétences requises...",
  "tags": [
    ["d", "attestation-{attestation_id}"],
    ["e", "{request_event_id}"],
    ["p", "{applicant_hex_pubkey}"],
    ["a", "30501:{uplanet_hex}:{request_id}"],
    ["permit", "{permit_definition_id}"],
    ["attester", "{attester_npub}"],
    ["license", "{attester_license_id}"],
    ["signature", "{attestation_signature}"],
    ["t", "attestation"],
    ["t", "permit"],
    ["t", "UPlanet"]
  ],
  "pubkey": "{attester_hex_pubkey}",
  "id": "{event_id_sha256}",
  "sig": "{event_signature_schnorr}"
}
```

**Tags expliqués:**
- `["d", ...]`: Tag de déduplication (Parameterized Replaceable Event)
- `["e", ...]`: Référence à l'événement de demande (kind 30501)
- `["p", ...]`: Tag du demandeur (permet de filtrer)
- `["a", ...]`: Référence à l'événement addressable
- `["permit", ...]`: Type de permis concerné
- `["attester", ...]`: NPUB de l'attesteur
- `["license", ...]`: License ID de l'attesteur (si applicable)
- `["signature", ...]`: Signature de l'attestation (SHA256 ou Ed25519)
- `["t", ...]`: Tags thématiques pour recherche

### Étape 6: Signature Schnorr (NOSTR Native)

Chaque événement NOSTR est signé avec une **signature Schnorr** (secp256k1):

```python
# Processus de signature NOSTR
def sign_nostr_event(event_dict: dict, private_key_hex: str) -> str:
    """
    Signe un événement NOSTR selon NIP-01
    """
    # 1. Construire le message à signer
    serialized = json.dumps([
        0,  # Version
        event_dict["pubkey"],
        event_dict["created_at"],
        event_dict["kind"],
        event_dict["tags"],
        event_dict["content"]
    ], separators=(',', ':'), ensure_ascii=False)
    
    # 2. Hash SHA256 du message
    message_hash = hashlib.sha256(serialized.encode('utf-8')).digest()
    
    # 3. Signature Schnorr avec la clé privée
    signature = schnorr_sign(message_hash, bytes.fromhex(private_key_hex))
    
    # 4. ID de l'événement = hash du message
    event_id = message_hash.hex()
    
    return event_id, signature.hex()
```

**Algorithme Schnorr (secp256k1):**
- Plus compact que ECDSA
- Permet la vérification par lot
- Utilisé par Bitcoin Taproot et NOSTR

### Étape 7: Vérification des Attestations (Seuil)

```python
# oracle_system.py
def attest_permit(self, attestation: PermitAttestation) -> bool:
    # Ajouter l'attestation
    permit_request.attestations.append(attestation)
    
    # Vérifier le seuil
    definition = self.definitions[permit_request.permit_definition_id]
    if len(permit_request.attestations) >= definition.min_attestations:
        # Validation automatique
        permit_request.status = PermitStatus.VALIDATED
        
        # Émettre le Verifiable Credential
        credential = self.issue_credential(permit_request)
        return True
```

**Validation multi-signature:**
- Chaque attestation = 1 signature
- Seuil défini dans `permit_definition.json`: `min_attestations`
- Exemple: PERMIT_ORE_V1 = 5 attestations requises
- Une fois le seuil atteint → émission automatique du VC

### Étape 8: Émission du Credential (W3C VC)

```python
# oracle_system.py - issue_credential()
def issue_credential(self, permit_request: PermitRequest) -> PermitCredential:
    definition = self.definitions[permit_request.permit_definition_id]
    
    # Créer la preuve cryptographique
    proof = {
        "type": "Ed25519Signature2020",
        "created": datetime.now().isoformat(),
        "verificationMethod": f"{definition.issuer_did}#uplanet-authority",
        "proofPurpose": "assertionMethod",
        "proofValue": self._sign_credential(permit_request)
    }
    
    credential = PermitCredential(
        credential_id=credential_id,
        permit_definition_id=permit_request.permit_definition_id,
        holder_did=permit_request.applicant_did,
        holder_npub=permit_request.applicant_npub,
        issued_by=definition.issuer_did,  # did:nostr:UPLANETNAME
        issued_at=datetime.now(),
        expires_at=expiration_date,
        attestations=permit_request.attestations,
        proof=proof,
        status=PermitStatus.ACTIVE
    )
    
    # Publier sur NOSTR (kind 30503)
    nostr_event_id = self._publish_credential_to_nostr(credential)
    credential.nostr_event_id = nostr_event_id
    
    return credential
```

**Signature du Credential par UPLANETNAME.G1:**
```python
def _sign_credential(self, permit_request: PermitRequest) -> str:
    """
    Signe le credential avec la clé privée UPLANETNAME.G1
    """
    # Charger la clé privée UPlanet
    uplanet_private_key = load_uplanet_g1_key()  # NSEC de UPLANETNAME.G1
    
    # Message à signer = hash du credential
    credential_data = {
        "permit_definition_id": permit_request.permit_definition_id,
        "holder_did": permit_request.applicant_did,
        "issued_at": datetime.now().isoformat(),
        "attestations": [a.attestation_id for a in permit_request.attestations]
    }
    
    message = json.dumps(credential_data, sort_keys=True).encode()
    message_hash = hashlib.sha256(message).digest()
    
    # Signature Ed25519
    signature = uplanet_private_key.sign(message_hash)
    
    # Encodage base64url (standard W3C VC)
    proof_value = base64.urlsafe_b64encode(signature).decode('ascii')
    
    return f"z{proof_value}"  # Prefixe 'z' = multibase base58btc
```

### Étape 9: Publication du Credential (Kind 30503)

```json
{
  "kind": 30503,
  "created_at": 1730000000,
  "content": "{W3C_VERIFIABLE_CREDENTIAL_JSON}",
  "tags": [
    ["d", "credential-{credential_id}"],
    ["e", "{request_event_id}"],
    ["p", "{holder_hex_pubkey}"],
    ["a", "30501:{uplanet_hex}:{request_id}"],
    ["permit", "{permit_definition_id}"],
    ["holder", "{holder_npub}"],
    ["issuer", "{uplanet_did}"],
    ["issued_at", "{timestamp}"],
    ["expires_at", "{expiration_timestamp}"],
    ["attestations_count", "{count}"],
    ["t", "credential"],
    ["t", "permit"],
    ["t", "verifiable-credential"],
    ["t", "UPlanet"]
  ],
  "pubkey": "{uplanet_hex_pubkey}",
  "id": "{event_id}",
  "sig": "{uplanet_signature}"
}
```

**Content = W3C Verifiable Credential complet:**
```json
{
  "@context": [
    "https://www.w3.org/2018/credentials/v1",
    "https://w3id.org/security/v2",
    "https://qo-op.com/credentials/v1"
  ],
  "id": "urn:uuid:{credential_id}",
  "type": ["VerifiableCredential", "UPlanetLicense"],
  "issuer": "did:nostr:{uplanet_hex}",
  "issuanceDate": "2025-10-30T12:00:00Z",
  "expirationDate": "2028-10-30T12:00:00Z",
  "credentialSubject": {
    "id": "did:nostr:{holder_hex}",
    "license": "PERMIT_ORE_V1",
    "licenseName": "ORE Environmental Verifier",
    "attestationsCount": 5,
    "status": "active"
  },
  "proof": {
    "type": "Ed25519Signature2020",
    "created": "2025-10-30T12:00:00Z",
    "verificationMethod": "did:nostr:{uplanet_hex}#uplanet-authority",
    "proofPurpose": "assertionMethod",
    "proofValue": "z58DAdFfa9SkqZMVPxAQpYqejQs2RWXHYCyJZ9DgxbCnFP..."
  }
}
```

---

## Événements NOSTR

### Kinds Utilisés

| Kind  | Type | Description |
|-------|------|-------------|
| 30500 | Permit Definition | Définition du type de permis |
| 30501 | Permit Request | Demande de permis par l'applicant |
| **30502** | **Permit Attestation** | **Attestation par un expert** ⭐ |
| 30503 | Permit Credential | Verifiable Credential émis |

### Parameterized Replaceable Events (NIP-33)

Tous les événements sont de type **Parameterized Replaceable** (kinds 30000-39999):
- Tag `["d", ...]` unique permet de remplacer l'événement
- Seule la dernière version est conservée
- Permet les mises à jour (ex: révocation de credential)

### Exemple de Flux Complet NOSTR

```
1. DÉFINITION (Kind 30500)
   └─> Publié par: UPLANETNAME.G1
       └─> Tag d: "permit-def-PERMIT_ORE_V1"

2. DEMANDE (Kind 30501)
   └─> Publié par: Applicant (npub1abc...)
       └─> Tag d: "permit-request-{request_id}"
       └─> Tag a: "30500:{uplanet}:permit-def-PERMIT_ORE_V1"

3. ATTESTATION 1 (Kind 30502) ⭐
   └─> Publié par: Expert 1 (npub1def...)
       └─> Tag d: "attestation-{attestation_id_1}"
       └─> Tag e: "{request_event_id}"
       └─> Tag a: "30501:{applicant}:permit-request-{request_id}"

4. ATTESTATION 2 (Kind 30502) ⭐
   └─> Publié par: Expert 2 (npub1ghi...)
       └─> Tag d: "attestation-{attestation_id_2}"
       └─> Tag e: "{request_event_id}"
       └─> Tag a: "30501:{applicant}:permit-request-{request_id}"

... (3 autres attestations)

5. ATTESTATION 5 (Kind 30502) ⭐
   └─> Publié par: Expert 5 (npub1stu...)
       └─> Tag d: "attestation-{attestation_id_5}"
       └─> Tag e: "{request_event_id}"
       └─> [SEUIL ATTEINT] → Émission automatique du VC

6. CREDENTIAL (Kind 30503)
   └─> Publié par: UPLANETNAME.G1
       └─> Tag d: "credential-{credential_id}"
       └─> Tag e: "{request_event_id}"
       └─> Content: W3C Verifiable Credential complet
       └─> Signature: UPlanet Authority (Ed25519)
```

---

## Signatures et Vérification

### Types de Signatures

Le système utilise **trois niveaux de signatures**:

#### 1. Signature d'Attestation (Application Level)
```python
# Signature SHA256 de l'attestation
signature = hashlib.sha256(
    f"{statement}:{attester_npub}:{timestamp}".encode()
).hexdigest()
```
**Usage:** Identifier l'attestation de manière unique

#### 2. Signature NOSTR (Event Level)
```python
# Signature Schnorr de l'événement NOSTR
event_signature = schnorr_sign(event_hash, attester_private_key)
```
**Usage:** Prouver que l'attesteur a bien publié l'événement

#### 3. Signature du Credential (Authority Level)
```python
# Signature Ed25519 par UPLANETNAME.G1
credential_signature = ed25519_sign(credential_hash, uplanet_private_key)
```
**Usage:** Certification finale par l'autorité UPlanet

### Vérification Multi-Niveaux

```python
def verify_attestation(attestation: PermitAttestation, nostr_event: dict) -> bool:
    """
    Vérifie une attestation à tous les niveaux
    """
    # 1. Vérifier la signature NOSTR de l'événement
    if not verify_schnorr_signature(
        event=nostr_event,
        pubkey=attestation.attester_npub
    ):
        return False  # Événement NOSTR invalide
    
    # 2. Vérifier la signature d'attestation
    expected_sig = hashlib.sha256(
        f"{attestation.statement}:{attestation.attester_npub}:{attestation.created_at.timestamp()}".encode()
    ).hexdigest()
    
    if attestation.signature != expected_sig:
        return False  # Signature d'attestation invalide
    
    # 3. Vérifier que l'attesteur a les droits
    if not verify_attester_credentials(attestation):
        return False  # Attesteur non autorisé
    
    return True  # ✅ Attestation valide
```

### Vérification du Credential

```python
def verify_credential(credential: PermitCredential) -> bool:
    """
    Vérifie un Verifiable Credential complet
    """
    # 1. Vérifier la signature UPlanet (Ed25519)
    credential_data = {
        "permit_definition_id": credential.permit_definition_id,
        "holder_did": credential.holder_did,
        "issued_at": credential.issued_at.isoformat(),
        "attestations": [a.attestation_id for a in credential.attestations]
    }
    
    message = json.dumps(credential_data, sort_keys=True).encode()
    message_hash = hashlib.sha256(message).digest()
    
    # Récupérer la clé publique UPlanet
    uplanet_public_key = get_uplanet_g1_public_key()
    
    # Décoder la signature (format multibase 'z')
    proof_value = credential.proof["proofValue"]
    signature_bytes = base64.urlsafe_b64decode(proof_value[1:])  # Skip 'z'
    
    # Vérifier Ed25519
    if not ed25519_verify(message_hash, signature_bytes, uplanet_public_key):
        return False  # Signature UPlanet invalide
    
    # 2. Vérifier toutes les attestations
    for attestation in credential.attestations:
        if not verify_attestation(attestation):
            return False  # Attestation invalide
    
    # 3. Vérifier le seuil d'attestations
    definition = get_permit_definition(credential.permit_definition_id)
    if len(credential.attestations) < definition.min_attestations:
        return False  # Pas assez d'attestations
    
    # 4. Vérifier l'expiration
    if credential.expires_at and datetime.now() > credential.expires_at:
        return False  # Credential expiré
    
    return True  # ✅ Credential valide
```

---

## Chaîne de Confiance

### Architecture de la Confiance

```
┌──────────────────────────────────────────────────────────────────┐
│                    CHAÎNE DE CONFIANCE WoT                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  NIVEAU 0: WoT Ğ1 (Base de Confiance)                           │
│     └─> Membres certifiés Duniter                                │
│         └─> Transaction 0.01Ğ1 vers MULTIPASS/ZEN Card          │
│             └─> Crée .2nd file (KYC WoT validation)             │
│                                                                   │
│  NIVEAU 1: MULTIPASS (Identité Décentralisée)                   │
│     └─> DID: did:nostr:{hex_pubkey}                             │
│         └─> Publié sur NOSTR (kind 30311)                       │
│             └─> Clés jumelles (G1, NOSTR, BTC, XMR)            │
│                                                                   │
│  NIVEAU 2: Attestation d'Expert                                  │
│     └─> Expert avec permit valide atteste                        │
│         └─> Signature Schnorr (NOSTR)                           │
│             └─> Événement kind 30502                             │
│                 └─> Vérifiable par tous                          │
│                                                                   │
│  NIVEAU 3: Multi-Signature (N experts)                          │
│     └─> Seuil atteint (ex: 5/5 attestations)                    │
│         └─> Validation automatique                               │
│             └─> Consensus décentralisé                           │
│                                                                   │
│  NIVEAU 4: Certification UPlanet Authority                       │
│     └─> UPLANETNAME.G1 signe le Verifiable Credential           │
│         └─> Signature Ed25519                                    │
│             └─> Événement kind 30503                             │
│                 └─> W3C VC standard                              │
│                     └─> Ajouté au DID du holder                  │
│                                                                   │
│  NIVEAU 5: Intégration DID                                       │
│     └─> VC ajouté au document DID du holder                      │
│         └─> Publié sur NOSTR (kind 30311 update)                │
│             └─> Vérifiable cryptographiquement                   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Validation en Cascade

Chaque niveau dépend du précédent:

1. **WoT Ğ1** → Validation initiale de l'humain (unique)
2. **MULTIPASS** → Identité décentralisée prouvée
3. **Attestations** → Compétence certifiée par pairs
4. **Multi-Sig** → Consensus communautaire
5. **Authority** → Certification officielle UPlanet
6. **DID Integration** → Propriété numérique vérifiable

### Exemple Concret: Permis ORE Verifier

```
Alice veut devenir vérificatrice ORE environnementale:

1. WoT Ğ1 Validation ✅
   └─> Alice est membre certifié Duniter
       └─> Son compte a reçu 0.01Ğ1 d'un forgeron
           └─> File: ~/.zen/tmp/coucou/{alice_g1pub}.2nd exists

2. MULTIPASS Creation ✅
   └─> ./make_NOSTRCARD.sh alice@example.com
       └─> DID: did:nostr:a1b2c3d4...
           └─> Publié sur NOSTR (kind 30311)

3. Permit Request ✅
   └─> Via /oracle interface or API POST /api/permit/request
       └─> NOSTR event kind 30501
           └─> Request ID: xyz123

4. Attestations (5 experts) ✅
   Expert 1: Via /oracle "Attest This Request" or API
   └─> NOSTR kind 30502 (Schnorr signature expert1)
   
   Expert 2: Via /oracle "Attest This Request" or API
   └─> NOSTR kind 30502 (Schnorr signature expert2)
   
   ... (3 other experts)
   
   Expert 5: Via /oracle "Attest This Request" or API
   └─> NOSTR kind 30502 (Schnorr signature expert5)
   └─> [THRESHOLD REACHED 5/5] → Automatic VC issuance

5. Credential Issuance ✅
   └─> oracle_system.issue_credential()
       └─> Signature Ed25519 par UPLANETNAME.G1
           └─> NOSTR kind 30503
               └─> W3C Verifiable Credential

6. DID Update ✅
   └─> did_manager_nostr.sh update alice@example.com
       └─> VC ajouté à verifiableCredential[]
           └─> DID republié sur NOSTR (kind 30311)

Alice a maintenant:
- ✅ Identité WoT validée (Ğ1)
- ✅ DID décentralisé (NOSTR)
- ✅ Permit ORE Verifier (5 attestations)
- ✅ Verifiable Credential (W3C standard)
- ✅ Certification UPlanet Authority
- ✅ Droits économiques (récompenses Ẑen pour vérifications)
```

---

## Sécurité et Révocation

### Attaques Possibles et Défenses

#### 1. Fausse Attestation

**Attaque:** Un expert malveillant atteste faussement

**Défense:**
- Assurance mutuelle: Les attesteurs forment un pool d'assurance
- Révocation en cascade: Si l'attestation est fausse, tous les permits dépendants sont révoqués
- Pénalité économique: L'attesteur perd son propre permit + pénalité Ẑen
- Traçabilité: Tous les événements NOSTR sont immuables et traçables

#### 2. Collusion d'Experts

**Attaque:** N experts se mettent d'accord pour valider un incompétent

**Défense:**
- Seuil élevé: 5-24 attestations selon le permit
- Diversité géographique: Les experts doivent être de différentes régions
- Réputation: Historique des attestations sur NOSTR
- Validation communautaire: Période de contestation de 7-30 jours

#### 3. Usurpation d'Identité

**Attaque:** Quelqu'un essaie de se faire passer pour un expert

**Défense:**
- Signature Schnorr: Impossible de forger sans NSEC
- NOSTR authentication: Challenge-response obligatoire
- DID verification: Chaque expert a un DID vérifiable
- WoT Ğ1: Base de confiance initiale

#### 4. Replay Attack

**Attaque:** Rejouer une ancienne attestation pour un nouveau request

**Défense:**
- Timestamp dans la signature
- Request ID unique lié à l'attestation
- Event ID NOSTR unique (hash de tout le contenu)
- Tags de référence (["e", ...], ["a", ...])

### Processus de Révocation

```python
# oracle_system.py - revoke_credential()
def revoke_credential(
    self,
    credential_id: str,
    reason: str,
    revoker_did: str
) -> bool:
    """
    Révoque un Verifiable Credential
    """
    credential = self.credentials.get(credential_id)
    if not credential:
        return False
    
    # Vérifier que le révocateur a les droits
    if not self._verify_revocation_authority(revoker_did):
        return False
    
    # Mettre à jour le statut
    credential.status = PermitStatus.REVOKED
    credential.revocation_reason = reason
    credential.revoked_at = datetime.now()
    credential.revoked_by = revoker_did
    
    # Publier la révocation sur NOSTR (update kind 30503)
    self._publish_revocation_to_nostr(credential)
    
    # Mettre à jour le DID du holder
    self._update_holder_did_revocation(credential)
    
    return True
```

**Événement de révocation (NOSTR kind 30503 update):**
```json
{
  "kind": 30503,
  "created_at": 1730100000,
  "content": "{UPDATED_VC_WITH_REVOCATION}",
  "tags": [
    ["d", "credential-{credential_id}"],
    ["status", "revoked"],
    ["revocation_reason", "{reason}"],
    ["revoked_by", "{revoker_did}"],
    ["revoked_at", "{timestamp}"],
    ["t", "revocation"],
    ["t", "credential"]
  ],
  "pubkey": "{uplanet_hex_pubkey}",
  "id": "{new_event_id}",
  "sig": "{new_signature}"
}
```

**⚠️ Note:** La révocation remplace l'événement précédent grâce au tag `["d", ...]` (Parameterized Replaceable Event).

---

## Résumé du Flux d'Attestation

### Vue Synthétique

```
1. EXPERT uses /oracle web interface (or API)
   ↓
2. Authenticates via NIP-42 (NOSTR extension)
   ↓
3. Construction JSON attestation + POST /api/permit/attest
   ↓
4. API vérifie NOSTR authentication (Challenge-Response)
   ↓
5. API crée PermitAttestation object avec signature SHA256
   ↓
6. oracle_system.attest_permit() est appelé
   ↓
7. Validation: request existe, expert a les droits, pas de doublon
   ↓
8. Création événement NOSTR kind 30502
   ↓
9. Signature Schnorr de l'événement avec NSEC expert
   ↓
10. Publication sur relais NOSTR (wss://relay.copylaradio.com)
    ↓
11. Vérification seuil: attestations >= min_attestations?
    ↓ OUI
12. Émission automatique Verifiable Credential
    ↓
13. Signature Ed25519 par UPLANETNAME.G1
    ↓
14. Création événement NOSTR kind 30503 (VC complet)
    ↓
15. Publication sur relais NOSTR
    ↓
16. Mise à jour DID holder (kind 30311 update)
    ↓
17. Notification holder + attesteurs
    ↓
18. [Optionnel] Virement PERMIT depuis RnD (UPLANET.official.sh)
```

### Signatures Impliquées

| Niveau | Type | Signé par | Algorithme | Localisation |
|--------|------|-----------|------------|--------------|
| 1 | Attestation | Expert | SHA256 | oracle_system.py |
| 2 | NOSTR Event | Expert | Schnorr (secp256k1) | NOSTR relay |
| 3 | Credential | UPLANETNAME.G1 | Ed25519 | oracle_system.py |
| 4 | NOSTR Event | UPLANETNAME.G1 | Schnorr (secp256k1) | NOSTR relay |
| 5 | DID Update | Holder | Schnorr (secp256k1) | NOSTR relay |

### Clés Cryptographiques

| Acteur | Clé Publique | Clé Privée | Usage |
|--------|--------------|------------|-------|
| Expert | NPUB (bech32) | NSEC (bech32) | Signer attestations NOSTR |
| Expert | HEX (64 chars) | HEX private | DID `did:nostr:{hex}` |
| Expert | G1PUB (base58) | G1 dunikey | Transactions Ğ1 |
| UPlanet | UPLANETNAME.G1 NPUB | NSEC | Signer credentials |
| UPlanet | UPLANETG1PUB | uplanet.G1.dunikey | Autorité certification |
| Holder | NPUB | NSEC | Recevoir credentials |

---

## Conclusion

Le système d'attestation Oracle UPlanet implémente un **mécanisme de validation multi-signature décentralisé** qui:

✅ **Garantit l'authenticité** via signatures cryptographiques (Schnorr + Ed25519)  
✅ **Assure la traçabilité** via événements NOSTR immuables  
✅ **Crée la confiance** via consensus communautaire (N attestations requises)  
✅ **Respecte les standards** W3C Verifiable Credentials  
✅ **Permet la vérification** par n'importe qui, n'importe quand  
✅ **Intègre l'économie** via récompenses Ẑen depuis portefeuille RnD  

C'est un exemple concret de **Web of Trust étendu à la compétence**, où la certification décentralisée remplace les autorités centralisées traditionnelles.

---

## Références

- [NIP-01: Basic Protocol](https://github.com/nostr-protocol/nips/blob/master/01.md) - Événements NOSTR et signatures Schnorr
- [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md) - Kinds 30000-39999
- [NIP-42: Authentication](https://github.com/nostr-protocol/nips/blob/master/42.md) - Challenge-Response
- [W3C Verifiable Credentials](https://www.w3.org/TR/vc-data-model/) - Standard VC
- [Ed25519 Signature 2020](https://w3c-ccg.github.io/lds-ed25519-2020/) - Signatures cryptographiques
- [CopyLaRadio Article](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#) - Philosophie WoT

---

**Auteur:** Équipe UPlanet/Astroport.ONE  
**Contact:** support@qo-op.com  
**Licence:** AGPL-3.0  
**Dernière mise à jour:** Octobre 2025

