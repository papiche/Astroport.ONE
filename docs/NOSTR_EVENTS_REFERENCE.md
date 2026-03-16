# 📡 NOSTR Events Reference - UPlanet Source of Truth

## Introduction

Les événements NOSTR sont la **source de vérité** pour tout le système UPlanet. Le stockage local n'est qu'un **cache** pour la performance. Toutes les données d'identité, économiques, et de gouvernance sont publiées et récupérées depuis les relays NOSTR.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     SOURCE DE VÉRITÉ = NOSTR RELAYS                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   wss://relay.copylaradio.com  ←→  wss://nos.lol  ←→  wss://relay.damus.io │
│                                                                              │
│   Synchronisation via N² (Network of Networks) - Constellation Sync          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     ↓
                          ┌─────────────────────┐
                          │   CACHE LOCAL       │
                          │  ~/.zen/game/...    │
                          │  (performance only) │
                          └─────────────────────┘
```

---

## 📊 Vue d'ensemble des Event Kinds

### Tableau récapitulatif

| Kind | Nom | Catégorie | Description | NIP |
|------|-----|-----------|-------------|-----|
| **0** | Profile | Identité | Profil utilisateur (metadata) | NIP-01 |
| **1** | Short Text Note | Interaction | Messages, notifications | NIP-01 |
| **3** | Contacts | Réseau | Liste d'amis (N1) | NIP-02 |
| **5** | Event Deletion | Gestion | Suppression d'événements | NIP-09 |
| **6** | Repost | Interaction | Partage de contenu | NIP-18 |
| **7** | Reaction | **Économie** | +ZEN, votes, likes | NIP-25 |
| **21** | Video | Média | Vidéo longue (NostrTube) | NIP-71 |
| **22** | Short Video | Média | Vidéo courte | NIP-71 |
| **1000** | **MUTE** | Modération | Liste de muting (utilisateurs, mots-clés, événements à ignorer) | NIP-51 |
| **1063** | File Metadata | Média | Métadonnées fichiers IPFS | NIP-94 |
| **1111** | Comment | Interaction | Commentaires vidéo | NIP-22 |
| **22242** | Auth Challenge | Auth | Authentification NIP-42 | NIP-42 |
| **30023** | Long-form | **Contenu** | Articles, documents, journaux | NIP-23 |
| **30024** | Draft Article | Contenu | Brouillons | NIP-23 |
| **30312** | ORE Meeting Space | **ORE** | Espace géographique ORE | NIP-101 |
| **30313** | ORE Verification | **ORE** | Vérification environnementale | NIP-101 |
| **30500** | Permit Definition | **Oracle** | Définition de permis | NIP-101 |
| **30501** | Permit Request | **Oracle** | Demande de permis | NIP-101 |
| **30502** | Permit Attestation | **Oracle** | Attestation multi-signature | NIP-101 |
| **30503** | Permit Credential | **Oracle** | Credential W3C | NIP-101 |
| **30800** | DID Document | **Identité** | Document d'identité W3C | NIP-101 |
| **30850** | Economic Health | **Économie** | Rapport santé économique | NIP-101 |
| **30900** | Crowdfunding | **Crowdfunding** | Métadonnées crowdfunding | NIP-101 |
| **30904** | CF Metadata | **Crowdfunding** | JSON structuré crowdfunding | NIP-101 |

---

## 🔐 IDENTITÉ NUMÉRIQUE

### Kind 30800 - DID Document (Source de vérité identité)

Le DID (Decentralized Identifier) est le **document d'identité** de chaque utilisateur/entité UPlanet. Il contient toutes les informations d'identité, credentials, et statuts.

**Qui l'utilise :**
- MULTIPASS (utilisateurs)
- UMAP (cellules géographiques)
- Cooperative wallets (CAPITAL, ASSETS, etc.)
- Biens Crowdfunding

**Structure :**
```json
{
  "kind": 30800,
  "pubkey": "<hex_pubkey>",
  "tags": [
    ["d", "did"],
    ["t", "uplanet"],
    ["t", "did-document"]
  ],
  "content": {
    "@context": ["https://www.w3.org/ns/did/v1"],
    "id": "did:nostr:<hex_pubkey>",
    "verificationMethod": [{
      "id": "did:nostr:<hex>#key-1",
      "type": "Ed25519VerificationKey2020",
      "publicKeyMultibase": "z<base58>"
    }],
    "service": [
      { "id": "#ipfs-drive", "type": "IPFSDrive", "serviceEndpoint": "ipns://<key>" },
      { "id": "#g1-wallet", "type": "Ğ1Wallet", "serviceEndpoint": "g1:<g1pub>" }
    ],
    "verifiableCredential": [
      { "type": ["VerifiableCredential", "MULTIPASS"], "issuer": "...", "status": "active" },
      { "type": ["VerifiableCredential", "SOCIÉTAIRE"], "tier": "satellite", "zen": 540 }
    ],
    "metadata": {
      "email": "user@example.com",
      "created": "2024-01-01T12:00:00Z",
      "updated": "2025-01-22T14:30:00Z",
      "contributions": [],
      "zenBalance": 450
    }
  }
}
```

**Scripts associés :**
- `did_manager_nostr.sh` - Gestion des DIDs
- `dashboard.DID.manager.sh` - Dashboard admin
- `make_NOSTRCARD.sh` - Création MULTIPASS

**Résolution DID :**
```bash
# Format: did:nostr:<hex_pubkey>
# Query: kind:30800 where pubkey == <hex_pubkey> and tags["d"] == "did"
```

---

### Kind 0 - Profile (Metadata public)

Profil public visible sur les clients Nostr.

```json
{
  "kind": 0,
  "pubkey": "<hex>",
  "content": {
    "name": "Alice",
    "about": "Description",
    "picture": "https://...",
    "nip05": "alice@uplanet.com",
    "lud16": "alice@getalby.com"
  }
}
```

**Scripts :** `nostr_setup_profile.py`

---

### Kind 3 - Contacts (Réseau social N1)

Liste des amis directs (Network Level 1).

```json
{
  "kind": 3,
  "pubkey": "<user_hex>",
  "tags": [
    ["p", "<friend1_hex>"],
    ["p", "<friend2_hex>"],
    ["p", "<friend3_hex>"]
  ]
}
```

**Usage :** Définit le réseau N1 pour les journaux, vidéos recommandées, et sync constellation.

**Scripts :** `nostr_follow.sh`, `nostr_get_N1.sh`

---

## 💰 FLUX ÉCONOMIQUES (ZEN)

### Kind 7 - Reaction (+ZEN, Votes, Likes)

L'événement kind 7 est le **mécanisme central** des flux économiques ZEN.

#### 7.1 Réaction standard (+ZEN / Like)

```json
{
  "kind": 7,
  "pubkey": "<sender_hex>",
  "content": "+50",
  "tags": [
    ["e", "<target_event_id>"],
    ["p", "<recipient_hex>"],
    ["t", "UPlanet"]
  ]
}
```

**Content interpretation :**
| Content | Signification |
|---------|---------------|
| `+` | Envoi 1 Ẑen |
| `+50` | Envoi 50 Ẑen |
| `👍` | Like simple (pas de ZEN) |
| `❤️` | Like avec cœur |

#### 7.2 Contribution Crowdfunding

```json
{
  "kind": 7,
  "pubkey": "<contributor_hex>",
  "content": "+100",
  "tags": [
    ["e", "<project_event_id>"],
    ["p", "<BIEN_HEX_PUBKEY>"],
    ["t", "crowdfunding"],
    ["t", "UPlanet"],
    ["project-id", "CF-20250122-XXXX"],
    ["target", "ZEN_CONVERTIBLE"],
    ["i", "g1pub:<BIEN_G1PUB>"]
  ]
}
```

**Processing (7.sh filter) :**
1. Détecte tag `["t", "crowdfunding"]`
2. Extrait `project-id` et `BIEN_HEX`
3. Valide solde sender
4. Transfère sender → BIEN_G1PUB
5. Enregistre contribution

#### 7.3 Vote ASSETS (Crowdfunding)

```json
{
  "kind": 7,
  "pubkey": "<voter_hex>",
  "content": "+5",
  "tags": [
    ["p", "<BIEN_HEX>"],
    ["t", "vote-assets"],
    ["t", "UPlanet"],
    ["project-id", "CF-XXXX"],
    ["vote-type", "ASSETS_USAGE"]
  ]
}
```

**Processing :**
1. Détecte tag `["t", "vote-assets"]`
2. Valide que voter est SOCIÉTAIRE
3. Compte le vote (poids = montant ZEN)
4. Met à jour quorum et seuil

**Scripts :**
- `7.sh` (relay filter) - Traitement des kind 7
- `CROWDFUNDING.sh contribute` - Enregistrement contribution
- `CROWDFUNDING.sh vote` - Enregistrement vote

---

### Kind 30850 - Economic Health Report

Rapport de santé économique diffusé quotidiennement/hebdomadairement par chaque station.

```json
{
  "kind": 30850,
  "pubkey": "<CAPTAIN_HEX>",
  "tags": [
    ["d", "economic-health-W03-2026"],
    ["t", "uplanet"],
    ["t", "economic-health"],
    ["constellation", "<UPLANETG1PUB>"],
    ["station", "<IPFSNODEID>"],
    ["balance:cash", "1250.50"],
    ["balance:assets", "2100.00"],
    ["balance:capital", "480.00"],
    ["revenue:total", "325.00"],
    ["health:status", "healthy"],
    ["health:weeks_runway", "45"]
  ],
  "content": {
    "wallets": { "cash": {...}, "rnd": {...}, "assets": {...} },
    "revenue": { "multipass": {...}, "zencard": {...} },
    "health": { "status": "healthy", "bilan": 283.00 }
  }
}
```

**Diffusion :** `ECONOMY.broadcast.sh` (quotidien/hebdomadaire)

**Collecte :** `economy.Swarm.html` agrège les kind 30850 pour dashboard swarm

---

## 📄 CONTENU & DOCUMENTATION

### Kind 30023 - Long-form Content (Articles/Documents)

Document markdown long (articles, contrats, journaux N², documents collaboratifs).

```json
{
  "kind": 30023,
  "pubkey": "<author_hex>",
  "tags": [
    ["d", "unique-identifier"],
    ["title", "Mon Article"],
    ["t", "UPlanet"],
    ["published_at", "1705939200"],
    ["g", "43.60,1.44"],
    ["latitude", "43.60"],
    ["longitude", "1.44"]
  ],
  "content": "# Titre\n\nContenu markdown complet..."
}
```

**Usages :**

| Type | d-tag pattern | Auteur | Description |
|------|---------------|--------|-------------|
| **Journal N² Daily** | `journal_daily_YYYY-MM-DD` | MULTIPASS | Résumé IA quotidien |
| **Journal N² Weekly** | `journal_weekly_WXX-YYYY` | MULTIPASS | Résumé IA hebdomadaire |
| **Document Collab.** | `commons_<topic>` | UMAP | Document collaboratif |
| **Crowdfunding Doc** | `crowdfunding-CF-XXXX` | BIEN | Campagne crowdfunding |
| **Contrat ORE** | `contract_ORE_<lat>_<lon>` | UMAP | Contrat environnemental |
| **Blog Personnel** | Custom | MULTIPASS | Article personnel |

**Scripts :**
- `N2.journal.sh` - Génération journaux IA
- `CROWDFUNDING.sh` - Publication campagnes
- `UPlanet_IA_Responder.sh` - Contrats ORE

---

### Kind 30904 - Crowdfunding Metadata (JSON)

Métadonnées structurées crowdfunding pour parsing machine par `crowdfunding.html`.

```json
{
  "kind": 30904,
  "pubkey": "<BIEN_HEX>",
  "tags": [
    ["d", "CF-20250122-XXXX"],
    ["t", "crowdfunding"],
    ["t", "UPlanet"],
    ["g", "43.60,1.44"],
    ["project-id", "CF-20250122-XXXX"]
  ],
  "content": {
    "id": "CF-20250122-XXXX",
    "name": "Forêt Enchantée",
    "description": "...",
    "location": { "latitude": 43.60, "longitude": 1.44 },
    "bien_identity": {
      "npub": "npub1xxx...",
      "hex": "abc123...",
      "g1pub": "GfCHe..."
    },
    "owners": [...],
    "totals": { "zen_target": 5000, "zen_collected": 1250 },
    "campaigns": { "zen_active": true, "g1_active": true },
    "vote": { "status": "pending", "threshold": 100, "quorum": 10 }
  }
}
```

---

## 🏛️ SYSTÈME ORACLE (PERMITS)

### Kind 30500 - Permit Definition

Définition d'un type de permis/licence.

```json
{
  "kind": 30500,
  "pubkey": "<UPLANETNAME_G1_hex>",
  "tags": [
    ["d", "PERMIT_ORE_V1"],
    ["t", "permit"],
    ["min_attestations", "5"],
    ["valid_duration_days", "1095"]
  ],
  "content": {
    "id": "PERMIT_ORE_V1",
    "name": "ORE Environmental Verifier",
    "min_attestations": 5,
    "validity_years": 3,
    "reward_zen": 10
  }
}
```

**Permis courants :**
| Permit ID | Attestations | Durée | Description |
|-----------|--------------|-------|-------------|
| `PERMIT_ORE_V1` | 5 | 3 ans | Vérificateur environnemental |
| `PERMIT_DRIVER` | 12 | 15 ans | Permis de conduire WoT |
| `PERMIT_WOT_DRAGON` | 3 | Illimité | Autorité UPlanet |

---

### Kind 30501 - Permit Request

Demande de permis par un utilisateur.

```json
{
  "kind": 30501,
  "pubkey": "<applicant_hex>",
  "tags": [
    ["d", "<request_id>"],
    ["permit", "PERMIT_ORE_V1"],
    ["t", "UPlanet"]
  ],
  "content": {
    "statement": "Je demande ce permis car...",
    "evidence": ["ipfs://Qm..."]
  }
}
```

---

### Kind 30502 - Permit Attestation

Attestation multi-signature par un détenteur de permis.

```json
{
  "kind": 30502,
  "pubkey": "<attester_hex>",
  "tags": [
    ["d", "<attestation_id>"],
    ["e", "<request_event_id>"],
    ["p", "<applicant_hex>"],
    ["permit", "PERMIT_ORE_V1"],
    ["attester_license", "<credential_id>"]
  ],
  "content": {
    "statement": "J'atteste de la compétence...",
    "date": "2025-01-22T12:00:00Z"
  }
}
```

**Règles :**
- L'attesteur DOIT détenir le permis requis
- Un attesteur ne peut attester qu'UNE FOIS par demande
- Signature Schnorr cryptographique

---

### Kind 30503 - Permit Credential (W3C Verifiable Credential)

Credential W3C émis après atteinte du seuil d'attestations.

```json
{
  "kind": 30503,
  "pubkey": "<UPLANETNAME_G1_hex>",
  "tags": [
    ["d", "<credential_id>"],
    ["p", "<holder_hex>"],
    ["permit", "PERMIT_ORE_V1"]
  ],
  "content": {
    "@context": "https://www.w3.org/2018/credentials/v1",
    "type": ["VerifiableCredential", "UPlanetLicense"],
    "issuer": "did:nostr:<UPLANETNAME_G1_hex>",
    "issuanceDate": "2025-01-22T12:00:00Z",
    "expirationDate": "2028-01-22T12:00:00Z",
    "credentialSubject": {
      "id": "did:nostr:<holder_hex>",
      "license": "PERMIT_ORE_V1",
      "attestations": 5
    }
  }
}
```

**Script :** `ORACLE.refresh.sh` - Validation automatique (20h12)

---

## 🌱 SYSTÈME ORE (Environnemental)

### Kind 30312 - ORE Meeting Space

Espace géographique persistant pour vérifications ORE.

```json
{
  "kind": 30312,
  "pubkey": "<UMAP_hex>",
  "tags": [
    ["d", "ore-space-43.60-1.44"],
    ["g", "43.60,1.44"],
    ["room", "UMAP_ORE_43.60_1.44"],
    ["t", "ore-space"]
  ],
  "content": {
    "description": "Espace pour vérifications ORE",
    "vdo_url": "https://vdo.ninja/?room=UMAP_ORE_43.60_1.44",
    "contractId": "ORE-2025-001"
  }
}
```

---

### Kind 30313 - ORE Verification Meeting

Vérification environnementale effectuée.

```json
{
  "kind": 30313,
  "pubkey": "<expert_hex>",
  "tags": [
    ["d", "ore-verification-43.60-1.44-1705939200"],
    ["a", "30312:<authority>:ore-space-43.60-1.44"],
    ["g", "43.60,1.44"],
    ["permit", "PERMIT_ORE_V1"]
  ],
  "content": {
    "result": "compliant",
    "evidence": "ipfs://Qm...",
    "method": "satellite_imagery",
    "notes": "Couverture forestière: 82%"
  }
}
```

**Flux économique :**
1. Contrat ORE → UMAP DID (30800)
2. Espace ORE → 30312
3. Validation expert → 30313
4. Paiement → RnD → UMAP wallet
5. Redistribution → Gardiens locaux

---

## 🔄 SYNCHRONISATION CONSTELLATION

### Events synchronisés via N²

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EVENTS SYNCHRONISÉS (backfill_constellation.sh)           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CORE:     0, 1, 3, 5, 6, 7                                                  │
│  MEDIA:    21, 22, 1063, 1111                                                │
│  CONTENT:  30023, 30024                                                      │
│  IDENTITY: 30800                                                             │
│  ORACLE:   30500, 30501, 30502, 30503                                        │
│  ORE:      30312, 30313                                                      │
│  ECONOMY:  30850                                                             │
│  CF:       30904                                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Script :** `~/.zen/workspace/NIP-101/backfill_constellation.sh`

---

## 📋 Scripts par catégorie

### Identité
| Script | Events | Description |
|--------|--------|-------------|
| `did_manager_nostr.sh` | 30800 | CRUD DID documents |
| `dashboard.DID.manager.sh` | 30800 | Dashboard admin DID |
| `make_NOSTRCARD.sh` | 0, 30800 | Création MULTIPASS |
| `nostr_setup_profile.py` | 0 | Setup profil Nostr |

### Économie
| Script | Events | Description |
|--------|--------|-------------|
| `7.sh` (filter) | 7 | Traitement +ZEN |
| `ECONOMY.broadcast.sh` | 30850 | Diffusion santé éco |
| `CROWDFUNDING.sh` | 7, 30023, 30904 | Gestion crowdfunding |
| `UPLANET.crowdfunding.sh` | 7, 30023, 30904 | Interface capitaine |

### Oracle
| Script | Events | Description |
|--------|--------|-------------|
| `ORACLE.refresh.sh` | 30500-30503 | Validation permits |
| `oracle_api.sh` | 30500-30503 | API Oracle |

### Contenu
| Script | Events | Description |
|--------|--------|-------------|
| `N2.journal.sh` | 30023 | Génération journaux IA |
| `nostr_send_note.py` | 1, 30023 | Publication events |

### ORE
| Script | Events | Description |
|--------|--------|-------------|
| `ore_system.py` | 30312, 30313 | Système ORE |
| `UPlanet_IA_Responder.sh` | 30023, 30312 | Contrats IA |

---

## 🔗 Références

- [NIP-101 - UPlanet Protocol](../nostr-nips/101.md)
- [NIP-101 Oracle Extension](../nostr-nips/42-oracle-permits-extension.md)
- [NIP-101 Economic Health](../nostr-nips/101-economic-health-extension.md)
- [Crowdfunding Contract](./UPlanet_CROWDFUNDING_CONTRACT.md)
- [ZEN Economy](./ZEN.ECONOMY.readme.md)
