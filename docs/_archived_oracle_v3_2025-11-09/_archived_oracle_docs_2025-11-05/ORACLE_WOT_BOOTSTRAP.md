# 🌐 Web of Trust (WoT) Initialization for Permits

## Le problème de l'œuf et la poule

Lorsqu'un nouveau type de permis est créé (événement NOSTR kind 30500), il n'existe aucun détenteur initial. Or, pour obtenir un permis, il faut être attesté par des détenteurs existants. **Comment obtenir les premiers détenteurs si personne ne peut attester?**

## La solution: Bootstrap "Block 0" de la WoT

Le script `oracle.WoT_PERMIT.init.sh` résout ce problème en créant le **"Block 0"** d'un nouveau permis à travers un processus de **signature croisée entre les membres initiaux**.

### 📝 Création préalable des MULTIPASS

**Tous les membres doivent avoir un MULTIPASS créé via `make_NOSTRCARD.sh` avant l'initialisation.**

Le script `make_NOSTRCARD.sh`:
- Génère la paire de clés NOSTR (nsec/npub)
- Crée le DID et le publie sur NOSTR (kind 30800 - NIP-101)
- Stocke les credentials dans `~/.zen/game/nostr/EMAIL/.secret.nostr`
- Publie le profil NOSTR avec le DID

### ⚙️ Principe du "Block 0"

Pour un permis nécessitant **N signatures**, il faut **N+1 membres inscrits** sur la station pour initialiser le groupe certificateur.

Chaque membre atteste tous les autres membres (sauf lui-même), ce qui donne **N attestations** par membre.

**Exemples:**
- **PERMIT_ORE_V1** (5 signatures) → minimum **6 MULTIPASS inscrits** (chacun reçoit 5 attestations)
- **PERMIT_DRIVER** (12 signatures) → minimum **13 MULTIPASS inscrits** (chacun reçoit 12 attestations)
- **PERMIT_WOT_DRAGON** (3 signatures) → minimum **4 MULTIPASS inscrits** (chacun reçoit 3 attestations)

Cette exigence garantit que chaque membre initial peut être attesté par suffisamment de pairs dès le démarrage.

---

## 📋 Processus de bootstrap

### Étape 1: Identification des permis non initialisés

Le script identifie tous les permis (kind 30500) qui n'ont **aucun détenteur** (aucun événement kind 30503).

```bash
./oracle.WoT_PERMIT.init.sh
```

**Sortie:**
```
╔════════════════════════════════════════════════════════════════╗
║      Permits without Web of Trust (No holders yet)            ║
╚════════════════════════════════════════════════════════════════╝

 1) PERMIT_ORE_V1           - Permis de Vérificateur ORE (needs 5 initial holders)
 2) PERMIT_DRIVER           - Driver's License WoT Model (needs 12 initial holders)
 3) PERMIT_MEDICAL_FIRST_AID - First Aid Provider (needs 8 initial holders)
```

### Étape 2: Sélection des membres initiaux

Le CAPTAIN de la station sélectionne les **MULTIPASS** (déjà créés via `make_NOSTRCARD.sh`) qui deviendront les premiers détenteurs du permis.

**Critères de sélection:**
- Minimum: `min_attestations + 1` membres (défini dans le 30500)
- Tous doivent avoir un MULTIPASS actif sur la station
- Membres de confiance de la communauté
- Expertise reconnue dans le domaine du permis

**Exemple pour PERMIT_ORE_V1 (5 signatures requises):**
```
Select permit to initialize (number): 1

Enter MULTIPASS email #1: alice@example.com
✓ Added: alice@example.com (1/6)

Enter MULTIPASS email #2: bob@example.com
✓ Added: bob@example.com (2/6)

Enter MULTIPASS email #3: carol@example.com
✓ Added: carol@example.com (3/6)

Enter MULTIPASS email #4: dave@example.com
✓ Added: dave@example.com (4/6)

Enter MULTIPASS email #5: eve@example.com
✓ Added: eve@example.com (5/6)

Enter MULTIPASS email #6: frank@example.com
✓ Added: frank@example.com (6/6)
```

### Étape 3: Création des demandes (kind 30501)

Pour chaque membre sélectionné, le script crée automatiquement un événement **30501** (Permit Request).

```
[INFO] Creating permit requests (30501)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO] Creating permit request for: alice@example.com
[SUCCESS] Request created: req_abc123
[INFO] Creating permit request for: bob@example.com
[SUCCESS] Request created: req_def456
[INFO] Creating permit request for: carol@example.com
[SUCCESS] Request created: req_ghi789
[INFO] Creating permit request for: dave@example.com
[SUCCESS] Request created: req_jkl012
[INFO] Creating permit request for: eve@example.com
[SUCCESS] Request created: req_mno345
[INFO] Creating permit request for: frank@example.com
[SUCCESS] Request created: req_pqr678
...
```

**Événement 30501 créé (exemple pour Alice):**
```json
{
  "kind": 30501,
  "pubkey": "<ALICE_PUBKEY>",
  "tags": [
    ["d", "req_abc123"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["status", "pending"]
  ],
  "content": "{\"statement\": \"Initial WoT member for PERMIT_ORE_V1 - Bootstrap attestation\"}",
  "created_at": <timestamp>,
  "sig": "<signature_par_Alice>"
}
```

### Étape 4: Signature croisée (kind 30502)

Le script crée des attestations **croisées** : chaque membre atteste **tous les autres membres** (sauf lui-même).

Pour 6 membres avec 5 attestations requises:
- Alice atteste → Bob, Carol, Dave, Eve, Frank (5 attestations)
- Bob atteste → Alice, Carol, Dave, Eve, Frank (5 attestations)
- Carol atteste → Alice, Bob, Dave, Eve, Frank (5 attestations)
- Dave atteste → Alice, Bob, Carol, Eve, Frank (5 attestations)
- Eve atteste → Alice, Bob, Carol, Dave, Frank (5 attestations)
- Frank atteste → Alice, Bob, Carol, Dave, Eve (5 attestations)

**Total: 6 × 5 = 30 attestations croisées**

```
[INFO] Creating cross-attestations (30502)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO] Attestations by: alice@example.com
[INFO]   → Attesting request: req_def456 (for bob@example.com)
[SUCCESS]   ✓ Attestation submitted
[INFO]   → Attesting request: req_ghi789 (for carol@example.com)
[SUCCESS]   ✓ Attestation submitted
...
```

**Matrice de signature croisée (exemple avec 6 membres, 5 attestations chacun):**

```
           Alice  Bob  Carol  Dave  Eve  Frank
Alice       -     ✓     ✓      ✓    ✓     ✓
Bob         ✓     -     ✓      ✓    ✓     ✓
Carol       ✓     ✓     -      ✓    ✓     ✓
Dave        ✓     ✓     ✓      -    ✓     ✓
Eve         ✓     ✓     ✓      ✓    -     ✓
Frank       ✓     ✓     ✓      ✓    ✓     -
```

Chaque membre reçoit donc **5 attestations** (tous les autres sauf lui-même).

**Événement 30502 créé (exemple: Bob atteste Alice):**
```json
{
  "kind": 30502,
  "pubkey": "<BOB_PUBKEY>",
  "tags": [
    ["d", "attest_xyz789"],
    ["e", "<REQUEST_EVENT_ID>", "", "root"],
    ["p", "<ALICE_PUBKEY>"],
    ["request_id", "req_abc123"],
    ["permit_id", "PERMIT_ORE_V1"]
  ],
  "content": "{\"statement\": \"Bootstrap WoT attestation - I certify alice@example.com as initial PERMIT_ORE_V1 holder\"}",
  "created_at": <timestamp>,
  "sig": "<signature_par_Bob>"
}
```

### Étape 5: Émission des credentials (kind 30503)

Une fois que chaque membre a reçu suffisamment d'attestations, l'Oracle (automatiquement ou manuellement) émet les **Verifiable Credentials** (kind 30503) signés par `UPLANETNAME.G1`.

```
[INFO] Waiting for credentials to be issued (30503)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Progress: 6/6 credentials issued (attempt 12/30)
[SUCCESS] All credentials have been issued!
```

**Événement 30503 créé (exemple pour Alice):**
```json
{
  "kind": 30503,
  "pubkey": "<UPLANETNAME.G1_PUBKEY>",
  "tags": [
    ["d", "cred_abc123"],
    ["p", "<ALICE_PUBKEY>"],
    ["permit_id", "PERMIT_ORE_V1"],
    ["request_id", "req_abc123"],
    ["issued_at", "2025-10-30T12:00:00Z"],
    ["expires_at", "2028-10-30T12:00:00Z"],
    ["attestation_count", "5"],
    ["attesters", "<BOB_PUBKEY>", "<CAROL_PUBKEY>", "<DAVE_PUBKEY>", "<EVE_PUBKEY>", "<FRANK_PUBKEY>"]
  ],
  "content": "{\"@context\": [...], \"type\": [\"VerifiableCredential\", \"UPlanetLicense\"], ...}",
  "created_at": <timestamp>,
  "sig": "<signature_par_UPLANETNAME.G1>"
}
```

### Étape 6: Web of Trust initialisée ✅

```
╔════════════════════════════════════════════════════════════════╗
║                    Initialization Complete                     ║
╚════════════════════════════════════════════════════════════════╝

[INFO] Permit: PERMIT_ORE_V1
[INFO] Initial WoT members: 6
[SUCCESS] Web of Trust initialized successfully!

Initial holders:
  ✓ alice@example.com
  ✓ bob@example.com
  ✓ carol@example.com
  ✓ dave@example.com
  ✓ eve@example.com
  ✓ frank@example.com

[INFO] These members can now attest new permit requests for PERMIT_ORE_V1
```

---

## 🚀 Utilisation

### Mode interactif (recommandé)

```bash
cd Astroport.ONE/tools
./oracle.WoT_PERMIT.init.sh
```

Le script vous guidera à travers:
1. Sélection du permis à initialiser
2. Saisie des emails des membres initiaux
3. Confirmation et lancement du processus

### Mode direct (avec arguments)

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

## 📊 Schéma du processus de bootstrap

```
┌───────────────────────────────────────────────────────────────┐
│  Permis nouveau (30500) publié par UPLANETNAME.G1             │
│  → Aucun détenteur (aucun 30503)                              │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  1. SÉLECTION DES MEMBRES INITIAUX                            │
│     - Alice, Bob, Carol, Dave, Eve, Frank (6 membres)         │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  2. CRÉATION DES DEMANDES (30501)                             │
│     - Alice publie 30501 (demande)                            │
│     - Bob publie 30501 (demande)                              │
│     - Carol publie 30501 (demande)                            │
│     - Dave publie 30501 (demande)                             │
│     - Eve publie 30501 (demande)                              │
│     - Frank publie 30501 (demande)                            │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  3. SIGNATURE CROISÉE (30502)                                 │
│     Alice atteste → Bob, Carol, Dave, Eve, Frank              │
│     Bob atteste → Alice, Carol, Dave, Eve, Frank              │
│     Carol atteste → Alice, Bob, Dave, Eve, Frank              │
│     Dave atteste → Alice, Bob, Carol, Eve, Frank              │
│     Eve atteste → Alice, Bob, Carol, Dave, Frank              │
│     Frank atteste → Alice, Bob, Carol, Dave, Eve              │
│     Total: 6×5 = 30 attestations                              │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  4. ORACLE VÉRIFIE LES SEUILS                                 │
│     - Chaque demande a 5 attestations                         │
│     - Seuil atteint (min_attestations = 5)                   │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  5. ÉMISSION DES CREDENTIALS (30503)                          │
│     - UPLANETNAME.G1 signe le 30503 pour Alice                │
│     - UPLANETNAME.G1 signe le 30503 pour Bob                  │
│     - UPLANETNAME.G1 signe le 30503 pour Carol                │
│     - UPLANETNAME.G1 signe le 30503 pour Dave                 │
│     - UPLANETNAME.G1 signe le 30503 pour Eve                  │
│     - UPLANETNAME.G1 signe le 30503 pour Frank                │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│  6. WOT INITIALISÉE ✅                                         │
│     - 6 détenteurs initiaux peuvent maintenant attester       │
│     - Nouveaux utilisateurs peuvent demander le permis        │
│     - Le système devient auto-suffisant                       │
└───────────────────────────────────────────────────────────────┘
```

---

## 🔒 Sécurité

### Considérations importantes

1. **Choix des membres initiaux**
   - Sélectionner des membres de confiance absolue
   - Vérifier leur expertise dans le domaine
   - Préférer la diversité géographique et institutionnelle
   - **S'assurer que tous ont un MULTIPASS actif créé via `make_NOSTRCARD.sh`**

2. **Signature par UPLANETNAME.G1**
   - Seule l'autorité UPlanet peut signer les 30503 initiaux
   - Protéger la clé privée `UPLANETNAME.G1` avec soin
   - Utiliser un processus multi-signature pour les décisions critiques

3. **Traçabilité**
   - Tous les événements sont publics sur NOSTR
   - Le processus de bootstrap est transparent
   - Les attestations initiales sont marquées comme "Bootstrap attestation"
   - Le "Block 0" de chaque WoT est tracé et vérifiable

4. **Révocation**
   - Si un membre initial s'avère indigne de confiance
   - Son credential peut être révoqué (si `revocable: true`)
   - La WoT reste viable tant qu'il reste assez de membres

---

## 🔄 Cas d'usage

### Cas 1: Nouveau permis créé

```bash
# 1. Admin publie la définition (30500)
# Via l'interface Oracle ou un script

# 2. Admin initialise la WoT avec N+1 membres pour N signatures
./oracle.WoT_PERMIT.init.sh PERMIT_NEW_TYPE \
    expert1@example.com \
    expert2@example.com \
    expert3@example.com \
    expert4@example.com

# 3. Les 4 experts peuvent maintenant attester de nouvelles demandes
# Chaque expert a reçu 3 attestations (requis pour ce permis)
```

### Cas 2: Permis existant avec WoT trop petite

Si un permis a été initialisé avec trop peu de membres et qu'il faut l'élargir:

```bash
# Re-run avec des membres supplémentaires
./oracle.WoT_PERMIT.init.sh PERMIT_ORE_V1 \
    newexpert1@example.com \
    newexpert2@example.com \
    newexpert3@example.com
```

**Note:** Les nouveaux membres peuvent être attestés par les membres existants via le processus normal.

---

## 📚 Références

- **ORACLE_SYSTEM.md**: Documentation complète du système Oracle
- **ORACLE_NOSTR_FLOW.md**: Flux détaillé des événements NOSTR
- **permit_definitions.json**: Définitions des types de permis

---

## 🎯 Checklist de bootstrap

- [ ] Le permis (30500) est publié par `UPLANETNAME.G1`
- [ ] Aucun détenteur existant (aucun 30503)
- [ ] Au moins `min_attestations` membres sélectionnés
- [ ] Tous les membres ont un MULTIPASS valide
- [ ] L'autorité UPlanet approuve les membres initiaux
- [ ] Le script `oracle.WoT_PERMIT.init.sh` est exécuté
- [ ] Tous les credentials (30503) sont émis et signés
- [ ] Vérification sur `/oracle` que les membres apparaissent comme détenteurs

---

## ⚠️ Prérequis

1. **MULTIPASS créés pour tous les membres**
   - Chaque membre doit avoir un MULTIPASS via `make_NOSTRCARD.sh`
   - Les credentials NOSTR doivent être dans `~/.zen/game/nostr/EMAIL/.secret.nostr`
   - Les DIDs doivent être publiés sur NOSTR (kind 30800 - NIP-101)

2. **Bootstrap manuel requis**
   - Chaque nouveau permis doit être bootstrappé manuellement
   - Nécessite une intervention du CAPTAIN de la station

3. **Nombre minimal de membres**
   - Pour N signatures requises → minimum **N+1 MULTIPASS inscrits**
   - Pour PERMIT_DRIVER (12 sig) → minimum **13 MULTIPASS**
   - Pour PERMIT_ORE_V1 (5 sig) → minimum **6 MULTIPASS**
   - Possibilité d'étendre la WoT progressivement après initialisation

---

---

## 🔄 Système WoT Dynamique Xn (WoTx2)

### Principe des Professions Auto-Proclamées

Le système **WoTx2** permet la création de **professions auto-proclamées** qui évoluent automatiquement de niveau en niveau (X1 → X2 → X3 → X4) selon les validations.

### Workflow de Progression Automatique

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
       ▼
┌─────────────┐
│  Niveau X2  │  Créé automatiquement par ORACLE.refresh.sh
│             │  • ID: PERMIT_PROFESSION_[NOM]_X2
│ 2 signatures│  • 2 compétences + 2 attestations requises
│ 2 compétences│  • Enrichi des compétences révélées en X1
└──────┬──────┘
       │
       │ ✅ 2 attestations (30502) reçues
       │ ✅ ORACLE.refresh.sh émet 30503
       ▼
┌─────────────┐
│  Niveau X3  │  Créé automatiquement par ORACLE.refresh.sh
│             │  • ID: PERMIT_PROFESSION_[NOM]_X3
│ 3 signatures│  • 3 compétences + 3 attestations requises
│ 3 compétences│  • Enrichi des compétences révélées en X2
└──────┬──────┘
       │
       │ ✅ 3 attestations (30502) reçues
       │ ✅ ORACLE.refresh.sh émet 30503
       ▼
┌─────────────┐
│  Niveau X4  │  Créé automatiquement par ORACLE.refresh.sh
│   (Maître)  │  • ID: PERMIT_PROFESSION_[NOM]_X4
│             │  • 4 compétences + 4 attestations requises
│ 4 signatures│  • Progression continue vers X5, X6...
│ 4 compétences│
└──────┬──────┘
       │
       │ ✅ Progression illimitée
       │ ✅ X5, X6, X10, X50, X100, X144...
       ▼
┌─────────────┐
│  Niveau Xn  │  Progression automatique infinie
│             │  • Chaque niveau nécessite N compétences et N signatures
│ N signatures│  • Labels: Expert (X5-X10), Maître (X11-X50), 
│ N compétences│    Grand Maître (X51-X100), Maître Absolu (X101+)
└─────────────┘
```

### Schéma Détaillé du Cycle de Vie

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CYCLE DE VIE D'UNE PROFESSION Xn                  │
└─────────────────────────────────────────────────────────────────────┘

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
   │ • Progression illimitée (X1→X2→...→X144→...) │
   │ • Authentification NIP-42 (kind 22242) avant API │
   │ • Nouveau permit 30500 créé          │
   │ • Visible dans /oracle et /wotx2     │
   │ • Labels: Expert, Maître, Grand Maître, Maître Absolu │
   └─────────────────────────────────────┘
```

### Exemple Concret: "Maître Nageur"

```
Jour 1: Alice crée "Maître Nageur" (X1)
  └─> PERMIT_PROFESSION_MAITRE_NAGEUR_X1 créé
      └─> 1 signature requise

Jour 2: Bob crée demande 30501 pour X1
  └─> Compétence réclamée: "Natation"
      └─> Apparaît dans "Apprentis Cherchant un Maître"

Jour 3: Alice (maître) atteste Bob (30502)
  └─> Bob reçoit 1 attestation
      └─> Seuil atteint (1/1)

Jour 4: ORACLE.refresh.sh s'exécute
  └─> Émet 30503 pour Bob
      └─> Bob devient "Maître Certifié" (X1)
      └─> Crée automatiquement PERMIT_PROFESSION_MAITRE_NAGEUR_X2
          └─> 2 compétences + 2 signatures requises

Jour 5: Carol crée demande 30501 pour X2
  └─> Compétence réclamée: "Sauvetage"
      └─> Apparaît dans "Apprentis Cherchant un Maître"

Jour 6-7: Bob et Alice attestent Carol (2×30502)
  └─> Carol reçoit 2 attestations
      └─> Seuil atteint (2/2)

Jour 8: ORACLE.refresh.sh s'exécute
  └─> Émet 30503 pour Carol
      └─> Carol devient "Maître Certifié" (X2)
      └─> Authentifie avec NIP-42 (kind 22242)
      └─> Crée automatiquement PERMIT_PROFESSION_MAITRE_NAGEUR_X3
          └─> 3 compétences + 3 signatures requises

Jour 9+: Progression continue
  └─> X3 → X4 → X5 → ... → X10 (Expert)
      └─> X11 → X50 (Maître)
          └─> X51 → X100 (Grand Maître)
              └─> X101+ (Maître Absolu)
                  └─> Progression illimitée jusqu'à X144 et au-delà
```

### Interface Utilisateur

**Création de profession auto-proclamée:**
- Interface: `/wotx2` → "Créer une Nouvelle Profession WoTx2"
- Formulaire avec checkbox "Profession Auto-Proclamée"
- ID généré automatiquement: `PERMIT_PROFESSION_[NOM]_X1`

**Visualisation:**
- `/oracle` → Liste tous les permits (X1, X2, X3, X4)
- `/wotx2?permit_id=PERMIT_PROFESSION_XXX_X1` → Détails du permit
- Badges de niveau affichés dans l'UI

**Workflow complet:**
- Voir: `/wotx2` → Section "Workflow de Progression Automatique"

### Différences avec Bootstrap Traditionnel

| Aspect | Bootstrap Traditionnel | WoTx2 Auto-Proclamé |
|--------|----------------------|---------------------|
| **Création** | Par UPLANETNAME_G1 (admin) | Par utilisateur (auto-proclamé) |
| **ID** | Fixe (ex: PERMIT_ORE_V1) | Dynamique (PERMIT_PROFESSION_*_X1) |
| **Progression** | Statique | Automatique illimitée X1→X2→...→X144→... |
| **Compétences** | Définies à la création | Révélées progressivement |
| **Bootstrap** | Requis (N+1 membres) | Non requis (démarre avec 1) |
| **Utilisation** | Permis officiels | Professions libres |

---

## 🌟 Évolution future

### Amélioration 1: Bootstrap semi-automatique

Permettre aux membres existants d'un permis similaire de bootstrap un nouveau permis:

```bash
./oracle.WoT_PERMIT.init.sh PERMIT_NEW_TYPE \
    --from-permit PERMIT_SIMILAR_TYPE \
    --select-top 5
```

### Amélioration 2: Bootstrap par DAO

Utiliser un vote DAO pour sélectionner les membres initiaux:

```bash
./oracle.WoT_PERMIT.init.sh PERMIT_NEW_TYPE \
    --dao-vote \
    --voting-period 7days
```

### Amélioration 3: Validation multi-signature

Exiger plusieurs signatures d'autorité pour le bootstrap:

```bash
./oracle.WoT_PERMIT.init.sh PERMIT_NEW_TYPE \
    --multisig-authority \
    --required-sigs 3/5
```

---

## 🔗 Liens Utiles

- **Interface Oracle**: `/oracle` - Vue d'ensemble de tous les permits
- **Interface WoTx2**: `/wotx2` - Création et gestion des professions auto-proclamées
- **Documentation API**: `/dev` - Documentation complète de l'API

