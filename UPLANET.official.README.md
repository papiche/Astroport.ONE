# UPLANET.official.sh - Script de Gestion des Virements Officiels

## 🎯 **Objectif**

Ce script gère les virements officiels de l'écosystème UPlanet ẐEN selon la [Constitution de l'Écosystème](./LEGAL.md) et implémente techniquement le [Code de la Route](./RUNTIME/ZEN.ECONOMY.readme.md).

## 🏗️ **Niveaux de Station UPlanet**

### **🔴 Niveau X (Station Standard)**
- **SSH** : Clé SSH standard (non jumelée)
- **IPFS** : Identité IPFS indépendante
- **NODE** : Conversion `IPFSNODEID → G1PUB` via `ipfs_to_g1.py`
- **Fichier** : ❌ Pas de `secret.NODE.dunikey`
- **Usage** : Stations de base, développement, tests

### **🟡 Niveau Y (Station Transmutée)**
- **SSH** : Clé SSH jumelée avec IPFS (via `Ylevel.sh`)
- **IPFS** : Identité IPFS liée à la clé SSH
- **NODE** : Fichier `secret.NODE.dunikey` créé par transmutation
- **Fichier** : ✅ `secret.NODE.dunikey` existe
- **Usage** : Stations de production, sécurité renforcée

### **🔄 Processus de Transmutation (Ylevel.sh)**
```bash
# Avant transmutation (Niveau X)
~/.ssh/id_ed25519          # Clé SSH standard
~/.ipfs/config             # Identité IPFS indépendante
# Pas de secret.NODE.dunikey

# Après transmutation (Niveau Y)
~/.ssh/id_ed25519          # Clé SSH jumelée avec IPFS
~/.ipfs/config             # Identité IPFS liée à SSH
~/.zen/game/secret.NODE.dunikey  # Fichier NODE créé
```

### **🎯 Détection Automatique du Niveau**
Le script détecte automatiquement le niveau de la station :

```bash
# Logique de détection (my.sh + UPLANET.official.sh)
if [[ -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
    # Niveau Y : Utilise le fichier transmuté
    node_pubkey=$(cat "$HOME/.zen/game/secret.NODE.dunikey" | grep "pub:" | cut -d ' ' -f 2)
    echo "✅ NODE trouvé (niveau Y): ${node_pubkey:0:8}..."
else
    # Niveau X : Conversion IPFSNODEID → G1PUB
    if [[ -n "$IPFSNODEID" ]]; then
        node_pubkey=$(${MY_PATH}/ipfs_to_g1.py "$IPFSNODEID")
        echo "✅ NODE généré (conversion IPFS): ${node_pubkey:0:8}..."
    fi
fi
```

### **📊 Comparaison des Niveaux**

| **Aspect** | **Niveau X** | **Niveau Y** | **Niveau Z** |
|------------|--------------|--------------|--------------|
| **SSH/IPFS** | Indépendants | Jumelés | Jumelés + PGP |
| **Fichier NODE** | ❌ Absent | ✅ `secret.NODE.dunikey` | ✅ `secret.NODE.dunikey` |
| **Méthode NODE** | Conversion IPFS | Lecture fichier | Lecture fichier |
| **Sécurité** | Standard | Renforcée | Maximale |
| **Performance** | Conversion à chaque fois | Cache optimisé | Cache optimisé |
| **Transmutation** | Non effectuée | Via `Ylevel.sh` | Via `Ylevel.sh` + PGP |
| **Vérification Humaine** | ⚠️ Limitée | ✅ Confirmée | ✅ Maximale |

### **🔒 Sécurité et Vérification Humaine**

Le système de niveaux X/Y/Z garantit qu'**un Humain est aux commandes** de la machine :

#### **🔴 Niveau X - Vérification Basique**
- **Statut** : Station standard, développement
- **Sécurité** : SSH/IPFS indépendants
- **Vérification Humaine** : Limitée (pas de jumelage cryptographique)
- **Usage** : Tests, développement, stations temporaires

#### **🟡 Niveau Y - Vérification Renforcée**
- **Statut** : Station transmutée, production
- **Sécurité** : SSH/IPFS jumelés via `Ylevel.sh`
- **Vérification Humaine** : ✅ **Confirmée** (transmutation cryptographique)
- **Usage** : Production, stations permanentes
- **Garantie** : L'identité SSH est liée à l'identité IPFS

#### **🟢 Niveau Z - Vérification Maximale**
- **Statut** : Station transmutée + PGP
- **Sécurité** : SSH/IPFS jumelés + PGP intégré
- **Vérification Humaine** : ✅ **Maximale** (triple vérification)
- **Usage** : Stations critiques, haute sécurité
- **Garantie** : Triple vérification SSH/IPFS/PGP

### **🎯 Pourquoi cette Vérification est Cruciale ?**

1. **Prévention des Bots** : Seuls les humains peuvent effectuer la transmutation
2. **Sécurité Économique** : Les virements importants nécessitent une identité vérifiée
3. **Traçabilité** : Chaque transaction est liée à une identité humaine confirmée
4. **Gouvernance** : Les décisions économiques sont prises par des humains identifiés
5. **Conformité Légale** : Respect des réglementations sur l'identité numérique

### **🔄 Processus de Vérification**

```bash
# Niveau X → Y : Transmutation SSH/IPFS
Ylevel.sh  # Jumelage cryptographique SSH ↔ IPFS

# Niveau Y → Z : Intégration PGP
# Vérification PGP supplémentaire pour sécurité maximale
```

## 🏗️ **Architecture des Virements**

### **1. Virement MULTIPASS (Recharge MULTIPASS)**
```
UPLANETNAME_G1 → UPLANETNAME → MULTIPASS[email]
```
- **Montant** : Variable selon `$NCARD` (défini dans `my.sh`)
- **Objectif** : Recharger le compte MULTIPASS d'un locataire
- **Conformité** : Respecte le flux économique hebdomadaire

### **2. Virement SOCIÉTAIRE (Parts Sociales)**
```
UPLANETNAME_G1 → UPLANETNAME_SOCIETY → ZEN Card[email] → 3x1/3
```
- **Types** :
  - **Satellite** : 50€/an (sans IA)
  - **Constellation** : 540€/3ans (avec IA)
- **Objectif** : Attribuer des parts sociales et effectuer la répartition 3x1/3
- **Répartition** : Utilise les mêmes portefeuilles que `ZEN.COOPERATIVE.3x1-3.sh`
  - 1/3 Treasury (`~/.zen/game/uplanet.CASH.dunikey`)
  - 1/3 R&D (`~/.zen/game/uplanet.RnD.dunikey`)
  - 1/3 Assets (`~/.zen/game/uplanet.ASSETS.dunikey`)

### **3. Apport CAPITAL INFRASTRUCTURE (Valorisation Machine)**
```
UPLANETNAME_G1 → ZEN Card[CAPTAIN] → NODE
```
- **Type** : Infrastructure (500€ par défaut)
- **Objectif** : Apport au capital fixe (valorisation machine du capitaine)
- **Spécificité** : **PAS de répartition 3x1/3** (apport au capital non distribuable)
- **Email automatique** : Utilise `$CAPTAINEMAIL` depuis `my.sh`
- **Valeur** : `$MACHINE_VALUE_ZEN` ou saisie interactive

### **4. 🔧 MODE DÉPANNAGE - Récupération Complète**
```
SOCIETY → ZEN Card[email] → 3x1/3 (TREASURY, RnD, ASSETS)
```
- **Usage** : Quand des fonds sont bloqués dans SOCIETY
- **Processus complet** : Effectue les 2 étapes (SOCIETY → ZEN Card → 3x1/3)
- **Option** : `-r` ou `--recovery`

### **5. 🔧 MODE DÉPANNAGE - Récupération Partielle**
```
ZEN Card[email] → 3x1/3 (au choix : TREASURY, RnD, ou ASSETS)
```
- **Usage** : Quand la 2ème étape a échoué partiellement
- **Processus sélectif** : Refaire un seul transfert vers le portefeuille manquant
- **Option** : `--recovery-3x13`
- **Cas d'usage** : Réparer les échecs de répartition 3x1/3

## 🚀 **Utilisation**

### **Mode Ligne de Commande**

#### **Virement Locataire**
```bash
# Recharge MULTIPASS standard (selon $NCARD)
./UPLANET.official.sh -l user@example.com

# Recharge MULTIPASS personnalisée
./UPLANET.official.sh -l user@example.com -m 5
```

#### **Virement Sociétaire**
```bash
# Parts sociales satellite (50€/an)
./UPLANET.official.sh -s user@example.com -t satellite

# Parts sociales constellation (540€/3ans)
./UPLANET.official.sh -s user@example.com -t constellation

# Montant personnalisé
./UPLANET.official.sh -s user@example.com -t satellite -m 100
```

#### **Apport Capital Infrastructure**
```bash
# Apport capital avec valeur par défaut (MACHINE_VALUE_ZEN ou 500€)
./UPLANET.official.sh -i

# Note: Email automatique depuis $CAPTAINEMAIL (my.sh)
```

#### **Modes Dépannage**
```bash
# Récupération complète depuis SOCIETY
./UPLANET.official.sh -r

# Récupération partielle depuis ZEN Card
./UPLANET.official.sh --recovery-3x13
```

### **Mode Interactif**
```bash
./UPLANET.official.sh
```

**Menu disponible :**
1. Virement MULTIPASS (recharge MULTIPASS)
2. Virement SOCIÉTAIRE Satellite (50€/an)
3. Virement SOCIÉTAIRE Constellation (540€/3ans)
4. Apport CAPITAL INFRASTRUCTURE (CAPTAIN → NODE)
5. 🔧 MODE DÉPANNAGE (récupération complète SOCIETY → 3x1/3)
6. 🔧 MODE DÉPANNAGE (récupération partielle ZEN Card → 3x1/3)
7. Quitter

## 🔒 **Sécurité et Conformité**

### **Vérification des Transactions**
- **Attente de confirmation** : Le script attend que chaque transaction soit confirmée sur la blockchain
- **Timeout** : Maximum **40 minutes** d'attente par transaction (configurable via `BLOCKCHAIN_TIMEOUT`)
- **Vérification automatique** : Vérifie que le solde pending repasse à 0
- **Intervalle de vérification** : Toutes les 60 secondes (configurable via `VERIFICATION_INTERVAL`)

### **Conformité Légale**
- ✅ Respect de la Constitution de l'Écosystème UPlanet ẐEN
- ✅ Application automatique de la règle 3x1/3
- ✅ Utilisation des portefeuilles coopératifs standardisés
- ✅ Traçabilité complète des flux économiques
- ✅ Mise à jour automatique des DID via `did_manager_nostr.sh`

### **Vérification Humaine des Virements**
- ✅ **Niveau Y/Z requis** : Les virements importants nécessitent une station transmutée
- ✅ **Identité vérifiée** : Chaque transaction est liée à une identité humaine confirmée
- ✅ **Prévention des bots** : Seuls les humains peuvent effectuer des virements économiques
- ✅ **Traçabilité** : Références blockchain incluent l'identité du nœud humain
- ✅ **Sécurité économique** : Protection contre les transactions automatisées non autorisées

### **WoT DRAGON - Web of Trust**
Le système respecte les usages de la **Web of Trust DRAGON** :

#### **🔑 Primo-Transaction NODE**
- **Source** : UPLANETNAME_G1 (compte principal)
- **Destination** : Wallet NODE (niveau Y/Z)
- **Montant** : 1Ğ1 (primo-transaction)
- **Référence** : `UPLANET:${UPLANETG1PUB:0:8}:NODEINIT:${IPFSNODEID}`
- **Justification** : Initialisation du nœud par l'écosystème UPlanet

#### **🔄 Validation WoT DRAGON (.2nd)**
- **Source** : Compte forgeron du Capitaine (`CAPTAINEMAIL`)
- **Destination** : Wallet NODE (même adresse)
- **Montant** : 0.01Ğ1 (transaction de validation)
- **Référence** : `$CAPTAINEMAIL`
- **Justification** : Validation WoT par le Capitaine forgeron

#### **📊 Avantages WoT DRAGON**
1. **Traçabilité** : Chaque NODE est initialisé par UPlanet puis validé par son Capitaine
2. **Sécurité** : Double vérification (UPlanet + Capitaine forgeron)
3. **Gouvernance** : Responsabilité claire du Capitaine sur son nœud
4. **Conformité** : Respect des standards de la Web of Trust
5. **Validation Humaine** : Le Capitaine confirme son contrôle via sa transaction forgeron

## 📋 **Prérequis**

### **Dépendances Système**
```bash
# Outils requis
silkaj      # Interface blockchain Ğ1
jq          # Traitement JSON
bc          # Calculs mathématiques
```

### **Niveau de Station Requis**

Le script fonctionne avec **tous les niveaux de station** :

#### **🔴 Niveau X (Standard)**
- ✅ **Fonctionne** : Utilise la conversion `IPFSNODEID → G1PUB`
- ✅ **Recommandé pour** : Développement, tests, stations temporaires
- ✅ **Prérequis** : `IPFSNODEID` disponible dans l'environnement

#### **🟡 Niveau Y (Transmutée)**
- ✅ **Fonctionne** : Utilise le fichier `secret.NODE.dunikey`
- ✅ **Recommandé pour** : Production, stations permanentes
- ✅ **Prérequis** : Exécution de `Ylevel.sh` pour la transmutation SSH/IPFS
- ✅ **Sécurité** : Vérification humaine confirmée

#### **🟢 Niveau Z (Transmutée + PGP)**
- ✅ **Fonctionne** : Utilise le fichier `secret.NODE.dunikey` + PGP
- ✅ **Recommandé pour** : Stations critiques, haute sécurité
- ✅ **Prérequis** : Transmutation SSH/IPFS + intégration PGP
- ✅ **Sécurité** : Vérification par Dongle USB (YubiKey)

### **Niveau de Station par Type de Virement**

| **Type de Virement** | **Niveau Minimum** | **Justification** |
|----------------------|-------------------|-------------------|
| **MULTIPASS** | X | Recharge simple, pas de risque économique majeur |
| **SOCIÉTAIRE** | Y | Parts sociales, nécessite identité vérifiée |
| **INFRASTRUCTURE** | Y | Apport capital, sécurité économique requise |
| **PAF Burn** | Y | Gestion économique critique, vérification humaine |
| **Dépannage** | Y | Opérations de récupération, sécurité requise |

### **Configuration UPlanet**
Le script nécessite que les portefeuilles suivants soient configurés :

#### **Portefeuilles Principaux**
- `UPLANETNAME_G1` → `~/.zen/game/uplanet.G1.dunikey` (Réserve Ğ1)
- `UPLANETNAME` → `~/.zen/game/uplanet.dunikey` (Compte d'exploitation)
- `UPLANETNAME_SOCIETY` → `~/.zen/game/uplanet.SOCIETY.dunikey` (Capital social)

#### **Portefeuilles Coopératifs** (créés par `ZEN.COOPERATIVE.3x1-3.sh`)
- `UPLANETNAME_TREASURY` → `~/.zen/game/uplanet.CASH.dunikey`
- `UPLANETNAME_RND` → `~/.zen/game/uplanet.RnD.dunikey`
- `UPLANETNAME_ASSETS` → `~/.zen/game/uplanet.ASSETS.dunikey`

#### **Portefeuilles Utilisateurs**
- **MULTIPASS** : `~/.zen/game/nostr/${email}/G1PUBNOSTR` & `~/.zen/game/nostr/${email}/.secret.dunikey`
- **ZEN Card** : `~/.zen/game/players/${email}/.g1pub` & `~/.zen/game/players/${email}/secret.dunikey`

**💡 Configuration** : Utilisez `zen.sh` pour configurer les portefeuilles principaux et `ZEN.COOPERATIVE.3x1-3.sh` pour les portefeuilles coopératifs.

## 🔄 **Flux de Traitement**

### **Virement Locataire**
1. **Vérification** : Contrôle de l'existence des portefeuilles
2. **Étape 1** : Transfert `UPLANETNAME_G1` → `UPLANETNAME` (via `uplanet.G1.dunikey`)
3. **Vérification** : Attente confirmation blockchain sur le wallet source
4. **Étape 2** : Transfert `UPLANETNAME` → `MULTIPASS[email]` (via `uplanet.dunikey`)
5. **Vérification** : Attente confirmation blockchain sur le wallet source
6. **Succès** : Rapport de fin d'opération

### **Virement Sociétaire**
1. **Vérification** : Contrôle de l'existence des portefeuilles
2. **Étape 1** : Transfert `UPLANETNAME_G1` → `UPLANETNAME_SOCIETY` (via `uplanet.G1.dunikey`)
3. **Vérification** : Attente confirmation blockchain (max 40 minutes)
4. **Étape 2** : Transfert `UPLANETNAME_SOCIETY` → `ZEN Card[email]` (via `uplanet.SOCIETY.dunikey`)
5. **Vérification** : Attente confirmation blockchain (max 40 minutes)
6. **Étape 3** : Répartition 3x1/3 depuis ZEN Card (via `secret.dunikey` de l'utilisateur)
   - Treasury (1/3) → `uplanet.CASH.dunikey` + attente confirmation
   - R&D (1/3) → `uplanet.RnD.dunikey` + attente confirmation
   - Assets (1/3) → `uplanet.ASSETS.dunikey` + attente confirmation
7. **Mise à jour DID** : Enregistrement des contributions pour chaque portefeuille
8. **Succès** : Rapport de fin d'opération

### **Mode Dépannage - Récupération Complète**
1. **Affichage du solde SOCIETY** : Vérification des fonds disponibles
2. **Demande de l'email** : Identification du sociétaire
3. **Vérification ZEN Card** : Récupération de la clé publique et dunikey
4. **Vérification portefeuilles 3x1/3** : TREASURY, R&D, ASSETS
5. **Demande du montant** : Saisie ou 'max' pour tout transférer
6. **Calcul 3x1/3** : Répartition automatique en 3 parts égales
7. **Étape 1** : SOCIETY → ZEN Card + attente confirmation (max 40 minutes)
8. **Étape 2** : ZEN Card → 3x1/3 (3 transferts séquentiels avec confirmation)
9. **Mise à jour DID** : Enregistrement du statut sociétaire et contributions
10. **Succès** : Rapport complet avec nouveau solde SOCIETY

### **Mode Dépannage - Récupération Partielle**
1. **Demande de l'email** : Identification du sociétaire
2. **Affichage du solde ZEN Card** : Vérification des fonds disponibles
3. **Menu de sélection** : Choix du portefeuille destination (TREASURY, R&D, ou ASSETS)
4. **Demande du montant** : Saisie du montant à transférer (en Ẑen)
5. **Transfert** : ZEN Card → Portefeuille sélectionné + attente confirmation (max 40 minutes)
6. **Mise à jour DID** : Enregistrement de la contribution spécifique
7. **Succès** : Rapport avec nouveau solde ZEN Card

## 🔧 **Configuration et Personnalisation**

### **Variables d'Environnement**
Le script charge automatiquement :
- **`my.sh`** : Variables UPlanet et configuration système
- **`.env`** : Paramètres personnalisables (créé à partir de `env.template`)

### **Paramètres Configurables**
```bash
# Timeouts et intervalles
BLOCKCHAIN_TIMEOUT=2400      # 40 minutes max (2400 secondes)
VERIFICATION_INTERVAL=60      # Vérification toutes les 60 secondes

# Montants par défaut (définis dans my.sh)
NCARD                        # Recharge MULTIPASS hebdomadaire
ZENCARD_SATELLITE=50         # 50€/an
ZENCARD_CONSTELLATION=540    # 540€/3ans
MACHINE_VALUE_ZEN=500        # Valeur machine par défaut
```

## 📊 **Exemples d'Utilisation**

### **Scénario 1 : Nouveau Locataire**
```bash
# Recharge hebdomadaire pour un nouveau locataire
./UPLANET.official.sh -l john.doe@example.com

# Résultat attendu
🏠 Traitement virement MULTIPASS pour: john.doe@example.com
💰 Montant: 1€ (1 Ẑen)
📤 Étape 1: Transfert UPLANETNAME_G1 → UPLANETNAME
📤 Étape 2: Transfert UPLANETNAME → MULTIPASS john.doe@example.com
🎉 Virement locataire terminé avec succès!
```

### **Scénario 2 : Nouveau Sociétaire Satellite**
```bash
# Attribution parts sociales satellite
./UPLANET.official.sh -s jane.smith@example.com -t satellite

# Résultat attendu
👑 Traitement virement SOCIÉTAIRE pour: jane.smith@example.com
💰 Type: satellite - Montant: 50€ (50 Ẑen)
📤 Étape 1: Transfert UPLANETNAME_G1 → UPLANETNAME_SOCIETY
📤 Étape 2: Transfert UPLANETNAME_SOCIETY → ZEN Card jane.smith@example.com
📤 Étape 3: Répartition 3x1/3 depuis ZEN Card
  📤 Treasury (1/3): 16.66 Ẑen
  📤 R&D (1/3): 16.66 Ẑen
  📤 Assets (1/3): 16.68 Ẑen
🎉 Virement sociétaire terminé avec succès!
```

### **Scénario 3 : Mode Dépannage - Fonds Bloqués dans SOCIETY**
```bash
# Situation : Des fonds sont restés bloqués dans SOCIETY après un échec
./UPLANET.official.sh -r

# Interaction
Email du sociétaire: jane.smith@example.com
✅ ZEN Card trouvée: AbCdEf12...
✅ Treasury trouvé: XyZ789...
✅ R&D trouvé: QrStUv45...
✅ Assets trouvé: WxYz67...

💰 Montant disponible dans SOCIETY: 5.0 Ğ1 (50 Ẑen)
Montant à transférer en Ẑen (ou 'max' pour tout transférer): max
Type de sociétaire (satellite/constellation): satellite

# Résultat attendu
📤 Étape 1: Transfert SOCIETY → ZEN Card jane.smith@example.com
✅ Transaction confirmée - Solde: 5.0 Ğ1
📤 Étape 2: Répartition 3x1/3 depuis ZEN Card
  📤 Treasury (1/3): 16.66 Ẑen
  ✅ Transaction confirmée
  📤 R&D (1/3): 16.66 Ẑen
  ✅ Transaction confirmée
  📤 Assets (1/3): 16.68 Ẑen
  ✅ Transaction confirmée
🎉 Transfert de récupération terminé avec succès!
```

### **Scénario 4 : Mode Dépannage - Réparation Partielle 3x1/3**
```bash
# Situation : La 2ème étape a échoué, seul le transfert vers R&D a réussi
# Il reste des fonds dans la ZEN Card à redistribuer
./UPLANET.official.sh --recovery-3x13

# Interaction
Email du sociétaire: jane.smith@example.com
✅ ZEN Card trouvée: AbCdEf12...

💰 Solde de la ZEN Card: 3.33 Ğ1 (33.3 Ẑen)

📋 Sélectionnez le portefeuille de destination:
1. TREASURY (CASH)
2. R&D
3. ASSETS
4. Annuler
Votre choix (1-4): 1

Montant à transférer en Ẑen: 16.65
Type de sociétaire (satellite/constellation): satellite

# Résultat attendu
🚀 Lancement du transfert ZEN Card → TREASURY...
✅ Transaction confirmée - Solde: 1.67 Ğ1
🎉 Transfert de récupération 3x1/3 terminé avec succès!
✅ Nouveau solde ZEN Card: 1.67 Ğ1 (16.7 Ẑen)

# On peut maintenant refaire le transfert vers ASSETS
./UPLANET.official.sh --recovery-3x13
# Sélectionner ASSETS cette fois...
```

## 🚨 **Gestion des Erreurs**

### **Erreurs Communes**
- **Portefeuilles non configurés** : Le script vérifie l'existence des fichiers dunikey
- **Portefeuilles coopératifs manquants** : Message d'aide pour exécuter `ZEN.COOPERATIVE.3x1-3.sh`
- **Timeout blockchain** : Si une transaction n'est pas confirmée en 40 minutes (configurable)
- **Dépendances manquantes** : Vérification de `silkaj`, `jq`, `bc`
- **ZEN Card non trouvée** : Vérifier que le dossier `~/.zen/game/players/${email}/` existe
- **Solde insuffisant ZEN Card** : Le script vérifie qu'il y a > 1Ğ1 pour effectuer un transfert

### **Modes de Dépannage - Quand les Utiliser ?**

| Situation | Mode à Utiliser | Commande |
|-----------|----------------|----------|
| 🔴 Fonds bloqués dans SOCIETY | Récupération Complète | `./UPLANET.official.sh -r` |
| 🟠 Étape 1 OK, mais 3x1/3 a échoué complètement | Récupération Complète | `./UPLANET.official.sh -r` |
| 🟡 Étape 1 OK, mais un seul transfert 3x1/3 a échoué | Récupération Partielle | `./UPLANET.official.sh --recovery-3x13` |
| 🟢 Transaction normale | Virement Sociétaire | `./UPLANET.official.sh -s user@example.com -t satellite` |

### **Alertes Automatiques**
Le script envoie automatiquement des alertes au CAPTAINEMAIL en cas de :
- **Timeout blockchain** : Transaction non confirmée après 40 minutes
- **Erreur de transfert** : Échec lors de l'exécution d'un transfert
- **Erreur dunikey** : Fichier de clés manquant ou invalide
- **Erreur pubkey** : Impossible de récupérer la clé publique

### **Codes de Retour**
- `0` : Succès
- `1` : Erreur (détails dans les messages)

## 🔍 **Fonctionnement Technique**

### **Format des Références Blockchain**

Toutes les transactions de parts de capital incluent l'identifiant IPFS du nœud (`$IPFSNODEID`) pour assurer la traçabilité :

| Type de Transaction | Format de Référence |
|---------------------|---------------------|
| **ZENCOIN** (Location) | `UPLANET:${UPLANETG1PUB:0:8}:ZENCOIN:${email}` |
| **CAPITAL** (Infrastructure) | `UPLANET:${UPLANETG1PUB:0:8}:CAPITAL:${email}:${IPFSNODEID}` |
| **SOCIETY** (Parts Sociales) | `UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email}:${type}:${IPFSNODEID}` |
| **TREASURY** (1/3 Trésorerie) | `UPLANET:${UPLANETG1PUB:0:8}:TREASURY:${email}:${type}:${IPFSNODEID}` |
| **RnD** (1/3 R&D) | `UPLANET:${UPLANETG1PUB:0:8}:RnD:${email}:${type}:${IPFSNODEID}` |
| **ASSETS** (1/3 Actifs) | `UPLANET:${UPLANETG1PUB:0:8}:ASSETS:${email}:${type}:${IPFSNODEID}` |

**Exemple de référence :**
```
UPLANET:4ZqazktD:SOCIETY:support@qo-op.com:constellation:12D3KooWL2FcDJ41U9SyLuvDmA5qGzyoaj2RoEHiJPpCvY8jvx9u
```

**Avantages de la traçabilité :**
- 🔍 **Identification du nœud** : Chaque transaction identifie la machine à l'origine
- 📊 **Statistiques par infrastructure** : Calcul des contributions par nœud
- 🏛️ **Gouvernance transparente** : Visibilité sur les apports de capital
- 🔒 **Auditabilité complète** : Transparence sur les sources de financement

### **Vérification des Transactions**
```bash
# Le script utilise silkaj --json money balance pour :
1. Récupérer le solde initial (blockchain + pending)
2. Attendre que pending = 0
3. Vérifier que le solde final = blockchain initial - pending initial
```

### **Gestion des Clés Privées**
```bash
# Chaque transfert utilise le fichier dunikey approprié :
- UPLANETNAME_G1 → uplanet.G1.dunikey
- UPLANETNAME → uplanet.dunikey  
- UPLANETNAME_SOCIETY → uplanet.SOCIETY.dunikey
- ZEN Card → secret.dunikey de l'utilisateur
```

## 🔧 **Maintenance et Évolution**

### **Logs et Monitoring**
- **Affichage en temps réel** : Progression des étapes avec couleurs
- **Validation automatique** : Confirmation de chaque étape
- **Gestion des timeouts** : Configurable via variables d'environnement

### **Évolutions Futures**
- Support des notifications email
- Mode simulation pour tests
- Intégration avec d'autres outils UPlanet

## 📚 **Documentation Associée**

- **[Constitution de l'Écosystème](./LEGAL.md)** : Cadre légal et règles économiques
- **[Code de la Route](./RUNTIME/ZEN.ECONOMY.readme.md)** : Implémentation technique
- **[ZEN.COOPERATIVE.3x1-3.sh](./RUNTIME/ZEN.COOPERATIVE.3x1-3.sh)** : Script de répartition coopérative
- **[Diagramme des Flux](./templates/mermaid_LEGAL_UPLANET_FLUX.mmd)** : Visualisation des flux économiques

## 🤝 **Support et Contribution**

- **Auteur** : Fred (support@qo-op.com)
- **Licence** : AGPL-3.0
- **Version** : 1.2
- **Statut** : ✅ **CONFORME** à la Constitution UPlanet ẐEN

### **Changelog v1.2**
- ✅ Timeout de confirmation étendu à 40 minutes (au lieu de 20)
- ✅ Nouveau mode dépannage complet : Récupération SOCIETY → ZEN Card → 3x1/3
- ✅ Nouveau mode dépannage partiel : Récupération ZEN Card → 3x1/3 (sélectif)
- ✅ Mise à jour automatique des DID après chaque contribution
- ✅ Alertes automatiques par email en cas d'erreur
- ✅ Amélioration de la traçabilité et du reporting

---

**"Ce script transforme les règles statutaires en protocole automatisé, transparent et décentralisé, en utilisant les standards de sécurité et de configuration du projet UPlanet."**
