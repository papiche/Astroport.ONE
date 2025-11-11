# 🔐 UPlanet Oracle System - Documentation Complète

**Version**: 3.0 - Système 100% Dynamique  
**Date**: Décembre 2025  
**Status**: Production - WoTx2 avec Progression Automatique Illimitée  
**License**: AGPL-3.0

> **Système Oracle 100% Dynamique** : Ce document décrit la dernière version du système Oracle qui permet la création et la progression automatique illimitée de professions auto-proclamées (WoTx2).

---

## 📖 Table des Matières

1. [Vue d'Ensemble](#1-vue-densemble)
2. [Architecture Dynamique](#2-architecture-dynamique)
3. [Système WoTx2 - Professions Auto-Proclamées](#3-système-wotx2---professions-auto-proclamées)
4. [Workflow Complet](#4-workflow-complet)
5. [Événements NOSTR](#5-événements-nostr)
6. [Authentification NIP-42](#6-authentification-nip-42)
7. [API Reference](#7-api-reference)
8. [Maintenance Quotidienne](#8-maintenance-quotidienne)
9. [Interfaces Utilisateur](#9-interfaces-utilisateur)
10. [Exemples Concrets](#10-exemples-concrets)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Vue d'Ensemble

### 1.1. Qu'est-ce que le Système Oracle ?

Le **Système Oracle** est un système décentralisé de gestion de permits/licences basé sur le modèle **Web of Trust (WoT)**. Il permet l'émission de **Verifiable Credentials** pour les compétences, licences et autorités dans l'écosystème UPlanet.

### 1.2. Philosophie

Le Système Oracle transforme la certification traditionnelle d'autorités centralisées vers une **certification validée par les pairs** :

- **Demande de Permit** : Un candidat demande publiquement un permit
- **Attestation par les Pairs** : Des experts certifiés attestent la compétence du candidat (validation multi-signature)
- **Émission de Credential** : Une fois suffisamment d'attestations collectées, un Verifiable Credential (VC) est émis
- **Signature d'Autorité** : Le VC final est signé par l'autorité UPlanet (clé UPLANETNAME.G1)

### 1.3. Système 100% Dynamique

Le système Oracle v3.0 est **100% dynamique** :

- ✅ **Création libre** : N'importe qui peut créer une profession auto-proclamée
- ✅ **Progression automatique** : X1 → X2 → X3 → ... → X144 → ... (illimité)
- ✅ **Compétences révélées** : Les compétences sont découvertes progressivement lors des attestations
- ✅ **Aucun bootstrap requis** : Démarre avec 1 signature (vs N+1 pour les permits officiels)
- ✅ **Évolution continue** : Le système crée automatiquement les niveaux suivants

---

## 2. Architecture Dynamique

### 2.1. Deux Types de Permits

#### Permits Officiels (Statiques)
- Créés par `UPLANETNAME_G1` (admin)
- ID fixe (ex: `PERMIT_ORE_V1`, `PERMIT_DRIVER`)
- Bootstrap requis (N+1 membres pour N signatures)
- Compétences définies à la création
- Exemples : Permis de conduire, Vérificateur ORE, etc.

#### Professions Auto-Proclamées (Dynamiques - WoTx2)
- Créés par n'importe quel utilisateur
- ID dynamique : `PERMIT_PROFESSION_[NOM]_X1`
- Aucun bootstrap requis (démarre avec 1 signature)
- Compétences révélées progressivement
- Progression automatique illimitée : X1 → X2 → ... → X144 → ...

### 2.2. Schéma d'Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTÈME ORACLE V3.0                      │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐
│  Permits Officiels   │         │  WoTx2 Auto-Proclamés │
│  (Statiques)         │         │  (Dynamiques)         │
├──────────────────────┤         ├──────────────────────┤
│ • PERMIT_ORE_V1      │         │ • PERMIT_PROFESSION_ │
│ • PERMIT_DRIVER      │         │   MAITRE_NAGEUR_X1    │
│ • PERMIT_MEDICAL...  │         │ • PERMIT_PROFESSION_  │
│                      │         │   CUISINIER_X1        │
│ Bootstrap: N+1       │         │                      │
│ Compétences: Fixes   │         │ Bootstrap: 1          │
│                      │         │ Compétences: Révélées │
│                      │         │ Progression: Auto     │
└──────────────────────┘         └──────────────────────┘
         │                                │
         └────────────┬───────────────────┘
                      │
         ┌────────────▼────────────┐
         │   NOSTR Relay Network   │
         │  (Kind 30500-30503)     │
         └────────────┬────────────┘
                      │
         ┌────────────▼────────────┐
         │   ORACLE.refresh.sh     │
         │  (Maintenance quotidienne)│
         └────────────┬────────────┘
                      │
         ┌────────────▼────────────┐
         │   API /api/permit/*    │
         │   (Authentification NIP-42)│
         └────────────────────────┘
```

---

## 3. Système WoTx2 - Professions Auto-Proclamées

### 3.1. Principe de Progression Automatique

Le système **WoTx2** permet la création de **professions auto-proclamées** qui évoluent automatiquement de niveau en niveau selon les validations.

### 3.2. Workflow de Progression Illimitée

```
┌─────────────────────────────────────────────────────────────────┐
│  PROFESSION AUTO-PROCLAMÉE - PROGRESSION AUTOMATIQUE           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────┐
│  Niveau X1  │  Création initiale par l'utilisateur
│             │  • ID: PERMIT_PROFESSION_[NOM]_X1
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
│           │  • ID: PERMIT_PROFESSION_[NOM]_X2
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

### 3.4. Cycle de Vie Complet

```
1. CRÉATION (Utilisateur via /wotx2)
   ┌─────────────────────────────────────┐
   │ Utilisateur crée profession X1       │
   │ • Nom: "Maître Nageur"               │
   │ • ID auto: PERMIT_PROFESSION_MAITRE_NAGEUR_X1 │
   │ • Événement 30500 signé par UPLANETNAME_G1 │
   └──────────────┬──────────────────────┘
                  │
                  ▼
2. DEMANDE D'APPRENTISSAGE (30501)
   ┌─────────────────────────────────────┐
   │ Apprenti crée demande 30501          │
   │ • Compétence réclamée: "Natation"   │
   │ • Apparaît dans "Apprentis Cherchant un Maître" │
   └──────────────┬──────────────────────┘
                  │
                  ▼
3. ATTESTATION (30502)
   ┌─────────────────────────────────────┐
   │ Maître certifié atteste (30502)     │
   │ • Transfère compétences             │
   │ • Révèle nouvelles compétences      │
   └──────────────┬──────────────────────┘
                  │
                  ▼
4. VALIDATION (ORACLE.refresh.sh)
   ┌─────────────────────────────────────┐
   │ Seuil atteint → Émission 30503      │
   │ • Credential signé par UPLANETNAME_G1 │
   │ • 30501 supprimé (plus apprenti)    │
   │ • Apparaît dans "Maîtres Certifiés" │
   └──────────────┬──────────────────────┘
                  │
                  ▼
5. PROGRESSION AUTOMATIQUE (ORACLE.refresh.sh)
   ┌─────────────────────────────────────┐
   │ Si Xn validé → Création X(n+1)        │
   │ • Authentification NIP-42 (kind 22242) │
   │ • Appel API /api/permit/define       │
   │ • Nouveau permit 30500 créé          │
   │ • Visible dans /oracle et /wotx2     │
   └─────────────────────────────────────┘
```

---

## 4. Workflow Complet

### 4.1. Création d'une Profession Auto-Proclamée

**Interface**: `/wotx2` → "Créer une Nouvelle Profession WoTx2"

1. **Formulaire** :
   - ✅ Cocher "Profession Auto-Proclamée"
   - Saisir le nom de la profession (ex: "Maître Nageur")
   - L'ID est généré automatiquement : `PERMIT_PROFESSION_MAITRE_NAGEUR_X1`
   - Ajouter une description

2. **Publication** :
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
   - Voir le niveau si c'est une profession Xn

2. **Formulaire** :
   - Déclaration d'apprentissage (minimum 20 caractères)
   - **Compétence réclamée** (obligatoire) : ex: "Natation", "Sauvetage"
   - Preuves de motivation (liens IPFS, optionnel)
   - Géolocalisation (automatique si autorisée)

3. **Publication** :
   - Événement kind 30501 publié sur Nostr
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
   - Événement kind 30502 publié sur Nostr
   - Signé par le MULTIPASS de l'attesteur
   - Référence la demande 30501 (tag `e`)

### 4.4. Validation et Émission de Credential (30503)

**Processus automatique** : `ORACLE.refresh.sh` (exécuté quotidiennement)

1. **Vérification** :
   - Récupère toutes les demandes 30501 depuis Nostr
   - Compte les attestations 30502 pour chaque demande
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
   - Détecte si le permit est auto-proclamé : `PERMIT_PROFESSION_*_X{n}`
   - Extrait le niveau actuel (X1, X2, X3, ...)

2. **Calcul du niveau suivant** :
   - `next_level = current_level + 1`
   - `next_permit_id = PERMIT_PROFESSION_[NOM]_X{next_level}`
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

### 5.1. Kind 30500 - Permit Definition

**Publié par** : `UPLANETNAME_G1` (permits officiels) ou utilisateur (auto-proclamés)

```json
{
  "kind": 30500,
  "pubkey": "<UPLANETNAME_G1_hex>",
  "tags": [
    ["d", "PERMIT_PROFESSION_MAITRE_NAGEUR_X1"],
    ["t", "permit"],
    ["t", "definition"],
    ["t", "auto_proclaimed"]
  ],
  "content": "{
    \"id\": \"PERMIT_PROFESSION_MAITRE_NAGEUR_X1\",
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

**Publié par** : Candidat (MULTIPASS)

```json
{
  "kind": 30501,
  "pubkey": "<applicant_hex>",
  "tags": [
    ["d", "req_abc123"],
    ["l", "PERMIT_PROFESSION_MAITRE_NAGEUR_X1", "permit_type"],
    ["p", "<applicant_npub>"],
    ["t", "permit"],
    ["t", "request"]
  ],
  "content": "{
    \"request_id\": \"req_abc123\",
    \"permit_definition_id\": \"PERMIT_PROFESSION_MAITRE_NAGEUR_X1\",
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

**Publié par** : Attesteur (MULTIPASS certifié)

```json
{
  "kind": 30502,
  "pubkey": "<attester_hex>",
  "tags": [
    ["d", "attest_xyz789"],
    ["e", "<request_event_id>"],
    ["p", "<applicant_npub>"],
    ["t", "permit"],
    ["t", "attestation"]
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
    ["permit_id", "PERMIT_PROFESSION_MAITRE_NAGEUR_X1"],
    ["request_id", "req_abc123"],
    ["issued_at", "2025-12-01T12:00:00Z"],
    ["attestation_count", "1"]
  ],
  "content": "{
    \"@context\": [
      \"https://www.w3.org/2018/credentials/v1\",
      \"https://uplanet.org/credentials/v1\"
    ],
    \"type\": [\"VerifiableCredential\", \"UPlanetLicense\"],
    \"id\": \"urn:uuid:...\",
    \"issuer\": \"did:nostr:<UPLANETNAME_G1_hex>\",
    \"issuanceDate\": \"2025-12-01T12:00:00Z\",
    \"credentialSubject\": {
      \"id\": \"did:nostr:<holder_npub>\",
      \"license\": \"PERMIT_PROFESSION_MAITRE_NAGEUR_X1\",
      \"attestations\": 1,
      \"level\": \"X1\"
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

**Publié par** : `UPLANETNAME_G1` (avant chaque appel API)

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

## 6. Authentification NIP-42

### 6.1. Pourquoi NIP-42 ?

L'API `/api/permit/define` nécessite une authentification NIP-42 pour :
- ✅ Vérifier que l'appelant est autorisé (UPLANETNAME_G1)
- ✅ Prévenir les abus et les créations non autorisées
- ✅ Assurer la traçabilité des opérations

### 6.2. Processus d'Authentification

1. **Génération de la clé** :
   - Si `~/.zen/game/uplanet.G1.nostr` n'existe pas, il est généré automatiquement
   - Utilise `keygen -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1"`

2. **Envoi de l'événement NIP-42** :
   ```bash
   nostr_send_note.py \
     --keyfile ~/.zen/game/uplanet.G1.nostr \
     --content "oracle_refresh_$(date +%s)_${permit_id}" \
     --kind 22242 \
     --relays ws://127.0.0.1:7777
   ```

3. **Attente** :
   - Le script attend 1 seconde pour que le relay traite l'événement

4. **Appel API avec header** :
   ```bash
   curl -X POST "${ORACLE_BASE}/api/permit/define" \
     -H "Content-Type: application/json" \
     -H "X-Nostr-Auth: ${UPLANETNAME_G1_NPUB}" \
     -d '{...}'
   ```

5. **Vérification côté API** :
   - L'API vérifie qu'un événement kind 22242 récent existe pour cette npub
   - Si valide → Traite la requête
   - Si invalide → Retourne 401 Unauthorized

---

## 7. API Reference

### 7.1. Endpoints Principaux

#### GET `/api/permit/definitions`
Récupère toutes les définitions de permits (30500)

**Réponse** :
```json
{
  "success": true,
  "permits": [
    {
      "id": "PERMIT_PROFESSION_MAITRE_NAGEUR_X1",
      "name": "Maître Nageur",
      "description": "...",
      "min_attestations": 1,
      "holders_count": 5,
      "pending_requests_count": 2
    }
  ]
}
```

#### POST `/api/permit/define`
Crée une nouvelle définition de permit (30500)

**Authentification** : NIP-42 requise

**Body** :
```json
{
  "permit": {
    "id": "PERMIT_PROFESSION_MAITRE_NAGEUR_X1",
    "name": "Maître Nageur",
    "description": "...",
    "min_attestations": 1,
    "metadata": {...}
  },
  "npub": "npub1..."
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

#### GET `/api/permit/list`
Liste les demandes, credentials, ou attestations

**Query params** :
- `type=requests|credentials|attestations`
- `permit_id=PERMIT_XXX` (optionnel)

---

## 8. Maintenance Quotidienne

### 8.1. ORACLE.refresh.sh

**Exécution** : Quotidienne (via cron)

**Fonctions** :

1. **Vérification des demandes 30501** :
   - Récupère toutes les demandes depuis Nostr
   - Compte les attestations 30502 pour chaque demande
   - Émet 30503 si seuil atteint

2. **Progression automatique WoTx2** :
   - Détecte les professions auto-proclamées validées
   - Authentifie avec NIP-42
   - Crée automatiquement le niveau suivant (X(n+1))

3. **Vérification des credentials expirés** :
   - Liste tous les credentials
   - Signale ceux qui ont expiré

4. **Génération de statistiques** :
   - Compte demandes et credentials par permit
   - Sauvegarde dans `~/.zen/tmp/${IPFSNODEID}/ORACLE/`

5. **Publication sur Nostr** :
   - Publie un rapport quotidien (kind 1)
   - Signé par UPLANETNAME_G1

6. **Nettoyage** :
   - Supprime fichiers temporaires > 7 jours

### 8.2. Configuration Cron

```bash
# Exécution quotidienne à 2h du matin
0 2 * * * /path/to/ORACLE.refresh.sh >> /var/log/oracle_refresh.log 2>&1
```

---

## 9. Interfaces Utilisateur

### 9.1. `/oracle` - Vue d'Ensemble

**URL** : `http://127.0.0.1:54321/oracle` ou `https://u.copylaradio.com/oracle`

**Fonctionnalités** :
- ✅ Liste tous les permits (officiels et auto-proclamés)
- ✅ Statistiques globales
- ✅ Graphiques de répartition
- ✅ Distinction visuelle entre permits officiels et WoTx2
- ✅ Workflow de progression visible
- ✅ Liens vers `/wotx2` pour créer des professions

### 9.2. `/wotx2` - Interface WoTx2

**URL** : `http://127.0.0.1:54321/wotx2` ou `https://u.copylaradio.com/wotx2`

**Fonctionnalités** :
- ✅ Création de professions auto-proclamées
- ✅ Sélection de permit pour créer une demande
- ✅ Formulaire de demande avec compétence réclamée
- ✅ Liste "Maîtres Certifiés" (30503)
- ✅ Liste "Apprentis Cherchant un Maître" (30501 sans 30503)
- ✅ Modal d'attestation
- ✅ Affichage des niveaux (X1, X2, X3, ...)
- ✅ Workflow de progression visible

**Paramètres URL** :
- `?permit_id=PERMIT_XXX` : Affiche les détails d'un permit spécifique

---

## 10. Exemples Concrets

### 10.1. Exemple Complet : "Maître Nageur"

#### Jour 1 : Création de la Profession
```
Alice crée "Maître Nageur" via /wotx2
  └─> PERMIT_PROFESSION_MAITRE_NAGEUR_X1 créé
      └─> 1 signature requise
      └─> Événement 30500 publié sur Nostr
```

#### Jour 2 : Première Demande
```
Bob crée demande 30501 pour X1
  └─> Compétence réclamée: "Natation"
      └─> Apparaît dans "Apprentis Cherchant un Maître"
      └─> Événement 30501 publié
```

#### Jour 3 : Attestation
```
Alice (créatrice) atteste Bob (30502)
  └─> Bob reçoit 1 attestation
      └─> Seuil atteint (1/1)
      └─> Événement 30502 publié
```

#### Jour 4 : Validation Automatique
```
ORACLE.refresh.sh s'exécute
  └─> Détecte que Bob a 1 attestation (seuil atteint)
      └─> Émet 30503 pour Bob
          └─> Bob devient "Maître Certifié" (X1)
          └─> 30501 supprimé du MULTIPASS de Bob
          └─> Bob apparaît dans "Maîtres Certifiés"
          
  └─> Détecte profession auto-proclamée X1 validée
      └─> Authentifie avec NIP-42 (kind 22242)
      └─> Crée automatiquement PERMIT_PROFESSION_MAITRE_NAGEUR_X2
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
      └─> Seuil atteint (2/2)
```

#### Jour 8 : Validation X2
```
ORACLE.refresh.sh s'exécute
  └─> Émet 30503 pour Carol
      └─> Carol devient "Maître Certifié" (X2)
      └─> Authentifie avec NIP-42
      └─> Crée automatiquement PERMIT_PROFESSION_MAITRE_NAGEUR_X3
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

### 10.2. Comparaison : Permits Officiels vs WoTx2

| Aspect | Permits Officiels | WoTx2 Auto-Proclamés |
|--------|----------------|---------------------|
| **Création** | Par UPLANETNAME_G1 (admin) | Par utilisateur (auto-proclamé) |
| **ID** | Fixe (ex: PERMIT_ORE_V1) | Dynamique (PERMIT_PROFESSION_*_X1) |
| **Progression** | Statique | Automatique illimitée X1→X2→...→X144→... |
| **Compétences** | Définies à la création | Révélées progressivement |
| **Bootstrap** | Requis (N+1 membres) | Non requis (démarre avec 1) |
| **Utilisation** | Permis officiels | Professions libres |
| **Authentification API** | NIP-42 pour création | NIP-42 pour progression automatique |

---

## 11. Troubleshooting

### 11.1. Problèmes Courants

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
4. Vérifier que le permit ID correspond au pattern `PERMIT_PROFESSION_*_X{n}`

#### Les demandes ne disparaissent pas après validation
**Symptôme** : 30501 toujours visible dans "Apprentis Cherchant un Maître" après émission 30503

**Solutions** :
1. Vérifier que le fichier 30501 a été supprimé du répertoire MULTIPASS
2. Recharger la page `/wotx2`
3. Vérifier que le credential 30503 existe bien pour cette demande

### 11.2. Logs et Debugging

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

## 12. Références et Liens

### 12.1. Interfaces Web
- **Oracle** : `/oracle` - Vue d'ensemble de tous les permits
- **WoTx2** : `/wotx2` - Création et gestion des professions auto-proclamées
- **API Dev** : `/dev` - Documentation interactive de l'API

### 12.2. Scripts
- **ORACLE.refresh.sh** : Maintenance quotidienne automatique
- **oracle_init_permit_definitions.sh** : Gestion interactive des permits officiels
- **nostr_send_note.py** : Publication d'événements Nostr
- **nostr_get_events.sh** : Récupération d'événements Nostr

### 12.3. Fichiers de Configuration
- **Clés NOSTR** : `~/.zen/game/uplanet.G1.nostr` (UPLANETNAME_G1)
- **Statistiques** : `~/.zen/tmp/${IPFSNODEID}/ORACLE/`
- **Templates** : `Astroport.ONE/templates/NOSTR/permit_definitions.json`

### 12.4. Documentation Technique
- **NIP-42** : Authentification Nostr
- **NIP-33** : Parameterized Replaceable Events (pour 30500)
- **W3C Verifiable Credentials** : Standard pour les credentials 30503

---

## 13. FAQ

### Q1 : Puis-je créer plusieurs professions auto-proclamées ?
**R** : Oui, il n'y a aucune limite. Chaque profession démarre à X1 et progresse indépendamment.

### Q2 : Que se passe-t-il si personne n'atteste ma demande ?
**R** : Votre demande reste dans "Apprentis Cherchant un Maître". Après 90 jours, un avertissement est affiché, mais la demande reste active.

### Q3 : Puis-je attester ma propre demande ?
**R** : Non, vous ne pouvez pas vous attester vous-même. Seuls les maîtres certifiés peuvent attester.

### Q4 : Combien de niveaux maximum peut-on atteindre ?
**R** : Aucune limite ! Le système peut progresser jusqu'à X144, X200, X1000... selon les validations.

### Q5 : Les compétences sont-elles obligatoires ?
**R** : Oui, lors de la création d'une demande 30501, vous devez indiquer la compétence que vous souhaitez acquérir.

### Q6 : Comment supprimer une profession auto-proclamée ?
**R** : Seul le créateur peut supprimer un permit (kind 5) si aucun credential 30503 n'a été émis pour ce permit.

### Q7 : L'authentification NIP-42 est-elle obligatoire ?
**R** : Oui, pour créer des permits via l'API, l'authentification NIP-42 est requise. `ORACLE.refresh.sh` gère cela automatiquement.

---

## 14. Conclusion

Le Système Oracle v3.0 est un système **100% dynamique** qui permet :

- ✅ La création libre de professions auto-proclamées
- ✅ La progression automatique illimitée (X1 → X2 → ... → X144 → ...)
- ✅ La découverte progressive des compétences
- ✅ L'authentification sécurisée via NIP-42
- ✅ La validation décentralisée par les pairs

**Le système évolue continuellement et s'adapte aux besoins de la communauté.**

---

---

## 15. Scripts et Outils

### 15.1. ORACLE.refresh.sh

**Localisation** : `Astroport.ONE/RUNTIME/ORACLE.refresh.sh`

**Description** : Script de maintenance quotidienne qui :
- Vérifie les demandes 30501 et émet les credentials 30503
- Gère la progression automatique WoTx2 (X1 → X2 → ... → X144 → ...)
- Authentifie avec NIP-42 avant chaque création de permit
- Génère des statistiques
- Publie un rapport quotidien sur Nostr

**Exécution** : Quotidienne via cron (recommandé : 2h du matin)

**Voir** : Description complète dans la section [8. Maintenance Quotidienne](#8-maintenance-quotidienne)

### 15.2. oracle_init_permit_definitions.sh

**Localisation** : `Astroport.ONE/tools/oracle_init_permit_definitions.sh`

**Description** : Script interactif pour gérer les **permits officiels uniquement**

**⚠️ Important** : Ce script est pour les permits officiels (PERMIT_ORE_V1, PERMIT_DRIVER, etc.)
- Pour les professions auto-proclamées (WoTx2), utilisez `/wotx2` via le navigateur

**Fonctionnalités** :
- Ajouter des permits officiels depuis le template JSON
- Éditer des permits existants
- Supprimer des permits (avec vérification d'utilisation)
- Lister tous les permits (officiels et WoTx2)

**Usage** :
```bash
cd Astroport.ONE/tools
./oracle_init_permit_definitions.sh
```

---

## 16. Migration depuis l'Ancien Système

### 16.1. Changements Majeurs v3.0

| Aspect | Ancien Système | Nouveau Système (v3.0) |
|--------|---------------|------------------------|
| **Création permits** | Script uniquement | Interface web `/wotx2` + Script |
| **Progression** | Statique | Automatique illimitée |
| **Limite niveaux** | X4 maximum | Illimité (X144+) |
| **Authentification API** | Optionnelle | NIP-42 requise |
| **Compétences** | Définies à la création | Révélées progressivement |
| **Bootstrap** | Toujours requis | Non requis pour WoTx2 |

### 16.2. Compatibilité

- ✅ Les permits officiels existants continuent de fonctionner
- ✅ Les credentials 30503 existants restent valides
- ✅ Les demandes 30501 en cours sont traitées normalement
- ✅ Aucune migration de données requise

---

**Documentation générée le** : $(date -u +"%Y-%m-%dT%H:%M:%SZ")  
**Version du système** : 3.0 - 100% Dynamique  
**Contact** : support@qo-op.com  
**Documentation complète** : `Astroport.ONE/docs/ORACLE_SYSTEM.md`





