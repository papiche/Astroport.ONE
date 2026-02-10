# UPLANET.INIT.SH - Initialisation Infrastructure UPlanet ẐEN

## 📋 Description

`UPLANET.init.sh` est le script **FONDAMENTAL** d'initialisation de l'infrastructure complète UPlanet ẐEN. Il crée et initialise tous les portefeuilles coopératifs, opérationnels et de gouvernance nécessaires au fonctionnement de l'écosystème, en respectant la source primale unique `UPLANETNAME_G1`.

## 🎯 Objectifs

1. **Initialisation complète** : Créer tous les portefeuilles depuis la source primale unique
2. **Sécurité primale** : Garantir la traçabilité et l'anti-intrusion
3. **Infrastructure opérationnelle** : NODE (Armateur) et CAPTAIN (MULTIPASS/ZEN Card)
4. **Gouvernance coopérative** : Portefeuilles de répartition 3x1/3 et fiscalité
5. **Compatibilité modes** : Fonctionnement ORIGIN (niveau X) et ẐEN (niveau Y)

## 🏛️ Infrastructure Complète Initialisée

Le script crée et initialise l'infrastructure complète UPlanet ẐEN :

### **🏦 Portefeuilles Coopératifs de Base**

| Portefeuille | Fichier Dunikey | Rôle dans l'Écosystème |
|---------------|------------------|------------------------|
| **`UPLANETNAME_G1`** | `uplanet.G1.dunikey` | **Source primale principale** - Réserve Ğ1 de l'écosystème |
| **`UPLANETNAME`** | `uplanet.dunikey` | **Services locaux** - Gestion revenus MULTIPASS |
| **`UPLANETNAME_SOCIETY`** | `uplanet.SOCIETY.dunikey` | **Capital social** - Émission parts sociales ZEN Cards |

### **🏛️ Portefeuilles de Gouvernance Coopérative (3x1/3)**

| Portefeuille | Fichier Dunikey | Allocation Coopérative |
|---------------|------------------|------------------------|
| **`UPLANETNAME_CASH`** | `uplanet.CASH.dunikey` | **Trésorerie** (33.33% du surplus) |
| **`UPLANETNAME_RND`** | `uplanet.RnD.dunikey` | **R&D** (33.33% du surplus) |
| **`UPLANETNAME_ASSETS`** | `uplanet.ASSETS.dunikey` | **Actifs** (33.34% du surplus) |
| **`UPLANETNAME_IMPOT`** | `uplanet.IMPOT.dunikey` | **Fiscalité** (TVA + IS) |

### **⚙️ Infrastructure Opérationnelle**

| Portefeuille | Fichier Dunikey | Fonction Opérationnelle |
|---------------|------------------|-------------------------|
| **`NODE`** | `secret.NODE.dunikey` | **Armateur** - Reçoit PAF et apport capital machine |
| **`CAPTAIN.MULTIPASS`** | `~/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey` | **MULTIPASS Captain** - Services NOSTR (1Ẑ/semaine) |
| **`CAPTAIN.ZENCARD`** | `~/.zen/game/players/$CAPTAINEMAIL/secret.dunikey` | **ZEN Card Captain** - Parts sociales (valorisation machine) |

## 🔧 Fonctionnement

### 1. Vérification des Prérequis
- Outils requis : `silkaj`, `jq`, `bc`, `G1check.sh`
- Portefeuille source disponible avec solde suffisant

### 2. Source Primale Unique : UPLANETNAME_G1

Le script utilise **exclusivement** `UPLANETNAME_G1` comme source primale pour garantir :

#### **🔐 Sécurité et Traçabilité**
- **Source unique** : Tous les portefeuilles proviennent de `UPLANETNAME_G1`
- **Chaîne primale** : Traçabilité complète des fonds
- **Anti-intrusion** : Protection contre les fonds non autorisés
- **Cohérence économique** : Respect de la Constitution ẐEN

#### **🎯 Modes UPlanet Supportés**

**🌍 Mode ORIGIN (Niveau X) :**
- `UPLANETNAME = "EnfinLibre"` (fixe)
- Source primale : `EnfinLibre.G1`
- Réseau IPFS public

**🏴‍☠️ Mode ẐEN (Niveau Y) :**
- `UPLANETNAME = $(cat ~/.ipfs/swarm.key)` (dynamique)
- Source primale : `$(cat ~/.ipfs/swarm.key).G1`
- Réseau IPFS privé avec swarm.key

#### **📍 Détection Automatique du Mode**
```bash
# Le script détecte automatiquement le mode :
if [[ -f ~/.ipfs/swarm.key ]]; then
    UPLANETNAME=$(cat ~/.ipfs/swarm.key)  # Mode ẐEN
else
    UPLANETNAME="EnfinLibre"              # Mode ORIGIN
fi
```

### 3. Calcul de la Capacité d'Initialisation
- **Solde minimum** : 1 Ğ1 requis pour commencer
- **Limite maximale** : 5 portefeuilles (1 Ğ1 chacun)
- **Initialisation partielle** : Si le solde est insuffisant, le script initialise le maximum possible

### 4. Vérification des Portefeuilles
- Utilise `G1check.sh` pour vérifier les soldes
- Identifie les portefeuilles vides (< 0.01 Ğ1)
- Calcule le montant total requis

### 5. Initialisation
- Transfère 1 Ğ1 vers chaque portefeuille vide
- Attend la confirmation blockchain entre chaque transaction
- Limite le nombre de portefeuilles initialisés selon le solde disponible

## 📖 Utilisation

### Options Disponibles

```bash
./UPLANET.init.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--dry-run` | Mode simulation (aucune transaction) |
| `--force` | Initialisation sans confirmation |
| `--help` | Affiche l'aide |

### Exemples d'Utilisation

#### Mode Simulation (Recommandé)
```bash
./UPLANET.init.sh --dry-run
```
Affiche ce qui serait fait sans effectuer de transactions.

#### Initialisation Complète
```bash
./UPLANET.init.sh
```
Lance l'initialisation avec confirmation interactive.

#### Initialisation Forcée
```bash
./UPLANET.init.sh --force
```
Lance l'initialisation sans demander de confirmation.

## 🔍 Mode Simulation

Le mode `--dry-run` permet de :
- Vérifier l'état actuel des portefeuilles
- Identifier les portefeuilles nécessitant une initialisation
- Calculer le montant total requis
- Simuler le processus sans risque

## ⚠️ Limitations et Contraintes

### Solde Minimum
- **Requis** : 1 Ğ1 minimum pour commencer
- **Recommandé** : 5 Ğ1 pour initialiser tous les portefeuilles

### Initialisation Partielle
Si le solde est insuffisant :
- Le script initialise le maximum possible
- Affiche un avertissement d'initialisation partielle
- Permet de compléter l'initialisation ultérieurement

### Sécurité
- Vérification de l'existence des fichiers dunikey
- Validation des clés publiques
- Confirmation interactive (sauf avec `--force`)

## 📊 Sortie et Rapports

### Informations Affichées
- **État des prérequis** : Outils disponibles
- **Portefeuille source** : Fichier et solde
- **Portefeuilles coopératifs** : Statut et soldes
- **Plan d'initialisation** : Nombre et montants
- **Résumé final** : Succès et échecs

### Codes de Sortie
- **0** : Succès
- **1** : Erreur (prérequis, solde insuffisant, etc.)

## 🚀 Cas d'Usage Typiques

### 1. Première Installation
```bash
# Vérifier l'état initial
./UPLANET.init.sh --dry-run

# Initialiser si nécessaire
./UPLANET.init.sh
```

### 2. Maintenance Régulière
```bash
# Vérifier périodiquement
./UPLANET.init.sh --dry-run

# Réinitialiser si des portefeuilles sont vides
./UPLANET.init.sh
```

### 3. Récupération Post-Erreur
```bash
# Identifier les problèmes
./UPLANET.init.sh --dry-run

# Forcer la réinitialisation
./UPLANET.init.sh --force
```

---

## 🔗 **INTÉGRATION AVEC L'ÉCOSYSTÈME UPLANET ẐEN**

### **🚀 Flux d'Embarquement**
```
install.sh → uplanet_onboarding.sh → UPLANET.init.sh → captain.sh
     ↓              ↓                      ↓              ↓
Installation → Configuration → Initialisation → Identité Capitaine
```

### **🏛️ Scripts Économiques Associés**

| Script | Rôle | Relation avec UPLANET.init.sh |
|--------|------|-------------------------------|
| **`UPLANET.official.sh`** | Virements officiels | Utilise les portefeuilles initialisés |
| **`ZEN.ECONOMY.sh`** | Paiement PAF + Burn | Utilise NODE et portefeuilles coopératifs |
| **`ZEN.COOPERATIVE.3x1-3.sh`** | Allocation 3x1/3 | Utilise CASH, RND, ASSETS |
| **`NOSTRCARD.refresh.sh`** | Collecte MULTIPASS | Utilise UPLANETNAME et IMPOT |
| **`PLAYER.refresh.sh`** | Collecte ZEN Cards | Utilise UPLANETNAME_SOCIETY et IMPOT |

### **🔧 Scripts de Configuration**

| Script | Rôle | Intégration |
|--------|------|-------------|
| **`uplanet_onboarding.sh`** | Embarquement complet | Lance UPLANET.init.sh automatiquement, option `q` pour config rapide |
| **`captain.sh`** | Dashboard Capitaine | Gestion config coopérative, embarquement, monitoring |
| **`cooperative_config.sh`** | Configuration DID NOSTR | Paramètres partagés essaim (kind 30800, chiffrés) |
| **`update_config.sh`** | Migration et mise à jour | Peut relancer UPLANET.init.sh si nécessaire |
| **`heartbox_analysis.sh`** | Analyse système | Fournit les capacités pour la valorisation |

### **📋 Configuration Coopérative DID (Nouveauté)**

UPLANET.init.sh initialise également la **configuration coopérative DID** dans NOSTR (kind 30800) :

| Paramètre | Description | Chiffré |
|-----------|-------------|---------|
| `NCARD`, `ZCARD` | Tarifs MULTIPASS/ZEN Card | Non |
| `TVA_RATE`, `IS_RATE_*` | Taux fiscaux | Non |
| `ZENCARD_SATELLITE`, `ZENCARD_CONSTELLATION` | Prix parts sociales | Non |
| `TREASURY_PERCENT`, `RND_PERCENT`, `ASSETS_PERCENT` | Règle 3x1/3 | Non |
| `OPENCOLLECTIVE_*` | Tokens API OpenCollective | **Oui** (AES-256-CBC) |
| `PLANTNET_API_KEY` | Clé API PlantNet | **Oui** (AES-256-CBC) |

**Fonctionnement :**
```bash
# Configuration automatique lors de UPLANET.init.sh
check_and_init_cooperative_config()

# Utilisation dans les scripts
source ~/.zen/Astroport.ONE/tools/cooperative_config.sh
TVA=$(coop_config_get "TVA_RATE")
coop_config_set "OPENCOLLECTIVE_PERSONAL_TOKEN" "mon_token"
```

### **🛡️ Sécurité et Contrôle**

| Script | Rôle | Protection Assurée |
|--------|------|-------------------|
| **`primal_wallet_control.sh`** | Anti-intrusion | Protège tous les portefeuilles initialisés |
| **`nostr_DESTROY_TW.sh`** | Désinscription MULTIPASS | Utilisé lors des migrations ORIGIN → ẐEN |
| **`PLAYER.unplug.sh`** | Désinscription ZEN Card | Utilisé lors des migrations ORIGIN → ẐEN |

---

## 🎯 **WORKFLOW COMPLET D'INITIALISATION**

### **🆕 Nouveau Capitaine (Installation Fraîche)**
1. **`install.sh`** : Installation Astroport.ONE
2. **`uplanet_onboarding.sh`** : Configuration et choix du mode
3. **`UPLANET.init.sh`** : **Initialisation automatique** de l'infrastructure
4. **`captain.sh`** : Création identité capitaine

### **🔄 Migration ORIGIN → ẐEN**
1. **`update_config.sh`** : Détection mode et migration
2. **Désinscription automatique** : `nostr_DESTROY_TW.sh` + `PLAYER.unplug.sh`
3. **`UPLANET.init.sh`** : **Réinitialisation** avec nouvelle source primale ẐEN
4. **`uplanet_onboarding.sh`** : Configuration ẐEN complète

### **🔍 Maintenance et Vérification**
1. **`UPLANET.init.sh --dry-run`** : Vérification état des portefeuilles
2. **`heartbox_analysis.sh`** : Analyse capacités système
3. **`zen.sh`** : Diagnostic économique complet
4. **`dashboard.sh`** : Monitoring quotidien

---

## 📚 **DOCUMENTATION CONNEXE**

### **📖 Guides Principaux**
- **[EMBARQUEMENT.md](EMBARQUEMENT.md)** : Guide complet d'embarquement UPlanet ẐEN
- **[SCRIPTS.ROLES.md](SCRIPTS.ROLES.md)** : Rôles de tous les scripts de l'écosystème

### **🏛️ Constitution Économique**
- **[RUNTIME/ZEN.ECONOMY.readme.md](RUNTIME/ZEN.ECONOMY.readme.md)** : Constitution économique complète
- **[RUNTIME/ZEN.INTRUSION.POLICY.md](RUNTIME/ZEN.INTRUSION.POLICY.md)** : Politique anti-intrusion

### **🔧 Configuration**
- **[.env.template](.env.template)** : Template de configuration locale avec toutes les variables
- **Configuration dynamique** via `heartbox_analysis.sh`
- **Configuration coopérative DID** via `cooperative_config.sh` (paramètres partagés essaim)
- **Dashboard Capitaine** via `captain.sh` (gestion centralisée configuration)

**Note de cohérence** : Les noms des fichiers dunikey sont **identiques** à ceux utilisés dans tous les scripts économiques (`ZEN.ECONOMY.sh`, `ZEN.COOPERATIVE.3x1-3.sh`, etc.), garantissant une **parfaite cohérence** dans l'écosystème UPlanet ẐEN.

## 🛠️ Dépannage

### Problèmes Courants

#### Portefeuille Source Non Trouvé
```bash
❌ Aucun portefeuille source trouvé
```
**Solution** : Créer un fichier dunikey dans `~/.zen/game/`

#### Solde Insuffisant
```bash
❌ Solde insuffisant pour l'initialisation
```
**Solution** : Alimenter le portefeuille source avec au moins 1 Ğ1

#### Erreur de Clé
```bash
❌ Erreur clé
```
**Solution** : Vérifier le format du fichier dunikey

### Vérifications
```bash
# Vérifier les fichiers dunikey
ls -la ~/.zen/game/*.dunikey

# Vérifier les soldes
./tools/G1check.sh <PUBKEY>

# Tester le mode simulation
./UPLANET.init.sh --dry-run
```

## 📝 Notes Techniques

### Format des Fichiers Dunikey
- Contiennent clé privée et publique
- Format : `priv: <clé_privée> pub: <clé_publique>`
- Permissions recommandées : 600
- **Cohérence** : Les noms des fichiers correspondent exactement à ceux utilisés dans `ZEN.COOPERATIVE.3x1-3.sh`

### Calculs de Solde
- Utilise `G1check.sh` pour la précision
- Tolérance de 0.01 Ğ1 pour les comparaisons
- Conversion automatique Ğ1 ↔ Ẑen (1:10 après transaction primale)

### Sécurité des Transactions
- Vérification blockchain avant confirmation
- Pause entre transactions pour éviter la surcharge
- Gestion des erreurs et rollback si nécessaire

---

## ✅ **CONFORMITÉ : ENCHAÎNEMENT CODE, NOSTR ET CACHE**

Cette section vérifie la conformité du README avec l’enchaînement réel du code, les événements NOSTR et le cache.

### **1. Enchaînement après `install.sh` (UPlanet ORIGIN)**

| Ordre | Script / Fichier | Rôle vérifié dans le code |
|-------|-------------------|----------------------------|
| 1 | `install.sh` | Clone Astroport.ONE, installe deps, appelle `setup.sh`, propose `uplanet_onboarding.sh` |
| 2 | `uplanet_onboarding.sh` | Config .env, mode ORIGIN/ẐEN, appelle `UPLANET.init.sh` puis `captain.sh` (étape 8 ou config rapide) |
| 3 | `UPLANET.init.sh` | Source `tools/my.sh` (crée si besoin uplanet.G1, uplanet, SOCIETY, etc.), crée les dunikey manquants (keygen), alimente les portefeuilles vides depuis `uplanet.G1.dunikey` ; initialise config coopérative DID |
| 4 | `captain.sh` | Vérifie `.current` ; sinon appelle `embark_captain` → `check_and_init_uplanet_infrastructure` (relance UPLANET.init si besoin) → `create_multipass` → `create_zen_card` → `did_manager_nostr.sh update … CAPTAIN` → `UPLANET.official.sh --infrastructure` |
| 5 | `make_NOSTRCARD.sh` | Création MULTIPASS : clés NOSTR/Ğ1, SSSS (head=G1PUBNOSTR, **middle=CAPTAING1PUB ou UPLANETG1PUB** si premier capitaine, tail=UPLANETG1PUB), IPNS, DID initial via `did_manager_nostr.sh` |
| 6 | `VISA.new.sh` | Création ZEN Card (secret.dunikey, MOA, lien `.current`) |
| 7 | `did_manager_nostr.sh update $email CAPTAIN` | Met à jour le DID (contractStatus astroport_captain, quota unlimited) |
| 8 | `UPLANET.official.sh --infrastructure -m $machine_value` | Inscription Armateur, apport capital |

**Bootstrap premier capitaine** : dans `make_NOSTRCARD.sh`, la part SSSS « middle » est chiffrée avec `CAPTAING1PUB` si définie, sinon **`UPLANETG1PUB`** (pas de capitaine existant). `UPLANETG1PUB` est défini par `my.sh` depuis `~/.zen/game/uplanet.dunikey` et écrit dans `~/.zen/tmp/UPLANETG1PUB`. Donc `UPLANET.init.sh` doit avoir été exécuté (ou `my.sh` sourcé) avant la création du premier MULTIPASS.

### **2. Portefeuilles créés / gérés**

- **Création des fichiers dunikey** : `my.sh` (sourcé partout) crée à la volée uplanet.G1, uplanet, SOCIETY, CASH, RnD, ASSETS, IMPOT, INTRUSION, CAPITAL, AMORTISSEMENT, TREASURY. `UPLANET.init.sh` crée aussi les dunikey manquants (dont uplanet.captain.dunikey si `CAPTAINEMAIL` est set) et **alimente** tous les portefeuilles vides depuis `uplanet.G1.dunikey`.
- **Nombre** : 10 portefeuilles coopératifs (COOPERATIVE_WALLETS) + NODE (NODE_CAPTAIN_WALLETS). Le README parle de « 8 portefeuilles + NODE + CAPTAIN » : en pratique le script gère 10 entrées coopératives (dont UPLANETNAME.CAPTAIN = `uplanet.captain.dunikey`) + NODE. L’**identité** Capitaine (MULTIPASS + ZEN Card) est créée par `captain.sh` / `make_NOSTRCARD.sh` + `VISA.new.sh`, pas par UPLANET.init.sh.

### **3. Documents et événements NOSTR**

| Usage | Kind | D-tag / identifiant | Script | Cache / stockage |
|-------|------|----------------------|--------|-------------------|
| DID utilisateur (MULTIPASS / Capitaine) | **30800** | `did` | `did_manager_nostr.sh` | `~/.zen/game/nostr/${email}/did.json.cache` |
| Config coopérative (essaim) | **30800** | `cooperative-config` | `cooperative_config.sh` | Lecture/écriture via `nostr_did_client.py` / publish DID |
| Vérification email déjà inscrit | — | — | `nostr_did_client.py check-email` | Utilisé dans `make_NOSTRCARD.sh` avant création |

- **DID (kind 30800)** : `did_manager_nostr.sh` utilise `DID_EVENT_KIND=30800`, fetch/publish via `nostr_did_client.py` et `nostr_publish_did.py`. Source de vérité = NOSTR ; cache local = `did.json.cache`.
- **Config coopérative** : `cooperative_config.sh` utilise `COOP_CONFIG_KIND=30800`, `COOP_CONFIG_D_TAG="cooperative-config"`, stockée dans le DID de UPLANETNAME_G1.

### **4. Cache (`~/.zen/tmp` et associés)**

| Fichier / répertoire | Rôle | Script / source |
|----------------------|------|-------------------|
| `~/.zen/tmp/UPLANETG1PUB` | Clé publique Services (uplanet.dunikey) | `my.sh` |
| `~/.zen/tmp/UPLANETNAME_G1` | Clé publique réserve (uplanet.G1.dunikey) | `my.sh` |
| `~/.zen/tmp/UPLANETNAME_SOCIETY` | Clé publique capital social | `my.sh` |
| `~/.zen/tmp/UPLANETNAME_*` | Autres clés coopératives (CASH, RND, IMPOT, etc.) | `my.sh` |
| `~/.zen/tmp/coucou/${pubkey}.COINS` | Solde Ğ1 par clé (TTL 24h) | `G1check.sh` |
| `~/.zen/tmp/coucou/${pubkey}.primal` | Marqueur source primale | `make_NOSTRCARD.sh` (PAYforSURE), etc. |
| `~/.zen/game/nostr/${email}/did.json.cache` | Cache DID local par utilisateur | `did_manager_nostr.sh` |

`UPLANET.init.sh` s’appuie sur `my.sh` (donc sur ce cache) et sur `G1check.sh` pour les soldes (cache `coucou`).

### **5. Résumé des corrections de conformité**

- **Bootstrap premier capitaine** : la part SSSS « middle » dans `make_NOSTRCARD.sh` utilise bien **`UPLANETG1PUB`** en fallback (pas G1PUBNOSTR), conforme au code actuel.
- **Flux** : install → uplanet_onboarding → UPLANET.init → captain → make_NOSTRCARD (avec UPLANETG1PUB si pas de capitaine) → VISA.new → did_manager_nostr (CAPTAIN) → UPLANET.official (infrastructure).
- **NOSTR** : kind 30800 pour DID et pour config coopérative (d-tag cooperative-config).
- **Cache** : `~/.zen/tmp/*` pour les clés publiques, `~/.zen/tmp/coucou/*.COINS` pour les soldes, `did.json.cache` pour les DID.

---

## 🤝 Contribution et Support

### Signaler un Problème
- Vérifier d'abord avec `--dry-run`
- Consulter les logs d'erreur
- Tester avec un solde suffisant

### Améliorations Suggérées
- Support de multiples portefeuilles sources
- Configuration des montants d'initialisation
- Intégration avec le monitoring automatique

---

## 🎯 **RÉSUMÉ EXÉCUTIF**

`UPLANET.init.sh` est le **script fondamental** qui transforme une installation Astroport.ONE en infrastructure UPlanet ẐEN complète. Il :

1. **🔐 Garantit la sécurité** via la source primale unique `UPLANETNAME_G1`
2. **🏛️ Crée l'infrastructure** complète (10 portefeuilles coopératifs + NODE ; l’identité Capitaine est créée par captain.sh)
3. **🎯 S'adapte automatiquement** au mode choisi (ORIGIN ou ẐEN)
4. **🔄 Intègre parfaitement** avec tous les scripts économiques
5. **🛡️ Assure la cohérence** de l'écosystème coopératif

**Usage recommandé** : Laisser `uplanet_onboarding.sh` l'exécuter automatiquement lors de l'embarquement, ou utiliser `--dry-run` pour vérifier l'état des portefeuilles.

---

**Version** : 2.0 (Architecture ORIGIN/ẐEN)  
**Dernière mise à jour** : Décembre 2024  
**Auteur** : Équipe UPlanet ẐEN  
**Licence** : Conforme à LEGAL.md
**Documentation** : Partie intégrante de l'écosystème UPlanet ẐEN
