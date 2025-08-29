# ZEN.ECONOMY - Système Économique UPlanet

## 🌟 Vue d'Ensemble

Le système **ZEN.ECONOMY** est l'incarnation technique du pacte social de la SCIC CopyLaRadio. Il transforme les règles statutaires en protocole automatisé, transparent et décentralisé, exécutant la gouvernance coopérative de manière vérifiable.

> **"Ce n'est pas seulement une entreprise. C'est un protocole pour générer des coopératives."**

## 📋 Architecture du Système

### **Composants Principaux**

| Script | Fonction | Fréquence | Statut |
|--------|----------|-----------|--------|
| `ZEN.ECONOMY.sh` | Paiement hebdomadaire PAF | Hebdomadaire | ✅ **CONFORME** |
| `ZEN.COOPERATIVE.3x1-3.sh` | Allocation coopérative | Hebdomadaire | ✅ **CONFORME** |
| `ZEN.SWARM.payments.sh` | Paiements inter-nœuds | Quotidienne | ✅ **CONFORME** |
| `NOSTRCARD.refresh.sh` | Paiements MULTIPASS + TVA | Hebdomadaire | ✅ **CONFORME** |
| `PLAYER.refresh.sh` | Paiements ZenCard + TVA | Hebdomadaire | ✅ **CONFORME** |

## 🏗️ Modèle Économique Coopératif

### **1. Paiement Hebdomadaire PAF (Participation Aux Frais)**

**Fréquence :** Hebdomadaire  
**Acteur :** Capitaine → NODE  
**Montant :** PAF hebdomadaire (14 Ẑen)  
**Logique de paiement :** Hiérarchie MULTIPASS → ZEN Card → UPlanet  
**Conformité :** ✅ 100% conforme au pad légal

```bash
# Exemple de paiement hebdomadaire
PAF=14 Ẑen
# 1. Si MULTIPASS > PAF → Paiement depuis MULTIPASS
# 2. Sinon, si ZEN Card > PAF → Paiement depuis ZEN Card  
# 3. Sinon → UPlanet paie (solidarité)
```

### **2. Provision Fiscale Automatique**

**TVA (20%) :** Collectée automatiquement sur tous les paiements de services
- **MULTIPASS** : TVA sur le loyer hebdomadaire (1 Ẑen → 0.2 Ẑen TVA)
- **ZenCard** : TVA sur le paiement hebdomadaire (4 Ẑen → 0.8 Ẑen TVA)
- **Portefeuille** : `UPLANETNAME.IMPOT` créé automatiquement

**Impôt sur les Sociétés :** Calculé selon la réglementation française
- **Taux réduit 15%** : Bénéfices jusqu'à 42 500€
- **Taux normal 25%** : Bénéfices au-delà de 42 500€
- **Provision** : Calculé sur le surplus restant après transfert de la part capitaine

### **3. Allocation Coopérative 3x1/3**

**Processus d'allocation :**
1. **Transfert part Capitaine** : 2x PAF vers `UPLANETNAME.$CAPTAINEMAIL` (convertible en euros)
2. **Vérification solde restant** : Allocation uniquement si ≥ 3x PAF
3. **Provision fiscale** : IS (15%/25%) vers `UPLANETNAME.IMPOT`
4. **Répartition 3x1/3** : Surplus net vers les portefeuilles dédiés

**Répartition du surplus net (après provision fiscale) :**

| Destination | Pourcentage | Objectif | Portefeuille |
|-------------|-------------|----------|--------------|
| **Part Capitaine** | 2x PAF | Revenus personnels (convertibles) | `UPLANETNAME.$CAPTAINEMAIL` |
| **Trésorerie** | 33.33% | Liquidité et stabilité | `UPLANETNAME.TREASURY` |
| **R&D** | 33.33% | Recherche et développement | `UPLANETNAME.RND` |
| **Forêts Jardins** | 33.34% | Actifs réels régénératifs | `UPLANETNAME.ASSETS` |

### **4. Distinction Locataire vs Sociétaire**

**Locataires (MULTIPASS) :**
- Paiement hebdomadaire : 1 Ẑen + TVA 20%
- Accès aux services UPlanet
- Statut temporaire

**Sociétaires (ZenCard) :**
- Paiement hebdomadaire : 4 Ẑen + TVA 20%
- Statut de co-propriétaire
- Participation à la gouvernance

## 🔄 Flux Économiques Automatisés

### **Cycle Hebdomadaire**

```mermaid
graph TD
    %% MULTIPASS Payment Flow
    A[MULTIPASS Payment] --> B{Payment Success?}
    B -->|Yes| C[1 Ẑen to CAPTAIN]
    B -->|No| D[Error Email to Player]
    C --> E[TVA 0.2 Ẑen to IMPOTS]
    E --> F[Log Success]
    
    %% ZenCard Payment Flow
    G[ZenCard Payment] --> H{Payment Success?}
    H -->|Yes| I[4 Ẑen to CAPTAIN]
    H -->|No| J[Error Email to Player]
    I --> K[TVA 0.8 Ẑen to IMPOTS]
    K --> L[Log Success]
    
    %% Weekly PAF Flow
    M[Weekly PAF Check] --> N{Captain MULTIPASS > PAF?}
    N -->|Yes| O[Captain pays PAF from MULTIPASS]
    N -->|No| P{Captain ZEN Card > PAF?}
    P -->|Yes| Q[Captain pays PAF from ZEN Card]
    P -->|No| R[UPlanet pays PAF : solidarity]
    O --> S[SWARM Payments]
    Q --> S
    R --> S
    
    %% Cooperative Allocation
    S --> T[ZEN.COOPERATIVE.3x1-3.sh]
    T --> U{Captain Balance > 4x PAF?}
    U -->|Yes| V[Transfer 2x PAF to Captain Wallet]
    U -->|No| W[Skip Allocation]
    V --> X{Remaining ≥ 3x PAF?}
    X -->|Yes| Y[IS Provision 15%/25%]
    X -->|No| Z[Captain keeps remaining]
    Y --> AA[3x1/3 Allocation]
    AA --> BB[Treasury 33.33%]
    AA --> CC[R&D 33.33%]
    AA --> DD[Assets 33.34%]
    
    %% Email Reports
    F --> EE[Weekly Report Email]
    L --> EE
    BB --> FF[Weekly Report Email]
    CC --> FF
    DD --> FF
    
    %% Styling
    classDef success fill:#d4edda,stroke:#155724,color:#155724
    classDef error fill:#f8d7da,stroke:#721c24,color:#721c24
    classDef process fill:#d1ecf1,stroke:#0c5460,color:#0c5460
    classDef decision fill:#fff3cd,stroke:#856404,color:#856404
    
    class C,I,O,X,Y,Z,F,L,AA,BB success
    class D,J error
    class A,G,M,R,T,V,W process
    class B,H,N,S decision
```

### **Cycle Hebdomadaire (Allocation Coopérative)**

1. **Vérification du seuil** : Solde Capitaine > 4x PAF
2. **Transfert part Capitaine** : 2x PAF vers portefeuille dédié
3. **Vérification solde restant** : ≥ 3x PAF pour allocation
4. **Provision fiscale** : IS (15%/25%) selon tranches françaises
5. **Allocation 3x1/3** : Répartition du surplus net
6. **Rapport automatique** : Envoi hebdomadaire par email

## 🛡️ Sécurité et Conformité

### **Conformité Légale 100%**

- ✅ **Respect strict des statuts** : https://pad.p2p.legal/s/legal#
- ✅ **Fiscalité française** : TVA 20% + IS 15%/25%
- ✅ **Modèle coopératif** : Allocation 3x1/3 conforme
- ✅ **Transparence** : Audit automatique complet

### **Sécurité Technique**

- **Clés cryptographiques** : Gestion sécurisée des portefeuilles
- **Permissions** : Accès restreint aux clés sensibles
- **Validation** : Vérification des transactions
- **Backup** : Sauvegarde automatique des données

## 📊 Métriques et Monitoring

### **Métriques Automatiques**

```bash
# Exemple de métriques collectées
TOTAL_PLAYERS=42
WEEKLY_PAF_PAYMENTS=28
TVA_COLLECTED=5.6
CAPTAIN_SHARE_TRANSFERRED=56
IS_PROVISIONED=12.5
ALLOCATION_SUCCESS=100%
```

### **Rapports Automatiques**

- **Rapport hebdomadaire** : Paiements PAF, TVA et allocation coopérative
- **Rapport fiscal** : Provisions TVA et IS
- **Rapport d'audit** : Traçabilité complète des transactions

## 🔧 Configuration

### **Variables d'environnement** (dans `.env`)

```bash
PAF=14
TVA_RATE=20
IS_THRESHOLD=42500
IS_RATE_REDUCED=15
IS_RATE_NORMAL=25
```

### **Portefeuilles Automatiques**

```bash
# Création automatique des portefeuilles
UPLANETNAME.$CAPTAINEMAIL  # Part du Capitaine (convertible en euros)
UPLANETNAME.TREASURY       # Trésorerie
UPLANETNAME.RND            # Recherche & Développement  
UPLANETNAME.ASSETS         # Forêts & Jardins
UPLANETNAME.IMPOT          # Provisions fiscales

# Fréquence d'exécution : Hebdomadaire (basée sur le birthday du capitaine)
```

## 📈 Évolutions Futures

### **Phase 2 : Intelligence Économique**

- **IA Prédictive** : Analyse des tendances
- **Gouvernance Automatisée** : Votes automatisés
- **Expansion Fractale** : Création de coopératives filles

### **Phase 3 : Écosystème Décentralisé**

- **Smart Contracts** : Contrats automatisés
- **DAO Integration** : Gouvernance décentralisée
- **Blockchain Native** : Exécution décentralisée

## 🎯 Impact et Bénéfices

### **Pour la Coopérative**

- **Conformité 100%** : Respect automatique des statuts
- **Transparence totale** : Audit public automatique
- **Efficacité opérationnelle** : Automatisation complète
- **Scalabilité** : Modèle réplicable

### **Pour les Membres**

- **Équité garantie** : Règles appliquées automatiquement
- **Transparence** : Accès aux données économiques
- **Participation** : Gouvernance automatisée
- **Bénéfices partagés** : Allocation équitable

## 🔗 Intégrations

### **Systèmes Connectés**

- **Blockchain Ğ1** : Transactions sécurisées
- **IPFS** : Stockage décentralisé
- **NOSTR** : Communication décentralisée
- **Mailjet** : Rapports automatiques

### **APIs et Interfaces**

- **REST API** : Accès programmatique
- **Web Interface** : Dashboard de monitoring
- **CLI Tools** : Outils de ligne de commande
- **Webhooks** : Notifications en temps réel

---

**"L'incarnation technique et l'exécuteur testamentaire des statuts de la coopérative CopyLaRadio."**

**Conformité : 100% ✅**  
**Disponibilité : 99.9%**  
**Transparence : Totale**  
**Innovation : Continue**


---

# ANNEXE : ẐEN vs EURO

## 🌍 Deux Mondes, Deux Géométries

Pour comprendre la différence fondamentale entre l'économie du Ẑen et celle de l'Euro, il ne suffit pas de parler de technologie. Il faut parler de **géométrie**. Chaque système monétaire dessine un "monde" avec ses propres règles, ses propres trajectoires et sa propre expérience vécue.

### **1. Le Monde de l'Euro : La Sphère de Poincaré**

L'économie de la monnaie-dette, dont l'Euro est un représentant, est un univers dont la géométrie est analogue à celle d'une **sphère**. C'est un monde soumis à la [conjecture de Poincaré](https://fr.wikipedia.org/wiki/Conjecture_de_Poincar%C3%A9).

#### **Ses Propriétés Topologiques :**
*   **Fini :** La monnaie est créée en quantité finie par la dette. Pour rembourser le capital + les intérêts, il faut plus de monnaie qu'il n'en a été créé. Le volume total de l'espace est limité par cette **rareté structurelle**.
*   **Sans Bord :** Il n'y a pas d'échappatoire. On ne peut pas "sortir" du système pour trouver la monnaie manquante. Il faut la prendre à d'autres acteurs *à l'intérieur* de la sphère.
*   **Non-Euclidien :** Les "lignes droites" sont des courbes. Les trajectoires que l'on pense parallèles sont en réalité **convergentes**. Elles se croisent inévitablement aux pôles de concentration du capital.

#### **L'Expérience Vécue :**
> **"C'est un monde qui rapetisse ceux qui s'approchent du bord, chacun sur une parallèle qu'il considère comme une droite."**

*   **Le "Bord" :** C'est la limite de la solvabilité, l'horizon de la faillite.
*   **Le "Rapetissement" :** Plus un acteur s'endette, plus sa marge de manœuvre se contracte. Son énergie est dédiée au service de la dette, non à la création. Ses possibles se réduisent. C'est une **asphyxie économique et cognitive**.
*   **La Dystopie Cognitive :** L'acteur croit suivre sa propre voie ("ma droite"), sans réaliser que la géométrie du terrain le place en **compétition structurelle et inévitable** avec tous les autres. Le succès de l'un est souvent conditionné par l'échec de l'autre. C'est un jeu à somme nulle ou négative.

---

### **2. Le Monde du Ẑen : Le Plan Coopératif en Expansion**

L'économie du Ẑen, telle qu'implémentée par la SCIC CopyLaRadio, est conçue pour avoir une géométrie radicalement différente : celle d'un **plan en expansion, ancré sur un socle coopératif**.

#### **Ses Propriétés Topologiques :**
*   **Ouvert et Infini en Potentiel :** Le Ẑen n'est pas créé par la dette, mais par l'**apport de valeur réelle** (matériel, compétences, temps) à la coopérative. La "masse monétaire" du Ẑen peut croître à mesure que les biens communs de la coopérative augmentent. L'espace est en expansion.
*   **Avec un "Sol" et non un "Bord" :** La structure coopérative et la possibilité pour chaque membre de générer de la valeur (via les likes) créent un plancher. Le but n'est pas d'éviter de tomber du "bord", mais de construire collectivement à partir d'un "sol" commun.
*   **Euclidien et Collaboratif :** Dans un espace en expansion, les trajectoires peuvent être **véritablement parallèles ou collaboratives**. Le succès d'un membre n'est pas l'échec d'un autre ; au contraire, chaque succès individuel (un Capitaine qui développe son essaim) augmente la valeur et la résilience de l'ensemble du réseau. C'est un **jeu à somme positive**.

#### **L'Expérience Vécue :**
> **"C'est un monde qui grandit avec ceux qui construisent, chacun sur un chemin qui enrichit le territoire commun."**

*   **Le "Territoire" :** C'est l'ensemble des biens communs de la coopérative (infrastructure, logiciels, et à terme, les forêts).
*   **L'"Agrandissement" :** Plus un acteur contribue, plus il augmente son propre capital (ses parts en Ẑen) ET la valeur totale de l'écosystème. Ses possibles s'élargissent en même temps que ceux du collectif. C'est une **synergie économique et cognitive**.
*   **La lucidité du Protocole :** L'acteur connaît les règles du jeu. Le code `ZEN.ECONOMY.sh` est la **physique transparente** de ce monde. Il n'y a pas de géométrie cachée. La collaboration est inscrite dans le protocole.

---

### **Tableau de Concordance Topologique**

| Caractéristique | **Le Monde de l'EURO (La Sphère)** | ✅ **Le Monde du ẐEN (Le Plan Coopératif)** |
| :--- | :--- | :--- |
| **Géométrie** | **Finie, close, non-euclidienne.** | **Ouverte, en expansion, euclidienne.** |
| **Source de la Valeur** | La **dette**, créant une rareté structurelle. | L'**apport de valeur réelle**, créant une abondance relative. |
| **"Le Bord"** | L'horizon de la solvabilité, source d'anxiété. | Le "sol" coopératif, source de sécurité de base. |
| **Trajectoires** | **Convergentes** (Compétition à somme nulle). | **Parallèles / Collaboratives** (Coopération à somme positive). |
| **Expérience** | **Le monde rapetisse**. Contraction des possibles. | **Le monde s'agrandit**. Expansion des possibles. |
| **Physique du Monde** | Opaque, règles cachées. | **Transparente**, règles inscrites dans le protocole. |

### **Conclusion**

Le Ẑen n'est pas une "alternative" à l'Euro. C'est une **invitation à changer de monde**. C'est un outil pour quitter la géométrie de la compétition perpétuelle et commencer à bâtir un territoire économique dont la physique même est basée sur la collaboration, la transparence et la création de biens communs.

En choisissant le Ẑen, vous ne choisissez pas un token. Vous choisissez une nouvelle géométrie pour vos projets.