# 📋 RÔLES DES SCRIPTS UPLANET ẐEN

## 🎯 **ARCHITECTURE COMPLÈTE ET SPÉCIALISÉE**

L'écosystème UPlanet ẐEN dispose d'une architecture modulaire avec des scripts spécialisés pour chaque fonction. Cette documentation présente les rôles de chaque composant dans le système coopératif.

---

## 🚀 **SCRIPTS D'EMBARQUEMENT ET CONFIGURATION**

### **🏴‍☠️ uplanet_onboarding.sh** - Assistant d'Embarquement Principal

#### **🎯 Rôle Principal**
Script **PRINCIPAL** pour l'embarquement des nouveaux capitaines dans l'écosystème UPlanet ẐEN.

#### **✅ Fonctionnalités**
- **Choix du mode** : ORIGIN (niveau X) vs ẐEN (niveau Y)
- **Configuration économique** : PAF, tarifs, valorisation machine
- **Détection automatique** des ressources via `heartbox_analysis.sh`
- **Configuration réseau** : Swarm IPFS selon le mode choisi
- **Initialisation complète** : Portefeuilles et infrastructure
- **Embarquement capitaine** : Création identité et formation

#### **🎮 Usage**
```bash
# Lancement complet
./uplanet_onboarding.sh

# Étapes individuelles disponibles dans le menu interactif
```

### **🔧 update_config.sh** - Gestionnaire de Configuration

#### **🎯 Rôle Principal**
Script **INTELLIGENT** pour la gestion des configurations existantes et les migrations.

#### **✅ Fonctionnalités**
- **Détection automatique** du mode UPlanet actuel (ORIGIN/ẐEN/Fraîche)
- **Migration sécurisée** ORIGIN → ẐEN avec désinscription automatique
- **Mise à jour configuration** avec fusion intelligente
- **Interdiction migrations** dangereuses (ẐEN → ORIGIN, ẐEN → ẐEN)
- **Interface ligne de commande** avec options directes

#### **🎮 Usage**
```bash
# Mode interactif
./update_config.sh

# Options directes
./update_config.sh --update    # Mise à jour
./update_config.sh --show      # Affichage config
./update_config.sh --onboard   # Embarquement
```

---

## 🏛️ **SCRIPTS ÉCONOMIQUES PRINCIPAUX**

### **🏛️ UPLANET.official.sh** - Virements Officiels Automatisés

#### **🎯 Rôle Principal**
Script **PRINCIPAL** pour tous les virements officiels conformes à la Constitution ẐEN.

#### **✅ Fonctionnalités**
- **Virement LOCATAIRE** : `UPLANETNAME_G1 → UPLANETNAME → MULTIPASS`
- **Virement SOCIÉTAIRE** : `UPLANETNAME_G1 → UPLANETNAME.SOCIETY → ZEN Card → 3x1/3`
- **Apport CAPITAL INFRASTRUCTURE** : `UPLANETNAME_G1 → ZEN Card CAPTAIN → NODE` (direct, pas de 3x1/3)
- **Vérification automatique** des transactions blockchain
- **Gestion des timeouts** et confirmations
- **Menu interactif** et ligne de commande
- **Conformité totale** aux flux économiques officiels

#### **🎮 Usage**
```bash
# Mode interactif
./UPLANET.official.sh

# Ligne de commande
./UPLANET.official.sh -l user@example.com          # Locataire
./UPLANET.official.sh -s user@example.com -t satellite    # Sociétaire
./UPLANET.official.sh -i                           # Apport capital (CAPTAIN automatique)
```

### **🏛️ UPLANET.init.sh** - Initialisation Infrastructure

#### **🎯 Rôle Principal**
Script **FONDAMENTAL** pour l'initialisation de tous les portefeuilles coopératifs.

#### **✅ Fonctionnalités**
- **Initialisation complète** : Tous les portefeuilles depuis `UPLANETNAME_G1`
- **Portefeuilles NODE et CAPTAIN** : Infrastructure opérationnelle
- **Portefeuilles coopératifs** : CASH, RND, ASSETS, IMPOT, SOCIETY
- **Vérification automatique** des soldes et prérequis
- **Mode simulation** : `--dry-run` pour tests sans risque

#### **🎮 Usage**
```bash
# Initialisation complète
./UPLANET.init.sh

# Mode simulation
./UPLANET.init.sh --dry-run

# Mode forcé (sans confirmation)
./UPLANET.init.sh --force
```

---

## 🔍 **zen.sh** - Analyse Économique et Diagnostic

### **🎯 Rôle Principal**
Script **SPÉCIALISÉ** pour l'analyse, le diagnostic et les transactions manuelles exceptionnelles.

### **✅ Fonctionnalités**
- **Analyse détaillée** des portefeuilles utilisateurs
- **Diagnostic** des chaînes primales et sources
- **Historique** des transactions avec exports
- **Reporting OpenCollective** automatisé
- **Retranscription** des versements par source
- **Transactions manuelles** pour cas exceptionnels
- **Maintenance** et configuration avancée

### **🎮 Usage**
```bash
./tools/zen.sh                    # Interface complète
./tools/zen.sh --detailed         # Affichage détaillé
```

### **⚠️ Important**
- **Focus** sur l'analyse et le diagnostic

---

## 📊 **dashboard.sh** - Interface Capitaine Simplifiée

### **🎯 Rôle Principal**
Interface **PRINCIPALE** pour le monitoring quotidien et les actions rapides.

### **✅ Fonctionnalités**
- **Vue d'ensemble** économique temps réel
- **Statut des services** critiques (IPFS, API, VPN, etc.)
- **Actions rapides** : redémarrage, découverte essaim
- **Navigation** vers les autres scripts spécialisés
- **Alertes** système et économiques

### **🎮 Usage**
```bash
./tools/dashboard.sh
```

### **🔗 Navigation**
- `o` → `UPLANET.official.sh` (virements officiels)
- `z` → `zen.sh` (analyse économique)
- `n` → `captain.sh` (embarquement)

---

## 🏴‍☠️ **captain.sh** - Embarquement et Gestion Capitaine

### **🎯 Rôle Principal**
Script **SPÉCIALISÉ** pour l'embarquement des nouveaux utilisateurs et la gestion des capitaines.

### **✅ Fonctionnalités**
- **Embarquement** nouveaux capitaines
- **Création** MULTIPASS et ZEN Cards
- **Initialisation** infrastructure UPLANET
- **Gestion** des comptes capitaines
- **Navigation** vers les scripts économiques

### **🎮 Usage**
```bash
./captain.sh
```

---

---

## 🌐 **SCRIPTS DE RÉSEAU ET SWARM**

### **🌍 BLOOM.Me.sh** - Formation Automatique de Swarm

#### **🎯 Rôle Principal**
Script **AUTOMATIQUE** pour la formation de swarms IPFS privés via consensus distribué.

#### **✅ Fonctionnalités**
- **Détection stations** : Scan des Astroports niveau Y dans la région GPS
- **Consensus distribué** : Génération collective de `swarm.key`
- **Vérification concordance** : SSH ↔ IPFS NodeID
- **Bootstrap automatique** : Configuration nœuds de démarrage
- **Filtrage géographique** : Même région GPS (~100km)

#### **🎮 Usage**
```bash
# Exécution automatique (via cron ou événement)
./RUNTIME/BLOOM.Me.sh

# Reset complet du swarm
./RUNTIME/BLOOM.Me.sh reset
```

### **🔍 heartbox_analysis.sh** - Analyse Système Temps Réel

#### **🎯 Rôle Principal**
Script **ANALYTIQUE** pour l'analyse complète du système et des capacités.

#### **✅ Fonctionnalités**
- **Ressources système** : CPU, RAM, disque en temps réel
- **Capacités d'hébergement** : Calcul slots ZEN Cards et MULTIPASS
- **État des services** : IPFS, Astroport, uSPOT, NOSTR
- **Export JSON** : Données structurées pour autres scripts
- **Cache intelligent** : TTL 5 minutes pour performance

#### **🎮 Usage**
```bash
# Analyse complète
./tools/heartbox_analysis.sh

# Export JSON pour intégration
./tools/heartbox_analysis.sh export --json
```

---

## 🔄 **FLUX DE TRAVAIL RECOMMANDÉ**

### **🆕 Nouveau Capitaine (Installation Fraîche)**
1. **`install.sh`** → Installation Astroport.ONE
2. **`uplanet_onboarding.sh`** → Embarquement complet UPlanet ẐEN
3. **`UPLANET.init.sh`** → Initialisation infrastructure (automatique)
4. **`captain.sh`** → Création identité et premiers utilisateurs

### **🔄 Utilisateur Existant (Migration ou Mise à Jour)**
1. **`update_config.sh`** → Détection mode et migration si nécessaire
2. **`uplanet_onboarding.sh`** → Configuration économique mise à jour
3. **`UPLANET.official.sh`** → Virements officiels

### **👨‍✈️ Capitaine Quotidien (Opérations)**
1. **`dashboard.sh`** → Vue d'ensemble et monitoring
2. **`UPLANET.official.sh`** → Virements locataires/sociétaires
3. **`zen.sh`** → Analyse et diagnostic si nécessaire

### **🔍 Diagnostic et Maintenance**
1. **`heartbox_analysis.sh`** → Analyse système complète
2. **`zen.sh`** → Diagnostic économique détaillé
3. **`UPLANET.init.sh --dry-run`** → Vérification portefeuilles
4. **`zen.sh`** → Transactions manuelles exceptionnelles

---

## ⚠️ **RÈGLES IMPORTANTES**

### **✅ EMBARQUEMENT ET CONFIGURATION**
- **Nouveaux utilisateurs** : Toujours commencer par `uplanet_onboarding.sh`
- **Utilisateurs existants** : Utiliser `update_config.sh` pour les migrations
- **Mode ORIGIN vs ẐEN** : Choisir selon vos besoins (simplicité vs coopérative complète)
- **Migration ORIGIN → ẐEN** : Possible mais destructive, bien comprendre les conséquences

### **✅ OPÉRATIONS QUOTIDIENNES**
- **Interface principale** : `dashboard.sh` pour le monitoring quotidien
- **Virements officiels** : `UPLANET.official.sh` pour TOUS les virements conformes
- **Analyse économique** : `zen.sh` pour le diagnostic et l'analyse détaillée
- **Initialisation** : `UPLANET.init.sh` pour créer/vérifier les portefeuilles

### **❌ INTERDICTIONS STRICTES**
- **Jamais de migration ẐEN → ORIGIN** : Techniquement impossible
- **Jamais de changement d'UPlanet ẐEN** : Nécessite réinstallation OS complète
- **Pas de transactions manuelles** sans comprendre les flux primaux
- **Pas de modification directe** des fichiers `.dunikey` sans sauvegarde

---

## 🎯 **MODES UPLANET : ORIGIN VS ẐEN**

### **🌍 Mode ORIGIN (Niveau X) - Simplicité**
- **Scripts principaux** : `uplanet_onboarding.sh`, `UPLANET.official.sh`, `dashboard.sh`
- **Réseau** : IPFS public, pas de `swarm.key`
- **Économie** : Simplifiée, idéale pour débuter
- **Source primale** : `EnfinLibre` (fixe)

### **🏴‍☠️ Mode ẐEN (Niveau Y) - Coopérative Complète**
- **Scripts principaux** : Tous les scripts + `BLOOM.Me.sh` + `heartbox_analysis.sh`
- **Réseau** : IPFS privé avec `swarm.key`
- **Économie** : Coopérative complète avec gouvernance
- **Source primale** : `$(cat ~/.ipfs/swarm.key)` (dynamique)

---

## 📚 **DOCUMENTATION TECHNIQUE COMPLÈTE**

### **📖 Guides d'Embarquement**
- **`EMBARQUEMENT.md`** - Guide complet d'embarquement UPlanet ẐEN
- **`SCRIPTS.ROLES.md`** - Ce document (rôles des scripts)
- **`UPLANET.init.README.md`** - Documentation détaillée de l'initialisation

### **🏛️ Constitution et Économie ẐEN**
- **`RUNTIME/ZEN.ECONOMY.readme.md`** - Constitution économique complète
- **`RUNTIME/ZEN.INTRUSION.POLICY.md`** - Politique anti-intrusion et sécurité
- **`RUNTIME/ZEN.ECONOMY.full.ml`** - Diagramme Mermaid architecture complète

### **🔧 Configuration et Templates**
- **`.env.template`** - Template de configuration avec toutes les variables
- **`templates/NOSTR/`** - Templates d'emails pour notifications
- **Configuration dynamique** via `heartbox_analysis.sh`

### **🤖 Scripts d'Automatisation Économique**
- **`ZEN.ECONOMY.sh`** - Paiement PAF + Burn 4-semaines + Apport capital
- **`ZEN.COOPERATIVE.3x1-3.sh`** - Allocation coopérative 3x1/3
- **`NOSTRCARD.refresh.sh`** - Collecte loyers MULTIPASS (1Ẑ + TVA)
- **`PLAYER.refresh.sh`** - Collecte loyers ZEN Cards (4Ẑ + TVA)
- **`primal_wallet_control.sh`** - Contrôle anti-intrusion des portefeuilles

### **🌐 Scripts de Réseau et Swarm**
- **`BLOOM.Me.sh`** - Formation automatique de swarms IPFS privés
- **`ssh_to_g1ipfs.py`** - Vérification concordance SSH ↔ IPFS NodeID
- **Scripts de désinscription** : `nostr_DESTROY_TW.sh`, `PLAYER.unplug.sh`

---

## 🔗 **LIENS ENTRE LES COMPOSANTS**

### **🔄 Flux d'Embarquement**
```
install.sh → uplanet_onboarding.sh → UPLANET.init.sh → captain.sh
     ↓              ↓                      ↓              ↓
Configuration → Choix Mode → Portefeuilles → Identité Capitaine
```

### **🏛️ Flux Économique Quotidien**
```
dashboard.sh → UPLANET.official.sh → ZEN.ECONOMY.sh → ZEN.COOPERATIVE.3x1-3.sh
     ↓               ↓                     ↓                    ↓
Monitoring → Virements Officiels → Paiements Auto → Allocation 3x1/3
```

### **🔍 Flux de Diagnostic**
```
heartbox_analysis.sh → zen.sh → primal_wallet_control.sh
        ↓               ↓              ↓
Analyse Système → Diagnostic → Sécurité Primale
```

Cette architecture modulaire garantit la **séparation des responsabilités**, la **sécurité des flux économiques**, et la **facilité de maintenance** de l'écosystème UPlanet ẐEN.


