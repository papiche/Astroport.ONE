# ZEN.ECONOMY - Code de la Route de l'Écosystème UPlanet

## 🏨 **PRÉAMBULE "POUR LES NULS" : L'ANALOGIE DE L'HÔTEL COOPÉRATIF**

> **📜 Ce document est le Code de la Route technique de la [Constitution de l'Écosystème UPlanet ẐEN](../LEGAL.md)**

Avant de plonger dans les détails techniques, imaginez que notre écosystème est un **hôtel coopératif** :

### **🏗️ L'Infrastructure (Le Bâtiment)**
- **L'Armateur** = Le propriétaire de l'immeuble
- **Le Capitaine** = Le concierge qui gère l'hôtel
- **Les Locataires** = Les clients qui paient pour une chambre
- **Les Sociétaires** = Les co-propriétaires de l'hôtel

### **💰 L'Économie (Les Flux Financiers)**
- **Les Locataires paient un loyer** → Le Capitaine reçoit l'argent
- **Le Capitaine paie une redevance** à l'Armateur (électricité, internet)
- **Le Capitaine garde sa part** (2x PAF) pour son travail
- **Le surplus va à la coopérative** pour investir (trésorerie, R&D, forêts)

### **🌱 L'Objectif (La Mission)**
Chaque loyer payé contribue à acheter des forêts et jardins, créant des biens communs physiques et durables.

---

## 🌟 **VUE D'ENSEMBLE TECHNIQUE**

Le système **ZEN.ECONOMY** est l'incarnation technique du pacte social de la SCIC CopyLaRadio. Il transforme les règles statutaires en protocole automatisé, transparent et décentralisé.

> **"Ce n'est pas seulement une entreprise. C'est un protocole pour générer des coopératives."**

---

## 📋 **ARCHITECTURE DU SYSTÈME**

### **Composants Principaux**

| Script | Fonction | Fréquence | Statut |
|--------|----------|-----------|--------|
| `ZEN.ECONOMY.sh` | Paiement hebdomadaire PAF | Hebdomadaire | ✅ **CONFORME** |
| `ZEN.COOPERATIVE.3x1-3.sh` | Allocation coopérative | Hebdomadaire | ✅ **CONFORME** |
| `ZEN.SWARM.payments.sh` | Paiements inter-nœuds | Quotidienne | ✅ **CONFORME** |
| `NOSTRCARD.refresh.sh` | Paiements MULTIPASS + TVA | Hebdomadaire | ✅ **CONFORME** |
| `PLAYER.refresh.sh` | Paiements ZenCard + TVA | Hebdomadaire | ✅ **CONFORME** |

---

## 🏗️ **MODÈLE ÉCONOMIQUE COOPÉRATIF**

### **1. Paiement Hebdomadaire PAF (Participation Aux Frais)**

**Fréquence :** Hebdomadaire  
**Acteur :** Capitaine → NODE (Armateur)  
**Montant :** PAF hebdomadaire (14 Ẑen)  
**Logique de paiement :** Hiérarchie MULTIPASS → ZEN Card → UPlanet  
**Conformité :** ✅ 100% conforme à la Constitution

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

---

## 💰 **FORMULE DU SURPLUS DU CAPITAINE**

### **Comment est calculé le revenu d'un Capitaine ?**

**Formule :** 
```
Surplus = Revenus Locatifs Totaux - (TVA Collectée + Rémunération Totale)

Où :
- Rémunération Totale = 3x PAF
  - 1x PAF pour l'Armateur (14 Ẑen)
  - 2x PAF pour le Capitaine (28 Ẑen)
```

### **Exemple Chiffré Concret**

```bash
# Scénario : 15 locataires MULTIPASS + 8 sociétaires ZenCard
Revenus Locatifs = (15 × 1 Ẑen) + (8 × 4 Ẑen) = 47 Ẑen

TVA Collectée = (15 × 0.2 Ẑen) + (8 × 0.8 Ẑen) = 9.4 Ẑen

Rémunération Totale = 3 × 14 Ẑen = 42 Ẑen

Surplus = 47 - (9.4 + 42) = -4.4 Ẑen
# Résultat : Pas encore de surplus, mais proche de l'équilibre
```

```bash
# Scénario : 25 locataires MULTIPASS + 15 sociétaires ZenCard
Revenus Locatifs = (25 × 1 Ẑen) + (15 × 4 Ẑen) = 85 Ẑen

TVA Collectée = (25 × 0.2 Ẑen) + (15 × 0.8 Ẑen) = 17 Ẑen

Rémunération Totale = 3 × 14 Ẑen = 42 Ẑen

Surplus = 85 - (17 + 42) = 26 Ẑen
# Résultat : 26 Ẑen de surplus pour la coopérative !
# Allocation 3x1/3 : 8.67 Ẑen vers chaque portefeuille dédié
```

```bash
# Scénario optimal : 30 locataires MULTIPASS + 20 sociétaires ZenCard
Revenus Locatifs = (30 × 1 Ẑen) + (20 × 4 Ẑen) = 110 Ẑen

TVA Collectée = (30 × 0.2 Ẑen) + (20 × 0.8 Ẑen) = 22 Ẑen

Rémunération Totale = 3 × 14 Ẑen = 42 Ẑen

Surplus = 110 - (22 + 42) = 46 Ẑen
# Résultat : 46 Ẑen de surplus pour la coopérative !
# Allocation 3x1/3 : 15.33 Ẑen vers chaque portefeuille dédié
# Impact : Acquisition de terrains, développement R&D, réserves de trésorerie
```

### **3. Allocation Coopérative 3x1/3**

**Processus d'allocation :**
1. **Transfert part Capitaine** : 2x PAF (ou solde disponible si inférieur) vers `UPLANETNAME.$CAPTAINEMAIL` (convertible en euros)
2. **Vérification solde restant** : Allocation coopérative si solde restant > 0
3. **Provision fiscale** : IS (15%/25%) vers `UPLANETNAME.IMPOT`
4. **Répartition 3x1/3** : Surplus net vers les portefeuilles dédiés

**Répartition du surplus net (après provision fiscale) :**

| Destination | Pourcentage | Objectif | Portefeuille |
|-------------|-------------|----------|--------------|
| **Part Capitaine** | 2x PAF | Revenus personnels (convertibles) | `UPLANETNAME.$CAPTAINEMAIL` |
| **Trésorerie** | 33.33% | Liquidité et stabilité | `UPLANETNAME.TREASURY` |
| **R&D** | 33.33% | Recherche et développement | `UPLANETNAME.RND` |
| **Forêts Jardins** | 33.34% | Actifs réels régénératifs | `UPLANETNAME.ASSETS` |

---

## 👥 **USER STORIES : LA VIE DES MEMBRES**

### **🏠 La Vie d'un Locataire (MULTIPASS)**

> **"Je paie mon loyer, je gagne des Ẑen par les likes, et je peux les convertir en euros"**

**Parcours hebdomadaire :**
1. **Paiement automatique** : 1 Ẑen + 0.2 Ẑen TVA vers le Capitaine
2. **Génération de revenus** : Likes et services → Ẑen sur MULTIPASS
3. **Conversion possible** : Pont de liquidité (règle du 1/3)
4. **Statut** : Client temporaire, pas de participation aux bénéfices

**Exemple concret :**
```bash
Loyer hebdomadaire : 1 Ẑen + 0.2 Ẑen TVA
Revenus likes : +3 Ẑen
Solde MULTIPASS : +2 Ẑen
Conversion possible : 0.67 Ẑen/an (1/3 de 2 Ẑen)
```

### **👑 La Vie d'un Sociétaire (ZenCard)**

> **"J'investis, je suis exempté de loyer, je participe à la gouvernance"**

**Parcours hebdomadaire :**
1. **Paiement automatique** : 4 Ẑen + 0.8 Ẑen TVA vers le Capitaine
2. **Statut privilégié** : Co-propriétaire de l'hôtel coopératif
3. **Gouvernance** : Participation aux décisions collectives
4. **Conversion illimitée** : Parts sociales non soumises à la règle du 1/3

**Exemple concret :**
```bash
Contribution hebdomadaire : 4 Ẑen + 0.8 Ẑen TVA
Statut : Co-propriétaire
Droits : Vote + participation aux bénéfices
Conversion : Illimitée (parts sociales)
```

### **👨‍✈️ La Vie d'un Capitaine**

> **"Je gère mon essaim, je perçois les loyers, je paie la PAF, je génère un surplus"**

**Parcours hebdomadaire :**
1. **Collecte des loyers** : MULTIPASS + ZenCard → Revenus totaux
2. **Paiement PAF** : 14 Ẑen vers l'Armateur (électricité, internet)
3. **Reception part personnelle** : 2x PAF (28 Ẑen) vers portefeuille dédié
4. **Génération surplus** : Si revenus > (TVA + 3x PAF)
5. **Allocation coopérative** : 3x1/3 sur le surplus net

**Exemple concret :**
```bash
Revenus hebdomadaires : 85 Ẑen (25 locataires + 15 sociétaires)
TVA collectée : 17 Ẑen
PAF Armateur : 14 Ẑen
Part Capitaine : 28 Ẑen
Surplus coopératif : 26 Ẑen
Allocation 3x1/3 : 8.67 Ẑen vers chaque portefeuille dédié
Impact : Acquisition de terrains, développement R&D, réserves de trésorerie
```

---

## 🌉 **LE PONT DE LIQUIDITÉ : CONVERSION ẐEN → EUROS**

### **Principe Universel**

**L'Armateur, tout comme les autres membres, peut utiliser le pont de liquidité pour convertir les Ẑen reçus en paiement de sa PAF.**

Cela montre que **tous les membres sont logés à la même enseigne** et que le système est équitable.

### **Processus de Conversion**

1. **Demande** : Le membre (y compris l'Armateur) initie la demande
2. **Justification** : Document justificatif uploadé sur IPFS
3. **Validation** : Le protocole vérifie la conformité
4. **Burn** : Transfert des Ẑen vers `UPLANETNAME.G1` (destruction)
5. **Paiement** : Virement SEPA en euros via l'hôte fiscal

### **Règle du 1/3 (Protection du Capital)**

- **Limitation** : 1/3 des Ẑen gagnés par an
- **Exception** : Les parts sociales (ZenCard) ne sont pas limitées
- **Calcul** : Basé sur les 12 derniers mois

---

## 🔄 **FLUX ÉCONOMIQUES AUTOMATISÉS**

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
    T --> U{Captain Balance > 0?}
    U -->|Yes| V[Transfer 2x PAF (or available) to Captain Wallet]
    U -->|No| W[Skip Allocation]
    V --> X{Remaining > 0?}
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

1. **Vérification du solde** : Solde Capitaine > 0
2. **Transfert part Capitaine** : 2x PAF (ou solde disponible) vers portefeuille dédié
3. **Vérification solde restant** : > 0 pour allocation coopérative
4. **Provision fiscale** : IS (15%/25%) selon tranches françaises
5. **Allocation 3x1/3** : Répartition du surplus net
6. **Rapport automatique** : Envoi hebdomadaire par email

---

## 🛡️ **SÉCURITÉ ET CONFORMITÉ**

### **Conformité Légale 100%**

- ✅ **Respect strict de la [Constitution de l'Écosystème](../LEGAL.md)** : https://pad.p2p.legal/s/legal#
- ✅ **Fiscalité française** : TVA 20% + IS 15%/25%
- ✅ **Modèle coopératif** : Allocation 3x1/3 conforme
- ✅ **Transparence** : Audit automatique complet

### **Sécurité Technique**

- **Clés cryptographiques** : Gestion sécurisée des portefeuilles
- **Permissions** : Accès restreint aux clés sensibles
- **Validation** : Vérification des transactions
- **Backup** : Sauvegarde automatique des données

---

## 📊 **MÉTRIQUES ET MONITORING**

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

---

## 🔧 **CONFIGURATION**

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

---

## 📈 **ÉVOLUTIONS FUTURES**

### ** Intelligence Économique Fractale**

- **IA Prédictive** : Analyse des tendances
- **Gouvernance Automatisée** : Votes automatisés
- **Expansion Fractale** : Création de coopératives filles

---

## 🎯 **IMPACT ET BÉNÉFICES**

### **Pour la Coopérative**

- **Conformité 100%** : Respect automatique de la Constitution
- **Transparence totale** : Audit public automatique
- **Efficacité opérationnelle** : Automatisation complète
- **Scalabilité** : Modèle réplicable

### **Pour les Membres**

- **Équité garantie** : Règles appliquées automatiquement
- **Transparence** : Accès aux données économiques
- **Participation** : Gouvernance automatisée
- **Bénéfices partagés** : Allocation équitable

---

## 🔗 **INTÉGRATIONS**

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

**"Le Code de la Route de l'écosystème UPlanet ẐEN - Exécutant technique de la Constitution coopérative."**

**Conformité : 100% ✅**  
**Disponibilité : 99.9%**  
**Transparence : Totale**  
**Innovation : Continue**

---

> **📜 Ce Code de la Route implémente techniquement la [Constitution de l'Écosystème UPlanet ẐEN](../LEGAL.md)**

---

# ANNEXE : ẐEN vs EURO

## 🌍 **Deux Mondes, Deux Géométries**

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