# 🔐 Oracle System - NOSTR Authentication (NIP-42)

## Vue d'ensemble

Le système Oracle d'UPlanet utilise l'authentification NOSTR (NIP-42) pour sécuriser toutes les interactions avec l'API. Chaque utilisateur doit s'authentifier avec sa clé NOSTR privée avant de pouvoir utiliser les endpoints de l'API.

---

## 🔑 Structure des credentials NOSTR

Chaque MULTIPASS est créé par `make_NOSTRCARD.sh` qui génère les credentials et publie le DID.

Les credentials NOSTR de chaque utilisateur sont stockés dans:

```
~/.zen/game/nostr/EMAIL/.secret.nostr
```

**Format du fichier `.secret.nostr`:**
```bash
NSEC=nsec1...; NPUB=npub1...; HEX=<hex_public_key>;
```

---

## 🔄 Flux d'authentification NIP-42

### 1. Envoi d'un événement d'authentification (kind 22242)

Avant chaque utilisation de l'API, l'utilisateur doit envoyer un événement **kind 22242** au relay NOSTR.

**Événement NIP-42:**
```json
{
  "kind": 22242,
  "created_at": <timestamp>,
  "tags": [
    ["relay", "ws://127.0.0.1:7777"],
    ["challenge", "auth-<timestamp>"]
  ],
  "content": "",
  "pubkey": "<USER_HEX_PUBKEY>",
  "sig": "<signature>"
}
```

### 2. Utilisation de `nostr_send_note.py`

Le script `nostr_send_note.py` est utilisé pour envoyer l'événement d'authentification:

```bash
python3 nostr_send_note.py \
    --keyfile ~/.zen/game/nostr/alice@example.com/.secret.nostr \
    --content "" \
    --kind 22242 \
    --tags '[["relay","ws://127.0.0.1:7777"],["challenge","auth-1730000000"]]' \
    --relays ws://127.0.0.1:7777
```

### 3. Validation par l'API

L'API FastAPI (`54321.py`) vérifie:
1. ✅ Que l'événement **22242** a été reçu par le relay
2. ✅ Que la signature est valide
3. ✅ Que l'événement est récent (< 5 minutes)

---

## 📋 Script `oracle.WoT_PERMIT.init.sh` - Authentification

Le script d'initialisation WoT gère automatiquement l'authentification NIP-42 pour tous les membres.

### Fonctions d'authentification

#### `send_nip42_auth(email)`

Envoie un événement NIP-42 pour authentifier un email:

```bash
send_nip42_auth "alice@example.com"
```

**Ce que fait la fonction:**
1. Vérifie l'existence du keyfile: `~/.zen/game/nostr/alice@example.com/.secret.nostr`
2. Crée un événement kind 22242 avec un challenge unique
3. Utilise `nostr_send_note.py` pour signer et envoyer l'événement
4. Attend la confirmation du relay

#### `get_pubkey_from_keyfile(email)`

Extrait la clé publique HEX d'un keyfile:

```bash
pubkey=$(get_pubkey_from_keyfile "alice@example.com")
echo $pubkey  # Output: <64_char_hex_pubkey>
```

#### `authenticate_admin()`

Authentifie le CAPTAIN de la station qui lance le script:

```bash
authenticate_admin
```

**Workflow:**
1. Utilise `$CAPTAINEMAIL` (admin de la station)
2. Vérifie le keyfile du CAPTAIN
3. Envoie un événement NIP-42
4. Attend 2 secondes pour la propagation

---

## 🔄 Flux d'authentification dans le bootstrap WoT

### Étape 1: Authentification de l'admin (CAPTAIN)

```bash
./oracle.WoT_PERMIT.init.sh
# → Utilise: $CAPTAINEMAIL (admin de la station)
# → Envoie NIP-42 pour $CAPTAINEMAIL
# → ✅ CAPTAIN authenticated
```

### Étape 2: Authentification de chaque membre (demande)

Lors de la création des demandes (30501):

```bash
for email in "${members[@]}"; do
    # Authentifie le membre
    send_nip42_auth "$email"
    sleep 1
    
    # Crée la demande via API
    curl -X POST "${ORACLE_API}/request" ...
done
```

**Pour chaque membre:**
1. Envoie NIP-42 (kind 22242)
2. Attend 1 seconde
3. Appelle l'API pour créer la demande (30501)

### Étape 3: Authentification de chaque attesteur (attestation)

Lors de la création des attestations (30502):

```bash
for attester_email in "${members[@]}"; do
    # Authentifie l'attesteur
    send_nip42_auth "$attester_email"
    sleep 1
    
    # Crée les attestations via API
    for applicant_email in "${members[@]}"; do
        curl -X POST "${ORACLE_API}/attest" ...
    done
done
```

**Pour chaque attesteur:**
1. Envoie NIP-42 (kind 22242)
2. Attend 1 seconde
3. Appelle l'API pour créer les attestations (30502)

---

## 📊 Schéma complet avec authentification

```
┌─────────────────────────────────────────────────────────────┐
│  CAPTAIN lance le script (admin de la station)              │
│  ./oracle.WoT_PERMIT.init.sh                                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  ÉTAPE 0: Authentification CAPTAIN                          │
│  - Envoie NIP-42 (kind 22242) pour $CAPTAINEMAIL           │
│  - Attend confirmation                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  ÉTAPE 1: Création des demandes (30501)                     │
│                                                              │
│  Pour chaque membre (Alice, Bob, Carol):                    │
│  1. Envoie NIP-42 pour le membre                            │
│  2. Appelle API /api/permit/request                         │
│  3. → Événement 30501 créé et signé par le membre           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  ÉTAPE 2: Signature croisée (30502)                         │
│                                                              │
│  Pour chaque attesteur (Alice, Bob, Carol):                 │
│  1. Envoie NIP-42 pour l'attesteur                          │
│  2. Pour chaque demande (sauf la sienne):                   │
│     - Appelle API /api/permit/attest                        │
│     - → Événement 30502 créé et signé par l'attesteur       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  ÉTAPE 3: Oracle vérifie les seuils                         │
│  - Toutes les attestations ont été authentifiées            │
│  - Les signatures sont valides                              │
│  - Seuil atteint → Émet 30503                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔒 Sécurité

### Vérifications de l'API

L'API `54321.py` effectue les vérifications suivantes:

1. **Authentification NIP-42:**
   ```python
   async def verify_nostr_auth(npub: Optional[str]) -> bool:
       # Vérifie l'événement kind 22242
       # Vérifie la signature
       # Vérifie la fraîcheur (< 5 minutes)
   ```

2. **Vérification des keyfiles:**
   - Les keyfiles doivent être présents localement
   - Format: `~/.zen/game/nostr/EMAIL/.secret.nostr`
   - Permissions restrictives recommandées: `chmod 600`

3. **Rate limiting:**
   - Limite par IP: 100 requêtes par minute
   - Protège contre les attaques par force brute

### Protection des clés privées

**⚠️ Important:**
- Les clés privées ne sont **jamais** transmises sur le réseau
- Seuls les événements **signés** sont envoyés
- Les keyfiles sont protégés: `chmod 600 ~/.zen/game/nostr/*/.secret.nostr`

---

## 🛠️ Dépannage

### Erreur: "NOSTR keyfile not found"

```bash
[ERROR] NOSTR keyfile not found for: alice@example.com
[ERROR] Path: /home/user/.zen/game/nostr/alice@example.com/.secret.nostr
```

**Solution:** Créer un MULTIPASS pour cet email:
```bash
cd Astroport.ONE/tools
./did_manager_nostr.sh create alice@example.com
```

### Erreur: "Failed to send NIP-42 authentication"

```bash
[ERROR] Failed to send NIP-42 authentication for: alice@example.com
```

**Solutions possibles:**
1. Vérifier que le relay NOSTR est accessible:
   ```bash
   curl -s ws://127.0.0.1:7777
   ```

2. Vérifier que `nostr_send_note.py` fonctionne:
   ```bash
   python3 nostr_send_note.py --help
   ```

3. Vérifier les permissions du keyfile:
   ```bash
   ls -la ~/.zen/game/nostr/alice@example.com/.secret.nostr
   ```

### Erreur: "Cannot access Oracle API"

```bash
[ERROR] Cannot access Oracle API: http://127.0.0.1:54321/api/permit
```

**Solution:** Démarrer l'API UPassport:
```bash
cd UPassport
python3 54321.py
```

---

## 📖 Références

- **NIP-42**: Authentication - https://github.com/nostr-protocol/nips/blob/master/42.md
- **nostr_send_note.py**: Script d'envoi d'événements NOSTR
- **54321.py**: API FastAPI avec vérification NIP-42
- **ORACLE_SYSTEM.md**: Documentation complète du système Oracle

---

## 🎯 Exemple complet

### Initialiser un permis avec authentification

```bash
# Étape 1: Le CAPTAIN de la station lance le script
export CAPTAINEMAIL="captain@station.example.com"

# Étape 2: Lancer le script
cd Astroport.ONE/tools
./oracle.WoT_PERMIT.init.sh

# Output:
# ╔════════════════════════════════════════════════════════════════╗
# ║     UPlanet Oracle - WoT Permit Initialization (Bootstrap)     ║
# ╚════════════════════════════════════════════════════════════════╝
#
# [INFO] Authenticating as CAPTAIN: captain@station.example.com
# [INFO] Sending NIP-42 authentication for: captain@station.example.com
# [SUCCESS] NIP-42 authentication sent for: captain@station.example.com
# [SUCCESS] CAPTAIN authenticated: captain@station.example.com
#
# [INFO] Fetching all permit definitions...
# ╔════════════════════════════════════════════════════════════════╗
# ║      Permits without Web of Trust (No holders yet)            ║
# ╚════════════════════════════════════════════════════════════════╝
#
#  1) PERMIT_ORE_V1           - Permis de Vérificateur ORE (needs 5 initial holders)
#
# Select permit to initialize (number): 1
#
# Enter MULTIPASS email #1: alice@example.com
# ✓ Added: alice@example.com (1/5)
# ...
#
# [INFO] Starting WoT initialization process...
#
# [INFO] Step 1: Creating permit requests (30501)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [INFO] Creating permit request for: alice@example.com
# [INFO] Sending NIP-42 authentication for: alice@example.com
# [SUCCESS] NIP-42 authentication sent for: alice@example.com
# [SUCCESS] Request created: req_abc123
# ...
```

Toutes les authentifications NIP-42 sont gérées automatiquement! ✅

