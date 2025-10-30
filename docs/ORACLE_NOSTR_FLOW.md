# 🔐 Oracle System - NOSTR Event Flow

## Vue d'ensemble

Le système Oracle d'UPlanet utilise les événements NOSTR (kinds 30500-30503) pour gérer les permis de compétence de manière décentralisée. Ce document décrit le flux complet des événements.

---

## 📋 Types d'événements NOSTR

| Kind  | Nom | Signé par | Description |
|-------|-----|-----------|-------------|
| **30500** | Permit Definition | `UPLANETNAME.G1` | Définition d'un type de permis (règles, validité, etc.) |
| **30501** | Permit Request | Demandeur (A) | Demande de permis soumise par un utilisateur |
| **30502** | Permit Attestation | Attesteur (B,C,D...) | Signature/validation par un expert certifié |
| **30503** | Permit Credential | `UPLANETNAME.G1` | Verifiable Credential (VC) final - permis validé |

---

## 🔄 Flux complet

### Étape 0: Définition des Permis (Kind 30500)

**Qui publie?** L'autorité UPlanet (compte NOSTR `UPLANETNAME.G1`)

```json
{
  "kind": 30500,
  "pubkey": "<UPLANETNAME.G1_HEX_PUBKEY>",
  "tags": [
    ["d", "PERMIT_ORE_V1"],
    ["name", "Permis de Vérificateur ORE"],
    ["min_attestations", "5"],
    ["valid_duration_days", "1095"],
    ["required_license", "PERMIT_WOT_DRAGON"]
  ],
  "content": "{\"description\": \"...\", \"verification_method\": \"peer_attestation\", ...}",
  "created_at": <timestamp>,
  "sig": "<signature_par_UPLANETNAME.G1>"
}
```

**Caractéristiques:**
- Événement **Parameterized Replaceable** (peut être mis à jour)
- Tag `d` (identifier) = ID du permis (ex: `PERMIT_ORE_V1`)
- Signé par la clé NOSTR `UPLANETNAME.G1`
- Définit les règles: nombre d'attestations, durée de validité, prérequis

---

### Étape 1: Demande de Permis (Kind 30501)

**Qui publie?** Le demandeur (MULTIPASS A)

Un utilisateur souhaite obtenir un permis. Il publie un événement **30501** signé par sa propre clé NOSTR.

```json
{
  "kind": 30501,
  "pubkey": "<MULTIPASS_A_HEX_PUBKEY>",
  "tags": [
    ["d", "<REQUEST_ID>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["status", "pending"]
  ],
  "content": "{\"statement\": \"J'ai 5 ans d'expérience...\", \"evidence\": [...]}",
  "created_at": <timestamp>,
  "sig": "<signature_par_A>"
}
```

**Caractéristiques:**
- Événement **Parameterized Replaceable**
- Tag `d` = `REQUEST_ID` unique
- Tag `permit_id` = Type de permis demandé
- Signé par le demandeur (A)
- Contient la déclaration de compétence

---

### Étape 2: Attestations (Kind 30502)

**Qui publie?** Les attesteurs (MULTIPASS B, C, D, ...)

Des experts qui possèdent **déjà** un événement **30503** (permis validé) pour le même type de permis peuvent attester la compétence du demandeur.

#### Exemple: MULTIPASS B atteste pour A

```json
{
  "kind": 30502,
  "pubkey": "<MULTIPASS_B_HEX_PUBKEY>",
  "tags": [
    ["d", "<ATTESTATION_ID>"],
    ["e", "<REQUEST_EVENT_ID>", "", "root"],
    ["p", "<MULTIPASS_A_HEX_PUBKEY>"],
    ["request_id", "<REQUEST_ID>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["attester_credential", "<B_CREDENTIAL_ID>"]
  ],
  "content": "{\"statement\": \"J'ai vérifié personnellement ses compétences...\"}",
  "created_at": <timestamp>,
  "sig": "<signature_par_B>"
}
```

**Caractéristiques:**
- Événement **Parameterized Replaceable**
- Tag `e` = Référence à l'événement de demande (30501)
- Tag `p` = Référence au demandeur (A)
- Tag `attester_credential` = Preuve que B possède le permis requis
- Signé par l'attesteur (B)

**Conditions pour attester:**
1. L'attesteur (B) doit avoir un événement **30503** valide pour ce type de permis
2. Cet événement 30503 doit être signé par `UPLANETNAME.G1`
3. L'attesteur ne peut attester qu'une seule fois par demande

#### Schéma des attestations multiples

```
MULTIPASS A (demandeur)
    ↓
  30501 (demande)
    ↓
    ├─→ MULTIPASS B (30502) ✍️
    ├─→ MULTIPASS C (30502) ✍️
    ├─→ MULTIPASS D (30502) ✍️
    └─→ MULTIPASS E (30502) ✍️
```

---

### Étape 3: Validation par l'Oracle

**Quand?** Chaque soir (tâche automatique)

L'Oracle (processus automatisé) extrait tous les événements de permis et:

#### 3.1. Vérifie les demandes en attente

Pour chaque événement **30501** avec `status: "attesting"`:

1. **Compte les attestations valides (30502)**
   - Vérifie que chaque attesteur a bien un événement 30503 validé
   - Vérifie que les signatures sont correctes
   - Compte le nombre d'attestations uniques

2. **Compare au seuil requis**
   - Lit la définition du permis (30500)
   - Vérifie si `nb_attestations >= min_attestations`

3. **Décide de l'action**
   - Si seuil atteint → Émet un événement **30503** (permis validé)
   - Si date limite dépassée → Marque la demande comme expirée
   - Si seuil non atteint → Continue d'attendre

#### 3.2. Nettoie les demandes expirées

Pour chaque événement **30501** avec `status: "pending"` ou `"attesting"`:

1. Vérifie la date de création
2. Si `created_at + deadline > now` → Supprime/révoque la demande
3. Publie un événement de mise à jour avec `status: "expired"`

---

### Étape 4: Émission du Credential (Kind 30503)

**Qui publie?** L'Oracle (avec la clé NOSTR `UPLANETNAME.G1`)

Une fois le seuil d'attestations atteint, l'Oracle émet un événement **30503** qui constitue le **Verifiable Credential** (VC) final.

```json
{
  "kind": 30503,
  "pubkey": "<UPLANETNAME.G1_HEX_PUBKEY>",
  "tags": [
    ["d", "<CREDENTIAL_ID>"],
    ["p", "<MULTIPASS_A_HEX_PUBKEY>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["request_id", "<REQUEST_ID>"],
    ["issued_at", "<ISO_DATE>"],
    ["expires_at", "<ISO_DATE>"],
    ["attestation_count", "5"],
    ["attesters", "<B_PUBKEY>", "<C_PUBKEY>", "<D_PUBKEY>", "<E_PUBKEY>", "<F_PUBKEY>"]
  ],
  "content": "{\"@context\": [...], \"type\": [\"VerifiableCredential\", \"UPlanetLicense\"], ...}",
  "created_at": <timestamp>,
  "sig": "<signature_par_UPLANETNAME.G1>"
}
```

**Caractéristiques:**
- Événement **Parameterized Replaceable**
- Tag `d` = `CREDENTIAL_ID` unique
- Tag `p` = Référence au bénéficiaire (A)
- Tag `permit_id` = Type de permis
- Tag `attesters` = Liste des attesteurs
- **Signé par `UPLANETNAME.G1`** (clé d'autorité UPlanet)
- Contenu = W3C Verifiable Credential (JSON-LD)

---

## 🔍 Vérification de validité d'un permis

Pour vérifier qu'un MULTIPASS possède un permis valide:

1. **Chercher l'événement 30503**
   - Filter: `kind: 30503`, `#p: <PUBKEY>`, `#permit_id: <PERMIT_ID>`

2. **Vérifier la signature**
   - La signature `sig` doit être vérifiable avec la clé publique `UPLANETNAME.G1`

3. **Vérifier la date d'expiration**
   - Comparer `expires_at` avec la date actuelle

4. **Vérifier le statut**
   - Le credential ne doit pas être révoqué

---

## 🔄 Renouvellement d'un permis

Un utilisateur peut renouveler un permis avant son expiration:

1. **Soumet une nouvelle demande 30501**
   - Tag `renewing` = `true`
   - Tag `previous_credential` = `<ANCIEN_CREDENTIAL_ID>`

2. **Le processus recommence**
   - Nouvelles attestations requises (30502)
   - Nouvel événement 30503 émis si validé

---

## 📊 Schéma complet du flux

```
┌──────────────────────────────────────────────────────────────┐
│                    Autorité UPlanet                          │
│                  (UPLANETNAME.G1)                            │
└────────┬─────────────────────────────────────────────┬───────┘
         │                                             │
         │ 1. Publie définition                       │ 4. Signe credential
         ▼                                             ▼
    ┌────────┐                                    ┌────────┐
    │ 30500  │                                    │ 30503  │
    │ Permit │                                    │  VC    │
    │  Def   │                                    │ Final  │
    └────────┘                                    └────────┘
         │                                             ▲
         │                                             │
         │ 2. Demandeur A                             │ 3. Attesteurs B,C,D
         │    soumet demande                          │    signent
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
         └─────────────────────────▶│ Système  │
                                    │ (nightly)│
                                    └──────────┘
                                         │
                                         │ Vérifie seuil
                                         │ atteint
                                         ▼
                                    ┌────────┐
                                    │ 30503  │
                                    │   VC   │
                                    │ signé  │
                                    └────────┘
```

---

## 💰 Récompenses économiques (optionnel)

Après l'émission d'un événement **30503** pour certains permis (ex: `PERMIT_WOT_DRAGON`), UPlanet peut envoyer une récompense économique:

```bash
UPLANET.official.sh -p EMAIL PERMIT_ID MONTANT
```

Cette commande:
1. Vérifie l'existence du credential 30503
2. Effectue un virement de Ẑen depuis le portefeuille `UPLANETNAME.RnD`
3. Met à jour le DID du bénéficiaire avec `PERMIT_ISSUED` status

---

## 🛠️ Interface Utilisateur (`/oracle`)

L'interface web `/oracle` permet:

1. **Voir les permis disponibles (30500)**
   - Liste de tous les types de permis
   - Règles et conditions

2. **Voir les détenteurs (30503)**
   - Pour chaque permis, liste des MULTIPASS qui le possèdent

3. **Connexion NOSTR (NIP-42)**
   - Authentification avec extension NOSTR

4. **Souscrire/renouveler un permis**
   - Soumet un événement 30501

5. **Attester les demandes**
   - Visualiser les demandes 30501 nécessitant attestation
   - Soumettre un événement 30502 (si autorisé)

---

## 🔐 Sécurité et intégrité

### Vérifications automatiques par l'Oracle

1. **Signature de l'attesteur**
   - Chaque événement 30502 doit être signé par l'attesteur

2. **Credential de l'attesteur**
   - L'attesteur doit avoir un événement 30503 valide
   - Cet événement doit être signé par `UPLANETNAME.G1`

3. **Unicité des attestations**
   - Un attesteur ne peut signer qu'une seule fois par demande

4. **Date limite**
   - Les demandes expirées sont automatiquement nettoyées

### Protection contre les abus

1. **Révocation de permis**
   - Pour les permis `revocable: true`
   - Publication d'un événement de révocation (kind 5)

2. **Liste noire**
   - Les MULTIPASS ayant fraudé peuvent être blacklistés

---

## 📚 Références

- **NIP-33**: Parameterized Replaceable Events
- **NIP-42**: Authentication (NIP-42)
- **W3C Verifiable Credentials**: https://www.w3.org/TR/vc-data-model/
- **DID NOSTR Spec**: https://github.com/nostr-protocol/nips/blob/master/11.md

---

## 🎯 Résumé

| Étape | Événement | Signé par | Objectif |
|-------|-----------|-----------|----------|
| 0 | **30500** | `UPLANETNAME.G1` | Définir les règles du permis |
| 1 | **30501** | Demandeur (A) | Demander le permis |
| 2 | **30502** | Attesteurs (B,C,D...) | Attester la compétence |
| 3 | - | Oracle (automatique) | Vérifier le seuil d'attestations |
| 4 | **30503** | `UPLANETNAME.G1` | Émettre le Verifiable Credential |

**Point clé:** Le système est décentralisé (NOSTR), mais l'autorité finale (signature du VC) reste centralisée sur la clé `UPLANETNAME.G1` pour garantir l'intégrité du réseau UPlanet.

