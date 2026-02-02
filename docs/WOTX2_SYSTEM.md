# 🔗 WoTx2 System - Documentation Complète

**Version**: 1.0 - Système de Toiles de Confiance Dynamiques  
**Date**: Décembre 2025  
**Status**: Production - Maîtrises Auto-Proclamées avec Progression Automatique Illimitée  
**License**: AGPL-3.0

> **Système WoTx2 100% Dynamique** : Ce document décrit l'implémentation complète du système WoTx2 qui permet la création et la progression automatique illimitée de maîtrises auto-proclamées via des toiles de confiance décentralisées.

---

## 📖 Table des Matières

1. [Vue d'Ensemble](#1-vue-densemble)
2. [Architecture WoTx2](#2-architecture-wotx2)
3. [Système de Progression Automatique](#3-système-de-progression-automatique)
4. [Workflow Complet](#4-workflow-complet)
5. [Événements NOSTR](#5-événements-nostr)
6. [Implémentation Backend](#6-implémentation-backend)
7. [Implémentation Frontend](#7-implémentation-frontend)
8. [API Reference](#8-api-reference)
9. [Exemples Concrets](#9-exemples-concrets)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Vue d'Ensemble

### 1.1. Qu'est-ce que WoTx2 ?

**WoTx2** (Web of Trust eXtended 2) est un système décentralisé de **toiles de confiance dynamiques** pour la certification de compétences. Il permet à n'importe quel utilisateur de créer une maîtrise auto-proclamée qui évolue automatiquement de niveau en niveau selon les validations par les pairs.

### 1.2. Philosophie

Le système WoTx2 transforme la certification traditionnelle d'autorités centralisées vers une **certification validée par les pairs avec progression automatique** :

- **Création libre** : N'importe qui peut créer une maîtrise auto-proclamée
- **Progression automatique** : X1 → X2 → X3 → ... → X144 → ... (illimité)
- **Compétences révélées** : Les compétences sont découvertes progressivement lors des attestations
- **Aucun bootstrap requis** : Démarre avec 1 signature (vs N+1 pour les permits officiels)
- **Évolution continue** : Le système crée automatiquement les niveaux suivants

### 1.3. Différence avec le Système Oracle Standard

| Aspect | Oracle Standard | WoTx2 |
|--------|----------------|-------|
| **Création** | Par UPLANETNAME_G1 (admin) | Par utilisateur (auto-proclamé) |
| **ID** | Fixe (ex: PERMIT_ORE_V1) | Dynamique (PERMIT_*_X1) |
| **Progression** | Statique | Automatique illimitée X1→X2→...→X144→... |
| **Compétences** | Définies à la création | Révélées progressivement |
| **Bootstrap** | Requis (N+1 membres) | Non requis (démarre avec 1) |
| **Utilisation** | Permis officiels | Maîtrises libres |

---

## 2. Architecture WoTx2

### 2.1. Schéma d'Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTÈME WOTX2                             │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐
│  Frontend (wotx2.html)│         │  Backend (54321.py)  │
│                      │         │                      │
│ • Interface Web      │◄────────►│ • Route /wotx2       │
│ • MULTIPASS Auth     │         │ • API /api/permit/*  │
│ • NOSTR Events       │         │ • NIP-42 Auth        │
│ • Progression UI     │         │ • Oracle System       │
└──────────────────────┘         └──────────────────────┘
         │                                │
         │                                │
         ▼                                ▼
┌─────────────────────────────────────────────────────────────┐
│              NOSTR Relay Network                            │
│  • Kind 30500: Permit Definitions                          │
│  • Kind 30501: Permit Requests                            │
│  • Kind 30502: Permit Attestations                         │
│  • Kind 30503: Verifiable Credentials                      │
│  • Kind 22242: NIP-42 Authentication                       │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│         ORACLE.refresh.sh (Maintenance Quotidienne)         │
│  • Validation des demandes 30501                           │
│  • Émission des credentials 30503                          │
│  • Progression automatique WoTx2 (X1 → X2 → ...)          │
│  • Authentification NIP-42 pour création de niveaux        │
└─────────────────────────────────────────────────────────────┘
```

### 2.2. Composants Principaux

#### Frontend (`wotx2.html`)
- Interface web pour créer et gérer les maîtrises auto-proclamées
- Connexion MULTIPASS via NIP-42
- Publication directe d'événements NOSTR (30501, 30502)
- Affichage de la progression automatique

#### Backend (`54321.py`)
- Route `/wotx2` : Interface principale
- API `/api/permit/define` : Création de permits (avec NIP-42)
- API `/api/permit/issue/{request_id}` : Émission de credentials
- Intégration avec `oracle_system.py`

#### Oracle System (`oracle_system.py`)
- Gestion des définitions de permits (30500)
- Validation des demandes et attestations
- Émission de credentials W3C (30503)

#### Maintenance (`ORACLE.refresh.sh`)
- Vérification quotidienne des demandes
- Progression automatique WoTx2
- Authentification NIP-42 pour création de niveaux

---

## 3. Système de Progression Automatique

### 3.1. Principe de Progression Illimitée

Le système **WoTx2** permet la création de **maîtrises auto-proclamées** qui évoluent automatiquement de niveau en niveau selon les validations.

### 3.2. Workflow de Progression

```
┌─────────────────────────────────────────────────────────────────┐
│  MAÎTRISE AUTO-PROCLAMÉE - PROGRESSION AUTOMATIQUE           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────┐
│  Niveau X1  │  Création initiale par l'utilisateur
│             │  • ID: PERMIT_[NOM]_X1
│ 1 signature │  • 1 attestation requise
│             │  • Compétence réclamée dans la demande 30501
└──────┬──────┘
       │
       │ ✅ 1 attestation (30502) reçue
       │ ✅ ORACLE.refresh.sh émet 30503
       │ ✅ Authentifie avec NIP-42 (kind 22242)
       │ ✅ Crée automatiquement X2
       ▼
┌─────────────┐
│  Niveau X2 │  Créé automatiquement par ORACLE.refresh.sh
│           │  • ID: PERMIT_[NOM]_X2
│ 2 signatures│  • 2 compétences + 2 attestations requises
│ 2 compétences│  • Enrichi des compétences révélées en X1
└──────┬──────┘
       │
       │ ✅ 2 attestations (30502) reçues
       │ ✅ ORACLE.refresh.sh émet 30503
       │ ✅ Authentifie avec NIP-42
       │ ✅ Crée automatiquement X3
       ▼
┌─────────────┐
│  Niveau X3  │  Créé automatiquement
│             │  • 3 compétences + 3 attestations requises
└──────┬──────┘
       │
       │ ✅ Progression continue...
       ▼
┌─────────────┐
│  Niveau Xn  │  Progression automatique infinie
│             │  • Chaque niveau nécessite N compétences et N signatures
│ N signatures│  • Labels: Expert (X5-X10), Maître (X11-X50), 
│ N compétences│    Grand Maître (X51-X100), Maître Absolu (X101+)
└─────────────┘
```

### 3.3. Labels Dynamiques

| Niveau | Label | Exigences |
|--------|-------|-----------|
| X1-X4 | Niveau Xn | N signatures, N compétences |
| X5-X10 | Niveau Xn (Expert) | N signatures, N compétences |
| X11-X50 | Niveau Xn (Maître) | N signatures, N compétences |
| X51-X100 | Niveau Xn (Grand Maître) | N signatures, N compétences |
| X101+ | Niveau Xn (Maître Absolu) | N signatures, N compétences |

### 3.4. Découverte Progressive des Compétences

Les compétences ne sont **pas définies à la création** mais **révélées progressivement** lors des attestations :

1. **Création X1** : Aucune compétence définie
2. **Première demande 30501** : L'apprenti réclame une compétence (ex: "Natation")
3. **Attestation 30502** : Le maître peut :
   - Transférer des compétences existantes
   - Révéler de nouvelles compétences (ex: "Sauvetage", "Aqua-fitness")
4. **Validation X1** : Les compétences révélées enrichissent le système
5. **Création X2** : Nécessite 2 compétences + 2 signatures
6. **Progression continue** : Chaque niveau révèle de nouvelles compétences

---

## 4. Workflow Complet

### 4.1. Création d'une Maîtrise Auto-Proclamée

**Interface**: `/wotx2` → "Créer une Nouvelle Maîtrise WoTx2"

1. **Formulaire** :
   - ✅ Cocher "Maîtrise Auto-Proclamée"
   - Saisir le nom de la maîtrise (ex: "Maître Nageur")
   - L'ID est généré automatiquement : `PERMIT_MAITRE_NAGEUR_X1`
   - Ajouter une description

2. **Publication** :
   - Appel API `/api/permit/define` avec authentification NIP-42
   - Événement kind 30500 publié sur Nostr
   - Signé par `UPLANETNAME_G1`
   - `min_attestations: 1` (démarrage X1)

3. **Résultat** :
   - Le permit apparaît dans `/oracle` et `/wotx2`
   - Les utilisateurs peuvent créer des demandes 30501

### 4.2. Demande d'Apprentissage (30501)

**Interface**: `/wotx2` → "Devenir Apprenti"

1. **Sélection du permit** :
   - Choisir parmi tous les permits disponibles (officiels ou auto-proclamés)
   - Voir le niveau si c'est une maîtrise Xn

2. **Formulaire** :
   - Déclaration d'apprentissage (minimum 20 caractères)
   - **Compétence réclamée** (obligatoire) : ex: "Natation", "Sauvetage"
   - Preuves de motivation (liens IPFS, optionnel)
   - Géolocalisation (automatique si autorisée)

3. **Publication** :
   - Événement kind 30501 publié directement sur Nostr par le MULTIPASS
   - Signé par le MULTIPASS de l'apprenti
   - Apparaît dans "Apprentis Cherchant un Maître"

### 4.3. Attestation (30502)

**Interface**: `/wotx2` → "Apprentis Cherchant un Maître" → Bouton "Attester"

1. **Conditions** :
   - L'attesteur doit avoir un credential 30503 pour ce permit (ou un niveau supérieur)
   - L'attesteur ne peut pas s'attester lui-même

2. **Formulaire** :
   - Déclaration d'attestation
   - Compétences à transférer (si l'attesteur en a)
   - Compétences révélées (nouvelles compétences découvertes)
   - Géolocalisation (optionnel)

3. **Publication** :
   - Événement kind 30502 publié directement sur Nostr par le MULTIPASS
   - Signé par le MULTIPASS de l'attesteur
   - Référence la demande 30501 (tag `e`)

### 4.4. Validation et Émission de Credential (30503)

**Processus automatique** : `ORACLE.refresh.sh` (exécuté quotidiennement)

1. **Vérification** :
   - Récupère toutes les demandes 30501 depuis Nostr **filtrées par IPFSNODEID** (évite les conflits entre Astroports)
   - Compte les attestations 30502 pour chaque demande **filtrées par IPFSNODEID**
   - Vérifie si le seuil est atteint (`attestations_count >= min_attestations`)

2. **Émission** :
   - Si seuil atteint → Appelle `/api/permit/issue/${request_id}`
   - L'API émet un événement kind 30503 (Verifiable Credential)
   - Signé par `UPLANETNAME_G1`
   - Le credential est un W3C Verifiable Credential standard

3. **Nettoyage** :
   - Supprime le fichier 30501 du répertoire MULTIPASS
   - La demande disparaît de "Apprentis Cherchant un Maître"
   - L'utilisateur apparaît dans "Maîtres Certifiés"

### 4.5. Progression Automatique (WoTx2 uniquement)

**Processus automatique** : `ORACLE.refresh.sh` (après émission 30503)

1. **Détection** :
   - Détecte si le permit est auto-proclamé : `PERMIT_*_X{n}`
   - Extrait le niveau actuel (X1, X2, X3, ...)

2. **Calcul du niveau suivant** :
   - `next_level = current_level + 1`
   - `next_permit_id = PERMIT_[NOM]_X{next_level}`
   - `min_attestations = next_level`

3. **Authentification NIP-42** :
   - Charge la clé `UPLANETNAME_G1` depuis `~/.zen/game/uplanet.G1.nostr`
   - Envoie un événement kind 22242 (NIP-42) via `nostr_send_note.py`
   - Attend 1 seconde pour le traitement par le relay

4. **Création du niveau suivant** :
   - Appelle `/api/permit/define` avec authentification NIP-42
   - Header `X-Nostr-Auth: ${UPLANETNAME_G1_NPUB}`
   - Crée le nouveau permit 30500 avec métadonnées de progression

5. **Résultat** :
   - Le nouveau niveau apparaît dans `/oracle` et `/wotx2`
   - Les utilisateurs peuvent créer des demandes pour ce niveau
   - Le cycle recommence

---

## 5. Événements NOSTR

### 5.0. Tag IPFSNODEID - Filtrage par Astroport

**Important** : Tous les événements WoTx2 (30500, 30501, 30502, 30503) incluent un tag `ipfs_node` avec la valeur `IPFSNODEID` de l'Astroport qui les a créés.

**Raison** : Dans une constellation UPlanet, plusieurs Astroports partagent le même relay Nostr. Le tag `ipfs_node` permet à chaque Astroport de filtrer et gérer uniquement ses propres événements, évitant les conflits entre stations.

**Format du tag** :
```json
["ipfs_node", "<IPFSNODEID>"]
```

**Exemple** : Si `IPFSNODEID=QmAbc123...`, tous les événements créés par cet Astroport incluront :
```json
["ipfs_node", "QmAbc123..."]
```

**Filtrage** :
- `ORACLE.refresh.sh` filtre automatiquement les événements par `IPFSNODEID` avant traitement
- Le frontend `wotx2.html` filtre également les événements lors de la récupération depuis Nostr
- Les requêtes utilisent le filtre `#ipfs_node: [IPFSNODEID]` pour ne récupérer que les événements de cet Astroport

**Compatibilité** : Les événements sans tag `ipfs_node` sont ignorés par `ORACLE.refresh.sh` si `IPFSNODEID` est défini, assurant la compatibilité avec les anciens événements tout en isolant les nouveaux.

**ORACLE des ORACLES - Station Primaire** :
- La station primaire (premier node dans `A_boostrap_nodes.txt`) peut fonctionner en mode "ORACLE des ORACLES"
- En mode primaire, `ORACLE.refresh.sh` traite **tous les permits de toutes les stations** de la constellation
- Cette fonctionnalité permet une vue globale et centralisée de tous les permits dans une constellation UPlanet
- La détection se fait automatiquement en comparant `IPFSNODEID` avec le premier STRAP dans `A_boostrap_nodes.txt` (même logique que `_UPLANET.refresh.sh`)
- En mode primaire, aucun filtre par `IPFSNODEID` n'est appliqué, permettant de traiter tous les événements

### 5.1. Kind 30500 - Permit Definition

**Publié par** : `UPLANETNAME_G1` (via API avec NIP-42)

```json
{
  "kind": 30500,
  "pubkey": "<UPLANETNAME_G1_hex>",
  "tags": [
    ["d", "PERMIT_MAITRE_NAGEUR_X1"],
    ["t", "permit"],
    ["t", "definition"],
    ["t", "auto_proclaimed"],
    ["ipfs_node", "<IPFSNODEID>"]
  ],
  "content": "{
    \"id\": \"PERMIT_MAITRE_NAGEUR_X1\",
    \"name\": \"Maître Nageur\",
    \"description\": \"Enseignement de la natation et du sauvetage\",
    \"min_attestations\": 1,
    \"valid_duration_days\": 0,
    \"revocable\": true,
    \"verification_method\": \"peer_attestation\",
    \"metadata\": {
      \"category\": \"auto_proclaimed\",
      \"level\": \"X1\",
      \"auto_proclaimed\": true,
      \"evolving_system\": {
        \"type\": \"WoTx2_AutoProclaimed\",
        \"auto_progression\": true,
        \"progression_rules\": {
          \"x1\": {
            \"signatures\": 1,
            \"competencies\": 0,
            \"next_level\": \"X2\"
          }
        }
      }
    }
  }",
  "created_at": <timestamp>,
  "sig": "<signature>"
}
```

### 5.2. Kind 30501 - Permit Request

**Publié par** : Candidat (MULTIPASS directement sur Nostr)

```json
{
  "kind": 30501,
  "pubkey": "<applicant_hex>",
  "tags": [
    ["d", "req_abc123"],
    ["l", "PERMIT_MAITRE_NAGEUR_X1", "permit_type"],
    ["p", "<applicant_npub>"],
    ["t", "permit"],
    ["t", "request"],
    ["ipfs_node", "<IPFSNODEID>"],
    ["g", "48.8566", "2.3522"]
  ],
  "content": "{
    \"request_id\": \"req_abc123\",
    \"permit_definition_id\": \"PERMIT_MAITRE_NAGEUR_X1\",
    \"applicant_did\": \"did:nostr:<applicant_npub>\",
    \"statement\": \"Je souhaite apprendre la natation...\",
    \"requested_competency\": \"Natation\",
    \"evidence\": [\"ipfs://Qm...\"],
    \"status\": \"pending\",
    \"location\": {
      \"latitude\": 48.8566,
      \"longitude\": 2.3522,
      \"timestamp\": \"2025-12-01T12:00:00Z\"
    }
  }",
  "created_at": <timestamp>,
  "sig": "<signature>"
}
```

### 5.3. Kind 30502 - Permit Attestation

**Publié par** : Attesteur (MULTIPASS directement sur Nostr)

```json
{
  "kind": 30502,
  "pubkey": "<attester_hex>",
  "tags": [
    ["d", "attest_xyz789"],
    ["e", "<request_event_id>"],
    ["p", "<applicant_npub>"],
    ["t", "permit"],
    ["t", "attestation"],
    ["ipfs_node", "<IPFSNODEID>"],
    ["competency", "Natation"],
    ["competency", "Sauvetage"],
    ["g", "48.8566", "2.3522"]
  ],
  "content": "{
    \"attestation_id\": \"attest_xyz789\",
    \"request_id\": \"req_abc123\",
    \"attester_did\": \"did:nostr:<attester_npub>\",
    \"statement\": \"Je certifie que cette personne possède les compétences...\",
    \"competencies_transferred\": [\"Natation\", \"Sauvetage\"],
    \"revealed_competencies\": [\"Aqua-fitness\"],
    \"location\": {
      \"latitude\": 48.8566,
      \"longitude\": 2.3522,
      \"timestamp\": \"2025-12-01T12:00:00Z\"
    }
  }",
  "created_at": <timestamp>,
  "sig": "<signature>"
}
```

### 5.4. Kind 30503 - Verifiable Credential

**Publié par** : `UPLANETNAME_G1` (après validation par ORACLE.refresh.sh)

```json
{
  "kind": 30503,
  "pubkey": "<UPLANETNAME_G1_hex>",
  "tags": [
    ["d", "cred_abc123"],
    ["p", "<holder_npub>"],
    ["permit_id", "PERMIT_MAITRE_NAGEUR_X1"],
    ["request_id", "req_abc123"],
    ["issued_at", "2025-12-01T12:00:00Z"],
    ["attestation_count", "1"],
    ["ipfs_node", "<IPFSNODEID>"]
  ],
  "content": "{
    \"@context\": [
      \"https://www.w3.org/2018/credentials/v1\",
      \"https://u.copylaradio.com/credentials/v1\"
    ],
    \"type\": [\"VerifiableCredential\", \"UPlanetLicense\"],
    \"id\": \"urn:uuid:...\",
    \"issuer\": \"did:nostr:<UPLANETNAME_G1_hex>\",
    \"issuanceDate\": \"2025-12-01T12:00:00Z\",
    \"credentialSubject\": {
      \"id\": \"did:nostr:<holder_npub>\",
      \"license\": \"PERMIT_MAITRE_NAGEUR_X1\",
      \"attestations\": 1,
      \"level\": \"X1\",
      \"competencies\": [\"Natation\", \"Sauvetage\", \"Aqua-fitness\"]
    },
    \"proof\": {
      \"type\": \"NostrSignature2024\",
      \"created\": \"2025-12-01T12:00:00Z\",
      \"proofPurpose\": \"assertionMethod\",
      \"verificationMethod\": \"did:nostr:<UPLANETNAME_G1_hex>#keys-1\",
      \"jws\": \"<nostr_signature>\"
    }
  }",
  "created_at": <timestamp>,
  "sig": "<signature_par_UPLANETNAME_G1>"
}
```

### 5.5. Kind 22242 - NIP-42 Authentication

**Publié par** : `UPLANETNAME_G1` (avant chaque appel API pour progression automatique)

```json
{
  "kind": 22242,
  "pubkey": "<UPLANETNAME_G1_hex>",
  "tags": [
    ["relay", "ws://127.0.0.1:7777"],
    ["challenge", "oracle_refresh_<timestamp>_<permit_id>"]
  ],
  "content": "oracle_refresh_<timestamp>_<permit_id>",
  "created_at": <timestamp>,
  "sig": "<signature>"
}
```

---

## 6. Implémentation Backend

### 6.1. Route `/wotx2`

**Fichier**: `UPassport/54321.py` (lignes 1665-1760)

```python
@app.get("/wotx2", response_class=HTMLResponse)
async def get_wotx2(request: Request, npub: Optional[str] = None, permit_id: Optional[str] = None):
    """WoTx2 Permit Interface - Evolving Web of Trust for Competency Mastery
    
    This interface reads all data from Nostr relays. The API only serves to initialize the page.
    All permit requests (30501) and attestations (30502) are managed directly via Nostr by each MULTIPASS.
    Only permit definitions (30500) and credentials (30503) are managed by UPLANETNAME_G1 via the API.
    """
```

**Fonctionnalités** :
- Récupère les définitions de permits depuis Nostr (kind 30500)
- Fusionne avec les définitions locales (oracle_system.definitions)
- Sélectionne le permit demandé ou le premier disponible
- Passe les données au template `wotx2.html`

**Paramètres** :
- `npub` : Clé publique NOSTR optionnelle pour l'authentification
- `permit_id` : ID du permit à afficher (défaut: "PERMIT_DE_NAGER")

### 6.2. API `/api/permit/define`

**Fichier**: `UPassport/54321.py` (lignes 7039-7132)

**Authentification** : NIP-42 requise

**Fonctionnalités** :
- Crée une nouvelle définition de permit (kind 30500)
- Vérifie l'authentification NIP-42
- Génère automatiquement l'ID pour les maîtrises auto-proclamées
- Publie l'événement sur Nostr via `oracle_system.create_permit_definition()`
- Sauvegarde l'événement dans le répertoire MULTIPASS du créateur

**Exemple de requête** :
```json
{
  "permit": {
    "id": "PERMIT_MAITRE_NAGEUR_X1",
    "name": "Maître Nageur",
    "description": "Enseignement de la natation",
    "min_attestations": 1,
    "metadata": {
      "category": "auto_proclaimed",
      "auto_proclaimed": true,
      "level": "X1"
    }
  },
  "npub": "npub1...",
  "bootstrap_emails": null
}
```

### 6.3. API `/api/permit/issue/{request_id}`

**Fichier**: `UPassport/54321.py` (lignes 7427-7475)

**Fonctionnalités** :
- Émet un credential (kind 30503) pour une demande validée
- Appelé automatiquement par `ORACLE.refresh.sh`
- Vérifie que le seuil d'attestations est atteint
- Crée un W3C Verifiable Credential
- Publie l'événement sur Nostr

### 6.4. Intégration avec Oracle System

Le système WoTx2 s'intègre avec `oracle_system.py` pour :
- Gestion des définitions de permits
- Validation des demandes et attestations
- Émission de credentials W3C
- Progression automatique (via `ORACLE.refresh.sh`)

### 6.5. Contextes JSON-LD (API u)

Le `@context` des Verifiable Credentials (kind 30503) inclut `https://u.copylaradio.com/credentials/v1`. Ce contexte est servi par l’API (54321.py) : **GET** `/credentials/v1` et **GET** `/credentials/v1/` retournent le document JSON-LD (`Content-Type: application/ld+json`) qui définit les termes UPlanet (UPlanetLicense, license, licenseName, holderNpub, attestationsCount, status). L’API sert également **GET** `/ns/v1` (et `/ns/v1/`) pour le contexte des documents DID (CooperativeWallet, IPFSGateway, etc.). Voir [DID_IMPLEMENTATION.md](../DID_IMPLEMENTATION.md) (section « Contextes JSON-LD et API Astroport (u) »).

---

## 7. Implémentation Frontend

### 7.1. Template `wotx2.html`

**Fichier**: `UPassport/templates/wotx2.html`

**Fonctionnalités principales** :

1. **Connexion MULTIPASS** :
   - Badge de connexion en haut à droite
   - Authentification NIP-42 via `common.js`
   - Accès à uDRIVE et GPS

2. **Sélecteur de Permits** :
   - Liste déroulante de tous les permits disponibles
   - Affichage des niveaux (X1, X2, X3, ...)
   - Bouton "Créer une Nouvelle Maîtrise"

3. **Liste de Tous les Permits** :
   - Affichage en grille (similaire à `/oracle`)
   - Statistiques par permit (titulaires, demandes en attente)
   - Bouton de suppression (si créateur et aucun 30503)

4. **Interface de Demande** :
   - Modal "Devenir Apprenti"
   - Formulaire avec compétence réclamée
   - Publication directe d'événement 30501 sur Nostr

5. **Interface d'Attestation** :
   - Modal "Attester une Demande"
   - Transfert de compétences
   - Révélation de nouvelles compétences
   - Publication directe d'événement 30502 sur Nostr

6. **Affichage des Résultats** :
   - "Maîtres Certifiés" : Liste des credentials 30503
   - "Apprentis Cherchant un Maître" : Liste des demandes 30501 sans 30503
   - Barre de progression pour chaque demande

### 7.2. Publication Directe sur Nostr

**Important** : Les événements 30501 et 30502 sont publiés **directement sur Nostr** par le MULTIPASS, pas via l'API.

**Code JavaScript** (extrait de `wotx2.html`) :
```javascript
// Publication d'un événement 30501
const signedEvent = await window.nostr.signEvent(event);

// Publication sur le relay (via common.js nostrRelay)
if (typeof nostrRelay !== 'undefined' && nostrRelay && isNostrConnected) {
    await nostrRelay.publish(signedEvent);
}
```

### 7.3. Chargement des Données depuis Nostr

Le frontend charge les données directement depuis Nostr :

```javascript
// Chargement des demandes 30501
const requests = await fetchNostrEvents(30501, {
    '#l': [permitData.id, 'permit_type']
});

// Chargement des credentials 30503
const credentials = await fetchNostrEvents(30503, {
    '#l': [permitData.id, 'permit_type']
});
```

---

## 8. API Reference

### 8.1. Endpoints Principaux

#### GET `/wotx2`
Interface web principale pour WoTx2

**Query Parameters** :
- `npub` (optionnel) : Clé publique NOSTR
- `permit_id` (optionnel) : ID du permit à afficher

**Réponse** : HTML (template `wotx2.html`)

#### POST `/api/permit/define`
Crée une nouvelle définition de permit (30500)

**Authentification** : NIP-42 requise

**Body** :
```json
{
  "permit": {
    "id": "PERMIT_MAITRE_NAGEUR_X1",
    "name": "Maître Nageur",
    "description": "...",
    "min_attestations": 1,
    "metadata": {...}
  },
  "npub": "npub1...",
  "bootstrap_emails": null
}
```

**Headers** :
- `Content-Type: application/json`
- `X-Nostr-Auth: npub1...` (NIP-42 authenticated npub)

#### POST `/api/permit/issue/{request_id}`
Émet un credential (30503) pour une demande validée

**Authentification** : Automatique (ORACLE.refresh.sh)

**Réponse** :
```json
{
  "success": true,
  "credential_id": "cred_abc123",
  "event_id": "nostr_event_id"
}
```

#### GET `/api/permit/definitions`
Récupère toutes les définitions de permits (30500)

**Réponse** :
```json
{
  "success": true,
  "permits": [
    {
      "id": "PERMIT_MAITRE_NAGEUR_X1",
      "name": "Maître Nageur",
      "description": "...",
      "min_attestations": 1,
      "holders_count": 5,
      "pending_requests_count": 2
    }
  ]
}
```

---

## 9. Exemples Concrets

### 9.1. Exemple Complet : "Maître Nageur"

#### Jour 1 : Création de la Maîtrise
```
Alice crée "Maître Nageur" via /wotx2
  └─> PERMIT_MAITRE_NAGEUR_X1 créé
      └─> 1 signature requise
      └─> Événement 30500 publié sur Nostr
```

#### Jour 2 : Première Demande
```
Bob crée demande 30501 pour X1
  └─> Compétence réclamée: "Natation"
      └─> Apparaît dans "Apprentis Cherchant un Maître"
      └─> Événement 30501 publié directement sur Nostr
```

#### Jour 3 : Attestation
```
Alice (créatrice) atteste Bob (30502)
  └─> Bob reçoit 1 attestation
      └─> Compétences révélées: "Sauvetage", "Aqua-fitness"
      └─> Seuil atteint (1/1)
      └─> Événement 30502 publié directement sur Nostr
```

#### Jour 4 : Validation Automatique
```
ORACLE.refresh.sh s'exécute
  └─> Détecte que Bob a 1 attestation (seuil atteint)
      └─> Émet 30503 pour Bob
          └─> Bob devient "Maître Certifié" (X1)
          └─> 30501 supprimé du MULTIPASS de Bob
          └─> Bob apparaît dans "Maîtres Certifiés"
          
  └─> Détecte maîtrise auto-proclamée X1 validée
      └─> Authentifie avec NIP-42 (kind 22242)
      └─> Crée automatiquement PERMIT_MAITRE_NAGEUR_X2
          └─> 2 compétences + 2 signatures requises
          └─> Visible dans /oracle et /wotx2
```

#### Jour 5 : Demande pour X2
```
Carol crée demande 30501 pour X2
  └─> Compétence réclamée: "Sauvetage"
      └─> Apparaît dans "Apprentis Cherchant un Maître"
```

#### Jour 6-7 : Attestations pour X2
```
Bob et Alice attestent Carol (2×30502)
  └─> Carol reçoit 2 attestations
      └─> Compétences transférées: "Natation", "Sauvetage"
      └─> Seuil atteint (2/2)
```

#### Jour 8 : Validation X2
```
ORACLE.refresh.sh s'exécute
  └─> Émet 30503 pour Carol
      └─> Carol devient "Maître Certifié" (X2)
      └─> Authentifie avec NIP-42
      └─> Crée automatiquement PERMIT_MAITRE_NAGEUR_X3
          └─> 3 compétences + 3 signatures requises
```

#### Progression Continue
```
X3 → X4 → X5 → ... → X10 (Expert)
  └─> X11 → X50 (Maître)
      └─> X51 → X100 (Grand Maître)
          └─> X101+ (Maître Absolu)
              └─> Progression illimitée jusqu'à X144 et au-delà
```

### 9.2. Comparaison : Permits Officiels vs WoTx2

| Aspect | Permits Officiels | WoTx2 Auto-Proclamés |
|--------|----------------|---------------------|
| **Création** | Par UPLANETNAME_G1 (admin) | Par utilisateur (auto-proclamé) |
| **ID** | Fixe (ex: PERMIT_ORE_V1) | Dynamique (PERMIT_*_X1) |
| **Progression** | Statique | Automatique illimitée X1→X2→...→X144→... |
| **Compétences** | Définies à la création | Révélées progressivement |
| **Bootstrap** | Requis (N+1 membres) | Non requis (démarre avec 1) |
| **Utilisation** | Permis officiels | Maîtrises libres |
| **Authentification API** | NIP-42 pour création | NIP-42 pour progression automatique |

---

## 10. Troubleshooting

### 10.1. Problèmes Courants

#### L'authentification NIP-42 échoue
**Symptôme** : `ORACLE.refresh.sh` affiche "NIP-42 authentication may have failed"

**Solutions** :
1. Vérifier que `~/.zen/game/uplanet.G1.nostr` existe
2. Vérifier que `nostr_send_note.py` est accessible
3. Vérifier que le relay Nostr est accessible (`ws://127.0.0.1:7777`)
4. Vérifier les logs du relay pour voir si l'événement 22242 est reçu

#### Le niveau suivant n'est pas créé
**Symptôme** : X1 validé mais X2 n'apparaît pas

**Solutions** :
1. Vérifier les logs de `ORACLE.refresh.sh` pour voir les erreurs
2. Vérifier que l'API `/api/permit/define` est accessible
3. Vérifier que l'authentification NIP-42 a réussi
4. Vérifier que le permit ID correspond au pattern `PERMIT_*_X{n}`

#### Les demandes ne disparaissent pas après validation
**Symptôme** : 30501 toujours visible dans "Apprentis Cherchant un Maître" après émission 30503

**Solutions** :
1. Vérifier que le fichier 30501 a été supprimé du répertoire MULTIPASS
2. Recharger la page `/wotx2`
3. Vérifier que le credential 30503 existe bien pour cette demande

#### La publication d'événements 30501/30502 échoue
**Symptôme** : Erreur lors de la publication sur Nostr

**Solutions** :
1. Vérifier que l'extension NOSTR est installée et connectée
2. Vérifier que le relay Nostr est accessible
3. Vérifier que le MULTIPASS a les permissions nécessaires
4. Vérifier les logs du navigateur pour les erreurs JavaScript

### 10.2. Logs et Debugging

#### Logs ORACLE.refresh.sh
```bash
# Exécuter manuellement avec sortie détaillée
./ORACLE.refresh.sh 2>&1 | tee /tmp/oracle_refresh.log
```

#### Vérifier les événements Nostr
```bash
# Vérifier les permits 30500
./nostr_get_events.sh --kind 30500

# Vérifier les demandes 30501
./nostr_get_events.sh --kind 30501

# Vérifier les attestations 30502
./nostr_get_events.sh --kind 30502

# Vérifier les credentials 30503
./nostr_get_events.sh --kind 30503
```

#### Vérifier l'API
```bash
# Vérifier que l'API est accessible
curl -s http://127.0.0.1:54321/api/permit/definitions | jq

# Vérifier les statistiques
curl -s http://127.0.0.1:54321/api/permit/stats | jq
```

---

## 11. Références et Liens

### 11.1. Interfaces Web
- **WoTx2** : `/wotx2` - Interface principale pour les maîtrises auto-proclamées
- **Oracle** : `/oracle` - Vue d'ensemble de tous les permits
- **API Dev** : `/dev` - Documentation interactive de l'API

### 11.2. Scripts
- **ORACLE.refresh.sh** : Maintenance quotidienne automatique avec progression WoTx2
- **oracle_init_permit_definitions.sh** : Gestion interactive des permits officiels
- **nostr_send_note.py** : Publication d'événements Nostr
- **nostr_get_events.sh** : Récupération d'événements Nostr

### 11.3. Fichiers de Configuration
- **Clés NOSTR** : `~/.zen/game/uplanet.G1.nostr` (UPLANETNAME_G1)
- **Statistiques** : `~/.zen/tmp/${IPFSNODEID}/ORACLE/`
- **Templates** : `Astroport.ONE/templates/NOSTR/permit_definitions.json`

### 11.4. Documentation Technique
- **ORACLE_SYSTEM.md** : Documentation complète du système Oracle
- **ORE_SYSTEM.md** : Documentation du système ORE
- **NIP-42** : Authentification Nostr
- **NIP-33** : Parameterized Replaceable Events (pour 30500)
- **W3C Verifiable Credentials** : Standard pour les credentials 30503

---

## 12. FAQ

### Q1 : Puis-je créer plusieurs maîtrises auto-proclamées ?
**R** : Oui, il n'y a aucune limite. Chaque maîtrise démarre à X1 et progresse indépendamment.

### Q2 : Que se passe-t-il si personne n'atteste ma demande ?
**R** : Votre demande reste dans "Apprentis Cherchant un Maître". Après 90 jours, un avertissement est affiché, mais la demande reste active.

### Q3 : Puis-je attester ma propre demande ?
**R** : Non, vous ne pouvez pas vous attester vous-même. Seuls les maîtres certifiés peuvent attester.

### Q4 : Combien de niveaux maximum peut-on atteindre ?
**R** : Aucune limite ! Le système peut progresser jusqu'à X144, X200, X1000... selon les validations.

### Q5 : Les compétences sont-elles obligatoires ?
**R** : Oui, lors de la création d'une demande 30501, vous devez indiquer la compétence que vous souhaitez acquérir.

### Q6 : Comment supprimer une maîtrise auto-proclamée ?
**R** : Seul le créateur peut supprimer un permit (kind 5) si aucun credential 30503 n'a été émis pour ce permit.

### Q7 : L'authentification NIP-42 est-elle obligatoire ?
**R** : Oui, pour créer des permits via l'API, l'authentification NIP-42 est requise. `ORACLE.refresh.sh` gère cela automatiquement pour la progression.

### Q8 : Comment fonctionne la découverte progressive des compétences ?
**R** : Les compétences sont révélées lors des attestations 30502. Chaque maître peut transférer des compétences existantes ou révéler de nouvelles compétences qui enrichissent le système.

---

## 13. Conclusion

Le Système WoTx2 est un système **100% dynamique** qui permet :

- ✅ La création libre de maîtrises auto-proclamées
- ✅ La progression automatique illimitée (X1 → X2 → ... → X144 → ...)
- ✅ La découverte progressive des compétences
- ✅ L'authentification sécurisée via NIP-42
- ✅ La validation décentralisée par les pairs
- ✅ La publication directe sur Nostr par les MULTIPASS

**Le système évolue continuellement et s'adapte aux besoins de la communauté, créant un véritable "cercle vertueux" de l'apprentissage décentralisé.**

---

## 🔗 Liens Utiles

- **Système ORE** : `Astroport.ONE/docs/ORE_SYSTEM.md`
- **Documents Collaboratifs** : `Astroport.ONE/docs/COLLABORATIVE_COMMONS_SYSTEM.md`
- **Système PlantNet** : `Astroport.ONE/docs/PLANTNET_SYSTEM.md`
- **Journaux N²** : `Astroport.ONE/docs/JOURNAUX_N2_NOSTRCARD.md`
- **Économie Ẑen** : `Astroport.ONE/docs/ZEN.ECONOMY.readme.md`

---

**Documentation générée le** : $(date -u +"%Y-%m-%dT%H:%M:%SZ")  
**Version du système** : 1.0 - 100% Dynamique  
**Contact** : support@qo-op.com  
**Documentation complète** : `Astroport.ONE/docs/WOTX2_SYSTEM.md`

