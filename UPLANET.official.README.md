# UPLANET.official.sh - Script de Gestion des Virements Officiels

## 🎯 **Objectif**

Ce script gère les virements officiels de l'écosystème UPlanet ẐEN selon la [Constitution de l'Écosystème](./LEGAL.md) et implémente techniquement le [Code de la Route](./RUNTIME/ZEN.ECONOMY.readme.md).

## 🏗️ **Architecture des Virements**

### **1. Virement LOCATAIRE (Recharge MULTIPASS)**
```
UPLANETNAME.G1 → UPLANETNAME → MULTIPASS[email]
```
- **Montant** : Variable selon `$NCARD` (défini dans `my.sh`)
- **Objectif** : Recharger le compte MULTIPASS d'un locataire
- **Conformité** : Respecte le flux économique hebdomadaire

### **2. Virement SOCIÉTAIRE (Parts Sociales)**
```
UPLANETNAME.G1 → UPLANETNAME.SOCIETY → ZEN Card[email] → 3x1/3
```
- **Types** :
  - **Satellite** : 50€/an (sans IA)
  - **Constellation** : 540€/3ans (avec IA)
- **Objectif** : Attribuer des parts sociales et effectuer la répartition 3x1/3
- **Répartition** : Utilise les mêmes portefeuilles que `ZEN.COOPERATIVE.3x1-3.sh`
  - 1/3 Treasury (`~/.zen/game/uplanet.CASH.dunikey`)
  - 1/3 R&D (`~/.zen/game/uplanet.RnD.dunikey`)
  - 1/3 Assets (`~/.zen/game/uplanet.ASSETS.dunikey`)

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

### **Mode Interactif**
```bash
./UPLANET.official.sh
```
Le script affiche un menu interactif permettant de choisir le type de virement.

## 🔒 **Sécurité et Conformité**

### **Vérification des Transactions**
- **Attente de confirmation** : Le script attend que chaque transaction soit confirmée sur la blockchain
- **Timeout** : Maximum 20 minutes d'attente par transaction (configurable via `BLOCKCHAIN_TIMEOUT`)
- **Vérification automatique** : Calcule le solde attendu en soustrayant le pending du solde blockchain initial
- **Tolérance** : 0.01 Ğ1 pour les arrondis

### **Conformité Légale**
- ✅ Respect de la Constitution de l'Écosystème UPlanet ẐEN
- ✅ Application automatique de la règle 3x1/3
- ✅ Utilisation des portefeuilles coopératifs standardisés
- ✅ Traçabilité complète des flux économiques

## 📋 **Prérequis**

### **Dépendances Système**
```bash
# Outils requis
silkaj      # Interface blockchain Ğ1
jq          # Traitement JSON
bc          # Calculs mathématiques
```

### **Configuration UPlanet**
Le script nécessite que les portefeuilles suivants soient configurés :

#### **Portefeuilles Principaux**
- `UPLANETNAME.G1` → `~/.zen/game/uplanet.G1.dunikey` (Réserve Ğ1)
- `UPLANETNAME` → `~/.zen/game/uplanet.dunikey` (Compte d'exploitation)
- `UPLANETNAME.SOCIETY` → `~/.zen/game/uplanet.SOCIETY.dunikey` (Capital social)

#### **Portefeuilles Coopératifs** (créés par `ZEN.COOPERATIVE.3x1-3.sh`)
- `UPLANETNAME.TREASURY` → `~/.zen/game/uplanet.CASH.dunikey`
- `UPLANETNAME.RND` → `~/.zen/game/uplanet.RnD.dunikey`
- `UPLANETNAME.ASSETS` → `~/.zen/game/uplanet.ASSETS.dunikey`

#### **Portefeuilles Utilisateurs**
- **MULTIPASS** : `~/.zen/game/nostr/${email}/G1PUBNOSTR` & `~/.zen/game/nostr/${email}/.secret.dunikey`
- **ZEN Card** : `~/.zen/game/players/${email}/.g1pub` & `~/.zen/game/players/${email}/secret.dunikey`

**💡 Configuration** : Utilisez `zen.sh` pour configurer les portefeuilles principaux et `ZEN.COOPERATIVE.3x1-3.sh` pour les portefeuilles coopératifs.

## 🔄 **Flux de Traitement**

### **Virement Locataire**
1. **Vérification** : Contrôle de l'existence des portefeuilles
2. **Étape 1** : Transfert `UPLANETNAME.G1` → `UPLANETNAME` (via `uplanet.G1.dunikey`)
3. **Vérification** : Attente confirmation blockchain sur le wallet source
4. **Étape 2** : Transfert `UPLANETNAME` → `MULTIPASS[email]` (via `uplanet.dunikey`)
5. **Vérification** : Attente confirmation blockchain sur le wallet source
6. **Succès** : Rapport de fin d'opération

### **Virement Sociétaire**
1. **Vérification** : Contrôle de l'existence des portefeuilles
2. **Étape 1** : Transfert `UPLANETNAME.G1` → `UPLANETNAME.SOCIETY` (via `uplanet.G1.dunikey`)
3. **Vérification** : Attente confirmation blockchain sur le wallet source
4. **Étape 2** : Transfert `UPLANETNAME.SOCIETY` → `ZEN Card[email]` (via `uplanet.SOCIETY.dunikey`)
5. **Vérification** : Attente confirmation blockchain sur le wallet source
6. **Étape 3** : Répartition 3x1/3 depuis ZEN Card (via `secret.dunikey` de l'utilisateur)
   - Treasury (1/3) → `uplanet.CASH.dunikey`
   - R&D (1/3) → `uplanet.RnD.dunikey`
   - Assets (1/3) → `uplanet.ASSETS.dunikey`
7. **Succès** : Rapport de fin d'opération

## 🔧 **Configuration et Personnalisation**

### **Variables d'Environnement**
Le script charge automatiquement :
- **`my.sh`** : Variables UPlanet et configuration système
- **`.env`** : Paramètres personnalisables (créé à partir de `env.template`)

### **Paramètres Configurables**
```bash
# Timeouts et intervalles
BLOCKCHAIN_TIMEOUT=1200      # 20 minutes max
VERIFICATION_INTERVAL=60      # Vérification toutes les 60 secondes

# Montants par défaut (définis dans my.sh)
NCARD                        # Recharge MULTIPASS hebdomadaire
ZENCARD_SATELLITE=50         # 50€/an
ZENCARD_CONSTELLATION=540    # 540€/3ans
```

## 📊 **Exemples d'Utilisation**

### **Scénario 1 : Nouveau Locataire**
```bash
# Recharge hebdomadaire pour un nouveau locataire
./UPLANET.official.sh -l john.doe@example.com

# Résultat attendu
🏠 Traitement virement LOCATAIRE pour: john.doe@example.com
💰 Montant: 1€ (1 Ẑen)
📤 Étape 1: Transfert UPLANETNAME.G1 → UPLANETNAME
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
📤 Étape 1: Transfert UPLANETNAME.G1 → UPLANETNAME.SOCIETY
📤 Étape 2: Transfert UPLANETNAME.SOCIETY → ZEN Card jane.smith@example.com
📤 Étape 3: Répartition 3x1/3 depuis ZEN Card
  📤 Treasury (1/3): 16.66 Ẑen
  📤 R&D (1/3): 16.66 Ẑen
  📤 Assets (1/3): 16.68 Ẑen
🎉 Virement sociétaire terminé avec succès!
```

## 🚨 **Gestion des Erreurs**

### **Erreurs Communes**
- **Portefeuilles non configurés** : Le script vérifie l'existence des fichiers dunikey
- **Portefeuilles coopératifs manquants** : Message d'aide pour exécuter `ZEN.COOPERATIVE.3x1-3.sh`
- **Timeout blockchain** : Si une transaction n'est pas confirmée en 20 minutes
- **Dépendances manquantes** : Vérification de `silkaj`, `jq`, `bc`

### **Codes de Retour**
- `0` : Succès
- `1` : Erreur (détails dans les messages)

## 🔍 **Fonctionnement Technique**

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
- UPLANETNAME.G1 → uplanet.G1.dunikey
- UPLANETNAME → uplanet.dunikey  
- UPLANETNAME.SOCIETY → uplanet.SOCIETY.dunikey
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
- **Version** : 1.0
- **Statut** : ✅ **CONFORME** à la Constitution UPlanet ẐEN

---

**"Ce script transforme les règles statutaires en protocole automatisé, transparent et décentralisé, en utilisant les standards de sécurité et de configuration du projet UPlanet."**
