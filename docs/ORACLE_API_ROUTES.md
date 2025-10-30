# 📡 Oracle API Routes - Reference Complete

## Vue d'ensemble

Toutes les routes Oracle de l'API `54321.py` pour la gestion des permis multi-signatures.

---

## 🔐 Routes principales (CRUD)

### 1. **POST /api/permit/define**
Créer une nouvelle définition de permis (admin/UPLANETNAME.G1 only)

**Body:**
```json
{
  "id": "PERMIT_NEW_TYPE",
  "name": "New Permit Type",
  "description": "Description of the permit",
  "min_attestations": 5,
  "required_license": null,
  "valid_duration_days": 1095,
  "revocable": true,
  "verification_method": "peer_attestation",
  "metadata": {}
}
```

**Response:**
```json
{
  "success": true,
  "message": "Permit definition PERMIT_NEW_TYPE created",
  "definition_id": "PERMIT_NEW_TYPE"
}
```

---

### 2. **POST /api/permit/request**
Soumettre une demande de permis (requiert NIP-42)

**Body:**
```json
{
  "permit_definition_id": "PERMIT_ORE_V1",
  "applicant_npub": "npub1...",
  "statement": "I have 5 years experience...",
  "evidence": [
    "https://example.com/certificate.pdf"
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Permit request submitted",
  "request_id": "a1b2c3d4e5f6",
  "status": "pending",
  "permit_type": "PERMIT_ORE_V1"
}
```

---

### 3. **POST /api/permit/attest**
Ajouter une attestation à une demande (requiert NIP-42)

**Body:**
```json
{
  "request_id": "a1b2c3d4e5f6",
  "attester_npub": "npub1...",
  "statement": "I certify this person's competence",
  "attester_license_id": null
}
```

**Response:**
```json
{
  "success": true,
  "message": "Attestation added",
  "attestation_id": "b2c3d4e5f6a1",
  "request_id": "a1b2c3d4e5f6",
  "status": "attesting",
  "attestations_count": 3
}
```

---

### 4. **GET /api/permit/status/{request_id}**
Obtenir le statut d'une demande

**Example:** `GET /api/permit/status/a1b2c3d4e5f6`

**Response:**
```json
{
  "request_id": "a1b2c3d4e5f6",
  "permit_type": "ORE Environmental Verifier",
  "permit_definition_id": "PERMIT_ORE_V1",
  "applicant_did": "did:nostr:...",
  "applicant_npub": "npub1...",
  "status": "attesting",
  "attestations_count": 3,
  "required_attestations": 5,
  "attestations": [
    {
      "attester_npub": "npub1...",
      "attester_did": "did:nostr:...",
      "statement": "Verified competence",
      "created_at": "2025-10-30T12:34:56Z"
    }
  ],
  "created_at": "2025-10-30T10:00:00Z",
  "updated_at": "2025-10-30T12:34:56Z"
}
```

---

### 5. **GET /api/permit/list**
Lister les demandes ou credentials

**Query params:**
- `type`: `"requests"` ou `"credentials"`
- `npub`: (optional) filtrer par npub

**Examples:**
- `GET /api/permit/list?type=requests`
- `GET /api/permit/list?type=requests&npub=npub1...`
- `GET /api/permit/list?type=credentials`

**Response:**
```json
{
  "success": true,
  "type": "requests",
  "count": 12,
  "results": [
    {
      "request_id": "a1b2c3d4",
      "permit_type": "ORE Environmental Verifier",
      "status": "validated",
      "attestations_count": 5
    }
  ]
}
```

---

### 6. **GET /api/permit/credential/{credential_id}**
Obtenir un Verifiable Credential W3C

**Example:** `GET /api/permit/credential/cred_xyz123`

**Response:** (Format W3C VC)
```json
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
    "holderNpub": "npub1...",
    "attestationsCount": 5,
    "status": "issued"
  },
  "proof": {
    "type": "Ed25519Signature2020",
    "created": "2025-10-30T12:00:00Z",
    "verificationMethod": "did:nostr:UPLANETNAME#uplanet-authority",
    "proofValue": "z58DAdFfa9..."
  }
}
```

---

### 7. **GET /api/permit/definitions**
Lister toutes les définitions de permis disponibles

**Response:**
```json
{
  "success": true,
  "count": 8,
  "definitions": [
    {
      "id": "PERMIT_ORE_V1",
      "name": "ORE Environmental Verifier",
      "description": "Environmental verification permit",
      "min_attestations": 5,
      "required_license": null,
      "valid_duration_days": 1095,
      "verification_method": "peer_attestation"
    }
  ]
}
```

---

## 🌐 Routes NOSTR (nouveaux)

### 8. **GET /api/permit/nostr/fetch** ⭐ NOUVEAU
Récupérer les événements de permis depuis les relays NOSTR

**Query params:**
- `kind`: Type d'événement (30500, 30501, ou 30503)
- `npub`: (optional) Filtrer par auteur/détenteur

**Examples:**
- `GET /api/permit/nostr/fetch?kind=30500` (définitions)
- `GET /api/permit/nostr/fetch?kind=30501` (demandes)
- `GET /api/permit/nostr/fetch?kind=30501&npub=npub1...` (mes demandes)
- `GET /api/permit/nostr/fetch?kind=30503` (credentials)
- `GET /api/permit/nostr/fetch?kind=30503&npub=npub1...` (mes credentials)

**Response:**
```json
{
  "success": true,
  "kind": 30501,
  "count": 5,
  "events": [
    {
      "request_id": "a1b2c3d4",
      "permit_id": "PERMIT_ORE_V1",
      "applicant_npub": "npub1...",
      "statement": "My competence statement",
      "created_at": "2025-10-30T12:00:00Z"
    }
  ]
}
```

---

## 🔧 Routes de maintenance (ORACLE.refresh.sh)

### 9. **POST /api/permit/issue/{request_id}** ⭐ NOUVEAU
Déclencher manuellement l'émission d'un credential (idempotent)

**Example:** `POST /api/permit/issue/a1b2c3d4e5f6`

**Response:**
```json
{
  "success": true,
  "message": "Credential issued",
  "credential_id": "cred_xyz123",
  "holder_npub": "npub1...",
  "permit_id": "PERMIT_ORE_V1"
}
```

**Utilisé par:** `ORACLE.refresh.sh` pour émettre automatiquement les credentials quand le seuil est atteint.

---

### 10. **POST /api/permit/expire/{request_id}** ⭐ NOUVEAU
Marquer une demande comme expirée (> 90 jours)

**Example:** `POST /api/permit/expire/a1b2c3d4e5f6`

**Response:**
```json
{
  "success": true,
  "message": "Request marked as expired",
  "request_id": "a1b2c3d4e5f6"
}
```

**Utilisé par:** `ORACLE.refresh.sh` pour nettoyer les demandes anciennes.

---

### 11. **POST /api/permit/revoke/{credential_id}** ⭐ NOUVEAU
Révoquer un credential

**Query params:**
- `reason`: (optional) Raison de la révocation

**Example:** `POST /api/permit/revoke/cred_xyz123?reason=expired`

**Response:**
```json
{
  "success": true,
  "message": "Credential revoked",
  "credential_id": "cred_xyz123",
  "reason": "expired"
}
```

**Utilisé par:** `ORACLE.refresh.sh` pour révoquer les credentials expirés.

---

## 🔐 Authentification

### Routes nécessitant NIP-42
Les routes suivantes nécessitent une authentification NOSTR (NIP-42):

- ✅ `POST /api/permit/request`
- ✅ `POST /api/permit/attest`

**Process:**
1. L'utilisateur se connecte via NOSTR extension (nos2x, Alby, etc.)
2. Un événement kind 22242 est envoyé au relay
3. L'API vérifie l'authentification via `verify_nostr_auth(npub)`
4. Si validé → requête acceptée

### Routes admin (UPLANETNAME.G1)
- ✅ `POST /api/permit/define` (création de définitions)
- ✅ `POST /api/permit/issue/{request_id}` (émission manuelle)
- ✅ `POST /api/permit/revoke/{credential_id}` (révocation)

---

## 📡 Intégration NOSTR

### Publication d'événements
Toutes les opérations Oracle publient automatiquement des événements NOSTR via `nostr_send_note.py`:

**Mapping:**
- **Définition créée** → kind 30500 (signé par UPLANETNAME.G1)
- **Demande soumise** → kind 30501 (signé par le demandeur)
- **Attestation ajoutée** → kind 30502 (signé par l'attesteur)
- **Credential émis** → kind 30503 (signé par UPLANETNAME.G1)

### Récupération d'événements
La route `/api/permit/nostr/fetch` permet de:
- Interroger les relays NOSTR pour les événements Oracle
- Filtrer par kind et npub
- Synchroniser l'état local avec NOSTR

---

## 🔄 Workflow complet

### 1. Demander un permis
```bash
# Via interface web /oracle ou CLI
curl -X POST ${uSPOT}/api/permit/request \
  -H "Content-Type: application/json" \
  -d '{
    "permit_definition_id": "PERMIT_ORE_V1",
    "applicant_npub": "npub1...",
    "statement": "My competence statement",
    "evidence": []
  }'
```

### 2. Attester une demande
```bash
curl -X POST ${uSPOT}/api/permit/attest \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "a1b2c3d4e5f6",
    "attester_npub": "npub1...",
    "statement": "I certify this person",
    "attester_license_id": null
  }'
```

### 3. Vérifier le statut
```bash
curl ${uSPOT}/api/permit/status/a1b2c3d4e5f6
```

### 4. Maintenance quotidienne (automatique)
```bash
# Exécuté par UPLANET.refresh.sh
${RUNTIME}/ORACLE.refresh.sh

# Qui appelle:
# - GET /api/permit/list?type=requests
# - POST /api/permit/issue/{request_id} (si seuil atteint)
# - POST /api/permit/expire/{request_id} (si > 90j)
```

---

## 📊 Résumé des routes

| Route | Méthode | Auth | Usage |
|-------|---------|------|-------|
| `/api/permit/define` | POST | Admin | Créer définition |
| `/api/permit/request` | POST | NIP-42 | Demander permis |
| `/api/permit/attest` | POST | NIP-42 | Attester demande |
| `/api/permit/status/{id}` | GET | - | Statut demande |
| `/api/permit/list` | GET | - | Liste demandes/credentials |
| `/api/permit/credential/{id}` | GET | - | Récupérer VC |
| `/api/permit/definitions` | GET | - | Liste définitions |
| `/api/permit/nostr/fetch` | GET | - | ⭐ Fetch NOSTR events |
| `/api/permit/issue/{id}` | POST | Admin | ⭐ Émettre credential |
| `/api/permit/expire/{id}` | POST | Admin | ⭐ Expirer demande |
| `/api/permit/revoke/{id}` | POST | Admin | ⭐ Révoquer credential |

**Légende:**
- ⭐ = Nouvelles routes ajoutées
- Auth "Admin" = Réservé à UPLANETNAME.G1
- Auth "NIP-42" = Authentification NOSTR requise
- Auth "-" = Accès public (lecture seule)

---

## 🛠️ Outils utilisés

### Par `oracle_system.py`
- **`nostr_send_note.py`** - Publication d'événements NOSTR
- **`~/.zen/game/nostr/EMAIL/.secret.nostr`** - Keyfiles pour signature
- **`~/.zen/game/nostr/UPLANETNAME.G1/.secret.nostr`** - Clé autorité

### Par l'interface `/oracle`
- **`common.js`** - Connexion NIP-42 (comme `astro_base.html`)
- **Routes GET** - Récupération des données
- **Routes POST** - Soumission avec auth

### Par `ORACLE.refresh.sh`
- **`/api/permit/list`** - Liste des demandes en attente
- **`/api/permit/status/{id}`** - Détails de chaque demande
- **`/api/permit/issue/{id}`** - Émission automatique
- **`/api/permit/expire/{id}`** - Nettoyage ancien

---

**Date:** 30 octobre 2025  
**Version:** 2.0  
**Auteur:** Assistant IA (Claude Sonnet 4.5)  
**Projet:** UPlanet / Astroport.ONE

